using Microsoft.AspNetCore.Mvc;
using Aduax.AuditorDocumentos.Api.Auth;
using Aduax.AuditorDocumentos.VModels;

namespace Aduax.AuditorDocumentos.Api.Controllers
{
    /// <summary>
    /// Reglas de IA (E3-ID01): prompts por tipo VUCEM y campo, diccionario de sinónimos ES/EN y
    /// equivalencias globales de unidad de medida. Acceso exclusivo de Compliance.
    /// El tipo de documento VUCEM viaja en la raíz de GenericAdRequest; IdCliente no aplica (reglas globales).
    /// </summary>
    public partial class MotorConfigController
    {
        private const string MensajeComplianceDenegado =
            "Su perfil no tiene permiso para administrar las reglas de IA.";

        [HttpPost("ObtenerPromptsIa")]
        public async Task<ActionResult<GenericResponse<IaPromptsDto>>> ObtenerPromptsIa(
            [FromBody] GenericAdRequest<object?> request)
        {
            try
            {
                var (error, _) = await ValidarComplianceAsync<IaPromptsDto>();
                if (error != null) return error;

                if (request.IdTipoDocumentoVucem is null or <= 0)
                {
                    return BadRequest(new GenericResponse<IaPromptsDto>
                    {
                        Success = false,
                        Message = "IdTipoDocumentoVucem es requerido y debe ser mayor a cero"
                    });
                }

                var prompts = await _iaReglasDbService.GetPromptsAsync(request.IdTipoDocumentoVucem.Value);
                return Ok(new GenericResponse<IaPromptsDto>
                {
                    Success = true,
                    Message = "Prompts obtenidos correctamente",
                    Data = prompts
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<IaPromptsDto>
                {
                    Success = false,
                    Message = $"Error al obtener los prompts: {ex.Message}"
                });
            }
        }

        [HttpPost("GuardarPromptIa")]
        public async Task<ActionResult<GenericResponse<IaPromptsDto>>> GuardarPromptIa(
            [FromBody] GenericAdRequest<GuardarIaPromptRequest> request)
        {
            try
            {
                var (error, usuario) = await ValidarComplianceAsync<IaPromptsDto>();
                if (error != null) return error;

                if (request.IdTipoDocumentoVucem is null or <= 0 || request.Data == null)
                {
                    return BadRequest(new GenericResponse<IaPromptsDto>
                    {
                        Success = false,
                        Message = "IdTipoDocumentoVucem y Data son requeridos"
                    });
                }

                var prompts = await _iaReglasDbService.SavePromptAsync(
                    request.IdTipoDocumentoVucem.Value,
                    request.Data,
                    usuario!);

                return Ok(new GenericResponse<IaPromptsDto>
                {
                    Success = true,
                    Message = "Prompt guardado correctamente",
                    Data = prompts
                });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new GenericResponse<IaPromptsDto> { Success = false, Message = ex.Message });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<IaPromptsDto>
                {
                    Success = false,
                    Message = $"Error al guardar el prompt: {ex.Message}"
                });
            }
        }

