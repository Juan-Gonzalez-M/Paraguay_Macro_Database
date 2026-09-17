# Data model

## Identity and provenance

- `sha256`: hash of exact workbook bytes.
- `vintage_id`: deterministic `source_id:hash-prefix`.
- `release_id`: deterministic hash of all source hashes in one update bundle.
- `publication_date`: filename date or guarded content date; never the execution clock.
- `executed_at`: operational timestamp.
- `publisher` and `source_format`: explicit source-registry attributes retained in `source_files`.

`source_files` has one row per distinct source content. `release_sources` is the many-to-many bridge between deterministic update bundles and source vintages. `source_sheets` records both Excel’s declared dimensions and XML-derived first/last meaningful cells; `reference_table_loads` records named semantic tables.

`ingestion_stage_timings` has grain `attempt × source vintage × stage`. It is operational telemetry only: elapsed time never enters a content, vintage, release or series identity. It is appended, never replaced, so the record of how long previous runs took survives the next one.

## Statistical series

Curated snapshot tables retain a complete publication by `vintage_id`. `fact_series_events` is sparse: a row is added only when a series-period value appears, changes, or disappears from a later full-history publication. Disappearances are tombstones (`is_deleted = TRUE`). `series_revisions` records the corresponding old and new values.

`v_series_latest` selects the newest event of a published vintage, suppresses tombstones, and since schema 30 returns **realized observations only**; `v_publisher_statement_latest` is the same with the publisher's projections included. `series_as_of_date()` performs the same resolution after an availability cutoff, with `series_statement_as_of_date()` as its projection-inclusive twin.

`dim_concept` is deliberately separate from `dim_series`. `map_series_concept` records whether a relationship is merely the generated source identity or a reviewed mapping supported by evidence. `v_series_concept_catalogue` exposes the audit trail; `v_concept_latest` never aggregates mapped series automatically.

`documented_sheet_drift` compares the parsed observation and series counts of each complex worksheet with its previous completed vintage. This makes a missing or truncated sheet visible even when the total workbook row count happens to increase elsewhere.

`documented_series_continuity` compares the set and metadata of series identities with the preceding completed source vintage. It retains every new, disappeared or metadata-changing identity, including labels and whether positional disambiguation was used.

`dim_series` keeps `unit` and `scale` separate. For example, FX values use `unit = USD` and `scale = millions`; this avoids encoding magnitude inside the economic unit.

## Documented series identity

A documented `series_id` is `source_id : worksheet_slug : hash(stable_path | frequency)`, and `identity_basis` is `worksheet | frequency | stable_path`.

The worksheet slug is produced by `documented_sheet_slug()`, which applies `janitor::make_clean_names()` to one sheet name at a time. Applying it to a vector would uniquify duplicates by position (`datos`, `datos_2`, … `datos_26`), which would make identity depend on where a series happened to fall in the identity table rather than on the sheet it came from: inserting one column upstream would silently reassign every later series in that sheet.

The worksheet that participates in identity is not always `source_sheet`. When `config/sheet_modes.csv` declares a `continuation_group` for a source or sheet, that value is used instead — for publishers that split one continuous series across several worksheets, such as `bcp_fx_daily`, which publishes one worksheet per year. `source_sheet`, `source_row` and `source_column` remain untouched on every observation, so the annual worksheets stay addressable as aliases and per-sheet drift, continuity and raw-cell lineage are unaffected.

When a label repeats within a sheet, the identity guard appends a structural slot drawn from the axis that is *not* the period axis: the source row for horizontal layouts (periods across columns) and the source column for vertical ones. `documented_period_axis_is_horizontal()` is the single place that decides this. Using the wrong axis pins the period and turns each column into a one-observation series.

## Research-readiness gate

`table_status` carries one reviewed status per source table, loaded from `config/table_status.csv`: `validated`, `provisional`, `needs_remodeling` or `quarantined`. `v_series_table_status` resolves each series to its status, matching an exact `(source_id, source_sheet)` row first and falling back to the source-level `*` row; curated sources with no worksheet grain always match the wildcard.

`v_research_series` exposes only `validated` tables. That status is a claim about economic review — definitions, units, period conventions, hierarchy — and no automated check can grant it, so `apply_table_status()` requires a named reviewer and a review date for every validated row. `validate_database()` raises a release-blocking `table_status_incomplete` error if a source or worksheet reaches the catalogue without a declared status, so the research surface cannot expand silently.

Since schema 13 a `validated` row additionally requires all six evidence columns — `definitions_reviewed`, `units_reviewed`, `timing_reviewed`, `hierarchy_reviewed`, `methodology_reviewed`, `evidence_uri` — and requires the worksheet's cell accounting to balance in `table_reconciliation`. A single reviewer name cannot carry a claim about five separate economic questions, and an unexplained residual of source cells is an unproven correctness claim.

Since schema 28 a second gate sits alongside it, on the series rather than the table. A series may not enter a validated mart without `unit_code`, `scale_multiplier`, `frequency`, `stock_flow`, `nominal_real` and `seasonal_adjustment` — and `not_reviewed` or `UNRESOLVED_SOURCE_UNITS` does not count as a value. These are not metadata niceties. Without them a transformation is a guess that looks like arithmetic: deflating a series nobody has marked nominal, summing a stock, annualising a rate, or comparing a seasonally adjusted series with an original one is in each case a technically valid query and an economically invalid answer. The gate passes vacuously today because nothing is promoted, which is the point of writing it now — writing it after the first promotion would be writing it too late.

**Schema 34 supplies the missing half: somewhere to record the answers.** Rows in `series_semantic_evidence` whose `basis` is `reviewed` have always been preserved across every rebuild while derived ones are deleted and recomputed — and nothing in the codebase had ever written one. There was an output worklist naming what was unreviewed and no input register.

`canonical.series_review`, loaded from `config/series_review.csv`, is that register: one row per series, carrying the published definition and its evidence URI, the source table and row semantics, frequency and reference-period convention, timing basis (end-of-period, average, total, cumulative), stock/flow, unit, scale, currency, valuation, nominal/real with base year, seasonal adjustment, transformation, hierarchy role and parent, methodology regime, comparability, availability convention, reviewer and date. `main.v_series_review` publishes it.

It is applied **after** the derivation layer, never before: several of those derivations are unconditional `UPDATE`s that would otherwise overwrite a reviewed value. "Reviewed wins" is true by construction rather than by each derivation remembering to check. The values land on `dim_series`, where every existing query already reads them; the reviewer's sentence lands in `series_semantic_evidence` with `basis = 'reviewed'`, so `v_series_measurement` goes on distinguishing "the publisher's label says so" from "an economist checked".

**A problem in any row applies none of the register.** Not the good rows with the bad ones reported: a partly-recorded review fills exactly the columns the gate above reads, so a series would become promotable on the strength of a row its reviewer never finished. `series_review_incomplete` is an error and blocks. The register ships empty and `marts.v_research_series` is 0 rows until somebody writes the first one.

### Which review is authoritative — both, and they answer different questions

