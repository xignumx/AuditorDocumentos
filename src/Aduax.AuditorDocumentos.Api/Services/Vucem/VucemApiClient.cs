using System.Diagnostics;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;
using Microsoft.Extensions.Options;
using Aduax.AuditorDocumentos.Api.Configuration;
using Aduax.AuditorDocumentos.VModels;

namespace Aduax.AuditorDocumentos.Api.Services.Vucem
{
    public class VucemApiClient : IVucemApiClient
    {
        private const int MaxUserMessageLength = 500;

        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            PropertyNameCaseInsensitive = true
        };

        private static readonly JsonSerializerOptions RequestJsonOptions = new()
        {
            DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
        };

        private readonly HttpClient _httpClient;
        private readonly VucemApiCfg _config;
        private readonly ILogger<VucemApiClient> _logger;
        private string? _accessToken;
        private DateTime _tokenExpiresAtUtc = DateTime.MinValue;
        private readonly SemaphoreSlim _tokenLock = new(1, 1);

        public VucemApiClient(
            HttpClient httpClient,
            IOptions<VucemApiCfg> config,
            ILogger<VucemApiClient> logger)
        {
            _httpClient = httpClient;
            _config = config.Value;
            _logger = logger;
            _httpClient.Timeout = TimeSpan.FromSeconds(Math.Max(60, _config.TimeoutSeconds));
        }

        public async Task<EnvioVucemResultDto> EnviarArchivoVucemAsync(
            int idArchivo,
            int idSello,
            string rfcConsulta,
            string nombreArchivo,
            string? correoElectronico,
            CancellationToken cancellationToken = default)
        {
            if (!_config.EstaConfigurado)
            {
                throw new InvalidOperationException(
                    "La API Vucem no está configurada. Revise la sección VucemApi en appsettings o variables de entorno.");
            }

            await EnsureTokenAsync(cancellationToken);

            var body = new
            {
                idSello,
                rfcConsulta,
                nombreArchivo,
                correoElectronico
            };

            var request = new HttpRequestMessage(
                HttpMethod.Post,
                $"api/archivos/{idArchivo}/envio-vucem")
            {
                Content = JsonContent.Create(body, options: RequestJsonOptions)
            };
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _accessToken);
            request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

            string content = string.Empty;
            var elapsed = Stopwatch.StartNew();
            try
            {
                var response = await _httpClient.SendAsync(request, cancellationToken);
                content = await response.Content.ReadAsStringAsync(cancellationToken);
                elapsed.Stop();

                if (!response.IsSuccessStatusCode)
                {
                    var isGateway = IsGatewayStatus(response.StatusCode, content);
                    var mensaje = BuildHttpErrorMessage(response.StatusCode, content, elapsed.Elapsed);
                    _logger.LogWarning(
                        "Envío Vucem falló {Status} archivo {IdArchivo} en {ElapsedMs}ms: {Mensaje}",
                        (int)response.StatusCode,
                        idArchivo,
                        elapsed.ElapsedMilliseconds,
                        mensaje);
                    throw new VucemApiException(
                        mensaje,
                        isGatewayError: isGateway);
                }

                _logger.LogInformation(
                    "Envío Vucem OK archivo {IdArchivo} en {ElapsedMs}ms",
                    idArchivo,
                    elapsed.ElapsedMilliseconds);
            }
            catch (VucemApiException)
            {
                throw;
            }
            catch (Exception ex) when (IsHttpTimeout(ex, cancellationToken))
            {
                _logger.LogWarning(
                    ex,
                    "Timeout al enviar archivo {IdArchivo} a API Vucem",
                    idArchivo);
                throw new VucemApiException(
                    "La API VUCEM no respondió a tiempo. El envío puede tardar varios minutos; intente de nuevo más tarde.",
                    isTimeout: true,
                    innerException: ex);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error de comunicación con API Vucem archivo {IdArchivo}", idArchivo);
                throw new VucemApiException(
                    "No fue posible completar la comunicación con la API VUCEM. Intente de nuevo más tarde.",
                    innerException: ex);
            }

            var result = JsonSerializer.Deserialize<EnvioVucemResultDto>(content, JsonOptions)
                ?? throw new VucemApiException("La API VUCEM devolvió una respuesta vacía.");

