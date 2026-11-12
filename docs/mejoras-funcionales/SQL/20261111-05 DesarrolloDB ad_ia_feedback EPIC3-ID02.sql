/*
  EPIC 3 ID_02 / TK-7006 — feedback IA y métricas (objetos NUEVOS).
*/
USE DesarrolloDB;
GO

IF OBJECT_ID('dbo.ad_ia_feedback', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ad_ia_feedback
    (
        Id                 BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        IdDocumento        BIGINT NOT NULL,
        IdCampo            INT NOT NULL,
        ValorIa            NVARCHAR(2000) NULL,
        ValorConfirmado    NVARCHAR(2000) NULL,
        FueCorregido       BIT NOT NULL CONSTRAINT DF_ad_ia_feedback_Corr DEFAULT (0),
        EsSugerido         BIT NOT NULL CONSTRAINT DF_ad_ia_feedback_Sug DEFAULT (0),
        Usuario            NVARCHAR(100) NOT NULL,
        FechaCreacion      DATETIME2 NOT NULL CONSTRAINT DF_ad_ia_feedback_Fc DEFAULT (SYSUTCDATETIME())
    );
    CREATE INDEX IX_ad_ia_feedback_Documento ON dbo.ad_ia_feedback (IdDocumento);
    CREATE INDEX IX_ad_ia_feedback_Campo ON dbo.ad_ia_feedback (IdCampo);
END
GO

CREATE OR ALTER PROCEDURE dbo.csp_Ad_IaFeedback_Metricas
    @idCliente VARCHAR(6) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        COUNT(1) AS TotalConfirmaciones,
        ISNULL(SUM(CASE WHEN f.FueCorregido = 1 THEN 1 ELSE 0 END), 0) AS TotalCorrecciones,
        ISNULL(SUM(CASE WHEN f.FueCorregido = 0 THEN 1 ELSE 0 END), 0) AS TotalExactas,
        CASE WHEN COUNT(1) = 0 THEN CAST(0 AS DECIMAL(5,2))
             ELSE CAST(100.0 * SUM(CASE WHEN f.FueCorregido = 0 THEN 1 ELSE 0 END) / COUNT(1) AS DECIMAL(5,2))
        END AS PorcentajePrecision
    FROM dbo.ad_ia_feedback f
    LEFT JOIN dbo.ad_documentos d ON d.Id = f.IdDocumento
    WHERE (@idCliente IS NULL OR @idCliente = '' OR d.IdCliente = @idCliente);

END
GO
