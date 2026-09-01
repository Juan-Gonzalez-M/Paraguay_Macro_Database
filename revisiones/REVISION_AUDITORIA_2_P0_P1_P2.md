# Response to the second technical audit — P0, P1 and P2

Audit: `Technical_Audit.docx`, comparative edition, 29 August 2026, read-only against
`paraguay_macro_pilot.duckdb` at schema 14.
Work delivered: schema 15 through 21.
Scope agreed with the project owner: the §12 roadmap items P0, P1 and P2. P3 was not in scope.

Four scope decisions were taken with the owner before any code changed, and they are what
this document is accountable to:

1. P0-1 goes to full depth — classify every unexplained cell **and** repair the parser
   defects that classification exposes, accepting the migration and identifier churn.
2. Measurement semantics are **derived with evidence, never reviewed**: a field is filled in
   only where the publisher states the answer in words, and the wording is recorded.
3. P1-4 (a second real release) is **blocked**: `input_archive/` holds one vintage per source
   and no newer BCP publication exists.
4. P2 takes the invasive options: a full physical schema move and BIGINT surrogate keys.

---

## 1. Was the criticism valid?

Yes. Every figure in the audit that could be checked was re-verified read-only against the
production database **before any code changed**, and all of them matched.

| Audit claim | Verified |
|---|---|
| 47/242 reconciliation rows unexplained; 18,883 unmapped in-region cells | exact |
| `canonical_series` / `map_canonical_series` / `continuity_map` / `methodology_regime` all empty | exact (0/0/0/0) |
| `v_research_series` = 0 while seven `v_mart_*` views hold 3,078–418,339 rows | exact |
| Tautological mart join | exact — a literal `d.source_sheet = d.source_sheet` |
| Reconciliation join omits release/vintage | exact |
| 36 prior identifiers with one-to-many resolution, no fail-closed resolver | exact |
| Eight stale Annex `table_status` notes | exact |
| All `stock_flow` and `seasonal_adjustment` `not_reviewed`; 3,946 unresolved units | exact |
| 2,112 positional-lane identities, 1,636 in `financial_indicators` | exact |
| All 22 durable source paths absolute `/Users/...` | exact |
| Runbook names v12 in one section and v11 in another; recovery stops at schema 11 | exact |

### 1.1 Two things the audit got directionally right and mechanically wrong

Neither changes the verdict; both change what the fix is, so they are recorded here rather
than quietly worked around.

**The 18,883 unexplained cells were mostly a defect in the measurement, not in the data.**
`report_cell_values` stores each worksheet cropped to its used range and numbers it from 1;
the parsers work on the uncropped sheet and record A1 coordinates. On a worksheet whose
content starts at A1 the two agree, which is why nobody noticed. On one starting at B2 every
coordinate is off by one and the join between the layers matches the wrong cells in both
directions. Translating the raw side into A1 — the whole of the fix — took the residual from
**18,883 across 47 worksheets to 5,842 across 22** before a single parser was touched. The
audit was right that the accounting did not close; the reason was that the accounting was
comparing two different coordinate systems.

**The `financial_indicators` lanes were not a modelling failure.** The audit read 1,636
positional-lane identities as layout-driven identity requiring a dimensional remodel. The
actual cause was one missing spelling: column 168 of sheet 3.2 is headed `SEPT-24`, the
period pattern knew `sep` and `set` but not the four-letter `sept`, and the axis fill-right
carried `AGO-24` across it. That **mis-dated 867 interest-rate and credit observations by a
month** and forked every affected row onto a lane. Recognising the spelling fixed both:
1,636 lanes to 0, with no value moved and no observation lost.

---

## 2. P0

### 2.1 Reconciliation is a hard gate, cell by cell

`config/reconciliation_exclusions.csv` carried a scalar count of cells someone had waved
through. It could not distinguish "these forty cells are the published annual subtotal" from
"forty observations went missing and nobody noticed", and on two worksheets the answer was
the second.

