import "./LoadingPanel.css";

export default function LoadingPanel({ show = false, message = "Cargando..." }) {
  if (!show) {
    return null;
  }

  return (
    <div className="loading-panel" role="status" aria-live="polite">
      <div className="loading-panel-content">
        <span className="loading-spinner" aria-hidden="true"></span>
        <span className="loading-text">{message}</span>
      </div>
    </div>
  );
}
