# Revisión de la quinta auditoría técnica (2026-08-30) — P0, P1, P2

Registro de lo que se implementó del informe `TECHNICAL_AUDIT_REPORT_2026-08-30.md` en su quinta
redacción, lo que se descartó y por qué. Esta auditoría se ejecutó **contra el estado que dejó la
ronda anterior** (rama `audit4-p0-p1-p2`, commit `cdd056c`, esquema 26): confirma que aquellas
reparaciones aterrizaron y encuentra dieciocho hallazgos nuevos, cuatro de los cuales son defectos
del código escrito en esa misma ronda.

Cada afirmación cuantitativa del informe se volvió a medir contra la base de datos viva antes de
tocar código. **Todas se reprodujeron.** Resultado: esquemas 27 (P0), 28 (P1) y 29 (P2).

## Verificación previa del diagnóstico

| Afirmación de la auditoría | Resultado de la comprobación |
|---|---|
| 34 vistas publicadas sin filtro de release: los 17 paneles `v_latest_raw_*`, la familia documentada y las dos vistas de mercado | Confirmada. Las de mercado probaban `ingestion_status = 'completed'`, que es un hecho sobre si el archivo cargó, no sobre si puede publicarse |
| `CUADRO 20` titulado *"En millones de dólares"* con 12 de 30 series en `unit_code = COUNT`, `scale_multiplier = 1` | Confirmada. Son exactamente aquellas cuya etiqueta de fila contiene *operaciones* |
| 18.416 de las 20.156 filas `blank_in_source` son celdas con el texto `s/m` | Confirmada. 65 contienen `"0"` y varias, un número guardado como texto |
| 343 filas de `v_series_latest` con fecha posterior a su fecha de publicación | Confirmada: 313 de `economic_annex`, 30 de `fx_operations` |
| 12.371 celdas `data_not_ingested` en `Cuadro 5`, `Cuadro 7` y el anexo `Cuadro 52a/52b` | Confirmada |
| 399 claves duplicadas en `raw_banks_canales_person`; `codigo_entidad` y `codigo_moneda` como `DOUBLE` | Confirmada, y sin `source_row` en ningún panel |
| `stage_release()` devuelve a `staged` una release ya aceptada al re-ejecutar el bundle | Confirmada. **Defecto propio**, esquema 24/26 |
| `coalesce(component, 0)` en `validate_published_identities()` | Confirmada. **Defecto propio**, esquema 25 |
| Ambas filas de `audit.build_identity` con `git_dirty = TRUE` | Confirmada. **Defecto propio**, esquema 26 |
| El README sigue titulado "governed pilot v11" con el esquema en 26 | Confirmada |
| `database/backups` en 7,7 GiB contra una base de 369 MiB | Confirmada |

## Decisiones del usuario tomadas antes de implementar

1. **Alcance: P0 + P1 + P2.** P3 queda fuera.
2. **`s/m` significa "sin movimiento"** — no hubo transacciones en el período de esa celda. En una
   tabla de tasas de interés eso quiere decir que no hay tasa que informar: no es un cero, y tampoco
   es un vacío ordinario.
3. **F-05 se implementa en versión estrecha, por instrucción del usuario.** `v_series_latest` y
   `series_as_of_date()` *exponen* `observation_status` y conservan las 343 filas, en lugar de
   devolver por defecto sólo lo realizado. La auditoría recomienda lo estricto; esa recomendación
   **no se toma**, conscientemente, y el riesgo residual de *look-ahead* se registra aquí, en el
   README y en `docs/DATA_MODEL.md` en vez de quedar implícito.
4. **El parser de doble encabezado de `Cuadro 5`/`Cuadro 7` sí se implementa** en esta ronda.

## Esquema 27 — P0

### F-01 — Un solo límite de release, en toda interfaz publicada

`accepted_release_vintages_sql()` ya existía desde el esquema 24 y es la definición única. El filtro
se aplicó **dentro** de cada subconsulta de ranking, no encima de ella: así una vista devuelve el
vintage más nuevo que el investigador puede ver, en lugar de no devolver nada mientras hay uno más
nuevo en `staged`. Toda vista filtrada tiene su gemela `_all` sin filtrar, para diagnóstico y para la
ruta de ingesta, que debe ver una release aún no aceptada.

