using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    /// <summary>
    /// Historial de cambios de prompts y diccionario de la IA (usuario, fecha y versión).
    /// </summary>
    [Table("ad_ia_config_historial", Schema = "dbo")]
    [Index(nameof(Entidad), nameof(Clave), nameof(Version), Name = "IX_ad_ia_config_historial_Clave")]
    [Index(nameof(Fecha), Name = "IX_ad_ia_config_historial_Fecha")]
    public class AdIaConfigHistorial
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long Id { get; set; }

        [Required]
        [MaxLength(15)]
        public string Entidad { get; set; } = string.Empty;

        [Required]
        [MaxLength(150)]
        public string Clave { get; set; } = string.Empty;

        public long? IdTipoDocumentoVucem { get; set; }

        public int? IdCampo { get; set; }

        [Required]
        public int Version { get; set; }

        [Required]
        [MaxLength(12)]
        public string Accion { get; set; } = string.Empty;

        [Column(TypeName = "VARCHAR(MAX)")]
        public string? ValorAnterior { get; set; }

        [Column(TypeName = "VARCHAR(MAX)")]
        public string? ValorNuevo { get; set; }

        [Required]
        [MaxLength(50)]
        public string Usuario { get; set; } = string.Empty;

        [Required]
        public DateTime Fecha { get; set; }
    }

    public static class AdIaConfigEntidad
    {
        public const string PromptDocumento = "PROMPT_DOC";
        public const string PromptCampo = "PROMPT_CAMPO";
        public const string Diccionario = "DICCIONARIO";
    }

    public static class AdIaConfigAccion
    {
        public const string Alta = "ALTA";
        public const string Cambio = "CAMBIO";
        public const string Eliminacion = "ELIMINACION";
    }
}
