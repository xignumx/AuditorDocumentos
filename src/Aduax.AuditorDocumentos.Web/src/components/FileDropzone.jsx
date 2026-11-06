import { useEffect, useRef, useState } from "react";
import "./FileDropzone.css";

const UploadIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
    <polyline points="17 8 12 3 7 8" />
    <line x1="12" y1="3" x2="12" y2="15" />
  </svg>
);

export default function FileDropzone({
  label = "Arrastra y suelta un archivo aquí",
  helper = "o haz clic para seleccionar",
  disabled = false,
  accept,
  onFileSelect,
  file = null,
  showPreview = false,
}) {
  const inputRef = useRef(null);
  const [isDragging, setIsDragging] = useState(false);
  const [previewUrl, setPreviewUrl] = useState("");
  const isPdf = file?.type === "application/pdf";

  useEffect(() => {
    if (!file) {
      setPreviewUrl("");
      return;
    }
    const url = URL.createObjectURL(file);
    setPreviewUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);

  const handleFile = (file) => {
    if (!file) {
      return;
    }
    if (accept) {
      const acceptTypes = accept.split(",").map((entry) => entry.trim().toLowerCase());
      const fileType = file.type?.toLowerCase() || "";
      const fileName = file.name?.toLowerCase() || "";
      const isAccepted = acceptTypes.some((entry) => {
        if (entry.startsWith(".")) {
          return fileName.endsWith(entry);
        }
        return entry === fileType;
      });
      if (!isAccepted) {
        return;
      }
    }
    onFileSelect?.(file);
  };

  const handleDrop = (event) => {
    event.preventDefault();
    if (disabled) {
      return;
    }
    setIsDragging(false);
    const file = event.dataTransfer?.files?.[0];
    handleFile(file);
  };

  const handleDragOver = (event) => {
    event.preventDefault();
    if (!disabled) {
      setIsDragging(true);
    }
  };

  const handleDragLeave = () => {
    setIsDragging(false);
  };

  const handleSelectClick = () => {
    if (disabled) {
      return;
    }
    inputRef.current?.click();
  };

  const handleInputChange = (event) => {
    const file = event.target.files?.[0];
    handleFile(file);
  };

  const dropzoneContent = (
    <div
      className={`file-dropzone ${disabled ? "disabled" : ""} ${
        isDragging ? "dragging" : ""
      }`}
      onClick={handleSelectClick}
      onDrop={handleDrop}
      onDragOver={handleDragOver}
      onDragLeave={handleDragLeave}
      role="button"
      tabIndex={disabled ? -1 : 0}
      onKeyDown={(event) => {
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          handleSelectClick();
        }
      }}
    >
      <div className="file-dropzone-icon">
        <UploadIcon />
      </div>
      <div className="file-dropzone-text">
        <span className="file-dropzone-label">{label}</span>
        <span className="file-dropzone-helper">{helper}</span>
      </div>
      <input
        ref={inputRef}
        type="file"
        className="file-dropzone-input"
        disabled={disabled}
        accept={accept}
        onChange={handleInputChange}
      />
    </div>
  );

  if (!showPreview) {
    return dropzoneContent;
  }

  return (
    <div className="file-dropzone-wrapper">
      <div className="file-dropzone-panel">{dropzoneContent}</div>
      <div className="file-preview-panel">
        {file && isPdf && previewUrl ? (
          <iframe
            title="Vista previa del archivo"
            src={previewUrl}
            className="file-preview-frame"
          />
        ) : (
          <div className="file-preview-empty">
            {file ? "Sin vista previa disponible." : "Selecciona un PDF para previsualizar."}
          </div>
        )}
      </div>
    </div>
  );
}
