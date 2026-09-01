# A canonical macro core — proposal for review

**Status: proposed. Nothing in this document has been loaded into the database, and nothing in it
is signed.** `canonical_series`, `map_canonical_series`, `methodology_regime` and `continuity_map`
are still empty, which is what the release reports.

The audit's P1 asks the project to "populate reviewed canonical mappings, methodology regimes and
continuity decisions for the macro core". The previous round declined, and the reason is in
`scripts/10_canonical.R`'s own header: a canonical series is an economic claim about what a measure
means, and seeding the register with plausible-looking guesses would put unreviewed economics behind
an interface that looks reviewed.

That reason still holds, so this round did not seed it either. What it did instead was remove the
three things that made the review expensive.

## What changed to make the review possible

**1. The candidates are now generated.** The real obstacle was never the decision, it was finding
what there was to decide between: 94 Annex worksheets, 14,423 series, labels in Spanish prose.
Every release now writes `outputs/canonical_core_candidates.csv` from live queries — for each macro
concept, every series whose published label could plausibly be it, with its worksheet, frequency,
unit, span and observation count. 108 candidates across 14 concepts in this release. A reviewer
picks from a menu instead of searching.

A row in that file asserts only that a label matched a pattern. That is exactly the kind of evidence
`docs/CONCEPT_GOVERNANCE.md` says is not sufficient on its own — which is why the file is an output
and not a register.

**2. `continuity_map` can now be written at all.** It had a table, a storage-layer assignment and a
release-gate presence check, and no writer anywhere in the project. A reviewer who had done the work
had nowhere to put it. `apply_continuity_decisions()` and `config/continuity_decisions.csv` now
exist, with the same guards as the other registers plus two closed vocabularies:

- `relationship` — `continues`, `replaces`, `splits_into`, `merges_into`
- `overlap_rule` — `direct_splice`, `ratio_splice_on_overlap`, `level_shift_on_overlap`,
  `no_splice_compare_only`

Both sides of a continuity decision must resolve through the migration map to exactly one live
series, for the same reason canonical membership must: a decision recorded against an identifier a
later repair split would otherwise silently widen to every successor.

**3. The guards refuse an unsigned register.** `documented_register_guard()` rejects
`reviewed_by = "unreviewed"`, so a draft cannot be loaded by accident. Filling the CSV in is a
deliberate act, and it is the act that constitutes the review.

## What the reviewer has to decide

These are the questions the candidate file surfaces but cannot answer. They are listed because they
are the actual work, and because several of them have more than one defensible answer.

### Which table, when the same series is published more than once

`PIB a precios de comprador` appears on **CUADRO 2**, **CUADRO 4b**, **CUADRO 6**, **CUADRO 6a**,
and on the `(Cont.)` continuation sheets of 6 and 6a. Annual on 2 and 4b (1991–2026, 36
observations); quarterly on 6 and 6a (1994Q1–2026Q1, 129). The pairs differ by valuation — current
versus constant prices — and the project has not recorded which is which, because the distinction
lives in the table titles and has not been reviewed. Deciding the canonical GDP series means
deciding that first.

The same shape recurs for `Formación bruta de capital fijo` (CUADRO 5, 7, 7a) and for the monetary
aggregates, where **Cuadro 21a** publishes M0–M3 monthly from 1962 and **CUADRO 21** publishes an
overlapping set from 1995 with a different decomposition (`M3 — e = (c+d)`, `BM — Base Monetaria`).

### Whether a concept exists in this catalogue at all

Two of the fifteen concepts return no candidate:

- **Nominal exchange rate.** `external_reserves_fx / nominal_exchange_rate` is one worksheet, and no
  series on it carries a label matching `tipo de cambio`. The exchange rate may be published under
  a label the pattern does not anticipate, or on the `exchange_rates` source rather than the Annex.
- **Net international reserves.** Two worksheets are classified `net_international_reserves` and no
  series label matches `reserva`.

Both need a look at the worksheets rather than a wider pattern. Widening the pattern until something
matches is how a canonical register acquires the wrong series.

### Whether the candidate is a level, a variation, or a contribution

The CPI candidates are all **CUADRO 15** and all three are variations, not the index:
`Inflación total — Variaciones (%) — Mensual`, `— Acumulada`, `— Interanual`. A canonical
"consumer prices" concept has to say which of those it is, or point at the index level on a
different worksheet.

### A label that is not a label

Two interest-rate candidates on **CUADRO 31** carry data in their labels:

```
Pasivas — A la vista — 12 — 14.08 — 11.3 — 11.2 — 11
Call — Interbancario — s/m — 30.1 — 34.2 — 18.636666
```

The values have leaked into the identity path. Both series parse, reconcile and hold correct
observations — the reconciliation for CUADRO 31 balances — but the label is not usable and the
identity built from it is not stable. This was found while assembling the candidate list and is
**not repaired in this round**: it is a parser defect that reconciliation cannot see, because every
cell is read and accounted for; only the label is wrong. It should be fixed before CUADRO 31 is
mapped to anything.

## What a signed row looks like

`config/canonical_series.csv`:

```
canonical_series_id,concept_id,definition,domain,subdomain,frequency,unit_code,currency,
stock_flow,nominal_real,seasonal_adjustment,transformation,valuation,methodology_regime_id,
reviewed_status,reviewed_by,reviewed_at
```

`reviewed_status` is one of `proposed`, `reviewed`, `retired`. `canonical_series_id` must not
collide with a parsed `series_id` — the identifier is assigned by the reviewer so that a future
parser repair cannot move it.

`config/canonical_series_members.csv` then attaches source series to it, with `relationship` in
`primary`, `component`, `alternative_frequency`, `spliced_predecessor`, and evidence per row.

Run `source("run_update.R")` after editing. The guards will reject an incomplete row, an unknown
series, an identifier that does not resolve one-to-one, and any row still marked `unreviewed`.

## What remains true regardless

Populating this register does not make a series validated. Promotion to `validated` is a separate
claim, made in `config/table_status.csv`, about definitions, units, period conventions, hierarchy
and methodology, and it requires a named economist and an evidence URI enforced by a database
`CHECK`. The canonical layer says *which series mean the same thing*; validation says *that the
series has been checked*. The database currently asserts neither, and says so.
