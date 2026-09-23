# 30 · N9 (proyecto nuevo) — SPI y demanda de efectivo: sustitución entre medios de pago

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 20:44:14 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

> **Proyecto nuevo, descriptivo.** Complementa el tablero de F4 con una pregunta concreta: ¿redujo el SPI el uso de efectivo y de cheques? **No tiene identificación causal limpia**: hay una sola fecha nacional de lanzamiento (mayo de 2022), sin grupo de control, y coincide con el ciclo de subas de tasas y la inflación alta de 2022.

## 1. Resumen y pregunta de investigación

- **Pregunta:** ¿cuánto sustituyó el SPI al efectivo (M0), a los cheques, a las transferencias ACH y a las tarjetas de débito, y cambió la composición de los depósitos transaccionales?
- **Estimando:** quiebre en la tendencia y en la participación de cada medio de pago tras 2022-05 y tras cada hito del SPI (alias, QR, iniciadores de pago).
- **Evidencia:** descriptiva/predictiva (serie de tiempo interrumpida con controles).

## 2. Estrategia empírica propuesta

1. **Participaciones por riel** (número e importe): SPI, ACH, LBTR cliente-cliente, cheques compensados, tarjetas de débito/crédito/prepagas; antes y después de 2022-05.
2. **Demanda de efectivo:** modelo de demanda de M0/M2 con TPM, inflación, IMAEP y estacionalidad, estimado hasta 2022-04 y proyectado fuera de muestra: la brecha entre lo observado y lo proyectado mide el cambio posterior (con bandas).
3. **Hitos:** cargar las fechas de alias, QR, iniciadores de pago y cambios de límites en `datos_manuales/hitos_spi.csv` y probar quiebres adicionales.
4. **Variación entre entidades (exploratoria):** cajeros y corresponsales por entidad (panel de canales) vs. adopción de alias por entidad (en la carpeta 20).

