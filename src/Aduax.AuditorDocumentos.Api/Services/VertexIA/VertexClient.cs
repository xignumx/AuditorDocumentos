using Google.Api.Gax;
using Google.Api.Gax.Grpc;
using Google.Apis.Auth.OAuth2;
using Google.Cloud.AIPlatform.V1;
using Google.Cloud.Storage.V1;
using Google.Protobuf;
using Aduax.AuditorDocumentos.Api.Services.VertexIA.Models;
using Aduax.AuditorDocumentos.VModels;
using Grpc.Core;
using iText.Kernel.Pdf;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;
using static Google.Cloud.AIPlatform.V1.SafetySetting.Types;

namespace Aduax.AuditorDocumentos.Api.Services.VertexIA
{
    public class VertexClient : IVertexClient
    {
        private readonly Config _config;
        private readonly string publisher = "google";
        private static readonly Dictionary<string, string> MimeTypes = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            { "pdf", "application/pdf" },
            { "xml", "application/xml" }
        };

        // Valores por defecto para el envío de PDFs grandes por rangos de páginas.
        // > 25 páginas: se trocea en grupos de 10 (partes más pequeñas => respuesta por parte más rápida).
        private const int DefaultMaxPagesSingleShot = 25;
        private const int DefaultPagesPerChunk = 10;
        // Pausa entre partes para suavizar el tráfico y aliviar límites de cuota (ResourceExhausted / 429).
        private const int InterChunkDelayMs = 3000;
        // PDFs grandes requieren más tiempo que el deadline gRPC por defecto.
        private static readonly TimeSpan CallTimeout = TimeSpan.FromMinutes(5);

        // Reintentos ante errores transitorios de Vertex (429 / capacidad).
        private const int MaxIntentosVertex = 5;
        // Backoff base para 429 (cuota por minuto): requiere esperas largas.
        private const int Backoff429BaseMs = 20000;
        private const int Backoff429MaxMs = 90000;
        // Backoff base para el resto de errores transitorios (Unavailable, etc.).
        private const int BackoffTransitorioBaseMs = 1000;
        private const int BackoffTransitorioMaxMs = 15000;

        // Campos multivalor (separados por ';') a los que se les limpian duplicados en el JSON acumulado.
        private static readonly HashSet<string> CamposMultivalorDedup = new(StringComparer.OrdinalIgnoreCase)
        {
            nameof(AdCampos.ProductoNoDeParte),
            nameof(AdCampos.DescripcionMercancia),
            nameof(AdCampos.Fracciones),
            nameof(AdCampos.UnidadMedidaUMT),
            nameof(AdCampos.PaisOrigenDestino)
        };

        // Serialización compacta y sin escapar caracteres no-ASCII (para no romper acentos).
        private static readonly JsonSerializerOptions JsonSalidaOptions = new()
        {
            Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
            WriteIndented = false
        };

        // Troceo habilitado por defecto; si la sección ArchivosGrandes no viene en el JSON, se asume true.
        private bool TroceoHabilitado => _config.ArchivosGrandes?.Habilitado ?? true;

        private int MaxPagesSingleShot =>
            (_config.ArchivosGrandes?.MaxPaginasEnvioUnico ?? 0) > 0
                ? _config.ArchivosGrandes!.MaxPaginasEnvioUnico
                : DefaultMaxPagesSingleShot;

        private int PagesPerChunk =>
            (_config.ArchivosGrandes?.PaginasPorGrupo ?? 0) > 0
                ? _config.ArchivosGrandes!.PaginasPorGrupo
                : DefaultPagesPerChunk;

        public VertexClient(Config config, float? temperatura = null)
        {
            _config = config;
            // Si se proporciona una temperatura, actualizar la temperatura en la configuración
            if (temperatura.HasValue)
            {
                _config.VertexTemperature = temperatura.Value;
            }
        }

