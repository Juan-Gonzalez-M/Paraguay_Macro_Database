# Inventario de series — paraguay_macro_pilot.duckdb

> **Aviso (2026-08-27).** El **texto** de este documento describe la base
> **anterior** a la ronda P0 de la auditoría técnica externa (esquema 11,
> 28.417 series). Los **CSV** sí están regenerados contra la base actual
> (esquema 12, 23.012 series), así que los conteos citados en la prosa ya no
> coinciden con ellos. Los cambios y sus cifras verificadas están en
> [`REVISION_AUDITORIA_EXTERNA.md`](REVISION_AUDITORIA_EXTERNA.md); los
> diagnósticos R45/R46/R47 que se citan más abajo siguen siendo correctos como
> descripción del defecto, pero R46 y R47 ya están cerrados.
>
> Cambios que afectan a los identificadores de estos CSV: el slug de hoja dentro
> de `series_id` ya no lleva sufijo posicional (`datos_16` → `datos`), y las 14
> hojas anuales de `bcp_fx_daily` comparten ahora una sola identidad (la columna
> `source_sheet` lista las hojas de origen separadas por ` | `).

**Generado:** 2026-08-26 (texto) / 2026-08-27 (CSV), contra
`release:748d41036c3a73638a1c2086` (última corrida completa,
`completed_with_warnings`, 22/22 fuentes).
**Archivos de datos completos** (texto plano, sin Git LFS):
- [`series_inventory.csv`](series_inventory.csv) — 23.012 filas, una por serie:
  fuente, hoja(s), período, periodicidad, unidad, flags de revisión.
- [`series_observations/`](series_observations/) — un CSV por fuente con las
  observaciones reales (`series_id, period, value`).

Este documento explica **qué contiene cada hoja** de las fuentes principales, en
qué unidad, con qué periodicidad y para qué rango de fechas — organizado como el
propio Anexo Estadístico del BCP agrupa sus cuadros. Toda descripción de contenido
citada acá viene del `table_title` real que el pipeline extrae de cada hoja
(`documented_table_catalog`), no es una interpretación mía — cuando el título no
alcanza para saber qué es una hoja, lo digo explícitamente en vez de adivinar.

---

## 1. Cómo analizar las series usando sólo lo que hay en el repo de Git

El problema original: una herramienta externa (base de conocimiento) leyó el
repositorio de GitHub y sólo obtuvo el **puntero de Git LFS** de
`database/paraguay_macro_pilot.duckdb`, no los datos reales — comportamiento
esperado de LFS cuando el cliente no resuelve objetos LFS, no un defecto de la
base.

**Solución:** dos CSV en texto plano, sin LFS, que reconstruyen cualquier serie:
1. `series_inventory.csv` — el catálogo (qué series existen, en qué hoja, con qué
   periodicidad y rango).
2. `series_observations/<fuente>.csv` — los valores reales, formato largo
   (`series_id, period, value`). Ningún archivo supera 51MB.

```python
import pandas as pd
inv = pd.read_csv("revisiones/series_inventory.csv")
obs = pd.read_csv("revisiones/series_observations/economic_annex.csv")
serie = inv[(inv.source_sheet == "CUADRO 1") & (inv.series_label.str.contains("PIB"))]
valores = obs[obs.series_id.isin(serie.series_id)].merge(serie[["series_id","series_label"]], on="series_id")
```

**Qué falta:** `banks`, `financial`, `bank_reference`, `securities_trades` usan un
modelo de tabla distinto (estados financieros por entidad, referencia semántica,
transacciones individuales) — se consultan directo por SQL, no están en este
export (alcance explícito, no un descuido).

---

## 2. Por qué el mismo indicador aparece con varios `series_id` — tres causas distintas, ya diagnosticadas

Encontraste el síntoma en dos lugares distintos y **son dos defectos diferentes**,
más un tercer caso que ya estaba documentado. Ninguno es "diseño general" del
pipeline — la mayoría de las fuentes sí producen una serie continua por indicador
(`CUADRO 1`: 21 series, cada una con ~35 años en una sola fila del CSV).

