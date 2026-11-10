namespace Aduax.AuditorDocumentos.VModels
{
    /// <summary>
    /// Reglas de acceso a la configuración del motor según IdClase (FUsuario en ADUASIS).
    /// Punto único de decisión: el origen del rol COMPLIANCE sigue abierto y se integra aquí.
    /// </summary>
    public static class AdRolesConfiguracion
    {
        public const string Adm = "ADM";
        public const string Lider = "LIDER";
        public const string Calidad = "CALIDAD";
        public const string Compliance = "COMPLIANCE";

        /// <summary>
        /// Usuario con acceso total heredado del código previo (ValidaUsuarioAdminLider).
        /// También permite probar las pantallas exclusivas de COMPLIANCE mientras el rol no exista en ADUASIS.
        /// </summary>
        public const string UsuarioSoporte = "mxochipa";

        /// <summary>
        /// /config por cliente: ADM, LIDER, CALIDAD (sin cambios) y COMPLIANCE.
        /// </summary>
        public static bool PuedeAdministrarConfigPorCliente(string? usuario, string? idClase)
        {
            return EsUsuarioSoporte(usuario)
                || EsClase(idClase, Adm)
                || EsClase(idClase, Lider)
                || EsClase(idClase, Calidad)
                || EsClase(idClase, Compliance);
        }

        /// <summary>
        /// Pantallas y endpoints exclusivos de Compliance (reglas IA, defaults por tipo, carga masiva de matriz).
        /// </summary>
        public static bool PuedeAdministrarReglasCompliance(string? usuario, string? idClase)
        {
            return EsUsuarioSoporte(usuario) || EsClase(idClase, Compliance);
        }

        public static bool EsUsuarioSoporte(string? usuario)
        {
            return string.Equals(usuario, UsuarioSoporte, StringComparison.Ordinal);
        }

        private static bool EsClase(string? idClase, string esperada)
        {
            return string.Equals(idClase?.Trim(), esperada, StringComparison.OrdinalIgnoreCase);
        }
    }
}
