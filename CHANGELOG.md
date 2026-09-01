# Changelog

## v32

Sixth technical audit, roadmap item P2. Changes no observation.

- **Grain is declared per worksheet as well as per source.** One grain for a whole workbook was too
  coarse, and direct investment is the case: the source is `scalar_series` and its `Cuadro 5` and
  `Cuadro 7` are foreign direct investment stocks by country — 73 and 34 country series, an entity
  panel wearing a scalar catalogue's clothes. `config/source_grains.csv` is now keyed
  `(source_id, source_sheet)` with `*` as the source-level rule. 214 identifiers left the macro
  catalogue, which holds **7,229**.
- **Workbook provenance per observation.** `marts.v_observation_source_behaviour` exposes
  `from_hidden_row` and `sheet_formula_cells` beside each value's coordinate. Recording them per
  worksheet was right for the drift test and wrong for a researcher holding a number: "15,403
  observations come from hidden rows" is a fact about the database, and "is *this* value one of them"
  was a question you could only answer by unpacking a packed range yourself. Derived, not stored.
- **Every source selects by recorded hash.** All 22 move from `newest_mtime` to `manifest`. The
  failure mode changes and it is worth knowing: with one candidate file the rule never fires, and
  with two the run now **stops** and names the fix where it used to pick the newer modification time
  and warn. Modification time is when a file reached this disk, not when the publisher released it.
- **The database is a recorded distribution artifact.** `audit.distribution_artifacts` gives the
  `.duckdb` file an identity, so the commit carrying a rebuilt database — necessarily later than the
  build that produced it — stops reading as a provenance mismatch.
- **The dominant phase is skipped when it cannot produce a different answer.** Rebuilding a
  2.4-million-row expected grid took 19 of the 36 seconds of a reuse build. It is skipped when the
  stored grid carries this same `build_id` — a stronger guard than "did any source change", because
  `build_id` hashes the code and configuration too, so editing the missingness logic forces a full
  rebuild. **19.08s → 0.03s**, with an identical 20,647 rows.

Three defects in v30's own work, found while verifying this round rather than by the audit:

- **The supported read interface bypassed the release boundary entirely.** `series_as_of()` in
  `scripts/05_query_helpers.R` — the file the operations manual calls the supported read path —
  ranked `canonical.fact_series_events` directly, with no release filter and no observation status.
  Neither the lint nor the new public-view contract was looking at it, because both reason about
  *stored objects* and this is an R function: the same class of gap as R6-01, one layer further out.
  It also answered a different question from the stored macro of the same name, ranking by
  publication date where `series_as_of_date()` ranks by `available_at`. It now delegates to the
  macro, and a test asserts the whole helper file reads only published surfaces.
- **A bare `DBI::dbBegin()` could abort the transaction it was inside.** The per-source ingestion
  opens its transaction explicitly, across a `tryCatch` boundary, and did not register it — so the
  first unit inside that asked for a transaction tried to open a second, and in DuckDB that failed
  `BEGIN` aborts the transaction it was asking about. Only a full ingest takes that path, which is
  why it took building a database from the real workbooks to find. Every transaction now goes
  through the register.
- **The fresh-connection check could hang instead of failing.** A second connection to a DuckDB file
  whose writer holds an open transaction waits rather than erroring, so a leaked transaction turned a
  release into a deadlock with nothing to read. It is now reported as
  `release_transaction_left_open` and the check is skipped: diagnosis beats deadlock.

## v31

Sixth technical audit, roadmap item P1. Changes no observation.

- **"Latest" files describe the latest run.** The flag CSV held 33 rows where the database held 35,
  because it was written at the end of validation and the gap and discontinuity screens run after
  validation. The update report, headed "this update", carried 696 timing rows from eight attempts
  that shared a source bundle — the same stage over and over with durations from runs that were not
  this one; it now carries the 56 this attempt measured. Flags are attributed to the attempt that
  raised them and are no longer deleted by `release_id`, so re-running a bundle stops destroying the
  accepted build's diagnostic evidence. The release compares each generated file against the
  database beside it.
- **The availability documentation was overstated, and it was ours.** `docs/DATA_MODEL.md` said
  `available_at` "is never inferred from the reference period". True of the operator-recorded field,
  false of the column: 12 of 22 publication dates derive from the content maximum, and `available_at`
  falls back to the publication date. The section now states the fallback chain, that
  `series_as_of_date('2020-12-31')` returns zero rows, and that no real-time claim should be made
  from this database until provenance is recorded.
- **Queues someone can pick up.** `outputs/source_provenance_worklist.csv` names per vintage which
  acquisition fields are missing and what each costs, separating `available_at` — on which every
  point-in-time claim depends — from the four that only affect re-acquisition.
  `outputs/source_region_review_queue.csv` ranks the 6,522 unreviewed cells by the economic weight of
  the worksheet rather than by cell count: sorted by volume the LRM auction year-sheets come first,
  and nobody should review those before the price index.
- **Two gates that pass vacuously, which is why they are written now.** A declared canonical
  membership must be *comparable* as well as equal — aliases differing in unit, scale or frequency,
  and aliases sharing no period with their primary and therefore never actually tested, block the
  release. And a direct publisher panel reaching an aggregate mart blocks the release while 411
  groups of rows repeat every dimension the database models.

## v30

Sixth technical audit, roadmap item P0. **Contains a breaking change to a published interface.**

- **Publication is a pointer at an immutable decision, not a status on the source bundle.** A
  `release_id` hashes the source files, so fourteen attempts across schemas 26–29 shared one, and the
  single attempt among them that ended blocked set that shared row to `blocked`. Every published view
  joined `releases.status = 'accepted'` — so **a failed rebuild withdrew the entire published
  database**, not the data it produced but the data it failed to replace. `audit.data_releases` now
  records one decision per product, inserted once and never rewritten;
  `audit.active_data_release` is a one-row pointer only an accepted build moves.
