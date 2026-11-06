using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.Aduasis
{
    [Table("FCLIENTE", Schema = "dbo")]
    public class FCliente
    {
        [Key]
        [Column("ID_CLIENTE")]
        public string IdCliente { get; set; } = string.Empty;

        [Column("RAZON_SOCIAL")]
        public string RazonSocial { get; set; } = string.Empty;

        [Column("RFC")]
        public string Rfc { get; set; } = string.Empty;

        [Column("cve_cliente")]
        public string CveCliente { get; set; } = string.Empty;
    }
}

