using Aduax.AuditorDocumentos.Api.Services.DesarrolloDb;
using Aduax.AuditorDocumentos.VModels;

namespace Aduax.AuditorDocumentos.Api.Services.IaReglas
{
    /// <summary>
    /// Aplica las reglas parametrizadas por Compliance a la extracción con IA (ExtraDatosDocumentoIa).
    /// Un fallo al leer el diccionario no debe tirar una extracción ya cobrada: se registra y se continúa sin él.
    /// </summary>
    public interface IIaReglasService
    {
        /// <summary>Inyecta el diccionario de sinónimos en el prompt ya armado.</summary>
        Task<string> AplicarSinonimosAsync(string prompt, IReadOnlyCollection<int> idsCamposVisibles);

        /// <summary>Normaliza la unidad de medida extraída al id_unidad_universal canónico (equivalencias globales).</summary>
        Task NormalizarUnidadesMedidaAsync(List<CampoExtraidoIA> campos);
    }

    public class IaReglasService : IIaReglasService
    {
        private readonly IIaReglasDbContextServices _iaReglasDb;
        private readonly ILogger<IaReglasService> _logger;

        public IaReglasService(IIaReglasDbContextServices iaReglasDb, ILogger<IaReglasService> logger)
        {
            _iaReglasDb = iaReglasDb;
            _logger = logger;
        }

        public async Task<string> AplicarSinonimosAsync(string prompt, IReadOnlyCollection<int> idsCamposVisibles)
        {
            try
            {
                var conceptos = await _iaReglasDb.GetDiccionarioAsync(IaDiccionarioCategoria.General);
                var bloque = IaReglasMotor.ConstruirBloqueSinonimos(conceptos, idsCamposVisibles);
                return IaReglasMotor.AplicarBloque(prompt, bloque);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "No se pudo aplicar el diccionario de sinónimos al prompt de IA");
                return IaReglasMotor.AplicarBloque(prompt, string.Empty);
            }
        }

        public async Task NormalizarUnidadesMedidaAsync(List<CampoExtraidoIA> campos)
        {
            var camposUm = campos.Where(c => c.IdCampo == (int)AdCampos.UnidadMedidaUMT).ToList();
            if (camposUm.Count == 0)
            {
                return;
            }

            try
            {
                var mapa = await _iaReglasDb.GetMapaUnidadMedidaAsync();
                foreach (var campo in camposUm)
                {
                    campo.Valor = IaReglasMotor.NormalizarUnidadMedida(campo.Valor, mapa);
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "No se pudieron normalizar las unidades de medida extraídas por la IA");
            }
        }
    }
}
