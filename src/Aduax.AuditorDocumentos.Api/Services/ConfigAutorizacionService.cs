using Aduax.AuditorDocumentos.Api.Services.Aduasis;
using Aduax.AuditorDocumentos.VModels;

namespace Aduax.AuditorDocumentos.Api.Services
{
    /// <summary>
    /// Decide qué usuarios pueden modificar la configuración del motor y las reglas de Compliance.
    /// </summary>
    public interface IConfigAutorizacionService
    {
        Task<bool> PuedeAdministrarConfigPorClienteAsync(string? usuario);
        Task<bool> PuedeAdministrarReglasComplianceAsync(string? usuario);
    }

    public class ConfigAutorizacionService : IConfigAutorizacionService
    {
        private readonly IAduasisDbContextServices _aduasisService;

        public ConfigAutorizacionService(IAduasisDbContextServices aduasisService)
        {
            _aduasisService = aduasisService;
        }

        public async Task<bool> PuedeAdministrarConfigPorClienteAsync(string? usuario)
        {
            if (string.IsNullOrWhiteSpace(usuario))
            {
                return false;
            }

            if (AdRolesConfiguracion.EsUsuarioSoporte(usuario))
            {
                return true;
            }

            var idClase = await ObtenerIdClaseAsync(usuario);
            return AdRolesConfiguracion.PuedeAdministrarConfigPorCliente(usuario, idClase);
        }

        public async Task<bool> PuedeAdministrarReglasComplianceAsync(string? usuario)
        {
            if (string.IsNullOrWhiteSpace(usuario))
            {
                return false;
            }

            if (AdRolesConfiguracion.EsUsuarioSoporte(usuario))
            {
                return true;
            }

            var idClase = await ObtenerIdClaseAsync(usuario);
            return AdRolesConfiguracion.PuedeAdministrarReglasCompliance(usuario, idClase);
        }

        private async Task<string?> ObtenerIdClaseAsync(string usuario)
        {
            var usuarioEntity = await _aduasisService.GetUsuarioPorUsuauarioAsync(usuario);
            return usuarioEntity?.IdClase;
        }
    }
}
