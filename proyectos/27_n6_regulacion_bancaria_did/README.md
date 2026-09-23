# 27 · N6 (proyecto nuevo) — Cambios regulatorios con exposición bancaria heterogénea (DiD)

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 20:41:11 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

> **Proyecto nuevo con potencial causal.** Usa cambios regulatorios fechados (encaje legal; tope a las tasas de tarjetas de crédito) y la exposición **previa** de cada banco para identificar efectos de oferta de crédito, lo que C2 y C1 no pueden hacer con agregados.

## 1. Resumen y pregunta de investigación

- **Módulo A — encaje legal:** ¿cuánto aumenta el crédito (y en qué moneda y sector) un banco más liberado por una reducción del encaje, frente a uno menos liberado? Estimando: elasticidad del crédito a la liquidez liberada (DiD continuo).
- **Módulo B — tope de tasas de tarjetas:** ¿qué pasó con el precio, la cantidad y el acceso al crédito de tarjetas tras el tope? Estimando: efecto sobre tasas, saldos y número de tarjetas.
- **Evidencia:** causal en el módulo A (tratamiento regulatorio × exposición predeterminada, con efectos fijos de tiempo y de sector-tiempo para absorber la demanda); en el módulo B, **serie de tiempo interrumpida** con los datos actuales (ver sección 6).

## 2. Estrategia empírica propuesta

**Módulo A (encaje)**
1. Cargar cada cambio de tasas de encaje (fecha, moneda, plazo, valor anterior y nuevo) en `datos_manuales/cambios_regulatorios.csv`.
2. Exposición del banco *b* a cada cambio: liquidez liberada = Δ tasa × base encajable previa (depósitos por moneda y plazo en t−1), normalizada por activos. La base encajable por plazo se aproxima con los depósitos a la vista, a plazo y CDA del panel EEFF.
3. `Δlog crédito_{b,s,m,t+h} = β_h · liberación_{b,m,t} + FE_{s,m,t} + FE_b + ε`, h = 0–12 meses, con efectos fijos sector × moneda × mes (Khwaja-Mian): compara el mismo sector y mes entre bancos.
4. Resultados: crédito por sector y moneda, tenencia de valores públicos y de IRM, tasas implícitas.

**Módulo B (tope de tarjetas)**
5. En los datos del sistema la tasa promedio ponderada de tarjetas en MN cae de **48,3% (sep-2015) a 16,9% (oct-2015)** y la máxima de 55% a 16% en noviembre: el tope entra en vigor en **octubre de 2015**.
6. Serie de tiempo interrumpida: tasas de tarjetas vs. tasas de consumo y sobregiros (sustitución), y saldos de tarjetas en el sistema (Indicadores Financieros, hoja 4) antes y después.
7. **DiD por banco**, solo si se consiguen boletines de bancos 2013–2015: participación previa de tarjetas en la cartera de cada banco × post-tope.

