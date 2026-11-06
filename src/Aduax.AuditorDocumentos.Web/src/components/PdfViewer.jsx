import "./PdfViewer.css";

export default function PdfViewer({
  url,
  title = "Vista previa",
  className = "",
  onError,
  onLoad,
}) {
  return (
    <div className={`pdf-viewer ${className}`.trim()}>
      <div className="pdf-viewer-header">
        <span className="pdf-viewer-title">{title}</span>
      </div>
      {url ? (
        <iframe
          className="pdf-viewer-frame"
          src={url}
          title={title}
          loading="lazy"
          onError={onError}
          onLoad={onLoad}
        />
      ) : (
        <div className="pdf-viewer-placeholder">Sin documento para mostrar.</div>
      )}
    </div>
  );
}
