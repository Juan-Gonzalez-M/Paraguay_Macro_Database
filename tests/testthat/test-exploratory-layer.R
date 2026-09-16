exploratory_layer_database <- function() {
  source <- file.path(project_test_root, "database", "paraguay_macro_pilot.duckdb")
  testthat::skip_if_not(file.exists(source), "production database not present")
  path <- tempfile(fileext = ".duckdb")
  file.copy(source, path, overwrite = TRUE)
  connection <- connect_project_database(path)
  initialize_database(connection, project_test_root)
  apply_platform_contracts(connection, project_test_root, "test:schema43")
  create_canonical_views(connection)
  create_mart_views(connection)
  create_research_views(connection)
  withr::defer({
    DBI::dbDisconnect(connection, shutdown = TRUE)
    unlink(path)
  }, envir = parent.frame())
  connection
}

testthat::test_that("schema 43 catalogues every candidate and separates access by grain", {
  con <- exploratory_layer_database()
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT max(version) AS v FROM audit.schema_version")$v, 43L
  )
  catalog_views <- DBI::dbGetQuery(con, paste(
    "SELECT view_name FROM duckdb_views() WHERE schema_name='catalog' AND NOT internal ORDER BY 1"
  ))$view_name
  explore_views <- DBI::dbGetQuery(con, paste(
    "SELECT view_name FROM duckdb_views() WHERE schema_name='explore' AND NOT internal ORDER BY 1"
  ))$view_name
  testthat::expect_setequal(catalog_views, c("series", "series_warnings", "datasets"))
  testthat::expect_setequal(explore_views, c(
    "series_catalog", "observations", "events", "panel_observations", "curve_observations"
  ))

  coverage <- DBI::dbGetQuery(con, paste(
    "SELECT (SELECT count(*) FROM canonical.dim_series) AS dimension_rows,",
    "(SELECT count(*) FROM catalog.series) AS catalogue_rows,",
    "(SELECT count(DISTINCT candidate_id) FROM catalog.series) AS candidate_ids,",
    "(SELECT count(*) FROM main.v_series_latest o LEFT JOIN catalog.series c",
    " ON c.candidate_id=o.series_id WHERE c.candidate_id IS NULL) AS orphan_observations"
  ))
  testthat::expect_equal(coverage$catalogue_rows, coverage$dimension_rows)
  testthat::expect_equal(coverage$candidate_ids, coverage$dimension_rows)
  testthat::expect_equal(coverage$orphan_observations, 0)
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT count(*) n FROM catalog.datasets")$n,
    DBI::dbGetQuery(con, "SELECT count(*) n FROM canonical.dataset_catalog")$n
  )

  tiers <- DBI::dbGetQuery(con, "SELECT DISTINCT validation_tier FROM catalog.series")$validation_tier
  testthat::expect_true(all(tiers %in% c(
    "research_ready", "exploratory_structurally_valid", "candidate_needs_review",
    "quarantined_or_invalid", "non_scalar_or_special_structure"
  )))
  complete_profiles <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) n FROM catalog.series WHERE candidate_id IS NULL OR source_id IS NULL",
    "OR validation_tier IS NULL OR status_code IS NULL OR concise_warning IS NULL",
    "OR warning_codes IS NULL OR warning_count<1 OR observation_interface IS NULL",
    "AND validation_tier NOT IN ('candidate_needs_review','quarantined_or_invalid')"
  ))$n
  testthat::expect_equal(complete_profiles, 0)
  categories <- DBI::dbGetQuery(con, paste(
    "SELECT primary_review_category,count(*) n FROM catalog.series GROUP BY 1 ORDER BY 1"
  ))
  testthat::expect_equal(sum(categories$n), coverage$dimension_rows)
  testthat::expect_true(all(categories$primary_review_category %in% c(
    "apparently_valid_preliminary", "research_validated", "discovery_only",
    "clear_mechanical_defect", "probable_identity_fragmentation",
    "probable_duplicate_or_overlap", "semantic_review_required",
    "provenance_review_required", "insufficient_evidence"
  )))
  admission <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) FILTER(WHERE validation_tier='research_ready') AS research_tier,",
    "count(*) FILTER(WHERE primary_review_category='research_validated') AS research_category,",
    "count(*) FILTER(WHERE research_admission_status='admitted') AS research_admitted,",
    "count(*) FILTER(WHERE validation_tier='candidate_needs_review'",
    " AND identity_stability IN ('positional','positional_lane')",
    " AND supported_overlap_series_count=0) AS positional_review,",
    "count(*) FILTER(WHERE primary_review_category='probable_identity_fragmentation')",
    " AS fragmented FROM catalog.series"
  ))
  testthat::expect_equal(admission$research_category, admission$research_tier)
  testthat::expect_equal(admission$research_admitted, admission$research_tier)
  testthat::expect_equal(admission$fragmented, admission$positional_review)
  supported_overlap <- DBI::dbGetQuery(con, paste(
    "SELECT source_id,count(*) n,min(supported_overlap_series_count) min_matches,",
    "max(supported_overlap_series_count) max_matches FROM catalog.series",
    "WHERE primary_review_category='probable_duplicate_or_overlap' GROUP BY 1 ORDER BY 1"
  ))
  testthat::expect_equal(supported_overlap$source_id, c("economic_annex", "fx_operations"))
  testthat::expect_equal(supported_overlap$n, c(30, 30))
  testthat::expect_equal(supported_overlap$min_matches, c(1, 1))
  testthat::expect_equal(supported_overlap$max_matches, c(1, 1))
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT coalesce(sum(warning_count),0) n FROM catalog.series")$n,
    DBI::dbGetQuery(con, "SELECT count(*) n FROM catalog.series_warnings")$n
  )

  scalar <- DBI::dbGetQuery(con, paste(
    "SELECT",
    "(SELECT coalesce(sum(observation_count),0) FROM catalog.series",
    " WHERE data_structure='scalar_series' AND validation_tier IN",
    " ('research_ready','exploratory_structurally_valid')) AS expected_rows,",
    "(SELECT count(*) FROM explore.observations) AS exposed_rows,",
    "(SELECT count(*) FROM (SELECT candidate_id,reference_period_start,count(*) n",
    " FROM explore.observations GROUP BY 1,2 HAVING count(*)>1)) AS duplicate_keys,",
    "(SELECT count(*) FROM explore.observations WHERE value IS NULL OR NOT isfinite(value)",
    " OR reference_period_start IS NULL OR reference_period_end<reference_period_start",
    " OR observation_status<>'observed') AS malformed_rows,",
    "(SELECT count(*) FROM explore.observations o JOIN catalog.series c USING(candidate_id)",
    " WHERE c.identity_stability<>'semantic' OR c.non_missing_observation_count<3) AS ineligible_rows"
  ))
  testthat::expect_equal(scalar$exposed_rows, scalar$expected_rows)
  testthat::expect_equal(scalar$duplicate_keys, 0)
  testthat::expect_equal(scalar$malformed_rows, 0)
  testthat::expect_equal(scalar$ineligible_rows, 0)

  short <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS candidates,count(*) FILTER(WHERE validation_tier='candidate_needs_review') AS labelled,",
    "sum(observation_count) AS observations FROM catalog.series",
    "WHERE data_structure='scalar_series' AND non_missing_observation_count<=2"
  ))
  testthat::expect_gt(short$candidates, 0)
  testthat::expect_equal(short$labelled, short$candidates)
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) n FROM explore.observations o JOIN catalog.series c USING(candidate_id)",
    "WHERE c.data_structure='scalar_series' AND c.non_missing_observation_count<=2"
  ))$n, 0)

  special <- DBI::dbGetQuery(con, paste(
    "SELECT",
    "(SELECT sum(observation_count) FROM catalog.series",
    " WHERE data_structure='event' OR frequency='irregular_interval') expected_events,",
    "(SELECT count(*) FROM explore.events) exposed_events,",
    "(SELECT sum(observation_count) FROM catalog.series WHERE data_structure='entity_panel') expected_panels,",
    "(SELECT count(*) FROM explore.panel_observations) exposed_panels,",
    "(SELECT sum(observation_count) FROM catalog.series WHERE data_structure='curve_panel') expected_curves,",
    "(SELECT count(*) FROM explore.curve_observations) exposed_curves"
  ))
  testthat::expect_equal(special$exposed_events, special$expected_events)
  testthat::expect_equal(special$exposed_panels, special$expected_panels)
  testthat::expect_equal(special$exposed_curves, special$expected_curves)
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) n FROM explore.observations o JOIN catalog.series c USING(candidate_id)",
    "WHERE c.data_structure<>'scalar_series'"
  ))$n, 0)
})

