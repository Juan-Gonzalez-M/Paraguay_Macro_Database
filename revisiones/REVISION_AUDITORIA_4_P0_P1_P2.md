# Revisión de la auditoría técnica del 2026-08-30 — P0, P1, P2

Registro de lo que se implementó del informe `TECHNICAL_AUDIT_REPORT_2026-08-30.md`, lo que se
descartó y por qué. Cada afirmación cuantitativa del informe se volvió a medir contra la base de
datos viva antes de tocar código; todas se reprodujeron.

## Verificación previa del diagnóstico

| Afirmación de la auditoría | Resultado de la comprobación |
|---|---|
| 422 hechos de `compensatory_fx_sales` con 2026-12-31 frente a 2026-07-31 en `raw.source_files` | Confirmada. El `snapshot` y `input_archive/archive_manifest.csv` también decían 2026-12-31 |
| 1.214.347 hechos, 14.423 series, 22 vintages, 0 filas en los marts validados | Confirmada |
| 4.054 series con unidad sin resolver; 13.649 sin revisión stock/flujo; 14.386 sin nominal/real | Confirmada |
| Siete snapshots de `staging` sin clave primaria | Confirmada |
| `v_series_latest` no filtra por release aceptada | Confirmada (`scripts/02_extract_raw.R`) |
| Sin `renv.lock`; `run_tests.R` instala paquetes | Confirmada |
| El README promete archivo, hoja, fila y columna para todo valor | Confirmada como falsa para ICC, EVE y FX |
| La documentación operativa aún dice `completed_with_errors` | Confirmada |

## P0

### F-01 — Autoridad de la fecha de publicación

La auditoría describe el síntoma. La causa son dos defectos independientes.

**El pin obsoleto.** `set_source_publication_date()` sólo escribía cuando la fecha registrada era
nula o seguía marcada `pending_content_inference`. Una fecha derivada del contenido no podía
corregirse nunca: cuando el parser leyó más hoja en una revisión posterior, el `snapshot` y 422
hechos pasaron a 2026-12-31 mientras `source_files` seguía en 2026-07-31. La regla ahora compara
autoridades — `official_registry` > `filename` > `content_max_period` — y una autoridad igual o
mayor puede reafirmar la fecha.

**El máximo del contenido como sustituto de la fecha de publicación.** En el libro de ventas
compensatorias, el bloque de 2026 sólo tiene valores reales hasta julio. Agosto a diciembre tienen
las dos componentes vacías y sólo un `Total` con un cero en caché de su propia fórmula `=+G+H`
(`I107` conserva la fórmula; `I114` a `I118` figuran en `xl/calcChain.xml`). Esos cinco ceros son
los que arrastraban `max(period)` a 2026-12-31. El `dcterms:modified` del libro es 2026-08-03.

Decisión del usuario: son plantilla, y la fecha autorizada es **2026-07-31**.

Implementado:

- `config/source_vintages.csv`: registro de procedencia mantenido por el operador y fuente de
  máxima autoridad para la fecha. Se entrega con todas las filas en `pending`.
- `resolve_vintage_publication_date()` decide la fecha antes de leer una sola celda.
- `propagate_vintage_publication_date()` copia la fecha desde `source_files` a toda tabla que
  lleve `vintage_id` y `publication_date` — el conjunto se descubre del catálogo, no de una lista.
  Se ejecuta dentro de la transacción de cada fuente y en la migración.
- En `documented_parse_compensatory_sales()`, las filas finales de un bloque anual cuyas
  componentes están vacías **y** cuyo total es cero son plantilla. Un cero publicado entre dos
  meses informados sigue leyéndose — la reparación del esquema 23 se conserva — y un mes final
  informado como un único total distinto de cero también.
- Nuevas puertas: `fact_publication_date_mismatch` (error), `publication_date_not_monotonic`
  (error), `publication_date_source_contradicts_content` (aviso) y
  `publication_date_inferred_from_content` (aviso).

Resultado medido: `compensatory_fx_sales` pasa de 422 a 417 hechos, `max(period)` 2026-07-31, y
**cero** discrepancias de fecha entre `source_files`, el `snapshot`, los hechos y el manifiesto.

El aviso `publication_date_source_contradicts_content` encontró de inmediato un segundo caso que la
auditoría no había visto: `fx_operations` declara 2026-07-31 como máximo del contenido mientras el
contenido llega a 2026-12-31.

### F-03 — Celdas fuera de la región del parser

