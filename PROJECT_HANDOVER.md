# Paraguay Macro Database — project handover and roadmap

Last updated: 2026-09-12

Current database schema: 41

Repository branch: `empirical-readiness-schema-39`

Purpose: the single authoritative record of project status, completed remediation, open work, and
the recommended path for the next team.

## 1. Executive handover

This repository is a governed R and DuckDB platform for 22 Paraguayan macroeconomic and financial
source families. It preserves original workbooks, source coordinates, hashes, vintages, parser
decisions, release decisions, quality evidence, semantic metadata, and research-facing views.

The engineering platform is operational and strongly auditable. The schema-41 `research` interface
is usable today for its explicitly admitted subset. It must not be described as a complete,
fully harmonized macroeconomic database for Paraguay: most datasets remain provisional, historical
real-time vintages do not yet exist, redistribution rights have not been verified, and most economic
series have not received human semantic review.

The correct claim is:

> This release is a traceable source bank for the 22 included source families, with a governed and
> deliberately limited research interface. `rule_certified` means deterministic structural and
> semantic checks passed; it does not mean an economist signed the series. Provisional data remain
> queryable through lower-level interfaces with explicit limitations.

Never weaken a gate, invent metadata, merge similar-looking series, or label automated evidence as
human review merely to increase coverage.

## 2. Frozen handover baseline

The published artifact inspected for this handover is:

| Item | Value |
|---|---|
| Database | `database/paraguay_macro_pilot.duckdb` |
| Schema | `41` |
| SHA-256 | `17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180` |
| Bytes | `418918400` |
| Active data release/build | `build:57fe1ff64fb654508b2a8f0a` |
| Source bundle | `release:748d41036c3a73638a1c2086` |
| Promoted at | `2026-09-09 11:43:07` |
| Promoted by | `release_gate` |
| Last code-cleanup commit before this handover | `25544e3` |

Current research-surface counts, queried directly from the final DuckDB on 2026-09-12:

| Metric | Count |
|---|---:|
| Source-series events | 1,227,082 |
| Source series | 13,985 |
| Retained source vintages | 22 |
| Certified scalar series | 32 |
| Certification decisions | 110 |
| Research actual observations | 7,498 |
| Research statement observations | 7,500 |
| Collision-free entity-panel rows | 93,217 |
| Corporate-bond curve nodes | 38,922 |
| Securities transactions | 312,329 |
| Rule-certified datasets | 4 |
| Provisional datasets | 18 |
| Open quality flags | 37 warnings, 0 errors |

Verify the artifact from the database directory:

```sh
cd database
shasum -a 256 -c paraguay_macro_pilot.duckdb.sha256
```

The database is tracked with Git LFS. A normal Git clone must also retrieve its LFS objects.

## 3. What has been implemented

### 3.1 Data engineering and provenance

- Content-addressed source vintages and an immutable archive are implemented.
- Source files, worksheets, meaningful cell bounds, formulas, hidden state, and A1 coordinates are
  retained where the format permits.
- Raw, staging, canonical, audit, marts, and research layers are separated.
- Sparse observation events preserve changes and explicit removals.
- Every accepted build records source, code, configuration, environment, platform, and release
  identities.
- Builds run in an isolated candidate DuckDB. A failed or blocked build cannot alter the published
  database; publication is an accepted candidate swap.
- Source-level and release-wide transactions prevent partial publication.
- Current, history, diagnostic, and unfiltered interfaces have explicit release boundaries.
- Portable source/archive URIs and checksums are retained; distribution copies can strip local
  workstation paths.
- Database compaction verifies schema and table contents in both directions before swapping files.

### 3.2 Parser and source-fidelity corrections

- All 22 supplied source families are ingested through guarded contracts.
- Complex Excel sheets use bounded meaningful ranges instead of declared million-row formatting.
- Period-axis detection was repaired for horizontal/vertical years, quarters, months, annotated
  years, consecutive-year blocks, and source-specific layouts.
- Documented observations retain source row and column coordinates where available.
- Source cells inside governed parser regions reconcile to observations or reviewed exclusions.
- Direct financial panels preserve source identifiers as text and use explicit reference mappings.
- Three securities trades with unreported volume are retained as transactions with null volume and
  an explicit status instead of being silently discarded.
