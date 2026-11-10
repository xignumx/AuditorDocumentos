# Plan de desarrollo Dev 2: ADX-OPER-26-0039 Auditor Documentos - Mejoras

Fuentes: PBL V2.0, SprintBacklog V1.6 (hoja Estimación), `especificaciones-prototipos.md` y revisión del código en `src/`.
Vista de todo el proyecto: [plan-general-desarrollo.md](./plan-general-desarrollo.md).

**Última actualización:** 2026-11-10

## Leyenda de estado

| Marca | Significado |
|-------|-------------|
| [x] | Hecho: código listo y compilando. Los scripts SQL están escritos pero **no ejecutados**, y falta QA. |
| [~] | Parcial: queda un punto abierto indicado en la fila. |
| [ ] | Pendiente. |

## 1. Resumen de avance

| Bloque | Requerimiento | Horas SBL | Estado |
|--------|---------------|-----------|--------|
| E5-ID01 | Perfil COMPLIANCE y bitácora de auditoría de reglas | 8 | [~] Código listo; falta el alta del rol COMPLIANCE |
| E3-ID01 | Prompts y diccionario de sinónimos ES/EN (`/config/ia-rules`) | 19 | [x] Código listo |
| E5-ID02 | Carga masiva de la matriz de validación | 9 | [ ] Pendiente |
| E5-ID03 | Reportes e indicadores (`/reportes`) | 10 | [ ] Pendiente |
| **Total** | | **46** | **27 h con código listo (59 %), 19 h pendientes** |

Pendientes transversales de lo ya construido:
- Ejecutar en QA los scripts `01`, `03` y `04` (están en `docs/mejoras-funcionales/SQL/implementacion/`).
- Probar con usuarios de cada clase y con una extracción real contra Vertex AI.
- Resolver el origen del rol COMPLIANCE.

## 2. Decisiones cerradas

| # | Tema | Decisión |
|---|------|----------|
| 1 | Rol COMPLIANCE | Opción c: `/config` por cliente no cambia (ADM, LIDER y CALIDAD siguen guardando). Lo nuevo (`/config/ia-rules`, `/config/compliance`, carga masiva) es exclusivo de COMPLIANCE. **Abierto:** origen del rol (catálogo de `IdClase` y quién lo da de alta). La autorización va en un solo lugar (`AdRolesConfiguracion` y `ConfigAutorizacionService`). |
| 2 | Unidad de medida | La IA devuelve la UM y se normaliza al `id_unidad_universal` canónico de `funidad_universal` mediante el diccionario. Equivalencias **globales**. |
| 3 | Carga masiva de matriz | Pantalla nueva `/config/compliance` (como el prototipo), archivo `.xlsx`. Los clientes destino se eligen en pantalla con una lista de checkboxes y buscador por razón social (uno o varios). No hay entidad nueva de "grupo de clientes". |
| 4 | Dependencias nuevas | ClosedXML en la API (aprobado) y una librería de gráficas en el Web (propuesta: Recharts). Ambas con versión fija. Verificar versión y compatibilidad (.NET 8, React 18) antes de instalar. |
| 5 | Coordinación con Dev 1 | Inyector de sinónimos y normalización de UM en clases nuevas. `ExtraDatosDocumentoIa` solo recibe una o dos llamadas. Dev 2 agrega a `ad_ia_ejecucion` las columnas de fecha, usuario, duración y resultado. |
| 6 | KPIs de `/reportes` | Ver sección 7. Aprobados. |
| 7 | Seguridad `MotorConfig` | Validación de rol en los endpoints nuevos y en `GuardarMotorConfig`. Los demás endpoints existentes no se tocan. |

## 3. Orden de ejecución

1. E5-ID01 (COMPLIANCE y bitácora). Base de permisos y bitácora. **Hecho (parcial).**
2. E3-ID01 (ia-rules y diccionario). **Hecho.**
3. E5-ID02 (carga masiva de matriz). **Siguiente.**
4. E5-ID03 (reportes). Depende de datos de Dev 1.

## 4. Tareas por bloque

### E5-ID01: COMPLIANCE y bitácora (8 h)

| # | Tarea | Horas | Estado | Entregable y notas |
|---|-------|-------|--------|--------------------|
| 1 | Rol y tabla de bitácora | 2 | [~] | Hecho: script `01 DesarrolloDB Create ad_motor_config_bitacora.sql`, entidad `AdMotorConfigBitacora` y `DbSet`. **Falta** el script de alta del rol COMPLIANCE (punto abierto 1). |
| 2 | Filtros de autorización | 2 | [x] | `AdRolesConfiguracion` (VModels) y `ConfigAutorizacionService`. `GuardarMotorConfig` devuelve 401 sin usuario y 403 sin perfil. `ValidaUsuarioAdminLider` usa el mismo servicio y ahora incluye COMPLIANCE. Nuevo `GET ValidaUsuarioCompliance`. |
| 3 | Bitácora de cambios | 2 | [x] | Una fila por parámetro modificado, dentro de la transacción de `SaveMotorConfigHeaderConDetalleAsync`. El parámetro `origen` (MANUAL o MASIVA) queda listo para la carga masiva. |
| 4 | UI y menú condicional | 2 | [x] | Hook `useConfigPermissions`, componente `RequirePermission`, `AppHeader` con permisos por prop e ítem "Reglas IA" solo para Compliance. Falta aplicar el guard a `/config/compliance` cuando exista la pantalla. |

