import Button from "./Button";
import "./VucemMensajeModal.css";

export default function VucemMensajeModal({
  open = false,
  mensaje = "",
  onClose,
}) {
  if (!open) {
    return null;
  }

  return (
    <div className="pdf-modal-overlay vucem-mensaje-overlay" role="dialog" aria-modal="true">
      <div className="reject-modal vucem-mensaje-modal">
        <div className="pdf-modal-header">
          <span className="pdf-modal-title">Mensaje de envío VUCEM</span>
          <button
            type="button"
            className="pdf-modal-close"
            onClick={onClose}
            aria-label="Cerrar"
            title="Cerrar"
          >
            ×
          </button>
        </div>
        <div className="reject-modal-body vucem-mensaje-modal-body">
          <label className="form-label" htmlFor="vucem-mensaje-text">
            Mensaje
          </label>
          <textarea
            id="vucem-mensaje-text"
            className="reject-textarea"
            rows={6}
            value={mensaje}
            readOnly
          />
        </div>
        <div className="authorize-modal-actions vucem-mensaje-modal-actions">
          <Button variant="primary" onClick={onClose}>
            Cerrar
          </Button>
        </div>
      </div>
    </div>
  );
}
