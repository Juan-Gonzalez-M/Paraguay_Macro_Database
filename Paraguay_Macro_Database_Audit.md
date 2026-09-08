# Technical and Macroeconomic Audit of `paraguay_macro_pilot (3).duckdb`

**Audit date:** 2026-09-07  
**Database inspected:** DuckDB, 391,393,280 bytes (373.2 MiB reported by DuckDB)  
**SHA-256:** `d20832bbb3cff7cd9e8591b45af8692f4ee746d88698832378e5eab7be0a32e6`  
**Engine used for inspection:** DuckDB v1.5.5, read-only connection  

## Evidence convention and audit boundary

This report uses three evidence levels:

- **Established fact:** directly queried from the database catalog, tables, views, constraints, or observations.
- **Strong inference:** the database evidence supports the conclusion, but the original publication was not visually checked cell by cell.
- **Source verification required:** a plausible interpretation or consolidation that should not be implemented until the relevant workbook headings, notes, or methodology are checked.

The audit inspected the database itself. It did not evaluate whether the 22 source files exhaust all macroeconomic data available for Paraguay. Consequently, “coverage” below means internal coverage of the loaded sources, not completeness relative to all BCP, government, or international databases.

## 1. Executive assessment

The database is **not yet a general-purpose, research-grade macroeconomic database**, although it is a strong and unusually auditable ingestion platform. Its engineering foundation is materially ahead of its economic curation.

The positive result is clear. The database preserves source files, workbook cells, formulas, releases, checksums, parsing evidence, missing-value reasons, and reconciliation results. The central series fact table has a declared primary key and no detected duplicate keys, orphan series, mismatched surrogate keys, or orphan vintages. All 123 user-created views executed successfully. All 244 rows in `audit.table_reconciliation` are `balanced`, with aggregate `balance_delta = 0`, zero unclassified cells inside the configured reconciliation regions, zero parser-defect cells, and zero rejected observations. The active release, `build:8f9a1d4ce77a77dbdec629a0`, completed with zero errors and 37 warnings.

The negative result is equally clear. The catalog contains 13,985 source series, but:

- `canonical.canonical_series`, `canonical.map_canonical_series`, `canonical.continuity_map`, `canonical.methodology_regime`, `canonical.series_revisions`, and `canonical.series_review` are all empty;
- `marts.v_research_series` contains zero rows by design because no series and no table have completed the required research review;
- 13,985 of 13,988 series-to-concept mappings are one-to-one `source_specific_unreviewed` mappings, so `canonical.dim_concept` is almost entirely a renaming of the source-series catalog rather than a catalog of economically distinct concepts;
- 7,874 series (56.3%) have unresolved hierarchy;
- 13,102 series (93.7%) have unreviewed stock/flow status, 13,948 (99.7%) have unreviewed nominal/real status, 13,965 (99.9%) have unreviewed seasonal adjustment, 13,766 (98.4%) have unreviewed transformation, and 13,347 (95.4%) have unreviewed valuation;
- 4,057 series (29.0%) retain `UNRESOLVED_SOURCE_UNITS`, covering 55,529 catalog observations;
- only 2,141 series (15.3%) have any row in `canonical.series_dimension`, and the implemented dimensions are concentrated in trade data;
- all 22 source vintages have `availability_quality = 'inferred_upper_bound'`, and the database contains only one source-file vintage per source.

The practical conclusion is that the database can already reproduce and trace source data, but it cannot yet protect a researcher from selecting the wrong economic concept, double-counting a repeated series, confusing a stock with a flow, using the wrong unit, mixing source date conventions, or treating a current revised history as a real-time vintage panel.

**Overall rating**

| Dimension | Assessment | Reason |
|---|---|---|
| Source preservation and lineage | Strong | Immutable source identifiers, hashes, cell-level storage, release controls, and reconciliation are present. |
| Internal key integrity | Strong | No detected fact-key duplicates, series-key mismatches, or key-table orphans. |
| Parser-region reconciliation | Strong within configured regions | 244/244 reconciliations balanced. |
| Economic semantics | Weak | Almost all substantive semantic fields are unreviewed; hierarchy is unresolved for 56.3% of series. |
| Canonicalization | Not implemented in populated data | Canonical series and membership tables are empty. |
| Real-time/vintage research | Not ready | One current source vintage per source; availability dates are conservative ingestion bounds, not historical release dates. |
| General econometric readiness | Not ready without a manually approved subset | The database itself correctly returns zero approved research series. |

## 2. What is already well designed

### 2.1 Layered storage and auditability

**Established fact.** The physical architecture separates 99 tables across `raw` (34), `staging` (13), `canonical` (29), and `audit` (23), with 100 user views in `main` and 23 in `marts`. The raw layer retains 1,255,806 workbook cell values, 91,673 workbook formulas, source files, source sheets, source provenance, and specialized banking tables. This is a defensible separation between source preservation, parsing, semantic modeling, and publication.

### 2.2 Release gating and fail-closed research access

**Established fact.** `audit.active_data_release` identifies one promoted build. Historical blocked release attempts remain auditable, but the active ingestion run reports zero errors. `marts.v_research_series` requires both validated table status and a populated `canonical.series_review` row. Because those conditions are not met, it returns zero rather than silently presenting provisional data as research-ready. This is the correct failure mode.

