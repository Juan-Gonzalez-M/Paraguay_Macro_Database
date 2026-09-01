# Response to the third technical audit — P0, P1 and P2

Audit: `Technical_Audit.docx`, comparative edition, 29 August 2026, read-only against
`paraguay_macro_pilot.duckdb` at schema 21.
Work delivered: schema 22 and 23.
Scope agreed with the project owner: the §12 roadmap items P0, P1 and P2. P3 was not in scope.

Four scope decisions were taken with the owner before any code changed:

1. The canonical layer is **proposed, not signed** — the machinery and a generated candidate list,
   with nothing entering the register as reviewed.
2. Financial-indicator semantics get a measure dimension and a unit repair, with **labels and
   identifiers unchanged**, so this item causes no identifier churn.
3. A full rebuild is run and committed.
4. The irregular-interval period model was assumed rather than confirmed, and is described in §3.4
   so it can be overruled.

---

## 1. Was the criticism valid?

Yes. Every figure in the audit that could be checked was re-verified read-only against the
production database **before any code changed**, and all of them matched.

| Audit claim | Verified |
|---|---|
| 74 of 74 views fail from a fresh default connection | exact — 0 of 74 executed |
| `resolve_series_id`, `resolve_series_ids`, `series_as_of_date` all fail | exact |
| 32 raw / 11 staging / 25 canonical / 12 audit tables; 16 marts views | exact |
| 14,339 series / 1,213,651 facts | exact |
| 237 balanced, 5 `defects_recorded`, 697 parser-defect cells, 0 unclassified | exact |
| defect split 605 / 83 / 5 / 2+2 on the five named worksheets | exact |
| 4,025 subtotal + 697 parser_defect + 65 out-of-scope classifications | exact |
| canonical / methodology / continuity registers all empty | exact |
| identity stability 9,615 / 3,930 / 476 / 318 | exact |
| 29 provisional / 6 needs_remodeling; 0 validated | exact |
| `financial_indicators` note claims 1,636 positional lanes; live count 0 | exact |
| 464 duplicate-label groups covering 1,014 of 1,050 series | exact |
| 3,946 unresolved units; 527 stock / 247 flow / 13,565 not_reviewed | exact |
| 1 ingestion run, 0 revisions | exact |

### 1.1 One thing the audit got directionally right and mechanically wrong

**The 605 interbank cells are two defects, not one, and the larger one is not the one described.**

The audit reports all 605 unread cells on `Datos (+ de 1 día)` as continuation-row operations, and
prescribes an event-grain remodel. Measuring the parser's own output against the worksheet says
otherwise:

- **551 cells** are the entire **REPO Tripartito** block, columns 15–20 — a published instrument
  with a full two-row header that the parser never admitted as data at all. It is a thinly traded
  instrument: it trades on 95 of 3,653 days, which is 2.6% against a 5% density floor. Not a grain
  problem, not a late start, and not recoverable by any amount of event modelling.
- **54 cells** are the genuine continuation rows, on columns 21 and 25.

The reconciliation rule that recorded the 605 described only the second cause, and its rectangle
happened to cover both. The audit inherited that description. Both are repaired here, by different
means, and the rule's own evidence is what made the discrepancy findable.

---

## 2. P0

### 2.1 The published interface

The defect is exactly as reported and reproduces on demand. `scripts/05_query_helpers.R` — the file
`docs/CONCEPT_GOVERNANCE.md` tells a researcher to source — opens a plain connection and then
queries unqualified views, so all five of its functions failed. It was sourced by neither
`run_update.R` nor the test helper, which is why nothing caught it: every test reached a view
through `connect_project_database()` or `initialize_database()`, both of which set a search path as
a side effect.

Every stored object is now written through `create_project_view()` / `create_project_macro()`, which
qualify the body against the live catalogue. Three layers, because none of them can be trusted
alone:

| Layer | What it catches |
|---|---|
| `qualify_project_sql()` | writes the qualified name in the first place |
| `unqualified_object_dependency` | reads the stored SQL back out and rejects a bare reference — error-severity |
| `fresh_connection_object_failed` | opens a second connection with nothing set and executes every view and macro — error-severity |

