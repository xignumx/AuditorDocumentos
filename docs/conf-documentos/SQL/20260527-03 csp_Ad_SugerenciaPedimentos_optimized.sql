/*
    csp_Ad_SugerenciaPedimentos — borrador optimizado (20260527-03) — NO USAR EN PRODUCCIÓN
    ======================================================================================
    Versión canónica / despliegue: 20260527-02 csp_Ad_SugerenciaPedimentos.sql

    Resultado de pruebas (mismos parámetros y entorno): esta versión tardó MÁS DEL DOBLE
    que 20260527-02. Se conserva solo como referencia histórica; no reemplazar el SP en Aduasis.

    Por qué la optimización anterior pudo causar timeouts en producción
    --------------------------------------------------------------------
    1. Materializar TODOS los resultados en #Resultados antes de paginar obliga a
       procesar el universo completo en tempdb; el original también ordena el UNION
       completo, pero un plan único sobre temp grande suele empeorar con parameter sniffing.
    2. Variables tabla (@) sin estadísticas: SQL Server asume ~1 fila; en conjuntos
       grandes genera planes anidados (nested loops) muy lentos. Mejor @ solo para
       filtros pequeños (fracciones, países, exclusiones por documento).
    3. Esta versión NO materializa el universo: conserva la estructura de 3 pasadas
       del original (COUNT pedimentos, COUNT tráficos, SELECT paginado) para mismo
       TotalRecords y comportamiento probado.

    Cambios respecto al original (20260527-02)
    ------------------------------------------
    - @OpsExcluidas: una lectura a DesarrolloDB por ejecución (variable tabla con índice).
    - EXISTS en lugar de CROSS JOIN @Fracciones x @Paises (misma lógica, menos filas intermedias).
    - @FilterTipoPedimento y @SinFiltroFraccionPais precalculados.
    - Corrección en SELECT paginado pedimentos: JOIN fdt.id_trafico = fgt.id_trafico
      (faltaba en 20260527-02 y puede producir producto cartesiano / timeout).
    - OPTION (RECOMPILE) en consultas pesadas: planes acordes a parámetros reales.
    - Filtros opcionales con OR se mantienen igual que el original (regla de negocio).

    Índices recomendados (validar con DBA en Aduasis / DesarrolloDB)
    -----------------------------------------------------------------
    - fpedimento: (id_cliente) INCLUDE (fecha_pago_banco, firma_banco, id_referencia, ...)
    - fgtrafico: (id_cliente, id_referencia, id_rectificacion)
    - fdtrafico: (id_trafico) INCLUDE (id_fraccion, id_pais_origen, id_pais_vendedor)
    - ad_documento_operacion: (IdDocumento) INCLUDE (id_referencia, id_rectificacion, pedimento)
*/
USE Aduasis
GO