El *lint* que exige el join también se reparó, y de la peor manera posible: exigía una lista de
prefijos escrita a mano, y **la lista ya estaba equivocada**. Las cinco vistas de catálogo por grano,
`v_series_projections` y `v_series_missingness` viven en `marts` y no coincidían con `v_mart_` ni con
`v_research_series`, de modo que el propio esquema 29 introdujo seis interfaces publicadas sin filtro
y el lint las dejó pasar. Ahora la regla es estructural — `v_latest_*`, `v_*_latest*`, y **todo lo
que viva en `marts`** — y sigue las dependencias entre vistas de forma transitiva. Al ampliarla
detectó las seis fugas de inmediato; están reparadas.

**Resultado: 43 interfaces publicadas, 0 sin filtro.**

### F-02 — Una unidad declarada en el título manda sobre una palabra en la etiqueta de fila

`CUADRO 20` está titulado *"En millones de dólares"* y doce de sus treinta series llevaban
`unit_code = COUNT`, `scale_multiplier = 1` porque su etiqueta de fila contiene *operaciones*, que el
parser leía como palabra clave de conteo. `value_in_base_units` estaba equivocado en un factor de
10⁶ sobre doce series cambiarias.

La guarda que ya existía para *saldos* codificaba el principio correcto; se extendió a todo título
que declare una magnitud monetaria (`millones de dólares`, `miles de guaraníes`, …) y se aplicó por
igual a la rama `count` y a la rama `days`. Radio de impacto medido antes de migrar: **16 series y
5.942 observaciones** en `CUADRO 19`, `20`, `36`, `37` y `38`. Ninguna cifra cambia; cambia la unidad
con la que se interpreta.

Comprobación posterior, período a período, contra la fuente dedicada `fx_operations`:

| Frecuencia | Comparadas | Coincidentes a precisión de punto flotante |
|---|---|---|
| Mensual | 3.790 | 3.790 |
| Trimestral | 1.320 | 1.320 |
| Anual | 370 | 370 |

**5.480 de 5.480.** Antes de la reparación, las doce series afectadas habrían diferido por 10⁶.

### F-03 — Lo que el editor escribe en vez de un número se lee, no se descarta

`config/source_value_tokens.csv` registra tokens con estado, significado, evidencia citada, **un
revisor con nombre** y fecha, bajo la misma disciplina que los demás registros. `layout_verified` se
rechaza explícitamente aquí: lo que un editor *quiere decir* con un token no es una afirmación sobre
maquetación, y sólo una persona puede hacerla.

`apply_observation_missingness()` clasifica ahora por el **texto** de la celda y no sólo por si se
parseó un número: token registrado → su estado; texto que parsea como número → `unread_source_cell`;
celda genuinamente vacía → `blank_in_source`; token no registrado → `source_token_unreviewed`, que
advierte en la release y bloquea la promoción.

| Razón | Antes | Después |
|---|---|---|
| `blank_in_source` | 20.156 | **1.740** |
| `no_movement` | — | **18.416** |
| `period_absent_from_axis` | 491 | 491 |

La semilla atribuye `s/m` → `no_movement` en `financial_indicators` y `economic_annex` a la
confirmación del usuario, citada como evidencia. No se registró ningún token que el usuario no haya
adjudicado: `s.d.`/`s/d` y `#N/A` tienen estado en el vocabulario pero no aparecen en estas fuentes,
y no se inventó una fila para ellos.

### F-04 — Las regiones de datos no leídas

**`Cuadro 5` y `Cuadro 7` de inversión directa.** El editor publica el encabezado año-trimestre en
dos filas: la fila 10 lleva el año de cada bloque trimestral en su primera columna, y la fila 11 los
trimestres más el año de la columna anual. El parser leía una sola fila y perdía 12.006 celdas.

La lectura de dos filas está **guardada por la aritmética del propio editor**: en una tabla de
stocks, el cuarto trimestre de un bloque debe igualar la columna anual que lo cierra. Si un libro
cambia de forma, `documented_assert_quarter_block_closes()` detiene la corrida en vez de desplazar
todos los períodos un año. Comprobación en ALEMANIA:

