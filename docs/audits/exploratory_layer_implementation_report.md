# Exploratory layer implementation report

Date: 2026-09-13

## Executive result

Schema 43 adds a comprehensive candidate catalogue and a mechanically gated preliminary access layer
without changing formal research admission. Researchers can now search all 13,985 parser-identified
series candidates in `catalog.series`, inspect one through `catalog.profile(candidate_id)`, read
normalized limitations in `catalog.series_warnings`, and retrieve eligible observations from a
grain-specific `explore.*` relation. Direct-panel and long-format sources that are not completely
represented by `dim_series` remain discoverable in `catalog.datasets` with their native access link,
provenance state, rights limits, and status warning.

The current audited population yields 6,849 preliminary scalar candidates with 950,129 observations,
plus the 32 already admitted research series with 7,498 observations. The ordinary exploratory scalar
relation therefore exposes 957,627 observations across 6,881 candidates. It has zero orphan catalogue
links, malformed periods, null/non-finite values, projections, duplicate normalized logical keys, or
positional identities. A deliberate normalized-period collision is classified
`quarantined_or_invalid` and returns zero rows from `explore.series()`.

Formal `research.*` admission is unchanged. The schema still has exactly nine research views and one
research table macro. The retained validation artifact has the same 32 admitted series, 7,498 scalar
actual observations, 332,745 EEFF rows, 38,922 curve nodes, and 312,329 transactions established by the
schema-42 audit resolution. The canonical fact table is set-identical to production.

The production database was not overwritten. It remains at SHA-256
`17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180`. The retained isolated schema-43
artifact is `/private/tmp/paraguay-exploratory-schema43.60oOOT/paraguay_macro_schema43.duckdb`, SHA-256
`23d8feacf1492fc2847d05c5e5f55342f97265f525342a1a76696a7c1af0a015`.

## Final architecture

### `catalog.*`

`catalog.series` has candidate grain `canonical.dim_series.series_id`; `candidate_id` is the existing
parser identity and is never rebuilt from a display label or inferred cross-source equivalence. Every
row includes:

- researcher name with its naming basis, exact source label, full source path, institution, file,
  sheet/table, vintage, and SHA-256;
- controlled domain fields and explicit parsed dimensions where present;
- retained frequency with `frequency_basis = 'parser_assigned_requires_verification'`, because the
  current evidence register does not establish a publisher-documented basis;
- current actual coverage, non-missing count, normalized date regularity, regular-step gaps, expected
  grid/missingness summaries, and duplicate/conflict counters;
- unaltered unit, scale, currency, index base, transformation, seasonal-adjustment, stock/flow,
  nominal/real, valuation, and hierarchy fields, including unresolved sentinels;
- parser method and source coordinates where `staging.documented_series_snapshot` retains them; and
  explicit fact/vintage-only lineage otherwise;
- current database schema version, source build schema/code digest, validation tier, status code,
  concise warning, normalized warning codes, and the correct observation interface.

The repository has no independent parser-version field. The catalogue says
`not_recorded_use_build_code_digest` rather than inventing one. `catalog.series_warnings` expands every
warning code to one row and repeats candidate tier/status and source/vintage provenance so it is usable
without a hidden join. `catalog.datasets` has one row for every governed source registry entry and
links certified native products such as `research.curves`, `research.transactions`, and
`research.entity_panel` without converting their rows to fake scalar series.

### `explore.*`

`explore.observations` contains scalar current actual observations only when the candidate:

1. has a semantic identity and at least three non-missing current observations;
2. has finite values and non-null ordered normalized period bounds;
3. has no duplicate or conflicting `(candidate_id, reference_period_start)` key;
4. has no applicable error-severity flag; and
5. is not attached to a `needs_remodeling`, quarantined, invalid, or excluded table state.

`explore.events` retains event and interval bounds; `explore.panel_observations` retains entity-panel
candidate identities and dimensions; and `explore.curve_observations` retains curve-panel identities.
The latter two are generic candidate retrieval paths, while `research.entity_panel` and
`research.curves` remain the certified native-grain products. `explore.series(candidate_id)` retrieves
one eligible scalar candidate. Every exploratory row carries its tier, status, concise warning, warning
codes, source/vintage identity, parser method where known, build digest, and source coordinates where
available.

