namespace Aduax.AuditorDocumentos.VModels
{
    public class SugerenciaPedimentosRequest
    {
        public long IdAdDocumento { get; set; }

        /// <summary>
        /// Búsqueda opcional por pedimento, referencia o id. de tráfico.
        /// Omitido en SP cuando el atajo AdCampos.Pedimento (24) está activo en el documento.
        /// </summary>
        public string? OperacionBusqueda { get; set; }
    }
}
