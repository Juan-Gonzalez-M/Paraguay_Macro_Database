# Audit resolution report

## Executive result

The audit's confirmed public-model defect is fixed in schema 42. `research.entity_panel` now preserves
the publisher's source currency code, currency of origin, and reporting unit. The view returns all
332,745 accepted bank and finance-company EEFF rows instead of 93,217, with zero duplicate or
conflicting keys at the declared grain. A new release gate blocks both target-release source-key
collisions and any current source-to-research row loss.

No source observation, parser output, series identifier, economic definition, or published database
file was changed. The isolated schema-42 database contains the same 1,227,082 canonical fact rows as
the published database, with zero rows present on only one side.

The project is fit for limited research through its governed interfaces: the 32 admitted scalar
series, the corrected EEFF panel, and the structurally certified curve and transaction views. It is
not yet fit for broad macroeconomic release or real-time/revision research. Official provenance and
licence evidence remain incomplete, human economic review is empty, and identity, hierarchy, gap,
source-region, and discontinuity worklists remain open.

The published database was not replaced. It remains schema 41 with SHA-256
`17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180`. The isolated schema-42
validation artifact is
`/private/tmp/paraguay-audit-schema42.u0SbJv/paraguay_macro_schema42.duckdb` with SHA-256
`593a1457d373171336bd5e161bd89e434abc8fb79a01b7cdc45d84df04fb8809`.

## Final disposition by finding

| ID | Audit issue | Final disposition |
|---|---|---|
| AR-01 | EEFF currency collapse and row loss | **Fixed and validated.** Source currency code is the key; origin and unit are explicit; all 332,745 rows are exposed; release-blocking accounting was added. |
| AR-02 | Uncertified data in the same file | **Partial; decision required.** Zero uncertified scalar observations reach `research`, but a complete distributed file still contains maintainer layers. Artifact scope is a product decision. |
| AR-03 | Incomplete official provenance and licences | **Confirmed; not implemented.** All 22 audited vintages remain incomplete and all licences unverified. Values cannot be invented; official evidence is required. |
| AR-04 | As-of interface exceeds retained vintage evidence | **Confirmed limitation; decision required.** Every audited source has one vintage and inferred availability. Existing docs and dataset contracts prohibit real-time claims, but the macro remains callable. |
| AR-05 | Sparse economic metadata and no human review | **Confirmed; not implemented.** The existing eligibility gate correctly excludes unreviewed series. Completing it requires economist sign-off. |
| AR-06 | Generated or positional identities | **Partial; not implemented.** The project reproduces 820 positional identities and visibly quarantines them. The audit's broader 1,729 classification lacked its referenced attachment and requires source-by-source review and migration evidence. |
| AR-07 | Short scalar series and regular gaps | **Partial; not implemented.** There are 25 scalar series with at most two observations, none certified. The project reports 499 gapped series under its documented convention; disposition requires source review. |
| AR-08 | 6,522 unreviewed numeric cells outside parser regions | **Confirmed and contained.** Existing code prevents affected worksheets from promotion. Classification or parser extension requires source evidence. |
| AR-09 | Incomplete hierarchy and domain coverage | **Confirmed; not implemented.** Existing warnings and promotion gates prevent blind research use; mappings require economic review. |
| AR-10 | Empty continuity, concordance, methodology, and canonical registers | **Confirmed state; no automatic action.** Empty is preferable to unsupported equivalence or splicing. |
| AR-11 | Similar risk in other bank/finance panels | **Partial; future work.** Their source views already preserve currency code and are not exposed through a common research mart. Any new mart needs its own grain and missingness contract. |
| AR-12 | No persisted foreign keys | **Obsolete as a protection gap.** Release-blocking anti-joins cover project relationships, and deliberate orphan fixtures are tested. Persisted keys conflict with the pipeline's normal delete-and-append assembly. |
| AR-13 | Index-base variants and empty naming/measure fields | **Partial; not implemented.** `canonical_name` and `measure_type` already exist but are empty. Controlled population requires semantic evidence; publisher display text remains immutable. |
| AR-14 | Period/projection confusion | **Obsolete.** Current actual, publisher statement, projection, and normalized reference-period interfaces are separate and documented. |
| AR-15 | Discontinuity flags lack reviewed dispositions | **Confirmed review debt; not implemented.** The 38,433 flagged observations are a screen, not proof of error; source/methodology review is required. |
| AR-16 | Reproducibility not proven from the audit attachment | **Resolved for this repository.** The isolated migration, real-workbook smoke build, and complete regression suite ran successfully. |

