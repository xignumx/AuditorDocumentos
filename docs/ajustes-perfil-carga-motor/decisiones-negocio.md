# Decisiones de negocio — Perfil del motor para acciones críticas

Actualizado 17/08/2026. Las respuestas del 04/07/2026 sobre Admin / Líder / Acceso general se mantienen; cambia el **alcance**.

| # | Tema | Decisión |
|---|------|----------|
| 1 | **Objetivo** | Restringir **acciones críticas** según `ad_motor_config_header.PerfilCarga` |
| 2 | **Opciones** | **Admin**, **Líder**, **Acceso general** (una por motor: cliente + tipo VUCEM) |
| 3 | **Admin** | Solo usuarios con `fusuario.IdClase = 'ADM'` |
| 4 | **Líder** | Solo usuarios con `fusuario.IdClase = 'LIDER'` |
| 5 | **Acceso general** | Cualquier usuario autenticado (sin importar `IdClase`) |
| 6 | **CALIDAD** | Se trata como **acceso general** (no como admin ni líder) |
| 7 | **Alta** | Cualquier usuario autenticado puede cargar; el perfil **no** bloquea el alta |
| 8 | **Acciones críticas** | Autorizar, rechazar, eliminar documento, relacionar operación, eliminar asociación |
| 9 | **Fuera de alcance** | Consultas, detalle, PDF, envío VUCEM, acceso a `/config` |
| 10 | **Default motores existentes** | **Acceso general** |
| 11 | **UI configuración** | Pantalla `/config`, título “Perfil para acciones críticas” |

## Matriz de validación (acciones críticas)

| Perfil en motor | ADM | LIDER | CALIDAD | Otro / sin clase |
|-----------------|-----|-------|---------|------------------|
| Admin | ✅ | ❌ | ❌ | ❌ |
| Líder | ❌ | ✅ | ❌ | ❌ |
| Acceso general | ✅ | ✅ | ✅ | ✅ |

Alta: ✅ para todos los perfiles y clases (si existe motor).
