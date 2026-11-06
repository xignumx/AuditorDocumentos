/*
  Baseline — csp_Ad_SugerenciaPedimentos_v2 (sin modificar el SP)
  Parámetros fijos: idCliente=9174, idAdDocumento=35081, Page=1, Size=10
  Casos: A) operacionBusqueda=''  B) operacionBusqueda='RA48356812'
*/
USE ADUASIS;
GO

SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#ResVacio') IS NOT NULL DROP TABLE #ResVacio;
IF OBJECT_ID('tempdb..#ResBusq') IS NOT NULL DROP TABLE #ResBusq;

CREATE TABLE #ResVacio
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

CREATE TABLE #ResBusq
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

DECLARE @t0 DATETIME2;
DECLARE @elapsedVacio INT = NULL;
DECLARE @elapsedBusq INT = NULL;
DECLARE @errVacio NVARCHAR(4000) = NULL;
DECLARE @errBusq NVARCHAR(4000) = NULL;
DECLARE @rowsVacio INT = 0;
DECLARE @rowsBusq INT = 0;
DECLARE @totalVacio INT = 0;
DECLARE @totalBusq INT = 0;

PRINT '=== A) operacionBusqueda vacia ===';
BEGIN TRY
    SET @t0 = SYSDATETIME();
    INSERT INTO #ResVacio
    EXEC dbo.csp_Ad_SugerenciaPedimentos_v2
        @idCliente = '9174',
        @idAdDocumento = 35081,
        @operacionBusqueda = '',
        @PageNumber = 1,
        @PageSize = 10;
    SET @elapsedVacio = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
    SELECT @rowsVacio = COUNT(*), @totalVacio = ISNULL(MAX(TotalRecords), 0) FROM #ResVacio;
    PRINT CONCAT('OK VACIO ms=', @elapsedVacio, ' rows=', @rowsVacio, ' total=', @totalVacio);
END TRY
BEGIN CATCH
    SET @elapsedVacio = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
    SET @errVacio = ERROR_MESSAGE();
    PRINT CONCAT('ERROR VACIO ms=', @elapsedVacio, ' msg=', @errVacio);
END CATCH;

PRINT '=== B) operacionBusqueda RA48356812 ===';
BEGIN TRY
    SET @t0 = SYSDATETIME();
    INSERT INTO #ResBusq
    EXEC dbo.csp_Ad_SugerenciaPedimentos_v2
        @idCliente = '9174',
        @idAdDocumento = 35081,
        @operacionBusqueda = 'RA48356812',
        @PageNumber = 1,
        @PageSize = 10;
    SET @elapsedBusq = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
    SELECT @rowsBusq = COUNT(*), @totalBusq = ISNULL(MAX(TotalRecords), 0) FROM #ResBusq;
    PRINT CONCAT('OK BUSQ ms=', @elapsedBusq, ' rows=', @rowsBusq, ' total=', @totalBusq);
END TRY
BEGIN CATCH
    SET @elapsedBusq = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
    SET @errBusq = ERROR_MESSAGE();
    PRINT CONCAT('ERROR BUSQ ms=', @elapsedBusq, ' msg=', @errBusq);
END CATCH;

SELECT 'RESUMEN' AS seccion,
       @elapsedVacio AS ms_vacio,
       @errVacio AS error_vacio,
       @rowsVacio AS rows_vacio,
       @totalVacio AS total_vacio,
       @elapsedBusq AS ms_busq,
       @errBusq AS error_busq,
       @rowsBusq AS rows_busq,
       @totalBusq AS total_busq;

SELECT 'VACIO' AS caso,
       id_referencia,
       id_rectificacion,
       patente,
       aduana,
       pedimento,
       tipo_operacion,
       clave_pedimento,
       TotalRecords
FROM #ResVacio
ORDER BY pedimento, id_referencia;

SELECT 'BUSQ' AS caso,
       id_referencia,
       id_rectificacion,
       patente,
       aduana,
       pedimento,
       tipo_operacion,
       clave_pedimento,
       TotalRecords
FROM #ResBusq
ORDER BY pedimento, id_referencia;
GO