## 3. Series extraídas

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `billetes_monedas` | M0: billetes y monedas en circulación | `economic_annex` CUADRO 21 | mensual | 1995-01-01 | 2026-06-01 | 378 | PYG (millones) | Preliminar | Resultado principal: demanda de efectivo |
| `base_monetaria` | Base monetaria | `economic_annex` CUADRO 21 | mensual | 1995-01-01 | 2026-06-01 | 378 | PYG (millones) | Preliminar | Control |
| `m1` | M1 | `economic_annex` CUADRO 21 | mensual | 1995-01-01 | 2026-06-01 | 378 | PYG (millones) | Preliminar | Resultado: dinero transaccional |
| `m2` | M2 | `economic_annex` CUADRO 21 | mensual | 1995-01-01 | 2026-06-01 | 378 | PYG (millones) | Preliminar | Normalización (M0/M2) |
| `dep_priv_mn_ctacte` | Depósitos privados MN en cuenta corriente | `economic_annex` CUADRO 23a | mensual | 1995-03-01 | 2026-06-01 | 370 | PYG (millones) | Preliminar | Resultado: depósitos transaccionales |
| `dep_priv_mn_vista` | Depósitos privados MN a la vista | `economic_annex` CUADRO 23a | mensual | 1995-03-01 | 2026-06-01 | 370 | PYG (millones) | Preliminar | Resultado: depósitos transaccionales |
| `tpm` | Tasa de política monetaria | `economic_annex` CUADRO 19  | mensual | 2011-05-01 | 2026-07-01 | 183 | PERCENT | Preliminar | Control: costo de oportunidad del efectivo (2022 = ciclo de subas) |
| `ipc_indice` | IPC índice general | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Deflactor / control |
| `ipc_var_interanual` | Inflación interanual | `economic_annex` CUADRO 15 | mensual | 1993-12-01 | 2026-07-01 | 392 | PERCENT | Validada por regla | Control (inflación alta en 2022) |
| `imaep_original` | IMAEP serie original | `economic_annex` CUADRO 9 | mensual | 1994-01-01 | 2026-06-01 | 390 | INDEX | Preliminar | Control de transacciones |
| `pag_ccc_01_*` | 6 series: payments hoja CCC 01 (detalle en diccionario_series.csv) | `payments` CCC 01 | mensual | 2013-11-01 | 2026-07-01 | 918 | PYG | No comprobada (6) | Sistemas de pago: hoja CCC 01 |
| `pag_ccc_02_*` | 42 series: payments hoja CCC 02 (detalle en diccionario_series.csv) | `payments` CCC 02 | mensual | 2013-11-01 | 2026-07-01 | 5.086 | COUNT/UNRESOLVED_SOURCE_UNITS | No comprobada (2); Preliminar (40) | Sistemas de pago: hoja CCC 02 |
| `pag_ccc_03_*` | 14 series: payments hoja CCC 03 (detalle en diccionario_series.csv) | `payments` CCC 03 | mensual | 2013-11-01 | 2026-07-01 | 2.142 | COUNT/UNRESOLVED_SOURCE_UNITS | Preliminar (14) | Sistemas de pago: hoja CCC 03 |
| `pag_cccoop_cccoop_*` | 10 series: payments hoja CCCoop (detalle en diccionario_series.csv) | `payments` CCCoop | mensual | 2021-12-01 | 2026-07-01 | 560 | COUNT/PYG | Preliminar (10) | Sistemas de pago: hoja CCCoop |
| `pag_cce_cce_*` | 2 series: payments hoja CCE (detalle en diccionario_series.csv) | `payments` CCE | mensual | 2020-10-01 | 2026-07-01 | 140 | PYG | Preliminar (2) | Sistemas de pago: hoja CCE |
| `pag_omp_01_*` | 14 series: payments hoja OMP 01 (detalle en diccionario_series.csv) | `payments` OMP 01 | mensual | 2018-01-01 | 2026-07-01 | 1.268 | COUNT/UNRESOLVED_SOURCE_UNITS | Preliminar (14) | Sistemas de pago: hoja OMP 01 |
| `pag_omp_02_*` | 12 series: payments hoja OMP 02 (detalle en diccionario_series.csv) | `payments` OMP 02 | mensual | 2018-01-01 | 2026-07-01 | 1.062 | COUNT/UNRESOLVED_SOURCE_UNITS | Preliminar (12) | Sistemas de pago: hoja OMP 02 |
| `pag_omp_03_*` | 12 series: payments hoja OMP 03 (detalle en diccionario_series.csv) | `payments` OMP 03 | mensual | 2018-01-01 | 2026-07-01 | 1.066 | COUNT/UNRESOLVED_SOURCE_UNITS | Preliminar (12) | Sistemas de pago: hoja OMP 03 |
| `pag_omp_04_*` | 21 series: payments hoja OMP 04 (detalle en diccionario_series.csv) | `payments` OMP 04 | mensual | 2018-01-01 | 2026-07-01 | 1.660 | COUNT/UNRESOLVED_SOURCE_UNITS | Preliminar (21) | Sistemas de pago: hoja OMP 04 |
| `pag_sipap_01_*` | 6 series: payments hoja SIPAP_01 (detalle en diccionario_series.csv) | `payments` SIPAP_01 | mensual | 2013-11-01 | 2026-07-01 | 700 | COUNT/EUR/PYG/USD | Preliminar (6) | Sistemas de pago: hoja SIPAP_01 |
| `pag_sipap_02_*` | 6 series: payments hoja SIPAP_02 (detalle en diccionario_series.csv) | `payments` SIPAP_02 | mensual | 2013-11-01 | 2026-07-01 | 908 | COUNT/EUR/PYG/USD | Preliminar (6) | Sistemas de pago: hoja SIPAP_02 |
| `pag_sipap_06_*` | 3 series: payments hoja SIPAP_06 (detalle en diccionario_series.csv) | `payments` SIPAP_06 | mensual | 2013-11-01 | 2026-07-01 | 459 | COUNT/PYG | Preliminar (3) | Sistemas de pago: hoja SIPAP_06 |
| `pag_sipap_07_*` | 2 series: payments hoja SIPAP_07 (detalle en diccionario_series.csv) | `payments` SIPAP_07 | mensual | 2022-05-01 | 2026-07-01 | 102 | PYG | Preliminar (2) | Sistemas de pago: hoja SIPAP_07 |
| `pag_sipap_09_*` | 16 series: payments hoja SIPAP_09 (detalle en diccionario_series.csv) | `payments` SIPAP_09 | mensual | 2022-05-01 | 2026-07-01 | 816 | PYG | Preliminar (16) | Sistemas de pago: hoja SIPAP_09 |
| `pag_sipap_10_*` | 24 series: payments hoja SIPAP_10 (detalle en diccionario_series.csv) | `payments` SIPAP_10 | mensual | 2022-05-01 | 2026-07-01 | 1.224 | PYG | Preliminar (24) | Sistemas de pago: hoja SIPAP_10 |
| `pag_sipap_12_*` | 18 series: payments hoja SIPAP_12 (detalle en diccionario_series.csv) | `payments` SIPAP_12 | mensual | 2022-05-01 | 2026-07-01 | 590 | COUNT/UNRESOLVED_SOURCE_UNITS | No comprobada (2); Preliminar (16) | Sistemas de pago: hoja SIPAP_12 |
| `pag_sipap_13_*` | 7 series: payments hoja SIPAP_13 (detalle en diccionario_series.csv) | `payments` SIPAP_13 | mensual | 2023-08-01 | 2026-07-01 | 220 | UNRESOLVED_SOURCE_UNITS | Preliminar (7) | Sistemas de pago: hoja SIPAP_13 |

