namespace Aduax.AuditorDocumentos.Api.Services.FileStorage.Models
{
    public class RespuestaAutenticacion
    {
        public string token { get; set; } = default!;
        public string expiracion { get; set; } = default!;
    }
}
