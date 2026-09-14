# Schema 43 independent release-acceptance review

Review date: 2026-09-13. Intended product: exploratory/discovery release, with `research.*` retaining its stricter admission contract.

**Decision: APPROVE CONDITIONALLY.** The candidate provides useful broad discovery and mechanically sound preliminary observations. Two pre-release conditions remain: correct misleading worksheet lineage in the new interfaces, and produce an accepted schema-43 product through the existing isolated release workflow. The exact conditions appear at the end. Economic review debt, incomplete official provenance, and further catalogue enrichment are not additional pre-release conditions for this stated product.

## Scope and method

Read completely: `docs/audits/exploratory_layer_plan.md`, `docs/audits/exploratory_layer_implementation_report.md`, `docs/RESEARCH_DATABASE_GUIDE.md`, `docs/audits/audit_resolution_plan.md`, `docs/audits/audit_resolution_report.md`, and the prior root `AUDIT_REPORT.md`. The alternative prior-audit path mentioned in the plan does not exist. Inspected the current executable catalogue, research, validation, source-coordinate, and release-path code; public-interface contracts; and relevant tests. Consulted the data-model documentation for the distinct raw and parser coordinate systems.

Database inspection used R DBI and DuckDB v1.5.5 with `read_only=TRUE`, without the project connection helper or setting `search_path`. Production and the candidate were opened only read-only. A separate in-memory connection attached the candidate with `READ_ONLY` for binding tests. No database was rebuilt or modified, no release decision was written, and no source or configuration file was edited. This report is the sole requested output file.

| Artifact | Identity verified by SHA-256 |
|---|---|
| Candidate: `/private/tmp/paraguay-exploratory-schema43.60oOOT/paraguay_macro_schema43.duckdb` | `23d8feacf1492fc2847d05c5e5f55342f97265f525342a1a76696a7c1af0a015` |
| Production: `database/paraguay_macro_pilot.duckdb` | `17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180` |

The hashes match the implementation report. `SELECT max(version) FROM audit.schema_version` returns **43** in the candidate. Read-only SQL checks below were executed independently. The reported prior automated-test passes were not treated as independently rerun results: the focused tests create and migrate database copies, and the regression/smoke suites perform builds and generate files, contrary to this review's read-only instruction. I inspected those tests, including their negative fixtures. No new fault-injection database was created.

## Findings

### F01 — Worksheet lineage is wrong or missing on otherwise valid observations

**Classification: release condition.**

`explore.observations` takes `source_sheet` and `table_title` from the one-row candidate profile, while taking `source_row` and `source_column` from the observation's staging record. These fields do not necessarily describe the same worksheet. This prevents reliable source inspection, a central purpose of this release.

Executed:

```sql
SELECT o.source_id, count(*) AS wrong_sheet_rows,
       count(DISTINCT o.candidate_id) AS affected_candidates
FROM explore.observations o
JOIN staging.documented_series_snapshot d
  ON d.series_id=o.candidate_id
 AND d.period=o.source_period_date AND d.vintage_id=o.vintage_id
WHERE o.source_sheet IS DISTINCT FROM d.source_sheet
GROUP BY o.source_id;
```

| Source | Wrong/missing sheet rows | Candidates |
|---|---:|---:|
| `bcp_fx_daily` | 37,800 | 12 |
| `financial_indicators` | 1,743 | 15 |
| Total | **39,543** | **27** |

The same comparison finds **37,800 differing table titles** and **zero differing values**. Event and entity-panel retrieval have zero sheet/title/value differences against their staging rows. Curve candidates use the separately declared fact/vintage-only lineage path.

Concrete example: candidate `bcp_fx_daily:op_divisas_datos_diarios:0957433db1b1c1cef39b7c41`, reference date `2013-01-07`, value approximately `0.08239141`, row **17**, column **14**. Retrieval named `OpDivisas2016(DatosDiarios)`, whose cell contains zero. Staging names `OpDivisas2013(DatosDiarios)`, whose cell contains the retrieved value. All 12 BCP FX candidates span **14 actual worksheets each**; a single profile sheet cannot stand for every observation. The selected profile sheet is not a reliable observation locator.

For `financial_indicators:x8:bf7ada9ae565830aeb0be353`, retrieval retains row/column/value but has null `source_sheet`; staging retains worksheet `8`. All 15 affected financial-indicator profiles nevertheless say `coordinate_lineage_status='complete_for_current_observations'`.

