# Auditor de Documentos (Aduax)

Solución **ITAduax** para la **auditoría y gestión de documentos** asociados al catálogo **VUCEM** (vía **EDOCS**), con **extracción asistida por IA** sobre PDFs, integración con **almacenamiento de archivos**, **notificaciones por correo** (incluido un proceso programado de vencimientos) y una **aplicación web** para operar el repositorio y la configuración del motor.

## Propósito

- Gestionar y consultar documentos del repositorio en función de cliente, tipos VUCEM y datos en **EDOCS**, **Aduasis** y la base de aplicación **DesarrolloDB**.
- Configurar el **motor** (asociaciones, catálogos y reglas de negocio expuestas por la API).
- Ejecutar flujos de **IA** (Google **Vertex AI**) para extraer campos de documentos PDF según configuración y prompts almacenados.
- Administrar **plantillas y envíos de notificaciones**, y ejecutar en segundo plano el **procesamiento de notificaciones por vencimiento** (correo vía configuración SMTP).

## Tecnologías

| Capa | Tecnología |
|------|------------|
| API | **ASP.NET Core 8** (controladores, minimal hosting en `Program.cs`), **Swagger** (Swashbuckle), **CORS** para el front en desarrollo |
| Datos | **Entity Framework Core 8** + **SQL Server**; tres contextos: `DesarrolloDB`, `Aduasis`, `EDOCS` |
| IA y nube | **Google.Cloud.AIPlatform.V1**, **Google.Cloud.Storage.V1** |
| Integraciones | Cliente HTTP tipado para **File Storage** REST; correo según `MailClient`; utilidades **Shared.Utilerias**; DLL **onecore.security** (token) |
| Contratos | Proyecto **`Aduax.AuditorDocumentos.VModels`**: DTOs y modelos de petición/respuesta compartidos con la API |
| Front | **React 18**, **Vite 5**, **React Router 7**, **react-toastify**; componentes en **JSX** y estilos en **CSS** por componente |

## Estructura del repositorio

La solución .NET vive bajo **`src/`**. El front es un proyecto **Node** independiente (no está incluido en el `.sln`).

```text
.
├── .github/                              # Plantilla de Pull Request
├── src/
│   ├── Aduax.AuditorDocumentos.sln       # Solución Visual Studio
│   ├── Aduax.AuditorDocumentos.Api/      # API REST
│   ├── Aduax.AuditorDocumentos.VModels/  # View models / DTOs
│   ├── Aduax.AuditorDocumentos.Web/      # SPA React (Vite)
│   └── DLL/                              # Referencias onecore.security.*
└── README.md
```

### Organización del código (estilo y patrones)

- **API**: controladores en `Controllers/` con rutas `api/[controller]`, atributo `[Authorize]` y respuestas envueltas en tipos como `GenericResponse<T>`. Reglas de negocio y acceso a datos en servicios **inyectados por interfaz** (`IDesarrolloDb_DbContextServices`, `IAduasisDbContextServices`, `IEDOCS_DbContextServices`, etc.), registrados como `Scoped`.
- **Autenticación**: esquema **Bearer** + middleware `TokenAuthenticationMiddleware` que valida el token (decodificación con clave en `AppSettings`) para endpoints autorizados; Swagger documenta el header `Authorization`.
- **Datos**: entidades EF en `Data/` por base; servicios dedicados por contexto.
- **Front**: páginas en `src/pages/`, componentes reutilizables en `src/components/`, llamadas HTTP en `src/services/`; enrutado con `basename="/AuditorDocumentos"` para despliegue bajo subruta.

## Aplicación web (rutas principales)

| Ruta | Uso |
|------|-----|
| `/repositorio` | Listado del repositorio de documentos |
| `/repositorio/nuevo` | Alta en el repositorio |
| `/config` | Configuraciones del motor |
| `/notificaciones` | Configuración de notificaciones |

## Requisitos

- [.NET 8 SDK](https://dotnet.microsoft.com/download)
- [Node.js](https://nodejs.org/) (LTS recomendado) y npm, para el front
- Acceso a instancias **SQL Server** y cadenas de conexión para **DesarrolloDB**, **Aduasis** y **EDOCS**
- Credenciales y proyecto Google Cloud según uso de **Vertex** / **Storage** (si aplica en el entorno)

## Configuración

En **`src/Aduax.AuditorDocumentos.Api/appsettings.json`** (o variables de entorno / secretos de usuario en desarrollo) deben definirse al menos:

- **`ConnectionStrings`**: `DesarrolloDB`, `Aduasis`, `EDOCS`
- **`AppSettings`**: clave para validación del token (`KeyToken`)
- **`FileStorageCfg`**: URL y credenciales del servicio de archivos
- **`MailClient`**: parámetros SMTP / envío para notificaciones

No versionar valores reales de producción; usar **User Secrets**, variables de entorno o el mecanismo seguro que defina el equipo.

## Cómo ejecutar en local

**API** (desde la carpeta del proyecto):

```bash
cd src/Aduax.AuditorDocumentos.Api
dotnet run
```

En desarrollo queda disponible **Swagger** en la raíz de la API (según `launchSettings` del proyecto).

**Web** (el `Program.cs` incluye orígenes CORS típicos de Vite, p. ej. `http://localhost:5173`):

```bash
cd src/Aduax.AuditorDocumentos.Web
npm install
npm run dev
```

El front debe enviar peticiones autenticadas con **Bearer** en el header `Authorization`, acorde a la API.

## Convenciones del equipo

- Los Pull Request deben seguir la plantilla en [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md).

## Más información

- **Documentación técnica detallada** (arquitectura, API, front, contratos y convenciones): [`docs/README.md`](docs/README.md)
- Wiki, Confluence o normativa interna de arquitectura .NET / front de ITAduax cuando aplique.
