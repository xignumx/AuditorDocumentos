/*
  Ajuste 07/2026 — Backfill ad_motor_config_detalle
  Agrega IdCampo 20–24 a configuraciones de motor ya existentes.

  Defaults: Visible = 0, Obligatorio = 0
  Base: DesarrolloDB
*/
USE DesarrolloDB;
GO

DECLARE @Campos TABLE
(
    IdCampo      INT          NOT NULL,
    NombreCampo  VARCHAR(100) NOT NULL,
    Visible      BIT          NOT NULL,
    Obligatorio  BIT          NOT NULL
);

INSERT INTO @Campos (IdCampo, NombreCampo, Visible, Obligatorio)
VALUES
    (20, 'Factura',      0, 0),
    (21, 'FechaFactura', 0, 0),
    (22, 'ValorUsd',     0, 0),
    (23, 'GuiaBl',       0, 0),
    (24, 'Pedimento',    0, 0);

INSERT INTO dbo.ad_motor_config_detalle
(
    IdMotorConfigHeader,
    IdCampo,
    NombreCampo,
    Visible,
    Obligatorio
)
SELECT
    h.Id,
    c.IdCampo,
    c.NombreCampo,
    c.Visible,
    c.Obligatorio
FROM dbo.ad_motor_config_header h
CROSS JOIN @Campos c
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.ad_motor_config_detalle d
    WHERE d.IdMotorConfigHeader = h.Id
      AND d.IdCampo = c.IdCampo
);

SELECT @@ROWCOUNT AS FilasInsertadas;
GO
