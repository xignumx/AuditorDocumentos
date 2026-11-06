using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Aduax.AuditorDocumentos.VModels
{
    public class GenericAdRequest<T>
    {
        public string? IdCliente { get; set; }
        public int? IdTipoDocumentoVucem { get; set; }
        public T? Data { get; set; }
    }
}
