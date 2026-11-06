import Button from "./Button";
import LoadingPanel from "./LoadingPanel";
import "./SelloVucemModal.css";

export default function SelloVucemModal({
  open = false,
  loading = false,
  puedeElegirCliente = false,
  operacionLabel = "",
  correoElectronico = "",
  onCorreoElectronicoChange,
  onSelectCliente,
  onSelectAgente,
  onCancel,
}) {
  if (!open) {
    return null;
  }

  return (
    <div className="pdf-modal-overlay sello-vucem-overlay" role="dialog" aria-modal="true">
      <div className="reject-modal sello-vucem-modal">
        <div className="pdf-modal-header">
          <span className="pdf-modal-title">Selección de sello VUCEM</span>
          <button
            type="button"
            className="pdf-modal-close"
            onClick={onCancel}
            aria-label="Cerrar"
            title="Cerrar"
            disabled={loading}
          >
            ×
          </button>
        </div>
        <LoadingPanel show={loading} message="Cargando sellos..." />
        <div className="reject-modal-body sello-vucem-modal-body">
          {operacionLabel ? (
            <div className="sello-vucem-field">
              <span className="form-label">Operación</span>
              <span className="associate-tag sello-vucem-operacion-tag">{operacionLabel}</span>
            </div>
          ) : null}
          <p className="sello-vucem-hint">
            Elija el tipo de sello con el que se registrará el documento en VUCEM.
          </p>
          <div className="sello-vucem-field">
            <label className="form-label" htmlFor="sello-vucem-correo">
              Correo electrónico (opcional)
            </label>
            <input
              id="sello-vucem-correo"
              type="email"
              className="form-input"
              placeholder="ejemplo@empresa.com"
              value={correoElectronico}
              onChange={(event) => onCorreoElectronicoChange?.(event.target.value)}
              disabled={loading}
              autoComplete="email"
            />
            <span className="sello-vucem-correo-hint">
              Si no se indica, la API VUCEM intentará resolverlo por el usuario del archivo.
            </span>
          </div>
        </div>
        <div className="authorize-modal-actions sello-vucem-modal-actions">
          <Button variant="secondary" disabled={loading} onClick={onCancel}>
            Cancelar
          </Button>
          <Button
            variant="primary"
            disabled={loading || !puedeElegirCliente}
            onClick={onSelectCliente}
            title={
              !puedeElegirCliente
                ? "No hay sello de cliente configurado para este RFC"
                : undefined
            }
          >
            Sello cliente
          </Button>
          <Button variant="primary" disabled={loading} onClick={onSelectAgente}>
            Agente aduanal
          </Button>
        </div>
      </div>
    </div>
  );
}