- **The release-wide phases run as one transaction.** Without it the pointer is theatre: a build that
  died halfway had already half-rebuilt reconciliation, semantics, the expected grid and missingness
  underneath a release still marked accepted. This needed a nesting-aware transaction helper, since
  eight phases open their own and DuckDB has no nested transactions — and detecting the outer one by
  attempting a `BEGIN` does not work, because the failed probe aborts the transaction it is probing.
  **What this does not give:** facts are not versioned per build, so a past product cannot be
  reconstructed from the database. Only the decisions are preserved.
- **Every published object declares what it is for.** The release lint has been rebuilt twice and the
  audit found the deeper problem: a rule over *names* cannot decide which objects are research
  interfaces, and a test for the word `releases` cannot decide whether one filters.
  `v_series_observations` read the whole fact table and `LEFT JOIN`ed accepted releases only to
  populate a label — the body contained the word, so the lint passed it, and passed the projections
  built on it, and the canonical views built on those. `v_fx_operations_annual` and
  `v_series_catalogue` matched no naming rule, and neither did 35 other public objects.
  `config/public_view_contract.csv` declares scope per object; an undeclared object blocks the
  release; and filtering is decided by descent to a declared boundary-carrying relation, never
  through an `_all` twin.
- **Breaking: `v_series_latest` is realized observations only.** Schema 27 kept the 343 projections
  there and exposed `observation_status` beside them. The reasoning was sound and the naming was not:
  it is the obvious default, and a researcher who never reads the column gets 2028 forecasts in an
  estimation sample. The publisher's full current statement is `v_publisher_statement_latest`;
  `v_series_latest_observed` remains as an alias; a projection reaching the realized view is now an
  **error**.
- **The projection fan-out**, the same `DISTINCT`-sheet join found and fixed in the grain catalogues
  one schema earlier and missed in this copy. And the expected grid and missingness carry the vintage
  and build they were computed from, so a diagnostic published in a mart can be release-filtered
  instead of matching on `series_id` and hoping.
- The acceptance test is adversarial, not the lint: `test-audit6-release-isolation.R` builds a
  database that genuinely holds a vintage nobody may see, asks every `current` interface for it, and
  asserts the `_all` twins *do* return it so the test cannot pass vacuously.

## v29

Fifth technical audit, roadmap item P2. Changes no observation.

- **A catalogue per series grain.** `marts.v_catalogue_scalar_series`, `v_catalogue_event`,
  `v_catalogue_curve_panel` and `v_catalogue_entity_panel`. `series_grain` already classified them and
  `v_catalogue_by_grain` already counted them, but a single undifferentiated catalogue is still what a
  reader opens, and it said this database holds thousands of macroeconomic series when 3,083 of those
  identifiers are one LRM auction tender each and 1,287 are one curve node.
- **Cached formulas and hidden rows are recorded per worksheet.** `raw.source_sheets` gains
  `formula_cells`, `hidden_rows` and `hidden_columns`. Neither survives into any value the parser
  reads, and both change what a number means: `readxl` cannot calculate, so every number here is a
  cached result, and a hidden row is one the publisher's own reader does not see. The current release
  holds 91,673 formula cells across 104 worksheets, and **15,403 published observations across 13
  worksheets come from rows the publisher hid** — mostly the annex collapsing the early history of a
  long table, which is benign, and none of which was visible before. `workbook_behaviour_changed`
  reports drift in either between vintages; `outputs/workbook_behaviour_latest.csv` carries the state.
- **No source was re-ingested to get them.** Both are properties of the workbook rather than of a
  parsed value, so every already-archived vintage was filled in from its own archived file. The
  backfill is idempotent and covers all 284 worksheets across all 22 sources.
- **Stage timings are per attempt and append-only.** `audit.ingestion_stage_timings` is keyed by
  `attempt_id` and no longer deleted per release, and the release-wide phases — reconciliation, region
  classification, the expected grid, missingness, semantics, canonical, marts, validation — are timed
  rather than only the per-source parsing. `observation_missingness` at 21s is the slowest phase in the
  run, which was not previously measurable.
- **Build dirtiness answers the question it is asked.** Every `build_identity` row recorded
  `git_dirty = TRUE`, and committing the tree did not change it. `git_build_state()` runs from inside
  the pipeline, by which time the run has written to the tracked `.duckdb`, so the file the build was
  producing counted as an uncommitted change against the build producing it — unsatisfiable by
  construction. The database is excluded and nothing else is, and a git call that fails is now `NA`
  rather than `FALSE`: a dirtiness check that fails open is worse than the one it replaced.
- Documentation: the README is titled for the schema it describes rather than v11, states what
  `latest`, `as-of` and `validated` each guarantee, and corrects the claim that bank and
  finance-company panels carry no row number. `docs/DATA_MODEL.md` and `docs/OPERATIONS.md` follow.

## v28

Fifth technical audit, roadmap item P1. Changes no observation.

- **An accepted release survives its own rebuild.** `stage_release()` used to delete and re-insert, so
  re-running a bundle set an already-accepted release back to `staged` and un-published the database
  for the duration of the run. It now leaves a decided release alone; promotion is one terminal
  `UPDATE`.
- **An attempt is recorded when it starts.** The `ingestion_run_attempts` row was written at the end,
  which meant the one case where the record mattered — a run that crashed — was the one case that left
  nothing. It is now opened with status `running` and closed from an `on.exit()` handler.
- **An identity component that is absent is no longer read as zero.** `validate_published_identities()`
  used `coalesce(component, 0)`, so a period publishing the total and half the parts could pass by
  arithmetic accident. Presence is now checked first and reported separately as
  `published_identity_incomplete` (warning); `published_identity_broken` (error) means the components
  are all there and do not add up. Five identities have periods where the publisher gives a total
  without every component.
