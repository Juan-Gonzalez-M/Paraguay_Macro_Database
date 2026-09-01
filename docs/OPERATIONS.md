# Operations manual

## First run

1. Open `pilot_paraguay_macro_database.Rproj` in RStudio.
2. Run `source("scripts/00_install_packages.R")` once.
3. Run `source("run_tests.R")` to validate the environment and pilot inputs.
4. Run `source("run_update.R")` to create the production database.
5. Review all output files listed in the README, especially `documented_source_coverage_latest.csv` and `documented_series_continuity_latest.csv`.
6. For a changed complex workbook, inspect `documented_sheet_drift_latest.csv`; any `missing_sheet`, `observations_shrank`, or `series_shrank` result is an error requiring explanation.
7. Inspect continuity changes. A `documented_series_identity_break` or `documented_series_metadata_changed` error means the new publication is not accepted even if its total row count grew.
8. Inspect `ingestion_stage_timings_latest.csv`. A clean first build is naturally heavier; a repeated update with unchanged hashes should report `reuse_and_validation` rather than full curation.

Concept mappings are maintained separately in `config/concept_mappings.csv`. Adding a row is a semantic assertion, not routine ingestion maintenance; record the official evidence, reviewer and date before running the update.

Table statuses are maintained in `config/table_status.csv`. Every registered source needs a `*` row, which covers any worksheet without a row of its own. A newly published worksheet therefore lands on the source's wildcard status — normally `provisional` — rather than arriving unstatused: it **is** in the catalogue and queryable, and what the wildcard withholds is research validation, not the data. `validate_database()` raises `table_status_incomplete` and blocks the release only if a source has no row at all. Promoting a table to `validated` publishes it through `v_research_series` and the `v_mart_*` views, and requires a named reviewer, a review date, an evidence URI and an answer to each of the five review questions — it asserts that an economist checked the table's definitions, units, period conventions, hierarchy and methodology, which is not something the automated gates can establish. A database `CHECK` enforces the reviewer, date and evidence, so the claim cannot be made by editing the table directly either.

Each row also states a `parser_claim` — `none`, `unread_cells` or `cell_reuse` — describing what it asserts about the parser. `validate_governance_drift()` checks that claim against the reconciliation this release computed, in both directions, and blocks if a row still describes a defect that is fixed or stays silent about one that is live. The eight foreign-trade notes that went on describing a repaired period-axis bug for months are what this replaced.

## Connecting to the database

Open it the way you would open any DuckDB file. Nothing has to be configured:

```r
con <- DBI::dbConnect(duckdb::duckdb(), "database/paraguay_macro_pilot.duckdb", read_only = TRUE)
DBI::dbGetQuery(con, "SELECT * FROM marts.v_mart_prices LIMIT 10")
```

Every stored view and macro names its dependencies in full, so a default connection resolves them. **Do not set a `search_path`.** If a query only works after you set one, that is a defect: report it, because it means an object shipped unqualified and the release gate missed it.

`scripts/05_query_helpers.R` is the supported read interface — `series_latest()`, `series_as_of()`, `series_revision_history()`, `series_by_concept()`, `concept_catalogue()` — and it opens exactly the connection above.

This section exists because the schema-21 release got it wrong. Moving every table into a storage layer left all 74 views and all three macros binding their tables by bare name, which resolved only against the search path the pipeline sets on its own connections. From anyone else's connection they raised `Catalog Error: Table with name dim_series does not exist`. Schema 22 rewrote every stored object with qualified dependencies and added two gates so it cannot recur:

- **`unqualified_object_dependency`** reads the stored SQL back out of the database and rejects a bare reference to a project object.
- **`fresh_connection_object_failed`** opens a second connection with nothing configured and executes every view and every macro on it.

Both are error-severity and block the release. `compact_database.R` and `prepare_distribution.R` run the execution check too, before they swap or ship anything.

## Where things live

Eighty tables sit in five storage layers, and the layer says what the object is for rather than what it is called:

| Layer | Holds | Example |
|---|---|---|
| `raw` | file, sheet and cell evidence exactly as read | `raw.report_cell_values`, `raw.source_files` |
| `staging` | typed parser output and parser diagnostics | `staging.documented_series_snapshot` |
| `canonical` | the curated economic layer | `canonical.dim_series`, `canonical.fact_series_events` |
| `marts` | the research-facing interface (views only) | `marts.v_mart_prices` |
| `audit` | governance, review status, reconciliation, release evidence | `audit.table_status`, `audit.quality_flags` |

