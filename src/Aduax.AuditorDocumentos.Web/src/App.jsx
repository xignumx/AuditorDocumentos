import { useState } from "react";
import {
  BrowserRouter,
  Navigate,
  Route,
  Routes,
  useLocation,
} from "react-router-dom";
import { ToastContainer } from "react-toastify";
import {
  ConfigurationsPage,
  DocumentRepositoryListPage,
  DocumentRepositoryCreatePage,
  IaRulesPage,
  NotificationConfigPage,
} from "./pages";
import { AppHeader, RequirePermission } from "./components";
import useConfigPermissions from "./hooks/useConfigPermissions";
import "./styles/App.css";

function AppRoutes({ selectedClient, permissions }) {
  const location = useLocation();
  const search = location.search || "";

  return (
    <Routes>
      <Route
        path="/"
        element={<Navigate to={`/repositorio${search}`} replace />}
      />
      <Route
        path="/config"
        element={<ConfigurationsPage selectedClient={selectedClient} />}
      />
      <Route
        path="/config/ia-rules"
        element={
          <RequirePermission
            allowed={permissions.canAccessCompliance}
            loaded={permissions.loaded}
          >
            <IaRulesPage />
          </RequirePermission>
        }
      />
      <Route
        path="/repositorio"
        element={<DocumentRepositoryListPage selectedClient={selectedClient} />}
      />
      <Route
        path="/repositorio/nuevo"
        element={<DocumentRepositoryCreatePage selectedClient={selectedClient} />}
      />
      <Route path="/notificaciones" element={<NotificationConfigPage selectedClient={selectedClient} />} />
      <Route
        path="*"
        element={<Navigate to={`/repositorio${search}`} replace />}
      />
    </Routes>
  );
}

export default function App() {
  const [selectedClient, setSelectedClient] = useState("");
  // Permisos de configuración: se consultan una sola vez para menú y guards de ruta.
  const permissions = useConfigPermissions();

  return (
    <BrowserRouter basename="/AuditorDocumentos">
      <div className="app-layout">
        <AppHeader
          selectedClient={selectedClient}
          onClientChange={setSelectedClient}
          canAccessConfig={permissions.canAccessConfig}
          canAccessCompliance={permissions.canAccessCompliance}
        />
        <div className="app-content">
          <AppRoutes selectedClient={selectedClient} permissions={permissions} />
        </div>
        <ToastContainer position="top-right" autoClose={5000} />
      </div>
    </BrowserRouter>
  );
}
