USE ADUASIS
GO

CREATE PROCEDURE csp_ReporteEstatusDigitalizacionDocumentos
    --DECLARE 
    @Fecha DATE = '2026-10-02'
AS BEGIN 
    SELECT
        CASE
            WHEN CHARINDEX('_', ar.Referencia) > 0
                 AND TRY_CONVERT(INT, RIGHT(ar.Referencia, CHARINDEX('_', REVERSE(ar.Referencia)) - 1)) IS NOT NULL
                THEN LEFT(ar.Referencia, LEN(ar.Referencia) - CHARINDEX('_', REVERSE(ar.Referencia)))
            ELSE ar.Referencia
        END                                              AS IdReferencia,
        CASE
            WHEN CHARINDEX('_', ar.Referencia) > 0
                THEN TRY_CONVERT(DECIMAL(18, 0), RIGHT(ar.Referencia, CHARINDEX('_', REVERSE(ar.Referencia)) - 1))
            ELSE NULL
        END                                              AS IdRectificacion,
        d.IdCliente                                      AS IdCliente,
        cli.RAZON_SOCIAL                                 AS RazonSocialCliente,
        vuc.Documento                                    AS Documento,
        arch.NombreArchivo                               AS NombreArchivo,
        en.Numero                                        AS Numero,
        en.Edocument                                     AS Edocumento,
        d.FechaCreacion                                  AS FechaAltaDocumento,
        en.Fecha_Envio                                   AS FechaEnvio,
        en.Fecha_Recepcion                               AS FechaRecepcion,
        ar.Fecha_Registro                                AS FechaRegistroArchivo,
        job.IntentosRealizados                           AS Intentos,
        DATEADD(HOUR, -6, job.FechaUltimoIntento)        AS FechaUltimaRespuestaVucem,
        CASE
            WHEN NULLIF(LTRIM(RTRIM(en.Edocument)), '') IS NOT NULL
                 AND LTRIM(RTRIM(en.Edocument)) <> '0000000000000'
                 AND job.FechaUltimoIntento IS NOT NULL
                 AND en.Fecha_Envio IS NOT NULL
                THEN DATEDIFF(MINUTE, en.Fecha_Envio, DATEADD(HOUR, -6, job.FechaUltimoIntento))
            ELSE NULL
        END                                              AS MinutosRegistroARespuesta,
        en.Mensaje                                       AS UltimoMensaje,
        CASE
            WHEN job.IntentosRealizados IS NULL THEN 'Edocs'
            ELSE 'Auditor Documentos'
        END                                              AS ProcesadoDesde
    FROM EDOCS.dbo.Tb_Envios AS en WITH (NOLOCK)
    INNER JOIN DesarrolloDB.dbo.ad_rel_documento_edoc AS rel WITH (NOLOCK)
        ON rel.Id_Archivo = en.Id_Archivo
    INNER JOIN EDOCS.dbo.Tb_Archivos AS ar WITH (NOLOCK)
        ON ar.Id_Archivo = en.Id_Archivo
    INNER JOIN DesarrolloDB.dbo.ad_documentos AS d WITH (NOLOCK)
        ON d.Id = rel.IdDocumento
    LEFT JOIN DesarrolloDB.dbo.ad_documentos_archivos AS arch WITH (NOLOCK)
        ON arch.IdDocumento = d.Id
    LEFT JOIN ADUASIS.dbo.fcliente AS cli WITH (NOLOCK)
        ON cli.ID_CLIENTE = d.IdCliente
    LEFT JOIN EDOCS.dbo.Tb_DocumentosVucem AS vuc WITH (NOLOCK)
        ON vuc.Id_DocumentoVucem = d.IdTipoDocumentoVucem
    LEFT JOIN EDOCS.dbo.Tb_Envio_ConsultaJob AS job WITH (NOLOCK)
        ON job.Id_Envio = en.Id_Envio
    WHERE en.Fecha_Envio >= CAST(@Fecha AS DATETIME)
      AND en.Fecha_Envio <  DATEADD(DAY, 1, CAST(@Fecha AS DATETIME))
    ORDER BY en.Fecha_Envio DESC;
END 