# Empirical readiness assessment — what is missing to run econometrics on this database

**Date:** 2026-09-03
**Database assessed:** `database/paraguay_macro_pilot.duckdb`, schema 38, build `build:5b33365376bc2a1c753da6b1`
**Method:** read-only queries against the live database and a reading of the current code. No project
source, input or database was modified; this report file was updated at the user's request. Every
number below is reproducible — the queries are in the appendix.

**Question asked:** what is still missing before this database can be used for an econometric or
empirical exercise?

**Relationship to the previous empirical-readiness report:** this is a cumulative revision, not a
replacement written without the earlier work. It preserves the previously established architecture,
database diagnostics, reproducible queries and unresolved findings; rechecks them against schema 38;
marks earlier audit findings that are now materially resolved; corrects the earlier description of
the `CUADRO 60c` exchange-rate evidence; and adds the issue-by-issue closure plan in section 11.

---

## 1. Verdict

**Overall assessment: Conditionally usable.**

The ingestion and database-engineering system is operationally sound. The schema-38 database opens
read-only, its SHA-256 matches its sidecar, all 22 sources completed, the principal natural keys are
unique, all 244 worksheet reconciliations balance, projections are separated from realized
observations, and the complete regression suite — including an isolated rebuild from the supplied
source files — passes with no failures or skips.

It is not yet suitable as a general-purpose, automatically trusted econometric database. It can be
used now for carefully selected, manually verified series. The remaining binding problems are:

1. the economic review layer is empty;
2. some unit assignments are demonstrably wrong;
3. monthly dates cannot safely be joined using the default `period` column;
4. the default extraction helper omits essential research metadata;
5. official provenance and historical vintages are absent;
6. aggregation hierarchies and several event identities remain unresolved;
7. bank personnel/channel panels contain unexplained dimensional duplicates;
8. the canonical cross-source macroeconomic layer is still empty.

The existing architecture should be preserved. The layered database, raw evidence, release
isolation, validation machinery and fail-closed research gate are worth keeping. What is missing is
primarily a reliable research-facing extraction surface and substantive economic adjudication.

The production database was not modified during this assessment. Its verified SHA-256 was:

```
0b5a7c25c809553e18f11bb1297af688fafe8b8405837a84f5449215d09d7774
```

### Prioritized findings

| ID | Severity | Confidence | Category | Finding and consequence |
|---|---|---|---|---|
| ER-01 | **High** | High | Correctness / economic semantics | Exchange-rate inference assigns `PYG_PER_USD` to index series and quotations against non-USD currencies. Unit-based selection can silently combine incomparable variables. |
| ER-02 | **High** | High | Research usability / correctness | Monthly `period` values use incompatible day conventions. Exact date joins can return empty or incomplete samples, and 164 series mix conventions internally. |
| ER-03 | **High** | High | Economic semantics | Zero series and zero worksheets have completed economic review; every validated research mart is empty. |
| ER-04 | **High** | High | Reproducibility / real-time research | All 22 vintages lack official acquisition metadata and there is only one vintage per source. Real-time, revision and publication-lag analysis are not supportable. |
| ER-05 | **Medium–High** | High | Research usability | The default helper returns values without labels, frequency, units, normalized period bounds or table title. |
| ER-06 | **Medium–High** | High | Data quality / semantics | 4,057 series have unresolved units; 7,540 documented series have unresolved hierarchy; 820 identities are positional or positional-lane. |
| ER-07 | **Medium** | High | Data quality | 6,522 numeric cells outside parser regions remain unreviewed and prevent 49 affected worksheets from being validated. |
| ER-08 | **Medium** | High | Panel correctness | Bank and finance-company channel/personnel panels contain 411 unexplained dimensional duplicate groups affecting 822 rows. |
| ER-09 | **Medium** | High | Validation / research usability | 38,433 large discontinuities and 4,428 gap episodes remain review worklists rather than adjudicated outcomes. |
| ER-11 | **Medium** | High | Research usability | Canonical series, memberships, methodology regimes and classification concordances are empty. Cross-source equivalence is not established. |
| ER-12 | **Low** | High | Reproducibility | The active build records `git_dirty = TRUE`; the current environment differs from `renv.lock` for transitive package `Rcpp`. |
| ER-14 | Enhancement | High | Scope | No unemployment, employment, occupation or population series was found; labour-market exercises require another source. |

---

## 2. What is genuinely ready

Stated first because it is substantial, and because the rest of this document is a list of problems.

| Fact | Measure |
|---|---|
| Monthly scalar series with ≥ 60 observations | **3,164** |
| …with ≥ 120 observations | **3,007** |
| Median observations, monthly scalar series | **186** (over 15 years) |
| Quarterly scalar series with ≥ 60 observations | 457 |
| Explained missing periods | 20,647, each with a reason |
| Publisher projections, separated from outcomes | 343 across 186 series |
| Source reconciliation | exact, 244 records, zero unexplained residual |

The headline macroeconomic variables are all present, and their units are mostly resolved:

| Concept | Candidate series | Units resolved |
|---|---:|---:|
| CPI / inflation | 20 | 20 |
| GDP | 25 | 24 |
| Monthly activity (IMAEP) | 8 | 8 |
| Policy / interbank rates | 15 | 13 |
| Monetary aggregates | 19 | 19 |
| Credit | 20 | 20 |
| Exchange rates | 11 | 11 |
| Exports / imports | 418 | 418 |
| Fiscal | 36 | 36 |

Provenance runs to the A1 cell for documented sources, `marts.v_catalogue_scalar_series` is an
informative discovery surface, and since schema 38 the published file is verifiable with
`shasum -a 256 -c`.

**Labour is the one thin domain**: 30 series, and a search for `desemple|desocupa` returns **zero**.
There is no unemployment series in this database.

### Previous audit findings now materially resolved

