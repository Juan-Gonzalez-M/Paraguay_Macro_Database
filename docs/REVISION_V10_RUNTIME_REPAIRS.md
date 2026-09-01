> Historical record of one release. The current acceptance rule, run-status vocabulary and data model are in `README.md`, `docs/OPERATIONS.md` and `docs/DATA_MODEL.md`; where this file disagrees with them it is describing an earlier state. Since schema 23 a failing run reports `release_blocked`, not `completed_with_errors`, and since schema 24 a release carries its own lifecycle in `audit.releases`.

# Version 10 runtime repairs

Version 10 responds to the real R execution recorded in `REVISION_v9.md` while preserving stable v7 identities, v8 performance and v9 source-level failure isolation.

| Runtime finding | v10 correction | Regression |
|---|---|---|
| Annex annotations acquired false dates | Date axes require an explicit date token; carry-forward stops at the last valid axis row | Real `Cuadro 49`, maximum source row 431 and period 2028-12-01 |
| A rate value was treated as year 2080 | Monthly history headers require consecutive years and Compra/Venta pairs; every vertical block is parsed | Five real historical sheets, more than 3,000 observations |
| Empty formula views disagreed with readxl | XML-empty bounds are `1:0`; reads and semantic matrices return typed 0 × 0 objects | All four real linked exchange-house views |
| Continuity SQL used a reserved implicit alias | Every aggregate alias uses `AS` | In-memory prior/current vintage execution |
| Deposit and repo shared an incomplete key | Local block titles map to canonical operation types before tenor and lane assignment | Real liquidity workbook; both types required |
| Bank EEFF differed by one from an old note | Verified 246,547 physical rows = one header + 246,546 data rows | Documented clarification; no parser change |

The migration marks only `economic_annex`, `exchange_rates`, `exchange_houses`, `liquidity_facility`, `interbank_market` and `lrm_auctions` for one v10 reingestion. The latter two are included because semantic dimension columns are no longer emitted again as measures; LRM identity now carries both standardized and residual tenor.
