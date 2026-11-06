USE DesarrolloDB
GO

/*
  csp_ad_InsertaDatosPedimento_v2
  - Misma lógica que v1 (incl. fgtrafico.id_rectificacion = @idRectificacion en ftrafico_caso pedimento).
  - MensajeEjecucion (result set): bitácora concatenada (CRLF) con contexto, tablas variables y @@ROWCOUNT por DML.
  - Result set final: Resultado (BIT) + MensajeEjecucion.
    Resultado = 1 para identificador general (1) al completar el SP.
    En clasificación partida (2) o permiso (3), Resultado = 1 si hubo filas afectadas o si existen
    partidas/permisos candidatos con los filtros del documento, aunque NOT EXISTS evite DML por duplicados.
    Clasificaciones no soportadas siguen devolviendo 0.
*/
CREATE PROCEDURE csp_ad_InsertaDatosPedimento_v2    
    --DECLARE
    @idDocumento BIGINT = 724,    
    @idReferencia VARCHAR(10) = 'SPF-23518',    
    @idRectificacion DECIMAL(1, 0) = 0,    
    @pedimento VARCHAR(8) = '6023518'    
AS    
BEGIN    
    SET NOCOUNT ON;

    DECLARE @MensajeEjecucion NVARCHAR(MAX);
    DECLARE @rc INT;
    DECLARE @AfectacionPartidaPermiso INT = 0; -- filas DML: identificador partida + permiso (tráfico/pedimento)
    DECLARE @AplicaPartidaPermiso BIT = 0; -- existen partidas/permisos candidatos aunque no haya DML por duplicados
    DECLARE @NL NCHAR(2) = NCHAR(13) + NCHAR(10);
    DECLARE @modoEjecucion NVARCHAR(40) =
        CASE
            WHEN @pedimento IS NULL AND @idRectificacion IS NULL THEN N'tráfico'
            ELSE N'pedimento'
        END;
    SET @MensajeEjecucion = N'';

    -- recuperación de clasificación del documento      
    DECLARE @idClasificacion INT;    
    SELECT @idClasificacion = m.IdClasificacion    
    FROM DesarrolloDB.dbo.ad_documentos ad WITH (NOLOCK)    
        INNER JOIN DesarrolloDB.dbo.ad_motor_config_header m WITH (NOLOCK)    
            ON m.Id = ad.IdMotorConfigHeader    
    WHERE ad.Id = @idDocumento;    
    
    -- asigna el valor de las fracciones      
    DECLARE @cfrac VARCHAR(MAX); 
    DECLARE @cpart VARCHAR(MAX);

    SELECT @cfrac = Valor    
    FROM DesarrolloDB.dbo.ad_documentos_campos WITH (NOLOCK)    
    WHERE IdDocumento = @idDocumento    
            AND IdCampo = 9;  
              
    SELECT @cpart = Valor    
    FROM DesarrolloDB.dbo.ad_documentos_campos WITH (NOLOCK)    
    WHERE IdDocumento = @idDocumento    
            AND IdCampo = 7;    
    
    -- generamos lista de fracciones      
    DECLARE @fracciones TABLE    
    (    
        fraccion VARCHAR(8)    
    );    
    INSERT INTO @fracciones    
    (    
        fraccion    
    )    
    SELECT LEFT(splitdata, 8)   
    FROM ADUASIS.dbo.FN_SplitSTR(REPLACE(@cfrac, '.', ''), ';');   

    SET @rc = @@ROWCOUNT;
    SET @MensajeEjecucion += CONCAT(N'Se identificaron ', CAST(@rc AS NVARCHAR(20)), N' fracciones en el documento.', @NL);
        
    -- generamos lista de no de parte
    DECLARE @nopartes TABLE 
    (
        noparte VARCHAR(1000)
    )
    INSERT INTO @nopartes
    (
        noparte
    )
    SELECT splitdata
    FROM ADUASIS.dbo.FN_SplitSTR(@cpart, ';'); 

    SET @rc = @@ROWCOUNT;
    SET @MensajeEjecucion += CONCAT(N'Se identificaron ', CAST(@rc AS NVARCHAR(20)), N' números de parte en el documento.', @NL);

    SET @MensajeEjecucion += CONCAT(N'Se inició el proceso en ', @modoEjecucion, N'.', @NL);
    
    -- secuencial de identificadores
    DECLARE @secuencial INT;

    -- manejo solo de datos de tráfico
    IF @pedimento IS NULL AND @idRectificacion IS NULL 
    BEGIN
        -- manejo de identificador general      
        IF @idClasificacion = 1    
        BEGIN    
            -- determian secuencial     
            SELECT @secuencial = MAX(secuencial) + 1    
            FROM ADUASIS.dbo.ftrafico_caso WITH (NOLOCK)    
            WHERE id_trafico = @idReferencia    ;    
    
            INSERT INTO ADUASIS.dbo.ftrafico_caso    
            (    
                id_trafico,    
                secuencial,    
                tipo_caso,    
                iden_caso,    
                complemento2,    
                complemento3    
            )    
            SELECT @idReferencia id_referencia,     
                   ISNULL(@secuencial, 1) secuencial,    
                   Identificador tipo_caso,    
                   Complemento iden_caso,    
                   Complemento2 complemento2,    
                   Complemento3 complemento3    
            FROM DesarrolloDB.dbo.ad_documentos_identificador_general WITH (NOLOCK)    
            WHERE IdDocumento = @idDocumento
            AND NOT EXISTS (
                SELECT 1 FROM ADUASIS.dbo.ftrafico_caso fc WITH(NOLOCK) 
                WHERE fc.id_trafico = @idReferencia
                AND fc.tipo_caso = Identificador AND ISNULL(fc.iden_caso, '') = ISNULL(Complemento, '') 
                AND ISNULL(fc.complemento2, '') = ISNULL(Complemento2, '') AND ISNULL(fc.complemento3, '') = ISNULL(Complemento3, ''));  

            SET @rc = @@ROWCOUNT;
            SET @MensajeEjecucion += CONCAT(N'Se agregaron ', CAST(@rc AS NVARCHAR(20)), N' registros nuevos de información general en tráfico.', @NL);
        END;
        IF @idClasificacion = 2    
        BEGIN 
            IF EXISTS (
                SELECT 1
                FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                INNER JOIN @fracciones frac ON fdt.id_fraccion LIKE frac.fraccion + '%'
                WHERE fdt.id_trafico = @idReferencia
                AND (@cpart = ''
                    OR EXISTS (SELECT 1 FROM @nopartes np WHERE np.noparte = fdt.id_producto))
                AND EXISTS (
                    SELECT 1
                    FROM DesarrolloDB.dbo.ad_documentos_identificador_partida p WITH (NOLOCK)
                    WHERE p.IdDocumento = @idDocumento
                )
            )
            BEGIN
                SET @AplicaPartidaPermiso = 1;
                SET @MensajeEjecucion += CONCAT(N'Se encontraron partidas relacionadas para procesar en tráfico.', @NL);
            END
            ELSE
            BEGIN
                SET @MensajeEjecucion += CONCAT(N'No se encontraron partidas relacionadas para procesar en tráfico.', @NL);
            END;

            -- identificadores a nivel partida
            INSERT INTO ADUASIS.dbo.ftrafico_detalle_caso
            (
                id_trafico,
                numero_secuencial,
                numero_identificador,
                tipo_caso,
                iden_caso,
                complemento2,
                complemento3
            )
            SELECT DISTINCT  
                fdt.id_trafico,  
                fdt.num_secuencial,  
                (SELECT ISNULL(MAX(numero_identificador), 0) + 1 numero_identificador  
                FROM ADUASIS.dbo.ftrafico_detalle_caso cc WITH(NOLOCK)   
                WHERE cc.id_trafico = fdt.id_trafico AND cc.numero_secuencial = fdt.num_secuencial  
                ) numero_identificador,  
                p.Identificador tipo_caso,  
                p.Complemento1 iden_caso,  
                p.Complemento2 complemento2,  
                p.Complemento3 complemento3  
            FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
            INNER JOIN @fracciones frac ON fdt.id_fraccion LIKE frac.fraccion + '%'  
            CROSS APPLY  
                (SELECT   
                        p.Identificador,  
                        p.Complemento1,  
                        p.Complemento2,
                        p.Complemento3
                FROM DesarrolloDB.dbo.ad_documentos_identificador_partida p WITH (NOLOCK)    
                WHERE p.IdDocumento = @idDocumento  
                ) p  
            WHERE fdt.id_trafico = @idReferencia
            AND (@cpart = ''
                OR EXISTS (SELECT noparte FROM @nopartes np WHERE np.noparte = fdt.id_producto))
            AND NOT EXISTS (SELECT 1 FROM ADUASIS.dbo.ftrafico_detalle_caso fdc WITH(NOLOCK)
                            WHERE fdc.id_trafico = @idReferencia AND fdc.numero_secuencial = fdt.num_secuencial
                            AND fdc.tipo_caso = p.Identificador AND ISNULL(fdc.iden_caso, '') = ISNULL(p.Complemento1, '')
                            AND ISNULL(fdc.complemento2, '') = ISNULL(p.Complemento2, '') AND ISNULL(fdc.complemento3, '') = ISNULL(p.Complemento3, '')
                           );

            SET @rc = @@ROWCOUNT;
            SET @AfectacionPartidaPermiso += @rc;
            SET @MensajeEjecucion += CONCAT(N'Se agregaron ', CAST(@rc AS NVARCHAR(20)), N' identificadores nuevos por partida en tráfico.', @NL);

            -- ident caso en catálogo de productos
            INSERT INTO ADUASIS.dbo.frel_prod_ident_obli
            (
                id_cliente,
                id_proveedor,
                id_producto,
                id_regimen,
                tipo_caso,
                iden_caso,
                complemento2,
                complemento3,
                idPermisoBBB,
                cve_tipo_operacion,
                fec_venc,
                id_fraccion,
                id_pais_origen
            )
            SELECT DISTINCT  
                fgt.id_cliente,  
                fdt.id_proveedor,  
                fdt.id_producto, 
                fgt.id_regimen,
                p.Identificador tipo_caso,  
                p.Complemento1 iden_caso,  
                p.Complemento2 complemento2,  
                p.Complemento3 complemento3  ,
                NULL idPermisoBBB,
                fgt.cve_tipo_operacion,
                p.FechaVigenciaFin fec_venc,
                null id_fraccion,
                null id_pais_origen
            FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
            INNER JOIN ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK) 
                ON fgt.id_trafico = fdt.id_trafico
            INNER JOIN @fracciones frac ON fdt.id_fraccion LIKE frac.fraccion + '%'  
            CROSS APPLY  
                (SELECT   
                        p.Identificador,  
                        p.Complemento1,  
                        p.Complemento2,
                        p.Complemento3,
                        d.FechaVigenciaFin
                FROM DesarrolloDB.dbo.ad_documentos_identificador_partida p WITH (NOLOCK)
                INNER JOIN DesarrolloDB.dbo.ad_documentos d WITH (NOLOCK)
                    ON d.Id = p.IdDocumento
                WHERE p.IdDocumento = @idDocumento  
                ) p  
            WHERE fdt.id_trafico = @idReferencia
            AND (@cpart = ''
                OR EXISTS (SELECT noparte FROM @nopartes np WHERE np.noparte = fdt.id_producto))
            AND NOT EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_prod_ident_obli fdc WITH(NOLOCK)
                            WHERE fdc.id_cliente = fgt.id_cliente AND fdc.id_proveedor = fdt.id_proveedor AND fdc.id_producto = fdt.id_producto
                            AND fdc.id_regimen = fgt.id_regimen AND fdc.cve_tipo_operacion = fgt.cve_tipo_operacion
                            AND fdc.tipo_caso = p.Identificador AND ISNULL(fdc.iden_caso, '') = ISNULL(p.Complemento1, '')
                            AND ISNULL(fdc.complemento2, '') = ISNULL(p.Complemento2, '') AND ISNULL(fdc.complemento3, '') = ISNULL(p.Complemento3, '')
                           );

            SET @rc = @@ROWCOUNT;
            SET @AfectacionPartidaPermiso += @rc;
            SET @MensajeEjecucion += CONCAT(N'Se agregaron ', CAST(@rc AS NVARCHAR(20)), N' registros nuevos en los productos relacionados.', @NL);

            -- cambio de advaloren
            IF EXISTS (SELECT   
                        1
                FROM DesarrolloDB.dbo.ad_documentos_identificador_partida p WITH (NOLOCK)    
                WHERE p.IdDocumento = @idDocumento  
                AND p.Identificador = 'TL' 
                AND p.Complemento1 = 'USA')
            BEGIN
                -- actualización de advaloren
                UPDATE fdt
                SET fdt.id_tipo_advalorem = '001',
                    fdt.advalorem = 0
                FROM ADUASIS.dbo.fdtrafico fdt
                INNER JOIN @fracciones frac ON fdt.id_fraccion LIKE frac.fraccion + '%'  
                INNER JOIN ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                    ON fdt.id_trafico = fgt.id_trafico
                WHERE
                    fdt.id_trafico = @idReferencia
                    AND (
                    @cpart = ''
                    OR 
                    EXISTS (SELECT 1 FROM @nopartes np WHERE np.noparte = fdt.id_producto)
                    );

                SET @rc = @@ROWCOUNT;
                SET @AfectacionPartidaPermiso += @rc;
                SET @MensajeEjecucion += CONCAT(N'Se actualizaron ', CAST(@rc AS NVARCHAR(20)), N' registros de ad valorem en tráfico.', @NL);

                -- advaloren para catálogo de productos
                INSERT INTO ADUASIS.dbo.frel_prod_tipo_adval
                (
                    id_cliente,
                    id_proveedor,
                    id_producto,
                    id_regimen,
                    id_tipo_advalorem,
                    fraccion,
                    origen,
                    cve_tipo_operacion,
                    fecha_inicio,
                    fecha_vencimiento
                )
                SELECT  
                    fgt.id_cliente,  
                    fdt.id_proveedor,  
                    fdt.id_producto, 
                    fgt.id_regimen,
                    '001' id_tipo_advalorem,
                    LEFT(fdt.id_fraccion, 6) fraccion,
                    MIN(fdt.id_pais_origen) origen,
                    fgt.cve_tipo_operacion,
                    MAX(p.FechaVigenciaInicio) fecha_inicio,
                    MAX(p.FechaVigenciaFin) fecha_vencimiento
                FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                INNER JOIN ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK) 
                    ON fgt.id_trafico = fdt.id_trafico
                INNER JOIN @fracciones frac ON fdt.id_fraccion LIKE frac.fraccion + '%'  
                CROSS APPLY  
                    (SELECT   
                            p.Identificador,  
                            p.Complemento1,  
                            p.Complemento2,
                            p.Complemento3,
                            d.FechaVigenciaInicio,
                            d.FechaVigenciaFin
                    FROM DesarrolloDB.dbo.ad_documentos_identificador_partida p WITH (NOLOCK)
                    INNER JOIN DesarrolloDB.dbo.ad_documentos d WITH (NOLOCK)
                        ON d.Id = p.IdDocumento
                    WHERE p.IdDocumento = @idDocumento  
                    ) p  
                WHERE fdt.id_trafico = @idReferencia
                AND (@cpart = ''
                    OR EXISTS (SELECT noparte FROM @nopartes np WHERE np.noparte = fdt.id_producto))
                AND NOT EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_prod_tipo_adval fdc WITH(NOLOCK)
                                WHERE fdc.id_cliente = fgt.id_cliente AND fdc.id_proveedor = fdt.id_proveedor AND fdc.id_producto = fdt.id_producto
                                AND fdc.id_regimen = fgt.id_regimen AND fdc.cve_tipo_operacion = fgt.cve_tipo_operacion
                                AND fdc.id_tipo_advalorem = '001'
                               )
                GROUP BY
                    fgt.id_cliente,  
                    fdt.id_proveedor,  
                    fdt.id_producto, 
                    fgt.id_regimen,
                    LEFT(fdt.id_fraccion, 6),
                    fgt.cve_tipo_operacion;

                SET @rc = @@ROWCOUNT;
                SET @AfectacionPartidaPermiso += @rc;
                SET @MensajeEjecucion += CONCAT(N'Se agregaron ', CAST(@rc AS NVARCHAR(20)), N' configuraciones de ad valorem para los productos relacionados.', @NL);
            END
            ELSE
            BEGIN
                SET @MensajeEjecucion += CONCAT(N'No fue necesario ajustar el ad valorem por origen Estados Unidos en este documento.', @NL);
            END;
        END;

        IF (@idClasificacion IS NULL OR @idClasificacion NOT IN (1, 2))
            SET @MensajeEjecucion += CONCAT(N'No se realizaron cambios en tráfico porque el documento no corresponde a información general ni por partida.', @NL);
    END 
    -- manejo de pedimento
    ELSE 
    BEGIN 
        -- manejo de identificador general      
        IF @idClasificacion = 1    
        BEGIN    
            -- determian secuencial          
            SELECT @secuencial = MAX(secuencial) + 1    
            FROM ADUASIS.dbo.fpedimento_caso WITH (NOLOCK)    
            WHERE id_referencia = @idReferencia    
                  AND id_rectificacion = @idRectificacion;    
    
            INSERT INTO ADUASIS.dbo.fpedimento_caso    
            (    
                id_referencia,    
                id_rectificacion,    
                secuencial,    
                tipo_caso,    
                iden_caso,    
                complemento2,    
                complemento3    
            )    
            SELECT @idReferencia id_referencia,    
                   @idRectificacion id_rectificacion,    
                   ISNULL(@secuencial, 1) secuencial,    
                   Identificador tipo_caso,    
                   Complemento iden_caso,    
                   Complemento2 complemento2,    
                   Complemento3 complemento3    
            FROM DesarrolloDB.dbo.ad_documentos_identificador_general WITH (NOLOCK)    
            WHERE IdDocumento = @idDocumento
            AND NOT EXISTS (
                SELECT 1 FROM ADUASIS.dbo.fpedimento_caso fc WITH(NOLOCK) 
                WHERE fc.id_referencia = @idReferencia AND fc.id_rectificacion = @idRectificacion 
                AND fc.tipo_caso = Identificador AND ISNULL(fc.iden_caso, '') = ISNULL(Complemento, '') 
                AND ISNULL(fc.complemento2, '') = ISNULL(Complemento2, '') AND ISNULL(fc.complemento3, '') = ISNULL(Complemento3, ''));    

            SET @rc = @@ROWCOUNT;
            SET @MensajeEjecucion += CONCAT(N'Se agregaron ', CAST(@rc AS NVARCHAR(20)), N' registros nuevos de información general en pedimento.', @NL);

            -- identificador para tráfico
            SELECT @secuencial = MAX(secuencial) + 1    
            FROM ADUASIS.dbo.ftrafico_caso WITH (NOLOCK)    
            WHERE id_trafico = @idReferencia    ;    
    
            INSERT INTO ADUASIS.dbo.ftrafico_caso    
            (    
                id_trafico,    
                secuencial,    
                tipo_caso,    
                iden_caso,    
                complemento2,    
                complemento3    
            )    
            SELECT @idReferencia id_referencia,     
                   ISNULL(@secuencial, 1) secuencial,    
                   Identificador tipo_caso,    
                   Complemento iden_caso,    
                   Complemento2 complemento2,    
                   Complemento3 complemento3    
            FROM DesarrolloDB.dbo.ad_documentos_identificador_general WITH (NOLOCK)    
            WHERE IdDocumento = @idDocumento
            AND NOT EXISTS (
                SELECT 1 FROM ADUASIS.dbo.ftrafico_caso fc WITH(NOLOCK) 
                INNER JOIN ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK) 
                    ON fgt.id_trafico = fc.id_trafico
                    AND fgt.id_referencia = @idReferencia 
                    AND fgt.id_rectificacion = @idRectificacion
                WHERE fc.tipo_caso = Identificador AND ISNULL(fc.iden_caso, '') = ISNULL(Complemento, '') 
                AND ISNULL(fc.complemento2, '') = ISNULL(Complemento2, '') AND ISNULL(fc.complemento3, '') = ISNULL(Complemento3, ''));  

            SET @rc = @@ROWCOUNT;
            SET @MensajeEjecucion += CONCAT(N'Se agregaron ', CAST(@rc AS NVARCHAR(20)), N' registros nuevos de información general en tráfico.', @NL);
        END    
        ELSE    
        BEGIN    
            -- manejo de identificador partida      
            IF @idClasificacion = 2    
            BEGIN    
                IF EXISTS (
                    SELECT 1
                    FROM ADUASIS.dbo.fpedimento fped WITH(NOLOCK)
                    INNER JOIN ADUASIS.dbo.fpedimento_detalle fdet WITH(NOLOCK)
                        ON fdet.id_referencia = fped.id_referencia
                            AND fdet.id_rectificacion = fped.id_rectificacion
                    INNER JOIN ADUASIS.dbo.fpedimento_trafico AS fpedtraf WITH (NOLOCK)
                        ON fpedtraf.id_referencia = fped.id_referencia
                            AND fpedtraf.id_rectificacion = fped.id_rectificacion
		                    AND fpedtraf.referencia_secuencial = fdet.numero_secuencial
                    INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                        ON fdt.id_trafico = fpedtraf.id_trafico
                            AND fdt.id_producto = fpedtraf.id_producto
                            AND fdt.num_secuencial = fpedtraf.trafico_secuencial
                    INNER JOIN @fracciones frac ON fdet.id_fraccion LIKE frac.fraccion + '%'
                    WHERE fped.id_referencia = @idReferencia
                    AND fped.id_rectificacion = @idRectificacion
                    AND fped.pedimento = @pedimento
                    AND (@cpart = ''
                        OR EXISTS (SELECT 1 FROM @nopartes np WHERE np.noparte = fdt.id_producto))
                    AND EXISTS (
                        SELECT 1
                        FROM DesarrolloDB.dbo.ad_documentos_identificador_partida p WITH (NOLOCK)
                        WHERE p.IdDocumento = @idDocumento
                    )
                )
                BEGIN
                    SET @AplicaPartidaPermiso = 1;
                    SET @MensajeEjecucion += CONCAT(N'Se encontraron partidas relacionadas para procesar en pedimento.', @NL);
                END
                ELSE
                BEGIN
                    SET @MensajeEjecucion += CONCAT(N'No se encontraron partidas relacionadas para procesar en pedimento.', @NL);
                END;

                INSERT INTO ADUASIS.dbo.fpedimento_detalle_caso  
                (  
                    id_referencia,  
                    id_rectificacion,  
                    numero_secuencial,  
                    numero_identificador,  
                    tipo_caso,  
                    iden_caso,  
                    complemento2,  
                    complemento3  
                )  
                SELECT DISTINCT  
                    fped.id_referencia,  
                    fped.id_rectificacion,  
                    fdet.numero_secuencial,  
                    (SELECT ISNULL(MAX(numero_identificador), 0) + 1 numero_identificador  
                    FROM ADUASIS.dbo.fpedimento_detalle_caso cc WITH(NOLOCK)   
                    WHERE cc.id_referencia = fped.id_referencia AND cc.id_rectificacion = fped.id_rectificacion AND cc.numero_secuencial = fdet.numero_secuencial  
                    ) numero_identificador,  
                    p.Identificador tipo_caso,  
                    p.Complemento1 iden_caso,  
                    p.Complemento2 complemento2,  
                    p.Complemento3 complemento3  
                FROM ADUASIS.dbo.fpedimento fped WITH(NOLOCK)
                INNER JOIN ADUASIS.dbo.fpedimento_detalle fdet WITH(NOLOCK)
                    ON fdet.id_referencia = fped.id_referencia
                        AND fdet.id_rectificacion = fped.id_rectificacion
                INNER JOIN ADUASIS.dbo.fpedimento_trafico AS fpedtraf WITH (NOLOCK)
                    ON fpedtraf.id_referencia = fped.id_referencia
                        AND fpedtraf.id_rectificacion = fped.id_rectificacion
		                AND fpedtraf.referencia_secuencial = fdet.numero_secuencial
                INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                    ON fdt.id_trafico = fpedtraf.id_trafico
                        AND fdt.id_producto = fpedtraf.id_producto
                        AND fdt.num_secuencial = fpedtraf.trafico_secuencial
                INNER JOIN @fracciones frac ON fdet.id_fraccion LIKE frac.fraccion + '%'  
                CROSS APPLY  
                    (SELECT   
                           p.Identificador,  
                           p.Complemento1,  
                           p.Complemento2,
                           p.Complemento3
                    FROM DesarrolloDB.dbo.ad_documentos_identificador_partida p WITH (NOLOCK)    
                    WHERE p.IdDocumento = @idDocumento  
                    ) p  
                WHERE fped.id_referencia = @idReferencia  
                AND fped.id_rectificacion = @idRectificacion  
                AND fped.pedimento = @pedimento
                AND (@cpart = ''
                    OR EXISTS (SELECT noparte FROM @nopartes np WHERE np.noparte = fdt.id_producto))
                AND NOT EXISTS (SELECT 1 FROM ADUASIS.dbo.fpedimento_detalle_caso fdc WITH(NOLOCK)
                                WHERE fdc.id_referencia = @idReferencia AND fdc.id_rectificacion = @idRectificacion AND fdc.numero_secuencial = fdet.numero_secuencial
                                AND fdc.tipo_caso = p.Identificador AND ISNULL(fdc.iden_caso, '') = ISNULL(p.Complemento1, '')
                                AND ISNULL(fdc.complemento2, '') = ISNULL(p.Complemento2, '') AND ISNULL(fdc.complemento3, '') = ISNULL(p.Complemento3, '')
                               );

                SET @rc = @@ROWCOUNT;
                SET @AfectacionPartidaPermiso += @rc;
                SET @MensajeEjecucion += CONCAT(N'Se agregaron ', CAST(@rc AS NVARCHAR(20)), N' identificadores nuevos por partida en pedimento.', @NL);

                -- identificadores en tráfico a nivel partida
                INSERT INTO ADUASIS.dbo.ftrafico_detalle_caso
                (
                    id_trafico,
                    numero_secuencial,
                    numero_identificador,
                    tipo_caso,
                    iden_caso,
                    complemento2,
                    complemento3
                )
                SELECT DISTINCT  
                    fdt.id_trafico,  
                    fdt.num_secuencial,  
                    (SELECT ISNULL(MAX(cc.numero_identificador), 0) + 1 numero_identificador  
                    FROM ADUASIS.dbo.ftrafico_detalle_caso cc WITH(NOLOCK)   
                    WHERE cc.id_trafico = fdt.id_trafico AND cc.numero_secuencial = fdt.num_secuencial  
                    ) numero_identificador,  
                    p.Identificador tipo_caso,  
                    p.Complemento1 iden_caso,  
                    p.Complemento2 complemento2,  
                    p.Complemento3 complemento3  
                FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                INNER JOIN ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK)
                    ON fgt.id_trafico = fdt.id_trafico
                    AND fgt.id_referencia = @idReferencia
                    AND fgt.id_rectificacion = @idRectificacion
                INNER JOIN @fracciones frac ON fdt.id_fraccion LIKE frac.fraccion + '%'  
                CROSS APPLY  
                    (SELECT   
                           p.Identificador,  
                           p.Complemento1,  
                           p.Complemento2,
                           p.Complemento3
                    FROM DesarrolloDB.dbo.ad_documentos_identificador_partida p WITH (NOLOCK)    
                    WHERE p.IdDocumento = @idDocumento  
                    ) p  
                WHERE (@cpart = ''
                    OR EXISTS (SELECT noparte FROM @nopartes np WHERE np.noparte = fdt.id_producto))
                    AND NOT EXISTS (SELECT 1 FROM ADUASIS.dbo.ftrafico_detalle_caso fdc WITH(NOLOCK)
                                    WHERE fdc.id_trafico = fdt.id_trafico AND fdc.numero_secuencial = fdt.num_secuencial
                                    AND fdc.tipo_caso = p.Identificador AND ISNULL(fdc.iden_caso, '') = ISNULL(p.Complemento1, '')
                                    AND ISNULL(fdc.complemento2, '') = ISNULL(p.Complemento2, '') AND ISNULL(fdc.complemento3, '') = ISNULL(p.Complemento3, '')
                                   );

                SET @rc = @@ROWCOUNT;
                SET @AfectacionPartidaPermiso += @rc;
                SET @MensajeEjecucion += CONCAT(N'Se agregaron ', CAST(@rc AS NVARCHAR(20)), N' identificadores nuevos por partida en tráfico.', @NL);

                -- ident caso en catálogo de productos
                INSERT INTO ADUASIS.dbo.frel_prod_ident_obli
                (
                    id_cliente,
                    id_proveedor,
                    id_producto,
                    id_regimen,
                    tipo_caso,
                    iden_caso,
                    complemento2,
                    complemento3,
                    idPermisoBBB,
                    cve_tipo_operacion,
                    fec_venc,
                    id_fraccion,
                    id_pais_origen
                )
                SELECT DISTINCT  
                    fgt.id_cliente,  
                    fdt.id_proveedor,  
                    fdt.id_producto, 
                    fgt.id_regimen,
                    p.Identificador tipo_caso,  
                    p.Complemento1 iden_caso,  
                    p.Complemento2 complemento2,  
                    p.Complemento3 complemento3  ,
                    NULL idPermisoBBB,
                    fgt.cve_tipo_operacion,
                    p.FechaVigenciaFin fec_venc,
                    null id_fraccion,
                    null id_pais_origen
                FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                INNER JOIN ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK) 
                    ON fgt.id_trafico = fdt.id_trafico
                    AND fgt.id_referencia = @idReferencia
                    AND fgt.id_rectificacion = @idRectificacion
                INNER JOIN @fracciones frac ON fdt.id_fraccion LIKE frac.fraccion + '%'  
                CROSS APPLY  
                    (SELECT   
                            p.Identificador,  
                            p.Complemento1,  
                            p.Complemento2,
                            p.Complemento3,
                            d.FechaVigenciaFin
                    FROM DesarrolloDB.dbo.ad_documentos_identificador_partida p WITH (NOLOCK)
                    INNER JOIN DesarrolloDB.dbo.ad_documentos d WITH (NOLOCK)
                        ON d.Id = p.IdDocumento
                    WHERE p.IdDocumento = @idDocumento  
                    ) p  
                WHERE (@cpart = ''
                    OR EXISTS (SELECT noparte FROM @nopartes np WHERE np.noparte = fdt.id_producto))
                AND NOT EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_prod_ident_obli fdc WITH(NOLOCK)
                                WHERE fdc.id_cliente = fgt.id_cliente AND fdc.id_proveedor = fdt.id_proveedor AND fdc.id_producto = fdt.id_producto
                                AND fdc.id_regimen = fgt.id_regimen AND fdc.cve_tipo_operacion = fgt.cve_tipo_operacion
                                AND fdc.tipo_caso = p.Identificador AND ISNULL(fdc.iden_caso, '') = ISNULL(p.Complemento1, '')
                                AND ISNULL(fdc.complemento2, '') = ISNULL(p.Complemento2, '') AND ISNULL(fdc.complemento3, '') = ISNULL(p.Complemento3, '')
                               );
            
                SET @rc = @@ROWCOUNT;
                SET @AfectacionPartidaPermiso += @rc;
                SET @MensajeEjecucion += CONCAT(N'Se agregaron ', CAST(@rc AS NVARCHAR(20)), N' registros nuevos en los productos relacionados.', @NL);

                -- cambio de advaloren
                IF EXISTS (SELECT   
                           1
                    FROM DesarrolloDB.dbo.ad_documentos_identificador_partida p WITH (NOLOCK)    
                    WHERE p.IdDocumento = @idDocumento  
                    AND p.Identificador = 'TL' 
                    AND p.Complemento1 = 'USA')
                BEGIN
                    -- actualización de advaloren en pedimento detalle
                    UPDATE det
                    SET det.advalorem = 0,
                    det.id_tipo_advalorem = '001'
                    FROM ADUASIS.dbo.fpedimento_detalle det
                    INNER JOIN ADUASIS.dbo.fpedimento_detalle_caso fcaso ON fcaso.id_referencia = det.id_referencia
                        AND fcaso.id_rectificacion = det.id_rectificacion
                        AND fcaso.numero_secuencial = det.numero_secuencial
                    WHERE det.id_referencia = @idReferencia
                    AND det.id_rectificacion = @idRectificacion
                    AND fcaso.tipo_caso = 'TL'
                    AND fcaso.iden_caso = 'USA';

                    SET @rc = @@ROWCOUNT;
                    SET @AfectacionPartidaPermiso += @rc;
                    SET @MensajeEjecucion += CONCAT(N'Se actualizaron ', CAST(@rc AS NVARCHAR(20)), N' registros de ad valorem en pedimento.', @NL);

                    -- actualización de advaloren
                    UPDATE fdt
                    SET fdt.id_tipo_advalorem = '001',
                        fdt.advalorem = 0
                    FROM ADUASIS.dbo.fdtrafico fdt
                    INNER JOIN @fracciones frac ON fdt.id_fraccion LIKE frac.fraccion + '%'  
                    INNER JOIN ADUASIS.dbo.fgtrafico AS fgt WITH (NOLOCK)
                        ON fdt.id_trafico = fgt.id_trafico
                    WHERE
                        fgt.id_referencia = @idReferencia
                        AND fgt.id_rectificacion = @idRectificacion
                        AND (@cpart = ''
                        OR 
                        EXISTS (SELECT 1 FROM @nopartes np WHERE np.noparte = fdt.id_producto)
                        );

                    SET @rc = @@ROWCOUNT;
                    SET @AfectacionPartidaPermiso += @rc;
                    SET @MensajeEjecucion += CONCAT(N'Se actualizaron ', CAST(@rc AS NVARCHAR(20)), N' registros de ad valorem en tráfico.', @NL);

                    -- advaloren para catálogo de productos
                    INSERT INTO ADUASIS.dbo.frel_prod_tipo_adval
                    (
                        id_cliente,
                        id_proveedor,
                        id_producto,
                        id_regimen,
                        id_tipo_advalorem,
                        fraccion,
                        origen,
                        cve_tipo_operacion,
                        fecha_inicio,
                        fecha_vencimiento
                    )
                    SELECT  
                        fgt.id_cliente,  
                        fdt.id_proveedor,  
                        fdt.id_producto, 
                        fgt.id_regimen,
                        '001' id_tipo_advalorem,
                        LEFT(fdt.id_fraccion, 6) fraccion,
                        MIN(fdt.id_pais_origen) origen,
                        fgt.cve_tipo_operacion,
                        MAX(p.FechaVigenciaInicio) fecha_inicio,
                        MAX(p.FechaVigenciaFin) fecha_vencimiento
                    FROM ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                    INNER JOIN ADUASIS.dbo.fgtrafico fgt WITH (NOLOCK) 
                        ON fgt.id_trafico = fdt.id_trafico
                        AND fgt.id_referencia = @idReferencia
                        AND fgt.id_rectificacion = @idRectificacion
                    INNER JOIN @fracciones frac ON fdt.id_fraccion LIKE frac.fraccion + '%'  
                    CROSS APPLY  
                        (SELECT   
                                p.Identificador,  
                                p.Complemento1,  
                                p.Complemento2,
                                p.Complemento3,
                                d.FechaVigenciaInicio,
                                d.FechaVigenciaFin
                        FROM DesarrolloDB.dbo.ad_documentos_identificador_partida p WITH (NOLOCK)
                        INNER JOIN DesarrolloDB.dbo.ad_documentos d WITH (NOLOCK)
                            ON d.Id = p.IdDocumento
                        WHERE p.IdDocumento = @idDocumento  
                        ) p  
                    WHERE (@cpart = ''
                        OR EXISTS (SELECT noparte FROM @nopartes np WHERE np.noparte = fdt.id_producto))
                    AND NOT EXISTS (SELECT 1 FROM ADUASIS.dbo.frel_prod_tipo_adval fdc WITH(NOLOCK)
                                    WHERE fdc.id_cliente = fgt.id_cliente AND fdc.id_proveedor = fdt.id_proveedor AND fdc.id_producto = fdt.id_producto
                                    AND fdc.id_regimen = fgt.id_regimen AND fdc.cve_tipo_operacion = fgt.cve_tipo_operacion
                                    AND fdc.id_tipo_advalorem = '001'
                                   )
                    GROUP BY
                        fgt.id_cliente,  
                        fdt.id_proveedor,  
                        fdt.id_producto, 
                        fgt.id_regimen,
                        LEFT(fdt.id_fraccion, 6),
                        fgt.cve_tipo_operacion;

                    SET @rc = @@ROWCOUNT;
                    SET @AfectacionPartidaPermiso += @rc;
                    SET @MensajeEjecucion += CONCAT(N'Se agregaron ', CAST(@rc AS NVARCHAR(20)), N' configuraciones de ad valorem para los productos relacionados.', @NL);
                END
                ELSE
                BEGIN
                    SET @MensajeEjecucion += CONCAT(N'No fue necesario ajustar el ad valorem por origen Estados Unidos en este documento.', @NL);
                END;
            END;    
    
            -- manejo de permiso      
            IF @idClasificacion = 3    
            BEGIN      
                IF EXISTS (
                    SELECT 1
                    FROM ADUASIS.dbo.fpedimento fped WITH(NOLOCK)
                    INNER JOIN ADUASIS.dbo.fpedimento_detalle fdet WITH(NOLOCK)
                        ON fdet.id_referencia = fped.id_referencia
                            AND fdet.id_rectificacion = fped.id_rectificacion
                    INNER JOIN ADUASIS.dbo.fpedimento_trafico AS fpedtraf WITH (NOLOCK)
                        ON fpedtraf.id_referencia = fped.id_referencia
                            AND fpedtraf.id_rectificacion = fped.id_rectificacion
		                    AND fpedtraf.referencia_secuencial = fdet.numero_secuencial
                    INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                        ON fdt.id_trafico = fpedtraf.id_trafico
                            AND fdt.id_producto = fpedtraf.id_producto
                            AND fdt.num_secuencial = fpedtraf.trafico_secuencial
                    INNER JOIN @fracciones frac ON fdet.id_fraccion LIKE frac.fraccion + '%'
                    WHERE fped.id_referencia = @idReferencia
                    AND fped.id_rectificacion = @idRectificacion
                    AND fped.pedimento = @pedimento
                    AND (@cpart = ''
                        OR EXISTS (SELECT 1 FROM @nopartes np WHERE np.noparte = fdt.id_producto))
                    AND EXISTS (
                        SELECT 1
                        FROM DesarrolloDB.dbo.ad_documentos_permiso p WITH (NOLOCK)
                        WHERE p.IdDocumento = @idDocumento
                    )
                )
                BEGIN
                    SET @AplicaPartidaPermiso = 1;
                    SET @MensajeEjecucion += CONCAT(N'Se encontraron partidas relacionadas para aplicar el permiso en pedimento.', @NL);
                END
                ELSE
                BEGIN
                    SET @MensajeEjecucion += CONCAT(N'No se encontraron partidas relacionadas para aplicar el permiso en pedimento.', @NL);
                END;

                -- insertado en fpedimento_permiso  
                INSERT INTO ADUASIS.dbo.fpedimento_permiso  
                (  
                    id_referencia,  
                    id_rectificacion,  
                    numero_secuencial,  
                    id_permiso,  
                    numero_permiso,  
                    firma_permiso,  
                    valor_comercial_dlls,  
                    cantidad_tarifa  
                )  
                SELECT DISTINCT   
                    fped.id_referencia,  
                    fped.id_rectificacion,  
                    fdet.numero_secuencial,  
                    p.Permiso,  
                    p.Numero,  
                    p.Firma,  
                    (SELECT CASE
                    WHEN TRY_CAST(Valor AS NUMERIC(14, 2)) IS NULL THEN CAST(NULL AS NUMERIC(14, 2))
                    ELSE CAST(Valor AS NUMERIC(14, 2)) END valor
                    FROM DesarrolloDB.dbo.ad_documentos_campos
                    WHERE IdDocumento = @idDocumento
                    AND IdCampo = 19) valor_comercial_dlls,  
                    (SELECT CASE
                    WHEN TRY_CAST(Valor AS NUMERIC(15, 3)) IS NULL THEN CAST(NULL AS NUMERIC(15, 3))
                    ELSE CAST(Valor AS NUMERIC(15, 3)) END valor
                    FROM DesarrolloDB.dbo.ad_documentos_campos
                    WHERE IdDocumento = @idDocumento
                    AND IdCampo = 11) cantidad_tarifa  
                FROM ADUASIS.dbo.fpedimento fped WITH(NOLOCK)
                INNER JOIN ADUASIS.dbo.fpedimento_detalle fdet WITH(NOLOCK)
                    ON fdet.id_referencia = fped.id_referencia
                        AND fdet.id_rectificacion = fped.id_rectificacion
                INNER JOIN ADUASIS.dbo.fpedimento_trafico AS fpedtraf WITH (NOLOCK)
                    ON fpedtraf.id_referencia = fped.id_referencia
                        AND fpedtraf.id_rectificacion = fped.id_rectificacion
		                AND fpedtraf.referencia_secuencial = fdet.numero_secuencial
                INNER JOIN ADUASIS.dbo.fdtrafico AS fdt WITH (NOLOCK)
                    ON fdt.id_trafico = fpedtraf.id_trafico
                        AND fdt.id_producto = fpedtraf.id_producto
                        AND fdt.num_secuencial = fpedtraf.trafico_secuencial
                INNER JOIN @fracciones frac ON fdet.id_fraccion LIKE frac.fraccion + '%'  
                CROSS APPLY  
                    (SELECT   
                           p.Permiso,    
                           p.Numero,    
                           p.Firma ,  
                           d.FechaVigenciaFin,  
                           id_proveedor = (SELECT TOP (1) c.Valor   
                                           FROM DesarrolloDB.dbo.ad_documentos_campos c WITH(NOLOCK)   
                                           WHERE c.IdDocumento = p.IdDocumento AND c.IdCampo = 6
                                           ORDER BY c.Id DESC)  
                    FROM DesarrolloDB.dbo.ad_documentos_permiso p WITH (NOLOCK)    
                    INNER JOIN DesarrolloDB.dbo.ad_documentos d WITH(NOLOCK) ON d.Id = p.IdDocumento  
                    WHERE p.IdDocumento = @idDocumento  
                    ) p  
                WHERE fped.id_referencia = @idReferencia  
                AND fped.id_rectificacion = @idRectificacion  
                AND fped.pedimento = @pedimento
                AND (@cpart = ''
                    OR EXISTS (SELECT noparte FROM @nopartes np WHERE np.noparte = fdt.id_producto))
			    AND NOT EXISTS(SELECT 1 FROM ADUASIS.dbo.fpedimento_permiso fc WITH(NOLOCK)
                    WHERE fc.id_referencia = @idReferencia AND fc.id_rectificacion = @idRectificacion
                    AND fc.numero_secuencial = fdet.numero_secuencial AND fc.id_permiso = p.Permiso
                    AND fc.numero_permiso = ISNULL(p.Numero, '') AND fc.firma_permiso = ISNULL(p.Firma, ''));    

            SET @rc = @@ROWCOUNT;
            SET @AfectacionPartidaPermiso += @rc;
            SET @MensajeEjecucion += CONCAT(N'Se agregaron ', CAST(@rc AS NVARCHAR(20)), N' permisos nuevos en el pedimento.', @NL);
            END;    

            IF (@idClasificacion IS NULL OR @idClasificacion NOT IN (2, 3))
                SET @MensajeEjecucion += CONCAT(N'No se realizaron cambios en pedimento porque el documento no corresponde a información por partida ni a permisos.', @NL);
        END;
    END;    
    
    DECLARE @Resultado BIT;
    IF @modoEjecucion = N'tráfico'
    BEGIN
        IF @idClasificacion = 2
            SET @Resultado = CASE WHEN @AfectacionPartidaPermiso > 0 OR @AplicaPartidaPermiso = 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END;
        ELSE IF @idClasificacion = 1
            SET @Resultado = CAST(1 AS BIT);
        ELSE
            SET @Resultado = CAST(0 AS BIT);
    END
    ELSE
    BEGIN
        IF @idClasificacion IN (2, 3)
            SET @Resultado = CASE WHEN @AfectacionPartidaPermiso > 0 OR @AplicaPartidaPermiso = 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END;
        ELSE IF @idClasificacion = 1
            SET @Resultado = CAST(1 AS BIT);
        ELSE
            SET @Resultado = CAST(0 AS BIT);
    END

    SELECT @Resultado AS Resultado,
           @MensajeEjecucion AS MensajeEjecucion;
END;
