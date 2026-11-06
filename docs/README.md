# Documentación técnica — Auditor de Documentos

Índice de referencia para desarrollo y mantenimiento del código en `src/`. El README raíz del repositorio resume propósito, requisitos y ejecución local; aquí se profundiza en arquitectura, tecnologías y convenciones.

## Documentos

| Documento | Contenido |
|-----------|-----------|
| [inventario-funcionalidades.md](./inventario-funcionalidades.md) | Capacidades actuales de la aplicación (usuario, reglas y superficies de API) para análisis de mejoras |
| [arquitectura-general.md](./arquitectura-general.md) | Visión de la solución, bases de datos, integraciones y flujos principales |
| [api-backend.md](./api-backend.md) | Proyecto `Aduax.AuditorDocumentos.Api`: capas, controladores, servicios, EF, auth |
| [frontend-web.md](./frontend-web.md) | Proyecto `Aduax.AuditorDocumentos.Web`: React, rutas, servicios HTTP, UI |
| [vmodels-y-contratos-api.md](./vmodels-y-contratos-api.md) | Proyecto `Aduax.AuditorDocumentos.VModels` y contrato API ↔ front |
| [convenciones-y-estilo.md](./convenciones-y-estilo.md) | Patrones de código, nombres, respuestas HTTP y buenas prácticas del equipo |

## Otros recursos en `docs/`

- **`docs/SQL/`** — Scripts de stored procedures y cambios de esquema usados por la API.
- **`docs/auto-edocs/`** — Documentación y SQL relacionados con integración e-Docs / VUCEM.
  - [guia-cliente-envio-vucem-sellos.md](./auto-edocs/guia-cliente-envio-vucem-sellos.md) — Contrato API Vucem (`idSello`)
  - [plan-integracion-envio-vucem-sellos.md](./auto-edocs/plan-integracion-envio-vucem-sellos.md) — Plan de implementación en Auditor de Documentos (actualizado con `IdSelloEdoc`, SP operaciones, UI eDocument)
- **`docs/ajustes-072026/`** — Ajuste 07/2026: campos IA 20–24 + sugerencia/diagnóstico pedimentos `_v2` (**implementado**; pendiente QA/promoción).
  - [README.md](./ajustes-072026/README.md) · [guia-implementacion.md](./ajustes-072026/guia-implementacion.md)
  - [decisiones-negocio.md](./ajustes-072026/decisiones-negocio.md) · [decisiones-filtros-sugerencia-pedimentos.md](./ajustes-072026/decisiones-filtros-sugerencia-pedimentos.md)
  - [SQL/](./ajustes-072026/SQL/) — `implementacion/` · `referencia/` · `pruebas/`
- **`docs/ajustes-perfil-carga-motor/`** — Perfil del motor para **acciones críticas** (`PerfilCarga`). Alta libre. Implementado en `src/`; pendiente script BD si la columna no existe.
  - [README.md](./ajustes-perfil-carga-motor/README.md) · [guia-implementacion.md](./ajustes-perfil-carga-motor/guia-implementacion.md)
- **`docs/eliminar-asociacion-operacion/`** — Eliminar operación asociada (sin pago / sin eDocument ni número VUCEM). Implementado en `src/`; pendiente QA.
  - [README.md](./eliminar-asociacion-operacion/README.md) · [decisiones-negocio.md](./eliminar-asociacion-operacion/decisiones-negocio.md) · [plan-implementacion.md](./eliminar-asociacion-operacion/plan-implementacion.md)
- **`docs/ajuste-separacion-traficopedimento/`** — Sugerencia/diagnóstico `_v2`: tráficos visibles aunque ya tengan pedimento. Solo SQL (ADUASIS); pendiente ejecutar.
  - [README.md](./ajuste-separacion-traficopedimento/README.md) · [decisiones-negocio.md](./ajuste-separacion-traficopedimento/decisiones-negocio.md) · [guia-implementacion.md](./ajuste-separacion-traficopedimento/guia-implementacion.md)

## Proyectos en `src/`

```text
src/
├── Aduax.AuditorDocumentos.sln          # Solo Api + VModels (.NET)
├── Aduax.AuditorDocumentos.Api/         # ASP.NET Core 8 — API REST
├── Aduax.AuditorDocumentos.VModels/     # DTOs compartidos (referenciado por Api)
├── Aduax.AuditorDocumentos.Web/         # SPA React + Vite (fuera del .sln)
└── DLL/                                 # onecore.security.* (token)
```

## Cuándo consultar cada guía

- **Qué puede hacer hoy la aplicación (análisis de mejoras)** → `inventario-funcionalidades.md`
- **Nuevo endpoint o regla de negocio** → `api-backend.md`, `vmodels-y-contratos-api.md`, `convenciones-y-estilo.md`
- **Nueva pantalla o componente** → `frontend-web.md`, `vmodels-y-contratos-api.md`
- **Cambio de BD o SP** → `arquitectura-general.md`, scripts en `docs/SQL/`
- **Auth, CORS o despliegue** → `arquitectura-general.md`, `api-backend.md`, `frontend-web.md`
