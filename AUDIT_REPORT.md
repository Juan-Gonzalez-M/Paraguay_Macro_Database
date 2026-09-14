# Evidence-based audit of `paraguay_macro_pilot.duckdb`

Audit date: 2026-09-13  
Database SHA-256: `17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180`  
Database size: 418,918,400 bytes (DuckDB reports 399.5 MiB; WAL 0 bytes)  
Access mode: DuckDB 1.5.5, read-only

## 1. Executive assessment

**Overall readiness rating: Not ready.**

The database is substantially better engineered than a typical preliminary Excel consolidation: it has explicit raw, staging, canonical, mart, research, and audit layers; a release gate; stable source fingerprints; typed observation facts; source-cell traceability; and a narrow certification mechanism. The active scalar fact store is structurally clean: 1,226,739 current actual observations across 13,985 series, with no null or non-finite values, no duplicate fact keys, and no orphan series or vintage references.

That structural strength does not yet make it a broad research database. Only 32 of 13,985 series (0.23%) are exposed as rule-certified research series, none has a recorded human review, all 22 source vintages have incomplete official provenance and unverified licenses, all research observations use inferred—not publisher-verified—availability timestamps, and the cross-source canonical, continuity, concordance, methodology-regime, and revision registers are empty.

The most serious confirmed defect is in `research.entity_panel`. Its key collapses source currency codes `6200` (foreign-origin balances converted to PYG) and `6900` (PYG-origin balances) into the same `economic_currency='PYG'`. The view then suppresses every collided key. It exposes 93,217 of 332,745 eligible statement rows and excludes 239,528 rows (72.0%); 119,737 of the 119,764 collision groups contain different values. Replacing `economic_currency` in the key with the original currency code—or an equivalent combination preserving currency of origin and unit currency—reduces these collisions to zero.

### Safe uses now

- Limited latest-vintage descriptive and conventional time-series analysis using the 32 series in `research.series_catalog` joined to `research.observations_latest_actual`, subject to source/provenance caveats.
- Exploratory curve-node analysis with `research.curves`: 38,922 rows, complete tested keys, and no duplicate or conflicting curve keys.
- Exploratory transaction analysis with `research.transactions`: 312,329 unique transaction IDs; the three missing volumes are explicitly marked `volume_status='not_reported'`.

### Uses that are not safe now

- Broad querying of the 13,953 uncertified series as though they were economically validated.
- Bank/finance statement panel research through `research.entity_panel`.
- Real-time, vintage, news, revision, or pseudo-out-of-sample claims. Each source has only one data vintage, and every published research observation uses an inferred archive-ingestion availability bound.
- Blind aggregation across series: 7,874 series have unresolved hierarchy and the active gate explicitly warns that many tables mix totals and components.
- Automated continuity across releases for 820 position-dependent identifiers, or for the additional generated-column identities identified below.

### Gating issues

1. Correct or withdraw `research.entity_panel`.
2. Make the release boundary explicit: researchers should receive only certified researcher-facing objects, not an undifferentiated database containing raw and uncertified canonical data.
3. Complete official source provenance, licensing, and availability evidence for every released dataset, or explicitly prohibit real-time/as-of and redistribution claims.
4. Complete economic review for the series intended for release, including units, transformations, seasonal adjustment, stock/flow applicability, hierarchy, and methodology/continuity regimes.
5. Resolve or quarantine the 3,019 series in the supplied suspicious-series worklist before expanding the research surface.

## 2. Database inventory and architecture

### Inventory

| Layer/schema | Tables | Views | Evidenced role |
|---|---:|---:|---|
| `raw` | 34 | 0 | Source files, source provenance, workbook cells/formulas/sheets, long panel extracts, reference snapshots |
| `staging` | 13 | 0 | Parsed series snapshot, expected grids, missingness, discarded rows, specialized curve/event/transaction extracts |
| `canonical` | 32 | 0 | Series/concept dimensions, fact events, mappings, certification, semantic evidence, migration and review registers |
| `audit` | 27 | 0 | Releases, build identity/environment, quality flags, contracts, reconciliation, structural checks |
| `main` | 0 | 101 | Transformation, latest/history, source-specific and compatibility views; four macros are also here |
| `marts` | 0 | 23 | Domain and grain-oriented analytical views |
| `research` | 0 | 9 | Intended researcher-facing catalogues, scalar observations, panels, curves, events, transactions, and flags; one macro is also here |

