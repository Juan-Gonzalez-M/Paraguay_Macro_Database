testthat::test_that("LRM parser preserves both header levels and reconciles real cells", {
  path <- file.path(project_test_root, "input", "current", "lrm_auctions", "Subasta de LRM_WEB.xlsx")
  dimensions <- xlsx_sheet_dimensions(path)
  expected_sheets <- paste0("Subastas ", 2013:2026)
  expected_sheets[expected_sheets == "Subastas 2015"] <- "Subastas 2015 "
  testthat::expect_setequal(dimensions$sheet_name, expected_sheets)
  all <- lapply(seq_len(nrow(dimensions)), function(i) {
    raw <- read_dimensioned_sheet(path, dimensions[i, ])
    parsed <- documented_parse_lrm_auction_sheet(raw, dimensions$sheet_name[[i]])$observations
    numbers <- documented_number_matrix(raw)
    data_rows <- unique(parsed$source_row)
    testthat::expect_equal(nrow(parsed), sum(!is.na(numbers[data_rows, 6:16, drop = FALSE])))
    testthat::expect_equal(sum(duplicated(parsed[c("source_row", "source_column")])), 0L)
    parsed$identity_sheet <- "lrm_auction_events"
    parsed$hierarchy_status <- "flat"
    parsed
  })
  observations <- dplyr::bind_rows(all)
  testthat::expect_equal(nrow(observations), 10351L)
  testthat::expect_setequal(unique(observations$measure), c(
    "announced_amount", "offered_amount", "assigned_amount", "offered_bid_count",
    "assigned_bid_count", "offered_average_rate", "offered_minimum_rate",
    "offered_maximum_rate", "assigned_average_rate", "assigned_minimum_rate",
    "assigned_maximum_rate"
  ))
  testthat::expect_false(any(observations$series_label %in% c("Promedio", "Minima", "Maxima")))
  testthat::expect_true(all(observations$unit[grepl("_rate$", observations$measure)] == "source_units"))
  testthat::expect_true(all(observations$unit[grepl("_amount$", observations$measure)] == "PYG"))
  testthat::expect_true(all(observations$scale[grepl("_amount$", observations$measure)] == "millions"))

  finalized <- documented_finalize_observations(
    observations,
    list(source_id = "lrm_auctions", vintage_id = "test:vintage", source_file = basename(path)),
    "release:test", as.Date("2026-07-30")
  )
  testthat::expect_equal(dplyr::n_distinct(finalized$series_id), 957L)
  testthat::expect_equal(dplyr::n_distinct(
    finalized$series_id[finalized$identity_stability == "positional_lane"]
  ), 39L)
  testthat::expect_equal(sum(duplicated(finalized[c("series_id", "period")])), 0L)
  testthat::expect_false(any(grepl("Subastas 20", finalized$identity_basis)))

  repeated <- documented_finalize_observations(
    observations,
    list(source_id = "lrm_auctions", vintage_id = "test:vintage", source_file = basename(path)),
    "release:test", as.Date("2026-07-30")
  )
  testthat::expect_identical(finalized$series_id, repeated$series_id)
})

testthat::test_that("LRM early, middle and recent sheets keep offered and assigned rates separate", {
  path <- file.path(project_test_root, "input", "current", "lrm_auctions", "Subasta de LRM_WEB.xlsx")
  dimensions <- xlsx_sheet_dimensions(path)
  for (sheet in c("Subastas 2013", "Subastas 2020", "Subastas 2026")) {
    raw <- read_dimensioned_sheet(path, dimensions[dimensions$sheet_name == sheet, ])
    observations <- documented_parse_lrm_auction_sheet(raw, sheet)$observations
    row <- min(observations$source_row)
    offered <- observations[observations$source_row == row & observations$measure == "offered_average_rate", ]
    assigned <- observations[observations$source_row == row & observations$measure == "assigned_average_rate", ]
    testthat::expect_equal(offered$source_column, 11L)
    testthat::expect_equal(assigned$source_column, 14L)
    testthat::expect_match(offered$series_label, "ofertada")
    testthat::expect_match(assigned$series_label, "asignada")
  }
})
