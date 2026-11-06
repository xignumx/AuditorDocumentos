/*
  Medición de tiempos — ramas pedimento vs tráfico
  Caso: idCliente=9174, filtros de partida del doc 35081 (sin modificar el SP)

  Compara:
    1) Volúmenes
    2) Rama pedimentos abiertos + EXISTS partida
    3) Rama tráfico ACTUAL (sin excluir por pedimento) + EXISTS partida
    4) Rama tráfico ANTERIOR (NOT EXISTS fpedimento) + EXISTS partida
    5) Prefiltro #TrafCliente + EXISTS (candidata de optimización, solo lectura)
    6) EXEC SP con búsqueda (referencia conocida ~419ms)
*/
USE ADUASIS;
GO
SET NOCOUNT ON;

DECLARE @idCliente VARCHAR(10) = '9174';
DECLARE @ValProveedor VARCHAR(20) = 'RAM002';
DECLARE @ValProducto VARCHAR(100) = '26551-101-02';
DECLARE @ValPais VARCHAR(20) = 'USA';
DECLARE @t0 DATETIME2;
DECLARE @ms INT;
DECLARE @n INT;

IF OBJECT_ID('tempdb..#Tiempos') IS NOT NULL DROP TABLE #Tiempos;
CREATE TABLE #Tiempos
(
    paso VARCHAR(80) NOT NULL,
    elapsed_ms INT NOT NULL,
    filas INT NULL,
    nota VARCHAR(200) NULL
);

/* ========== 1) Volúmenes ========== */
SET @t0 = SYSDATETIME();
SELECT @n = COUNT(*) FROM ADUASIS.dbo.fgtrafico WITH (NOLOCK) WHERE id_cliente = @idCliente;
SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
INSERT INTO #Tiempos VALUES ('01 volumen traficos cliente', @ms, @n, 'fgtrafico por id_cliente');

SET @t0 = SYSDATETIME();
SELECT @n = COUNT(*)
FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
WHERE fgt.id_cliente = @idCliente
      AND NOT EXISTS
(
    SELECT 1
    FROM ADUASIS.dbo.fpedimento AS fped WITH (NOLOCK)
    WHERE NULLIF(RTRIM(fgt.id_referencia), '') IS NOT NULL
          AND fped.id_cliente = fgt.id_cliente
          AND fped.id_referencia = fgt.id_referencia
          AND fped.id_rectificacion = fgt.id_rectificacion
);
SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
INSERT INTO #Tiempos VALUES ('02 volumen traficos SIN pedimento', @ms, @n, 'filtro anterior');

SET @t0 = SYSDATETIME();
SELECT @n = COUNT(*)
FROM ADUASIS.dbo.fpedimento WITH (NOLOCK)
WHERE id_cliente = @idCliente
      AND fecha_pago_banco IS NULL
      AND firma_banco IS NULL
      AND pedimento <> '';
SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
INSERT INTO #Tiempos VALUES ('03 volumen pedimentos abiertos', @ms, @n, NULL);

/* ========== 2) Rama PEDIMENTO + EXISTS partida (busqueda vacia) ========== */
SET @t0 = SYSDATETIME();
SELECT @n = COUNT(*)
FROM ADUASIS.dbo.fpedimento AS fped WITH (NOLOCK)
WHERE fped.fecha_pago_banco IS NULL
      AND fped.firma_banco IS NULL
      AND fped.id_cliente = @idCliente
      AND fped.pedimento <> ''
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
SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
INSERT INTO #Tiempos VALUES ('04 rama PEDIMENTO + EXISTS partida', @ms, @n, 'busqueda vacia');

/* ========== 3) Rama TRAFICO ACTUAL (sin excluir pedimento) ========== */
SET @t0 = SYSDATETIME();
SELECT @n = COUNT(*)
FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
WHERE fgt.id_cliente = @idCliente
      AND EXISTS
(
    SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
    WHERE fdt.id_trafico = fgt.id_trafico AND fdt.id_proveedor = @ValProveedor
)
      AND EXISTS
(
    SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
    WHERE fdt.id_trafico = fgt.id_trafico AND REPLACE(fdt.id_producto, ' ', '') = @ValProducto
)
      AND EXISTS
(
    SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
    WHERE fdt.id_trafico = fgt.id_trafico
          AND (fdt.id_pais_origen LIKE '%' + @ValPais + '%'
               OR fdt.id_pais_vendedor LIKE '%' + @ValPais + '%')
);
SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
INSERT INTO #Tiempos VALUES ('05 rama TRAFICO actual (con ped)', @ms, @n, 'sin NOT EXISTS pedimento');

/* ========== 4) Rama TRAFICO ANTERIOR (solo sin pedimento) ========== */
SET @t0 = SYSDATETIME();
SELECT @n = COUNT(*)
FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
WHERE fgt.id_cliente = @idCliente
      AND NOT EXISTS
(
    SELECT 1
    FROM ADUASIS.dbo.fpedimento AS fped WITH (NOLOCK)
    WHERE NULLIF(RTRIM(fgt.id_referencia), '') IS NOT NULL
          AND fped.id_cliente = fgt.id_cliente
          AND fped.id_referencia = fgt.id_referencia
          AND fped.id_rectificacion = fgt.id_rectificacion
)
      AND EXISTS
