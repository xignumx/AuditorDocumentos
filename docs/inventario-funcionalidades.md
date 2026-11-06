# Inventario de funcionalidades — Auditor de Documentos

Documento de apoyo para el **análisis de mejoras** de la plataforma. Describe **qué existe hoy** en la aplicación (capacidades de usuario, reglas de negocio y superficies de API), no cómo desplegarla ni cómo extender el código.

| Dato | Valor |
|------|--------|
| Fecha de corte | 2026-10-22 |
| Fuentes | Código en `src/` y documentación en `docs/` |
| Alcance | Funcionalidades implementadas en API + SPA. No incluye ajustes SQL pendientes de ejecutar. |

Para arquitectura, contratos y convenciones de desarrollo consultar [README.md](./README.md), [arquitectura-general.md](./arquitectura-general.md), [api-backend.md](./api-backend.md), [frontend-web.md](./frontend-web.md) y [vmodels-y-contratos-api.md](./vmodels-y-contratos-api.md).

---

## 1. Qué es la plataforma

**Auditor de Documentos (ITAduax / Aduax)** gestiona documentos aduaneros ligados al catálogo **VUCEM** (vía **EDOCS**). El usuario:

1. Configura, por cliente y tipo de documento, qué campos aplican y cómo se comportan.
2. Da de alta un PDF, opcionalmente extrae datos con **IA (Vertex)**, y lo envía a aprobación.
3. Autoriza o rechaza el documento.
4. Lo asocia a un tráfico o pedimento (operación ADUASIS).
5. Lo envía a **VUCEM** con sello de cliente o de agente.
6. Recibe avisos de vencimiento por correo.

El front es una SPA React bajo `/AuditorDocumentos`. El usuario llega con `?token=` (OneCore). El cliente seleccionado en el header es el contexto de **todas** las pantallas.

```text
Config. documentos  →  Alta documento  →  Repo. documentos  →  Asociación  →  VUCEM
         ↓
Config. notificaciones  →  Job diario de vencimiento (03:00)
```

---

## 2. Módulos y pantallas

| Módulo | Ruta | Quién lo ve | Función |
|--------|------|-------------|---------|
| Configuración del motor | `/config` | ADM, LIDER, CALIDAD (y excepción `mxochipa`). El menú se oculta al resto; la ruta no tiene guard. | Matriz de campos, clasificación, acción en operación, perfil de acciones críticas |
| Repositorio | `/repositorio` (inicio) | Cualquier usuario autenticado | Listado, filtros, ver PDF, autorizar, rechazar, eliminar, asociar, VUCEM |
| Alta de documento | `/repositorio/nuevo` | Cualquier usuario autenticado | Carga PDF, extracción IA, captura y envío a pendiente |
| Notificaciones | `/notificaciones` | Cualquier usuario autenticado | Correos y días de aviso por tipo VUCEM |
| Header | todas | Todos | Navegación + selector paginado de cliente ADUASIS |

Sin cliente seleccionado las pantallas no cargan datos.

---

## 3. Acceso, cliente y permisos

### 3.1 Autenticación

- Token cifrado OneCore en la URL (`?token=`).
- El front lo envía como `Authorization: Bearer`.
- La API valida endpoints `[Authorize]`; Swagger queda fuera de esa validación.

### 3.2 Dos capas de permiso (no son equivalentes)

| Capa | Qué controla | Criterio |
|------|----------------|----------|
| Acceso a **Config. documentos** | Menú `/config` | `fusuario.IdClase` ∈ `ADM`, `LIDER`, `CALIDAD`, o usuario `mxochipa` (`GET MotorConfig/ValidaUsuarioAdminLider`) |
| **Acciones críticas** | Autorizar, rechazar, eliminar documento, asociar y desasociar operación | Campo `PerfilCarga` del motor (`G` / `A` / `L`) vs `IdClase` del usuario |

**Perfil para acciones críticas** (`PerfilCarga`):

