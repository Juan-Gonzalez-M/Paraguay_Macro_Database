# Inventario de series — paraguay_macro_pilot.duckdb

**Generado:** 2026-08-26, contra `release:748d41036c3a73638a1c2086` (última corrida
completa, `completed_with_warnings`, 22/22 fuentes).
**Archivos de datos completos** (todos texto plano, sin Git LFS — ver sección 1):
- [`series_inventory.csv`](series_inventory.csv) — una fila por serie (28.417
  filas): fuente, **hoja**, período, periodicidad, unidad y flags de revisión.
- [`series_observations/`](series_observations/) — un CSV por fuente con las
  observaciones reales (`series_id, period, value`), 1.216.910 filas en total.

Este documento es el resumen navegable; los CSV son la fuente exacta y completa.

---

## 1. Cómo analizar las series usando sólo lo que hay en el repo de Git

El problema original: una herramienta externa (base de conocimiento) leyó el
repositorio de GitHub y sólo obtuvo el **puntero de Git LFS** de
`database/paraguay_macro_pilot.duckdb` — un archivo de texto con el hash SHA-256 y
el tamaño, no los datos reales. Eso es el comportamiento esperado de Git LFS cuando
el cliente que lee el repo no resuelve objetos LFS explícitamente; no es un defecto
de la base.

**Solución: dos CSV en texto plano, versionados sin LFS**, que entre los dos
reconstruyen exactamente lo que la base ofrece para consultas de series:

1. `series_inventory.csv` — el catálogo (qué series existen, con qué etiqueta, en
   qué hoja, con qué periodicidad y rango de fechas).
2. `series_observations/<fuente>.csv` — los valores reales, uno por fuente
   (`source_id`), formato largo: `series_id, period, value`.

Se unen por `series_id`. Ningún archivo individual supera 51MB (el más grande,
`economic_annex.csv`, pesa 50MB), muy por debajo del límite de 100MB de GitHub por
archivo — se leen con cualquier lector de CSV, sin DuckDB, sin R, sin resolver LFS.

**Ejemplo (Python/pandas), reconstruir una serie completa desde los dos archivos:**

```python
import pandas as pd
inv = pd.read_csv("revisiones/series_inventory.csv")
obs = pd.read_csv("revisiones/series_observations/economic_annex.csv")

serie = inv[(inv.source_sheet == "CUADRO 1") & (inv.series_label.str.contains("PIB"))]
valores = obs[obs.series_id.isin(serie.series_id)].merge(
    serie[["series_id", "series_label"]], on="series_id"
)
```

**Ejemplo (R), lo mismo sin abrir la base:**

```r
inv <- readr::read_csv("revisiones/series_inventory.csv")
obs <- readr::read_csv("revisiones/series_observations/economic_annex.csv")
serie <- dplyr::filter(inv, source_sheet == "CUADRO 1", grepl("PIB", series_label))
valores <- dplyr::inner_join(obs, serie, by = "series_id")
```

**Qué falta en este esquema (alcance explícito, no un descuido):** 4 de las 22
fuentes (`banks`, `financial`, `bank_reference`, `securities_trades`) no viven en
`dim_series`/`fact_series_events` — usan un modelo de tabla distinto (estados
financieros por entidad y fecha, referencia semántica pura, o transacciones
individuales) que no encaja en "serie con período y valor" de la misma forma. Se
consultan directamente vía SQL contra la base (`raw_banks_eeff`,
`raw_financial_eeff`, `securities_transactions_snapshot`, `reference_table_loads`),
no están en este export. Si hace falta un CSV de éstas también, es un pedido
aparte — la forma de la tabla es distinta y merece su propio formato de export.

**Cómo regenerar ambos:**

