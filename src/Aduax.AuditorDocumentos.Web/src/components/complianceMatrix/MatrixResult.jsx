import { useEffect, useMemo, useState } from "react";
import Button from "../Button";
import Select from "../Select";

const PAGE_SIZE = 15;

const ESTADO_LABELS = {
  NUEVO: "Nuevo",
  MODIFICA: "Modifica",
  SIN_CAMBIOS: "Sin cambios",
  ERROR: "Error",
};

const estadoOptions = [
  { value: "", label: "Todos los estados" },
  ...Object.entries(ESTADO_LABELS).map(([value, label]) => ({ value, label })),
];

/** Resumen y detalle de la vista previa o del resultado de aplicar la carga masiva. */
export default function MatrixResult({ result }) {
  const [estado, setEstado] = useState("");
  const [page, setPage] = useState(1);

  useEffect(() => {
    setEstado("");
    setPage(1);
  }, [result]);

  const filtered = useMemo(
    () => (estado ? result.items.filter((item) => item.estado === estado) : result.items),
    [result, estado]
  );
  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const visibleItems = filtered.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);
  const hasFileErrors = result.erroresArchivo.length > 0;

  return (
    <div className="cm-result">
      {hasFileErrors && (
        <div className="cm-alert cm-alert-error" role="alert">
          <strong>El archivo tiene errores. No se calculó ni se aplicó ningún cambio.</strong>
          <ul>
            {result.erroresArchivo.map((error) => (
              <li key={error}>{error}</li>
            ))}
          </ul>
        </div>
      )}

      {result.avisos.length > 0 && (
        <div className="cm-alert cm-alert-info">
          <ul>
            {result.avisos.map((aviso) => (
              <li key={aviso}>{aviso}</li>
            ))}
          </ul>
        </div>
      )}

      {!hasFileErrors && (
        <>
          <div className="cm-kpis">
            <div className="cm-kpi">
              <span className="cm-kpi-value">{result.totalNuevos}</span>
              <span className="cm-kpi-label">Nuevos</span>
            </div>
            <div className="cm-kpi">
              <span className="cm-kpi-value">{result.totalModifica}</span>
              <span className="cm-kpi-label">Modifican</span>
            </div>
            <div className="cm-kpi">
              <span className="cm-kpi-value">{result.totalSinCambios}</span>
              <span className="cm-kpi-label">Sin cambios</span>
            </div>
            <div className="cm-kpi cm-kpi-error">
              <span className="cm-kpi-value">{result.totalErrores}</span>
              <span className="cm-kpi-label">Con error</span>
            </div>
            {!result.soloPrevisualizar && (
              <div className="cm-kpi cm-kpi-ok">
                <span className="cm-kpi-value">{result.totalAplicados}</span>
                <span className="cm-kpi-label">Aplicados</span>
              </div>
            )}
          </div>

          <div className="cm-result-toolbar">
            <div className="cm-result-filter">
              <Select
                options={estadoOptions}
                value={estado}
                onChange={(value) => {
                  setEstado(value);
                  setPage(1);
                }}
              />
            </div>
            <span className="cm-helper">
              {result.totalClientes} cliente(s) · {result.totalFilasArchivo} fila(s) del archivo ·{" "}
              {filtered.length} resultado(s)
            </span>
          </div>

          <div className="cm-table-wrap">
            <table className="cm-table">
              <thead>
                <tr>
                  <th>Cliente</th>
                  <th>Tipo de documento</th>
                  <th>Estado</th>
                  <th>Detalle</th>
                </tr>
              </thead>
              <tbody>
                {visibleItems.length === 0 ? (
                  <tr>
                    <td colSpan={4} className="cm-empty-cell">
                      Sin resultados con el filtro actual.
                    </td>
                  </tr>
                ) : (
                  visibleItems.map((item) => (
                    <tr key={`${item.idCliente}|${item.idTipoDocumentoVucem}`}>
                      <td>
                        <span className="cm-strong">{item.idCliente}</span> {item.razonSocial}
                      </td>
                      <td>{item.documento}</td>
                      <td>
                        <span className={`cm-badge cm-badge-${item.estado.toLowerCase()}`}>
                          {ESTADO_LABELS[item.estado] ?? item.estado}
                          {item.aplicado ? " ✓" : ""}
                        </span>
                      </td>
                      <td className="cm-detail">
                        {item.estado === "ERROR" ? (
                          <span className="cm-error-text">{item.mensaje}</span>
                        ) : item.cambios.length === 0 ? (
                          <span className="cm-helper">
                            {item.estado === "NUEVO" ? "Se crea con valores por defecto" : "Sin cambios"}
                          </span>
                        ) : (
                          <ul>
                            {item.estado === "NUEVO" && <li>Se crea la configuración</li>}
                            {item.cambios.map((cambio) => (
                              <li key={cambio}>{cambio}</li>
                            ))}
                            {item.totalCambios > item.cambios.length && (
                              <li className="cm-helper">
                                y {item.totalCambios - item.cambios.length} cambio(s) más
                              </li>
                            )}
                          </ul>
                        )}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>

          <div className="cm-pager">
            <span className="cm-helper">
              Página {page} de {totalPages}
            </span>
            <Button variant="secondary" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>
              Anterior
            </Button>
            <Button variant="secondary" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>
              Siguiente
            </Button>
          </div>
        </>
      )}
    </div>
  );
}
