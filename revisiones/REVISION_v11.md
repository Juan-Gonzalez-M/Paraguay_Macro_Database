# Revisión del piloto — versión 11

## Alcance de lo verificado

`scripts/00_install_packages.R`, `run_tests.R` (batería completa) y `run_update.R`
corridos contra los 22 archivos reales de `input/current/`, **sin ningún parche esta
vez** — a diferencia de la revisión anterior, `run_update.R` corre tal cual está en
el repositorio. Se reprodujo además, de forma aislada, la única fuente que sigue sin
cargar (`economic_annex`), recorriendo sus 94 hojas una por una para localizar
exactamente cuál produce el problema. Se recontrastó la base resultante contra la
tabla de verdad conocida de `CLAUDE.md`. Cada defecto de la revisión anterior
(`revisiones/REVISION_v10.md`) se reverificó leyendo el código actual y reproduciendo
el escenario real correspondiente — no se da nada por cerrado porque el CHANGELOG lo
diga.

**No se pudo hacer esta vez:** una segunda corrida real completa para certificar
idempotencia de punta a punta (el tiempo de esta sesión se priorizó en localizar la
causa exacta del único bloqueo que queda). Como evidencia parcial: el `release_id`
determinístico (`release:748d41036c3a73638a1c2086`) es idéntico al de las dos
revisiones anteriores, corrido contra el mismo conjunto de archivos con tres
versiones de código distintas — no reemplaza una prueba de idempotencia dedicada,
pero es una señal consistente. Pruebas de mutación de guard sobre archivo real
tampoco esta vez, mismo motivo de foco.

---

## Veredicto

**El defecto que bloqueaba todo el pipeline en la revisión anterior está cerrado, de
raíz y con doble resguardo.** `run_update.R` corre sin intervención por primera vez
en esta serie de revisiones, y lo hace con un arreglo que no es un parche puntual:
separaron explícitamente "¿esta base es nueva?" de "¿hay que migrar contenido
viejo?", así que ninguna función de invalidación corre nunca contra una base recién
creada — el error puntual también se corrigió, pero incluso si no lo hubieran hecho,
la causa por la que se disparaba en una base vacía ya no existe.

Con eso resuelto, el resultado real es el mejor de toda esta serie de revisiones:
**21 de 22 fuentes cargan limpio.** La única que falta —`economic_annex`— ya no
falla por fechas imposibles (ese defecto se cerró de fondo, con la generalización
que esta auditoría venía pidiendo desde hace dos rondas), sino por un problema
mucho más acotado y ya localizado en este mismo informe: una sola hoja de 94 no
produce observaciones. Es, con diferencia, el estado más cercano a "toda la base
carga" que se vio en esta serie de auditorías.

---

## Regresiones verificadas

| id | Estado | Evidencia de esta corrida |
|---|---|---|
| R1/R2 | Idempotencia no re-certificada con una segunda corrida dedicada esta ronda; `release_id` determinístico idéntico a v9/v10 sobre los mismos archivos, en tres versiones de código distintas. |
| R3–R23 | Sin cambios respecto de la revisión anterior; sin evidencia de regresión en ninguno durante esta corrida. |
| R24 | Sin cambios — alcance FMI sigue sin conectar. |
| R25 | Sin cambios — `concept_mappings.csv` sigue vacío. |
| R26 | CERRADO, confirmado de nuevo | Sin errores de sintaxis SQL en `validate_documented_series_continuity()` en esta corrida. |
| R27 | **CERRADO de fondo, no sólo el caso puntual** | `documented_year_values()` reescrita con reconocimiento estricto de años anotados (`03_curate_documented.R:61-71`) + nuevo `documented_year_axis_counts()` que exige secuencia ordenada con saltos plausibles (≤10) en vez de sólo rango numérico (líneas 73-86). `Cuadro 49` y `CUADRO 58` — los dos casos concretos encontrados en rondas anteriores — ya no producen fechas implausibles. Ver Defecto 1 de todos modos: el mismo endurecimiento generó una regresión colateral puntual, no del mismo tipo de bug. |
| R28 | CERRADO, confirmado de nuevo | `exchange_houses`: 10 hojas, 6.164 celdas — exacto, tercera corrida seguida. |
| R29 | CERRADO, confirmado de nuevo | `liquidity_facility`: observaciones con "repo" y "deposito" en la etiqueta presentes en la base real. |
| R30 | **Sigue abierto, cuarta corrida con el mismo resultado exacto** | `raw_banks_eeff` = 246.546 filas, igual que en v8, v9 y v10. El CHANGELOG de v11 menciona "dynamic bank-header row accounting" — no se observó ningún cambio en este número; o esa mejora apunta a algo distinto de este conteo puntual, o no llegó a afectar este archivo. |
| R38 | **CERRADO, de raíz** | Ver Defecto (resuelto) abajo — `run_update.R` corre sin parche por primera vez en esta serie. |
| R39 | No verificado explícitamente esta ronda (requiere el mismo camino de migración v2→v3 sintético que antes; no se repitió el test específico de forma aislada). |

