# Decisiones — Separación tráfico / pedimento

## Problema

`csp_Ad_SugerenciaPedimentos_v2` filtraba la rama de tráfico con un `NOT EXISTS` contra `fpedimento` (mismo cliente + referencia + rectificación). Un tráfico ya relacionado con pedimento **no aparecía**; solo el pedimento.

## Decisión

| # | Decisión |
|---|----------|
| 1 | Retirar esa exclusión en **sugerencia** `_v2`. |
| 2 | En **diagnóstico** `_v2`, si `@operacionBusqueda` no trae `/` y existe `fgtrafico.id_trafico` del cliente, diagnosticar como **tráfico** aunque haya pedimento relacionado. |
| 3 | Atajo **Pedimento (24)** se mantiene: solo pedimento, sin rama tráfico. |
| 4 | Duplicados en grilla son válidos: pedimento con `ref/rect` vs tráfico sin diagonal. |
| 5 | Solo SPs vigentes (`_v2`). v1 intocable. |
| 6 | Solo scripts SQL; sin cambios de API/front. |

## Qué se mantiene

- Filtros del motor (AND, obligatorios visibles con valor).
- Pedimentos sin pago/firma banco.
- Exclusión de operaciones ya asociadas al documento (`ad_documento_operacion` / `@OpsExcluidas`).
- Formato UI: pedimento = `referencia/rectificacion`; tráfico = `id_trafico`.

## Aclaración técnica (relación que se deja de usar como bloqueo)

La relación que **ya no bloquea** la aparición del tráfico es únicamente:

```text
fpedimento.id_cliente = fgtrafico.id_cliente
AND fpedimento.id_referencia = fgtrafico.id_referencia
AND fpedimento.id_rectificacion = fgtrafico.id_rectificacion
```

No se alteran los joins usados para validar campos del pedimento contra partidas de tráfico (`fdtrafico`, facturas, etc.).
