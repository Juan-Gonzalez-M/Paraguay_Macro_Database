# Revisión del piloto — versión 9

## Alcance de lo verificado

Corrido en este entorno, contra los 22 archivos reales de `input/current/`:
`scripts/00_install_packages.R`, `run_tests.R` (batería completa de testthat) y
`run_update.R` **dos veces seguidas** (para verificar idempotencia). Cada falla de
ingesta se reprodujo además de forma aislada — cargando sólo los scripts necesarios e
invocando la función exacta sobre el archivo real, con el *call stack* completo
capturado en el punto del error — no es lectura de código sin ejecutar. Se hizo un
intento de mutación de guard sobre una copia real (ver sección de mutación); se
contrastaron los resultados persistidos contra la tabla de verdad conocida de
`CLAUDE.md` para las fuentes que llegaron a cargar.

**No se pudo hacer esta vez:** `AUDITORIA_REGRESIONES.md` no está presente en esta
versión del proyecto (desapareció entre la sesión anterior y esta — no hay forma de
saber si fue un cambio intencional o un artefacto de la subida). Lo reconstruyo al
final de este informe con el estado verificado de R1–R25 más los hallazgos nuevos,
pero no hay forma de confirmar que coincide con lo que el equipo tenía antes de
borrarlo. Tampoco se completaron pruebas de mutación de guard sobre copias de archivo
reales más allá de un intento (ver abajo) — la evidencia de guards que sí frenan viene
en cambio de un test unitario existente del proyecto y de dos guards que se dispararon
orgánicamente contra datos reales durante esta misma corrida, lo cual es, si acaso,
evidencia más fuerte que una mutación sintética.

Este informe es la continuación directa de una revisión informal de la sesión
anterior (`revisiones/REVISION_v8_errores_ingesta.md`, contra el código v8). Cada uno
de los defectos reportados ahí se verificó de nuevo, uno por uno, contra el código v9
actual.

---

## Veredicto

Se puede usar para lo que carga: de 22 fuentes, **19 cargan limpio** (subió de 11 en
la revisión anterior). Las seis fuentes con "claves duplicadas" que bloqueaban media
base la sesión pasada quedaron resueltas, y con un mecanismo genuinamente bien
diseñado (`identity_stability = "positional_lane"`), no un parche. Lo que más importa
ahora: **de las tres fuentes que todavía no cargan, dos (`economic_annex`,
`exchange_houses`) son fuentes centrales** — el Anexo Estadístico es la fuente más
grande del proyecto (94 hojas) y Casas de Cambio es requerida — así que aunque el
porcentaje de éxito mejoró mucho, el impacto de lo que sigue roto no es menor. Además,
`exchange_houses` lleva ya tres bugs distintos en tres revisiones seguidas, todos
originados en la misma trampa de fondo (hojas vacías por fórmulas) — vale la pena una
revisión de una vez por todas de ese mecanismo en lugar de seguir cerrando síntomas
uno por uno.

---

## Regresiones verificadas (contra el estado conocido de `AUDITORIA_REGRESIONES.md`)

