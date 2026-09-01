# Revisión de la sexta auditoría técnica (2026-08-31) — P0, P1, P2

Registro de lo que se implementó del informe `TECHNICAL_AUDIT_REPORT_2026-08-30.md` en su sexta
redacción, lo que se descartó y por qué. La auditoría se ejecutó **en modo de sólo lectura contra el
estado que dejó la ronda anterior** (`audit4-p0-p1-p2`, commit `4451cd6`, esquema 29, build
`edeae918…`). Confirma que aquella ronda aterrizó y encuentra dieciocho hallazgos, **R6-01 … R6-18**,
de los cuales tres son defectos del código escrito en esa misma ronda.

Cada afirmación cuantitativa se volvió a medir contra la base de datos viva antes de tocar código.
**Todas se reprodujeron.** Resultado: esquemas 30 (P0), 31 (P1) y 32 (P2).

## Verificación previa del diagnóstico

| Afirmación de la auditoría | Resultado de la comprobación |
|---|---|
| `release_filtered_object()` devuelve TRUE con sólo encontrar la cadena `releases` en el cuerpo de una vista | Confirmada (`scripts/04_validate.R:1552-1567`) |
| `v_series_observations` lee toda la tabla de hechos; su join con las releases aceptadas es un `LEFT JOIN` que sólo rellena una etiqueta | Confirmada. Las proyecciones y las vistas canónicas heredan la fuga |
| `v_series_missingness` sólo compara `series_id`; `v_fx_operations_annual` y `v_series_catalogue` no coinciden con ninguna regla de nombres | Confirmada, y **37 objetos públicos** quedaban fuera de la regla del lint |
| 14 intentos comparten `release:748d…`, abarcando los esquemas 26 a 29, y uno terminó `release_blocked` | Confirmada. `decide_release()` es un `UPDATE` incondicional sobre esa misma fila |
| `v_series_projections` conserva el join `DISTINCT (series_id, source_sheet)` | Confirmada. **Defecto propio**: el mismo que se reparó en los catálogos por grano un esquema antes |
| 35 banderas en la base y 33 en `quality_flags_latest.csv` | Confirmada. Faltan `regular_period_gaps` y `discontinuity_screen`, que corren *después* de la validación. **Defecto propio** |
| El informe de actualización usa las 488 filas de tiempos de la release en vez de las 55 del intento | Confirmada. **Defecto propio** |
| `docs/DATA_MODEL.md` afirma que la disponibilidad nunca se infiere del período de referencia | Confirmada como falsa: 12 de 22 fechas provienen de `content_max_period`. **Defecto propio** |
| `available_at` nulo en las 22 filas de procedencia; `series_as_of_date('2020-12-31')` devuelve 0 filas | Confirmada |
| Las 22 fuentes usan `newest_mtime`; `manifest` está implementado y sin usar | Confirmada |

## Decisiones del usuario tomadas antes de implementar

1. **Alcance: P0 + P1 + P2.** P3 queda fuera.
2. **R6-03 revierte la decisión de la ronda anterior.** `v_series_latest` pasa a contener **sólo
   observaciones realizadas**; la declaración completa del editor, proyecciones incluidas, se publica
   como `v_publisher_statement_latest`. Es un **cambio incompatible** en una interfaz publicada y se
   anuncia como tal.
3. **R6-02 se repara con decisiones inmutables, un puntero atómico y una transacción de release.**
   **No** se intenta versionar los hechos por build. Ese límite se documenta explícitamente en lugar
   de insinuar lo contrario.

## Esquema 30 — P0

### R6-01 — El lint demostraba lo que no era, dos veces

La primera versión nombraba dos objetos y una familia de marts; una auditoría encontró treinta y
cuatro vistas publicadas sin ningún filtro. La segunda cambió la lista por reglas de nombres. Esta
auditoría encuentra el problema de fondo: **una regla sobre nombres no puede decidir qué objetos son
interfaces de investigación, y buscar la palabra `releases` no puede decidir si un objeto filtra.**

Ambas mitades fallaban en concreto. `v_series_observations` lee la tabla de hechos completa y hace
`LEFT JOIN` con las releases aceptadas sólo para rellenar `accepted_release_id`, de modo que una fila
que no pertenece a ninguna release aceptada sobrevive con la etiqueta nula — y como el cuerpo
contiene la palabra, el lint la aprobaba, y aprobaba `v_series_projections` construida sobre ella, y
`v_canonical_observations` construida sobre esa. Mientras tanto `v_fx_operations_annual` y
`v_series_catalogue` no coincidían con ninguna regla, ni otros treinta y cinco objetos públicos.