Total: 106 tables, 133 views, 5 macros, 24 explicit indexes, and 256 catalogued constraints. All 133 stored views successfully bound with `SELECT * ... LIMIT 0`.

### Observation models and logical keys

The canonical scalar/event/curve/entity-series store is:

- dimension: `canonical.dim_series`, primary key `series_id`;
- facts: `canonical.fact_series_events`, primary key `(series_sk, period, vintage_sk)`;
- public natural event key: `(series_id, period, vintage_id)`;
- current publisher statement: one row per `(series_id, period)` in `main.v_publisher_statement_latest`;
- current actual research key: `(research_series_id, reference_period_start)` in `research.observations_latest_actual`.

`series_id` incorporates the dimensions needed to distinguish the 13,985 series variants. The database separately labels four grains: 7,229 scalar series, 4,485 event series, 1,287 curve-panel series, and 984 entity-panel series. Specialized long-format data also use independent keys: transaction ID for securities trades, curve node `(period, currency, risk_rating, maturity_years)`, and entity-statement keys for bank/finance panels.

The panel observation model is not yet uniformly published. Only bank/finance financial statements are exposed in `research.entity_panel`; portfolios, credit by activity/sector, ratios, channels, cards, and related source tables remain in raw or source-specific views.

### Evidenced strengths

- Every one of the 22 source-file records has a filename, local source/archive path or URI, SHA-256, ingestion time, and ingestion status.
- The latest build records a clean Git state (`git_dirty=false`), a concrete commit, schema version 41, and hashes of code, configuration, packages, and environment.
- The fact table enforces non-null identifiers/periods, a primary key, and `CHECK(is_deleted OR value IS NOT NULL)`.
- The independent audit found zero fact-key duplicates, zero conflicting fact keys, zero orphan series/vintage references, and zero dimension series without facts.
- Staging/raw natural keys are frequently protected by unique indexes; for example, `staging.documented_series_snapshot(vintage_id, series_id, period)`.
- The release mechanism retains blocked attempts. The active build is accepted with zero errors and 37 warnings; a prior build against the same source bundle was blocked. This is evidence that the release gate can prevent a failed build rather than evidence that the current accepted build contains that historical error.
- The design distinguishes current publisher statements, actual observations, and projections. There are 343 future-dated statement observations; they are excluded from `main.v_series_latest` and exposed separately through the projections mart.

## 3. Time-series integrity audit

### Full-universe summary

The series-level audit covers all 13,985 rows of `canonical.dim_series`, not a sample. The full diagnostic is `series_diagnostics.csv` in the audit package.

| Grain | Series | Current actual observations | Length/regularity interpretation |
|---|---:|---:|---|
| Scalar series | 7,229 | 997,452 | Main macro time-series universe |
| Event | 4,485 | 95,477 | Irregular/event-specific series; short length is often legitimate |
| Curve panel | 1,287 | 116,766 | Tenor/rating/currency/measure variants; 117 have at most two observations |
| Entity panel | 984 | 17,044 | Includes 336 monthly variants with one observation; these are snapshots, not usable time series |
| **Total** | **13,985** | **1,226,739** | Plus 343 publisher-statement projections |

Scalar-series length by principal regular frequency is: 2,735 annual series (median 17 observations), 775 quarterly series (median 73), 3,650 monthly series (median 186), and 16 monthly-survey series (median 162.5). There are 25 scalar series with one or two observations.

### Structural and numeric checks

| Check | Verified result |
|---|---:|
| Current actual rows | 1,226,739 |
| Distinct current actual `(series_id, period)` keys | 1,226,739 |
| Null stored actual values | 0 |
| NaN/infinite actual values | 0 |
| Duplicate canonical fact primary keys | 0 |
| Conflicting canonical fact primary keys | 0 |
| Orphan fact `series_id`/`series_sk`/`vintage_id` references | 0 / 0 / 0 |
| Malformed/null canonical dates | 0; `period` is typed `DATE` and non-null |
| Stored projections in publisher statement | 343 observations across 186 series, through 2028-12-01 |

