# Project purpose

This repository builds a research-grade DuckDB database from official Paraguayan macroeconomic and financial publications. Changes must preserve source fidelity, reproducibility, provenance, temporal integrity, semantic caution, and publication safety.

# Non-negotiable invariants

- Use `scripts/load_project.R` as the authoritative script loader. Numeric filenames do not define execution order.
- Treat source content as immutable and content-addressed. Never rewrite a vintage, substitute filenames or modification times for SHA-256 identity, or treat a code rebuild as a new statistical vintage.
- Preserve publisher values, labels, dates, codes, worksheet names, significant whitespace, and source coordinates. Put corrections or interpretations in explicit parser, override, mapping, review, or migration layers.
- Keep raw evidence, parser output, canonical semantics, audit evidence, marts, research interfaces, and compatibility views conceptually separate. Do not bypass a layer to make data appear research-ready.
- Never silently discard source content. Every claimed source cell or delimited row must become an observation or receive an explicit, governed classification or rejection reason.
- Preserve `period` as published and use `period_start` or `period_end` for normalized alignment. Keep units, scale, currency, frequency, stock/flow, valuation, adjustment, and transformation distinct; never silently choose a temporal convention or rescale, aggregate, splice, interpolate, deflate, seasonally adjust, or derive growth rates.
- Do not infer economic equivalence, canonical membership, continuity, precedence, or duplicate disposition from labels or matching values. These require governed evidence and, where specified, human review.
- Never present derived metadata or `rule_certified` assurance as human verification. Worksheet validation and series-level economic review are independent.
- Preserve observations, publisher projections, missingness states, revisions, and deletion tombstones as distinct concepts.
- Preserve declared natural grains and source rows. Do not collapse duplicates or collisions merely to satisfy an analytical key.
- Respect public-interface scope. Staged or blocked data must not leak into current or research views; `_all` and diagnostic interfaces are not default research interfaces.
- Build and migrate through the existing candidate, transaction, release-decision, and active-pointer mechanisms. A failed or blocked build must not alter the published database, and an accepted or blocked product decision must not be rewritten.
- Do not silently weaken guards, constraints, reconciliation, provenance, review requirements, migrations, or public-view contracts to make a build pass.
- Stored views and macros must use schema-qualified project dependencies and work from a fresh default DuckDB connection.

# Working rules

- Before editing, inspect the relevant executable code, configuration contracts, tests, and routed documentation.
- When documentation and executable behavior disagree, use executable behavior to describe the current implementation, but do not silently treat it as intended policy. Report the inconsistency before changing semantics.
- Make the smallest change consistent with the requested outcome. Do not combine parser repair, semantic review, historical correction, or schema migration unless each is required and supported by evidence.
- Treat governed CSV/YAML changes as data or economic decisions, not formatting work. Preserve column order, controlled vocabularies, reviewer fields, evidence, and exact source identifiers.
- A parser change must retain raw lineage, define its accepted region and rejection behavior, and make unexplained shrinkage, duplication, or identity movement visible.
- If published series identifiers can move, use the existing migration machinery and account for every prior identifier.
- If a task requires an economic judgment not established by the source or an authorized review record, leave the state explicit and unresolved.
- Do not manually edit the published DuckDB artifact as an implementation shortcut. Use the appropriate pipeline, migration, compaction, or distribution workflow.
- Preserve unrelated user changes and generated evidence. Do not regenerate review baselines or sign off review decisions unless explicitly requested.

# Documentation routing

Consult the following before these classes of changes:

- Pipeline order, ingestion architecture, parser extension, or publication isolation: `docs/ARCHITECTURE.md`
- Schemas, identities, revisions, missingness, reconciliation, and layer ownership: `docs/DATA_MODEL.md`
- Period construction, frequency handling, joins, or temporal validation: `docs/TEMPORAL_CONTRACT.md`
- Concepts, semantic fields, mappings, or human review: `docs/CONCEPT_GOVERNANCE.md` and `docs/SEMANTIC_REFERENCE.md`
- Stable research views, assurance levels, or analytical use: `docs/RESEARCH_DATABASE_GUIDE.md`
- Acquisition, availability evidence, vintages, or real-time claims: `docs/ACQUISITION_RUNBOOK.md`
- Database replacement, backups, compaction, or distribution: `docs/DATABASE_STORAGE.md` and `docs/OPERATIONS.md`
- Schema changes or identifier migration: `docs/SCHEMA_MIGRATIONS.md`
- Public view or macro changes: `config/public_view_contract.csv`
- Source-specific parser work: the source registry row and applicable contracts or specifications under `config/`

# Verification before completion

- Run focused tests for every changed behavior.
- Run the full regression suite for changes affecting shared infrastructure, ingestion, schemas, identifiers, publication logic, or public interfaces, unless execution is genuinely unavailable. If it is not run, state that explicitly.
- For ingestion or schema changes, validate on an isolated database or candidate; never use the published database as a test target.
- Verify affected natural keys, row or cell accounting, provenance, temporal bounds, semantic evidence, release boundaries, and public-interface scope.
- For parser changes, check representative real source coordinates and confirm that accepted, rejected, and excluded content reconciles.
- For view or macro changes, test from a fresh read-only connection without setting `search_path`.
- For identifier-affecting changes, verify migration coverage for every previously published identifier.
- For release-path changes, verify that failure leaves the published database byte-for-byte unchanged and that only an accepted product can become active.
- For any change affecting series meaning, units, frequency, temporal alignment, transformations, or research eligibility, check explicitly for unintended changes in economic interpretation.
- Confirm documentation and executable contracts remain consistent where the change alters user-visible behavior.
- Inspect the final diff for accidental database, archive, generated-output, review-register, or unrelated changes. Do not declare completion while relevant error-severity checks fail.
