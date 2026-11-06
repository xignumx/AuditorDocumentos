/*
  Ajuste 07/2026 — Prompts IA por campo (ad_ia_prompt_campo)
  Inserta PromptParcial para IdCampo 20–24 en todos los tipos VUCEM
  activos en Auditor de Documentos (ActivoAuditorDocumentos = 1).

  Bases: DesarrolloDB + EDOCS

  IMPORTANTE — este script es solo SEED (alta idempotente):
  - El WHERE NOT EXISTS evita duplicar filas ya existentes.
  - NO actualiza PromptParcial de filas que ya están en ad_ia_prompt_campo.
  - Cambiar el texto en @CamposPrompt solo afecta tipos/campos que aún no tienen fila.
  - Para corregir un prompt ya desplegado hace falta un script de migración aparte
    (UPDATE de PromptParcial / FechaActualizacion / ActualizadoPor) ejecutado por DBA.
*/
USE DesarrolloDB;
GO

DECLARE @CamposPrompt TABLE
(
    IdCampo       INT           NOT NULL,
    NombreCampo   VARCHAR(100)  NOT NULL,
    PromptParcial VARCHAR(2000) NOT NULL
);

INSERT INTO @CamposPrompt (IdCampo, NombreCampo, PromptParcial)
VALUES
    (20, 'Factura',
     'Número o folio de la factura comercial. Devolver solo el identificador, sin etiquetas ni texto adicional.'),
    (21, 'FechaFactura',
     'Fecha de la factura en formato yyyy-MM-dd. Si el documento muestra dd/MM/yyyy, convertir a yyyy-MM-dd.'),
    (22, 'ValorUsd',
     'Valor total expresado en USD. Si el documento está en dólares, usar ese mismo monto (puede coincidir con ValorComercial). Si está en otra moneda y no hay equivalencia en USD, retornar null. Solo número decimal, sin símbolo $ ni separadores de miles.'),
    (23, 'GuiaBl',
     'Número(s) de guía aérea, conocimiento de embarque (BL) o documento de transporte. Si hay varios, separar con punto y coma (;).'),
    (24, 'Pedimento',
     'Número de pedimento aduanero de 15 dígitos sin espacios: 2 dígitos año + 2 aduana + 4 patente + 7 número (ej. 268034386543210). Solo dígitos.');

DECLARE @Tipos TABLE (IdTipoDocumentoVucem BIGINT NOT NULL PRIMARY KEY);

INSERT INTO @Tipos (IdTipoDocumentoVucem)
SELECT v.Id_DocumentoVucem
FROM EDOCS.dbo.Tb_DocumentosVucem v WITH (NOLOCK)
WHERE v.ActivoAuditorDocumentos = 1;

INSERT INTO dbo.ad_ia_prompt_campo
(
    IdTipoDocumentoVucem,
    IdCampo,
    NombreCampo,
    PromptParcial,
    Activo,
    FechaCreacion,
    CreadoPor
)
SELECT
    t.IdTipoDocumentoVucem,
    c.IdCampo,
    c.NombreCampo,
    c.PromptParcial,
    1,
    GETDATE(),
    'ajuste-072026'
FROM @Tipos t
CROSS JOIN @CamposPrompt c
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.ad_ia_prompt_campo p
    WHERE p.IdTipoDocumentoVucem = t.IdTipoDocumentoVucem
      AND p.IdCampo = c.IdCampo
);

SELECT @@ROWCOUNT AS FilasInsertadas;
GO
