/*
  EPIC 1 ID_01 / TK-7006 — objetos NUEVOS (no altera stores existentes).
  Lotes de carga masiva por referencia + avance %.
  Base: DesarrolloDB
*/
USE DesarrolloDB;
GO

IF OBJECT_ID('dbo.ad_lote_carga_detalle', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ad_lote_carga_detalle
    (
        Id              BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        IdLote          BIGINT NOT NULL,
        NombreArchivo   NVARCHAR(260) NOT NULL,
        RutaTemporal    NVARCHAR(500) NULL,
        EstatusLote     INT NOT NULL CONSTRAINT DF_ad_lote_carga_detalle_Estatus DEFAULT (0),
        MensajeError    NVARCHAR(1000) NULL,
        IdDocumento     BIGINT NULL,
        FechaCreacion   DATETIME2 NOT NULL CONSTRAINT DF_ad_lote_carga_detalle_Fc DEFAULT (SYSUTCDATETIME()),
        FechaActualizacion DATETIME2 NULL
    );
END
GO

IF OBJECT_ID('dbo.ad_lote_carga', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ad_lote_carga
    (
        Id              BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        IdCliente       VARCHAR(6) NOT NULL,
        Referencia      NVARCHAR(50) NOT NULL,
        CreadoPor       NVARCHAR(100) NOT NULL,
        EstatusLote     INT NOT NULL CONSTRAINT DF_ad_lote_carga_Estatus DEFAULT (0),
        TotalArchivos   INT NOT NULL CONSTRAINT DF_ad_lote_carga_Total DEFAULT (0),
        FechaCreacion   DATETIME2 NOT NULL CONSTRAINT DF_ad_lote_carga_Fc DEFAULT (SYSUTCDATETIME()),
        FechaActualizacion DATETIME2 NULL
    );
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ad_lote_carga_detalle_lote'
)
BEGIN
    ALTER TABLE dbo.ad_lote_carga_detalle
    ADD CONSTRAINT FK_ad_lote_carga_detalle_lote
        FOREIGN KEY (IdLote) REFERENCES dbo.ad_lote_carga(Id);
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes WHERE name = 'IX_ad_lote_carga_Cliente_Referencia' AND object_id = OBJECT_ID('dbo.ad_lote_carga')
)
BEGIN
    CREATE INDEX IX_ad_lote_carga_Cliente_Referencia ON dbo.ad_lote_carga (IdCliente, Referencia);
END
GO

CREATE OR ALTER PROCEDURE dbo.csp_Ad_LoteCarga_Avance
    @idLote BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        l.Id AS IdLote,
        l.IdCliente,
        l.Referencia,
        l.EstatusLote,
        l.TotalArchivos,
        SUM(CASE WHEN d.EstatusLote IN (2, 3, 4, 5) THEN 1 ELSE 0 END) AS Procesados,
        SUM(CASE WHEN d.EstatusLote = 0 THEN 1 ELSE 0 END) AS EnCola,
        SUM(CASE WHEN d.EstatusLote = 1 THEN 1 ELSE 0 END) AS Procesando,
        SUM(CASE WHEN d.EstatusLote = 2 THEN 1 ELSE 0 END) AS ListoParaRevisar,
        SUM(CASE WHEN d.EstatusLote = 3 THEN 1 ELSE 0 END) AS ConObservaciones,
        SUM(CASE WHEN d.EstatusLote = 4 THEN 1 ELSE 0 END) AS Autorizado,
        SUM(CASE WHEN d.EstatusLote = 5 THEN 1 ELSE 0 END) AS Error,
        CASE
            WHEN l.TotalArchivos = 0 THEN 0
            ELSE CAST(100.0 * SUM(CASE WHEN d.EstatusLote IN (2, 3, 4, 5) THEN 1 ELSE 0 END) / l.TotalArchivos AS DECIMAL(5, 2))
        END AS PorcentajeAvance
    FROM dbo.ad_lote_carga l
    LEFT JOIN dbo.ad_lote_carga_detalle d ON d.IdLote = l.Id
    WHERE l.Id = @idLote
    GROUP BY l.Id, l.IdCliente, l.Referencia, l.EstatusLote, l.TotalArchivos;
END
GO

CREATE OR ALTER PROCEDURE dbo.csp_Ad_LoteCarga_ListarDetalle
    @idLote BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        d.Id,
        d.IdLote,
        d.NombreArchivo,
        d.EstatusLote,
        d.MensajeError,
        d.IdDocumento,
        d.FechaCreacion,
        d.FechaActualizacion
    FROM dbo.ad_lote_carga_detalle d
    WHERE d.IdLote = @idLote
    ORDER BY d.Id;
END
GO