### 2.3 Observation keys and internal consistency

**Established fact.** `canonical.fact_series_events` has primary key `(series_sk, period, vintage_sk)` and a check requiring a value unless a row is deleted. Independent checks found:

- zero duplicate `(series_id, period, vintage_id)` records;
- zero duplicate active `(series_id, period)` observations;
- zero null or duplicate `series_sk` values in `canonical.dim_series`;
- zero fact rows orphaned from `canonical.dim_series` or `raw.source_files`;
- zero inconsistencies between the stored `series_sk` and `series_id`;
- zero null-valued, non-deleted fact rows.

### 2.4 Explicit missingness

**Established fact.** `staging.observation_missingness` distinguishes 18,416 `no_movement` observations marked by the source token `s/m`, 1,740 `blank_in_source` observations, and 491 `period_absent_from_axis` observations. The explanatory metadata correctly warns that `s/m` is neither a zero rate nor an ordinary unknown value. This distinction is econometrically valuable.

### 2.5 Forecast/projection separation

**Established fact.** `main.v_publisher_statement_latest` contains 343 observations in 186 series dated after the publication date, mainly Economic Annex projections through December 2028 and FX-operation rows through December 2026. `main.v_series_latest` excludes them, and `marts.v_series_projections` exposes the complement. The separation is conceptually sound.

### 2.6 Unit coding and normalized value support

**Established fact.** Every `canonical.dim_series` row has a populated `unit`, `unit_code`, `scale`, `scale_multiplier`, and frequency. `main.v_series_observations` exposes both the source value and `value_in_base_units`. Eight reviewed unit overrides correct specific exchange-rate/index inheritance problems. This is a good framework, even though a large unresolved-unit backlog remains.

### 2.7 Structural and reconciliation tests

**Established fact.** All 83 rows in `audit.structure_checks` are marked `passed`. The database also records source-region classifications, table reconciliation, aggregate identities, discontinuity screens, temporal-convention warnings, and missingness worklists. The project is not hiding its weaknesses; many of the critical limitations identified independently in this audit are already surfaced by its own active warnings.

## 3. Critical problems

### 3.1 The “canonical” layer is mostly structural scaffolding

**Observed.** There are zero populated canonical series, memberships, continuity mappings, methodology regimes, revision records, and series-review records. There are 13,986 concepts, but 13,985 are automatically generated source-specific concepts mapped one-to-one to 13,985 source series. Only three interbank series have reviewed mappings to one shared economic concept.

**Why it matters.** A canonical layer should answer “which economically distinct variable is this?” and “which source series or historical segment implements it?” The current concept layer mostly answers “which source series generated this source-specific concept?”

**Likely consequence.** Researchers will still select variables using workbook-derived labels and source locations. The database cannot systematically prevent duplicate inclusion, inappropriate splicing, or substitution between economically different measures.

**Improvement.** Retain `dim_series` as a source-series catalog, but rename it accordingly. Populate a smaller `canonical_series` catalog only after economic review. Map source series to canonical concepts with explicit relationship types such as `primary`, `replica`, `historical_segment`, `methodology_break`, `component`, `aggregate`, and `projection`. Do not auto-create one canonical concept per source series.

### 3.2 Source hierarchy is frequently missing from series identity

**Observed.** 7,874 series have `hierarchy_status = 'unresolved'`. The active warning reports 220 parsed worksheets with unresolved aggregate/component hierarchy and explicitly warns not to sum all series blindly.

Concrete evidence appears in Economic Annex `CUADRO 38`. The parser produces two quarterly series named `1. Remuneración de empleados`:

- `economic_annex:cuadro_38:5cc7b918175002c1d8ee3fdb`, sourced from row 37;
- `economic_annex:cuadro_38:82580462a41f97e15e19d9cf`, sourced from row 66.

Both run from 2008-Q1 to 2026-Q1 and have identical zeros, but the raw sheet shows that row 37 is under the export/credit-side section and row 66 is under the import/debit-side section. `series_path` contains only the local row label, and no parent dimension distinguishes the two.

**Why it matters.** Repeated row labels under different parent headings are economically distinct even when values happen to coincide. An automated duplicate detector that sees only label, unit, dates, and values can recommend a false merge.

**Likely consequence.** External-sector credits and debits, assets and liabilities, income and expense components, or institutional subgroups can be conflated. Aggregate identities may be impossible to reproduce safely.

**Improvement.** Make the full heading path part of semantic identity. Store typed parent dimensions—e.g., `balance_side`, `flow_direction`, `asset_liability`, `credit_debit`, `institutional_sector`, and `aggregate_level`—rather than only embedding text in a label. Block canonicalization for any repeated label with unresolved parents.

### 3.3 Some labels are semantically misleading even when units are technically populated

**Observed.** `financial_indicators:x4:097cbfe739a9eb94a4aa170e` is labeled `MN — Tasa Activa — Sobregiros — Total`, but its table title is `Cuadro Nº 4 — Saldos desglosados por plazo y cartera - Bancos`, its unit is PYG, and recent values are around 1.7–2.3 million. This is a balance series, not an interest-rate series. Many similar sheet 4 and sheet 7 labels contain `Tasa Activa` or `Tasa Pasiva` while the unit is PYG or unresolved source units.

