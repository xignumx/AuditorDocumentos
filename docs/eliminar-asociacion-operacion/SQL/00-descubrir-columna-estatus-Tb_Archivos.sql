-- [Referencia] Columna confirmada: EDOCS.dbo.Tb_Archivos.Status (bit)
-- Despliegue: usar 20260727-01 y 20260727-02 (CREATE PROCEDURE).
-- Este archivo se conserva solo como evidencia del discovery.

USE EDOCS;
GO

SELECT c.COLUMN_NAME, c.DATA_TYPE
FROM EDOCS.INFORMATION_SCHEMA.COLUMNS c
WHERE c.TABLE_NAME = 'Tb_Archivos'
  AND c.COLUMN_NAME = 'Status';
GO
