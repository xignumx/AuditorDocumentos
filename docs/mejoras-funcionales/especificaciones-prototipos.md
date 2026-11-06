# Especificaciones de Prototipos — Auditor de Documentos (Mejoras)

> **Nota de diseño:** Los prototipos son **pantallas nuevas**. Deben copiar la línea gráfica de la SPA actual (`/AuditorDocumentos`: header, Outfit, naranja `#FF5800`, botones OneCore, dropzone, selects, badges). La **estructura de navegación se amplía**; las rutas actuales **siguen existiendo y operables**. Ninguna funcionalidad nueva deshabilita las validaciones ya configuradas (fracciones, proveedores, NOM, vigencias, etc.).

**Fuentes:** PBL `ADX-OPER-26-0039`, este documento, y los renders de [`Mejora Auditor Documentos.pdf`](./Mejora%20Auditor%20Documentos.pdf) (págs. 2, 4 y 5).

---

## 0. Decisiones cerradas (cascarón y convivencia)

| # | Decisión | Valor |
|---|----------|--------|
| 1 | Composición del módulo nuevo | **Una pantalla con pestañas** (no cuatro rutas sueltas para carga / tablero / lote / invoice) |
| 2 | Cascarón | **Opción A:** header actual intacto + **ítems nuevos**; rutas viejas no se quitan |
| 3 | Datos | **Los mismos documentos** se ven en el flujo actual y en el módulo nuevo |
| 4 | Punto de partida del flujo nuevo | La **referencia aduanal** (PDF). Al consultar, el sistema resuelve cliente, operación y clave de pedimento |
| 5 | Carga individual actual | `/repositorio/nuevo` **no se rediseña** en estos prototipos |
| 6 | Listado actual | `/repositorio` **sigue**; la columna Invoice **no es obligatoria** ahí (va en el módulo nuevo). Un estado opcional puede mostrarla de forma aditiva |
| 7 | Asociación a operación | En el módulo nuevo la referencia del encabezado **es** el vínculo del expediente. No se prototipa el modal “Relacionar operación” por cada PDF. El flujo actual de asociación **sigue** en `/repositorio` |
| 8 | Lote VUCEM | Solo documentos **Autorizado**; un sello para el lote (Cliente / Agente), resultado por fila (Digitalizado / error con reintento) |
| 9 | Aduabook 3 | No es monitor aparte: al consultar la referencia se **ingestan** prealertas/archivos y aparecen en la bandeja con badge de origen |
| 10 | Estilos | Copiar header, tipografía y componentes actuales. Los renders del PDF son **layout y copy**, no otra marca |

### Navegación (opción A)

**Siguen**

| Ítem | Ruta | Cambio en prototipo |
|------|------|---------------------|
| Config. documentos | `/config` | Ninguno (motor cliente + tipo, FieldCards) |
| Repo. documentos | `/repositorio` | Ninguno (salvo estado opcional de columna Invoice) |
| Alta documento | `/repositorio/nuevo` | Ninguno |
| Config. notificaciones | `/notificaciones` | Ninguno |
| Selector de cliente | header | Sigue; en el módulo nuevo el cliente **también** puede llegar por la referencia |

**Se agregan**

| Ítem (propuesto) | Ruta | Contenido |
|------------------|------|-----------|
| Expediente | `/expediente` | Pantalla con pestañas (carga, bandeja, lote, invoice) |
| Reglas IA | `/config/ia-rules` | Diccionario + prompts + versiones (Compliance/Admin) |
| Compliance | `/config/compliance` | Defaults por tipo VUCEM para todos los clientes + carga Excel |
| Reportes | `/reportes` | KPIs e indicadores |

### Estatus (módulo nuevo, labels del PDF)

| Badge | Uso |
|-------|-----|
| Leyendo | OCR/IA en segundo plano (equivale a *Procesando* del PBL) |
| Listo para revisar | Prelectura lista, falta auditoría humana |
| Con observaciones | Campos faltantes, discrepancias o sugerencia IA por confirmar |
| Autorizado | Auditoría completa; elegible para lote VUCEM |
| Digitalizado eDOCS | Transmisión exitosa |
| Error / reintento | Fallo VUCEM; no pierde Autorizado; se puede reenviar |

El listado actual conserva sus estatus 1–8. Mapeo de convivencia (mismos documentos): *Autorizado* (nuevo) ↔ *Aprobado* (actual); *Digitalizado eDOCS* es el mismo en ambos.

---

## 1. Lineamientos de diseño

* Header, contenedores y tablas como en la app actual; scrollbar horizontal si hace falta.
* **Tipo documento VUCEM:** no usar combo. Reutilizar el panel lateral de cards (`VucemDocumentSelector`): título *Documento VUCEM*, buscador y lista con nombre, `VUCEM:` y `Prefijo:`. Layout 1+3 como `/config` y `/repositorio/nuevo`.
* Badges: *Leyendo* azul/gris animado; *Listo para revisar* naranja suave; *Con observaciones* ámbar; *Autorizado* / *Digitalizado* verde; *Error* rojo.
* Referencia de layout principal: PDF página 2 (dropzone izquierda + tabla derecha + pie de acciones).
* Referencia de columna Invoice: PDF página 4.
* Referencia de matriz de campos: PDF página 5 (solo como look de `/config`; el prototipo de Compliance es **pantalla nueva**).

---

## 2. Prototipos HTML a generar

Carpeta destino: `docs/mejoras-funcionales/prototipos/`.

### P-EXP — Expediente (pestañas) — cubre P01, P02, P03, P06

**Ruta prototipo:** `/expediente`  
**Render guía:** PDF págs. 2 y 4.

**Pestaña 1 — Carga y bandeja** (PDF p. 2)

