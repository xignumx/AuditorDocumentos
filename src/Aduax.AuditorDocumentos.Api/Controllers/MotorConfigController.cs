using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Aduax.AuditorDocumentos.Api.Auth;
using Aduax.AuditorDocumentos.Api.Data.Aduasis;
using Aduax.AuditorDocumentos.Api.Data.DesarrolloDB;
using Aduax.AuditorDocumentos.Api.Data.EDOCS;
using Aduax.AuditorDocumentos.Api.Services;
using Aduax.AuditorDocumentos.Api.Services.Aduasis;
using Aduax.AuditorDocumentos.Api.Services.DesarrolloDb;
using Aduax.AuditorDocumentos.Api.Services.EDOCS;
using Aduax.AuditorDocumentos.Api.Services.MotorConfigMasiva;
using Aduax.AuditorDocumentos.VModels;

namespace Aduax.AuditorDocumentos.Api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public partial class MotorConfigController : ControllerBase
    {
        private readonly IEDOCS_DbContextServices _edocsService;
        private readonly IAduasisDbContextServices _aduasisService;
        private readonly IDesarrolloDb_DbContextServices _desarrolloDbService;
        private readonly IConfigAutorizacionService _configAutorizacionService;
        private readonly IIaReglasDbContextServices _iaReglasDbService;
        private readonly IMotorConfigMasivaService _motorConfigMasivaService;

        private const string MensajeConfigDenegada =
            "Su perfil no tiene permiso para modificar la configuración del motor.";

        public MotorConfigController(
            IEDOCS_DbContextServices edocsService, 
            IAduasisDbContextServices aduasisService,
            IDesarrolloDb_DbContextServices desarrolloDbService,
            IConfigAutorizacionService configAutorizacionService,
            IIaReglasDbContextServices iaReglasDbService,
            IMotorConfigMasivaService motorConfigMasivaService)
        {
            _edocsService = edocsService;
            _aduasisService = aduasisService;
            _desarrolloDbService = desarrolloDbService;
            _configAutorizacionService = configAutorizacionService;
            _iaReglasDbService = iaReglasDbService;
            _motorConfigMasivaService = motorConfigMasivaService;
        }

        [HttpPost("ObtenerDocumentosVucem")]
        public async Task<ActionResult<GenericResponse<PagedResponse<TbDocumentosVucem>>>> ObtenerDocumentosVucem([FromBody] PagedRequest request)
        {
            try
            {
                var (documentos, totalRecords) = await _edocsService.GetDocumentosVucemActivosConPrefijoAsync(
                    request.Filter, 
                    request.Page, 
                    request.Size);

                int totalPages = (int)Math.Ceiling(totalRecords / (double)request.Size);
                bool more = request.Page < totalPages;

                return Ok(new GenericResponse<PagedResponse<TbDocumentosVucem>>
                {
                    Success = true,
                    Message = "Documentos obtenidos correctamente",
                    Data = new PagedResponse<TbDocumentosVucem>
                    {
                        Data = documentos,
                        Page = request.Page,
                        Size = request.Size,
                        TotalRecords = totalRecords,
                        TotalPages = totalPages,
                        More = more
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<PagedResponse<TbDocumentosVucem>>
                {
                    Success = false,
                    Message = $"Error al obtener documentos: {ex.Message}",
                    Data = new PagedResponse<TbDocumentosVucem>
                    {
                        Data = new(),
                        Page = request.Page,
                        Size = request.Size,
                        TotalRecords = 0,
                        TotalPages = 0,
                        More = false
                    }
                });
            }
        }

        [HttpPost("ObtenerClientes")]
        public async Task<ActionResult<GenericResponse<PagedResponse<FCliente>>>> ObtenerClientes([FromBody] PagedRequest request)
        {
            try
            {
                var (clientes, totalRecords) = await _aduasisService.GetClientesAsync(
                    request.Filter, 
                    request.Page, 
                    request.Size);

                int totalPages = (int)Math.Ceiling(totalRecords / (double)request.Size);
                bool more = request.Page < totalPages;

                return Ok(new GenericResponse<PagedResponse<FCliente>>
                {
                    Success = true,
                    Message = "Clientes obtenidos correctamente",
                    Data = new PagedResponse<FCliente>
                    {
                        Data = clientes,
                        Page = request.Page,
                        Size = request.Size,
                        TotalRecords = totalRecords,
                        TotalPages = totalPages,
                        More = more
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<PagedResponse<FCliente>>
                {
                    Success = false,
                    Message = $"Error al obtener clientes: {ex.Message}",
                    Data = new PagedResponse<FCliente>
                    {
                        Data = new(),
                        Page = request.Page,
                        Size = request.Size,
                        TotalRecords = 0,
                        TotalPages = 0,
                        More = false
                    }
                });
            }
        }

        [HttpPost("ObtenerAduanas")]
        public async Task<ActionResult<GenericResponse<PagedResponse<FAduana>>>> ObtenerAduanas([FromBody] PagedRequest request)
        {
            try
            {
                var (aduanas, totalRecords) = await _aduasisService.GetAduanasAsync(
                    request.Filter, 
                    request.Page, 
                    request.Size);

                int totalPages = (int)Math.Ceiling(totalRecords / (double)request.Size);
                bool more = request.Page < totalPages;

                return Ok(new GenericResponse<PagedResponse<FAduana>>
                {
                    Success = true,
                    Message = "Aduanas obtenidas correctamente",
                    Data = new PagedResponse<FAduana>
                    {
                        Data = aduanas,
                        Page = request.Page,
                        Size = request.Size,
                        TotalRecords = totalRecords,
                        TotalPages = totalPages,
                        More = more
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<PagedResponse<FAduana>>
                {
                    Success = false,
                    Message = $"Error al obtener aduanas: {ex.Message}",
                    Data = new PagedResponse<FAduana>
                    {
                        Data = new(),
                        Page = request.Page,
                        Size = request.Size,
                        TotalRecords = 0,
                        TotalPages = 0,
                        More = false
                    }
                });
            }
        }

        [HttpPost("ObtenerRegimenes")]
        public async Task<ActionResult<GenericResponse<PagedResponse<FRegimen>>>> ObtenerRegimenes([FromBody] PagedRequest<AduanaRequest> request)
        {
            try
            {
                string? operacion = request.Data?.TipoOperacion switch
                {
                    "1" => "0",
                    "2" => "1",
                    _ => null
                };

                var (regimenes, totalRecords) = await _aduasisService.GetRegimenesAsync(
                    request.Data?.Filter,
                    request.Page,
                    request.Size,
                    operacion);

                int totalPages = (int)Math.Ceiling(totalRecords / (double)request.Size);
                bool more = request.Page < totalPages;

                return Ok(new GenericResponse<PagedResponse<FRegimen>>
                {
                    Success = true,
                    Message = "Régimenes obtenidos correctamente",
                    Data = new PagedResponse<FRegimen>
                    {
                        Data = regimenes,
                        Page = request.Page,
                        Size = request.Size,
                        TotalRecords = totalRecords,
                        TotalPages = totalPages,
                        More = more
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<PagedResponse<FRegimen>>
                {
                    Success = false,
                    Message = $"Error al obtener régimenes: {ex.Message}",
                    Data = new PagedResponse<FRegimen>
                    {
                        Data = new(),
                        Page = request.Page,
                        Size = request.Size,
                        TotalRecords = 0,
                        TotalPages = 0,
                        More = false
                    }
                });
            }
        }

        [HttpPost("ObtenerMotorConfig")]
        public async Task<ActionResult<GenericResponse<AdMotorConfigHeader>>> ObtenerMotorConfig([FromBody] GenericAdRequest<object> request)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(request.IdCliente))
                {
                    return BadRequest(new GenericResponse<AdMotorConfigHeader>
                    {
                        Success = false,
                        Message = "IdCliente es requerido",
                        Data = null
                    });
                }

                if (!request.IdTipoDocumentoVucem.HasValue || request.IdTipoDocumentoVucem.Value <= 0)
                {
                    return BadRequest(new GenericResponse<AdMotorConfigHeader>
                    {
                        Success = false,
                        Message = "IdTipoDocumentoVucem es requerido y debe ser mayor a cero",
                        Data = null
                    });
                }

                var motorConfig = await _desarrolloDbService.GetMotorConfigHeaderConDetalleAsync(
                    request.IdCliente,
                    request.IdTipoDocumentoVucem.Value);

                // Limpiar la propiedad de navegación MotorConfigHeader en cada detalle para evitar referencias circulares en JSON
                if (motorConfig.Detalles != null)
                {
                    foreach (var detalle in motorConfig.Detalles)
                    {
                        detalle.MotorConfigHeader = null;
                    }
                }

                return Ok(new GenericResponse<AdMotorConfigHeader>
                {
                    Success = true,
                    Message = "Configuración del motor obtenida correctamente",
                    Data = motorConfig
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<AdMotorConfigHeader>
                {
                    Success = false,
                    Message = $"Error al obtener configuración del motor: {ex.Message}",
                    Data = null
                });
            }
        }

        [HttpPost("GuardarMotorConfig")]
        public async Task<ActionResult<GenericResponse<AdMotorConfigHeader>>> GuardarMotorConfig([FromBody] GenericAdRequest<AdMotorConfigHeader> request)
        {
            try
            {
                if (request.Data == null)
                {
                    return BadRequest(new GenericResponse<AdMotorConfigHeader>
                    {
                        Success = false,
                        Message = "Data es requerido",
                        Data = null
                    });
                }

                if (string.IsNullOrWhiteSpace(request.Data.IdCliente))
                {
                    return BadRequest(new GenericResponse<AdMotorConfigHeader>
                    {
                        Success = false,
                        Message = "IdCliente es requerido",
                        Data = null
                    });
                }

                if (request.Data.IdTipoDocumentoVucem <= 0)
                {
                    return BadRequest(new GenericResponse<AdMotorConfigHeader>
                    {
                        Success = false,
                        Message = "IdTipoDocumentoVucem es requerido y debe ser mayor a cero",
                        Data = null
                    });
                }

                // Obtener el usuario del token
                var tokenDTO = HttpContext.GetTokenLoginDTO();
                if (tokenDTO == null || string.IsNullOrWhiteSpace(tokenDTO.ShortUserName))
                {
                    return Unauthorized(new GenericResponse<AdMotorConfigHeader>
                    {
                        Success = false,
                        Message = "No se pudo obtener la información del usuario autenticado",
                        Data = null
                    });
                }

                string usuario = tokenDTO.ShortUserName;

                // Solo perfiles autorizados pueden guardar la configuración (el menú del front es solo visual)
                if (!await _configAutorizacionService.PuedeAdministrarConfigPorClienteAsync(usuario))
                {
                    return StatusCode(StatusCodes.Status403Forbidden, new GenericResponse<AdMotorConfigHeader>
                    {
                        Success = false,
                        Message = MensajeConfigDenegada,
                        Data = null
                    });
                }

                // Asignar usuario de auditoría según si es nuevo o actualización
                if (request.Data.Id == 0)
                {
                    // Nuevo registro
                    request.Data.CreadoPor = usuario;
                }
                else
                {
                    // Actualización
                    request.Data.ActualizadoPor = usuario;
                }

                var motorConfig = await _desarrolloDbService.SaveMotorConfigHeaderConDetalleAsync(request.Data);


                // Limpiar la propiedad de navegación MotorConfigHeader en cada detalle para evitar referencias circulares en JSON
                if (motorConfig.Detalles != null)
                {
                    foreach (var detalle in motorConfig.Detalles)
                    {
                        detalle.MotorConfigHeader = null;
                    }
                }

                return Ok(new GenericResponse<AdMotorConfigHeader>
                {
                    Success = true,
                    Message = request.Data.Id == 0 
                        ? "Configuración del motor guardada correctamente" 
                        : "Configuración del motor actualizada correctamente",
                    Data = motorConfig
                });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new GenericResponse<AdMotorConfigHeader>
                {
                    Success = false,
                    Message = ex.Message,
                    Data = null
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<AdMotorConfigHeader>
                {
                    Success = false,
                    Message = $"Error al guardar configuración del motor: {ex.Message}",
                    Data = null
                });
            }
        }

        [HttpPost("PuedeCambiarClasificacion")]
        public async Task<ActionResult<GenericResponse<bool>>> PuedeCambiarClasificacion([FromBody] GenericAdRequest<long> request)
        {
            try
            {
                if (request.Data <= 0)
                {
                    return BadRequest(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "El Id del MotorConfigHeader es requerido",
                        Data = false
                    });
                }

                bool existenDocumentosNoPendientes = await _desarrolloDbService.ExisteDocumentoNoPendientePorMotorConfigAsync(request.Data);
                bool puedeCambiar = !existenDocumentosNoPendientes;

                return Ok(new GenericResponse<bool>
                {
                    Success = true,
                    Message = puedeCambiar
                        ? "La clasificación puede modificarse; no existen documentos asociados con estatus diferente a Pendiente."
                        : "No es posible cambiar la clasificación porque existen documentos asociados con estatus diferente a Pendiente.",
                    Data = puedeCambiar
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<bool>
                {
                    Success = false,
                    Message = $"Error al validar cambio de clasificación: {ex.Message}",
                    Data = false
                });
            }
        }

        [HttpPost("ValidaFraccion")]
        public async Task<ActionResult<GenericResponse<bool>>> ValidaFraccion([FromBody] GenericAdRequest<string> request)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(request.IdCliente))
                {
                    return BadRequest(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "IdCliente es requerido",
                        Data = false
                    });
                }

                if (string.IsNullOrWhiteSpace(request.Data))
                {
                    return BadRequest(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "La fracción arancelaria es requerida",
                        Data = false
                    });
                }

                var idFraccion = await _aduasisService.ValidaFraccionAsync(request.IdCliente, request.Data);
                bool existe = !string.IsNullOrWhiteSpace(idFraccion);

                return Ok(new GenericResponse<bool>
                {
                    Success = true,
                    Message = existe
                        ? "Fracción arancelaria válida"
                        : "Fracción arancelaria no encontrada",
                    Data = existe
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<bool>
                {
                    Success = false,
                    Message = $"Error al validar fracción arancelaria: {ex.Message}",
                    Data = false
                });
            }
        }

        [HttpPost("ValidaUnidadMedida")]
        public async Task<ActionResult<GenericResponse<bool>>> ValidaUnidadMedida([FromBody] GenericAdRequest<string> request)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(request.Data))
                {
                    return BadRequest(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "La unidad de medida es requerida",
                        Data = false
                    });
                }

                var idUnidadUniversal = await _aduasisService.ValidaUnidadMedidaAsync(request.Data);
                bool existe = !string.IsNullOrWhiteSpace(idUnidadUniversal);

                return Ok(new GenericResponse<bool>
                {
                    Success = true,
                    Message = existe
                        ? "Unidad de medida válida"
                        : "Unidad de medida no encontrada",
                    Data = existe
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<bool>
                {
                    Success = false,
                    Message = $"Error al validar unidad de medida: {ex.Message}",
                    Data = false
                });
            }
        }

        [HttpPost("ValidaPais")]
        public async Task<ActionResult<GenericResponse<bool>>> ValidaPais([FromBody] GenericAdRequest<string> request)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(request.Data))
                {
                    return BadRequest(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "El país es requerido",
                        Data = false
                    });
                }

                var idPais = await _aduasisService.ValidaPaisAsync(request.Data);
                bool existe = !string.IsNullOrWhiteSpace(idPais);

                return Ok(new GenericResponse<bool>
                {
                    Success = true,
                    Message = existe
                        ? "País válido"
                        : "País no encontrado",
                    Data = existe
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<bool>
                {
                    Success = false,
                    Message = $"Error al validar país: {ex.Message}",
                    Data = false
                });
            }
        }

        [HttpPost("ValidaExistenciaMotorConfig")]
        public async Task<ActionResult<GenericResponse<bool>>> ValidaExistenciaMotorConfig([FromBody] GenericAdRequest<object> request)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(request.IdCliente))
                {
                    return BadRequest(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "IdCliente es requerido",
                        Data = false
                    });
                }

                if (!request.IdTipoDocumentoVucem.HasValue || request.IdTipoDocumentoVucem.Value <= 0)
                {
                    return BadRequest(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "IdTipoDocumentoVucem es requerido y debe ser mayor a cero",
                        Data = false
                    });
                }

                bool existe = await _desarrolloDbService.ExistsMotorConfigHeaderAsync(
                    request.IdCliente,
                    request.IdTipoDocumentoVucem.Value);

                return Ok(new GenericResponse<bool>
                {
                    Success = true,
                    Message = existe 
                        ? "La configuración del motor existe" 
                        : "La configuración del motor no existe",
                    Data = existe
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<bool>
                {
                    Success = false,
                    Message = $"Error al validar existencia de configuración del motor: {ex.Message}",
                    Data = false
                });
            }
        }

        [HttpPost("ObtenerSugerenciaPedimentos")]
        public async Task<ActionResult<GenericResponse<PagedResponse<CspAdSugerenciaPedimentos>>>> ObtenerSugerenciaPedimentos([FromBody] GenericAdRequest<PagedRequest<SugerenciaPedimentosRequest>> request)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(request.IdCliente))
                {
                    return BadRequest(new GenericResponse<PagedResponse<CspAdSugerenciaPedimentos>>
                    {
                        Success = false,
                        Message = "IdCliente es requerido",
                        Data = new PagedResponse<CspAdSugerenciaPedimentos>
                        {
                            Data = new(),
                            Page = request.Data?.Page ?? 1,
                            Size = request.Data?.Size ?? 10,
                            TotalRecords = 0,
                            TotalPages = 0,
                            More = false
                        }
                    });
                }

                if (request.Data == null)
                {
                    return BadRequest(new GenericResponse<PagedResponse<CspAdSugerenciaPedimentos>>
                    {
                        Success = false,
                        Message = "Data es requerido",
                        Data = new PagedResponse<CspAdSugerenciaPedimentos>
                        {
                            Data = new(),
                            Page = 1,
                            Size = 10,
                            TotalRecords = 0,
                            TotalPages = 0,
                            More = false
                        }
                    });
                }

                if (request.Data.Data == null)
                {
                    return BadRequest(new GenericResponse<PagedResponse<CspAdSugerenciaPedimentos>>
                    {
                        Success = false,
                        Message = "Data.Data es requerido",
                        Data = new PagedResponse<CspAdSugerenciaPedimentos>
                        {
                            Data = new(),
                            Page = request.Data.Page,
                            Size = request.Data.Size,
                            TotalRecords = 0,
                            TotalPages = 0,
                            More = false
                        }
                    });
                }

                int page = request.Data.Page < 1 ? 1 : request.Data.Page;
                int size = request.Data.Size < 1 ? 10 : request.Data.Size;

                var pedimentos = await _aduasisService.GetSugerenciaPedimentosAsync(
                    request.IdCliente,
                    request.Data.Data.IdAdDocumento,
                    request.Data.Data.OperacionBusqueda ?? string.Empty,
                    page,
                    size);

                int totalRecords = pedimentos.FirstOrDefault()?.TotalRecords ?? 0;
                int totalPages = (int)Math.Ceiling(totalRecords / (double)size);
                bool more = page < totalPages;

                return Ok(new GenericResponse<PagedResponse<CspAdSugerenciaPedimentos>>
                {
                    Success = true,
                    Message = "Sugerencias de pedimentos obtenidas correctamente",
                    Data = new PagedResponse<CspAdSugerenciaPedimentos>
                    {
                        Data = pedimentos,
                        Page = page,
                        Size = size,
                        TotalRecords = totalRecords,
                        TotalPages = totalPages,
                        More = more
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<PagedResponse<CspAdSugerenciaPedimentos>>
                {
                    Success = false,
                    Message = $"Error al obtener sugerencias de pedimentos: {ex.Message}",
                    Data = new PagedResponse<CspAdSugerenciaPedimentos>
                    {
                        Data = new(),
                        Page = request.Data?.Page ?? 1,
                        Size = request.Data?.Size ?? 10,
                        TotalRecords = 0,
                        TotalPages = 0,
                        More = false
                    }
                });
            }
        }

        [HttpPost("DiagnosticoSugerenciaPedimentos")]
        public async Task<ActionResult<GenericResponse<List<CspAdDiagnosticoSugerenciaPedimentoRow>>>> DiagnosticoSugerenciaPedimentos([FromBody] GenericAdRequest<SugerenciaPedimentosRequest> request)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(request.IdCliente))
                {
                    return BadRequest(new GenericResponse<List<CspAdDiagnosticoSugerenciaPedimentoRow>>
                    {
                        Success = false,
                        Message = "IdCliente es requerido",
                        Data = new()
                    });
                }

                if (request.Data == null)
                {
                    return BadRequest(new GenericResponse<List<CspAdDiagnosticoSugerenciaPedimentoRow>>
                    {
                        Success = false,
                        Message = "Data es requerido",
                        Data = new()
                    });
                }

                var filas = await _aduasisService.GetDiagnosticoSugerenciaPedimentosAsync(
                    request.IdCliente,
                    request.Data.IdAdDocumento,
                    request.Data.OperacionBusqueda ?? string.Empty);

                return Ok(new GenericResponse<List<CspAdDiagnosticoSugerenciaPedimentoRow>>
                {
                    Success = true,
                    Message = "Diagnóstico obtenido correctamente",
                    Data = filas
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<List<CspAdDiagnosticoSugerenciaPedimentoRow>>
                {
                    Success = false,
                    Message = $"Error al obtener diagnóstico de sugerencias: {ex.Message}",
                    Data = new()
                });
            }
        }

        [HttpPost("ObtenerProveedores")]
        public async Task<ActionResult<GenericResponse<PagedResponse<CspAdProveedoresListarPaginado>>>> ObtenerProveedores([FromBody] GenericAdRequest<PagedRequest> request)
        {
            try
            {
                if (string.IsNullOrWhiteSpace(request.IdCliente))
                {
                    return BadRequest(new GenericResponse<PagedResponse<CspAdProveedoresListarPaginado>>
                    {
                        Success = false,
                        Message = "IdCliente es requerido",
                        Data = new PagedResponse<CspAdProveedoresListarPaginado>
                        {
                            Data = new(),
                            Page = request.Data?.Page ?? 1,
                            Size = request.Data?.Size ?? 10,
                            TotalRecords = 0,
                            TotalPages = 0,
                            More = false
                        }
                    });
                }

                if (request.Data == null)
                {
                    return BadRequest(new GenericResponse<PagedResponse<CspAdProveedoresListarPaginado>>
                    {
                        Success = false,
                        Message = "Data es requerido",
                        Data = new PagedResponse<CspAdProveedoresListarPaginado>
                        {
                            Data = new(),
                            Page = 1,
                            Size = 10,
                            TotalRecords = 0,
                            TotalPages = 0,
                            More = false
                        }
                    });
                }

                int page = request.Data.Page < 1 ? 1 : request.Data.Page;
                int size = request.Data.Size < 1 ? 10 : request.Data.Size;

                var proveedores = await _desarrolloDbService.GetProveedoresPaginadoAsync(
                    request.IdCliente,
                    request.Data.Filter,
                    page,
                    size);

                int totalRecords = proveedores.FirstOrDefault()?.TotalRows ?? 0;
                int totalPages = (int)Math.Ceiling(totalRecords / (double)size);
                bool more = page < totalPages;

                return Ok(new GenericResponse<PagedResponse<CspAdProveedoresListarPaginado>>
                {
                    Success = true,
                    Message = "Proveedores obtenidos correctamente",
                    Data = new PagedResponse<CspAdProveedoresListarPaginado>
                    {
                        Data = proveedores,
                        Page = page,
                        Size = size,
                        TotalRecords = totalRecords,
                        TotalPages = totalPages,
                        More = more
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<PagedResponse<CspAdProveedoresListarPaginado>>
                {
                    Success = false,
                    Message = $"Error al obtener proveedores: {ex.Message}",
                    Data = new PagedResponse<CspAdProveedoresListarPaginado>
                    {
                        Data = new(),
                        Page = request.Data?.Page ?? 1,
                        Size = request.Data?.Size ?? 10,
                        TotalRecords = 0,
                        TotalPages = 0,
                        More = false
                    }
                });
            }
        }

        [HttpGet("ValidaUsuarioAdminLider")]
        public async Task<ActionResult<GenericResponse<bool>>> ValidaUsuarioAdminLider()
        {
            try
            {
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

                // ADM, LIDER, CALIDAD, COMPLIANCE o usuario de soporte
                bool esAdminLider = await _configAutorizacionService
                    .PuedeAdministrarConfigPorClienteAsync(tokenLogin.ShortUserName);

                return Ok(new GenericResponse<bool>
                {
                    Success = true,
                    Message = esAdminLider
                        ? "El usuario cuenta con permisos de administrador o líder"
                        : "El usuario no cuenta con permisos de administrador o líder",
                    Data = esAdminLider
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<bool>
                {
                    Success = false,
                    Message = $"Error al validar permisos del usuario: {ex.Message}",
                    Data = false
                });
            }
        }

        [HttpGet("ValidaUsuarioCompliance")]
        public async Task<ActionResult<GenericResponse<bool>>> ValidaUsuarioCompliance()
        {
            try
            {
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

                bool esCompliance = await _configAutorizacionService
                    .PuedeAdministrarReglasComplianceAsync(tokenLogin.ShortUserName);

                return Ok(new GenericResponse<bool>
                {
                    Success = true,
                    Message = esCompliance
                        ? "El usuario cuenta con permisos de Compliance"
                        : "El usuario no cuenta con permisos de Compliance",
                    Data = esCompliance
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<bool>
                {
                    Success = false,
                    Message = $"Error al validar permisos de Compliance: {ex.Message}",
                    Data = false
                });
            }
        }
    }
}
