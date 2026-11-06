# Ajuste 07/2026 — Campos IA 20–24 y sugerencia pedimentos v2

**Estado:** implementado en BD y `src/`. Pendiente: QA formal y promoción a `docs/SQL/`.

| Documento | Contenido |
|-----------|-----------|
| **[guia-implementacion.md](./guia-implementacion.md)** | Orden SQL, validación, QA, promoción, rollback |
| [decisiones-negocio.md](./decisiones-negocio.md) | Campos 20–24 |
| [decisiones-filtros-sugerencia-pedimentos.md](./decisiones-filtros-sugerencia-pedimentos.md) | Lógica SPs `_v2` |
| [mapeo-campos.md](./mapeo-campos.md) | Detalle técnico por campo |
| [analisis-performance-sugerencia-v2.md](./analisis-performance-sugerencia-v2.md) | Optimización SP sugerencia |

---

## SQL

```text
SQL/
├── implementacion/   ← ejecutar en orden 01 → 06
├── referencia/       ← baselines v1 (no ejecutar)
└── pruebas/          ← QA y diagnóstico (al final)
```

Ver tabla completa en [guia-implementacion.md](./guia-implementacion.md).

---

## Objetivo

1. Cinco campos nuevos **AdCampos 20–24** (motor, IA, captura, reporte).
2. **Sugerencia y diagnóstico** con filtros AND desde documento/motor vía SPs `_v2`.

---

## Campos 20–24 (resumen)

| ID | Campo | En sugerencia |
|----|-------|---------------|
| 20 | Factura | Filtro si obligatorio+visible+valor |
| 21 | FechaFactura | Idem |
| 22 | ValorUsd | No aplica |
| 23 | GuiaBl | Filtro si activo |
| 24 | Pedimento | **Atajo** (15 dígitos) |

---

## API

Request sugerencia: `idAdDocumento` + `operacionBusqueda` (opcional). Los filtros de campos los resuelve el SP.

SPs activos: `csp_Ad_SugerenciaPedimentos_v2`, `csp_Ad_DiagnosticoSugerenciaPedimentos_v2`.

---

## Historial

| Fecha | Hito |
|-------|------|
| 02/07/2026 | Definición negocio y baselines v1 |
| 02–04/07/2026 | Scripts BD + código Fases 2–5 |
| 06–07/07/2026 | Optimización SP (`#Candidatos`), scripts QA |
| 24/09/2026 | Fix sugerencia v2: tráficos con `id_referencia` vacía/espacio no excluidos por pedimento fantasma (`'' = ' '`) |
| 08/10/2026 | Migración prompt ValorUsd (22): puede coincidir con ValorComercial en docs USD — `SQL/implementacion/07` |
