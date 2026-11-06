import { useEffect, useMemo, useRef, useState } from "react";
import "./PaginatedSelect.css";

/**
 * @param {Object} props
 * @param {string|number} props.value
 * @param {(value: string|number) => void} props.onChange
 * @param {(item: any) => void} [props.onSelectItem]
 * @param {string} [props.placeholder]
 * @param {boolean} [props.disabled]
 * @param {boolean} [props.allowClear]
 * @param {(params: import("../models/api").PaginatedRequest & { token?: string }) => Promise<import("../models/api").ApiResponse<any>>} props.loadPage
 * @param {number} [props.pageSize]
 * @param {string} [props.token]
 * @param {(item: any) => string|number} [props.getOptionValue]
 * @param {(item: any) => string} [props.getOptionLabel]
 * @param {boolean} [props.filterable]
 * @param {string} [props.initialFilter]
 * @param {(info: { totalRecords: number, page: number, filter: string, replace: boolean }) => void} [props.onAfterLoad]
 */
export default function PaginatedSelect({
  value,
  onChange,
  onSelectItem,
  placeholder = "Seleccione una opción...",
  disabled = false,
  allowClear = false,
  loadPage,
  pageSize = 10,
  token,
  onAfterLoad,
  getOptionValue = (item) =>
    item?.value ?? item?.id ?? item?.id_DocumentoVucem ?? "",
  getOptionLabel = (item) =>
    item?.label ?? item?.documento ?? String(getOptionValue(item)),
  filterable = false,
  initialFilter = "",
}) {
  const [isOpen, setIsOpen] = useState(false);
  const [items, setItems] = useState([]);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [filter, setFilter] = useState(initialFilter);
  const selectRef = useRef(null);

  const selectedItem = useMemo(
    () => items.find((item) => getOptionValue(item) === value),
    [items, getOptionValue, value]
  );

  const handleClear = (event) => {
    event.stopPropagation();
    if (disabled) {
      return;
    }
    onChange?.("");
    onSelectItem?.(null);
  };

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (selectRef.current && !selectRef.current.contains(event.target)) {
        setIsOpen(false);
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const fetchPage = async (pageToLoad, replace = false) => {
    if (!loadPage) {
      return;
    }
    setLoading(true);
    setError("");
    try {
      const response = await loadPage({
        filter,
        page: pageToLoad,
        size: pageSize,
        token,
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

      setItems((prev) => (replace ? nextItems : [...prev, ...nextItems]));
      setPage(currentPage);
      setHasMore(Boolean(more));
      const totalRecords =
        typeof pageData.totalRecords === "number"
          ? pageData.totalRecords
          : nextItems.length;
      onAfterLoad?.({
        totalRecords,
        page: currentPage,
        filter,
        replace,
      });
    } catch (err) {
      setError("No se pudieron cargar los datos.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (isOpen && items.length === 0 && !loading) {
      fetchPage(1, true);
    }
  }, [isOpen]);

  useEffect(() => {
    if (!isOpen) {
      return;
    }
    setItems([]);
    setPage(1);
    setHasMore(true);
    fetchPage(1, true);
  }, [filter]);

  const handleSelect = (item) => {
    onChange?.(getOptionValue(item));
    onSelectItem?.(item);
    setIsOpen(false);
  };

  return (
    <div
      ref={selectRef}
      className={`oc-dropdown-select paginated-select ${disabled ? "disabled" : ""} ${
        isOpen ? "open" : ""
      }`}
    >
      <div
        className={`select-selected ${isOpen ? "select-arrow-active" : ""}`}
        onClick={() => !disabled && setIsOpen(!isOpen)}
      >
        <span className={selectedItem ? "has-value" : "placeholder"}>
          {selectedItem ? getOptionLabel(selectedItem) : placeholder}
        </span>
        {allowClear && value && !disabled && (
          <button
            type="button"
            className="select-clear"
            onClick={handleClear}
            aria-label="Limpiar selección"
            title="Limpiar"
          >
            ×
          </button>
        )}
        <svg
          className="select-arrow"
          width="12"
          height="8"
          viewBox="0 0 12 8"
          fill="none"
        >
          <path
            d="M1 1.5L6 6.5L11 1.5"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </div>
      {isOpen && !disabled && (
        <div className="select-items">
          {filterable && (
            <div className="select-filter">
              <input
                type="text"
                value={filter}
                onChange={(event) => setFilter(event.target.value)}
                placeholder="Filtrar..."
              />
            </div>
          )}

          {items.map((item) => {
            const itemValue = getOptionValue(item);
            return (
              <div
                key={itemValue}
                className={`select-item ${
                  value === itemValue ? "same-as-selected" : ""
                }`}
                onClick={() => handleSelect(item)}
              >
                {getOptionLabel(item)}
              </div>
            );
          })}

          {loading && <div className="select-status">Cargando...</div>}
          {error && <div className="select-status error">{error}</div>}
          {!loading && !items.length && !error && (
            <div className="select-status">Sin resultados</div>
          )}
          {!loading && hasMore && (
            <button
              type="button"
              className="select-load-more"
              onClick={() => fetchPage(page + 1)}
            >
              Cargar más
            </button>
          )}
        </div>
      )}
    </div>
  );
}
