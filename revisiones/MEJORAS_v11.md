# Mejoras y propuestas — pipeline BCP (post-v11)

Informe separado de la auditoría de defectos. Acá no hay nada roto — es lo que un
ingeniero R con contexto de todo el proyecto y una mirada macroeconómica agregaría,
sacaría o cambiaría de rumbo, ahora que el pipeline carga las 22 fuentes limpio por
primera vez. Todo lo verificado abajo se comprobó contra el código y/o la base real,
no es una lista de ideas sin chequear.

---

## 0. Antes que nada: una corrección propia

Sostuve durante cuatro rondas de auditoría (`revisiones/REVISION_v8...v11.md`) que
`raw_banks_eeff` tenía "una fila de menos" contra la verdad conocida de `CLAUDE.md`
(246.546 contra 246.547). **No era un defecto — era mi propia comparación mal
planteada.** `CLAUDE.md` cuenta filas físicas de la hoja Excel *incluyendo el
encabezado*; la tabla curada correctamente *no* cuenta el encabezado como una
observación. `246.546 + 1 = 246.547`. Lo verifiqué de forma independiente con
`readxl::read_excel()` directo sobre el archivo real, sin pasar por el pipeline.
Ya corregí el registro en `AUDITORIA_REGRESIONES.md` (R30). Lo repito acá porque la
misma vara con la que reviso el proyecto tiene que aplicarse a mi propio trabajo, y
porque es relevante para la recomendación de la sección 3.

---

## 1. Lo más urgente: dos registros de auditoría en paralelo, con numeración que colisiona

`docs/AUDITORIA_REGRESIONES.md` es un registro que el propio proyecto generó en v11
(mencionado en el CHANGELOG como "reconstructed regression-audit documentation"),
independiente del `AUDITORIA_REGRESIONES.md` de la raíz que esta auditoría externa
viene manteniendo desde v9. Los dos:

- Usan **la misma numeración (R1-R35+) para contenido distinto** a partir de R26 —
  por ejemplo, su R27 describe el arreglo de fechas de `Cuadro 49` (lo que este
  informe llama "R27, cerrado en v10/v11"), mientras que este archivo abrió un R27
  propio con contenido relacionado pero no idéntico. Es cuestión de tiempo hasta que
  alguien cite "R27" y ambos documentos digan cosas distintas.
