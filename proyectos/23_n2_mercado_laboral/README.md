# 23 · N2 (proyecto nuevo) — Mercado laboral, informalidad y ciclo

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 20:14:56 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

> **Proyecto no incluido en el portafolio original.** Lo propongo porque la base incorpora el anexo trimestral completo de la EPHC del INE (2017–2026: fuerza de trabajo, ocupación por sector, categoría, tamaño de empresa, formalidad, horas e ingresos), que casi ningún proyecto del portafolio usa, y porque el mercado laboral es el eslabón que falta entre la actividad (D1, N1) y la inflación (D4, F5).

## 1. Resumen y pregunta de investigación

Con ≈ 60% de informalidad entre los ocupados no agropecuarios (58–65% en 2017–2026 según la EPHC), el ajuste del mercado laboral paraguayo al ciclo puede darse más por **composición** (formal ↔ informal, horas, cuenta propia) que por desempleo. Eso cambia la lectura de la holgura de la economía para la política monetaria.

- **Preguntas:** (i) ¿cuál es la relación de Okun en Paraguay y por qué margen se ajusta el empleo (desocupación, subocupación, horas, informalidad)? (ii) ¿funciona la informalidad como amortiguador del ciclo? (iii) ¿hay una curva de Phillips de salarios o de precios con medidas de holgura que incluyan la subocupación?
- **Estimandos:** coeficiente de Okun por margen de ajuste; elasticidad de la tasa de informalidad al ciclo; pendiente de la curva de Phillips con distintas medidas de holgura.
- **Evidencia:** descriptiva y de forma reducida; muestra corta (38 trimestres), sin causalidad.

## 2. Estrategia empírica propuesta

1. **Hechos estilizados (2017T1–2026T2):** tasas de actividad, ocupación, desocupación y subocupación (total, urbana, rural); tasa de informalidad = 1 − ocupados formales / ocupados no agropecuarios; composición por categoría ocupacional, tamaño de empresa y sector.
2. **Okun por margen:** Δ desocupación, Δ subocupación, Δ horas promedio y Δ informalidad sobre el crecimiento del PIB/IMAEP (trimestral), con y sin 2020.
3. **Informalidad como amortiguador:** respuesta del empleo formal e informal y de los ingresos por categoría a caídas de actividad (2019 sequía, 2020 COVID, 2022 sequía).
4. **Phillips:** inflación (total y subyacente) y salario mínimo/índice de salarios sobre holgura (desocupación, tasa combinada de subocupación y desocupación, brecha del IMAEP); estabilidad de la pendiente.
5. **Robustez:** por área (urbana/rural) y por sexo, previa verificación de las series posicionales.

## 3. Series extraídas

