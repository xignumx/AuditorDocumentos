import { useEffect, useState } from "react";
import { toast } from "react-toastify";
import { AdCampos } from "../constants/adCampos";
import { AdDocumentoClasificacion } from "../constants/adDocumentoClasificacion";
import {
  AdAccionPedimento,
  adAccionPedimentoOptions,
} from "../constants/adAccionPedimento";
import {
  AdPerfilCargaMotor,
  adPerfilCargaMotorOptions,
} from "../constants/adPerfilCargaMotor";
import { API_BASE_URL } from "../config/api";
import {
  PageHeader,
  FieldCard,
  RadioGroup,
  Button,
  VucemDocumentSelector,
  LoadingPanel,
  ConfirmationModal,
} from "../components";
import { motorConfigService } from "../services";
import "./ConfigurationsPage.css";

// Iconos SVG inline
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

const ArrowsIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <polyline points="17 1 21 5 17 9" />
    <path d="M3 11V9a4 4 0 0 1 4-4h14" />
    <polyline points="7 23 3 19 7 15" />
    <path d="M21 13v2a4 4 0 0 1-4 4H3" />
  </svg>
);

const KeyIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4" />
  </svg>
);

const BoxIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z" />
  </svg>
);

const GridIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <rect x="3" y="3" width="7" height="7" />
    <rect x="14" y="3" width="7" height="7" />
    <rect x="14" y="14" width="7" height="7" />
    <rect x="3" y="14" width="7" height="7" />
  </svg>
);

const HashIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <line x1="4" y1="9" x2="20" y2="9" />
    <line x1="4" y1="15" x2="20" y2="15" />
    <line x1="10" y1="3" x2="8" y2="21" />
    <line x1="16" y1="3" x2="14" y2="21" />
  </svg>
);

const NumberIcon = () => (
  <span style={{ fontWeight: 600, fontSize: "14px", color: "#6E6E6E" }}>123</span>
);

const RulerIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2" />
    <rect x="8" y="2" width="8" height="4" rx="1" ry="1" />
  </svg>
);

const GlobeIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <circle cx="12" cy="12" r="10" />
    <line x1="2" y1="12" x2="22" y2="12" />
    <path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" />
  </svg>
);

const CalendarIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
    <line x1="16" y1="2" x2="16" y2="6" />
    <line x1="8" y1="2" x2="8" y2="6" />
    <line x1="3" y1="10" x2="21" y2="10" />
  </svg>
);

const CalendarCheckIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
    <line x1="16" y1="2" x2="16" y2="6" />
    <line x1="8" y1="2" x2="8" y2="6" />
    <line x1="3" y1="10" x2="21" y2="10" />
    <path d="M9 16l2 2 4-4" />
  </svg>
);

const BuildingIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <rect x="4" y="2" width="16" height="20" rx="2" ry="2" />
    <path d="M9 22v-4h6v4" />
    <line x1="8" y1="6" x2="8" y2="6" />
    <line x1="12" y1="6" x2="12" y2="6" />
    <line x1="16" y1="6" x2="16" y2="6" />
    <line x1="8" y1="10" x2="8" y2="10" />
    <line x1="12" y1="10" x2="12" y2="10" />
    <line x1="16" y1="10" x2="16" y2="10" />
    <line x1="8" y1="14" x2="8" y2="14" />
    <line x1="12" y1="14" x2="12" y2="14" />
    <line x1="16" y1="14" x2="16" y2="14" />
  </svg>
);

const FolderIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z" />
  </svg>
);

const CloseIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <circle cx="12" cy="12" r="10" />
    <line x1="15" y1="9" x2="9" y2="15" />
    <line x1="9" y1="9" x2="15" y2="15" />
  </svg>
);

const CheckIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
    <polyline points="22 4 12 14.01 9 11.01" />
  </svg>
);

const WarningIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
    <line x1="12" y1="9" x2="12" y2="13" />
    <line x1="12" y1="17" x2="12.01" y2="17" />
  </svg>
);

// Opciones de clasificación
const classificationOptions = [
  { value: AdDocumentoClasificacion.IdentificadorGeneral, label: "Identificador General" },
  { value: AdDocumentoClasificacion.IdentificadorPartida, label: "Identificador Partida" },
  { value: AdDocumentoClasificacion.Permisos, label: "Permiso" },
];

// Configuración inicial de campos
const initialFields = [
  {
    id: "tipoPedimento",
    idCampo: AdCampos.TipoPedimento,
    label: "Tipo pedimento",
    icon: <ListIcon />,
    visible: true,
    obligatory: false,
  },
  {
    id: "tipoOperacion",
    idCampo: AdCampos.TipoOperacion,
    label: "Tipo de operación",
    icon: <ArrowsIcon />,
    visible: true,
    obligatory: false,
  },
  {
    id: "clavePedimento",
    idCampo: AdCampos.ClavePedimento,
    label: "Clave de pedimento",
    icon: <KeyIcon />,
    visible: true,
    obligatory: false,
  },
  {
    id: "proveedor",
    idCampo: AdCampos.Proveedor,
    label: "Proveedor",
    icon: <BuildingIcon />,
    visible: true,
    obligatory: false,
  },
  {
    id: "productoNoDeParte",
    idCampo: AdCampos.ProductoNoDeParte,
    label: "Producto/No de parte",
    icon: <BoxIcon />,
    visible: true,
    obligatory: false,
  },
  {
    id: "descripcionMercancia",
    idCampo: AdCampos.DescripcionMercancia,
    label: "Descripción de mercancía",
    icon: <ListIcon />,
    visible: true,
    obligatory: false,
  },
  {
    id: "fracciones",
    idCampo: AdCampos.Fracciones,
    label: "Fracciones",
    icon: <GridIcon />,
    visible: true,
    obligatory: false,
  },
  {
    id: "nico",
    idCampo: AdCampos.Nico,
    label: "Nico",
    icon: <HashIcon />,
    visible: true,
    obligatory: false,
  },
  {
    id: "cantidad",
    idCampo: AdCampos.Cantidad,
    label: "Cantidad",
    icon: <NumberIcon />,
    visible: true,
    obligatory: false,
  },
  {
    id: "unidadMedida",
    idCampo: AdCampos.UnidadMedidaUMT,
    label: "Unidad de medida (UMT)",
    icon: <RulerIcon />,
    visible: true,
    obligatory: false,
  },
  {
    id: "paisOrigen",
    idCampo: AdCampos.PaisOrigenDestino,
    label: "País de origen/destino",
    icon: <GlobeIcon />,
    visible: true,
    obligatory: false,
  },
  {
    id: "vigenciaDesde",
    idCampo: AdCampos.VigenciaDesde,
    label: "Vigencia desde",
    icon: <CalendarIcon />,
    visible: true,
    obligatory: false,
  },
  {
    id: "vigenciaHasta",
    idCampo: AdCampos.VigenciaHasta,
    label: "Vigencia hasta",
    icon: <CalendarCheckIcon />,
    visible: true,
    obligatory: false,
  },
  {
    id: "aduana",
    idCampo: AdCampos.Aduana,
    label: "Aduana",
    icon: <BuildingIcon />,
    visible: true,
    obligatory: false,
  },
  {
    id: "firmaDeRL",
    idCampo: AdCampos.FirmaDeRL,
    label: "Firma de Representante Legal",
    icon: <DocumentIcon />,
    visible: true,
    obligatory: false,
  },
  {
    id: "nom",
    idCampo: AdCampos.Nom,
    label: "Nom",
    icon: <ListIcon />,
    visible: true,
    obligatory: false,
  },
  {
    id: "valorComercial",
    idCampo: AdCampos.ValorComercial,
    label: "Valor Comercial",
    icon: <NumberIcon />,
    visible: true,
    obligatory: false,
  },
  {
    id: "factura",
    idCampo: AdCampos.Factura,
    label: "Factura",
    icon: <DocumentIcon />,
    visible: false,
    obligatory: false,
  },
  {
    id: "fechaFactura",
    idCampo: AdCampos.FechaFactura,
    label: "Fecha factura",
    icon: <CalendarIcon />,
    visible: false,
    obligatory: false,
  },
  {
    id: "valorUsd",
    idCampo: AdCampos.ValorUsd,
    label: "Valor USD",
    icon: <NumberIcon />,
    visible: false,
    obligatory: false,
  },
  {
    id: "guiaBl",
    idCampo: AdCampos.GuiaBl,
    label: "Guía/BL",
    icon: <BoxIcon />,
    visible: false,
    obligatory: false,
  },
  {
    id: "pedimento",
    idCampo: AdCampos.Pedimento,
    label: "Pedimento",
    icon: <KeyIcon />,
    visible: false,
    obligatory: false,
  },
];