Until schema 36 the paragraph above was true of the register and **false of the gate**, and this document said otherwise. `marts.v_research_series` required only that every worksheet a series was assembled from carried `table_status = 'validated'`; it did not mention `canonical.series_review` at all. The eligibility check beside it inspected six *column values* on `dim_series` for the sentinels `not_reviewed` and `UNRESOLVED_SOURCE_UNITS` — which the derivation layer never writes. A label reading `saldo` yields `stock_flow = 'stock'` with `basis = 'published_label'`; a published price base year yields `nominal_real = 'real'`. Every field would have been populated, none of them by an economist, and promoting a single worksheet would have admitted every series on it. The re-audit's RA2-02.

The two reviews are not competing claims about the same object:

| Register | Object | Question |
| --- | --- | --- |
| `config/table_status.csv` → `audit.table_status` | a **worksheet** | is this source table's parsing and cell accounting fit to publish? |
| `config/series_review.csv` → `canonical.series_review` | a **series** | is this series' economic meaning established — unit, scale, timing, stock/flow, nominal/real, adjustment, hierarchy? |

Neither implies the other. A series can sit on a perfectly reconciled worksheet with no established meaning, and a reviewed series can sit on a worksheet whose cells do not add up. **Both are required**, by `marts.v_research_series` and by every `marts.v_mart_*`.

And the gate reads the *basis*, not the value: `validate_research_eligibility_metadata()` raises `research_series_evidence_not_reviewed` when a series on the research surface carries an eligibility field with no `series_semantic_evidence` row at `basis = 'reviewed'`. The view requires the register row; the validator requires the evidence that row produces. They diverge only when a row reaches the table without going through `apply_series_review()` — which is the case where "reviewed" would otherwise be a claim with nothing behind it.

## Cross-release identity

Parser repairs move identifiers. `series_id_migration` records, for each pair of releases, how every identifier moved: `identical`, `renamed`, `merged`, `split`, `split_and_merged`, `dropped` or `new`, with the evidence that established it. The primary evidence is the physical source cell — the same file, sheet, row, column and period in both releases — because labels and identities are exactly what a repair changes, while the cell does not move.

`v_series_id_resolution` is the single lookup for research code: given any identifier the project has ever published, it returns `current`, `prior_release_alias` (with the series it became) or `retired` (withdrawn, because the series it named was a parser artefact). Resolution is transitive, so an identifier renamed by one release and again by the next still resolves. `validate_release_gate()` blocks a release in which any published identifier has no recorded outcome — the failure that broke reproducibility in the first place.

`build_migration_map.R` records a hop; `source_alias` and `continuity_map` hold the resolved aliases and reviewed continuity decisions.

## Source-to-target reconciliation

`table_reconciliation` answers, per worksheet and vintage, whether every numeric source cell became an observation. Two measures matter. `cell_reuse` is accepted observations minus distinct consumed cells and must be zero — it is the invariant the compensatory-FX defect violated. `unmapped_in_region` counts numeric cells inside the rectangle the parser actually consumed that became neither an observation nor a recorded discard; it is what silently dropped data looks like from the outside. Cells outside that rectangle are period-axis headers, numeric row labels and footnote markers, recorded as `out_of_region_cells` but deliberately outside the balance, since the parser never claimed them. Every unmapped cell must resolve to exactly one rule in `config/reconciliation_cell_rules.csv`, which maps coordinate rectangles to a classification (`header_or_label`, `subtotal_or_formula`, `report_layout_derived`, `out_of_scope_block`, `parser_defect`, `observation_expected`) with the worksheet evidence quoted and a named reviewer; `reconciliation_cell_classification` records which rule explained which cell, so the total can be audited rather than trusted. A cell matching no rule blocks the release; a `parser_defect` rule keeps its worksheet out of every research view until the parser is repaired.

The two storage layers do not share a coordinate system. `report_cell_values` stores each worksheet cropped to its used range and numbers it from 1; the parsers work on the uncropped sheet and record A1 coordinates. **Join the layers through `v_report_cells_a1`, never directly** — comparing them untranslated is what produced 13,041 phantom unexplained cells before schema 16.

**Since schema 34 the two delimited sources are in this table too, with a row where a worksheet has a cell.** Their unit is the source row rather than the source cell — `source data rows = accepted + rejected + documented exclusions`, with `source_sheet = 'data'` — but the identity, the status vocabulary and the release-blocking residual are the same. Source rows come from the recorded content bounds, accepted rows from the snapshot, rejected rows from `staging.discarded_rows`.

Until then neither CSV source was in the accounting at all, and both parsers read permissively and dropped whatever failed to parse: **three securities trades with a blank volume had been disappearing on every run since the source was added**, 312,329 rows in the file against 312,326 in the database, with nothing anywhere recording the difference. Every recorded rejection now carries a reason from `ROW_REJECTION_REASONS`, `config/row_rejection_reasons.csv` says what each means and whether seeing it is expected, and an undeclared reason blocks the release. The register covers every writer of `discarded_rows`, not only the delimited path — which the gate demonstrated on its first run by finding that the ICC/EVE and FX-operations parsers had been discarding rows under an undeclared reason since schema 12.

## Ingestion completeness outside the parser's region

`table_reconciliation` measures the rectangle the parser consumed, and that rectangle is derived from the observations the parser emitted. It therefore cannot say anything about a cell the parser never went near: an entire published block can be missing and the worksheet still balance. Since schema 24, `source_region_classification` answers the other half of the question. It is built from the raw cell layer **independently of what the parser emitted**, over every documented worksheet — not only the ones that produced observations, because a worksheet the parser reads nothing from has no region at all and would otherwise vanish from the accounting exactly when it matters most.

Every numeric cell outside every parser region resolves to one rule in `config/source_region_rules.csv` or to `unreviewed`. The vocabulary says what the cell is: `period_axis` (the year or date column the sheet is indexed by — Excel stores a date as a number, which is why these are counted at all), `row_index`, `header_or_note`, `report_layout_derived` (cumulative-to-date and variation columns), `out_of_scope_block` (a second table the parser does not claim) and `data_not_ingested` (published data no parser region reaches: real loss). Rules carry the same discipline as the in-region register — a coordinate rectangle, a reason, the worksheet evidence quoted, a named reviewer, and a verified cell count whose drift is reported.

`unreviewed` and `data_not_ingested` block promotion to `validated`; neither blocks the release. A gate nobody can pass is a gate that gets switched off, and nobody classifies tens of thousands of cells in one sitting — but a worksheet whose region has not been examined has not been shown to be complete, and completeness is precisely what validating it would claim. `outputs/source_region_review_worklist.csv` is the reviewer's queue.

**`data_not_ingested` is now zero.** It stood at 12,371 cells, and a `data_not_ingested` rule is not an explanation — it is a record of loss with a reviewer's name on it. Schema 27 repaired the two parsers responsible rather than keeping the rules: the direct-investment stock tables `Cuadro 5` and `Cuadro 7` publish a year-quarter header across two rows, and the annex `Cuadro 52a`/`52b` horizontal axis stopped at the column carrying the last period's label instead of at the end of its block. The four rules were retired with the defects.

## Release lifecycle and what is published

A source commits and is marked `completed` one at a time, before the release-wide validation has run. That is deliberate — it is what keeps one broken workbook from stopping the diagnosis of the next — but it means "this vintage loaded" has never meant "this vintage may be published". Since schema 24 those are different facts. `releases` gives a release a lifecycle: it enters `staged` when the run begins and leaves `accepted` or `blocked` when the release gate has counted the flags.

