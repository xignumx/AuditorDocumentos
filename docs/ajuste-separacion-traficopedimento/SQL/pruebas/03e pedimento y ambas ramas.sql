/*
  Pedimento (HayFiltroTrafico) + ambas ramas juntas, patrón @Act + table vars.
  Sin modificar el SP.
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
INSERT INTO @Paises VALUES ('USA');
INSERT INTO @Productos VALUES ('26551-101-02');
INSERT INTO @UnidadesUMT (IdUnidad)
SELECT DISTINCT u.id_unidad_universal
FROM ADUASIS.dbo.funidad_universal u WITH (NOLOCK)
WHERE u.id_unidad_universal = 'PZA' OR u.cve_unidad_oficial = 'PZA'
   OR u.descripcion LIKE '%PZA%' OR u.desc_abreviada LIKE '%PZA%';
IF NOT EXISTS (SELECT 1 FROM @UnidadesUMT WHERE IdUnidad = 'PZA')
    INSERT INTO @UnidadesUMT VALUES ('PZA');

IF OBJECT_ID('tempdb..#Eval') IS NOT NULL DROP TABLE #Eval;
CREATE TABLE #Eval (paso VARCHAR(80), elapsed_ms INT, filas INT, nota VARCHAR(200));
IF OBJECT_ID('tempdb..#C') IS NOT NULL DROP TABLE #C;
CREATE TABLE #C (
    id_referencia VARCHAR(50) NOT NULL,
    id_rectificacion INT NULL,
    patente VARCHAR(10) NOT NULL,
    aduana VARCHAR(20) NOT NULL,
    pedimento VARCHAR(50) NOT NULL,
    tipo_operacion VARCHAR(5) NOT NULL,
    clave_pedimento VARCHAR(10) NOT NULL
);

/* J) solo pedimento HayFiltroTrafico + table vars */
TRUNCATE TABLE #C;
SET @t0 = SYSDATETIME();
INSERT INTO #C
SELECT fped.id_referencia, CAST(fped.id_rectificacion AS INT), fped.id_patente,
       fped.id_aduana + fped.seccion, fped.pedimento, fped.cve_tipo_operacion, fped.id_regimen
FROM ADUASIS.dbo.fpedimento AS fped WITH (NOLOCK)
WHERE fped.fecha_pago_banco IS NULL AND fped.firma_banco IS NULL
      AND fped.id_cliente = @idCliente AND fped.pedimento <> ''
      AND (@operacionBusquedaTrim = ''
           OR fped.pedimento LIKE '%' + @operacionBusquedaTrim + '%'
           OR fped.id_referencia LIKE '%' + @operacionBusquedaTrim + '%')
      AND (@ActFactura = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura rel WITH (NOLOCK)
           WHERE rel.id_referencia = fped.id_referencia AND rel.id_rectificacion = fped.id_rectificacion
             AND RTRIM(LTRIM(rel.id_factura)) = @ValFactura))
      AND (@ActFechaFactura = 0 OR @ValFechaFactura IS NULL OR EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura rel WITH (NOLOCK)
           WHERE rel.id_referencia = fped.id_referencia AND rel.id_rectificacion = fped.id_rectificacion
             AND TRY_CONVERT(DATE, rel.fecha_factura) = @ValFechaFactura))
      AND (@ActProveedor = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
           WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
             AND fdt.id_proveedor = @ValProveedor))
      AND (@ActProducto = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
           INNER JOIN @Productos pr ON REPLACE(fdt.id_producto,' ','') = pr.Producto
           WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0))
      AND (@ActPais = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
           INNER JOIN @Paises p ON fdt.id_pais_origen LIKE '%' + p.Pais + '%' OR fdt.id_pais_vendedor LIKE '%' + p.Pais + '%'
           WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0))
      AND (@ActUMT = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
           INNER JOIN @UnidadesUMT u ON fdt.id_unidad_universal = u.IdUnidad OR fdt.cve_unidad_tarifa = u.IdUnidad
           WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0));
SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
SELECT @n = COUNT(*) FROM #C;
INSERT INTO #Eval VALUES ('J solo pedimento @Act+tablevar', @ms, @n, 'sin RECOMPILE');

