/*
  EPIC 1 ID_01 — columnas OCR en tablas NUEVAS del sprint (no toca stores legacy).
*/
USE DesarrolloDB;
GO

IF COL_LENGTH('dbo.ad_lote_carga_detalle', 'ResultadoOcr') IS NULL
BEGIN
    ALTER TABLE dbo.ad_lote_carga_detalle ADD ResultadoOcr NVARCHAR(MAX) NULL;
END
GO

IF COL_LENGTH('dbo.ad_lote_carga_detalle', 'IdTipoDocumentoVucem') IS NULL
BEGIN
    ALTER TABLE dbo.ad_lote_carga_detalle ADD IdTipoDocumentoVucem INT NULL;
END
GO

IF COL_LENGTH('dbo.ad_lote_carga', 'IdTipoDocumentoVucem') IS NULL
BEGIN
    ALTER TABLE dbo.ad_lote_carga ADD IdTipoDocumentoVucem INT NULL;
END
GO
