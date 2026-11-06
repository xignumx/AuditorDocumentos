using Aduax.AuditorDocumentos.Api.Data.EDOCS;

namespace Aduax.AuditorDocumentos.Api.Services.EDOCS
{
    public interface IEDOCS_DbContextServices
    {
        Task<(List<TbDocumentosVucem> Data, int TotalRecords)> GetDocumentosVucemActivosConPrefijoAsync(string? filter, int page, int size);
        Task<TbDocumentosVucem?> GetDocumentoVucemporIdTipoDocumentoVucemAsync(int idTipoDocumentoVucemAduana);
        Task<int> InsertEdocsAsync(string referencia, string rutaLocal, string rutaRemota, string serverUrl, string link, int idUsuario, string idDoc, string idDocVucem, string tipoVucemAnexo, string tipoOperacionReferencia, string tipoOperacionReferenciaId);
        Task<int?> GetIdArchivoPorReferenciaAsync(string referenciaEdocs);
        Task<CspVuceSellosRfcResult?> GetVuceSellosPorRfcAsync(string rfc);
        Task<int?> GetIdSelloAgentePorPatenteAsync(string patente);
        /// <summary>
        /// Baja lógica: Tb_Archivos.Status = 0 (bit).
        /// </summary>
        Task AnularArchivoEdocsAsync(int idArchivo);
    }
}
