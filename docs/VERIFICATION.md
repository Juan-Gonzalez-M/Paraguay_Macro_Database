# Pilot verification record

## Independently inspected workbook facts

- All 22 supplied source files open successfully: 20 Excel workbooks and two UTF-8 semicolon-delimited CSV files.
- The Economic Annex contains 94 worksheets: one index and 93 statistical tables. The 93 tables fall into eight recurring period orientations covered by the parser.
- Annex `Cuadro 49` contains genuine monthly projections through 2028-12-01 followed by percentage summaries and a footnote; only rows through 431 belong to its date axis.
- `CUADRO 8` begins in 1950, so the Annex has an explicit 1900 lower plausibility bound while the original curated sources retain the stricter 1980 bound.
- The payments bulletin contains 40 worksheets: one index, one 28-row BIC directory and 38 statistical tables.
- The exchange-house bulletin exposes three authoritative source panels plus its own entity/currency/item references; linked presentation sheets are not duplicated as observations.
- Several exchange-house sheets declare Excel row 1,048,576; XML-derived content extents cap reads at the last meaningful cell while retaining A1-based coordinates.
- The credit survey contains one response-share sheet and one index sheet, both with guarded year-quarter headers.
- Bank and finance-company worksheet names and headers match `config/direct_schema.csv` independently.
- The reference workbook contains all 15 expected named tables with the exact configured headers.
- Reference-table row counts match the values documented in `SEMANTIC_REFERENCE.md`.
- Current account identifiers are stored as shared-string text (including spaces and negative signs), not numeric Excel cells; the parser nevertheless forces text and rejects future scientific notation.
- The direct bank EEFF table contains 246,546 data rows; its 246,547 physical worksheet rows include one header. The finance-company EEFF table contains 86,199 data rows.
- Independent key comparisons produced the documented mapping coverage figures.
- The direct-investment workbook contains eight sheets and seven statistical year-quarter tables spanning 1995–2024.
- The insurance annex contains 43 sheets: cover, index and 41 fiscal-year statistical tables.
- The daily BCP FX workbook contains 14 annual sheets; the LRM workbook contains 14 annual sheets.
- The five monthly exchange-rate history sheets contain repeated consecutive-year blocks with paired Compra/Venta columns; isolated rate values in the 1900–2100 range are not headers.
- The interbank workbook contains three worksheets plus a chartsheet relationship. `Mdo Secundario` declares more than 2,700 columns but has meaningful content only through the first few columns.
- Corporate bond curves contain at least 38,000 data rows and both PYG and USD; securities trades contain at least 300,000 valid rows and both PYG and USD.

## Runtime defects addressed from the colleague’s R execution

The colleague’s R 4.3.3 execution established the failure modes and expected parser counts for v2. Versions 3 and 4 directly address every reproduced defect and both subsequent semantic/design review rounds:

- XML relationship IDs;
- source-filter data masking;
- Excel/R date epochs;
- character serial-date errors;
- UTF-8 YAML loading.

The corrected minimum acceptance targets encoded in tests are:

| Output | Expected result |
|---|---:|
| ICC snapshot | At least 1,236 rows |
| EVE snapshot | At least 2,760 rows |
| EVE date range | 2006-04-01 to 2026-08-01 |
| FX snapshot | At least 5,480 rows |
| FX latest content-based publication date | 2026-07-31 or later, within the plausibility bound |
| Reference named-table loads | At least 15 |
| Reference entities | At least 31 |
| Reference statement items | At least 218 |
| Reference credit activities | At least 1,112 |
| Economic Annex documented sheets | At least 93 |
| Economic Annex observations | At least 100,000 |

## Audit P0 repair targets

`tests/testthat/test-audit-p0-repairs.R` and the cardinality block of `test-full-pipeline-smoke.R` lock the P0 findings of the external technical audit. These are exact counts, not minimums: each is a repaired identity defect, so drift in either direction means a parser or the identity rule regressed. The full verification record is in `revisiones/REVISION_AUDITORIA_EXTERNA.md`.

| Check | Before | After |
|---|---:|---:|
| `compensatory_fx_sales` series | 36 | 3 |
| `compensatory_fx_sales` conflicting months (Total / Compensatorias / Complementarias) | 114 / 109 / 92 | 0 / 0 / 0 |
| `eve` series | 2,760 | 16 |
| `bcp_fx_daily` series | 168 | 12 |
| `credit_survey` one-observation series | 2,539 | 5 (register R52) |
| `CUADRO 61` series / non-semantic identities | 170 / 25,912 | 182 / 0 |
| `fx_operations` series | 30 | 30 (unchanged by design) |
| Documented series whose slug differs from `make_clean_names(sheet)` | — | 0 of 21,667 |
| Series with no declared table status | — | 0 |