Decisiones tomadas al implementar:
- COMPLIANCE entra también a `/config` por cliente, porque el PBL dice que Compliance gestiona esa pantalla.
- `mxochipa` pasa en la validación de Compliance, para poder probar mientras el rol no exista. Está marcado como temporal en el código.
- Cambio de comportamiento: un usuario sin perfil que antes guardaba llamando a la API directamente ahora recibe 403.

### E3-ID01: Prompts y diccionario (19 h)

| # | Tarea | Horas | Estado | Entregable y notas |
|---|-------|-------|--------|--------------------|
| 1 | Tablas | 3 | [x] | Scripts `03` (tablas `ad_ia_diccionario` y `ad_ia_config_historial`) y `04` (semilla de sinónimos). |
| 2 | Endpoints CRUD | 3 | [x] | En `MotorConfig`: `ObtenerPromptsIa`, `GuardarPromptIa`, `ObtenerDiccionarioIa`, `GuardarDiccionarioConceptoIa`, `EliminarDiccionarioConceptoIa`, `ObtenerHistorialIa` y `ObtenerUnidadesMedida`. Se separó en `MotorConfigController.IaReglas.cs` (clase `partial`). Rutas distintas a las del SBL (`/Prompts` y `/Diccionario`). |
| 3 | Inyector dinámico | 3 | [x] | `IaReglasService` y `IaReglasMotor`. Marcador `[SINONIMOS]`, o bloque al final del prompt si no existe. Si el diccionario falla, la extracción continúa sin él. |
| 4 | Vista `/config/ia-rules` | 4 | [x] | Pestañas Prompts, Diccionario, Equivalencias UM e Historial. |
| 5 | Equivalencias de UM | 6 | [x] | Categoría UM del diccionario (concepto = `id_unidad_universal`), selector del catálogo de ADUASIS y normalización del valor extraído tras la IA. |

Alcance no incluido (decidido al implementar):
- No hay botón para restaurar una versión anterior; el historial solo se consulta.
- La versión del prompt usada en cada extracción no se guarda en `ad_ia_ejecucion`. Se hará con las columnas de E5-ID03.
- Las equivalencias de UM no se siembran; se capturan desde la pantalla (el script `04` trae una plantilla).

### E5-ID02: Carga masiva de matriz (9 h)

| # | Tarea | Horas | Estado | Entregable |
|---|-------|-------|--------|------------|
| 1 | SP `csp_Ad_CargaMasivaMatrizConfig` | 2 | [ ] | Upsert masivo de visibilidad, obligatoriedad, clasificación y acción de pedimento para los clientes seleccionados. Respeta `ValidateMotorConfigDetalles` y el bloqueo de cambio de clasificación con documentos activos. |
| 2 | Endpoint `POST /api/MotorConfig/CargaMasivaMatriz` | 2 | [ ] | Recibe archivo y lista de clientes, parsea con ClosedXML. Incluye la descarga de la plantilla `.xlsx`. |
| 3 | Pre-validación | 2 | [ ] | Estructura del archivo, existencia de tipos VUCEM y campos, conflictos con configuraciones existentes. Modo solo previsualizar antes de aplicar. Escribe en la bitácora con origen MASIVA. |
| 4 | Pantalla `/config/compliance` | 3 | [ ] | Selector de clientes (checkboxes y buscador por razón social), descarga de plantilla, subida, vista previa por cliente (nuevo vs modifica) y confirmación. |

Reglas propuestas contra sobrescritura accidental: las celdas vacías no pisan valores existentes y la vista previa marca "nuevo" vs "modifica".

### E5-ID03: Reportes (10 h)

| # | Tarea | Horas | Estado | Entregable |
|---|-------|-------|--------|------------|
| 1 | Vistas de BD | 2 | [ ] | `vw_ad_metricas_sistema` y agregaciones, a partir de los SPs de uso existentes. Columnas nuevas en `ad_ia_ejecucion` (fecha, usuario, duración, resultado y versión de prompt usada). |
| 2 | Endpoints | 2 | [ ] | `GET /api/Reportes/DashboardMetricas` y `GET /api/Reportes/ExportarExcel` en un `ReportesController` nuevo. |
| 3 | Lógica de cálculo | 2 | [ ] | KPIs de la sección 7 y generación de Excel/CSV con ClosedXML. |
| 4 | Pantalla `/reportes` | 4 | [ ] | Tarjetas KPI, gráficas con la librería aprobada, filtros de fecha, cliente y tipo, y exportación. |