`main` holds internal views only; no table is left in it, and `storage_layer_unassigned` warns if one appears.

The fact table is keyed on `(series_sk, period, vintage_sk)` — BIGINT surrogates, because the old key was two long text columns and cost more index than table. The human `series_id` and `vintage_id` stay on every fact row and stay unique in the dimensions, so no query has to know the surrogates exist; three release-gate tests assert the two never diverge.

## Research marts and the `_all` split

Each domain mart is published twice and the names mean different things:

- `marts.v_mart_<domain>` carries only rows whose worksheet an economist validated **and** whose source cells reconcile. Use this one. It is empty today, and that is the honest answer — no table has been validated.
- `marts.v_mart_<domain>_all` carries everything, including provisional worksheets. Use it knowingly, for exploration, and do not report from it without saying so.

`marts.v_research_series` is the series-level equivalent: one row per series, validated only if **every** worksheet the series was assembled from is, **and** the series carries a complete research-eligibility record — unit, scale, frequency, stock/flow, nominal/real and seasonal adjustment, none of them left at `not_reviewed`.

Catalogues are published per series grain: `marts.v_catalogue_scalar_series` is the macroeconomic surface, and `v_catalogue_event`, `v_catalogue_curve_panel` and `v_catalogue_entity_panel` hold auction tenders, curve nodes and per-institution statement lines. Quote the scalar count when asked how many macroeconomic series this database holds; the others are complete and queryable but are not series about the economy.

## Defect states, and what "balanced" covers

A worksheet's reconciliation status is derived, not configured:

| Status | Meaning |
|---|---|
| `balanced` | every numeric cell inside the parsed region is an observation or a classified non-observation |
| `defects_recorded` | fully classified, but a reviewed rule says published data is not being read |
| `unexplained_cells` | a numeric cell matches no rule — **blocks the release** |
| `cell_reuse_detected` | one source cell feeding several observations — **blocks the release** |

A `defects_recorded` worksheet keeps its `table_status` at `needs_remodeling` with `parser_claim = unread_cells`, is excluded from `v_research_series` and from every validated mart, and cannot be promoted. `validate_governance_drift()` checks the claim against the measured reconciliation in both directions, and `governance_note_stale_count` checks any number written into a status note against the live metric it names.

**`balanced` speaks only for the rectangle the parser consumed.** Since schema 24 the cells outside it are classified rather than merely counted. `source_region_classification` is built from the raw cell layer independently of what the parser emitted, over every documented worksheet, and every cell resolves to a rule in `config/source_region_rules.csv` or to `unreviewed`:

| Classification | Meaning |
|---|---|
| `period_axis` | the year or date column the sheet is indexed by; Excel stores a date as a number |
| `row_index` | a row number, ordinal or published code beside the data |
| `header_or_note` | a numeric header, footnote marker or note outside the table body |
| `report_layout_derived` | cumulative-to-date and variation columns: report layout, not a time observation |
| `out_of_scope_block` | a second table on the worksheet this parser does not claim |
| `data_not_ingested` | published data no parser region reaches — **blocks promotion to `validated`** |
| `unreviewed` | nobody has said which of the above it is — **blocks promotion to `validated`** |

Neither blocks the release: a gate nobody can pass is a gate that gets switched off, and nobody classifies tens of thousands of cells in one sitting. Both block promotion, because a worksheet whose region has not been examined has not been shown to be complete.

Work the queue from `outputs/source_region_review_worklist.csv`, add a rule with the worksheet evidence quoted, and re-run. `source_region_rule_unused` tells you a rule stopped matching — usually because a parser repair landed. Note that a rule's `source_sheet` is matched byte for byte: several published worksheets end in a space (`CUADRO 10 `, `Subastas 2015 `), and the register keeps them exactly as the publisher typed them.

## Accepting or blocking a release

A release enters the database `staged` and leaves it `accepted` or `blocked`. Since schema 27 **every** published interface — `v_series_latest`, `series_as_of_date()`, the seventeen `v_latest_raw_*` direct panels, the documented family, both market views and every `marts.*` view — shows only vintages belonging to an accepted release, so a run that ends `release_blocked` publishes nothing at all. The sources have committed, the diagnostics are complete, and the data is simply not visible through any research interface until the run repeats without error-severity flags.