**Result: 74 of 74 views and 3 of 3 macros execute from a default connection, against 0 of 74
before.** The same check runs in `compact_database.R` before the atomic swap and in
`prepare_distribution.R` before a copy is shipped.

`main`-resident views are qualified too, which is not cosmetic. A bare name binds against the
caller's catalogue, so `marts.v_mart_trade_all` reading `FROM v_series_observations` worked on a
direct connection and failed the moment the file was `ATTACH`ed under an alias — which is how a
researcher combines this database with their own, and how the compaction and migration tools
already read across releases. That case is now tested.

### 2.2 The same defect, three more times

The audit found one instance. Fixing it properly surfaced three more of the same shape — a name
resolved by assumption in a database whose objects had moved — and each was silently disabling
something:

**`initialize_database()` believed the database was empty.** Its bootstrap detector asked
`dbExistsTable("schema_version")` before setting a search path. Schema 21 moved that table into
`audit`, so on the pipeline's own connection the answer was FALSE, `fresh_bootstrap` came out TRUE,
and **every `if (!fresh_bootstrap) invalidate_...` step was skipped**. A migration that re-ingests a
source had been a no-op since schema 21. This is how the first attempt at this round's rebuild
reported success while re-reading nothing. The detector now reads `information_schema` across every
layer and the path is set first.

**`build_migration_map.R` could not run.** It passed the literal `"main"` as the current catalogue
to `attached_table()`, which filters `duckdb_tables()` by `database_name`. DuckDB names the primary
catalogue after the file — `paraguay_macro_pilot` — so the filter matched nothing. It now asks
`current_database()`.

**Views owned by a source were never rewritten.** One view per raw worksheet, ten documented
financial views and the FX-operations view are created as a side effect of ingesting their source,
so on a run where every vintage is reused they are never touched. Schema 22 qualified everything it
created and left eighteen of them bare. The lint caught it, which is what the lint is for;
`recreate_source_derived_views()` now rewrites them on every migration.

### 2.3 The research boundary and the recovered cells

The `_all` / validated split already existed and holds. What was missing was the proof, which is now
three assertions: no worksheet at anything other than `balanced` appears in any validated mart or in
`v_research_series`; every mart row is `validated` and `balanced`; and each strict mart is **exactly**
the qualifying subset of its `_all` counterpart — not fewer, which would be a join defect losing
rows, and not more, which would be a filter that does not filter.

`generate_audit_fixtures.R` cuts the golden fixtures by the audit's own method — a physical
source-cell comparison on `(source_id, source_sheet, source_row, source_column)`, which survives the
identifier churn a parser repair causes. Against the last database that predates the repairs:

- **5,034 recovered cells** — the audit's 4,338 plus this round's 696
- **1,089 period corrections** — exactly the audit's figure
- **zero cells that the baseline read and this release does not**

The test does not trust the database's account of them: it joins back to the raw cell layer in
worksheet coordinates and compares the value stored against the value in the cell.

One detail worth recording, because it made 64 of those rows silently unmatchable at first: three of
the publisher's worksheet names end in a space — `"CUADRO 17 "`, `"CUADRO 19 "`, `"Subastas 2015 "` —
and `readr::read_csv()` trims by default. A golden fixture that mangles its own key is not one, so
the fixtures are read with `trim_ws = FALSE` and a test asserts the untrimmed names survive.

`revisiones/RECOVERED_CELLS_SAMPLE_CHECK.md` is the economic sample-check the audit asks for. It is
generated and **unsigned**; reading it against the published headers is a reviewer's task.

---

## 3. P1

### 3.1 The 697 recorded parser defects: 696 repaired