| id | Estado | Evidencia de esta corrida |
|---|---|---|
| R1 | CERRADO | Segunda corrida `run_update.R`: `input_archive/` sigue con 22 archivos + manifest, no creció. |
| R2 | CERRADO | Mismo `release_id` (`release:748d41036c3a73638a1c2086`) en ambas corridas; `ingestion_runs` tiene 1 sola fila, no 2. |
| R3 | CERRADO | `fx_operations_snapshot`: 5.480 filas, 370/1.320/3.790 por frecuencia — igual a la tabla de verdad de CLAUDE.md. |
| R4 | CERRADO (con matiz) | `assert_direct_structure()` frena para `banks`/`financial` (modo `direct`). Test dedicado `test-structure-guards.R:10-15` pasa. No se pudo mutar un archivo real completo por una limitación de la herramienta de mutación (ver más abajo), pero la cobertura sintética + el hecho de que ningún guard de estructura falló silenciosamente en 22 fuentes reales es evidencia razonable. |
| R5 | CERRADO | `semantic_coverage` sin filas `inventory_only` en las fuentes cargadas. |
| R6 | No verificado explícitamente esta vez (no se probó con 2 archivos en una carpeta). |
| R7 | **Vuelve a manifestarse, por causa distinta** — ver historia completa abajo: cerrado por archivo faltante en v3, roto de nuevo en v8 por el bug de XPath (ahora cerrado), pero *hoy* sigue potencialmente afectado porque `exchange_houses` (que aporta nombres de casas de cambio a `dim_entity`) no carga. `banks`/`financial` sí tienen nombre de entidad vía `bank_reference`, que ahora carga bien. |
| R8 | CERRADO | `xlsx_sheet_dimensions()` resuelve las 22 fuentes sin error de relación XML. |
| R9 | CERRADO | `banks` y `financial` cargan; `assert_direct_structure()` pasa para ambas. |
| R10 | CERRADO | EVE: 2.760 obs., 2006-04-01 → 2026-08-01, exacto. |
| R11 | CERRADO | ICC: 1.236 obs., 2018-01-31 → 2026-07-31, 12 métricas, exacto. |
| R12 | No verificado esta vez (no se corrió con `LC_ALL=C`). |
| R13 | CERRADO | `dim_currency`: 6900→PYG/PYG, 6200→FX/PYG — exacto. |
| R14 | CERRADO | El smoke test usa `expect_gte`/`expect_gt` en todo lo que crece; no hay `expect_equal` sobre conteos de series. |
| R15 | CERRADO | `bank_reference` presente y — ahora — carga. |
| R16 | CERRADO | `resolve_reference_table()` sigue resolviendo por hoja + firma de columnas. |
| R17 | CERRADO | Guards de notación científica siguen presentes en `03_reference_semantics.R`. |
| R18 | No verificado explícitamente esta vez (requiere comparar corridas con contenido distinto). |
| R19 | CERRADO, confirmado en v7 y sigue así | `series_id` = hash de `stable_path\|frequency` (sin unit/currency); `identity_stability` expuesto; `validate_documented_series_continuity()` como error duro — **pero ver R26**, el guard que implementa la mitad "continuidad entre vintages" de este cierre está roto por un bug de SQL no relacionado con la lógica de identidad. |
| R20 | PARCIALMENTE CERRADO, sin cambios desde v7 | El mínimo viable (`hierarchy_status` por configuración en `sheet_modes.csv`, warning en vez de silencio) sigue anduvo. `hierarchy_level`/`parent_series_id` siguen constantes/`NA` en el parser genérico — la jerarquía real sigue sin modelarse, tal como se dejó documentado la vez pasada. Los nuevos parsers de eventos (`documented_parse_row_events`, usados por `interbank_market`/`lrm_auctions`/`liquidity_facility`) sí incorporan una identidad más rica, pero no llegan a modelar jerarquía padre-hijo tampoco. |
| R21 | CERRADO | El guard duro de `unit`/`scale` en `validate_documented_source()` sigue ahí; no se vio ningún `index`/`percent`/`ratio` con escala distinta de `units` en la base. |
| R22 | CERRADO | `documented_mode()` ya no tiene la excepción de `"CUADRO 57a"` hardcodeada; vive en `config/sheet_modes.csv`. |
| R23 | CERRADO | El smoke test deriva el conteo esperado del registro (`registry %>% filter(required)`), no un número fijo. |
| R24 | ABIERTO, alcance reducido | El mecanismo `long_csv` que se agregó en v6/v7 sigue funcionando bien (`corporate_bond_curves`, `securities_trades` cargan limpio) — pero el alcance original de R24 (FMI WEO/IFS/BOP) sigue sin ninguna fuente conectada. Sigue siendo "el próximo bloque de trabajo real", como decía el registro original. |
| R25 | ABIERTO, sin cambios | `config/concept_mappings.csv` sigue con sólo el encabezado, 0 filas. La maquinaria de validación (`apply_reviewed_concept_mappings()`) sigue sin ejercerse con contenido real. |

---

## Lo que quedó resuelto desde la última revisión (v8 → v9)

Cada uno de estos se verificó leyendo el código actual **y** reproduciendo el
escenario que antes fallaba contra el archivo real correspondiente — no se da nada
por cerrado sólo porque el CHANGELOG lo diga.

- **`bank_reference` carga completo.** `xlsx_named_table_catalog()`
  (`scripts/03_reference_semantics.R:31`) ahora usa `xml2::xml_root(table_doc)` en vez
  de una búsqueda `.//` que nunca podía encontrar el nodo raíz. Verificado: las 15
  tablas nombradas del libro real resuelven `table_range`/`source_table` sin ningún
  `NA`, y la fuente carga en la corrida completa (`Loaded: bank_reference / ... /
  bank_reference:cd800f82e64f8f2a0b65eea7`). Con esto, `banks`/`financial` vuelven a
  tener nombres de entidad — R7 vuelve a estar cerrado *para esas dos fuentes*.

