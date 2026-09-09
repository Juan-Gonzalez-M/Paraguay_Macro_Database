# Economist source-review and catalogue approval workbook

**Status:** to be completed before the source bank is declared generally available  
**Product:** Paraguay Macro Database  
**Primary publisher currently in scope:** Banco Central del Paraguay (BCP)  
**Companion technical audit and implementation plan:**
[`Paraguay_Macro_Database_Audit.md`](../Paraguay_Macro_Database_Audit.md)

## 1. Purpose and redefined target

This workbook records the economic and source-interpretation decisions needed to publish a
comprehensive, source-faithful and queryable bank of the series recoverable from the BCP source
files included in this project.

The target is:

> Make every legitimate series in the included BCP publications discoverable and extractable,
> preserving its original observations, labels, time structure, dimensions, units and workbook
> provenance. Do not preselect variables or transform the source bank for one particular research
> design.

This is a more precise target than “make the database ready for econometrics.” The database is a
general input to many future research projects. A future researcher—not this source-bank build—will
choose variables, sample dates, transformations, lags, seasonal treatment and econometric methods.

### 1.1 What “all available data” means here

For the first release, “all available data” means all legitimate series recoverable from the source
files registered in this repository and successfully admitted to the build. It does **not** yet mean
all macroeconomic data ever published for Paraguay, all BCP web/API data, or data from other
institutions.

A numeric spreadsheet cell is not automatically a legitimate observation. Titles, years embedded
in headers, footnotes, axis labels, formula scaffolding, subtotals duplicated for presentation and
uninterpretable regions must not be converted into invented series. Conversely, a valid source
series must not disappear merely because its economic metadata has not yet been fully harmonized.

### 1.2 Required release layers

The project should distinguish four layers:

1. **Source-faithful data bank:** all admitted observations with stable source-derived identities,
   original meaning and provenance.
2. **Searchable series catalogue:** one record per series, sufficient to discover what is available.
3. **Reviewed economic layer:** optional, progressively curated concepts, classifications,
   concordances, hierarchies and continuity relationships.
4. **Research datasets:** project-specific selections and transformations created downstream.

Layers 3 and 4 must not silently overwrite layer 1. Incomplete optional harmonization is not a
reason to suppress a correctly parsed source series; unresolved source identity, grain, period or
unit ambiguity may be.

### 1.3 Explicitly out of scope for this workbook

Do not answer the following here:

- Which variables belong in a VAR, regression, forecast or other model.
- Which dependent variable, controls, instruments, shocks, lags or leads a researcher should use.
- Which sample period a future paper should select.
- Whether future research should log, difference, deflate, seasonally adjust, interpolate or splice
  a series.
- Which econometric estimator or identification strategy should be preferred.
- Whether a research-specific balanced panel should be created.

Those decisions belong to the documentation of each downstream empirical exercise.

---

## 2. How to complete this workbook

Use exact `source_id`, `source_sheet` and `series_id` values from the database and configuration
files. Labels are evidence but are not identifiers; the same label may legitimately occur in
different tables, dimensions, units or frequencies.

For every decision:

- Preserve the publisher's meaning. Do not silently improve, standardize or reinterpret it.
- Cite the workbook, worksheet, table, header, note, methodology document or source coordinates.
- State the scope and effective dates when a decision is not valid for the full history.
- Use `UNRESOLVED` where evidence is insufficient; state whether the affected data remain exposed
  as provisional or must be quarantined.
- Record the reviewer and an ISO date (`YYYY-MM-DD`).
- Distinguish observed source facts, reviewer interpretation and implementation instructions.
- Never approve a source-value correction merely because a value appears implausible. A correction
  requires evidence that the stored value differs from the source.

### 2.1 Decision status vocabulary

| Status | Meaning |
|---|---|
| `APPROVED` | Evidence is sufficient and the decision may be implemented. |
| `APPROVED_WITH_LIMITATION` | The item may be exposed only with the stated warning or scope. |
| `PROVISIONAL` | Source-faithful data may remain available, but the unresolved interpretation must be visible. |
| `QUARANTINE` | Do not expose the affected observations in the normal public interface. |
| `NOT_DATA` | The source region is presentation, metadata or another non-observation region. |
| `NEEDS_SOURCE_EVIDENCE` | No final decision can yet be made. |
| `NOT_APPLICABLE` | The question genuinely does not apply; explain why. |

### 2.2 Decision record template

```text
Decision ID:
Status:
Source ID / sheet / series IDs:
Question:
Answer:
Scope / effective dates:
Observed source evidence:
Reviewer interpretation:
Required implementation consequence:
Acceptance test:
Approved by:
Approved at:
Second reviewer, if required:
Second-review date:
```

