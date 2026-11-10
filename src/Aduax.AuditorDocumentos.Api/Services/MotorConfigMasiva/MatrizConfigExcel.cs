using System.Globalization;
using System.Text;
using ClosedXML.Excel;
using Aduax.AuditorDocumentos.VModels;

namespace Aduax.AuditorDocumentos.Api.Services.MotorConfigMasiva
{
    /// <summary>Una fila de la hoja "Matriz": configuración deseada para un tipo de documento VUCEM.</summary>
    public class FilaMatriz
    {
        public int Fila { get; set; }
        public int IdTipoDocumentoVucem { get; set; }
        public int? Clasificacion { get; set; }
        public string? AccionPedimento { get; set; }

        /// <summary>IdCampo → (Visible, Obligatorio). null = celda vacía (no modifica).</summary>
        public Dictionary<int, (bool? Visible, bool? Obligatorio)> Campos { get; } = new();

        public bool TieneValores =>
            Clasificacion.HasValue
            || AccionPedimento != null
            || Campos.Values.Any(c => c.Visible.HasValue || c.Obligatorio.HasValue);
    }

    public class MatrizParseada
    {
        public List<FilaMatriz> Filas { get; } = new();
        public List<string> Errores { get; } = new();
        public List<string> Avisos { get; } = new();
    }

    /// <summary>
    /// Plantilla y lectura del archivo Excel de la matriz de validación documental. Lógica pura, sin acceso a datos.
    /// Formato: hoja "Matriz", una fila por tipo VUCEM, columnas "{Campo} Visible" y "{Campo} Obligatorio".
    /// </summary>
    public static class MatrizConfigExcel
    {
        public const string HojaMatriz = "Matriz";
        public const string HojaInstrucciones = "Instrucciones";
        public const int MaxFilas = 1000;

        private const string ColId = "IdTipoDocumentoVucem";
        private const string ColDocumento = "Documento";
        private const string ColClasificacion = "Clasificacion";
        private const string ColAccion = "AccionPedimento";
        private const string SufijoVisible = " Visible";
        private const string SufijoObligatorio = " Obligatorio";

        /// <summary>Campos que se configuran en /config (TipoPedimento a Pedimento).</summary>
        public static readonly IReadOnlyList<AdCampos> CamposConfigurables = Enum
            .GetValues<AdCampos>()
            .Where(c => (int)c >= (int)AdCampos.TipoPedimento && (int)c <= (int)AdCampos.Pedimento)
            .ToList();

        private static readonly Dictionary<AdCampos, string> Etiquetas = new()
        {
            [AdCampos.TipoPedimento] = "Tipo de pedimento",
            [AdCampos.TipoOperacion] = "Tipo de operación",
            [AdCampos.ClavePedimento] = "Clave de pedimento",
            [AdCampos.Proveedor] = "Proveedor",
            [AdCampos.ProductoNoDeParte] = "Producto / No. de parte",
            [AdCampos.DescripcionMercancia] = "Descripción de mercancía",
            [AdCampos.Fracciones] = "Fracciones",
            [AdCampos.Nico] = "Nico",
            [AdCampos.Cantidad] = "Cantidad",
            [AdCampos.UnidadMedidaUMT] = "Unidad de medida (UMT)",
            [AdCampos.PaisOrigenDestino] = "País origen/destino",
            [AdCampos.VigenciaDesde] = "Vigencia desde",
            [AdCampos.VigenciaHasta] = "Vigencia hasta",
            [AdCampos.Aduana] = "Aduana",
            [AdCampos.FirmaDeRL] = "Firma de Representante Legal",
            [AdCampos.Nom] = "Nom",
            [AdCampos.ValorComercial] = "Valor comercial",
            [AdCampos.Factura] = "Factura",
            [AdCampos.FechaFactura] = "Fecha factura",
            [AdCampos.ValorUsd] = "Valor USD",
            [AdCampos.GuiaBl] = "Guía/BL",
            [AdCampos.Pedimento] = "Pedimento"
        };

        private static string NombreColumna(AdCampos campo) => campo.ToString();

        // ===== Plantilla =====