I checked the affected rows against `main.v_report_cells_a1` using **staging's** worksheet and coordinates: both sources have **zero missing raw cells and zero numeric differences**, at tolerance `1e-8 * greatest(1,abs(value))`. The corresponding complete scalar staging-to-A1 comparison has no source with a missing cell or numeric discrepancy. This establishes that the observed defect is in exposed lineage; it does not establish corrupted publisher values. Direct joins to cropped `raw.report_cell_values.row_id/column_id` are invalid here; `docs/DATA_MODEL.md` explicitly requires the A1 translation.

**Code evidence:** `scripts/13_explore.R::create_catalog_explore_views()`, the `titles` and `lineage` CTEs and `observation_select`. The latter selects `s.source_sheet,s.table_title` beside `d.source_row,d.source_column`. The profile's completeness calculation counts staging matches rather than testing the full exposed locator. `main.v_series_titles` reads `canonical.series_titles`, which cannot supply missing/current observation-specific worksheet names in these cases. `tests/testthat/test-exploratory-layer.R` checks that coordinates exist for one candidate, but does not check that the published sheet/row/column locates its value.

**Required remedy:** use available observation-specific sheet/title lineage at retrieval; make profiles explicitly represent multiple worksheets or incomplete sheet lineage. Preserve exact worksheet text and existing candidate IDs and values. Verify every documented exploratory row against its staging locator and the A1 source relation, with focused regression coverage for both cases above. A profile must not claim a complete usable locator while dropping a worksheet available in staging. No economic reinterpretation or source re-ingestion is needed to establish this correction.

### F02 — The retained artifact has no schema-43 product acceptance record

**Classification: release condition.**

Executed:

```sql
SELECT * FROM audit.active_data_release;
SELECT data_release_id, schema_version, status, error_count, warning_count
FROM audit.data_releases ORDER BY decided_at DESC LIMIT 1;
SELECT count(*) FROM audit.data_releases WHERE schema_version=43;
SELECT count(*) FROM audit.build_identity WHERE schema_version=43;
```

The pointer names `build:57fe1ff64fb654508b2a8f0a`, source bundle `release:748d41036c3a73638a1c2086`. Its accepted decision is **schema 41**, with **0 errors and 37 warnings**. There are **zero** schema-43 data-release records and **zero** schema-43 build-identity records. Profiles report `database_schema_version=43`, but `build_schema_version=41` and code digest `dcd5bd4ffc0d6ce3233af48f`.

There are zero current error rows in `research.quality_flags`. However:

```sql
SELECT count(*) FROM audit.quality_flags
WHERE release_id='release:exploratory-schema43-final-dimensions';
```

returns **zero rows of any severity**, not a persisted schema-43 accepted decision. Absence of error flags under this validation label cannot independently prove that the normal product-release gate ran and accepted these interfaces. The two historical errors in the full quality-flag table are not current errors and are not release blockers by themselves.

**Code/document evidence:** `scripts/06_pipeline.R::run_isolated_update()` verifies that the accepted candidate's active pointer names the build just produced before replacement. `docs/OPERATIONS.md`, acceptance checklist, likewise requires the pointer to name this build. The implementation report explicitly describes the retained artifact as a validation migration and calls for the normal release workflow from a clean reviewed commit. `docs/RESEARCH_DATABASE_GUIDE.md` requires a clean-commit build for a citable artifact.

**Practical consequence:** directly copying this file over production would publish changed interfaces under the old accepted product identity. Retaining the old source vintage is correct; retaining the old product decision as authorization for schema 43 is not. Produce and accept a distinct schema-43 build through the existing candidate/transaction/decision/pointer workflow, recording the actual code/configuration identity and zero release-blocking errors. Do not rewrite the old decision or invent a new statistical vintage.

### F03 — Discovery and scalar retrieval are useful across the required domains

**Classification: no issue**, subject to F01's lineage correction.

Searches of `researcher_name`, `full_series_path`, and `table_title` found relevant candidates in all seven requested domains. For each exact ID below I executed `catalog.profile(ID)` and `explore.series(ID)`, checked a single profile, checked that the retrieved row count equals `observation_count`, and checked candidate ID, tier, and warning codes on every retrieved row.

