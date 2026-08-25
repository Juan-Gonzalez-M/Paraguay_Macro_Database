testthat::test_that("exchange-house million-row declarations are read as bounded tables", {
  path <- fs::dir_ls(file.path(project_test_root, "input", "current", "exchange_houses"), regexp = "\\.xlsm$")[[1]]
  dimensions <- xlsx_sheet_dimensions(path)
  panel <- dimensions %>% dplyr::filter(.data$sheet_name == "1. EEFF")
  testthat::expect_gte(panel$used_rows[[1]], 1000000L)
  testthat::expect_equal(panel$content_first_row[[1]], 19L)
  testthat::expect_lt(panel$content_last_row[[1]], 1000L)
  raw <- read_dimensioned_sheet(path, panel)
  testthat::expect_lt(nrow(raw), 1000L)
  testthat::expect_true(any(normalize_semantic_label(documented_text_matrix(raw)) == "fecha", na.rm = TRUE))
})

testthat::test_that("worksheet inventory skips chartsheets and uses active-cell bounds", {
  path <- fs::dir_ls(file.path(project_test_root, "input", "current", "interbank_market"), regexp = "\\.xlsx$")[[1]]
  dimensions <- xlsx_sheet_dimensions(path)
  testthat::expect_setequal(dimensions$sheet_name, c("Datos", "Datos (+ de 1 día)", "Mdo Secundario"))
  secondary <- dimensions %>% dplyr::filter(.data$sheet_name == "Mdo Secundario")
  testthat::expect_gt(secondary$used_cols[[1]], 2000L)
  testthat::expect_lte(secondary$content_last_col[[1]], 10L)
})

testthat::test_that("CSV inventory recognizes the two guarded long sources", {
  curves <- fs::dir_ls(file.path(project_test_root, "input", "current", "corporate_bond_curves"), regexp = "\\.csv$")[[1]]
  trades <- fs::dir_ls(file.path(project_test_root, "input", "current", "securities_trades"), regexp = "\\.csv$")[[1]]
  curve_dimensions <- csv_source_dimensions(curves)
  trade_dimensions <- csv_source_dimensions(trades)
  testthat::expect_equal(curve_dimensions$used_cols[[1]], 13L)
  testthat::expect_gte(curve_dimensions$used_rows[[1]], 38000L)
  testthat::expect_equal(trade_dimensions$used_cols[[1]], 12L)
  testthat::expect_gte(trade_dimensions$used_rows[[1]], 300000L)
})