export default function ConfigurationsPage({ selectedClient }) {
  const [selectedDocument, setSelectedDocument] = useState(null);
  const [fields, setFields] = useState(initialFields);
  const [classification, setClassification] = useState(
    AdDocumentoClasificacion.IdentificadorGeneral
  );
  const [accionPedimento, setAccionPedimento] = useState(
    AdAccionPedimento.PreguntaSiAfecta
  );
  const [perfilCarga, setPerfilCarga] = useState(AdPerfilCargaMotor.AccesoGeneral);
  const [isLoading, setIsLoading] = useState(false);
  const [showConfirmSave, setShowConfirmSave] = useState(false);
  const [motorConfigHeader, setMotorConfigHeader] = useState(null);
  const isActionsEnabled = Boolean(
    selectedClient && selectedDocument?.id_DocumentoVucem
  );
  const isConfigured = Number(motorConfigHeader?.id) > 0;
  const statusText = isConfigured
    ? "Configurado"
    : "Pendiente de configuración";

  const resetConfiguration = ({ clearSelection = false } = {}) => {
    setFields(initialFields);
    setClassification(AdDocumentoClasificacion.IdentificadorGeneral);
    setAccionPedimento(AdAccionPedimento.PreguntaSiAfecta);
    setPerfilCarga(AdPerfilCargaMotor.AccesoGeneral);
    setMotorConfigHeader(null);
    if (clearSelection) {
      setSelectedDocument(null);
    }
  };

  const loadConfiguration = async ({ clientId, documentoVucemId, keepSelection }) => {
    setIsLoading(true);
    try {
      const response = await motorConfigService.obtenerMotorConfig({
        idCliente: clientId,
        idTipoDocumentoVucem: documentoVucemId,
      });

      if (!response?.success || !response?.data) {
        throw new Error(response?.message || "No se pudo cargar la configuración.");
      }

      const {
        detalles = [],
        idClasificacion,
        accionPedimento: accionPedimentoApi,
        perfilCarga: perfilCargaApi,
      } = response.data || {};
      const detailMap = new Map(detalles.map((detail) => [detail.idCampo, detail]));

      setFields((prev) =>
        prev.map((field) => {
          const detail = detailMap.get(field.idCampo);
          if (!detail) {
            return field;
          }
          return {
            ...field,
            visible: Boolean(detail.visible),
            obligatory: Boolean(detail.obligatorio),
          };
        })
      );

      setMotorConfigHeader(response.data || null);
      setClassification(
        typeof idClasificacion === "number"
          ? idClasificacion
          : AdDocumentoClasificacion.IdentificadorGeneral
      );
      setAccionPedimento(
        adAccionPedimentoOptions.some((opt) => opt.value === accionPedimentoApi)
          ? accionPedimentoApi
          : AdAccionPedimento.PreguntaSiAfecta
      );
      setPerfilCarga(
        adPerfilCargaMotorOptions.some((opt) => opt.value === perfilCargaApi)
          ? perfilCargaApi
          : AdPerfilCargaMotor.AccesoGeneral
      );
    } catch (error) {
      toast.error(error?.message || "Ocurrió un error al cargar la configuración.");
      resetConfiguration({ clearSelection: !keepSelection });
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    if (!selectedClient) {
      setIsLoading(false);
      if (!selectedDocument) {
        resetConfiguration();
      }
      return;
    }

    if (!selectedDocument?.id_DocumentoVucem) {
      setIsLoading(false);
      resetConfiguration();
      return;
    }

    loadConfiguration({
      clientId: selectedClient,
      documentoVucemId: selectedDocument.id_DocumentoVucem,
      keepSelection: true,
    }).catch(() => {});
  }, [selectedClient, selectedDocument]);

  const handleFieldVisibleChange = (fieldId, value) => {
    setFields((prev) =>
      prev.map((field) =>
        field.id === fieldId
          ? {
              ...field,
              visible: value,
              obligatory: value ? field.obligatory : false,
            }
          : field
      )
    );
  };

  const handleFieldObligatoryChange = (fieldId, value) => {
    setFields((prev) =>
      prev.map((field) =>
        field.id === fieldId
          ? {
              ...field,
              obligatory: field.visible ? value : false,
            }
          : field
      )
    );
  };

  const handleClassificationChange = async (value) => {
    const nextValue = Number(value);
    if (Number.isNaN(nextValue) || nextValue === classification) {
      return;
    }
    if (!isConfigured || !selectedClient || !selectedDocument?.id_DocumentoVucem) {
      setClassification(nextValue);
      return;
    }
    setIsLoading(true);
    try {
      const response = await motorConfigService.puedeCambiarClasificacion({
        idCliente: selectedClient,
        idTipoDocumentoVucem: selectedDocument.id_DocumentoVucem,
        data: motorConfigHeader?.id ?? 0,
      });
      if (!response?.success) {
        throw new Error(
          response?.message || "No se pudo validar el cambio de clasificación."
        );
      }
      if (response?.data === false) {
        toast.error(
          response?.message ||
            "No se puede cambiar la clasificación porque ya existen registros relacionados con la configuración seleccionada."
        );
        return;
      }
      setClassification(nextValue);
    } catch (error) {
      toast.error(
        error?.message || "No se pudo validar el cambio de clasificación."
      );
    } finally {
      setIsLoading(false);
    }
  };

  const handleReset = () => {
    if (!selectedClient || !selectedDocument?.id_DocumentoVucem) {
      return;
    }
    loadConfiguration({
      clientId: selectedClient,
      documentoVucemId: selectedDocument.id_DocumentoVucem,
      keepSelection: true,
    }).catch(() => {});
  };

  const handleSave = () => {
    if (!isActionsEnabled) {
      return;
    }
    setShowConfirmSave(true);
  };

  const handleConfirmSave = async () => {
    setShowConfirmSave(false);
    if (!selectedClient || !selectedDocument?.id_DocumentoVucem) {
      return;
    }

    const header = motorConfigHeader || {};
    const detalles = fields.map((field) => {
      const existingDetail =
        header.detalles?.find((detail) => detail.idCampo === field.idCampo) || {};

      return {
        ...existingDetail,
        idCampo: field.idCampo,
        nombreCampo: existingDetail.nombreCampo ?? field.label,
        visible: Boolean(field.visible),
        obligatorio: Boolean(field.obligatory),
      };
    });

    const payload = {
      idCliente: selectedClient,
      idTipoDocumentoVucem: selectedDocument.id_DocumentoVucem,
      data: {
        ...header,
        idCliente: selectedClient,
        idTipoDocumentoVucem: selectedDocument.id_DocumentoVucem,
        idClasificacion: classification,
        accionPedimento,
        perfilCarga,
        detalles,
      },
    };

    setIsLoading(true);
    try {
      const response = await motorConfigService.guardarMotorConfig(payload);
      if (!response?.success) {
        throw new Error(response?.message || "No se pudo guardar la configuración.");
      }
      toast.success("Configuración guardada exitosamente.");
      await loadConfiguration({
        clientId: selectedClient,
        documentoVucemId: selectedDocument.id_DocumentoVucem,
        keepSelection: true,
      });
    } catch (error) {
      toast.error(error?.message || "Ocurrió un error al guardar la configuración.");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="configurations-page">
      <PageHeader
        icon={<DocumentIcon />}
        title="Matriz Operativa - Auditoría de Documentos"
        subtitle="Configuración de campos y validaciones"
      />

      <div className="configurations-content">
        <div className="configurations-layout">
          {/* Card lateral documento VUCEM */}
          <VucemDocumentSelector
            className="config-sidebar"
            value={selectedDocument}
            onChange={setSelectedDocument}
          />

          <div className="config-main">
            <LoadingPanel
              show={isLoading}
              message="Cargando configuración..."
            />
            <ConfirmationModal
              open={showConfirmSave}
              title="Confirmar guardado"
              message="¿Deseas guardar la configuración actual?"
              confirmLabel="Guardar"
              cancelLabel="Cancelar"
              onConfirm={handleConfirmSave}
              onCancel={() => setShowConfirmSave(false)}
            />
            {/* Grid de campos configurables */}
            <section className="fields-grid">
              {fields.map((field) => (
                <FieldCard
                  key={field.id}
                  icon={field.icon}
                  label={field.label}
                  visible={field.visible}
                  onVisibleChange={(value) =>
                    handleFieldVisibleChange(field.id, value)
                  }
                  obligatory={field.obligatory}
                  onObligatoryChange={(value) =>
                    handleFieldObligatoryChange(field.id, value)
                  }
                  disableObligatory={!field.visible}
                />
              ))}
            </section>

            {/* Clasificación y acción en pedimento */}
            <div className="config-options-row">
              <section className="config-section oc-light-card">
                <div className="section-header">
                  <FolderIcon />
                  <span className="section-title">Clasificación de documento</span>
                </div>

                <div className="classification-row">
                  <RadioGroup
                    name="classification"
                    options={classificationOptions}
                    value={classification}
                    onChange={(value) => {
                      void handleClassificationChange(value);
                    }}
                  />
                  <span
                    className={`status-badge status-badge-right ${
                      isConfigured ? "configured" : "pending"
                    }`}
                  >
                    {isConfigured ? <CheckIcon /> : <WarningIcon />}
                    {statusText}
                  </span>
                </div>
              </section>

              <section className="config-section oc-light-card">
                <div className="section-header">
                  <ArrowsIcon />
                  <span className="section-title">Acción en operación</span>
                </div>

                <RadioGroup
                  name="accionPedimento"
                  options={adAccionPedimentoOptions}
                  value={accionPedimento}
                  onChange={setAccionPedimento}
                />
              </section>

              <section className="config-section oc-light-card">
                <div className="section-header">
                  <KeyIcon />
                  <span className="section-title">Perfil para acciones críticas</span>
                </div>

                <RadioGroup
                  name="perfilCarga"
                  options={adPerfilCargaMotorOptions}
                  value={perfilCarga}
                  onChange={setPerfilCarga}
                />
              </section>
            </div>

            {/* Botones de acción */}
            <div className="config-actions">
              <Button
                variant="secondary"
                icon={<CloseIcon />}
                onClick={handleReset}
                disabled={!isActionsEnabled}
              >
                Deshacer cambios
              </Button>
              <Button
                variant="primary"
                icon={<CheckIcon />}
                onClick={handleSave}
                disabled={!isActionsEnabled}
              >
                Guardar
              </Button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
