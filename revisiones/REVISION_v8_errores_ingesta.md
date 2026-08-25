# Errores encontrados en la ingesta — pipeline BCP v8

Informe focalizado: qué se rompe al correr el pipeline contra los 22 archivos reales de
`input/current/`, con la causa exacta y el arreglo propuesto para cada uno. No es todavía
la revisión formal completa (falta el recorrido contra `AUDITORIA_REGRESIONES.md`, el
contraste completo con la tabla de verdad conocida de CLAUDE.md, y las pruebas de
mutación de guards) — eso sigue en curso por separado.

**Cómo se verificó todo lo que sigue:** corriendo `run_tests.R` y `run_update.R` contra
los 22 archivos reales en este entorno, y reproduciendo cada falla de forma aislada
(cargando sólo los scripts necesarios, invocando la función exacta sobre el archivo real,
capturando el *call stack* con `withCallingHandlers`/`sys.calls()` en el punto del error).
Cuando el mecanismo lo permitía, se confirmó con una repetición mínima fuera del pipeline
(ver defecto 3). Nada de esto es lectura de código sin ejecutar.

---

## Resumen

De las 22 fuentes del registro, **11 no cargan** en esta corrida:

| Fuente | Error observado | Defecto |
|---|---|---|
| `bank_reference` | `Can't guess format of this cell reference: NA` | #1 |
| `exchange_houses` | `Column 'row_id' not found in '.data'` | #2 |
| `exchange_rates` | `invalid argument type` | #3 |
| `compensatory_fx_sales` | `invalid argument type` | #3 |
| `financial_indicators` | `character string is not in a standard unambiguous format` | #4 |
| `economic_annex` | `Documented-series key guard: 3279 duplicate series-period keys` | #6 |
| `credit_survey` | `Documented-series key guard: 1108 duplicate series-period keys` | #6 |
| `interbank_market` | `Documented-series key guard: 546 duplicate series-period keys` | #6 |
| `direct_investment` | `Documented-series key guard: 16 duplicate series-period keys` | #6 |
| `lrm_auctions` | `Documented-series key guard: 21 duplicate series-period keys` | #6 |
| `liquidity_facility` | `Documented-series key guard: 14 duplicate series-period keys` | #6 |

`bank_reference` es una fuente **requerida** (el libro de referencias de bancos y
financieras); sin ella, los códigos de entidad de `banks`/`financial` quedan sin nombre
— exactamente el síntoma que R7 (`AUDITORIA_REGRESIONES.md`) daba por cerrado, aunque
por una causa nueva y distinta.

---

## Defecto 1 — `bank_reference` no carga: XPath no encuentra la tabla nombrada

**Severidad:** bloqueante · fuente requerida.
**Archivo:línea:** `scripts/03_reference_semantics.R:31` (`xlsx_named_table_catalog()`).

**Qué pasa:** cada `xl/tables/tableN.xml` dentro de un `.xlsx` es un documento cuyo
**elemento raíz es `<table>`** — los atributos `ref` (rango) y `displayName` están en ese
nodo raíz, no en un descendiente. El código busca:

```r
table_node <- xml2::xml_find_first(table_doc, ".//*[local-name()='table']")
```

`.//` busca **descendientes** del nodo de contexto, y como `<table>` es el nodo raíz —
no un descendiente de sí mismo — la búsqueda nunca encuentra nada y devuelve
`xml_missing`. Cualquier atributo leído de un nodo missing da `NA`.

**Cómo se verificó:** reproducido en aislado sobre
`input/current/bank_reference/Referencias_bancos_financieras.xlsx`:

```r
node <- xml2::xml_find_first(doc, ".//*[local-name()='table']")
# {xml_missing}
xml2::xml_attr(xml2::xml_root(doc), "ref")
# "B16:F125"   <- el atributo SÍ está ahí, sólo no se encuentra con esa XPath
```

