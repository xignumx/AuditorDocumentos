/*
  Ajuste 07/2026 — CREATE csp_Ad_DiagnosticoSugerenciaPedimentos_v2
  Diagnóstico con filtros desde motor (obligatorio + visible + valor).
  @operacionBusqueda identifica la operación candidata; omitido si atajo Pedimento (24).

  Ejecutar en: ADUASIS
  Referencia: decisiones-filtros-sugerencia-pedimentos.md, baseline 20260702-05
  No modifica csp_Ad_DiagnosticoSugerenciaPedimentos (v1).
*/
USE ADUASIS;
GO

CREATE OR ALTER PROCEDURE dbo.csp_Ad_DiagnosticoSugerenciaPedimentos_v2
    @idCliente VARCHAR(10),
    @idAdDocumento BIGINT,
    @operacionBusqueda VARCHAR(40) = ''
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
        INSERT INTO @Diag (Validacion, Resultado, DetalleDocumento, DetallePedimento, Orden)
        VALUES (N'Datos del documento', 'FALLO', N'Falta el cliente o el documento de auditoría para realizar la revisión.', NULL, 1);

        SELECT d.Validacion, d.Resultado, d.DetalleDocumento, d.DetallePedimento
        FROM @Diag AS d
        ORDER BY d.Orden;
        RETURN;
    END;

    /* --- Filtros activos --- */
    DECLARE @Filtros TABLE (IdCampo INT NOT NULL PRIMARY KEY, Valor NVARCHAR(MAX) NOT NULL);

    INSERT INTO @Filtros (IdCampo, Valor)
    SELECT dcd.IdCampo, LTRIM(RTRIM(dc.Valor))
    FROM DesarrolloDB.dbo.ad_documentos AS d WITH (NOLOCK)
        INNER JOIN DesarrolloDB.dbo.ad_motor_config_detalle AS dcd WITH (NOLOCK)
            ON dcd.IdMotorConfigHeader = d.IdMotorConfigHeader
        INNER JOIN DesarrolloDB.dbo.ad_documentos_campos AS dc WITH (NOLOCK)
            ON dc.IdDocumento = d.Id AND dc.IdCampo = dcd.IdCampo
    WHERE d.Id = @idAdDocumento
          AND dcd.Visible = 1 AND dcd.Obligatorio = 1
          AND NULLIF(LTRIM(RTRIM(dc.Valor)), '') IS NOT NULL
          AND dcd.IdCampo NOT IN (1, 2, 11, 14, 15, 17, 18, 19, 22, 100, 101);

    DECLARE @AtajoPedimento24 BIT = 0;
    DECLARE @ValorPedimento24 VARCHAR(20) = NULL;
    DECLARE @PedAduana VARCHAR(2) = NULL, @PedPatente VARCHAR(4) = NULL, @PedNumero VARCHAR(7) = NULL;

    IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 24)
    BEGIN
        SET @AtajoPedimento24 = 1;
        SELECT @ValorPedimento24 = REPLACE(REPLACE(Valor, ' ', ''), CHAR(9), '') FROM @Filtros WHERE IdCampo = 24;
        IF LEN(@ValorPedimento24) >= 15
        BEGIN
            SET @PedAduana = SUBSTRING(@ValorPedimento24, 3, 2);
            SET @PedPatente = SUBSTRING(@ValorPedimento24, 5, 4);
            SET @PedNumero = SUBSTRING(@ValorPedimento24, 9, 7);
        END;
    END;

    DECLARE @operacionTrim NVARCHAR(40) = LTRIM(RTRIM(@operacionBusqueda));

    IF @AtajoPedimento24 = 0 AND NULLIF(@operacionTrim, N'') IS NULL
    BEGIN
        INSERT INTO @Diag (Validacion, Resultado, DetalleDocumento, DetallePedimento, Orden)
        VALUES (N'Operación a revisar', 'FALLO', N'Debe indicar la operación que desea diagnosticar.', NULL, 1);

        SELECT d.Validacion, d.Resultado, d.DetalleDocumento, d.DetallePedimento FROM @Diag AS d ORDER BY d.Orden;
        RETURN;
    END;

    DECLARE @Op_idReferencia VARCHAR(20) = NULL, @Op_idRectificacion VARCHAR(5) = NULL;

    IF @AtajoPedimento24 = 1 AND @PedNumero IS NOT NULL
    BEGIN
        SELECT TOP (1) @Op_idReferencia = f.id_referencia, @Op_idRectificacion = f.id_rectificacion
        FROM ADUASIS.dbo.fpedimento AS f WITH (NOLOCK)
        WHERE f.id_cliente = @idCliente
              AND f.id_aduana = @PedAduana AND f.id_patente = @PedPatente AND f.pedimento = @PedNumero
        ORDER BY f.fecha_pago DESC;
    END;
    ELSE
    BEGIN
        SELECT TOP (1) @Op_idReferencia = f.id_referencia, @Op_idRectificacion = f.id_rectificacion
        FROM ADUASIS.dbo.fpedimento AS f WITH (NOLOCK)
        WHERE f.id_cliente = @idCliente
              AND (RTRIM(LTRIM(f.pedimento)) = @operacionTrim
                   OR CONCAT(f.id_referencia, '/', f.id_rectificacion) = @operacionTrim
                   OR f.id_referencia = @operacionTrim)
        ORDER BY f.fecha_pago DESC;
    END;

    DECLARE @EsTrafico BIT = 0;
    IF @Op_idReferencia IS NULL
    BEGIN
        IF EXISTS (SELECT 1 FROM ADUASIS.dbo.fgtrafico AS g WITH (NOLOCK) WHERE g.id_trafico = @operacionTrim)
            SET @EsTrafico = 1;
        ELSE IF @AtajoPedimento24 = 0
        BEGIN
            INSERT INTO @Diag (Validacion, Resultado, DetalleDocumento, DetallePedimento, Orden)
            VALUES (N'Operación localizada', 'FALLO',
                    N'Cliente del documento: ' + @idCliente + N'. Operación buscada: ' + @operacionTrim + N'.',
                    N'No hay ninguna operación registrada para su cliente con ese identificador.', 1);

            SELECT d.Validacion, d.Resultado, d.DetalleDocumento, d.DetallePedimento FROM @Diag AS d ORDER BY d.Orden;
            RETURN;
        END;
        ELSE
        BEGIN
            INSERT INTO @Diag (Validacion, Resultado, DetalleDocumento, DetallePedimento, Orden)
            VALUES (N'Operación localizada', 'FALLO',
                    N'Pedimento del documento: ' + ISNULL(@ValorPedimento24, N''),
                    N'No hay pedimento que coincida con aduana/patente/número del documento.', 1);

            SELECT d.Validacion, d.Resultado, d.DetalleDocumento, d.DetallePedimento FROM @Diag AS d ORDER BY d.Orden;
            RETURN;
        END;
    END;

    /* Tablas multivalor desde documento */
    DECLARE @ClavesPed TABLE (Clave VARCHAR(2) NOT NULL);
    DECLARE @Productos TABLE (Producto VARCHAR(1000) NOT NULL);
    DECLARE @Descripciones TABLE (Descripcion NVARCHAR(MAX) NOT NULL);
    DECLARE @Fracciones TABLE (Fraccion VARCHAR(8) NOT NULL);
    DECLARE @Paises TABLE (Pais VARCHAR(1000) NOT NULL);
    DECLARE @Guias TABLE (Guia VARCHAR(100) NOT NULL);
    DECLARE @UnidadesUMT TABLE (IdUnidad VARCHAR(20) NOT NULL PRIMARY KEY);

    IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 5)
        INSERT INTO @ClavesPed (Clave)
        SELECT DISTINCT LTRIM(RTRIM(s.splitdata))
        FROM @Filtros f CROSS APPLY ADUASIS.dbo.FN_SplitSTR(f.Valor, ';') s
        WHERE f.IdCampo = 5
              AND NULLIF(LTRIM(RTRIM(s.splitdata)), '') IS NOT NULL;

    IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 7)
        INSERT INTO @Productos (Producto)
        SELECT DISTINCT REPLACE(LTRIM(RTRIM(s.splitdata)), ' ', '')
        FROM @Filtros f CROSS APPLY ADUASIS.dbo.FN_SplitSTR(f.Valor, ';') s
        WHERE f.IdCampo = 7
              AND NULLIF(REPLACE(LTRIM(RTRIM(s.splitdata)), ' ', ''), '') IS NOT NULL;

    IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 8)
        INSERT INTO @Descripciones (Descripcion)
        SELECT DISTINCT LTRIM(RTRIM(s.splitdata))
        FROM @Filtros f CROSS APPLY ADUASIS.dbo.FN_SplitSTR(f.Valor, ';') s
        WHERE f.IdCampo = 8
              AND NULLIF(LTRIM(RTRIM(s.splitdata)), '') IS NOT NULL;

    IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 9)
        INSERT INTO @Fracciones (Fraccion)
        SELECT DISTINCT LEFT(LTRIM(RTRIM(s.splitdata)), 8)
        FROM @Filtros f CROSS APPLY ADUASIS.dbo.FN_SplitSTR(REPLACE(f.Valor, '.', ''), ';') s
        WHERE f.IdCampo = 9
              AND NULLIF(LEFT(LTRIM(RTRIM(s.splitdata)), 8), '') IS NOT NULL;

    IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 13)
        INSERT INTO @Paises (Pais)
        SELECT DISTINCT LTRIM(RTRIM(s.splitdata))
        FROM @Filtros f CROSS APPLY ADUASIS.dbo.FN_SplitSTR(f.Valor, ';') s
        WHERE f.IdCampo = 13
              AND NULLIF(LTRIM(RTRIM(s.splitdata)), '') IS NOT NULL;

    IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 23)
        INSERT INTO @Guias (Guia)
        SELECT DISTINCT LTRIM(RTRIM(s.splitdata))
        FROM @Filtros f CROSS APPLY ADUASIS.dbo.FN_SplitSTR(f.Valor, ';') s
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
                   OR u.cve_unidad_oficial = LTRIM(RTRIM(s.splitdata))
                   OR u.descripcion LIKE '%' + LTRIM(RTRIM(s.splitdata)) + '%'
                   OR u.desc_abreviada LIKE '%' + LTRIM(RTRIM(s.splitdata)) + '%'
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
                        OR u.cve_unidad_oficial = LTRIM(RTRIM(s.splitdata))
                        OR u.descripcion LIKE '%' + LTRIM(RTRIM(s.splitdata)) + '%'
                        OR u.desc_abreviada LIKE '%' + LTRIM(RTRIM(s.splitdata)) + '%'
              )
              AND NOT EXISTS (
                  SELECT 1
                  FROM @UnidadesUMT AS umt
                  WHERE umt.IdUnidad = LTRIM(RTRIM(s.splitdata))
              );
    END;

    DECLARE @fped_id_cliente VARCHAR(10), @fped_fecha_pago_banco DATE, @fped_firma_banco VARCHAR(10),
            @fped_pedimento VARCHAR(50), @fped_cve_tipo_operacion VARCHAR(10), @fped_id_tipo_pedimento VARCHAR(10),
            @fped_id_regimen VARCHAR(10), @fped_aduana_seccion VARCHAR(20),
            @fped_id_referencia VARCHAR(20), @fped_id_rectificacion VARCHAR(5);

    DECLARE @fgt_id_trafico VARCHAR(10), @fgt_id_cliente VARCHAR(10), @fgt_cve_tipo_operacion VARCHAR(10),
            @fgt_id_tipo_pedimento VARCHAR(10), @fgt_id_regimen VARCHAR(10), @fgt_aduana_seccion VARCHAR(30);

    IF @EsTrafico = 0
    BEGIN
        SELECT TOP (1) @fped_id_cliente = f.id_cliente, @fped_fecha_pago_banco = f.fecha_pago_banco,
               @fped_firma_banco = f.firma_banco, @fped_pedimento = f.pedimento,
               @fped_cve_tipo_operacion = f.cve_tipo_operacion, @fped_id_tipo_pedimento = f.id_tipo_pedimento,
               @fped_id_regimen = f.id_regimen, @fped_aduana_seccion = f.id_aduana + f.seccion,
               @fped_id_referencia = f.id_referencia, @fped_id_rectificacion = f.id_rectificacion
        FROM ADUASIS.dbo.fpedimento AS f WITH (NOLOCK)
        WHERE f.id_referencia = @Op_idReferencia AND f.id_rectificacion = @Op_idRectificacion
        ORDER BY f.fecha_pago DESC;
    END;
    ELSE
    BEGIN
        SELECT TOP (1) @fgt_id_trafico = g.id_trafico, @fgt_id_cliente = g.id_cliente,
               @fgt_cve_tipo_operacion = g.cve_tipo_operacion, @fgt_id_tipo_pedimento = g.id_tipo_pedimento,
               @fgt_id_regimen = g.id_regimen,
               @fgt_aduana_seccion = ISNULL(g.id_aduana, '') + ISNULL(g.seccion_aduana, '')
        FROM ADUASIS.dbo.fgtrafico AS g WITH (NOLOCK)
        WHERE g.id_trafico = @operacionTrim;
    END;

    DECLARE @existeOpBloqueo BIT = CASE
        WHEN EXISTS (
            SELECT 1 FROM DesarrolloDB.dbo.ad_documento_operacion AS op WITH (NOLOCK)
            WHERE op.IdDocumento = @idAdDocumento
                  AND ((op.id_referencia = @fped_id_referencia AND op.id_rectificacion = @fped_id_rectificacion AND op.pedimento = @fped_pedimento)
                       OR (op.id_referencia = @fgt_id_trafico AND op.id_rectificacion IS NULL AND ISNULL(op.pedimento, '') = ''))
        ) THEN 1 ELSE 0 END;

    DECLARE @ord SMALLINT = 0;

    /* ========== Filas fijas operativas (pedimento) ========== */
    IF @EsTrafico = 0
    BEGIN
        SET @ord = @ord + 10;
        INSERT INTO @Diag VALUES (N'Datos de la operación', CASE WHEN @fped_id_referencia IS NULL THEN 'FALLO' ELSE 'OK' END,
            CASE WHEN @fped_id_referencia IS NULL THEN N'No fue posible leer la información de la operación.' ELSE NULL END,
            CASE WHEN @fped_id_referencia IS NULL THEN N'Compruebe el identificador de operación.' ELSE NULL END, @ord);

        SET @ord = @ord + 10;
        INSERT INTO @Diag VALUES (N'Cliente de la operación',
            CASE WHEN @fped_id_referencia IS NULL THEN 'NA' WHEN @fped_id_cliente = @idCliente THEN 'OK' ELSE 'FALLO' END,
            CASE WHEN @fped_id_cliente <> @idCliente THEN N'Cliente del documento: ' + @idCliente ELSE NULL END,
            CASE WHEN @fped_id_cliente <> @idCliente THEN N'Cliente de la operación: ' + ISNULL(@fped_id_cliente, N'—') ELSE NULL END, @ord);

        SET @ord = @ord + 10;
        INSERT INTO @Diag VALUES (N'Pago en banco',
            CASE WHEN @fped_id_referencia IS NULL THEN 'NA' WHEN @fped_fecha_pago_banco IS NULL THEN 'OK' ELSE 'FALLO' END,
            CASE WHEN @fped_fecha_pago_banco IS NOT NULL THEN N'La operación no debe tener pago en banco para aparecer en sugerencias.' ELSE NULL END,
            CASE WHEN @fped_fecha_pago_banco IS NOT NULL THEN N'Fecha pago banco: ' + CONVERT(NVARCHAR(30), @fped_fecha_pago_banco, 103) ELSE NULL END, @ord);

        SET @ord = @ord + 10;
        INSERT INTO @Diag VALUES (N'Firma en banco',
            CASE WHEN @fped_id_referencia IS NULL THEN 'NA' WHEN @fped_firma_banco IS NULL THEN 'OK' ELSE 'FALLO' END,
            CASE WHEN @fped_firma_banco IS NOT NULL THEN N'La operación no debe tener firma en banco para aparecer en sugerencias.' ELSE NULL END,
            CASE WHEN @fped_firma_banco IS NOT NULL THEN N'Firma en banco registrada.' ELSE NULL END, @ord);

        SET @ord = @ord + 10;
        INSERT INTO @Diag VALUES (N'Número de pedimento',
            CASE WHEN @fped_id_referencia IS NULL THEN 'NA' WHEN NULLIF(LTRIM(RTRIM(@fped_pedimento)), '') IS NOT NULL THEN 'OK' ELSE 'FALLO' END,
            CASE WHEN NULLIF(LTRIM(RTRIM(@fped_pedimento)), '') IS NULL THEN N'La operación debe tener número de pedimento.' ELSE NULL END,
            CASE WHEN NULLIF(LTRIM(RTRIM(@fped_pedimento)), '') IS NULL THEN N'Pedimento vacío en la operación.' ELSE NULL END, @ord);

        SET @ord = @ord + 10;
        INSERT INTO @Diag VALUES (N'Asociación con este documento',
            CASE WHEN @fped_id_referencia IS NULL THEN 'NA' WHEN @existeOpBloqueo = 0 THEN 'OK' ELSE 'FALLO' END,
            CASE WHEN @existeOpBloqueo = 1 THEN N'Documento: ' + CAST(@idAdDocumento AS NVARCHAR(20)) ELSE NULL END,
            CASE WHEN @existeOpBloqueo = 1 THEN N'Operación ya vinculada a este documento.' ELSE NULL END, @ord);
    END;

    /* ========== Filas fijas operativas (tráfico) ========== */
    IF @EsTrafico = 1
    BEGIN
        SET @ord = @ord + 10;
        INSERT INTO @Diag VALUES (N'Datos de la operación', CASE WHEN @fgt_id_trafico IS NULL THEN 'FALLO' ELSE 'OK' END,
            CASE WHEN @fgt_id_trafico IS NULL THEN N'No fue posible leer la información del tráfico.' ELSE NULL END, NULL, @ord);

        SET @ord = @ord + 10;
        INSERT INTO @Diag VALUES (N'Cliente de la operación',
            CASE WHEN @fgt_id_trafico IS NULL THEN 'NA' WHEN @fgt_id_cliente = @idCliente THEN 'OK' ELSE 'FALLO' END,
            CASE WHEN @fgt_id_cliente <> @idCliente THEN N'Cliente del documento: ' + @idCliente ELSE NULL END,
            CASE WHEN @fgt_id_cliente <> @idCliente THEN N'Cliente del tráfico: ' + ISNULL(@fgt_id_cliente, N'—') ELSE NULL END, @ord);

        SET @ord = @ord + 10;
        INSERT INTO @Diag VALUES (N'Asociación con este documento',
            CASE WHEN @fgt_id_trafico IS NULL THEN 'NA' WHEN @existeOpBloqueo = 0 THEN 'OK' ELSE 'FALLO' END,
            CASE WHEN @existeOpBloqueo = 1 THEN N'Documento: ' + CAST(@idAdDocumento AS NVARCHAR(20)) ELSE NULL END,
            CASE WHEN @existeOpBloqueo = 1 THEN N'Tráfico ya vinculado a este documento.' ELSE NULL END, @ord);
    END;

    /* ========== Validaciones por campo activo (AND) ========== */
    DECLARE @IdCampo INT, @ValorCampo NVARCHAR(MAX), @NombreCampo NVARCHAR(100);
    DECLARE @ok BIT, @detDoc NVARCHAR(MAX), @detOp NVARCHAR(MAX);

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT f.IdCampo, f.Valor, dcd.NombreCampo
        FROM @Filtros f
            INNER JOIN DesarrolloDB.dbo.ad_documentos AS d WITH (NOLOCK)
                ON d.Id = @idAdDocumento
            INNER JOIN DesarrolloDB.dbo.ad_motor_config_detalle AS dcd WITH (NOLOCK)
                ON dcd.IdMotorConfigHeader = d.IdMotorConfigHeader AND dcd.IdCampo = f.IdCampo
        ORDER BY f.IdCampo;

    OPEN cur;
    FETCH NEXT FROM cur INTO @IdCampo, @ValorCampo, @NombreCampo;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @ok = 0; SET @detDoc = NULL; SET @detOp = NULL;
        SET @ord = @ord + 10;

        IF @IdCampo = 4
        BEGIN
            SET @ValorCampo = dbo.FN_Ad_NormalizarTipoOperacion(@ValorCampo);
        END;

        IF @IdCampo = 3 AND @EsTrafico = 0
        BEGIN
            SET @ok = CASE WHEN @fped_id_tipo_pedimento = @ValorCampo THEN 1 ELSE 0 END;
            IF @ok = 0 SET @detDoc = N'Valor documento: ' + @ValorCampo;
            IF @ok = 0 SET @detOp = N'Valor operación: ' + ISNULL(@fped_id_tipo_pedimento, N'—');
        END;
        ELSE IF @IdCampo = 3 AND @EsTrafico = 1
        BEGIN
            SET @ok = CASE WHEN @fgt_id_tipo_pedimento = @ValorCampo THEN 1 ELSE 0 END;
            IF @ok = 0 SET @detDoc = N'Valor documento: ' + @ValorCampo;
            IF @ok = 0 SET @detOp = N'Valor tráfico: ' + ISNULL(@fgt_id_tipo_pedimento, N'—');
        END;
        ELSE IF @IdCampo = 4 AND @EsTrafico = 0
        BEGIN
            SET @ok = CASE WHEN @fped_cve_tipo_operacion = @ValorCampo THEN 1 ELSE 0 END;
            IF @ok = 0 SET @detDoc = N'Valor documento: ' + @ValorCampo;
            IF @ok = 0 SET @detOp = N'Valor operación: ' + ISNULL(@fped_cve_tipo_operacion, N'—');
        END;
        ELSE IF @IdCampo = 4 AND @EsTrafico = 1
        BEGIN
            SET @ok = CASE WHEN CASE WHEN @fgt_cve_tipo_operacion = '0' THEN '1' WHEN @fgt_cve_tipo_operacion = '1' THEN '2' ELSE '' END = @ValorCampo THEN 1 ELSE 0 END;
            IF @ok = 0 SET @detDoc = N'Valor documento: ' + @ValorCampo;
            IF @ok = 0 SET @detOp = N'Valor tráfico (convertido): ' + ISNULL(@fgt_cve_tipo_operacion, N'—');
        END;
        ELSE IF @IdCampo = 5 AND @EsTrafico = 0
        BEGIN
            SET @ok = CASE WHEN EXISTS (SELECT 1 FROM @ClavesPed c WHERE c.Clave = @fped_id_regimen) THEN 1 ELSE 0 END;
            IF @ok = 0 SET @detDoc = N'Claves documento: ' + @ValorCampo;
            IF @ok = 0 SET @detOp = N'Clave operación: ' + ISNULL(@fped_id_regimen, N'—');
        END;
        ELSE IF @IdCampo = 5 AND @EsTrafico = 1
        BEGIN
            SET @ok = CASE WHEN EXISTS (SELECT 1 FROM @ClavesPed c WHERE c.Clave = @fgt_id_regimen) THEN 1 ELSE 0 END;
            IF @ok = 0 SET @detDoc = N'Claves documento: ' + @ValorCampo;
            IF @ok = 0 SET @detOp = N'Clave tráfico: ' + ISNULL(@fgt_id_regimen, N'—');
        END;
        ELSE IF @IdCampo = 16 AND @EsTrafico = 0
        BEGIN
            SET @ok = CASE WHEN @fped_aduana_seccion LIKE '%' + @ValorCampo + '%' THEN 1 ELSE 0 END;
            IF @ok = 0 SET @detDoc = N'Aduana documento: ' + @ValorCampo;
            IF @ok = 0 SET @detOp = N'Aduana operación: ' + ISNULL(@fped_aduana_seccion, N'—');
        END;
        ELSE IF @IdCampo = 16 AND @EsTrafico = 1
        BEGIN
            SET @ok = CASE WHEN @fgt_aduana_seccion LIKE '%' + @ValorCampo + '%' THEN 1 ELSE 0 END;
            IF @ok = 0 SET @detDoc = N'Aduana documento: ' + @ValorCampo;
            IF @ok = 0 SET @detOp = N'Aduana tráfico: ' + ISNULL(@fgt_aduana_seccion, N'—');
        END;
        ELSE IF @IdCampo = 24 AND @EsTrafico = 0
        BEGIN
            SET @ok = CASE
                WHEN EXISTS (
                    SELECT 1
                    FROM ADUASIS.dbo.fpedimento AS f WITH (NOLOCK)
                    WHERE f.id_referencia = @fped_id_referencia
                          AND f.id_rectificacion = @fped_id_rectificacion
                          AND f.id_aduana = @PedAduana
                          AND f.id_patente = @PedPatente
                          AND f.pedimento = @PedNumero
                ) THEN 1
                ELSE 0
            END;
            IF @ok = 0 SET @detDoc = N'Pedimento documento: ' + @ValorPedimento24;
            IF @ok = 0 SET @detOp = N'No coincide aduana/patente/número con la operación.';
        END;
        ELSE IF @IdCampo IN (6, 7, 8, 9, 10, 12, 13, 20, 21, 23)
        BEGIN
            /*
              Validación partida por campo (no EXISTS monolítico con @IdCampo <> X OR ...).
              Ese patrón obliga al optimizador a planes genéricos sobre fdtrafico (~tens of millions)
              y puede tardar minutos por cada campo activo.
              Tráfico de pedimento: fgt.id_rectificacion = 0 (misma regla que csp_Ad_SugerenciaPedimentos_v2).
            */
            IF @EsTrafico = 0 AND @fped_id_referencia IS NOT NULL
            BEGIN
                IF @IdCampo = 6
                    SET @ok = CASE WHEN EXISTS (
                        SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
                            INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                        WHERE fgt.id_referencia = @fped_id_referencia AND fgt.id_rectificacion = 0
                              AND fdt.id_proveedor = @ValorCampo
                    ) THEN 1 ELSE 0 END;
                ELSE IF @IdCampo = 7
                    SET @ok = CASE WHEN EXISTS (
                        SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
                            INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                            INNER JOIN @Productos pr ON REPLACE(fdt.id_producto, ' ', '') = pr.Producto
                        WHERE fgt.id_referencia = @fped_id_referencia AND fgt.id_rectificacion = 0
                    ) THEN 1 ELSE 0 END;
                ELSE IF @IdCampo = 8
                    SET @ok = CASE WHEN EXISTS (
                        SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
                            INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                            INNER JOIN @Descripciones d ON fdt.descripcion_clasificacion = d.Descripcion
                        WHERE fgt.id_referencia = @fped_id_referencia AND fgt.id_rectificacion = 0
                    ) OR EXISTS (
                        SELECT 1 FROM ADUASIS.dbo.fpedimento_detalle pd WITH (NOLOCK)
                            INNER JOIN @Descripciones d ON pd.descripcion_fraccion = d.Descripcion
                        WHERE pd.id_referencia = @fped_id_referencia AND pd.id_rectificacion = @fped_id_rectificacion
                    ) THEN 1 ELSE 0 END;
                ELSE IF @IdCampo = 9
                    SET @ok = CASE WHEN EXISTS (
                        SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
                            INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                            INNER JOIN @Fracciones fr ON fdt.id_fraccion LIKE fr.Fraccion + '%'
                        WHERE fgt.id_referencia = @fped_id_referencia AND fgt.id_rectificacion = 0
                    ) THEN 1 ELSE 0 END;
                ELSE IF @IdCampo = 10
                    SET @ok = CASE WHEN EXISTS (
                        SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
                            INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                        WHERE fgt.id_referencia = @fped_id_referencia AND fgt.id_rectificacion = 0
                              AND TRY_CONVERT(INT, fdt.nico) = TRY_CONVERT(INT, @ValorCampo)
                    ) OR EXISTS (
                        SELECT 1 FROM ADUASIS.dbo.fpedimento_detalle pd WITH (NOLOCK)
                        WHERE pd.id_referencia = @fped_id_referencia AND pd.id_rectificacion = @fped_id_rectificacion
                              AND TRY_CONVERT(INT, pd.sub_fraccion) = TRY_CONVERT(INT, @ValorCampo)
                    ) THEN 1 ELSE 0 END;
                ELSE IF @IdCampo = 12
                    SET @ok = CASE WHEN EXISTS (
                        SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
                            INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                            INNER JOIN @UnidadesUMT u ON fdt.id_unidad_universal = u.IdUnidad
                                                      OR fdt.cve_unidad_tarifa = u.IdUnidad
                        WHERE fgt.id_referencia = @fped_id_referencia AND fgt.id_rectificacion = 0
                    ) OR EXISTS (
                        SELECT 1 FROM @UnidadesUMT u
                            INNER JOIN ADUASIS.dbo.fpedimento_detalle pd WITH (NOLOCK)
                                ON pd.id_referencia = @fped_id_referencia
                                   AND pd.id_rectificacion = @fped_id_rectificacion
                                   AND (pd.id_unidad_universal = u.IdUnidad OR pd.cve_unidad_tarifa = u.IdUnidad)
                    ) THEN 1 ELSE 0 END;
                ELSE IF @IdCampo = 13
                    SET @ok = CASE WHEN EXISTS (
                        SELECT 1 FROM ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
                            INNER JOIN ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                            INNER JOIN @Paises p ON fdt.id_pais_origen LIKE '%' + p.Pais + '%'
                                                   OR fdt.id_pais_vendedor LIKE '%' + p.Pais + '%'
                        WHERE fgt.id_referencia = @fped_id_referencia AND fgt.id_rectificacion = 0
                    ) THEN 1 ELSE 0 END;
                ELSE IF @IdCampo = 20
                    SET @ok = CASE WHEN EXISTS (
                        SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura rel WITH (NOLOCK)
                        WHERE rel.id_referencia = @fped_id_referencia AND rel.id_rectificacion = @fped_id_rectificacion
                              AND RTRIM(LTRIM(rel.id_factura)) = @ValorCampo
                    ) THEN 1 ELSE 0 END;
                ELSE IF @IdCampo = 21
                    SET @ok = CASE WHEN EXISTS (
                        SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura rel WITH (NOLOCK)
                        WHERE rel.id_referencia = @fped_id_referencia AND rel.id_rectificacion = @fped_id_rectificacion
                              AND TRY_CONVERT(DATE, rel.fecha_factura) = TRY_CONVERT(DATE, @ValorCampo, 23)
                    ) THEN 1 ELSE 0 END;
                ELSE IF @IdCampo = 23
                    SET @ok = CASE WHEN EXISTS (
                        SELECT 1 FROM ADUASIS.dbo.fpedimento_guia pg WITH (NOLOCK)
                            INNER JOIN @Guias g ON RTRIM(LTRIM(pg.guia)) = g.Guia
                        WHERE pg.id_referencia = @fped_id_referencia AND pg.id_rectificacion = @fped_id_rectificacion
                    ) THEN 1 ELSE 0 END;
            END;
            ELSE IF @EsTrafico = 1
            BEGIN
                IF @IdCampo = 6
                    SET @ok = CASE WHEN EXISTS (
                        SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                        WHERE fdt.id_trafico = @fgt_id_trafico AND fdt.id_proveedor = @ValorCampo
                    ) THEN 1 ELSE 0 END;
                ELSE IF @IdCampo = 7
                    SET @ok = CASE WHEN EXISTS (
                        SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                            INNER JOIN @Productos pr ON REPLACE(fdt.id_producto, ' ', '') = pr.Producto
                        WHERE fdt.id_trafico = @fgt_id_trafico
                    ) THEN 1 ELSE 0 END;
                ELSE IF @IdCampo = 8
                    SET @ok = CASE WHEN EXISTS (
                        SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                            INNER JOIN @Descripciones d ON fdt.descripcion_clasificacion = d.Descripcion
                        WHERE fdt.id_trafico = @fgt_id_trafico
                    ) THEN 1 ELSE 0 END;
                ELSE IF @IdCampo = 9
                    SET @ok = CASE WHEN EXISTS (
                        SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                            INNER JOIN @Fracciones fr ON fdt.id_fraccion LIKE fr.Fraccion + '%'
                        WHERE fdt.id_trafico = @fgt_id_trafico
                    ) THEN 1 ELSE 0 END;
                ELSE IF @IdCampo = 10
                    SET @ok = CASE WHEN EXISTS (
                        SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                        WHERE fdt.id_trafico = @fgt_id_trafico
                              AND TRY_CONVERT(INT, fdt.nico) = TRY_CONVERT(INT, @ValorCampo)
                    ) THEN 1 ELSE 0 END;
                ELSE IF @IdCampo = 12
                    SET @ok = CASE WHEN EXISTS (
                        SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                            INNER JOIN @UnidadesUMT u ON fdt.id_unidad_universal = u.IdUnidad
                                                      OR fdt.cve_unidad_tarifa = u.IdUnidad
                        WHERE fdt.id_trafico = @fgt_id_trafico
                    ) THEN 1 ELSE 0 END;
                ELSE IF @IdCampo = 13
                    SET @ok = CASE WHEN EXISTS (
                        SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                            INNER JOIN @Paises p ON fdt.id_pais_origen LIKE '%' + p.Pais + '%'
                                                   OR fdt.id_pais_vendedor LIKE '%' + p.Pais + '%'
                        WHERE fdt.id_trafico = @fgt_id_trafico
                    ) THEN 1 ELSE 0 END;
                ELSE IF @IdCampo = 20
                    SET @ok = CASE WHEN EXISTS (
                        SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                            INNER JOIN ADUASIS.dbo.fdfactura fdf WITH (NOLOCK)
                                ON fdf.id_entrada = fdt.id_entrada
                                   AND fdf.id_cliente = @fgt_id_cliente
                                   AND fdf.id_proveedor = fdt.id_proveedor
                                   AND fdf.id_producto = fdt.id_producto
                            INNER JOIN ADUASIS.dbo.fgfactura fgf WITH (NOLOCK)
                                ON fgf.id_factura = fdf.id_factura
                                   AND fgf.id_cliente = fdf.id_cliente
                                   AND fgf.id_proveedor = fdf.id_proveedor
                        WHERE fdt.id_trafico = @fgt_id_trafico
                              AND RTRIM(LTRIM(fgf.id_factura)) = @ValorCampo
                    ) THEN 1 ELSE 0 END;
                ELSE IF @IdCampo = 21
                    SET @ok = CASE WHEN EXISTS (
                        SELECT 1 FROM ADUASIS.dbo.fdtrafico fdt WITH (NOLOCK)
                            INNER JOIN ADUASIS.dbo.fdfactura fdf WITH (NOLOCK)
                                ON fdf.id_entrada = fdt.id_entrada
                                   AND fdf.id_cliente = @fgt_id_cliente
                                   AND fdf.id_proveedor = fdt.id_proveedor
                                   AND fdf.id_producto = fdt.id_producto
                            INNER JOIN ADUASIS.dbo.fgfactura fgf WITH (NOLOCK)
                                ON fgf.id_factura = fdf.id_factura
                                   AND fgf.id_cliente = fdf.id_cliente
                                   AND fgf.id_proveedor = fdf.id_proveedor
                        WHERE fdt.id_trafico = @fgt_id_trafico
                              AND TRY_CONVERT(DATE, fgf.fecha_factura) = TRY_CONVERT(DATE, @ValorCampo, 23)
                    ) THEN 1 ELSE 0 END;
            END;
            IF @ok = 0 SET @detDoc = N'Valor documento: ' + @ValorCampo;
            IF @ok = 0 SET @detOp = N'No se encontró coincidencia en la operación para este criterio.';
        END;

        INSERT INTO @Diag (Validacion, Resultado, DetalleDocumento, DetallePedimento, Orden)
        VALUES (@NombreCampo, CASE WHEN @ok = 1 THEN 'OK' ELSE 'FALLO' END, @detDoc, @detOp, @ord);

        FETCH NEXT FROM cur INTO @IdCampo, @ValorCampo, @NombreCampo;
    END;

    CLOSE cur;
    DEALLOCATE cur;

    SELECT d.Validacion, d.Resultado, d.DetalleDocumento, d.DetallePedimento
    FROM @Diag AS d
    ORDER BY d.Orden;
END;
GO