Since schema 27 that boundary is on **every** published interface, not only the generic series path: the seventeen `v_latest_raw_*` direct panels, the documented family (`v_documented_series_latest_snapshot` and the annex, payments, exchange-house and credit-survey views built on it), both market views (`v_bond_curves_latest`, `v_securities_transactions_latest`), `v_series_latest`, the `series_as_of_date()` macro and every `marts.*` view restrict themselves to publishable vintages, **in SQL**. The release filter sits *inside* each ranking subquery, so a view returns the newest vintage a researcher may see rather than nothing at all when a newer one is still staged.

## Source bundle, build, data release

Since schema 30 there are three identities, because one identifier was being asked to mean three things.

| Identity | What it hashes | What it means |
| --- | --- | --- |
| `release_id` (source bundle) | every admitted source file's SHA-256 and, for an explicitly scoped product, the governed scope identity/digest | "these authorized input files" |
| `build_id` | the release, the Git commit and dirty flag, the schema version, digests of `config/` and `scripts/`, a digest of `renv.lock`, **and the package versions that actually ran** | "this code, in this environment, on those files" |
| `data_release_id` | the two above, as a decided product | "this database" |

An unscoped `release_id` hashes the sources and nothing else. A release governed by
`config/release_input_scope.csv` additionally hashes the canonical scope identity and digest, so
the same bytes admitted under a distinct product-scope decision receive a distinct source-bundle
identity. Both forms are deterministic. Neither includes parser code, which is why a source bundle
is the wrong thing to publish from by itself: the same historical bundle had **fourteen attempts
spanning schemas 26 to 29**, with materially different observations, and `audit.releases` kept only
the latest status for the one row they shared. One of those attempts ended blocked. Because every
published view joined `releases.status = 'accepted'`, **a failed rebuild withdrew the entire
published database** — not the data it produced, the data it failed to replace.

So publication is now two things that used to be one mutable `UPDATE`:

- **`audit.data_releases`** records one decision per product, **inserted once and never rewritten**. Re-deciding the same product identically is a no-op; re-deciding it differently is an error, because a different verdict from the same code, configuration and sources means one of them is not what it claims to be.
- **`audit.active_data_release`** is a single-row pointer, swapped in one transaction and **only by a build that was accepted**. A blocked build records its verdict and stops. `accepted_release_vintages_sql()` resolves through the pointer, so publishing is one row changing and no view is rebuilt.

The release-wide phases run inside **one transaction** (schema 30). Without it the pointer would be theatre: a build that died halfway had already deleted and half-rebuilt reconciliation, region classification, semantics, the expected grid and the missingness table underneath a release still marked accepted, so the published database was a mixture of two builds. DuckDB rolls DDL and DML back together, so a failure now leaves the previous build's derived tables untouched. Units that manage their own atomicity call `with_project_transaction()`, which joins an outer transaction rather than opening a second one — DuckDB has no nested transactions, and probing for one by attempting a `BEGIN` aborts the transaction being probed, so depth is tracked per connection instead.

**Every transaction in the project goes through that register**, including the explicit one the per-source ingestion opens across a `tryCatch` boundary: `project_begin_transaction()`, `project_commit_transaction()`, `project_rollback_transaction()`. A bare `DBI::dbBegin()` would leave the register saying nothing is open, so the first unit inside that asked for a transaction would try to open a second — and the failed `BEGIN` would abort the source's own transaction, reporting a transaction error from code that never wrote one. That path only runs on a full ingest, which is why it has to be tested by building a database from the real workbooks rather than by reusing vintages.

**A build runs in its own file (schema 33).** Everything above operates *inside* the database it is protecting, and that is why it was not enough. Published views resolve vintages through the source bundle rather than the build, so every build of one bundle exposes the same rows; the ingestion commits source by source hundreds of steps before the verdict exists; and `initialize_database()` runs the migrations' invalidation steps, which delete published facts by `source_id` before the run has begun. Committed work under a pointer that has not moved is still committed, so a failed build could not withdraw the published database but could change it.

`run_isolated_update()` copies the database to `database/candidates/`, runs the whole pipeline there, and renames the candidate into place only if the build is accepted. The pointer, the decision and the release transaction are all still there and still do their jobs; what the file boundary adds is that **a build you did not accept cannot have altered the one you did, provably, by hashing the file**.

**What this does not give you.** Facts are still not versioned per build. Reconstructing an arbitrary past product from inside one database would need a fact namespace per build, which is a much larger change and is not attempted. `audit.data_releases` preserves the decisions; the data under a superseded decision is gone — though since schema 33 the database that held it is retained as `database/backups/paraguay_macro_pilot_pre_swap_<stamp>.duckdb` until the retention rule reclaims it.

**`audit.build_environment` (schema 35)** records the version of every package the project loaded, one row per package, beside the build it produced. `environment_digest` hashes `renv.lock`, which is a *declaration*; before schema 35 that was the only environment input to `build_id`, so two builds run against libraries differing from each other and from the lockfile produced the same identifier. The digest of the observed versions is now part of the hash — a different library is a different build — and the list is kept beside it, because a digest can say two builds differ and only the list can say which package moved.

Every filtered view has an unfiltered `_all` twin. Those exist for diagnostics and for the ingestion path, which compares a new vintage against what the database already holds and must see a release that has not been accepted yet. **An `_all` view is not a research interface.**

## What is published, declared rather than inferred

`config/public_view_contract.csv` gives every view and macro in `main`, `marts`, `catalog`, `explore`, and `research` a `public_scope`, with a reason and a reviewer:

| Scope | Meaning |
| --- | --- |
| `current` | Publishes observations from the active data release. Must descend restrictively from a filtered base relation. |
| `all` | The unfiltered twin of a `current` object. Sees staged and blocked builds; exists for the ingestion path and for diagnosis. **Not a research interface.** |
| `history` | All vintages, deliberately. |
| `reference` | Describes series, dimensions or review status. Carries no observation and therefore no release boundary. |
| `diagnostic` | Evidence about how the database was built — cells, reconciliation, provenance, identity migration. |

**An object absent from the register blocks the release.** That is the point: a view added without anyone saying whether researchers should read it is the failure the register exists to catch, and "undeclared" must not quietly default to "diagnostic".

The lint that checks all this has been rebuilt twice, and the reason is worth recording. Version one named two objects and matched the mart family; an audit found thirty-four published views with no release join at all. Version two replaced the list with naming rules — and the third audit found the deeper problem: **a rule over names cannot decide which objects are research interfaces, and a test for the word `releases` cannot decide whether one filters.**

Both failed concretely. `v_series_observations` read the whole fact table and `LEFT JOIN`ed accepted releases only to populate a label, so a row belonging to no accepted release survived with a null column — and the body contained the word, so the lint passed it, and everything built on it. Meanwhile `v_fx_operations_annual` and `v_series_catalogue` matched no naming rule, and neither did thirty-five other public objects.

Neither question is inferred any more. Scope is declared. Filtering is decided by **descent**: an object qualifies if it carries the boundary in its own body — declared per object as `carries_release_boundary`, and verified against the stored SQL — or if it reads something that does. An `_all` twin is never followed. Forgetting to declare a new filtering view makes the lint *fail*, not pass.

