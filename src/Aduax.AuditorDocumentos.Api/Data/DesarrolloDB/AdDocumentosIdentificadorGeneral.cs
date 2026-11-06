using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    [Table("ad_documentos_identificador_general", Schema = "dbo")]
    public class AdDocumentosIdentificadorGeneral
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public long IdDocumento { get; set; }

        [Required]
        [MaxLength(2)]
        public string Identificador { get; set; } = string.Empty;

        [MaxLength(200)]
        public string? Complemento { get; set; }

        [MaxLength(200)]
        public string? Complemento2 { get; set; }

        [MaxLength(200)]
        public string? Complemento3 { get; set; }

        [ForeignKey(nameof(IdDocumento))]
        public AdDocumentos? Documento { get; set; }
    }
}
