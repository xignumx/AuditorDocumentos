import { useEffect, useMemo, useState } from "react";
import { toast } from "react-toastify";
import { motorConfigService } from "../../services";
import {
  getIaCampoLabel,
  iaCampoOptions,
  IaDiccionarioCategoria,
} from "../../constants/iaRules";
import Button from "../Button";
import ConfirmationModal from "../ConfirmationModal";
import LoadingPanel from "../LoadingPanel";
import PaginatedSelect from "../PaginatedSelect";
import Select from "../Select";
import TagInput from "../TagInput";

const NINGUN_CAMPO = "";

const emptyEditor = () => ({
  isNew: true,
  concepto: "",
  idCampo: NINGUN_CAMPO,
  descripcion: "",
  es: "",
  en: "",
});

const splitTags = (value) =>
  String(value ?? "")
    .split(";")
    .map((item) => item.trim())
    .filter(Boolean);

const formatUnidad = (item) =>
  item?.idUnidadUniversal
    ? `${item.idUnidadUniversal} - ${item.descripcion ?? item.descAbreviada ?? ""}`.trim()
    : "";

/**
 * Matriz editable de equivalencias ES/EN.
 * - GENERAL: etiquetas equivalentes que se inyectan en el prompt de la IA (globales).
 * - UM: variantes de unidad de medida que se normalizan al id_unidad_universal (globales).
 */
