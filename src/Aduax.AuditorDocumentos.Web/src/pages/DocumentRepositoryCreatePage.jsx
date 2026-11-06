import { useEffect, useMemo, useState } from "react";
import { toast } from "react-toastify";
import {
  AlertModal,
  Button,
  FileDropzone,
  ConfirmationModal,
  LoadingPanel,
  PaginatedSelect,
  PaginatedMultiSelect,
  TagInput,
  PageHeader,
  VucemDocumentSelector,
} from "../components";
import { documentosService, motorConfigService } from "../services";
import { AdCampos } from "../constants/adCampos";
import { AdDocumentoClasificacion } from "../constants/adDocumentoClasificacion";
import "./DocumentRepositoryCreatePage.css";

const DocumentIcon = () => (
  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
    <polyline points="14 2 14 8 20 8" />
    <line x1="16" y1="13" x2="8" y2="13" />
    <line x1="16" y1="17" x2="8" y2="17" />
    <polyline points="10 9 9 9 8 9" />
  </svg>
);

const CheckIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
    <polyline points="22 4 12 14.01 9 11.01" />
  </svg>
);

function DocumentRepositoryCreatePage({ selectedClient }) {
  const [selectedDocument, setSelectedDocument] = useState(null);
  const [showMissingConfig, setShowMissingConfig] = useState(false);
  const [missingConfigMessage, setMissingConfigMessage] = useState("");
  const [hasMotorConfig, setHasMotorConfig] = useState(null);
  const [motorConfigHeader, setMotorConfigHeader] = useState(null);
  const [selectedFile, setSelectedFile] = useState(null);
  const [preguardadoId, setPreguardadoId] = useState(null);
  const [iaContext, setIaContext] = useState(null);
  const [formValues, setFormValues] = useState({});
  const [additionalValues, setAdditionalValues] = useState({
    identificadorGeneral: {
      identificador: "",
      complemento: "",
      complemento2: "",
      complemento3: "",
    },
    identificadorPartida: {
      regimen: "",
      tipoAdvalorem: "",
      origen: "",
      identificador: "",
      complemento1: "",
      complemento2: "",
      complemento3: "",
    },
    permiso: {
      regimen: "",
      permiso: "",
      numero: "",
      firma: "",
    },
  });
  const [isLoading, setIsLoading] = useState(false);
  const [loadingMessage, setLoadingMessage] = useState("");
  const [showConfirmSave, setShowConfirmSave] = useState(false);
  const [alertTitle, setAlertTitle] = useState("Atención");
  const [alertVariant, setAlertVariant] = useState("alert");

  const isSaveEnabled = Boolean(
    selectedClient &&
      selectedDocument?.id_DocumentoVucem &&
      hasMotorConfig === true
  );
  const detailMap = useMemo(() => {
    const detalles = motorConfigHeader?.detalles || [];
    return new Map(detalles.map((detail) => [detail.idCampo, detail]));
  }, [motorConfigHeader]);
  const configClasificacion = motorConfigHeader?.idClasificacion;
  const showIdentificadorGeneral =
    !hasMotorConfig || !configClasificacion
      ? true
      : configClasificacion === AdDocumentoClasificacion.IdentificadorGeneral;
  const showIdentificadorPartida =
    !hasMotorConfig || !configClasificacion
      ? true
      : configClasificacion === AdDocumentoClasificacion.IdentificadorPartida;
  const showPermisos =
    !hasMotorConfig || !configClasificacion
      ? true
      : configClasificacion === AdDocumentoClasificacion.Permisos;
  const showCaptureControls = Boolean(motorConfigHeader);

  const isFieldVisible = (campoId) => {
    if (!hasMotorConfig) {
      return true;
    }
    const detail = detailMap.get(campoId);
    if (!detail) {
      return true;
    }
    return Boolean(detail.visible);
  };

  const isFieldRequired = (campoId) => {
    if (!hasMotorConfig) {
      return false;
    }
    const detail = detailMap.get(campoId);
    return Boolean(detail?.obligatorio);
  };

  const renderLabel = (text, campoId) => (
    <label className="form-label">
      {text}
      {isFieldRequired(campoId) && (
        <span className="form-label-required">*</span>
      )}
    </label>
  );

  const renderRequiredLabel = (text, required) => (
    <label className="form-label">
      {text}
      {required && <span className="form-label-required">*</span>}
    </label>
  );

  const renderMultiValueHint = () => (
    <span className="form-helper">Agrega multiples valores usando ";"</span>
  );

  const normalizeOperacionValue = (value) => {
    const raw = String(value || "").trim();
    if (!raw) {
      return null;
    }
    const normalized = raw.toLowerCase();
    if (
      normalized.startsWith("imp") ||
      normalized.startsWith("impo") ||
      normalized.startsWith("import")
    ) {
      return "1";
    }
    if (
      normalized.startsWith("exp") ||
      normalized.startsWith("expo") ||
      normalized.startsWith("export")
    ) {
      return "2";
    }
    return raw;
  };

  const updateFormValue = (campoId, value) => {
    setFormValues((prev) => ({
      ...prev,
      [campoId]: value ?? "",
    }));
  };

  const splitTagValues = (value) =>
    String(value ?? "")
      .split(";")
      .map((item) => item.trim())
      .filter(Boolean);

  const joinTagValues = (tags) => tags.join(";");

  const validateCatalogTag = async (campoId, value) => {
    if (!value) {
      return true;
    }
    if (!selectedClient || !selectedDocument?.id_DocumentoVucem) {
      return true;
    }
    const payload = {
      idCliente: selectedClient,
      idTipoDocumentoVucem: selectedDocument?.id_DocumentoVucem ?? 0,
      data: value,
    };
    let response;
    let fieldLabel = "";
    try {
      if (campoId === AdCampos.Fracciones) {
        fieldLabel = "fracción";
        response = await motorConfigService.validaFraccion(payload);
      } else if (campoId === AdCampos.UnidadMedidaUMT) {
        fieldLabel = "unidad de medida";
        response = await motorConfigService.validaUnidadMedida(payload);
      } else if (campoId === AdCampos.PaisOrigenDestino) {
        fieldLabel = "país de origen/destino";
        response = await motorConfigService.validaPais(payload);
      } else {
        return true;
      }
      if (!response?.success || response?.data === false) {
        throw new Error(response?.message || `No se pudo validar ${fieldLabel}.`);
      }
      return true;
    } catch (error) {
      toast.error(
        getErrorMessage(error, `No se pudo validar ${fieldLabel}.`)
      );
      return false;
    }
  };

  const isValidFraccionLength = (tag) => {
    const trimmed = String(tag ?? "").trim();
    if (!/^\d+$/.test(trimmed)) {
      return false;
    }
    return trimmed.length === 6 || trimmed.length === 8;
  };

  const handleValidatedTagChange = async (campoId, nextValue) => {
    const nextTags = splitTagValues(nextValue);
    const prevTags = splitTagValues(formValues[campoId] ?? "");
    const normalizedNextTags =
      campoId === AdCampos.PaisOrigenDestino
        ? nextTags.map((tag) => tag.trim().toUpperCase())
        : nextTags;
    const normalizedPrevTags =
      campoId === AdCampos.PaisOrigenDestino
        ? prevTags.map((tag) => tag.trim().toUpperCase())
        : prevTags;
    const prevSet = new Set(normalizedPrevTags);
    const addedTags = normalizedNextTags.filter((tag) => !prevSet.has(tag));
    if (!addedTags.length) {
      updateFormValue(campoId, joinTagValues(normalizedNextTags));
      return;
    }
    const invalidTags = new Set();
    for (const tag of addedTags) {
      if (campoId === AdCampos.Fracciones) {
        if (!isValidFraccionLength(tag)) {
          toast.error(
            "La fracción debe tener 6 u 8 dígitos numéricos."
          );
          invalidTags.add(tag);
          continue;
        }
      }
      if (campoId === AdCampos.PaisOrigenDestino) {
        if (tag.length < 2 || tag.length > 3) {
          toast.error(
            "El país de origen/destino debe tener 2 o 3 caracteres."
          );
          invalidTags.add(tag);
          continue;
        }
      }
      const isValid = await validateCatalogTag(campoId, tag);
      if (!isValid) {
        invalidTags.add(tag);
      }
    }
    if (invalidTags.size) {
      const filtered = normalizedNextTags.filter((tag) => !invalidTags.has(tag));
      updateFormValue(campoId, joinTagValues(filtered));
      return;
    }
    updateFormValue(campoId, joinTagValues(normalizedNextTags));
  };

  const normalizeTwoDigitTags = (value) => {
    if (!value) {
      return "";
    }
    return String(value)
      .split(";")
      .map((item) => item.trim())
      .filter((item) => item.length > 0 && item.length <= 2)
      .join(";");
  };

  const getTodayDateInputMax = () => new Date().toISOString().slice(0, 10);

  const sanitizePositiveDecimal = (value) => {
    if (value === "" || value === null || value === undefined) {
      return "";
    }
    let cleaned = String(value).replace(/[^\d.]/g, "");
    const parts = cleaned.split(".");
    if (parts.length > 2) {
      cleaned = `${parts[0]}.${parts.slice(1).join("")}`;
    }
    if (cleaned.startsWith(".")) {
      cleaned = `0${cleaned}`;
    }
    return cleaned;
  };

  const isPositiveDecimalValue = (value) => {
    const raw = String(value ?? "").trim();
    if (!raw) {
      return true;
    }
    const num = Number(raw);
    return Number.isFinite(num) && num > 0;
  };

  const normalizeGuiaBlTags = (value) => {
    if (!value) {
      return "";
    }
    return String(value)
      .split(";")
      .map((item) => item.trim().replace(/[^a-zA-Z0-9]/g, ""))
      .filter(Boolean)
      .join(";");
  };

  const updateAdditionalValue = (section, field, value) => {
    setAdditionalValues((prev) => ({
      ...prev,
      [section]: {
        ...prev[section],
        [field]: value ?? "",
      },
    }));
  };

  const resetFormState = () => {
    setFormValues({});
    setAdditionalValues({
      identificadorGeneral: {
        identificador: "",
        complemento: "",
        complemento2: "",
        complemento3: "",
      },
      identificadorPartida: {
        regimen: "",
        tipoAdvalorem: "",
        origen: "",
        identificador: "",
        complemento1: "",
        complemento2: "",
        complemento3: "",
      },
      permiso: {
        regimen: "",
        permiso: "",
        numero: "",
        firma: "",
      },
    });
    setSelectedFile(null);
    setPreguardadoId(null);
    setIaContext(null);
  };

  const showAlert = ({ title, message, variant = "alert" }) => {
    setAlertTitle(title || "Atención");
    setMissingConfigMessage(message || "");
    setAlertVariant(variant);
    setShowMissingConfig(true);
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

  const normalizeFieldValue = (campoId, value) => {
    if (!value) {
      return "";
    }
    if (Array.isArray(value)) {
      return value
        .map((item) => String(item ?? "").trim())
        .filter(Boolean)
        .join(";");
    }
    if (
      campoId === AdCampos.VigenciaDesde ||
      campoId === AdCampos.VigenciaHasta ||
      campoId === AdCampos.FechaFactura
    ) {
      const date = new Date(value);
      if (!Number.isNaN(date.getTime())) {
        return date.toISOString().slice(0, 10);
      }
    }
    if (
      campoId === AdCampos.Cantidad ||
      campoId === AdCampos.ValorComercial ||
      campoId === AdCampos.ValorUsd
    ) {
      if (campoId === AdCampos.Cantidad) {
        const cleaned = String(value ?? "").replace(/[^\d.-]/g, "").trim();
        return cleaned || "";
      }
      return sanitizePositiveDecimal(value);
    }
    if (campoId === AdCampos.GuiaBl) {
      return normalizeGuiaBlTags(value);
    }
    if (campoId === AdCampos.Pedimento) {
      return String(value ?? "").replace(/\D/g, "").slice(0, 15);
    }
    if (campoId === AdCampos.TipoOperacion) {
      return normalizeOperacionValue(value) ?? "";
    }
    return String(value);
  };

  const applyExtractedValues = (data) => {
    if (!data) {
      return;
    }
    const updates = {};

    if (Array.isArray(data)) {
      data.forEach((item) => {
        if (!item) {
          return;
        }
        const campoId = Number(item.idCampo ?? item.campoId);
        if (!Number.isNaN(campoId)) {
          updates[campoId] = normalizeFieldValue(
            campoId,
            item.valor ?? item.value ?? ""
          );
        }
      });
    } else if (Array.isArray(data?.campos)) {
      data.campos.forEach((item) => {
        if (!item) {
          return;
        }
        const campoId = Number(item.idCampo ?? item.campoId);
        if (!Number.isNaN(campoId)) {
          updates[campoId] = normalizeFieldValue(
            campoId,
            item.valor ?? item.value ?? ""
          );
        }
      });
    } else if (typeof data === "object") {
      Object.entries(data).forEach(([key, value]) => {
        const campoId = Number(key);
        if (!Number.isNaN(campoId)) {
          updates[campoId] = normalizeFieldValue(campoId, value);
        }
      });
    }

    if (Object.keys(updates).length) {
      setFormValues((prev) => ({
        ...prev,
        ...updates,
      }));
    }
  };

  const readFileAsBase64 = (file) =>
    new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        const result = reader.result;
        if (typeof result === "string") {
          const base64 = result.split(",")[1] || "";
          resolve(base64);
        } else {
          resolve("");
        }
      };
      reader.onerror = () => reject(reader.error);
      reader.readAsDataURL(file);
    });

  const isPdfReadable = async (file) => {
    if (!file) {
      return false;
    }
    const headerSlice = file.slice(0, 5);
    const tailSlice = file.slice(Math.max(0, file.size - 1024), file.size);
    const [headerBuffer, tailBuffer] = await Promise.all([
      headerSlice.arrayBuffer(),
      tailSlice.arrayBuffer(),
    ]);
    const decoder = new TextDecoder("ascii");
    const headerText = decoder.decode(headerBuffer);
    const tailText = decoder.decode(tailBuffer);
    const hasPdfHeader = headerText.startsWith("%PDF-");
    const hasEofMarker = tailText.includes("%%EOF");
    return hasPdfHeader && hasEofMarker;
  };

  const handleFileSelect = async (file) => {
    setSelectedFile(file);
    setPreguardadoId(null);
    setIaContext(null);
    if (!file || !isSaveEnabled || !motorConfigHeader) {
      return;
    }
    try {
      setIsLoading(true);
      setLoadingMessage("Preparando documento");
      const isReadable = await isPdfReadable(file);
      if (!isReadable) {
        showAlert({
          title: "Archivo inválido",
          message:
            "El archivo PDF no es legible o está corrupto. Verifica el documento e intenta de nuevo.",
          variant: "alert",
        });
        return;
      }
      const base64 = await readFileAsBase64(file);
      const fileName = file.name || "";
      const preguardadoPayload = {
        idCliente: selectedClient,
        idTipoDocumentoVucem: selectedDocument.id_DocumentoVucem,
        data: {
          id: 0,
          idCliente: selectedClient,
          idTipoDocumentoVucem: selectedDocument.id_DocumentoVucem,
          idMotorConfigHeader: motorConfigHeader?.id ?? 0,
          idEstatus: 0,
          creadoPor: "-",
          campos: [],
        },
      };

      const preguardadoResponse =
        await documentosService.preguardaDocumento(preguardadoPayload);
      if (!preguardadoResponse?.success) {
        throw new Error(
          preguardadoResponse?.message ||
            "No se pudo preguardar el documento."
        );
      }

      const documentoId = Number(preguardadoResponse?.data ?? 0);
      if (!documentoId) {
        throw new Error("No se obtuvo el id del documento preguardado.");
      }
      setPreguardadoId(documentoId);
      setIaContext({
        documentoId,
        fileName,
        base64,
      });
    } catch (error) {
      showAlert({
        title: "Error al procesar",
        message: getErrorMessage(
          error,
          "Ocurrió un error al procesar el documento."
        ),
        variant: "error",
      });
    } finally {
      setIsLoading(false);
      setLoadingMessage("");
    }
  };

  const handleExtractIa = async () => {
    if (!iaContext || !selectedClient || !selectedDocument?.id_DocumentoVucem) {
      showAlert({
        title: "Archivo requerido",
        message: "Carga un archivo para ejecutar la extracción de datos.",
        variant: "alert",
      });
      return;
    }
    try {
      setIsLoading(true);
      setLoadingMessage("Extrayendo datos con IA");
      const extraResponse = await documentosService.extraDatosDocumentoIa({
        idCliente: selectedClient,
        idTipoDocumentoVucem: selectedDocument.id_DocumentoVucem,
        data: {
          idDocumento: iaContext.documentoId,
          nombreArchivo: iaContext.fileName,
          docBase64: iaContext.base64,
        },
      });

      if (!extraResponse?.success) {
        throw new Error(
          extraResponse?.message || "No se pudieron extraer los datos."
        );
      }

      applyExtractedValues(extraResponse?.data);
    } catch (error) {
      showAlert({
        title: "Error al procesar",
        message: getErrorMessage(
          error,
          "Ocurrió un error al procesar el documento."
        ),
        variant: "error",
      });
    } finally {
      setIsLoading(false);
      setLoadingMessage("");
    }
  };

  const getRequiredMissingFields = () => {
    const detalles = motorConfigHeader?.detalles || [];
    return detalles
      .filter((detail) => detail?.obligatorio && detail?.visible)
      .filter((detail) => {
        const value = formValues[detail.idCampo];
        return !String(value ?? "").trim();
      })
      .map((detail) => detail?.nombreCampo || `Campo ${detail.idCampo}`);
  };

  const getAdditionalMissingFields = () => {
    const missing = [];
    if (showIdentificadorGeneral) {
      if (!additionalValues.identificadorGeneral.identificador) {
        missing.push("Identificador");
      }
    }
    if (showIdentificadorPartida) {
      if (!additionalValues.identificadorPartida.identificador) {
        missing.push("Identificador (partida)");
      }
    }
    if (showPermisos) {
      if (!additionalValues.permiso.regimen) {
        missing.push("Régimen (permiso)");
      }
      if (!additionalValues.permiso.permiso) {
        missing.push("Permiso");
      }
    }
    return missing;
  };

  const isVigenciaFinInvalid = () => {
    const vigenciaFin = formValues[AdCampos.VigenciaHasta];
    if (!vigenciaFin) {
      return false;
    }
    const endDate = new Date(vigenciaFin);
    if (Number.isNaN(endDate.getTime())) {
      return true;
    }
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    endDate.setHours(0, 0, 0, 0);
    return endDate <= today;
  };

  const isInvalidDateValue = (value) => {
    if (!value) {
      return false;
    }
    const raw = String(value).trim();
    if (!/^\d{4}-\d{2}-\d{2}$/.test(raw)) {
      return true;
    }
    const parsed = new Date(raw);
    return Number.isNaN(parsed.getTime());
  };

  const hasInvalidVigenciaDates = () =>
    isInvalidDateValue(formValues[AdCampos.VigenciaDesde]) ||
    isInvalidDateValue(formValues[AdCampos.VigenciaHasta]);

  const isVigenciaRangeInvalid = () => {
    const isVisibleFrom = isFieldVisible(AdCampos.VigenciaDesde);
    const isVisibleTo = isFieldVisible(AdCampos.VigenciaHasta);
    if (!(isVisibleFrom && isVisibleTo)) {
      return false;
    }
    const rawFrom = formValues[AdCampos.VigenciaDesde];
    const rawTo = formValues[AdCampos.VigenciaHasta];
    if (!rawFrom || !rawTo) {
      return false;
    }
    const startDate = new Date(rawFrom);
    const endDate = new Date(rawTo);
    if (Number.isNaN(startDate.getTime()) || Number.isNaN(endDate.getTime())) {
      return false;
    }
    return startDate > endDate;
  };

  const isFutureDateValue = (value) => {
    const raw = String(value ?? "").trim();
    if (!raw || isInvalidDateValue(raw)) {
      return false;
    }
    const date = new Date(raw);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    date.setHours(0, 0, 0, 0);
    return date > today;
  };

  const getFechaFacturaValidationError = () => {
    if (!isFieldVisible(AdCampos.FechaFactura)) {
      return null;
    }
    const raw = formValues[AdCampos.FechaFactura];
    if (!String(raw ?? "").trim()) {
      return null;
    }
    if (isInvalidDateValue(raw)) {
      return "La fecha de factura debe tener el formato YYYY-MM-DD.";
    }
    if (isFutureDateValue(raw)) {
      return "La fecha de factura no puede ser posterior a la fecha actual.";
    }
    return null;
  };

  const getPositiveAmountValidationError = (campoId, label) => {
    if (!isFieldVisible(campoId)) {
      return null;
    }
    const raw = String(formValues[campoId] ?? "").trim();
    if (!raw) {
      return null;
    }
    if (!isPositiveDecimalValue(raw)) {
      return `${label} debe ser un número mayor que cero.`;
    }
    return null;
  };

  const getPedimentoValidationError = () => {
    if (!isFieldVisible(AdCampos.Pedimento)) {
      return null;
    }
    const digits = String(formValues[AdCampos.Pedimento] ?? "").replace(/\D/g, "");
    if (!digits) {
      return null;
    }
    if (digits.length !== 15) {
      return "El pedimento debe tener exactamente 15 dígitos (2 año + 2 aduana + 4 patente + 7 número).";
    }
    return null;
  };

  const getCustomFieldValidationError = () =>
    getFechaFacturaValidationError() ||
    getPositiveAmountValidationError(
      AdCampos.ValorComercial,
      "El valor comercial"
    ) ||
    getPositiveAmountValidationError(AdCampos.ValorUsd, "El valor USD") ||
    getPedimentoValidationError();

  const buildArchivoPayload = async () => {
    if (!selectedFile) {
      return null;
    }
    const base64 = await readFileAsBase64(selectedFile);
    const fileName = selectedFile.name || "";
    const extension =
      fileName.includes(".") ? fileName.split(".").pop() ?? "" : "";
    return {
      id: 0,
      idDocumento: 0,
      nombreArchivo: fileName,
      extension,
      tamanoBytes: selectedFile.size ?? 0,
      awsRuta: "-",
      docBase64: base64,
    };
  };

  const handleConfirmSave = async () => {
    setShowConfirmSave(false);

    if (!selectedFile || !motorConfigHeader) {
      showAlert({
        title: "Archivo requerido",
        message: "Debes cargar un archivo antes de guardar el documento.",
        variant: "alert",
      });
      return;
    }

    if (isVigenciaFinInvalid()) {
      showAlert({
        title: "Vigencia inválida",
        message:
          "La fecha de vigencia hasta debe ser mayor a la fecha actual.",
        variant: "alert",
      });
      return;
    }

    if (hasInvalidVigenciaDates()) {
      showAlert({
        title: "Formato de fecha inválido",
        message:
          "Las fechas de vigencia deben tener el formato YYYY-MM-DD.",
        variant: "alert",
      });
      return;
    }

    if (isVigenciaRangeInvalid()) {
      showAlert({
        title: "Rango de fechas inválido",
        message:
          "La fecha de vigencia desde no puede ser mayor a la fecha de vigencia hasta.",
        variant: "alert",
      });
      return;
    }

    const customFieldError = getCustomFieldValidationError();
    if (customFieldError) {
      showAlert({
        title: "Validación de campos",
        message: customFieldError,
        variant: "alert",
      });
      return;
    }

    const missingFields = getRequiredMissingFields();
    const additionalMissingFields = getAdditionalMissingFields();
    const allMissingFields = [...missingFields, ...additionalMissingFields];
    if (allMissingFields.length) {
      showAlert({
        title: "Campos obligatorios",
        message: `Completa los campos obligatorios: ${allMissingFields.join(", ")}`,
        variant: "alert",
      });
      return;
    }

    try {
      setIsLoading(true);
      setLoadingMessage("Guardando documento");

      if (!preguardadoId) {
        throw new Error("No se encontró el id del documento preguardado.");
      }

      const nowIso = new Date().toISOString();
      const archivoPayload = await buildArchivoPayload();
      if (!archivoPayload) {
        throw new Error("No se pudo preparar el archivo para el guardado.");
      }

      const detalles = motorConfigHeader?.detalles || [];
      const campos = detalles.map((detail) => {
        let valor = String(formValues[detail.idCampo] ?? "");
        if (
          detail.idCampo === AdCampos.Cantidad ||
          detail.idCampo === AdCampos.ValorComercial ||
          detail.idCampo === AdCampos.ValorUsd
        ) {
          valor =
            detail.idCampo === AdCampos.Cantidad
              ? valor.replace(/[^\d.-]/g, "").trim() || ""
              : sanitizePositiveDecimal(valor);
        }
        if (detail.idCampo === AdCampos.GuiaBl) {
          valor = normalizeGuiaBlTags(valor);
        }
        if (detail.idCampo === AdCampos.Pedimento) {
          valor = valor.replace(/\D/g, "");
        }
        if (detail.idCampo === AdCampos.TipoOperacion) {
          valor = normalizeOperacionValue(valor) ?? "";
        }
        return {
          id: 0,
          idDocumento: 0,
          idCampo: detail.idCampo,
          valor,
        };
      });

      const shouldSendGeneral = !configClasificacion
        ? true
        : configClasificacion === AdDocumentoClasificacion.IdentificadorGeneral;
      const shouldSendPartida = !configClasificacion
        ? true
        : configClasificacion === AdDocumentoClasificacion.IdentificadorPartida;
      const shouldSendPermiso = !configClasificacion
        ? true
        : configClasificacion === AdDocumentoClasificacion.Permisos;

      const payload = {
        idCliente: selectedClient,
        idTipoDocumentoVucem: selectedDocument?.id_DocumentoVucem ?? 0,
        data: {
          id: preguardadoId,
          idCliente: selectedClient,
          idTipoDocumentoVucem: selectedDocument?.id_DocumentoVucem ?? 0,
          idMotorConfigHeader: motorConfigHeader?.id ?? 0,
          idEstatus: 0,
          fechaVigenciaInicio: formValues[AdCampos.VigenciaDesde] || null,
          fechaVigenciaFin: formValues[AdCampos.VigenciaHasta] || null,
          observaciones: "",
          comentarioRechazo: "",
          fechaCreacion: nowIso,
          creadoPor: "-",
          fechaActualizacion: nowIso,
          actualizadoPor: "-",
          campos,
          archivo: archivoPayload,
          identificadorGeneral: shouldSendGeneral
            ? {
                idDocumento: 0,
                ...additionalValues.identificadorGeneral,
              }
            : null,
          identificadorPartida: shouldSendPartida
            ? {
                idDocumento: 0,
                regimen: "",
                tipoAdvalorem: "",
                origen: "",
                identificador: additionalValues.identificadorPartida.identificador ?? "",
                complemento1: additionalValues.identificadorPartida.complemento1 ?? "",
                complemento2: additionalValues.identificadorPartida.complemento2 ?? "",
                complemento3: additionalValues.identificadorPartida.complemento3 ?? "",
              }
            : null,
          permiso: shouldSendPermiso
            ? {
                idDocumento: 0,
                ...additionalValues.permiso,
              }
            : null,
        },
      };

      const response =
        await documentosService.guardaDocumentoPendienteAprobacion(payload);
      if (!response?.success) {
        throw new Error(
          response?.message || "No se pudo guardar el documento."
        );
      }

      toast.success(response?.message || "Documento guardado correctamente.");
      resetFormState();
      setSelectedDocument(null);
    } catch (error) {
      showAlert({
        title: "Error al guardar",
        message: getErrorMessage(
          error,
          "Ocurrió un error al guardar el documento."
        ),
        variant: "error",
      });
    } finally {
      setIsLoading(false);
      setLoadingMessage("");
    }
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
  };

  const validateMotorConfig = async ({
    clientId,
    documentoVucemId,
    showAlert: showAlertFlag = false,
    checkVigente = true,
  }) => {
    if (!clientId || !documentoVucemId) {
      setHasMotorConfig(null);
      setMotorConfigHeader(null);
      return null;
    }
    try {
      const response = await motorConfigService.validaExistenciaMotorConfig({
        idCliente: clientId,
        idTipoDocumentoVucem: documentoVucemId,
      });
      const hasConfig = Boolean(response?.success && response?.data);
      setHasMotorConfig(hasConfig);

      if (hasConfig) {
        await loadMotorConfig({ clientId, documentoVucemId });

        if (checkVigente) {
          const vigenteResponse =
            await documentosService.validarDocumentoVigenteAprobado({
              idCliente: clientId,
              idTipoDocumentoVucem: documentoVucemId,
            });
          if (vigenteResponse?.success && vigenteResponse?.data === true) {
            showAlert({
              title: "Documento vigente",
              message:
                vigenteResponse?.message || "Ya existe un documento vigente.",
              variant: "alert",
            });
          }
        }
      } else {
        setMotorConfigHeader(null);
      }

      if (!hasConfig && showAlertFlag) {
        showAlert({
          title: "Configuración no encontrada",
          message:
            "No existe configuración del motor para el cliente y documento seleccionados. Configura primero los documentos.",
          variant: "alert",
        });
      }
      return hasConfig;
    } catch (error) {
      setHasMotorConfig(false);
      setMotorConfigHeader(null);
      if (showAlertFlag) {
        showAlert({
          title: "Error de validación",
          message: getErrorMessage(
            error,
            "No se pudo validar la configuración del motor."
          ),
          variant: "error",
        });
      }
      return false;
    }
  };

  useEffect(() => {
    if (!selectedClient || !selectedDocument?.id_DocumentoVucem) {
      setHasMotorConfig(null);
      setMotorConfigHeader(null);
      setSelectedFile(null);
      return;
    }

    validateMotorConfig({
      clientId: selectedClient,
      documentoVucemId: selectedDocument.id_DocumentoVucem,
      showAlert: true,
    }).catch(() => {});
  }, [selectedClient, selectedDocument?.id_DocumentoVucem]);

  useEffect(() => {
    resetFormState();
  }, [selectedClient, selectedDocument?.id_DocumentoVucem]);


  const handleSave = async () => {
    if (!isSaveEnabled) {
      return;
    }

    if (!selectedFile) {
      showAlert({
        title: "Archivo requerido",
        message: "Debes cargar un archivo antes de guardar el documento.",
        variant: "alert",
      });
      return;
    }

    if (isVigenciaFinInvalid()) {
      showAlert({
        title: "Vigencia inválida",
        message:
          "La fecha de vigencia hasta debe ser mayor a la fecha actual.",
        variant: "alert",
      });
      return;
    }

    if (hasInvalidVigenciaDates()) {
      showAlert({
        title: "Formato de fecha inválido",
        message:
          "Las fechas de vigencia deben tener el formato YYYY-MM-DD.",
        variant: "alert",
      });
      return;
    }

    if (isVigenciaRangeInvalid()) {
      showAlert({
        title: "Rango de fechas inválido",
        message:
          "La fecha de vigencia desde no puede ser mayor a la fecha de vigencia hasta.",
        variant: "alert",
      });
      return;
    }

    const customFieldError = getCustomFieldValidationError();
    if (customFieldError) {
      showAlert({
        title: "Validación de campos",
        message: customFieldError,
        variant: "alert",
      });
      return;
    }

    const missingFields = getRequiredMissingFields();
    if (missingFields.length) {
      showAlert({
        title: "Campos obligatorios",
        message: `Completa los campos obligatorios: ${missingFields.join(", ")}`,
        variant: "alert",
      });
      return;
    }

    const exists = await validateMotorConfig({
      clientId: selectedClient,
      documentoVucemId: selectedDocument?.id_DocumentoVucem,
      showAlert: true,
      checkVigente: false,
    });
    if (!exists) {
      return;
    }

    setShowConfirmSave(true);
  };

  return (
    <div className="document-repository-page">
      <PageHeader
        icon={<DocumentIcon />}
        title="Alta de documento"
        subtitle="Registro de un nuevo documento"
      />

      <div className="document-repository-content">
        <div className="document-repository-layout">
          <VucemDocumentSelector
            className="document-repository-sidebar"
            value={selectedDocument}
            onChange={setSelectedDocument}
          />

          <section className="document-repository-main">
            <LoadingPanel show={isLoading} message={loadingMessage} />
            <div className="section-header">
              <DocumentIcon />
              <span className="section-title">Datos del documento</span>
            </div>
            <p className="section-helper">
              Panel de captura en construcción.
            </p>
            <div className="document-repository-capture-scroll custom-scrollbar">
              {showCaptureControls && (
                <FileDropzone
                  label="Carga de archivo"
                  helper={
                    selectedFile
                      ? selectedFile.name
                      : "Arrastra el archivo aquí o haz clic"
                  }
                  onFileSelect={handleFileSelect}
                  file={selectedFile}
                  showPreview
                  disabled={!isSaveEnabled}
                  accept="application/pdf,.pdf"
                />
              )}
              {showCaptureControls && iaContext && (
                <div className="document-repository-extract">
                  <Button
                    variant="secondary"
                    onClick={handleExtractIa}
                    disabled={!isSaveEnabled || isLoading}
                  >
                    Extraer datos
                  </Button>
                </div>
              )}
              {showCaptureControls && (
                <div className="document-repository-form">
              {isFieldVisible(AdCampos.Proveedor) && (
                <div className="form-field">
                  {renderLabel("Proveedor", AdCampos.Proveedor)}
                  <PaginatedSelect
                    value={formValues[AdCampos.Proveedor] ?? ""}
                    onChange={(value) =>
                      updateFormValue(AdCampos.Proveedor, value)
                    }
                    placeholder="Seleccione un proveedor..."
                    filterable
                    disabled={
                      !selectedClient || !selectedDocument?.id_DocumentoVucem
                    }
                    loadPage={({ filter, page, size, token }) =>
                      motorConfigService.obtenerProveedores(
                        {
                          idCliente: selectedClient,
                          idTipoDocumentoVucem:
                            selectedDocument?.id_DocumentoVucem ?? 0,
                          data: { filter, page, size },
                        },
                        token
                      )
                    }
                    getOptionValue={(item) => item?.idProveedor ?? ""}
                    getOptionLabel={(item) => {
                      const val = item?.idProveedor ?? "";
                      const lbl = item?.proveedor ?? "";
                      return [val, lbl].filter(Boolean).join(" ").trim() || "";
                    }}
                  />
                </div>
              )}
              {isFieldVisible(AdCampos.TipoPedimento) && (
                <div className="form-field">
                  {renderLabel("Tipo pedimento", AdCampos.TipoPedimento)}
                  <input
                    className="form-input"
                    type="text"
                    name="tipoPedimento"
                    data-campo-id={AdCampos.TipoPedimento}
                    inputMode="numeric"
                    maxLength={2}
                    placeholder="00"
                    value={formValues[AdCampos.TipoPedimento] ?? ""}
                    onChange={(event) => {
                      const nextValue = event.target.value
                        .replace(/\D/g, "")
                        .slice(0, 2);
                      updateFormValue(AdCampos.TipoPedimento, nextValue);
                    }}
                    onBlur={(event) => {
                      if (!isFieldVisible(AdCampos.TipoPedimento)) {
                        return;
                      }
                      const value = String(event.target.value || "").trim();
                      if (!value) {
                        return;
                      }
                      const allowed = new Set(["10", "20", "21", "30"]);
                      if (!allowed.has(value)) {
                        showAlert({
                          title: "Valor no válido",
                          message: "El tipo de pedimento capturado no es válido.",
                          variant: "alert",
                        });
                        updateFormValue(AdCampos.TipoPedimento, "");
                      }
                    }}
                  />
                </div>
              )}
              {isFieldVisible(AdCampos.TipoOperacion) && (
                <div className="form-field">
                  {renderLabel("Tipo de operación", AdCampos.TipoOperacion)}
                  <select
                    className="form-input"
                    name="tipoOperacion"
                    data-campo-id={AdCampos.TipoOperacion}
                    defaultValue=""
                    value={formValues[AdCampos.TipoOperacion] ?? ""}
                    onChange={(event) => {
                      const nextTipo = event.target.value;
                      updateFormValue(AdCampos.TipoOperacion, nextTipo);
                      updateFormValue(AdCampos.ClavePedimento, "");
                    }}
                  >
                    <option value="" disabled>
                      Seleccione una opción...
                    </option>
                    <option value="importacion">Importación</option>
                    <option value="exportacion">Exportación</option>
                  </select>
                </div>
              )}
              {isFieldVisible(AdCampos.ClavePedimento) && (
                <div className="form-field">
                  {renderLabel("Clave de pedimento", AdCampos.ClavePedimento)}
                  <PaginatedMultiSelect
                    key={formValues[AdCampos.TipoOperacion] ?? "tipo"}
                    value={formValues[AdCampos.ClavePedimento] ?? ""}
                    onChange={(value) =>
                      updateFormValue(AdCampos.ClavePedimento, value)
                    }
                    placeholder="Seleccione régimen(es)..."
                    filterable
                    disabled={!selectedClient}
                    loadPage={({ filter, page, size, token }) =>
                      motorConfigService.obtenerRegimenes(
                        {
                          data: {
                            filter,
                            tipoOperacion: isFieldVisible(AdCampos.TipoOperacion)
                              ? normalizeOperacionValue(
                                  formValues[AdCampos.TipoOperacion]
                                )
                              : null,
                          },
                          page,
                          size,
                        },
                        token
                      )
                    }
                    getOptionValue={(item) => item?.idRegimen ?? ""}
                    getOptionLabel={(item) => item?.idRegimen ?? ""}
                  />
                  {renderMultiValueHint()}
                </div>
              )}
              {isFieldVisible(AdCampos.ProductoNoDeParte) && (
                <div className="form-field">
                  {renderLabel("Producto/No de parte", AdCampos.ProductoNoDeParte)}
                  <TagInput
                    value={formValues[AdCampos.ProductoNoDeParte] ?? ""}
                    onChange={(value) => updateFormValue(AdCampos.ProductoNoDeParte, value)}
                    placeholder="Producto/No de parte"
                  />
                  {renderMultiValueHint()}
                </div>
              )}
              {isFieldVisible(AdCampos.DescripcionMercancia) && (
                <div className="form-field">
                  {renderLabel("Descripción de mercancía", AdCampos.DescripcionMercancia)}
                  <TagInput
                    value={formValues[AdCampos.DescripcionMercancia] ?? ""}
                    onChange={(value) =>
                      updateFormValue(AdCampos.DescripcionMercancia, value)
                    }
                    placeholder="Descripción de mercancía"
                  />
                  {renderMultiValueHint()}
                </div>
              )}
              {isFieldVisible(AdCampos.Fracciones) && (
                <div className="form-field">
                  {renderLabel("Fracciones", AdCampos.Fracciones)}
                  <TagInput
                    value={formValues[AdCampos.Fracciones] ?? ""}
                    onChange={(value) => {
                      void handleValidatedTagChange(AdCampos.Fracciones, value);
                    }}
                    placeholder="00000000"
                  />
                  {renderMultiValueHint()}
                </div>
              )}
              {isFieldVisible(AdCampos.Nico) && (
                <div className="form-field">
                  {renderLabel("Nico", AdCampos.Nico)}
                  <TagInput
                    value={formValues[AdCampos.Nico] ?? ""}
                    onChange={(value) =>
                      updateFormValue(AdCampos.Nico, normalizeTwoDigitTags(value))
                    }
                    placeholder="00"
                  />
                  {renderMultiValueHint()}
                </div>
              )}
              {isFieldVisible(AdCampos.Cantidad) && (
                <div className="form-field">
                  {renderLabel("Cantidad", AdCampos.Cantidad)}
                  <input
                    className="form-input"
                    type="number"
                    name="cantidad"
                    data-campo-id={AdCampos.Cantidad}
                    inputMode="decimal"
                    step="any"
                    min="0"
                    placeholder="0"
                    value={formValues[AdCampos.Cantidad] ?? ""}
                    onChange={(event) =>
                      updateFormValue(AdCampos.Cantidad, event.target.value)
                    }
                  />
                </div>
              )}
              {isFieldVisible(AdCampos.UnidadMedidaUMT) && (
                <div className="form-field">
                  {renderLabel("Unidad de medida (UMT)", AdCampos.UnidadMedidaUMT)}
                  <TagInput
                    value={formValues[AdCampos.UnidadMedidaUMT] ?? ""}
                    onChange={(value) => {
                      void handleValidatedTagChange(
                        AdCampos.UnidadMedidaUMT,
                        value
                      );
                    }}
                    placeholder="Unidad de medida"
                  />
                  {renderMultiValueHint()}
                </div>
              )}
              {isFieldVisible(AdCampos.PaisOrigenDestino) && (
                <div className="form-field">
                  {renderLabel("País de origen/destino", AdCampos.PaisOrigenDestino)}
                  <TagInput
                    value={formValues[AdCampos.PaisOrigenDestino] ?? ""}
                    onChange={(value) => {
                      void handleValidatedTagChange(
                        AdCampos.PaisOrigenDestino,
                        value
                      );
                    }}
                    placeholder="MEX"
                  />
                  {renderMultiValueHint()}
                </div>
              )}
              {isFieldVisible(AdCampos.VigenciaDesde) && (
                <div className="form-field">
                  {renderLabel("Vigencia desde", AdCampos.VigenciaDesde)}
                  <input
                    className="form-input"
                    type="date"
                    name="vigenciaDesde"
                    data-campo-id={AdCampos.VigenciaDesde}
                    value={formValues[AdCampos.VigenciaDesde] ?? ""}
                    onChange={(event) =>
                      updateFormValue(AdCampos.VigenciaDesde, event.target.value)
                    }
                  />
                </div>
              )}
              {isFieldVisible(AdCampos.VigenciaHasta) && (
                <div className="form-field">
                  {renderLabel("Vigencia hasta", AdCampos.VigenciaHasta)}
                  <input
                    className="form-input"
                    type="date"
                    name="vigenciaHasta"
                    data-campo-id={AdCampos.VigenciaHasta}
                    value={formValues[AdCampos.VigenciaHasta] ?? ""}
                    onChange={(event) =>
                      updateFormValue(AdCampos.VigenciaHasta, event.target.value)
                    }
                  />
                </div>
              )}
              {isFieldVisible(AdCampos.Aduana) && (
                <div className="form-field">
                  {renderLabel("Aduana", AdCampos.Aduana)}
                  <PaginatedSelect
                    value={formValues[AdCampos.Aduana] ?? ""}
                    onChange={(value) =>
                      updateFormValue(AdCampos.Aduana, value)
                    }
                    placeholder="Seleccione una aduana..."
                    filterable
                    disabled={!selectedClient}
                    loadPage={({ filter, page, size, token }) =>
                      motorConfigService.obtenerAduanas(
                        { filter, page, size },
                        token
                      )
                    }
                    getOptionValue={(item) => item?.aduana ?? ""}
                    getOptionLabel={(item) =>
                      item?.aduana
                        ? `${item.aduana} ${
                            item?.descripcion ?? item?.aduana ?? ""
                          }`.trim()
                        : item?.descripcion ?? item?.aduana ?? ""
                    }
                  />
                </div>
              )}
              {isFieldVisible(AdCampos.FirmaDeRL) && (
                <div className="form-field">
                  {renderLabel("Firma de Representante Legal", AdCampos.FirmaDeRL)}
                  <input
                    className="form-input"
                    type="text"
                    name="firmaDeRL"
                    data-campo-id={AdCampos.FirmaDeRL}
                    value={formValues[AdCampos.FirmaDeRL] ?? ""}
                    onChange={(event) =>
                      updateFormValue(AdCampos.FirmaDeRL, event.target.value)
                    }
                  />
                </div>
              )}
              {isFieldVisible(AdCampos.Nom) && (
                <div className="form-field">
                  {renderLabel("Nom", AdCampos.Nom)}
                  <input
                    className="form-input"
                    type="text"
                    name="nom"
                    data-campo-id={AdCampos.Nom}
                    value={formValues[AdCampos.Nom] ?? ""}
                    onChange={(event) =>
                      updateFormValue(AdCampos.Nom, event.target.value)
                    }
                  />
                </div>
              )}
              {isFieldVisible(AdCampos.ValorComercial) && (
                <div className="form-field">
                  {renderLabel("Valor Comercial", AdCampos.ValorComercial)}
                  <input
                    className="form-input"
                    type="number"
                    name="valorComercial"
                    data-campo-id={AdCampos.ValorComercial}
                    inputMode="decimal"
                    step="any"
                    min="0.000001"
                    placeholder="0"
                    value={formValues[AdCampos.ValorComercial] ?? ""}
                    onChange={(event) =>
                      updateFormValue(
                        AdCampos.ValorComercial,
                        sanitizePositiveDecimal(event.target.value)
                      )
                    }
                  />
                </div>
              )}
              {isFieldVisible(AdCampos.Factura) && (
                <div className="form-field">
                  {renderLabel("Factura", AdCampos.Factura)}
                  <input
                    className="form-input"
                    type="text"
                    name="factura"
                    data-campo-id={AdCampos.Factura}
                    value={formValues[AdCampos.Factura] ?? ""}
                    onChange={(event) =>
                      updateFormValue(AdCampos.Factura, event.target.value)
                    }
                  />
                </div>
              )}
              {isFieldVisible(AdCampos.FechaFactura) && (
                <div className="form-field">
                  {renderLabel("Fecha factura", AdCampos.FechaFactura)}
                  <input
                    className="form-input"
                    type="date"
                    name="fechaFactura"
                    data-campo-id={AdCampos.FechaFactura}
                    max={getTodayDateInputMax()}
                    value={formValues[AdCampos.FechaFactura] ?? ""}
                    onChange={(event) =>
                      updateFormValue(AdCampos.FechaFactura, event.target.value)
                    }
                  />
                </div>
              )}
              {isFieldVisible(AdCampos.ValorUsd) && (
                <div className="form-field">
                  {renderLabel("Valor USD", AdCampos.ValorUsd)}
                  <input
                    className="form-input"
                    type="number"
                    name="valorUsd"
                    data-campo-id={AdCampos.ValorUsd}
                    inputMode="decimal"
                    step="any"
                    min="0.000001"
                    placeholder="0"
                    value={formValues[AdCampos.ValorUsd] ?? ""}
                    onChange={(event) =>
                      updateFormValue(
                        AdCampos.ValorUsd,
                        sanitizePositiveDecimal(event.target.value)
                      )
                    }
                  />
                </div>
              )}
              {isFieldVisible(AdCampos.GuiaBl) && (
                <div className="form-field">
                  {renderLabel("Guía/BL", AdCampos.GuiaBl)}
                  <TagInput
                    value={formValues[AdCampos.GuiaBl] ?? ""}
                    onChange={(value) =>
                      updateFormValue(AdCampos.GuiaBl, normalizeGuiaBlTags(value))
                    }
                    sanitizeInput={(text) => text.replace(/[^a-zA-Z0-9]/g, "")}
                    placeholder="Número de guía o BL"
                  />
                  {renderMultiValueHint()}
                </div>
              )}
              {isFieldVisible(AdCampos.Pedimento) && (
                <div className="form-field">
                  {renderLabel("Pedimento", AdCampos.Pedimento)}
                  <input
                    className="form-input"
                    type="text"
                    name="pedimento"
                    data-campo-id={AdCampos.Pedimento}
                    inputMode="numeric"
                    maxLength={15}
                    placeholder="268034386543210"
                    value={formValues[AdCampos.Pedimento] ?? ""}
                    onChange={(event) =>
                      updateFormValue(
                        AdCampos.Pedimento,
                        event.target.value.replace(/\D/g, "").slice(0, 15)
                      )
                    }
                  />
                  <span className="form-helper">
                    15 dígitos: año (2) + aduana (2) + patente (4) + número (7)
                  </span>
                </div>
              )}
                </div>
              )}
              {showCaptureControls && (
                <div className="document-repository-cards">
              {showIdentificadorGeneral && (
                <section className="data-card oc-light-card">
                  <h3 className="data-card-title">Identificador general</h3>
                  <div className="data-card-grid">
                    <div className="form-field">
                      {renderRequiredLabel("Identificador", showIdentificadorGeneral)}
                      <input
                        className="form-input"
                        type="text"
                        name="identificadorGeneral"
                        maxLength={2}
                        placeholder="AA"
                        value={additionalValues.identificadorGeneral.identificador}
                        onChange={(event) =>
                          updateAdditionalValue(
                            "identificadorGeneral",
                            "identificador",
                            event.target.value
                          )
                        }
                      />
                    </div>
                    <div className="form-field">
                      {renderRequiredLabel("Complemento", false)}
                      <input
                        className="form-input"
                        type="text"
                        name="complementoGeneral"
                        maxLength={255}
                        value={additionalValues.identificadorGeneral.complemento}
                        onChange={(event) =>
                          updateAdditionalValue(
                            "identificadorGeneral",
                            "complemento",
                            event.target.value
                          )
                        }
                      />
                    </div>
                    <div className="form-field">
                      {renderRequiredLabel("Complemento 2", false)}
                      <input
                        className="form-input"
                        type="text"
                        name="complementoGeneral2"
                        maxLength={255}
                        value={additionalValues.identificadorGeneral.complemento2}
                        onChange={(event) =>
                          updateAdditionalValue(
                            "identificadorGeneral",
                            "complemento2",
                            event.target.value
                          )
                        }
                      />
                    </div>
                    <div className="form-field">
                      {renderRequiredLabel("Complemento 3", false)}
                      <input
                        className="form-input"
                        type="text"
                        name="complementoGeneral3"
                        maxLength={255}
                        value={additionalValues.identificadorGeneral.complemento3}
                        onChange={(event) =>
                          updateAdditionalValue(
                            "identificadorGeneral",
                            "complemento3",
                            event.target.value
                          )
                        }
                      />
                    </div>
                  </div>
                </section>
              )}

              {showIdentificadorPartida && (
                <section className="data-card oc-light-card">
                  <h3 className="data-card-title">Identificador partida</h3>
                  <div className="data-card-grid">
                    <div className="form-field">
                      {renderRequiredLabel("Identificador", showIdentificadorPartida)}
                      <input
                        className="form-input"
                        type="text"
                        name="identificadorPartida"
                        maxLength={255}
                        placeholder="Identificador"
                        value={additionalValues.identificadorPartida.identificador}
                        onChange={(event) =>
                          updateAdditionalValue(
                            "identificadorPartida",
                            "identificador",
                            event.target.value
                          )
                        }
                      />
                    </div>
                    <div className="form-field">
                      {renderRequiredLabel("Complemento 1", false)}
                      <input
                        className="form-input"
                        type="text"
                        name="complemento1Partida"
                        maxLength={255}
                        value={additionalValues.identificadorPartida.complemento1}
                        onChange={(event) =>
                          updateAdditionalValue(
                            "identificadorPartida",
                            "complemento1",
                            event.target.value
                          )
                        }
                      />
                    </div>
                    <div className="form-field">
                      {renderRequiredLabel("Complemento 2", false)}
                      <input
                        className="form-input"
                        type="text"
                        name="complemento2Partida"
                        maxLength={255}
                        value={additionalValues.identificadorPartida.complemento2}
                        onChange={(event) =>
                          updateAdditionalValue(
                            "identificadorPartida",
                            "complemento2",
                            event.target.value
                          )
                        }
                      />
                    </div>
                    <div className="form-field">
                      {renderRequiredLabel("Complemento 3", false)}
                      <input
                        className="form-input"
                        type="text"
                        name="complemento3Partida"
                        maxLength={255}
                        value={additionalValues.identificadorPartida.complemento3}
                        onChange={(event) =>
                          updateAdditionalValue(
                            "identificadorPartida",
                            "complemento3",
                            event.target.value
                          )
                        }
                      />
                    </div>
                  </div>
                </section>
              )}

              {showPermisos && (
                <section className="data-card oc-light-card">
                  <h3 className="data-card-title">Permiso</h3>
                  <div className="data-card-grid">
                    <div className="form-field">
                      {renderRequiredLabel("Régimen", showPermisos)}
                      <input
                        className="form-input"
                        type="text"
                        name="regimenPermiso"
                        maxLength={2}
                        placeholder="00"
                        value={additionalValues.permiso.regimen}
                        onChange={(event) =>
                          updateAdditionalValue(
                            "permiso",
                            "regimen",
                            event.target.value
                          )
                        }
                      />
                    </div>
                    <div className="form-field">
                      {renderRequiredLabel("Permiso", showPermisos)}
                      <input
                        className="form-input"
                        type="text"
                        name="permiso"
                        maxLength={2}
                        placeholder="AA"
                        value={additionalValues.permiso.permiso}
                        onChange={(event) =>
                          updateAdditionalValue(
                            "permiso",
                            "permiso",
                            event.target.value
                          )
                        }
                      />
                    </div>
                    <div className="form-field">
                      {renderRequiredLabel("Número", false)}
                      <input
                        className="form-input"
                        type="text"
                        name="numeroPermiso"
                        maxLength={255}
                        value={additionalValues.permiso.numero}
                        onChange={(event) =>
                          updateAdditionalValue(
                            "permiso",
                            "numero",
                            event.target.value
                          )
                        }
                      />
                    </div>
                    <div className="form-field">
                      {renderRequiredLabel("Firma", false)}
                      <input
                        className="form-input"
                        type="text"
                        name="firmaPermiso"
                        maxLength={255}
                        value={additionalValues.permiso.firma}
                        onChange={(event) =>
                          updateAdditionalValue(
                            "permiso",
                            "firma",
                            event.target.value
                          )
                        }
                      />
                    </div>
                  </div>
                </section>
              )}
                </div>
              )}
            </div>
            <AlertModal
              open={showMissingConfig}
              title={alertTitle}
              message={missingConfigMessage}
              confirmLabel="Entendido"
              variant={alertVariant}
              onClose={() => setShowMissingConfig(false)}
            />
            <ConfirmationModal
              open={showConfirmSave}
              title="Confirmar guardado"
              message="¿Deseas guardar este documento?"
              confirmLabel="Guardar"
              cancelLabel="Cancelar"
              onConfirm={handleConfirmSave}
              onCancel={() => setShowConfirmSave(false)}
            />

            <div className="document-repository-actions">
              <Button
                variant="primary"
                icon={<CheckIcon />}
                onClick={handleSave}
                disabled={!isSaveEnabled}
              >
                Guardar
              </Button>
            </div>
          </section>
        </div>
      </div>
    </div>
  );
}

export default DocumentRepositoryCreatePage;
