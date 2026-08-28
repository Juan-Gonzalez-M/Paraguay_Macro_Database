# Revisión — auditoría técnica externa (`Technical_Audit.docx`, 2026-08-27)

Qué es este documento: qué afirmó la auditoría externa, qué de eso se verificó
contra la base real, qué se arregló, y qué se dejó explícitamente sin hacer.
El detalle por defecto está en `AUDITORIA_REGRESIONES.md` (R46-R52).

---

## 1. Verificación previa: ¿es válida la auditoría?

Sí. Antes de tocar una línea de código se reejecutaron sus comprobaciones contra
`database/paraguay_macro_pilot.duckdb` en modo sólo lectura. **Todas las cifras
verificables resultaron exactas**, incluidas las difíciles:

| Afirmación de la auditoría | Verificación |
|---|---|
| 28.417 `dim_series` / 1.216.910 `fact_series_events` / 1.090.668 `documented_series_snapshot` | exacta |
| 12.630 series `positional_lane` (44,45%); 15.756 de una observación (55,45%); 18.597 con menos de 12 (65,44%) | exacta |
| FX compensatorias: 474 filas → 139 meses por medida; 114 / 109 / 92 meses en conflicto | exacta |
| `bcp_fx_daily`: 12 etiquetas × 14 hojas anuales = 168 IDs, 3.394 observaciones en fechas disjuntas cada una | exacta |
| `eve`: 2.760 IDs de una observación para 16 indicadores reales | exacta |
| `CUADRO 61`: 170 IDs, 25.912 filas, 6 etiquetas distintas formadas por números concatenados | exacta |
| Encuesta de crédito: 2.500 `positional_lane` + 34 `positional`, todas de una observación | exacta |
| 521 grupos con firma numérica idéntica (≥12 obs); 0 claves de hecho duplicadas; 0 restricciones de clave foránea | exacta |
| 565 observaciones con período futuro (535 Anexo + 30 `fx_operations`); rutas absolutas `/Users/...` | exacta |
| `fx_operations` = 10 conceptos × 3 frecuencias, mantener 30 | exacta |

Dos diferencias inmateriales, ninguna cambia una conclusión: el informe dice
28.417 mapeos de concepto (real 28.420 = 28.417 `source_specific_unreviewed` + 3
revisados), y 1.441 grupos de etiqueta/dimensión repetida (con nuestra definición
contamos 2.521; el informe no publica la suya).

Tres de los defectos ya estaban en el registro propio del proyecto con causa raíz
encontrada y arreglo **no aplicado**: **R46** (`eve`), **R47** (`bcp_fx_daily`) y
**R45** (hojas de comercio del Anexo). La auditoría externa los redescubrió de
forma independiente. `compensatory_fx_sales`, `credit_survey` y `CUADRO 61` son
hallazgos genuinamente nuevos.

## 2. Alcance acordado

Sólo los **defectos P0 de parser/identidad** que la auditoría nombra, incluidos
los tres que exigían mecanismos nuevos, más la compuerta de allowlist de la
sección 12. Nada de P1/P2/P3 ni de la arquitectura objetivo de la sección 9.

## 3. Qué se arregló

| Registro | Defecto | Antes → Después |
|---|---|---|
| R48 | Bloques anuales sin cortar en FX compensatorias | 36 series / 474 filas / 114-109-92 meses en conflicto → **3 series / 417 filas / 0 conflictos** |
| R46 | `slug()` sobre la columna materializada en `eve_parser()` | 2.760 series → **16** |
| R49 | Slot estructural en el eje equivocado en la encuesta de crédito | 2.534 series de una observación → **5** (residuo distinto, R52) |
| R47 | 14 hojas anuales de `bcp_fx_daily` sin unir | 168 series → **12** |
| R50 | `CUADRO 61` nombrando series desde filas de datos | 170 identidades `positional_lane` → **182 identidades 100% `semantic`** |
| R51 | Slug de hoja unificado por posición dentro de `series_id` | sufijos `_2 … _26` dependientes del orden → **slug estable, 0 discrepancias en 21.667 series** |

Resultado global: `dim_series` **28.417 → 23.012**; series de una observación
**15.756 → 10.462**; `positional_lane` **12.630 → 9.924**; flags de severidad
`error`: **0**.

**Las observaciones se conservan.** Comparando fuente por fuente contra la copia
previa a la migración, el total de observaciones es idéntico en las 18 fuentes
salvo los dos cambios buscados: `compensatory_fx_sales` −1.005 (filas duplicadas
del defecto de parseo) y `economic_annex` +394 (celdas de `CUADRO 61` que el
extractor genérico no leía). Ninguna reparación de identidad perdió ni duplicó un
solo dato.

### Balance fuente-a-destino (sección 11 de la auditoría)

