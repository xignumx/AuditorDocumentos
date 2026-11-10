using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    /// <summary>
    /// Bitácora de auditoría de cambios en la configuración del motor. Una fila por parámetro modificado.
    /// </summary>
    [Table("ad_motor_config_bitacora", Schema = "dbo")]
    [Index(nameof(IdMotorConfigHeader), nameof(FechaCambio), Name = "IX_ad_motor_config_bitacora_Header")]
    [Index(nameof(IdCliente), nameof(IdTipoDocumentoVucem), nameof(FechaCambio), Name = "IX_ad_motor_config_bitacora_ClienteTipo")]
    public class AdMotorConfigBitacora
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long Id { get; set; }

        [Required]
        public long IdMotorConfigHeader { get; set; }

        [Required]
        [MaxLength(6)]
        public string IdCliente { get; set; } = string.Empty;

        [Required]
        public int IdTipoDocumentoVucem { get; set; }

        [Required]
        [MaxLength(100)]
        public string Parametro { get; set; } = string.Empty;

        [MaxLength(200)]
        public string? ValorAnterior { get; set; }

        [MaxLength(200)]
        public string? ValorNuevo { get; set; }

        [Required]
        [MaxLength(10)]
        public string Origen { get; set; } = AdMotorConfigBitacoraOrigen.Manual;

        [MaxLength(500)]
        public string? MotivoCambio { get; set; }

        [Required]
        [MaxLength(50)]
        public string UsuarioCambio { get; set; } = string.Empty;

        [Required]
        public DateTime FechaCambio { get; set; }
    }

    public static class AdMotorConfigBitacoraOrigen
    {
        public const string Manual = "MANUAL";
        public const string Masiva = "MASIVA";
    }
}
