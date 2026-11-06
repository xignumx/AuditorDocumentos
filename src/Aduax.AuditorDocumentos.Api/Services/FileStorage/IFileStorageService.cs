namespace Aduax.AuditorDocumentos.Api.Services.FileStorage
{
    public interface IFileStorageService
    {
        string SaveDocumentAws(byte[] fileBytes, string fileName, string referencia, string rfcCliente);
    }
}