`blocked_release_visible` reports any of it. The row invariant is checked too, but the structural test is the real guarantee: a view rewritten without the filter would publish a blocked build while every row test kept passing, because during a normal run the unpublishable rows do not exist yet. That is why the acceptance test for this is adversarial — `tests/testthat/test-release-isolation.R` builds a database that genuinely holds a vintage nobody may see, asks every `current` object for it, and asserts the `_all` twins *do* return it so the test cannot pass vacuously.

## Measurement semantics

`unit_code` and `scale_multiplier` are derived and complete: the scale vocabulary is a closed set of four magnitudes, and the multiplier is the field that prevents a silent 1,000x error.

The derivation has one rule worth stating because it was got wrong. **A unit stated in the table title outranks a unit keyword read from a row label.** `CUADRO 20` of the annex is titled *"En millones de dólares"*, and twelve of its thirty series carried `unit_code = COUNT`, `scale_multiplier = 1` because their row label contains the word *operaciones* — so `value_in_base_units` was wrong by a factor of 10⁶ on a foreign-exchange series that each match a dedicated `fx_operations` series to floating precision over 379 monthly observations. The publisher denominated the table; a word in a row label cannot un-denominate it. The guard already existed for *saldos* and now covers any title stating a monetary magnitude, on both the `count` and the `days` branches. `stock_flow`, `nominal_real`, `seasonal_adjustment`, `transformation` and `valuation` exist with controlled vocabularies but sit at `not_reviewed` except where the source itself determines them (`nominal_real = real` where `price_base_year` is published; `transformation = index` where the unit is an index). There is no seasonal-adjustment evidence anywhere in these sources, so a populated column would be inference presented as metadata. `outputs/semantic_metadata_completeness.csv` reports the coverage rather than implying it.

## Period bounds, availability and as-of

`period` is never rewritten — it is part of the observation key. `v_series_observations` derives `period_start` and `period_end` from the period and the frequency, so the mixed monthly convention (some sources publish day 1, others month end) cannot lose observations or shift a lag on a join. The same view carries `available_at` and `observation_status`.

`available_at` is when the vintage became available to this project. Since schema 28 it is taken in order of authority: the operator-recorded availability in `raw.source_provenance` where one exists, then the vintage's publication date, then the timestamp of first ingestion.

**Only the first is a fact about the publisher, and it is currently empty for all 22 vintages.** An earlier version of this section said `available_at` is "never inferred from the reference period". That was true of the operator-recorded field and false of the column as a whole, which is what the sentence was about. The publication date it falls back to is itself derived from the content maximum for **12 of the 22 sources** — that is, from the latest reference period the workbook contains. For those sources `available_at` is the reference period, and one FX source contradicts even that: it is recorded 2026-07-31 while its values reach 2026-12-31.

The operational consequence, stated plainly because the mechanism looks complete and the data is not:

- **`series_as_of_date()` is snapshot-limited, not real-time.** There is one retained vintage per source and no recorded revision, so `series_as_of_date('2020-12-31')` returns **zero rows** despite the database holding history back to 1945. The macro answers the right question; the evidence to answer it does not exist yet.

### The carrier as-of ranks over (schema 36)

Until schema 36 the macro also answered the right question over the **wrong population**, and it would have failed silently the moment the evidence above arrived.

`accepted_release_vintages_sql()` resolves through `audit.active_data_release`, a one-row pointer at the current source bundle. That is the correct filter for "what is published now" and the wrong one for "what could have been seen then", and the as-of macros read a view built on it. Since `release_id` is a hash of the manifest, replacing a single workbook mints a new bundle whose `release_sources` set omits the vintage it replaced — so a superseded vintage stayed in `fact_series_events`, in `source_files` and in `input_archive/`, and **left the population being ranked**. No cutoff could return it, including cutoffs from before its replacement existed. Retaining a workbook would have produced two vintages and one answer, which is the same look-ahead error the interface exists to prevent, in the place it was least visible.

The ingredients for the right population already existed and nothing joined them: `audit.release_sources` is append-only and many-to-many, and `audit.data_releases` records one immutable decision per product. Their join is every vintage that was ever published.

| Carrier | Vintages | Question | Scope |
| --- | --- | --- | --- |
| `main.v_series_observations` | of the bundle the active pointer names | what is published now | `current` |
| `main.v_series_observations_history` | of **any** accepted data release | what could have been seen then | `history` |
| `main.v_series_observations_all` | every vintage in the database | ingestion diagnostics | `all` |

`series_as_of_date()` and `series_statement_as_of_date()` descend from the history carrier and are declared `history` in `config/public_view_contract.csv` — a scope the contract has declared valid since schema 30 and no object had ever used. Their previous `current` classification was itself part of the defect: the release lint requires a `current` object to descend from the active-pointer carrier, so it was certifying precisely what made them wrong. The lint now checks the two boundaries separately, and a history carrier that restricts to the pointer fails.

It reads `data_releases.status`, **not** `releases.status` — the latter is the mutable per-bundle column schema 30 retired, and using it here would let a later failed rebuild erase history that was genuinely published.

Three consequences, stated because they are not symmetrical:

- **A superseded vintage stays answerable.** That is what makes retaining workbooks worth doing.
- **A build that was never accepted is never knowable**, at any cutoff. It was not published, so nobody could have read it.
- **Blocking a bundle today does not erase what it published yesterday.** Current views empty immediately, because the pointer moves. As-of keeps answering, because a later failed rebuild does not un-happen an earlier publication.
- **No real-time claim should be made from this database** — no forecast evaluation, no nowcasting backtest, no monetary-policy event study that depends on what was knowable on a date — until `official_release_date` and `retrieved_at` are recorded in `config/source_vintages.csv` and every new vintage is retained beside its predecessor.
- `publication_date_inferred_from_content` and `publication_date_source_contradicts_content` report both conditions at every release.

`observation_status` separates an observation dated on or before the vintage that published it (`observed`) from one dated after it (`after_publication`) — a published projection. 343 observations across 186 series are projections: the annex publishes forecast years to 2028 and FX operations to end-2026.

Since schema 30 the **names match the contents**:

| View | Contains |
| --- | --- |
| `v_series_latest` | realized observations only — the research default |
| `v_publisher_statement_latest` | the publisher's full current statement, projections included |
| `marts.v_series_projections` | the projections on their own |
| `v_series_latest_observed` | deprecated alias of `v_series_latest` |
| `series_as_of_date(d)` / `series_statement_as_of_date(d)` | the same split, point-in-time |

Schema 27 kept the projections in `v_series_latest` and exposed the status beside them, reasoning that the view answers "what does the publisher currently say" and a projection is part of that answer. The reasoning was sound and the naming was not. `v_series_latest` is the obvious default, it is what every example query reaches for, and a researcher who never reads the column gets 2028 forecasts in an estimation sample: the safe-sounding name was the unsafe one. Nothing is hidden and nothing was lost — the full statement has a name that says what it is. A projection reaching `v_series_latest` is now an **error** (`projections_in_realized_view`), not a warning to remember.

## Canonical layer

