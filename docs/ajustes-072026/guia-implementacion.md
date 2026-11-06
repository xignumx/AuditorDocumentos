# Guía de implementación — Ajuste 07/2026

**Estado:** implementado en `src/`; scripts BD en `SQL/implementacion/`. Pendiente: QA formal y promoción a `docs/SQL/`.

---

## Alcance

| Bloque | Descripción |
|--------|-------------|
| **A — Campos 20–24** | Factura, FechaFactura, ValorUsd, GuiaBl, Pedimento: motor, IA, UI, reporte uso |
| **B — Sugerencia v2** | `csp_*_v2` con filtros AND desde motor; API con `OperacionBusqueda` |

Decisiones: [decisiones-negocio.md](./decisiones-negocio.md) · [decisiones-filtros-sugerencia-pedimentos.md](./decisiones-filtros-sugerencia-pedimentos.md)

---

## Scripts SQL — orden de aplicación

### Implementación (`SQL/implementacion/`)

| Paso | Script | Base |
|------|--------|------|
| 1 | [01 DesarrolloDB motor detalle campos 20-24.sql](./SQL/implementacion/01%20DesarrolloDB%20motor%20detalle%20campos%2020-24.sql) | DesarrolloDB |
| 2 | [02 DesarrolloDB prompts IA campos 20-24.sql](./SQL/implementacion/02%20DesarrolloDB%20prompts%20IA%20campos%2020-24.sql) | DesarrolloDB |
| 3 | [03 ADUASIS reporte uso AuditorDocumentosUsoCompleto.sql](./SQL/implementacion/03%20ADUASIS%20reporte%20uso%20AuditorDocumentosUsoCompleto.sql) | ADUASIS |
| 4 | [04 ADUASIS FN_Ad_NormalizarTipoOperacion.sql](./SQL/implementacion/04%20ADUASIS%20FN_Ad_NormalizarTipoOperacion.sql) | ADUASIS |
| 5 | [05 ADUASIS csp_Ad_SugerenciaPedimentos_v2.sql](./SQL/implementacion/05%20ADUASIS%20csp_Ad_SugerenciaPedimentos_v2.sql) | ADUASIS |
| 6 | [06 ADUASIS csp_Ad_DiagnosticoSugerenciaPedimentos_v2.sql](./SQL/implementacion/06%20ADUASIS%20csp_Ad_DiagnosticoSugerenciaPedimentos_v2.sql) | ADUASIS |

> El paso 5 incluye optimización de rendimiento (`#Candidatos`, paginación `ROW_NUMBER`). Requiere el paso 4.

### Referencia — no ejecutar (`SQL/referencia/`)

Baselines v1 extraídos del servidor para comparar lógica legacy.

### Pruebas (`SQL/pruebas/`)

| Script | Uso |
|--------|-----|
| [01 QA validacion documento vs operacion.sql](./SQL/pruebas/01%20QA%20validacion%20documento%20vs%20operacion.sql) | Comparar documento + operación campo a campo |
| [02 Diagnostico rendimiento sugerencia.sql](./SQL/pruebas/02%20Diagnostico%20rendimiento%20sugerencia.sql) | Plan de ejecución, IO/TIME, volumen |
| [03 Verificar despliegue SP sugerencia.sql](./SQL/pruebas/03%20Verificar%20despliegue%20SP%20sugerencia.sql) | Smoke test post-despliegue pasos 4–5 |

---

## SPs en paralelo (v1 / v2)

| Producción legacy | En uso por API |
|-------------------|----------------|
| `csp_Ad_SugerenciaPedimentos` | **`csp_Ad_SugerenciaPedimentos_v2`** |
| `csp_Ad_DiagnosticoSugerenciaPedimentos` | **`csp_Ad_DiagnosticoSugerenciaPedimentos_v2`** |

v1 no se modifica hasta promoción formal. Rollback API: revertir `EXEC` en `AduasisDbContextServices.cs`.

---

## Validación post-despliegue

```sql
USE ADUASIS;
SELECT name, modify_date FROM sys.procedures
WHERE name IN ('csp_Ad_SugerenciaPedimentos_v2', 'csp_Ad_DiagnosticoSugerenciaPedimentos_v2');
```

Ejecutar `SQL/pruebas/03` tras los pasos 4–5.

---

## Cambios en `src/`

| Capa | Archivos principales |
|------|---------------------|
| Backend | `AdCampos.cs`, `SugerenciaPedimentosRequest.cs`, `AduasisDbContextServices.cs`, `MotorConfigController.cs` |
| Frontend | `adCampos.js`, `ConfigurationsPage.jsx`, `DocumentRepositoryCreatePage.jsx`, `DocumentRepositoryListPage.jsx` |

Detalle por campo: [mapeo-campos.md](./mapeo-campos.md). Performance SP: [analisis-performance-sugerencia-v2.md](./analisis-performance-sugerencia-v2.md).

---

## Checklist QA

### Campos 20–24

- Motor post-backfill muestra 5 tarjetas nuevas (ocultas por defecto).
- Alta: pedimento 15 dígitos, fecha `yyyy-MM-dd`, ValorUsd independiente de ValorComercial.
- `EXEC csp_AuditorDocumentosUsoCompleto` incluye columnas 20–24.

### Sugerencia / diagnóstico v2

- Filtros AND desde motor (no params de campos en API).
- Atajo pedimento (24): localiza por 15 dígitos sin `operacionBusqueda`.
- Script QA: `pruebas/01` con `idAdDocumento` + `id_referencia` / `id_trafico`.

---

## Promoción a canónico (tras sign-off)

| Origen | Destino |
|--------|---------|
| `implementacion/03` | `docs/SQL/csp_AuditorDocumentosUsoCompleto.sql` |
| `implementacion/05` | `docs/SQL/csp_Ad_SugerenciaPedimentos_v2.sql` |
| `implementacion/06` | `docs/SQL/csp_Ad_DiagnosticoSugerenciaPedimentos_v2.sql` |

---

## Rollback BD

| Paso | Acción |
|------|--------|
| 1–2 | DELETE manual campos 20–24 en motor/prompts si necesario |
| 3 | Restaurar `csp_AuditorDocumentosUsoCompleto` desde `docs/SQL/` |
| 5–6 | `DROP PROCEDURE` de los `_v2` |