Independent review is required for changes to stored values; unit or scale corrections; currency
direction; period interpretation; stock/flow timing; panel or curve grain; source-region exclusion;
methodology continuity; and total/component relationships used for validation.

---

## 3. Roles and decision authority

The economist supplies source meaning. The senior data engineer converts approved decisions into
bounded implementation tickets and reviews schema/grain consequences. The junior coder implements
only recorded decisions and escalates ambiguity.

| Role | Name | Authority | Date accepted |
|---|---|---|---|
| Lead source economist |  | Interprets publisher meaning and approves source semantics |  |
| Independent reviewer |  | Reviews high-risk economic/source decisions |  |
| Senior data engineer |  | Defines technical design and acceptance tests |  |
| Junior implementation coder |  | Implements approved, bounded tickets |  |
| Release approver |  | Authorizes publication of the source bank |  |

Answer:

1. Who may classify a worksheet or region as data, metadata or non-data?
2. Who may approve a worksheet as `validated`?
3. Who may change the unit, scale, frequency or period interpretation of a series?
4. Who may authorize a stored-value correction after a demonstrated parsing error?
5. Who may approve a canonical relationship across publications?
6. Who signs the final coverage statement?
7. If one person holds multiple roles, which high-risk decisions still receive independent review?

---

## 4. Public data contract: two grains, not one overloaded catalogue

The requested minimal catalogue contains both series attributes and observation/vintage attributes.
They must be delivered through two related public objects. Putting all fields in one row per series
would either discard observation detail or repeat catalogue rows with an unstated grain.

### 4.1 Object A: minimal series catalogue

**Required grain:** exactly one row per `series_id`.

| Required field | Meaning and rule |
|---|---|
| `series_id` | Stable identifier for one source-defined series at one defensible grain. |
| `label` | Original human-readable series label, preserved without using it as a key. |
| `full_series_path` | Ordered source header/dimension path that disambiguates repeated labels. |
| `source_id` | Stable identifier for the source publication family. |
| `source_filename` | Clearly defined representative filename; use `latest_source_filename` instead if it means the latest admitted vintage. |
| `source_sheet` | Original worksheet or equivalent source subdivision. |
| `table_title` | Original table/region title needed to interpret the label. |
| `frequency` | Source observation frequency, not an inferred research frequency. |
| `unit_code` | Controlled unit code, with original unit text retained elsewhere. |
| `scale_multiplier` | Multiplier converting the displayed source scale to the declared base unit. |
| `currency` | Currency when applicable; null must mean not applicable or unresolved according to a documented rule. |
| `first_period` | Earliest admitted observation period for the series under the catalogue's vintage rule. |
| `last_period` | Latest admitted observation period for the series under the same rule. |
| `observation_count` | Count of admitted observations under the same rule; the rule must say latest-only or all vintages. |

The recommended public name `latest_source_filename` is less ambiguous than `source_filename` at
series grain. If the requested field name is retained, its contract must explicitly say that it is
the filename supplying the latest admitted observation set, not the unique origin of the series.
Complete filename history belongs in Object B and the source-vintage table.

### 4.2 Object B: source-faithful observation extract

**Required grain:** one row per admitted `series_id` × source period × `vintage_id`. If the system
exposes only latest values, that must be a separate latest-only view, not an undocumented filter.

| Required field | Meaning and rule |
|---|---|
| `series_id` | Foreign key to exactly one series-catalogue row. |
| `original_period` | Publisher's period label/value before normalization. |
| `period_start` | Normalized inclusive start of the represented period. |
| `period_end` | Normalized inclusive/logical end of the represented period under one documented convention. |
| `value` | Parsed numeric observation in original published units. This is essential even though it was omitted from the initial field list. |
| `observation_status` | Realized, projection, preliminary, revised, deleted or other controlled status. |
| `vintage_id` | Release identity supporting revision-aware retrieval. |
| `source_filename` | Exact file from which this vintage observation came. |

Retain `source_id`, `source_sheet`, `publication_date`, `available_at`, original unit/scale text,
base-unit value and internal cell/region provenance where available. These may be additional public
columns or linked provenance objects; they must not be lost.

### 4.3 Current implementation mapping to verify after implementation

The prior inspected schema distributed the requested contract across several objects. This table is
a design inventory, not proof that current values are correct.