**`payments/SIPAP_12`.** La razón registrada era incorrecta. El informe decía que la columna 18 y la
columna 12 del CUADRO 35 son indistinguibles en la matriz de celdas y que sólo los rangos
combinados las separan — y los rangos combinados las separan: `SIPAP_12` tiene `mergeCell
ref="Q2:R2"`, y el CUADRO 35 no tiene ninguna combinación sobre la columna L. La identidad
publicada lo confirma: en la fila 54 las cinco columnas de *Cantidad* suman exactamente el TOTAL SPI
publicado, 63.735.362, y las cinco de *Importe Destino* suman 21.232.517.839.313.

Los rangos combinados se extraen ahora en `xlsx_sheet_dimensions()`, se guardan en
`raw.source_sheets.merge_ranges` como procedencia publicada, y admiten una columna sin cabecera
propia cuando una cabecera de grupo combinada la abarca junto a una columna ya aceptada.

**Los bloques del mercado interbancario.** La ventana de recuperación de columnas iba sólo del
primer al último dato reconocido, así que un bloque publicado fuera de ese tramo no se examinaba
nunca — en ninguna de las dos direcciones. Se perdían tres bloques con cabecera: *Call Money Market
(PYG)* (columnas 3-8, antes del primero) y, en «Datos (+ de 1 día)», el *Plazo* del Call Money USD
y todo el bloque de *Facilidad de Crédito Especial* (columnas 26 y 28-30, después del último). La
ventana es ahora el tramo que el publicador encabezó.

Radio de impacto medido sobre las 113 hojas de modo `vertical_date`: 647 celdas recuperadas, cero
perdidas, y ninguna hoja afectada fuera de los casos revisados.

**El registro fuera de región.** `audit.source_region_classification` se construye desde la capa de
celdas en bruto **con independencia de lo que el parser emitió**, que es la única forma de decir
algo sobre completitud de ingesta. El universo de hojas son todas las hojas documentadas, no las que
produjeron observaciones — una hoja de la que el parser no lee nada no tiene región y desaparecería
de la contabilidad justo cuando más importa. Cada celda resuelve contra
`config/source_region_rules.csv` o queda `unreviewed`.

Estado tras la reconstrucción:

| Clasificación | Celdas | Hojas |
|---|---:|---:|
| `period_axis` | 46.745 | 140 |
| `data_not_ingested` | 12.371 | 4 |
| `unreviewed` | 7.695 | 50 |
| `report_layout_derived` | 6.706 | 8 |

`unreviewed` y `data_not_ingested` bloquean la promoción a `validated`; no bloquean la release,
porque una puerta que nadie puede pasar es una puerta que se acaba desactivando.

### Un defecto material que la auditoría no llegó a ver

Al construir el registro apareció `direct_investment`. Las hojas Cuadro 5 y Cuadro 7 ponen el año y
sus cuatro trimestres en una misma fila de cabecera. El parser de año-trimestre busca los
trimestres en una fila *por debajo* de la del año; al no encontrarlos, `which.max` sobre un vector
de ceros devolvía el primer candidato, que es la primera fila de datos. El resultado no era una
omisión silenciosa:

- el saldo de ALEMANIA de 1995 se convirtió en cabecera;
- las 72 series de Cuadro 5 quedaron etiquetadas con tres de sus propios valores;
- las 105 filas de ambas hojas quedaron fechadas 2024-12-31 en la única columna que sobrevivió;
- las otras 12.006 celdas publicadas no se leyeron nunca.

Las 105 filas corruptas se eliminan. Las 12.006 celdas **no** se recuperan en esta revisión y quedan
registradas como `data_not_ingested`: leer el bloque correctamente exige las dos filas de cabecera
juntas, porque la fila 10 nombra el año de cada bloque trimestral y la fila 11 nombra el año de la
columna anual que lo cierra. Es comprobable: el cuarto trimestre del primer bloque de ALEMANIA,
538.145,747, coincide con la columna anual etiquetada 1996 que le sigue, no con la 1995 que la
precede. Publicar 12.006 observaciones fechadas un año antes sería peor que no publicarlas.

### F-04 — Barrera de publicación por release aceptada

`audit.releases` da a la release un ciclo de vida (`staged` → `accepted` | `blocked`). Las fuentes
siguen confirmándose de una en una — es lo que evita que un libro roto detenga el diagnóstico del
siguiente — pero nada publicado lee una release en `staged`. El filtro va **en SQL**, así que la
decisión es un solo `UPDATE` atómico y ninguna vista se reconstruye para aplicarla.

Filtran por release aceptada: `v_series_latest`, la macro `series_as_of_date()`, `marts.v_mart_*` y
`marts.v_research_series`. `v_series_latest_all` conserva la vista sin filtrar para diagnóstico y
para la detección de revisiones durante la ingesta. La puerta `blocked_release_visible` comprueba
las dos cosas: que las filas visibles pertenezcan a una release aceptada y que el SQL almacenado de
cada interfaz publicada siga uniéndose a `releases` — lo segundo es la garantía real, porque una
vista reescrita sin el join publicaría una release bloqueada sin que ninguna prueba de filas lo
notara.