**a) `economic_annex`, 8 hojas de comercio exterior (R45).** `Cuadro 46a/b, 51a/b,
52a/b, 53a/b` tienen, después de su eje mensual normal, un bloque de 7 columnas de
comparación interanual ("A Julio 2024", "A Julio 2025\*", variación %, incidencia)
que no son observaciones nuevas — son estadísticas derivadas. Como esos
encabezados no son fechas reconocibles, las 7 caen en el mismo período final de la
hoja y se vuelven 7 `series_id` de sobra por fila. Detalle completo con evidencia
de coordenadas reales: `AUDITORIA_REGRESIONES.md`, R45.

**b) `eve`, las 2.760 series son en realidad 16 (R46, el caso más severo).**
Encontrado al investigar tu ejemplo de `bcp_fx_daily`: dentro de `eve_parser()`,
`slug(block)` termina leyendo una columna de `tibble()` ya materializada (245
copias idénticas de "Bloque de Inflación") en vez del valor escalar del loop —
`janitor::make_clean_names()` desambigua esas 245 copias idénticas con sufijos
`_2` a `_245`, y cada una se vuelve una serie de una sola observación. Confirmado
con `trace()` contra una llamada real, no especulado. Es un bug de código con
arreglo simple identificado (no aplicado). Detalle: `AUDITORIA_REGRESIONES.md`, R46.

