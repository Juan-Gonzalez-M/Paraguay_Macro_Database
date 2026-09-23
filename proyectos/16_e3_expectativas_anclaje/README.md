# 16 · E3 — Desacuerdo y anclaje de expectativas

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 18:58:09 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

## 1. Resumen y pregunta de investigación

La dispersión entre modelos, la dispersión de la EVE y el anclaje son objetos distintos; la ficha pide tratarlos como validaciones empíricas y no como sinónimos de incertidumbre o credibilidad. Con los datos disponibles, **solo la parte de anclaje en versión agregada es factible**: la EVE publicada trae un único estadístico por variable (la mediana), sin dispersión ni número de respuestas.

- **Pregunta (versión factible):** ¿cuán sensible es la expectativa de inflación de largo plazo (horizonte de política, 24 meses) a las sorpresas de inflación y de política monetaria, y a los cambios de la meta?
- **Estimandos:** (i) coeficiente de traspaso de sorpresas de inflación a la expectativa a 24 meses (≈ 0 si está anclada); (ii) cambio de la expectativa de largo plazo alrededor de los cambios de meta (event study); (iii) sesgo y eficiencia de los pronósticos EVE.
- **Fuera de alcance con estos datos:** ganancia predictiva del desacuerdo (requiere dispersión o microdatos).

## 2. Estrategia empírica propuesta

1. **Armonizar horizontes.** Los horizontes fijos (`eve_inf_anio_t`, `_t1`: diciembre del año t y t+1) se acortan cada mes; construir un horizonte constante de 12 meses ponderando t y t+1 por los meses restantes (método de Dovern et al.) y compararlo con `eve_inf_12m` (disponible desde 2017-09).
2. **Sorpresas:** inflación mensual publicada − `eve_inf_mes` relevada ese mes; TPM − `eve_tpm_mes`.
3. **Regresión de anclaje (2014–2026):** `Δ eve_inf_24m_t = α + β·sorpresa_inflación_t + γ·sorpresa_TPM_t + ε`, con β estable en el tiempo como test de anclaje; coeficientes variables (rolling o TVP) para detectar desanclaje (2022).
4. **Event study de la meta:** ventanas alrededor de 2014-12, 2017 y del posible cambio de 2025 (ver supuestos), con pre-tendencias.
5. **Eficiencia de pronósticos:** errores de `eve_inf_anio_t`, `eve_pib_anio_t` y `eve_tc_anio_t` frente a la realización de diciembre; tests de Mincer–Zarnowitz.
6. **Complemento:** comparación con expectativas de hogares (ICC/IEE, 2018–) y de bancos por sector (Situación General del Crédito, trimestral 2015–).