        public static byte[] GenerarPlantilla(IEnumerable<(int Id, string Documento)> tipos)
        {
            using var libro = new XLWorkbook();
            var hoja = libro.Worksheets.Add(HojaMatriz);

            var encabezados = new List<string> { ColId, ColDocumento, ColClasificacion, ColAccion };
            foreach (var campo in CamposConfigurables)
            {
                encabezados.Add(NombreColumna(campo) + SufijoVisible);
                encabezados.Add(NombreColumna(campo) + SufijoObligatorio);
            }

            for (var i = 0; i < encabezados.Count; i++)
            {
                var celda = hoja.Cell(1, i + 1);
                celda.Value = encabezados[i];
                celda.Style.Font.Bold = true;
                celda.Style.Fill.BackgroundColor = i < 2 ? XLColor.LightGray : XLColor.FromHtml("#FFE3D6");
            }

            var fila = 2;
            foreach (var (id, documento) in tipos.OrderBy(t => t.Documento, StringComparer.CurrentCultureIgnoreCase))
            {
                hoja.Cell(fila, 1).Value = id;
                hoja.Cell(fila, 2).Value = documento;
                fila++;
            }

            var ultimaFila = Math.Max(fila - 1, 2);
            AgregarLista(hoja, 3, ultimaFila, "General,Partida,Permiso");
            AgregarLista(hoja, 4, ultimaFila, "S,N,P");
            for (var columna = 5; columna <= encabezados.Count; columna++)
            {
                AgregarLista(hoja, columna, ultimaFila, "SI,NO");
            }

            hoja.SheetView.FreezeRows(1);
            hoja.SheetView.FreezeColumns(2);
            hoja.Columns().AdjustToContents(1, 1);
            hoja.Column(2).Width = 45;
            hoja.Column(1).Width = 24;

            AgregarInstrucciones(libro);

            using var salida = new MemoryStream();
            libro.SaveAs(salida);
            return salida.ToArray();
        }

        private static void AgregarLista(IXLWorksheet hoja, int columna, int ultimaFila, string valores)
        {
            var validacion = hoja.Range(2, columna, ultimaFila, columna).CreateDataValidation();
            validacion.List($"\"{valores}\"");
            validacion.IgnoreBlanks = true;
        }

        private static void AgregarInstrucciones(XLWorkbook libro)
        {
            var hoja = libro.Worksheets.Add(HojaInstrucciones);
            var lineas = new List<string>
            {
                "Carga masiva de la matriz de validación documental",
                "",
                "1. Llene solo los tipos de documento que desea configurar. Las filas sin ningún valor se omiten.",
                "2. Una celda vacía NO modifica la configuración actual del cliente. Solo se aplica lo que capture.",
                "3. Los clientes destino se eligen en la pantalla al subir el archivo; el archivo no lleva columna de cliente.",
                "4. Si el cliente aún no tiene configuración del tipo, se crea con los valores por defecto y se aplica lo capturado.",
                "5. Visible = NO apaga también Obligatorio. Un campo Obligatorio = SI debe quedar Visible.",
                "6. Debe quedar al menos un campo visible (distinto de Tipo de pedimento) y al menos un campo visible obligatorio.",
                "7. La clasificación no puede cambiarse si el cliente ya tiene documentos Pendientes, Aprobados, Vinculados o Digitalizados.",
                "8. El perfil para acciones críticas no se modifica desde este archivo.",
                "",
                $"Columna {ColClasificacion}: General, Partida o Permiso.",
                $"Columna {ColAccion}: S = Afecta operación, N = No afecta operación, P = Pregunta si afecta.",
                "Columnas Visible / Obligatorio: SI o NO.",
                "",
                "Campos (nombre de columna → etiqueta en pantalla):"
            };

            for (var i = 0; i < lineas.Count; i++)
            {
                hoja.Cell(i + 1, 1).Value = lineas[i];
            }
            hoja.Cell(1, 1).Style.Font.Bold = true;
            hoja.Cell(lineas.Count, 1).Style.Font.Bold = true;

            var fila = lineas.Count + 1;
            foreach (var campo in CamposConfigurables)
            {
                hoja.Cell(fila, 1).Value = NombreColumna(campo);
                hoja.Cell(fila, 2).Value = Etiquetas.GetValueOrDefault(campo, NombreColumna(campo));
                fila++;
            }

            hoja.Column(1).Width = 110;
            hoja.Column(2).Width = 35;
        }

        // ===== Lectura =====

