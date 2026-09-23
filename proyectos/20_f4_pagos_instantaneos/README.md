# 20 · F4 — Pagos instantáneos, competencia y movilidad de depósitos

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 20:05:00 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

## 1. Resumen y pregunta de investigación

El volumen agregado del Sistema de Pagos Instantáneos (SPI, operativo desde mayo de 2022) no muestra la adopción por cliente, la movilidad de depósitos ni las externalidades de red. La ficha pide tratarlo como **piloto de monitoreo**, sin inferir estrés a partir del crecimiento normal.

- **Pregunta:** ¿la adopción y la participación en el SPI alteran el uso de efectivo, la movilidad de depósitos, la competencia entre entidades y la gestión intradía de reservas?
- **Estimando (factible):** descripción de la adopción agregada y por entidad (alias registrados/operativos, montos SPI por entidad), sustitución entre rieles (SPI vs. ACH, LBTR, cheques, tarjetas) y asociación con el efectivo y los depósitos transaccionales.
- **Estimando (no factible con estos datos):** efecto causal del acceso o la adopción en resultados de cliente o entidad; requiere rollout exógeno o datos cliente-día.

## 2. Estrategia empírica propuesta

1. **Tablero de monitoreo mensual (2022-05 → 2026):** operaciones e importes SPI (totales, por día, franja horaria y funcionalidad), alias registrados y operativos por entidad, participantes vía servicio patrocinador.
2. **Sustitución entre rieles:** descomposición de la participación de cada riel (SPI, ACH, LBTR cliente-cliente, cheques compensados, tarjetas de débito/crédito/prepagas) en el valor y el número de pagos; event study alrededor del lanzamiento del SPI (2022-05) y de nuevas funcionalidades (QR, iniciadores de pago).
3. **Efectivo y depósitos:** relación entre la adopción del SPI y la demanda de efectivo (M0/M1) y los depósitos a la vista por entidad (panel), con controles de ciclo y TPM.
4. **Competencia:** concentración (HHI) de los alias operativos por entidad frente a la cuota de depósitos a la vista; cambios en canales físicos (cajeros, corresponsales) por entidad.

## 3. Series extraídas

