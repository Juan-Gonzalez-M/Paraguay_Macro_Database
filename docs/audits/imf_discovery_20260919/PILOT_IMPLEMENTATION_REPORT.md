# IMF pilot implementation report — 2026-09-19

## Outcome

The approved CPI, ER, EER, QNEA, and CTOT pilot is implemented through the
preservation, staging, canonical, catalog, and exploratory layers. No IMF series
is admitted to `research.*`. No candidate was promoted and the published
database remained byte-for-byte unchanged.

The isolated build completed ingestion but was correctly blocked by the release
gate and retained at:

`database/candidates/blocked_20260919_175200.duckdb`

Candidate identity:

- release: `release:6eff4860e564a105024312d8`
- build: `build:96c6ee3f555a7f86532032c2`
- attempt: `attempt:5f31d745755309011d92cb4a`
- schema: 47
- SHA-256: `f680d317eb745909ce1947a5eb50e793a627c98b90be82eab1aa30b84bc684df`

The blocking condition for the current attempt is not an IMF parsing failure:
it is the dirty-tree reproducibility error. Earlier `blocked_release_visible`
flags for `marts.v_observation_source_behaviour` are retained historical audit
rows, not errors of this attempt; the current contract declares that view with
`public_scope=current` and a release boundary.

## Loaded population

| source | series/raw records | non-empty observations |
|---|---:|---:|
| imf_cpi | 782 | 130,548 |
| imf_er | 288 | 105,780 |
| imf_eer | 24 | 9,030 |
| imf_qnea | 595 | 29,632 |
| imf_ctot | 108 | 60,156 |
| **total** | **1,797** | **335,146** |

Each source reconciles exact raw records, series, and non-empty period cells
against `config/imf_wide_contracts.csv`. Structural blank period cells are not
facts. Original period labels, raw values, observation status, source row,
source column, dataset/version, series code, dimensions, and reconstructed inner
payload are retained. The source bytes remain immutable and content-addressed.

## Isolation and public scope

- The source scope `schema47_imf_pilot_20260919` admits exactly 29 current
  hashes: 24 carried-forward sources and the five IMF pilot exports.
- IMF series remain provisional and are excluded from `research.series_catalog`.
- No IMF/BCP concordance or equivalence is asserted.
- No implicit conversion, aggregation, interpolation, seasonal adjustment, or
  derived growth calculation is performed.
- The production SHA-256 remains
  `9cf802028b8693506f5f6ad9ab321f2ace93f314fbeffe0a5ac831cdad087ca4`
  (Schema 46, build `build:6928154663966c1f7d0ee63d`).

## Verification

- Focused parser tests passed on all five real IMF files.
- Historical Schema 43 and Schema 46 scope tests passed after explicitly
  reconstructing their closed historical source universes.
- Governance/migration, research-platform, exploratory-layer, semantic-contract,
  and source-identity suites passed.
- The full test directory completed. Its only error is the expected strict
  environment mismatch (six directly loaded packages differ from `renv.lock`);
  packages were not installed. One intentional corrupt-ZIP isolation test emits
  its expected warning.
- Text diffs pass `git diff --check`. The all-files invocation cannot run in the
  sandbox because Git LFS attempts to write under `.git/lfs/tmp`; the published
  database hash was therefore verified directly with SHA-256.

## Exact implementation files

Created:

- `config/imf_wide_contracts.csv`
- `scripts/16_imf_wide.R`
- `tests/testthat/test-imf-wide-parser.R`
- `docs/audits/imf_discovery_20260919/build_pilot_candidate.R`
- `docs/audits/imf_discovery_20260919/PILOT_IMPLEMENTATION_REPORT.md`

Modified for this pilot:

- `README.md`
- `config/acquisition_contracts.csv`
- `config/missingness_contracts.csv`
- `config/release_input_scope.csv`
- `config/source_grains.csv`
- `config/source_registry.csv`
- `config/source_vintages.csv`
- `config/table_dictionary.csv`
- `config/table_domains.csv`
- `config/table_status.csv`
- `docs/SCHEMA_MIGRATIONS.md`
- `scripts/01_utils.R`
- `scripts/02_extract_raw.R`
- `scripts/03_curate_special.R`
- `scripts/04_validate.R`
- `scripts/06_pipeline.R`
- `scripts/08_reconciliation.R`
- `scripts/load_project.R`
- `tests/testthat/test-cda-provisional-scope.R`
- `tests/testthat/test-exploratory-layer.R`
- `tests/testthat/test-release-input-scope.R`
- `tests/testthat/test-research-platform.R`

The candidate and normal ignored runtime outputs were also created, but the
published database, its sidecar, backups, promotion records, original IMF files,
CDA/TCN acceptance package, and `research.*` interfaces were not modified by
this work.
