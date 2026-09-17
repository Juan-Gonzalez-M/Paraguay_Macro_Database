# LRM parser and identity remediation

## Verdict

`PARTIALLY READY — UNRESOLVED LRM SUBSET WITHHELD`

The corrected source is suitable for bounded acceptance review, but not for promotion in this
session. Amount and bid-count measures with semantic event identities are available provisionally
through `explore.events`. Rate measures remain catalog-only because the workbook does not state a
rate unit. Thirty-nine identities tied to four colliding 2013 rows remain catalog-only because the
workbook publishes no auction identifier capable of separating them without a positional lane.
Nothing was admitted to `research.*`.

## Source contract and historical structure

The immutable source is `Subasta de LRM_WEB.xlsx`, SHA-256
`b7e160f57d37a215d182eaeffea7d18a4e99151ebbde1efd9aa320d08ba71a37`. All fourteen annual sheets,
2013--2026, use rows 13--14 as a two-level A:P header. Merges are A13:C13, D13:E13, F13:H13,
I13:J13, K13:M13 and N13:P13. Rows 11--12 are hidden in 2020--2026; there are no hidden columns.
The 1,763 formula cells are retained as formula/cached-value evidence; 1,744 are event dimensions.
The machine-readable worksheet comparison is `worksheet_structure.csv`.

No material column-layout change occurs across the fourteen sheets. Row counts, formula counts,
hidden-row state and observed date ranges change by year. `Subastas 2015 ` retains its publisher
trailing space. Some sheet titles contain publisher anomalies (for example older titles ending in
`1`, and 2021--2026 retaining `SUBASTAS DE LRM 2020`); these are preserved as source text and do not
enter economic identity.

## Representation and identity

The representation is native-grain auction-tenor event measures, not derived aggregates and not
annual-sheet series. Stable identity uses standardized tenor, residual tenor and the explicit
measure; auction date is the observation date. Settlement and maturity dates are retained as event
dimensions in the parser output and raw coordinate layer. Annual worksheet is lineage only.

The corrected measures are announced/offered/assigned amount, offered/assigned bid count, and the
six explicit offered/assigned × average/minimum/maximum rate measures. No public label is merely
`Promedio`, `Minima` or `Maxima`.

The narrowest published event key tested was auction date + settlement date + maturity date +
standardized tenor + residual tenor. Two duplicate keys covering four rows occur in `Subastas 2013`.
They are preserved with an explicitly positional unresolved storage lane and withheld; no value is
used in identity.

## Units

- Amounts: publisher-explicit PYG, scale millions; values are retained exactly as published.
- Tenors: publisher-explicit days.
- Bid counts: count, scale units.
- Rates: side and statistic are explicit, but the unit is not; stored as `source_units` /
  `UNRESOLVED_SOURCE_UNITS` and withheld.

No percent interpretation or rescaling was inferred from value ranges.

## Cell reconciliation

The cell ledger contains 20,016 A1 cells: 10,351 parsed observations, 5,075 identity/dimension
cells, 448 headers, 78 intentionally excluded non-observational cells and 4,064 blanks. It records
1,763 formula/cached-formula coordinates and zero parser-defect cells. Every numeric F:P data cell
emits exactly once; no emitted source coordinate is duplicated. All fourteen sheets are present.
See `source_cell_reconciliation.csv` and its summary.

## Populations and migration

| Population | Production | Candidate |
|---|---:|---:|
| Canonical facts | 1,227,082 | 1,227,082 |
| Non-LRM series | 10,902 | 10,902 |
| LRM facts | 10,351 | 10,351 |
| LRM identities | 3,083 | 957 |
| LRM exploratory observations | 0 | 4,597 |
| LRM research observations | 0 | 0 |

All 3,083 old identifiers have exactly one migration disposition: 604 one-to-one renames and 2,479
many-to-one mappings, all matched by exact source cell and period. The old side contributes 10,351
observations and every one is shared with its replacement. Aliases remain resolvable through the
existing migration interfaces. The enriched ledger is `lrm_identifier_migration.csv`; the repository
also generated `outputs/series_id_migration.csv`.

Candidate LRM admission is 417 eligible semantic identities / 4,597 observations; 501 semantic rate
identities are withheld for unresolved units; 39 positional identities are withheld for published
event-key collisions. CDA and TCN remain deferred with zero series/observations. Non-LRM series and
facts are invariant.

## Candidate and verification

- Candidate: `database/candidates/accepted_for_review_20260917_174613.duckdb`
- SHA-256: `a0c86e4e91124573699883accba053cca61279546b71ceca7981df64ac9a01ef`
- Bytes: 439,103,488
- Build: `build:a7fa76ae9c866dca60ed2605`
- Attempt: `attempt:09850a0b5d3ba2a8cc3da2c0`
- Source bundle: `release:dcbccb827b93ee2362ab3c56`
- Schema: 44
- Release gate: accepted with warnings, zero errors; retained without publication
- Production SHA-256 before and after:
  `f53a973b65c12eb2492871613c9eb67676b52ba3a74555ddb6e8114a0dc28876`

Focused real-workbook parser, migration, exploratory-interface and research-interface tests passed.
The complete `tests/testthat` suite passed. Its sole warning is the intentional corrupt-zip warning
in the ingestion-failure-isolation test. Stored public views/macros were exercised from fresh default
connections by the release gate and regression suite. The candidate was built with the explicit
development overrides for the pre-existing environment drift and dirty working tree; both remain
visible warnings and must be considered during acceptance.

## Files changed

Parser and identity: `scripts/03_curate_expanded.R`, `scripts/03_curate_documented.R`,
`config/sheet_modes.csv`. Migration/build: `scripts/02_extract_raw.R`, `scripts/06_pipeline.R`,
`docs/SCHEMA_MIGRATIONS.md`. Admission: `scripts/13_explore.R`. Tests:
`tests/testthat/test-lrm-auction-parser.R`, `tests/testthat/test-exploratory-layer.R`,
`tests/testthat/test-research-platform.R`, `tests/testthat/helper-project.R`. Evidence tooling:
`scripts/lrm_remediation_evidence.R`. User-facing schema title: `README.md`.

## Bounded acceptance checklist

- Confirm that PYG millions is the intended public description of F:H without rescaling values.
- Obtain authoritative evidence for the rate unit, or accept continued rate withholding.
- Review the four colliding 2013 rows and determine whether an external auction identifier exists.
- Verify the 3,083-row migration ledger and representative aliases.
- Confirm 4,597-row provisional `explore.events` scope and zero `research.*` admission.
- Confirm non-LRM invariance, CDA/TCN deferral, production hash, candidate hash and zero gate errors.
- Rebuild from a committed, lockfile-consistent tree if reproducible acceptance requires removal of
  the recorded dirty-tree/environment warnings.
- Only after a separate explicit authorization, promote the hash-pinned retained candidate through
  `promote_retained_candidate()` with the recorded identities above.
