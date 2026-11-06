using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    [Table("ad_motor_config_header", Schema = "dbo")]
    [Index(nameof(IdCliente), nameof(IdTipoDocumentoVucem), Name = "IX_ad_motor_config_header_Consulta")]
    public class AdMotorConfigHeader
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long Id { get; set; }

        [Required]
        [MaxLength(6)]
        public string IdCliente { get; set; } = string.Empty;

        [Required]
        public int IdTipoDocumentoVucem { get; set; }

        [Required]
        public int IdClasificacion { get; set; }

        [Required]
        [MaxLength(2)]
        public string AccionPedimento { get; set; } = "P";

        /// <summary>
        /// Perfil para acciones críticas: G=general, A=admin, L=líder.
        /// </summary>
        [Required]
        [MaxLength(1)]
        public string PerfilCarga { get; set; } = "G";

        [Required]
        public bool Activo { get; set; }

        [Required]
        public DateTime FechaCreacion { get; set; }

        [Required]
        [MaxLength(50)]
        public string CreadoPor { get; set; } = string.Empty;

        public DateTime? FechaActualizacion { get; set; }

        [MaxLength(50)]
        public string? ActualizadoPor { get; set; }

        [MaxLength(500)]
        public string? MotivoCambio { get; set; }

        // Navegación
        public ICollection<AdMotorConfigDetalle>? Detalles { get; set; }
    }
}

