# Eliminar asociación de operación — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir eliminar una operación asociada a un documento cuando el pedimento no está pagado y no hay eDocument válido ni número de operación VUCEM, actualizando `Tb_Archivos` a estatus 0 y borrando `ad_documento_operacion` + `ad_rel_documento_edoc`.

**Architecture:** Nuevo endpoint `POST api/Documentos/EliminarAsociacionOperacion` en `DocumentosController`. Orquesta validaciones (ADUASIS pago + lectura eDocument/`Numero` existente) y mutaciones vía `IDesarrolloDb_DbContextServices` + `IEDOCS_DbContextServices`. El front agrega botón por fila en el modal de asociación con confirmación.

**Tech Stack:** ASP.NET Core 8, EF Core, SQL Server (DesarrolloDB / ADUASIS / EDOCS), React 18 + Vite, VModels DTOs.

## Global Constraints

- No revertir transferencia de datos al pedimento.
- No cambiar `AdDocumentos.IdEstatus`.
- No renombrar/borrar archivo en File Storage.
- Bloqueo VUCEM: solo eDocument válido o `Numero` (el `Mensaje` solo no bloquea).
- Bloqueo pago: `fecha_pago_banco IS NOT NULL`.
- Mensajes al usuario en español; respuesta `GenericResponse<T>`.
- No codificar hasta que este plan esté revisado/aprobado por el usuario.

**Spec:** [decisiones-negocio.md](./decisiones-negocio.md)

---

## File map (previsto)

| Archivo | Rol |
|---------|-----|
| `docs/eliminar-asociacion-operacion/SQL/` | Scripts de soporte (consulta pago, UPDATE Tb_Archivos) |
| `src/.../VModels/EliminarAsociacionOperacionRequest.cs` | Request body `data` |
| `src/.../VModels/AdEventos.cs` | Nuevo evento bitácora |
| `src/.../Api/Services/Aduasis/*` | Consulta `fecha_pago_banco` |
| `src/.../Api/Services/EDOCS/*` | `UPDATE` estatus archivo = 0 |
| `src/.../Api/Services/DesarrolloDb/*` | DELETE operación + `ad_rel` |
| `src/.../Api/Controllers/DocumentosController.cs` | Endpoint |
| `src/.../Web/src/services/documentosService.js` | Cliente HTTP |
| `src/.../Web/src/constants/adVucemEnvio.js` (o helper nuevo) | `puedeEliminarAsociacionOperacion` |
| `src/.../Web/src/pages/DocumentRepositoryListPage.jsx` | Botón + confirmación |
| `docs/README.md` | Enlace al índice de esta carpeta |

---

### Task 0: Confirmar columna de estatus en `Tb_Archivos` y script SQL de pago

**Files:**
- Create: `docs/eliminar-asociacion-operacion/SQL/00-descubrir-columna-estatus-Tb_Archivos.sql`
- Create: `docs/eliminar-asociacion-operacion/SQL/01-csp_Ad_GetFechaPagoBancoByReferencia.sql` (nombre final alineado al patrón `csp_Ad_*`)

**Interfaces:**
- Produces: nombre exacto de columna estatus en `EDOCS.dbo.Tb_Archivos` (documentado en comentario del script 00 y en este plan tras ejecución).
- Produces: SP o consulta reutilizable que, dados `@idReferencia` y `@idRectificacion`, devuelve `fecha_pago_banco` (o null).

- [ ] **Step 1: Descubrir columna de estatus (solo lectura)**

Ejecutar en EDOCS (MCP o SSMS):

```sql
SELECT c.COLUMN_NAME, c.DATA_TYPE
FROM EDOCS.INFORMATION_SCHEMA.COLUMNS c
WHERE c.TABLE_NAME = 'Tb_Archivos'
  AND (
    c.COLUMN_NAME LIKE '%status%'
    OR c.COLUMN_NAME LIKE '%estatus%'
    OR c.COLUMN_NAME LIKE '%Estatus%'
    OR c.COLUMN_NAME LIKE '%activo%'
  )
ORDER BY c.COLUMN_NAME;
```

