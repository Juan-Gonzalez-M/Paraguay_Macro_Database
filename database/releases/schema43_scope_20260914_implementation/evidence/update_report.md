# Paraguay macro database — update report

**Published.** This build (`build:a3e94ab54dacd47000223d28`) was accepted and is the database at `database/paraguay_macro_pilot.duckdb`. The build it replaced is retained under `database/backups/paraguay_macro_pilot_pre_swap_*.duckdb`.

Deterministic release: release:dcbccb827b93ee2362ab3c56

Build: build:a3e94ab54dacd47000223d28

## Source vintages

- **bank_reference** — `Referencias_bancos_financieras.xlsx`; vintage `bank_reference:cd800f82e64f8f2a0b65eea7`; publication date `unknown` (pending_content_inference); status `completed`
- **banking_indicators** — `IDB_JUN26.xlsx`; vintage `banking_indicators:c57dc0f6a422ac9e54dafccd`; publication date `2026-06-30` (filename); status `completed`
- **banks** — `1.1 Tablas Boletín Bancos Jul26 1.xlsx`; vintage `banks:3809900872e5af28e11ae86e`; publication date `2026-07-31` (filename); status `completed`
- **bcp_fx_daily** — `Compra_Venta de Divisas del BCP_2026 (1).xlsx`; vintage `bcp_fx_daily:a45bea1e1508bb019befcac9`; publication date `2026-08-14` (content_max_period); status `completed`
- **compensatory_fx_sales** — `Ventas Compensatorias_Ventas Complementarias_2026.xlsx`; vintage `compensatory_fx_sales:474d8c47b1ad9622b1bb8b29`; publication date `2026-07-31` (content_max_period); status `completed`
- **corporate_bond_curves** — `Curvas Bonoc Corporativos.csv`; vintage `corporate_bond_curves:e5d5a3a5c3e2b00d96d76a11`; publication date `2026-07-31` (content_max_period); status `completed`
- **credit_survey** — `Estadística Situación General del Crédito.xlsx`; vintage `credit_survey:58a83c5bcd64e4423fc13c40`; publication date `2026-06-30` (content_max_period); status `completed`
- **direct_investment** — `Anexo estadístico de Inversión Directa (ID) 1995 - 2024 (1).xlsx`; vintage `direct_investment:fbc612f5e64f6905a2e84928`; publication date `2024-12-31` (content_max_period); status `completed`
- **economic_annex** — `Anexo_Estadístico_del_Informe_Económico_13_08_2026.xlsx`; vintage `economic_annex:25818cb75022083e13cab48e`; publication date `2026-08-13` (filename); status `completed`
- **eve** — `EVE_Anexo Estadístico_agosto_2026.xlsx`; vintage `eve:9eef7e154e7e7c6f3990e0fc`; publication date `2026-08-31` (filename); status `completed`
- **exchange_houses** — `3. Boletín Casa de Cambio Jul26.xlsm`; vintage `exchange_houses:93e85a8013fb6cf2b842f72e`; publication date `2026-07-31` (filename); status `completed`
- **exchange_rates** — `Cotizaciones - Julio 2026.xlsx`; vintage `exchange_rates:a822c1e0cb97438c1bde2836`; publication date `2026-07-31` (filename); status `completed`
- **financial** — `2.1 Tablas Boletín Financieras Jul26 1.xlsx`; vintage `financial:5ebb0bcb3260e482dbf6f83e`; publication date `2026-07-31` (filename); status `completed`
- **financial_indicators** — `Ind. Financieros web-Junio 2026.xlsx`; vintage `financial_indicators:f9ded3c4fe24e11b14caa1df`; publication date `2026-06-30` (filename); status `completed`
- **fx_operations** — `Histórico - Operaciones Cambiarias.xlsx`; vintage `fx_operations:40495acf211c2c2d11664e42`; publication date `2026-07-31` (content_max_period); status `completed`
- **icc** — `Estadistica ICC.xlsx`; vintage `icc:b15c74f9723cd0465d088b85`; publication date `2026-07-31` (content_max_period); status `completed`
- **insurance_annex** — `Anexo_estadístico_2025.xlsx`; vintage `insurance_annex:7cb2b1d2ffa3badb8113e890`; publication date `2025-06-30` (content_max_period); status `completed`
- **interbank_market** — `mercado-interbancario.xlsx`; vintage `interbank_market:dbcda6fadd28e3dd5bb3afc2`; publication date `2026-08-14` (content_max_period); status `completed`
- **liquidity_facility** — `administracion-de-liquidez-web_1.xlsx`; vintage `liquidity_facility:d0704796350e86652138be52`; publication date `2021-09-09` (content_max_period); status `completed`
- **lrm_auctions** — `Subasta de LRM_WEB.xlsx`; vintage `lrm_auctions:b7e160f57d37a215d182eaef`; publication date `2026-07-30` (content_max_period); status `completed`
- **payments** — `Boletín Estadístico de Sistemas de Pago_Julio_2026.xlsx`; vintage `payments:de7b4a670c8e2d7430cd91d6`; publication date `2026-07-31` (filename); status `completed`
- **securities_trades** — `Negociaciones_Bursatiles.csv`; vintage `securities_trades:80f03b3d8b9c898031344ee4`; publication date `2026-08-19` (content_max_period); status `completed`