        public static MatrizParseada Parsear(byte[] contenido)
        {
            var resultado = new MatrizParseada();

            XLWorkbook libro;
            try
            {
                libro = new XLWorkbook(new MemoryStream(contenido));
            }
            catch (Exception)
            {
                resultado.Errores.Add("El archivo no es un libro de Excel (.xlsx) válido");
                return resultado;
            }

            using (libro)
            {
                if (!libro.TryGetWorksheet(HojaMatriz, out var hoja))
                {
                    resultado.Errores.Add($"El archivo no contiene la hoja \"{HojaMatriz}\". Use la plantilla descargable");
                    return resultado;
                }

                var ultimaColumna = hoja.LastColumnUsed()?.ColumnNumber() ?? 0;
                var ultimaFila = hoja.LastRowUsed()?.RowNumber() ?? 0;
                if (ultimaColumna == 0 || ultimaFila < 2)
                {
                    resultado.Errores.Add("La hoja \"Matriz\" no contiene filas de datos");
                    return resultado;
                }

                if (ultimaFila - 1 > MaxFilas)
                {
                    resultado.Errores.Add($"El archivo excede el máximo de {MaxFilas} filas por carga");
                    return resultado;
                }

                var columnas = LeerEncabezados(hoja, ultimaColumna, resultado);
                if (resultado.Errores.Count > 0)
                {
                    return resultado;
                }

                var tiposVistos = new Dictionary<int, int>();
                var filasSinValores = 0;

                for (var numeroFila = 2; numeroFila <= ultimaFila; numeroFila++)
                {
                    var fila = LeerFila(hoja, numeroFila, columnas, resultado);
                    if (fila == null)
                    {
                        continue;
                    }

                    if (tiposVistos.TryGetValue(fila.IdTipoDocumentoVucem, out var filaPrevia))
                    {
                        resultado.Errores.Add(
                            $"Fila {numeroFila}: el tipo {fila.IdTipoDocumentoVucem} ya aparece en la fila {filaPrevia}");
                        continue;
                    }
                    tiposVistos[fila.IdTipoDocumentoVucem] = numeroFila;

                    if (!fila.TieneValores)
                    {
                        filasSinValores++;
                        continue;
                    }

                    resultado.Filas.Add(fila);
                }

                if (filasSinValores > 0)
                {
                    resultado.Avisos.Add($"{filasSinValores} fila(s) sin valores de configuración se omitieron");
                }

                if (resultado.Errores.Count == 0 && resultado.Filas.Count == 0)
                {
                    resultado.Errores.Add("El archivo no contiene ninguna fila con valores de configuración");
                }
            }

            return resultado;
        }

        private sealed class MapaColumnas
        {
            public int Id { get; set; }
            public int? Clasificacion { get; set; }
            public int? Accion { get; set; }
            public Dictionary<int, int> Visible { get; } = new();
            public Dictionary<int, int> Obligatorio { get; } = new();
        }

        private static MapaColumnas LeerEncabezados(IXLWorksheet hoja, int ultimaColumna, MatrizParseada resultado)
        {
            var mapa = new MapaColumnas();
            var porNombre = CamposConfigurables.ToDictionary(
                c => NombreColumna(c).ToLowerInvariant(),
                c => (int)c);
            var desconocidas = new List<string>();

            for (var columna = 1; columna <= ultimaColumna; columna++)
            {
                var encabezado = hoja.Cell(1, columna).GetString().Trim();
                if (encabezado.Length == 0)
                {
                    continue;
                }

                var clave = encabezado.ToLowerInvariant();
                if (clave == ColId.ToLowerInvariant()) { mapa.Id = columna; continue; }
                if (clave == ColDocumento.ToLowerInvariant()) { continue; }
                if (clave == ColClasificacion.ToLowerInvariant()) { mapa.Clasificacion = columna; continue; }
                if (clave == ColAccion.ToLowerInvariant()) { mapa.Accion = columna; continue; }

                if (clave.EndsWith(SufijoVisible.ToLowerInvariant())
                    && porNombre.TryGetValue(clave[..^SufijoVisible.Length], out var idVisible))
                {
                    mapa.Visible[idVisible] = columna;
                }
                else if (clave.EndsWith(SufijoObligatorio.ToLowerInvariant())
                    && porNombre.TryGetValue(clave[..^SufijoObligatorio.Length], out var idObligatorio))
                {
                    mapa.Obligatorio[idObligatorio] = columna;
                }
                else
                {
                    desconocidas.Add(encabezado);
                }
            }

            if (mapa.Id == 0)
            {
                resultado.Errores.Add($"Falta la columna \"{ColId}\"");
            }
            else if (mapa.Clasificacion == null && mapa.Accion == null && mapa.Visible.Count == 0 && mapa.Obligatorio.Count == 0)
            {
                resultado.Errores.Add("El archivo no contiene columnas de configuración (Clasificacion, AccionPedimento, Visible, Obligatorio)");
            }

            if (desconocidas.Count > 0)
            {
                resultado.Avisos.Add($"Columnas no reconocidas (se ignoran): {string.Join(", ", desconocidas)}");
            }

            return mapa;
        }

