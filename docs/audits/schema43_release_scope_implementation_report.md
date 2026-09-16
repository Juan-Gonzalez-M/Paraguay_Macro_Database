# Schema 43 release-input scope implementation and reconciliation

Date: 2026-09-14  
Scope: Schema 43 lineage-only release-input correction  
Engineering verdict: **READY FOR INDEPENDENT ACCEPTANCE**  
Promotion verdict: **NOT PROMOTED; formal acceptance remains external to this session**

## Outcome

Schema 43 now uses an exhaustive, content-addressed release-input scope instead of allowing the
global source registry to determine this product's population implicitly. The final isolated
candidate contains the same canonical facts and series as the frozen incumbent and independently
accepted lineage-fixed candidate. The exact CDA and TCN vintages are preserved and visibly
deferred, with no rows at raw admission, staging, canonical, catalogue-series, exploratory, or
research observation layers.

The normal in-candidate transaction, validation, decision, and active-pointer workflow returned an
accepted internal decision with zero release-blocking errors. `publish = FALSE` retained the file
for independent review and returned before the production swap and artifact-sidecar steps.

## Root cause

`build_current_manifest()` resolved every row in `config/source_registry.csv`. Its
`selection_rule = manifest` branch consulted `config/source_vintages.csv` only when more than one
file matched. Because CDA and TCN were registered `required = TRUE` sources with one current file
each, the official rebuild admitted both automatically. The independently reviewed lineage-fixed
Schema 43 candidate had been migrated from the 22-source incumbent and therefore did not contain
them. The official rebuild consequently used 24 inputs and produced the rejected bundle
`release:549669d609b3dc600b81b9bf`.

The frozen incumbent and accepted lineage-fixed candidate both use the same 22 source hashes. The
rejected artifact adds exactly the two diagnosed vintages and, relative to the lineage-only
population, 28,858 canonical facts and 501 canonical series.

## Explicit product-scope decision

The governed scope is `schema43_lineage_only_20260914`, schema 43, with digest
`7761380c0b4c73dc29759d00f30132574e15558e1ba689bfa50e267d88406dd8`. It has exactly one full-hash
decision for each of the 24 globally registered sources: 22 admissions and these two deferrals:

| Source | Exact vintage | Full SHA-256 | Schema 43 disposition |
|---|---|---|---|
| `cda_curve` | `cda_curve:8796a589fc2bd31317efdce7` | `8796a589fc2bd31317efdce7865d4598473fdacd048cf04b676dc8f78e2b144c` | Deferred for separate onboarding review |
| `tcn_referential_daily` | `tcn_referential_daily:74df666397a33b9c8cdfac10` | `74df666397a33b9c8cdfac10d7ffedd23acf7cbd5907ea21332e100fb939c0a4` | Deferred for separate onboarding review |

This does not alter either source's `required = TRUE` registration, parser, contract, archive,
hash, vintage identity, or future onboarding status. No `config/source_vintages.csv` row was added
and no provenance requirement was relaxed.

## Admission and isolation mechanism

`config/release_input_scope.csv` is a positive, exhaustive scope. The loader validates the exact
column contract, nonblank reviewer/evidence fields, one decision per source, full lowercase
64-character SHA-256 values, controlled dispositions, and one schema version. Resolution then:

1. runs the unchanged global current-source resolver, retaining its `required = TRUE` errors;
2. compares the scope and complete registry in both directions;
3. requires exactly one resolved current vintage with the declared full hash for every decision;
4. emits `release_input_deferred` warnings only for exact deferred bytes;
5. emits release-blocking `release_input_scope_unresolved` errors for missing, changed, duplicate,
   newly registered, or stale decisions; and
6. passes only exact admitted rows to the pipeline.

The scope ID and digest participate in `make_release_id()`, so the 22 admitted hashes receive the
new auditable source-bundle identity `release:dcbccb827b93ee2362ab3c56` rather than reusing the
incumbent's unscoped identity. Ordinary unscoped release-ID behavior remains unchanged.

