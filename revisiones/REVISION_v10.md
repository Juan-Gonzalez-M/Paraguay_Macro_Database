# Revisión del piloto — versión 10

## Alcance de lo verificado

`scripts/00_install_packages.R`, `run_tests.R` (batería completa) y `run_update.R`
corridos contra los 22 archivos reales de `input/current/` en este entorno.
`run_update.R`, tal como está en el repositorio, **no llega a procesar ni una sola
fuente** — falla en la inicialización de la base (ver Defecto 1). Para poder seguir
auditando el resto del pipeline con evidencia real y no especulación, apliqué un
parche de una función **sólo en la sesión de R de diagnóstico, nunca en los archivos
del repositorio** (queda documentado textualmente en el Defecto 1) y con eso corrí el
pipeline completo contra los 22 archivos reales, más un barrido de las 94 hojas de
`economic_annex` en busca de fechas implausibles, más una recontrastación completa
contra la tabla de verdad conocida de `CLAUDE.md`. Cada defecto de la revisión
anterior (`revisiones/REVISION_v9.md`) se reverificó leyendo el código actual y
reproduciendo el escenario real correspondiente.

**No se pudo hacer esta vez:** una segunda corrida real de idempotencia (R1/R2) —
tendría que repetirse con el mismo parche cada vez, y dado que el Defecto 1 bloquea
`run_update.R` tal cual está, no tiene sentido certificar idempotencia de un comando
que no corre. Pruebas de mutación de guard sobre archivo real tampoco esta vez, por
la misma razón de foco: el hallazgo que más importa reportar hoy es que nada corre
sin intervención manual.

---

## Veredicto

**Hoy, `source("run_update.R")` no produce una base de datos: se cae en el primer
segundo, antes de tocar una sola fuente.** Es un error de una línea (una variable sin
definir) en una función de invalidación de esquema que se ejecuta siempre, incluso
contra una base nueva y vacía — así que no hay forma de esquivarlo sin editar el
código. Esto tiene que arreglarse antes de cualquier otra cosa.

Dicho eso — y es un dicho importante, no un atenuante cosmético — **una vez que se
puentea ese error de una línea, el resto del trabajo de esta ronda es notablemente
sólido**: 21 de 22 fuentes cargan limpio contra los archivos reales (subió de 19 en
la revisión anterior), incluidas dos fuentes centrales que llevaban varias rondas
rotas (`exchange_houses`, `exchange_rates`), y los cinco defectos de la revisión
anterior se cerraron con arreglos que corrigen la causa, no el síntoma. El propio
test suite del proyecto atrapó el error de la variable sin definir de inmediato y sin
ambigüedad — lo cual dice que el problema no es falta de cobertura, es no haber
corrido `run_tests.R` una vez antes de subir esta versión.

---

## Regresiones verificadas

Tabla completa contra el estado conocido en `AUDITORIA_REGRESIONES.md`. Se marca
"no verificable" donde el Defecto 1 impide ejercer el chequeo tal como está descrito
(se verificó igual vía la corrida parcheada donde fue posible).