Las 15 tablas nombradas del libro real (`table1.xml`…`table15.xml`) dan
`source_table = NA`, `table_range = NA`. Ese `NA` llega a
`readxl::read_excel(path, range = NA)`, que es exactamente el error de producción:
*"Can't guess format of this cell reference: NA"*.

También lo confirma el test ya existente del proyecto,
`tests/testthat/test-structure-guards.R:66` ("reference workbook populates verified
dimensions"), que falla con el mismo síntoma al correr contra el archivo real.

**Nota sobre R7:** `AUDITORIA_REGRESIONES.md` cerró R7 ("sin diccionario de entidades")
verificando que el libro de referencias esté presente en `input/current/`. Está
presente — el defecto no es de archivo faltante, es de parseo. El síntoma final
(entidades de bancos/financieras sin nombre) es el mismo que R7 describía.

**Arreglo propuesto:** la búsqueda tiene que incluir el nodo raíz, no sólo sus
descendientes. Dos opciones simples:

```r
# Opción A — usar el root directamente, sin XPath relativo:
table_node <- xml2::xml_root(table_doc)

# Opción B — XPath absoluta que sí matchea el elemento raíz:
table_node <- xml2::xml_find_first(table_doc, "/*[local-name()='table']")
```

---

## Defecto 2 — `exchange_houses` no carga: hoja vacía rompe el layer crudo

**Severidad:** bloqueante · fuente requerida.
**Archivo:línea:** `scripts/02_extract_raw.R:452-467` (`cells_from_matrix()`) →
`report_sheet_version_id()` (línea ~470).

**Qué pasa:** `cells_from_matrix()` recorre cada columna de la hoja; si una columna
**no tiene ninguna celda de texto no vacía**, hace `next` y nunca asigna nada a
`records[[j]]` para esa columna. Si **todas** las columnas de la hoja están así —
exactamente la trampa que `CLAUDE.md` ya documenta para esta fuente: *"4 hojas son
vistas con fórmulas, vacías al leer"* — `records` queda como una lista de puros `NULL`,
y `dplyr::bind_rows(records)` devuelve un tibble de **0 filas y 0 columnas** (sin
siquiera una columna `row_id`, porque no hay ningún elemento con esquema del cual
inferirla). Ese tibble sin columnas llega a
`report_sheet_version_id()`, que hace `dplyr::arrange(.data$row_id, ...)` — y ahí
truena: *"Column `row_id` not found in `.data`"*.

**Cómo se verificó:** reproducido con una matriz sintética completamente vacía:

```r
data <- tibble::tibble(a = as.list(rep(NA,5)), b = as.list(rep(NA,5)), c = as.list(rep(NA,5)))
cells <- cells_from_matrix(data)   # 0 x 0
report_sheet_version_id(cells, "exchange_houses", "TestSheet")
# ! Column `row_id` not found in `.data`.
```

Mensaje idéntico, carácter por carácter, al de la corrida real.

**Nota adicional:** al reproducir el flujo completo de `exchange_houses` sin pasar por
el layer crudo, aparece un **segundo bug latente e independiente** en
`documented_parse_exchange_panel()` (`scripts/03_curate_documented.R`, alrededor de la
línea 876): `period[[r]]` puede quedar fuera de rango del vector `period` dentro del
loop de construcción de observaciones (`subscript out of bounds`). No se manifiesta en
producción sólo porque el defecto 2 lo bloquea antes — pero va a aparecer en cuanto se
arregle el primero, conviene resolver los dos juntos.

**Arreglo propuesto:** `cells_from_matrix()` debe devolver una tibble **tipada
explícitamente** cuando no hay celdas, en vez de dejar que `bind_rows()` infiera el
esquema de una lista vacía:

```r
cells_from_matrix <- function(data) {
  empty <- tibble(row_id = integer(), column_id = integer(),
                   raw_value_text = character(), raw_value_num = double(),
                   raw_value_date = as.Date(character()))
  records <- vector("list", ncol(data))
  for (j in seq_along(data)) { ... }
  result <- bind_rows(records)
  if (!nrow(result) && !ncol(result)) return(empty)
  result
}
```

---

## Defecto 3 — Dos fuentes mueren por el mismo bug: `which(..., arr.ind=TRUE)` sobre una matriz que dejó de ser matriz

**Severidad:** bloqueante · dos fuentes requeridas (`exchange_rates`,
`compensatory_fx_sales`).
**Archivo:línea:** `scripts/03_curate_expanded.R:97-99` (`documented_parse_daily_exchange_rates`)
y `scripts/03_curate_expanded.R:219-220` (`documented_parse_compensatory_sales`).

**Qué pasa:** las tres líneas siguientes tienen la misma forma:

```r
month_anchors <- which(stringr::str_detect(normalized, month_pattern), arr.ind = TRUE)      # línea 97
year_hits     <- which(stringr::str_detect(normalize_semantic_label(text), "..."), arr.ind = TRUE)  # línea 219
month_hits    <- which(normalize_semantic_label(text) == "meses", arr.ind = TRUE)            # línea 220
```

`normalized`/`text` **son matrices**. Pero `stringr::str_detect()` (y
`normalize_semantic_label()`, construida sobre funciones de `stringr`/`stringi`) no
preserva el atributo `dim` — devuelve un vector plano. `which(x, arr.ind = TRUE)`
**ignora `arr.ind` si `x` no es un array** (así lo documenta `?which`), así que en vez
de una matriz de columnas `row`/`col` se obtiene un vector entero simple. `nrow()` de
ese vector es `NULL`, y `!NULL` en R no da `logical(0)` como podría esperarse — da un
error real: `"invalid argument type"`. Eso ocurre en **toda** invocación, con o sin
coincidencias — no es un caso límite, la función está rota siempre que se la llama.

**Cómo se verificó**, aislado, sin nada del proyecto:

```r
m <- matrix(c("enero/2020","x","y","z"), nrow=2, ncol=2)
detected <- stringr::str_detect(m, "enero")
dim(detected)          # NULL  <- la matriz perdió sus dimensiones
which(detected, arr.ind = TRUE)   # vector plano, no matriz
nrow(which(detected, arr.ind = TRUE))  # NULL
!NULL                              # Error: invalid argument type
```

Mismo mensaje exacto que en producción para `exchange_rates` (hoja "Cotizaciones
Diarias") y `compensatory_fx_sales` (hoja completa).

**Arreglo propuesto:** reconstruir las dimensiones antes de buscar posiciones, en las
tres líneas:

```r
hits <- matrix(stringr::str_detect(as.vector(text), pattern), nrow = nrow(text), ncol = ncol(text))
month_anchors <- which(hits, arr.ind = TRUE)
```

Como el patrón se repite tres veces en dos funciones distintas, vale la pena un
helper compartido (`matrix_which(m, predicate_fn)`) en `01_utils.R` en vez de parchear
cada sitio por separado — es el tipo de bug que va a reaparecer si se sigue escribiendo
`which(str_detect(matriz, ...), arr.ind=TRUE)` a mano en nuevos parsers.

---

## Defecto 4 — `financial_indicators` no carga: "set" no está en el mapa de meses

**Severidad:** bloqueante (aquí) / de fondo es un vacío de datos, no un bug de lógica.
**Archivo:línea:** `scripts/03_curate_documented.R:42-53` (`documented_date_matrix()`)
usa `documented_month_number()`, definida en `scripts/03_curate_documented.R:67-88`.

**Qué pasa:** `documented_date_matrix()` reconoce fechas de texto tipo "Ene-20" con esta
expresión regular (línea 44):

```r
"^(ene|feb|mar|abr|may|jun|jul|ago|sep|set|oct|nov|dic)[- /]([0-9]{2}|[0-9]{4})$"
```

`set` — la abreviatura de septiembre común en español rioplatense/paraguayo,
distinta de la abreviatura inglesa `sep` — está en la lista de tokens aceptados por
la regex. Pero el mapa de `documented_month_number()` sólo conoce `sep`, `sept`,
`setiembre` y `septiembre` — **no `set` sola**:

```r
sep = 9L, sept = 9L, setiembre = 9L, septiembre = 9L, ...
```

Cuando el texto real trae "Set-20" (o similar), `documented_month_number("set")`
devuelve `NA`. Esa `NA` llega a `month_end(year, NA)`, que arma
`sprintf("%04d-%02d-01", year, NA)` — y `sprintf("%02d", NA)` en R produce el texto
literal `"NA"`, así que el resultado es algo como `"2020-NA-01"`. `as.Date()` sobre
eso lanza exactamente el error observado: *"character string is not in a standard
unambiguous format"*.

**Cómo se verificó:** reproducido en aislado sobre el archivo real de
`financial_indicators`; el *call stack* capturado con `sys.calls()` muestra la cadena
completa `documented_date_matrix → month_end → as.Date → charToDate`.

**Arreglo propuesto:** agregar `set = 9L` (y de paso `sept = 9L` ya está, pero conviene
revisar si faltan otras variantes cortas usadas en los boletines del BCP) al `map` de
`documented_month_number()`.

---

## Defecto 5 — `documented_quarter_number()` confunde números de columna con trimestres

**Severidad:** silencioso — el más importante de este informe, porque no siempre se
nota (a veces cae en el guard del defecto 6, pero no siempre).
**Archivo:línea:** `scripts/03_curate_documented.R:97` (dentro de
`documented_quarter_number()`).

**Qué pasa:**

```r
numeric_match <- stringr::str_match(key, "^(?:t)?([1-4])(?:er|do|ro)?(?:\\s*trim(?:estre)?)?$")
```

Todos los calificadores son opcionales: el prefijo `T`, el sufijo ordinal (`er/do/ro`)
y la palabra `trim(estre)`. Eso significa que un simple dígito suelto — "1", "2", "3"
o "4" — matchea como trimestre **aunque no diga nada de trimestre**. Cualquier fila u
columna con números de orden, notas al pie, o índices de columna del 1 al 4 corre el
riesgo de ser leída como Q1–Q4.

**Cómo se verificó:** es exactamente lo que rompe el test existente del proyecto,
`tests/testthat/test-documented-source-helpers.R:27` ("documented orientation
classification covers recurring layouts"), que arma una tabla con una fila de índices
genéricos `1,2,3,4,5` y espera `documented_mode(...) == "horizontal_year"`; con el
código actual da `"horizontal_year_quarter"` porque esa fila de índices genéricos
pasa el umbral de `quarter_row >= 3`.

**Por qué importa más que un test roto:** `documented_mode()` es el clasificador
genérico que decide cómo se lee **la mayoría** de las 22 fuentes (todo lo que pasa por
`documented_extract_generic_sheet()`). Si clasifica mal la orientación de una hoja,
el parser correcto ni se llama — se llama el equivocado, silenciosamente, y asigna
fechas/trimestres donde no corresponde. Es plausible que esto explique — al menos en
parte — por qué `direct_investment` (que sí usa el modo `horizontal_year_quarter`)
produce columnas distintas colapsando al mismo trimestre en el defecto 6.

**Arreglo propuesto:** exigir al menos un calificador real (la `T` inicial o la
palabra "trim"), no aceptar el dígito pelado:

```r
numeric_match <- stringr::str_match(key, "^(?:t([1-4])(?:er|do|ro)?|([1-4])\\s*trim(?:estre)?)$")
```

(o equivalente: cualquier forma que rechace `"1"` sola y siga aceptando `"T1"`,
`"1er trim"`, `"1trim"`).

---

## Defecto 6 — Seis fuentes chocan contra el guard de claves duplicadas (`series_id`+`period`)

**Severidad:** el guard en sí funciona bien — convierte lo que sería una fusión
silenciosa de observaciones distintas en una falla ruidosa y seguible. Pero la causa
de fondo (los parsers genéricos no siempre capturan toda la dimensión que distingue
una fila/columna de otra) es un defecto real, no un falso positivo del guard.
**Archivos:** el guard vive en `documented_finalize_observations()`
(`scripts/03_curate_documented.R`, chequeo final antes de escribir), pero el origen
está en los parsers que alimentan sus observaciones. Se identificaron **al menos dos
mecanismos distintos**, no uno solo:

### 6a. `documented_parse_credit_sheet()` — no incorpora la columna a la identidad

`scripts/03_curate_documented.R:898` (hoja `"%"` de `credit_survey`). El
`series_path` se arma como `documented_compact_path(c(question, label))` — pregunta +
respuesta —, sin nada que dependa de qué columna produjo el valor. Reproducido en
aislado: las columnas 22, 23, 24 y 25 (mismo trimestre `2018-03-31`) comparten
`series_path` idéntico porque nada en la etiqueta las distingue. 1108 claves
duplicadas en total sobre este archivo real.

**Arreglo propuesto:** incluir en el path lo que de verdad distingue esas columnas
(hay que mirar el encabezado real de la hoja "%" para saber si son sectores,
entidades u otra cosa — el parser hoy ni siquiera lee ese encabezado por columna).

### 6b. `documented_extract_horizontal_year_quarter()` — no tiene subencabezado de columna

`scripts/03_curate_documented.R:555-604`. A diferencia de su función hermana
`documented_extract_horizontal_time()` (que sí arma `column_labels` desde
subencabezados, línea 469), esta función **nunca calcula un label por columna** — el
`series_label` es sólo `row_label`. Reproducido sobre `direct_investment/Cuadro 2`:
dos columnas distintas (9 y 11) para el mismo trimestre `1997-09-30` con valores
distintos (86.981.846 y 96.644.923) colapsan al mismo `series_path` porque ambas
comparten fila. El path resultante además contiene un fragmento numérico crudo
(`"81568553.7817158"`) mezclado con las etiquetas — indicio de que el límite entre
columnas de etiqueta y columnas de dato también se está calculando mal para esta
hoja.

**Arreglo propuesto:** dotar a esta función del mismo mecanismo de `column_labels`
que ya tiene `documented_extract_horizontal_time`.

### 6c. Estructuras con fecha repetida legítima (`vertical_date`, `date_header_blocks`)

`interbank_market` (546 duplicados, hoja "Mdo Secundario"), `lrm_auctions` (21) y
`liquidity_facility` (14) fallan con el mismo guard pero en hojas donde **es normal
que la misma fecha tenga más de una observación** (varias operaciones el mismo día,
varias licitaciones con la misma ventana). El extractor genérico `vertical_date`
asume como mucho un valor por (fecha, columna) y no captura la dimensión que
realmente distingue cada fila (instrumento, tramo, contraparte). En `lrm_auctions`
además se observó el mismo rango de fechas concatenado dos veces dentro de un mismo
`series_path` (`"2013-01-09 — 2013-03-29 — 2013-01-09 — 2013-03-29 — ..."`), indicio
de una construcción de etiqueta duplicada aparte del problema de fondo.

**No alcanza a determinarse en este informe** si estos tres casos comparten una única
causa o son variantes independientes del mismo síntoma general — necesitan mirarse
hoja por hoja contra el archivo real. Lo que sí está confirmado con evidencia directa
es que las seis fuentes fallan por el mismo guard y que, en los dos casos que se
pudieron diagnosticar a fondo (6a y 6b), la causa es la misma familia de problema:
identidad de serie incompleta.

**Nota para el próximo run:** no se pudo determinar si estos seis fallos ya existían
antes de la optimización de performance de esta sesión (`v8`) o si están ahí desde
antes — la corrida previa a la optimización nunca llegó a procesar estas fuentes
porque se cortó antes en `economic_annex` por una causa aparte (ver más abajo). Decirlo
así, sin asumir.

---

## Hallazgo aparte — una fuente corrupta puede tumbar toda la corrida, no sólo la suya

**Severidad:** operativo, pero contradice directamente una garantía central del
proyecto ("Transacción por fuente — una fuente rota no detiene ni corrompe a las
demás", `CLAUDE.md`).
**Archivo:línea:** `scripts/06_pipeline.R:64-66`, dentro de `run_manifest_pipeline()`.

**Qué pasa:** `xlsx_sheet_dimensions(item$path)` y `record_source_metadata(...)` se
llaman **antes** de `DBI::dbBegin(con); tryCatch({...})` — es decir, fuera del bloque
que aísla fallas por fuente. En una corrida real, `utils::unzip()` falló al extraer
uno de los workbooks ("error 1 in extracting from zip file") y el error, al no estar
protegido por el `tryCatch` de la fuente, propagó hasta el tope y abortó **todo el
script**, no sólo esa fuente. No se pudo confirmar con certeza si el zip realmente
estaba dañado o si fue un problema puntual del entorno (el archivo, al re-listarlo,
existe y tiene el tamaño esperado) — pero el hueco en el código es real
independientemente de qué lo disparó esta vez: cualquier archivo que falle en esa
etapa de detección de dimensiones se lleva puesta la corrida completa.

**Arreglo propuesto:** mover la detección de dimensiones y el registro de metadata
adentro del `tryCatch` por fuente, o envolverlos en su propio `tryCatch` que registre
la falla como `quality_flag` y haga `next` en el loop, igual que se hace con los
errores de ingesta/validación más abajo.

---

## Nota de justicia — la optimización de performance está bien hecha

No es un error, pero corresponde decirlo en el mismo lugar: la reescritura vectorizada
de `documented_measure_metadata()` (ahora `documented_measure_metadata_vectorized()`,
`scripts/03_curate_documented.R:187`) y su integración en
`documented_enrich_metadata()` (línea 260) están implementadas con cuidado — calculan
metadata una sola vez por par distinto `(etiqueta, título)` y la vuelven a unir con
`left_join(..., na_matches = "na")`, preservando exactamente la semántica de la
versión escalar anterior (paridad confirmada empíricamente: la corrida completa de 22
fuentes pasó de tardar más de 50 minutos a ~4.5 minutos). El proyecto agregó además
tests de "performance-equivalence" dedicados, que pasan limpio. El problema no es la
optimización — es que los defectos de arriba están todos en código que la
optimización no tocó (o, en el caso del defecto 6, en parsers cuya lógica de
identidad nunca se había ejercido de punta a punta contra estos archivos reales antes
de esta sesión).

---

## Qué falta para cerrar la auditoría completa

Este informe cubre "qué se rompe y por qué" para la corrida real de ingesta. Todavía
falta, según el procedimiento de auditoría de este proyecto:

- Recorrer `AUDITORIA_REGRESIONES.md` completo (R1–R25) con evidencia punto por punto.
- Contrastar la base resultante contra la tabla de verdad conocida de `CLAUDE.md`
  (conteos y rangos de fecha por fuente) — sólo se pudo hacer parcialmente porque
  varias fuentes no llegan a persistirse.
- Pruebas de mutación de guards (romper una copia a propósito y confirmar que el
  guard frena la corrida).
- Actualizar `AUDITORIA_REGRESIONES.md` con los defectos nuevos (candidatos a
  R26–R32 según esta lista) y escribir el informe formal
  `revisiones/REVISION_v8.md` con el formato completo.
