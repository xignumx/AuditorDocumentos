using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;
using Aduax.AuditorDocumentos.Api.Configuration;
using onecore.security.services;
using onecore.security.utils;
using System.Security.Claims;
using System.Text.Encodings.Web;

namespace Aduax.AuditorDocumentos.Api.Auth
{
    public class TokenAuthenticationHandler : AuthenticationHandler<AuthenticationSchemeOptions>
    {
        private readonly AppSettings _appSettings;

        public TokenAuthenticationHandler(
            IOptionsMonitor<AuthenticationSchemeOptions> options,
            ILoggerFactory logger,
            UrlEncoder encoder,
            ISystemClock clock,
            IOptions<AppSettings> appSettings)
            : base(options, logger, encoder, clock)
        {
            _appSettings = appSettings.Value;
        }

        protected override Task<AuthenticateResult> HandleAuthenticateAsync()
        {
            // Obtener el token del header Authorization
            string? authHeader = Request.Headers["Authorization"].FirstOrDefault();

            if (string.IsNullOrEmpty(authHeader) || !authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            {
                return Task.FromResult(AuthenticateResult.NoResult());
            }

            // Extraer el token (remover "Bearer ")
            string token = authHeader.Substring("Bearer ".Length).Trim();

            try
            {
                // Decodificar el token
                string PSWD = _appSettings.KeyToken;
                TokenLoginDTO? tokenDTO = EncryptService.DecryptTokenLogin(token, PSWD);

                if (tokenDTO == null)
                {
                    return Task.FromResult(AuthenticateResult.Fail("Token inválido"));
                }

                // Almacenar TokenLoginDTO en HttpContext.Items para acceso posterior
                Context.Items["TokenLoginDTO"] = tokenDTO;

                // Crear claims y principal
                var claims = new List<Claim>
                {
                    new Claim(ClaimTypes.NameIdentifier, tokenDTO.ToString() ?? string.Empty)
                };

                var identity = new ClaimsIdentity(claims, Scheme.Name);
                var principal = new ClaimsPrincipal(identity);
                var ticket = new AuthenticationTicket(principal, Scheme.Name);

                return Task.FromResult(AuthenticateResult.Success(ticket));
            }
            catch (Exception ex)
            {
                return Task.FromResult(AuthenticateResult.Fail($"Error al procesar el token: {ex.Message}"));
            }
        }
    }
}

