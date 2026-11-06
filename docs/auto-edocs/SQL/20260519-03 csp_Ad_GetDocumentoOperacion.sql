USE DesarrolloDB;
GO

CREATE PROCEDURE csp_Ad_GetDocumentoOperacion 
    @idDocumento INT = 51
AS
BEGIN
    SELECT op.IdDocumento,
           op.id_referencia,
           op.id_rectificacion,
           op.pedimento,
           en.Edocument,
           en.Numero,
           en.Mensaje
    FROM DesarrolloDB.dbo.ad_documento_operacion op WITH (NOLOCK)
        OUTER APPLY
        (
            SELECT TOP (1)
                   ed.Id_Archivo
            FROM DesarrolloDB.dbo.ad_rel_documento_edoc ed WITH (NOLOCK)
                INNER JOIN EDOCS.dbo.Tb_Archivos ar WITH (NOLOCK)
                    ON ar.Id_Archivo = ed.Id_Archivo
                       AND ar.Referencia = CASE
                                               WHEN op.id_rectificacion IS NOT NULL THEN
                                                   CONCAT(op.id_referencia, '_', op.id_rectificacion)
                                               ELSE
                                                   op.id_referencia
                                           END
            WHERE ed.IdDocumento = op.IdDocumento
            ORDER BY ed.Id DESC
        ) rel
        LEFT JOIN EDOCS.dbo.Tb_Envios en WITH (NOLOCK)
            ON en.Id_Archivo = rel.Id_Archivo
    WHERE op.IdDocumento = @idDocumento;
END;
