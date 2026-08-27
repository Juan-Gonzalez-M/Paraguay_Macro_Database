# Inventario de series — paraguay_macro_pilot.duckdb

**Generado:** 2026-08-26, contra `release:748d41036c3a73638a1c2086` (última corrida
completa, `completed_with_warnings`, 22/22 fuentes).
**Archivo de datos completo:** [`series_inventory.csv`](series_inventory.csv) — una
fila por serie (28.417 filas), con período, periodicidad y flags de revisión. Este
documento es el resumen; el CSV es la fuente exacta.

## Por qué este archivo existe

Al intentar analizar `database/paraguay_macro_pilot.duckdb` desde una herramienta
externa (base de conocimiento), el repositorio en GitHub sólo entregó el **puntero
de Git LFS** (un archivo de texto con el hash SHA-256 y el tamaño, no los datos),
no el binario real. Eso es el comportamiento esperado de Git LFS cuando el cliente
que lee el repo no resuelve objetos LFS — no es un error de la base en sí. Este
inventario (CSV + este resumen) es texto plano, no pasa por LFS, y sí es legible
por cualquier herramienta que lea archivos de un repo de GitHub directamente.

## Resumen general

- **28.417 series** en `dim_series`, **1.216.910 observaciones** en total
  (`fact_series_events`), **22 fuentes** (`source_id`).
- **Rango temporal global:** 1945-12-31 a 2028-12-01 (el extremo superior son
  proyecciones oficiales de `Cuadro 49` del Anexo Estadístico, no un error —
  ver `docs/VERIFICATION.md`).
- **Periodicidades presentes:** `daily`, `irregular_daily`, `monthly`,
  `monthly_survey`, `quarterly`, `semiannual`, `annual`.

### Una advertencia antes de leer "28.417 series" como "28.417 indicadores económicos"

**16.411 de las 28.417 series (58%) tienen 2 observaciones o menos.** Esto no es un
defecto — viene del modelo de identidad de "row-event" que usa el pipeline para
fuentes transaccionales: cada operación individual (una subasta de LRM, una
transacción interbancaria, un punto de una curva de bonos corporativa en una fecha
dada) se modela como su propia serie con `identity_stability = positional_lane`,
precisamente para no fusionar operaciones distintas del mismo día bajo un mismo
`series_id`. `lrm_auctions` (3.083 series), buena parte de `interbank_market`
(1.814) y toda `corporate_bond_curves` (1.287) son así por diseño. Si el objetivo es
un panel de **indicadores macro tradicionales** (series largas, una observación por
período), conviene filtrar el CSV por `observations > 12` o por
`identity_stability = 'semantic'` antes de usarlo.

## Por fuente

| Fuente | Series | Periodicidad(es) | Rango temporal | Posicional/lane | Jerarquía sin resolver | Unidad ambigua |
|---|---:|---|---|---:|---:|---:|
| `economic_annex` | 10.607 | monthly (9.783), annual (516), quarterly (296), semiannual (12) | 1950-12-31 → 2028-12-01 | 8.214 | 10.607 | 69 |
| `lrm_auctions` | 3.083 | irregular_daily | 2013-01-08 → 2026-07-30 | 3.083 | 0 | 0 |
| `credit_survey` | 2.805 | quarterly | 2013-03-31 → 2026-06-30 | 2.534 | 0 | 0 |
| `eve` | 2.760 | monthly_survey | 2006-04-01 → 2026-08-01 | 0 | 0 | 0 |
| `insurance_annex` | 2.050 | annual | 2009-06-30 → 2025-06-30 | 2 | 2.050 | 0 |
| `financial_indicators` | 1.868 | monthly | 2011-01-31 → 2026-06-30 | 1.636 | 0 | 0 |
| `interbank_market` | 1.814 | irregular_daily (1.263), daily (551) | 2010-01-04 → 2026-08-14 | 1.263 | 551 | 632 |
| `corporate_bond_curves` | 1.287 | irregular_daily | 2010-11-01 → 2026-07-31 | 0 | 0 | 0 |
| `exchange_houses` | 770 | annual (434), monthly (336) | 2016-07-31 → 2026-07-31 | 0 | 770 | 0 |
| `payments` | 573 | monthly | 2013-11-30 → 2026-07-31 | 74 | 573 | 142 |
| `direct_investment` | 407 | annual (256), quarterly (151) | 1995-12-31 → 2024-12-31 | 0 | 407 | 0 |
| `bcp_fx_daily` | 168 | daily | 2013-01-02 → 2026-08-14 | 0 | 0 | 0 |
| `liquidity_facility` | 56 | irregular_daily | 2016-01-20 → 2021-09-09 | 56 | 0 | 0 |
| `exchange_rates` | 52 | daily (28), monthly (22), annual (2) | 1945-12-31 → 2026-07-31 | 14 | 0 | 0 |
| `banking_indicators` | 39 | monthly | 2016-01-01 → 2026-06-01 | 0 | 39 | 20 |
| `compensatory_fx_sales` | 36 | monthly | 2015-01-31 → 2026-07-31 | 36 | 0 | 0 |
| `fx_operations` | 30 | annual (10), monthly (10), quarterly (10) | 1990-12-31 → 2026-12-31 | 0 | 0 | 0 |
| `icc` | 12 | monthly | 2018-01-31 → 2026-07-31 | 0 | 0 | 0 |

**Cómo leer las últimas tres columnas** (todas son flags de revisión documentados en
`README.md`, no errores):
- **Posicional/lane** (`identity_stability != 'semantic'`): la serie no tiene una
  etiqueta textual única y estable en la fuente; su identidad depende de la
  posición en la hoja o de una regla de desambiguación entre eventos del mismo
  día. No cambia entre corridas del mismo archivo, pero es más frágil ante un
  rediseño de la hoja publicada.
- **Jerarquía sin resolver** (`hierarchy_status = 'unresolved'`): la hoja fuente
  publica agregados y componentes juntos sin que exista todavía un modelo
  padre-hijo revisado (p. ej. total vs. desagregado por entidad).
- **Unidad ambigua** (`unit = 'source_units'`): el parser no pudo inferir con
  confianza la unidad de medida a partir de la etiqueta/título y no inventó una;
  queda en el valor original de la fuente hasta revisión manual.

## Columnas del CSV completo

`source_id, series_id, series_label, frequency, first_period, last_period, observations, unit, scale, currency, identity_stability, hierarchy_status`

- `first_period` / `last_period`: primera y última fecha con una observación real
  para esa serie (no son límites sintéticos ni interpolados).
- `observations`: cantidad de observaciones reales de esa serie en
  `fact_series_events` (sparse — no incluye huecos rellenados).
- `series_id`: formato `fuente:hoja_o_ruta:hash` — el mismo identificador usado en
  todas las vistas `v_*` del proyecto (ver `README.md`, sección "Data layers").

## Cómo regenerar este inventario

```r
library(DBI); library(duckdb)
con <- DBI::dbConnect(duckdb::duckdb(), "database/paraguay_macro_pilot.duckdb", read_only = TRUE)
DBI::dbExecute(con, "
  COPY (
    SELECT source_id, series_id, label AS series_label, frequency,
           first_period, last_period, observations, unit, scale, currency,
           identity_stability, hierarchy_status
    FROM v_series_catalogue ORDER BY source_id, series_id
  ) TO 'revisiones/series_inventory.csv' (HEADER, DELIMITER ',')
")
```

Los números de este resumen quedan desactualizados en cuanto se corra
`run_update.R` con una fuente modificada; regenerar ambos archivos después de cada
actualización real de la base.