Documentar el nombre real (hipótesis frecuente: `Estatus` o `Id_Estatus`). **No asumir** hasta confirmar.

- [ ] **Step 2: Definir UPDATE de baja lógica**

Ejemplo (ajustar nombre de columna tras Step 1):

```sql
-- Pseudocódigo; sustituir {EstatusCol} por el nombre real
UPDATE EDOCS.dbo.Tb_Archivos
SET {EstatusCol} = 0
WHERE Id_Archivo = @idArchivo;
```

- [ ] **Step 3: Script / SP de fecha de pago**

Reutilizar la misma fuente que `csp_Ad_SugerenciaPedimentos_v2` (`fecha_pago_banco` en pedimento ADUASIS). El SP debe recibir referencia (+ rectificación opcional) y devolver una fila con `FechaPagoBanco` nullable.

Criterio de implementación C#:

- Si el SP no encuentra pedimento → `BadRequest` con mensaje claro (“No se pudo validar el pago del pedimento”).
- Si `FechaPagoBanco IS NOT NULL` → `BadRequest` (“El pedimento ya está pagado; no se puede eliminar la asociación”).
- Si `FechaPagoBanco IS NULL` → permitir continuar.

- [ ] **Step 4: Guardar scripts en `SQL/` y anotar el nombre de columna en el README de la carpeta**

---

### Task 1: VModels + evento de bitácora

**Files:**
- Create: `src/Aduax.AuditorDocumentos.VModels/EliminarAsociacionOperacionRequest.cs`
- Modify: `src/Aduax.AuditorDocumentos.VModels/AdEventos.cs`

**Interfaces:**
- Produces: `EliminarAsociacionOperacionRequest` con `IdDocumento`, `IdReferencia`, `IdRectificacion` (nullable).
- Produces: `AdEventos.DOC_DESASOCIADO_OPERACION = 16` (siguiente entero libre tras `DOC_ACTUALIZACION_DATOS = 15`).

- [ ] **Step 1: Crear request**

```csharp
namespace Aduax.AuditorDocumentos.VModels
{
    public class EliminarAsociacionOperacionRequest
    {
        public long IdDocumento { get; set; }
        public string IdReferencia { get; set; } = string.Empty;
        public int? IdRectificacion { get; set; }
    }
}
```

- [ ] **Step 2: Extender enum**

```csharp
DOC_ACTUALIZACION_DATOS = 15,
DOC_DESASOCIADO_OPERACION = 16
```

Si existe catálogo BD de eventos (`ad_eventos` o similar), agregar script de alta del valor 16 en `docs/eliminar-asociacion-operacion/SQL/`.

- [ ] **Step 3: Compilar VModels**

Run: `dotnet build src/Aduax.AuditorDocumentos.VModels/Aduax.AuditorDocumentos.VModels.csproj`  
Expected: 0 errores.

---

### Task 2: Capa de datos — pago, baja eDOCS, delete operación/rel

**Files:**
- Modify: `src/.../Services/Aduasis/IAduasisDbContextServices.cs` + implementación (o DesarrolloDb si el SP vive en DesarrolloDB y hace linked query a ADUASIS — preferir el contexto donde se ejecute el SP del Task 0).
- Modify: `src/.../Services/EDOCS/IEDOCS_DbContextServices.cs` + `EDOCS_DbContextServices.cs`
- Modify: `src/.../Services/DesarrolloDb/IDesarrolloDb_DbContextServices.cs` + `DesarrolloDb_DbContextServices.cs`
- Create (si aplica): entidad keyless resultado del SP de pago en `Data/Aduasis/` o `Data/DesarrolloDB/`

**Interfaces:**
- Produces: `Task<DateTime?> GetFechaPagoBancoByReferenciaAsync(string idReferencia, decimal? idRectificacion)`
- Produces: `Task AnularArchivoEdocsAsync(int idArchivo)` → `UPDATE Tb_Archivos SET {Estatus}=0`
- Produces: `Task EliminarDocumentoOperacionAsync(long idDocumento, string idReferencia, decimal? idRectificacion)`
- Produces: `Task EliminarRelDocumentoEdocPorArchivoAsync(long idDocumento, int idArchivo)` (o por `idRel`)