`canonical_series` identifiers are assigned by a reviewer and must not reuse a parsed `series_id`;
the canonical name is stored separately from the publisher's `source_label` and `full_series_path`.
`map_canonical_series` holds membership, resolved through `v_series_id_resolution` so a canonical
series keeps its members across a parser repair that renamed them. Each membership records a
relationship (`primary`, `replica`, `historical_segment`, `methodology_break`, `component`,
`aggregate`, or `projection`), effective dates, precedence, and overlap policy. `methodology_regime`
records definition, base-period and classification changes with comparability;
`classification_concordance` maps between classification schemes. All reviewed registers ship
empty: the machinery and guards are delivered, and populating them is economic review.

That is a decision, not an omission. Declaring one canonical series means asserting its definition, domain, frequency, unit, currency, stock/flow and nominal/real character under a named reviewer — seven economic judgements per concept — and no automated screen can make them. What the pipeline does instead is assemble the evidence and rank it. `outputs/canonical_core_candidates.csv` ranks concepts by how much of the database they would unify; `outputs/duplicate_series_candidates.csv` screens for series whose values agree period-for-period, by md5 signature over the shared periods, which is what a duplicate looks like before anyone has decided which one is primary. The `CUADRO 20`/`fx_operations` pair is the clearest case in the database and sits at the top of that list.

The guards run whether or not anything is declared: `validate_canonical_membership_agreement()`
blocks a release in which a declared replica disagrees with its primary over their overlapping
periods. Equal-precedence overlapping carriers block unless they are an explicitly equality-tested
primary/replica pair. A canonical relationship that stops holding is a fact about the sources, and
it should stop the release rather than be discovered by a reader.

## Researcher-facing catalogue, exploration, and research schemas

Schema 43 adds discovery without changing formal admission. `catalog.series` has exactly one row per
`canonical.dim_series.series_id` and combines the source label/path, available dimensions and economic
metadata, current coverage, declared-frequency gap diagnostics, normalized-key checks, lineage,
machine-readable validation tier, and explicit warnings. The post-promotion contract additionally
assigns exactly one conservative `primary_review_category`, records its deterministic rule and
separate issue codes, and exposes catalog, explore, and research admission or exclusion status.
These fields classify usability; they do not create research assurance, merge identities, or claim
human economic verification. A research-admission category names its actual assurance basis
(`rule_certified` or `human_verified`). Exact supported overlap groups are carried into exploratory
rows, while source-specific identity or label ambiguity may withhold an otherwise mechanically valid
native-grain candidate without removing it from the catalogue. `catalog.series_warnings` normalizes those
limitations and `catalog.datasets` covers direct panels and long-format source datasets that are not
fully described by scalar candidate rows. `catalog.profile(candidate_id)` is the one-candidate lookup.

`explore.observations` contains current actual scalar observations only for semantic identities with at
least three finite observations, ordered normalized period bounds, no normalized-period collision, no
applicable error flag, and no quarantined/invalid table status. `explore.events`,
`explore.panel_observations`, and `explore.curve_observations` keep special structures separate. All
rows carry their validation tier, status, warning, source/vintage lineage, and available source
coordinates. These are mechanical retrieval conditions, not economic certification.

Worksheet lineage in `explore.*` is resolved at the observation natural key
`(vintage_id, series_id, period)` from `staging.documented_series_snapshot`. `source_sheet`,
`table_title`, `source_row`, and `source_column` therefore describe one source cell together. The
series identity remains separately visible as `identity_basis` and `identity_source_sheet`, while
`title_record_source_sheet` and `title_record_table_title` retain the one-row canonical title record.
`worksheet_lineage_correction_reason` explains rows where that series-level record differs from the
observation worksheet. A catalogue profile publishes `source_sheet` only when every current
coordinate belongs to one worksheet; `source_sheets`, `source_sheet_count`, and
`worksheet_lineage_status` represent continuation groups honestly. An invalid locator quarantines
the candidate, and the staging natural-key constraint rejects ambiguous observation lineage.

Schema 43 continues to publish exactly nine stable views under `research`: `dataset_catalog`, `series_catalog`,
`observations_latest_actual`, `observations_latest_statement`, `entity_panel`, `events`, `curves`,
`transactions`, and `quality_flags`. The table macro `research.observations_as_of(timestamp)` is the
point-in-time scalar interface. Every data row carries its assurance level and rule. Automated
certification is stored separately from `canonical.series_review`, so it cannot be mistaken for a
human signature. Unresolved series and unsafe canonical mappings remain out of the data views while
their source-level disposition remains queryable in `dataset_catalog`.

## Series grain

`series_grain`, declared in `config/source_grains.csv` per source and (since schema 32) per worksheet, separates `scalar_series` from `event` (auction tenders, interbank operations, securities transactions), `curve_panel` (yield-curve nodes) and `entity_panel` (per-institution statement items). `v_catalogue_by_grain` reports counts by grain, because a catalogue that counts an auction tender as a macroeconomic series misrepresents economic breadth.

Reporting the counts was not enough on its own: a single undifferentiated catalogue is still the thing a reader opens, and it still says that this database holds thousands of macroeconomic series when most of those identifiers are one auction or one curve node. Since schema 29 there is a catalogue **per grain** — `marts.v_catalogue_scalar_series`, `v_catalogue_event`, `v_catalogue_curve_panel`, `v_catalogue_entity_panel` — and the scalar one is the macroeconomic surface. The others are complete and queryable; they are simply not a count of series about the economy.

Since schema 32 grain is declared **per worksheet as well as per source**, keyed `(source_id, source_sheet)` with `*` as the source-level rule. One grain for a whole workbook was too coarse and direct investment is the case: the source is `scalar_series`, and its `Cuadro 5` and `Cuadro 7` are foreign direct investment stocks by country — 73 and 34 country series, an entity panel wearing a scalar catalogue's clothes. Declaring them moved 214 identifiers out of the macro catalogue, which now holds 7,229.

## Workbook behaviour: cached formulas and hidden rows

Two properties of a published workbook survive into no value the parser reads, and both change what a number means.

Every number this project reads is a **cached formula result**. `readxl` does not calculate, so a workbook shipped without recalculating stores whatever was last computed, and nothing downstream can tell the difference between a value the publisher typed and one Excel last evaluated on some other machine. `raw.source_sheets.formula_cells` records how many cells on each worksheet carry a formula: 91,673 across 104 worksheets in the current release, concentrated in the economic annex, the daily BCP FX workbook and the interbank market sheet.

`hidden_rows` and `hidden_columns` record the ranges the publisher hid, packed as `12-18;44;51-53`. This matters because the parser reads them: **15,403 published observations across 13 worksheets come from rows the publisher's own reader does not see.** In the annex the pattern is benign and legible — `CUADRO 31` hides rows 13–305, `Cuadro 21 a` hides most of 11–669 — the publisher collapsing the early history of a long table so the visible sheet shows recent periods. Reading them is right. But it is not something a researcher can discover from the values, and a hidden block is also how a superseded series would look, so it is recorded and reported rather than assumed.

Neither is a defect, and `workbook_cached_formulas_and_hidden_state` is a warning that says so. What it is really for is the **next** vintage: a worksheet that was 30% formulas and is now 2%, or that has begun hiding a block it used to show, has changed behaviour in a way no cell-by-cell comparison reveals. `workbook_behaviour_changed` fires when it does. `outputs/workbook_behaviour_latest.csv` carries the per-worksheet state, ordered by how many published observations sit on hidden rows.

