# Technical and macroeconomic re-audit — Paraguay Macroeconomic Database

**Re-audit date:** 2026-08-31

**Project state audited:** branch `audit4-p0-p1-p2`, commit `4451cd6`

**Recorded database build:** schema 29, build `build:edeae9186966b5c22527e74a`, commit `3c73d5c`, clean working tree at build time

**Database:** `database/paraguay_macro_pilot.duckdb`, DuckDB 1.5.5, approximately 464 MiB

**Audit mode:** read-only diagnosis; this report is the only overwritten project file

**Overall verdict:** **Not ready for general empirical research; conditionally usable for source-level inspection and manually verified descriptive work**

## 1. Executive assessment

The latest implementation resolves most of the concrete parser and metadata defects identified in the previous audit. The live database confirms that:

- all 54 R files parse;
- the current source bundle has one accepted release containing 22 completed sources, zero errors, and 35 warnings;
- all 242 reconciliation records balance, with zero recorded unclassified in-region cells and zero parser-defect cells;
- `data_not_ingested` fell from 12,371 cells to zero;
- direct investment increased from 21,113 to 33,109 observations, including correctly aligned annual and quarterly histories for `Cuadro 5` and `Cuadro 7`;
- the 18,416 `s/m` cells are now explicitly classified `no_movement`, not `blank_in_source`;
- all 30 Economic Annex `CUADRO 20` series are USD with a 1,000,000 multiplier, correcting the previous count/unit error;
- generic fact, latest-view, and documented-snapshot keys are unique; no live fact is null or orphaned;
- physical source rows and text identifiers are present in all 17 direct banking/financial panel tables;
- projection status is exposed, with 343 post-publication observations separated by `main.v_series_latest_observed` and `marts.v_series_projections`;
- build/configuration/environment digests match the present project content, and the final stored build was clean;
- per-attempt phase timing, formula counts, and hidden worksheet structure are now recorded.

These are substantial, successful improvements. The project is now operationally credible as a source-preserving ingestion, normalization, and diagnostic system.

It is still not a research-grade canonical macroeconomic database. Four issues dominate the current assessment:

1. **Release isolation is still incomplete.** The validator treats any SQL reference to `releases` as proof of filtering. `main.v_series_observations` merely left-joins accepted-release labels without excluding unaccepted facts; `marts.v_series_projections` inherits all of those rows. `marts.v_series_missingness` stores no vintage or release key and tests only whether the same `series_id` exists in accepted data. Other non-`_all` interfaces—including `main.v_fx_operations_annual`, `main.v_series_catalogue`, and the latent canonical observation views—are also unfiltered and outside the lint’s naming rule.
2. **The release identifier names only the source bundle, not the transformed data product.** Fourteen ingestion attempts and materially different schema-26 through schema-29 outputs share the same release ID. A failed schema-27 attempt changed that same accepted row to blocked. Thus an unsuccessful rebuild of an accepted bundle can still withdraw the last accepted product at the terminal decision, and historical release diagnostics are overwritten.
3. **The economic layer remains deliberately unreviewed.** All 37 table-status records are provisional; all validated marts and `marts.v_research_series` have zero rows; the canonical-series, membership, continuity, methodology, concordance, and revision tables remain empty. Of 13,985 source series, 13,102 have unreviewed stock/flow status, 13,948 unreviewed nominal/real status, 13,971 unreviewed seasonal adjustment, and 4,057 unresolved units.
4. **Point-in-time provenance is not available.** All 22 source vintages lack complete official URLs, release identifiers, retrieval timestamps, and retrieval methods. There is one retained vintage per source and no recorded data revision. `series_as_of_date('2020-12-31')` therefore returns zero observations despite long historical coverage. This is a current-snapshot database with an as-of mechanism, not a historical-vintage database.

The target architecture should continue to use the existing raw-cell, source-vintage, staging, long-fact, semantic-evidence, and audit foundations. It should be modified around immutable data-product releases, strict public-view filtering, versioned diagnostics, observed/forecast defaults, canonical economic governance, and acquisition provenance. A wholesale rewrite is not warranted.

## 2. Audit scope and coverage

| Area inspected | Role | Coverage | Limitation |
|---|---|---:|---|
| Git history from `cdd056c` through `4451cd6` | Identifies implemented changes | Full diff inventory; high-risk changes reviewed in detail | Earlier historical commits used only as context |
| `README.md`, `CHANGELOG.md`, primary `docs/*.md`, `revisiones/REVISION_AUDITORIA_5_P0_P1_P2.md` | Current contract and implementation claims | Full for active architecture/model/operations documents; targeted for revision history | Documentation claims were independently checked and not treated as proof |
| `run_update.R`, `run_tests.R`, `scripts/01`–`11`, source-specific `scripts/03_*` | Executable pipeline | Full parse; detailed review of release, publication, missingness, units, provenance, validation, canonical, and mart logic | Large parser bodies were traced by inputs/outputs and high-risk paths rather than narrated line by line |
| Active `config/*.csv` and `renv.lock` | Registry, parsing rules, semantics, provenance, governance, package versions | Full structural inspection; content review of high-risk registers | Publisher-specific economic declarations require external source evidence |
| `tests/testthat/*.R` | Regression controls | All inventoried and parsed; `test-audit5-catalogues-and-workbook.R` executed successfully | Full suite was not run because some tests invoke writable pipeline/fixture behavior |
| `database/paraguay_macro_pilot.duckdb` | Persistent analytical database | Full catalog inspection and extensive read-only SQL across schemas, keys, views, facts, releases, provenance, semantics, duplicates, gaps, and coverage | No source or database mutation was used to simulate a future release |
| Raw/current/archive source inventory | Publisher evidence | Inventory and current archive linkage; workbook behavior read from stored diagnostics | No external re-download or publisher-site verification |
| `outputs/` | Generated diagnostics and operational reports | All current report types inventoried; high-risk reports cross-checked against database contents | Some report-generation defects were found; outputs are not assumed authoritative |
| `database/backups/` | Recovery history | Count and disk use inspected | Individual backup contents were not opened |

### Safe execution performed

- Opened DuckDB with `read_only=TRUE` for all SQL diagnostics.
- Parsed all 54 R files without executing the update pipeline.
- Ran `tests/testthat/test-audit5-catalogues-and-workbook.R`; all 32 expectations passed.
- Recomputed the current code, configuration, and environment digests read-only and compared them with the latest build identity.
- Read generated CSV/Markdown diagnostics and compared their counts with live database tables.

No packages were installed, no source was downloaded, no workbook was saved, no database object was modified, and no pipeline or migration was executed.

### Evidence convention

- **Observed fact:** directly established from current code, configuration, database contents, or a read-only diagnostic.
- **Strong inference:** follows from direct evidence but would benefit from a controlled future-release test or publisher documentation.
- **Hypothesis requiring verification:** economically plausible but not safe to encode without source evidence.

## 3. Regression assessment of the previous findings