- **Hoja vacía ya no rompe el layer crudo.** `cells_from_matrix()`
  (`scripts/02_extract_raw.R:531`) ahora devuelve una tibble tipada de 0 filas cuando
  no hay ninguna celda de texto, en vez de dejar que `bind_rows()` infiera un esquema
  vacío sin columna `row_id`. Verificado con la misma matriz sintética vacía que usé
  la sesión pasada — ya no falla.

- **El bug de `which(str_detect(matriz), arr.ind=TRUE)` está resuelto de raíz, no
  parchado.** Nuevo helper `matrix_predicate()`/`matrix_detect()`/`matrix_equal()`
  (`scripts/01_utils.R:35-53`) reconstruye las dimensiones después de aplicar el
  predicado, con guardas explícitas (`stop()` si la entrada no es 2D, si la longitud
  del resultado no coincide). Usado ahora en los tres sitios que antes tenían el bug
  inline. Verificado sobre archivo real: `compensatory_fx_sales` carga completo
  (1.422 filas).

- **`documented_month_number()` ya conoce "set".** `scripts/03_curate_documented.R:80`
  agrega `set = 9L` al mapa. `financial_indicators` carga completo (antes tronaba con
  `charToDate`).

- **`documented_quarter_number()` ya no acepta un dígito suelto como trimestre.**
  Regex reescrita (`scripts/03_curate_documented.R:100-102`) para exigir el prefijo
  `T` o el sufijo `trim`, con un comentario que explica el porqué. El test que rompía
  esto (`test-documented-source-helpers.R:27`) ya no aparece en la lista de fallas.

- **Las seis fuentes con "duplicate series-period keys" cargan.** `credit_survey`,
  `direct_investment`, `interbank_market`, `lrm_auctions`, `liquidity_facility` y
  también `economic_annex` ya no chocan contra ese guard específico (economic_annex
  ahora falla por una razón distinta — ver defecto nuevo abajo). El mecanismo nuevo
  (`documented_parse_row_events()`, `identity_stability = "positional_lane"` para
  duplicados legítimos del mismo día) es un diseño genuinamente bueno: separa la
  identidad de la serie del valor observado, en línea con el principio que
  `AUDITORIA_REGRESIONES.md` ya dejaba escrito para R19.

