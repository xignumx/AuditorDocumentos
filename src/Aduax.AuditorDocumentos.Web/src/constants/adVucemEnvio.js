/** eDocument pendiente en Tb_Envios (equivalente guía §11). */
export const EDOCUMENT_PENDIENTE = "0000000000000";

export const OrigenSelloVucem = Object.freeze({
  Cliente: "Cliente",
  AgenteAduanal: "AgenteAduanal",
});

/**
 * Envío o reintento VUCEM: sin número de operación y sin eDocument válido.
 * - Primer envío: eDocument pendiente y sin mensaje.
 * - Reintento: mensaje de error y número vacío (puede cambiar sello/correo).
 * @param {{ edocument?: string, mensaje?: string, numero?: string } | null | undefined} operation
 * @returns {boolean}
 */
export function puedeEnviarVucem(operation) {
  const edoc = (operation?.edocument ?? "").trim();
  const msg = (operation?.mensaje ?? "").trim();
  const numero = (operation?.numero ?? "").trim();

  if (numero) {
    return false;
  }

  if (edoc && edoc !== EDOCUMENT_PENDIENTE) {
    return false;
  }

  if (!msg) {
    return !edoc || edoc === EDOCUMENT_PENDIENTE;
  }

  return true;
}

/**
 * @param {{ mensaje?: string } | null | undefined} operation
 * @returns {boolean}
 */
export function tieneMensajeVucem(operation) {
  return Boolean((operation?.mensaje ?? "").trim());
}

/**
 * Eliminar asociación: sin número, sin eDocument válido y pedimento no pagado.
 * El API sigue validando el pago como defensa en profundidad.
 * @param {{ edocument?: string, numero?: string, estaPagado?: boolean|number } | null | undefined} operation
 * @returns {boolean}
 */
export function puedeEliminarAsociacionOperacion(operation) {
  const edoc = (operation?.edocument ?? "").trim();
  const numero = (operation?.numero ?? "").trim();
  const estaPagado = operation?.estaPagado ?? operation?.EstaPagado;

  if (estaPagado === true || estaPagado === 1 || estaPagado === "1") {
    return false;
  }

  if (numero) {
    return false;
  }

  if (edoc && edoc !== EDOCUMENT_PENDIENTE) {
    return false;
  }

  return true;
}

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/**
 * @param {string} [value]
 * @returns {boolean}
 */
export function esCorreoVucemValido(value) {
  const trimmed = (value ?? "").trim();
  if (!trimmed) {
    return true;
  }
  return EMAIL_PATTERN.test(trimmed);
}

/**
 * @param {string} [value]
 * @returns {string | null}
 */
export function normalizarCorreoVucem(value) {
  const trimmed = (value ?? "").trim();
  return trimmed || null;
}

const HTML_LIKE_PATTERN =
  /^\s*<(!DOCTYPE|html|style)/i;

/**
 * Mensaje amigable para errores al enviar a VUCEM (toast / UI).
 * @param {unknown} error
 * @param {string} [fallback]
 * @returns {string}
 */
export function mensajeErrorEnvioVucem(
  error,
  fallback = "No se pudo enviar el documento a VUCEM."
) {
  const status = Number(error?.status) || 0;
  const raw =
    typeof error?.message === "string" ? error.message.trim() : "";

  if (!raw) {
    return fallback;
  }

  if (HTML_LIKE_PATTERN.test(raw) || raw.length > 500) {
    if (status === 504 || status === 408) {
      return "El envío a VUCEM tardó demasiado. El servicio externo o el servidor no respondió a tiempo; intente de nuevo más tarde.";
    }
    if (status === 502 || status === 503) {
      return "El envío a VUCEM no se completó porque el servicio no está disponible temporalmente. Intente de nuevo más tarde.";
    }
    return "El envío a VUCEM no se completó. El servidor devolvió una respuesta no válida; intente de nuevo o contacte al administrador.";
  }

  if (/timeout|timed out|gateway timeout|operation was canceled/i.test(raw)) {
    return "El envío a VUCEM tardó demasiado. Intente de nuevo más tarde.";
  }

  if (status === 504 || status === 408) {
    return raw.includes("VUCEM") ? raw : "El envío a VUCEM tardó demasiado. Intente de nuevo más tarde.";
  }

  return raw;
}