testthat::test_that("candidate profile and retrieval carry warnings and lineage", {
  con <- exploratory_layer_database()
  candidate <- DBI::dbGetQuery(con, paste(
    "SELECT candidate_id FROM catalog.series WHERE validation_tier='exploratory_structurally_valid'",
    "AND coordinate_lineage_status='complete_for_current_observations' ORDER BY candidate_id LIMIT 1"
  ))$candidate_id[[1]]
  quoted <- sql_string(candidate)
  profile <- DBI::dbGetQuery(con, paste0("SELECT * FROM catalog.profile(", quoted, ")"))
  observations <- DBI::dbGetQuery(con, paste0("SELECT * FROM explore.series(", quoted, ")"))
  testthat::expect_equal(nrow(profile), 1L)
  testthat::expect_equal(nrow(observations), profile$observation_count)
  testthat::expect_true(all(observations$candidate_id == candidate))
  testthat::expect_true(all(!is.na(observations$validation_tier)))
  testthat::expect_true(all(!is.na(observations$primary_review_category)))
  testthat::expect_true(all(observations$explore_admission_status == "eligible_scalar"))
  testthat::expect_true(all(!is.na(observations$research_admission_status)))
  testthat::expect_true(all(nzchar(observations$concise_warning)))
  testthat::expect_true(all(nzchar(observations$source_id)))
  testthat::expect_true(all(nzchar(observations$vintage_id)))
  testthat::expect_true(all(nzchar(observations$build_code_digest)))
  testthat::expect_true(all(!is.na(observations$source_row)))
  testthat::expect_true(all(!is.na(observations$source_column)))
})

