# 02 · B1 — Intervención cambiaria y eficacia en el mercado FX

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 20:01:34 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

## 1. Resumen y pregunta de investigación

Las intervenciones ocurren justamente cuando la presión cambiaria es excepcional, lo que invierte la causalidad de un coeficiente promedio. El aporte es estimar **duración, magnitud y dependencia de estado** de los efectos.

- **Pregunta:** ¿cuál es el efecto dinámico de una operación FX del BCP (mejor identificada) sobre el retorno, la volatilidad y el riesgo de cola del PYG/USD?
- **Estimando:** respuesta acumulada del tipo de cambio a h días por monto y tipo de operación (venta al sector financiero —compensatorias y complementarias—, compra, operaciones con el sector público).
- **Evidencia:** asociación condicionada con datos diarios; causalidad solo con timing, reglas o narrativa creíbles.

## 2. Estrategia empírica propuesta

1. **Taxonomía auditable de operaciones (2013–2026):** separar ventas al sector financiero (intervención de mercado), compras/ventas con el sector público (liquidación del Tesoro, no intervención) y compras de acumulación. Conciliar el diario con el mensual (ver sección 4).
2. **Función de reacción:** probit/tobit diario de la probabilidad y monto de venta en función de la presión previa (retornos y volatilidad de 1–5 días, BRL, dólar amplio, VIX, mes de cosecha). El memo de la función de reacción es un entregable en sí mismo.
3. **Estudios de eventos condicionados:** trayectoria del TCN 20 días antes y después de días con venta, comparando con días "falsos eventos" de presión similar sin intervención (matching por propensity score de la función de reacción).
4. **Proyecciones locales diarias:** `Δlog TCN_{t,t+h} = β_h · venta_t + γ·presión_{t-1} + controles`, h = 0–20, con venta instrumentada o residualizada por la función de reacción; resultados sobre volatilidad realizada y cuantiles (colas).
5. **Robustez:** excluir episodios extremos (2015–16, 2020, 2022–23), separar por régimen de ventas compensatorias (desde 2015) y comparar con los proxies del FMI (WPFXI).

La ficha exige no usar turnover como flujo ni ventas brutas como tratamiento neto; aquí el tratamiento es la venta al sector financiero y el neto se usa como robustez.

