testthat::test_that("vintage and release identities are deterministic", {
  sha <- paste(rep("a", 64), collapse = "")
  testthat::expect_identical(make_vintage_id("icc", sha), make_vintage_id("icc", sha))
  manifest <- tibble::tibble(source_id = c("b", "a"), sha256 = c("2", "1"))
  testthat::expect_identical(make_release_id(manifest), make_release_id(manifest[2:1, ]))
})

testthat::test_that("archiving is deduplicated by hash", {
  source_path <- fs::dir_ls(file.path(project_test_root, "input", "current", "icc"), regexp = "\\.xlsx$")[[1]]
  temp_root <- tempfile("archive_test_")
  dir.create(temp_root)
  sha <- file_sha256(source_path)
  first <- archive_source(source_path, "icc", temp_root, sha)
  second <- archive_source(source_path, "icc", temp_root, sha)
  testthat::expect_true(first$created)
  testthat::expect_false(second$created)
  testthat::expect_identical(normalizePath(first$path), normalizePath(second$path))
})

testthat::test_that("sparse series retain changes and explicit removals", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  initialize_database(con)
  meta <- tibble::tibble(
    series_id = "test:series", source_id = "test", label = "Test", unit = "index", scale = "units",
    frequency = "monthly", currency = NA_character_, index_base = NA_character_,
    hierarchy_level = "indicator", parent_series_id = NA_character_, is_total = FALSE,
    semantic_status = "curated", first_vintage_id = "test:first"
  )
  first_item <- tibble::tibble(vintage_id = "test:first", source_file = "first.xlsx")
  second_item <- tibble::tibble(vintage_id = "test:second", source_file = "second.xlsx")
  first <- tibble::tibble(
    series_id = "test:series", period = as.Date(c("2026-01-31", "2026-02-28")), value = c(1, 2)
  )
  second <- tibble::tibble(
    series_id = "test:series", period = as.Date("2026-01-31"), value = 3
  )
  write_sparse_series(con, first, meta, first_item, as.Date("2026-03-01"))
  write_sparse_series(con, second, meta, second_item, as.Date("2026-04-01"))
  latest <- DBI::dbGetQuery(con, "SELECT period, value FROM v_series_latest ORDER BY period")
  events <- DBI::dbGetQuery(con, "SELECT is_deleted FROM fact_series_events WHERE vintage_id = 'test:second'")
  testthat::expect_equal(nrow(latest), 1)
  testthat::expect_equal(latest$value[[1]], 3)
  testthat::expect_true(any(events$is_deleted))
})

testthat::test_that("schema-v2 curated outputs are invalidated before v3 reingestion", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(con, "CREATE TABLE schema_version (version INTEGER, applied_at TIMESTAMP, description VARCHAR)")
  DBI::dbExecute(con, "INSERT INTO schema_version VALUES (2, current_timestamp, 'v2')")
  DBI::dbExecute(con, "CREATE TABLE source_files (vintage_id VARCHAR, source_id VARCHAR, publication_date DATE, publication_date_source VARCHAR, ingestion_status VARCHAR)")
  DBI::dbExecute(con, "INSERT INTO source_files VALUES ('eve:old', 'eve', DATE '2096-08-02', 'content_max_period', 'completed')")
  DBI::dbExecute(con, "CREATE TABLE dim_series (series_id VARCHAR, source_id VARCHAR)")
  DBI::dbExecute(con, "INSERT INTO dim_series VALUES ('eve:test', 'eve')")
  DBI::dbExecute(con, "CREATE TABLE fact_series_events (series_id VARCHAR, period DATE, value DOUBLE, vintage_id VARCHAR, publication_date DATE, value_hash VARCHAR, is_deleted BOOLEAN, source_file VARCHAR)")
  DBI::dbExecute(con, "INSERT INTO fact_series_events VALUES ('eve:test', DATE '2096-08-02', 1, 'eve:old', DATE '2096-08-02', 'x', FALSE, 'old.xlsx')")
  DBI::dbExecute(con, "CREATE TABLE series_revisions (revision_id VARCHAR, series_id VARCHAR)")
  DBI::dbExecute(con, "INSERT INTO series_revisions VALUES ('x', 'eve:test')")
  DBI::dbExecute(con, "CREATE TABLE eve_expectations_snapshot (vintage_id VARCHAR)")
  DBI::dbExecute(con, "INSERT INTO eve_expectations_snapshot VALUES ('eve:old')")
  initialize_database(con)
  status <- DBI::dbGetQuery(con, "SELECT ingestion_status, publication_date FROM source_files")
  testthat::expect_identical(status$ingestion_status[[1]], "needs_v3_reingestion")
  testthat::expect_true(is.na(status$publication_date[[1]]))
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM fact_series_events")$n[[1]], 0)
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM dim_series")$n[[1]], 0)
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM series_revisions")$n[[1]], 0)
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM eve_expectations_snapshot")$n[[1]], 0)
})

