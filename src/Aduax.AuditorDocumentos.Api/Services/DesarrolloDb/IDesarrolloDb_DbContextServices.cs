using Aduax.AuditorDocumentos.Api.Data.DesarrolloDB;
using Aduax.AuditorDocumentos.VModels;

namespace Aduax.AuditorDocumentos.Api.Services.DesarrolloDb
{
    public interface IDesarrolloDb_DbContextServices
    {
        Task<AdMotorConfigHeader> GetMotorConfigHeaderConDetalleAsync(string idCliente, int idTipoDocumentoVucem);
        Task<AdMotorConfigHeader> SaveMotorConfigHeaderConDetalleAsync(AdMotorConfigHeader motorConfigHeader);
        Task<bool> ExistsMotorConfigHeaderAsync(string idCliente, int idTipoDocumentoVucem);
        Task<string?> GetPerfilCargaPersistidoAsync(string idCliente, int idTipoDocumentoVucem);
        Task<Dictionary<int, string>> GetPerfilesCargaPorClienteAsync(string idCliente, IReadOnlyCollection<int> idTiposDocumentoVucem);
        Task<(AdIaPromptDocumento? PromptDocumento, List<AdIaPromptCampo> PromptCampos)> GetIaPromptDocumentoConCamposAsync(long idTipoDocumentoVucem);
        Task<AdConfiguracionIa?> GetConfiguracionIaAsync(string ia);
        Task<AdBitacoraEventos> SaveBitacoraEventoAsync(long idDocumento, AdEventos tipoEvento, string descripcionEvento, string? datosAdicionales, string usuarioEvento);
        Task<AdIaEjecucion> SaveIaEjecucionAsync(long idDocumento, string? proveedorIA, string modeloIA, string promptEntrada, string? jsonResultado);
        Task<AdDocumentos> SaveDocumentoAsync(AdDocumentos documento, bool validarClasificacion = true);
        Task<AdDocumentos?> GetDocumentoByIdAsync(long id);
        Task<AdDocumentosArchivos> GetDocumentoByIdArchivosAsync(long id);
        Task<AdAprobaciones> SaveAprobacionAsync(long idDocumento, int idResultado, string? motivo, string aprobadoPor);
        Task<List<CspAdDocumentosPorEstatus>> GetDocumentosPorEstatusAsync(string idCliente, int idEstatus);
        Task<AdNotifConfig?> GetNotifConfigByMotorConfigHeaderIdAsync(long idMotorConfigHeader);
        Task<AdNotifConfig> SaveNotifConfigAsync(AdNotifConfig notifConfig);
        Task<bool> ExistsMotorConfigHeaderByIdAsync(long id);
        Task<AdNotifEnvios> SaveNotifEnvioAsync(long idDocumento, string correosDestino, int diasAntesVencimiento, AdNotifResultado resultado, string? mensajeError, string creadoPor);
        Task<AdNotifTemplate?> GetNotifTemplateActivaAsync();
        Task<List<CspAdDocumentosPorVencer>> GetDocumentosPorVencerAsync(string idCliente, int idMotorConfigHeader, int diasVencimiento);
        Task<List<AdNotifConfig>> GetAllNotifConfigAsync();
        Task<List<CspAdProveedoresListarPaginado>> GetProveedoresPaginadoAsync(string idCliente, string? filtro, int pageNumber, int pageSize);
        Task<bool> ExisteDocumentoVigenteAprobadoAsync(string idCliente, int idTipoDocumentoVucem);
        Task<bool> ExisteDocumentoNoPendientePorMotorConfigAsync(long idMotorConfigHeader);
        Task<List<string>> GetCorreosRecordatorioAsync(string idCliente);
        Task<AdDocumentoOperacion> SaveDocumentoOperacionAsync(AdDocumentoOperacion operacion);
        Task<List<AdDocumentoOperacion>> GetDocumentoOperacionesConEdocumentAsync(long idDocumento);
        Task<AdRelDocumentoEdoc> SaveRelDocumentoEdocAsync(long idDocumento, int idArchivo, string creadoPor);
        Task<CspAdGetPatenteRfcClienteRow?> GetPatenteRfcClienteByRelOperacionAsync(string idReferencia, decimal? idRectificacion);
        Task<AdRelDocumentoEdoc?> GetRelDocumentoEdocAsync(long idDocumento, int idArchivo);
        Task<AdRelDocumentoEdoc?> GetRelDocumentoEdocPorOperacionAsync(long idDocumento, string idReferencia, decimal? idRectificacion);
        Task UpdateRelDocumentoEdocIdSelloEdocAsync(int idRel, int idSelloEdoc);
        Task UpdateDocumentoArchivoNombreEdocsAsync(long idDocumento, string nombreEdocs);
        Task<bool> OperacionPendienteEnvioVucemAsync(long idDocumento, string idReferencia, decimal? idRectificacion);
        Task<bool> OperacionPuedeEliminarseRespectoVucemAsync(long idDocumento, string idReferencia, decimal? idRectificacion);
        Task<DateTime?> GetFechaPagoBancoByReferenciaAsync(string idReferencia, decimal? idRectificacion);
        Task<List<AdRelDocumentoEdoc>> GetRelsDocumentoEdocPorOperacionAsync(long idDocumento, string idReferencia, decimal? idRectificacion);
        Task<int> EliminarDocumentoOperacionesByClaveAsync(long idDocumento, string idReferencia, decimal? idRectificacion);
        Task EliminarRelDocumentoEdocAsync(int idRel);

        [Obsolete("Usar InsertarDatosPedimentoV2Async con csp_ad_InsertaDatosPedimento_v2.")]
        Task<bool> InsertarDatosPedimentoAsync(long idDocumento, string idReferencia, int? idRectificacion, string? pedimento);

        Task<InsertarDatosPedimentoResultDto> InsertarDatosPedimentoV2Async(long idDocumento, string idReferencia, int? idRectificacion, string? pedimento);
        Task<List<CspAdGetTraficoPorReferencia>> GetTraficoPorReferenciaRectificacionAsync(string idReferencia, decimal idRectificacion);
    }
}