| Previous finding | Status | Evidence and residual issue |
|---|---|---|
| F-01 — public views bypass accepted releases | **Partially resolved; reopened** | Direct panels, documented latest views, market latest views, generic latest, and marts now usually filter. However `scripts/04_validate.R:1552-1567` equates any `releases` reference with filtering. `v_series_observations`, projections, missingness, FX annual, catalog, and canonical surfaces remain problematic. |
| F-02 — Annex `CUADRO 20` count/USD scaling error | **Resolved** | All 30 series now have `unit_code=USD`, `scale_multiplier=1e6`, currency USD, covering 5,480 observations. |
| F-03 — `s/m` classified as blank | **Resolved under the user-provided meaning** | 18,416 missing expected periods are `no_movement`; only 1,740 are `blank_in_source`. `config/source_value_tokens.csv` records the adjudication and reviewer. |
| F-04 — 12,371 known data cells not ingested | **Resolved for the identified regions** | `data_not_ingested=0`; `Cuadro 5` has 7,721 observations and `Cuadro 7` 4,275. Annual/Q4 overlaps agree in all 1,543 and 851 comparable rows respectively. |
| F-05 — projections indistinguishable from outcomes | **Partially resolved by explicit design choice** | Status is exposed and an observed-only view exists. The default `v_series_latest` still contains 343 projections, so it remains unsafe as an estimation default. |
| F-06 — inadequate source-vintage provenance | **Mechanism improved; data unresolved** | `available_at` exists, but it is null for all 22 current provenance rows; all remain incomplete. No historical vintages were added. |
| F-07 — canonical layer empty | **Unresolved** | Candidate worklists and guards improved, but canonical series and membership remain zero; research marts remain empty. |
| F-08 — economic metadata incomplete | **Guard improved; content unresolved** | Eligibility gates now prevent promotion. Actual reviewed coverage remains near zero. |
| F-09 — accepted release can be withdrawn by rebuild failure | **Partially resolved; still material** | An accepted row stays accepted while work runs, but `decide_release()` can set that same row to blocked at the end. One recorded attempt did exactly that for the current release ID. |
| F-10 — direct-panel ambiguous grain and numeric codes | **Physical lineage resolved; economic grain unresolved** | `source_row` and text codes are present, physical keys are unique. The 399 and 12 duplicate dimensional groups remain economically ambiguous by design. |
| F-11 — source vintage carries misleading release ID | **Mostly resolved** | Renamed `first_ingested_release_id`; query context is derived through `release_sources`. `accepted_release_id=max(release_id)` remains arbitrary when several accepted releases contain a vintage. |
| F-12 — identities coalesce missing components to zero | **Resolved** | Completeness is tested separately. Five identities now report incomplete component coverage instead of falsely passing. |
| F-13 — formula/hidden state absent | **Partially resolved** | Per-sheet counts and hidden ranges are stored. Formula expressions and per-observation hidden/formula flags remain outside the database. |
| F-14 — duplicates not governed | **Detection improved; adjudication unresolved** | A 454-group candidate report and canonical candidate list exist. No canonical alias/member decision is populated. |
| F-15 — no clean build identity | **Resolved** | Latest stored build is clean; current digests match it. HEAD differs only because the database rebuild was committed afterward. |
| F-16 — incomplete performance telemetry | **Resolved structurally** | Timings are attempt-keyed and cover release-wide phases. The update report still mixes all attempts sharing a release ID. |
| F-17 — documentation drift | **Mostly resolved** | Schema/version and major interfaces are documented. The statement that availability is never inferred from reference periods conflicts with content-max publication fallbacks. |
| F-18 — excessive backup storage | **Unresolved and larger** | Backups increased from about 7.7 GiB/roughly 22 files to about 11 GiB/30 files. |

## 4. System architecture and data lineage

### 4.1 Reconstructed pipeline

```text
current input folders
  └─ source_registry + filename pattern + newest_mtime selection
       └─ SHA-256 source vintage + archive copy/link
            ├─ raw source_files/source_sheets/report cells/direct panels
            ├─ staging source-specific snapshots
            └─ canonical dim_series + fact_series_events
                  ├─ reconciliation and source-region accounting
                  ├─ semantic evidence, expected grids, missingness, gaps, jumps
                  ├─ release-wide validation and release decision
                  └─ main latest/as-of/catalog views
                        └─ reviewed canonical membership
                              └─ validated marts (currently empty)
```

### 4.2 Current physical organization

| Schema | Base tables | Views | Purpose | Assessment |
|---|---:|---:|---|---|
| `raw` | 33 | — | Source files, provenance, worksheet/cell evidence, direct publisher-shaped panels | Strong foundation; source paths and physical evidence are retained |
| `staging` | 13 | — | Typed source snapshots, parser diagnostics, expected grid and missingness | Useful separation, but missingness is global and not vintage/release keyed |
| `canonical` | 26 | — | Long facts, series metadata, dimensions, concepts, continuity and revisions | Long physical model is sound; “canonical” economic content is still empty |
| `audit` | 19 | — | Releases, attempts, reconciliation, quality, rules, table status | Extensive, but several records are mutable per source bundle/vintage rather than immutable per build |
| `main` | — | 90 | General and source-specific access views/macros | Discoverable, but current/all/release semantics remain inconsistent for several names |
| `marts` | — | 22 | Research, domain, projection, missingness and grain catalogs | Validated domain marts are conservatively empty; two auxiliary views have release-scope defects |

### 4.3 Actual grain and observation model

The generic fact table has a unique `(series, period, vintage)` identity through surrogate keys. The current accepted/latest surface has 1,227,082 observations and 13,985 source series, covering 1945-12-31 through 2028-12-01.

| Grain | Series | Observations | One-observation series | Interpretation |
|---|---:|---:|---:|---|
| Scalar series | 7,443 | 1,009,791 | 23 | Closest to conventional macroeconomic time series, but largely unreviewed |
| Event | 4,485 | 95,477 | 2,272 | Auctions/interbank operations; not 4,485 distinct macro concepts |
| Curve panel | 1,287 | 116,766 | 117 | Yield-curve nodes by currency/rating/maturity |
| Entity panel | 770 | 5,048 | 336 | Institution/item histories, many sparse or one-period |

The per-grain catalogs are a meaningful improvement. Source-wide grain assignment remains coarse: direct investment contains country/activity panels but is assigned `scalar_series` because `config/source_grains.csv` assigns one grain to an entire source. A table- or series-level grain override is preferable where one workbook mixes structures.

## 5. Prioritized findings