- Compensatory-FX duplicate identities and CUADRO 61 extraction defects were corrected and locked by
  golden regression fixtures.
- Source-unit inheritance errors in exchange-rate tables were corrected with reviewed overrides.
- Forecasts/projections are excluded from the default realized interface and remain available in the
  publisher-statement interface.
- Missing observations distinguish blank source cells, absent periods, and source tokens such as
  `s/m`; absence is not silently converted to zero.

### 3.3 Economic and temporal safeguards

- The publisher's original `period` is preserved.
- `period_start` and `period_end` provide normalized reference-period bounds. Monthly research joins
  must use `period_start`, never the source day printed in `period`.
- Scalar time series, entity panels, events, curves, and transactions are modeled at separate grains.
- Units, scale multipliers, currency, stock/flow, nominal/real, seasonal adjustment, transformation,
  hierarchy, timing, valuation, methodology regimes, and comparability have governed fields.
- Unreviewed meanings use explicit sentinel/status values rather than guessed semantics.
- Canonical membership supports effective dates, precedence, overlap policies, replicas, historical
  segments, projections, and methodology breaks.
- Point-in-time macros rank accepted vintage history by availability, but legacy availability is
  explicitly marked as an inferred upper bound.
- Automated certification and human verification are separate assurance paths.

### 3.4 Schema-41 research interface

The stable public surface consists of nine views and one table macro:

- `research.dataset_catalog`
- `research.series_catalog`
- `research.observations_latest_actual`
- `research.observations_latest_statement`
- `research.entity_panel`
- `research.events`
- `research.curves`
- `research.transactions`
- `research.quality_flags`
- `research.observations_as_of(cutoff)`

Every admitted row exposes its assurance level. The current automated rules are versioned in
`config/certification_rules.csv`, and decisions are append-only in
`canonical.certification_decisions`.

### 3.5 Codebase organization and cleanup

- Script dependency order is centralized in `scripts/load_project.R` rather than copied across
  entry points.
- Named profiles cover pipeline, research tools, governance, worksheet review, and migration tasks.
- The obsolete schema-40 research-view builder and two unreachable helper functions were removed.
- The active platform regression suite was renamed for the current research platform.
- Broken documentation links and stale schema-40 labels were corrected.
- Repository tests now check loader consistency, current schema labeling, and local Markdown links.
- Fixture generation requires an explicit historical baseline rather than a missing hard-coded file.
- Shell launchers use `Rscript --vanilla`.
- Generated outputs, archives, candidates, and rolling backups remain outside ordinary Git history.

The detailed schema-by-schema implementation history remains in `CHANGELOG.md`; executable database
migrations remain in `scripts/02_extract_raw.R` and are summarized in
`docs/SCHEMA_MIGRATIONS.md`.

## 4. What is usable now

### Suitable now

- Latest-snapshot analysis using the 32 admitted scalar series.
- Curve-node research using `research.curves`, subject to rights and vintage limitations.
- Transaction-level securities analysis using `research.transactions`; distinguish transaction
  counts from observations with reported volume.
- Banking/finance-company statement analysis using collision-free keys in `research.entity_panel`.
- Source-faithful exploratory work through `main.v_series_research` when the researcher explicitly
  reviews and records the selected definitions, transformations, exclusions, and warnings.
- Parser, lineage, reconciliation, and database-platform research.

### Not suitable yet

- Historical real-time forecasting evaluation or vintage/revision studies.
- Claims about what an analyst knew before the retained current snapshots.
- Treating every source series as an economically distinct canonical concept.
- Combining similarly named or identical-valued series without a reviewed mapping.
- Blind aggregation where hierarchy is unresolved.
- License-assured public redistribution.
- A claim of complete Paraguayan macroeconomic coverage.
- Automatic deflation, seasonal adjustment, interpolation, splicing, growth-rate construction, or
  research-specific transformations. These are intentionally not stored as if source facts.

## 5. Known limitations and open evidence

The 37 current warnings are expected, visible limitations rather than hidden release errors:

| Warning | Rows |
|---|---:|
| `documented_hierarchy_unresolved` | 10 |
| `positional_series_identity` | 7 |
| `positional_lane_series_identity` | 4 |
| `documented_units_need_review` | 3 |
| Each of the following | 1 |