- [ ] **Step 1: Implementar consulta de pago** usando el SP/script del Task 0.

- [ ] **Step 2: Implementar `AnularArchivoEdocsAsync`**

```csharp
// Ejemplo; sustituir Estatus por columna confirmada
await _context.Database.ExecuteSqlRawAsync(
    "UPDATE EDOCS.dbo.Tb_Archivos SET Estatus = 0 WHERE Id_Archivo = {0}",
    idArchivo);
```

- [ ] **Step 3: Implementar deletes en DesarrolloDB**

1. Localizar `AdDocumentoOperacion` por `IdDocumento` + `id_referencia` + `id_rectificacion` (si hay duplicados históricos, eliminar **todas** las filas que coincidan con esa clave de negocio, o solo la del `Id` enviado — **decisión de implementación:** eliminar todas las filas con misma clave documento+referencia+rectificación para limpiar duplicados de re-asociación).
2. Resolver `AdRelDocumentoEdoc` con `GetRelDocumentoEdocPorOperacionAsync` (mejorar con `ORDER BY Id DESC` si aún es `FirstOrDefault` sin orden, o eliminar todas las `ad_rel` del documento cuyo `Id_Archivo` tenga `Tb_Archivos.Referencia` = referencia eDOCS de la operación).
3. Orden sugerido de mutación:
   1. Validaciones (sin mutar).
   2. `AnularArchivoEdocsAsync(idArchivo)`.
   3. `DELETE ad_rel_documento_edoc`.
   4. `DELETE ad_documento_operacion`.
   5. Bitácora.

- [ ] **Step 4: Compilar API**

Run: `dotnet build src/Aduax.AuditorDocumentos.Api/Aduax.AuditorDocumentos.Api.csproj`  
Expected: 0 errores.

---

### Task 3: Endpoint `EliminarAsociacionOperacion`

**Files:**
- Modify: `src/Aduax.AuditorDocumentos.Api/Controllers/DocumentosController.cs`

**Interfaces:**
- Consumes: request `GenericAdRequest<EliminarAsociacionOperacionRequest>`
- Produces: `ActionResult<GenericResponse<bool>>`
- Reutiliza: `GetDocumentoOperacionesConEdocumentAsync` / misma lógica que `OperacionPendienteEnvioVucemAsync` pero **solo** bloqueo por eDocument válido o `Numero` (no por `Mensaje`).

Helper sugerido en servicio (evitar duplicar UI rules):

```csharp
// true = se puede eliminar respecto a VUCEM
bool PuedeEliminarRespectoVucem(string? edocument, string? numero)
{
    var edoc = (edocument ?? string.Empty).Trim();
    var num = (numero ?? string.Empty).Trim();
    if (!string.IsNullOrEmpty(num)) return false;
    if (!string.IsNullOrEmpty(edoc) && edoc != "0000000000000") return false;
    return true;
}
```

- [ ] **Step 1: Agregar acción HTTP POST**

Firma:

```csharp
[HttpPost("EliminarAsociacionOperacion")]
public async Task<ActionResult<GenericResponse<bool>>> EliminarAsociacionOperacion(
    [FromBody] GenericAdRequest<EliminarAsociacionOperacionRequest> request)
```

Flujo:

1. Validar `IdCliente` / `Data` / `IdDocumento` / `IdReferencia` / usuario token.
2. Verificar que existe la operación.
3. `GetFechaPagoBanco...` → si pagado, 400.
4. Cargar eDocument/`Numero` de la operación → si no `PuedeEliminarRespectoVucem`, 400 (“La operación ya tiene eDocument o número de operación VUCEM”).
5. Resolver `idArchivo` vía `GetRelDocumentoEdocPorOperacionAsync`. Si no hay `ad_rel`/`IdArchivo`, decidir: fallar con mensaje o eliminar solo operación (recomendado: **fallar** si se espera siempre rel tras asociación normal; si datos legacy sin rel, eliminar solo operación y bitácora — documentar en mensaje).
6. Anular archivo eDOCS → delete `ad_rel` → delete operación → bitácora `DOC_DESASOCIADO_OPERACION`.
7. `Ok` con `Success = true`, `Data = true`.

