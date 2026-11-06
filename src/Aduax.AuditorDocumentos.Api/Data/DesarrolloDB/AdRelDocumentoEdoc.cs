using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    [Table("ad_rel_documento_edoc", Schema = "dbo")]
    public class AdRelDocumentoEdoc
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        [Required]
        public long IdDocumento { get; set; }

        [Required]
        [Column("Id_Archivo")]
        public int IdArchivo { get; set; }

        [Required]
        public DateTime FechaRegistro { get; set; }

        [Required]
        [MaxLength(50)]
        public string CreadoPor { get; set; } = string.Empty;

        public int? IdSelloEdoc { get; set; }

        [ForeignKey(nameof(IdDocumento))]
        public AdDocumentos? Documento { get; set; }
    }
}