**Strong inference.** The parser is treating a workbook hierarchy label as an economic measurement label. The data values and table title strongly indicate balances, while the constructed label reads like a rate.

**Likely consequence.** A user searching for lending rates can select a balance series, or a user aggregating balances can exclude it. This is a high-risk silent semantic error because no missing field alerts the user.

**Improvement.** Separate `instrument_side` or `portfolio_side` from `measure`. Validate label/unit/table-title compatibility with rules such as “rate/tasa requires percent or basis points unless manually overridden” and “saldo/balance requires currency or count.” Require review for all violations.

### 3.4 Raw series count substantially overstates usable macroeconomic concepts

**Observed.** Of 13,985 series, 4,159 have fewer than six observations, 4,083 are constant over their observed history, and 2,423 belong to one of 586 exact date-value signature groups with at least two observations. This does not mean that all 2,423 are duplicates: constant and short series often coincide mechanically, and distinct dimensions can generate equal values.

The source structure explains much of the inflation:

- `lrm_auctions`: 3,083 event-grain “series,” median 2 observations; 1,358 are singletons;
- `interbank_market`: 1,346 event-grain series, median 1 observation; 888 are singletons;
- `exchange_houses`: 770 entity-panel series, including 336 single-observation series;
- `corporate_bond_curves`: 1,287 curve-panel series;
- `insurance_annex`: 2,050 annual scalar series, 917 constant over the available 17 observations.

**Why it matters.** A researcher sees thousands of identifiers but far fewer stable, distinct macroeconomic variables. Events, securities, institutions, products, and annual worksheet lanes are often better represented as dimensions of panel/event tables than as independent scalar time series.

**Improvement.** Maintain separate catalogs for scalar macro series, entity panels, curve panels, and events. Do not count event lanes as macro “series coverage.” Expose grain-specific research views and require a grain declaration in every query/export.

### 3.5 Real-time and revision analysis are not supported by the populated data

**Observed.** Each of the 22 source IDs has exactly one source-file vintage. `canonical.series_revisions` is empty. Every provenance row has `availability_quality = 'inferred_upper_bound'`. The source file’s publication date is applied to its full historical content, so a 1995 observation in a 2026 workbook is associated with the 2026 file vintage, not the date on which the 1995 observation first became available.

**Why it matters.** This is acceptable for current-vintage descriptive work, but not for pseudo-real-time forecasting, real-time output-gap estimation, forecast evaluation, announcement studies, or tests sensitive to data revisions.

**Likely consequence.** A backtest using today’s revised history may exhibit look-ahead/revision bias. Conversely, a strict `available_at` filter before August 2026 returns no historical data, which is conservative but unusable as a real-time panel.

**Improvement.** Explicitly label every source as `current_snapshot_only` until historical releases are archived. Add release-level and observation-level availability where obtainable. Populate revision events only from genuinely different source vintages, not from repeated engineering builds of the same 22-file bundle.

### 3.6 Specialized panel tables lack enforceable natural keys

**Observed.** Twenty-one specialized raw/staging panel tables were tested. None declares a primary-key or unique constraint over the proposed natural key. Three tables have natural-key collisions totaling 430 excess rows:

- `raw.raw_banks_canales_person`: 399 collisions;
- `raw.raw_financial_canales_person`: 12 collisions;
- `raw.raw_banks_inhab`: 19 collisions.

There are three exact duplicate records in `raw.raw_financial_canales_person` after excluding `source_row`; for example, entity `2078`, March 2024, `Canales de Atención / Dependencias`, value 5, occurs at source rows 5089 and 5090. Other channel collisions contain different values under the same represented dimensions. In `raw.raw_banks_inhab`, some duplicate keys split `inhab` and `rehab` across separate rows, so a wide-table join can multiply observations.

**Why it matters.** Panel regressions, bank-level aggregation, and merges can double-count or create many-to-many joins even though the canonical scalar fact table is clean.

**Improvement.** Define a source-row primary key for immutable raw data, then create a curated long panel with an explicit `measure` dimension and a reviewed natural key. Quarantine exact duplicates and resolve different-value collisions by recovering the missing source dimension. Add uniqueness tests to the published panel views.

### 3.7 Provenance supports internal lineage but not independent reacquisition

**Observed.** All 22 files have a SHA-256 and an internal `source_uri`, but the URI values are local paths such as `input/current/...`. All 22 rows in `raw.source_provenance` lack an official URL, official release date, and license; the active warning also reports missing release identifiers and acquisition details in the source-vintage configuration.

**Why it matters.** A third party can verify that a local file has not changed, but cannot independently retrieve the original release or establish its public release time.

**Improvement.** Require official URL, retrieval timestamp, retrieval method, release identifier, and rights/license status for every new vintage. Allow explicit `not_available` values with evidence rather than silent nulls.

### 3.8 The public date fields are easy to misuse

**Observed.** The active warning identifies 164 monthly series that change day convention within their raw histories. `main.v_series_observations` creates normalized `period_start` and `period_end`, but `main.v_series_latest` exposes only the original `period`. The project’s own warning states that the raw `period` should not be lagged or differenced directly for affected series.

**Likely consequence.** Joining one month-start series to a month-end series on `period`, or using raw day differences to infer frequency, can silently lose observations or create false gaps.