| Previous issue | Current status |
|---|---|
| Failed builds could alter published data | Resolved through isolated candidate databases and atomic publication |
| CSV rows could disappear silently | Resolved through row accounting and declared rejection reasons |
| Three blank-volume securities trades were omitted | Resolved; retained with `volume_status = not_reported` |
| Coverage-dashboard many-to-many join | Resolved; 242 rows for 242 distinct source-sheet keys |
| Formula risk existed only at worksheet level | Resolved; 81,367 formula-derived observations are identifiable individually |
| As-of history lost superseded vintages | Mechanically resolved and regression-tested |
| Series review did not control research eligibility | Resolved; the series register and worksheet status are both binding |
| Concurrent updates could overwrite each other | Resolved through locking and base-hash verification |
| Runtime environment was not recorded | Materially resolved; all 61 package records and build metadata are retained |
| Backup retention had no tooling | Dry-run classification and retention tooling now exists |
| Warning noise and a skipped defect-state test | Resolved; the full suite has no skips |
| Stale schema-12/14 flat-file exports could be mistaken for current data (ER-10) | Resolved during repository cleanup; the exports, inventory and obsolete links were removed |
| Superseded database backups occupied approximately 15 GB (ER-13) | Resolved during repository cleanup; all superseded local backups were removed while the current database and immutable source archive were retained |

---

## 3. Blocker 1 — a cross-source join silently returns zero rows

*Engineering. Not named by any audit. Fix first.*

Monthly series do not share a date convention:

| Convention | Series | Observations |
|---|---:|---:|
| Month end | 2,057 | 260,804 |
| Month start (day 1) | 1,757 | 580,732 |
| Other | 14 | 103 |

Worse, **164 monthly series mix both conventions inside a single series** — 150 with two
conventions, 14 with three. They include core monetary aggregates:

- `M2 — Billetes y monedas en circulación`
- `Activos Internos Netos (AIN) — Total`
- `Crédito y depósito del sector público`

A single series whose own time index alternates between day 1 and month end will produce wrong lags
and wrong differences in any time-series package, silently.

### Demonstrated

Joining the consumer price index (economic annex, dated day 1) to the exchange rate
(`exchange_rates`, dated month end) through the documented read path:

```
CPI       378 observations
FX rate   451 observations

  ⋈ ON period          →     0 rows
  ⋈ ON month           →   378 rows
```

**No error. No warning. An empty estimation sample.**

The normalisation that fixes this — `period_start` and `period_end`, correctly day 1 and month end
for all 3,986 monthly series — exists on `main.v_series_observations`. But `README.md` and
`scripts/05_query_helpers.R` point researchers at `main.v_series_latest`, **which does not carry
either column**.

---

## 4. Blocker 2 — the documented read path returns no metadata

*Engineering.*

`series_latest()` returns seven columns:

```
series_id, period, value, vintage_id, publication_date, source_file, observation_status
```

**No label. No unit. No frequency.** A researcher must know to join `canonical.dim_series`.

And when they do, the label is not an identifier:

| Measure | Value |
|---|---:|
| Distinct labels among scalar series | 4,813 |
| Labels used by more than one series | **1,599** |
| Scalar series sharing a label with another | **4,015 of 7,229 (56%)** |
| Worst case: series sharing one label | 16 |

`PIB a precios de comprador` appears on **13 worksheets**. Two of them are indistinguishable on
every field a researcher can see:

| Sheet | Unit | Freq | `nominal_real` | Base year | Mean value |
|---|---|---|---|---|---:|
| CUADRO 6 | PYG | quarterly | real | 2014 | 39,262,581.0 |
| CUADRO 6a | PYG | quarterly | `not_reviewed` | — | 35,356,590.3 |
| CUADRO 7 | PYG | quarterly | real | 2014 | 39,262,557.8 |
| CUADRO 7a | PYG | quarterly | `not_reviewed` | — | 35,356,590.3 |

CUADRO 6 and CUADRO 7 differ by **23 units in 39 million**. The 6/7 pair is almost certainly
constant-price and the 6a/7a pair current-price, but nothing in the metadata says so.

The only field that separates them is the published table title —
*"Producto interno bruto trimestral (Incluye binacionales)"* and its variants — and **`table_title`
is not exposed in any published view.** It lives in `staging.documented_series_snapshot`, a staging
table.

---

## 5. Blocker 3 — some unit metadata is confidently wrong

*Targeted repair. Needs someone who reads the workbooks, not an economist.*

Units are inherited at worksheet level, so a worksheet mixing units mislabels everything on it.
`CUADRO 60c` is the clear case — a real-exchange-rate table where every column was tagged with the
sheet's unit:

| Series on CUADRO 60c | Declared unit | Actual value range | Correct interpretation |
|---|---|---:|---|
| IPC | `PYG_PER_USD` | 100.0 – 659.5 | Index |
| TCN | `PYG_PER_USD` | 100.0 – 412.3 | Index |
| TCR Br | `PYG_PER_USD` | 65.0 – 179.1 | Bilateral real-exchange-rate index |
| TCR USA | `PYG_PER_USD` | 87.6 – 194.0 | Bilateral real-exchange-rate index |
| TCR Arg | `PYG_PER_USD` | 51.7 – 129.0 | Bilateral real-exchange-rate index |

The worksheet title explicitly states `enero 1995 = 100`. Those five are **index numbers**, not
prices of foreign currency. The true daily PYG/USD observations with values around 5,928–6,093 are
on `Cotizaciones Diarias`, not on `CUADRO 60c`; an earlier draft of this report incorrectly placed
them in the `CUADRO 60c` table. The correction does not weaken the finding: a researcher filtering
`unit_code = 'PYG_PER_USD'` receives both index points and actual currency quotations.

Nine worksheets carry the `PYG_PER_USD` tag. `CUADRO 60a` supplies an independently confirmed second
error: Euro, Argentine-peso and Brazilian-real quotations all carry unit `PYG_PER_USD` and currency
`PYG/USD`; only the USD series can have that denominator. `USD Fin Mes`, with values from 3.1 to
147.5, also requires methodological review before its early history is combined with modern rates.

Besides these, **340 scalar series remain `UNRESOLVED_SOURCE_UNITS`** and **148
`MIXED_PHYSICAL_UNITS`**.

---

## 6. Blocker 4 — the economics is genuinely unestablished

*This is the part that needs an economist, and it is the largest item.*

For the 7,229 scalar macro series:

| Field | Established | Share |
|---|---:|---:|
| Unit | 6,889 | 95% |
| Scale | 7,229 | 100% |
| Frequency | 7,229 | 100% |
| Stock / flow | 669 | **9%** |
| Nominal / real | 37 | **0.5%** |
| Seasonal adjustment | 14 | **0.2%** |
| Hierarchy resolved | 422 | **6%** |
| **All six eligibility fields together** | **0** | **0%** |