testthat::test_that("worksheet lineage resolves every documented exploratory observation to raw A1 evidence", {
  con <- exploratory_layer_database()
  corrected <- DBI::dbGetQuery(con, paste(
    "SELECT source_id,count(*) AS observations,count(DISTINCT candidate_id) AS candidates",
    "FROM explore.observations WHERE worksheet_lineage_correction_reason IS NOT NULL",
    "GROUP BY 1 ORDER BY 1"
  ))
  testthat::expect_equal(corrected$source_id, c("bcp_fx_daily", "financial_indicators"))
  testthat::expect_equal(corrected$observations, c(37800, 1743))
  testthat::expect_equal(corrected$candidates, c(12, 15))
  testthat::expect_equal(sum(corrected$observations), 39543)
  testthat::expect_equal(sum(corrected$candidates), 27)

  profiles <- DBI::dbGetQuery(con, paste(
    "SELECT source_id,count(*) AS candidates,sum(worksheet_lineage_correction_rows) AS observations,",
    "min(source_sheet_count) AS min_sheets,max(source_sheet_count) AS max_sheets,",
    "count(*) FILTER(WHERE source_sheet IS NOT NULL) AS single_sheet_profiles,",
    "string_agg(DISTINCT worksheet_lineage_status,';' ORDER BY worksheet_lineage_status) AS statuses",
    "FROM catalog.series WHERE worksheet_lineage_correction_rows>0 GROUP BY 1 ORDER BY 1"
  ))
  testthat::expect_equal(profiles$candidates, c(12, 15))
  testthat::expect_equal(profiles$observations, c(37800, 1743))
  testthat::expect_equal(profiles$min_sheets, c(14, 1))
  testthat::expect_equal(profiles$max_sheets, c(14, 1))
  testthat::expect_equal(profiles$single_sheet_profiles, c(0, 15))
  testthat::expect_equal(
    profiles$statuses, c("complete_multiple_worksheets", "complete_single_worksheet")
  )

  locator <- DBI::dbGetQuery(con, paste(
    "WITH exposed AS (",
    " SELECT * FROM explore.observations UNION ALL BY NAME",
    " SELECT * FROM explore.events UNION ALL BY NAME",
    " SELECT * FROM explore.panel_observations UNION ALL BY NAME",
    " SELECT * FROM explore.curve_observations",
    "), documented AS (",
    " SELECT e.*,d.source_sheet AS expected_sheet,d.table_title AS expected_title,",
    " d.source_row AS expected_row,d.source_column AS expected_column",
    " FROM exposed e JOIN staging.documented_series_snapshot d",
    " ON d.series_id=e.candidate_id AND d.period=e.source_period_date",
    " AND d.vintage_id=e.vintage_id",
    "), checked AS (",
    " SELECT d.*,c.raw_value_num,c.raw_value_text FROM documented d",
    " LEFT JOIN main.v_report_cells_a1 c ON c.vintage_id=d.vintage_id",
    " AND c.source_sheet=d.expected_sheet AND c.row_id=d.expected_row",
    " AND c.column_id=d.expected_column",
    ") SELECT count(*) AS documented_rows,",
    " count(*) FILTER(WHERE source_sheet IS DISTINCT FROM expected_sheet",
    "  OR table_title IS DISTINCT FROM expected_title",
    "  OR source_row IS DISTINCT FROM expected_row",
    "  OR source_column IS DISTINCT FROM expected_column) AS staging_disagreements,",
    " count(*) FILTER(WHERE raw_value_text IS NULL AND raw_value_num IS NULL) AS missing_raw_cells,",
    " count(*) FILTER(WHERE raw_value_num IS NULL",
    "  OR abs(raw_value_num-value)>1e-8*greatest(1,abs(value))) AS numeric_differences",
    " FROM checked"
  ))
  testthat::expect_gt(locator$documented_rows, 0)
  testthat::expect_equal(locator$staging_disagreements, 0)
  testthat::expect_equal(locator$missing_raw_cells, 0)
  testthat::expect_equal(locator$numeric_differences, 0)

  unchanged <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS differences FROM explore.observations e",
    "JOIN main.v_series_latest o ON o.series_id=e.candidate_id",
    " AND o.period=e.source_period_date AND o.vintage_id=e.vintage_id",
    "JOIN canonical.dim_series d ON d.series_id=e.candidate_id WHERE",
    " e.value IS DISTINCT FROM o.value",
    " OR e.reference_period_start IS DISTINCT FROM o.period_start",
    " OR e.reference_period_end IS DISTINCT FROM o.period_end",
    " OR e.observation_status IS DISTINCT FROM o.observation_status",
    " OR e.source_file IS DISTINCT FROM o.source_file",
    " OR e.frequency IS DISTINCT FROM d.frequency",
    " OR e.source_unit IS DISTINCT FROM d.unit OR e.unit_code IS DISTINCT FROM d.unit_code",
    " OR e.source_scale IS DISTINCT FROM d.scale",
    " OR e.scale_multiplier IS DISTINCT FROM d.scale_multiplier",
    " OR e.currency IS DISTINCT FROM d.currency OR e.stock_flow IS DISTINCT FROM d.stock_flow",
    " OR e.nominal_real IS DISTINCT FROM d.nominal_real",
    " OR e.seasonal_adjustment IS DISTINCT FROM d.seasonal_adjustment",
    " OR e.transformation IS DISTINCT FROM d.transformation",
    " OR e.valuation IS DISTINCT FROM d.valuation"
  ))$differences
  testthat::expect_equal(unchanged, 0)

  reconciliation <- DBI::dbGetQuery(con, paste(
    "SELECT source_id,sum(balance_delta) AS balance_delta,",
    "sum(unclassified_cells) AS unclassified,sum(parser_defect_cells) AS parser_defects",
    "FROM audit.table_reconciliation",
    "WHERE source_id IN ('bcp_fx_daily','financial_indicators') GROUP BY 1 ORDER BY 1"
  ))
  testthat::expect_equal(reconciliation$source_id, c("bcp_fx_daily", "financial_indicators"))
  testthat::expect_equal(reconciliation$balance_delta, c(0, 0))
  testthat::expect_equal(reconciliation$unclassified, c(0, 0))
  testthat::expect_equal(reconciliation$parser_defects, c(0, 0))
})

