const API_BASE_URLS = {
  development: "https://localhost:7031/",
  //production: "https://preproduccion.grupoei.com.mx/AuditorDocumentosApi/",
  production: "https://web.aduax.com/Auditor_API/",
};

const mode = import.meta.env.MODE || "development";

export const API_BASE_URL = API_BASE_URLS[mode] || API_BASE_URLS.development;
