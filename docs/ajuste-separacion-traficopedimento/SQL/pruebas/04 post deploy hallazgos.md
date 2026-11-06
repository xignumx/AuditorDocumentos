# Post-deploy — OPTION (RECOMPILE) en INSERT #Candidatos

**Fecha:** 2026-10-13  
**SP:** `csp_Ad_SugerenciaPedimentos_v2` desplegado desde `SQL/implementacion/01`  
**Caso:** cliente `9174`, documento `35081`

## Resultados

| Caso | Antes | Después | Resultado |
|------|-------|---------|-----------|
| `operacionBusqueda=''` | timeout ≥ 15 min | **4 861 ms** | 1 fila `RA48356812`, TotalRecords=1 |
| `operacionBusqueda='RA48356812'` | 108–419 ms | 7–17 s (1ª/2ª corrida) | misma 1 fila |

## Igualdad

Filtro vacío y búsqueda devuelven el **mismo conjunto** (tráfico `RA48356812`). Semántica de separación pedimento/tráfico intacta.

## Nota

La búsqueda puntual puede ser más lenta que el baseline previo por el costo de recompilar cada `INSERT`; a cambio, el filtro vacío deja de colgarse.  
**Seguimiento:** aplicado RECOMPILE solo con búsqueda vacía — ver `04b recompile condicional hallazgos.md`.
