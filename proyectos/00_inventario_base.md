# Inventario de la base de datos macro-financiera de Paraguay

*Fase 1 — reconocimiento. Generado el 2026-09-22 leyendo la base en modo solo lectura.*

| Elemento | Valor |
|---|---|
| Archivo | `database/paraguay_macro_pilot.duckdb` (1,08 GB) |
| SHA-256 | `c902c77fcddd3050641c50243c9244f4f77e9814ebdaa4582f14aed11a4b4f50` |
| Versión de esquema / build | 49 / `build:481cb2d5c90afff4f1964f7f` (promovido 2026-09-20) |
| Insumos | 22 fuentes BCP/SIB/BVA/SS + 2 libros sueltos (MEF, INE-EPHC) + 25 CSV del FMI en `input/current/` |
| Series candidatas escalares/especiales en `catalog.series` | 33.902 |
| Paneles entidad-mes (bancos y financieras) | 17 tablas, 2016-01 a 2026-07 |
| Detalle serie por serie | [`00_inventario_series.csv`](00_inventario_series.csv) (una fila por serie, con `candidate_id`) |

> **Actualización 2026-09-24.** La base **no cambió**: se verificó el mismo SHA-256 (`c902c77f…4f50`), así que las secciones 1 a 4 siguen vigentes. Lo que cambió es lo que existe **fuera** de la base:
> - se construyó el bloque clima/agro en `data/clima/` (scripts en `R/clima/`);
> - se adquirieron fuentes públicas en `input/acquisition_candidates/`.
>
> La sección 5 indica qué brechas quedaron cubiertas por fuera y la **sección 6** lista esos datos. El inventario de series incluye ahora 948 series externas de `data/clima`, identificables por `interfaz = data/clima/…` y `nivel_verificacion = Externa (fuera de la base; no revisada)`. **Nada de esto está integrado a DuckDB ni revisado por un economista.**

## Cómo leer el nivel de verificación

La base no tiene ninguna serie revisada por un economista (`human_verified` = 0). Traduzco sus categorías internas a cuatro niveles:

| Nivel en este inventario | Categoría interna | Qué significa | Nº |
|---|---|---|---|
| **Validada por regla** | `research_ready` + `rule_certified` | Pasó una regla determinística versionada (unidad, identidad, continuidad). No es revisión humana. | 32 series escalares |
| **Validada por regla (estructural)** | curvas de bonos corporativos y transacciones bursátiles `rule_certified` | Estructura del archivo certificada; la economía de la curva no fue revisada. | 1.287 nodos de curva + 312.329 transacciones |
| **Preliminar** | `exploratory_structurally_valid` | Fechas, claves y valores pasan chequeos mecánicos; unidad, stock/flujo, desestacionalización y jerarquía **no** revisadas. | 27.070 |
| **No comprobada** | `candidate_needs_review` | Identificable pero con problemas: identidad posicional (no se sabe con certeza qué fila es), sin observaciones numéricas o historia muy corta. | 1.765 |
| **Estructura especial (provisional)** | `non_scalar_or_special_structure` + paneles | Eventos (subastas, interbancario), curvas CDA, paneles por entidad. Se usan por su interfaz propia. | 3.748 + paneles bancarios |

Advertencias transversales, válidas para todas las series:

- **Un solo vintage por fuente.** No hay historia de publicaciones: nada sirve para evaluación en tiempo real ni análisis de revisiones.
- **31% de las series (10.548) tienen la unidad sin resolver** (`UNRESOLVED_SOURCE_UNITS`), sobre todo en moneda extranjera del Anexo, EPHC y sistemas de pago.
- **Desestacionalización no revisada** en 33.882 series; solo el IMAEP (Cuadro 9 a) declara serie ajustada y tendencia-ciclo.
- **Jerarquía (qué suma a qué) sin revisar o sin resolver** en 29.932 series.
- **Etiquetas contaminadas:** 242 series del Anexo tienen números del Excel pegados al nombre (Cuadros 18, 19, 20, 26, 27, 32, 33, 35, 37, 56a). En el Cuadro 33 (indicadores bancarios) el nombre es **solo** números. Los valores verificados son coherentes (p. ej. TPM 5,50% en 2026), pero la etiqueta no sirve para identificar la serie.
- **1.517 series con identidad posicional** (`positional`/`positional_lane`): el parser las identifica por posición, no por etiqueta; p. ej. las variaciones % de los Cuadros 14 a y 14 b del IPC.
- **La clave temporal correcta es `period_start`** (primer día del período). La fecha impresa (`period`) varía entre fuentes y produce uniones vacías.

## 1. Resumen por fuente