**Improvement.** Make normalized `reference_period_start` and `reference_period_end` the default published key. Rename the original field `source_period_date`. A researcher-facing monthly view should use one canonical month key, such as the first day of month, across all sources.

### 3.9 Missingness coverage is selective

**Observed.** `staging.expected_observation_grid` covers 267,830 expected cells across only four sources: `financial_indicators`, `payments`, `economic_annex`, and `exchange_rates`. The database contains 18 source families in `dim_series` and 22 source files overall.

**Why it matters.** Absence means “explicitly classified missing” for some sources but merely “no row” for others. Gap comparisons across sources are therefore not semantically uniform.

**Improvement.** Define a per-dataset missingness contract. Regular scalar series should have an expected calendar and reason-coded absence. Event data should explicitly declare that no-event days are structurally absent, not missing.

### 3.10 Complexity is high relative to the populated semantic output

**Observed.** The database contains 99 tables, 123 user views, 132,543 series-ID migration rows, and 21,847 aliases for 12,175 current series. All aliases are `prior_release_series_id`. There are 19 recorded builds for the same source bundle, of which the active build is schema version 39.

**Strong inference.** Much of the complexity records engineering identity changes across builds rather than economic revisions across publication vintages.

**Improvement.** Preserve build lineage, but separate `engineering_id_migration` from `economic_series_continuity`. Reduce the public surface to a small, documented set of stable views. Keep internal compatibility views out of the default researcher schema.

## 4. Database architecture findings

### 4.1 Physical organization

| Schema | Tables | Main purpose | Assessment |
|---|---:|---|---|
| `raw` | 34 | Source files, workbook cells, specialized banking tables, reference snapshots | Appropriate, although specialized raw tables need source-row keys and curated successors. |
| `staging` | 13 | Parsed series, expected grids, missingness, event/curve snapshots | Appropriate intermediate layer. |
| `canonical` | 29 | Series catalog, fact observations, concepts, mappings, dimensions, review infrastructure | Structurally rich, but many economically critical tables are empty. |
| `audit` | 23 | Releases, checks, reconciliation, quality flags, source regions | Strong and useful. |
| `main` | 100 views | Current/latest, documented, and compatibility interfaces | Too broad for ordinary researchers; naming does not always signal safety. |
| `marts` | 23 views | Domain and research views | Correct direction; approved research mart is intentionally empty. |

### 4.2 Normalization and denormalization

The source-to-staging-to-canonical duplication is mostly justified: raw preservation and reproducible parsing require retaining both source cells and parsed observations. The problematic duplication is semantic, not merely physical. The database stores source series and source-specific concepts almost one-to-one, while the true canonical concept and continuity layers are unpopulated.

For scalar series, the long observation table is appropriate. For bank panels, auction events, securities transactions, and yield curves, a dedicated fact table with typed dimensions is preferable to forcing every column/lane into the scalar-series abstraction. The existing `series_grain` field recognizes this distinction, but the public catalog still combines the grains.

### 4.3 Keys and referential integrity

The database declares 179 constraints and 24 indexes, but zero foreign keys. This is not automatically a defect in an analytical database, and independent orphan checks passed for the central fact relationships. However, panel tables have no declared uniqueness constraints, and the collisions found demonstrate that tests cannot be optional. If foreign keys are avoided for bulk-load performance, equivalent release-gate assertions should cover every published relationship.

### 4.4 Data types

Dates in the central series model use `DATE`, with normalized bounds exposed as timestamps. Values use `DOUBLE`, which is suitable for most econometrics and faithful to Excel numeric storage. Transaction amounts that must reconcile exactly in currency units could use `DECIMAL`, but conversion should occur in a curated layer, not by rewriting raw source values.

The principal type defect found is `ano` and `mes` stored as `DOUBLE` in `raw.raw_banks_inhab`. They should be integer source fields and a derived canonical `DATE`/month key should be published.

## 5. Duplicate and fragmented-series analysis

### 5.1 Results and interpretation

**Established fact.** Exact signatures were calculated from ordered `(period, value)` sequences in `main.v_series_latest`. Among series with at least two observations:

- 586 exact signature groups contain 2,423 series;
- 152 groups are short or constant and therefore low-information matches;
- 310 have identical observations but conflicting labels or measurement metadata;
- 50 have recorded dimensional differences and should not be merged automatically;
- 15 have positional identity or unresolved hierarchy that may conceal a parent dimension;
- 59 are high-confidence duplicates under the metadata currently represented in the database.

These are observational classifications, not blanket merge instructions. Equal values do not establish equal economic meaning.

### 5.2 Concrete cases

