ALTER TABLE EDOCS.dbo.Tb_DocumentosVucem ADD ActivoAuditorDocumentos BIT NULL 
GO

UPDATE EDOCS.dbo.Tb_DocumentosVucem SET ActivoAuditorDocumentos = Activo WHERE ActivoAuditorDocumentos IS NULL
GO

ALTER TABLE EDOCS.dbo.Tb_DocumentosVucem ALTER COLUMN ActivoAuditorDocumentos BIT NOT NULL
GO