| Domain / example | Exact candidate ID | Rows | Tier |
|---|---|---:|---|
| Macroeconomic: PIB a precios de comprador | `economic_annex:cuadro_1:0a012e9b809e605737c253e0` | 35 | `research_ready` |
| Monetary: BM — Base Monetaria | `economic_annex:cuadro_21:2bf58454c90affb85cd6091b` | 378 | `exploratory_structurally_valid` |
| Financial: persons with credit, total | `banking_indicators:x1:06bffc92908b1fc0cf19dee6` | 126 | `exploratory_structurally_valid` |
| External: Exportaciones F.O.B (Crédito), annual | `economic_annex:cuadro_37:44de3a29693f598b8de1a6bb` | 18 | `exploratory_structurally_valid` |
| Fiscal: Ingresos Tributarios, monthly | `economic_annex:cuadro_36:1b01dbe94e4838a3e0b66c6b` | 138 | `exploratory_structurally_valid` |
| Prices: Servicios básicos — Electricidad | `economic_annex:cuadro_13:1e5a8331004342d21b305402` | 463 | `exploratory_structurally_valid` |
| Real sector: IMAEP Serie Original | `economic_annex:cuadro_9:fc9a02c5dcc0573b3c038553` | 390 | `exploratory_structurally_valid` |

These are examples of discoverability, not new economic certifications. The profiles distinguish frequency, unit, scale, source path, date span, hierarchy state, and review status. For example, exports have 18 annual observations spanning 2008–2025, USD/millions, MBP6 table context, unreviewed economic fields, and **11 warnings**. Fiscal receipts have PYG/billions, monthly frequency, 2015–2026 coverage, and **10 warnings**. These distinctions prevent accidental equality assumptions based on a shared label.

Every exploratory interface carries `validation_tier`, `status_code`, `concise_warning`, and `warning_codes`. Preliminary rows explicitly say that mechanical checks pass while meaning, completeness, continuity, and comparability require verification. Research-ready profiles expose the separate research assurance. A user does not have to read internal implementation documentation to distinguish the tiers.

**Code evidence:** `scripts/13_explore.R`, `assembled`, `tiered`, `classified`, `warned`, and both lookup macros. The guide's monthly-price search returns **192 candidates**. The sample GDP candidate also retrieves **35 rows** through `research.observations_latest_actual`, and its research catalogue assurance is explicitly `rule_certified`.

### F04 — Current exploratory integrity, withholding, and source membership pass

**Classification: no issue.**

Executed on each of `explore.observations`, `explore.events`, `explore.panel_observations`, and `explore.curve_observations`:

```sql
SELECT count(*) AS rows, count(DISTINCT candidate_id) AS candidates,
       count(*)-count(DISTINCT(candidate_id,reference_period_start)) AS duplicates,
       count(*) FILTER (WHERE value IS NULL OR NOT isfinite(value)
         OR reference_period_start IS NULL OR reference_period_end IS NULL
         OR NOT isfinite(reference_period_start) OR NOT isfinite(reference_period_end)
         OR reference_period_end<reference_period_start
         OR observation_status IS DISTINCT FROM 'observed') AS bad_rows
FROM explore.observations; -- Repeat for each other interface.
```

| Interface | Candidates | Rows | Duplicate keys | Bad rows |
|---|---:|---:|---:|---:|
| `explore.observations` | 6,881 | 957,627 | 0 | 0 |
| `explore.events` | 4,486 | 95,560 | 0 | 0 |
| `explore.panel_observations` | 984 | 17,044 | 0 | 0 |
| `explore.curve_observations` | 1,287 | 116,766 | 0 | 0 |

Catalogue IDs are unique. Left joins of each exploratory relation to `catalog.series` find **zero orphan rows** and zero discrepancies in tier, warning codes, full path, or current vintage. Joining each observation back to `main.v_series_latest` by candidate/vintage/published period finds **zero missing rows or changed values**. Status, warning text/codes, source ID, vintage, source file, and code digest are non-null throughout. F01 separately addresses whether the sheet locator and build identity are adequate.

An anti-join of scalar exploratory vintages to `audit.release_sources`, `audit.active_data_release`, and its accepted `audit.data_releases` row returns **0**. The stored definition of `main.v_series_observations` restricts facts to the active source bundle; `main.v_series_latest` selects only `observation_status='observed'`. All four exploratory relations descend from that relation. No projection rows enter exploration.

Executed withholding checks:

```sql
SELECT count(*) AS candidates, sum(observation_count) AS observations,
       count(*) FILTER(WHERE observation_interface IS NOT NULL) AS interfaces
FROM catalog.series WHERE validation_tier='candidate_needs_review';

SELECT count(*) AS candidates, sum(observation_count) AS observations,
       count(*) FILTER(WHERE validation_tier='candidate_needs_review') AS withheld
FROM catalog.series
WHERE data_structure='scalar_series' AND non_missing_observation_count<=2;
```

