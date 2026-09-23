# 25 · N4 (proyecto nuevo) — Sorpresas de política monetaria de alta frecuencia

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 20:39:18 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

> **Proyecto nuevo, de infraestructura con potencial causal.** Construye la serie de *shocks monetarios bien medidos* que hoy le falta al portafolio y que usarían como tratamiento A1, C2, C3, E3, B2 y el canal de crédito (proyecto 29).

## 1. Resumen y pregunta de investigación

En Paraguay la TPM responde a la inflación y a la actividad, por lo que su nivel no es un shock. La literatura (Gürkaynak-Sack-Swanson; Nakamura-Steinsson) identifica el componente sorpresivo con el movimiento de tasas de mercado en una ventana estrecha alrededor del anuncio.

- **Pregunta:** ¿qué parte de cada decisión del COPOM fue sorpresiva para el mercado y cómo se transmite esa sorpresa a las tasas interbancarias, de LRM, de bonos y al tipo de cambio?
- **Estimando:** serie de sorpresas `s_t = Δ tasa de mercado (ventana del anuncio)`, y respuestas de tasas y tipo de cambio a `s_t` (0–60 días).
- **Evidencia:** causal en el sentido de alta frecuencia (el anuncio es lo único que cambia sistemáticamente dentro de la ventana), con los límites de la sección 7.

## 2. Estrategia empírica propuesta

1. **Calendario:** fechas y horas de las reuniones y anuncios del COPOM (`datos_manuales/calendario_copom.csv`). Mientras tanto, `fechas_candidatas_cambio_tpm.csv` identifica **40 fechas** en que FPL y FPD se movieron en paralelo y en la misma magnitud (2015–2026), que reconstruyen la trayectoria de la TPM (p. ej., recortes a 0,75% en 2020 y subas a 8,5% en 2021–22).
2. **Sorpresa diaria:** variación de la tasa promedio del mercado interbancario (call + REPO + tripartito) y del REPO interbancario entre t−1 y t+1 del anuncio, menos el cambio de la TPM *esperado* (EVE, mediana del mes). Variante sin EVE: componente del cambio de la TPM no anticipado por el movimiento previo del interbancario.
3. **Validación:** las sorpresas deben ser grandes en las fechas del COPOM y ≈ 0 en días placebo (sin reunión); no deben predecirse con información pública previa (inflación, IMAEP, Fed).
4. **Transmisión:** proyecciones locales diarias de tasas de LRM adjudicadas, REPO, curva de bonos corporativos en PYG (plazos 1–5 años) y TCN sobre `s_t`; mensual, sobre tasas activas y pasivas.
5. **Uso posterior:** exportar la serie de sorpresas como instrumento de la TPM para A1, C2, C3, E3, B2 y el canal de crédito (proyecto 29).

