using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    [Table("ad_documentos_campos", Schema = "dbo")]
    [Index(nameof(IdDocumento), nameof(IdCampo), IsUnique = true, Name = "UX_ad_documentos_campos_Unico")]
    [Index(nameof(IdDocumento), Name = "IX_ad_documentos_campos_Documento")]
    public class AdDocumentosCampos
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long Id { get; set; }

        [Required]
        public long IdDocumento { get; set; }

        [Required]
        public int IdCampo { get; set; }

        public string? Valor { get; set; }

        // Navegación
        [ForeignKey(nameof(IdDocumento))]
        public AdDocumentos? Documento { get; set; }
    }
}

