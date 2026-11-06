/*
  Compara EXISTS con literales vs JOIN a table variables (@UnidadesUMT / @Paises)
  como en el SP — causa típica de mal plan. Sin modificar el SP.
*/
USE ADUASIS;
GO
SET NOCOUNT ON;

DECLARE @idCliente VARCHAR(10) = '9174';
DECLARE @ValProveedor VARCHAR(20) = 'RAM002';
DECLARE @ValProducto VARCHAR(100) = '26551-101-02';
DECLARE @ValFactura VARCHAR(50) = 'T2RA48356812A1';
DECLARE @ValFechaFactura DATE = '2026-10-09';
DECLARE @ActProveedor BIT = 1, @ActProducto BIT = 1, @ActPais BIT = 1;
DECLARE @ActFactura BIT = 1, @ActFechaFactura BIT = 1, @ActUMT BIT = 1;
DECLARE @operacionBusquedaTrim VARCHAR(40) = '';
DECLARE @t0 DATETIME2, @ms INT, @n INT;

DECLARE @Paises TABLE (Pais VARCHAR(1000) NOT NULL);
DECLARE @UnidadesUMT TABLE (IdUnidad VARCHAR(20) NOT NULL PRIMARY KEY);
DECLARE @Productos TABLE (Producto VARCHAR(1000) NOT NULL);

INSERT INTO @Paises (Pais) VALUES ('USA');
INSERT INTO @Productos (Producto) VALUES ('26551-101-02');
INSERT INTO @UnidadesUMT (IdUnidad)
SELECT DISTINCT u.id_unidad_universal
FROM ADUASIS.dbo.funidad_universal AS u WITH (NOLOCK)
WHERE u.id_unidad_universal = 'PZA'
   OR u.cve_unidad_oficial = 'PZA'
   OR u.descripcion LIKE '%PZA%'
   OR u.desc_abreviada LIKE '%PZA%';
INSERT INTO @UnidadesUMT (IdUnidad)
SELECT 'PZA' WHERE NOT EXISTS (SELECT 1 FROM @UnidadesUMT WHERE IdUnidad = 'PZA');

IF OBJECT_ID('tempdb..#Eval') IS NOT NULL DROP TABLE #Eval;
CREATE TABLE #Eval (paso VARCHAR(80), elapsed_ms INT, filas INT, nota VARCHAR(200));

/* G) literales (rápido conocido) */
SET @t0 = SYSDATETIME();
SELECT @n = COUNT(*)
FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
WHERE fgt.id_cliente = @idCliente
      AND (@ActProveedor = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           WHERE fdt.id_trafico = fgt.id_trafico AND fdt.id_proveedor = @ValProveedor))
      AND (@ActProducto = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           WHERE fdt.id_trafico = fgt.id_trafico AND REPLACE(fdt.id_producto,' ','') = @ValProducto))
      AND (@ActPais = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           WHERE fdt.id_trafico = fgt.id_trafico
             AND (fdt.id_pais_origen LIKE '%USA%' OR fdt.id_pais_vendedor LIKE '%USA%')))
      AND (@ActFactura = 0 OR EXISTS (
           SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdfactura fdf WITH (NOLOCK)
             ON fdf.id_entrada = fdt.id_entrada AND fdf.id_cliente = fgt.id_cliente
            AND fdf.id_proveedor = fdt.id_proveedor AND fdf.id_producto = fdt.id_producto
           INNER JOIN ADUASIS.dbo.fgfactura fgf WITH (NOLOCK)
             ON fgf.id_factura = fdf.id_factura AND fgf.id_cliente = fdf.id_cliente AND fgf.id_proveedor = fdf.id_proveedor
           WHERE fdt.id_trafico = fgt.id_trafico AND RTRIM(LTRIM(fgf.id_factura)) = @ValFactura))
      AND (@ActUMT = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           WHERE fdt.id_trafico = fgt.id_trafico AND (fdt.id_unidad_universal = 'PZA' OR fdt.cve_unidad_tarifa = 'PZA')));
SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
INSERT INTO #Eval VALUES ('G literales (sin table var)', @ms, @n, NULL);

/* H) table vars como SP, sin RECOMPILE */
SET @t0 = SYSDATETIME();
SELECT @n = COUNT(*)
FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
WHERE fgt.id_cliente = @idCliente
      AND (@operacionBusquedaTrim = ''
           OR fgt.id_trafico LIKE '%' + @operacionBusquedaTrim + '%'
           OR fgt.id_trafico = @operacionBusquedaTrim)
      AND (@ActProveedor = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           WHERE fdt.id_trafico = fgt.id_trafico AND fdt.id_proveedor = @ValProveedor))
      AND (@ActProducto = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           INNER JOIN @Productos pr ON REPLACE(fdt.id_producto,' ','') = pr.Producto
           WHERE fdt.id_trafico = fgt.id_trafico))
      AND (@ActPais = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           INNER JOIN @Paises p ON fdt.id_pais_origen LIKE '%' + p.Pais + '%'
                                OR fdt.id_pais_vendedor LIKE '%' + p.Pais + '%'
           WHERE fdt.id_trafico = fgt.id_trafico))
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
           INNER JOIN @UnidadesUMT u ON fdt.id_unidad_universal = u.IdUnidad OR fdt.cve_unidad_tarifa = u.IdUnidad
           WHERE fdt.id_trafico = fgt.id_trafico));
SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
INSERT INTO #Eval VALUES ('H table vars SIN RECOMPILE', @ms, @n, 'patron SP exacto');

/* I) table vars + RECOMPILE */
SET @t0 = SYSDATETIME();
SELECT @n = COUNT(*)
FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
WHERE fgt.id_cliente = @idCliente
      AND (@operacionBusquedaTrim = ''
           OR fgt.id_trafico LIKE '%' + @operacionBusquedaTrim + '%'
           OR fgt.id_trafico = @operacionBusquedaTrim)
      AND (@ActProveedor = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           WHERE fdt.id_trafico = fgt.id_trafico AND fdt.id_proveedor = @ValProveedor))
      AND (@ActProducto = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           INNER JOIN @Productos pr ON REPLACE(fdt.id_producto,' ','') = pr.Producto
           WHERE fdt.id_trafico = fgt.id_trafico))
      AND (@ActPais = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           INNER JOIN @Paises p ON fdt.id_pais_origen LIKE '%' + p.Pais + '%'
                                OR fdt.id_pais_vendedor LIKE '%' + p.Pais + '%'
           WHERE fdt.id_trafico = fgt.id_trafico))
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
           INNER JOIN @UnidadesUMT u ON fdt.id_unidad_universal = u.IdUnidad OR fdt.cve_unidad_tarifa = u.IdUnidad
           WHERE fdt.id_trafico = fgt.id_trafico))
OPTION (RECOMPILE);
SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
INSERT INTO #Eval VALUES ('I table vars CON RECOMPILE', @ms, @n, 'candidato a aplicar en SP');

SELECT * FROM #Eval ORDER BY paso;
SELECT (SELECT COUNT(*) FROM @UnidadesUMT) AS unidades_umt_cargadas;
GO