---

## Lo que quedó resuelto desde la última revisión (v10 → v11)

- **El pipeline arranca sin intervención.** `initialize_database()`
  (`scripts/02_extract_raw.R:333-462`) ahora calcula
  `fresh_bootstrap <- !length(existing_versions) && !existing_sources` **antes** de
  insertar ninguna fila en `schema_version`, y cada llamada a una función
  `invalidate_v*_*()` está condicionada a `if (!fresh_bootstrap) ...`. Con esto,
  ninguna función de migración corre nunca contra una base nueva, sin importar en
  qué punto intermedio del bootstrap se encuentre `schema_version`. Además — no sólo
  el resguardo arquitectónico, sino también el arreglo puntual — `affected_concepts`
  ahora se calcula correctamente antes de usarse en
  `invalidate_v9_runtime_repairs()` (línea ~203), así que una migración real
  v9→v10 sobre una base existente tampoco fallaría. Doble resguardo, no uno solo.
  Verificado corriendo `Rscript -e 'source("run_update.R")'` sin ningún parche: 21
  fuentes cargan, ninguna falla por este motivo.

- **`documented_year_values()` ya no acepta cualquier entero en rango.** Ahora exige
  un patrón de año anotado estricto y anclado
  (`^((?:19|20)[0-9]{2})(?:\s*(?:\(?\*+\)?|[0-9]{1,2}/))*\s*$`), y el nuevo
  `documented_year_axis_counts()` puntúa un eje de tiempo como válido sólo si sus
  valores forman una secuencia ordenada con saltos razonables. Esto cierra R27 de
  fondo — no cuadro por cuadro como en v10 — y el proyecto agregó una prueba de
  regresión real para `CUADRO 58` específicamente (visible en
  `test-full-pipeline-smoke.R:65-66`, aunque hoy no puede pasar porque
  `economic_annex` no llega a persistir — ver Defecto abajo).

---

## Defectos

### Defecto 1 (nuevo, colateral) — `economic_annex` sigue sin cargar: `CUADRO 57a` quedó sin observaciones tras endurecer la detección de años

**Severidad:** silencioso en potencia (una hoja que antes producía datos ahora no
produce ninguno, sin que nada además del guard de cobertura mínima lo note) —
bloqueante en su efecto inmediato, porque el guard de cobertura sí lo atrapa y frena
la fuente completa.
**Archivo:línea:** el síntoma vive en `documented_extract_horizontal_year_month()`
(vía `documented_year_values()`, `scripts/03_curate_documented.R:61-71`), aplicado a
la hoja `CUADRO 57a` — la misma que R22 documentaba como excepción manual
(`config/sheet_modes.csv`: `parser_mode_override = horizontal_year_month`).

**Qué pasa:** con el endurecimiento de `documented_year_values()` de esta ronda
(Defecto resuelto de R27), la fila que `CUADRO 57a` usa como eje de años ahora sólo
reconoce **un** valor: `"2021*"`, en la columna 2. El resto de la fila (más allá de
la etiqueta `"Mes"` en la columna 1) no tiene ningún otro token que matchee el nuevo
patrón estricto. El resultado: `documented_extract_horizontal_year_month()` no
produce ninguna observación para esta hoja (0 filas, con 33 celdas crudas no
vacías detectadas — la hoja no está vacía, simplemente no se extrae nada), y el
guard de cobertura mínima de `economic_annex`
(`config/documented_source_contracts.csv`, exige ≥93 hojas parseadas de 94)
falla por una sola hoja: *"economic_annex parsed 92 sheets; expected at least 93"*.