- **`source_files.release_id` is `first_ingested_release_id`.** It records the bundle a vintage arrived
  in, which is not the release a query is reading; that is derived through `release_sources`.
  `v_series_observations` carries both.
- **Operator-recorded availability.** `available_at` in `raw.source_provenance` outranks the date
  derived from the file when `series_as_of_date()` ranks vintages. It ships `pending`; the values are
  the operator's to supply.
- **A research-eligibility gate.** A series may not enter a validated mart without unit, scale,
  frequency, stock/flow, nominal/real and seasonal adjustment, with `not_reviewed` not counting. It
  passes vacuously because nothing is promoted — which is why it is written now rather than after the
  first promotion.
- **Duplicate evidence, not duplicate decisions.** `outputs/duplicate_series_candidates.csv` screens
  for series agreeing period-for-period by md5 signature, and
  `validate_canonical_membership_agreement()` blocks a release in which a declared alias disagrees with
  its primary. `config/canonical_series.csv` stays empty: declaring one canonical series means
  asserting seven economic properties under a named reviewer, and that is economic review, not
  automation. The evidence is ranked and waiting.

## v27

Fifth technical audit, roadmap item P0.

- **One accepted-release boundary, on every published interface.** Thirty-four views carried no release
  join: all seventeen `v_latest_raw_*` direct panels, the whole documented family, and both market
  views, which tested `ingestion_status = 'completed'` — a fact about whether a file loaded, not about
  whether it may be published. The filter now sits inside each ranking subquery, so a view returns the
  newest vintage a researcher may see rather than nothing while a newer one is staged, and every
  filtered view has an unfiltered `_all` twin for diagnostics. The lint requiring the join follows view
  dependencies transitively instead of reading a hard-coded list.
- **A unit stated in a table title outranks a keyword in a row label.** `CUADRO 20` is titled *"En
  millones de dólares"*, and twelve of its thirty series carried `unit_code = COUNT` with
  `scale_multiplier = 1` because their row label contains *operaciones* — `value_in_base_units` wrong
  by 10⁶ on twelve foreign-exchange series, each of which matches a dedicated `fx_operations` series to
  floating precision over 379 monthly observations. The guard that already existed for *saldos* now
  covers any title stating a monetary magnitude, on the `count` and `days` branches alike. 16 series
  and 5,942 observations change unit; no value changes.
- **What the publisher writes instead of a number is read, not discarded.** 18,416 of the 20,156
  `blank_in_source` rows sat on cells holding the text `s/m` — *sin movimiento*, no transactions — and
  the classifier tested only whether a number had parsed. `config/source_value_tokens.csv` registers
  tokens with a status, quoted evidence and a **named** reviewer (`layout_verified` is rejected: what a
  publisher means is not a layout claim). Missingness is now classified on the cell's text, and an
  unregistered token becomes `source_token_unreviewed`, which blocks promotion rather than passing as a
  blank.
- **A published projection is distinguishable from an outcome.** 343 observations across 186 series are
  dated after the vintage that published them. `v_series_latest` and `series_as_of_date()` now expose
  `observation_status`; `v_series_latest_observed` and `marts.v_series_projections` split them.
  **The default keeps the projections, on the operator's instruction** — they are what the publisher
  published — so it is not a look-ahead-safe default, and `current_view_contains_projections` reports
  the count every release.
- **The unread data regions are parsed.** The direct-investment stock tables `Cuadro 5` and `Cuadro 7`
  publish a year-quarter header across two rows; the parser read one and lost 12,006 cells. It now
  reads both, guarded by the publisher's own arithmetic — the fourth quarter of a block must equal the
  annual column that closes it — so a workbook that changes shape fails loudly rather than shifting
  every period by a year. The annex horizontal axis stopped at the column carrying the last period's
  label rather than at the end of its block, losing 256 cells on `Cuadro 52a`/`52b`. **`data_not_ingested`
  falls from 12,371 cells to zero**, and the four rules recording that loss are retired with the
  defects.
- **Direct panels have a grain.** Each row records `source_row`, the physical worksheet row, and each
  panel declares `(vintage_id, source_sheet, source_row)` as a natural key enforced by a unique index —
  which makes the 399 duplicate dimensional keys in `raw_banks_canales_person` representable instead of
  ambiguous, and reported in `outputs/direct_panel_duplicate_keys.csv` rather than guessed at.
  `codigo_entidad` and `codigo_moneda` are stored as text: they are labels, not quantities, and the
  reference joins no longer depend on a `TRY_CAST` round-trip.

## v26

Fourth technical audit, roadmap item P2. Changes no observation.

- **The environment is recorded.** `renv.lock` pins R 4.5.1 and 61 packages. It was written with
  `renv::snapshot()` over the already-verified library rather than `renv::init()`, so renv is not
  activated through `.Rprofile` and no open session in the directory has its library path changed
  underneath it; `renv::restore()` stays a deliberate act.
- **`run_tests.R` no longer installs anything.** It used to source the installer first, so running
  the tests could change the environment being tested — which is also what made the suite unsafe in
  CI or during an audit. It now calls `check_environment()`, which reports drift against `renv.lock`
  and, in strict mode, stops. It does not install.
- **`audit.build_identity`** records the Git commit and dirty flag, schema version, digests of
  `config/`, of `scripts/` and `run_update.R`, and of `renv.lock`, plus the R version. `release_id`
  keeps meaning "these input files"; `build_id` means "this database".
- **`audit.ingestion_run_attempts`** is appended and never rewritten, so re-running a bundle no
  longer erases the record of what happened the previous times.
