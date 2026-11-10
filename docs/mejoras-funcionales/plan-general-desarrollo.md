# Plan general de desarrollo: ADX-OPER-26-0039 Auditor Documentos - Mejoras

Fuentes: PBL V2.0, SprintBacklog V1.6 (hoja Estimación), `especificaciones-prototipos.md` y prototipos HTML.
Detalle del trabajo de Dev 2: [plan-desarrollo-dev2.md](./plan-desarrollo-dev2.md).

**Última actualización:** 2026-11-10

## Leyenda de estado

| Marca | Significado |
|-------|-------------|
| [x] | Hecho: código listo y compilando. Scripts SQL escritos pero no ejecutados; falta QA. |
| [~] | Parcial: queda un punto abierto indicado en la fila. |
| [ ] | Pendiente. |
| [?] | Sin información: el avance lo lleva otra persona y no se ha reportado aquí. |

## 1. Objetivo

Optimizar el Auditor de Documentos con prelectura OCR asíncrona, clasificación por IA, integración con VUCEM y Aduabook 3, visibilidad directa del folio de Invoice y gobierno de reglas para Compliance.

## 2. Resumen de avance (horas de desarrollo según SBL)

| Responsable | Horas SBL | Con código listo | Pendiente | Sin información |
|-------------|-----------|------------------|-----------|-----------------|
| Dev 1 | 46 | - | - | 46 [?] |
| Dev 2 | 46 | 27 | 19 | - |
| **Total** | **92** | **27** | **19** | **46** |

Las tareas generales del SBL (sección 5) no están incluidas en estas horas.

## 3. Requerimientos por épico

| Épico | ID | Requerimiento | Responsable | Horas | Estado |
|-------|----|---------------|-------------|-------|--------|
| 1 | ID_01 | Carga masiva por referencia, prelectura OCR en segundo plano y tablero de estatus | Dev 1 | 9 | [?] |
| 1 | ID_02 | Selección masiva, transmisión a VUCEM en lote e historial de envíos | Dev 1 | 10 | [?] |
| 2 | ID_01 | Sincronización automática de expedientes y prealertas desde Aduabook 3 | Dev 1 | 8 | [?] |
| 3 | ID_01 | Prompts y diccionario de sinónimos ES/EN (`/config/ia-rules`) | Dev 2 | 19 | [x] |
| 3 | ID_02 | Interpretación inteligente de tablas y confirmación asistida en 1-clic | Dev 1 | 11 | [?] |
| 4 | ID_01 | Visualización directa de folio Invoice/Factura/Permiso en repositorio | Dev 1 | 8 | [?] |
| 5 | ID_01 | Perfil COMPLIANCE y bitácora de auditoría de reglas | Dev 2 | 8 | [~] |
| 5 | ID_02 | Carga masiva de la matriz de validación (`/config/compliance`) | Dev 2 | 9 | [ ] |
| 5 | ID_03 | Reportes e indicadores (`/reportes`) | Dev 2 | 10 | [ ] |

## 4. Tareas de desarrollo

### Dev 1

| Épico / ID | Tarea | Horas | Estado |
|------------|-------|-------|--------|
| E1-ID01 | Tablas y campos de control de lotes (`ad_lote_carga`), estados de tarea asíncrona y SP de avance | 2 | [?] |
| E1-ID01 | Endpoint `POST /api/Documentos/CargaMasivaReferencia` y procesamiento en segundo plano | 2 | [?] |
| E1-ID01 | Llamadas asíncronas no bloqueantes a Vertex AI y clasificación automática de estatus | 2 | [?] |
| E1-ID01 | Drag & Drop por referencia, barra de avance y tablero de estatus | 3 | [?] |
| E1-ID02 | Tablas y SPs de lotes de envío VUCEM, historial de respuestas SOAP y reintentos | 2 | [?] |
| E1-ID02 | Endpoint `POST /api/Documentos/EnviarVucemLote` con procesamiento por bloques | 3 | [?] |
| E1-ID02 | Validación masiva de sellos, actualización en lote a Digitalizado eDOCS y reintentos | 2 | [?] |
| E1-ID02 | Selección múltiple, botón de envío masivo y modal de sello con resultados | 3 | [?] |
| E2-ID01 | Tabla/log de ingesta de prealertas (`ad_prealertas_aduabook`) y SP anti-duplicados | 2 | [?] |
| E2-ID01 | Webhook `POST /api/Integraciones/Aduabook/Prealerta` | 2 | [?] |
| E2-ID01 | Mapeo de archivos recibidos al flujo de prelectura con marca de origen | 2 | [?] |
| E2-ID01 | Badge "Origen: Aduabook 3" e indicador de sincronización | 2 | [?] |
| E3-ID02 | Tabla de métricas de precisión OCR y retroalimentación (`ad_ia_feedback`) | 2 | [?] |
| E3-ID02 | Endpoint `POST /api/Documentos/ConfirmarLecturaIa` | 2 | [?] |
| E3-ID02 | Refinar prompts del OCR para encabezados heterogéneos y partidas | 3 | [?] |
| E3-ID02 | Revisión asistida (visor dividido PDF vs formulario) con confirmación 1-clic | 4 | [?] |
| E4-ID01 | Modificar `csp_Ad_ObtenerDocumentos` para exponer el campo 20/24 | 2 | [?] |
| E4-ID01 | DTOs y mapeos del controller `ObtenerDocumentos` | 2 | [?] |
| E4-ID01 | Búsqueda y filtrado por folio de Invoice/Permiso | 2 | [?] |
| E4-ID01 | Columna "Número de Factura / Invoice / Permiso" en `/repositorio` | 2 | [?] |