Both columns are read from the workbook rather than from a parsed value, so a vintage archived before schema 29 gains them from its own archived file without being re-parsed and without an observation moving.

Since schema 32 the same facts are queryable **per observation** through `marts.v_observation_source_behaviour`: `from_hidden_row` and `sheet_formula_cells` beside each value's coordinate. Recording them per worksheet was the right grain for the drift test — a sheet that has begun hiding a block has changed behaviour — and the wrong grain for a researcher holding a number. "15,403 observations come from hidden rows" is a fact about the database; "is *this* value one of them" was a question you could only answer by unpacking a packed range yourself. The view derives it rather than storing it: the ranges are on the worksheet and the coordinate is on the observation, so the join is the answer, and copying a flag onto 1.2 million rows would only create something to keep in step.

Schema 32 could close that gap for hidden rows and not for formulas, because the hidden ranges are coordinates and the formula count is a number. **`raw.report_cell_formulas` (schema 35)** keeps the coordinates — `(vintage_id, sheet_name, row_id, column_id)`, in the worksheet's own A1 coordinates, the same ones every documented observation carries — so `from_formula_cell` joins directly and the question becomes answerable per value.

It is a side table by design. `report_cell_values` is content-hashed by `report_sheet_version_id()`, and putting formula data inside that hash would re-key the entire raw layer for a diagnostic; keyed by vintage and sheet name instead, it re-hashes nothing. The A1 refs cost no extra work: `xlsx_sheet_dimensions()` was already selecting the `<f>` node set and collapsing it with `length()`, and the refs are on the parent `<c>` in the same pass. As with schema 29's counts, no source is re-ingested — formula position is a property of the archived workbook and is recovered from it.

**And the answer is concentrated, which is why the per-value grain matters.** 81,367 of 1,100,840 published documented observations — 7.4% — sit on a cell that held a formula, but they are not spread evenly:

| Source | Observations on a formula cell | Of |
| --- | ---: | ---: |
| `bcp_fx_daily` | 27,224 | 40,836 (**67%**) |
| `interbank_market` | 16,323 | 81,474 (20%) |
| `economic_annex` | 30,079 | 656,179 (4.6%) |
| `financial_indicators` | 4,232 | 158,038 (2.7%) |
| `payments` | 2,843 | 51,830 (5.5%) |

Two thirds of the daily BCP exchange-rate series are cached results of formulas `readxl` cannot recompute. That is not a defect and it is not a reason to distrust the values; it is a fact about their provenance that a researcher could not previously establish for any individual number.

## Documented complex-report model

`documented_series_snapshot` has grain `vintage × series × period`. It normalizes semantic-table Excel sources while retaining `source_sheet`, `source_row`, `source_column`, original period label, parser mode and source file. `identity_basis`, `identity_stability` and `hierarchy_status` expose identity and aggregation risk. `identity_stability = positional_lane` identifies multiple same-period source events that have equal published dimensions and no official operation key; deterministic occurrence order distinguishes them, while observed values are excluded from identity. `documented_table_catalog` records one audit row per worksheet, including parsed observations, series count, date coverage, units and hierarchy status.

The principal access views are:

| View | Grain and purpose |
|---|---|
| `v_economic_annex_latest` | Latest Annex series-period observations from 93 statistical sheets |
| `v_payments_latest` | Latest payment series-period observations, enriched where a BIC identifies a participant |
| `v_exchange_houses_latest` | Latest verified entity-item-period balance-sheet, ratio and operating observations |
| `v_credit_survey_latest` | Latest quarterly response shares and sector/general credit indices |
| `v_documented_series_catalogue` | Current series definitions and period coverage |

The additional market tables retain their natural grains:

| Object | Grain |
|---|---|
| `bond_curve_snapshot` | vintage × date × currency × risk rating × maturity |
| `securities_transactions_snapshot` | vintage × deterministic transaction identity |
| `v_securities_daily_activity` | date × currency × instrument × market × operation type × venue |

`dim_payment_participant` is sourced from the official BIC sheet. `dim_exchange_item` identifies the published exchange-house item hierarchy. Unknown unit metadata is stored as `source_units`; it is an explicit non-harmonized state and must not be aggregated across series without review.

## Financial panel model

Bank and finance-company observations remain source-aligned panel tables. Their stable grain is typically:

| Family | Grain |
|---|---|
| EEFF | vintage × date × entity × report item × currency |
| Ratios | vintage × date × entity × ratio |
| Carteras | vintage × date × entity × portfolio item × currency |
| Crédito sector | vintage × date × entity × source sector × currency |
| Crédito actividad | vintage × date × entity × detailed activity × currency |

Semantic dimensions enrich those panels:

- `dim_entity`: type-safe code, legal name, short name and ownership type;
- `dim_currency`: bulletin code and label, `currency_of_origin` (the denomination of the underlying operation) and `unit_currency` (the unit in which the reported amount is measured). `economic_currency` is a deprecated compatibility alias of `unit_currency`;
- `dim_statement_item`: published EEFF hierarchy and report code;
- `map_statement_account`: one-to-many underlying account definitions and signs;
- `dim_ratio`: published ratio hierarchy;
- `dim_portfolio_item`: published portfolio hierarchy;
- `map_portfolio_account`: underlying portfolio accounts;
- `dim_credit_activity`: 1,112 detailed activities and their bulletin-sector concordance.
- `dim_credit_sector`: 13 shared bulletin sectors linking aggregate and detailed credit views.

The `v_banks_*_documented` and `v_financial_*_documented` views preserve all raw fields and append verified semantic keys and labels. Semantic hierarchy fields use the `semantic_` prefix when a raw column has the same name.

Since schema 27 each panel row also records `source_row`, the physical worksheet row it was read from, and each panel declares `(vintage_id, source_sheet, source_row)` as its natural key, enforced by a unique index like the staging snapshots. That is what makes the panels' pre-existing duplicates *representable* rather than ambiguous: 399 rows of `raw_banks_canales_person` repeat their dimensional key, mostly `INHAB`/`REHAB` pairs and conflicting totals published on separate lines. The rows are kept as the publisher wrote them and reported in `outputs/direct_panel_duplicate_keys.csv`; guessing the missing dimension would be inventing one.

`codigo_entidad` and `codigo_moneda` are stored as **text**, not as numbers. They are labels — a leading zero is part of the identifier and a code is not a quantity — and storing them as `DOUBLE` was how a join between a panel and its reference dimension came to depend on a `TRY_CAST` round-trip surviving.

For the current bulletins, code `6900` represents operations in PYG measured in PYG. Code `6200` represents foreign-currency operations converted and reported in PYG. Therefore `6200` has `currency_of_origin = FX` and `unit_currency = PYG`; it must never be interpreted or aggregated as a USD amount.

`research.entity_panel` preserves all four currency representations needed to use this distinction:
`source_currency_code`, `currency_of_origin`, `unit_currency`, and the deprecated
`economic_currency` reporting-unit alias. Its natural key uses `source_currency_code`, not
`economic_currency`. This matters because 6200 and 6900 legitimately share the reporting unit PYG.
The release gate checks the target release for duplicate source keys and checks current
source-to-research row conservation, so a collision blocks publication rather than suppressing rows.

