using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    [Table("ad_notif_template", Schema = "dbo")]
    [Index(nameof(Version), IsUnique = true, Name = "UX_ad_notif_template_Version")]
    public class AdNotifTemplate
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public int Id { get; set; }

        [Required]
        [Column(TypeName = "NVARCHAR(MAX)")]
        public string Html { get; set; } = string.Empty;

        [Required]
        [MaxLength(300)]
        public string Descripcion { get; set; } = string.Empty;

        [Required]
        public int Version { get; set; }

        [Required]
        public bool Activo { get; set; }

        [Required]
        public DateTime FechaCreacion { get; set; }
    }
}
