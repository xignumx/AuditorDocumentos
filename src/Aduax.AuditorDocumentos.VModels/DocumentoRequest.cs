namespace Aduax.AuditorDocumentos.VModels
{
    public class DocumentoRequest
    {
        public long IdDocumento { get; set; }
        public string NombreArchivo { get; set; } = string.Empty;
        public string DocBase64 { get; set; } = string.Empty;
    }
}

