using Amazon.S3.Model;
using Aduax.AuditorDocumentos.Api.Data.Aduasis;
using Aduax.AuditorDocumentos.VModels;

namespace Aduax.AuditorDocumentos.Api.Services.Aduasis
{
    public interface IAduasisDbContextServices
    {
        Task<(List<FCliente> Data, int TotalRecords)> GetClientesAsync(string? filter, int page, int size);
        Task<(List<FAduana> Data, int TotalRecords)> GetAduanasAsync(string? filter, int page, int size);
        Task<(List<FRegimen> Data, int TotalRecords)> GetRegimenesAsync(string? filter, int page, int size, string? cveTipoOperacion);
        Task<FCliente> GetClienteAsync(string idCliente);
        Task<string?> ValidaFraccionAsync(string idCliente, string idFraccion);
        Task<string?> ValidaUnidadMedidaAsync(string unidadMedida);
        Task<(List<UnidadMedidaDto> Data, int TotalRecords)> GetUnidadesMedidaAsync(string? filter, int page, int size);
        Task<List<UnidadMedidaDto>> GetUnidadesMedidaPorIdsAsync(IReadOnlyCollection<string> ids);
        Task<string?> ValidaPaisAsync(string pais);
        Task<List<CspAdSugerenciaPedimentos>> GetSugerenciaPedimentosAsync(
            string idCliente,
            long idAdDocumento,
            string operacionBusqueda,
            int pageNumber,
            int pageSize);
        Task<List<CspAdDiagnosticoSugerenciaPedimentoRow>> GetDiagnosticoSugerenciaPedimentosAsync(
            string idCliente,
            long idAdDocumento,
            string operacionBusqueda);
        Task<FUsuario?> GetUsuarioPorUsuauarioAsync(string usuario);
        Task<bool> EsUsuarioAdminLider(string usuario);
        Task<int> GetIdUsuarioEdocsAsync(string usuario);
    }
}