- **Staging natural keys are enforced.** A unique index on each of the seven snapshots, plus
  `validate_declared_natural_keys()` asserting both the key and the table's required fields at every
  release. The tables were not rebuilt to gain a `PRIMARY KEY`: DuckDB cannot add one to a populated
  table without recreating it, and recreating six snapshots along with every dependent view is a
  large risk for a small gain — the index covers uniqueness and the assertion covers nullability,
  which is the alternative the audit itself offers.
- **`selection_rule = 'manifest'`** picks a source file by the SHA-256 recorded in
  `config/source_vintages.csv`. `newest_mtime` still works and now says in its warning what it
  actually does: modification time is when the file reached this disk, not when it was published.
- Documentation: `README.md` and `docs/OPERATIONS.md` drop `completed_with_errors` and explain what a
  blocked release means for the research views; the README's provenance claim is narrowed to what
  each source family actually carries; `docs/VERIFICATION.md` describes the current executable
  environment instead of asserting that R is unavailable; and `revisiones/README.md` says which notes
  are historical record, with a banner on each superseded one.

## v25

Fourth technical audit, roadmap item P1, less the parts that need a human. Changes no observation.

- **Source acquisition provenance.** `config/source_vintages.csv` is loaded into
  `raw.source_provenance`, joined on `(source_id, sha256)` rather than on the filename — the one
  thing the publisher changes freely. The gate is a warning while a source is provisional and an
  error once a worksheet of that source is claimed `validated`, because a research product nobody can
  re-acquire is not reproducible. All 22 vintages currently read `pending`, and the warning lists
  them.
- **Absence now has a reason.** The parsers skip `NA`, so a period the publisher never reported and a
  period the parser failed to read were the same missing row. `staging.expected_observation_grid` is
  the regular sequence each series' declared frequency implies, bounded by its own first and last
  period; `staging.observation_missingness` classifies every gap against the raw cell layer.
  **20,156 `blank_in_source`, 491 `period_absent_from_axis`, nothing unread and nothing ambiguous** —
  which answers the 18,448 financial-indicator gaps the audit reported: the cells are in the workbook
  and hold no number. The invariant `grid = observed + explained` holds exactly (267,830 = 247,183 +
  20,647).
- Three corrections were needed to get there, all of which manufactured gaps that do not exist: a
  `summarise()` that resolved a later `.data$source_row` to the column the same call had just
  created (which discarded 18,448 real gaps); the exchange-rate histories reusing one column across
  disjoint year blocks, so the months in between resolve to cells that *were* read, as a different
  series (2,090 on EURO Prom); and periods a worksheet places at several coordinates, where taking
  the first named a cell in another block.
- **Publisher-stated identities are checked.** `config/aggregate_identities.csv` carries only
  identities the source itself states, expressed over worksheet columns because a parser repair moves
  labels and never moves columns. All five hold on every published period, including the interbank
  `Mercado Interbancario de Fondos = CMM + REPO Interbancario + REPO Tripartito` across 3,287 trading
  days — which is independent corroboration of the Call Money block schema 24 recovered.
- **The two-vintage path is exercised end to end**: revision recorded with previous and new value,
  tombstone for the withdrawn series, `series_as_of_date()` returning 100 in March and 107 in June,
  and the release barrier withdrawing both vintages when the release is blocked. What remains
  undemonstrated, and is said so, is that a real BCP revision behaves this way.
- **No economic review is written.** `outputs/semantic_review_worklist.csv` ranks the 13,927 series
  with an open measurement field by weight, so a reviewer can start where it matters.

## v24

Fourth technical audit, roadmap item P0. See `revisiones/REVISION_AUDITORIA_4_P0_P1_P2.md` for the
verification record. Every figure in the audit was re-measured read-only against the live database
before any code changed; all of them reproduced.

- **One authoritative publication date per vintage.** The audit found 422 `compensatory_fx_sales`
  facts saying 2026-12-31 while `raw.source_files` said 2026-07-31. Two defects, not one.
  `set_source_publication_date()` refused to overwrite a date it had already derived, so a
  content-derived date could never be corrected once the parser read more of the sheet; and the
  content maximum is not a publication date when the sheet is a template for the whole calendar
  year. Authority now decides — `official_registry` > `filename` > `content_max_period` — and
  `propagate_vintage_publication_date()` copies the settled date from `source_files` onto every
  table that carries the pair, discovered from the catalogue rather than from a list. **Zero
  disagreements** between `source_files`, the snapshots, 1.2 million facts and the archive
  manifest, enforced by `fact_publication_date_mismatch`.
- The compensatory-FX template tail is no longer read as data. Agosto to Diciembre 2026 have both
  components empty and a cached zero from the sheet's own `=+G+H`; the source goes from 422 to 417
  facts and its availability from 2026-12-31 back to 2026-07-31. A published zero total between two
  reported months, which is what the schema-23 repair exists for, is still read.
- New warning `publication_date_source_contradicts_content` immediately found a second case the
  audit had not seen: `fx_operations` records 2026-07-31 as its content maximum while the content
  reaches 2026-12-31.
- **A release is a lifecycle, not a status string.** `audit.releases` moves `staged` →
  `accepted` | `blocked`, and `v_series_latest`, `series_as_of_date()`, every mart and
  `v_research_series` join through it in SQL. Accepting or blocking is one atomic `UPDATE` and no
  view is rebuilt. Verified: blocking the release takes `v_series_latest` from 1,214,830 rows to 0
  and `series_as_of_date()` from 1,212,070 to 0, while `v_series_latest_all` keeps both for
  diagnostics. `blocked_release_visible` checks the rows *and* lints the stored SQL, because a view
  rewritten without the join would pass every row test.
- **Worksheet merge ranges are retained as published provenance** in `raw.source_sheets`, and they
  settle the SIPAP_12 question the schema-23 note called undecidable. `mergeCell ref="Q2:R2"` says
  columns 17 and 18 are one block; `CUADRO 35` column 12 is in no merge and stays out of scope. The
  published footnote confirms the reading: the five component *Cantidad* columns sum to the
  published TOTAL SPI of 63,735,362 and the five *Importe Destino* columns to 21,232,517,839,313,
  both exactly.
