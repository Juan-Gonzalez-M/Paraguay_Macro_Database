> Historical record of one release. The current acceptance rule, run-status vocabulary and data model are in `README.md`, `docs/OPERATIONS.md` and `docs/DATA_MODEL.md`; where this file disagrees with them it is describing an earlier state. Since schema 23 a failing run reports `release_blocked`, not `completed_with_errors`, and since schema 24 a release carries its own lifecycle in `audit.releases`.

# Auditoría — registro de defectos y regresiones

**Cómo se usa.** Los **CERRADOS** son la batería de regresión: confirmá en cada
revisión que siguen cerrados. Los **ABIERTOS** son lo pendiente al cierre de la
revisión más reciente. Actualizá este archivo al terminar cada auditoría.

Severidades: **silencioso** (produce datos equivocados sin avisar) · **bloqueante**
(impide correr) · **operativo** · **menor**.

**Nota v11 (consolidado):** este archivo era, durante v11, uno de dos registros de
auditoría en paralelo con numeraciones que colisionaban desde R26.
`docs/AUDITORIA_REGRESIONES.md` ahora es un stub que apunta acá — éste es el único
registro activo. El detalle de por qué se consolidó está en
`revisiones/MEJORAS_v11.md`, sección 1.

---

## Cerrados en la ronda P0/P1/P2 de la auditoría técnica externa (2026-08-29)

Fuente: `Technical_Audit.docx`, edición comparativa, sobre `paraguay_macro_pilot (2).duckdb`
(schema 12). Igual que en la ronda anterior, antes de tocar nada se reverificó cada
cifra del informe contra la base real: **todas exactas** (23.012 `dim_series`,
1.216.299 `fact_series_events`, 9.924 `positional_lane` = 43,13%, 10.462 series de
una observación, 13.300 con menos de 12, 50 identidades posicionales en
`credit_survey`, 7.812 `positional_lane` en `economic_annex`, 66/44 tablas y
vistas, 0 claves foráneas, 1.571 de 28.417 IDs previos retenidos).

Alcance acordado con el usuario: **P0, P1 y P2** de la sección 12. P3 fuera de alcance.

Resultado global: `dim_series` 23.012 → 15.191; `positional_lane` 9.924 → 2.112;
series de una observación 10.462 → 3.751; largo mediano 3 → 17; reuso de celda
fuente **cero** en las 242 hojas; **cero** flags de severidad `error`.
`v_research_series` sigue vacía a propósito. Migraciones `schema_version` 13 y 14.
El registro completo de verificación está en
`revisiones/REVISION_AUDITORIA_P0_P1_P2.md`.

---

### R45 — eje temporal horizontal sin borde derecho y marcador de provisionalidad dentro de la identidad · silencioso · CERRADO
**Dónde:** `scripts/03_curate_documented.R`, `documented_extract_horizontal_time()`.

**Causa raíz (dos mitades).** (1) El relleno hacia la derecha del eje de períodos
corría hasta la última columna de la hoja, así que las siete columnas de
comparación interanual que las hojas de comercio exterior publican a la derecha de
los datos (`A Julio 2024`, `Var. % …`, `Incidencia`, …) heredaban el último período
real. (2) La fila 13 lleva un `*` suelto sobre los últimos 24 meses; `documented_fill_right()`
lo convertía en subencabezado y `column_labels` en `measure`, partiendo cada serie
de producto en dos en 2024-08 (`Soja` 367 obs y `Soja — *` 31 obs).

**Arreglo.** El eje se acota en la última celda de encabezado que efectivamente
parsea como período; el relleno sigue operando dentro del eje, que es para lo que
existe. Las celdas cuyo contenido es sólo un marcador de nota (`*`, `(*)`, `1/`)
se excluyen del subencabezado mediante `documented_footnote_only()` y se conservan
en `footnote_marker`.

**Evidencia.** Se corrió el extractor compartido sobre las 94 hojas del Anexo antes
y después y se diffeó serie por serie: **cambian exactamente 8 hojas**
(Cuadro 46a/46b/51a/51b/52a/52b/53a/53b), **85 quedan idénticas**. Diffeando por
celda física y valor, ignorando etiquetas: **6.962 quitadas, 0 agregadas**, y las
6.962 llevan período **2026-07-01** y están en columnas más allá del fin del eje.
Etiquetas terminadas en marcador: 22.228 → 0. `positional_lane` en `economic_annex`:
7.812 → 0. Las ocho hojas ahora concilian exacto (`unmapped_in_region = 0`).

**Cómo verificar que sigue cerrado:** `test-audit-p1-p2-remediation.R`, bloque
"the foreign-trade axis is bounded"; y las firmas de `parser_contract_signatures.csv`.

---

### R52 — la prueba de encabezado de pregunta de la encuesta de crédito exigía fila sin valores · silencioso · CERRADO
**Dónde:** `scripts/03_curate_documented.R`, `documented_parse_credit_sheet()`.

**Causa raíz.** Una fila era encabezado de pregunta sólo si `all(is.na(values))`.
**Nueve de las 73 filas de encabezado de la hoja `%` llevan un numérico suelto** en
alguna columna de período (la fila 99, `10,2 - Ganadería`, lleva trece), y una
décima (`18,2`) se publica sin guion después del número. Esos encabezados se
consumían como respuesta de la pregunta anterior y **todo el bloque siguiente
heredaba la pregunta equivocada**: las respuestas de Ganadería se publicaban bajo
Agricultura y chocaban con las de Agricultura en el mismo trimestre, forzando a
ambas a identidad posicional.

**Nota sobre el alcance previo.** La entrada anterior de R52 estimaba el daño en
5 series espurias de una observación. Era correcta en la causa pero corta en el
alcance: esas 5 más **50 identidades posicionales y 25 grupos pregunta/respuesta en
conflicto**, que la auditoría externa había medido por separado y atribuido a una
dimensión institucional faltante que no existe.

**Arreglo.** El número de pregunta publicado es la única autoridad; se acepta
separador o espacio. Ninguna etiqueta de respuesta empieza con dígito y una fila de
respuesta real trae 46-54 valores, no uno o dos, así que el patrón decide solo.

**Evidencia.** `EXCEPT ALL` a nivel celda entre schema 12 y 13: **24 filas quitadas,
0 agregadas, ninguna otra fuente tocada**; las 24 caen en las nueve filas de
encabezado (76, 99, 109, 129, 144, 169, 199, 294, 339) y suman exactamente
1+13+1+2+1+2+2+1+1. Posicionales 50 → 0; grupos en conflicto 25 → 0; singletons 5 → 0.

**Cómo verificar que sigue cerrado:** `test-audit-p0-remediation.R`, bloque
"the credit-survey question axis is fully semantic"; y el conteo exacto de 312
series en `test-full-pipeline-smoke.R`.

---

## Cerrados en la ronda P0 de la auditoría técnica externa (2026-08-27)

Fuente: `Technical_Audit.docx`, auditoría externa de sólo lectura sobre la base
de producción. Antes de tocar nada se reverificó cada cifra del informe contra la
base real: **todas exactas** (28.417 `dim_series`, 1.216.910 `fact_series_events`,
12.630 `positional_lane` = 44,45%, 474 filas → 139 meses con 114/109/92 meses en
conflicto en FX compensatorias, 168 IDs de `bcp_fx_daily`, 2.760 de `eve`, 170 y
25.912 filas en `CUADRO 61`, 521 grupos de firma numérica idéntica, 565
observaciones futuras, 0 restricciones de clave foránea). Dos diferencias
inmateriales: el informe dice 28.417 mapeos de concepto (real 28.420 = 28.417
source-specific + 3 revisados) y 1.441 grupos de etiqueta repetida (contamos
2.521 con nuestra definición; el informe no publica la suya).