**c) `bcp_fx_daily`, 168 filas son 12 series × 14 años (R47 — tu ejemplo exacto).**
El archivo fuente tiene una hoja por año (`OpDivisas2013(DatosDiarios)` …
`OpDivisas2026(DatosDiarios)`), cada una con las mismas 12 etiquetas ("Compra del
BCP — Sector Financiero", etc.). Como `series_id` incluye la hoja de origen, cada
etiqueta se vuelve 14 `series_id` (12×14=168, exacto). A diferencia de (a) y (b),
esto **no es un bug de parseo** — el pipeline describe con precisión que son 14
hojas reales; es una limitación de diseño (no existe hoy un mecanismo para decirle
"estas hojas son continuaciones cronológicas de la misma serie"). Mismo tipo de
limitación que `CUADRO 61` de `economic_annex` (dimensión de entidad no capturada,
`MEJORAS_v11.md` ítem #4). Detalle: `AUDITORIA_REGRESIONES.md`, R47.

**Ninguno de los tres se corrigió en esta ronda** — (a) y (c) tocan el parser
compartido o el modelo de identidad (mismo riesgo que el ítem #4, ya excluido
explícitamente); (b) tiene arreglo trivial identificado pero requiere reprocesar
la fuente antes de aceptar el resultado, y no se pidió aplicarlo.

**Cómo filtrar esto en el CSV mientras tanto:** para un panel de indicadores
tradicionales, quedate con `observations > 12`. Eso excluye limpiamente los tres
casos sin necesitar saber a cuál pertenece cada fila.

---

## 3. `economic_annex`, hoja por hoja, agrupado por bloque económico (como lo organiza el propio Anexo)

93 hojas con series reales (la 94ª es el índice de contenidos, sin datos).
`hierarchy_status='unresolved'` es prácticamente universal acá (10.607 de 10.607
series) — no se repite por hoja, no es una señal útil a este nivel.

### Bloque A — Sector real: cuentas nacionales y actividad económica

| Hoja | Contenido | Periodicidad | Rango | Series |
|---|---|---|---|---:|
| CUADRO 1 | PIB a precios de comprador, por sectores económicos, **precios constantes de 2014** | annual | 1991→2026 | 21 |
| CUADRO 2 | PIB a precios de comprador, por sectores económicos, **precios corrientes** | annual | 1991→2026 | 21 |
| CUADRO 3 | Evolución del PIB por rama de actividad económica, variación % | annual | 1992→2026 | 21 |
| CUADRO 4a | PIB por sectores — estructura económica, % sobre valor corriente | annual | 1991→2026 | 21 |
| CUADRO 4b | PIB por sectores — estructura económica, % sobre valor constante | annual | 1991→2026 | 21 |
| CUADRO 5 | PIB por tipo de gasto, precios corrientes | annual | 1991→2026 | 19 |
| CUADRO 6 | PIB trimestral (incluye binacionales Itaipú/Yacyretá) por sectores, **precios constantes 2014** | quarterly | 1994→2026 | 9 |
| CUADRO 6 (Cont.) | ídem — variación interanual, constantes | quarterly | 1995→2026 | 9 |
| CUADRO 6a | PIB trimestral por sectores, **precios corrientes** | quarterly | 1994→2026 | 9 |
| CUADRO 6a (Cont.) | ídem — variación interanual, corrientes | quarterly | 1995→2026 | 9 |
| CUADRO 7 | PIB trimestral por tipo de gasto, **precios constantes 2014** | quarterly | 1994→2026 | 7 |
| CUADRO 7 (Cont.) | ídem — variación interanual, constantes | quarterly | 1995→2026 | 7 |
| CUADRO 7a | PIB trimestral por tipo de gasto, **precios corrientes** | quarterly | 1994→2026 | 7 |
| CUADRO 7a (Cont.) | ídem — variación interanual, corrientes | quarterly | 1995→2026 | 7 |
| CUADRO 8 | Sin título propio en el archivo fuente — serie más larga de la base (PYG\|USD, 8 series); por rango y unidad, compatible con PIB nominal histórico — **no confirmado por título, no afirmado como tal** | annual | 1950→2026 | 8 |
| CUADRO 9 | IMAEP — Indicador Mensual de Actividad Económica del Paraguay, base 2014=100 | monthly | 1994→2026 | 2 |
| CUADRO 9 a | IMAEP, desagregado | monthly | 2014→2026 | 18 |
| CUADRO 10 | ECN — Estimador de Cifras de Negocios, índice base 2014=100 | monthly | 2013→2026 | 3 |
| CUADRO 10 a | ECN — índice real, subramas comerciales y servicios de telefonía móvil, base 2014=100 | monthly | 2001→2026 | 8 |

### Bloque B — Precios y mercado laboral

| Hoja | Contenido | Periodicidad | Rango | Series |
|---|---|---|---|---:|
| CUADRO 11 | Evolución del salario mínimo legal, base 1980=100 | annual/monthly | 1980→2026 | 7 |
| CUADRO 12 | Índice de Sueldos y Salarios, base junio 2001=100 | annual/semiannual | 2001→2025 | 22 |
| CUADRO 13 | Índice nominal de tarifas y precios, base dic-2017=100 (serie empalmada) | monthly | 1988→2026 | 5 |
| CUADRO 13 a | IPC, base dic-2017=100 (serie empalmada) | monthly | 1988→2026 | 4 |
| CUADRO 14 | IPC, Área Metropolitana de Asunción, base dic-2017=100 | monthly | 1994→2026 | 16 |
| CUADRO 14 a | IPC AMA — inflación total, bienes transables/no transables, nacional/importados s/fyv | monthly | 1995→2026 | 20 |
| CUADRO 14 b | IPC AMA — inflación total/alimentos/bienes/servicios/renta, desagregación fina | monthly | 1995→2026 | 44 |
| CUADRO 14 c | IPC AMA — bienes y servicios administrados (serie empalmada) | monthly | 2003→2026 | 4 |
| CUADRO 15 | IPC AMA — inflación total, subyacente y subyacente X1 | monthly | 1992→2026 | 24 |
| CUADRO 16 | IPC AMA por principales grupos dentro de cada agrupación | monthly | 1994→2026 | 11 |
| CUADRO 16 (Cont.) | ídem, continuación | monthly | 1994→2026 | 14 |
| CUADRO 16 a | IPC AMA — Carne Vacuna, por cortes | monthly | 1994→2026 | 20 |
| CUADRO 17 | Índice de precios del productor, base marzo 2025=100 | monthly | 1995→2026 | 18 |

### Bloque C — Sector monetario y financiero

| Hoja | Contenido | Periodicidad | Rango | Series |
|---|---|---|---|---:|
| CUADRO 18 | Balance monetario del BCP — activos internacionales/internos netos, billetes y monedas en circulación (M0) | annual/monthly | 1990→2024 | 29 |
| CUADRO 19 | Instrumentos de regulación monetaria | annual/monthly | 1993→2026 | 19 |
| CUADRO 20 | Operaciones cambiarias del BCP, millones de USD | annual/quarterly/monthly | 1990→2026 | 30 |
| CUADRO 21 | Agregados monetarios | monthly | 1995→2024 | 10 |
| Cuadro 21 a | Agregados Monetarios — Serie Histórica | monthly | 1960→2024 | 5 |
| CUADRO 22 | Agregados monetarios, tasas de variación % | monthly | 1996→2024 | 10 |
| CUADRO 23 | Depósitos del sector privado y público en bancos y financieras | monthly | 1995→2024 | 17 |
| CUADRO 23a | Depósitos del sector privado en bancos y financieras | monthly | 1995→2024 | 15 |
| CUADRO 23b | Depósitos en Cooperativas de Ahorro y Crédito Tipo A | monthly | 2017→2025 | 7 |
| CUADRO 24 | Créditos de bancos y financieras al sector privado y público | monthly | 1995→2024 | 7 |
| CUADRO 24a | Créditos de bancos y financieras al sector privado | monthly | 1995→2024 | 7 |
| CUADRO 24b | Créditos otorgados por Cooperativas de Ahorro y Crédito Tipo A | monthly | 2017→2025 | 7 |
| CUADRO 25 | Créditos y depósitos del sector privado/público, tasas de variación % | monthly | 1997→2024 | 12 |
| CUADRO 26 | Gastos de la Política Monetaria del BCP | monthly/annual | 2002→2026 | 12 |
| CUADRO 27 | Posición del BCP ante el sistema financiero | annual/monthly | 1990→2024 | 20 |
| CUADRO 28 | Panorama Monetario — Activos | monthly | 1995→2024 | 7 |
| CUADRO 29 | Panorama Monetario — Pasivos | monthly | 1995→2024 | 7 |
| CUADRO 29 (Cont.) | ídem, continuación | monthly | 1995→2024 | 8 |
| CUADRO 30 | Créditos y depósitos del sector privado/público, moneda extranjera (dólares), tasas de variación % | monthly | 1997→2024 | 4 |
| CUADRO 31 | Tasas efectivas de interés, sistema bancario, **moneda nacional** | monthly/annual | 1990→2026 | 10 |
| CUADRO 31 (Cont.) | ídem, **moneda extranjera** | monthly/annual | 1990→2026 | 5 |
| CUADRO 32 | Operaciones de la Bolsa de Valores de Asunción | monthly/annual | 1994→2026 | 38 |
| CUADRO 32 A | Instrumentos Bursátiles — Documentos en Custodia, Total Guaraníes (MN+ME) | monthly | 2013→2026 | 56 |
| CUADRO 33 | Principales indicadores del sistema bancario nacional — morosidad, solvencia, rentabilidad | monthly | 1999→2026 | 6 |
| CUADRO 34 | Principales indicadores de las empresas financieras | monthly | 2002→2026 | 7 |
| CUADRO 35 | Depósitos del sector público no financiero en el BCP | annual/monthly | 1990→2026 | 18 |
| CUADRO 60a | Tipo de cambio nominal del guaraní | monthly | 1997→2026 | 4 |
| CUADRO 60b | Tipo de cambio real Multilateral — índice de precios externos (ene-1995=100) | monthly | 1995→2026 | 6 |
| CUADRO 60c | Tipo de cambio real bilateral (ene-1995=100) | monthly | 1995→2026 | 5 |

### Bloque D — Finanzas públicas

| Hoja | Contenido | Periodicidad | Rango | Series |
|---|---|---|---|---:|
| CUADRO 36 | Ejecución Presupuestaria de la Administración Central, miles de millones de guaraníes | monthly/annual | 2003→2026 | 38 |

### Bloque E — Sector externo: balanza de pagos y comercio exterior

| Hoja | Contenido | Periodicidad | Rango | Series | Notas |
|---|---|---|---|---:|---|
| CUADRO 37 | Balanza de pagos — presentación normalizada (MBP6), millones USD | quarterly/annual | 2008→2026 | 76 | — |
| CUADRO 38 | Cuenta corriente por componentes normalizados (MBP6), millones USD | quarterly/annual | 2008→2026 | 120 | — |
| CUADRO 39 | Cuenta Financiera por componentes normalizados (MBP6), millones USD | quarterly/annual | 2008→2026 | 76 | — |
| CUADRO 40 | Balanza de pagos — presentación analítica (MBP6), millones USD | quarterly/annual | 2008→2026 | 88 | — |
| CUADRO 41 | Posición de inversión internacional, saldos a fin de período (MBP6), millones USD | quarterly/annual | 2008→2026 | 84 | — |
| CUADRO 42 | Inversión directa — conciliación entre principio activo/pasivo y direccional, millones USD | annual | 2008→2024 | 30 | — |
| Cuadro 43 | Balanza de Bienes, miles USD FOB | monthly | 1994→2026 | 8 | — |
| Cuadro 44a | Exportaciones por principales productos, miles USD FOB | monthly | 1994→2026 | 17 | — |
| Cuadro 44b | Exportaciones por principales productos, **en cantidades** (kWh y toneladas) | monthly | 1994→2026 | 17 | — |
| Cuadro 45 | Exportaciones registradas, miles USD FOB | monthly | 1994→2026 | 13 | — |
| Cuadro 46a | Exportaciones por niveles de procesamiento, miles USD FOB | monthly | 1994→2026 | 1.290 | **R45** — 1.142 series espurias |
| Cuadro 46b | ídem, **en toneladas y 1.000 kWh** | monthly | 1994→2026 | 1.288 | **R45** — 1.140 espurias |
| Cuadro 47 | Exportaciones por principales productos, miles USD FOB | monthly | 2003→2026 | 18 | — |
| Cuadro 48 | Exportaciones por regímenes aduaneros, miles USD FOB | monthly | 2003→2026 | 6 | — |
| Cuadro 49 | Precios internacionales (petróleo USD/barril, soja USD/tonelada, etc.) | monthly | 1994→**2028** | 13 | proyección oficial revisada (R40) |
| Cuadro 50 | Importaciones registradas, miles USD FOB | monthly | 1994→2026 | 13 | — |
| Cuadro 51a | Importaciones por tipo de bienes, miles USD FOB | monthly | 1994→2026 | 574 | **R45** — 513 espurias |
| Cuadro 51b | ídem, **en toneladas** | monthly | 1994→2026 | 574 | **R45** — 513 espurias |
| Cuadro 52a | Importaciones para uso interno y bajo Régimen de Turismo, miles USD FOB | monthly | 2006→2026 | 1.287 | **R45** — 1.104 espurias |
| Cuadro 52b | ídem, **en toneladas** | monthly | 2006→2026 | 1.287 | **R45** — 1.104 espurias |
| Cuadro 53a | Importaciones por niveles de procesamiento, miles USD FOB | monthly | 1994→2026 | 1.309 | **R45** — 1.160 espurias |
| Cuadro 53b | ídem, **en toneladas** | monthly | 1994→2026 | 1.309 | **R45** — 1.160 espurias |
| Cuadro 54 | Importaciones por regímenes aduaneros, miles USD FOB | monthly | 2003→2026 | 10 | — |
| CUADRO 55 | Ingreso de divisas — entidades binacionales, miles USD | monthly/annual | 1994→2026 | 6 | — |
| CUADRO 56a | Reservas Internacionales Netas, millones USD | annual/monthly | 1990→2026 | 18 | — |
| CUADRO 56b | Reservas Internacionales Netas | monthly | 2009→2026 | 5 | — |
| CUADRO 57a | Retornos interanuales de Reservas Internacionales | monthly | 2021 (un año) | 1 | arreglada esta sesión, R40 |
| CUADRO 57b | Intereses cobrados por colocaciones de las reservas internacionales netas, miles USD | monthly | 1991→2020 | 1 | — |
| CUADRO 58 | Remesas Familiares — ingreso de divisas, miles USD/EUR | monthly | 1994→2026 | 30 | — |
| CUADRO 59 | Deuda pública externa, miles USD | annual/monthly | 1980→2026 | 7 | — |
| CUADRO 61 | Compra/Venta de divisas en el mercado cambiario local — Bancos comerciales, Casas de cambio, miles USD | monthly | 2004→2026 | 170 | Dimensión de entidad no capturada por el parser genérico (distinto de R45; ver `MEJORAS_v11.md` ítem #4) |

---

## 4. Resumen general (todas las fuentes)

- **28.417 series**, **1.216.910 observaciones**, **18 fuentes** con modelo de
  series (de 22 totales — sección 1 explica las 4 restantes).
- **58% de las series (16.411 de 28.417) tienen ≤2 observaciones.** De ese total:
  ~7.812 son R45 (economic_annex), 2.760 son R46 (eve — antes de la corrección
  serían 16), 168 son R47 (bcp_fx_daily — antes de la corrección serían 12), y el
  resto son series "row-event" genuinamente diseñadas así (cada subasta de LRM,
  transacción interbancaria o punto de curva de bonos es su propia serie por
  diseño). **Filtrar por `observations > 12` cubre los tres defectos y las
  legítimas por igual, sin necesitar identificar a cuál pertenece cada fila.**

| Fuente | Series | Periodicidad(es) | Rango temporal | Nota de identidad |
|---|---:|---|---|---|
| `economic_annex` | 10.607 | monthly, annual, quarterly, semiannual | 1950-12 → 2028-12 | R45 en 8 hojas (7.812 series); ver sección 3 |
| `lrm_auctions` | 3.083 | irregular_daily | 2013-01 → 2026-07 | row-event, diseño correcto |
| `credit_survey` | 2.805 | quarterly | 2013-03 → 2026-06 | subpreguntas de encuesta, ver README |
| `eve` | 2.760 | monthly_survey | 2006-04 → 2026-08 | **R46 — en realidad 16 series** |
| `insurance_annex` | 2.050 | annual | 2009-06 → 2025-06 | no auditado en detalle esta ronda |
| `financial_indicators` | 1.868 | monthly | 2011-01 → 2026-06 | no auditado en detalle esta ronda |
| `interbank_market` | 1.814 | irregular_daily, daily | 2010-01 → 2026-08 | row-event, diseño correcto |
| `corporate_bond_curves` | 1.287 | irregular_daily | 2010-11 → 2026-07 | row-event, diseño correcto |
| `exchange_houses` | 770 | annual, monthly | 2016-07 → 2026-07 | ver sección 5 |
| `payments` | 573 | monthly | 2013-11 → 2026-07 | ver sección 6 |
| `direct_investment` | 407 | annual, quarterly | 1995-12 → 2024-12 | no auditado en detalle esta ronda |
| `bcp_fx_daily` | 168 | daily | 2013-01 → 2026-08 | **R47 — en realidad 12 series** |
| `liquidity_facility` | 56 | irregular_daily | 2016-01 → 2021-09 | row-event, diseño correcto |
| `exchange_rates` | 52 | daily, monthly, annual | 1945-12 → 2026-07 | no auditado en detalle esta ronda |
| `banking_indicators` | 39 | monthly | 2016-01 → 2026-06 | no auditado en detalle esta ronda |
| `compensatory_fx_sales` | 36 | monthly | 2015-01 → 2026-07 | patrón atípico (rangos superpuestos, no año-limpio) — no diagnosticado, ver nota abajo |
| `fx_operations` | 30 | annual, monthly, quarterly | 1990-12 → 2026-12 | limpio |
| `icc` | 12 | monthly | 2018-01 → 2026-07 | limpio |

**Nota sobre `compensatory_fx_sales`:** tiene ratio series/etiqueta de 12.0 (36
series, 3 etiquetas), parecido a R47, pero al inspeccionar las 36 series sus rangos
de fecha se superponen de forma irregular (ej. una serie 2015-2017, otra
2015-2023, otra 2015-2021 para la misma etiqueta) — no encaja con el patrón limpio
"una hoja por año" de R47 ni con el de R45/R46. Puede ser un tercer mecanismo
distinto (posibles columnas de vintage/corte de publicación superpuestas) — no
investigado a fondo en esta ronda por acotar alcance; queda como candidato para la
próxima revisión, señalado explícitamente en vez de adivinar una causa.

---

## 5. `exchange_houses`, hoja por hoja

De 10 hojas totales, sólo 3 tienen series; 4 son formularios sin contenido
(`1.1 BG`, `1.2 EERR`, `2.1 Ratios`, `3.1 Dep y P.` — confirmado vacías en
`test-v10-runtime-repairs.R`) y el resto son portada/notas/tablas de referencia.

| Hoja | Contenido | Periodicidad | Rango | Series |
|---|---|---|---|---:|
| 1. EEFF | Estados financieros de casas de cambio — Reporte, importe en guaraníes | annual | 2016→2026 | 434 |
| 2. Ratios | Ratios financieros del sistema de casas de cambio | monthly | 2026-06 (corte único) | 240 |
| 3. Dep y Person | Dependencias y personal de casas de cambio | monthly | 2026-06 (corte único) | 96 |

`2. Ratios` y `3. Dep y Person` publican sólo el corte vigente, no una serie
histórica — no es un error, es lo que el boletín ofrece.

---

## 6. `payments`, hoja por hoja

Boletín Estadístico de Sistemas de Pago del BCP. 38 de 40 hojas tienen series
(las 2 restantes son índice/portada). Todas mensuales.

| Grupo | Hojas | Contenido |
|---|---|---|
| SIPAP (Sistema de Pagos de Alto Valor, LBTR) | SIPAP_01 a SIPAP_15 | Transferencias entre entidades/clientes financieros vía LBTR y SPI: por entidad, por rango de monto, por día, por franja horaria, por funcionalidad, alias registrados/operativos |
| CCC (Cámara Compensadora de Cheques — BANCARD) | CCC 01-04 | Cheques compensados, pagados por entidad, por rango de monto, rechazados por causal |
| OMP (Operadoras de Medios de Pago) | OMP 01-04, 01_02-03_02 | Tarjetas de crédito/débito/prepagas — cantidad, compras por tecnología, infraestructura |
| MIHA (Ministerio de Hacienda) | MIHA 01-05 | Pagos/transferencias de y hacia el Ministerio de Hacienda vía LBTR/ACH, PYG y USD |
| AFD (Agencia Financiera de Desarrollo) | AFD 01-05 | Pagos/transferencias de y hacia la AFD vía LBTR/ACH, PYG y USD |
| Otros | CCCoop, CCE, BIC E. Bancarias | Cámara compensadora de cooperativas (CABAL), transferencias EMPE, catálogo de códigos BIC |

`SIPAP_08` (transferencias SPI por entidad financiera) es la única con
concentración notable de `positional_lane` (52 de 55 series) — no investigada en
esta ronda, patrón a confirmar antes de asumir que es la misma familia que R45.

---

## 7. Columnas de `series_inventory.csv`

`source_id, source_sheet, series_id, series_label, frequency, first_period,
last_period, observations, unit, scale, currency, identity_stability,
hierarchy_status`

- `source_sheet`: vacío para fuentes sin modelo de hoja documentada (`icc`, `eve`,
  `fx_operations` usan snapshot dedicado; las fuentes row-event no tienen hoja
  única).
- `observations`: cantidad real en `fact_series_events` (sparse, no interpolada).
- `series_id`: formato `fuente:hoja_o_ruta:hash`.
