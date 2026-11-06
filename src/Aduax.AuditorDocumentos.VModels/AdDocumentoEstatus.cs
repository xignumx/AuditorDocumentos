namespace Aduax.AuditorDocumentos.VModels
{
    public enum AdDocumentoEstatus : int
    {
        Registro = 1,
        Pendiente = 2,
        Aprobado = 3,
        Rechazado = 4,
        VinculadoOperacion = 5,
        DigitalizadoEdocs = 6,
        ErrorDigitalizacion = 7,
        Eliminado = 8
    }
}