* Barra de contexto: `Referencia` (`10008872/0`) + **Consultar**. Al consultar se llenan `Cliente`, `Operación`, `Cve. Pedimento` (solo lectura).
* Columna izquierda **Carga de documentos:** dropzone “Arrastra aquí tus archivos PDF” + “Seleccionar archivos”; varios PDF; validación visual `%PDF`.
* Columna derecha **Documentos cargados:** tabla con checkbox, nombre, **Tipo sugerido (IA)** (select), **Confirmado** (select), **Estatus**, acciones (revisar / eliminar).
* Pie de métricas: Cargados / Leyendo / Listos (A) / Observaciones.
* Pie de acciones: “Seleccionar autorizados”, **Transmitir seleccionados a VUCEM**, **Revisar** (abre el siguiente *Listo para revisar* o *Con observaciones*).
* Checkboxes de transmisión **solo** si estatus = Autorizado.
* Filas Aduabook 3: badge `Origen: Aduabook 3`. Tras Consultar, al menos una fila de ejemplo ya sincronizada y una omitida por duplicado (tooltip).
* Modal de sello (reutilizar look de `SelloVucemModal`): lote, sello cliente/agente, correo opcional; después, resultado por fila en la tabla.

**Pestaña 2 — Documentos** (Invoice / permiso)

* Misma referencia en contexto.
* Grilla tipo repositorio con columna **Número de Factura / Invoice / Permiso** a la derecha de **Archivo** (PDF p. 4): folio en negrita (`INV-2026-0891`) o `Sin Factura / N/A` en gris.
* Buscador que filtra también por invoice.
* Badge de origen si aplica.

Al autorizar o transmitir en la pestaña 1, el mismo folio debe poder reconocerse en esta pestaña (mismos documentos).

### P-REV — Revisión asistida (1-clic) — cubre P05

**Apertura:** botón Revisar / icono de fila en la bandeja. Al guardar, **regresa a la bandeja** (PDF pto. 5).

* Split: PDF izquierda (resaltado ilustrativo del dato); campos derecha según motor (visibles/obligatorios).
* Por campo: valor extraído + **Confirmar** (1-clic) o edición; las sugerencias por sinónimo/etiqueta no literal se marcan como “Sugerido”.
* No sustituye el modal Ver/Autorizar de `/repositorio`.

### P-IA — Diccionario y prompts — cubre P04

**Ruta:** `/config/ia-rules`

* Matriz editable de sinónimos ES/EN. Semilla del PDF: Número de parte, Valor unitario, Valor total (listas de equivalencias).
* Editor de prompt por tipo VUCEM y campo.
* Historial: fecha, usuario, versión.

### P-COMP — Compliance y carga masiva de reglas — cubre P07

**Ruta:** `/config/compliance`

* Aviso: la configuración **por tipo de documento aplica a todos los clientes** (PDF p. 5). El `/config` actual (por cliente + tipo) no se quita.
* Look de FieldCards (PDF p. 5) + indicador de rol `COMPLIANCE`.
* Descarga de plantilla Excel/CSV, subida, preview de errores, confirmar aplicación.

### P-REP — Reportes — cubre P08

**Ruta:** `/reportes`

* KPIs: documentos procesados, % lectura IA, envíos VUCEM, correcciones manuales.
* Filtros fecha / cliente / tipo; exportar Excel/CSV.

### Fuera de alcance de rediseño (se muestran solo como navegables)

Header links a `/config`, `/repositorio`, `/repositorio/nuevo`, `/notificaciones` con **copy y layout actuales** (placeholder o screenshot-like estático). No se rehacen.

---

## 3. Archivos HTML previstos

Generados en `docs/mejoras-funcionales/prototipos/`. Abrir [`prototipos/index.html`](./prototipos/index.html) en el navegador.

| Archivo | Prototipo |
|---------|-----------|
| `prototipos/index.html` | Shell + header opción A + Expediente pestaña 1 (estado con datos). Modal de sello y resultado de lote. |
| `prototipos/expediente-documentos.html` | Expediente pestaña 2 (invoice) |
| `prototipos/expediente-vacio.html` | Expediente sin referencia consultada |
| `prototipos/revision.html` | Split 1-clic |
| `prototipos/ia-rules.html` | Diccionario y prompts |
| `prototipos/compliance.html` | Defaults por tipo + Excel |
| `prototipos/reportes.html` | Dashboard |
| `prototipos/repositorio.html`, `alta.html`, `config.html`, `notificaciones.html` | Rutas actuales, sin rediseño (navegables) |

---

## 4. Pendientes que siguen abiertos (no bloquean el primer HTML)

1. **Nombre del ítem nuevo** en el header: se propone **Expediente**. El PDF mete el flujo nuevo dentro de “Alta documento”; en prototipo **no** se pisa esa ruta.
2. Formato de referencia en Consultar: el render usa `10008872/0` (referencia/rectificación). Tráfico sin `/` se puede mostrar como segundo ejemplo.
3. Catálogo exacto de “Tipo sugerido / Confirmado” (Factura, Carta, BL, Permiso, Packing list, Certificado de origen en el PDF).
4. Fórmulas de KPI y columnas del Excel de Compliance (el prototipo usa plantilla ilustrativa).
5. Coordenadas reales de resaltado OCR (el split usa recuadros de ejemplo).

---

## 5. Criterio de no ruptura

* Las cuatro rutas actuales permanecen en el menú y responden.
* Validaciones del motor actual siguen vigentes en la revisión asistida (campos visibles/obligatorios).
* Transmitir lote no está en el listado actual; el VUCEM por fila del repositorio actual no se elimina.
* Compliance no quita a ADM/LIDER/CALIDAD el `/config` por cliente.