        [HttpPost("ObtenerDiccionarioIa")]
        public async Task<ActionResult<GenericResponse<List<IaDiccionarioConceptoDto>>>> ObtenerDiccionarioIa(
            [FromBody] GenericAdRequest<IaDiccionarioFiltro?> request)
        {
            try
            {
                var (error, _) = await ValidarComplianceAsync<List<IaDiccionarioConceptoDto>>();
                if (error != null) return error;

                var conceptos = await _iaReglasDbService.GetDiccionarioAsync(request.Data?.Categoria);
                await CompletarDescripcionUnidadesMedidaAsync(conceptos);

                return Ok(new GenericResponse<List<IaDiccionarioConceptoDto>>
                {
                    Success = true,
                    Message = "Diccionario obtenido correctamente",
                    Data = conceptos
                });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new GenericResponse<List<IaDiccionarioConceptoDto>> { Success = false, Message = ex.Message });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<List<IaDiccionarioConceptoDto>>
                {
                    Success = false,
                    Message = $"Error al obtener el diccionario: {ex.Message}"
                });
            }
        }

        [HttpPost("GuardarDiccionarioConceptoIa")]
        public async Task<ActionResult<GenericResponse<IaDiccionarioConceptoDto>>> GuardarDiccionarioConceptoIa(
            [FromBody] GenericAdRequest<IaDiccionarioConceptoDto> request)
        {
            try
            {
                var (error, usuario) = await ValidarComplianceAsync<IaDiccionarioConceptoDto>();
                if (error != null) return error;

                if (request.Data == null)
                {
                    return BadRequest(new GenericResponse<IaDiccionarioConceptoDto>
                    {
                        Success = false,
                        Message = "Data es requerido"
                    });
                }

                // En UM el concepto es el id_unidad_universal: debe existir en el catálogo de ADUASIS
                UnidadMedidaDto? unidad = null;
                if (IaDiccionarioCategoria.Normalizar(request.Data.Categoria) == IaDiccionarioCategoria.UnidadMedida)
                {
                    var idUnidad = request.Data.Concepto?.Trim() ?? string.Empty;
                    unidad = (await _aduasisService.GetUnidadesMedidaPorIdsAsync(new[] { idUnidad })).FirstOrDefault();
                    if (unidad == null)
                    {
                        return BadRequest(new GenericResponse<IaDiccionarioConceptoDto>
                        {
                            Success = false,
                            Message = "La unidad de medida no existe en el catálogo"
                        });
                    }
                    request.Data.Concepto = unidad.IdUnidadUniversal;
                }

                var guardado = await _iaReglasDbService.SaveDiccionarioConceptoAsync(request.Data, usuario!);
                guardado.Descripcion = unidad?.Descripcion;

                return Ok(new GenericResponse<IaDiccionarioConceptoDto>
                {
                    Success = true,
                    Message = "Diccionario guardado correctamente",
                    Data = guardado
                });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new GenericResponse<IaDiccionarioConceptoDto> { Success = false, Message = ex.Message });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<IaDiccionarioConceptoDto>
                {
                    Success = false,
                    Message = $"Error al guardar el diccionario: {ex.Message}"
                });
            }
        }

        [HttpPost("EliminarDiccionarioConceptoIa")]
        public async Task<ActionResult<GenericResponse<bool>>> EliminarDiccionarioConceptoIa(
            [FromBody] GenericAdRequest<EliminarIaDiccionarioConceptoRequest> request)
        {
            try
            {
                var (error, usuario) = await ValidarComplianceAsync<bool>();
                if (error != null) return error;

                if (request.Data == null)
                {
                    return BadRequest(new GenericResponse<bool> { Success = false, Message = "Data es requerido", Data = false });
                }

                await _iaReglasDbService.DeleteDiccionarioConceptoAsync(
                    request.Data.Categoria,
                    request.Data.Concepto,
                    usuario!);

                return Ok(new GenericResponse<bool>
                {
                    Success = true,
                    Message = "Concepto eliminado correctamente",
                    Data = true
                });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new GenericResponse<bool> { Success = false, Message = ex.Message, Data = false });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<bool>
                {
                    Success = false,
                    Message = $"Error al eliminar el concepto: {ex.Message}",
                    Data = false
                });
            }
        }

        [HttpPost("ObtenerHistorialIa")]
        public async Task<ActionResult<GenericResponse<PagedResponse<IaHistorialDto>>>> ObtenerHistorialIa(
            [FromBody] PagedRequest<IaHistorialFiltro?> request)
        {
            try
            {
                var (error, _) = await ValidarComplianceAsync<PagedResponse<IaHistorialDto>>();
                if (error != null) return error;

                var (data, total) = await _iaReglasDbService.GetHistorialAsync(request.Data, request.Page, request.Size);
                return Ok(new GenericResponse<PagedResponse<IaHistorialDto>>
                {
                    Success = true,
                    Message = "Historial obtenido correctamente",
                    Data = ConstruirPagina(data, total, request.Page, request.Size)
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<PagedResponse<IaHistorialDto>>
                {
                    Success = false,
                    Message = $"Error al obtener el historial: {ex.Message}"
                });
            }
        }

        [HttpPost("ObtenerUnidadesMedida")]
        public async Task<ActionResult<GenericResponse<PagedResponse<UnidadMedidaDto>>>> ObtenerUnidadesMedida(
            [FromBody] PagedRequest request)
        {
            try
            {
                var (error, _) = await ValidarComplianceAsync<PagedResponse<UnidadMedidaDto>>();
                if (error != null) return error;

                var (data, total) = await _aduasisService.GetUnidadesMedidaAsync(request.Filter, request.Page, request.Size);
                return Ok(new GenericResponse<PagedResponse<UnidadMedidaDto>>
                {
                    Success = true,
                    Message = "Unidades de medida obtenidas correctamente",
                    Data = ConstruirPagina(data, total, request.Page, request.Size)
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<PagedResponse<UnidadMedidaDto>>
                {
                    Success = false,
                    Message = $"Error al obtener las unidades de medida: {ex.Message}"
                });
            }
        }

        /// <summary>
        /// Valida usuario autenticado y rol Compliance. Devuelve el resultado HTTP de error, o el usuario si tiene permiso.
        /// </summary>
        private async Task<(ActionResult? Error, string? Usuario)> ValidarComplianceAsync<T>()
        {
            var tokenLogin = HttpContext.GetTokenLoginDTO();
            if (tokenLogin == null || string.IsNullOrWhiteSpace(tokenLogin.ShortUserName))
            {
                return (Unauthorized(new GenericResponse<T>
                {
                    Success = false,
                    Message = "No se pudo obtener la información del usuario autenticado"
                }), null);
            }

            if (!await _configAutorizacionService.PuedeAdministrarReglasComplianceAsync(tokenLogin.ShortUserName))
            {
                return (StatusCode(StatusCodes.Status403Forbidden, new GenericResponse<T>
                {
                    Success = false,
                    Message = MensajeComplianceDenegado
                }), null);
            }

            return (null, tokenLogin.ShortUserName);
        }

        /// <summary>Agrega la descripción del catálogo de ADUASIS a los conceptos de UM.</summary>
        private async Task CompletarDescripcionUnidadesMedidaAsync(List<IaDiccionarioConceptoDto> conceptos)
        {
            var conceptosUm = conceptos
                .Where(c => c.Categoria == IaDiccionarioCategoria.UnidadMedida)
                .ToList();
            if (conceptosUm.Count == 0)
            {
                return;
            }

            var unidades = await _aduasisService.GetUnidadesMedidaPorIdsAsync(
                conceptosUm.Select(c => c.Concepto).ToList());
            var descripciones = unidades.ToDictionary(
                u => u.IdUnidadUniversal,
                u => u.Descripcion,
                StringComparer.OrdinalIgnoreCase);

            foreach (var concepto in conceptosUm)
            {
                concepto.Descripcion = descripciones.TryGetValue(concepto.Concepto, out var descripcion)
                    ? descripcion
                    : null;
            }
        }

        private static PagedResponse<T> ConstruirPagina<T>(List<T> data, int total, int page, int size)
        {
            if (page < 1) page = 1;
            if (size < 1) size = 10;
            var totalPages = (int)Math.Ceiling(total / (double)size);

            return new PagedResponse<T>
            {
                Data = data,
                Page = page,
                Size = size,
                TotalRecords = total,
                TotalPages = totalPages,
                More = page < totalPages
            };
        }
    }
}
