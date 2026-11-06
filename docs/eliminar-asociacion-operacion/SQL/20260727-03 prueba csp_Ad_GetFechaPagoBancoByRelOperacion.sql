USE DesarrolloDB
GO

-- Resultado: una fila con FechaPagoBanco (DATE/DATETIME nullable) o cero filas.

DECLARE @idReferencia VARCHAR(10) = 'XXXXXXXX'; -- cambiar
DECLARE @idRectificacion DECIMAL(1, 0) = NULL;  -- o 0, 1, ...

EXEC dbo.csp_Ad_GetFechaPagoBancoByRelOperacion
    @idReferencia = @idReferencia,
    @idRectificacion = @idRectificacion;
GO