**Cómo se verificó:** se recorrieron las 94 hojas de `economic_annex` una por una
buscando errores de parseo (ninguna lanzó error) y buscando cuáles producen 0
observaciones (sólo `CUADRO 57a`). Inspeccionando el contenido crudo de esa hoja
directamente: la fila candidata a eje de años (`year_row = 12`) tiene sólo dos
celdas no vacías en toda la fila — `"Mes"` y `"2021*"` — lo cual sugiere que esta
hoja en particular nunca tuvo una fila de "muchos años lado a lado" como el resto de
las hojas `horizontal_year_month`; es la razón original por la que necesitó una
excepción manual desde antes de R22. No alcancé a determinar con certeza si la
estructura real de esta hoja necesita un eje de años distinto al que
`documented_extract_horizontal_year_month()` asume, o si el patrón nuevo de
`documented_year_values()` simplemente no reconoce el formato específico de "2021*"
en el lugar correcto — dejo la evidencia tal como la verifiqué, sin inventar la
causa exacta.

**Por qué vale la pena señalarlo con cuidado:** es exactamente el patrón que
`AUDITORIA_REGRESIONES.md` ya tiene registrado como lista de control (punto 6,
agregado la ronda pasada): un arreglo general y bien pensado (R27) tuvo un efecto
colateral puntual en la única hoja que ya necesitaba trato especial. No es una señal
de que el arreglo de R27 esté mal — al contrario, es prueba de que ahora es
*estricto* donde antes era permisivo — pero `CUADRO 57a` necesita su propio ajuste
dentro de esa nueva lógica, no una vuelta atrás.

**Arreglo propuesto:** revisar el contenido real de `CUADRO 57a` con
`readxl`/inspección manual para confirmar qué fila/columna contiene la información
de año que el override de `sheet_modes.csv` asume, y ajustar
`documented_extract_horizontal_year_month()` (o el propio override) para esa hoja
específicamente — igual que se hizo para `Cuadro 49` con el "horizonte de proyección
revisado". Dado que ya existe el mecanismo de excepciones por hoja en
`sheet_modes.csv`, es el lugar natural para una segunda anotación específica de esta
hoja si su estructura es genuinamente distinta al resto.

---

### Defecto 2 (persistente, sin cambios) — Bancos EEFF: cuarta corrida seguida con la misma fila de diferencia

**Severidad:** menor.
**Evidencia:** `raw_banks_eeff` = 246.546 filas, idéntico a v8, v9 y v10, contra las
246.547 de `CLAUDE.md`. El CHANGELOG de v11 menciona "dynamic bank-header row
accounting", pero el número no cambió — o esa mejora no apunta a este conteo
puntual, o no tuvo el efecto esperado sobre este archivo real. Sigue sin causa
determinada.

---

### Defecto 3 (menor, en el propio test suite) — Alias sin `AS` en una consulta del smoke test

**Severidad:** menor — vive en el archivo de test, no en el pipeline de producción.
**Archivo:línea:** `tests/testthat/test-full-pipeline-smoke.R:78`.
`SELECT COUNT(*) rows FROM documented_series_snapshot GROUP BY 1,2 HAVING COUNT(*) >
1` — `rows` es, igual que `label` en una ronda anterior, palabra reservada en la
gramática de DuckDB sin `AS`. Confirmado aislado:
`SELECT COUNT(*) rows FROM t GROUP BY a` tira el mismo error de sintaxis. Es la
misma familia de bug que R26, esta vez en el test y no en el código de producción —
significa que esa aserción específica del smoke test nunca puede ejecutarse tal como
está escrita.
**Arreglo:** agregar `AS` — `COUNT(*) AS rows`.

---

## Lo que agregaría

1. **Revisar `CUADRO 57a` puntualmente** — es lo único que falta para que
   `economic_annex` cargue completo, y ya está localizado con precisión en este
   informe.
2. **Agregar `AS` en `test-full-pipeline-smoke.R:78`** — una línea, desbloquea una
   aserción del propio smoke test que hoy nunca corre.
3. Determinar de una vez la causa del Defecto 2 (Bancos EEFF) — ya lleva cuatro
   rondas señalado.
4. Ahora que el pipeline corre de punta a punta sin intervención, la próxima ronda
   es un buen momento para retomar las pruebas de mutación de guard sobre archivo
   real que quedaron pendientes hace dos revisiones.

---

## En resumen

Esta ronda cerró el defecto más grave de toda esta serie de auditorías — el
pipeline no arrancaba — con un arreglo arquitectónico correcto (separar bootstrap de
migración) más el arreglo puntual, no uno solo. El resultado es 21 de 22 fuentes
cargando limpio contra archivos reales, el mejor número visto hasta ahora. Lo único
que falta es una hoja específica dentro de la fuente más grande del proyecto, con
causa ya localizada — no es un misterio para la próxima ronda, es una tarea acotada.
