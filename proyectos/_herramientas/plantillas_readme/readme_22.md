# 22 · N1 (proyecto nuevo) — Política fiscal: ciclicidad, estabilizadores y multiplicadores

*Carpeta de datos generada por `R/01_extraer_datos.R` · {{GENERADO}}*

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

{{TABLA_SERIES}}

{{TABLA_ARCHIVOS}}

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