        public async Task<string> GetAnalizeJson(string prompt, DocumentToAnalize? document)
        {
            string? filename = null;
            string? fileBase64 = null;
            if (document != null)
            {
                filename = document.NombreArchivo;
                fileBase64 = document.DocBase64;
            }

            // Endpoint global (aiplatform.googleapis.com + locations/global) cuando LocationId = "global";
            // Google recomienda el endpoint global para reducir errores 429 (más capacidad on-demand disponible).
            string endpointHost = string.Equals(_config.LocationId, "global", StringComparison.OrdinalIgnoreCase)
                ? "aiplatform.googleapis.com"
                : $"{_config.LocationId}-aiplatform.googleapis.com";

            var predictionServiceClient = await new PredictionServiceClientBuilder
            {
                Endpoint = endpointHost,
                JsonCredentials = _config.JsonCredentials
            }.BuildAsync();

            var callSettings = CallSettings.FromExpiration(Expiration.FromTimeout(CallTimeout));

            // PDFs grandes: enviar por rangos de páginas manteniendo el contexto
            // (refinamiento incremental del JSON) para no exceder los límites del modelo.
            // Configurable vía ArchivosGrandes; solo la evaluación/división con iText se protege
            // (los errores de Vertex se propagan). Si el troceo está deshabilitado, se usa envío completo.
            byte[]? pdfBytesParaRangos = null;
            int totalPaginasPdf = 0;
            if (TroceoHabilitado
                && !string.IsNullOrEmpty(filename) && !string.IsNullOrEmpty(fileBase64)
                && GetMimeType(filename) == "application/pdf")
            {
                try
                {
                    byte[] pdfBytes = Convert.FromBase64String(fileBase64);
                    int pageCount = GetPdfPageCount(pdfBytes);
                    if (pageCount > MaxPagesSingleShot)
                    {
                        pdfBytesParaRangos = pdfBytes;
                        totalPaginasPdf = pageCount;
                    }
                }
                catch (Exception ex)
                {
                    // Si no se puede leer/dividir el PDF con iText, se continúa con el envío completo.
                    Console.WriteLine($"[Vertex] No se pudo preparar el envío por rangos, se usará envío completo: {ex.Message}");
                }
            }

            if (pdfBytesParaRangos != null)
            {
                // Nota: los errores de Vertex (p. ej. 429) se propagan; NO se reintenta con envío
                // completo porque una sola petición con todo el documento consume aún más cuota.
                return await AnalyzeByPageRangesAsync(
                    predictionServiceClient, prompt, pdfBytesParaRangos, totalPaginasPdf, callSettings);
            }

            // Camino normal: documento pequeño (o sin documento) en una sola petición.
            GenerateContentRequest generateContentRequest = BuildBaseRequest(prompt);

            if (!string.IsNullOrEmpty(filename) && !string.IsNullOrEmpty(fileBase64))
            {
                bool uploaded = await UploadFile(filename, fileBase64);
                if (uploaded)
                {
                    string mimeType = GetMimeType(filename);
                    generateContentRequest.Contents[0].Parts.Add(
                        new Part { FileData = new() { MimeType = mimeType, FileUri = $"gs://{_config.Bucket}/{filename}" } }
                    );
                }
                else
                {
                    Console.WriteLine("No se pudo subir el archivo [Vertex]");
                    return "";
                }
            }

            return await GenerateWithRetryAsync(predictionServiceClient, generateContentRequest, callSettings);
        }