Ninguna de las dos preguntas se infiere ya:

- **`config/public_view_contract.csv`** declara, por objeto, qué publica: `current`, `all`,
  `history`, `reference` o `diagnostic`, con una razón y un revisor. **Un objeto sin declarar bloquea
  la release** — que es el punto: una vista añadida sin que nadie diga si los investigadores deben
  leerla es justamente el fallo que el registro existe para atrapar.
- **El filtrado se decide por descendencia**, no por subcadena: un objeto califica si lleva el límite
  en su propio cuerpo —declarado como `carries_release_boundary` y verificado contra el SQL
  almacenado— o si lee algo que lo lleva. Nunca a través de una gemela `_all`. Olvidar declarar una
  vista nueva hace que el lint **falle**, no que pase.

`v_series_observations` pasa a ser la relación base filtrada, con `v_series_observations_all` como
gemela; `v_fx_operations_annual` y `v_series_catalogue` se filtran y ganan sus gemelas.

**Resultado: 62 objetos `current`, 0 sin filtrar, 121 objetos declarados.**

### R6-02 — Un build fallido podía retirar la base de datos que no logró reemplazar

Un `release_id` es el hash de los archivos fuente. Catorce intentos a través de cuatro versiones de
esquema compartieron uno, y el único que falló puso esa fila compartida en `blocked`. Como toda vista
publicada hacía join con `releases.status = 'accepted'`, **un fallo al reconstruir vaciaba toda la
base publicada**.

Tres identidades, como plantea la sección 16.1 de la auditoría:

| Identidad | Qué resume | Qué significa |
|---|---|---|
| `release_id` | el SHA-256 de cada archivo fuente | "estos archivos" |
| `build_id` | la release, el commit, la versión de esquema y los digests de `config/`, `scripts/` y `renv.lock` | "este código, sobre esos archivos" |
| `data_release_id` | las dos anteriores, como producto decidido | "esta base de datos" |

- `audit.data_releases` registra **una decisión por producto, insertada una vez y nunca reescrita**.
  Volver a decidir el mismo producto igual es un no-op; decidirlo distinto es un error.
- `audit.active_data_release` es un puntero de una fila, intercambiado en una transacción y **sólo
  por un build aceptado**. Un build bloqueado registra su veredicto y se detiene.
- `validate_active_data_release()` comprueba los tres invariantes de los que depende toda la vista
  publicada —hay exactamente un puntero, nombra una decisión que existe, y esa decisión es una
  aceptación— porque un invariante que nada comprueba es un comentario. Es la prueba 7 de la
  auditoría.

**La transacción de release importa tanto como el puntero.** Sin ella el puntero es teatro: un build
que moría a mitad ya había borrado y reconstruido a medias la reconciliación, la clasificación de
regiones, la semántica, la grilla esperada y los faltantes bajo una release todavía marcada aceptada.
Las fases de release completa corren ahora en una transacción; DuckDB revierte DDL y DML juntos.

Eso exigió `with_project_transaction()`, que se une a una transacción exterior en lugar de abrir una
segunda —DuckDB no tiene transacciones anidadas y ocho de esas fases abrían la suya—. Detectar la
exterior intentando un `BEGIN` **no funciona**: el intento fallido aborta la transacción que estaba
sondeando, y todo lo siguiente falla con "current transaction is aborted".

**Lo que esto no da, y se dice sin adornos.** Los hechos no se versionan por build. La garantía es
que un build fallido no puede retirar ni corromper el publicado, **no** que se pueda reconstruir el
producto de un build arbitrario del pasado. Eso requeriría un espacio de nombres de hechos por build
y no se intenta.

### R6-03 — El nombre que sonaba seguro era el inseguro

El esquema 27 mantuvo las proyecciones en `v_series_latest` exponiendo `observation_status` al lado,
razonando que la vista responde "qué dice hoy el editor" y una proyección es parte de esa respuesta.
El razonamiento era correcto y el nombre no: `v_series_latest` es el default obvio, es lo que toma
cualquier consulta de ejemplo, y quien no lee la columna se lleva pronósticos de 2028 a una muestra
de estimación.

| Vista | Contiene |
|---|---|
| `v_series_latest` | sólo observaciones realizadas — el default de investigación |
| `v_publisher_statement_latest` | la declaración completa del editor, con las 343 proyecciones |
| `marts.v_series_projections` | las proyecciones solas |
| `v_series_latest_observed` | alias en desuso de `v_series_latest` |
| `series_as_of_date(d)` / `series_statement_as_of_date(d)` | la misma división, punto en el tiempo |

