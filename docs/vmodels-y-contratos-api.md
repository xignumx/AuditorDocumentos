# VModels y contratos API

Proyecto: **`Aduax.AuditorDocumentos.VModels`** (.NET 8, sin dependencias NuGet).

Sirve como **única biblioteca de contratos** referenciada por la API. El front **no** lo consume directamente; replica la forma de los DTOs en JSDoc y payloads JSON (camelCase por serialización por defecto de ASP.NET Core).

## Tipos de respuesta estándar

### `GenericResponse<T>`

```csharp
public class GenericResponse<T>
{
    public bool Success { get; set; }
    public string Message { get; set; }
    public T? Data { get; set; }
}
```

Uso: casi todas las acciones de `Documentos` y `NotificacionConfig`, y muchas de `MotorConfig` cuando no hay paginación.

### `PagedResponse<T>` / `PagedRequest`

- Listados con `Filter`, `Page`, `Size`.
- Variante genérica `PagedRequest<T>` cuando el filtro lleva objeto en `Data`.

### Petición con contexto de cliente y tipo VUCEM

### `GenericAdRequest<T>`

```csharp
public class GenericAdRequest<T>
{
    public string? IdCliente { get; set; }
    public int? IdTipoDocumentoVucem { get; set; }
    public T? Data { get; set; }
}
```

En el front suele llamarse **`MotorConfigRequestBase`** en JSDoc (mismo shape).

**Regla:** endpoints de documentos y motor esperan `idCliente` e `idTipoDocumentoVucem` en la raíz del JSON; el cuerpo específico va en `data`.

## Enums y constantes de dominio

| Tipo C# | Uso |
|---------|-----|
| `AdCampos` | Identificadores de campos configurables / extraídos por IA |
| `AdDocumentoClasificacion` | Clasificación del documento en motor y listados |
| `AdDocumentoEstatus` | Estatus del ciclo de vida |
| `AdEventos` | Tipos de evento en bitácora |
| `AdNotifResultado` | Resultado de envío de notificación |

Equivalentes JS: `src/constants/adCampos.js`, `adDocumentoClasificacion.js`.

## DTOs de operaciones frecuentes

| Clase | Campo clave en `Data` |
|-------|------------------------|
| `DocumentoRequest` | `IdDocumento`, `NombreArchivo`, `DocBase64` (IA / archivos) |
| `RechazarDocumentoRequest` | `IdDocumento`, motivo rechazo |
| `AsociacionOperacionRequest` | Referencia, rectificación, pedimento |
| `SugerenciaPedimentosRequest` | Criterios de búsqueda de pedimentos |
| `AduanaRequest` | Filtros de aduana |
| `CampoExtraidoIA` | Respuesta de extracción IA |
| `InsertarDatosPedimentoResultDto` | Resultado SP inserción pedimento |
| `CspAdDiagnosticoSugerenciaPedimentoRow` | Fila diagnóstico sugerencias |

## Entidades expuestas en JSON

Muchas respuestas devuelven entidades EF o proyecciones con nombres de tabla, por ejemplo:

- `AdDocumentos` (+ navegación `Campos`, `Archivo`, identificadores, permisos)
- `AdMotorConfigHeader` + lista `Detalles`
- `AdNotifConfig`
- `CspAdDocumentosPorEstatus` (listado repositorio)

El serializador usa **camelCase** en JSON (`idCliente`, `idTipoDocumentoVucem`). El front debe enviar y leer en camelCase.

## Mapa endpoint ↔ servicio front

Detalle completo en `src/Aduax.AuditorDocumentos.Web/readme.txt`. Resumen:

### Documentos (`documentosService.js`)

| Acción API | Función JS |
|------------|------------|
| ExtraDatosDocumentoIa | `extraDatosDocumentoIa` |
| PreguardaDocumento | `preguardaDocumento` |
| GuardaDocumentoPendienteAprobacion | `guardaDocumentoPendienteAprobacion` |
| AutorizaDocumento | `autorizaDocumento` |
| RechazarDocumento | `rechazarDocumento` |
| EliminarDocumento | `eliminarDocumento` |
| ObtenerDocumentos | `obtenerDocumentos` |
| ObtenerDocumentoPorId | `obtenerDocumentoPorId` |
| ValidarDocumentoVigenteAprobado | `validarDocumentoVigenteAprobado` |
| AltaAsociacionOperacion | `altaAsociacionOperacion` |

### MotorConfig (`motorConfigService.js`)

Catálogos paginados, CRUD motor, validaciones (`ValidaFraccion`, `ValidaUnidadMedida`, `ValidaPais`), sugerencias y diagnóstico de pedimentos, `ValidaUsuarioAdminLider` (GET).

### NotificacionConfig (`notificacionesService.js`)

`ObtenerNotifConfig`, `GuardarNotifConfig`, `RecuperaCorreosRecordados`, `EjecutarNotificaciones`.

## Códigos HTTP

- **200** + `success: true` — operación correcta.
- **400** — validación de entrada (`success: false`, `message` descriptivo).
- **401** — token ausente, inválido o usuario no recuperable del token.
- Errores no controlados — 500; el front muestra `message` si viene en el cuerpo.

## Al agregar un contrato nuevo

1. Clase en **VModels** (preferir tipos simples, sin referencias a EF).
2. Usar en firma del controlador `[FromBody]`.
3. Documentar en `readme.txt` del Web y función en el `*Service.js` con `@typedef`.
4. Si es enum, duplicar constante en `constants/` del front.
