/*
  Ajuste 07/2026 — Baseline csp_Ad_SugerenciaPedimentos
  Definición extraída del servidor 10.46.4.39 (ADUASIS) el 2026-07-02.

  Origen: OBJECT_DEFINITION(OBJECT_ID('dbo.csp_Ad_SugerenciaPedimentos'))
  Uso: referencia para la modificación pendiente de sugerencia de pedimentos
       en el marco del ajuste 072026 (nuevos campos AdCampos).

  Nota: script de despliegue con CREATE OR ALTER. No modificar docs/SQL/
        hasta promover el ajuste acordado.
*/
USE ADUASIS;
GO

CREATE OR ALTER PROCEDURE csp_Ad_SugerenciaPedimentos  
    --DECLARE   
    @idCliente VARCHAR(10) = '11886',  
    @idAdDocumento BIGINT = 3953,  
    @pedimento VARCHAR(14) = '21323492',  
    @clavePedimento VARCHAR(2) = '',  
    @tipoOperacion VARCHAR(1) = '',  
    @tipoPedimento VARCHAR(2) = '',  
    @aduana VARCHAR(3) = '',  
    @fraccion VARCHAR(MAX) = '27101992',  
    @pais VARCHAR(MAX) = 'USA',  
    @PageNumber INT = 1,  
    @PageSize INT = 10  
