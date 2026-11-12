/*
  EPIC 4 / TK-7006 — SP NUEVO (no altera csp_Ad_DocumentosPorEstatus).
  Listado por estatus + folio Invoice/Factura/Permiso (campos 20/24 y permiso).
  Base: DesarrolloDB
*/
USE DesarrolloDB;
GO

CREATE OR ALTER PROCEDURE dbo.csp_Ad_DocumentosPorEstatusConFolio
    @idCliente varchar(6),
    @idEstatus int = 0
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        d.Id,
        d.IdCliente,
        d.FechaCreacion,
        d.CreadoPor,
        d.IdTipoDocumentoVucem,
        v.PrefijoEI,
        v.Id_Vucem,
        v.Documento AS DocumentoVucem,
        a.NombreArchivo,
        a.AwsRuta,
        d.FechaVigenciaInicio,
        d.FechaVigenciaFin,
        m.IdClasificacion,
        CASE
            WHEN m.IdClasificacion = 1 THEN 'Identificador general'
            WHEN m.IdClasificacion = 2 THEN 'Identificador partida'
            WHEN m.IdClasificacion = 3 THEN 'Identificador permiso'
        END AS Clasificacion,
        d.IdEstatus,
        CASE
            WHEN d.IdEstatus = 1 THEN 'Registro'
            WHEN d.IdEstatus = 2 THEN 'Pendiente'
            WHEN d.IdEstatus = 3 THEN 'Aprobado'
            WHEN d.IdEstatus = 4 THEN 'Rechazado'
            WHEN d.IdEstatus = 5 THEN 'Vinculado a operación'
            WHEN d.IdEstatus = 6 THEN 'Digitalizado Edocs'
            WHEN d.IdEstatus = 7 THEN 'Error de digitalización'
            WHEN d.IdEstatus = 8 THEN 'Eliminado'
        END AS Estatus,
        d.ComentarioRechazo,
        COALESCE(
            NULLIF(LTRIM(RTRIM(fcFactura.Valor)), ''),
            NULLIF(LTRIM(RTRIM(perm.Numero)), ''),
            NULLIF(LTRIM(RTRIM(perm.Permiso)), ''),
            NULLIF(LTRIM(RTRIM(fcPedimento.Valor)), '')
        ) AS NumeroFacturaInvoicePermiso
    FROM DesarrolloDB.dbo.ad_documentos d WITH (NOLOCK)
    INNER JOIN DesarrolloDB.dbo.ad_motor_config_header m WITH (NOLOCK)
        ON m.Id = d.IdMotorConfigHeader
    INNER JOIN DesarrolloDB.dbo.ad_documentos_archivos a WITH (NOLOCK)
        ON a.IdDocumento = d.Id
    INNER JOIN EDOCS.dbo.Tb_DocumentosVucem v WITH (NOLOCK)
        ON v.Id_DocumentoVucem = d.IdTipoDocumentoVucem
    LEFT JOIN DesarrolloDB.dbo.ad_documentos_campos fcFactura WITH (NOLOCK)
        ON fcFactura.IdDocumento = d.Id AND fcFactura.IdCampo = 20
    LEFT JOIN DesarrolloDB.dbo.ad_documentos_campos fcPedimento WITH (NOLOCK)
        ON fcPedimento.IdDocumento = d.Id AND fcPedimento.IdCampo = 24
    LEFT JOIN DesarrolloDB.dbo.ad_documentos_permiso perm WITH (NOLOCK)
        ON perm.IdDocumento = d.Id
    WHERE
        (d.FechaVigenciaFin IS NULL OR CAST(d.FechaVigenciaFin AS date) >= CAST(GETDATE() AS date))
        AND (@idEstatus = 0 OR d.IdEstatus = @idEstatus)
        AND d.IdEstatus NOT IN (0, 8)
        AND d.IdCliente = @idCliente;
END
GO
