import { request } from "./httpClient";

/**
 * @typedef {Object} DocumentoRequest
 * @property {number} idDocumento
 * @property {string} [nombreArchivo]
 * @property {string} [docBase64]
 */
/**
 * @typedef {Object} RechazarDocumentoRequest
 * @property {number} idDocumento
 * @property {string} [motivoRechazo]
 */
/**
 * @typedef {Object} AsociacionOperacionRequest
 * @property {number} idDocumento
 * @property {string} idReferencia
 * @property {number | null} [idRectificacion]
 * @property {string | null} [pedimento]
 * @property {boolean} [afectaOperacion]
 */
/**
 * @typedef {Object} InsertarDatosPedimentoResultDto
 * @property {boolean} resultado
 * @property {string} mensajeEjecucion
 */
/**
 * @typedef {Object} OperacionVucemRequest
 * @property {number} idDocumento
 * @property {string} idReferencia
 * @property {number | null} [idRectificacion]
 */
/**
 * @typedef {Object} EnviarDocumentoVucemRequest
 * @property {number} idDocumento
 * @property {string} idReferencia
 * @property {number | null} [idRectificacion]
 * @property {string} origenSello
 * @property {string} [correoElectronico]
 */
/**
 * @typedef {Object} VucemSellosLookupDto
 * @property {number} idSelloCliente
 * @property {number} idSelloAduana
 * @property {string} [patente]
 * @property {string} [rfcCliente]
 * @property {string} [rfcPatente]
 */
/**
 * @typedef {Object} EnvioVucemResultDto
 * @property {number} idArchivo
 * @property {number | null} [idEnvio]
 * @property {string} [numeroOperacion]
 * @property {string} [mensaje]
 * @property {number | null} [estadoJob]
 * @property {boolean} esExitoso
 * @property {number | null} [tiempoEjecucionMs]
 */
/**
 * @typedef {Object} AdDocumentosCampos
 * @property {number} id
 * @property {number} idDocumento
 * @property {number} idCampo
 * @property {string} [valor]
 * @property {string} [documento]
 */
/**
 * @typedef {Object} AdDocumentosArchivos
 * @property {number} id
 * @property {number} idDocumento
 * @property {string} nombreArchivo
 * @property {string} extension
 * @property {number} tamanoBytes
 * @property {string} awsRuta
 * @property {string} [documento]
 */
/**
 * @typedef {Object} DocumentoExtraDatosItem
 * @property {number} idCampo
 * @property {string} nombreCampo
 * @property {string} valor
 */
/**
 * @typedef {Object} DocumentoIdentificadorGeneral
 * @property {number} idDocumento
 * @property {string} identificador
 * @property {string} [complemento]
 * @property {string} [complemento2]
 * @property {string} [complemento3]
 * @property {string} [documento]
 */
/**
 * @typedef {Object} DocumentoIdentificadorPartida
 * @property {number} idDocumento
 * @property {string} regimen
 * @property {string} [tipoAdvalorem]
 * @property {string} [origen]
 * @property {string} [documento]
 */
/**
 * @typedef {Object} DocumentoPermiso
 * @property {number} idDocumento
 * @property {string} regimen
 * @property {string} permiso
 * @property {string} [numero]
 * @property {string} [firma]
 * @property {string} [documento]
 */
/**
 * @typedef {Object} AdDocumentos
 * @property {number} id
 * @property {string} idCliente
 * @property {number} idTipoDocumentoVucem
 * @property {number} idMotorConfigHeader
 * @property {number} idEstatus
 * @property {string} [fechaVigenciaInicio]
 * @property {string} [fechaVigenciaFin]
 * @property {string} [observaciones]
 * @property {string} [comentarioRechazo]
 * @property {string} fechaCreacion
 * @property {string} creadoPor
 * @property {string} [fechaActualizacion]
 * @property {string} [actualizadoPor]
 * @property {import("./motorConfigService").MotorConfigHeader} [motorConfigHeader]
 * @property {AdDocumentosCampos[]} [campos]
 * @property {AdDocumentosArchivos} archivo
 * @property {DocumentoIdentificadorGeneral} [identificadorGeneral]
 * @property {DocumentoIdentificadorPartida} [identificadorPartida]
 * @property {DocumentoPermiso} [permiso]
 */