### `research.*`

The new tiers do not grant assurance. `research_ready` is assigned only when the candidate already
appears in `main.v_certified_research_series`. `exploratory_structurally_valid` is never written to the
certification ledger and never satisfies the existing human/rule admission gate. No research view,
macro, assurance level, certification decision, series definition, or economic value was broadened.

## Coverage by tier and structure

Counts below come from the retained schema-43 artifact built from the audited production facts.

| Validation tier | Structure | Candidates | Current actual observations |
|---|---|---:|---:|
| `research_ready` | scalar series | 32 | 7,498 |
| `exploratory_structurally_valid` | scalar series | 6,849 | 950,129 |
| `candidate_needs_review` | scalar series | 347 | 39,742 |
| `non_scalar_or_special_structure` | event | 4,485 | 95,477 |
| `non_scalar_or_special_structure` | irregular-interval scalar identity | 1 | 83 |
| `non_scalar_or_special_structure` | entity panel | 984 | 17,044 |
| `non_scalar_or_special_structure` | curve panel | 1,287 | 116,766 |
| `quarantined_or_invalid` | current population | 0 | 0 |
| **Total** |  | **13,985** | **1,226,739** |

The absence of a current invalid-tier row is a result, not a disabled state: the negative fixture proves
that a normalized-period collision enters that tier and is withheld. There are 25 scalar candidates
with at most two observations (27 observations total); all 25 remain discoverable as
`candidate_needs_review` and none appears in `explore.observations`.

| Exploratory interface | Candidates | Rows |
|---|---:|---:|
| `explore.observations` | 6,881 | 957,627 |
| `explore.events` | 4,486 | 95,560 |
| `explore.panel_observations` | 984 | 17,044 |
| `explore.curve_observations` | 1,287 | 116,766 |

`catalog.datasets` has 24 governed source rows in the current worktree: 15 carry
`candidate_needs_review` at dataset grain and nine are `non_scalar_or_special_structure`. The migrated
artifact contains active source vintages for the 22 production sources; the pre-existing CDA and TCN
onboarding sources are registered but have no active production vintage there. The separate full
real-workbook smoke build successfully exercised all 24 current worktree sources.

## Warnings and lineage coverage

All 13,985 candidates have normalized warnings: 149,828 rows across 19 warning codes. The largest
current limitations are:

| Warning | Candidates |
|---|---:|
| availability not publisher verified | 13,985 |
| frequency parser-assigned and requires verification | 13,985 |
| official source provenance incomplete | 13,985 |
| table not economically validated | 13,985 |
| seasonal adjustment requires verification | 13,965 |
| transformation requires verification | 13,766 |
| stock/flow requires verification | 13,102 |
| no expected grid constructed | 12,133 |
| hierarchy requires verification | 7,874 |
| unresolved unit | 4,057 |
| positional/positional-lane identity | 820 |
| declared-frequency gaps detected by the catalogue convention | 488 |
| short scalar candidate | 25 |

Source coordinates cover 12,640 candidates and 1,100,527 observations completely. The other 1,345
candidates and 126,212 observations retain fact, source file, vintage, SHA-256, and build lineage but
do not have a coordinate in `staging.documented_series_snapshot`; their profiles explicitly say
`fact_and_vintage_lineage_only`.

## Files changed