```r
library(DBI); library(duckdb)
con <- DBI::dbConnect(duckdb::duckdb(), "database/paraguay_macro_pilot.duckdb", read_only = TRUE)

DBI::dbExecute(con, "CREATE OR REPLACE TEMP VIEW sheet_of AS
  SELECT DISTINCT series_id, source_sheet FROM documented_series_snapshot")
DBI::dbExecute(con, "COPY (
  SELECT c.source_id, sh.source_sheet, c.series_id, c.label AS series_label, c.frequency,
         c.first_period, c.last_period, c.observations, c.unit, c.scale, c.currency,
         c.identity_stability, c.hierarchy_status
  FROM v_series_catalogue c LEFT JOIN sheet_of sh USING(series_id)
  ORDER BY c.source_id, sh.source_sheet, c.series_id
) TO 'revisiones/series_inventory.csv' (HEADER, DELIMITER ',')")

for (src in DBI::dbGetQuery(con, "SELECT DISTINCT source_id FROM dim_series")$source_id) {
  DBI::dbExecute(con, sprintf("COPY (
    SELECT f.series_id, f.period, f.value FROM fact_series_events f
    JOIN dim_series d USING(series_id) WHERE d.source_id = %s
    ORDER BY f.series_id, f.period
  ) TO %s (HEADER, DELIMITER ',')",
    DBI::dbQuoteString(con, src),
    DBI::dbQuoteString(con, file.path("revisiones/series_observations", paste0(src, ".csv")))))
}
```

Regenerar ambos después de cada `run_update.R` real — quedan desactualizados en
cuanto cambia una fuente.

---

## 2. Por qué el mismo "tipo de dato" aparece con `series_id` distintos que sólo difieren en el año

Esto **no** es un diseño general del pipeline ("una serie por año") — de hecho la
gran mayoría de `economic_annex` hace exactamente lo contrario: una sola serie
continua con cientos de observaciones mensuales (ver `CUADRO 1`, `n=21` series,
cada una con ~35 años de datos anuales en **una** fila del CSV). Lo que encontraste
es un **defecto real, puntual y ya diagnosticado**, catalogado ahora como
**R45** en `AUDITORIA_REGRESIONES.md`.

**En una frase:** 8 hojas de comercio exterior (`Cuadro 46a/b, 51a/b, 52a/b,
53a/b`) tienen, después de su eje mensual normal, un bloque de 7 columnas de
comparación interanual —no observaciones nuevas, sino estadísticas derivadas:
"A Julio 2024", "A Julio 2025\*", "A Julio 2026\*", variación nominal, variación %,
incidencia, variación interanual—. Como esos encabezados no son fechas
reconocibles, el parser no logra darles un período propio y las 7 terminan cayendo
en el mismo período final de la hoja; el guard de identidad (que está funcionando
correctamente) evita fusionarlas creando 7 `series_id` distintos.

**Evidencia concreta** (`Cuadro 53a`, fila 67 = "Aceite de girasol"):

| Columnas | Encabezado real (fila 12) | Qué contienen |
|---|---|---|
| 2–392 (391 cols) | fechas mensuales, ene-1994 a jul-2026 | la serie mensual real — **una sola serie**, 367+24 observaciones |
| 393 | "A Julio 2024" | acumulado enero-julio 2024 |
| 394 | "A Julio 2025\*" | acumulado enero-julio 2025 (provisorio) |
| 395 | "A Julio 2026\*" | acumulado enero-julio 2026 (provisorio) |
| 396 | "Var. Nominal A Julio 2026/2025" | diferencia entre las dos columnas anteriores |
| 397 | "Var. % A Julio 2026/2025" | igual, en porcentaje |
| 398 | "Incidencia" | contribución al cambio total |
| 399 | "Var. % Interanual Julio 2026/2025" | variación interanual del propio mes de julio |

Las columnas 393–399 **no están en el CSV como una sola serie con 7 observaciones
en fechas distintas** — cada una se volvió una serie de 1 sola observación, todas
fechadas 2026-07-01 (el último período real de la hoja), porque ésa fue la única
fecha disponible cuando el parser no pudo leer "A Julio 2024" como una fecha.

**Cómo detectarlas en el CSV:** `identity_stability = 'positional_lane'` y
`observations` muy bajo (1 o 2) dentro de una de las 8 hojas listadas. La sección 4
de este informe da el conteo exacto por hoja. **Cómo evitarlas al analizar:**
filtrar `identity_stability = 'semantic'`, o `observations > 12`, antes de tratar
una fila del CSV como una serie temporal utilizable — la serie mensual real
(`identity_stability = 'semantic'`) para cada producto sigue completa y correcta;
las derivadas están fragmentadas pero técnicamentente son redundantes (se
recalculan de la serie mensual).

