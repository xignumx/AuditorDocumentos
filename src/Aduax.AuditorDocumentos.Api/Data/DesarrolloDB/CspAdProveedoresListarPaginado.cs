using System.ComponentModel.DataAnnotations;

namespace Aduax.AuditorDocumentos.Api.Data.DesarrolloDB
{
    /// <summary>
    /// Entidad que mapea el resultado del SP ad_proveedores_listar_paginado.
    /// </summary>
    public class CspAdProveedoresListarPaginado
    {
        public int TotalRows { get; set; }

        [Key]
        public string IdProveedor { get; set; }

        public string Proveedor { get; set; } = string.Empty;
    }
}