## Deduplicated report cells

- `report_sheet_versions` stores one content hash and metadata row per distinct source worksheet content.
- `report_cell_values` stores physical cell values once per sheet version.
- `report_sheet_vintages` links every source vintage and worksheet to its content version.
- `report_cells` is a compatibility view that expands links back to the original vintage-sheet-cell grain.

Databases upgraded from v3 retain previous full copies in `report_cells_legacy`; the compatibility view unions those rows with new sparse storage. No historical rows are discarded.

## Entity identity

`entity_id` combines institution type and source code, so `bank:2081` and `finance_company:2081` cannot collide. Current names come from the verified reference workbook. `config/entity_dictionary.csv` remains a fallback scaffold for historical codes not present in the current reference; blank fallback names are explicitly marked unavailable.

## Coverage statuses

- `curated`: guarded dates, units and statistical-series identities.
- `documented_panel`: structured panel joined to verified semantic dimensions.
- `reference_dimension`: versioned semantic-reference source.
- `documented_series`: guarded series identity derived from a documented table orientation while retaining source coordinates.
- `curated_long_format`: guarded typed CSV at its natural published grain.
- `source_units` is a unit review state, not a coverage status.

These statuses describe meaning, not file-read success. Ingestion status is tracked separately in `source_files.ingestion_status`.


## Storage layers

Every table lives in the layer that says what it is for. A search path set on every connection
keeps unqualified names resolving, so the SQL in this project does not name schemas and does
not have to; what the layers change is what a person sees when they open the catalogue.

| Layer | Holds |
|---|---|
| `raw` | Immutable file, sheet and cell evidence exactly as read, plus the reference tables |
| `staging` | Typed parser output, parser diagnostics, exclusions and curated snapshots |
| `canonical` | The curated economic layer: dimensions, facts, identity, concepts, evidence |
| `marts` | Reusable reviewed catalogues and domain marts used to build publication products |
| `research` | The stable, compact, fail-closed researcher interface |
| `audit` | Governance, review status, reconciliation and release evidence |

The assignment lives in `PROJECT_TABLE_SCHEMA` (`scripts/01_utils.R`); a table without one
stays in `main` and `validate_database()` raises `storage_layer_unassigned`.

## Physical and public keys

`fact_series_events` is keyed on `(series_sk, period, vintage_sk)` — three fixed-width values.
The previous key was two long text columns plus a date, about 99 bytes per row over 1.2 million
rows, and its index cost more than the table it indexed. The human identifiers stay on every
fact row and stay unique in their dimensions, so nothing that queries the database changed;
`series_sk` and `vintage_sk` are assigned once by `assign_surrogate_keys()` and never
reassigned, because a key that moved between runs would repoint every fact row carrying it.
Three release-gate tests assert the surrogate and the identifier never name different rows.

## Measurement evidence and economic dimensions

`series_semantic_evidence` records, per series and field, the value, its basis
(`published_label`, `published_unit`, `price_base_year`, `reviewed`) and the exact published
wording relied on. `v_series_measurement` publishes a `_basis` column beside every judgement
field, so "the source says so" and "an economist checked" are never flattened into one
populated column. Nothing the pipeline writes carries the `reviewed` basis.

`series_dimension` holds the economic dimensions that would otherwise live in a row label or a
worksheet position — `trade_flow`, `trade_classification`, `trade_regime` and `product` for the
detailed trade worksheets — in long form, because dimensions are source-specific and columns
per family would be null most of the time. `v_series_dimensions` pivots them for the marts.

## Portable source identity

`source_files.source_uri` and `archive_uri` are repository-relative and are the durable
identity of an ingested file. `source_path` and `archive_path` remain as run metadata: true of
the machine that ingested the file, and of nothing else.

**And the archive is verified, not assumed (schema 34).** `validate_archive_integrity()` re-hashes
every archived file on every release against the SHA-256 recorded for its vintage, and raises the
release-blocking `archived_vintage_unverifiable` if one is missing or has changed. The whole
point-in-time story rests on the archive: a vintage whose workbook is gone cannot be re-read,
re-parsed or re-checked, and the database would go on reporting its observations as though it could.
A vintage without its bytes is not retained; it is a row claiming to be. Measured at **0.51 seconds
for all 22 files, 104 MiB**, against a 49-second run — cheap enough that sampling, or trusting the
file size, would be a false economy.

`outputs/vintage_retention_status.csv` reports per vintage the archive state and how many vintages
that source holds. While a source holds one — which is all of them today — the row says so and says
what it costs: no revision history, and no as-of reconstruction. That is why
`series_as_of_date('2020-12-31')` returns zero rows, and it should not take an external audit to
find it out.

## Publication date, and which layer owns it

Every vintage has exactly one publication date, and it lives on `source_files`. Everything else that
carries the pair `(vintage_id, publication_date)` — the documented snapshot, the curated snapshots,
the raw panel tables and the fact table — holds a copy that `propagate_vintage_publication_date()`
refreshes from that one row. The set of tables is discovered from the catalogue, so a table added
later cannot be forgotten. `fact_publication_date_mismatch` blocks the release if any copy has
drifted, which is what the audit found: 422 facts and their snapshot rows saying 2026-12-31 while
the vintage said 2026-07-31.

Where the date itself comes from is decided by authority, not by whichever writer ran last:

| `publication_date_source` | Authority | Meaning |
|---|---:|---|
| `official_registry` | 3 | An operator recorded the publisher's release date in `config/source_vintages.csv` |
| `filename` | 2 | The official filename carries a date |
| `content_max_period` | 1 | Last resort: the latest period the content contains |
| `pending_content_inference`, `discovery_failed` | 0 | Not yet known |

An equal or higher authority may restate the date; a lower one may not. The old rule refused to
overwrite any date already present, which is why a content-derived date could never be corrected
once the parser learned to read more of the sheet.

`content_max_period` is a fallback, not a publication date, and two warnings say so.
`publication_date_inferred_from_content` lists every vintage without a registry date — the worklist
for `config/source_vintages.csv`. `publication_date_source_contradicts_content` fires when a date
*labelled* as the content maximum is exceeded by the content, which is an internal contradiction and
is how this defect first appeared.

`config/source_vintages.csv` is also the acquisition record the audit asks for: official URL, release
identifier, retrieval timestamp, retrieval method and licence, keyed by `source_id` and the file's
SHA-256. It is loaded into `raw.source_provenance`, and it is what `selection_rule = 'manifest'` reads
when a source folder holds more than one candidate file — naming the bytes rather than the moment they
reached this disk.

## Which release, and which build

`release_id` hashes the admitted source files and, when present, the canonical governed
release-scope identity/digest. That is what makes it deterministic, and it is also what makes it
insufficient on its own: change a parser and the same `release_id` names a different set of
observations. Since schema 26 `audit.build_identity` answers the other question. It
records the release, the Git commit and whether the working tree was dirty, the schema version, a
digest of `config/`, a digest of `scripts/` and `run_update.R`, a digest of `renv.lock`, and the R
version; `build_id` hashes all of them. `release_id` means "these authorized input files"; `build_id`
means "this database".

