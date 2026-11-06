# Perfil del motor para acciones críticas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** El alta de documentos queda libre para cualquier usuario autenticado; `PerfilCarga` del motor restringe autorizar, rechazar, eliminar, relacionar operación y eliminar asociación.

**Architecture:** Se reutiliza `ad_motor_config_header.PerfilCarga` (`G`/`A`/`L`). La regla vive en `AdPerfilCargaMotor.UsuarioPuedeAccionCritica`. El API valida en los cinco endpoints críticos leyendo el perfil persistido (nunca el header sintético de `GetMotorConfigHeaderConDetalleAsync`). `ObtenerDocumentos` enriquece cada fila con `puedeAccionCritica`. El front oculta botones por fila y deja de bloquear el alta.

**Tech Stack:** ASP.NET Core 8, EF Core, React + Vite, ADUASIS `fusuario.IdClase`.

## Global Constraints

- No `ALTER` de columna; no renombrar `PerfilCarga`; valores siguen `G` / `A` / `L`.
- No usar `GetMotorConfigHeaderConDetalleAsync` para esta validación (inventa header con `G` si no hay fila).
- Sin motor persistido → 403 con el mismo mensaje de denegación.
- Mensaje 403: `Su perfil no tiene permiso para realizar esta acción según la configuración del motor.`
- Acceso a `/config` (`ValidaUsuarioAdminLider`) no se toca.
- Consulta, detalle, PDF y envío VUCEM no se bloquean por perfil.
- No hay proyecto de tests en la solución; verificar con `dotnet build` y la matriz manual del spec.
- Spec: `docs/superpowers/specs/2026-08-17-perfil-acciones-criticas-design.md`.

## File map

| File | Responsibility |
|------|----------------|
| `src/Aduax.AuditorDocumentos.VModels/AdPerfilCargaMotor.cs` | Matriz G/A/L → `UsuarioPuedeAccionCritica` |
| `src/Aduax.AuditorDocumentos.Api/Data/DesarrolloDB/AdMotorConfigHeader.cs` | Comentario de `PerfilCarga` |
| `src/Aduax.AuditorDocumentos.Api/Services/DesarrolloDb/IDesarrolloDb_DbContextServices.cs` | Contratos de lectura de perfil persistido |
| `src/Aduax.AuditorDocumentos.Api/Services/DesarrolloDb/DesarrolloDb_DbContextServices.cs` | Implementación de esas lecturas |
| `src/Aduax.AuditorDocumentos.Api/Data/DesarrolloDB/CspAdDocumentosPorEstatus.cs` | Flag `[NotMapped] PuedeAccionCritica` |
| `src/Aduax.AuditorDocumentos.Api/Controllers/DocumentosController.cs` | Quitar validación de alta; validar acciones críticas; enriquecer listado |
| `src/Aduax.AuditorDocumentos.Api/Controllers/MotorConfigController.cs` | Eliminar `ValidaPerfilCargaDocumento` |
| `src/Aduax.AuditorDocumentos.Web/src/services/motorConfigService.js` | Eliminar `validaPerfilCargaDocumento` |
| `src/Aduax.AuditorDocumentos.Web/src/services/documentosService.js` | Typedef `puedeAccionCritica` |
| `src/Aduax.AuditorDocumentos.Web/src/pages/DocumentRepositoryCreatePage.jsx` | Alta sin chequeo de perfil |
| `src/Aduax.AuditorDocumentos.Web/src/pages/DocumentRepositoryListPage.jsx` | Botones por `item.puedeAccionCritica` |
| `src/Aduax.AuditorDocumentos.Web/src/constants/adPerfilCargaMotor.js` | Labels Acceso general / Admin / Líder |
| `src/Aduax.AuditorDocumentos.Web/src/pages/ConfigurationsPage.jsx` | Título “Perfil para acciones críticas” |
| `docs/ajustes-perfil-carga-motor/*` | Decisiones, README, guía, comentario SQL |

---

### Task 1: Renombrar la regla de perfil

**Files:**
- Modify: `src/Aduax.AuditorDocumentos.VModels/AdPerfilCargaMotor.cs`
- Modify: `src/Aduax.AuditorDocumentos.Api/Data/DesarrolloDB/AdMotorConfigHeader.cs`
- Modify: `src/Aduax.AuditorDocumentos.Api/Controllers/DocumentosController.cs` (solo el call site del helper actual)
- Modify: `src/Aduax.AuditorDocumentos.Api/Controllers/MotorConfigController.cs` (solo el call site de `UsuarioPuedeCargar`)

**Interfaces:**
- Consumes: constantes `AccesoGeneral` / `Admin` / `Lider` ya existentes
- Produces: `public static bool UsuarioPuedeAccionCritica(string? perfilCarga, string? idClaseUsuario)` — misma matriz que `UsuarioPuedeCargar`

- [ ] **Step 1: Actualizar `AdPerfilCargaMotor`**

Reemplazar el archivo para que quede así (conservar `EsValorValido` y `Normalizar` sin cambio de lógica):