## 3. Series extraídas

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `tpm` | Tasa de política monetaria | `economic_annex` CUADRO 19  | mensual | 2011-05-01 | 2026-07-01 | 183 | PERCENT | Preliminar | Control (política monetaria simultánea) |
| `bancos_encaje_mn` | Encaje legal de bancos en el BCP MN (agregado) | `economic_annex` CUADRO 27 | mensual | 1994-01-01 | 2026-06-01 | 390 | PYG (millones) | Preliminar | Primera etapa agregada (módulo A) |
| `bancos_encaje_me` | Encaje legal de bancos en el BCP ME (millones de Gs. equivalentes) | `economic_annex` CUADRO 27 | mensual | 1994-01-01 | 2026-06-01 | 390 | UNRESOLVED_SOURCE_UNITS (millones) | Preliminar | Primera etapa agregada (módulo A) |
| `gasto_remun_encaje_mn` | Remuneración del encaje MN (gasto del BCP) | `economic_annex` CUADRO 26 | mensual | 2002-01-01 | 2026-07-01 | 295 | PYG (millones) | Preliminar | Costo del encaje |
| `cred_priv_mn` | Crédito privado MN (agregado) | `economic_annex` CUADRO 24a | mensual | 1995-03-01 | 2026-06-01 | 370 | PYG (millones) | Preliminar | Resultado agregado |
| `cred_priv_me_usd` | Crédito privado ME en millones de USD | `economic_annex` CUADRO 24a | mensual | 1995-03-01 | 2026-06-01 | 370 | UNRESOLVED_SOURCE_UNITS (millones) | Preliminar | Resultado agregado |
| `imaep_original` | IMAEP serie original | `economic_annex` CUADRO 9 | mensual | 1994-01-01 | 2026-06-01 | 390 | INDEX | Preliminar | Control de demanda |
| `ipc_indice` | IPC índice general | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Deflactor |
| `fi_1_1_*` | 9 series: financial_indicators hoja 1.1 (detalle en diccionario_series.csv) | `financial_indicators` 1.1 | mensual | 2011-01-01 | 2026-06-01 | 1.674 | PERCENT | Preliminar (9) | Tasas y saldos de tarjetas/consumo/sobregiros (módulo B: resultado y placebo) |
| `fi_1_2_*` | 9 series: financial_indicators hoja 1.2 (detalle en diccionario_series.csv) | `financial_indicators` 1.2 | mensual | 2011-01-01 | 2026-06-01 | 1.674 | PERCENT | Preliminar (9) | Tasas y saldos de tarjetas/consumo/sobregiros (módulo B: resultado y placebo) |
| `fi_2_1_*` | 11 series: financial_indicators hoja 2.1 (detalle en diccionario_series.csv) | `financial_indicators` 2.1 | mensual | 2011-01-01 | 2026-06-01 | 1.957 | PERCENT | Preliminar (11) | Tasas y saldos de tarjetas/consumo/sobregiros (módulo B: resultado y placebo) |
| `fi_2_2_*` | 11 series: financial_indicators hoja 2.2 (detalle en diccionario_series.csv) | `financial_indicators` 2.2 | mensual | 2011-01-01 | 2026-06-01 | 1.958 | PERCENT | Preliminar (11) | Tasas y saldos de tarjetas/consumo/sobregiros (módulo B: resultado y placebo) |
| `fi_3_1_*` | 55 series: financial_indicators hoja 3.1 (detalle en diccionario_series.csv) | `financial_indicators` 3.1 | mensual | 2011-01-01 | 2026-06-01 | 9.790 | PERCENT | Preliminar (55) | Tasas y saldos de tarjetas/consumo/sobregiros (módulo B: resultado y placebo) |
| `fi_3_2_*` | 55 series: financial_indicators hoja 3.2 (detalle en diccionario_series.csv) | `financial_indicators` 3.2 | mensual | 2011-01-01 | 2026-06-01 | 9.790 | PERCENT | Preliminar (55) | Tasas y saldos de tarjetas/consumo/sobregiros (módulo B: resultado y placebo) |
| `fi_4_*` | 24 series: financial_indicators hoja 4 (detalle en diccionario_series.csv) | `financial_indicators` 4 | mensual | 2011-01-01 | 2026-06-01 | 4.464 | UNRESOLVED_SOURCE_UNITS/PYG | Preliminar (24) | Tasas y saldos de tarjetas/consumo/sobregiros (módulo B: resultado y placebo) |
| `fi_5_*` | 4 series: financial_indicators hoja 5 (detalle en diccionario_series.csv) | `financial_indicators` 5 | mensual | 2011-01-01 | 2026-06-01 | 744 | PERCENT | Preliminar (4) | Tasas y saldos de tarjetas/consumo/sobregiros (módulo B: resultado y placebo) |
| `fi_6_*` | 9 series: financial_indicators hoja 6 (detalle en diccionario_series.csv) | `financial_indicators` 6 | mensual | 2011-01-01 | 2026-06-01 | 1.283 | PERCENT | Preliminar (9) | Tasas y saldos de tarjetas/consumo/sobregiros (módulo B: resultado y placebo) |
| `fi_7_*` | 24 series: financial_indicators hoja 7 (detalle en diccionario_series.csv) | `financial_indicators` 7 | mensual | 2011-01-01 | 2026-06-01 | 4.440 | UNRESOLVED_SOURCE_UNITS/PYG | Preliminar (24) | Tasas y saldos de tarjetas/consumo/sobregiros (módulo B: resultado y placebo) |