## 3. Series extraídas

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `eve_inf_mes` | EVE (mediana): inflación mensual esperada para el mes corriente | `eve` NA | mensual | 2006-04-01 | 2026-08-01 | 245 | PROPORTION | Preliminar | Expectativa de corto plazo |
| `eve_inf_prox_mes` | EVE (mediana): inflación mensual esperada para el próximo mes | `eve` NA | mensual | 2014-06-01 | 2026-08-01 | 147 | PROPORTION | Preliminar | Expectativa de corto plazo |
| `eve_inf_anio_t` | EVE (mediana): inflación esperada para diciembre del año t | `eve` NA | mensual | 2006-04-01 | 2026-08-01 | 245 | PROPORTION | Preliminar | Expectativa de horizonte fijo (fin de año) |
| `eve_inf_anio_t1` | EVE (mediana): inflación esperada para diciembre del año t+1 | `eve` NA | mensual | 2006-04-01 | 2026-08-01 | 245 | PROPORTION | Preliminar | Expectativa de horizonte fijo (fin de año siguiente) |
| `eve_inf_12m` | EVE (mediana): inflación esperada próximos 12 meses | `eve` NA | mensual | 2017-09-01 | 2026-08-01 | 108 | PROPORTION | Preliminar | Expectativa de horizonte móvil |
| `eve_inf_24m` | EVE (mediana): inflación esperada en el horizonte de política (24 meses) | `eve` NA | mensual | 2014-08-01 | 2026-08-01 | 145 | PROPORTION | Preliminar | Variable central de anclaje (largo plazo) |
| `eve_tpm_mes` | EVE (mediana): TPM esperada para el mes | `eve` NA | mensual | 2014-06-01 | 2026-08-01 | 147 | PROPORTION | Preliminar | Sorpresa de política |
| `eve_tpm_prox_mes` | EVE (mediana): TPM esperada para el próximo mes | `eve` NA | mensual | 2014-06-01 | 2026-08-01 | 147 | PROPORTION | Preliminar | Sorpresa de política |
| `eve_tpm_anio_t` | EVE (mediana): TPM esperada fin de año t | `eve` NA | mensual | 2014-06-01 | 2026-08-01 | 147 | PROPORTION | Preliminar | Trayectoria esperada de política |
| `eve_tpm_anio_t1` | EVE (mediana): TPM esperada fin de año t+1 | `eve` NA | mensual | 2014-06-01 | 2026-08-01 | 147 | PROPORTION | Preliminar | Trayectoria esperada de política |
| `eve_pib_anio_t` | EVE (mediana): crecimiento del PIB esperado año t | `eve` NA | mensual | 2011-11-01 | 2026-08-01 | 178 | PERCENT_CHANGE | Preliminar | Expectativa de actividad |
| `eve_pib_anio_t1` | EVE (mediana): crecimiento del PIB esperado año t+1 | `eve` NA | mensual | 2011-11-01 | 2026-08-01 | 178 | PERCENT_CHANGE | Preliminar | Expectativa de actividad |
| `eve_tc_mes` | EVE (mediana): tipo de cambio esperado para el mes | `eve` NA | mensual | 2011-11-01 | 2026-08-01 | 178 | PYG_PER_USD | Preliminar | Expectativa cambiaria |
| `eve_tc_prox_mes` | EVE (mediana): tipo de cambio esperado próximo mes | `eve` NA | mensual | 2014-06-01 | 2026-08-01 | 147 | PYG_PER_USD | Preliminar | Expectativa cambiaria |
| `eve_tc_anio_t` | EVE (mediana): tipo de cambio esperado fin de año t | `eve` NA | mensual | 2011-11-01 | 2026-08-01 | 178 | PYG_PER_USD | Preliminar | Expectativa cambiaria |
| `eve_tc_anio_t1` | EVE (mediana): tipo de cambio esperado fin de año t+1 | `eve` NA | mensual | 2011-11-01 | 2026-08-01 | 178 | PYG_PER_USD | Preliminar | Expectativa cambiaria |
| `ipc_indice` | IPC índice general (base dic-2017=100) | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Realización (para errores de pronóstico) |
| `ipc_var_mensual` | Inflación total mensual | `economic_annex` CUADRO 15 | mensual | 1993-01-01 | 2026-07-01 | 403 | PERCENT | Validada por regla | Realización / sorpresa de inflación |
| `ipc_var_interanual` | Inflación total interanual | `economic_annex` CUADRO 15 | mensual | 1993-12-01 | 2026-07-01 | 392 | PERCENT | Validada por regla | Realización / sorpresa de inflación |
| `ipc_subyacente_mensual` | Inflación subyacente mensual | `economic_annex` CUADRO 15 | mensual | 1993-01-01 | 2026-07-01 | 403 | PERCENT | Validada por regla | Sorpresa de inflación subyacente |
| `ipc_subyacente_interanual` | Inflación subyacente interanual | `economic_annex` CUADRO 15 | mensual | 1993-12-01 | 2026-07-01 | 392 | PERCENT | Validada por regla | Realización |
| `tpm` | Tasa de política monetaria (promedio del mes; etiqueta contaminada) | `economic_annex` CUADRO 19  | mensual | 2011-05-01 | 2026-07-01 | 183 | PERCENT | Preliminar | Realización / sorpresa de política |
| `pyg_usd_prom_venta` | PYG por USD promedio mensual (venta) | `exchange_rates` USD Prom | mensual | 1989-01-01 | 2026-07-01 | 451 | PYG_PER_USD | Validada por regla | Realización cambiaria |
| `tcn_venta` | Tipo de cambio referencial diario (para el valor de fin de año) | `tcn_referential_daily` 2012_Venta + 2013_Venta + 2014_Venta +… | diaria | 2012-08-06 | 2026-08-25 | 3.502 | PYG_PER_USD | Preliminar | Realización cambiaria |
| `pib_real_anual` | PIB anual a precios de comprador (millones de Gs. constantes de 2014) | `economic_annex` CUADRO 1 | anual | 1991-01-01 | 2025-01-01 | 35 | PYG (millones) | Validada por regla | Realización de crecimiento |
| `pib_var_anual` | Variación porcentual anual del PIB (Cuadro 3) | `economic_annex` CUADRO 3 | anual | 1992-01-01 | 2025-01-01 | 34 | UNRESOLVED_SOURCE_UNITS | Preliminar | Realización de crecimiento |
| `icc` | Índice de confianza del consumidor | `icc` NA | mensual | 2018-01-01 | 2026-07-01 | 103 | INDEX_POINTS | Preliminar | Expectativas de hogares |
| `iee` | Índice de expectativas económicas (hogares) | `icc` NA | mensual | 2018-01-01 | 2026-07-01 | 103 | INDEX_POINTS | Preliminar | Expectativas de hogares |
| `iee_pais` | Índice de expectativas económicas: país | `icc` NA | mensual | 2018-01-01 | 2026-07-01 | 103 | INDEX_POINTS | Preliminar | Expectativas de hogares |
| `iee_personal` | Índice de expectativas económicas: situación personal | `icc` NA | mensual | 2018-01-01 | 2026-07-01 | 103 | INDEX_POINTS | Preliminar | Expectativas de hogares |
| `sgc_general_expectativa` | Situación General del Crédito: índice de expectativa general | `credit_survey` Índices | trimestral | 2015-01-01 | 2026-04-01 | 46 | INDEX_POINTS | Preliminar | Expectativas de empresas/bancos |
| `sgc_consumo_expectativa` | Situación General del Crédito: expectativa consumo | `credit_survey` Índices | trimestral | 2015-01-01 | 2026-04-01 | 46 | INDEX_POINTS | Preliminar | Expectativas sectoriales |
| `sgc_agricultura_expectativa` | Situación General del Crédito: expectativa agricultura | `credit_survey` Índices | trimestral | 2015-01-01 | 2026-04-01 | 46 | INDEX_POINTS | Preliminar | Expectativas sectoriales |
| `sgc_industria_expectativa` | Situación General del Crédito: expectativa industria | `credit_survey` Índices | trimestral | 2015-01-01 | 2026-04-01 | 46 | INDEX_POINTS | Preliminar | Expectativas sectoriales |
| `sgc_comercio_expectativa` | Situación General del Crédito: expectativa comercio | `credit_survey` Índices | trimestral | 2015-01-01 | 2026-04-01 | 46 | INDEX_POINTS | Preliminar | Expectativas sectoriales |

