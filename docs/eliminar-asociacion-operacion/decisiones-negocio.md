# Decisiones de negocio — Eliminar asociación de operación

Fecha de acuerdo: 2026-07-27.

## 1. Alcance de la eliminación

| Objeto | Acción |
|--------|--------|
| `DesarrolloDB.dbo.ad_documento_operacion` | `DELETE` de la fila de la operación |
| `EDOCS.dbo.Tb_Archivos` | `UPDATE Status = 0` (`bit`; columna confirmada 2026-07-27) |
| `DesarrolloDB.dbo.ad_rel_documento_edoc` | `DELETE` de la(s) relación(es) del documento con ese `Id_Archivo` |

Fuera de alcance:

- No borrar físicamente el archivo en File Storage / AWS.
- No revertir identificadores/permisos transferidos al pedimento (`afectaOperacion`).
- No cambiar `AdDocumentos.IdEstatus` (ni aunque no queden operaciones).

## 2. Condiciones para permitir eliminar

### 2.1 Pedimento no pagado

Misma regla que sugerencia de pedimentos:

- Origen: ADUASIS (`fped` / pedimento de la referencia-rectificación).
- **Pagado** si `fecha_pago_banco IS NOT NULL` → **bloquear** eliminación.
- **No pagado** si `fecha_pago_banco IS NULL` (o no hay pedimento resoluble) → continuar con validación VUCEM.  
  *Nota de implementación:* si no se encuentra pedimento/fecha, el plan debe definir mensaje de error seguro (no asumir “no pagado” sin criterio explícito en código; ver plan).

### 2.2 Envío VUCEM / eDocument no llevado a cabo

Bloquear eliminación **solo** si:

- Existe **eDocument válido** (no vacío y distinto de `0000000000000`), **o**
- Existe **`Numero`** de operación en `Tb_Envios` (vía la misma lectura que el modal: `csp_Ad_GetDocumentoOperacion`).

**Sí se puede eliminar** si solo hay `Mensaje` de error de un intento fallido (sin eDocument válido ni `Numero`).

Equivalencia aproximada: eliminar permitido cuando la operación aún sería candidata a “Enviar/Reenviar” **o** cuando no hay envío exitoso; el bloqueo estricto es eDocument/`Numero`, no el `Mensaje`.

## 3. UI / UX

- Ubicación: tabla **Pedimentos asociados** del modal de asociación (`DocumentRepositoryListPage`).
- Acción por fila, con **modal de confirmación**.
- Tras éxito: refrescar listado de operaciones (`ObtenerDocumentoPorId` / refresh actual).
- Mensajes de error en español (toast / response `message`).

## 4. Autorización

- Mismo criterio que otras acciones de gestión en el repositorio (`canManageDocuments` / validación admin-líder existente en front).
- Endpoint API con `[Authorize]` como el resto de `DocumentosController`.

## 5. Bitácora

Registrar evento en bitácora del documento al eliminar (nuevo valor de `AdEventos` o reutilizar si el equipo prefiere no ampliar el enum; el plan recomienda evento nuevo `DOC_DESASOCIADO_OPERACION`).

## 6. Enfoque técnico acordado

Endpoint dedicado en Auditor API + servicios DesarrolloDB / EDOCS / Aduasis (no un único SP monolítico que mezcle las tres bases sin capa C#).
