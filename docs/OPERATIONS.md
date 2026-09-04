# Operations manual

## First run

1. Open `pilot_paraguay_macro_database.Rproj` in RStudio.
2. Run `renv::restore()` once to reproduce the recorded environment. `source("scripts/00_install_packages.R")` is the fallback without `renv`; it installs by name rather than by version. `run_update.R` refuses to build against an environment that differs from `renv.lock` unless `PARAGUAY_MACRO_ALLOW_ENV_DRIFT=1` is set, which is recorded as a flag on the build.
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

Grain is declared in `config/source_grains.csv`, one row per source under the `*` wildcard and, since schema 32, optional rows per worksheet that override it. Add a worksheet row when one workbook mixes structures — direct investment is the case in the file: the source is `scalar_series`, and its `Cuadro 5` and `Cuadro 7` are foreign direct investment stocks by country, which is an entity panel. Every registered source still needs its `*` row; a missing one stops the run.

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

### The delimited sources, where the unit is a row

The two CSV sources are accounted for in the same table under the same rule, with `source_sheet = 'data'` and a row where a worksheet has a cell:

```text
source data rows = accepted rows + rejected rows + documented exclusions
```

Source rows come from the recorded content bounds, accepted rows are the snapshot, and rejected rows are `staging.discarded_rows`. A residual is `unexplained_cells` and blocks, exactly as it does for a worksheet.

Until schema 34 neither source was in this table at all. Both parsers read permissively and dropped whatever failed to parse, so the only loss they could notice was losing every row — and three real securities trades with a blank volume had been disappearing on every run since the source was added.

Every recorded rejection carries a reason from `ROW_REJECTION_REASONS`, and `config/row_rejection_reasons.csv` says what each one means and whether seeing it is expected:

| Reason | `expected` |
|---|---|
| `non_data_note` | a labelled row with no numeric value: a heading, note or footnote — **expected** |
| `missing_mandatory_dimension` | a real publisher record the grain cannot place — **expected** |
| `invalid_date`, `invalid_numeric_token`, `unsupported_currency`, `out_of_range_value`, `duplicate_key`, `unrecognized_period_with_values` | **unexpected**: the publication has changed shape or the contract is wrong |

An **undeclared** reason is an error and blocks the release. An **unexpected** one is a warning: the reason is understood, and its appearance means something changed. To add a reason, add it to `ROW_REJECTION_REASONS` in `scripts/01_utils.R` *and* to the register — the reader checks the two sets match in both directions, so neither can drift.

## Accepting or blocking a release

Since schema 30 a run decides a **product**, not a source bundle, and publishing is a pointer.

```sql
-- what is published right now, and what decided it
SELECT a.data_release_id, a.promoted_at, d.status, d.schema_version, d.error_count, d.warning_count
FROM audit.active_data_release a JOIN audit.data_releases d USING (data_release_id);

-- every decision ever recorded, none of which can be rewritten
SELECT data_release_id, source_bundle_id, status, decided_at, decided_by FROM audit.data_releases
ORDER BY decided_at DESC;
```

**A failed run no longer withdraws the database it failed to replace.** This is the change to understand: a `release_id` hashes only the source files, so re-running the same bundle with broken code used to set that shared row to `blocked` and empty every research view. Now a blocked build records its own verdict and never touches the pointer. The previously published build stays published while you read the flags and repeat the run.

Every published interface — `v_series_latest`, `series_as_of_date()`, the seventeen `v_latest_raw_*` direct panels, the documented family, both market views and every `marts.*` view — resolves through that pointer. Each has an unfiltered `_all` twin; use those to inspect an unpublished build, never for research output.

What each object publishes is declared in `config/public_view_contract.csv`. **Adding a view without a row there blocks the release** — deliberately, because a view nobody has classified is one nobody has decided researchers should read. Set `public_scope` (`current`, `all`, `history`, `reference`, `diagnostic`), say why in a sentence, and put your name on it. If the view carries the release boundary in its own body rather than reading something that does, set `carries_release_boundary` to `TRUE`; the release verifies that claim against the stored SQL.

