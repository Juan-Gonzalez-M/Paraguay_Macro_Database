# 13 · D5 — Clima y riesgo de crédito

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 20:02:23 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

## 1. Resumen y pregunta de investigación

La mora agregada oculta dónde se concentra la vulnerabilidad climática y mezcla riesgo realizado con cambios en la oferta de crédito. Este proyecto es el puente entre el bloque climático (D1–D4) y la estabilidad financiera.

- **Pregunta:** ¿afecta ENSO/el clima a la mora y a la oferta de crédito según la exposición preexistente de cada banco al sector agropecuario?
- **Estimando:** respuesta de los resultados banco-mes (mora, crédito, provisiones, refinanciaciones) a `shock ENSO × participación predeterminada de la cartera en agricultura/ganadería/cultivos`.
- **Evidencia:** forma reducida; más fuerte con comparación dentro de banco entre sectores (banco-sector-mes).

## 2. Estrategia empírica propuesta

1. **Mapa de exposición (2016–2026):** participación de agricultura, ganadería y de cada cultivo (soja, trigo, arroz, algodón) en la cartera de cada entidad, por moneda; congelada a diciembre del año previo a cada episodio.
2. **Stress test descriptivo:** trayectoria de la mora por sector y de los ratios de refinanciados, reestructurados y renovados (RRR) alrededor de los episodios ENSO del período (La Niña 2020–2023 con sequía; El Niño 2023–24), comparando bancos más y menos expuestos.
3. **Event study / LP banco-sector-mes:** `y_{b,s,t+h} = β_h · ENSO_t × agro_s + efectos fijos banco-tiempo y banco-sector`, h = 0–18 meses. Resultados separados: mora (vencida/total), nueva oferta (Δ cartera vigente), reprogramación (RRR) y provisiones.
4. **Canal de seguro:** relación anual entre siniestros agropecuarios y mora agropecuaria (2016–2025).
5. **Placebos:** sectores no expuestos (consumo, comercio, vivienda) y bancos diversificados; pre-tendencias.

Con 127 meses y pocos eventos ENSO desde 2016, la inferencia debe ser prudente: la ficha pide usar primero el stress test transparente.

