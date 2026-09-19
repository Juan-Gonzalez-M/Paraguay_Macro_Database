# CDA semantic expansion review

Date: 2026-09-19
Production was not changed.

## Candidate

- Path: `database/candidates/accepted_for_review_20260919_094613.duckdb`
- SHA-256: `49c79f20a43db6194667dfafec2f12923b50a015470e811ebc129ce3e29ae1bb`
- Build: `build:33e0b5ab5e893910793a7b8e`
- Attempt: `attempt:ff465a8a456b2190351418b0`
- Source bundle: `release:b4fa3c04186b336a91e9be7b`
- CDA vintage: `cda_curve:8796a589fc2bd31317efdce7`
- Decision: accepted, retained for independent review; 0 errors and 42 warnings

## Verified result

- CDA contains 456 identities and 21,839 observations.
- Rates: 228 identities, `PERCENT_PER_ANNUM`, nominal, published values unchanged.
- Counts: 114 identities, `COUNT`.
- Volumes: 114 identities, whole currency units (`PYG` for ML and `USD` for ME), scale 1.
- Currency-origin mapping agrees for all 456 identities.
- The exploratory curve interface admits 421 semantic identities and 21,804 observations.
- The 35 identities and 35 observations from the two missing institution headings in
  `CDA_ML_102021` remain catalog-only and explicitly withheld.
- The 14 `Monto Capital Original` cells and the one unlabeled row-40 cell remain in raw
  evidence and are excluded from observations. Reconciliation accounts for all 21,854
  numeric source cells as 21,839 observations plus 15 governed out-of-region cells.
- Reconciliation has zero balance delta, reuse, unmapped in-region cells, unclassified
  cells, and parser defects.
- The production-to-candidate migration records 456 identical CDA identifiers and 15
  explicit retirements.
- Bidirectional fact comparisons for every non-CDA source return zero differences.
- LRM remains at 940 identities and 10,334 facts.
- CDA remains absent from `research.*`.
- All 141 public views open from a fresh read-only connection.
- CDA provenance remains visibly incomplete: availability is an inferred upper bound,
  official release date is null, and license is null.

## Tests

- Focused CDA parser, scope, semantic/ingestion, public-interface and exploratory-layer
  tests passed.
- The full suite was run against the retained candidate. After replacing the historical
  CDA count/admission expectations with the reviewed contract, the affected real-workbook
  full-pipeline smoke test passed.
- The only remaining full-suite failure is the strict environment test: six directly
  loaded installed packages differ from `renv.lock`. Package installation was prohibited,
  so the candidate records `environment_drift_overridden` as a warning. Five additional
  transitive differences are recorded in `audit.build_environment`.

## Publication state

The candidate was not promoted. Production remains SHA-256
`11727959edd135bb211dd267dedd0d7c569dea3e473510ee72b6ef8cb1155876`.
The prior authorization named a different exact candidate and therefore does not authorize
promotion of this semantic-expansion product.
