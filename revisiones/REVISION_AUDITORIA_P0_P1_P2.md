# Response to the technical audit — P0, P1 and P2

Audit: `Technical_Audit.docx`, comparative edition, 28 August 2026, read-only against
`paraguay_macro_pilot (2).duckdb` (schema 12).
Work delivered: schema 13 (P0) and schema 14 (P1 and P2).
Scope agreed with the project owner: the §12 roadmap items P0, P1 and P2. P3 was not in scope.

---

## 1. Was the criticism valid?

Yes. Every figure in the audit that could be checked was re-verified read-only against the
production database **before any code changed**, and all of them matched exactly.

| Audit claim | Verified |
|---|---|
| 66 base tables / 44 views / 240,922,624 bytes | exact |
| 23,012 `dim_series`, 1,216,299 `fact_series_events`, 23,013 `dim_concept` | exact |
| 22 source files / 284 source sheets / 93 Annex sheet identifiers | exact |
| positional-lane 9,924 (43.13%) | exact |
| one-observation 10,462 (45.46%); under 12 observations 13,300 (57.80%) | exact |
| `fact_series_events` all-nullable, no primary key; 0 foreign keys | exact |
| `table_status` 30 rows (21 provisional, 9 needs_remodeling); `v_research_series` 0 rows | exact |
| credit_survey 321 series including exactly 50 positional, 25 conflicting groups | exact |
| economic_annex 10,619 series, 7,812 positional-lane | exact |
| monthly dates split day-1 587,516 / month-end 256,487 | exact |
| `price_base_year` blank for 22,975 of 23,012 series | exact |
| 535 future-dated Annex observations plus 30 in FX operations | exact |
| 1,571 of 28,417 prior identifiers retained | exact, and reproduced by the migration map |

Two findings are refined rather than accepted as written; both are documented in §4.

---

## 2. Headline result

| Measure | Audited release (schema 12) | Now (schema 14) |
|---|---|---|
| Catalogued series | 23,012 | **15,191** |
| Fact observations | 1,216,299 | 1,209,313 |
| Positional-lane series | 9,924 (43.13%) | **2,112 (13.90%)** |
| One-observation series | 10,462 (45.46%) | **3,751 (24.69%)** |
| Series under 12 observations | 13,300 (57.80%) | **6,586 (43.36%)** |
| Median series length | 3 | **17** |
| economic_annex positional-lane | 7,812 | **0** |
| credit_survey positional identities | 50 | **0** |
| credit_survey conflicting question/response groups | 25 | **0** |
| Cross-release identity map | absent | **3 hops, 74,474 mappings, 0 unresolved identifiers** |
| Source-cell reuse across all worksheets | untested | **0 of 242 worksheets** |
| Observation grain | unenforced | **PRIMARY KEY + 4 NOT NULL** |
| Release behaviour on an error flag | advisory | **blocks, non-zero exit** |
| Validated research series | 0 | **0, deliberately** |

Every remaining observation change is explained cell by cell in §5.

---

## 3. What was implemented

### P0 — schema 13

| # | Audit item | Delivered |
|---|---|---|
| 1 | Publish a complete old-to-new series-ID migration table | `series_id_migration`, `source_alias`, `continuity_map`; `scripts/07_migration.R`; operator entry point `build_migration_map.R`; view `v_series_id_resolution` |
| 2 | Resolve the 50 residual positional credit-survey series | Question-header test repaired in `documented_parse_credit_sheet()`; 50 → 0 |
| 3 | Keep `v_research_series` closed, promote only on evidence | Six evidence columns on `table_status`; `apply_table_status()` refuses a `validated` row without all of them; still 0 validated |
| 4 | Table-level source-to-target reconciliation | `table_reconciliation`; `scripts/08_reconciliation.R`; `config/reconciliation_exclusions.csv` |
| 5 | Lock the four repaired families with golden fixtures | `tests/testthat/fixtures/repaired_family_signatures.csv` + regression tests |
| 6 | Canonical release gate | Primary key and NOT NULL on `fact_series_events`; eight §11 P0 checks in `validate_release_gate()`; `release_blocked` status |

### P1 — schema 14