- **The column-recovery window is the published header span.** It used to run only between the
  first and last confident data column, so a headed block outside that span was never examined in
  either direction. The interbank sheets lost three: Call Money Market (PYG) before the first, and
  the Call Money USD *Plazo* and the whole *Facilidad de Crédito Especial* block after the last.
  **647 cells recovered across 113 worksheets, none lost.**
- **Numeric cells outside every parser region are now classified.** `audit.source_region_
  classification` is built from the raw cell layer independently of what the parser emitted, over
  every documented worksheet rather than only those that produced observations. Of the audit's
  73,830 cells: 46,745 `period_axis`, 6,706 `report_layout_derived`, 12,371 `data_not_ingested` and
  7,695 `unreviewed`. The last two block promotion to `validated`; neither blocks the release.
- **A material defect the audit could not see.** Building that register exposed
  `direct_investment`. Cuadro 5 and Cuadro 7 put the year and its four quarters on one header row;
  the year-quarter parser looked for the quarters only *below* the year row, found none, and
  `which.max` over a vector of zeros handed it the first data row as the period header. ALEMANIA's
  1995 balance became a header, all 105 rows across the two sheets were labelled with their own
  values and stamped 2024-12-31 in the single surviving column, and 12,006 published cells were
  never read. The 105 corrupted rows are removed. The 12,006 are recorded as `data_not_ingested`
  rather than recovered: row 10 names the year of each quarter block and row 11 names the year of
  the annual column that closes it, so reading the quarters off row 11 alone dates every one of
  them a year early.

## v23

Third technical audit, roadmap items P0, P1 and P2. See
`revisiones/REVISION_AUDITORIA_3_P0_P1_P2.md` for the verification record.

Delivered across schema 22 and 23. Every audit figure was re-verified read-only before any
code changed; all of them matched. One diagnosis was right about the symptom and wrong about
the cause, and is recorded rather than worked around.

- **The published interface works again.** Schema 21 moved every table into a storage layer
  while every stored view and macro still named its dependencies bare, so 74 of 74 views and
  all 3 macros raised `Catalog Error: Table with name dim_series does not exist` from any
  connection this project did not open itself -- including `scripts/05_query_helpers.R`, the
  read API the documentation tells researchers to use. Every object is now written through
  `create_project_view()`/`create_project_macro()`. **74 of 74 views and 3 of 3 macros execute
  from a default connection.** They also survive being `ATTACH`ed under an alias, which bare
  `main.` references did not.
- Two release-blocking gates so it cannot recur: `unqualified_object_dependency` reads the
  stored SQL back out of the database and rejects a bare reference; `fresh_connection_object_
  failed` opens a second connection with nothing configured and executes everything. Both run
  in `compact_database.R` before the swap and in `prepare_distribution.R` before a copy ships.
- **Found three more instances of the same defect.** `initialize_database()` asked
  `dbExistsTable("schema_version")` before setting a search path, concluded the database was
  empty and had been **skipping every source-reingesting migration since schema 21**;
  `build_migration_map.R` passed the literal `"main"` as a catalogue name DuckDB calls
  `paraguay_macro_pilot` and could not run at all; and eighteen views owned by a source were
  never rewritten because they are created only during ingestion.
- **Repaired 696 of the 697 recorded parser defects.** The density floor was the common cause:
  a column is now admitted on the header the publisher printed for it rather than on how busy
  it is. That recovers the whole interbank REPO Tripartito block (551 cells, an instrument
  trading on 95 of 3,653 days), the participant that reported once on CCC 02, and the column
  opened in the final month on SIPAP_12. Continuation rows become events with the trade date
  inherited and a positional operation sequence (54 cells); CUADRO 11's compound interval
  labels resolve to effective-dated periods (83); the compensatory-FX block tests activity
  over the columns it actually reads (5). Reconciliation: **241 balanced, 1 unread cell.**
- The audit reported all 605 interbank cells as continuation rows. 551 of them are a published
  instrument block no parser region reached, which no amount of event modelling would have
  recovered. Both causes are repaired; the discrepancy is recorded.
- SIPAP_12 column 18 is **not** repaired: it has no published header of its own, and admitting
  it on a neighbour's inherited label is indistinguishable from CUADRO 35 column 12, which a
  reviewer classified out of scope. One cell, an accurate reason, and the review left standing.
- `canonical.series_period_bounds` stores the opening date of an irregular published interval
  for the 83 observations that have one. The 1.2M fact rows and their key are untouched.
- **Financial-indicator semantics.** Sheets 4 and 7 publish balances and the rest publish
  interest rates over the same portfolio taxonomy, which is why 464 labels recurred. A
  `measure` dimension derived from the published table name now separates them (847 rate, 188
  outstanding amount), and two unit bugs are fixed: a "Volver al índice" navigation link was
  read as the word `indice` on 146 series, and a product name in a row label outranked a unit
  the publisher stated in the title on 363 more. **Rate-labelled series with a non-rate unit:
  0, from 432.** A new `semantic_contradiction` gate holds the line. Labels and identifiers are
  unchanged; the migration map records 84 new identifiers and **zero retired**.
- `governance_note_stale_count` checks numbers written into status notes against the live
  metric they name, which is how "1,636 positional-lane series" survived on a source whose
  count is zero. The prose stays free; only a number followed by a known claim phrase is read.
- `continuity_map` had a table, a storage assignment and a release gate, and **no writer**.
  `apply_continuity_decisions()` and `config/continuity_decisions.csv` now exist. The canonical
  registers still ship empty; `outputs/canonical_core_candidates.csv` generates the candidate
  list a reviewer needs, and `revisiones/CANONICAL_CORE_PROPOSAL.md` records the decisions.