Alcance acordado con el usuario: **sólo los defectos P0 de parser/identidad** que
el informe nombra, más la compuerta de allowlist. Todo lo demás (P1/P2/P3 y la
arquitectura objetivo de la sección 9) queda explícitamente fuera.

Resultado global: `dim_series` 28.417 → 23.012; series de una sola observación
15.756 → 10.462; `positional_lane` 12.630 → 9.924; **cero** flags de severidad
`error`; observaciones conservadas fuente por fuente salvo los dos cambios
buscados (FX compensatorias −1.005 filas duplicadas, `CUADRO 61` +394 celdas que
antes no se leían). Migración `schema_version` 12 con reingesta dirigida.

---

### R48 — `documented_parse_compensatory_sales()` no cortaba cada bloque anual en el encabezado siguiente · silencioso · CERRADO
**Dónde:** `scripts/03_curate_expanded.R`, `documented_parse_compensatory_sales()`.
**Causa raíz:** la hoja `Ventas(DatosMensuales)` publica seis bandas de filas con
encabezados `AÑO 2015`…`AÑO 2025` en la **columna 1** y `AÑO 2016`…`AÑO 2026` en
la **columna 6** (filas 3, 21, 39, 57, 75, 93), doce filas de meses por bloque.
El parser hacía `possible_rows <- seq.int(month_row + 1L, nrow(text))` y luego
recorría hasta `max(active_rows)`: nunca se detenía en el encabezado siguiente,
así que el bloque 1 emitía 72 registros con año 2015, el bloque 2 sesenta con año
2017, y así (72/60/48/36/24/12 por grupo de columnas = 474 filas). El guard de
identidad repartía las colisiones en seis `lane_`.
**Alcance medido:** 3 medidas × 474 filas para 139 meses reales; valores en
conflicto en 114 meses (`Total Ventas`), 109 (`Compensatorias`) y 92
(`Complementarias`). Confirmado que `lane_1` de cada grupo de columnas contenía
por casualidad la serie correcta y `lane_2`..`lane_6` eran copias corridas de
año — pero se reparseó desde la fuente, no se eligió una lane.
**Arreglo (aplicado):** el bloque termina en la fila anterior al siguiente
`AÑO` de la **misma columna**, más un guard duro: ningún bloque anual puede
tener más de 12 filas de mes.
**Verificado:** 36 → 3 series, 417 observaciones, 139 meses distintos, **cero**
meses en conflicto; `Total = Compensatorias + Complementarias` en los 139 meses;
ninguna celda fuente alimenta dos observaciones. Contrastes contra celdas crudas:
2015-01 = 84,0 (fila 8), 2016-01 = 175,8, 2017-01 = 29,6 (fila 26).
**Exclusión documentada:** 5 celdas numéricas de la hoja (filas 114-118, columna
9) quedan fuera a propósito: son ceros de relleno en la columna de total para
ago-dic 2026, meses todavía no publicados (las columnas de componentes están
vacías). Incorporarlas inventaría observaciones futuras con valor cero.

---

### R49 — El slot estructural del guard de identidad usaba el eje equivocado en la encuesta de crédito · silencioso · CERRADO
**Dónde:** `scripts/03_curate_documented.R`, `documented_finalize_observations()`.
**Causa raíz:** la lista de modos "horizontales" estaba escrita literalmente
(`horizontal_date`, `horizontal_year`, `horizontal_year_quarter`) y
`credit_question_quarter` no estaba en ella, pese a ser un diseño horizontal
(trimestres a lo ancho, pregunta-respuesta a lo alto). Cuando dos filas
publicadas repetían el mismo par pregunta-respuesta, la desambiguación se hacía
por **columna** — lo que fija el período y deja **una observación por serie**.
**Alcance medido:** 2.500 series `positional_lane` + 34 `positional`, todas con
exactamente una observación (2.534 de las 2.805 de la fuente).
**Arreglo (aplicado):** la orientación se deriva de un único helper,
`documented_period_axis_is_horizontal()`, para que un parser horizontal nuevo no
pueda heredar el slot equivocado en silencio — es el defecto de clase, no el
caso puntual. Se agregaron `credit_question_quarter`, `credit_index_quarter` y
`horizontal_year_month` (este último latente: `CUADRO 57a` no colisiona hoy).
**Verificado:** `credit_survey` 2.805 → 321 series con las mismas 15.830
observaciones y la misma cobertura 2013-03 a 2026-06.

---

### R50 — `CUADRO 61` nombraba las series desde filas de datos · silencioso · CERRADO
**Dónde:** nuevo `documented_parse_fx_market_turnover()` en
`scripts/03_curate_documented.R`, despachado por
`parser_mode_override = fx_market_turnover` en `config/sheet_modes.csv`.
**Causa raíz:** el extractor genérico resolvía bien el eje de fechas de la hoja
(2.752 × 236, 29.119 celdas no vacías) pero nunca capturaba su encabezado de dos
niveles, así que tomaba etiquetas de filas de datos: 170 identidades cuyas
etiquetas eran concatenaciones de números (`221174 — 2534436.331676 — …`), el
100% `positional_lane`.
**Estructura real (verificada contra `report_cell_values`):** fila 10
`Compra`/`Venta`, fila 11 la institución por columna (`Bancos comerciales`,
`Casas de cambio`, `Financieras`, `Casas de cambios y financieras`, `Total`) para
las columnas 2-6 y 7-11; columna 1 es el eje de filas y mezcla 30 años sueltos,
28 filas `Ner. trim.` y 271 fechas mensuales. Desde julio de 2015 el desglose es
de **dos niveles**: un tipo de operación (`Spot y Efectivo`, `Arbitraje`,
`Operación Nominal`, `Forward`, `Canje`) y, bajo algunos de ellos, filas con
guion inicial por moneda (`- Dólar`, `- Euros`, …) o residencia
(`- Residentes`). El guion es el marcador de anidamiento del publicador: `Euros`
significa una cosa bajo `Arbitraje` y otra bajo `Operación Nominal`, así que el
padre tiene que quedar dentro de la identidad. La primera versión del parser
aplanó ese nivel y reintrodujo 80 `positional_lane`; el guard de ambigüedad que
ahora tiene el parser lo detectó.
**Arreglo (aplicado):** parser específico con guards duros sobre las dos filas de
encabezado, jerarquía padre-hijo en el eje de filas, y un guard final que aborta
si algún par (serie, frecuencia, período) aparece más de una vez — para que un
nivel de anidamiento no reconocido falle acá en vez de disolverse en lanes.
**Verificado:** 170 → 182 identidades (170 mensuales = 2 lados × 5 instituciones
× 17 desgloses, más 6 anuales y 6 trimestrales de los años tempranos), **100%
`semantic`**, 25.912 → 26.306 observaciones. Balance fuente-a-destino perfecto:
las 26.306 celdas numéricas de las columnas 2-11 producen exactamente 26.306
observaciones, cero sin explicar; las 301 de la columna 1 son el eje de años y
las 45 de las columnas 225-236 son un bloque duplicado suelto, ambos excluidos.
Reconciliación aritmética: los cinco tipos de operación suman el total del
período en 1.822 de 1.822 grupos, y las tres instituciones suman el `Total` en
350 de 350, dentro del 0,01%.

