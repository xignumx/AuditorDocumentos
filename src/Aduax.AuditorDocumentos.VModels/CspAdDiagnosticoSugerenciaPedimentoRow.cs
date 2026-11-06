namespace Aduax.AuditorDocumentos.VModels
{
    /// <summary>
    /// Fila devuelta por csp_Ad_DiagnosticoSugerenciaPedimentos (SELECT final).
    /// </summary>
    public class CspAdDiagnosticoSugerenciaPedimentoRow
    {
        public string? Validacion { get; set; }
        public string? Resultado { get; set; }
        public string? DetalleDocumento { get; set; }
        public string? DetallePedimento { get; set; }
    }
}