Comprobado sobre una copia: con la release aceptada, `v_series_latest` devuelve 1.214.830 filas y
`series_as_of_date()` 1.212.070; al marcarla `blocked`, ambas devuelven 0 y `v_series_latest_all`
sigue devolviendo 1.214.830.

### Lo que no se tocó

«Mantener vacías las vistas de investigación validadas» ya estaba implementado en
`scripts/11_marts.R` y no necesitaba cambios. `marts.v_research_series` sigue devolviendo 0 filas:
nada de esta revisión promueve ningún dato.

## P1

### F-14 — Procedencia de adquisición

`config/source_vintages.csv` se carga en `raw.source_provenance` junto a la vintage que describe,
unida por `(source_id, sha256)` y no por el nombre del archivo, que es justamente lo que el
publicador cambia sin avisar. `v_source_provenance` informa `complete` o `incomplete` por vintage.

La puerta `source_provenance_incomplete` es un aviso mientras la fuente es provisional — completar
el registro es trabajo del operador, no del parser — y pasa a error en cuanto alguien declara
`validated` una hoja de esa fuente: un producto de investigación que nadie puede volver a obtener no
es reproducible. Hoy las 22 vintages están en `pending` y el aviso las lista.

### F-12 — Ausencia con motivo

Los parsers saltan los `NA`, así que un período que el publicador no informó y un período que el
parser no leyó son indistinguibles desde fuera: en ambos casos falta la fila. Significan lo
contrario.

`staging.expected_observation_grid` es la secuencia regular que implica la frecuencia declarada de
cada serie, entre su primer y su último período — nunca más allá: una serie que empieza en 2015 no
«perdió» 2014. Sólo se construye para frecuencias con calendario regular (mensual, trimestral,
anual): una serie diaria no pierde los fines de semana. Y sólo si todos los períodos observados de
la serie caen sobre esa grilla; si no, la serie no es regular, diga lo que diga la columna.

Cada período esperado sin observación se clasifica contra la capa de celdas en bruto:

| Motivo | Períodos | Significado |
|---|---:|---|
| `blank_in_source` | 20.156 | la celda está en el libro y no tiene número |
| `period_absent_from_axis` | 491 | la hoja no tiene fila ni columna para ese período |
| `unread_source_cell` | 0 | la celda tiene un número y el parser no lo leyó |
| `axis_position_ambiguous` | 0 | la hoja coloca el período en varias coordenadas |

Los 18.448 huecos de `financial_indicators` que la auditoría reporta quedan así respondidos: las
celdas están y están vacías. No es pérdida de datos.

Se mantiene la invariante que hace útil el registro: **grilla = observado + ausente con motivo**
(267.830 = 247.183 + 20.647). Un tercer grupo silencioso sería exactamente la ambigüedad que se
quería eliminar.

Llegar a eso costó tres correcciones que vale la pena registrar, porque las tres producían el mismo
síntoma — huecos que no existen:

- `summarise()` resuelve un `.data$source_row` posterior a la columna que esa misma llamada acaba de
  crear, así que `min()` sobre ella devolvía un único valor y el límite del bloque colapsaba a «la
  primera fila de la serie». Descartaba 18.448 huecos reales.
- En las hojas de cotizaciones el mismo par de columnas se reutiliza en varios bloques anuales, de
  modo que una serie ocupa años disjuntos. Los meses intermedios resuelven a celdas que sí se
  leyeron, como otra serie. Son 2.090 en `EURO Prom`, y no son pérdida sino una cuestión de
  identidad, que la maquinaria de carriles posicionales ya informa.
- Un período que la hoja coloca en varias coordenadas no se puede ubicar, y elegir la primera
  nombraba la celda de otro bloque.

`unread_source_cell`, `axis_position_ambiguous` y `unreviewed` bloquean la promoción a `validated`;
`blank_in_source` no, porque es una respuesta.

### Identidades publicadas

`config/aggregate_identities.csv` sólo recoge identidades que el publicador enuncia, en una nota al
pie o en la propia cabecera del bloque, y las enuncia sobre **columnas**: las etiquetas cambian con
cada reparación del parser, las columnas de la hoja no.

Las cinco cargadas se cumplen en todos los períodos publicados:

- `SIPAP_12` TOTAL SPI (I) = D+E+F+G+H, en *Cantidad* y en *Importe Destino* (nota de la fila 64).
- `SIPAP_12` TOTAL ALIAS (C) = A+B, en ambas medidas (nota de la fila 58).
- Mercado Interbancario de Fondos = CMM + REPO Interbancario + REPO Tripartito, enunciada en la
  cabecera de la fila 18, verificada en los 3.287 días publicados.

