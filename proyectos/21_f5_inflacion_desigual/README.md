# 21 · F5 — Inflación desigual (N9) y comunicación experimental (N10)

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 18:55:17 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

## 1. Resumen y pregunta de investigación

La inflación promedio no representa las canastas ni la capacidad de sustitución de todos los hogares. La ficha contiene dos proyectos que no deben mezclarse:

- **N9 — Inflación por grupos (descriptivo/predictivo):** ¿qué grupos de hogares (quintil de ingreso, área urbana/rural, inquilinos/propietarios) enfrentan una inflación distinta y por qué? Estimando: índice por grupo y descomposición de la brecha con el IPC oficial por componente (alimentos, tarifas, alquiler, transporte).
- **N10 — Comunicación experimental (causal sobre creencias):** ¿qué mensaje del banco central cambia las expectativas y las decisiones declaradas? Requiere un diseño prospectivo (aleatorización, creencias pre/post). **No hay datos para N10 en la base**, y la ficha pide no usar la EVE para afirmar conducta de hogares.

## 2. Estrategia empírica propuesta (N9)

1. **Índices Laspeyres por grupo:** `π_g,t = Σ_i w_{g,i} · π_{i,t}`, con `π_{i,t}` las variaciones de los índices por división (Cuadro 14, 12 divisiones) y por grupo de gasto (Cuadros 16 y 16 (Cont.), ~25 grupos), y con `w_{g,i}` las participaciones de gasto de cada grupo de hogares tomadas de la EIGH del INE (**externa**, ver brechas).
2. **Descomposición de la brecha** `π_g − π_oficial = Σ_i (w_{g,i} − w_i) π_i` por componente, para identificar qué rubros la explican (alimentos, carne, tarifas de electricidad y agua, transporte público, alquiler).
3. **Episodios:** 2007–08 (alimentos), 2011–12 y 2019 (carne), 2021–22 (combustibles y alimentos), y análisis de persistencia de la brecha.
4. **Sensibilidad:** pesos alternativos (EIGH 2011/12 frente a pesos del IPC oficial), índice con alimentos detallados (cortes de carne del Cuadro 16 a) y con precios regulados (Cuadros 13/14 c).
5. **Complemento de ingresos:** poder de compra relativo con el salario mínimo (Cuadro 11) y el ingreso promedio por categoría ocupacional y área de la EPHC (2017–2026).

