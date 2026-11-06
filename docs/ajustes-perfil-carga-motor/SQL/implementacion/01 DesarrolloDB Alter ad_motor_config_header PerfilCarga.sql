/*
  Ajuste — Perfil para acciones críticas en ad_motor_config_header
  Base: DesarrolloDB

  Valores PerfilCarga:
    G = Acceso general (default) — cualquiera autenticado puede acciones críticas
    A = Admin  (IdClase ADM)
    L = Líder  (IdClase LIDER)

  El alta de documentos no se restringe por esta columna.

  Ejecutar en QA antes de producción.
*/
USE DesarrolloDB;
GO

IF COL_LENGTH('dbo.ad_motor_config_header', 'PerfilCarga') IS NULL
BEGIN
    ALTER TABLE dbo.ad_motor_config_header
    ADD PerfilCarga CHAR(1) NOT NULL
        CONSTRAINT DF_ad_motor_config_header_PerfilCarga DEFAULT ('G')
        CONSTRAINT CK_ad_motor_config_header_PerfilCarga
            CHECK (PerfilCarga IN ('G', 'A', 'L'));
END;
GO

-- Motores existentes: acceso general (equivalente a decisión de negocio)
UPDATE dbo.ad_motor_config_header
SET PerfilCarga = 'G'
WHERE PerfilCarga IS NULL OR PerfilCarga = '';
GO