| ID | Severity | Confidence | Category | Evidence | Problem | Consequence | Recommendation | Effort |
|---|---|---|---|---|---|---|---|---|
| R6-01 | Critical | High | Correctness | `scripts/04_validate.R:1518-1567`; `scripts/09_semantics.R:466-500,523-531,877-885`; stored view SQL | Release lint accepts a mere `releases` reference as filtering. `v_series_observations` left-joins but does not filter; projections inherit it; missingness has no vintage key; several public views are outside the naming rule | Staged/blocked data or diagnostics can leak through interfaces that tests certify as filtered | Define a single filtered observation relation; require restrictive lineage, not substring presence; version missingness by vintage/build; add adversarial blocked-vintage tests | Medium–High |
| R6-02 | Critical | High | Reproducibility | 14 attempts and schemas 26–29 share `release:748d...`; attempt `dd3fa...` is `release_blocked`; `scripts/02_extract_raw.R:2126-2149,2186-2196`; `scripts/06_pipeline.R:252-271` | Release ID hashes source files only, while transformed contents and decisions change by build. A failed rerun can set the already accepted row to blocked | Last known-good data can be withdrawn; old release decisions/audit evidence are not reproducible from the DB | Separate `source_bundle_id`, immutable `data_release_id` including code/config/schema, and atomic active-release pointer | High |
| R6-03 | High | High | Research usability | `main.v_series_latest`: 343 `after_publication` rows/186 series; `main.v_series_latest_observed` excludes them | General default deliberately mixes projections and realized observations | A naive estimation sample can contain future values despite documentation | Make observed-only the default or rename the mixed view to `v_publisher_statement_latest`; require explicit forecast selection | Low–Medium |
| R6-04 | High | High | Reproducibility | All 22 `main.v_source_provenance` rows incomplete; `available_at` null; one vintage/source; zero revisions; as-of 2020 returns zero | Point-in-time claims are unsupported by historical acquisition evidence | Forecasting, nowcasting, policy-event, and real-time studies risk look-ahead or empty histories | Record official release and retrieval metadata and retain every future vintage; describe current as-of as snapshot-limited until then | High/ongoing |
| R6-05 | High | High | Research usability | 37/37 table statuses provisional; validated marts and research view zero; canonical/membership/regime/continuity/concordance/revisions all zero | The governed economic catalog is unpopulated | Researchers must select source-layout series and make undocumented judgments themselves | Review and promote a small priority macro core before expanding breadth | High |
| R6-06 | High | High | Economic semantics | 4,057 unresolved units; 13,102 stock/flow, 13,948 nominal/real, 13,971 seasonal-adjustment unreviewed | Transformations lack essential semantic prerequisites | Invalid summation, deflation, seasonal comparison, or frequency conversion can look valid | Complete semantics for promoted series and prohibit generic transformation otherwise | High |
| R6-07 | High | High | Data quality | 6,522 numeric source cells across 49 sheets remain `unreviewed`; quality flag and `source_region_review_worklist.csv` | Known data loss is fixed, but completeness is not established for these regions | A sheet may still omit or misclassify source content and cannot be validated | Work through the region queue, prioritizing high-value macro tables and largest blocks | Medium–High |
| R6-08 | High | High | Economic semantics | 454 exact-signature groups/2,149 series; 30 cross-source nonzero FX/Annex groups; canonical mappings zero | Duplicate and repeated concepts are detected but not adjudicated | Double-counting, arbitrary source choice, and fragmented histories remain likely | Populate reviewed alias/primary/fragment mappings with overlap policies | High |
| R6-09 | High | High | Data model | Direct panels preserve physical rows but 399 bank and 12 finance dimensional duplicate groups remain; worklist documents conflicting totals | Physical identity is not economic identity | Aggregation by currently modeled dimensions can double-count materially different source rows | Identify missing direction/status/report dimensions from publisher definitions; keep rows excluded from aggregate marts until resolved | Medium–High |
| R6-10 | Medium | High | Correctness | `scripts/09_semantics.R:523-531` selects `n.source_sheet` after joining distinct `(series_id, source_sheet)` even though `o.source_sheet` exists | A multi-sheet series can fan out projection rows | Future projections for multi-sheet series may be duplicated | Remove the join and use `o.source_sheet`, or join on vintage/series/period | Low |
| R6-11 | Medium | High | Reproducibility | `quality_flags_latest.csv` has 33 data rows while DB has 35; `scripts/04_validate.R:2144-2145` writes before quality screens; update report uses all 488 release timings at `2159-2162` instead of the latest attempt’s 55 | “Latest” output files do not consistently describe the latest completed attempt | Auditors can see incomplete flags and repeated/mixed timing histories | Write outputs after all screens and scope operational reports by `attempt_id` | Low |
| R6-12 | Medium | High | Data quality | Five aggregate identities are incomplete for most periods; interbank total lacks all components in 3,277/3,287 periods | The fixed validator correctly refuses false equality, but configured identities provide little coverage | Aggregate/component consistency remains mostly untested | Redefine components or narrow valid periods only with publisher evidence | Medium |
| R6-13 | Medium | High | Lineage | 91,673 formula cells/104 sheets; 15,403 observations from hidden rows/13 sheets; stored at sheet level only | A value cannot be queried directly for formula or visibility provenance | Analysts cannot exclude or inspect hidden/formula-derived observations without reinterpreting sheet ranges | Expose derived per-observation flags; retain formula expression only where material | Medium |
| R6-14 | Medium | High | Maintainability | All 22 source rules use `newest_mtime`; explicit manifest selection is implemented but unused | Multiple candidate files would be selected by copy time | Wrong source vintage can become current with only a warning | Adopt manifest/hash selection for required single-file sources | Low |
| R6-15 | Medium | High | Documentation | `docs/DATA_MODEL.md` says availability is never inferred from reference period, but 12 sources use `content_max_period` and all official dates are absent | Documentation overstates point-in-time semantics | Researchers may treat inferred dates as actual availability | State the exact fallback and prohibit real-time claims until provenance is complete | Low |
| R6-16 | Medium | High | Performance | Latest attempt: missingness 18.97 s, validation 8.43 s, total about 36 s; expected grid about 2.43 million rows | Full-grid rebuild dominates current runtime and is global per run | Runtime will scale poorly with more vintages/series | Incrementalize by affected vintage/series and persist only required gaps if full grid is not queried | Medium |
| R6-17 | Low | High | Maintainability | 30 backups consume about 11 GiB versus a 464 MiB active DB | Backup growth is unmanaged | Storage cost and distribution burden grow rapidly | Define retention and external archival policy | Low |
| R6-18 | Enhancement | High | Documentation | Current HEAD is `4451cd6`; latest build records clean `3c73d5c`, while all content digests match | Commit IDs differ because the database-only rebuild was committed after the recorded build | Provenance is correct by digest but initially confusing | Document that the post-build commit contains only the database, or record a distribution artifact ID | Low |

## 6. Database architecture findings

### 6.1 Release boundary: the main unresolved engineering defect

`accepted_release_vintages_sql()` correctly defines accepted vintages as those linked to `audit.releases.status='accepted'`. Most current views now use it correctly inside their ranking subquery.

The structural lint is not sufficient. `release_filtered_object()` at `scripts/04_validate.R:1552-1567` returns true as soon as a view body contains the string `releases`. That does not establish a restrictive predicate.

Concrete cases:

- `main.v_series_observations` reads every row in `canonical.fact_series_events`. It left-joins a subquery of accepted releases only to populate `accepted_release_id`; rows with no accepted release remain in the result with a null label.
- `marts.v_series_projections` reads that unfiltered view and applies only status/deletion predicates. It is therefore not release-filtered, although the lint follows the dependency and marks it safe.
- `marts.v_series_missingness` reads a global staging table with no `vintage_id` or `release_id`. Its `EXISTS` condition matches only `series_id`. Missingness calculated from a staged/blocked vintage can remain visible whenever that series ID also exists in accepted data.
- `main.v_fx_operations_annual` selects all `staging.fx_operations_snapshot` rows and has no `_all` suffix.
- `main.v_series_catalogue` derives coverage from `main.v_series_latest_all`, contrary to its unqualified name.
- `main.v_canonical_observations` and `main.v_canonical_series_catalogue` use unfiltered `v_series_observations`. They are empty now but will leak if the canonical registers are populated.

