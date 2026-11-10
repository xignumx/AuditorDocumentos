using Microsoft.AspNetCore.Mvc;
using Aduax.AuditorDocumentos.VModels;

namespace Aduax.AuditorDocumentos.Api.Controllers
{
    /// <summary>
    /// Carga masiva de la matriz de validación documental (E5-ID02). Acceso exclusivo de Compliance.
    /// El archivo viaja en base64 dentro del JSON, igual que los PDF del resto de la API.
    /// </summary>
    public partial class MotorConfigController
    {
        private const string NombrePlantillaMatriz = "Plantilla matriz de validacion documental.xlsx";

        [HttpPost("DescargarPlantillaMatriz")]
        public async Task<ActionResult<GenericResponse<ArchivoDescargaDto>>> DescargarPlantillaMatriz()
        {
            try
            {
                var (error, _) = await ValidarComplianceAsync<ArchivoDescargaDto>();
                if (error != null) return error;

                var contenido = await _motorConfigMasivaService.GenerarPlantillaAsync();

                return Ok(new GenericResponse<ArchivoDescargaDto>
                {
                    Success = true,
                    Message = "Plantilla generada correctamente",
                    Data = new ArchivoDescargaDto
                    {
                        NombreArchivo = NombrePlantillaMatriz,
                        ContenidoBase64 = Convert.ToBase64String(contenido)
                    }
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<ArchivoDescargaDto>
                {
                    Success = false,
                    Message = $"Error al generar la plantilla: {ex.Message}"
                });
            }
        }

        [HttpPost("CargaMasivaMatriz")]
        public async Task<ActionResult<GenericResponse<CargaMasivaMatrizResultDto>>> CargaMasivaMatriz(
            [FromBody] GenericAdRequest<CargaMasivaMatrizRequest> request)
        {
            try
            {
                var (error, usuario) = await ValidarComplianceAsync<CargaMasivaMatrizResultDto>();
                if (error != null) return error;

                if (request.Data == null)
                {
                    return BadRequest(new GenericResponse<CargaMasivaMatrizResultDto>
                    {
                        Success = false,
                        Message = "Data es requerido"
                    });
                }

                var resultado = await _motorConfigMasivaService.ProcesarAsync(request.Data, usuario!);

                // Un archivo con errores nunca se aplica, ni parcialmente
                if (!request.Data.SoloPrevisualizar && resultado.ErroresArchivo.Count > 0)
                {
                    return BadRequest(new GenericResponse<CargaMasivaMatrizResultDto>
                    {
                        Success = false,
                        Message = "El archivo tiene errores; corríjalos y previsualice de nuevo antes de aplicar",
                        Data = resultado
                    });
                }

                return Ok(new GenericResponse<CargaMasivaMatrizResultDto>
                {
                    Success = true,
                    Message = request.Data.SoloPrevisualizar
                        ? "Vista previa generada correctamente"
                        : $"Carga aplicada: {resultado.TotalAplicados} configuración(es) guardada(s)",
                    Data = resultado
                });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new GenericResponse<CargaMasivaMatrizResultDto>
                {
                    Success = false,
                    Message = ex.Message
                });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new GenericResponse<CargaMasivaMatrizResultDto>
                {
                    Success = false,
                    Message = $"Error en la carga masiva: {ex.Message}"
                });
            }
        }
    }
}
