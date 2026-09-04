# Paraguay macroeconomic database — governed pilot v38

## About this project

Paraguay's central bank (BCP), insurance regulator (Superintendencia de Seguros), financial system regulator (Superintendencia de Bancos) and stock exchange (Bolsa de Valores de Asunción) each publish their statistical bulletins as standalone Excel/CSV workbooks — bank and finance-company financial statements, exchange-house balance sheets, payment-system activity, the economic annex, credit surveys, FX operations, bond curves, securities trades and more. Each publication has its own layout, is revised monthly or quarterly, and none of them are designed to be queried together.

This project turns those 22 official sources into a single governed, versioned DuckDB database that can be queried with plain SQL. It is an R-only, local pipeline — no Python, no external services, no manual spreadsheet wrangling. Every value keeps a traceable path back to its source file and worksheet, and every database build is content-addressed and deterministic: re-running the pipeline against unchanged inputs reproduces the exact same release.

How far that trace goes depends on the source family, and the difference matters when you need to check a number against the workbook:

- **Documented series** (the economic annex, payments, exchange houses, the credit survey, direct investment, the insurance annex, daily BCP FX, exchange rates, bancarisation and financial indicators, the interbank market, LRM auctions, compensatory FX sales and short-term liquidity) carry `source_row` and `source_column` on every observation, in the worksheet's own A1 coordinates.
- **Corporate bond curves and securities trades** carry `source_row` of the delimited file they were read from.
- **ICC, EVE and FX operations** carry the source file and worksheet but not a cell coordinate; their position has to be reconstructed from the parser's rules.
- **Bank and finance-company panels** carry the source file, worksheet and `source_row`, and keep every published column. Their institution and currency codes are stored as the text the publisher wrote, not as numbers.

What this buys a researcher or analyst working with Paraguayan macro/financial data:

- **One queryable history instead of dozens of spreadsheets.** All 22 sources share a common provenance, vintage and quality-flag model, so a single SQL query can span sources that would otherwise require manually reconciling incompatible Excel layouts every month.
- **Point-in-time correctness.** Because every observation is tied to the publication vintage that produced it, you can ask "what did this series look like as of a past release," not just "what does it look like now" — essential for reproducing prior analysis or auditing a revision.
- **Fail-closed data quality.** The pipeline does not silently coerce ambiguous data: unresolved units, unreviewed cross-source concept mappings, and hierarchy ambiguities are explicitly flagged rather than guessed at, and a run reporting `release_blocked` produced error-severity flags, is never published through the research views, and stops the caller with a nonzero status.
- **Explicit series identity.** A series is only merged with another when a human has reviewed and recorded the relationship in `config/concept_mappings.csv` — the pipeline never infers economic equivalence from similar-looking labels alone.

The schema is at version 38. `CHANGELOG.md` records the implementation history, while `docs/SCHEMA_MIGRATIONS.md` is regenerated from the executable migration registry on every run so it describes the database in front of you. The current readiness limitations and remediation plan are in `revisiones/EMPIRICAL_READINESS_2026-09-03.md`.

## What the three interfaces promise

Three access paths answer three different questions, and using the wrong one is the easiest way to get a technically valid, economically wrong answer.

| Interface | Question it answers | What it guarantees |
| --- | --- | --- |
| `v_series_latest`, `v_*_latest`, `v_latest_raw_*` | "What is the current data?" | The newest **published** vintage of each series, **realized observations only**. A staged or blocked build is invisible here; the `_all` twins exist for ingestion diagnostics and are not a research interface. |
| `v_publisher_statement_latest` | "What does the publisher currently say?" | The same, **including the 343 published projections**. Not an estimation sample. `marts.v_series_projections` is the projections on their own. |
| `series_as_of_date(d)` | "What did the database say on date `d`?" | Point-in-time, realized observations only; `series_statement_as_of_date(d)` includes projections. Ranks over **every vintage that was ever published**, not the ones currently published. **Snapshot-limited today** — see below. |
| `marts.v_research_series` and the validated marts | "What has an economist signed off on?" | Only series that an economist has reviewed in `config/series_review.csv` **and** whose worksheets are `validated` — two different reviews of two different objects, both required. **This is currently 0 rows by design**: no series has been through that review yet. |

Three things a researcher has to know:

- **The realized/statement split is new, and it is a breaking change.** Until schema 30, `v_series_latest` held the projections too and exposed `observation_status` beside them. That was defensible and the naming was not: `v_series_latest` is the obvious default, and a researcher who never read the column got 2028 forecasts in an estimation sample. Nothing is hidden — `v_publisher_statement_latest` is the full statement and `v_series_latest_observed` still works as an alias — but the default is now the safe one.
- **`latest` is not `validated`.** Everything outside the marts is the publisher's number with its provenance attached, not a reviewed economic series. Units, stock/flow and comparability across sources have not been adjudicated.
- **`as-of` is not real-time.** There is one retained vintage per source, no recorded revision, and no operator-recorded availability, so `series_as_of_date('2020-12-31')` returns **zero rows** despite history back to 1945. The mechanism is complete; the acquisition evidence is not. Do not make a real-time claim from this database until `config/source_vintages.csv` is filled in — `outputs/source_provenance_worklist.csv` says exactly what is missing per vintage.

  Until schema 36 the mechanism was *not* complete, and it would have failed quietly the moment a second vintage arrived: the as-of macros ranked over the bundle the active pointer names, so a superseded vintage left the population entirely and no cutoff could return it. Retaining a workbook would have produced two vintages and one answer. It now ranks over every vintage belonging to any accepted data release, which is the population a point-in-time question is about.

The sections below cover the quick start, the monthly replacement workflow, the full changelog of correctness fixes by version, the data model, and example queries.

## Quick start

1. Unzip the project and open `pilot_paraguay_macro_database.Rproj` in RStudio.
2. Reproduce the recorded environment once:

```r
renv::restore()
```

   `renv.lock` records R 4.5.1 and the exact package versions this database was built with, and `renv::restore()` is the only way to get them. `source("scripts/00_install_packages.R")` remains as a fallback for a setup without `renv`, but it installs whatever CRAN publishes today and checks presence rather than version — so it can leave you a step behind or ahead of the lockfile without saying so.

   **`run_update.R` now stops if the environment does not match**, rather than recording a lockfile digest that describes a library it was not built against. `check_environment()` names the difference. If you need to build anyway, `PARAGUAY_MACRO_ALLOW_ENV_DRIFT=1` is the deliberate override and the resulting build carries an `environment_drift_overridden` flag saying you took it.

3. Build or update the database:

```r
source("run_update.R")
```

   The run does not write `database/paraguay_macro_pilot.duckdb`. It copies it to `database/candidates/`, builds there, and renames the candidate into place only if the build is accepted — so budget roughly three times the database size in free disk. A blocked run leaves the published database byte-for-byte unchanged and keeps its candidate for you to inspect. See [docs/DATABASE_STORAGE.md](docs/DATABASE_STORAGE.md).

   The copy itself is cheap where the filesystem supports cloning — 0.1–0.3 seconds for 500 MiB on APFS — because `file.copy()` clones rather than duplicating blocks. On a filesystem without it, expect a full copy.

4. Inspect these files before using the update:

- `outputs/update_report.md`
- `outputs/quality_flags_latest.csv`
- `outputs/semantic_coverage_latest.csv`
- `outputs/documented_financial_coverage_latest.csv`
- `outputs/documented_source_coverage_latest.csv`
- `outputs/documented_sheet_drift_latest.csv`
- `outputs/documented_series_continuity_latest.csv`
- `outputs/report_storage_latest.csv`
- `outputs/ingestion_stage_timings_latest.csv`
- `outputs/observation_missingness_latest.csv` — every expected observation the publisher did not supply, and why
- `outputs/workbook_behaviour_latest.csv` — cached formulas and hidden rows per worksheet, with the observations read from hidden rows

Six further files are worklists for a reviewer rather than release diagnostics, and do not change between runs unless the evidence does: `outputs/canonical_core_candidates.csv`, `outputs/duplicate_series_candidates.csv`, `outputs/direct_panel_duplicate_keys.csv`, `outputs/source_region_review_worklist.csv`, `outputs/source_region_review_queue.csv` (the same cells ranked by the economic weight of the worksheet) and `outputs/source_provenance_worklist.csv` (which acquisition field is missing per vintage, and what it costs).

The database is published at `database/paraguay_macro_pilot.duckdb`. A run whose report says `release_blocked` **cannot have changed it at all**. Schema 30 made publication a pointer at an immutable per-build decision, so a failed build could not withdraw the database; schema 33 makes the build run in a separate file that is renamed into place only if it is accepted, so a failed build cannot alter it either — which the earlier design could not prevent, because the run and the published database were the same bytes. The last published build stays published, byte for byte, while you read the flags and repeat the run, and the failed build is retained under `database/candidates/` if you want to see what it produced.

## Monthly replacement workflow