| Case | Evidence | Classification | Recommended treatment |
|---|---|---|---|
| IMAEP original, `CUADRO 9` vs `CUADRO 9 a` | `economic_annex:cuadro_9:fc9a02c5dcc0573b3c038553` spans 1994-01 to 2026-06; `economic_annex:cuadro_9_a:fd9298219967c6b520d1afff` spans 2014-01 to 2026-06; all 150 overlapping monthly values are identical; same label, table title, frequency, unit, and base-2014 index definition. | Probable duplicate/subset, high confidence | Use the longer series as the primary canonical member; retain the other as a source replica/alias. Do not append overlapping rows. |
| IMAEP excluding agriculture and binational entities, `CUADRO 9` vs `9 a` | IDs `...:50676b58c0b150737790879f` and `...:8f84ed0f8814038ee0810d9e`; 150 identical overlapping months, with the first series beginning in 1994. | Probable duplicate/subset, high confidence | Same treatment as above. |
| M2 in `CUADRO 29` and `CUADRO 29 (Cont.)` | IDs `economic_annex:cuadro_29:e3bb0bf377d93222be89f9a2` and `economic_annex:cuadro_29_cont:e3bb0bf377d93222be89f9a2`; 378 identical monthly observations, 1995-01 to 2026-06, both PYG. | Definite source-layout repetition, high confidence | One canonical M2 concept with two source aliases; preserve both raw locations. |
| TCN and IPC in `CUADRO 60b` and `CUADRO 60c` | Each pair has 378 identical monthly index observations, 1995-01 to 2026-06. | Legitimate repeated input series across tables; canonical duplication | One canonical TCN index and one canonical IPC index, with multiple source-table aliases. |
| Dedicated FX operations vs Economic Annex `CUADRO 20` | Ten monthly FX-operation sequences are duplicated across `fx_operations` and `economic_annex`; representative groups contain 379 identical observations from 1995-01 to 2026-07. | Cross-source replication, high confidence observationally | Prefer the dedicated `fx_operations` semantic series as primary, and map Annex rows as replicas after confirming definitions/sign conventions. |
| Financial-indicator rate tables | Examples include `financial_indicators:x2_1:f116ef1d49e95003df8995d4` and `...:x3_1:cda62c39c75048c93e1b1ce6`, 186 identical monthly values for local-currency sight-deposit rates, 2011-01 to 2026-06. | Probable repeated publication across rate tables | Canonicalize by currency × active/passive × instrument × maturity × statistic. Verify whether TPP, minimum, maximum, and table totals are distinct before mapping. |
| Minimum sight-deposit rates in MN and ME | Four series in group `EDG-0283` have 186 identical observations but represent both MN and ME and sheets 3.1/3.2. Values are almost always 0.01. | Legitimate distinct series with coincident minimum values | Do not merge currencies. This is a counterexample showing why value equality is insufficient. |
| `CUADRO 38` repeated `Remuneración de empleados` | Two quarterly sequences are identical zeros but occur at source rows 37 and 66 under different parent sections. | Economically distinct; missing parent dimension | Recover credit/debit or export/import parent path; do not consolidate. |
| Gas-oil import volumes in `Cuadro 51b` and `Cuadro 53b` | Same 391 monthly tonne observations; one table classifies imports by type of goods and another by processing level. | Same economic measure repeated under two classifications, probable canonical duplicate | Canonicalize product × import × volume; store classification as source presentation metadata, not as a distinct economic series, after source confirmation. |

### 5.3 Fragmentation

No high-confidence adjacent, non-overlapping scalar fragments were found by the conservative same-source/same-label/same-table-title screen. This does **not** prove fragmentation is absent. Annual-sheet event sources such as `lrm_auctions` are already represented as thousands of short event-grain series, and positional identities can prevent labels from matching across layout changes. The empty `canonical.continuity_map` and `staging.documented_series_continuity` tables confirm that continuity has not yet been curated.

## 6. Economic and semantic consistency findings

### 6.1 Stock, flow, nominal/real, seasonal adjustment, and transformation

The database has fields for all of these concepts but almost no reviewed content. A populated column containing `not_reviewed` is not equivalent to usable metadata. Until these fields are curated, a user cannot reliably know whether to log a series, difference it, deflate it, annualize it, seasonally adjust it, or interpret it as an end-period stock versus a period flow.

### 6.2 Units and scales

The scale framework is strong, but 4,057 unresolved-unit series are concentrated in economically important sources: all 3,083 LRM-auction series, 634 interbank series, 145 payments series, 106 financial-indicator series, 69 Economic Annex series, and 20 banking-indicator series. The problem is especially severe where a label suggests a rate while the unit suggests a balance.

### 6.3 Frequency and timing

The catalog distinguishes annual, semiannual, quarterly, monthly, monthly survey, daily, irregular daily, and irregular interval. However, 499 regular-frequency series skip at least one expected period, totaling 24,149 missing expected periods in the project’s active warning. Sparse monthly rate minima and payment variables should not be silently treated as balanced monthly series.

### 6.4 Aggregates and components

Five published identities are incomplete because totals are available when not all components are reported. The FX-operation audit also records nine annual subtotal differences in documented exception years, with a maximum difference of 29.7465. These may be legitimate publisher behavior, rounding, or classification issues, but should be carried as series-level quality flags rather than only global warnings.

### 6.5 Hidden rows and cached formulas

The database reports 91,673 cached-formula cells across 104 worksheets, 34 worksheets with hidden rows/columns, and 15,403 published observations sourced from hidden rows across 13 worksheets. This is not inherently wrong, but it is a provenance risk: source formulas may not have been recalculated before publication, and hidden rows may represent discontinued or supplementary material. These observations need a flag available in the observation view.

## 7. Time-series inventory

