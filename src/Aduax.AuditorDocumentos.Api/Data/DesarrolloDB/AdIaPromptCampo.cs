using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    [Table("ad_ia_prompt_campo", Schema = "dbo")]
    [Index(nameof(IdTipoDocumentoVucem), nameof(IdCampo), IsUnique = true, Name = "UX_ad_ia_prompt_campo_Unico")]
    [Index(nameof(IdTipoDocumentoVucem), nameof(Activo), Name = "IX_ad_ia_prompt_campo_Consulta")]
    public class AdIaPromptCampo
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long Id { get; set; }

        [Required]
        public long IdTipoDocumentoVucem { get; set; }

        [Required]
        public int IdCampo { get; set; }

        [Required]
        [MaxLength(100)]
        public string NombreCampo { get; set; } = string.Empty;

        [Required]
        [MaxLength(2000)]
        public string PromptParcial { get; set; } = string.Empty;

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

