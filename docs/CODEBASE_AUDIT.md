# Codebase audit and organization

Audit date: 2026-09-09

Audited release: schema 41

## Outcome

The repository has a coherent data architecture and a broad regression suite, but its operational
surface had grown organically. The cleanup deliberately preserves the published DuckDB, source
archive, governed CSV registers, migration history, and public SQL contract. It changes code
organization only where behavior can be held constant and tested.

## Findings and actions

| Finding | Risk | Action |
|---|---|---|
| Six entry points and the test helper copied their own script lists. | A new stage could be loaded in one workflow but omitted from another. | Added `scripts/load_project.R`, with named dependency profiles used by update, archive rebuild, review, sign-off, migration, and tests. |
| Numbered filenames do not sort into dependency order. | A contributor could source files lexically and get a partially defined runtime. | The loader is now the authoritative order; numeric names remain unchanged to avoid a high-risk repository-wide rename. |
| The complete schema-40 research-view builder remained after schema 41 replaced and retired those views. | Dead code made the current public contract ambiguous and could accidentally resurrect obsolete views. | Removed the unreachable builder. Historical schema-40 migrations and tests remain because they verify upgrade behavior. |
| The README title still said v40. | Users could mistake the current database contract. | Updated it to v41. |
| The active platform regression file and fixture helper were still named for schema 40. | Test discovery worked, but names misrepresented what was under test. | Renamed the suite and helper for the current research platform; retained genuine schema-40 migration history. |
| Current docs linked to a removed `revisiones/` file. | Readers encountered broken links and competing claims about the authoritative audit. | Pointed current guidance to the consolidated audit, schema-41 baseline, and review workflow; left changelog references untouched as history. |
| Two unreferenced convenience functions survived earlier workflow changes. | They implied supported paths that no entry point or test exercised; one could regenerate a release baseline that is meant to stay frozen. | Removed `register_column_order()` and `write_review_readiness_packets()`; kept the individually invoked review-queue writers and user-facing query helpers. |
| The regression-fixture generator defaulted to a backup filename that no longer exists. | Its documented no-argument invocation always failed, and a future similarly named file could select the wrong comparison release. | Made the historical baseline path a required explicit argument. |
| Platform launchers inherited user/site R profiles. | A local profile could alter a supposedly reproducible unattended run before environment checks begin. | Both shell launchers now call `Rscript --vanilla`. |
| Ignored database recovery files occupy about 4.0 GiB in addition to the published file. | Local storage cost and visual clutter; no source-control impact. | Ran the existing retention policy in dry-run mode. Seven old pre-swap backups (about 2.5 GiB) are eligible; no recovery file was deleted implicitly. |
| Generated outputs, logs, archive copies, candidates, and backups coexist with source files. | A directory listing looks larger and less structured than the tracked product. | Existing directory boundaries and `.gitignore` rules are correct; this document makes their ownership explicit. |

## Canonical entry points

| Purpose | Command | Loader profile |
|---|---|---|
| Build/update and publish if accepted | `Rscript --vanilla run_update.R` | `pipeline` |
| Rebuild into a separate archive-derived database | `Rscript --vanilla rebuild_from_archive.R` | `pipeline` |
| Regenerate economist review packets, read-only | `Rscript --vanilla prepare_review_packets.R` | `research_tools` |
| Draft worksheet review proposals | `Rscript --vanilla worksheet_review.R` | `worksheet_review` |
| Promote signed governance proposals | `Rscript --vanilla sign_off_reviews.R ...` | `governance` |
| Record series-ID continuity between releases | `Rscript --vanilla build_migration_map.R ...` | `migration` |
| Run regression tests | `Rscript --vanilla run_tests.R` | test helper loads `pipeline` |

Standalone operational utilities intentionally load only what they use:
`compact_database.R`, `prepare_distribution.R`, `prune_backups.R`,
`generate_regression_fixtures.R`, and `generate_spec_skeletons.R`.
Fixture regeneration requires an explicit historical baseline database; no retained backup is
silently treated as canonical.
`scripts/upgrade_v1_to_v12.R` is retained as a supported legacy bootstrap referenced by the
migration guide; it is not part of normal schema-41 execution.

## Directory ownership

- `scripts/`: reusable pipeline stages plus the canonical loader.
- `config/`: version-controlled machine-readable contracts and governed decisions.
- `tests/testthat/`: regression and contract tests; fixtures live below `tests/fixtures/`.
- `docs/`: current architecture, operations, research, and governance documentation.
- `input/current/`: operator-supplied current source files.
- `input_archive/`: immutable content-addressed source copies; generated and ignored.
- `database/`: published database and checksum; `backups/` and `candidates/` are local recovery data.
- `outputs/` and `logs/`: generated diagnostics and execution records; ignored except placeholders.

## Retention and deletion policy

Do not infer that an ignored file is disposable. The database itself distinguishes published,
blocked, and historical states, while filesystem backups provide disaster recovery.

```sh
Rscript --vanilla prune_backups.R --keep=3          # dry run
Rscript --vanilla prune_backups.R --keep=3 --apply  # explicit deletion
```

The policy keeps all migration and named milestone copies, keeps the newest three files in each
rolling class, and never removes an unrecognized filename. On the audit date, applying it would
remove seven superseded pre-swap files and retain the newest three plus the blocked candidate.

## Rules for future cleanup

1. Add reusable pipeline code under `scripts/` and add it once to the appropriate loader profile.
2. Add a new profile only when an entry point truly needs a smaller dependency surface.
3. Remove a function only after searches show no caller in code, tests, entry points, or current
   documentation; migration-only code is not dead merely because the live database is newer.
4. Do not commit generated outputs, archive copies, candidates, or rolling backups.
5. Treat changes to `research.*`, configuration schemas, identifiers, and migration functions as
   data-contract changes, not code tidying; they require schema/version review and database rebuild.