```csharp
namespace Aduax.AuditorDocumentos.VModels
{
    /// <summary>
    /// Perfil requerido para acciones críticas (ad_motor_config_header.PerfilCarga).
    /// G=acceso general, A=admin, L=líder. El alta de documentos no usa esta regla.
    /// </summary>
    public static class AdPerfilCargaMotor
    {
        public const string AccesoGeneral = "G";
        public const string Admin = "A";
        public const string Lider = "L";

        public static bool EsValorValido(string? perfilCarga)
        {
            if (string.IsNullOrWhiteSpace(perfilCarga))
            {
                return false;
            }

            var normalized = perfilCarga.Trim().ToUpperInvariant();
            return normalized is AccesoGeneral or Admin or Lider;
        }

        public static string Normalizar(string? perfilCarga)
        {
            if (string.IsNullOrWhiteSpace(perfilCarga))
            {
                return AccesoGeneral;
            }

            var normalized = perfilCarga.Trim().ToUpperInvariant();
            return EsValorValido(normalized) ? normalized : AccesoGeneral;
        }

        /// <summary>
        /// Indica si el usuario puede ejecutar acciones críticas según PerfilCarga del motor e IdClase en ADUASIS.
        /// </summary>
        public static bool UsuarioPuedeAccionCritica(string? perfilCarga, string? idClaseUsuario)
        {
            var perfil = Normalizar(perfilCarga);
            var idClase = idClaseUsuario?.Trim() ?? string.Empty;

            return perfil switch
            {
                Admin => string.Equals(idClase, "ADM", StringComparison.OrdinalIgnoreCase),
                Lider => string.Equals(idClase, "LIDER", StringComparison.OrdinalIgnoreCase),
                _ => true
            };
        }
    }
}
```

- [ ] **Step 2: Actualizar comentario de entidad**

En `AdMotorConfigHeader.cs` reemplazar el XML de `PerfilCarga`:

```csharp
        /// <summary>
        /// Perfil para acciones críticas: G=general, A=admin, L=líder.
        /// </summary>
```

- [ ] **Step 3: Actualizar call sites para que compile**

En `DocumentosController.cs`, dentro de `ValidarPerfilCargaAltaAsync`, cambiar:

```csharp
            if (!AdPerfilCargaMotor.UsuarioPuedeAccionCritica(motor.PerfilCarga, usuarioEntity?.IdClase))
```

En `MotorConfigController.cs` `ValidaPerfilCargaDocumento`, cambiar:

```csharp
                bool puedeCargar = AdPerfilCargaMotor.UsuarioPuedeAccionCritica(
                    motor.PerfilCarga,
                    usuario?.IdClase);
```

Buscar `UsuarioPuedeCargar` en `src/` y confirmar cero resultados.

- [ ] **Step 4: Compilar**

Run:

```powershell
dotnet build src/Aduax.AuditorDocumentos.sln --no-restore
```

Si faltan paquetes, repetir con restore. Expected: `Build succeeded` / 0 errores.

- [ ] **Step 5: Commit**

```powershell
git add src/Aduax.AuditorDocumentos.VModels/AdPerfilCargaMotor.cs src/Aduax.AuditorDocumentos.Api/Data/DesarrolloDB/AdMotorConfigHeader.cs src/Aduax.AuditorDocumentos.Api/Controllers/DocumentosController.cs src/Aduax.AuditorDocumentos.Api/Controllers/MotorConfigController.cs
git commit -m "refactor: perfil del motor aplica a acciones críticas, no al alta"
```

---

### Task 2: Lectura de PerfilCarga persistido

**Files:**
- Modify: `src/Aduax.AuditorDocumentos.Api/Services/DesarrolloDb/IDesarrolloDb_DbContextServices.cs`
- Modify: `src/Aduax.AuditorDocumentos.Api/Services/DesarrolloDb/DesarrolloDb_DbContextServices.cs`

**Interfaces:**
- Consumes: `AdMotorConfigHeaders` en EF; no usa `GetMotorConfigHeaderConDetalleAsync`
- Produces:
  - `Task<string?> GetPerfilCargaPersistidoAsync(string idCliente, int idTipoDocumentoVucem)`
  - `Task<Dictionary<int, string>> GetPerfilesCargaPorClienteAsync(string idCliente, IReadOnlyCollection<int> idTiposDocumentoVucem)`

- [ ] **Step 1: Agregar contratos a la interfaz**

Insertar justo debajo de `ExistsMotorConfigHeaderAsync`:

```csharp
        Task<string?> GetPerfilCargaPersistidoAsync(string idCliente, int idTipoDocumentoVucem);
        Task<Dictionary<int, string>> GetPerfilesCargaPorClienteAsync(string idCliente, IReadOnlyCollection<int> idTiposDocumentoVucem);
```

- [ ] **Step 2: Implementar en el servicio**

Insertar justo después de `ExistsMotorConfigHeaderAsync` (el método que hace `AnyAsync` sobre `AdMotorConfigHeaders`):