/**
 * @typedef {Object} CspAdDocumentosPorEstatus
 * @property {number} id
 * @property {string} [idCliente]
 * @property {number} idTipoDocumentoVucem
 * @property {string} [prefijoEI]
 * @property {number} idVucem
 * @property {string} [documentoVucem]
 * @property {string} [nombreArchivo]
 * @property {string} [awsRuta]
 * @property {string} [fechaCreacion]
 * @property {string} [creadoPor]
 * @property {string} [fechaVigenciaInicio]
 * @property {string} [fechaVigenciaFin]
 * @property {number} idClasificacion
 * @property {string} clasificacion
 * @property {string} [comentarioRechazo]
 * @property {number} idEstatus
 * @property {string} estatus
 * @property {number} estatusEnum
 * @property {boolean} [puedeAccionCritica]
 */
/**
 * @typedef {import("../models/api").ApiResponseData<DocumentoExtraDatosItem[]>} DocumentoExtraDatosResponse
 */
/**
 * @typedef {import("../models/api").ApiResponseData<number>} DocumentoInt64Response
 */
/**
 * @typedef {import("../models/api").ApiResponseData<AdDocumentos>} AdDocumentosResponse
 */
/**
 * @typedef {import("../models/api").ApiResponseData<CspAdDocumentosPorEstatus[]>} DocumentosPorEstatusResponse
 */

export const documentosService = {
  /**
   * @param {import("../models/api").MotorConfigRequestBase<DocumentoRequest>} payload
   * @param {string} [token]
   * @returns {Promise<DocumentoExtraDatosResponse>}
   */
  async extraDatosDocumentoIa(payload, token) {
    return request("/api/Documentos/ExtraDatosDocumentoIa", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase<AdDocumentos>} payload
   * @param {string} [token]
   * @returns {Promise<DocumentoInt64Response>}
   */
  async preguardaDocumento(payload, token) {
    return request("/api/Documentos/PreguardaDocumento", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase<AdDocumentos>} payload
   * @param {string} [token]
   * @returns {Promise<AdDocumentosResponse>}
   */
  async guardaDocumentoPendienteAprobacion(payload, token) {
    return request("/api/Documentos/GuardaDocumentoPendienteAprobacion", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase<number>} payload
   * @param {string} [token]
   * @returns {Promise<AdDocumentosResponse>}
   */
  async autorizaDocumento(payload, token) {
    return request("/api/Documentos/AutorizaDocumento", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase<RechazarDocumentoRequest>} payload
   * @param {string} [token]
   * @returns {Promise<AdDocumentosResponse>}
   */
  async rechazarDocumento(payload, token) {
    return request("/api/Documentos/RechazarDocumento", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase<number>} payload
   * @param {string} [token]
   * @returns {Promise<AdDocumentosResponse>}
   */
  async eliminarDocumento(payload, token) {
    return request("/api/Documentos/EliminarDocumento", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase<number>} payload
   * @param {string} [token]
   * @returns {Promise<DocumentosPorEstatusResponse>}
   */
  async obtenerDocumentos(payload, token) {
    return request("/api/Documentos/ObtenerDocumentos", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase<number>} payload
   * @param {string} [token]
   * @returns {Promise<AdDocumentosResponse>}
   */
  async obtenerDocumentoPorId(payload, token) {
    return request("/api/Documentos/ObtenerDocumentoPorId", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase} payload
   * @param {string} [token]
   * @returns {Promise<import("../models/api").ApiResponseData<boolean>>}
   */
  async validarDocumentoVigenteAprobado(payload, token) {
    return request("/api/Documentos/ValidarDocumentoVigenteAprobado", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase<AsociacionOperacionRequest>} payload
   * @param {string} [token]
   * @returns {Promise<import("../models/api").ApiResponseData<InsertarDatosPedimentoResultDto>>}
   */
  async altaAsociacionOperacion(payload, token) {
    return request("/api/Documentos/AltaAsociacionOperacion", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase<OperacionVucemRequest>} payload
   * @param {string} [token]
   */
  async obtenerSellosVucemDisponibles(payload, token) {
    return request("/api/Documentos/ObtenerSellosVucemDisponibles", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase<EnviarDocumentoVucemRequest>} payload
   * @param {string} [token]
   */
  async enviarDocumentoVucem(payload, token) {
    return request("/api/Documentos/EnviarDocumentoVucem", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase<{ idDocumento: number, idReferencia: string, idRectificacion?: number|null }>} payload
   * @param {string} [token]
   */
  async eliminarAsociacionOperacion(payload, token) {
    return request("/api/Documentos/EliminarAsociacionOperacion", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
};