| File | Purpose |
|---|---|
| `docs/audits/exploratory_layer_plan.md` | Required pre-implementation architecture, tier rules, grain strategy, and acceptance tests. |
| `scripts/13_explore.R` | Schema-qualified catalogue profiles, warning normalization, dataset discovery, grain-specific exploratory relations, and lookup macros. |
| `scripts/load_project.R` | Adds the exploratory builder to the authoritative pipeline and research-tools profiles. |
| `scripts/12_platform.R` | Creates the new schemas, invokes the builder, and adds release-blocking catalogue/exploratory reconciliation checks. |
| `scripts/04_validate.R` | Extends publication-contract coverage to `catalog`/`explore` and normalizes DuckDB's quoted same-schema dependencies during release-boundary descent. |
| `scripts/02_extract_raw.R` | Registers additive schema 43 with no source re-ingestion. |
| `config/public_view_contract.csv` | Declares the scope and release-boundary expectations of all ten new views/macros. |
| `tests/testthat/test-exploratory-layer.R` | Proves coverage, tiers, keys, sparse-series withholding, lineage, macros, fresh binding, attached binding, and collision quarantine. |
| `tests/testthat/test-research-platform.R` | Advances the schema expectation while retaining the exact nine-view research contract. |
| `tests/testthat/test-public-interface.R` | Includes the two new schemas in stored-SQL qualification linting. |
| `docs/RESEARCH_DATABASE_GUIDE.md` | Adds validation-tier definitions and the five requested researcher SQL workflows. |
| `docs/DATA_MODEL.md` | Documents layer ownership, mechanical eligibility, grain-specific access, and unchanged research admission. |
| `README.md` | Identifies schema 43 and the three researcher-facing layers. |
| `CHANGELOG.md` | Records the schema-42 panel correction and schema-43 exploratory interface. |
| `docs/SCHEMA_MIGRATIONS.md` | Generated schema-43 migration record from the executable registry. |
| `docs/audits/exploratory_layer_implementation_report.md` | This implementation and validation record. |

The CDA/TCN source, parser, configuration, and test changes present before this task were preserved.
The schema-42 EEFF fix and audit-resolution documents were also preserved; this work does not claim
them as new exploratory-layer changes.

## Validation results

### Isolated database

- Schema version: 43.
- Catalogue: 13,985 rows and 13,985 distinct candidate IDs, exactly matching
  `canonical.dim_series`.
- Current actual accounting: 1,226,739 rows in both `main.v_series_latest` and the summed catalogue
  profiles; zero current observations without a catalogue entry.
- Scalar exploration: 957,627 rows; zero malformed/null/non-finite/projection rows; zero duplicate
  `(candidate_id, reference_period_start)` keys; zero positional identities or candidates with fewer
  than three observations.
- Special structures: event/interval, entity-panel, and curve-panel exposed row counts exactly equal
  their eligible catalogue profile totals.
- Warning accounting: `sum(catalog.series.warning_count) = 149,828 =
  count(catalog.series_warnings)`; no null warning code or warning text.
- Research boundary: 32 series and 7,498 actual scalar observations; zero research observation without
  its research catalogue row; exactly nine stored research views and one macro.
- Canonical regression: 1,227,082 facts in both schema 43 and production; zero schema-43-only and zero
  production-only fact rows.
- Stored object health: all 141 stored views bind from a fresh default connection with no `search_path`;
  the focused test also binds every new view while the database is attached under an alias.
- Release validation: zero error-severity flags for
  `release:exploratory-schema43-final-dimensions`.
- Production isolation: production SHA-256 remained
  `17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180`.

### Automated tests

- `tests/testthat/test-exploratory-layer.R`: passed.
- `tests/testthat/test-research-platform.R`: passed.
- `tests/testthat/test-public-interface.R`: passed.
- `tests/testthat/test-governance-and-migrations.R`: passed.
- `tests/testthat/test-project-loader.R`: passed.
- `tests/testthat/test-full-pipeline-smoke.R`: passed in a disposable project copy using the current
  real workbooks and all current source registrations.
- `Rscript --vanilla run_tests.R`: passed the complete suite. Its only warning is the intentional
  corrupt-zip fixture in `test-ingestion-failure-isolation.R`.
- `git diff --check`: passed.

## Remaining limitations

The preliminary layer does not resolve the review debt documented by the audit:

- all current candidates lack complete official provenance and publisher-verified availability;
- 4,057 units, 7,874 hierarchies, 820 positional identities, 488 catalogue-convention gap cases, and
  25 short scalar candidates remain explicitly flagged;
- no expected grid exists for 12,133 candidates, so absence of stored nulls is not proof of complete
  source coverage;
- source coordinates are unavailable for 126,212 observations from specialized parser paths;
- semantic review is incomplete for every exploratory-only scalar candidate;
- event, panel, curve, interval, and transaction data require their native grain and must not be
  counted or joined as ordinary macro time series;