These results verify integrity after parsing. They do **not** prove that every Excel token was converted correctly. The database preserves raw cell text/numeric/date representations and source row/column coordinates, but the original workbooks and parser source were not attached, so silent coercions cannot be independently ruled out in this audit.

The active gate reports 20,647 expected absences with explicit reasons: 18,416 `no_movement`, 1,740 `blank_in_source`, and 491 `period_absent_from_axis`. It also reports 499 regular-frequency series with 24,149 skipped periods. The independent actual-only screen using normalized `period_start` found unexpected regular steps in 469 series; four of those were assigned to a stronger parsing/identity category, leaving 465 in the dedicated gap-review category. The difference from the stored 499-series screen reflects different universes/conventions and must itself be reconciled before certification.

The gate also reports 164 monthly series whose raw date convention changes within history. Normalized period bounds make the research view safer, but researchers must not lag or difference the raw `period` field for those series.

### Suspicious-series classification

The complete table of all 3,019 suspicious or unresolved series is `suspicious_series.csv`. It includes identifier, source, sheet, domain where available, grain, label, frequency, observation count, coverage, issue, severity, confidence, and proposed action.

| Classification | Series | Evidence-based interpretation | Severity/confidence |
|---|---:|---|---|
| Confirmed scalar fact corruption | 0 | No null/non-finite values, duplicate/conflicting fact keys, reference-period collisions, or empty observed series were found | — |
| Likely parsing or unresolved semantic-identity failure | 1,729 | 1,644 LRM event identities retain generated `column_N` disambiguators; 47 payment series have labels such as `column_3`; 38 economic-annex series include source values/`s/d` tokens in the identity | P1, medium |
| Likely positional-identity failure | 818 | Identity depends on workbook position/lane: interbank market 433, economic annex 232, payments 74, LRM 39, liquidity facility 24, exchange rates 14, insurance 2 | P1, medium |
| Regular gaps requiring confirmation | 465 | Unexpected step(s) at a documented annual/semiannual/quarterly/monthly frequency; missingness metadata is not yet reconciled gap by gap | P1, medium |
| Potentially legitimate one/two-observation scalar | 7 | Five narrowly defined bank-rate categories and two payment-participant amount/count series; insufficient evidence to call them errors | P1 review, low |

Examples of high-priority parsing/identity review include:

| Series/source | Evidence | Assessment |
|---|---|---|
| Payment series with labels `column_3`, `column_4`, etc. | Generated column labels are the researcher-visible identity despite histories of 51–108 observations | Likely header-path parsing failure; values may still be genuine |
| Economic-annex `CUADRO 32` one-observation series such as `Total operación — s/d — 32237.786` | A source value is embedded in the label and only the 1994 observation exists | High-priority likely row/column orientation failure |
| LRM auction identities containing `column_11`, `column_14`, `column_15`, or `column_16` | The visible label may say “Mínima/Promedio/Máxima,” but the identity needs a generated column token to remain unique | Semantic identity is incomplete; not proof that the numeric value is wrong |
| Economic-annex price/variation series with positional IDs | Long histories exist, but continuity depends on workbook position rather than a stable semantic key | Numerically usable only after source-backed identity review |

The seven short scalar series left for human confirmation are five `financial_indicators` interest-rate categories with one or two isolated months and two `payments` observations for participant `BCPAPYPXXXXX` in 2013-11. They may represent genuine entry/exit or sparse publication and must not be deleted solely because they are short.

Shortness was **not** used to condemn natural event/panel variants: 2,894 event series, 117 curve variants, and 336 monthly entity-panel variants have at most two observations. Their usability depends on grain. An event can legitimately occur once; a one-period entity series is a cross-sectional snapshot, not a time series.

### Panel and long-format checks

| Published/near-published object | Verified result | Assessment |
|---|---|---|
| `research.entity_panel` | 332,745 source rows; 93,217 exposed; 239,528 excluded in 119,764 collision groups; 119,737 groups conflict | Confirmed P0 public-model defect |
| Revised entity key retaining raw currency code | 0 collision groups and 0 conflicting groups | Demonstrates the precise key remedy |
| `research.curves` | 38,922 rows and keys; no incomplete, duplicate, conflicting, or non-finite tested rows | Structurally suitable for exploratory curve work |
| `research.transactions` | 312,329 rows and unique IDs; dates 2010-01-12 to 2026-08-19; 3 volumes explicitly `not_reported` | Structurally suitable for exploratory transaction work |
| Other bank/finance documented panels | Currency-collapsed keys also collide heavily; credit tables additionally retain explicit null measures | Must preserve source currency distinction before a research mart is built |