        /// <summary>
        /// Envía un PDF grande a Vertex en varias partes (rangos de páginas), manteniendo el
        /// contexto entre partes mediante el JSON consolidado que se va acumulando.
        /// </summary>
        private async Task<string> AnalyzeByPageRangesAsync(
            PredictionServiceClient client,
            string prompt,
            byte[] pdfBytes,
            int totalPages,
            CallSettings callSettings)
        {
            var ranges = BuildPageRanges(totalPages, PagesPerChunk);
            string accumulatedJson = string.Empty;

            for (int i = 0; i < ranges.Count; i++)
            {
                var (from, to) = ranges[i];
                byte[] chunkBytes = ExtractPages(pdfBytes, from, to);

                var sb = new StringBuilder();
                sb.AppendLine(prompt);
                sb.AppendLine();
                sb.AppendLine("=== INSTRUCCIONES DE PROCESAMIENTO POR PARTES ===");
                sb.AppendLine($"El documento original tiene {totalPages} páginas y se está enviando por partes para respetar los límites del modelo.");
                sb.AppendLine($"Estás analizando ÚNICAMENTE las páginas {from} a {to} de {totalPages} (parte {i + 1} de {ranges.Count}).");

                if (!string.IsNullOrWhiteSpace(accumulatedJson))
                {
                    sb.AppendLine();
                    sb.AppendLine("Este es el JSON consolidado con la información extraída de las páginas anteriores:");
                    sb.AppendLine("```json");
                    sb.AppendLine(accumulatedJson);
                    sb.AppendLine("```");
                    sb.AppendLine();
                    sb.AppendLine("Combina esa información con lo que encuentres en las páginas actuales:");
                    sb.AppendLine("- NO elimines datos ya presentes, salvo que las páginas actuales los corrijan explícitamente.");
                    sb.AppendLine("- Agrega o actualiza los campos y elementos (partidas, mercancías, etc.) que aparezcan en estas páginas.");
                    sb.AppendLine("- En los campos multivalor separados por ';' (fracción, unidad de medida, país, no. de parte y descripción de mercancía) NO repitas valores: consolida sin duplicados.");
                    sb.AppendLine("- Devuelve SIEMPRE el JSON COMPLETO y consolidado con la estructura solicitada, no solo lo nuevo.");
                }
                else
                {
                    sb.AppendLine();
                    sb.AppendLine("Devuelve el JSON con la estructura solicitada usando la información encontrada en estas páginas.");
                }

                GenerateContentRequest request = BuildBaseRequest(sb.ToString());
                request.Contents[0].Parts.Add(new Part
                {
                    InlineData = new Blob
                    {
                        MimeType = "application/pdf",
                        Data = ByteString.CopyFrom(chunkBytes)
                    }
                });

                accumulatedJson = await GenerateWithRetryAsync(client, request, callSettings);
                // Limpiar duplicados en campos multivalor antes de reenviar el contexto y de retornar.
                accumulatedJson = LimpiarDuplicadosMultivalor(accumulatedJson);

                if (i < ranges.Count - 1 && InterChunkDelayMs > 0)
                    await Task.Delay(InterChunkDelayMs);
            }

            return accumulatedJson;
        }

        /// <summary>
        /// Limpia valores duplicados en los campos multivalor (separados por ';') del JSON acumulado:
        /// no. de parte, descripción de mercancía, fracción, unidad de medida y país.
        /// Es best-effort: ante cualquier error devuelve el JSON original sin modificar.
        /// </summary>
        private static string LimpiarDuplicadosMultivalor(string json)
        {
            if (string.IsNullOrWhiteSpace(json))
                return json;

            try
            {
                if (JsonNode.Parse(json) is not JsonObject obj)
                    return json;

                bool modificado = false;
                foreach (var clave in CamposMultivalorDedup)
                {
                    if (!obj.TryGetPropertyValue(clave, out JsonNode? valor) || valor is null)
                        continue;

                    bool quitarEspacios = string.Equals(clave, nameof(AdCampos.ProductoNoDeParte),
                        StringComparison.OrdinalIgnoreCase);

                    if (valor is JsonArray arr)
                    {
                        var tokens = new List<string>();
                        foreach (var el in arr)
                            if (el is JsonValue ev && ev.TryGetValue<string>(out string? s) && s != null)
                                tokens.Add(s);

                        var limpios = DeduplicarTokens(tokens, quitarEspacios);
                        var nuevoArr = new JsonArray();
                        foreach (var t in limpios)
                            nuevoArr.Add(t);
                        obj[clave] = nuevoArr;
                        modificado = true;
                    }
                    else if (valor is JsonValue jv && jv.TryGetValue<string>(out string? texto)
                             && texto != null && texto.Contains(';'))
                    {
                        var limpios = DeduplicarTokens(texto.Split(';'), quitarEspacios);
                        obj[clave] = string.Join("; ", limpios);
                        modificado = true;
                    }
                }

                return modificado ? obj.ToJsonString(JsonSalidaOptions) : json;
            }
            catch
            {
                return json;
            }
        }

