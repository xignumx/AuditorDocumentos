import { request } from "./httpClient";
/**
 * @typedef {Object} DocumentoVucem
 * @property {number} id_DocumentoVucem
 * @property {number} id_Cliente
 * @property {string} documento
 * @property {number} id_Vucem
 * @property {number} id_TipoDocumento
 * @property {number} bit_Requerido
 * @property {number} operativo
 * @property {number} administrativo
 * @property {string} nombreAnterior
 * @property {string} prefijoEI
 * @property {number} activo
 */
/**
 * @typedef {import("../models/api").ApiResponse<DocumentoVucem>} MotorConfigDocumentosVucemResponse
 */
/**
 * @typedef {Object} Cliente
 * @property {string} idCliente
 * @property {string} razonSocial
 * @property {string} rfc
 * @property {string} cveCliente
 */
/**
 * @typedef {import("../models/api").ApiResponse<Cliente>} MotorConfigClientesResponse
 */
/**
 * @typedef {Object} Aduana
 * @property {string} idAduana
 * @property {string} seccionAduana
 * @property {string} descripcionOficial
 * @property {string} aduana
 * @property {string} descripcion
 */
/**
 * @typedef {import("../models/api").ApiResponse<Aduana>} MotorConfigAduanasResponse
 */
/**
 * @typedef {Object} Regimen
 * @property {string} idRegimen
 * @property {string} descripcionReg
 */
/**
 * @typedef {import("../models/api").ApiResponse<Regimen>} MotorConfigRegimenesResponse
 */
/**
 * @typedef {Object} Proveedor
 * @property {number} totalRows
 * @property {number} idProveedor
 * @property {string} proveedor
 */
/**
 * @typedef {import("../models/api").ApiResponse<Proveedor>} MotorConfigProveedoresResponse
 */
/**
 * @typedef {Object} MotorConfigDetalle
 * @property {number} id
 * @property {number} idMotorConfigHeader
 * @property {number} idCampo
 * @property {string} nombreCampo
 * @property {boolean} visible
 * @property {boolean} obligatorio
 * @property {string} motorConfigHeader
 */
/**
 * @typedef {Object} MotorConfigHeader
 * @property {number} id
 * @property {string} idCliente
 * @property {number} idTipoDocumentoVucem
 * @property {number} idClasificacion
 * @property {boolean} activo
 * @property {string} fechaCreacion
 * @property {string} creadoPor
 * @property {string} fechaActualizacion
 * @property {string} actualizadoPor
 * @property {string} motivoCambio
 * @property {string} accionPedimento
 * @property {string} perfilCarga
 * @property {MotorConfigDetalle[]} detalles
 */
/**
 * @typedef {import("../models/api").ApiResponseData<MotorConfigHeader>} MotorConfigHeaderResponse
 */
/**
 * @typedef {import("../models/api").ApiResponseBase} MotorConfigValidaFraccionResponse
 */
/**
 * @typedef {import("../models/api").ApiResponseData<string>} MotorConfigValidaUnidadMedidaResponse
 */
/**
 * @typedef {import("../models/api").ApiResponseData<string>} MotorConfigValidaPaisResponse
 */
/**
 * @typedef {import("../models/api").ApiResponseData<boolean>} MotorConfigValidaExistenciaResponse
 */
/**
 * @typedef {import("../models/api").ApiResponseData<boolean>} MotorConfigPuedeCambiarClasificacionResponse
 */
/**
 * @typedef {Object} SugerenciaPedimentoFiltro
 * @property {number} idAdDocumento
 * @property {string} [operacionBusqueda]
 */
/**
 * @typedef {Object} SugerenciaPedimentoItem
 * @property {number} idReferencia
 * @property {number | null} [idRectificacion]
 * @property {string} patente
 * @property {string} aduana
 * @property {string | null} [pedimento]
 * @property {string} tipoOperacion
 * @property {string} clavePedimento
 * @property {number} totalRecords
 */
/**
 * @typedef {import("../models/api").ApiResponse<SugerenciaPedimentoItem>} MotorConfigSugerenciaPedimentosResponse
 */

