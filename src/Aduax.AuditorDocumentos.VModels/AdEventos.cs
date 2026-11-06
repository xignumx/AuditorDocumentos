using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Aduax.AuditorDocumentos.VModels
{
    public enum AdEventos : int
    {
        DOC_CREADO = 1,
        DOC_CARGA_ARCHIVO = 2,
        DOC_ENVIO_IA = 3,
        DOC_RESULTADO_IA = 4,
        DOC_APROBADO = 5,
        DOC_RECHAZADO = 6,
        DOC_ASOCIADO_OPERACION = 7,
        DOC_ENVIO_EDOCS = 8,
        DOC_ERROR_EDOCS = 9,
        DOC_DIGITALIZADO = 10,
        DOC_NOTIF_PROGRAMADA = 11,
        DOC_NOTIF_ENVIADA = 12,
        DOC_NOTIF_ERROR = 13,
        DOC_CAMBIO_ESTATUS = 14,
        DOC_ACTUALIZACION_DATOS = 15,
        DOC_DESASOCIADO_OPERACION = 16
    }
}
