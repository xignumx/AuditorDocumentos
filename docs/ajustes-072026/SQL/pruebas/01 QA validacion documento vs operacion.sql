/*
  QA — Documento vs operación (sugerencia pedimentos v2)
  Base: ADUASIS. SP: csp_Ad_SugerenciaPedimentos_v2 (implementacion/05).

  OBJETIVO
  Dado un documento y UNA operación (pedimento o tráfico), mostrar:
    1) Valores obligatorios del documento (filtros activos del motor)
    2) Valores de la operación en ADUASIS
    3) Comparación campo a campo: ¿cumple sí / no?

  PARÁMETROS (editar en la sección siguiente)
    @idAdDocumento     — Id del documento en ad_documentos
    @id_referencia     — id_trafico si es tráfico sin pedimento; id_referencia del pedimento si aplica
    @id_rectificacion  — NULL = tráfico sin pedimento (solo id_trafico en @id_referencia);
                         valor numérico = pedimento con esa rectificación

  EJEMPLOS
    Tráfico:     @id_referencia = 'V26-10422', @id_rectificacion = NULL
    Pedimento:   @id_referencia = '12345678', @id_rectificacion = 0

  REQUISITOS: implementacion/04 FN_Ad_NormalizarTipoOperacion

  NOTA (alineado con implementacion/05):
  - Tráfico sin pedimento: @id_referencia = fgtrafico.id_trafico y NOT EXISTS fpedimento
    para (fgt.id_referencia, fgt.id_rectificacion).
  - Al leer tráfico para validar un pedimento, fgtrafico se une solo por id_referencia
    y fgt.id_rectificacion = 0 (no se usa la rectificación del pedimento).
*/
USE ADUASIS;
GO

/* ========== PARÁMETROS — editar aquí ========== */
DECLARE @idAdDocumento BIGINT = 252;              -- <-- Id documento
DECLARE @id_referencia VARCHAR(20) = 'V26-10422'; -- <-- id_trafico o id_referencia pedimento
DECLARE @id_rectificacion INT = NULL;             -- <-- NULL = tráfico sin pedimento

/* ========== Validación de parámetros ========== */
IF @idAdDocumento IS NULL OR NULLIF(LTRIM(RTRIM(@id_referencia)), '') IS NULL
BEGIN
    RAISERROR('Indique @idAdDocumento y @id_referencia.', 16, 1);
    RETURN;
END;

DECLARE @idCliente VARCHAR(10);

SELECT @idCliente = d.IdCliente
FROM DesarrolloDB.dbo.ad_documentos AS d WITH (NOLOCK)
WHERE d.Id = @idAdDocumento;

IF @idCliente IS NULL
BEGIN
    RAISERROR('No existe el documento indicado.', 16, 1);
    RETURN;
END;

/* Tipo de operación (alineado implementacion/05 — tráfico sin pedimento) */
DECLARE @EsTrafico BIT = 0;

IF EXISTS (
    SELECT 1
    FROM ADUASIS.dbo.fgtrafico AS g WITH (NOLOCK)
    WHERE g.id_trafico = @id_referencia
          AND g.id_cliente = @idCliente
          AND NOT EXISTS (
              SELECT 1
              FROM ADUASIS.dbo.fpedimento AS f WITH (NOLOCK)
              WHERE f.id_referencia = g.id_referencia
                    AND f.id_rectificacion = g.id_rectificacion
          )
)
BEGIN
    /* @id_referencia es id_trafico (como devuelve el SP en la columna id_referencia) */
    IF @id_rectificacion IS NULL
       OR NOT EXISTS (
           SELECT 1
           FROM ADUASIS.dbo.fpedimento AS f WITH (NOLOCK)
           WHERE f.id_referencia = @id_referencia
                 AND f.id_rectificacion = ISNULL(@id_rectificacion, 0)
                 AND f.id_cliente = @idCliente
       )
    BEGIN
        SET @EsTrafico = 1;
    END;
END;

IF @EsTrafico = 0
   AND NOT EXISTS (
       SELECT 1
       FROM ADUASIS.dbo.fpedimento AS f WITH (NOLOCK)
       WHERE f.id_referencia = @id_referencia
             AND f.id_rectificacion = ISNULL(@id_rectificacion, 0)
             AND f.id_cliente = @idCliente
   )
BEGIN
    IF @id_rectificacion IS NULL
    BEGIN
        RAISERROR('No se localizó tráfico sin pedimento (id_trafico) ni pedimento para la referencia indicada.', 16, 1);
    END;
    ELSE
    BEGIN
        RAISERROR('No se localizó pedimento con esa referencia/rectificación para el cliente del documento.', 16, 1);
    END;
    RETURN;
END;

/* --- Filtros activos (misma regla que el SP v2) --- */
DECLARE @Filtros TABLE
(
    IdCampo INT NOT NULL PRIMARY KEY,
    NombreCampo NVARCHAR(100) NOT NULL,
    Valor NVARCHAR(MAX) NOT NULL
);

INSERT INTO @Filtros (IdCampo, NombreCampo, Valor)
SELECT dcd.IdCampo,
       dcd.NombreCampo,
       LTRIM(RTRIM(dc.Valor))
FROM DesarrolloDB.dbo.ad_documentos AS d WITH (NOLOCK)
    INNER JOIN DesarrolloDB.dbo.ad_motor_config_detalle AS dcd WITH (NOLOCK)
        ON dcd.IdMotorConfigHeader = d.IdMotorConfigHeader
    INNER JOIN DesarrolloDB.dbo.ad_documentos_campos AS dc WITH (NOLOCK)
        ON dc.IdDocumento = d.Id
           AND dc.IdCampo = dcd.IdCampo
