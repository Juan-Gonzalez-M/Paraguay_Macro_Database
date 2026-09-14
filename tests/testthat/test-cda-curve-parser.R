cda_workbook <- function() file.path(project_test_root, "input", "current", "Curva_CDA.xlsx")

read_cda_sheet <- function(sheet) {
  path <- cda_workbook()
  dimensions <- xlsx_sheet_dimensions(path) %>% dplyr::filter(.data$sheet_name == .env$sheet)
  testthat::expect_equal(nrow(dimensions), 1L)
  read_dimensioned_sheet(path, dimensions)
}

testthat::test_that("CDA rate curves retain published period coordinates and maturity lanes", {
  result <- documented_parse_cda_curve_sheet(read_cda_sheet("CDA_ME_072026"), "CDA_ME_072026")
  observations <- result$observations

  testthat::expect_identical(result$mode, "cda_monthly_curve")
  testthat::expect_true(all(observations$period == as.Date("2026-07-31")))
  testthat::expect_true(all(observations$source_period_label == "Datos al 31/07/2026"))
  h10 <- observations %>% dplyr::filter(.data$source_row == 10L, .data$source_column == 8L)
  testthat::expect_equal(nrow(h10), 1L)
  testthat::expect_equal(h10$value, 2.8615163478971799)
  testthat::expect_match(h10$series_label, "30 DÍAS", fixed = TRUE)
  testthat::expect_identical(h10$unit, "percent")

  long_nodes <- observations %>%
    dplyr::filter(.data$source_row %in% c(36L, 37L), .data$source_column == 8L)
  testthat::expect_setequal(
    stringr::str_extract(long_nodes$series_label, "3600 DÍAS[+]?") ,
    c("3600 DÍAS", "3600 DÍAS+")
  )
})

testthat::test_that("CDA activity curves preserve counts volumes and currency-origin wording", {
  result <- documented_parse_cda_curve_sheet(
    read_cda_sheet("OPERACIONES_VOLUMEN_ME_072026"), "OPERACIONES_VOLUMEN_ME_072026"
  )
  observations <- result$observations
  count <- observations %>% dplyr::filter(.data$source_row == 12L, .data$source_column == 5L)
  volume <- observations %>% dplyr::filter(.data$source_row == 12L, .data$source_column == 7L)

  testthat::expect_equal(count$value, 57)
  testthat::expect_identical(count$unit, "count")
  testthat::expect_equal(volume$value, 73535547408)
  testthat::expect_identical(volume$unit, "source_units")
  testthat::expect_identical(volume$scale, "units")
  testthat::expect_true(is.na(volume$currency))
  testthat::expect_match(volume$series_path, "MONEDA EXTRANJERA", fixed = TRUE)
  testthat::expect_equal(
    nrow(observations),
    nrow(dplyr::distinct(observations, .data$source_row, .data$source_column))
  )
})

testthat::test_that("CDA parsing uses cell evidence rather than historical sheet suffixes", {
  cases <- c(
    "CDA_ML_0621" = "2021-06-30",
    "OPERACIONES_VOLUMEN_ME_0622" = "2022-06-30",
    "OPERACIONES_VOLUMEN_ML_1220201" = "2021-12-31"
  )
  for (sheet in names(cases)) {
    result <- documented_parse_cda_curve_sheet(read_cda_sheet(sheet), sheet)
    testthat::expect_true(all(result$observations$period == as.Date(cases[[sheet]])), info = sheet)
  }
})

testthat::test_that("CDA missing institution headers remain explicit and unresolved", {
  result <- documented_parse_cda_curve_sheet(read_cda_sheet("CDA_ML_102021"), "CDA_ML_102021")
  testthat::expect_true(any(stringr::str_detect(result$observations$series_label, "UNLABELED COLUMN H")))
  testthat::expect_true(any(stringr::str_detect(result$observations$series_label, "UNLABELED COLUMN I")))
  testthat::expect_identical(result$hierarchy_status, "unresolved")
})

testthat::test_that("CDA anomalous numeric cells are retained under unresolved identities", {
  extra <- documented_parse_cda_curve_sheet(
    read_cda_sheet("OPERACIONES_VOLUMEN_ML_072025"), "OPERACIONES_VOLUMEN_ML_072025"
  )$observations
  o12 <- extra %>% dplyr::filter(.data$source_row == 12L, .data$source_column == 15L)
  testthat::expect_equal(o12$value, 35603423)
  testthat::expect_match(o12$series_label, "Monto Capital Original", fixed = TRUE)
  testthat::expect_match(o12$series_label, "INSTITUTION NOT PUBLISHED", fixed = TRUE)

  unlabeled <- documented_parse_cda_curve_sheet(
    read_cda_sheet("OPERACIONES_VOLUMEN_ML_062025"), "OPERACIONES_VOLUMEN_ML_062025"
  )$observations %>% dplyr::filter(.data$source_row == 40L, .data$source_column == 7L)
  testthat::expect_equal(unlabeled$value, 1748724340582)
  testthat::expect_match(unlabeled$series_label, "UNLABELED ROW 40", fixed = TRUE)
})
