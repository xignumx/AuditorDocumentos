namespace Aduax.AuditorDocumentos.VModels
{
    /// <summary>
    /// Resultado del SP csp_ad_InsertaDatosPedimento_v2 (columnas del SELECT final).
    /// Resultado: con clasificación identificador general (1) es 1 si el SP completó; con partida (2) o permiso (3)
    /// es 1 solo si hubo al menos un INSERT/UPDATE contado en esos bloques (tráfico o pedimento).
    /// </summary>
    public class InsertarDatosPedimentoResultDto
    {
        public bool Resultado { get; set; }

        public string MensajeEjecucion { get; set; } = string.Empty;
    }
}
