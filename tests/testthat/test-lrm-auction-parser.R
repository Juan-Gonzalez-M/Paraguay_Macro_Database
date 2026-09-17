testthat::test_that("LRM parser preserves both header levels and reconciles real cells", {
  path <- file.path(project_test_root, "input", "current", "lrm_auctions", "Subasta de LRM_WEB.xlsx")
  dimensions <- xlsx_sheet_dimensions(path)
  expected_sheets <- paste0("Subastas ", 2013:2026)
  expected_sheets[expected_sheets == "Subastas 2015"] <- "Subastas 2015 "
  testthat::expect_setequal(dimensions$sheet_name, expected_sheets)
  all <- lapply(seq_len(nrow(dimensions)), function(i) {
    raw <- read_dimensioned_sheet(path, dimensions[i, ])
    result <- documented_parse_lrm_auction_sheet(raw, dimensions$sheet_name[[i]], project_test_root)
    parsed <- result$observations
    source <- result$component_observations
    numbers <- documented_number_matrix(raw)
    data_rows <- unique(source$source_row)
    testthat::expect_equal(nrow(source), sum(!is.na(numbers[data_rows, 6:16, drop = FALSE])))
    testthat::expect_equal(sum(duplicated(source[c("source_row", "source_column")])), 0L)
    parsed$identity_sheet <- "lrm_auction_events"
    parsed$hierarchy_status <- "flat"
    parsed
  })
  observations <- dplyr::bind_rows(all)
  testthat::expect_equal(nrow(observations), 10334L)
  testthat::expect_setequal(unique(observations$measure), c(
    "announced_amount", "offered_amount", "assigned_amount", "offered_bid_count",
    "assigned_bid_count", "offered_average_rate", "offered_minimum_rate",
    "offered_maximum_rate", "assigned_average_rate", "assigned_minimum_rate",
    "assigned_maximum_rate"
  ))
  testthat::expect_false(any(observations$series_label %in% c("Promedio", "Minima", "Maxima")))
  testthat::expect_true(all(observations$unit[grepl("_rate$", observations$measure)] == "percent_per_annum"))
  testthat::expect_true(all(observations$unit[grepl("_amount$", observations$measure)] == "PYG"))
  testthat::expect_true(all(observations$scale[grepl("_amount$", observations$measure)] == "millions"))

  finalized <- documented_finalize_observations(
    observations,
    list(source_id = "lrm_auctions", vintage_id = "test:vintage", source_file = basename(path)),
    "release:test", as.Date("2026-07-30")
  )
  testthat::expect_equal(dplyr::n_distinct(finalized$series_id), 940L)
  testthat::expect_equal(dplyr::n_distinct(
    finalized$series_id[finalized$identity_stability == "positional_lane"]
  ), 0L)
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

testthat::test_that("LRM human-confirmed units and 2013 consolidations preserve values and lineage", {
  path <- file.path(project_test_root, "input", "current", "lrm_auctions", "Subasta de LRM_WEB.xlsx")
  dimensions <- xlsx_sheet_dimensions(path)
  raw <- read_dimensioned_sheet(path, dimensions[dimensions$sheet_name == "Subastas 2013", ])
  result <- documented_parse_lrm_auction_sheet(raw, "Subastas 2013", project_test_root)
  derived <- result$observations[result$observations$parser_mode ==
    "lrm_auction_event_governed_consolidation", ]
  source <- result$component_observations

  testthat::expect_true(all(result$observations$unit[grepl("_rate$", result$observations$measure)] ==
    "percent_per_annum"))
  testthat::expect_equal(source$value[source$source_row == 15L & source$source_column == 11L],
                         6.387762237762238)
  expected <- c(
    announced_amount = 750000, offered_amount = 950000, assigned_amount = 615000,
    offered_bid_count = 18, assigned_bid_count = 12,
    offered_average_rate = 6.443947368421052,
    offered_minimum_rate = 6, offered_maximum_rate = 6.75,
    assigned_average_rate = 6.317073170731708,
    assigned_minimum_rate = 6, assigned_maximum_rate = 6.5
  )
  first <- derived[derived$category ==
    "standardized_tenor_days: 91 — residual_tenor_days: 79", ]
  testthat::expect_equal(stats::setNames(first$value, first$measure)[names(expected)], expected)
  expected_second <- c(
    announced_amount = 400000, offered_amount = 375000, assigned_amount = 360000,
    offered_bid_count = 5, assigned_bid_count = 4,
    offered_average_rate = 7.6273333333333335,
    offered_minimum_rate = 7.4, offered_maximum_rate = 7.75,
    assigned_average_rate = 7.622222222222222,
    assigned_minimum_rate = 7.4, assigned_maximum_rate = 7.75
  )
  second <- derived[derived$category ==
    "standardized_tenor_days: 182 — residual_tenor_days: 261", ]
  testthat::expect_equal(stats::setNames(second$value, second$measure)[names(expected_second)], expected_second)
  testthat::expect_false(any(second$source_row %in% c(17L, 22L), na.rm = TRUE))
  assigned_average_lineage <- result$consolidation_lineage[
    result$consolidation_lineage$category == second$category[[1]] &
      result$consolidation_lineage$measure == "assigned_average_rate", ]
  testthat::expect_setequal(assigned_average_lineage$source_row, c(17L, 22L))
  testthat::expect_setequal(assigned_average_lineage$source_column, c(8L, 14L))
  testthat::expect_equal(nrow(source[source$source_row %in% c(15L,17L,21L,22L), ]), 39L)
  testthat::expect_equal(nrow(derived), 22L)
  testthat::expect_true(all(is.na(derived$source_row) & is.na(derived$source_column)))
})
