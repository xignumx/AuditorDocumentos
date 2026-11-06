# Eliminar asociación de operación

**Estado:** implementado en `src/` (pendiente QA). Columna eDOCS confirmada: `Tb_Archivos.Status` (`bit`).

| Documento | Contenido |
|-----------|-----------|
| [decisiones-negocio.md](./decisiones-negocio.md) | Reglas acordadas (alcance, bloqueos, UI) |
| [plan-implementacion.md](./plan-implementacion.md) | Plan técnico por tareas (API, EDOCS, Web, SQL) |
| [SQL/](./SQL/) | Scripts desplegables (`CREATE PROCEDURE`) — ver [SQL/README.md](./SQL/README.md) |

## Objetivo

Permitir eliminar una operación relacionada a un documento cuando:

1. El pedimento **no** está pagado (`fecha_pago_banco IS NULL`).
2. No hay **eDocument válido** ni **número de operación** VUCEM.

Al eliminar:

- `DELETE` de `ad_documento_operacion`
- `UPDATE` de `Tb_Archivos.Status = 0`
- `DELETE` de `ad_rel_documento_edoc`

Sin revertir transferencia al pedimento ni cambiar el estatus del documento en Auditor.

## Endpoint

`POST /api/Documentos/EliminarAsociacionOperacion`

## UI

Botón por fila (ícono papelera) en la tabla **Pedimentos asociados** del modal de asociación, con confirmación. Visible si `puedeEliminarAsociacionOperacion` y `canManageDocuments`.