```
1995-12-31   522.375,1
1996-03-31   523.126,3
1996-06-30   528.691,3
1996-09-30   533.352,9
1996-12-31   538.145,7   <- Q4 del bloque
1996-12-31   538.145,7   <- columna anual etiquetada 1996
```

**El anexo `Cuadro 52a`/`52b`.** El eje horizontal terminaba en la columna que lleva la etiqueta del
período, de modo que las otras dos medidas del último mes nunca se leían (256 celdas).
`axis_last_column()` extiende el eje por el paso regular, hasta el final del bloque del último
período y no hasta su etiqueta.

**`data_not_ingested` cae de 12.371 celdas a cero.** Las cuatro reglas que registraban esa pérdida se
retiran junto con los defectos: una regla `data_not_ingested` no es una explicación, es un acta de
pérdida con el nombre de un revisor al pie. `direct_investment` vuelve a `minimum_parsed_sheets = 7`.

Inversión directa, resultado final: 7 hojas, 33.109 observaciones; `Cuadro 5` con 7.721 desde
1995-12-31 y `Cuadro 7` con 4.275.

### F-05 — Una proyección publicada se distingue de un dato realizado

`v_series_latest` y `series_as_of_date()` exponen `observation_status`; `v_series_latest_observed` y
`marts.v_series_projections` separan los dos conjuntos. 343 observaciones en 186 series están
fechadas después del vintage que las publicó: el anexo publica años de pronóstico hasta 2028 y
`fx_operations` hasta el cierre de 2026.

**Por decisión del usuario, la vista por defecto conserva las proyecciones.** Son lo que el editor
publicó. Eso significa explícitamente que `v_series_latest` **no es un default a prueba de
look-ahead**: una muestra de estimación debe filtrar `observation_status = 'observed'` o leer
`v_series_latest_observed`. `current_view_contains_projections` informa la cuenta en cada release
para que el número no se mueva sin que nadie lo note.

### F-10 — Grano de los paneles directos (adelantado desde P1)

Se hizo junto con F-04 porque ambos exigen la misma reingesta de ~900.000 filas de panel.

- Cada fila registra `source_row`, la fila física de la hoja.
- Cada panel declara `(vintage_id, source_sheet, source_row)` como clave natural, con índice único.
  Eso hace **representables** las 399 claves dimensionales duplicadas de `raw_banks_canales_person`
  en lugar de ambiguas; son en su mayoría pares `INHAB`/`REHAB` y totales en conflicto publicados en
  líneas separadas. Se conservan como el editor las escribió y se informan en
  `outputs/direct_panel_duplicate_keys.csv`. Adivinar la dimensión faltante sería inventarla.
- `codigo_entidad` y `codigo_moneda` se guardan como **texto**: son etiquetas, no cantidades, y un
  cero a la izquierda es parte del identificador. Los joins con las dimensiones de referencia ya no
  dependen de que sobreviva un round-trip por `TRY_CAST`.

## Esquema 28 — P1

- **F-09.** `stage_release()` deja en paz una release ya decidida: la aceptada sigue publicada
  mientras se construye la siguiente, y la promoción es un único `UPDATE` terminal. La fila de
  `ingestion_run_attempts` se escribe al **iniciar**, con estado `running`, y se cierra desde un
  manejador `on.exit()`; antes se escribía al final, de modo que el único caso en que el registro
  importaba —una corrida que muere— era el único que no dejaba registro.
- **F-12.** `validate_published_identities()` pregunta dos cosas en vez de una: primero, si todos los
  componentes declarados están presentes en ese período; sólo después, si el total iguala su suma. El
  `coalesce(..., 0)` permitía que un período con el total y la mitad de las partes pasara por
  accidente aritmético, que es el peor resultado posible porque es justamente donde el parser tiene
  más probabilidad de estar equivocado. La incompletitud se informa aparte como
  `published_identity_incomplete` (advertencia): cinco identidades tienen períodos en que el editor
  publica el total sin todos sus componentes, lo que no rompe la identidad —simplemente impide
  probarla.
- **F-11.** `source_files.release_id` pasa a llamarse `first_ingested_release_id`, y el contexto de
  release de una consulta se deriva por `release_sources`. Un vintage reutilizado deja de informar el
  bundle en que llegó como si fuera el actual.
