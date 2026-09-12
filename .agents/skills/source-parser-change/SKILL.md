---
name: source-parser-change
description: Repair, extend, refactor, or diagnose a source-specific Excel or CSV ingestion parser, including onboarding a new source when new parser logic is required, parser regions, period axes, row or cell classification, source coordinates, parser-driven identities, and extracted metadata. Use when workbook drift clearly requires parser remediation. Do not use for ordinary database audits, acquisition or new vintages handled by an existing parser, release review, purely economic review, or unrelated R refactoring.
---

# Source parser changes

Follow the repository `AGENTS.md`. Preserve source fidelity, raw lineage, reproducibility, temporal integrity, semantic caution, and publication isolation.

## Establish scope

1. Identify the source family and its row in `config/source_registry.csv`.
2. Determine its ingest mode, executable parser path, configuration contracts, and focused tests.
3. Read the routed project documentation before editing:
   - `docs/ARCHITECTURE.md`
   - `docs/DOCUMENTED_SOURCES.md`
   - `docs/DATA_MODEL.md`
   - `docs/TEMPORAL_CONTRACT.md` when periods, frequencies, or alignment may change
   - semantic, acquisition, migration, or public-interface documentation only when those concerns are implicated
4. Inspect the applicable source contracts or specifications under `config/`, including region, rejection, grain, override, and reconciliation registers where relevant.
5. Use `scripts/load_project.R` as the authoritative loader. Do not infer execution order from numeric filenames.

## Diagnose before changing

Inspect representative real source evidence, including worksheet or CSV structure, publisher labels, raw values, significant whitespace, formulas or hidden state where relevant, and exact source coordinates.

Determine whether the issue belongs in:

- generic parser logic;
- source-specific parser logic;
- governed configuration;
- an explicit metadata override;
- semantic or economic review;
- identifier migration.

Do not encode an unresolved economic judgment in parser logic. Do not infer semantic equivalence to preserve an identifier. Escalate unresolved semantic or policy questions.

Define the parser's accepted region and the explicit treatment of content outside or rejected from it. Every claimed source cell or delimited row must become an observation or receive a governed classification or rejection reason.

Before implementation, examine implications for:

- published period and normalized period bounds;
- frequency and temporal convention;
- declared natural grain and duplicate behavior;
- series and event identity;
- unit, scale, currency, and other extracted metadata;
- source row, column, sheet, file, vintage, and hash provenance;
- continuity with previously published identities;
- current, diagnostic, and research-interface scope.

## Implement narrowly

Make the smallest justified change in the correct layer. Preserve publisher-facing evidence and raw lineage.

Never:

- weaken structure guards, validation, reconciliation, or release gates to make the parser pass;
- silently discard source content;
- rewrite or reinterpret immutable source evidence;
- collapse collisions merely to satisfy an analytical key;
- combine parser repair with semantic review, historical correction, or schema migration unless each is required and supported by evidence.

Add or update focused regression evidence where appropriate. Prefer assertions against representative real coordinates, accepted and rejected content, natural keys, period behavior, and stable parser signatures. Do not regenerate governed baselines or review decisions without explicit authorization.

## Validate

Use an isolated database or build candidate; never test ingestion changes against the published database.

Verify, as applicable:

1. accepted, rejected, excluded, and out-of-region content reconcile;
2. representative observations retain correct source coordinates and provenance;
3. natural keys and declared grain are preserved;
4. published periods and normalized bounds remain correct;
5. identities, metadata, and prior-vintage continuity change only as justified;
6. quality flags expose shrinkage, duplication, identity movement, and unexplained content;
7. staged or blocked data do not enter current or research interfaces;
8. no unintended economic interpretation or assurance change occurred.

If published series identifiers moved, use the existing migration machinery and account for every previously published identifier.

Run focused tests for every changed behavior. Because parser changes affect ingestion, also run the full regression suite unless execution is genuinely unavailable; report any omission explicitly.

Inspect the final diff for accidental database, archive, generated-output, governed-review, baseline, or unrelated changes. Do not declare completion while relevant error-severity checks fail.
