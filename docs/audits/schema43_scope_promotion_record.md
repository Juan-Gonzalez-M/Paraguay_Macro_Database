# Schema 43 scoped-candidate promotion record

Date: 2026-09-16  
Status: **PROMOTED SUCCESSFULLY**

## Authorized transition

| Item | Identity |
|---|---|
| Retained candidate | `database/candidates/accepted_for_review_20260914_202049.duckdb` |
| Candidate SHA-256 | `6079c80ce0edd26f899b9f54fe98f73eee08c90c5f006759b051960edbd7a9fa` |
| Candidate bytes | 423,374,848 |
| Build | `build:a3e94ab54dacd47000223d28` |
| Source bundle | `release:dcbccb827b93ee2362ab3c56` |
| Attempt | `attempt:2305af6de17f489900d0afb8` |
| Scope digest | `7761380c0b4c73dc29759d00f30132574e15558e1ba689bfa50e267d88406dd8` |
| Incumbent SHA-256 | `17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180` |

The earlier bounded attempt stopped correctly because the only filesystem publisher was embedded in
the same `run_isolated_update()` invocation that created a transient `candidate_*.duckdb`.
`publish = FALSE` deliberately returned after retaining `accepted_for_review_*.duckdb`, and no
supported entry point could resume the lock, incumbent check, backup, atomic swap, sidecar, manifest,
or rollback stages for those already reviewed bytes. The ordinary publish branch also wrote an
inherited-artifact row into its transient candidate before swapping; doing that to this retained
artifact would have changed its authorized SHA-256.

## Implemented mechanism

`scripts/06_pipeline.R` now exposes `promote_retained_candidate()` and a shared internal
`publish_candidate_atomically()` used by both it and `run_isolated_update()`. Retained promotion:

1. accepts an explicit candidate path, candidate SHA-256 and byte count, incumbent SHA-256, build,
   source-bundle, attempt, schema, optional release-scope, and optional population counts;
2. accepts only a direct `accepted_for_review_*.duckdb` child of `database/candidates/`;
3. verifies the DuckDB audit tables, accepted immutable decision, active in-candidate pointer,
   completed attempt, zero release errors, governed artifact path, admitted source hashes, scope
   digest, and canonical counts through read-only connections;
4. takes the existing update lock, refuses WAL or interrupted-swap state, and rechecks the incumbent
   before and immediately after staging;
5. stages a byte-identical copy while preserving the authorized candidate, then uses the same
   marker-protected backup and rename implementation as the normal build-and-promote path;
6. opens production through a fresh read-only connection, verifies the active accepted release and
   binds principal `catalog`, `explore`, and `research` objects;
7. automatically moves a failed promoted artifact aside and restores the exact incumbent if the
   candidate rename or smoke test fails; and
8. writes the established SHA-256 sidecar, build manifest, append-only run log, and a compact durable
   JSON record under `database/releases/promotions/`.

The exact candidate remains immutable; its byte-identical staged copy is what crossed the shared
atomic rename boundary. No database table, source observation, parser, release scope, or semantic
decision was changed by promotion.

## Verification before promotion

The following focused and adjacent regression subset passed immediately before promotion:

| Command | Result |
|---|---|
| `testthat::test_file("tests/testthat/test-build-isolation.R")` | PASS; 55 expectations |
| `testthat::test_file("tests/testthat/test-release-isolation.R")` | PASS; 35 expectations |
| `testthat::test_file("tests/testthat/test-publication-safety.R")` | PASS; 34 expectations |

The focused fixtures demonstrated accepted retained promotion, wrong candidate-hash refusal, stale
incumbent-hash refusal, incomplete-DuckDB refusal, smoke-failure rollback, unchanged retained-source
bytes, use of the common publisher by `run_isolated_update()`, and explicit repeated-invocation
refusal. All destructive and failure-path tests used temporary roots. The two adjacent files emitted
only the pre-existing non-failing interrupted-promise teardown warning; packages also reported that
some were built under R 4.5.2.