| Contract field | Previously observed location | Gap or decision required | Acceptance test |
|---|---|---|---|
| `series_id` | `marts.v_catalogue_scalar_series`, `main.v_series_observations` | Confirm stability and scope | Non-null; unique in catalogue; every observation joins exactly once |
| `label` | `marts.v_catalogue_scalar_series`, `canonical.dim_series` | Confirm original-label policy | Compare sample/all labels to source headers |
| `full_series_path` | Not present in the inspected public catalogue | Define construction and persist it | Repeated labels are distinguishable without inspecting code |
| `source_id` | Catalogue and observations views | Confirm registry foreign key | Every value joins one registered source |
| `source_filename` | `main.v_series_latest`, `main.v_series_observations`, `raw.source_files` | Define series-level versus vintage-level semantics | Exact filename joins to admitted vintage manifest |
| `source_sheet` | Catalogue and observations views | Confirm original spelling/normalization policy | Every admitted row maps to reviewed sheet inventory |
| `table_title` | Not present in inspected public catalogue | Extract/preserve region title | Non-null where source supplies a table title; exceptions documented |
| `frequency` | Catalogue, observations and series dimension | Verify against source, not row-count inference alone | Allowed code and period spacing agree, with exceptions listed |
| `original_period` | Not clearly exposed in inspected views | Preserve source period token separately from normalized dates | Round-trip sample to source label; no normalized date substituted |
| `period_start` | `main.v_series_observations` | Confirm inclusivity and timezone/type | Deterministic for every supported frequency |
| `period_end` | `main.v_series_observations` | Confirm end convention | No overlaps/gaps inconsistent with declared frequency unless documented |
| `unit_code` | Catalogue, observations and series dimension | Complete source review | Controlled code, original unit retained, unresolved visible |
| `scale_multiplier` | Catalogue, observations and series dimension | Complete scale review | `value_in_base_units = value * scale_multiplier` where applicable |
| `currency` | Catalogue and series dimension | Define null/not-applicable/unresolved states | Currency-required units have a valid currency or explicit unresolved flag |
| `first_period` | Catalogue | Define latest-only/all-vintage basis | Equals minimum period under documented rule |
| `last_period` | Catalogue | Define latest-only/all-vintage basis | Equals maximum period under documented rule |
| `observation_count` | Previously named `observations` in catalogue | Standardize name and counting rule | Equals recomputed count under documented rule |
| `observation_status` | Latest and observations views | Complete status vocabulary/source mapping | Allowed code; projections are distinguishable from realized data |
| `vintage_id` | Latest and observations views | Preserve release history | Joins exactly once to source-vintage manifest |
| `value` | Observation views | Add to explicit contract | Matches parsed source value and declared unit/scale |

### 4.4 Recommended catalogue additions

These fields materially improve discoverability and prevent misuse. They are recommended additions,
not substitutes for the required minimal fields:

- Original unit and scale text.
- `series_grain` and explicit dimension names/values.
- Publisher and source publication label.
- Domain and subdomain where reviewed.
- `stock_flow`, timing basis, nominal/real, seasonal adjustment, valuation and transformation.
- Index or price base year where applicable.
- Hierarchy role and parent identifier where supported.
- Semantic/review status and visible warning text.
- Publication date range and vintage count.
- Source or methodology URL where available.
- Stable table/region identifier and cell-level provenance link.

Approval:

```text
Catalogue contract decision ID:
Series-catalogue object name:
Observation-history object name:
Latest-only observation object name:
Meaning of source_filename at series grain:
Meaning of observation_count:
Period-end convention:
Null versus unresolved policy:
Approved required additions:
Approved by / date:
Senior engineer review / date:
```

---

## 5. Global scope and source coverage approval

The previous audit observed 22 registered BCP source files. Recompute this inventory from the live
manifest before completion; do not hard-code 22 as a permanent expectation.

### 5.1 Scope declaration

```text
Release identifier:
Publisher(s) included:
Source families included:
Number of registered files:
Number of admitted vintages:
Earliest source publication date:
Latest source publication date:
Known BCP publications intentionally outside this repository:
Known unavailable/password-protected/corrupt files:
Definition of complete for this release:
Evidence query/report:
Approved by / date:
```

### 5.2 Source-file inventory

Create one row for every registered file or vintage.

| Source ID | Exact filename | Vintage ID | Publication date | Sheets/regions expected | Ingestion result | Coverage status | Exclusion reason | Reviewer | Date |
|---|---|---|---|---|---|---|---|---|---|
|  |  |  |  |  |  |  |  |  |  |

Allowed coverage status:

