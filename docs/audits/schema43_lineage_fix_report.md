# Schema 43 worksheet-lineage correction report

Date: 2026-09-13  
Scope: the sole substantive data-interface condition F01 from the independent schema-43
release-acceptance review. This report does not perform or authorize the final release workflow.

## Result

The worksheet-lineage condition is fully satisfied in the isolated schema-43 candidate. Exactly
39,543 observations across the 27 independently identified exploratory candidates now expose the
worksheet and table title from the matching source observation. Candidate identities, observation
values, published periods, normalized bounds, dimensions, economic metadata, validation tiers, and
the strict `research.*` population are unchanged.

The final isolated candidate is:

- path: `/private/tmp/schema43-lineage-final.JPitWw/paraguay_macro_schema43_candidate.duckdb`
- schema version: 43
- SHA-256: `586f2e7af80d54316d45233f1532d03d6f6846d279316d194fa5dbc1d1c26dd8`
- release-validation errors under `release:schema43-lineage-fix-final`: 0

The production database was never a write target. Its SHA-256 was
`17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180`
before and after this work.

## Root cause and exact mechanism

The source parsers were correct. `documented_extract_vertical_date()` emitted the BCP FX rows and
`documented_extract_horizontal_time()` emitted financial-indicator sheet 8 through the generic
documented-sheet dispatcher. `documented_finalize_observations()` retained exact
`source_sheet`, `source_row`, and `source_column`; for BCP FX it separately used the governed
`OpDivisas(DatosDiarios)` continuation group as the identity sheet. The parser outputs in
`staging.documented_series_snapshot` locate every affected value correctly.

The defect was introduced when schema 43 assembled `explore.*` in
`create_catalog_explore_views()`:

1. The `titles` CTE reduced `main.v_series_titles` to one row per series. That table is designed to
   provide a series-level title, not an observation locator.
2. The `observation_select` then selected `source_sheet` and `table_title` from that one-row profile
   while selecting `source_row`, `source_column`, and `source_period_label` from the matching
   observation in `staging.documented_series_snapshot`.
3. The resulting locator combined fields from different records.

This produced two source-specific manifestations:

- The 12 `bcp_fx_daily` identities intentionally span 14 annual worksheets. The canonical title
  record retained one annual sheet (`OpDivisas2016(DatosDiarios)` or
  `OpDivisas2021(DatosDiarios)`) and its year-specific title. That sheet happened to match 253
  observations per candidate and mislocated the other 3,150 per candidate: 37,800 rows total.
- Financial-indicator worksheet `8` publishes no table title. `apply_series_titles()` correctly
  excludes null/blank titles, so no series-level title record existed for its 15 candidates. The
  schema-43 profile nevertheless reported complete coordinates, and retrieval combined null
  worksheet/title fields with the correct row and column: 1,743 rows total.

This was an incorrect interface join/field selection. It was not a wrong parser sheet reference, a
source-file defect, a value defect, a candidate-identity defect, or permission to reinterpret any
economic field.

## Immutable source evidence

| Source | Current source file | Vintage | SHA-256 | Archived evidence |
|---|---|---|---|---|
| `bcp_fx_daily` | `input/current/bcp_fx_daily/Compra_Venta de Divisas del BCP_2026 (1).xlsx` | `bcp_fx_daily:a45bea1e1508bb019befcac9` | `a45bea1e1508bb019befcac9c545dfb03e0e537649a4d7a20d2a8bea59652091` | `input_archive/bcp_fx_daily/a45bea1e1508bb019befcac9c545dfb03e0e537649a4d7a20d2a8bea59652091.xlsx` |
| `financial_indicators` | `input/current/financial_indicators/Ind. Financieros web-Junio 2026.xlsx` | `financial_indicators:f9ded3c4fe24e11b14caa1df` | `f9ded3c4fe24e11b14caa1df69f4390a3e3367ed076e6c35b1328cbe0c3eaff3` | `input_archive/financial_indicators/f9ded3c4fe24e11b14caa1df69f4390a3e3367ed076e6c35b1328cbe0c3eaff3.xlsx` |

