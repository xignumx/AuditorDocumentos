using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    /// <summary>
    /// Resultado de csp_Ad_GetPatenteRfcClienteByRelOperacion (RFC importador, patente y RFC del agente).
    /// </summary>
    public class CspAdGetPatenteRfcClienteRow
    {
        public string? RfcCliente { get; set; }

        public string? Patente { get; set; }

        public string? RfcPatente { get; set; }
    }
}
