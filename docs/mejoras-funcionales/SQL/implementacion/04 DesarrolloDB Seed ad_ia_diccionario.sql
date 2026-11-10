/*
  ADX-OPER-26-0039 - Epic 3 ID_01 (Dev 2)
  Semilla del diccionario de sinonimos (prototipo ia-rules.html / PDF de mejora).
  Base: DesarrolloDB. Requiere el script 03. Es idempotente: no duplica terminos ya existentes.

  Codificacion: guardar y ejecutar como UTF-8 (los terminos llevan acentos).

  Equivalencias de UM: no se siembran aqui porque dependen de los id_unidad_universal reales de ADUASIS.
  Capturarlas desde /config/ia-rules (pestana Equivalencias UM) o completar la plantilla del final.
*/
USE DesarrolloDB;
GO

DECLARE @Seed TABLE
(
    Concepto VARCHAR(100) NOT NULL,
    IdCampo  INT          NULL,
    Termino  VARCHAR(200) NOT NULL,
    Idioma   CHAR(2)      NOT NULL
);

-- Numero de parte -> AdCampos.ProductoNoDeParte (7)
INSERT INTO @Seed (Concepto, IdCampo, Termino, Idioma) VALUES
 ('Número de parte', 7, N'Número de Parte', 'ES'),
 ('Número de parte', 7, N'No. de Parte',    'ES'),
 ('Número de parte', 7, N'N/P',             'ES'),
 ('Número de parte', 7, N'NP',              'ES'),
 ('Número de parte', 7, N'Artículo',        'ES'),
 ('Número de parte', 7, N'Código',          'ES'),
 ('Número de parte', 7, N'Referencia',      'ES'),
 ('Número de parte', 7, N'Item',            'EN'),
 ('Número de parte', 7, N'Item Number',     'EN'),
 ('Número de parte', 7, N'Item No.',        'EN'),
 ('Número de parte', 7, N'Part Number',     'EN'),
 ('Número de parte', 7, N'Part No.',        'EN'),
 ('Número de parte', 7, N'P/N',             'EN'),
 ('Número de parte', 7, N'PN',              'EN'),
 ('Número de parte', 7, N'Product Code',    'EN'),
 ('Número de parte', 7, N'Code',            'EN'),
 ('Número de parte', 7, N'SKU',             'EN');

-- Valor unitario (sin campo directo en AdCampos)
INSERT INTO @Seed (Concepto, IdCampo, Termino, Idioma) VALUES
 ('Valor unitario', NULL, N'Valor Unitario',  'ES'),
 ('Valor unitario', NULL, N'Precio Unitario', 'ES'),
 ('Valor unitario', NULL, N'P.U.',            'ES'),
 ('Valor unitario', NULL, N'P. Unitario',     'ES'),
 ('Valor unitario', NULL, N'Precio / U',      'ES'),
 ('Valor unitario', NULL, N'Unit Price',      'EN'),
 ('Valor unitario', NULL, N'Price/Unit',      'EN'),
 ('Valor unitario', NULL, N'Unit Cost',       'EN'),
 ('Valor unitario', NULL, N'Price',           'EN'),
 ('Valor unitario', NULL, N'Rate',            'EN');

-- Valor total (sin campo directo en AdCampos)
INSERT INTO @Seed (Concepto, IdCampo, Termino, Idioma) VALUES
 ('Valor total', NULL, N'Valor Total',     'ES'),
 ('Valor total', NULL, N'Precio Total',    'ES'),
 ('Valor total', NULL, N'Importe',         'ES'),
 ('Valor total', NULL, N'Monto Total',     'ES'),
 ('Valor total', NULL, N'Subtotal',        'ES'),
 ('Valor total', NULL, N'Total',           'ES'),
 ('Valor total', NULL, N'Total Amount',    'EN'),
 ('Valor total', NULL, N'Amount',          'EN'),
 ('Valor total', NULL, N'Ext. Price',      'EN'),
 ('Valor total', NULL, N'Extended Price',  'EN'),
 ('Valor total', NULL, N'Total Price',     'EN'),
 ('Valor total', NULL, N'Line Total',      'EN');

INSERT INTO dbo.ad_ia_diccionario (Categoria, Concepto, IdCampo, Termino, Idioma, CreadoPor)
SELECT 'GENERAL', s.Concepto, s.IdCampo, s.Termino, s.Idioma, 'Sistema'
FROM @Seed AS s
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.ad_ia_diccionario AS d
    WHERE d.Categoria = 'GENERAL'
      AND d.Termino = s.Termino
);
GO

/*
  Plantilla de equivalencias de UM (completar con los id_unidad_universal reales y descomentar):

  INSERT INTO dbo.ad_ia_diccionario (Categoria, Concepto, IdCampo, Termino, Idioma, CreadoPor)
  VALUES
   ('UM', '<id_unidad_universal de PIEZA>', NULL, N'PZA',   'ES', 'Sistema'),
   ('UM', '<id_unidad_universal de PIEZA>', NULL, N'PCS',   'EN', 'Sistema'),
   ('UM', '<id_unidad_universal de PIEZA>', NULL, N'Piece', 'EN', 'Sistema'),
   ('UM', '<id_unidad_universal de PIEZA>', NULL, N'EA',    'EN', 'Sistema');
*/