The current and archived copies independently hash to the recorded SHA-256 values. No source or
archive byte was changed.

The BCP FX workbook contains these 14 source worksheets. Counts are current observations across the
12 affected candidates; all 12 candidates occur on every sheet.

| Source worksheet | Observations |
|---|---:|
| `OpDivisas2013(DatosDiarios)` | 3,000 |
| `OpDivisas2014(DatosDiarios)` | 2,988 |
| `OpDivisas2015(DatosDiarios)` | 2,988 |
| `OpDivisas2016(DatosDiarios)` | 3,036 |
| `OpDivisas2017(DatosDiarios)` | 2,988 |
| `OpDivisas2018(DatosDiarios)` | 3,000 |
| `OpDivisas2019(DatosDiarios)` | 3,000 |
| `OpDivisas2020(DatosDiarios)` | 3,000 |
| `OpDivisas2021(DatosDiarios)` | 3,036 |
| `OpDivisas2022(DatosDiarios)` | 3,012 |
| `OpDivisas2023(DatosDiarios)` | 2,988 |
| `OpDivisas2024(DatosDiarios)` | 3,000 |
| `OpDivisas2025(DatosDiarios)` | 2,964 |
| `OpDivisas2026(DatosDiarios)` | 1,836 |
| **Total** | **40,836** |

The affected financial-indicator observations all come from the workbook's exact worksheet name
`8`; the workbook also contains `Índice`, `1.1`, `1.2`, `2.1`, `2.2`, `3.1`, `3.2`, `4`, `5`, `6`,
and `7`.

All 39,543 affected staging locators join to `main.v_report_cells_a1` with zero missing raw cells
and zero numeric differences at tolerance `1e-8 * greatest(1, abs(value))`. The two source families'
25 worksheet reconciliation rows are balanced, with total balance delta 0, unclassified cells 0,
and parser-defect cells 0.

## Exact affected candidates

`Current observations` is the candidate's complete current population. `Corrected observations` is
the subset whose previously exposed series-title worksheet differed from the matching observation.