**Observed fact:** no unaccepted facts exist in the current settled database, so row-level leakage is zero today.

**Strong inference:** a genuinely new staged or blocked vintage can be exposed through the paths above. The missingness path is especially risky because release-wide tables are deleted and rebuilt before the release decision and are not rolled back as one release transaction.

The validation test passes because it reuses the same flawed predicate. A correct adversarial test needs an isolated database containing one accepted vintage and one newer blocked/staged vintage with distinguishable values and missingness, then must query every public interface.

### 6.2 Source bundle versus data-product release

`make_release_id()` hashes sorted `source_id:sha256` pairs. This is a valid **source bundle ID**. It is not a valid identifier for a transformed database release because parser code, configuration, schema, and semantic rules determine the resulting observations.

The database demonstrates the distinction:

- the same release ID has 14 attempts;
- those attempts span schema versions 26–29 and materially different fact counts and semantics;
- one attempt was `release_blocked` with 10 errors;
- later attempts accepted the same release ID;
- `audit.releases` retains only the latest state/decision for that ID;
- `audit.quality_flags` is deleted by release ID at the start of each rerun (`scripts/06_pipeline.R:61`);
- `audit.ingestion_runs` is deleted and rewritten by release ID (`scripts/06_pipeline.R:264-268`);
- several reconciliation/governance tables are keyed by vintage rather than build.

The append-only attempt and build tables preserve useful evidence, but facts and release-wide diagnostics do not preserve the product produced by each build. A data-product release should include source bundle, code digest, configuration digest, environment digest, and schema version, with an immutable acceptance decision and an atomic pointer to the active accepted product.

### 6.3 Keys and integrity

Current integrity is strong at declared physical grains:

- zero duplicate generic fact keys;
- zero duplicate latest `(series_id, period)` keys;
- zero duplicate documented snapshot `(vintage_id, series_id, period)` keys;
- `v_series_observations` has exactly 1,227,082 rows, matching the fact table, so its current joins do not fan out;
- zero orphan facts and zero null live fact values;
- unique indexes exist on the six main staging snapshots and all 17 direct panels;
- direct-panel `(vintage_id, source_sheet, source_row)` keys have no duplicates.

The direct key is physical, not economic. This is defensible at the raw layer and insufficient for aggregation. The project correctly retains rather than guesses the duplicate publisher rows, but those panels must remain outside research aggregates until missing dimensions are documented.

No database foreign-key constraints are declared. Given DuckDB’s bulk analytical workload, logical validation can be a defensible choice. The existing referential tests must remain release-blocking because the engine is not enforcing those relationships.

### 6.4 Dates, periods, and availability

`v_series_observations` now exposes `period_start` and `period_end`, which is a material improvement over a single ambiguous date. Annual, semiannual, quarterly, monthly, and monthly-survey intervals are derived consistently; reviewed irregular wage intervals can use stored bounds.

Availability remains provisional:

- `raw.source_provenance.available_at` is null for all 22 sources;
- the view falls back to `publication_date`, and 12 publication dates are derived from content maxima;
- one FX source explicitly contradicts its content, recorded 2026-07-31 while values reach 2026-12-31;
- current facts contain only one source vintage each.

The mechanics are ready for proper vintages. The data needed to make them meaningful are not.

## 7. Data lineage and ingestion correctness

### 7.1 Source ingestion

The pipeline retains one current file for each of 22 registered sources. All current source rows are completed. Source discovery, metadata registration, parsing, publication-date propagation, source validation, and commit/rollback are executed inside source-specific error boundaries (`scripts/06_pipeline.R:66-195`). This is robust against one malformed workbook preventing diagnostics for later sources.

All source-registry rules still select `newest_mtime`. With one current candidate per source there is no observed ambiguity. The failure mode appears when an old and new file coexist: filesystem modification time is not publisher chronology. The code already supports hash-manifest selection, so this is an operational configuration gap rather than a missing capability.

### 7.2 Reconciliation and source regions

The current database has 242 balanced table reconciliations and no `data_not_ingested` cells. The direct-investment and Annex parser repairs are supported by strong internal checks:

- `Cuadro 5`: 73 annual and 73 quarterly series; 7,721 observations; annual/Q4 equality holds for all 1,543 comparable rows.
- `Cuadro 7`: 34 annual and 34 quarterly series; 4,275 observations; annual/Q4 equality holds for all 851 comparable rows.
- Annex `Cuadro 52a/52b` now reads the full three-column monthly block through July 2026.

The remaining 6,522 unreviewed out-of-region numeric cells do not prove data loss. They prove that completeness has not been established. Largest concentrations include LRM year sheets, exchange-rate layouts, interbank secondary-market layout, and numerous Annex tables. A table touched by these cells is correctly prevented from being promoted.

### 7.3 Excel behavior

Per-sheet XML metadata now records 91,673 formulas across 104 sheets and hidden rows/columns on 34 sheets. The project identifies 15,403 published observations from hidden rows in 13 sheets, including:

- Annex `CUADRO 32`: 4,342;
- `Cuadro 21 a`: 2,803;
- `CUADRO 56a`: 2,194;
- `CUADRO 33`: 1,032;
- `CUADRO 59`: 1,020.

This is a useful drift control. It does not establish that cached formula values were recalculated by the publisher, and it does not place formula/hidden flags directly on each observation. The archived workbook remains necessary to answer cell-level questions.

### 7.4 Missing-value handling

Current expected-period missingness is:

| Reason | Periods | Series | Interpretation |
|---|---:|---:|---|
| `no_movement` | 18,416 | 353 | Publisher explicitly reports no transaction/rate for the cell; not zero and not an ordinary blank |
| `blank_in_source` | 1,740 | 67 | Expected coordinate is physically blank |
| `period_absent_from_axis` | 491 | 2 | Expected period cannot be located on the source axis |

The token logic at `scripts/09_semantics.R:839-860` now inspects numeric and text content in the correct order and treats unregistered tokens as review-blocking. This resolves the prior silent classification error.

The missingness storage model remains problematic: `staging.observation_missingness` contains neither vintage nor release. It is a mutable snapshot rebuilt globally, yet it is published in a mart. Add `vintage_id`, `build_id` or `data_release_id` to make the diagnostic reproducible and release-filterable.

## 8. Duplicate and fragmented-series analysis

### 8.1 Systematic screen

The updated exact-signature report considers histories with at least six periods and finds:

- 454 exact value/date signature groups;
- 2,149 member series;
- 18 all-zero groups containing 1,220 series;
- 436 nonzero groups containing 929 series;
- 31 cross-source groups, of which 30 are nonzero;
- 180 groups with at least 60 observations.

By source membership, the largest concentrations are insurance (1,168 members), Economic Annex (408), financial indicators (200), exchange houses (129), and LRM auctions (122). Most large insurance and exchange-house groups are zero histories across economically distinct product/entity dimensions and must not be merged merely because their values match.

### 8.2 Important classifications

