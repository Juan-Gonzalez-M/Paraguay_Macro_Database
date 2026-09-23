# 24 · N3 (proyecto nuevo) — Paraguay en el panel regional: shocks globales, reservas, intervención y vulnerabilidad financiera

*Carpeta de datos generada por `R/01_extraer_datos.R` · {{GENERADO}}*

> **Proyecto no incluido en el portafolio original.** Lo propongo porque la base ya contiene, para **9 países sudamericanos** (Argentina, Bolivia, Brasil, Chile, Colombia, Ecuador, Paraguay, Perú y Uruguay), balanza de pagos, reservas, indicadores de solidez financiera (FSI), IPC, tipo de cambio, tipo de cambio real, términos de intercambio, tasas de política e intervención cambiaria del FMI, datos que ningún proyecto usa. Todos los proyectos del portafolio son de un solo país; este aporta la **variación entre países** que les falta a B1, B2 y C1 para separar lo común (shocks globales) de lo específico de Paraguay.

## 1. Resumen y pregunta de investigación

- **Preguntas:** (i) ¿cómo responden los flujos de capital, el tipo de cambio, la inflación, la mora y el capital bancario de cada país a shocks globales comunes (VIX, tasa Fed, dólar, commodities)? (ii) ¿amortiguan esas respuestas el nivel de reservas, la intervención cambiaria y la dolarización del crédito? (iii) ¿dónde se ubica Paraguay: es su respuesta excepcional una vez condicionada a sus características?
- **Estimandos:** respuestas medias y heterogéneas (interacciones con reservas/PIB, intervención y préstamos en ME) en proyecciones locales de panel; posición de Paraguay en la distribución regional.
- **Evidencia:** forma reducida con shocks globales comunes (más exógenos para economías pequeñas que los shocks domésticos) y efectos fijos de país.

## 2. Estrategia empírica propuesta

1. **Benchmarking descriptivo:** Paraguay frente a la mediana y el rango regional en cuenta corriente/PIB, entradas de IED, cartera y otra inversión, reservas, mora, capital, dolarización del crédito y posición abierta en ME (2005–2026).
2. **Proyecciones locales de panel (trimestral, 2005–2026):** `y_{i,t+h} = α_i + β_h · shock_global_t + γ_h · shock_t × X_{i,t−1} + controles + ε`, con `X` = reservas/PIB, intervención/PIB, préstamos ME/total. Resultados: flujos de capital (% del PIB), tipo de cambio, inflación, mora.
3. **Intervención cambiaria comparada:** usar los proxies homogéneos del FMI (WPFXI) para comparar la reacción de Paraguay con la de sus pares ante presiones cambiarias (complementa B1, que tiene el dato oficial diario).
4. **Términos de intercambio país-específicos:** shock de precios de commodities ponderado por la canasta exportadora de cada país (índice CTOT del FMI), con Paraguay y su canasta soja/carne/energía.
5. **Robustez:** excluir Argentina (inflación alta) y Ecuador (dolarizado) o tratarlos aparte; errores estándar de Driscoll-Kraay.

## 3. Series extraídas

Las series se nombran `<país>_<indicador>` (p. ej. `pry_fsi_mora`, `bra_cuenta_corriente`); la descripción incluye el código SDMX del FMI.

{{TABLA_SERIES}}

### Otros archivos

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `panel_regional_trimestral.csv` | Panel largo país × indicador × trimestre (balanza de pagos, PIB, FSI) | {{RANGO:panel_regional_trimestral.csv}} | Preliminar |
| `panel_regional_mensual.csv` | Panel largo país × indicador × mes (reservas, tipo de cambio, IPC, TCRE, términos de intercambio, tasa de política, intervención) | {{RANGO:panel_regional_mensual.csv}} | Preliminar |
| `disponibilidad_pais_indicador.csv` | Matriz de disponibilidad (1 = existe en la base) | 22 indicadores × 9 países | — |

{{TABLA_ARCHIVOS}}

## 4. Cómo se usarían los datos

- **Normalización:** flujos de balanza de pagos (millones de USD, trimestrales) en % del PIB: convertir el PIB nominal (moneda local) a USD con el tipo de cambio promedio del trimestre (promedio de los 3 meses de `tipo_cambio_prom`).
- **Transformaciones:** `Δlog` de tipo de cambio e IPC (inflación interanual); reservas en `log` o en % del PIB; FSI en puntos porcentuales; PIB real en `Δlog` interanual (viene sin desestacionalizar).
- **Frecuencias:** los shocks globales son mensuales; para el panel trimestral promediar (VIX, tasas) o tomar el fin de período (dólar).
- **Paraguay:** para la tasa de política usar la serie del BCP (carpetas 01/03), porque la del FMI termina en 2021-11; para reservas, comparar con la RIN del BCP antes de mezclar fuentes.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Datos actualizados del FMI (algunas series terminan en 2021–2025) | Cobertura reciente | Descarga nueva de IMF Data (reprocesar con el pipeline) |
| Intervención oficial diaria de los otros bancos centrales | La proxy WPFXI es mensual y aproximada | Bancos centrales de la región; base de Adler et al. (FMI) |
| Spreads soberanos (EMBI) por país | Shock de riesgo país | JP Morgan (EMBI) / Bloomberg |
| Flujos de cartera de alta frecuencia (EPFR) | Identificación de shocks de flujos | EPFR / IIF |
| Tipo de cambio real efectivo de Argentina, Perú y Ecuador | Faltan en la base | BIS (REER amplio); bancos centrales |

