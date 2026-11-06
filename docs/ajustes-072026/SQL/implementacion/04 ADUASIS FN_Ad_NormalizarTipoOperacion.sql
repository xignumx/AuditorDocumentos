/*
  Normaliza TipoOperacion (AdCampos 4) al código ADUASIS: '1' importación, '2' exportación.
  Acepta alias: Importación, Impo, IMP, Importacion, Exportación, Expo, EXP, etc.

  Ejecutar en: ADUASIS (antes o junto con actualización de SPs v2).
*/
USE ADUASIS;
GO

CREATE OR ALTER FUNCTION dbo.FN_Ad_NormalizarTipoOperacion (@valor VARCHAR(100))
RETURNS VARCHAR(1)
AS
BEGIN
    DECLARE @raw VARCHAR(100) = LTRIM(RTRIM(ISNULL(@valor, '')));

    IF @raw = ''
    BEGIN
        RETURN NULL;
    END;

    IF @raw IN ( '1', '2' )
    BEGIN
        RETURN @raw;
    END;

    DECLARE @lower VARCHAR(100) = LOWER(@raw);

    IF (
           @lower LIKE 'imp%'
           OR @lower LIKE 'impo%'
           OR @lower LIKE 'import%'
       )
    BEGIN
        RETURN '1';
    END;

    IF (
           @lower LIKE 'exp%'
           OR @lower LIKE 'expo%'
           OR @lower LIKE 'export%'
       )
    BEGIN
        RETURN '2';
    END;

    RETURN LEFT(@raw, 1);
END;
GO