## Semantic coverage

- **bank_reference** — `reference_dimension`; raw cells: 3210; curated observations: 3210
- **banking_indicators** — `unparsed`; raw cells: 21; curated observations: 0
- **banking_indicators** — `documented_series`; raw cells: 5893; curated observations: 4914
- **bcp_fx_daily** — `documented_series`; raw cells: 44533; curated observations: 40836
- **compensatory_fx_sales** — `documented_series`; raw cells: 627; curated observations: 417
- **corporate_bond_curves** — `curated_long_format`; raw cells: 505999; curated observations: 38922
- **credit_survey** — `documented_series`; raw cells: 21065; curated observations: 15806
- **direct_investment** — `documented_series`; raw cells: 34773; curated observations: 33109
- **direct_investment** — `unparsed`; raw cells: 37; curated observations: 0
- **economic_annex** — `documented_series`; raw cells: 700162; curated observations: 656179
- **economic_annex** — `index_only`; raw cells: 100; curated observations: 0
- **eve** — `curated`; raw cells: 3031; curated observations: 2760
- **exchange_houses** — `documented_series`; raw cells: 5355; curated observations: 5048
- **exchange_houses** — `linked_display_only`; raw cells: 0; curated observations: 0
- **exchange_houses** — `presentation_only`; raw cells: 55; curated observations: 0
- **exchange_houses** — `reference_dimension`; raw cells: 754; curated observations: 0
- **exchange_rates** — `documented_series`; raw cells: 7809; curated observations: 4340
- **financial_indicators** — `documented_series`; raw cells: 201532; curated observations: 158038
- **financial_indicators** — `unparsed`; raw cells: 24; curated observations: 0
- **fx_operations** — `curated`; raw cells: 6061; curated observations: 5480
- **icc** — `curated`; raw cells: 2929; curated observations: 1236
- **insurance_annex** — `unparsed`; raw cells: 99; curated observations: 0
- **insurance_annex** — `documented_series`; raw cells: 38224; curated observations: 34846
- **interbank_market** — `documented_series`; raw cells: 103717; curated observations: 81474
- **liquidity_facility** — `documented_series`; raw cells: 5510; curated observations: 3652
- **lrm_auctions** — `documented_series`; raw cells: 15812; curated observations: 10351
- **payments** — `index_only`; raw cells: 84; curated observations: 0
- **payments** — `documented_series`; raw cells: 57540; curated observations: 51830
- **payments** — `reference_dimension`; raw cells: 59; curated observations: 0
- **securities_trades** — `curated_long_format`; raw cells: 3747960; curated observations: 312329

## Documented financial mapping coverage

