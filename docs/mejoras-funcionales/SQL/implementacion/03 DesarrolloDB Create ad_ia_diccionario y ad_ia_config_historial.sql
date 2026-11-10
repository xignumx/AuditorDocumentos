/*
  ADX-OPER-26-0039 - Epic 3 ID_01 (Dev 2)
  Diccionario de sinonimos / equivalencias de UM e historial de cambios de prompts y diccionario.
  Base: DesarrolloDB

  ad_ia_diccionario
    Categoria = GENERAL : equivalencias de etiquetas ES/EN que se inyectan en el prompt de Vertex
                          (Concepto = nombre del dato, ej. "Numero de parte"; IdCampo = AdCampos opcional).
    Categoria = UM      : equivalencias de unidad de medida, GLOBALES. Concepto = id_unidad_universal canonico
                          (ADUASIS.dbo.funidad_universal); Termino = variante que puede devolver la IA.
    Un Termino pertenece a un solo Concepto por categoria (evita ambiguedad / falsos positivos).
    Supuesto: la coleccion de la base es case-insensitive (el indice unico trata "Part No." = "part no.").

  ad_ia_config_historial
    Una fila por cambio. Version se incrementa por (Entidad, Clave). Los prompts y conceptos que ya
    existen sin historial se consideran version 1 (el primer cambio genera la version 2).
    Clave: PROMPT_DOC = "{IdTipoDocumentoVucem}" | PROMPT_CAMPO = "{IdTipoDocumentoVucem}:{IdCampo}"
           DICCIONARIO = "{Categoria}|{Concepto}"

  No se ejecuta desde la aplicacion. Ejecutar en QA antes de produccion.
*/
USE DesarrolloDB;
GO

IF OBJECT_ID('dbo.ad_ia_diccionario', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ad_ia_diccionario
    (
        Id                 BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_ad_ia_diccionario PRIMARY KEY,
        Categoria          VARCHAR(10)  NOT NULL
            CONSTRAINT CK_ad_ia_diccionario_Categoria CHECK (Categoria IN ('GENERAL', 'UM')),
        Concepto           VARCHAR(100) NOT NULL,
        IdCampo            INT          NULL,
        Termino            VARCHAR(200) NOT NULL,
        Idioma             CHAR(2)      NOT NULL
            CONSTRAINT CK_ad_ia_diccionario_Idioma CHECK (Idioma IN ('ES', 'EN')),
        FechaCreacion      DATETIME     NOT NULL
            CONSTRAINT DF_ad_ia_diccionario_FechaCreacion DEFAULT (GETDATE()),
        CreadoPor          VARCHAR(50)  NOT NULL,
        FechaActualizacion DATETIME     NULL,
        ActualizadoPor     VARCHAR(50)  NULL
    );

    CREATE UNIQUE INDEX UX_ad_ia_diccionario_Termino
        ON dbo.ad_ia_diccionario (Categoria, Termino);

    CREATE INDEX IX_ad_ia_diccionario_Concepto
        ON dbo.ad_ia_diccionario (Categoria, Concepto);
END;
GO

IF OBJECT_ID('dbo.ad_ia_config_historial', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ad_ia_config_historial
    (
        Id                   BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_ad_ia_config_historial PRIMARY KEY,
        Entidad              VARCHAR(15)  NOT NULL
            CONSTRAINT CK_ad_ia_config_historial_Entidad
                CHECK (Entidad IN ('PROMPT_DOC', 'PROMPT_CAMPO', 'DICCIONARIO')),
        Clave                VARCHAR(150) NOT NULL,
        IdTipoDocumentoVucem BIGINT       NULL,
        IdCampo              INT          NULL,
        Version              INT          NOT NULL,
        Accion               VARCHAR(12)  NOT NULL
            CONSTRAINT CK_ad_ia_config_historial_Accion CHECK (Accion IN ('ALTA', 'CAMBIO', 'ELIMINACION')),
        ValorAnterior        VARCHAR(MAX) NULL,
        ValorNuevo           VARCHAR(MAX) NULL,
        Usuario              VARCHAR(50)  NOT NULL,
        Fecha                DATETIME     NOT NULL
            CONSTRAINT DF_ad_ia_config_historial_Fecha DEFAULT (GETDATE())
    );

    CREATE INDEX IX_ad_ia_config_historial_Clave
        ON dbo.ad_ia_config_historial (Entidad, Clave, Version DESC);

    CREATE INDEX IX_ad_ia_config_historial_Fecha
        ON dbo.ad_ia_config_historial (Fecha DESC);
END;
GO
