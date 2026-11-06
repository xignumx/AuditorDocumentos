namespace Aduax.AuditorDocumentos.VModels
{
    public class VucemSellosLookupDto
    {
        public int IdSelloCliente { get; set; }
        public int IdSelloAduana { get; set; }
        public string? Patente { get; set; }
        public string? RfcCliente { get; set; }
        public string? RfcPatente { get; set; }
    }
}