Each source has one folder under `input/current/`. Replace the workbook in the appropriate folder with the new official version and run `source("run_update.R")`. Keep the folder name and source registry entry stable; the official Excel filename may change.

The pipeline ignores Excel lock files beginning with `~$`. Identical bytes reuse the existing content vintage and archive copy.

**Since schema 32 every source selects by the SHA-256 recorded in `config/source_vintages.csv`, and this changes one failure mode.** With one candidate file in a folder — the normal case, where you replace the workbook and remove the old one — the rule never fires and nothing is different. With **two** candidates the run now stops and names the fix, where it used to pick the newer modification time and warn. That is deliberate: modification time is when a file reached this disk, not when the publisher released it, and a wrong vintage becoming current on a warning is not a risk worth carrying. If you mean to keep both files, record the intended one's hash; if you are replacing one, remove the old one.

The semantic reference workbook lives at:

```text
input/current/bank_reference/Referencias_bancos_financieras.xlsx
```

Replace it only when an official reviewed reference version changes. Its fifteen named Excel tables are identified primarily by worksheet and exact column signature; Excel’s autogenerated display name is used only to resolve an otherwise ambiguous match.

## Current release and change history

The active project is schema 38. `CHANGELOG.md` is the single maintained implementation history;
`docs/SCHEMA_MIGRATIONS.md` is generated from the migration registry and records the executable
upgrade path. Historical audit narratives and version-specific repair notes are intentionally not
part of the current distribution. The only current readiness assessment and remediation plan is
`revisiones/EMPIRICAL_READINESS_2026-09-03.md`.

## Data layers

| Layer | Main objects | Interpretation |
|---|---|---|
| Provenance | `source_files`, `source_sheets`, `release_sources`, `reference_table_loads` | Hashes, publishers, formats, publication dates, worksheet and named-table inventory |
| Raw | `report_sheet_versions`, `report_sheet_vintages`, `report_cell_values`, `report_cells`, `raw_banks_*`, `raw_financial_*` | Deduplicated report cells and source-aligned observations with full vintage provenance |
| Curated snapshots | `consumer_confidence_snapshot`, `eve_expectations_snapshot`, `fx_operations_snapshot`, `documented_series_snapshot`, `bond_curve_snapshot`, `securities_transactions_snapshot` | Guarded semantic observations for each publication vintage |
| Financial semantics | `dim_entity`, `dim_currency`, `dim_statement_item`, `dim_ratio`, `dim_portfolio_item`, `dim_credit_activity`, account maps | Verified labels and concordances from the reference workbook |
| Series semantics | `dim_series`, `dim_concept`, `map_series_concept`, `fact_series_events`, `series_revisions` | Source series, reviewed concepts, explicit relationships and sparse change/removal events |
| Quality and operations | `structure_checks`, `quality_flags`, `discarded_rows`, `semantic_coverage`, `ingestion_stage_timings` | Fail-closed guards, omissions, checks, limitations and measured runtime by stage |
| Views | `v_series_latest`, `v_series_catalogue`, `v_latest_raw_*`, `v_*_documented`, `v_*_latest` | Current, analysis-oriented access without losing source coordinates |

`report_cells` is a compatibility view that reconstructs the full vintage-sheet-cell inventory from deduplicated content plus vintage links. It is not a claim of harmonized statistical coverage.

## Bank and finance-company semantic views

The reference workbook supplies verified institution names, currency codes, financial-statement classifications, ratios, portfolio concepts, underlying account maps and 1,112 detailed activity-to-bulletin-sector mappings. The original raw columns remain in every documented view.

```r
library(DBI)
library(duckdb)
source("scripts/01_utils.R")
source("scripts/05_query_helpers.R")
con <- open_macro_database()

# Financial statements with institution, currency and hierarchy labels
dbGetQuery(con, "
  SELECT fecha, short_name, currency_of_origin, unit_currency,
         semantic_classification, semantic_rubro, semantic_sub_rubro, importe
  FROM v_banks_eeff_documented
  WHERE fecha >= DATE '2026-01-01'
  LIMIT 100
")

# Detailed credit activity with the bulletin-sector concordance
dbGetQuery(con, "
  SELECT fecha, short_name, activity_code, bulletin_sector,
         cartera_vigente, cartera_vencida
  FROM v_banks_credito_actividad_documented
  LIMIT 100
")
```

Equivalent views exist for `financial` and for `ratios`, `carteras`, `credito_sector` and `credito_actividad`.

## Documented Excel sources and market CSVs