| Current series | Evidence | Classification | Confidence | Recommended treatment |
|---|---|---|---|---|
| 30 Annex `CUADRO 20` series and 30 `fx_operations` series | Exact signatures by concept/frequency; 5,480 dedicated observations; units now both USD millions | **Definite duplicate economic concepts across source surfaces** | High | Dedicated FX source as primary; Annex aliases and reconciliation records |
| Annex `Cuadro 14a/14b`, headline `Índice General` | 379 exact monthly observations | **Definite repeated concept** | High | One canonical index, two physical aliases |
| Annex `Cuadro 29` and `Cuadro 29 (Cont.)`, M2 | 378 exact monthly observations | **Probable source-layout duplicate/continuation** | High | One canonical series after source-layout confirmation |
| GDP at purchasers’ prices, Annex `CUADRO 6` vs `CUADRO 7` | 129 quarters; 128 equal; 2026Q1 differs by 2,998.481 | **Same accounting aggregate repeated in two presentations, with one conflict** | High | One canonical GDP with authoritative-source rule and reconciliation discrepancy; never average |
| `Gas oíl` in Annex `Cuadro 51a` vs `Gas - oil` in `Cuadro 53a` | 391 exact monthly values, identical USD-thousand scale | **Probable repeated trade subtotal across classifications** | High | Verify classification definitions; alias with precedence if economically identical |
| `1000 KWh — Energía Eléctrica` (`Cuadro 44b`) vs `Energía eléctrica (1000Kwh)` (`Cuadro 46b`) | 391 exact monthly values; one unit is KWH, the other `MIXED_PHYSICAL_UNITS` | **Probable repeated physical-volume concept with metadata inconsistency** | High | Verify table definition; harmonize unit metadata before canonicalization |
| Annex `Cuadro 52a` registered versus internal-consumption imports for products such as asphalt, coffee, and fuels | Exact 247-month histories, but customs-regime labels differ | **Legitimate distinct series whose values coincide because excluded regimes are zero** | High | Do not merge; preserve `trade_regime` dimension |
| Financial-indicator nominal vs effective rate sheets | Some exact long histories, but rate basis differs | **Legitimate distinct series** | High | Do not merge; expose `rate_basis` prominently |
| Direct-investment flow vs stock zero histories | Equality arises from all-zero histories; stock/flow differs | **Legitimate distinct series** | High | Do not merge |
| Payments opposite-direction zero histories | Direction differs despite exact zeros | **Legitimate distinct series** | High | Do not merge; preserve direction/counterparty |
| Financial-indicator same label split between an older monthly history and a 2020 one-off row | No overlap and different sheets | **Ambiguous / possible fragment** | Medium | Require publisher definition/methodology evidence before splicing |

### 8.3 Consolidation policy

Exact numerical agreement is evidence, not a merge instruction. Consolidation should require agreement on concept, population, frequency, units, seasonal adjustment, valuation, timing, and methodology. Canonical mappings should retain both physical lineages and specify primary/alias/fragment/component roles, overlap tolerance, valid dates, and conflict behavior.

## 9. Economic and semantic consistency

### 9.1 Semantic coverage

| Field | Populated by derivation | Reviewed | Residual assessment |
|---|---:|---:|---|
| Unit and scale | 13,985 | 0 explicitly reviewed | 4,057 remain unresolved source units despite non-null codes |
| Stock/flow | 883 | 0 | 13,102 unreviewed |
| Nominal/real | 37 | 0 | 13,948 unreviewed |
| Seasonal adjustment | 14 | 0 | 13,971 unreviewed |
| Transformation | 214 indexes | 0 | Most level/rate/growth semantics unreviewed |
| Valuation | 638 FOB | 0 | Most valuation bases unreviewed |

The database correctly labels these values as derived rather than reviewed. That honesty is valuable. It also means only a very small subset is semantically interpretable without returning to the source.

### 9.2 Aggregation and identities

The corrected identity validator separates missing-component coverage from arithmetic equality. Current warnings show that the selected identities are usually not testable:

- two SIPAP total identities lack all components in 50/51 periods each;
- two alias identities lack all components in 20/35 periods each;
- the interbank total lacks all components in 3,277/3,287 periods.

This may reflect genuinely unpublished components. It may also mean the configured component sets do not match the publisher hierarchy. Until verified, the identities are diagnostic examples rather than broad accounting controls.

### 9.3 Forecasts, vintages, and information sets

The project now labels 343 rows after publication:

- Economic Annex: 313, reaching 2028-12-01;
- FX operations: 30, reaching 2026-12-31.

The label is based on `period > publication_date`. It is a useful mechanical distinction but not a complete forecast model. Proper forecast data require forecast origin/vintage, target period, horizon, status, and whether a value is forecast, target, assumption, preliminary estimate, or realized observation.

Keeping both classes in `v_series_latest` is documented and defensible as “the publisher’s current statement,” but the name is unsafe for econometric use. A safe research default should contain realized observations only.

### 9.4 Methodological breaks and revisions

`canonical.methodology_regime`, `canonical.continuity_map`, and `canonical.series_revisions` contain zero rows. Consequently:

- apparent long histories cannot be assumed methodologically homogeneous;
- rebasing and classification changes are not explicitly encoded;
- source revisions cannot be studied;
- automated splicing is not justified;
- structural-break analysis cannot distinguish economic breaks from source-method changes.

## 10. Time-series inventory

| Source | Series | Observations | Coverage | Frequencies | Research assessment |
|---|---:|---:|---|---|---|
| Banking indicators | 39 | 4,914 | 2016-01 to 2026-06 | Monthly | Candidate after unit/hierarchy review |
| BCP FX daily | 12 | 40,836 | 2013-01-02 to 2026-08-14 | Daily | Strong continuity handling; needs true vintage dates |
| Compensatory FX sales | 3 | 417 | 2015-01 to 2026-07 | Monthly | Template-row defect remains fixed |
| Corporate bond curves | 1,287 | 116,766 | 2010-11-01 to 2026-07-31 | Irregular daily | Curve panel, not macro series catalog |
| Credit survey | 312 | 15,806 | 2013Q1 to 2026Q2 | Quarterly | Requires scale/weighting/methodology review |
| Direct investment | 516 | 33,109 | 1995-12 to 2024-12 | Annual, quarterly | Coverage repair successful; economic hierarchy unreviewed |
| Economic Annex | 2,764 | 656,179 | 1950-12 to 2028-12 | Annual to monthly plus irregular | Broad but heterogeneous, duplicated, and partly forecast |
| EVE | 16 | 2,760 | 2006-04 to 2026-08 | Monthly survey | Definitions and information timing need review |
| Exchange houses | 770 | 5,048 | 2016-07 to 2026-07 | Annual, monthly | Entity panel; many sparse histories |
| Exchange rates | 52 | 4,340 | 1945-12 to 2026-07 | Annual, daily, monthly | Quotation/average/end-period semantics need review |
| Financial indicators | 1,050 | 158,038 | 2011-01 to 2026-06 | Monthly | Large no-movement population; rate basis and institution dimensions matter |
| FX operations | 30 | 5,480 | 1990-12 to 2026-12 | Annual, monthly, quarterly | Canonical candidate; future periods/publication conflict unresolved |
| ICC | 12 | 1,236 | 2018-01 to 2026-07 | Monthly | Construction/base/revision review required |
| Insurance Annex | 2,050 | 34,846 | 2009-06 to 2025-06 | Annual | 917 zero-only series; dimensional panel, not breadth measure |
| Interbank market | 1,346 | 81,474 | 2010-01-04 to 2026-08-14 | Daily/irregular daily | Mostly events; aggregate identity coverage weak |
| Liquidity facility | 56 | 3,652 | 2016-01-20 to 2021-09-09 | Irregular daily | Historical endpoint and units require confirmation |
| LRM auctions | 3,083 | 10,351 | 2013-01-08 to 2026-07-30 | Irregular daily | Event/instrument data; 100% source units unresolved |
| Payments | 587 | 51,830 | 2013-11 to 2026-07 | Monthly | Direction/value/count/hierarchy require governance |
| **Generic total** | **13,985** | **1,227,082** | **1945-12 to 2028-12** | Mixed | Not a count of distinct macroeconomic concepts |