| Defect | Cells | Repair |
|---|---|---|
| Interbank REPO Tripartito block | 551 | A column is admitted on the header the publisher printed for it, not on how busy it is |
| Interbank continuation operations | 54 | Event records: trade date inherited, positional operation sequence |
| Annex CUADRO 11 minimum-wage steps | 83 | Compound interval labels parse to an effective-dated period |
| Compensatory FX zero totals | 5 | The block's activity test now spans the same columns the reading loop consumes |
| Payments CCC 02 | 2 | Same header rule as the interbank block |
| Payments SIPAP_12 | 1 of 2 | See §3.2 |

**The density floor was the common cause of four of the five.** It was always a proxy for "did the
publisher mean this to be a column", and the publisher answers that directly by heading it. A
column inside the data block, holding a value, not a date column, and carrying a label on the header
rows the confident columns established, is a data column — whether it holds 551 values or one.

Catalogue-wide the reconciliation moves from **237 balanced / 5 defects_recorded / 697 unread** to
**241 balanced / 1 defects_recorded / 1 unread**, with zero unclassified cells and zero cell reuse
throughout. The release raises **no error-severity flag**.

### 3.2 The one cell not repaired, and why

SIPAP_12 column 18 holds the second half of a two-column block the publisher opened in the final
published month without printing its sub-header row. The column carries no header of its own; the
only thing that would admit it is a label inherited by filling right from its neighbour.

That is not decidable from the cells. **CUADRO 35 column 12 has the identical shape** — blank on
every header row, taking a neighbour's label when filled — and a reviewer has already classified it
`out_of_scope_block`: three isolated values in a column the publisher never headed. Only the
worksheet's merge ranges separate the two cases, and this parser reads cells.

Admitting column 18 would have overridden a human review to gain one cell. It stays a recorded
defect with an accurate reason, and SIPAP_12 stays `needs_remodeling`. The neighbouring column 17,
which does carry its own published header, is read.

For the same reason its label is the group name alone rather than the inherited `Importe Destino`:
that label would have described a count of 302,815 operations as an amount. Two columns sharing a
group name become positional identities, which is what the publisher's own labelling supports.

### 3.3 What the repairs did not do

`CUADRO 35` reads exactly what it read before — the reviewed out-of-scope classification is intact.
`Datos`, `bcp_fx_daily`, `credit_survey` and `CUADRO 61` are byte-identical by golden signature. The
migration map records **14,423 mappings, 84 new and zero retired**: no identifier the project has
published was lost.

### 3.4 Irregular sub-annual intervals — the assumed model

CUADRO 11 publishes the legal minimum wage in force over irregular within-year intervals
(`Enero/Junio`, `Mayo/Diciembre`) underneath the annual average. Two things blocked it: the compound
label resolved to no month, and two steps in one year would have collided on `(series_id, period)`.

The model used, **assumed rather than confirmed with the owner**:

- the steps are their own series, `frequency = 'irregular_interval'`, because they are a different
  measure from the annual row — 22,065 in 1980 is the average of 20,520 in force to June and 23,610
  from July, which the test asserts;
- `period` carries the interval's closing month, keeping the project's period-end convention;
- the opening date is stored for those 83 observations only, in `canonical.series_period_bounds`,
  which `v_series_observations` coalesces ahead of the frequency-derived bound.

The 1.2 million fact rows, the `(series_sk, period, vintage_sk)` key and the existing annual series
are untouched. **Say so if you want a different model** — storing bounds on every fact row, or
keeping the steps out of the fact table entirely, were the alternatives.

### 3.5 Financial-indicator semantics

The cause was not fragmentation. Sheets 4 and 7 publish **Saldos** — outstanding balances — while
every other sheet publishes **Tasas de interés**, over the same portfolio taxonomy. Both therefore
carry rows called `MN — Tasa Activa — Comercial — Total`, and nothing in the label, unit or metadata
said which was which.

Three changes, none touching a label or an identifier:

1. The eleven worksheets are declared in `config/table_domains.csv` with a `measure_family`, so they
   reach `v_series_domain` and the marts for the first time.
