using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    [Table("ad_notif_config", Schema = "dbo")]
    [Index(nameof(IdMotorConfigHeader), IsUnique = true, Name = "UX_ad_notif_config_Unica")]
    public class AdNotifConfig
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long Id { get; set; }

        [Required]
        public long IdMotorConfigHeader { get; set; }

        [Required]
        [MaxLength(1000)]
        public string Correos { get; set; } = string.Empty;

        [Required]
        [MaxLength(100)]
        public string DiasAntesVencimiento { get; set; } = string.Empty;

        [Required]
        public bool RecordarCorreos { get; set; }

        [Required]
        public DateTime FechaCreacion { get; set; }

        [Required]
        [MaxLength(50)]
        public string CreadoPor { get; set; } = string.Empty;

        public DateTime? FechaActualizacion { get; set; }

        [MaxLength(50)]
        public string? ActualizadoPor { get; set; }

        // Navegación
        [ForeignKey(nameof(IdMotorConfigHeader))]
        public AdMotorConfigHeader? MotorConfigHeader { get; set; }
    }
}

