# 32 · N11 (proyecto nuevo) — Ajustes del salario mínimo: precios de servicios, salarios e informalidad

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 20:44:35 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

> **Proyecto nuevo con potencial causal moderado.** La base trae la vigencia de cada tramo del salario mínimo (83 tramos desde 1980). Desde 2017 los ajustes son anuales, en julio, de magnitud variable (3,4% a 10,8%), y en 2020 no hubo ajuste: eso da eventos fechados con intensidad distinta.

## 1. Resumen y pregunta de investigación

- **Pregunta:** ¿cuánto se trasladan los ajustes del salario mínimo a los precios de servicios intensivos en mano de obra, a los salarios formales y a la informalidad?
- **Estimandos:** elasticidad de precios de servicios al ajuste (vs. bienes como placebo); cambio en la proporción de ocupados formales tras el ajuste.
- **Evidencia:** estudio de eventos con intensidad variable. Límite: desde la Ley N.º 5764/2016 el ajuste se basa en la variación interanual del IPC a junio, por lo que es en buena parte **anticipado**; la sorpresa es la diferencia entre el ajuste y lo que implicaba la fórmula o la expectativa.

## 2. Estrategia empírica propuesta

1. **Eventos:** tramos de `salario_minimo_tramos_vigencia.csv` (12 ajustes desde 2010: 2010-07, 2011-04, 2014-03, 2017-01, 2017-07 y cada julio 2018–2025 salvo 2020). Con los decretos (`datos_manuales/decretos_salario_minimo.csv`), agregar la fecha de anuncio y la regla aplicada.
2. **LP mensuales** del IPC de servicios, restaurantes, educación, salud y confección, frente a bienes transables (placebo), sobre la magnitud del ajuste, h = 0–12.
3. **Mercado laboral (trimestral):** proporción de ocupados formales y por categoría (EPHC 2017–2026) en los trimestres posteriores a cada ajuste; índice de salarios semestral.
4. **Anticipación:** comparar ajustes cercanos a la fórmula con desvíos (2022: +10,8% con inflación alta; 2020: sin ajuste).

## 3. Series extraídas

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `sm_nominal_anual` | Salario mínimo legal nominal (anual) | `economic_annex` CUADRO 11 | anual | 1980-01-01 | 2025-01-01 | 46 | INDEX | Preliminar | Tratamiento (nivel) |
| `sm_real_anual` | Salario mínimo legal real (anual) | `economic_annex` CUADRO 11 | anual | 1980-01-01 | 2025-01-01 | 46 | INDEX | Preliminar | Tratamiento real |
| `sm_indice_nominal_anual` | Índice de salario mínimo nominal (anual) | `economic_annex` CUADRO 11 | anual | 1980-01-01 | 2025-01-01 | 46 | INDEX | Preliminar | Tratamiento |
| `sm_indice_real_anual` | Índice de salario mínimo real (anual) | `economic_annex` CUADRO 11 | anual | 1980-01-01 | 2025-01-01 | 46 | INDEX | Preliminar | Tratamiento |
| `ipc_servicios` | IPC servicios | `economic_annex` CUADRO 14 b | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Resultado: servicios intensivos en mano de obra |
| `ipc_renta` | IPC renta (alquileres) | `economic_annex` CUADRO 14 b | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Placebo parcial |
| `ipc_total_bienes` | IPC total de bienes | `economic_annex` CUADRO 14 b | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Placebo (bienes transables) |
| `ipc_restaurantes_hoteles` | IPC restaurantes y hoteles | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Resultado: intensivo en mano de obra |
| `ipc_educacion` | IPC educación | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Resultado |
| `ipc_salud` | IPC gasto en salud | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Resultado |
| `ipc_confeccion_ropas` | IPC vestido: confección de ropas (servicio) | `economic_annex` CUADRO 16 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Resultado: servicio intensivo en mano de obra |
| `ipc_indice` | IPC índice general | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Deflactor |
| `ipc_var_mensual` | Inflación total mensual | `economic_annex` CUADRO 15 | mensual | 1993-01-01 | 2026-07-01 | 403 | PERCENT | Validada por regla | Resultado agregado |
| `ipc_subyacente_mensual` | Inflación subyacente mensual | `economic_annex` CUADRO 15 | mensual | 1993-01-01 | 2026-07-01 | 403 | PERCENT | Validada por regla | Resultado agregado |
| `eve_inf_anio_t` | EVE (mediana): inflación esperada año t | `eve` NA | mensual | 2006-04-01 | 2026-08-01 | 245 | PROPORTION | Preliminar | Canal de expectativas |
| `imaep_original` | IMAEP serie original | `economic_annex` CUADRO 9 | mensual | 1994-01-01 | 2026-06-01 | 390 | INDEX | Preliminar | Control |
| `salarios_cuadro_12_*` | 12 series: economic_annex hoja CUADRO 12 (detalle en diccionario_series.csv) | `economic_annex` CUADRO 12 | semestral | 2001-01-01 | 2025-01-01 | 585 | INDEX/PERCENT | Preliminar (12) | Índice de sueldos y salarios por sector (semestral) |
| `ephc_formalidad_formalidad_*` | 24 series: ine_ephc hoja FORMALIDAD (detalle en diccionario_series.csv) | `ine_ephc` FORMALIDAD | trimestral | 2017-01-01 | 2026-04-01 | 900 | UNRESOLVED_SOURCE_UNITS | Preliminar (24) | EPHC: ocupados formales y totales por categoría |
| `ephc_ingreso_ingresos_*` | 90 series: ine_ephc hoja INGRESOS_CATE (detalle en diccionario_series.csv) | `ine_ephc` INGRESOS_CATE | trimestral | 2017-01-01 | 2026-01-01 | 1.575 | PYG (miles) | No comprobada (90) | EPHC: ingreso promedio por categoría ocupacional (no comprobado) |
| `ephc_tasas_tasas_*` | 63 series: ine_ephc hoja Tasas (detalle en diccionario_series.csv) | `ine_ephc` Tasas | trimestral | 2017-01-01 | 2026-04-01 | 2.232 | PERCENT | No comprobada (42); Preliminar (21) | EPHC: tasas de fuerza de trabajo |