CREATE OR ALTER PROCEDURE dbo.csp_Ad_SugerenciaPedimentos
    @idCliente VARCHAR(10),
    @idAdDocumento BIGINT,
    @pedimento VARCHAR(7),
    @clavePedimento VARCHAR(2),
    @tipoOperacion VARCHAR(1),
    @tipoPedimento VARCHAR(2),
    @aduana VARCHAR(3),
    @fraccion VARCHAR(MAX),
    @pais VARCHAR(MAX),
    @PageNumber INT = 1,
    @PageSize INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    IF @PageNumber < 1 SET @PageNumber = 1;
    IF @PageSize < 1 SET @PageSize = 10;
    IF @PageSize > 100 SET @PageSize = 100;

    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    DECLARE @TotalRecords INT;
    DECLARE @FilterTipoPedimento BIT =
        CASE WHEN TRY_CAST(@tipoPedimento AS INT) IS NOT NULL THEN 1 ELSE 0 END;
    DECLARE @SinFiltroFraccionPais BIT = 0;

    DECLARE @Fracciones TABLE (Fraccion VARCHAR(8) NOT NULL);
    DECLARE @Paises TABLE (Pais VARCHAR(1000) NOT NULL);
    DECLARE @ClavesPed TABLE (Clave VARCHAR(2) NOT NULL);

    /* Exclusiones por documento: conjunto pequeño → variable tabla con índice (mejor que #temp aquí) */
    DECLARE @OpsExcluidas TABLE
    (
        id_referencia VARCHAR(50) NOT NULL,
        id_rectificacion INT NULL,
        pedimento VARCHAR(50) NULL,
        INDEX IX_OpsExcluidas CLUSTERED (id_referencia, id_rectificacion, pedimento)
    );

    INSERT INTO @Fracciones (Fraccion)
    SELECT LEFT(splitdata, 8)
    FROM ADUASIS.dbo.FN_SplitSTR(REPLACE(@fraccion, '.', ''), ';');

    INSERT INTO @Paises (Pais)
    SELECT splitdata
    FROM ADUASIS.dbo.FN_SplitSTR(@pais, ';');

    INSERT INTO @ClavesPed (Clave)
    SELECT splitdata
    FROM ADUASIS.dbo.FN_SplitSTR(@clavePedimento, ';');

    IF NOT EXISTS (SELECT 1 FROM @Fracciones)
        INSERT INTO @Fracciones (Fraccion) VALUES ('');

    IF NOT EXISTS (SELECT 1 FROM @Paises)
        INSERT INTO @Paises (Pais) VALUES ('');

    IF NOT EXISTS (SELECT 1 FROM @Fracciones WHERE Fraccion <> '')
        AND NOT EXISTS (SELECT 1 FROM @Paises WHERE Pais <> '')
        SET @SinFiltroFraccionPais = 1;

    INSERT INTO @OpsExcluidas (id_referencia, id_rectificacion, pedimento)
    SELECT op.id_referencia, op.id_rectificacion, op.pedimento
    FROM DesarrolloDB.dbo.ad_documento_operacion op WITH (NOLOCK)
    WHERE op.IdDocumento = @idAdDocumento;

    /* Misma fórmula de TotalRecords que 20260527-02 (pedimentos) */
    SELECT @TotalRecords =
        COUNT(DISTINCT CAST(fped.id_referencia AS VARCHAR(8)) + '|' + CAST(fped.id_rectificacion AS VARCHAR(1)))
    FROM ADUASIS.dbo.fpedimento fped WITH (NOLOCK)
        INNER JOIN ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
            ON fgt.id_referencia = fped.id_referencia
               AND fgt.id_rectificacion = 0
    WHERE fped.fecha_pago_banco IS NULL
          AND fped.firma_banco IS NULL
          AND fped.id_cliente = @idCliente
          AND
          (
              (@clavePedimento = '' OR EXISTS (SELECT 1 FROM @ClavesPed cv WHERE cv.Clave = fped.id_regimen))
              OR (@tipoOperacion = '' OR fped.cve_tipo_operacion = @tipoOperacion)
              OR (@FilterTipoPedimento = 0 OR fped.id_tipo_pedimento = @tipoPedimento)
              OR (@aduana = '' OR (fped.id_aduana + fped.seccion) LIKE '%' + @aduana + '%')
          )
          AND
          (
              @pedimento = ''
              OR fped.pedimento LIKE '%' + @pedimento + '%'
              OR fped.id_referencia LIKE '%' + @pedimento + '%'
          )
          AND fped.pedimento <> ''
          AND NOT EXISTS
          (
              SELECT 1
              FROM @OpsExcluidas op
              WHERE op.id_referencia = fped.id_referencia
                    AND op.id_rectificacion = fped.id_rectificacion
                    AND op.pedimento = fped.pedimento
          )
          AND
          (
              (
                  @SinFiltroFraccionPais = 1
                  AND EXISTS
                  (
                      SELECT 1
                      FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                      WHERE fdt.id_trafico = fgt.id_trafico
                  )
              )
              OR
              (
                  @SinFiltroFraccionPais = 0
                  AND EXISTS
                  (
                      SELECT 1
                      FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                          INNER JOIN @Fracciones AS frac
                              ON fdt.id_fraccion LIKE frac.Fraccion + '%'
                          INNER JOIN @Paises AS pais
                              ON (
                                     fdt.id_pais_origen LIKE '%' + pais.Pais + '%'
                                  OR fdt.id_pais_vendedor LIKE '%' + pais.Pais + '%'
                                 )
                      WHERE fdt.id_trafico = fgt.id_trafico
                  )
              )
          )
    OPTION (RECOMPILE);

    /* Misma fórmula de TotalRecords que 20260527-02 (tráficos sin pedimento) */
    SELECT @TotalRecords = @TotalRecords + COUNT(DISTINCT fgt.id_trafico)
    FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
        LEFT JOIN ADUASIS.dbo.fpedimento fped WITH (NOLOCK)
            ON fped.id_referencia = fgt.id_referencia
               AND fped.id_rectificacion = fgt.id_rectificacion
    WHERE fped.id_referencia IS NULL
          AND fgt.id_cliente = @idCliente
          AND
          (
              (@clavePedimento = '' OR EXISTS (SELECT 1 FROM @ClavesPed cv WHERE cv.Clave = fgt.id_regimen))
              OR
              (
                  @tipoOperacion = ''
                  OR CASE
                         WHEN fgt.cve_tipo_operacion = '0' THEN '1'
                         WHEN fgt.cve_tipo_operacion = '1' THEN '2'
                         ELSE ''
                     END = @tipoOperacion
              )
              OR (@FilterTipoPedimento = 0 OR fgt.id_tipo_pedimento = @tipoPedimento)
              OR
              (
                  @aduana = ''
                  OR fgt.id_aduana IS NULL
                  OR (ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, '')) LIKE '%' + @aduana + '%'
              )
          )
          AND (@pedimento = '' OR fgt.id_trafico LIKE '%' + @pedimento + '%')
          AND NOT EXISTS
          (
              SELECT 1
              FROM @OpsExcluidas op
              WHERE op.id_referencia = fgt.id_trafico
                    AND op.id_rectificacion IS NULL
                    AND op.pedimento IS NULL
          )
          AND
          (
              (
                  @SinFiltroFraccionPais = 1
                  AND EXISTS
                  (
                      SELECT 1
                      FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                      WHERE fdt.id_trafico = fgt.id_trafico
                  )
              )
              OR
              (
                  @SinFiltroFraccionPais = 0
                  AND EXISTS
                  (
                      SELECT 1
                      FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                          INNER JOIN @Fracciones AS frac
                              ON fdt.id_fraccion LIKE frac.Fraccion + '%'
                          INNER JOIN @Paises AS pais
                              ON (
                                     fdt.id_pais_origen LIKE '%' + pais.Pais + '%'
                                  OR fdt.id_pais_vendedor LIKE '%' + pais.Pais + '%'
                                 )
                      WHERE fdt.id_trafico = fgt.id_trafico
                  )
              )
          )
    OPTION (RECOMPILE);

    /* Resultados paginados — misma forma que 20260527-02; JOIN fdt corregido en rama pedimentos */
    SELECT *
    FROM
    (
        SELECT
            fped.id_referencia,
            fped.id_rectificacion,
            fped.id_patente AS patente,
            fped.id_aduana + fped.seccion AS aduana,
            fped.pedimento,
            fped.cve_tipo_operacion AS tipo_operacion,
            fped.id_regimen AS clave_pedimento,
            @TotalRecords AS TotalRecords
        FROM ADUASIS.dbo.fpedimento fped WITH (NOLOCK)
            INNER JOIN ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                ON fgt.id_referencia = fped.id_referencia
                   AND fgt.id_rectificacion = 0
        WHERE fped.fecha_pago_banco IS NULL
              AND fped.firma_banco IS NULL
              AND fped.id_cliente = @idCliente
              AND
              (
                  (@clavePedimento = '' OR EXISTS (SELECT 1 FROM @ClavesPed cv WHERE cv.Clave = fped.id_regimen))
                  OR (@tipoOperacion = '' OR fped.cve_tipo_operacion = @tipoOperacion)
                  OR (@FilterTipoPedimento = 0 OR fped.id_tipo_pedimento = @tipoPedimento)
                  OR (@aduana = '' OR (fped.id_aduana + fped.seccion) LIKE '%' + @aduana + '%')
              )
              AND
              (
                  @pedimento = ''
                  OR fped.pedimento LIKE '%' + @pedimento + '%'
                  OR fped.id_referencia LIKE '%' + @pedimento + '%'
              )
              AND fped.pedimento <> ''
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM @OpsExcluidas op
                  WHERE op.id_referencia = fped.id_referencia
                        AND op.id_rectificacion = fped.id_rectificacion
                        AND op.pedimento = fped.pedimento
              )
              AND
              (
                  (
                      @SinFiltroFraccionPais = 1
                      AND EXISTS
                      (
                          SELECT 1
                          FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                          WHERE fdt.id_trafico = fgt.id_trafico
                      )
                  )
                  OR
                  (
                      @SinFiltroFraccionPais = 0
                      AND EXISTS
                      (
                          SELECT 1
                          FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                              INNER JOIN @Fracciones AS frac
                                  ON fdt.id_fraccion LIKE frac.Fraccion + '%'
                              INNER JOIN @Paises AS pais
                                  ON (
                                         fdt.id_pais_origen LIKE '%' + pais.Pais + '%'
                                      OR fdt.id_pais_vendedor LIKE '%' + pais.Pais + '%'
                                     )
                          WHERE fdt.id_trafico = fgt.id_trafico
                      )
                  )
              )
        GROUP BY
            fped.id_referencia,
            fped.id_rectificacion,
            fped.id_patente,
            fped.id_aduana + fped.seccion,
            fped.pedimento,
            fped.cve_tipo_operacion,
            fped.id_regimen

        UNION ALL

        SELECT
            fgt.id_trafico AS id_referencia,
            NULL AS id_rectificacion,
            ISNULL(fgt.id_patente, '') AS patente,
            ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, '') AS aduana,
            '' AS pedimento,
            CASE
                WHEN fgt.cve_tipo_operacion = '0' THEN '1'
                WHEN fgt.cve_tipo_operacion = '1' THEN '2'
                ELSE ''
            END AS tipo_operacion,
            fgt.id_regimen AS clave_pedimento,
            @TotalRecords AS TotalRecords
        FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
            LEFT JOIN ADUASIS.dbo.fpedimento fped WITH (NOLOCK)
                ON fped.id_referencia = fgt.id_referencia
                   AND fped.id_rectificacion = fgt.id_rectificacion
        WHERE fped.id_referencia IS NULL
              AND fgt.id_cliente = @idCliente
              AND
              (
                  (@clavePedimento = '' OR EXISTS (SELECT 1 FROM @ClavesPed cv WHERE cv.Clave = fgt.id_regimen))
                  OR
                  (
                      @tipoOperacion = ''
                      OR CASE
                             WHEN fgt.cve_tipo_operacion = '0' THEN '1'
                             WHEN fgt.cve_tipo_operacion = '1' THEN '2'
                             ELSE ''
                         END = @tipoOperacion
                  )
                  OR (@FilterTipoPedimento = 0 OR fgt.id_tipo_pedimento = @tipoPedimento)
                  OR
                  (
                      @aduana = ''
                      OR fgt.id_aduana IS NULL
                      OR (ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, '')) LIKE '%' + @aduana + '%'
                  )
              )
              AND (@pedimento = '' OR fgt.id_trafico LIKE '%' + @pedimento + '%')
              AND NOT EXISTS
              (
                  SELECT 1
                  FROM @OpsExcluidas op
                  WHERE op.id_referencia = fgt.id_trafico
                        AND op.id_rectificacion IS NULL
                        AND op.pedimento IS NULL
              )
              AND
              (
                  (
                      @SinFiltroFraccionPais = 1
                      AND EXISTS
                      (
                          SELECT 1
                          FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                          WHERE fdt.id_trafico = fgt.id_trafico
                      )
                  )
                  OR
                  (
                      @SinFiltroFraccionPais = 0
                      AND EXISTS
                      (
                          SELECT 1
                          FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                              INNER JOIN @Fracciones AS frac
                                  ON fdt.id_fraccion LIKE frac.Fraccion + '%'
                              INNER JOIN @Paises AS pais
                                  ON (
                                         fdt.id_pais_origen LIKE '%' + pais.Pais + '%'
                                      OR fdt.id_pais_vendedor LIKE '%' + pais.Pais + '%'
                                     )
                          WHERE fdt.id_trafico = fgt.id_trafico
                      )
                  )
              )
        GROUP BY
            fgt.id_trafico,
            ISNULL(fgt.id_patente, ''),
            ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, ''),
            CASE
                WHEN fgt.cve_tipo_operacion = '0' THEN '1'
                WHEN fgt.cve_tipo_operacion = '1' THEN '2'
                ELSE ''
            END,
            fgt.id_regimen
    ) AS foo
    ORDER BY foo.pedimento, foo.id_referencia
    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY
    OPTION (RECOMPILE);
END;
GO
