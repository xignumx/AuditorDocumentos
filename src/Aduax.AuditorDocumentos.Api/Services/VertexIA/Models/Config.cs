namespace Aduax.AuditorDocumentos.Api.Services.VertexIA.Models
{
    public class Config
    {
        public string ProjectId { get; set; } = default!;
        public string ProjectAlias { get; set; } = default!;
        public string Bucket { get; set; } = default!;
        public string LocationId { get; set; } = default!;
        public string JsonCredentials { get; set; } = default!;
        public string VertexModel { get; set; } = default!;
        public double VertexTemperature { get; set; }
        public int VertexMaxOutputTokens { get; set; }
        public double VertexTopP { get; set; }
        public double VertexTopK { get; set; }

        /// <summary>
        /// Configuración para el manejo de archivos grandes (XL): los PDF que superan cierto
        /// número de páginas se envían a Vertex por rangos (grupos de páginas) manteniendo el contexto.
        /// Si se omite en el JSON, el troceo queda habilitado con los valores por defecto internos.
        /// </summary>
        public ArchivosGrandesConfig? ArchivosGrandes { get; set; }
    }

    /// <summary>
    /// Parámetros del envío por rangos de páginas para documentos PDF grandes (XL).
    /// </summary>
    public class ArchivosGrandesConfig
    {
        /// <summary>
        /// Habilita/deshabilita el troceo por rangos de páginas. Por defecto habilitado
        /// (si el objeto no viene en el JSON, se asume habilitado).
        /// </summary>
        public bool Habilitado { get; set; } = true;

        /// <summary>
        /// PDF con más páginas que este valor se envían por rangos.
        /// Si es 0 se usa el valor por defecto interno.
        /// </summary>
        public int MaxPaginasEnvioUnico { get; set; }

        /// <summary>
        /// Número de páginas por cada parte cuando el PDF se envía por rangos.
        /// Si es 0 se usa el valor por defecto interno.
        /// </summary>
        public int PaginasPorGrupo { get; set; }
    }
}