/* K) pedimento CON RECOMPILE */
TRUNCATE TABLE #C;
SET @t0 = SYSDATETIME();
INSERT INTO #C
SELECT fped.id_referencia, CAST(fped.id_rectificacion AS INT), fped.id_patente,
       fped.id_aduana + fped.seccion, fped.pedimento, fped.cve_tipo_operacion, fped.id_regimen
FROM ADUASIS.dbo.fpedimento AS fped WITH (NOLOCK)
WHERE fped.fecha_pago_banco IS NULL AND fped.firma_banco IS NULL
      AND fped.id_cliente = @idCliente AND fped.pedimento <> ''
      AND (@operacionBusquedaTrim = ''
           OR fped.pedimento LIKE '%' + @operacionBusquedaTrim + '%'
           OR fped.id_referencia LIKE '%' + @operacionBusquedaTrim + '%')
      AND (@ActFactura = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura rel WITH (NOLOCK)
           WHERE rel.id_referencia = fped.id_referencia AND rel.id_rectificacion = fped.id_rectificacion
             AND RTRIM(LTRIM(rel.id_factura)) = @ValFactura))
      AND (@ActFechaFactura = 0 OR @ValFechaFactura IS NULL OR EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura rel WITH (NOLOCK)
           WHERE rel.id_referencia = fped.id_referencia AND rel.id_rectificacion = fped.id_rectificacion
             AND TRY_CONVERT(DATE, rel.fecha_factura) = @ValFechaFactura))
      AND (@ActProveedor = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
           WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
             AND fdt.id_proveedor = @ValProveedor))
      AND (@ActProducto = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
           INNER JOIN @Productos pr ON REPLACE(fdt.id_producto,' ','') = pr.Producto
           WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0))
      AND (@ActPais = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
           INNER JOIN @Paises p ON fdt.id_pais_origen LIKE '%' + p.Pais + '%' OR fdt.id_pais_vendedor LIKE '%' + p.Pais + '%'
           WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0))
      AND (@ActUMT = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
           INNER JOIN @UnidadesUMT u ON fdt.id_unidad_universal = u.IdUnidad OR fdt.cve_unidad_tarifa = u.IdUnidad
           WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0))
OPTION (RECOMPILE);
SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
SELECT @n = COUNT(*) FROM #C;
INSERT INTO #Eval VALUES ('K solo pedimento CON RECOMPILE', @ms, @n, NULL);

/* L) AMBAS ramas sin RECOMPILE (más parecido al SP) */
TRUNCATE TABLE #C;
SET @t0 = SYSDATETIME();
INSERT INTO #C
SELECT fped.id_referencia, CAST(fped.id_rectificacion AS INT), fped.id_patente,
       fped.id_aduana + fped.seccion, fped.pedimento, fped.cve_tipo_operacion, fped.id_regimen
