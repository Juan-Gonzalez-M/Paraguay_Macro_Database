# 22 · N1 (proyecto nuevo) — Política fiscal: ciclicidad, estabilizadores y multiplicadores

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 20:13:17 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

> **Proyecto no incluido en el portafolio original.** Lo propongo porque la base contiene el estado de operaciones **mensual** de la Administración Central (MEFP 2001, 2003–2026) —una fuente que ningún proyecto del portafolio usa— y porque las regalías y compensaciones de Itaipú y Yacyretá ofrecen una fuente de ingreso fiscal en gran medida externa al ciclo doméstico, algo poco común para identificar efectos fiscales en una economía pequeña.

## 1. Resumen y pregunta de investigación

El portafolio estudia la transmisión monetaria, cambiaria, climática y financiera, pero no la política fiscal, que en Paraguay opera bajo la Ley de Responsabilidad Fiscal (techo de déficit) con suspensiones y convergencias explícitas (2020–2024). Entender la ciclicidad del gasto y su efecto sobre la actividad es relevante para la coordinación fiscal-monetaria del BCP.

- **Preguntas:** (i) ¿es el gasto de la Administración Central procíclico, acíclico o contracíclico, y cambia bajo la regla fiscal? (ii) ¿cuál es el multiplicador del gasto corriente y de capital sobre la actividad a 1–24 meses? (iii) ¿cómo responden gasto y actividad a shocks de ingresos de las binacionales?
- **Estimandos:** elasticidad del gasto real al ciclo; multiplicador acumulado `ΣΔY / ΣΔG` por tipo de gasto; respuesta a innovaciones de regalías/compensaciones.
- **Evidencia:** forma reducida con identificación tipo Blanchard-Perotti (rezagos de decisión del gasto a frecuencia mensual) y, para la parte de binacionales, variación plausiblemente exógena al ciclo doméstico.

## 2. Estrategia empírica propuesta

1. **Hechos estilizados (2003–2026):** ingresos, gasto obligado, gasto de capital (adquisición neta de activos no financieros) y balances en términos reales y en % del PIB; elasticidad de la recaudación (IVA, renta) al IMAEP.
2. **Ciclicidad:** regresiones del crecimiento del gasto real sobre la brecha del producto (IMAEP sin agricultura ni binacionales), con interacción de los períodos de regla fiscal vigente vs. suspendida.
3. **Multiplicadores (proyecciones locales mensuales):** shock de gasto = innovación del gasto real no explicada por rezagos de actividad, recaudación e IPC (supuesto de Blanchard-Perotti: el gasto no responde a la actividad dentro del mes); respuestas del IMAEP, consumo privado e inversión (trimestral) a h = 0–24; separar gasto corriente y de capital. Multiplicador acumulado según Ramey-Zubairy.
4. **Binacionales como variación externa:** las regalías y compensaciones (`mef_serie_regalias_y_compensacion_itaipu_y_yacyreta`) y el ingreso de divisas de las binacionales dependen de tarifas y acuerdos binacionales (p. ej. la negociación del Anexo C de Itaipú en 2023) más que del ciclo doméstico; usarlas como instrumento del gasto o como shock de ingreso fiscal, con pruebas de exclusión (no correlación con choques de demanda previos).
5. **Robustez:** excluir 2020–2021 (pandemia) y los años de sequía; deflactar por IPC vs. deflactor del PIB; controlar por TPM y términos de intercambio.

