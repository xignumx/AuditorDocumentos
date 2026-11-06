# Decisiones de negocio — Ajuste campos 07/2026

Respuestas confirmadas el 02/07/2026.

| # | Tema | Decisión |
|---|------|----------|
| 1 | **Pedimento** (24) | Número de pedimento de **15 dígitos**: 2 año + 2 aduana/sección + 4 patente + 7 número. Ejemplo: `26 80 3438 6543210` → `268034386543210` |
| 2 | **Valor USD** (22) | Campo **independiente** de `ValorComercial` (19). Solo dato capturado; no se usa en SPs de pedimento |
| 3 | **Guía/BL** (23) | Un campo con soporte **múltiple** (TagInput, valores separados por `;`) |
| 4 | **Fecha Factura** (21) | Extracción y captura en formato `yyyy-MM-dd`, sin validación adicional |
| 5 | **Defaults motor** | Los 5 campos: **no visibles** y **no obligatorios** por defecto |
| 6 | **Prompts IA** | Insertar para **todos** los `IdTipoDocumentoVucem` con `ActivoAuditorDocumentos = 1` en EDOCS |
| 7 | **Reporte uso** | Sí, incluir campos 20–24 en `csp_AuditorDocumentosUsoCompleto` |
| 8 | **Nombres enum** | `Factura`, `FechaFactura`, `ValorUsd`, `GuiaBl`, `Pedimento` |

## Formato Pedimento (15 dígitos)

```text
Posición   Longitud   Significado              Ejemplo
1–2        2          Últimos 2 dígitos año    26
3–4        2          Aduana / sección         80
5–8        4          Patente                  3438
9–15       7          Número de pedimento      6543210
```

Validación UI: solo dígitos, longitud exacta 15 (espacios opcionales al capturar, se normalizan al guardar).
