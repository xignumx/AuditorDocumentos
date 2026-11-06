using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    [Table("ad_cat_eventos", Schema = "dbo")]
    [Index(nameof(Clave), IsUnique = true, Name = "UQ_ad_cat_eventos_Clave")]
    public class AdCatEventos
    {
        [Key]
        public int Id { get; set; }

        [Required]
        [MaxLength(50)]
        public string Clave { get; set; } = string.Empty;

        [Required]
        [MaxLength(200)]
        public string Descripcion { get; set; } = string.Empty;

        [Required]
        [MaxLength(50)]
        public string Categoria { get; set; } = string.Empty;

        [Required]
        public bool Activo { get; set; }
    }
}