```csharp
        public async Task<string?> GetPerfilCargaPersistidoAsync(string idCliente, int idTipoDocumentoVucem)
        {
            return await _context.AdMotorConfigHeaders
                .AsNoTracking()
                .Where(h => h.IdCliente == idCliente && h.IdTipoDocumentoVucem == idTipoDocumentoVucem)
                .Select(h => h.PerfilCarga)
                .FirstOrDefaultAsync();
        }

        public async Task<Dictionary<int, string>> GetPerfilesCargaPorClienteAsync(
            string idCliente,
            IReadOnlyCollection<int> idTiposDocumentoVucem)
        {
            if (idTiposDocumentoVucem == null || idTiposDocumentoVucem.Count == 0)
            {
                return new Dictionary<int, string>();
            }

            return await _context.AdMotorConfigHeaders
                .AsNoTracking()
                .Where(h => h.IdCliente == idCliente && idTiposDocumentoVucem.Contains(h.IdTipoDocumentoVucem))
                .Select(h => new { h.IdTipoDocumentoVucem, h.PerfilCarga })
                .ToDictionaryAsync(x => x.IdTipoDocumentoVucem, x => x.PerfilCarga);
        }
```

`using Microsoft.EntityFrameworkCore` ya está en el archivo.

- [ ] **Step 3: Compilar**

Run:

```powershell
dotnet build src/Aduax.AuditorDocumentos.sln --no-restore
```

Expected: 0 errores.

- [ ] **Step 4: Commit**

```powershell
git add src/Aduax.AuditorDocumentos.Api/Services/DesarrolloDb/IDesarrolloDb_DbContextServices.cs src/Aduax.AuditorDocumentos.Api/Services/DesarrolloDb/DesarrolloDb_DbContextServices.cs
git commit -m "feat: leer PerfilCarga persistido sin header sintético"
```

---

### Task 3: Quitar bloqueo de alta y validar acciones críticas

**Files:**
- Modify: `src/Aduax.AuditorDocumentos.Api/Controllers/DocumentosController.cs`

**Interfaces:**
- Consumes: `GetPerfilCargaPersistidoAsync`, `GetUsuarioPorUsuauarioAsync`, `AdPerfilCargaMotor.UsuarioPuedeAccionCritica`
- Produces: `ValidarPerfilAccionCriticaAsync<T>(string idCliente, int idTipoDocumentoVucem, string usuario)` → `Task<ActionResult?>` (null = ok, 403 = denegado)

- [ ] **Step 1: Reemplazar el helper al final de `DocumentosController`**

Borrar `MensajePerfilCargaDenegado` y `ValidarPerfilCargaAltaAsync`. Poner:

```csharp
        private const string MensajePerfilAccionCriticaDenegado =
            "Su perfil no tiene permiso para realizar esta acción según la configuración del motor.";

        private async Task<ActionResult?> ValidarPerfilAccionCriticaAsync<T>(
            string idCliente,
            int idTipoDocumentoVucem,
            string usuario)
        {
            var perfilCarga = await _desarrolloDbService.GetPerfilCargaPersistidoAsync(
                idCliente,
                idTipoDocumentoVucem);
            if (string.IsNullOrWhiteSpace(perfilCarga))
            {
                return StatusCode(StatusCodes.Status403Forbidden, new GenericResponse<T>
                {
                    Success = false,
                    Message = MensajePerfilAccionCriticaDenegado
                });
            }

            var usuarioEntity = await _aduasisDbContextServices.GetUsuarioPorUsuauarioAsync(usuario);
            if (!AdPerfilCargaMotor.UsuarioPuedeAccionCritica(perfilCarga, usuarioEntity?.IdClase))
            {
                return StatusCode(StatusCodes.Status403Forbidden, new GenericResponse<T>
                {
                    Success = false,
                    Message = MensajePerfilAccionCriticaDenegado
                });
            }

            return null;
        }
```

- [ ] **Step 2: Quitar validación de alta**

Eliminar por completo estos tres bloques (incluye el `if (perfilCargaError != null) return`):

1. En `ExtraDatosDocumentoIa`, el `ValidarPerfilCargaAltaAsync<List<CampoExtraidoIA>>(...)`.
2. En `PreguardaDocumento`, el `ValidarPerfilCargaAltaAsync<long>(...)`.
3. En `GuardaDocumentoPendienteAprobacion`, el `ValidarPerfilCargaAltaAsync<AdDocumentos>(...)`.

Confirmar que `ValidarPerfilCargaAltaAsync` no queda ninguna referencia.

- [ ] **Step 3: Insertar validación en `AutorizaDocumento`**

Inmediatamente después del `if (documento == null) { return NotFound(...); }` y **antes** de validar estatus Pendiente:

```csharp
                var perfilError = await ValidarPerfilAccionCriticaAsync<AdDocumentos>(
                    documento.IdCliente,
                    documento.IdTipoDocumentoVucem,
                    tokenLogin.ShortUserName);
                if (perfilError != null)
                {
                    return perfilError;
                }
```

