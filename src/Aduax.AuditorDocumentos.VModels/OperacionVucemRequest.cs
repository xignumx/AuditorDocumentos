namespace Aduax.AuditorDocumentos.VModels
{
    public class OperacionVucemRequest
    {
        public long IdDocumento { get; set; }
        public string IdReferencia { get; set; } = string.Empty;
        public decimal? IdRectificacion { get; set; }
    }
}
