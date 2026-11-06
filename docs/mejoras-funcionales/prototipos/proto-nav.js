function svgIcon(inner) {
  return `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">${inner}</svg>`;
}

const protoIcons = {
  eye: svgIcon('<path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12z"/><circle cx="12" cy="12" r="3"/>'),
  check: svgIcon('<polyline points="20 6 9 17 4 12"/>'),
  trash: svgIcon('<polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/><path d="M10 11v6"/><path d="M14 11v6"/><path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"/>'),
  file: svgIcon('<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/>'),
};

function icon(name) {
  const paths = {
    settings: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09a1.65 1.65 0 0 0-1-1.51 1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l-.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09a1.65 1.65 0 0 0 1.51-1 1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33A1.65 1.65 0 0 0 9 3.09V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82 1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>',
    list: '<line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/>',
    upload: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/>',
    bell: '<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 7h18s-3 0-3-7"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/>',
    folder: '<path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/>',
    spark: '<path d="M12 2l1.5 6.5L20 10l-6.5 1.5L12 18l-1.5-6.5L4 10l6.5-1.5z"/>',
    shield: '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>',
    chart: '<line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/>',
  };
  return `<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">${paths[name] || ""}</svg>`;
}

function protoHeader(active, client) {
  const items = [
    ["config.html", "settings", "Config. documentos", "config"],
    ["repositorio.html", "list", "Repo. documentos", "repo"],
    ["alta.html", "upload", "Alta documento", "alta"],
    ["notificaciones.html", "bell", "Config. notificaciones", "notif"],
    ["index.html", "folder", "Expediente", "expediente"],
    ["ia-rules.html", "spark", "Reglas IA", "ia"],
    ["compliance.html", "shield", "Compliance", "compliance"],
    ["reportes.html", "chart", "Reportes", "reportes"],
  ];
  const nav = items
    .map(
      ([href, ic, label, key]) =>
        `<a class="app-header-link${active === key ? " active" : ""}" href="${href}">${icon(ic)}<span>${label}</span></a>`
    )
    .join("");
  return `
    <header class="app-header">
      <nav class="app-header-nav">${nav}</nav>
      <div class="app-header-client">
        <span class="app-header-label">Cliente</span>
        <div class="client-pill">${client || "0324 PARKER-HANNIFIN DE MÉXICO SA DE CV (TOLUCA)"}</div>
      </div>
    </header>`;
}

function protoPageHeader(title, subtitle, svgInner) {
  return `
    <div class="page-header">
      <div class="page-header-content">
        <div class="page-header-icon">${svgInner || icon("folder")}</div>
        <div>
          <h1 class="page-header-title">${title}</h1>
          <p class="page-header-subtitle">${subtitle}</p>
        </div>
      </div>
    </div>`;
}

const VUCEM_DOCS = [
  { id: 436, name: "AAIPS", prefijo: "3-009" },
  { id: 189, name: "Actas administrativas", prefijo: "3-016" },
  { id: 82, name: "Acuse de COVE", prefijo: "7-003" },
  { id: 59, name: "Acuse eDocument", prefijo: "7-002" },
  { id: 81, name: "Acuses de recepcion COVE e EDOCS", prefijo: "7-001" },
  { id: 433, name: "Anexo VIII", prefijo: "4-003" },
  { id: 170, name: "Factura / CFDI en importación", prefijo: "1-002" },
  { id: 142, name: "BL / Guía", prefijo: "4-001" },
  { id: 166, name: "Antes de importación temporal de artículos", prefijo: "3-015" },
];

function protoVucemPanelHtml(selectedId, includeAll) {
  const tag =
    '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z"/><line x1="7" y1="7" x2="7.01" y2="7"/></svg>';
  const allCard = includeAll
    ? `<button type="button" class="vucem-selector-item${selectedId === "all" ? " active" : ""}" data-id="all" data-name="Todos los tipos">
        <div class="vucem-selector-title">Todos los tipos</div>
        <div class="vucem-selector-meta">
          <span class="vucem-selector-subtitle">Sin filtro</span>
          <span class="vucem-selector-divider"></span>
          <span class="vucem-selector-subtitle">Catálogo completo</span>
        </div>
      </button>`
    : "";
  const cards = VUCEM_DOCS.map(
    (d) => `<button type="button" class="vucem-selector-item${String(d.id) === String(selectedId) ? " active" : ""}" data-id="${d.id}" data-name="${d.name}">
      <div class="vucem-selector-title">${d.name}</div>
      <div class="vucem-selector-meta">
        <span class="vucem-selector-subtitle">VUCEM: ${d.id}</span>
        <span class="vucem-selector-divider"></span>
        <span class="vucem-selector-subtitle">Prefijo: ${d.prefijo}</span>
      </div>
    </button>`
  ).join("");
  return `<aside class="vucem-selector">
    <div class="section-header">${tag}<span class="section-title">Documento VUCEM</span></div>
    <input type="text" class="vucem-selector-search" placeholder="Buscar documento..." />
    <div class="vucem-selector-list">${allCard}${cards}</div>
  </aside>`;
}

function bindVucemPanel(root) {
  const search = root.querySelector(".vucem-selector-search");
  const list = root.querySelector(".vucem-selector-list");
  search.addEventListener("input", () => {
    const q = search.value.trim().toLowerCase();
    list.querySelectorAll(".vucem-selector-item").forEach((item) => {
      item.style.display = item.textContent.toLowerCase().includes(q) ? "" : "none";
    });
  });
  list.addEventListener("click", (event) => {
    const item = event.target.closest(".vucem-selector-item");
    if (!item) return;
    list.querySelectorAll(".vucem-selector-item").forEach((el) => el.classList.remove("active"));
    item.classList.add("active");
    const label = document.querySelector("[data-vucem-label]");
    if (label) label.textContent = item.dataset.name;
  });
}

document.addEventListener("DOMContentLoaded", () => {
  const mount = document.querySelector("[data-header]");
  if (mount) {
    mount.outerHTML = protoHeader(mount.dataset.header, mount.dataset.client);
  }
  const ph = document.querySelector("[data-page-header]");
  if (ph) {
    ph.outerHTML = protoPageHeader(ph.dataset.title, ph.dataset.subtitle);
  }
  document.querySelectorAll("[data-vucem-panel]").forEach((el) => {
    const selected = el.dataset.selected || "170";
    const includeAll = el.dataset.all === "true";
    el.outerHTML = protoVucemPanelHtml(selected, includeAll);
    const aside = document.querySelector(".vucem-selector");
    if (aside) bindVucemPanel(aside);
  });
});