- **Una fuente corrupta ya no se lleva puesta toda la corrida.** La detección de
  dimensiones y el registro de metadata se movieron adentro del `tryCatch` por fuente
  (`scripts/06_pipeline.R:64-79`), con una bandera `transaction_open` que evita hacer
  `dbRollback()` sobre una transacción que nunca se abrió. El proyecto agregó además
  un test dedicado (`test-v9-ingestion-repairs.R:177`, "a discovery failure is
  persisted without losing the next source") que corrompe un zip a propósito — es
  exactamente la prueba de mutación que este informe hubiera pedido, y ya está
  escrita.

---

## Defectos

### Defecto A — `economic_annex` no carga: filas de anotación reciben fechas imposibles

**Severidad:** silencioso en su origen, bloqueante en su efecto — el guard de fecha
frena la fuente completa (94 hojas) en vez de descartar sólo las filas que corresponde.
**Archivo:línea:** el guard que lo atrapa es `assert_plausible_dates()` (vía
`documented_validate_contract()`); el origen está en la extracción de `Cuadro 49`
mediante `documented_extract_vertical_date()` (`scripts/03_curate_documented.R`).

**Qué pasa:** `Cuadro 49` (precios internacionales — soja, aceite de soja, carne,
petróleo — proyectados por año/mes) es exactamente la trampa que `CLAUDE.md` ya
advierte: *"hay cuadros que llegan a 2028; confirmar si son proyecciones"*. Los datos
reales y plausibles llegan hasta **2028-12-01** (fila 431: precios de soja ~420-433
USD/ton, petróleo ~70-71 USD/barril — cifras reales, no basura). Pero **filas 432 a
437** de esa misma hoja no son datos: son resúmenes de variación porcentual (`"Var. %
Interanual 2028/2027"`) y una nota al pie (`"*Ganado vivo"`). Esas filas sí tienen
valores numéricos reales en las columnas de datos (son las tasas de variación), pero
su columna de fecha no contiene una fecha real. El extractor les asigna igual un
período — hasta **2099-12-31**, 73 años después de la última fecha real de la hoja.

**Cómo se verificó:** reproducido en aislado; se interceptó
`documented_validate_contract()` antes de que lance el error y se imprimieron las
filas con fecha fuera de rango — 158 en total, todas en `Cuadro 49`, todas con
`series_label`/`value` de commodities reales pero `period` disparado. Se leyó además
la hoja cruda directamente (`documented_text_matrix`) y se confirmó que las filas
432-437 son texto de resumen, no datos mensuales.

**Arreglo propuesto:** las filas de resumen/nota al pie de una hoja `vertical_date`
necesitan excluirse explícitamente antes de asignarles período — por ejemplo,
detectar filas donde la etiqueta de fecha no matchea el patrón esperado (no es una
fecha real ni un año) y tratarlas como metadata/nota, igual que ya se hace en otras
hojas con etiquetas tipo `"* Nota..."`. Alternativa más económica: acotar
`candidate_rows` a las filas hasta la última fecha realmente parseada en la columna
ancla, en vez de dejar que seleccione filas posteriores por densidad numérica.

---

### Defecto B — `exchange_rates` no carga: un valor de cotización se confunde con un año

**Severidad:** silencioso en su origen (misma familia que el Defecto A), bloqueante en
su efecto.
**Archivo:línea:** `documented_year_values()` (`scripts/03_curate_documented.R:58-65`),
usada por `documented_parse_exchange_rate_history()` (`scripts/03_curate_expanded.R`).

**Qué pasa:** `documented_year_values()` acepta **cualquier entero entre 1900 y 2100**
como año candidato, sin ningún chequeo posicional o de contexto — es la misma
permisividad que causó el Defecto A. En la hoja mensual de cotizaciones, algún valor
de tipo de cambio (probablemente de una moneda cuyo valor en guaraníes cae en ese
rango, p.ej. pesos argentinos o chilenos por guaraní) termina leyéndose como si fuera
la cabecera de un bloque de año "2080", y el guard de esa hoja
(`"Exchange-rate monthly guard: year 2080 does not contain Compra and Venta"`) frena
la fuente entera al no encontrar las columnas Compra/Venta esperadas bajo ese año
inexistente.

**Cómo se verificó:** reproducido en aislado sobre el archivo real; mismo mensaje
exacto en la corrida completa y en la reproducción aislada, en ambas corridas
(primera y segunda, idempotente).

**Arreglo propuesto:** la detección de "fila de años" para estas tablas debería
exigir que la mayoría de valores candidatos en la fila formen una secuencia
ascendente razonable (años consecutivos), no aceptar cualquier entero suelto en rango
— el mismo principio que ya se aplicó para arreglar el Defecto de trimestres (exigir
contexto, no sólo rango numérico). Vale la pena revisar si el Defecto A y este
comparten la solución.

---

### Defecto C — `exchange_houses`: tercer bug distinto sobre la misma trampa de hojas vacías

**Severidad:** bloqueante · fuente requerida.
**Archivo:línea:** `read_source_sheet()`, dentro de `documented_source_parser()`
(`scripts/03_curate_documented.R`, la línea con
`raw[inventory_rows, inventory_cols, drop = FALSE]`).

**Qué pasa:** de las 4 hojas "vista con fórmulas, vacía al leer" que `CLAUDE.md` ya
documenta para esta fuente, 2 (`1.1 BG`, `1.2 EERR`) quedan con `ncol(raw) == 1`, que
coincide con lo que `xlsx_sheet_dimensions()` calculó (`content_last_col = 1`) — no
hay problema. Pero las otras 2 (**`2.1 Ratios`**, **`3.1 Dep y P.`**) quedan con
`ncol(raw) == 0`: `readxl` no devuelve ninguna columna para esas hojas, mientras que
`xlsx_sheet_dimensions()` sigue devolviendo `content_last_col = 1` (su valor por
defecto cuando no encuentra ninguna celda activa). Ese desacople hace que
`raw[inventory_rows, inventory_cols, drop = FALSE]` intente pedir la columna 1 de una
tabla que tiene 0 columnas, y `tibble` lo rechaza: *"Can't subset columns past the
end."*

**Cómo se verificó:** recorrida aislada de las 10 hojas del archivo real, comparando
`ncol(raw)` contra `content_last_col` una por una — sólo estas dos hojas están
desalineadas. Es la tercera causa distinta de falla para esta misma fuente en tres
revisiones seguidas de este proyecto (`row_id` faltante → resuelto; ahora esto).

**Arreglo propuesto:** dos capas de arreglo, no sólo una — porque esta trampa ya
demostró tres veces que sigue teniendo variantes: (1) puntual, hacer que
`xlsx_sheet_dimensions()` devuelva `content_last_col = 0L` (no `1L`) cuando no
encuentra ninguna celda activa, para que sea consistente con lo que `readxl`
realmente entrega; (2) de fondo, agregar un test que ejercite explícitamente las 4
hojas "vacías por fórmulas" de `exchange_houses` contra el archivo real — ya existe
uno para `liquidity_facility`/`daily_exchange_rates` con datos reales
(`test-expanded-parsers.R`), falta el equivalente para esta trampa específica.

---

### Defecto D — El guard de continuidad de series (R19) crashea por una palabra reservada de SQL

**Severidad:** bloqueante, pero sólo se manifiesta en la segunda ingesta de una fuente
en adelante (cuando ya existe un vintage previo contra el cual comparar) — por eso no
apareció en corridas anteriores de este informe centradas en la primera carga.
**Archivo:línea:** `validate_documented_series_continuity()`
(`scripts/04_validate.R`, la línea con
`any_value(series_label) label, any_value(unit) unit, ...`).

**Qué pasa:** la consulta arma un alias de columna implícito (`any_value(x) label`,
sin `AS`) para una columna llamada literalmente `label`. `LABEL` es palabra reservada
en la gramática SQL de DuckDB — no se puede usar como alias implícito sin `AS`.
Confirmado de forma aislada, sin nada del proyecto:

```r
DBI::dbGetQuery(con, "SELECT a, any_value(b) label FROM t GROUP BY a")
# Parser Error: syntax error at or near "label"
DBI::dbGetQuery(con, "SELECT a, any_value(b) AS label FROM t GROUP BY a")
# OK
```

**Por qué importa tanto:** este guard es la mitad operativa del cierre de R19 — el
chequeo de continuidad "con error duro" que el registro de auditoría pedía como parte
del arreglo. Hoy, en cuanto una fuente tenga un vintage previo (es decir, en la
segunda corrida contra un archivo *distinto* del mismo origen — no se dispara en las
corridas idénticas de este informe porque esas reusan el vintage sin re-validar
continuidad), el guard no va a decir "identidad rota" o "todo bien": va a tronar con
un error de sintaxis SQL que no tiene nada que ver con el problema que se supone debe
vigilar. Esto no se había reportado formalmente antes (sólo se mencionó en
conversación en la revisión anterior); queda como hallazgo nuevo en este informe.

**Arreglo propuesto:** agregar `AS` antes del alias, en las tres columnas afectadas:

```r
fields <- "series_id, any_value(source_sheet) AS source_sheet, any_value(series_label) AS label, ..."
```

---

### Defecto E — `liquidity_facility`: la identidad de evento no distingue depósito de repo

**Severidad:** silencioso — el guard de duplicados ya no lo atrapa porque el nuevo
mecanismo de "positional lane" (ver más abajo) absorbe cualquier colisión sin quejarse,
incluida esta.
**Archivo:línea:** llamada a `documented_parse_row_events()` para `liquidity_facility`
(`scripts/03_curate_documented.R:1315-1320`).

**Qué pasa:** `documented_parse_row_events(..., dimension_headers = c("^plazos"),
...)` sólo captura la columna "Plazos" (tenor) como dimensión de identidad. El test
nuevo del propio proyecto (`test-expanded-parsers.R:22-36`, "liquidity parser keeps
deposit and repo blocks distinct") espera que la etiqueta de cada observación
distinga operaciones de depósito de operaciones de repo — y falla: ninguna etiqueta
contiene "repo" ni "deposito". Se confirmó además que el archivo real sí contiene
ambas palabras en la hoja. Como el resultado de esta fuente ya no dispara el guard de
claves duplicadas (que sería la señal de alarma si dos operaciones distintas
colisionaran), es plausible que operaciones de depósito y de repo del mismo día y
mismo plazo se estén fusionando bajo la misma `series_id` sin que nada lo marque —
justo el tipo de fusión silenciosa que el mecanismo de "positional lane" fue diseñado
para prevenir, pero que necesita que la dimensión de identidad esté completa para
funcionar.

**Cómo se verificó:** corrida de la batería completa de tests contra el archivo real;
es una falla real del proyecto, no un artefacto de este informe. Confirmado además
que el mismo patrón de llamada (`c("^plazos")`) se usa en producción
(`documented_source_parser`) y en el test — no es que el test pida algo que el código
de producción no intenta hacer.

**Arreglo propuesto:** agregar a `dimension_headers` el patrón de la columna que
distingue tipo de operación (repo vs. depósito) — hay que mirar el encabezado real de
la hoja para saber si es una columna (`c("^plazos", "^tipo")`, por ejemplo) o una
sección por bloque de filas, en cuyo caso `documented_parse_row_events()` necesitaría
el mismo mecanismo de "carry-forward de categoría" que ya usan
`documented_extract_vertical_block()`/`documented_parse_credit_sheet()` para filas de
sección sin valores numéricos.

---

### Defecto F (menor) — Bancos EEFF: una fila de diferencia contra la verdad conocida

**Severidad:** menor — no se pudo confirmar si es una regresión o una diferencia
legítima de vintage.
**Evidencia:** `raw_banks_eeff` tiene 246.546 filas en esta corrida; `CLAUDE.md`
documenta 246.547 para la publicación de julio/agosto de 2026. Es el mismo archivo
(`1.1 Tablas Boletín Bancos Jul26 1.xlsx`) según el nombre, así que en principio
debería coincidir exacto. No alcancé a determinar si la diferencia es una fila de
encabezado/total contada distinto, un cambio real del archivo entre cuando CLAUDE.md
se escribió y ahora, u otra cosa — lo dejo señalado para la próxima revisión en vez
de adivinar.

---

## Intento de mutación de guard

Se copió el archivo real de `banks` a un directorio temporal y se intentó corromper
un encabezado de la hoja EEFF con `openxlsx::loadWorkbook()` /
`saveWorkbook()` para forzar el guard de estructura. El re-guardado de `openxlsx`
sobre un archivo real de 18 MB corrompió la codificación de caracteres del XML interno
(`xmlParseEntityRef: no name`) antes de llegar siquiera a la detección de dimensiones
— una limitación de la herramienta de mutación usada, no del pipeline. No se reintentó
con una técnica de edición de XML más quirúrgica por límite de tiempo de esta sesión.
Como evidencia alternativa: el test dedicado del proyecto que rompe a propósito una
lista de columnas esperada (`test-structure-guards.R:10-15`) pasa limpio, y dos guards
reales (fecha plausible, Compra/Venta de `exchange_rates`) se dispararon
*orgánicamente* contra datos reales en esta misma corrida — lo cual demuestra que
pueden fallar, con datos reales, no sintéticos.

---

## Lo que agregaría

Por orden de valor:

1. **Un test de regresión dedicado a la trampa de "hojas vacías por fórmulas" de
   `exchange_houses`**, con las 4 hojas reales, no sólo con matrices sintéticas — ya
   lleva tres bugs distintos originados ahí en tres revisiones.
2. **Acotar `documented_year_values()`/`documented_quarter_number()` con contexto
   posicional**, no sólo rango numérico — el mismo principio que ya se aplicó para
   arreglar el defecto de trimestre debería extenderse a años, dado que el Defecto A
   y el B son la misma familia de error con la misma causa raíz permisiva.
3. **Revisar `dimension_headers` de los tres usos de `documented_parse_row_events()`**
   (`liquidity_facility`, `interbank_market`, `lrm_auctions`) uno por uno contra el
   archivo real, no sólo el de `liquidity_facility` que ya tiene test fallando —
   `interbank_market`/`lrm_auctions` podrían tener el mismo problema sin que ningún
   test lo esté marcando todavía.
4. Agregar `AS` en el defecto D — es una corrección de una línea con alto impacto
   (desbloquea el chequeo real de continuidad de R19 en cuanto haya un segundo
   vintage real).

---

## En resumen

Esta fue una corrección genuinamente sólida: siete defectos reales de la revisión
anterior se cerraron con arreglos correctos, no parches — el manejo de matrices con
`matrix_predicate()`, el mecanismo de `positional_lane` para duplicados legítimos, y
el aislamiento por fuente moviendo la detección de dimensiones adentro del
`tryCatch` son, en particular, del tipo de arreglo que corrige la causa y no el
síntoma. El paso de 11 a 3 fuentes fallando en una semana de trabajo es un ritmo
bueno. Lo que sigue pendiente no es trivial (`economic_annex` es la fuente más grande
del proyecto) pero está bien localizado y con causa raíz identificada en este mismo
informe, no es un misterio para la próxima ronda.
