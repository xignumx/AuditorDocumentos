import { useEffect, useMemo, useRef, useState } from "react";
import "./PaginatedSelect.css";
import "./PaginatedMultiSelect.css";

const splitValue = (value) =>
  String(value ?? "")
    .split(";")
    .map((v) => String(v).trim())
    .filter(Boolean);

const joinValue = (values) => values.join(";");

/**
 * @param {Object} props
 * @param {string} props.value - Semicolon-separated values (e.g. "id1;id2;id3")
 * @param {(value: string) => void} props.onChange
 * @param {string} [props.placeholder]
 * @param {boolean} [props.disabled]
 * @param {(params: import("../models/api").PaginatedRequest & { token?: string }) => Promise<import("../models/api").ApiResponse<any>>} props.loadPage
 * @param {number} [props.pageSize]
 * @param {string} [props.token]
 * @param {(item: any) => string|number} [props.getOptionValue]
 * @param {(item: any) => string} [props.getOptionLabel]
 * @param {boolean} [props.filterable]
 */
export default function PaginatedMultiSelect({
  value,
  onChange,
  placeholder = "Seleccione...",
  disabled = false,
  loadPage,
  pageSize = 10,
  token,
  getOptionValue = (item) =>
    item?.value ?? item?.id ?? item?.idRegimen ?? item?.id_DocumentoVucem ?? "",
  getOptionLabel = (item) =>
    item?.label ?? item?.documento ?? item?.idRegimen ?? String(getOptionValue(item)),
  filterable = false,
}) {
  const [isOpen, setIsOpen] = useState(false);
  const [items, setItems] = useState([]);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [filter, setFilter] = useState("");
  const selectRef = useRef(null);
  const valueToLabelRef = useRef(new Map());

  const selectedValues = useMemo(() => splitValue(value), [value]);

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
    if (!loadPage) return;
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
        typeof pageData.totalPages === "number" ? pageData.totalPages : 0;
      const more =
        typeof pageData.more === "boolean"
          ? pageData.more
          : currentPage < totalPages;

      nextItems.forEach((item) => {
        const v = getOptionValue(item);
        const lbl = getOptionLabel(item);
        if (v != null && v !== "") {
          valueToLabelRef.current.set(String(v), lbl);
        }
      });

      setItems((prev) => (replace ? nextItems : [...prev, ...nextItems]));
      setPage(currentPage);
      setHasMore(Boolean(more));
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
    if (!isOpen) return;
    setItems([]);
    setPage(1);
    setHasMore(true);
    fetchPage(1, true);
  }, [filter]);

  const getLabelForValue = (val) =>
    valueToLabelRef.current.get(String(val)) ?? String(val);

  const handleSelect = (item) => {
    const itemValue = getOptionValue(item);
    const strVal = String(itemValue ?? "");
    if (!strVal) return;
    valueToLabelRef.current.set(strVal, getOptionLabel(item));
    const next = [...new Set([...selectedValues, strVal])];
    onChange?.(joinValue(next));
  };

  const handleRemove = (valToRemove) => {
    const next = selectedValues.filter((v) => v !== valToRemove);
    onChange?.(joinValue(next));
  };

  return (
    <div
      ref={selectRef}
      className={`paginated-multi-select oc-dropdown-select ${disabled ? "disabled" : ""} ${
        isOpen ? "open" : ""
      }`}
    >
      <div
        className="paginated-multi-select-trigger select-selected"
        onClick={() => !disabled && setIsOpen(!isOpen)}
      >
        <div className="paginated-multi-select-tags">
          {selectedValues.length > 0 ? (
            selectedValues.map((val) => (
              <span key={val} className="tag-chip">
                {getLabelForValue(val)}
                <button
                  type="button"
                  className="tag-remove"
                  onClick={(e) => {
                    e.stopPropagation();
                    handleRemove(val);
                  }}
                  disabled={disabled}
                  aria-label={`Eliminar ${getLabelForValue(val)}`}
                >
                  ×
                </button>
              </span>
            ))
          ) : (
            <span className="placeholder">{placeholder}</span>
          )}
        </div>
        <svg
          className={`select-arrow ${isOpen ? "select-arrow-active" : ""}`}
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
                onChange={(e) => setFilter(e.target.value)}
                placeholder="Filtrar..."
              />
            </div>
          )}
          {items.map((item) => {
            const itemValue = getOptionValue(item);
            const strVal = String(itemValue ?? "");
            const isSelected = selectedValues.includes(strVal);
            return (
              <div
                key={strVal}
                className={`select-item ${isSelected ? "same-as-selected" : ""}`}
                onClick={() => handleSelect(item)}
              >
                {getOptionLabel(item)}
                {isSelected && " ✓"}
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