The accompanying workbook contains the complete 13,985-row catalog in the **Series Inventory** sheet. It includes every requested field that can be established or conservatively derived: source and provisional names, concept mapping, source institution/file/table/sheet, frequency, unit, scale, currency, bases, stock/flow and nominal/real status, seasonal adjustment, transformation, valuation, grain, hierarchy, dimensions, observed coverage, projections, explicit missingness, aliases, review status, exact-duplicate status, cadence screens, discontinuity candidates, related groups, and caveats.

Unavailable information is marked as missing or unreviewed. The “standardized name” is explicitly labeled provisional because no populated human-reviewed naming table exists. Auto-generated definitions such as `Source-specific concept for ...` are classified as `generated_source_identity_only`, not accepted as economic definitions.

### 7.1 Catalog composition by source

| Source ID | Series | Catalog rows | Coverage |
|---|---:|---:|---|
| `lrm_auctions` | 3,083 | 10,351 | 2013-01-08 to 2026-07-30 |
| `economic_annex` | 2,764 | 656,179 | 1950-12-31 to 2028-12-01, including projections |
| `insurance_annex` | 2,050 | 34,846 | 2009-06-30 to 2025-06-30 |
| `interbank_market` | 1,346 | 81,474 | 2010-01-04 to 2026-08-14 |
| `corporate_bond_curves` | 1,287 | 116,766 | 2010-11-01 to 2026-07-31 |
| `financial_indicators` | 1,050 | 158,038 | 2011-01-31 to 2026-06-30 |
| `exchange_houses` | 770 | 5,048 | 2016-07-31 to 2026-07-31 |
| `payments` | 587 | 51,830 | 2013-11-30 to 2026-07-31 |
| `direct_investment` | 516 | 33,109 | 1995-12-31 to 2024-12-31 |
| `credit_survey` | 312 | 15,806 | 2013-03-31 to 2026-06-30 |
| Remaining eight series sources | 220 | 63,852 | Varies |

Four loaded source families—`banks`, `financial`, `bank_reference`, and `securities_trades`—are outside `canonical.dim_series`. Their specialized panel/event tables are documented separately in **Panel Integrity**, **Sources**, and **Object Catalog**. This is appropriate if deliberate, but the dataset catalog should make the split explicit.

## 8. Econometric research-readiness assessment

| Use case | Current readiness | Main obstacle |
|---|---|---|
| Source reproduction and ingestion diagnostics | High | Source reacquisition metadata is incomplete. |
| Supervised descriptive macro analysis | Moderate | Requires manual concept, unit, hierarchy, and transformation verification. |
| Unsupervised catalog exploration | Low | Hashed IDs, source-specific concepts, and unresolved hierarchy create selection risk. |
| Standard time-series regressions | Low | Canonical series, transformations, seasonal adjustment, and break metadata are not reviewed. |
| VAR/SVAR and local projections | Low | Duplicate/related measures and mixed semantics can alter identification and impulse responses. |
| Monetary-policy analysis | Low to moderate for a manually curated subset | Policy, rates, expectations, and liquidity data exist, but event and rate semantics require review. |
| Fiscal analysis | Low | Relevant Annex series may exist, but the semantic layer cannot establish a trusted fiscal catalog. |
| External-sector analysis | Low to moderate for a manually curated subset | Rich coverage, but repeated labels and missing parent direction in tables such as `CUADRO 38` are hazardous. |
| Forecasting with the latest revised history | Moderate after manual curation | Current-vintage series can be used, but date, gap, transformation, and break checks are required. |
| Pseudo-real-time forecasting/nowcasting | Not ready | One vintage per source and inferred availability bounds. |
| Mixed-frequency models | Low | Availability timing is not publication-accurate; raw date conventions vary. |
| Banking panel analysis | Low to moderate | Rich panels, but natural-key collisions, nullable keys, and uneven curated views must be resolved. |
| Structural-break analysis | Low | `methodology_regime` is empty; automated jumps are screens, not documented breaks. |

Before trusting a regression, I would require a version-controlled research manifest listing the exact canonical series, source members, units, transformations, seasonal-adjustment status, sample, methodology regimes, and as-of policy. Today, that manifest would have to be created outside the database because the populated canonical/review layer cannot produce it.

## 9. Recommended target architecture

The best redesign is evolutionary, not a wholesale rewrite. Preserve the strong raw and audit layers; simplify and complete the semantic/public layers.

### 9.1 Recommended logical model

1. **Immutable acquisition layer**
   - `source`
   - `source_release` / `source_vintage`
   - `source_file`
   - raw cells and specialized raw records

2. **Source-semantic layer**
   - `source_series`: one identifier per publisher-defined series or stable source lane
   - `source_observation`: source value, source period representation, source cell/row, vintage, and status
   - typed event/panel tables for auctions, trades, curves, and bank panels

3. **Canonical economic layer**
   - `canonical_series`: one reviewed economic concept and measurement definition
   - `canonical_member`: maps source series to canonical series with relationship and valid dates
   - `continuity_segment`: documents splices, overlaps, precedence, rebasing, and methodology breaks
   - `methodology_regime`: comparability and effective dates
   - wide common metadata fields plus a flexible dimension table for less common dimensions

4. **Research publication layer**
   - `research_series_catalog`
   - `research_observations_latest`
   - `research_observations_asof`
   - grain-specific panel/event views
   - explicit projection views