Una proyección que llegue a `v_series_latest` es ahora un **error**, no una advertencia que recordar.

### R6-10 — Fan-out en las proyecciones

`v_series_projections` conservaba `LEFT JOIN (SELECT DISTINCT series_id, source_sheet …)` sobre
`series_id` solo — el mismo defecto encontrado y reparado en los catálogos por grano un esquema
antes, y esta copia se pasó por alto. Doce series de `bcp_fx_daily` abarcan catorce hojas anuales.
Latente hoy sólo porque las proyecciones actuales están en una hoja cada una. `o.source_sheet` ya
venía en la fila.

### R6-04 (parte) — Grilla y faltantes versionados

`expected_observation_grid` y `observation_missingness` ganan `vintage_id` y `build_id`.
`v_series_missingness` filtra por vintage aceptado en vez de comparar `series_id`.

## Esquema 31 — P1

- **R6-11.** Las banderas se atribuyen al intento que las levantó y ya no se borran por `release_id`
  al empezar una corrida, así que volver a ejecutar un bundle deja de destruir la evidencia
  diagnóstica del build aceptado. El informe de banderas se escribe **después** de las cribas
  estadísticas, se compara contra la base y se reescribe. El informe de actualización pasa de 696
  filas de tiempos (ocho intentos) a **56** (este intento). El `attempt_id` se pasa por argumento:
  el informe se escribe después de cerrar el intento, y la búsqueda caía silenciosamente a la
  release, que es como llegaron ahí las 696 filas.
- **R6-15.** Corregida la afirmación sobre `available_at`, que era mía. Se documenta la cadena real
  de autoridad, que 12 de 22 fechas derivan del máximo del contenido, que
  `series_as_of_date('2020-12-31')` devuelve cero filas, y que **no debe hacerse ninguna afirmación
  de tiempo real** hasta que la procedencia esté registrada.
- **R6-04.** `outputs/source_provenance_worklist.csv` nombra, por vintage, qué campos faltan y qué
  cuesta cada uno, separando `available_at` —del que depende toda afirmación punto-en-el-tiempo— de
  los cuatro que sólo afectan la re-adquisición. **No se inventa ninguna fecha.**
- **R6-07.** La cola de regiones se ordena por el peso económico de la hoja y no por cantidad de
  celdas, como pide la auditoría: 6.522 celdas ordenadas por volumen ponen primero las hojas anuales
  de subastas LRM, y nadie debería revisarlas antes que el índice de precios. Ahora encabezan las
  tablas del anexo con dominio macro declarado.
- **Dos compuertas que pasan de forma vacía, que es por qué se escriben ahora.** Una membresía
  canónica declarada se comprueba por **comparabilidad** además de por igualdad: alias que difieren
  en unidad, escala o frecuencia, y alias que no comparten ningún período con su primaria y por lo
  tanto nunca fueron probados, bloquean la release. Y un panel directo que llegue a un mart agregado
  bloquea la release mientras 411 grupos de filas repitan toda dimensión modelada.

## Esquema 32 — P2

- **R6-14.** Las 22 fuentes se seleccionan por el SHA-256 registrado. Con un candidato —el caso
  mensual normal— la regla no se activa; con dos, la corrida **se detiene** y nombra la solución en
  vez de adivinar por fecha de modificación.
- **Sección 4.3.** El grano se declara por hoja además de por fuente, con clave
  `(source_id, source_sheet)` y `*` como regla de fuente. `direct_investment` es `scalar_series` y
  sus `Cuadro 5` y `Cuadro 7` son paneles por país: 214 identificadores salieron del catálogo macro,
  que queda en **7.229**.
- **R6-13.** `marts.v_observation_source_behaviour` expone `from_hidden_row` y `sheet_formula_cells`
  **por observación**. Registrarlo por hoja era el grano correcto para la prueba de deriva y el
  equivocado para un investigador con un número en la mano. Derivado, no almacenado.
- **R6-18.** `audit.distribution_artifacts` registra la identidad del archivo `.duckdb`, de modo que
  el commit que lo lleva —necesariamente posterior al build que lo produjo— deja de parecer una
  discrepancia de procedencia.
- **R6-16.** La fase dominante se salta cuando el `build_id` almacenado en la grilla coincide con el
  actual. Es una guarda más fuerte que "¿cambió alguna fuente?", porque `build_id` resume también el
  código y la configuración: editar la lógica de faltantes, un registro de tokens o una declaración
  de frecuencia la cambia y fuerza la reconstrucción. Medido: **19,08 s → 0,03 s**, con las mismas
  20.647 filas.

## Tres defectos propios encontrados al verificar, que la auditoría no nombra

