using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.EDOCS
{
    public class CspVuceSellosAgenteResult
    {
        [Column("pk_Id_Sello")]
        public int IdSello { get; set; }
    }
}
