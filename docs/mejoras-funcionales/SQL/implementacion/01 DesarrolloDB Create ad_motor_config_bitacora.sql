/*
  ADX-OPER-26-0039 - Epic 5 ID_01 (Dev 2)
  Bitacora de auditoria de cambios en la configuracion del motor (/config).
  Base: DesarrolloDB

  Una fila por parametro modificado:
    Parametro   = IdClasificacion | AccionPedimento | PerfilCarga | Activo
                  | Campo:{NombreCampo}.Visible | Campo:{NombreCampo}.Obligatorio | Campo:{NombreCampo}.Eliminado
    Origen      = MANUAL (pantalla /config) | MASIVA (carga masiva de matriz)
    Alta        = ValorAnterior NULL (primer guardado del motor)

  Supuesto: ad_motor_config_header.Id es BIGINT (la entidad EF lo mapea como long). Verificar antes de ejecutar.
  No se ejecuta desde la aplicacion. Ejecutar en QA antes de produccion.
*/
USE DesarrolloDB;
GO

IF OBJECT_ID('dbo.ad_motor_config_bitacora', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ad_motor_config_bitacora
    (
        Id                   BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_ad_motor_config_bitacora PRIMARY KEY,
        IdMotorConfigHeader  BIGINT        NOT NULL,
        IdCliente            VARCHAR(6)    NOT NULL,
        IdTipoDocumentoVucem INT           NOT NULL,
        Parametro            VARCHAR(100)  NOT NULL,
        ValorAnterior        VARCHAR(200)  NULL,
        ValorNuevo           VARCHAR(200)  NULL,
        Origen               VARCHAR(10)   NOT NULL
            CONSTRAINT DF_ad_motor_config_bitacora_Origen DEFAULT ('MANUAL')
            CONSTRAINT CK_ad_motor_config_bitacora_Origen CHECK (Origen IN ('MANUAL', 'MASIVA')),
        MotivoCambio         VARCHAR(500)  NULL,
        UsuarioCambio        VARCHAR(50)   NOT NULL,
        FechaCambio          DATETIME      NOT NULL
            CONSTRAINT DF_ad_motor_config_bitacora_Fecha DEFAULT (GETDATE()),
        CONSTRAINT FK_ad_motor_config_bitacora_header
            FOREIGN KEY (IdMotorConfigHeader) REFERENCES dbo.ad_motor_config_header (Id)
    );

    CREATE INDEX IX_ad_motor_config_bitacora_Header
        ON dbo.ad_motor_config_bitacora (IdMotorConfigHeader, FechaCambio DESC);

    CREATE INDEX IX_ad_motor_config_bitacora_ClienteTipo
        ON dbo.ad_motor_config_bitacora (IdCliente, IdTipoDocumentoVucem, FechaCambio DESC);

    CREATE INDEX IX_ad_motor_config_bitacora_Usuario
        ON dbo.ad_motor_config_bitacora (UsuarioCambio, FechaCambio DESC);
END;
GO
