using Aduax.AuditorDocumentos.Api.Services.VertexIA.Models;

namespace Aduax.AuditorDocumentos.Api.Services.VertexIA
{
    public interface IVertexClient
    {
        /// <summary>
        /// Analiza un prompt y opcionalmente un documento para generar una respuesta JSON
        /// </summary>
        /// <param name="prompt">El prompt a procesar</param>
        /// <param name="document">Documento opcional a analizar</param>
        /// <returns>Respuesta JSON del análisis</returns>
        Task<string> GetAnalizeJson(string prompt, DocumentToAnalize document);
    }
}