EPHC completa (15 hojas) más ciclo, precios y salarios.

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `imaep_original` | IMAEP serie original (mensual; agregar a trimestre) | `economic_annex` CUADRO 9 | mensual | 1994-01-01 | 2026-06-01 | 390 | INDEX | Preliminar | Ciclo (Okun) |
| `imaep9a_desest` | IMAEP serie ajustada (mensual) | `economic_annex` CUADRO 9 a | mensual | 2014-01-01 | 2026-06-01 | 150 | INDEX | Validada por regla | Ciclo (Okun) |
| `pib_real` | PIB trimestral real (millones de Gs. de 2014) | `economic_annex` CUADRO 6 | trimestral | 1994-01-01 | 2026-01-01 | 129 | PYG (millones) | Validada por regla | Ciclo trimestral |
| `pib_real_agricultura` | PIB trimestral real: agricultura | `economic_annex` CUADRO 6 | trimestral | 1994-01-01 | 2026-01-01 | 129 | PYG (millones) | Preliminar | Ciclo sectorial |
| `pib_real_manufactura` | PIB trimestral real: manufactura | `economic_annex` CUADRO 6 | trimestral | 1994-01-01 | 2026-01-01 | 129 | PYG (millones) | Preliminar | Ciclo sectorial |
| `pib_real_construccion` | PIB trimestral real: construcción | `economic_annex` CUADRO 6 | trimestral | 1994-01-01 | 2026-01-01 | 129 | PYG (millones) | Preliminar | Ciclo sectorial |
| `pib_real_servicios` | PIB trimestral real: servicios | `economic_annex` CUADRO 6 | trimestral | 1994-01-01 | 2026-01-01 | 129 | PYG (millones) | Preliminar | Ciclo sectorial |
| `ipc_indice` | IPC índice general | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Deflactor / curva de Phillips de salarios |
| `ipc_var_interanual` | Inflación total interanual | `economic_annex` CUADRO 15 | mensual | 1993-12-01 | 2026-07-01 | 392 | PERCENT | Validada por regla | Curva de Phillips |
| `salario_minimo_nominal` | Salario mínimo legal nominal (índice) | `economic_annex` CUADRO 11 | mensual | 1985-01-01 | 2026-07-01 | 6 | INDEX | Preliminar | Salario institucional |
| `indice_salarios` | Índice de sueldos y salarios: general (semestral) | `economic_annex` CUADRO 12 | semestral | 2001-01-01 | 2025-01-01 | 49 | INDEX | Preliminar | Salario formal |
| `icc` | Índice de confianza del consumidor | `icc` NA | mensual | 2018-01-01 | 2026-07-01 | 103 | INDEX_POINTS | Preliminar | Percepción de hogares |
| `tpm` | Tasa de política monetaria | `economic_annex` CUADRO 19  | mensual | 2011-05-01 | 2026-07-01 | 183 | PERCENT | Preliminar | Control |
| `ephc_caracteristica_caracteristicas_*` | 57 series: ine_ephc hoja CARACTERÍSTICAS_OCU (detalle en diccionario_series.csv) | `ine_ephc` CARACTERÍSTICAS_OCU | trimestral | 2017-01-01 | 2026-04-01 | 2.143 | PERCENT/UNRESOLVED_SOURCE_UNITS | Preliminar (57) | EPHC (INE) hoja CARACTERÍSTICAS_OCU |
| `ephc_categoriaocupa_categoriaocupacional_*` | 29 series: ine_ephc hoja CATEGORÍAOCUPACIONAL (detalle en diccionario_series.csv) | `ine_ephc` CATEGORÍAOCUPACIONAL | trimestral | 2017-01-01 | 2026-04-01 | 962 | UNRESOLVED_SOURCE_UNITS | Preliminar (29) | EPHC (INE) hoja CATEGORÍAOCUPACIONAL |
| `ephc_formalidad_formalidad_*` | 24 series: ine_ephc hoja FORMALIDAD (detalle en diccionario_series.csv) | `ine_ephc` FORMALIDAD | trimestral | 2017-01-01 | 2026-04-01 | 900 | UNRESOLVED_SOURCE_UNITS | Preliminar (24) | EPHC (INE) hoja FORMALIDAD |
| `ephc_horashabituale_horashabituales_*` | 15 series: ine_ephc hoja HORASHABITUALES (detalle en diccionario_series.csv) | `ine_ephc` HORASHABITUALES | trimestral | 2017-01-01 | 2026-04-01 | 518 | UNRESOLVED_SOURCE_UNITS | Preliminar (15) | EPHC (INE) hoja HORASHABITUALES |
| `ephc_ingresos_cate_*` | 90 series: ine_ephc hoja INGRESOS_CATE (detalle en diccionario_series.csv) | `ine_ephc` INGRESOS_CATE | trimestral | 2017-01-01 | 2026-01-01 | 1.575 | PYG (miles) | No comprobada (90) | EPHC (INE) hoja INGRESOS_CATE |
| `ephc_ingresos_ocup_*` | 198 series: ine_ephc hoja INGRESOS_OCUP (detalle en diccionario_series.csv) | `ine_ephc` INGRESOS_OCUP | trimestral | 2017-01-01 | 2026-01-01 | 3.432 | PYG (miles) | No comprobada (198) | EPHC (INE) hoja INGRESOS_OCUP |
| `ephc_ingresos_secto_*` | 162 series: ine_ephc hoja INGRESOS_SECTOR (detalle en diccionario_series.csv) | `ine_ephc` INGRESOS_SECTOR | trimestral | 2017-01-01 | 2026-01-01 | 2.831 | PYG (miles) | No comprobada (162) | EPHC (INE) hoja INGRESOS_SECTOR |
| `ephc_ingresosporhor_ingresosporhoras_*` | 90 series: ine_ephc hoja INGRESOSPORHORAS (detalle en diccionario_series.csv) | `ine_ephc` INGRESOSPORHORAS | trimestral | 2017-01-01 | 2026-01-01 | 1.575 | PYG | No comprobada (90) | EPHC (INE) hoja INGRESOSPORHORAS |
| `ephc_poblacion_tota_*` | 81 series: ine_ephc hoja Población Total (detalle en diccionario_series.csv) | `ine_ephc` Población Total | trimestral | 2017-01-01 | 2026-04-01 | 2.916 | UNRESOLVED_SOURCE_UNITS | Preliminar (81) | EPHC (INE) hoja Población Total |
| `ephc_promedio_de_*` | 81 series: ine_ephc hoja PROMEDIO DE HORAS (detalle en diccionario_series.csv) | `ine_ephc` PROMEDIO DE HORAS | trimestral | 2017-01-01 | 2026-04-01 | 3.069 | HOURS | Preliminar (81) | EPHC (INE) hoja PROMEDIO DE HORAS |
| `ephc_promediodeanod_promediodeanodeestudio_*` | 126 series: ine_ephc hoja PROMEDIODEAÑODEESTUDIO (detalle en diccionario_series.csv) | `ine_ephc` PROMEDIODEAÑODEESTUDIO | trimestral | 2017-01-01 | 2026-01-01 | 2.394 | YEARS | No comprobada (126) | EPHC (INE) hoja PROMEDIODEAÑODEESTUDIO |
| `ephc_sectoreconomic_sectoreconomico_*` | 30 series: ine_ephc hoja SECTORECONÓMICO (detalle en diccionario_series.csv) | `ine_ephc` SECTORECONÓMICO | trimestral | 2017-01-01 | 2026-04-01 | 997 | UNRESOLVED_SOURCE_UNITS | Preliminar (30) | EPHC (INE) hoja SECTORECONÓMICO |
| `ephc_tamanodeempres_tamanodeempresa_*` | 24 series: ine_ephc hoja TAMAÑODEEMPRESA (detalle en diccionario_series.csv) | `ine_ephc` TAMAÑODEEMPRESA | trimestral | 2017-01-01 | 2026-04-01 | 863 | UNRESOLVED_SOURCE_UNITS | Preliminar (24) | EPHC (INE) hoja TAMAÑODEEMPRESA |
| `ephc_tasas_tasas_*` | 63 series: ine_ephc hoja Tasas (detalle en diccionario_series.csv) | `ine_ephc` Tasas | trimestral | 2017-01-01 | 2026-04-01 | 2.232 | PERCENT | No comprobada (42); Preliminar (21) | EPHC (INE) hoja Tasas |
| `ephc_tiempoexperien_tiempoexperiencia_*` | 18 series: ine_ephc hoja TIEMPOEXPERIENCIA (detalle en diccionario_series.csv) | `ine_ephc` TIEMPOEXPERIENCIA | trimestral | 2017-01-01 | 2026-04-01 | 610 | UNRESOLVED_SOURCE_UNITS | Preliminar (18) | EPHC (INE) hoja TIEMPOEXPERIENCIA |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_mensual.csv` | 1.604 | 11 | 1985-01-01 | 2026-07-01 |
| `datos/series_mensual_ancho.csv` | 394 | 8 | 1985-01-01 | 2026-07-01 |
| `datos/series_semestral.csv` | 49 | 11 | 2001-01-01 | 2025-01-01 |
| `datos/series_semestral_ancho.csv` | 49 | 2 | 2001-01-01 | 2025-01-01 |
| `datos/series_trimestral.csv` | 27.662 | 11 | 1994-01-01 | 2026-04-01 |
| `datos/series_trimestral_ancho.csv` | 130 | 1094 | 1994-01-01 | 2026-04-01 |
| `datos/diccionario_series.csv` | 1.101 | 13 | 1985-01-01 | 2021-01-01 |

## 4. Cómo se usarían los datos

- **Frecuencia:** trimestral (la EPHC). Agregar el IMAEP mensual a trimestre (promedio) y usar el PIB trimestral; el índice de salarios es semestral (asignar al último trimestre del semestre, sin interpolar).
- **Estacionalidad:** las tasas trimestrales de la EPHC tienen estacionalidad (actividad agrícola, fin de año); usar variaciones interanuales o dummies trimestrales (la muestra es corta para X-13).
- **Niveles:** las series de población ocupada están en **personas** (la base las marca con unidad no resuelta); las tasas en %. Ingresos en guaraníes corrientes (miles de Gs. en las hojas de ingreso mensual): deflactar por el IPC.
- **Informalidad:** construirla desde la hoja `FORMALIDAD` (`ephc_formalidad_*`): ocupados formales / total ocupados (no agropecuarios, según la nota 3/ del INE).

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Microdatos de la EPHC (panel rotativo) | Transiciones formal ↔ informal ↔ desempleo (flujos), heterogeneidad | INE – microdatos públicos de la EPH/EPHC |
| Serie empalmada antes de 2017 (EPH anual, EPH continua con metodología previa) | Muestra corta: 38 trimestres | INE – series históricas; CEPALSTAT |
| Cotizantes a la seguridad social (IPS) mensuales | Empleo formal a alta frecuencia | IPS – registros administrativos |
| Salarios del sector formal mensuales por sector | Curva de Phillips de salarios | IPS / MTESS; BCP (índice de salarios, hoy semestral) |
| Desestacionalización oficial de la EPHC | Comparabilidad | INE |

## 6. Evaluación de viabilidad

**Media.** Los indicadores agregados de la EPHC (tasas, ocupados por sector, categoría, tamaño y formalidad) son preliminares y cubren 38 trimestres; alcanzan para Okun, la informalidad como amortiguador y la curva de Phillips descriptiva, aunque la muestra corta y la pandemia limitan la inferencia. Las desagregaciones por sexo y los ingresos tienen identidad posicional (no comprobados).

## 7. Supuestos que debes revisar

1. **Series posicionales:** en la hoja `Tasas` las filas por sexo (Hombres/Mujeres) repiten la etiqueta sin decir qué tasa son (actividad, ocupación, desocupación…), y lo mismo ocurre en las hojas de ingresos; son **no comprobadas** y deben identificarse contra el Excel del INE. Las tasas totales, urbanas y rurales sí tienen etiqueta.
2. Unidad de ocupados: personas (lectura por magnitud: ≈ 2,85 millones de ocupados no agropecuarios en 2026T2).
3. La tasa de informalidad se calcula solo para ocupados no agropecuarios (definición del cuadro del INE).
4. El IMAEP mensual se agrega a trimestre por promedio.
5. Los ingresos de la EPHC terminan en 2026T1; las tasas, en 2026T2.
