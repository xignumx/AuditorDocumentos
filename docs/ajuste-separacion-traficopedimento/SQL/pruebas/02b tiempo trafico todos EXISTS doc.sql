/*
  Complemento: costo rama tráfico con TODOS los EXISTS del doc 35081
  (como el SP en filtro vacío), actual vs anterior. Sin modificar el SP.
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
DECLARE @t0 DATETIME2;
DECLARE @ms INT;
DECLARE @n INT;

IF OBJECT_ID('tempdb..#T') IS NOT NULL DROP TABLE #T;
CREATE TABLE #T (paso VARCHAR(80), elapsed_ms INT, filas INT, nota VARCHAR(200));

/* ACTUAL: sin excluir por pedimento + todos EXISTS */
SET @t0 = SYSDATETIME();
SELECT @n = COUNT(*)
FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
WHERE fgt.id_cliente = @idCliente
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) WHERE fdt.id_trafico = fgt.id_trafico AND fdt.id_proveedor = @ValProveedor)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) WHERE fdt.id_trafico = fgt.id_trafico AND REPLACE(fdt.id_producto,' ','') = @ValProducto)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) WHERE fdt.id_trafico = fgt.id_trafico AND (fdt.id_pais_origen LIKE '%'+@ValPais+'%' OR fdt.id_pais_vendedor LIKE '%'+@ValPais+'%'))
      AND EXISTS (
          SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
          INNER JOIN ADUASIS.dbo.fdfactura fdf WITH (NOLOCK)
            ON fdf.id_entrada = fdt.id_entrada AND fdf.id_cliente = fgt.id_cliente
           AND fdf.id_proveedor = fdt.id_proveedor AND fdf.id_producto = fdt.id_producto
          INNER JOIN ADUASIS.dbo.fgfactura fgf WITH (NOLOCK)
            ON fgf.id_factura = fdf.id_factura AND fgf.id_cliente = fdf.id_cliente AND fgf.id_proveedor = fdf.id_proveedor
          WHERE fdt.id_trafico = fgt.id_trafico AND RTRIM(LTRIM(fgf.id_factura)) = @ValFactura)
      AND EXISTS (
          SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
          INNER JOIN ADUASIS.dbo.fdfactura fdf WITH (NOLOCK)
            ON fdf.id_entrada = fdt.id_entrada AND fdf.id_cliente = fgt.id_cliente
           AND fdf.id_proveedor = fdt.id_proveedor AND fdf.id_producto = fdt.id_producto
          INNER JOIN ADUASIS.dbo.fgfactura fgf WITH (NOLOCK)
            ON fgf.id_factura = fdf.id_factura AND fgf.id_cliente = fdf.id_cliente AND fgf.id_proveedor = fdf.id_proveedor
          WHERE fdt.id_trafico = fgt.id_trafico AND TRY_CONVERT(DATE, fgf.fecha_factura) = @ValFechaFactura)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) WHERE fdt.id_trafico = fgt.id_trafico AND (fdt.id_unidad_universal = 'PZA' OR fdt.cve_unidad_tarifa = 'PZA'));
SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
INSERT INTO #T VALUES ('TRAFICO actual todos EXISTS doc', @ms, @n, 'sin NOT EXISTS pedimento');

/* ANTERIOR: con excluir pedimento + mismos EXISTS */
SET @t0 = SYSDATETIME();
SELECT @n = COUNT(*)
FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
WHERE fgt.id_cliente = @idCliente
      AND NOT EXISTS (
          SELECT 1 FROM ADUASIS.dbo.fpedimento fped WITH (NOLOCK)
          WHERE NULLIF(RTRIM(fgt.id_referencia),'') IS NOT NULL
            AND fped.id_cliente = fgt.id_cliente
            AND fped.id_referencia = fgt.id_referencia
            AND fped.id_rectificacion = fgt.id_rectificacion)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) WHERE fdt.id_trafico = fgt.id_trafico AND fdt.id_proveedor = @ValProveedor)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) WHERE fdt.id_trafico = fgt.id_trafico AND REPLACE(fdt.id_producto,' ','') = @ValProducto)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) WHERE fdt.id_trafico = fgt.id_trafico AND (fdt.id_pais_origen LIKE '%'+@ValPais+'%' OR fdt.id_pais_vendedor LIKE '%'+@ValPais+'%'))
      AND EXISTS (
          SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
          INNER JOIN ADUASIS.dbo.fdfactura fdf WITH (NOLOCK)
            ON fdf.id_entrada = fdt.id_entrada AND fdf.id_cliente = fgt.id_cliente
           AND fdf.id_proveedor = fdt.id_proveedor AND fdf.id_producto = fdt.id_producto
          INNER JOIN ADUASIS.dbo.fgfactura fgf WITH (NOLOCK)
            ON fgf.id_factura = fdf.id_factura AND fgf.id_cliente = fdf.id_cliente AND fgf.id_proveedor = fdf.id_proveedor
          WHERE fdt.id_trafico = fgt.id_trafico AND RTRIM(LTRIM(fgf.id_factura)) = @ValFactura)
      AND EXISTS (
          SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
          INNER JOIN ADUASIS.dbo.fdfactura fdf WITH (NOLOCK)
            ON fdf.id_entrada = fdt.id_entrada AND fdf.id_cliente = fgt.id_cliente
           AND fdf.id_proveedor = fdt.id_proveedor AND fdf.id_producto = fdt.id_producto
          INNER JOIN ADUASIS.dbo.fgfactura fgf WITH (NOLOCK)
            ON fgf.id_factura = fdf.id_factura AND fgf.id_cliente = fdf.id_cliente AND fgf.id_proveedor = fdf.id_proveedor
          WHERE fdt.id_trafico = fgt.id_trafico AND TRY_CONVERT(DATE, fgf.fecha_factura) = @ValFechaFactura)
      AND EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) WHERE fdt.id_trafico = fgt.id_trafico AND (fdt.id_unidad_universal = 'PZA' OR fdt.cve_unidad_tarifa = 'PZA'));
SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
INSERT INTO #T VALUES ('TRAFICO anterior todos EXISTS doc', @ms, @n, 'con NOT EXISTS pedimento');

SELECT * FROM #T ORDER BY paso;
GO