**Not one series clears all six, even counting values derived from published wording.**

This matters for how the problem is framed: `marts.v_research_series` would be empty even if every
worksheet were promoted to `validated` *and* the series-review requirement added in schema 36 were
removed entirely. The binding constraint is that the facts have never been established — not that a
gate is too strict.

Three practical consequences:

- **You cannot deflate inside the database.** Only 37 series carry a price base year (all 2014), and
  no series is designated as a deflator. Index base years *are* recoverable from the data — `IMAEP
  Serie Original` averages exactly 100.0 in 2014 — but recovering them is the researcher's problem
  and the recovery is not recorded anywhere.
- **You cannot systematically select a seasonal convention.** The sources publish `Serie Original`,
  `Serie ajustada` and `Tendencia Ciclo` variants, but only 14 series carry any
  `seasonal_adjustment` value, so the three cannot be told apart by query.
- **You cannot safely aggregate.** 94% of series have an unresolved hierarchy, so summing components
  risks double-counting a total that is already in the set.

The cross-source concept layer (`canonical_series`, `map_canonical_series`, `methodology_regime`,
`continuity_map`) is empty, so nothing links a measure in one source to the same measure in another.

---

## 7. Blocker 5 — real-time work is impossible, and the loss is permanent

*Acquisition. Cannot be backfilled.*

One vintage per source. **Zero recorded revisions.** No operator-recorded `available_at`.
`series_as_of_date('2020-12-31')` returns nothing.

The machinery is now correct — schema 36 repaired a carrier that would have returned the *current*
vintage at every historical cutoff even once vintages existed — but the evidence only accrues going
forward. **Every month that passes without retaining the publications is a month of real-time
history that cannot be recovered later.** This is the only item on this list whose cost grows with
delay.

Without it: no forecast evaluation, no nowcasting backtest, no publication-lag analysis, no event
study conditioned on what was knowable at the time.

---

## 8. Resolved repository trap

The former `revisiones/series_observations/*.csv` export and `series_inventory.csv` were generated
against **schema 12/14**, before the identity and grain repairs incorporated in schema 38. They and
the obsolete inventory documentation have now been removed from the working tree.

No flat-file research export is currently supported. Researchers must use the governed database
interface. If a flat export is added later, it must be generated reproducibly from the current public
contract and carry its schema version, build ID, database checksum, query version and grain.

---

## 9. What to do, in order

### P0 — required before using the selected variables

1. **Define one concrete empirical exercise.** Select perhaps 5–30 variables, not all 13,985
   series. Readiness depends on whether the exercise is a VAR, panel model, event study, forecast or
   historical decomposition.
2. **Correct the confirmed exchange-rate unit errors.** Review every series on `CUADRO 60a` and
   `CUADRO 60c`, plus the other worksheets currently producing `PYG_PER_USD`.
3. **Use normalized periods.** Construct monthly samples from `period_start` or `period_end`; never
   join cross-source monthly data on `main.v_series_latest.period`.
4. **Review every selected series economically.** Complete its definition, timing, stock/flow,
   unit, scale, currency, valuation, nominal/real, seasonal, transformation, hierarchy and
   comparability evidence. Promote only the worksheets actually required by the exercise.
5. **Inspect the selected observations against their sources.** Review signs, bases, gaps,
   discontinuities, formula/hidden-row provenance and total/component status.
6. **Freeze the research input.** Record the build ID, database SHA-256, exact series IDs,
   extraction SQL, sample interval, transformations and exclusions.

### P1 — required for reliable multi-variable research

1. **A research extraction layer.** One view carrying what a researcher needs on the path they are
   told to use: `series_id, label, table_title, source_id, source_sheet, period_start, period_end,
   frequency, unit_code, scale_multiplier, currency, stock_flow, nominal_real,
   seasonal_adjustment, value, value_in_base_units, vintage_id, available_at`. A wide-pivot helper
   should make the join key explicit rather than silently guessing it.
2. **Expose `table_title`.** It is often the only field that distinguishes repeated labels and is
   currently absent from the generic research-facing views.
3. **Resolve units, hierarchy, identity stability and methodology breaks for the selected core.**
4. **Work through the discontinuity and gap queues for selected variables.**
5. **Add the economic accounting identities relevant to the exercise.** Cell reconciliation proves
   parser completeness; it does not prove national-accounts, monetary or balance-sheet identities.
6. **Resolve direct-panel dimensional duplicates** before aggregating channels or personnel.
7. **Record official provenance** for every participating source.

### P2 — needed for a reusable research platform

1. **Review 30–50 series for the first intended exercise — not 13,985.** The register
   (`config/series_review.csv`), its vocabularies and its gates are built and empty;
   The update pipeline regenerates `outputs/canonical_core_candidates.csv`, which listed 108
   candidates across 14 concepts in the audited build, so the reviewer can pick from a menu rather
   than searching 94 worksheets of Spanish prose.
2. **Populate a small canonical core** only after source-level review, covering CPI, activity, GDP,
   monetary aggregates, rates, credit, exchange rates, reserves, fiscal variables, trade and
   external accounts.
3. **Record methodology regimes and comparability breaks.**
4. **Retain every monthly publication and record `available_at`.**
   `outputs/source_provenance_worklist.csv` names the missing field per vintage.
5. **Resolve the current transitive environment drift and build from a clean committed state.**
6. **Apply the documented backup-retention policy after future update or compaction runs.**
7. **Add missing domains where the intended research requires them, especially labour-market and
   demographic data.**

---

## 10. Bottom line

**A defensible single-country VAR appears feasible after a bounded review.** CPI, IMAEP, the
interbank rate and the exchange rate have 15–30 years of monthly data — *provided* the selected
series are verified against the workbooks, the known unit defects are resolved and dates are
normalised. The elapsed effort depends on access to source methodology and an authorized economic
reviewer; this audit does not assign an unsupported calendar estimate.

What is **not** currently supportable without the P0–P2 work above: automatic cross-source
selection, real-time analysis, aggregation over unresolved hierarchies, or research claims that
assume the units and definitions have already been economically certified.

The honest one-line description of the current state:

> A finished, well-governed source-preservation system with an unbuilt research interface and an
> unstarted economic review.

### Use-case verdict

