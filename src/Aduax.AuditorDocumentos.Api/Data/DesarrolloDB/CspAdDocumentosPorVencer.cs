using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    /// <summary>
    /// Entidad que mapea el resultado del SP csp_Ad_ObtieneDocumentosPorVencer.
    /// </summary>
    public class CspAdDocumentosPorVencer
    {
        [Key]
        public long Id { get; set; }

        public int IdTipoDocumentoVucem { get; set; }

        public long IdMotorConfigHeader { get; set; }

        public string Documento { get; set; } = string.Empty;

        public string IdCliente { get; set; } = string.Empty;

        public string NombreArchivo { get; set; } = string.Empty;

        public string AwsRuta { get; set; } = string.Empty;

        public DateTime? FechaVigenciaInicio { get; set; }

        public DateTime? FechaVigenciaFin { get; set; }

        public string CreadoPor { get; set; } = string.Empty;
    }
}