---

### R51 — El slug de hoja dentro de `series_id` se unificaba por posición · silencioso, no reportado por la auditoría externa · CERRADO
**Dónde:** `scripts/03_curate_documented.R`, `documented_finalize_observations()`,
construcción de `series_id`.
**Causa raíz:** `janitor::make_clean_names(.data$source_sheet)` se aplicaba a la
**columna repetida** de la tabla de identidades, y `make_clean_names()` unifica
duplicados **por posición**: `datos`, `datos_2`, … `datos_26`. Es la misma
familia que R46, un nivel más arriba. El sufijo no describe nada: depende de
dónde cayó la serie en la tabla, así que **insertar una columna aguas arriba
reasignaba la identidad de todas las series posteriores de esa hoja**, sin aviso.
**Evidencia de que ya mordía:** los únicos tres mapeos de concepto revisados por
humanos del proyecto estaban anclados exactamente a esos sufijos
(`interbank_market:datos_16`, `datos_26`, `datos_de_1_dia_10`).
**Por qué se arregló acá:** es bloqueante para R47 — al fusionar 14 hojas en un
grupo de continuación, la misma unificación habría producido
`op_divisas_datos_diarios_2 … _12` y refragmentado justo lo que R47 corrige.
Decisión del usuario: arreglarlo globalmente y reingerir todas las fuentes
documentadas.
**Arreglo (aplicado):** `documented_sheet_slug()` aplica `make_clean_names()` a
un valor por vez, así que el slug depende sólo del nombre de la hoja.
`config/concept_mappings.csv` se reescribió a los tres identificadores estables
(los hashes no cambian: se calculan sobre `stable_path|frequency`).
**Verificado:** 21.667 series documentadas, 221 hojas distintas, **cero**
discrepancias entre el slug almacenado y `make_clean_names(hoja)`. Un test de
regexp no sirve acá (hay nombres de hoja que terminan en dígitos: `CUADRO 61`,
`SIPAP_01`), así que el smoke test recalcula el slug y compara.

---

### R46 — `eve_parser()`: `slug(block)` recibe la columna ya materializada de `tibble()` · CERRADO
Diagnóstico completo más abajo (sección de la auditoría del inventario). El
arreglo es el que ese diagnóstico proponía: `block_slug <- slug(block)` y
`label_slug <- slug(label)` **antes** del `tibble()`.
**Verificado:** `eve` 2.760 → 16 series, mismas 2.760 observaciones, cobertura
completa 2006-04 a 2026-08, entre 108 y 245 observaciones por serie.
**Hallazgo secundario destapado por la reingesta:** `discarded_rows` no estaba en
ninguna de las funciones `invalidate_v*()`. Como `eve_parser()` reinserta los
mismos `discard_id` (direccionados por contenido) en cada pasada, reingerir un
vintage sin cambios abortaba con violación de clave primaria. Agregado a la
limpieza de `invalidate_v12_p0_identity_repairs()`.

---

### R47 — `bcp_fx_daily`: 14 hojas anuales de una misma serie diaria continua · CERRADO
**Arreglo (aplicado):** mecanismo general de continuación de hojas, no un caso
especial. `config/sheet_modes.csv` tiene una columna nueva `continuation_group`;
cuando está definida, `documented_finalize_observations()` usa ese valor en lugar
de `source_sheet` para `identity_basis`, el componente de hoja del `series_id` y
las claves de colisión. `source_sheet`, `source_row` y `source_column` quedan
intactos en cada observación, así que el linaje por hoja,
`documented_sheet_drift` y el camino a la celda cruda no cambian: las hojas
anuales siguen siendo alias, exactamente en el sentido que pedía la auditoría.
**Verificado:** 168 → 12 series diarias, 3.394 observaciones cada una, 3.394
fechas distintas, 2013-01-02 a 2026-08-14, y cada serie sigue apuntando a las 14
hojas de origen. Las fechas son disjuntas entre hojas, así que no aparece
ninguna colisión (serie, período) nueva.
**Pregunta abierta de R47, cerrada con evidencia:** `lrm_auctions` tiene también
14 hojas anuales pero **no** recibe grupo de continuación. Sus series son
`row_event_semantic` (3.044 de 3.083): cada fila es un resultado de subasta, no
un punto de una serie temporal. La auditoría externa es explícita en que las
tablas de eventos deben seguir siendo tablas de eventos (sección 5.3).

---

## Diagnóstico histórico de R45 y R52 — ambos CERRADOS en la ronda 2026-08-29

**Estas dos entradas quedan como registro del diagnóstico, no como pendientes.**
El arreglo, la evidencia y la verificación están arriba, en la ronda P0/P1/P2.
Dos correcciones al texto que sigue, que se conservan sin editar para no perder
la traza del razonamiento original:

- **R52 subestimaba el alcance.** El texto de abajo lo cifra en 5 series espurias
  de una observación. La causa raíz es correcta, pero el daño real incluía además
  50 identidades posicionales y 25 grupos pregunta/respuesta en conflicto, porque
  cada encabezado no reconocido arrastraba la pregunta equivocada a todo el bloque
  siguiente. No eran nueve filas con "un cero suelto": son nueve filas con entre
  uno y trece numéricos sueltos, más una décima (`18,2`) sin guion tras el número.
- **R45 estaba bien diagnosticado en sus dos mecanismos** y el arreglo aplicado es
  el que este texto propone.

### R52 — Una fila de encabezado de pregunta con un cero suelto se lee como respuesta · silencioso, residual, CERRADO 2026-08-29
**Dónde:** `scripts/03_curate_documented.R`, `documented_parse_credit_sheet()`,
rama de la hoja `%`.
**Síntoma:** el reconocimiento de encabezado de pregunta exige
`all(is.na(values))`. Una fila de encabezado que además trae un cero suelto no
pasa ese test, se toma como respuesta de la pregunta anterior y el encabezado
siguiente termina concatenado en la etiqueta, p. ej. `8 - Si su entidad
presentara un exceso de recursos… — 9 - Ordene las siguientes actividades…`.
**Alcance medido:** **5** series espurias, todas de una sola observación y valor
0 (períodos 2021-09-30 y 2023-12-31). Antes de R49 este residuo estaba escondido
entre las 2.539 series de una observación de la fuente; con R49 cerrado queda a
la vista.
**Por qué no se aplicó:** fuera del alcance P0 acordado — la auditoría externa
midió y nombró las 2.500 lanes + 34 posicionales (R49), no este residuo, que es
dos órdenes de magnitud menor. El arreglo natural (reconocer el patrón de
numeración de pregunta aun con valores presentes) tiene que decidir además qué
hacer con el cero suelto en vez de descartarlo en silencio.
**Anclado:** `tests/testthat/test-full-pipeline-smoke.R` afirma exactamente 5,
no un máximo, para que cualquier deriva en cualquier dirección se note.

---

### R45 — Bloque final de comparación interanual mal interpretado como columnas de período, en 8 hojas del Anexo · silencioso · CERRADO 2026-08-29
**Dónde:** `Cuadro 46a`, `Cuadro 46b`, `Cuadro 51a`, `Cuadro 51b`, `Cuadro 52a`,
`Cuadro 52b`, `Cuadro 53a`, `Cuadro 53b` de `economic_annex` (todas hojas de comercio
exterior por producto, mismo template de publicación). No reproducido en `CUADRO 61`
(hoja también con alta concentración `positional_lane`, pero por una causa distinta:
un encabezado repetido de entidad — `Bancos comerciales | Casas de cambio |
Financieras | ...` — que el parser genérico no captura como parte de la etiqueta;
ver `revisiones/MEJORAS_v11.md` sección 4, ítem de riesgo alto ya identificado).

