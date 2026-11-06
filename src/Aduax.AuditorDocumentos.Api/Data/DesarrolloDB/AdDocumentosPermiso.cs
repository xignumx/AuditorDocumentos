using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    [Table("ad_documentos_permiso", Schema = "dbo")]
    public class AdDocumentosPermiso
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public long IdDocumento { get; set; }

        [Required]
        [MaxLength(2)]
        public string Regimen { get; set; } = string.Empty;

        [Required]
        [MaxLength(2)]
        public string Permiso { get; set; } = string.Empty;

        [MaxLength(200)]
        public string? Numero { get; set; }

        [MaxLength(200)]
        public string? Firma { get; set; }

        [ForeignKey(nameof(IdDocumento))]
        public AdDocumentos? Documento { get; set; }
    }
}
