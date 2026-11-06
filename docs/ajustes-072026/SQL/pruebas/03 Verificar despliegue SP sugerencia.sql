/*
  Prueba — Verificar despliegue csp_Ad_SugerenciaPedimentos_v2
  Ejecutar en ADUASIS después de aplicar scripts en SQL/implementacion/ (04 y 05).

  Ajustar @idCliente y @idAdDocumento para la prueba EXEC.
*/
USE ADUASIS;
GO

DECLARE @idCliente VARCHAR(10) = '9375';
DECLARE @idAdDocumento BIGINT = 548;

PRINT '--- Verificación post-despliegue ---';

IF OBJECT_ID('dbo.FN_Ad_NormalizarTipoOperacion', 'FN') IS NULL
    RAISERROR('FALTA: FN_Ad_NormalizarTipoOperacion. Ejecute implementacion/04.', 16, 1);
ELSE
    PRINT 'OK: FN_Ad_NormalizarTipoOperacion.';

IF OBJECT_ID('dbo.csp_Ad_SugerenciaPedimentos_v2', 'P') IS NULL
    RAISERROR('FALTA: csp_Ad_SugerenciaPedimentos_v2. Ejecute implementacion/05.', 16, 1);

DECLARE @def NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.csp_Ad_SugerenciaPedimentos_v2'));

IF @def NOT LIKE '%#Candidatos%'
    RAISERROR('SP sin #Candidatos. Redesplegar implementacion/05.', 16, 1);

IF @def LIKE '%OFFSET @Offset%'
    RAISERROR('SP desactualizado (OFFSET). Redesplegar implementacion/05.', 16, 1);

IF @def NOT LIKE '%ROW_NUMBER()%'
    RAISERROR('SP sin ROW_NUMBER. Revise implementacion/05.', 16, 1);

PRINT 'OK: definición del SP validada.';

EXEC dbo.csp_Ad_SugerenciaPedimentos_v2
    @idCliente = @idCliente,
    @idAdDocumento = @idAdDocumento,
    @operacionBusqueda = '',
    @PageNumber = 1,
    @PageSize = 10;

PRINT 'OK: EXEC de prueba completado.';
GO