### Paneles y datos manuales

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `panel_eeff_regulacion_entidad_mes.csv` | Caja, **encaje y cuenta corriente en el BCP**, IRM, valores, colocaciones, depósitos por tipo, capital, ingresos y egresos financieros, por entidad y moneda | 2016-01-01 a 2026-07-01, 115.341 filas | Panel provisional |
| `panel_tarjetas_credito_entidad_mes.csv` | Cantidad y saldo de tarjetas de crédito por entidad | 2016-01-01 a 2026-07-01, 5.982 filas | Panel provisional |
| `panel_carteras_entidad_mes.csv` | Cartera por tipo (incluye tarjetas de crédito) y depósitos por tipo | 2016-01-01 a 2026-07-01, 75.618 filas | Panel provisional |
| `panel_credito_sector_entidad_mes.csv` | Cartera vigente y vencida por sector y moneda | 2016-01-01 a 2026-07-01, 66.073 filas | Panel provisional |
| `panel_ratios_entidad_mes.csv` | 40 ratios publicados por entidad | 2016-01-01 a 2026-07-01, 132.025 filas | Panel provisional |
| `datos_manuales/cambios_regulatorios.csv` | **Plantilla para completar**: fecha de vigencia y de anuncio, instrumento (encaje MN/ME, tope de tarjetas, etc.), moneda, plazo, valor anterior y nuevo, norma, fuente | vacía | Manual |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_mensual.csv` | 40.542 | 11 | 1994-01-01 | 2026-07-01 |
| `datos/series_mensual_ancho.csv` | 391 | 220 | 1994-01-01 | 2026-07-01 |
| `datos/diccionario_series.csv` | 219 | 13 | 1994-01-01 | 2012-09-01 |
| `datos/panel_eeff_regulacion_entidad_mes.csv` | 115.341 | 10 | 2016-01-01 | 2026-07-01 |
| `datos/panel_tarjetas_credito_entidad_mes.csv` | 5.982 | 7 | 2016-01-01 | 2026-07-01 |
| `datos/panel_carteras_entidad_mes.csv` | 75.618 | 8 | 2016-01-01 | 2026-07-01 |
| `datos/panel_credito_sector_entidad_mes.csv` | 66.073 | 9 | 2016-01-01 | 2026-07-01 |
| `datos/panel_ratios_entidad_mes.csv` | 132.025 | 7 | 2016-01-01 | 2026-07-01 |
| `datos/entidades.csv` | 29 | 4 | — | — |

## 4. Cómo se usarían los datos

- Crédito en moneda de origen (`Δlog`); los saldos ME del panel (código 6200) se convierten a USD con el tipo de cambio de fin de mes.
- Exposiciones congeladas en el mes previo al anuncio.
- Tasas en puntos porcentuales; en el módulo B, comparar niveles y dispersión (máx.−mín.) de las tasas de tarjetas.
- Errores estándar agrupados por banco (≈ 29 entidades: usar *wild bootstrap*).

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| **Fechas y valores de cada cambio de encaje** (por moneda y plazo) y del tope de tarjetas (norma, fórmula del tope) | Define el tratamiento | BCP – resoluciones del Directorio; Ley del tope de tarjetas (lo conseguirás mañana) |
| **Boletines de bancos anteriores a 2016** (2013–2015) | Período previo por banco para el DiD del tope de tarjetas | SIB – boletines históricos |
| Base encajable exacta por banco (depósitos por plazo residual) | Exposición precisa | SIB / BCP (encaje requerido y constituido por banco) |
| Tasas de tarjetas por banco | Resultado a nivel banco | SIB / BCP (tasas máximas y efectivas por entidad) |

## 6. Evaluación de viabilidad

**Media-alta (módulo A)**: panel banco × moneda × sector desde 2016 con encaje por banco; solo falta el calendario de cambios. **Media-baja (módulo B)**: el quiebre del tope se ve con claridad en octubre de 2015, pero los paneles por banco de la base empiezan en enero de 2016, **después** del tope; sin boletines anteriores solo es posible una serie de tiempo interrumpida del sistema.

## 7. Supuestos que debes revisar

1. **Fecha del tope de tarjetas:** inferida de los datos (octubre de 2015); confirmar con la ley y su reglamentación.
2. Los cambios de encaje posteriores a 2016 (p. ej., medidas de 2020) son los únicos utilizables por banco; confirmar cuántos hubo.
3. La base encajable se aproxima con depósitos por tipo, no por plazo residual.
4. Tasas de tarjetas, consumo y sobregiros: promedios, máximos y mínimos del sistema (no por banco).

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Módulo A: encaje legal y oferta de crédito

| Referencia | Qué respalda en este proyecto |
|---|---|
| Dassatti Camors, C., Peydró, J.-L., Rodriguez-Tous, F. y Vicente, S. (2019). "Macroprudential and Monetary Policy: Loan-Level Evidence from Reserve Requirements." CEPR Discussion Paper 14224. **[DT]** | **Diseño más cercano, en Uruguay** (economía pequeña y dolarizada): diferencias en diferencias entre bancos afectados de forma distinta por un cambio del encaje, con datos préstamo-firma. Encuentra que el endurecimiento reduce la oferta de crédito. |
| Barroso, J. B. R. B., Gonzalez, R. B. y Van Doornik, B. F. N. (2017). "Credit Supply Responses to Reserve Requirement: Loan-Level Evidence from Macroprudential Policy." BIS Working Paper 674. **[DT]** | Brasil: exposición de cada banco a los cambios de encaje; los bancos más líquidos amortiguan el efecto y las reducciones pesan más que los aumentos. Respalda la medida de "liquidez liberada" y la asimetría. |
| Tovar, C. E., Garcia-Escribano, M. y Martin, M. V. (2012). "Credit Growth and the Effectiveness of Reserve Requirements and Other Macroprudential Instruments in Latin America." IMF Working Paper 12/142. **[DT]** | Evidencia regional con datos agregados. |
| Federico, P., Végh, C. A. y Vuletin, G. (2014). "Reserve Requirement Policy over the Business Cycle." NBER Working Paper 20612. **[DT]** | El encaje como instrumento contracíclico en países en desarrollo. Contexto del uso por el BCP. |
| Khwaja, A. I. y Mian, A. (2008). *American Economic Review*, 98(4), 1413–1442. **[Revista]** | Efectos fijos sector × moneda × mes para absorber la demanda. |

### 8.2 Módulo B: topes a las tasas

| Referencia | Qué respalda |
|---|---|
| Agarwal, S., Chomsisengphet, S., Mahoney, N. y Stroebel, J. (2015). "Regulating Consumer Financial Products: Evidence from Credit Cards." *Quarterly Journal of Economics*, 130(1), 111–164. **[Revista]** | Regulación de **tarjetas de crédito** (CARD Act) con comparación entre segmentos. Referencia de diseño para el DiD por banco. |
| Madeira, C. (2019). "The Impact of Interest Rate Ceilings on Households' Credit Access: Evidence from a 2013 Chilean Legislation." *Journal of Banking & Finance*, 106, 166–179. **[Revista]** | Chile: la reducción del tope excluyó a ≈ 10% de los deudores de consumo bancario. Anticipa el efecto sobre el **acceso**. |
| Cuesta, J. I. y Sepúlveda, A. "Price Regulation in Credit Markets: A Trade-off between Consumer Protection and Credit Access." SSRN 3282910. **[DT]** | Mismo episodio chileno: tasas −9%, préstamos −19%, pérdida de bienestar mayor para deudores riesgosos. |
| Maimbo, S. M. y Henriquez Gallegos, C. A. (2014). "Interest Rate Caps around the World: Still Popular, but a Blunt Instrument." World Bank Policy Research Working Paper 7070. **[DT]** | Revisión internacional de los topes y sus efectos. |

### 8.3 Métodos

- Callaway, B. y Sant'Anna, P. H. C. (2021). "Difference-in-Differences with Multiple Time Periods." *Journal of Econometrics*, 225(2), 200–230. **[Revista]** Cambios de encaje escalonados y efectos heterogéneos.

### 8.4 Antecedentes para Paraguay

- **[PY]** **Ley N.º 5476/2015**, "que establece normas de transparencia y defensa al usuario en la utilización de tarjetas de crédito y débito", vigente desde el **25 de septiembre de 2015**. El tope es tres veces la tasa pasiva promedio y el BCP publica el límite mensual. Esto confirma el quiebre de octubre de 2015 observado en los datos.
- **[PY]** Hay un artículo sobre los "Efectos de la Ley 5476/15 en el comportamiento de compra y uso de la tarjeta de crédito en Asunción y Gran Asunción", en la *Revista Científica Empresarial Mba'apoha* (UEP). No pude abrir el texto; parece un estudio de encuesta a usuarios.
