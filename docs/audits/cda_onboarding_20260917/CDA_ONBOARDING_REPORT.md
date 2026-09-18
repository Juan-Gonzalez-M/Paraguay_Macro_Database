# CDA provisional onboarding evidence

Date: 2026-09-17

## Verdict

**PARTIALLY READY — UNRESOLVED CDA SUBSET WITHHELD**

The exact authorized CDA workbook is in a retained, isolated schema-46
candidate with zero release errors and no promotion. `catalog.*` retains all
reconciled CDA cells; only safe count-of-operations curve nodes reach
`explore.curve_observations`; `research.*` has zero CDA facts.

## Source, scope, and provenance

| Field | Evidence |
| --- | --- |
| Source/vintage | `cda_curve` / `cda_curve:8796a589fc2bd31317efdce7` |
| SHA-256 / bytes | `8796a589fc2bd31317efdce7865d4598473fdacd048cf04b676dc8f78e2b144c` / 4,505,245 |
| Current / immutable paths | `input/current/Curva_CDA.xlsx` / `input_archive/cda_curve/8796a589fc2bd31317efdce7865d4598473fdacd048cf04b676dc8f78e2b144c.xlsx` |
| Archive evidence | content maximum `2026-07-31`; archive-ingest upper bound `2026-09-14T21:02:26Z` |
| Scope / digest | `schema46_cda_provisional_20260917` / `7f94c1cc30fcf3b8eee15ae73a7ae2c426f7afd545ccc3c9bd8c8e896f19cf29` |
| Scope outcome | 23 exact hashes admitted; only exact TCN remains deferred |

Both paths hash to the stated SHA-256. The exhaustive, content-addressed scope
fails closed on a changed or future CDA hash, changed TCN hash, or unexpected
registered source. Schema-43 decisions remain untouched.

The candidate records only supported provenance: hash, paths, filename, content
maximum, parser contract, and archive-ingest upper bound. It does not assert an
official release date, URL, release identifier, actual retrieval timestamp,
licence, redistribution right, or publisher verification. The archive bound is
explicitly not a download/publication time; availability is
`inferred_upper_bound`. This leaves CDA unsuitable for real-time/as-of claims
and licence-assured redistribution.

## Meaning and representation

The registry documents CDA as *Curva de Certificados de Depósitos de Ahorro*
from Banco Central del Paraguay. The workbook explicitly labels monthly blocks
for `TASAS PONDERADAS DE DEPÓSITOS A PLAZO` and `DEPÓSITOS A PLAZO`, each for
`MONEDA LOCAL` and `MONEDA EXTRANJERA`. Rate sheets label `BANCOS` and
`FINANCIERAS`; operations sheets label `CANTIDAD DE OPERACIONES` and `VOLUMEN
CAPTADO`. One foreign-origin operations title adds `(EN GUARANÍES)`, retained
as publisher wording only.

There are 412 visible worksheets (206 rate, 206 operation/volume snapshots).
Every sheet has a workbook-explicit `Datos al dd/mm/yyyy` date; coverage is
2018-01-31 to 2026-07-31. Rows state labels such as `30 DÍAS`, `3600 DÍAS+`,
and `1 MES`, but no maturity date, residual maturity, issue/trade/auction date,
or standardized numeric tenor. These labels stay verbatim. The correct shape is
a monthly **curve-node panel**, not scalar series or worksheet fragments.

| Interpretation | Basis |
| --- | --- |
| weighted rates, counts, volume, institution class, origin wording, tenors | workbook-explicit |
| CDA expansion, BCP publisher, curve-panel grain, provisional assurance | repository-documented |
| one recurring monthly snapshot per sheet | strongly supported structural inference |
| percent/decimal; nominal/effective; compounding; curve fitting; full currency meaning; issuer coverage; timing meaning beyond `Datos al` | unresolved |

The workbook contains 263 formula-bearing cells and no hidden rows/columns.
Raw formula/cached state is retained; the parser uses the supplied cached numeric
result where present and never recomputes formulas.

## Identity, temporal, and unit contract