export default function IaDictionaryTab({ categoria }) {
  const isUm = categoria === IaDiccionarioCategoria.UnidadMedida;
  const [conceptos, setConceptos] = useState([]);
  const [isLoading, setIsLoading] = useState(false);
  const [search, setSearch] = useState("");
  const [editor, setEditor] = useState(null);
  const [toDelete, setToDelete] = useState(null);

  const campoOptions = useMemo(
    () => [
      { value: NINGUN_CAMPO, label: "Ninguno (aplica a todo el documento)" },
      ...iaCampoOptions.map((option) => ({ value: String(option.value), label: option.label })),
    ],
    []
  );

  const loadConceptos = async () => {
    setIsLoading(true);
    try {
      const response = await motorConfigService.obtenerDiccionarioIa(categoria);
      if (!response?.success) {
        throw new Error(response?.message || "No se pudo cargar el diccionario.");
      }
      setConceptos(response.data ?? []);
    } catch (error) {
      toast.error(error?.message || "No se pudo cargar el diccionario.");
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    setEditor(null);
    setSearch("");
    loadConceptos();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [categoria]);

  const filtered = useMemo(() => {
    const term = search.trim().toLowerCase();
    if (!term) {
      return conceptos;
    }
    return conceptos.filter((item) =>
      [item.concepto, item.descripcion, ...item.terminosEs, ...item.terminosEn]
        .filter(Boolean)
        .some((value) => String(value).toLowerCase().includes(term))
    );
  }, [conceptos, search]);

  const startEdit = (item) =>
    setEditor({
      isNew: false,
      concepto: item.concepto,
      idCampo: item.idCampo ? String(item.idCampo) : NINGUN_CAMPO,
      descripcion: item.descripcion ?? "",
      es: item.terminosEs.join(";"),
      en: item.terminosEn.join(";"),
    });

  const handleSave = async () => {
    const terminosEs = splitTags(editor.es);
    const terminosEn = splitTags(editor.en);

    if (!editor.concepto.trim()) {
      toast.error(isUm ? "Seleccione la unidad de medida." : "Capture el concepto.");
      return;
    }
    if (terminosEs.length + terminosEn.length === 0) {
      toast.error("Capture al menos un término en español o inglés.");
      return;
    }

    setIsLoading(true);
    try {
      const response = await motorConfigService.guardarDiccionarioConceptoIa({
        categoria,
        concepto: editor.concepto.trim(),
        idCampo: !isUm && editor.idCampo ? Number(editor.idCampo) : null,
        terminosEs,
        terminosEn,
      });
      if (!response?.success) {
        throw new Error(response?.message || "No se pudo guardar el diccionario.");
      }
      toast.success("Diccionario guardado correctamente.");
      setEditor(null);
      await loadConceptos();
    } catch (error) {
      toast.error(error?.message || "No se pudo guardar el diccionario.");
      setIsLoading(false);
    }
  };

  const handleDelete = async () => {
    const target = toDelete;
    setToDelete(null);
    setIsLoading(true);
    try {
      const response = await motorConfigService.eliminarDiccionarioConceptoIa({
        categoria,
        concepto: target.concepto,
      });
      if (!response?.success) {
        throw new Error(response?.message || "No se pudo eliminar el concepto.");
      }
      toast.success("Concepto eliminado correctamente.");
      await loadConceptos();
    } catch (error) {
      toast.error(error?.message || "No se pudo eliminar el concepto.");
      setIsLoading(false);
    }
  };

  const renderChips = (items) =>
    items.length ? (
      <div className="ia-chips">
        {items.map((item) => (
          <span key={item} className="ia-chip">
            {item}
          </span>
        ))}
      </div>
    ) : (
      <span className="ia-helper">—</span>
    );

  return (
    <div className="ia-tab-body">
      <LoadingPanel show={isLoading} message="Procesando..." />
      <ConfirmationModal
        open={Boolean(toDelete)}
        title="Eliminar concepto"
        message={`Se eliminará "${toDelete?.concepto ?? ""}" con todos sus términos. ¿Deseas continuar?`}
        confirmLabel="Eliminar"
        onConfirm={handleDelete}
        onCancel={() => setToDelete(null)}
      />

      <p className="ia-hint">
        {isUm
          ? "Equivalencias globales de unidad de medida: cuando la IA lee una de estas variantes, el valor se normaliza a la clave de la unidad en ADUASIS. Un término solo puede pertenecer a una unidad."
          : "Equivalencias globales ES/EN que se envían a la IA al leer el documento. Un término solo puede pertenecer a un concepto."}
      </p>

      <div className="ia-toolbar">
        <input
          type="search"
          className="ia-input ia-search"
          placeholder="Buscar concepto o término..."
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
        <Button variant="primary" disabled={Boolean(editor)} onClick={() => setEditor(emptyEditor())}>
          {isUm ? "Agregar unidad" : "Agregar concepto"}
        </Button>
      </div>

      {editor && (
        <section className="ia-editor oc-light-card">
          <div className="ia-editor-grid">
            <div className="ia-field">
              <label className="ia-label">{isUm ? "Unidad de medida" : "Concepto"}</label>
              {isUm ? (
                editor.isNew ? (
                  <PaginatedSelect
                    value={editor.concepto}
                    onChange={(value) => setEditor((prev) => ({ ...prev, concepto: String(value ?? "") }))}
                    placeholder="Busque por clave o descripción..."
                    filterable
                    loadPage={({ filter, page, size, token }) =>
                      motorConfigService.obtenerUnidadesMedida({ filter, page, size }, token)
                    }
                    getOptionValue={(item) => item?.idUnidadUniversal ?? ""}
                    getOptionLabel={formatUnidad}
                  />
                ) : (
                  <input
                    className="ia-input"
                    disabled
                    value={`${editor.concepto}${editor.descripcion ? ` - ${editor.descripcion}` : ""}`}
                    readOnly
                  />
                )
              ) : (
                <input
                  className="ia-input"
                  maxLength={100}
                  disabled={!editor.isNew}
                  value={editor.concepto}
                  placeholder="Ej. Número de parte"
                  onChange={(event) => setEditor((prev) => ({ ...prev, concepto: event.target.value }))}
                />
              )}
            </div>
            {!isUm && (
              <div className="ia-field">
                <label className="ia-label">Campo destino (opcional)</label>
                <Select
                  options={campoOptions}
                  value={editor.idCampo}
                  onChange={(value) => setEditor((prev) => ({ ...prev, idCampo: value }))}
                />
                <span className="ia-helper">
                  Con campo destino, el concepto solo se envía cuando ese campo está visible en el motor.
                </span>
              </div>
            )}
            <div className="ia-field">
              <label className="ia-label">Español</label>
              <TagInput
                value={editor.es}
                onChange={(value) => setEditor((prev) => ({ ...prev, es: value }))}
                placeholder="Escriba un término y presione Enter"
              />
            </div>
            <div className="ia-field">
              <label className="ia-label">Inglés</label>
              <TagInput
                value={editor.en}
                onChange={(value) => setEditor((prev) => ({ ...prev, en: value }))}
                placeholder="Type a term and press Enter"
              />
            </div>
          </div>
          <div className="ia-actions-row">
            <div className="ia-actions-spacer" />
            <Button variant="secondary" onClick={() => setEditor(null)}>
              Cancelar
            </Button>
            <Button variant="primary" onClick={handleSave}>
              Guardar
            </Button>
          </div>
        </section>
      )}

      <div className="ia-table-wrap">
        <table className="ia-table">
          <thead>
            <tr>
              <th>{isUm ? "Unidad de medida" : "Concepto"}</th>
              {!isUm && <th>Campo destino</th>}
              <th>Español</th>
              <th>Inglés</th>
              <th aria-label="Acciones" />
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr>
                <td colSpan={isUm ? 4 : 5} className="ia-empty-cell">
                  {conceptos.length === 0
                    ? "Aún no hay equivalencias registradas."
                    : "Sin resultados para la búsqueda."}
                </td>
              </tr>
            ) : (
              filtered.map((item) => (
                <tr key={`${item.categoria}|${item.concepto}`}>
                  <td className="ia-strong">
                    {item.concepto}
                    {isUm && item.descripcion ? ` - ${item.descripcion}` : ""}
                  </td>
                  {!isUm && (
                    <td>{item.idCampo ? getIaCampoLabel(item.idCampo) : <span className="ia-helper">—</span>}</td>
                  )}
                  <td>{renderChips(item.terminosEs)}</td>
                  <td>{renderChips(item.terminosEn)}</td>
                  <td className="ia-row-actions">
                    <button type="button" className="ia-link-btn" onClick={() => startEdit(item)} disabled={Boolean(editor)}>
                      Editar
                    </button>
                    <button type="button" className="ia-link-btn danger" onClick={() => setToDelete(item)} disabled={Boolean(editor)}>
                      Eliminar
                    </button>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