- `COMPLETE`: every legitimate region was admitted or explicitly accounted for.
- `PARTIAL`: some legitimate regions remain unavailable; list them.
- `QUARANTINED`: parsing or interpretation is unsafe.
- `NO_DATA`: file contains no observations within scope; provide evidence.
- `SUPERSEDED_DUPLICATE`: byte-identical or demonstrably duplicate release; link the retained file.

### 5.3 Coverage questions

For each source family answer:

1. Are all supplied files represented in `raw.source_files` or the equivalent manifest?
2. Are file hashes, exact filenames, paths/URIs, sizes, ingestion timestamps and outcomes retained?
3. Are repeated releases treated as vintages rather than silently overwritten?
4. Are overlapping files reconciled without double-counting?
5. Are excluded files or worksheets visible in a machine-readable exclusions register?
6. Does a changed filename represent a new release, a replacement or the same bytes?
7. Are publication dates sourced from the publisher, file metadata or inference? Is that source
   recorded?
8. Can the release make a truthful coverage claim without implying data not yet collected?

---

## 6. Workbook, worksheet and source-region review

Complete this section once per worksheet and separately for multiple unrelated tables on one sheet.

| Field | Answer |
|---|---|
| Decision ID |  |
| Source ID |  |
| Filename / vintage ID |  |
| Source sheet |  |
| Region coordinates or stable region ID |  |
| Exact table title |  |
| Publisher's subject/domain |  |
| Data orientation | Rows are series / columns are series / matrix / panel / other |
| Header rows and columns |  |
| First and last legitimate data cells |  |
| Footnote/note regions |  |
| Hidden rows/columns/sheets |  |
| Merged-cell meaning |  |
| Formula-cell treatment |  |
| Repeated header treatment |  |
| Missing-value tokens |  |
| Provisional/projection markers |  |
| Duplicate presentation regions |  |
| Expected number of series |  |
| Expected number of observations |  |
| Status |  |
| Evidence |  |
| Reviewer / date |  |

Questions:

1. Which regions are observations, metadata, notes, decorative layout or formulas?
2. Do blank merged-header cells inherit the last nonblank parent, and over what exact range?
3. Are formula cells legitimate published values? If formulas and cached values differ, which is
   authoritative?
4. Are any sheets hidden, very hidden, filtered or outside the parser's selected range?
5. Do negative values use a minus sign, parentheses, color, trailing sign or another convention?
6. Which tokens mean missing, zero, not applicable, confidential, negligible or not yet available?
7. Are repeated totals genuine distinct concepts or duplicated presentation?
8. Does each excluded region have an explicit reason and reviewer?
9. Could a future layout change shift a table while still producing plausible but wrong output?
10. What structural signature should fail ingestion when the layout changes?

---

## 7. Series identity, labels and paths

The bank must preserve the source label while giving every distinct series a stable identity.
Duplicate labels are permitted; duplicate identities at the same grain are not.

### 7.1 Identity review form

| Field | Answer |
|---|---|
| Decision ID |  |
| Series ID(s) |  |
| Exact original label |  |
| Full series path |  |
| Table title |  |
| Source dimensions encoded in the path/ID |  |
| Series grain |  |
| Frequency |  |
| Unit/scale/currency |  |
| First/last period |  |
| Similar or duplicate labels |  |
| Why this is a distinct series |  |
| Identity stable across vintages? |  |
| Methodology/definition break? |  |
| Status and evidence |  |
| Reviewer / date |  |

### 7.2 Path construction approval

Define one deterministic `full_series_path` grammar. It should normally use ordered source-native
components such as:

```text
publisher / publication / table_title / section / row hierarchy / column hierarchy / dimensions
```

Answer:

1. Which components are mandatory?
2. How are blank inherited headers represented?
3. How are repeated labels disambiguated?
4. Are unit, currency and frequency part of identity or attributes? Explain each choice.
5. How are panel entity, maturity, instrument, sector, geography and counterpart dimensions encoded?
6. Which punctuation/whitespace normalization is allowed without changing meaning?
7. Can a source label correction in a later vintage retain the same `series_id`? Under what rule?
8. What happens when a table is moved or renamed but its concept remains unchanged?
9. What evidence is required to merge two source paths into one identity?

Acceptance criteria:

- A `series_id` resolves to one and only one approved grain.
- Every catalogue row has sufficient label/path context to distinguish it from same-label rows.
- ID generation is deterministic across unchanged re-ingestion.
- A file rename does not silently create a new economic series.
- A genuine dimension or definition change does not silently reuse the old identity.

---

## 8. Time, frequency and period semantics

Complete by table or series family; split the decision when conventions differ.