**No se corrigió en esta ronda.** El arreglo toca el parser compartido del eje de
columnas — mismo nivel de riesgo que el ítem #4 de `revisiones/MEJORAS_v11.md`
(reescribir identidad de estas mismas 9 hojas), que el usuario ya excluyó
explícitamente de la ronda de mejoras de riesgo bajo/medio. Detalle completo,
alcance medido hoja por hoja y precedente ya resuelto en el proyecto (`Cuadro 49`
tuvo el mismo problema en su eje de filas) en `AUDITORIA_REGRESIONES.md`, entrada
R45.

---

## 3. Resumen general

- **28.417 series** en `dim_series`, **1.216.910 observaciones** en total, **18
  fuentes** con modelo de series (de las 22 totales — ver sección 1 para las 4
  restantes).
- **Rango temporal global:** 1945-12-31 a 2028-12-01 (el extremo superior son
  proyecciones oficiales de `Cuadro 49`, no un error — `docs/VERIFICATION.md`).
- **Periodicidades:** `daily`, `irregular_daily`, `monthly`, `monthly_survey`,
  `quarterly`, `semiannual`, `annual`.
- **58% de las series (16.411 de 28.417) tienen 2 observaciones o menos.** La mitad
  de este total (7.812) es exactamente el defecto R45 de la sección 2. El resto son
  series "row-event" genuinamente diseñadas así — cada operación individual
  (subasta de LRM, transacción interbancaria, punto de curva de bonos en una fecha)
  es su propia serie por diseño (`lrm_auctions`: 3.083 series así; buena parte de
  `interbank_market`; toda `corporate_bond_curves`). Si buscás un panel de
  indicadores macro tradicionales, filtrá por `observations > 12` **y**
  `identity_stability = 'semantic'`.

---

## 4. Detalle por fuente

| Fuente | Series | Hojas con datos | Periodicidad(es) | Rango temporal | Posicional/lane | Unidad ambigua |
|---|---:|---:|---|---|---:|---:|
| `economic_annex` | 10.607 | 93 (de 94; la restante es sólo índice) | monthly (9.783), annual (516), quarterly (296), semiannual (12) | 1950-12-31 → 2028-12-01 | 8.214 (7.812 son R45; ver abajo) | 69 |
| `lrm_auctions` | 3.083 | — (row-event, sin hoja) | irregular_daily | 2013-01-08 → 2026-07-30 | 3.083 (diseño, no defecto) | 0 |
| `credit_survey` | 2.805 | 1 hoja (`%`) | quarterly | 2013-03-31 → 2026-06-30 | 2.534 | 0 |
| `eve` | 2.760 | — (snapshot, sin hoja) | monthly_survey | 2006-04-01 → 2026-08-01 | 0 | 0 |
| `insurance_annex` | 2.050 | ver detalle propio (no expandido acá) | annual | 2009-06-30 → 2025-06-30 | 2 | 0 |
| `financial_indicators` | 1.868 | 1 hoja | monthly | 2011-01-31 → 2026-06-30 | 1.636 | 0 |
| `interbank_market` | 1.814 | — (row-event) | irregular_daily (1.263), daily (551) | 2010-01-04 → 2026-08-14 | 1.263 (diseño) | 632 |
| `corporate_bond_curves` | 1.287 | — (row-event, CSV largo) | irregular_daily | 2010-11-01 → 2026-07-31 | 0 | 0 |
| `exchange_houses` | 770 | 3 (de 10; 4 formularios vacíos, otras metadata) | annual (434), monthly (336) | 2016-07-31 → 2026-07-31 | 0 | 0 |
| `payments` | 573 | 38 (de 40) | monthly | 2013-11-30 → 2026-07-31 | 74 | 142 |
| `direct_investment` | 407 | ver detalle propio | annual (256), quarterly (151) | 1995-12-31 → 2024-12-31 | 0 | 0 |
| `bcp_fx_daily` | 168 | 1 hoja | daily | 2013-01-02 → 2026-08-14 | 0 | 0 |
| `liquidity_facility` | 56 | — (row-event) | irregular_daily | 2016-01-20 → 2021-09-09 | 56 (diseño) | 0 |
| `exchange_rates` | 52 | 1 hoja | daily (28), monthly (22), annual (2) | 1945-12-31 → 2026-07-31 | 14 | 0 |
| `banking_indicators` | 39 | 1 hoja | monthly | 2016-01-01 → 2026-06-01 | 0 | 20 |
| `compensatory_fx_sales` | 36 | 1 hoja | monthly | 2015-01-31 → 2026-07-31 | 36 (diseño) | 0 |
| `fx_operations` | 30 | — (snapshot) | annual (10), monthly (10), quarterly (10) | 1990-12-31 → 2026-12-31 | 0 | 0 |
| `icc` | 12 | — (snapshot) | monthly | 2018-01-31 → 2026-07-31 | 0 | 0 |