**Síntoma:** cada una de estas 8 hojas tiene un eje mensual continuo normal (p. ej.
`Cuadro 53a`, columnas 2–392, enero 1994 a julio 2026) seguido de **7 columnas
adicionales** con un encabezado de comparación interanual, no de período:
`A Julio 2024 | A Julio 2025* | A Julio 2026* | Var. Nominal A Julio 2026/2025 |
Var. % A Julio 2026/2025 | Incidencia | Var. % Interanual Julio 2026/2025`
(fila 12 de `Cuadro 53a`, columnas 393–399; confirmado idéntico, con variaciones
menores de espaciado, en `Cuadro 46a` fila 12, `Cuadro 51a` fila 10, `Cuadro 52a`
fila 10). Ninguno de esos 7 encabezados es una fecha ni un año anotado reconocible
por `documented_year_values()`/`documented_date_axis_token()`, así que el parser no
los excluye del eje — pero tampoco logra asignarles un período propio, y las 7
observaciones de cada fila terminan **todas asignadas al mismo período**, el último
real de la hoja (`2026-07-01` en `Cuadro 53a`). El guard de identidad posicional
(correcto, funcionando como debe) detecta la colisión de 7 valores en la misma
`(fila, período)` y evita fusionarlos creando 7 `series_id` distintos en modo
`positional_lane` — pero el resultado visible es exactamente lo que se reportó:
"la misma fila de datos con 7 IDs distintos, sólo con años distintos en la
etiqueta visible del encabezado".

**Alcance medido** (vía `dim_series`/`fact_series_events`, base real):

| Hoja | Series positional_lane | Observaciones en el período final |
|---|---:|---:|
| Cuadro 53a / 53b | 1.160 cada una | 1.160 (100% de sus lane) |
| Cuadro 46a | 1.142 | 1.142 (100%) |
| Cuadro 46b | 1.140 | 1.140 (100%) |
| Cuadro 52a / 52b | 1.104/1.095 cada una | 1.104/1.095 (100%) |
| Cuadro 51a / 51b | 513/510 cada una | 513/510 (100%) |

En las 8 hojas, el 100% de las observaciones `positional_lane` caen exactamente en
el último período real de la hoja — ninguna excepción — lo que confirma que es un
único mecanismo, no ruido disperso. Suma aproximada: **7.812 series espurias** (de
las 8.214 `positional_lane` totales en `economic_annex`; las ~400 restantes están en
`CUADRO 61` y otras hojas menores, con causas distintas, ya catalogadas).

**No es lo mismo que R27/CUADRO 57a.** R27 y R40 trataban con años sueltos que
podían confundirse con datos numéricos dentro del eje real. Acá el eje mensual está
bien resuelto de punta a punta (367+24 columnas correctas) — el problema es
exclusivamente el bloque de comparación *después* del eje, que no es parte de la
serie temporal en absoluto (son estadísticas derivadas: acumulado a julio de cada
año, variación nominal, variación %, incidencia, variación interanual — todo
calculable a partir de la propia serie mensual, no observaciones nuevas).

**Precedente ya resuelto en el propio proyecto:** `Cuadro 49` tuvo exactamente esta
familia de problema en el **eje de filas** (resumen porcentual y nota al pie después
de las filas reales) y ya se resolvió truncando la extracción antes de esas filas
(`docs/REVISION_V10_RUNTIME_REPAIRS.md`, "excludes the following percentage-summary
and footnote rows from the time axis"). R45 es el mismo patrón en el **eje de
columnas** de estas 8 hojas — la solución natural es análoga: reconocer el
encabezado de comparación interanual (`^A `+mes+año, `Var\\.`, `Incidencia`) y
truncar el eje de columnas antes de esas 7, en vez de dejar que cada una intente
convertirse en una observación.

**Impacto en analítica:** no afecta los valores mensuales reales (están completos y
correctos); infla el conteo de `series_id` de estas 8 hojas en 7× lo necesario y
oculta 7 estadísticas derivadas legítimas (que el usuario final debería poder
recalcular de la propia serie mensual, no consultarlas como observaciones sueltas
con `series_id` opacos). Ver `revisiones/INVENTARIO_SERIES.md` para el detalle
completo con evidencia de coordenadas reales.

**Arreglo:** no aplicado — es un cambio de parser compartido
(`documented_extract_horizontal_time()` o el detector de eje de columnas genérico),
mismo nivel de riesgo que el ítem #4 de `revisiones/MEJORAS_v11.md` (ya excluido
explícitamente por el usuario de la ronda de mejoras de riesgo bajo/medio). Requiere
sesión propia con regresión completa sobre las 94 hojas antes de aplicar.