| Source | Candidate | Source label | Current observations | Corrected observations | Worksheets | Identity sheet | Prior title-record sheet | Corrected profile status |
|---|---|---|---:|---:|---:|---|---|---|
| `bcp_fx_daily` | `bcp_fx_daily:op_divisas_datos_diarios:0957433db1b1c1cef39b7c41` | Sector Público — Acumulado en el Año | 3,403 | 3,150 | 14 | `OpDivisas(DatosDiarios)` | `OpDivisas2016(DatosDiarios)` | `complete_multiple_worksheets` |
| `bcp_fx_daily` | `bcp_fx_daily:op_divisas_datos_diarios:10aa9337ca44858e6554071b` | Compra del BCP — Total | 3,403 | 3,150 | 14 | `OpDivisas(DatosDiarios)` | `OpDivisas2021(DatosDiarios)` | `complete_multiple_worksheets` |
| `bcp_fx_daily` | `bcp_fx_daily:op_divisas_datos_diarios:1167218c0c4db02d98be2ed4` | Sector Público + Sector Financiero — Acumulado en el Año | 3,403 | 3,150 | 14 | `OpDivisas(DatosDiarios)` | `OpDivisas2016(DatosDiarios)` | `complete_multiple_worksheets` |
| `bcp_fx_daily` | `bcp_fx_daily:op_divisas_datos_diarios:17b3daf11066d8eac5808be7` | Compra del BCP — Sector Financiero | 3,403 | 3,150 | 14 | `OpDivisas(DatosDiarios)` | `OpDivisas2016(DatosDiarios)` | `complete_multiple_worksheets` |
| `bcp_fx_daily` | `bcp_fx_daily:op_divisas_datos_diarios:299c6815e8c66c366cbda661` | Compra del BCP — Sector Público | 3,403 | 3,150 | 14 | `OpDivisas(DatosDiarios)` | `OpDivisas2016(DatosDiarios)` | `complete_multiple_worksheets` |
| `bcp_fx_daily` | `bcp_fx_daily:op_divisas_datos_diarios:2e11e6bedf4350e619bbfcb6` | Venta del BCP — Total | 3,403 | 3,150 | 14 | `OpDivisas(DatosDiarios)` | `OpDivisas2021(DatosDiarios)` | `complete_multiple_worksheets` |
| `bcp_fx_daily` | `bcp_fx_daily:op_divisas_datos_diarios:3c951804d5e93c97589a95e2` | Sector Público — Compras Netas | 3,403 | 3,150 | 14 | `OpDivisas(DatosDiarios)` | `OpDivisas2021(DatosDiarios)` | `complete_multiple_worksheets` |
| `bcp_fx_daily` | `bcp_fx_daily:op_divisas_datos_diarios:542ac0ab6cb137a1139018b2` | Sector Público + Sector Financiero — Compras Netas | 3,403 | 3,150 | 14 | `OpDivisas(DatosDiarios)` | `OpDivisas2021(DatosDiarios)` | `complete_multiple_worksheets` |
| `bcp_fx_daily` | `bcp_fx_daily:op_divisas_datos_diarios:5aa4e7262dee69adde87a3ae` | Sector Financiero — Compras Netas | 3,403 | 3,150 | 14 | `OpDivisas(DatosDiarios)` | `OpDivisas2016(DatosDiarios)` | `complete_multiple_worksheets` |
| `bcp_fx_daily` | `bcp_fx_daily:op_divisas_datos_diarios:b074d786fee864b2efd438e0` | Venta del BCP — Sector Financiero | 3,403 | 3,150 | 14 | `OpDivisas(DatosDiarios)` | `OpDivisas2021(DatosDiarios)` | `complete_multiple_worksheets` |
| `bcp_fx_daily` | `bcp_fx_daily:op_divisas_datos_diarios:b26a6ad2b9ed04e5fb4eedea` | Sector Financiero — Acumulado en el Año | 3,403 | 3,150 | 14 | `OpDivisas(DatosDiarios)` | `OpDivisas2021(DatosDiarios)` | `complete_multiple_worksheets` |
| `bcp_fx_daily` | `bcp_fx_daily:op_divisas_datos_diarios:fc1b68ba4459ed6c42b6f1d6` | Venta del BCP — Sector Público | 3,403 | 3,150 | 14 | `OpDivisas(DatosDiarios)` | `OpDivisas2016(DatosDiarios)` | `complete_multiple_worksheets` |
| `financial_indicators` | `financial_indicators:x8:0566de5b3bc74a078d40e847` | ESTER 3/ | 75 | 75 | 1 | `8` | NULL | `complete_single_worksheet` |
| `financial_indicators` | `financial_indicators:x8:0f923121c2226d98a43c3f04` | LIBOR A 6 MESES USD 4/ | 107 | 107 | 1 | `8` | NULL | `complete_single_worksheet` |
| `financial_indicators` | `financial_indicators:x8:1cd6fc48efef7ba37aa53d03` | SOFR 2/180 días | 76 | 76 | 1 | `8` | NULL | `complete_single_worksheet` |
| `financial_indicators` | `financial_indicators:x8:34f5511046704209dd8c44d5` | SOFR 2/ | 99 | 99 | 1 | `8` | NULL | `complete_single_worksheet` |
| `financial_indicators` | `financial_indicators:x8:6251c27469b8d2b105a77c05` | Banco de la Republica de Colombia | 126 | 126 | 1 | `8` | NULL | `complete_single_worksheet` |
| `financial_indicators` | `financial_indicators:x8:6525e9b20e3a11458bb7714f` | Rango Inferior | 126 | 126 | 1 | `8` | NULL | `complete_single_worksheet` |
| `financial_indicators` | `financial_indicators:x8:66dac7933b59a1b55c19f938` | Tasa Selic | 126 | 126 | 1 | `8` | NULL | `complete_single_worksheet` |
| `financial_indicators` | `financial_indicators:x8:7e62e7df7a84499a568bb9c5` | BANCOS CENTRALES | 126 | 126 | 1 | `8` | NULL | `complete_single_worksheet` |
| `financial_indicators` | `financial_indicators:x8:a8e0c095c2ec81d2f46f90ca` | Banco Central de Chile | 126 | 126 | 1 | `8` | NULL | `complete_single_worksheet` |
| `financial_indicators` | `financial_indicators:x8:bf7ada9ae565830aeb0be353` | PRIME 1/ | 126 | 126 | 1 | `8` | NULL | `complete_single_worksheet` |
| `financial_indicators` | `financial_indicators:x8:c0f4dff6144df6447a4187fc` | Facilidad de depósitos | 126 | 126 | 1 | `8` | NULL | `complete_single_worksheet` |
| `financial_indicators` | `financial_indicators:x8:c6e9b9ddaec363c3e89b538d` | Rango Superior | 126 | 126 | 1 | `8` | NULL | `complete_single_worksheet` |
| `financial_indicators` | `financial_indicators:x8:c909e6273a7f691d34edfe9f` | Operaciones de refinanciación | 126 | 126 | 1 | `8` | NULL | `complete_single_worksheet` |
| `financial_indicators` | `financial_indicators:x8:eb41a637066fb4132ff6948d` | Banco de la Reserva de Perú | 126 | 126 | 1 | `8` | NULL | `complete_single_worksheet` |
| `financial_indicators` | `financial_indicators:x8:ec6a43113beb692e7b4dd5e1` | Facilidad marginal de créditos | 126 | 126 | 1 | `8` | NULL | `complete_single_worksheet` |
| **Total** | **27 candidates** |  | **42,579** | **39,543** |  |  |  |  |