- [ ] **Step 4: Insertar validación en `RechazarDocumento`**

Después de obtener `documento` y el NotFound, antes de validar estatus Pendiente, el mismo bloque que Step 3 (`GenericResponse<AdDocumentos>` / `AdDocumentos`).

- [ ] **Step 5: Insertar validación en `EliminarDocumento`**

Después de obtener `documento` y el NotFound, antes de validar “ya está eliminado”, el mismo bloque que Step 3.

- [ ] **Step 6: Insertar validación en `AltaAsociacionOperacion`**

Después de `var documento = await _desarrolloDbService.GetDocumentoByIdAsync(request.Data.IdDocumento);` y el chequeo `documento == null`, **antes** de `GetDocumentoVucemporIdTipoDocumentoVucemAsync`:

```csharp
                var perfilError = await ValidarPerfilAccionCriticaAsync<InsertarDatosPedimentoResultDto>(
                    documento.IdCliente,
                    documento.IdTipoDocumentoVucem,
                    tokenLogin.ShortUserName);
                if (perfilError != null)
                {
                    return perfilError;
                }
```

- [ ] **Step 7: Insertar validación en `EliminarAsociacionOperacion`**

Después de obtener `tokenLogin` (y el Unauthorized), **antes** de `GetDocumentoOperacionesConEdocumentAsync`:

```csharp
                var documento = await _desarrolloDbService.GetDocumentoByIdAsync(request.Data.IdDocumento);
                if (documento == null)
                {
                    return BadRequest(new GenericResponse<bool>
                    {
                        Success = false,
                        Message = "No se encontró el documento",
                        Data = false
                    });
                }

                var perfilError = await ValidarPerfilAccionCriticaAsync<bool>(
                    documento.IdCliente,
                    documento.IdTipoDocumentoVucem,
                    tokenLogin.ShortUserName);
                if (perfilError != null)
                {
                    return perfilError;
                }
```

Usar `documento.IdCliente` / `documento.IdTipoDocumentoVucem`, no el `IdCliente` del request.

- [ ] **Step 8: Compilar**

```powershell
dotnet build src/Aduax.AuditorDocumentos.sln --no-restore
```

Expected: 0 errores.

- [ ] **Step 9: Commit**

```powershell
git add src/Aduax.AuditorDocumentos.Api/Controllers/DocumentosController.cs
git commit -m "feat: validar perfil del motor en acciones críticas y liberar el alta"
```

---

### Task 4: Flag `puedeAccionCritica` en el listado

**Files:**
- Modify: `src/Aduax.AuditorDocumentos.Api/Data/DesarrolloDB/CspAdDocumentosPorEstatus.cs`
- Modify: `src/Aduax.AuditorDocumentos.Api/Controllers/DocumentosController.cs` (`ObtenerDocumentos`)

**Interfaces:**
- Consumes: `GetPerfilesCargaPorClienteAsync`, `GetUsuarioPorUsuauarioAsync`, `UsuarioPuedeAccionCritica`
- Produces: cada ítem de `ObtenerDocumentos` serializa `puedeAccionCritica` (bool). El SP `csp_Ad_DocumentosPorEstatus` no se modifica.

- [ ] **Step 1: Propiedad no mapeada**

En `CspAdDocumentosPorEstatus.cs`, al final de la clase (después de `ComentarioRechazo` / `Estatus`):

```csharp
        [NotMapped]
        public bool PuedeAccionCritica { get; set; }
```

`using System.ComponentModel.DataAnnotations.Schema;` ya existe.

- [ ] **Step 2: Enriquecer `ObtenerDocumentos`**

Reemplazar el tramo que hoy hace `GetDocumentosPorEstatusAsync` y `return Ok` por:

```csharp
                int idEstatus = request.Data;

                var documentos = await _desarrolloDbService.GetDocumentosPorEstatusAsync(request.IdCliente, idEstatus);

                var usuario = await _aduasisDbContextServices.GetUsuarioPorUsuauarioAsync(tokenLogin.ShortUserName);
                var tipos = documentos
                    .Select(d => d.IdTipoDocumentoVucem)
                    .Distinct()
                    .ToList();
                var perfiles = await _desarrolloDbService.GetPerfilesCargaPorClienteAsync(request.IdCliente, tipos);

                foreach (var doc in documentos)
                {
                    if (perfiles.TryGetValue(doc.IdTipoDocumentoVucem, out var perfilCarga))
                    {
                        doc.PuedeAccionCritica = AdPerfilCargaMotor.UsuarioPuedeAccionCritica(
                            perfilCarga,
                            usuario?.IdClase);
                    }
                    else
                    {
                        doc.PuedeAccionCritica = false;
                    }
                }

                return Ok(new GenericResponse<List<CspAdDocumentosPorEstatus>>
                {
                    Success = true,
                    Message = "Documentos obtenidos correctamente",
                    Data = documentos
                });
```

