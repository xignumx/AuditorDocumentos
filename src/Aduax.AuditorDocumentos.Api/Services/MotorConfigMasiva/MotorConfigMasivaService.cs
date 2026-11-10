using Aduax.AuditorDocumentos.Api.Data.Aduasis;
using Aduax.AuditorDocumentos.Api.Data.DesarrolloDB;
using Aduax.AuditorDocumentos.Api.Services.Aduasis;
using Aduax.AuditorDocumentos.Api.Services.DesarrolloDb;
using Aduax.AuditorDocumentos.Api.Services.EDOCS;
using Aduax.AuditorDocumentos.VModels;

namespace Aduax.AuditorDocumentos.Api.Services.MotorConfigMasiva
{
    /// <summary>
    /// Carga masiva de la matriz de validación documental (E5-ID02). Aplica las filas del Excel a cada cliente
    /// seleccionado reutilizando las mismas reglas y la misma bitácora que el guardado manual de /config.
    /// Las validaciones de la solicitud lanzan <see cref="InvalidOperationException"/> con mensaje para el usuario.
    /// </summary>
    public interface IMotorConfigMasivaService
    {
        Task<byte[]> GenerarPlantillaAsync();
        Task<CargaMasivaMatrizResultDto> ProcesarAsync(CargaMasivaMatrizRequest request, string usuario);
    }

    public class MotorConfigMasivaService : IMotorConfigMasivaService
    {
        public const int MaxBytesArchivo = 5 * 1024 * 1024;
        public const int MaxClientes = 200;
        public const int MaxCombinaciones = 1000;
        private const int MaxCambiosPorItem = 8;
        private const string MotivoPorDefecto = "Carga masiva de matriz (Compliance)";

        private readonly IDesarrolloDb_DbContextServices _desarrolloDb;
        private readonly IAduasisDbContextServices _aduasisDb;
        private readonly IEDOCS_DbContextServices _edocsDb;

        public MotorConfigMasivaService(
            IDesarrolloDb_DbContextServices desarrolloDb,
            IAduasisDbContextServices aduasisDb,
            IEDOCS_DbContextServices edocsDb)
        {
            _desarrolloDb = desarrolloDb;
            _aduasisDb = aduasisDb;
            _edocsDb = edocsDb;
        }

        public async Task<byte[]> GenerarPlantillaAsync()
        {
            var catalogo = await ObtenerCatalogoTiposAsync();
            return MatrizConfigExcel.GenerarPlantilla(catalogo.Select(t => (t.Key, t.Value)));
        }

        public async Task<CargaMasivaMatrizResultDto> ProcesarAsync(CargaMasivaMatrizRequest request, string usuario)
        {
            var contenido = DecodificarArchivo(request);
            var idsClientes = (request.IdsClientes ?? new List<string>())
                .Where(id => !string.IsNullOrWhiteSpace(id))
                .Select(id => id.Trim())
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();

            if (idsClientes.Count == 0)
            {
                throw new InvalidOperationException("Seleccione al menos un cliente");
            }
            if (idsClientes.Count > MaxClientes)
            {
                throw new InvalidOperationException($"Solo se pueden seleccionar {MaxClientes} clientes por carga");
            }

            var resultado = new CargaMasivaMatrizResultDto
            {
                SoloPrevisualizar = request.SoloPrevisualizar,
                TotalClientes = idsClientes.Count
            };

            var parseada = MatrizConfigExcel.Parsear(contenido);
            resultado.ErroresArchivo.AddRange(parseada.Errores);
            resultado.Avisos.AddRange(parseada.Avisos);
            resultado.TotalFilasArchivo = parseada.Filas.Count;

            var catalogo = await ObtenerCatalogoTiposAsync();
            foreach (var fila in parseada.Filas.Where(f => !catalogo.ContainsKey(f.IdTipoDocumentoVucem)))
            {
                resultado.ErroresArchivo.Add(
                    $"Fila {fila.Fila}: el tipo {fila.IdTipoDocumentoVucem} no existe o no está activo en el Auditor de Documentos");
            }

            var clientes = await _aduasisDb.GetClientesPorIdsAsync(idsClientes);
            var noEncontrados = idsClientes
                .Except(clientes.Select(c => c.IdCliente.Trim()), StringComparer.OrdinalIgnoreCase)
                .ToList();
            if (noEncontrados.Count > 0)
            {
                resultado.ErroresArchivo.Add($"Clientes no encontrados: {string.Join(", ", noEncontrados)}");
            }

            var combinaciones = parseada.Filas.Count * clientes.Count;
            if (combinaciones > MaxCombinaciones)
            {
                resultado.ErroresArchivo.Add(
                    $"La carga genera {combinaciones} configuraciones y el máximo es {MaxCombinaciones}. " +
                    "Reduzca los clientes o las filas del archivo");
            }

            if (resultado.ErroresArchivo.Count > 0)
            {
                return resultado;
            }

            var motivo = string.IsNullOrWhiteSpace(request.MotivoCambio)
                ? MotivoPorDefecto
                : request.MotivoCambio.Trim();

            foreach (var cliente in clientes.OrderBy(c => c.RazonSocial, StringComparer.CurrentCultureIgnoreCase))
            {
                foreach (var fila in parseada.Filas)
                {
                    var item = await ProcesarCombinacionAsync(
                        cliente,
                        fila,
                        catalogo[fila.IdTipoDocumentoVucem],
                        !request.SoloPrevisualizar,
                        usuario,
                        motivo);
                    resultado.Items.Add(item);
                }
            }

            resultado.TotalNuevos = resultado.Items.Count(i => i.Estado == CargaMasivaMatrizEstado.Nuevo);
            resultado.TotalModifica = resultado.Items.Count(i => i.Estado == CargaMasivaMatrizEstado.Modifica);
            resultado.TotalSinCambios = resultado.Items.Count(i => i.Estado == CargaMasivaMatrizEstado.SinCambios);
            resultado.TotalErrores = resultado.Items.Count(i => i.Estado == CargaMasivaMatrizEstado.Error);
            resultado.TotalAplicados = resultado.Items.Count(i => i.Aplicado);

            return resultado;
        }