Independent evidence that the repairs did not move data:

- Observation totals are identical source by source against the pre-migration database, except `compensatory_fx_sales` (−1,005 duplicated rows removed) and `economic_annex` (+394 `CUADRO 61` cells the generic extractor never read).
- `CUADRO 61` source-to-target balance is exact: the 26,306 numeric cells in columns 2-11 produce 26,306 observations, none unaccounted. The 301 cells in column 1 are the year axis and the 45 in columns 225-236 are a stray duplicated block; both are deliberate exclusions.
- Compensatory FX accepts 417 of 422 numeric cells. The five excluded (rows 114-118, column 9) are placeholder zeros in the totals column for August-December 2026, months whose component columns are still empty; accepting them would invent future zero-valued observations.
- Arithmetic reconciliation: `Total Ventas = Ventas Compensatorias + Ventas Complementarias` in all 139 months; in `CUADRO 61` the five operation types sum to the period total in 1,822 of 1,822 groups and the three institutions sum to `Total` in 350 of 350, within 0.01%.
| Payments documented sheets | At least 38 |
| Payments observations | At least 40,000 |
| Exchange-house documented panels | 3; at least 4,000 observations |
| Credit-survey documented sheets | 2; at least 15,000 observations |
| Additional documented Excel sources | Per-source sheet and observation minima in `documented_source_contracts.csv` |
| Corporate bond curves | At least 38,000 typed rows |
| Securities transactions | At least 300,000 typed rows; unique deterministic transaction IDs |

## Automated tests included

- deterministic vintage and release IDs;
- archive deduplication;
- sparse changes and explicit removals;
- v2 curated-output invalidation, v3-to-v4 migration and v4-to-v5 documented-source invalidation;
- v6 source-specific concept coverage, reviewed-mapping guards, bounded anchor lookup and sheet-level drift diagnostics;
- v7 identity invariance to unit/currency, positional-identity visibility, scale coherence and series continuity;
- v8 scalar-versus-vector metadata equivalence, explicit-override precedence, byte-identical identity hashes, vectorized year-month cell order and timing schema;
- v9 named-table-root discovery, typed empty worksheets, shape-preserving matrix anchors, conservative quarter parsing, hierarchical credit questions, row-event identity invariance and per-source discovery failure isolation;
- v10 real formula-only exchange-house sheets, Annex annotation-row exclusion, repeated exchange-rate year blocks, liquidity deposit/repo identity, explicit continuity SQL aliases and schema migration;
- v11 bootstrap-versus-migration separation, v9 concept cleanup, legacy v2 columns, ordered annotated-year axes, real `CUADRO 58` dates and dynamic EEFF header accounting;
- exact direct-source guards;
- ICC, EVE, FX and reference parsers against real files;
- full registry-derived 22-source temporary database build;
- source completion, row-count and plausible-date assertions;
- documented bank mapping existence.
- currency-origin versus measurement-unit rules;
- display-name-independent reference-table resolution;
- text-safe account identifiers;
- sparse reuse of unchanged report-sheet content;
- non-shrinking snapshot checks against the prior completed vintage.
- documented orientation helpers, per-source contracts, key Annex metadata, BIC/entity mapping and credit-survey ranges.
- chartsheet exclusion, active-cell bounds, long-CSV dimensions and typed market-table baselines.

## Execution environment

The historical note that R was unavailable in the packaging environment no longer applies. This
project is developed and verified on a machine with R and a populated runtime database, and the
schema-24 work was accepted only after a full migration, a complete 22-source rebuild and the test
suite were executed here.

The recorded environment is `renv.lock`. `check_environment()` compares the running R and package
versions against it and fails loudly on drift; `run_tests.R` calls it and no longer installs
anything, so running the tests cannot change the environment it is testing.

The acceptance commands are:

```r
source("run_tests.R")     # verifies the environment, then runs the suite
source("run_update.R")    # migrates, ingests, validates and decides the release
```

`run_update.R` returns a nonzero status when the release is blocked. A release that ends `blocked`
is never published: `v_series_latest`, `series_as_of_date()` and every mart join through
`audit.releases` and return nothing until the run repeats without error-severity flags.

After the update, use `outputs/ingestion_stage_timings_latest.csv` to compare elapsed time with the
prior run on the same machine and inputs.
