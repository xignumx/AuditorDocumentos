/*
  Prueba — Diagnóstico de rendimiento csp_Ad_SugerenciaPedimentos_v2
  Ejecutar en SSMS, base ADUASIS.

  PREVIO: desplegar SQL/implementacion/ 04 y 05; validar con pruebas/03.

  INSTRUCCIONES:
  1. Ajustar parámetros en sección PARÁMETROS.
  2. Ejecutar por bloques (GO) o script completo tras desplegar implementacion/.
*/
USE ADUASIS;
GO

/* ========== 0) Verificar que existe el SP ========== */
IF OBJECT_ID('dbo.csp_Ad_SugerenciaPedimentos_v2', 'P') IS NULL
BEGIN
    RAISERROR(
        'No existe dbo.csp_Ad_SugerenciaPedimentos_v2. Ejecute implementacion/05.',
        16,
        1
    );
END
ELSE
BEGIN
    PRINT 'OK: dbo.csp_Ad_SugerenciaPedimentos_v2 existe.';
END;
GO

/* ========== 0b) Versión desplegada — paginación sin OFFSET ========== */
IF OBJECT_ID('dbo.csp_Ad_SugerenciaPedimentos_v2', 'P') IS NOT NULL
BEGIN
    DECLARE @def NVARCHAR(MAX) = OBJECT_DEFINITION(OBJECT_ID('dbo.csp_Ad_SugerenciaPedimentos_v2'));

    IF @def LIKE '%OFFSET @Offset%'
    BEGIN
        RAISERROR(
            'SP desactualizado. Redesplegar implementacion/05.',
            16,
            1
        );
    END
    ELSE IF @def NOT LIKE '%ROW_NUMBER()%'
    BEGIN
        PRINT 'ADVERTENCIA: no se detectó ROW_NUMBER en el SP; revise que esté actualizado.';
    END
    ELSE
    BEGIN
        PRINT 'OK: paginación ROW_NUMBER detectada (sin OFFSET @Offset).';
    END;
END;
GO

/* ========== PARÁMETROS — editar aquí (mismos valores en secciones 3, 4 y 5) ========== */
DECLARE @idCliente VARCHAR(10) = '9375';       -- <-- ajustar
DECLARE @idAdDocumento BIGINT = 548;           -- <-- ajustar
DECLARE @operacionBusqueda VARCHAR(40) = '';    -- <-- ajustar si aplica

/* ========== 1) Filtros activos del documento ========== */
SELECT d.Id,
       d.IdCliente,
       d.IdMotorConfigHeader,
       dcd.IdCampo,
       dcd.NombreCampo,
       dc.Valor
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
ORDER BY dcd.IdCampo;

/* ========== 2) Volumen base por cliente (pedimentos abiertos) ========== */
SELECT COUNT(*) AS pedimentos_abiertos
FROM ADUASIS.dbo.fpedimento AS fped WITH (NOLOCK)
WHERE fped.id_cliente = @idCliente
      AND fped.fecha_pago_banco IS NULL
      AND fped.firma_banco IS NULL
      AND fped.pedimento <> '';
GO

/* ========== 3) Plan de ejecución estimado ========== */
/* Si 0b falló, desplegar implementacion/05 antes de continuar. */
SET SHOWPLAN_XML ON;
GO

EXEC dbo.csp_Ad_SugerenciaPedimentos_v2
    @idCliente = '11886',
    @idAdDocumento = 3953,
    @operacionBusqueda = '',
    @PageNumber = 1,
    @PageSize = 10;
GO

SET SHOWPLAN_XML OFF;
GO

/* ========== 4) Ejecución real — sugerencia (métricas; puede tardar) ========== */
DECLARE @idCliente VARCHAR(10) = '11886';
DECLARE @idAdDocumento BIGINT = 3953;
DECLARE @operacionBusqueda VARCHAR(40) = '';

IF OBJECT_DEFINITION(OBJECT_ID('dbo.csp_Ad_SugerenciaPedimentos_v2')) LIKE '%OFFSET @Offset%'
BEGIN
    RAISERROR(
        'OMITIDO sección 4: SP desactualizado. Despliegue implementacion/05.',
        16,
        1
    );
END
ELSE
BEGIN
    SET STATISTICS IO ON;
    SET STATISTICS TIME ON;

    EXEC dbo.csp_Ad_SugerenciaPedimentos_v2
        @idCliente = @idCliente,
        @idAdDocumento = @idAdDocumento,
        @operacionBusqueda = @operacionBusqueda,
        @PageNumber = 1,
        @PageSize = 10;

    SET STATISTICS IO OFF;
    SET STATISTICS TIME OFF;
END;
GO

/* ========== 5) Diagnóstico de asociación (csp_Ad_DiagnosticoSugerenciaPedimentos_v2) ========== */
DECLARE @idClienteDiag VARCHAR(10) = '11886';       -- <-- ajustar
DECLARE @idAdDocumentoDiag BIGINT = 3953;           -- <-- ajustar
DECLARE @operacionBusquedaDiag VARCHAR(40) = '';    -- <-- operación a diagnosticar (pedimento/ref/tráfico)

IF OBJECT_ID('dbo.csp_Ad_DiagnosticoSugerenciaPedimentos_v2', 'P') IS NULL
BEGIN
    RAISERROR(
        'No existe dbo.csp_Ad_DiagnosticoSugerenciaPedimentos_v2. Ejecute el script 20260702-07.',
        16,
        1
    );
END
ELSE
BEGIN
    EXEC dbo.csp_Ad_DiagnosticoSugerenciaPedimentos_v2
        @idCliente = @idClienteDiag,
        @idAdDocumento = @idAdDocumentoDiag,
        @operacionBusqueda = @operacionBusquedaDiag;
END;
GO

/* ========== 6) Índices existentes en tablas críticas ========== */
SELECT OBJECT_NAME(i.object_id) AS tabla,
       i.name AS indice,
       i.type_desc,
       STUFF(
           (
               SELECT ', ' + c.name
               FROM sys.index_columns AS ic
                   INNER JOIN sys.columns AS c
                       ON c.object_id = ic.object_id
                          AND c.column_id = ic.column_id
               WHERE ic.object_id = i.object_id
                     AND ic.index_id = i.index_id
                     AND ic.is_included_column = 0
               ORDER BY ic.key_ordinal
               FOR XML PATH('')
           ),
           1,
           2,
           ''
       ) AS columnas_clave
FROM sys.indexes AS i
WHERE i.object_id IN (
                         OBJECT_ID('dbo.fpedimento'),
                         OBJECT_ID('dbo.fgtrafico'),
                         OBJECT_ID('dbo.fdtrafico'),
                         OBJECT_ID('dbo.frel_pedimento_factura'),
                         OBJECT_ID('dbo.fpedimento_guia')
                     )
      AND i.type > 0
ORDER BY tabla,
         indice;
GO