- **La interfaz de lectura soportada saltaba el límite de release por completo.** `series_as_of()`
  en `scripts/05_query_helpers.R` —el archivo que el manual de operaciones llama la interfaz de
  lectura soportada— ordenaba `canonical.fact_series_events` directamente, sin filtro de release y
  sin estado de observación. Ni el lint ni el nuevo contrato de vistas lo miraban, porque ambos
  razonan sobre **objetos almacenados** y esto es una función de R: la misma clase de hueco que
  R6-01, una capa más afuera. Además respondía una pregunta distinta que la macro homónima: ordenaba
  por fecha de publicación donde `series_as_of_date()` ordena por `available_at`. Dos
  implementaciones de "as of" es en sí el defecto. Ahora delega en la macro, y una prueba afirma que
  todo el archivo lee sólo superficies publicadas.
- **Un `DBI::dbBegin()` desnudo podía abortar la transacción en la que estaba.** La ingesta por
  fuente abre su transacción de forma explícita, cruzando un `tryCatch`, y no la registraba — así que
  la primera unidad interior que pedía una transacción intentaba abrir una segunda, y en DuckDB ese
  `BEGIN` fallido aborta la transacción sobre la que preguntaba. Sólo una ingesta completa toma ese
  camino, que es por qué hizo falta construir una base desde los libros reales para encontrarlo.
- **La comprobación de conexión fresca podía colgarse en vez de fallar.** Una segunda conexión a un
  archivo DuckDB cuyo escritor tiene una transacción abierta **espera** en lugar de dar error, de modo
  que una transacción filtrada convertía la release en un bloqueo sin nada que leer. Ahora se informa
  como `release_transaction_left_open` y la comprobación se omite: **diagnosticar es mejor que
  colgarse.**

## Lo que no se hizo, y por qué

- **P3 completo**, por alcance acordado.
- **R6-05, R6-06, R6-08, R6-09 — el núcleo canónico, la semántica económica, la adjudicación de
  duplicados y las dimensiones de los paneles directos.** Se entrega la maquinaria, las compuertas y
  la evidencia ordenada. `config/canonical_series.csv` sigue vacío y `marts.v_research_series` sigue
  devolviendo **0 filas**. Declarar una serie canónica es afirmar siete propiedades económicas bajo
  un revisor con nombre; ninguna criba automática puede emitirlas.
- **R6-04 (los valores).** La procedencia de adquisición es conocimiento del operador. El mecanismo
  está completo, la cola está escrita, y no se inventó ninguna fecha ni URL.
- **R6-07 (la revisión).** Las 6.522 celdas requieren que una persona lea hojas de cálculo. Se
  entrega la cola priorizada.
- **R6-17 (11 GiB de respaldos).** Es política operativa sobre archivos del usuario, no código.

## Verificación

Base reconstruida: esquema **32**, corrida `completed_with_warnings` con **cero errores**.

**El criterio de aceptación de R6-01 y R6-02 no es el lint sino
`tests/testthat/test-audit6-release-isolation.R`**: una base aislada que realmente contiene un
vintage que nadie puede ver, con cada interfaz `current` interrogada por él, y con las gemelas `_all`
comprobadas para que la prueba no pueda pasar de forma vacía. La prueba anterior pasaba reutilizando
el mismo predicado defectuoso que el código, y por eso no demostraba nada.

| Comprobación | Resultado |
|---|---|
| Objetos públicos declarados / `current` / sin filtrar | 122 / 62 / **0** |
| Interfaces `current` que devuelven el vintage retenido | 0 |
| Gemelas `_all` que sí lo devuelven (la prueba no es vacía) | sí |
| Un build fallido mueve el puntero activo | no |
| Una decisión registrada puede reescribirse | no |
| Punteros activos (exactamente uno, aceptado, con vintages) | 1 |
| Una fase que muere revierte las tablas derivadas | sí |
| `v_series_latest` con `after_publication` | 0 |
| `v_publisher_statement_latest` con proyecciones | 343 |
| `marts.v_series_projections` único por (vintage, serie, período) | sí |
| `quality_flags_latest.csv` frente a la base | 35 = 35 |
| Tiempos del informe frente al intento | 56 = 56 |
| Grilla y faltantes con `vintage_id` | sí |
| Catálogo macro tras el override de grano | 7.229 |
| Observaciones desde filas ocultas, por observación | 15.403 |
| Faltantes: `no_movement` / `blank_in_source` | 18.416 / 1.740 |
| Fase de faltantes reutilizada | 19,08 s → 0,03 s |
| `marts.v_research_series` | **0 filas** |
