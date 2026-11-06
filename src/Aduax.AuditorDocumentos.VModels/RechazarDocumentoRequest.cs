namespace Aduax.AuditorDocumentos.VModels
{
    public class RechazarDocumentoRequest
    {
        public long IdDocumento { get; set; }
        public string MotivoRechazo { get; set; } = string.Empty;
    }
}

