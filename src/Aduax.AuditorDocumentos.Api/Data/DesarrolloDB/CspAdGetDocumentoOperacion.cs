using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    /// <summary>
    /// Resultado del SP csp_Ad_GetDocumentoOperacion (operación + eDocument desde EDOCS).
    /// </summary>
    public class CspAdGetDocumentoOperacion
    {
        public long IdDocumento { get; set; }

        [Column("id_referencia")]
        public string id_referencia { get; set; } = string.Empty;

        [Column("id_rectificacion")]
        public decimal? id_rectificacion { get; set; }

        public string? pedimento { get; set; }

        public string? Edocument { get; set; }

        public string? Numero { get; set; }

        public string? Mensaje { get; set; }

        /// <summary>
        /// true si fpedimento.fecha_pago_banco tiene valor (columna BIT o 0/1 del SP).
        /// </summary>
        public bool EstaPagado { get; set; }
    }
}
