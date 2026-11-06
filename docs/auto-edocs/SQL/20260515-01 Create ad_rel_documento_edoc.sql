USE DesarrolloDB
GO

CREATE TABLE dbo.ad_rel_documento_edoc (
	Id INT IDENTITY(1,1) PRIMARY KEY NOT NULL,
	IdDocumento BIGINT NOT NULL,
	Id_Archivo INT NOT NULL,
	FechaRegistro DATETIME NOT NULL,
	CreadoPor VARCHAR(50) NOT NULL,
	IdSelloEdoc INT NULL
)
GO