testthat::test_that("invalid or ambiguous worksheet lineage fails closed", {
  con <- exploratory_layer_database()
  candidates <- DBI::dbGetQuery(con, paste(
    "SELECT candidate_id FROM catalog.series",
    "WHERE validation_tier='exploratory_structurally_valid'",
    "AND coordinate_lineage_status='complete_for_current_observations'",
    "ORDER BY candidate_id LIMIT 2"
  ))$candidate_id
  testthat::expect_length(candidates, 2L)
  ambiguous <- sql_string(candidates[[1]])
  invalid <- sql_string(candidates[[2]])

  DBI::dbExecute(con, "DROP INDEX staging.ux_documented_series_snapshot_natural_key")
  DBI::dbExecute(con, paste0(
    "INSERT INTO staging.documented_series_snapshot SELECT * REPLACE",
    " ('ambiguous_lineage_fixture' AS source_sheet)",
    " FROM staging.documented_series_snapshot WHERE series_id=", ambiguous, " LIMIT 1"
  ))
  DBI::dbExecute(con, paste0(
    "UPDATE staging.documented_series_snapshot SET source_sheet=NULL WHERE series_id=", invalid,
    " AND period=(SELECT min(period) FROM staging.documented_series_snapshot WHERE series_id=",
    invalid, ")"
  ))
  create_research_views(con)

  profiles <- DBI::dbGetQuery(con, paste0(
    "SELECT candidate_id,validation_tier,invalid_lineage_rows,ambiguous_lineage_rows ",
    "FROM catalog.series WHERE candidate_id IN (", ambiguous, ",", invalid, ") ORDER BY candidate_id"
  ))
  testthat::expect_true(all(profiles$validation_tier == "quarantined_or_invalid"))
  testthat::expect_equal(sum(profiles$ambiguous_lineage_rows > 0), 1)
  testthat::expect_equal(sum(profiles$invalid_lineage_rows > 0), 1)
  testthat::expect_equal(DBI::dbGetQuery(con, paste0(
    "SELECT count(*) n FROM explore.observations WHERE candidate_id IN (",
    ambiguous, ",", invalid, ")"
  ))$n, 0)
})