| id | Estado | Evidencia de esta corrida |
|---|---|---|
| R1 | No verificable con `run_update.R` tal cual (falla antes de archivar nada). Con el parche de diagnóstico: `input_archive/` no creció respecto de la corrida anterior. |
| R2 | Igual que R1 — no verificable sin el parche; con el parche, mismo comportamiento determinístico que en v9. |
| R3 | CERRADO | `fx_operations_snapshot` carga en la corrida parcheada: 5.480 filas esperadas (no re-contado explícito esta vez, sin cambios en el parser). |
| R4 | CERRADO | `assert_direct_structure()` sigue en uso para `banks`/`financial`; ambas cargan. |
| R5 | CERRADO | Sin filas `inventory_only` en `semantic_coverage` de las fuentes cargadas. |
| R6 | CERRADO (verificado en código esta vez) | `resolve_source_files()` (`scripts/01_utils.R:92-104`): con `allow_multiple=FALSE` y 2+ archivos, exige `selection_rule="newest_mtime"`, elige el más nuevo por `mtime` y **registra un warning**, no aborta. |
| R7 | CERRADO para las tres fuentes de entidad | `bank_reference` carga (15 tablas); `exchange_houses` carga (5.048 obs. mapeadas con `entity_id`/`exchange_item_id`). |
| R8 | CERRADO | 22 fuentes resuelven dimensiones sin error de relación XML. |
| R9 | CERRADO | `banks`/`financial` cargan; guard pasa. |
| R10 | CERRADO | EVE carga (no re-contado explícito esta vuelta). |
| R11 | CERRADO | ICC: 1.236 obs., 2018-01-31→2026-07-31 — exacto, igual que las dos rondas anteriores. |
| R12 | **CERRADO, verificado explícitamente esta vez** | `LC_ALL=C Rscript -e 'read_parser_spec(".", "eve")'` no falla. |
| R13 | CERRADO | `dim_currency`: 6900→PYG/PYG, 6200→FX/PYG — exacto, tercera corrida seguida sin cambios. |
| R14 | CERRADO | Smoke test sigue usando `expect_gte`/`expect_gt`. |
| R15 | CERRADO | `bank_reference` presente y carga. |
| R16 | CERRADO | `resolve_reference_table()` sin cambios, sigue por hoja+firma de columnas. |
| R17 | CERRADO | Guards de notación científica presentes. |
| R18 | No verificado explícitamente esta ronda (requiere comparar corridas con contenido distinto en el mismo vintage). |
| R19 | CERRADO, y ahora con el guard de continuidad realmente operativo | Ver R26 abajo — el bug de SQL que lo rompía está arreglado, con un test de regresión de dos vintages reales agregado por el propio proyecto. |
| R20 (parcial) | Sin cambios — sigue igual que en v7/v9: mínimo viable (`hierarchy_status`) cerrado, jerarquía real (`parent_series_id`) sigue sin modelarse en el parser genérico. |
| R21 | CERRADO | Guard duro de unidad/escala sigue presente, sin regresiones observadas. |
| R22 | CERRADO | Sin cambios. |
| R23 | CERRADO | Sin cambios. |
| R24 | ABIERTO, mismo alcance reducido que la ronda anterior — mecanismo `long_csv` funciona, FMI (WEO/IFS/BOP) sigue sin conectar. |
| R25 | ABIERTO, sin cambios | `config/concept_mappings.csv` sigue con sólo encabezado. |
| R26 | **CERRADO** | `AS source_sheet`, `AS label` agregados en `scripts/04_validate.R:287-288`. El proyecto agregó además un test de regresión ejecutable con **dos vintages reales** (mencionado en el CHANGELOG como "an executable two-vintage regression") — es exactamente la prueba que esta auditoría no podía hacer por sí sola sin dos publicaciones reales del BCP. |
| R27 | **PARCIALMENTE CERRADO** | El caso que motivó el hallazgo (`Cuadro 49`, filas de resumen con fecha hasta 2099) está resuelto: 0 filas implausibles en esa hoja ahora. Pero el mismo síntoma general reaparece en **`CUADRO 58`**, con una firma distinta (ver Defecto 2 abajo) — la causa raíz (`documented_year_values()` sin contexto posicional) sigue sin una solución general; lo que se arregló fue el caso puntual de Cuadro 49. |
| R28 | **CERRADO** | `content_bounds` por defecto ahora es `last_row=0L, last_col=0L` (antes `1L,1L`) cuando no hay celdas activas (`scripts/01_utils.R:300`). `exchange_houses` carga completo, las 10 hojas, incluidas las 4 "vacías por fórmulas". |
| R29 | **CERRADO** | Nuevo parámetro `block_patterns` en `documented_parse_row_events()` (`scripts/03_curate_expanded.R:67-98`) con validación dura (exige exactamente un match de bloque semántico). Confirmado en la base real: 3.650 observaciones con "deposito" en la etiqueta, 2 con "repo" — ambas presentes y distinguidas por `operation_type:`. |
| R30 | Sin cambios, sigue abierto | `raw_banks_eeff` da 246.546 filas contra las 246.547 de `CLAUDE.md`, **tercera corrida seguida con el mismo resultado exacto** — ya no parece ruido, es reproducible. Sigue sin causa determinada. |

---

## Lo que quedó resuelto desde la última revisión (v9 → v10)

Cada uno verificado leyendo el código y reproduciendo el escenario real:

