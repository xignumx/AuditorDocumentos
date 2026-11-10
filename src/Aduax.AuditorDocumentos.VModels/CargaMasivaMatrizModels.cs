namespace Aduax.AuditorDocumentos.VModels
{
    /// <summary>Resultado posible de cada combinación cliente + tipo VUCEM en la carga masiva de la matriz.</summary>
    public static class CargaMasivaMatrizEstado
    {
        public const string Nuevo = "NUEVO";
        public const string Modifica = "MODIFICA";
        public const string SinCambios = "SIN_CAMBIOS";
        public const string Error = "ERROR";
    }

    /// <summary>
    /// Carga masiva de la matriz de validación (Excel .xlsx). Las filas del archivo se aplican a cada cliente
    /// de IdsClientes; las celdas vacías no modifican la configuración existente.
    /// </summary>
    public class CargaMasivaMatrizRequest
    {
        public string NombreArchivo { get; set; } = string.Empty;
        public string ArchivoBase64 { get; set; } = string.Empty;
        public List<string> IdsClientes { get; set; } = new();

        /// <summary>true = solo calcula qué cambiaría; false = aplica los cambios.</summary>
        public bool SoloPrevisualizar { get; set; } = true;

        /// <summary>Se guarda en la bitácora de cada configuración modificada.</summary>
        public string? MotivoCambio { get; set; }
    }

    public class CargaMasivaMatrizItemDto
    {
        public string IdCliente { get; set; } = string.Empty;
        public string? RazonSocial { get; set; }
        public int IdTipoDocumentoVucem { get; set; }
        public string? Documento { get; set; }

        /// <summary>NUEVO, MODIFICA, SIN_CAMBIOS o ERROR (<see cref="CargaMasivaMatrizEstado"/>).</summary>
        public string Estado { get; set; } = string.Empty;

        /// <summary>true cuando el cambio ya se guardó (solo en la aplicación).</summary>
        public bool Aplicado { get; set; }

        /// <summary>Motivo del error cuando Estado = ERROR.</summary>
        public string? Mensaje { get; set; }

        public int TotalCambios { get; set; }

        /// <summary>Primeros cambios en texto legible; el detalle completo queda en la bitácora.</summary>
        public List<string> Cambios { get; set; } = new();
    }

    public class CargaMasivaMatrizResultDto
    {
        public bool SoloPrevisualizar { get; set; }
        public int TotalClientes { get; set; }
        public int TotalFilasArchivo { get; set; }
        public int TotalNuevos { get; set; }
        public int TotalModifica { get; set; }
        public int TotalSinCambios { get; set; }
        public int TotalErrores { get; set; }
        public int TotalAplicados { get; set; }

        /// <summary>Errores de formato o contenido del archivo. Si hay alguno no se calcula ni aplica nada.</summary>
        public List<string> ErroresArchivo { get; set; } = new();

        /// <summary>Observaciones que no impiden continuar (columnas desconocidas, filas vacías omitidas).</summary>
        public List<string> Avisos { get; set; } = new();

        public List<CargaMasivaMatrizItemDto> Items { get; set; } = new();
    }

    /// <summary>Archivo devuelto dentro de GenericResponse (el cliente HTTP solo maneja JSON).</summary>
    public class ArchivoDescargaDto
    {
        public string NombreArchivo { get; set; } = string.Empty;
        public string ContenidoBase64 { get; set; } = string.Empty;
    }
}
