# 12 · D4 — Inflación climática, precios relativos y riesgo de cola

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 20:02:12 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

## 1. Resumen y pregunta de investigación

Un efecto medio de ENSO sobre la inflación no dice en qué parte de la canasta cae ni cuánto eleva el riesgo de inflación alta. La ficha propone dos módulos complementarios, sin confundir la predicción de colas con la causalidad de segunda vuelta:

- **Módulo 1 — propagación:** ¿qué componentes del IPC (alimentos frescos, carne, procesados, transables, núcleo) cargan el efecto ENSO y con qué rezago?
- **Módulo 2 — distribución:** ¿mejora la información ENSO el pronóstico de cuantiles y de la probabilidad de superar un umbral (p. ej. inflación interanual > meta + 2 pp) a 1–12 meses?
- **Evidencia:** forma reducida para componentes; predictiva para densidades. No inferir política óptima de la reacción histórica.

## 2. Estrategia empírica propuesta

1. **Perfiles por componente (1995–2026):** proyecciones locales con la misma especificación y nudos que D1 (carpeta 09) para cada componente; tests conjuntos entre componentes y control de multiplicidad. **No** controlar por alimentos al estimar el efecto sobre el núcleo (post-tratamiento).
2. **Descomposición por tipo de bien:** tradables/no tradables (Cuadro 14 a), flexibles/administrados (Cuadro 14 c), bienes/servicios (Cuadro 14 b), y precios al productor (Cuadro 17) como etapa previa.
3. **Regresión cuantílica y pronóstico de densidad:** cuantiles 10/50/90 de la inflación interanual a h = 1–12 con y sin ENSO, precios mundiales de alimentos y tipo de cambio; evaluación recursiva fuera de muestra con CRPS y WIS; benchmark EVE (mediana) y random walk.
4. **Probabilidad de cola:** logit/probit de `π_{t+h} > umbral`; scores de Brier y curvas de confiabilidad.

