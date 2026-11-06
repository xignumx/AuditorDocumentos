using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Aduax.AuditorDocumentos.VModels
{
    public class GenericResponse<T>
    {
        public bool Success { get; set; }
        public string Message { get; set; } = default!;
        public T? Data { get; set; }
    }
}
