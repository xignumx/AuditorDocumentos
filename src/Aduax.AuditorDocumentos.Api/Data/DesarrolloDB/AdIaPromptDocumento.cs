using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    [Table("ad_ia_prompt_documento", Schema = "dbo")]
    [Index(nameof(IdTipoDocumentoVucem), nameof(Activo), Name = "IX_ad_ia_prompt_documento_Consulta")]
    public class AdIaPromptDocumento
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long Id { get; set; }

        [Required]
        public long IdTipoDocumentoVucem { get; set; }

        [Required]
        [MaxLength(5000)]
        public string Prompt { get; set; } = string.Empty;

        [Required]
        public bool Activo { get; set; }

        [Required]
        public DateTime FechaCreacion { get; set; }

        [Required]
        [MaxLength(50)]
        public string CreadoPor { get; set; } = string.Empty;

        public DateTime? FechaActualizacion { get; set; }

        [MaxLength(50)]
        public string? ActualizadoPor { get; set; }
    }
}