## Before and after evidence

For candidate
`bcp_fx_daily:op_divisas_datos_diarios:0957433db1b1c1cef39b7c41`, period
`2013-01-07`, the value is `0.0823914066046846` at A1 row 17, column 14.

| State | Worksheet | Table title | Cell value |
|---|---|---|---:|
| Before | `OpDivisas2016(DatosDiarios)` | `Monto de Operaciones de Divisas del Banco Central del Paraguay (millones de USD) - Año 2016` | 0 at row 17, column 14 |
| Correct staging/raw evidence | `OpDivisas2013(DatosDiarios)` | `Monto de Operaciones de Divisas del Banco Central del Paraguay (millones de USD) - Año 2013` | 0.0823914066046846 at row 17, column 14 |
| After | `OpDivisas2013(DatosDiarios)` | `Monto de Operaciones de Divisas del Banco Central del Paraguay (millones de USD) - Año 2013` | 0.0823914066046846 at row 17, column 14 |

For `financial_indicators:x8:bf7ada9ae565830aeb0be353`, period `2016-01-01`,
the value is 3.5 at row 3, column 2. Before, retrieval exposed a null worksheet. After, it exposes
worksheet `8`; the raw A1 cell is 3.5. The table title remains null because that is the publisher
evidence, not missing lineage to be invented.

## Implementation

The correction is confined to the schema-43 interface and validation layer:

- `scripts/13_explore.R` now takes observation `source_sheet`, `table_title`, row, column, parser
  method, and source-period label from the same staging natural-key row. It retains
  `identity_basis`/`identity_source_sheet` and the old `title_record_*` fields separately.
- Profiles publish `source_sheet` only for a complete one-worksheet locator and otherwise use
  `source_sheets`, `source_sheet_count`, `table_titles`, `table_title_count`, and an explicit
  `worksheet_lineage_status`. Both profile and observation rows carry a correction reason.
- Invalid source locators set `quarantined_or_invalid`. The staging unique index rejects ambiguous
  `(vintage_id, series_id, period)` lineage; the profile also detects match excess and quarantines
  the candidate if that constraint is damaged.
- `scripts/12_platform.R` adds a release-blocking lineage check for corrected observations against
  their staging record and raw A1 cell, and splits the existing scalar integrity aggregate into
  equivalent lower-memory checks.
- `tests/testthat/test-exploratory-layer.R` verifies the complete 39,543-row/27-candidate scope,
  all documented exploratory locators, raw A1 values, unchanged value/period/dimension fields,
  reconciliation, and null/duplicate fault injection.
