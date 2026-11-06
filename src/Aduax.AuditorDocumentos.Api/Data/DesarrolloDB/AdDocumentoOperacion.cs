using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    [Table("ad_documento_operacion", Schema = "dbo")]
    [Index(nameof(id_referencia), nameof(pedimento), nameof(id_rectificacion), Name = "IX_ad_documento_operacion_Busqueda")]
    public class AdDocumentoOperacion
    {
        [Key]
        [DatabaseGenerated(DatabaseGeneratedOption.Identity)]
        public long Id { get; set; }

        [Required]
        public long IdDocumento { get; set; }

        [Required]
        [MaxLength(10)]
        [Column("id_referencia")]
        public string id_referencia { get; set; } = string.Empty;

        [Column("id_rectificacion", TypeName = "DECIMAL(1,0)")]
        public decimal? id_rectificacion { get; set; }

        [MaxLength(16)]
        public string? pedimento { get; set; } = string.Empty;

        [Required]
        public DateTime FechaAsociacion { get; set; }

        [Required]
        [MaxLength(50)]
        public string AsociadoPor { get; set; } = string.Empty;

        [NotMapped]
        public string? Edocument { get; set; }

        [NotMapped]
        public string? Numero { get; set; }

        [NotMapped]
        public string? Mensaje { get; set; }

        /// <summary>Indica si el pedimento tiene fecha_pago_banco (viene del SP, no mapeado a tabla).</summary>
        [NotMapped]
        public bool EstaPagado { get; set; }

        // Navegación
        [ForeignKey(nameof(IdDocumento))]
        public AdDocumentos? Documento { get; set; }
    }
}

