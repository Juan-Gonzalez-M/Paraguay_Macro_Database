# RSUI and WPFXI experimental onboarding — Schema 49

## Result

RSUI and WPFXI are incorporated into preservation, staging, provisional
canonical catalogue and exploratory processing. They are not classified as
official statistics and receive no `research.*` admission.

| Source | Dataset | Classification | Series | Observations |
|---|---|---|---:|---:|
| `imf_rsui` | `IMF.WHD:RSUI(1.0.0)` | experimental research indicator | 16 | 6,992 |
| `imf_wpfxi` | `IMF.STA:WPFXI(1.0.2)` | working-paper public data and proxies | 186 | 34,541 |

The combined IMF population is now 24 dataflows, 20,964 published series codes,
2,558,738 numeric observations and 101,095 FSI textual metadata values.

## Controls

- Both source files are pinned by exact SHA-256 in
  `schema49_imf_experimental_20260919`.
- Dataset, version, series code, frequency, country, published periods and all
  other dimensions remain source-native.
- Structural blanks are not facts and no transformations or imputations are
  generated.
- Product-specific rights review remains pending. Allowed use is internal,
  non-commercial exploratory inspection with IMF attribution.
- `research.series_catalog` contains zero RSUI or WPFXI rows.
- IMTS remains absent from `config/source_registry.csv` and `raw.source_files`.

## Candidate

- path: `database/candidates/blocked_20260919_192433.duckdb`
- release: `release:42753eb4fa49d2dbedd73b07`
- build: `build:68ee020667d5b12855fbee13`
- attempt: `attempt:9c00088f5aa91c93b3b6c6cb`
- schema: 49
- SHA-256: `1d0053eb2f83da52d3cc9ef2ce2ec62d2786e80ee896ef96ca7c5e5656a6667b`

The release gate retained the candidate because the working tree was
uncommitted. Historical `blocked_release_visible` rows remain in the append-only
audit table, but the current attempt has no public-contract error and the
`marts.v_observation_source_behaviour` contract is valid. No IMF validation
failed and production was not modified.

## Verification

Focused parser, contract, scope and migration tests pass. The full regression
suite and real-source smoke test completed; the only error is the already-known
strict environment mismatch against `renv.lock`. The corrupt-ZIP isolation test
emits its expected warning.

Created in this phase:

- `docs/audits/imf_discovery_20260919/build_experimental_candidate.R`
- `docs/audits/imf_discovery_20260919/EXPERIMENTAL_ONBOARDING_REPORT.md`
- `database/candidates/blocked_20260919_192433.duckdb` (ignored review artifact)

Modified in this phase:

- `README.md`
- `config/acquisition_contracts.csv`
- `config/imf_wide_contracts.csv`
- `config/missingness_contracts.csv`
- `config/release_input_scope.csv`
- `config/source_grains.csv`
- `config/source_registry.csv`
- `config/source_vintages.csv`
- `config/table_domains.csv`
- `config/table_status.csv`
- `docs/SCHEMA_MIGRATIONS.md`
- `docs/audits/imf_discovery_20260919/IMPLEMENTATION_STATUS.md`
- `scripts/02_extract_raw.R`
- `tests/testthat/test-exploratory-layer.R`
- `tests/testthat/test-imf-wide-parser.R`
- `tests/testthat/test-research-platform.R`
