# 28 · N7 (proyecto nuevo) — Medidas de alivio COVID, reprogramaciones y mora posterior

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 20:41:52 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

> **Proyecto nuevo con potencial causal moderado.** La base publica, por banco, la cartera acogida a la "Medida Excepcional COVID" (vigente y vencida), lo que permite estudiar si las reprogramaciones masivas de 2020 postergaron o evitaron la mora, y a qué costo para el crédito nuevo.

## 1. Resumen y pregunta de investigación

- **Pregunta:** ¿los bancos que reprogramaron una mayor proporción de su cartera en 2020 tuvieron luego más mora, más reestructuraciones y menos crédito nuevo, o las medidas funcionaron como puente de liquidez?
- **Estimando:** efecto de la intensidad de uso de la medida (cartera COVID / cartera total en jun–dic 2020) sobre la mora, las reprogramaciones y el crecimiento del crédito en 2021–2024.
- **Evidencia:** forma reducida con **selección**: los bancos con clientes más frágiles reprogramaron más. Se mitiga con exposición sectorial previa (2019) como instrumento o control.

## 2. Estrategia empírica propuesta

1. **Hechos:** la cartera COVID vigente llega a ≈ 20 billones de Gs. en diciembre de 2020 (≈ 11% del crédito) en 23 entidades; su parte vencida sube a ≈ 1,4 billones en 2022 y se reduce después. Describir la trayectoria por banco y moneda.
2. **Intensidad predeterminada:** participación de la cartera COVID en dic-2020; instrumentada por la exposición sectorial de 2019 (comercio, servicios, consumo, más afectados por el confinamiento) para separar la fragilidad de los clientes de la política del banco.
3. **Event study banco-mes (2016–2026):** `y_{b,t} = Σ_k β_k · intensidad_b · 1[t = k] + FE_b + FE_t + ε`, con resultados: mora total y por sector, categorías de riesgo 3–6, refinanciados/reestructurados/renovados, previsiones, crecimiento del crédito vigente.
4. **Pre-tendencias** 2016–2019 y placebo con financieras vs. bancos.

## 3. Series extraídas

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `imaep_original` | IMAEP serie original | `economic_annex` CUADRO 9 | mensual | 1994-01-01 | 2026-06-01 | 390 | INDEX | Preliminar | Shock agregado (COVID) |
| `imaep9a_desest` | IMAEP serie ajustada | `economic_annex` CUADRO 9 a | mensual | 2014-01-01 | 2026-06-01 | 150 | INDEX | Validada por regla | Shock agregado |
| `tpm` | Tasa de política monetaria | `economic_annex` CUADRO 19  | mensual | 2011-05-01 | 2026-07-01 | 183 | PERCENT | Preliminar | Control (política simultánea) |
| `cred_priv_mn` | Crédito privado MN (agregado) | `economic_annex` CUADRO 24a | mensual | 1995-03-01 | 2026-06-01 | 370 | PYG (millones) | Preliminar | Resultado agregado |
| `cred_priv_me_usd` | Crédito privado ME en millones de USD | `economic_annex` CUADRO 24a | mensual | 1995-03-01 | 2026-06-01 | 370 | UNRESOLVED_SOURCE_UNITS (millones) | Preliminar | Resultado agregado |
| `pyg_usd_prom_venta` | PYG por USD promedio mensual | `exchange_rates` USD Prom | mensual | 1989-01-01 | 2026-07-01 | 451 | PYG_PER_USD | Validada por regla | Conversión de cartera ME |

