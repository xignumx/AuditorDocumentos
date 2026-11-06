using onecore.security.services;

namespace Aduax.AuditorDocumentos.Api.Auth
{
    public static class HttpContextExtensions
    {
        private const string TokenLoginDTOKey = "TokenLoginDTO";

        /// <summary>
        /// Obtiene el TokenLoginDTO decodificado del HttpContext
        /// </summary>
        /// <param name="context">El HttpContext actual</param>
        /// <returns>TokenLoginDTO si existe, null en caso contrario</returns>
        public static TokenLoginDTO? GetTokenLoginDTO(this HttpContext context)
        {
            if (context.Items.TryGetValue(TokenLoginDTOKey, out var tokenDTO) && tokenDTO is TokenLoginDTO dto)
            {
                return dto;
            }
            return null;
        }
    }
}

