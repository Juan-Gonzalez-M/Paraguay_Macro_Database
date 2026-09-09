schema40_database <- function() {
  source <- file.path(project_test_root, "database", "paraguay_macro_pilot.duckdb")
  testthat::skip_if_not(file.exists(source), "production database not present")
  path <- tempfile(fileext = ".duckdb")
  file.copy(source, path, overwrite = TRUE)
  connection <- connect_project_database(path)
  initialize_database(connection, project_test_root)
  apply_platform_contracts(connection, project_test_root, "test:schema41")
  create_canonical_views(connection)
  create_mart_views(connection)
  create_research_views(connection)
  withr::defer({
    DBI::dbDisconnect(connection, shutdown = TRUE)
    unlink(path)
  }, envir = parent.frame())
  connection
}

testthat::test_that("schema 41 publishes exactly the governed grain-aware research API", {
  con <- schema40_database()
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT max(version) AS version FROM audit.schema_version")$version,
    41L
  )
  views <- DBI::dbGetQuery(con, paste(
    "SELECT view_name FROM duckdb_views()",
    "WHERE schema_name = 'research' AND NOT internal ORDER BY 1"
  ))$view_name
  testthat::expect_setequal(views, c(
    "dataset_catalog", "series_catalog", "observations_latest_actual",
    "observations_latest_statement", "entity_panel", "events", "curves",
    "transactions", "quality_flags"
  ))
  for (view in views) testthat::expect_error(
    DBI::dbGetQuery(con, paste0("SELECT * FROM research.", view, " LIMIT 0")), NA
  )
})

testthat::test_that("rule-certified rows are usable without claiming human sign-off", {
  con <- schema40_database()
  testthat::expect_gt(
    DBI::dbGetQuery(con, "SELECT count(*) AS n FROM research.observations_latest_actual")$n,
    0
  )
  testthat::expect_gt(DBI::dbGetQuery(con, "SELECT count(*) AS n FROM research.entity_panel")$n, 0)
  testthat::expect_gt(nrow(research_catalogue(con)), 0L)
  testthat::expect_gt(nrow(research_observations(con)), 0L)
  assurance <- DBI::dbGetQuery(con, "SELECT DISTINCT assurance_level FROM research.series_catalog")
  testthat::expect_true(all(assurance$assurance_level %in% ASSURANCE_LEVELS))
  testthat::expect_true("rule_certified" %in% assurance$assurance_level)
  testthat::expect_false("human_verified" %in% assurance$assurance_level)
  testthat::expect_equal(
    nrow(research_observations_as_of(con, Sys.time())), nrow(research_observations(con))
  )
})

testthat::test_that("certification is evidence-hashed, complete, and conservative", {
  con <- schema40_database()
  registered <- readr::read_csv(
    file.path(project_test_root, "config", "source_registry.csv"), show_col_types = FALSE
  )$source_id
  datasets <- DBI::dbGetQuery(con, "SELECT * FROM research.dataset_catalog")
  testthat::expect_setequal(datasets$source_id, registered)
  testthat::expect_true(all(datasets$assurance_level %in% ASSURANCE_LEVELS))
  testthat::expect_true(all(nzchar(datasets$allowed_uses)))
  testthat::expect_true(all(nzchar(datasets$prohibited_uses)))

  certified <- DBI::dbGetQuery(con, "SELECT * FROM canonical.rule_certified_series")
  decisions <- DBI::dbGetQuery(con, paste(
    "SELECT object_id,evidence_hash FROM canonical.certification_decisions",
    "WHERE object_type='series' AND assurance_level='rule_certified'"
  ))
  testthat::expect_gt(nrow(certified), 0L)
  testthat::expect_setequal(certified$series_id, decisions$object_id)
  testthat::expect_true(all(nchar(certified$evidence_hash) == 64L))

  proposals <- readr::read_csv(
    file.path(project_test_root, "config", "proposals", "series_review.csv"),
    show_col_types = FALSE
  )
  open <- proposals$series_id[!is.na(proposals$open_questions) & nzchar(proposals$open_questions)]
  testthat::expect_length(intersect(open, certified$series_id), 0L)
  testthat::expect_gte(DBI::dbGetQuery(con, paste(
    "SELECT count(*) n FROM canonical.certification_decisions",
    "WHERE object_type='canonical_series'"
  ))$n, 1)
})

