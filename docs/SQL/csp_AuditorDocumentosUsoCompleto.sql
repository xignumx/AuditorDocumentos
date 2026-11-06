USE ADUASIS;
GO

-- csp_AuditorDocumentosUsoCompleto '2026-04-01', '2026-05-06'
CREATE OR ALTER PROCEDURE csp_AuditorDocumentosUsoCompleto
    --DECLARE
    @fechaDesde DATE = '2026-05-01',
    @fechaHasta DATE = '2026-06-19'
AS
BEGIN
    DECLARE @referencias TABLE
    (
        referencia VARCHAR(16) NOT NULL,
        id_referencia VARCHAR(10) NULL,
        id_rectificacion DECIMAL(1, 0) NULL,
        operacion VARCHAR(20) NOT NULL
    );

    INSERT INTO @referencias
    (
        referencia,
        id_referencia,
        id_rectificacion,
        operacion
    )
    SELECT DISTINCT
           CONCAT(fped.id_referencia, '_', fped.id_rectificacion) referencia,
           fped.id_referencia,
           fped.id_rectificacion,
           'PEDIMENTO' operacion
    FROM ADUASIS.dbo.fpedimento fped WITH (NOLOCK)
        INNER JOIN ADUASIS.dbo.fpedimento_caso cas WITH (NOLOCK)
            ON cas.id_referencia = fped.id_referencia
               AND cas.id_rectificacion = fped.id_rectificacion
               AND cas.tipo_caso = 'ED'
    WHERE fped.firma_shcp IS NOT NULL
          AND CAST(fped.fecha_pago AS DATE)
          BETWEEN @fechaDesde AND @fechaHasta;

    INSERT INTO @referencias
    (
        referencia,
        operacion
    )
    SELECT fgt.id_trafico referencia,
           'TRAFICO' operacion
    FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
        INNER JOIN @referencias ref
            ON ref.id_referencia = fgt.id_referencia;

    SELECT DISTINCT
           fped.id_referencia,
           fped.id_rectificacion,
           fped.id_cliente,
           fped.razon_social_cliente,
           fped.fecha_pago,
           d.FechaCreacion,
           d.CreadoPor,
           ISNULL(d.IdTipoDocumentoVucem, doc.Id_DocumentoVucem) IdTipoDocumentoVucem,
           ISNULL(v.PrefijoEI, doc.PrefijoEI) PrefijoEI,
           ISNULL(v.Id_Vucem, doc.Id_DocumentoVucem) Id_Vucem,
           ISNULL(v.Documento, doc.Documento) DocumentoVucem,
           ISNULL(a.NombreArchivo, env.Edocument) NombreArchivoEdoc,
           CASE
               WHEN hd.IdClasificacion = 1 THEN
                   'Identificador general'
               WHEN hd.IdClasificacion = 2 THEN
                   'Identificador partida'
               WHEN hd.IdClasificacion = 3 THEN
                   'Identificador permiso'
           END Clasificacion,
           CASE
               WHEN d.IdEstatus = 1 THEN
                   'Registro'
               WHEN d.IdEstatus = 2 THEN
                   'Pendiente'
               WHEN d.IdEstatus = 3 THEN
                   'Aprobado'
               WHEN d.IdEstatus = 4 THEN
                   'Rechazado'
               WHEN d.IdEstatus = 5 THEN
                   'Vinculado a operación'
               WHEN d.IdEstatus = 6 THEN
                   'Digitalizado Edocs'
               WHEN d.IdEstatus = 7 THEN
                   'Error de digitalización'
               WHEN d.IdEstatus = 8 THEN
                   'Eliminado'
           END Estatus,
           d.ComentarioRechazo,
           CASE
               WHEN d.Id IS NULL THEN
                   'No'
               ELSE
                   'Si'
           END Auditado,
           campos.TipoPedimento,
           campos.TipoOperacion,
           campos.ClavePedimento,
           campos.Proveedor,
           campos.ProductoNoDeParte,
           campos.DescripcionMercancia,
           campos.Fracciones,
           campos.Nico,
           campos.Cantidad,
           campos.UnidadMedidaUMT,
           campos.PaisOrigenDestino,
           campos.VigenciaDesde,
           campos.VigenciaHasta,
           campos.Aduana,
           campos.FirmaDeRL,
           campos.Nom,
           campos.ValorComercial,
           dbo.fn_WeekFriThu(fped.fecha_pago) Semana,
           YEAR(fped.fecha_pago) Anio,
           MONTH(fped.fecha_pago) Mes
    FROM @referencias ref
        INNER JOIN ADUASIS.dbo.fpedimento fped WITH (NOLOCK)
            ON fped.id_referencia = ref.id_referencia
               AND fped.id_rectificacion = ref.id_rectificacion
        INNER JOIN EDOCS.dbo.Tb_Archivos arc WITH (NOLOCK)
            ON arc.Referencia = ref.referencia
        INNER JOIN EDOCS.dbo.Tb_Archivos_Relacion_DocumentoVucem rel WITH (NOLOCK)
            ON rel.Id_Archivo = arc.Id_Archivo
        INNER JOIN EDOCS.dbo.Tb_DocumentosVucem doc WITH (NOLOCK)
            ON doc.Id_DocumentoVucem = rel.Id_DocumentoVucem
        INNER JOIN DesarrolloDB.dbo.ad_motor_config_header hd WITH (NOLOCK)
            ON hd.IdTipoDocumentoVucem = rel.Id_DocumentoVucem
               AND hd.IdCliente = fped.id_cliente
        INNER JOIN EDOCS.dbo.Tb_Envios env WITH (NOLOCK)
            ON env.Id_Archivo = arc.Id_Archivo
        LEFT JOIN DesarrolloDB.dbo.ad_documento_operacion op WITH (NOLOCK)
            ON op.id_referencia = fped.id_referencia
               AND op.id_rectificacion = fped.id_rectificacion
        LEFT JOIN DesarrolloDB.dbo.ad_documentos d WITH (NOLOCK)
            ON d.Id = op.IdDocumento
               AND d.IdEstatus <> 8
               AND d.IdCliente = fped.id_cliente
               AND d.IdMotorConfigHeader = hd.Id
        LEFT JOIN DesarrolloDB.dbo.ad_documentos_archivos a WITH (NOLOCK)
            ON a.IdDocumento = d.Id
        LEFT JOIN EDOCS.dbo.Tb_DocumentosVucem v WITH (NOLOCK)
            ON v.Id_DocumentoVucem = d.IdTipoDocumentoVucem
        LEFT JOIN ADUASIS.dbo.FCLIENTE c WITH (NOLOCK)
            ON c.ID_CLIENTE = d.IdCliente
        LEFT JOIN
        (
            SELECT dc.IdDocumento,
                   MAX(CASE WHEN dc.IdCampo = 3 THEN dc.Valor END) TipoPedimento,
                   MAX(CASE WHEN dc.IdCampo = 4 THEN dc.Valor END) TipoOperacion,
                   MAX(CASE WHEN dc.IdCampo = 5 THEN dc.Valor END) ClavePedimento,
                   MAX(CASE WHEN dc.IdCampo = 6 THEN dc.Valor END) Proveedor,
                   MAX(CASE WHEN dc.IdCampo = 7 THEN dc.Valor END) ProductoNoDeParte,
                   MAX(CASE WHEN dc.IdCampo = 8 THEN dc.Valor END) DescripcionMercancia,
                   MAX(CASE WHEN dc.IdCampo = 9 THEN dc.Valor END) Fracciones,
                   MAX(CASE WHEN dc.IdCampo = 10 THEN dc.Valor END) Nico,
                   MAX(CASE WHEN dc.IdCampo = 11 THEN dc.Valor END) Cantidad,
                   MAX(CASE WHEN dc.IdCampo = 12 THEN dc.Valor END) UnidadMedidaUMT,
                   MAX(CASE WHEN dc.IdCampo = 13 THEN dc.Valor END) PaisOrigenDestino,
                   MAX(CASE WHEN dc.IdCampo = 14 THEN dc.Valor END) VigenciaDesde,
                   MAX(CASE WHEN dc.IdCampo = 15 THEN dc.Valor END) VigenciaHasta,
                   MAX(CASE WHEN dc.IdCampo = 16 THEN dc.Valor END) Aduana,
                   MAX(CASE WHEN dc.IdCampo = 17 THEN dc.Valor END) FirmaDeRL,
                   MAX(CASE WHEN dc.IdCampo = 18 THEN dc.Valor END) Nom,
                   MAX(CASE WHEN dc.IdCampo = 19 THEN dc.Valor END) ValorComercial
            FROM DesarrolloDB.dbo.ad_documentos_campos dc WITH (NOLOCK)
            WHERE dc.IdCampo BETWEEN 3 AND 19
            GROUP BY dc.IdDocumento
        ) campos
            ON campos.IdDocumento = d.Id
    ORDER BY fped.fecha_pago;
END;