Results: **347 / 39,742 / 0**, and **25 / 27 / 25**, respectively. Joining `explore.observations` to candidates with positional/non-semantic identity, fewer than three observations, or withheld/invalid tiers returns **0**. Short event and cross-sectional variants remain in special interfaces, as intended.

**Code/test evidence:** `scripts/13_explore.R` checks malformed bounds, null/non-finite values, normalized duplicate/conflict counts, applicable series/source-table errors, and invalid table states before admission or special-grain routing. `scripts/12_platform.R::validate_platform_contracts()` adds release errors for catalogue, scalar, special-grain, and warning reconciliation failures. `tests/testthat/test-exploratory-layer.R` includes a deliberate normalized-period collision and requires invalid tier plus zero macro rows. Current invalid-tier population is **0**; the negative fixture was inspected, not independently injected. This review establishes the current population and executable controls, not an exhaustive proof against every possible future malformed input.

### F05 — Candidate and source-preservation accounting is credible, with explicit limits

**Classification: no issue** for the claimed candidate totals; remaining discoverability limitations are F07.

```sql
SELECT validation_tier, data_structure, count(*) AS candidates,
       sum(observation_count) AS observations
FROM catalog.series GROUP BY ALL ORDER BY 1,2;
```

| Tier / structure | Candidates | Actual observations |
|---|---:|---:|
| Exploratory scalar | 6,849 | 950,129 |
| Research-ready scalar | 32 | 7,498 |
| Withheld scalar | 347 | 39,742 |
| Special event | 4,485 | 95,477 |
| Special irregular-interval scalar identity | 1 | 83 |
| Special entity panel | 984 | 17,044 |
| Special curve panel | 1,287 | 116,766 |
| **Total** | **13,985** | **1,226,739** |

Thus the **6,757 special candidates** are `4,485 + 1 + 984 + 1,287`; the ordinary scalar relation also includes the existing 32 research-ready series. The 83 minimum-wage intervals, candidate `economic_annex:cuadro_11:7e29379e92ec54eb715af64d`, correctly route to `explore.events`, with retained interval bounds. They are not added to scalar time-series counts.

`catalog.series` contains **13,985 rows and distinct IDs**, exactly the canonical dimension; dimension-to-catalogue and current-fact-to-catalogue anti-joins return **0**. No staging documented-series ID lacks a canonical dimension row. Summed profiles equal all **1,226,739** current actual observations. The canonical fact table contains **1,227,082** rows including the separate publisher-statement population. Bidirectional `EXCEPT ALL` against production's `canonical.fact_series_events` returns **0 / 0**, establishing preservation including multiplicities.

`catalog.datasets` has **24** governed entries and covers every source ID in the **22** retained source vintages. CDA and TCN are registered but have no candidate observations or current source vintage in this migrated artifact. They are not evidence of newly ingested data. Dataset status does not promote them to research admission.

Source-region evidence is not equivalent to catalogue completeness over every numeric workbook cell:

```sql
SELECT classification,count(*) FROM audit.source_region_classification GROUP BY 1;
SELECT status,count(*) AS worksheets,sum(balance_delta) AS delta,
       sum(unclassified_cells) AS unclassified,sum(parser_defect_cells) AS defects
FROM audit.table_reconciliation GROUP BY 1;
```

Results: **48,037 period-axis**, **6,706 layout-derived**, and **6,522 unreviewed** out-of-region cells; **244 balanced worksheets**, total balance delta **0**, unclassified in-region cells **0**, parser-defect cells **0**. Of **4,095** unmapped in-region cells, all **4,095** have classifications. The unresolved out-of-region population spans **49 worksheets**. It is explicitly retained and prevents worksheet promotion; it is not proof of 6,522 missing observations, nor proof that all extractable categories have already been represented.

**Code/document evidence:** `scripts/08_reconciliation.R`, source-region classification and worksheet-promotion controls; `docs/DATA_MODEL.md`, cell accounting and A1 coordinates; `scripts/13_explore.R`, complete dimension-based discovery and dataset counts. The candidate totals are credible counts of extracted identities, not a claim of exhaustive economic-variable coverage.

### F06 — The strict research boundary is preserved; the EEFF repair is retained

**Classification: no issue.**