`git_dirty` answers one question — **was the code that built this database committed** — and
deliberately ignores `database/`. It had never once been `FALSE`, and the reason was not an
uncommitted tree: the identity is recorded from inside the pipeline, by which time the run has already
written to the tracked `.duckdb`, so the file the build was producing counted as an uncommitted change
against the build producing it. A flag that cannot be clear is a flag nobody reads. Everything outside
`database/` still counts, and a git call that fails records `NA`, never `FALSE`.

`audit.ingestion_runs` holds one row per release, because a release is deterministic and there is
only one of it. `audit.ingestion_run_attempts` is appended and never rewritten, so the operational
question — what happened the last several times this was run — has an answer that re-running does not
erase. Since schema 28 the attempt row is written when the run **starts**, with status `running`, and
closed from an `on.exit()` handler. It used to be written at the end, which meant the one case where
the record mattered most — a run that crashed — was the one case that left no record at all.

Two release facts follow from this. First, `stage_release()` no longer deletes and re-inserts: a
decided release is left alone while the next run builds. Re-running a bundle used to set an
already-accepted release back to `staged`, which un-published the database for the duration of the
run — schema 28 stopped that, and schema 30 removed the remaining half of it, where the *terminal*
decision on a failed rebuild could still block the row every published view was reading. Second, `source_files.first_ingested_release_id`
is named for what it is. It records the bundle a vintage *arrived in*, which is not the release a
query is reading; that is derived through `release_sources`, so a vintage reused across five releases
stops reporting the first one as the current one. `v_series_observations` carries both.

`audit.quality_flags` carries the `attempt_id` that raised each flag and is no longer deleted by
`release_id` when a run starts. Re-running a bundle used to erase the diagnostic evidence of the
build that had been accepted, which is the half of the same defect that is about evidence rather than
publication. A report about "this run" therefore scopes by attempt, not by release: the update report
was carrying 696 timing rows from eight attempts that shared a bundle where the run it described had
56.

`audit.ingestion_stage_timings` is keyed by `attempt_id` and appended rather than replaced per
release, so the history of how long a run took survives the next run. Since schema 29 it also times
the release-wide phases — reconciliation, region classification, the expected grid, missingness,
semantics, canonical, marts, validation — and not only the per-source parsing, which is how
`observation_missingness` at 21 seconds became visible as the slowest phase in the run.

## Staging keys

Every staging snapshot declares a natural key. Since schema 26 the database knows it too: a unique
index enforces it physically, and `validate_declared_natural_keys()` asserts both the key and the
table's required fields at every release, so a violation blocks rather than being found later by a
researcher. DuckDB cannot add a primary key to a populated table without rebuilding it, and rebuilding
six snapshots with every view that depends on them would be a large risk taken for a small one; the
index plus the assertion covers the same ground.

| Table | Natural key |
|---|---|
| `staging.documented_series_snapshot` | vintage, series, period |
| `staging.bond_curve_snapshot` | vintage, period, currency, rating, maturity |
| `staging.securities_transactions_snapshot` | vintage, transaction |
| `staging.consumer_confidence_snapshot` | vintage, series, date |
| `staging.eve_expectations_snapshot` | vintage, series, date |
| `staging.fx_operations_snapshot` | vintage, series, period |
| `staging.semantic_coverage` | vintage, worksheet |

## Expected observations and missingness

`staging.expected_observation_grid` is the regular period sequence a series' own declared frequency
implies, between its first and last observed period and no further — a series that starts in 2015 was
not missing 2014. It is built only for monthly, quarterly and annual series, because a daily series is
not missing the weekends, and only where the series' own periods all sit on that grid; a series that
fails that test is not regular, whatever its frequency column says.

`staging.observation_missingness` gives every expected period with no observation a reason, decided
against the raw cell layer rather than assumed. Since schema 27 the decision is made on the cell's
**text**, not only on whether a number was parsed, because what a publisher writes instead of a
number is itself a statement:

| Reason | What the cell holds |
| --- | --- |
| `blank_in_source` | Nothing. The cell is there and empty. |
| `no_movement` | A token the publisher uses for "no transactions in this period" — `s/m`, *sin movimiento*. On an interest-rate table that is not a zero and not an ordinary blank: there was no rate to report. |
| `not_available` | A token for "not available" (`s.d.`, `s/d`). |
| `suppressed` | A token for a value withheld, typically for confidentiality. |
| `formula_error` | A spreadsheet error value the publisher shipped (`#N/A`, `#DIV/0!`). |
| `source_token_unreviewed` | Some other non-numeric text nobody has adjudicated. |
| `unread_source_cell` | A number, stored as text, that no parser read. |
| `period_absent_from_axis` | The period is not on the worksheet's axis at all. |
| `axis_position_ambiguous` | A worksheet of repeated year blocks places the period at several coordinates. |
| `unreviewed` | Not yet classified. |

The tokens themselves live in `config/source_value_tokens.csv` under the same discipline as the other
registers: a source, a worksheet, the exact token, its status, the meaning, quoted evidence, a
**named** reviewer and a date. `layout_verified` is explicitly rejected as a reviewer here — a claim
about what a publisher *means* by a token is not a claim about layout, and only a person can make it.
An unregistered token is therefore never silently read as a blank; it becomes
`source_token_unreviewed`, which warns at release and blocks promotion.

The invariant to rely on is **grid = observed + explained**; a silent
third category would be the ambiguity this exists to remove. `period_absent_from_axis`,
`axis_position_ambiguous`, `unreviewed` and `source_token_unreviewed` block promotion to
`validated`; a blank cell, and a token a reviewer has explained, are answers and do not.

Since schema 30 both tables carry `vintage_id` and `build_id`. Without them the missingness a mart
published was a global mutable snapshot that could not be release-filtered at all: `v_series_missingness`
could only test whether the same `series_id` existed in accepted data, so a gap computed from a staged
or blocked vintage stayed visible whenever that series also existed in published data — which, for a
rebuild of the same bundle, is every series.

The `build_id` earns its place twice. It is also what makes the phase skippable: rebuilding a
2.4-million-row grid took 19 of the 36 seconds a reuse build spent, and since schema 32 the work is
skipped when the stored grid was computed by **this same build identity**. That is a stronger guard
than "did any source change", because `build_id` hashes the code and configuration too — editing the
missingness logic, a token register or a frequency declaration changes it and forces a full rebuild.
A guard on source changes alone would have kept a stale answer under new code, which is how schema 22
first failed to land. Measured: 19.08s to 0.03s, with an identical 20,647 rows.

`config/aggregate_identities.csv` carries the identities the publisher itself states — in a footnote,
or in a block header — expressed over worksheet **columns**, because a parser repair moves labels and
never moves columns. `published_identity_broken` is an error: if the publisher's own arithmetic does
not hold in what was parsed, either the parser is reading the wrong columns or the source has changed
shape.

Since schema 28 the check asks two questions instead of one. First, **are all the declared components
present at that period**; only then, does the total equal their sum. It used to read an absent
component as a zero, which meant a period that published the total and half the parts could pass by
arithmetic accident — the worst possible outcome, since it is exactly the period where the parser is
most likely to be wrong. Incompleteness is now reported separately as
`published_identity_incomplete`, a warning, because a publisher who reports a total without every
component has not broken an identity; the identity simply cannot be tested there.
