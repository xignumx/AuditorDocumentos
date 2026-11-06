# API Backend — `Aduax.AuditorDocumentos.Api`

## Stack

| Elemento | Versión / detalle |
|----------|-------------------|
| Runtime | .NET **8** (`net8.0`) |
| Hosting | ASP.NET Core minimal (`Program.cs`) |
| API style | **Controllers** (no Minimal APIs para negocio) |
| ORM | **Entity Framework Core 8** + SQL Server |
| Documentación HTTP | **Swashbuckle** 6.x (solo en `Development`) |
| Nullable | Habilitado a nivel de proyecto |

## Estructura de carpetas

```text
Aduax.AuditorDocumentos.Api/
├── Program.cs                 # DI, CORS, DbContexts, hosted services
├── appsettings.json           # ConnectionStrings, AppSettings, FileStorage, Mail
├── Controllers/               # Entrada HTTP
├── Auth/                      # Middleware, handler, extensiones HttpContext
├── Configuration/             # Clases ligadas a IOptions (AppSettings, MailClient, FileStorageCfg)
├── Data/
│   ├── DesarrolloDB_DBContext.cs
│   ├── Aduasis_DBContext.cs
│   ├── EDOCS_DBContext.cs
│   ├── DesarrolloDB/          # Entidades + resultados de SP (prefijo Ad*, CspAd*)
│   ├── Aduasis/               # Entidades F* y CspAd*
│   └── EDOCS/                 # TbDocumentosVucem, etc.
└── Services/
    ├── DesarrolloDb/          # IDesarrolloDb_DbContextServices + implementación
    ├── Aduasis/
    ├── EDOCS/
    ├── FileStorage/
    ├── VertexIA/
    ├── SendMailServices.cs
    ├── NotificacionVencimientoService.cs      # BackgroundService
    └── NotificacionVencimientoProcessor.cs
```

## Registro de dependencias (`Program.cs`)

- **DbContext**: uno por base, `AddDbContext<...>(UseSqlServer(...))`.
- **Servicios de datos**: `AddScoped` para interfaces `I*DbContextServices`.
- **FileStorage**: `AddHttpClient<IFileStorageService, FileStorageService>()`.
- **Background**: `AddHostedService<NotificacionVencimientoService>()`.
- **Auth**: esquema `"Bearer"` con `TokenAuthenticationHandler` + middleware personalizado **después** de `UseAuthorization`.

## Controladores

| Controlador | Ruta base | Responsabilidad principal |
|-------------|-----------|---------------------------|
| `DocumentosController` | `api/Documentos` | Ciclo de vida del documento, IA, aprobación, asociación operación |
| `MotorConfigController` | `api/MotorConfig` | Configuración motor, catálogos paginados, validaciones, sugerencias pedimento |
| `NotificacionConfigController` | `api/NotificacionConfig` | Config y envío de notificaciones |

Convenciones comunes:

- `[ApiController]`, `[Route("api/[controller]")]`, `[Authorize]` a nivel de clase.
- Acciones con **`[HttpPost("NombreAccion")]`** (estilo RPC sobre REST; el verbo HTTP casi siempre es POST).
- Una excepción documentada: `MotorConfig/ValidaUsuarioAdminLider` usa **GET**.

### Patrón de una acción

1. Recibir `GenericAdRequest<T>` o `PagedRequest` desde **VModels**.
2. Validar `IdCliente`, `IdTipoDocumentoVucem` y `Data` en el controlador (mensajes en español).
3. `HttpContext.GetTokenLoginDTO()` para usuario (`ShortUserName`, etc.).
4. Llamar servicios inyectados (no usar `DbContext` directo en el controlador salvo casos excepcionales).
5. Devolver `ActionResult<GenericResponse<T>>` o `PagedResponse<T>` con `Success`, `Message`, `Data`.
6. `try/catch` con respuestas de error coherentes (patrón repetido en `DocumentosController`).