**Estado tras la ronda P0 de la auditoría externa (2026-08-27):** sigue abierto y
es el mayor foco restante de inflación del catálogo (7.812 de las 9.924 series
`positional_lane` que quedan). Quedó explícitamente fuera de alcance porque la
auditoría externa ubica el trabajo de comercio detallado en **P1** ("needs
remodeling", secciones 8.1 y 12), no en P0. Mientras tanto las 8 hojas están
marcadas `needs_remodeling` en `config/table_status.csv`, así que ninguna llega a
`v_research_series`. **Es el siguiente paso recomendado.**

---

#### CORRECCIÓN al diagnóstico de R45 (2026-08-27, forense sobre celdas crudas) — el defecto tiene DOS mitades, no una

El diagnóstico de arriba describe **la mitad** del problema. Antes de implementar
el arreglo se releyeron las celdas crudas de `Cuadro 53a` (vía
`report_cell_values`) y apareció un segundo mecanismo, más dañino, que el
diagnóstico original no menciona. **No aplicar el arreglo asumiendo sólo la
mitad documentada arriba: dejaría todas las series partidas en dos.**

**Layout real de `Cuadro 53a`** (idéntico en las 8 hojas, salvo desplazamientos
menores de fila/columna):

| Coordenada | Contenido |
|---|---|
| fila 12, cols 2–392 | eje mensual genuino, 1994-01-01 → 2026-07-01 (391 columnas) |
| fila 12, cols 393–399 | los 7 encabezados de comparación interanual ya catalogados arriba |
| **fila 13, cols 369–392** | **`*` y nada más** — marcador de dato provisional del publicador sobre los últimos 24 meses (ago-2024 a jul-2026) |

La fila 13 no aparece en el diagnóstico original. Es la que genera la segunda
mitad del defecto.

**Mecanismo 1 — eje de columnas sin cota derecha** (`scripts/03_curate_documented.R`,
`documented_extract_horizontal_time()` líneas 584-586 y 600). El bucle de arrastre
`for (j in seq.int(first_time_col, ncol(text)))` llega hasta la última columna de
la hoja, así que toda columna a la derecha de la última fecha real hereda el
período anterior (`period_values[[j]] <- period_values[[j - 1L]]`). En la línea
600, `time_cols <- which(!is.na(period_values))` termina siendo literalmente
`first_time_col:ncol(text)`. Las 7 columnas de comparación heredan `2026-07-01`.
Ésta es la mitad que el diagnóstico original describe correctamente.

**Mecanismo 2 — el marcador de provisionalidad entra en la identidad de la serie**
(mismas función, líneas 610 y 613). `documented_fill_right()` convierte el `*` de
la fila 13 en un sub-encabezado y `column_labels` lo transforma en `measure`, de
modo que las columnas 369–392 producen `series_label = "<fila> — *"` mientras las
columnas 2–368 producen `series_label = "<fila>"`. **Cada serie económica de estas
8 hojas queda cortada en dos en 2024-08.** Medido contra la base real:

```
Soja       — 367 observaciones, 1994-01-01 → 2024-07-01, identity_stability = semantic
Soja — *   —  31 observaciones, 2024-08-01 → 2026-07-01, identity_stability = positional_lane
```

Etiquetas `— *` afectadas por hoja: `Cuadro 52a`/`52b` 186 cada una, `53a`/`53b`
149, `46a`/`46b` 148, `51a`/`51b` 62 → **1.090 etiquetas en total**.

**Corrección a la medición original.** El diagnóstico de arriba afirma que el 100%
de las observaciones `positional_lane` cae en el último período real de la hoja.
Es incorrecto: caen en el rango **2024-08 → 2026-07** (24 períodos). La razón es
que `lane_required`, en `documented_finalize_observations()`, se evalúa por
`axis_collision_key` — la serie entera — no por período. En cuanto `Soja — *`
colisiona en 2026-07-01 (su valor genuino de julio más los 7 heredados de las
columnas de comparación), **los 24 meses** de esa serie escalan a
`positional_lane`. De ahí también el 31 = 24 meses reales + 7 columnas de
comparación.

**Qué implica para el arreglo.** Acotar el eje de columnas **no alcanza**: elimina
las 7 columnas espurias pero deja cada serie partida en dos en 2024-08, que es el
daño analítico mayor (rompe rezagos, tasas de variación y muestras justo en el
tramo más reciente). El arreglo necesita las dos mitades:

1. **Cota derecha del eje**, siguiendo el precedente ya resuelto del eje de filas
   en `documented_extract_vertical_date()` (líneas 498-517): compuerta de token
   con `documented_date_axis_token()` más arrastre acotado a la última columna con
   token válido. Ojo: `documented_date_axis_token()` está anclado `^...$`, así que
   `A Julio 2026*` y `Var. % Interanual Julio 2026/2025` no lo pasan — es
   exactamente la discriminación que hace falta.
2. **El marcador de nota al pie no puede entrar en la etiqueta.** Debe rutearse al
   campo `footnote_marker` que `documented_series_snapshot` ya tiene, con el
   precedente de `documented_year_footnote()` y `CUADRO 57a` (ver R40). Es
   información editorial legítima —"provisional, sujeto a revisión"— y hoy se está
   perdiendo como tal a la vez que corrompe la identidad.

**Regresión obligatoria antes de aceptar el cambio:** ambas mitades tocan el
extractor horizontal genérico, compartido por todas las hojas del Anexo y de
`payments`. Hay que correr el extractor sobre las 94 hojas antes y después y
diferenciar serie por serie, verificando en particular que ninguna hoja pierda
columnas de datos legítimas ubicadas a la derecha de la última fecha del
encabezado.

---

### R46 — `eve_parser()`: `slug(block)` recibe la columna ya materializada de `tibble()`, no el escalar del loop — 2.760 "series" son en realidad 16 · silencioso · CERRADO (diagnóstico original; el cierre está arriba, ronda P0 2026-08-27)
**Dónde:** `scripts/03_curate_special.R`, dentro de `eve_parser()` (función completa
~línea 142-206), específicamente la construcción de:
```r
records[[k]] <- tibble(
  ..., date = dates[keep], block = block, variable = label, value = vals[keep],
  ...,
  series_id = paste("eve", slug(block), slug(label), sep = ":")
)
```
**Mecanismo exacto** (confirmado con `trace(slug, ...)` contra una llamada real a
`eve_parser()`, no especulado): dentro de un mismo `tibble(...)`, las columnas se
evalúan en orden y una expresión posterior puede referirse a una columna ya
creada por el propio `tibble()` en lugar de a la variable externa del mismo
nombre. Como el argumento `block = block` ya crea una columna llamada `block`
(reciclada a la longitud de `date`, p. ej. 245 fechas), la expresión siguiente
`slug(block)` **ya no ve el escalar del loop** — ve la columna recién creada,
un vector de 245 elementos idénticos ("Bloque de Inflación" repetido 245 veces).
`slug()` (`janitor::make_clean_names()`) genera nombres *únicos* por posición
para desambiguar un vector, así que convierte esos 245 valores idénticos en
`bloque_de_inflacion`, `bloque_de_inflacion_2`, ..., `bloque_de_inflacion_245` —
y cada uno pasa a formar parte de un `series_id` distinto. `slug(label)` no sufre
esto porque la tibble sólo define una columna `variable = label`, nunca una
columna llamada literalmente `label`, así que no hay colisión de nombre.
**Por qué queda oculto:** el resultado se clasifica `identity_stability =
'semantic'` (no `positional_lane`) porque desde el punto de vista del guard de
identidad cada `series_id` es, en efecto, estable y único — el guard no tiene
forma de saber que 245 IDs "estables" deberían haber sido uno solo. No aparece
en ningún filtro de revisión existente.
**Alcance medido:** las 2.760 series de `eve` (100% de la fuente) son en realidad
**16 indicadores reales** (`SELECT COUNT(DISTINCT label) FROM v_series_catalogue
WHERE source_id='eve'` → 16), cada uno con entre 108 y 245 observaciones mensuales
genuinas fragmentadas en igual cantidad de `series_id` de una sola observación.
Confirmado también en `bcp_fx_daily` que el guard clasifica sus 168 series como
100% `semantic` pese a ser 12 indicadores × 14 años (ver R47) — la clasificación
`semantic` no es garantía de "una fila = una serie útil".
**Arreglo (no aplicado):** trivial y de bajo riesgo — computar
`block_slug <- slug(block); label_slug <- slug(label)` **antes** del `tibble()`
(o simplemente reordenar para que `series_id` no comparta nombre de columna con
ninguna variable local), y usar esos escalares dentro. No toca ningún otro
llamador de `slug()` (el único otro uso, en `icc_parser()`, no tiene esta
colisión de nombres). Requiere reprocesar `eve` una vez (invalidación dirigida a
esa fuente) y verificar que las 16 series resultantes tengan la cobertura
temporal completa 2006-2026 antes de aceptar el cambio.

---

### R47 — `bcp_fx_daily`: el publicador divide una serie diaria continua en una hoja por año; el pipeline no la vuelve a unir · menor, diseño de identidad · CERRADO (diagnóstico original; el cierre está arriba, ronda P0 2026-08-27)
**Dónde:** `input/current/bcp_fx_daily/*.xlsx` tiene 14 hojas, una por año
(`OpDivisas2013(DatosDiarios)` … `OpDivisas2026(DatosDiarios)`), cada una con las
mismas 12 etiquetas ("Compra del BCP — Sector Financiero", "Venta del BCP — Total",
etc.). Como `series_id` incluye la hoja de origen como parte de su identidad
(mismo patrón que toda `documented_series_snapshot`), cada etiqueta se convierte en
14 `series_id` distintos — 12 × 14 = 168, confirmado exacto contra la base real.
**Diferencia con R45/R46:** acá no hay ningún error de parseo ni de identidad —
las 14 hojas son, en los datos fuente, genuinamente hojas separadas; el pipeline
está describiendo la estructura real del archivo con precisión. El "defecto", si
se lo quiere corregir, es de diseño: no existe hoy un mecanismo para decirle al
pipeline "estas N hojas son continuaciones cronológicas de la misma serie, uní los
`series_id` a través de ellas" — lo mismo que ya identificó
`revisiones/MEJORAS_v11.md` ítem #4 para las 9 hojas "a/b" de `economic_annex`,
pero acá con años en vez de cortes a/b.
**Arreglo:** no aplicado — mismo nivel de riesgo que el ítem #4 (cambiaría
`series_id` de series existentes sin mecanismo de migración de vintages). Antes de
tocarlo, valdría la pena revisar si `lrm_auctions` (14 hojas también año por año,
pero con ratio series/label de sólo 4.4, no 14.0) esconde el mismo patrón para
alguna de sus columnas agregadas — no investigado en esta ronda.