| Exercise | Current status |
|---|---|
| Source inspection and descriptive exploration | **Yes** |
| Manually verified single-series analysis | **Yes, with caveats** |
| Small ex-post VAR/ARDL using manually reviewed series and normalized periods | **Possible after the P0 checks** |
| Bank or finance-company panel analysis | **Possible for well-defined panels; not channels/personnel aggregation yet** |
| Securities transaction counts | **Yes**, retaining the three unknown-volume transactions |
| Securities volume totals | **Yes, with an explicit non-missing-volume denominator** |
| Automated use of `marts.v_research_series` | **No — zero rows** |
| Automated cross-source macro dataset | **No** |
| Real-time, vintage, revision or publication-surprise work | **No** |
| Unrestricted aggregation across source series | **No** |
| Labour-market econometrics | **No relevant coverage identified** |

The engineering system is no longer the principal obstacle. Once the known unit defects, time-key
alignment and economic review are completed for a deliberately small variable set, the database can
support defensible ex-post econometric exercises. It is not necessary to review every series before
starting research; it is necessary to review every series actually used and preserve the exact
extraction and build identity.

---

## 11. Detailed issue-closure plan

This section converts findings ER-01 through ER-14 into a controlled remediation programme. It is a
plan, not evidence that the work has already been performed. Changes to semantic configuration must
be reviewed like data changes: a passing build proves that the declared rules were applied, not that
the declarations are economically correct.

### Governing principles

1. **Work use-case first.** Establish a small reviewed core for a named empirical exercise before
   attempting to certify the full catalogue.
2. **Keep source facts separate from reviewer decisions.** Preserve the workbook value, label,
   formula status and cell provenance; record unit, hierarchy, comparability and exclusion decisions
   as governed metadata with evidence.
3. **Fail closed.** A series with an unresolved required field must remain outside validated research
   marts. Do not replace `not_reviewed` with a guessed value merely to make a gate pass.
4. **Make every correction auditable.** Each decision needs reviewer, review date, source citation,
   rationale and, when values or interpretation change, the first affected build.
5. **Rebuild and test on an isolated candidate.** Publish only after source reconciliation, schema
   checks, semantic checks, research-extraction checks and checksum verification all pass.
6. **Freeze each research dataset.** An estimation result must be traceable to database checksum,
   build ID, series IDs, vintage rule, extraction query and transformation code.

### ER-01 — correct exchange-rate units and currency semantics

**Goal:** no exchange-rate series can be selected under a unit or currency pair that contradicts
its published meaning.

**Approach:**

1. Export a review worklist for every series on `CUADRO 60a`, `CUADRO 60c` and every other worksheet
   assigning `PYG_PER_USD`. Include `series_id`, complete dimensional path, table title, source cells,
   observed range, period coverage, current unit and currency fields.
2. Read the worksheet title, footnotes and BCP methodology for each item. Classify separately:
   nominal quotation, real-exchange-rate index, price index, period average, end-of-period, buying
   rate, selling rate and any historical currency regime.
3. Correct the governed unit/currency mapping at the narrowest stable identity level. `CUADRO 60c`
   index series should have an index unit and documented base (`January 1995 = 100`), while
   `CUADRO 60a` quotations must identify their actual numerator and denominator. Do not infer a
   denominator from the worksheet default when columns differ.
4. Investigate the early `USD Fin Mes` range as a possible redenomination, inverse quotation,
   different concept or parsing issue. If regimes are not directly comparable, split the series or
   record a methodology regime and prohibit an unqualified splice.
5. Search all units for the same pattern: one sheet-level unit applied to heterogeneous columns.
   Add a validation rule comparing declared unit families with table/column semantics and plausible
   magnitude, while treating magnitude as a warning rather than proof.
6. Rebuild an isolated candidate and compare affected observations and metadata with the source.

**Deliverables:** reviewed unit/currency decisions; source citations; any required methodology
regimes; a regression fixture covering the heterogeneous-unit worksheets; and a before/after list of
affected series.

**Acceptance criteria:** every affected series has a defensible unit, currency pair, quotation basis,
timing and index base where applicable; filtering by `PYG_PER_USD` returns only PYG per USD
quotations; the five `CUADRO 60c` indices cannot enter that result; no unresolved `CUADRO 60a/60c`
series is research eligible; source reconciliation and the full regression suite pass.

**Owner / dependencies / impact:** economist plus data curator; requires official table notes. This
can change metadata, series grouping and transformed research values, but must not alter raw source
values without independent evidence of a parsing defect. **Priority: P0.**

### ER-02 — establish one safe temporal key

**Goal:** frequency-compatible series join deterministically, including series that currently mix
month-start and month-end source dates.

**Approach:**

1. Define the public temporal contract by frequency. For monthly data, use a canonical month key
   (for example `period_start`) plus explicit `period_start` and `period_end`; retain the original
   source date separately. Define corresponding quarterly and annual bounds and do not manufacture a
   daily interpretation for lower-frequency observations.
2. Determine why the 164 internally mixed monthly series change convention. Separate source-layout
   changes from genuine timing changes. Where the economic concept changed from average to
   end-of-period, create a methodology regime rather than only normalising the date.
3. Extend the documented research-facing view and `series_latest()` so normalized bounds are
   returned by default. A wide helper must require an explicit join convention and reject incompatible
   frequencies unless an aggregation/alignment rule is supplied.
4. Add assertions that each series-frequency-regime has one temporal convention, all monthly keys
   are unique after normalization, bounds are ordered, and normalization creates no duplicate
   `series_id`–period keys.
5. Test representative CPI, exchange-rate, monetary, quarterly GDP and daily series. Preserve the
   demonstrated CPI–FX case as a regression test: the canonical monthly join must return the shared
   378-month sample while a raw-date join is clearly labelled unsafe.

**Deliverables:** written temporal contract, normalized public columns, helper behavior, regime
decisions for mixed series and regression tests.

**Acceptance criteria:** all public monthly series have one unique canonical month per observation;
zero unresolved within-regime convention changes remain among research-eligible series; the helper
cannot silently perform the unsafe exact-date join; lag/difference tests operate on a regular ordered
index. **Owner:** data engineer, with economist review where observation timing changes meaning.
**Impact:** interface and potentially series regimes, not raw values. **Priority: P0.**

### ER-03 — perform and govern economic review

**Goal:** populate validated research marts only with series whose meaning and permitted use have
been explicitly established.