- **v_banks_eeff_documented_all** — rows: 246546; mapped_entity_id: 246546; mapped_currency_of_origin: 246546; mapped_unit_currency: 246546; mapped_semantic_classification: 246544
- **v_banks_ratios_documented_all** — rows: 90830; mapped_entity_id: 90830; mapped_semantic_classification: 90830
- **v_banks_carteras_documented_all** — rows: 55004; mapped_entity_id: 55004; mapped_currency_of_origin: 55004; mapped_unit_currency: 55004; mapped_semantic_classification: 55004
- **v_banks_credito_sector_documented_all** — rows: 48134; mapped_entity_id: 48134; mapped_currency_of_origin: 48134; mapped_unit_currency: 48134; mapped_credit_sector_id: 48134
- **v_banks_credito_actividad_documented_all** — rows: 10299; mapped_entity_id: 10299; mapped_currency_of_origin: 10299; mapped_unit_currency: 10299; mapped_credit_sector_id: 10299; mapped_activity_code: 10299
- **v_financial_eeff_documented_all** — rows: 86199; mapped_entity_id: 86199; mapped_currency_of_origin: 86199; mapped_unit_currency: 86199; mapped_semantic_classification: 86199
- **v_financial_ratios_documented_all** — rows: 41195; mapped_entity_id: 41195; mapped_semantic_classification: 41190
- **v_financial_carteras_documented_all** — rows: 20614; mapped_entity_id: 20614; mapped_currency_of_origin: 20614; mapped_unit_currency: 20614; mapped_semantic_classification: 20614
- **v_financial_credito_sector_documented_all** — rows: 17939; mapped_entity_id: 17939; mapped_currency_of_origin: 17939; mapped_unit_currency: 17939; mapped_credit_sector_id: 17939
- **v_financial_credito_actividad_documented_all** — rows: 2722; mapped_entity_id: 2722; mapped_currency_of_origin: 2722; mapped_unit_currency: 2722; mapped_credit_sector_id: 2722; mapped_activity_code: 2722

## Pipeline timings

- **bank_reference / reuse_and_validation:** 0.15 seconds
- **bank_reference / source_total:** 0.15 seconds
- **banking_indicators / reuse_and_validation:** 0.16 seconds
- **banking_indicators / source_total:** 0.17 seconds
- **banks / reuse_and_validation:** 0.29 seconds
- **banks / source_total:** 0.30 seconds
- **bcp_fx_daily / reuse_and_validation:** 0.19 seconds
- **bcp_fx_daily / source_total:** 0.19 seconds
- **compensatory_fx_sales / reuse_and_validation:** 0.14 seconds
- **compensatory_fx_sales / source_total:** 0.15 seconds
- **corporate_bond_curves / reuse_and_validation:** 0.15 seconds
- **corporate_bond_curves / source_total:** 0.16 seconds
- **credit_survey / reuse_and_validation:** 0.14 seconds
- **credit_survey / source_total:** 0.15 seconds
- **direct_investment / reuse_and_validation:** 0.16 seconds
- **direct_investment / source_total:** 0.16 seconds
- **economic_annex / reuse_and_validation:** 0.22 seconds
- **economic_annex / source_total:** 0.23 seconds
- **eve / reuse_and_validation:** 0.14 seconds
- **eve / source_total:** 0.14 seconds
- **exchange_houses / reuse_and_validation:** 0.22 seconds
- **exchange_houses / source_total:** 0.23 seconds
- **exchange_rates / reuse_and_validation:** 0.20 seconds
- **exchange_rates / source_total:** 0.20 seconds
- **financial / reuse_and_validation:** 0.25 seconds
- **financial / source_total:** 0.26 seconds
- **financial_indicators / reuse_and_validation:** 0.17 seconds
- **financial_indicators / source_total:** 0.18 seconds
- **fx_operations / reuse_and_validation:** 0.18 seconds
- **fx_operations / source_total:** 0.19 seconds
- **icc / reuse_and_validation:** 0.14 seconds
- **icc / source_total:** 0.14 seconds
- **insurance_annex / reuse_and_validation:** 0.17 seconds
- **insurance_annex / source_total:** 0.17 seconds
- **interbank_market / reuse_and_validation:** 0.18 seconds
- **interbank_market / source_total:** 0.18 seconds
- **liquidity_facility / reuse_and_validation:** 0.17 seconds
- **liquidity_facility / source_total:** 0.18 seconds
- **lrm_auctions / reuse_and_validation:** 0.16 seconds
- **lrm_auctions / source_total:** 0.17 seconds
- **payments / reuse_and_validation:** 0.18 seconds
- **payments / source_total:** 0.18 seconds
- **securities_trades / reuse_and_validation:** 0.15 seconds
- **securities_trades / source_total:** 0.15 seconds
- **NA / concept_mappings:** 0.06 seconds
- **NA / governance_registers:** 0.58 seconds
- **NA / mart_views:** 0.37 seconds
- **NA / observation_missingness:** 17.32 seconds
- **NA / quality_flag_report:** 0.03 seconds
- **NA / quality_screens:** 0.93 seconds
- **NA / reports:** 0.56 seconds
- **NA / series_semantics:** 1.21 seconds
- **NA / source_region_classification:** 0.44 seconds
- **NA / table_reconciliation:** 0.32 seconds
- **NA / table_status_and_domains:** 0.06 seconds
- **NA / validation:** 34.88 seconds

