USE ADUASIS;
GO

-- 1240
CREATE PROCEDURE csp_AdIndicadorUsoPorEquipo
    --DECLARE
    @fechaDesde DATE = '2026-04-01',
    @fechaHasta DATE = '2026-05-14'
AS
BEGIN
    SELECT DISTINCT
           grel.GrupoNombre Equipo,
           fped.id_referencia,
           fped.id_rectificacion,
           ISNULL(d.IdTipoDocumentoVucem, doc.Id_DocumentoVucem) IdTipoDocumentoVucem,
           ISNULL(v.PrefijoEI, doc.PrefijoEI) PrefijoEI,
           ISNULL(v.Id_Vucem, doc.Id_DocumentoVucem) Id_Vucem,
           ISNULL(v.Documento, doc.Documento) DocumentoVucem,
           ISNULL(a.NombreArchivo, env.Edocument) NombreArchivoEdoc,
           a.AwsRuta,
           CASE
               WHEN d.Id IS NULL THEN
                   'No'
               ELSE
                   'Si'
           END Auditado,
           dbo.fn_WeekFriThu(fped.fecha_pago) Semana,
           YEAR(fped.fecha_pago) Anio,
           MONTH(fped.fecha_pago) Mes
    INTO #tmp
    FROM ADUASIS.dbo.fpedimento fped WITH (NOLOCK)
        INNER JOIN EquiposAutodirigidos.dbo.VW_RelClienteEquipo grel
            ON grel.ClienteId = fped.id_cliente
        INNER JOIN ADUASIS.dbo.fpedimento_caso cas WITH (NOLOCK)
            ON cas.id_referencia = fped.id_referencia
               AND cas.id_rectificacion = fped.id_rectificacion
               AND cas.tipo_caso = 'ED'
        INNER JOIN ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
            ON fgt.id_referencia = fped.id_referencia
               AND fgt.id_rectificacion = fped.id_rectificacion
        INNER JOIN EDOCS.dbo.Tb_Archivos arc WITH (NOLOCK)
            ON arc.Referencia IN ( CONCAT(fped.id_referencia, '_', fped.id_rectificacion), fgt.id_trafico )
        INNER JOIN EDOCS.dbo.Tb_Archivos_Relacion_DocumentoVucem rel WITH (NOLOCK)
            ON rel.Id_Archivo = arc.Id_Archivo
        INNER JOIN EDOCS.dbo.Tb_DocumentosVucem doc WITH (NOLOCK)
            ON doc.Id_DocumentoVucem = rel.Id_DocumentoVucem
        INNER JOIN EDOCS.dbo.Tb_Envios env WITH (NOLOCK)
            ON env.Id_Archivo = arc.Id_Archivo
               AND env.Edocument = cas.iden_caso
        LEFT JOIN DesarrolloDB.dbo.ad_documento_operacion op WITH (NOLOCK)
            ON op.id_referencia = fped.id_referencia
               AND op.id_rectificacion = fped.id_rectificacion
        LEFT JOIN DesarrolloDB.dbo.ad_documentos d WITH (NOLOCK)
            ON d.Id = op.IdDocumento
               AND d.IdEstatus <> 8
        LEFT JOIN DesarrolloDB.dbo.ad_motor_config_header m WITH (NOLOCK)
            ON m.Id = d.IdMotorConfigHeader
        LEFT JOIN DesarrolloDB.dbo.ad_documentos_archivos a WITH (NOLOCK)
            ON a.IdDocumento = d.Id
        LEFT JOIN EDOCS.dbo.Tb_DocumentosVucem v WITH (NOLOCK)
            ON v.Id_DocumentoVucem = d.IdTipoDocumentoVucem
        LEFT JOIN ADUASIS.dbo.FCLIENTE c WITH (NOLOCK)
            ON c.ID_CLIENTE = d.IdCliente
    WHERE (
              (
                  fped.firma_shcp IS NOT NULL
                  AND CAST(fped.fecha_pago AS DATE)
          BETWEEN @fechaDesde AND @fechaHasta
              )
              OR a.Id IS NOT NULL
          );

    SELECT Equipo,
           COUNT(DISTINCT CONCAT(id_referencia, '/', id_rectificacion)) TotalOperaciones,
           COUNT(NombreArchivoEdoc) TotalDocumentosEdocs,
           SUM(   CASE
                      WHEN AwsRuta IS NULL THEN
                          0
                      ELSE
                          1
                  END
              ) TotalDocumentosAuditados
    INTO #result
    FROM #tmp
    GROUP BY Equipo;


    SELECT Equipo,
           TotalOperaciones,
           TotalDocumentosEdocs - TotalDocumentosAuditados TotalDocumentosNoAuditados,
           TotalDocumentosAuditados,
           TotalDocumentosEdocs,
           CAST((CAST(TotalDocumentosAuditados AS DECIMAL) / CAST(TotalDocumentosEdocs AS DECIMAL)) AS NUMERIC(4, 3))
           * 100 PorcentajeUso
    FROM #result;


    DROP TABLE #tmp;
    DROP TABLE #result;
END;