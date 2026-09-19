# CDA bounded independent acceptance

Date: 2026-09-18
Verdict: **PASS — CDA PROMOVIDO**

## Authorized object and release identity

The independently reviewed object was exactly
`database/candidates/accepted_for_review_20260917_212826.duckdb`, SHA-256
`11727959edd135bb211dd267dedd0d7c569dea3e473510ee72b6ef8cb1155876`,
468,725,760 bytes. Its accepted active decision identifies schema 46, build
`build:180fb40bb51fadff89f9509f`, attempt
`attempt:a35046bd8c9f23aece17d28f`, source bundle
`release:b4fa3c04186b336a91e9be7b`, 23 sources, zero errors and 39 warnings.
The governed distribution-artifact row identifies the retained candidate path
and byte count. The candidate was not rebuilt or modified.

The exhaustive scope `schema46_cda_provisional_20260917`, digest
`7f94c1cc30fcf3b8eee15ae73a7ae2c426f7afd545ccc3c9bd8c8e896f19cf29`,
contains 23 exact-hash admits and one exact-hash deferral. CDA is admitted only
at SHA-256 `8796a589fc2bd31317efdce7865d4598473fdacd048cf04b676dc8f78e2b144c`;
both current and immutable archive copies match. TCN is the sole deferral, at
SHA-256 `74df666397a33b9c8cdfac10d7ffedd23acf7cbd5907ea21332e100fb939c0a4`,
and is absent from the release bundle. The fail-closed changed-CDA-hash test
passed.

## Representation, population and reconciliation

CDA is a monthly curve-node panel. All 471 identities use either
`CDA_RATE_CURVE|monthly|...` or `CDA_OPERATIONS_CURVE|monthly|...`; no identity
contains a worksheet token or A1 coordinate, and the natural key
`(series_id, period, vintage_id)` has zero duplicates. Dates, values, worksheet
names, coordinates and order are not identity material. Published tenor labels
remain text; no maturity date, numeric tenor, currency, rate convention,
transformation or financial interpretation was added.

The candidate contains 471 CDA identities and 21,854 CDA facts. Exactly 114
`COUNT` identities and 7,269 observations are available through
`explore.curve_observations`. The other 357 identities and 14,585 facts remain
withheld: 342 semantic rate/volume identities with 14,570 facts, and 15
positional/anomalous identities with 15 facts. Withheld values retain
`UNRESOLVED_SOURCE_UNITS`, scale multiplier 1, null currency and
`transformation = not_reviewed`. All CDA observation-bearing `research.*`
interfaces return zero rows.

The 412 worksheets reconcile 21,854 numeric cells to 21,854 accepted
observations and 21,854 distinct accepted cells. Rejected observations,
documented exclusions, balance delta, cell reuse, unmapped cells, unclassified
cells and parser defects are all zero. The retained raw evidence has 49,813
nonempty cells and 263 formula-bearing cells. No material omission or duplicate
natural key was found.

## Provenance and containment

CDA provenance exposes `archive_ingest_upper_bound` and
`availability_quality = inferred_upper_bound`. Official release date, official
URL, release identifier and licence are null. The evidence text explicitly
states that `2026-09-14T21:02:26Z` is an archive-ingest upper bound, not an
official publication or actual retrieval time, and that publisher verification
and redistribution rights remain unresolved. These limitations remain visible
and block research admission, real-time claims and licence-assured
redistribution.

## Invariance and tests

Bidirectional `EXCEPT ALL` comparisons returned zero differences for every
non-CDA canonical fact and identity. LRM is unchanged in candidate and former
production at 10,334 facts and 940 identities; all LRM observation-bearing
`research.*` interfaces return zero rows. All 141 declared public views bound
from a fresh default read-only candidate connection.

The independently executed focused tests all passed:

- `test-cda-curve-parser.R`
- `test-cda-provisional-scope.R`
- `test-release-input-scope.R`
- `test-public-interface.R`
- `test-release-isolation.R`
- `test-build-isolation.R`

The candidate evidence package attributes a passing final full
`testthat::test_dir("tests/testthat")` suite to this exact candidate; its only
warning was the intentional corrupt-ZIP fixture. Because the build, attempt,
bundle, hash and byte count are exact and the later commit changed only a test
fixture, the full suite was not repeated.

## Governed promotion

Promotion used `promote_retained_candidate()` with the exact candidate hash,
byte count, build, attempt, bundle, schema, scope ID/digest, candidate
populations and incumbent production SHA-256. The mechanism acquired the update
lock, revalidated the retained candidate and release scope, rechecked the
incumbent hash, staged a byte-identical copy, created the pre-swap backup,
performed the atomic replacement, updated the checksum and build manifest,
wrote the durable promotion record, and reported its built-in read-only smoke
test as passed. No rollback was needed.

Previous production SHA-256:
`eaba62ab6efbc3c81a59dd77493282d5a3f28290319ec487f0876eb3b318c553`.
New production SHA-256:
`11727959edd135bb211dd267dedd0d7c569dea3e473510ee72b6ef8cb1155876`.
The sidecar, manifest, production bytes and retained candidate all agree.

Backup:
`database/backups/paraguay_macro_pilot_pre_swap_20260918_201352.duckdb`;
its SHA-256 is the previous production hash. Promotion record:
`database/releases/promotions/build_180fb40bb51fadff89f9509f_20260918_201359.json`.
The retained candidate remains present and unchanged.

An additional independent read-only post-promotion smoke check verified the
active accepted build/bundle, zero release errors, 1,248,919 facts, 12,313
identities, 7,269 CDA exploratory curve observations, 10,334 LRM facts, and all
141 public views.

## Remaining CDA work

Rate unit/convention/periodicity/compounding, volume unit/currency/scale, the 15
positional nodes, official source/release/acquisition evidence, licence and
publisher verification remain unresolved. The next workstream should be CDA
semantic expansion only after authoritative BCP/source-owner evidence is
available. TCN remains a separate deferred workstream and was not started.

The executable independent verification is retained in `verify_acceptance.R`.