| Código | Etiqueta UI | Quién puede ejecutar acciones críticas |
|--------|-------------|----------------------------------------|
| `G` | Acceso general | Cualquier usuario autenticado |
| `A` | Admin | Solo `IdClase = ADM` |
| `L` | Líder | Solo `IdClase = LIDER` |

Reglas vigentes:

- El **alta no se bloquea** por este perfil.
- Si **no hay motor persistido**, las acciones críticas se **niegan**.
- **CALIDAD** puede entrar a `/config`, pero en un motor `A` o `L` no puede autorizar/asociar/eliminar.
- Consultas, visor PDF y envío VUCEM **no** usan este perfil.

Detalle de negocio: [ajustes-perfil-carga-motor/decisiones-negocio.md](./ajustes-perfil-carga-motor/decisiones-negocio.md).

---

## 4. Configuración del motor (`/config`)

Unidad de configuración: **un motor por cliente + tipo VUCEM**.

### 4.1 Qué se configura

1. **Visibilidad y obligatoriedad** de campos 3–24 (toggles Visible / Obligatorio; si se oculta, Obligatorio se apaga).
2. **Clasificación del documento** (una sola):
   - Identificador general
   - Identificador de partida
   - Permiso
3. **Acción en operación** (`AccionPedimento`):
   - `S` Afecta operación
   - `N` No afecta operación
   - `P` Pregunta si afecta (default)
4. **Perfil para acciones críticas** (`PerfilCarga`): `G` / `A` / `L` (default `G`).

Badge **Configurado** si el header ya existe; si no, **Pendiente de configuración**. Acciones: **Guardar** (con confirmación) y **Deshacer cambios**.

### 4.2 Defaults al crear un motor

- Campos 3–19 visibles; 20–24 (Factura, Fecha factura, Valor USD, Guía/BL, Pedimento) **no visibles**.
- Único obligatorio por defecto: **Vigencia hasta**.
- Al guardar, la API exige: al menos un detalle; al menos un campo visible distinto de IdCliente / RfcCliente / TipoPedimento; al menos un campo visible y obligatorio.

### 4.3 Bloqueo de clasificación

Si el motor ya está persistido y hay documentos en Pendiente, Aprobado, Vinculado a operación o Digitalizado eDOCS, **no se puede cambiar la clasificación**. Rechazado, Eliminado, Registro y Error de digitalización no bloquean.

### 4.4 Cómo gobierna el resto de la app

El mismo header se usa en:

- Alta: qué campos se muestran y cuáles son obligatorios.
- Detalle/autorización: mismos campos en solo lectura.
- Sugerencia de pedimentos: filtros = campos **visible + obligatorio + con valor**.
- Acciones críticas: `PerfilCarga`.
- Notificaciones: no se configuran si no existe motor real.

---

## 5. Alta de documento (`/repositorio/nuevo`)

### 5.1 Flujo

1. Seleccionar cliente (header) y tipo VUCEM (sidebar con búsqueda e infinite scroll; solo tipos con `ActivoAuditorDocumentos` y `PrefijoEI`).
2. Validar que exista motor. Si no: alerta *“Configura primero los documentos.”*
3. Aviso (no bloqueo) si ya hay un documento **vigente** en Aprobado / Vinculado / Digitalizado (`ValidarDocumentoVigenteAprobado`).
4. Cargar PDF → **preguardado automático** (estatus Registro).
5. Opcional: **Extraer datos** con IA.
6. Completar campos visibles/obligatorios y el bloque de clasificación.
7. **Guardar** → confirmación → estatus Pendiente; se sube el archivo a File Storage (AWS) con nombre eDOCS.

Al cambiar cliente o tipo se resetean archivo, IA, campos y preguardado.

### 5.2 Carga de archivo

- Solo PDF (dropzone + vista previa).
- Se valida magic bytes `%PDF-` / `%%EOF`.
- El botón Guardar requiere cliente + tipo + motor existente.
- Extraer datos exige archivo ya preguardado.

### 5.3 Campos de captura (según visibilidad del motor)

