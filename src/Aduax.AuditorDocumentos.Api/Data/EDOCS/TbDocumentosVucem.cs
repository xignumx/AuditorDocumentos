using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.EDOCS
{
    [Table("Tb_DocumentosVucem", Schema = "dbo")]
    public class TbDocumentosVucem
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        [Column("Id_DocumentoVucem")]
        public int Id_DocumentoVucem { get; set; }

        [Column("id_Cliente")]
        public int? id_Cliente { get; set; }

        [Required]
        [MaxLength(150)]
        public string Documento { get; set; } = string.Empty;

        [Required]
        [Column("Id_Vucem")]
        public int Id_Vucem { get; set; }

        [Required]
        [Column("Id_TipoDocumento")]
        public int Id_TipoDocumento { get; set; }

        [Column("bit_Requerido")]
        public int? bit_Requerido { get; set; }

        public int? Operativo { get; set; }

        public int? Administrativo { get; set; }

        [MaxLength(150)]
        public string? NombreAnterior { get; set; }

        [MaxLength(10)]
        public string? PrefijoEI { get; set; }

        [Required]
        public int Activo { get; set; }

        [Required]
        public bool ActivoAuditorDocumentos { get; set; }
    }
}