## 3. Series extraídas

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `bcp_compra_total_d` | Compra diaria de divisas del BCP: total | `bcp_fx_daily` OpDivisas2013(DatosDiarios) + OpDivisa… | diaria | 2013-01-02 | 2026-08-14 | 3.403 | USD (millones) | Preliminar | Tratamiento (compras) |
| `bcp_compra_financiero_d` | Compra diaria del BCP al sector financiero | `bcp_fx_daily` OpDivisas2013(DatosDiarios) + OpDivisa… | diaria | 2013-01-02 | 2026-08-14 | 3.403 | USD (millones) | Preliminar | Tratamiento (mercado) |
| `bcp_compra_publico_d` | Compra diaria del BCP al sector público | `bcp_fx_daily` OpDivisas2013(DatosDiarios) + OpDivisa… | diaria | 2013-01-02 | 2026-08-14 | 3.403 | USD (millones) | Preliminar | Operación con el Tesoro (no intervención de mercado) |
| `bcp_venta_total_d` | Venta diaria de divisas del BCP: total | `bcp_fx_daily` OpDivisas2013(DatosDiarios) + OpDivisa… | diaria | 2013-01-02 | 2026-08-14 | 3.403 | USD (millones) | Preliminar | Tratamiento (ventas) |
| `bcp_venta_financiero_d` | Venta diaria del BCP al sector financiero | `bcp_fx_daily` OpDivisas2013(DatosDiarios) + OpDivisa… | diaria | 2013-01-02 | 2026-08-14 | 3.403 | USD (millones) | Preliminar | Tratamiento principal (intervención vendedora) |
| `bcp_venta_publico_d` | Venta diaria del BCP al sector público | `bcp_fx_daily` OpDivisas2013(DatosDiarios) + OpDivisa… | diaria | 2013-01-02 | 2026-08-14 | 3.403 | USD (millones) | Preliminar | Operación con el Tesoro |
| `bcp_neto_financiero_d` | Compras netas diarias del BCP al sector financiero | `bcp_fx_daily` OpDivisas2013(DatosDiarios) + OpDivisa… | diaria | 2013-01-02 | 2026-08-14 | 3.403 | USD (millones) | Preliminar | Tratamiento neto (mercado) |
| `bcp_neto_publico_d` | Compras netas diarias del BCP al sector público | `bcp_fx_daily` OpDivisas2013(DatosDiarios) + OpDivisa… | diaria | 2013-01-02 | 2026-08-14 | 3.403 | USD (millones) | Preliminar | Control / separación de propósito |
| `bcp_neto_total_d` | Compras netas diarias (público + financiero) | `bcp_fx_daily` OpDivisas2013(DatosDiarios) + OpDivisa… | diaria | 2013-01-02 | 2026-08-14 | 3.403 | USD (millones) | Preliminar | Tratamiento agregado |
| `bcp_acum_financiero_d` | Compras netas acumuladas en el año: sector financiero | `bcp_fx_daily` OpDivisas2013(DatosDiarios) + OpDivisa… | diaria | 2013-01-02 | 2026-08-14 | 3.403 | USD (millones) | Preliminar | Verificación contable |
| `bcp_acum_publico_d` | Compras netas acumuladas en el año: sector público | `bcp_fx_daily` OpDivisas2013(DatosDiarios) + OpDivisa… | diaria | 2013-01-02 | 2026-08-14 | 3.403 | USD (millones) | Preliminar | Verificación contable |
| `bcp_acum_total_d` | Compras netas acumuladas en el año: total | `bcp_fx_daily` OpDivisas2013(DatosDiarios) + OpDivisa… | diaria | 2013-01-02 | 2026-08-14 | 3.403 | USD (millones) | Preliminar | Verificación contable |
| `tcn_venta` | Tipo de cambio referencial PYG/USD venta | `tcn_referential_daily` 2012_Venta + 2013_Venta + 2014_Venta +… | diaria | 2012-08-06 | 2026-08-25 | 3.502 | PYG_PER_USD | Preliminar | Resultado: retorno volatilidad y colas |
| `tcn_compra` | Tipo de cambio referencial PYG/USD compra | `tcn_referential_daily` 2012_Compra + 2013_Compra + 2014_Compr… | diaria | 2012-08-06 | 2026-08-25 | 3.502 | PYG_PER_USD | Preliminar | Resultado (spread compra-venta) |
| `ventas_compensatorias_m` | Ventas compensatorias del BCP (mensual) | `compensatory_fx_sales` Ventas(DatosMensuales) | mensual | 2015-01-01 | 2026-07-01 | 139 | USD (millones) | Preliminar | Tipo de operación |
| `ventas_complementarias_m` | Ventas complementarias del BCP (mensual) | `compensatory_fx_sales` Ventas(DatosMensuales) | mensual | 2015-01-01 | 2026-07-01 | 139 | USD (millones) | Preliminar | Tipo de operación |
| `ventas_total_m` | Ventas compensatorias + complementarias (mensual) | `compensatory_fx_sales` Ventas(DatosMensuales) | mensual | 2015-01-01 | 2026-07-01 | 139 | USD (millones) | Preliminar | Tipo de operación |
| `opfx_neto_total_m` | Histórico de operaciones cambiarias: neto total (mensual) | `fx_operations` NA | mensual | 1995-01-01 | 2026-07-01 | 379 | USD (millones) | Preliminar | Conciliación diario-mensual |
| `opfx_neto_financiero_m` | Histórico: neto con el sector financiero | `fx_operations` NA | mensual | 1995-01-01 | 2026-07-01 | 379 | USD (millones) | Preliminar | Conciliación |
| `opfx_compra_financiero_m` | Histórico: compras al sector financiero | `fx_operations` NA | mensual | 1995-01-01 | 2026-07-01 | 379 | USD (millones) | Preliminar | Conciliación |
| `opfx_venta_financiero_m` | Histórico: ventas al sector financiero | `fx_operations` NA | mensual | 1995-01-01 | 2026-07-01 | 379 | USD (millones) | Preliminar | Conciliación |
| `opfx_neto_publico_m` | Histórico: neto con el sector público | `fx_operations` NA | mensual | 1995-01-01 | 2026-07-01 | 379 | USD (millones) | Preliminar | Conciliación |
| `opfx_neto_otras_m` | Histórico: otras operaciones netas | `fx_operations` NA | mensual | 1995-01-01 | 2026-07-01 | 379 | USD (millones) | Preliminar | Conciliación |
| `wpfxi_spot_publicada_m` | FMI WPFXI: intervención spot publicada (millones USD) | `imf_wpfxi` NA | mensual | 2013-01-01 | 2024-07-01 | 139 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Comparación internacional |
| `wpfxi_spot_proxy_m` | FMI WPFXI: intervención spot aproximada (millones USD) | `imf_wpfxi` NA | mensual | 2000-01-01 | 2024-08-01 | 296 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Comparación internacional |
| `wpfxi_total_proxy_pib_m` | FMI WPFXI: intervención total aproximada (% del PIB promedio 3 años) | `imf_wpfxi` NA | mensual | 2000-01-01 | 2024-08-01 | 296 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Comparación internacional |
| `wpfxi_esterilizacion_m` | FMI WPFXI: dummy de esterilización | `imf_wpfxi` NA | mensual | 2000-01-01 | 2021-11-01 | 263 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Metadato de esterilización |
| `pyg_usd_prom_venta` | PYG por USD promedio mensual (venta) | `exchange_rates` USD Prom | mensual | 1989-01-01 | 2026-07-01 | 451 | PYG_PER_USD | Validada por regla | Resultado mensual |
| `rin_saldo` | Reservas internacionales netas | `economic_annex` CUADRO 56b | mensual | 2009-01-01 | 2026-08-01 | 212 | USD (millones) | Preliminar | Capacidad de intervención |
| `tpm` | Tasa de política monetaria | `economic_annex` CUADRO 19  | mensual | 2011-05-01 | 2026-07-01 | 183 | PERCENT | Preliminar | Control |
| `pyg_brl` | PYG por BRL (mensual) | `economic_annex` CUADRO 60a | mensual | 1997-01-01 | 2026-07-01 | 355 | PYG_PER_BRL | Preliminar | Control regional |
| `pyg_ars` | PYG por ARS (mensual) | `economic_annex` CUADRO 60a | mensual | 1997-01-01 | 2026-07-01 | 355 | PYG_PER_ARS | Preliminar | Control regional |
| `soja_chicago` | Soja Chicago USD/t (mensual) | `economic_annex` Cuadro 49 | mensual | 1994-01-01 | 2026-08-01 | 392 | USD_PER_TONNE | Preliminar | Control de flujos de exportación |
| `eve_tc_mes` | EVE (mediana): tipo de cambio esperado para el mes | `eve` NA | mensual | 2011-11-01 | 2026-08-01 | 178 | PYG_PER_USD | Preliminar | Presión esperada |
| `fwd_compra_no_residentes` | Compras forward a no residentes (volumen mensual) | `economic_annex` CUADRO 61 | mensual | 2015-07-01 | 2026-07-01 | 133 | USD (miles) | Preliminar | Presión de no residentes |
| `fwd_venta_no_residentes` | Ventas forward a no residentes (volumen mensual) | `economic_annex` CUADRO 61 | mensual | 2015-07-01 | 2026-07-01 | 133 | USD (miles) | Preliminar | Presión de no residentes |
| `call_usd_tasa_prom` | Call money USD: tasa promedio diaria | `interbank_market` Datos | diaria | 2011-02-01 | 2026-02-19 | 905 | PERCENT | Estructura especial (provisional) | Liquidez en dólares (control) |
| `call_usd_monto` | Call money USD: monto diario | `interbank_market` Datos | diaria | 2011-02-01 | 2026-02-19 | 905 | USD | Estructura especial (provisional) | Liquidez en dólares (control) |
| `dolar_amplio_d` | FRED: índice nominal amplio del dólar (diario) | `FRED` DTWEXBGS | diaria | 2006-01-02 | 2026-09-18 | 5.193 | INDEX | Externa (FRED), no verificada en la base | Control global diario |
| `vix_d` | FRED: VIX diario | `FRED` VIXCLS | diaria | 1990-01-02 | 2026-09-21 | 9.278 | INDEX_POINTS | Externa (FRED), no verificada en la base | Control global diario (riesgo) |
| `brl_usd_d` | FRED: BRL por USD diario | `FRED` DEXBZUS | diaria | 1995-01-02 | 2026-09-18 | 7.954 | BRL_PER_USD | Externa (FRED), no verificada en la base | Control regional diario |
| `ust_2a_d` | FRED: rendimiento Tesoro EE.UU. 2 años (diario) | `FRED` DGS2 | diaria | 1976-06-01 | 2026-09-21 | 12.573 | PERCENT | Externa (FRED), no verificada en la base | Control global diario (tasas) |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_diaria.csv` | 84.648 | 11 | 1976-06-01 | 2026-09-21 |
| `datos/series_diaria_ancho.csv` | 12.807 | 21 | 1976-06-01 | 2026-09-21 |
| `datos/series_mensual.csv` | 6.077 | 11 | 1989-01-01 | 2026-08-01 |
| `datos/series_mensual_ancho.csv` | 452 | 23 | 1989-01-01 | 2026-08-01 |
| `datos/diccionario_series.csv` | 42 | 13 | 1976-06-01 | 2015-07-01 |

## 4. Cómo se usarían los datos

- **Retornos:** `100·Δlog(tcn_venta)` diario; volatilidad realizada con ventanas de 5 y 20 días; colas con cuantiles condicionales.
- **Tratamiento:** `bcp_venta_financiero_d` en millones de USD, normalizado por el turnover del mercado (Cuadro 61, en B2) o por la RIN; indicador binario de "día con venta". **Conciliación verificada:** la suma mensual de `bcp_venta_financiero_d` coincide exactamente con `ventas_total_m` (compensatorias + complementarias) en todos los meses desde 2015. La suma de `bcp_neto_total_d` frente a `opfx_neto_total_m` tiene diferencia mediana ≈ 0, pero hay meses con diferencias de hasta ±35 millones de USD, probablemente porque el total mensual incluye "otras operaciones" que el archivo diario no registra; revisar antes de usar el neto total.
- **Tipo de operación diario:** solo existe el total diario; la partición compensatoria/complementaria es mensual, así que la separación diaria requiere la regla del programa (ver brechas).
- **Alineación de calendarios:** el TCN referencial y las operaciones del BCP siguen días hábiles de Paraguay; los controles de FRED siguen días hábiles de EE.UU. Unir por fecha calendario y **no** rellenar hacia adelante en feriados.
- **Mensual:** solo para la conciliación, la comparación con el FMI y la descripción; el análisis causal es diario.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Clasificación **diaria** compensatoria vs. complementaria | Tipo de operación, exigido por el nivel "mínimo" | BCP – Gerencia de Operaciones Internacionales |
| Hora de anuncio y de ejecución; ventana de subasta | Separar decisión de ejecución; frontera intradía | BCP – mesa de cambios |
| Reglas del programa de ventas compensatorias (montos preanunciados según ingresos de binacionales/Tesoro) | Posible fuente de variación predeterminada (identificación) | BCP – comunicados y resoluciones |
| Spreads y profundidad del mercado; flujo dealer-cliente | Nivel "ideal/óptimo" | BCP – reportes de operaciones cambiarias por entidad |
| Precios diarios de soja (CBOT) | Control diario de flujos de exportación | CME / Bloomberg (no disponible en FRED sin clave) |
| Comunicados del BCP fechados | Narrativa y anuncios | BCP – sala de prensa |

## 6. Evaluación de viabilidad

**Media.** La cronología diaria de operaciones (2013–2026, con ventas en 1.836 de 3.403 días hábiles) y el tipo de cambio diario permiten estudios de eventos y proyecciones locales condicionadas; la identificación causal depende de información institucional (reglas y timing del programa compensatorio) que no está en la base.

## 7. Supuestos que debes revisar

1. **Intervención de mercado = ventas y compras al sector financiero.** Las operaciones con el sector público se tratan como liquidación de flujos del Tesoro y binacionales, no como intervención.
2. La venta diaria al sector financiero equivale a la suma de ventas compensatorias + complementarias (conciliación mensual exacta desde 2015). El neto total diario no concilia exactamente con el mensual (ver sección 4).
3. Las series diarias de FRED (dólar amplio, VIX, BRL, UST 2 años) se unen por fecha calendario sin rellenar.
4. `wpfxi_*` (FMI) termina en 2024 y usa definiciones propias; es solo comparación.
5. Montos en millones de USD tal como publica el BCP.

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 El problema de identificación y cómo lo resuelve la literatura

| Referencia | Qué respalda en este proyecto |
|---|---|
| Dominguez, K. M. y Frankel, J. A. (1993). "Does Foreign-Exchange Intervention Matter? The Portfolio Effect." *American Economic Review*, 83(5), 1356–1369. **[Revista]** | Canales de portafolio y de señal de la intervención esterilizada. Es el marco conceptual del estimando. |
| Fatum, R. y Hutchison, M. M. (2003). "Is Sterilised Foreign Exchange Intervention Effective After All? An Event Study Approach." *Economic Journal*, 113(487), 390–411. **[Revista]** | **Estudios de eventos** de intervención con ventanas cortas (paso 3). |
| Kearns, J. y Rigobon, R. (2005). "Identifying the Efficacy of Central Bank Interventions: Evidence from Australia and Japan." *Journal of International Economics*, 66(1), 31–48. **[Revista]** | La simultaneidad entre intervención y tipo de cambio sesga el coeficiente, y un cambio de regla permite identificar. Respalda separar por régimen de ventas compensatorias (desde 2015). |
| Kuersteiner, G. M., Phillips, D. C. y Villamizar-Villegas, M. (2018). "Effective Sterilized Foreign Exchange Intervention? Evidence from a Rule-Based Policy." *Journal of International Economics*, 113, 118–138. **[Revista]** | **Referencia más cercana al diseño ideal**: una regla de intervención (Colombia) genera variación cuasi-aleatoria con datos diarios. Si las ventas compensatorias del BCP siguen una regla o un anuncio, este es el diseño a replicar. |
| Fratzscher, M., Gloede, O., Menkhoff, L., Sarno, L. y Stöhr, T. (2019). "When Is Foreign Exchange Intervention Effective? Evidence from 33 Countries." *American Economic Journal: Macroeconomics*, 11(1), 132–156. **[Revista]** | Con datos diarios de 33 países, la intervención es más eficaz para **suavizar** y cuando es de mayor tamaño y comunicada. Respalda medir la volatilidad y las colas además del retorno. |

### 8.2 Métodos y datos

| Referencia | Uso |
|---|---|
| Angrist, J. D., Jordà, Ò. y Kuersteiner, G. M. (2018). "Semiparametric Estimates of Monetary Policy Effects: String Theory Revisited." *Journal of Business & Economic Statistics*, 36(3), 371–387. **[Revista]** | Proyecciones locales ponderadas por la **probabilidad de intervención** (propensity score). Es la versión formal del matching de "falsos eventos" de los pasos 3 y 4. |
| Echavarría, J. J., Melo-Velandia, L. F. y Villamizar-Villegas, M. (2018). "The Impact of Pre-announced Day-to-day Interventions on the Colombian Exchange Rate." *Empirical Economics*, 55(3), 1319–1336. **[Revista]** | Función de reacción Tobit con impacto sobre el nivel y la volatilidad (GARCH) con datos diarios. Modelo para el paso 2. |
| Fuentes, M. et al. (2014). "The Effects of Intraday Foreign Exchange Market Operations in Latin America: Results for Chile, Colombia, Mexico and Peru." BIS Working Paper 462. **[DT]** | Comparación regional: efectos significativos pero transitorios, salvo anuncios de programas. |
| Chamon, M., Hofman, D., Magud, N. E. y Werner, A. (eds.) (2019). *Foreign Exchange Intervention in Inflation Targeters in Latin America*. Fondo Monetario Internacional. **[Libro]** | Experiencias de bancos centrales con metas de inflación e intervención, incluido el caso dolarizado de Perú. |
| Adler, G., Chang, K. S., Mano, R. C. y Shao, Y. (2025). "Foreign Exchange Intervention: A Data Set of Official Data and Estimates." *Journal of Money, Credit and Banking*, 57(5), 1241–1273. **[Revista]** | Fuente de los proxies de intervención del FMI (WPFXI) usados como robustez (paso 5). |

### 8.3 Antecedentes para Paraguay

No encontré una evaluación publicada de la eficacia de las ventas del BCP. La prensa y los analistas locales discuten si las ventas "cortan picos" o consolidan tendencias, sin estimaciones formales. Conviene revisar el material interno del BCP sobre el esquema de ventas compensatorias (venta al mercado de las divisas del Tesoro), cuya **regla o anuncio** es la clave para aplicar un diseño como el de Kuersteiner et al. (2018).
