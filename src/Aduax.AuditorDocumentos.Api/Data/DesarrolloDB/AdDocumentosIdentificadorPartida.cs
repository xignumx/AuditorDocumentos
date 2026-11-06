using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    [Table("ad_documentos_identificador_partida", Schema = "dbo")]
    public class AdDocumentosIdentificadorPartida
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.None)]
        public long IdDocumento { get; set; }

        [Required(AllowEmptyStrings = true)]
        [MaxLength(2)]
        public string Regimen { get; set; } = string.Empty;

        [MaxLength(200)]
        public string? TipoAdvalorem { get; set; } = null;

        [MaxLength(200)]
        public string? Origen { get; set; } = null;

        [Required]
        public string Identificador { get; set; } = default!;

        [MaxLength(50)]
        public string? Complemento1 { get; set; } = null;

        [MaxLength(50)]
        public string? Complemento2 { get; set; } = null;

        [MaxLength(50)]
        public string? Complemento3 { get; set; } = null;

        [ForeignKey(nameof(IdDocumento))]
        public AdDocumentos? Documento { get; set; }
    }
}