### Paneles y datos manuales

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `panel_carteras_entidad_mes.csv` | Cartera vigente, vencida, **Medida Excepcional COVID (vigente y vencida)**, medidas transitorias, refinanciados, reestructurados, renovados, por moneda | 2016-01-01 a 2026-07-01, 75.618 filas | Panel provisional |
| `panel_credito_sector_entidad_mes.csv` | Cartera vigente y vencida por sector y moneda | 2016-01-01 a 2026-07-01, 66.073 filas | Panel provisional |
| `panel_categoria_riesgo_entidad_mes.csv` | Cartera por categoría de riesgo (1, 1a, 1b, 2 a 6) | 2016-01-01 a 2026-07-01, 23.049 filas | Panel provisional |
| `panel_ratios_entidad_mes.csv` | 40 ratios publicados (morosidad, RRR/cartera, previsiones, capital) | 2016-01-01 a 2026-07-01, 132.025 filas | Panel provisional |
| `panel_eeff_riesgo_entidad_mes.csv` | Colocaciones, productos financieros, depósitos, patrimonio y previsiones | 2016-01-01 a 2026-07-01, 93.024 filas | Panel provisional |
| `datos_manuales/medidas_alivio.csv` | **Plantilla para completar**: resoluciones de medidas excepcionales y transitorias (vigencia, alcance, condiciones) | vacía | Manual |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_mensual.csv` | 1.914 | 11 | 1989-01-01 | 2026-07-01 |
| `datos/series_mensual_ancho.csv` | 451 | 7 | 1989-01-01 | 2026-07-01 |
| `datos/diccionario_series.csv` | 6 | 13 | 1989-01-01 | 2014-01-01 |
| `datos/panel_carteras_entidad_mes.csv` | 75.618 | 8 | 2016-01-01 | 2026-07-01 |
| `datos/panel_credito_sector_entidad_mes.csv` | 66.073 | 9 | 2016-01-01 | 2026-07-01 |
| `datos/panel_categoria_riesgo_entidad_mes.csv` | 23.049 | 7 | 2016-01-01 | 2026-07-01 |
| `datos/panel_ratios_entidad_mes.csv` | 132.025 | 7 | 2016-01-01 | 2026-07-01 |
| `datos/panel_eeff_riesgo_entidad_mes.csv` | 93.024 | 10 | 2016-01-01 | 2026-07-01 |
| `datos/entidades.csv` | 29 | 4 | — | — |

## 4. Cómo se usarían los datos

- Proporciones sobre la cartera total del banco y moneda; saldos ME convertidos a USD con el tipo de cambio de fin de mes.
- Intensidad congelada en diciembre de 2020; exposición sectorial congelada en diciembre de 2019.
- Errores estándar agrupados por banco con *wild bootstrap* (≈ 23 entidades tratadas).

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Resoluciones de medidas excepcionales y transitorias (fechas, plazos, condiciones) | Define el tratamiento y su duración | SIB/BCP (lo conseguirás mañana) |
| Préstamo-prestatario con marca de reprogramación | Comparar el mismo prestatario (causalidad fuerte) | Central de riesgos |
| Medidas de 2022–2024 por sequía o inundaciones | Tratamientos posteriores que contaminan el período | SIB |

## 6. Evaluación de viabilidad

**Media.** Los datos por banco son buenos (cartera COVID mensual 2020–2026 con período previo desde 2016), pero la selección de los bancos que más reprogramaron limita la causalidad; con exposición sectorial previa como instrumento se obtiene una estimación defendible, y con datos de prestatario sería alta.

## 7. Supuestos que debes revisar

1. La cuenta "Medida Excepcional COVID" del panel de carteras corresponde a las reprogramaciones bajo las medidas excepcionales del BCP de 2020; confirmar la definición con la SIB.
2. Los montos del panel están en millones de Gs. (verificado en C1).
3. El número de entidades con cartera COVID cae de 23 a 19 entre 2021 y 2024 (salidas o cancelaciones): revisar fusiones.

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Reprogramaciones y moratorias

| Referencia | Qué respalda en este proyecto |
|---|---|
| Önder, Y. K., Villamizar-Villegas, M. y Villegas, J. (2023). "Debt Moratorium: Theory and Evidence." Borradores de Economía 1253, Banco de la República (Colombia). **[DT]** | **Antecedente regional más cercano**: evalúa las moratorias de Colombia (incluida la de COVID) comparando firmas justo por debajo y por encima del criterio de elegibilidad (≤ 60 días de atraso). Las moratorias mejoran el crédito posterior pero elevan el riesgo de default. Muestra el diseño ideal (regresión discontinua) si se accede a datos de deudores. |
| Burga, C., Cuba, W., Díaz, E. y Sánchez, E. (2023). "Loan Guarantees and Bank Incentives: Evidence from Covid-19 Relief Funds in Peru." Documento de Trabajo 2023-001, BCRP. **[DT]** | Programa peruano de alivio (garantías): efectos sobre la mora y el reparto del crédito entre firmas. Comparación regional. |

### 8.2 El riesgo de "evergreening" (préstamos zombi)

| Referencia | Qué respalda |
|---|---|
| Peek, J. y Rosengren, E. S. (2005). "Unnatural Selection: Perverse Incentives and the Misallocation of Credit in Japan." *American Economic Review*, 95(4), 1144–1166. **[Revista]** | Los bancos débiles renuevan créditos a deudores débiles para no reconocer pérdidas. Es la hipótesis alternativa a "puente de liquidez". |
| Caballero, R. J., Hoshi, T. y Kashyap, A. K. (2008). "Zombie Lending and Depressed Restructuring in Japan." *American Economic Review*, 98(5), 1943–1977. **[Revista]** | Costos agregados de la tolerancia: menos crédito a firmas sanas. Respalda el resultado "crecimiento del crédito vigente". |
| Blattner, L., Farinha, L. y Rebelo, F. (2023). "When Losses Turn into Loans: The Cost of Weak Banks." *American Economic Review*, 113(6), 1600–1641. **[Revista]** | Bancos con poco capital posponen el reconocimiento de pérdidas. Respalda la heterogeneidad por capital del banco. |

### 8.3 Métodos

- Instrumento de exposición sectorial predeterminada (paso 2): Goldsmith-Pinkham, P., Sorkin, I. y Swift, H. (2020). "Bartik Instruments: What, When, Why, and How." *American Economic Review*, 110(8), 2586–2624; y Borusyak, K., Hull, P. y Jaravel, X. (2022). "Quasi-Experimental Shift-Share Research Designs." *Review of Economic Studies*, 89(1), 181–213. **[Revista]** Condiciones para que la exposición sectorial de 2019 sea un instrumento válido.

### 8.4 Antecedentes para Paraguay

No encontré evaluaciones publicadas de las medidas excepcionales del BCP de 2020. Las resoluciones de la medida (fechas, plazos, condiciones) deben cargarse en `datos_manuales/medidas_alivio.csv`.
