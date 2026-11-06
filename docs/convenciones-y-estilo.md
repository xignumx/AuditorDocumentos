# Convenciones y estilo de programación

Guía para que el código nuevo sea consistente con el existente en **Auditor de Documentos**.

## Principios generales

1. **Cambios mínimos** — No refactorizar ampliamente al corregir un bug o agregar un endpoint.
2. **Servicios para datos** — Los controladores orquestan; la persistencia vive en `*DbContextServices`.
3. **Mensajes al usuario en español** — Validaciones y `GenericResponse.Message`.
4. **Misma forma de respuesta** — Preferir `GenericResponse<T>` / `PagedResponse<T>` sobre tipos anónimos o excepciones sin manejar al cliente.

## Backend (.NET / C#)

### Nomenclatura

| Elemento | Convención | Ejemplo |
|----------|------------|---------|
| Tablas / entidades app | Prefijo `Ad` + PascalCase | `AdDocumentos`, `AdMotorConfigHeader` |
| Resultados SP | `CspAd` + nombre SP | `CspAdDocumentosPorEstatus` |
| Catálogos Aduasis | Prefijo `F` | `FCliente`, `FAduana` |
| Interfaces de servicio | `I` + nombre + `DbContextServices` | `IDesarrolloDb_DbContextServices` |
| Implementación | Mismo nombre sin `I` | `DesarrolloDb_DbContextServices` |
| Controladores | `{Dominio}Controller` | `DocumentosController` |
| Acciones HTTP | PascalCase descriptivo | `GuardaDocumentoPendienteAprobacion` |

### Estilo de código C#

- **Nullable reference types** habilitados: usar `?` donde aplique.
- **Async** en operaciones de I/O: `async Task<...>` en servicios y controladores.
- **Inyección por constructor** en controladores y servicios (campos `readonly` privados con `_camelCase`).
- Comentarios **solo** para reglas de negocio no obvias o restricciones EF (triggers, índices filtrados).
- `// no hace nada` en constructores vacíos de `DbContext` — patrón ya usado, mantener si se toca el archivo.

### Controladores

- Atributo de clase: `[Authorize]` salvo endpoints públicos explícitos (ninguno hoy en producción).
- Validar primero parámetros de `GenericAdRequest`, luego `Data`.
- Obtener usuario: `HttpContext.GetTokenLoginDTO()`; si falta, `Unauthorized` con `GenericResponse`.
- Devolver `BadRequest`, `Ok`, `Unauthorized` con el mismo tipo genérico de respuesta que el éxito.
- Bloques `try/catch` por acción en controladores grandes; loguear o encapsular según patrón del método vecino.

### Entity Framework

- Configuración de relaciones e índices en `OnModelCreating` del contexto correspondiente.
- No usar `SaveChanges` síncrono en código nuevo.
- SP: parámetros con `SqlParameter`, `FromSqlRaw` con nombres exactos del script en `docs/SQL/`.
- Marcar métodos obsoletos con `[Obsolete]` y alternativa (`InsertarDatosPedimentoV2Async`).

### Seguridad

- No loguear tokens ni contraseñas.
- Secretos fuera de `appsettings.json` en repositorio compartido (User Secrets / variables de entorno).
- Validar extensiones de archivo en servidor (ej. solo `.pdf` para IA).

## Frontend (React / JavaScript)

### Nomenclatura

| Elemento | Convención | Ejemplo |
|----------|------------|---------|
| Componentes | PascalCase archivo y función | `DocumentRepositoryListPage.jsx` |
| Servicios | camelCase archivo, funciones exportadas camelCase | `documentosService.js`, `obtenerDocumentos` |
| CSS | Mismo nombre base que componente | `Button.css` |
| Hooks | Prefijo `use` estándar React | `useState`, `useEffect`, `useMemo` |

### Estilo de código JS

- **JSX** funcional (sin clases de componente).
- **ES modules** (`import` / `export`).
- Estado local con `useState`; efectos con `useEffect` y dependencias explícitas.
- Feedback: **`react-toastify`** (`toast.success`, `toast.error`).
- Sin TypeScript: documentar contratos con **JSDoc** en servicios.
- Fetch centralizado en `httpClient.js`; no usar `axios` ni duplicar URL base.

### CSS

- Un archivo CSS por componente o página.
- Variables y utilidades compartidas en `styles/main.css` y `oc-components.css`.
- No introducir otro framework CSS sin acuerdo de equipo.

### Integración API

- Payload: `{ idCliente, idTipoDocumentoVucem, data: { ... } }`.
- Token en URL para embed en portal OneCore; el servicio lo propaga al header.
- Manejar errores con `try/catch` y mostrar `error.message` al usuario.

## SQL y versionado

- Scripts en `docs/SQL/` con prefijo de fecha cuando sea migración: `YYYYMMDD-NN Descripcion.sql`.
- Nombre de SP alineado con entidad `CspAd*` en C#.
- Documentar SP nuevo en commit/PR y en comentario del método que lo invoca.

## Git y PR

- Plantilla de PR en `.github/PULL_REQUEST_TEMPLATE.md`.
- Commits solo cuando el usuario lo pida explícitamente (regla del repositorio).

## Anti-patrones a evitar

| Evitar | Preferir |
|--------|----------|
| Lógica SQL en controladores | Servicio `*DbContextServices` |
| Nuevo contexto EF “unificado” | Tres contextos existentes por base |
| Endpoints GET con cuerpo o sin auth para datos sensibles | POST + `[Authorize]` como el resto |
| Duplicar enums solo en front sin VModels | Enum en VModels + constante JS |
| Credenciales en código fuente commiteado | Configuración externa |
| Refactor masivo de `DocumentosController` en el mismo PR que un fix pequeño | PR enfocado |

## Referencias cruzadas

- Arquitectura: [arquitectura-general.md](./arquitectura-general.md)
- API: [api-backend.md](./api-backend.md)
- Front: [frontend-web.md](./frontend-web.md)
- Contratos: [vmodels-y-contratos-api.md](./vmodels-y-contratos-api.md)
- Ejecución local: [README.md](../README.md) en la raíz del repo