### Dev 2

| Épico / ID | Tarea | Horas | Estado |
|------------|-------|-------|--------|
| E3-ID01 | Tablas de diccionario, historial de versiones y semilla | 3 | [x] |
| E3-ID01 | Endpoints CRUD de prompts y diccionario | 3 | [x] |
| E3-ID01 | Inyector dinámico de sinónimos y prompts en la llamada a Vertex AI | 3 | [x] |
| E3-ID01 | Vista `/config/ia-rules` | 4 | [x] |
| E3-ID01 | Equivalencias dinámicas de UM | 6 | [x] |
| E5-ID01 | Rol COMPLIANCE y tabla de bitácora | 2 | [~] Falta el alta del rol |
| E5-ID01 | Filtros de autorización en `MotorConfigController` | 2 | [x] |
| E5-ID01 | Bitácora de auditoría de cambios en `/config` | 2 | [x] |
| E5-ID01 | Menú y accesos condicionales por rol en la UI | 2 | [x] |
| E5-ID02 | SP `csp_Ad_CargaMasivaMatrizConfig` | 2 | [ ] |
| E5-ID02 | Endpoint `POST /api/MotorConfig/CargaMasivaMatriz` y plantilla Excel | 2 | [ ] |
| E5-ID02 | Pre-validación y prevención de sobrescritura accidental | 2 | [ ] |
| E5-ID02 | Pantalla `/config/compliance` | 3 | [ ] |
| E5-ID03 | Vistas de BD (`vw_ad_metricas_sistema`) | 2 | [ ] |
| E5-ID03 | Endpoints `DashboardMetricas` y `ExportarExcel` | 2 | [ ] |
| E5-ID03 | Lógica de cálculo de KPIs y generación de Excel/CSV | 2 | [ ] |
| E5-ID03 | Pantalla `/reportes` | 4 | [ ] |

## 5. Tareas generales y de otros roles (SBL)

Las horas de estas filas no entran en el resumen de la sección 2. El SBL no indica qué desarrollador toma cada tarea general.

| Rol | Tarea | Horas | Estado |
|-----|-------|-------|--------|
| Desarrollador | Revisiones UX | 1 | [ ] |
| Desarrollador | KO de desarrollo (LT a Devs) | 1 | [ ] |
| Líder Técnico | Control de versión en TFS (rama Dev, Main y Rel) | 1 | [?] |
| Desarrollador | Video técnico | 1 | [ ] |
| Desarrollador | Automatización de pruebas | 1 | [ ] |
| Desarrollador | Log para validación de errores | 1 | [ ] |
| Desarrollador | Query de medición de uso y asignación en Portal Único | 1 | [ ] |
| Desarrollador | Video Happy Path para Kick off de pruebas | 1 | [ ] |
| Desarrollador | Preparación de escenarios para Kick off de pruebas | 1 | [ ] |
| Desarrollador | Estimación de riesgo por tecnología experimental | 1 | [ ] |
| Desarrollador | Implementación y pruebas en producción | 2 | [ ] |
| QA | Matriz de pruebas, ciclos de ejecución, smoke test, UAT y manual de usuario | - | [ ] |
| Soporte Técnico | Publicación e implementación | 2 | [ ] |

## 6. Dependencias entre desarrolladores