- **F-06.** `available_at` en `raw.source_provenance` es la disponibilidad registrada por el
  operador, distinta de la fecha derivada del período de referencia, y manda sobre ella al ordenar
  vintages en `series_as_of_date()`. Se entrega en `pending`: los valores son del operador.
- **F-08.** Compuerta de elegibilidad para investigación: una serie no entra en un mart validado sin
  unidad, escala, frecuencia, stock/flujo, nominal/real y ajuste estacional, y `not_reviewed` no
  cuenta como valor. Pasa de forma vacía porque no hay nada promovido, que es exactamente el motivo
  de escribirla ahora y no después de la primera promoción.
- **F-07 / F-14.** Se entrega la maquinaria de adjudicación y la evidencia ordenada, no la decisión.
  `outputs/duplicate_series_candidates.csv` criba por firma md5 sobre los períodos compartidos;
  `outputs/canonical_core_candidates.csv` ordena los conceptos por cuánto unificarían;
  `validate_canonical_membership_agreement()` bloquea la release en que un alias declarado
  discrepa de su primaria.

## Esquema 29 — P2

- **Catálogos por grano.** `marts.v_catalogue_scalar_series` (7.599), `v_catalogue_event` (4.485),
  `v_catalogue_curve_panel` (1.287) y `v_catalogue_entity_panel` (770). Contar juntos una licitación
  de LRM y el índice de precios es lo que hace parecer la cobertura un orden de magnitud más amplia
  de lo que es. Se cuentan sobre `v_series_latest`, no sobre `fact_series_events`, para que un
  catálogo describa la base que se puede leer.
- **F-13 — Fórmulas en caché y estado oculto.** `raw.source_sheets` gana `formula_cells`,
  `hidden_rows` y `hidden_columns`. Ninguno de los dos sobrevive a ningún valor que el parser lea, y
  ambos cambian lo que un número significa: `readxl` no calcula, así que **todo** número aquí es un
  resultado en caché, y una fila oculta es una que el lector del propio editor no ve.

  Estado actual: 91.673 celdas con fórmula en 104 hojas, y 34 hojas que ocultan filas o columnas.
  Lo que no era visible antes: **15.403 observaciones publicadas, en 13 hojas, provienen de filas que
  el editor ocultó** — `CUADRO 32` (4.342), `Cuadro 21 a` (2.803), `CUADRO 56a` (2.194). El patrón
  es legible y benigno: el anexo colapsa la historia temprana de una tabla larga para que la hoja
  visible muestre los períodos recientes, y leerlas es lo correcto. Pero un bloque oculto es también
  el aspecto que tendría una serie retirada, así que se registra e informa en vez de suponerse.
  `workbook_behaviour_changed` es la comprobación que realmente importa, y sirve para el vintage
  siguiente.

  **No se reingestó ninguna fuente para obtenerlo.** Ambas propiedades son del libro, no del valor
  parseado, así que cada vintage ya archivado se rellenó desde su propio archivo. El relleno es
  idempotente y cubre las 284 hojas de las 22 fuentes.
- **F-16 — Tiempos por intento.** `audit.ingestion_stage_timings` se indexa por `attempt_id` y ya no
  se borra por release, y se cronometran las fases de release completa —reconciliación,
  clasificación de regiones, grilla esperada, faltantes, semántica, canónica, marts, validación— y no
  sólo el parseo por fuente. `observation_missingness`, con 20,7 s, resulta ser la fase más lenta de
  la corrida; no era medible antes.
- **F-15 — Reconstrucción limpia.** P0 y P1 se comitearon antes de la reconstrucción final, de modo
  que `audit.build_identity` registra un commit limpio.
- **F-17 — Documentación.** README titulado por el esquema que describe; qué garantizan `latest`,
  `as-of` y `validated`; corregida la afirmación de que los paneles bancarios no llevan número de
  fila. `docs/DATA_MODEL.md` y `docs/OPERATIONS.md` acompañan.

## Lo que no se hizo, y por qué

- **P3 completo**, por alcance acordado.
- **`config/canonical_series.csv` sigue vacío.** Declarar una serie canónica es afirmar su
  definición, dominio, frecuencia, unidad, moneda, carácter stock/flujo y nominal/real bajo un
  revisor con nombre: siete juicios económicos por concepto. Ninguna criba automática puede
  emitirlos, y escribirlos en nombre de un economista que no los ha hecho sería precisamente el
  defecto que esta base existe para evitar. Se entrega la maquinaria, las compuertas y la evidencia
  ordenada; el par `CUADRO 20`/`fx_operations` encabeza la lista con 5.480 coincidencias exactas.
