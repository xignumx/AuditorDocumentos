import Button from "./Button";
import LoadingPanel from "./LoadingPanel";
import "./ConfirmationModal.css";

export default function ConfirmationModal({
  open = false,
  title = "Confirmar acción",
  message = "¿Deseas continuar?",
  confirmLabel = "Confirmar",
  cancelLabel = "Cancelar",
  loading = false,
  loadingMessage = "Procesando...",
  onConfirm,
  onCancel,
  children,
}) {
  if (!open) {
    return null;
  }

  return (
    <div className="confirmation-modal-overlay" role="dialog" aria-modal="true">
      <div className="confirmation-modal">
        <LoadingPanel show={loading} message={loadingMessage} />
        <div className="confirmation-modal-header">
          <div className="confirmation-modal-hero" aria-hidden="true">
            <span className="confirmation-modal-hero-card">
              <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7">
                <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                <polyline points="14 2 14 8 20 8" />
                <line x1="8" y1="13" x2="16" y2="13" />
                <line x1="8" y1="17" x2="16" y2="17" />
              </svg>
            </span>
            <span className="confirmation-modal-hero-badge">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
                <polyline points="22 4 12 14.01 9 11.01" />
              </svg>
            </span>
          </div>
          <span className="confirmation-modal-title">{title}</span>
        </div>
        <div className="confirmation-modal-body">
          <p className="confirmation-modal-message">{message}</p>
          {children ? (
            <div className="confirmation-modal-extra">{children}</div>
          ) : null}
        </div>
        <div className="confirmation-modal-actions">
          <Button variant="secondary" disabled={loading} onClick={onCancel}>
            {cancelLabel}
          </Button>
          <Button variant="primary" disabled={loading} onClick={onConfirm}>
            {confirmLabel}
          </Button>
        </div>
      </div>
    </div>
  );
}