Boletín de sistemas de pago completo (38 hojas), bancarización y agregados monetarios.

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `billetes_monedas` | M0: billetes y monedas en circulación | `economic_annex` CUADRO 21 | mensual | 1995-01-01 | 2026-06-01 | 378 | PYG (millones) | Preliminar | Uso de efectivo (resultado) |
| `base_monetaria` | Base monetaria | `economic_annex` CUADRO 21 | mensual | 1995-01-01 | 2026-06-01 | 378 | PYG (millones) | Preliminar | Control |
| `m1` | M1 | `economic_annex` CUADRO 21 | mensual | 1995-01-01 | 2026-06-01 | 378 | PYG (millones) | Preliminar | Depósitos transaccionales (resultado) |
| `m2` | M2 | `economic_annex` CUADRO 21 | mensual | 1995-01-01 | 2026-06-01 | 378 | PYG (millones) | Preliminar | Control |
| `dep_priv_mn_ctacte` | Depósitos privados MN en cuenta corriente | `economic_annex` CUADRO 23a | mensual | 1995-03-01 | 2026-06-01 | 370 | PYG (millones) | Preliminar | Depósitos transaccionales |
| `dep_priv_mn_vista` | Depósitos privados MN a la vista | `economic_annex` CUADRO 23a | mensual | 1995-03-01 | 2026-06-01 | 370 | PYG (millones) | Preliminar | Depósitos transaccionales |
| `tpm` | Tasa de política monetaria | `economic_annex` CUADRO 19  | mensual | 2011-05-01 | 2026-07-01 | 183 | PERCENT | Preliminar | Control (costo de oportunidad del efectivo) |
| `ipc_indice` | IPC índice general | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Deflactor |
| `bancariz_1_1_*` | 12 series: banking_indicators hoja 1 (detalle en diccionario_series.csv) | `banking_indicators` 1 | mensual | 2016-01-01 | 2026-06-01 | 1.512 | COUNT | Preliminar (12) | Bancarización (personas y cuentas) |
| `bancariz_2_2_*` | 3 series: banking_indicators hoja 2 (detalle en diccionario_series.csv) | `banking_indicators` 2 | mensual | 2016-01-01 | 2026-06-01 | 378 | UNRESOLVED_SOURCE_UNITS | Preliminar (3) | Bancarización (personas y cuentas) |
| `bancariz_3_3_*` | 6 series: banking_indicators hoja 3 (detalle en diccionario_series.csv) | `banking_indicators` 3 | mensual | 2016-01-01 | 2026-06-01 | 756 | COUNT/UNRESOLVED_SOURCE_UNITS | Preliminar (6) | Bancarización (personas y cuentas) |
| `bancariz_4_4_*` | 6 series: banking_indicators hoja 4 (detalle en diccionario_series.csv) | `banking_indicators` 4 | mensual | 2016-01-01 | 2026-06-01 | 756 | COUNT/UNRESOLVED_SOURCE_UNITS | Preliminar (6) | Bancarización (personas y cuentas) |
| `bancariz_5_5_*` | 3 series: banking_indicators hoja 5 (detalle en diccionario_series.csv) | `banking_indicators` 5 | mensual | 2016-01-01 | 2026-06-01 | 378 | UNRESOLVED_SOURCE_UNITS | Preliminar (3) | Bancarización (personas y cuentas) |
| `bancariz_6_6_*` | 6 series: banking_indicators hoja 6 (detalle en diccionario_series.csv) | `banking_indicators` 6 | mensual | 2016-01-01 | 2026-06-01 | 756 | UNRESOLVED_SOURCE_UNITS | Preliminar (6) | Bancarización (personas y cuentas) |
| `bancariz_7_7_*` | 3 series: banking_indicators hoja 7 (detalle en diccionario_series.csv) | `banking_indicators` 7 | mensual | 2016-01-01 | 2026-06-01 | 378 | COUNT/UNRESOLVED_SOURCE_UNITS | Preliminar (3) | Bancarización (personas y cuentas) |
| `pag_afd_01_*` | 1 series: payments hoja AFD 01 (detalle en diccionario_series.csv) | `payments` AFD 01 | mensual | 2014-06-01 | 2026-07-01 | 108 | PYG | Preliminar (1) | Sistemas de pago: hoja AFD 01 |
| `pag_afd_02_*` | 5 series: payments hoja AFD 02 (detalle en diccionario_series.csv) | `payments` AFD 02 | mensual | 2013-11-01 | 2026-07-01 | 765 | COUNT/PYG | No comprobada (4); Preliminar (1) | Sistemas de pago: hoja AFD 02 |
| `pag_afd_03_*` | 5 series: payments hoja AFD 03 (detalle en diccionario_series.csv) | `payments` AFD 03 | mensual | 2013-11-01 | 2026-07-01 | 423 | COUNT/PYG | No comprobada (4); Preliminar (1) | Sistemas de pago: hoja AFD 03 |
| `pag_afd_04_*` | 2 series: payments hoja AFD 04 (detalle en diccionario_series.csv) | `payments` AFD 04 | mensual | 2013-11-01 | 2026-07-01 | 306 | COUNT/UNRESOLVED_SOURCE_UNITS | Preliminar (2) | Sistemas de pago: hoja AFD 04 |
| `pag_afd_05_*` | 2 series: payments hoja AFD 05 (detalle en diccionario_series.csv) | `payments` AFD 05 | mensual | 2013-11-01 | 2026-07-01 | 306 | COUNT/USD | Preliminar (2) | Sistemas de pago: hoja AFD 05 |
| `pag_ccc_01_*` | 6 series: payments hoja CCC 01 (detalle en diccionario_series.csv) | `payments` CCC 01 | mensual | 2013-11-01 | 2026-07-01 | 918 | PYG | No comprobada (6) | Sistemas de pago: hoja CCC 01 |
| `pag_ccc_02_*` | 42 series: payments hoja CCC 02 (detalle en diccionario_series.csv) | `payments` CCC 02 | mensual | 2013-11-01 | 2026-07-01 | 5.086 | COUNT/UNRESOLVED_SOURCE_UNITS | No comprobada (2); Preliminar (40) | Sistemas de pago: hoja CCC 02 |
| `pag_ccc_03_*` | 14 series: payments hoja CCC 03 (detalle en diccionario_series.csv) | `payments` CCC 03 | mensual | 2013-11-01 | 2026-07-01 | 2.142 | COUNT/UNRESOLVED_SOURCE_UNITS | Preliminar (14) | Sistemas de pago: hoja CCC 03 |
| `pag_ccc_04_*` | 24 series: payments hoja CCC 04 (detalle en diccionario_series.csv) | `payments` CCC 04 | mensual | 2013-11-01 | 2026-07-01 | 3.574 | COUNT/UNRESOLVED_SOURCE_UNITS | Preliminar (24) | Sistemas de pago: hoja CCC 04 |
| `pag_cccoop_cccoop_*` | 10 series: payments hoja CCCoop (detalle en diccionario_series.csv) | `payments` CCCoop | mensual | 2021-12-01 | 2026-07-01 | 560 | COUNT/PYG | Preliminar (10) | Sistemas de pago: hoja CCCoop |
| `pag_cce_cce_*` | 2 series: payments hoja CCE (detalle en diccionario_series.csv) | `payments` CCE | mensual | 2020-10-01 | 2026-07-01 | 140 | PYG | Preliminar (2) | Sistemas de pago: hoja CCE |
| `pag_miha_01_*` | 1 series: payments hoja MIHA 01 (detalle en diccionario_series.csv) | `payments` MIHA 01 | mensual | 2013-11-01 | 2026-07-01 | 153 | PYG | Preliminar (1) | Sistemas de pago: hoja MIHA 01 |
| `pag_miha_02_*` | 5 series: payments hoja MIHA 02 (detalle en diccionario_series.csv) | `payments` MIHA 02 | mensual | 2013-11-01 | 2026-07-01 | 765 | COUNT/PYG | No comprobada (4); Preliminar (1) | Sistemas de pago: hoja MIHA 02 |
| `pag_miha_03_*` | 5 series: payments hoja MIHA 03 (detalle en diccionario_series.csv) | `payments` MIHA 03 | mensual | 2013-11-01 | 2026-07-01 | 765 | COUNT/PYG | No comprobada (4); Preliminar (1) | Sistemas de pago: hoja MIHA 03 |
| `pag_miha_04_*` | 3 series: payments hoja MIHA 04 (detalle en diccionario_series.csv) | `payments` MIHA 04 | mensual | 2013-11-01 | 2026-07-01 | 459 | COUNT/USD | Preliminar (3) | Sistemas de pago: hoja MIHA 04 |
| `pag_miha_05_*` | 3 series: payments hoja MIHA 05 (detalle en diccionario_series.csv) | `payments` MIHA 05 | mensual | 2013-11-01 | 2026-07-01 | 459 | COUNT/USD | Preliminar (3) | Sistemas de pago: hoja MIHA 05 |
| `pag_omp_01_*` | 14 series: payments hoja OMP 01 (detalle en diccionario_series.csv) | `payments` OMP 01 | mensual | 2018-01-01 | 2026-07-01 | 1.268 | COUNT/UNRESOLVED_SOURCE_UNITS | Preliminar (14) | Sistemas de pago: hoja OMP 01 |
| `pag_omp_01_02_*` | 14 series: payments hoja OMP 01_02 (detalle en diccionario_series.csv) | `payments` OMP 01_02 | mensual | 2024-01-01 | 2026-07-01 | 434 | COUNT/UNRESOLVED_SOURCE_UNITS | Preliminar (14) | Sistemas de pago: hoja OMP 01_02 |
| `pag_omp_02_*` | 12 series: payments hoja OMP 02 (detalle en diccionario_series.csv) | `payments` OMP 02 | mensual | 2018-01-01 | 2026-07-01 | 1.062 | COUNT/UNRESOLVED_SOURCE_UNITS | Preliminar (12) | Sistemas de pago: hoja OMP 02 |
| `pag_omp_02_02_*` | 14 series: payments hoja OMP 02_02 (detalle en diccionario_series.csv) | `payments` OMP 02_02 | mensual | 2024-01-01 | 2026-07-01 | 434 | COUNT/UNRESOLVED_SOURCE_UNITS | Preliminar (14) | Sistemas de pago: hoja OMP 02_02 |
| `pag_omp_03_*` | 12 series: payments hoja OMP 03 (detalle en diccionario_series.csv) | `payments` OMP 03 | mensual | 2018-01-01 | 2026-07-01 | 1.066 | COUNT/UNRESOLVED_SOURCE_UNITS | Preliminar (12) | Sistemas de pago: hoja OMP 03 |
| `pag_omp_03_02_*` | 14 series: payments hoja OMP 03_02 (detalle en diccionario_series.csv) | `payments` OMP 03_02 | mensual | 2024-01-01 | 2026-07-01 | 434 | COUNT/UNRESOLVED_SOURCE_UNITS | Preliminar (14) | Sistemas de pago: hoja OMP 03_02 |
| `pag_omp_04_*` | 21 series: payments hoja OMP 04 (detalle en diccionario_series.csv) | `payments` OMP 04 | mensual | 2018-01-01 | 2026-07-01 | 1.660 | COUNT/UNRESOLVED_SOURCE_UNITS | Preliminar (21) | Sistemas de pago: hoja OMP 04 |
| `pag_sipap_01_*` | 6 series: payments hoja SIPAP_01 (detalle en diccionario_series.csv) | `payments` SIPAP_01 | mensual | 2013-11-01 | 2026-07-01 | 700 | COUNT/EUR/PYG/USD | Preliminar (6) | Sistemas de pago: hoja SIPAP_01 |
| `pag_sipap_02_*` | 6 series: payments hoja SIPAP_02 (detalle en diccionario_series.csv) | `payments` SIPAP_02 | mensual | 2013-11-01 | 2026-07-01 | 908 | COUNT/EUR/PYG/USD | Preliminar (6) | Sistemas de pago: hoja SIPAP_02 |
| `pag_sipap_03_*` | 16 series: payments hoja SIPAP_03 (detalle en diccionario_series.csv) | `payments` SIPAP_03 | mensual | 2021-10-01 | 2026-07-01 | 924 | COUNT/PYG/USD/UNRESOLVED_SOURCE_UNITS | Preliminar (16) | Sistemas de pago: hoja SIPAP_03 |
| `pag_sipap_04_*` | 74 series: payments hoja SIPAP_04 (detalle en diccionario_series.csv) | `payments` SIPAP_04 | mensual | 2013-11-01 | 2026-07-01 | 8.088 | COUNT/EUR/PYG/USD (units/millions) | Preliminar (74) | Sistemas de pago: hoja SIPAP_04 |
| `pag_sipap_05_*` | 73 series: payments hoja SIPAP_05 (detalle en diccionario_series.csv) | `payments` SIPAP_05 | mensual | 2013-11-01 | 2026-07-01 | 9.745 | EUR/PYG/USD | Preliminar (73) | Sistemas de pago: hoja SIPAP_05 |
| `pag_sipap_06_*` | 3 series: payments hoja SIPAP_06 (detalle en diccionario_series.csv) | `payments` SIPAP_06 | mensual | 2013-11-01 | 2026-07-01 | 459 | COUNT/PYG | Preliminar (3) | Sistemas de pago: hoja SIPAP_06 |
| `pag_sipap_07_*` | 2 series: payments hoja SIPAP_07 (detalle en diccionario_series.csv) | `payments` SIPAP_07 | mensual | 2022-05-01 | 2026-07-01 | 102 | PYG | Preliminar (2) | Sistemas de pago: hoja SIPAP_07 |
| `pag_sipap_08_*` | 55 series: payments hoja SIPAP_08 (detalle en diccionario_series.csv) | `payments` SIPAP_08 | mensual | 2022-05-01 | 2026-07-01 | 2.773 | PYG | No comprobada (52); Preliminar (3) | Sistemas de pago: hoja SIPAP_08 |
| `pag_sipap_09_*` | 16 series: payments hoja SIPAP_09 (detalle en diccionario_series.csv) | `payments` SIPAP_09 | mensual | 2022-05-01 | 2026-07-01 | 816 | PYG | Preliminar (16) | Sistemas de pago: hoja SIPAP_09 |
| `pag_sipap_10_*` | 24 series: payments hoja SIPAP_10 (detalle en diccionario_series.csv) | `payments` SIPAP_10 | mensual | 2022-05-01 | 2026-07-01 | 1.224 | PYG | Preliminar (24) | Sistemas de pago: hoja SIPAP_10 |
| `pag_sipap_11_*` | 8 series: payments hoja SIPAP_11 (detalle en diccionario_series.csv) | `payments` SIPAP_11 | mensual | 2023-07-01 | 2026-07-01 | 292 | COUNT/UNRESOLVED_SOURCE_UNITS | Preliminar (8) | Sistemas de pago: hoja SIPAP_11 |
| `pag_sipap_12_*` | 18 series: payments hoja SIPAP_12 (detalle en diccionario_series.csv) | `payments` SIPAP_12 | mensual | 2022-05-01 | 2026-07-01 | 590 | COUNT/UNRESOLVED_SOURCE_UNITS | No comprobada (2); Preliminar (16) | Sistemas de pago: hoja SIPAP_12 |
| `pag_sipap_13_*` | 7 series: payments hoja SIPAP_13 (detalle en diccionario_series.csv) | `payments` SIPAP_13 | mensual | 2023-08-01 | 2026-07-01 | 220 | UNRESOLVED_SOURCE_UNITS | Preliminar (7) | Sistemas de pago: hoja SIPAP_13 |
| `pag_sipap_14_*` | 24 series: payments hoja SIPAP_14 (detalle en diccionario_series.csv) | `payments` SIPAP_14 | mensual | 2023-01-01 | 2026-07-01 | 854 | UNRESOLVED_SOURCE_UNITS | Preliminar (24) | Sistemas de pago: hoja SIPAP_14 |
| `pag_sipap_15_*` | 24 series: payments hoja SIPAP_15 (detalle en diccionario_series.csv) | `payments` SIPAP_15 | mensual | 2023-01-01 | 2026-07-01 | 848 | UNRESOLVED_SOURCE_UNITS | Preliminar (24) | Sistemas de pago: hoja SIPAP_15 |

