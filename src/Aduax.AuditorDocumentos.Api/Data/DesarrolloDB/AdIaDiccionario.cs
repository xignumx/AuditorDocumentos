using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    /// <summary>
    /// Diccionario de sinónimos (GENERAL) y equivalencias de unidad de medida (UM). Una fila por término.
    /// </summary>
    [Table("ad_ia_diccionario", Schema = "dbo")]
    [Index(nameof(Categoria), nameof(Termino), IsUnique = true, Name = "UX_ad_ia_diccionario_Termino")]
    [Index(nameof(Categoria), nameof(Concepto), Name = "IX_ad_ia_diccionario_Concepto")]
    public class AdIaDiccionario
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long Id { get; set; }

        [Required]
        [MaxLength(10)]
        public string Categoria { get; set; } = string.Empty;

        [Required]
        [MaxLength(100)]
        public string Concepto { get; set; } = string.Empty;

        public int? IdCampo { get; set; }

        [Required]
        [MaxLength(200)]
        public string Termino { get; set; } = string.Empty;

        [Required]
        [MaxLength(2)]
        public string Idioma { get; set; } = string.Empty;

        [Required]
        public DateTime FechaCreacion { get; set; }

        [Required]
        [MaxLength(50)]
        public string CreadoPor { get; set; } = string.Empty;

        public DateTime? FechaActualizacion { get; set; }

        [MaxLength(50)]
        public string? ActualizadoPor { get; set; }
    }
}
