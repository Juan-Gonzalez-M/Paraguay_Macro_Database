testthat::test_that("direct bank and finance schemas match independently", {
  for (source_id in c("banks", "financial")) {
    path <- fs::dir_ls(file.path(project_test_root, "input", "current", source_id), regexp = "\\.xlsx$")[[1]]
    dimensions <- xlsx_sheet_dimensions(path)
    checks <- assert_direct_structure(path, source_id, dimensions, project_test_root)
    testthat::expect_true(all(checks$status == "passed"))
  }
})

testthat::test_that("structure changes fail closed", {
  testthat::expect_error(
    assert_same_structure(c("date", "value"), c("date", "inserted", "value"), "test", "sheet", "headers"),
    "Structure guard failed"
  )
})

testthat::test_that("ICC guarded parser creates twelve metrics", {
  path <- fs::dir_ls(file.path(project_test_root, "input", "current", "icc"), regexp = "\\.xlsx$")[[1]]
  item <- tibble::tibble(source_id = "icc", source_label = "ICC", ingest_mode = "icc", semantic_status = "curated", path = path, source_file = basename(path), sha256 = file_sha256(path), vintage_id = make_vintage_id("icc", file_sha256(path)))
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  initialize_database(con)
  dimensions <- xlsx_sheet_dimensions(path)
  record_source_metadata(con, item, dimensions, "test-release", tempfile("root_"))
  result <- icc_parser(con, item, dimensions, "test-release", project_test_root, as.Date(NA))
  metrics <- DBI::dbGetQuery(con, "SELECT COUNT(DISTINCT metric) AS n FROM consumer_confidence_snapshot")$n[[1]]
  dates <- DBI::dbGetQuery(con, "SELECT min(date) AS minimum, max(date) AS maximum FROM consumer_confidence_snapshot")
  testthat::expect_equal(metrics, 12)
  testthat::expect_gte(result$curated_rows, 1236)
  testthat::expect_gte(as.Date(dates$minimum[[1]]), as.Date("2010-01-01"))
  testthat::expect_lte(as.Date(dates$maximum[[1]]), Sys.Date() + 400L)
})

testthat::test_that("EVE dates retain the Excel epoch and plausible history", {
  path <- fs::dir_ls(file.path(project_test_root, "input", "current", "eve"), regexp = "\\.xlsx$")[[1]]
  item <- tibble::tibble(source_id = "eve", source_label = "EVE", ingest_mode = "eve", semantic_status = "curated", path = path, source_file = basename(path), sha256 = file_sha256(path), vintage_id = make_vintage_id("eve", file_sha256(path)))
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  initialize_database(con)
  dimensions <- xlsx_sheet_dimensions(path)
  record_source_metadata(con, item, dimensions, "test-release", tempfile("root_"))
  result <- eve_parser(con, item, dimensions, "test-release", project_test_root, as.Date(NA))
  dates <- DBI::dbGetQuery(con, "SELECT min(date) AS minimum, max(date) AS maximum FROM eve_expectations_snapshot")
  testthat::expect_gte(result$curated_rows, 2760)
  testthat::expect_equal(as.Date(dates$minimum[[1]]), as.Date("2006-04-01"))
  testthat::expect_gte(as.Date(dates$maximum[[1]]), as.Date("2026-08-01"))
  testthat::expect_lte(as.Date(dates$maximum[[1]]), Sys.Date() + 400L)
})

testthat::test_that("FX parser retains annual quarterly and monthly levels", {
  path <- fs::dir_ls(file.path(project_test_root, "input", "current", "fx_operations"), regexp = "\\.xlsx$")[[1]]
  item <- tibble::tibble(source_id = "fx_operations", source_label = "FX", ingest_mode = "fx_operations", semantic_status = "curated", path = path, source_file = basename(path), sha256 = file_sha256(path), vintage_id = make_vintage_id("fx_operations", file_sha256(path)))
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  initialize_database(con)
  dimensions <- xlsx_sheet_dimensions(path)
  record_source_metadata(con, item, dimensions, "test-release", tempfile("root_"))
  result <- fx_parser(con, item, dimensions, "test-release", project_test_root, as.Date(NA))
  frequencies <- DBI::dbGetQuery(con, "SELECT DISTINCT frequency FROM fx_operations_snapshot ORDER BY 1")$frequency
  testthat::expect_setequal(frequencies, c("annual", "monthly", "quarterly"))
  testthat::expect_gte(result$curated_rows, 5480)
  testthat::expect_gte(as.Date(result$publication_date), as.Date("2026-07-31"))
  testthat::expect_lte(as.Date(result$publication_date), Sys.Date() + 400L)
})

testthat::test_that("reference workbook populates verified dimensions", {
  path <- fs::dir_ls(file.path(project_test_root, "input", "current", "bank_reference"), regexp = "\\.xlsx$")[[1]]
  item <- tibble::tibble(source_id = "bank_reference", source_label = "References", ingest_mode = "reference", semantic_status = "reference_dimension", path = path, source_file = basename(path), sha256 = file_sha256(path), vintage_id = make_vintage_id("bank_reference", file_sha256(path)))
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  initialize_database(con)
  dimensions <- xlsx_sheet_dimensions(path)
  record_source_metadata(con, item, dimensions, "test-release", tempfile("root_"))
  ingest_reference_workbook(con, item, dimensions, "test-release", project_test_root, as.Date(NA))
  testthat::expect_gte(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM reference_table_loads")$n[[1]], 15)
  testthat::expect_gte(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM dim_statement_item")$n[[1]], 218)
  testthat::expect_gte(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM map_statement_account")$n[[1]], 456)
  testthat::expect_gte(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM dim_credit_activity")$n[[1]], 1112)
  testthat::expect_gte(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM dim_credit_sector")$n[[1]], 13)
  testthat::expect_gte(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM dim_entity")$n[[1]], 31)
  currency <- DBI::dbGetQuery(con, "SELECT currency_of_origin, unit_currency, economic_currency FROM dim_currency WHERE currency_code = '6200'")
  testthat::expect_identical(currency$currency_of_origin[[1]], "FX")
  testthat::expect_identical(currency$unit_currency[[1]], "PYG")
  testthat::expect_identical(currency$economic_currency[[1]], "PYG")
  accounts <- DBI::dbGetQuery(con, "SELECT account_number_raw, account_number FROM map_statement_account")
  testthat::expect_false(any(grepl("[eE][+-]?[0-9]", accounts$account_number_raw)))
  testthat::expect_true(all(grepl("^[0-9]+$", accounts$account_number)))
})

testthat::test_that("reference resolution prioritizes sheet and column signature", {
  catalog <- tibble::tibble(
    source_sheet = "Financieras", source_table = "ExcelGenerated999",
    table_range = "A1:C3", observed_columns = "A|B|C"
  )
  spec <- tibble::tibble(
    source_sheet = "Financieras", source_table_hint = "OldGeneratedName",
    semantic_role = "test", expected_columns = "A|B|C"
  )
  resolved <- resolve_reference_table(catalog, spec)
  testthat::expect_identical(resolved$source_table[[1]], "ExcelGenerated999")
})