```sql
SELECT release_id, status, decided_at, error_count, warning_count FROM audit.releases;
```

Every filtered view has an unfiltered `_all` twin. Use those to inspect a staged or blocked release; do not use them for research output. Re-running a bundle does **not** un-accept an already-accepted release: the accepted release stays readable while the next one builds, and promotion is a single terminal `UPDATE` at the end.

Nothing here is meant to be edited by hand. If you must override a decision, update `audit.releases.status` and record who did it in `decided_by` — the change takes effect immediately, because every published view joins through that table rather than being rebuilt from it.

## Recording where a source came from

`config/source_vintages.csv` is the acquisition record, keyed by `source_id` and the file's SHA-256. Fill `official_release_date`, `official_url`, `release_identifier`, `retrieved_at` and `retrieval_method` when you download a file; the licence field records the publisher's terms. It ships with every row `pending`.

The release warns while it is incomplete: `publication_date_inferred_from_content` lists every vintage whose availability is still being guessed from a filename or from the content. `official_release_date` outranks both, so recording it is also how you correct a date the pipeline inferred wrongly — the next run picks it up even for an unchanged file, and propagates it to every snapshot and fact of that vintage.

`available_at` is a separate field and a separate fact: when the file actually became available to you, which is not the reference period it covers and not necessarily the date printed on it. It is what `series_as_of_date()` ranks by when it is present, so a point-in-time query is only as honest as this column. Leave it blank rather than guessing; the pipeline falls back to the publication date and says so.

## Preparing a copy for distribution

```
Rscript prepare_distribution.R
```

Writes `database/paraguay_macro_pilot_distribution.duckdb` with `source_path` and `archive_path` blanked. Those are absolute workstation paths and are run metadata: true of the machine that ingested the file and of nothing else. The portable lineage — `source_uri`, `archive_uri` and `sha256` — is kept and verified, and the copy is opened and executed before it is written. The live database is never modified.

## Schema migrations

**See [SCHEMA_MIGRATIONS.md](SCHEMA_MIGRATIONS.md).** That file is generated from the migration registry and the `schema_version` table on every release, so it always describes the database you have in front of you: which version it is at, what each step changed, and which sources each step sends back through the parser.

It is generated rather than written because this section used to be written by hand and drifted. It named `upgrade_v1_to_v12.R` as the entry point while the recovery section below named `upgrade_v1_to_v11.R`, and the recovery sequence stopped at schema 11 while the database was at 14 — three statements about the same migrations, none of them checked against the registry. `validate_database()` now raises `migration_runbook_stale` if the generated file falls behind.

Do not edit `docs/SCHEMA_MIGRATIONS.md`. To change what it says, change `SCHEMA_MIGRATIONS` in `scripts/02_extract_raw.R`, which is also what the invalidation steps read.

## Recording an identity migration

Any run that changes how `series_id` is built retires identifiers, and the release gate blocks until the move is recorded. After such a run:

```
Rscript build_migration_map.R database/backups/<the backup taken before the run> schema_<from> schema_<to>
```

The map is always written into the production database, whichever pair of releases is compared. To record an older hop whose "current" side is itself an archived file, pass that file as a fourth argument. Recording every hop matters because resolution is transitive: an identifier published two releases ago may have been renamed twice before reaching the live catalogue.

If `run_update.R` stops with `Release gate: the run produced error-severity quality flags`, read `outputs/quality_flags_latest.csv`. A `superseded_identifier_unresolved` flag means exactly this step is outstanding.

## Reclaiming space after a migrating release

The database file grows on every run and never shrinks on its own. A run that rewrites a table writes the replacement blocks before releasing the old ones, so the file expands to that run's high-water mark; the freed blocks are reused by later runs but are never returned to the operating system. `docs/DATABASE_STORAGE.md` explains the mechanism.

Run the compaction after any migrating release, and after any burst of repeated runs:

```
Rscript compact_database.R
```

It backs the database up to `database/backups/`, copies every object into a fresh file, and swaps that in **only** if the two are content-identical. Row counts are not enough — a defect that moves a value between two rows, swaps two columns or drops a column default leaves every count unchanged — so every table is compared as a multiset in both directions with `EXCEPT ALL`, alongside column definitions and defaults, view SQL, constraints, indexes, sequences, macros and the schema version. If anything differs it deletes the candidate and leaves the live database untouched.

Expect roughly:

