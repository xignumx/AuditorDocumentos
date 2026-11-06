import Button from "./Button";
import "./AlertModal.css";

export default function AlertModal({
  open = false,
  title = "Atención",
  message = "",
  confirmLabel = "Aceptar",
  variant = "alert",
  multiline = false,
  wide = false,
  onClose,
}) {
  if (!open) {
    return null;
  }

  const renderBadgeIcon = () => {
    if (variant === "error") {
      return (
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <circle cx="12" cy="12" r="10" />
          <line x1="15" y1="9" x2="9" y2="15" />
          <line x1="9" y1="9" x2="15" y2="15" />
        </svg>
      );
    }
    if (variant === "success") {
      return (
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M20 6L9 17l-5-5" />
        </svg>
      );
    }
    return (
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
        <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
        <line x1="12" y1="9" x2="12" y2="13" />
        <line x1="12" y1="17" x2="12.01" y2="17" />
      </svg>
    );
  };

  return (
    <div className="alert-modal-overlay" role="alertdialog" aria-modal="true">
      <div className={`alert-modal${wide ? " alert-modal--wide" : ""}`}>
        <div className="alert-modal-header">
          <div className="alert-modal-hero" aria-hidden="true">
            <span className="alert-modal-hero-card">
              <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7">
                <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                <polyline points="14 2 14 8 20 8" />
                <line x1="8" y1="13" x2="16" y2="13" />
                <line x1="8" y1="17" x2="16" y2="17" />
              </svg>
            </span>
            <span className={`alert-modal-hero-badge ${variant}`}>
              {renderBadgeIcon()}
            </span>
          </div>
          <span className="alert-modal-title">{title}</span>
        </div>
        <div className="alert-modal-body">
          <p
            className={`alert-modal-message${multiline ? " alert-modal-message--multiline" : ""}`}
          >
            {message}
          </p>
        </div>
        <div className="alert-modal-actions">
          <Button variant="primary" onClick={onClose}>
            {confirmLabel}
          </Button>
        </div>
      </div>
    </div>
  );
}
