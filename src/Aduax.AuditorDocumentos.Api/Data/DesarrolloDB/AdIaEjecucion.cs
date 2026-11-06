using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    [Table("ad_ia_ejecucion", Schema = "dbo")]
    [Index(nameof(IdDocumento), nameof(ProveedorIA), nameof(ModeloIA), Name = "IX_ad_ia_ejecucion_Documento")]
    public class AdIaEjecucion
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long Id { get; set; }

        [Required]
        public long IdDocumento { get; set; }

        [MaxLength(50)]
        public string? ProveedorIA { get; set; }

        [Required]
        [MaxLength(100)]
        public string ModeloIA { get; set; } = string.Empty;

        [Required]
        [Column(TypeName = "VARCHAR(MAX)")]
        public string PromptEntrada { get; set; } = string.Empty;

        [Column(TypeName = "VARCHAR(MAX)")]
        public string? JsonResultado { get; set; }

        // Navegación
        [ForeignKey(nameof(IdDocumento))]
        public AdDocumentos? Documento { get; set; }
    }
}