## 3. Series extraídas

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `ipc_indice` | IPC índice general (base dic-2017=100) | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Resultado: headline (nivel) |
| `ipc_alimentos_div` | IPC alimentación y bebidas no alcohólicas (Cuadro 14) | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Componente que carga el efecto |
| `ipc_bienes_alimenticios` | IPC bienes alimenticios (índice) | `economic_annex` CUADRO 14 b | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Componente: alimentos |
| `ipc_alimenticios_sin_fyv` | IPC bienes alimenticios sin frutas y verduras | `economic_annex` CUADRO 14 b | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Componente: alimentos procesados |
| `ipc_sin_alimentos` | IPC sin alimentos | `economic_annex` CUADRO 14 b | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Componente |
| `ipcsae` | IPCSAE (sin alimentos ni energía) | `economic_annex` CUADRO 14 b | mensual | 2007-12-01 | 2026-07-01 | 224 | INDEX | Preliminar | Núcleo alternativo (no controlar por alimentos) |
| `ipc_sin_alim_comb_tarif` | IPC sin alimentos combustibles ni tarifados | `economic_annex` CUADRO 14 b | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Núcleo alternativo |
| `ipc_servicios` | IPC servicios | `economic_annex` CUADRO 14 b | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Componente sticky |
| `ipc_total_bienes` | IPC total de bienes | `economic_annex` CUADRO 14 b | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Componente flexible |
| `ipc_transables_sin_fyv` | IPC transables sin frutas y verduras | `economic_annex` CUADRO 14 a | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Tradables (canal FX) |
| `ipc_no_transables` | IPC no transables | `economic_annex` CUADRO 14 a | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | No tradables |
| `ipc_importados_sin_fyv` | IPC productos importados sin frutas y verduras | `economic_annex` CUADRO 14 a | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Canal FX |
| `ipc_nacionales` | IPC productos nacionales | `economic_annex` CUADRO 14 a | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Canal doméstico |
| `ipc_bienes_libres` | IPC bienes libres | `economic_annex` CUADRO 14 c | mensual | 2003-01-01 | 2026-07-01 | 283 | INDEX | Preliminar | Flexibles |
| `ipc_administrados` | IPC bienes y servicios administrados | `economic_annex` CUADRO 14 c | mensual | 2003-01-01 | 2026-07-01 | 283 | INDEX | Preliminar | Precios regulados (excluir en robustez) |
| `eve_inf_mes` | EVE (mediana): inflación esperada del mes | `eve` NA | mensual | 2006-04-01 | 2026-08-01 | 245 | PROPORTION | Preliminar | Expectativas (densidad aproximada / sorpresa) |
| `eve_inf_anio_t` | EVE (mediana): inflación esperada año t | `eve` NA | mensual | 2006-04-01 | 2026-08-01 | 245 | PROPORTION | Preliminar | Expectativas |
| `eve_inf_12m` | EVE (mediana): inflación esperada 12 meses | `eve` NA | mensual | 2017-09-01 | 2026-08-01 | 108 | PROPORTION | Preliminar | Benchmark para pronóstico de densidad |
| `eve_inf_24m` | EVE (mediana): inflación esperada 24 meses | `eve` NA | mensual | 2014-08-01 | 2026-08-01 | 145 | PROPORTION | Preliminar | Anclaje |
| `tpm` | Tasa de política monetaria | `economic_annex` CUADRO 19  | mensual | 2011-05-01 | 2026-07-01 | 183 | PERCENT | Preliminar | Control (reacción; no inferir política óptima) |
| `pyg_usd_prom_venta` | PYG por USD promedio mensual | `exchange_rates` USD Prom | mensual | 1989-01-01 | 2026-07-01 | 451 | PYG_PER_USD | Validada por regla | Canal FX |
| `soja_chicago` | Soja Chicago USD/t | `economic_annex` Cuadro 49 | mensual | 1994-01-01 | 2026-08-01 | 392 | USD_PER_TONNE | Preliminar | Precio mundial agrícola |
| `maiz_chicago` | Maíz Chicago USD/t | `economic_annex` Cuadro 49 | mensual | 1994-01-01 | 2026-07-01 | 391 | USD_PER_TONNE | Preliminar | Precio mundial agrícola |
| `trigo_chicago` | Trigo Chicago USD/t | `economic_annex` Cuadro 49 | mensual | 1994-01-01 | 2026-07-01 | 391 | USD_PER_TONNE | Preliminar | Precio mundial agrícola (pan) |
| `carne_chicago` | Carne Chicago USD/t | `economic_annex` Cuadro 49 | mensual | 1994-01-01 | 2026-08-01 | 392 | USD_PER_TONNE | Preliminar | Precio mundial (carne) |
| `petroleo_brent` | Petróleo Brent USD/barril | `economic_annex` Cuadro 49 | mensual | 1994-01-01 | 2026-07-01 | 391 | USD_PER_BARREL | Preliminar | Costos energéticos |
| `oni` | NOAA CPC: Oceanic Niño Index (media móvil 3 meses; mes central) | `NOAA CPC` oni.ascii.txt | mensual | 1950-01-01 | 2026-07-01 | 919 | GRADOS_C | Externa (NOAA), no verificada en la base | Tratamiento: ENSO |
| `nino34_sst_3m` | NOAA CPC: temperatura absoluta Niño 3.4 media móvil 3 meses | `NOAA CPC` oni.ascii.txt | mensual | 1950-01-01 | 2026-07-01 | 919 | GRADOS_C | Externa (NOAA), no verificada en la base | Índice alternativo |
| `roni` | NOAA CPC: ONI relativo | `NOAA CPC` RONI.ascii.txt | mensual | 1950-01-01 | 2026-07-01 | 919 | GRADOS_C | Externa (NOAA), no verificada en la base | Índice alternativo |
| `nino34_anom_mensual` | NOAA CPC: anomalía mensual Niño 3.4 (1982-) | `NOAA CPC` sstoi.indices | mensual | 1982-01-01 | 2026-08-01 | 536 | GRADOS_C | Externa (NOAA), no verificada en la base | Índice alternativo mensual |
| `alimentos_indice_mundial` | FRED/FMI: índice mundial de precios de alimentos | `FRED` PFOODINDEXM | mensual | 1992-01-01 | 2026-07-01 | 415 | INDEX | Externa (FRED), no verificada en la base | Global food (nivel suficiente) |
| `commodities_indice` | FRED/FMI: índice de todas las commodities | `FRED` PALLFNFINDEXM | mensual | 1992-01-01 | 2026-07-01 | 415 | INDEX | Externa (FRED), no verificada en la base | Control global |
| `ipc15_cuadro_15_combustibles_variaciones_pct_acumulada_*` | 24 series: economic_annex hoja CUADRO 15 (detalle en diccionario_series.csv) | `economic_annex` CUADRO 15 | mensual | 1992-12-01 | 2026-07-01 | 9.546 | PERCENT/INDEX | Preliminar (20); Validada por regla (4) | IPC: total, subyacente, frutas y verduras, combustibles, tarifados (índices y variaciones) |
| `ipc_grupo_cuadro_16_*` | 11 series: economic_annex hoja CUADRO 16 (detalle en diccionario_series.csv) | `economic_annex` CUADRO 16 | mensual | 1994-12-01 | 2026-07-01 | 4.180 | INDEX | Preliminar (11) | IPC por grupo de gasto (alimentos, vivienda, vestido) |
| `ipp_cuadro_17_*` | 22 series: economic_annex hoja CUADRO 17 (detalle en diccionario_series.csv) | `economic_annex` CUADRO 17  | mensual | 1995-12-01 | 2026-06-01 | 5.911 | INDEX | Preliminar (22) | Índice de precios del productor (base mar-2025) |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_mensual.csv` | 32.434 | 11 | 1950-01-01 | 2026-08-01 |
| `datos/series_mensual_ancho.csv` | 920 | 90 | 1950-01-01 | 2026-08-01 |
| `datos/diccionario_series.csv` | 89 | 13 | 1950-01-01 | 2025-03-01 |

## 4. Cómo se usarían los datos

- **Variaciones:** `Δlog` mensual e interanual de los índices; para las series oficiales de variación (Cuadro 15, validadas) usar directamente las publicadas.
- **Estacionalidad:** frutas y verduras y alimentos tienen estacionalidad fuerte; usar variaciones interanuales o desestacionalizar (X-13) cada componente por separado **antes** de agregar, y no desestacionalizar la serie de ENSO.
- **Precios mundiales:** en USD; convertir a PYG con `pyg_usd_prom_venta` para medir el traspaso en moneda local o incluir el tipo de cambio por separado.
- **Expectativas EVE:** proporciones (0,04 = 4%); multiplicar por 100.
- **ENSO:** rezagar un mes el ONI (media móvil centrada).
- **Muestra:** el IPP (Cuadro 17) cambió de base en marzo de 2025 y varios componentes empiezan ese mes; usar solo los que cubren 1995–2026.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Clima (lluvia, temperatura) nacional/regional | Canal físico; nivel "mínimo" pide "clima" además de ONI | DMH-DINAC; CHIRPS; ERA5-Land |
| Jerarquía estable del IPC con ponderaciones (base 2017) | Agregación consistente y contribuciones | BCP – metodología del IPC |
| Precios mayoristas (Mercado de Abasto de Asunción) | Etapa intermedia alimentos | DAMA / MAG – precios del Abasto |
| Microprecios por ítem y comercio | Nivel "óptimo" | BCP – relevamiento del IPC |
| Distribución de expectativas (EVE: dispersión, cuantiles) | Densidades de expectativas | BCP – EVE interna |
| Vintages del IPC y de la EVE | Evaluación en tiempo real | Excluido por tu instrucción |

## 6. Evaluación de viabilidad

**Media-alta.** Con el ONI incorporado desde NOAA, el mínimo de la ficha —IPC total, alimentos y núcleo, ONI, clima y tasa— queda completo salvo el clima físico, y el nivel "suficiente" (alimentos mundiales, tipo de cambio, EVE, componentes) también está. El riesgo principal es la cantidad de componentes frente a pocos episodios ENSO.

## 7. Supuestos que debes revisar

1. **Etiquetas del Cuadro 15:** las series de índice figuran como "Índice — Interanual" (p. ej. `ipc15_cuadro_15_combustibles_indice_interanual`); por su unidad (INDEX) las trato como **niveles de índice**, no como variaciones. Verificar contra el Excel.
2. **Cuadro 17 (IPP):** la serie `ipp_cuadro_17_indice_general_indice_de_productos_importados` tiene una etiqueta combinada ambigua; puede ser el índice general. El IPP cambió de base en marzo de 2025.
3. Uso las mismas definiciones de ENSO que D1 (ONI, RONI y Niño 3.4 de NOAA).
4. EVE = mediana; no hay cuantiles de expectativas.
5. El IPCSAE empieza en 2007-12; el resto de los núcleos, en 1995.

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Módulo 2: inflación en riesgo (cuantiles y colas)

| Referencia | Qué respalda en este proyecto |
|---|---|
| Adrian, T., Boyarchenko, N. y Giannone, D. (2019). "Vulnerable Growth." *American Economic Review*, 109(4), 1263–1289. **[Revista]** | Método de referencia: **regresión cuantílica** de resultados futuros sobre variables de estado y ajuste de una distribución completa. Es la base del paso 3. |
| López-Salido, D. y Loria, F. (2024). "Inflation at Risk." *Journal of Monetary Economics*, 145. **[Revista]** | Aplica el enfoque de Adrian et al. a la **inflación** en un panel de la OCDE: las colas varían mucho aunque la media sea estable. Respalda que ENSO pueda mover las colas sin mover la mediana. |
| Koenker, R. y Bassett, G. (1978). "Regression Quantiles." *Econometrica*, 46(1), 33–50. **[Revista]** | Estimador cuantílico. |
| Gneiting, T. y Raftery, A. E. (2007). "Strictly Proper Scoring Rules, Prediction, and Estimation." *Journal of the American Statistical Association*, 102(477), 359–378. **[Revista]** | CRPS y reglas de puntuación propias para evaluar pronósticos de densidad. |
| Bracher, J., Ray, E. L., Gneiting, T. y Reich, N. G. (2021). "Evaluating Epidemic Forecasts in an Interval Format." *PLOS Computational Biology*, 17(2), e1008618. **[Revista]** | Definición del **WIS** (weighted interval score) para evaluar cuantiles 10/50/90. |

### 8.2 Módulo 1: clima y componentes del IPC

| Referencia | Qué respalda |
|---|---|
| Kotz, M., Kuik, F., Lis, E. y Nickel, C. (2024). "Global Warming and Heat Extremes to Enhance Inflationary Pressures." *Communications Earth & Environment*, 5, 116. **[Revista]** | Con IPC mensuales de muchos países, la temperatura eleva la inflación de **alimentos** y la general durante unos 12 meses, con efectos que dependen de la estación y la región. Respalda los perfiles por componente con horizonte de 12 meses. |
| Brunner, A. D. (2002). *Review of Economics and Statistics*, 84(1), 176–183. **[Revista]** | ENSO → precios mundiales de commodities (ver carpeta 09). |
| Cashin, P., Mohaddes, K. y Raissi, M. (2017). *Journal of International Economics*, 106, 37–54. **[Revista]** | ENSO → inflación por país (ver carpeta 09). |
| Peersman, G. (2022). "International Food Commodity Prices and Missing (Dis)Inflation in the Euro Area." *Review of Economics and Statistics*, 104(1), 85–100. **[Revista]** | Traspaso de los precios mundiales de alimentos a la inflación, incluida la **segunda vuelta** hacia el núcleo. Respalda no controlar por alimentos al estimar el efecto sobre el núcleo. |

### 8.3 Antecedentes para Paraguay

- **[PY]** Monfort, B. y Peña, S. (2008). "Inflation Determinants in Paraguay: Cost Push versus Demand Pull Factors." IMF Working Paper 08/270. **[DT]** Encuentra que los precios de algunos alimentos y los precios de Brasil pesan en la dinámica de corto plazo de la inflación paraguaya. Respalda el foco en alimentos y carne como canal del clima.
- **[PY]** Ver también el trabajo de Á. González (BCP) citado en la carpeta 09.
