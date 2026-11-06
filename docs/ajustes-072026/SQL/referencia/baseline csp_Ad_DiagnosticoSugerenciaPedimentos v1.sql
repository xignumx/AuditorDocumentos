/*
  Ajuste 07/2026 — Baseline csp_Ad_DiagnosticoSugerenciaPedimentos
  Definición extraída del servidor 10.46.4.39 (ADUASIS) el 2026-07-02.

  Origen: OBJECT_DEFINITION(OBJECT_ID('dbo.csp_Ad_DiagnosticoSugerenciaPedimentos'))
  Uso: referencia para la modificación pendiente de diagnóstico de sugerencia
       de pedimentos en el marco del ajuste 072026.

  Nota: script de despliegue con CREATE OR ALTER. No modificar docs/SQL/
        hasta promover el ajuste acordado.
*/
USE ADUASIS;
GO

/*
    Diagnóstico orientado al usuario final.

    Entrada obligatoria: cliente del documento, documento auditado y número de pedimento (@pedimento).
    Solo se localiza la operación por el campo pedimento (texto exacto, mismo cliente). No se usa
    referencia/rectificación ni id. de tráfico para buscar.
*/
CREATE OR ALTER PROCEDURE dbo.csp_Ad_DiagnosticoSugerenciaPedimentos
    @idCliente VARCHAR(10),
    @idAdDocumento BIGINT,
    @pedimento VARCHAR(40),
    @clavePedimento VARCHAR(MAX) = '',
    @tipoOperacion VARCHAR(1) = '',
    @tipoPedimento VARCHAR(2) = '',
    @aduana VARCHAR(3) = '',
    @fraccion VARCHAR(MAX) = '',
    @pais VARCHAR(MAX) = ''
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Diag TABLE
    (
        Validacion NVARCHAR(300) NOT NULL,
        Resultado VARCHAR(10) NOT NULL,
        DetalleDocumento NVARCHAR(MAX) NULL,
        DetallePedimento NVARCHAR(MAX) NULL,
        Orden SMALLINT NOT NULL
    );

    IF NULLIF(LTRIM(RTRIM(@idCliente)), '') IS NULL
       OR @idAdDocumento IS NULL
    BEGIN
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        VALUES
        (N'Datos del documento', 'FALLO', N'Falta el cliente o el documento de auditoría para realizar la revisión.', NULL, 1);

        SELECT d.Validacion,
               d.Resultado,
               d.DetalleDocumento,
               d.DetallePedimento
        FROM @Diag AS d
        ORDER BY d.Orden;

        RETURN;
    END;

    DECLARE @pedTrim NVARCHAR(40) = LTRIM(RTRIM(@pedimento));

    IF NULLIF(@pedTrim, N'') IS NULL
    BEGIN
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        VALUES
        (N'Número de pedimento', 'FALLO', N'Debe indicar el número de pedimento que desea revisar.', NULL, 1);

        SELECT d.Validacion,
               d.Resultado,
               d.DetalleDocumento,
               d.DetallePedimento
        FROM @Diag AS d
        ORDER BY d.Orden;

        RETURN;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM ADUASIS.dbo.fpedimento AS f WITH (NOLOCK)
        WHERE f.id_cliente = @idCliente
              AND 
              (RTRIM(LTRIM(f.pedimento)) = @pedTrim
              OR
              CONCAT(f.id_referencia, '/', f.id_rectificacion) = @pedTrim
              OR
              f.id_referencia = @pedTrim
              )
    )
    AND NOT EXISTS
    (
        SELECT 1
        FROM ADUASIS.dbo.fgtrafico AS g WITH (NOLOCK)
        WHERE g.id_trafico = @pedTrim
    )
    BEGIN
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        VALUES
        (N'Operación localizada', 'FALLO', N'Cliente del documento: ' + @idCliente + N'. Pedimento buscado: ' + @pedTrim + N'.',
         N'No hay ninguna operación con ese número de pedimento registrada para su cliente.', 1);

        SELECT d.Validacion,
               d.Resultado,
               d.DetalleDocumento,
               d.DetallePedimento
        FROM @Diag AS d
        ORDER BY d.Orden;

        RETURN;
    END;

    DECLARE @Op_idReferencia VARCHAR(20) = NULL,
            @Op_idRectificacion VARCHAR(5) = NULL;

    SELECT TOP (1)
           @Op_idReferencia = f.id_referencia,
           @Op_idRectificacion = f.id_rectificacion
    FROM ADUASIS.dbo.fpedimento AS f WITH (NOLOCK)
    WHERE f.id_cliente = @idCliente
          AND (
          RTRIM(LTRIM(f.pedimento)) = @pedTrim
          OR
          CONCAT(f.id_referencia, '/', f.id_rectificacion) = @pedTrim
          OR
          f.id_referencia = @pedTrim
          )
    ORDER BY f.fecha_pago DESC;

    DECLARE @Fracciones TABLE
    (
        Fraccion VARCHAR(8)
    );
    DECLARE @Paises TABLE
    (
        Pais VARCHAR(1000)
    );
    DECLARE @ClavesPed TABLE
    (
        Clave VARCHAR(2)
    );

    INSERT INTO @Fracciones
    (
        Fraccion
    )
    SELECT LEFT(splitdata, 8)
    FROM ADUASIS.dbo.FN_SplitSTR(REPLACE(@fraccion, '.', ''), ';');

    INSERT INTO @Paises
    (
        Pais
    )
    SELECT splitdata
    FROM ADUASIS.dbo.FN_SplitSTR(@pais, ';');

    INSERT INTO @ClavesPed
    (
        Clave
    )
    SELECT splitdata
    FROM ADUASIS.dbo.FN_SplitSTR(@clavePedimento, ';');

    IF NOT EXISTS (SELECT 1 FROM @Fracciones)
        INSERT INTO @Fracciones
        (
            Fraccion
        )
        VALUES
        ('');

    IF NOT EXISTS (SELECT 1 FROM @Paises)
        INSERT INTO @Paises
        (
            Pais
        )
        VALUES
        ('');

    DECLARE @clavesDocLista NVARCHAR(500)
        = COALESCE(
    (
        SELECT STUFF(
        (
            SELECT N', ' + LTRIM(RTRIM(cv.Clave))
            FROM @ClavesPed AS cv
            WHERE NULLIF(LTRIM(RTRIM(cv.Clave)), '') IS NOT NULL
            FOR XML PATH(''), TYPE
        ).value(N'.[1]', N'nvarchar(max)'),
               1,
               2,
               N''
              )
    ),
                   N''
                  );
    DECLARE @fraccionesDocLista NVARCHAR(MAX)
        = COALESCE(
    (
        SELECT STUFF(
        (
            SELECT N', ' + LTRIM(RTRIM(fr.Fraccion))
            FROM @Fracciones AS fr
            WHERE NULLIF(LTRIM(RTRIM(fr.Fraccion)), '') IS NOT NULL
            FOR XML PATH(''), TYPE
        ).value(N'.[1]', N'nvarchar(max)'),
               1,
               2,
               N''
              )
    ),
                   N''
                  );
    DECLARE @paisesDocLista NVARCHAR(MAX)
        = COALESCE(
    (
        SELECT STUFF(
        (
            SELECT N', ' + LTRIM(RTRIM(p.Pais))
            FROM @Paises AS p
            WHERE NULLIF(LTRIM(RTRIM(p.Pais)), '') IS NOT NULL
            FOR XML PATH(''), TYPE
        ).value(N'.[1]', N'nvarchar(max)'),
               1,
               2,
               N''
              )
    ),
                   N''
                  );

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
            @fgt_id_tipo_pedimento VARCHAR(10),
            @fgt_id_regimen VARCHAR(10),
            @fgt_aduana_seccion VARCHAR(30);

    DECLARE @IdTraficoDiag VARCHAR(10);

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
    WHERE f.id_referencia = @Op_idReferencia
          AND f.id_rectificacion = @Op_idRectificacion
    ORDER BY f.fecha_pago DESC;

    SELECT TOP (1)
           @fgt_id_trafico = g.id_trafico,
           @fgt_id_cliente = g.id_cliente,
           @fgt_cve_tipo_operacion = g.cve_tipo_operacion,
           @fgt_id_tipo_pedimento = g.id_tipo_pedimento,
           @fgt_id_regimen = g.id_regimen,
           @fgt_aduana_seccion = ISNULL(g.id_aduana, '') + ISNULL(g.seccion_aduana, '')
    FROM ADUASIS.dbo.fgtrafico AS g WITH (NOLOCK)
    WHERE g.id_trafico = @pedTrim;

    SET @IdTraficoDiag = @fgt_id_trafico;

    DECLARE @okClavePedPed BIT,
            @okTipoOpPed BIT,
            @okTipoPedPed BIT,
            @okAduanaPed BIT;

    SET @okClavePedPed
        = CASE
              WHEN @clavePedimento = ''
                   OR EXISTS
        (
            SELECT 1
            FROM @ClavesPed AS cv
            WHERE cv.Clave = @fped_id_regimen
        ) THEN
                  1
              ELSE
                  0
          END;
    SET @okTipoOpPed = CASE WHEN @tipoOperacion = '' OR @fped_cve_tipo_operacion = @tipoOperacion THEN 1 ELSE 0 END;
    SET @okTipoPedPed
        = CASE WHEN ISNUMERIC(@tipoPedimento) = 0 OR @fped_id_tipo_pedimento = @tipoPedimento THEN 1 ELSE 0 END;
    SET @okAduanaPed = CASE WHEN @aduana = '' OR (@fped_aduana_seccion) LIKE '%' + @aduana + '%' THEN 1 ELSE 0 END;

    DECLARE @okClavePedTraf BIT,
            @okTipoOpTraf BIT,
            @okTipoPedTraf BIT,
            @okAduanaTraf BIT;

    SET @okClavePedTraf
        = CASE
              WHEN @clavePedimento = ''
                   OR EXISTS
        (
            SELECT 1
            FROM @ClavesPed AS cv
            WHERE cv.Clave = @fgt_id_regimen
        ) THEN
                  1
              ELSE
                  0
          END;
    SET @okTipoOpTraf = CASE WHEN @tipoOperacion = '' OR @fgt_cve_tipo_operacion = @tipoOperacion THEN 1 ELSE 0 END;
    SET @okTipoPedTraf
        = CASE WHEN ISNUMERIC(@tipoPedimento) = 0 OR @fgt_id_tipo_pedimento = @tipoPedimento THEN 1 ELSE 0 END;
    SET @okAduanaTraf = CASE WHEN @aduana = '' OR (@fgt_aduana_seccion) LIKE '%' + @aduana + '%' THEN 1 ELSE 0 END;

    DECLARE @bloqueOrPed BIT,
            @bloqueOrTraf BIT,
            @cruceFraccionPaisOk BIT,
            @existeOpBloqueoPed BIT,
            @hayParesFracPaisFallo BIT;

    SET @bloqueOrPed
        = CASE
              WHEN (
                       @clavePedimento = ''
                       OR EXISTS
               (
                   SELECT 1
                   FROM @ClavesPed AS cv
                   WHERE cv.Clave = @fped_id_regimen
               )
                   )
                   OR (@tipoOperacion = '' OR @fped_cve_tipo_operacion = @tipoOperacion)
                   OR (ISNUMERIC(@tipoPedimento) = 0 OR @fped_id_tipo_pedimento = @tipoPedimento)
                   OR (@aduana = '' OR (@fped_aduana_seccion) LIKE '%' + @aduana + '%') THEN
                  1
              ELSE
                  0
          END;

    SET @bloqueOrTraf
        = CASE
              WHEN (
                       @clavePedimento = ''
                       OR EXISTS
               (
                   SELECT 1
                   FROM @ClavesPed AS cv
                   WHERE cv.Clave = @fgt_id_regimen
               )
                   )
                   OR (@tipoOperacion = '' OR @fgt_cve_tipo_operacion = @tipoOperacion)
                   OR (ISNUMERIC(@tipoPedimento) = 0 OR @fgt_id_tipo_pedimento = @tipoPedimento)
                   OR (@aduana = '' OR (@fgt_aduana_seccion) LIKE '%' + @aduana + '%') THEN
                  1
              ELSE
                  0
          END;

    IF @IdTraficoDiag IS NOT NULL
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM @Fracciones AS f
                CROSS JOIN @Paises AS p
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                WHERE fdt.id_trafico = @IdTraficoDiag
                      AND fdt.id_fraccion LIKE f.Fraccion + '%'
                      AND
                      (
                          fdt.id_pais_origen LIKE '%' + p.Pais + '%'
                          OR fdt.id_pais_vendedor LIKE '%' + p.Pais + '%'
                      )
            )
        )
            SET @hayParesFracPaisFallo = 1;
        ELSE
            SET @hayParesFracPaisFallo = 0;
    END;
    ELSE IF @fped_id_referencia IS NOT NULL AND @fped_id_rectificacion IS NOT NULL
    BEGIN 
        IF EXISTS
        (
            SELECT 1
            FROM @Fracciones AS f
                CROSS JOIN @Paises AS p
            WHERE NOT EXISTS
            (
                SELECT 1
                FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                INNER JOIN ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                    ON fgt.id_trafico = fdt.id_trafico
                    AND fgt.id_referencia = @fped_id_referencia
                    AND fgt.id_rectificacion = @fped_id_rectificacion
                WHERE fdt.id_fraccion LIKE f.Fraccion + '%'
                      AND
                      (
                          fdt.id_pais_origen LIKE '%' + p.Pais + '%'
                          OR fdt.id_pais_vendedor LIKE '%' + p.Pais + '%'
                      )
            )
        )
            SET @hayParesFracPaisFallo = 1;
        ELSE
            SET @hayParesFracPaisFallo = 0;
    END;
    ELSE
        SET @hayParesFracPaisFallo = 1;

    SET @cruceFraccionPaisOk = CASE WHEN @hayParesFracPaisFallo = 0 THEN 1 ELSE 0 END;

    SET @existeOpBloqueoPed
        = CASE
              WHEN EXISTS
    (
        SELECT 1
        FROM DesarrolloDB.dbo.ad_documento_operacion AS op WITH (NOLOCK)
        WHERE op.IdDocumento = @idAdDocumento
              AND ((
                  op.id_referencia = @fped_id_referencia
                  AND op.id_rectificacion = @fped_id_rectificacion
                  AND op.pedimento = @fped_pedimento
                  )
                  OR
                  op.id_referencia = @fgt_id_trafico
                  AND op.id_rectificacion IS NULL 
                  AND ISNULL(op.pedimento, '') = ''
                  )

    ) THEN
                  1
              ELSE
                  0
          END;

    /* ---------- Resultados ---------- */
    DECLARE @ord SMALLINT = 0;

    IF @fped_id_referencia IS NOT NULL AND @fped_id_rectificacion IS NOT NULL
    BEGIN 
        SET @ord = @ord + 10;
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        SELECT N'Datos de la operación',
               CASE WHEN @fped_id_referencia IS NULL THEN 'FALLO' ELSE 'OK' END,
               CASE WHEN @fped_id_referencia IS NULL THEN N'No fue posible leer la información de la operación.' ELSE NULL END,
               CASE WHEN @fped_id_referencia IS NULL THEN N'Compruebe el número de pedimento.' ELSE NULL END,
               @ord;

        SET @ord = @ord + 10;
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        SELECT N'Cliente de la operación',
               CASE WHEN @fped_id_referencia IS NULL THEN 'NA' WHEN @fped_id_cliente = @idCliente THEN 'OK' ELSE 'FALLO' END,
               CASE WHEN @fped_id_referencia IS NOT NULL AND @fped_id_cliente <> @idCliente THEN N'Cliente del documento: ' + @idCliente ELSE NULL END,
               CASE WHEN @fped_id_referencia IS NOT NULL AND @fped_id_cliente <> @idCliente THEN N'Cliente de la operación: ' + ISNULL(@fped_id_cliente, N'—') ELSE NULL END,
               @ord;

        SET @ord = @ord + 10;
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        SELECT N'Pago en banco',
               CASE WHEN @fped_id_referencia IS NULL THEN 'NA' WHEN @fped_fecha_pago_banco IS NULL THEN 'OK' ELSE 'FALLO' END,
               CASE WHEN @fped_fecha_pago_banco IS NOT NULL THEN N'Para aparecer en sugerencias, la operación no debe tener registrado el pago en banco.' ELSE NULL END,
               CASE WHEN @fped_fecha_pago_banco IS NOT NULL THEN N'La operación tiene fecha de pago en banco: '
                    + CONVERT(NVARCHAR(30), @fped_fecha_pago_banco, 103) ELSE NULL END,
               @ord;

        SET @ord = @ord + 10;
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        SELECT N'Firma en banco',
               CASE WHEN @fped_id_referencia IS NULL THEN 'NA' WHEN @fped_firma_banco IS NULL THEN 'OK' ELSE 'FALLO' END,
               CASE WHEN @fped_firma_banco IS NOT NULL THEN N'Para aparecer en sugerencias, la operación no debe tener registrada la firma en banco.' ELSE NULL END,
               CASE WHEN @fped_firma_banco IS NOT NULL THEN N'La operación tiene firma en banco registrada.' ELSE NULL END,
               @ord;

        SET @ord = @ord + 10;
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        SELECT N'Número de pedimento',
               CASE WHEN @fped_id_referencia IS NULL THEN 'NA' WHEN NULLIF(LTRIM(RTRIM(@fped_pedimento)), '') IS NOT NULL THEN 'OK' ELSE 'FALLO' END,
               CASE WHEN @fped_id_referencia IS NOT NULL AND NULLIF(LTRIM(RTRIM(@fped_pedimento)), '') IS NULL THEN N'La operación debe tener un número de pedimento capturado.' ELSE NULL END,
               CASE WHEN @fped_id_referencia IS NOT NULL AND NULLIF(LTRIM(RTRIM(@fped_pedimento)), '') IS NULL THEN N'El número de pedimento está vacío en la operación.' ELSE NULL END,
               @ord;

        SET @ord = @ord + 10;
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        SELECT N'Asociación con este documento',
               CASE WHEN @fped_id_referencia IS NULL THEN 'NA' WHEN @existeOpBloqueoPed = 0 THEN 'OK' ELSE 'FALLO' END,
               CASE WHEN @existeOpBloqueoPed = 1 THEN N'Documento auditado: ' + CAST(@idAdDocumento AS NVARCHAR(20)) + N'.' ELSE NULL END,
               CASE WHEN @existeOpBloqueoPed = 1 THEN N'Esta operación ya está vinculada a este documento.' ELSE NULL END,
               @ord;

        SET @ord = @ord + 10;
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        SELECT N'Clave de pedimento',
               CASE WHEN @fped_id_referencia IS NULL THEN 'NA' WHEN @clavePedimento = '' THEN 'NA' WHEN @okClavePedPed = 1 THEN 'OK' ELSE 'FALLO' END,
               CASE WHEN @fped_id_referencia IS NOT NULL AND @clavePedimento <> '' AND @okClavePedPed = 0 THEN N'Claves en el documento: '
                    + ISNULL(NULLIF(@clavesDocLista, ''), N'(ninguna)') ELSE NULL END,
               CASE WHEN @fped_id_referencia IS NOT NULL AND @clavePedimento <> '' AND @okClavePedPed = 0 THEN N'Clave en la operación: ' + ISNULL(@fped_id_regimen, N'—') ELSE NULL END,
               @ord;

        SET @ord = @ord + 10;
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        SELECT N'Tipo de operación',
               CASE WHEN @fped_id_referencia IS NULL THEN 'NA' WHEN @tipoOperacion = '' THEN 'NA' WHEN @okTipoOpPed = 1 THEN 'OK' ELSE 'FALLO' END,
               CASE WHEN @fped_id_referencia IS NOT NULL AND @tipoOperacion <> '' AND @okTipoOpPed = 0 THEN N'Tipo indicado en el documento: ' + @tipoOperacion ELSE NULL END,
               CASE WHEN @fped_id_referencia IS NOT NULL AND @tipoOperacion <> '' AND @okTipoOpPed = 0 THEN N'Tipo en la operación: ' + ISNULL(@fped_cve_tipo_operacion, N'—') ELSE NULL END,
               @ord;

        SET @ord = @ord + 10;
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        SELECT N'Tipo de pedimento',
               CASE WHEN @fped_id_referencia IS NULL THEN 'NA' WHEN ISNUMERIC(@tipoPedimento) = 0 THEN 'NA' WHEN @okTipoPedPed = 1 THEN 'OK' ELSE 'FALLO' END,
               CASE WHEN @fped_id_referencia IS NOT NULL AND ISNUMERIC(@tipoPedimento) = 1 AND @okTipoPedPed = 0 THEN N'Tipo de pedimento en el documento: ' + @tipoPedimento ELSE NULL END,
               CASE WHEN @fped_id_referencia IS NOT NULL AND ISNUMERIC(@tipoPedimento) = 1 AND @okTipoPedPed = 0 THEN N'Tipo de pedimento en la operación: ' + ISNULL(@fped_id_tipo_pedimento, N'—') ELSE NULL END,
               @ord;

        SET @ord = @ord + 10;
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        SELECT N'Aduana',
               CASE WHEN @fped_id_referencia IS NULL THEN 'NA' WHEN @aduana = '' THEN 'NA' WHEN @okAduanaPed = 1 THEN 'OK' ELSE 'FALLO' END,
               CASE WHEN @fped_id_referencia IS NOT NULL AND @aduana <> '' AND @okAduanaPed = 0 THEN N'Aduana o sección buscada en el documento: ' + @aduana ELSE NULL END,
               CASE WHEN @fped_id_referencia IS NOT NULL AND @aduana <> '' AND @okAduanaPed = 0 THEN N'Aduana y sección en la operación: ' + ISNULL(@fped_aduana_seccion, N'—') ELSE NULL END,
               @ord;

        SET @ord = @ord + 10;
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        SELECT N'Filtros del documento (clave, tipo, aduana…)',
               CASE WHEN @fped_id_referencia IS NULL THEN 'NA' WHEN @bloqueOrPed = 1 THEN 'OK' ELSE 'FALLO' END,
               CASE WHEN @bloqueOrPed = 0 THEN N'Debe cumplirse al menos una de las condiciones que el documento exige sobre clave de pedimento, tipo de operación, tipo de pedimento o aduana.' ELSE NULL END,
               CASE WHEN @bloqueOrPed = 0 THEN N'Revise las filas anteriores de clave, tipo de operación, tipo de pedimento y aduana.' ELSE NULL END,
               @ord;

        SET @ord = @ord + 10;
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        SELECT N'Fracciones y países en partidas',
               CASE WHEN @fped_id_referencia IS NULL THEN 'NA' WHEN @cruceFraccionPaisOk = 1 THEN 'OK' ELSE 'FALLO' END,
               CASE WHEN @cruceFraccionPaisOk = 0 THEN N'Fracciones en el documento: '
                    + ISNULL(NULLIF(@fraccionesDocLista, ''), N'(ninguna)') + N'. Países en el documento: '
                    + ISNULL(NULLIF(@paisesDocLista, ''), N'(ninguno)') + N'.' ELSE NULL END,
               CASE WHEN @cruceFraccionPaisOk = 0 THEN N'No hay partidas que cumplan todas las combinaciones de fracción y país que pide el documento para esta operación.' ELSE NULL END,
               @ord;
    END;

    IF @fgt_id_trafico IS NOT NULL 
    BEGIN
        SET @ord = @ord + 10;
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        SELECT N'Datos de la operación',
               CASE WHEN @fgt_id_trafico IS NULL THEN 'FALLO' ELSE 'OK' END,
               CASE WHEN @fgt_id_trafico IS NULL THEN N'No fue posible leer la información de la operación.' ELSE NULL END,
               CASE WHEN @fgt_id_trafico IS NULL THEN N'Compruebe el número de tráfico.' ELSE NULL END,
               @ord;

        SET @ord = @ord + 10;
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        SELECT N'Cliente de la operación',
               CASE WHEN @fgt_id_trafico IS NULL THEN 'NA' WHEN @fgt_id_cliente = @idCliente THEN 'OK' ELSE 'FALLO' END,
               CASE WHEN @fgt_id_trafico IS NOT NULL AND @fgt_id_cliente <> @idCliente THEN N'Cliente del documento: ' + @idCliente ELSE NULL END,
               CASE WHEN @fgt_id_trafico IS NOT NULL AND @fgt_id_cliente <> @idCliente THEN N'Cliente de la operación: ' + ISNULL(@fgt_id_cliente, N'—') ELSE NULL END,
               @ord;
       
        SET @ord = @ord + 10;
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        SELECT N'Asociación con este documento',
               CASE WHEN @fgt_id_trafico IS NULL THEN 'NA' WHEN @existeOpBloqueoPed = 0 THEN 'OK' ELSE 'FALLO' END,
               CASE WHEN @existeOpBloqueoPed = 1 THEN N'Documento auditado: ' + CAST(@idAdDocumento AS NVARCHAR(20)) + N'.' ELSE NULL END,
               CASE WHEN @existeOpBloqueoPed = 1 THEN N'Esta operación ya está vinculada a este documento.' ELSE NULL END,
               @ord;

        SET @ord = @ord + 10;
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        SELECT N'Clave de pedimento',
               CASE WHEN @fgt_id_trafico IS NULL THEN 'NA' WHEN @clavePedimento = '' THEN 'NA' WHEN @okClavePedTraf = 1 THEN 'OK' ELSE 'FALLO' END,
               CASE WHEN @fgt_id_trafico IS NOT NULL AND @clavePedimento <> '' AND @okClavePedTraf = 0 THEN N'Claves en el documento: '
                    + ISNULL(NULLIF(@clavesDocLista, ''), N'(ninguna)') ELSE NULL END,
               CASE WHEN @fgt_id_trafico IS NOT NULL AND @clavePedimento <> '' AND @okClavePedTraf = 0 THEN N'Clave en la operación: ' + ISNULL(@fgt_id_regimen, N'—') ELSE NULL END,
               @ord;

        SET @ord = @ord + 10;
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        SELECT N'Tipo de operación',
               CASE WHEN @fgt_id_trafico IS NULL THEN 'NA' WHEN @tipoOperacion = '' THEN 'NA' WHEN @okTipoOpTraf = 1 THEN 'OK' ELSE 'FALLO' END,
               CASE WHEN @fgt_id_trafico IS NOT NULL AND @tipoOperacion <> '' AND @okTipoOpTraf = 0 THEN N'Tipo indicado en el documento: ' + @tipoOperacion ELSE NULL END,
               CASE WHEN @fgt_id_trafico IS NOT NULL AND @tipoOperacion <> '' AND @okTipoOpTraf = 0 THEN N'Tipo en la operación: ' + ISNULL(@fgt_cve_tipo_operacion, N'—') ELSE NULL END,
               @ord;

        SET @ord = @ord + 10;
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        SELECT N'Tipo de pedimento',
               CASE WHEN @fgt_id_trafico IS NULL THEN 'NA' WHEN ISNUMERIC(@tipoPedimento) = 0 THEN 'NA' WHEN @okTipoPedTraf = 1 THEN 'OK' ELSE 'FALLO' END,
               CASE WHEN @fgt_id_trafico IS NOT NULL AND ISNUMERIC(@tipoPedimento) = 1 AND @okTipoPedTraf = 0 THEN N'Tipo de pedimento en el documento: ' + @tipoPedimento ELSE NULL END,
               CASE WHEN @fgt_id_trafico IS NOT NULL AND ISNUMERIC(@tipoPedimento) = 1 AND @okTipoPedTraf = 0 THEN N'Tipo de pedimento en la operación: ' + ISNULL(@fgt_id_tipo_pedimento, N'—') ELSE NULL END,
               @ord;

        SET @ord = @ord + 10;
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        SELECT N'Aduana',
               CASE WHEN @fgt_id_trafico IS NULL THEN 'NA' WHEN @aduana = '' THEN 'NA' WHEN @okAduanaTraf = 1 THEN 'OK' ELSE 'FALLO' END,
               CASE WHEN @fgt_id_trafico IS NOT NULL AND @aduana <> '' AND @okAduanaTraf = 0 THEN N'Aduana o sección buscada en el documento: ' + @aduana ELSE NULL END,
               CASE WHEN @fgt_id_trafico IS NOT NULL AND @aduana <> '' AND @okAduanaTraf = 0 THEN N'Aduana y sección en la operación: ' + ISNULL(@fgt_aduana_seccion, N'—') ELSE NULL END,
               @ord;

        SET @ord = @ord + 10;
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        SELECT N'Filtros del documento (clave, tipo, aduana…)',
               CASE WHEN @fgt_id_trafico IS NULL THEN 'NA' WHEN @bloqueOrTraf = 1 THEN 'OK' ELSE 'FALLO' END,
               CASE WHEN @bloqueOrTraf = 0 THEN N'Debe cumplirse al menos una de las condiciones que el documento exige sobre clave de pedimento, tipo de operación, tipo de pedimento o aduana.' ELSE NULL END,
               CASE WHEN @bloqueOrTraf = 0 THEN N'Revise las filas anteriores de clave, tipo de operación, tipo de pedimento y aduana.' ELSE NULL END,
               @ord;

        SET @ord = @ord + 10;
        INSERT INTO @Diag
        (
            Validacion,
            Resultado,
            DetalleDocumento,
            DetallePedimento,
            Orden
        )
        SELECT N'Fracciones y países en partidas',
               CASE WHEN @fgt_id_trafico IS NULL THEN 'NA' WHEN @cruceFraccionPaisOk = 1 THEN 'OK' ELSE 'FALLO' END,
               CASE WHEN @cruceFraccionPaisOk = 0 AND @fgt_id_trafico IS NOT NULL THEN N'Fracciones en el documento: '
                    + ISNULL(NULLIF(@fraccionesDocLista, ''), N'(ninguna)') + N'. Países en el documento: '
                    + ISNULL(NULLIF(@paisesDocLista, ''), N'(ninguno)') + N'.' ELSE NULL END,
               CASE WHEN @cruceFraccionPaisOk = 0 AND @fgt_id_trafico IS NOT NULL THEN N'No hay partidas que cumplan todas las combinaciones de fracción y país que pide el documento para esta operación.' ELSE NULL END,
               @ord;
    END;


    SELECT d.Validacion,
           d.Resultado,
           d.DetalleDocumento,
           d.DetallePedimento
    FROM @Diag AS d
    ORDER BY d.Orden;
END;
GO

