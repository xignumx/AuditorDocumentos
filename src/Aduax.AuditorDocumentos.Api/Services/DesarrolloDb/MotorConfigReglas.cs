using Aduax.AuditorDocumentos.Api.Data.DesarrolloDB;
using Aduax.AuditorDocumentos.VModels;

namespace Aduax.AuditorDocumentos.Api.Services.DesarrolloDb
{
    /// <summary>
    /// Reglas del motor de configuración compartidas por el guardado manual (/config) y la carga masiva.
    /// </summary>
    public static class MotorConfigReglas
    {
        /// <summary>
        /// Detalle con los valores por defecto de un campo nuevo: visible salvo los campos agregados en 07/2026
        /// (Factura, Fecha factura, Valor USD, Guía/BL y Pedimento); único obligatorio: Vigencia hasta.
        /// </summary>
        public static AdMotorConfigDetalle CrearDetalleDefault(AdCampos campo)
        {
            bool esCampoNuevo072026 = campo is AdCampos.Factura or AdCampos.FechaFactura or AdCampos.ValorUsd
                or AdCampos.GuiaBl or AdCampos.Pedimento;

            return new AdMotorConfigDetalle
            {
                IdCampo = (int)campo,
                NombreCampo = Enum.GetName(typeof(AdCampos), campo) ?? campo.ToString(),
                Visible = !esCampoNuevo072026,
                Obligatorio = campo == AdCampos.VigenciaHasta
            };
        }

        /// <summary>
        /// Validaciones del motor: al menos un campo visible distinto de IdCliente, RfcCliente y TipoPedimento,
        /// y al menos un campo visible obligatorio. Lanza <see cref="InvalidOperationException"/>.
        /// </summary>
        public static void ValidarDetalles(ICollection<AdMotorConfigDetalle>? detalles)
        {
            if (detalles == null || !detalles.Any())
            {
                throw new InvalidOperationException("Debe existir al menos un detalle en la configuración");
            }

            bool tieneCampoVisibleDiferente = detalles.Any(d =>
                d.Visible &&
                d.IdCampo != (int)AdCampos.IdCliente &&
                d.IdCampo != (int)AdCampos.RfcCliente &&
                d.IdCampo != (int)AdCampos.TipoPedimento);

            if (!tieneCampoVisibleDiferente)
            {
                throw new InvalidOperationException("Debe existir al menos un campo visible diferente de TipoPedimento");
            }

            bool tieneCampoVisibleObligatorio = detalles.Any(d => d.Visible && d.Obligatorio);

            if (!tieneCampoVisibleObligatorio)
            {
                throw new InvalidOperationException("Al menos uno de los campos visibles debe ser obligatorio");
            }
        }

        /// <summary>
        /// Foto de los parámetros auditables del motor: header y Visible/Obligatorio por campo.
        /// </summary>
        public static Dictionary<string, string> ConstruirParametros(AdMotorConfigHeader header)
        {
            static string SiNo(bool valor) => valor ? "Sí" : "No";

            var parametros = new Dictionary<string, string>
            {
                ["IdClasificacion"] = header.IdClasificacion.ToString(),
                ["AccionPedimento"] = header.AccionPedimento ?? string.Empty,
                ["PerfilCarga"] = header.PerfilCarga ?? string.Empty,
                ["Activo"] = SiNo(header.Activo)
            };

            if (header.Detalles != null)
            {
                foreach (var detalle in header.Detalles)
                {
                    var nombre = string.IsNullOrWhiteSpace(detalle.NombreCampo)
                        ? detalle.IdCampo.ToString()
                        : detalle.NombreCampo;
                    parametros[$"Campo:{nombre}.Visible"] = SiNo(detalle.Visible);
                    parametros[$"Campo:{nombre}.Obligatorio"] = SiNo(detalle.Obligatorio);
                }
            }

            return parametros;
        }
    }
}