| Punto | Detalle | Estado |
|-------|---------|--------|
| `ExtraDatosDocumentoIa` | Dev 1 lo modifica (Vertex asíncrono, prompts del OCR) y Dev 2 agregó dos llamadas (sinónimos y normalización de UM). El constructor de `DocumentosController` también cambió. Coordinar la integración de ramas. | Abierto |
| Columnas de `ad_ia_ejecucion` | Dev 2 las agrega (fecha, usuario, duración, resultado y versión de prompt) en E5-ID03. | Pendiente |
| Datos para reportes | E5-ID03 necesita de Dev 1: `ad_ia_feedback`, tablas de lotes de envío VUCEM, `ad_lote_carga` y origen Aduabook. Confirmar nombres y columnas antes de crear las vistas. | Abierto |
| `/repositorio` | Dev 1 modifica la grilla (columna Invoice, badge de origen, casillas de selección). Sin cambios de Dev 2 en esa pantalla. | Sin conflicto |
| `AppHeader.jsx` y `App.jsx` | Dev 2 los modificó (permisos y ruta `/config/ia-rules`). Dev 1 puede necesitar tocarlos si agrega ítems de menú. | Posible conflicto |

## 7. Decisiones del proyecto

| # | Tema | Decisión |
|---|------|----------|
| 1 | Rol COMPLIANCE | `/config` por cliente no cambia. Las pantallas nuevas (ia-rules, compliance, carga masiva) son exclusivas de COMPLIANCE. Origen del rol abierto. |
| 2 | Unidad de medida | La IA devuelve la UM y se normaliza al `id_unidad_universal` mediante el diccionario. Equivalencias globales. |
| 3 | Carga masiva de matriz | Pantalla `/config/compliance`, archivo `.xlsx`; clientes elegidos con lista de checkboxes y buscador por razón social. |
| 4 | Dependencias nuevas | ClosedXML (API) y una librería de gráficas (Web, propuesta Recharts), con versión fija. |
| 5 | Coordinación Dev 1 / Dev 2 | Lógica nueva en clases aparte; `ExtraDatosDocumentoIa` solo recibe llamadas. |
| 6 | KPIs | Documentos procesados, % de lectura IA, envíos VUCEM, correcciones manuales y tiempo de atención (carga a autorización). Fórmulas en el plan de Dev 2. |
| 7 | Seguridad `MotorConfig` | Validación de rol en endpoints nuevos y en `GuardarMotorConfig`. |
| 8 | Scripts SQL | Se escriben como archivos en `docs/mejoras-funcionales/SQL/implementacion/`; no se ejecutan desde la herramienta. |

## 8. Scripts SQL

| # | Archivo | Responsable | Estado |
|---|---------|-------------|--------|
| 01 | DesarrolloDB Create ad_motor_config_bitacora | Dev 2 | Escrito, sin ejecutar |
| 02 | Alta de rol COMPLIANCE (ADUASIS, por confirmar) | Dev 2 | Pendiente (punto abierto) |
| 03 | DesarrolloDB Create ad_ia_diccionario y ad_ia_config_historial | Dev 2 | Escrito, sin ejecutar |
| 04 | DesarrolloDB Seed ad_ia_diccionario | Dev 2 | Escrito, sin ejecutar |
| 05 | DesarrolloDB alter ad_ia_ejecucion | Dev 2 | Pendiente |
| 06 | DesarrolloDB csp_Ad_CargaMasivaMatrizConfig | Dev 2 | Pendiente |
| 07 | DesarrolloDB vw_ad_metricas_sistema | Dev 2 | Pendiente |
| - | Scripts de Dev 1 (lotes, VUCEM, Aduabook, feedback IA, `csp_Ad_ObtenerDocumentos`) | Dev 1 | [?] |

Orden de ejecución en QA para lo de Dev 2: 01, 03, 04.

## 9. Puntos abiertos

| # | Punto | Responsable | Estado |
|---|-------|-------------|--------|
| 1 | Origen del rol COMPLIANCE (catálogo de `IdClase` y alta del rol) | Equipo | Abierto |
| 2 | Convivencia de defaults por tipo con los motores por cliente | Dev 2 / Analista | Abierto |
| 3 | Nombres de tablas y columnas de Dev 1 para los reportes | Dev 1 / Dev 2 | Abierto |
| 4 | Reparto de las tareas generales entre desarrolladores | LT | Abierto |
| 5 | Retirar el usuario `mxochipa` de la validación de Compliance cuando exista el rol | Dev 2 | Abierto |
| 6 | Estado de avance de Dev 1 (todas sus filas están sin información) | Dev 1 | Abierto |

## 10. Riesgos del PBL a vigilar

- Latencia de Vertex AI en picos de carga y archivos corruptos en el procesamiento en segundo plano (Épico 1).
- Caídas o timeouts de VUCEM y sellos vencidos en lotes grandes (Épico 1).
- Fallas de conectividad o metadatos inconsistentes de Aduabook 3 (Épico 2).
- Un prompt mal editado puede degradar la lectura; por eso cada cambio queda versionado (Épico 3).
- Sobrescritura accidental de configuraciones en la carga masiva (Épico 5).
- Consultas pesadas de reportes sobre la base transaccional (Épico 5).