WHERE d.Id = @idAdDocumento
      AND dcd.Visible = 1
      AND dcd.Obligatorio = 1
      AND NULLIF(LTRIM(RTRIM(dc.Valor)), '') IS NOT NULL
      AND dcd.IdCampo NOT IN ( 1, 2, 11, 14, 15, 17, 18, 19, 22, 100, 101 );

DECLARE @ClavesPed TABLE (Clave VARCHAR(2) NOT NULL);
DECLARE @Fracciones TABLE (Fraccion VARCHAR(8) NOT NULL);
DECLARE @Paises TABLE (Pais VARCHAR(1000) NOT NULL);
DECLARE @Guias TABLE (Guia VARCHAR(100) NOT NULL);
DECLARE @UnidadesUMT TABLE (IdUnidad VARCHAR(20) NOT NULL PRIMARY KEY);

IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 5)
    INSERT INTO @ClavesPed (Clave)
    SELECT DISTINCT LTRIM(RTRIM(s.splitdata))
    FROM @Filtros AS f
        CROSS APPLY ADUASIS.dbo.FN_SplitSTR(f.Valor, ';') AS s
    WHERE f.IdCampo = 5
          AND NULLIF(LTRIM(RTRIM(s.splitdata)), '') IS NOT NULL;

IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 9)
    INSERT INTO @Fracciones (Fraccion)
    SELECT DISTINCT LEFT(LTRIM(RTRIM(s.splitdata)), 8)
    FROM @Filtros AS f
        CROSS APPLY ADUASIS.dbo.FN_SplitSTR(REPLACE(f.Valor, '.', ''), ';') AS s
    WHERE f.IdCampo = 9
          AND NULLIF(LEFT(LTRIM(RTRIM(s.splitdata)), 8), '') IS NOT NULL;

IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 13)
    INSERT INTO @Paises (Pais)
    SELECT DISTINCT LTRIM(RTRIM(s.splitdata))
    FROM @Filtros AS f
        CROSS APPLY ADUASIS.dbo.FN_SplitSTR(f.Valor, ';') AS s
    WHERE f.IdCampo = 13
          AND NULLIF(LTRIM(RTRIM(s.splitdata)), '') IS NOT NULL;

IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 23)
    INSERT INTO @Guias (Guia)
    SELECT DISTINCT LTRIM(RTRIM(s.splitdata))
    FROM @Filtros AS f
        CROSS APPLY ADUASIS.dbo.FN_SplitSTR(f.Valor, ';') AS s
    WHERE f.IdCampo = 23
          AND NULLIF(LTRIM(RTRIM(s.splitdata)), '') IS NOT NULL;

IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 12)
BEGIN
    INSERT INTO @UnidadesUMT (IdUnidad)
    SELECT DISTINCT u.id_unidad_universal
    FROM @Filtros AS f
        CROSS APPLY ADUASIS.dbo.FN_SplitSTR(f.Valor, ';') AS s
        INNER JOIN ADUASIS.dbo.funidad_universal AS u WITH (NOLOCK)
            ON u.id_unidad_universal = LTRIM(RTRIM(s.splitdata))
               OR u.descripcion LIKE '%' + LTRIM(RTRIM(s.splitdata)) + '%'
               OR u.desc_abreviada = LTRIM(RTRIM(s.splitdata))
    WHERE f.IdCampo = 12;

    INSERT INTO @UnidadesUMT (IdUnidad)
    SELECT DISTINCT LTRIM(RTRIM(s.splitdata))
    FROM @Filtros AS f
        CROSS APPLY ADUASIS.dbo.FN_SplitSTR(f.Valor, ';') AS s
    WHERE f.IdCampo = 12
          AND NULLIF(LTRIM(RTRIM(s.splitdata)), '') IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM ADUASIS.dbo.funidad_universal AS u WITH (NOLOCK)
              WHERE u.id_unidad_universal = LTRIM(RTRIM(s.splitdata))
                    OR u.descripcion LIKE '%' + LTRIM(RTRIM(s.splitdata)) + '%'
                    OR u.desc_abreviada = LTRIM(RTRIM(s.splitdata))
          )
          AND NOT EXISTS (
              SELECT 1
              FROM @UnidadesUMT AS umt
              WHERE umt.IdUnidad = LTRIM(RTRIM(s.splitdata))
          );
END;

DECLARE @ValorPedimento24 VARCHAR(20) = NULL,
        @PedAduana VARCHAR(2) = NULL,
        @PedPatente VARCHAR(4) = NULL,
        @PedNumero VARCHAR(7) = NULL;

IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 24)
BEGIN
    SELECT @ValorPedimento24 = REPLACE(REPLACE(Valor, ' ', ''), CHAR(9), '')
    FROM @Filtros
    WHERE IdCampo = 24;

    IF LEN(@ValorPedimento24) >= 15
    BEGIN
        SET @PedAduana = SUBSTRING(@ValorPedimento24, 3, 2);
        SET @PedPatente = SUBSTRING(@ValorPedimento24, 5, 4);
        SET @PedNumero = SUBSTRING(@ValorPedimento24, 9, 7);
    END;
END;

DECLARE @AtajoPedimento24 BIT = CASE WHEN EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 24) THEN 1 ELSE 0 END;

/* --- Datos de la operación --- */
DECLARE @fped_id_cliente VARCHAR(10),
        @fped_fecha_pago_banco DATE,
        @fped_firma_banco VARCHAR(10),
        @fped_pedimento VARCHAR(50),
        @fped_cve_tipo_operacion VARCHAR(10),
        @fped_id_tipo_pedimento VARCHAR(10),
        @fped_id_regimen VARCHAR(10),
        @fped_aduana_seccion VARCHAR(20),
        @fped_id_referencia VARCHAR(20),
        @fped_id_rectificacion VARCHAR(5);