**Approach:**

1. Choose the first empirical specification and its 5–30 input variables. Start from
   `outputs/canonical_core_candidates.csv` if regenerated by the current build; otherwise query the
   live catalogue rather than relying on stale exports.
2. For each candidate, complete `config/series_review.csv`: concept definition, unit and scale,
   currency, stock/flow, nominal/real, seasonal status, timing basis, frequency, transformation
   status, hierarchy role, source table/cell, methodology citation, exclusions, reviewer and date.
3. Compare observations with the source at the beginning, end, extrema, apparent breaks, missing
   episodes and a reproducible random sample. Explicitly review formula-derived and hidden-row cells.
4. Review only necessary worksheets in `config/table_status.csv`; do not validate an entire sheet
   because one series looks correct. If worksheet status is the gate granularity, document all other
   series thereby admitted or narrow the gate design before promotion.
5. Require independent review for high-impact judgement calls: splices, deflators, seasonal variants,
   unit corrections, sign conventions and total/component classifications.
6. Rebuild and inspect exactly which rows enter each validated mart. Record rejected series and the
   reason so absence is explainable.

**Deliverables:** completed review records and evidence packets for the chosen core, reviewer sign-off,
validated table statuses and a generated eligibility report.

**Acceptance criteria:** every series used in estimation satisfies every eligibility field; every
participating worksheet is appropriately reviewed; the resulting mart is non-empty for intentional
reasons; independently reproduced spot checks match the source; no research result is based on an
unreviewed fallback. **Owner:** macroeconomist/domain reviewer, supported by a data curator.
**Impact:** metadata, eligibility and possibly exclusions; no automatic value rewriting. **Priority:
P0 for selected variables, P2 for catalogue-wide coverage.**

### ER-04 — create prospective vintage and publication-time history

**Goal:** preserve what was available when, enabling future real-time and revision-aware research.

**Approach:**

1. For each source in `config/source_registry.csv`, document the official release page, direct file
   URL or retrieval route, publisher release timestamp, retrieval timestamp, source timezone,
   checksum, file name and operator/process identity in the provenance/vintage controls.
2. Establish a scheduled acquisition procedure that stores each publication immutably before it can
   be replaced upstream. A byte-identical file should deduplicate physically while retaining the
   acquisition event; a changed file must create a new vintage.
3. Define `available_at` conservatively. Use the official release timestamp when documented; use
   retrieval time with a lower-quality flag when it is not. Never backdate availability from the
   observation period.
4. Compare consecutive vintages by natural key and populate revision records for additions,
   deletions and value changes. Alert on a source layout change or unexpectedly empty/partial release.
5. Test as-of queries with synthetic or future accumulated vintages: before first availability,
   between releases and after a revision. Confirm that a cutoff never sees a later value.
6. Investigate official archives for historical releases. Import only files whose authenticity and
   release timing can be established; label reconstructed history separately from contemporaneously
   captured vintages.

**Deliverables:** acquisition runbook, complete forward provenance, immutable release archive,
revision reports, availability-quality flag and as-of regression tests.

**Acceptance criteria:** every new release has verifiable origin, checksum and availability time;
changed releases produce auditable revisions; as-of extraction passes no-look-ahead tests; partial
acquisition fails closed. Historical information that was never retained must be documented as
irrecoverable rather than marked resolved. **Owner:** data operations/data engineer. **Impact:**
workflow, storage, provenance and new vintage rows. **Priority: P0 now for future real-time use; not
a blocker for explicitly ex-post exercises.**

### ER-05 — provide a complete research extraction interface

**Goal:** a researcher can retrieve an interpretable, uniquely identified series without private
knowledge of staging tables.

**Approach:**

1. Specify the public contract in `config/public_view_contract.csv`, including at minimum the fields
   listed in P1 above plus hierarchy role, review status, methodology regime and source-date field.
2. Expose `table_title` through a governed canonical source rather than joining a staging snapshot at
   query time. Verify uniqueness at the intended series identity and define behavior when titles vary
   by vintage.
3. Update the public view and `scripts/05_query_helpers.R`. The helper should accept stable IDs or
   canonical concept IDs; label search may discover candidates but must not select ambiguously.
4. Return both stored value and a clearly named base-unit value. Never silently rescale, seasonally
   adjust, deflate, splice or aggregate.
5. Add contract tests for types, required columns, one-row-per-key grain, ambiguous labels, normalized
   dates, empty results and incompatible-frequency pivots. Document minimal extraction examples.

**Deliverables:** versioned public-view contract, research view/helper, tests and researcher guide.

**Acceptance criteria:** the public path supplies enough metadata to interpret every returned value;
ambiguous labels cannot silently choose a series; normalized time bounds are present; staging tables
are unnecessary for ordinary research; contract and grain tests pass. **Owner:** data engineer with
researcher acceptance testing. **Impact:** public interface and documentation. **Priority: P0/P1.**

### ER-06 — resolve units, hierarchy and unstable identities

**Goal:** remove semantic ambiguity for the research core and progressively for the complete
catalogue without creating false precision.

**Approach:**

1. Partition the 4,057 unresolved-unit records into true unknowns, mixed-unit sheets, missing mapping
   rules and non-measure/structural records. Resolve column-level units using published headers and
   notes; retain `unresolved` where evidence is insufficient.
2. Build explicit component/total relationships in `config/aggregate_identities.csv`, including sign,
   expected operator, tolerance, valid regime and whether the identity is definitional or diagnostic.
3. Review the 820 positional or positional-lane identities against stable labels, dimensions and
   source cells. Replace position-dependent IDs with semantic identities where stable; split regimes
   when source structure changes; retain a documented position dependency only when it is genuinely
   the publisher's identity.
4. Validate that each child has the intended parent by regime and that queryable hierarchies are
   acyclic. Do not assume that displayed indentation proves additivity.
5. Prioritize the selected research core and any variable used as a total, denominator, deflator or
   aggregation weight, then expand by source risk.

**Deliverables:** unit decisions with evidence, hierarchy/identity mappings, regime splits, exception
register and coverage dashboard.

**Acceptance criteria:** all research-eligible series have resolved units and hierarchy roles; no
positional identity is admitted without documented stability; hierarchy graphs are acyclic; declared
identities reconcile within justified tolerances or carry reviewed exceptions. **Owner:** data curator
and domain economist. **Impact:** metadata, identities and possibly series continuity. **Priority:
P0 for selected series; P1/P2 globally.**

