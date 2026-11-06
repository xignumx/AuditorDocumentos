using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using Microsoft.EntityFrameworkCore;
using Aduax.AuditorDocumentos.VModels;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    /// <summary>
    /// Entidad que mapea el resultado del SP csp_Ad_DocumentosPorEstatus.
    /// </summary>
    public class CspAdDocumentosPorEstatus
    {
        [Key]
        public long Id { get; set; }

        public string IdCliente { get; set; } = string.Empty;

        public DateTime FechaCreacion { get; set; }

        public string CreadoPor { get; set; } = string.Empty;

        public int IdTipoDocumentoVucem { get; set; }

        public string? PrefijoEI { get; set; }

        [Column("Id_Vucem")]
        public int IdVucem { get; set; }

        public string DocumentoVucem { get; set; } = string.Empty;

        public string NombreArchivo { get; set; } = string.Empty;

        public string AwsRuta { get; set; } = string.Empty;

        public DateTime? FechaVigenciaInicio { get; set; }

        public DateTime? FechaVigenciaFin { get; set; }

        public int IdClasificacion { get; set; }

        public string Clasificacion { get; set; } = string.Empty;

        public int IdEstatus { get; set; }

        public string Estatus { get; set; } = string.Empty;

        public string ComentarioRechazo { get; set; } = string.Empty;

        [NotMapped]
        public bool PuedeAccionCritica { get; set; }
    }
}