Replaced by `config/reconciliation_cell_rules.csv`: coordinate rectangles mapped to a
classification (`header_or_label`, `subtotal_or_formula`, `report_layout_derived`,
`out_of_scope_block`, `parser_defect`, `observation_expected`) with a reason, the worksheet
evidence quoted, a named reviewer and a date. Every unmapped cell resolves to exactly one
rule; `reconciliation_cell_classification` records which rule explained which cell, so the
total can be audited rather than trusted.

Layout claims may be signed `layout_verified` instead of by a person, because every one of
them is checkable by opening the workbook at the coordinates the rule names — but only if
the evidence quotes what is actually there, which the guard enforces. Economic claims still
require a named economist, everywhere they always did.

A cell matching no rule is now an **error-severity flag that blocks the release**, which is
the audit's central complaint: a numeric cell nobody has accounted for is not a warning to
read later. A `parser_defect` rule keeps its worksheet out of `v_research_series` and out of
every mart.

**Result: 0 unclassified cells across all 242 worksheets.** 237 balance; 5 carry 697 cells of
named, documented, still-unread published data and cannot be validated until repaired.

### 2.2 Parser repairs the classification exposed

Five defect families, all of them silently losing or corrupting published data:

| Defect | Cost | Repair |
|---|---|---|
| Footnote-marked month labels (`Ene**`, `Set*`) | CUADRO 59 lost 480 external-debt observations, CUADRO 55 lost 229 | The month axis strips the marker and keeps it in `footnote_marker`, as the year axis has since the CUADRO 57a repair |
| Late-starting data columns | CUADRO 17 lost four real-exchange-rate partner indices, SIPAP_04 lost ten payment-band columns | A column is admitted by shape — an unbroken run to the end of the data, with a published header — not only by density |
| `mar.-19`, `sept-25`, `dic- 19*` | CUADRO 56a/56b, 18, 23, 23a, 26, 35 dropped whole rows; `financial_indicators` mis-dated 867 observations | The month-year pattern accepts the abbreviation with a full stop, the four-letter September, and a space inside the separator |
| Text day-month-year (`30-nov.-20`) | bcp_fx_daily 2020 lost 108 FX-intervention observations | A day-month-year label resolves to that day |
| Comparison-block columns | already fixed at schema 14 | Classified as `report_layout_derived` so the accounting closes |

**4,338 observations recovered** (economic_annex +4,180, bcp_fx_daily +108, payments +50),
none invented: every one sits on a source cell that holds its value, which
`test-audit-p0-remediation.R` now asserts end to end.

### 2.3 Marts, joins and the research boundary

- `d.source_sheet = d.source_sheet` reads as a join key and constrains nothing. Sheet
  identity now comes from the observation: `v_series_observations` carries `source_sheet`
  per row, joined one-to-one on the snapshot's declared natural key.
- The reconciliation join carries `vintage_id`. `table_reconciliation` is keyed by
  `(vintage_id, source_sheet)` and rewritten per release; without it, a second vintage
  multiplies every row.
- Status joins apply exact-over-wildcard precedence instead of accepting either.
- `v_mart_<x>_all` keeps the data and the name that says what it is; `v_mart_<x>` carries
  only rows whose worksheet an economist validated and whose cells reconcile. All seven are
  empty today, which is the honest answer.
- `v_research_series` emitted one row per worksheet, so promoting `bcp_fx_daily` would have
  published its twelve series fourteen times each. It is now one row per series, validated
  only if **every** worksheet the series was assembled from is.
- New release-blocking tests: mart key uniqueness after all joins, and no unvalidated row in
  any research mart.

### 2.4 Governance drift

The eight stale notes are corrected. More usefully, each `table_status` row now states a
`parser_claim` in a closed vocabulary (`none`, `unread_cells`, `cell_reuse`) which
`validate_governance_drift()` checks against the reconciliation this release computed, in
both directions and at the scope the claim was written at. A row may not claim a defect that
is fixed, nor stay silent about one that is live. The prose is never pattern-matched — a
check that guesses at prose fires on notes that mention a defect they are denying.

A database `CHECK` on `table_status` now enforces reviewer, date and evidence for a
`validated` row, so the claim cannot be made by editing the table directly either.

### 2.5 Identity resolution fails closed

