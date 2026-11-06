# Baseline — sugerencia doc 35081 / cliente 9174

**Fecha:** 2026-10-13  
**SP:** `csp_Ad_SugerenciaPedimentos_v2` (sin modificar)  
**Paginación:** page=1, size=10

## Parámetros

| Parámetro | Valor |
|-----------|--------|
| idCliente | 9174 |
| idAdDocumento | 35081 |
| Filtros activos | Proveedor, Producto, UMT, País, Factura, FechaFactura |

## Resultados medidos del SP (EXEC real)

| Caso | operacionBusqueda | Tiempo | Resultado |
|------|-------------------|--------|-----------|
| A | `''` (vacío) | **Timeout 1800 s** | Sin resultset |
| B | `RA48356812` | **419 ms** | 1 fila, TotalRecords=1 |

### Filas caso B (SP)

| id_referencia | id_rectificacion | patente | aduana | pedimento | tipo | clave |
|---------------|------------------|---------|--------|-----------|------|-------|
| RA48356812 | NULL | 3438 | 240 | (vacío) | 1 | A1 |

Salida: `01b baseline salida.txt`

## Resultado esperado con filtro vacío (lectura equivalente)

Como **Factura está activa**, todo candidato del SP debe tener `T2RA48356812A1`.  
Script `01c` enumera candidatos con la misma semántica AND/EXISTS partiendo de factura (no altera el SP):

| Métrica | Valor |
|---------|--------|
| Tiempo diagnóstico | 2747 ms |
| TotalRecords esperado | **1** |
| Página 1 | **RA48356812** (tráfico; misma fila que caso B) |

Salida: `01c baseline salida.txt`

## Conclusión para optimizar

1. Con este documento, filtro vacío y búsqueda `RA48356812` deben devolver **el mismo conjunto** (1 tráfico).
2. El SP actual **no puede usarse como oráculo de igualdad** en vacío: no termina en 30 min.
3. El oráculo fiable es el conjunto de candidatos que cumplen los filtros del motor (aquí, 1 fila).
4. Cualquier cambio (p. ej. arrancar por Factura cuando `@ActFactura=1`) debe seguir devolviendo exactamente esa fila en vacío y en búsqueda, antes de dar por buena la optimización.

## Archivos

- `01a baseline solo vacio.sql` / `01a baseline salida.txt` — timeout
- `01b baseline solo busqueda.sql` / `01b baseline salida.txt` — OK 419 ms
- `01c baseline esperado por factura.sql` / `01c baseline salida.txt` — oráculo vacío