| # | Audit item | Delivered |
|---|---|---|
| 1, 6 | Concepts independent of source; stable canonical IDs | `canonical_series`, `map_canonical_series`, `methodology_regime`; reviewer-assigned IDs that a parser cannot move; `scripts/10_canonical.R` |
| 2 | Reviewed domain/subdomain classification for all 93 Annex identifiers | `config/table_domains.csv`, `table_domains`, `v_series_domain`; 94 worksheets, 11 domains, 0 unclassified |
| 3 | Remodel the detailed trade tables | R45 repaired: bounded period axis and provisional markers out of identity |
| 4 | Unit codes, scale multipliers, stock/flow, nominal/real, SA, transformation, valuation | `unit_code`, `scale_multiplier` derived and complete; five judgement fields created at `not_reviewed`; `outputs/semantic_metadata_completeness.csv` |
| 5 | `source_alias` and `continuity_map` with reviewer, evidence, valid dates | Delivered with P0.1 |
| 7 | `available_at` and as-of research views | `v_series_observations.available_at`, `observation_status`; `series_as_of_date(as_of)` |
| 8 | Standardise reference periods, add `period_start`/`period_end` | Derived in `v_series_observations`; `period` deliberately untouched |
| 9 | Enforced foreign-key and natural-key integrity checks | `validate_referential_integrity()`: 10 anti-join relations, 3 natural keys, release-blocking |

### P2 — schema 14

| # | Audit item | Delivered |
|---|---|---|
| 1 | Reviewed Annex marts | Seven marts: `v_mart_national_accounts_activity`, `_prices`, `_money_credit`, `_fiscal`, `_external_accounts`, `_trade`, `_reserves_fx`, each carrying review and reconciliation status |
| 2 | Coverage dashboard | `outputs/coverage_dashboard.csv`: per worksheet, grain, domain, range, review status, reconciliation, revisions, unresolved metadata |
| 3 | Methodology-break and concordance registries | `methodology_regime`, `classification_concordance` with guarded config files |
| 4 | Parser contracts and fixtures for every complex layout | `tests/testthat/fixtures/parser_contract_signatures.csv`: all 14 documented sources |
| 5 | Gap, outlier and cross-source screens | `run_quality_screens()`: §11 P2 gap test, robust discontinuity screen, cross-source comparison |
| 6 | Separate event and panel grains from scalar-series counts | `config/source_grains.csv`, `series_grain`, `v_catalogue_by_grain` |

The catalogue now distinguishes what it counts:

| Grain | Series | Observations |
|---|---|---|
| scalar_series | 8,181 | 993,219 |
| event | 4,953 | 94,280 |
| curve_panel | 1,287 | 116,766 |
| entity_panel | 770 | 5,048 |

---

## 4. Where this response departs from the audit

**P0.2 — the diagnosis was wrong; the defect is simpler and fully closed.** The audit reads the 50
positional credit-survey series as "a missing block or institutional dimension". They are not. In
worksheet `%`, row 94 is question `10,1 - Agricultura` and rows 95–97 are its
Aumentó/No cambio/Disminuyó answers; row 99 is `10,2 - Ganadería` and rows 100–102 are its answers.
The parser labelled rows 100–102 `10,1 - Agricultura`, so Agricultura and Ganadería collided — which
is exactly why their values conflicted. Root cause: `documented_parse_credit_sheet()` required a
header row to have no values, and **nine of the 73 header rows carry a stray numeric** in a period
column (row 99 carries thirteen). A tenth header, `18,2`, is published without a dash after the
number and failed the pattern too. The published question number is now the sole authority. No new
dimension was needed; 50 positional identities, 25 conflicting groups and 5 spurious singletons all
went to zero.

**P1.4 — mandatory seasonal-adjustment status has nothing to populate it.** A search of all 94 Annex
table titles for `desestacionalizad`, `tendencia.?ciclo`, `\bSA\b` and `serie original` returns
nothing. A populated column would be 15,191 guesses presented as metadata. Following the decision
taken with the project owner, the schema and controlled vocabulary exist, the two determinate fields
are derived and complete, and the five judgement fields are explicitly `not_reviewed` with a
published completeness report. This is what the audit's own VERIFY discipline requires.

**P1.8 — `period` is not rewritten.** `period` is part of the observation key; normalising it would
retire every identifier in the catalogue to fix a join hazard. `period_start` and `period_end` are
derived instead, so the mixed day-1/month-end convention can no longer lose observations or shift a
lag, at no cost in identity churn.