Separate current market/direct surfaces include 312,326 securities transactions and 38,922 bond-curve snapshot rows. Banking and finance-company direct panels contain roughly 900,000 source-aligned rows across 17 raw tables; they are not represented in the generic fact count.

## 11. Detailed code review

| File / subsystem | What it does | Assessment |
|---|---|---|
| `scripts/01_utils.R` | Schema routing, IDs, hashing, manifests, environment identity | Digest/build identity is strong. `accepted_release_vintages_sql()` is correct as a fragment. All active source selections still rely on `newest_mtime`. |
| `scripts/02_extract_raw.R` | Schema/migrations, raw/direct ingestion, release lifecycle, generic/latest views | Direct physical lineage and text code repair are correct. Release ID/state remains mutable across builds. `v_series_catalogue` uses `_all`; `v_fx_operations_annual` is unfiltered. |
| `scripts/03_curate_documented.R` | Documented workbook parsing, axis/unit inference, latest views | Monetary-title precedence resolves the material FX scale error. Double-header and final-axis repairs are supported by source identities. General heuristic parsing still requires table review. |
| `scripts/03_curate_expanded.R` | Bond/securities snapshots and current views | Current natural keys pass and latest views now use accepted vintages. |
| `scripts/03_reference_semantics.R` | Banking/finance dimensions and mappings | Text identifier joins are safer. A few documented mappings remain incomplete, and duplicated panel dimensions remain unresolved. |
| `scripts/04_validate.R` | Reconciliation, identities, metadata eligibility, release lint, reports | Broad coverage and separate identity completeness are strengths. Release-filter lint is semantically unsound. Quality CSV is emitted before statistical screens. Update timings are scoped by release rather than attempt. |
| `scripts/06_pipeline.R` | Orchestration, transactions, timings, decision | Source error isolation and attempt-open/close logic are improved. Same-ID accepted release can still be blocked at terminal decision; release-wide derived tables are not one atomic product snapshot. |
| `scripts/08_reconciliation.R` | Independent out-of-region classification | Successfully made known omissions visible and now records zero `data_not_ingested`. Unreviewed queue remains material. |
| `scripts/09_semantics.R` | Period bounds, observation view, as-of, dimensions, missingness | Token classification and timing fields improved. Observation/projection/missingness release scoping is defective; projection join can fan out. |
| `scripts/10_canonical.R` | Reviewer-governed canonical series, continuity, regimes, candidates | Register guards and candidate worklists are useful. Public canonical observations inherit unfiltered facts; actual registers remain empty. |
| `scripts/11_marts.R` | Domain marts, grain catalogs, screens | Validated marts correctly remain empty. Per-grain catalogs solve count inflation. Source-wide grain classification is coarse. |
| `run_tests.R`, tests | Regression entry and fixtures | Test entry no longer installs. Audit-5 test passes but validates the flawed release-filter recursion, so passing does not prove isolation. |

## 12. Data-quality and validation assessment

### Controls that now work well

- Content-addressed source and worksheet storage.
- Source-specific transactions and rollback.
- Physical/natural key uniqueness on facts, snapshots, and direct panels.
- Publication-date mirror reconciliation.
- Full parser-region reconciliation.
- Independent out-of-region accounting.
- Explicit source tokens and missingness reasons.
- Unit/scale consistency guards and title precedence.
- Table-status and semantic eligibility gates.
- Separate incomplete/equality aggregate tests.
- Per-grain catalogs.
- Workbook formula/hidden-state drift metadata.
- Append-only ingestion attempts and phase timings.
- Clean build/config/environment identity.

### Highest-value additional tests

1. **Adversarial release isolation:** in an isolated temporary DB, create accepted A and staged/blocked B with different values, projections, missingness, direct rows, catalogs, and canonical membership. Assert every non-`_all` interface returns only A.
2. **Immutable product release:** assert a failed rerun cannot change the active accepted build ID or its fact/diagnostic checksums.
3. **Public-view contract:** maintain explicit metadata (`public_scope = current/all/history/diagnostic`) rather than inferring intent only from names.
4. **Missingness key integrity:** require vintage/build/release in expected-grid and missingness keys; reject any public row without accepted membership.
5. **Projection uniqueness:** assert `marts.v_series_projections` is unique by vintage/series/period and equals the after-publication subset of the accepted observation surface.
6. **Output/database agreement:** compare every `*_latest.csv` count and distinct check list to the live latest attempt after all phases finish.
7. **Active release uniqueness:** assert exactly one active data-product release, while historical accepted releases remain immutable.
8. **Canonical overlap:** for every declared alias/fragment, require units/frequency/status agreement, overlap completeness, residual tolerance, and explicit conflict policy.
9. **Semantic promotion:** require reviewed stock/flow, nominal/real, adjustment, timing, valuation, definition, and source evidence before mart eligibility.
10. **Source-region completion:** fail table promotion on unreviewed regions, as now; add priority dashboards by economically important table rather than cell count alone.
11. **Direct-panel aggregation safety:** require all modeled dimensions to identify an economic row before any aggregate mart uses the panel.
12. **Revision checks:** compare new vintages with prior accepted vintage for additions, revisions, disappearances, unit/base changes, and historical rewrites.
13. **Formula cache risk:** alert on formula-count change and optionally compare formula-cell cached values with a separately recalculated controlled copy.
14. **Frequency and timing:** use variable-specific calendars and end/average conventions rather than only generic monthly/quarterly grids.
15. **Rebuild determinism:** compare product-release table checksums and schema signatures from two clean isolated rebuilds.

## 13. Performance and scalability

The database remains small enough for DuckDB, and current reuse builds complete in roughly 36 seconds. Latest release-wide timings identify actual bottlenecks:

| Phase | Seconds | Assessment |
|---|---:|---|
| Observation missingness | 18.97 | Dominant; rebuilds global expected grid/missingness |
| Validation | 8.43 | Significant but proportionate to broad integrity checks |
| Series semantics | 0.85 | Acceptable |
| Governance registers | 0.73 | Acceptable |
| Source-region classification | 0.64 | Acceptable |
| Other release-wide phases | Under 0.5 each | Not current bottlenecks |

