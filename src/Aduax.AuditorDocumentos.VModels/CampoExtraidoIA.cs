namespace Aduax.AuditorDocumentos.VModels
{
    /// <summary>
    /// Representa un campo extra�do por la IA con su identificador y valor.
    /// </summary>
    public class CampoExtraidoIA
    {
        public int IdCampo { get; set; }
        public string NombreCampo { get; set; } = string.Empty;
        public object? Valor { get; set; }
    }
}