Identity is parser family (`CDA_RATE_CURVE` or `CDA_OPERATIONS_CURVE`), monthly
frequency, and source path: origin wording, measure, published institution
class, and exact maturity/tenor labels. Date is the observation key. Worksheet
name, cell coordinate, formatting, value, and workbook order are excluded. A
finalization regression that overwrote the family with the worksheet name was
repaired; a focused real-workbook test proves a node from two monthly sheets has
one identity. The CDA natural key `(series_id, period, vintage_id)` has zero
duplicates.

No rate conversion or value transformation occurs. Counts retain `COUNT`.
Rates retain `UNRESOLVED_SOURCE_UNITS`: `TASA` does not establish percent versus
decimal, annual/effective/nominal convention, or compounding. Volumes and
anomalous amounts retain source units and scale 1; they are not rescaled or
assigned currency. No interpolation, annualisation, aggregation, or conversion
is applied. Fourteen unlabelled-extra-column and one unlabelled-row observations
are explicitly positional and remain catalogued but withheld.

## Reconciliation and layer populations

| Item | Count |
| --- | ---: |
| Worksheets / raw nonempty cells | 412 / 49,813 |
| Numeric cells / accepted observations | 21,854 / 21,854 |
| Rejected / documented exclusion / balance delta | 0 / 0 / 0 |
| Cell reuse / unmapped / unclassified / parser defect | 0 / 0 / 0 / 0 |
| Canonical facts / identities | 21,854 / 471 |
| Catalogued | 471 identities / 21,854 facts |
| Explorable curve counts | 114 identities / 7,269 facts |
| Withheld | 357 identities / 14,585 facts |
| Research | 0 identities / 0 facts |

Every emitted fact maps to a cell. Blanks are not made into zero or a missing
observation; the `observed_only` contract remains in force. The reconciliation
contains no unexplained numeric data-bearing region.

The previous rejected artifact's 471 identities reproduce exactly: 228 rate
identities / 7,301 facts, 114 count identities / 7,269 facts, 114 volume
identities / 7,269 facts, and 15 explicit anomaly identities / 15 facts. This
is a reconciliation result, not a forced target. Rate, volume, and anomalous
nodes are withheld for unit/scale or positional-identity reasons. All candidate
warnings (provenance, availability, frequency, hierarchy, semantic review, and
unit limitations) remain query-visible.

## Candidate and invariance

| Field | Value |
| --- | --- |
| Candidate | `database/candidates/accepted_for_review_20260917_212826.duckdb` |
| Candidate SHA-256 / bytes | `11727959edd135bb211dd267dedd0d7c569dea3e473510ee72b6ef8cb1155876` / 468,725,760 |
| Schema / build / attempt | 46 / `build:180fb40bb51fadff89f9509f` / `attempt:a35046bd8c9f23aece17d28f` |
| Source bundle | `release:b4fa3c04186b336a91e9be7b` |
| Candidate errors / warnings | 0 / 39 |
| Candidate facts / identities | 1,248,919 / 12,313 |
| Production SHA before and after | `eaba62ab6efbc3c81a59dd77493282d5a3f28290319ec487f0876eb3b318c553` |

Bidirectional `EXCEPT ALL` comparisons of non-CDA facts and identities against
production both returned zero. LRM is unchanged at 10,334 facts and 940
identities. A fresh default read-only connection bound all 141 declared public
views. TCN is not a candidate release source. Production was never opened for
writing.

The candidate carries the explicit dirty-development warning because the active
production database, checksum, and promotion records were already user-owned
uncommitted changes. This did not suppress a CDA gate; release errors are zero.

## Verification and next action

Focused tests passed: `test-cda-curve-parser.R`,
`test-cda-provisional-scope.R`, `test-release-input-scope.R`, and the real
`test-full-pipeline-smoke.R`. The final full
`testthat::test_dir("tests/testthat")` suite passed. Its only test warning is
intentional: the corrupt-ZIP ingestion-isolation fixture.

- [x] source scope, identity, reconciliation, catalogue/explore/research split, public views, invariance, and production hash verified
- [ ] obtain official release/acquisition/licence and rate/volume methodology evidence
- [ ] independently review the retained candidate

Do **not** promote in this session. The exact next authorized action is an
independent review of this package and the hash-pinned retained candidate,
followed only by an explicit user decision to promote or leave it unpromoted.
Separate source-owner evidence is required before admitting withheld nodes or
any CDA observation to `research.*`.
