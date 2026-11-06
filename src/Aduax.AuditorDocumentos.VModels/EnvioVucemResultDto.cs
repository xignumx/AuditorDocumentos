namespace Aduax.AuditorDocumentos.VModels
{
    public class EnvioVucemResultDto
    {
        public int IdArchivo { get; set; }
        public int? IdEnvio { get; set; }
        public string? NumeroOperacion { get; set; }
        public string? Mensaje { get; set; }
        public int? EstadoJob { get; set; }
        public bool EsExitoso { get; set; }
        public long? TiempoEjecucionMs { get; set; }
    }
}
