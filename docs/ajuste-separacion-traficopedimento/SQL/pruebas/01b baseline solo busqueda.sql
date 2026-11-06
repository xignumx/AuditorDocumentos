/*
  Baseline B — operacionBusqueda='RA48356812'
  idCliente=9174, idAdDocumento=35081, Page=1, Size=10
  Sin modificar el SP.
*/
USE ADUASIS;
GO
SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#ResBusq') IS NOT NULL DROP TABLE #ResBusq;
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

DECLARE @t0 DATETIME2 = SYSDATETIME();
DECLARE @elapsed INT;
DECLARE @rows INT = 0;
DECLARE @total INT = 0;

BEGIN TRY
    INSERT INTO #ResBusq
    EXEC dbo.csp_Ad_SugerenciaPedimentos_v2
        @idCliente = '9174',
        @idAdDocumento = 35081,
        @operacionBusqueda = 'RA48356812',
        @PageNumber = 1,
        @PageSize = 10;
    SET @elapsed = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
    SELECT @rows = COUNT(*), @total = ISNULL(MAX(TotalRecords), 0) FROM #ResBusq;
    SELECT 'OK' AS status, @elapsed AS elapsed_ms, @rows AS rows_page, @total AS total_records;
    SELECT * FROM #ResBusq ORDER BY pedimento, id_referencia;
END TRY
BEGIN CATCH
    SET @elapsed = DATEDIFF(MILLISECOND, @t0, SYSDATETIME());
    SELECT 'ERROR' AS status, @elapsed AS elapsed_ms, ERROR_NUMBER() AS err_no, ERROR_MESSAGE() AS err_msg;
END CATCH;
GO
