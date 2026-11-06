USE DesarrolloDB
GO

ALTER TABLE dbo.ad_documentos_archivos ADD NombreEdocs VARCHAR(250) NULL
GO

UPDATE dbo.ad_documentos_archivos SET NombreEdocs = NombreArchivo WHERE NombreEdocs IS NULL
GO

ALTER TABLE dbo.ad_documentos_archivos ALTER COLUMN NombreEdocs VARCHAR(250) NOT NULL
GO