2. A `measure` dimension — `rate` / `outstanding_amount` — derived from the published table name
   through the existing evidence-bearing mechanism, with the wording recorded and the basis
   published. **847 rate and 188 outstanding_amount.** The pattern is anchored to the table name
   because the rate tables also end with *"Ponderación sobre saldos"*: they are weighted by
   balances, they do not report them.
3. Two unit-derivation bugs, both demonstrable:
   - every one of these worksheets carries a *"Volver al índice"* navigation link in its header
     block, and because the unit rule reads the title for the word `indice` it put `unit = index` on
     146 series, including sheet 8 whose entire title is that link;
   - a word in a row label outranked a unit the publisher stated in the title, so `Préstamo Personal`
     and `<= 90 días` were read as a headcount and a duration and put `count` on 311 published
     interest rates and `days` on 52 more.

   A unit stated in the title now wins, and a title that names the table's measure suppresses the
   label heuristics entirely.

**Rate-labelled financial indicators carrying a non-rate unit: 0, from 432.** Catalogue-wide the
audit's own predicate returns 1, from 457. A new release-blocking `semantic_contradiction` check
holds the line: a `rate` must carry a rate-compatible unit, an `outstanding_amount` a currency, a
`transaction_count` a count.

The 464 duplicate-label groups remain, by agreement — the labels are the publisher's. They are no
longer ambiguous, because the measure is a queryable column beside them.

### 3.6 Numbers written into prose

The stale note said *"1,636 positional-lane series"* for a source whose live count is zero.
`validate_governance_drift()` did not catch it and was right not to: it polices the closed-vocabulary
`parser_claim` and deliberately never pattern-matches prose, because a check that guesses at prose
fires on notes that mention a defect in order to deny it.

The new `governance_note_stale_count` keeps that principle and narrows the target. A *number*
followed by one of the phrases this project uses to make a quantitative claim — `N published source
cell(s)`, `N positional-lane series` — is not prose but an assertion with a live counterpart, and is
checked against it. Everything else in the note stays free text and stays unread. The note itself is
rewritten from live evidence, and `financial_indicators` moves to `provisional`.

### 3.7 Canonical layer — proposed, not signed

`canonical_series`, `map_canonical_series`, `methodology_regime` and `continuity_map` are **still
empty**, and the release says so. What changed is the cost of filling them; see
`revisiones/CANONICAL_CORE_PROPOSAL.md`.

- `outputs/canonical_core_candidates.csv` is generated from live queries every release: 108
  candidates across 14 macro concepts, each with worksheet, frequency, unit, span and observation
  count. A reviewer picks from a menu instead of searching 94 worksheets of Spanish prose.
- **`continuity_map` had no writer at all** — a table, a storage assignment and a release-gate
  presence check, and nowhere for a reviewer to put the work.
  `apply_continuity_decisions()` and `config/continuity_decisions.csv` now exist, with closed
  vocabularies for `relationship` and `overlap_rule` and both sides required to resolve one-to-one.
- The guards still reject `reviewed_by = "unreviewed"`, so a draft cannot load by accident.

The proposal also records what the reviewer must decide and what a candidate list cannot: which of
CUADRO 2 / 4b / 6 / 6a is the canonical GDP (they differ by valuation, which is not yet reviewed);
that the CPI candidates are all variations rather than the index; and that two concepts — the
nominal exchange rate and net international reserves — return **no** candidate and need a look at
the worksheets rather than a wider pattern.

It also records a defect found while assembling that list and **not repaired here**: two CUADRO 31
interest-rate series carry data in their labels (`Pasivas — A la vista — 12 — 14.08 — 11.3 …`). Every
cell is read and the worksheet balances, so reconciliation cannot see it; only the label is wrong.

### 3.8 P1-5: blocked, and reported as blocked

`input_archive/archive_manifest.csv` holds exactly one file per source for all 22 sources. There is
no second BCP publication, so revisions, `available_at` ordering and as-of extraction remain
demonstrable only on the synthetic vintage already covered. No claim to the contrary appears
anywhere.

---

## 4. P2