`DocumentosController` es el archivo más grande (~1300+ líneas): concentra orquestación IA + File Storage + persistencia. Para cambios acotados, localizar el método por nombre de acción.

## Capa de servicios de datos

### `DesarrolloDb_DbContextServices`

- Implementa `IDesarrolloDb_DbContextServices`.
- Usa `DesarrolloDB_DBContext` inyectado.
- Operaciones CRUD con EF (`SaveChangesAsync`), transacciones donde aplica.
- Stored procedures vía `FromSqlRaw` / `ExecuteSqlRawAsync`, por ejemplo:
  - `csp_Ad_DocumentosPorEstatus`
  - `csp_Ad_ObtieneDocumentosPorVencer`
  - `ad_proveedores_listar_paginado`
  - `csp_AD_GetTraficoPorReferencia`
  - `csp_ad_InsertaDatosPedimento_v2` (preferido sobre versión obsoleta)

### `AduasisDbContextServices` / `EDOCS_DbContextServices`

- Consultas a catálogos y SPs de Aduasis/EDOCS sin duplicar tablas en DesarrolloDB.

## Entity Framework — convenciones del proyecto

- Entidades de tabla: prefijo **`Ad`** en DesarrolloDB (`AdDocumentos`, `AdMotorConfigHeader`, …).
- Resultados de SP: prefijo **`CspAd`** (`CspAdDocumentosPorEstatus`, …), registrados como `DbSet` sin ser tablas reales.
- Tablas con **triggers**: `UseSqlOutputClause(false)` en `OnModelCreating` (evita error de OUTPUT con triggers).
- Índices únicos filtrados y FKs con `DeleteBehavior.Restrict` documentados en `DesarrolloDB_DBContext.OnModelCreating`.
- Relaciones navegables en entidades (ej. `AdMotorConfigHeader.Detalles`).

## Servicios de integración

### File Storage (`IFileStorageService`)

- Autenticación REST contra URL en `FileStorageCfg`.
- Subida de bytes a almacenamiento AWS vía API interna Grupo EI.
- Uso sincrónico con `.GetAwaiter().GetResult()` en algunos métodos (estilo legado).

### Vertex AI (`VertexClient` / `IVertexClient`)

- Configuración por `Config` (proyecto, modelo, credenciales JSON, temperatura).
- Entrada: prompt + `DocumentToAnalize` (nombre + base64 PDF/XML).
- Salida: JSON en string para parsear en el controlador.

### Correo (`SendMailServices`)

- Configuración `MailClient` en appsettings.
- Usado por notificaciones manuales y el processor de vencimientos.

## Configuración

Archivos: `appsettings.json`, `appsettings.Development.json`.

Secciones:

- `ConnectionStrings`: **DesarrolloDB**, **Aduasis**, **EDOCS**
- `AppSettings.KeyToken`: clave descifrado token OneCore
- `FileStorageCfg`: User, Pass, RefType, App, Url
- `MailClient`: SMTP / envío directo

**No commitear secretos de producción**; usar User Secrets o variables de entorno.

## Ejecución local

```bash
cd src/Aduax.AuditorDocumentos.Api
dotnet run
```

Perfil `https`: Swagger en `https://localhost:7031/swagger` (alineado con `API_BASE_URL` del front en development).

## Extender la API (checklist)

1. ¿El DTO es compartido con el front? → agregar en **VModels**.
2. ¿Nueva tabla o columna? → entidad en `Data/DesarrolloDB`, `DbSet` + configuración en `DbContext`, script en `docs/SQL/`.
3. ¿Solo lectura vía SP? → clase resultado `CspAd*`, `FromSqlRaw` en servicio, no en controlador.
4. Método en `I*DbContextServices` + implementación.
5. Acción en controlador con `[Authorize]`, validaciones y `GenericResponse<T>`.
6. Actualizar servicio JS en `Web/src/services/` y tipos JSDoc si aplica.
7. Probar con Swagger y token Bearer válido.