### ER-07 — adjudicate numeric cells outside parser regions

**Goal:** account for all 6,522 flagged numeric cells and determine whether any represent omitted
observations or totals.

**Approach:**

1. Group the worklist by workbook, sheet, contiguous region and structural pattern rather than
   reviewing cells independently.
2. Inspect workbook context: title blocks, notes, hidden rows/columns, merged cells, formulas,
   repeated panels and print areas. Classify each region as observation, header/year axis, footnote,
   formula total, duplicate display, chart support, or other documented non-data content.
3. For genuine observations, correct `config/source_region_rules.csv` or source-specific parsing
   rules and add representative fixtures. For non-observations, record a narrow, reasoned exception;
   never suppress an entire sheet merely to clear the count.
4. Re-run cell accounting and reconciliation on an isolated build and review all newly admitted rows
   for identity, period, unit and duplication effects.

**Deliverables:** adjudicated worklist, scoped parser changes/exceptions, recovered-cell report and
regression fixtures.

**Acceptance criteria:** zero unreviewed out-of-region numeric cells on any validated worksheet;
every excluded region has a reason and evidence; recovered observations reconcile with the source;
layout perturbation tests fail clearly. **Owner:** ingestion engineer plus data curator. **Impact:**
parser configuration and potentially observation coverage. **Priority: P1, P0 for participating
worksheets.**

### ER-08 — resolve direct-panel duplicates

**Goal:** establish a unique analytical grain for channel and personnel panels before any panel
regression or aggregation.

**Approach:**

1. Materialize a diagnostic worklist for the 411 duplicate groups with all source dimensions,
   provenance cells, entity, period, measure, labels and values.
2. Determine whether the apparent duplicates are true duplicate records or missing dimensions such
   as branch type, service channel, geographic scope, institution class, total/component flag or
   reporting basis.
3. If a dimension is missing from the schema, add it to the governed direct-source contract and
   stable key. If rows are repeated source displays, retain one according to a documented provenance
   rule and keep an audit link to the duplicate cells. Never resolve by arbitrary `distinct`, first,
   last or summation.
4. Re-test uniqueness for the corrected grain and reconcile subtotals/totals where the publisher
   defines them. Check entity identifiers against `config/entity_dictionary.csv`.
5. Keep affected panels outside validated marts until every duplicate group is explained or excluded
   with a reviewed reason.

**Deliverables:** grain specification, duplicate adjudication file, any new dimension mappings and
panel-key/reconciliation tests.

**Acceptance criteria:** zero unexplained duplicates at the declared grain; aggregation does not mix
totals with components; entity-period balance is explainable; row counts reconcile before and after
the repair. **Owner:** data modeller plus financial-sector domain reviewer. **Impact:** schema/key,
panel membership and possibly analytical totals. **Priority: P0 for these panels, otherwise P1.**

### ER-09 — adjudicate discontinuities and gaps

**Goal:** distinguish real macroeconomic events and publication patterns from parsing, unit,
methodology or missing-data defects.

**Approach:**

1. Rank the 38,433 discontinuities and 4,428 gap episodes by research relevance, magnitude, core
   status, proximity to parser/layout changes and whether related series move similarly.
2. For each selected series, overlay source values and notes around every flagged episode. Classify
   events as real economic movement, seasonal pattern, crisis/policy event, base or methodology
   change, unit/scaling change, source omission, parser defect or unresolved.
3. Record classification, evidence, reviewer and permitted treatment. Methodology/base changes belong
   in regimes; parser defects require source-level repair; real events must remain unaltered.
4. Do not interpolate by default. If an empirical design requires imputation, perform it downstream,
   preserve an imputation indicator and report sensitivity to exclusion or alternative methods.
5. Add expected-gap calendars only when publication design supports them. Confirm that lags and
   growth rates do not bridge structural breaks or missing spans unknowingly.

**Deliverables:** adjudicated event/gap register, methodology regimes, any parser repairs and
research-specific missing-data decisions.

**Acceptance criteria:** every gap or discontinuity affecting a research sample is classified;
unresolved events exclude the affected span/series or are disclosed as a robustness risk; no source
value is winsorized, smoothed or imputed in the canonical layer without an explicit separate product.
**Owner:** economist with ingestion support. **Impact:** regimes, exclusions and downstream research
transformations. **Priority: P0 for selected samples; P2 globally.**

### ER-10 — stale export interface resolved

**Goal:** nobody can mistake schema-12/14 flat files for current schema-38 data.

**Resolution:** the stale exports, inventory and obsolete documentation links were removed during
repository cleanup. The governed DuckDB interface is the only supported analytical path.

**Ongoing control:** if supported flat exports are introduced later, generate them only through a
versioned deterministic command and embed schema version, build ID, database checksum, generation
time, query/contract version and grain. Validate their row count, key uniqueness and checksum, and
fail a freshness check when they do not match the active database contract.

### ER-11 — build a reviewed canonical macroeconomic core

**Goal:** represent cross-source economic concepts and continuity decisions explicitly, without
collapsing distinct definitions.

**Approach:**

1. Define a deliberately small concept dictionary for the first research programme: headline CPI,
   IMAEP/activity, GDP variants, policy/interbank rates, monetary aggregates, credit, exchange rate,
   reserves, fiscal balance/revenue/expenditure, trade and external accounts as required.
2. Review candidates using the current live catalogue and the pipeline-generated
   `outputs/canonical_core_candidates.csv`. For each member, document concept, unit, frequency,
   seasonal/price basis, timing, geography, sector,
   valuation and valid period in `config/canonical_series.csv` and
   `config/canonical_series_members.csv`.
3. Populate `config/methodology_regimes.csv` and `config/continuity_decisions.csv` for rebases,
   definition changes, source transitions and splices. Use `config/classification_concordance.csv`
   only where mapping evidence exists; quantify non-bijective mappings.
4. Never choose among sources solely by longest coverage. Define precedence and overlap checks; test
   levels/growth over overlap and retain discrepancies as diagnostics.
5. Publish raw members and any constructed canonical series separately. A splice or conversion must
   expose its formula, component series, regime and transformation version.