| Field | Answer |
|---|---|
| Source ID / sheet / series scope |  |
| Source period representation |  |
| `original_period` preservation rule |  |
| Frequency | Daily / monthly / quarterly / semiannual / annual / irregular / other |
| Period meaning | Point-in-time / period total / period average / cumulative-to-date / other |
| Normalized `period_start` rule |  |
| Normalized `period_end` rule |  |
| Time zone, if applicable |  |
| Fiscal/calendar convention |  |
| Partial-period treatment |  |
| Duplicate-period rule |  |
| Evidence |  |
| Reviewer / date |  |

Confirm:

- Original period labels are retained separately from normalized dates.
- Monthly, quarterly and annual labels are not assigned arbitrary point dates without documentation.
- Daily series preserve nonbusiness-day meaning and do not invent missing dates.
- Cumulative-to-date observations are not mislabeled as period flows.
- End-of-period and period-average stocks remain distinguishable.
- Frequency is not inferred solely from the number of observations.
- Gaps are reported, not automatically interpolated.

---

## 9. Units, scale, currency and value representation

Complete once per semantically uniform series family.

| Field | Answer |
|---|---|
| Source ID / sheet / series IDs |  |
| Exact original unit text |  |
| Approved `unit_code` |  |
| Exact original scale text |  |
| Approved `scale_multiplier` |  |
| Currency |  |
| Currency direction for exchange rates |  |
| Index base/reference period |  |
| Nominal/real/not applicable/unresolved |  |
| Price base year, if real |  |
| Percentage versus percentage-point meaning |  |
| Original value retained? |  |
| Base-unit value formula |  |
| Evidence |  |
| Reviewer / date |  |

Required checks:

1. Does multiplying by `scale_multiplier` produce the declared base unit?
2. Are percent values stored as publisher-displayed percentages or decimal fractions? Is this
   explicit?
3. Are index values distinguished from percent changes and contributions?
4. Are local-currency, USD and other currency series distinguished?
5. Are currency-per-foreign-unit and foreign-unit-per-currency rates distinguished?
6. Can null currency mean both “not applicable” and “unknown”? If so, add a status field.
7. Are revisions to unit or base period treated as metadata changes or identity/methodology breaks?

Do not convert source observations destructively. If normalized base-unit values are offered, retain
the original value, unit and scale beside the normalized representation.

---

## 10. Grain, dimensions, panels and curves

A scalar time series is not the only possible source shape. A table may describe entities,
instruments, sectors, counterparties, maturities, currencies, regions or other dimensions.

### Grain declaration

```text
Decision ID:
Source ID / sheet / region:
Plain-language grain:
Exact candidate key:
Time dimension:
Entity/dimension fields:
Which dimensions are encoded in series_id:
Expected uniqueness rule:
Expected panel balance, if any:
Legitimate duplicate-looking rows:
Aggregation represented in the source:
Status / evidence / reviewer / date:
```

Answer:

1. What does one source observation represent?
2. Can two rows share the same label and date because another dimension differs?
3. Are totals and components separate source series?
4. Are maturity buckets, tenors or curve nodes ordered categories rather than independent labels?
5. Are missing entity-period combinations true missingness, non-applicability or absent reporting?
6. Could any parser reshape create a many-to-many join or collapse a dimension?
7. Is a panel deliberately unbalanced? If so, is that visible to users?
8. Can the public observation interface reconstruct all source dimensions through `series_id` and
   catalogue/path fields?

---

## 11. Hierarchies, totals and source identities

Hierarchies help discovery and validation but must be evidence-based. Do not infer a parent merely
from indentation or similar wording without checking the source layout and notes.

| Series ID | Role: total/component/standalone | Parent series ID | Identity formula | Coverage/weight rule | Tolerance | Evidence | Reviewer/date |
|---|---|---|---|---|---|---|---|
|  |  |  |  |  |  |  |  |

Confirm whether:

- Totals include all displayed components or also undisplayed residuals.
- Components are mutually exclusive.
- Percent shares use the displayed total as denominator.
- Chain-linked or index aggregates are not tested by simple addition.
- Currency conversions or rounding explain tolerable discrepancies.
- The identity is valid for the entire history or only a dated regime.

An unresolved hierarchy should remain unresolved; it does not by itself justify deleting the
underlying source series.

---

## 12. Missingness, revisions, projections and discontinuities

### 12.1 Missing-value semantics

For each nonnumeric token, record:

| Source scope | Token | Meaning | Store as | Status/flag | Evidence | Reviewer/date |
|---|---|---|---|---|---|---|
|  |  |  |  |  |  |  |

Never coerce “not applicable,” “confidential,” “negligible,” “not yet published” and parse failure
to an indistinguishable missing value without retaining the distinction.

