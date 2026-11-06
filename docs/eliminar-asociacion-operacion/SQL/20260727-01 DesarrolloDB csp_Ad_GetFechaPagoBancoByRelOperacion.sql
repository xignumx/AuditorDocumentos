USE DesarrolloDB
GO

-- Fecha de pago en banco por referencia/rectificación (ADUASIS.fpedimento).
-- Usado por EliminarAsociacionOperacion para bloquear si el pedimento está pagado.
-- Si no hay fila, la API interpreta "no pagado" (permite eliminar).

CREATE PROCEDURE dbo.csp_Ad_GetFechaPagoBancoByRelOperacion
    @idReferencia VARCHAR(10),
    @idRectificacion DECIMAL(1, 0) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @idRectificacion IS NOT NULL
    BEGIN
        SELECT TOP (1)
               fped.fecha_pago_banco AS FechaPagoBanco
        FROM ADUASIS.dbo.fpedimento AS fped WITH (NOLOCK)
        WHERE fped.id_referencia = @idReferencia
          AND fped.id_rectificacion = @idRectificacion;
    END
    ELSE
    BEGIN
        -- Asociación a tráfico (sin rectificación): si existe algún pedimento
        -- con esa referencia, toma el de menor rectificación.
        SELECT TOP (1)
               fped.fecha_pago_banco AS FechaPagoBanco
        FROM ADUASIS.dbo.fpedimento AS fped WITH (NOLOCK)
        WHERE fped.id_referencia = @idReferencia
        ORDER BY fped.id_rectificacion;
    END
END
GO
