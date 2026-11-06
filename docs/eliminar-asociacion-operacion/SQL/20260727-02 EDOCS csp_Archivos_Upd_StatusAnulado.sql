USE EDOCS
GO

-- Baja lógica de archivo eDOCS: Status = 0 (bit).
-- Columna confirmada: Tb_Archivos.Status
-- Usado por EliminarAsociacionOperacion.

CREATE PROCEDURE dbo.csp_Archivos_Upd_StatusAnulado
    @Id_Archivo INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @Id_Archivo IS NULL OR @Id_Archivo <= 0
    BEGIN
        RAISERROR(N'Id_Archivo inválido.', 16, 1);
        RETURN;
    END

    UPDATE dbo.Tb_Archivos
    SET Status = 0
    WHERE Id_Archivo = @Id_Archivo;
END
GO