`v_series_id_resolution` gained `candidate_count` and `resolution_cardinality`.
`v_series_id_scalar_resolution` gives exactly one row per published identifier with a
`resolved_series_id` that is NULL unless the identifier still names precisely one series —
so a retired or split identifier drops out of a join instead of silently picking up a series
it never named. `resolve_series_id()` and `resolve_series_ids()` are the scalar and table
forms. Canonical membership refuses an ambiguous identifier outright.

The scalar macro's key column is deliberately named `lookup_id`: a DuckDB macro substitutes
the caller's argument expression into its body, so a macro comparing `published_series_id`
would become a tautology the moment someone called it with a bare column of that name and
would resolve every identifier to the same arbitrary series. That failure was reproduced and
is now covered by a test with literals.

**36 one-to-many and 15,096 retired identifiers all resolve to NULL; all 35,630 one-to-one
identifiers resolve.**

---

## 3. P1

### 3.1 Measurement semantics: derived with evidence, never reviewed

The previous position was that nothing could be derived, based on searching the 94 Annex
**titles**. That was true and the conclusion was wrong: the seasonal-adjustment status of the
IMAEP block is written on the series **labels** (`IMAEP — Serie Original`, `Servicios —
Tendencia Ciclo`), and the valuation basis of the trade tables is in their titles in the word
FOB. The evidence was there; the search was in the wrong column.

`series_semantic_evidence` records, per series and field, the value, the basis
(`published_label`, `published_unit`, `price_base_year`, or `reviewed`) and the exact wording
relied on. `v_series_measurement` publishes a `_basis` column beside every judgement field,
so a researcher can filter to reviewed only, derived only, or both, and read the sentence
behind each one. Nothing the pipeline writes claims review.

| Field | Series with a value | Basis |
|---|---|---|
| `stock_flow` | 774 | published title or label says *saldo* / *a fin de* / *flujo* |
| `valuation` | 638 | published title says FOB |
| `transformation` | 359 | published unit is an index |
| `nominal_real` | 37 | a price base year is published |
| `seasonal_adjustment` | 14 | label says *Serie Original* or *Tendencia Ciclo* |

The 3,946 unresolved units are unchanged and deliberately so: 3,083 are `lrm_auctions` and
632 `interbank_market`, event-grain sources whose unit varies by measure within the event and
is not stated anywhere the parser can reach. Guessing them is the error this whole layer
exists to prevent.

### 3.2 Detailed trade has explicit economic dimensions

`series_dimension` holds `trade_flow`, `trade_classification`, `trade_regime` and `product`
for the eight detailed trade worksheets — 3,574 values, all derived from the published table
title and row label with the wording recorded. Long-form rather than columns on `dim_series`,
because dimensions are source-specific by nature and columns per family would be null most of
the time. `v_series_dimensions` pivots them and the trade mart exposes them, so a researcher
who wants every import under the tourism regime filters a column instead of parsing Spanish
prose. The eight sheets moved from `needs_remodeling` to `provisional`.

`financial_indicators` needed no remodel — see §1.1. Its 1,636 lanes are gone.

### 3.3 What remains a lane

794 positional identities remain, the largest being `interbank_market / Mdo Secundario`
(409) and the 605 unread continuation-row cells on `Datos (+ de 1 día)`, where a trading day
with several operations is published as one dated row followed by unlabelled rows. Recovering
those requires deciding what the observation grain of a multi-operation day **is**, which is
an economic modelling decision rather than a parser repair. It is recorded as a
`parser_defect` with its evidence, it blocks validation, and it is not disguised as anything
else.

### 3.4 Compaction and the runbook

Compaction verified row counts, which a defect that moves a value between two rows, swaps two
columns or drops a column default passes untouched. It now compares **content**: every table
as a multiset in both directions with `EXCEPT ALL`, plus column definitions and defaults, view
SQL, constraints, indexes, sequences, macros and the schema version. The candidate is flushed
before the atomic rename and a failure leaves nothing behind.