### Otros archivos

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `salario_minimo_tramos_vigencia.csv` | Monto del salario mínimo por tramo de vigencia (inicio y fin), variación y marca de ajuste | 1980-01-01 a 2026-01-01, 83 filas | Estructura especial |
| `datos_manuales/decretos_salario_minimo.csv` | **Plantilla para completar**: fecha del decreto y de vigencia, monto, norma, criterio de ajuste | vacía | Manual |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_anual.csv` | 184 | 11 | 1980-01-01 | 2025-01-01 |
| `datos/series_anual_ancho.csv` | 46 | 5 | 1980-01-01 | 2025-01-01 |
| `datos/series_mensual.csv` | 4.478 | 11 | 1993-01-01 | 2026-08-01 |
| `datos/series_mensual_ancho.csv` | 404 | 13 | 1993-01-01 | 2026-08-01 |
| `datos/series_semestral.csv` | 585 | 11 | 2001-01-01 | 2025-01-01 |
| `datos/series_semestral_ancho.csv` | 49 | 13 | 2001-01-01 | 2025-01-01 |
| `datos/series_trimestral.csv` | 4.707 | 11 | 2017-01-01 | 2026-04-01 |
| `datos/series_trimestral_ancho.csv` | 38 | 178 | 2017-01-01 | 2026-04-01 |
| `datos/diccionario_series.csv` | 205 | 13 | 1980-01-01 | 2019-01-01 |
| `datos/salario_minimo_tramos_vigencia.csv` | 83 | 8 | 1980-01-01 | 2026-01-01 |

## 4. Cómo se usarían los datos

- Magnitud del ajuste = `Δlog` del monto entre tramos; en términos reales, restando la inflación acumulada desde el ajuste anterior.
- IPC por componentes en `Δlog` mensual; EPHC en proporciones trimestrales.
- El índice de salarios es semestral: asignar al último mes del semestre.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Decretos: fecha de anuncio, regla aplicada | Separar anticipado de sorpresa | MTESS; Presidencia (lo conseguirás mañana) |
| Distribución salarial (proporción de trabajadores cerca del mínimo) por sector | Exposición sectorial al ajuste (diseño de intensidad) | INE – microdatos EPHC; IPS |
| Salarios mensuales formales por sector | Traspaso salarial | IPS |

## 6. Evaluación de viabilidad

**Media.** Los eventos están fechados en la base y los precios por componente son mensuales desde 1994; la anticipación de la fórmula y la falta de exposición sectorial (proporción de trabajadores en el mínimo) limitan la interpretación causal.

## 7. Supuestos que debes revisar

1. Los tramos de vigencia provienen del Cuadro 11 (estructura de eventos en la base, provisional); coinciden con ajustes anuales conocidos, pero conviene verificar contra los decretos.
2. Los ingresos de la EPHC son no comprobados (identidad posicional).
3. Uso servicios intensivos en mano de obra como tratados y bienes transables como placebo.

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Salario mínimo y precios

| Referencia | Qué respalda en este proyecto |
|---|---|
| Aaronson, D. (2001). "Price Pass-Through and the Minimum Wage." *Review of Economics and Statistics*, 83(1), 158–169. **[Revista]** | Traspaso de los aumentos del mínimo a los precios de **restaurantes**. Diseño de referencia del paso 2 y de la elección de rubros tratados. |
| Harasztosi, P. y Lindner, A. (2019). "Who Pays for the Minimum Wage?" *American Economic Review*, 109(8), 2693–2727. **[Revista]** | En Hungría, la mayor parte del aumento lo pagaron los **consumidores** vía precios. Respalda los servicios intensivos en trabajo como tratados. |

### 8.2 Empleo, salarios e informalidad

| Referencia | Qué respalda |
|---|---|
| Card, D. y Krueger, A. B. (1994). "Minimum Wages and Employment: A Case Study of the Fast-Food Industry in New Jersey and Pennsylvania." *American Economic Review*, 84(4), 772–793. **[Revista]** | Referencia clásica de la evaluación con grupo de control. |
| Cengiz, D., Dube, A., Lindner, A. y Zipperer, B. (2019). "The Effect of Minimum Wages on Low-Wage Jobs." *Quarterly Journal of Economics*, 134(3), 1405–1454. **[Revista]** | Método de "bunching" en la distribución salarial. Posible con microdatos de la EPHC. |
| Maloney, W. F. y Nuñez Mendez, J. (2004). "Measuring the Impact of Minimum Wages: Evidence from Latin America." En Heckman, J. J. y Pagés, C. (eds.), *Law and Employment: Lessons from Latin America and the Caribbean*. University of Chicago Press. **[Capítulo]** | En América Latina el mínimo afecta también al sector **informal** (efecto faro). Respalda medir los ingresos informales. |
| Boeri, T., Garibaldi, P. y Ribeiro, M. (2011). "The Lighthouse Effect and Beyond." *Review of Income and Wealth*, 57(s1), S54–S78. **[Revista]** | Formalización del efecto faro. |
| Engbom, N. y Moser, C. (2022). "Earnings Inequality and the Minimum Wage: Evidence from Brazil." *American Economic Review*, 112(12), 3803–3847. **[Revista]** | Efectos de los aumentos del mínimo en Brasil sobre la desigualdad salarial. Comparación regional. |

### 8.3 Antecedentes para Paraguay y corrección

- **[PY]** El ajuste se rige por el art. 255 del Código del Trabajo, modificado por la **Ley N.º 5764/2016**: el Ejecutivo, a propuesta del CONASAM, lo basa en la variación interanual del IPC a junio. **Corrección aplicada:** una versión anterior de este README decía que la fórmula regía "desde 2019"; según la norma, la base legal es de 2016. Lo que importa para el diseño es lo mismo: el ajuste es mayormente **anticipado**, y la sorpresa es el desvío respecto del IPC a junio.
- **[PY]** MTESS (2025). *Reporte Técnico N.º 2: Salario mínimo legal en Paraguay, normativa, evolución y cobertura.* Descriptivo. Aporta la **cobertura**: según cifras difundidas, solo ≈ 15% de los asalariados gana exactamente el mínimo y la mayoría de los informales gana menos. Es la medida de exposición que falta en la brecha "distribución salarial".