### A build runs in its own file

Since schema 33 a run does not write the published database at all. `run_isolated_update()` copies `database/paraguay_macro_pilot.duckdb` to `database/candidates/candidate_<stamp>.duckdb`, runs the whole pipeline there, and renames the candidate into place only if the build is accepted:

```text
production (untouched, still published)
        │ copy
        ▼
database/candidates/candidate_<stamp>.duckdb  ← every write the run makes
        │
   accepted? ──no──▶ database/candidates/blocked_<stamp>.duckdb
        │                (production is byte-for-byte unchanged)
       yes
        ▼
  production ─▶ database/backups/paraguay_macro_pilot_pre_swap_<stamp>.duckdb
  candidate  ─▶ production
```

This is the seventh audit's F-01. The pointer already prevented a failed build from *withdrawing* the published database; it could not prevent it from *changing* it. Published views resolve vintages through the source bundle rather than the build, sources commit one at a time long before the decision exists, and the schema migrations' `invalidate_v*()` steps delete published facts before the run even begins. None of that is reachable now, because the run and the published file are no longer the same bytes.

What it costs: a full copy of the database at the start of every run, and roughly twice the database size in free space while a run is in progress. What it does **not** give: facts are still not versioned per build, so an arbitrary past product cannot be reconstructed from inside one file. The guarantee is that a build you did not accept cannot have altered the one you did.

**A blocked run leaves `outputs/` describing the blocked build, not the database you have.** That is deliberate — diagnosing a block needs the blocked build's reports — and `outputs/update_report.md` says so in its first line. Query the retained candidate directly to inspect what the failed build produced.

### One writer at a time

Since schema 37 an update takes a lock at `database/.update.lock` before it copies anything, and releases it however the run ends.

This is not belt-and-braces on DuckDB's own lock — DuckDB's lock does nothing here. The whole point of the candidate design is that production is never *opened*; it is only copied. Two updates could therefore copy the same published database, build independently, both be accepted, and both rename over production. The last one won, and the other release vanished along with its build identity and every diagnostic it produced, silently.

- A **live** holder refuses the second run and names the process, host and start time.
- A holder whose process is **gone** is reported and taken over. A crashed update must not block the run that fixes it.
- If you are certain a lock is dead and the takeover did not fire — a different machine, say — remove the directory by hand.

**The base is verified too**, because a lock cannot cover every case: a lock inherited from a dead holder, or an operator restoring a backup by hand mid-build, produces a state no lock sees. The production file's SHA-256 is recorded when it is copied and re-checked immediately before the swap. If it changed, the run refuses and **keeps** its candidate under `database/candidates/unpublished_<stamp>.duckdb` — it is a complete accepted build, and you will want it to diff against whatever replaced its base.

### If a swap is interrupted

Between moving the published database aside and moving the candidate in, the published pathname does not exist. A soft failure is rolled back automatically; a hard kill in that window is not.

`database/.swap_in_progress` exists only during that window. If a run finds it, it **refuses to start** and tells you to read it. The file names three paths:

```
moved_aside=database/backups/paraguay_macro_pilot_pre_swap_<stamp>.duckdb
candidate=database/candidates/candidate_<stamp>.duckdb
publication=database/paraguay_macro_pilot.duckdb
```

Move whichever you want published to `publication`, then delete the marker. The two candidates are the previous database and the new build; both are intact, and the choice is yours.

### Verifying the published file

Every accepted swap writes `database/paraguay_macro_pilot.duckdb.sha256` after the file is closed, checkpointed and renamed — the one moment its bytes are final. It is in the format the standard tool reads:

```
shasum -a 256 -c database/paraguay_macro_pilot.duckdb.sha256
```

The hash lives beside the file rather than inside it because **a file cannot contain its own hash**: writing the row changes the bytes the row describes. That is why the artifact rows recorded before schema 38 are 37% short of the file they name — the size was read from a connection that was still open with rows still to write. A database therefore records the hashes of artifacts *other* than itself: `audit.distribution_artifacts` carries the real hash of the database each build replaced, and `compact_database.R` records the same link between what it consumed and what it produced.

