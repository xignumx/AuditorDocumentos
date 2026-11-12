/*
  EPIC 1 ID_02 / TK-7006 — objetos NUEVOS para transmisión VUCEM en lote.
  No altera stores legacy.
*/
USE DesarrolloDB;
GO

IF OBJECT_ID('dbo.ad_lote_vucem', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ad_lote_vucem
    (
        Id                BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        IdCliente         VARCHAR(6) NOT NULL,
        Referencia        NVARCHAR(50) NOT NULL,
        OrigenSello       NVARCHAR(30) NOT NULL,
        CorreoElectronico NVARCHAR(200) NULL,
        CreadoPor         NVARCHAR(100) NOT NULL,
        EstatusLote       INT NOT NULL CONSTRAINT DF_ad_lote_vucem_Est DEFAULT (0),
        TotalItems        INT NOT NULL CONSTRAINT DF_ad_lote_vucem_Tot DEFAULT (0),
        TamanoBloque      INT NOT NULL CONSTRAINT DF_ad_lote_vucem_Blk DEFAULT (5),
        FechaCreacion     DATETIME2 NOT NULL CONSTRAINT DF_ad_lote_vucem_Fc DEFAULT (SYSUTCDATETIME()),
        FechaActualizacion DATETIME2 NULL
    );
END
GO

IF OBJECT_ID('dbo.ad_lote_vucem_detalle', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ad_lote_vucem_detalle
    (
        Id               BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        IdLote           BIGINT NOT NULL,
        IdDocumento      BIGINT NOT NULL,
        IdReferencia     NVARCHAR(50) NOT NULL,
        IdRectificacion  DECIMAL(18,0) NULL,
        EstatusItem      INT NOT NULL CONSTRAINT DF_ad_lote_vucem_det_Est DEFAULT (0),
        Intentos         INT NOT NULL CONSTRAINT DF_ad_lote_vucem_det_Int DEFAULT (0),
        Mensaje          NVARCHAR(2000) NULL,
        NumeroOperacion  NVARCHAR(100) NULL,
        RespuestaJson    NVARCHAR(MAX) NULL,
        FechaCreacion    DATETIME2 NOT NULL CONSTRAINT DF_ad_lote_vucem_det_Fc DEFAULT (SYSUTCDATETIME()),
        FechaActualizacion DATETIME2 NULL
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ad_lote_vucem_detalle_lote')
BEGIN
    ALTER TABLE dbo.ad_lote_vucem_detalle
    ADD CONSTRAINT FK_ad_lote_vucem_detalle_lote
        FOREIGN KEY (IdLote) REFERENCES dbo.ad_lote_vucem(Id);
END
GO

CREATE OR ALTER PROCEDURE dbo.csp_Ad_LoteVucem_Avance
    @idLote BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        l.Id AS IdLote,
        l.IdCliente,
        l.Referencia,
        l.EstatusLote,
        l.TotalItems,
        l.TamanoBloque,
        SUM(CASE WHEN d.EstatusItem IN (2, 3) THEN 1 ELSE 0 END) AS Procesados,
        SUM(CASE WHEN d.EstatusItem = 0 THEN 1 ELSE 0 END) AS Pendientes,
        SUM(CASE WHEN d.EstatusItem = 1 THEN 1 ELSE 0 END) AS EnProceso,
        SUM(CASE WHEN d.EstatusItem = 2 THEN 1 ELSE 0 END) AS Exitosos,
        SUM(CASE WHEN d.EstatusItem = 3 THEN 1 ELSE 0 END) AS Fallidos,
        CASE WHEN l.TotalItems = 0 THEN 0
             ELSE CAST(100.0 * SUM(CASE WHEN d.EstatusItem IN (2, 3) THEN 1 ELSE 0 END) / l.TotalItems AS DECIMAL(5,2))
        END AS PorcentajeAvance
    FROM dbo.ad_lote_vucem l
    LEFT JOIN dbo.ad_lote_vucem_detalle d ON d.IdLote = l.Id
    WHERE l.Id = @idLote
    GROUP BY l.Id, l.IdCliente, l.Referencia, l.EstatusLote, l.TotalItems, l.TamanoBloque;
END
GO