**P1.9 — anti-join tests rather than declared foreign keys.** Every curated table is rewritten with
DELETE-then-append on each run; a declared constraint would reject the pipeline's own normal
operation midway through a release. The anti-join tests give the same guarantee on the finished
release. The audit itself allows this ("where DuckDB workflow permits, plus release-blocking
anti-join tests").

**Not done, and why.** No series was promoted to `validated`: that is economic review with a named
reviewer, and inventing one would defeat the gate the audit asked for. The canonical and methodology
registers ship empty for the same reason — the machinery, guards and workflow are delivered;
populating them is review work. P3 was out of scope.

---

## 5. Verification

Every change was verified before and after a full pipeline run (`Rscript run_update.R`, exit 0,
0 error-severity flags).

**Credit survey (P0.2).** Cell-level `EXCEPT ALL` on
`(source_id, source_file, source_sheet, period, source_row, source_column, value)` between schema 12
and schema 13: **24 rows removed, 0 added, no other source touched**. All 24 sit on the nine
question-header rows identified above (76, 99, 109, 129, 144, 169, 199, 294, 339) and are the stray
numerics that were being read as survey responses. Header rows carrying strays: 1+13+1+2+1+2+2+1+1 =
24 — an exact account.

**Trade sheets (P1.3 / R45).** The shared horizontal extractor was re-run over all 94 Annex
worksheets and diffed series by series against the stored parse:

- **exactly 8 worksheets changed** (Cuadro 46a/46b/51a/51b/52a/52b/53a/53b); **85 unchanged**
- labels ending in a bare footnote marker: **22,228 → 0**
- diffing on the physical cell and value, ignoring labels: **6,962 removed, 0 added**
- every one of the 6,962 carries period **2026-07-01**, the last real period, and sits in a column
  past the end of the date axis — the exact signature of the unbounded fill-right
- the last column producing observations is now 392 (740 on Cuadro 52a/52b), the last real date
- `Soja` on Cuadro 53a is one series again: 391 observations, 1994-01 → 2026-07, replacing
  `Soja` (367) plus `Soja — *` (31) minus the 7 spurious comparison columns
- all eight worksheets now reconcile exactly: `unmapped_in_region = 0`, where before they did not

**Release gate.** The gate proved itself during this work: the schema-14 run was **blocked** because
the trade repair retired 7,812 identifiers before the migration hop was recorded. Recording it
cleared the block. That is the failure mode the audit's P0.1 exists to prevent, caught automatically.

**Reconciliation.** 242 worksheets measured; **cell reuse is zero on every one**. 195 balance
exactly; 47 carry 18,883 unmapped in-region cells, now recorded per worksheet with a status rather
than being invisible. No worksheet can be promoted to `validated` while unbalanced.

**Identity continuity.** Three hops recorded (schema 11→12→13→14, 74,474 mappings). Every identifier
the project has ever published resolves: 15,191 current, 21,307 aliases, 13,460 retired, **0 with no
recorded outcome**. Resolution is transitive and verified — the schema-11 fragment
`eve:bloque_de_inflacion_216:expectativa_del_mes` resolves to
`eve:bloque_de_inflacion:expectativa_del_mes`. The map independently reproduces the audit's
1,571 retained identifiers, and its 6,706 schema-13 retirements are exactly the audit's
"6,706 one-observation IDs concentrated in trade", confirming that entire population was this one
defect.

**Availability.** 565 observations are flagged `after_publication` — precisely the audit's 535 Annex
plus 30 FX-operations rows. Cuadro 49's quotations running to 2028-12 were checked against the raw
cells and are genuine published forward commodity prices, correctly flagged rather than treated as
realised data.

**Tests.** `tests/testthat/test-audit-p0-remediation.R` (40 assertions) and
`test-audit-p1-p2-remediation.R` (84 assertions) plus the existing suite.

---

## 6. Status

Against the audit's own closing assessment: the ingestion-induced identity inflation it diagnosed is
now substantially removed, the reproducibility contract it asked for exists and is enforced, and the
research boundary remains deliberately closed. What is still open is economic, not technical:
concepts, definitions, methodology regimes and the review that turns a provisional table into a
validated one. The database is now in a state where that review is the only thing standing between
it and the audit's target status — and where doing it is a matter of filling reviewed registers
rather than repairing parsers.