### 12.2 Observation status

Approve a controlled vocabulary and mapping for at least:

- realized/final;
- preliminary;
- revised;
- projection/forecast;
- estimated by publisher;
- suppressed/confidential;
- deleted/retracted;
- unresolved.

```text
Approved observation-status vocabulary:
Source markers mapped to each status:
Precedence when markers conflict:
Treatment in latest-only view:
Treatment in all-vintage view:
Reviewer / date:
```

Projections may belong in the source bank because they are publisher data, but they must never be
indistinguishable from realized observations.

### 12.3 Revisions and vintages

Answer:

1. What constitutes a distinct `vintage_id`?
2. Can more than one file belong to the same release?
3. How are replacement/corrected files represented?
4. Does latest-only mean latest release, latest non-deleted value or latest available-at timestamp?
5. Are publication date and `available_at` based on source evidence or inference?
6. Can users reproduce the information set available on a past date?
7. Are unchanged repeated values retained in vintage history or deduplicated with lineage?

### 12.4 Methodology and classification breaks

| Scope | Effective date | Change type | Same source series? | Comparable? | New regime/ID needed? | Evidence | Reviewer/date |
|---|---|---|---|---|---|---|---|
|  |  |  |  |  |  |  |  |

The bank should expose breaks and regimes. It must not automatically splice them for research use.

---

## 13. Optional reviewed economic layer

The following work improves search and cross-source use but is not a condition for exposing a
correctly represented source series. Its incompleteness must be visible.

Existing review/configuration structures include `series_review.csv`, `canonical_series.csv`,
`canonical_series_members.csv`, `methodology_regimes.csv`, `continuity_decisions.csv`,
`classification_concordance.csv` and `aggregate_identities.csv`.

### 13.1 Series semantic review

Where evidence is available, review:

- definition and official evidence;
- reference-period convention and timing basis;
- stock or flow;
- unit, scale and currency;
- valuation;
- nominal or real status and base year;
- seasonal-adjustment status;
- level, index, growth rate, contribution or ratio;
- hierarchy role;
- methodology regime and comparability;
- availability convention.

Use the controlled vocabularies already enforced by project configuration. Do not invent synonyms
in review files.

### 13.2 Canonical relationships

Canonical concepts may group aliases, alternative frequencies, components or predecessors, but the
original source series must remain accessible. Every relationship needs evidence and review.

```text
Canonical decision ID:
Canonical series ID / concept ID:
Member source series IDs:
Relationship for each member:
Definition and evidence:
Frequency/unit compatibility:
Methodology regimes:
Continuity or overlap rule:
Does this alter source-bank values? Must be NO unless separately approved.
Reviewer / date:
```

No canonical mapping, splice, deflation, seasonal adjustment or aggregation should be presented as
the publisher's original series unless it actually is.

---

## 14. Catalogue and extraction acceptance tests

The senior engineer must convert each item below into an executable, read-only release check. The
economist approves expected source meaning and documented exceptions; the coder does not choose
tolerances or exclusions.

### 14.1 Completeness and lineage

- [ ] Every registered source file has one declared coverage status.
- [ ] Every expected worksheet/region is admitted or explicitly excluded with evidence.
- [ ] Every admitted observation joins exactly one source file/vintage record.
- [ ] Every admitted observation joins exactly one series-catalogue record.
- [ ] Every catalogue series has at least one admitted observation, or a documented reason for a
      zero-observation placeholder.
- [ ] Source filename, sheet and table title are queryable for every series.
- [ ] Internal cell/region provenance can trace sampled values back to their source location.
- [ ] Re-running inventory reports does not depend on undocumented local paths or manual state.

### 14.2 Keys and grain

- [ ] `series_id` is non-null and unique in the series catalogue.
- [ ] The observation-history candidate key is declared and unique.
- [ ] Latest-only observations contain at most one row per `series_id` and normalized period.
- [ ] Duplicate labels are retained when paths/dimensions differ.
- [ ] No join used to build the public interface creates unexplained row multiplication.
- [ ] Panel, curve and other non-scalar source grains pass source-specific uniqueness checks.

### 14.3 Period and coverage

- [ ] `original_period`, `period_start` and `period_end` follow the approved mapping.
- [ ] Catalogue `first_period`, `last_period` and `observation_count` reconcile to the documented
      latest/all-vintage rule.
- [ ] Frequency codes agree with source semantics and normalized spacing.
- [ ] Gaps, overlaps and duplicate periods are reported by series and classified.
- [ ] Partial periods and cumulative-to-date observations are flagged correctly.