export const motorConfigService = {
  /**
   * @param {string} [token]
   * @returns {Promise<any>}
   */
  async list(token) {
    return request("/motor-config", { token });
  },
  /**
   * @param {import("../models/api").PaginatedRequest} payload
   * @param {string} [token]
   * @returns {Promise<MotorConfigDocumentosVucemResponse>}
   */
  async obtenerDocumentosVucem(payload, token) {
    return request("/api/MotorConfig/ObtenerDocumentosVucem", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").PaginatedRequest} payload
   * @param {string} [token]
   * @returns {Promise<MotorConfigClientesResponse>}
   */
  async obtenerClientes(payload, token) {
    return request("/api/MotorConfig/ObtenerClientes", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").PaginatedRequest} payload
   * @param {string} [token]
   * @returns {Promise<MotorConfigAduanasResponse>}
   */
  async obtenerAduanas(payload, token) {
    return request("/api/MotorConfig/ObtenerAduanas", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").PaginatedRequest & {
   *   data: { filter: string, tipoOperacion: string | null }
   * }} payload
   * @param {string} [token]
   * @returns {Promise<MotorConfigRegimenesResponse>}
   */
  async obtenerRegimenes(payload, token) {
    return request("/api/MotorConfig/ObtenerRegimenes", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase<import("../models/api").PaginatedRequest>} payload
   * @param {string} [token]
   * @returns {Promise<MotorConfigProveedoresResponse>}
   */
  async obtenerProveedores(payload, token) {
    return request("/api/MotorConfig/ObtenerProveedores", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase} payload
   * @param {string} [token]
   * @returns {Promise<MotorConfigHeaderResponse>}
   */
  async obtenerMotorConfig(payload, token) {
    return request("/api/MotorConfig/ObtenerMotorConfig", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase<MotorConfigHeader>} payload
   * @param {string} [token]
   * @returns {Promise<MotorConfigHeaderResponse>}
   */
  async guardarMotorConfig(payload, token) {
    return request("/api/MotorConfig/GuardarMotorConfig", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase<string>} payload
   * @param {string} [token]
   * @returns {Promise<MotorConfigValidaFraccionResponse>}
   */
  async validaFraccion(payload, token) {
    return request("/api/MotorConfig/ValidaFraccion", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase<string>} payload
   * @param {string} [token]
   * @returns {Promise<MotorConfigValidaUnidadMedidaResponse>}
   */
  async validaUnidadMedida(payload, token) {
    return request("/api/MotorConfig/ValidaUnidadMedida", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase<string>} payload
   * @param {string} [token]
   * @returns {Promise<MotorConfigValidaPaisResponse>}
   */
  async validaPais(payload, token) {
    return request("/api/MotorConfig/ValidaPais", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase} payload
   * @param {string} [token]
   * @returns {Promise<MotorConfigValidaExistenciaResponse>}
   */
  async validaExistenciaMotorConfig(payload, token) {
    return request("/api/MotorConfig/ValidaExistenciaMotorConfig", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase<number>} payload
   * @param {string} [token]
   * @returns {Promise<MotorConfigPuedeCambiarClasificacionResponse>}
   */
  async puedeCambiarClasificacion(payload, token) {
    return request("/api/MotorConfig/PuedeCambiarClasificacion", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {string} [token]
   * @returns {Promise<import("../models/api").ApiResponseData<boolean>>}
   */
  async validaUsuarioAdminLider(token) {
    return request("/api/MotorConfig/ValidaUsuarioAdminLider", {
      method: "GET",
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase<{
   *   data: SugerenciaPedimentoFiltro,
   *   page: number,
   *   size: number
   * }>} payload
   * @param {string} [token]
   * @returns {Promise<MotorConfigSugerenciaPedimentosResponse>}
   */
  async obtenerSugerenciaPedimentos(payload, token) {
    return request("/api/MotorConfig/ObtenerSugerenciaPedimentos", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * Misma forma que obtenerSugerenciaPedimentos pero sin paginación; `data.operacionBusqueda` identifica la operación a diagnosticar.
   * @param {Object} payload
   * @param {string} [token]
   * @returns {Promise<import("../models/api").ApiResponseData<Array<{ validacion?: string, resultado?: string, detalleDocumento?: string, detallePedimento?: string }>>>}
   */
  async diagnosticoSugerenciaPedimentos(payload, token) {
    return request("/api/MotorConfig/DiagnosticoSugerenciaPedimentos", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
};