The one-row warnings are `published_identity_incomplete`,
`publication_date_source_contradicts_content`, `known_published_fx_non_additivity`,
`availability_inferred_upper_bound`, `discontinuity_screen`,
`workbook_cached_formulas_and_hidden_state`, `regular_period_gaps`,
`source_provenance_incomplete`, `temporal_convention_mixed`,
`publisher_statement_contains_projections`, `publication_date_inferred_from_content`,
`observation_missingness_recorded`, and `source_region_unreviewed`.

Important interpretation limits:

1. There is only one retained source-file vintage per source. All 22 legacy availability timestamps
   are conservative ingestion bounds, not official historical release times.
2. Eighteen datasets remain provisional. Four are structurally rule-certified; none of the 32
   certified scalar series is currently `human_verified`.
3. Many source series still have unresolved hierarchy, positional identity, units, stock/flow,
   nominal/real, seasonal status, transformation, valuation, or comparability.
4. Equal observation sequences are only evidence for review. They do not prove economic identity.
5. Official landing-page URLs and license status remain incomplete/unverified in the acquisition
   register.
6. Some direct-panel collisions remain excluded rather than aggregated because a missing dimension
   or true duplication has not been adjudicated.
7. Cached formulas and observations from hidden rows are retained and flagged; their presence is not
   itself proof of error.

## 6. Remaining roadmap

### Status of the previously agreed first three steps

1. **Freeze the schema-41 baseline — complete.** The immutable identifiers and counts are preserved
   in section 2 and in `outputs/release_baseline.csv`. The old standalone baseline document was
   consolidated here.
2. **Prepare the flagship economic-review packet — engineering complete, economic review open.**
   The generator and 50-row queue exist. No reviewer identity or decision was fabricated.
3. **Prepare duplicate/canonical resolution evidence — engineering complete, adjudication open.**
   The generator and 1,286-row queue exist. Candidates remain proposals until an economist records
   definition, disposition, dates, precedence, evidence, and sign-off.

This distinction matters: producing a queue is completed engineering work; deciding its rows is
future economic-governance work.

### Priority 0 — preserve continuity from the next publication onward

These actions should begin before additional modeling work because missing vintages cannot be
reconstructed later with certainty.

1. For every new official publication, retain the exact bytes and record:
   official URL, release identifier, official release date, retrieval timestamp, retrieval method,
   checksum, license evidence, and responsible steward.
2. Complete `config/acquisition_contracts.csv` with official landing pages and verified rights.
3. Never overwrite archive content. Replace the relevant file under `input/current/<source_id>/`,
   update `config/source_vintages.csv` when multiple candidates exist, and run the isolated update.
4. Review structure drift, counts, missingness, reconciliation, quality flags, and publication date
   before accepting each release.
5. Preserve every genuine future vintage so `research.observations_as_of()` gradually becomes a real
   point-in-time interface. Do not backfill inferred timestamps as facts.

Owner: data steward plus release engineer. Dependency: access to official publications.

### Priority 1 — complete the first economist-review wave

The evidence packets already exist locally and can be regenerated read-only:

```sh
Rscript --vanilla prepare_review_packets.R
```

This produces:

- `outputs/flagship_review_queue.csv`: 50 high-value scalar candidates.
- `outputs/duplicate_canonical_resolution_queue.csv`: approximately 1,286 duplicate, canonical,
  membership, and panel-resolution candidates.

For each flagship series, confirm from the cited source:

- source label, full heading path, table title, and definition;
- frequency and reference-period convention;
- timing basis and stock/flow status;
- source unit, scale multiplier, and currency;
- nominal/real status, price base, seasonal adjustment, and transformation;
- hierarchy role and parent;
- methodology regime and comparability through time;
- source citation, evidence, reviewer, review date, and remaining questions.

Draft evidence belongs under `config/proposals/`. It has no effect on the database. A reviewed row is
promoted only through `sign_off_reviews.R`, with a named reviewer. High-impact decisions—splices,
deflators, sign conventions, seasonal variants, aggregate identities, and methodology breaks—should
receive independent second-economist review.