## 3. Series extraídas

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `tpm` | TPM promedio mensual (Cuadro 19) | `economic_annex` CUADRO 19  | mensual | 2011-05-01 | 2026-07-01 | 183 | PERCENT | Preliminar | Referencia mensual |
| `eve_tpm_mes` | EVE (mediana): TPM esperada para el mes | `eve` NA | mensual | 2014-06-01 | 2026-08-01 | 147 | PROPORTION | Preliminar | Sorpresa mensual alternativa (baja frecuencia) |
| `eve_tpm_prox_mes` | EVE (mediana): TPM esperada próximo mes | `eve` NA | mensual | 2014-06-01 | 2026-08-01 | 147 | PROPORTION | Preliminar | Sorpresa mensual alternativa |
| `eve_tpm_anio_t` | EVE (mediana): TPM esperada fin de año t | `eve` NA | mensual | 2014-06-01 | 2026-08-01 | 147 | PROPORTION | Preliminar | Sorpresa de trayectoria (forward guidance) |
| `eve_tpm_anio_t1` | EVE (mediana): TPM esperada fin de año t+1 | `eve` NA | mensual | 2014-06-01 | 2026-08-01 | 147 | PROPORTION | Preliminar | Sorpresa de trayectoria |
| `tcn_venta` | TCN referencial diario PYG/USD venta | `tcn_referential_daily` 2012_Venta + 2013_Venta + 2014_Venta +… | diaria | 2012-08-06 | 2026-08-25 | 3.502 | PYG_PER_USD | Preliminar | Resultado diario: tipo de cambio |
| `bcp_fx_neto_total_d` | Compras netas diarias del BCP | `bcp_fx_daily` OpDivisas2013(DatosDiarios) + OpDivisa… | diaria | 2013-01-02 | 2026-08-14 | 3.403 | USD (millones) | Preliminar | Control (días con intervención) |
| `ib_call_money_market_pyg_monto_call_millones_de_gs` | Mercado interbancario diario: Call Money Market (PYG) — Monto Call (Millones de Gs.) | `interbank_market` Datos | diaria | 2016-04-28 | 2026-01-26 | 12 | PYG (millones) | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_call_money_market_pyg_numero_de_transacciones` | Mercado interbancario diario: Call Money Market (PYG) — Número de transacciones | `interbank_market` Datos | diaria | 2016-04-28 | 2026-01-26 | 12 | COUNT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_call_money_market_pyg_tasa_maxima` | Mercado interbancario diario: Call Money Market (PYG) — Tasa Máxima | `interbank_market` Datos | diaria | 2016-04-28 | 2026-01-26 | 12 | PYG | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_call_money_market_pyg_tasa_minima` | Mercado interbancario diario: Call Money Market (PYG) — Tasa Mínima | `interbank_market` Datos | diaria | 2016-04-28 | 2026-01-26 | 12 | PYG | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_call_money_market_pyg_tasa_promedio_pct` | Mercado interbancario diario: Call Money Market (PYG) — Tasa Promedio (%) | `interbank_market` Datos | diaria | 2016-04-28 | 2026-01-26 | 12 | PERCENT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_call_money_market_usd_monto_usd` | Mercado interbancario diario: Call Money Market (USD) — Monto (USD) | `interbank_market` Datos | diaria | 2011-02-01 | 2026-02-19 | 905 | USD | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_call_money_market_usd_numero_de_transacciones` | Mercado interbancario diario: Call Money Market (USD) — Número de transacciones | `interbank_market` Datos | diaria | 2011-02-01 | 2026-02-19 | 905 | COUNT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_call_money_market_usd_tasa_maxima_pct` | Mercado interbancario diario: Call Money Market (USD) — Tasa Máxima (%) | `interbank_market` Datos | diaria | 2011-02-01 | 2026-02-19 | 905 | PERCENT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_call_money_market_usd_tasa_minima_pct` | Mercado interbancario diario: Call Money Market (USD) — Tasa Mínima (%) | `interbank_market` Datos | diaria | 2011-02-01 | 2026-02-19 | 905 | PERCENT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_call_money_market_usd_tasa_promedio_pct` | Mercado interbancario diario: Call Money Market (USD) — Tasa Promedio (%) | `interbank_market` Datos | diaria | 2011-02-01 | 2026-02-19 | 905 | PERCENT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_coeficiente_de_cobertura_haircut_tasa_pct` | Mercado interbancario diario: Coeficiente de Cobertura Haircut — Tasa (%) | `interbank_market` Datos | diaria | 2010-01-04 | 2026-08-14 | 4.158 | PERCENT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_facilidad_permanente_de_deposito_fpd_monto_adjudicado_millon` | Mercado interbancario diario: Facilidad Permanente de Depósito (FPD) — Monto Adjudicado (Millones Gs.) | `interbank_market` Datos | diaria | 2013-01-02 | 2026-08-14 | 3.401 | PYG (millones) | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_facilidad_permanente_de_deposito_fpd_tasa_pct` | Mercado interbancario diario: Facilidad Permanente de Depósito (FPD) — Tasa (%) | `interbank_market` Datos | diaria | 2013-01-02 | 2026-08-14 | 3.401 | PERCENT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_facilidad_permanente_de_liquidez_fpl_1er_tramo_tasa_pct` | Mercado interbancario diario: Facilidad Permanente de Liquidez (FPL) 1er Tramo — Tasa (%) | `interbank_market` Datos | diaria | 2014-01-16 | 2026-08-14 | 3.141 | PERCENT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_facilidad_permanente_de_liquidez_fpl_2do_tramo_tasa_pct` | Mercado interbancario diario: Facilidad Permanente de Liquidez (FPL) 2do Tramo — Tasa (%) | `interbank_market` Datos | diaria | 2014-01-16 | 2026-08-14 | 3.141 | PERCENT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_facilidad_permanente_de_liquidez_fpl_tasa_pct` | Mercado interbancario diario: Facilidad Permanente de Liquidez (FPL) — Tasa (%) | `interbank_market` Datos | diaria | 2014-03-19 | 2026-08-14 | 3.097 | PERCENT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_mercado_interbancario_de_fondos_cmm_repo_interbancario_repo_` | Mercado interbancario diario: Mercado Interbancario de Fondos CMM + REPO Interbancario + REPO Tripartito (PYG) — Monto VLI + Call (Millones Gs.) | `interbank_market` Datos | diaria | 2011-10-10 | 2026-08-14 | 3.287 | PYG (millones) | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_mercado_interbancario_de_fondos_cmm_repo_interbancario_repo__1` | Mercado interbancario diario: Mercado Interbancario de Fondos CMM + REPO Interbancario + REPO Tripartito (PYG) — Número de Participantes | `interbank_market` Datos | diaria | 2020-08-14 | 2026-08-14 | 1.487 | COUNT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_mercado_interbancario_de_fondos_cmm_repo_interbancario_repo__2` | Mercado interbancario diario: Mercado Interbancario de Fondos CMM + REPO Interbancario + REPO Tripartito (PYG) — Número de transacciones | `interbank_market` Datos | diaria | 2011-10-10 | 2026-08-14 | 3.287 | COUNT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_mercado_interbancario_de_fondos_cmm_repo_interbancario_repo__3` | Mercado interbancario diario: Mercado Interbancario de Fondos CMM + REPO Interbancario + REPO Tripartito (PYG) — Tasa Máxima (%) | `interbank_market` Datos | diaria | 2011-10-10 | 2026-08-14 | 3.250 | PERCENT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_mercado_interbancario_de_fondos_cmm_repo_interbancario_repo__4` | Mercado interbancario diario: Mercado Interbancario de Fondos CMM + REPO Interbancario + REPO Tripartito (PYG) — Tasa Mínima (%) | `interbank_market` Datos | diaria | 2011-10-10 | 2026-08-14 | 3.251 | PERCENT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_mercado_interbancario_de_fondos_cmm_repo_interbancario_repo__5` | Mercado interbancario diario: Mercado Interbancario de Fondos CMM + REPO Interbancario + REPO Tripartito (PYG) — Tasa Promedio (%) | `interbank_market` Datos | diaria | 2011-10-10 | 2026-08-14 | 3.249 | PERCENT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_repo_interbancario_pyg_de_operaciones` | Mercado interbancario diario: REPO Interbancario (PYG) — # de Operaciones | `interbank_market` Datos | diaria | 2014-07-11 | 2026-08-14 | 2.888 | COUNT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_repo_interbancario_pyg_monto` | Mercado interbancario diario: REPO Interbancario (PYG) — Monto | `interbank_market` Datos | diaria | 2014-07-11 | 2026-08-14 | 2.888 | PYG | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_repo_interbancario_pyg_tasa_maxima_pct` | Mercado interbancario diario: REPO Interbancario (PYG) — Tasa Máxima (%) | `interbank_market` Datos | diaria | 2014-07-11 | 2026-08-14 | 2.855 | PERCENT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_repo_interbancario_pyg_tasa_minima_pct` | Mercado interbancario diario: REPO Interbancario (PYG) — Tasa Mínima (%) | `interbank_market` Datos | diaria | 2014-07-11 | 2026-08-14 | 2.855 | PERCENT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_repo_interbancario_pyg_tasa_promedio_pct` | Mercado interbancario diario: REPO Interbancario (PYG) — Tasa Promedio (%) | `interbank_market` Datos | diaria | 2014-07-11 | 2026-08-14 | 2.855 | PERCENT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_repo_tripartito_pyg_monto_vli_millones_gs` | Mercado interbancario diario: REPO Tripartito (PYG) — Monto VLI (Millones Gs.) | `interbank_market` Datos | diaria | 2011-10-10 | 2026-08-14 | 2.963 | PYG (millones) | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_repo_tripartito_pyg_numero_de_transacciones` | Mercado interbancario diario: REPO Tripartito (PYG) — Número de transacciones | `interbank_market` Datos | diaria | 2011-10-10 | 2026-08-14 | 2.963 | COUNT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_repo_tripartito_pyg_tasa_maxima_pct` | Mercado interbancario diario: REPO Tripartito (PYG) — Tasa Máxima (%) | `interbank_market` Datos | diaria | 2011-10-10 | 2026-08-14 | 2.955 | PERCENT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_repo_tripartito_pyg_tasa_minima_pct` | Mercado interbancario diario: REPO Tripartito (PYG) — Tasa Mínima (%) | `interbank_market` Datos | diaria | 2011-10-10 | 2026-08-14 | 2.955 | PERCENT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `ib_repo_tripartito_pyg_tasa_promedio_pct` | Mercado interbancario diario: REPO Tripartito (PYG) — Tasa Promedio (%) | `interbank_market` Datos | diaria | 2011-10-10 | 2026-08-14 | 2.955 | PERCENT | Estructura especial (provisional) | Resultado diario: tasas y cantidades de corto plazo |
| `fed_funds_d` | FRED: tasa de fondos federales efectiva diaria | `FRED` DFF | diaria | 1954-07-01 | 2026-09-21 | 26.381 | PERCENT | Externa (FRED), no verificada en la base | Control externo diario |
| `ust_2a_d` | FRED: rendimiento Tesoro EE.UU. 2 años diario | `FRED` DGS2 | diaria | 1976-06-01 | 2026-09-21 | 12.573 | PERCENT | Externa (FRED), no verificada en la base | Control externo diario |
| `vix_d` | FRED: VIX diario | `FRED` VIXCLS | diaria | 1990-01-02 | 2026-09-21 | 9.278 | INDEX_POINTS | Externa (FRED), no verificada en la base | Control externo diario |