5. **Quality layer**
   - row/series/release flags with severity, test version, resolution, and waiver evidence
   - publication contracts that fail closed

### 9.2 Illustrative DuckDB schema

```sql
CREATE TABLE semantic.canonical_series (
    canonical_series_id VARCHAR PRIMARY KEY,
    canonical_name VARCHAR NOT NULL,
    definition VARCHAR NOT NULL,
    domain VARCHAR NOT NULL,
    frequency VARCHAR NOT NULL,
    unit_code VARCHAR NOT NULL,
    scale_multiplier DOUBLE NOT NULL,
    stock_flow VARCHAR NOT NULL,
    nominal_real VARCHAR NOT NULL,
    seasonal_adjustment VARCHAR NOT NULL,
    transformation VARCHAR NOT NULL,
    currency VARCHAR,
    price_base_year INTEGER,
    geography_code VARCHAR,
    review_status VARCHAR NOT NULL,
    reviewed_by VARCHAR,
    reviewed_at TIMESTAMP,
    evidence_uri VARCHAR
);

CREATE TABLE semantic.canonical_member (
    canonical_series_id VARCHAR NOT NULL,
    source_series_id VARCHAR NOT NULL,
    relationship VARCHAR NOT NULL, -- primary, replica, historical_segment, component...
    valid_from DATE,
    valid_to DATE,
    precedence INTEGER,
    overlap_policy VARCHAR,
    reviewed_by VARCHAR NOT NULL,
    reviewed_at TIMESTAMP NOT NULL,
    evidence_uri VARCHAR NOT NULL,
    PRIMARY KEY (canonical_series_id, source_series_id, valid_from)
);

CREATE TABLE core.source_observation (
    source_series_id VARCHAR NOT NULL,
    reference_period_start DATE NOT NULL,
    reference_period_end DATE NOT NULL,
    source_period_date DATE,
    value DOUBLE,
    value_status VARCHAR NOT NULL, -- observed, no_movement, missing, projection, deleted
    vintage_id VARCHAR NOT NULL,
    available_at TIMESTAMP,
    availability_quality VARCHAR NOT NULL,
    source_locator VARCHAR,
    PRIMARY KEY (source_series_id, reference_period_start, vintage_id)
);
```

For panel/event data, do not manufacture scalar IDs for each sparse lane. For example, LRM auctions should have one row per auction × instrument/tenor × measure, with `auction_date`, `standardized_term`, `residual_term`, `measure`, `currency`, and `value` as explicit columns.

### 9.3 Public API simplification

The default researcher schema should contain fewer than ten stable views. Names should state their contract:

- `research.series_catalog_approved`
- `research.observations_latest_actual`
- `research.observations_latest_with_projections`
- `research.observations_asof`
- `research.bank_panel`
- `research.lrm_auction_events`
- `research.interbank_events`
- `research.bond_curves`

Compatibility and ingestion views can remain, but should not appear in the default research search path.

## 10. Specific consolidation recommendations

### Immediate high-confidence mappings

1. **IMAEP original and IMAEP excluding agriculture/binational entities:** map `CUADRO 9 a` as a replica/subset of the longer `CUADRO 9` series. Use source precedence rather than concatenation.
2. **M2 across `CUADRO 29` and its continuation sheet:** one canonical M2 series; retain both source aliases.
3. **TCN and IPC repeated in `CUADRO 60b/60c`:** one canonical series per economic measure; multiple source-table aliases.
4. **Dedicated FX operations and Annex `CUADRO 20`:** ten canonical monthly series, preferably sourced primarily from the dedicated file after sign/definition confirmation.

### Review before consolidation

5. **Financial-indicator rates across sheets 2.1, 3.1, and 3.2:** create a complete dimension key for currency, lending/deposit side, instrument, maturity, and statistic. Merge only exact replicas of the same statistic.
6. **Trade products repeated under alternative classifications:** distinguish the economic observation (flow × product × measure) from the table’s presentation classification. Gas-oil import tonnes in `Cuadro 51b` and `53b` are a leading candidate.
7. **Insurance rows:** do not use constant zeros or equal values as evidence of equivalence. Recover company, line of business, account, accepted/ceded status, domestic/foreign, and total/component dimensions first.

### Explicitly do not consolidate yet

8. **Economic Annex repeated labels under different parents**, including `CUADRO 38` row 37 versus row 66. Parent-flow recovery is mandatory.
9. **MN and ME rate minima** that happen to equal 0.01. Currency makes them distinct.
10. **Event-grain LRM/interbank lanes.** Redesign them as event records rather than splicing sparse annual “series.”

## 11. Recommended automated data-quality tests