The detailed pre-implementation evidence, root cause, proposed remedy, and validation criterion for
each row are in `docs/audits/audit_resolution_plan.md`.

## Implementation

### Public EEFF panel

`create_research_views()` in `scripts/12_platform.R` now partitions EEFF rows by
`codigo_moneda` and publishes it as `source_currency_code`. It also exposes
`currency_of_origin`, `unit_currency`, and `economic_currency`. The existing `currency` column
remains as a compatibility alias of the reporting unit.

The natural key is:

`(source_id, reference_period, entity_id, item_id, source_currency_code, measure)`.

This preserves the source distinction:

| Source code | Currency of origin | Reporting unit | Isolated panel rows |
|---|---|---|---:|
| 6200 | FX | PYG | 127,078 |
| 6900 | PYG | PYG | 205,667 |

### Release controls

`validate_platform_contracts()` now:

1. tests research-panel uniqueness on `source_currency_code`;
2. compares all accepted current EEFF source rows with `research.entity_panel` and raises
   `research_entity_panel_row_loss` on any difference; and
3. checks the target release through the unfiltered source views and raises
   `research_entity_panel_source_key_collision` before publication if the publisher grain collides.

The `collision_free_panel_row` rule is version 2. The public view contract states the corrected grain.
A negative test duplicates a real EEFF source row at a new physical coordinate and verifies that both
error controls fire.

### Schema and documentation

Schema 42 changes no source observation and requires no source re-ingestion. The migration registry,
generated migration runbook, data model, research guide, public view contract, certification rule,
and README version now agree. The migration-runbook test applies migrations to a temporary database
copy so development can validate a new schema without modifying the published artifact.

## Files changed

| File | Reason |
|---|---|
| `scripts/12_platform.R` | Correct the panel key and columns; add row-conservation and target-release collision gates. |
| `scripts/02_extract_raw.R` | Register schema 42 as a no-reingestion public-interface correction. |
| `config/certification_rules.csv` | Version the corrected panel assurance rule. |
| `config/public_view_contract.csv` | Declare the source-currency-code grain and explicit currency semantics. |
| `tests/testthat/test-research-platform.R` | Prove row conservation, key uniqueness, code semantics, and negative collision blocking. |
| `tests/testthat/test-governance-and-migrations.R` | Validate the current migration registry against an isolated migrated copy. |
| `docs/DATA_MODEL.md` | Document schema 42 and the panel's currency dimensions and grain. |
| `docs/RESEARCH_DATABASE_GUIDE.md` | Give researchers the correct grouping key and interpretation of 6200/6900. |
| `docs/SCHEMA_MIGRATIONS.md` | Generated schema-42 migration record. |
| `README.md` | Publish the current executable schema version. |
| `docs/audits/audit_resolution_plan.md` | Complete evidence-led findings ledger. |
| `docs/audits/audit_resolution_report.md` | Final dispositions, validation, release recommendation, and reproduction commands. |

Pre-existing CDA/TCN source files, parsers, configuration, tests, and other user changes were
preserved. They appear in the worktree status but were not authored or reclassified by this audit.

## Validation performed

### Original failure and corrected panel

Against the audited source rows:

| Check | Result |
|---|---:|
| Accepted EEFF source rows | 332,745 |
| Old `economic_currency` collision groups | 119,764 |
| Old collision groups with different values | 119,737 |
| Schema-42 research rows | 332,745 |
| Fixed-key collision groups | 0 |
| Fixed-key conflicting groups | 0 |
| Research duplicate groups | 0 |
| Isolated platform error flags | 0 |

The negative fixture passed: a duplicate publisher key causes
`research_entity_panel_source_key_collision` and `research_entity_panel_row_loss` error flags.

### Canonical and series diagnostics

The isolated schema-42 database was checked over the complete series universe:

| Grain | Series | Current actual observations | Series with at most two observations |
|---|---:|---:|---:|
| Scalar | 7,229 | 997,452 | 25 |
| Event | 4,485 | 95,477 | 2,894 |
| Curve panel | 1,287 | 116,766 | 117 |
| Entity panel | 984 | 17,044 | 336 |

All four grains have zero null and zero non-finite current values. The canonical fact table has
1,227,082 rows, zero duplicate primary keys, zero mismatched series references, zero mismatched
vintage references, and a stored period range of 1945-12-31 through 2028-12-01. The 25 short scalar
series include zero certified research series.