Per-source reuse/validation is generally 0.14–0.32 seconds. A full parser rebuild may have different bottlenecks; the latest attempt is a reuse run.

The expected grid contains roughly 2.43 million rows to explain 20,647 missing periods. That is acceptable at current size but should be incremental by affected vintage/series. Do not optimize before fixing release/version semantics: an efficient mutable global table would still be incorrect.

Backup storage is now the largest physical inefficiency: roughly 11 GiB across 30 database files, about 24 times the active database size. This does not affect query speed but harms portability and will continue growing.

## 14. Reproducibility and maintainability

### What can currently be reproduced

- The present source files are identified by SHA-256 and archived.
- The current code/config/environment content matches the latest recorded build digests.
- The environment is locked to R 4.5.1 and package versions through `renv.lock`.
- The final stored build was clean.
- Current facts and reports can plausibly be rebuilt from the retained source bundle, subject to executing the writable pipeline.

### What cannot currently be reproduced from the database alone

- The exact transformed product associated with each of the 14 historical attempts sharing the release ID.
- The accepted database state before and after the recorded blocked attempt, except through external backups/Git.
- Historical publisher information sets or data revisions.
- Official acquisition/release timing for any of the 22 current source vintages.
- Cell-level formula expressions or visibility flags without reopening archives.
- A canonical research dataset, because no economic review decisions exist.

The project is maintainable for its primary developer but still demands substantial domain judgment. The candidate worklists are a good way to make that judgment tractable. The next maintainability step should be to reduce ambiguity in public contracts—current versus all, source bundle versus product release, source series versus canonical concept—not to add more parser abstraction.

## 15. Econometric research-readiness

| Use case | Current readiness | Reason |
|---|---|---|
| Parser/source reconciliation | Ready | Strong raw lineage, hashes, coordinates, transactions, and balanced tables |
| Manual source-level descriptive analysis | Conditionally usable | Series must be individually verified and observed-only filters used |
| Automated descriptive dashboards | Not ready generally | No validated tables; semantics and canonical selection unresolved |
| Time-series regressions, VAR/SVAR, local projections | Not ready | Units, stock/flow, nominal/real, adjustment, breaks, and duplicate aliases unresolved |
| Monetary-policy event studies | Not ready | True availability/vintage timing absent; event and scalar concepts require curation |
| Fiscal analysis | Not established | Fiscal mart empty and definitions unreviewed |
| External-sector analysis | Improved but not ready | Direct-investment coverage repaired; duplicate FX/trade concepts and provenance remain |
| Forecasting/nowcasting/backtesting | Not ready | No historical vintages; default current view contains forecasts; inferred publication dates |
| Business-cycle analysis | Not ready | Seasonal adjustment, real/nominal, rebasing, and methodology regimes mostly absent |
| Mixed-frequency models | Not ready | Mechanical period bounds improved, but actual release calendars and availability are absent |
| Structural-break analysis | Not ready | Methodology and continuity tables empty |
| Banking/entity panels | Not ready for aggregate research | Physical keys fixed; duplicated economic dimensions unresolved |

Interim empirical use is defensible only for a manually chosen series after verifying definition, unit/scale, timing, adjustment, stock/flow, nominal/real status, observed-only sample, complete source region, duplicate/fragment status, and the absence of a real-time claim.

## 16. Recommended target architecture

### 16.1 Separate source bundles from data products

Use three identities:

1. `source_bundle_id`: hash of source vintages, equivalent to the current release ID.
2. `build_id`: code/config/environment/schema execution identity, already substantially present.
3. `data_release_id`: immutable product identity derived from source bundle + build identity, with a decision and complete table/diagnostic checksums.

Maintain a one-row active pointer:

```sql
CREATE TABLE active_data_release (
  singleton BOOLEAN PRIMARY KEY CHECK (singleton),
  data_release_id VARCHAR NOT NULL,
  promoted_at TIMESTAMP NOT NULL,
  promoted_by VARCHAR NOT NULL
);
```

A build writes a new product namespace or versioned rows. Validation completes. One transaction inserts the immutable decision and swaps the active pointer. Failure never changes the previous pointer.

### 16.2 One safe observation relation

Every public current view should descend from one relation that joins the active data release restrictively. Diagnostic/all-history relations should end in `_all` or `_history`.

Required observation fields:

- canonical/source series ID;
- source vintage and data release;
- reference period start/end;
- `available_at` with evidence type;
- observation type (`observed`, `forecast`, `target`, `estimate`);
- forecast origin/horizon where applicable;
- value, source unit, multiplier, base-unit value;
- value status (`reported`, `no_movement`, `blank`, `suppressed`, `unread`);
- physical source cell/row and formula/hidden flags;
- quality status.

### 16.3 Canonical economic layer

Retain:

- `source_series` for every publisher/layout identity;
- `canonical_series` for reviewed economic concepts;
- `canonical_membership` with `primary`, `alias`, `fragment`, and `component` roles;
- methodology regimes and continuity mappings;
- structured dimensions for sector, institution class, instrument, direction, rate basis, currency, valuation, seasonal adjustment, and trade regime;
- separate event, entity-panel, and curve facts.

The current empty registers are appropriate scaffolding. Populate them incrementally, starting with GDP, CPI, IMAEP, policy/interbank rates, exchange rates, monetary aggregates, credit/deposits, reserves, trade, fiscal balance, external debt, and direct investment.

### 16.4 Version diagnostics

Expected grid, missingness, reconciliation, semantic coverage, flags, and timings should be keyed by `data_release_id` or `build_id`. “Latest” output files should be derived after the active product is decided and identify the attempt/build in every row or header.

## 17. Specific consolidation recommendations

| Priority | Current series | Canonical concept | Agreement | Merge risk | Treatment |
|---|---|---|---|---|---|
| P0 | 30 Annex `CUADRO 20` / dedicated FX pairs | FX purchases, sales, net by sector and frequency, USD millions | Exact over all audited paired histories | Future divergence/revisions | Dedicated primary; Annex aliases; blocking overlap test |
| P1 | Annex `Cuadro 14a/14b` headline index | General consumer price index | 379 exact months | Base/method changes | One canonical ID with two aliases after definition check |
| P1 | Annex `Cuadro 29` / continuation M2 | M2 | 378 exact months | Continuation layout could change | Continuity alias with future overlap check |
| P1 | GDP purchasers’ price in production/expenditure tables | Headline GDP by frequency/base/price type | 128/129 quarters equal | One current discrepancy and accounting revisions | Primary presentation plus reconciliation flag; never average |
| P1 | Repeated gas-oil and other trade subtotals | Product-flow-unit concepts | Long exact histories | Classification/regime scope | Verify dimensions; alias only when definitions match |
| P1 | Electricity physical-volume pair | Electricity export/import physical quantity as applicable | 391 exact months | Unit metadata conflict and potentially different table scope | Correct metadata and verify title/direction before mapping |
| P2 | Financial nominal/effective exact histories | Separate nominal/effective rates | Values sometimes exact | Economic basis differs | No value consolidation; dimension/naming consolidation only |
| P2 | Insurance zero-only products | Dimensional insurance reporting combinations | Identical zeros | Dropping rows loses reported coverage | Preserve; mark zero-only/sparse |
| P2 | `Cuadro 52` registered/internal/tourism imports | Separate customs-regime measures | Some exact histories | Regime is economically material | Never merge solely on equality |
| Verify | Nonoverlapping financial-indicator same-label fragments | Potential continuous rate concept | No overlap | Methodology/sheet definition unknown | Source verification before splice |

