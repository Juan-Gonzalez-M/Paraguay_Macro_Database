testthat::test_that("insurance parser handles the published sheet without an Ejercicio header", {
  path <- fs::dir_ls(file.path(project_test_root, "input", "current", "insurance_annex"), regexp = "\\.xlsx$")[[1]]
  dimensions <- xlsx_sheet_dimensions(path) %>% dplyr::filter(.data$sheet_name == "1.38")
  raw <- read_dimensioned_sheet(path, dimensions)
  result <- documented_parse_insurance_sheet(raw, "1.38")
  testthat::expect_gt(nrow(result$observations), 50L)
  testthat::expect_true(all(result$observations$unit == "PYG"))
  testthat::expect_equal(min(result$observations$period), as.Date("2009-06-30"))
})

testthat::test_that("daily exchange-rate parser covers every published currency block", {
  path <- fs::dir_ls(file.path(project_test_root, "input", "current", "exchange_rates"), regexp = "\\.xlsx$")[[1]]
  dimensions <- xlsx_sheet_dimensions(path) %>% dplyr::filter(.data$sheet_name == "Cotizaciones Diarias")
  raw <- read_dimensioned_sheet(path, dimensions)
  item <- tibble::tibble(source_id = "exchange_rates")
  result <- documented_parse_daily_exchange_rates(raw, "Cotizaciones Diarias", item)
  testthat::expect_gte(dplyr::n_distinct(result$observations$currency), 14L)
  testthat::expect_gt(nrow(result$observations), 600L)
  testthat::expect_true(all(result$observations$unit != "source_units"))
})

testthat::test_that("liquidity parser keeps deposit and repo blocks distinct", {
  path <- fs::dir_ls(file.path(project_test_root, "input", "current", "liquidity_facility"), regexp = "\\.xlsx$")[[1]]
  dimensions <- xlsx_sheet_dimensions(path)
  raw <- read_dimensioned_sheet(path, dimensions)
  result <- documented_parse_row_events(
    raw, "ADM- LIQ- DEPOSITO", "fecha de liquidacion",
    c("^plazos"),
    "short_term_liquidity_auction",
    block_patterns = c(deposito = "deposit", repo = "repo")
  )
  labels <- normalize_semantic_label(result$observations$series_label)
  testthat::expect_gt(nrow(result$observations), 3000L)
  testthat::expect_true(any(stringr::str_detect(labels, "deposito")))
  testthat::expect_true(any(stringr::str_detect(labels, "repo")))
  testthat::expect_false(any(stringr::str_detect(normalize_semantic_label(result$observations$measure), "^plazos")))
  testthat::expect_identical(result$mode, "row_event_table")
})

testthat::test_that("direct-investment quarter tables retain published annual totals", {
  path <- fs::dir_ls(file.path(project_test_root, "input", "current", "direct_investment"), regexp = "\\.xlsx$")[[1]]
  dimensions <- xlsx_sheet_dimensions(path) %>% dplyr::filter(.data$sheet_name == "Cuadro 1")
  raw <- read_dimensioned_sheet(path, dimensions)
  result <- documented_extract_generic_sheet(raw, "Cuadro 1")
  testthat::expect_identical(result$mode, "horizontal_year_quarter")
  testthat::expect_true(all(c("quarterly", "annual") %in% result$observations$frequency))
})