`docs/SCHEMA_MIGRATIONS.md` is **generated** from `SCHEMA_MIGRATIONS` and the `schema_version`
table on every release, and the invalidation steps read the same declaration — so the runbook
cannot say v12 in one section and v11 in another again. `validate_database()` raises
`migration_runbook_stale` if the file falls behind. The wildcard-status and "grows 9 MiB per
run" wordings in `OPERATIONS.md` are corrected: a wildcard makes a new worksheet
*provisional*, not absent, and 9 MiB is peak allocation, not permanent growth.

Governance tables are rewritten only when their content actually changed, by fingerprint —
which is most of what a non-migrating run was allocating.

### 3.5 P1-4: blocked, and reported as blocked

No second publication exists. The machinery is proven end to end in
`test-audit-p1-p2-remediation.R` on a synthetic second vintage — a revised value, a withdrawn
series, the revision rows, the tombstone, and `series_as_of_date()` returning 100 before the
revision and 107 after — but **real revision history remains undemonstrated** and no claim to
the contrary is made anywhere in the database or the documentation.

---

## 4. P2

- **Storage layers.** All 80 tables moved into `raw` (32), `staging` (11), `canonical` (25)
  and `audit` (12); the research interface — sixteen views — is published under `marts`.
  Nothing is left in `main`. DuckDB has no `ALTER TABLE ... SET SCHEMA`, so each table is
  recreated from its declaration and refilled by name, which is what preserves the primary
  keys and the two CHECK constraints; a `CREATE TABLE AS SELECT` would have moved the rows
  and dropped every constraint on them. A search path set on every connection keeps every
  unqualified name in the project resolving, so the move is invisible to the SQL that does
  not care which layer an object is in.
- **Surrogate keys.** `fact_series_events` is keyed on `(series_sk, period, vintage_sk)`.
  The old key was two long text columns plus a date, about 99 bytes per row over 1.2 million
  rows — 114 MiB of index, more than the table it indexed. The human identifiers stay on
  every fact row and stay unique in the dimensions, so no query in the project changed, and
  three release-gate tests assert the surrogate and the identifier never diverge.
  **The compacted database is 243.3 MiB, down from 309.7 MiB at the audit, with 4,338 more
  observations in it.**
- **Portable paths.** `source_uri` and `archive_uri` are repository-relative on all 22 files;
  the absolute paths remain as run metadata, which is what they always were.
- **Coverage dashboard.** Extended rather than duplicated: 26 columns now reporting
  unclassified and unread cells, derived versus reviewed measurement fields, economic
  dimension values and ambiguous prior identifiers beside the coverage counts.

---

## 5. Where the database stands

| Measure | At the audit | Now |
|---|---|---|
| Schema | 14 | 21 |
| Series / observations | 15,191 / 1,209,313 | 14,339 / 1,213,651 |
| Unexplained in-region cells | 18,883 across 47 worksheets | **0** |
| Recorded unread cells | not measured | 697 across 5 worksheets, named and blocking |
| Positional-lane identities | 2,112 | 794 |
| Marts exposing unvalidated rows | 7 | 0 |
| One-to-many identifiers resolving to a series | 36 | 0 |
| Measurement fields with a value | 524 | 1,822, each with its evidence |
| Economic dimension values | 0 | 3,574 |
| Absolute durable paths | 22 | 0 |
| Compacted file | 309.7 MiB | 243.3 MiB |
| Validated research series | 0 | 0 |

The last row is the point. Nothing here promotes a single series to validated, and nothing
should: promotion is an economist's claim about definitions, units, period conventions,
hierarchy and methodology, and no amount of parser work substitutes for it. What this round
changed is that the boundary is now enforced rather than described — every source cell is
accounted for or blocks the release, every mart is empty until someone signs for it, every
derived value carries the sentence it came from, and every identifier the project has ever
published resolves or declines.

## 6. What remains open

- **P1-1**: `canonical_series`, `map_canonical_series`, `continuity_map` and
  `methodology_regime` remain empty. They require a named economist and published
  methodological evidence; the machinery, the guards and the review workflow are ready.
- **P1-2**: 3,946 units and the bulk of the judgement fields remain `not_reviewed` because
  the sources do not state them.
- **P1-3**: the interbank event grain (605 cells, 409 lanes) needs a modelling decision.
- **P1-4**: blocked until a newer BCP publication exists.
- **P3**: out of scope by agreement.
