using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Aduax.AuditorDocumentos.Api.Configuration;
using onecore.security.services;
using onecore.security.utils;
using System.Net;

namespace Aduax.AuditorDocumentos.Api.Auth
{
    public class TokenAuthenticationMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly AppSettings _appSettings;

        public TokenAuthenticationMiddleware(RequestDelegate next, IOptions<AppSettings> appSettings)
        {
            _next = next;
            _appSettings = appSettings.Value;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            // Excluir Swagger
            if (context.Request.Path.StartsWithSegments("/swagger"))
            {
                await _next(context);
                return;
            }

            // Verificar si el endpoint requiere autorización
            var endpoint = context.GetEndpoint();
            var requiresAuth = endpoint?.Metadata.GetMetadata<AuthorizeAttribute>() != null ||
                              endpoint?.Metadata.GetMetadata<IAuthorizeData>() != null;

            // Si no requiere autorización, continuar sin validar
            if (!requiresAuth)
            {
                await _next(context);
                return;
            }

            // Obtener el token del header Authorization
            string? authHeader = context.Request.Headers["Authorization"].FirstOrDefault();

            if (string.IsNullOrEmpty(authHeader) || !authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            {
                context.Response.StatusCode = (int)HttpStatusCode.Unauthorized;
                await context.Response.WriteAsync("Token de autorización requerido");
                return;
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
                    context.Response.StatusCode = (int)HttpStatusCode.Unauthorized;
                    await context.Response.WriteAsync("Token inválido");
                    return;
                }

                // Almacenar TokenLoginDTO en HttpContext.Items para acceso posterior
                context.Items["TokenLoginDTO"] = tokenDTO;

                // Continuar con el siguiente middleware
                await _next(context);
            }
            catch (Exception)
            {
                context.Response.StatusCode = (int)HttpStatusCode.Unauthorized;
                await context.Response.WriteAsync("Error al procesar el token");
            }
        }
    }
}