testthat::test_that("a normalized-period collision is quarantined from scalar exploration", {
  con <- exploratory_layer_database()
  fixture <- DBI::dbGetQuery(con, paste(
    "WITH candidates AS (SELECT f.*,d.frequency,",
    " CASE WHEN f.period<>date_trunc('month',f.period)::DATE",
    "  THEN date_trunc('month',f.period)::DATE ELSE last_day(f.period) END AS alternate_period",
    " FROM canonical.fact_series_events f JOIN canonical.dim_series d USING(series_id)",
    " WHERE d.series_grain='scalar_series' AND d.identity_stability='semantic'",
    "  AND d.frequency='monthly' AND NOT f.is_deleted), eligible AS (",
    " SELECT c.* FROM candidates c WHERE c.alternate_period<>c.period AND NOT EXISTS(",
    "  SELECT 1 FROM canonical.fact_series_events x WHERE x.series_sk=c.series_sk",
    "  AND x.vintage_sk=c.vintage_sk AND x.period=c.alternate_period))",
    "SELECT * FROM eligible LIMIT 1"
  ))
  testthat::expect_equal(nrow(fixture), 1L)
  DBI::dbExecute(con, paste0(
    "INSERT INTO canonical.fact_series_events ",
    "SELECT series_sk,CAST(", sql_string(as.character(fixture$alternate_period)), " AS DATE),",
    "vintage_sk,series_id,vintage_id,value+1,publication_date,",
    sql_string(digest::digest(paste(fixture$value + 1), algo = "sha256", serialize = FALSE)),
    ",FALSE,source_file FROM canonical.fact_series_events WHERE series_sk=",
    as.character(fixture$series_sk), " AND vintage_sk=", as.character(fixture$vintage_sk),
    " AND period=CAST(", sql_string(as.character(fixture$period)), " AS DATE) LIMIT 1"
  ))
  create_research_views(con)
  profile <- DBI::dbGetQuery(con, paste0(
    "SELECT validation_tier,duplicate_logical_key_count,conflicting_logical_key_count ",
    "FROM catalog.profile(", sql_string(fixture$series_id), ")"
  ))
  testthat::expect_equal(profile$validation_tier, "quarantined_or_invalid")
  testthat::expect_gt(profile$duplicate_logical_key_count, 0)
  testthat::expect_gt(profile$conflicting_logical_key_count, 0)
  testthat::expect_equal(DBI::dbGetQuery(con, paste0(
    "SELECT count(*) n FROM explore.series(", sql_string(fixture$series_id), ")"
  ))$n, 0)
})