- **Documentation.** `docs/OPERATIONS.md` gains **Connecting to the database** (stating plainly that
  no `search_path` is required, and that needing one is a defect to report), **Where things live**,
  **Research marts and the `_all` split**, **Defect states, and what "balanced" covers**, and
  **Preparing a copy for distribution**. `docs/DATABASE_STORAGE.md` gains the storage-layer history
  and the reason comparison alone could not catch the schema-21 defect.
- **Generated rather than narrated.** `outputs/canonical_core_candidates.csv` and
  `outputs/source_region_completeness.csv` join the coverage dashboard as live-query outputs.
- **Distribution scrub.** `prepare_distribution.R` writes a copy with the 44 workstation-absolute
  path values blanked, verifies all 22 files keep their source URI, archive URI and hash, and
  executes every view in the copy before writing it. The live database is never modified.
- **Compaction.** Comparing contents could never have caught schema 21: all 74 broken views were
  copied, compared and compacted faithfully, because the stored SQL was identical and identically
  wrong. The candidate is now opened unconfigured and every view and macro executed before the swap.
  **337.5 MiB → 247.0 MiB, 81 tables, 4,781,317 rows, 77 published objects executed.**

### 4.1 What "balanced" does not cover — reported, not gated

The audit's §11 asks that every nonempty numeric source block be inside a reviewed parser region or
explicitly out of scope. Measuring it is uncomfortable: **73,830 published numeric cells across 150
worksheets sit outside the rectangle their parser consumed**, and every one of those worksheets
reads `balanced`, because `balanced` speaks only for cells inside that rectangle.

Most are period axes and row codes, which are not observations. Some are not — the interbank
`Datos (+ de 1 día)` worksheet publishes a Call Money Market block in columns 3–8 that no parser
region reaches, on a sheet that now balances.

This is reported as a warning with `outputs/source_region_completeness.csv`, not turned into a gate.
Gating it would require a reviewer to classify 73,830 cells first, and a gate nobody can pass is a
gate that gets switched off. Repairing those blocks was also outside the agreed scope, which was the
697 recorded defects.

---

## 5. Where the database stands

| Measure | At the audit | Now |
|---|---|---|
| Schema | 21 | 23 |
| Views executable from a default connection | **0 of 74** | **74 of 74** |
| Macros executable from a default connection | 0 of 3 | 3 of 3 |
| Recorded unread published cells | 697 across 5 worksheets | **1 across 1** |
| Worksheets balanced | 237 | 241 |
| Unclassified cells / cell reuse | 0 / 0 | 0 / 0 |
| Series / observations | 14,339 / 1,213,651 | 14,423 / 1,214,347 |
| Rate-labelled series with a non-rate unit | 457 | **1** |
| Financial-indicator series with a derived measure | 0 | 1,035 |
| Stale counts in status notes | 1 | 0 |
| Registry-driven migrations that actually run | 0 | all |
| Prior identifiers retired by this round | — | 0 |
| Canonical / methodology / continuity rows | 0 / 0 / 0 | 0 / 0 / 0 |
| Validated research series | 0 | **0** |
| Compacted file | 243.5 MiB | 247.0 MiB |

The last two rows are the point. Nothing here promotes a single series to validated and nothing
should: promotion is an economist's claim about definitions, units, period conventions, hierarchy
and methodology, and no amount of parser work substitutes for it. What this round changed is that
the interface a researcher actually opens now works, that the published cells this project knew it
was not reading are read, and that three more places where a name was resolved by assumption have
been found and closed.

## 6. What remains open

- **P1-4**: the canonical registers remain empty. The machinery, the guards, the missing
  `continuity_map` writer and a generated candidate list are what this round delivers; the review is
  the owner's.
- **P1-5**: blocked until a newer BCP publication exists.
- **SIPAP_12 column 18**: one published cell, undecidable without the worksheet's merge ranges.
- **Source-region completeness**: 73,830 cells outside every parser region, now measured and
  reported. The interbank Call Money block is the clearest candidate for the next repair.
- **CUADRO 31 labels**: two interest-rate series carry values in their identity path.
- **P3**: out of scope by agreement.