### Otros archivos

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `panel_canales_entidad_mes.csv` | Cajeros automáticos, dependencias, terminales de autoservicio y corresponsales no bancarios por entidad | 2016-01-01 a 2026-07-01, 20.505 filas | Panel provisional |
| `manual_hitos_spi.csv` | Copia de `datos_manuales/hitos_spi.csv` (1 hito inferido: inicio 2022-05, no verificado) | 2022-05-01 a 2022-05-01, 1 filas | Manual |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_mensual.csv` | 22.518 | 11 | 1993-12-01 | 2026-07-01 |
| `datos/series_mensual_ancho.csv` | 392 | 226 | 1993-12-01 | 2026-07-01 |
| `datos/diccionario_series.csv` | 225 | 13 | 1993-12-01 | 2026-07-01 |
| `datos/panel_canales_entidad_mes.csv` | 20.505 | 8 | 2016-01-01 | 2026-07-01 |
| `datos/manual_hitos_spi.csv` | 1 | 5 | 2022-05-01 | 2022-05-01 |

## 4. Cómo se usarían los datos

- M0 y depósitos en PYG deflactados por IPC; `log` y variación interanual; estacionalidad fuerte en diciembre.
- En `SIPAP_07`, `column_3` = cantidad y `column_4` = importe del SPI (etiquetas vacías en la base).
- Participaciones sobre el total de pagos electrónicos (suma de rieles).

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Fechas de hitos del SPI (entrada de entidades, QR, alias, límites) | Quiebres múltiples y variación entre entidades | BCP – normativa SPI (lo conseguirás mañana) |
| SPI por entidad-día | Variación de adopción entre bancos | BCP – SIPAP |
| Retiros de efectivo en cajeros | Uso directo del efectivo | Bancard / Infonet |

## 6. Evaluación de viabilidad

**Media como estudio descriptivo** (≈ 50 meses de SPI y todos los rieles desde 2013); **baja para causalidad** por la ausencia de grupo de control y la coincidencia con el ciclo monetario de 2022.

## 7. Supuestos que debes revisar

1. Inicio del SPI = 2022-05 (primer dato del boletín); confirmar la fecha oficial.
2. Las series por entidad del boletín de pagos se identifican por posición (ver carpeta 20).

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Pagos digitales y demanda de efectivo

| Referencia | Qué respalda en este proyecto |
|---|---|
| Alvarez, F. y Lippi, F. (2009). "Financial Innovation and the Transactions Demand for Cash." *Econometrica*, 77(2), 363–402. **[Revista]** | Demanda de efectivo con tecnología de pagos como determinante. Base de la especificación del paso 2. |
| Chodorow-Reich, G., Gopinath, G., Mishra, P. y Narayanan, A. (2020). "Cash and the Economy: Evidence from India's Demonetization." *Quarterly Journal of Economics*, 135(1), 57–103. **[Revista]** | Sustitución entre efectivo y pagos electrónicos ante un shock. |
| Crouzet, N., Gupta, A. y Mezzanotti, F. (2023). *Journal of Political Economy*, 131(11), 3003–3065. **[Revista]** | La adopción de pagos electrónicos es **persistente** por complementariedades. Respalda buscar quiebres de tendencia y no solo de nivel. |
| Duarte, A., Frost, J., Gambacorta, L., Koo Wilkens, P. y Shin, H. S. (2022). BIS Bulletin 52. **[DT]** | Caso Pix: adopción rápida y sustitución de otros rieles (TED, DOC, boletos). Comparación directa para el paso 1. |
| Sarkisyan, S. SSRN 4176990. **[DT]** | Efecto de Pix en los depósitos por tipo de banco. Referencia para la variación entre entidades del paso 4. |

### 8.2 Métodos para una serie de tiempo interrumpida

| Referencia | Uso |
|---|---|
| Brodersen, K. H., Gallusser, F., Koehler, J., Remy, N. y Scott, S. L. (2015). "Inferring Causal Impact Using Bayesian Structural Time-Series Models." *Annals of Applied Statistics*, 9(1), 247–274. **[Revista]** | Contrafactual proyectado con modelo estimado antes del lanzamiento y bandas de incertidumbre. Es exactamente el paso 2. |
| Bernal, J. L., Cummins, S. y Gasparrini, A. (2017). "Interrupted Time Series Regression for the Evaluation of Public Health Interventions: A Tutorial." *International Journal of Epidemiology*, 46(1), 348–355. **[Revista]** | Buenas prácticas y amenazas a la validez (eventos simultáneos como el ciclo de tasas de 2022). |

### 8.3 Antecedentes para Paraguay

No encontré evaluaciones académicas del SPI (ver carpeta 20). El limitante sigue siendo la falta de un grupo de control; la literatura con identificación creíble (Higgins, 2024; Sarkisyan) usa **variación geográfica** en la exposición, que en Paraguay requeriría datos por localidad.