### 14.4 Values and semantics

- [ ] Parsed values reconcile to source cells for a risk-based sample and all known edge cases.
- [ ] Negative signs, parentheses, decimals and thousands separators are parsed correctly.
- [ ] Missing tokens retain their approved meanings/statuses.
- [ ] Unit, scale, currency and base-unit calculations pass approved checks.
- [ ] Projections, preliminary data, revisions and deletions remain distinguishable.
- [ ] Source totals and components reconcile only where an approved identity applies.
- [ ] No interpolation, splicing, deflation or seasonal adjustment contaminates the source-faithful
      value column.

### 14.5 User-facing extraction

- [ ] A researcher can search labels and full paths without knowing IDs in advance.
- [ ] A researcher can list every series from a source file, sheet or table.
- [ ] A researcher can extract any selected series for any valid date range.
- [ ] A researcher can choose latest-only or all-vintage observations explicitly.
- [ ] Output includes enough metadata to interpret frequency, unit, scale and currency.
- [ ] Warnings and unresolved statuses survive export.
- [ ] A documented example demonstrates discovery first and extraction second without prescribing
      an econometric model.

### 14.6 Release reconciliation summary

```text
Registered source files:
Complete / partial / quarantined / no-data / duplicate files:
Expected worksheets/regions:
Admitted worksheets/regions:
Explicitly excluded worksheets/regions:
Catalogue series:
Latest observations:
All-vintage observations:
Orphan observations:
Duplicate catalogue IDs:
Duplicate observation keys:
Unresolved source ambiguities:
Unresolved unit/period/grain ambiguities:
Failed acceptance tests and approved exceptions:
Evidence report location:
Reviewed by / date:
```

---

## 15. Implementation tickets for a junior coder

The completed workbook is source authority, not executable specification by itself. A senior data
engineer should translate each approved decision into a ticket with an exact scope and tests.

### Ticket template

```text
Ticket ID and title:
Workbook decision IDs implemented:
Problem demonstrated by:
Files/functions/views allowed to change:
Files/data explicitly out of scope:
Input grain and schema:
Required output grain and schema:
Exact transformation or mapping:
Controlled vocabulary values:
Null/error behavior:
Backwards-compatibility consequence:
Does this change data values, IDs, structure, metadata, documentation or workflow?
Migration/rebuild requirement:
Unit tests:
Integration/reconciliation tests:
Expected row/key counts or how to derive them:
Performance constraint, if material:
Documentation update:
Reviewer:
Definition of done:
```

### Mandatory escalation rules

The junior coder must stop and escalate when:

- source evidence conflicts with the workbook decision;
- implementation would merge or split series not explicitly authorized;
- a new missing token, period format, unit, scale or dimension appears;
- a join changes row counts unexpectedly;
- a source-layout change passes parsing but alters headers, regions or grain;
- a value must be guessed, imputed, interpolated or manually corrected;
- a public field cannot meet the agreed grain;
- a requested fix would overwrite source-faithful data;
- an acceptance test fails without an approved, documented exception.

Coding ability does not confer authority to make unresolved economic or source-semantic decisions.

---

## 16. Prioritized completion plan

### P0 — required before claiming the included source bank is complete

| Work item | Economist/source reviewer | Senior engineer | Junior coder | Exit criterion |
|---|---|---|---|---|
| Freeze the release scope | Approve included/excluded publications | Generate manifest and coverage report | Implement report if missing | Every registered file has a coverage status |
| Review every sheet/region | Identify data, metadata, notes and exclusions | Define region contracts and structural checks | Encode approved contracts | Every expected region is admitted or explained |
| Stabilize series identity | Approve label/path/grain distinctions | Specify deterministic ID/path rules | Implement and regression-test | Catalogue key unique and stable across rebuilds |
| Deliver two-object public contract | Approve meanings and warnings | Define views/schemas and grains | Implement views | All required minimal fields pass contract tests |
| Preserve original period | Approve source-to-normalized mapping | Define types/conventions | Implement mapping | Original and normalized periods both queryable |
| Resolve unsafe unit/scale/grain ambiguities | Supply evidence or quarantine decision | Identify affected rows and tests | Apply approved mapping/status | No unflagged material ambiguity in exposed data |
| Validate lineage and counts | Approve expected coverage/exceptions | Define reconciliation suite | Implement checks | No orphan facts; counts reconcile |
| Separate projections/revisions | Approve source markers | Define status/vintage semantics | Implement mappings/views | Status and vintage history are queryable |

### P1 — required for reliable general researcher use