### Otros archivos

| Archivo | Contenido | Rango | Nivel |
|---|---|---|---|
| `meta_inflacion_manual.csv` | Meta de inflación y rango de tolerancia por fecha de vigencia. **No está en la base**: registro manual con fechas aproximadas; la fila de 2025 está inferida de la EVE | 2011-05-01 a 2025-01-01, 4 filas | Manual, no verificado |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_anual.csv` | 69 | 11 | 1991-01-01 | 2025-01-01 |
| `datos/series_anual_ancho.csv` | 35 | 3 | 1991-01-01 | 2025-01-01 |
| `datos/series_diaria.csv` | 3.502 | 11 | 2012-08-06 | 2026-08-25 |
| `datos/series_diaria_ancho.csv` | 3.502 | 2 | 2012-08-06 | 2026-08-25 |
| `datos/series_mensual.csv` | 5.776 | 11 | 1989-01-01 | 2026-08-01 |
| `datos/series_mensual_ancho.csv` | 452 | 28 | 1989-01-01 | 2026-08-01 |
| `datos/series_trimestral.csv` | 230 | 11 | 2015-01-01 | 2026-04-01 |
| `datos/series_trimestral_ancho.csv` | 46 | 6 | 2015-01-01 | 2026-04-01 |
| `datos/diccionario_series.csv` | 35 | 13 | 1989-01-01 | 2018-01-01 |
| `datos/meta_inflacion_manual.csv` | 4 | 5 | 2011-05-01 | 2025-01-01 |

## 4. Cómo se usarían los datos

- Las expectativas de inflación y TPM de la EVE vienen como **proporciones** (0,035 = 3,5%); multiplicar por 100 antes de compararlas con el IPC o la TPM, que están en %.
- Inflación realizada de fin de año: `ipc_var_interanual` de diciembre; tipo de cambio realizado de fin de año: último `tcn_venta` de diciembre (o promedio de diciembre de `pyg_usd_prom_venta`, según el criterio que usa la encuesta; verificar).
- Crecimiento realizado: `pib_var_anual` (Cuadro 3) o variación de `pib_real_anual`. Son datos **finales**; los errores de pronóstico contra datos finales mezclan revisiones (proyecto de vintages excluido por tu instrucción).
- Sin logaritmos ni desestacionalización en expectativas; la inflación mensual (`ipc_var_mensual`) sí es estacional: para sorpresas conviene usar la diferencia con la expectativa del mismo mes, que ya incorpora la estacionalidad.
- Trimestral (encuesta de crédito) → mensual: asignar al último mes del trimestre, sin interpolar.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Dispersión, media, moda, n de respuestas de la EVE | Núcleo del módulo de desacuerdo | BCP – Estudios Económicos (planilla interna de la EVE) |
| Microdatos anónimos de respondentes (panel con ID estable) | Nivel "ideal": entradas/salidas y aprendizaje individual | BCP – EVE, bajo acuerdo de confidencialidad |
| Fecha de levantamiento y publicación de cada EVE | Para ordenar sorpresas antes/después del COPOM | BCP – calendario de la EVE |
| Historia oficial de la meta de inflación y su rango | Event study de la meta | BCP – resoluciones del Directorio / Informes de Política Monetaria |
| Calendario de reuniones del COPOM | Sorpresas de política bien fechadas | BCP – comunicados del COPOM |
| Pronósticos de modelos del BCP | "Dispersión de modelos" | BCP – archivo interno de pronósticos (ligado a E1/E2, fuera de alcance) |

## 6. Evaluación de viabilidad

**Media.** El anclaje agregado es factible: hay expectativas de inflación a 24 meses desde 2014 y de fin de año desde 2006, con realizaciones y TPM; el desacuerdo no lo es porque la EVE publicada solo trae la mediana.

## 7. Supuestos que debes revisar

1. **EVE = mediana** (confirmado por ti).
2. **Meta de inflación (registro manual):** 5% ± 2,5 desde 2011-05; 4,5% ± 2 desde 2014-12; 4% ± 2 desde 2017. Las fechas son aproximadas y deben verificarse con las resoluciones.
3. **Posible cambio de meta en 2025:** la mediana a 24 meses pasa de 4,0% a 3,5% exactamente en 2025-01 y se mantiene; lo registré como meta de 3,5% **no verificada** y sin rango. Si no hubo cambio de meta, hay que eliminar esa fila: el salto sería entonces un desanclaje hacia abajo, un resultado de interés en sí mismo.
4. La TPM usada es el promedio mensual del Cuadro 19; la sorpresa con la EVE supone que la encuesta se releva antes de la decisión del mes.
5. `pib_var_anual` (Cuadro 3) figura con unidad no resuelta en la base; los valores son variaciones en % (p. ej. 6,6 en 2025).

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Pruebas de anclaje con expectativas de encuestas

| Referencia | Qué respalda en este proyecto |
|---|---|
| Levin, A. T., Natalucci, F. M. y Piger, J. M. (2004). "The Macroeconomic Effects of Inflation Targeting." *Federal Reserve Bank of St. Louis Review*, 86(4), 51–80. **[Revista]** | Prueba original de anclaje con encuestas: regresión del **cambio en la expectativa de largo plazo sobre la inflación observada**. Coeficiente ≈ 0 si las expectativas están ancladas. Es exactamente la regresión del paso 3. |
| Gürkaynak, R. S., Levin, A. T. y Swanson, E. T. (2010). "Does Inflation Targeting Anchor Long-Run Inflation Expectations? Evidence from the U.S., UK, and Sweden." *Journal of the European Economic Association*, 8(6), 1208–1242. **[Revista]** | Sensibilidad de las expectativas de largo plazo a sorpresas macroeconómicas y de política. Respalda usar **sorpresas** (dato − mediana EVE) en lugar de niveles. |
| De Pooter, M., Robitaille, P., Walker, I. y Zdinak, M. (2014). "Are Long-Term Inflation Expectations Well Anchored in Brazil, Chile, and Mexico?" *International Journal of Central Banking*, 10(2), 337–400. **[Revista]** | **Antecedente regional directo**: pruebas de anclaje con encuestas mensuales en países con metas de inflación de América Latina. Sirve de modelo para la especificación y como punto de comparación de resultados. |
| Bems, R., Caselli, F., Grigoli, F. y Gruss, B. (2021). "Expectations' Anchoring and Inflation Persistence." *Journal of International Economics*, 132, 103516. **[Revista]** | Índice de anclaje para 45 economías basado en encuestas: desvío respecto de la meta, variabilidad y sensibilidad a sorpresas. Respalda construir un índice comparable para Paraguay con la meta del cuadro manual. |
| Carvalho, C., Eusepi, S., Moench, E. y Preston, B. (2023). "Anchored Inflation Expectations." *American Economic Journal: Macroeconomics*, 15(1), 1–47. **[Revista]** | Anclaje que varía en el tiempo, con sensibilidad a la inflación observada. Respalda los coeficientes variables (rolling o TVP) para detectar desanclaje en 2022. |

### 8.2 Construcción de variables y eficiencia de pronósticos

| Referencia | Uso |
|---|---|
| Dovern, J., Fritsche, U. y Slacalek, J. (2012). "Disagreement Among Forecasters in G7 Countries." *Review of Economics and Statistics*, 94(4), 1081–1096. **[Revista]** | Conversión de pronósticos de **horizonte fijo en el calendario** (diciembre de t y t+1) a horizonte constante de 12 meses con ponderación por meses restantes (paso 1). |
| Mincer, J. y Zarnowitz, V. (1969). "The Evaluation of Economic Forecasts." En Mincer, J. (ed.), *Economic Forecasts and Expectations*. NBER. **[Libro]** | Prueba de insesgamiento y eficiencia (paso 5). |
| Coibion, O. y Gorodnichenko, Y. (2015). "Information Rigidity and the Expectations Formation Process: A Simple Framework and New Facts." *American Economic Review*, 105(8), 2644–2678. **[Revista]** | Regresión del error de pronóstico sobre la revisión del pronóstico. Funciona con **la mediana** (no requiere microdatos), así que es aplicable a la EVE publicada. |
| Capistrán, C. y Ramos-Francia, M. (2010). "Does Inflation Targeting Affect the Dispersion of Inflation Expectations?" *Journal of Money, Credit and Banking*, 42(1), 113–134. **[Revista]** | Referencia para la parte de **desacuerdo**, que queda fuera de alcance mientras la EVE publicada no traiga dispersión. |

### 8.3 Antecedentes para Paraguay

- **[PY]** Alonso, P. (2018). "Creation and Evolution of Inflation Expectations in Paraguay." Banco Interamericano de Desarrollo, doi:10.18235/0001241. **[DT]**
- **[PY]** Alonso Méndez, P. A. (2020). "Formation and Evolution of Inflation Expectations in Paraguay." En *Inflation Expectations, Their Measurement and the Estimate of Their Degree of Anchoring*, Joint Research Program 2017, CEMLA. **[DT]** Con la EVE, estima determinantes de la expectativa a 12 meses por MCO, FMOLS y GMM, y construye un índice de credibilidad. Encuentra que dominan la expectativa del mes anterior y la inflación reciente, y que el tipo de cambio no es significativo.

**Aporte frente a estos antecedentes:** Alonso estudia la *formación* de la expectativa a 12 meses. Este proyecto prueba el **anclaje en el horizonte de política (24 meses)** con sorpresas, coeficientes variables en el tiempo (2022) y un event study de los cambios de meta, siguiendo a Levin et al. (2004), Gürkaynak et al. (2010) y De Pooter et al. (2014).
