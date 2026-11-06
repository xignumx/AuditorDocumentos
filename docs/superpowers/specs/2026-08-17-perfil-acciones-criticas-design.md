# Spec — Perfil del motor para acciones críticas

**Fecha:** 2026-08-17  
**Estado:** implementado — ver `docs/superpowers/plans/2026-08-17-perfil-acciones-criticas.md`.  
**Enfoque:** reutilizar `ad_motor_config_header.PerfilCarga` (`G` / `A` / `L`); no hay `ALTER` de columna.

## Objetivo

El perfil configurado en el motor **no restringe el alta** de documentos. Cualquier usuario autenticado puede cargar. El perfil **sí restringe las acciones críticas** sobre documentos ya existentes: autorizar, rechazar, eliminar, relacionar operación y eliminar asociación.

## Fuera de alcance

- Acceso a `/config` (`ValidaUsuarioAdminLider` / `EsUsuarioAdminLider` con ADM, LIDER, CALIDAD).
- Consulta de repositorio, detalle y visualización de PDF.
- Envío VUCEM.
- Renombrar la columna `PerfilCarga`.
- Cambiar valores persistidos (`G` / `A` / `L`) ni el default de motores existentes (`G`).

## Matriz

`IdClase` sale de `fusuario` (ADUASIS). `CALIDAD` y cualquier otra clase se tratan como “otro”.

| Perfil motor | Alta | Autorizar / Rechazar / Eliminar documento / Relacionar operación / Eliminar asociación |
|--------------|------|----------------------------------------------------------------------------------------|
| Acceso general (`G`) | Todos | Todos |
| Admin (`A`) | Todos | Solo `ADM` |
| Líder (`L`) | Todos | Solo `LIDER` |

ADM no ejecuta acciones críticas en un motor `L`. LIDER no las ejecuta en un motor `A`.

Si **no existe** fila real de motor para `IdCliente` + `IdTipoDocumentoVucem`, las acciones críticas se **deniegan**. No usar `GetMotorConfigHeaderConDetalleAsync` para esta validación: ese método inventa un header sintético con `PerfilCarga = G` cuando no hay registro.

## Componentes

### 1. Regla compartida — `AdPerfilCargaMotor`

**Archivo:** `src/Aduax.AuditorDocumentos.VModels/AdPerfilCargaMotor.cs`

- Actualizar el comentario de clase: el perfil aplica a acciones críticas, no al alta.
- Renombrar `UsuarioPuedeCargar` → `UsuarioPuedeAccionCritica`.
- La lógica del `switch` no cambia (`A` → ADM, `L` → LIDER, `_` → true).
- Conservar `EsValorValido` y `Normalizar`.

### 2. API — quitar bloqueo de alta

**Archivo:** `src/Aduax.AuditorDocumentos.Api/Controllers/DocumentosController.cs`

Eliminar llamadas a `ValidarPerfilCargaAltaAsync` en:

- `POST /api/Documentos/ExtraDatosDocumentoIa`
- `POST /api/Documentos/PreguardaDocumento`
- `POST /api/Documentos/GuardaDocumentoPendienteAprobacion`

Eliminar el helper `ValidarPerfilCargaAltaAsync` y el mensaje `MensajePerfilCargaDenegado` de alta.

### 3. API — validar acciones críticas

Nuevo helper en el mismo controller, p. ej. `ValidarPerfilAccionCriticaAsync<T>(idCliente, idTipoDocumentoVucem, usuario)`:

1. `ExistsMotorConfigHeaderAsync` → si no existe, 403.
2. Leer `PerfilCarga` persistido (consulta ligera; no el header sintético).
3. `GetUsuarioPorUsuauarioAsync` → `IdClase`.
4. Si `!UsuarioPuedeAccionCritica(...)`, 403 con mensaje:  
   `"Su perfil no tiene permiso para realizar esta acción según la configuración del motor."`

Invocar el helper **después** de cargar el documento (cuando aplique), usando `documento.IdCliente` y `documento.IdTipoDocumentoVucem` (no confiar solo en el `IdCliente` del request).

Endpoints:

| Endpoint | Origen del motor |
|----------|------------------|
| `POST /api/Documentos/AutorizaDocumento` | Documento por `request.Data` (id) |
| `POST /api/Documentos/RechazarDocumento` | Documento por `request.Data.IdDocumento` |
| `POST /api/Documentos/EliminarDocumento` | Documento por `request.Data` (id) |
| `POST /api/Documentos/AltaAsociacionOperacion` | Documento por `request.Data.IdDocumento` |
| `POST /api/Documentos/EliminarAsociacionOperacion` | Documento por `request.Data.IdDocumento` |

### 4. API — listado con flag por fila

**Archivos:**

- `src/Aduax.AuditorDocumentos.Api/Data/DesarrolloDB/CspAdDocumentosPorEstatus.cs`
- `src/Aduax.AuditorDocumentos.Api/Controllers/DocumentosController.cs` (`ObtenerDocumentos`)
- `src/Aduax.AuditorDocumentos.Api/Services/DesarrolloDb/` (método nuevo de perfiles)

No modificar el SP `csp_Ad_DocumentosPorEstatus`.

