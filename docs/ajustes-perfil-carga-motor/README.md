# Ajuste — Perfil del motor para acciones críticas

**Estado:** implementado en `src/` — **pendiente ejecutar script SQL en BD** si la columna `PerfilCarga` aún no existe.

| Documento | Contenido |
|-----------|-----------|
| [decisiones-negocio.md](./decisiones-negocio.md) | Alta libre; acciones críticas por Admin / Líder / Acceso general |
| [guia-implementacion.md](./guia-implementacion.md) | Script SQL y validación |

---

## SQL

```text
SQL/
└── implementacion/
    └── 01 DesarrolloDB Alter ad_motor_config_header PerfilCarga.sql
```

---

## Objetivo

Columna `PerfilCarga` en `ad_motor_config_header` (`G` / `A` / `L`) para restringir **acciones críticas**. El alta no se bloquea. Consulta y detalle no se bloquean.

---

## Casos de prueba

| Motor | Usuario | Alta | Acciones críticas | Ver repositorio |
|-------|---------|------|-------------------|-----------------|
| G | cualquiera | Sí | Sí | Sí |
| A | ADM | Sí | Sí | Sí |
| A | LIDER | Sí | No | Sí |
| A | CALIDAD / otro | Sí | No | Sí |
| L | LIDER | Sí | Sí | Sí |
| L | ADM | Sí | No | Sí |
| L | CALIDAD / otro | Sí | No | Sí |

Detalle en [decisiones-negocio.md](./decisiones-negocio.md).