### Overriding a decision

Nothing here is meant to be edited by hand, and **editing `audit.releases.status` does nothing**. Until schema 30 every published view joined that column; they now resolve through `audit.active_data_release`, and `audit.data_releases` records one immutable decision per product. A hand-edited status changes a lifecycle record and no data.

There are two supported interventions:

- **To withdraw the current build**, restore the database it replaced. Every accepted swap leaves it at `database/backups/paraguay_macro_pilot_pre_swap_<stamp>.duckdb`, and `audit.distribution_artifacts` records each artifact's size and build beside the build that produced it. Stop anything reading the database, move the current file aside, move the backup into its place, and confirm `audit.active_data_release` names the build you intended.
- **To publish a corrected build**, fix the cause and re-run. That is the whole procedure: a run that is accepted publishes itself and one that is not cannot.

The 2026-09-03 repository cleanup removed all superseded local backups. Until the next accepted run
creates a new pre-swap copy, the current database has no local predecessor to restore; use Git LFS
history if recovery of an earlier committed database is required.

There is no supported way to promote a build the gates blocked. That is not an oversight — `promote_data_release()` refuses a product not decided `accepted`, and the refusal is tested.

## Recording where a source came from

`config/source_vintages.csv` is the acquisition record, keyed by `source_id` and the file's SHA-256. Fill `official_release_date`, `official_url`, `release_identifier`, `retrieved_at` and `retrieval_method` when you download a file; the licence field records the publisher's terms. It ships with every row `pending`.

The release warns while it is incomplete: `publication_date_inferred_from_content` lists every vintage whose availability is still being guessed from a filename or from the content. `official_release_date` outranks both, so recording it is also how you correct a date the pipeline inferred wrongly — the next run picks it up even for an unchanged file, and propagates it to every snapshot and fact of that vintage.

`available_at` is a separate field and a separate fact: when the file actually became available to you, which is not the reference period it covers and not necessarily the date printed on it. It is what `series_as_of_date()` ranks by when it is present, so a point-in-time query is only as honest as this column. Leave it blank rather than guessing; the pipeline falls back to the publication date and says so.

### Retaining a superseded workbook

`series_as_of_date('2020-12-31')` returns zero rows because there is one vintage per source, not because the mechanism is missing. Every retained vintage is a past information set; the archive is what makes it one.

Two rules, and the first is the one that changed at schema 32:

- **Do not leave the old workbook in `input/current/<source>/`.** Selection is by the SHA-256 recorded in `config/source_vintages.csv`, so two candidate files in one folder stop the run by design. Replace the file, and let `input_archive/` keep the predecessor — it is content-addressed as `input_archive/<source_id>/<sha256>.<ext>` and is never overwritten, so the previous vintage is retained by the act of ingesting the new one.
- **Never prune `input_archive/`.** `validate_archive_integrity()` re-hashes every archived file on every release and raises `archived_vintage_unverifiable` — an error, which blocks — if a vintage the database reports cannot be re-read or no longer matches its recorded hash. A vintage without its bytes is not retained; it is a row claiming to be.

`outputs/vintage_retention_status.csv` reports, per vintage, the archive state and how many vintages that source now holds. While a source holds one, that row says so and says what it costs: no revision history and no as-of reconstruction.

To ingest a historical workbook you still have, put it in the folder on its own, record its hash in `config/source_vintages.csv`, run, then restore the current file and run again. Both vintages then exist and `series_as_of_date()` has something to rank.

**Until schema 36 that recipe did not work, and the manual was the thing that was wrong.** Each run mints a bundle whose id is a hash of the manifest, so the two runs produce two different bundles and the pointer ends on the second. The as-of macros ranked over `v_series_observations`, which filters to the bundle the pointer names — so the historical vintage was ingested, archived, retained, and invisible to every cutoff. Following these instructions produced two vintages and one answer.

