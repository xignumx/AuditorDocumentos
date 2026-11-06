# Guía de implementación — Separación tráfico / pedimento

## Precondiciones

- SPs `_v2` ya desplegados (ajuste 07/2026).
- Ejecutar en **ADUASIS** con permisos de `CREATE OR ALTER PROCEDURE`.

## Orden

| # | Script | Efecto |
|---|--------|--------|
| 1 | `SQL/implementacion/01 ADUASIS csp_Ad_SugerenciaPedimentos_v2.sql` | Recrea sugerencia sin filtro “tráfico sin pedimento” |
| 2 | `SQL/implementacion/02 ADUASIS csp_Ad_DiagnosticoSugerenciaPedimentos_v2.sql` | Preferir tráfico por `id_trafico` (sin `/`) |

## Validación rápida

1. Documento con filtros que antes devolvían solo pedimento cuando el tráfico ya tenía relación.
2. `csp_Ad_SugerenciaPedimentos_v2`: deben aparecer filas de pedimento **y** de tráfico (mismo caso operativo, dos filas).
3. Diagnosticar la fila de tráfico (`id_trafico` sin `/`): resultado en rama tráfico, no forzado a pedimento.
4. Diagnosticar pedimento (`ref/rect` con `/`): rama pedimento sin cambio.
5. Con atajo Pedimento (24) activo: solo pedimentos (sin tráfico).

## Rollback

Re-ejecutar los scripts originales del ajuste 07/2026:

- `docs/ajustes-072026/SQL/implementacion/05 ADUASIS csp_Ad_SugerenciaPedimentos_v2.sql`
- `docs/ajustes-072026/SQL/implementacion/06 ADUASIS csp_Ad_DiagnosticoSugerenciaPedimentos_v2.sql`
