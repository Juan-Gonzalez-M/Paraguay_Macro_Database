# CDA provisional onboarding representation plan

Date: 2026-09-17
Scope: exact `cda_curve:8796a589fc2bd31317efdce7` only; no promotion

## Evidence checked before implementation

`input/current/Curva_CDA.xlsx` and its immutable archive copy both hash to
`8796a589fc2bd31317efdce7865d4598473fdacd048cf04b676dc8f78e2b144c`
and are 4,505,245 bytes.  The archive manifest records `2026-07-31` as a
content maximum and `2026-09-14T21:02:26Z` as the archive-ingest upper bound;
neither is an asserted publisher release or retrieval time.

The workbook has 412 visible monthly snapshots.  Its titles explicitly split
local- and foreign-currency-origin presentation, weighted deposit rates, and
deposit operation/count/volume panels.  Each sheet supplies a `Datos al
dd/mm/yyyy` observation date and published maturity labels such as `30 DÍAS`
and `1 MES`.  The rejected schema-43 artifact retained 21,854 facts in 471
candidate identities: 228 rate-curve and 243 operations-curve candidates.

## Chosen representation

Treat CDA as an observed monthly **curve panel**, not a collection of
worksheet time series.  Stable identity is the parser-family (`rate` or
`operations`), source frequency, and the publisher's full label path:
currency-origin wording, measure, institution class when published, and the
published maturity/tenor labels.  Worksheet name, source coordinate, snapshot
date, value, and workbook order are not identity material.  The source date is
the valuation/observation date; no issue, trade, auction, maturity date, or
standardized numeric tenor is asserted because the workbook does not supply
one.

The row labels are retained verbatim as tenor/maturity-bucket text.  No
calendar maturity, residual tenor, compounding, effective/nominal conversion,
interpolation, rate annualisation, or volume scaling is derived.

## Bounded access decision

* `catalog.*`: retain all recognized observations and candidates, including
  unresolved publisher cells, with lineage and warnings.
* `explore.curve_observations`: admit only count-of-operations nodes with a
  published institution class, a numeric value, a date, a semantic natural
  key, and reconciled cell lineage.
* Rate nodes are catalogued but withheld: `TASA PONDERADA` is explicit, but
  the workbook inspected does not explicitly state percent/decimal, annual or
  other rate convention, nominal/effective treatment, or compounding.
* Volume and anomalous amount nodes are catalogued but withheld: their numeric
  values are preserved exactly, but scale is not established.  `MONEDA
  EXTRANJERA (EN GUARANÍES)` is retained as publisher wording rather than
  generalized to all panels.
* Blank-header and unlabeled-row subsets remain catalogued with explicit
  coordinate-dependent identity warnings and are withheld.
* No CDA observation is eligible for `research.*`; the existing research gate
  remains unchanged.

## Scope and provenance decision

Create a new exhaustive schema-46 scope that admits this exact hash and
continues to defer the exact TCN hash.  It is a one-candidate decision, not a
rule for future CDA bytes.  CDA provenance records only the archive-ingest
upper bound using the repository's existing explicitly-qualified policy;
official release date, URL, release identifier, actual retrieval timestamp,
licence, and publisher verification remain unresolved.  This does not claim
that archive time is an acquisition time and does not change the research
provenance gate.
