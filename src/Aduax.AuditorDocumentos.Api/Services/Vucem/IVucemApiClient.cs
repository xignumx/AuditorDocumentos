using Aduax.AuditorDocumentos.VModels;

namespace Aduax.AuditorDocumentos.Api.Services.Vucem
{
    public interface IVucemApiClient
    {
        Task<EnvioVucemResultDto> EnviarArchivoVucemAsync(
            int idArchivo,
            int idSello,
            string rfcConsulta,
            string nombreArchivo,
            string? correoElectronico,
            CancellationToken cancellationToken = default);
    }
}