---

## Cerrados en la ronda de mejoras post-v11 (abiertos al cierre de la v11)

### R41 — Alias sin `AS` en una consulta del propio smoke test · menor · CERRADO
**Dónde:** `tests/testthat/test-full-pipeline-smoke.R:78` —
`SELECT COUNT(*) rows FROM documented_series_snapshot GROUP BY 1,2 HAVING COUNT(*) >
1`. `rows` es palabra reservada en DuckDB sin `AS`, misma familia que R26 pero en el
test, no en producción. Esa aserción específica del smoke test no podía ejecutarse
tal como estaba escrita.
**Arreglo (aplicado en la sesión de mejoras post-v11):** `COUNT(*) AS rows`. Además
se agregó `tests/testthat/test-sql-alias-hygiene.R`, un guard permanente que escanea
`scripts/` buscando la misma familia de alias sin `AS` contra palabras reservadas de
DuckDB, para que R26/R41/R44 no tengan un cuarto episodio.

---

### R42 — El guard de fecha global no reconoce el horizonte de proyección ya revisado para `economic_annex` · menor · CERRADO
**Dónde:** chequeo `implausible_semantic_date_range` en `validate_database()`
(`scripts/04_validate.R`), sobre `fact_series_events` agregado de todas las fuentes.
Con `CUADRO 57a` resuelto, la corrida completa dejaba **una sola** quality flag de
severidad `error`: *"Semantic observations span 1945-12-31 to 2028-12-01"*. El
contrato específico de `economic_annex` (`config/documented_source_contracts.csv`,
`maximum_future_days=1000`) ya aceptaba el horizonte de proyección revisado de
`Cuadro 49` (hasta 2028-12-01) — pero el guard **global** de `validate_database()`
seguía con un techo más angosto (`Sys.Date() + 400`, ~fines de 2027) fijo e
independiente, así que la misma fecha que el contrato de la fuente ya aceptaba como
legítima seguía marcándose como error a nivel base completa.
**Arreglo (aplicado):** `validate_database()` ahora lee
`config/documented_source_contracts.csv` y usa
`Sys.Date() + max(400, contratos$maximum_future_days, na.rm=TRUE)` como techo, en
vez de la constante fija — sube el techo global sólo lo necesario para no
contradecir ningún contrato de fuente ya revisado, sin debilitar el guard para el
resto (que se quedan con el default de 400 si no tienen fila propia en el CSV).
**Verificado:** `run_tests.R` completo, `test-full-pipeline-smoke.R:14`
(`result$status == "completed_with_errors"` ahora `FALSE`) en verde.

---

### R43 — Incompatibilidad de API de `testthat`: `info=` ya no es un argumento válido en varios `expect_*` · menor, sólo test suite · CERRADO
**Dónde:** 7 usos de `info = ...` en `tests/testthat/test-v10-runtime-repairs.R` y
`tests/testthat/test-v9-ingestion-repairs.R`. De los 7, sólo 2 rompían realmente con
`testthat` 3.3.2 instalado (confirmado con `formals()`): `expect_no_error()` y
`expect_gt()` no aceptan `info=` en esta versión; `expect_identical()` y
`expect_equal()` sí lo aceptan — los otros 5 usos nunca fallaron.
**Arreglo (aplicado):**
`test-v10-runtime-repairs.R:13`: se quitó `info = sheet` de `expect_no_error()` (sin
sustituto directo en esta expectativa; el loop es corto, el nombre del test alcanza
para identificar el contexto). `test-v9-ingestion-repairs.R:119`: `expect_gt(nrow(finalized), 0L, info = source_id)`
reemplazado por `expect_true(nrow(finalized) > 0L, info = source_id)`, que sí acepta
`info=` y preserva la identificación por fuente dentro del loop de 3 specs.
**Verificado:** `run_tests.R` completo, ambos archivos en verde.

---

### R44 — `create_market_views()` falla con "window expression is not supported" en dos fixtures sintéticos de test · menor, no reproducido con datos reales · CERRADO
**Dónde:** `scripts/03_curate_expanded.R:528-547`, invocada sin condición desde
`initialize_database()`. Disparaba en `test-identity-and-archive.R:101`/`:120` —
ambos tests arman una base sintética mínima antes de llamar `initialize_database()`.
**Causa raíz encontrada** (el catálogo original decía "no determinado"): los dos
tests crean `source_files` con sólo 3 columnas
(`vintage_id, source_id, ingestion_status`) *antes* de llamar
`initialize_database()`. Como la tabla ya existe, el
`CREATE TABLE IF NOT EXISTS source_files (...)` de `initialize_database()`
(línea 352, con `publication_date DATE` incluido) es un no-op — nunca agrega esa
columna. Ninguno de los `ensure_table_column(con, "source_files", ...)` existentes
cubría `publication_date`. `create_market_views()` hace
`ORDER BY publication_date DESC NULLS LAST, ...` dentro de un `row_number() OVER
(...)` — al no existir la columna, el binder de DuckDB reporta el críptico "window
expression is not supported here" en vez de "column not found" (reproducido en
aislado: agregar la columna faltante hace pasar la misma vista sin tocar su SQL).
**Arreglo (aplicado):** `ensure_table_column(con, "source_files", "publication_date", "DATE")`
agregado junto a los demás `ensure_table_column` de esa tabla
(`scripts/02_extract_raw.R`).
**Hallazgo secundario, destapado por este arreglo:** con el crash resuelto, ambos
tests avanzaron más allá y expusieron 2 aserciones obsoletas
(`needs_v4_reingestion`/`needs_v5_reingestion`) que nunca se actualizaron cuando se
agregaron las migraciones v6-v11. Verificado contra el código real de los 5
`invalidate_v*_*()`: el comportamiento actual es correcto por diseño —
`invalidate_v8_ingestion_repairs()` re-incluye `bank_reference` explícitamente
(`OR source_id = 'bank_reference'`), y `economic_annex` está listado en cada
migración posterior (v6, v8, v9, v10) — una base genuinamente vieja debe cascadear
por todas las que le aplican, no detenerse en la primera. Aserciones corregidas a
`needs_v9_reingestion`/`needs_v11_reingestion` en `tests/testthat/test-identity-and-archive.R`.
**Verificado:** `run_tests.R` completo, `test-identity-and-archive.R` en verde.

---

