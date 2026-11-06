namespace Aduax.AuditorDocumentos.Api.Services.VertexIA.Models
{
    public class DocumentToAnalize
    {
        public string NombreArchivo { get; set; } = default!;
        public string DocBase64 { get; set; } = default!;
    }
}
