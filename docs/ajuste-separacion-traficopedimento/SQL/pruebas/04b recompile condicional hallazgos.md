# Post-deploy — RECOMPILE solo con búsqueda vacía

**Fecha:** 2026-10-13  
**SP:** `csp_Ad_SugerenciaPedimentos_v2` desde `SQL/implementacion/01`  
**Caso:** cliente `9174`, documento `35081`

## Cambio

`OPTION (RECOMPILE)` en INSERT a `#Candidatos` de la **rama tráfico** únicamente cuando `@operacionBusquedaTrim = ''`.  
Pedimento: sin RECOMPILE. Con texto de búsqueda: INSERT sin RECOMPILE.

## Resultados

| Caso | Siempre RECOMPILE (04) | Condicional vacío (04b) | Resultado |
|------|------------------------|-------------------------|-----------|
| `operacionBusqueda=''` | 4 861 ms | **2 080 ms** | 1 fila `RA48356812`, TotalRecords=1 |
| `operacionBusqueda='RA48356812'` | 7–17 s | **416 / 156 ms** (1ª/2ª) | misma 1 fila |

Salidas sqlcmd: locales (ignoradas en git vía `.gitignore` de esta carpeta).

## Conclusión

Se recupera la latencia de búsqueda puntual y el filtro vacío sigue estable (mejor que con RECOMPILE siempre activo).