```r
# Detailed Annex catalogue and latest observations
dbGetQuery(con, "SELECT source_sheet, series_label, unit, frequency, first_period, last_period
                  FROM v_documented_series_catalogue
                  WHERE source_id = 'economic_annex'")
dbGetQuery(con, "SELECT * FROM v_economic_annex_latest WHERE source_sheet = 'CUADRO 9' LIMIT 100")

# Other newly normalized sources
dbGetQuery(con, "SELECT * FROM v_payments_latest LIMIT 100")
dbGetQuery(con, "SELECT * FROM v_exchange_houses_latest LIMIT 100")
dbGetQuery(con, "SELECT period, question, response, value
                  FROM v_credit_survey_latest WHERE source_sheet = '%' LIMIT 100")

# All additional Excel sources share the documented-series interface
dbGetQuery(con, "SELECT source_id, source_sheet, series_label, period, value, unit, scale
                  FROM v_documented_series_latest_snapshot
                  WHERE source_id = 'interbank_market' LIMIT 100")

# Typed long-format market sources
dbGetQuery(con, "SELECT * FROM v_bond_curves_latest LIMIT 100")
dbGetQuery(con, "SELECT * FROM v_securities_daily_activity ORDER BY operation_date DESC LIMIT 100")
```

`series_id` is based on source, worksheet, semantic label path and frequency—not inferred unit or currency. `source_row` and `source_column` trace every normalized value back to the official worksheet. Treat `source_units`, `identity_stability IN ('positional', 'positional_lane')`, and `hierarchy_status = unresolved` as review flags.

## Latest and historical series queries

```r
dbGetQuery(con, "SELECT * FROM v_series_catalogue ORDER BY source_id, series_id")
series_latest(con, "icc:icc")
series_as_of(con, "2026-06-30", "icc:icc")
series_revision_history(con)
concept_catalogue(con)
# series_by_concept(con, "concept:bcp:reviewed_identifier")
```

## Tests

Run the complete test suite from the project root:

```r
source("run_tests.R")
```

The full smoke test copies the real pilot inputs to a temporary directory, builds a fresh DuckDB database, requires every registry source to complete, checks semantic date plausibility, verifies minimum source contracts and confirms documented bank mappings. Runtime validation separately rejects unexplained observation shrinkage, series disappearance and metadata drift relative to the prior completed vintage.

## Upgrades and reconstruction

For a database created by pilot v1:

```r
source("scripts/upgrade_v1_to_v12.R")
```

The script backs up and retires the v1 database before rebuilding. Obsolete version-specific compatibility wrappers are not shipped.

**`docs/SCHEMA_MIGRATIONS.md` is the authority on this, and it is generated from the migration registry on every run.** Read it for the current entry point, the per-version table of what each step changed, and which sources each step re-ingests.

Any database at an earlier applied schema upgrades automatically when `run_update.R` is executed; `initialize_database()` walks every step it is missing, in order, and re-ingests only the sources whose registry entry says so. Existing full-copy `report_cells` data remains available through the compatibility view.

To reconstruct a separate database from archived content:

```r
source("rebuild_from_archive.R")
```

This creates `database/paraguay_macro_rebuilt_from_archive.duckdb` and never overwrites the production database.

## Documentation map

- `docs/ARCHITECTURE.md`: processing sequence and extension rules.
- `docs/DATA_MODEL.md`: keys, vintages, semantic dimensions and view grains.
- `docs/SEMANTIC_REFERENCE.md`: exact reference tables, mappings and coverage behavior.
- `docs/DOCUMENTED_SOURCES.md`: parser orientations, series identity, hierarchy, units, all expanded sources and review queries.
- `docs/CONCEPT_GOVERNANCE.md`: safe cross-source mapping workflow and review contract.
- `docs/OPERATIONS.md`: replacement procedure, acceptance checklist and recovery.
- `docs/VERIFICATION.md`: verified workbook facts, test targets and environment limitation.
- `docs/SCHEMA_MIGRATIONS.md`: generated from the migration registry on every run — which version the database is at, what each step changed, and which sources it re-ingested.
- `revisiones/EMPIRICAL_READINESS_2026-09-03.md`: current limitations, evidence and ordered remediation plan.
- `config/table_dictionary.csv`: machine-readable database object catalogue.

## Pilot boundary

All 22 supplied sources are queryable, but “queryable” does not mean “equivalent” or “additive.” The pipeline preserves each publisher’s sheet, label, frequency and unit identity, and explicitly marks unresolved hierarchy. The concept framework will not merge series until reviewed mappings are entered in `config/concept_mappings.csv`. `generate_spec_skeletons.R` creates optional review companions; it does not change active mappings.