(
    SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
    WHERE fdt.id_trafico = fgt.id_trafico AND fdt.id_proveedor = @ValProveedor
)
      AND EXISTS
(
    SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
    WHERE fdt.id_trafico = fgt.id_trafico AND REPLACE(fdt.id_producto, ' ', '') = @ValProducto
)
      AND EXISTS
(
    SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
    WHERE fdt.id_trafico = fgt.id_trafico
          AND (fdt.id_pais_origen LIKE '%' + @ValPais + '%'
               OR fdt.id_pais_vendedor LIKE '%' + @ValPais + '%')
);
SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
INSERT INTO #Tiempos VALUES ('06 rama TRAFICO anterior (sin ped)', @ms, @n, 'con NOT EXISTS pedimento');

/* ========== 5) Candidata: #TrafCliente + EXISTS ========== */
IF OBJECT_ID('tempdb..#TrafCliente') IS NOT NULL DROP TABLE #TrafCliente;
SET @t0 = SYSDATETIME();
SELECT fgt.id_trafico,
       fgt.id_patente,
       fgt.id_aduana,
       fgt.seccion_aduana,
       fgt.cve_tipo_operacion,
       fgt.id_regimen,
       fgt.id_tipo_pedimento
INTO #TrafCliente
FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
WHERE fgt.id_cliente = @idCliente;
CREATE CLUSTERED INDEX IX_TrafCliente ON #TrafCliente (id_trafico);
SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
SELECT @n = COUNT(*) FROM #TrafCliente;
INSERT INTO #Tiempos VALUES ('07 materializar #TrafCliente', @ms, @n, 'prefiltro id_cliente');

SET @t0 = SYSDATETIME();
SELECT @n = COUNT(*)
FROM #TrafCliente AS fgt
WHERE EXISTS
(
    SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
    WHERE fdt.id_trafico = fgt.id_trafico AND fdt.id_proveedor = @ValProveedor
)
      AND EXISTS
(
    SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
    WHERE fdt.id_trafico = fgt.id_trafico AND REPLACE(fdt.id_producto, ' ', '') = @ValProducto
)
      AND EXISTS
(
    SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
    WHERE fdt.id_trafico = fgt.id_trafico
          AND (fdt.id_pais_origen LIKE '%' + @ValPais + '%'
               OR fdt.id_pais_vendedor LIKE '%' + @ValPais + '%')
);
SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
INSERT INTO #Tiempos VALUES ('08 #TrafCliente + EXISTS partida', @ms, @n, 'candidata optimizacion');

/* ========== 6) Trafico con igualdad id_trafico (busqueda) ========== */
SET @t0 = SYSDATETIME();
SELECT @n = COUNT(*)
FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
WHERE fgt.id_cliente = @idCliente
      AND fgt.id_trafico = 'RA48356812'
      AND EXISTS
(
    SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
    WHERE fdt.id_trafico = fgt.id_trafico AND fdt.id_proveedor = @ValProveedor
)
      AND EXISTS
(
    SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
    WHERE fdt.id_trafico = fgt.id_trafico AND REPLACE(fdt.id_producto, ' ', '') = @ValProducto
)
      AND EXISTS
(
    SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
    WHERE fdt.id_trafico = fgt.id_trafico
          AND (fdt.id_pais_origen LIKE '%' + @ValPais + '%'
               OR fdt.id_pais_vendedor LIKE '%' + @ValPais + '%')
);
SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
INSERT INTO #Tiempos VALUES ('09 trafico igualdad id_trafico', @ms, @n, 'busqueda RA48356812');

/* ========== 7) EXEC SP busqueda (referencia) ========== */
IF OBJECT_ID('tempdb..#SpOut') IS NOT NULL DROP TABLE #SpOut;
CREATE TABLE #SpOut
(
    id_referencia VARCHAR(40) NULL,
    id_rectificacion INT NULL,
    patente VARCHAR(40) NULL,
    aduana VARCHAR(40) NULL,
    pedimento VARCHAR(40) NULL,
    tipo_operacion VARCHAR(10) NULL,
    clave_pedimento VARCHAR(20) NULL,
    TotalRecords INT NULL
);
SET @t0 = SYSDATETIME();
BEGIN TRY
    INSERT INTO #SpOut
    EXEC dbo.csp_Ad_SugerenciaPedimentos_v2
        @idCliente = '9174',
        @idAdDocumento = 35081,
        @operacionBusqueda = 'RA48356812',
        @PageNumber = 1,
        @PageSize = 10;
    SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
    SELECT @n = ISNULL(MAX(TotalRecords), 0) FROM #SpOut;
    INSERT INTO #Tiempos VALUES ('10 EXEC SP busqueda RA48356812', @ms, @n, 'SP completo');
END TRY
BEGIN CATCH
    SET @ms = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
    INSERT INTO #Tiempos VALUES ('10 EXEC SP busqueda RA48356812', @ms, NULL, LEFT(ERROR_MESSAGE(), 200));
END CATCH;

SELECT paso, elapsed_ms, filas, nota
FROM #Tiempos
ORDER BY paso;

PRINT 'Nota: EXEC SP filtro vacio omitido (timeout 30 min en prueba previa).';
GO