DECLARE @fgt_id_trafico VARCHAR(10),
        @fgt_id_cliente VARCHAR(10),
        @fgt_cve_tipo_operacion VARCHAR(10),
        @fgt_tipo_operacion_norm VARCHAR(5),
        @fgt_id_tipo_pedimento VARCHAR(10),
        @fgt_id_regimen VARCHAR(10),
        @fgt_aduana_seccion VARCHAR(30);

IF @EsTrafico = 0
BEGIN
    SELECT TOP (1)
        @fped_id_cliente = f.id_cliente,
        @fped_fecha_pago_banco = f.fecha_pago_banco,
        @fped_firma_banco = f.firma_banco,
        @fped_pedimento = f.pedimento,
        @fped_cve_tipo_operacion = f.cve_tipo_operacion,
        @fped_id_tipo_pedimento = f.id_tipo_pedimento,
        @fped_id_regimen = f.id_regimen,
        @fped_aduana_seccion = f.id_aduana + f.seccion,
        @fped_id_referencia = f.id_referencia,
        @fped_id_rectificacion = f.id_rectificacion
    FROM ADUASIS.dbo.fpedimento AS f WITH (NOLOCK)
    WHERE f.id_referencia = @id_referencia
          AND f.id_rectificacion = ISNULL(@id_rectificacion, 0)
          AND f.id_cliente = @idCliente
    ORDER BY f.fecha_pago DESC;
END;
ELSE
BEGIN
    SELECT TOP (1)
        @fgt_id_trafico = g.id_trafico,
        @fgt_id_cliente = g.id_cliente,
        @fgt_cve_tipo_operacion = g.cve_tipo_operacion,
        @fgt_tipo_operacion_norm = CASE
                                       WHEN g.cve_tipo_operacion = '0' THEN '1'
                                       WHEN g.cve_tipo_operacion = '1' THEN '2'
                                       ELSE ''
                                   END,
        @fgt_id_tipo_pedimento = g.id_tipo_pedimento,
        @fgt_id_regimen = g.id_regimen,
        @fgt_aduana_seccion = ISNULL(g.id_aduana, '') + ISNULL(g.seccion_aduana, '')
    FROM ADUASIS.dbo.fgtrafico AS g WITH (NOLOCK)
    WHERE g.id_trafico = @id_referencia
          AND g.id_cliente = @idCliente
          AND NOT EXISTS (
              SELECT 1
              FROM ADUASIS.dbo.fpedimento AS f WITH (NOLOCK)
              WHERE f.id_referencia = g.id_referencia
                    AND f.id_rectificacion = g.id_rectificacion
          );
END;

DECLARE @existeOpBloqueo BIT = CASE
                                    WHEN EXISTS (
                                        SELECT 1
                                        FROM DesarrolloDB.dbo.ad_documento_operacion AS op WITH (NOLOCK)
                                        WHERE op.IdDocumento = @idAdDocumento
                                              AND (
                                                      (
                                                          @EsTrafico = 0
                                                          AND op.id_referencia = @fped_id_referencia
                                                          AND op.id_rectificacion = @fped_id_rectificacion
                                                          AND op.pedimento = @fped_pedimento
                                                      )
                                                      OR (
                                                             @EsTrafico = 1
                                                             AND op.id_referencia = @fgt_id_trafico
                                                             AND op.id_rectificacion IS NULL
                                                             AND ISNULL(op.pedimento, '') = ''
                                                         )
                                                  )
                                    ) THEN 1
                                    ELSE 0
                                END;

/* ========== 1) Documento — valores obligatorios ========== */
SELECT @idAdDocumento AS IdDocumento,
       @idCliente AS IdCliente,
       f.IdCampo,
       f.NombreCampo,
       f.Valor AS ValorObligatorioDocumento
FROM @Filtros AS f
ORDER BY f.IdCampo;

/* ========== 2) Operación — identificación ========== */
SELECT @idAdDocumento AS IdDocumento,
       CASE WHEN @EsTrafico = 1 THEN 'TRAFICO' ELSE 'PEDIMENTO' END AS TipoOperacion,
       CASE WHEN @EsTrafico = 1 THEN @fgt_id_trafico ELSE @fped_id_referencia END AS id_referencia,
       CASE WHEN @EsTrafico = 1 THEN NULL ELSE @fped_id_rectificacion END AS id_rectificacion,
       CASE WHEN @EsTrafico = 1 THEN NULL ELSE @fped_pedimento END AS pedimento,
       CASE WHEN @EsTrafico = 1 THEN @fgt_id_cliente ELSE @fped_id_cliente END AS id_cliente,
       CASE WHEN @EsTrafico = 1 THEN @fgt_aduana_seccion ELSE @fped_aduana_seccion END AS aduana,
       CASE WHEN @EsTrafico = 1 THEN @fgt_id_tipo_pedimento ELSE @fped_id_tipo_pedimento END AS tipo_pedimento,
       CASE WHEN @EsTrafico = 1 THEN @fgt_tipo_operacion_norm ELSE @fped_cve_tipo_operacion END AS tipo_operacion,
       CASE WHEN @EsTrafico = 1 THEN @fgt_id_regimen ELSE @fped_id_regimen END AS clave_pedimento,
       CASE WHEN @EsTrafico = 1 THEN NULL ELSE @fped_fecha_pago_banco END AS fecha_pago_banco,
       CASE WHEN @EsTrafico = 1 THEN NULL ELSE @fped_firma_banco END AS firma_banco;

/* ========== 3) Comparación: documento vs operación ========== */
DECLARE @Cmp TABLE
(
    Orden SMALLINT NOT NULL,
    IdCampo INT NULL,
    Campo NVARCHAR(100) NOT NULL,
    ValorObligatorioDocumento NVARCHAR(MAX) NULL,
    ValorEnOperacion NVARCHAR(MAX) NULL,
    Cumple VARCHAR(3) NOT NULL
);

