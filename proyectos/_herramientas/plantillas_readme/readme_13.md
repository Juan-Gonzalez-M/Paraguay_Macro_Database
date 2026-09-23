# 13 · D5 — Clima y riesgo de crédito

*Carpeta de datos generada por `R/01_extraer_datos.R` · {{GENERADO}}*

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

{{TABLA_SERIES}}

### Paneles por entidad

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `panel_credito_sector_entidad_mes.csv` | Cartera vigente y vencida × 13 sectores (incluye AGRICULTURA y GANADERIA) × moneda × entidad | {{RANGO:panel_credito_sector_entidad_mes.csv}} | Panel provisional |
| `panel_credito_cultivo_entidad_mes.csv` | Cartera vigente y vencida para CULTIVO DE SOJA, TRIGO, ARROZ y ALGODÓN × moneda × entidad | {{RANGO:panel_credito_cultivo_entidad_mes.csv}} | Panel provisional |
| `panel_ratios_riesgo_entidad_mes.csv` | Morosidad total/MN/ME, refinanciados, reestructurados, renovados y RRR sobre cartera, previsiones/vencidos, TIER 1 y TIER 1+2, liquidez, ROE | {{RANGO:panel_ratios_riesgo_entidad_mes.csv}} | Panel provisional |
| `panel_categoria_riesgo_entidad_mes.csv` | Cartera por categoría de riesgo (1, 1a, 1b, 2 a 6) | {{RANGO:panel_categoria_riesgo_entidad_mes.csv}} | Panel provisional |
| `panel_eeff_riesgo_entidad_mes.csv` | Colocaciones al sector no financiero, vencidos, morosos, previsiones (stock, constitución, desafectación) y capital, por moneda (millones de Gs.) | {{RANGO:panel_eeff_riesgo_entidad_mes.csv}} | Panel provisional |
| `entidades.csv` | `entity_id` → nombre y tipo de propiedad | 29 entidades | Referencia |

{{TABLA_ARCHIVOS}}

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