There are **nine research views and one table macro**, **32 scalar catalogue rows**, and **7,498 current scalar observations**. Bidirectional `EXCEPT ALL` comparisons of complete `research.observations_latest_actual` rows with production return **0 / 0**. A left join from research observations to `research.series_catalog` finds **0** orphans. No research-ready candidate has assurance outside `human_verified`/`rule_certified`; `canonical.series_review` remains empty, so no new human verification is implied.

The EEFF interface has **332,745 rows**, equal to the union of current accepted bank and financial-company EEFF source views. Grouping by `(source_id,reference_period,entity_id,item_id,source_currency_code,measure)` finds **0** duplicate keys. Code `6200` retains **127,078 FX-origin/ PYG-unit rows**, while `6900` retains **205,667 PYG-origin/ PYG-unit rows**. This is the documented schema-42 restoration, not schema-43 exploratory admission bleeding into research. `research.curves` has **38,922 rows**, `research.transactions` **312,329**, and `research.events` **0**.

**Code evidence:** `scripts/12_platform.R::create_research_views()`, the separate human/automated branches of `main.v_certified_research_series`, and the observation joins to that membership relation. The worktree diff changes the EEFF source-currency key and adds exploration; it does not insert exploratory tiers into scalar certification. `tests/testthat/test-research-platform.R` retains the strict research-object assertions and tests EEFF row conservation and deliberate source-key collisions.

### F07 — Discovery of heterogeneous panels and source omissions needs clearer detail

**Classification: post-release P1.**

Source-level registration is complete, but the catalogue does not yet make every preserved subdataset discoverable by variable/category. `catalog.datasets` has `banks` and `financial`, both provisional, with access `research.entity_panel`; both have null `source_sheets/table_titles` and **0** candidate-series observations. That zero is a scalar-candidate count, not zero available panel rows.

Direct counts demonstrate substantial other preserved material: `raw.raw_banks_carteras` **55,004**, `raw.raw_financial_carteras` **20,614**, `raw.raw_banks_ratios` **90,830**, and `raw.raw_financial_ratios` **41,195** rows. Searching bank/financial candidates for `cartera` returns **0**. The appropriate maintainer views, including `main.v_banks_carteras_documented` and `main.v_financial_carteras_documented`, exist, but are not individually linked from the dataset entries. The generic dataset warning and provisional assurance honestly deny blanket economic validation; the existing disposition identifies the limited research-panel route. They do not fully explain which non-EEFF products are unavailable through that route.

Similarly, the 6,522 out-of-region cells are visible through `main.v_source_region_unreviewed` and a global `research.quality_flags` warning. **No** candidate profile's `applicable_quality_checks` includes `source_region_unreviewed`: the flag is global (`source_id` and `source_sheet` null), whereas `scripts/13_explore.R::active_flags` joins series or source-specific flags. Generic completeness warnings remain present, so completeness is not asserted, but researchers must leave the catalogue to learn the specific omission risk.

**Practical action:** add explicit dataset/subdataset coverage descriptions, current native-row counts where meaningful, and maintainer-view pointers, stating that `research.entity_panel` covers EEFF only. Surface affected worksheet source-region counts and relevant global quality-screen links. Keep unresolved panel grains and missing-value contracts unresolved; do not manufacture scalar IDs or publish a generic combined panel. This improves the release's discovery purpose and honest routing without requiring those panels to become research-ready before release.

### F08 — Semantic, provenance, and continuity debt is visible and compatible with this release

**Classification: post-release P1.**

`SELECT warning_code,count(*) FROM catalog.series_warnings GROUP BY 1` reproduces **149,828 warnings across 19 codes**; this equals `sum(catalog.series.warning_count)`. There are **0** duplicate `(candidate_id,warning_code)` groups and no null warning text/code. Every candidate carries incomplete official provenance, non-publisher-verified availability, parser-assigned frequency, and non-validated table warnings. Other counts include **4,057** unresolved units, **7,874** unresolved hierarchies, **820** positional identities, **488** catalogue-convention gap cases, and **12,133** candidates without an expected grid.

`catalog.series` has domain values for **3,814** candidates, concentrated in `economic_annex` and `financial_indicators`; **10,171** have no domain. Label/path/title searches work, but domain-only search misses most sources. Prior continuity, methodology, semantic, and discontinuity review debt remains unresolved. The catalogue's 488 gap cases and the existing global screen's 499 cases use different conventions; neither is a signed missing-data diagnosis.

**Code/document evidence:** `scripts/13_explore.R`, normalized warnings and frequency-gap calculations; `docs/RESEARCH_DATABASE_GUIDE.md`, explicit preliminary non-guarantees and point-in-time prohibition; acquisition restrictions exposed through `catalog.datasets`; prior audit-resolution dispositions AR-03 through AR-10 and AR-15.

