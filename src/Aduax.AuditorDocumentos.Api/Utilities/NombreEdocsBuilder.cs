namespace Aduax.AuditorDocumentos.Api.Utilities
{
    /// <summary>
    /// Nombre de archivo para eDOCS/VUCEM y FileStorage: base sanitizada + Id_Vucem + timestamp + extensión.
    /// </summary>
    public static class NombreEdocsBuilder
    {
        public const int MaxLength = 250;

        public static string Build(string nombreArchivoOriginal, int idVucem, DateTime fechaHoraServidor)
        {
            if (string.IsNullOrWhiteSpace(nombreArchivoOriginal))
            {
                throw new ArgumentException("El nombre de archivo original es requerido.", nameof(nombreArchivoOriginal));
            }

            var extension = Path.GetExtension(nombreArchivoOriginal).ToLowerInvariant();
            var basePart = SanitizeBase(Path.GetFileNameWithoutExtension(nombreArchivoOriginal));
            if (string.IsNullOrEmpty(basePart))
            {
                basePart = "documento";
            }

            var idVucemPart = FormatIdVucem(idVucem);
            var timestamp = fechaHoraServidor.ToString("yyyyMMddHHmmss");
            var suffix = $"_{idVucemPart}_{timestamp}{extension}";

            if (suffix.Length >= MaxLength)
            {
                throw new InvalidOperationException(
                    $"No es posible generar NombreEdocs: el sufijo (_Id_Vucem_fecha.ext) supera {MaxLength} caracteres.");
            }

            var maxBaseLength = MaxLength - suffix.Length;
            if (basePart.Length > maxBaseLength)
            {
                basePart = basePart[..maxBaseLength];
            }

            return basePart + suffix;
        }

        private static string FormatIdVucem(int idVucem)
        {
            if (idVucem < 0)
            {
                return "0000";
            }

            return idVucem <= 9999 ? idVucem.ToString("D4") : idVucem.ToString();
        }

        private static string SanitizeBase(string value)
        {
            if (string.IsNullOrWhiteSpace(value))
            {
                return string.Empty;
            }

            var buffer = new char[value.Length];
            var count = 0;
            foreach (var c in value)
            {
                if (char.IsAsciiLetterOrDigit(c))
                {
                    buffer[count++] = c;
                }
            }

            return count == 0 ? string.Empty : new string(buffer, 0, count);
        }
    }
}
