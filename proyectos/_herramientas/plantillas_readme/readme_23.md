# 23 · N2 (proyecto nuevo) — Mercado laboral, informalidad y ciclo

*Carpeta de datos generada por `R/01_extraer_datos.R` · {{GENERADO}}*

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

{{TABLA_SERIES}}

{{TABLA_ARCHIVOS}}

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

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Okun y márgenes de ajuste

| Referencia | Qué respalda en este proyecto |
|---|---|
| Okun, A. M. (1962). "Potential GNP: Its Measurement and Significance." *Proceedings of the Business and Economic Statistics Section*, American Statistical Association, 98–104. **[Conferencia]** | Relación original entre producto y desempleo. |
| Ball, L., Leigh, D. y Loungani, P. (2017). "Okun's Law: Fit at 50?" *Journal of Money, Credit and Banking*, 49(7), 1413–1441. **[Revista]** | Okun en panel de países, con coeficientes que varían entre países. Es la especificación de referencia del paso 2 y una base de comparación. |

### 8.2 Informalidad y ciclo

| Referencia | Qué respalda |
|---|---|
| Fernández, A. y Meza, F. (2015). "Informal Employment and Business Cycles in Emerging Economies: The Case of Mexico." *Review of Economic Dynamics*, 18(2), 381–405. **[Revista]** | La informalidad es procíclica o contracíclica según el shock. Respalda el paso 3 (¿amortiguador o no?). |
| Leyva, G. y Urrutia, C. (2020). "Informality, Labor Regulation, and the Business Cycle." *Journal of International Economics*, 126. **[Revista]** | El sector informal amortigua las fluctuaciones del empleo y el consumo en economías pequeñas abiertas. Es la hipótesis del paso 3. |
| Bosch, M. y Maloney, W. F. (2010). "Comparative Analysis of Labor Market Dynamics Using Markov Processes: An Application to Informality." *Labour Economics*, 17(4), 621–631. **[Revista]** | Flujos formal ↔ informal en América Latina. Su versión con microdatos de la EPHC sería una extensión natural. |

### 8.3 Curva de Phillips

| Referencia | Qué respalda |
|---|---|
| Galí, J. (2011). "The Return of the Wage Phillips Curve." *Journal of the European Economic Association*, 9(3), 436–461. **[Revista]** | Curva de Phillips de **salarios** con desempleo. Respalda usar el índice de salarios como resultado. |
| Hazell, J., Herreño, J., Nakamura, E. y Steinsson, J. (2022). "The Slope of the Phillips Curve: Evidence from U.S. States." *Quarterly Journal of Economics*, 137(3), 1299–1344. **[Revista]** | La pendiente es pequeña y difícil de identificar con series agregadas. Advierte sobre los límites de 38 trimestres. |

### 8.4 Antecedentes para Paraguay

- **[PY]** MTESS y CADEP publicaron documentos descriptivos sobre la evolución y características del empleo informal en Paraguay (por ejemplo, "El empleo informal en el Paraguay: evolución, características y acciones de…", CADEP). Describen la informalidad a lo largo del ciclo 2003–2014 sin estimar Okun ni Phillips.
- No encontré estimaciones publicadas de Okun por margen de ajuste para Paraguay; este es el aporte del proyecto.
