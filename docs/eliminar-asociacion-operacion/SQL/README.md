# SQL — Eliminar asociación de operación

**Orden de despliegue** (ejecutar en SSMS / DBA):

| # | Script | Base | Acción |
|---|--------|------|--------|
| 1 | [20260727-01 DesarrolloDB csp_Ad_GetFechaPagoBancoByRelOperacion.sql](./20260727-01%20DesarrolloDB%20csp_Ad_GetFechaPagoBancoByRelOperacion.sql) | DesarrolloDB | `CREATE PROCEDURE` consulta `fecha_pago_banco` |
| 2 | [20260727-02 EDOCS csp_Archivos_Upd_StatusAnulado.sql](./20260727-02%20EDOCS%20csp_Archivos_Upd_StatusAnulado.sql) | EDOCS | `CREATE PROCEDURE` → `Tb_Archivos.Status = 0` |
| 3 | [20260727-03 prueba…](./20260727-03%20prueba%20csp_Ad_GetFechaPagoBancoByRelOperacion.sql) | DesarrolloDB | Prueba manual del SP de pago (opcional) |
| 4 | [20260727-04 ALTER csp_Ad_GetDocumentoOperacion EstaPagado.sql](./20260727-04%20ALTER%20csp_Ad_GetDocumentoOperacion%20EstaPagado.sql) | DesarrolloDB | `CREATE OR ALTER` — agrega `EstaPagado` para ocultar botón eliminar en UI |

Columna de baja en eDOCS: **`Tb_Archivos.Status`** (`bit`) → valor `0`.

La API invoca:

- `EXEC csp_Ad_GetFechaPagoBancoByRelOperacion` (DesarrolloDB) — validación al eliminar
- `EXEC csp_Archivos_Upd_StatusAnulado` (EDOCS)
- `EXEC csp_Ad_GetDocumentoOperacion` — listado con `Edocument` / `Numero` / `Mensaje` / **`EstaPagado`**

> Los scripts **no se despliegan automáticamente**. Coordinar con DBA. Si el SP ya existe, el `20260727-04` usa `CREATE OR ALTER` (confirmado).