## 3. Series extraídas

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `imaep9a_primario` | IMAEP sector primario serie original (2014-) | `economic_annex` CUADRO 9 a | mensual | 2014-01-01 | 2026-06-01 | 150 | INDEX | Validada por regla | Canal: cash flow agropecuario |
| `imaep_original` | IMAEP serie original (1994-) | `economic_annex` CUADRO 9 | mensual | 1994-01-01 | 2026-06-01 | 390 | INDEX | Preliminar | Control de actividad |
| `pib_real_agricultura` | PIB trimestral real: agricultura | `economic_annex` CUADRO 6 | trimestral | 1994-01-01 | 2026-01-01 | 129 | PYG (millones) | Preliminar | Canal: cash flow agrícola |
| `pib_real_ganaderia` | PIB trimestral real: ganadería forestal pesca y minería | `economic_annex` CUADRO 6 | trimestral | 1994-01-01 | 2026-01-01 | 129 | PYG (millones) | Preliminar | Canal: cash flow ganadero |
| `expo_ton_soja` | Exportaciones de granos de soja (toneladas) | `economic_annex` Cuadro 44b | mensual | 1994-01-01 | 2026-07-01 | 391 | TONNES | Preliminar | Canal: cosecha |
| `expo_ton_maiz` | Exportaciones de maíz (toneladas) | `economic_annex` Cuadro 44b | mensual | 1994-01-01 | 2026-07-01 | 391 | TONNES | Preliminar | Canal: cosecha |
| `expo_ton_carne` | Exportaciones de carne (toneladas) | `economic_annex` Cuadro 44b | mensual | 1994-01-01 | 2026-07-01 | 391 | TONNES | Preliminar | Canal: ganadería |
| `soja_chicago` | Soja Chicago USD/t | `economic_annex` Cuadro 49 | mensual | 1994-01-01 | 2026-08-01 | 392 | USD_PER_TONNE | Preliminar | Control: precio (separar de cantidad) |
| `carne_chicago` | Carne Chicago USD/t | `economic_annex` Cuadro 49 | mensual | 1994-01-01 | 2026-08-01 | 392 | USD_PER_TONNE | Preliminar | Control: precio |
| `pyg_usd_prom_venta` | PYG por USD promedio mensual | `exchange_rates` USD Prom | mensual | 1989-01-01 | 2026-07-01 | 451 | PYG_PER_USD | Validada por regla | Control: valuación de cartera en ME |
| `tpm` | Tasa de política monetaria | `economic_annex` CUADRO 19  | mensual | 2011-05-01 | 2026-07-01 | 183 | PERCENT | Preliminar | Control |
| `seg_agro_primas` | Seguros: primas directas rama agropecuaria (anual) | `insurance_annex` 1.1 | anual | 2009-01-01 | 2025-01-01 | 17 | PYG | Preliminar | Canal: seguro |
| `seg_agro_siniestros` | Seguros: siniestros directos rama agropecuaria (anual) | `insurance_annex` 1.8 | anual | 2009-01-01 | 2025-01-01 | 17 | PYG | Preliminar | Resultado: pérdidas aseguradas por clima |
| `seg_agro_recupero_siniestros` | Seguros: recupero de siniestros directos rama agropecuaria | `insurance_annex` 1.16 | anual | 2009-01-01 | 2025-01-01 | 17 | PYG | Preliminar | Canal: seguro |
| `seg_agro_siniestros_reaseg_cedidos_ext` | Seguros: siniestros recuperados de reaseguro cedido al exterior (agropecuario) | `insurance_annex` 1.18 | anual | 2009-01-01 | 2025-01-01 | 17 | PYG | Preliminar | Transferencia del riesgo al exterior |
| `oni` | NOAA CPC: Oceanic Niño Index (media móvil 3 meses; mes central) | `NOAA CPC` oni.ascii.txt | mensual | 1950-01-01 | 2026-07-01 | 919 | GRADOS_C | Externa (NOAA), no verificada en la base | Shock climático (ENSO) |
| `nino34_sst_3m` | NOAA CPC: temperatura absoluta Niño 3.4 media móvil 3 meses | `NOAA CPC` oni.ascii.txt | mensual | 1950-01-01 | 2026-07-01 | 919 | GRADOS_C | Externa (NOAA), no verificada en la base | Índice alternativo |
| `roni` | NOAA CPC: ONI relativo | `NOAA CPC` RONI.ascii.txt | mensual | 1950-01-01 | 2026-07-01 | 919 | GRADOS_C | Externa (NOAA), no verificada en la base | Índice alternativo |
| `nino34_anom_mensual` | NOAA CPC: anomalía mensual Niño 3.4 (1982-) | `NOAA CPC` sstoi.indices | mensual | 1982-01-01 | 2026-08-01 | 536 | GRADOS_C | Externa (NOAA), no verificada en la base | Índice alternativo mensual |
| `sgc_indices_agricultura_*` | 27 series: credit_survey hoja Índices (detalle en diccionario_series.csv) | `credit_survey` Índices | trimestral | 2015-01-01 | 2026-04-01 | 1.236 | INDEX_POINTS | Preliminar (27) | Situación General del Crédito por sector (situación, expectativa, confianza) |

