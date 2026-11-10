import { useEffect, useState } from "react";
import { toast } from "react-toastify";
import { motorConfigService } from "../../services";
import { getIaCampoLabel, iaHistorialEntidadOptions } from "../../constants/iaRules";
import Button from "../Button";
import LoadingPanel from "../LoadingPanel";
import Select from "../Select";
import Toggle from "../Toggle";

const PAGE_SIZE = 10;
const MAX_PREVIEW = 140;

const ACCION_LABELS = {
  ALTA: "Alta",
  CAMBIO: "Cambio",
  ELIMINACION: "Eliminación",
};

const formatDate = (value) => {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "" : date.toLocaleString("es-MX");
};

const truncate = (value) =>
  value && value.length > MAX_PREVIEW ? `${value.slice(0, MAX_PREVIEW)}…` : value ?? "";

const describeClave = (item) => {
  if (item.entidad === "PROMPT_DOC") {
    return `Plantilla · tipo ${item.clave}`;
  }
  if (item.entidad === "PROMPT_CAMPO") {
    return `${getIaCampoLabel(item.idCampo)} · tipo ${item.idTipoDocumentoVucem}`;
  }
  return item.clave.replace("|", " · ");
};

/** Historial de cambios de prompts y diccionario (usuario, fecha y versión). */
export default function IaHistoryTab({ selectedDocument }) {
  const idTipo = selectedDocument?.id_DocumentoVucem ?? null;
  const [entidad, setEntidad] = useState("");
  const [onlySelected, setOnlySelected] = useState(false);
  const [page, setPage] = useState(1);
  const [result, setResult] = useState({ data: [], totalPages: 0, totalRecords: 0 });
  const [isLoading, setIsLoading] = useState(false);

  const filterByTipo = onlySelected && Boolean(idTipo);

  useEffect(() => {
    setPage(1);
  }, [entidad, filterByTipo, idTipo]);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      setIsLoading(true);
      try {
        const response = await motorConfigService.obtenerHistorialIa({
          data: {
            entidad: entidad || undefined,
            idTipoDocumentoVucem: filterByTipo ? idTipo : null,
          },
          page,
          size: PAGE_SIZE,
        });
        if (!response?.success) {
          throw new Error(response?.message || "No se pudo cargar el historial.");
        }
        if (!cancelled) {
          setResult(response.data ?? { data: [], totalPages: 0, totalRecords: 0 });
        }
      } catch (error) {
        if (!cancelled) {
          toast.error(error?.message || "No se pudo cargar el historial.");
        }
      } finally {
        if (!cancelled) {
          setIsLoading(false);
        }
      }
    };
    load();

    return () => {
      cancelled = true;
    };
  }, [entidad, filterByTipo, idTipo, page]);

  return (
    <div className="ia-tab-body">
      <LoadingPanel show={isLoading} message="Cargando historial..." />

      <div className="ia-toolbar">
        <div className="ia-toolbar-select">
          <Select options={iaHistorialEntidadOptions} value={entidad} onChange={setEntidad} />
        </div>
        <Toggle
          checked={filterByTipo}
          onChange={setOnlySelected}
          disabled={!idTipo}
          label="Solo el tipo de documento seleccionado"
        />
      </div>

      <div className="ia-table-wrap">
        <table className="ia-table">
          <thead>
            <tr>
              <th>Fecha</th>
              <th>Usuario</th>
              <th>Elemento</th>
              <th>Versión</th>
              <th>Acción</th>
              <th>Cambio</th>
            </tr>
          </thead>
          <tbody>
            {result.data.length === 0 ? (
              <tr>
                <td colSpan={6} className="ia-empty-cell">
                  No hay cambios registrados con el filtro actual.
                </td>
              </tr>
            ) : (
              result.data.map((item) => (
                <tr key={item.id}>
                  <td>{formatDate(item.fecha)}</td>
                  <td>{item.usuario}</td>
                  <td className="ia-strong">{describeClave(item)}</td>
                  <td>v{item.version}</td>
                  <td>{ACCION_LABELS[item.accion] ?? item.accion}</td>
                  <td className="ia-change-cell">
                    {item.valorAnterior ? (
                      <div title={item.valorAnterior}>
                        <span className="ia-change-label">Antes:</span> {truncate(item.valorAnterior)}
                      </div>
                    ) : null}
                    {item.valorNuevo ? (
                      <div title={item.valorNuevo}>
                        <span className="ia-change-label">Después:</span> {truncate(item.valorNuevo)}
                      </div>
                    ) : null}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      <div className="ia-pager">
        <span className="ia-helper">
          Página {result.totalPages === 0 ? 0 : page} de {result.totalPages} · {result.totalRecords} cambios
        </span>
        <Button variant="secondary" disabled={page <= 1 || isLoading} onClick={() => setPage((p) => p - 1)}>
          Anterior
        </Button>
        <Button
          variant="secondary"
          disabled={page >= result.totalPages || isLoading}
          onClick={() => setPage((p) => p + 1)}
        >
          Siguiente
        </Button>
      </div>
    </div>
  );
}