`run_isolated_update(..., publish = FALSE)` exercises the normal accepted-candidate workflow but
retains the candidate before any production rename. It precomputes the final review pathname so the
candidate's own `audit.distribution_artifacts` row truthfully records
`candidates/accepted_for_review_20260914_202049.duckdb`, not the production pathname.

## Final candidate identity

| Field | Value |
|---|---|
| Candidate | `database/candidates/accepted_for_review_20260914_202049.duckdb` |
| Bytes | 423,374,848 |
| SHA-256 | `6079c80ce0edd26f899b9f54fe98f73eee08c90c5f006759b051960edbd7a9fa` |
| Build / data-release ID | `build:a3e94ab54dacd47000223d28` |
| Source-bundle / deterministic release ID | `release:dcbccb827b93ee2362ab3c56` |
| Attempt ID | `attempt:2305af6de17f489900d0afb8` |
| Schema | 43 |
| Internal decision | accepted |
| Release-blocking errors | 0 |
| Warnings | 41, including 2 explicit deferrals and 1 dirty-tree override |
| Published | false |

Build identity: commit `98370c2c26f8162401cf6e0e3eb3019ef7f687c1`, configuration digest
`85bcc3424f67419908c14006`, code digest `8ea69398fee25228e796d88c`, environment digest
`16bed9afaddb5f23c6f27fd7`, and package-version digest `e85120defdcfd58c70c4f54e`.

The working tree had to remain uncommitted because this task did not authorize commits. The build
therefore used the existing explicit `PARAGUAY_MACRO_ALLOW_DIRTY_BUILD=1` audit path and carries a
`dirty_tree_build_overridden` warning. This candidate is review evidence, not a citable or promoted
research release.

## Population reconciliation

| Artifact | Canonical facts | Canonical series | SHA-256 |
|---|---:|---:|---|
| Frozen incumbent | 1,227,082 | 13,985 | `17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180` |
| Production before and after | 1,227,082 | 13,985 | `17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180` |
| Accepted lineage-fixed Schema 43 | 1,227,082 | 13,985 | `586f2e7af80d54316d45233f1532d03d6f6846d279316d194fa5dbc1d1c26dd8` |
| Rejected 24-source build | 1,255,940 | 14,486 | `e31e444a4ca79cb18f9bc322391562d553a28b179c6cf10e3037b881cb61169b` |
| New scoped candidate | 1,227,082 | 13,985 | `6079c80ce0edd26f899b9f54fe98f73eee08c90c5f006759b051960edbd7a9fa` |

Complete bidirectional `EXCEPT ALL` comparisons returned 0/0 for canonical facts and 0/0 for
canonical series against both the accepted lineage-fixed candidate and the repository-held frozen
incumbent. The latter comparison makes the canonical reconciliation reproducible after the
temporary accepted-lineage artifact is retired. The rejected build exceeds the new candidate by
exactly 28,858 facts and 501 series, matching the rejection diagnosis.

For each of `cda_curve` and `tcn_referential_daily`, all of these counts are zero in the new
candidate: `raw.source_files`, documented staging rows, canonical facts, canonical series,
`catalog.series`, combined `explore.*` observations, and combined `research.*` observations.
`catalog.datasets` retains both discovery rows with `candidate_series = 0`, current observations
`= 0`, and null current vintage/hash, so it does not claim observation availability.

Other verified release results:

- `new_vintage_provenance_incomplete = 0`;
- source-cell natural-key duplicates = 0;
- canonical fact natural-key duplicates = 0;
- 244 worksheet reconciliations, total balance delta = 0, unclassified cells = 0, parser-defect
  cells = 0;
- all error-severity/release-blocking flags = 0;
- 155 stored project views bind from a fresh direct read-only default connection with empty
  `search_path`, with 0 errors; and
- all 7 governed public macros bind under the same conditions, with 0 errors.

