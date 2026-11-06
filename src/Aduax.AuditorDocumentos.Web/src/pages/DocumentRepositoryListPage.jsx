import { useEffect, useMemo, useState, Fragment } from "react";
import { toast } from "react-toastify";
import {
  AlertModal,
  Button,
  ConfirmationModal,
  RadioGroup,
  LoadingPanel,
  PaginatedSelect,
  PageHeader,
  PdfViewer,
  TagInput,
  SelloVucemModal,
  VucemMensajeModal,
} from "../components";
import { documentosService, motorConfigService } from "../services";
import { AdCampos } from "../constants/adCampos";
import { AdDocumentoClasificacion } from "../constants/adDocumentoClasificacion";
import { AdAccionPedimento } from "../constants/adAccionPedimento";
import {
  puedeEnviarVucem,
  puedeEliminarAsociacionOperacion,
  tieneMensajeVucem,
  OrigenSelloVucem,
  esCorreoVucemValido,
  normalizarCorreoVucem,
  mensajeErrorEnvioVucem,
} from "../constants/adVucemEnvio";
import "./DocumentRepositoryListPage.css";

const DocumentIcon = () => (
  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
    <polyline points="14 2 14 8 20 8" />
    <line x1="16" y1="13" x2="8" y2="13" />
    <line x1="16" y1="17" x2="8" y2="17" />
    <polyline points="10 9 9 9 8 9" />
  </svg>
);

const ListIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <line x1="8" y1="6" x2="21" y2="6" />
    <line x1="8" y1="12" x2="21" y2="12" />
    <line x1="8" y1="18" x2="21" y2="18" />
    <line x1="3" y1="6" x2="3.01" y2="6" />
    <line x1="3" y1="12" x2="3.01" y2="12" />
    <line x1="3" y1="18" x2="3.01" y2="18" />
  </svg>
);

const EyeIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12z" />
    <circle cx="12" cy="12" r="3" />
  </svg>
);

const CheckIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <polyline points="20 6 9 17 4 12" />
  </svg>
);

const TrashIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <polyline points="3 6 5 6 21 6" />
    <path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" />
    <path d="M10 11v6" />
    <path d="M14 11v6" />
    <path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2" />
  </svg>
);

const LinkIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M10 13a5 5 0 0 1 0-7l1.5-1.5a5 5 0 0 1 7 7L17 12" />
    <path d="M14 11a5 5 0 0 1 0 7L12.5 19.5a5 5 0 0 1-7-7L7 12" />
  </svg>
);

const MessageIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M21 15a4 4 0 0 1-4 4H8l-5 3V7a4 4 0 0 1 4-4h10a4 4 0 0 1 4 4z" />
    <line x1="8" y1="9" x2="16" y2="9" />
    <line x1="8" y1="13" x2="14" y2="13" />
  </svg>
);

const RefreshIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <polyline points="23 4 23 10 17 10" />
    <polyline points="1 20 1 14 7 14" />
    <path d="M3.51 9a9 9 0 0 1 14.13-3.36L23 10M1 14l5.36 4.36A9 9 0 0 0 20.49 15" />
  </svg>
);

/** Envío / carga hacia VUCEM */
const SendVucemIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
    <polyline points="17 8 12 3 7 8" />
    <line x1="12" y1="3" x2="12" y2="15" />
  </svg>
);

/** Icono tipo laboratorio (matraz) para diagnóstico de sugerencias */
const LabFlaskIcon = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
    <path d="M9 3h6M10 3v5.5L6 20h12l-4-11.5V3" strokeLinecap="round" strokeLinejoin="round" />
    <path d="M6 16h12" strokeLinecap="round" />
  </svg>
);

const ASSOCIATE_OPERATIONS_PAGE_SIZE = 5;

const formatDateOnly = (value) => {
  if (!value) {
    return "";
  }
  if (typeof value === "string") {
    return value.split("T")[0] || value;
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "";
  }
  return date.toISOString().slice(0, 10);
};

const matchesAssociateOperationFilter = (operation, filter) => {
  const search = filter.trim().toLowerCase();
  if (!search) {
    return true;
  }
  const values = [
    operation?.id_referencia,
    operation?.id_rectificacion,
    operation?.pedimento,
    operation?.edocument,
    formatDateOnly(operation?.fechaAsociacion),
  ]
    .filter((value) => value != null && String(value).trim() !== "")
    .map((value) => String(value).toLowerCase());
  return values.some((value) => value.includes(search));
};