| Campo | Control | Validación visible |
|-------|---------|--------------------|
| Proveedor | select paginado | Catálogo del cliente |
| Tipo pedimento | texto 2 dígitos | Solo `10`, `20`, `21`, `30` |
| Tipo de operación | select | Importación / Exportación; al cambiar borra clave de pedimento |
| Clave de pedimento | multi-select | Catálogo de regímenes filtrado por tipo de operación |
| Producto / No de parte | tags (`;`) | — |
| Descripción de mercancía | tags | — |
| Fracciones | tags | 6 u 8 dígitos + catálogo ADUASIS |
| Nico | tags | Máx. 2 caracteres |
| Cantidad | número | — |
| Unidad de medida (UMT) | tags | Catálogo ADUASIS |
| País origen/destino | tags | 2–3 caracteres + catálogo |
| Vigencia desde / hasta | fecha | Hasta **mayor que hoy**; si ambas visibles, desde ≤ hasta |
| Aduana | select paginado | Catálogo ADUASIS |
| Firma de Representante Legal | texto | — |
| Nom | texto | — |
| Valor comercial | número | `> 0` |
| Factura | texto | Default no visible |
| Fecha factura | fecha | Formato `YYYY-MM-DD`, no futura |
| Valor USD | número | `> 0`; independiente de valor comercial |
| Guía/BL | tags alfanuméricos | Se quitan símbolos |
| Pedimento | 15 dígitos | Año(2)+aduana(2)+patente(4)+número(7) |

### 5.4 Bloques de clasificación (alta)

Si hay clasificación en el motor, solo se muestra el bloque correspondiente. Si aún no hay, se muestran los tres.

- **Identificador general:** Identificador* (máx. 2), Complemento, Complemento 2, Complemento 3.
- **Identificador partida:** Identificador*, Complemento 1–3.
- **Permiso:** Régimen* (máx. 2), Permiso* (máx. 2), Número, Firma.

Al persistir, la API exige **exactamente una** entidad de clasificación y que coincida con el motor.

---

## 6. Extracción con IA

Acción de usuario: botón **Extraer datos** en el alta.

Comportamiento:

1. Toma solo campos **visibles** del motor.
2. Usa prompt de documento activo + prompts parciales de campo (`ad_ia_prompt_*`).
3. Envía el PDF a **Google Vertex AI** (troceo si supera ~25 páginas).
4. Devuelve valores al formulario (fechas a `yyyy-MM-dd`, pedimento a 15 dígitos, Guía/BL a tags).
5. Registra bitácora `DOC_ENVIO_IA` / `DOC_RESULTADO_IA` y `ad_ia_ejecucion`.

Campos de lectura IA `CadenaOriginal` (100) y `CodigoQR` (101) existen en el enum; **no** se editan en `/config` ni filtran sugerencia de pedimentos.

---

## 7. Repositorio (`/repositorio`)

### 7.1 Listado y filtros

- Carga todos los documentos del cliente (`ObtenerDocumentos`).
- Sidebar **Resumen**: KPI total + botones por tipo VUCEM y por estatus (con conteos cruzados).
- Búsqueda local: tipo, prefijo EI, nombre de archivo, ruta AWS, id cliente.
- Columnas: Documento, Prefijo, VUCEM, Vigencia, Archivo, Clasificación, Estatus, Creación, Creado por, Acciones.

### 7.2 Ciclo de vida (estatus)

| Id | Estatus | Cómo se llega |
|----|---------|----------------|
| 1 | Registro | Preguardado al cargar PDF |
| 2 | Pendiente | Guardar en alta |
| 3 | Aprobado | Autorizar |
| 4 | Rechazado | Rechazar con motivo |
| 5 | Vinculado a operación | Asociar operación |
| 6 | Digitalizado eDOCS | Envío VUCEM exitoso |
| 7 | Error digitalización | Definido; **la API no lo asigna** |
| 8 | Eliminado | Baja lógica |