The as-of interface now ranks over `main.v_series_observations_history`: every vintage belonging to **any accepted data release**, which is the population a point-in-time question is actually about. Three consequences worth stating plainly:

- **A superseded vintage stays answerable.** That is the whole point, and it is what makes retaining workbooks worth doing.
- **A build that was never accepted is never knowable**, at any cutoff. It was not published, so nobody could have read it, and admitting it would be look-ahead in the one interface that exists to prevent look-ahead.
- **Blocking a bundle today does not erase what it published yesterday.** Current views empty immediately, because the pointer moves; as-of keeps answering, because a later failed rebuild does not un-happen an earlier publication.

`series_as_of_date()` and `series_statement_as_of_date()` are declared `history` in `config/public_view_contract.csv`, not `current`. That reclassification is part of the repair: the release lint requires a `current` object to descend from the active-pointer carrier, so while they were declared `current` the lint was certifying exactly the thing that made them wrong.

## Preparing a copy for distribution

```
Rscript prepare_distribution.R
```

Writes `database/paraguay_macro_pilot_distribution.duckdb` with `source_path` and `archive_path` blanked. Those are absolute workstation paths and are run metadata: true of the machine that ingested the file and of nothing else. The portable lineage — `source_uri`, `archive_uri` and `sha256` — is kept and verified, and the copy is opened and executed before it is written. The live database is never modified.

## Schema migrations

**See [SCHEMA_MIGRATIONS.md](SCHEMA_MIGRATIONS.md).** That file is generated from the migration registry and the `schema_version` table on every release, so it always describes the database you have in front of you: which version it is at, what each step changed, and which sources each step sends back through the parser.

It is generated rather than maintained separately so the entry point, recovery sequence and migration registry cannot drift apart. `validate_database()` raises `migration_runbook_stale` if the generated file falls behind.

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

### Classifying what is already there

Twenty-six copies predating the convention had names like `pre30b_194844.duckdb`, matched no class, and were reported and ignored — 9.5 GiB the script could see and not understand. What they are cannot be read from their names, but it can be read from inside them: every DuckDB file states the schema version it was left at.

```
Rscript prune_backups.R --classify            # read each one, propose names, rename nothing
Rscript prune_backups.R --classify --apply    # rename
```

It opens each unrecognised file read-only and names it for what it contains. **The earliest copy at each schema version is that step's migration evidence and is kept; a second or fifth copy at the same version is a working snapshot from one session and ages out** — five of them were schema 29 alone. `outputs/backup_inventory.csv` records the mapping. Nothing is deleted, and `--classify --apply` renames only; deletion is the separate `--apply` below.

### Retaining and pruning copies

Compaction reclaims free space *inside* the live file. What dominated `database/` was everything beside it: 34 files and 13 GB in eight days, because every compaction wrote a full pre-compaction copy and nothing ever removed one. Since schema 33 an accepted build also leaves the database it replaced, so the accumulation is faster, not slower — and both leftovers are worth keeping, for a while.

The retention rule reads the filename:

| Prefix | Written by | Rule |
|---|---|---|
| `paraguay_macro_pilot_pre_swap_` | an accepted build, before the swap | rolling |
| `paraguay_macro_pilot_pre_compaction_` | `compact_database.R` | rolling |
| `blocked_` (in `database/candidates/`) | a build that did not pass its gates | rolling |
| `paraguay_macro_pilot_pre_migration_schema<N>_` | a schema step that re-ingests sources | **kept** |
| `paraguay_macro_pilot_milestone_<label>` | you, deliberately | **kept** |
| anything else | — | **reported, never touched** |

```
Rscript prune_backups.R            # says what it would delete, deletes nothing
Rscript prune_backups.R --apply
Rscript prune_backups.R --keep=5 --apply
```

**It is dry-run by default and the pipeline never calls it.** A rule that deletes databases as a side effect of a build is one that will eventually delete the copy you needed, and the pre-swap backup exists precisely for the runs where something has gone wrong. Deleting a database is an operator's act.

