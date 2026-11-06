using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    /// <summary>
    /// Entidad que mapea el resultado del SP csp_AD_GetTraficoPorReferencia.
    /// </summary>
    public class CspAdGetTraficoPorReferencia
    {
        [Column("id_trafico")]
        public string IdTrafico { get; set; } = string.Empty;
    }
}