```text
Registro → Pendiente → Aprobado → Vinculado a operación → Digitalizado eDOCS
                 ↘ Rechazado
Cualquier estatus (salvo ya Eliminado) → Eliminado
```

### 7.3 Acciones por fila

| Acción | Estatus | Habilitada si |
|--------|---------|----------------|
| Ver (detalle + PDF) | Todos | Siempre |
| Autorizar | Pendiente | `puedeAccionCritica` |
| Eliminar documento | Pendiente, Aprobado, Vinculado, Digitalizado | `puedeAccionCritica` |
| Ver comentarios de rechazo | Rechazado | Siempre |
| Relacionar con operación | Aprobado, Vinculado, Digitalizado | `puedeAccionCritica` |

Estatus Registro, Error digitalización y Eliminado solo tienen **Ver**.

### 7.4 Autorizar / rechazar / ver

- **Ver** y **Autorizar** abren el mismo modal de campos capturados (solo lectura, filtrados por visibilidad del motor).
- Autorizar muestra **Aprobar** / **Rechazar**.
- Rechazo: motivo obligatorio, máx. 450 caracteres.
- API: solo se autoriza o rechaza si el documento está en **Pendiente**.
- Aprobado/rechazado se guarda también en `ad_aprobaciones` (una fila por documento).

### 7.5 Eliminar documento

- Baja **lógica** (estatus Eliminado).
- Si está Vinculado o Digitalizado, el mensaje aclara que **no desvincula** datos ya enviados a la operación.
- No anula eDOCS, no borra AWS y no revierte identificadores/permisos.

### 7.6 Visor PDF

Abre la `awsRuta` en iframe. Si no hay URL o no es http(s), muestra alerta.

---

## 8. Asociación a operación

Modal **Relacionar operación** desde el repositorio.

### 8.1 Sugerencia de pedimentos / tráficos

- Combobox paginado alimentado por `csp_Ad_SugerenciaPedimentos_v2`.
- Etiqueta: `{referencia}/{rectificación} :: {aduana} {patente} {pedimento}`.
- Los tráficos se identifican por `id_trafico` (sin `/`).
- Excluye operaciones ya asociadas al documento.
- Filtros AND entre campos del documento que estén visibles, obligatorios y con valor; OR entre valores múltiples (`;`).
- **Atajo Pedimento (campo 24):** si está visible + obligatorio + 15 dígitos, se omiten los demás filtros y la rama de tráfico.

Campos que **no** filtran: IdCliente, RfcCliente, Cantidad, vigencias, Firma RL, Nom, Valor comercial, Valor USD, CadenaOriginal, CodigoQR.

Si la primera página de sugerencias viene vacía, aparece el diagnóstico **“¿Por qué no aparece mi operación?”** (`csp_Ad_DiagnosticoSugerenciaPedimentos_v2`): el usuario captura pedimento/referencia/tráfico y ve validaciones OK/FALLO con detalle documento vs operación.

Documentación de reglas: [ajustes-072026/decisiones-filtros-sugerencia-pedimentos.md](./ajustes-072026/decisiones-filtros-sugerencia-pedimentos.md), [ajuste-separacion-traficopedimento/](./ajuste-separacion-traficopedimento/).

### 8.2 Alta de asociación

1. Si la sugerencia **no tiene pedimento** (tráfico): aviso de que identificadores/permisos **no se trasladarán**.
2. Según `AccionPedimento` del motor:
   - `P`: el usuario elige si traslada datos al pedimento/tráfico.
   - `S`: afecta siempre.
   - `N`: no afecta.
3. Si afecta: SP `csp_ad_InsertaDatosPedimento_v2`. En clasificación partida/permiso, si el SP no inserta/actualiza registros, **se aborta** toda la asociación.
4. Persiste `ad_documento_operacion`.
5. Alta en eDOCS (`csp_Archivos_Ins_EdocsYVucem_2023`): proceso `"1"` si hay rectificación (pedimento), `"3"` si es tráfico.
6. Relación `ad_rel_documento_edoc`.
7. Estatus → Vinculado a operación (si aún no es 5 o 6).