## 4. Macroeconomic research fitness

### Metadata and semantic adequacy

| Field/problem | Series affected | Share of 13,985 |
|---|---:|---:|
| Unresolved source units | 4,057 | 29.0% |
| Stock/flow not reviewed | 13,102 | 93.7% |
| Nominal/real not reviewed | 13,948 | 99.7% |
| Seasonal adjustment not reviewed | 13,965 | 99.9% |
| Transformation not reviewed | 13,766 | 98.4% |
| Valuation not reviewed | 13,347 | 95.4% |
| Hierarchy unresolved | 7,874 | 56.3% |
| Positional/positional-lane identity | 820 | 5.9% |
| Domain classification available | 3,814 | 27.3%; only 2 of 18 canonical-series sources |
| Human series reviews | 0 | 0% |
| Rule-certified research series | 32 | 0.23% |

Scale metadata are mechanically complete—every series has a multiplier—but a multiplier cannot compensate for an unresolved unit. Index-base labels also have several capitalization/punctuation variants for the same apparent base; they should be normalized to controlled codes.

The 32 certified series are concentrated in only two sources: 30 from the economic annex and 2 exchange-rate series. They cover GDP, selected inflation rates, selected interest rates, current account, remittances, real exchange-rate indices, IMAEP variants, and monthly USD buy/sell rates. Their research catalog has definitions, evidence URIs, timing conventions, transformation and comparability fields. However, all 32 lack a populated methodology-regime ID and none has a human review record.

### Frequency and missingness

Frequency is populated for all series, but documented frequency alone is insufficient. Regular gaps, mixed raw date conventions, and sparse variants must be evaluated using normalized `reference_period_start`/`reference_period_end`. The complete diagnostic supplies documented frequency, modal observed gap, inferred frequency class, span, stored-null share, expected-grid missing share where a grid exists, and gap counts for every series.

Only 1,852 series have entries in `staging.expected_observation_grid`; therefore a zero stored-null share should not be read as complete coverage for the rest. Missing observations can disappear at parse time rather than appear as null fact rows.

### Revisions, vintages, and real-time use

The architecture is capable of event/vintage storage and provides `series_as_of_date`, `series_statement_as_of_date`, and `research.observations_as_of` macros. The population does not support the claims those interfaces might invite:

- each of the 22 sources has exactly one source-file vintage;
- canonical series facts cover 18 of those sources and also have one vintage per source;
- `canonical.series_revisions` is empty;
- all 7,498 certified current-actual rows have `availability_quality='inferred_upper_bound'`;
- official release dates/identifiers are missing;
- one source (`eve`) has an inferred publication date later than its recorded retrieval/availability timestamp, demonstrating that `publication_date` is not consistently an official release timestamp;
- `fx_operations` is explicitly flagged because its recorded publication date is 2026-07-31 while content extends to 2026-12-31.

Consequently, latest-snapshot estimation can be performed on certified series, but pseudo-real-time forecasting, release-lag analysis, news decomposition, and revision research cannot be defended.

### Provenance and concept consistency

Local lineage is strong: file hashes, paths/URIs, workbook sheet/cell coordinates, formulas, hidden-state metadata, and build hashes are retained. Official provenance is not: all 22 vintages lack an official URL, release identifier, and license; availability is inferred from archive ingestion. The database itself labels all 22 provenance records incomplete and all dataset licenses unverified.

All 13,985 series map to a concept and only three have more than one concept mapping. However, `canonical.canonical_series`, `map_canonical_series`, `continuity_map`, `classification_concordance`, and `methodology_regime` are empty. Thus a concept mapping should not be mistaken for a validated continuous or cross-source canonical series. Users still cannot safely answer whether two similarly named series from different institutions, base years, currencies, or methodologies are comparable.

## 5. Data-engineering fitness

### Positive findings

