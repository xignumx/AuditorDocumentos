/*
  Evaluación de plan (sin modificar csp_Ad_SugerenciaPedimentos_v2)
  Caso: 9174 / doc 35081 — filtro vacío, HayFiltroTrafico=1

  Compara inserts a #Candidatos:
    A) Como el SP (OR de búsqueda vacía) SIN RECOMPILE
    B) Igual CON OPTION (RECOMPILE)
    C) Camino búsqueda vacía SIN ramas OR LIKE  CON RECOMPILE
*/
USE ADUASIS;
GO
SET NOCOUNT ON;

DECLARE @idCliente VARCHAR(10) = '9174';
DECLARE @ValProveedor VARCHAR(20) = 'RAM002';
DECLARE @ValProducto VARCHAR(100) = '26551-101-02';
DECLARE @ValPais VARCHAR(20) = 'USA';
DECLARE @ValFactura VARCHAR(50) = 'T2RA48356812A1';
DECLARE @ValFechaFactura DATE = '2026-10-09';
DECLARE @operacionBusquedaTrim VARCHAR(40) = '';
DECLARE @t0 DATETIME2;
DECLARE @ms INT;
DECLARE @n INT;

IF OBJECT_ID('tempdb..#Eval') IS NOT NULL DROP TABLE #Eval;
CREATE TABLE #Eval (paso VARCHAR(80), elapsed_ms INT, filas INT, nota VARCHAR(200));

IF OBJECT_ID('tempdb..#Candidatos') IS NOT NULL DROP TABLE #Candidatos;
CREATE TABLE #Candidatos
(
    id_referencia VARCHAR(50) NOT NULL,
    id_rectificacion INT NULL,
    patente VARCHAR(10) NOT NULL,
    aduana VARCHAR(20) NOT NULL,
    pedimento VARCHAR(50) NOT NULL,
    tipo_operacion VARCHAR(5) NOT NULL,
    clave_pedimento VARCHAR(10) NOT NULL
);

/* ========== A) Pedimento + Trafico estilo SP, SIN RECOMPILE ========== */
TRUNCATE TABLE #Candidatos;
SET @t0 = SYSDATETIME();

INSERT INTO #Candidatos
SELECT fped.id_referencia, CAST(fped.id_rectificacion AS INT), fped.id_patente,
       fped.id_aduana + fped.seccion, fped.pedimento, fped.cve_tipo_operacion, fped.id_regimen
FROM ADUASIS.dbo.fpedimento AS fped WITH (NOLOCK)
WHERE fped.fecha_pago_banco IS NULL AND fped.firma_banco IS NULL
      AND fped.id_cliente = @idCliente AND fped.pedimento <> ''
      AND (@operacionBusquedaTrim = ''
           OR fped.pedimento LIKE '%' + @operacionBusquedaTrim + '%'
           OR fped.id_referencia LIKE '%' + @operacionBusquedaTrim + '%'
           OR fped.id_referencia = @operacionBusquedaTrim)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura rel WITH (NOLOCK)
                  WHERE rel.id_referencia = fped.id_referencia AND rel.id_rectificacion = fped.id_rectificacion
                        AND RTRIM(LTRIM(rel.id_factura)) = @ValFactura)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura rel WITH (NOLOCK)
                  WHERE rel.id_referencia = fped.id_referencia AND rel.id_rectificacion = fped.id_rectificacion
                        AND TRY_CONVERT(DATE, rel.fecha_factura) = @ValFechaFactura)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
                  INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                  WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
                        AND fdt.id_proveedor = @ValProveedor)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
                  INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                  WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
                        AND REPLACE(fdt.id_producto, ' ', '') = @ValProducto)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
                  INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                  WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
                        AND (fdt.id_pais_origen LIKE '%' + @ValPais + '%' OR fdt.id_pais_vendedor LIKE '%' + @ValPais + '%'))
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
                  INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                  WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
                        AND (fdt.id_unidad_universal = 'PZA' OR fdt.cve_unidad_tarifa = 'PZA'));

INSERT INTO #Candidatos
SELECT fgt.id_trafico, NULL, ISNULL(fgt.id_patente, ''),
       ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, ''), '',
       CASE WHEN fgt.cve_tipo_operacion = '0' THEN '1' WHEN fgt.cve_tipo_operacion = '1' THEN '2' ELSE '' END,
       fgt.id_regimen
FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
WHERE fgt.id_cliente = @idCliente
      AND (@operacionBusquedaTrim = ''
           OR fgt.id_trafico LIKE '%' + @operacionBusquedaTrim + '%'
           OR fgt.id_trafico = @operacionBusquedaTrim)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                  WHERE fdt.id_trafico = fgt.id_trafico AND fdt.id_proveedor = @ValProveedor)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                  WHERE fdt.id_trafico = fgt.id_trafico AND REPLACE(fdt.id_producto, ' ', '') = @ValProducto)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                  WHERE fdt.id_trafico = fgt.id_trafico
                        AND (fdt.id_pais_origen LIKE '%' + @ValPais + '%' OR fdt.id_pais_vendedor LIKE '%' + @ValPais + '%'))
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                  INNER JOIN ADUASIS.dbo.fdfactura fdf WITH (NOLOCK)
                    ON fdf.id_entrada = fdt.id_entrada AND fdf.id_cliente = fgt.id_cliente
                   AND fdf.id_proveedor = fdt.id_proveedor AND fdf.id_producto = fdt.id_producto
                  INNER JOIN ADUASIS.dbo.fgfactura fgf WITH (NOLOCK)
                    ON fgf.id_factura = fdf.id_factura AND fgf.id_cliente = fdf.id_cliente AND fgf.id_proveedor = fdf.id_proveedor
                  WHERE fdt.id_trafico = fgt.id_trafico AND RTRIM(LTRIM(fgf.id_factura)) = @ValFactura)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                  INNER JOIN ADUASIS.dbo.fdfactura fdf WITH (NOLOCK)
                    ON fdf.id_entrada = fdt.id_entrada AND fdf.id_cliente = fgt.id_cliente
                   AND fdf.id_proveedor = fdt.id_proveedor AND fdf.id_producto = fdt.id_producto
                  INNER JOIN ADUASIS.dbo.fgfactura fgf WITH (NOLOCK)
                    ON fgf.id_factura = fdf.id_factura AND fgf.id_cliente = fdf.id_cliente AND fgf.id_proveedor = fdf.id_proveedor
                  WHERE fdt.id_trafico = fgt.id_trafico AND TRY_CONVERT(DATE, fgf.fecha_factura) = @ValFechaFactura)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                  WHERE fdt.id_trafico = fgt.id_trafico AND (fdt.id_unidad_universal = 'PZA' OR fdt.cve_unidad_tarifa = 'PZA'));

SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
SELECT @n = COUNT(*) FROM #Candidatos;
INSERT INTO #Eval VALUES ('A inserts estilo SP sin RECOMPILE', @ms, @n, 'OR busqueda vacia incluido');

/* ========== B) Igual CON OPTION (RECOMPILE) en cada INSERT ========== */
TRUNCATE TABLE #Candidatos;
SET @t0 = SYSDATETIME();

INSERT INTO #Candidatos
SELECT fped.id_referencia, CAST(fped.id_rectificacion AS INT), fped.id_patente,
       fped.id_aduana + fped.seccion, fped.pedimento, fped.cve_tipo_operacion, fped.id_regimen
FROM ADUASIS.dbo.fpedimento AS fped WITH (NOLOCK)
WHERE fped.fecha_pago_banco IS NULL AND fped.firma_banco IS NULL
      AND fped.id_cliente = @idCliente AND fped.pedimento <> ''
      AND (@operacionBusquedaTrim = ''
           OR fped.pedimento LIKE '%' + @operacionBusquedaTrim + '%'
           OR fped.id_referencia LIKE '%' + @operacionBusquedaTrim + '%'
           OR fped.id_referencia = @operacionBusquedaTrim)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura rel WITH (NOLOCK)
                  WHERE rel.id_referencia = fped.id_referencia AND rel.id_rectificacion = fped.id_rectificacion
                        AND RTRIM(LTRIM(rel.id_factura)) = @ValFactura)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura rel WITH (NOLOCK)
                  WHERE rel.id_referencia = fped.id_referencia AND rel.id_rectificacion = fped.id_rectificacion
                        AND TRY_CONVERT(DATE, rel.fecha_factura) = @ValFechaFactura)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
                  INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                  WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
                        AND fdt.id_proveedor = @ValProveedor)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
                  INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                  WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
                        AND REPLACE(fdt.id_producto, ' ', '') = @ValProducto)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
                  INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                  WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
                        AND (fdt.id_pais_origen LIKE '%' + @ValPais + '%' OR fdt.id_pais_vendedor LIKE '%' + @ValPais + '%'))
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
                  INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                  WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
                        AND (fdt.id_unidad_universal = 'PZA' OR fdt.cve_unidad_tarifa = 'PZA'))
