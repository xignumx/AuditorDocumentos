import { NavLink, useLocation } from "react-router-dom";
import { PaginatedSelect } from "../components";
import { motorConfigService } from "../services";
import "./AppHeader.css";

const SettingsIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <circle cx="12" cy="12" r="3" />
    <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09a1.65 1.65 0 0 0-1-1.51 1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09a1.65 1.65 0 0 0 1.51-1 1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33h0A1.65 1.65 0 0 0 9 3.09V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51h0a1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82v0a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
  </svg>
);

const SparkIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M12 3l1.9 5.1L19 10l-5.1 1.9L12 17l-1.9-5.1L5 10l5.1-1.9z" />
    <path d="M19 15l.9 2.1L22 18l-2.1.9L19 21l-.9-2.1L16 18l2.1-.9z" />
  </svg>
);

const ShieldIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
    <polyline points="9 12 11 14 15 10" />
  </svg>
);

const ListIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <line x1="8" y1="6" x2="21" y2="6" />
    <line x1="8" y1="12" x2="21" y2="12" />
    <line x1="8" y1="18" x2="21" y2="18" />
    <line x1="3" y1="6" x2="3.01" y2="6" />
    <line x1="3" y1="12" x2="3.01" y2="12" />
    <line x1="3" y1="18" x2="3.01" y2="18" />
  </svg>
);

const UploadIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
    <polyline points="17 8 12 3 7 8" />
    <line x1="12" y1="3" x2="12" y2="15" />
  </svg>
);

const BellIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
    <path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 7h18s-3 0-3-7" />
    <path d="M13.73 21a2 2 0 0 1-3.46 0" />
  </svg>
);

export default function AppHeader({
  selectedClient,
  onClientChange,
  canAccessConfig = false,
  canAccessCompliance = false,
}) {
  const location = useLocation();
  const search = location.search || "";

  return (
    <header className="app-header">
      <div className="app-header-nav">
        <NavLink
          to={`/config${search}`}
          end
          className={({ isActive }) =>
            `oc-link-btn app-header-link ${
              !canAccessConfig ? "disabled" : ""
            } ${isActive ? "active" : ""}`
          }
          onClick={(event) => {
            if (!canAccessConfig) {
              event.preventDefault();
            }
          }}
        >
          <SettingsIcon />
          <span>Config. documentos</span>
        </NavLink>
        {canAccessCompliance && (
          <NavLink
            to={`/config/ia-rules${search}`}
            className={({ isActive }) =>
              `oc-link-btn app-header-link ${isActive ? "active" : ""}`
            }
          >
            <SparkIcon />
            <span>Reglas IA</span>
          </NavLink>
        )}
        {canAccessCompliance && (
          <NavLink
            to={`/config/compliance${search}`}
            className={({ isActive }) =>
              `oc-link-btn app-header-link ${isActive ? "active" : ""}`
            }
          >
            <ShieldIcon />
            <span>Compliance</span>
          </NavLink>
        )}
        <NavLink
          to={`/repositorio${search}`}
          end
          className={({ isActive }) =>
            `oc-link-btn app-header-link ${isActive ? "active" : ""}`
          }
        >
          <ListIcon />
          <span>Repo. documentos</span>
        </NavLink>
        <NavLink
          to={`/repositorio/nuevo${search}`}
          className={({ isActive }) =>
            `oc-link-btn app-header-link ${isActive ? "active" : ""}`
          }
        >
          <UploadIcon />
          <span>Alta documento</span>
        </NavLink>
        <NavLink
          to={`/notificaciones${search}`}
          className={({ isActive }) =>
            `oc-link-btn app-header-link ${isActive ? "active" : ""}`
          }
        >
          <BellIcon />
          <span>Config. notificaciones</span>
        </NavLink>
      </div>
      <div className="app-header-client inline">
        <span className="app-header-label">Cliente</span>
        <PaginatedSelect
          value={selectedClient}
          onChange={onClientChange}
          placeholder="Seleccione un cliente..."
          filterable
          loadPage={({ filter, page, size, token }) =>
            motorConfigService.obtenerClientes({ filter, page, size }, token)
          }
          getOptionValue={(item) => item?.idCliente ?? ""}
          getOptionLabel={(item) =>
            item?.idCliente && item?.razonSocial
              ? `${item.idCliente} ${item.razonSocial}`
              : ""
          }
        />
      </div>
    </header>
  );
}