| Situation | Peak allocation during the run |
|---|---|
| A routine run | about 9 MiB |
| A migrating release that re-ingests the Annex | 100 MiB or more |
| After compaction | the size of the live data |

Read these as the space a run must be able to *claim*, not as permanent growth. Freed blocks go back on the file's own free list and the next run writes into them before extending the file, so a steady monthly cadence climbs to a plateau and stays there — the file stops growing well before the sum of these numbers. What compaction reclaims is the plateau itself, and only a burst of migrating runs pushes that plateau far above the live data.

Report used and free blocks after each release rather than watching the file size:

```r
DBI::dbGetQuery(con, "
  SELECT round(used_blocks * block_size / 1048576.0, 1) AS used_mib,
         round(free_blocks * block_size / 1048576.0, 1) AS free_mib,
         round(100.0 * free_blocks / total_blocks, 0)   AS pct_free
  FROM pragma_database_size()")
```

The schema-13 and schema-14 round is the worked example: about ten runs, several of them migrating, took the file from 230 MiB to 555 MiB, of which 254 MiB was free space. Compaction returned it to 301 MiB with every row, view and constraint verified identical.

Compaction matters more than the disk cost suggests, because `database/paraguay_macro_pilot.duckdb` is tracked through Git LFS: every committed release stores the whole file, so a bloated database consumes LFS quota and bandwidth on each commit. Compact before committing a release.

## Routine replacement

1. Close the Excel workbooks.
2. In each updated source folder under `input/current/`, remove the old current workbook and place the newest official workbook.
3. Do not rename folders or edit `input_archive/`.
4. Run `source("run_update.R")`.
5. Accept the update only after reviewing status, errors, warnings, semantic coverage and documented financial mapping coverage.

Replacing only some source files is valid. Unchanged hashes reuse their existing vintages.

## Reference workbook procedure

Treat `input/current/bank_reference/Referencias_bancos_financieras.xlsx` as a governed input. When it changes:

1. confirm that the workbook is an official/reviewed version;
2. replace the current file;
3. run the test suite;
4. run the update;
5. compare named-table counts and documented mapping coverage with the previous run.

Autogenerated Excel table names may change without intervention. A failure should be investigated only when no unique worksheet-plus-column-signature match exists or when the columns themselves changed.

Never weaken `config/reference_schema.csv` merely to make a changed workbook pass. First determine whether the change is structural only or changes the statistical meaning.

## Failure interpretation

### `source_ingestion_failed`

The affected source transaction rolled back. Read the detail in `quality_flags_latest.csv`. Prior valid values remain available.

### `documented_mapping_below_threshold`

One or more new source codes/labels do not match the reference tables. Inspect the raw label and obtain an updated verified reference. Do not add fuzzy or memory-based mappings.

### Date guard failure

Confirm the actual Excel cell type and epoch. Do not expand the acceptable date range to accommodate an unexplained future date.

### Subtotal failure

Check frequency membership, signs, missing components and published adjustments. The known 2004 FX annual non-additivity is documented in `config/validation_exceptions.csv`; an unlisted year remains an error.

### Multiple candidates

Remove the stale file or deliberately configure a multi-file source. The warning states which file was selected.

### Documented-source contract failure

The workbook no longer contains the required worksheets, too few worksheets matched a supported orientation, or extracted coverage collapsed below the established pilot baseline. Compare `documented_source_coverage_latest.csv` with the new workbook and inspect its changed headers before modifying a parser or contract.

### `documented_units_need_review`

The data loaded, but the workbook did not state a unique unit in enough title/header paths. Filter `v_documented_series_catalogue` for `unit = 'source_units'`. Add a reviewed source-specific override only after confirming the official table note; never replace it with a guessed currency or index unit.

### `positional_series_identity`

Repeated source labels required a row/column collision suffix. The data is queryable, but inspect `identity_stability = 'positional'` when the workbook layout changes.

### `positional_lane_series_identity`

The official file contains multiple rows with the same period and semantic dimensions but no transaction identifier. Every row is retained in deterministic source order and observed values are excluded from identity. Inspect the affected source coordinates when comparing a structurally changed publication.

### `source_ingestion_failed` during discovery

The workbook could not be inventoried or registered. The source is recorded with `failed_structure_or_ingestion`, the detail is written to quality flags, and subsequent sources continue. Replace or repair the file; do not delete prior valid vintages.

