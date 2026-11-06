using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    [Table("ad_bitacora_eventos", Schema = "dbo")]
    [Index(nameof(IdDocumento), nameof(FechaEvento), Name = "IX_ad_bitacora_eventos_Documento")]
    [Index(nameof(IdTipoEvento), nameof(FechaEvento), Name = "IX_ad_bitacora_eventos_Tipo")]
    public class AdBitacoraEventos
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long Id { get; set; }

        [Required]
        public long IdDocumento { get; set; }

        [Required]
        public int IdTipoEvento { get; set; }

        [Required]
        [MaxLength(500)]
        public string DescripcionEvento { get; set; } = string.Empty;

        [MaxLength(1000)]
        public string? DatosAdicionales { get; set; }

        [Required]
        public DateTime FechaEvento { get; set; }

        [Required]
        [MaxLength(50)]
        public string UsuarioEvento { get; set; } = string.Empty;

        // Navegación
        [ForeignKey(nameof(IdDocumento))]
        public AdDocumentos? Documento { get; set; }
    }
}