## 6. Evaluación de viabilidad

**Media-alta.** 192 de 198 combinaciones país-indicador están en la base (balanza de pagos desde 1975, FSI desde 2001–2005, series mensuales largas) y los shocks globales se incorporaron desde FRED. Los límites son la calidad preliminar de las series del FMI (no validadas en la base) y la falta de spreads soberanos.

## 7. Supuestos que debes revisar

1. **Selección de indicadores:** elegí por código SDMX un conjunto núcleo (22 indicadores). La base tiene muchas más desagregaciones (p. ej. 7.520 series de balanza de pagos); se pueden agregar editando la tabla `plantillas` del script.
2. **Reservas de Paraguay:** `pry_reservas_sin_oro` del FMI (≈ 9.000 millones de USD a nov-2025) no coincide con la RIN del BCP (Cuadro 56b) por diferencias de definición (oro, activos de reserva vs. reservas netas); no mezclar fuentes.
3. La tasa de política del FMI para Paraguay termina en 2021-11 y la de Argentina en 2025-06; Bolivia y Ecuador no tienen.
4. Ecuador está dolarizado: su tipo de cambio es 1 y su "política cambiaria" no es comparable.
5. Los signos de la balanza de pagos siguen el MBP6 (cuenta financiera = activos − pasivos; un saldo negativo es entrada neta de capital).

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Shocks globales y flujos de capital

| Referencia | Qué respalda en este proyecto |
|---|---|
| Rey, H. (2013). "Dilemma not Trilemma: The Global Financial Cycle and Monetary Policy Independence." *Jackson Hole Economic Policy Symposium*. **[Conferencia]** | Un ciclo financiero global (VIX) mueve flujos y crédito en todos los países. Justifica los shocks globales comunes. |
| Miranda-Agrippino, S. y Rey, H. (2020). "U.S. Monetary Policy and the Global Financial Cycle." *Review of Economic Studies*, 87(6), 2754–2776. **[Revista]** | La política de la Fed impulsa ese ciclo. Respalda la tasa Fed como shock. |
| Forbes, K. J. y Warnock, F. E. (2012). "Capital Flow Waves: Surges, Stops, Flight, and Retrenchment." *Journal of International Economics*, 88(2), 235–251. **[Revista]** | Los episodios extremos de flujos responden sobre todo a factores globales. Respalda los resultados de flujos por componente de la balanza de pagos. |
| Fratzscher, M. (2012). "Capital Flows, Push versus Pull Factors and the Global Financial Crisis." *Journal of International Economics*, 88(2), 341–356. **[Revista]** | Factores globales (push) frente a factores del país (pull). Justifica la heterogeneidad `shock × X_{i,t−1}`. |

### 8.2 Amortiguadores

| Referencia | Qué respalda |
|---|---|
| Obstfeld, M., Ostry, J. D. y Qureshi, M. S. (2019). "A Tie That Binds: Revisiting the Trilemma in Emerging Market Economies." *Review of Economics and Statistics*, 101(2), 279–293. **[Revista]** | El régimen cambiario modula la transmisión de shocks globales en emergentes. Es el diseño de las interacciones del paso 2. |
| Gourinchas, P.-O. y Obstfeld, M. (2012). "Stories of the Twentieth Century for the Twenty-First." *American Economic Journal: Macroeconomics*, 4(1), 226–265. **[Revista]** | Las reservas altas reducen la probabilidad de crisis. Respalda las reservas/PIB como amortiguador. |
| Adler, G., Chang, K. S., Mano, R. C. y Shao, Y. (2025). *Journal of Money, Credit and Banking*, 57(5), 1241–1273. **[Revista]** | Fuente de los datos de intervención del FMI (paso 3). |
| Gruss, B. y Kebhaj, S. (2019). "Commodity Terms of Trade: A New Database." IMF Working Paper 19/21. **[DT]** | Fuente y método de los **términos de intercambio de commodities** por país (paso 4). |

### 8.3 Métodos

- Jordà (2005) para las proyecciones locales de panel, y Driscoll, J. C. y Kraay, A. C. (1998), "Consistent Covariance Matrix Estimation with Spatially Dependent Panel Data", *Review of Economics and Statistics*, 80(4), 549–560, para los errores robustos a la dependencia entre países.

### 8.4 Antecedentes para Paraguay

- **[PY]** Adler, G. y Sosa, S. (2012). "Intra-Regional Spillovers in South America: Is Brazil Systemic After All?" IMF Working Paper 12/145. **[DT]** Los países del Cono Sur (incluido Paraguay) son vulnerables a shocks de producto de Brasil, sobre todo por comercio. Respalda incluir el ciclo de Brasil como shock regional.
