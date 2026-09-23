testthat::test_that("MEF central-government parser preserves monthly flows and excludes formulas", {
  path <- Sys.glob(file.path(project_test_root, "input", "current", "*MEFP*.xlsx"))
  testthat::expect_length(path, 1L)
  dimensions <- xlsx_sheet_dimensions(path)
  result <- documented_parse_mef_central_government(
    read_dimensioned_sheet(path, dimensions[1, ]), "Serie"
  )
  formulas <- xlsx_formula_cell_coordinates(dimensions)
  formula_key <- paste(formulas$row_id, formulas$column_id, sep = ":")
  observations <- result$observations[
    !paste(result$observations$source_row, result$observations$source_column, sep = ":") %in% formula_key,
  ]
  testthat::expect_equal(nrow(observations), 23108L)
  testthat::expect_equal(min(observations$period), as.Date("2003-01-01"))
  testthat::expect_equal(max(observations$period), as.Date("2026-08-01"))
  testthat::expect_setequal(unique(observations$unit), "PYG")
  testthat::expect_setequal(unique(observations$scale), "billions")
  testthat::expect_false(any(paste(observations$source_row, observations$source_column, sep = ":") %in% formula_key))
  testthat::expect_true(any(observations$source_row == 11L & observations$source_column == 3L))
})

testthat::test_that("INE EPHC parser retains calendar quarters and all non-formula values", {
  path <- file.path(project_test_root, "input", "current", "Anexo_EPHC_2017-2026.xlsx")
  dimensions <- xlsx_sheet_dimensions(path)
  formulas <- xlsx_formula_cell_coordinates(dimensions)
  collected <- list()
  for (i in seq_len(nrow(dimensions))) {
    sheet <- dimensions$sheet_name[[i]]
    result <- documented_parse_ine_ephc_sheet(read_dimensioned_sheet(path, dimensions[i, ]), sheet)
    observations <- result$observations
    sheet_formulas <- formulas[formulas$sheet_name == sheet, , drop = FALSE]
    if (nrow(observations) && nrow(sheet_formulas)) {
      observations <- observations[
        !paste(observations$source_row, observations$source_column, sep = ":") %in%
          paste(sheet_formulas$row_id, sheet_formulas$column_id, sep = ":"),
      ]
    }
    collected[[sheet]] <- observations
  }
  observations <- dplyr::bind_rows(collected)
  testthat::expect_equal(nrow(observations), 27017L)
  testthat::expect_equal(min(observations$period), as.Date("2017-01-01"))
  testthat::expect_equal(max(observations$period), as.Date("2026-04-01"))
  testthat::expect_true(all(format(observations$period, "%m-%d") %in% c("01-01", "04-01", "07-01", "10-01")))
  testthat::expect_equal(nrow(collected$Hoja2), 0L)
  testthat::expect_false(any(
    paste(observations$source_sheet, observations$source_row, observations$source_column, sep = ":") %in%
      paste(formulas$sheet_name, formulas$row_id, formulas$column_id, sep = ":")
  ))
  testthat::expect_true(any(observations$source_sheet == "Tasas" & observations$source_row == 6L & observations$source_column == 3L))
})
