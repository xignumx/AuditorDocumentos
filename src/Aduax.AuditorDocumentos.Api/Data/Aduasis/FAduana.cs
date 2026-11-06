using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.Aduasis
{
    [Table("faduana", Schema = "dbo")]
    public class FAduana
    {
        [Column("id_aduana")]
        public string IdAduana { get; set; } = string.Empty;

        [Column("seccion_aduana")]
        public string SeccionAduana { get; set; } = string.Empty;

        [Column("descripcion_oficial")]
        public string? DescripcionOficial { get; set; }

        /// <summary>
        /// Propiedad calculada que concatena id_aduana + seccion_aduana.
        /// No se mapea a la base de datos.
        /// </summary>
        [NotMapped]
        public string Aduana => IdAduana + SeccionAduana;

        /// <summary>
        /// Propiedad calculada que devuelve descripcion_oficial o '-' si es null.
        /// No se mapea a la base de datos.
        /// </summary>
        [NotMapped]
        public string Descripcion => DescripcionOficial ?? "-";
    }
}