## 3. Series extraídas

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `imaep_original` | IMAEP serie original (1994-) | `economic_annex` CUADRO 9 | mensual | 1994-01-01 | 2026-06-01 | 390 | INDEX | Preliminar | Resultado: actividad mensual |
| `imaep_sin_agro_bin_original` | IMAEP sin agricultura ni binacionales (1994-) | `economic_annex` CUADRO 9 | mensual | 1994-01-01 | 2026-06-01 | 390 | INDEX | Preliminar | Resultado: actividad no agrícola (menos ruido climático) |
| `imaep9a_desest` | IMAEP serie ajustada (2014-) | `economic_annex` CUADRO 9 a | mensual | 2014-01-01 | 2026-06-01 | 150 | INDEX | Validada por regla | Resultado (robustez) |
| `pib_real` | PIB trimestral real (millones de Gs. de 2014) | `economic_annex` CUADRO 6 | trimestral | 1994-01-01 | 2026-01-01 | 129 | PYG (millones) | Validada por regla | Resultado trimestral / normalización |
| `pib_nominal` | PIB trimestral a precios corrientes (millones de Gs.) | `economic_annex` CUADRO 6a | trimestral | 1994-01-01 | 2026-01-01 | 129 | PYG (millones) | Validada por regla | Normalización (% del PIB) |
| `consumo_publico_real` | PIB por gasto (millones de Gs. de 2014): consumo público | `economic_annex` CUADRO 7 | trimestral | 1994-01-01 | 2026-01-01 | 129 | PYG (millones) | Preliminar | Gasto público en cuentas nacionales |
| `consumo_privado_real` | PIB por gasto (millones de Gs. de 2014): consumo privado | `economic_annex` CUADRO 7 | trimestral | 1994-01-01 | 2026-01-01 | 129 | PYG (millones) | Preliminar | Resultado: respuesta del consumo |
| `fbkf_real` | PIB por gasto (millones de Gs. de 2014): formación bruta de capital fijo | `economic_annex` CUADRO 7 | trimestral | 1994-01-01 | 2026-01-01 | 129 | PYG (millones) | Validada por regla | Resultado: respuesta de la inversión |
| `ipc_indice` | IPC índice general | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Deflactor |
| `tpm` | Tasa de política monetaria | `economic_annex` CUADRO 19  | mensual | 2011-05-01 | 2026-07-01 | 183 | PERCENT | Preliminar | Control: interacción fiscal-monetaria |
| `pyg_usd_prom_venta` | PYG por USD promedio mensual | `exchange_rates` USD Prom | mensual | 1989-01-01 | 2026-07-01 | 451 | PYG_PER_USD | Validada por regla | Conversión de ingresos binacionales y deuda externa |
| `binacionales_divisas_total` | Ingreso de divisas de entidades binacionales: total (miles USD) | `economic_annex` CUADRO 55 | mensual | 1994-01-01 | 2026-06-01 | 390 | USD (miles) | Preliminar | Fuente de ingreso externa al ciclo |
| `binacionales_divisas_itaipu` | Ingreso de divisas: Itaipú (miles USD) | `economic_annex` CUADRO 55 | mensual | 1994-01-01 | 2026-06-01 | 390 | USD (miles) | Preliminar | Fuente de ingreso externa al ciclo |
| `binacionales_divisas_yacyreta` | Ingreso de divisas: Yacyretá (miles USD) | `economic_annex` CUADRO 55 | mensual | 1994-01-01 | 2026-06-01 | 328 | USD (miles) | Preliminar | Fuente de ingreso externa al ciclo |
| `deuda_ext_saldo` | Deuda pública externa: saldo (miles USD) | `economic_annex` CUADRO 59 | mensual | 1994-01-01 | 2026-05-01 | 389 | USD (miles) | Preliminar | Sostenibilidad / financiamiento |
| `deuda_ext_desembolsos` | Deuda pública externa: desembolsos | `economic_annex` CUADRO 59 | mensual | 1994-01-01 | 2026-05-01 | 389 | USD (miles) | Preliminar | Financiamiento |
| `deuda_ext_servicio` | Deuda pública externa: pagos de capital e intereses | `economic_annex` CUADRO 59 | mensual | 1994-01-01 | 2026-05-01 | 389 | USD (miles) | Preliminar | Servicio de deuda |
| `dep_adm_central_bcp` | Depósitos de la Administración Central en el BCP | `economic_annex` CUADRO 35 | mensual | 1994-01-01 | 2026-05-01 | 389 | PYG (millones) | Preliminar | Colchón de caja del Tesoro |
| `eve_pib_anio_t` | EVE (mediana): crecimiento esperado del PIB año t | `eve` NA | mensual | 2011-11-01 | 2026-08-01 | 178 | PERCENT_CHANGE | Preliminar | Componente esperado del ciclo |
| `soja_chicago` | Soja Chicago USD/t | `economic_annex` Cuadro 49 | mensual | 1994-01-01 | 2026-08-01 | 392 | USD_PER_TONNE | Preliminar | Control: términos de intercambio |
| `ejec_ppto_cuadro_36_*` | 19 series: economic_annex hoja CUADRO 36 (detalle en diccionario_series.csv) | `economic_annex` CUADRO 36 | mensual | 2015-01-01 | 2026-06-01 | 2.622 | PYG (miles de millones) | Preliminar (19) | Ejecución presupuestaria de la Administración Central (Anexo BCP; etiquetas contaminadas) |
| `mef_serie_activos_*` | 82 series: mef_central_government hoja Serie (detalle en diccionario_series.csv) | `mef_central_government` Serie | mensual | 2003-01-01 | 2026-08-01 | 23.108 | PYG (miles de millones) | No comprobada (28); Preliminar (54) | Estado de operaciones de la Administración Central (MEFP 2001) |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_mensual.csv` | 30.908 | 11 | 1989-01-01 | 2026-08-01 |
| `datos/series_mensual_ancho.csv` | 452 | 117 | 1989-01-01 | 2026-08-01 |
| `datos/series_trimestral.csv` | 645 | 11 | 1994-01-01 | 2026-01-01 |
| `datos/series_trimestral_ancho.csv` | 129 | 6 | 1994-01-01 | 2026-01-01 |
| `datos/diccionario_series.csv` | 121 | 13 | 1989-01-01 | 2018-01-01 |

## 4. Cómo se usarían los datos

- **Unidades:** el MEF publica en **miles de millones de Gs.** (`escala = billions`); el Cuadro 36 del Anexo, en miles de millones de Gs.; binacionales y deuda externa, en miles de USD; PIB, en millones de Gs.
- **Transformaciones:** deflactar por el IPC (mensual) a guaraníes constantes; `log` de ingresos y gastos reales; % del PIB con el PIB nominal trimestral (sumar 3 meses de flujos fiscales). Balances en niveles (pueden ser negativos: no usar logaritmos).
- **Estacionalidad:** muy fuerte (aguinaldo en diciembre, calendario tributario, ejecución de capital concentrada a fin de año): desestacionalizar con X-13 o trabajar con variaciones interanuales y dummies de mes; **nunca** comparar meses consecutivos sin ajustar.
- **Signos:** `Préstamo neto / endeudamiento neto` negativo = déficit (convención MEFP 2001); los rubros de financiamiento tienen signos del publicador.
- **Binacionales:** convertir las divisas (USD) a PYG con el tipo de cambio del mes para compararlas con las regalías del MEF.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Presupuesto aprobado y reprogramaciones (plan vs. ejecución) | Separar gasto anticipado de sorpresas fiscales | MEF – Presupuesto General de la Nación (PGN) y SIAF |
| Cronología de la Ley de Responsabilidad Fiscal (suspensiones, techos, sendas de convergencia) | Régimen de la regla | MEF / Congreso (leyes y decretos) |
| Gasto del Sector Público no financiero consolidado (IPS, entes, municipios) | La Administración Central no es todo el gasto público | MEF – estadísticas del SPNF; FMI GFS |
| Tarifas y acuerdos de Itaipú y Yacyretá fechados | Validar la exogeneidad de los ingresos binacionales | ANDE, Itaipú Binacional, EBY |
| Datos tributarios por impuesto y contribuyente | Elasticidades y bases imponibles | DNIT (ex SET) |
| Pronósticos fiscales y del PIB del MEF | Separar componente anticipado (enlaza con E1/E2, excluidos) | MEF |

## 6. Evaluación de viabilidad

**Media-alta.** Hay 23 años de datos fiscales mensuales (MEFP 2001) junto con actividad mensual y PIB por gasto trimestral. La variable central existe y es larga; los riesgos son la estacionalidad fuerte, la identificación del shock de gasto y la calidad de 28 series del MEF con identidad posicional (etiquetas repetidas como "Corrientes" o "De Capital").

## 7. Supuestos que debes revisar

1. **Series del MEF no comprobadas:** 28 series tienen etiquetas repetidas (`mef_serie_corrientes`, `_1`, …, `mef_serie_de_capital_*`, `mef_serie_internos_*`, `mef_serie_externos_*`, donaciones, organismos internacionales); corresponden a sub-rubros de distintos bloques (ingresos por donaciones, financiamiento interno/externo, etc.) y **hay que identificarlas contra el Excel del MEF** antes de usarlas. Las 54 restantes tienen etiqueta única.
2. Los ingresos de las binacionales se consideran externos al ciclo doméstico: es una **hipótesis de identificación** que debe defenderse (dependen de la hidrología, de las tarifas negociadas y del tipo de cambio).
3. Cuadro 36 del Anexo: las etiquetas están contaminadas con encabezados de otras columnas; asignar por el texto inicial ("Ingresos", "Gastos — …", "Balance…").
4. Uso el IMAEP sin agricultura ni binacionales como medida principal del ciclo para no mezclar el efecto fiscal con el clima y la hidrología.
5. Este proyecto no usa vintages ni pronósticos del PIB (coherente con tu instrucción de excluir cortes de cuentas nacionales).

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Identificación y multiplicadores

| Referencia | Qué respalda en este proyecto |
|---|---|
| Blanchard, O. y Perotti, R. (2002). "An Empirical Characterization of the Dynamic Effects of Changes in Government Spending and Taxes on Output." *Quarterly Journal of Economics*, 117(4), 1329–1368. **[Revista]** | Supuesto de identificación del paso 3: el gasto no responde a la actividad dentro del período por los rezagos de decisión. Con datos **mensuales** el supuesto es más creíble que con trimestrales. |
| Ramey, V. A. y Zubairy, S. (2018). "Government Spending Multipliers in Good Times and in Bad: Evidence from US Historical Data." *Journal of Political Economy*, 126(2), 850–901. **[Revista]** | Multiplicador acumulado `ΣΔY/ΣΔG` estimado con proyecciones locales. |
| Ilzetzki, E., Mendoza, E. G. y Végh, C. A. (2013). "How Big (Small?) Are Fiscal Multipliers?" *Journal of Monetary Economics*, 60(2), 239–254. **[Revista]** | Los multiplicadores son **menores en economías abiertas, con tipo de cambio flexible y en desarrollo**, y el de la inversión pública es mayor que el del consumo público. Da la referencia de magnitud esperable para Paraguay y respalda separar el gasto corriente del de capital. |

### 8.2 Ciclicidad y regla fiscal

| Referencia | Qué respalda |
|---|---|
| Kaminsky, G. L., Reinhart, C. M. y Végh, C. A. (2004). "When It Rains, It Pours: Procyclical Capital Flows and Macroeconomic Policies." *NBER Macroeconomics Annual*, 19, 11–53. **[Revista]** | La política fiscal de los países en desarrollo tiende a ser **procíclica**. Es la hipótesis del paso 2. |
| Frankel, J. A., Végh, C. A. y Vuletin, G. (2013). "On Graduation from Fiscal Procyclicality." *Journal of Development Economics*, 100(1), 32–47. **[Revista]** | Algunos países dejaron de ser procíclicos, en parte por mejores instituciones. Respalda la interacción con los períodos de regla fiscal vigente o suspendida. |
| Alesina, A., Campante, F. R. y Tabellini, G. (2008). "Why Is Fiscal Policy Often Procyclical?" *Journal of the European Economic Association*, 6(5), 1006–1036. **[Revista]** | Explicación de economía política de la prociclicidad. Útil para interpretar los resultados. |
| Céspedes, L. F. y Velasco, A. (2014). "Was This Time Different?: Fiscal Policy in Commodity Republics." *Journal of Development Economics*, 106, 92–106. **[Revista]** | Respuesta del gasto a ingresos fiscales atados a recursos naturales. Es el análogo de las **regalías de las binacionales** del paso 4. |

### 8.3 Antecedentes para Paraguay

- **[PY]** David, A. C. (2017). "Fiscal Policy Effectiveness in a Small Open Economy: Estimates of Tax and Spending Multipliers in Paraguay." IMF Working Paper 17/63. **[DT]** **Antecedente directo**: encuentra multiplicadores del gasto de capital sustancialmente mayores que los del gasto corriente, y multiplicadores tributarios cercanos a cero con la identificación convencional (mayores con el enfoque narrativo). Este proyecto lo actualiza con datos mensuales hasta 2026, agrega la dimensión de la regla fiscal y el uso de las binacionales como variación externa.
- **[PY]** Ley N.º 5098/2013 de Responsabilidad Fiscal: déficit de hasta 1,5% del PIB (3% en emergencias) y un tope al crecimiento del gasto corriente primario de inflación + 4%. Estas reglas fechan los regímenes del paso 2.