- Agregar en `CspAdDocumentosPorEstatus`:  
  `[NotMapped] public bool PuedeAccionCritica { get; set; }`
- Tras el SP, en C#:
  1. Obtener `IdClase` del usuario autenticado (una vez).
  2. Consultar `PerfilCarga` de motores del cliente para los `IdTipoDocumentoVucem` distintos de la lista.
  3. Por fila: `PuedeAccionCritica = UsuarioPuedeAccionCritica(perfil, idClase)` si hay motor; si no hay motor, `false`.

JSON: `puedeAccionCritica` (camelCase, igual que el resto del listado).

Método de servicio sugerido:  
`Task<Dictionary<int, string>> GetPerfilesCargaPorClienteAsync(string idCliente, IReadOnlyCollection<int> idTiposDocumentoVucem)`  
→ mapa `IdTipoDocumentoVucem` → `PerfilCarga` solo de filas reales.

### 5. API — endpoint de prechequeo de alta

Eliminar consumidores y el endpoint `POST /api/MotorConfig/ValidaPerfilCargaDocumento` (controller + `motorConfigService.validaPerfilCargaDocumento`). El listado lleva el flag; cada acción crítica se valida en su endpoint.

### 6. Front — alta

**Archivo:** `src/Aduax.AuditorDocumentos.Web/src/pages/DocumentRepositoryCreatePage.jsx`

- Quitar llamada a `validaPerfilCargaDocumento`.
- Quitar estado `canCargarDocumento` y su uso en `isSaveEnabled`.
- Seguir exigiendo `hasMotorConfig === true` para habilitar guardado.
- Quitar el alert “Perfil no autorizado” de carga.

### 7. Front — repositorio

**Archivo:** `src/Aduax.AuditorDocumentos.Web/src/pages/DocumentRepositoryListPage.jsx`

- Dejar de usar `validaUsuarioAdminLider` / `canManageDocuments` para estas acciones.
- Usar `item.puedeAccionCritica` (y el mismo valor del documento abierto en modales) para:
  - Autorizar / Aprobar
  - Rechazar
  - Eliminar documento
  - Relacionar con operación (hoy el botón no usa `canManageDocuments`; debe usarlo)
  - Eliminar asociación
- Ver / detalle / PDF no se ocultan por perfil.
- `canManageDocuments` no debe quedar como permiso de página para esto. El acceso a `/config` en `AppHeader.jsx` sigue con `validaUsuarioAdminLider`.

**Archivo:** `src/Aduax.AuditorDocumentos.Web/src/services/documentosService.js`  
Agregar `puedeAccionCritica` al typedef `CspAdDocumentosPorEstatus`.

### 8. Front — configuración

**Archivos:**

- `src/Aduax.AuditorDocumentos.Web/src/constants/adPerfilCargaMotor.js`
- `src/Aduax.AuditorDocumentos.Web/src/pages/ConfigurationsPage.jsx`

Copy:

- Título de sección: **Perfil para acciones críticas**
- Opciones: Acceso general / Admin / Líder (quitar “Solo”, porque el alta ya no es exclusivo)

Persistencia: sigue enviando `perfilCarga` `G` / `A` / `L`.

### 9. Documentación de producto

Actualizar `docs/ajustes-perfil-carga-motor/`:

- README: objetivo y tabla de casos (alta siempre sí; acciones críticas según perfil).
- `decisiones-negocio.md`: alcance = acciones críticas; alta libre; incluir rechazar y eliminar asociación.
- `guia-implementacion.md`: código relacionado (helper nuevo, flag de listado, sin validación de alta).
- Comentarios del SQL: el valor restringe acciones críticas, no la carga.

No hace falta un script SQL nuevo si la columna ya existe o se aplica el `01` actual.

## Errores

| Caso | HTTP | Mensaje |
|------|------|---------|
| Usuario autenticado sin permiso de perfil | 403 | `Su perfil no tiene permiso para realizar esta acción según la configuración del motor.` |
| No hay motor persistido para el documento | 403 | El mismo mensaje (no revelar detalle interno en UI) |
| No autenticado | 401 | El flujo actual de token |

La UI deja visibles los botones de acción crítica y los **deshabilita** si `puedeAccionCritica === false`. El 403 cubre llamadas directas al API.

## Pruebas

No hay proyecto de tests en la solución. Verificar a mano (o con llamadas API) esta matriz:

| Motor | Usuario | Alta | Autorizar / Rechazar / Eliminar / Relacionar / Quitar asociación | Ver listado |
|-------|---------|------|-------------------------------------------------------------------|-------------|
| G | cualquiera | Sí | Sí | Sí |
| A | ADM | Sí | Sí | Sí |
| A | LIDER | Sí | No | Sí |
| A | CALIDAD / otro | Sí | No | Sí |
| L | LIDER | Sí | Sí | Sí |
| L | ADM | Sí | No | Sí |
| L | CALIDAD / otro | Sí | No | Sí |
| (sin motor) | cualquiera | Alta bloqueada por “no hay motor”, no por perfil | No | N/A |

## Comentario de entidad

Actualizar XML doc de `AdMotorConfigHeader.PerfilCarga`: perfil para acciones críticas, no “mínimo para alta”.