- [ ] **Step 2: Compilar y probar en Swagger** con token Bearer (caso OK, caso pagado, caso con eDocument).

---

### Task 4: Front — servicio, helper de visibilidad, UI

**Files:**
- Modify: `src/Aduax.AuditorDocumentos.Web/src/services/documentosService.js`
- Modify: `src/Aduax.AuditorDocumentos.Web/src/constants/adVucemEnvio.js` (agregar `puedeEliminarAsociacionOperacion`)
- Modify: `src/Aduax.AuditorDocumentos.Web/src/pages/DocumentRepositoryListPage.jsx`
- Modify (si aplica): CSS del botón en la misma página / `associate-operation-actions`

**Interfaces:**
- Produces: `documentosService.eliminarAsociacionOperacion(payload)`
- Produces: `puedeEliminarAsociacionOperacion(operation)` → sin `numero` y sin eDocument válido (ignora `mensaje` para el botón; el pago lo valida solo el API).

- [ ] **Step 1: Helper**

```javascript
export function puedeEliminarAsociacionOperacion(operation) {
  const edoc = (operation?.edocument ?? "").trim();
  const numero = (operation?.numero ?? "").trim();
  if (numero) return false;
  if (edoc && edoc !== EDOCUMENT_PENDIENTE) return false;
  return true;
}
```

Nota: el botón puede mostrarse aunque el pedimento esté pagado; el API devolverá error. Opcional futuro: exponer flag de pago en el listado. Fuera de alcance v1 salvo que se agregue campo en el SP de operaciones.

- [ ] **Step 2: Servicio**

`POST /api/Documentos/EliminarAsociacionOperacion` con `{ idCliente, idTipoDocumentoVucem, data: { idDocumento, idReferencia, idRectificacion } }`.

- [ ] **Step 3: UI**

En la columna Acción de “Pedimentos asociados”:

- Mostrar botón eliminar si `puedeEliminarAsociacionOperacion(operation) && canManageDocuments`.
- `ConfirmationModal`: “¿Eliminar la asociación a la referencia {id}? Se anulará el archivo en eDOCS. Esta acción no se puede deshacer.”
- On confirm → llamar servicio → toast → `refreshAssociateOperations()`.

- [ ] **Step 4: Probar manualmente**

1. Asociación sin envío VUCEM → eliminar OK; fila desaparece; `Tb_Archivos.estatus = 0`; sin `ad_rel`.
2. Con eDocument o `Numero` → botón oculto o API 400.
3. Pedimento pagado → API 400 con mensaje de pago.

---

### Task 5: Documentación índice + cierre

**Files:**
- Modify: `docs/README.md` (enlace a esta carpeta)
- Modify: `docs/eliminar-asociacion-operacion/README.md` (estado → implementado cuando aplique)

- [ ] **Step 1: Enlazar desde `docs/README.md`**
- [ ] **Step 2: Actualizar estado del README de la feature tras merge/QA**

---

## Orden de ejecución

0 → 1 → 2 → 3 → 4 → 5

## Criterios de aceptación

| # | Criterio |
|---|----------|
| 1 | Usuario puede eliminar asociación desde el modal si no hay eDocument válido ni `Numero` |
| 2 | Pedimento con `fecha_pago_banco` no nula → no elimina |
| 3 | Tras OK: sin fila en `ad_documento_operacion` (esa clave), sin `ad_rel` de ese archivo, `Tb_Archivos` en estatus 0 |
| 4 | Documento Auditor conserva estatus; no se revierte transferencia a pedimento |
| 5 | Bitácora registra desasociación |
| 6 | Front no llama a VucemApi ni File Storage para esta acción |

## Riesgos / notas

- Nombre exacto de columna estatus en `Tb_Archivos` **pendiente Task 0**.
- Duplicados históricos de asociación: el plan recomienda limpiar todas las filas de la misma clave documento+referencia+rectificación.
- `GetRelDocumentoEdocPorOperacionAsync` sin `ORDER BY Id DESC` puede ser ambiguo si hay varias `ad_rel`; alinear con el SP (`ORDER BY ed.Id DESC`) al implementar.
