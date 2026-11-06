namespace Aduax.AuditorDocumentos.Api.Configuration
{
    public class VucemApiCfg
    {
        public string BaseUrl { get; set; } = string.Empty;
        public string NombreAplicacion { get; set; } = string.Empty;
        public string ApiKey { get; set; } = string.Empty;
        public int TimeoutSeconds { get; set; } = 600;

        public bool EstaConfigurado =>
            !string.IsNullOrWhiteSpace(BaseUrl) &&
            !string.IsNullOrWhiteSpace(NombreAplicacion) &&
            !string.IsNullOrWhiteSpace(ApiKey);
    }
}
