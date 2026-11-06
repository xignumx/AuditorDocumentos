import { API_BASE_URL } from "../config/api";

const MAX_SAFE_MESSAGE_LENGTH = 500;

function getTokenFromUrl() {
  if (typeof window === "undefined") {
    return "";
  }
  const params = new URLSearchParams(window.location.search);
  return params.get("token") || "";
}

function looksLikeHtml(text) {
  if (!text || typeof text !== "string") {
    return false;
  }
  const trimmed = text.trimStart();
  if (
    trimmed.startsWith("<!DOCTYPE") ||
    trimmed.startsWith("<html") ||
    trimmed.startsWith("<style")
  ) {
    return true;
  }
  return /HTTP\s+Error\s+\d|Bad\s+Gateway|Gateway\s+Timeout|iiserror/i.test(trimmed);
}

/**
 * Mensaje legible para errores HTTP del API (evita mostrar HTML de IIS/proxy).
 * @param {string} rawMessage
 * @param {number} [status]
 * @returns {string}
 */
export function sanitizeApiErrorMessage(rawMessage, status = 0) {
  const trimmed = (rawMessage ?? "").trim();
  if (!trimmed) {
    return defaultMessageForStatus(status);
  }

  if (looksLikeHtml(trimmed) || trimmed.length > MAX_SAFE_MESSAGE_LENGTH) {
    return defaultMessageForStatus(status);
  }

  if (trimmed.startsWith("{")) {
    try {
      const parsed = JSON.parse(trimmed);
      if (typeof parsed?.message === "string" && parsed.message.trim()) {
        const inner = parsed.message.trim();
        if (!looksLikeHtml(inner) && inner.length <= MAX_SAFE_MESSAGE_LENGTH) {
          return inner;
        }
        return defaultMessageForStatus(status);
      }
    } catch {
      // ignore
    }
  }

  return trimmed;
}

function defaultMessageForStatus(status) {
  switch (status) {
    case 408:
      return "La solicitud tardó demasiado. Intente de nuevo.";
    case 502:
      return "El servidor no pudo completar la operación (Bad Gateway). Intente más tarde.";
    case 503:
      return "El servicio no está disponible temporalmente. Intente más tarde.";
    case 504:
      return "El servidor tardó demasiado en responder (Gateway Timeout). Intente de nuevo.";
    default:
      return status > 0
        ? `Ocurrió un error al comunicarse con el servidor (${status}).`
        : "Ocurrió un error al comunicarse con el servidor.";
  }
}

function parseErrorBody(errorText) {
  const text = (errorText ?? "").trim();
  if (!text) {
    return "";
  }

  if (text.startsWith("{")) {
    try {
      const parsed = JSON.parse(text);
      if (typeof parsed?.message === "string") {
        return parsed.message.trim();
      }
    } catch {
      // ignore
    }
  }

  return text;
}

export async function request(path, options = {}) {
  const token = options.token || getTokenFromUrl();
  const authHeader = token ? { Authorization: `Bearer ${token}` } : {};
  const baseUrl = API_BASE_URL.endsWith("/")
    ? API_BASE_URL
    : `${API_BASE_URL}/`;
  const normalizedPath = path.startsWith("/") ? path.slice(1) : path;
  const url = new URL(normalizedPath, baseUrl).toString();

  const response = await fetch(url, {
    headers: {
      "Content-Type": "application/json",
      ...authHeader,
      ...(options.headers || {}),
    },
    ...options,
  });

  if (!response.ok) {
    const errorText = await response.text().catch(() => "");
    const rawMessage = parseErrorBody(errorText);
    const message = sanitizeApiErrorMessage(
      rawMessage || response.statusText,
      response.status
    );
    const error = new Error(message);
    error.status = response.status;
    error.rawMessage = rawMessage;
    throw error;
  }

  if (response.status === 204) {
    return null;
  }

  return response.json();
}