Dependencias con Dev 1 (confirmar nombres de tablas y columnas antes de crear las vistas): `ad_ia_feedback`, tablas de lotes de envío VUCEM, `ad_lote_carga` y origen Aduabook. Riesgo: consultas pesadas sobre la base transaccional; usar vistas o agregación y paginar la exportación.

## 5. Scripts SQL

Los scripts se escriben como archivos y no se ejecutan contra la base. Carpeta: `docs/mejoras-funcionales/SQL/implementacion/`, con el formato `NN <BD> descripción.sql`.

| # | Archivo | BD | Estado |
|---|---------|----|--------|
| 01 | DesarrolloDB Create ad_motor_config_bitacora | DesarrolloDB | Escrito, sin ejecutar |
| 02 | Alta de rol COMPLIANCE | ADUASIS (por confirmar) | Pendiente (punto abierto) |
| 03 | DesarrolloDB Create ad_ia_diccionario y ad_ia_config_historial | DesarrolloDB | Escrito, sin ejecutar |
| 04 | DesarrolloDB Seed ad_ia_diccionario | DesarrolloDB | Escrito, sin ejecutar |
| 05 | DesarrolloDB alter ad_ia_ejecucion | DesarrolloDB | Pendiente (E5-ID03) |
| 06 | DesarrolloDB csp_Ad_CargaMasivaMatrizConfig | DesarrolloDB | Pendiente (E5-ID02) |
| 07 | DesarrolloDB vw_ad_metricas_sistema | DesarrolloDB | Pendiente (E5-ID03) |

Orden de ejecución en QA: 01, 03, 04. El 02 depende de resolver el punto abierto 1.

## 6. Archivos nuevos y modificados (lo ya implementado)

**API**
- Nuevos: `Controllers/MotorConfigController.IaReglas.cs`, `Data/DesarrolloDB/AdMotorConfigBitacora.cs`, `AdIaDiccionario.cs`, `AdIaConfigHistorial.cs`, `Services/ConfigAutorizacionService.cs`, `Services/DesarrolloDb/IIaReglasDbContextServices.cs`, `IaReglasDbContextServices.cs`, `Services/IaReglas/IaReglasMotor.cs`, `IaReglasService.cs`.
- Modificados: `MotorConfigController.cs` (clase `partial`, autorización y nuevo `ValidaUsuarioCompliance`), `DocumentosController.cs` (dos llamadas en `ExtraDatosDocumentoIa` y un parámetro en el constructor), `DesarrolloDb_DbContextServices.cs` (bitácora de config), `AduasisDbContextServices.cs` (catálogo de UM), `DesarrolloDB_DBContext.cs`, `Program.cs`.

**VModels**
- Nuevos: `AdRolesConfiguracion.cs`, `IaReglasModels.cs`.

**Web**
- Nuevos: `pages/IaRulesPage.jsx` y `.css`, `components/iaRules/` (tres pestañas), `components/RequirePermission.jsx`, `hooks/useConfigPermissions.js`, `constants/iaRules.js`.
- Modificados: `App.jsx`, `AppHeader.jsx`, `components/index.js`, `pages/index.js`, `services/motorConfigService.js`.

## 7. Fórmulas de KPI (aprobadas)

1. **Documentos procesados:** documentos cargados en el periodo (por fecha de creación), sin contar los eliminados.
2. **% de lectura IA:** de los documentos con extracción IA, porcentaje en que el usuario no corrigió ningún campo (con las correcciones que guarda Dev 1).
3. **Envíos VUCEM:** total de envíos del periodo, separados en exitosos (Digitalizado eDOCS) y con error.
4. **Correcciones manuales:** campos corregidos después de la lectura IA y su porcentaje sobre los campos leídos.
5. **Tiempo de atención:** lapso entre la carga del documento y su autorización, con promedio por usuario.

## 8. Puntos abiertos

| # | Punto | Estado |
|---|-------|--------|
| 1 | Origen del rol COMPLIANCE: catálogo de `IdClase` y quién da de alta el rol. | Abierto (lo investiga el equipo) |
| 2 | Convivencia entre los defaults por tipo de documento y los motores ya configurados por cliente. | Abierto (afecta E5-ID02) |
| 3 | Nombres de tablas y columnas de Dev 1 que alimentan los reportes (`ad_ia_feedback`, lotes VUCEM, `ad_lote_carga`). | Abierto (afecta E5-ID03) |
| 4 | Reparto de las tareas generales del SBL entre Dev 1 y Dev 2. | Abierto |
| 5 | Filtro de autorización global en `Program.cs`. | Cerrado: no hay; cada controlador usa `[Authorize]` y el middleware de token. |
| 6 | Quitar el usuario `mxochipa` hardcodeado de `AdRolesConfiguracion` cuando exista el rol COMPLIANCE. | Abierto |