- **`exchange_houses` carga completo por primera vez en esta serie de revisiones.**
  Tres rondas, tres bugs distintos originados en la misma trampa ("hojas vacías por
  fórmulas" que `CLAUDE.md` ya documentaba) — esta vez el arreglo fue de raíz:
  `xlsx_sheet_dimensions()` ahora reporta 0 columnas de contenido cuando no hay
  ninguna celda activa (antes reportaba 1 por defecto, lo cual generaba un desacople
  con lo que `readxl` realmente devolvía). Verificado: 10 hojas, 6.164 celdas — exacto
  contra `CLAUDE.md`; 5.048 observaciones mapeadas con entidad e ítem verificados.

- **`exchange_rates` carga completo.** Nuevo helper
  `documented_consecutive_year_rows()` (`scripts/03_curate_documented.R:70-78`) exige
  que los años candidatos de una fila formen una secuencia consecutiva sin
  duplicados antes de aceptarlos como encabezado de bloque — exactamente el
  principio que esta auditoría había sugerido para evitar que un valor de cotización
  suelto se confunda con un año. Verificado: 14 monedas distintas en "Cotizaciones
  Diarias", igual al mínimo del contrato.

- **`liquidity_facility` distingue depósito de repo.** Nuevo parámetro
  `block_patterns` en `documented_parse_row_events()`, con guard duro (exige
  exactamente un tipo de bloque semántico detectado, no cero ni más de uno).
  Verificado contra la base real cargada.

- **El guard de continuidad de identidad (R19/R26) ya no crashea.** `AS` agregado a
  los alias de columna. El propio proyecto agregó un test de regresión de dos
  vintages reales — coincide exactamente con lo que esta auditoría había señalado
  como la prueba que faltaba.

---

## Defectos

### Defecto 1 — El pipeline no arranca: variable sin definir en la inicialización de la base

**Severidad:** bloqueante — el más urgente de este informe, aunque por la propia
filosofía de severidad de este proyecto (un defecto silencioso es más grave que uno
que frena la corrida) técnicamente no es "el peor tipo" de error; lo pongo primero
porque su alcance es total: bloquea el 100% de las fuentes, no una.
**Archivo:línea:** `scripts/02_extract_raw.R:209-210`, dentro de
`invalidate_v9_runtime_repairs()` (definida en la línea 183).

**Qué pasa:**

```r
invalidate_v9_runtime_repairs <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!9L %in% versions || 10L %in% versions) return(invisible(FALSE))
  affected_sources <- c(...)
  ...
  DBI::dbWithTransaction(con, {
    ...
    if (DBI::dbExistsTable(con, "dim_concept") && length(affected_concepts)) {   # <- línea 209
      concept_sql <- paste(vapply(affected_concepts, sql_string, character(1)), collapse = ", ")  # <- línea 210
      ...
```

`affected_concepts` nunca se calcula dentro de esta función — se referencia
directamente. La función hermana de la línea de arriba,
`invalidate_v8_ingestion_repairs()` (línea 134), sí calcula `affected_concepts` antes
de su bloque de transacción (línea 152); todo indica que el bloque de código de esa
función se copió para armar la nueva de v9→v10, pero la línea que calcula
`affected_concepts` no se copió con él.

**Por qué se dispara incluso en una base nueva y vacía:** el guard de la línea
184-188 sólo debería dejar pasar una base que "estuvo en v9 pero no en v10" — la
migración de una base real preexistente. Pero `initialize_database()` bootstrapea
una base nueva insertando las versiones de esquema **en secuencia** (1, 2, 3, ...,
9, 10), así que en algún punto intermedio del bootstrap, `schema_version` contiene
9 pero todavía no 10 — el guard se satisface igual, y la función truena, incluso en
un `:memory:` recién creado. Confirmado así:

```r
Rscript -e 'source("run_update.R")'
# Error in invalidate_v9_runtime_repairs(con) :
#   object 'affected_concepts' not found
```

Y confirmado además por el propio test suite del proyecto: **13 de las fallas de
`run_tests.R`** (documented-source-helpers, full-pipeline-smoke,
identity-and-archive, performance-equivalence, y más) fallan con este mismo mensaje
exacto — el proyecto no llegó a correr su propia batería de tests antes de subir
esta versión, porque de haberlo hecho, esto se ve inmediato.

**Cómo se verificó sin tocar el repositorio:** se sourcearon los scripts del
proyecto en una sesión de R de diagnóstico y se redefinió
`invalidate_v9_runtime_repairs()` **sólo en esa sesión**, agregando la línea que
falta (calcada de `invalidate_v8_ingestion_repairs()`, adaptada a la lista de
fuentes de v9→v10). Con eso se corrió `run_manifest_pipeline()` contra los 22
archivos reales para poder seguir auditando el resto — el resultado de esa corrida
es la base de todo lo demás que sigue en este informe. El archivo del repositorio
**no fue modificado** en ningún momento.

**Arreglo propuesto:** agregar la línea que falta, replicando el patrón de la
función hermana:

```r
affected_concepts <- if (DBI::dbExistsTable(con, "map_series_concept")) {
  DBI::dbGetQuery(con, paste0(
    "SELECT DISTINCT concept_id FROM map_series_concept WHERE series_id IN (",
    series_query, ") AND mapping_status = 'source_specific_unreviewed'"
  ))$concept_id
} else character()
```
antes del `DBI::dbWithTransaction(con, { ... })`. Además de arreglar esta línea,
vale la pena revisar si el guard de versión (línea 184-188) debería distinguir una
migración real de un bootstrap desde cero — hoy ambos casos entran por la misma
puerta, lo cual es justamente lo que hizo que este bug pasara desapercibido incluso
en el escenario más simple posible (base nueva y vacía).

---

### Defecto 2 — `economic_annex` sigue sin cargar: la misma familia de bug, ahora en `CUADRO 58`

**Severidad:** silencioso en su origen — de hecho el más importante en términos de
la filosofía de este proyecto, porque el guard que lo atrapa hoy podría no atraparlo
mañana si el rango de fechas involucradas cambia ligeramente.
**Archivo:línea:** mismo origen que R27 — `documented_year_values()`
(`scripts/03_curate_documented.R:58-65`), ahora manifestándose en una hoja distinta
de la que motivó el arreglo anterior.

**Qué pasa:** el arreglo de esta ronda (helper `documented_date_axis_token()` +
ajustes en `documented_extract_vertical_date()`) resolvió el caso concreto que se
había reportado (`Cuadro 49`) — confirmado: esa hoja da 0 filas con fecha
implausible ahora. Pero recorriendo programáticamente **las 94 hojas** de
`economic_annex` en busca de períodos fuera de rango, aparece una hoja distinta:
**`CUADRO 58`**. La firma del problema ahí es más severa que en el caso anterior —
no es sólo una fecha mal asignada a una fila de anotación, es la tabla entera mal
interpretada: las etiquetas de serie contienen números crudos concatenados en vez de
texto (`"3716.77357160609 — 8026.94992618446 — 5658.3411598545 — ..."`) y los
períodos resultantes están dispersos sin ningún patrón entre 2033 y 2098 — indicio
de que la columna elegida como eje de años para esta hoja específica no es la
columna de años real, sino alguna otra columna numérica que por casualidad tiene
suficientes valores dentro del rango 1900-2100 como para ganarle a la columna
correcta en `which.max(colSums(!is.na(years)))`.

**Por qué importa que sea la misma familia y no un caso aislado:** confirma que el
arreglo de esta ronda fue puntual para `Cuadro 49` (el CHANGELOG lo dice con esas
palabras: *"allowing the reviewed official projection horizon"* — sugiere una
revisión manual de ESE cuadro específico) y no una solución general al problema de
fondo que ya se había señalado la ronda pasada (R27): `documented_year_values()`
sigue aceptando cualquier entero 1900-2100 sin ningún chequeo de contexto o
posición. Mientras esa función no cambie, es cuestión de tiempo hasta que aparezca
en una hoja más.

**Cómo se verificó:** se recorrieron programáticamente las 94 hojas de
`economic_annex` con `documented_extract_generic_sheet()`, filtrando observaciones
con período fuera de rango plausible — sólo `CUADRO 58` produjo resultados. Esto es
lo único que impide que `economic_annex` cargue hoy (con el resto del pipeline
parcheado según el Defecto 1, las otras 92 hojas procesables cargan sin problema).

**Arreglo propuesto:** el de fondo, no el puntual — `documented_year_values()`
necesita exigir contexto: que los candidatos de una fila/columna formen una
secuencia razonable con sus vecinos (el mismo principio que ya se aplicó con éxito
en `documented_consecutive_year_rows()` para el caso de `exchange_rates` esta misma
ronda), en vez de aceptar cualquier entero suelto en rango. Aplicar ese mismo
principio acá cerraría de una vez R27 en su forma general, no cuadro por cuadro.

---

### Defecto 3 (nuevo, en la batería de tests) — Regresión en la migración de esquema v2→v3: columna inexistente

**Severidad:** menor en impacto real (sólo afecta la ruta hipotética de migrar una
base que todavía esté en schema v2, algo improbable en este momento del proyecto),
pero es una regresión real y nueva: este test pasaba en la revisión anterior (v9) y
ahora falla.
**Archivo:línea:** `scripts/02_extract_raw.R:97`, dentro de
`invalidate_v6_documented_identity()`.

**Qué pasa:** la consulta de esa función selecciona
`series_id FROM dim_series WHERE ... AND semantic_status = 'documented_series'`.
DuckDB devuelve: *"Referenced column 'semantic_status' not found in FROM clause!
Candidate bindings: mapping_status, hierarchy_status, identity_stability, scale,
identity_basis"* — el test que lo dispara
(`test-identity-and-archive.R:62`, "schema-v2 curated outputs are invalidated
before v3 reingestion") arma una tabla `dim_series` sintética mínima, y en el
camino de migraciones encadenadas que corre `initialize_database()` sobre esa base
sintética, esta consulta ya no encuentra la columna que espera.

**Cómo se verificó:** falla reproducible corriendo `run_tests.R` completo; no
alcancé a determinar con certeza si el cambio de fondo fue en el orden de las
migraciones encadenadas o en el esquema sintético del test — lo señalo con la
evidencia que tengo, no con una causa que no pude confirmar.

**Arreglo propuesto:** revisar si `invalidate_v6_documented_identity()` debería
usar una columna distinta (quizás ya no existe `semantic_status` en `dim_series`
para bases que llegan hasta acá, y correspondería otra condición), o si el problema
está en el fixture del test. De cualquier forma, es una regresión real que
`run_tests.R` ya está señalando con claridad.

---

### Defecto 4 (menor, persistente) — Bancos EEFF: la misma fila de diferencia, tercera corrida seguida

**Severidad:** menor.
**Evidencia:** `raw_banks_eeff` = 246.546 filas contra las 246.547 de `CLAUDE.md`,
igual que en la revisión anterior y la anterior a esa — mismo archivo, mismo
resultado exacto tres veces. Ya no es plausible que sea ruido de medición; hay algo
puntual (una fila de encabezado, un total, una fila en blanco al final del rango)
que se cuenta distinto entre lo que dice `CLAUDE.md` y lo que produce el pipeline.
No se investigó la causa exacta esta ronda tampoco — señalado otra vez para que no
se pierda.

---

## Sobre las pruebas de mutación de guard

No se repitieron esta ronda por foco: el hallazgo que más vale la pena comunicar
hoy es que el pipeline no corre sin intervención manual, y confirmar eso — más
diagnosticar qué pasa una vez que se puentea — consumió el tiempo de esta sesión.
Como evidencia indirecta de que los guards siguen funcionando: **el propio test
suite actuó como guard de mutación involuntario** sobre el Defecto 1 — 13 tests
distintos, tocando rutas de código muy distintas entre sí, fallaron todos con el
mismo mensaje exacto en cuanto se intentó inicializar una base. Eso es exactamente
el comportamiento que se espera de una batería de regresión sana: detectar un
cambio que rompe todo, de forma inequívoca, en el primer intento de correrla.

---

## Lo que agregaría

Por orden de valor:

1. **Correr `run_tests.R` antes de subir una versión.** No es una sugerencia de
   proceso genérica — literalmente hubiera evitado el Defecto 1 en su totalidad.
2. **Generalizar `documented_year_values()`** con el mismo principio de secuencia
   consecutiva que ya se aplicó en `documented_consecutive_year_rows()` — cerraría
   R27 de fondo en vez de cuadro por cuadro.
3. **Revisar si el guard de versión de las funciones `invalidate_v*_*()` debería
   distinguir bootstrap-desde-cero de migración-real** — el patrón que causó el
   Defecto 1 (correr sobre una base nueva porque el guard no distingue los dos
   casos) podría repetirse en la próxima función de invalidación que se agregue.
4. Determinar la causa de la fila de diferencia en Bancos EEFF (Defecto 4) — bajo
   impacto pero ya lleva tres rondas señalado sin resolver.

---

## En resumen

La sustancia de esta ronda es buena — de hecho la mejor hasta ahora en términos de
calidad de los arreglos: `exchange_houses`, `exchange_rates` y la identidad
depósito/repo de `liquidity_facility` quedaron resueltos con causa raíz corregida,
no parcheados. Pero nada de eso importa hoy porque **el pipeline no arranca**: un
error de una variable sin definir, en una función que corre siempre, tumba
`run_update.R` antes de procesar la primera fuente. Es un arreglo de una línea, y el
propio test suite del proyecto ya lo señala sin ambigüedad — el paso que falta no es
diagnóstico, es simplemente correr `run_tests.R` una vez antes de la próxima subida.
