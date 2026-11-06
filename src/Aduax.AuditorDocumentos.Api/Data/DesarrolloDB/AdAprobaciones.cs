using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    [Table("ad_aprobaciones", Schema = "dbo")]
    [Index(nameof(IdDocumento), IsUnique = true, Name = "UX_ad_aprobaciones_Unica")]
    [Index(nameof(AprobadoPor), nameof(FechaAprobacion), Name = "IX_ad_aprobaciones_Consulta")]
    public class AdAprobaciones
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long Id { get; set; }

        [Required]
        public long IdDocumento { get; set; }

        [Required]
        public int IdResultado { get; set; }

        [MaxLength(500)]
        public string? Motivo { get; set; }

        [Required]
        public DateTime FechaAprobacion { get; set; }

        [Required]
        [MaxLength(50)]
        public string AprobadoPor { get; set; } = string.Empty;

        // Navegación
        [ForeignKey(nameof(IdDocumento))]
        public AdDocumentos? Documento { get; set; }
    }
}