| Fuente (`source_id`) | Contenido | Archivo | Estructura | Nº series | Obs. | Desde | Hasta | Nivel dominante |
|---|---|---|---|---|---|---|---|---|
| `bank_reference` | Referencias semánticas: entidades, monedas, rubros, ratios, actividades | Referencias_bancos_financieras.xlsx | entity_panel | 0 | 0 | — | — | Referencia |
| `banking_indicators` | Indicadores de bancarización: personas con crédito/depósito, cuentas, género | IDB_JUN26.xlsx | scalar_series | 39 | 4.914 | 2016-01-01 | 2026-06-30 | 39 prelim. |
| `banks` | Boletín de bancos (SIB): EEFF, carteras, crédito por sector/actividad, ratios, categorías de riesgo, tarjetas… | 1.1 Tablas Boletín Bancos Jul26 1.xlsx | entity_panel | 9 tablas | 493.471 | 2016-01-31 | 2026-07-31 | Panel provisional |
| `bcp_fx_daily` | Compra/venta diaria de divisas del BCP por contraparte (sector público / financiero) | Compra_Venta de Divisas del BCP_2026 (1).xlsx | scalar_series | 12 | 40.836 | 2013-01-02 | 2026-08-14 | 12 prelim. |
| `cda_curve` | Curva de tasas de Certificados de Depósito de Ahorro (CDA) por plazo, ML y ME, y volúmenes | Curva_CDA.xlsx | curve_panel | 421 | 21.839 | 2018-01-01 | 2026-07-31 | 421 estr. especial |
| `compensatory_fx_sales` | Ventas compensatorias y complementarias de divisas del BCP (mensual) | Ventas Compensatorias_Ventas Complementarias… | scalar_series | 3 | 417 | 2015-01-01 | 2026-07-31 | 3 prelim. |
| `corporate_bond_curves` | Curvas Nelson-Siegel-Svensson de bonos corporativos por moneda y calificación | Curvas Bonoc Corporativos.csv | curve_panel | 1.287 | 116.766 | 2010-11-01 | 2026-07-31 | 1287 valid. estructural |
| `credit_survey` | Encuesta de Situación General del Crédito (trimestral): proporciones de respuestas e índices por sector | Estadística Situación General del Crédito… | scalar_series | 312 | 15.806 | 2013-01-01 | 2026-06-30 | 312 prelim. |
| `direct_investment` | Anexo de inversión directa 1995-2024: flujos y posiciones por país y sector | Anexo estadístico de Inversión Directa (ID… | scalar_series | 516 | 33.109 | 1995-01-01 | 2024-12-31 | 302 prelim. · 214 estr. especial |
| `economic_annex` | Anexo Estadístico del Informe Económico (BCP): cuentas nacionales, IMAEP, precios, dinero, tasas, sector exte… | Anexo_Estadístico_del_Informe_Económico_13… | scalar_series | 2.764 | 655.866 | 1950-01-01 | 2026-08-31 | 30 validadas · 2485 prelim. · 248 no compr. · 1 estr. especial |
| `eve` | Encuesta de Expectativas de Variables Económicas: inflación, PIB, TPM, tipo de cambio | EVE_Anexo Estadístico_agosto_2026.xlsx | scalar_series | 16 | 2.760 | 2006-04-01 | 2026-08-31 | 16 prelim. |
| `exchange_houses` | Boletín de casas de cambio: EEFF, ratios, depósitos y personal por entidad | 3. Boletín Casa de Cambio Jul26.xlsm | entity_panel | 770 | 5.048 | 2016-01-01 | 2026-12-31 | 770 estr. especial |
| `exchange_rates` | Cotizaciones del mercado fluctuante (BCP): USD, EUR, ARS, BRL; promedio y fin de mes; diario del último mes | Cotizaciones - Julio 2026.xlsx | scalar_series | 52 | 4.340 | 1945-01-01 | 2026-07-31 | 2 validadas · 36 prelim. · 14 no compr. |
| `financial` | Boletín de empresas financieras (SIB): mismas tablas que bancos | 2.1 Tablas Boletín Financieras Jul26 1.xlsx | entity_panel | 9 tablas | 183.367 | 2016-01-31 | 2026-07-31 | Panel provisional |
| `financial_indicators` | Indicadores financieros: tasas activas/pasivas por producto, plazo y moneda; saldos; tasas internacionales | Ind. Financieros web-Junio 2026.xlsx | scalar_series | 1.050 | 158.038 | 2011-01-01 | 2026-06-30 | 1045 prelim. · 5 no compr. |
| `fx_operations` | Histórico de operaciones cambiarias del BCP (compra/venta/neto por sector) | Histórico - Operaciones Cambiarias.xlsx | scalar_series | 30 | 5.450 | 1990-01-01 | 2026-07-31 | 30 prelim. |
| `icc` | Índice de Confianza del Consumidor y subíndices | Estadistica ICC.xlsx | scalar_series | 12 | 1.236 | 2018-01-01 | 2026-07-31 | 12 prelim. |
| `imf_bop` | FMI — Balance of Payments (BOP) | Balance of Payments (BOP).csv | scalar_series | 7.520 | 760.820 | 1975-01-01 | 2026-06-30 | 7512 prelim. · 8 no compr. |
| `imf_cpi` | FMI — Consumer Price Index (CPI) | Consumer Price Index (CPI).csv | scalar_series | 782 | 130.548 | 1955-01-01 | 2026-07-31 | 696 prelim. · 86 no compr. |
| `imf_cpi_wca` | FMI — Consumer Price Index (CPI), World and Country Aggregates (CPI_WCA) | Consumer Price Index (CPI), World and Countr… | scalar_series | 30 | 5.690 | 2010-02-01 | 2026-06-30 | 30 prelim. |
| `imf_ctot` | FMI — Commodity Terms of Trade (CTOT) | Commodity Terms of Trade (CTOT).csv | scalar_series | 108 | 60.156 | 1980-01-01 | 2026-05-31 | 108 prelim. |
| `imf_eer` | FMI — Effective Exchange Rate (EER) | Effective Exchange Rate (EER).csv | scalar_series | 24 | 9.030 | 1979-01-01 | 2026-06-30 | 24 prelim. |
| `imf_er` | FMI — Exchange Rates (ER) | Exchange Rates (ER).csv | scalar_series | 288 | 105.780 | 1957-01-01 | 2026-08-31 | 288 prelim. |
| `imf_fsi_metadata` | FMI — Financial Soundness Indicators (FSI), Country Metadata Table 2 | Financial Soundness Indicators (FSI), Countr… | scalar_series | 0 | 0 | — | — | Solo metadatos |
| `imf_fsibsis` | FMI — Financial Soundness Indicators (FSI), Balance Sheet, Income Statement and Memorandum Series | Financial Soundness Indicators (FSI), Balanc… | scalar_series | 883 | 99.395 | 2001-01-01 | 2026-05-31 | 883 prelim. |
| `imf_fsic` | FMI — Financial Soundness Indicators (FSI), Core and Additional Indicators | Financial Soundness Indicators (FSI), Core a… | scalar_series | 710 | 87.244 | 2001-01-01 | 2026-05-31 | 710 prelim. |
| `imf_iip` | FMI — International Investment Position (IIP) | International Investment Position (IIP).csv | scalar_series | 2.947 | 197.733 | 1991-01-01 | 2026-06-30 | 2947 prelim. |
| `imf_il` | FMI — International Liquidity (IL) | International Liquidity (IL).csv | scalar_series | 288 | 149.846 | 1945-01-01 | 2026-07-31 | 288 prelim. |
| `imf_irfcl` | FMI — International Reserves and Foreign Currency Liquidity (IRFCL) | International Reserves and Foreign Currency … | scalar_series | 2.632 | 215.764 | 2000-04-01 | 2026-07-31 | 2385 prelim. · 247 no compr. |
| `imf_itg` | FMI — International Trade in Goods (ITG) | International Trade in Goods (ITG).csv | scalar_series | 37 | 5.980 | 2005-01-01 | 2026-06-30 | 37 prelim. |
| `imf_mfs_cbs` | FMI — Monetary and Financial Statistics (MFS), Central Bank Data | Monetary and Financial Statistics (MFS), Cen… | scalar_series | 540 | 98.662 | 1997-10-01 | 2026-07-31 | 540 prelim. |
| `imf_mfs_dc` | FMI — Monetary and Financial Statistics (MFS), Depository Corporations | Monetary and Financial Statistics (MFS), Dep… | scalar_series | 1.019 | 190.028 | 1997-10-01 | 2026-07-31 | 1019 prelim. |
| `imf_mfs_ir` | FMI — Monetary and Financial Statistics (MFS), Interest Rate | Monetary and Financial Statistics (MFS), Int… | scalar_series | 148 | 37.068 | 1957-01-01 | 2026-07-31 | 148 prelim. |
| `imf_mfs_ma` | FMI — Monetary and Financial Statistics (MFS), Monetary Aggregates | Monetary and Financial Statistics (MFS), Mon… | scalar_series | 80 | 14.659 | 1997-10-01 | 2026-06-30 | 80 prelim. |
| `imf_mfs_odc` | FMI — Monetary and Financial Statistics (MFS), Other Depository Corporations | Monetary and Financial Statistics (MFS), Oth… | scalar_series | 466 | 90.673 | 1997-10-01 | 2026-07-31 | 466 prelim. |
| `imf_pcps` | FMI — Primary Commodity Price System (PCPS) | Primary Commodity Price System (PCPS).csv | scalar_series | 852 | 209.333 | 1992-01-01 | 2026-07-31 | 808 prelim. · 44 no compr. |
| `imf_pi_wca` | FMI — Production Indexes, World and Country Group Aggregates | Production Indexes, World and Country Group … | scalar_series | 16 | 2.184 | 2015-01-01 | 2026-05-31 | 16 prelim. |
| `imf_qgdp_wca` | FMI — Quarterly Gross Domestic Product (GDP), World and Country Aggregates | Quarterly Gross Domestic Product (GDP), Worl… | scalar_series | 300 | 16.980 | 2012-01-01 | 2026-03-31 | 300 prelim. |
| `imf_qnea` | FMI — National Economic Accounts (NEA), Quarterly Data | National Economic Accounts (NEA), Quarterly … | scalar_series | 595 | 29.632 | 1990-01-01 | 2026-06-30 | 298 prelim. · 297 no compr. |
| `imf_rsui` | FMI — Reported Social Unrest Index (RSUI) | Reported Social Unrest Index (RSUI).csv | scalar_series | 16 | 6.992 | 1990-01-01 | 2026-05-31 | 16 prelim. |
| `imf_wpfxi` | FMI — Working Paper Foreign Exchange Intervention (WPFXI) A Dataset of Public Data and Proxies | Working Paper Foreign Exchange Intervention … | scalar_series | 186 | 34.541 | 2000-01-01 | 2024-12-31 | 186 prelim. |
| `ine_ephc` | INE: Anexo EPHC trimestral: fuerza de trabajo, ocupación, informalidad, ingresos | Anexo_EPHC_2017-2026.xlsx | scalar_series | 1.088 | 27.017 | 2017-01-01 | 2026-06-30 | 380 prelim. · 708 no compr. |
| `insurance_annex` | Anexo estadístico de seguros (anual): primas, siniestros, reaseguros por rama | Anexo_estadístico_2025.xlsx | scalar_series | 2.050 | 34.846 | 2009-01-01 | 2025-12-31 | 2048 prelim. · 2 no compr. |
| `interbank_market` | Mercado interbancario diario: call PYG/USD, REPO, FPL/FPD, mercado secundario LRM y bonos | mercado-interbancario.xlsx | event | 1.346 | 81.474 | 2010-01-04 | 2026-08-14 | 1346 estr. especial |
| `liquidity_facility` | Subastas de depósito/repo de administración de liquidez de corto plazo | administracion-de-liquidez-web_1.xlsx | event | 56 | 3.652 | 2016-01-20 | 2021-09-09 | 56 estr. especial |
| `lrm_auctions` | Subastas de Letras de Regulación Monetaria (LRM): montos y tasas ofertadas/asignadas | Subasta de LRM_WEB.xlsx | event | 940 | 10.334 | 2013-01-08 | 2026-07-30 | 940 estr. especial |
| `mef_central_government` | MEF: Estado de operaciones de la Administración Central (MEFP 2001), mensual | MEFP 2001 ADMINISTRACIÓN CENTRAL 2003-2026 … | scalar_series | 82 | 23.108 | 2003-01-01 | 2026-08-31 | 54 prelim. · 28 no compr. |
| `payments` | Boletín de sistemas de pago: SIPAP (LBTR, ACH, SPI), cheques, tarjetas, AFD, Hacienda, cooperativas | Boletín Estadístico de Sistemas de Pago_Ju… | scalar_series | 587 | 51.830 | 2013-11-01 | 2026-07-31 | 509 prelim. · 78 no compr. |
| `securities_trades` | Negociaciones bursátiles (BVA): operación a operación, instrumento, emisor, mercado | Negociaciones_Bursatiles.csv | event | — | 312.329 | 2010-01-12 | 2026-08-19 | Validada por regla (estructural) |
| `tcn_referential_daily` | Tipo de cambio nominal referencial diario PYG/USD compra y venta (BCP) | TCN_Referencial_Diario.xlsx | scalar_series | 2 | 7.004 | 2012-08-06 | 2026-08-25 | 2 prelim. |
| *(fuera de la base)* | FMI — International Trade in Goods by partner country (IMTS): exportaciones FOB, importaciones CIF/FOB y balanza por país socio, 9 países sudamericanos (Paraguay: 1.718 series) | IMTS.csv (98 MB) | — | 12.811 | — | 1960 | 2026 | **No incorporada** |

Notas: `banks` y `financial` no aparecen como series sino como paneles (sección 2). La cobertura del FMI es Argentina, Bolivia, Brasil, Chile, Colombia, Ecuador, Paraguay, Perú y Uruguay más agregados mundiales/regionales (CPI_WCA, QGDP_WCA, PI_WCA) y precios mundiales de commodities (PCPS). **No hay series de Estados Unidos** en el bloque FMI (sí hay tasa Fed —rango—, SOFR, Selic y otras tasas de política en `financial_indicators`, hoja 8).

## 2. Paneles por entidad (bancos y financieras)

Vistas `main.v_latest_raw_banks_*`, `main.v_latest_raw_financial_*` y sus versiones documentadas `v_banks_*_documented` (con nombres de entidad y rubros). Nivel: **panel provisional** (clave banco-fecha-rubro-moneda sin colisiones; contenido económico no revisado). Moneda: `6900` = originado en PYG; `6200` = originado en moneda extranjera, expresado en PYG.

| Tabla | Contenido | Dimensiones | Filas bancos / financieras | Entidades | Rango | Nivel |
|---|---|---|---|---|---|---|
| EEFF | Balance y resultados (98 sub-rubros) | entidad × mes × sub-rubro × moneda | 246.546 / 86.199 | 20 / 9 | 2016-01 a 2026-07 (127 meses) | Panel provisional |
| Carteras | Cartera vigente, vencida, renovada, refinanciada, reestructurada, medidas COVID; depósitos vista/plazo/CDA | entidad × mes × cuenta × moneda | 55.004 / 20.614 | 20 / 9 | 2016-01 a 2026-07 (127 meses) | Panel provisional |
| Credito Sector | Cartera vigente y vencida por 13 sectores (agricultura, ganadería, consumo, comercio, etc.) | entidad × mes × moneda × sector | 48.134 / 17.939 | 20 / 9 | 2016-01 a 2026-07 (127 meses) | Panel provisional |
| Credito Actividad | Cartera por actividad (4 categorías en el vintage actual) | entidad × mes × actividad × moneda | 10.299 / 2.722 | 19 / 9 | 2016-01 a 2026-07 (127 meses) | Panel provisional |
| Ratios | Morosidad MN/ME, capital nivel 1/2, liquidez, rentabilidad, refinanciados/cartera, etc. | entidad × mes × ratio | 90.830 / 41.195 | 22 / 10 | 2016-01 a 2026-07 (127 meses) | Panel provisional |
| Categoría Creditos | Cartera por categoría de riesgo (1, 1a, 1b, 2 a 6) | entidad × mes × categoría | 15.920 / 7.129 | 20 / 9 | 2016-01 a 2026-07 (127 meses) | Panel provisional |
| TC | Tarjetas de crédito: cantidad y saldo | entidad × mes | 4.184 / 1.798 | 20 / 9 | 2016-01 a 2026-07 (127 meses) | Panel provisional |
| Canales & Person | Cajeros, dependencias, corresponsales, personal | entidad × mes × canal | 14.734 / 5.771 | 20 / 9 | 2016-01 a 2026-07 (127 meses) | Panel provisional |
| Inhab | Inhabilitaciones de cuentas por causal (año-mes) | entidad × año × mes × causal | 7.819 / — | 40 / — | 2008-02 a 2026-07 (222 meses) | Panel provisional |

También hay paneles especiales: `exchange_houses` (casas de cambio: EEFF anual 2016-2026; ratios y depósitos solo 2026-06) y `direct_investment` (inversión directa por país/sector 1995-2024).

## 3. Detalle por tabla u hoja

Una fila por fuente × hoja × frecuencia. Nivel: número de series en cada categoría (validada · preliminar · no comprobada · estructura especial). El detalle por serie, con el identificador exacto, está en `00_inventario_series.csv`.


### `banking_indicators` — Indicadores de bancarización: personas con crédito/depósito, cuentas, género

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| 1 | CRÉDITOS — Personas con crédito y cantidad total de operaciones | monthly | 12 | 2016-01-01 | 2026-06-30 | 12 prelim. |
| 2 | CRÉDITOS — Personas físicas con crédito por género | monthly | 3 | 2016-01-01 | 2026-06-30 | 3 prelim. |
| 3 | CRÉDITOS — Cantidad de operaciones por tipo de crédito | monthly | 6 | 2016-01-01 | 2026-06-30 | 6 prelim. |
| 4 | DEPÓSITOS — Personas con cuentas y cantidad total de cuentas | monthly | 6 | 2016-01-01 | 2026-06-30 | 6 prelim. |
| 5 | DEPÓSITOS — Personas con depósitos por género | monthly | 3 | 2016-01-01 | 2026-06-30 | 3 prelim. |
| 6 | DEPÓSITOS — Cantidad de cuentas por tipo de depósito | monthly | 6 | 2016-01-01 | 2026-06-30 | 6 prelim. |
| 7 | Personas con algún depósito o crédito | monthly | 3 | 2016-01-01 | 2026-06-30 | 3 prelim. |

### `bcp_fx_daily` — Compra/venta diaria de divisas del BCP por contraparte (sector público / financiero)

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| Compra y Venta de Divisas del B… | Monto de Operaciones de Divisas del Banco Central del Paraguay (millones de USD) - Año 2021 | daily | 12 | 2013-01-02 | 2026-08-14 | 12 prelim. |

### `cda_curve` — Curva de tasas de Certificados de Depósito de Ahorro (CDA) por plazo, ML y ME, y volúmenes

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| CDA_ME_112018 | TASAS PONDERADAS DE DEPÓSITOS A PLAZO - MONEDA EXTRANJERA | monthly | 36 | 2018-11-01 | 2018-11-30 | 36 estr. especial |
| CDA_ML_112018 | TASAS PONDERADAS DE DEPÓSITOS A PLAZO - MONEDA LOCAL | monthly | 43 | 2018-11-01 | 2018-11-30 | 43 estr. especial |
| Curva de Certificados de Depósi… | TASAS PONDERADAS DE DEPÓSITOS A PLAZO - MONEDA LOCAL | monthly | 342 | 2018-01-01 | 2026-07-31 | 342 estr. especial |

### `compensatory_fx_sales` — Ventas compensatorias y complementarias de divisas del BCP (mensual)

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| Ventas(DatosMensuales) | Monto de Operaciones de Divisas Compensatorias y Complementarias del Banco Central del Paragua… | monthly | 3 | 2015-01-01 | 2026-07-31 | 3 prelim. |

### `corporate_bond_curves` — Curvas Nelson-Siegel-Svensson de bonos corporativos por moneda y calificación

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| Curvas de Bonos Corporativos |  | irregular_daily | 1287 | 2010-11-01 | 2026-07-31 | 1287 valid. estructural |

### `credit_survey` — Encuesta de Situación General del Crédito (trimestral): proporciones de respuestas e índices por sector

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| % | Situación General de Créditos - SGC | quarterly | 285 | 2013-01-01 | 2026-06-30 | 285 prelim. |
| Índices | Situación General de Créditos - SGC | quarterly | 27 | 2015-01-01 | 2026-06-30 | 27 prelim. |

### `direct_investment` — Anexo de inversión directa 1995-2024: flujos y posiciones por país y sector

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| Cuadro 1 | Estadísticas de Inversión Directa en Paraguay — 1995 - 2024 — Cuadro 1. Flujos de Inversión Di… | annual | 16 | 1996-01-01 | 2024-12-31 | 16 prelim. |
| Cuadro 1 | Estadísticas de Inversión Directa en Paraguay — 1995 - 2024 — Cuadro 1. Flujos de Inversión Di… | quarterly | 16 | 1996-01-01 | 2024-12-31 | 16 prelim. |
| Cuadro 2 | Estadísticas de Inversión Directa en Paraguay — 1995 - 2024 — Cuadro 2. Saldos de Inversión Di… | annual | 16 | 1995-01-01 | 2024-12-31 | 16 prelim. |
| Cuadro 2 | Estadísticas de Inversión Directa en Paraguay — 1995 - 2024 — Cuadro 2. Saldos de Inversión Di… | quarterly | 16 | 1996-01-01 | 2024-12-31 | 16 prelim. |
| Cuadro 3 | Estadísticas de Inversión Directa en Paraguay — 1995 - 2024 — Cuadro 3. Utilidades devengadas,… | annual | 12 | 1996-01-01 | 2024-12-31 | 12 prelim. |
| Cuadro 3 | Estadísticas de Inversión Directa en Paraguay — 1995 - 2024 — Cuadro 3. Utilidades devengadas,… | quarterly | 12 | 1996-01-01 | 2024-12-31 | 12 prelim. |
| Cuadro 4 | Estadísticas de Inversión Directa en Paraguay — 1995 - 2024 — Cuadro 4. Flujos de Inversión Di… | annual | 73 | 1996-01-01 | 2024-12-31 | 73 prelim. |
| Cuadro 4 | Estadísticas de Inversión Directa en Paraguay — 1995 - 2024 — Cuadro 4. Flujos de Inversión Di… | quarterly | 73 | 1996-01-01 | 2024-12-31 | 73 prelim. |
| Cuadro 5 | Estadísticas de Inversión Directa en Paraguay — 1995 - 2024 — Cuadro 5. Saldos de Inversión Di… | annual | 73 | 1995-01-01 | 2024-12-31 | 73 estr. especial |
| Cuadro 5 | Estadísticas de Inversión Directa en Paraguay — 1995 - 2024 — Cuadro 5. Saldos de Inversión Di… | quarterly | 73 | 1996-01-01 | 2024-12-31 | 73 estr. especial |
| Cuadro 6 | Estadísticas de Inversión Directa en Paraguay — 1995 - 2024 — Cuadro 6. Flujos de Inversión Di… | annual | 34 | 1996-01-01 | 2024-12-31 | 34 prelim. |
| Cuadro 6 | Estadísticas de Inversión Directa en Paraguay — 1995 - 2024 — Cuadro 6. Flujos de Inversión Di… | quarterly | 34 | 1996-01-01 | 2024-12-31 | 34 prelim. |
| Cuadro 7 | Estadísticas de Inversión Directa en Paraguay — 1995 - 2024 — Cuadro 7. Saldos de Inversión Di… | annual | 34 | 1995-01-01 | 2024-12-31 | 34 estr. especial |
| Cuadro 7 | Estadísticas de Inversión Directa en Paraguay — 1995 - 2024 — Cuadro 7. Saldos de Inversión Di… | quarterly | 34 | 1996-01-01 | 2024-12-31 | 34 estr. especial |

### `economic_annex` — Anexo Estadístico del Informe Económico (BCP): cuentas nacionales, IMAEP, precios, dinero, tasas, sector externo, fiscal

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| CUADRO 1 | Cuadro Nº 1 — Producto interno bruto a precios de comprador — Por sectores económicos — En mil… | annual | 21 | 1991-01-01 | 2025-12-31 | 1 validada · 20 prelim. |
| CUADRO 10 | Cuadro Nº 10 — Estimador Cifras de Negocios (ECN) — Índice base 2014 = 100. | monthly | 3 | 2001-01-01 | 2026-06-30 | 3 prelim. |
| CUADRO 10 a | Cuadro Nº 10 a — Estimador Cifras de Negocios (ECN) — Índice Real Subramas Comerciales y Servi… | monthly | 8 | 2001-01-01 | 2026-06-30 | 8 prelim. |
| CUADRO 11 | Cuadro Nº 11 — Evolución del salario mínimo legal. — Base 1980 = 100. | annual | 6 | 1980-01-01 | 2025-12-31 | 6 prelim. |
| CUADRO 11 | Cuadro Nº 11 — Evolución del salario mínimo legal. — Base 1980 = 100. | irregular_interval | 1 | 1980-01-01 | 2026-06-30 | 1 estr. especial |
| CUADRO 11 | Cuadro Nº 11 — Evolución del salario mínimo legal. — Base 1980 = 100. | monthly | 1 | 1985-01-01 | 2026-07-31 | 1 prelim. |
| CUADRO 12 | Cuadro Nº 12 — Índice de Sueldos y Salarios — Base Junio 2001 = 100 | annual | 10 | 2001-01-01 | 2025-12-31 | 10 prelim. |
| CUADRO 12 | Cuadro Nº 12 — Índice de Sueldos y Salarios — Base Junio 2001 = 100 | semiannual | 12 | 2001-01-01 | 2025-06-30 | 12 prelim. |
| CUADRO 13 | Cuadro Nº 13 — Índice nominal de tarifas y precios. — Base Diciembre de 2017=100 — Serie empal… | monthly | 5 | 1988-01-01 | 2026-07-31 | 5 prelim. |
| CUADRO 13 a | Cuadro Nº 13 a — Índice de Precios al Consumidor — Base Diciembre de 2017=100 — Serie empalmada | monthly | 4 | 1988-01-01 | 2026-07-31 | 4 prelim. |
| CUADRO 14 | Cuadro Nº 14 — Índice de precios al consumidor. — Área Metropolitana de Asunción. — Base dicie… | monthly | 16 | 1994-12-01 | 2026-07-31 | 16 prelim. |
| CUADRO 14 a | Cuadro Nº 14 a — Índice de Precios al Consumidor (IPC)- Área Metropolitana de Asunción. — Infl… | monthly | 20 | 1995-01-01 | 2026-07-31 | 5 prelim. · 15 no compr. |
| CUADRO 14 b | Cuadro Nº 14 b — Índice de Precios al Consumidor (IPC) - Área Metropolitana de Asunción. — Inf… | monthly | 44 | 1995-01-01 | 2026-07-31 | 11 prelim. · 33 no compr. |
| CUADRO 14 c | Cuadro Nº 14 c — Índice de Precios al Consumidor (IPC) - Área Metropolitana de Asunción — Bien… | monthly | 4 | 2003-01-01 | 2026-07-31 | 4 prelim. |
| CUADRO 15 | Cuadro Nº 15 — Índice de precios al consumidor - Área Metropolitana de Asunción. — Inflación t… | monthly | 24 | 1992-12-01 | 2026-07-31 | 4 validadas · 20 prelim. |
| CUADRO 16 | Cuadro Nº 16 — Índice de precios al consumidor - Área Metropolitana de Asunción. — Principales… | monthly | 11 | 1994-12-01 | 2026-07-31 | 11 prelim. |
| CUADRO 16 (Cont.) | Cuadro Nº 16 (continuación) — Índice de precios al consumidor - Área Metropolitana de Asunción… | monthly | 14 | 1994-12-01 | 2026-07-31 | 14 prelim. |
| CUADRO 16 a | Cuadro Nº 16 a — Índice de precios al consumidor - Área Metropolitana de Asunción. — Carne Vac… | monthly | 20 | 1994-12-01 | 2026-07-31 | 20 prelim. |
| CUADRO 17 | Cuadro Nº 17 — Índice de precios del productor. — Base Marzo 2025= 100. | monthly | 22 | 1995-12-01 | 2026-06-30 | 22 prelim. |
| CUADRO 18 | Cuadro N° 18 — Balance monetario del Banco Central del Paraguay. — En millones de guaraníes. —… | annual | 14 | 1990-01-01 | 1994-12-31 | 14 prelim. |
| CUADRO 18 | Cuadro N° 18 — Balance monetario del Banco Central del Paraguay. — En millones de guaraníes. —… | monthly | 15 | 1994-01-01 | 2026-06-30 | 13 prelim. · 2 no compr. |
| CUADRO 19 | Cuadro N° 19 — Instrumentos de regulación monetaria. — En millones de guaraníes. | monthly | 19 | 1993-01-01 | 2026-07-31 | 19 prelim. |
| CUADRO 2 | Cuadro Nº 2 — Producto interno bruto a precios de comprador — Por sectores económicos. — En mi… | annual | 21 | 1991-01-01 | 2025-12-31 | 1 validada · 20 prelim. |
| CUADRO 20 | Cuadro N° 20 — Operaciones cambiarias del Banco Central del Paraguay. — En millones de dólares. | annual | 10 | 1990-01-01 | 2025-12-31 | 10 prelim. |
| CUADRO 20 | Cuadro N° 20 — Operaciones cambiarias del Banco Central del Paraguay. — En millones de dólares. | monthly | 10 | 1995-01-01 | 2026-07-31 | 10 prelim. |
| CUADRO 20 | Cuadro N° 20 — Operaciones cambiarias del Banco Central del Paraguay. — En millones de dólares. | quarterly | 10 | 1994-01-01 | 2026-06-30 | 10 prelim. |
| CUADRO 21 | Cuadro N° 21 — Agregados monetarios 1/ — En millones de guaraníes. | monthly | 10 | 1995-01-01 | 2026-06-30 | 10 prelim. |
| CUADRO 22 | Cuadro N° 22 — Agregados monetarios. — Tasas de variación, (%). | monthly | 10 | 1996-01-01 | 2026-06-30 | 10 prelim. |
| CUADRO 23 | Cuadro N° 23 — Depósitos /1 del sector privado y público en bancos y financieras. | monthly | 17 | 1995-12-01 | 2026-06-30 | 17 prelim. |
| CUADRO 23a | Cuadro N° 23a — Depósitos /1 del sector privado en bancos y financieras. | monthly | 15 | 1995-03-01 | 2026-06-30 | 15 prelim. |
| CUADRO 23b | Cuadro N° 23b — Depósitos/1 en Cooperativas de Ahorro y Crédito Tipo A. | monthly | 7 | 2017-12-01 | 2025-11-30 | 5 prelim. · 2 no compr. |
| CUADRO 24 | Cuadro N° 24 — Créditos de bancos y financieras al sector privado y público. | monthly | 7 | 1995-03-01 | 2026-06-30 | 7 prelim. |
| CUADRO 24a | Cuadro N° 24a — Créditos de bancos y financieras al sector privado | monthly | 7 | 1995-03-01 | 2026-06-30 | 7 prelim. |
| CUADRO 24b | Cuadro N° 24b — Créditos/1 otorgados por Cooperativas de Ahorro y Crédito Tipo A. | monthly | 7 | 2017-12-01 | 2025-11-30 | 5 prelim. · 2 no compr. |
| CUADRO 25 | Cuadro N° 25 — Créditos y depósitos del sector privado y público en bancos y financieras — Tas… | monthly | 12 | 1997-01-01 | 2026-06-30 | 12 prelim. |
| CUADRO 26 | Cuadro N° 26 — Gastos de la Política Monetaria del BCP — En millones de guaraníes. | annual | 6 | 2002-01-01 | 2025-12-31 | 6 prelim. |
| CUADRO 26 | Cuadro N° 26 — Gastos de la Política Monetaria del BCP — En millones de guaraníes. | monthly | 6 | 2002-01-01 | 2026-07-31 | 6 prelim. |
| CUADRO 27 | Cuadro N° 27 — Posición del BCP ante el sistema financiero. — En millones de guaraníes. | annual | 10 | 1990-01-01 | 1993-12-31 | 10 prelim. |
| CUADRO 27 | Cuadro N° 27 — Posición del BCP ante el sistema financiero. — En millones de guaraníes. | monthly | 10 | 1994-01-01 | 2026-06-30 | 10 prelim. |
| CUADRO 28 | Cuadro N° 28 — Panorama Monetario - Activos 1/ — En millones de guaraníes. | monthly | 7 | 1995-01-01 | 2026-06-30 | 7 prelim. |
| CUADRO 29 | Cuadro N° 29 — Panorama Monetario - Pasivos 1/ — En millones de guaraníes. | monthly | 7 | 1995-01-01 | 2026-06-30 | 7 prelim. |
| CUADRO 29 (Cont.) | Cuadro N° 29 (continuación) — Panorama Monetario - Pasivos 1/ — En millones de guaraníes. | monthly | 8 | 1995-01-01 | 2026-06-30 | 8 prelim. |
| CUADRO 3 | Cuadro Nº 3 — Evolución del producto interno bruto — Por rama de actividad económica. — Variac… | annual | 21 | 1992-01-01 | 2025-12-31 | 21 prelim. |
| CUADRO 30 | Cuadro N° 30 — Créditos y depósitos del sector privado y público en bancos y financieras. — Mo… | monthly | 4 | 1997-01-01 | 2026-06-30 | 4 prelim. |
| CUADRO 31 | Cuadro Nº 31 — Tasas efectivas de interés. — Sistema bancario - moneda nacional. — Promedios m… | annual | 3 | 1990-01-01 | 1994-12-31 | 3 prelim. |
| CUADRO 31 | Cuadro Nº 31 — Tasas efectivas de interés. — Sistema bancario - moneda nacional. — Promedios m… | monthly | 7 | 1994-01-01 | 2026-05-31 | 7 prelim. |
| CUADRO 31 (Cont.) | Cuadro N° 31 (continuación) — Tasas efectivas de interés. — Sistema bancario - moneda extranje… | annual | 1 | 1990-01-01 | 1994-12-31 | 1 prelim. |
| CUADRO 31 (Cont.) | Cuadro N° 31 (continuación) — Tasas efectivas de interés. — Sistema bancario - moneda extranje… | monthly | 4 | 1994-01-01 | 2026-05-31 | 4 validadas |
| CUADRO 32 | Cuadro N° 32 — Operaciones de la Bolsa de Valores de Asunción. — En millones de guaraníes. | annual | 16 | 1994-01-01 | 1994-12-31 | 16 no compr. |
| CUADRO 32 | Cuadro N° 32 — Operaciones de la Bolsa de Valores de Asunción. — En millones de guaraníes. | monthly | 22 | 1994-01-01 | 2026-05-31 | 22 prelim. |
| CUADRO 32 A | Cuadro N° 32 A — Instrumentos Bursátiles-Documentos en Custodia — Total Guaraníes (MN+ME) | monthly | 8 | 2013-01-01 | 2026-06-30 | 8 prelim. |
| CUADRO 33 | Cuadro N° 33 — Principales indicadores del sistema bancario nacional. — En porcentaje. — Moros… | monthly | 6 | 1999-01-01 | 2026-05-31 | 4 prelim. · 2 no compr. |
| CUADRO 34 | Cuadro N° 34 — Principales indicadores de las empresas financieras. — En porcentaje. | monthly | 7 | 2002-01-01 | 2026-05-31 | 7 prelim. |
| CUADRO 35 | Cuadro Nº 35 — Depósitos del sector público no financiero en el Banco Central del Paraguay — E… | annual | 7 | 1990-01-01 | 1994-12-31 | 5 prelim. · 2 no compr. |
| CUADRO 35 | Cuadro Nº 35 — Depósitos del sector público no financiero en el Banco Central del Paraguay — E… | monthly | 11 | 1994-01-01 | 2026-05-31 | 9 prelim. · 2 no compr. |
| CUADRO 36 | Cuadro Nº 36 — Ejecución Presupuestaria de la Administración Central — En miles millones de Gu… | annual | 19 | 2003-01-01 | 2025-12-31 | 19 prelim. |
| CUADRO 36 | Cuadro Nº 36 — Ejecución Presupuestaria de la Administración Central — En miles millones de Gu… | monthly | 19 | 2015-01-01 | 2026-06-30 | 19 prelim. |
| CUADRO 37 | Cuadro Nº 37 — Balanza de pagos - presentación normalizada-(MBP6) ** — En millones de dólares. | annual | 38 | 2008-01-01 | 2025-12-31 | 38 prelim. |
| CUADRO 37 | Cuadro Nº 37 — Balanza de pagos - presentación normalizada-(MBP6) ** — En millones de dólares. | quarterly | 38 | 2008-01-01 | 2026-03-31 | 38 prelim. |
| CUADRO 38 | Cuadro Nº 38 — Resumen de la cuenta corriente por componentes normalizados- MBP6** — En millon… | annual | 60 | 2008-01-01 | 2025-12-31 | 14 prelim. · 46 no compr. |
| CUADRO 38 | Cuadro Nº 38 — Resumen de la cuenta corriente por componentes normalizados- MBP6** — En millon… | quarterly | 60 | 2008-01-01 | 2026-03-31 | 1 validada · 13 prelim. · 46 no compr. |
| CUADRO 39 | Cuadro Nº 39 — Resumen de la Cuenta Financiera por componentes normalizados-MBP6** — En millon… | annual | 38 | 2008-01-01 | 2025-12-31 | 34 prelim. · 4 no compr. |
| CUADRO 39 | Cuadro Nº 39 — Resumen de la Cuenta Financiera por componentes normalizados-MBP6** — En millon… | quarterly | 38 | 2008-01-01 | 2026-03-31 | 34 prelim. · 4 no compr. |
| CUADRO 40 | Cuadro Nº 40 — Balanza de pagos de Paraguay.** — Presentación analítica - (MBP6) — En millones… | annual | 44 | 2008-01-01 | 2025-12-31 | 44 prelim. |
| CUADRO 40 | Cuadro Nº 40 — Balanza de pagos de Paraguay.** — Presentación analítica - (MBP6) — En millones… | quarterly | 44 | 2008-01-01 | 2026-03-31 | 44 prelim. |
| CUADRO 41 | Cuadro Nº 41 — Posición de inversión internacional (saldos a fin de periodo)-(MBP6)** — En mil… | annual | 42 | 2008-01-01 | 2025-12-31 | 36 prelim. · 6 no compr. |
| CUADRO 41 | Cuadro Nº 41 — Posición de inversión internacional (saldos a fin de periodo)-(MBP6)** — En mil… | quarterly | 42 | 2008-01-01 | 2026-03-31 | 36 prelim. · 6 no compr. |
| CUADRO 42 | Cuadro Nº 42 — Inversión directa: Conciliación entre el principio activo/pasivo y el principio… | annual | 30 | 2008-01-01 | 2024-12-31 | 14 prelim. · 16 no compr. |
| CUADRO 4a | Cuadro Nº 4a — Producto interno bruto a precios de comprador — Por sectores económicos. — Estr… | annual | 21 | 1991-01-01 | 2025-12-31 | 21 prelim. |
| CUADRO 4b | Cuadro Nº 4b — Producto interno bruto a precios de comprador — Por sectores económicos. — Estr… | annual | 21 | 1991-01-01 | 2025-12-31 | 21 prelim. |
| CUADRO 5 | Cuadro Nº 5 — Producto interno bruto por tipo de gasto — En millones de guaraníes corrientes | annual | 19 | 1991-01-01 | 2025-12-31 | 1 prelim. · 18 no compr. |
| CUADRO 55 | Cuadro Nº 55 — Ingreso de divisas - entidades binacionales. — En miles de dólares. | annual | 3 | 1994-01-01 | 2025-12-31 | 3 prelim. |
| CUADRO 55 | Cuadro Nº 55 — Ingreso de divisas - entidades binacionales. — En miles de dólares. | monthly | 3 | 1994-01-01 | 2026-06-30 | 3 prelim. |
| CUADRO 56a | Cuadro Nº 56a — Reservas Internacionales Netas 1/ — En millones de dólares. | annual | 9 | 1990-01-01 | 1993-12-31 | 9 prelim. |
| CUADRO 56a | Cuadro Nº 56a — Reservas Internacionales Netas 1/ — En millones de dólares. | monthly | 9 | 1994-01-01 | 2026-08-31 | 9 prelim. |
| CUADRO 56b | Cuadro Nº 56b — Reservas Internacionales Netas — En millones de dólares. | monthly | 5 | 2009-01-01 | 2026-08-31 | 5 prelim. |
| CUADRO 57a | Cuadro Nº 57a — Retornos interanuales de Reservas Internacionales | monthly | 1 | 2021-01-01 | 2021-12-31 | 1 prelim. |
| CUADRO 57b | Cuadro Nº 57b — Intereses cobrados por colocaciones de las reservas internacionales netas. — E… | monthly | 1 | 1991-01-01 | 2020-12-31 | 1 prelim. |
| CUADRO 58 | Cuadro N° 58 — Remesas Familiares — Ingreso de divisas. — En miles de dólares. | annual | 15 | 2008-01-01 | 2025-12-31 | 15 prelim. |
| CUADRO 58 | Cuadro N° 58 — Remesas Familiares — Ingreso de divisas. — En miles de dólares. | monthly | 15 | 2008-01-01 | 2026-05-31 | 15 prelim. |
| CUADRO 59 | CUADRO N° 59 — Deuda pública externa (*) — En miles de dólares. | annual | 3 | 1994-01-01 | 2025-12-31 | 3 prelim. |
| CUADRO 59 | CUADRO N° 59 — Deuda pública externa (*) — En miles de dólares. | monthly | 4 | 1994-01-01 | 2026-05-31 | 4 prelim. |
| CUADRO 6 | Cuadro Nº 6 — Producto interno bruto trimestral (incluye binacionales) — Por sectores económic… | quarterly | 9 | 1994-01-01 | 2026-03-31 | 1 validada · 8 prelim. |
| CUADRO 6 (Cont.) | Cuadro Nº 6 (Continuación) — Producto interno bruto trimestral (Incluye binacionales) — Por se… | quarterly | 9 | 1995-01-01 | 2026-03-31 | 9 prelim. |
| CUADRO 60a | Cuadro Nº 60a — Tipo de cambio nominal del guaraní | monthly | 4 | 1997-01-01 | 2026-07-31 | 4 prelim. |
| CUADRO 60b | Cuadro Nº 60b — Tipo de cambio real Multilateral - Indice de precios externos — (enero 1995 = … | monthly | 6 | 1995-01-01 | 2026-06-30 | 1 validada · 5 prelim. |
| CUADRO 60c | Cuadro Nº 60c — Tipo de cambio real bilateral — (enero 1995 = 100) | monthly | 5 | 1995-01-01 | 2026-06-30 | 3 validadas · 2 prelim. |
| CUADRO 61 | Cuadro Nº 61 — Compra / Venta de divisas en el mercado cambiario local. — En miles de dólares.… | annual | 6 | 1994-01-01 | 2005-12-31 | 6 prelim. |
| CUADRO 61 | Cuadro Nº 61 — Compra / Venta de divisas en el mercado cambiario local. — En miles de dólares.… | monthly | 170 | 2004-01-01 | 2026-07-31 | 170 prelim. |
| CUADRO 61 | Cuadro Nº 61 — Compra / Venta de divisas en el mercado cambiario local. — En miles de dólares.… | quarterly | 6 | 1997-01-01 | 2003-12-31 | 6 prelim. |
| CUADRO 6a | Cuadro Nº 6 a — Producto interno bruto trimestral (incluye binacionales) — Por sectores económ… | quarterly | 9 | 1994-01-01 | 2026-03-31 | 1 validada · 8 prelim. |
| CUADRO 6a (Cont.) | Cuadro Nº 6a (Continuación) — Producto interno bruto trimestral (Incluye binacionales) — Por s… | quarterly | 9 | 1995-01-01 | 2026-03-31 | 9 prelim. |
| CUADRO 7 | Cuadro Nº 7 — Producto interno bruto trimestral (Incluye binacionales) — Por tipo de gasto. — … | quarterly | 7 | 1994-01-01 | 2026-03-31 | 1 validada · 6 prelim. |
| CUADRO 7 (Cont.) | Cuadro Nº 7 (Continuación) — Producto interno bruto trimestral (Incluye binacionales) — Por ti… | quarterly | 7 | 1995-01-01 | 2026-03-31 | 7 prelim. |
| CUADRO 7a | Cuadro Nº 7a — Producto interno bruto trimestral (Incluye binacionales) — Por tipo de gasto. —… | quarterly | 7 | 1994-01-01 | 2026-03-31 | 1 validada · 6 prelim. |
| CUADRO 7a (Cont.) | Cuadro Nº 7a (Continuación) — Producto interno bruto trimestral (Incluye binacionales) — Por t… | quarterly | 7 | 1995-01-01 | 2026-03-31 | 7 prelim. |
| CUADRO 8 | Cuadro Nº 8 | annual | 8 | 1950-01-01 | 2025-12-31 | 8 prelim. |
| CUADRO 9 | Indicador Mensual de la Actividad Económica del Paraguay (IMAEP). — Índice base 2014 = 100. | monthly | 2 | 1994-01-01 | 2026-06-30 | 2 prelim. |
| CUADRO 9 a | INDICADOR MENSUAL DE LA ACTIVIDAD ECONÓMICA DEL PARAGUAY (IMAEP) — Índice base 2014 = 100. | monthly | 18 | 2014-01-01 | 2026-06-30 | 10 validadas · 8 prelim. |
| Cuadro 21 a | Cuadro Nº 21 a — Agregados Monetarios -Serie Histórica 1/ — En millones de guaranies | monthly | 5 | 1960-01-01 | 2026-06-30 | 5 prelim. |
| Cuadro 43 | Cuadro Nº 43 — Balanza de Bienes — En miles de dólares FOB. | monthly | 8 | 1994-01-01 | 2026-07-31 | 6 prelim. · 2 no compr. |
| Cuadro 44a | Cuadro Nº 44a — Exportaciones por principales productos. — En miles de dólares FOB. | monthly | 17 | 1994-01-01 | 2026-07-31 | 17 prelim. |
| Cuadro 44b | Cuadro Nº 44b — Exportaciones por principales productos. — En cantidades. | monthly | 17 | 1994-01-01 | 2026-07-31 | 17 prelim. |
| Cuadro 45 | Cuadro Nº 45 — Exportaciones registradas. — En miles de dólares FOB. | monthly | 13 | 1994-01-01 | 2026-07-31 | 13 prelim. |
| Cuadro 46a | Cuadro Nº 46a — Exportaciones por niveles de procesamiento. — En miles de dólares FOB. | monthly | 148 | 1994-01-01 | 2026-07-31 | 1 validada · 147 prelim. |
| Cuadro 46b | Cuadro Nº 46b — Exportaciones por niveles de procesamiento. — En toneladas y 1000 Kwh. | monthly | 148 | 1994-01-01 | 2026-07-31 | 148 prelim. |
| Cuadro 47 | Cuadro Nº 47 — Exportaciones por principales productos. — En miles de dólares FOB. | monthly | 18 | 2003-01-01 | 2026-07-31 | 18 prelim. |
| Cuadro 48 | Cuadro Nº 48 — Exportaciones por regímenes aduaneros — En miles de dólares FOB. | monthly | 6 | 2003-01-01 | 2026-07-31 | 6 prelim. |
| Cuadro 49 | Cuadro Nº 49 — Precios Internacionales | monthly | 13 | 1994-01-01 | 2026-08-31 | 13 prelim. |
| Cuadro 50 | Cuadro Nº 50 — Importaciones registradas. — En miles de dólares FOB. | monthly | 13 | 1994-01-01 | 2026-07-31 | 13 prelim. |
| Cuadro 51a | Cuadro Nº 51 a — Importaciones por tipo de bienes. — En miles de dólares FOB | monthly | 64 | 1994-01-01 | 2026-07-31 | 61 prelim. · 3 no compr. |
| Cuadro 51b | Cuadro Nº 51 b — En toneladas. | monthly | 64 | 1994-01-01 | 2026-07-31 | 61 prelim. · 3 no compr. |
| Cuadro 52a | Cuadro Nº 52 a — Importaciones para uso interno y bajo el Régimen de Turismo. — En miles de dó… | monthly | 192 | 2006-01-01 | 2026-07-31 | 183 prelim. · 9 no compr. |
| Cuadro 52b | Cuadro Nº 52 b — Importaciones para uso interno y bajo el Régimen de Turismo. — En toneladas | monthly | 192 | 2006-01-01 | 2026-07-31 | 183 prelim. · 9 no compr. |
| Cuadro 53a | Cuadro Nº 53 a — Importaciones por niveles de procesamiento. — En miles de dólares FOB. | monthly | 149 | 1994-01-01 | 2026-07-31 | 149 prelim. |
| Cuadro 53b | Cuadro Nº 53 b — Importaciones por niveles de procesamiento. — En toneladas | monthly | 149 | 1994-01-01 | 2026-07-31 | 149 prelim. |
| Cuadro 54 | Cuadro Nº 54 — Importaciones por regímenes aduaneros — En miles de dólares FOB. | monthly | 10 | 2003-01-01 | 2026-07-31 | 10 prelim. |

### `eve` — Encuesta de Expectativas de Variables Económicas: inflación, PIB, TPM, tipo de cambio

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| Encuesta de Variables Económicas |  | monthly_survey | 16 | 2006-04-01 | 2026-08-31 | 16 prelim. |

### `exchange_houses` — Boletín de casas de cambio: EEFF, ratios, depósitos y personal por entidad

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| 1. EEFF | Reporte — Importe en Gs — Sistema | annual | 434 | 2016-01-01 | 2026-12-31 | 434 estr. especial |
| 2. Ratios | Sistema | monthly | 240 | 2026-06-01 | 2026-06-30 | 240 estr. especial |
| 3. Dep y Person | Sistema | monthly | 96 | 2026-06-01 | 2026-06-30 | 96 estr. especial |

### `exchange_rates` — Cotizaciones del mercado fluctuante (BCP): USD, EUR, ARS, BRL; promedio y fin de mes; diario del último mes

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| Cotizaciones Diarias | Julio/2026 | daily | 28 | 2026-07-01 | 2026-07-31 | 28 prelim. |
| EURO Fin Mes | Estudios Económicos — COTIZACIÓN DEL EURO EN EL MERCADO FLUCTUANTE — Fin de Período | monthly | 2 | 2002-01-01 | 2026-07-31 | 2 prelim. |
| EURO Prom | Estudios Económicos — COTIZACIÓN DEL EURO EN EL MERCADO FLUCTUANTE — Promedio mensual | monthly | 14 | 2002-01-01 | 2025-12-31 | 14 no compr. |
| PESO Fin Mes | Estudios Económicos — COTIZACIÓN DEL PESO EN EL MERCADO FLUCTUANTE — Fin de Periodo | monthly | 2 | 1994-01-01 | 2026-07-31 | 2 prelim. |
| REAL Fin Mes | Estudios Económicos — COTIZACIÓN DEL REAL EN EL MERCADO FLUCTUANTE — Fin de Periodo | monthly | 2 | 1994-01-01 | 2026-07-31 | 2 prelim. |
| USD Fin Mes | Estudios Económicos — COMPRA — COTIZACIONES DEL DOLAR EN EL MERCADO FLUCTUANTE — Fin de Período | annual | 2 | 1945-01-01 | 1969-12-31 | 2 prelim. |
| USD Prom | Estudios Económicos — COTIZACION DEL DOLAR AMERICANO — Promedio Mensual | monthly | 2 | 1989-01-01 | 2026-07-31 | 2 validadas |

### `financial_indicators` — Indicadores financieros: tasas activas/pasivas por producto, plazo y moneda; saldos; tasas internacionales

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| 1.1 | Cuadro Nº 1.1 — Tasas de interés nominales - Bancos — Promedio mensuales en porcentajes anuale… | monthly | 37 | 2011-01-01 | 2026-06-30 | 37 prelim. |
| 1.2 | Cuadro Nº 1.2 — Tasas de interés efectivas - Bancos — Promedio mensuales en porcentajes anuale… | monthly | 37 | 2011-01-01 | 2026-06-30 | 37 prelim. |
| 2.1 | Cuadro Nº 2.1 — Tasas de interés nominales desglosadas por plazos - Bancos — Promedio mensuale… | monthly | 58 | 2011-01-01 | 2026-06-30 | 58 prelim. |
| 2.2 | Cuadro Nº 2.2 — Tasas de interés efectivas desglosadas por plazos - Bancos — Promedio mensuale… | monthly | 58 | 2011-01-01 | 2026-06-30 | 58 prelim. |
| 3.1 | Cuadro Nº 3.1 — Tasas de interés nominales - Bancos — porcentajes anuales | monthly | 290 | 2011-01-01 | 2026-06-30 | 290 prelim. |
| 3.2 | Cuadro Nº 3.2 — Tasas de interés efectivas - Bancos — porcentajes anuales | monthly | 290 | 2011-01-01 | 2026-06-30 | 290 prelim. |
| 4 | Cuadro Nº 4 — Saldos desglosados por plazo y cartera - Bancos | monthly | 94 | 2011-01-01 | 2026-06-30 | 94 prelim. |
| 5 | Cuadro Nº 5 — Tasas de interés efectivas - Financieras — Promedio mensuales en porcentajes anu… | monthly | 28 | 2011-01-01 | 2026-06-30 | 26 prelim. · 2 no compr. |
| 6 | Cuadro Nº 6 — Tasas de interés efectivas desglosadas por plazos - Financieras — Promedios mens… | monthly | 49 | 2011-01-01 | 2026-06-30 | 46 prelim. · 3 no compr. |
| 7 | Cuadro Nº 7 — Saldos desglosados por plazo y cartera - Financieras | monthly | 94 | 2011-01-01 | 2026-06-30 | 94 prelim. |
| 8 |  | monthly | 15 | 2016-01-01 | 2026-06-30 | 15 prelim. |

### `fx_operations` — Histórico de operaciones cambiarias del BCP (compra/venta/neto por sector)

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| Histórico Operaciones Cambiarias |  | annual | 10 | 1990-01-01 | 2025-12-31 | 10 prelim. |
| Histórico Operaciones Cambiarias |  | monthly | 10 | 1995-01-01 | 2026-07-31 | 10 prelim. |
| Histórico Operaciones Cambiarias |  | quarterly | 10 | 1994-01-01 | 2026-06-30 | 10 prelim. |

### `icc` — Índice de Confianza del Consumidor y subíndices

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| Índice de Confianza del Consumi… |  | monthly | 12 | 2018-01-01 | 2026-07-31 | 12 prelim. |

### `imf_bop`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF Balance of Payments |  | quarterly | 7520 | 1975-01-01 | 2026-06-30 | 7512 prelim. · 8 no compr. |

### `imf_cpi`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF Consumer Price Index |  | monthly | 481 | 1955-01-01 | 2026-07-31 | 432 prelim. · 49 no compr. |
| IMF Consumer Price Index |  | quarterly | 301 | 1955-01-01 | 2026-06-30 | 264 prelim. · 37 no compr. |

### `imf_cpi_wca`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF CPI World and Country Aggre… |  | monthly | 30 | 2010-02-01 | 2026-06-30 | 30 prelim. |

### `imf_ctot`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF Commodity Terms of Trade |  | monthly | 108 | 1980-01-01 | 2026-05-31 | 108 prelim. |

### `imf_eer`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF Effective Exchange Rates |  | monthly | 12 | 1979-01-01 | 2026-06-30 | 12 prelim. |
| IMF Effective Exchange Rates |  | quarterly | 12 | 1979-01-01 | 2026-06-30 | 12 prelim. |

### `imf_er`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF Exchange Rates |  | monthly | 144 | 1957-01-01 | 2026-08-31 | 144 prelim. |
| IMF Exchange Rates |  | quarterly | 144 | 1957-01-01 | 2026-06-30 | 144 prelim. |

### `imf_fsibsis`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF FSI Balance Sheet and Incom… |  | monthly | 289 | 2001-01-01 | 2026-05-31 | 289 prelim. |
| IMF FSI Balance Sheet and Incom… |  | quarterly | 594 | 2001-01-01 | 2026-03-31 | 594 prelim. |

### `imf_fsic`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF FSI Core and Additional Ind… |  | monthly | 237 | 2001-01-01 | 2026-05-31 | 237 prelim. |
| IMF FSI Core and Additional Ind… |  | quarterly | 473 | 2001-01-01 | 2026-03-31 | 473 prelim. |

### `imf_iip`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF International Investment Po… |  | quarterly | 2947 | 1991-01-01 | 2026-06-30 | 2947 prelim. |

### `imf_il`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF International Liquidity |  | monthly | 144 | 1945-01-01 | 2026-07-31 | 144 prelim. |
| IMF International Liquidity |  | quarterly | 144 | 1945-01-01 | 2026-06-30 | 144 prelim. |

### `imf_irfcl`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF International Reserves and … |  | monthly | 1400 | 2000-04-01 | 2026-07-31 | 1223 prelim. · 177 no compr. |
| IMF International Reserves and … |  | quarterly | 1232 | 2000-04-01 | 2026-06-30 | 1162 prelim. · 70 no compr. |

### `imf_itg`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF International Trade in Goods |  | monthly | 19 | 2006-01-01 | 2026-06-30 | 19 prelim. |
| IMF International Trade in Goods |  | quarterly | 18 | 2005-01-01 | 2026-06-30 | 18 prelim. |

### `imf_mfs_cbs`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF MFS Central Bank Data |  | monthly | 270 | 1997-12-01 | 2026-07-31 | 270 prelim. |
| IMF MFS Central Bank Data |  | quarterly | 270 | 1997-10-01 | 2026-06-30 | 270 prelim. |

### `imf_mfs_dc`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF MFS Depository Corporations |  | monthly | 496 | 1997-12-01 | 2026-07-31 | 496 prelim. |
| IMF MFS Depository Corporations |  | quarterly | 523 | 1997-10-01 | 2026-06-30 | 523 prelim. |

### `imf_mfs_ir`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF MFS Interest Rate |  | monthly | 74 | 1957-01-01 | 2026-07-31 | 74 prelim. |
| IMF MFS Interest Rate |  | quarterly | 74 | 1957-01-01 | 2026-06-30 | 74 prelim. |

### `imf_mfs_ma`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF MFS Monetary Aggregates |  | monthly | 40 | 1997-12-01 | 2026-06-30 | 40 prelim. |
| IMF MFS Monetary Aggregates |  | quarterly | 40 | 1997-10-01 | 2026-06-30 | 40 prelim. |

### `imf_mfs_odc`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF MFS Other Depository Corpor… |  | monthly | 233 | 1997-12-01 | 2026-07-31 | 233 prelim. |
| IMF MFS Other Depository Corpor… |  | quarterly | 233 | 1997-10-01 | 2026-06-30 | 233 prelim. |

### `imf_pcps`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF Primary Commodity Price Sys… |  | monthly | 434 | 1992-01-01 | 2026-07-31 | 404 prelim. · 30 no compr. |
| IMF Primary Commodity Price Sys… |  | quarterly | 418 | 1992-01-01 | 2026-06-30 | 404 prelim. · 14 no compr. |

### `imf_pi_wca`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF Production Indexes World an… |  | monthly | 16 | 2015-01-01 | 2026-05-31 | 16 prelim. |

### `imf_qgdp_wca`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF Quarterly GDP World and Cou… |  | quarterly | 300 | 2012-01-01 | 2026-03-31 | 300 prelim. |

### `imf_qnea`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF National Economic Accounts … |  | quarterly | 595 | 1990-01-01 | 2026-06-30 | 298 prelim. · 297 no compr. |

### `imf_rsui`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF Reported Social Unrest Index |  | monthly | 16 | 1990-01-01 | 2026-05-31 | 16 prelim. |

### `imf_wpfxi`

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| IMF Working Paper Foreign Excha… |  | monthly | 93 | 2000-01-01 | 2024-12-31 | 93 prelim. |
| IMF Working Paper Foreign Excha… |  | quarterly | 93 | 2000-01-01 | 2024-12-31 | 93 prelim. |

### `ine_ephc` — INE: Anexo EPHC trimestral: fuerza de trabajo, ocupación, informalidad, ingresos

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| CARACTERÍSTICAS_OCU | Población ocupada por año y trimestre, según área de residencia y caracteristicas seleccionada… | quarterly | 57 | 2017-01-01 | 2026-06-30 | 57 prelim. |
| CATEGORÍAOCUPACIONAL | Población ocupada por año y trimestre, según área de residencia y categoría ocupacional en la … | quarterly | 29 | 2017-01-01 | 2026-06-30 | 29 prelim. |
| FORMALIDAD | Población ocupada por año y ocupación formal1/ no agropecuaria, según categoría ocupacional en… | quarterly | 24 | 2017-01-01 | 2026-06-30 | 24 prelim. |
| HORASHABITUALES | Población ocupada por año y trimestre, según área de residencia y horas habitualmente trabajad… | quarterly | 15 | 2017-01-01 | 2026-06-30 | 15 prelim. |
| INGRESOSPORHORAS | Promedio de ingreso por hora en guaraníes corriente1/ de la población ocupada por año, trimest… | quarterly | 90 | 2017-01-01 | 2026-03-31 | 90 no compr. |
| INGRESOS_CATE | Promedio de ingreso mensual corriente1/ (miles de guaraníes) de la población ocupada por año, … | quarterly | 90 | 2017-01-01 | 2026-03-31 | 90 no compr. |
| INGRESOS_OCUP | Promedio de ingreso mensual corriente1/ (miles de guaraníes) de la población ocupada por año, … | quarterly | 198 | 2017-01-01 | 2026-03-31 | 198 no compr. |
| INGRESOS_SECTOR | Promedio de ingreso mensual corriente1/ (miles de guaraníes) de la población ocupada por año, … | quarterly | 162 | 2017-01-01 | 2026-03-31 | 162 no compr. |
| PROMEDIO DE HORAS | Promedio de horas habitualmente trabajadas (semanal) en la ocupación principal de la población… | quarterly | 81 | 2017-01-01 | 2026-06-30 | 81 prelim. |
| PROMEDIODEAÑODEESTUDIO | Promedio de años de estudio de la población ocupada por año, trimestre y sexo, según área de r… | quarterly | 126 | 2017-01-01 | 2026-03-31 | 126 no compr. |
| Población Total | Población total por año, trimestre y sexo, según clasificación económica y área de residencia.… | quarterly | 81 | 2017-01-01 | 2026-06-30 | 81 prelim. |
| SECTORECONÓMICO | Población ocupada por año y trimestre, según área de residencia y sector económico en la ocupa… | quarterly | 30 | 2017-01-01 | 2026-06-30 | 30 prelim. |
| TAMAÑODEEMPRESA | Población ocupada por año y trimestre, según área de residencia y tamaño de la empresa en la o… | quarterly | 24 | 2017-01-01 | 2026-06-30 | 24 prelim. |
| TIEMPOEXPERIENCIA | Población ocupada por año y trimestre, según área de residencia y tiempo de experiencia en la … | quarterly | 18 | 2017-01-01 | 2026-06-30 | 18 prelim. |
| Tasas | Tasa de la Fuerza de Trabajo, Ocupación, Desocupación, Subocupación por Insuficiencia de tiemp… | quarterly | 63 | 2017-01-01 | 2026-06-30 | 21 prelim. · 42 no compr. |

### `insurance_annex` — Anexo estadístico de seguros (anual): primas, siniestros, reaseguros por rama

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| 1.1 | Primas Directas (Guaraníes) | annual | 28 | 2009-01-01 | 2025-12-31 | 28 prelim. |
| 1.10 | Gastos de liquidación de siniestros — Gastos de Salvataje y Recupero — Total Gastos de liquida… | annual | 58 | 2009-01-01 | 2025-12-31 | 58 prelim. |
| 1.11 | Participación Recupero reaseguros cedidos local - Proporcional — Participación Recupero reaseg… | annual | 78 | 2009-01-01 | 2025-12-31 | 78 prelim. |
| 1.12 | Participación Recupero reaseguros cedidos exterior - Proporcional — Participación Recupero rea… | annual | 78 | 2009-01-01 | 2025-12-31 | 78 prelim. |
| 1.13 | Siniestros Reaseguros Aceptados Local (contratos proporcionales) (Guaraníes) — Siniestros Reas… | annual | 78 | 2009-01-01 | 2025-12-31 | 78 prelim. |
| 1.14 | Siniestros Reaseguros Aceptados exterior (contratos proporcionales) (Guaraníes) — Siniestros R… | annual | 78 | 2009-01-01 | 2025-12-31 | 78 prelim. |
| 1.15 | Constitución de Provisiones Técnicas de Siniestros (Guaraníes) | annual | 21 | 2009-01-01 | 2025-12-31 | 21 prelim. |
| 1.16 | Recupero de Siniestros Directos (Guaraníes) | annual | 18 | 2009-01-01 | 2025-12-31 | 18 prelim. |
| 1.17 | Siniestros Recuperados Reaseguros cedidos (contratos proporcionales) (Guaraníes) - Local — Sin… | annual | 78 | 2009-01-01 | 2025-12-31 | 78 prelim. |
| 1.18 | Siniestros Recuperados Reaseguros cedidos exterior (contratos proporcionales) (Guaraníes) — Si… | annual | 78 | 2009-01-01 | 2025-12-31 | 78 prelim. |
| 1.19 | Participación Recupero Reaseguros Aceptados - Proporcionales (Guaraníes) - Local — Participaci… | annual | 78 | 2009-01-01 | 2025-12-31 | 78 prelim. |
| 1.2 | Primas Reaseguros Aceptados (Local) Contratos Proporcionales (Guaraníes) — Primas Reaseguros A… | annual | 81 | 2009-01-01 | 2025-12-31 | 81 prelim. |
| 1.20 | Participación Recupero Reaseguros Aceptados - Proporcionales (Guaraníes) - Exterior — Particip… | annual | 78 | 2009-01-01 | 2025-12-31 | 78 prelim. |
| 1.21 | Desafectación de Provisiones Técnicas de Siniestros (Guaraníes) | annual | 21 | 2009-01-01 | 2025-12-31 | 21 prelim. |
| 1.22 | Reintegro Gastos de Revisión y examen de asegurabilidad (Guaraníes) — Intereses por Financiami… | annual | 89 | 2009-01-01 | 2025-12-31 | 89 prelim. |
| 1.23 | Comisión reaseguros cedidos - contratos proporcionales (Guaraníes) — Participación utilidades … | annual | 95 | 2009-01-01 | 2025-12-31 | 95 prelim. |
| 1.24 | Comisión reaseguros cedidos - contratos proporcionales (Guaraníes) - exterior — Participación … | annual | 95 | 2009-01-01 | 2025-12-31 | 95 prelim. |
| 1.25 | Intereses sobre reservas retenidas - contratos proporcionales (Guaraníes) — Intereses sobre re… | annual | 78 | 2009-01-01 | 2025-12-31 | 78 prelim. |
| 1.26 | Intereses sobre reserva retenidas - contratos proporcionales (Guaraníes) - Exterior — Interese… | annual | 78 | 2009-01-01 | 2025-12-31 | 78 prelim. |
| 1.27 | Desafectación de previsiones (Guaraníes) | annual | 8 | 2009-01-01 | 2025-12-31 | 8 prelim. |
| 1.28 | Comisión de seguros directos (Guaraníes) — Revisión examen de asegurabilidad (Guaraníes) — Fom… | annual | 104 | 2009-01-01 | 2025-12-31 | 104 prelim. |
| 1.29 | Gastos de cesión reaseguros cedidos - contratos no proporcionales (Local) — Gastos de cesión r… | annual | 78 | 2009-01-01 | 2025-12-31 | 78 prelim. |
| 1.3 | Primas Reaseguros Aceptados (Exterior) Contratos Proporcionales (Guaraníes) — Primas Reaseguro… | annual | 81 | 2009-01-01 | 2025-12-31 | 81 prelim. |
| 1.30 | Gastos de cesión reaseguros cedidos - contratos no proporcionales (Guaraníes) — Intereses sobr… | annual | 78 | 2009-01-01 | 2025-12-31 | 78 prelim. |
| 1.31 | Comisión reaseguros aceptados - contratos proporcionales (Guaraníes) — Participación utilidade… | annual | 104 | 2009-01-01 | 2025-12-31 | 104 prelim. |
| 1.32 | Comisiones reaseguros aceptados - exterior (Guaraníes) — Participación utilidades reaseguros a… | annual | 104 | 2009-01-01 | 2025-12-31 | 102 prelim. · 2 no compr. |
| 1.33 | Gastos Técnicos de Explotación | annual | 15 | 2009-01-01 | 2025-12-31 | 15 prelim. |
| 1.34 | Constitución de Previsiones | annual | 8 | 2009-01-01 | 2025-12-31 | 8 prelim. |
| 1.35 | Ingresos de inversiones | annual | 6 | 2009-01-01 | 2025-12-31 | 6 prelim. |
| 1.36 | Gastos de inversiones | annual | 7 | 2009-01-01 | 2025-12-31 | 7 prelim. |
| 1.37 | Ganancias Extraordinarias | annual | 4 | 2009-01-01 | 2025-12-31 | 4 prelim. |
| 1.38 | Perdidas Extraordinarias | annual | 5 | 2009-01-01 | 2025-12-31 | 5 prelim. |
| 1.4 | Desafectación de Provisiones Técnicas de Seguros (Guaraníes) | annual | 20 | 2009-01-01 | 2025-12-31 | 20 prelim. |
| 1.5 | Primas Reaseguros Cedidos (Local) Contratos Proporcionales | annual | 26 | 2009-01-01 | 2025-12-31 | 26 prelim. |
| 1.6 | Primas Reaseguros Cedidos (Exterior) Contratos Proporcionales | annual | 26 | 2009-01-01 | 2025-12-31 | 26 prelim. |
| 1.7 | Constitución de Provisiones Técnicas de Seguros | annual | 20 | 2009-01-01 | 2025-12-31 | 20 prelim. |
| 1.8 | Siniestros Seguros Directos | annual | 22 | 2009-01-01 | 2025-12-31 | 22 prelim. |
| 1.9 | Prestaciones e Indemnizaciones Seguros de Vida | annual | 20 | 2009-01-01 | 2025-12-31 | 20 prelim. |
| 2.1 | Activos | annual | 10 | 2009-01-01 | 2025-12-31 | 10 prelim. |
| 2.2 | Pasivos | annual | 12 | 2009-01-01 | 2025-12-31 | 12 prelim. |
| 2.3 | Patrimonio Neto | annual | 6 | 2009-01-01 | 2025-12-31 | 6 prelim. |

### `interbank_market` — Mercado interbancario diario: call PYG/USD, REPO, FPL/FPD, mercado secundario LRM y bonos

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| Datos | Mercado Interbancario de Fondos (hasta 1 día) — Tasas de Interés de Facilidades Permanentes fi… | daily | 32 | 2010-01-04 | 2026-08-14 | 32 estr. especial |
| Datos (+ de 1 día) | Mercado Interbancario de Fondos (más de 1 día) | daily | 51 | 2012-01-05 | 2026-08-14 | 51 estr. especial |
| Mdo Secundario | Operaciones del Mercado Secundario de LRM y Bonos | irregular_daily | 1263 | 2012-03-09 | 2026-08-14 | 1263 estr. especial |

### `liquidity_facility` — Subastas de depósito/repo de administración de liquidez de corto plazo

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| ADM- LIQ- DEPOSITO | Resultado de Subasta de Depósito - Administracion de Liquidez de Corto Plazo. | irregular_daily | 56 | 2016-01-20 | 2021-09-09 | 56 estr. especial |

### `lrm_auctions` — Subastas de Letras de Regulación Monetaria (LRM): montos y tasas ofertadas/asignadas

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| Subastas 2013 | SUBASTAS DE LRM 20131 | irregular_daily | 524 | 2013-01-08 | 2013-09-26 | 524 estr. especial |
| Subastas 2014 | SUBASTAS DE LRM 20141 | irregular_daily | 51 | 2014-01-09 | 2014-09-25 | 51 estr. especial |
| Subastas 2024 | SUBASTAS DE LRM 2020 | irregular_daily | 1 | 2024-03-27 | 2024-03-27 | 1 estr. especial |
| Subastas 2025 | SUBASTAS DE LRM 2020 | irregular_daily | 11 | 2025-12-23 | 2025-12-23 | 11 estr. especial |
| Subastas de LRM | SUBASTAS DE LRM 2020 | irregular_daily | 353 | 2013-01-25 | 2026-07-30 | 353 estr. especial |

### `mef_central_government` — MEF: Estado de operaciones de la Administración Central (MEFP 2001), mensual

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| Serie | ESTADO DE OPERACIONES DEL GOBIERNO  - Administración Central | monthly | 82 | 2003-01-01 | 2026-08-31 | 54 prelim. · 28 no compr. |

### `payments` — Boletín de sistemas de pago: SIPAP (LBTR, ACH, SPI), cheques, tarjetas, AFD, Hacienda, cooperativas

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| AFD 01 | Pagos de Intereses y Capital de Bonos emitidos por la AFD (DEPO) — En PYG — Importe Destino — … | monthly | 1 | 2014-06-01 | 2026-07-31 | 1 prelim. |
| AFD 02 | Transferencias de la AFD a las Entidades Financieras - LBTR & ACH — En PYG | monthly | 5 | 2013-11-01 | 2026-07-31 | 1 prelim. · 4 no compr. |
| AFD 03 | Transferencias a la AFD de Entidades Financieras - LBTR & ACH — En PYG | monthly | 5 | 2013-11-01 | 2026-07-31 | 1 prelim. · 4 no compr. |
| AFD 04 | Transferencias de la AFD a las Entidades Financieras - LBTR & ACH | monthly | 2 | 2013-11-01 | 2026-07-31 | 2 prelim. |
| AFD 05 | Transferencias a la AFD de Entidades Financieras - LBTR & ACH — En USD | monthly | 2 | 2013-11-01 | 2026-07-31 | 2 prelim. |
| CCC 01 | Cheques Compensados - (Cámara Compensadora de Cheques - BANCARD) PYG — Cheques Compensados en … | monthly | 6 | 2013-11-01 | 2026-07-31 | 6 no compr. |
| CCC 02 | Cheques Pagados por Entidad Bancaria - (Cámara Compensadora de Cheques - BANCARD) | monthly | 42 | 2013-11-01 | 2026-07-31 | 40 prelim. · 2 no compr. |
| CCC 03 | Cheques Pagados por rango de monto - (Cámara Compensadora de Cheques - BANCARD) | monthly | 14 | 2013-11-01 | 2026-07-31 | 14 prelim. |
| CCC 04 | Cheques rechazados en el País, por causales - (Cámara Compensadora de Cheques - BANCARD) | monthly | 24 | 2013-11-01 | 2026-07-31 | 24 prelim. |
| CCCoop | Cámara Compensadora de Cooperativas - CABAL PYG | monthly | 10 | 2021-12-01 | 2026-07-31 | 10 prelim. |
| CCE | Transferencias entre clientes de EMPE (Cámara Compensadora de EMPE) — Transferencias entre cli… | monthly | 2 | 2020-10-01 | 2026-07-31 | 2 prelim. |
| MIHA 01 | Pagos de Intereses y Capital de Bonos emitidos por el Ministerio de Hacienda (DEPO) — En PYG | monthly | 1 | 2013-11-01 | 2026-07-31 | 1 prelim. |
| MIHA 02 | Transferencias del Ministerio de Hacienda a Clientes de Entidades Financieras — LBTR & ACH - E… | monthly | 5 | 2013-11-01 | 2026-07-31 | 1 prelim. · 4 no compr. |
| MIHA 03 | Transferencias al Ministerio de Hacienda de Entidades Financieras — LBTR & ACH - En PYG | monthly | 5 | 2013-11-01 | 2026-07-31 | 1 prelim. · 4 no compr. |
| MIHA 04 | Transferencias del Ministerio de Hacienda a Clientes de Entidades Financieras — LBTR & ACH - E… | monthly | 3 | 2013-11-01 | 2026-07-31 | 3 prelim. |
| MIHA 05 | Transferencias al Ministerio de Hacienda de Entidades Financieras — LBTR & ACH - En USD | monthly | 3 | 2013-11-01 | 2026-07-31 | 3 prelim. |
| OMP 01 | Tarjetas de Crédito - (Operadoras de Medios de Pago) | monthly | 14 | 2018-01-01 | 2026-07-31 | 14 prelim. |
| OMP 01_02 | Tarjetas de Crédito - Compras por tecnología | monthly | 14 | 2024-01-01 | 2026-07-31 | 14 prelim. |
| OMP 02 | Tarjetas de Débito - (Operadoras de Medios de Pago) | monthly | 12 | 2018-01-01 | 2026-07-31 | 12 prelim. |
| OMP 02_02 | Tarjetas de Débito - Compras por tecnología | monthly | 14 | 2024-01-01 | 2026-07-31 | 14 prelim. |
| OMP 03 | Tarjetas Prepagas - (Operadoras de Medios de Pago) | monthly | 12 | 2018-01-01 | 2026-07-31 | 12 prelim. |
| OMP 03_02 | Tarjetas Pre Paga - Compras por tecnología | monthly | 14 | 2024-01-01 | 2026-07-31 | 14 prelim. |
| OMP 04 | Infraestructura de Operadoras de Medios de Pago | monthly | 21 | 2018-01-01 | 2026-07-31 | 21 prelim. |
| SIPAP_01 | Transferencias entre Entidades Financieras en el LBTR | monthly | 6 | 2013-11-01 | 2026-07-31 | 6 prelim. |
| SIPAP_02 | Transferencias entre Clientes de Entidades Financieras en el LBTR | monthly | 6 | 2013-11-01 | 2026-07-31 | 6 prelim. |
| SIPAP_03 | Transferencias entre clientes a través del Servicio Patrocinador (LBTR) | monthly | 16 | 2021-10-01 | 2026-07-31 | 16 prelim. |
| SIPAP_04 | Transferencias entre Clientes de Entidades Financieras, por rango de Monto | monthly | 74 | 2013-11-01 | 2026-07-31 | 74 prelim. |
| SIPAP_05 | Transferencias entre Clientes por Entidades Financieras en el LBTR — Por Entidad Financiera | monthly | 73 | 2013-11-01 | 2026-07-31 | 73 prelim. |
| SIPAP_06 | Transferencias entre Clientes de Entidades Financieras por ACH — ACH liquida sólo PYG | monthly | 3 | 2013-11-01 | 2026-07-31 | 3 prelim. |
| SIPAP_07 | Transferencias entre Clientes de Entidades Financieras por SPI — SPI liquida sólo PYG — Cant. … | monthly | 2 | 2022-05-01 | 2026-07-31 | 2 prelim. |
| SIPAP_08 | Transferencias entre Clientes por Entidades Financieras en el SPI — Por Entidad Financiera | monthly | 55 | 2022-05-01 | 2026-07-31 | 3 prelim. · 52 no compr. |
| SIPAP_09 | Transferencias entre Clientes de Entidades Financieras por SPI por día — SPI liquida sólo PYG … | monthly | 16 | 2022-05-01 | 2026-07-31 | 16 prelim. |
| SIPAP_10 | Transferencias entre Clientes de Entidades Financieras por SPI por franja horaria — SPI liquid… | monthly | 24 | 2022-05-01 | 2026-07-31 | 24 prelim. |
| SIPAP_11 | Transferencias entre clientes a través del Servicio Patrocinador (SPI) | monthly | 8 | 2023-07-01 | 2026-07-31 | 8 prelim. |
| SIPAP_12 | Transferencias por funcionalidades del SPI | monthly | 18 | 2022-05-01 | 2026-07-31 | 16 prelim. · 2 no compr. |
| SIPAP_13 | Tipo de Alias registrados — 2023/01 — 2023/02 — 2023/03 — 2023/04 — 2023/05 | monthly | 7 | 2023-08-01 | 2026-07-31 | 7 prelim. |
| SIPAP_14 | Alias registrados por entidad | monthly | 24 | 2023-01-01 | 2026-07-31 | 24 prelim. |
| SIPAP_15 | Alias operativos por entidad (*) | monthly | 24 | 2023-01-01 | 2026-07-31 | 24 prelim. |

### `tcn_referential_daily` — Tipo de cambio nominal referencial diario PYG/USD compra y venta (BCP)

| Tabla / hoja | Título publicado | Frecuencia | Nº series | Desde | Hasta | Nivel de verificación |
|---|---|---|---|---|---|---|
| TCN Referencial Diario | PLANILLA DE COTIZACIONES DEL AÑO 2016 - MERCADO LIBRE FLUCTUANTE - COMPRA | daily | 2 | 2012-08-06 | 2026-08-25 | 2 prelim. |

### `securities_trades` — Negociaciones bursátiles (vista `research.transactions`)

| Instrumento | Operaciones | Desde |
|---|---|---|
| CDA | 160.754 | 2023-01-02 |
| Bonos corporativos | 81.109 | 2010-10-07 |
| Bonos subordinados | 20.980 | 2010-11-04 |
| Bono financiero | 20.975 | 2015-07-15 |
| Fondo mutuo | 8.698 | 2023-01-02 |
| Acción | 8.611 | 2010-01-12 |
| Otros activos / título extranjero / fondo de inversión / fideicomiso | 9.843 | 2011-03-22 |
| BBCP (bonos del BCP) | 959 | 2010-05-17 |
| Bonos municipales | 772 | 2012-11-28 |
| Bonos del Tesoro | 484 | 2023-01-03 |
| LRM | 141 | 2023-01-27 |

Mercados primario, secundario y repo, en PYG y USD, con emisor, ISIN y casa de bolsa. Nivel: **validada por regla (estructural)**. Hasta 2026-08-19.

## 4. Archivos y hojas no incorporados a la base

| Archivo / hoja | Motivo | Relevancia |
|---|---|---|
| `IMF_Data/International Trade in Goods (by partner country) (IMTS).csv` | No tiene parser; 12.811 series (exportaciones e importaciones por país socio, mensual y trimestral) | Alta para F2 y para ponderadores comerciales de B2 |
| `IMF_Data/Financial Soundness Indicators (FSI), Country Metadata Table 2.csv` | Solo metadatos (1.988 registros, 0 observaciones) | Documentación de definiciones FSI |
| `exchange_houses`: hojas 1.1 BG, 1.2 EERR, 2.1 Ratios, 3.1 Dep y P., Tablas ref., Notas | Hojas de presentación; los datos vienen de las hojas base | Baja |
| `payments`: hoja BIC E. Bancarias | Lista de códigos BIC | Referencia para F4 |
| Portadas e índices (Anexo, IDB, Ind. Financieros, Seguros, Inversión Directa, Pagos) y `ine_ephc` Hoja2 (vacía) | Sin datos | Ninguna |

Todas las demás hojas con datos de los 26 libros Excel y los 2 CSV de mercado entraron a la base.

## 5. Qué no hay en la base (transversal)

*Entre corchetes: qué parte está disponible **fuera** de la base desde el 2026-09-24 (ver § 6).*

- Clima y ENSO: ONI, precipitación, temperatura, nivel de ríos, restricciones de navegación. **[Fuera de la base: ENSO, lluvia, SPI, niveles del río Paraguay, Itaipú, vegetación; temperatura y SPEI en descarga. Siguen faltando las restricciones de navegación y los fletes.]**
- Variables de EE.UU. y globales financieras: índice dólar amplio (DXY), VIX, IPC de EE.UU., rendimientos del Tesoro de EE.UU.
- Vintages o fechas reales de publicación; pronósticos archivados; microdatos de encuestas (EVE, ICC, EPHC); datos de préstamo a préstamo o de prestatario. **[Fuera de la base: microdatos EPH/EPHC 1997–2025 y vintages de pronósticos ENSO 2003–2025-04.]**
- Reservas bancarias diarias en el BCP (encaje, cuenta corriente); saldos diarios de liquidez; flujos diarios del Tesoro.
- Flujo de órdenes FX firmado por agente, cotizaciones intradía, posiciones cambiarias por banco.
- Cooperativas por entidad (solo el agregado Tipo A del Anexo, 2017-12 a 2025-11); facturación electrónica (SIFEN); aduanas a nivel de transacción; microprecios del IPC; ponderadores por grupo de hogares. **[Fuera de la base: balances por cooperativa tipo A 2017–2025 (INCOOP), aduanas a nivel ítem 1997–2026 (DNA) y ponderadores oficiales del IPC por artículo (465). Siguen faltando los ponderadores por grupo de hogares, los microprecios y SIFEN.]**
- Resultados de subastas de bonos del Tesoro (solo aparecen sus negociaciones bursátiles desde 2023). **[Fuera de la base: subastas 2006–2026, *security master* de 194 emisiones y tenencias por tenedor en 4 cortes (MEF).]**

## 6. Datos disponibles fuera de la base (2026-09-24)

Estos archivos **no pasan por el pipeline de la base**: no hay parser, registro de fuentes ni releases. Integrarlos exigiría el flujo de `docs/ARCHITECTURE.md`. Las descargas crudas se conservan localmente con hash y están excluidas de Git.

### 6.1 Bloque clima/agro — `data/clima/` (procesado, formato largo)

Catálogo completo con rangos calculados de los datos: [`data/clima/README.md`](../data/clima/README.md) y `data/clima/00_catalogo_variables.csv`.

| Archivo | Contenido | Cobertura |
|---|---|---|
| `enso_indices.csv` | ONI, RONI, MEI.v2, SOI, Niño 3.4 | 1950 → 2026-08 |
| `enso_iri_pronosticos.csv` | Vintages de probabilidades ENSO: IRI probabilístico y CPC/IRI oficial (dos productos, no empalmados) | 2003-06 → 2025-04 |
| `clima_chirps_precipitacion.csv`, `clima_spi.csv` | Lluvia CHIRPS y SPI 1/3/6/12, por departamento, nacional y nacional agrícola | 1981 → 2026-08 |
| `clima_era5land.csv`, `clima_spei.csv` | Temperatura media, máxima y mínima; días ≥ 35 °C y ≤ 0 °C; humedad del suelo; SPEI | **en descarga** (ERA5-Land horario 1981 → 2026-08) |
| `clima_modis_vegetacion.csv` | NDVI y EVI MODIS, por departamento y nacional | 2000-02 → 2026-08 |
| `rios_dmh_diario.csv`, `rios_dmh_mensual.csv` | Nivel del río Paraguay: Asunción, Pilar, Concepción | 1904/1909/1932 → 2026-09 |
| `hidro_itaipu_diario.csv`, `hidro_itaipu_mensual.csv` | Itaipú: caudales, nivel, volumen útil, generación (total, 50/60 Hz, Brasil) | 2000 → 2026-09 |
| `agro_mag_departamental.csv` | MAG: superficie, producción y rendimiento de 16–22 cultivos por departamento (versiones en conflicto conservadas) | 2007/08 → 2024/25 |
| `agro_faostat_nacional.csv`, `agro_usda_psd_nacional.csv` | Producción nacional FAOSTAT y oferta y uso USDA PSD | 1961 → 2024; 1960 → 2026 |
| `abasto_*.csv` | Mercado de Abasto: precios mayoristas diarios por origen PY/AR/BR; ingresos mensuales | 2021 → 2026-06; 1991 → 2023 |
| `eventos_emdat_*.csv` | EM-DAT: 61 desastres en Paraguay | 1963 → 2025 |
| `calendario_cultivos.csv` | Ventanas de siembra y cosecha (citas USDA verificadas) | estático |

### 6.2 Adquisiciones no climáticas — `input/acquisition_candidates/`

| Carpeta | Contenido verificado | Brecha |
|---|---|---|
| `web_no_clima_2026-09-23/` | MEF: subastas del Tesoro 2006–2026, *security master* y tenencias (4 cortes); INCOOP: balances por cooperativa 2017–2025; INE: EPH 2008–2016; IPS: anuarios 2014–2025; SITUFIN anual | C3, C2, N2, N1 |
| `web_brechas_2026-09-23/` | INE: EPH/EPHC 1997–2007 y 2017–2025; DNA: aduanas a nivel ítem 1997-01 → 2026-08 (4,1 GB en gzip); BCRA y paralelo argentino diario; **extraídos** a CSV: ponderaciones del IPC base 2017 (465 artículos) y decretos de salario mínimo 1989–2025 | N2, F5, F2, N5, D4, N11 |

Detalle, verificaciones y limitaciones: el `README.md` de cada carpeta.
