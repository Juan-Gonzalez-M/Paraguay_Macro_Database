testthat::test_that("fresh bootstrap installs v11 without running historical invalidations", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  testthat::expect_no_error(initialize_database(con))
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 11")$n[[1]],
    1
  )
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM source_files")$n[[1]], 0)
})

testthat::test_that("annotated years are accepted without accepting arbitrary numeric labels", {
  values <- c("2012 1/", "2021 (*)", "2026***", "2080.5", "Value 2020", "1899")
  testthat::expect_identical(
    documented_year_values(values),
    c(2012L, 2021L, 2026L, NA_integer_, NA_integer_, NA_integer_)
  )
})

testthat::test_that("year-axis selection requires an ordered sequence", {
  text <- matrix(NA_character_, nrow = 14L, ncol = 4L)
  text[1, 1] <- "Año"
  text[c(2, 6, 10, 14), 1] <- c("2020", "2021 1/", "2022 (*)", "2023***")
  text[, 2] <- as.character(c(2080, 1940, 2033, 1999, 2044, 2010, 2098, 1962, 2025, 1901, 2060, 1977, 2051, 1910))
  testthat::expect_identical(documented_year_axis_index(text, margin = 2L), 1L)
})

testthat::test_that("Annex CUADRO 58 uses its annotated first-column year axis", {
  path <- fs::dir_ls(
    file.path(project_test_root, "input", "current", "economic_annex"), regexp = "\\.xlsx$"
  )[[1]]
  dimensions <- xlsx_sheet_dimensions(path)
  dimension <- dimensions %>% dplyr::filter(toupper(.data$sheet_name) == "CUADRO 58")
  result <- documented_extract_generic_sheet(read_dimensioned_sheet(path, dimension), "CUADRO 58")
  testthat::expect_identical(result$mode, "vertical_block")
  testthat::expect_equal(min(result$observations$period), as.Date("2008-01-31"))
  testthat::expect_equal(max(result$observations$period), as.Date("2026-12-31"))
  testthat::expect_true(all(lubridate::year(result$observations$period) %in% 2008:2026))
  testthat::expect_true(all(c("annual", "monthly") %in% result$observations$frequency))
  testthat::expect_false(any(stringr::str_detect(result$observations$series_label, "^[0-9]")))
})

testthat::test_that("v11 migration invalidates only the economic Annex", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  initialize_database(con)
  DBI::dbExecute(con, "DELETE FROM schema_version WHERE version = 11")
  DBI::dbExecute(con, paste0(
    "INSERT INTO source_files (vintage_id, source_id, ingestion_status) VALUES ",
    "('annex:v10', 'economic_annex', 'completed'), ",
    "('payments:v10', 'payments', 'completed')"
  ))
  DBI::dbExecute(con, paste0(
    "INSERT INTO dim_series (series_id, source_id, semantic_status) VALUES ",
    "('annex:series', 'economic_annex', 'documented_series'), ",
    "('payments:series', 'payments', 'documented_series')"
  ))
  DBI::dbExecute(con, paste0(
    "INSERT INTO dim_concept (concept_id, mapping_status) VALUES ",
    "('concept:annex', 'source_specific_unreviewed'), ",
    "('concept:payments', 'source_specific_unreviewed')"
  ))
  DBI::dbExecute(con, paste0(
    "INSERT INTO map_series_concept (series_id, concept_id, mapping_status) VALUES ",
    "('annex:series', 'concept:annex', 'source_specific_unreviewed'), ",
    "('payments:series', 'concept:payments', 'source_specific_unreviewed')"
  ))
  testthat::expect_true(invalidate_v10_annex_year_axis(con))
  statuses <- DBI::dbGetQuery(con, "SELECT source_id, ingestion_status FROM source_files")
  testthat::expect_identical(
    statuses$ingestion_status[statuses$source_id == "economic_annex"], "needs_v11_reingestion"
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
})
