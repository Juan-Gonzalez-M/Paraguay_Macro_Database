tcn_workbook <- function() {
  file.path(project_test_root, "input", "current", "TCN_Referencial_Diario.xlsx")
}

tcn_parsed_workbook <- function() {
  path <- tcn_workbook()
  dimensions <- xlsx_sheet_dimensions(path)
  documented_validate_daily_calendar_grid_workbook(dimensions)
  observations <- dplyr::bind_rows(lapply(seq_len(nrow(dimensions)), function(i) {
    documented_parse_daily_calendar_grid(
      read_dimensioned_sheet(path, dimensions[i, ]), dimensions$sheet_name[[i]]
    )$observations
  }))
  list(path = path, dimensions = dimensions, observations = observations)
}

testthat::test_that("TCN daily calendar grids retain exact dates, values and coordinates", {
  parsed <- tcn_parsed_workbook()
  observations <- parsed$observations

  testthat::expect_equal(nrow(observations), 7004L)
  testthat::expect_equal(
    dplyr::n_distinct(paste(
      observations$source_sheet, observations$source_row, observations$source_column
    )),
    7004L
  )
  testthat::expect_equal(min(observations$period), as.Date("2012-08-06"))
  testthat::expect_equal(max(observations$period), as.Date("2026-08-25"))
  testthat::expect_setequal(unique(observations$series_label), c("Compra", "Venta"))
  testthat::expect_true(all(observations$frequency == "daily"))
  testthat::expect_true(all(observations$unit == "PYG_per_USD"))
  testthat::expect_true(all(observations$scale == "units"))
  testthat::expect_true(all(observations$currency == "PYG/USD"))

  representative <- observations %>%
    dplyr::filter(
      (.data$source_sheet == "2012_Compra" & .data$source_row == 8L & .data$source_column == 9L) |
        (.data$source_sheet == "2024_Venta" & .data$source_row == 6L & .data$source_column == 2L) |
        (.data$source_sheet == "2026_Venta" & .data$source_row == 27L & .data$source_column == 9L)
    ) %>%
    dplyr::arrange(.data$period)
  testthat::expect_equal(
    representative$period,
    as.Date(c("2012-08-06", "2024-01-04", "2026-08-25"))
  )
  testthat::expect_equal(representative$value, c(4410.97, 7257.10, 5989.78))
  testthat::expect_equal(representative$source_period_label, c(
    "6 AGO 2012", "4 ENE 2024", "25 AGO 2026"
  ))
})

testthat::test_that("TCN ND cells remain raw non-business-day evidence", {
  parsed <- tcn_parsed_workbook()
  dimensions <- parsed$dimensions
  nd_cells <- 0L
  for (i in seq_len(nrow(dimensions))) {
    text <- documented_text_matrix(read_dimensioned_sheet(parsed$path, dimensions[i, ]))
    nd_cells <- nd_cells + sum(text[3:33, 2:13, drop = FALSE] == "ND", na.rm = TRUE)
  }
  testthat::expect_equal(nd_cells, 4156L)
  testthat::expect_false(any(
    parsed$observations$source_sheet == "2012_Compra" &
      parsed$observations$source_row == 3L & parsed$observations$source_column == 2L
  ))

  damaged_dimension <- dimensions %>% dplyr::filter(.data$sheet_name == "2021_Compra")
  damaged <- documented_parse_daily_calendar_grid(
    read_dimensioned_sheet(parsed$path, damaged_dimension), "2021_Compra"
  )
  testthat::expect_identical(damaged$title, "}")
  testthat::expect_true(all(damaged$observations$table_title == "}"))
})

testthat::test_that("TCN calendar-grid guards fail on token and calendar drift", {
  path <- tcn_workbook()
  dimensions <- xlsx_sheet_dimensions(path)
  dimension <- dimensions %>% dplyr::filter(.data$sheet_name == "2024_Compra")
  raw <- read_dimensioned_sheet(path, dimension)

  token_drift <- raw
  token_drift[[2]][[3]] <- "N/D"
  testthat::expect_error(
    documented_parse_daily_calendar_grid(token_drift, "2024_Compra"),
    "numeric value or exact ND at B3"
  )

  invalid_date <- raw
  invalid_date[[3]][[32]] <- 1
  testthat::expect_error(
    documented_parse_daily_calendar_grid(invalid_date, "2024_Compra"),
    "numeric value occupies invalid calendar cell C32"
  )

  range_drift <- dimensions
  range_drift$used_rows[[1]] <- 34L
  testthat::expect_error(
    documented_validate_daily_calendar_grid_workbook(range_drift), "exactly A1:M33"
  )
})

testthat::test_that("TCN annual worksheets join the reviewed Compra and Venta continuities", {
  parsed <- tcn_parsed_workbook()
  observations <- parsed$observations %>%
    dplyr::mutate(hierarchy_status = "flat", identity_sheet = "TCN_REFERENCIAL_DAILY")
  finalized <- documented_finalize_observations(
    observations,
    list(
      source_id = "tcn_referential_daily",
      vintage_id = "tcn_referential_daily:test",
      source_file = "TCN_Referencial_Diario.xlsx"
    ),
    "release:test", as.Date(NA)
  )

  testthat::expect_equal(dplyr::n_distinct(finalized$series_id), 2L)
  testthat::expect_equal(anyDuplicated(finalized[c("series_id", "period")]), 0L)
  testthat::expect_true(all(finalized$identity_stability == "semantic"))
  testthat::expect_true(all(is.na(finalized$publication_date)))
  testthat::expect_equal(
    finalized %>% dplyr::count(.data$series_label, name = "observations") %>%
      dplyr::arrange(.data$series_label),
    tibble::tibble(series_label = c("Compra", "Venta"), observations = c(3502L, 3502L))
  )
})
