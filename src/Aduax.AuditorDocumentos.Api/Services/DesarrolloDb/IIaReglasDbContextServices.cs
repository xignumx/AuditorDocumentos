using Aduax.AuditorDocumentos.VModels;

namespace Aduax.AuditorDocumentos.Api.Services.DesarrolloDb
{
    /// <summary>
    /// Prompts y diccionario de sinónimos de la IA (E3-ID01). Cada cambio queda en ad_ia_config_historial.
    /// Las validaciones de negocio lanzan <see cref="InvalidOperationException"/> con mensaje para el usuario.
    /// </summary>
    public interface IIaReglasDbContextServices
    {
        Task<IaPromptsDto> GetPromptsAsync(long idTipoDocumentoVucem);
        Task<IaPromptsDto> SavePromptAsync(long idTipoDocumentoVucem, GuardarIaPromptRequest request, string usuario);

        Task<List<IaDiccionarioConceptoDto>> GetDiccionarioAsync(string? categoria);
        Task<IaDiccionarioConceptoDto> SaveDiccionarioConceptoAsync(IaDiccionarioConceptoDto concepto, string usuario);
        Task DeleteDiccionarioConceptoAsync(string categoria, string concepto, string usuario);

        Task<(List<IaHistorialDto> Data, int TotalRecords)> GetHistorialAsync(IaHistorialFiltro? filtro, int page, int size);

        /// <summary>Término de UM (sin distinguir mayúsculas) → id_unidad_universal canónico.</summary>
        Task<Dictionary<string, string>> GetMapaUnidadMedidaAsync();
    }
}