### Paneles por entidad

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `panel_credito_sector_entidad_mes.csv` | Cartera vigente y vencida × 13 sectores (incluye AGRICULTURA y GANADERIA) × moneda × entidad | 2016-01-01 a 2026-07-01, 66.073 filas | Panel provisional |
| `panel_credito_cultivo_entidad_mes.csv` | Cartera vigente y vencida para CULTIVO DE SOJA, TRIGO, ARROZ y ALGODÓN × moneda × entidad | 2016-01-01 a 2026-07-01, 13.021 filas | Panel provisional |
| `panel_ratios_riesgo_entidad_mes.csv` | Morosidad total/MN/ME, refinanciados, reestructurados, renovados y RRR sobre cartera, previsiones/vencidos, TIER 1 y TIER 1+2, liquidez, ROE | 2016-01-01 a 2026-07-01, 39.606 filas | Panel provisional |
| `panel_categoria_riesgo_entidad_mes.csv` | Cartera por categoría de riesgo (1, 1a, 1b, 2 a 6) | 2016-01-01 a 2026-07-01, 23.049 filas | Panel provisional |
| `panel_eeff_riesgo_entidad_mes.csv` | Colocaciones al sector no financiero, vencidos, morosos, previsiones (stock, constitución, desafectación) y capital, por moneda (millones de Gs.) | 2016-01-01 a 2026-07-01, 47.859 filas | Panel provisional |
| `entidades.csv` | `entity_id` → nombre y tipo de propiedad | 29 entidades | Referencia |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_anual.csv` | 68 | 11 | 2009-01-01 | 2025-01-01 |
| `datos/series_anual_ancho.csv` | 17 | 5 | 2009-01-01 | 2025-01-01 |
| `datos/series_mensual.csv` | 6.424 | 11 | 1950-01-01 | 2026-08-01 |
| `datos/series_mensual_ancho.csv` | 920 | 14 | 1950-01-01 | 2026-08-01 |
| `datos/series_trimestral.csv` | 1.494 | 11 | 1994-01-01 | 2026-04-01 |
| `datos/series_trimestral_ancho.csv` | 130 | 30 | 1994-01-01 | 2026-04-01 |
| `datos/diccionario_series.csv` | 46 | 13 | 1950-01-01 | 2015-07-01 |
| `datos/panel_credito_sector_entidad_mes.csv` | 66.073 | 9 | 2016-01-01 | 2026-07-01 |
| `datos/panel_credito_cultivo_entidad_mes.csv` | 13.021 | 9 | 2016-01-01 | 2026-07-01 |
| `datos/panel_ratios_riesgo_entidad_mes.csv` | 39.606 | 7 | 2016-01-01 | 2026-07-01 |
| `datos/panel_categoria_riesgo_entidad_mes.csv` | 23.049 | 7 | 2016-01-01 | 2026-07-01 |
| `datos/panel_eeff_riesgo_entidad_mes.csv` | 47.859 | 10 | 2016-01-01 | 2026-07-01 |
| `datos/entidades.csv` | 29 | 4 | — | — |

## 4. Cómo se usarían los datos

- **Mora sectorial:** `cartera_vencida / (cartera_vigente + cartera_vencida)` por banco-sector-moneda; en ME, convertir a USD antes de comparar niveles en el tiempo.
- **Forbearance:** la mora agropecuaria observada es *menor* que la del resto de la cartera (≈ 1,6–2,3% frente a ≈ 3,0–3,4% en 2019, 2021 y 2024), lo que puede reflejar reprogramaciones; analizar siempre junto con `Refinanciados/Cartera`, `Reestructurados/Cartera` y `RRR/Cartera`, y con las medidas excepcionales COVID (panel de carteras de C1/C2).
- **ENSO:** mensual (NOAA), rezagado; agregar a la campaña agrícola (setiembre–marzo para soja) como robustez.
- **Frecuencias:** paneles mensuales; seguros anuales; encuesta de crédito trimestral (asignar al último mes del trimestre).
- **Exposición congelada:** participación en t−12 o en diciembre previo al episodio.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Clima geográfico (lluvia, sequía por departamento) | Exposición física, no solo ENSO | CHIRPS / ERA5-Land; DMH |
| Ubicación geográfica de la cartera (departamento del prestatario) | Exposición banco-región | SIB – central de riesgos |
| Préstamo-prestatario con colateral, seguro y reestructuración | Nivel "ideal/óptimo" | Central de riesgos BCP (acuerdo de confidencialidad) |
| Seguro agrícola por cultivo y departamento | Canal de seguro | Superintendencia de Seguros; MAG (seguro agrícola) |
| Definición y fechas de las medidas de alivio (reprogramaciones por sequía) | Separar default de forbearance | SIB – resoluciones de medidas transitorias |
| Datos de cooperativas (fuerte presencia en el agro) | Parte del riesgo agrícola fuera de la banca | INCOOP |

## 6. Evaluación de viabilidad

**Media para el stress test descriptivo** (panel banco-sector-cultivo-moneda de 127 meses, con ratios de reprogramación y ENSO incorporado desde NOAA); **baja para inferencia causal**, por los pocos episodios ENSO desde 2016 y la falta de geografía y de datos de prestatario.

## 7. Supuestos que debes revisar

1. **Exposición climática = participación en agricultura y ganadería** (panel sectorial) y en los 4 cultivos del panel por actividad; no incluye agroindustria ni comercio de insumos.
2. El panel de cultivos cubre solo lo que publica el boletín actual (soja, trigo, arroz, algodón); maíz y otros cultivos no están desagregados.
3. Los seguros (Superintendencia de Seguros) son anuales, en guaraníes corrientes y a nivel de todo el mercado.
4. Montos del panel EEFF en millones de Gs. (verificado en C1).
5. Índices de la Encuesta de Situación General del Crédito: unidad "puntos de índice"; la metodología (difusión) debe confirmarse con el BCP.

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Shocks climáticos y bancos

| Referencia | Qué respalda en este proyecto |
|---|---|
| Damette, O., Fajeau, M. y Mathonnat, C. (2026). "Climate Shocks and Banking Sector Stability: Evidence from El Niño Southern Oscillation." *Ecological Economics*, 239. **[Revista]** | **Antecedente más directo**: en 51 países (2000–2020), El Niño deteriora la estabilidad bancaria, con efectos más fuertes en América Latina, y la **mora** es el principal canal. Respalda la mora como resultado principal. |
| De Marco, F. y Limodio, N. "The Financial Transmission of a Climate Shock: El Niño and US Banks" (ahora "Climate, Amenities and Banking: El Niño in the US"). CEPR Discussion Paper 17909. **[DT]** | Usa ENSO como shock cuasi-aleatorio y la exposición geográfica de cada banco. Mismo diseño de **exposición × shock**. |
| Noth, F. y Schüwer, U. (2023). "Natural Disasters and Bank Stability: Evidence from the U.S. Financial System." *Journal of Environmental Economics and Management*, 119, 102792. **[Revista]** | Los bancos expuestos a regiones con desastres muestran más mora y menor capital en los años siguientes. Respalda horizontes de hasta 18 meses y el resultado de provisiones. |
| Cortés, K. R. y Strahan, P. E. (2017). "Tracing Out Capital Flows: How Financially Integrated Banks Respond to Natural Disasters." *Journal of Financial Economics*, 125(1), 182–199. **[Revista]** | Tras un desastre, los bancos reasignan crédito hacia las zonas afectadas. Respalda separar mora (riesgo realizado) de **nueva oferta** (Δ cartera vigente). |

### 8.2 Identificación

- Khwaja y Mian (2008, *AER*): efectos fijos banco-tiempo para comparar sectores dentro del mismo banco (paso 3).
- Kashyap y Stein (2000, *AER*): exposición predeterminada del banco. Referencias completas en la carpeta 06.
- Proyecciones locales (Jordà, 2005) y referencias sobre ENSO en la carpeta 09.

### 8.3 Antecedentes para Paraguay

- **[PY]** González, Á. (BCP). "Nonlinear Climate Shocks and Financial Stability: Evidence from El Niño in Paraguay." Presentado en un taller regional del BCP; sin versión pública localizada. **Es prácticamente el mismo tema que este proyecto.** Antes de avanzar conviene conseguir el trabajo, para decidir si este proyecto lo complementa (por ejemplo, con el diseño banco-sector-mes y los ratios de refinanciados, reestructurados y renovados) o si hay que reorientarlo.
