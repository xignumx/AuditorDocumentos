# Ajuste — Separación tráfico / pedimento en sugerencia y diagnóstico

**Estado:** SPs desplegados en ADUASIS. Sugerencia `_v2` con separación tráfico/pedimento + `OPTION (RECOMPILE)` solo en INSERT de tráfico cuando la búsqueda va vacía (2026-10-13).  
**Alcance:** solo base de datos (SPs `_v2` vigentes). Sin cambios en `src/`.

| Documento | Contenido |
|-----------|-----------|
| [decisiones-negocio.md](./decisiones-negocio.md) | Qué se retira, qué se mantiene, UI |
| [guia-implementacion.md](./guia-implementacion.md) | Orden de ejecución y validación |

---

## SQL

```text
SQL/
└── implementacion/
    ├── 01 ADUASIS csp_Ad_SugerenciaPedimentos_v2.sql
    └── 02 ADUASIS csp_Ad_DiagnosticoSugerenciaPedimentos_v2.sql
```

Ejecutar en orden `01` → `02` sobre **ADUASIS**.

---

## Objetivo

Dejar de excluir tráficos que ya tienen relación con pedimento en ADUASIS, para que la sugerencia (y el diagnóstico alineado) puedan devolver **ambos**:

- pedimento → en UI `referencia/rectificacion`
- tráfico → en UI solo `id_trafico` (sin diagonal)

aunque el tráfico ya esté ligado a un pedimento por `(id_cliente, id_referencia, id_rectificacion)`.

**No cambia:** atajo Pedimento (24), exclusiones por operación ya asociada al documento (`@OpsExcluidas`), filtros de pago/firma banco en pedimentos, ni SPs v1.