- `docs/DATA_MODEL.md` and `docs/RESEARCH_DATABASE_GUIDE.md` document the corrected fields and profile
  semantics.
- `docs/audits/schema43_lineage_fix_report.md` is this evidence record.

No source file, archive, governed CSV/YAML record, parser identity, canonical fact, or production
database was changed. No `distinct()`-based observation suppression or manual DuckDB patch was used.

## Complete logical diff

The reviewed pre-fix artifact at
`/private/tmp/paraguay-exploratory-schema43.60oOOT/paraguay_macro_schema43.duckdb` was compared
read-only with the final isolated candidate. Canonical comparisons used bidirectional `EXCEPT ALL`;
the exploratory and catalogue comparisons joined their declared unique keys and compared every
shared non-lineage field with `IS DISTINCT FROM`.

| Population or field set | Before | After | Differences |
|---|---:|---:|---:|
| `canonical.fact_series_events`, all fields and multiplicities | 1,227,082 | 1,227,082 | 0 |
| `canonical.dim_series`, all candidate identities and dimensions | 13,985 | 13,985 | 0 |
| `main.v_series_latest`, all value/period/metadata fields | 1,226,739 | 1,226,739 | 0 |
| `explore.observations` rows | 957,627 | 957,627 | 0 |
| `explore.observations` candidates | 6,881 | 6,881 | 0 |
| Every shared exploratory field except `source_sheet`/`table_title` | 957,627 matched rows | 957,627 matched rows | 0 |
| Every shared catalogue field except profile `source_sheet`/`table_title` | 13,985 matched profiles | 13,985 matched profiles | 0 |
| Observation `source_sheet` |  |  | 39,543 intended changes |
| Observation `table_title` |  |  | 37,800 intended changes |
| Observation `value` on the same candidate/period/vintage key | 957,627 | 957,627 | 0 |
| `research.series_catalog` | 32 | 32 | 0 |
| `research.observations_latest_actual` | 7,498 | 7,498 | 0 |
| `research.entity_panel` | 332,745 | 332,745 | 0 |
| `research.curves` | 38,922 | 38,922 | 0 |
| `research.transactions` | 312,329 | 312,329 | 0 |
| `research.events` | 0 | 0 | 0 |

Bidirectional comparisons also found zero differences in
`research.observations_latest_statement`, `research.quality_flags`, and all research data views.
`research.dataset_catalog` has 24 logically identical rows after excluding its operational
`updated_at` field. Its timestamp changed from `2026-09-13 21:28:48` to
`2026-09-14 00:43:17` because `apply_platform_contracts()` rebuilt the isolated candidate; no
dataset content or admission state changed. This is the only measured non-lineage artifact
difference.

## Validation results

- Focused `tests/testthat/test-exploratory-layer.R`: passed.
- `tests/testthat/test-research-platform.R`: passed, including the EEFF collision fixture.
- `tests/testthat/test-public-interface.R`: passed.
- `tests/testthat/test-governance-and-migrations.R`: passed.
- `tests/testthat/test-ingestion-failure-isolation.R`: passed; its corrupt-zip warning is intentional.
- `tests/testthat/test-full-pipeline-smoke.R`: passed against the current real workbooks in a
  disposable project copy.
- `Rscript --vanilla run_tests.R`: passed the complete suite; the only warning is the intentional
  corrupt-zip fixture.
- All 1,060,785 documented rows across the four exploratory interfaces match their staging
  sheet/title/row/column and raw A1 numeric value; missing raw cells 0, coordinate disagreements 0,
  numeric differences 0.
- Corrected-candidate profiles: 12 BCP FX profiles with 14 exact worksheets and 15 financial
  profiles with exact worksheet `8`; summed correction rows 39,543.
- Isolated schema-43 validation: zero error-severity flags.
- Production SHA-256 before/after: unchanged.

## Release condition

The schema-43 worksheet-lineage pre-release condition is fully satisfied. The separate acceptance
condition requiring a clean-commit accepted schema-43 product and active-pointer promotion remains
outside this task and was deliberately not run. Production was not replaced.