            return result;
        }

        private async Task EnsureTokenAsync(CancellationToken cancellationToken)
        {
            if (!string.IsNullOrEmpty(_accessToken) && DateTime.UtcNow < _tokenExpiresAtUtc.AddMinutes(-2))
            {
                return;
            }

            await _tokenLock.WaitAsync(cancellationToken);
            try
            {
                if (!string.IsNullOrEmpty(_accessToken) && DateTime.UtcNow < _tokenExpiresAtUtc.AddMinutes(-2))
                {
                    return;
                }

                var loginBody = new
                {
                    nombre = _config.NombreAplicacion,
                    apiKey = _config.ApiKey
                };

                HttpResponseMessage response;
                string content;
                try
                {
                    response = await _httpClient.PostAsJsonAsync("api/auth/login", loginBody, cancellationToken);
                    content = await response.Content.ReadAsStringAsync(cancellationToken);
                }
                catch (Exception ex) when (IsHttpTimeout(ex, cancellationToken))
                {
                    throw new VucemApiException(
                        "No se pudo autenticar en la API VUCEM: tiempo de espera agotado.",
                        isTimeout: true,
                        innerException: ex);
                }

                if (!response.IsSuccessStatusCode)
                {
                    throw new VucemApiException(
                        $"No se pudo autenticar en la API VUCEM: {BuildHttpErrorMessage(response.StatusCode, content)}");
                }

                using var doc = JsonDocument.Parse(content);
                var root = doc.RootElement;
                _accessToken = root.GetProperty("accessToken").GetString();
                var expiresIn = root.TryGetProperty("expiresIn", out var exp) ? exp.GetInt32() : 3600;
                _tokenExpiresAtUtc = DateTime.UtcNow.AddSeconds(expiresIn);

                if (string.IsNullOrEmpty(_accessToken))
                {
                    throw new VucemApiException("La API VUCEM devolvió un token de autenticación vacío.");
                }
            }
            finally
            {
                _tokenLock.Release();
            }
        }

        private static bool IsHttpTimeout(Exception ex, CancellationToken cancellationToken)
        {
            if (cancellationToken.IsCancellationRequested)
            {
                return false;
            }

            for (var current = ex; current != null; current = current.InnerException)
            {
                if (current is TimeoutException)
                {
                    return true;
                }

                if (current is TaskCanceledException)
                {
                    return true;
                }
            }

            return false;
        }

        private static bool IsGatewayStatus(HttpStatusCode statusCode, string? content)
        {
            return statusCode is HttpStatusCode.BadGateway
                or HttpStatusCode.GatewayTimeout
                or HttpStatusCode.ServiceUnavailable
                || LooksLikeHtml(content);
        }

        private static string BuildHttpErrorMessage(
            HttpStatusCode statusCode,
            string? content,
            TimeSpan? elapsed = null)
        {
            var extracted = TryExtractJsonMessage(content);
            if (!string.IsNullOrWhiteSpace(extracted) && !LooksLikeHtml(extracted))
            {
                return TruncateMessage(extracted);
            }

            if (LooksLikeHtml(content))
            {
                var elapsedHint = elapsed.HasValue && elapsed.Value.TotalSeconds >= 60
                    ? $" Tras {elapsed.Value.TotalSeconds:F0} s de espera, el proxy IIS frente a VUCEM cerró la conexión."
                    : string.Empty;

                return statusCode switch
                {
                    HttpStatusCode.InternalServerError =>
                        "La API VUCEM reportó un error interno (500). Intente de nuevo más tarde.",
                    HttpStatusCode.BadGateway =>
                        "El envío a VUCEM superó el tiempo permitido por el proxy del servidor (502)." +
                        elapsedHint +
                        " El proceso en VUCEM puede tardar más de 1 minuto; solicite aumentar el timeout del proxy en VucemApi o reintente.",
                    HttpStatusCode.ServiceUnavailable =>
                        "La API VUCEM no está disponible (503). Intente de nuevo más tarde.",
                    HttpStatusCode.GatewayTimeout =>
                        "La API VUCEM no respondió a tiempo (504)." + elapsedHint + " Intente de nuevo más tarde.",
                    HttpStatusCode.RequestTimeout =>
                        "La API VUCEM no respondió a tiempo (408). Intente de nuevo más tarde.",
                    _ => $"La API VUCEM respondió con error {(int)statusCode}. Intente de nuevo más tarde."
                };
            }

            if (!string.IsNullOrWhiteSpace(extracted))
            {
                return TruncateMessage(extracted);
            }

            return statusCode switch
            {
                HttpStatusCode.InternalServerError =>
                    "La API VUCEM reportó un error interno (500). Intente de nuevo más tarde.",
                _ => $"La API VUCEM respondió con error {(int)statusCode}."
            };
        }

        private static string? TryExtractJsonMessage(string? content)
        {
            if (string.IsNullOrWhiteSpace(content))
            {
                return null;
            }

            var trimmed = content.Trim();
            if (!trimmed.StartsWith('{') && !trimmed.StartsWith('['))
            {
                return null;
            }

            try
            {
                using var doc = JsonDocument.Parse(trimmed);
                if (doc.RootElement.TryGetProperty("mensaje", out var mensaje))
                {
                    return mensaje.GetString();
                }

                if (doc.RootElement.TryGetProperty("message", out var message))
                {
                    return message.GetString();
                }

                if (doc.RootElement.TryGetProperty("title", out var title))
                {
                    return title.GetString();
                }
            }
            catch (JsonException)
            {
                return null;
            }

            return null;
        }

        private static bool LooksLikeHtml(string? value)
        {
            if (string.IsNullOrWhiteSpace(value))
            {
                return false;
            }

            var trimmed = value.TrimStart();
            if (trimmed.StartsWith("<!DOCTYPE", StringComparison.OrdinalIgnoreCase)
                || trimmed.StartsWith("<html", StringComparison.OrdinalIgnoreCase)
                || trimmed.StartsWith("<style", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            return Regex.IsMatch(
                trimmed,
                @"HTTP\s+Error\s+\d|Bad\s+Gateway|Gateway\s+Timeout|iiserror|innerException",
                RegexOptions.IgnoreCase);
        }

        private static string TruncateMessage(string message)
        {
            var normalized = Regex.Replace(message.Trim(), @"\s+", " ");
            if (normalized.Length <= MaxUserMessageLength)
            {
                return normalized;
            }

            return normalized[..MaxUserMessageLength] + "…";
        }
    }
}