        /// <summary>
        /// Quita tokens duplicados preservando el primero y su orden. Comparación sin distinción de
        /// mayúsculas y con espacios internos colapsados; para no. de parte además ignora todos los espacios.
        /// </summary>
        private static List<string> DeduplicarTokens(IEnumerable<string> tokens, bool ignorarEspaciosEnComparacion)
        {
            var vistos = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var resultado = new List<string>();
            foreach (var raw in tokens)
            {
                var t = Regex.Replace((raw ?? string.Empty).Trim(), @"\s+", " ");
                if (t.Length == 0)
                    continue;

                var clave = ignorarEspaciosEnComparacion ? t.Replace(" ", string.Empty) : t;
                if (vistos.Add(clave))
                    resultado.Add(t);
            }
            return resultado;
        }

        /// <summary>
        /// Construye la petición base (modelo, generation config y safety settings) con el prompt indicado.
        /// </summary>
        private GenerateContentRequest BuildBaseRequest(string promptText)
        {
            GenerateContentRequest request = new()
            {
                //Model = $"projects/{_config.ProjectId}/locations/{_config.LocationId}/publishers/{publisher}/models/{_config.VertexModel}",
                Model = $"projects/{_config.ProjectId}/locations/global/publishers/{publisher}/models/{_config.VertexModel}",
                Contents =
                {
                    new Content
                    {
                        Role = "USER",
                        Parts =
                        {
                            new Part { Text = promptText }
                        }
                    }
                },
                GenerationConfig = new GenerationConfig
                {
                    Temperature = (float)_config.VertexTemperature,
                    MaxOutputTokens = _config.VertexMaxOutputTokens,
                    TopP = (float)_config.VertexTopP,
                    TopK = (float)_config.VertexTopK
                }
            };

            request.SafetySettings.Add(new SafetySetting { Category = HarmCategory.Harassment, Threshold = HarmBlockThreshold.BlockNone });
            request.SafetySettings.Add(new SafetySetting { Category = HarmCategory.HateSpeech, Threshold = HarmBlockThreshold.BlockNone });
            request.SafetySettings.Add(new SafetySetting { Category = HarmCategory.SexuallyExplicit, Threshold = HarmBlockThreshold.BlockNone });
            request.SafetySettings.Add(new SafetySetting { Category = HarmCategory.DangerousContent, Threshold = HarmBlockThreshold.BlockNone });

            return request;
        }

        /// <summary>
        /// Ejecuta la petición contra Vertex con reintentos y backoff exponencial truncado, devolviendo el JSON.
        /// Distingue errores transitorios (reintentables) de definitivos; para 429 usa esperas largas.
        /// </summary>
        private async Task<string> GenerateWithRetryAsync(
            PredictionServiceClient client,
            GenerateContentRequest request,
            CallSettings callSettings)
        {
            int intento = 0;

            while (true)
            {
                intento++;
                try
                {
                    GenerateContentResponse response = await client.GenerateContentAsync(request, callSettings);
                    string resultText = response.Candidates[0].Content.Parts[0].Text;

                    // Extraer JSON si viene dentro de bloque ```json ... ```
                    var match = Regex.Match(resultText, @"```(?:json)?\s*(.*?)\s*```", RegexOptions.Singleline);
                    return match.Success ? match.Groups[1].Value.Trim() : resultText.Trim();
                }
                catch (Exception ex)
                {
                    bool reintentable = EsErrorReintentable(ex, out StatusCode? statusCode);
                    Console.WriteLine($"[Vertex] Error en intento {intento}/{MaxIntentosVertex} " +
                        $"(status={statusCode?.ToString() ?? "N/A"}, reintentable={reintentable}): {ex.Message}");

                    if (intento >= MaxIntentosVertex || !reintentable)
                        throw new Exception(
                            $"Fallaron los intentos con Vertex tras {intento} intento(s). Último error: {ex.Message}", ex);

                    int delayMs = CalcularBackoffMs(statusCode, intento);
                    Console.WriteLine($"[Vertex] Reintentando en {delayMs} ms (status={statusCode})...");
                    await Task.Delay(delayMs);
                }
            }
        }

