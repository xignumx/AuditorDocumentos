/*
  Baseline esperado (lectura) — mismos filtros del doc 35081 / cliente 9174
  operacionBusqueda vacía.

  NO modifica el SP. Como Factura (T2RA48356812A1) está obligatoria+visible+valor,
  todo candidato del SP DEBE cumplir esa factura; se enumeran candidatos
  partiendo de factura (misma semántica AND EXISTS del SP).
*/
USE ADUASIS;
GO
SET NOCOUNT ON;

DECLARE @idCliente VARCHAR(10) = '9174';
DECLARE @ValFactura VARCHAR(50) = 'T2RA48356812A1';
DECLARE @ValFechaFactura DATE = '2026-10-09';
DECLARE @ValProveedor VARCHAR(20) = 'RAM002';
DECLARE @ValProducto VARCHAR(100) = '26551-101-02';
DECLARE @ValPais VARCHAR(20) = 'USA';
DECLARE @t0 DATETIME2 = SYSDATETIME();

IF OBJECT_ID('tempdb..#Candidatos') IS NOT NULL DROP TABLE #Candidatos;
CREATE TABLE #Candidatos
(
    id_referencia VARCHAR(40) NOT NULL,
    id_rectificacion INT NULL,
    patente VARCHAR(40) NULL,
    aduana VARCHAR(40) NULL,
    pedimento VARCHAR(40) NULL,
    tipo_operacion VARCHAR(10) NULL,
    clave_pedimento VARCHAR(20) NULL
);

/* --- Pedimentos abiertos con factura + filtros partida (EXISTS independientes) --- */
INSERT INTO #Candidatos
SELECT fped.id_referencia,
       CAST(fped.id_rectificacion AS INT),
       fped.id_patente,
       fped.id_aduana + fped.seccion,
       fped.pedimento,
       fped.cve_tipo_operacion,
       fped.id_regimen
FROM ADUASIS.dbo.fpedimento AS fped WITH (NOLOCK)
WHERE fped.fecha_pago_banco IS NULL
      AND fped.firma_banco IS NULL
      AND fped.id_cliente = @idCliente
      AND fped.pedimento <> ''
      AND EXISTS
(
    SELECT 1
    FROM ADUASIS.dbo.frel_pedimento_factura AS rel WITH (NOLOCK)
    WHERE rel.id_referencia = fped.id_referencia
          AND rel.id_rectificacion = fped.id_rectificacion
          AND RTRIM(LTRIM(rel.id_factura)) = @ValFactura
)
      AND EXISTS
(
    SELECT 1
    FROM ADUASIS.dbo.frel_pedimento_factura AS rel WITH (NOLOCK)
    WHERE rel.id_referencia = fped.id_referencia
          AND rel.id_rectificacion = fped.id_rectificacion
          AND TRY_CONVERT(DATE, rel.fecha_factura) = @ValFechaFactura
)
      AND EXISTS
(
    SELECT 1
    FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
        INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
            ON fdt.id_trafico = fgt.id_trafico
    WHERE fgt.id_referencia = fped.id_referencia
          AND fgt.id_rectificacion = 0
          AND fdt.id_proveedor = @ValProveedor
)
      AND EXISTS
(
    SELECT 1
    FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
        INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
            ON fdt.id_trafico = fgt.id_trafico
    WHERE fgt.id_referencia = fped.id_referencia
          AND fgt.id_rectificacion = 0
          AND REPLACE(fdt.id_producto, ' ', '') = @ValProducto
)
      AND EXISTS
(
    SELECT 1
    FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
        INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
            ON fdt.id_trafico = fgt.id_trafico
    WHERE fgt.id_referencia = fped.id_referencia
          AND fgt.id_rectificacion = 0
          AND (fdt.id_pais_origen LIKE '%' + @ValPais + '%'
               OR fdt.id_pais_vendedor LIKE '%' + @ValPais + '%')
);

/* --- Tráficos (incluye con pedimento) con factura + filtros --- */
INSERT INTO #Candidatos
SELECT fgt.id_trafico,
       NULL,
       ISNULL(fgt.id_patente, ''),
       ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, ''),
       '',
       CASE
           WHEN fgt.cve_tipo_operacion = '0' THEN '1'
           WHEN fgt.cve_tipo_operacion = '1' THEN '2'
           ELSE ''
       END,
       fgt.id_regimen
FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
WHERE fgt.id_cliente = @idCliente
      AND EXISTS
(
    SELECT 1
    FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
        INNER JOIN ADUASIS.dbo.fdfactura AS fdf WITH (NOLOCK)
            ON fdf.id_entrada = fdt.id_entrada
               AND fdf.id_cliente = fgt.id_cliente
               AND fdf.id_proveedor = fdt.id_proveedor
               AND fdf.id_producto = fdt.id_producto
        INNER JOIN ADUASIS.dbo.fgfactura AS fgf WITH (NOLOCK)
            ON fgf.id_factura = fdf.id_factura
               AND fgf.id_cliente = fdf.id_cliente
               AND fgf.id_proveedor = fdf.id_proveedor
    WHERE fdt.id_trafico = fgt.id_trafico
          AND RTRIM(LTRIM(fgf.id_factura)) = @ValFactura
)
      AND EXISTS
(
    SELECT 1
    FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
        INNER JOIN ADUASIS.dbo.fdfactura AS fdf WITH (NOLOCK)
            ON fdf.id_entrada = fdt.id_entrada
               AND fdf.id_cliente = fgt.id_cliente
               AND fdf.id_proveedor = fdt.id_proveedor
               AND fdf.id_producto = fdt.id_producto
        INNER JOIN ADUASIS.dbo.fgfactura AS fgf WITH (NOLOCK)
            ON fgf.id_factura = fdf.id_factura
               AND fgf.id_cliente = fdf.id_cliente
               AND fgf.id_proveedor = fdf.id_proveedor
    WHERE fdt.id_trafico = fgt.id_trafico
          AND TRY_CONVERT(DATE, fgf.fecha_factura) = @ValFechaFactura
)
      AND EXISTS
(
    SELECT 1
    FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
    WHERE fdt.id_trafico = fgt.id_trafico
          AND fdt.id_proveedor = @ValProveedor
)
      AND EXISTS
(
    SELECT 1
    FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
    WHERE fdt.id_trafico = fgt.id_trafico
          AND REPLACE(fdt.id_producto, ' ', '') = @ValProducto
)
      AND EXISTS
(
    SELECT 1
    FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
    WHERE fdt.id_trafico = fgt.id_trafico
          AND (fdt.id_pais_origen LIKE '%' + @ValPais + '%'
               OR fdt.id_pais_vendedor LIKE '%' + @ValPais + '%')
);

DECLARE @total INT = (SELECT COUNT(*) FROM #Candidatos);
DECLARE @elapsed INT = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());

SELECT 'ESPERADO_VACIO' AS status,
       @elapsed AS elapsed_ms_diagnostico,
       @total AS total_records;

SELECT TOP (10)
       id_referencia,
       id_rectificacion,
       patente,
       aduana,
       pedimento,
       tipo_operacion,
       clave_pedimento,
       @total AS TotalRecords
FROM #Candidatos
ORDER BY pedimento, id_referencia;
GO
