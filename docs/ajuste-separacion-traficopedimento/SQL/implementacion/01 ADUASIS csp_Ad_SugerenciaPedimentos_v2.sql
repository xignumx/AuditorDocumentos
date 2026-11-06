/*
  Ajuste separación tráfico/pedimento — CREATE OR ALTER csp_Ad_SugerenciaPedimentos_v2
  Base: docs/ajustes-072026/SQL/implementacion/05 (v3 materialized).

  Cambio de negocio:
    - La rama de tráfico YA NO exige ausencia de pedimento (se retira el NOT EXISTS
      contra fpedimento por id_cliente + id_referencia + id_rectificacion).
    - Pueden coexistir en resultados un pedimento (referencia/rectificación) y su
      tráfico (id_trafico sin diagonal), aunque ya estén relacionados en ADUASIS.
    - Atajo Pedimento (24): sin cambio (solo fpedimento; sin rama tráfico).
    - Resto de filtros (pago/firma banco, @OpsExcluidas, motor AND, etc.): sin cambio.

  Optimización plan (2026-10-13):
    - OPTION (RECOMPILE) solo en INSERT de rama TRAFICO cuando operacionBusqueda va vacia.
      Pedimento: sin RECOMPILE (no era el cuello). Con busqueda: sin RECOMPILE (mejor latencia).
    - Evidencia: docs/.../SQL/pruebas/03 y 04

  Ejecutar en: ADUASIS
  Carpeta: docs/ajuste-separacion-traficopedimento/
*/
USE ADUASIS;
GO

