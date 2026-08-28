# Data model

## Identity and provenance

- `sha256`: hash of exact workbook bytes.
- `vintage_id`: deterministic `source_id:hash-prefix`.
- `release_id`: deterministic hash of all source hashes in one update bundle.
- `publication_date`: filename date or guarded content date; never the execution clock.
- `executed_at`: operational timestamp.
- `publisher` and `source_format`: explicit source-registry attributes retained in `source_files`.

`source_files` has one row per distinct source content. `release_sources` is the many-to-many bridge between deterministic update bundles and source vintages. `source_sheets` records both Excel’s declared dimensions and XML-derived first/last meaningful cells; `reference_table_loads` records named semantic tables.

`ingestion_stage_timings` has grain `release × source vintage × stage`. It is operational telemetry only: elapsed time never enters a content, vintage, release or series identity. Re-running the same deterministic release replaces its timing rows while preserving statistical history.

## Statistical series

Curated snapshot tables retain a complete publication by `vintage_id`. `fact_series_events` is sparse: a row is added only when a series-period value appears, changes, or disappears from a later full-history publication. Disappearances are tombstones (`is_deleted = TRUE`). `series_revisions` records the corresponding old and new values.

`v_series_latest` selects the newest event and suppresses tombstones. `series_as_of()` performs the same resolution after a publication-date cutoff.

`dim_concept` is deliberately separate from `dim_series`. `map_series_concept` records whether a relationship is merely the generated source identity or a reviewed mapping supported by evidence. `v_series_concept_catalogue` exposes the audit trail; `v_concept_latest` never aggregates mapped series automatically.

`documented_sheet_drift` compares the parsed observation and series counts of each complex worksheet with its previous completed vintage. This makes a missing or truncated sheet visible even when the total workbook row count happens to increase elsewhere.

`documented_series_continuity` compares the set and metadata of series identities with the preceding completed source vintage. It retains every new, disappeared or metadata-changing identity, including labels and whether positional disambiguation was used.

`dim_series` keeps `unit` and `scale` separate. For example, FX values use `unit = USD` and `scale = millions`; this avoids encoding magnitude inside the economic unit.

## Documented series identity

A documented `series_id` is `source_id : worksheet_slug : hash(stable_path | frequency)`, and `identity_basis` is `worksheet | frequency | stable_path`.

The worksheet slug is produced by `documented_sheet_slug()`, which applies `janitor::make_clean_names()` to one sheet name at a time. Applying it to a vector would uniquify duplicates by position (`datos`, `datos_2`, … `datos_26`), which would make identity depend on where a series happened to fall in the identity table rather than on the sheet it came from: inserting one column upstream would silently reassign every later series in that sheet.

The worksheet that participates in identity is not always `source_sheet`. When `config/sheet_modes.csv` declares a `continuation_group` for a source or sheet, that value is used instead — for publishers that split one continuous series across several worksheets, such as `bcp_fx_daily`, which publishes one worksheet per year. `source_sheet`, `source_row` and `source_column` remain untouched on every observation, so the annual worksheets stay addressable as aliases and per-sheet drift, continuity and raw-cell lineage are unaffected.

When a label repeats within a sheet, the identity guard appends a structural slot drawn from the axis that is *not* the period axis: the source row for horizontal layouts (periods across columns) and the source column for vertical ones. `documented_period_axis_is_horizontal()` is the single place that decides this. Using the wrong axis pins the period and turns each column into a one-observation series.

## Research-readiness gate

`table_status` carries one reviewed status per source table, loaded from `config/table_status.csv`: `validated`, `provisional`, `needs_remodeling` or `quarantined`. `v_series_table_status` resolves each series to its status, matching an exact `(source_id, source_sheet)` row first and falling back to the source-level `*` row; curated sources with no worksheet grain always match the wildcard.

`v_research_series` exposes only `validated` tables. That status is a claim about economic review — definitions, units, period conventions, hierarchy — and no automated check can grant it, so `apply_table_status()` requires a named reviewer and a review date for every validated row. `validate_database()` raises a release-blocking `table_status_incomplete` error if a source or worksheet reaches the catalogue without a declared status, so the research surface cannot expand silently.

## Documented complex-report model