## 3. Series extraídas

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `ipc_var_mensual` | Inflación total mensual (oficial) | `economic_annex` CUADRO 15 | mensual | 1993-01-01 | 2026-07-01 | 403 | PERCENT | Validada por regla | Benchmark: inflación promedio |
| `ipc_var_interanual` | Inflación total interanual (oficial) | `economic_annex` CUADRO 15 | mensual | 1993-12-01 | 2026-07-01 | 392 | PERCENT | Validada por regla | Benchmark: inflación promedio |
| `ipc_subyacente_interanual` | Inflación subyacente interanual | `economic_annex` CUADRO 15 | mensual | 1993-12-01 | 2026-07-01 | 392 | PERCENT | Validada por regla | Benchmark |
| `ipc_transables_sin_fyv` | IPC bienes transables sin frutas y verduras (índice) | `economic_annex` CUADRO 14 a | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Descomposición de la brecha |
| `ipc_no_transables` | IPC bienes no transables (índice; la base agrega 'Inter.' a la etiqueta) | `economic_annex` CUADRO 14 a | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Descomposición de la brecha |
| `ipc_importados_sin_fyv` | IPC productos importados sin frutas y verduras (índice) | `economic_annex` CUADRO 14 a | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Descomposición de la brecha |
| `ipc_nacionales` | IPC productos nacionales (índice) | `economic_annex` CUADRO 14 a | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Descomposición de la brecha |
| `ipc_bienes_alimenticios` | IPC bienes alimenticios (índice) | `economic_annex` CUADRO 14 b | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Componente con peso alto en hogares pobres |
| `ipc_alimenticios_sin_fyv` | IPC bienes alimenticios sin frutas y verduras (índice) | `economic_annex` CUADRO 14 b | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Componente |
| `ipc_bienes_no_alimenticios` | IPC bienes distintos de alimentos (índice) | `economic_annex` CUADRO 14 b | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Componente |
| `ipc_servicios` | IPC servicios (índice) | `economic_annex` CUADRO 14 b | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Componente |
| `ipc_renta` | IPC renta (alquileres; índice) | `economic_annex` CUADRO 14 b | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Componente (inquilinos vs propietarios) |
| `ipc_servicios_y_renta` | IPC servicios y renta (índice) | `economic_annex` CUADRO 14 b | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Componente |
| `ipc_total_bienes` | IPC total de bienes (índice) | `economic_annex` CUADRO 14 b | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Componente |
| `ipc_sin_alimentos` | IPC sin alimentos (índice) | `economic_annex` CUADRO 14 b | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Componente |
| `ipcsae` | IPCSAE (sin alimentos ni energía; índice) | `economic_annex` CUADRO 14 b | mensual | 2007-12-01 | 2026-07-01 | 224 | INDEX | Preliminar | Componente |
| `ipc_sin_alim_comb_tarif` | IPC sin alimentos combustibles ni servicios tarifados (índice) | `economic_annex` CUADRO 14 b | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Componente |
| `salario_minimo_nominal` | Salario mínimo legal nominal (índice) | `economic_annex` CUADRO 11 | mensual | 1985-01-01 | 2026-07-01 | 6 | INDEX | Preliminar | Ingreso de hogares de menores recursos |
| `indice_salarios` | Índice de sueldos y salarios: general (semestral) | `economic_annex` CUADRO 12 | semestral | 2001-01-01 | 2025-01-01 | 49 | INDEX | Preliminar | Ingreso laboral |
| `tarifa_cuadro_13_*` | 5 series: economic_annex hoja CUADRO 13 (detalle en diccionario_series.csv) | `economic_annex` CUADRO 13 | mensual | 1988-01-01 | 2026-07-01 | 2.217 | INDEX | Preliminar (5) | Índice de tarifas y precios regulados (etiquetas de la base cruzadas: ver supuestos) |
| `tarifa_gasoil_cuadro_13_*` | 4 series: economic_annex hoja CUADRO 13 a (detalle en diccionario_series.csv) | `economic_annex` CUADRO 13 a | mensual | 1988-01-01 | 2026-07-01 | 1.826 | PERCENT/INDEX | Preliminar (4) | Índice de precio del gasoil (el título del cuadro dice IPC empalmado; por valores es gasoil) |
| `ipc_div_cuadro_14_*` | 16 series: economic_annex hoja CUADRO 14 (detalle en diccionario_series.csv) | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 6.080 | INDEX/PERCENT | Preliminar (16) | Índice por división COICOP (base dic-2017) |
| `ipc_admin_cuadro_14_*` | 4 series: economic_annex hoja CUADRO 14 c (detalle en diccionario_series.csv) | `economic_annex` CUADRO 14 c | mensual | 2003-01-01 | 2026-07-01 | 1.132 | INDEX | Preliminar (4) | Bienes libres vs administrados |
| `ipc_grupo_cuadro_16_*` | 11 series: economic_annex hoja CUADRO 16 (detalle en diccionario_series.csv) | `economic_annex` CUADRO 16 | mensual | 1994-12-01 | 2026-07-01 | 4.180 | INDEX | Preliminar (11) | Índice por grupo de gasto |
| `ipc_grupo_cont_*` | 14 series: economic_annex hoja CUADRO 16 (Cont.) (detalle en diccionario_series.csv) | `economic_annex` CUADRO 16 (Cont.) | mensual | 1994-12-01 | 2026-07-01 | 5.320 | COUNT/INDEX | Preliminar (14) | Índice por grupo de gasto |
| `ipc_carne_cuadro_16_*` | 20 series: economic_annex hoja CUADRO 16 a (detalle en diccionario_series.csv) | `economic_annex` CUADRO 16 a | mensual | 1994-12-01 | 2026-07-01 | 5.752 | INDEX | Preliminar (20) | Índice por corte de carne vacuna |
| `ephc_ingreso_ingresos_*` | 90 series: ine_ephc hoja INGRESOS_CATE (detalle en diccionario_series.csv) | `ine_ephc` INGRESOS_CATE | trimestral | 2017-01-01 | 2026-01-01 | 1.575 | PYG (miles) | No comprobada (90) | Ingreso promedio por área/categoría/sexo (caracterización de grupos) |