Acceptance: all selected rows have complete evidence, no open questions, valid vocabulary, coherent
units/currency/scale, reconciled cells, unique keys, and named non-future sign-off dates. Rebuild from
a clean commit and compare all counts and hashes with the baseline in section 2.

Owner: lead macroeconomist; second economist for high-impact decisions; data engineer for validation.

### Priority 2 — resolve duplicates, canonical identities, and panel collisions

For every candidate, record exactly one disposition:

- `replica`: same economic series repeated by a source; keep lineage, select one primary.
- `historical_segment`: compatible non-overlapping or governed segment of one continuing concept.
- `alternative_definition`: related but economically distinct measure; never splice implicitly.
- `methodology_break`: same broad concept with a non-comparable regime change.
- `exact_duplicate`: duplicate physical panel row with a reviewed canonical row.
- `measure_split`: collision caused by an unmodeled measure dimension.
- `not_duplicate`: observational similarity without economic identity.
- `quarantined`: evidence is inadequate for a safe disposition.

Every canonical mapping requires a definition, source members, relationship, effective dates,
precedence, overlap policy, evidence, reviewer, and review date. Overlapping replicas must agree
within the declared tolerance. A primary must never be selected solely because it is longer or more
convenient.

High-priority cases already identified include repeated IMAEP variants, M2 in CUADRO 29 and its
continuation, TCN/IPC inputs repeated across exchange-rate tables, FX operations repeated in the
Economic Annex, financial-rate tables, and classification-table repetitions. Counterexamples—such
as identical minimum rates in different currencies and repeated balance-of-payments labels under
credit/debit parents—must remain separate.

Panel collisions must be classified in `config/panel_resolution.csv` as an exact duplicate, a
measure split, a missing dimension, or quarantine. Until reviewed, collision-free rows only remain
the correct research interface.

Owner: macroeconomist plus source specialist; data engineer implements only signed decisions.

### Priority 3 — resolve the semantic backlog

Proceed source family by source family, beginning with macroeconomic flagship tables and the most
widely used banking variables:

1. Recover full heading paths and typed parent dimensions for unresolved hierarchies.
2. Resolve source units and scales from titles, footnotes, reference tables, and official metadata.
3. Correct misleading constructed labels without overwriting publisher labels.
4. Review stock/flow, timing, nominal/real, valuation, seasonal adjustment, and transformations.
5. Record methodology regimes, classification concordances, and continuity decisions.
6. Add source-specific accounting identities and acceptable exception/tolerance evidence.
7. Review regular-period gaps and discontinuities; distinguish sparse publication from missing data.
8. Complete source-region decisions for numeric content outside admitted parser regions.

Quarantine is a valid outcome. The target is no unflagged material ambiguity in the research
surface, not artificial 100% coverage.

### Priority 4 — broaden the macroeconomic bank carefully

The current 22 sources do not exhaust Paraguay's macroeconomic data. After the existing sources are
governed, consider official fiscal, debt, labor, national-accounts, price, trade, balance-of-payments,
reserves, monetary, supervisory, and international-comparison sources. Each new source must receive:

- a stable source identifier and owner;
- official acquisition and rights evidence;
- immutable vintage retention;
- exact structural contracts and parser-region accounting;
- source-grain, key, frequency, timing, unit, scale, and missingness declarations;
- continuity and revision policy;
- reconciliation/identity tests;
- dataset disposition and allowed/prohibited uses;
- real-file smoke tests before publication.

Do not add a source merely to increase row counts. Coverage should be measured against an explicit
source manifest and research purpose.

### Priority 5 — optional products after governance

- Searchable catalogue, synonyms, subject taxonomy, and Spanish/English discovery metadata.
- Research-specific transformed marts with formulas and provenance kept separate from source facts.
- Curated seasonal adjustment, deflation, or splicing only under versioned methodologies.
- API or browser interface over the stable research contract.
- Automated scheduled acquisition where official endpoints and rights support it.
- Real-time vintage cubes once sufficient genuine forward history exists.
- Reusable macroeconometric datasets for forecasting, monetary-policy, fiscal, external-sector, and
  banking studies, each with its own variable-selection and transformation manifest.

## 7. Decision rules the next team must preserve