- [ ] **Step 3: Compilar**

```powershell
dotnet build src/Aduax.AuditorDocumentos.sln --no-restore
```

Expected: 0 errores.

- [ ] **Step 4: Commit**

```powershell
git add src/Aduax.AuditorDocumentos.Api/Data/DesarrolloDB/CspAdDocumentosPorEstatus.cs src/Aduax.AuditorDocumentos.Api/Controllers/DocumentosController.cs
git commit -m "feat: exponer puedeAccionCritica por documento en el listado"
```

---

### Task 5: Eliminar endpoint `ValidaPerfilCargaDocumento`

**Files:**
- Modify: `src/Aduax.AuditorDocumentos.Api/Controllers/MotorConfigController.cs`

**Interfaces:**
- Consumes: nada nuevo
- Produces: el action `POST /api/MotorConfig/ValidaPerfilCargaDocumento` deja de existir. El método JS se borra en Task 6, cuando el alta ya no lo llama.

- [ ] **Step 1: Borrar el action del controller**

Eliminar el método completo `ValidaPerfilCargaDocumento` (desde `[HttpPost("ValidaPerfilCargaDocumento")]` hasta el cierre del método, inclusive).

Si el `using Aduax.AuditorDocumentos.VModels` queda sin uso en ese archivo, eliminarlo. Si otro método del mismo controller lo usa, dejarlo.

- [ ] **Step 2: Compilar API**

```powershell
dotnet build src/Aduax.AuditorDocumentos.sln --no-restore
```

Expected: 0 errores. Buscar `ValidaPerfilCargaDocumento` en `src/Aduax.AuditorDocumentos.Api`: cero resultados.

- [ ] **Step 3: Commit**

```powershell
git add src/Aduax.AuditorDocumentos.Api/Controllers/MotorConfigController.cs
git commit -m "chore: eliminar endpoint de prechequeo de perfil en el alta"
```

---

### Task 6: Alta libre en `DocumentRepositoryCreatePage`

**Files:**
- Modify: `src/Aduax.AuditorDocumentos.Web/src/pages/DocumentRepositoryCreatePage.jsx`
- Modify: `src/Aduax.AuditorDocumentos.Web/src/services/motorConfigService.js`

**Interfaces:**
- Consumes: `validaExistenciaMotorConfig` (sin cambio)
- Produces: `isSaveEnabled` depende de cliente + tipo + `hasMotorConfig === true`, no de perfil

- [ ] **Step 1: Quitar estado `canCargarDocumento`**

Eliminar:

```javascript
  const [canCargarDocumento, setCanCargarDocumento] = useState(null);
```

Cambiar `isSaveEnabled` a:

```javascript
  const isSaveEnabled = Boolean(
    selectedClient &&
      selectedDocument?.id_DocumentoVucem &&
      hasMotorConfig === true
  );
```

- [ ] **Step 2: Limpiar `validateMotorConfig`**

Reemplazar la función por:

```javascript
  const validateMotorConfig = async ({
    clientId,
    documentoVucemId,
    showAlert: showAlertFlag = false,
    checkVigente = true,
  }) => {
    if (!clientId || !documentoVucemId) {
      setHasMotorConfig(null);
      setMotorConfigHeader(null);
      return null;
    }
    try {
      const response = await motorConfigService.validaExistenciaMotorConfig({
        idCliente: clientId,
        idTipoDocumentoVucem: documentoVucemId,
      });
      const hasConfig = Boolean(response?.success && response?.data);
      setHasMotorConfig(hasConfig);

      if (hasConfig) {
        await loadMotorConfig({ clientId, documentoVucemId });

        if (checkVigente) {
          const vigenteResponse =
            await documentosService.validarDocumentoVigenteAprobado({
              idCliente: clientId,
              idTipoDocumentoVucem: documentoVucemId,
            });
          if (vigenteResponse?.success && vigenteResponse?.data === true) {
            showAlert({
              title: "Documento vigente",
              message:
                vigenteResponse?.message || "Ya existe un documento vigente.",
              variant: "alert",
            });
          }
        }
      } else {
        setMotorConfigHeader(null);
      }

      if (!hasConfig && showAlertFlag) {
        showAlert({
          title: "Configuración no encontrada",
          message:
            "No existe configuración del motor para el cliente y documento seleccionados. Configura primero los documentos.",
          variant: "alert",
        });
      }
      return hasConfig;
    } catch (error) {
      setHasMotorConfig(false);
      setMotorConfigHeader(null);
      if (showAlertFlag) {
        showAlert({
          title: "Error de validación",
          message: getErrorMessage(
            error,
            "No se pudo validar la configuración del motor."
          ),
          variant: "error",
        });
      }
      return false;
    }
  };
```

- [ ] **Step 3: Limpiar el `useEffect` que resetea al cambiar cliente/tipo**

Quitar `setCanCargarDocumento(null)` de ese efecto. Debe quedar:

```javascript
    if (!selectedClient || !selectedDocument?.id_DocumentoVucem) {
      setHasMotorConfig(null);
      setMotorConfigHeader(null);
      setSelectedFile(null);
      return;
    }
```

Buscar `canCargarDocumento` / `setCanCargarDocumento` / `validaPerfilCargaDocumento` en el archivo: cero resultados.

- [ ] **Step 4: Borrar `validaPerfilCargaDocumento` del servicio JS**

Eliminar este bloque de `motorConfigService.js`:

```javascript
  /**
   * @param {import("../models/api").MotorConfigRequestBase} payload
   * @param {string} [token]
   * @returns {Promise<MotorConfigValidaExistenciaResponse>}
   */
  async validaPerfilCargaDocumento(payload, token) {
    return request("/api/MotorConfig/ValidaPerfilCargaDocumento", {
      method: "POST",
      body: JSON.stringify(payload),
      token,
    });
  },
```

Buscar `validaPerfilCargaDocumento` en `src/`: cero resultados.

- [ ] **Step 5: Commit**

```powershell
git add src/Aduax.AuditorDocumentos.Web/src/pages/DocumentRepositoryCreatePage.jsx src/Aduax.AuditorDocumentos.Web/src/services/motorConfigService.js
git commit -m "fix: el alta de documentos ya no se bloquea por perfil del motor"
```

---

### Task 7: Botones del repositorio por fila

**Files:**
- Modify: `src/Aduax.AuditorDocumentos.Web/src/services/documentosService.js`
- Modify: `src/Aduax.AuditorDocumentos.Web/src/pages/DocumentRepositoryListPage.jsx`

**Interfaces:**
- Consumes: `item.puedeAccionCritica` del listado (Task 4)
- Produces: autorizar, rechazar, eliminar, relacionar y quitar asociación visibles solo si el documento tiene `puedeAccionCritica === true`. `AppHeader` sigue usando `validaUsuarioAdminLider`.

- [ ] **Step 1: Typedef del listado**

En `documentosService.js`, dentro de `@typedef {Object} CspAdDocumentosPorEstatus`, agregar:

```javascript
 * @property {boolean} [puedeAccionCritica]
```

- [ ] **Step 2: Quitar permiso global de la página**

Eliminar:

```javascript
  const [canManageDocuments, setCanManageDocuments] = useState(false);
```

Eliminar el `useEffect` de `loadPermissions` que llama `motorConfigService.validaUsuarioAdminLider()` y hace `setCanManageDocuments`. **No** quitar otras llamadas a `motorConfigService` (sugerencia / diagnóstico).

Agregar estado para el modal de autorizar:

```javascript
  const [canAccionCriticaDetalle, setCanAccionCriticaDetalle] = useState(false);
```

Al inicio de `handleOpenAuthorizeModal`, después de validar `item` / `selectedClient`:

```javascript
    setCanAccionCriticaDetalle(Boolean(item?.puedeAccionCritica));
```

- [ ] **Step 3: Condicionar botones de la tabla**

Dentro del `map` de `filteredDocuments`, después de `canAssociateStatus`, agregar:

```javascript
                      const puedeAccionCritica = Boolean(item?.puedeAccionCritica);
```

Reemplazar el bloque pendiente (autorizar + eliminar) para que los botones solo existan con permiso. El botón Ver (ojo) no se toca:

```javascript
                            {isPending && puedeAccionCritica && (
                              <>
                                <button
                                  type="button"
                                  className="document-action-button"
                                  aria-label="Autorizar"
                                  title="Autorizar"
                                  onClick={() =>
                                    handleOpenAuthorizeModal(item, { showActions: true })
                                  }
                                >
                                  <CheckIcon />
                                </button>
                                <button
                                  type="button"
                                  className="document-action-button"
                                  aria-label="Eliminar"
                                  title="Eliminar"
                                  onClick={() => handleRequestDelete(item)}
                                >
                                  <TrashIcon />
                                </button>
                              </>
                            )}
                            {(isApproved || canAssociateStatus) && puedeAccionCritica && (
                              <button
                                type="button"
                                className="document-action-button"
                                aria-label="Eliminar"
                                title="Eliminar"
                                onClick={() => handleRequestDelete(item)}
                              >
                                <TrashIcon />
                              </button>
                            )}
```

El botón de comentarios de rechazo (estatus 4) se deja igual.

Reemplazar el botón relacionar:

```javascript
                            {canAssociateStatus && puedeAccionCritica && (
                              <button
                                type="button"
                                className="document-action-button"
                                aria-label="Relacionar con operación"
                                title="Relacionar con operación"
                                onClick={() => handleOpenAssociateModal(item)}
                              >
                                <LinkIcon />
                              </button>
                            )}
```

- [ ] **Step 4: Modales de autorizar / rechazar / asociación**

En el modal de autorizar, mostrar Aprobar/Rechazar solo con permiso:

```javascript
            {showAuthorizeActions && canAccionCriticaDetalle && (
              <div className="authorize-modal-actions">
                <Button
                  variant="primary"
                  onClick={handleApprove}
                  disabled={detailLoading}
                >
                  Aprobar
                </Button>
                <Button
                  variant="secondary"
                  onClick={handleOpenRejectModal}
                  disabled={detailLoading}
                >
                  Rechazar
                </Button>
              </div>
            )}
```

En el modal de rechazo, el Continuar:

```javascript
                disabled={
                  !rejectComment.trim() || detailLoading || !canAccionCriticaDetalle
                }
```

En el modal de asociación, el botón eliminar asociación. Hoy:

```javascript
                            {puedeEliminarAsociacionOperacion(operation) &&
                            canManageDocuments ? (
```

Reemplazar por:

```javascript
                            {puedeEliminarAsociacionOperacion(operation) &&
                            Boolean(associateDocument?.puedeAccionCritica) ? (
```

Buscar `canManageDocuments` en el archivo: cero resultados.

- [ ] **Step 5: Commit**

```powershell
git add src/Aduax.AuditorDocumentos.Web/src/services/documentosService.js src/Aduax.AuditorDocumentos.Web/src/pages/DocumentRepositoryListPage.jsx
git commit -m "feat: ocultar acciones críticas del repositorio según perfil del motor"
```

---

### Task 8: Copy de configuración

**Files:**
- Modify: `src/Aduax.AuditorDocumentos.Web/src/constants/adPerfilCargaMotor.js`
- Modify: `src/Aduax.AuditorDocumentos.Web/src/pages/ConfigurationsPage.jsx`

**Interfaces:**
- Consumes: valores `G` / `A` / `L` sin cambio
- Produces: labels Acceso general / Admin / Líder; título de sección “Perfil para acciones críticas”

- [ ] **Step 1: Labels**

`adPerfilCargaMotor.js` debe quedar:

```javascript
export const AdPerfilCargaMotor = Object.freeze({
  AccesoGeneral: "G",
  Admin: "A",
  Lider: "L",
});

export const adPerfilCargaMotorOptions = [
  { value: AdPerfilCargaMotor.AccesoGeneral, label: "Acceso general" },
  { value: AdPerfilCargaMotor.Admin, label: "Admin" },
  { value: AdPerfilCargaMotor.Lider, label: "Líder" },
];
```

- [ ] **Step 2: Título de sección**

En `ConfigurationsPage.jsx`, reemplazar:

```javascript
                  <span className="section-title">Perfil para carga</span>
```

por:

```javascript
                  <span className="section-title">Perfil para acciones críticas</span>
```

No cambiar el `name="perfilCarga"` del `RadioGroup` ni el payload de guardado.

- [ ] **Step 3: Commit**

```powershell
git add src/Aduax.AuditorDocumentos.Web/src/constants/adPerfilCargaMotor.js src/Aduax.AuditorDocumentos.Web/src/pages/ConfigurationsPage.jsx
git commit -m "fix: copy de perfil del motor alineado a acciones críticas"
```

---

### Task 9: Documentación de producto

**Files:**
- Modify: `docs/ajustes-perfil-carga-motor/README.md`
- Modify: `docs/ajustes-perfil-carga-motor/decisiones-negocio.md`
- Modify: `docs/ajustes-perfil-carga-motor/guia-implementacion.md`
- Modify: `docs/ajustes-perfil-carga-motor/SQL/implementacion/01 DesarrolloDB Alter ad_motor_config_header PerfilCarga.sql`
- Modify: `docs/README.md` (una línea del índice)
- Modify: `docs/superpowers/specs/2026-08-17-perfil-acciones-criticas-design.md` (estado)

**Interfaces:**
- Consumes: matriz del spec
- Produces: docs de producto coherentes con alta libre + acciones críticas

- [ ] **Step 1: Reescribir `decisiones-negocio.md`**

```markdown
# Decisiones de negocio — Perfil del motor para acciones críticas

Actualizado 17/08/2026. Las respuestas del 04/07/2026 sobre Admin / Líder / Acceso general se mantienen; cambia el **alcance**.

| # | Tema | Decisión |
|---|------|----------|
| 1 | **Objetivo** | Restringir **acciones críticas** según `ad_motor_config_header.PerfilCarga` |
| 2 | **Opciones** | **Admin**, **Líder**, **Acceso general** (una por motor: cliente + tipo VUCEM) |
| 3 | **Admin** | Solo usuarios con `fusuario.IdClase = 'ADM'` |
| 4 | **Líder** | Solo usuarios con `fusuario.IdClase = 'LIDER'` |
| 5 | **Acceso general** | Cualquier usuario autenticado (sin importar `IdClase`) |
| 6 | **CALIDAD** | Se trata como **acceso general** (no como admin ni líder) |
| 7 | **Alta** | Cualquier usuario autenticado puede cargar; el perfil **no** bloquea el alta |
| 8 | **Acciones críticas** | Autorizar, rechazar, eliminar documento, relacionar operación, eliminar asociación |
| 9 | **Fuera de alcance** | Consultas, detalle, PDF, envío VUCEM, acceso a `/config` |
| 10 | **Default motores existentes** | **Acceso general** |
| 11 | **UI configuración** | Pantalla `/config`, título “Perfil para acciones críticas” |

## Matriz de validación (acciones críticas)

| Perfil en motor | ADM | LIDER | CALIDAD | Otro / sin clase |
|-----------------|-----|-------|---------|------------------|
| Admin | ✅ | ❌ | ❌ | ❌ |
| Líder | ❌ | ✅ | ❌ | ❌ |
| Acceso general | ✅ | ✅ | ✅ | ✅ |

Alta: ✅ para todos los perfiles y clases (si existe motor).
```

