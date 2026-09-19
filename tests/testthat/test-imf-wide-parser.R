testthat::test_that("IMF envelope parser preserves inner semicolons and coordinates", {
  path <- tempfile(fileext = ".csv")
  writeLines(c(
    '"DATASET,""SERIES_CODE"",""OBS_MEASURE"",""COUNTRY"",""INDICATOR"",""FREQUENCY"",""2026-M01""";',
    '"IMF.STA:TEST(1.0.0),""PRY.X.M"",""OBS_VALUE"",""Paraguay"",""First; second"",""Monthly"",""12.5""";'
  ), path, useBytes = TRUE)
  parsed <- imf_read_wide_export(path)
  testthat::expect_equal(parsed$INDICATOR, "First; second")
  testthat::expect_equal(parsed$source_record, 2L)
  normalized <- imf_normalize_wide_export(parsed)
  testthat::expect_equal(normalized$value, 12.5)
  testthat::expect_equal(normalized$published_period, "2026-M01")
  testthat::expect_equal(normalized$period_start, as.Date("2026-01-01"))
  testthat::expect_equal(normalized$period_end, as.Date("2026-01-31"))
  testthat::expect_equal(normalized$source_column, 7L)
})

testthat::test_that("IMF parser restores metadata records split across physical lines", {
  path <- tempfile(fileext = ".csv")
  writeLines(c(
    '"DATASET,""SERIES_CODE"",""OBS_MEASURE"",""COUNTRY"",""NOTE_1"",""NOTE_2"",""FREQUENCY"",""2026-M01""";',
    '"IMF.STA:TEST(1.0.0),""PRY.X.M"",""OBS_VALUE"",""Paraguay"",""First note"""',
    '"""Second note"",""Monthly"",""1""";'
  ), path, useBytes = TRUE)
  parsed <- imf_read_wide_export(path)
  testthat::expect_equal(nrow(parsed), 1L)
  testthat::expect_equal(parsed$physical_start, 2L)
  testthat::expect_equal(parsed$physical_end, 3L)
  testthat::expect_equal(ncol(parsed) - 4L, 8L)
})

testthat::test_that("IMF parser converts Windows-1252 source text to UTF-8", {
  path <- tempfile(fileext = ".csv")
  text <- paste0(
    '"DATASET,""SERIES_CODE"",""OBS_MEASURE"",""COUNTRY"",""INDICATOR"",',
    '""FREQUENCY"",""2026-M01""";\r\n',
    '"IMF.STA:TEST(1.0.0),""PRY.X.M"",""OBS_VALUE"",""Paraguay"",',
    '""Producci\u00f3n"",""Monthly"",""1""";\r\n'
  )
  bytes <- iconv(text, from = "UTF-8", to = "windows-1252", toRaw = TRUE)[[1]]
  writeBin(bytes, path)
  parsed <- imf_read_wide_export(path)
  testthat::expect_equal(attr(parsed, "imf_encoding"), "windows-1252")
  testthat::expect_equal(parsed$INDICATOR, "Producci\u00f3n")
})

testthat::test_that("pilot IMF files reproduce the discovery census when present", {
  root <- project_test_root
  folder <- file.path(root, "input", "current", "IMF_Data")
  expected <- c(
    "Consumer Price Index (CPI).csv" = 130548,
    "Exchange Rates (ER).csv" = 105780,
    "Effective Exchange Rate (EER).csv" = 9030,
    "National Economic Accounts (NEA), Quarterly Data.csv" = 29632,
    "Commodity Terms of Trade (CTOT).csv" = 60156
  )
  if (!dir.exists(folder)) testthat::skip("IMF pilot inputs are not present")
  for (file in names(expected)) {
    parsed <- imf_read_wide_export(file.path(folder, file))
    normalized <- imf_normalize_wide_export(parsed)
    testthat::expect_equal(nrow(normalized), unname(expected[[file]]), info = file)
    testthat::expect_true(all(normalized$physical_start <= normalized$physical_end), info = file)
    testthat::expect_identical(anyDuplicated(normalized[c("DATASET", "SERIES_CODE", "OBS_MEASURE", "published_period")]), 0L, info = file)
  }
})

testthat::test_that("FSI textual metadata remains separate from numeric observations", {
  path <- file.path(
    project_test_root, "input", "current", "IMF_Data",
    "Financial Soundness Indicators (FSI), Country Metadata Table 2.csv"
  )
  if (!file.exists(path)) testthat::skip("IMF FSI metadata input is not present")
  parsed <- imf_read_wide_export(path)
  normalized <- imf_normalize_wide_export(parsed)
  testthat::expect_equal(nrow(parsed), 1988L)
  testthat::expect_equal(length(unique(parsed$SERIES_CODE)), 497L)
  testthat::expect_equal(nrow(normalized), 101095L)
  testthat::expect_false(any(normalized$OBS_MEASURE == "OBS_VALUE"))
  testthat::expect_true(all(is.na(normalized$value)))
  testthat::expect_true(all(nzchar(normalized$raw_value)))
})

testthat::test_that("experimental IMF files reproduce their governed census", {
  folder <- file.path(project_test_root, "input", "current", "IMF_Data")
  expected <- c(
    "Reported Social Unrest Index (RSUI).csv" = 6992,
    "Working Paper Foreign Exchange Intervention (WPFXI) A Dataset of Public Data and Proxies.csv" = 34541
  )
  if (!dir.exists(folder)) testthat::skip("IMF experimental inputs are not present")
  for (file in names(expected)) {
    parsed <- imf_read_wide_export(file.path(folder, file))
    normalized <- imf_normalize_wide_export(parsed)
    testthat::expect_equal(nrow(normalized), unname(expected[[file]]), info = file)
    testthat::expect_true(all(normalized$OBS_MEASURE == "OBS_VALUE"), info = file)
    testthat::expect_identical(
      anyDuplicated(normalized[c("DATASET", "SERIES_CODE", "OBS_MEASURE", "published_period")]),
      0L, info = file
    )
  }
})

testthat::test_that("IMF dataset identity keeps agency dataflow and version separate", {
  identity <- imf_dataset_identity("IMF.STA:CPI(5.0.0)")
  testthat::expect_equal(identity$agency, "IMF.STA")
  testthat::expect_equal(identity$dataflow, "CPI")
  testthat::expect_equal(identity$version, "5.0.0")
})
