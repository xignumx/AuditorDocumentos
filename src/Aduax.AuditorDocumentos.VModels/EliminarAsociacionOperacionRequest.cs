namespace Aduax.AuditorDocumentos.VModels
{
    public class EliminarAsociacionOperacionRequest
    {
        public long IdDocumento { get; set; }
        public string IdReferencia { get; set; } = string.Empty;
        public int? IdRectificacion { get; set; }
    }
}