- **Revisión stock/flujo y nominal/real, y regímenes de metodología.** Mismo motivo. Las columnas
  existen con vocabulario controlado y en `not_reviewed`, y
  `outputs/semantic_metadata_completeness.csv` informa la cobertura en lugar de insinuarla.
- **`marts.v_research_series` sigue devolviendo 0 filas**, y es la respuesta honesta: ninguna tabla
  ha pasado revisión económica.
- **F-18 (7,7 GiB de backups).** Es política operativa sobre archivos del usuario, no código; los
  respaldos previos a cada migración de esta ronda se conservaron deliberadamente.

### Un hallazgo implementado en versión más estrecha que la pedida

**F-13 se registra por hoja, no por celda.** La auditoría pide guardar la presencia y la expresión de
la fórmula "junto a cada celda cruda en `raw.report_cell_values`". Se registra en
`raw.source_sheets`: cuántas celdas de la hoja llevan fórmula, y qué filas y columnas están ocultas.

El motivo es que la unidad accionable es la hoja, no la celda. El parser trabaja por hoja; la prueba
de deriva —que es para lo que sirve realmente este registro— compara hojas entre vintages; y la
respuesta a "¿esta hoja cambió de comportamiento?" no mejora por saber cuál de sus 4.248 celdas con
fórmula lo hizo. A cambio, una bandera por celda ensancharía la capa cruda sobre más de un millón de
filas. Si en algún momento hace falta la expresión concreta de una fórmula, el libro archivado la
tiene y `xlsx_sheet_dimensions()` ya recorre su XML.

Lo que sí se agregó por encima de lo pedido, porque el estado por sí solo no justifica una
advertencia: las filas ocultas se cruzan contra las observaciones parseadas, y de ahí sale el número
que un investigador necesita —15.403 observaciones publicadas provenientes de filas ocultas.

**F-15 no era un árbol sucio.** `git_build_state()` se llama desde dentro del pipeline, cuando la
corrida ya escribió en el `.duckdb`, que está versionado. El archivo que la construcción estaba
*produciendo* contaba como cambio sin comitear contra la construcción que lo producía: insatisfacible
por definición, y una bandera que nunca puede estar limpia es una bandera que nadie lee. Se excluye
la base de datos y sólo la base de datos. Una llamada a git que falla ahora devuelve `NA` y nunca
`FALSE`: el primer intento de esta reparación usó un pathspec `:(exclude)`, el shell lo rechazó, el
comando no devolvió nada, y nada se leyó como árbol limpio —informó `FALSE` con código sin comitear
delante. Una comprobación de suciedad que falla en abierto es peor que la que reemplaza.

## Verificación

Base reconstruida: esquema **29**, 1.227.082 observaciones, 13.985 series, corrida
`completed_with_warnings` con **cero errores**.

| Comprobación | Resultado |
|---|---|
| Interfaces publicadas con join a `releases` | 43 de 43; 0 sin filtro |
| Paneles `v_latest_raw_*` filtrados / gemelas `_all` | 17 / 17 |
| `CUADRO 20`: unidad y escala | 30 de 30 en `USD` / 1e6 |
| `CUADRO 20` contra `fx_operations`, período a período | 5.480 de 5.480 |
| `blank_in_source` / `no_movement` | 1.740 / 18.416 |
| `source_token_unreviewed` | 0 |
| `observation_status = 'after_publication'` en `v_series_latest` | 343, todas alcanzables por `marts.v_series_projections` |
| `data_not_ingested` | 0 |
| `Cuadro 5` ALEMANIA: Q4 del primer bloque contra la columna anual | 538.145,7 = 538.145,7 |
| Paneles directos con `source_row` y clave única | 17 de 17 |
| `codigo_entidad` / `codigo_moneda` como `VARCHAR` | En todos los paneles |
| Hojas con `formula_cells` registrado | 284 de 284, en las 22 fuentes |
| `marts.v_research_series` | 0 filas |
