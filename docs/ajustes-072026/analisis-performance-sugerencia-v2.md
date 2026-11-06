# Análisis de rendimiento — `csp_Ad_SugerenciaPedimentos_v2`

**Fecha:** 06/07/2026  
**Síntoma:** timeout al ejecutar el SP (API tiene timeout de 5 min en `AduasisDbContextServices`).

**Conexión MCP:** no disponible desde el entorno del agente. Validar en SSMS con [pruebas/02](./SQL/pruebas/02%20Diagnostico%20rendimiento%20sugerencia.sql) y [pruebas/03](./SQL/pruebas/03%20Verificar%20despliegue%20SP%20sugerencia.sql).

---

## v3 materialized (`implementacion/05`)

| Cambio | Beneficio |
|--------|-----------|
| `#Candidatos` temp table | 1 scan en lugar de 2 COUNT + 1 UNION |
| `INNER JOIN` tráfico cuando `@HayFiltroTrafico` | Evita nested loops |
| Paginación `ROW_NUMBER` | Sin error Msg 10743 |
| `OPTION (RECOMPILE)` solo en SELECT final | Menos tiempo de compilación |

Desplegar: `implementacion/04` → `implementacion/05` → `pruebas/03`.


## Causas probables (análisis estático)

### 1. Tres pasadas sobre el mismo universo

El SP ejecuta **3 consultas pesadas** con la misma lógica de filtros:

1. `COUNT` rama pedimentos  
2. `COUNT` rama tráfico sin pedimento  
3. `SELECT` paginado (`UNION ALL`)

Cada una puede escanear decenas de miles de filas para un cliente con muchos pedimentos abiertos (`fecha_pago_banco IS NULL`).

### 2. `EXISTS` correlacionado a tráfico (v2 vs v1)

En **v1** (baseline), pedimentos siempre hacen `INNER JOIN fgtrafico` + `fdtrafico` en el `FROM`, filtrando temprano.

En **v2**, cuando hay filtros de tráfico activos (fracción, país, proveedor, etc.), la rama pedimentos usa:

```sql
EXISTS (SELECT 1 FROM fgtrafico fgt INNER JOIN fdtrafico fdt ... WHERE fgt.id_referencia = fped.id_referencia ...)
```

Eso genera **nested loops**: por cada pedimento abierto del cliente se re-evalúa tráfico. Con clientes grandes es el patrón típico de timeout.

### 3. `NOT EXISTS` cross-database repetido

Cada fila candidata consulta `DesarrolloDB.dbo.ad_documento_operacion` (4–6 veces por ejecución del SP). Aunque el conjunto de exclusiones es pequeño, el costo se multiplica por filas evaluadas.

### 4. `LIKE '%texto%'` no sargable

`@operacionBusqueda`, aduana, fracción (`LIKE frac + '%'` sí es parcialmente sargable), países (`LIKE '%' + pais + '%'`) impiden seeks en índices.

### 5. Sin `OPTION (RECOMPILE)`

Muchos filtros son opcionales (`@ActFracciones`, `@ActPais`, …). Un plan cacheado para “pocos filtros” se reutiliza con “muchos filtros” (o viceversa) → mal estimado de cardinalidad.

### 6. `COUNT(DISTINCT ...)` + `GROUP BY` redundante

El conteo y el `SELECT` final agrupan por las mismas claves; el optimizador no reutiliza trabajo entre las 3 pasadas.

---

## Script optimizado propuesto

**Archivo:** [implementacion/05 ADUASIS csp_Ad_SugerenciaPedimentos_v2.sql](./SQL/implementacion/05%20ADUASIS%20csp_Ad_SugerenciaPedimentos_v2.sql)

| Cambio | Beneficio esperado |
|--------|-------------------|
| `@OpsExcluidas` materializada (1 lectura) | Elimina NOT EXISTS cross-db por fila |
| `@HayFiltroTrafico` + `INNER JOIN` en COUNT pedimentos | Evita nested loops cuando hay filtros de tráfico |
| `PRIMARY KEY` en `@Fracciones`, `@ClavesPed`, `@Guias` | Mejor estimación en EXISTS/JOIN |
| `OPTION (RECOMPILE)` en consultas pesadas | Plan acorde a filtros activos del documento |

**Pendiente resuelto en implementacion/05:** materialización `#Candidatos` y JOIN alineado en SELECT paginado.

---

## Índices recomendados (validar con DBA)

```sql
-- fpedimento: pedimentos abiertos por cliente
CREATE NONCLUSTERED INDEX IX_fpedimento_cliente_abierto
ON dbo.fpedimento (id_cliente, fecha_pago_banco, firma_banco)
INCLUDE (id_referencia, id_rectificacion, pedimento, id_aduana, seccion, id_patente, cve_tipo_operacion, id_regimen, id_tipo_pedimento);

-- fgtrafico: enlace referencia → tráfico
CREATE NONCLUSTERED INDEX IX_fgtrafico_referencia
ON dbo.fgtrafico (id_referencia, id_rectificacion)
INCLUDE (id_trafico, id_cliente);

-- fdtrafico: líneas por tráfico
CREATE NONCLUSTERED INDEX IX_fdtrafico_trafico
ON dbo.fdtrafico (id_trafico)
INCLUDE (id_fraccion, id_proveedor, id_producto, id_pais_origen, id_pais_vendedor, cve_unidad_tarifa, nico, descripcion_clasificacion);

-- DesarrolloDB
CREATE NONCLUSTERED INDEX IX_ad_documento_operacion_IdDocumento
ON dbo.ad_documento_operacion (IdDocumento)
INCLUDE (id_referencia, id_rectificacion, pedimento);
```

No crear en producción sin medir en QA.

---

## Plan de validación

1. Ejecutar **pruebas/02** con `@idCliente` / `@idAdDocumento` del caso lento.
2. Revisar plan XML: nested loops, scans.
3. Desplegar **implementacion/05** en QA.
4. Ejecutar **pruebas/03** para smoke test.

---

## Atajo Pedimento (24)

Si el documento tiene campo 24 activo y valor de 15 dígitos, el SP usa rama directa por `id_aduana` + `id_patente` + `pedimento`. Esa rama **debe ser rápida**; si también hace timeout, falta índice en `(id_cliente, id_aduana, id_patente, pedimento)`.