La API **no** exige que el documento esté Aprobado; la UI sí limita el botón a estatus 3/5/6. No hay unique constraint de (documento, referencia) en código.

### 8.3 Pedimentos asociados (tabla)

Columnas: Id referencia, Id rectificación, Pedimento, eDocument, Fecha de asociación, Acción. Búsqueda local, paginación (5), refresco.

Acciones por fila:

| Acción | Condición |
|--------|-----------|
| Enviar / Reenviar a VUCEM | Sin número de operación VUCEM y sin eDocument válido (`0000000000000` = pendiente) |
| Ver mensaje de envío VUCEM | Hay texto en `mensaje` |
| Eliminar asociación | Pedimento no pagado, sin número VUCEM y sin eDocument válido; además `puedeAccionCritica` |

### 8.4 Eliminar asociación

- Anula archivos en eDOCS (`Status = 0`).
- Borra `ad_rel_documento_edoc` y `ad_documento_operacion`.
- **No** revierte identificadores/permisos ya transferidos.
- **No** baja el estatus del documento aunque no queden asociaciones.
- **No** borra el PDF en File Storage.

Detalle: [eliminar-asociacion-operacion/decisiones-negocio.md](./eliminar-asociacion-operacion/decisiones-negocio.md).

---

## 9. Envío a VUCEM / sellos / eDocument

El envío **no** ocurre al asociar. Primero queda el archivo en eDOCS; el usuario dispara el SOAP VUCEM por fila.

### 9.1 Selección de sello

Modal **Selección de sello VUCEM**:

- Correo opcional (si vacío, la API usa el del usuario o un fallback).
- **Sello cliente**: habilitado solo si hay `idSelloCliente > 0` para el RFC.
- **Agente aduanal**: siempre ofrecido (la API resuelve sello por patente).

### 9.2 Resultado

- Éxito: estatus **Digitalizado eDOCS**, bitácora `DOC_DIGITALIZADO`.
- Fallo: el estatus **no cambia** (no se usa Error digitalización); bitácora `DOC_ERROR_EDOCS`; se puede reintentar si hay mensaje y aún no hay número/eDocument válido.
- Auditor **no escribe** el eDocument; lo hace el worker VUCEM. La UI lo lee después.

Plan y contrato: [auto-edocs/plan-integracion-envio-vucem-sellos.md](./auto-edocs/plan-integracion-envio-vucem-sellos.md).

---

## 10. Notificaciones de vencimiento

### 10.1 Configuración (`/notificaciones`)

Prerrequisito: motor real para cliente + tipo VUCEM.

El usuario configura:

- Lista de correos (tags).
- Un plazo entre **7 / 15 / 30 / 45** días (en UI es exclusivo; la API y el job aceptan lista).
- Switch **Recordar correos** (recupera últimos correos usados vía SP).

Plantillas HTML: **no hay CRUD** en la app. Se usa la única plantilla activa (`ad_notif_template`). Placeholders: cliente, documento, fecha de vencimiento, días, URL del archivo, URL de plataforma.

### 10.2 Envío

- **Job diario a las 03:00** (hora del servidor). Si falla, reintenta en 1 hora.
- Por cada config y cada día de antelación: documentos por vencer (`csp_Ad_ObtieneDocumentosPorVencer`).
- Destinatarios: correos de la config **más** el correo del usuario que creó el documento.
- Resultado en `ad_notif_envios` (enviado / fallido).
- `POST NotificacionConfig/EjecutarNotificaciones` existe en API para corrida manual; **el front no lo expone**.

---

## 11. Catálogos y validaciones de apoyo

Expuestos por `MotorConfig` y usados en alta, config y asociación:

| Capacidad | Fuente |
|-----------|--------|
| Tipos VUCEM | EDOCS `Tb_DocumentosVucem` (activos para Auditor y con prefijo EI) |
| Clientes | ADUASIS `FCliente` (excluye clave `"0"`) |
| Aduanas | ADUASIS `FAduana` |
| Regímenes / clave pedimento | ADUASIS `FRegimen` filtrado por tipo de operación |
| Proveedores | SP `ad_proveedores_listar_paginado` (por cliente) |
| Fracción | ADUASIS `frel_prod_frac` |
| Unidad de medida | ADUASIS `funidad_universal` |
| País | ADUASIS `fpais` |
| Sugerencia / diagnóstico de operaciones | SPs `_v2` en ADUASIS |
| Usuario / clase / correo | ADUASIS `FUsuario` |

---

## 12. Integraciones que sostienen las funciones

| Integración | Para qué la usa el usuario (indirectamente) |
|-------------|---------------------------------------------|
| **DesarrolloDB** | Documentos, motor, IA, notificaciones, bitácora, relación eDOCS |
| **ADUASIS** | Cliente, catálogos, clase de usuario, sugerencia de pedimentos, inserción de identificadores/permisos, pago de pedimento |
| **EDOCS** | Catálogo VUCEM, alta/anulación de archivos, sellos |
| **File Storage (AWS)** | Guardar y visualizar el PDF |
| **Google Vertex AI + GCS** | Extracción de campos del PDF |
| **Vucem.Api** | Envío SOAP / eDocument con sello |
| **SMTP / correo** | Avisos de vencimiento |
| **OneCore security** | Login por token |

---

## 13. Bitácora

Tabla `ad_bitacora_eventos`. Eventos que **sí** se escriben hoy:

| Evento | Momento |
|--------|---------|
| `DOC_ENVIO_IA` / `DOC_RESULTADO_IA` | Extracción Vertex |
| `DOC_APROBADO` / `DOC_RECHAZADO` | Autorización |
| `DOC_ASOCIADO_OPERACION` | Alta asociación |
| `DOC_ENVIO_EDOCS` | Alta archivo en eDOCS (no el SOAP) |
| `DOC_DIGITALIZADO` / `DOC_ERROR_EDOCS` | Resultado envío VUCEM |
| `DOC_CAMBIO_ESTATUS` | Eliminar documento |
| `DOC_DESASOCIADO_OPERACION` | Eliminar asociación |

Definidos y **no usados**: `DOC_CREADO`, `DOC_CARGA_ARCHIVO`, `DOC_NOTIF_*`, `DOC_ACTUALIZACION_DATOS`.

No hay pantalla de consulta de bitácora en el front.

---

## 14. Mapa rápido: función de usuario → API

### Documentos — `POST /api/Documentos/...`

| Función | Acción |
|---------|--------|
| Extraer datos IA | `ExtraDatosDocumentoIa` |
| Preguardar al cargar PDF | `PreguardaDocumento` |
| Enviar a aprobación | `GuardaDocumentoPendienteAprobacion` |
| Aprobar | `AutorizaDocumento` |
| Rechazar | `RechazarDocumento` |
| Eliminar documento | `EliminarDocumento` |
| Listar repositorio | `ObtenerDocumentos` |
| Ver detalle | `ObtenerDocumentoPorId` |
| Aviso de vigente | `ValidarDocumentoVigenteAprobado` |
| Asociar operación | `AltaAsociacionOperacion` |
| Lookup de sellos | `ObtenerSellosVucemDisponibles` |
| Enviar a VUCEM | `EnviarDocumentoVucem` |
| Quitar asociación | `EliminarAsociacionOperacion` |

### Motor — `POST /api/MotorConfig/...` (salvo la GET indicada)

| Función | Acción |
|---------|--------|
| Catálogos | `ObtenerDocumentosVucem`, `ObtenerClientes`, `ObtenerAduanas`, `ObtenerRegimenes`, `ObtenerProveedores` |
| CRUD motor | `ObtenerMotorConfig`, `GuardarMotorConfig`, `ValidaExistenciaMotorConfig` |
| Cambio de clasificación | `PuedeCambiarClasificacion` |
| Validar captura | `ValidaFraccion`, `ValidaUnidadMedida`, `ValidaPais` |
| Sugerencias | `ObtenerSugerenciaPedimentos`, `DiagnosticoSugerenciaPedimentos` |
| Permiso menú config | `GET ValidaUsuarioAdminLider` |

