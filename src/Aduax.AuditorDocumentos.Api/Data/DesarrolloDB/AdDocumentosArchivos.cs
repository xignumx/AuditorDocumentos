using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Mvc.ModelBinding.Validation;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    [Table("ad_documentos_archivos", Schema = "dbo")]
    [Index(nameof(IdDocumento), IsUnique = true, Name = "UX_ad_documentos_archivos_Unico")]
    public class AdDocumentosArchivos
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long Id { get; set; }

        [Required]
        public long IdDocumento { get; set; }

        [Required]
        [MaxLength(255)]
        public string NombreArchivo { get; set; } = string.Empty;

        [MaxLength(250)]
        [JsonIgnore]
        [ValidateNever]
        public string NombreEdocs { get; set; } = string.Empty;

        [Required]
        [MaxLength(10)]
        public string Extension { get; set; } = string.Empty;

        [Required]
        public long TamanoBytes { get; set; }

        [Required]
        [MaxLength(500)]
        public string AwsRuta { get; set; } = string.Empty;

        [NotMapped]
        public string DocBase64 { get; set; } = string.Empty;

        // Navegación
        [ForeignKey(nameof(IdDocumento))]
        public AdDocumentos? Documento { get; set; }
    }
}