- Layering and naming make the intended progression understandable.
- The current scalar fact key is enforced and empirically unique.
- Source and build fingerprinting are unusually complete for a pilot.
- Raw workbook cells, formulas, hidden rows/columns, and source coordinates support later forensic reconciliation.
- Release, build, and validation histories exist; the active release is explicit.
- All views bind, and the current scalar actual view has a unique logical key.
- The database distinguishes structural/rule certification from provisional datasets rather than labeling everything “clean.”

### Material weaknesses

1. **Published panel key loses an economically essential currency dimension.** This is the confirmed row-loss defect described above.
2. **Certification coverage is too narrow for a broad database.** The raw/canonical inventory is much larger than the safe research surface, and a standalone DuckDB file does not prevent users from bypassing that surface.
3. **No foreign-key constraints are catalogued.** Current orphan tests pass, but future updates rely on build-time controls rather than persisted referential enforcement. This is acceptable only if those controls are complete and release-blocking.
4. **Key registers are empty.** Panel resolution, human series review, revisions, methodology regimes, continuity, concordance, and canonical cross-source membership have zero rows.
5. **Open validation debt is large.** The active accepted release carries 37 warnings, including 38,433 discontinuity-screen observations across 2,611 series, 6,522 numeric cells outside reviewed parser regions, 91,673 cached formula cells, 15,403 published observations from hidden rows, and unresolved hierarchy/identity/unit warnings.
6. **Availability and publication semantics are not reliable enough for as-of interfaces.** Archive-ingestion time is a conservative operational bound, not the economic release time.
7. **Independent reproducibility cannot be proven from the attachment alone.** The database records a clean commit and environment/config/code digests, but the referenced repository, configuration files, original Excel/CSV files, and generated worklists were not attached. The audit therefore verifies stored evidence, not a clean rebuild from source.

Performance was not treated as a problem: read-only scans and grouped diagnostics over 1.2 million facts completed without evidence of a workload bottleneck. No performance redesign is recommended until representative researcher queries show one.

## 6. Prioritized remediation plan

### P0 — blocks reliable release

| Exact problem and evidence | Precise remedy | Expected benefit | Verification criterion |
|---|---|---|---|
| `research.entity_panel` drops 239,528/332,745 rows because `6200` and `6900` both map to PYG | Retain `source_currency_code`, `currency_of_origin`, `unit_currency`, and `economic_currency`; key on source code or the economically equivalent origin/unit pair. Do not silently filter collisions; publish quarantine counts | Complete, economically interpretable bank/finance panels | Source-to-research row conservation; zero duplicates/conflicts on `(source_id, period, entity_id, item_id, source_currency_code)`; the independent test already shows zero with this key |
| The file contains 13,953 uncertified series alongside 32 certified ones | Define the distributable interface as `research.*` plus its catalog/flags, or distribute a researcher-only artifact. Require every published scalar observation to join a certified series and every long dataset to a certified dataset rule | Prevents accidental use of provisional/raw data | Automated negative test proves no uncertified series/dataset is reachable from the published interface; release documentation states scope |
| Official provenance is incomplete for all 22 vintages | Populate official URL, publisher release identifier/date, retrieval timestamp/method, license, and immutable snapshot evidence; make completeness release-blocking for published data | Re-acquisition, citation, legal clarity, and defensible lineage | `main.v_source_provenance.provenance_status='complete'` for every released vintage; license status no longer `unverified` |
| As-of interfaces expose inferred availability and only one vintage per source | Either label/disable as-of and revision interfaces for this release, or collect official publication timestamps and successive immutable vintages prospectively | Prevents invalid pseudo-real-time and revision claims | No research row with inferred availability when real-time use is allowed; at least two genuine vintages for any series advertised as revision-capable; source-based as-of spot checks pass |

### P1 — materially limits research usability

