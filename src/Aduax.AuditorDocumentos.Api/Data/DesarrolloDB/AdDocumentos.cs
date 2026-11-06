using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    [Table("ad_documentos", Schema = "dbo")]
    [Index(nameof(IdCliente), nameof(IdEstatus), nameof(IdTipoDocumentoVucem), nameof(FechaCreacion), Name = "IX_ad_documentos_Consulta")]
    [Index(nameof(IdCliente), nameof(FechaVigenciaFin), nameof(IdEstatus), Name = "IX_ad_documentos_Vigencias")]
    [Index(nameof(CreadoPor), nameof(FechaCreacion), Name = "IX_ad_documentos_CreadoPor")]
    public class AdDocumentos
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
        public long IdMotorConfigHeader { get; set; }

        [Required]
        public int IdEstatus { get; set; }

        public DateTime? FechaVigenciaInicio { get; set; }

        public DateTime? FechaVigenciaFin { get; set; }

        [MaxLength(500)]
        public string? Observaciones { get; set; }

        [MaxLength(500)]
        public string? ComentarioRechazo { get; set; }

        [Required]
        public DateTime FechaCreacion { get; set; }

        [Required]
        [MaxLength(50)]
        public string CreadoPor { get; set; } = string.Empty;

        public DateTime? FechaActualizacion { get; set; }

        [MaxLength(50)]
        public string? ActualizadoPor { get; set; }

        [ForeignKey(nameof(IdMotorConfigHeader))]
        public AdMotorConfigHeader? MotorConfigHeader { get; set; }

        public ICollection<AdDocumentosCampos>? Campos { get; set; }
        public AdDocumentosArchivos? Archivo { get; set; }
        public AdDocumentosIdentificadorGeneral? IdentificadorGeneral { get; set; }
        public AdDocumentosIdentificadorPartida? IdentificadorPartida { get; set; }
        public AdDocumentosPermiso? Permiso { get; set; }
        public ICollection<AdDocumentoOperacion>? Operaciones { get; set; }
    }
}

