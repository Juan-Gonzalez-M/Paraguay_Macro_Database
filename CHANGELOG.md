# Changelog

## v11

- Separated fresh schema bootstrap from versioned data migrations so a new database never executes historical invalidation code.
- Fixed selective concept cleanup in the v9-to-v10 repair and retained unrelated source-specific concepts.
- Expanded legacy `dim_series` tables before migration queries, including the v2 compatibility fixture.
- Added strict annotated-year recognition and ordered-sequence scoring for row and column time axes.
- Added a real `CUADRO 58` regression that excludes false 2033–2098 periods.
- Added selective v10-to-v11 Annex reingestion, dynamic bank-header row accounting and a current v1-to-v11 entry point.

## v10

- Excluded Annex annotation/percentage rows from vertical date axes while allowing the reviewed official projection horizon.
- Rebuilt historical exchange-rate parsing around every consecutive-year block with verified Compra/Venta headers.
- Represented XML-empty formula views with zero content bounds and made all semantic matrix helpers 0 × 0 safe.
- Fixed DuckDB continuity aliases and added an executable two-vintage regression.
- Added canonical deposit/repo block identity to liquidity events and excluded semantic dimensions from measure observations.
- Added selective v9-to-v10 reingestion, a current v1-to-v10 migration entry point and reconstructed regression-audit documentation.

## v9

- Fixed named-table XML discovery by reading the root `<table>` node, restoring all 15 bank/finance reference tables.
- Made empty/formula-only worksheets produce a typed zero-row raw-cell table and hardened exchange-house date propagation.
- Added shape-preserving matrix predicates for regex/equality anchor searches.
- Added the BCP `set` month alias; quarter parsing now rejects naked digits and infers a missing quarter only inside a validated Q1--Q4/annual block.
- Preserved hierarchical credit-survey subquestions such as `10,1` and corrected direct-investment annual/quarter column boundaries.
- Added semantic row-event parsers for interbank operations, LRM tenors and liquidity auctions. Genuine same-day duplicates use deterministic positional lanes that never hash observed values and are explicitly marked `identity_stability = positional_lane`.
- Moved workbook discovery and metadata registration inside per-source failure isolation; a corrupt workbook is persisted as failed while later sources continue.
- Added v8-to-v9 reingestion invalidation, real-file regression tests and a v1-to-v9 migration entry point.

## v8

- Vectorized unit, scale, currency, index-base and total inference over distinct semantic keys while preserving source-specific overrides.
- Replaced per-observation one-row tibbles and growing-list function round trips with lightweight direct record assignment; vectorized the horizontal year-month grid.
- Calculated documented-series hashes once per unique worksheet/path/frequency identity and payment BIC matches once per unique series path.
- Reused one worksheet read for raw content-addressed storage and semantic parsing, eliminating the second full Excel pass for `semantic_table` sources.
- Cached sheet-mode and source-contract configuration with file-change invalidation.
- Added schema-v8 source/stage timings and `outputs/ingestion_stage_timings_latest.csv`.
- Added performance-equivalence tests against the v7 scalar metadata rules and identity contract.

## v7

- Removed inferred unit and currency from documented-series identity; exposed `identity_basis` and `identity_stability`.
- Added prior-vintage series continuity, disappearance thresholds and unit/scale/currency drift errors.
- Added configuration-driven sheet modes, hierarchy-status warnings and coherent non-monetary scales.
- Added 12 sources: ten Excel report sources and two guarded long-format market CSVs.
- Added typed bond-curve and securities-transaction tables plus latest and daily-activity views.
- Added active-cell bounds for every worksheet, chartsheet filtering and a repeated date-block parser for liquidity operations.
- Added registry-derived smoke-test source counts, expanded contracts and a v1-to-v7 migration entry point.

## v6

- Added `dim_concept`, `map_series_concept`, and audited concept views without automatic cross-source equivalence.
- Added guarded reviewed mappings through `config/concept_mappings.csv`.
- Added per-sheet prior-vintage drift diagnostics and `outputs/documented_sheet_drift_latest.csv`.
- Added bounded and occurrence-aware anchor lookup for repeated labels.
- Added a current v1-to-v6 migration entry point and updated compatibility aliases.

## Version 5

- Converted the four remaining inventory-only sources into guarded documented-series sources.
- Added reusable parsers for eight recurring Annex/payment table orientations and specialized credit-survey and exchange-house parsers.
- Added `documented_series_snapshot`, `documented_table_catalog`, `dim_payment_participant` and `dim_exchange_item`.
- Added latest-source views for the Annex, payments, exchange houses and credit survey plus a documented-series catalogue.
- Added source contracts, key-series/unit/entity/range validations, parser-helper tests and full-pipeline coverage assertions.
- Added v4-to-v5 reingestion invalidation and a current `upgrade_v1_to_v5.R` entry point.
- Retained ambiguous units as explicit `source_units` review items rather than inferring harmonized semantics.

## Version 4

- Corrected code 6200 from a false USD interpretation to foreign-currency origin measured in PYG.
- Added `currency_of_origin` and `unit_currency`; retained `economic_currency` only as a corrected deprecated alias.
- Added currency-description consistency validation.
- Replaced brittle exact growth-series counts with minimum baselines and prior-vintage shrinkage checks.
- Changed reference resolution from autogenerated Excel display names to worksheet-plus-column signatures.
- Forced reference cells to text and added raw/canonical account identifiers plus scientific-notation guards.
- Replaced full-copy report-cell ingestion with content-addressed sheet versions and vintage links.
- Added a compatibility view and non-destructive v3 legacy migration for report cells.
- Added schema version 4, migration tests and expanded documentation.

## Version 3

- Fixed worksheet relationship resolution for all workbooks.
- Fixed direct-source schema filtering for bank versus finance-company inputs.
- Standardized report reading on list cells to preserve mixed Excel types.
- Added Excel-epoch and defensive character date conversion.
- Added hard semantic-date plausibility guards.
- Made YAML loading locale-independent with explicit UTF-8.
- Added `publisher`, `source_format` and separate `scale` metadata.
- Added automatic invalidation/reingestion of defective v2 ICC, EVE and FX content.
- Added a version-1-to-version-3 migration and retained the old v2 filename as an alias.
- Added the bank/finance reference workbook as a required, versioned source.
- Added verified entity, currency, statement, ratio, portfolio, account and credit-activity dimensions.
- Added ten documented bank/finance views and mapping-coverage checks.
- Added exact reference-table count/structure tests and a full real-workbook smoke test.
- Corrected FX content-based publication-date inference to use the latest observed month.
- Expanded README, data model, architecture, operations, feedback and verification documentation.

## Version 2

- Added strict structure guards for direct and curated sources.
- Added deterministic content identities, deduplicated archives and consultable vintages.
- Added full snapshots, sparse change/removal events, as-of queries and revision history.
- Expanded FX operations to annual, quarterly and monthly data with subtotal checks.
- Added source transactions, discarded-row records and explicit semantic coverage.
- Added archive reconstruction and review-required semantic spec skeletons.

## Version 1

- Initial folder-based source resolver, raw archive, XML dimension detection, direct tables and three curated parsers.