### Notificaciones — `POST /api/NotificacionConfig/...`

| Función | Acción | En UI |
|---------|--------|-------|
| Leer / guardar config | `ObtenerNotifConfig`, `GuardarNotifConfig` | Sí |
| Recordar correos | `RecuperaCorreosRecordados` | Sí |
| Ejecutar job ahora | `EjecutarNotificaciones` | No |

---

## 15. Consideraciones para el análisis de mejoras

Hechos del producto actual que suelen importar al priorizar cambios. No son un backlog; son **huecos o asimetrías** detectadas al inventariar.

### 15.1 Superficie de usuario

- Cuatro pantallas; la lógica de repositorio y alta está concentrada en dos páginas grandes.
- `/config` se oculta en el menú pero se puede abrir por URL.
- `/notificaciones` no exige perfil admin/líder.
- No hay UI para: bitácora, plantillas de correo, ejecución manual de vencimientos, consulta de `ad_ia_ejecucion`, ni estatus Error digitalización.

### 15.2 Ciclo de vida

- Eliminar documento no limpia asociaciones, eDOCS ni AWS.
- Eliminar asociación no revierte `csp_ad_InsertaDatosPedimento_v2` ni cambia el estatus del documento.
- Asociación no valida estatus en API (la UI sí filtra).
- Aviso de “documento vigente” no bloquea un segundo alta.
- Estatus 7 nunca se asigna; el fallo VUCEM solo deja mensaje y bitácora.

### 15.3 Permisos y consistencia

- Dos modelos de autorización (`ValidaUsuarioAdminLider` vs `PerfilCarga`) con tratamiento distinto de CALIDAD.
- Usuario hardcode `mxochipa` en acceso a config (y fallback de correo VUCEM).
- `AccionPedimento` vive como string en header/front; la API solo recibe el bool `afectaOperacion`.

### 15.4 Notificaciones e IA

- UI de días de aviso: un solo valor; job: lista.
- Eventos de notificación definidos y no escritos en bitácora.
- Campos IA 100–101 y campos 1–2 no se gestionan en `/config`.

### 15.5 Integración VUCEM

- `rfcConsulta` en código está invertido respecto al comentario XML y a la guía de cliente; conviene validar con negocio antes de tocarlo.
- Timeout largo del envío; el front traduce 504/HTML a mensajes amigables.

### 15.6 Ajustes documentados y no necesariamente en producción

Revisar estado real de BD/QA al analizar:

| Paquete en `docs/` | Tema | Nota en índice |
|--------------------|------|----------------|
| [ajustes-072026/](./ajustes-072026/) | Campos IA 20–24 + SPs `_v2` | Implementado en `src/`; pendiente QA/promoción |
| [ajustes-perfil-carga-motor/](./ajustes-perfil-carga-motor/) | `PerfilCarga` | Implementado en `src/`; pendiente script BD si falta columna |
| [eliminar-asociacion-operacion/](./eliminar-asociacion-operacion/) | Quitar asociación | Implementado en `src/`; pendiente QA |
| [ajuste-separacion-traficopedimento/](./ajuste-separacion-traficopedimento/) | Tráficos visibles aunque ya tengan pedimento | Solo SQL ADUASIS; pendiente ejecutar |

---

## 16. Cómo usar este inventario

1. Tomar cada sección 4–10 como **capacidad actual** (qué puede hacer el usuario).
2. Contrastar con el objetivo de mejora: ¿es extensión de una capacidad, cambio de regla, o módulo nuevo?
3. Si la mejora toca reglas de motor, pedimentos, VUCEM o permisos, leer primero las carpetas de `docs/` citadas arriba.
4. El mapa de la sección 14 sirve para acotar impacto API/front sin reabrir la arquitectura completa.