- **`CUADRO 61`**: las 26.306 celdas numéricas de las columnas 2-11 producen
  exactamente 26.306 observaciones; **cero sin explicar**. Las 301 celdas de la
  columna 1 son el eje de años y las 45 de las columnas 225-236 son un bloque
  duplicado suelto de la hoja, ambos excluidos deliberadamente.
- **FX compensatorias**: 422 celdas numéricas, 417 aceptadas. Las 5 restantes
  (filas 114-118, columna 9) son ceros de relleno en la columna de total para
  ago-dic 2026, meses aún no publicados; incorporarlas inventaría observaciones
  futuras con valor cero. **Exclusión documentada, no pérdida.**

### Reconciliación aritmética

- FX compensatorias: `Total = Compensatorias + Complementarias` en los **139**
  meses.
- `CUADRO 61`: los cinco tipos de operación suman el total del período en
  **1.822 de 1.822** grupos, y las tres instituciones suman el `Total` en **350
  de 350**, dentro del 0,01%.

## 4. Compuerta de disponibilidad para investigación

`config/table_status.csv` declara un estado revisado por tabla fuente, con cuatro
valores deliberadamente estrechos:

- `validated` — un economista revisó definiciones, unidades, convenciones de
  período y jerarquía. **Sólo estas llegan a `v_research_series`.** Ninguna
  comprobación automática puede otorgar este estado.
- `provisional` — parsea limpio y pasa las compuertas automáticas, sin revisión
  económica. Es el estado por defecto.
- `needs_remodeling` — los valores se creen correctos pero las identidades no son
  usables para investigación.
- `quarantined` — defecto probado; fuera de toda vista orientada a investigación.

Sembrado honesto, no halagador: **0 tablas `validated`**, 21 fuentes
`provisional`, y `needs_remodeling` para las 8 hojas de comercio detallado del
Anexo (R45) y `financial_indicators` (sección 5.3 de la auditoría). Eso deja hoy
`v_research_series` **vacía a propósito** — 12.382 series `provisional` y 10.786
`needs_remodeling` están visibles con su estado en `v_series_table_status`, pero
ninguna se publica como lista para investigación. Asignar los estados reales es
trabajo de revisión económica, no de código.

`validate_database()` emite un error bloqueante `table_status_incomplete` si
aparece una fuente u hoja en la base sin fila en el archivo: la superficie de
investigación no puede crecer en silencio.

## 5. Qué NO se hizo, y por qué

- **R45 — las 8 hojas de comercio del Anexo** (`Cuadro 46a/b, 51a/b, 52a/b,
  53a/b`): ~7.812 series espurias, el mayor foco restante. La causa raíz ya está
  documentada, pero la auditoría ubica el trabajo de comercio detallado en **P1**
  ("needs remodeling", secciones 8.1 y 12), no en P0, y el arreglo toca el
  detector de eje de columnas compartido por las 93 hojas. **Siguiente paso
  recomendado.**
- **R52** — 5 series residuales de la encuesta de crédito (encabezado de pregunta
  con un cero suelto). Dos órdenes de magnitud menor que lo que la auditoría
  midió; anclado con una aserción exacta en el smoke test.
- **Sección 9 completa** (capas `raw`/`staging`/`canonical`/`marts`/`audit`,
  modelo canónico concepto ↔ serie ↔ alias, vistas as-of, marts revisados).
- **Sección 6** (ajuste estacional, stock/flujo, nominal/real, transformación,
  multiplicadores de escala): el esquema es fácil; los **valores** exigen revisión
  económica de más de 20.000 series. Columnas llenas de `unknown` serían peores
  que su ausencia.
- **Sección 4** (clave primaria en `fact_series_events`, claves foráneas, rutas
  relativas al repositorio, `period_start`/`period_end`) y todo P1/P2/P3.
- **Alias de versión de cuestionario en la encuesta de crédito** (sección 10):
  R49 repara el defecto de identidad; modelar cambios de redacción entre
  versiones exige los cuestionarios originales, que la propia auditoría marca
  como VERIFY.

## 6. Migración y verificación

`schema_version` 12, `invalidate_v12_p0_identity_repairs()`. Reingesta dirigida
de las 14 fuentes `semantic_table` más `eve` (el arreglo R51 cambia todo
`series_id` documentado). Las fuentes no afectadas —`banks`, `financial`,
`bank_reference`, `icc`, `fx_operations`, `corporate_bond_curves`,
`securities_trades`— reutilizan su vintage sin volver a parsear.

Regresión: `tests/testthat/test-audit-p0-repairs.R` (nuevo) más aserciones de
cardinalidad en `test-full-pipeline-smoke.R` contra la tabla de la sección 10 de
la auditoría. `run_tests.R` completo en verde.
