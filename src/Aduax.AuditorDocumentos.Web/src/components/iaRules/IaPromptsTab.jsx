import { useEffect, useMemo, useState } from "react";
import { toast } from "react-toastify";
import { motorConfigService } from "../../services";
import { iaCampoOptions, IaPromptTipo } from "../../constants/iaRules";
import Button from "../Button";
import ConfirmationModal from "../ConfirmationModal";
import LoadingPanel from "../LoadingPanel";
import Select from "../Select";
import Toggle from "../Toggle";

const DOCUMENTO_KEY = "documento";
const MAX_DOCUMENTO = 5000;
const MAX_CAMPO = 2000;

const formatDate = (value) => {
  if (!value) {
    return "";
  }
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? "" : date.toLocaleString("es-MX");
};

/** Prompts por tipo VUCEM: plantilla del documento y prompt parcial por campo. */
export default function IaPromptsTab({ selectedDocument }) {
  const idTipo = selectedDocument?.id_DocumentoVucem ?? null;
  const [prompts, setPrompts] = useState(null);
  const [target, setTarget] = useState(DOCUMENTO_KEY);
  const [text, setText] = useState("");
  const [activo, setActivo] = useState(true);
  const [isLoading, setIsLoading] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);

  const campoPrompts = useMemo(
    () => new Map((prompts?.promptsCampo ?? []).map((item) => [item.idCampo, item])),
    [prompts]
  );

  const targetOptions = useMemo(
    () => [
      {
        value: DOCUMENTO_KEY,
        label: `Plantilla del documento${prompts?.promptDocumento ? "" : " (sin prompt)"}`,
      },
      ...iaCampoOptions.map((option) => ({
        value: String(option.value),
        label: `${option.label}${campoPrompts.has(option.value) ? "" : " (sin prompt)"}`,
      })),
    ],
    [campoPrompts, prompts]
  );

  const isDocumento = target === DOCUMENTO_KEY;
  const current = isDocumento
    ? prompts?.promptDocumento
    : campoPrompts.get(Number(target));
  const originalText = isDocumento ? current?.prompt : current?.promptParcial;
  const maxLength = isDocumento ? MAX_DOCUMENTO : MAX_CAMPO;
  const isDirty =
    text !== (originalText ?? "") || activo !== (current ? current.activo : true);
  const canSave = Boolean(idTipo) && isDirty && text.trim().length > 0 && !isLoading;

  useEffect(() => {
    setPrompts(null);
    setTarget(DOCUMENTO_KEY);
    if (!idTipo) {
      return undefined;
    }

    let cancelled = false;
    const load = async () => {
      setIsLoading(true);
      try {
        const response = await motorConfigService.obtenerPromptsIa(idTipo);
        if (!response?.success) {
          throw new Error(response?.message || "No se pudieron cargar los prompts.");
        }
        if (!cancelled) {
          setPrompts(response.data);
        }
      } catch (error) {
        if (!cancelled) {
          toast.error(error?.message || "No se pudieron cargar los prompts.");
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
  }, [idTipo]);

  useEffect(() => {
    setText(originalText ?? "");
    setActivo(current ? current.activo : true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [target, prompts]);

  const handleSave = async () => {
    setShowConfirm(false);
    setIsLoading(true);
    try {
      const response = await motorConfigService.guardarPromptIa(idTipo, {
        tipo: isDocumento ? IaPromptTipo.Documento : IaPromptTipo.Campo,
        idCampo: isDocumento ? null : Number(target),
        texto: text.trim(),
        activo,
      });
      if (!response?.success) {
        throw new Error(response?.message || "No se pudo guardar el prompt.");
      }
      setPrompts(response.data);
      toast.success("Prompt guardado correctamente.");
    } catch (error) {
      toast.error(error?.message || "No se pudo guardar el prompt.");
    } finally {
      setIsLoading(false);
    }
  };

  if (!idTipo) {
    return (
      <p className="ia-empty">
        Seleccione un tipo de documento VUCEM para ver y editar sus prompts.
      </p>
    );
  }

  return (
    <div className="ia-tab-body">
      <LoadingPanel show={isLoading} message="Procesando..." />
      <ConfirmationModal
        open={showConfirm}
        title="Guardar prompt"
        message="Se creará una nueva versión del prompt. ¿Deseas continuar?"
        confirmLabel="Guardar"
        onConfirm={handleSave}
        onCancel={() => setShowConfirm(false)}
      />

      <p className="ia-hint">
        Tipo seleccionado: <strong>{selectedDocument?.documento}</strong>. Los prompts aplican
        solo a este tipo de documento.
      </p>

      <div className="ia-field">
        <label className="ia-label">Prompt a editar</label>
        <Select options={targetOptions} value={target} onChange={setTarget} />
      </div>

      <div className="ia-field">
        <label className="ia-label" htmlFor="ia-prompt-text">
          {isDocumento ? "Plantilla del documento" : "Prompt parcial del campo"}
        </label>
        <textarea
          id="ia-prompt-text"
          className="ia-textarea"
          rows={isDocumento ? 14 : 8}
          maxLength={maxLength}
          value={text}
          onChange={(event) => setText(event.target.value)}
        />
        <div className="ia-meta-row">
          <span className="ia-helper">
            {isDocumento
              ? "Debe conservar los marcadores [CAMPOS] y [JSON]. Use [SINONIMOS] para ubicar el diccionario; si se omite, se agrega al final del prompt."
              : 'No puede contener comillas dobles ("). Se envía como descripción del campo en la estructura JSON.'}
          </span>
          <span className="ia-helper">
            {text.length}/{maxLength}
          </span>
        </div>
      </div>

      <div className="ia-actions-row">
        <Toggle checked={activo} onChange={setActivo} label="Prompt activo" />
        {current ? (
          <span className="ia-helper">
            Versión {current.version}
            {current.actualizadoPor
              ? ` · ${current.actualizadoPor} · ${formatDate(current.fechaActualizacion)}`
              : ""}
          </span>
        ) : (
          <span className="ia-helper">Aún no existe un prompt para este elemento.</span>
        )}
        <div className="ia-actions-spacer" />
        <Button variant="secondary" disabled={!isDirty || isLoading} onClick={() => {
          setText(originalText ?? "");
          setActivo(current ? current.activo : true);
        }}>
          Deshacer cambios
        </Button>
        <Button variant="primary" disabled={!canSave} onClick={() => setShowConfirm(true)}>
          Guardar versión
        </Button>
      </div>
    </div>
  );
}
