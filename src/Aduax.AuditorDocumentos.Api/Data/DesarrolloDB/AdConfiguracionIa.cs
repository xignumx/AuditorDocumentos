using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    [Table("ad_configuacion_ia", Schema = "dbo")]
    public class AdConfiguracionIa
    {
        [Key]
        [MaxLength(50)]
        public string Ia { get; set; } = string.Empty;

        [Required]
        public bool Activo { get; set; }

        [Required]
        [Column(TypeName = "VARCHAR(MAX)")]
        public string Configuracion { get; set; } = string.Empty;

        [Required]
        public DateTime FechaRegistro { get; set; }
    }
}

