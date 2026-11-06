using Microsoft.Extensions.Options;
using Newtonsoft.Json;
using Aduax.AuditorDocumentos.Api.Configuration;
using Aduax.AuditorDocumentos.Api.Services.FileStorage.Models;
using System.Net;
using System.Net.Http.Headers;

namespace Aduax.AuditorDocumentos.Api.Services.FileStorage
{
    public class FileStorageService : IFileStorageService
    {
        private readonly FileStorageCfg _fileStorageConfig;
        private readonly HttpClient _httpClient;

        public FileStorageService(IOptions<FileStorageCfg> fileStorageConfig, HttpClient httpClient)
        {
            _fileStorageConfig = fileStorageConfig.Value;
            _httpClient = httpClient;
        }

        public string SaveDocumentAws(byte[] fileBytes, string fileName, string referencia, string rfcCliente)
        {
            //Iniciamos Sesion
            CredencialesUsuario credencialesUsuario = new CredencialesUsuario()
            {
                email = _fileStorageConfig.User,
                password = _fileStorageConfig.Pass
            };

            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls | SecurityProtocolType.Tls11 | SecurityProtocolType.Tls12;
            var url = _fileStorageConfig.Url + "cuentas/login";
            HttpResponseMessage httpResponseMessage = _httpClient.PostAsJsonAsync(url, credencialesUsuario).GetAwaiter().GetResult();
            RespuestaAutenticacion respuestaAutenticacion = JsonConvert.DeserializeObject<RespuestaAutenticacion>(httpResponseMessage.Content.ReadAsStringAsync().Result);

            // Agregamos token de autenticacion
            _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", respuestaAutenticacion.token);

            //Solicitamos token de la aplicacion
            AplicacionCreacion aplicacionCreacionDTO = new AplicacionCreacion() { Nombre = _fileStorageConfig.App };
            url = _fileStorageConfig.Url + "cuentas/AgregarTokenAplicacion";
            httpResponseMessage = _httpClient.PutAsJsonAsync(url, aplicacionCreacionDTO).GetAwaiter().GetResult();
            respuestaAutenticacion = JsonConvert.DeserializeObject<RespuestaAutenticacion>(httpResponseMessage.Content.ReadAsStringAsync().Result);

            // Actualizamos el token
            _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", respuestaAutenticacion.token);

            // Creamos el contenido de la solicitud usando el byte array
            ByteArrayContent archivo = new ByteArrayContent(fileBytes);
            archivo.Headers.ContentType = new MediaTypeHeaderValue(GetMimeFromFileName(fileName));

            string tipoReferencia = _fileStorageConfig.RefType;

            MultipartFormDataContent formDataContent = new MultipartFormDataContent()
            {
                { new StringContent(tipoReferencia), "IdTipoReferencia" }, // Doc_PortalCliente
                { new StringContent(referencia), "Referencia" },
                { new StringContent(rfcCliente), "RFC" },
                { archivo, "Archivo", fileName }
            };

            // Enviamos la solicitud
            url = _fileStorageConfig.Url + "AmazonStorage";
            httpResponseMessage = _httpClient.PostAsync(url, formDataContent).GetAwaiter().GetResult();

            // Leemos la respuesta
            string response = httpResponseMessage.Content.ReadAsStringAsync().GetAwaiter().GetResult();
            try
            {
                ArchivoResponse archivoDTO = JsonConvert.DeserializeObject<ArchivoResponse>(response);
                return archivoDTO.UrlArchivo;
            }
            catch
            {
                return null;
            }
        }

        private static readonly Dictionary<string, string> MimeMappings = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            { ".txt", "text/plain" },
            { ".html", "text/html" },
            { ".htm", "text/html" },
            { ".pdf", "application/pdf" },
            { ".jpg", "image/jpeg" },
            { ".jpeg", "image/jpeg" },
            { ".png", "image/png" },
            { ".gif", "image/gif" },
            { ".bmp", "image/bmp" },
            { ".csv", "text/csv" },
            { ".json", "application/json" },
            { ".xml", "application/xml" },
            { ".zip", "application/zip" },
            { ".mp3", "audio/mpeg" },
            { ".mp4", "video/mp4" },
            { ".exe", "application/octet-stream" }, // Tipo genérico para binarios
            // Agrega más extensiones según sea necesario
        };

        private static string GetMimeFromFileName(string fileName)
        {
            string extension = Path.GetExtension(fileName);
            if (!string.IsNullOrEmpty(extension) && MimeMappings.TryGetValue(extension, out string mime))
            {
                return mime;
            }

            return "application/octet-stream"; // Tipo MIME genérico
        }
    }
}
