testthat::test_that("real formula-only exchange-house sheets have consistent empty bounds", {
  path <- fs::dir_ls(
    file.path(project_test_root, "input", "current", "exchange_houses"),
    regexp = "\\.(xlsx|xlsm)$"
  )[[1]]
  empty_views <- c("1.1 BG", "1.2 EERR", "2.1 Ratios", "3.1 Dep y P.")
  dimensions <- xlsx_sheet_dimensions(path) %>%
    dplyr::filter(.data$sheet_name %in% .env$empty_views)
  testthat::expect_setequal(dimensions$sheet_name, empty_views)
  for (sheet in empty_views) {
    dimension <- dimensions %>% dplyr::filter(.data$sheet_name == .env$sheet)
    raw <- read_dimensioned_sheet(path, dimension)
    testthat::expect_no_error(cells_from_matrix(raw), info = sheet)
    if (dimension$content_last_col[[1]] == 0L) {
      testthat::expect_identical(dim(raw), c(0L, 0L), info = sheet)
      testthat::expect_identical(dim(documented_text_matrix(raw)), c(0L, 0L), info = sheet)
      testthat::expect_identical(dim(documented_number_matrix(raw)), c(0L, 0L), info = sheet)
      testthat::expect_identical(dim(documented_date_matrix(raw, documented_text_matrix(raw))), c(0L, 0L), info = sheet)
    }
  }
  truly_empty <- dimensions %>% dplyr::filter(.data$sheet_name %in% c("2.1 Ratios", "3.1 Dep y P."))
  testthat::expect_true(all(truly_empty$content_last_row == 0L))
  testthat::expect_true(all(truly_empty$content_last_col == 0L))
})

testthat::test_that("Annex date extraction stops before summary and footnote rows", {
  path <- fs::dir_ls(
    file.path(project_test_root, "input", "current", "economic_annex"), regexp = "\\.xlsx$"
  )[[1]]
  dimension <- xlsx_sheet_dimensions(path) %>% dplyr::filter(.data$sheet_name == "Cuadro 49")
  result <- documented_extract_generic_sheet(read_dimensioned_sheet(path, dimension), "Cuadro 49")
  testthat::expect_identical(result$mode, "vertical_date")
  testthat::expect_equal(max(result$observations$period), as.Date("2028-12-01"))
  testthat::expect_lte(max(result$observations$source_row), 431L)
  testthat::expect_false(any(result$observations$period > as.Date("2030-12-31")))
})

testthat::test_that("exchange-rate histories use every validated consecutive-year block", {
  path <- fs::dir_ls(
    file.path(project_test_root, "input", "current", "exchange_rates"), regexp = "\\.xlsx$"
  )[[1]]
  sheets <- c("USD Prom", "EURO Fin Mes", "EURO Prom", "REAL Fin Mes", "PESO Fin Mes")
  dimensions <- xlsx_sheet_dimensions(path)
  observations <- lapply(sheets, function(sheet) {
    dimension <- dimensions %>% dplyr::filter(.data$sheet_name == .env$sheet)
    documented_parse_exchange_rate_history(read_dimensioned_sheet(path, dimension), sheet)$observations
  }) %>% dplyr::bind_rows()
  testthat::expect_gt(nrow(observations), 3000L)
  testthat::expect_lte(max(observations$period), as.Date("2026-12-31"))
  testthat::expect_false(any(lubridate::year(observations$period) == 2080L))
  testthat::expect_true(all(c("compra", "venta") %in% normalize_semantic_label(observations$measure)))
})

testthat::test_that("year-header context rejects isolated exchange-rate values", {
  text <- matrix(NA_character_, nrow = 3L, ncol = 8L)
  text[1, c(2, 5, 8)] <- c("2020", "2021", "2022")
  text[2, 1:4] <- c("Enero", "1940", "1945", "2080")
  testthat::expect_identical(documented_consecutive_year_rows(text), 1L)
})

testthat::test_that("continuity SQL executes with explicit aliases on a second vintage", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  initialize_database(con)
  DBI::dbExecute(con, paste0(
    "INSERT INTO source_files (vintage_id, source_id, publication_date, first_ingested_at, ingestion_status) VALUES ",
    "('annex:old', 'economic_annex', DATE '2026-07-31', current_timestamp, 'completed'), ",
    "('annex:new', 'economic_annex', DATE '2026-08-31', current_timestamp, 'started')"
  ))
  DBI::dbExecute(con, paste0(
    "INSERT INTO documented_series_snapshot ",
    "(vintage_id, source_id, source_sheet, series_id, series_label, unit, scale, currency, identity_stability, period, value) VALUES ",
    "('annex:old', 'economic_annex', 'Sheet', 'series:1', 'Series', 'index', 'units', NULL, 'semantic', DATE '2026-06-30', 1), ",
    "('annex:new', 'economic_annex', 'Sheet', 'series:1', 'Series', 'index', 'units', NULL, 'semantic', DATE '2026-06-30', 1)"
  ))
  item <- tibble::tibble(source_id = "economic_annex", vintage_id = "annex:new")
  testthat::expect_no_error(
    validate_documented_series_continuity(con, item, "release:test", project_test_root)
  )
})

testthat::test_that("schema v10 is installed", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  initialize_database(con)
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 10")$n[[1]],
    1
  )
})

testthat::test_that("v10 migration invalidates only affected documented sources", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  initialize_database(con)
  DBI::dbExecute(con, "DELETE FROM schema_version WHERE version = 10")
  DBI::dbExecute(con, paste0(
    "INSERT INTO source_files (vintage_id, source_id, ingestion_status) VALUES ",
    "('annex:v9', 'economic_annex', 'completed'), ",
    "('payments:v9', 'payments', 'completed')"
  ))
  DBI::dbExecute(con, paste0(
    "INSERT INTO dim_series (series_id, source_id, semantic_status) VALUES ",
    "('annex:series', 'economic_annex', 'documented_series'), ",
    "('payments:series', 'payments', 'documented_series')"
  ))
  DBI::dbExecute(con, paste0(
    "INSERT INTO dim_concept (concept_id, mapping_status) VALUES ",
    "('concept:annex', 'source_specific_unreviewed'), ",
    "('concept:payments', 'source_specific_unreviewed'), ",
    "('concept:unrelated-orphan', 'source_specific_unreviewed')"
  ))
  DBI::dbExecute(con, paste0(
    "INSERT INTO map_series_concept (series_id, concept_id, mapping_status) VALUES ",
    "('annex:series', 'concept:annex', 'source_specific_unreviewed'), ",
    "('payments:series', 'concept:payments', 'source_specific_unreviewed')"
  ))
  invalidate_v9_runtime_repairs(con)
  statuses <- DBI::dbGetQuery(con, "SELECT source_id, ingestion_status FROM source_files")
  testthat::expect_identical(
    statuses$ingestion_status[statuses$source_id == "economic_annex"], "needs_v10_reingestion"
  )
  testthat::expect_identical(
    statuses$ingestion_status[statuses$source_id == "payments"], "completed"
  )
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM dim_series WHERE series_id = 'annex:series'")$n[[1]], 0
  )
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM dim_series WHERE series_id = 'payments:series'")$n[[1]], 1
  )
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM dim_concept WHERE concept_id = 'concept:annex'")$n[[1]], 0
  )
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM dim_concept WHERE concept_id = 'concept:payments'")$n[[1]], 1
  )
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM dim_concept WHERE concept_id = 'concept:unrelated-orphan'")$n[[1]], 1
  )
})
