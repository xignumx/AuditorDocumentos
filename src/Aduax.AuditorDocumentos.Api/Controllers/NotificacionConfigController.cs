using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Aduax.AuditorDocumentos.Api.Auth;
using Aduax.AuditorDocumentos.Api.Data.DesarrolloDB;
using Aduax.AuditorDocumentos.Api.Services;
using Aduax.AuditorDocumentos.Api.Services.DesarrolloDb;
using Aduax.AuditorDocumentos.VModels;
using System.Text.RegularExpressions;

namespace Aduax.AuditorDocumentos.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class NotificacionConfigController : ControllerBase
    {
        private readonly IDesarrolloDb_DbContextServices _desarrolloDbService;
        private readonly INotificacionVencimientoProcessor _notificacionProcessor;

        public NotificacionConfigController(
            IDesarrolloDb_DbContextServices desarrolloDbService,
            INotificacionVencimientoProcessor notificacionProcessor)
        {
            _desarrolloDbService = desarrolloDbService;
            _notificacionProcessor = notificacionProcessor;
        }

        [HttpPost("ObtenerNotifConfig")]
        public async Task<ActionResult<GenericResponse<AdNotifConfig>>> ObtenerNotifConfig([FromBody] GenericAdRequest<long?> request)
        {
            try
            {
                if (!request.Data.HasValue || request.Data.Value <= 0)
                {
                    return BadRequest(new GenericResponse<AdNotifConfig>
                    {
                        Success = false,
                        Message = "IdMotorConfigHeader es requerido y debe ser mayor a cero",
                        Data = null
                    });
                }

                long idMotorConfigHeader = request.Data.Value;

                var notifConfig = await _desarrolloDbService.GetNotifConfigByMotorConfigHeaderIdAsync(idMotorConfigHeader);

                if (notifConfig == null)
                {
                    notifConfig = new AdNotifConfig
                    {
                        Id = 0,
                        IdMotorConfigHeader = idMotorConfigHeader,
                        Correos = string.Empty,
                        DiasAntesVencimiento = string.Empty
                    };
                }

                // Limpiar la propiedad de navegación MotorConfigHeader para evitar referencias circulares en JSON
                notifConfig.MotorConfigHeader = null;

                return Ok(new GenericResponse<AdNotifConfig>
                {
                    Success = true,
                    Message = "Configuración de notificación obtenida correctamente",
                    Data = notifConfig
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<AdNotifConfig>
                {
                    Success = false,
                    Message = $"Error al obtener configuración de notificación: {ex.Message}",
                    Data = null
                });
            }
        }

        [HttpPost("GuardarNotifConfig")]
        public async Task<ActionResult<GenericResponse<AdNotifConfig>>> GuardarNotifConfig([FromBody] GenericAdRequest<AdNotifConfig> request)
        {
            try
            {
                if (request.Data == null)
                {
                    return BadRequest(new GenericResponse<AdNotifConfig>
                    {
                        Success = false,
                        Message = "Data es requerido",
                        Data = null
                    });
                }

                if (request.Data.IdMotorConfigHeader <= 0)
                {
                    return BadRequest(new GenericResponse<AdNotifConfig>
                    {
                        Success = false,
                        Message = "IdMotorConfigHeader es requerido y debe ser mayor a cero",
                        Data = null
                    });
                }

                // Validar que el IdMotorConfigHeader exista
                bool existeMotorConfig = await _desarrolloDbService.ExistsMotorConfigHeaderByIdAsync(request.Data.IdMotorConfigHeader);

                if (!existeMotorConfig)
                {
                    return BadRequest(new GenericResponse<AdNotifConfig>
                    {
                        Success = false,
                        Message = "El IdMotorConfigHeader no existe",
                        Data = null
                    });
                }

                // Validar correos
                if (string.IsNullOrWhiteSpace(request.Data.Correos))
                {
                    return BadRequest(new GenericResponse<AdNotifConfig>
                    {
                        Success = false,
                        Message = "Correos es requerido",
                        Data = null
                    });
                }

                if (!ValidateEmails(request.Data.Correos))
                {
                    return BadRequest(new GenericResponse<AdNotifConfig>
                    {
                        Success = false,
                        Message = "El formato de uno o más correos electrónicos no es válido",
                        Data = null
                    });
                }

                // Validar DiasAntesVencimiento
                if (string.IsNullOrWhiteSpace(request.Data.DiasAntesVencimiento))
                {
                    return BadRequest(new GenericResponse<AdNotifConfig>
                    {
                        Success = false,
                        Message = "DiasAntesVencimiento es requerido",
                        Data = null
                    });
                }

                if (!ValidateDiasAntesVencimiento(request.Data.DiasAntesVencimiento))
                {
                    return BadRequest(new GenericResponse<AdNotifConfig>
                    {
                        Success = false,
                        Message = "DiasAntesVencimiento debe contener números positivos mayores a cero, separados por comas si hay múltiples valores",
                        Data = null
                    });
                }

                // Obtener el usuario del token
                var tokenDTO = HttpContext.GetTokenLoginDTO();
                string usuario = tokenDTO?.ShortUserName ?? "Sistema";

                // Verificar si ya existe un registro con el mismo IdMotorConfigHeader
                var notifConfigExistente = await _desarrolloDbService.GetNotifConfigByMotorConfigHeaderIdAsync(request.Data.IdMotorConfigHeader);

                if (notifConfigExistente != null)
                {
                    // Actualización
                    request.Data.Id = notifConfigExistente.Id;
                    request.Data.FechaCreacion = notifConfigExistente.FechaCreacion;
                    request.Data.CreadoPor = notifConfigExistente.CreadoPor;
                    request.Data.ActualizadoPor = usuario;
                }
                else
                {
                    // Nuevo registro
                    request.Data.Id = 0;
                    request.Data.CreadoPor = usuario;
                }

                var notifConfig = await _desarrolloDbService.SaveNotifConfigAsync(request.Data);

                // Limpiar la propiedad de navegación MotorConfigHeader para evitar referencias circulares en JSON
                notifConfig.MotorConfigHeader = null;

                return Ok(new GenericResponse<AdNotifConfig>
                {
                    Success = true,
                    Message = notifConfigExistente == null
                        ? "Configuración de notificación guardada correctamente"
                        : "Configuración de notificación actualizada correctamente",
                    Data = notifConfig
                });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new GenericResponse<AdNotifConfig>
                {
                    Success = false,
                    Message = ex.Message,
                    Data = null
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<AdNotifConfig>
                {
                    Success = false,
                    Message = $"Error al guardar configuración de notificación: {ex.Message}",
                    Data = null
                });
            }
        }

        [HttpPost("RecuperaCorreosRecordados")]
        public async Task<ActionResult<GenericResponse<List<string>>>> RecuperaCorreosRecordados([FromBody] GenericAdRequest<object> request)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(request.IdCliente))
                {
                    return BadRequest(new GenericResponse<List<string>>
                    {
                        Success = false,
                        Message = "IdCliente es requerido",
                        Data = null
                    });
                }

                var correos = await _desarrolloDbService.GetCorreosRecordatorioAsync(request.IdCliente);

                return Ok(new GenericResponse<List<string>>
                {
                    Success = true,
                    Message = correos.Any()
                        ? "Correos recuperados correctamente"
                        : "No se encontraron correos configurados para recordatorio",
                    Data = correos
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<List<string>>
                {
                    Success = false,
                    Message = $"Error al recuperar correos recordados: {ex.Message}",
                    Data = null
                });
            }
        }

        [HttpPost("EjecutarNotificaciones")]
        public async Task<ActionResult<GenericResponse<NotificacionProcesoResultado>>> EjecutarNotificaciones()
        {
            try
            {
                var resultado = await _notificacionProcessor.ProcesarAsync(HttpContext.RequestAborted);

                return Ok(new GenericResponse<NotificacionProcesoResultado>
                {
                    Success = true,
                    Message = "Proceso de notificaciones ejecutado correctamente",
                    Data = resultado
                });
            }
            catch (OperationCanceledException)
            {
                return StatusCode(StatusCodes.Status499ClientClosedRequest, new GenericResponse<NotificacionProcesoResultado>
                {
                    Success = false,
                    Message = "La ejecución manual fue cancelada",
                    Data = null
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<NotificacionProcesoResultado>
                {
                    Success = false,
                    Message = $"Error al ejecutar el proceso de notificaciones: {ex.Message}",
                    Data = null
                });
            }
        }

        private bool ValidateEmails(string correos)
        {
            if (string.IsNullOrWhiteSpace(correos))
                return false;

            // Patrón para validar email
            string emailPattern = @"^[^@\s]+@[^@\s]+\.[^@\s]+$";
            Regex emailRegex = new Regex(emailPattern, RegexOptions.IgnoreCase);

            // Separar por comas y validar cada email
            string[] emails = correos.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

            foreach (string email in emails)
            {
                if (string.IsNullOrWhiteSpace(email) || !emailRegex.IsMatch(email))
                {
                    return false;
                }
            }

            return true;
        }

        private bool ValidateDiasAntesVencimiento(string diasAntesVencimiento)
        {
            if (string.IsNullOrWhiteSpace(diasAntesVencimiento))
                return false;

            // Separar por comas y validar cada número
            string[] dias = diasAntesVencimiento.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

            foreach (string dia in dias)
            {
                if (string.IsNullOrWhiteSpace(dia))
                    return false;

                if (!int.TryParse(dia, out int diaNumero))
                    return false;

                if (diaNumero <= 0)
                    return false;
            }

            return true;
        }
    }
}
