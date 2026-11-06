using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    [Table("ad_notif_envios", Schema = "dbo")]
    [Index(nameof(IdDocumento), nameof(FechaEnvio), Name = "IX_ad_notif_envios_Documento")]
    [Index(nameof(FechaEnvio), nameof(IdResultado), Name = "IX_ad_notif_envios_Fecha")]
    public class AdNotifEnvios
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long Id { get; set; }

        [Required]
        public long IdDocumento { get; set; }

        [Required]
        public DateTime FechaEnvio { get; set; }

        [Required]
        [MaxLength(1000)]
        public string CorreosDestino { get; set; } = string.Empty;

        [Required]
        public int DiasAntesVencimiento { get; set; }

        [Required]
        public int IdResultado { get; set; }

        [MaxLength(500)]
        public string? MensajeError { get; set; }

        [Required]
        [MaxLength(50)]
        public string CreadoPor { get; set; } = string.Empty;

        // Navegación
        [ForeignKey(nameof(IdDocumento))]
        public AdDocumentos? Documento { get; set; }
    }
}

