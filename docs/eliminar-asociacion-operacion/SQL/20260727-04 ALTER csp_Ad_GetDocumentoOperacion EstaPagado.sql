USE DesarrolloDB;
GO

/*
  ALTER de csp_Ad_GetDocumentoOperacion
  - Agrega EstaPagado (INT 0/1) según ADUASIS.dbo.fpedimento.fecha_pago_banco
  - INT (no BIT) para mapeo fiable con EF Core FromSqlRaw
  - Misma regla que csp_Ad_GetFechaPagoBancoByRelOperacion
  - Ejecutar manualmente en el ambiente (no desplegado por el agente)
*/

CREATE OR ALTER PROCEDURE dbo.csp_Ad_GetDocumentoOperacion
    @idDocumento INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT op.IdDocumento,
           op.id_referencia,
           op.id_rectificacion,
           op.pedimento,
           en.Edocument,
           en.Numero,
           en.Mensaje,
           CAST(CASE
                    WHEN pago.fecha_pago_banco IS NOT NULL THEN
                        1
                    ELSE
                        0
                END AS BIT) AS EstaPagado
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
        OUTER APPLY
        (
            SELECT TOP (1)
                   x.fecha_pago_banco
            FROM
            (
                -- Con rectificación: pedimento exacto
                SELECT fped.fecha_pago_banco
                FROM ADUASIS.dbo.fpedimento AS fped WITH (NOLOCK)
                WHERE op.id_rectificacion IS NOT NULL
                  AND fped.id_referencia = op.id_referencia
                  AND fped.id_rectificacion = op.id_rectificacion

                UNION ALL

                -- Sin rectificación (tráfico): primer pedimento de la referencia
                SELECT fped.fecha_pago_banco
                FROM ADUASIS.dbo.fpedimento AS fped WITH (NOLOCK)
                WHERE op.id_rectificacion IS NULL
                  AND fped.id_referencia = op.id_referencia
            ) AS x
            ORDER BY x.fecha_pago_banco DESC
        ) pago
    WHERE op.IdDocumento = @idDocumento;
END;
GO