**Deliverables:** governed concept/member tables, regime and continuity records, overlap diagnostics,
canonical mart and concept-level documentation.

**Acceptance criteria:** every canonical observation traces to a source observation and decision;
members are definitionally compatible within their stated regime; overlaps reconcile or have
documented reasons; no automatic splice crosses an unreviewed break. **Owner:** lead economist plus
data modeller. **Impact:** canonical metadata and derived research series. **Priority: P1 after
ER-01/02/03/06.**

### ER-12 — restore environment and build-state reproducibility

**Goal:** a clean checkout can reproduce the published candidate with the declared R environment.

**Approach:**

1. Determine whether the installed `Rcpp` drift is intentional and whether it affects any compiled
   dependency. Compare the actual dependency graph with `renv.lock`; update the lock only through a
   reviewed environment change, or restore the locked version in a disposable environment.
2. Run the full suite and isolated rebuild from a clean committed worktree. Record R version,
   platform, package versions, locale, timezone and source checksums.
3. Make dirty-tree publication fail closed or require an explicit development override that cannot
   be confused with a research release.
4. Produce a machine-readable build manifest and confirm deterministic table counts/checksums, with
   documented exceptions for inherently variable metadata.

**Deliverables:** reconciled lockfile/environment, clean release commit, build manifest and clean-build
evidence.

**Acceptance criteria:** no unexplained package drift; release records `git_dirty = FALSE`; a second
authorized clean rebuild yields identical governed outputs or only documented nondeterministic
fields; all tests pass. **Owner:** maintainer/release engineer. **Impact:** environment and workflow,
normally not data values. **Priority: P1 before a citable release.**

### ER-13 — accumulated backup footprint resolved

**Resolution:** 39 superseded local backup databases occupying approximately 15 GB were removed
during repository cleanup. The current production database, its SHA-256 sidecar, Git LFS history and
the immutable source archive were retained.

**Ongoing control:** run `Rscript prune_backups.R` in dry-run mode after future updates or compactions,
review the exact candidates and apply retention only as a deliberate operator action. Preserve cited
release artifacts and test restoration periodically. Raw source vintages are not substitutes for
database backups and must remain under their separate immutable archive policy.

### ER-14 — close only the domain gaps required by research

**Goal:** add labour-market or demographic data only when an intended empirical question requires it.

**Approach:**

1. Translate the research question into required concepts: employment level/rate, unemployment,
   participation, hours, earnings, informality, sector, population denominator and relevant
   demographic splits.
2. Identify authoritative Paraguayan sources and assess frequency, sampling design, geographic
   coverage, breaks, public microdata/aggregate availability, revision policy and publication lag.
3. Define source registry, licensing, grain, entity/classification dictionaries, units, weights and
   ingestion contracts before loading. Survey estimates require sampling/weight metadata and should
   not be treated as administrative totals.
4. Build through the same isolated, reconciled, provenance-preserving pipeline; add classification
   concordances only where changes in industry/occupation/geography can be defended.
5. Validate published totals, uncertainty measures where available, break handling and population
   denominators before admitting the data to research marts.

**Deliverables:** scoped source assessment, approved data contract, provenance, validation identities
and reviewed series.

**Acceptance criteria:** the added domain supports the named question at the needed frequency and
grain; estimates reproduce published aggregates; weights, breaks and coverage are documented; no
unsupported interpolation is used to manufacture higher frequency. **Owner:** labour economist/data
engineer. **Impact:** project scope, sources, schema and observations. **Priority: optional unless the
research design requires labour/demographic controls or outcomes.**

### Programme sequence and dependencies

| Stage | Work | Depends on | Exit condition |
|---|---|---|---|
| 0. Specify use | Freeze the first model/question, concepts, frequency, sample and information-set requirement | None | Written research data specification and candidate series list |
| 1. Remove correctness blockers | ER-01 units; ER-02 time key; ER-08 if affected panels are used | Stage 0; source documentation | Correct units/grain/time contract and focused regression tests pass |
| 2. Certify inputs | ER-03 review; selected ER-06 semantics; selected ER-07 cells; selected ER-09 events | Stages 0–1 | Every selected series has evidence, review status and adjudicated sample risks |
| 3. Make extraction safe | ER-05 public interface; ER-10 stale-export disposition | Stages 1–2 define the contract | One reproducible extraction path with explicit metadata and keys |
| 4. Establish concepts | ER-11 canonical core and methodology regimes | Stages 1–3 | Traceable, definitionally compatible model-ready concept set |
| 5. Release reproducibly | ER-12 clean build; freeze checksum/query/transforms | Stages 1–4 | Clean, tested, checksummed research release and data manifest |
| 6. Expand capability | ER-04 prospective vintages; global ER-06/07/09 review; ER-14 if needed | Stable release process | Future real-time capability and/or broader validated coverage |
| 7. Operate sustainably | ER-13 retention and recurring reviews | Release/archive policy | Tested recovery and controlled storage |

Stages 1–5 define the shortest defensible route to ex-post econometrics. ER-04 must begin immediately
if future real-time research matters, but years of vintage history cannot be created retrospectively.
ER-13 and ER-14 do not block a small ex-post macro model unless storage pressure or the research
question makes them binding.

### Mandatory empirical-release gates

A dataset should be labelled **model-ready for a specified exercise** only when all of the following
are true. “Research-ready” applies to the declared variable set and sample, not automatically to the
whole database.

| Gate | Required evidence | Failure response |
|---|---|---|
| Identity and grain | Unique documented key; duplicates adjudicated; total/component role known | Exclude series/panel until resolved |
| Meaning | Definition, unit, scale, currency, price basis, seasonal status and stock/flow reviewed | Exclude; never guess metadata |
| Time | Canonical period key, observation timing and frequency known; no duplicate normalized periods | Correct contract/regime or exclude |
| Coverage | Start/end, gaps and missingness report for the estimation sample | Amend sample or document downstream treatment |
| Breaks | Discontinuities, rebases and methodology regimes adjudicated | Split regime, model break explicitly or exclude |
| Provenance | Source file/cell, source identity, checksum and retrieval lineage available | Do not certify the series |
| Cross-source comparability | Overlap and definition checks for canonical members | Keep sources separate |
| Transformations | Formula, lag convention, seasonal/price treatment and component IDs versioned | Recreate transformation transparently |
| No look-ahead | Vintage/availability rule appropriate to the design | Limit claim to ex-post/full-information research |
| Extraction reproducibility | Build ID, DB checksum, SQL/helper version, IDs, sample and exclusions frozen | Results are not reproducible; do not release |
| Statistical sanity | Ranges, zeros, signs, missingness, frequency, identities and outliers reviewed | Investigate; do not automatically delete/winsorize |
| Independent verification | Second reviewer reproduces selected source checks and extraction | Hold release pending review |