DECLARE @ord SMALLINT = 0;
DECLARE @valDoc NVARCHAR(MAX);
DECLARE @valDocNorm NVARCHAR(MAX);
DECLARE @valOp NVARCHAR(MAX);
DECLARE @cumple VARCHAR(3);
DECLARE @IdCampo INT;
DECLARE @NombreCampo NVARCHAR(100);

/* --- Reglas operativas (no son IdCampo del motor, pero afectan sugerencia) --- */
SET @ord = @ord + 10;
INSERT INTO @Cmp (Orden, IdCampo, Campo, ValorObligatorioDocumento, ValorEnOperacion, Cumple)
VALUES (
    @ord,
    NULL,
    N'Cliente de la operación',
    @idCliente,
    CASE WHEN @EsTrafico = 1 THEN @fgt_id_cliente ELSE @fped_id_cliente END,
    CASE
        WHEN @EsTrafico = 1 AND @fgt_id_cliente = @idCliente THEN 'SI'
        WHEN @EsTrafico = 0 AND @fped_id_cliente = @idCliente THEN 'SI'
        ELSE 'NO'
    END
);

IF @EsTrafico = 0
BEGIN
    SET @ord = @ord + 10;
    INSERT INTO @Cmp (Orden, IdCampo, Campo, ValorObligatorioDocumento, ValorEnOperacion, Cumple)
    VALUES (
        @ord,
        NULL,
        N'Pedimento abierto (sin pago/firma banco)',
        N'Sin pago y sin firma',
        N'Pago: ' + ISNULL(CONVERT(VARCHAR(10), @fped_fecha_pago_banco, 23), '(null)')
        + N' | Firma: ' + ISNULL(@fped_firma_banco, '(null)'),
        CASE
            WHEN @fped_fecha_pago_banco IS NULL AND @fped_firma_banco IS NULL THEN 'SI'
            ELSE 'NO'
        END
    );

    SET @ord = @ord + 10;
    INSERT INTO @Cmp (Orden, IdCampo, Campo, ValorObligatorioDocumento, ValorEnOperacion, Cumple)
    VALUES (
        @ord,
        NULL,
        N'Número de pedimento',
        N'Debe tener pedimento',
        ISNULL(@fped_pedimento, N'(vacío)'),
        CASE WHEN NULLIF(LTRIM(RTRIM(@fped_pedimento)), '') IS NOT NULL THEN 'SI' ELSE 'NO' END
    );
END;

SET @ord = @ord + 10;
INSERT INTO @Cmp (Orden, IdCampo, Campo, ValorObligatorioDocumento, ValorEnOperacion, Cumple)
VALUES (
    @ord,
    NULL,
    N'No asociada previamente a este documento',
    CAST(@idAdDocumento AS NVARCHAR(20)),
    CASE WHEN @existeOpBloqueo = 1 THEN N'Ya vinculada' ELSE N'Sin vínculo previo' END,
    CASE WHEN @existeOpBloqueo = 0 THEN 'SI' ELSE 'NO' END
);

/* --- Campos obligatorios del motor --- */
DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
SELECT f.IdCampo,
       f.NombreCampo,
       f.Valor
FROM @Filtros AS f
ORDER BY f.IdCampo;

