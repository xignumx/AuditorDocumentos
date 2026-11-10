using System.Text.Json;
using System.Text.RegularExpressions;
using Aduax.AuditorDocumentos.VModels;

namespace Aduax.AuditorDocumentos.Api.Services.IaReglas
{
    /// <summary>
    /// Lógica pura (sin acceso a datos) del diccionario de sinónimos y de la normalización de UM.
    /// </summary>
    public static class IaReglasMotor
    {
        /// <summary>Marcador opcional del prompt del documento donde se coloca el bloque de equivalencias.</summary>
        public const string TokenSinonimos = "[SINONIMOS]";

        private const string EncabezadoBloque =
            "EQUIVALENCIAS DE ETIQUETAS (el documento puede usar cualquiera de estos términos, en español o en inglés, " +
            "para referirse al mismo dato; usa estas equivalencias al interpretar etiquetas y encabezados de columnas):";

        /// <summary>
        /// Arma el bloque de equivalencias. Incluye los conceptos sin campo destino y los ligados a campos visibles.
        /// Devuelve cadena vacía si no hay nada que informar.
        /// </summary>
        public static string ConstruirBloqueSinonimos(
            IEnumerable<IaDiccionarioConceptoDto> conceptos,
            IReadOnlyCollection<int> idsCamposVisibles)
        {
            var lineas = new List<string>();

            foreach (var concepto in conceptos)
            {
                if (concepto.Categoria != IaDiccionarioCategoria.General)
                {
                    continue;
                }

                if (concepto.IdCampo.HasValue && !idsCamposVisibles.Contains(concepto.IdCampo.Value))
                {
                    continue;
                }

                var terminos = concepto.TerminosEs
                    .Concat(concepto.TerminosEn)
                    .Select(Sanear)
                    .Where(t => t.Length > 0)
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .ToList();

                var nombre = Sanear(concepto.Concepto);
                if (terminos.Count == 0 || nombre.Length == 0)
                {
                    continue;
                }

                lineas.Add($"- {nombre}: {string.Join("; ", terminos)}");
            }

            return lineas.Count == 0
                ? string.Empty
                : EncabezadoBloque + "\n" + string.Join("\n", lineas);
        }

        /// <summary>
        /// Coloca el bloque en el marcador [SINONIMOS]; si el prompt no lo trae, lo agrega al final.
        /// Sin bloque, retira el marcador para que no llegue a la IA.
        /// </summary>
        public static string AplicarBloque(string prompt, string bloque)
        {
            if (string.IsNullOrEmpty(bloque))
            {
                return prompt.Replace(TokenSinonimos, string.Empty);
            }

            return prompt.Contains(TokenSinonimos, StringComparison.Ordinal)
                ? prompt.Replace(TokenSinonimos, bloque)
                : prompt.TrimEnd() + "\n\n" + bloque;
        }

        /// <summary>
        /// Reemplaza cada variante de UM por su id_unidad_universal canónico. Conserva la forma del valor
        /// (cadena separada por ';' o arreglo), elimina repetidos y deja intactos los términos sin equivalencia.
        /// </summary>
        public static object? NormalizarUnidadMedida(object? valor, IReadOnlyDictionary<string, string> mapa)
        {
            if (valor == null || mapa.Count == 0)
            {
                return valor;
            }

            bool esLista;
            List<string> terminos;

            switch (valor)
            {
                case string texto:
                    esLista = false;
                    terminos = mapa.ContainsKey(texto.Trim())
                        ? new List<string> { texto.Trim() }
                        : texto.Split(';').ToList();
                    break;
                case JsonElement { ValueKind: JsonValueKind.String } elemento:
                    esLista = false;
                    terminos = new List<string> { elemento.GetString() ?? string.Empty };
                    break;
                case JsonElement { ValueKind: JsonValueKind.Array } arreglo:
                    esLista = true;
                    terminos = arreglo.EnumerateArray().Select(e => ATexto(e)).ToList();
                    break;
                case System.Collections.IEnumerable coleccion when valor is not string:
                    esLista = true;
                    terminos = coleccion.Cast<object?>().Select(ATexto).ToList();
                    break;
                default:
                    return valor;
            }

            var normalizados = new List<string>();
            var vistos = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var termino in terminos.Select(t => t.Trim()).Where(t => t.Length > 0))
            {
                var resultado = mapa.TryGetValue(termino, out var canonico) ? canonico : termino;
                if (vistos.Add(resultado))
                {
                    normalizados.Add(resultado);
                }
            }

            return esLista
                ? normalizados.Cast<object>().ToArray()
                : string.Join(";", normalizados);
        }

        private static string ATexto(object? valor)
        {
            return valor switch
            {
                null => string.Empty,
                JsonElement { ValueKind: JsonValueKind.String } e => e.GetString() ?? string.Empty,
                JsonElement e => e.GetRawText(),
                _ => valor.ToString() ?? string.Empty
            };
        }

        private static string Sanear(string? texto)
        {
            return Regex.Replace(texto ?? string.Empty, @"\s+", " ").Trim();
        }
    }
}