1. Source observations are immutable evidence; curated interpretations are separate records.
2. Similar labels or values never authorize an automatic economic merge.
3. `rule_certified` and `human_verified` are different and must stay visible.
4. Projections never enter the default realized estimation sample.
5. Join regular series on normalized reference periods, not publisher-specific dates.
6. Unknown is not zero. Blank, not reported, no movement, structurally absent, deleted, and rejected
   are distinct states.
7. One current snapshot does not create historical real-time information.
8. A blocked build cannot replace or withdraw the published database.
9. Governance CSVs are machine-readable contracts. Proposals are inert until signed.
10. Public-interface, identifier, grain, unit, and schema changes require migrations and tests; they
    are not ordinary refactoring.
11. No completeness or redistribution claim may exceed the source manifest or license evidence.
12. Preserve source labels, paths, coordinates, hashes, and original periods even when a canonical
    layer supplies cleaner research names.

## 8. Operating the project

### Environment and tests

```sh
Rscript --vanilla -e 'renv::restore()'
Rscript --vanilla run_tests.R
```

`renv.lock` records the intended R/package environment. Do not make test execution install or update
packages. The last full suite run during cleanup passed; its one warning is an intentional corrupt-
ZIP fixture verifying that one discovery failure does not suppress the next source.

### Monthly/current-source update

```sh
Rscript --vanilla run_update.R
```

Before publishing, inspect at minimum:

- `outputs/update_report.md`
- `outputs/quality_flags_latest.csv`
- semantic and documented-source coverage outputs
- structure/sheet drift and series continuity outputs
- reconciliation and source-region worklists
- missingness and workbook-behavior reports
- stage timings and build manifest

A run with any error-severity flag is blocked and must leave the published database unchanged.

### Review and governance commands

```sh
Rscript --vanilla prepare_review_packets.R
Rscript --vanilla worksheet_review.R
Rscript --vanilla worksheet_review.R --expand
Rscript --vanilla sign_off_reviews.R
Rscript --vanilla sign_off_reviews.R --register=series_review --series=<id> --reviewer="Name"
```

Never sign on behalf of a reviewer. The dry-run output must be read before promotion.

### Other supported utilities

```sh
Rscript --vanilla rebuild_from_archive.R
Rscript --vanilla build_migration_map.R <previous_db> <from_release> <to_release> [current_db]
Rscript --vanilla compact_database.R
Rscript --vanilla prepare_distribution.R [output_path]
Rscript --vanilla prune_backups.R --keep=3
Rscript --vanilla generate_regression_fixtures.R <historical_baseline.duckdb>
Rscript --vanilla generate_spec_skeletons.R
```

`scripts/upgrade_v1_to_v12.R` is retained only as a legacy version-1 bootstrap. Normal schema-41
operation does not call it.

### Backup retention

At the 2026-09-12 handover, local ignored recovery data include ten pre-swap backups (about 3.7 GiB)
and one blocked candidate (about 358 MiB). The dry-run policy identifies seven old pre-swap files,
about 2.5 GiB, as eligible while retaining the newest three and the blocked candidate:

```sh
Rscript --vanilla prune_backups.R --keep=3          # inspect only
Rscript --vanilla prune_backups.R --keep=3 --apply  # explicit irreversible deletion
```

These files are not committed. The next operator should decide whether to delete them after checking
that the published database, LFS object, source archive, and any required migration evidence are
recoverable.

## 9. Repository map and maintained documentation

### Code and data

- `scripts/load_project.R`: authoritative dependency order and profiles.
- `scripts/01_utils.R` through `scripts/14_review_readiness.R`: reusable pipeline stages.
- `config/`: version-controlled contracts, registers, rules, and signed decisions.
- `tests/testthat/`: regression, real-file smoke, migration, and public-contract tests.
- `input/current/`: current official inputs; large files use Git LFS.
- `input_archive/`: immutable generated archive, ignored by Git.
- `database/`: published DuckDB/checksum; local backups and candidates are ignored.
- `outputs/` and `logs/`: generated evidence, queues, and runtime records, ignored by default.

### Durable technical references

This handover is the only plan/status document. The following files remain because they describe
live technical contracts in greater depth:

- `README.md`: user entry point and examples.
- `CHANGELOG.md`: chronological implementation record.
- `docs/ARCHITECTURE.md`: pipeline isolation and architectural principles.
- `docs/DATA_MODEL.md`: tables, keys, layers, views, and grains.
- `docs/OPERATIONS.md`: detailed update, recovery, migration, and distribution procedures.
- `docs/ACQUISITION_RUNBOOK.md`: future-vintage collection and provenance.
- `docs/RESEARCH_DATABASE_GUIDE.md`: supported research interface and assurance meanings.
- `docs/TEMPORAL_CONTRACT.md`: original versus normalized periods and safe joins.
- `docs/CONCEPT_GOVERNANCE.md`: concept and canonical-mapping controls.
- `docs/DOCUMENTED_SOURCES.md`: parser families and source-specific behavior.
- `docs/SEMANTIC_REFERENCE.md`: bank/finance reference mappings.
- `docs/DATABASE_STORAGE.md`: DuckDB growth, compaction, and backup retention.
- `docs/SCHEMA_MIGRATIONS.md`: generated executable migration summary.

Superseded audit/plan/workbook documents were consolidated into this file and removed on purpose.
Use Git history if their original wording is ever required; do not restore them as parallel plans.
The historical pilot verification narrative was also removed: its maintained acceptance targets are
executable tests, while corrected outcomes and restart verification are recorded here and in the
changelog.
Some signed configuration evidence in `config/unit_overrides.csv` cites the filename of a historical
audit. Those citations are intentionally left byte-for-byte unchanged so the governed configuration
continues to match the published build; the cited document remains recoverable from Git history and
its substantive correction is summarized in section 3.2.

## 10. Restart checklist for the next team

1. Clone the repository and check out `empirical-readiness-schema-39` unless it has been merged.
2. Run `git lfs pull` and verify the DuckDB sidecar checksum.
3. Restore `renv.lock` and run the complete test suite.
4. Read this handover, `README.md`, the research guide, architecture, operations, acquisition, and
   temporal contract before changing data behavior.
5. Query `research.dataset_catalog`, `research.quality_flags`, and the active release directly; do
   not assume the counts in this frozen section still describe a later release.
6. Confirm source ownership, economist-review authority, release authority, and license-review
   responsibility by name.
7. Start forward vintage acquisition immediately.
8. Regenerate the two review queues read-only and select a small, high-value review wave.
9. Commit evidence/configuration changes separately from pipeline code where practical.
10. Rebuild only from a clean commit; inspect all gates; record the new checksum, release IDs, count
    changes, approved limitations, and reviewers in this handover.

## 11. Suggested ownership and release approval

Minimum roles:

- Data steward: acquisition, provenance, archive, source manifest, and rights evidence.
- Source economist: definitions, timing, units, hierarchy, comparability, and methodology regimes.
- Independent economist: high-impact canonicalization and transformation decisions.
- Data engineer: parsers, migrations, tests, keys, performance, and publication isolation.
- Release approver: confirms evidence and limitations; does not substitute for source review.

For each new release record:

```text
Release/build identifier:
Database/schema version:
Database SHA-256 and bytes:
Source bundle/manifest:
Git commit and environment digest:
Changed source vintages:
Research-interface count changes:
Quality errors/warnings:
Reviewed semantic/canonical decisions:
Known limitations and quarantines:
License/redistribution status:
Lead economist approval/date:
Independent economist approval/date where required:
Data engineer approval/date:
Release approver/date:
```

## 12. Definition of longer-term completion

The platform may be called a generally usable research data bank for its declared source universe
when:

- every included source and worksheet/region has an admitted, provisional, excluded, or quarantined
  disposition with evidence;
- the public catalogue and observation grains remain unique and fully traceable;
- material units, scales, timing, stock/flow, hierarchy, transformations, and comparability are
  human-reviewed or visibly excluded;
- duplicate, canonical, continuity, panel-collision, and methodology-break decisions are complete
  for the published research surface;
- genuine forward vintages and official availability metadata support the intended point-in-time
  claims;
- official rights and redistribution conditions are known;
- all automated gates pass from a clean, reproducible build;
- the release statement names the exact source manifest and does not overstate national coverage.

Even then, each empirical project must document its own variable selection, transformations,
sample, identification assumptions, and econometric validation. A canonical data bank can prevent
many data errors; it cannot pre-authorize every research design.