## Expected-grid cost

- **Seconds this attempt:** 17.32 (budget 120)
- Grid rows retained: 267,830 (budget 25,000,000)
- Retained source vintages: 22; vintages contributing a grid: 4
- Rows per contributing vintage: 66,958
- The stored grid is what survives pruning: a period is kept only where it is an observation or an explained absence. The phase builds a much larger intermediate first — one row per regular series-period per vintage — so **the seconds, not the retained rows, are the cost**, and both grow linearly in retained vintages.

## Quality flags

- **warning / banking_indicators / documented_units_need_review:** 51.28% of observations retain source_units because the workbook does not state a unique unit in the parsed title/header path.
- **warning / banking_indicators / documented_hierarchy_unresolved:** 7 parsed sheets contain aggregates/components whose parent-child hierarchy is not fully encoded; do not sum all series blindly.
- **warning / bcp_fx_daily / documented_hierarchy_unresolved:** 14 parsed sheets contain aggregates/components whose parent-child hierarchy is not fully encoded; do not sum all series blindly.
- **warning / cda_curve / release_input_deferred:** Release-input scope schema43_lineage_only_20260914 explicitly defers cda_curve:8796a589fc2bd31317efdce7 (full SHA-256 8796a589fc2bd31317efdce7865d4598473fdacd048cf04b676dc8f78e2b144c): Deferred from Schema 43 for separate source-onboarding review; source evidence remains preserved.
- **warning / compensatory_fx_sales / documented_hierarchy_unresolved:** 1 parsed sheets contain aggregates/components whose parent-child hierarchy is not fully encoded; do not sum all series blindly.
- **warning / direct_investment / documented_hierarchy_unresolved:** 7 parsed sheets contain aggregates/components whose parent-child hierarchy is not fully encoded; do not sum all series blindly.
- **warning / economic_annex / positional_series_identity:** 232 series required a positional disambiguator; inspect identity_stability before relying on automated continuity.
- **warning / economic_annex / documented_hierarchy_unresolved:** 93 parsed sheets contain aggregates/components whose parent-child hierarchy is not fully encoded; do not sum all series blindly.
- **warning / exchange_houses / documented_hierarchy_unresolved:** 3 parsed sheets contain aggregates/components whose parent-child hierarchy is not fully encoded; do not sum all series blindly.
- **warning / exchange_rates / positional_series_identity:** 14 series required a positional disambiguator; inspect identity_stability before relying on automated continuity.
- **warning / exchange_rates / positional_lane_series_identity:** 4 series represent repeated same-period source rows/cells that have no unique published semantic identifier; all values were retained in deterministic within-period lanes.
- **warning / financial_indicators / documented_hierarchy_unresolved:** 11 parsed sheets contain aggregates/components whose parent-child hierarchy is not fully encoded; do not sum all series blindly.
- **warning / fx_operations / known_published_fx_non_additivity:** 9 published annual subtotals differ in documented exception years; max difference 29.7465
- **warning / insurance_annex / positional_series_identity:** 2 series required a positional disambiguator; inspect identity_stability before relying on automated continuity.
- **warning / insurance_annex / documented_hierarchy_unresolved:** 41 parsed sheets contain aggregates/components whose parent-child hierarchy is not fully encoded; do not sum all series blindly.
- **warning / interbank_market / positional_series_identity:** 433 series required a positional disambiguator; inspect identity_stability before relying on automated continuity.
- **warning / interbank_market / positional_lane_series_identity:** 433 series represent repeated same-period source rows/cells that have no unique published semantic identifier; all values were retained in deterministic within-period lanes.
- **warning / interbank_market / documented_hierarchy_unresolved:** 2 parsed sheets contain aggregates/components whose parent-child hierarchy is not fully encoded; do not sum all series blindly.
- **warning / liquidity_facility / positional_lane_series_identity:** 24 series represent repeated same-period source rows/cells that have no unique published semantic identifier; all values were retained in deterministic within-period lanes.
- **warning / liquidity_facility / positional_series_identity:** 24 series required a positional disambiguator; inspect identity_stability before relying on automated continuity.
- **warning / lrm_auctions / positional_series_identity:** 39 series required a positional disambiguator; inspect identity_stability before relying on automated continuity.
- **warning / lrm_auctions / positional_lane_series_identity:** 39 series represent repeated same-period source rows/cells that have no unique published semantic identifier; all values were retained in deterministic within-period lanes.
- **warning / lrm_auctions / documented_units_need_review:** 100.00% of observations retain source_units because the workbook does not state a unique unit in the parsed title/header path.
- **warning / payments / positional_series_identity:** 76 series required a positional disambiguator; inspect identity_stability before relying on automated continuity.
- **warning / payments / documented_units_need_review:** 18.70% of observations retain source_units because the workbook does not state a unique unit in the parsed title/header path.
- **warning / payments / documented_hierarchy_unresolved:** 38 parsed sheets contain aggregates/components whose parent-child hierarchy is not fully encoded; do not sum all series blindly.
- **warning / tcn_referential_daily / release_input_deferred:** Release-input scope schema43_lineage_only_20260914 explicitly defers tcn_referential_daily:74df666397a33b9c8cdfac10 (full SHA-256 74df666397a33b9c8cdfac10d7ffedd23acf7cbd5907ea21332e100fb939c0a4): Deferred from Schema 43 for separate source-onboarding review; source evidence remains preserved.
- **warning / NA / source_region_unreviewed:** 6,522 published numeric cell(s) across 49 worksheet(s) sit outside every parser region and have no rule in config/source_region_rules.csv saying what they are, so no worksheet they touch can be promoted to validated. See outputs/source_region_review_worklist.csv. Largest: economic_annex/Cuadro 47 (   88); liquidity_facility/ADM- LIQ- DEPOSITO (  614); lrm_auctions/Subastas 2020 (  144); banking_indicators/Índice (    7); exchange_rates/USD Fin Mes (1,529)
- **warning / NA / source_region_rule_unused:** 30 source-region rule(s) match no out-of-region cell. Either the coordinates are wrong or the parser has since been repaired: rule:7f2c2af04692e012a9446012; rule:86a104c72842c81868613200; rule:9a778de4f960d68d8772b032; rule:14c7c13c936377e988311377; rule:66062913f3df395eaa588deb
- **warning / NA / published_identity_incomplete:** 5 identity(ies) have period(s) where the publisher gives the total but not every component, so the equality cannot be tested there: payments/SIPAP_12 TOTAL SPI (I) — Cantidad: 50 of 51 period(s) publish the total without every component | payments/SIPAP_12 TOTAL SPI (I) — Importe Destino: 50 of 51 period(s) publish the total without every component | payments/SIPAP_12 TOTAL ALIAS (C) — Cantidad: 20 of 35 period(s) publish the total without every component | payments/SIPAP_12 TOTAL ALIAS (C) — Importe Destino: 20 of 35 period(s) publish the total without every component | interbank_market/Datos Mercado Interbancario de Fondos — Monto: 3277 of 3287 period(s) publish the total without every component
- **warning / NA / source_provenance_incomplete:** 22 source vintage(s) have no official URL, release identifier, retrieval timestamp or retrieval method in config/source_vintages.csv, so they cannot be independently re-acquired. See outputs/source_provenance_status.csv.
- **warning / NA / availability_inferred_upper_bound:** 22 of 22 vintage(s) date availability from the moment the file entered the immutable archive rather than from a publisher's release timestamp. The bound is safe -- it is later than real availability, so an as-of query sees less than a researcher could have seen and never more -- but it is not evidence of when the publication appeared, and a real-time claim must not be made from it. outputs/source_provenance_worklist.csv names the missing field per vintage; docs/ACQUISITION_RUNBOOK.md is the procedure that stops this recurring for future releases.
- **warning / NA / temporal_convention_mixed:** 164 monthly series change day convention inside their own history. The normalised bounds make a join over them safe, so this does not block; what it does mean is that the raw `period` column of these series is not a regular index and must not be differenced or lagged directly. Ranked in outputs/temporal_convention_worklist.csv.
- **warning / NA / dirty_tree_build_overridden:** PARAGUAY_MACRO_ALLOW_DIRTY_BUILD=1: this database was built from a working tree with uncommitted tracked changes at commit 98370c2c26f8162401cf6e0e3eb3019ef7f687c1. It is a development build. The code that produced it is not in the history, so the build cannot be reproduced from the commit it names, and it must not be cited as a research release.
- **warning / NA / observation_missingness_recorded:** Expected-period absence is recorded with a reason for 20,647 period(s): no_movement 18,416; blank_in_source  1,740; period_absent_from_axis    491. A validated worksheet may not carry unreviewed or unread absence.
- **warning / NA / publisher_statement_contains_projections:** 343 observation(s) across 186 series in main.v_publisher_statement_latest are dated after the vintage that published them. That view is the publisher's current statement and holds them by design; main.v_series_latest excludes them and marts.v_series_projections is the complement. By source: economic_annex (313, to 2028-12-01); fx_operations (30, to 2026-12-31)
- **warning / NA / workbook_cached_formulas_and_hidden_state:** 91,673 cell(s) across 104 worksheet(s) hold a cached formula result rather than a typed value, and 34 worksheet(s) hide rows or columns. Neither is a defect, and neither can be seen from the cell values: whether the publisher recalculated before shipping, and whether a hidden row was meant to be read, are questions for the publisher. 15,403 published observation(s) across 13 worksheet(s) come from rows the publisher hid: economic_annex/CUADRO 32 (4342); economic_annex/Cuadro 21 a (2803); economic_annex/CUADRO 56a (2194); economic_annex/CUADRO 33 (1032); economic_annex/CUADRO 59 (1020). See outputs/workbook_behaviour_latest.csv.
- **warning / NA / publication_date_source_contradicts_content:** The publication date is recorded as the maximum period in the content, but the content reaches further. Record the official release date in config/source_vintages.csv or review the parser: fx_operations (recorded 2026-07-31, content reaches 2026-12-31)
- **warning / NA / publication_date_inferred_from_content:** 22 source vintage(s) have no official release date in config/source_vintages.csv, so availability is inferred from the filename or the content: bank_reference (pending_content_inference); banking_indicators (filename); banks (filename); bcp_fx_daily (content_max_period); compensatory_fx_sales (content_max_period); corporate_bond_curves (content_max_period); credit_survey (content_max_period); direct_investment (content_max_period); economic_annex (filename); eve (filename); exchange_houses (filename); exchange_rates (filename); financial (filename); financial_indicators (filename); fx_operations (content_max_period); icc (content_max_period); insurance_annex (content_max_period); interbank_market (content_max_period); liquidity_facility (content_max_period); lrm_auctions (content_max_period); payments (filename); securities_trades (content_max_period)
- **warning / NA / regular_period_gaps:** 499 regular-frequency series skip at least one expected period (24149 periods in total). Expected for series that start late or pause; see outputs/gap_screen_latest.csv.
- **warning / NA / discontinuity_screen:** 38433 observations in 2611 series move more than ten times the series' own median absolute change. A screen for source and methodology review, not proof of an error; see outputs/discontinuity_screen_latest.csv.

Documented-table sources are analytically queryable. Values whose workbook headers do not identify a unique unit remain explicitly marked as `source_units` pending review.