## 18. Prioritized remediation roadmap

### P0 — critical

| Recommendation | Reason / benefit | Dependencies | Difficulty | Affects |
|---|---|---|---|---|
| Introduce immutable data-product releases and an atomic active pointer | Prevents failed rebuilds from withdrawing prior accepted output and makes each transformed product reproducible | Schema migration and versioned writes | High | Architecture, database, workflow |
| Rebuild release filtering around one restrictive base relation | Eliminates staged/blocked leakage through observations, projections, missingness, catalogs, FX annual, and canonical views | Product release identity | Medium–High | SQL views, tests |
| Add vintage/build keys to expected-grid and missingness tables | Makes missingness reproducible and genuinely release-filterable | Release redesign | Medium | Schema, validation |
| Make observed-only access the research default or rename the mixed latest view | Removes the easiest route to look-ahead contamination | View contract decision | Low | Views, documentation |

### P1 — high priority

| Recommendation | Reason / benefit | Dependencies | Difficulty | Affects |
|---|---|---|---|---|
| Record complete official provenance and retain every new source vintage | Enables genuine as-of and revision research | Acquisition process | High/ongoing | Metadata, workflow, storage |
| Review 6,522 unreviewed source-region cells | Establishes full-sheet completeness for promotion | Publisher/layout review | Medium–High | Config, documentation |
| Populate a high-value canonical macro core | Produces economically distinct, trustworthy research variables | Named economist/reviewer | High | Metadata, marts |
| Complete semantic fields for the canonical core | Makes aggregation, transformations, and comparisons valid | Source definitions | High | Metadata, documentation |
| Adjudicate top duplicate/fragment candidates | Prevents double counting and arbitrary source selection | Canonical model and source review | Medium–High | Mappings, views |
| Resolve direct-panel duplicated economic dimensions | Enables safe banking/finance aggregation | Publisher documentation | Medium–High | Data model, marts |
| Correct projection join and public catalog naming/scope | Removes latent fan-out and current/all ambiguity | Public-view inventory | Low | SQL, tests |

### P2 — useful

| Recommendation | Reason / benefit | Dependencies | Difficulty | Affects |
|---|---|---|---|---|
| Fix generated “latest” reports to use the latest attempt after all screens | Aligns files with the live database | Attempt/build IDs | Low | Reporting |
| Use explicit manifest/hash selection for all required sources | Prevents mtime-based source mistakes | Operator registry workflow | Low | Config, operations |
| Add table/series-level grain overrides | Correctly separates mixed source structures | Grain review | Medium | Metadata, catalogs |
| Expose per-observation formula/hidden flags | Makes source behavior directly queryable | Existing sheet metadata/source coordinates | Medium | Views/raw metadata |
| Incrementalize expected-grid/missingness computation | Reduces the 19-second dominant phase | Versioned diagnostics | Medium | Performance |
| Populate methodology regimes and continuity mappings | Supports break-aware time series | Canonical review | Medium–High | Metadata |
| Correct availability documentation | Prevents false real-time interpretations | None | Low | Documentation |

### P3 — optional

| Recommendation | Benefit | Dependencies | Difficulty | Affects |
|---|---|---|---|---|
| Define backup retention and external archival policy | Controls 11 GiB and growing local storage | Recovery requirements | Low | Operations/storage |
| Add researcher-facing semantic search/catalog documentation | Improves discovery after review | Canonical core | Medium | Views/docs |
| Add approved unit-aware transformations | Reduces repeated analyst code | Complete semantics | Medium | Marts |
| Record a distribution artifact ID after committing the rebuilt DB | Clarifies commit/build handoff | Release redesign desirable | Low | Provenance/docs |

## 19. Unresolved questions and limitations

1. Which database product should remain active if the same source bundle is rebuilt with new code and fails validation? The current model has no separate product identity.
2. Is `main.v_series_observations` intended as an all-history diagnostic or a public accepted-release view? Its name and documentation imply the latter; its SQL implements the former.
3. Should `main.v_series_catalogue` describe all parsed series or current accepted series? It currently uses `v_series_latest_all` without an `_all` name.
4. Are the 30 FX-operation future periods forecasts, targets, formula placeholders, or complete-year aggregates? The recorded July 2026 publication date contradicts content through December 2026.
5. What are the official publication and retrieval times for every current vintage?
6. Which of the 6,522 unreviewed numeric cells are axes/layout versus unparsed data?
7. What dimensions distinguish the 399 bank and 12 finance duplicated panel groups, especially conflicting totals?
8. Which GDP presentation is authoritative for 2026Q1 and future discrepancies?
9. Are exact repeated trade quantities aliases, accounting identities, or distinct classification presentations?
10. Were all cached workbook formulas recalculated by the publisher before distribution?
11. Are all 15,403 observations from hidden rows intended published history rather than withdrawn/superseded material?
12. The full regression suite and clean rebuild were not executed because the audit remained read-only. Dynamic failure behavior is established by code and stored attempts, not by a new destructive simulation.
13. No publisher websites or external documentation were consulted. Economic interpretations requiring official definitions remain hypotheses until reviewed.

## 20. Final assessment

### What is already working well?

The project now has a strong source-engineering foundation: hashes, archives, source transactions, physical row/cell lineage, unique fact/snapshot keys, balanced reconciliation, explicit missing-value tokens, repaired direct-investment parsing, corrected monetary units, phase timings, workbook behavior diagnostics, environment locking, and honest promotion gates. Most previous concrete parsing defects were successfully fixed.

### What remains unsafe or unreliable?

Release isolation and release identity are not yet correct for multiple builds/vintages. Several interfaces can expose unaccepted facts or diagnostics despite passing the lint. The general latest view remains forecast-inclusive. Provenance does not support real-time analysis. Economic semantics, duplicate adjudication, methodology breaks, continuity, and canonical series remain largely unreviewed, and no validated research row exists.

### What should be addressed first?

Redesign the release boundary around immutable data products, fix every public view to depend on one restrictive accepted relation, version missingness/diagnostics, and make the realized-observation contract unmistakable. Then complete acquisition provenance and curate a small canonical macro core rather than attempting to review all 13,985 source identifiers at once.

### Can the database be used for empirical work now?

Only for narrowly scoped, manually verified descriptive work that uses observed-only rows and does not claim real-time validity. It should not yet be used as a general automated input to regressions, VAR/SVAR models, local projections, nowcasting, forecasting evaluation, business-cycle analysis, structural-break analysis, or banking panel aggregation.

### Final verdict

**Not ready for general empirical research.** The current architecture should be **preserved at the raw, staging, long-fact, and audit foundations, but materially modified at the release, diagnostic-versioning, public-view, canonical, and research layers**. The project has moved from broad parser risk to a smaller set of architectural and economic-governance blockers. Resolving those blockers would place it on a credible path to becoming a clean, canonical, auditable, research-grade macroeconomic database for Paraguay.
