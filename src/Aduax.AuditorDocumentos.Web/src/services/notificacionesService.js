import { request } from "./httpClient";

/**
 * @typedef {Object} AdNotifConfig
 * @property {number} id
 * @property {number} idMotorConfigHeader
 * @property {string} correos
 * @property {string} diasAntesVencimiento
 * @property {boolean} recordarCorreos
 * @property {string} fechaCreacion
 * @property {string} creadoPor
 * @property {string} [fechaActualizacion]
 * @property {string} [actualizadoPor]
 */
/**
 * @typedef {import("../models/api").ApiResponseData<AdNotifConfig>} NotifConfigResponse
 */
/**
 * @typedef {import("../models/api").ApiResponseData<string[]>} NotifCorreosRecordadosResponse
 */

export const notificacionesService = {
  /**
   * @param {import("../models/api").MotorConfigRequestBase<number | null>} payload
   * @param {string} [token]
   * @returns {Promise<NotifConfigResponse>}
   */
  async obtenerNotifConfig(payload, token) {
    return request("/api/NotificacionConfig/ObtenerNotifConfig", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase<AdNotifConfig>} payload
   * @param {string} [token]
   * @returns {Promise<NotifConfigResponse>}
   */
  async guardarNotifConfig(payload, token) {
    return request("/api/NotificacionConfig/GuardarNotifConfig", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
  /**
   * @param {import("../models/api").MotorConfigRequestBase<string>} payload
   * @param {string} [token]
   * @returns {Promise<NotifCorreosRecordadosResponse>}
   */
  async recuperaCorreosRecordados(payload, token) {
    return request("/api/NotificacionConfig/RecuperaCorreosRecordados", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
};