- direct bank/finance products beyond the certified EEFF panel remain dataset-level catalogue entries
  until each native panel key and missing-value contract receives a dedicated public interface; and
- one retained vintage per production source and inferred availability still prevent defensible
  real-time, revision, or news-analysis claims.

These states are visible in the catalogue and are not silently repaired, excluded, or converted into
economic metadata.

## Release recommendation

Schema 43 is fit for a preliminary research-discovery product: its catalogue is comprehensive over the
current canonical candidate universe, its exploratory rows are mechanically controlled and visibly
limited, and its formal research boundary has not regressed. It is not a broad research-ready release.
Only `research.*` should be described as admitted research data, at the assurance shown on each row.

Do not replace the current production file solely from this report. The retained artifact demonstrates
the migration and interfaces, while the full smoke test demonstrates current-source rebuildability. A
production release should use the normal isolated candidate workflow from a clean reviewed commit and
become active only through its accepted product decision.

## Rebuild and validation commands

Run from the repository root.

Create a disposable schema-43 validation copy without touching production:

```bash
Rscript --vanilla - <<'RS'
root <- normalizePath(getwd(), winslash = '/', mustWork = TRUE)
source('scripts/load_project.R')
load_project_scripts(root, profile = 'pipeline', quiet = TRUE)
output <- file.path(tempdir(), 'paraguay_macro_schema43.duckdb')
stopifnot(file.copy('database/paraguay_macro_pilot.duckdb', output, overwrite = TRUE))
con <- connect_project_database(output)
initialize_database(con, root)
apply_platform_contracts(con, root, 'build:exploratory-schema43-validation')
create_canonical_views(con)
create_mart_views(con)
create_research_views(con)
validate_platform_contracts(con, 'release:exploratory-schema43-validation', root)
stopifnot(DBI::dbGetQuery(con,
  "SELECT count(*) n FROM audit.quality_flags
   WHERE release_id='release:exploratory-schema43-validation' AND severity='error'"
)$n == 0)
DBI::dbDisconnect(con, shutdown = TRUE)
message(output)
RS
```

Run focused, real-workbook, and complete validation:

```bash
Rscript --vanilla -e 'source("scripts/load_project.R"); load_project_scripts(getwd(), profile="pipeline", quiet=TRUE); testthat::test_file("tests/testthat/test-exploratory-layer.R", reporter="summary")'
Rscript --vanilla -e 'source("scripts/load_project.R"); load_project_scripts(getwd(), profile="pipeline", quiet=TRUE); testthat::test_file("tests/testthat/test-research-platform.R", reporter="summary")'
Rscript --vanilla -e 'source("scripts/load_project.R"); load_project_scripts(getwd(), profile="pipeline", quiet=TRUE); testthat::test_file("tests/testthat/test-public-interface.R", reporter="summary")'
Rscript --vanilla -e 'source("scripts/load_project.R"); load_project_scripts(getwd(), profile="pipeline", quiet=TRUE); testthat::test_file("tests/testthat/test-full-pipeline-smoke.R", reporter="summary")'
Rscript --vanilla run_tests.R
git diff --check
shasum -a 256 database/paraguay_macro_pilot.duckdb
```

## Interface examples

```sql
-- Search without hiding status.
SELECT candidate_id,researcher_name,source_id,domain,frequency,
       earliest_period,latest_period,unit_code,currency,validation_tier,concise_warning
FROM catalog.series
WHERE lower(researcher_name) LIKE '%cambio%'
ORDER BY validation_tier,source_id,researcher_name;

-- Profile and preliminary retrieval.
SELECT * FROM catalog.profile('candidate_id_returned_by_the_search');
SELECT * FROM explore.series('candidate_id_returned_by_the_search')
ORDER BY reference_period_start;

-- Formally admitted retrieval.
SELECT * FROM research.series_catalog ORDER BY research_series_id;
SELECT * FROM research.observations_latest_actual
WHERE research_series_id='selected_research_series_id'
ORDER BY reference_period_start;

-- Read every limitation before analysis.
SELECT * FROM catalog.series_warnings
WHERE candidate_id='candidate_id_returned_by_the_search'
ORDER BY warning_code;
```
