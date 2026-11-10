import { useEffect, useRef, useState } from "react";
import { toast } from "react-toastify";
import { motorConfigService } from "../../services";
import Button from "../Button";

const PAGE_SIZE = 20;
const SEARCH_DELAY_MS = 400;
const BULK_PAGE_SIZE = 100;

/**
 * Lista de clientes con casillas y buscador por clave, razón social o RFC.
 * `selected` es un objeto { [idCliente]: razonSocial }; la selección se conserva al cambiar la búsqueda.
 */
export default function ClientMultiSelector({ selected, onChange, maxSelected, disabled = false }) {
  const [search, setSearch] = useState("");
  const [items, setItems] = useState([]);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(false);
  const [totalRecords, setTotalRecords] = useState(0);
  const [isLoading, setIsLoading] = useState(false);
  const requestId = useRef(0);

  const selectedIds = Object.keys(selected);
  const selectedCount = selectedIds.length;

  const loadPage = async (pageToLoad, filter, replace) => {
    const current = ++requestId.current;
    setIsLoading(true);
    try {
      const response = await motorConfigService.obtenerClientes({
        filter,
        page: pageToLoad,
        size: PAGE_SIZE,
      });
      if (current !== requestId.current) {
        return;
      }
      const pageData = response?.data || {};
      const nextItems = pageData.data || [];
      setItems((prev) => (replace ? nextItems : [...prev, ...nextItems]));
      setPage(pageData.page ?? pageToLoad);
      setHasMore(Boolean(pageData.more));
      setTotalRecords(pageData.totalRecords ?? nextItems.length);
    } catch (error) {
      if (current === requestId.current) {
        toast.error(error?.message || "No se pudieron cargar los clientes.");
      }
    } finally {
      if (current === requestId.current) {
        setIsLoading(false);
      }
    }
  };

  useEffect(() => {
    const timer = setTimeout(() => {
      loadPage(1, search.trim(), true);
    }, SEARCH_DELAY_MS);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search]);

  const toggle = (client) => {
    const next = { ...selected };
    if (next[client.idCliente] !== undefined) {
      delete next[client.idCliente];
    } else {
      if (maxSelected && Object.keys(next).length >= maxSelected) {
        toast.warn(`Solo se pueden seleccionar ${maxSelected} clientes por carga.`);
        return;
      }
      next[client.idCliente] = client.razonSocial;
    }
    onChange(next);
  };

  const selectAllMatching = async () => {
    setIsLoading(true);
    try {
      const next = { ...selected };
      let currentPage = 1;
      let more = true;
      let truncated = false;
      while (more && !truncated) {
        const response = await motorConfigService.obtenerClientes({
          filter: search.trim(),
          page: currentPage,
          size: BULK_PAGE_SIZE,
        });
        const pageData = response?.data || {};
        for (const client of pageData.data || []) {
          if (maxSelected && Object.keys(next).length >= maxSelected) {
            truncated = true;
            break;
          }
          next[client.idCliente] = client.razonSocial;
        }
        more = Boolean(pageData.more);
        currentPage += 1;
      }
      onChange(next);
      if (truncated) {
        toast.warn(`Se seleccionaron los primeros ${maxSelected} clientes (máximo por carga).`);
      }
    } catch (error) {
      toast.error(error?.message || "No se pudieron seleccionar los clientes.");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="cm-clients">
      <div className="cm-clients-toolbar">
        <input
          type="search"
          className="cm-input"
          placeholder="Buscar por clave, razón social o RFC..."
          value={search}
          disabled={disabled}
          onChange={(event) => setSearch(event.target.value)}
        />
        <Button variant="secondary" disabled={disabled || isLoading || totalRecords === 0} onClick={selectAllMatching}>
          Seleccionar resultados ({totalRecords})
        </Button>
        <Button variant="secondary" disabled={disabled || selectedCount === 0} onClick={() => onChange({})}>
          Limpiar
        </Button>
      </div>

      <div className="cm-clients-list" role="group" aria-label="Clientes">
        {items.length === 0 && !isLoading ? (
          <p className="cm-helper cm-clients-empty">Sin clientes para la búsqueda.</p>
        ) : (
          items.map((client) => (
            <label key={client.idCliente} className="cm-client-row">
              <input
                type="checkbox"
                checked={selected[client.idCliente] !== undefined}
                disabled={disabled}
                onChange={() => toggle(client)}
              />
              <span className="cm-client-id">{client.idCliente}</span>
              <span className="cm-client-name">{client.razonSocial}</span>
            </label>
          ))
        )}
        {hasMore && (
          <button
            type="button"
            className="cm-link-btn"
            disabled={isLoading || disabled}
            onClick={() => loadPage(page + 1, search.trim(), false)}
          >
            Cargar más
          </button>
        )}
        {isLoading && <p className="cm-helper">Cargando...</p>}
      </div>

      <p className="cm-helper">
        {selectedCount} cliente(s) seleccionado(s)
        {maxSelected ? ` de ${maxSelected} permitidos` : ""}.
      </p>
      {selectedCount > 0 && (
        <div className="cm-chips">
          {selectedIds.slice(0, 12).map((id) => (
            <span key={id} className="cm-chip" title={selected[id]}>
              {id}
            </span>
          ))}
          {selectedCount > 12 && <span className="cm-chip cm-chip-more">+{selectedCount - 12}</span>}
        </div>
      )}
    </div>
  );
}
