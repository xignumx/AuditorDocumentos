using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    [Table("ad_motor_config_detalle", Schema = "dbo")]
    [Index(nameof(IdMotorConfigHeader), nameof(IdCampo), IsUnique = true, Name = "UX_ad_motor_config_detalle_CampoUnico")]
    [Index(nameof(IdMotorConfigHeader), nameof(IdCampo), nameof(Visible), nameof(Obligatorio), Name = "IX_ad_motor_config_detalle_Consulta")]
    public class AdMotorConfigDetalle
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long Id { get; set; }

        [Required]
        public long IdMotorConfigHeader { get; set; }

        [Required]
        public int IdCampo { get; set; }

        [Required]
        [MaxLength(100)]
        public string NombreCampo { get; set; } = string.Empty;

        [Required]
        public bool Visible { get; set; }

        [Required]
        public bool Obligatorio { get; set; }

        // Navegación
        [ForeignKey(nameof(IdMotorConfigHeader))]
        public AdMotorConfigHeader? MotorConfigHeader { get; set; }
    }
}

