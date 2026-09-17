# LRM representation plan

Status: implementation plan recorded before executable changes on 2026-09-17.

## Evidence boundary

The immutable workbook is `input/current/lrm_auctions/Subasta de LRM_WEB.xlsx`, SHA-256
`b7e160f57d37a215d182eaeffea7d18a4e99151ebbde1efd9aa320d08ba71a37`. It contains fourteen
worksheets, `Subastas 2013` through `Subastas 2026` (including the publisher's trailing space in
`Subastas 2015 `). Direct XML-aware inventory found the same two-row header contract on every
sheet at rows 13--14 and the same merged groups across A:P. Rows 11--12 are hidden on sheets
2020--2026; no columns are hidden. Formula cells and cached values are present and remain raw
evidence; the semantic parser reads the cached published values and retains exact A1 coordinates.

The explicit fields are:

| Columns | Meaning | Evidence status |
|---|---|---|
| A:C | auction, settlement, and maturity dates | explicit in workbook |
| D:E | standardized and residual tenor | explicit in workbook; upper header says days |
| F:H | announced, offered, and assigned amounts | explicit in workbook; upper header says millions of guaranies |
| I:J | offered and assigned bid counts | explicit in workbook |
| K:M | offered average, minimum, and maximum interest rate | explicit side/statistic; rate unit unresolved |
| N:P | assigned average, minimum, and maximum interest rate | explicit side/statistic; rate unit unresolved |

No auction number, security code, instrument column, cutoff-rate field, counterparty count, subtotal,
or total is published in this workbook. The workbook and source registry establish that the table is
LRM auctions; they do not establish an additional instrument subtype.

## Representation decision

Represent the source at its native auction-tenor event grain. Do not derive aggregates or present
each annual sheet as a separate concept. Within the repository's sparse fact architecture, an
event-measure identity will be based on:

`auction date + settlement date + maturity date + standardized tenor + residual tenor + measure`

The annual worksheet remains lineage only. This is the narrowest key supported by published fields;
it distinguishes multiple same-date tenders and different maturities without using values, row or
column positions, formatting, or worksheet year. If this key collides, ingestion must stop rather
than manufacture an occurrence lane.

Measures use stable semantic names: `announced_amount`, `offered_amount`, `assigned_amount`,
`offered_bid_count`, `assigned_bid_count`, `offered_average_rate`, `offered_minimum_rate`,
`offered_maximum_rate`, `assigned_average_rate`, `assigned_minimum_rate`, and
`assigned_maximum_rate`. A public label will always carry the side and statistic.

## Units and admission

- Amounts retain publisher values with currency `PYG`, source unit `PYG`, and scale `millions`.
- Tenors are event dimensions measured in days, not separate facts.
- Bid counts use unit `count` and scale `units`.
- Rate statistics retain `source_units` / `UNRESOLVED_SOURCE_UNITS`; percent will not be inferred
  from plausible magnitudes.

Corrected amount and count event measures may enter `explore.events` with provisional assurance
after exact cell reconciliation and key checks. Rate measures remain catalog-only until an
authoritative rate-unit decision exists. Nothing enters `research.*` in this remediation.

## Reconciliation and migration

Every nonblank workbook cell will receive a structural classification. Every numeric data cell in
F:P must emit exactly once; A:E are event identity/dimension cells; rows 13--14 are headers; title,
notes, formulas, blanks, and presentation cells remain classified raw evidence. Any unexplained
data-bearing cell is a stop condition.

The existing coordinate-based migration machinery will map old identities to corrected identities
using source file, sheet, row, column, and period. A separate LRM ledger will enrich those mappings
with old/new labels, cardinality, before/after counts, ambiguity, preservation checks, access path,
and deprecation treatment. Coverage must include all 3,083 prior identifiers before acceptance.
