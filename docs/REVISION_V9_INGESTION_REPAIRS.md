> Historical record of one release. The current acceptance rule, run-status vocabulary and data model are in `README.md`, `docs/OPERATIONS.md` and `docs/DATA_MODEL.md`; where this file disagrees with them it is describing an earlier state. Since schema 23 a failing run reports `release_blocked`, not `completed_with_errors`, and since schema 24 a release carries its own lifecycle in `audit.releases`.

# Version 9 ingestion repairs

Version 9 implements the seven mechanisms reproduced in the external v8 ingestion review while retaining the v8 vectorization and single-pass workbook reads.

| Reported mechanism | v9 implementation | Guard or test |
|---|---|---|
| Named Excel table not found | `xlsx_named_table_catalog()` reads and verifies `xml_root()` | 15 real named tables must have names, ranges and column signatures |
| Empty formula view loses schema | `cells_from_matrix()` returns a typed zero-row tibble | Empty-sheet content hash test |
| Matrix flattened before `which()` | Shared `matrix_predicate()`, `matrix_detect()` and `matrix_equal()` | Exact real/synthetic row-column coordinates |
| `set` month missing | September alias added | Date-helper regression |
| Naked numbers interpreted as quarters | Explicit `T`/`trim` required; structural inference is limited to a complete Q1--Q4/annual block | Naked-digit rejection and direct-investment real-file test |
| Incomplete series/event identity | Hierarchical credit question IDs, corrected annual boundaries, semantic row-event dimensions and deterministic value-invariant lanes | Real credit, direct-investment, interbank, LRM and liquidity tests |
| Discovery outside source transaction | Discovery, metadata, ingestion and validation share the source-level `tryCatch`; a minimal failed provenance row is inserted if discovery fails | Corrupt-first/good-second pipeline regression |

## Event identity policy

LRM auctions are keyed by standardized tenor; interbank secondary-market operations by instrument and residual term; liquidity operations by term. If two rows still share the same period and semantic key and the source provides no operation identifier, v9 assigns a deterministic within-key occurrence lane. The lane is based on source order, never on amount, rate or another observed measure, so a value revision does not manufacture a new identity. Such series are marked `identity_stability = positional_lane` and raise a review warning.

## Migration behavior

The schema records version 9 and marks every documented Excel source for one corrected re-ingestion when upgrading from v8. Series, concept links, events and documented snapshots from those vintages are removed transactionally before rebuilding. The reference workbook is also retried. Direct sources and long CSV sources are not invalidated by this repair.

## Acceptance

On an R-enabled machine, run:

```r
source("run_tests.R")
source("run_update.R")
```

Do not accept the update if `outputs/update_report.md` reports `completed_with_errors`. Review positional-lane warnings and confirm all 22 source vintages completed.
