using System.ComponentModel.DataAnnotations.Schema;

namespace Aduax.AuditorDocumentos.Api.Data.EDOCS
{
    public class CspVuceSellosRfcResult
    {
        [Column("Id_Sello_Cliente")]
        public int IdSelloCliente { get; set; }

        [Column("Id_Sello_Aduana")]
        public int IdSelloAduana { get; set; }
    }
}
