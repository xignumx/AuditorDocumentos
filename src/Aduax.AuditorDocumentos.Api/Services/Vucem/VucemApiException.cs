namespace Aduax.AuditorDocumentos.Api.Services.Vucem
{
    /// <summary>
    /// Error al invocar la API externa VUCEM (timeout o respuesta de error).
    /// </summary>
    public class VucemApiException : Exception
    {
        public VucemApiException(
            string message,
            bool isTimeout = false,
            bool isGatewayError = false,
            Exception? innerException = null)
            : base(message, innerException)
        {
            IsTimeout = isTimeout;
            IsGatewayError = isGatewayError;
        }

        /// <summary>HttpClient.Timeout o cancelación por tiempo de espera.</summary>
        public bool IsTimeout { get; }

        /// <summary>502/504 o HTML de proxy IIS frente a la API VUCEM.</summary>
        public bool IsGatewayError { get; }
    }
}