| Exact problem and evidence | Precise remedy | Expected benefit | Verification criterion |
|---|---|---|---|
| Economic metadata are overwhelmingly `not_reviewed`; no human series review exists | Prioritize a release set by domain, then review definition, unit, multiplier, frequency, reference period, stock/flow/not-applicable, nominal/real, base, SA, transformation, valuation, hierarchy, and evidence | Researchers can select the economically correct series without institutional memory | Every released series has a signed review row and no required semantic field is null/`not_reviewed`/unresolved |
| 1,729 identities retain generated/source-value artifacts and 818 rely on position | Revisit parser header paths and natural keys; create semantic identifiers; map retired IDs through the migration/alias mechanism; quarantine unresolved cases | Stable continuity across workbook layout changes | No released ID contains generated column/source-value disambiguators or has positional stability; migration resolution is one-to-one |
| Seven short scalar series remain ambiguous; 465 gap cases need confirmation; the internal gate reports 499 | Reconcile each against source cell coordinates and expected grids; mark legitimate entry/exit/no-movement/blank cases explicitly; repair parser failures | Separates real sparsity from missing data | Each worklist row has source evidence and disposition; independent and built-in gap screens reconcile exactly |
| 6,522 numeric cells lie outside reviewed parser regions | Extend parser regions or record explicit exclusion rules tied to source evidence | Prevents silent omission of numeric content | Zero unreviewed numeric cells in every promoted worksheet |
| Hierarchy unresolved for 7,874 series; only 3,814 have domain mapping | Populate hierarchy roles/parents and expand controlled domain/subdomain mappings | Safe aggregation and discovery | Every released aggregate/component has a tested hierarchy; every released series has one controlled domain assignment |
| Canonical continuity/concordance/methodology registers are empty | Populate methodology regimes, break dates, comparability, classification concordances, and cross-source canonical memberships only after review | Defensible long spans and cross-source substitution | Continuous/canonical series have evidence-backed mappings and break tests; no automatic splicing without a reviewed regime |
| Other bank/finance panels show the same currency-collision pattern and explicit null measures | Build a common long panel model preserving source currency and a missing-value status/reason; publish only after key/accounting tests | Extends panel research safely beyond statements | Row accounting, key uniqueness, mapping completeness, and null-reason checks pass for each panel |
| No persisted foreign keys | Add foreign keys where operationally feasible; otherwise add release-blocking orphan/key tests for every dimension/fact and every research view | Protects future updates | Zero orphans/duplicates is enforced on every build and a deliberate bad fixture blocks release |

### P2 — important improvements

| Exact problem and evidence | Precise remedy | Expected benefit | Verification criterion |
|---|---|---|---|
| Index bases use multiple textual variants; `measure_type` is null for every series; `canonical_name` is absent from `dim_series` | Introduce controlled codes and separate display labels; populate measure type and canonical naming only when reviewed | Cleaner search, joins, and automated validation | Controlled-value tests pass; display-label variation no longer creates distinct semantics |
| Researchers can easily confuse raw `period`, statement projections, and actuals | Publish a concise data dictionary and query cookbook using `reference_period_start/end`, `observations_latest_actual`, projections, and certification fields | Reduces technically valid but economically wrong SQL | Acceptance test with representative researcher tasks produces the intended series and excludes projections |
| Discontinuity screen has 38,433 flagged observations but no stored review dispositions in the attachment | Store review outcome, methodology explanation, or waiver evidence at series/period level | Auditable treatment of genuine jumps versus errors | Every released flagged jump has a disposition and evidence |

## 7. Final readiness decision

**Do not hand the database to researchers as a broad, research-ready macroeconomic database.** It is appropriate for maintainers and for a tightly controlled pilot using selected objects.

A limited preview can be released only with an explicit scope statement:

- scalar work must use the 32 rows of `research.series_catalog` and `research.observations_latest_actual`;
- `research.curves` and `research.transactions` are structurally certified for exploratory use, while provenance/license limitations remain;
- `research.entity_panel` must be withdrawn until corrected;
- no real-time, vintage, revision, or release-timing claims are allowed;
- provisional/raw/canonical series are discovery candidates, not validated research inputs.

Minimum criteria for a broader release are: completion of every P0 item; human semantic review of the intended released series; resolution or explicit quarantine of their P1 identity/gap/hierarchy/unit issues; zero release-blocking errors; reconciled source-to-public row counts; complete official provenance for released sources; and an explicit decision either to support genuine vintages or to remove real-time/as-of claims.

## 8. Reproducibility appendix

### Files supplied with this report