AS  
BEGIN  
    SET NOCOUNT ON;  
  
    -- Validar parámetros de paginación  
    IF @PageNumber < 1  
        SET @PageNumber = 1;  
    IF @PageSize < 1  
        SET @PageSize = 10;  
    IF @PageSize > 100  
        SET @PageSize = 100; -- Límite máximo  
  
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;  
  
    -- Contar total de registros  
    DECLARE @TotalRecords INT;  
  
    -- Tablas de multiples valores fracciones, paises yy claves de pedimento  
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
  
    -- Poblado de tablas  
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

    -- validación de valores vacios
    IF NOT EXISTS (SELECT 1 FROM @Fracciones)
        INSERT INTO @Fracciones
        (
            Fraccion
        )
        VALUES
        ('' -- Fraccion - varchar(8)
            )

    IF NOT EXISTS (SELECT 1 FROM @Paises)
        INSERT INTO @Paises
        (
            Pais
        )
        VALUES
        ('' -- Pais - varchar(100)
            )
  
     
    -- cálculo inicial de cantidades totales filtradas
    SELECT @TotalRecords  
        = COUNT(DISTINCT CAST(fped.id_referencia AS VARCHAR(8)) + '|' + CAST(fped.id_rectificacion AS VARCHAR(1)))  
    FROM ADUASIS.dbo.fpedimento fped WITH (NOLOCK)  
        CROSS JOIN @Fracciones frac  
        CROSS JOIN @Paises pais  
        INNER JOIN ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
            ON fgt.id_referencia = fped.id_referencia
               AND fgt.id_rectificacion = 0 -- fped.id_rectificacion
        INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
            ON fdt.id_trafico = fgt.id_trafico
            AND fdt.id_fraccion LIKE frac.Fraccion + '%'
            AND (fdt.id_pais_origen LIKE '%' + pais.Pais + '%'
                OR fdt.id_pais_vendedor LIKE '%' + pais.Pais + '%')
    WHERE fped.fecha_pago_banco IS NULL  
          AND fped.firma_banco IS NULL  
          AND fped.id_cliente = @idCliente  
          AND  
          (  
              (  
                  @clavePedimento = ''  
                  OR EXISTS (SELECT 1 FROM @ClavesPed cv WHERE cv.Clave = fped.id_regimen)
              )  
              OR  
              (  
                  @tipoOperacion = ''  
                  OR fped.cve_tipo_operacion = @tipoOperacion  
              )  
              OR  
              (  
                  ISNUMERIC(@tipoPedimento) = 0  
                  OR fped.id_tipo_pedimento = @tipoPedimento  
              )  
              OR  
              (  
                  @aduana = ''  
                  OR (fped.id_aduana + fped.seccion) LIKE '%' + @aduana + '%'  
              )  
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
                      FROM DesarrolloDB.dbo.ad_documento_operacion op WITH (NOLOCK)  
                      WHERE op.IdDocumento = @idAdDocumento  
                            AND op.id_referencia = fped.id_referencia  
                            AND op.id_rectificacion = fped.id_rectificacion  
                            AND op.pedimento = fped.pedimento  
                  ); 
                  
    -- integración de traficos sin pedimento
    SELECT @TotalRecords = @TotalRecords
        + COUNT(DISTINCT fgt.id_trafico)  
    FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
        CROSS JOIN @Fracciones frac  
        CROSS JOIN @Paises pais  
        INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
            ON fdt.id_trafico = fgt.id_trafico
            AND fdt.id_fraccion LIKE frac.Fraccion + '%'
            AND (fdt.id_pais_origen LIKE '%' + pais.Pais + '%'
                OR fdt.id_pais_vendedor LIKE '%' + pais.Pais + '%')
        LEFT JOIN ADUASIS.dbo.fpedimento fped WITH (NOLOCK) 
            ON fped.id_referencia = fgt.id_referencia
            AND fped.id_rectificacion = fgt.id_rectificacion
    WHERE fped.id_referencia IS NULL
          AND fgt.id_cliente = @idCliente  
          AND  
          (  
              (  
                  @clavePedimento = ''  
                  OR EXISTS (SELECT 1 FROM @ClavesPed cv WHERE cv.Clave = fgt.id_regimen)
              )  
              OR  
              (  
                  @tipoOperacion = ''  
                  OR CASE WHEN fgt.cve_tipo_operacion = '0' THEN '1' WHEN fgt.cve_tipo_operacion = '1' THEN '2' ELSE '' END = @tipoOperacion  
              )  
              OR  
              (  
                  ISNUMERIC(@tipoPedimento) = 0  
                  OR fgt.id_tipo_pedimento = @tipoPedimento  
              )  
              OR  
              (  
                  @aduana = '' 
                  OR fgt.id_aduana IS NULL   
                  OR (ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, '')) LIKE '%' + @aduana + '%'  
              )  
          )  
          AND  
          (  
              @pedimento = ''  
              OR fgt.id_trafico LIKE '%' + @pedimento + '%'  
          )    
          AND NOT EXISTS  
                  (  
                      SELECT 1  
                      FROM DesarrolloDB.dbo.ad_documento_operacion op WITH (NOLOCK)  
                      WHERE op.IdDocumento = @idAdDocumento  
                            AND op.id_referencia = fgt.id_trafico  
                            AND op.id_rectificacion IS NULL  
                            AND op.pedimento IS NULL  
                  ); 
  
    -- Retornar resultados paginados 
    SELECT *
    FROM 
    (SELECT fped.id_referencia,  
           fped.id_rectificacion,  
           fped.id_patente AS patente,  
           fped.id_aduana + fped.seccion AS aduana,  
           fped.pedimento,  
           fped.cve_tipo_operacion AS tipo_operacion,  
           fped.id_regimen AS clave_pedimento,  
           @TotalRecords AS TotalRecords  
    FROM ADUASIS.dbo.fpedimento fped WITH (NOLOCK)  
        CROSS JOIN @Fracciones frac  
        CROSS JOIN @Paises pais  
        INNER JOIN ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
            ON fgt.id_referencia = fped.id_referencia
               AND fgt.id_rectificacion = 0 -- fped.id_rectificacion
        INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
            ON fdt.id_trafico = fgt.id_trafico
            AND fdt.id_fraccion LIKE frac.Fraccion + '%'
            AND (fdt.id_pais_origen LIKE '%' + pais.Pais + '%'
                OR fdt.id_pais_vendedor LIKE '%' + pais.Pais + '%')
    WHERE fped.fecha_pago_banco IS NULL  
          AND fped.firma_banco IS NULL  
          AND fped.id_cliente = @idCliente  
          AND  
         (  
              (  
 @clavePedimento = ''  
                  OR EXISTS (SELECT 1 FROM @ClavesPed cv WHERE cv.Clave = fped.id_regimen)
              )  
              OR  
              (  
                  @tipoOperacion = ''  
                  OR fped.cve_tipo_operacion = @tipoOperacion  
              )  
              OR  
              (  
                  ISNUMERIC(@tipoPedimento) = 0  
                  OR fped.id_tipo_pedimento = @tipoPedimento  
              )  
              OR  
              (  
                  @aduana = ''  
                  OR (fped.id_aduana + fped.seccion) LIKE '%' + @aduana + '%'  
              )  
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
                      FROM DesarrolloDB.dbo.ad_documento_operacion op WITH (NOLOCK)  
                      WHERE op.IdDocumento = @idAdDocumento  
                            AND op.id_referencia = fped.id_referencia  
                            AND op.id_rectificacion = fped.id_rectificacion  
                            AND op.pedimento = fped.pedimento  
                  )  
    GROUP BY fped.id_referencia,  
             fped.id_rectificacion,  
             fped.id_patente,  
             fped.id_aduana + fped.seccion,  
             fped.pedimento,  
             fped.cve_tipo_operacion,  
             fped.id_regimen
    --ORDER BY fped.pedimento ASC
    UNION ALL
    SELECT fgt.id_trafico id_referencia,  
           NULL id_rectificacion,  
           ISNULL(fgt.id_patente, '') AS patente,  
           ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana,'') AS aduana,  
           '' pedimento,  
           CASE
                WHEN fgt.cve_tipo_operacion = '0' THEN '1'
                WHEN fgt.cve_tipo_operacion = '1' THEN '2'
                ELSE ''
           END AS tipo_operacion,  
           fgt.id_regimen AS clave_pedimento,  
           @TotalRecords AS TotalRecords 
    FROM ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
        CROSS JOIN @Fracciones frac  
        CROSS JOIN @Paises pais  
        INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
            ON fdt.id_trafico = fgt.id_trafico
            AND fdt.id_fraccion LIKE frac.Fraccion + '%'
            AND (fdt.id_pais_origen LIKE '%' + pais.Pais + '%'
                OR fdt.id_pais_vendedor LIKE '%' + pais.Pais + '%')
        LEFT JOIN ADUASIS.dbo.fpedimento fped WITH (NOLOCK) 
            ON fped.id_referencia = fgt.id_referencia
            AND fped.id_rectificacion = fgt.id_rectificacion
    WHERE fped.id_referencia IS NULL 
          AND fgt.id_cliente = @idCliente  
          AND  
          (  
              (  
                  @clavePedimento = ''  
                  OR EXISTS (SELECT 1 FROM @ClavesPed cv WHERE cv.Clave = fgt.id_regimen)
              )  
              OR  
              (  
                  @tipoOperacion = ''  
                  OR CASE WHEN fgt.cve_tipo_operacion = '0' THEN '1' WHEN fgt.cve_tipo_operacion = '1' THEN '2' ELSE '' END = @tipoOperacion  
              )  
              OR  
              (  
                  ISNUMERIC(@tipoPedimento) = 0  
                  OR fgt.id_tipo_pedimento = @tipoPedimento  
              )  
              OR  
              (  
                  @aduana = '' 
                  OR fgt.id_aduana IS NULL   
                  OR (ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana, '')) LIKE '%' + @aduana + '%'  
              )  
          )  
          AND  
          (  
              @pedimento = ''  
              OR fgt.id_trafico LIKE '%' + @pedimento + '%'  
          )    
    AND NOT EXISTS  
                  (  
           SELECT 1  
                      FROM DesarrolloDB.dbo.ad_documento_operacion op WITH (NOLOCK)  
                      WHERE op.IdDocumento = @idAdDocumento  
                            AND op.id_referencia = fgt.id_trafico  
                            AND op.id_rectificacion IS NULL  
                            AND op.pedimento IS NULL  
                  )
          GROUP BY
                fgt.id_trafico,  
                ISNULL(fgt.id_patente, ''),  
                ISNULL(fgt.id_aduana, '') + ISNULL(fgt.seccion_aduana,''),  
                CASE
                     WHEN fgt.cve_tipo_operacion = '0' THEN '1'
                     WHEN fgt.cve_tipo_operacion = '1' THEN '2'
                     ELSE ''
                END,  
                fgt.id_regimen
         --ORDER BY fgt.id_trafico
    ) foo
    ORDER BY foo.pedimento, foo.id_referencia OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;  
END;
GO