        private async Task<CargaMasivaMatrizItemDto> ProcesarCombinacionAsync(
            FCliente cliente,
            FilaMatriz fila,
            string documento,
            bool aplicar,
            string usuario,
            string motivo)
        {
            var item = new CargaMasivaMatrizItemDto
            {
                IdCliente = cliente.IdCliente.Trim(),
                RazonSocial = cliente.RazonSocial,
                IdTipoDocumentoVucem = fila.IdTipoDocumentoVucem,
                Documento = documento
            };

            try
            {
                // Si no existe motor devuelve uno con los valores por defecto (sin guardar)
                var header = await _desarrolloDb.GetMotorConfigHeaderConDetalleAsync(
                    item.IdCliente,
                    fila.IdTipoDocumentoVucem);
                header.Detalles ??= new List<AdMotorConfigDetalle>();

                var esNuevo = header.Id == 0;
                var antes = MotorConfigReglas.ConstruirParametros(header);

                await AplicarFilaAsync(header, fila, esNuevo);
                MotorConfigReglas.ValidarDetalles(header.Detalles);

                var cambios = Diferencias(antes, MotorConfigReglas.ConstruirParametros(header));
                item.TotalCambios = cambios.Count;
                item.Cambios = cambios.Take(MaxCambiosPorItem).ToList();
                item.Estado = esNuevo
                    ? CargaMasivaMatrizEstado.Nuevo
                    : cambios.Count > 0 ? CargaMasivaMatrizEstado.Modifica : CargaMasivaMatrizEstado.SinCambios;

                if (aplicar && item.Estado != CargaMasivaMatrizEstado.SinCambios)
                {
                    header.MotivoCambio = motivo;
                    if (esNuevo)
                    {
                        header.CreadoPor = usuario;
                    }
                    else
                    {
                        header.ActualizadoPor = usuario;
                    }

                    await _desarrolloDb.SaveMotorConfigHeaderConDetalleAsync(header, AdMotorConfigBitacoraOrigen.Masiva);
                    item.Aplicado = true;
                }
            }
            catch (InvalidOperationException ex)
            {
                MarcarError(item, ex.Message);
            }
            catch (Exception ex)
            {
                MarcarError(item, $"Error inesperado: {ex.Message}");
            }
            finally
            {
                // El contexto es único por solicitud: se libera lo rastreado para no degradar el resto de la carga
                _desarrolloDb.LimpiarSeguimientoCambios();
            }

            return item;
        }

