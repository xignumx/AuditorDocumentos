/*
  Evalúa el patrón real del SP: (@ActX = 0 OR EXISTS(...))
  con variables locales, filtro vacío, sin modificar el SP.
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
DECLARE @ActProveedor BIT = 1;
DECLARE @ActProducto BIT = 1;
DECLARE @ActPais BIT = 1;
DECLARE @ActFactura BIT = 1;
DECLARE @ActFechaFactura BIT = 1;
DECLARE @ActUMT BIT = 1;
DECLARE @t0 DATETIME2;
DECLARE @ms INT;
DECLARE @n INT;

IF OBJECT_ID('tempdb..#Eval') IS NOT NULL DROP TABLE #Eval;
CREATE TABLE #Eval (paso VARCHAR(80), elapsed_ms INT, filas INT, nota VARCHAR(200));

IF OBJECT_ID('tempdb..#C') IS NOT NULL DROP TABLE #C;
CREATE TABLE #C
(
    id_referencia VARCHAR(50) NOT NULL,
    id_rectificacion INT NULL,
    patente VARCHAR(10) NOT NULL,
    aduana VARCHAR(20) NOT NULL,
    pedimento VARCHAR(50) NOT NULL,
    tipo_operacion VARCHAR(5) NOT NULL,
    clave_pedimento VARCHAR(10) NOT NULL
);

/* ---- D) patrón @Act sin RECOMPILE ---- */
TRUNCATE TABLE #C;
SET @t0 = SYSDATETIME();

INSERT INTO #C
SELECT fgt.id_trafico, NULL, ISNULL(fgt.id_patente, ''),
       ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, ''), '',
       CASE WHEN fgt.cve_tipo_operacion = '0' THEN '1' WHEN fgt.cve_tipo_operacion = '1' THEN '2' ELSE '' END,
       fgt.id_regimen
FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
WHERE fgt.id_cliente = @idCliente
      AND (@operacionBusquedaTrim = ''
           OR fgt.id_trafico LIKE '%' + @operacionBusquedaTrim + '%'
           OR fgt.id_trafico = @operacionBusquedaTrim)
      AND (@ActProveedor = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           WHERE fdt.id_trafico = fgt.id_trafico AND fdt.id_proveedor = @ValProveedor))
      AND (@ActProducto = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           WHERE fdt.id_trafico = fgt.id_trafico AND REPLACE(fdt.id_producto, ' ', '') = @ValProducto))
      AND (@ActPais = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           WHERE fdt.id_trafico = fgt.id_trafico
             AND (fdt.id_pais_origen LIKE '%' + @ValPais + '%' OR fdt.id_pais_vendedor LIKE '%' + @ValPais + '%')))
      AND (@ActFactura = 0 OR EXISTS (
           SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdfactura fdf WITH (NOLOCK)
             ON fdf.id_entrada = fdt.id_entrada AND fdf.id_cliente = fgt.id_cliente
            AND fdf.id_proveedor = fdt.id_proveedor AND fdf.id_producto = fdt.id_producto
           INNER JOIN ADUASIS.dbo.fgfactura fgf WITH (NOLOCK)
             ON fgf.id_factura = fdf.id_factura AND fgf.id_cliente = fdf.id_cliente AND fgf.id_proveedor = fdf.id_proveedor
           WHERE fdt.id_trafico = fgt.id_trafico AND RTRIM(LTRIM(fgf.id_factura)) = @ValFactura))
      AND (@ActFechaFactura = 0 OR @ValFechaFactura IS NULL OR EXISTS (
           SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdfactura fdf WITH (NOLOCK)
             ON fdf.id_entrada = fdt.id_entrada AND fdf.id_cliente = fgt.id_cliente
            AND fdf.id_proveedor = fdt.id_proveedor AND fdf.id_producto = fdt.id_producto
           INNER JOIN ADUASIS.dbo.fgfactura fgf WITH (NOLOCK)
             ON fgf.id_factura = fdf.id_factura AND fgf.id_cliente = fdf.id_cliente AND fgf.id_proveedor = fdf.id_proveedor
           WHERE fdt.id_trafico = fgt.id_trafico AND TRY_CONVERT(DATE, fgf.fecha_factura) = @ValFechaFactura))
      AND (@ActUMT = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           WHERE fdt.id_trafico = fgt.id_trafico AND (fdt.id_unidad_universal = 'PZA' OR fdt.cve_unidad_tarifa = 'PZA')));

SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
SELECT @n = COUNT(*) FROM #C;
INSERT INTO #Eval VALUES ('D trafico @Act sin RECOMPILE', @ms, @n, 'patron SP');

/* ---- E) patrón @Act CON RECOMPILE ---- */
TRUNCATE TABLE #C;
SET @t0 = SYSDATETIME();

INSERT INTO #C
SELECT fgt.id_trafico, NULL, ISNULL(fgt.id_patente, ''),
       ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, ''), '',
       CASE WHEN fgt.cve_tipo_operacion = '0' THEN '1' WHEN fgt.cve_tipo_operacion = '1' THEN '2' ELSE '' END,
       fgt.id_regimen
FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
WHERE fgt.id_cliente = @idCliente
      AND (@operacionBusquedaTrim = ''
           OR fgt.id_trafico LIKE '%' + @operacionBusquedaTrim + '%'
           OR fgt.id_trafico = @operacionBusquedaTrim)
      AND (@ActProveedor = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           WHERE fdt.id_trafico = fgt.id_trafico AND fdt.id_proveedor = @ValProveedor))
      AND (@ActProducto = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           WHERE fdt.id_trafico = fgt.id_trafico AND REPLACE(fdt.id_producto, ' ', '') = @ValProducto))
      AND (@ActPais = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           WHERE fdt.id_trafico = fgt.id_trafico
             AND (fdt.id_pais_origen LIKE '%' + @ValPais + '%' OR fdt.id_pais_vendedor LIKE '%' + @ValPais + '%')))
      AND (@ActFactura = 0 OR EXISTS (
           SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdfactura fdf WITH (NOLOCK)
             ON fdf.id_entrada = fdt.id_entrada AND fdf.id_cliente = fgt.id_cliente
            AND fdf.id_proveedor = fdt.id_proveedor AND fdf.id_producto = fdt.id_producto
           INNER JOIN ADUASIS.dbo.fgfactura fgf WITH (NOLOCK)
             ON fgf.id_factura = fdf.id_factura AND fgf.id_cliente = fdf.id_cliente AND fgf.id_proveedor = fdf.id_proveedor
           WHERE fdt.id_trafico = fgt.id_trafico AND RTRIM(LTRIM(fgf.id_factura)) = @ValFactura))
      AND (@ActFechaFactura = 0 OR @ValFechaFactura IS NULL OR EXISTS (
           SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdfactura fdf WITH (NOLOCK)
             ON fdf.id_entrada = fdt.id_entrada AND fdf.id_cliente = fgt.id_cliente
            AND fdf.id_proveedor = fdt.id_proveedor AND fdf.id_producto = fdt.id_producto
           INNER JOIN ADUASIS.dbo.fgfactura fgf WITH (NOLOCK)
             ON fgf.id_factura = fdf.id_factura AND fgf.id_cliente = fdf.id_cliente AND fgf.id_proveedor = fdf.id_proveedor
           WHERE fdt.id_trafico = fgt.id_trafico AND TRY_CONVERT(DATE, fgf.fecha_factura) = @ValFechaFactura))
      AND (@ActUMT = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           WHERE fdt.id_trafico = fgt.id_trafico AND (fdt.id_unidad_universal = 'PZA' OR fdt.cve_unidad_tarifa = 'PZA')))
OPTION (RECOMPILE);

SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
SELECT @n = COUNT(*) FROM #C;
INSERT INTO #Eval VALUES ('E trafico @Act CON RECOMPILE', @ms, @n, 'patron SP + RECOMPILE');

/* ---- F) @Act + sin OR busqueda + RECOMPILE ---- */
TRUNCATE TABLE #C;
SET @t0 = SYSDATETIME();

INSERT INTO #C
SELECT fgt.id_trafico, NULL, ISNULL(fgt.id_patente, ''),
       ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, ''), '',
       CASE WHEN fgt.cve_tipo_operacion = '0' THEN '1' WHEN fgt.cve_tipo_operacion = '1' THEN '2' ELSE '' END,
       fgt.id_regimen
FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
WHERE fgt.id_cliente = @idCliente
      AND (@ActProveedor = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           WHERE fdt.id_trafico = fgt.id_trafico AND fdt.id_proveedor = @ValProveedor))
      AND (@ActProducto = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           WHERE fdt.id_trafico = fgt.id_trafico AND REPLACE(fdt.id_producto, ' ', '') = @ValProducto))
      AND (@ActPais = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           WHERE fdt.id_trafico = fgt.id_trafico
             AND (fdt.id_pais_origen LIKE '%' + @ValPais + '%' OR fdt.id_pais_vendedor LIKE '%' + @ValPais + '%')))
      AND (@ActFactura = 0 OR EXISTS (
           SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdfactura fdf WITH (NOLOCK)
             ON fdf.id_entrada = fdt.id_entrada AND fdf.id_cliente = fgt.id_cliente
            AND fdf.id_proveedor = fdt.id_proveedor AND fdf.id_producto = fdt.id_producto
           INNER JOIN ADUASIS.dbo.fgfactura fgf WITH (NOLOCK)
             ON fgf.id_factura = fdf.id_factura AND fgf.id_cliente = fdf.id_cliente AND fgf.id_proveedor = fdf.id_proveedor
           WHERE fdt.id_trafico = fgt.id_trafico AND RTRIM(LTRIM(fgf.id_factura)) = @ValFactura))
      AND (@ActFechaFactura = 0 OR @ValFechaFactura IS NULL OR EXISTS (
           SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdfactura fdf WITH (NOLOCK)
             ON fdf.id_entrada = fdt.id_entrada AND fdf.id_cliente = fgt.id_cliente
            AND fdf.id_proveedor = fdt.id_proveedor AND fdf.id_producto = fdt.id_producto
           INNER JOIN ADUASIS.dbo.fgfactura fgf WITH (NOLOCK)
             ON fgf.id_factura = fdf.id_factura AND fgf.id_cliente = fdf.id_cliente AND fgf.id_proveedor = fdf.id_proveedor
           WHERE fdt.id_trafico = fgt.id_trafico AND TRY_CONVERT(DATE, fgf.fecha_factura) = @ValFechaFactura))
      AND (@ActUMT = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           WHERE fdt.id_trafico = fgt.id_trafico AND (fdt.id_unidad_universal = 'PZA' OR fdt.cve_unidad_tarifa = 'PZA')))
OPTION (RECOMPILE);

SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
SELECT @n = COUNT(*) FROM #C;
INSERT INTO #Eval VALUES ('F trafico @Act sin OR busq + RECOMPILE', @ms, @n, 'mejor candidato');

SELECT * FROM #Eval ORDER BY paso;
SELECT TOP 5 id_referencia, pedimento FROM #C ORDER BY pedimento, id_referencia;
GO