testthat::test_that("unchanged report sheets reuse one physical cell version", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  initialize_database(con)
  cells <- tibble::tibble(
    row_id = c(1L, 2L), column_id = c(1L, 1L), raw_value_text = c("Header", "100"),
    raw_value_num = c(NA_real_, 100), raw_value_date = as.Date(c(NA_character_, NA_character_))
  )
  first <- tibble::tibble(source_id = "report", vintage_id = "report:first", source_file = "first.xlsx")
  second <- tibble::tibble(source_id = "report", vintage_id = "report:second", source_file = "second.xlsx")
  store_report_sheet_version(con, cells, first, "Sheet1", "release:first", as.Date("2026-01-31"), "sig")
  store_report_sheet_version(con, cells, second, "Sheet1", "release:second", as.Date("2026-02-28"), "sig")
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM report_sheet_versions")$n[[1]], 1)
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM report_cell_values")$n[[1]], 2)
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM report_sheet_vintages")$n[[1]], 2)
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM report_cells")$n[[1]], 4)
})

testthat::test_that("schema-v3 currency and report storage migrate safely to v4", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(con, "CREATE TABLE schema_version (version INTEGER, applied_at TIMESTAMP, description VARCHAR)")
  DBI::dbExecute(con, "INSERT INTO schema_version VALUES (3, current_timestamp, 'v3')")
  DBI::dbExecute(con, "CREATE TABLE source_files (vintage_id VARCHAR, source_id VARCHAR, ingestion_status VARCHAR)")
  DBI::dbExecute(con, "INSERT INTO source_files VALUES ('bank_reference:old', 'bank_reference', 'completed')")
  DBI::dbExecute(con, "CREATE TABLE dim_currency (currency_code VARCHAR, economic_currency VARCHAR)")
  DBI::dbExecute(con, "INSERT INTO dim_currency VALUES ('6200', 'USD')")
  DBI::dbExecute(con, "CREATE TABLE report_cells (vintage_id VARCHAR, release_id VARCHAR, publication_date DATE, source_id VARCHAR, source_file VARCHAR, source_sheet VARCHAR, row_id BIGINT, column_id BIGINT, raw_value_text VARCHAR, raw_value_num DOUBLE, raw_value_date DATE)")
  DBI::dbExecute(con, "INSERT INTO report_cells VALUES ('old', 'release', DATE '2026-01-01', 'report', 'old.xlsx', 'Sheet1', 1, 1, 'x', NULL, NULL)")
  initialize_database(con)
  testthat::expect_identical(database_object_type(con, "report_cells"), "VIEW")
  testthat::expect_true(DBI::dbExistsTable(con, "report_cells_legacy"))
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM report_cells")$n[[1]], 1)
  currency <- DBI::dbGetQuery(con, "SELECT currency_of_origin, unit_currency, economic_currency FROM dim_currency WHERE currency_code = '6200'")
  testthat::expect_identical(currency$currency_of_origin[[1]], "FX")
  testthat::expect_identical(currency$unit_currency[[1]], "PYG")
  testthat::expect_identical(currency$economic_currency[[1]], "PYG")
  status <- DBI::dbGetQuery(con, "SELECT ingestion_status FROM source_files WHERE source_id = 'bank_reference'")$ingestion_status[[1]]
  # v3->v4 marks bank_reference for v4 reingestion, but invalidate_v8_ingestion_repairs()
  # explicitly re-touches bank_reference too (its own WHERE clause includes
  # "OR source_id = 'bank_reference'") -- migrating a genuinely stale v3 database
  # cascades through every later step that also targets this source, landing on v9.
  testthat::expect_identical(status, "needs_v9_reingestion")
})

testthat::test_that("schema-v4 documented sources are invalidated before v5 reingestion", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbExecute(con, "CREATE TABLE schema_version (version INTEGER, applied_at TIMESTAMP, description VARCHAR)")
  DBI::dbExecute(con, "INSERT INTO schema_version VALUES (4, current_timestamp, 'v4')")
  DBI::dbExecute(con, "CREATE TABLE source_files (vintage_id VARCHAR, source_id VARCHAR, ingestion_status VARCHAR)")
  DBI::dbExecute(con, "INSERT INTO source_files VALUES ('annex:old', 'economic_annex', 'completed'), ('icc:old', 'icc', 'completed')")
  initialize_database(con)
  status <- DBI::dbGetQuery(con, "SELECT source_id, ingestion_status FROM source_files ORDER BY source_id")
  # economic_annex is explicitly listed in every subsequent invalidate_v*() step
  # (v6, v8, v9, v10 all target it too), so migrating from a genuinely stale v4
  # database cascades through all of them, landing on the latest, v11.
  testthat::expect_identical(status$ingestion_status[status$source_id == "economic_annex"], "needs_v11_reingestion")
  testthat::expect_identical(status$ingestion_status[status$source_id == "icc"], "completed")
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM schema_version WHERE version = 5")$n[[1]], 1)
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM schema_version WHERE version = 6")$n[[1]], 1)
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM schema_version WHERE version = 8")$n[[1]], 1)
  testthat::expect_true(DBI::dbExistsTable(con, "ingestion_stage_timings"))
  testthat::expect_true(DBI::dbExistsTable(con, "dim_concept"))
  testthat::expect_true(DBI::dbExistsTable(con, "map_series_concept"))
})
