# IMF expansion report — Schema 48

## Scope and result

The second onboarding phase adds 17 dataflows to the five-dataflow pilot. The
implemented IMF population is now 22 dataflows. IMTS bilateral trade, RSUI and
WPFXI remain outside the registry and outside every database layer.

| Dataflow | Series codes | Numeric observations | Text metadata |
|---|---:|---:|---:|
| BOP | 7,520 | 760,820 | 0 |
| CPI | 782 | 130,548 | 0 |
| CPI_WCA | 30 | 5,690 | 0 |
| CTOT | 108 | 60,156 | 0 |
| EER | 24 | 9,030 | 0 |
| ER | 288 | 105,780 | 0 |
| FSIBSIS | 883 | 99,395 | 0 |
| FSIC | 710 | 87,244 | 0 |
| FSI_COUNTRY_METADATA_TABLE_2 | 497 | 0 | 101,095 |
| IIP | 2,947 | 197,733 | 0 |
| IL | 288 | 149,846 | 0 |
| IRFCL | 2,632 | 215,764 | 0 |
| ITG | 37 | 5,980 | 0 |
| MFS_CBS | 540 | 98,662 | 0 |
| MFS_DC | 1,019 | 190,028 | 0 |
| MFS_IR | 148 | 37,068 | 0 |
| MFS_MA | 80 | 14,659 | 0 |
| MFS_ODC | 466 | 90,673 | 0 |
| PCPS | 852 | 209,333 | 0 |
| PI_WCA | 16 | 2,184 | 0 |
| QGDP_WCA | 300 | 16,980 | 0 |
| QNEA | 595 | 29,632 | 0 |
| **Total** | **20,762** | **2,517,205** | **101,095** |

The FSI metadata file has 1,988 data records because each of 497 series codes
has four published metadata measures: definition, consolidation basis,
intragroup adjustments and accounting standards. These are 1,988 metadata
identities, but not 1,988 distinct economic series codes and not numeric facts.

## Safety and reconciliation

- Every registered file is pinned by SHA-256 in
  `schema48_imf_expansion_20260919`.
- Record counts, distinct series codes, numeric observations, metadata values
  and encodings are contract-checked per dataflow.
- The Windows-1252 PI_WCA export is converted explicitly to UTF-8 after byte
  encoding detection; an unconvertible byte fails ingestion.
- Reconciliation counts numeric and textual populated period cells together,
  while retaining them in separate carriers.
- Aggregates and staff estimates remain labelled as dataset-level aggregate
  sources. PCPS remains a global-factor source.
- All IMF sources remain provisional and return zero rows from
  `research.series_catalog`.
- Production retains SHA-256
  `9cf802028b8693506f5f6ad9ab321f2ace93f314fbeffe0a5ac831cdad087ca4`.

## Candidate disposition

The isolated candidate completed ingestion and validation but the common
release gate retained it as blocked. The only error on the current attempt is
the uncommitted tree. Historical `blocked_release_visible` rows remain in the
append-only audit table but do not belong to this attempt; the current public
contract for `marts.v_observation_source_behaviour` is present and valid.

## Files created in this phase

- `docs/audits/imf_discovery_20260919/build_expansion_candidate.R`
- `docs/audits/imf_discovery_20260919/EXPANSION_REPORT.md`
- `database/candidates/blocked_20260919_184122.duckdb` (ignored review artifact)

## Files modified in this phase

- `README.md`
- `config/acquisition_contracts.csv`
- `config/imf_wide_contracts.csv`
- `config/missingness_contracts.csv`
- `config/release_input_scope.csv`
- `config/source_grains.csv`
- `config/source_registry.csv`
- `config/source_vintages.csv`
- `config/table_dictionary.csv`
- `config/table_domains.csv`
- `config/table_status.csv`
- `docs/SCHEMA_MIGRATIONS.md`
- `docs/audits/imf_discovery_20260919/IMPLEMENTATION_STATUS.md`
- `scripts/01_utils.R`
- `scripts/02_extract_raw.R`
- `scripts/04_validate.R`
- `scripts/08_reconciliation.R`
- `scripts/16_imf_wide.R`
- `tests/testthat/test-exploratory-layer.R`
- `tests/testthat/test-imf-wide-parser.R`
- `tests/testthat/test-research-platform.R`

The historical scope tests had already been adapted during the pilot to
reconstruct their closed source universes; no historical promotion or scope row
was rewritten.