**"Posicional/lane" y "diseño, no defecto":** en las fuentes row-event
(`lrm_auctions`, buena parte de `interbank_market`, `liquidity_facility`,
`compensatory_fx_sales`), cada evento sin identificador propio del publicador se
modela como su propia serie a propósito (`README.md`, sección "What v9 repaired").
En `economic_annex`, en cambio, la enorme mayoría de los casos `positional_lane`
(7.812 de 8.214) es el defecto R45 recién diagnosticado — la distinción importa
para decidir si conviene filtrar esas filas del análisis.

---

## 5. `economic_annex`, hoja por hoja (las 93 hojas con series reales)

`hierarchy_status = 'unresolved'` es prácticamente universal en esta fuente (10.607
de 10.607 series) — no es una señal útil hoja por hoja acá, se omite de esta tabla
(sí es comparable entre fuentes, ver sección 4).

| Hoja | Series | Periodicidad(es) | Rango | Positional/lane | Nota |
|---|---:|---|---|---:|---|
| Cuadro 53a | 1.309 | monthly | 1994-01 → 2026-07 | 1.160 | R45 |
| Cuadro 53b | 1.309 | monthly | 1994-01 → 2026-07 | 1.160 | R45 |
| Cuadro 46a | 1.290 | monthly | 1994-01 → 2026-07 | 1.142 | R45 |
| Cuadro 46b | 1.288 | monthly | 1994-01 → 2026-07 | 1.140 | R45 |
| Cuadro 52b | 1.287 | monthly | 2006-01 → 2026-07 | 1.104 | R45 |
| Cuadro 52a | 1.287 | monthly | 2006-01 → 2026-07 | 1.104 | R45 |
| Cuadro 51b | 574 | monthly | 1994-01 → 2026-07 | 513 | R45 |
| Cuadro 51a | 574 | monthly | 1994-01 → 2026-07 | 513 | R45 |
| CUADRO 61 | 170 | monthly | 2004-01 → 2026-07 | 170 | Dimensión de entidad no capturada (distinto de R45, ver MEJORAS #4) |
| CUADRO 38 | 120 | annual/quarterly | 2008-03 → 2026-12 | 92 | sin diagnosticar en detalle |
| CUADRO 40 | 88 | quarterly/annual | 2008-03 → 2026-12 | 0 | — |
| CUADRO 41 | 84 | quarterly/annual | 2008-03 → 2026-12 | 12 | sin diagnosticar |
| CUADRO 37 | 76 | quarterly/annual | 2008-03 → 2026-12 | 0 | — |
| CUADRO 39 | 76 | annual/quarterly | 2008-03 → 2026-12 | 8 | sin diagnosticar |
| CUADRO 32 A | 56 | monthly | 2013-01 → 2026-06 | 0 | — |
| CUADRO 14 b | 44 | monthly | 1995-01 → 2026-07 | 33 | sin diagnosticar |
| CUADRO 36 | 38 | monthly/annual | 2003-12 → 2026-12 | 0 | — |
| CUADRO 32 | 38 | monthly/annual | 1994-01 → 2026-05 | 0 | — |
| CUADRO 42 | 30 | annual | 2008-12 → 2024-12 | 16 | sin diagnosticar |
| CUADRO 58 | 30 | annual/monthly | 2008-01 → 2026-12 | 0 | — |
| CUADRO 20 | 30 | annual/quarterly/monthly | 1990-12 → 2026-12 | 0 | — |
| CUADRO 18 | 29 | annual/monthly | 1990-12 → 2024-11 | 2 | menor |
| CUADRO 15 | 24 | monthly | 1992-12 → 2026-07 | 0 | — |
| CUADRO 12 | 22 | annual/semiannual | 2001-06 → 2025-12 | 0 | — |
| CUADRO 1 | 21 | annual | 1991-12 → 2026-12 | 0 | — |
| CUADRO 2 | 21 | annual | 1991-12 → 2026-12 | 0 | — |
| CUADRO 3 | 21 | annual | 1992-12 → 2026-12 | 0 | — |
| CUADRO 4a | 21 | annual | 1991-12 → 2026-12 | 0 | — |
| CUADRO 4b | 21 | annual | 1991-12 → 2026-12 | 0 | — |
| CUADRO 27 | 20 | annual/monthly | 1990-12 → 2024-11 | 0 | — |
| CUADRO 14 a | 20 | monthly | 1995-01 → 2026-07 | 15 | sin diagnosticar |
| CUADRO 16 a | 20 | monthly | 1994-12 → 2026-07 | 0 | — |
| CUADRO 19 | 19 | monthly | 1993-01 → 2026-07 | 0 | — |
| CUADRO 5 | 19 | annual | 1991-12 → 2026-12 | 18 | sin diagnosticar |
| CUADRO 17 | 18 | monthly | 1995-12 → 2026-06 | 0 | — |
| CUADRO 56a | 18 | annual/monthly | 1990-12 → 2026-08 | 0 | — |
| CUADRO 35 | 18 | annual/monthly | 1990-12 → 2026-05 | 4 | sin diagnosticar |
| Cuadro 47 | 18 | monthly | 2003-01 → 2026-07 | 0 | — |
| CUADRO 9 a | 18 | monthly | 2014-01 → 2026-06 | 0 | — |
| Cuadro 44a | 17 | monthly | 1994-01 → 2026-07 | 0 | — |
| Cuadro 44b | 17 | monthly | 1994-01 → 2026-07 | 0 | — |
| CUADRO 23 | 17 | monthly | 1995-12 → 2024-03 | 0 | — |
| CUADRO 14 | 16 | monthly | 1994-12 → 2026-07 | 0 | — |
| CUADRO 23a | 15 | monthly | 1995-03 → 2024-03 | 0 | — |
| CUADRO 16 (Cont.) | 14 | monthly | 1994-12 → 2026-07 | 0 | — |
| Cuadro 50 | 13 | monthly | 1994-01 → 2026-07 | 0 | — |
| Cuadro 49 | 13 | monthly | 1994-01 → 2028-12 | 0 | proyección oficial, ya revisada (R40) |
| Cuadro 45 | 13 | monthly | 1994-01 → 2026-07 | 0 | — |
| CUADRO 25 | 12 | monthly | 1997-01 → 2024-03 | 0 | — |
| CUADRO 26 | 12 | monthly/annual | 2002-01 → 2026-12 | 0 | — |
| CUADRO 16 | 11 | monthly | 1994-12 → 2026-07 | 0 | — |
| CUADRO 21 | 10 | monthly | 1995-01 → 2024-11 | 0 | — |
| Cuadro 54 | 10 | monthly | 2003-01 → 2026-07 | 0 | — |
| CUADRO 22 | 10 | monthly | 1996-01 → 2024-11 | 0 | — |
| CUADRO 31 | 10 | monthly/annual | 1990-12 → 2026-05 | 0 | — |
| CUADRO 6a (Cont.) | 9 | quarterly | 1995-03 → 2026-03 | 0 | — |
| CUADRO 6 | 9 | quarterly | 1994-03 → 2026-03 | 0 | — |
| CUADRO 6 (Cont.) | 9 | quarterly | 1995-03 → 2026-03 | 0 | — |
| CUADRO 6a | 9 | quarterly | 1994-03 → 2026-03 | 0 | — |
| CUADRO 29 (Cont.) | 8 | monthly | 1995-01 → 2024-03 | 0 | — |
| CUADRO 10 a | 8 | monthly | 2001-01 → 2026-06 | 0 | — |
| Cuadro 43 | 8 | monthly | 1994-01 → 2026-07 | 2 | sin diagnosticar |
| CUADRO 8 | 8 | annual | 1950-12 → 2026-12 | 0 | serie más larga de toda la base |
| CUADRO 34 | 7 | monthly | 2002-01 → 2026-05 | 0 | — |
| CUADRO 23b | 7 | monthly | 2017-12 → 2025-11 | 2 | sin diagnosticar |
| CUADRO 7a (Cont.) | 7 | quarterly | 1995-03 → 2026-03 | 0 | — |
| CUADRO 7a | 7 | quarterly | 1994-03 → 2026-03 | 0 | — |
| CUADRO 24b | 7 | monthly | 2017-12 → 2025-11 | 2 | sin diagnosticar |
| CUADRO 24 | 7 | monthly | 1995-03 → 2024-03 | 0 | — |
| CUADRO 28 | 7 | monthly | 1995-01 → 2024-03 | 0 | — |
| CUADRO 7 (Cont.) | 7 | quarterly | 1995-03 → 2026-03 | 0 | — |
| CUADRO 7 | 7 | quarterly | 1994-03 → 2026-03 | 0 | — |
| CUADRO 24a | 7 | monthly | 1995-03 → 2024-03 | 0 | — |
| CUADRO 59 | 7 | monthly/annual | 1994-01 → 2026-12 | 0 | — |
| CUADRO 29 | 7 | monthly | 1995-01 → 2024-03 | 0 | — |
| CUADRO 11 | 7 | annual/monthly | 1980-12 → 2026-12 | 0 | — |
| Cuadro 48 | 6 | monthly | 2003-01 → 2026-07 | 0 | — |
| CUADRO 60b | 6 | monthly | 1995-01 → 2026-06 | 0 | — |
| CUADRO 55 | 6 | monthly/annual | 1994-01 → 2026-12 | 0 | — |
| CUADRO 33 | 6 | monthly | 1999-01 → 2026-05 | 2 | sin diagnosticar |
| CUADRO 31 (Cont.) | 5 | annual/monthly | 1990-12 → 2026-05 | 0 | — |
| CUADRO 56b | 5 | monthly | 2009-01 → 2026-08 | 0 | — |
| Cuadro 21 a | 5 | monthly | 1960-01 → 2024-11 | 0 | serie histórica más larga después de CUADRO 8 |
| CUADRO 60c | 5 | monthly | 1995-01 → 2026-06 | 0 | — |
| CUADRO 13 | 5 | monthly | 1988-01 → 2026-07 | 0 | — |
| CUADRO 13 a | 4 | monthly | 1988-01 → 2026-07 | 0 | — |
| CUADRO 14 c | 4 | monthly | 2003-01 → 2026-07 | 0 | — |
| CUADRO 30 | 4 | monthly | 1997-01 → 2024-03 | 0 | — |
| CUADRO 60a | 4 | monthly | 1997-01 → 2026-07 | 0 | — |
| CUADRO 10 | 3 | monthly | 2001-01 → 2026-06 | 0 | — |
| CUADRO 9 | 2 | monthly | 1994-01 → 2026-06 | 0 | — |
| CUADRO 57a | 1 | monthly | 2021-01 → 2021-12 | 0 | arreglada esta sesión (R40) |
| CUADRO 57b | 1 | monthly | 1991-01 → 2020-12 | 0 | — |

**"Sin diagnosticar":** hojas con algo de `positional_lane` pero en cantidades
pequeñas (2-33 series), no investigadas en esta ronda porque no tienen el patrón
100%-en-el-último-período de R45 ni son evidentemente el mismo problema — quedan
como candidatas para una revisión puntual futura, no se afirma una causa sin
evidencia (misma disciplina que el resto de esta auditoría).

---

## 6. `payments`, hoja por hoja (38 de 40 hojas)

Periodicidad uniforme `monthly` en todas. `SIPAP_08` es la única con concentración
notable de `positional_lane` (52 de 55 series) — no investigada en esta ronda;
patrón a confirmar antes de asumir que es la misma familia que R45.

| Hoja | Series | Rango | Positional/lane |
|---|---:|---|---:|
| SIPAP_05 | 73 | 2013-11 → 2026-07 | 0 |
| SIPAP_04 | 64 | 2013-11 → 2026-07 | 0 |
| SIPAP_08 | 55 | 2022-05 → 2026-07 | 52 |
| CCC 02 | 40 | 2013-11 → 2026-07 | 0 |
| SIPAP_15 | 24 | 2023-01 → 2026-07 | 0 |
| CCC 04 | 24 | 2013-11 → 2026-07 | 0 |
| SIPAP_10 | 24 | 2022-05 → 2026-07 | 0 |
| SIPAP_14 | 24 | 2023-01 → 2026-07 | 0 |
| OMP 04 | 21 | 2018-01 → 2026-07 | 0 |
| SIPAP_09 | 16 | 2022-05 → 2026-07 | 0 |
| SIPAP_12 | 16 | 2022-05 → 2026-07 | 0 |
| SIPAP_03 | 16 | 2021-10 → 2026-07 | 0 |
| CCC 03 | 14 | 2013-11 → 2026-07 | 0 |
| OMP 03_02 | 14 | 2024-01 → 2026-07 | 0 |
| OMP 01_02 | 14 | 2024-01 → 2026-07 | 0 |
| OMP 02_02 | 14 | 2024-01 → 2026-07 | 0 |
| OMP 01 | 14 | 2018-01 → 2026-07 | 0 |
| OMP 02 | 12 | 2018-01 → 2026-07 | 0 |
| OMP 03 | 12 | 2018-01 → 2026-07 | 0 |
| CCCoop | 10 | 2021-12 → 2026-07 | 0 |
| SIPAP_11 | 8 | 2023-07 → 2026-07 | 0 |
| SIPAP_13 | 7 | 2023-08 → 2026-07 | 0 |
| SIPAP_01 | 6 | 2013-11 → 2026-07 | 0 |
| CCC 01 | 6 | 2013-11 → 2026-07 | 6 |
| SIPAP_02 | 6 | 2013-11 → 2026-07 | 0 |
| AFD 03 | 5 | 2013-11 → 2026-07 | 4 |
| AFD 02 | 5 | 2013-11 → 2026-07 | 4 |
| MIHA 02 | 5 | 2013-11 → 2026-07 | 4 |
| MIHA 03 | 5 | 2013-11 → 2026-07 | 4 |
| SIPAP_06 | 3 | 2013-11 → 2026-07 | 0 |
| MIHA 04 | 3 | 2013-11 → 2026-07 | 0 |
| MIHA 05 | 3 | 2013-11 → 2026-07 | 0 |
| AFD 04 | 2 | 2013-11 → 2026-07 | 0 |
| AFD 05 | 2 | 2013-11 → 2026-07 | 0 |
| SIPAP_07 | 2 | 2022-05 → 2026-07 | 0 |
| CCE | 2 | 2020-10 → 2026-07 | 0 |
| MIHA 01 | 1 | 2013-11 → 2026-07 | 0 |
| AFD 01 | 1 | 2014-06 → 2026-07 | 0 |

---

## 7. `exchange_houses`, hoja por hoja (3 de 10 hojas tienen series; 4 son
formularios sin contenido — ver `test-v10-runtime-repairs.R` — y las restantes son
metadata/entidad, no series temporales)