- `series_diagnostics.csv`: all 13,985 series/variants, including counts, periods, spans, documented/inferred frequency, gap metrics, stored/grid missingness, numeric checks, metadata, provenance, flags, and certification.
- `suspicious_series.csv`: all 3,019 suspicious/unresolved series with classification, evidence, severity, confidence, and action.
- `panel_variant_diagnostics.csv` and `panel_table_summary.csv`: bank/finance panel variant and table-level checks.
- `view_health.csv`: bind result for every stored view.
- `catalog.json` and `metrics.json`: complete catalog and principal metric outputs.
- `audit_catalog.py` and `audit_diagnostics.py`: executable read-only audit logic. Run with `python audit_diagnostics.py DATABASE --output audit_outputs`.

### Key SQL logic

Catalog inventory:

```sql
SELECT * FROM duckdb_schemas();
SELECT * FROM duckdb_tables() WHERE NOT internal;
SELECT * FROM duckdb_views() WHERE NOT internal;
SELECT * FROM duckdb_columns() WHERE NOT internal;
SELECT * FROM duckdb_constraints();
SELECT * FROM duckdb_indexes();
SELECT * FROM duckdb_functions()
WHERE NOT internal AND function_type IN ('macro', 'table_macro');
```

Canonical fact integrity:

```sql
SELECT count(*) AS rows_total,
       count(DISTINCT series_id) AS series,
       count(value) AS nonmissing_values,
       sum((value IS NULL)::INTEGER) AS null_values,
       sum((NOT isfinite(value))::INTEGER) AS nonfinite_values,
       min(period), max(period)
FROM canonical.fact_series_events;

SELECT series_sk, period, vintage_sk,
       count(*) AS n, count(DISTINCT value) AS distinct_values
FROM canonical.fact_series_events
GROUP BY 1,2,3
HAVING count(*) > 1;
```

Current actual key and projection separation:

```sql
SELECT count(*) AS rows_total,
       count(DISTINCT (series_id, period)) AS logical_keys,
       count(*) FILTER (WHERE observation_status='observed') AS actual_rows,
       count(*) FILTER (WHERE observation_status='after_publication') AS projection_rows
FROM main.v_publisher_statement_latest;
```

Series-level logic:

```sql
-- For every dim_series row, left join current publisher observations.
-- Aggregate non-missing count, distinct source/reference periods, first/last
-- period, span, stored-null/non-finite counts, modal lag, maximum lag, and
-- regular-frequency unexpected steps. Join expected_observation_grid,
-- observation_missingness, quality_flags, source provenance, titles/domains,
-- active fact/staging duplicate screens, and certification status.
-- The complete executable query is series_sql in audit_diagnostics.py.
```

Published entity-panel defect and remedy test:

```sql
WITH source AS (
  SELECT * FROM main.v_banks_eeff_documented
  UNION ALL BY NAME
  SELECT * FROM main.v_financial_eeff_documented
), current_key AS (
  SELECT source_id, fecha, entity_id, statement_item_id, economic_currency,
         count(*) AS n, count(DISTINCT importe) AS distinct_values
  FROM source GROUP BY 1,2,3,4,5
), corrected_key AS (
  SELECT source_id, fecha, entity_id, statement_item_id, codigo_moneda,
         count(*) AS n, count(DISTINCT importe) AS distinct_values
  FROM source GROUP BY 1,2,3,4,5
)
SELECT
  (SELECT count(*) FROM source) AS source_rows,
  (SELECT count(*) FROM current_key WHERE n>1) AS current_collisions,
  (SELECT count(*) FROM corrected_key WHERE n>1) AS corrected_collisions;
```

Certification, metadata, provenance, and vintage coverage:

```sql
SELECT count(*) FROM canonical.dim_series;
SELECT count(*) FROM canonical.series_review;
SELECT count(*) FROM canonical.rule_certified_series;
SELECT count(*) FROM research.series_catalog;

SELECT provenance_status, count(*)
FROM main.v_source_provenance GROUP BY 1;

SELECT source_id, count(DISTINCT vintage_id)
FROM raw.source_files GROUP BY 1;
```

View health:

```sql
-- For every non-internal row in duckdb_views():
SELECT * FROM "schema"."view" LIMIT 0;
```

### Evidentiary limits

Verified findings above come from read-only SQL against the attached database. “Likely” classifications use stored identity stability, generated labels/paths, source coordinates, gap behavior, and database warnings; they do not assert that the underlying numeric value is wrong. Items requiring original workbooks, parser/configuration source, referenced output worklists, official publisher pages, or a clean rebuild remain undetermined because those materials were not attached.