OPTION (RECOMPILE);

INSERT INTO #Candidatos
SELECT fgt.id_trafico, NULL, ISNULL(fgt.id_patente, ''),
       ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, ''), '',
       CASE WHEN fgt.cve_tipo_operacion = '0' THEN '1' WHEN fgt.cve_tipo_operacion = '1' THEN '2' ELSE '' END,
       fgt.id_regimen
FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
WHERE fgt.id_cliente = @idCliente
      AND (@operacionBusquedaTrim = ''
           OR fgt.id_trafico LIKE '%' + @operacionBusquedaTrim + '%'
           OR fgt.id_trafico = @operacionBusquedaTrim)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                  WHERE fdt.id_trafico = fgt.id_trafico AND fdt.id_proveedor = @ValProveedor)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                  WHERE fdt.id_trafico = fgt.id_trafico AND REPLACE(fdt.id_producto, ' ', '') = @ValProducto)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                  WHERE fdt.id_trafico = fgt.id_trafico
                        AND (fdt.id_pais_origen LIKE '%' + @ValPais + '%' OR fdt.id_pais_vendedor LIKE '%' + @ValPais + '%'))
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                  INNER JOIN ADUASIS.dbo.fdfactura fdf WITH (NOLOCK)
                    ON fdf.id_entrada = fdt.id_entrada AND fdf.id_cliente = fgt.id_cliente
                   AND fdf.id_proveedor = fdt.id_proveedor AND fdf.id_producto = fdt.id_producto
                  INNER JOIN ADUASIS.dbo.fgfactura fgf WITH (NOLOCK)
                    ON fgf.id_factura = fdf.id_factura AND fgf.id_cliente = fdf.id_cliente AND fgf.id_proveedor = fdf.id_proveedor
                  WHERE fdt.id_trafico = fgt.id_trafico AND RTRIM(LTRIM(fgf.id_factura)) = @ValFactura)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                  INNER JOIN ADUASIS.dbo.fdfactura fdf WITH (NOLOCK)
                    ON fdf.id_entrada = fdt.id_entrada AND fdf.id_cliente = fgt.id_cliente
                   AND fdf.id_proveedor = fdt.id_proveedor AND fdf.id_producto = fdt.id_producto
                  INNER JOIN ADUASIS.dbo.fgfactura fgf WITH (NOLOCK)
                    ON fgf.id_factura = fdf.id_factura AND fgf.id_cliente = fdf.id_cliente AND fgf.id_proveedor = fdf.id_proveedor
                  WHERE fdt.id_trafico = fgt.id_trafico AND TRY_CONVERT(DATE, fgf.fecha_factura) = @ValFechaFactura)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                  WHERE fdt.id_trafico = fgt.id_trafico AND (fdt.id_unidad_universal = 'PZA' OR fdt.cve_unidad_tarifa = 'PZA'))
OPTION (RECOMPILE);

SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
SELECT @n = COUNT(*) FROM #Candidatos;
INSERT INTO #Eval VALUES ('B inserts estilo SP CON RECOMPILE', @ms, @n, 'OR busqueda vacia + RECOMPILE');

/* ========== C) Camino vacio SIN OR LIKE + RECOMPILE ========== */
TRUNCATE TABLE #Candidatos;
SET @t0 = SYSDATETIME();

INSERT INTO #Candidatos
SELECT fped.id_referencia, CAST(fped.id_rectificacion AS INT), fped.id_patente,
       fped.id_aduana + fped.seccion, fped.pedimento, fped.cve_tipo_operacion, fped.id_regimen
