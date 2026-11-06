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
  NotificationConfigPage,
} from "./pages";
import { AppHeader } from "./components";
import "./styles/App.css";

function AppRoutes({ selectedClient }) {
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

  return (
    <BrowserRouter basename="/AuditorDocumentos">
      <div className="app-layout">
        <AppHeader
          selectedClient={selectedClient}
          onClientChange={setSelectedClient}
        />
        <div className="app-content">
          <AppRoutes selectedClient={selectedClient} />
        </div>
        <ToastContainer position="top-right" autoClose={5000} />
      </div>
    </BrowserRouter>
  );
}
