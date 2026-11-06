using Amazon.Runtime.Internal.Endpoints.StandardLibrary;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http.Timeouts;
using Microsoft.AspNetCore.Mvc;
using Aduax.AuditorDocumentos.Api.Auth;
using Aduax.AuditorDocumentos.Api.Data.DesarrolloDB;
using Aduax.AuditorDocumentos.Api.Services.Aduasis;
using Aduax.AuditorDocumentos.Api.Services.DesarrolloDb;
using Aduax.AuditorDocumentos.Api.Services.EDOCS;
using Aduax.AuditorDocumentos.Api.Services.FileStorage;
using Aduax.AuditorDocumentos.Api.Services.Vucem;
using Aduax.AuditorDocumentos.Api.Services.VertexIA;
using Aduax.AuditorDocumentos.Api.Services.VertexIA.Models;
using Aduax.AuditorDocumentos.Api.Utilities;
using Aduax.AuditorDocumentos.VModels;
using Org.BouncyCastle.Crypto.Fpe;
using System.Text;
using System.Text.Json;
using DocumentFormat.OpenXml.Office2016.Drawing.Command;

namespace Aduax.AuditorDocumentos.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class DocumentosController : ControllerBase
    {
        private readonly IDesarrolloDb_DbContextServices _desarrolloDbService;
        private readonly IAduasisDbContextServices _aduasisDbContextServices;
        private readonly IEDOCS_DbContextServices _eDOCS_DbContextServices;
        private readonly IFileStorageService _fileStorageService;
        private readonly IVucemApiClient _vucemApiClient;

        public DocumentosController(
            IDesarrolloDb_DbContextServices desarrolloDbService,
            IAduasisDbContextServices aduasisDbContextServices,
            IEDOCS_DbContextServices eDOCS_DbContextServices,
            IFileStorageService fileStorageService,
            IVucemApiClient vucemApiClient)
        {
            _desarrolloDbService = desarrolloDbService;
            _aduasisDbContextServices = aduasisDbContextServices;
            _eDOCS_DbContextServices = eDOCS_DbContextServices;
            _fileStorageService = fileStorageService;
            _vucemApiClient = vucemApiClient;
        }

        [HttpPost("ExtraDatosDocumentoIa")]
        public async Task<ActionResult<GenericResponse<List<CampoExtraidoIA>>>> ExtraDatosDocumentoIa([FromBody] GenericAdRequest<DocumentoRequest> request)
        {
            try
            {
                // Validar IdCliente e IdTipoDocumentoVucem
                if (string.IsNullOrWhiteSpace(request.IdCliente))
                {
                    return BadRequest(new GenericResponse<List<CampoExtraidoIA>>
                    {
                        Success = false,
                        Message = "IdCliente es requerido"
                    });
                }

                if (!request.IdTipoDocumentoVucem.HasValue)
                {
                    return BadRequest(new GenericResponse<List<CampoExtraidoIA>>
                    {
                        Success = false,
                        Message = "IdTipoDocumentoVucem es requerido"
                    });
                }

                // Validar datos del archivo
                if (request.Data == null)
                {
                    return BadRequest(new GenericResponse<List<CampoExtraidoIA>>
                    {
                        Success = false,
                        Message = "Los datos del documento son requeridos"
                    });
                }

                if (string.IsNullOrWhiteSpace(request.Data.NombreArchivo))
                {
                    return BadRequest(new GenericResponse<List<CampoExtraidoIA>>
                    {
                        Success = false,
                        Message = "El nombre del archivo es requerido"
                    });
                }

                if (string.IsNullOrWhiteSpace(request.Data.DocBase64))
                {
                    return BadRequest(new GenericResponse<List<CampoExtraidoIA>>
                    {
                        Success = false,
                        Message = "El contenido del archivo (DocBase64) es requerido"
                    });
                }

                // Validar IdDocumento en Data
                if (request.Data.IdDocumento == 0)
                {
                    return BadRequest(new GenericResponse<List<CampoExtraidoIA>>
                    {
                        Success = false,
                        Message = "IdDocumento es requerido en los datos del documento"
                    });
                }

                // Obtener usuario del token
                var tokenLogin = HttpContext.GetTokenLoginDTO();
                if (tokenLogin == null || string.IsNullOrWhiteSpace(tokenLogin.ShortUserName))
                {
                    return Unauthorized(new GenericResponse<List<CampoExtraidoIA>>
                    {
                        Success = false,
                        Message = "No se pudo obtener la información del usuario autenticado"
                    });
                }

                // Validar que sea PDF
                string extension = Path.GetExtension(request.Data.NombreArchivo).ToLowerInvariant();
                if (extension != ".pdf")
                {
                    return BadRequest(new GenericResponse<List<CampoExtraidoIA>>
                    {
                        Success = false,
                        Message = "El archivo debe ser un PDF"
                    });
                }

                // Validar que el PDF no esté dañado (intentar decodificar base64)
                byte[] pdfBytes;
                try
                {
                    pdfBytes = Convert.FromBase64String(request.Data.DocBase64);
                    if (pdfBytes.Length == 0)
                    {
                        return BadRequest(new GenericResponse<List<CampoExtraidoIA>>
                        {
                            Success = false,
                            Message = "El archivo PDF está vacío o dañado"
                        });
                    }

                    // Validar que los primeros bytes sean del formato PDF (%PDF)
                    if (pdfBytes.Length < 4 || Encoding.ASCII.GetString(pdfBytes, 0, 4) != "%PDF")
                    {
                        return BadRequest(new GenericResponse<List<CampoExtraidoIA>>
                        {
                            Success = false,
                            Message = "El archivo no es un PDF válido"
                        });
                    }
                }
                catch (FormatException)
                {
                    return BadRequest(new GenericResponse<List<CampoExtraidoIA>>
                    {
                        Success = false,
                        Message = "El contenido del archivo (DocBase64) no es válido"
                    });
                }

                int idTipoDocumentoVucem = request.IdTipoDocumentoVucem.Value;

                // Recuperar configuración del motor con detalles visibles
                var motorConfig = await _desarrolloDbService.GetMotorConfigHeaderConDetalleAsync(
                    request.IdCliente, 
                    idTipoDocumentoVucem);

                var detallesVisibles = motorConfig.Detalles?
                    .Where(d => d.Visible)
                    .OrderBy(d => d.IdCampo)
                    .ToList() ?? new List<AdMotorConfigDetalle>();

                if (!detallesVisibles.Any())
                {
                    return BadRequest(new GenericResponse<List<CampoExtraidoIA>>
                    {
                        Success = false,
                        Message = "No hay campos visibles configurados para este documento"
                    });
                }

                // Recuperar prompt del documento y prompts de campos
                var (promptDocumento, promptCampos) = await _desarrolloDbService.GetIaPromptDocumentoConCamposAsync(idTipoDocumentoVucem);

                if (promptDocumento == null || !promptDocumento.Activo)
                {
                    return BadRequest(new GenericResponse<List<CampoExtraidoIA>>
                    {
                        Success = false,
                        Message = "No existe un prompt activo configurado para este tipo de documento"
                    });
                }

                // Construir lista de campos para [CAMPOS]
                var listaCampos = new StringBuilder();
                foreach (var detalle in detallesVisibles)
                {
                    string nombreCampo = Enum.GetName(typeof(AdCampos), detalle.IdCampo) ?? detalle.NombreCampo;
                    string obligatorio = detalle.Obligatorio ? "obligatorio" : "opcional";
                    listaCampos.AppendLine($"- {nombreCampo} ({obligatorio})");
                }

                // Construir estructura JSON para [JSON]
                var jsonStructure = new StringBuilder();
                jsonStructure.AppendLine("{");
                for (int i = 0; i < detallesVisibles.Count; i++)
                {
                    var detalle = detallesVisibles[i];
                    string nombreCampo = Enum.GetName(typeof(AdCampos), detalle.IdCampo) ?? detalle.NombreCampo;
                    
                    // Buscar el prompt del campo
                    var promptCampo = promptCampos.FirstOrDefault(p => p.IdCampo == detalle.IdCampo);
                    string descripcion = promptCampo?.PromptParcial ?? detalle.NombreCampo;

                    jsonStructure.Append($"  \"{nombreCampo}\": \"{descripcion}\"");
                    if (i < detallesVisibles.Count - 1)
                    {
                        jsonStructure.AppendLine(",");
                    }
                    else
                    {
                        jsonStructure.AppendLine();
                    }
                }
                jsonStructure.AppendLine("}");

                // Reemplazar etiquetas en el prompt
                string promptFinal = promptDocumento.Prompt
                    .Replace("[CAMPOS]", listaCampos.ToString().TrimEnd())
                    .Replace("[JSON]", jsonStructure.ToString());

                // Recuperar configuración de IA
                var configIa = await _desarrolloDbService.GetConfiguracionIaAsync("Google");
                if (configIa == null)
                {
                    return BadRequest(new GenericResponse<List<CampoExtraidoIA>>
                    {
                        Success = false,
                        Message = "No existe una configuración activa de IA para Google"
                    });
                }

                // Deserializar configuración
                var config = JsonSerializer.Deserialize<Config>(configIa.Configuracion);
                if (config == null)
                {
                    return BadRequest(new GenericResponse<List<CampoExtraidoIA>>
                    {
                        Success = false,
                        Message = "La configuración de IA no es válida"
                    });
                }

                // Instanciar VertexClient
                var vertexClient = new VertexClient(config);

                // Preparar documento para análisis
                var documento = new DocumentToAnalize
                {
                    NombreArchivo = request.Data.NombreArchivo,
                    DocBase64 = request.Data.DocBase64
                };

                // Guardar evento: Envío a IA
                await _desarrolloDbService.SaveBitacoraEventoAsync(
                    request.Data.IdDocumento,
                    AdEventos.DOC_ENVIO_IA,
                    $"Documento enviado a IA para procesamiento. Tipo: {idTipoDocumentoVucem}",
                    null,
                    tokenLogin.ShortUserName);

                // Ejecutar IA
                string jsonResult = await vertexClient.GetAnalizeJson(promptFinal, documento);

                if (string.IsNullOrWhiteSpace(jsonResult))
                {
                    return BadRequest(new GenericResponse<List<CampoExtraidoIA>>
                    {
                        Success = false,
                        Message = "No se pudo obtener una respuesta de la IA"
                    });
                }

                // Deserializar JSON resultante a diccionario
                var jsonDoc = JsonDocument.Parse(jsonResult);
                var resultDictionary = new Dictionary<string, object>();

                // No se recuperan datos desde la IA
                if (jsonDoc.RootElement.ValueKind != JsonValueKind.Object)
                {
                    return Ok(new GenericResponse<List<CampoExtraidoIA>>
                    {
                        Success = false,
                        Message = "No se pudo extraer la información solicitada por parte de la IA, revisar el archivo cargado"
                    });
                }

                // Convertir todo el JSON a diccionario
                if (jsonDoc.RootElement.ValueKind == JsonValueKind.Object)
                {
                    foreach (var property in jsonDoc.RootElement.EnumerateObject())
                    {
                        resultDictionary[property.Name] = property.Value.ValueKind switch
                        {
                            JsonValueKind.String => property.Value.GetString() ?? string.Empty,
                            JsonValueKind.Number => property.Value.GetDecimal(),
                            JsonValueKind.True => true,
                            JsonValueKind.False => false,
                            JsonValueKind.Null => null!,
                            JsonValueKind.Array => JsonSerializer.Deserialize<object[]>(property.Value.GetRawText()) ?? Array.Empty<object>(),
                            JsonValueKind.Object => JsonSerializer.Deserialize<Dictionary<string, object>>(property.Value.GetRawText()) ?? new Dictionary<string, object>(),
                            _ => property.Value.GetRawText()
                        };
                    }
                }

                // Guardar ejecución de IA
                await _desarrolloDbService.SaveIaEjecucionAsync(
                    request.Data.IdDocumento,
                    "Google",
                    config.VertexModel,
                    promptFinal,
                    jsonResult);

                // Guardar evento: Resultado de IA
                await _desarrolloDbService.SaveBitacoraEventoAsync(
                    request.Data.IdDocumento,
                    AdEventos.DOC_RESULTADO_IA,
                    $"Resultado de IA obtenido exitosamente. Modelo: {config.VertexModel}",
                    null,
                    tokenLogin.ShortUserName);

                // Transformar el diccionario a lista de CampoExtraidoIA con IdCampo
                var camposExtraidos = new List<CampoExtraidoIA>();

                foreach (var kvp in resultDictionary)
                {
                    if (kvp.Key == "1" || kvp.Key == "3")
                        continue;

                    // Intentar parsear el nombre del campo al enum AdCampos
                    if (Enum.TryParse<AdCampos>(kvp.Key, true, out var campoEnum))
                    {
                        camposExtraidos.Add(new CampoExtraidoIA
                        {
                            IdCampo = (int)campoEnum,
                            NombreCampo = kvp.Key,
                            Valor = kvp.Value
                        });
                    }
                    else
                    {
                        // Si no se puede parsear, intentar buscar en los detalles visibles
                        var detalle = detallesVisibles.FirstOrDefault(d => 
                            d.NombreCampo.Equals(kvp.Key, StringComparison.OrdinalIgnoreCase));
                        
                        if (detalle != null)
                        {
                            camposExtraidos.Add(new CampoExtraidoIA
                            {
                                IdCampo = detalle.IdCampo,
                                NombreCampo = kvp.Key,
                                Valor = kvp.Value
                            });
                        }
                    }
                }

                // Ordenar por IdCampo
                camposExtraidos = camposExtraidos.OrderBy(c => c.IdCampo).ToList();

                return Ok(new GenericResponse<List<CampoExtraidoIA>>
                {
                    Success = true,
                    Message = "Documento procesado correctamente",
                    Data = camposExtraidos
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<List<CampoExtraidoIA>>
                {
                    Success = false,
                    Message = $"Error al procesar el documento: {ex.Message}"
                });
            }
        }

        [HttpPost("PreguardaDocumento")]
        public async Task<ActionResult<GenericResponse<long>>> PreguardaDocumento([FromBody] GenericAdRequest<AdDocumentos> request)
        {
            try
            {
                // Validar IdCliente
                if (string.IsNullOrWhiteSpace(request.IdCliente))
                {
                    return BadRequest(new GenericResponse<long>
                    {
                        Success = false,
                        Message = "IdCliente es requerido"
                    });
                }

                // Validar IdTipoDocumentoVucem
                if (!request.IdTipoDocumentoVucem.HasValue)
                {
                    return BadRequest(new GenericResponse<long>
                    {
                        Success = false,
                        Message = "IdTipoDocumentoVucem es requerido"
                    });
                }

                // Validar Data
                if (request.Data == null)
                {
                    return BadRequest(new GenericResponse<long>
                    {
                        Success = false,
                        Message = "Los datos del documento son requeridos"
                    });
                }

                // Validar IdMotorConfigHeader
                if (request.Data.IdMotorConfigHeader == 0)
                {
                    return BadRequest(new GenericResponse<long>
                    {
                        Success = false,
                        Message = "IdMotorConfigHeader es requerido"
                    });
                }

                // Obtener usuario del token
                var tokenLogin = HttpContext.GetTokenLoginDTO();
                if (tokenLogin == null || string.IsNullOrWhiteSpace(tokenLogin.ShortUserName))
                {
                    return Unauthorized(new GenericResponse<long>
                    {
                        Success = false,
                        Message = "No se pudo obtener la información del usuario autenticado"
                    });
                }

                // Construir el documento para preguardar
                var documento = new AdDocumentos
                {
                    IdCliente = request.IdCliente,
                    IdTipoDocumentoVucem = request.IdTipoDocumentoVucem.Value,
                    IdMotorConfigHeader = request.Data.IdMotorConfigHeader,
                    IdEstatus = (int)AdDocumentoEstatus.Registro,
                    FechaVigenciaInicio = request.Data.FechaVigenciaInicio,
                    FechaVigenciaFin = request.Data.FechaVigenciaFin,
                    Observaciones = request.Data.Observaciones,
                    ComentarioRechazo = request.Data.ComentarioRechazo,
                    CreadoPor = tokenLogin.ShortUserName,
                    // No incluir Archivo ni Campos (es preguardado)
                    Archivo = null,
                    Campos = null
                };

                // Guardar el documento SIN validar clasificación (es preguardado)
                var documentoGuardado = await _desarrolloDbService.SaveDocumentoAsync(documento, validarClasificacion: false);

                return Ok(new GenericResponse<long>
                {
                    Success = true,
                    Message = "Documento preguardado correctamente",
                    Data = documentoGuardado.Id
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<long>
                {
                    Success = false,
                    Message = $"Error al preguardar el documento: {ex.Message}"
                });
            }
        }

        [HttpPost("GuardaDocumentoPendienteAprobacion")]
        public async Task<ActionResult<GenericResponse<AdDocumentos>>> GuardaDocumentoPendienteAprobacion([FromBody] GenericAdRequest<AdDocumentos> request)
        {
            try
            {
                // Validar Data
                if (request.Data == null)
                {
                    return BadRequest(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = "Los datos del documento son requeridos"
                    });
                }

                // Validar que el documento tenga Id
                if (request.Data.Id == 0)
                {
                    return BadRequest(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = "El Id del documento es requerido"
                    });
                }

                // Obtener usuario del token
                var tokenLogin = HttpContext.GetTokenLoginDTO();
                if (tokenLogin == null || string.IsNullOrWhiteSpace(tokenLogin.ShortUserName))
                {
                    return Unauthorized(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = "No se pudo obtener la información del usuario autenticado"
                    });
                }

                // Obtener documento existente
                var documentoExistente = await _desarrolloDbService.GetDocumentoByIdAsync(request.Data.Id);
                if (documentoExistente == null)
                {
                    return NotFound(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = $"No se encontró el documento con Id {request.Data.Id}"
                    });
                }

                // Preparar el documento para guardar
                var documento = request.Data;
                documento.IdEstatus = (int)AdDocumentoEstatus.Pendiente;

                // Si el estatus actual es "Registro", preservar FechaCreacion y CreadoPor
                if (documentoExistente.IdEstatus == (int)AdDocumentoEstatus.Registro)
                {
                    documento.FechaCreacion = documentoExistente.FechaCreacion;
                    documento.CreadoPor = documentoExistente.CreadoPor;
                    // No asignar FechaActualizacion ni ActualizadoPor
                    documento.FechaActualizacion = null;
                    documento.ActualizadoPor = null;
                }
                else
                {
                    // Si el estatus NO es "Registro", preservar FechaCreacion y CreadoPor originales
                    documento.FechaCreacion = documentoExistente.FechaCreacion;
                    documento.CreadoPor = documentoExistente.CreadoPor;
                    // Asignar FechaActualizacion y ActualizadoPor
                    documento.FechaActualizacion = DateTime.Now;
                    documento.ActualizadoPor = tokenLogin.ShortUserName;
                }

                if (documento.Archivo == null)
                {
                    return BadRequest(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = "El documento debe incluir un archivo"
                    });
                }

                var docVucem = await _eDOCS_DbContextServices.GetDocumentoVucemporIdTipoDocumentoVucemAsync(
                    documento.IdTipoDocumentoVucem);
                if (docVucem == null)
                {
                    return BadRequest(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = "No se encontró el tipo de documento VUCEM para generar el nombre eDOCS"
                    });
                }

                documento.Archivo.NombreEdocs = NombreEdocsBuilder.Build(
                    documento.Archivo.NombreArchivo,
                    docVucem.Id_Vucem,
                    DateTime.Now);

                // Respaldo de documento Aws
                var cliente = await _aduasisDbContextServices.GetClienteAsync(documento.IdCliente);
                documento.Archivo.AwsRuta = _fileStorageService.SaveDocumentAws(
                    Convert.FromBase64String(documento.Archivo.DocBase64),
                    documento.Archivo.NombreEdocs,
                    "auditoriDocumentos",
                    cliente.Rfc);

                // Guardar el documento
                var documentoGuardado = await _desarrolloDbService.SaveDocumentoAsync(documento);

                // formatea retorno
                documentoGuardado.MotorConfigHeader = null;
                foreach (var campo in documentoGuardado.Campos ?? Enumerable.Empty<AdDocumentosCampos>())
                {
                    campo.Documento = null;
                }
                foreach (var operacion in documentoGuardado.Operaciones ?? Enumerable.Empty<AdDocumentoOperacion>())
                {
                    operacion.Documento = null;
                }
                if (documentoGuardado.Archivo != null)
                    documentoGuardado.Archivo.Documento = null;
                if (documentoGuardado.IdentificadorGeneral != null)
                    documentoGuardado.IdentificadorGeneral.Documento = null;
                if (documentoGuardado.IdentificadorPartida != null)
                    documentoGuardado.IdentificadorPartida.Documento = null;
                if (documentoGuardado.Permiso != null)
                    documentoGuardado.Permiso.Documento = null;

                return Ok(new GenericResponse<AdDocumentos>
                {
                    Success = true,
                    Message = "Documento guardado correctamente con estatus Pendiente",
                    Data = documentoGuardado
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<AdDocumentos>
                {
                    Success = false,
                    Message = $"Error al guardar el documento: {ex.Message}"
                });
            }
        }

        [HttpPost("AutorizaDocumento")]
        public async Task<ActionResult<GenericResponse<AdDocumentos>>> AutorizaDocumento([FromBody] GenericAdRequest<long> request)
        {
            try
            {
                // Validar Data (IdDocumento)
                if (request.Data == 0)
                {
                    return BadRequest(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = "El Id del documento es requerido"
                    });
                }

                long idDocumento = request.Data;

                // Obtener usuario del token
                var tokenLogin = HttpContext.GetTokenLoginDTO();
                if (tokenLogin == null || string.IsNullOrWhiteSpace(tokenLogin.ShortUserName))
                {
                    return Unauthorized(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = "No se pudo obtener la información del usuario autenticado"
                    });
                }

                // Obtener documento existente
                var documento = await _desarrolloDbService.GetDocumentoByIdAsync(idDocumento);
                if (documento == null)
                {
                    return NotFound(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = $"No se encontró el documento con Id {idDocumento}"
                    });
                }

                var perfilError = await ValidarPerfilAccionCriticaAsync<AdDocumentos>(
                    documento.IdCliente,
                    documento.IdTipoDocumentoVucem,
                    tokenLogin.ShortUserName);
                if (perfilError != null)
                {
                    return perfilError;
                }

                // Validar que el estatus actual sea Pendiente
                if (documento.IdEstatus != (int)AdDocumentoEstatus.Pendiente)
                {
                    return BadRequest(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = $"El documento debe estar en estatus 'Pendiente' para poder ser aprobado. Estatus actual: {documento.IdEstatus}"
                    });
                }

                // Cambiar estatus a Aprobado
                documento.IdEstatus = (int)AdDocumentoEstatus.Aprobado;
                documento.FechaActualizacion = DateTime.Now;
                documento.ActualizadoPor = tokenLogin.ShortUserName;

                // Guardar documento actualizado
                var documentoGuardado = await _desarrolloDbService.SaveDocumentoAsync(documento);

                // Guardar aprobación (IdResultado = 1 para Aprobado)
                await _desarrolloDbService.SaveAprobacionAsync(
                    idDocumento,
                    1, // IdResultado: 1 = Aprobado
                    null, // Motivo no requerido para aprobación
                    tokenLogin.ShortUserName);

                // Guardar evento en bitácora
                await _desarrolloDbService.SaveBitacoraEventoAsync(
                    idDocumento,
                    AdEventos.DOC_APROBADO,
                    "Documento aprobado exitosamente",
                    null,
                    tokenLogin.ShortUserName);

                // Limpiar referencias circulares para evitar problemas de serialización
                documentoGuardado.MotorConfigHeader = null;
                foreach (var campo in documentoGuardado.Campos ?? Enumerable.Empty<AdDocumentosCampos>())
                {
                    campo.Documento = null;
                }
                foreach (var operacion in documentoGuardado.Operaciones ?? Enumerable.Empty<AdDocumentoOperacion>())
                {
                    operacion.Documento = null;
                }
                if (documentoGuardado.Archivo != null)
                    documentoGuardado.Archivo.Documento = null;
                if (documentoGuardado.IdentificadorGeneral != null)
                    documentoGuardado.IdentificadorGeneral.Documento = null;
                if (documentoGuardado.IdentificadorPartida != null)
                    documentoGuardado.IdentificadorPartida.Documento = null;
                if (documentoGuardado.Permiso != null)
                    documentoGuardado.Permiso.Documento = null;

                return Ok(new GenericResponse<AdDocumentos>
                {
                    Success = true,
                    Message = "Documento aprobado correctamente",
                    Data = documentoGuardado
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<AdDocumentos>
                {
                    Success = false,
                    Message = $"Error al autorizar el documento: {ex.Message}"
                });
            }
        }

        [HttpPost("RechazarDocumento")]
        public async Task<ActionResult<GenericResponse<AdDocumentos>>> RechazarDocumento([FromBody] GenericAdRequest<RechazarDocumentoRequest> request)
        {
            try
            {
                // Validar Data
                if (request.Data == null)
                {
                    return BadRequest(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = "Los datos del rechazo son requeridos"
                    });
                }

                // Validar IdDocumento
                if (request.Data.IdDocumento == 0)
                {
                    return BadRequest(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = "El Id del documento es requerido"
                    });
                }

                long idDocumento = request.Data.IdDocumento;

                // Validar motivo de rechazo
                if (string.IsNullOrWhiteSpace(request.Data.MotivoRechazo))
                {
                    return BadRequest(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = "El motivo de rechazo es requerido"
                    });
                }

                // Obtener usuario del token
                var tokenLogin = HttpContext.GetTokenLoginDTO();
                if (tokenLogin == null || string.IsNullOrWhiteSpace(tokenLogin.ShortUserName))
                {
                    return Unauthorized(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = "No se pudo obtener la información del usuario autenticado"
                    });
                }

                // Obtener documento existente
                var documento = await _desarrolloDbService.GetDocumentoByIdAsync(idDocumento);
                if (documento == null)
                {
                    return NotFound(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = $"No se encontró el documento con Id {idDocumento}"
                    });
                }

                var perfilError = await ValidarPerfilAccionCriticaAsync<AdDocumentos>(
                    documento.IdCliente,
                    documento.IdTipoDocumentoVucem,
                    tokenLogin.ShortUserName);
                if (perfilError != null)
                {
                    return perfilError;
                }

                // Validar que el estatus actual sea Pendiente
                if (documento.IdEstatus != (int)AdDocumentoEstatus.Pendiente)
                {
                    return BadRequest(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = $"El documento debe estar en estatus 'Pendiente' para poder ser rechazado. Estatus actual: {documento.IdEstatus}"
                    });
                }

                // Cambiar estatus a Rechazado
                documento.IdEstatus = (int)AdDocumentoEstatus.Rechazado;
                documento.ComentarioRechazo = request.Data.MotivoRechazo;
                documento.FechaActualizacion = DateTime.Now;
                documento.ActualizadoPor = tokenLogin.ShortUserName;

                // Guardar documento actualizado
                var documentoGuardado = await _desarrolloDbService.SaveDocumentoAsync(documento);

                // Guardar rechazo (IdResultado = 2 para Rechazado)
                await _desarrolloDbService.SaveAprobacionAsync(
                    idDocumento,
                    2, // IdResultado: 2 = Rechazado
                    request.Data.MotivoRechazo, // Motivo de rechazo
                    tokenLogin.ShortUserName);

                // Guardar evento en bitácora
                await _desarrolloDbService.SaveBitacoraEventoAsync(
                    idDocumento,
                    AdEventos.DOC_RECHAZADO,
                    $"Documento rechazado. Motivo: {request.Data.MotivoRechazo}",
                    null,
                    tokenLogin.ShortUserName);

                // Limpiar referencias circulares para evitar problemas de serialización
                documentoGuardado.MotorConfigHeader = null;
                foreach (var campo in documentoGuardado.Campos ?? Enumerable.Empty<AdDocumentosCampos>())
                {
                    campo.Documento = null;
                }
                foreach (var operacion in documentoGuardado.Operaciones ?? Enumerable.Empty<AdDocumentoOperacion>())
                {
                    operacion.Documento = null;
                }
                if (documentoGuardado.Archivo != null)
                    documentoGuardado.Archivo.Documento = null;
                if (documentoGuardado.IdentificadorGeneral != null)
                    documentoGuardado.IdentificadorGeneral.Documento = null;
                if (documentoGuardado.IdentificadorPartida != null)
                    documentoGuardado.IdentificadorPartida.Documento = null;
                if (documentoGuardado.Permiso != null)
                    documentoGuardado.Permiso.Documento = null;

                return Ok(new GenericResponse<AdDocumentos>
                {
                    Success = true,
                    Message = "Documento rechazado correctamente",
                    Data = documentoGuardado
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<AdDocumentos>
                {
                    Success = false,
                    Message = $"Error al rechazar el documento: {ex.Message}"
                });
            }
        }

        [HttpPost("EliminarDocumento")]
        public async Task<ActionResult<GenericResponse<AdDocumentos>>> EliminarDocumento([FromBody] GenericAdRequest<long> request)
        {
            try
            {
                // Validar Data (IdDocumento)
                if (request.Data == 0)
                {
                    return BadRequest(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = "El Id del documento es requerido"
                    });
                }

                long idDocumento = request.Data;

                // Obtener usuario del token
                var tokenLogin = HttpContext.GetTokenLoginDTO();
                if (tokenLogin == null || string.IsNullOrWhiteSpace(tokenLogin.ShortUserName))
                {
                    return Unauthorized(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = "No se pudo obtener la información del usuario autenticado"
                    });
                }

                // Obtener documento existente
                var documento = await _desarrolloDbService.GetDocumentoByIdAsync(idDocumento);
                if (documento == null)
                {
                    return NotFound(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = $"No se encontró el documento con Id {idDocumento}"
                    });
                }

                var perfilError = await ValidarPerfilAccionCriticaAsync<AdDocumentos>(
                    documento.IdCliente,
                    documento.IdTipoDocumentoVucem,
                    tokenLogin.ShortUserName);
                if (perfilError != null)
                {
                    return perfilError;
                }

                // Validar que el documento no esté ya eliminado
                if (documento.IdEstatus == (int)AdDocumentoEstatus.Eliminado)
                {
                    return BadRequest(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = "El documento ya está eliminado"
                    });
                }

                // Cambiar estatus a Eliminado
                documento.IdEstatus = (int)AdDocumentoEstatus.Eliminado;
                documento.FechaActualizacion = DateTime.Now;
                documento.ActualizadoPor = tokenLogin.ShortUserName;

                // Guardar documento actualizado
                var documentoGuardado = await _desarrolloDbService.SaveDocumentoAsync(documento, false);

                // Guardar evento en bitácora
                await _desarrolloDbService.SaveBitacoraEventoAsync(
                    idDocumento,
                    AdEventos.DOC_CAMBIO_ESTATUS,
                    "Documento eliminado",
                    null,
                    tokenLogin.ShortUserName);

                // Limpiar referencias circulares para evitar problemas de serialización
                documentoGuardado.MotorConfigHeader = null;
                foreach (var campo in documentoGuardado.Campos ?? Enumerable.Empty<AdDocumentosCampos>())
                {
                    campo.Documento = null;
                }
                foreach (var operacion in documentoGuardado.Operaciones ?? Enumerable.Empty<AdDocumentoOperacion>())
                {
                    operacion.Documento = null;
                }
                if (documentoGuardado.Archivo != null)
                    documentoGuardado.Archivo.Documento = null;
                if (documentoGuardado.IdentificadorGeneral != null)
                    documentoGuardado.IdentificadorGeneral.Documento = null;
                if (documentoGuardado.IdentificadorPartida != null)
                    documentoGuardado.IdentificadorPartida.Documento = null;
                if (documentoGuardado.Permiso != null)
                    documentoGuardado.Permiso.Documento = null;

                return Ok(new GenericResponse<AdDocumentos>
                {
                    Success = true,
                    Message = "Documento eliminado correctamente",
                    Data = documentoGuardado
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<AdDocumentos>
                {
                    Success = false,
                    Message = $"Error al eliminar el documento: {ex.Message}"
                });
            }
        }

        [HttpPost("ObtenerDocumentos")]
        public async Task<ActionResult<GenericResponse<List<CspAdDocumentosPorEstatus>>>> ObtenerDocumentos([FromBody] GenericAdRequest<int> request)
        {
            try
            {
                // Validar IdCliente
                if (string.IsNullOrWhiteSpace(request.IdCliente))
                {
                    return BadRequest(new GenericResponse<List<CspAdDocumentosPorEstatus>>
                    {
                        Success = false,
                        Message = "IdCliente es requerido"
                    });
                }

                // Obtener usuario del token
                var tokenLogin = HttpContext.GetTokenLoginDTO();
                if (tokenLogin == null || string.IsNullOrWhiteSpace(tokenLogin.ShortUserName))
                {
                    return Unauthorized(new GenericResponse<List<CspAdDocumentosPorEstatus>>
                    {
                        Success = false,
                        Message = "No se pudo obtener la información del usuario autenticado"
                    });
                }

                int idEstatus = request.Data;

                var documentos = await _desarrolloDbService.GetDocumentosPorEstatusAsync(request.IdCliente, idEstatus);

                var usuario = await _aduasisDbContextServices.GetUsuarioPorUsuauarioAsync(tokenLogin.ShortUserName);
                var tipos = documentos
                    .Select(d => d.IdTipoDocumentoVucem)
                    .Distinct()
                    .ToList();
                var perfiles = await _desarrolloDbService.GetPerfilesCargaPorClienteAsync(request.IdCliente, tipos);

                foreach (var doc in documentos)
                {
                    if (perfiles.TryGetValue(doc.IdTipoDocumentoVucem, out var perfilCarga))
                    {
                        doc.PuedeAccionCritica = AdPerfilCargaMotor.UsuarioPuedeAccionCritica(
                            perfilCarga,
                            usuario?.IdClase);
                    }
                    else
                    {
                        doc.PuedeAccionCritica = false;
                    }
                }

                return Ok(new GenericResponse<List<CspAdDocumentosPorEstatus>>
                {
                    Success = true,
                    Message = "Documentos obtenidos correctamente",
                    Data = documentos
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<List<CspAdDocumentosPorEstatus>>
                {
                    Success = false,
                    Message = $"Error al obtener los documentos: {ex.Message}"
                });
            }
        }

        [HttpPost("ObtenerDocumentoPorId")]
        public async Task<ActionResult<GenericResponse<AdDocumentos>>> ObtenerDocumentoPorId([FromBody] GenericAdRequest<long> request)
        {
            try
            {
                // Validar Data (IdDocumento)
                if (request.Data == 0)
                {
                    return BadRequest(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = "El Id del documento es requerido"
                    });
                }

                long idDocumento = request.Data;

                // Obtener usuario del token
                var tokenLogin = HttpContext.GetTokenLoginDTO();
                if (tokenLogin == null || string.IsNullOrWhiteSpace(tokenLogin.ShortUserName))
                {
                    return Unauthorized(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = "No se pudo obtener la información del usuario autenticado"
                    });
                }

                // Obtener documento por ID con todas sus relaciones
                var documento = await _desarrolloDbService.GetDocumentoByIdAsync(idDocumento);
                                
                if (documento == null)
                {
                    return NotFound(new GenericResponse<AdDocumentos>
                    {
                        Success = false,
                        Message = $"No se encontró el documento con Id {idDocumento}"
                    });
                }

                // Recuperamos motor header para obtener la configuración
                documento.MotorConfigHeader = await _desarrolloDbService.GetMotorConfigHeaderConDetalleAsync(documento.IdCliente, documento.IdTipoDocumentoVucem);

                documento.Operaciones = await _desarrolloDbService.GetDocumentoOperacionesConEdocumentAsync(idDocumento);

                // Limpiar referencias circulares para evitar problemas de serialización
                foreach (var campo in documento.Campos ?? Enumerable.Empty<AdDocumentosCampos>())
                {
                    campo.Documento = null;
                }
                foreach (var operacion in documento.Operaciones ?? Enumerable.Empty<AdDocumentoOperacion>())
                {
                    operacion.Documento = null;
                }
                if (documento.Archivo != null)
                    documento.Archivo.Documento = null;
                if (documento.IdentificadorGeneral != null)
                    documento.IdentificadorGeneral.Documento = null;
                if (documento.IdentificadorPartida != null)
                    documento.IdentificadorPartida.Documento = null;
                if (documento.Permiso != null)
                    documento.Permiso.Documento = null;

                if (documento.MotorConfigHeader != null)
                {
                    foreach (var detalle in documento.MotorConfigHeader.Detalles ?? Enumerable.Empty<AdMotorConfigDetalle>())
                    {
                        detalle.MotorConfigHeader = null;
                    }
                }

                return Ok(new GenericResponse<AdDocumentos>
                {
                    Success = true,
                    Message = "Documento obtenido correctamente",
                    Data = documento
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<AdDocumentos>
                {
                    Success = false,
                    Message = $"Error al obtener el documento: {ex.Message}"
                });
            }
        }

        [HttpPost("ValidarDocumentoVigenteAprobado")]
        public async Task<ActionResult<GenericResponse<bool>>> ValidarDocumentoVigenteAprobado([FromBody] GenericAdRequest<object> request)
        {
            try
            {
                // Validar IdCliente
                if (string.IsNullOrWhiteSpace(request.IdCliente))
                {
                    return BadRequest(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "IdCliente es requerido"
                    });
                }

                // Validar IdTipoDocumentoVucem
                if (!request.IdTipoDocumentoVucem.HasValue)
                {
                    return BadRequest(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "IdTipoDocumentoVucem es requerido"
                    });
                }

                // Obtener usuario del token
                var tokenLogin = HttpContext.GetTokenLoginDTO();
                if (tokenLogin == null || string.IsNullOrWhiteSpace(tokenLogin.ShortUserName))
                {
                    return Unauthorized(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "No se pudo obtener la información del usuario autenticado"
                    });
                }

                // Validar si existe documento vigente aprobado
                bool existeDocumento = await _desarrolloDbService.ExisteDocumentoVigenteAprobadoAsync(
                    request.IdCliente, 
                    request.IdTipoDocumentoVucem.Value);

                return Ok(new GenericResponse<bool>
                {
                    Success = true,
                    Message = existeDocumento 
                        ? "Existe un documento vigente y aprobado para este cliente y tipo de documento" 
                        : "No existe un documento vigente y aprobado para este cliente y tipo de documento",
                    Data = existeDocumento
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<bool>
                {
                    Success = false,
                    Message = $"Error al validar documento vigente aprobado: {ex.Message}"
                });
            }
        }

        [HttpPost("AltaAsociacionOperacion")]
        public async Task<ActionResult<GenericResponse<InsertarDatosPedimentoResultDto>>> AltaAsociacionOperacion([FromBody] GenericAdRequest<AsociacionOperacionRequest> request)
        {
            try
            {
                // Validar IdCliente
                if (string.IsNullOrWhiteSpace(request.IdCliente))
                {
                    return BadRequest(new GenericResponse<InsertarDatosPedimentoResultDto>
                    {
                        Success = false,
                        Message = "IdCliente es requerido"
                    });
                }

                if (request.Data == null)
                {
                    return BadRequest(new GenericResponse<InsertarDatosPedimentoResultDto>
                    {
                        Success = false,
                        Message = "Los datos de la asociación son requeridos"
                    });
                }

                if (request.Data.IdDocumento <= 0)
                {
                    return BadRequest(new GenericResponse<InsertarDatosPedimentoResultDto>
                    {
                        Success = false,
                        Message = "IdDocumento es requerido"
                    });
                }

                if (string.IsNullOrWhiteSpace(request.Data.IdReferencia))
                {
                    return BadRequest(new GenericResponse<InsertarDatosPedimentoResultDto>
                    {
                        Success = false,
                        Message = "IdReferencia es requerido"
                    });
                }

                /*if (request.Data.IdRectificacion < 0)
                {
                    return BadRequest(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "IdRectificacion debe ser mayor o igual a cero",
                        Data = false
                    });
                }

                if (string.IsNullOrWhiteSpace(request.Data.Pedimento))
                {
                    return BadRequest(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "Pedimento es requerido",
                        Data = false
                    });
                }*/

                var tokenLogin = HttpContext.GetTokenLoginDTO();
                if (tokenLogin == null || string.IsNullOrWhiteSpace(tokenLogin.ShortUserName))
                {
                    return Unauthorized(new GenericResponse<InsertarDatosPedimentoResultDto>
                    {
                        Success = false,
                        Message = "No se pudo obtener la información del usuario autenticado"
                    });
                }

                var documento = await _desarrolloDbService.GetDocumentoByIdAsync(request.Data.IdDocumento);
                if (documento == null)
                {
                    return BadRequest(new GenericResponse<InsertarDatosPedimentoResultDto>
                    {
                        Success = false,
                        Message = "No se encontró el documento"
                    });
                }

                var perfilError = await ValidarPerfilAccionCriticaAsync<InsertarDatosPedimentoResultDto>(
                    documento.IdCliente,
                    documento.IdTipoDocumentoVucem,
                    tokenLogin.ShortUserName);
                if (perfilError != null)
                {
                    return perfilError;
                }

                var docVucem = await _eDOCS_DbContextServices.GetDocumentoVucemporIdTipoDocumentoVucemAsync(documento.IdTipoDocumentoVucem);
                if (docVucem == null)
                {
                    return BadRequest(new GenericResponse<InsertarDatosPedimentoResultDto>
                    {
                        Success = false,
                        Message = "No se encontró la configuración de documento VUCEM para enviar a eDOCS"
                    });
                }

                var archivo = documento.Archivo;
                if (archivo == null)
                {
                    return BadRequest(new GenericResponse<InsertarDatosPedimentoResultDto>
                    {
                        Success = false,
                        Message = "El documento no tiene un archivo asociado"
                    });
                }

                string rutaRemota = archivo.AwsRuta.Replace("%20", " ");

                var uri = new Uri(archivo.AwsRuta);
                var path = uri.AbsolutePath.TrimStart('/');
                var pathremotofull = path.Substring(0, path.LastIndexOf('/') + 1);

                string nombredocurl = rutaRemota.Split('?')[0].Split('/')[rutaRemota.Split('?')[0].Split('/').Length - 1];
                string serverurl = rutaRemota.Split('?')[0].Replace(pathremotofull + nombredocurl, "");
                string ruta_remota = rutaRemota;
                if (ruta_remota.Contains("?"))
                    ruta_remota = ruta_remota.Split('?')[0];

                string procesoEdocs = "3"; // proceso de trádico | "1"; // proceso de pedimento
                var traficos = new List<CspAdGetTraficoPorReferencia>();
                if (request.Data.IdRectificacion.HasValue)
                {
                    // traficos = await _desarrolloDbService.GetTraficoPorReferenciaRectificacionAsync(request.Data.IdReferencia, request.Data.IdRectificacion.Value);
                    traficos.Add(new CspAdGetTraficoPorReferencia { IdTrafico = request.Data.IdReferencia + "_" + request.Data.IdRectificacion.Value });
                    procesoEdocs = "1";
                }
                else
                {
                    traficos.Add(new CspAdGetTraficoPorReferencia { IdTrafico = request.Data.IdReferencia });
                    procesoEdocs = "3";
                }

                InsertarDatosPedimentoResultDto transferenciaResult;
                if (request.Data.AfectaOperacion)
                {
                    try
                    {
                        transferenciaResult = await _desarrolloDbService.InsertarDatosPedimentoV2Async(
                            documento.Id,
                            request.Data.IdReferencia,
                            request.Data.IdRectificacion,
                            request.Data.Pedimento);
                    }
                    catch (Exception ex)
                    {
                        return Ok(new GenericResponse<InsertarDatosPedimentoResultDto>
                        {
                            Success = false,
                            Message = $"No se pudo completar la transferencia de datos al pedimento: {ex.Message}",
                            Data = new InsertarDatosPedimentoResultDto
                            {
                                Resultado = false,
                                MensajeEjecucion = string.Empty
                            }
                        });
                    }

                    if (!transferenciaResult.Resultado)
                    {
                        return Ok(new GenericResponse<InsertarDatosPedimentoResultDto>
                        {
                            Success = false,
                            Message = "La transferencia de datos a pedimento o tráfico no afectó registros en partida o permisos.",
                            Data = transferenciaResult
                        });
                    }
                }
                else
                {
                    transferenciaResult = new InsertarDatosPedimentoResultDto
                    {
                        Resultado = true,
                        MensajeEjecucion = string.Empty
                    };
                }

                var usuarioEdocs = await _aduasisDbContextServices.GetIdUsuarioEdocsAsync(tokenLogin.ShortUserName);

                var operacion = new AdDocumentoOperacion
                {
                    IdDocumento = request.Data.IdDocumento,
                    id_referencia = request.Data.IdReferencia,
                    id_rectificacion = request.Data.IdRectificacion,
                    pedimento = request.Data.Pedimento,
                    AsociadoPor = tokenLogin.ShortUserName
                };

                await _desarrolloDbService.SaveDocumentoOperacionAsync(operacion);

                await _desarrolloDbService.SaveBitacoraEventoAsync(
                    request.Data.IdDocumento,
                    AdEventos.DOC_ASOCIADO_OPERACION,
                    $"Documento asociado a la referencia {request.Data.IdReferencia} (rectificación {request.Data.IdRectificacion}, pedimento {request.Data.Pedimento})",
                    null,
                    tokenLogin.ShortUserName);

                foreach (var trafico in traficos)
                {
                    var idArchivoEdocs = await _eDOCS_DbContextServices.InsertEdocsAsync(
                        trafico.IdTrafico,
                        path,
                        ruta_remota,
                        serverurl,
                        rutaRemota,
                        usuarioEdocs,
                        docVucem.Id_DocumentoVucem.ToString(),
                        docVucem.Id_Vucem.ToString(),
                        "",
                        "",
                        procesoEdocs);

                    await _desarrolloDbService.SaveRelDocumentoEdocAsync(
                        request.Data.IdDocumento,
                        idArchivoEdocs,
                        tokenLogin.ShortUserName);
                }

                if(documento.IdEstatus != (int)AdDocumentoEstatus.VinculadoOperacion && documento.IdEstatus != (int)AdDocumentoEstatus.DigitalizadoEdocs)
                {
                    documento.IdEstatus = (int)AdDocumentoEstatus.VinculadoOperacion;
                    documento.FechaActualizacion = DateTime.Now;
                    documento.ActualizadoPor = tokenLogin.ShortUserName;
                    await _desarrolloDbService.SaveDocumentoAsync(documento, false);
                }

                await _desarrolloDbService.SaveBitacoraEventoAsync(
                        request.Data.IdDocumento,
                        AdEventos.DOC_ENVIO_EDOCS,
                        "Documento enviado a eDOCS",
                        null,
                        tokenLogin.ShortUserName);

                return Ok(new GenericResponse<InsertarDatosPedimentoResultDto>
                {
                    Success = true,
                    Message = "Asociación registrada correctamente",
                    Data = transferenciaResult
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<InsertarDatosPedimentoResultDto>
                {
                    Success = false,
                    Message = $"Error al procesar la asociación del documento: {ex.Message}"
                });
            }
        }

        [HttpPost("ObtenerSellosVucemDisponibles")]
        public async Task<ActionResult<GenericResponse<VucemSellosLookupDto>>> ObtenerSellosVucemDisponibles(
            [FromBody] GenericAdRequest<OperacionVucemRequest> request)
        {
            try
            {
                if (request.Data == null || string.IsNullOrWhiteSpace(request.Data.IdReferencia))
                {
                    return BadRequest(new GenericResponse<VucemSellosLookupDto>
                    {
                        Success = false,
                        Message = "IdReferencia es requerido"
                    });
                }

                var pedimento = await _desarrolloDbService.GetPatenteRfcClienteByRelOperacionAsync(
                    request.Data.IdReferencia,
                    request.Data.IdRectificacion);

                if (pedimento == null || string.IsNullOrWhiteSpace(pedimento.RfcCliente))
                {
                    return BadRequest(new GenericResponse<VucemSellosLookupDto>
                    {
                        Success = false,
                        Message = "No se encontró RFC o patente para la operación"
                    });
                }

                var sellosRfc = await _eDOCS_DbContextServices.GetVuceSellosPorRfcAsync(pedimento.RfcCliente);

                return Ok(new GenericResponse<VucemSellosLookupDto>
                {
                    Success = true,
                    Message = sellosRfc == null
                        ? "No se encontró una configuración de sellos válida para el RFC del importador."
                        : "Sellos obtenidos correctamente",
                    Data = new VucemSellosLookupDto
                    {
                        IdSelloCliente = sellosRfc?.IdSelloCliente ?? 0,
                        IdSelloAduana = sellosRfc?.IdSelloAduana ?? 0,
                        Patente = pedimento.Patente,
                        RfcCliente = pedimento.RfcCliente,
                        RfcPatente = pedimento.RfcPatente
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<VucemSellosLookupDto>
                {
                    Success = false,
                    Message = $"Error al obtener sellos VUCEM: {ex.Message}"
                });
            }
        }

        [HttpPost("EnviarDocumentoVucem")]
        [RequestTimeout("VucemEnvio")]
        public async Task<ActionResult<GenericResponse<EnvioVucemResultDto>>> EnviarDocumentoVucem(
            [FromBody] GenericAdRequest<EnviarDocumentoVucemRequest> request)
        {
            try
            {
                if (request.Data == null)
                {
                    return BadRequest(new GenericResponse<EnvioVucemResultDto>
                    {
                        Success = false,
                        Message = "Los datos del envío son requeridos"
                    });
                }

                if (request.Data.IdDocumento <= 0)
                {
                    return BadRequest(new GenericResponse<EnvioVucemResultDto>
                    {
                        Success = false,
                        Message = "IdDocumento es requerido"
                    });
                }

                if (string.IsNullOrWhiteSpace(request.Data.IdReferencia))
                {
                    return BadRequest(new GenericResponse<EnvioVucemResultDto>
                    {
                        Success = false,
                        Message = "IdReferencia es requerido"
                    });
                }

                if (string.IsNullOrWhiteSpace(request.Data.OrigenSello))
                {
                    return BadRequest(new GenericResponse<EnvioVucemResultDto>
                    {
                        Success = false,
                        Message = "OrigenSello es requerido (Cliente o AgenteAduanal)"
                    });
                }

                var origenSello = request.Data.OrigenSello.Trim();
                if (!origenSello.Equals(OrigenSelloVucem.Cliente, StringComparison.OrdinalIgnoreCase) &&
                    !origenSello.Equals(OrigenSelloVucem.AgenteAduanal, StringComparison.OrdinalIgnoreCase))
                {
                    return BadRequest(new GenericResponse<EnvioVucemResultDto>
                    {
                        Success = false,
                        Message = "OrigenSello no válido. Use Cliente o AgenteAduanal"
                    });
                }

                var tokenLogin = HttpContext.GetTokenLoginDTO();
                if (tokenLogin == null || string.IsNullOrWhiteSpace(tokenLogin.ShortUserName))
                {
                    return Unauthorized(new GenericResponse<EnvioVucemResultDto>
                    {
                        Success = false,
                        Message = "No se pudo obtener la información del usuario autenticado"
                    });
                }

                if (string.IsNullOrEmpty(request.Data.CorreoElectronico))
                {
                    var usuario = await _aduasisDbContextServices.GetUsuarioPorUsuauarioAsync(tokenLogin.ShortUserName);
                    request.Data.CorreoElectronico = usuario?.CorreoElectronico ?? "mxochipa.mty@aduax.com";
                }

                var pendiente = await _desarrolloDbService.OperacionPendienteEnvioVucemAsync(
                    request.Data.IdDocumento,
                    request.Data.IdReferencia,
                    request.Data.IdRectificacion);

                if (!pendiente)
                {
                    return BadRequest(new GenericResponse<EnvioVucemResultDto>
                    {
                        Success = false,
                        Message = "La operación ya tiene eDocument válido o número de operación; no aplica envío o reintento VUCEM"
                    });
                }

                var rel = await _desarrolloDbService.GetRelDocumentoEdocPorOperacionAsync(
                    request.Data.IdDocumento,
                    request.Data.IdReferencia,
                    request.Data.IdRectificacion);

                if (rel == null)
                {
                    return BadRequest(new GenericResponse<EnvioVucemResultDto>
                    {
                        Success = false,
                        Message = "No existe relación documento-eDOCS para esta operación (referencia/rectificación)"
                    });
                }

                var pedimento = await _desarrolloDbService.GetPatenteRfcClienteByRelOperacionAsync(
                    request.Data.IdReferencia,
                    request.Data.IdRectificacion);

                if (pedimento == null || string.IsNullOrWhiteSpace(pedimento.RfcCliente))
                {
                    return BadRequest(new GenericResponse<EnvioVucemResultDto>
                    {
                        Success = false,
                        Message = "No se encontró RFC del importador para la operación"
                    });
                }

                int idSello = await ResolverIdSelloAsync(origenSello, pedimento.RfcCliente, pedimento.Patente);
                if (idSello <= 0)
                {
                    return BadRequest(new GenericResponse<EnvioVucemResultDto>
                    {
                        Success = false,
                        Message = "No se pudo resolver un sello válido para el envío"
                    });
                }

                await _desarrolloDbService.UpdateRelDocumentoEdocIdSelloEdocAsync(rel.Id, idSello);

                var rfcConsulta = ResolverRfcConsultaVucem(origenSello, pedimento);
                if (string.IsNullOrWhiteSpace(rfcConsulta))
                {
                    return BadRequest(new GenericResponse<EnvioVucemResultDto>
                    {
                        Success = false,
                        Message = "No se pudo determinar el RFC de consulta para el envío VUCEM"
                    });
                }

                var archivo = await _desarrolloDbService.GetDocumentoByIdArchivosAsync(request.Data.IdDocumento);
                if (archivo == null || string.IsNullOrWhiteSpace(archivo.NombreArchivo))
                {
                    return BadRequest(new GenericResponse<EnvioVucemResultDto>
                    {
                        Success = false,
                        Message = "El documento no tiene un archivo con nombre válido para generar NombreEdocs"
                    });
                }

                var documentoTipo = await _desarrolloDbService.GetDocumentoByIdAsync(request.Data.IdDocumento);
                if (documentoTipo == null)
                {
                    return BadRequest(new GenericResponse<EnvioVucemResultDto>
                    {
                        Success = false,
                        Message = "No se encontró el documento"
                    });
                }

                var docVucem = await _eDOCS_DbContextServices.GetDocumentoVucemporIdTipoDocumentoVucemAsync(
                    documentoTipo.IdTipoDocumentoVucem);
                if (docVucem == null)
                {
                    return BadRequest(new GenericResponse<EnvioVucemResultDto>
                    {
                        Success = false,
                        Message = "No se encontró el tipo de documento VUCEM para generar NombreEdocs"
                    });
                }

                string nombreEdocs;
                try
                {
                    nombreEdocs = NombreEdocsBuilder.Build(
                        archivo.NombreArchivo,
                        docVucem.Id_Vucem,
                        DateTime.Now);
                }
                catch (Exception ex) when (ex is ArgumentException or InvalidOperationException)
                {
                    return BadRequest(new GenericResponse<EnvioVucemResultDto>
                    {
                        Success = false,
                        Message = ex.Message
                    });
                }

                await _desarrolloDbService.UpdateDocumentoArchivoNombreEdocsAsync(
                    request.Data.IdDocumento,
                    nombreEdocs);

                EnvioVucemResultDto resultadoVucem;
                try
                {
                    resultadoVucem = await _vucemApiClient.EnviarArchivoVucemAsync(
                        rel.IdArchivo,
                        idSello,
                        rfcConsulta,
                        nombreEdocs,
                        request.Data.CorreoElectronico);
                }
                catch (VucemApiException ex) when (ex.IsTimeout || ex.IsGatewayError)
                {
                    return StatusCode(StatusCodes.Status504GatewayTimeout, new GenericResponse<EnvioVucemResultDto>
                    {
                        Success = false,
                        Message = ex.Message
                    });
                }
                catch (VucemApiException ex)
                {
                    return BadRequest(new GenericResponse<EnvioVucemResultDto>
                    {
                        Success = false,
                        Message = ex.Message
                    });
                }

                var documento = await _desarrolloDbService.GetDocumentoByIdAsync(request.Data.IdDocumento);
                if (documento != null && resultadoVucem.EsExitoso)
                {
                    documento.IdEstatus = (int)AdDocumentoEstatus.DigitalizadoEdocs;
                    documento.FechaActualizacion = DateTime.Now;
                    documento.ActualizadoPor = tokenLogin.ShortUserName;
                    await _desarrolloDbService.SaveDocumentoAsync(documento, false);

                    await _desarrolloDbService.SaveBitacoraEventoAsync(
                        request.Data.IdDocumento,
                        AdEventos.DOC_DIGITALIZADO,
                        $"Envío VUCEM exitoso. Número operación: {resultadoVucem.NumeroOperacion}",
                        null,
                        tokenLogin.ShortUserName);
                }
                else if (documento != null && !resultadoVucem.EsExitoso)
                {
                    await _desarrolloDbService.SaveBitacoraEventoAsync(
                        request.Data.IdDocumento,
                        AdEventos.DOC_ERROR_EDOCS,
                        $"Envío VUCEM falló: {resultadoVucem.Mensaje}",
                        null,
                        tokenLogin.ShortUserName);
                }

                return Ok(new GenericResponse<EnvioVucemResultDto>
                {
                    Success = resultadoVucem.EsExitoso,
                    Message = resultadoVucem.Mensaje ?? (resultadoVucem.EsExitoso
                        ? "Envío VUCEM registrado correctamente"
                        : "El envío VUCEM no fue exitoso"),
                    Data = resultadoVucem
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<EnvioVucemResultDto>
                {
                    Success = false,
                    Message = $"Error al enviar documento a VUCEM: {ex.Message}"
                });
            }
        }

        [HttpPost("EliminarAsociacionOperacion")]
        public async Task<ActionResult<GenericResponse<bool>>> EliminarAsociacionOperacion(
            [FromBody] GenericAdRequest<EliminarAsociacionOperacionRequest> request)
        {
            try
            {
                if (request.Data == null)
                {
                    return BadRequest(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "Los datos de la eliminación son requeridos",
                        Data = false
                    });
                }

                if (request.Data.IdDocumento <= 0)
                {
                    return BadRequest(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "IdDocumento es requerido",
                        Data = false
                    });
                }

                if (string.IsNullOrWhiteSpace(request.Data.IdReferencia))
                {
                    return BadRequest(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "IdReferencia es requerido",
                        Data = false
                    });
                }

                var tokenLogin = HttpContext.GetTokenLoginDTO();
                if (tokenLogin == null || string.IsNullOrWhiteSpace(tokenLogin.ShortUserName))
                {
                    return Unauthorized(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "No se pudo obtener la información del usuario autenticado",
                        Data = false
                    });
                }

                var documento = await _desarrolloDbService.GetDocumentoByIdAsync(request.Data.IdDocumento);
                if (documento == null)
                {
                    return BadRequest(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "No se encontró el documento",
                        Data = false
                    });
                }

                var perfilError = await ValidarPerfilAccionCriticaAsync<bool>(
                    documento.IdCliente,
                    documento.IdTipoDocumentoVucem,
                    tokenLogin.ShortUserName);
                if (perfilError != null)
                {
                    return perfilError;
                }

                decimal? idRectificacion = request.Data.IdRectificacion;

                var operaciones = await _desarrolloDbService.GetDocumentoOperacionesConEdocumentAsync(
                    request.Data.IdDocumento);
                var operacion = operaciones.FirstOrDefault(o =>
                    o.id_referencia == request.Data.IdReferencia &&
                    o.id_rectificacion == idRectificacion);

                if (operacion == null)
                {
                    return BadRequest(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "No se encontró la asociación de operación a eliminar",
                        Data = false
                    });
                }

                var edoc = (operacion.Edocument ?? string.Empty).Trim();
                var numero = (operacion.Numero ?? string.Empty).Trim();
                if (!string.IsNullOrEmpty(numero) ||
                    (!string.IsNullOrEmpty(edoc) && edoc != "0000000000000"))
                {
                    return BadRequest(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "La operación ya tiene eDocument válido o número de operación VUCEM; no se puede eliminar la asociación",
                        Data = false
                    });
                }

                var fechaPago = await _desarrolloDbService.GetFechaPagoBancoByReferenciaAsync(
                    request.Data.IdReferencia,
                    idRectificacion);

                if (fechaPago.HasValue)
                {
                    return BadRequest(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "El pedimento ya está pagado; no se puede eliminar la asociación",
                        Data = false
                    });
                }

                var rels = await _desarrolloDbService.GetRelsDocumentoEdocPorOperacionAsync(
                    request.Data.IdDocumento,
                    request.Data.IdReferencia,
                    idRectificacion);

                foreach (var rel in rels)
                {
                    await _eDOCS_DbContextServices.AnularArchivoEdocsAsync(rel.IdArchivo);
                    await _desarrolloDbService.EliminarRelDocumentoEdocAsync(rel.Id);
                }

                var eliminadas = await _desarrolloDbService.EliminarDocumentoOperacionesByClaveAsync(
                    request.Data.IdDocumento,
                    request.Data.IdReferencia,
                    idRectificacion);

                if (eliminadas == 0 && rels.Count == 0)
                {
                    return BadRequest(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "No se encontró la asociación de operación a eliminar",
                        Data = false
                    });
                }

                await _desarrolloDbService.SaveBitacoraEventoAsync(
                    request.Data.IdDocumento,
                    AdEventos.DOC_DESASOCIADO_OPERACION,
                    $"Asociación eliminada. Referencia {request.Data.IdReferencia}" +
                    (idRectificacion.HasValue ? $", rectificación {idRectificacion.Value}" : string.Empty) +
                    $". Archivos eDOCS anulados: {rels.Count}. Operaciones eliminadas: {eliminadas}.",
                    null,
                    tokenLogin.ShortUserName);

                return Ok(new GenericResponse<bool>
                {
                    Success = true,
                    Message = "Asociación eliminada correctamente",
                    Data = true
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<bool>
                {
                    Success = false,
                    Message = $"Error al eliminar la asociación de operación: {ex.Message}",
                    Data = false
                });
            }
        }

        /// <summary>
        /// Regla de negocio VUCEM: sello Cliente → rfcConsulta = RfcCliente (importador);
        /// sello Agente aduanal → rfcConsulta = RfcPatente (agente), o RfcCliente si no hay RfcPatente.
        /// </summary>
        private static string? ResolverRfcConsultaVucem(string origenSello, CspAdGetPatenteRfcClienteRow pedimento)
        {
            var origen = origenSello.Trim();

            if (origen.Equals(OrigenSelloVucem.Cliente, StringComparison.OrdinalIgnoreCase))
            {
                return pedimento.RfcPatente;
            }

            if (origen.Equals(OrigenSelloVucem.AgenteAduanal, StringComparison.OrdinalIgnoreCase))
            {
                return pedimento.RfcCliente;
            }

            return null;
        }

        private async Task<int> ResolverIdSelloAsync(string origenSello, string rfcCliente, string? patente)
        {
            var sellosRfc = await _eDOCS_DbContextServices.GetVuceSellosPorRfcAsync(rfcCliente);
            var origen = origenSello.Trim();

            if (origen.Equals(OrigenSelloVucem.Cliente, StringComparison.OrdinalIgnoreCase))
            {
                return sellosRfc?.IdSelloCliente ?? 0;
            }

            if (origen.Equals(OrigenSelloVucem.AgenteAduanal, StringComparison.OrdinalIgnoreCase))
            {
                if (string.IsNullOrWhiteSpace(patente))
                {
                    return 0;
                }

                var idAgente = await _eDOCS_DbContextServices.GetIdSelloAgentePorPatenteAsync(patente);
                return idAgente ?? 0;
            }

            return 0;
        }

        private const string MensajePerfilAccionCriticaDenegado =
            "Su perfil no tiene permiso para realizar esta acción según la configuración del motor.";

        private async Task<ActionResult?> ValidarPerfilAccionCriticaAsync<T>(
            string idCliente,
            int idTipoDocumentoVucem,
            string usuario)
        {
            var perfilCarga = await _desarrolloDbService.GetPerfilCargaPersistidoAsync(
                idCliente,
                idTipoDocumentoVucem);
            if (string.IsNullOrWhiteSpace(perfilCarga))
            {
                return StatusCode(StatusCodes.Status403Forbidden, new GenericResponse<T>
                {
                    Success = false,
                    Message = MensajePerfilAccionCriticaDenegado
                });
            }

            var usuarioEntity = await _aduasisDbContextServices.GetUsuarioPorUsuauarioAsync(usuario);
            if (!AdPerfilCargaMotor.UsuarioPuedeAccionCritica(perfilCarga, usuarioEntity?.IdClase))
            {
                return StatusCode(StatusCodes.Status403Forbidden, new GenericResponse<T>
                {
                    Success = false,
                    Message = MensajePerfilAccionCriticaDenegado
                });
            }

            return null;
        }
    }
}