FROM ADUASIS.dbo.fpedimento AS fped WITH (NOLOCK)
WHERE fped.fecha_pago_banco IS NULL AND fped.firma_banco IS NULL
      AND fped.id_cliente = @idCliente AND fped.pedimento <> ''
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura rel WITH (NOLOCK)
                  WHERE rel.id_referencia = fped.id_referencia AND rel.id_rectificacion = fped.id_rectificacion
                        AND RTRIM(LTRIM(rel.id_factura)) = @ValFactura)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura rel WITH (NOLOCK)
                  WHERE rel.id_referencia = fped.id_referencia AND rel.id_rectificacion = fped.id_rectificacion
                        AND TRY_CONVERT(DATE, rel.fecha_factura) = @ValFechaFactura)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
                  INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                  WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
                        AND fdt.id_proveedor = @ValProveedor)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
                  INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                  WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
                        AND REPLACE(fdt.id_producto, ' ', '') = @ValProducto)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
                  INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                  WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
                        AND (fdt.id_pais_origen LIKE '%' + @ValPais + '%' OR fdt.id_pais_vendedor LIKE '%' + @ValPais + '%'))
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
                  INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                  WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
                        AND (fdt.id_unidad_universal = 'PZA' OR fdt.cve_unidad_tarifa = 'PZA'))
OPTION (RECOMPILE);

INSERT INTO #Candidatos
SELECT fgt.id_trafico, NULL, ISNULL(fgt.id_patente, ''),
       ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, ''), '',
       CASE WHEN fgt.cve_tipo_operacion = '0' THEN '1' WHEN fgt.cve_tipo_operacion = '1' THEN '2' ELSE '' END,
       fgt.id_regimen
FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
WHERE fgt.id_cliente = @idCliente
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                  WHERE fdt.id_trafico = fgt.id_trafico AND fdt.id_proveedor = @ValProveedor)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                  WHERE fdt.id_trafico = fgt.id_trafico AND REPLACE(fdt.id_producto, ' ', '') = @ValProducto)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                  WHERE fdt.id_trafico = fgt.id_trafico
                        AND (fdt.id_pais_origen LIKE '%' + @ValPais + '%' OR fdt.id_pais_vendedor LIKE '%' + @ValPais + '%'))
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                  INNER JOIN ADUASIS.dbo.fdfactura fdf WITH (NOLOCK)
                    ON fdf.id_entrada = fdt.id_entrada AND fdf.id_cliente = fgt.id_cliente
                   AND fdf.id_proveedor = fdt.id_proveedor AND fdf.id_producto = fdt.id_producto
                  INNER JOIN ADUASIS.dbo.fgfactura fgf WITH (NOLOCK)
                    ON fgf.id_factura = fdf.id_factura AND fgf.id_cliente = fdf.id_cliente AND fgf.id_proveedor = fdf.id_proveedor
                  WHERE fdt.id_trafico = fgt.id_trafico AND RTRIM(LTRIM(fgf.id_factura)) = @ValFactura)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                  INNER JOIN ADUASIS.dbo.fdfactura fdf WITH (NOLOCK)
                    ON fdf.id_entrada = fdt.id_entrada AND fdf.id_cliente = fgt.id_cliente
                   AND fdf.id_proveedor = fdt.id_proveedor AND fdf.id_producto = fdt.id_producto
                  INNER JOIN ADUASIS.dbo.fgfactura fgf WITH (NOLOCK)
                    ON fgf.id_factura = fdf.id_factura AND fgf.id_cliente = fdf.id_cliente AND fgf.id_proveedor = fdf.id_proveedor
                  WHERE fdt.id_trafico = fgt.id_trafico AND TRY_CONVERT(DATE, fgf.fecha_factura) = @ValFechaFactura)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                  WHERE fdt.id_trafico = fgt.id_trafico AND (fdt.id_unidad_universal = 'PZA' OR fdt.cve_unidad_tarifa = 'PZA'))
OPTION (RECOMPILE);

SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
SELECT @n = COUNT(*) FROM #Candidatos;
INSERT INTO #Eval VALUES ('C camino vacio sin OR LIKE + RECOMPILE', @ms, @n, 'sin predicados busqueda');

/* Resultado página 1 (mismo ORDER BY del SP) */
SELECT paso, elapsed_ms, filas, nota FROM #Eval ORDER BY paso;

SELECT TOP (10)
       id_referencia, id_rectificacion, patente, aduana, pedimento, tipo_operacion, clave_pedimento
FROM #Candidatos
ORDER BY pedimento, id_referencia;
GO