        private static FilaMatriz? LeerFila(IXLWorksheet hoja, int numeroFila, MapaColumnas columnas, MatrizParseada resultado)
        {
            var ultimaColumna = hoja.LastColumnUsed()?.ColumnNumber() ?? 0;
            var filaVacia = true;
            for (var c = 1; c <= ultimaColumna; c++)
            {
                if (!hoja.Cell(numeroFila, c).IsEmpty())
                {
                    filaVacia = false;
                    break;
                }
            }
            if (filaVacia)
            {
                return null;
            }

            var textoId = hoja.Cell(numeroFila, columnas.Id).GetString().Trim();
            if (!int.TryParse(textoId, NumberStyles.Integer, CultureInfo.InvariantCulture, out var idTipo) || idTipo <= 0)
            {
                resultado.Errores.Add($"Fila {numeroFila}: {ColId} \"{textoId}\" no es un número válido");
                return null;
            }

            var fila = new FilaMatriz { Fila = numeroFila, IdTipoDocumentoVucem = idTipo };
            var errorEnFila = false;

            if (columnas.Clasificacion.HasValue)
            {
                var texto = hoja.Cell(numeroFila, columnas.Clasificacion.Value).GetString().Trim();
                if (texto.Length > 0)
                {
                    var clasificacion = ParsearClasificacion(texto);
                    if (clasificacion == null)
                    {
                        resultado.Errores.Add($"Fila {numeroFila}: {ColClasificacion} \"{texto}\" no es válida (General, Partida o Permiso)");
                        errorEnFila = true;
                    }
                    fila.Clasificacion = clasificacion;
                }
            }

            if (columnas.Accion.HasValue)
            {
                var texto = hoja.Cell(numeroFila, columnas.Accion.Value).GetString().Trim().ToUpperInvariant();
                if (texto.Length > 0)
                {
                    if (texto is "S" or "N" or "P")
                    {
                        fila.AccionPedimento = texto;
                    }
                    else
                    {
                        resultado.Errores.Add($"Fila {numeroFila}: {ColAccion} \"{texto}\" no es válida (S, N o P)");
                        errorEnFila = true;
                    }
                }
            }

            foreach (var campo in CamposConfigurables)
            {
                var idCampo = (int)campo;
                bool? visible = null;
                bool? obligatorio = null;

                if (columnas.Visible.TryGetValue(idCampo, out var colVisible))
                {
                    visible = LeerBooleano(hoja, numeroFila, colVisible, $"{NombreColumna(campo)}{SufijoVisible}", resultado, ref errorEnFila);
                }
                if (columnas.Obligatorio.TryGetValue(idCampo, out var colObligatorio))
                {
                    obligatorio = LeerBooleano(hoja, numeroFila, colObligatorio, $"{NombreColumna(campo)}{SufijoObligatorio}", resultado, ref errorEnFila);
                }

                if (visible == false && obligatorio == true)
                {
                    resultado.Errores.Add($"Fila {numeroFila}: {NombreColumna(campo)} no puede ser Obligatorio si no es Visible");
                    errorEnFila = true;
                }

                if (visible.HasValue || obligatorio.HasValue)
                {
                    fila.Campos[idCampo] = (visible, obligatorio);
                }
            }

            return errorEnFila ? null : fila;
        }

        private static bool? LeerBooleano(
            IXLWorksheet hoja,
            int numeroFila,
            int columna,
            string nombreColumna,
            MatrizParseada resultado,
            ref bool errorEnFila)
        {
            var texto = Normalizar(hoja.Cell(numeroFila, columna).GetString());
            if (texto.Length == 0)
            {
                return null;
            }

            switch (texto)
            {
                case "si":
                case "1":
                case "true":
                case "verdadero":
                    return true;
                case "no":
                case "0":
                case "false":
                case "falso":
                    return false;
                default:
                    resultado.Errores.Add($"Fila {numeroFila}: {nombreColumna} \"{texto}\" no es válido (SI o NO)");
                    errorEnFila = true;
                    return null;
            }
        }

        private static int? ParsearClasificacion(string texto)
        {
            return Normalizar(texto) switch
            {
                "1" or "general" or "identificadorgeneral" or "identificador general" => (int)AdDocumentoClasificacion.IdentificadorGeneral,
                "2" or "partida" or "identificadorpartida" or "identificador partida" => (int)AdDocumentoClasificacion.IdentificadorPartida,
                "3" or "permiso" or "permisos" => (int)AdDocumentoClasificacion.Permisos,
                _ => null
            };
        }

        /// <summary>Minúsculas, sin acentos y sin espacios en los extremos.</summary>
        private static string Normalizar(string? texto)
        {
            var descompuesto = (texto ?? string.Empty).Trim().ToLowerInvariant().Normalize(NormalizationForm.FormD);
            var sb = new StringBuilder(descompuesto.Length);
            foreach (var c in descompuesto)
            {
                if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark)
                {
                    sb.Append(c);
                }
            }
            return sb.ToString().Normalize(NormalizationForm.FormC);
        }
    }
}