### R39 — Regresión nueva: migración v2→v3 referencia una columna inexistente · menor (bajo impacto real, alta claridad de señal)
**Dónde:** `scripts/02_extract_raw.R:97`, dentro de
`invalidate_v6_documented_identity()`. La consulta usa
`dim_series ... AND semantic_status = 'documented_series'`; DuckDB responde que esa
columna no existe (candidatos: `mapping_status`, `hierarchy_status`,
`identity_stability`, `scale`, `identity_basis`). Test que lo dispara:
`test-identity-and-archive.R:62` ("schema-v2 curated outputs are invalidated before
v3 reingestion") — pasaba limpio en v9, falla en v10. No se determinó si el cambio
de fondo fue en el orden de migraciones encadenadas o en el fixture del test.
**Cómo verificar que sigue cerrado:** `run_tests.R`, contexto
`identity-and-archive`, sin errores de tipo "Binder Error" por columna inexistente.
**Arreglo:** revisar si `invalidate_v6_documented_identity()` debería usar otra
columna, o si el fixture sintético de ese test necesita actualizarse.

---

### R24 — No hay lector de formato largo para el alcance original (FMI) · pendiente de alcance
Sin cambios desde v9. El mecanismo `long_csv` funciona bien para
`corporate_bond_curves`/`securities_trades`; el alcance original (FMI WEO/IFS/BOP)
sigue sin ninguna fuente conectada.

---

### R25 — La maquinaria de conceptos nunca se ejerció con contenido · menor · CERRADO
**Corrección (2026-08-29):** esta entrada estaba desactualizada. `config/concept_mappings.csv`
dejó de tener sólo el encabezado en la ronda post-v11: lleva tres filas revisadas
sobre `concept:interbank_repo_rate_pyg` (un `aggregate` y dos `component`), así que
la ruta de mapeo revisado sí se ejerce con contenido real. La capa canónica que
la ronda P0/P1/P2 agregó (`canonical_series`, `map_canonical_series`) es la que
queda vacía a propósito, y por una razón distinta: poblarla es revisión económica.

---

### R30 — RETRACTADO: no era un defecto, era un error de comparación propio de esta auditoría
Sostenido erróneamente como abierto durante cuatro rondas (v8, v9, v10, v11). El
número de `CLAUDE.md` (246.547) cuenta las filas físicas de la hoja **incluyendo el
encabezado**; `raw_banks_eeff` (246.546) correctamente **no** incluye el encabezado
como fila de datos. Verificado de forma independiente, fuera del pipeline:
`readxl::read_excel(path, sheet="EEFF")` da `nrow() = 246.546`, y
`246.546 + 1 (encabezado) = 246.547`. Los dos números siempre fueron consistentes
entre sí — la discrepancia era una comparación entre "filas físicas de la hoja" y
"filas de datos en la tabla curada" sin reconciliar qué contaba cada uno, no un bug
del pipeline. `docs/AUDITORIA_REGRESIONES.md` (el registro propio del proyecto,
agregado en v11) lo describe correctamente: *"the raw table contains exactly
worksheet rows minus one header."* Corrijo el registro acá con la misma vara que le
pido al proyecto: verificar antes de sostener un hallazgo, y decirlo claro cuando el
error es propio.

---

## Cerrados — batería de regresión

Confirmá en cada revisión que ninguno volvió.

| id | Defecto | Sev. | Cerrado en | Cómo verificar que sigue cerrado |
|---|---|---|---|---|
| R1 | El archivo histórico se recopiaba en cada corrida | operativo | v2 | Correr dos veces seguidas: `input_archive/` no debe crecer |
| R2 | `release_id` sin reproducibilidad | silencioso | v2 | Dos corridas idénticas → mismo `release_id`; `ingestion_runs` no duplica filas |
| R3 | Parser de operaciones cambiarias descartaba 521/558 filas | silencioso | v2 | `fx_operations_snapshot` ≥ 5.480 filas, tres frecuencias |
| R4 | Sin guard de estructura; parsers con filas fijas | silencioso | v2 | Copia con fila de título insertada → corrida se detiene nombrando la hoja |
| R5 | `report_cells` presentado como cobertura sin fechas/unidades | operativo | v5 | `semantic_coverage WHERE semantic_status='inventory_only'` = 0 |
| R6 | Exigía exactamente 1 archivo por carpeta | operativo | v2 | `resolve_source_files()` (`01_utils.R:92-104`): 2 archivos con `allow_multiple=FALSE` → elige el más nuevo por mtime, warning, no abort |
| R7 | Sin diccionario de entidades | operativo | v3 (y de nuevo v9/v10, causas distintas) | `dim_entity WHERE entity_name IS NULL AND entity_type IN ('bank','finance_company')` = 0; `bank_reference` y `exchange_houses` cargan |
| R8 | `xml_attr(node,"id",ns="r")` devolvía NA | bloqueante | v3 | `xlsx_sheet_dimensions()` resuelve todas las hojas sin error |
| R9 | Filtro tautológico en guard de bancos/financieras | bloqueante | v3 | Ambas fuentes cargan; `assert_direct_structure()` pasa |
| R10 | Fechas EVE 25.569 días en el futuro | silencioso | v3 | MIN/MAX `eve_expectations_snapshot` dentro de 2006-04-01 → hoy |
| R11 | Parser ICC fallaba en seco con fechas seriales | bloqueante | v3 | ICC carga; ≥1.236 filas; fechas desde 2018-01-31 |
| R12 | Specs YAML con acentos no leían fuera de UTF-8 | operativo | v3 | `LC_ALL=C Rscript -e 'read_parser_spec(...)'` no falla — verificado explícito en v10 |
| R13 | Código de moneda 6200 etiquetado USD siendo guaraníes | silencioso | v4 | `dim_currency` 6200 ⇒ FX/PYG; 6900 ⇒ PYG/PYG — cuarta corrida seguida sin cambios |
| R14 | Smoke test con conteos exactos de series crecientes | menor | v4 | Smoke test usa `expect_gte`/`expect_gt`, no `expect_equal` |
| R15 | `bank_reference` requerido con carpeta vacía | operativo | v3 | Libro presente en `input/current/bank_reference/` |
| R16 | Esquema de referencias dependía de nombres autogenerados | menor | v4 | Resolución usa hoja + firma de columnas |
| R17 | Números de cuenta en notación científica | silencioso | v4 | Ningún `map_statement_account` con `e+` |
| R18 | `report_cells` copiaba full por vintage | operativo | v4 | `report_sheet_vintages`: enlaces > versiones distintas |
| R19 | Identidad de series documentadas inestable (unit/currency en el hash) | silencioso | v7, guard de continuidad operativo desde v10 (ver R26) | `series_id` no incluye unit/currency; `identity_stability` expuesto; guard de continuidad como error duro, funcional |
| R20 (parcial) | Jerarquía no modelada en series documentadas | silencioso | mínimo viable en v7, sin cambios desde entonces | `documented_hierarchy_unresolved` como warning vía `sheet_modes.csv`; nivel/padre real sigue sin modelarse — dejar abierto conceptualmente, cerrado el mínimo |
| R21 | Sin validación de coherencia unidad/escala | menor | v7 | `unit IN (index,percent,ratio,count) AND scale<>'units'` = 0, con guard duro |
| R22 | Excepción de hoja hardcodeada en el detector genérico | menor | v7 | `documented_mode()` sin `if (source_sheet=="CUADRO 57a")`; vive en `sheet_modes.csv` |
| R23 | Smoke test fija el número de fuentes | menor | v7 | Conteo esperado derivado de `registry %>% filter(required)` |
| R26 | Guard de continuidad de identidad crasheaba por palabra reservada de SQL (`label` sin `AS`) | bloqueante | v10 | `AS source_sheet`, `AS label` en `04_validate.R:287-288`; test de regresión con dos vintages reales agregado por el proyecto |
| R27 | `documented_year_values()` aceptaba cualquier entero 1900-2100 sin contexto posicional ni secuencia | silencioso | v11 (cerrado de fondo; parcial en v10) | Patrón de año anotado estricto + `documented_year_axis_counts()` exige secuencia ordenada con saltos ≤10 (`03_curate_documented.R:61-86`); `Cuadro 49` y `CUADRO 58` sin fechas implausibles. Ver R40: el mismo endurecimiento generó una regresión colateral puntual en `CUADRO 57a`, no del mismo tipo de bug |
| R38 | El pipeline no arrancaba: variable sin definir en `invalidate_v9_runtime_repairs()`, disparada incluso en bootstrap desde cero | bloqueante, alcance total | v11 | `fresh_bootstrap` calculado antes de insertar `schema_version` y usado para condicionar cada `invalidate_v*_*()` (`02_extract_raw.R:333-462`); `affected_concepts` también corregido puntualmente. `Rscript -e 'source("run_update.R")'` corre sin parche, 21/22 fuentes cargan |
| R28 | `exchange_houses`: hojas "vacías por fórmulas" rompían el parser por desacople `readxl`/`xlsx_sheet_dimensions` | bloqueante, fuente requerida | v10 | `content_bounds` por defecto ahora `last_row=0L,last_col=0L` (`01_utils.R:300`); las 10 hojas cargan, 6.164 celdas, exacto contra CLAUDE.md |
| R29 | `documented_parse_row_events()` no distinguía depósito de repo en `liquidity_facility` | silencioso | v10 | Parámetro `block_patterns` con guard duro; base real: 3.650 obs. "deposito", 2 "repo", ambas con `operation_type:` en la etiqueta |
| R31 (ex-"defecto 1", informe v8) | `xlsx_named_table_catalog()` no encontraba la tabla nombrada (XPath `.//` sobre el nodo raíz) | bloqueante | v9 | Las 15 tablas de `bank_reference` resuelven `table_range`/`source_table` sin NA; fuente carga completo |
| R32 (ex-"defecto 2", informe v8) | Hoja totalmente vacía rompía `cells_from_matrix()` (tibble sin columna `row_id`) | bloqueante | v9 | Tibble tipada de 0 filas devuelta explícitamente cuando no hay celdas |
| R33 (ex-"defecto 3", informe v8) | `which(str_detect(matriz), arr.ind=TRUE)` perdía las dimensiones de la matriz | bloqueante | v9 | `matrix_predicate()`/`matrix_detect()`/`matrix_equal()` en `01_utils.R`; `compensatory_fx_sales` carga completo |
| R34 (ex-"defecto 4", informe v8) | `documented_month_number()` no reconocía "set" (setiembre) | bloqueante | v9 | `set = 9L` en el mapa; `financial_indicators` carga completo |
| R35 (ex-"defecto 5", informe v8) | `documented_quarter_number()` aceptaba un dígito suelto como trimestre | silencioso | v9 | Regex exige prefijo `T` o sufijo `trim`; test de orientación ya no falla |
| R40 | `CUADRO 57a` sin observaciones tras el endurecimiento general de R27 — el eje de años requería ≥2 valores distintos incluso para hojas de un solo año reseñado | silencioso en origen | v11 (parche aplicado en esta sesión, fuera del ciclo normal de subida) | Nuevo campo `year_axis_minimum` en `config/sheet_modes.csv`, hilado a través de `documented_sheet_rule()` → `documented_extract_generic_sheet()` → `documented_extract_horizontal_year_month()` → `documented_year_axis_counts()`; `CUADRO 57a=1`. Verificado: 12 observaciones correctas para la hoja; barrido completo de las 94 hojas sin ceros ni fechas implausibles; `economic_annex` carga completo (94 hojas, 700.262 celdas, CUADRO 8 min 1950-12-31 — exacto contra CLAUDE.md) |
| R36 (ex-"defecto 6", informe v8) | Seis fuentes chocaban contra el guard de claves duplicadas por identidad de serie incompleta | silencioso (contenido por el guard) | v9 | `credit_survey`, `direct_investment`, `interbank_market`, `lrm_auctions`, `liquidity_facility` cargan; mecanismo `identity_stability='positional_lane'` para duplicados legítimos |
| R37 (ex-"hallazgo aparte", informe v8) | Una fuente corrupta podía tumbar toda la corrida (detección de dimensiones fuera del `tryCatch` por fuente) | operativo, contradice garantía central del proyecto | v9 | Detección de dimensiones movida adentro del `tryCatch` (`06_pipeline.R:64-79`), bandera `transaction_open`; test dedicado `test-v9-ingestion-repairs.R:177` corrompe un zip a propósito |

---

## Errores que este proyecto ya cometió, como lista de control

Patrones que aparecieron más de una vez. Al revisar código nuevo, buscalos primero:

1. **Fechas de Excel convertidas con el origen equivocado**, seriales leídos como
   texto, o valores numéricos confundidos con años/trimestres por rango sin contexto
   posicional. Apareció en EVE, ICC; R27 se cerró cuadro por cuadro en v10
   (`Cuadro 49`), reapareció en `CUADRO 58` esa misma ronda, y se cerró de fondo en
   v11 — pero ese mismo endurecimiento de fondo generó una regresión colateral
   puntual en `CUADRO 57a` (R40). Cuatro apariciones de la misma familia.
2. **Metadata inferida por expresión regular usada como si fuera un hecho** —
   unidades, escalas, monedas, identidad de evento (R29, cerrado en v10). Cuando
   entra en una clave, se vuelve un problema de identidad (R19).
3. **Validaciones que no pueden fallar, o que fallan por la razón equivocada** — el
   filtro tautológico de R9 fue el caso extremo; R26 (cerrado en v10) fue la
   variante "guard correcto interrumpido por un error ajeno".
4. **Agregados tratados como si fueran componentes** — el total anual entre los
   meses, el código `6200 + 6900` junto a sus partes, los subtotales de balanza de
   pagos.
5. **Una misma trampa de origen, resuelta a medias varias veces seguidas** —
   `exchange_houses` y sus hojas "vacías por fórmulas" llevaron tres bugs distintos
   en tres revisiones (R32 en v9, R28 cerrado de fondo en v10). Cuando una trampa ya
   documentada en CLAUDE.md sigue generando bugs nuevos después de "cerrada", vale
   la pena un test que ejercite la trampa completa contra el archivo real.
6. **Refactors que copian un bloque de código sin copiar la línea de la que
   depende** — R38 (`affected_concepts` sin definir) es el ejemplo más caro de este
   patrón hasta ahora: tumbó el pipeline completo, no una fuente. Cuando se copie el
   cuerpo de una función de invalidación/migración para crear la siguiente versión,
   revisar qué variables usa que se calculan *antes* del bloque copiado.
7. **Guards de migración que no distinguen bootstrap-desde-cero de migración-real**
   — R38 se disparaba incluso contra una base recién creada porque `schema_version`
   pasa por todas las versiones intermedias durante el bootstrap. Cerrado en v11 con
   una bandera `fresh_bootstrap` calculada una sola vez, antes de cualquier inserción
   — el arreglo correcto era arquitectónico, no puntual.
8. **Un arreglo general y bien pensado tiene efecto colateral en la hoja que ya
   necesitaba trato especial** — R40 es el segundo caso de este patrón (el primero
   fue R22/`CUADRO 57a` con la excepción hardcodeada). Cuando una hoja ya está
   marcada como caso especial en `sheet_modes.csv`, cualquier endurecimiento de una
   función genérica que esa hoja también usa merece una verificación puntual aparte,
   no sólo la corrida completa del contrato mínimo.
