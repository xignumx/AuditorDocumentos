using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.Aduasis
{
    [Table("FUSUARIO", Schema = "dbo")]
    public class FUsuario
    {
        [Key]
        [Column("id_usuario")]
        public string IdUsuario { get; set; } = string.Empty;

        [Column("id_clase")]
        public string IdClase { get; set; } = string.Empty;

        [Column("usuario")]
        public string Usuario { get; set; } = string.Empty;

        [Column("correo_electronico")]
        public string CorreoElectronico { get; set; } = string.Empty;
    }
}