testthat::test_that("catalog and explore views bind from a fresh attached connection", {
  source <- file.path(project_test_root, "database", "paraguay_macro_pilot.duckdb")
  testthat::skip_if_not(file.exists(source), "production database not present")
  path <- tempfile(fileext = ".duckdb")
  file.copy(source, path, overwrite = TRUE)
  builder <- connect_project_database(path)
  initialize_database(builder, project_test_root)
  apply_platform_contracts(builder, project_test_root, "test:schema43-bind")
  create_canonical_views(builder)
  create_mart_views(builder)
  create_research_views(builder)
  DBI::dbDisconnect(builder, shutdown = TRUE)
  withr::defer(unlink(path))

  direct <- DBI::dbConnect(duckdb::duckdb(), path, read_only = TRUE)
  testthat::expect_identical(trimws(
    DBI::dbGetQuery(direct, "SELECT current_setting('search_path') AS s")$s[[1]]
  ), "")
  objects <- DBI::dbGetQuery(direct, paste(
    "SELECT schema_name,view_name FROM duckdb_views() WHERE schema_name IN ('catalog','explore')",
    "AND NOT internal ORDER BY 1,2"
  ))
  for (i in seq_len(nrow(objects))) testthat::expect_error(DBI::dbGetQuery(
    direct, sprintf('SELECT * FROM "%s"."%s" LIMIT 0', objects$schema_name[[i]], objects$view_name[[i]])
  ), NA)
  testthat::expect_error(DBI::dbGetQuery(direct, "SELECT * FROM catalog.profile('x') LIMIT 0"), NA)
  testthat::expect_error(DBI::dbGetQuery(direct, "SELECT * FROM explore.series('x') LIMIT 0"), NA)
  DBI::dbDisconnect(direct, shutdown = TRUE)

  attached <- DBI::dbConnect(duckdb::duckdb(), ":memory:")
  withr::defer(DBI::dbDisconnect(attached, shutdown = TRUE))
  DBI::dbExecute(attached, paste0(
    "ATTACH ", DBI::dbQuoteString(attached, path), " AS candidate (READ_ONLY)"
  ))
  for (object in c(
    "catalog.series", "catalog.series_warnings", "catalog.datasets", "explore.series_catalog",
    "explore.observations", "explore.events", "explore.panel_observations", "explore.curve_observations"
  )) testthat::expect_error(DBI::dbGetQuery(
    attached, paste0("SELECT * FROM candidate.", object, " LIMIT 0")
  ), NA)
})