OPEN cur;
FETCH NEXT FROM cur
INTO @IdCampo,
     @NombreCampo,
     @valDoc;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @ord = @ord + 10;
    SET @valOp = NULL;
    SET @cumple = 'NO';
    SET @valDocNorm = @valDoc;

    /* Atajo pedimento 24: el SP ignora el resto de filtros del motor */
    IF @AtajoPedimento24 = 1 AND @IdCampo <> 24
    BEGIN
        INSERT INTO @Cmp (Orden, IdCampo, Campo, ValorObligatorioDocumento, ValorEnOperacion, Cumple)
        VALUES (@ord, @IdCampo, @NombreCampo, @valDoc, N'Omitido (atajo pedimento 24 activo)', 'NA');
    END;
    ELSE
    BEGIN
    IF @IdCampo = 3 AND @EsTrafico = 0
    BEGIN
        SET @valOp = @fped_id_tipo_pedimento;
        SET @cumple = CASE WHEN @fped_id_tipo_pedimento = @valDoc THEN 'SI' ELSE 'NO' END;
    END;
    ELSE IF @IdCampo = 3 AND @EsTrafico = 1
    BEGIN
        SET @valOp = @fgt_id_tipo_pedimento;
        SET @cumple = CASE WHEN @fgt_id_tipo_pedimento = @valDoc THEN 'SI' ELSE 'NO' END;
    END;
    ELSE IF @IdCampo = 4 AND @EsTrafico = 0
    BEGIN
        SET @valDocNorm = dbo.FN_Ad_NormalizarTipoOperacion(@valDoc);
        SET @valOp = @fped_cve_tipo_operacion;
        SET @cumple = CASE WHEN @fped_cve_tipo_operacion = @valDocNorm THEN 'SI' ELSE 'NO' END;
    END;
    ELSE IF @IdCampo = 4 AND @EsTrafico = 1
    BEGIN
        SET @valDocNorm = dbo.FN_Ad_NormalizarTipoOperacion(@valDoc);
        SET @valOp = @fgt_tipo_operacion_norm + N' (raw: ' + ISNULL(@fgt_cve_tipo_operacion, '') + N')';
        SET @cumple = CASE WHEN @fgt_tipo_operacion_norm = @valDocNorm THEN 'SI' ELSE 'NO' END;
    END;
    ELSE IF @IdCampo = 5 AND @EsTrafico = 0
    BEGIN
        SET @valOp = @fped_id_regimen;
        SET @cumple = CASE WHEN EXISTS (SELECT 1 FROM @ClavesPed AS c WHERE c.Clave = @fped_id_regimen) THEN 'SI' ELSE 'NO' END;
    END;
    ELSE IF @IdCampo = 5 AND @EsTrafico = 1
    BEGIN
        SET @valOp = @fgt_id_regimen;
        SET @cumple = CASE WHEN EXISTS (SELECT 1 FROM @ClavesPed AS c WHERE c.Clave = @fgt_id_regimen) THEN 'SI' ELSE 'NO' END;
    END;
    ELSE IF @IdCampo = 16 AND @EsTrafico = 0
    BEGIN
        SET @valOp = @fped_aduana_seccion;
        SET @cumple = CASE WHEN @fped_aduana_seccion LIKE '%' + @valDoc + '%' THEN 'SI' ELSE 'NO' END;
    END;
    ELSE IF @IdCampo = 16 AND @EsTrafico = 1
    BEGIN
        SET @valOp = @fgt_aduana_seccion;
        SET @cumple = CASE WHEN @fgt_aduana_seccion LIKE '%' + @valDoc + '%' THEN 'SI' ELSE 'NO' END;
    END;
    ELSE IF @IdCampo = 24 AND @EsTrafico = 0
    BEGIN
        SET @valOp = ISNULL(@fped_aduana_seccion, '') + N' / patente '
                      + ISNULL((SELECT TOP (1) f.id_patente FROM ADUASIS.dbo.fpedimento AS f WITH (NOLOCK) WHERE f.id_referencia = @fped_id_referencia AND f.id_rectificacion = @fped_id_rectificacion), '')
                      + N' / ped. ' + ISNULL(@fped_pedimento, '');
        SET @cumple = CASE
                          WHEN @fped_id_referencia IS NOT NULL
                               AND EXISTS (
                                   SELECT 1
                                   FROM ADUASIS.dbo.fpedimento AS f WITH (NOLOCK)
                                   WHERE f.id_referencia = @fped_id_referencia
                                         AND f.id_rectificacion = @fped_id_rectificacion
                                         AND f.id_aduana = @PedAduana
                                         AND f.id_patente = @PedPatente
                                         AND f.pedimento = @PedNumero
                               ) THEN 'SI'
                          ELSE 'NO'
                      END;
    END;
    ELSE IF @IdCampo = 24 AND @EsTrafico = 1
    BEGIN
        SET @valOp = N'N/A (atajo pedimento no aplica a tráfico)';
        SET @cumple = 'NO';
    END;
    ELSE IF @IdCampo IN ( 6, 7, 8, 9, 10, 12, 13, 20, 21, 23 )
    BEGIN
        IF @EsTrafico = 0 AND @fped_id_referencia IS NOT NULL
        BEGIN
            IF @IdCampo = 6
            BEGIN
                SELECT @valOp = STUFF((
                    SELECT DISTINCT N'; ' + fdt.id_proveedor
                    FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                        INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                    WHERE fgt.id_referencia = @fped_id_referencia AND fgt.id_rectificacion = 0
                    FOR XML PATH(''), TYPE
                ).value('.', 'NVARCHAR(MAX)'), 1, 2, '');
                SET @cumple = CASE WHEN EXISTS (
                    SELECT 1 FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                        INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                    WHERE fgt.id_referencia = @fped_id_referencia AND fgt.id_rectificacion = 0
                          AND fdt.id_proveedor = @valDoc
                ) THEN 'SI' ELSE 'NO' END;
            END;
            ELSE IF @IdCampo = 7
            BEGIN
                SELECT @valOp = STUFF((
                    SELECT DISTINCT N'; ' + fdt.id_producto
                    FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                        INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                    WHERE fgt.id_referencia = @fped_id_referencia AND fgt.id_rectificacion = 0
                    FOR XML PATH(''), TYPE
                ).value('.', 'NVARCHAR(MAX)'), 1, 2, '');
                SET @cumple = CASE WHEN EXISTS (
                    SELECT 1 FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                        INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                    WHERE fgt.id_referencia = @fped_id_referencia AND fgt.id_rectificacion = 0
                          AND fdt.id_producto = @valDoc
                ) THEN 'SI' ELSE 'NO' END;
            END;
            ELSE IF @IdCampo = 8
            BEGIN
                SELECT @valOp = STUFF((
                    SELECT DISTINCT N'; ' + v.txt
                    FROM (
                        SELECT fdt.descripcion_clasificacion AS txt
                        FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                            INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                        WHERE fgt.id_referencia = @fped_id_referencia AND fgt.id_rectificacion = 0
                        UNION
                        SELECT pd.descripcion_fraccion
                        FROM ADUASIS.dbo.fpedimento_detalle AS pd WITH (NOLOCK)
                        WHERE pd.id_referencia = @fped_id_referencia AND pd.id_rectificacion = @fped_id_rectificacion
                    ) AS v
                    WHERE NULLIF(v.txt, '') IS NOT NULL
                    FOR XML PATH(''), TYPE
                ).value('.', 'NVARCHAR(MAX)'), 1, 2, '');
                SET @cumple = CASE WHEN EXISTS (
                    SELECT 1 FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                        INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                    WHERE fgt.id_referencia = @fped_id_referencia AND fgt.id_rectificacion = 0
                          AND fdt.descripcion_clasificacion = @valDoc
                ) OR EXISTS (
                    SELECT 1 FROM ADUASIS.dbo.fpedimento_detalle AS pd WITH (NOLOCK)
                    WHERE pd.id_referencia = @fped_id_referencia AND pd.id_rectificacion = @fped_id_rectificacion
                          AND pd.descripcion_fraccion = @valDoc
                ) THEN 'SI' ELSE 'NO' END;
            END;
            ELSE IF @IdCampo = 9
            BEGIN
                SELECT @valOp = STUFF((
                    SELECT DISTINCT N'; ' + fdt.id_fraccion
                    FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                        INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                    WHERE fgt.id_referencia = @fped_id_referencia AND fgt.id_rectificacion = 0
                    FOR XML PATH(''), TYPE
                ).value('.', 'NVARCHAR(MAX)'), 1, 2, '');
                SET @cumple = CASE WHEN EXISTS (
                    SELECT 1 FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                        INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                        INNER JOIN @Fracciones AS fr ON fdt.id_fraccion LIKE fr.Fraccion + '%'
                    WHERE fgt.id_referencia = @fped_id_referencia AND fgt.id_rectificacion = 0
                ) THEN 'SI' ELSE 'NO' END;
            END;
            ELSE IF @IdCampo = 10
            BEGIN
                SELECT @valOp = STUFF((
                    SELECT DISTINCT N'; ' + CAST(TRY_CONVERT(INT, v.n) AS NVARCHAR(20))
                    FROM (
                        SELECT fdt.nico AS n FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                            INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                        WHERE fgt.id_referencia = @fped_id_referencia AND fgt.id_rectificacion = 0
                        UNION
                        SELECT pd.sub_fraccion FROM ADUASIS.dbo.fpedimento_detalle AS pd WITH (NOLOCK)
                        WHERE pd.id_referencia = @fped_id_referencia AND pd.id_rectificacion = @fped_id_rectificacion
                    ) AS v
                    FOR XML PATH(''), TYPE
                ).value('.', 'NVARCHAR(MAX)'), 1, 2, '');
                SET @cumple = CASE WHEN EXISTS (
                    SELECT 1 FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                        INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                    WHERE fgt.id_referencia = @fped_id_referencia AND fgt.id_rectificacion = 0
                          AND TRY_CONVERT(INT, fdt.nico) = TRY_CONVERT(INT, @valDoc)
                ) OR EXISTS (
                    SELECT 1 FROM ADUASIS.dbo.fpedimento_detalle AS pd WITH (NOLOCK)
                    WHERE pd.id_referencia = @fped_id_referencia AND pd.id_rectificacion = @fped_id_rectificacion
                          AND TRY_CONVERT(INT, pd.sub_fraccion) = TRY_CONVERT(INT, @valDoc)
                ) THEN 'SI' ELSE 'NO' END;
            END;
            ELSE IF @IdCampo = 12
            BEGIN
                SELECT @valOp = STUFF((
                    SELECT DISTINCT N'; ' + fdt.cve_unidad_tarifa
                    FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                        INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                    WHERE fgt.id_referencia = @fped_id_referencia AND fgt.id_rectificacion = 0
                    FOR XML PATH(''), TYPE
                ).value('.', 'NVARCHAR(MAX)'), 1, 2, '');
                SET @cumple = CASE WHEN EXISTS (
                    SELECT 1 FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                        INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                        INNER JOIN @UnidadesUMT AS u ON fdt.cve_unidad_tarifa = u.IdUnidad
                    WHERE fgt.id_referencia = @fped_id_referencia AND fgt.id_rectificacion = 0
                ) OR EXISTS (
                    SELECT 1 FROM @UnidadesUMT AS u
                        INNER JOIN ADUASIS.dbo.fpedimento_detalle AS pd WITH (NOLOCK)
                            ON pd.id_referencia = @fped_id_referencia AND pd.id_rectificacion = @fped_id_rectificacion
                               AND pd.cve_unidad_tarifa = u.IdUnidad
                ) THEN 'SI' ELSE 'NO' END;
            END;
            ELSE IF @IdCampo = 13
            BEGIN
                SELECT @valOp = STUFF((
                    SELECT DISTINCT N'; orig:' + ISNULL(fdt.id_pais_origen, '') + N' vend:' + ISNULL(fdt.id_pais_vendedor, '')
                    FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                        INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                    WHERE fgt.id_referencia = @fped_id_referencia AND fgt.id_rectificacion = 0
                    FOR XML PATH(''), TYPE
                ).value('.', 'NVARCHAR(MAX)'), 1, 2, '');
                SET @cumple = CASE WHEN EXISTS (
                    SELECT 1 FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                        INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                        INNER JOIN @Paises AS p ON fdt.id_pais_origen LIKE '%' + p.Pais + '%' OR fdt.id_pais_vendedor LIKE '%' + p.Pais + '%'
                    WHERE fgt.id_referencia = @fped_id_referencia AND fgt.id_rectificacion = 0
                ) THEN 'SI' ELSE 'NO' END;
            END;
            ELSE IF @IdCampo = 20
            BEGIN
                SELECT @valOp = STUFF((
                    SELECT DISTINCT N'; ' + RTRIM(LTRIM(rel.id_factura))
                    FROM ADUASIS.dbo.frel_pedimento_factura AS rel WITH (NOLOCK)
                    WHERE rel.id_referencia = @fped_id_referencia AND rel.id_rectificacion = @fped_id_rectificacion
                    FOR XML PATH(''), TYPE
                ).value('.', 'NVARCHAR(MAX)'), 1, 2, '');
                SET @cumple = CASE WHEN EXISTS (
                    SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura AS rel WITH (NOLOCK)
                    WHERE rel.id_referencia = @fped_id_referencia AND rel.id_rectificacion = @fped_id_rectificacion
                          AND RTRIM(LTRIM(rel.id_factura)) = @valDoc
                ) THEN 'SI' ELSE 'NO' END;
            END;
            ELSE IF @IdCampo = 21
            BEGIN
                SELECT @valOp = STUFF((
                    SELECT DISTINCT N'; ' + CONVERT(VARCHAR(10), TRY_CONVERT(DATE, rel.fecha_factura), 23)
                    FROM ADUASIS.dbo.frel_pedimento_factura AS rel WITH (NOLOCK)
                    WHERE rel.id_referencia = @fped_id_referencia AND rel.id_rectificacion = @fped_id_rectificacion
                    FOR XML PATH(''), TYPE
                ).value('.', 'NVARCHAR(MAX)'), 1, 2, '');
                SET @cumple = CASE WHEN EXISTS (
                    SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura AS rel WITH (NOLOCK)
                    WHERE rel.id_referencia = @fped_id_referencia AND rel.id_rectificacion = @fped_id_rectificacion
                          AND TRY_CONVERT(DATE, rel.fecha_factura) = TRY_CONVERT(DATE, @valDoc, 23)
                ) THEN 'SI' ELSE 'NO' END;
            END;
            ELSE IF @IdCampo = 23
            BEGIN
                SELECT @valOp = STUFF((
                    SELECT DISTINCT N'; ' + RTRIM(LTRIM(pg.guia))
                    FROM ADUASIS.dbo.fpedimento_guia AS pg WITH (NOLOCK)
                    WHERE pg.id_referencia = @fped_id_referencia AND pg.id_rectificacion = @fped_id_rectificacion
                    FOR XML PATH(''), TYPE
                ).value('.', 'NVARCHAR(MAX)'), 1, 2, '');
                SET @cumple = CASE WHEN EXISTS (
                    SELECT 1 FROM ADUASIS.dbo.fpedimento_guia AS pg WITH (NOLOCK)
                        INNER JOIN @Guias AS g ON RTRIM(LTRIM(pg.guia)) = g.Guia
                    WHERE pg.id_referencia = @fped_id_referencia AND pg.id_rectificacion = @fped_id_rectificacion
                ) THEN 'SI' ELSE 'NO' END;
            END;
        END;
        ELSE IF @EsTrafico = 1
        BEGIN
            IF @IdCampo = 6
            BEGIN
                SELECT @valOp = STUFF((SELECT DISTINCT N'; ' + fdt.id_proveedor FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) WHERE fdt.id_trafico = @fgt_id_trafico FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '');
                SET @cumple = CASE WHEN EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) WHERE fdt.id_trafico = @fgt_id_trafico AND fdt.id_proveedor = @valDoc) THEN 'SI' ELSE 'NO' END;
            END;
            ELSE IF @IdCampo = 7
            BEGIN
                SELECT @valOp = STUFF((SELECT DISTINCT N'; ' + fdt.id_producto FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) WHERE fdt.id_trafico = @fgt_id_trafico FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '');
                SET @cumple = CASE WHEN EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) WHERE fdt.id_trafico = @fgt_id_trafico AND fdt.id_producto = @valDoc) THEN 'SI' ELSE 'NO' END;
            END;
            ELSE IF @IdCampo = 8
            BEGIN
                SELECT @valOp = STUFF((SELECT DISTINCT N'; ' + fdt.descripcion_clasificacion FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) WHERE fdt.id_trafico = @fgt_id_trafico FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '');
                SET @cumple = CASE WHEN EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) WHERE fdt.id_trafico = @fgt_id_trafico AND fdt.descripcion_clasificacion = @valDoc) THEN 'SI' ELSE 'NO' END;
            END;
            ELSE IF @IdCampo = 9
            BEGIN
                SELECT @valOp = STUFF((SELECT DISTINCT N'; ' + fdt.id_fraccion FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) WHERE fdt.id_trafico = @fgt_id_trafico FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '');
                SET @cumple = CASE WHEN EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) INNER JOIN @Fracciones AS fr ON fdt.id_fraccion LIKE fr.Fraccion + '%' WHERE fdt.id_trafico = @fgt_id_trafico) THEN 'SI' ELSE 'NO' END;
            END;
            ELSE IF @IdCampo = 10
            BEGIN
                SELECT @valOp = STUFF((SELECT DISTINCT N'; ' + CAST(TRY_CONVERT(INT, fdt.nico) AS NVARCHAR(20)) FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) WHERE fdt.id_trafico = @fgt_id_trafico FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '');
                SET @cumple = CASE WHEN EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) WHERE fdt.id_trafico = @fgt_id_trafico AND TRY_CONVERT(INT, fdt.nico) = TRY_CONVERT(INT, @valDoc)) THEN 'SI' ELSE 'NO' END;
            END;
            ELSE IF @IdCampo = 12
            BEGIN
                SELECT @valOp = STUFF((SELECT DISTINCT N'; ' + fdt.cve_unidad_tarifa FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) WHERE fdt.id_trafico = @fgt_id_trafico FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '');
                SET @cumple = CASE WHEN EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) INNER JOIN @UnidadesUMT AS u ON fdt.cve_unidad_tarifa = u.IdUnidad WHERE fdt.id_trafico = @fgt_id_trafico) THEN 'SI' ELSE 'NO' END;
            END;
            ELSE IF @IdCampo = 13
            BEGIN
                SELECT @valOp = STUFF((SELECT DISTINCT N'; orig:' + ISNULL(fdt.id_pais_origen, '') + N' vend:' + ISNULL(fdt.id_pais_vendedor, '') FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) WHERE fdt.id_trafico = @fgt_id_trafico FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, '');
                SET @cumple = CASE WHEN EXISTS (SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) INNER JOIN @Paises AS p ON fdt.id_pais_origen LIKE '%' + p.Pais + '%' OR fdt.id_pais_vendedor LIKE '%' + p.Pais + '%' WHERE fdt.id_trafico = @fgt_id_trafico) THEN 'SI' ELSE 'NO' END;
            END;
            ELSE IF @IdCampo = 20
            BEGIN
                SELECT @valOp = STUFF((
                    SELECT DISTINCT N'; ' + RTRIM(LTRIM(fgf.id_factura))
                    FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                        INNER JOIN ADUASIS.dbo.fdfactura AS fdf WITH (NOLOCK) ON fdf.id_entrada = fdt.id_entrada AND fdf.id_cliente = @fgt_id_cliente AND fdf.id_proveedor = fdt.id_proveedor AND fdf.id_producto = fdt.id_producto
                        INNER JOIN ADUASIS.dbo.fgfactura AS fgf WITH (NOLOCK) ON fgf.id_factura = fdf.id_factura AND fgf.id_cliente = fdf.id_cliente AND fgf.id_proveedor = fdf.id_proveedor
                    WHERE fdt.id_trafico = @fgt_id_trafico
                    FOR XML PATH(''), TYPE
                ).value('.', 'NVARCHAR(MAX)'), 1, 2, '');
                SET @cumple = CASE WHEN EXISTS (
                    SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                        INNER JOIN ADUASIS.dbo.fdfactura AS fdf WITH (NOLOCK) ON fdf.id_entrada = fdt.id_entrada AND fdf.id_cliente = @fgt_id_cliente AND fdf.id_proveedor = fdt.id_proveedor AND fdf.id_producto = fdt.id_producto
                        INNER JOIN ADUASIS.dbo.fgfactura AS fgf WITH (NOLOCK) ON fgf.id_factura = fdf.id_factura AND fgf.id_cliente = fdf.id_cliente AND fgf.id_proveedor = fdf.id_proveedor
                    WHERE fdt.id_trafico = @fgt_id_trafico AND RTRIM(LTRIM(fgf.id_factura)) = @valDoc
                ) THEN 'SI' ELSE 'NO' END;
            END;
            ELSE IF @IdCampo = 21
            BEGIN
                SELECT @valOp = STUFF((
                    SELECT DISTINCT N'; ' + CONVERT(VARCHAR(10), TRY_CONVERT(DATE, fgf.fecha_factura), 23)
                    FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                        INNER JOIN ADUASIS.dbo.fdfactura AS fdf WITH (NOLOCK) ON fdf.id_entrada = fdt.id_entrada AND fdf.id_cliente = @fgt_id_cliente AND fdf.id_proveedor = fdt.id_proveedor AND fdf.id_producto = fdt.id_producto
                        INNER JOIN ADUASIS.dbo.fgfactura AS fgf WITH (NOLOCK) ON fgf.id_factura = fdf.id_factura AND fgf.id_cliente = fdf.id_cliente AND fgf.id_proveedor = fdf.id_proveedor
                    WHERE fdt.id_trafico = @fgt_id_trafico
                    FOR XML PATH(''), TYPE
                ).value('.', 'NVARCHAR(MAX)'), 1, 2, '');
                SET @cumple = CASE WHEN EXISTS (
                    SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                        INNER JOIN ADUASIS.dbo.fdfactura AS fdf WITH (NOLOCK) ON fdf.id_entrada = fdt.id_entrada AND fdf.id_cliente = @fgt_id_cliente AND fdf.id_proveedor = fdt.id_proveedor AND fdf.id_producto = fdt.id_producto
                        INNER JOIN ADUASIS.dbo.fgfactura AS fgf WITH (NOLOCK) ON fgf.id_factura = fdf.id_factura AND fgf.id_cliente = fdf.id_cliente AND fgf.id_proveedor = fdf.id_proveedor
                    WHERE fdt.id_trafico = @fgt_id_trafico AND TRY_CONVERT(DATE, fgf.fecha_factura) = TRY_CONVERT(DATE, @valDoc, 23)
                ) THEN 'SI' ELSE 'NO' END;
            END;
            ELSE IF @IdCampo = 23
            BEGIN
                SET @valOp = N'N/A (guía aplica solo a pedimento)';
                SET @cumple = 'NO';
            END;
        END;

        IF @valOp IS NULL
            SET @valOp = N'(sin datos en operación)';
    END;

    INSERT INTO @Cmp (Orden, IdCampo, Campo, ValorObligatorioDocumento, ValorEnOperacion, Cumple)
    VALUES (
        @ord,
        @IdCampo,
        @NombreCampo,
        CASE
            WHEN @IdCampo = 4 THEN @valDoc + N' → norm: ' + @valDocNorm
            ELSE @valDoc
        END,
        @valOp,
        @cumple
    );
    END; /* ELSE atajo 24 */

    FETCH NEXT FROM cur INTO @IdCampo, @NombreCampo, @valDoc;
END;

CLOSE cur;
DEALLOCATE cur;

SELECT c.Orden,
       c.IdCampo,
       c.Campo,
       c.ValorObligatorioDocumento,
       c.ValorEnOperacion,
       c.Cumple
FROM @Cmp AS c
ORDER BY c.Orden;

/* Veredicto: debería aparecer en sugerencia si todo es SI */
SELECT CASE
           WHEN EXISTS (SELECT 1 FROM @Cmp AS c WHERE c.Cumple = 'NO') THEN 'NO_DEBERIA_APARECER'
           ELSE 'DEBERIA_APARECER_EN_SUGERENCIA'
       END AS VeredictoSugerencia,
       SUM(CASE WHEN c.Cumple = 'SI' THEN 1 ELSE 0 END) AS CriteriosCumplidos,
       SUM(CASE WHEN c.Cumple = 'NO' THEN 1 ELSE 0 END) AS CriteriosNoCumplidos,
       SUM(CASE WHEN c.Cumple = 'NA' THEN 1 ELSE 0 END) AS CriteriosOmitidos
FROM @Cmp AS c;
GO