| Priority | Test | Failure action |
|---|---|---|
| P0 | Unique source observation key and unique published canonical `(series, period, as_of)` key | Block release. |
| P0 | Specialized panel natural-key uniqueness after curation | Block affected published panel; quarantine collisions. |
| P0 | Full referential-integrity assertions for facts, dimensions, mappings, vintages, and releases | Block release. |
| P0 | Label–unit–measure compatibility (`tasa` vs PYG, `saldo` vs percent, index without base) | Block research promotion; require override evidence. |
| P0 | Parent-path completeness for repeated labels and unresolved hierarchies | Block canonical mapping. |
| P0 | Actual/projection separation and no future-dated values in actual-only views | Block release. |
| P0 | Canonical membership overlap: no two primary members for the same canonical period unless precedence is explicit | Block canonical publication. |
| P0 | Real-time contract: no `as_of` claim when availability is inferred or only a current snapshot exists | Block real-time view. |
| P0 | Source-region completeness: every numeric cell is parsed, excluded by rule, or reviewed | Block table validation. |
| P1 | Exact and rounded sequence signatures across source series | Create duplicate-review work item; do not auto-merge. |
| P1 | Expected-period grid by regular dataset and reason-coded missingness | Block “complete panel” claims. |
| P1 | Frequency/date convention: canonical month/quarter/year keys and empirical cadence | Flag or block depending severity. |
| P1 | Unit and scale consistency across canonical members and methodology regimes | Block consolidation. |
| P1 | Aggregate identities with documented tolerances and coverage conditions | Flag failures with affected periods. |
| P1 | Revision detection between genuine source vintages | Record old/new value and revision magnitude. |
| P1 | Source checksum, official URL, release ID, retrieval time/method | Block new-vintage promotion unless an evidenced waiver exists. |
| P1 | Extreme level/growth/discontinuity screen using robust, unit-aware thresholds | Review; never auto-correct. |
| P2 | Near-duplicate overlap correlation and proportional/scaled duplicates | Create review worklist. |
| P2 | Metadata completeness by domain-specific required fields | Prevent research approval until complete. |
| P2 | Hidden-row/cached-formula lineage flags in observation exports | Preserve warning at row/series level. |
| P3 | Naming, spelling, acronym, and bilingual-label consistency | Quality-of-life warning. |

## 12. Prioritized remediation roadmap

### P0 — Critical

1. **Keep `marts.v_research_series` fail-closed.** Do not bypass it by treating `main.v_series_latest` as research-ready.
2. **Fix the banking-panel natural-key collisions.** Resolve the 430 excess rows, including three exact duplicates in `raw_financial_canales_person`, and publish constrained curated panel tables.
3. **Recover missing parent hierarchy for high-value macro tables.** Start with national accounts/activity, prices, money/credit, external accounts, rates, and payments. `CUADRO 38` is a mandatory regression test.
4. **Correct semantically misleading labels and unresolved units.** Prioritize financial-indicator balances mislabeled as rates and all series likely to enter monetary-transmission work.
5. **Publish a canonical period key.** Rename the source date and make normalized period start/end mandatory in researcher views.
6. **Populate a first canonical-series tranche.** Curate a limited set of flagship variables—GDP/activity, CPI, policy/interbank rates, credit, monetary aggregates, exchange rates, reserves, trade, fiscal variables, and expectations—rather than attempting all 13,985 at once.
7. **Resolve or explicitly exclude the 6,522 numeric cells outside parser regions across 49 worksheets** before validating affected tables.
8. **Enforce a vintage-use policy.** Mark current data as current-snapshot-only and prohibit real-time claims until historical source vintages are loaded.

### P1 — High priority

1. Populate `canonical_series`, `map_canonical_series`, `continuity_map`, `methodology_regime`, and `series_review` with reviewed evidence.
2. Implement the high-confidence consolidation mappings listed in Section 10.
3. Separate scalar, event, entity-panel, and curve catalogs and stop reporting them as one undifferentiated series count.
4. Extend expected-period/missingness contracts beyond the four currently covered sources.
5. Add official acquisition metadata for every source vintage.
6. Move engineering migration history out of the economic continuity namespace and rationalize the 21,847 prior-ID aliases.
7. Convert active warnings into series- and observation-level flags exposed in research exports.

### P2 — Useful

1. Reduce the 123-view public surface and document a small stable API.
2. Add dataset-level documentation for the four source families outside the canonical series model.
3. Standardize coded dimensions and concordances across banks/financials, trade classifications, sectors, entities, and currencies.
4. Add near-duplicate, proportional-series, and overlap-consistency screens.
5. Add coverage dashboards by economically distinct approved concepts, not raw series count.

### P3 — Optional

1. Add user-facing search aliases, abbreviations, and English/Spanish standardized names.
2. Add convenience wide exports generated from the approved long tables.
3. Add usage examples for R, DuckDB SQL, and reproducible research manifests.
4. Add performance benchmarks after the public semantic model is simplified; current correctness work is more important than further optimization.

## 13. Final assessment

`paraguay_macro_pilot (3)(3).duckdb` can become a clean, canonical, auditable, and research-grade macroeconomic database. The hard engineering foundations—source preservation, parsing layers, release tracking, reconciliation, current-view isolation, and explicit quality warnings—are already present and in several respects unusually strong.

The database should not, however, be trusted today as an unsupervised catalog for reproducible econometric research. Its own fail-closed research mart correctly returns zero approved series. The decisive gap is economic curation: canonical concepts, hierarchy, measurement definitions, methodology regimes, continuity, revisions, and availability are mostly scaffolding or unreviewed placeholders.

The project’s next phase should therefore be narrower and more economic, not broader and more architectural. Curate a small flagship macro dataset end to end, prove its canonical identities and vintages, publish it through a minimal research API, and only then expand domain by domain. If that discipline is followed, the existing audit infrastructure gives the project a credible route to research-grade status.