The current and archive copies of both deferred inputs still exist and independently re-hash to the
scope values above. Production's active pointer remains `build:57fe1ff64fb654508b2a8f0a` /
`release:748d41036c3a73638a1c2086`. The rejected build's decision remains blocked.

## Verification commands and exit status

Material commands are reproduced here; their complete output is retained in the linked evidence
files.

| Command | Status | Result |
|---|---:|---|
| `find . -name AGENTS.md -print` plus routed `sed`/`rg` inspection | 0 | Root `AGENTS.md` was the only applicable instruction file; relevant code, contracts, tests, and routed docs were read before editing. |
| `git status --short --branch` and read-only `git diff` inspection | 0 | Original untracked release evidence was treated as user-owned; no unrelated tracked diff existed initially. |
| `Rscript --vanilla -e '... test_file("tests/testthat/test-build-isolation.R") ... test_file("tests/testthat/test-release-input-scope.R") ...'` | 0 | Final focused run passed 33 isolation and 41 scope expectations. |
| `PARAGUAY_MACRO_ALLOW_DIRTY_BUILD=1 Rscript --vanilla -e '... build_scoped_current_manifest(...); run_isolated_update(..., publish = FALSE) ...'` | 0 | Final candidate built through the normal isolated transaction/decision workflow; production not replaced. |
| `Rscript --vanilla database/releases/schema43_scope_20260914_implementation/verify_candidate.R` | 0 | `verification_status=PASS`; exact hashes, counts, layer exclusions, keys, reconciliation, interfaces, and preservation verified read-only. |
| `Rscript --vanilla run_tests.R` | 0 | Complete regression suite passed. The sole test warning is the intentional corrupt-ZIP failure-isolation fixture. R also reported two non-failing interrupted-promise teardown warnings and that `testthat` was built under R 4.5.2. |
| `shasum -a 256` over production, rejected artifact, and final candidate; `wc -c` over the same | 0 | Hashes and bytes match this report after build, verification, and regression. |
| `git diff --check` | 0 | No whitespace errors. Test-generated `docs/SCHEMA_MIGRATIONS.md` date churn was restored. |

Superseded diagnostic runs were also preserved rather than hidden:

| Command/run | Status | Disposition |
|---|---:|---|
| First isolated scoped build and verifier | 0 | Produced `accepted_for_review_20260914_195427.duckdb`; post-implementation review found its distribution record named production, so it was superseded and not proposed for acceptance. |
| First complete regression run | 0 | Passed against the pre-artifact-path implementation; retained as `full_regression_pre_artifact_fix.log`, then rerun in full after the correction. |
| First focused isolation run after precomputing the review path | 1 | One assertion found `artifact_path = NA` in a symlinked temporary test root. `repository_uri()` was corrected to canonicalize the existing parent of a prospective leaf, and the focused tests were rerun successfully. |

During adversarial review, the first retained development candidate
`accepted_for_review_20260914_195427.duckdb` was found to carry a false in-database distribution
path naming production. That candidate is preserved but superseded and is not proposed for
acceptance. The wrapper and regression test were corrected; an initial focused test then exposed
macOS `/var` versus `/private/var` canonicalization for prospective paths, which was fixed in
`repository_uri()`. The final focused run, rebuild, verifier, and full suite all passed. Pre-fix
logs and verifier outputs are retained under `evidence/*_pre_artifact_fix.log` and
`pre_artifact_fix/` rather than being rewritten.

## Files changed or created by this implementation

Implementation and governed configuration:

- `config/release_input_scope.csv`
- `run_update.R`
- `scripts/01_utils.R`
- `scripts/06_pipeline.R`
- `tests/testthat/test-release-input-scope.R`
- `tests/testthat/test-build-isolation.R`

Contract documentation:

- `docs/ARCHITECTURE.md`
- `docs/DATA_MODEL.md`
- `docs/DATABASE_STORAGE.md`
- `docs/OPERATIONS.md`
- `docs/audits/schema43_release_scope_implementation_report.md`

New candidate and evidence:

- `database/candidates/accepted_for_review_20260914_195427.duckdb` (superseded development candidate, retained as adverse-review evidence)
- `database/candidates/accepted_for_review_20260914_202049.duckdb`
- `database/releases/schema43_scope_20260914_implementation/review_candidate_manifest.json`
- `database/releases/schema43_scope_20260914_implementation/release_input_scope.csv`
- `database/releases/schema43_scope_20260914_implementation/source_input_manifest.csv`
- `database/releases/schema43_scope_20260914_implementation/verify_candidate.R`
- `database/releases/schema43_scope_20260914_implementation/verification_results.txt`
- `database/releases/schema43_scope_20260914_implementation/evidence/artifact_population_counts.csv`
- `database/releases/schema43_scope_20260914_implementation/evidence/authoritative_build.log`
- `database/releases/schema43_scope_20260914_implementation/evidence/authoritative_build_pre_artifact_fix.log`
- `database/releases/schema43_scope_20260914_implementation/evidence/candidate_counts_by_source.csv`
- `database/releases/schema43_scope_20260914_implementation/evidence/deferred_dataset_discovery.csv`
- `database/releases/schema43_scope_20260914_implementation/evidence/deferred_file_preservation.csv`
- `database/releases/schema43_scope_20260914_implementation/evidence/deferred_input_diagnostics.csv`
- `database/releases/schema43_scope_20260914_implementation/evidence/documented_series_continuity_latest.csv`
- `database/releases/schema43_scope_20260914_implementation/evidence/documented_sheet_drift_latest.csv`
- `database/releases/schema43_scope_20260914_implementation/evidence/documented_source_coverage_latest.csv`
- `database/releases/schema43_scope_20260914_implementation/evidence/full_regression.log`
- `database/releases/schema43_scope_20260914_implementation/evidence/full_regression_pre_artifact_fix.log`
- `database/releases/schema43_scope_20260914_implementation/evidence/ingestion_stage_timings_latest.csv`
- `database/releases/schema43_scope_20260914_implementation/evidence/quality_flags_latest.csv`
- `database/releases/schema43_scope_20260914_implementation/evidence/source_provenance_status.csv`
- `database/releases/schema43_scope_20260914_implementation/evidence/source_provenance_worklist.csv`
- `database/releases/schema43_scope_20260914_implementation/evidence/source_sheet_catalogue_latest.csv`
- `database/releases/schema43_scope_20260914_implementation/evidence/table_reconciliation_latest.csv`
- `database/releases/schema43_scope_20260914_implementation/evidence/update_report.md`
- the eight superseded verifier/source/population files under
  `database/releases/schema43_scope_20260914_implementation/pre_artifact_fix/`

The superseded first candidate and `pre_artifact_fix/` evidence were created during this session and
retained to keep the review finding auditable. No previously existing release directory, accepted
evidence, rejected evidence, source file, archive record, production database, or rejected database
was rewritten.

## Outstanding policy and review items

1. A fresh Codex session with no implementation authority must perform the formal independent
   acceptance. This report is an engineering proposal, not acceptance.
2. The build is deliberately dirty-tree audited because commits were not authorized. A citable or
   promotable product still requires the repository's clean reviewed-commit workflow and a newly
   rebuilt artifact under the resulting code identity.
3. CDA and TCN remain separate future source-onboarding decisions. Their parsers and tests pass, but
   neither source has been economically or provenance-approved by this work.
4. The accepted lineage-fixed comparison file is currently at
   `/private/tmp/schema43-lineage-final.JPitWw/paraguay_macro_schema43_candidate.duckdb`. Its hash and
   direct comparison are captured here; durable reproduction is additionally anchored by complete
   0/0 comparisons against the repository-held frozen incumbent.
5. The acquisition runbook's description of availability evidence and the executable provenance
   gate remain a separate policy inconsistency. No provenance rule was changed or weakened here.

Proposed engineering verdict: **READY FOR INDEPENDENT ACCEPTANCE**. Do not promote this artifact.