### `documented_hierarchy_unresolved`

Published totals and components coexist without reviewed parent-child keys. Filter by sheet and choose either the published aggregate or its components; never sum every series blindly.

### Long-CSV contract failure

The CSV header, minimum row count, date range, transaction key or required currencies changed. Confirm delimiter/encoding and obtain the complete official file before changing `config/long_csv_contracts.csv`.

### `source_token_unreviewed`

The publisher wrote something other than a number in a cell, and nobody has said what it means. Find it in `outputs/observation_missingness_latest.csv` — the `source_token` column carries the exact text — open the worksheet, and add a row to `config/source_value_tokens.csv` giving the token a status (`no_movement`, `not_available`, `suppressed`, `formula_error`), its meaning, the evidence you read it from, **your name** and the date. `layout_verified` is rejected here: what a publisher means by a token is not a claim about layout, and only a person can make it. Until it is registered the token blocks promotion to `validated` but not the release.

### `current_view_contains_projections`

Not a defect — the count of observations in `v_series_latest` that are dated after the vintage that published them. The annex publishes forecast years and FX operations publishes to year end. Act on it in the query, not in the pipeline: filter `observation_status = 'observed'`, or read `v_series_latest_observed`. Investigate only if the count moves sharply without a new forecast horizon in the source.

### `published_identity_incomplete`

The publisher gives an aggregate at some period but not every component of it, so the identity cannot be tested there. This is usually the source's own convention (a SIPAP total published before its breakdown existed) and is a warning, not an error. Compare with `published_identity_broken`, which is an error and means the components *are* all present and do not add up — that is a parser reading the wrong columns, or a source that changed shape.

### `workbook_cached_formulas_and_hidden_state` and `workbook_behaviour_changed`

The first reports state and is expected every release: how many cells hold cached formula results, how many worksheets hide rows or columns, and how many published observations sit on hidden rows. Read `outputs/workbook_behaviour_latest.csv`; no action is implied.

The second is the one to act on. A worksheet changed its formula count or its hidden ranges between vintages, which no cell-by-cell comparison shows. Open both workbooks and establish what the publisher changed before accepting the release — a block newly hidden may be a series they have stopped standing behind.

### Update remains unexpectedly slow

Sort `outputs/ingestion_stage_timings_latest.csv` by `elapsed_seconds`. `source_discovery_and_metadata` isolates workbook/XML inventory, `ingestion_and_curation` includes the single-pass sheet read plus raw/semantic persistence, and `source_validation` isolates guards. Rows with no `source_id` are the release-wide phases — reconciliation, region classification, the expected grid, missingness, semantics, canonical, marts and validation — which are timed since schema 29; `observation_missingness` is normally the slowest of them. Timings are keyed by `attempt_id` and appended, so compare the current attempt against the previous ones rather than against a remembered number. If an unchanged file is fully curated, check `source_files.ingestion_status`: completed content-identical vintages should take the `reuse_and_validation` path. Do not delete the DuckDB database for routine monthly updates, because that deliberately forces a full rebuild.

## Acceptance checklist

- Run status is not `release_blocked`, and `audit.releases` records the release as `accepted`.
- Every required source vintage has status `completed`.
- All structure checks passed.
- All semantic dates are plausible.
- No data-bearing row was silently discarded.
- Financial entity/currency mappings are complete.
- Currency code 6200 is classified as origin FX and unit PYG.
- Financial hierarchy/activity mapping is at least 99.9%, and residuals are understood.
- Published totals reconcile or have a documented source-side exception.
- All required documented-source sheets meet their configured coverage contracts.
- No unexplained series identities disappeared and no continuing series changed unit, scale or currency.
- Positional identities and unresolved hierarchies are understood before aggregation.
- `source_units` series are not combined with known-unit series without manual review.

## Recovery and migration

Recovery from any applied schema version is the normal update: `source("run_update.R")`. `initialize_database()` walks every step the database is missing, in order. **See [SCHEMA_MIGRATIONS.md](SCHEMA_MIGRATIONS.md)** for the per-version table of what each step changes and which sources it re-ingests, and for the version-1 entry point.

- A fresh database follows the bootstrap path and executes no historical invalidation. A non-empty database with no recognized schema version fails closed instead of guessing which migration applies.
- Archive reconstruction: run `source("rebuild_from_archive.R")`; it writes a separate database.
- Never manually edit or delete `input_archive/` content.
