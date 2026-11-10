namespace Aduax.AuditorDocumentos.VModels
{
    /// <summary>Categorías del diccionario de la IA.</summary>
    public static class IaDiccionarioCategoria
    {
        /// <summary>Equivalencias de etiquetas ES/EN que se inyectan en el prompt.</summary>
        public const string General = "GENERAL";

        /// <summary>Equivalencias globales de unidad de medida (Concepto = id_unidad_universal).</summary>
        public const string UnidadMedida = "UM";

        public static string? Normalizar(string? categoria)
        {
            var valor = categoria?.Trim().ToUpperInvariant();
            return valor is General or UnidadMedida ? valor : null;
        }
    }

    public static class IaPromptTipo
    {
        public const string Documento = "DOCUMENTO";
        public const string Campo = "CAMPO";
    }

    public class IaPromptDocumentoDto
    {
        public long Id { get; set; }
        public long IdTipoDocumentoVucem { get; set; }
        public string Prompt { get; set; } = string.Empty;
        public bool Activo { get; set; }
        public int Version { get; set; }
        public DateTime? FechaActualizacion { get; set; }
        public string? ActualizadoPor { get; set; }
    }

    public class IaPromptCampoDto
    {
        public long Id { get; set; }
        public long IdTipoDocumentoVucem { get; set; }
        public int IdCampo { get; set; }
        public string NombreCampo { get; set; } = string.Empty;
        public string PromptParcial { get; set; } = string.Empty;
        public bool Activo { get; set; }
        public int Version { get; set; }
        public DateTime? FechaActualizacion { get; set; }
        public string? ActualizadoPor { get; set; }
    }

    public class IaPromptsDto
    {
        public IaPromptDocumentoDto? PromptDocumento { get; set; }
        public List<IaPromptCampoDto> PromptsCampo { get; set; } = new();
    }

    /// <summary>Alta o cambio de un prompt. El tipo de documento VUCEM va en la raíz de GenericAdRequest.</summary>
    public class GuardarIaPromptRequest
    {
        /// <summary>DOCUMENTO o CAMPO (<see cref="IaPromptTipo"/>).</summary>
        public string Tipo { get; set; } = string.Empty;

        /// <summary>Requerido cuando Tipo = CAMPO.</summary>
        public int? IdCampo { get; set; }

        public string Texto { get; set; } = string.Empty;
        public bool Activo { get; set; } = true;
    }

    public class IaDiccionarioFiltro
    {
        /// <summary>GENERAL o UM. Vacío = ambas.</summary>
        public string? Categoria { get; set; }
    }

    /// <summary>Un concepto con sus términos equivalentes en español e inglés.</summary>
    public class IaDiccionarioConceptoDto
    {
        public string Categoria { get; set; } = IaDiccionarioCategoria.General;

        /// <summary>Nombre del dato (GENERAL) o id_unidad_universal canónico (UM).</summary>
        public string Concepto { get; set; } = string.Empty;

        /// <summary>Campo AdCampos al que aplica (opcional, solo GENERAL).</summary>
        public int? IdCampo { get; set; }

        /// <summary>Descripción de la unidad en ADUASIS (solo lectura, UM).</summary>
        public string? Descripcion { get; set; }

        public List<string> TerminosEs { get; set; } = new();
        public List<string> TerminosEn { get; set; } = new();
    }

    public class EliminarIaDiccionarioConceptoRequest
    {
        public string Categoria { get; set; } = string.Empty;
        public string Concepto { get; set; } = string.Empty;
    }

    public class IaHistorialFiltro
    {
        /// <summary>PROMPT_DOC, PROMPT_CAMPO o DICCIONARIO. Vacío = todas.</summary>
        public string? Entidad { get; set; }
        public long? IdTipoDocumentoVucem { get; set; }
    }

    public class IaHistorialDto
    {
        public long Id { get; set; }
        public string Entidad { get; set; } = string.Empty;
        public string Clave { get; set; } = string.Empty;
        public long? IdTipoDocumentoVucem { get; set; }
        public int? IdCampo { get; set; }
        public int Version { get; set; }
        public string Accion { get; set; } = string.Empty;
        public string? ValorAnterior { get; set; }
        public string? ValorNuevo { get; set; }
        public string Usuario { get; set; } = string.Empty;
        public DateTime Fecha { get; set; }
    }

    /// <summary>Fila de ADUASIS.dbo.funidad_universal.</summary>
    public class UnidadMedidaDto
    {
        public string IdUnidadUniversal { get; set; } = string.Empty;
        public string? Descripcion { get; set; }
        public string? DescAbreviada { get; set; }
        public string? CveUnidadOficial { get; set; }
    }
}