        /// <summary>Superpone las celdas capturadas sobre la configuración actual (o por defecto).</summary>
        private async Task AplicarFilaAsync(AdMotorConfigHeader header, FilaMatriz fila, bool esNuevo)
        {
            if (fila.Clasificacion.HasValue && fila.Clasificacion.Value != header.IdClasificacion)
            {
                if (!esNuevo && await _desarrolloDb.ExisteDocumentoNoPendientePorMotorConfigAsync(header.Id))
                {
                    throw new InvalidOperationException(
                        "No se puede cambiar la clasificación: existen documentos Pendientes, Aprobados, Vinculados o Digitalizados");
                }
                header.IdClasificacion = fila.Clasificacion.Value;
            }

            if (fila.AccionPedimento != null)
            {
                header.AccionPedimento = fila.AccionPedimento;
            }

            foreach (var (idCampo, valores) in fila.Campos)
            {
                var detalle = header.Detalles!.FirstOrDefault(d => d.IdCampo == idCampo);
                if (detalle == null)
                {
                    // Motores anteriores a un campo nuevo no lo tienen todavía
                    detalle = MotorConfigReglas.CrearDetalleDefault((AdCampos)idCampo);
                    header.Detalles!.Add(detalle);
                }

                if (valores.Visible.HasValue)
                {
                    detalle.Visible = valores.Visible.Value;
                    if (!detalle.Visible)
                    {
                        detalle.Obligatorio = false;
                    }
                }

                if (valores.Obligatorio.HasValue)
                {
                    if (valores.Obligatorio.Value && !detalle.Visible)
                    {
                        throw new InvalidOperationException(
                            $"{detalle.NombreCampo}: no puede ser obligatorio mientras no sea visible");
                    }
                    detalle.Obligatorio = valores.Obligatorio.Value;
                }
            }
        }

        private static void MarcarError(CargaMasivaMatrizItemDto item, string mensaje)
        {
            item.Estado = CargaMasivaMatrizEstado.Error;
            item.Mensaje = mensaje;
            item.Aplicado = false;
        }

        private static List<string> Diferencias(
            Dictionary<string, string> antes,
            Dictionary<string, string> despues)
        {
            var cambios = new List<string>();
            foreach (var parametro in antes.Keys.Union(despues.Keys))
            {
                antes.TryGetValue(parametro, out var valorAntes);
                despues.TryGetValue(parametro, out var valorDespues);
                if (string.Equals(valorAntes, valorDespues, StringComparison.Ordinal))
                {
                    continue;
                }
                cambios.Add(DescribirCambio(parametro, valorAntes, valorDespues));
            }
            return cambios;
        }

        private static string DescribirCambio(string parametro, string? antes, string? despues)
        {
            if (parametro == "IdClasificacion")
            {
                return $"Clasificación: {NombreClasificacion(antes)} → {NombreClasificacion(despues)}";
            }
            if (parametro == "AccionPedimento")
            {
                return $"Acción en operación: {antes ?? "-"} → {despues ?? "-"}";
            }
            if (parametro.StartsWith("Campo:", StringComparison.Ordinal))
            {
                var detalle = parametro["Campo:".Length..];
                var separador = detalle.LastIndexOf('.');
                var campo = separador > 0 ? detalle[..separador] : detalle;
                var atributo = separador > 0 ? detalle[(separador + 1)..].ToLowerInvariant() : string.Empty;
                return $"{campo} ({atributo}): {antes ?? "-"} → {despues ?? "-"}";
            }
            return $"{parametro}: {antes ?? "-"} → {despues ?? "-"}";
        }

        private static string NombreClasificacion(string? valor)
        {
            return valor switch
            {
                "1" => "Identificador general",
                "2" => "Identificador partida",
                "3" => "Permisos",
                _ => valor ?? "-"
            };
        }

        private async Task<Dictionary<int, string>> ObtenerCatalogoTiposAsync()
        {
            var (tipos, _) = await _edocsDb.GetDocumentosVucemActivosConPrefijoAsync(null, 1, 5000);
            return tipos.ToDictionary(t => t.Id_DocumentoVucem, t => t.Documento);
        }

        private static byte[] DecodificarArchivo(CargaMasivaMatrizRequest request)
        {
            if (string.IsNullOrWhiteSpace(request.ArchivoBase64))
            {
                throw new InvalidOperationException("El archivo es requerido");
            }

            if (!(request.NombreArchivo ?? string.Empty).EndsWith(".xlsx", StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException("El archivo debe ser un libro de Excel (.xlsx)");
            }

            byte[] contenido;
            try
            {
                contenido = Convert.FromBase64String(request.ArchivoBase64);
            }
            catch (FormatException)
            {
                throw new InvalidOperationException("El contenido del archivo no es válido");
            }

            if (contenido.Length > MaxBytesArchivo)
            {
                throw new InvalidOperationException(
                    $"El archivo excede el tamaño máximo de {MaxBytesArchivo / (1024 * 1024)} MB");
            }

            return contenido;
        }
    }
}