CREATE OR ALTER PROCEDURE dbo.csp_Ad_SugerenciaPedimentos_v2
    @idCliente VARCHAR(10),
    @idAdDocumento BIGINT,
    @operacionBusqueda VARCHAR(40) = '',
    @PageNumber INT = 1,
    @PageSize INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    SET @PageNumber = ISNULL(@PageNumber, 1);
    SET @PageSize = ISNULL(@PageSize, 10);
    IF @PageNumber < 1
        SET @PageNumber = 1;
    IF @PageSize < 1
        SET @PageSize = 10;
    IF @PageSize > 100
        SET @PageSize = 100;

    DECLARE @Offset INT;
    SET @Offset = (@PageNumber - 1) * @PageSize;
    DECLARE @RowEnd INT;
    SET @RowEnd = @Offset + @PageSize;
    DECLARE @TotalRecords INT = 0;
    DECLARE @operacionBusquedaTrim VARCHAR(40) = LTRIM(RTRIM(ISNULL(@operacionBusqueda, '')));
    /* Formato UI típico: id_referencia/id_rectificacion (p.ej. EXP-29063/0), igual que el diagnóstico. */
    DECLARE @BusqEsRefRect BIT = 0;
    DECLARE @BusqReferencia VARCHAR(40) = NULL;
    DECLARE @BusqRectificacion INT = NULL;
    IF CHARINDEX('/', @operacionBusquedaTrim) > 1
    BEGIN
        SET @BusqReferencia = LEFT(@operacionBusquedaTrim, CHARINDEX('/', @operacionBusquedaTrim) - 1);
        SET @BusqRectificacion = TRY_CONVERT(INT, SUBSTRING(@operacionBusquedaTrim, CHARINDEX('/', @operacionBusquedaTrim) + 1, 40));
        IF NULLIF(LTRIM(RTRIM(@BusqReferencia)), '') IS NOT NULL AND @BusqRectificacion IS NOT NULL
            SET @BusqEsRefRect = 1;
    END;

    /* --- Filtros activos: obligatorio + visible + valor en documento --- */
    DECLARE @Filtros TABLE
    (
        IdCampo INT NOT NULL PRIMARY KEY,
        Valor NVARCHAR(MAX) NOT NULL
    );

    INSERT INTO @Filtros (IdCampo, Valor)
    SELECT
        dcd.IdCampo,
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

    /* --- Atajo Pedimento (24) --- */
    DECLARE @AtajoPedimento24 BIT = 0;
    DECLARE @ValorPedimento24 VARCHAR(20) = NULL;

    IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 24)
    BEGIN
        SET @AtajoPedimento24 = 1;
        SELECT @ValorPedimento24 = REPLACE(Valor, ' ', '')
        FROM @Filtros
        WHERE IdCampo = 24;
        SET @ValorPedimento24 = REPLACE(@ValorPedimento24, CHAR(9), '');
    END;

    DECLARE @PedAduana VARCHAR(2) = NULL,
            @PedPatente VARCHAR(4) = NULL,
            @PedNumero VARCHAR(7) = NULL;

    IF @AtajoPedimento24 = 1 AND LEN(@ValorPedimento24) >= 15
    BEGIN
        SET @PedAduana = SUBSTRING(@ValorPedimento24, 3, 2);
        SET @PedPatente = SUBSTRING(@ValorPedimento24, 5, 4);
        SET @PedNumero = SUBSTRING(@ValorPedimento24, 9, 7);
    END;

    /* --- Variables por campo (solo rama normal) --- */
    DECLARE @ActTipoPedimento BIT = 0,
            @ValTipoPedimento VARCHAR(2) = NULL,
            @ActTipoOperacion BIT = 0,
            @ValTipoOperacion VARCHAR(1) = NULL,
            @ActClavePedimento BIT = 0,
            @ActProveedor BIT = 0,
            @ValProveedor VARCHAR(50) = NULL,
            @ActProducto BIT = 0,
            @ActDescripcion BIT = 0,
            @ActFracciones BIT = 0,
            @ActNico BIT = 0,
            @ValNico VARCHAR(20) = NULL,
            @ActUMT BIT = 0,
            @ActPais BIT = 0,
            @ActAduana BIT = 0,
            @ValAduana VARCHAR(10) = NULL,
            @ActFactura BIT = 0,
            @ValFactura VARCHAR(50) = NULL,
            @ActFechaFactura BIT = 0,
            @ValFechaFactura DATE = NULL,
            @ActGuiaBl BIT = 0;

    DECLARE @ClavesPed TABLE (Clave VARCHAR(2) NOT NULL PRIMARY KEY);
    DECLARE @Productos TABLE (Producto VARCHAR(1000) NOT NULL);
    DECLARE @Descripciones TABLE (Descripcion NVARCHAR(MAX) NOT NULL);
    DECLARE @Fracciones TABLE (Fraccion VARCHAR(8) NOT NULL PRIMARY KEY);
    DECLARE @Paises TABLE (Pais VARCHAR(1000) NOT NULL);
    DECLARE @Guias TABLE (Guia VARCHAR(100) NOT NULL PRIMARY KEY);

    DECLARE @UnidadesUMT TABLE (IdUnidad VARCHAR(20) NOT NULL PRIMARY KEY);

    DECLARE @HayFiltroTrafico BIT = 0;

    DECLARE @OpsExcluidas TABLE
    (
        id_referencia VARCHAR(50) NOT NULL,
        id_rectificacion INT NULL,
        pedimento VARCHAR(50) NULL,
        es_trafico_sin_ped BIT NOT NULL,
        INDEX IX_OpsExcluidas CLUSTERED (id_referencia, id_rectificacion, pedimento)
    );

    IF @AtajoPedimento24 = 0
    BEGIN
        IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 3)
        BEGIN
            SET @ActTipoPedimento = 1;
            SELECT @ValTipoPedimento = Valor FROM @Filtros WHERE IdCampo = 3;
        END;
        IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 4)
        BEGIN
            SET @ActTipoOperacion = 1;
            /* Normalizar desde Valor completo: @ValTipoOperacion es VARCHAR(1) y truncaría
               'importacion'→'i' antes de FN_Ad_NormalizarTipoOperacion (diag OK / sugerencia 0). */
            SELECT @ValTipoOperacion = dbo.FN_Ad_NormalizarTipoOperacion(Valor)
            FROM @Filtros
            WHERE IdCampo = 4;
        END;
        IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 5)
        BEGIN
            SET @ActClavePedimento = 1;
            INSERT INTO @ClavesPed (Clave)
            SELECT DISTINCT LTRIM(RTRIM(splitdata))
            FROM DesarrolloDB.dbo.ad_documentos_campos AS dc
                CROSS APPLY ADUASIS.dbo.FN_SplitSTR(dc.Valor, ';')
            WHERE dc.IdDocumento = @idAdDocumento
                  AND dc.IdCampo = 5
                  AND NULLIF(LTRIM(RTRIM(splitdata)), '') IS NOT NULL;
        END;
        IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 6)
        BEGIN
            SET @ActProveedor = 1;
            SELECT @ValProveedor = Valor FROM @Filtros WHERE IdCampo = 6;
        END;
        IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 7)
        BEGIN
            SET @ActProducto = 1;
            /* Normalizar espacios en no. de parte: 'F-...-001 1' ≈ 'F-...-0011' */
            INSERT INTO @Productos (Producto)
            SELECT DISTINCT REPLACE(LTRIM(RTRIM(splitdata)), ' ', '')
            FROM DesarrolloDB.dbo.ad_documentos_campos AS dc
                CROSS APPLY ADUASIS.dbo.FN_SplitSTR(dc.Valor, ';')
            WHERE dc.IdDocumento = @idAdDocumento
                  AND dc.IdCampo = 7
                  AND NULLIF(REPLACE(LTRIM(RTRIM(splitdata)), ' ', ''), '') IS NOT NULL;
        END;
        IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 8)
        BEGIN
            SET @ActDescripcion = 1;
            INSERT INTO @Descripciones (Descripcion)
            SELECT DISTINCT LTRIM(RTRIM(splitdata))
            FROM DesarrolloDB.dbo.ad_documentos_campos AS dc
                CROSS APPLY ADUASIS.dbo.FN_SplitSTR(dc.Valor, ';')
            WHERE dc.IdDocumento = @idAdDocumento
                  AND dc.IdCampo = 8
                  AND NULLIF(LTRIM(RTRIM(splitdata)), '') IS NOT NULL;
        END;
        IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 9)
        BEGIN
            SET @ActFracciones = 1;
            INSERT INTO @Fracciones (Fraccion)
            SELECT DISTINCT LEFT(LTRIM(RTRIM(splitdata)), 8)
            FROM DesarrolloDB.dbo.ad_documentos_campos AS dc
                CROSS APPLY ADUASIS.dbo.FN_SplitSTR(REPLACE(dc.Valor, '.', ''), ';')
            WHERE dc.IdDocumento = @idAdDocumento
                  AND dc.IdCampo = 9
                  AND NULLIF(LEFT(LTRIM(RTRIM(splitdata)), 8), '') IS NOT NULL;
        END;
        IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 10)
        BEGIN
            SET @ActNico = 1;
            SELECT @ValNico = Valor FROM @Filtros WHERE IdCampo = 10;
        END;
        IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 12)
        BEGIN
            SET @ActUMT = 1;
            INSERT INTO @UnidadesUMT (IdUnidad)
            SELECT DISTINCT u.id_unidad_universal
            FROM DesarrolloDB.dbo.ad_documentos_campos AS dc WITH (NOLOCK)
                CROSS APPLY ADUASIS.dbo.FN_SplitSTR(dc.Valor, ';') AS s
                INNER JOIN ADUASIS.dbo.funidad_universal AS u WITH (NOLOCK)
                    ON u.id_unidad_universal = LTRIM(RTRIM(s.splitdata))
                       OR u.cve_unidad_oficial = LTRIM(RTRIM(s.splitdata))
                       OR u.descripcion LIKE '%' + LTRIM(RTRIM(s.splitdata)) + '%'
                       OR u.desc_abreviada LIKE '%' + LTRIM(RTRIM(s.splitdata)) + '%'
            WHERE dc.IdDocumento = @idAdDocumento
                  AND dc.IdCampo = 12;

            INSERT INTO @UnidadesUMT (IdUnidad)
            SELECT DISTINCT LTRIM(RTRIM(s.splitdata))
            FROM DesarrolloDB.dbo.ad_documentos_campos AS dc WITH (NOLOCK)
                CROSS APPLY ADUASIS.dbo.FN_SplitSTR(dc.Valor, ';') AS s
            WHERE dc.IdDocumento = @idAdDocumento
                  AND dc.IdCampo = 12
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
        IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 13)
        BEGIN
            SET @ActPais = 1;
            INSERT INTO @Paises (Pais)
            SELECT DISTINCT LTRIM(RTRIM(splitdata))
            FROM DesarrolloDB.dbo.ad_documentos_campos AS dc
                CROSS APPLY ADUASIS.dbo.FN_SplitSTR(dc.Valor, ';')
            WHERE dc.IdDocumento = @idAdDocumento
                  AND dc.IdCampo = 13
                  AND NULLIF(LTRIM(RTRIM(splitdata)), '') IS NOT NULL;
        END;
        IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 16)
        BEGIN
            SET @ActAduana = 1;
            SELECT @ValAduana = Valor FROM @Filtros WHERE IdCampo = 16;
        END;
        IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 20)
        BEGIN
            SET @ActFactura = 1;
            SELECT @ValFactura = Valor FROM @Filtros WHERE IdCampo = 20;
        END;
        IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 21)
        BEGIN
            SET @ActFechaFactura = 1;
            SELECT @ValFechaFactura = TRY_CONVERT(DATE, Valor, 23)
            FROM @Filtros
            WHERE IdCampo = 21;
        END;
        IF EXISTS (SELECT 1 FROM @Filtros WHERE IdCampo = 23)
        BEGIN
            SET @ActGuiaBl = 1;
            INSERT INTO @Guias (Guia)
            SELECT DISTINCT LTRIM(RTRIM(splitdata))
            FROM DesarrolloDB.dbo.ad_documentos_campos AS dc
                CROSS APPLY ADUASIS.dbo.FN_SplitSTR(dc.Valor, ';')
            WHERE dc.IdDocumento = @idAdDocumento
                  AND dc.IdCampo = 23
                  AND NULLIF(LTRIM(RTRIM(splitdata)), '') IS NOT NULL;
        END;
    END;

    IF @AtajoPedimento24 = 0
       AND (
           @ActFracciones = 1
           OR @ActPais = 1
           OR @ActProveedor = 1
           OR @ActProducto = 1
           OR @ActDescripcion = 1
           OR @ActNico = 1
           OR @ActUMT = 1
       )
    BEGIN
        SET @HayFiltroTrafico = 1;
    END;

    INSERT INTO @OpsExcluidas (id_referencia, id_rectificacion, pedimento, es_trafico_sin_ped)
    SELECT op.id_referencia,
           op.id_rectificacion,
           op.pedimento,
           CASE
               WHEN op.pedimento IS NULL AND op.id_rectificacion IS NULL THEN 1
               ELSE 0
           END
    FROM DesarrolloDB.dbo.ad_documento_operacion AS op WITH (NOLOCK)
    WHERE op.IdDocumento = @idAdDocumento;

    /* ========== RAMA ATAJO PEDIMENTO 24 ========== */
    IF @AtajoPedimento24 = 1
       AND @PedAduana IS NOT NULL
       AND @PedPatente IS NOT NULL
       AND @PedNumero IS NOT NULL
    BEGIN
        SELECT @TotalRecords = COUNT(DISTINCT CAST(fped.id_referencia AS VARCHAR(8)) + '|' + CAST(fped.id_rectificacion AS VARCHAR(1)))
        FROM ADUASIS.dbo.fpedimento AS fped WITH (NOLOCK)
        WHERE fped.fecha_pago_banco IS NULL
              AND fped.firma_banco IS NULL
              AND fped.id_cliente = @idCliente
              AND fped.id_aduana = @PedAduana
              AND fped.id_patente = @PedPatente
              AND fped.pedimento = @PedNumero
              AND fped.pedimento <> ''
              AND NOT EXISTS
        (
            SELECT 1
            FROM @OpsExcluidas AS op
            WHERE op.es_trafico_sin_ped = 0
                  AND op.id_referencia = fped.id_referencia
                  AND op.id_rectificacion = fped.id_rectificacion
                  AND op.pedimento = fped.pedimento
        );

        SELECT p.id_referencia,
               p.id_rectificacion,
               p.patente,
               p.aduana,
               p.pedimento,
               p.tipo_operacion,
               p.clave_pedimento,
               p.TotalRecords
        FROM
        (
            SELECT fped.id_referencia,
                   CAST(fped.id_rectificacion AS INT) AS id_rectificacion,
                   fped.id_patente AS patente,
                   fped.id_aduana + fped.seccion AS aduana,
                   fped.pedimento,
                   fped.cve_tipo_operacion AS tipo_operacion,
                   fped.id_regimen AS clave_pedimento,
                   CAST(@TotalRecords AS INT) AS TotalRecords,
                   ROW_NUMBER() OVER (ORDER BY fped.pedimento, fped.id_referencia) AS _RowNum
            FROM ADUASIS.dbo.fpedimento AS fped WITH (NOLOCK)
            WHERE fped.fecha_pago_banco IS NULL
                  AND fped.firma_banco IS NULL
                  AND fped.id_cliente = @idCliente
                  AND fped.id_aduana = @PedAduana
                  AND fped.id_patente = @PedPatente
                  AND fped.pedimento = @PedNumero
                  AND fped.pedimento <> ''
                  AND NOT EXISTS
            (
                SELECT 1
                FROM @OpsExcluidas AS op
                WHERE op.es_trafico_sin_ped = 0
                      AND op.id_referencia = fped.id_referencia
                      AND op.id_rectificacion = fped.id_rectificacion
                      AND op.pedimento = fped.pedimento
            )
        ) AS p
        WHERE p._RowNum > @Offset
              AND p._RowNum <= @RowEnd
        OPTION (RECOMPILE);

        RETURN;
    END;

    /* ========== RAMA NORMAL: materializar candidatos una vez (#Candidatos) ========== */

    CREATE TABLE #Candidatos
    (
        id_referencia VARCHAR(50) NOT NULL,
        id_rectificacion INT NULL,
        patente VARCHAR(10) NOT NULL,
        aduana VARCHAR(20) NOT NULL,
        pedimento VARCHAR(50) NOT NULL,
        tipo_operacion VARCHAR(5) NOT NULL,
        clave_pedimento VARCHAR(10) NOT NULL
    );

    /* --- Pedimentos abiertos --- */
    IF @HayFiltroTrafico = 0
    BEGIN
        INSERT INTO #Candidatos
        (
            id_referencia,
            id_rectificacion,
            patente,
            aduana,
            pedimento,
            tipo_operacion,
            clave_pedimento
        )
        SELECT fped.id_referencia,
               CAST(fped.id_rectificacion AS INT),
               fped.id_patente,
               fped.id_aduana + fped.seccion,
               fped.pedimento,
               fped.cve_tipo_operacion,
               fped.id_regimen
        FROM ADUASIS.dbo.fpedimento AS fped WITH (NOLOCK)
        WHERE fped.fecha_pago_banco IS NULL
              AND fped.firma_banco IS NULL
              AND fped.id_cliente = @idCliente
              AND fped.pedimento <> ''
              AND (@ActTipoPedimento = 0 OR fped.id_tipo_pedimento = @ValTipoPedimento)
              AND (@ActTipoOperacion = 0 OR fped.cve_tipo_operacion = @ValTipoOperacion)
              AND (@ActClavePedimento = 0 OR EXISTS (SELECT 1 FROM @ClavesPed AS cv WHERE cv.Clave = fped.id_regimen))
              AND (@ActAduana = 0 OR (fped.id_aduana + fped.seccion) LIKE '%' + @ValAduana + '%')
              AND (@operacionBusquedaTrim = ''
                   OR fped.pedimento LIKE '%' + @operacionBusquedaTrim + '%'
                   OR fped.id_referencia LIKE '%' + @operacionBusquedaTrim + '%'
                   OR fped.id_referencia = @operacionBusquedaTrim
                   OR (@BusqEsRefRect = 1 AND fped.id_referencia = @BusqReferencia AND fped.id_rectificacion = @BusqRectificacion)
                   OR CONCAT(RTRIM(fped.id_referencia), '/', CAST(fped.id_rectificacion AS VARCHAR(10))) = @operacionBusquedaTrim)
              AND (@ActFactura = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura AS rel WITH (NOLOCK) WHERE rel.id_referencia = fped.id_referencia AND rel.id_rectificacion = fped.id_rectificacion AND RTRIM(LTRIM(rel.id_factura)) = @ValFactura))
              AND (@ActFechaFactura = 0 OR @ValFechaFactura IS NULL OR EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura AS rel WITH (NOLOCK) WHERE rel.id_referencia = fped.id_referencia AND rel.id_rectificacion = fped.id_rectificacion AND TRY_CONVERT(DATE, rel.fecha_factura) = @ValFechaFactura))
              AND (@ActGuiaBl = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fpedimento_guia AS pg WITH (NOLOCK) INNER JOIN @Guias AS g ON RTRIM(LTRIM(pg.guia)) = g.Guia WHERE pg.id_referencia = fped.id_referencia AND pg.id_rectificacion = fped.id_rectificacion))
              AND NOT EXISTS (SELECT 1 FROM @OpsExcluidas AS op WHERE op.es_trafico_sin_ped = 0 AND op.id_referencia = fped.id_referencia AND op.id_rectificacion = fped.id_rectificacion AND op.pedimento = fped.pedimento)
        GROUP BY fped.id_referencia,
                 fped.id_rectificacion,
                 fped.id_patente,
                 fped.id_aduana + fped.seccion,
                 fped.pedimento,
                 fped.cve_tipo_operacion,
                 fped.id_regimen;
    END
    ELSE
    BEGIN
        /*
          Filtros de partida (proveedor/producto/fracción/país/etc.): EXISTS independiente por campo,
          igual que csp_Ad_DiagnosticoSugerenciaPedimentos_v2.
          Antes se AND-eaban sobre la misma fila de fdtrafico (INNER JOIN), lo que excluía
          operaciones válidas donde cada criterio se cumple en partidas distintas.
        */
        INSERT INTO #Candidatos
        (
            id_referencia,
            id_rectificacion,
            patente,
            aduana,
            pedimento,
            tipo_operacion,
            clave_pedimento
        )
        SELECT fped.id_referencia,
               CAST(fped.id_rectificacion AS INT),
               fped.id_patente,
               fped.id_aduana + fped.seccion,
               fped.pedimento,
               fped.cve_tipo_operacion,
               fped.id_regimen
        FROM ADUASIS.dbo.fpedimento AS fped WITH (NOLOCK)
        WHERE fped.fecha_pago_banco IS NULL
              AND fped.firma_banco IS NULL
              AND fped.id_cliente = @idCliente
              AND fped.pedimento <> ''
              AND (@ActTipoPedimento = 0 OR fped.id_tipo_pedimento = @ValTipoPedimento)
              AND (@ActTipoOperacion = 0 OR fped.cve_tipo_operacion = @ValTipoOperacion)
              AND (@ActClavePedimento = 0 OR EXISTS (SELECT 1 FROM @ClavesPed AS cv WHERE cv.Clave = fped.id_regimen))
              AND (@ActAduana = 0 OR (fped.id_aduana + fped.seccion) LIKE '%' + @ValAduana + '%')
              AND (@operacionBusquedaTrim = ''
                   OR fped.pedimento LIKE '%' + @operacionBusquedaTrim + '%'
                   OR fped.id_referencia LIKE '%' + @operacionBusquedaTrim + '%'
                   OR fped.id_referencia = @operacionBusquedaTrim
                   OR (@BusqEsRefRect = 1 AND fped.id_referencia = @BusqReferencia AND fped.id_rectificacion = @BusqRectificacion)
                   OR CONCAT(RTRIM(fped.id_referencia), '/', CAST(fped.id_rectificacion AS VARCHAR(10))) = @operacionBusquedaTrim)
              AND (@ActFactura = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura AS rel WITH (NOLOCK) WHERE rel.id_referencia = fped.id_referencia AND rel.id_rectificacion = fped.id_rectificacion AND RTRIM(LTRIM(rel.id_factura)) = @ValFactura))
              AND (@ActFechaFactura = 0 OR @ValFechaFactura IS NULL OR EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_pedimento_factura AS rel WITH (NOLOCK) WHERE rel.id_referencia = fped.id_referencia AND rel.id_rectificacion = fped.id_rectificacion AND TRY_CONVERT(DATE, rel.fecha_factura) = @ValFechaFactura))
              AND (@ActGuiaBl = 0 OR EXISTS (SELECT 1 FROM ADUASIS.dbo.fpedimento_guia AS pg WITH (NOLOCK) INNER JOIN @Guias AS g ON RTRIM(LTRIM(pg.guia)) = g.Guia WHERE pg.id_referencia = fped.id_referencia AND pg.id_rectificacion = fped.id_rectificacion))
              AND (@ActProveedor = 0 OR EXISTS (
                      SELECT 1
                      FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                          INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                      WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
                            AND fdt.id_proveedor = @ValProveedor
                  ))
              AND (@ActProducto = 0 OR EXISTS (
                      SELECT 1
                      FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                          INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                          INNER JOIN @Productos AS pr ON REPLACE(fdt.id_producto, ' ', '') = pr.Producto
                      WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
                  ))
              AND (@ActDescripcion = 0 OR EXISTS (
                      SELECT 1
                      FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                          INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                          INNER JOIN @Descripciones AS d ON fdt.descripcion_clasificacion = d.Descripcion
                      WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
                  ) OR EXISTS (
                      SELECT 1
                      FROM ADUASIS.dbo.fpedimento_detalle AS pd WITH (NOLOCK)
                          INNER JOIN @Descripciones AS d ON pd.descripcion_fraccion = d.Descripcion
                      WHERE pd.id_referencia = fped.id_referencia
                            AND pd.id_rectificacion = fped.id_rectificacion
                  ))
              AND (@ActFracciones = 0 OR EXISTS (
                      SELECT 1
                      FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                          INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                          INNER JOIN @Fracciones AS frac ON fdt.id_fraccion LIKE frac.Fraccion + '%'
                      WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
                  ))
              AND (@ActNico = 0 OR EXISTS (
                      SELECT 1
                      FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                          INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                      WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
                            AND TRY_CONVERT(INT, fdt.nico) = TRY_CONVERT(INT, @ValNico)
                  ) OR EXISTS (
                      SELECT 1
                      FROM ADUASIS.dbo.fpedimento_detalle AS pd WITH (NOLOCK)
                      WHERE pd.id_referencia = fped.id_referencia
                            AND pd.id_rectificacion = fped.id_rectificacion
                            AND TRY_CONVERT(INT, pd.sub_fraccion) = TRY_CONVERT(INT, @ValNico)
                  ))
              AND (@ActUMT = 0 OR EXISTS (
                      SELECT 1
                      FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                          INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                          INNER JOIN @UnidadesUMT AS u ON fdt.id_unidad_universal = u.IdUnidad
                                                      OR fdt.cve_unidad_tarifa = u.IdUnidad
                      WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
                  ) OR EXISTS (
                      SELECT 1
                      FROM @UnidadesUMT AS u
                          INNER JOIN ADUASIS.dbo.fpedimento_detalle AS pd WITH (NOLOCK)
                              ON pd.id_referencia = fped.id_referencia
                                 AND pd.id_rectificacion = fped.id_rectificacion
                                 AND (pd.id_unidad_universal = u.IdUnidad OR pd.cve_unidad_tarifa = u.IdUnidad)
                  ))
              AND (@ActPais = 0 OR EXISTS (
                      SELECT 1
                      FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                          INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK) ON fdt.id_trafico = fgt.id_trafico
                          INNER JOIN @Paises AS p ON fdt.id_pais_origen LIKE '%' + p.Pais + '%'
                                                 OR fdt.id_pais_vendedor LIKE '%' + p.Pais + '%'
                      WHERE fgt.id_referencia = fped.id_referencia AND fgt.id_rectificacion = 0
                  ))
              AND NOT EXISTS (SELECT 1 FROM @OpsExcluidas AS op WHERE op.es_trafico_sin_ped = 0 AND op.id_referencia = fped.id_referencia AND op.id_rectificacion = fped.id_rectificacion AND op.pedimento = fped.pedimento)
        GROUP BY fped.id_referencia,
                 fped.id_rectificacion,
                 fped.id_patente,
                 fped.id_aduana + fped.seccion,
                 fped.pedimento,
                 fped.cve_tipo_operacion,
                 fped.id_regimen;
    END;

    /* --- Trafico (incluye tráficos ya relacionados con pedimento) --- */
    IF @HayFiltroTrafico = 1
    BEGIN
        /*
          Misma semántica que pedimentos: cada filtro de partida se valida con EXISTS
          independiente sobre las partidas del tráfico (no AND sobre la misma fila).
          No se excluye por existencia de fpedimento (misma referencia/rectificación).
        */
        IF @operacionBusquedaTrim = ''
        BEGIN
            INSERT INTO #Candidatos
            (
                id_referencia,
                id_rectificacion,
                patente,
                aduana,
                pedimento,
                tipo_operacion,
                clave_pedimento
            )
            SELECT fgt.id_trafico,
                   NULL,
                   ISNULL(fgt.id_patente, ''),
                   ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, ''),
                   '',
                   CASE
                       WHEN fgt.cve_tipo_operacion = '0' THEN '1'
                       WHEN fgt.cve_tipo_operacion = '1' THEN '2'
                       ELSE ''
                   END,
                   fgt.id_regimen
            FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
            WHERE fgt.id_cliente = @idCliente
                  AND (@ActTipoPedimento = 0 OR fgt.id_tipo_pedimento = @ValTipoPedimento)
                  AND (@ActTipoOperacion = 0 OR CASE WHEN fgt.cve_tipo_operacion = '0' THEN '1' WHEN fgt.cve_tipo_operacion = '1' THEN '2' ELSE '' END = @ValTipoOperacion)
                  AND (@ActClavePedimento = 0 OR EXISTS (SELECT 1 FROM @ClavesPed AS cv WHERE cv.Clave = fgt.id_regimen))
                  AND (@ActAduana = 0 OR fgt.id_aduana IS NULL OR (ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, '')) LIKE '%' + @ValAduana + '%')
                  AND (@operacionBusquedaTrim = ''
                       OR fgt.id_trafico LIKE '%' + @operacionBusquedaTrim + '%'
                       OR fgt.id_trafico = @operacionBusquedaTrim
                       OR (@BusqEsRefRect = 1 AND fgt.id_trafico = @BusqReferencia))
                  AND (@ActFactura = 0 OR EXISTS (
                          SELECT 1
                          FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                              INNER JOIN ADUASIS.dbo.fdfactura AS fdf WITH (NOLOCK)
                                  ON fdf.id_entrada = fdt.id_entrada
                                     AND fdf.id_cliente = fgt.id_cliente
                                     AND fdf.id_proveedor = fdt.id_proveedor
                                     AND fdf.id_producto = fdt.id_producto
                              INNER JOIN ADUASIS.dbo.fgfactura AS fgf WITH (NOLOCK)
                                  ON fgf.id_factura = fdf.id_factura
                                     AND fgf.id_cliente = fdf.id_cliente
                                     AND fgf.id_proveedor = fdf.id_proveedor
                                     AND fdf.id_entrada = fdf.id_entrada
                          WHERE fdt.id_trafico = fgt.id_trafico
                                AND RTRIM(LTRIM(fgf.id_factura)) = @ValFactura
                      ))
                  AND (@ActFechaFactura = 0 OR @ValFechaFactura IS NULL OR EXISTS (
                          SELECT 1
                          FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                              INNER JOIN ADUASIS.dbo.fdfactura AS fdf WITH (NOLOCK)
                                  ON fdf.id_entrada = fdt.id_entrada
                                     AND fdf.id_cliente = fgt.id_cliente
                                     AND fdf.id_proveedor = fdt.id_proveedor
                                     AND fdf.id_producto = fdt.id_producto
                              INNER JOIN ADUASIS.dbo.fgfactura AS fgf WITH (NOLOCK)
                                  ON fgf.id_factura = fdf.id_factura
                                     AND fgf.id_cliente = fdf.id_cliente
                                     AND fgf.id_proveedor = fdf.id_proveedor
                                     AND fdf.id_entrada = fdf.id_entrada
                          WHERE fdt.id_trafico = fgt.id_trafico
                                AND TRY_CONVERT(DATE, fgf.fecha_factura) = @ValFechaFactura
                      ))
                  AND (@ActProveedor = 0 OR EXISTS (
                          SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                          WHERE fdt.id_trafico = fgt.id_trafico AND fdt.id_proveedor = @ValProveedor
                      ))
                  AND (@ActProducto = 0 OR EXISTS (
                          SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                              INNER JOIN @Productos AS pr ON REPLACE(fdt.id_producto, ' ', '') = pr.Producto
                          WHERE fdt.id_trafico = fgt.id_trafico
                      ))
                  AND (@ActDescripcion = 0 OR EXISTS (
                          SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                              INNER JOIN @Descripciones AS d ON fdt.descripcion_clasificacion = d.Descripcion
                          WHERE fdt.id_trafico = fgt.id_trafico
                      ))
                  AND (@ActFracciones = 0 OR EXISTS (
                          SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                              INNER JOIN @Fracciones AS frac ON fdt.id_fraccion LIKE frac.Fraccion + '%'
                          WHERE fdt.id_trafico = fgt.id_trafico
                      ))
                  AND (@ActNico = 0 OR EXISTS (
                          SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                          WHERE fdt.id_trafico = fgt.id_trafico
                                AND TRY_CONVERT(INT, fdt.nico) = TRY_CONVERT(INT, @ValNico)
                      ))
                  AND (@ActUMT = 0 OR EXISTS (
                          SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                              INNER JOIN @UnidadesUMT AS u ON fdt.id_unidad_universal = u.IdUnidad
                                                          OR fdt.cve_unidad_tarifa = u.IdUnidad
                          WHERE fdt.id_trafico = fgt.id_trafico
                      ))
                  AND (@ActPais = 0 OR EXISTS (
                          SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                              INNER JOIN @Paises AS p ON fdt.id_pais_origen LIKE '%' + p.Pais + '%'
                                                     OR fdt.id_pais_vendedor LIKE '%' + p.Pais + '%'
                          WHERE fdt.id_trafico = fgt.id_trafico
                      ))
                  AND NOT EXISTS (SELECT 1 FROM @OpsExcluidas AS op WHERE op.es_trafico_sin_ped = 1 AND op.id_referencia = fgt.id_trafico)
            GROUP BY fgt.id_trafico,
                     ISNULL(fgt.id_patente, ''),
                     ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, ''),
                     CASE WHEN fgt.cve_tipo_operacion = '0' THEN '1' WHEN fgt.cve_tipo_operacion = '1' THEN '2' ELSE '' END,
                     fgt.id_regimen
            OPTION (RECOMPILE);
        END
        ELSE
        BEGIN
            INSERT INTO #Candidatos
            (
                id_referencia,
                id_rectificacion,
                patente,
                aduana,
                pedimento,
                tipo_operacion,
                clave_pedimento
            )
            SELECT fgt.id_trafico,
                   NULL,
                   ISNULL(fgt.id_patente, ''),
                   ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, ''),
                   '',
                   CASE
                       WHEN fgt.cve_tipo_operacion = '0' THEN '1'
                       WHEN fgt.cve_tipo_operacion = '1' THEN '2'
                       ELSE ''
                   END,
                   fgt.id_regimen
            FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
            WHERE fgt.id_cliente = @idCliente
                  AND (@ActTipoPedimento = 0 OR fgt.id_tipo_pedimento = @ValTipoPedimento)
                  AND (@ActTipoOperacion = 0 OR CASE WHEN fgt.cve_tipo_operacion = '0' THEN '1' WHEN fgt.cve_tipo_operacion = '1' THEN '2' ELSE '' END = @ValTipoOperacion)
                  AND (@ActClavePedimento = 0 OR EXISTS (SELECT 1 FROM @ClavesPed AS cv WHERE cv.Clave = fgt.id_regimen))
                  AND (@ActAduana = 0 OR fgt.id_aduana IS NULL OR (ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, '')) LIKE '%' + @ValAduana + '%')
                  AND (@operacionBusquedaTrim = ''
                       OR fgt.id_trafico LIKE '%' + @operacionBusquedaTrim + '%'
                       OR fgt.id_trafico = @operacionBusquedaTrim
                       OR (@BusqEsRefRect = 1 AND fgt.id_trafico = @BusqReferencia))
                  AND (@ActFactura = 0 OR EXISTS (
                          SELECT 1
                          FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                              INNER JOIN ADUASIS.dbo.fdfactura AS fdf WITH (NOLOCK)
                                  ON fdf.id_entrada = fdt.id_entrada
                                     AND fdf.id_cliente = fgt.id_cliente
                                     AND fdf.id_proveedor = fdt.id_proveedor
                                     AND fdf.id_producto = fdt.id_producto
                              INNER JOIN ADUASIS.dbo.fgfactura AS fgf WITH (NOLOCK)
                                  ON fgf.id_factura = fdf.id_factura
                                     AND fgf.id_cliente = fdf.id_cliente
                                     AND fgf.id_proveedor = fdf.id_proveedor
                                     AND fdf.id_entrada = fdf.id_entrada
                          WHERE fdt.id_trafico = fgt.id_trafico
                                AND RTRIM(LTRIM(fgf.id_factura)) = @ValFactura
                      ))
                  AND (@ActFechaFactura = 0 OR @ValFechaFactura IS NULL OR EXISTS (
                          SELECT 1
                          FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                              INNER JOIN ADUASIS.dbo.fdfactura AS fdf WITH (NOLOCK)
                                  ON fdf.id_entrada = fdt.id_entrada
                                     AND fdf.id_cliente = fgt.id_cliente
                                     AND fdf.id_proveedor = fdt.id_proveedor
                                     AND fdf.id_producto = fdt.id_producto
                              INNER JOIN ADUASIS.dbo.fgfactura AS fgf WITH (NOLOCK)
                                  ON fgf.id_factura = fdf.id_factura
                                     AND fgf.id_cliente = fdf.id_cliente
                                     AND fgf.id_proveedor = fdf.id_proveedor
                                     AND fdf.id_entrada = fdf.id_entrada
                          WHERE fdt.id_trafico = fgt.id_trafico
                                AND TRY_CONVERT(DATE, fgf.fecha_factura) = @ValFechaFactura
                      ))
                  AND (@ActProveedor = 0 OR EXISTS (
                          SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                          WHERE fdt.id_trafico = fgt.id_trafico AND fdt.id_proveedor = @ValProveedor
                      ))
                  AND (@ActProducto = 0 OR EXISTS (
                          SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                              INNER JOIN @Productos AS pr ON REPLACE(fdt.id_producto, ' ', '') = pr.Producto
                          WHERE fdt.id_trafico = fgt.id_trafico
                      ))
                  AND (@ActDescripcion = 0 OR EXISTS (
                          SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                              INNER JOIN @Descripciones AS d ON fdt.descripcion_clasificacion = d.Descripcion
                          WHERE fdt.id_trafico = fgt.id_trafico
                      ))
                  AND (@ActFracciones = 0 OR EXISTS (
                          SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                              INNER JOIN @Fracciones AS frac ON fdt.id_fraccion LIKE frac.Fraccion + '%'
                          WHERE fdt.id_trafico = fgt.id_trafico
                      ))
                  AND (@ActNico = 0 OR EXISTS (
                          SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                          WHERE fdt.id_trafico = fgt.id_trafico
                                AND TRY_CONVERT(INT, fdt.nico) = TRY_CONVERT(INT, @ValNico)
                      ))
                  AND (@ActUMT = 0 OR EXISTS (
                          SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                              INNER JOIN @UnidadesUMT AS u ON fdt.id_unidad_universal = u.IdUnidad
                                                          OR fdt.cve_unidad_tarifa = u.IdUnidad
                          WHERE fdt.id_trafico = fgt.id_trafico
                      ))
                  AND (@ActPais = 0 OR EXISTS (
                          SELECT 1 FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                              INNER JOIN @Paises AS p ON fdt.id_pais_origen LIKE '%' + p.Pais + '%'
                                                     OR fdt.id_pais_vendedor LIKE '%' + p.Pais + '%'
                          WHERE fdt.id_trafico = fgt.id_trafico
                      ))
                  AND NOT EXISTS (SELECT 1 FROM @OpsExcluidas AS op WHERE op.es_trafico_sin_ped = 1 AND op.id_referencia = fgt.id_trafico)
            GROUP BY fgt.id_trafico,
                     ISNULL(fgt.id_patente, ''),
                     ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, ''),
                     CASE WHEN fgt.cve_tipo_operacion = '0' THEN '1' WHEN fgt.cve_tipo_operacion = '1' THEN '2' ELSE '' END,
                     fgt.id_regimen;
        END
    END
    ELSE
    BEGIN
        IF @operacionBusquedaTrim = ''
        BEGIN
            INSERT INTO #Candidatos
            (
                id_referencia,
                id_rectificacion,
                patente,
                aduana,
                pedimento,
                tipo_operacion,
                clave_pedimento
            )
            SELECT fgt.id_trafico,
                   NULL,
                   ISNULL(fgt.id_patente, ''),
                   ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, ''),
                   '',
                   CASE
                       WHEN fgt.cve_tipo_operacion = '0' THEN '1'
                       WHEN fgt.cve_tipo_operacion = '1' THEN '2'
                       ELSE ''
                   END,
                   fgt.id_regimen
            FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
            WHERE fgt.id_cliente = @idCliente
                  AND (@ActTipoPedimento = 0 OR fgt.id_tipo_pedimento = @ValTipoPedimento)
                  AND (@ActTipoOperacion = 0 OR CASE WHEN fgt.cve_tipo_operacion = '0' THEN '1' WHEN fgt.cve_tipo_operacion = '1' THEN '2' ELSE '' END = @ValTipoOperacion)
                  AND (@ActClavePedimento = 0 OR EXISTS (SELECT 1 FROM @ClavesPed AS cv WHERE cv.Clave = fgt.id_regimen))
                  AND (@ActAduana = 0 OR fgt.id_aduana IS NULL OR (ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, '')) LIKE '%' + @ValAduana + '%')
                  AND (@operacionBusquedaTrim = ''
                       OR fgt.id_trafico LIKE '%' + @operacionBusquedaTrim + '%'
                       OR fgt.id_trafico = @operacionBusquedaTrim
                       OR (@BusqEsRefRect = 1 AND fgt.id_trafico = @BusqReferencia))
                  AND (@ActFactura = 0 OR EXISTS (
                          SELECT 1
                          FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                              INNER JOIN ADUASIS.dbo.fdfactura AS fdf WITH (NOLOCK)
                                  ON fdf.id_entrada = fdt.id_entrada
                                     AND fdf.id_cliente = fgt.id_cliente
                                     AND fdf.id_proveedor = fdt.id_proveedor
                                     AND fdf.id_producto = fdt.id_producto
                              INNER JOIN ADUASIS.dbo.fgfactura AS fgf WITH (NOLOCK)
                                  ON fgf.id_factura = fdf.id_factura
                                     AND fgf.id_cliente = fdf.id_cliente
                                     AND fgf.id_proveedor = fdf.id_proveedor
                                     AND fdf.id_entrada = fdf.id_entrada
                          WHERE fdt.id_trafico = fgt.id_trafico
                                AND RTRIM(LTRIM(fgf.id_factura)) = @ValFactura
                      ))
                  AND (@ActFechaFactura = 0 OR @ValFechaFactura IS NULL OR EXISTS (
                          SELECT 1
                          FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                              INNER JOIN ADUASIS.dbo.fdfactura AS fdf WITH (NOLOCK)
                                  ON fdf.id_entrada = fdt.id_entrada
                                     AND fdf.id_cliente = fgt.id_cliente
                                     AND fdf.id_proveedor = fdt.id_proveedor
                                     AND fdf.id_producto = fdt.id_producto
                              INNER JOIN ADUASIS.dbo.fgfactura AS fgf WITH (NOLOCK)
                                  ON fgf.id_factura = fdf.id_factura
                                     AND fgf.id_cliente = fdf.id_cliente
                                     AND fgf.id_proveedor = fdf.id_proveedor
                                     AND fdf.id_entrada = fdf.id_entrada
                          WHERE fdt.id_trafico = fgt.id_trafico
                                AND TRY_CONVERT(DATE, fgf.fecha_factura) = @ValFechaFactura
                      ))
                  AND NOT EXISTS (SELECT 1 FROM @OpsExcluidas AS op WHERE op.es_trafico_sin_ped = 1 AND op.id_referencia = fgt.id_trafico)
            GROUP BY fgt.id_trafico,
                     ISNULL(fgt.id_patente, ''),
                     ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, ''),
                     CASE WHEN fgt.cve_tipo_operacion = '0' THEN '1' WHEN fgt.cve_tipo_operacion = '1' THEN '2' ELSE '' END,
                     fgt.id_regimen
            OPTION (RECOMPILE);
        END
        ELSE
        BEGIN
            INSERT INTO #Candidatos
            (
                id_referencia,
                id_rectificacion,
                patente,
                aduana,
                pedimento,
                tipo_operacion,
                clave_pedimento
            )
            SELECT fgt.id_trafico,
                   NULL,
                   ISNULL(fgt.id_patente, ''),
                   ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, ''),
                   '',
                   CASE
                       WHEN fgt.cve_tipo_operacion = '0' THEN '1'
                       WHEN fgt.cve_tipo_operacion = '1' THEN '2'
                       ELSE ''
                   END,
                   fgt.id_regimen
            FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
            WHERE fgt.id_cliente = @idCliente
                  AND (@ActTipoPedimento = 0 OR fgt.id_tipo_pedimento = @ValTipoPedimento)
                  AND (@ActTipoOperacion = 0 OR CASE WHEN fgt.cve_tipo_operacion = '0' THEN '1' WHEN fgt.cve_tipo_operacion = '1' THEN '2' ELSE '' END = @ValTipoOperacion)
                  AND (@ActClavePedimento = 0 OR EXISTS (SELECT 1 FROM @ClavesPed AS cv WHERE cv.Clave = fgt.id_regimen))
                  AND (@ActAduana = 0 OR fgt.id_aduana IS NULL OR (ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, '')) LIKE '%' + @ValAduana + '%')
                  AND (@operacionBusquedaTrim = ''
                       OR fgt.id_trafico LIKE '%' + @operacionBusquedaTrim + '%'
                       OR fgt.id_trafico = @operacionBusquedaTrim
                       OR (@BusqEsRefRect = 1 AND fgt.id_trafico = @BusqReferencia))
                  AND (@ActFactura = 0 OR EXISTS (
                          SELECT 1
                          FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                              INNER JOIN ADUASIS.dbo.fdfactura AS fdf WITH (NOLOCK)
                                  ON fdf.id_entrada = fdt.id_entrada
                                     AND fdf.id_cliente = fgt.id_cliente
                                     AND fdf.id_proveedor = fdt.id_proveedor
                                     AND fdf.id_producto = fdt.id_producto
                              INNER JOIN ADUASIS.dbo.fgfactura AS fgf WITH (NOLOCK)
                                  ON fgf.id_factura = fdf.id_factura
                                     AND fgf.id_cliente = fdf.id_cliente
                                     AND fgf.id_proveedor = fdf.id_proveedor
                                     AND fdf.id_entrada = fdf.id_entrada
                          WHERE fdt.id_trafico = fgt.id_trafico
                                AND RTRIM(LTRIM(fgf.id_factura)) = @ValFactura
                      ))
                  AND (@ActFechaFactura = 0 OR @ValFechaFactura IS NULL OR EXISTS (
                          SELECT 1
                          FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                              INNER JOIN ADUASIS.dbo.fdfactura AS fdf WITH (NOLOCK)
                                  ON fdf.id_entrada = fdt.id_entrada
                                     AND fdf.id_cliente = fgt.id_cliente
                                     AND fdf.id_proveedor = fdt.id_proveedor
                                     AND fdf.id_producto = fdt.id_producto
                              INNER JOIN ADUASIS.dbo.fgfactura AS fgf WITH (NOLOCK)
                                  ON fgf.id_factura = fdf.id_factura
                                     AND fgf.id_cliente = fdf.id_cliente
                                     AND fgf.id_proveedor = fdf.id_proveedor
                                     AND fdf.id_entrada = fdf.id_entrada
                          WHERE fdt.id_trafico = fgt.id_trafico
                                AND TRY_CONVERT(DATE, fgf.fecha_factura) = @ValFechaFactura
                      ))
                  AND NOT EXISTS (SELECT 1 FROM @OpsExcluidas AS op WHERE op.es_trafico_sin_ped = 1 AND op.id_referencia = fgt.id_trafico)
            GROUP BY fgt.id_trafico,
                     ISNULL(fgt.id_patente, ''),
                     ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, ''),
                     CASE WHEN fgt.cve_tipo_operacion = '0' THEN '1' WHEN fgt.cve_tipo_operacion = '1' THEN '2' ELSE '' END,
                     fgt.id_regimen;
        END
    END;

    SELECT @TotalRecords = COUNT(*) FROM #Candidatos;

    SELECT p.id_referencia,
           p.id_rectificacion,
           p.patente,
           p.aduana,
           p.pedimento,
           p.tipo_operacion,
           p.clave_pedimento,
           CAST(@TotalRecords AS INT) AS TotalRecords
    FROM
    (
        SELECT c.id_referencia,
               c.id_rectificacion,
               c.patente,
               c.aduana,
               c.pedimento,
               c.tipo_operacion,
               c.clave_pedimento,
               ROW_NUMBER() OVER (ORDER BY c.pedimento, c.id_referencia) AS _RowNum
        FROM #Candidatos AS c
    ) AS p
    WHERE p._RowNum > @Offset
          AND p._RowNum <= @RowEnd
    OPTION (RECOMPILE);

    DROP TABLE #Candidatos;
END;
GO