- Golden fixtures for **5,034 recovered cells and 1,089 period corrections**, cut by physical
  source-cell comparison and verified back against the raw cell layer. Zero cells the baseline
  read have stopped being read.
- `source_region_incomplete` reports the 73,830 published numeric cells that sit outside every
  parser region -- `balanced` speaks only for cells inside it. Reported, not gated.
- `prepare_distribution.R` ships a copy with workstation paths removed and portable URIs and
  hashes verified. `docs/OPERATIONS.md` gains the client interface, the storage layers, the
  mart split and the defect-state policy.

## v21

Second technical audit, roadmap items P0, P1 and P2. See
`revisiones/REVISION_AUDITORIA_2_P0_P1_P2.md` for the verification record.

Delivered across schema 15-21. Every audit figure was re-verified read-only before any code
changed; all of them matched. Two of the audit's diagnoses were right about the symptom and
wrong about the cause, and both are recorded rather than worked around.

- Reconciliation resolves the residual cell by cell. `config/reconciliation_cell_rules.csv`
  maps coordinate rectangles to a classification with the worksheet evidence quoted and a
  named reviewer; `reconciliation_cell_classification` records which rule explained which
  cell. A cell matching no rule now blocks the release. Result: 0 unclassified cells across
  all 242 worksheets, and 697 cells of still-unread published data named, documented and
  blocking on 5 of them.
- Fixed the reconciliation's own coordinate bug. `report_cell_values` stores each worksheet
  cropped to its used range; the parsers record A1 coordinates. Joining them untranslated
  reported 13,041 phantom unexplained cells -- most of the audit's 18,883. `v_report_cells_a1`
  is now the only correct way to join the layers.
- Repaired five parser defect families the classification exposed, recovering **4,338
  observations**: footnote-marked month labels (CUADRO 59 +480, CUADRO 55 +229), late-starting
  data columns (CUADRO 17, SIPAP_04), the month-year spellings `mar.-19`, `sept-25` and
  `dic- 19*`, and text day-month-year labels (bcp_fx_daily +108). The `sept` spelling had also
  been mis-dating 867 `financial_indicators` observations by a month and forking them onto
  1,636 positional lanes; both are gone.
- Split the marts. `v_mart_<x>_all` carries the data; `v_mart_<x>` carries only validated,
  reconciled rows and all seven are empty. Fixed the tautological `d.source_sheet =
  d.source_sheet` join, added `vintage_id` to the reconciliation join, applied exact-over-
  wildcard status precedence, and rebuilt `v_research_series` as one row per series.
- Added `parser_claim` to `table_status` and `validate_governance_drift()`, which checks the
  claim against this release's reconciliation in both directions. Corrected the eight stale
  Annex notes. A database CHECK now enforces reviewer, date and evidence on a validated row.
- Made identity resolution fail closed: `v_series_id_scalar_resolution`, `resolve_series_id()`
  and `resolve_series_ids()`. All 36 one-to-many and 15,096 retired identifiers resolve to
  NULL; canonical membership refuses an ambiguous identifier.
- Added `series_semantic_evidence`: `stock_flow`, `valuation`, `transformation`,
  `nominal_real` and `seasonal_adjustment` are derived only where the publisher states the
  answer in words, and `v_series_measurement` publishes the basis beside every field. 1,822
  fields have a value, none of them claiming review.
- Added `series_dimension`: `trade_flow`, `trade_classification`, `trade_regime` and `product`
  for the eight detailed trade worksheets, derived from the published title and label. The
  eight sheets moved from `needs_remodeling` to `provisional`.
- Strengthened compaction from row counts to content equivalence: every table as a multiset in
  both directions with `EXCEPT ALL`, plus column definitions, view SQL, constraints, indexes,
  sequences and macros. `docs/SCHEMA_MIGRATIONS.md` is now generated from the migration
  registry the invalidation steps read, so the runbook cannot drift from the database again.
- Moved every table into a storage layer -- `raw`, `staging`, `canonical`, `audit` -- and
  published the research interface under `marts`. Nothing remains in `main`. A search path set
  on every connection keeps unqualified names resolving.
- Moved the fact grain onto BIGINT surrogate keys, keeping the human identifiers on the row
  and unique in the dimensions. The compacted database is **243.3 MiB, down from 309.7 MiB**
  with 4,338 more observations in it.
- Added repository-relative `source_uri` and `archive_uri`; the 22 absolute `/Users/...` paths
  are no longer the durable identity of anything.

Not delivered, and reported as blocked: the canonical and methodology registers (they require
a named economist), the remaining 3,946 unresolved units (the sources do not state them), the
interbank event grain (it needs a modelling decision), and a second real vintage (no newer BCP
publication exists).

## v14

P1 and P2 of the external technical audit. See `revisiones/REVISION_AUDITORIA_P0_P1_P2.md`
for the verification record and `AUDITORIA_REGRESIONES.md` R45 for the trade-sheet detail.