### Paneles por entidad

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `panel_depositos_entidad_mes.csv` | Depósitos por tipo (vista, cuenta corriente, plazo fijo, CDA) × moneda × entidad (millones de Gs.) | 2016-01-01 a 2026-07-01, 26.130 filas | Panel provisional |
| `panel_canales_personal_entidad_mes.csv` | Cajeros automáticos, dependencias, terminales de autoservicio, corresponsales no bancarios y personal por entidad | 2016-01-01 a 2026-07-01, 20.505 filas | Panel provisional |
| `panel_tarjetas_credito_entidad_mes.csv` | Tarjetas de crédito: cantidad y saldo por entidad | 2016-01-01 a 2026-07-01, 5.982 filas | Panel provisional |
| `entidades.csv` | `entity_id` → nombre y tipo de propiedad | 29 entidades | Referencia |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_mensual.csv` | 59.559 | 11 | 1994-12-01 | 2026-07-01 |
| `datos/series_mensual_ancho.csv` | 380 | 635 | 1994-12-01 | 2026-07-01 |
| `datos/diccionario_series.csv` | 634 | 13 | 1994-12-01 | 2026-07-01 |
| `datos/panel_depositos_entidad_mes.csv` | 26.130 | 9 | 2016-01-01 | 2026-07-01 |
| `datos/panel_canales_personal_entidad_mes.csv` | 20.505 | 8 | 2016-01-01 | 2026-07-01 |
| `datos/panel_tarjetas_credito_entidad_mes.csv` | 5.982 | 7 | 2016-01-01 | 2026-07-01 |
| `datos/entidades.csv` | 29 | 4 | — | — |

## 4. Cómo se usarían los datos

- **Nombres:** las series se nombran `pag_<hoja>_<etiqueta>`; el mapa completo hoja → descripción está en `diccionario_series.csv`. En `SIPAP_07` las etiquetas vienen vacías en la base: `column_3` = cantidad de operaciones y `column_4` = importe en Gs. (identificados por magnitud).
- **Transformaciones:** `log` de cantidades e importes; importes en PYG deflactados por el IPC; participaciones por riel sobre el total de pagos electrónicos; variaciones interanuales por la estacionalidad (diciembre).
- **Entidades:** los montos SPI por entidad (`SIPAP_08`) son **no comprobados** (identidad posicional); verificar el orden de entidades contra el Excel antes de unirlos a los paneles. Los alias por entidad (`SIPAP_14`, `SIPAP_15`) sí son preliminares.
- **Muestra:** el SPI tiene ~50 observaciones mensuales; cualquier regresión es exploratoria.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Transacciones SPI por entidad-día (y remitente-receptor anonimizado) | Movilidad de depósitos y estrés; nivel "suficiente/óptimo" | BCP – Sistemas de Pago (SIPAP) |
| Fechas de incorporación de cada entidad, límites, horarios y precios del SPI | Variación de rollout para un event study | BCP – normativa y comunicados del SPI |
| Adopción por cliente/comercio (QR), ubicación | Externalidades de red | BCP; entidades participantes; Bancard |
| Saldos intradía de reservas | Liquidez intradía (vínculo con A1) | BCP – LBTR |
| Retiros de efectivo en cajeros por entidad | Sustitución de efectivo | Bancard / Infonet; SIB |

## 6. Evaluación de viabilidad

**Media como piloto de monitoreo**: el boletín de pagos ofrece el SPI desde 2022-05 con desagregaciones por día, horario, funcionalidad y entidad, además de todos los rieles alternativos desde 2013 y los paneles de depósitos y canales. **Baja para inferencia causal**: no hay datos cliente o entidad-día ni una variación de rollout documentada.

## 7. Supuestos que debes revisar

1. `pag_sipap_07_*_column_3/column_4` = cantidad e importe del SPI (inferido por magnitud; la base no tiene etiqueta).
2. Varias series de montos del boletín tienen unidad no resuelta; las leo como guaraníes (o USD/EUR según la hoja).
3. Las series por entidad del boletín identifican a la entidad por posición en la hoja; no las uní con los códigos SIB.
4. El SPI comenzó en mayo de 2022; valores anteriores de SIPAP_07 a SIPAP_12 no existen (no son ceros).

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Pagos instantáneos y bancos

| Referencia | Qué respalda en este proyecto |
|---|---|
| Duarte, A., Frost, J., Gambacorta, L., Koo Wilkens, P. y Shin, H. S. (2022). "Central Banks, the Monetary System and Public Payment Infrastructures: Lessons from Brazil's Pix." BIS Bulletin 52. **[DT]** | Descripción de la adopción de Pix y de sus efectos en competencia e inclusión. Es el **modelo de tablero** (paso 1) y el caso regional más comparable. |
| Sarkisyan, S. "Instant Payment Systems and Competition for Deposits." SSRN 4176990. **[DT]** | Con variación por municipio en la exposición a Pix, encuentra que los **depósitos de bancos pequeños crecen frente a los grandes**. Respalda la pregunta de competencia (paso 4, HHI de alias frente a cuota de depósitos) y muestra qué datos harían falta para una versión causal. |

### 8.2 Adopción, externalidades de red y efectivo

| Referencia | Qué respalda |
|---|---|
| Higgins, S. (2024). "Financial Technology Adoption: Network Externalities of Cashless Payments in Mexico." *American Economic Review*, 114(11), 3469–3512. **[Revista]** | Externalidades de red en la adopción de pagos electrónicos, con un despliegue escalonado como fuente de variación. Muestra el tipo de rollout que la ficha pide para identificar. |
| Crouzet, N., Gupta, A. y Mezzanotti, F. (2023). "Shocks and Technology Adoption: Evidence from Electronic Payment Systems." *Journal of Political Economy*, 131(11), 3003–3065. **[Revista]** | Complementariedades en la adopción de billeteras tras la desmonetización india. Respalda medir la adopción como fenómeno de red (alias operativos por entidad). |
| Chodorow-Reich, G., Gopinath, G., Mishra, P. y Narayanan, A. (2020). "Cash and the Economy: Evidence from India's Demonetization." *Quarterly Journal of Economics*, 135(1), 57–103. **[Revista]** | Relación entre efectivo, pagos electrónicos y actividad. Respalda la relación SPI–M0 (paso 3). |
| Alvarez, F. y Lippi, F. (2009). "Financial Innovation and the Transactions Demand for Cash." *Econometrica*, 77(2), 363–402. **[Revista]** | Modelo de demanda de efectivo con innovación financiera. Respalda la especificación de la demanda de M0/M1 con tasa, actividad y tecnología de pagos. |
| Jack, W. y Suri, T. (2014). "Risk Sharing and Transactions Costs: Evidence from Kenya's Mobile Money Revolution." *American Economic Review*, 104(1), 183–223. **[Revista]** | Referencia clásica de efectos de una tecnología de pagos con variación geográfica en el acceso. Útil para la brecha "datos cliente-día o por localidad". |

### 8.3 Antecedentes para Paraguay

No encontré evaluaciones académicas del SPI. Según cifras del BCP difundidas por la prensa, el SPI procesó pagos por ≈ 5% del PIB en 2022, 14% en 2023 y 24% en 2024, y concentra más del 97% de las transacciones del SIPAP. El proyecto sería la **primera descripción sistemática**, pero sin variación exógena queda como monitoreo, igual que Duarte et al. (2022) para Pix.
