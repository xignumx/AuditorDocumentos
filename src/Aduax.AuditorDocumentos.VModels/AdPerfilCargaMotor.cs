namespace Aduax.AuditorDocumentos.VModels
{
    /// <summary>
    /// Perfil requerido para acciones críticas (ad_motor_config_header.PerfilCarga).
    /// G=acceso general, A=admin, L=líder. El alta de documentos no usa esta regla.
    /// </summary>
    public static class AdPerfilCargaMotor
    {
        public const string AccesoGeneral = "G";
        public const string Admin = "A";
        public const string Lider = "L";

        public static bool EsValorValido(string? perfilCarga)
        {
            if (string.IsNullOrWhiteSpace(perfilCarga))
            {
                return false;
            }

            var normalized = perfilCarga.Trim().ToUpperInvariant();
            return normalized is AccesoGeneral or Admin or Lider;
        }

        public static string Normalizar(string? perfilCarga)
        {
            if (string.IsNullOrWhiteSpace(perfilCarga))
            {
                return AccesoGeneral;
            }

            var normalized = perfilCarga.Trim().ToUpperInvariant();
            return EsValorValido(normalized) ? normalized : AccesoGeneral;
        }

        /// <summary>
        /// Indica si el usuario puede ejecutar acciones críticas según PerfilCarga del motor e IdClase en ADUASIS.
        /// </summary>
        public static bool UsuarioPuedeAccionCritica(string? perfilCarga, string? idClaseUsuario)
        {
            var perfil = Normalizar(perfilCarga);
            var idClase = idClaseUsuario?.Trim() ?? string.Empty;

            return perfil switch
            {
                Admin => string.Equals(idClase, "ADM", StringComparison.OrdinalIgnoreCase),
                Lider => string.Equals(idClase, "LIDER", StringComparison.OrdinalIgnoreCase),
                _ => true
            };
        }
    }
}
