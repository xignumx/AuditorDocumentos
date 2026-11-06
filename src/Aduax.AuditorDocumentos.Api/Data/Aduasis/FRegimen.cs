using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.Aduasis
{
    [Table("fregimen", Schema = "dbo")]
    public class FRegimen
    {
        [Key]
        [Column("id_regimen")]
        public string IdRegimen { get; set; } = string.Empty;
        [Column("descripcion_reg")]
        public string DescripcionReg { get; set; } = string.Empty;
        [Column("cve_tipo_operacion")]
        public string CveTipoOperacion { get; set; } = string.Empty;
    }
}
