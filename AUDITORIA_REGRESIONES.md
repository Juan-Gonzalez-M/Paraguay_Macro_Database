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

## Abiertos al cierre de la v11 (parche aplicado en la sesión de fix)

### R41 — Alias sin `AS` en una consulta del propio smoke test · menor
**Dónde:** `tests/testthat/test-full-pipeline-smoke.R:78` —
`SELECT COUNT(*) rows FROM documented_series_snapshot GROUP BY 1,2 HAVING COUNT(*) >
1`. `rows` es palabra reservada en DuckDB sin `AS`, misma familia que R26 pero en el
test, no en producción. Esa aserción específica del smoke test no puede ejecutarse
tal como está escrita.
**Arreglo:** `COUNT(*) AS rows`.

---

### R42 — El guard de fecha global no reconoce el horizonte de proyección ya revisado para `economic_annex` · menor
**Dónde:** chequeo `implausible_semantic_date_range` en `validate_database()`
(`scripts/04_validate.R`), sobre `fact_series_events` agregado de todas las fuentes.
Con `CUADRO 57a` resuelto (ver abajo), la corrida completa deja **una sola** quality
flag de severidad `error`: *"Semantic observations span 1945-12-31 to
2028-12-01"*. El contrato específico de `economic_annex`
(`documented_validate_contract`) ya fue ampliado esta ronda para aceptar el horizonte
de proyección revisado de `Cuadro 49` (hasta 2028-12-01) — pero el guard **global**
de `validate_database()` sigue con un techo más angosto (`Sys.Date() + 400`, ~fines
de 2027), así que la misma fecha que el contrato de la fuente ya acepta como
legítima sigue marcándose como error a nivel base completa. No es un defecto de
`CUADRO 57a` ni algo que el arreglo de esa hoja debía tocar — es una inconsistencia
menor entre dos guards que deberían compartir el mismo techo revisado.
**Cómo verificar que sigue cerrado:** `outputs/quality_flags_latest.csv` sin filas
`severity=error, check_name=implausible_semantic_date_range` para fechas dentro del
horizonte ya revisado de `economic_annex`.
**Arreglo:** alinear el techo de `validate_database()` con el mismo horizonte
revisado que ya usa el contrato de `economic_annex`, en vez de dos constantes
independientes.

---

### R43 — Incompatibilidad de API de `testthat`: `info=` ya no es un argumento válido en varios `expect_*` · menor, sólo test suite
**Dónde:** 7 usos de `info = ...` en `tests/testthat/test-v10-runtime-repairs.R` y
`tests/testthat/test-v9-ingestion-repairs.R` (`expect_no_error()`, `expect_gt()`).
Con `testthat` 3.3.2 instalado, ambas llamadas tiran
`` `...` must be empty `` / `unused argument (info = ...)`. No es un defecto del
pipeline — es una prueba escrita contra una versión de `testthat` distinta a la
instalada.
**Arreglo:** quitar `info=` de esas 7 llamadas, o envolver el mensaje en el propio
`expect_*` según lo que soporte la versión fijada del paquete.

---

### R44 — `create_market_views()` falla con "window expression is not supported" en dos fixtures sintéticos de test · menor, no reproducido con datos reales
**Dónde:** `scripts/03_curate_expanded.R:528-547`, invocada sin condición desde
`initialize_database()`. Dispara en `test-identity-and-archive.R:101` ("schema-v3
currency and report storage migrate safely to v4") y `:120` ("schema-v4 documented
sources are invalidated before v5 reingestion") — ambos tests arman una base
sintética mínima antes de llamar `initialize_database()`. La misma consulta
exacta, reproducida aislada contra tablas `source_files`/`bond_curve_snapshot`
con un esquema realista, corre sin error — y la corrida real completa contra los 22
archivos tampoco la dispara. Parece específico a alguna combinación de columnas o
tipos del fixture sintético de esos dos tests, no una falla general de la vista.
**Arreglo:** no determinado — revisar qué columna/tipo del fixture sintético de
esos dos tests difiere de una base real hasta encontrar la combinación que dispara
el error de DuckDB.

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

### R25 — La maquinaria de conceptos nunca se ejerció con contenido · menor
Sin cambios desde v9. `config/concept_mappings.csv` sigue con sólo el encabezado.

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
