# Frontend Web — `Aduax.AuditorDocumentos.Web`

## Stack

| Elemento | Versión |
|----------|---------|
| React | 18.3 |
| Build | Vite 5.4 |
| Routing | React Router 7 |
| Notificaciones UI | react-toastify 11 |
| Estilos | **CSS por componente/página** (sin Tailwind ni MUI) |
| Módulos ES | `"type": "module"` en `package.json` |

El proyecto **no** está incluido en `Aduax.AuditorDocumentos.sln`; se despliega como estáticos bajo la subruta `/AuditorDocumentos/`.

## Estructura de carpetas

```text
Aduax.AuditorDocumentos.Web/
├── vite.config.js              # base: "/AuditorDocumentos/"
├── public/web.config             # IIS (rewrite SPA)
├── src/
│   ├── main.jsx                  # Entry: StrictMode, estilos globales, ToastContainer en App
│   ├── App.jsx                   # Router + layout + estado cliente global
│   ├── config/api.js             # API_BASE_URL por MODE (development | production)
│   ├── constants/                # Enums espejo de VModels (AdCampos, AdDocumentoClasificacion)
│   ├── components/               # UI reutilizable + index.js barrel
│   ├── pages/                    # Pantallas por ruta
│   ├── services/                 # Capa HTTP (documentos, motor, notificaciones)
│   ├── models/api.js             # Tipos/helpers compartidos del cliente API
│   └── styles/                   # index.css, main.css, App.css, oc-components.css
└── readme.txt                    # Documentación inline de servicios (contratos endpoints)
```

## Enrutado

`BrowserRouter` con `basename="/AuditorDocumentos"`:

| Ruta | Componente | Función |
|------|------------|---------|
| `/` | redirect | → `/repositorio` |
| `/repositorio` | `DocumentRepositoryListPage` | Listado, filtros, aprobación, visor PDF |
| `/repositorio/nuevo` | `DocumentRepositoryCreatePage` | Alta de documento |
| `/config` | `ConfigurationsPage` | Motor de configuración por tipo VUCEM |
| `/notificaciones` | `NotificationConfigPage` | Plantillas y correos de aviso |
| `*` | redirect | → `/repositorio` |

El **cliente seleccionado** (`selectedClient`) vive en estado de `App` y se pasa como prop a todas las páginas. El header (`AppHeader`) permite cambiarlo.

Los query params de la URL (p. ej. `?token=`) se preservan en redirects con `location.search`.

## Comunicación con la API

### `config/api.js`

```javascript
const API_BASE_URLS = {
  development: "https://localhost:7031/",
  production: "http://192.168.6.185/AuditorDocumentosApi/",
};
```

Vite define `import.meta.env.MODE` (`development` en `npm run dev`, `production` en `npm run build`).

### `services/httpClient.js`

- Función exportada: `request(path, options)`.
- Token: query `?token=` o `options.token`.
- Header: `Authorization: Bearer {token}`, `Content-Type: application/json`.
- Errores: intenta leer `message` del JSON de error; lanza `Error` con texto legible.
- 204 → `null`.

### Servicios de dominio

| Archivo | Controlador API |
|---------|-----------------|
| `documentosService.js` | `Documentos` |
| `motorConfigService.js` | `MotorConfig` |
| `notificacionesService.js` | `NotificacionConfig` |
| `services/index.js` | Reexporta los tres |

Cada función exportada:

- Construye payload acorde a `GenericAdRequest` / `PagedRequest` (ver `readme.txt` y `vmodels-y-contratos-api.md`).
- Llama `request("api/Controller/Accion", { method: "POST", body: JSON.stringify(...) })`.
- Usa **JSDoc** `@typedef` para documentar DTOs en el cliente (no TypeScript).

## Componentes UI

Patrón habitual por componente:

- `Nombre.jsx` + `Nombre.css`
- Export en `components/index.js` para imports cortos: `import { Button, LoadingPanel } from "../components"`.

Componentes notables:

| Componente | Uso |
|------------|-----|
| `PaginatedSelect` / `PaginatedMultiSelect` | Catálogos con filtro y paginación vía API |
| `FileDropzone` | Carga PDF en base64 |
| `PdfViewer` | Visualización del documento |
| `FieldCard` | Campos extraídos / editables |
| `VucemDocumentSelector` | Selección tipo documento VUCEM |
| `AlertModal` / `ConfirmationModal` | Confirmaciones y avisos |
| `LoadingPanel` | Bloqueo UI durante requests |
| `TagInput` | Listas de correos (notificaciones) |

Estilos globales de marca OneCore en `styles/oc-components.css` y `main.css`.

## Constantes alineadas con el backend

- `constants/adCampos.js` — IDs de campos (`AdCampos` en VModels).
- `constants/adDocumentoClasificacion.js` — Clasificación del documento.

Mantener sincronizados con enums C# al agregar valores.

## Páginas grandes

`DocumentRepositoryListPage.jsx` y `DocumentRepositoryCreatePage.jsx` concentran mucha lógica de estado (`useState`, `useEffect`, `useMemo`). Patrón:

- Cargar catálogos al cambiar `selectedClient` o tipo VUCEM.
- `toast.success` / `toast.error` para feedback.
- Modales para confirmar acciones destructivas o irreversibles.

## Scripts npm

```bash
npm install
npm run dev      # Vite → http://localhost:5173/AuditorDocumentos/
npm run build    # dist/ para IIS o servidor estático
npm run preview  # Vista previa del build
```

Abrir la app con **token en URL**, por ejemplo:  
`http://localhost:5173/AuditorDocumentos/repositorio?token=...`

## CORS

El API debe listar el origen del dev server (`Program.cs` ya incluye `5173`, `5174`). Si cambia el puerto de Vite, actualizar CORS en la API.

## Extender el front (checklist)

1. Nueva ruta en `App.jsx` + página en `pages/` (+ CSS).
2. Método en el `*Service.js` correspondiente con JSDoc del payload.
3. Reutilizar `request()`; no duplicar lógica de token.
4. Si hay nuevo enum de negocio, valor en `constants/` y en VModels.
5. Probar con cliente y token reales contra API en development.