The 26 hand-named copies already in `database/backups/` — `pre_schema29_212127.duckdb` and the rest — match no class and are reported rather than deleted. Rename one to `paraguay_macro_pilot_pre_migration_schema29_...` to have it kept deliberately, or remove it by hand.

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

### `blocked_release_visible`

An error, and read the detail: it covers three different failures.

**"declare no public_scope"** — a view was added without a row in `config/public_view_contract.csv`. Add one saying what it is for, with your name. This is the common case and takes a minute.

**"do not descend from a filtered base relation"** — a view declared `current` neither carries the release boundary nor reads anything that does. Either point it at a filtered relation, or, if it filters in its own body, set `carries_release_boundary` to `TRUE` in the register.

**"observation(s) are visible … whose vintage belongs to no accepted release"** — the row test failed, which means data really is leaking. Do not publish.

### `release_transaction_left_open`

An error, and a bug in the pipeline rather than in the data. A phase opened a transaction and did not close it, and the release reached the fresh-connection interface check with it still open. The check is skipped deliberately: a second connection to a DuckDB file whose writer holds a transaction **waits** rather than failing, so running it would hang the release with nothing to read. Find the phase; every transaction in the project goes through `project_begin_transaction()` / `with_project_transaction()`, so a bare `DBI::dbBegin()` is the first thing to look for.

### `projections_in_realized_view`

An error. `v_series_latest` is contracted to hold realized observations only, and an observation dated after the vintage that published it reached it. Either the filter was removed or a publication date moved. `v_publisher_statement_latest` is where a published projection belongs.

### `report_disagrees_with_database`

A generated `*_latest.csv` does not match the database beside it — almost always because a check now runs after the report is written. Move the report write later; a file that looks authoritative and is stale misleads more than no file.

### `canonical_membership_incomparable`

A declared canonical alias differs from its primary in unit, scale or frequency, or shares no period with it and has therefore never actually been tested against it. Declaring a membership asserts the members are the same economic quantity; fix the declaration or the metadata before publishing.

### `direct_panel_in_aggregate_mart`

A mart reads a bank or finance-company panel while 411 groups of rows in those panels repeat every dimension the database models. Aggregating them double-counts by an amount nobody can bound. See `outputs/direct_panel_duplicate_keys.csv`; the missing dimension has to come from the publisher's documentation.

### `manifest_selection_unresolved`

Two or more candidate files sit in one source folder and none matches a recorded SHA-256. Remove the file you are replacing, or record the intended one's hash in `config/source_vintages.csv`. Since schema 32 this stops the run instead of guessing by modification time.

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

Sort `outputs/ingestion_stage_timings_latest.csv` by `elapsed_seconds`. `source_discovery_and_metadata` isolates workbook/XML inventory, `ingestion_and_curation` includes the single-pass sheet read plus raw/semantic persistence, and `source_validation` isolates guards. Rows with no `source_id` are the release-wide phases — reconciliation, region classification, the expected grid, missingness, semantics, canonical, marts and validation — which are timed since schema 29; `observation_missingness` used to be the slowest of them by a wide margin and since schema 32 is skipped entirely when the stored expected grid carries the same `build_id` as this run — 19s to 0.03s on a build where nothing changed. If it is taking 19 seconds, something in the code, configuration, environment or sources *did* change, which is the answer to why the run is slow rather than a problem with it. Timings are keyed by `attempt_id` and appended, so compare the current attempt against the previous ones rather than against a remembered number. If an unchanged file is fully curated, check `source_files.ingestion_status`: completed content-identical vintages should take the `reuse_and_validation` path. Do not delete the DuckDB database for routine monthly updates, because that deliberately forces a full rebuild.

## Acceptance checklist

- Run status is not `release_blocked`, and **`audit.active_data_release` names this build**. A blocked run leaves the previous build published; that is correct behaviour, and it also means "the database still works" is not evidence that this run succeeded. Check the pointer, not the views.
- `outputs/quality_flags_latest.csv` row count equals `audit.quality_flags` for this attempt. The release checks this itself, but it is the file you are about to read.
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
