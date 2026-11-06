# Guía de implementación — Perfil del motor para acciones críticas

## Script

| Paso | Archivo | Base |
|------|---------|------|
| 1 | [01 DesarrolloDB Alter ad_motor_config_header PerfilCarga.sql](./SQL/implementacion/01%20DesarrolloDB%20Alter%20ad_motor_config_header%20PerfilCarga.sql) | DesarrolloDB |

## Validación

```sql
USE DesarrolloDB;
SELECT TOP 5 Id, PerfilCarga FROM dbo.ad_motor_config_header;
-- Esperado: columna existe; registros existentes con 'G'
```

## Código relacionado (`src/`)

- `AdPerfilCargaMotor.UsuarioPuedeAccionCritica`
- `ad_motor_config_header.PerfilCarga` / `AdMotorConfigHeader.PerfilCarga`
- `GetPerfilCargaPersistidoAsync`, `GetPerfilesCargaPorClienteAsync`
- `DocumentosController.ValidarPerfilAccionCriticaAsync` en autorizar, rechazar, eliminar, asociar y quitar asociación
- `CspAdDocumentosPorEstatus.PuedeAccionCritica` en `ObtenerDocumentos`
- UI: `ConfigurationsPage` (copy), `DocumentRepositoryCreatePage` (alta libre), `DocumentRepositoryListPage` (botones por fila)