- Su entrada **R31 es la más valiosa de las dos versiones** en un punto concreto:
  explica correctamente el mecanismo de Bancos EEFF (*"the raw table contains
  exactly worksheet rows minus one header"*) — la explicación que a esta auditoría
  externa le tomó cuatro rondas encontrar por su cuenta (ver sección 0). Vale la
  pena leerlo, no descartarlo.
- Su entrada **R31 (numeración propia) también repite el error inverso en algún
  punto**: describe el estado como cerrado sin que quien lo escribió necesariamente
  haya corrido el pipeline contra los 22 archivos reales de punta a punta —
  compárese con el hecho de que esta auditoría *sí* encontró `CUADRO 57a` roto en la
  misma versión que ese documento describe como completamente resuelta.

**Recomendación concreta:** consolidar en un solo archivo, con una sola numeración,
antes de que la próxima ronda tenga que reconciliar tres fuentes de verdad en lugar
de dos. Si el equipo quiere mantener su propio registro en inglés y este informe
seguir en español, al menos deberían compartir los IDs — o usar prefijos distintos
(`R#` para esta auditoría, `BR#` para el registro interno del equipo, por ejemplo)
para que nunca colisionen por accidente.

**Aplicado.** `docs/AUDITORIA_REGRESIONES.md` reemplazado por un stub corto que
apunta al `AUDITORIA_REGRESIONES.md` canónico de la raíz, preservando el crédito
por la explicación de Bancos EEFF que ese archivo tenía correcta. Una sola fuente
de verdad activa desde ahora.

---

## 2. Automatizar el contraste contra `CLAUDE.md` en vez de repetirlo a mano cada ronda

Cada una de las cinco rondas de esta auditoría gastó tiempo comparando manualmente
la base resultante contra la tabla de "verdad conocida" de `CLAUDE.md` (94 hojas,
700.262 celdas, 1.236 obs. de ICC, etc.). Es exactamente el tipo de chequeo que
debería vivir en `run_tests.R`, no en la cabeza de quien audita. El propio
`test-full-pipeline-smoke.R` ya hace parte de esto (líneas como la de CUADRO 8/9) —
la propuesta es completar la cobertura para **todas** las filas de la tabla de
`CLAUDE.md`, no sólo las que alguien recordó agregar:

```r
# tests/testthat/test-known-truth.R (propuesta)
testthat::test_that("economic_annex matches the last verified publication counts", {
  ...
  testthat::expect_equal(sheets, 94)
  testthat::expect_equal(cells, 700262)
})
# repetir para payments (40/57.683), exchange_houses (10/6.164),
# banks (9 hojas; 20 entidades), financial (8 hojas; 9 entidades), etc.
```

Esto convierte cinco rondas de trabajo manual en un chequeo de segundos que corre
cada vez que alguien ejecuta `run_tests.R` — y hubiera detectado, por ejemplo, que
`economic_annex` no cargaba en v9/v10/v11 sin necesitar una auditoría externa para
notarlo.

**Aplicado.** `tests/testthat/test-full-pipeline-smoke.R` extendido con aserciones
exactas (no mínimos) contra `semantic_coverage` para `economic_annex` (94/700.262),
`payments` (40/57.683) y `exchange_houses` (10/6.164), más conteos de hojas y de
entidades de bancos/financieras (9/20, 8/9) vía `raw_banks_eeff`/`raw_financial_eeff`
— no `dim_entity`, que es acumulativo, no del ciclo actual (ver sección 0).
Reverificado contra la base reconstruida desde cero en esta sesión: exacto.

---

## 3. Versionar el proyecto con git

No hay repositorio git en este directorio. Cada ronda de esta auditoría gastó los
primeros minutos comparando `mtime` de archivos para reconstruir "qué cambió desde
la vez pasada" — un sustituto pobre de `git diff`/`git log`, que además no distingue
un archivo tocado de un archivo genuinamente modificado en contenido. Con git:

- El CHANGELOG dejaría de ser la única fuente de "qué se tocó" — se podría verificar
  directamente qué funciones cambiaron entre v10 y v11.
- Los `revisiones/REVISION_v*.md` podrían referenciar el commit exacto auditado,
  no sólo un número de versión de CHANGELOG.
- Revertir un cambio puntual (como el que causó R40, `CUADRO 57a`) sería trivial en
  vez de tener que re-diagnosticar desde cero.

Esto no es una preferencia estética — se sintió directamente como fricción real en
cada una de las cinco rondas de esta auditoría.

**Aplicado.** `git init` + `.gitignore` extendido (`input/current/*`, sumado a los
patrones ya existentes para `database/`, `outputs/`, `input_archive/`) + commit
inicial (`4198632`) como línea de base post-fix de `CUADRO 57a`. Excluye
deliberadamente todos los directorios de datos; `.git` se mantiene liviano (~550K).

---

## 4. Reducir la dependencia en "positional lane" mejorando la identidad de origen, no sólo tolerándola

**Fuera de alcance en esta ronda — riesgo alto, excluido explícitamente por el
usuario.** Reescribir la identidad de estas 9 hojas cambiaría el `series_id` de
~9.000 series sin un mecanismo de migración de vintages existente. Queda como
recomendación abierta para una ronda futura con alcance propio.

El mecanismo de `identity_stability = 'positional_lane'` (agregado en v9-v10) es un
diseño genuinamente bueno — convierte una posible fusión silenciosa de observaciones
distintas en algo explícito y trazable. Pero **10.607 series de `economic_annex`
existen, y 8.982 de ellas (85%) están en modo posicional**, concentradas en 9 hojas:

| Hoja | Series en modo posicional |
|---|---|
| Cuadro 53a | 1.160 |
| Cuadro 53b | 1.160 |
| Cuadro 46a | 1.142 |
| Cuadro 46b | 1.140 |
| Cuadro 52a | 1.095 |
| Cuadro 52b | 1.095 |
| Cuadro 51a | 510 |
| Cuadro 51b | 510 |
| CUADRO 61 | 170 |

Esto no es una falla — el guard está haciendo exactamente lo que tiene que hacer.
Pero es una señal fuerte de que estas 9 hojas específicas tienen una dimensión real
(probablemente país, entidad, o sector, a juzgar por el patrón "a/b" en los nombres —
posiblemente activos vs. pasivos, o dos cortes de la misma tabla) que el parser
genérico no está capturando como parte de la etiqueta. El caso de `CUADRO 58`
(encontrado en v10) y el de `direct_investment/Cuadro 2` (encontrado en v8) eran
exactamente este patrón — y ya existe la solución de referencia:
`documented_extract_horizontal_time()` sí arma `column_labels` desde subencabezados;
`documented_extract_horizontal_year_quarter()` no. Vale la pena revisar
puntualmente estas 9 hojas — es probable que unas pocas horas de trabajo dirigido
reduzcan la dependencia en modo posicional de "la mayoría de la fuente más grande
del proyecto" a un puñado de casos genuinamente ambiguos.

---

## 5. Configuración muerta: `liquidity_facility` en `sheet_modes.csv`

`config/sheet_modes.csv` tiene `liquidity_facility,*,row_event_table,...` — pero el
despacho real de esa fuente en `documented_source_parser()` llama a
`documented_parse_row_events()` **directamente**, sin pasar por
`documented_extract_generic_sheet()` ni leer `rule$parser_mode_override` en ningún
momento. El valor `row_event_table` en esa fila nunca se lee. No rompe nada — es
simplemente código de configuración que quedó de una versión anterior del despacho y
nadie lo limpió. Vale la pena o (a) borrar esa columna para esa fila, o (b) si el
despacho *debería* mirar `sheet_modes.csv` para decidir el modo (más consistente con
cómo se resuelven `interbank_market`/`compensatory_fx_sales`), conectarlo de verdad.

**Aplicado — opción (a).** `parser_mode_override` vaciado para esa fila, con nota
explicando por qué no se lee, para que no se reintroduzca por confusión. Conectar el
despacho de verdad (opción b) se deja como mejora futura, no era parte de este
alcance de bajo/medio riesgo.

---

## 6. `documented_measure_metadata()`: el wrapper escalar ya no tiene a quién servir

Confirmé que **ningún camino de producción** llama a `documented_measure_metadata()`
(el wrapper escalar de compatibilidad de la vectorización de v8) — sólo
`tests/testthat/test-documented-source-helpers.R` lo usa, como atajo para probar un
caso a la vez. Está bien mantenerlo *como utilidad de test* (es cómodo), pero el
comentario que lo describe como "compatibility wrapper" ya no es preciso — no hay
ningún llamador de producción con el que sea compatible. Vale la pena o renombrarlo
a algo como `documented_measure_metadata_single()` para que el nombre diga lo que
realmente es hoy (un helper de test), o simplemente dejar un comentario que aclare
que ya no lo usa producción.

**Aplicado.** Renombrado a `documented_measure_metadata_single()` en su definición y
en los 5 call sites de `test-documented-source-helpers.R`; comentario actualizado
para dejar de decir "compatibility wrapper". `grep -rn "documented_measure_metadata("`
no devuelve resultados fuera de la nueva definición.

---

## 7. Higiene de SQL: evitar la familia de bugs "alias sin `AS`" de raíz

Van tres apariciones de la misma clase de bug en esta serie de auditorías: `label`
(R26), `rows` (R41, todavía abierto) y, aunque de naturaleza distinta,
`row_number() OVER (...) rn` cerca de R44. DuckDB tiene una lista de palabras
reservadas que colisiona con nombres comunes de columna (`label`, `rows`, y
probablemente otras que todavía no aparecieron: `order`, `group`, `column`, `date`
son candidatas típicas). Ya que el patrón sigue reapareciendo pese a corregirse cada
vez puntualmente, dos opciones concretas:

- **Barata:** un test que recorra todos los `.R` de `scripts/` con una regex simple
  buscando `\)\s+[a-z_]+\s+FROM` (una función seguida de un identificador sin `AS`) y
  falle si encuentra un alias que coincida con la lista de palabras reservadas de
  DuckDB. No atrapa todo, pero atraparía exactamente los tres casos que ya
  aparecieron.
- **Más robusta:** adoptar como convención de equipo "todo alias lleva `AS`, sin
  excepción" y hacerlo parte de la revisión de cualquier PR que toque SQL crudo.

**Aplicado.** R41 corregido (`COUNT(*) AS rows`). Nuevo
`tests/testthat/test-sql-alias-hygiene.R`: escanea los `.R` de `scripts/` buscando
literales SQL con alias sin `AS` que coincidan con una lista de palabras reservadas
de DuckDB (incluye `label`, `rows`, y las candidatas típicas — `order`, `group`,
`column`, `date`, etc.). Documentado en el propio test que es una heurística dirigida
a la clase exacta de bug de R26/R41/R44, no un parser SQL general.

---

## 8. Rendimiento: dónde ya no hay más para sacar fácil, y dónde sí

La vectorización de v8 (`documented_measure_metadata_vectorized()`,
`documented_enrich_metadata()`) fue un arreglo correcto y bien medido — el pipeline
completo pasó de ~50 minutos a ~4-5 minutos. Con el estado actual:

- `economic_annex` sigue siendo la fuente más lenta (~120-130 segundos) — es
  esperable dado que son 94 hojas y ~700.000 celdas de lectura real de Excel; no
  parece haber una ganancia fácil ahí sin cambiar de librería de lectura.
- Si en algún momento el tiempo total vuelve a ser un problema, el candidato natural
  para la siguiente ronda de optimización es paralelizar la lectura **entre**
  fuentes independientes (no dentro de una fuente) — cada fuente ya corre en su
  propia transacción aislada, así que en principio nada impide correr 2-3 fuentes
  en paralelo con `future`/`furrr` sobre conexiones DuckDB separadas, mergeando al
  final. No lo propongo como urgente — 4-5 minutos totales es razonable — sólo como
  la dirección obvia si alguna vez hace falta.

**Fuera de alcance en esta ronda — riesgo alto, excluido explícitamente por el
usuario.** Paralelizar entre fuentes chocaría con el modelo de escritura de DuckDB
si no se hace con sumo cuidado; queda como dirección abierta, no urgente, para
cuando el tiempo total de corrida vuelva a ser un problema real.

---

## 9. Sugerencias con sombrero de macroeconomista

Estas son más de fondo que de código — pensando en qué necesitaría alguien
consultando esta base para hacer análisis macro real, no sólo en que el pipeline
corra sin errores.

### 9.1 Capturar el marcador de "dato provisorio/revisado", no descartarlo
`CUADRO 57a` mostró algo que se repite en varias hojas del Anexo: años y valores con
un asterisco (`"2021*"`) u otras marcas de nota al pie. Hoy, en todos los puntos
donde se parsean años/fechas (`documented_year_values()`, `documented_date_axis_token()`),
esas marcas se reconocen sólo para *permitir* el match y después se descartan
silenciosamente — la información de "esto es un dato provisorio, sujeto a revisión"
que el BCP publicó a propósito se pierde en el camino. Para una base que existe
justamente para preservar *vintages* y saber "qué se decía en tal fecha", perder la
marca de provisionalidad es tirar información editorial real. Vale la pena un campo
explícito (`is_provisional`/`footnote_marker`) en `documented_series_snapshot` en vez
de descartar la marca en el regex.

**Aplicado.** Columna `footnote_marker` (nullable) en `documented_series_snapshot`;
`documented_year_footnote()` (`scripts/03_curate_documented.R`) reutiliza el mismo
patrón que `documented_year_values()` ya calculaba y descartaba, sin inventar
detección nueva; poblado en `documented_extract_horizontal_year_month()`, el único
punto con evidencia real confirmada (`CUADRO 57a`, 12 observaciones con
`footnote_marker='*'`). Verificado contra las 94 hojas de `economic_annex`: cero
errores, cero hojas en cero, cero fechas implausibles nuevas.

### 9.2 Base del índice vs. año base de precios constantes: son conceptos distintos, hoy comparten un campo
`index_base` (capturado de títulos tipo "Base diciembre 2017 = 100") es el concepto
correcto para series de índice. Pero el "año base" de una serie a precios
**constantes** (el corte que `CLAUDE.md` ya señala como trampa: "PIB constante
2014") es un concepto relacionado pero distinto — no es una base 100, es el año cuyos
precios se usan para valorar cantidades de otros años. Hoy esa información, si
aparece, queda mezclada en el texto libre de `series_label`/`table_title`, no en un
campo estructurado. Alguien construyendo una serie larga de PIB real corre el riesgo
de pegar dos tramos con distinta base de precios sin que ningún campo se lo marque.
Vale la pena un campo `price_base_year` separado de `index_base`.

**Aplicado, con evidencia real verificada primero.** Antes de escribir el regex se
buscó el patrón contra los 94 títulos reales de `economic_annex`: aparece de forma
consistente ("guaraníes constantes de 2014") en Cuadro 1/2/6/6a/7/7a — exactamente
los cuadros de PIB — y en ningún otro lugar de forma espuria. Columna
`price_base_year` (nullable) agregada tanto a `documented_series_snapshot` como a
`dim_series` (a diferencia de `footnote_marker`, éste es un atributo a nivel serie,
no por observación, así que se lo llevó también a la dimensión — mismo tratamiento
que ya recibe `index_base`). El escritor compartido de `dim_series`
(`ensure_series_dimension()`, `scripts/03_curate_special.R`) para fuentes que no
son `documented` (ICC, EVE, operaciones cambiarias) sigue funcionando sin cambios:
recibe `NA` por default, verificado explícitamente. `CUADRO 1`: 756/756
observaciones con `price_base_year='2014'`; barrido completo de las 94 hojas sin
regresiones.

### 9.3 El ajuste estacional no está modelado como dimensión
Si el BCP publica versiones desestacionalizadas junto a las originales de algún
indicador (común en series de actividad económica tipo IMAEP), hoy esa distinción
—si existe en el archivo fuente— sólo sobrevive como texto libre dentro de la
etiqueta, no como un campo consultable. No alcancé a confirmar si el Anexo actual
efectivamente publica ambas versiones de algún indicador — vale la pena revisarlo
puntualmente — pero si las publica, es exactamente el tipo de distinción que
alguien haciendo análisis de coyuntura necesita poder filtrar de forma confiable, no
adivinar por el texto de la etiqueta.

**Investigado, no implementado — sin evidencia.** Se buscó contra los 94 títulos
reales de `economic_annex` (`documented_table_catalog.table_title`, la misma fuente
usada para confirmar 9.2) con los patrones `desestacionalizad`, `tendencia.?ciclo`,
`\bSA\b` y `serie original`: **cero coincidencias** en las 94 hojas. El Anexo
Estadístico actual, tal como está publicado en `input/current/`, no distingue series
originales de desestacionalizadas en el texto de sus títulos — no hay campo que
agregar todavía porque no hay nada que capturar. Si una publicación futura sí lo
hace, o si otra fuente (no revisada acá) lo publica, el mismo patrón aditivo de 9.1
y 9.2 aplica directo. Documentado en vez de construir un campo sin evidencia.

### 9.4 La capa de conceptos (R25) es la pieza que más valor macro agregaría, y sigue vacía
De las tareas pendientes, ésta es la que más cambia lo que esta base *puede hacer*
para alguien de macro, no sólo cómo de bien ingiere Excel. Con 22 fuentes ya
cargando y series con identidad estable (`series_id`), el siguiente paso natural es
empezar a poblar `config/concept_mappings.csv` con 3-5 equivalencias reales y
revisadas — por ejemplo, si el tipo de cambio de referencia aparece tanto en
`exchange_rates` como en `bcp_fx_daily` con series_id distintos, esa es una
equivalencia real y verificable, no una inferencia automática (que el proyecto
explícitamente evita, con buen criterio). Cargar un puñado de casos reales
probaría el mecanismo con evidencia — que es exactamente lo que R25 pide desde hace
varias versiones — y empezaría a convertir 22 fuentes aisladas en una base
consultable por concepto económico, no sólo por fuente publicada.

**Aplicado, con un candidato distinto y mejor evidenciado que el propuesto
originalmente.** El candidato de este párrafo (`exchange_rates` vs. `bcp_fx_daily`,
ambos "USD") se descartó ya en la planificación: la primera es la cotización
comprador/vendedor, la segunda es volumen de intervención del BCP en millones de
USD — no son el mismo concepto pese a la etiqueta similar, es exactamente el tipo de
trampa que la exigencia de evidencia real está pensada para evitar. Se buscó en
cambio por `unit`+`scale`+`frequency` idénticos entre series con etiquetas
relacionadas, y apareció un caso más limpio **dentro de** `interbank_market`: la
serie combinada "Mercado Interbancario de Fondos CMM + REPO Interbancario + REPO
Tripartito (PYG) — Tasa Promedio (%)" nombra explícitamente su propia composición en
la etiqueta publicada por el BCP, incluyendo "REPO Interbancario" como uno de sus
tres componentes — que además existe como serie propia, en dos hojas distintas
(`Datos` y `Datos (+ de 1 día)`), con el mismo `unit`/`scale`/`frequency`
(percent/units/daily). Se cargaron 3 filas bajo un mismo `concept_id`
(`concept:interbank_repo_rate_pyg`): 1 `aggregate` + 2 `component`, con evidencia
citando la etiqueta exacta del BCP. Verificado contra `apply_reviewed_concept_mappings()`
real: las 3 filas pasan todos los guards (relación permitida, evidencia/revisor/fecha
completos, sin colisión con el prefijo reservado `concept:source:`) y quedan en
`map_series_concept` con `mapping_status='reviewed'`.

### 9.5 Lo que ya está bien y vale la pena no tocar
La convención de cotización cambiaria (`PYG_per_USD`, siempre guaraníes por unidad
de moneda extranjera, nunca al revés) es consistente en todas las fuentes que la
usan — `exchange_rates`, `bcp_fx_daily`, `eve`. Es la convención de cotización
directa estándar para Paraguay y está aplicada de forma uniforme; no hay nada que
cambiar acá, sólo vale la pena señalarlo para que nadie lo "corrija" por accidente
en una futura refactorización.

---

## 10. Resumen priorizado

| # | Propuesta | Esfuerzo estimado | Valor |
|---|---|---|---|
| 1 | Consolidar los dos registros de auditoría en uno | bajo | alto — evita confusión activa, ya está pasando |
| 2 | Test de "verdad conocida" automatizado | medio | alto — reemplaza 5 rondas de trabajo manual futuro |
| 3 | Versionar con git | bajo (una vez) | alto — cambia la naturaleza de cada auditoría futura |
| 4 | Revisar las 9 hojas de mayor identidad posicional en `economic_annex` | medio-alto | alto — 85% de la fuente más grande del proyecto |
| 7 | Test/convención contra alias SQL sin `AS` | bajo | medio — ya causó 3 bugs reales |
| 9.4 | Poblar `concept_mappings.csv` con casos reales | medio | alto de fondo — es la pieza que hace esto "una base macro", no sólo un cargador de Excel |
| 5, 6 | Limpiar configuración/código muerto puntual | bajo | bajo-medio — higiene, no urgente |
| 8 | Paralelizar entre fuentes | medio | bajo hoy, medio si el tiempo vuelve a importar |
| 9.1, 9.2, 9.3 | Campos estructurados para provisionalidad / base de precios / ajuste estacional | medio-alto cada uno | alto de fondo, ninguno urgente hoy |
