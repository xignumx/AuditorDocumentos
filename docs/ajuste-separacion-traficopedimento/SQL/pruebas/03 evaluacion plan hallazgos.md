# Evaluación de plan — filtro vacío (sin modificar el SP aún)

**Caso:** `9174` / doc `35081` / `operacionBusqueda=''`  
**Fecha:** 2026-10-13

## Hallazgo principal (monitor en vivo)

Mientras el SP corre con filtro vacío, se queda en:

```text
INSERT INTO #Candidatos ... SELECT fgt.id_trafico ...  -- rama TRÁFICO
```

Ejemplo a ~45 s: CPU ~45 s, **~2.5 millones** logical reads, `wait_type=NULL` (CPU bound).  
No está bloqueado: está ejecutando un mal plan de la rama tráfico.

`EXEC ... WITH RECOMPILE` a nivel llamada **no basta** (sigue timeout ≥ 600 s): las variables locales `@Act*` / `@Val*` se asignan **después** del compile del batch; el plan del `INSERT` no las “ve” bien.

## Comparativas (simulaciones, mismo caso)

| Prueba | ms | Filas |
|--------|---:|------:|
| Inserts estilo SP sin RECOMPILE | 4 355 | 1 |
| Inserts estilo SP + RECOMPILE | 3 517 | 1 |
| Camino vacío sin OR LIKE + RECOMPILE | 2 786 | 1 |
| Tráfico `@Act` sin RECOMPILE | 3 189 | 1 |
| Tráfico `@Act` + RECOMPILE | 2 413 | 1 |
| Ambas ramas sin RECOMPILE | **5 076** | 1 |
| Ambas ramas + RECOMPILE en cada INSERT | **2 674** | 1 |
| EXEC SP filtro vacío | **timeout ≥ 180–600 s** | — |
| EXEC SP con búsqueda `RA48356812` | 108–419 | 1 |

Resultado de negocio en simulaciones rápidas: **1 fila** `RA48356812` (igual que con búsqueda).

## Conclusión

1. El cuello es el **`INSERT #Candidatos` de la rama tráfico** dentro del SP (universo ~119 k tras la separación pedimento/tráfico).
2. La corrección con mejor evidencia: **`OPTION (RECOMPILE)` en cada `INSERT INTO #Candidatos`** (pedimento y tráfico), no solo en el `SELECT` final.
3. Complemento opcional: si `@operacionBusquedaTrim = ''`, omitir los `OR LIKE` muertos (mejora menor en simulación).
4. `#TrafCliente` no aportó; RECOMPILE a nivel `EXEC` no alcanza.

## Cambio propuesto (pendiente de confirmación)

En `csp_Ad_SugerenciaPedimentos_v2`: añadir `OPTION (RECOMPILE)` al final de cada `INSERT` que llena `#Candidatos` en la rama normal (y, si aplica, alinear el script en `docs/ajuste-separacion-traficopedimento/SQL/implementacion/01`).

Validación post-cambio:

1. Filtro vacío: debe terminar y devolver la misma fila `RA48356812` / TotalRecords=1.  
2. Búsqueda `RA48356812`: mismos resultados que baseline (~100–400 ms).  
3. No tocar diagnóstico ni v1.