### Otros archivos

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `fechas_candidatas_cambio_tpm.csv` | Días en que FPD y FPL cambian el mismo día y en la misma magnitud, con la TPM implícita (punto medio del corredor) | 2015-04-22 a 2026-02-23, 40 filas | Inferido de datos preliminares |
| `cambios_corredor_inferidos.csv` | Todos los cambios diarios de la tasa FPD o FPL (incluye ajustes menores de 2013–2014 que no son decisiones de TPM) | 2013-01-04 a 2026-02-23, 127 filas | Inferido |
| `eventos_subastas_lrm.csv` | Subastas de LRM (tasas ofertadas/adjudicadas, montos, plazo) | 2013-01-08 a 2026-07-30, 10.334 filas | Estructura especial |
| `curvas_bonos_pyg.csv` | Curva cero de bonos corporativos en PYG por calificación y plazo (fechas irregulares) | 2010-11-01 a 2026-07-31, 23.673 filas | Validada por regla (estructural) |
| `datos_manuales/calendario_copom.csv` | **Plantilla para completar**: fecha de reunión, fecha y hora del anuncio, TPM anterior y nueva, tipo de reunión, fuente | vacía | Manual |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_diaria.csv` | 127.004 | 11 | 1954-07-01 | 2026-09-21 |
| `datos/series_diaria_ancho.csv` | 26.381 | 38 | 1954-07-01 | 2026-09-21 |
| `datos/series_mensual.csv` | 771 | 11 | 2011-05-01 | 2026-08-01 |
| `datos/series_mensual_ancho.csv` | 184 | 6 | 2011-05-01 | 2026-08-01 |
| `datos/diccionario_series.csv` | 42 | 13 | 1954-07-01 | 2020-08-14 |
| `datos/cambios_corredor_inferidos.csv` | 127 | 7 | 2013-01-04 | 2026-02-23 |
| `datos/fechas_candidatas_cambio_tpm.csv` | 40 | 7 | 2015-04-22 | 2026-02-23 |
| `datos/eventos_subastas_lrm.csv` | 10.334 | 9 | 2013-01-08 | 2026-07-30 |
| `datos/curvas_bonos_pyg.csv` | 23.673 | 5 | 2010-11-01 | 2026-07-31 |

## 4. Cómo se usarían los datos

- **Ventanas:** diaria (t−1 a t+1). Con la hora del anuncio se puede decidir si el día del anuncio pertenece a t o a t+1 (anuncios después del cierre del mercado).
- **Tasas en puntos porcentuales**; sorpresas en puntos básicos. No transformar en logaritmos.
- **Días hábiles:** el mercado interbancario tiene huecos (días sin operaciones); usar la última observación disponible *antes* y la primera *después* del anuncio, y registrar la distancia en días.
- **Agregación mensual:** suma de las sorpresas del mes para usarlas en modelos mensuales.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| **Calendario del COPOM con hora de anuncio** | Define las ventanas; sin él la sorpresa se basa en las fechas inferidas del corredor (fecha de vigencia, no de anuncio) | BCP – comunicados del COPOM (lo conseguirás mañana) |
| Tasas intradía o de cierre del interbancario y del REPO | Ventanas más estrechas | BCP – mercado monetario |
| Rendimientos de mercado secundario de bonos del Tesoro y de LRM (diarios) | Sorpresas sobre la curva (*path* vs. *target*) | BVA / SEN; BCP |
| Forwards PYG/USD diarios | Reacción cambiaria de corto plazo | BCP – operaciones cambiarias |

## 6. Evaluación de viabilidad

**Media-alta.** Hay tasas diarias del interbancario y del corredor desde 2011–2014 y las fechas de cambio de TPM se pueden reconstruir desde los datos (40 fechas candidatas); con el calendario oficial del COPOM (que tendrás mañana) el proyecto queda completo. El límite es la ventana diaria: en Paraguay no hay un mercado de futuros de tasas y el interbancario es poco profundo.

## 7. Supuestos que debes revisar

1. Las fechas candidatas son **fechas de vigencia del nuevo corredor**, no necesariamente de la reunión ni del anuncio; confirmar con el calendario del COPOM.
2. En 2016 el punto medio del corredor (p. ej. 6,375%) no coincide con la TPM publicada: el corredor no era simétrico en todos los períodos; la TPM oficial debe venir del calendario.
3. Las decisiones de **mantener** la TPM no aparecen como fechas candidatas (no mueven el corredor), pero pueden contener sorpresas; por eso el calendario completo es indispensable.
4. Las series del mercado interbancario son "estructura especial (provisional)" en la base.

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Identificación de alta frecuencia

| Referencia | Qué respalda en este proyecto |
|---|---|
| Kuttner, K. N. (2001). "Monetary Policy Surprises and Interest Rates: Evidence from the Fed Funds Futures Market." *Journal of Monetary Economics*, 47(3), 523–544. **[Revista]** | Separar el componente **esperado** del sorpresivo de cada decisión con precios de mercado. Base del paso 2. |
| Gürkaynak, R. S., Sack, B. y Swanson, E. T. (2005). "Do Actions Speak Louder Than Words? The Response of Asset Prices to Monetary Policy Actions and Statements." *International Journal of Central Banking*, 1(1), 55–93. **[Revista]** | Sorpresas en ventanas estrechas y su efecto en la curva. Respalda el paso 4. |
| Nakamura, E. y Steinsson, J. (2018). "High-Frequency Identification of Monetary Non-Neutrality: The Information Effect." *Quarterly Journal of Economics*, 133(3), 1283–1330. **[Revista]** | Justificación de la ventana alrededor del anuncio, y advertencia sobre el **efecto información** (el anuncio revela información del banco central sobre la economía). |
| Jarociński, M. y Karadi, P. (2020). "Deconstructing Monetary Policy Surprises—The Role of Information Shocks." *American Economic Journal: Macroeconomics*, 12(2), 1–43. **[Revista]** | Separa el shock de política del de información con el co-movimiento de tasas y acciones. En Paraguay podría aproximarse con tasas y tipo de cambio. |
| Bauer, M. D. y Swanson, E. T. (2023). "A Reassessment of Monetary Policy Surprises and High-Frequency Identification." *NBER Macroeconomics Annual*, 37, 87–155. **[Revista]** | Las sorpresas pueden ser **predecibles** con información pública previa. Respalda la prueba de validación del paso 3. |

### 8.2 Alternativas cuando no hay derivados

| Referencia | Qué respalda |
|---|---|
| Romer, C. D. y Romer, D. H. (2004). "A New Measure of Monetary Shocks: Derivation and Implications." *American Economic Review*, 94(4), 1055–1084. **[Revista]** | Shock como el residuo de la decisión respecto de los pronósticos del banco central. Alternativa cuando el mercado interbancario es poco líquido (con los pronósticos internos del BCP). |
| Bolhuis, M. A., Das, S. y Yao, B. (2024). "A New Dataset of High-Frequency Monetary Policy Shocks." IMF Working Paper 24/224. **[DT]** | Base de datos de sorpresas diarias para 29 bancos centrales, incluidos emergentes, con un método estandarizado. Referencia de procedimiento y de comparación. |

### 8.3 Antecedentes para Paraguay

No encontré una serie publicada de sorpresas monetarias para Paraguay. Al no haber futuros de tasas, la sorpresa debe construirse con el **mercado interbancario** y con la **EVE** (mediana de la TPM esperada). Esa combinación de mercado y encuesta está menos validada en la literatura que los derivados, así que la validación del paso 3 es clave.