| Work item | Reason and benefit | Dependency | Difficulty | Affects |
|---|---|---|---|---|
| Search documentation and examples | Users must discover series before selecting IDs | Public contract | Medium | Documentation/interface |
| Visible semantic status/warnings | Prevent unresolved fields being mistaken for reviewed facts | Review-status rules | Medium | Structure/documentation |
| Source-specific validation identities | Detect parsing and layout errors | Approved hierarchy evidence | Medium–High | Validation |
| Revision-aware extraction documentation | Prevent accidental full-information/look-ahead use | Vintage contract | Medium | Documentation/interface |
| Completeness dashboard/report | Make scope claims reproducible | Coverage inventory | Medium | Workflow |
| Risk-based source-cell reconciliation | Demonstrate source fidelity, especially edge formats | Cell provenance | Medium–High | Validation |

### P2 — progressive curation and maintainability

| Work item | Reason and benefit | Dependency | Difficulty | Affects |
|---|---|---|---|---|
| Complete reviewed semantic metadata | Better filtering and safer interpretation | Economist time/evidence | High | Metadata |
| Build canonical concept layer | Cross-publication discovery without erasing origins | Reviewed source series | High | Optional structure |
| Record methodology regimes/concordances | Make breaks and classification changes explicit | Official documentation | High | Metadata |
| Automate new-vintage layout drift checks | Safer updates | Stable source contracts | Medium | Workflow/testing |
| Add further BCP publications | Expand the bank honestly | Repeat full source onboarding | Variable | Data/scope |
| Add other Paraguayan publishers | Broaden national coverage | Publisher-specific provenance/contracts | High | Architecture/data |

### Optional downstream enhancements

- Research-specific transformed datasets or marts.
- Curated seasonal-adjusted, deflated or spliced variants clearly separated from source values.
- API or graphical catalogue browser.
- Subject taxonomies, synonyms and multilingual search.
- Real-time vintage cubes for projects that require publication-information sets.

These enhancements must not delay publication of a correct, traceable source bank unless they are
part of the declared release scope.

---

## 17. Final approvals

### 17.1 Source-bank release approval

```text
Release/build identifier:
Database/schema version:
Source manifest hash or immutable reference:
Catalogue contract version:
Coverage report reference:
Validation report reference:
All P0 acceptance tests pass: YES / NO
Open approved limitations:
Quarantined sources/regions/series:
Meaning of the public completeness claim:
Lead source economist approval / date:
Independent reviewer approval / date:
Senior data engineer approval / date:
Release approver / date:
```

### 17.2 Approved user statement

Complete and publish a statement in this form:

> This release exposes the legitimate series recovered from **[exact included source manifest]**.
> It preserves **[latest/all vintage policy]**, original source labels and provenance. The catalogue
> contains **[number]** series and the observation interfaces contain **[counts]** records. Known
> exclusions, quarantines and unresolved semantics are **[linked/listed]**. Availability in the bank
> does not imply that a series is appropriate for every empirical design; researchers remain
> responsible for research-specific selection, transformations, comparability and information-set
> choices.

Do not use “all data for Paraguay” without the manifest qualification. The honest claim is complete
coverage of the explicitly included and reviewed source universe.

---

## 18. Completion checklist

- [ ] Roles and approval authority are named.
- [ ] Release scope and completeness claim are explicit.
- [ ] Every registered source file/vintage has a reviewed coverage status.
- [ ] Every worksheet/region is admitted or explicitly excluded.
- [ ] The series catalogue and observation-history grains are separately defined.
- [ ] Every requested minimal catalogue field is present in the correct public object.
- [ ] `value` is included in the observation contract.
- [ ] `full_series_path`, `table_title` and `original_period` are preserved and exposed.
- [ ] Filename semantics distinguish series discovery from exact vintage provenance.
- [ ] Series identity and dimension/grain rules are approved.
- [ ] Period, unit, scale, currency and status conventions are approved or visibly unresolved.
- [ ] Projections, revisions and deletions are distinguishable.
- [ ] Catalogue and observation keys pass uniqueness tests.
- [ ] All facts have catalogue, source and vintage lineage.
- [ ] Coverage and source-value reconciliations pass or have approved exceptions.
- [ ] Search and arbitrary series/date-range extraction are documented and tested.
- [ ] Optional canonical metadata is separated from source-bank availability.
- [ ] Junior-coder tickets contain exact decisions, scope and acceptance tests.
- [ ] The final release statement identifies limitations without overstating coverage.

When these items are complete, the database can be released as a general-purpose source bank. A
future empirical project will still need its own variable-selection, transformation, sample and
econometric validation decisions; those are deliberately not precommitted here.
