import { useEffect, useState } from "react";
import { toast } from "react-toastify";
import {
  AlertModal,
  Button,
  ConfirmationModal,
  LoadingPanel,
  PageHeader,
  TagInput,
  VucemDocumentSelector,
} from "../components";
import { motorConfigService, notificacionesService } from "../services";
import "./NotificationConfigPage.css";

const BellIcon = () => (
  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 7h18s-3 0-3-7" />
    <path d="M13.73 21a2 2 0 0 1-3.46 0" />
  </svg>
);

export default function NotificationConfigPage({ selectedClient }) {
  const [selectedDocument, setSelectedDocument] = useState(null);
  const [hasMotorConfig, setHasMotorConfig] = useState(null);
  const [motorConfigHeader, setMotorConfigHeader] = useState(null);
  const [isLoading, setIsLoading] = useState(false);
  const [loadingMessage, setLoadingMessage] = useState("");
  const [showAlertModal, setShowAlertModal] = useState(false);
  const [alertTitle, setAlertTitle] = useState("Atención");
  const [alertMessage, setAlertMessage] = useState("");
  const [emails, setEmails] = useState("");
  const [notificationDays, setNotificationDays] = useState("");
  const [rememberEmails, setRememberEmails] = useState(false);
  const [showConfirmSave, setShowConfirmSave] = useState(false);

  const CheckCircleIcon = () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
      <polyline points="22 4 12 14.01 9 11.01" />
    </svg>
  );

  const CircleIcon = () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <circle cx="12" cy="12" r="8" />
    </svg>
  );

  const showAlert = (message, title = "Atención") => {
    setAlertTitle(title);
    setAlertMessage(message);
    setShowAlertModal(true);
  };

  const getErrorMessage = (error, fallback) => {
    const rawMessage =
      typeof error?.message === "string" ? error.message.trim() : "";
    if (!rawMessage) {
      return fallback;
    }
    const jsonStart = rawMessage.indexOf("{");
    if (jsonStart >= 0) {
      const jsonText = rawMessage.slice(jsonStart);
      try {
        const parsed = JSON.parse(jsonText);
        if (parsed?.message) {
          return parsed.message;
        }
      } catch (parseError) {
        // ignore parse error and fallback to rawMessage
      }
    }
    try {
      const parsed = JSON.parse(rawMessage);
      if (parsed?.message) {
        return parsed.message;
      }
    } catch (parseError) {
      // ignore parse error and fallback to rawMessage
    }
    return rawMessage;
  };

  const loadMotorConfig = async ({ clientId, documentoVucemId }) => {
    const response = await motorConfigService.obtenerMotorConfig({
      idCliente: clientId,
      idTipoDocumentoVucem: documentoVucemId,
    });

    if (!response?.success || !response?.data) {
      throw new Error(
        response?.message || "No se pudo cargar la configuración del motor."
      );
    }

    setMotorConfigHeader(response.data);
    return response.data;
  };

  const applyNotifConfig = (config) => {
    if (!config) {
      setEmails("");
      setRememberEmails(false);
      setNotificationDays("");
      return;
    }
    const rawEmails = config?.correos || "";
    const normalizedEmails = String(rawEmails).replace(/[;,]/g, " ");
    setEmails(normalizedEmails.trim());
    setRememberEmails(Boolean(config?.recordarCorreos));
    const rawDays = String(config?.diasAntesVencimiento || "");
    const firstDay = rawDays
      .split(",")
      .map((item) => item.trim())
      .filter(Boolean)[0] || "";
    setNotificationDays(firstDay);
  };

  const loadNotifConfig = async ({ clientId, documentoVucemId, motorConfigId }) => {
    setIsLoading(true);
    setLoadingMessage("Cargando configuración");
    try {
      const response = await notificacionesService.obtenerNotifConfig({
        idCliente: clientId,
        idTipoDocumentoVucem: documentoVucemId,
        data: motorConfigId ?? null,
      });
      if (!response?.success) {
        throw new Error(
          response?.message || "No se pudo cargar la configuración de notificaciones."
        );
      }
      const config = response?.data || null;
      applyNotifConfig(config);
      return config;
    } catch (error) {
      applyNotifConfig(null);
        showAlert(
          getErrorMessage(
            error,
            "No se pudo cargar la configuración de notificaciones."
          ),
          "Error al cargar"
        );
      return null;
    } finally {
      setIsLoading(false);
      setLoadingMessage("");
    }
  };

  const loadRememberedEmails = async ({ clientId, documentoVucemId }) => {
    try {
      const response = await notificacionesService.recuperaCorreosRecordados({
        idCliente: clientId,
        idTipoDocumentoVucem: documentoVucemId,
        data: "",
      });
      if (!response?.success) {
        throw new Error(
          response?.message || "No se pudieron recuperar los correos recordados."
        );
      }
      const list = Array.isArray(response?.data) ? response.data : [];
      if (list.length) {
        setEmails(list.join(" "));
      }
    } catch (error) {
      toast.error(
        getErrorMessage(
          error,
          "No se pudieron recuperar los correos recordados."
        )
      );
    }
  };

  const validateMotorConfig = async ({ clientId, documentoVucemId }) => {
    if (!clientId || !documentoVucemId) {
      setHasMotorConfig(null);
      setMotorConfigHeader(null);
      return;
    }
    try {
      setIsLoading(true);
      setLoadingMessage("Validando configuración");
      const response = await motorConfigService.validaExistenciaMotorConfig({
        idCliente: clientId,
        idTipoDocumentoVucem: documentoVucemId,
      });
      const hasConfig = Boolean(response?.success && response?.data);
      setHasMotorConfig(hasConfig);
      if (hasConfig) {
        const header = await loadMotorConfig({ clientId, documentoVucemId });
        const notifConfig = await loadNotifConfig({
          clientId,
          documentoVucemId,
          motorConfigId: header?.id ?? null,
        });
        const hasSavedEmails = Boolean(
          String(notifConfig?.correos || "").trim()
        );
        if (!hasSavedEmails) {
          await loadRememberedEmails({ clientId, documentoVucemId });
        }
      } else {
        setMotorConfigHeader(null);
        applyNotifConfig(null);
        showAlert(
          "No existe configuración del motor para el cliente y documento seleccionados. Configura primero los documentos.",
          "Configuración no encontrada"
        );
      }
    } catch (error) {
      setHasMotorConfig(false);
      setMotorConfigHeader(null);
      applyNotifConfig(null);
      showAlert(
        getErrorMessage(
          error,
          "No se pudo validar la configuración del motor."
        ),
        "Error de validación"
      );
    } finally {
      setIsLoading(false);
      setLoadingMessage("");
    }
  };

  useEffect(() => {
    if (!selectedClient || !selectedDocument?.id_DocumentoVucem) {
      setHasMotorConfig(null);
      setMotorConfigHeader(null);
      applyNotifConfig(null);
      return;
    }
    validateMotorConfig({
      clientId: selectedClient,
      documentoVucemId: selectedDocument.id_DocumentoVucem,
    }).catch(() => {});
  }, [selectedClient, selectedDocument?.id_DocumentoVucem]);

  const handleToggleOption = (value) => {
    setNotificationDays((prev) => (prev === value ? "" : value));
  };

  const handleReset = () => {
    setEmails("");
    setNotificationDays("");
    setRememberEmails(false);
  };

  const buildDiasAntesVencimiento = () => {
    return notificationDays ? notificationDays : "";
  };

  const handleSave = () => {
    if (!selectedClient || !selectedDocument?.id_DocumentoVucem || !hasMotorConfig) {
      showAlert(
        "Selecciona un cliente y un documento con configuración.",
        "Atención"
      );
      return;
    }
    const emailList = emails
      .trim()
      .split(/\s+/)
      .map((item) => item.trim())
      .filter(Boolean);
    if (!emailList.length) {
      showAlert("Captura al menos un correo electrónico.", "Atención");
      return;
    }
    if (!buildDiasAntesVencimiento()) {
      showAlert("Selecciona al menos una opción de notificación.", "Atención");
      return;
    }
    setShowConfirmSave(true);
  };

  const handleConfirmSave = async () => {
    setShowConfirmSave(false);
    if (!selectedClient || !selectedDocument?.id_DocumentoVucem || !motorConfigHeader) {
      showAlert(
        "Selecciona un cliente y un documento con configuración.",
        "Atención"
      );
      return;
    }
    const emailList = emails
      .trim()
      .split(/\s+/)
      .map((item) => item.trim())
      .filter(Boolean);
    if (!emailList.length) {
      showAlert("Captura al menos un correo electrónico.", "Atención");
      return;
    }
    if (!buildDiasAntesVencimiento()) {
      showAlert("Selecciona al menos una opción de notificación.", "Atención");
      return;
    }
    try {
      setIsLoading(true);
      setLoadingMessage("Guardando configuración");
      const payload = {
        idCliente: selectedClient,
        idTipoDocumentoVucem: selectedDocument.id_DocumentoVucem,
        data: {
          id: 0,
          idMotorConfigHeader: motorConfigHeader?.id ?? 0,
          correos: emails
            .trim()
            .split(/[\s,]+/)
            .filter(Boolean)
            .join(","),
          diasAntesVencimiento: buildDiasAntesVencimiento(),
          recordarCorreos: rememberEmails,
          fechaCreacion: new Date().toISOString(),
          creadoPor: "-",
          fechaActualizacion: new Date().toISOString(),
          actualizadoPor: "-",
        },
      };
      const response = await notificacionesService.guardarNotifConfig(payload);
      if (!response?.success) {
        throw new Error(
          response?.message || "No se pudo guardar la configuración de notificaciones."
        );
      }
      toast.success("Configuración de notificaciones guardada correctamente.");
    } catch (error) {
      showAlert(
        getErrorMessage(
          error,
          "No se pudo guardar la configuración de notificaciones."
        ),
        "Error al guardar"
      );
    } finally {
      setIsLoading(false);
      setLoadingMessage("");
    }
  };

  return (
    <div className="notification-config-page">
      <PageHeader
        icon={<BellIcon />}
        title="Configuración de notificaciones"
        subtitle="Reglas y destinatarios para alertas"
      />

      <div className="notification-config-content">
        <div className="notification-config-layout">
          <VucemDocumentSelector
            className="notification-config-sidebar"
            value={selectedDocument}
            onChange={setSelectedDocument}
          />

          <section className="notification-config-main">
            <LoadingPanel show={isLoading} message={loadingMessage} />
            <div className="section-header">
              <BellIcon />
              <span className="section-title">Configuración</span>
            </div>
            {!selectedClient && (
              <p className="section-helper">
                Selecciona un cliente para iniciar la configuración.
              </p>
            )}
            {selectedClient && !selectedDocument?.id_DocumentoVucem && (
              <p className="section-helper">
                Selecciona un documento VUCEM para continuar.
              </p>
            )}
            {selectedClient && selectedDocument?.id_DocumentoVucem && hasMotorConfig && (
              <div className="notification-form">
                <div className="form-field">
                  <label className="form-label">Correos</label>
                  <TagInput
                    value={emails}
                    onChange={setEmails}
                    placeholder="Escribe un correo y presiona espacio"
                    separators={[" "]}
                    joinWith=" "
                  />
                  <span className="form-helper">
                    Agrega múltiples correos usando espacio.
                  </span>
                </div>
                <div className="notification-remember">
                  <label className="notification-switch">
                    <input
                      type="checkbox"
                      checked={rememberEmails}
                      onChange={() => setRememberEmails((prev) => !prev)}
                    />
                    <span className="switch-slider" />
                    <span className="switch-label">Recordar correos electrónicos</span>
                  </label>
                </div>
                <div className="notification-options">
                  <label className="form-label">Notificaciones</label>
                  <div className="notification-toggle-list">
                    <button
                      type="button"
                      className={`notification-toggle ${
                        notificationDays === "7" ? "active" : ""
                      }`}
                      onClick={() => handleToggleOption("7")}
                      aria-pressed={notificationDays === "7"}
                    >
                      <span className="notification-toggle-icon">
                        {notificationDays === "7" ? <CheckCircleIcon /> : <CircleIcon />}
                      </span>
                      Notificación con 7 días de antelación
                    </button>
                    <button
                      type="button"
                      className={`notification-toggle ${
                        notificationDays === "15" ? "active" : ""
                      }`}
                      onClick={() => handleToggleOption("15")}
                      aria-pressed={notificationDays === "15"}
                    >
                      <span className="notification-toggle-icon">
                        {notificationDays === "15" ? <CheckCircleIcon /> : <CircleIcon />}
                      </span>
                      Notificación con 15 días de antelación
                    </button>
                    <button
                      type="button"
                      className={`notification-toggle ${
                        notificationDays === "30" ? "active" : ""
                      }`}
                      onClick={() => handleToggleOption("30")}
                      aria-pressed={notificationDays === "30"}
                    >
                      <span className="notification-toggle-icon">
                        {notificationDays === "30" ? <CheckCircleIcon /> : <CircleIcon />}
                      </span>
                      Notificación con 30 días de antelación
                    </button>
                    <button
                      type="button"
                      className={`notification-toggle ${
                        notificationDays === "45" ? "active" : ""
                      }`}
                      onClick={() => handleToggleOption("45")}
                      aria-pressed={notificationDays === "45"}
                    >
                      <span className="notification-toggle-icon">
                        {notificationDays === "45" ? <CheckCircleIcon /> : <CircleIcon />}
                      </span>
                      Notificación con 45 días de antelación
                    </button>
                  </div>
                </div>
                <div className="notification-actions">
                  <Button variant="secondary" onClick={handleReset}>
                    Resetear
                  </Button>
                  <Button variant="primary" onClick={handleSave}>
                    Guardar
                  </Button>
                </div>
              </div>
            )}
            {selectedClient && selectedDocument?.id_DocumentoVucem && hasMotorConfig === false && (
              <p className="section-helper">
                El documento seleccionado no cuenta con configuración.
              </p>
            )}
          </section>
        </div>
      </div>
      <AlertModal
        open={showAlertModal}
        title={alertTitle}
        message={alertMessage}
        confirmLabel="Entendido"
        variant="alert"
        onClose={() => setShowAlertModal(false)}
      />
      <ConfirmationModal
        open={showConfirmSave}
        title="Confirmar guardado"
        message="¿Deseas guardar esta configuración de notificaciones?"
        confirmLabel="Guardar"
        cancelLabel="Cancelar"
        onConfirm={handleConfirmSave}
        onCancel={() => setShowConfirmSave(false)}
      />
    </div>
  );
}