`documented_series_snapshot` has grain `vintage × series × period`. It normalizes semantic-table Excel sources while retaining `source_sheet`, `source_row`, `source_column`, original period label, parser mode and source file. `identity_basis`, `identity_stability` and `hierarchy_status` expose identity and aggregation risk. `identity_stability = positional_lane` identifies multiple same-period source events that have equal published dimensions and no official operation key; deterministic occurrence order distinguishes them, while observed values are excluded from identity. `documented_table_catalog` records one audit row per worksheet, including parsed observations, series count, date coverage, units and hierarchy status.

The principal access views are:

| View | Grain and purpose |
|---|---|
| `v_economic_annex_latest` | Latest Annex series-period observations from 93 statistical sheets |
| `v_payments_latest` | Latest payment series-period observations, enriched where a BIC identifies a participant |
| `v_exchange_houses_latest` | Latest verified entity-item-period balance-sheet, ratio and operating observations |
| `v_credit_survey_latest` | Latest quarterly response shares and sector/general credit indices |
| `v_documented_series_catalogue` | Current series definitions and period coverage |

The additional market tables retain their natural grains:

| Object | Grain |
|---|---|
| `bond_curve_snapshot` | vintage × date × currency × risk rating × maturity |
| `securities_transactions_snapshot` | vintage × deterministic transaction identity |
| `v_securities_daily_activity` | date × currency × instrument × market × operation type × venue |

`dim_payment_participant` is sourced from the official BIC sheet. `dim_exchange_item` identifies the published exchange-house item hierarchy. Unknown unit metadata is stored as `source_units`; it is an explicit non-harmonized state and must not be aggregated across series without review.

## Financial panel model

Bank and finance-company observations remain source-aligned panel tables. Their stable grain is typically:

| Family | Grain |
|---|---|
| EEFF | vintage × date × entity × report item × currency |
| Ratios | vintage × date × entity × ratio |
| Carteras | vintage × date × entity × portfolio item × currency |
| Crédito sector | vintage × date × entity × source sector × currency |
| Crédito actividad | vintage × date × entity × detailed activity × currency |

Semantic dimensions enrich those panels:

- `dim_entity`: type-safe code, legal name, short name and ownership type;
- `dim_currency`: bulletin code and label, `currency_of_origin` (the denomination of the underlying operation) and `unit_currency` (the unit in which the reported amount is measured). `economic_currency` is a deprecated compatibility alias of `unit_currency`;
- `dim_statement_item`: published EEFF hierarchy and report code;
- `map_statement_account`: one-to-many underlying account definitions and signs;
- `dim_ratio`: published ratio hierarchy;
- `dim_portfolio_item`: published portfolio hierarchy;
- `map_portfolio_account`: underlying portfolio accounts;
- `dim_credit_activity`: 1,112 detailed activities and their bulletin-sector concordance.
- `dim_credit_sector`: 13 shared bulletin sectors linking aggregate and detailed credit views.

The `v_banks_*_documented` and `v_financial_*_documented` views preserve all raw fields and append verified semantic keys and labels. Semantic hierarchy fields use the `semantic_` prefix when a raw column has the same name.

For the current bulletins, code `6900` represents operations in PYG measured in PYG. Code `6200` represents foreign-currency operations converted and reported in PYG. Therefore `6200` has `currency_of_origin = FX` and `unit_currency = PYG`; it must never be interpreted or aggregated as a USD amount.

## Deduplicated report cells

- `report_sheet_versions` stores one content hash and metadata row per distinct source worksheet content.
- `report_cell_values` stores physical cell values once per sheet version.
- `report_sheet_vintages` links every source vintage and worksheet to its content version.
- `report_cells` is a compatibility view that expands links back to the original vintage-sheet-cell grain.

Databases upgraded from v3 retain previous full copies in `report_cells_legacy`; the compatibility view unions those rows with new sparse storage. No historical rows are discarded.

## Entity identity

`entity_id` combines institution type and source code, so `bank:2081` and `finance_company:2081` cannot collide. Current names come from the verified reference workbook. `config/entity_dictionary.csv` remains a fallback scaffold for historical codes not present in the current reference; blank fallback names are explicitly marked unavailable.

## Coverage statuses

- `curated`: guarded dates, units and statistical-series identities.
- `documented_panel`: structured panel joined to verified semantic dimensions.
- `reference_dimension`: versioned semantic-reference source.
- `documented_series`: guarded series identity derived from a documented table orientation while retaining source coordinates.
- `curated_long_format`: guarded typed CSV at its natural published grain.
- `source_units` is a unit review state, not a coverage status.

These statuses describe meaning, not file-read success. Ingestion status is tracked separately in `source_files.ingestion_status`.