        /// <summary>
        /// Determina si un error de Vertex es transitorio (conviene reintentar) y extrae el StatusCode gRPC.
        /// </summary>
        private static bool EsErrorReintentable(Exception ex, out StatusCode? statusCode)
        {
            var rpc = ex as RpcException ?? ex.InnerException as RpcException;
            statusCode = rpc?.StatusCode;

            if (rpc == null)
                return false;

            return rpc.StatusCode switch
            {
                StatusCode.ResourceExhausted => true,   // 429: capacidad/cuota
                StatusCode.Unavailable => true,         // 503: transitorio
                StatusCode.DeadlineExceeded => true,
                StatusCode.Aborted => true,
                StatusCode.Internal => true,
                _ => false
            };
        }

        /// <summary>
        /// Backoff exponencial truncado con jitter. Para 429 usa una base grande (cuota por minuto).
        /// </summary>
        private static int CalcularBackoffMs(StatusCode? statusCode, int intento)
        {
            bool esCuota = statusCode == StatusCode.ResourceExhausted;
            double baseMs = esCuota ? Backoff429BaseMs : BackoffTransitorioBaseMs;
            double maxMs = esCuota ? Backoff429MaxMs : BackoffTransitorioMaxMs;

            double calculado = baseMs * Math.Pow(2, intento - 1);
            double truncado = Math.Min(calculado, maxMs);
            int jitter = Random.Shared.Next(0, 2000);
            return (int)truncado + jitter;
        }

        /// <summary>
        /// Calcula los rangos de páginas [desde, hasta] (1-indexado, inclusivos) para el chunking.
        /// </summary>
        private static List<(int From, int To)> BuildPageRanges(int totalPages, int pagesPerChunk)
        {
            var ranges = new List<(int From, int To)>();
            for (int start = 1; start <= totalPages; start += pagesPerChunk)
            {
                int end = Math.Min(start + pagesPerChunk - 1, totalPages);
                ranges.Add((start, end));
            }
            return ranges;
        }

        private static int GetPdfPageCount(byte[] pdfBytes)
        {
            using var ms = new MemoryStream(pdfBytes);
            using var reader = new PdfReader(ms);
            reader.SetUnethicalReading(true); // permitir PDFs protegidos solo con contraseña de propietario
            using var doc = new PdfDocument(reader);
            return doc.GetNumberOfPages();
        }

        /// <summary>
        /// Extrae un rango de páginas (inclusivo, 1-indexado) del PDF y lo devuelve como un PDF nuevo.
        /// </summary>
        private static byte[] ExtractPages(byte[] pdfBytes, int from, int to)
        {
            using var srcMs = new MemoryStream(pdfBytes);
            using var reader = new PdfReader(srcMs);
            reader.SetUnethicalReading(true); // permitir PDFs protegidos solo con contraseña de propietario
            using var srcDoc = new PdfDocument(reader);

            using var outMs = new MemoryStream();
            var writer = new PdfWriter(outMs);
            writer.SetCloseStream(false); // controlamos el ciclo de vida del MemoryStream
            using (var destDoc = new PdfDocument(writer))
            {
                srcDoc.CopyPagesTo(from, to, destDoc);
            }
            return outMs.ToArray();
        }

        private async Task<bool> UploadFile(string fileName, string Base64String)
        {
            try
            {
                var credentialStream = new MemoryStream(Encoding.UTF8.GetBytes(_config.JsonCredentials));
                var googleCredential = GoogleCredential.FromStream(credentialStream);
                StorageClientBuilder storageClientBuilder = new()
                {
                    Credential = googleCredential
                };
                StorageClient storage = storageClientBuilder.Build();
                byte[] bytes = Convert.FromBase64String(Base64String);
                using MemoryStream fileStream = new(bytes);
                string mimeType = GetMimeType(fileName);
                await storage.UploadObjectAsync(_config.Bucket, fileName, mimeType, fileStream);

                var obj = await storage.GetObjectAsync(_config.Bucket, fileName);
                return obj != null;
            }
            catch (Exception ex)
            {
                Console.WriteLine("An error ocurred in UploadFile(): " + ex.Message);
                return false;
            }
        }

        private string GetMimeType(string? filename)
        {
            if (string.IsNullOrEmpty(filename))
                return "application/octet-stream";
            var ext = Path.GetExtension(filename).TrimStart('.').ToLowerInvariant();
            return MimeTypes.TryGetValue(ext, out var mime) ? mime : "application/octet-stream";
        }
    }
}