The expected grid contains 267,830 rows for 1,852 series and records 20,647 classified absences.
The publisher statement contains 343 projections; the actual view contains zero non-actual rows.
The scalar research boundary contains 32 admitted series and 7,498 actual observations, with zero
observations lacking a research-catalogue entry.

`research.curves` contains 38,922 rows with zero tested duplicate keys.
`research.transactions` contains 312,329 rows with zero duplicate transaction IDs and three rows
whose volume is explicitly `not_reported`.

### Regression and runtime

- All 1,227,082 canonical fact rows in the isolated database are set-identical to the published
  database: zero isolated-only and zero published-only rows.
- All 133 stored views bind from a fresh read-only connection with no `search_path`.
- The focused schema-42 research-platform tests passed.
- The focused public-interface tests passed.
- The focused governance/migration and project-loader tests passed.
- The real-workbook full-pipeline smoke test passed in an isolated temporary project. It exercised
  all current worktree sources; synthetic provenance for the pre-existing CDA/TCN onboarding was
  confined to the test copy.
- `Rscript --vanilla run_tests.R` completed successfully. Its only warning is intentional:
  `test-ingestion-failure-isolation.R` supplies a corrupt zip and verifies that discovery failure is
  persisted without losing the next source.
- `git diff --check` passed.
- The published database SHA-256 remained
  `17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180`.

## Remaining P1 and P2 work

The remaining work is review work, not a safe automatic correction:

- obtain official URL, release identifier/date, retrieval evidence, and licence evidence for each
  released vintage;
- choose a human-reviewed release set and complete semantic, unit, timing, hierarchy, and
  comparability review;
- investigate positional/generated identities source by source and migrate any changed identifiers;
- reconcile short-series and gap worklists against source coordinates and expected grids;
- classify the 6,522 out-of-region numeric cells before promoting their worksheets;
- populate hierarchy, domain, methodology, continuity, concordance, and canonical mappings only
  where reviewed evidence supports them; and
- disposition discontinuity flags for any series selected for release.

## Release recommendation and required decision

Do not replace the published database yet, consistent with the task instruction. The schema-42
candidate is technically sound for the corrected EEFF panel and preserves every canonical fact, but
the project still supports only a limited research release. It should not be described or distributed
as a broad research-ready macroeconomic database while provenance, rights, real-time history, and
economic review remain open.

The next product decision is whether to:

1. keep the complete auditable DuckDB as the maintainer artifact, publish only `research.*` as the
   supported limited interface, and retain `observations_as_of` with its explicit
   inferred-upper-bound prohibition; or
2. create a reduced researcher-only distribution artifact and withdraw the as-of interface until
   official timestamps and successive vintages exist.

After that choice, provide the official provenance/licence evidence for the intended released
sources and name the first domain or series set for human economic review.

## Reproduction commands

Run from the repository root.

Focused schema and public-interface checks:

```bash
Rscript --vanilla -e 'source("scripts/load_project.R"); load_project_scripts(getwd(), profile="pipeline", quiet=TRUE); testthat::test_file("tests/testthat/test-research-platform.R", reporter="summary")'
Rscript --vanilla -e 'source("scripts/load_project.R"); load_project_scripts(getwd(), profile="pipeline", quiet=TRUE); testthat::test_file("tests/testthat/test-public-interface.R", reporter="summary")'
Rscript --vanilla -e 'source("scripts/load_project.R"); load_project_scripts(getwd(), profile="pipeline", quiet=TRUE); testthat::test_file("tests/testthat/test-governance-and-migrations.R", reporter="summary")'
```

Isolated real-workbook build:

```bash
Rscript --vanilla -e 'source("scripts/load_project.R"); load_project_scripts(getwd(), profile="pipeline", quiet=TRUE); testthat::test_file("tests/testthat/test-full-pipeline-smoke.R", reporter="summary")'
```

Complete regression suite and final hygiene checks:

```bash
Rscript --vanilla run_tests.R
git diff --check
shasum -a 256 database/paraguay_macro_pilot.duckdb
```

To inspect the retained isolated schema-42 artifact from this audit:

```r
con <- DBI::dbConnect(
  duckdb::duckdb(),
  "/private/tmp/paraguay-audit-schema42.u0SbJv/paraguay_macro_schema42.duckdb",
  read_only = TRUE
)
DBI::dbGetQuery(con, "SELECT max(version) FROM audit.schema_version")
DBI::dbGetQuery(con, "SELECT count(*) FROM research.entity_panel")
DBI::dbDisconnect(con, shutdown = TRUE)
```
