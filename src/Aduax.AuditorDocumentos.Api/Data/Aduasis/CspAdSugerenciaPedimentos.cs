using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.Aduasis
{
    /// <summary>
    /// Entidad que mapea el resultado del SP csp_Ad_SugerenciaPedimentos.
    /// </summary>
    public class CspAdSugerenciaPedimentos
    {
        [Column("id_referencia")]
        public string IdReferencia { get; set; } = string.Empty;

        [Column("id_rectificacion")]
        public int? IdRectificacion { get; set; }

        [Column("patente")]
        public string Patente { get; set; } = string.Empty;

        [Column("aduana")]
        public string Aduana { get; set; } = string.Empty;

        [Column("pedimento")]
        public string? Pedimento { get; set; }

        [Column("tipo_operacion")]
        public string TipoOperacion { get; set; } = string.Empty;

        [Column("clave_pedimento")]
        public string ClavePedimento { get; set; } = string.Empty;

        public int TotalRecords { get; set; }
    }
}
