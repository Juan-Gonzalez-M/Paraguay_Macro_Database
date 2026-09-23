# 21 · F5 — Inflación desigual (N9) y comunicación experimental (N10)

*Carpeta de datos generada por `R/01_extraer_datos.R` · {{GENERADO}}*

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

{{TABLA_SERIES}}

### Otros archivos

| Archivo | Contenido | Rango | Nivel |
|---|---|---|---|
| `ponderadores_ipc_fmi_2005.csv` | Ponderaciones (%) del IPC de Paraguay por división COICOP informadas al FMI, **solo para 2005** (canasta anterior a la base 2017); referencia, no sirve como peso actual | {{RANGO:ponderadores_ipc_fmi_2005.csv}} | Preliminar |

{{TABLA_ARCHIVOS}}

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
