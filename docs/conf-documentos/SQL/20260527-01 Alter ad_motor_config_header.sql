USE DesarrolloDB
GO

ALTER TABLE dbo.ad_motor_config_header ADD AccionPedimento VARCHAR(2) NULL
GO

UPDATE dbo.ad_motor_config_header SET AccionPedimento = 'P' WHERE AccionPedimento IS NULL
GO

ALTER TABLE dbo.ad_motor_config_header ALTER COLUMN AccionPedimento VARCHAR(2) NOT NULL
GO
