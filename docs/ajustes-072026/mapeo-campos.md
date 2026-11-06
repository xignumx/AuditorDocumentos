# Mapeo técnico — Nuevos campos AdCampos (20–24)

**Estado:** ✅ implementado en BD y `src/`.  
Decisiones: [decisiones-negocio.md](./decisiones-negocio.md)

## Resumen

| ID | Enum | Tabla valor | Tabla motor | Tabla prompt IA | UI |
|----|------|-------------|-------------|-----------------|-----|
| 20 | `Factura` | `ad_documentos_campos` | `ad_motor_config_detalle` | `ad_ia_prompt_campo` | Texto |
| 21 | `FechaFactura` | `ad_documentos_campos` | `ad_motor_config_detalle` | `ad_ia_prompt_campo` | `type="date"` |
| 22 | `ValorUsd` | `ad_documentos_campos` | `ad_motor_config_detalle` | `ad_ia_prompt_campo` | Numérico |
| 23 | `GuiaBl` | `ad_documentos_campos` | `ad_motor_config_detalle` | `ad_ia_prompt_campo` | TagInput (`;`) |
| 24 | `Pedimento` | `ad_documentos_campos` | `ad_motor_config_detalle` | `ad_ia_prompt_campo` | 15 dígitos |

**Defaults motor:** Visible = 0, Obligatorio = 0 (backfill SQL + configs nuevas en API).

## Detalle por campo

### Factura (20)

- UI: texto libre
- IA: folio de factura comercial
- SP v2: `frel_pedimento_factura` / joins `fgfactura` (tráfico)

### FechaFactura (21)

- UI: `input type="date"`, formato `yyyy-MM-dd`
- IA: fecha factura en `yyyy-MM-dd`
- Validación al guardar: formato `YYYY-MM-DD` si tiene valor
- SP v2: `rel.fecha_factura` / `fgfactura.fecha`

### ValorUsd (22)

- UI: numérico decimal
- Independiente de `ValorComercial` (19)
- **No participa** en filtros de SPs sugerencia/diagnóstico v2
- Prompt IA (2026-10-08): si el documento está en USD, puede coincidir con ValorComercial; no exigir que sea “distinto”

### GuiaBl (23)

- UI: `TagInput` (valores múltiples separados por `;`)
- IA: uno o más números de guía/BL
- SP v2: `fpedimento_guia.guia` (OR entre valores)

### Pedimento (24)

- UI: solo dígitos, máx. 15
- Estructura: 2 año + 2 aduana + 4 patente + 7 número (ej. `268034386543210`)
- Validación al guardar: si tiene valor, longitud exacta 15
- **Atajo en SP v2:** si obligatorio+visible+valor → búsqueda directa en `fpedimento`; omite `@operacionBusqueda` y demás filtros
- Distinto de `TipoPedimento` (3), `ClavePedimento` (5) y `OperacionBusqueda` (parámetro API)

## Archivos implementados

```
src/Aduax.AuditorDocumentos.VModels/AdCampos.cs
src/Aduax.AuditorDocumentos.VModels/SugerenciaPedimentosRequest.cs
src/Aduax.AuditorDocumentos.Web/src/constants/adCampos.js
src/Aduax.AuditorDocumentos.Api/Services/DesarrolloDb/DesarrolloDb_DbContextServices.cs
src/Aduax.AuditorDocumentos.Api/Services/Aduasis/AduasisDbContextServices.cs
src/Aduax.AuditorDocumentos.Api/Controllers/MotorConfigController.cs
src/Aduax.AuditorDocumentos.Web/src/pages/ConfigurationsPage.jsx
src/Aduax.AuditorDocumentos.Web/src/pages/DocumentRepositoryCreatePage.jsx
src/Aduax.AuditorDocumentos.Web/src/pages/DocumentRepositoryListPage.jsx
src/Aduax.AuditorDocumentos.Web/src/services/motorConfigService.js
```

## Scripts SQL

| Orden | Script | Base |
|-------|--------|------|
| 1 | `implementacion/01` | DesarrolloDB |
| 2 | `implementacion/02` | DesarrolloDB + EDOCS |
| 3 | `implementacion/03` | ADUASIS (reporte) |
| 4 | `implementacion/04` | ADUASIS (FN tipo operación) |
| 5 | `implementacion/05` | ADUASIS (sugerencia v2) |
| 6 | `implementacion/06` | ADUASIS (diagnóstico v2) |

Ver [guia-implementacion.md](./guia-implementacion.md).

## Mapeo AdCampos → ADUASIS (SP v2)

Campos 20–24 en contexto de sugerencia/diagnóstico: ver tabla completa en [decisiones-filtros-sugerencia-pedimentos.md](./decisiones-filtros-sugerencia-pedimentos.md).

| Id | Campo | Participa en filtro SP v2 |
|----|-------|---------------------------|
| 20 | Factura | Sí (si obligatorio+visible+valor) |
| 21 | FechaFactura | Sí |
| 22 | ValorUsd | **No** |
| 23 | GuiaBl | Sí |
| 24 | Pedimento | Sí (atajo especial) |
