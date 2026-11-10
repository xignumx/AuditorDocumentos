import { Navigate, useLocation } from "react-router-dom";
import LoadingPanel from "./LoadingPanel";

/**
 * Restringe una ruta a usuarios con permiso. Mientras se consultan los permisos
 * muestra el panel de carga; sin permiso redirige al repositorio conservando `?token=`.
 */
export default function RequirePermission({ allowed, loaded, children }) {
  const location = useLocation();

  if (!loaded) {
    return <LoadingPanel show message="Validando permisos..." />;
  }

  if (!allowed) {
    return <Navigate to={`/repositorio${location.search || ""}`} replace />;
  }

  return children;
}