FROM ADUASIS.dbo.fpedimento AS fped WITH (NOLOCK)
WHERE fped.fecha_pago_banco IS NULL AND fped.firma_banco IS NULL
      AND fped.id_cliente = @idCliente AND fped.pedimento <> ''
      AND (@operacionBusquedaTrim = ''
           OR fped.pedimento LIKE '%' + @operacionBusquedaTrim + '%'
           OR fped.id_referencia LIKE '%' + @operacionBusquedaTrim + '%')
      AND (@ActFactura = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura rel WITH (NOLOCK)
           WHERE rel.id_referencia = fped.id_referencia AND rel.id_rectificacion = fped.id_rectificacion
             AND RTRIM(LTRIM(rel.id_factura)) = @ValFactura))
      AND (@ActFechaFactura = 0 OR @ValFechaFactura IS NULL OR EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura rel WITH (NOLOCK)
           WHERE rel.id_referencia = fped.id_referencia AND rel.id_rectificacion = fped.id_rectificacion
             AND TRY_CONVERT(DATE, rel.fecha_factura) = @ValFechaFactura))
      AND (@ActProveedor = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
           WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
             AND fdt.id_proveedor = @ValProveedor))
      AND (@ActProducto = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
           INNER JOIN @Productos pr ON REPLACE(fdt.id_producto,' ','') = pr.Producto
           WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0))
      AND (@ActPais = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
           INNER JOIN @Paises p ON fdt.id_pais_origen LIKE '%' + p.Pais + '%' OR fdt.id_pais_vendedor LIKE '%' + p.Pais + '%'
           WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0))
      AND (@ActUMT = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
           INNER JOIN @UnidadesUMT u ON fdt.id_unidad_universal = u.IdUnidad OR fdt.cve_unidad_tarifa = u.IdUnidad
           WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0));

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
           INNER JOIN @Productos pr ON REPLACE(fdt.id_producto,' ','') = pr.Producto
           WHERE fdt.id_trafico = fgt.id_trafico))
      AND (@ActPais = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           INNER JOIN @Paises p ON fdt.id_pais_origen LIKE '%' + p.Pais + '%' OR fdt.id_pais_vendedor LIKE '%' + p.Pais + '%'
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
SELECT @n = COUNT(*) FROM #C;
INSERT INTO #Eval VALUES ('L ambas ramas SIN RECOMPILE', @ms, @n, 'mas parecido al SP');

/* M) AMBAS ramas CON RECOMPILE en cada INSERT */
TRUNCATE TABLE #C;
SET @t0 = SYSDATETIME();
INSERT INTO #C
SELECT fped.id_referencia, CAST(fped.id_rectificacion AS INT), fped.id_patente,
       fped.id_aduana + fped.seccion, fped.pedimento, fped.cve_tipo_operacion, fped.id_regimen
FROM ADUASIS.dbo.fpedimento AS fped WITH (NOLOCK)
WHERE fped.fecha_pago_banco IS NULL AND fped.firma_banco IS NULL
      AND fped.id_cliente = @idCliente AND fped.pedimento <> ''
      AND (@operacionBusquedaTrim = ''
           OR fped.pedimento LIKE '%' + @operacionBusquedaTrim + '%'
           OR fped.id_referencia LIKE '%' + @operacionBusquedaTrim + '%')
      AND (@ActFactura = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura rel WITH (NOLOCK)
           WHERE rel.id_referencia = fped.id_referencia AND rel.id_rectificacion = fped.id_rectificacion
             AND RTRIM(LTRIM(rel.id_factura)) = @ValFactura))
      AND (@ActFechaFactura = 0 OR @ValFechaFactura IS NULL OR EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura rel WITH (NOLOCK)
           WHERE rel.id_referencia = fped.id_referencia AND rel.id_rectificacion = fped.id_rectificacion
             AND TRY_CONVERT(DATE, rel.fecha_factura) = @ValFechaFactura))
      AND (@ActProveedor = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
           WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
             AND fdt.id_proveedor = @ValProveedor))
      AND (@ActProducto = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
           INNER JOIN @Productos pr ON REPLACE(fdt.id_producto,' ','') = pr.Producto
           WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0))
      AND (@ActPais = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
           INNER JOIN @Paises p ON fdt.id_pais_origen LIKE '%' + p.Pais + '%' OR fdt.id_pais_vendedor LIKE '%' + p.Pais + '%'
           WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0))
      AND (@ActUMT = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
           INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
           INNER JOIN @UnidadesUMT u ON fdt.id_unidad_universal = u.IdUnidad OR fdt.cve_unidad_tarifa = u.IdUnidad
           WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0))
OPTION (RECOMPILE);

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
           INNER JOIN @Productos pr ON REPLACE(fdt.id_producto,' ','') = pr.Producto
           WHERE fdt.id_trafico = fgt.id_trafico))
      AND (@ActPais = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
           INNER JOIN @Paises p ON fdt.id_pais_origen LIKE '%' + p.Pais + '%' OR fdt.id_pais_vendedor LIKE '%' + p.Pais + '%'
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
SELECT @n = COUNT(*) FROM #C;
INSERT INTO #Eval VALUES ('M ambas ramas CON RECOMPILE', @ms, @n, 'candidato SP');

SELECT * FROM #Eval ORDER BY paso;
SELECT TOP 5 id_referencia, id_rectificacion, pedimento FROM #C ORDER BY pedimento, id_referencia;
GO