export default function DocumentRepositoryListPage({ selectedClient }) {
  const [documents, setDocuments] = useState([]);
  const [filter, setFilter] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [selectedTypeFilter, setSelectedTypeFilter] = useState("");
  const [selectedStatusFilter, setSelectedStatusFilter] = useState("");
  const [showPdfModal, setShowPdfModal] = useState(false);
  const [pdfUrl, setPdfUrl] = useState("");
  const [showPdfError, setShowPdfError] = useState(false);
  const [pdfErrorMessage, setPdfErrorMessage] = useState("");
  const [showAssociateModal, setShowAssociateModal] = useState(false);
  const [associateDocument, setAssociateDocument] = useState(null);
  const [associateMotorConfigHeader, setAssociateMotorConfigHeader] =
    useState(null);
  const [associateLoading, setAssociateLoading] = useState(false);
  const [associateOperationsRefreshing, setAssociateOperationsRefreshing] =
    useState(false);
  const [associateOperations, setAssociateOperations] = useState([]);
  const [associateOperationsPage, setAssociateOperationsPage] = useState(1);
  const [associateOperationsFilter, setAssociateOperationsFilter] = useState("");
  const [associatePedimento, setAssociatePedimento] = useState("");
  const [selectedSuggestion, setSelectedSuggestion] = useState(null);
  const [showAssociateConfirm, setShowAssociateConfirm] = useState(false);
  const [showAssociatePedimentoWarning, setShowAssociatePedimentoWarning] =
    useState(false);
  const [pendingAfectaOperacion, setPendingAfectaOperacion] = useState(false);
  const [showAssociateTransferAlert, setShowAssociateTransferAlert] =
    useState(false);
  const [associateTransferAlertTitle, setAssociateTransferAlertTitle] =
    useState("");
  const [associateTransferAlertMessage, setAssociateTransferAlertMessage] =
    useState("");
  const [associateTransferAlertVariant, setAssociateTransferAlertVariant] =
    useState("alert");
  const [associateSugerenciasVacias, setAssociateSugerenciasVacias] =
    useState(false);
  const [showDiagnosticoSugerenciasModal, setShowDiagnosticoSugerenciasModal] =
    useState(false);
  const [showSelloVucemModal, setShowSelloVucemModal] = useState(false);
  const [showVucemMensajeModal, setShowVucemMensajeModal] = useState(false);
  const [vucemMensajeText, setVucemMensajeText] = useState("");
  const [selloVucemLoading, setSelloVucemLoading] = useState(false);
  const [vucemOperationTarget, setVucemOperationTarget] = useState(null);
  const [sellosVucemLookup, setSellosVucemLookup] = useState(null);
  const [vucemCorreoElectronico, setVucemCorreoElectronico] = useState("");
  const [diagnosticoPedimentoInput, setDiagnosticoPedimentoInput] =
    useState("");
  const [diagnosticoLoading, setDiagnosticoLoading] = useState(false);
  const [diagnosticoRows, setDiagnosticoRows] = useState([]);
  const [diagnosticoDetalleIndex, setDiagnosticoDetalleIndex] = useState(null);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [documentToDelete, setDocumentToDelete] = useState(null);
  const [showDeleteAsociacionConfirm, setShowDeleteAsociacionConfirm] =
    useState(false);
  const [asociacionToDelete, setAsociacionToDelete] = useState(null);
  const [deleteAsociacionLoading, setDeleteAsociacionLoading] = useState(false);
  const [showAuthorizeModal, setShowAuthorizeModal] = useState(false);
  const [detailLoading, setDetailLoading] = useState(false);
  const [detailData, setDetailData] = useState(null);
  const [detailValues, setDetailValues] = useState({});
  const [showAuthorizeActions, setShowAuthorizeActions] = useState(true);
  const [canAccionCriticaDetalle, setCanAccionCriticaDetalle] = useState(false);
  const [authorizeTitle, setAuthorizeTitle] = useState("Autorizar documento");
  const [detailAdditional, setDetailAdditional] = useState({
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
  const [showRejectModal, setShowRejectModal] = useState(false);
  const [rejectComment, setRejectComment] = useState("");
  const [showRejectCommentModal, setShowRejectCommentModal] = useState(false);
  const [rejectCommentText, setRejectCommentText] = useState("");

  const filteredDocuments = useMemo(() => {
    const search = filter.trim().toLowerCase();
    return documents.filter((item) => {
      if (selectedTypeFilter && (item?.documentoVucem || "") !== selectedTypeFilter) {
        return false;
      }
      if (selectedStatusFilter && (item?.estatus || "") !== selectedStatusFilter) {
        return false;
      }
      if (!search) {
        return true;
      }
      const values = [
        item?.documentoVucem,
        item?.prefijoEI,
        item?.nombreArchivo,
        item?.awsRuta,
        item?.idCliente,
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      return values.includes(search);
    });
  }, [documents, filter, selectedStatusFilter, selectedTypeFilter]);

  const documentsForType = useMemo(() => {
    if (selectedTypeFilter) {
      return documents;
    }
    if (!selectedStatusFilter) {
      return documents;
    }
    return documents.filter(
      (item) => (item?.estatus || "") === selectedStatusFilter
    );
  }, [documents, selectedStatusFilter, selectedTypeFilter]);

  const typeCounts = useMemo(() => {
    return documentsForType.reduce((acc, item) => {
      const key =
        item?.documentoVucem ||
        (item?.idTipoDocumentoVucem != null
          ? `Tipo ${item.idTipoDocumentoVucem}`
          : "Sin tipo");
      acc[key] = (acc[key] || 0) + 1;
      return acc;
    }, {});
  }, [documentsForType]);

  const documentsForStatus = useMemo(() => {
    if (!selectedTypeFilter) {
      return documents;
    }
    return documents.filter(
      (item) => (item?.documentoVucem || "") === selectedTypeFilter
    );
  }, [documents, selectedTypeFilter]);

  const statusCounts = useMemo(() => {
    return documentsForStatus.reduce((acc, item) => {
      const key = item?.estatus || "Sin estatus";
      acc[key] = (acc[key] || 0) + 1;
      return acc;
    }, {});
  }, [documentsForStatus]);

  const filteredAssociateOperations = useMemo(
    () =>
      associateOperations.filter((operation) =>
        matchesAssociateOperationFilter(operation, associateOperationsFilter)
      ),
    [associateOperations, associateOperationsFilter]
  );

  const associateOperationsTotalPages = useMemo(
    () =>
      Math.max(
        1,
        Math.ceil(
          filteredAssociateOperations.length / ASSOCIATE_OPERATIONS_PAGE_SIZE
        )
      ),
    [filteredAssociateOperations.length]
  );

  const paginatedAssociateOperations = useMemo(() => {
    const start = (associateOperationsPage - 1) * ASSOCIATE_OPERATIONS_PAGE_SIZE;
    return filteredAssociateOperations.slice(
      start,
      start + ASSOCIATE_OPERATIONS_PAGE_SIZE
    );
  }, [filteredAssociateOperations, associateOperationsPage]);

  const associateOperationsRangeLabel = useMemo(() => {
    if (!filteredAssociateOperations.length) {
      return "";
    }
    const start = (associateOperationsPage - 1) * ASSOCIATE_OPERATIONS_PAGE_SIZE + 1;
    const end = Math.min(
      associateOperationsPage * ASSOCIATE_OPERATIONS_PAGE_SIZE,
      filteredAssociateOperations.length
    );
    const total = filteredAssociateOperations.length;
    const hasFilter = associateOperationsFilter.trim().length > 0;
    const totalAll = associateOperations.length;
    if (hasFilter && total !== totalAll) {
      return `${start}-${end} de ${total} (${totalAll} en total)`;
    }
    return `${start}-${end} de ${total}`;
  }, [
    associateOperations.length,
    associateOperationsFilter,
    associateOperationsPage,
    filteredAssociateOperations.length,
  ]);

  useEffect(() => {
    setAssociateOperationsPage(1);
  }, [associateOperationsFilter]);

  useEffect(() => {
    if (associateOperationsPage > associateOperationsTotalPages) {
      setAssociateOperationsPage(associateOperationsTotalPages);
    }
  }, [associateOperationsPage, associateOperationsTotalPages]);

  const loadDocuments = async () => {
    setIsLoading(true);
    try {
      const response = await documentosService.obtenerDocumentos({
        idCliente: selectedClient,
        idTipoDocumentoVucem: 0,
        data: 0,
      });
      if (!response?.success) {
        throw new Error(response?.message || "No se pudo cargar la lista de documentos.");
      }
      setDocuments(response?.data || []);
    } catch (error) {
      toast.error(error?.message || "Ocurrió un error al cargar los documentos.");
      setDocuments([]);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    if (!selectedClient) {
      setDocuments([]);
      setSelectedTypeFilter("");
      setSelectedStatusFilter("");
      return;
    }
    loadDocuments();
  }, [selectedClient]);

  const handleTypeFilter = (type) => {
    setSelectedTypeFilter((prev) => (prev === type ? "" : type));
  };

  const handleStatusFilter = (status) => {
    setSelectedStatusFilter(status);
  };

  const detailMotorConfigHeader = detailData?.motorConfigHeader ?? null;
  const detailMap = useMemo(() => {
    const detalles = detailMotorConfigHeader?.detalles || [];
    return new Map(detalles.map((detail) => [detail.idCampo, detail]));
  }, [detailMotorConfigHeader]);
  const configClasificacion = Number(detailMotorConfigHeader?.idClasificacion);
  const showIdentificadorGeneral =
    configClasificacion === AdDocumentoClasificacion.IdentificadorGeneral;
  const showIdentificadorPartida =
    configClasificacion === AdDocumentoClasificacion.IdentificadorPartida;
  const showPermisos =
    configClasificacion === AdDocumentoClasificacion.Permisos;

  const isDetailFieldVisible = (campoId) => {
    if (!detailMotorConfigHeader) {
      return true;
    }
    const detail = detailMap.get(campoId);
    return Boolean(detail?.visible);
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
    return String(value);
  };

  const handleOpenAuthorizeModal = async (item, options = {}) => {
    if (!item || !selectedClient) {
      return;
    }
    setCanAccionCriticaDetalle(Boolean(item?.puedeAccionCritica));
    const showActions = options.showActions !== false;
    setShowAuthorizeActions(showActions);
    if (showActions) {
      setAuthorizeTitle("Autorizar documento");
    } else {
      const docName = item?.documentoVucem || "Ver documento";
      const fileName = item?.nombreArchivo;
      setAuthorizeTitle(
        fileName ? `${docName} (${fileName})` : docName
      );
    }
    setShowAuthorizeModal(true);
    setDetailLoading(true);
    setPdfUrl(item?.awsRuta || "");
    setDetailData(null);
    setDetailValues({});
    setRejectComment("");
    try {
      const response = await documentosService.obtenerDocumentoPorId({
        idCliente: selectedClient,
        idTipoDocumentoVucem: item?.idTipoDocumentoVucem ?? 0,
        data: item?.id ?? 0,
      });
      if (!response?.success) {
        throw new Error(response?.message || "No se pudo cargar el documento.");
      }
      const data = response?.data || null;
      setDetailData(data);
      const values = {};
      (data?.campos || []).forEach((campo) => {
        if (!campo) {
          return;
        }
        const campoId = Number(campo.idCampo);
        if (!Number.isNaN(campoId)) {
          values[campoId] = normalizeFieldValue(campoId, campo.valor);
        }
      });
      setDetailValues(values);
      setDetailAdditional({
        identificadorGeneral: {
          identificador: data?.identificadorGeneral?.identificador ?? "",
          complemento: data?.identificadorGeneral?.complemento ?? "",
          complemento2: data?.identificadorGeneral?.complemento2 ?? "",
          complemento3: data?.identificadorGeneral?.complemento3 ?? "",
        },
        identificadorPartida: {
          regimen: data?.identificadorPartida?.regimen ?? "",
          tipoAdvalorem: data?.identificadorPartida?.tipoAdvalorem ?? "",
          origen: data?.identificadorPartida?.origen ?? "",
          identificador: data?.identificadorPartida?.identificador ?? "",
          complemento1: data?.identificadorPartida?.complemento1 ?? "",
          complemento2: data?.identificadorPartida?.complemento2 ?? "",
          complemento3: data?.identificadorPartida?.complemento3 ?? "",
        },
        permiso: {
          regimen: data?.permiso?.regimen ?? "",
          permiso: data?.permiso?.permiso ?? "",
          numero: data?.permiso?.numero ?? "",
          firma: data?.permiso?.firma ?? "",
        },
      });
    } catch (error) {
      toast.error(error?.message || "Ocurrió un error al cargar el documento.");
      setShowAuthorizeModal(false);
    } finally {
      setDetailLoading(false);
    }
  };

  const handleCloseAuthorizeModal = () => {
    setShowAuthorizeModal(false);
    setDetailData(null);
    setDetailValues({});
    setRejectComment("");
    setShowAuthorizeActions(true);
    setAuthorizeTitle("Autorizar documento");
  };

  const handleApprove = async () => {
    if (!detailData || !selectedClient) {
      return;
    }
    try {
      setDetailLoading(true);
      const response = await documentosService.autorizaDocumento({
        idCliente: selectedClient,
        idTipoDocumentoVucem: detailData?.idTipoDocumentoVucem ?? 0,
        data: detailData?.id ?? 0,
      });
      if (!response?.success) {
        throw new Error(response?.message || "No se pudo autorizar el documento.");
      }
      toast.success("Documento autorizado correctamente.");
      handleCloseAuthorizeModal();
      await loadDocuments();
    } catch (error) {
      toast.error(error?.message || "Ocurrió un error al autorizar el documento.");
    } finally {
      setDetailLoading(false);
    }
  };

  const handleOpenRejectModal = () => {
    setShowRejectModal(true);
  };

  const handleCancelReject = () => {
    setShowRejectModal(false);
    setRejectComment("");
  };

  const handleConfirmReject = async () => {
    if (!detailData || !selectedClient || !rejectComment.trim()) {
      return;
    }
    try {
      handleCancelReject();
      setDetailLoading(true);
      const response = await documentosService.rechazarDocumento({
        idCliente: selectedClient,
        idTipoDocumentoVucem: detailData?.idTipoDocumentoVucem ?? 0,
        data: {
          idDocumento: detailData?.id ?? 0,
          motivoRechazo: rejectComment.trim(),
        },
      });
      if (!response?.success) {
        throw new Error(response?.message || "No se pudo rechazar el documento.");
      }
      toast.success("Documento rechazado correctamente.");
      handleCloseAuthorizeModal();
      await loadDocuments();
    } catch (error) {
      toast.error(error?.message || "Ocurrió un error al rechazar el documento.");
      handleCancelReject();
    } finally {
      setDetailLoading(false);
    }
  };

  const handleOpenRejectCommentModal = (comment) => {
    setRejectCommentText(comment || "");
    setShowRejectCommentModal(true);
  };

  const handleCloseRejectCommentModal = () => {
    setShowRejectCommentModal(false);
    setRejectCommentText("");
  };
  const handleOpenPdf = (url) => {
    if (!url) {
      setPdfErrorMessage("No existe una URL válida para mostrar el documento.");
      setShowPdfError(true);
      return;
    }
    try {
      const parsed = new URL(url);
      if (!["http:", "https:"].includes(parsed.protocol)) {
        throw new Error("Invalid protocol");
      }
    } catch (error) {
      setPdfErrorMessage("No existe una URL válida para mostrar el documento.");
      setShowPdfError(true);
      return;
    }
    setPdfUrl(url);
    setShowPdfModal(true);
  };

  const handleClosePdf = () => {
    setShowPdfModal(false);
  };

  const handleOpenAssociateModal = (item) => {
    setAssociateDocument(item);
    setAssociateOperations([]);
    setAssociateOperationsPage(1);
    setAssociateOperationsFilter("");
    setAssociatePedimento("");
    setSelectedSuggestion(null);
    setAssociateSugerenciasVacias(false);
    setShowAssociateModal(true);
    setDetailValues({});
    setAssociateMotorConfigHeader(null);
    if (!item || !selectedClient) {
      return;
    }
    setAssociateLoading(true);
    documentosService
      .obtenerDocumentoPorId({
        idCliente: selectedClient,
        idTipoDocumentoVucem: item?.idTipoDocumentoVucem ?? 0,
        data: item?.id ?? 0,
      })
      .then((response) => {
        if (!response?.success) {
          throw new Error(
            response?.message || "No se pudo cargar el documento."
          );
        }
        const data = response?.data || null;
        setAssociateMotorConfigHeader(data?.motorConfigHeader ?? null);
        setAssociateOperations(data?.operaciones || []);
        const values = {};
        (data?.campos || []).forEach((campo) => {
          if (!campo) {
            return;
          }
          const campoId = Number(campo.idCampo);
          if (!Number.isNaN(campoId)) {
            values[campoId] = normalizeFieldValue(campoId, campo.valor);
          }
        });
        setDetailValues(values);
      })
      .catch((error) => {
        toast.error(error?.message || "No se pudo cargar el documento.");
        setAssociateOperations([]);
        setAssociateMotorConfigHeader(null);
      })
      .finally(() => {
        setAssociateLoading(false);
      });
  };

  const getAssociateAccionPedimento = () =>
    associateMotorConfigHeader?.accionPedimento ?? AdAccionPedimento.PreguntaSiAfecta;

  const resolveAfectaOperacion = (explicitChoice) => {
    const accion = getAssociateAccionPedimento();
    if (accion === AdAccionPedimento.AfectaOperacion) {
      return true;
    }
    if (accion === AdAccionPedimento.NoAfectaOperacion) {
      return false;
    }
    return explicitChoice === true;
  };

  const associateRequiresAfectaChoice =
    getAssociateAccionPedimento() === AdAccionPedimento.PreguntaSiAfecta;

  const openAssociateConfirm = () => {
    setPendingAfectaOperacion(false);
    setShowAssociateConfirm(true);
  };

  const associateAfectaOperacionOptions = [
    {
      value: "true",
      label: "Sí, trasladar identificadores y/o permisos al pedimento o tráfico",
    },
    {
      value: "false",
      label: "No trasladar datos al pedimento o tráfico",
    },
  ];

  const refreshAssociateOperations = async () => {
    if (!associateDocument || !selectedClient || associateOperationsRefreshing) {
      return;
    }
    try {
      setAssociateOperationsRefreshing(true);
      const refresh = await documentosService.obtenerDocumentoPorId({
        idCliente: selectedClient,
        idTipoDocumentoVucem: associateDocument?.idTipoDocumentoVucem ?? 0,
        data: associateDocument?.id ?? 0,
      });
      if (refresh?.success) {
        setAssociateOperations(refresh?.data?.operaciones || []);
        if (refresh?.data?.motorConfigHeader) {
          setAssociateMotorConfigHeader(refresh.data.motorConfigHeader);
        }
      } else {
        toast.error(
          refresh?.message || "No se pudieron actualizar los pedimentos asociados."
        );
      }
    } catch (error) {
      toast.error(
        error?.message || "No se pudieron actualizar los pedimentos asociados."
      );
    } finally {
      setAssociateOperationsRefreshing(false);
    }
  };

  const handleCloseSelloVucemModal = () => {
    setShowSelloVucemModal(false);
    setVucemOperationTarget(null);
    setSellosVucemLookup(null);
    setVucemCorreoElectronico("");
    setSelloVucemLoading(false);
  };

  const handleOpenVucemMensajeModal = (mensaje) => {
    setVucemMensajeText((mensaje ?? "").trim());
    setShowVucemMensajeModal(true);
  };

  const handleCloseVucemMensajeModal = () => {
    setShowVucemMensajeModal(false);
    setVucemMensajeText("");
  };

  const handleOpenVucemEnvio = async (operation) => {
    if (!operation || !associateDocument || !selectedClient) {
      return;
    }
    setVucemOperationTarget(operation);
    setVucemCorreoElectronico("");
    setShowSelloVucemModal(true);
    setSelloVucemLoading(true);
    setSellosVucemLookup(null);
    try {
      const response = await documentosService.obtenerSellosVucemDisponibles({
        idCliente: selectedClient,
        idTipoDocumentoVucem: associateDocument?.idTipoDocumentoVucem ?? 0,
        data: {
          idDocumento: associateDocument?.id ?? 0,
          idReferencia: operation?.id_referencia ?? "",
          idRectificacion: operation?.id_rectificacion ?? null,
        },
      });
      if (!response?.success) {
        throw new Error(response?.message || "No se pudieron cargar los sellos.");
      }
      setSellosVucemLookup(response?.data ?? null);
    } catch (error) {
      toast.error(error?.message || "No se pudieron cargar los sellos VUCEM.");
      handleCloseSelloVucemModal();
    } finally {
      setSelloVucemLoading(false);
    }
  };

  const handleEnviarVucemConOrigen = async (origenSello) => {
    if (!vucemOperationTarget || !associateDocument || !selectedClient) {
      return;
    }
    if (!esCorreoVucemValido(vucemCorreoElectronico)) {
      toast.error("Ingrese un correo electrónico válido o déjelo en blanco.");
      return;
    }
    const correoElectronico = normalizarCorreoVucem(vucemCorreoElectronico);
    try {
      setSelloVucemLoading(true);
      const response = await documentosService.enviarDocumentoVucem({
        idCliente: selectedClient,
        idTipoDocumentoVucem: associateDocument?.idTipoDocumentoVucem ?? 0,
        data: {
          idDocumento: associateDocument?.id ?? 0,
          idReferencia: vucemOperationTarget?.id_referencia ?? "",
          idRectificacion: vucemOperationTarget?.id_rectificacion ?? null,
          origenSello,
          correoElectronico,
        },
      });
      if (!response?.success) {
        throw new Error(response?.message || "No se pudo enviar a VUCEM.");
      }
      toast.success(
        response?.message ||
          `Envío registrado. Número de operación: ${response?.data?.numeroOperacion ?? "-"}`
      );
      handleCloseSelloVucemModal();
      await refreshAssociateOperations();
    } catch (error) {
      toast.error(mensajeErrorEnvioVucem(error));
    } finally {
      setSelloVucemLoading(false);
    }
  };

  const handleOpenDeleteAsociacion = (operation) => {
    if (!operation || !associateDocument) {
      return;
    }
    setAsociacionToDelete(operation);
    setShowDeleteAsociacionConfirm(true);
  };

  const handleCancelDeleteAsociacion = () => {
    if (deleteAsociacionLoading) {
      return;
    }
    setShowDeleteAsociacionConfirm(false);
    setAsociacionToDelete(null);
  };

  const handleConfirmDeleteAsociacion = async () => {
    if (
      !asociacionToDelete ||
      !associateDocument ||
      !selectedClient ||
      deleteAsociacionLoading
    ) {
      return;
    }
    try {
      setDeleteAsociacionLoading(true);
      const response = await documentosService.eliminarAsociacionOperacion({
        idCliente: selectedClient,
        idTipoDocumentoVucem: associateDocument?.idTipoDocumentoVucem ?? 0,
        data: {
          idDocumento: associateDocument?.id ?? 0,
          idReferencia: asociacionToDelete?.id_referencia ?? "",
          idRectificacion: asociacionToDelete?.id_rectificacion ?? null,
        },
      });
      if (!response?.success) {
        throw new Error(
          response?.message || "No se pudo eliminar la asociación."
        );
      }
      toast.success(response?.message || "Asociación eliminada correctamente.");
      setShowDeleteAsociacionConfirm(false);
      setAsociacionToDelete(null);
      await refreshAssociateOperations();
    } catch (error) {
      toast.error(error?.message || "No se pudo eliminar la asociación.");
    } finally {
      setDeleteAsociacionLoading(false);
    }
  };

  const handleCloseAssociateModal = () => {
    handleCloseSelloVucemModal();
    handleCloseVucemMensajeModal();
    handleCancelDeleteAsociacion();
    setShowAssociateModal(false);
    setAssociateOperationsRefreshing(false);
    setAssociateDocument(null);
    setAssociateMotorConfigHeader(null);
    setAssociateOperations([]);
    setAssociateOperationsPage(1);
    setAssociateOperationsFilter("");
    setAssociatePedimento("");
    setSelectedSuggestion(null);
    setAssociateSugerenciasVacias(false);
    setShowDiagnosticoSugerenciasModal(false);
    setDiagnosticoPedimentoInput("");
    setDiagnosticoRows([]);
    setDiagnosticoDetalleIndex(null);
    setShowAssociateTransferAlert(false);
    setAssociateTransferAlertMessage("");
    setPendingAfectaOperacion(false);
  };

  const isSuggestionWithoutPedimento = (suggestion) => {
    if (!suggestion) {
      return false;
    }
    const idRect = suggestion.idRectificacion;
    const rectIsNull = idRect == null;
    const ped = suggestion.pedimento;
    const pedIsEmpty =
      ped == null || String(ped).trim() === "";
    return rectIsNull && pedIsEmpty;
  };

  const handleRequestAssociate = () => {
    if (!selectedSuggestion || !associateDocument) {
      return;
    }
    if (isSuggestionWithoutPedimento(selectedSuggestion)) {
      setShowAssociatePedimentoWarning(true);
    } else {
      openAssociateConfirm();
    }
  };

  const handleCancelAssociate = () => {
    setShowAssociateConfirm(false);
    setPendingAfectaOperacion(false);
  };

  const handleCancelAssociatePedimentoWarning = () => {
    setShowAssociatePedimentoWarning(false);
  };

  const performAssociateOperation = async () => {
    if (!selectedSuggestion || !associateDocument || !selectedClient) {
      return;
    }
    try {
      setAssociateLoading(true);
      const payload = {
        idCliente: selectedClient,
        idTipoDocumentoVucem: associateDocument?.idTipoDocumentoVucem ?? 0,
        data: {
          idDocumento: associateDocument?.id ?? 0,
          idReferencia: selectedSuggestion?.idReferencia ?? "",
          idRectificacion: selectedSuggestion?.idRectificacion ?? null,
          pedimento:
            selectedSuggestion?.pedimento != null &&
            String(selectedSuggestion.pedimento).trim() !== ""
              ? String(selectedSuggestion.pedimento).trim()
              : null,
          afectaOperacion: resolveAfectaOperacion(
            associateRequiresAfectaChoice ? pendingAfectaOperacion : null
          ),
        },
      };
      const response = await documentosService.altaAsociacionOperacion(payload);
      const transferPayload = response?.data ?? {};
      const mensajeEjecucionTransfer = (() => {
        const a = transferPayload.mensajeEjecucion;
        const b = transferPayload.MensajeEjecucion;
        const raw = a != null ? a : b;
        return raw != null ? String(raw).trim() : "";
      })();
      const resultadoSp =
        transferPayload.resultado ?? transferPayload.Resultado;
      const spSinFilasAfectadas = resultadoSp === false;

      if (!response?.success || spSinFilasAfectadas) {
        const baseMsg =
          response?.message || "No se pudo asociar la operación.";
        const full = mensajeEjecucionTransfer
          ? `${baseMsg}\n\n${mensajeEjecucionTransfer}`
          : baseMsg;
        setAssociateTransferAlertTitle(
          spSinFilasAfectadas
            ? "Sin registros afectados"
            : "Transferencia de datos"
        );
        setAssociateTransferAlertMessage(full);
        setAssociateTransferAlertVariant("error");
        setShowAssociateTransferAlert(true);
        return;
      }
      await refreshAssociateOperations();
      setAssociatePedimento("");
      setSelectedSuggestion(null);
      setPendingAfectaOperacion(false);
      const mensajeEjecucionOk =
        response?.data?.mensajeEjecucion != null
          ? String(response.data.mensajeEjecucion).trim()
          : response?.data?.MensajeEjecucion != null
            ? String(response.data.MensajeEjecucion).trim()
            : "";
      const okSummary =
        (typeof response?.message === "string" && response.message.trim()) ||
        "Operación asociada correctamente.";
      const successBody = mensajeEjecucionOk
        ? `${okSummary}\n\n${mensajeEjecucionOk}`
        : okSummary;
      setAssociateTransferAlertTitle("Asociación completada");
      setAssociateTransferAlertMessage(successBody);
      setAssociateTransferAlertVariant("success");
      setShowAssociateTransferAlert(true);
    } catch (error) {
      setAssociateTransferAlertTitle("Error al asociar");
      setAssociateTransferAlertMessage(
        getErrorMessage(error, "No se pudo asociar la operación.")
      );
      setAssociateTransferAlertVariant("error");
      setShowAssociateTransferAlert(true);
    } finally {
      setAssociateLoading(false);
    }
  };

  const handleConfirmAssociatePedimentoWarning = () => {
    setShowAssociatePedimentoWarning(false);
    openAssociateConfirm();
  };

  const handleConfirmAssociate = async () => {
    if (!selectedSuggestion || !associateDocument || !selectedClient) {
      setShowAssociateConfirm(false);
      return;
    }
    setShowAssociateConfirm(false);
    await performAssociateOperation();
  };

  useEffect(() => {
    if (!showAssociateModal || associateLoading || !associateDocument || !selectedClient) {
      return undefined;
    }
    let cancelled = false;
    (async () => {
      try {
        const response = await motorConfigService.obtenerSugerenciaPedimentos(
          {
            idCliente: selectedClient,
            idTipoDocumentoVucem: associateDocument?.idTipoDocumentoVucem ?? 0,
            data: {
              data: {
                idAdDocumento: associateDocument?.id ?? 0,
                operacionBusqueda: "",
              },
              page: 1,
              size: 10,
            },
          },
          undefined
        );
        if (cancelled) {
          return;
        }
        const totalRecords = response?.data?.totalRecords ?? 0;
        setAssociateSugerenciasVacias(totalRecords === 0);
      } catch {
        if (!cancelled) {
          setAssociateSugerenciasVacias(false);
        }
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [
    showAssociateModal,
    associateLoading,
    associateDocument,
    selectedClient,
  ]);

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
        if (typeof parsed?.message === "string") {
          return parsed.message.trim();
        }
      } catch (parseError) {
        // ignore
      }
    }
    try {
      const parsed = JSON.parse(rawMessage);
      if (typeof parsed?.message === "string") {
        return parsed.message.trim();
      }
    } catch (parseError) {
      // ignore
    }
    return rawMessage;
  };

  const handleOpenDiagnosticoSugerenciasModal = () => {
    setDiagnosticoPedimentoInput("");
    setDiagnosticoRows([]);
    setDiagnosticoDetalleIndex(null);
    setShowDiagnosticoSugerenciasModal(true);
  };

  const handleCloseDiagnosticoSugerenciasModal = () => {
    setShowDiagnosticoSugerenciasModal(false);
    setDiagnosticoDetalleIndex(null);
  };

  const handleEjecutarDiagnosticoSugerencias = async () => {
    if (!associateDocument || !selectedClient) {
      return;
    }
    const operacionBusqueda = String(diagnosticoPedimentoInput || "").trim();
    if (!operacionBusqueda) {
      toast.warn("Indique pedimento, referencia/rectificación o tráfico.");
      return;
    }
    setDiagnosticoLoading(true);
    setDiagnosticoDetalleIndex(null);
    try {
      const response = await motorConfigService.diagnosticoSugerenciaPedimentos(
        {
          idCliente: selectedClient,
          idTipoDocumentoVucem: associateDocument?.idTipoDocumentoVucem ?? 0,
          data: {
            idAdDocumento: associateDocument?.id ?? 0,
            operacionBusqueda,
          },
        },
        undefined
      );
      if (!response?.success) {
        throw new Error(response?.message || "No se pudo ejecutar el diagnóstico.");
      }
      const rows = Array.isArray(response.data) ? response.data : [];
      setDiagnosticoRows(rows);
    } catch (error) {
      toast.error(getErrorMessage(error, "No se pudo ejecutar el diagnóstico."));
      setDiagnosticoRows([]);
    } finally {
      setDiagnosticoLoading(false);
    }
  };

  const handlePdfError = () => {
    setPdfErrorMessage("No se pudo cargar el documento desde la URL proporcionada.");
    setShowPdfError(true);
  };

  const handleRequestDelete = (item) => {
    setDocumentToDelete(item);
    setShowDeleteConfirm(true);
  };

  const handleCancelDelete = () => {
    setShowDeleteConfirm(false);
    setDocumentToDelete(null);
  };

  const handleConfirmDelete = async () => {
    if (!documentToDelete || !selectedClient) {
      handleCancelDelete();
      return;
    }
    try {
      handleCancelDelete();
      setIsLoading(true);
      const response = await documentosService.eliminarDocumento({
        idCliente: selectedClient,
        idTipoDocumentoVucem: documentToDelete?.idTipoDocumentoVucem ?? 0,
        data: documentToDelete?.id ?? 0,
      });
      if (!response?.success) {
        throw new Error(response?.message || "No se pudo eliminar el documento.");
      }
      toast.success("Documento eliminado correctamente.");
      handleCancelDelete();
      await loadDocuments();
    } catch (error) {
      toast.error(error?.message || "Ocurrió un error al eliminar el documento.");
      handleCancelDelete();
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="document-repository-page">
      <PageHeader
        icon={<DocumentIcon />}
        title="Repositorio de documentos"
        subtitle="Listado de documentos registrados"
      />

      <div className="document-repository-content">
        <div className="document-repository-layout">
          <aside className="document-repository-sidebar oc-light-card">
            <div className="section-header">
              <ListIcon />
              <span className="section-title">Resumen</span>
            </div>
            {!selectedClient && (
              <p className="section-helper">
                Selecciona un cliente para ver el resumen.
              </p>
            )}
            {selectedClient && (
              <div className="document-kpis">
                <button
                  type="button"
                  className="document-kpi document-kpi-button"
                  onClick={() => {
                    setSelectedTypeFilter("");
                    setSelectedStatusFilter("");
                  }}
                >
                  <span className="document-kpi-label">Total documentos</span>
                  <span className="document-kpi-value">{documents.length}</span>
                </button>
                <div className="document-kpi-group">
                  <span className="document-kpi-title">Tipos de documento</span>
                  {Object.keys(typeCounts).length === 0 && (
                    <p className="section-helper">Sin documentos registrados.</p>
                  )}
                  {Object.entries(typeCounts).map(([tipo, count]) => (
                    <button
                      key={tipo}
                      type="button"
                      className={`document-kpi document-kpi-button ${
                        selectedTypeFilter === tipo ? "active" : ""
                      }`}
                      onClick={() => handleTypeFilter(tipo)}
                    >
                      <span className="document-kpi-label">
                        {tipo}
                      </span>
                      <span className="document-kpi-value">{count}</span>
                    </button>
                  ))}
                </div>
                <div className="document-kpi-group">
                  <span className="document-kpi-title">Estatus</span>
                  {Object.keys(statusCounts).length === 0 && (
                    <p className="section-helper">Sin documentos registrados.</p>
                  )}
                  {Object.entries(statusCounts).map(([status, count]) => (
                    <button
                      key={status}
                      type="button"
                      className={`document-kpi document-kpi-button ${
                        selectedStatusFilter === status ? "active" : ""
                      }`}
                      onClick={() => handleStatusFilter(status)}
                    >
                      <span className="document-kpi-label">
                        {status}
                      </span>
                      <span className="document-kpi-value">{count}</span>
                    </button>
                  ))}
                </div>
              </div>
            )}
          </aside>

          <section className="document-repository-main oc-light-card">
            <LoadingPanel show={isLoading} message="Cargando documentos..." />
            <div className="section-header">
              <ListIcon />
              <span className="section-title">Documentos configurados</span>
            </div>

            <div className="document-repository-toolbar">
              <div className="document-repository-filter">
                <label className="document-filter-label" htmlFor="document-filter">
                  Buscar
                </label>
                <input
                  id="document-filter"
                  className="document-filter-input"
                  type="text"
                  value={filter}
                  onChange={(event) => setFilter(event.target.value)}
                  placeholder="Buscar por documento, prefijo o archivo..."
                />
              </div>
              <div className="document-repository-actions" />
            </div>

            {!selectedClient && (
              <div className="document-repository-placeholder">
                Selecciona un cliente para listar documentos.
              </div>
            )}

            {selectedClient && !filteredDocuments.length && (
              <div className="document-repository-placeholder">
                No hay documentos para mostrar.
              </div>
            )}

            {selectedClient && filteredDocuments.length > 0 && (
              <div className="document-table-wrapper">
                <table className="document-table">
                  <thead>
                    <tr>
                      <th>Documento</th>
                      <th>Prefijo</th>
                      <th>VUCEM</th>
                      <th>Vigencia</th>
                      <th>Archivo</th>
                      <th>Clasificación</th>
                      <th>Estatus</th>
                      <th>Creación</th>
                      <th>Creado por</th>
                      <th>Acciones</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredDocuments.map((item) => {
                      const isPending = item?.idEstatus === 2;
                      const isApproved = item?.idEstatus === 3;
                      const canAssociateStatus =
                        item?.idEstatus === 3 ||
                        item?.idEstatus === 5 ||
                        item?.idEstatus === 6;
                      const puedeAccionCritica = Boolean(item?.puedeAccionCritica);
                      return (
                        <tr key={item.id}>
                          <td>{item.documentoVucem ?? "-"}</td>
                          <td>{item.prefijoEI ?? "-"}</td>
                          <td>{item.idVucem ?? "-"}</td>
                          <td>
                            {item.fechaVigenciaInicio || item.fechaVigenciaFin
                              ? `${formatDateOnly(item.fechaVigenciaInicio)} ${
                                  item.fechaVigenciaFin
                                    ? `- ${formatDateOnly(item.fechaVigenciaFin)}`
                                    : ""
                                }`
                              : "-"}
                          </td>
                          <td>{item.nombreArchivo ?? "-"}</td>
                        <td>{item.clasificacion ?? "-"}</td>
                          <td>{item.estatus ?? "-"}</td>
                          <td>{formatDateOnly(item.fechaCreacion) || "-"}</td>
                          <td>{item.creadoPor ?? "-"}</td>
                          <td className="document-actions">
                            <button
                              type="button"
                              className="document-action-button"
                              aria-label="Ver"
                              title="Ver"
                              onClick={() =>
                                handleOpenAuthorizeModal(item, { showActions: false })
                              }
                            >
                              <EyeIcon />
                            </button>
                            {isPending && (
                              <>
                                <button
                                  type="button"
                                  className="document-action-button"
                                  aria-label="Autorizar"
                                  title="Autorizar"
                                  onClick={() =>
                                    handleOpenAuthorizeModal(item, { showActions: true })
                                  }
                                  disabled={!puedeAccionCritica}
                                >
                                  <CheckIcon />
                                </button>
                                <button
                                  type="button"
                                  className="document-action-button"
                                  aria-label="Eliminar"
                                  title="Eliminar"
                                  onClick={() => handleRequestDelete(item)}
                                  disabled={!puedeAccionCritica}
                                >
                                  <TrashIcon />
                                </button>
                              </>
                            )}
                            {(isApproved || canAssociateStatus) && (
                              <button
                                type="button"
                                className="document-action-button"
                                aria-label="Eliminar"
                                title="Eliminar"
                                onClick={() => handleRequestDelete(item)}
                                disabled={!puedeAccionCritica}
                              >
                                <TrashIcon />
                              </button>
                            )}
                            {item?.idEstatus === 4 && (
                              <button
                                type="button"
                                className="document-action-button"
                                aria-label="Ver comentarios de rechazo"
                                title="Ver comentarios de rechazo"
                                onClick={() =>
                                  handleOpenRejectCommentModal(
                                    item?.comentarioRechazo
                                  )
                                }
                              >
                                <MessageIcon />
                              </button>
                            )}
                            {canAssociateStatus && (
                              <button
                                type="button"
                                className="document-action-button"
                                aria-label="Relacionar con operación"
                                title="Relacionar con operación"
                                onClick={() => handleOpenAssociateModal(item)}
                                disabled={!puedeAccionCritica}
                              >
                                <LinkIcon />
                              </button>
                            )}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </section>
        </div>
      </div>
      {showPdfModal && (
        <div className="pdf-modal-overlay pdf-viewer-overlay" role="dialog" aria-modal="true">
          <div className="pdf-modal">
            <div className="pdf-modal-header">
              <span className="pdf-modal-title">Documento</span>
              <button
                type="button"
                className="pdf-modal-close"
                onClick={handleClosePdf}
                aria-label="Cerrar"
                title="Cerrar"
              >
                ×
              </button>
            </div>
            <PdfViewer
              url={pdfUrl}
              title="Vista previa del documento"
              onError={handlePdfError}
            />
          </div>
        </div>
      )}
      <AlertModal
        open={showPdfError}
        title="No se pudo cargar el documento"
        message={pdfErrorMessage}
        confirmLabel="Entendido"
        variant="error"
        onClose={() => setShowPdfError(false)}
      />
      {showAuthorizeModal && (
        <div className="pdf-modal-overlay" role="dialog" aria-modal="true">
          <div className="pdf-modal pdf-modal-large">
            <div className="pdf-modal-header">
              <span className="pdf-modal-title">{authorizeTitle}</span>
              <button
                type="button"
                className="pdf-modal-close"
                onClick={handleCloseAuthorizeModal}
                aria-label="Cerrar"
                title="Cerrar"
              >
                ×
              </button>
            </div>
            <LoadingPanel show={detailLoading} message="Cargando documento..." />
            <div className="authorize-modal-toolbar">
              <Button
                variant="secondary"
                onClick={() => handleOpenPdf(pdfUrl)}
                disabled={!pdfUrl}
              >
                Ver documento
              </Button>
            </div>
            <div className="authorize-modal-body">
                <div className="authorize-section">
                  <h3 className="authorize-title">Campos capturados</h3>
                  <div className="authorize-form">
                    {isDetailFieldVisible(AdCampos.Proveedor) && (
                      <div className="form-field">
                        <label className="form-label">Proveedor</label>
                        <input
                          className="form-input"
                          type="text"
                          value={detailValues[AdCampos.Proveedor] ?? ""}
                          disabled
                        />
                      </div>
                    )}
                    {isDetailFieldVisible(AdCampos.TipoPedimento) && (
                      <div className="form-field">
                        <label className="form-label">Tipo pedimento</label>
                        <input
                          className="form-input"
                          type="text"
                          value={detailValues[AdCampos.TipoPedimento] ?? ""}
                          disabled
                        />
                      </div>
                    )}
                    {isDetailFieldVisible(AdCampos.TipoOperacion) && (
                      <div className="form-field">
                        <label className="form-label">Tipo de operación</label>
                        <input
                          className="form-input"
                          type="text"
                          value={detailValues[AdCampos.TipoOperacion] ?? ""}
                          disabled
                        />
                      </div>
                    )}
                    {isDetailFieldVisible(AdCampos.ClavePedimento) && (
                      <div className="form-field">
                        <label className="form-label">Clave de pedimento</label>
                        <TagInput
                          value={detailValues[AdCampos.ClavePedimento] ?? ""}
                          disabled
                        />
                      </div>
                    )}
                    {isDetailFieldVisible(AdCampos.ProductoNoDeParte) && (
                      <div className="form-field">
                        <label className="form-label">Producto/No de parte</label>
                        <TagInput value={detailValues[AdCampos.ProductoNoDeParte] ?? ""} disabled />
                      </div>
                    )}
                    {isDetailFieldVisible(AdCampos.DescripcionMercancia) && (
                      <div className="form-field">
                        <label className="form-label">Descripción de mercancía</label>
                        <TagInput
                          value={detailValues[AdCampos.DescripcionMercancia] ?? ""}
                          disabled
                        />
                      </div>
                    )}
                    {isDetailFieldVisible(AdCampos.Fracciones) && (
                      <div className="form-field">
                        <label className="form-label">Fracciones</label>
                        <TagInput value={detailValues[AdCampos.Fracciones] ?? ""} disabled />
                      </div>
                    )}
                    {isDetailFieldVisible(AdCampos.Nico) && (
                      <div className="form-field">
                        <label className="form-label">Nico</label>
                        <TagInput value={detailValues[AdCampos.Nico] ?? ""} disabled />
                      </div>
                    )}
                    {isDetailFieldVisible(AdCampos.Cantidad) && (
                      <div className="form-field">
                        <label className="form-label">Cantidad</label>
                        <input
                          className="form-input"
                          type="text"
                          inputMode="decimal"
                          value={detailValues[AdCampos.Cantidad] ?? ""}
                          disabled
                        />
                      </div>
                    )}
                    {isDetailFieldVisible(AdCampos.UnidadMedidaUMT) && (
                      <div className="form-field">
                        <label className="form-label">Unidad de medida (UMT)</label>
                        <TagInput value={detailValues[AdCampos.UnidadMedidaUMT] ?? ""} disabled />
                      </div>
                    )}
                    {isDetailFieldVisible(AdCampos.PaisOrigenDestino) && (
                      <div className="form-field">
                        <label className="form-label">País de origen/destino</label>
                        <TagInput value={detailValues[AdCampos.PaisOrigenDestino] ?? ""} disabled />
                      </div>
                    )}
                    {isDetailFieldVisible(AdCampos.VigenciaDesde) && (
                      <div className="form-field">
                        <label className="form-label">Vigencia desde</label>
                        <input
                          className="form-input"
                          type="date"
                          value={detailValues[AdCampos.VigenciaDesde] ?? ""}
                          disabled
                        />
                      </div>
                    )}
                    {isDetailFieldVisible(AdCampos.VigenciaHasta) && (
                      <div className="form-field">
                        <label className="form-label">Vigencia hasta</label>
                        <input
                          className="form-input"
                          type="date"
                          value={detailValues[AdCampos.VigenciaHasta] ?? ""}
                          disabled
                        />
                      </div>
                    )}
                    {isDetailFieldVisible(AdCampos.Aduana) && (
                      <div className="form-field">
                        <label className="form-label">Aduana</label>
                        <input
                          className="form-input"
                          type="text"
                          value={detailValues[AdCampos.Aduana] ?? ""}
                          disabled
                        />
                      </div>
                    )}
                    {isDetailFieldVisible(AdCampos.FirmaDeRL) && (
                      <div className="form-field">
                        <label className="form-label">Firma de Representante Legal</label>
                        <input
                          className="form-input"
                          type="text"
                          value={detailValues[AdCampos.FirmaDeRL] ?? ""}
                          disabled
                        />
                      </div>
                    )}
                    {isDetailFieldVisible(AdCampos.Nom) && (
                      <div className="form-field">
                        <label className="form-label">Nom</label>
                        <input
                          className="form-input"
                          type="text"
                          value={detailValues[AdCampos.Nom] ?? ""}
                          disabled
                        />
                      </div>
                    )}
                    {isDetailFieldVisible(AdCampos.ValorComercial) && (
                      <div className="form-field">
                        <label className="form-label">Valor Comercial</label>
                        <input
                          className="form-input"
                          type="text"
                          inputMode="decimal"
                          value={detailValues[AdCampos.ValorComercial] ?? ""}
                          disabled
                        />
                      </div>
                    )}
                    {isDetailFieldVisible(AdCampos.Factura) && (
                      <div className="form-field">
                        <label className="form-label">Factura</label>
                        <input
                          className="form-input"
                          type="text"
                          value={detailValues[AdCampos.Factura] ?? ""}
                          disabled
                        />
                      </div>
                    )}
                    {isDetailFieldVisible(AdCampos.FechaFactura) && (
                      <div className="form-field">
                        <label className="form-label">Fecha factura</label>
                        <input
                          className="form-input"
                          type="date"
                          value={detailValues[AdCampos.FechaFactura] ?? ""}
                          disabled
                        />
                      </div>
                    )}
                    {isDetailFieldVisible(AdCampos.ValorUsd) && (
                      <div className="form-field">
                        <label className="form-label">Valor USD</label>
                        <input
                          className="form-input"
                          type="text"
                          inputMode="decimal"
                          value={detailValues[AdCampos.ValorUsd] ?? ""}
                          disabled
                        />
                      </div>
                    )}
                    {isDetailFieldVisible(AdCampos.GuiaBl) && (
                      <div className="form-field">
                        <label className="form-label">Guía/BL</label>
                        <TagInput value={detailValues[AdCampos.GuiaBl] ?? ""} disabled />
                      </div>
                    )}
                    {isDetailFieldVisible(AdCampos.Pedimento) && (
                      <div className="form-field">
                        <label className="form-label">Pedimento</label>
                        <input
                          className="form-input"
                          type="text"
                          inputMode="numeric"
                          value={detailValues[AdCampos.Pedimento] ?? ""}
                          disabled
                        />
                      </div>
                    )}
                  </div>
                </div>
                {showIdentificadorGeneral && (
                  <div className="authorize-section">
                    <h3 className="authorize-title">Identificador general</h3>
                    <div className="authorize-form">
                      <div className="form-field">
                        <label className="form-label">Identificador</label>
                        <input
                          className="form-input"
                          type="text"
                          value={detailAdditional.identificadorGeneral.identificador}
                          disabled
                        />
                      </div>
                      <div className="form-field">
                        <label className="form-label">Complemento</label>
                        <input
                          className="form-input"
                          type="text"
                          value={detailAdditional.identificadorGeneral.complemento}
                          disabled
                        />
                      </div>
                      <div className="form-field">
                        <label className="form-label">Complemento 2</label>
                        <input
                          className="form-input"
                          type="text"
                          value={detailAdditional.identificadorGeneral.complemento2}
                          disabled
                        />
                      </div>
                      <div className="form-field">
                        <label className="form-label">Complemento 3</label>
                        <input
                          className="form-input"
                          type="text"
                          value={detailAdditional.identificadorGeneral.complemento3}
                          disabled
                        />
                      </div>
                    </div>
                  </div>
                )}
                {showIdentificadorPartida && (
                  <div className="authorize-section">
                    <h3 className="authorize-title">Identificador partida</h3>
                    <div className="authorize-form">
                      <div className="form-field">
                        <label className="form-label">Identificador</label>
                        <input
                          className="form-input"
                          type="text"
                          value={detailAdditional.identificadorPartida.identificador}
                          disabled
                        />
                      </div>
                      <div className="form-field">
                        <label className="form-label">Complemento 1</label>
                        <input
                          className="form-input"
                          type="text"
                          value={detailAdditional.identificadorPartida.complemento1}
                          disabled
                        />
                      </div>
                      <div className="form-field">
                        <label className="form-label">Complemento 2</label>
                        <input
                          className="form-input"
                          type="text"
                          value={detailAdditional.identificadorPartida.complemento2}
                          disabled
                        />
                      </div>
                      <div className="form-field">
                        <label className="form-label">Complemento 3</label>
                        <input
                          className="form-input"
                          type="text"
                          value={detailAdditional.identificadorPartida.complemento3}
                          disabled
                        />
                      </div>
                    </div>
                  </div>
                )}
                {showPermisos && (
                  <div className="authorize-section">
                    <h3 className="authorize-title">Permiso</h3>
                    <div className="authorize-form">
                      <div className="form-field">
                        <label className="form-label">Régimen</label>
                        <input
                          className="form-input"
                          type="text"
                          value={detailAdditional.permiso.regimen}
                          disabled
                        />
                      </div>
                      <div className="form-field">
                        <label className="form-label">Permiso</label>
                        <input
                          className="form-input"
                          type="text"
                          value={detailAdditional.permiso.permiso}
                          disabled
                        />
                      </div>
                      <div className="form-field">
                        <label className="form-label">Número</label>
                        <input
                          className="form-input"
                          type="text"
                          value={detailAdditional.permiso.numero}
                          disabled
                        />
                      </div>
                      <div className="form-field">
                        <label className="form-label">Firma</label>
                        <input
                          className="form-input"
                          type="text"
                          value={detailAdditional.permiso.firma}
                          disabled
                        />
                      </div>
                    </div>
                  </div>
                )}
            </div>
            {showAuthorizeActions && (
              <div className="authorize-modal-actions">
                <Button
                  variant="primary"
                  onClick={handleApprove}
                  disabled={detailLoading || !canAccionCriticaDetalle}
                >
                  Aprobar
                </Button>
                <Button
                  variant="secondary"
                  onClick={handleOpenRejectModal}
                  disabled={detailLoading || !canAccionCriticaDetalle}
                >
                  Rechazar
                </Button>
              </div>
            )}
          </div>
        </div>
      )}
      {showRejectModal && (
        <div className="pdf-modal-overlay" role="dialog" aria-modal="true">
          <div className="reject-modal">
            <div className="pdf-modal-header">
              <span className="pdf-modal-title">Motivo de rechazo</span>
              <button
                type="button"
                className="pdf-modal-close"
                onClick={handleCancelReject}
                aria-label="Cerrar"
                title="Cerrar"
              >
                ×
              </button>
            </div>
            <div className="reject-modal-body">
              <label className="form-label">Comentarios</label>
              <textarea
                className="reject-textarea"
                rows={4}
                value={rejectComment}
                maxLength={450}
                onChange={(event) => setRejectComment(event.target.value)}
              />
            </div>
            <div className="authorize-modal-actions">
              <Button variant="secondary" onClick={handleCancelReject}>
                Cancelar
              </Button>
              <Button
                variant="primary"
                onClick={handleConfirmReject}
                disabled={
                  !rejectComment.trim() || detailLoading || !canAccionCriticaDetalle
                }
              >
                Continuar
              </Button>
            </div>
          </div>
        </div>
      )}
      {showRejectCommentModal && (
        <div className="pdf-modal-overlay" role="dialog" aria-modal="true">
          <div className="reject-modal">
            <div className="pdf-modal-header">
              <span className="pdf-modal-title">Comentarios de rechazo</span>
              <button
                type="button"
                className="pdf-modal-close"
                onClick={handleCloseRejectCommentModal}
                aria-label="Cerrar"
                title="Cerrar"
              >
                ×
              </button>
            </div>
            <div className="reject-modal-body">
              <label className="form-label">Comentarios</label>
              <textarea
                className="reject-textarea"
                rows={4}
                value={rejectCommentText}
                readOnly
              />
            </div>
            <div className="authorize-modal-actions">
              <Button variant="primary" onClick={handleCloseRejectCommentModal}>
                Cerrar
              </Button>
            </div>
          </div>
        </div>
      )}
      {showAssociateModal && (
        <div className="pdf-modal-overlay" role="dialog" aria-modal="true">
          <div className="pdf-modal associate-modal">
            <div className="pdf-modal-header">
              <span className="pdf-modal-title">Relacionar operación</span>
              <button
                type="button"
                className="pdf-modal-close"
                onClick={handleCloseAssociateModal}
                aria-label="Cerrar"
                title="Cerrar"
              >
                ×
              </button>
            </div>
            <LoadingPanel
              show={associateLoading}
              message="Cargando operaciones..."
            />
            <div className="associate-modal-body">
              <div className="associate-section">
                <span className="associate-title">Datos del documento</span>
                <div className="associate-tags">
                  <span className="associate-tag">
                    {associateDocument?.documentoVucem ?? "Sin documento"}
                  </span>
                  <span className="associate-tag">
                    {associateDocument?.nombreArchivo ?? "Sin archivo"}
                  </span>
                  <span className="associate-tag">
                    {associateDocument?.clasificacion ?? "Sin clasificación"}
                  </span>
                </div>
              </div>
              <div className="associate-section">
                <span className="associate-title">Operaciones sugeridas</span>
                <div className="associate-suggested-row">
                  <PaginatedSelect
                    value={associatePedimento}
                    onChange={(value) => setAssociatePedimento(value)}
                    onSelectItem={(item) => setSelectedSuggestion(item)}
                    placeholder="Seleccione un pedimento..."
                    filterable
                    disabled={!associateDocument}
                    loadPage={({ filter, page, size, token }) =>
                      motorConfigService.obtenerSugerenciaPedimentos(
                        {
                          idCliente: selectedClient,
                          idTipoDocumentoVucem:
                            associateDocument?.idTipoDocumentoVucem ?? 0,
                          data: {
                            data: {
                              idAdDocumento: associateDocument?.id ?? 0,
                              operacionBusqueda: filter || "",
                            },
                            page,
                            size,
                          },
                        },
                        token
                      )
                    }
                    onAfterLoad={({ totalRecords, page }) => {
                      if (page === 1) {
                        setAssociateSugerenciasVacias(totalRecords === 0);
                      }
                    }}
                    getOptionValue={(item) => item?.idReferencia ?? ""}
                    getOptionLabel={(item) =>
                      [
                        `${item?.idReferencia ?? "-"}${item?.idRectificacion != null ? `/${item.idRectificacion}` : ""} ::`,
                        item?.aduana ?? "",
                        item?.patente ?? "",
                        item?.pedimento ?? "",
                      ]
                        .filter(Boolean)
                        .join(" ")
                        .trim()
                    }
                  />
                  <Button
                    variant="primary"
                    onClick={handleRequestAssociate}
                    disabled={
                      !selectedSuggestion ||
                      !associateDocument
                    }
                  >
                    Asociar
                  </Button>
                  {associateSugerenciasVacias && (
                    <button
                      type="button"
                      className="associate-diagnostico-btn"
                      onClick={handleOpenDiagnosticoSugerenciasModal}
                      title="¿Por qué no aparece mi operación?"
                      aria-label="¿Por qué no aparece mi operación?"
                    >
                      <LabFlaskIcon />
                    </button>
                  )}
                </div>
              </div>
              <div className="associate-section">
                <div className="associate-section-header">
                  <span className="associate-title">Pedimentos asociados</span>
                  <div className="associate-operations-toolbar">
                    <input
                      type="search"
                      className="associate-operations-search"
                      value={associateOperationsFilter}
                      onChange={(event) =>
                        setAssociateOperationsFilter(event.target.value)
                      }
                      placeholder="Buscar referencia, pedimento, eDocument..."
                      aria-label="Buscar pedimentos asociados"
                      disabled={
                        associateLoading ||
                        associateOperationsRefreshing ||
                        !associateDocument
                      }
                      autoComplete="off"
                    />
                    <button
                      type="button"
                      className="associate-operation-action-btn associate-refresh-operations-btn"
                      aria-label="Actualizar pedimentos asociados"
                      title="Actualizar pedimentos asociados"
                      disabled={
                        associateLoading ||
                        associateOperationsRefreshing ||
                        selloVucemLoading ||
                        !associateDocument
                      }
                      onClick={refreshAssociateOperations}
                    >
                      <RefreshIcon />
                    </button>
                  </div>
                </div>
                <div
                  className={`document-table-wrapper associate-operations-table-wrap${
                    associateOperationsRefreshing
                      ? " document-table-wrapper--refreshing"
                      : ""
                  }`}
                >
                  <table className="document-table">
                    <thead>
                      <tr>
                        <th>Id referencia</th>
                        <th>Id rectificación</th>
                        <th>Pedimento</th>
                        <th>eDocument</th>
                        <th>Fecha de asociación</th>
                        <th>Acción</th>
                      </tr>
                    </thead>
                    <tbody>
                      {associateOperations.length === 0 && (
                        <tr>
                          <td colSpan={6}>Sin asociaciones</td>
                        </tr>
                      )}
                      {associateOperations.length > 0 &&
                        filteredAssociateOperations.length === 0 && (
                          <tr>
                            <td colSpan={6}>
                              Sin resultados para la búsqueda
                            </td>
                          </tr>
                        )}
                      {paginatedAssociateOperations.map((operation, index) => (
                        <tr
                          key={`${operation?.id ?? index}-${operation?.id_referencia}-${operation?.id_rectificacion}`}
                        >
                          <td>{operation?.id_referencia ?? "-"}</td>
                          <td>{operation?.id_rectificacion ?? "-"}</td>
                          <td>{operation?.pedimento ?? "-"}</td>
                          <td>{operation?.edocument?.trim() || "-"}</td>
                          <td>{formatDateOnly(operation?.fechaAsociacion) || "-"}</td>
                          <td>
                            <div className="associate-operation-actions">
                            {puedeEnviarVucem(operation) ? (
                              <button
                                type="button"
                                className="associate-operation-action-btn"
                                aria-label={
                                  (operation?.mensaje ?? "").trim()
                                    ? "Reenviar a VUCEM"
                                    : "Enviar a VUCEM"
                                }
                                title={
                                  (operation?.mensaje ?? "").trim()
                                    ? "Reenviar a VUCEM"
                                    : "Enviar a VUCEM"
                                }
                                disabled={
                                  associateLoading ||
                                  associateOperationsRefreshing ||
                                  selloVucemLoading ||
                                  deleteAsociacionLoading
                                }
                                onClick={() => handleOpenVucemEnvio(operation)}
                              >
                                <SendVucemIcon />
                              </button>
                            ) : null}
                            {puedeEliminarAsociacionOperacion(operation) ? (
                              <button
                                type="button"
                                className="associate-operation-action-btn"
                                aria-label="Eliminar asociación"
                                title="Eliminar asociación"
                                disabled={
                                  associateLoading ||
                                  associateOperationsRefreshing ||
                                  selloVucemLoading ||
                                  deleteAsociacionLoading ||
                                  !associateDocument?.puedeAccionCritica
                                }
                                onClick={() =>
                                  handleOpenDeleteAsociacion(operation)
                                }
                              >
                                <TrashIcon />
                              </button>
                            ) : null}
                            {tieneMensajeVucem(operation) ? (
                              <button
                                type="button"
                                className="associate-operation-action-btn associate-operation-action-btn--message"
                                aria-label="Ver mensaje de envío VUCEM"
                                title="Ver mensaje de envío VUCEM"
                                onClick={() =>
                                  handleOpenVucemMensajeModal(operation?.mensaje)
                                }
                              >
                                <MessageIcon />
                              </button>
                            ) : null}
                            {!puedeEnviarVucem(operation) &&
                            !puedeEliminarAsociacionOperacion(operation) &&
                            !tieneMensajeVucem(operation)
                              ? "-"
                              : null}
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                {filteredAssociateOperations.length > 0 && (
                  <div className="associate-operations-pagination">
                    <span className="associate-operations-pagination-info">
                      Mostrando {associateOperationsRangeLabel}
                    </span>
                    {associateOperationsTotalPages > 1 && (
                      <nav
                        className="associate-operations-pagination-controls"
                        aria-label="Paginación de pedimentos asociados"
                      >
                        <button
                          type="button"
                          className="associate-operations-pagination-link"
                          onClick={() =>
                            setAssociateOperationsPage((prev) =>
                              Math.max(1, prev - 1)
                            )
                          }
                          disabled={
                            associateOperationsPage <= 1 ||
                            associateLoading ||
                            associateOperationsRefreshing
                          }
                        >
                          Anterior
                        </button>
                        <span className="associate-operations-pagination-page">
                          {associateOperationsPage} / {associateOperationsTotalPages}
                        </span>
                        <button
                          type="button"
                          className="associate-operations-pagination-link"
                          onClick={() =>
                            setAssociateOperationsPage((prev) =>
                              Math.min(associateOperationsTotalPages, prev + 1)
                            )
                          }
                          disabled={
                            associateOperationsPage >=
                              associateOperationsTotalPages ||
                            associateLoading ||
                            associateOperationsRefreshing
                          }
                        >
                          Siguiente
                        </button>
                      </nav>
                    )}
                  </div>
                )}
              </div>
            </div>
            <div className="authorize-modal-actions">
              <Button variant="secondary" onClick={handleCloseAssociateModal}>
                Cerrar
              </Button>
            </div>
          </div>
        </div>
      )}
      {showAssociateModal && showSelloVucemModal && (
        <SelloVucemModal
          open={showSelloVucemModal}
          loading={selloVucemLoading}
          puedeElegirCliente={Boolean(sellosVucemLookup?.idSelloCliente > 0)}
          correoElectronico={vucemCorreoElectronico}
          onCorreoElectronicoChange={setVucemCorreoElectronico}
          operacionLabel={
            vucemOperationTarget
              ? `Ref. ${vucemOperationTarget.id_referencia ?? ""}${
                  vucemOperationTarget.id_rectificacion != null
                    ? ` / Rect. ${vucemOperationTarget.id_rectificacion}`
                    : ""
                }`
              : ""
          }
          onSelectCliente={() => handleEnviarVucemConOrigen(OrigenSelloVucem.Cliente)}
          onSelectAgente={() => handleEnviarVucemConOrigen(OrigenSelloVucem.AgenteAduanal)}
          onCancel={handleCloseSelloVucemModal}
        />
      )}
      {showAssociateModal && showDiagnosticoSugerenciasModal && (
        <div
          className="pdf-modal-overlay diagnostico-sugerencias-overlay"
          role="dialog"
          aria-modal="true"
        >
          <div className="pdf-modal diagnostico-sugerencias-modal">
            <div className="pdf-modal-header">
              <span className="pdf-modal-title">Diagnóstico de sugerencias</span>
              <button
                type="button"
                className="pdf-modal-close"
                onClick={handleCloseDiagnosticoSugerenciasModal}
                aria-label="Cerrar diagnóstico"
                title="Cerrar"
              >
                ×
              </button>
            </div>
            <LoadingPanel
              show={diagnosticoLoading}
              message="Ejecutando diagnóstico..."
            />
            <div className="diagnostico-sugerencias-body">
              <p className="diagnostico-sugerencias-hint">
                Indique el pedimento, la referencia con rectificación (por ejemplo 123/1) o el identificador de tráfico que esperaba ver en la lista de sugerencias.
              </p>
              <label className="form-label" htmlFor="diagnostico-pedimento-input">
                Pedimento / referencia–rectificación / tráfico
              </label>
              <input
                id="diagnostico-pedimento-input"
                type="text"
                className="diagnostico-sugerencias-input"
                value={diagnosticoPedimentoInput}
                onChange={(event) =>
                  setDiagnosticoPedimentoInput(event.target.value)
                }
                disabled={diagnosticoLoading}
                autoComplete="off"
              />
              <div className="diagnostico-sugerencias-actions">
                <Button
                  variant="primary"
                  onClick={handleEjecutarDiagnosticoSugerencias}
                  disabled={diagnosticoLoading || !associateDocument}
                >
                  Ejecutar revisión
                </Button>
                <Button
                  variant="secondary"
                  onClick={handleCloseDiagnosticoSugerenciasModal}
                  disabled={diagnosticoLoading}
                >
                  Cerrar
                </Button>
              </div>
              <div className="document-table-wrapper diagnostico-sugerencias-table-wrap">
                <table className="document-table diagnostico-sugerencias-table">
                  <thead>
                    <tr>
                      <th>Validación</th>
                      <th>Resultado</th>
                      <th className="diagnostico-col-accion" aria-label="Detalle" />
                    </tr>
                  </thead>
                  <tbody>
                    {!diagnosticoLoading &&
                      diagnosticoRows.length === 0 && (
                        <tr>
                          <td colSpan={3}>
                            Ejecute la revisión para ver el detalle de las validaciones.
                          </td>
                        </tr>
                      )}
                    {diagnosticoRows.map((row, idx) => {
                      const fallo =
                        String(row?.resultado ?? "")
                          .trim()
                          .toUpperCase() === "FALLO";
                      return (
                        <Fragment key={`diag-${idx}`}>
                          <tr>
                            <td>{row?.validacion ?? "—"}</td>
                            <td>{row?.resultado ?? "—"}</td>
                            <td className="diagnostico-col-accion">
                              {fallo && (
                                <button
                                  type="button"
                                  className="diagnostico-ver-detalle-btn"
                                  onClick={() =>
                                    setDiagnosticoDetalleIndex(
                                      diagnosticoDetalleIndex === idx
                                        ? null
                                        : idx
                                    )
                                  }
                                >
                                  {diagnosticoDetalleIndex === idx
                                    ? "Ocultar detalle"
                                    : "Ver detalle"}
                                </button>
                              )}
                            </td>
                          </tr>
                          {diagnosticoDetalleIndex === idx && (
                            <tr className="diagnostico-detalle-row">
                              <td colSpan={3}>
                                <div className="diagnostico-detalle-block">
                                  <div className="diagnostico-detalle-label">
                                    Detalle documento
                                  </div>
                                  <pre className="diagnostico-detalle-text">
                                    {row?.detalleDocumento ?? "—"}
                                  </pre>
                                  <div className="diagnostico-detalle-label">
                                    Detalle pedimento
                                  </div>
                                  <pre className="diagnostico-detalle-text">
                                    {row?.detallePedimento ?? "—"}
                                  </pre>
                                </div>
                              </td>
                            </tr>
                          )}
                        </Fragment>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>
      )}
      <ConfirmationModal
        open={showAssociatePedimentoWarning}
        title="Confirmar asociación"
        message="Debido a que la operación que intenta asociar no se encuentra relacionada con un pedimento, los identificadores y/o permisos relacionados no se van a trasladar ¿Está seguro de continuar con la asociación?"
        confirmLabel="Continuar"
        cancelLabel="Cancelar"
        onConfirm={handleConfirmAssociatePedimentoWarning}
        onCancel={handleCancelAssociatePedimentoWarning}
      />
      <ConfirmationModal
        open={showAssociateConfirm}
        title="Confirmar asociación"
        message={
          associateRequiresAfectaChoice
            ? "¿Está seguro de asociar esta operación? Indique si desea trasladar los datos del documento al pedimento o tráfico."
            : "¿Está seguro de asociar esta operación?"
        }
        confirmLabel="Asociar"
        cancelLabel="Cancelar"
        onConfirm={handleConfirmAssociate}
        onCancel={handleCancelAssociate}
      >
        {associateRequiresAfectaChoice ? (
          <RadioGroup
            name="associateAfectaOperacion"
            options={associateAfectaOperacionOptions}
            value={pendingAfectaOperacion ? "true" : "false"}
            onChange={(value) => setPendingAfectaOperacion(value === "true")}
          />
        ) : null}
      </ConfirmationModal>
      <ConfirmationModal
        open={showDeleteConfirm}
        title="Confirmar eliminación"
        message={
          documentToDelete && (documentToDelete.idEstatus === 5 || documentToDelete.idEstatus === 6)
            ? "Tome en cuenta que eliminar este documento no disvincula los datos enviados a la operación asociada ¿Desea continuar con la baja del documento?"
            : "¿Deseas eliminar este documento?"
        }
        confirmLabel="Eliminar"
        cancelLabel="Cancelar"
        onConfirm={handleConfirmDelete}
        onCancel={handleCancelDelete}
      />
      <ConfirmationModal
        open={showDeleteAsociacionConfirm}
        title="Confirmar eliminación de asociación"
        message={
          asociacionToDelete
            ? `¿Eliminar la asociación a la referencia ${asociacionToDelete.id_referencia ?? ""}${
                asociacionToDelete.id_rectificacion != null &&
                asociacionToDelete.id_rectificacion !== ""
                  ? ` (rectificación ${asociacionToDelete.id_rectificacion})`
                  : ""
              }? Se anulará el archivo en eDOCS. Esta acción no se puede deshacer.`
            : "¿Eliminar esta asociación de operación?"
        }
        confirmLabel="Eliminar"
        cancelLabel="Cancelar"
        loading={deleteAsociacionLoading}
        loadingMessage="Eliminando asociación..."
        onConfirm={handleConfirmDeleteAsociacion}
        onCancel={handleCancelDeleteAsociacion}
      />
      <AlertModal
        open={showAssociateTransferAlert}
        title={associateTransferAlertTitle}
        message={associateTransferAlertMessage}
        variant={associateTransferAlertVariant}
        multiline
        wide
        confirmLabel="Aceptar"
        onClose={() => setShowAssociateTransferAlert(false)}
      />
      <VucemMensajeModal
        open={showVucemMensajeModal}
        mensaje={vucemMensajeText}
        onClose={handleCloseVucemMensajeModal}
      />
    </div>
  );
}