- [ ] **Step 2: Actualizar README del ajuste**

Escribir el archivo completo `docs/ajustes-perfil-carga-motor/README.md` con este contenido (el árbol SQL va en un fence de tipo text):

````markdown
# Ajuste — Perfil del motor para acciones críticas

**Estado:** implementado en `src/` — **pendiente ejecutar script SQL en BD** si la columna `PerfilCarga` aún no existe.

| Documento | Contenido |
|-----------|-----------|
| [decisiones-negocio.md](./decisiones-negocio.md) | Alta libre; acciones críticas por Admin / Líder / Acceso general |
| [guia-implementacion.md](./guia-implementacion.md) | Script SQL y validación |

---

## SQL

```text
SQL/
└── implementacion/
    └── 01 DesarrolloDB Alter ad_motor_config_header PerfilCarga.sql
```

---

## Objetivo

Columna `PerfilCarga` en `ad_motor_config_header` (`G` / `A` / `L`) para restringir **acciones críticas**. El alta no se bloquea. Consulta y detalle no se bloquean.

---

## Casos de prueba

| Motor | Usuario | Alta | Acciones críticas | Ver repositorio |
|-------|---------|------|-------------------|-----------------|
| G | cualquiera | Sí | Sí | Sí |
| A | ADM | Sí | Sí | Sí |
| A | LIDER | Sí | No | Sí |
| A | CALIDAD / otro | Sí | No | Sí |
| L | LIDER | Sí | Sí | Sí |
| L | ADM | Sí | No | Sí |
| L | CALIDAD / otro | Sí | No | Sí |

Detalle en [decisiones-negocio.md](./decisiones-negocio.md).
````

- [ ] **Step 3: Actualizar `guia-implementacion.md` sección código**

Reemplazar “Código relacionado” por:

```markdown
## Código relacionado (`src/`)

- `AdPerfilCargaMotor.UsuarioPuedeAccionCritica`
- `ad_motor_config_header.PerfilCarga` / `AdMotorConfigHeader.PerfilCarga`
- `GetPerfilCargaPersistidoAsync`, `GetPerfilesCargaPorClienteAsync`
- `DocumentosController.ValidarPerfilAccionCriticaAsync` en autorizar, rechazar, eliminar, asociar y quitar asociación
- `CspAdDocumentosPorEstatus.PuedeAccionCritica` en `ObtenerDocumentos`
- UI: `ConfigurationsPage` (copy), `DocumentRepositoryCreatePage` (alta libre), `DocumentRepositoryListPage` (botones por fila)
```

- [ ] **Step 4: Comentario del SQL**

En el script `01`, reemplazar el encabezado de valores:

```sql
/*
  Ajuste — Perfil para acciones críticas en ad_motor_config_header
  Base: DesarrolloDB

  Valores PerfilCarga:
    G = Acceso general (default) — cualquiera autenticado puede acciones críticas
    A = Admin  (IdClase ADM)
    L = Líder  (IdClase LIDER)

  El alta de documentos no se restringe por esta columna.

  Ejecutar en QA antes de producción.
*/
```

- [ ] **Step 5: Índice `docs/README.md`**

Cambiar la viñeta de `docs/ajustes-perfil-carga-motor/` a: perfil del motor para **acciones críticas** (`PerfilCarga`). Alta libre.

En el spec, cambiar `**Estado:** pendiente de implementación` a `**Estado:** plan listo — ver docs/superpowers/plans/2026-08-17-perfil-acciones-criticas.md`.

- [ ] **Step 6: Commit**

```powershell
git add docs/ajustes-perfil-carga-motor docs/README.md docs/superpowers/specs/2026-08-17-perfil-acciones-criticas-design.md
git commit -m "docs: perfil del motor restringe acciones críticas, no el alta"
```

---

## Verificación manual (después de las 9 tareas)

Compilar:

```powershell
dotnet build src/Aduax.AuditorDocumentos.sln
```

En UI / API, con un motor `A` y usuario LIDER: alta ok; autorizar/rechazar/eliminar/relacionar/quitar asociación ocultan botones y el API responde 403. Con motor `G`, el mismo LIDER (u otro) puede las acciones críticas. Ver listado siempre visible. `/config` sigue limitado a ADM/LIDER/CALIDAD.
