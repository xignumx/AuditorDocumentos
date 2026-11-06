import { useEffect, useState } from "react";
import { motorConfigService } from "../services";
import "./VucemDocumentSelector.css";

const TagIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z" />
    <line x1="7" y1="7" x2="7.01" y2="7" />
  </svg>
);

export default function VucemDocumentSelector({
  value,
  onChange,
  className = "",
}) {
  const [documentFilter, setDocumentFilter] = useState("");
  const [documentItems, setDocumentItems] = useState([]);
  const [documentPage, setDocumentPage] = useState(1);
  const [documentHasMore, setDocumentHasMore] = useState(true);
  const [documentLoading, setDocumentLoading] = useState(false);
  const pageSize = 10;

  const fetchDocuments = async (pageToLoad, replace = false, filterValue) => {
    if (documentLoading) {
      return;
    }
    setDocumentLoading(true);
    try {
      const response = await motorConfigService.obtenerDocumentosVucem({
        filter: filterValue ?? documentFilter,
        page: pageToLoad,
        size: pageSize,
      });
      const pageData = response?.data || {};
      const nextItems = pageData?.data || [];
      const currentPage =
        typeof pageData.page === "number" ? pageData.page : pageToLoad;
      const totalPages =
        typeof pageData.totalPages === "number"
          ? pageData.totalPages
          : 0;
      const more =
        typeof pageData.more === "boolean"
          ? pageData.more
          : currentPage < totalPages;

      setDocumentItems((prev) => (replace ? nextItems : [...prev, ...nextItems]));
      setDocumentPage(currentPage);
      setDocumentHasMore(Boolean(more));
    } finally {
      setDocumentLoading(false);
    }
  };

  useEffect(() => {
    fetchDocuments(1, true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const timer = setTimeout(() => {
      setDocumentItems([]);
      setDocumentPage(1);
      setDocumentHasMore(true);
      fetchDocuments(1, true, documentFilter);
    }, 300);

    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [documentFilter]);

  const handleDocumentScroll = (event) => {
    const target = event.currentTarget;
    const threshold = 40;
    const reachedBottom =
      target.scrollTop + target.clientHeight >= target.scrollHeight - threshold;

    if (reachedBottom && documentHasMore && !documentLoading) {
      fetchDocuments(documentPage + 1);
    }
  };

  return (
    <aside className={`vucem-selector oc-light-card ${className}`.trim()}>
      <div className="section-header">
        <TagIcon />
        <span className="section-title">Documento VUCEM</span>
      </div>

      <input
        type="text"
        className="vucem-selector-search"
        value={documentFilter}
        onChange={(event) => setDocumentFilter(event.target.value)}
        placeholder="Buscar documento..."
      />

      <div className="vucem-selector-list" onScroll={handleDocumentScroll}>
        {documentItems.map((item) => (
          <button
            key={item.id_DocumentoVucem}
            type="button"
            className={`vucem-selector-item ${
              value?.id_DocumentoVucem === item.id_DocumentoVucem ? "active" : ""
            }`}
            onClick={() => onChange?.(item)}
          >
            <div className="vucem-selector-title">{item.documento}</div>
            <div className="vucem-selector-meta">
              <span className="vucem-selector-subtitle">
                {`VUCEM: ${item.id_Vucem ?? "-"}`}
              </span>
              <span className="vucem-selector-divider" />
              <span className="vucem-selector-subtitle">
                {`Prefijo: ${item.prefijoEI ?? "-"}`}
              </span>
            </div>
          </button>
        ))}

        {documentLoading && (
          <div className="vucem-selector-status">Cargando...</div>
        )}
        {!documentLoading && !documentItems.length && (
          <div className="vucem-selector-status">Sin resultados</div>
        )}
      </div>
    </aside>
  );
}
