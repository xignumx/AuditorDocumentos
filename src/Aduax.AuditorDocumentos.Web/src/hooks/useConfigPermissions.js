import { useEffect, useState } from "react";
import { motorConfigService } from "../services";

const SIN_PERMISOS = {
  canAccessConfig: false,
  canAccessCompliance: false,
  loaded: false,
};

/**
 * Permisos de configuración del usuario autenticado (una sola carga para toda la app).
 * - canAccessConfig: /config por cliente (ADM, LIDER, CALIDAD, COMPLIANCE).
 * - canAccessCompliance: pantallas exclusivas de Compliance.
 * `loaded` indica que ya se consultaron ambos permisos (evita redirigir antes de tiempo).
 */
export default function useConfigPermissions() {
  const [permissions, setPermissions] = useState(SIN_PERMISOS);

  useEffect(() => {
    let cancelled = false;

    const readFlag = async (call) => {
      try {
        const response = await call();
        return Boolean(response?.success && response?.data);
      } catch (error) {
        return false;
      }
    };

    const loadPermissions = async () => {
      const [canAccessConfig, canAccessCompliance] = await Promise.all([
        readFlag(() => motorConfigService.validaUsuarioAdminLider()),
        readFlag(() => motorConfigService.validaUsuarioCompliance()),
      ]);

      if (!cancelled) {
        setPermissions({ canAccessConfig, canAccessCompliance, loaded: true });
      }
    };

    loadPermissions();

    return () => {
      cancelled = true;
    };
  }, []);

  return permissions;
}
