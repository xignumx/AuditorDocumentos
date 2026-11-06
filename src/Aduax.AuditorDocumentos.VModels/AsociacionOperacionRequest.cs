namespace Aduax.AuditorDocumentos.VModels
{
    public class AsociacionOperacionRequest
    {
        public long IdDocumento { get; set; }
        public string IdReferencia { get; set; } = string.Empty;
        public int? IdRectificacion { get; set; }
        public string? Pedimento { get; set; }
        public bool AfectaOperacion { get; set; }
    }
}
