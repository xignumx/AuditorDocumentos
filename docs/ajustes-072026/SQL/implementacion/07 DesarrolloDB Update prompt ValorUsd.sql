/*
  Migración 2026-10-08 — Actualizar PromptParcial de ValorUsd (IdCampo = 22)
  en TODOS los tipos de documento YA configurados en ad_ia_prompt_campo.

  Diferencia vs script 02:
    - 02 = SEED: solo INSERT si no existe la fila (no toca prompts existentes).
    - 07 = MIGRACIÓN: UPDATE del PromptParcial en cada IdTipoDocumentoVucem
      que ya tiene fila IdCampo = 22 (~694 tipos al 2026-10-08).

  La IA lee estos prompts por tipo en ExtraDatosDocumentoIa
  (GetIaPromptDocumentoConCamposAsync → ad_ia_prompt_campo.PromptParcial).
  ad_ia_prompt_documento (plantilla [CAMPOS]/[JSON]) no guarda el texto de ValorUsd;
  no requiere cambio.

  Motivo: el texto anterior ("Distinto del valor comercial") hacía que en PDFs
  en USD la IA dejara ValorUsd en null al coincidir con ValorComercial (19).

  Base: DesarrolloDB (+ EDOCS solo para el SELECT de nombres en verificación)
  NO ejecutar desde el agente; aplicar manualmente / DBA.

  Opcional: descomentar AND IdTipoDocumentoVucem = 26 para limitar a
  Id_Vucem 170 / PrefijoEI 1-002.
*/

USE DesarrolloDB;
GO

DECLARE @PromptNuevo NVARCHAR(2000) =
    N'Valor total expresado en USD. Si el documento está en dólares, usar ese mismo monto (puede coincidir con ValorComercial). Si está en otra moneda y no hay equivalencia en USD, retornar null. Solo número decimal, sin símbolo $ ni separadores de miles.';

/* --- Verificación previa: prompts por documento ya configurado --- */
SELECT
    p.Id,
    p.IdTipoDocumentoVucem,
    v.Id_Vucem,
    v.PrefijoEI,
    v.Documento AS NombreTipoDocumento,
    p.IdCampo,
    p.NombreCampo,
    p.PromptParcial AS PromptActual,
    p.Activo
FROM dbo.ad_ia_prompt_campo AS p WITH (NOLOCK)
LEFT JOIN EDOCS.dbo.Tb_DocumentosVucem AS v WITH (NOLOCK)
    ON v.Id_DocumentoVucem = p.IdTipoDocumentoVucem
WHERE p.IdCampo = 22
      -- AND p.IdTipoDocumentoVucem = 26
ORDER BY p.IdTipoDocumentoVucem;

SELECT
    COUNT(*) AS FilasAActualizar,
    SUM(CASE WHEN p.PromptParcial LIKE N'%Distinto del valor comercial%' THEN 1 ELSE 0 END) AS ConTextoViejo
FROM dbo.ad_ia_prompt_campo AS p WITH (NOLOCK)
WHERE p.IdCampo = 22
      -- AND p.IdTipoDocumentoVucem = 26
;

/* --- Actualización: todos los documentos ya configurados con campo 22 --- */
UPDATE dbo.ad_ia_prompt_campo
SET
    PromptParcial = @PromptNuevo,
    FechaActualizacion = GETDATE(),
    ActualizadoPor = N'ajuste-20261008-valor-usd'
WHERE IdCampo = 22
      -- AND IdTipoDocumentoVucem = 26
;

SELECT @@ROWCOUNT AS FilasActualizadas;

/* --- Verificación posterior --- */
SELECT
    p.Id,
    p.IdTipoDocumentoVucem,
    v.Documento AS NombreTipoDocumento,
    p.PromptParcial AS PromptNuevo,
    p.FechaActualizacion,
    p.ActualizadoPor
FROM dbo.ad_ia_prompt_campo AS p WITH (NOLOCK)
LEFT JOIN EDOCS.dbo.Tb_DocumentosVucem AS v WITH (NOLOCK)
    ON v.Id_DocumentoVucem = p.IdTipoDocumentoVucem
WHERE p.IdCampo = 22
      -- AND p.IdTipoDocumentoVucem = 26
ORDER BY p.IdTipoDocumentoVucem;

SELECT
    COUNT(*) AS FilasConTextoNuevo
FROM dbo.ad_ia_prompt_campo AS p WITH (NOLOCK)
WHERE p.IdCampo = 22
      AND p.PromptParcial LIKE N'%puede coincidir con ValorComercial%'
      -- AND p.IdTipoDocumentoVucem = 26
;
GO