A final read-only call to `validate_retained_candidate()` passed for the exact authorized artifact.
Immediately afterward `shasum -a 256` still reported the authorized candidate and incumbent hashes,
the candidate byte count was 423,374,848, no update lock or swap marker existed, and 44 GiB was
available. The complete regression suite and database build were not rerun: the task requested the
smallest relevant subset and no ingestion, schema, identity, public-interface definition, or data
content changed.

## Promotion command and result

Promotion was executed through `scripts/load_project.R` and
`promote_retained_candidate(...)`, passing every identity in the table above plus scope ID
`schema43_lineage_only_20260914`, canonical facts `1,227,082`, and canonical series `13,985`.

Result:

- production SHA-256:
  `6079c80ce0edd26f899b9f54fe98f73eee08c90c5f006759b051960edbd7a9fa`;
- prior production backup:
  `database/backups/paraguay_macro_pilot_pre_swap_20260916_174257.duckdb`;
- backup SHA-256:
  `17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180`;
- durable promotion record:
  `database/releases/promotions/build_a3e94ab54dacd47000223d28_20260916_174303.json`;
- retained candidate after promotion: present, 423,374,848 bytes, and still
  `6079c80ce0edd26f899b9f54fe98f73eee08c90c5f006759b051960edbd7a9fa`;
- swap marker and update lock after promotion: absent.

## Post-promotion read-only verification

A fresh direct DuckDB connection with no configured search path verified:

- exactly 1,227,082 canonical facts and 13,985 canonical series;
- active build `build:a3e94ab54dacd47000223d28`;
- active source bundle `release:dcbccb827b93ee2362ab3c56`;
- active attempt `attempt:2305af6de17f489900d0afb8`;
- accepted status, schema 43, and zero release errors;
- all 17 `catalog.*`, `explore.*`, and `research.*` tables/views bound with `LIMIT 0`, with zero
  binding errors;
- `catalog.datasets` retained one discovery row for each of `cda_curve` and
  `tcn_referential_daily`, both with zero candidate series, zero current observations, and null
  current vintage/hash;
- CDA and TCN returned zero rows in canonical series, canonical facts, all `explore.*` observation
  carriers, and all `research.*` observation carriers; and
- the pre-swap backup opened read-only and retained active build
  `build:57fe1ff64fb654508b2a8f0a` / source bundle
  `release:748d41036c3a73638a1c2086`.

The implementation-evidence directory was not written by the promotion code. Its post-promotion
aggregate SHA-256-of-file-checksums is
`d85a811c4b862efc0efd67a4b1f03415e69c0e6bdb46fd57d927397ef8cec10a`; the retained candidate and
the evidence referenced by its existing manifest remain in place. The candidate mtime remains
2026-09-14 20:21:55 -03, and the newest implementation-evidence mtime remains on 2026-09-14, before
this promotion task. One first post-check shell command
had an R quoting syntax error after it had already printed the active identity, counts, 17 successful
interface bindings, and the two discovery rows; it made no writes. The deferred-source and backup
queries were rerun separately and passed.

## Files changed by this promotion task

- `scripts/06_pipeline.R`
- `tests/testthat/test-build-isolation.R`
- `docs/ARCHITECTURE.md`
- `docs/DATABASE_STORAGE.md`
- `docs/OPERATIONS.md`
- `docs/audits/schema43_scope_promotion_record.md`
- `database/paraguay_macro_pilot.duckdb`
- `database/paraguay_macro_pilot.duckdb.sha256`
- `outputs/build_manifest.json`
- `database/backups/paraguay_macro_pilot_pre_swap_20260916_174257.duckdb`
- `database/releases/promotions/build_a3e94ab54dacd47000223d28_20260916_174303.json`
- the append-only September update run log under `logs/`

All other pre-existing tracked and untracked changes were preserved. The only material limitation is
operational: retained candidates and governed backups accumulate and remain subject to the documented
retention policy; the full regression suite was not rerun for this narrowly scoped release-path
change.

Final status: **PROMOTED SUCCESSFULLY**
