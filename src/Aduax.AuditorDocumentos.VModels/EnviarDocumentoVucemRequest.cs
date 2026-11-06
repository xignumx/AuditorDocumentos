namespace Aduax.AuditorDocumentos.VModels
{
    public class EnviarDocumentoVucemRequest
    {
        public long IdDocumento { get; set; }
        public string IdReferencia { get; set; } = string.Empty;
        public decimal? IdRectificacion { get; set; }
        public string OrigenSello { get; set; } = string.Empty;
        public string? CorreoElectronico { get; set; }
    }
}