La segunda es lo que identifica la columna 18 de `SIPAP_12`, que el publicador dejó sin
sub-cabecera, como el *Importe Destino* del bloque QR.

### F-05 — Comportamiento con dos vintages

La maquinaria existe y ahora se ejercita de extremo a extremo sobre dos vintages sintéticas en
`tests/testthat/test-audit-p1-p2-remediation.R`: revisión registrada con valor anterior y nuevo,
lápida para la serie que deja de publicarse, `series_as_of_date()` devolviendo 100 en marzo y 107 en
junio, y la barrera de release retirando ambas de toda interfaz al bloquearla. Lo que sigue sin
demostrarse, y se dice explícitamente, es que una revisión real del BCP se comporte así: para eso
hacen falta publicaciones sucesivas que hoy no existen en `input_archive/`.

### F-02, F-06, F-13 — Revisión económica (placeholder)

No se escribe ninguna revisión. `outputs/semantic_review_worklist.csv` ordena las 13.927 series con
algún campo sin revisar por peso: primero las que ya tiene mapeadas una serie canónica, después las
de unidad sin resolver, después por número de observaciones, con el estado de revisión y de
conciliación de su hoja al lado. Es una cola de trabajo para un economista, no un sustituto de su
firma.

## P2

### F-09 — Entorno de ejecución

`renv.lock` registra R 4.5.1 y 61 paquetes: los 19 que el proyecto carga y su árbol transitivo. Se
generó con `renv::snapshot()` sobre la biblioteca ya verificada, **sin** `renv::init()`, para no
activar renv por `.Rprofile` y cambiar la ruta de biblioteca de toda sesión abierta en el directorio.
Restaurarlo (`renv::restore()`) sigue siendo un acto deliberado del operador.

`run_tests.R` ya no instala nada. Antes cargaba `scripts/00_install_packages.R`, así que correr las
pruebas podía modificar el entorno que estaban probando — y eso es también lo que hacía imposible
ejecutarlas en CI o durante una auditoría. Ahora llama a `check_environment()`, que compara la sesión
con `renv.lock` y avisa; en modo estricto detiene. No instala.

### F-08 — Identidad de la construcción

`release_id` es un hash de los archivos de origen. Eso es lo que lo hace determinista y también lo que
lo vuelve insuficiente: con otro parser, el mismo `release_id` nombra otras observaciones.
`audit.build_identity` responde la otra pregunta — commit de Git y si el árbol estaba sucio, versión
de esquema, digest de `config/`, digest de `scripts/` y `run_update.R`, digest de `renv.lock`, versión
de R — y `build_id` los resume. `release_id` significa «estos archivos»; `build_id`, «esta base».

`audit.ingestion_run_attempts` guarda un intento por ejecución, se agrega y no se reescribe.
`ingestion_runs` sigue teniendo una fila por release, porque una release es determinista; un intento
no lo es, y hasta ahora la pregunta operativa «qué pasó las últimas cinco veces» no tenía respuesta.

### F-10 — Claves de las tablas de staging

Los siete snapshots declaraban una clave natural en la documentación y en el código de validación, y
la base de datos no la conocía. Ahora un índice único la impone físicamente y
`validate_declared_natural_keys()` verifica en cada release tanto la clave como los campos
obligatorios de la tabla.

No se reconstruyeron las tablas para ponerles una `PRIMARY KEY`: DuckDB no puede añadirla a una tabla
poblada sin recrearla, y recrear seis snapshots junto con todas las vistas que dependen de ellos es un
riesgo grande a cambio de uno pequeño. El índice cubre la unicidad; la aserción cubre la nulidad, que
es la alternativa que la propia auditoría ofrece.

### F-11 — Elección del archivo de origen

`selection_rule = 'manifest'` resuelve el archivo por el SHA-256 que el operador registró en
`config/source_vintages.csv`. `newest_mtime` sigue disponible y ahora dice en el aviso lo que
realmente hace: la fecha de modificación es cuándo el archivo llegó a este disco, no cuándo el
publicador lo publicó.

### F-15 — Documentación

`README.md` y `docs/OPERATIONS.md` ya no dicen `completed_with_errors`, y explican qué implica una
release bloqueada: no se publica nada por ninguna interfaz de investigación hasta que la ejecución se
repita sin errores. La afirmación de procedencia de la línea 7 del README se acotó por familia de
fuentes, que es lo que realmente ocurre. `docs/VERIFICATION.md` describe el entorno ejecutable actual
en lugar de decir que R no está instalado. `revisiones/README.md` indica qué notas son registro
histórico y cuáles son la guía vigente, y cada nota superada lleva ahora un encabezado que lo dice.
