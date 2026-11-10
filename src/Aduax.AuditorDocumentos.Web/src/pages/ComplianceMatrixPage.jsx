import { useRef, useState } from "react";
import { toast } from "react-toastify";
import { Button, ConfirmationModal, LoadingPanel, PageHeader } from "../components";
import ClientMultiSelector from "../components/complianceMatrix/ClientMultiSelector";
import MatrixResult from "../components/complianceMatrix/MatrixResult";
import { motorConfigService } from "../services";
import "./ComplianceMatrixPage.css";

// Mismos límites que el API (MotorConfigMasivaService)
const MAX_CLIENTES = 200;
const MAX_BYTES = 5 * 1024 * 1024;

const ShieldIcon = () => (
  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
    <polyline points="9 12 11 14 15 10" />
  </svg>
);

const readFileAsBase64 = (file) =>
  new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const result = reader.result;
      resolve(typeof result === "string" ? result.split(",")[1] || "" : "");
    };
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });

const downloadBase64File = (base64, fileName) => {
  const bytes = Uint8Array.from(atob(base64), (char) => char.charCodeAt(0));
  const blob = new Blob([bytes], {
    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = fileName;
  link.click();
  URL.revokeObjectURL(url);
};

/**
 * Carga masiva de la matriz de validación documental (solo Compliance):
 * 1) clientes destino, 2) archivo Excel, 3) vista previa y aplicación.
 */
export default function ComplianceMatrixPage() {
  const [selectedClients, setSelectedClients] = useState({});
  const [file, setFile] = useState(null);
  const [fileBase64, setFileBase64] = useState("");
  const [motivo, setMotivo] = useState("");
  const [result, setResult] = useState(null);
  const [loadingMessage, setLoadingMessage] = useState("");
  const [showConfirm, setShowConfirm] = useState(false);
  const fileInputRef = useRef(null);

  const clientIds = Object.keys(selectedClients);
  const isLoading = Boolean(loadingMessage);
  const canPreview = clientIds.length > 0 && Boolean(fileBase64) && !isLoading;
  const canApply =
    Boolean(result?.soloPrevisualizar) &&
    result.erroresArchivo.length === 0 &&
    result.totalNuevos + result.totalModifica > 0 &&
    !isLoading;

  const handleClientsChange = (next) => {
    setSelectedClients(next);
    setResult(null);
  };

  const handleFileChange = async (event) => {
    const selected = event.target.files?.[0];
    setResult(null);
    if (!selected) {
      setFile(null);
      setFileBase64("");
      return;
    }
    if (!selected.name.toLowerCase().endsWith(".xlsx")) {
      toast.error("El archivo debe ser un libro de Excel (.xlsx).");
      event.target.value = "";
      setFile(null);
      setFileBase64("");
      return;
    }
    if (selected.size > MAX_BYTES) {
      toast.error(`El archivo excede el tamaño máximo de ${MAX_BYTES / (1024 * 1024)} MB.`);
      event.target.value = "";
      setFile(null);
      setFileBase64("");
      return;
    }
    try {
      setFileBase64(await readFileAsBase64(selected));
      setFile(selected);
    } catch (error) {
      toast.error("No se pudo leer el archivo.");
      setFile(null);
      setFileBase64("");
    }
  };

  const handleDownloadTemplate = async () => {
    setLoadingMessage("Generando plantilla...");
    try {
      const response = await motorConfigService.descargarPlantillaMatriz();
      if (!response?.success || !response?.data?.contenidoBase64) {
        throw new Error(response?.message || "No se pudo generar la plantilla.");
      }
      downloadBase64File(response.data.contenidoBase64, response.data.nombreArchivo);
    } catch (error) {
      toast.error(error?.message || "No se pudo generar la plantilla.");
    } finally {
      setLoadingMessage("");
    }
  };

  const runLoad = async (soloPrevisualizar) => {
    setLoadingMessage(soloPrevisualizar ? "Calculando vista previa..." : "Aplicando cambios...");
    try {
      const response = await motorConfigService.cargaMasivaMatriz({
        nombreArchivo: file.name,
        archivoBase64: fileBase64,
        idsClientes: clientIds,
        soloPrevisualizar,
        motivoCambio: motivo.trim() || undefined,
      });
      if (!response?.success) {
        throw new Error(response?.message || "No se pudo procesar el archivo.");
      }
      setResult(response.data);
      if (!soloPrevisualizar) {
        const { totalAplicados, totalErrores } = response.data;
        if (totalErrores > 0) {
          toast.warn(`${totalAplicados} configuración(es) guardada(s) y ${totalErrores} con error.`);
        } else {
          toast.success(`${totalAplicados} configuración(es) guardada(s) correctamente.`);
        }
      }
    } catch (error) {
      toast.error(error?.message || "No se pudo procesar el archivo.");
    } finally {
      setLoadingMessage("");
    }
  };

  const handleConfirmApply = async () => {
    setShowConfirm(false);
    await runLoad(false);
  };

  return (
    <div className="compliance-matrix-page">
      <PageHeader
        icon={<ShieldIcon />}
        title="Matriz de validación documental"
        subtitle="Carga masiva de visibilidad, obligatoriedad, clasificación y acción en operación"
      />

      <div className="cm-content">
        <LoadingPanel show={isLoading} message={loadingMessage} />
        <ConfirmationModal
          open={showConfirm}
          title="Aplicar carga masiva"
          message={`Se crearán ${result?.totalNuevos ?? 0} y se modificarán ${result?.totalModifica ?? 0} configuración(es) en ${result?.totalClientes ?? 0} cliente(s). Los cambios quedan registrados en la bitácora. ¿Deseas continuar?`}
          confirmLabel="Aplicar"
          onConfirm={handleConfirmApply}
          onCancel={() => setShowConfirm(false)}
        />

        <section className="cm-section">
          <h2 className="cm-section-title">1. Clientes destino</h2>
          <p className="cm-helper">
            Marque uno o varios clientes. Las filas del archivo se aplican a cada uno de ellos.
          </p>
          <ClientMultiSelector
            selected={selectedClients}
            onChange={handleClientsChange}
            maxSelected={MAX_CLIENTES}
            disabled={isLoading}
          />
        </section>

        <section className="cm-section">
          <h2 className="cm-section-title">2. Archivo de la matriz</h2>
          <p className="cm-helper">
            Descargue la plantilla, capture solo los tipos de documento que desea configurar y súbala.
            Las celdas vacías no modifican la configuración actual.
          </p>
          <div className="cm-file-row">
            <Button variant="secondary" disabled={isLoading} onClick={handleDownloadTemplate}>
              Descargar plantilla
            </Button>
            <input
              ref={fileInputRef}
              type="file"
              accept=".xlsx"
              className="cm-file-input"
              disabled={isLoading}
              onChange={handleFileChange}
              aria-label="Archivo de la matriz (.xlsx)"
            />
            {file && <span className="cm-helper">{file.name}</span>}
          </div>
          <div className="cm-field">
            <label className="cm-label" htmlFor="cm-motivo">
              Motivo del cambio (opcional)
            </label>
            <input
              id="cm-motivo"
              className="cm-input"
              type="text"
              maxLength={500}
              value={motivo}
              disabled={isLoading}
              onChange={(event) => setMotivo(event.target.value)}
              placeholder="Se guarda en la bitácora de cada configuración modificada"
            />
          </div>
        </section>

        <section className="cm-section">
          <h2 className="cm-section-title">3. Vista previa y aplicación</h2>
          <div className="cm-actions">
            <Button variant="secondary" disabled={!canPreview} onClick={() => runLoad(true)}>
              Previsualizar
            </Button>
            <Button variant="primary" disabled={!canApply} onClick={() => setShowConfirm(true)}>
              Aplicar cambios
            </Button>
          </div>
          {result ? (
            <MatrixResult result={result} />
          ) : (
            <p className="cm-helper">
              Seleccione clientes y archivo, y presione Previsualizar para ver qué cambiaría antes de aplicar.
            </p>
          )}
        </section>
      </div>
    </div>
  );
}