- Bounded the horizontal period axis at the last header cell that parses as a period. The fill-right loop ran to the last column of the worksheet, so the seven interannual comparison columns on each foreign-trade sheet inherited the last real period; 6,962 spurious observations, all dated 2026-07-01, are gone and no real value moved.
- Kept bare provisional-data markers out of series identity. A `*` published over the most recent 24 months was read as a sub-header and cut every product series in two at 2024-08; 22,228 marker-suffixed labels became 0 and `Soja` is one series again. The marker is retained on the observation in `footnote_marker`.
- Added `config/table_domains.csv`, `table_domains` and `v_series_domain`: an economic domain, subdomain and measure family for all 94 Annex worksheets, recorded as unreviewed.
- Derived `unit_code` and `scale_multiplier` on `dim_series` from the published unit and scale, and created `stock_flow`, `nominal_real`, `seasonal_adjustment`, `transformation` and `valuation` at `not_reviewed` rather than filling them by inference; `outputs/semantic_metadata_completeness.csv` reports the coverage.
- Added `v_series_observations` with `period_start`, `period_end`, `available_at`, `observation_status` and `value_in_base_units`, plus the `series_as_of_date(as_of)` interface. `period` itself is untouched, so no observation key moved.
- Added `canonical_series`, `map_canonical_series`, `methodology_regime` and `classification_concordance` with guarded reviewer-facing configuration; canonical identifiers are assigned by a reviewer and cannot be reused from a parsed `series_id`.
- Added seven Annex marts by domain, a coverage dashboard, the section 11 P2 gap, discontinuity and cross-source screens, and `series_grain` so auctions, trades, curve nodes and entity panels are counted separately from scalar macro series.
- Added release-blocking anti-join and natural-key integrity checks in place of declared foreign keys, which the DELETE-then-append curation path cannot support.
- Added `compact_database.R` and `docs/DATABASE_STORAGE.md`. The file never shrinks on its own: a run writes replacement blocks before releasing the old ones, so it grows to each run's high-water mark and keeps the freed blocks on an internal free list. Ten runs during this round left 254 MiB of free space in a 555 MiB file. Compaction copies every object into a fresh file and swaps it in only after verifying every table, row count, view, macro, constraint and schema version is identical.

## v13

P0 of the external technical audit. See `revisiones/REVISION_AUDITORIA_P0_P1_P2.md`
and `AUDITORIA_REGRESIONES.md` R52.

- Added `series_id_migration`, `source_alias` and `continuity_map`, the operator entry point `build_migration_map.R`, and `v_series_id_resolution`, which resolves any identifier the project has ever published to its current series or an explicit retirement. Resolution is transitive across releases; three hops are recorded and no published identifier is left without an outcome.
- Repaired the credit-survey question-header test. It required a header row to carry no values, but nine of the 73 header rows carry a stray numeric and one is published without a dash after the question number, so each of those headers was consumed as a response of the previous question and the following block inherited the wrong question. 50 positional identities, 25 conflicting question/response groups and 5 spurious one-observation series went to zero; 24 stray cells stopped being read as survey responses.
- Added `table_reconciliation` and `config/reconciliation_exclusions.csv`: per worksheet, the numeric source cells reconciled against accepted observations, recorded discards and reviewed exclusions. Cell reuse is zero across all 242 worksheets.
- Added six evidence columns to `table_status`; a `validated` row now requires definitions, units, timing, hierarchy and methodology to be answered individually and the worksheet's cell accounting to balance.
- Enforced the observation grain: `fact_series_events` gained `PRIMARY KEY (series_id, period, vintage_id)` and NOT NULL on its key columns.
- Added the section 11 P0 release gate and made it block. An error-severity flag now sets the run to `release_blocked` and `run_update.R` exits non-zero, where the pipeline previously recorded errors and continued.
- Added golden source-cell signatures for the four repaired parser families.

## v12

P0 parser and identity repairs from the external technical audit. See
`revisiones/REVISION_AUDITORIA_EXTERNA.md` for the verification record and
`AUDITORIA_REGRESIONES.md` R46-R52 for per-defect detail.

- Bounded each compensatory-FX year block at the next year header in its own column; 36 lane series became 3 measures with zero conflicting months.
- Made the worksheet slug inside `series_id` a pure function of the sheet name; it was uniquified by position, so an inserted column reassigned the identity of every later series in that sheet.
- Added `continuation_group` to `config/sheet_modes.csv` so worksheets that are chronological continuations of one series share an identity while keeping per-sheet lineage; `bcp_fx_daily` went from 168 series to 12.
- Derived period-axis orientation from a single helper so a horizontal parser cannot inherit a column slot; the credit survey lost 2,534 one-observation identities.
- Computed the EVE block and label slugs before `tibble()` so `slug()` no longer sees the materialized column; 2,760 series became 16.
- Added a table-specific `CUADRO 61` parser with a two-level row hierarchy, header guards and an ambiguity guard; 170 numeric-label lane identities became 182 semantic series with a perfect source-cell balance.
- Added `config/table_status.csv`, `table_status`, `v_series_table_status` and `v_research_series` so the generic catalogue is not exposed as research-ready, plus a release-blocking `table_status_incomplete` check.
- Added schema 12 with targeted reingestion of every documented source plus EVE, and cleared `discarded_rows` during invalidation so a re-ingested vintage no longer aborts on its content-addressed primary key.

## v11

- Separated fresh schema bootstrap from versioned data migrations so a new database never executes historical invalidation code.
- Fixed selective concept cleanup in the v9-to-v10 repair and retained unrelated source-specific concepts.
- Expanded legacy `dim_series` tables before migration queries, including the v2 compatibility fixture.
- Added strict annotated-year recognition and ordered-sequence scoring for row and column time axes.
- Added a real `CUADRO 58` regression that excludes false 2033–2098 periods.
- Added selective v10-to-v11 Annex reingestion, dynamic bank-header row accounting and a current v1-to-v11 entry point.

## v10

- Excluded Annex annotation/percentage rows from vertical date axes while allowing the reviewed official projection horizon.
- Rebuilt historical exchange-rate parsing around every consecutive-year block with verified Compra/Venta headers.
- Represented XML-empty formula views with zero content bounds and made all semantic matrix helpers 0 × 0 safe.
- Fixed DuckDB continuity aliases and added an executable two-vintage regression.
- Added canonical deposit/repo block identity to liquidity events and excluded semantic dimensions from measure observations.
- Added selective v9-to-v10 reingestion, a current v1-to-v10 migration entry point and reconstructed regression-audit documentation.

## v9