### Otros archivos

| Archivo | Contenido | Rango | Nivel |
|---|---|---|---|
| `ponderadores_ipc_fmi_2005.csv` | Ponderaciones (%) del IPC de Paraguay por división COICOP informadas al FMI, **solo para 2005** (canasta anterior a la base 2017); referencia, no sirve como peso actual | 2005-01-01 a 2005-12-01, 144 filas | Preliminar |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_mensual.csv` | 32.851 | 11 | 1985-01-01 | 2026-07-01 |
| `datos/series_mensual_ancho.csv` | 465 | 93 | 1985-01-01 | 2026-07-01 |
| `datos/series_semestral.csv` | 49 | 11 | 2001-01-01 | 2025-01-01 |
| `datos/series_semestral_ancho.csv` | 49 | 2 | 2001-01-01 | 2025-01-01 |
| `datos/series_trimestral.csv` | 1.575 | 11 | 2017-01-01 | 2026-01-01 |
| `datos/series_trimestral_ancho.csv` | 27 | 91 | 2017-01-01 | 2026-01-01 |
| `datos/diccionario_series.csv` | 183 | 13 | 1985-01-01 | 2017-12-01 |
| `datos/ponderadores_ipc_fmi_2005.csv` | 144 | 5 | 2005-01-01 | 2005-12-01 |

## 4. Cómo se usarían los datos

- **Variaciones:** calcular `Δlog` mensual e interanual de cada índice; no usar las variaciones % publicadas en los Cuadros 14 a y 14 b porque tienen identidad posicional (no comprobadas).
- **Base:** los índices por división (Cuadro 14) y grupos (Cuadro 16) están en base dic-2017 = 100, empalmados hacia atrás hasta 1994-12; antes de 2017 la canasta y los pesos eran distintos, así que las comparaciones largas mezclan canastas.
- **Agregación:** encadenar mensualmente (Laspeyres encadenado) y comprobar que, con los pesos oficiales, el agregado reproduce `ipc_div_cuadro_14_indice_general` (prueba de consistencia de la jerarquía).
- **Desestacionalización:** no es necesaria para índices por grupo comparados en variación interanual; frutas y verduras y educación (marzo) son muy estacionales si se usan variaciones mensuales.
- **Ingresos EPHC:** trimestrales y en guaraníes corrientes; deflactar por el índice de cada grupo para medir ingreso real diferencial.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| **Ponderadores de gasto por grupo de hogares** (quintil, área, tenencia de vivienda) | Sin ellos no hay índice por grupo; es la variable central de N9 | INE – Encuesta de Ingresos y Gastos (EIGH 2011/12) y módulo de gastos de la EPH; BCP – ponderaciones del IPC base 2017 |
| Ponderaciones oficiales del IPC base 2017 por división y grupo | Consistencia con el índice general | BCP – metodología del IPC 2017 |
| Índices por producto (canasta completa) | Nivel "suficiente": más detalle que las divisiones | BCP – IPC por producto (datos internos) |
| Microprecios por comercio y región | Nivel "ideal/óptimo": sustitución y dispersión | BCP – relevamiento de precios; scanner data |
| Pobreza y distribución del ingreso por quintil | Definir grupos | INE – EPH anual (microdatos públicos) |
| N10: diseño experimental, encuesta propia con creencias pre/post | Sin esto N10 no existe | Diseño prospectivo (encuesta en línea o módulo en la EPH/ICC) |

## 6. Evaluación de viabilidad

**Media para N9.** Hay índices mensuales por división, grupo y producto desde 1994, además de tarifas y salarios, pero falta la variable central —pesos de gasto por grupo de hogares—, que debe incorporarse de la EIGH del INE (fuente pública). **Baja para N10**, que requiere un diseño prospectivo.

## 7. Supuestos que debes revisar

1. **Cuadro 13 a:** el título dice "IPC empalmado base 2017", pero por sus valores es un **índice de precio del gasoil** (195,9 en 2026-07 frente a 141,4 del IPC general; coincide con la columna de gasoil del Cuadro 13 hasta 2018-05). Lo nombré `tarifa_gasoil_*`.
2. **Cuadro 13:** las etiquetas de la base están cruzadas ("Gasoil — Teléfono", "Pasaje — Teléfono"). Por valores, `tarifa_cuadro_13_gasoil_telefono` es el gasoil (hasta 2018-05) y `tarifa_cuadro_13_pasaje_telefono` es el pasaje de transporte público; revisar las demás contra el Excel.
3. `ipc_grupo_cont_cuadro_16_cont_b_y_serv_div_higiene_y_cuidado_personal` figura con unidad "COUNT" en la base; es un índice.
4. Los ingresos de la EPHC (`ephc_ingreso_*`) son **no comprobados** (identidad posicional en la base); usarlos solo para caracterizar grupos, tras verificar contra el Excel del INE.
5. Los pesos del FMI corresponden a la canasta de 2005; los incluyo solo como referencia histórica.
6. N10 queda sin datos; la carpeta solo sirve a N9.

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 N9: inflación por grupos de hogares

| Referencia | Qué respalda en este proyecto |
|---|---|
| Hobijn, B. y Lagakos, D. (2005). "Inflation Inequality in the United States." *Review of Income and Wealth*, 51(4), 581–606. **[Revista]** | Método del paso 1: **índices Laspeyres por grupo** con los índices oficiales por componente y pesos de gasto de cada grupo. Identifica qué rubros (salud, energía) explican las brechas. Respalda la descomposición del paso 2. |
| Kaplan, G. y Schulhofer-Wohl, S. (2017). "Inflation at the Household Level." *Journal of Monetary Economics*, 91, 19–38. **[Revista]** | Con datos de escáner, la dispersión de la inflación entre hogares es grande y persistente. Justifica que la inflación promedio no represente a todos los hogares, aunque con datos por componente solo se captura la parte **entre canastas**, no la de precios pagados. |
| Jaravel, X. (2021). "Inflation Inequality: Measurement, Causes, and Policy Implications." *Annual Review of Economics*, 13, 599–629. **[Revista]** | Revisión de referencia sobre medición y sesgos por agregación de categorías. Respalda el análisis de sensibilidad al nivel de desagregación (divisiones frente a grupos y cortes de carne). |
| Argente, D. y Lee, M. (2021). "Cost of Living Inequality During the Great Recession." *Journal of the European Economic Association*, 19(2), 913–952. **[Revista]** | La brecha se amplía en episodios de shock. Respalda el análisis por episodios (2007–08, 2021–22). |
| Easterly, W. y Fischer, S. (2001). "Inflation and the Poor." *Journal of Money, Credit and Banking*, 33(2), 160–178. **[Revista]** | Evidencia internacional de que la inflación afecta más a los pobres. Motiva el foco en quintiles de ingreso. |
| Goñi, E., López, J. H. y Servén, L. (2006). "Getting Real about Inequality: Evidence from Brazil, Colombia, Mexico, and Peru." World Bank Policy Research Working Paper 3815. **[DT]** | **Antecedente regional directo**: con encuestas de gasto de hogares, encuentran que el IPC suele reflejar la canasta de hogares entre los percentiles 80 y 90 del gasto. Es el mismo diseño propuesto con la EIGH. |

### 8.2 N10: comunicación experimental

| Referencia | Qué respalda |
|---|---|
| Coibion, O., Gorodnichenko, Y. y Weber, M. (2022). "Monetary Policy Communications and Their Effects on Household Inflation Expectations." *Journal of Political Economy*, 130(6), 1537–1584. **[Revista]** | Diseño de referencia: ensayo controlado aleatorizado con hogares que reciben distintos mensajes del banco central, con creencias medidas antes y después. Es el diseño que la ficha pide para N10. |
| Blinder, A. S., Ehrmann, M., de Haan, J. y Jansen, D.-J. (2024). "Central Bank Communication with the General Public: Promise or False Hope?" *Journal of Economic Literature*, 62(2), 425–457. **[Revista]** | Revisión de la evidencia sobre comunicación con el público: efectos reales pero pequeños y poco persistentes. Ayuda a fijar expectativas realistas sobre el tamaño del efecto y el tamaño muestral necesario. |

### 8.3 Nota sobre Paraguay

No encontré estudios publicados de inflación por quintil para Paraguay. Esto hace más valioso el N9, pero depende de acceder a los pesos de la EIGH del INE (ver brechas).