### Definition of final resolution

The project can be called **available for econometric and empirical exercises** when:

1. at least one named model-ready dataset passes every applicable release gate above;
2. ER-01 and ER-02 are corrected in the governed database interface, not only worked around in one
   notebook;
3. ER-03, ER-06, ER-07 and ER-09 are closed for every series and worksheet used by that dataset;
4. ER-05 provides the supported extraction route; ER-10 is already closed and must remain closed;
5. ER-08 is closed for any direct panel used, and ER-11 is complete for any cross-source canonical
   concept used;
6. ER-12 yields a clean, checksummed, reproducible release; and
7. the limitations of ER-04 and ER-14 are reflected in the allowed research claims.

This definition deliberately permits a reviewed ex-post macroeconomic dataset to be released before
all 13,985 series are certified. It does **not** permit the whole database to be described as
universally research-ready until the unresolved catalogue-wide semantics and validation queues are
closed. A release manifest should therefore state both the approved use cases and the non-approved
ones.

---

## Appendix — reproducing the numbers

Open the database read-only and run these. All were executed against schema 38 on 2026-09-03.

```r
source("scripts/01_utils.R")
con <- connect_project_database("database/paraguay_macro_pilot.duckdb", read_only = TRUE)
```

**Series universe and length (§2)**

```sql
WITH s AS (
  SELECT d.series_id, d.frequency, count(*) AS obs
  FROM canonical.dim_series d JOIN main.v_series_latest l USING (series_id)
  WHERE d.series_grain = 'scalar_series' GROUP BY 1,2)
SELECT frequency, count(*) AS series,
       count(*) FILTER (WHERE obs >= 60)  AS ge60_obs,
       count(*) FILTER (WHERE obs >= 120) AS ge120_obs,
       median(obs) AS median_obs
FROM s GROUP BY 1 ORDER BY 2 DESC;
```

**Date conventions and internal inconsistency (§3)**

```sql
SELECT CASE WHEN day(l.period) = 1 THEN 'month start'
            WHEN day(l.period) >= 28 THEN 'month end' ELSE 'other' END AS convention,
       count(DISTINCT d.series_id) AS series, count(*) AS observations
FROM canonical.dim_series d JOIN main.v_series_latest l USING (series_id)
WHERE d.frequency = 'monthly' AND d.series_grain = 'scalar_series'
GROUP BY 1 ORDER BY 2 DESC;

-- series whose own periods mix conventions
WITH c AS (
  SELECT d.series_id,
    count(DISTINCT CASE WHEN day(l.period)=1 THEN 1 WHEN day(l.period)>=28 THEN 2 ELSE 3 END) AS conventions
  FROM canonical.dim_series d JOIN main.v_series_latest l USING (series_id)
  WHERE d.frequency='monthly' AND d.series_grain='scalar_series' GROUP BY 1)
SELECT conventions, count(*) AS series FROM c GROUP BY 1 ORDER BY 1;
```

**The zero-row join (§3)**

```sql
WITH cpi AS (SELECT l.period, l.value FROM main.v_series_latest l
             JOIN canonical.dim_series d USING (series_id)
             WHERE d.label='IPC' AND d.unit_code='INDEX' AND d.frequency='monthly'),
     fx  AS (SELECT l.period, l.value FROM main.v_series_latest l
             JOIN canonical.dim_series d USING (series_id)
             WHERE d.label='USD — VENTA' AND d.frequency='monthly')
SELECT (SELECT count(*) FROM cpi) AS cpi_obs,
       (SELECT count(*) FROM fx)  AS fx_obs,
       (SELECT count(*) FROM cpi JOIN fx USING (period)) AS join_on_period,
       (SELECT count(*) FROM cpi JOIN fx
          ON date_trunc('month',cpi.period)=date_trunc('month',fx.period)) AS join_on_month;
```

**Label ambiguity (§4)**

```sql
WITH labelled AS (
  SELECT label, count(DISTINCT series_id) AS series
  FROM canonical.dim_series WHERE series_grain='scalar_series' GROUP BY 1)
SELECT count(*) AS distinct_labels,
       count(*) FILTER (WHERE series > 1) AS ambiguous_labels,
       sum(series) FILTER (WHERE series > 1) AS series_sharing_a_label,
       max(series) AS worst_case
FROM labelled;
```

**The unit defect (§5)**

```sql
SELECT substr(d.label,1,34) AS label, d.unit_code,
       round(min(l.value),2) AS min_v, round(max(l.value),2) AS max_v
FROM staging.documented_series_snapshot n
JOIN canonical.dim_series d USING (series_id)
JOIN main.v_series_latest l USING (series_id)
WHERE n.source_sheet = 'CUADRO 60c'
GROUP BY 1,2 ORDER BY max_v DESC;
```

**Semantic readiness (§6)**

```sql
SELECT count(*) AS scalar_series,
  count(*) FILTER (WHERE unit_code IS NOT NULL AND unit_code <> 'UNRESOLVED_SOURCE_UNITS') AS unit_ok,
  count(*) FILTER (WHERE scale_multiplier IS NOT NULL)      AS scale_ok,
  count(*) FILTER (WHERE stock_flow <> 'not_reviewed')      AS stockflow_ok,
  count(*) FILTER (WHERE nominal_real <> 'not_reviewed')    AS nomreal_ok,
  count(*) FILTER (WHERE seasonal_adjustment <> 'not_reviewed') AS seasadj_ok,
  count(*) FILTER (WHERE hierarchy_status <> 'unresolved')  AS hierarchy_ok
FROM canonical.dim_series WHERE series_grain = 'scalar_series';
```

**Real-time capability (§7)**

```sql
SELECT (SELECT count(*) FROM canonical.series_revisions) AS recorded_revisions,
       (SELECT count(*) FROM marts.v_series_projections) AS projections,
       (SELECT count(*) FROM main.v_series_latest)       AS realized_observations;
```