- Fixed named-table XML discovery by reading the root `<table>` node, restoring all 15 bank/finance reference tables.
- Made empty/formula-only worksheets produce a typed zero-row raw-cell table and hardened exchange-house date propagation.
- Added shape-preserving matrix predicates for regex/equality anchor searches.
- Added the BCP `set` month alias; quarter parsing now rejects naked digits and infers a missing quarter only inside a validated Q1--Q4/annual block.
- Preserved hierarchical credit-survey subquestions such as `10,1` and corrected direct-investment annual/quarter column boundaries.
- Added semantic row-event parsers for interbank operations, LRM tenors and liquidity auctions. Genuine same-day duplicates use deterministic positional lanes that never hash observed values and are explicitly marked `identity_stability = positional_lane`.
- Moved workbook discovery and metadata registration inside per-source failure isolation; a corrupt workbook is persisted as failed while later sources continue.
- Added v8-to-v9 reingestion invalidation, real-file regression tests and a v1-to-v9 migration entry point.

## v8

- Vectorized unit, scale, currency, index-base and total inference over distinct semantic keys while preserving source-specific overrides.
- Replaced per-observation one-row tibbles and growing-list function round trips with lightweight direct record assignment; vectorized the horizontal year-month grid.
- Calculated documented-series hashes once per unique worksheet/path/frequency identity and payment BIC matches once per unique series path.
- Reused one worksheet read for raw content-addressed storage and semantic parsing, eliminating the second full Excel pass for `semantic_table` sources.
- Cached sheet-mode and source-contract configuration with file-change invalidation.
- Added schema-v8 source/stage timings and `outputs/ingestion_stage_timings_latest.csv`.
- Added performance-equivalence tests against the v7 scalar metadata rules and identity contract.

## v7

- Removed inferred unit and currency from documented-series identity; exposed `identity_basis` and `identity_stability`.
- Added prior-vintage series continuity, disappearance thresholds and unit/scale/currency drift errors.
- Added configuration-driven sheet modes, hierarchy-status warnings and coherent non-monetary scales.
- Added 12 sources: ten Excel report sources and two guarded long-format market CSVs.
- Added typed bond-curve and securities-transaction tables plus latest and daily-activity views.
- Added active-cell bounds for every worksheet, chartsheet filtering and a repeated date-block parser for liquidity operations.
- Added registry-derived smoke-test source counts, expanded contracts and a v1-to-v7 migration entry point.

## v6

- Added `dim_concept`, `map_series_concept`, and audited concept views without automatic cross-source equivalence.
- Added guarded reviewed mappings through `config/concept_mappings.csv`.
- Added per-sheet prior-vintage drift diagnostics and `outputs/documented_sheet_drift_latest.csv`.
- Added bounded and occurrence-aware anchor lookup for repeated labels.
- Added a current v1-to-v6 migration entry point and updated compatibility aliases.

## Version 5

- Converted the four remaining inventory-only sources into guarded documented-series sources.
- Added reusable parsers for eight recurring Annex/payment table orientations and specialized credit-survey and exchange-house parsers.
- Added `documented_series_snapshot`, `documented_table_catalog`, `dim_payment_participant` and `dim_exchange_item`.
- Added latest-source views for the Annex, payments, exchange houses and credit survey plus a documented-series catalogue.
- Added source contracts, key-series/unit/entity/range validations, parser-helper tests and full-pipeline coverage assertions.
- Added v4-to-v5 reingestion invalidation and a current `upgrade_v1_to_v5.R` entry point.
- Retained ambiguous units as explicit `source_units` review items rather than inferring harmonized semantics.

## Version 4

- Corrected code 6200 from a false USD interpretation to foreign-currency origin measured in PYG.
- Added `currency_of_origin` and `unit_currency`; retained `economic_currency` only as a corrected deprecated alias.
- Added currency-description consistency validation.
- Replaced brittle exact growth-series counts with minimum baselines and prior-vintage shrinkage checks.
- Changed reference resolution from autogenerated Excel display names to worksheet-plus-column signatures.
- Forced reference cells to text and added raw/canonical account identifiers plus scientific-notation guards.
- Replaced full-copy report-cell ingestion with content-addressed sheet versions and vintage links.
- Added a compatibility view and non-destructive v3 legacy migration for report cells.
- Added schema version 4, migration tests and expanded documentation.

## Version 3

- Fixed worksheet relationship resolution for all workbooks.
- Fixed direct-source schema filtering for bank versus finance-company inputs.
- Standardized report reading on list cells to preserve mixed Excel types.
- Added Excel-epoch and defensive character date conversion.
- Added hard semantic-date plausibility guards.
- Made YAML loading locale-independent with explicit UTF-8.
- Added `publisher`, `source_format` and separate `scale` metadata.
- Added automatic invalidation/reingestion of defective v2 ICC, EVE and FX content.
- Added a version-1-to-version-3 migration and retained the old v2 filename as an alias.
- Added the bank/finance reference workbook as a required, versioned source.
- Added verified entity, currency, statement, ratio, portfolio, account and credit-activity dimensions.
- Added ten documented bank/finance views and mapping-coverage checks.
- Added exact reference-table count/structure tests and a full real-workbook smoke test.
- Corrected FX content-based publication-date inference to use the latest observed month.
- Expanded README, data model, architecture, operations, feedback and verification documentation.

## Version 2

- Added strict structure guards for direct and curated sources.
- Added deterministic content identities, deduplicated archives and consultable vintages.
- Added full snapshots, sparse change/removal events, as-of queries and revision history.
- Expanded FX operations to annual, quarterly and monthly data with subtotal checks.
- Added source transactions, discarded-row records and explicit semantic coverage.
- Added archive reconstruction and review-required semantic spec skeletons.

## Version 1

- Initial folder-based source resolver, raw archive, XML dimension detection, direct tables and three curated parsers.