**Practical consequence:** use the layer for finding candidates and inspecting preliminary publisher observations, not blind aggregation, cross-source substitution, automated continuity, revision analysis, or pseudo-real-time inference. Prioritize source-backed domain metadata and economic review after release. The stated release intent explicitly permits these limitations; a complete semantic register, publisher timestamp history, or licence formalization is not an additional condition imposed by this review. Existing use restrictions remain in force.

### F09 — Fresh views bind; attached lookup macros have a narrower limitation

**Classification: no issue** for required fresh-connection view binding; **post-release P2** for attached macro usability.

`SELECT current_setting('search_path')` returned the empty string. Iterating `SELECT * FROM "schema"."view" LIMIT 0` over every non-internal stored view returned **141 successful bindings / 0 errors**. All **141** views also bound as `candidate."schema"."view"` when attached read-only to a fresh in-memory connection. Direct `catalog.profile()` and `explore.series()` calls retrieved the sample data successfully.

In the attached connection these fail:

```sql
SELECT * FROM candidate.catalog.profile('x') LIMIT 0;
SELECT * FROM candidate.explore.series('x') LIMIT 0;
```

DuckDB reports that schema `catalog`, respectively `explore`, does not exist for the macro's internal relation. The existing attached `research.observations_as_of()` likewise fails to resolve `main.v_series_observations_history`. The macro bodies use two-part names that resolve in the caller's current database. This is distinct from view binding, which passes.

**Code/test evidence:** the macro definitions in `scripts/13_explore.R` and `scripts/12_platform.R`; the attached test in `tests/testthat/test-exploratory-layer.R` exercises views only, while direct mode exercises the macros. Until improved, connect directly for the documented macro workflows or query `candidate.catalog.series` and `candidate.explore.observations` by ID. Attached macro compatibility is not necessary for the guide's working direct-connection workflow, so it is not a release condition.

### F10 — The SQL guide supports the intended workflow

**Classification: no issue**, with **post-release P2** documentation improvements.

The guide supplies catalogue search, dataset discovery, profile lookup, preliminary retrieval, strict research retrieval, and normalized-warning SQL. Placeholder IDs are expressly identified; substituting real search results works, as independently exercised in F03. It distinguishes preliminary tier from assurance, explains special interfaces, preserves source-currency distinctions for EEFF, and explicitly declines guarantees of economic definition, reviewed units, seasonal adjustment, stock/flow, completeness, continuity, comparability, and real-time availability. The source observations retain their published scale; normalized period fields are supplied separately.

**Practical improvements after release:** include one executable example with a real ID, search both labels and table titles when domains are null, add the EEFF-only/other-panel routing explanation in F07, and note the attached-macro limitation. The guide's `provisional` assurance description (“not admitted to a default data view”) predates broad preliminary access; clarify that this means strict research admission, since a provisional table can now legitimately contribute exploratory rows. The adjacent tier definitions already make the operational distinction, so this wording is not a release blocker.

## Exact pre-release conditions and recommendation

1. **Correct F01's exposed lineage.** Observation-level sheet/title must come from the matching source observation where available, with exact source text preserved. Profiles must honestly represent multiple or missing worksheets rather than implying one complete locator. On the corrected candidate, require zero sheet/title disagreements with corresponding documented staging records across all exploratory interfaces; verify the cited BCP FX and financial-indicator cases against `main.v_report_cells_a1`; retain IDs, values, and the strict research population. Run focused lineage tests and the project's required regression checks for the interface change.
2. **Complete F02's existing release workflow.** Produce the corrected schema-43 candidate from a clean reviewed commit through the normal isolated pipeline, with its actual build/configuration identity, a distinct accepted schema-43 product decision, zero release-blocking errors, and an active pointer naming that same build before replacement. Recheck this review's counts/integrity assertions against the final artifact and record its SHA-256. Any source-population change, including activating CDA/TCN, must be explicitly reconciled rather than attributed to this migrated candidate's counts. Preserve the old accepted decision and source-vintage identities; confirm failed acceptance leaves production unchanged.

**Recommendation: 2. APPROVE CONDITIONALLY, subject only to the two pre-release conditions above.** Do not replace production with the currently reviewed bytes unchanged. Do not delay the exploratory/discovery release for the post-release P1/P2 work or for broad economic certification that this product does not claim.