testthat::test_that("grain-specific views do not silently retain duplicate panel keys", {
  con <- schema40_database()
  duplicated <- DBI::dbGetQuery(con, paste(
    "SELECT source_id,reference_period,entity_id,item_id,currency,measure,count(*) n",
    "FROM research.entity_panel GROUP BY 1,2,3,4,5,6 HAVING count(*)>1"
  ))
  testthat::expect_equal(nrow(duplicated), 0L)
  testthat::expect_gt(DBI::dbGetQuery(con, "SELECT count(*) n FROM research.curves")$n, 0)
  testthat::expect_gt(DBI::dbGetQuery(con, "SELECT count(*) n FROM research.transactions")$n, 0)
  testthat::expect_true(all(DBI::dbGetQuery(
    con, "SELECT DISTINCT assurance_level FROM research.transactions"
  )$assurance_level == "rule_certified"))
})

testthat::test_that("every source declares missingness and legacy vintages declare their limit", {
  con <- schema40_database()
  registered <- readr::read_csv(
    file.path(project_test_root, "config", "source_registry.csv"), show_col_types = FALSE
  )$source_id
  contracts <- DBI::dbGetQuery(con, paste(
    "SELECT source_id, contract_type FROM audit.missingness_contracts",
    "WHERE source_sheet = '*'"
  ))
  testthat::expect_setequal(contracts$source_id, registered)
  testthat::expect_true(all(contracts$contract_type %in% MISSINGNESS_CONTRACT_TYPES))
  legacy <- DBI::dbGetQuery(con, paste(
    "SELECT availability_quality, snapshot_policy FROM raw.source_provenance"
  ))
  testthat::expect_true(all(
    legacy$snapshot_policy[legacy$availability_quality == "inferred_upper_bound"] ==
      "legacy_current_snapshot_only"
  ))
})

testthat::test_that("source labels and full paths are separate research metadata", {
  con <- schema40_database()
  columns <- DBI::dbGetQuery(con, paste(
    "SELECT column_name FROM information_schema.columns",
    "WHERE table_schema = 'canonical' AND table_name = 'dim_series'"
  ))$column_name
  testthat::expect_true(all(c(
    "source_label", "canonical_name", "measure_type", "full_series_path"
  ) %in% columns))
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM canonical.dim_series",
    "WHERE source_label IS DISTINCT FROM label"
  ))$n, 0)
})

testthat::test_that("canonical membership carries effective precedence policy", {
  con <- schema40_database()
  columns <- DBI::dbGetQuery(con, paste(
    "SELECT column_name FROM information_schema.columns",
    "WHERE table_schema = 'canonical' AND table_name = 'map_canonical_series'"
  ))$column_name
  testthat::expect_true(all(c(
    "valid_from", "valid_to", "precedence", "overlap_policy"
  ) %in% columns))
})

testthat::test_that("research interfaces satisfy the active-release contract", {
  con <- schema40_database()
  validate_published_release_filter(con, "release:schema40-test", project_test_root)
  failures <- DBI::dbGetQuery(con, paste(
    "SELECT * FROM audit.quality_flags WHERE release_id = 'release:schema40-test'",
    "AND severity = 'error'"
  ))
  testthat::expect_equal(nrow(failures), 0L)
})

testthat::test_that("the research flag view cannot shadow the writable audit table", {
  con <- schema40_database()
  release <- "release:schema40-shadow-test"
  testthat::expect_silent(insert_quality_flag(
    con, release, "warning", "schema40_shadow_test", "economic_annex", "fixture"
  ))
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM audit.quality_flags",
    "WHERE release_id = 'release:schema40-shadow-test'"
  ))$n, 1)
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM research.quality_flags",
    "WHERE release_id = 'release:schema40-shadow-test'"
  ))$n, 0)
})