| Hoja | Series | Periodicidad | Rango |
|---|---:|---|---|
| 1. EEFF | 434 | annual | 2016-07 → 2026-07 |
| 2. Ratios | 240 | monthly | 2026-06 (corte único) |
| 3. Dep y Person | 96 | monthly | 2026-06 (corte único) |

`2. Ratios` y `3. Dep y Person` sólo tienen el corte más reciente disponible (no es
un error — la fuente publica esos indicadores sólo para el mes vigente, no una
serie histórica).

---

## 8. Columnas de `series_inventory.csv`

`source_id, source_sheet, series_id, series_label, frequency, first_period,
last_period, observations, unit, scale, currency, identity_stability,
hierarchy_status`

- `source_sheet`: vacío para las 4 fuentes sin modelo de hoja documentada
  (`icc`, `eve`, `fx_operations` usan tablas de snapshot dedicadas;
  `lrm_auctions`/`interbank_market`/`liquidity_facility`/`compensatory_fx_sales`
  son row-event sin hoja única).
- `first_period` / `last_period`: primera y última fecha con una observación real
  (no son límites sintéticos).
- `observations`: cantidad real en `fact_series_events` (sparse).
- `series_id`: formato `fuente:hoja_o_ruta:hash`, mismo identificador usado en
  todas las vistas `v_*` (`README.md`, "Data layers").
