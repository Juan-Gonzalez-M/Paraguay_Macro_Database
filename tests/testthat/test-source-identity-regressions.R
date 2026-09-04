# Regression battery for the P0 findings of the external technical audit
# (Technical_Audit.docx, 27 August 2026). Each block locks one repaired defect
# and, where the audit named a target cardinality (section 10), asserts it.

audit_observation_frame <- function(records, identity_sheet = NULL) {
  observations <- documented_bind_records(records)
  observations$hierarchy_status <- "flat"
  observations$identity_sheet <- if (is.null(identity_sheet)) observations$source_sheet else identity_sheet
  observations
}

audit_finalize <- function(observations) {
  documented_finalize_observations(
    observations,
    list(source_id = "test_source", vintage_id = "test:vintage", source_file = "test.xlsx"),
    "release:test", as.Date("2026-08-27")
  )
}

# --- identity construction ---------------------------------------------------

testthat::test_that("the worksheet slug depends only on the sheet name", {
  # janitor::make_clean_names() uniquifies a vector by position. Applied to the
  # repeated sheet column it produced Datos, Datos_2, ... Datos_26, so inserting
  # one column upstream silently reassigned the identity of every later series.
  testthat::expect_identical(
    documented_sheet_slug(rep("Datos", 3L)),
    rep("datos", 3L)
  )
  testthat::expect_identical(
    documented_sheet_slug(c("Datos", "Datos (+ de 1 día)", "Datos")),
    c("datos", "datos_de_1_dia", "datos")
  )
})

testthat::test_that("period-axis orientation covers every horizontal parser mode", {
  testthat::expect_true(documented_period_axis_is_horizontal("credit_question_quarter"))
  testthat::expect_true(documented_period_axis_is_horizontal("credit_index_quarter"))
  testthat::expect_true(documented_period_axis_is_horizontal("horizontal_year_month"))
  testthat::expect_false(documented_period_axis_is_horizontal("vertical_date"))
  testthat::expect_false(documented_period_axis_is_horizontal("year_month_blocks"))
})

testthat::test_that("a horizontal layout disambiguates on rows, never on columns", {
  # Two published rows carrying the same question/response at the same quarter.
  # Slotting them by column pins the period and yields one observation per
  # series; slotting by row keeps two series with the full quarterly history.
  records <- list()
  for (row in c(10L, 20L)) for (column in c(3L, 4L)) {
    records[[length(records) + 1L]] <- documented_record(
      "%", "Credit survey", "credit_question_quarter",
      if (column == 3L) as.Date("2020-03-31") else as.Date("2020-06-30"),
      "1T", "quarterly", "Industria — Aumentó", "credit_survey_responses",
      "response_share", 0.25 + row / 1000, row, column
    )
  }
  finalized <- audit_finalize(audit_observation_frame(records))
  testthat::expect_true(all(stringr::str_detect(finalized$identity_basis, "row_")))
  testthat::expect_false(any(stringr::str_detect(finalized$identity_basis, "column_")))
  testthat::expect_equal(dplyr::n_distinct(finalized$series_id), 2L)
  testthat::expect_true(all(table(finalized$series_id) == 2L))
})

testthat::test_that("a continuation group merges worksheets into one series identity", {
  # bcp_fx_daily: the publisher splits one continuous daily series into one
  # worksheet per year. The sheets are a lineage segment, not a dimension.
  records <- list(
    documented_record("OpDivisas2013(DatosDiarios)", "FX", "vertical_date",
                      as.Date("2013-01-02"), "2013-01-02", "daily",
                      "Compra del BCP — Total", "FX", "Compra", 1, 5L, 2L),
    documented_record("OpDivisas2014(DatosDiarios)", "FX", "vertical_date",
                      as.Date("2014-01-02"), "2014-01-02", "daily",
                      "Compra del BCP — Total", "FX", "Compra", 2, 5L, 2L)
  )
  split <- audit_finalize(audit_observation_frame(records))
  testthat::expect_equal(dplyr::n_distinct(split$series_id), 2L)

  merged <- audit_finalize(audit_observation_frame(records, identity_sheet = "OpDivisas(DatosDiarios)"))
  testthat::expect_equal(dplyr::n_distinct(merged$series_id), 1L)
  testthat::expect_identical(unique(merged$identity_stability), "semantic")
  # Per-sheet lineage must survive the merge: source_sheet is untouched.
  testthat::expect_setequal(
    merged$source_sheet,
    c("OpDivisas2013(DatosDiarios)", "OpDivisas2014(DatosDiarios)")
  )
})

# --- compensatory / complementary FX sales -----------------------------------

testthat::test_that("compensatory FX year blocks stop at the next year header", {
  path <- fs::dir_ls(
    file.path(project_test_root, "input", "current", "compensatory_fx_sales"),
    regexp = "\\.(xlsx|xlsm)$"
  )[[1]]
  dimensions <- xlsx_sheet_dimensions(path) %>% dplyr::filter(.data$sheet_name == "Ventas(DatosMensuales)")
  raw <- read_dimensioned_sheet(path, dimensions)
  observations <- documented_parse_compensatory_sales(raw, "Ventas(DatosMensuales)")$observations

  # Audit section 10: 36 stored identities collapse to 3 measures.
  testthat::expect_equal(dplyr::n_distinct(observations$series_path), 3L)
  testthat::expect_setequal(
    unique(observations$series_label),
    c("Total Ventas", "Ventas Compensatorias", "Ventas Complementarias")
  )
  # Bounded year blocks: no calendar year may exceed twelve months, and no
  # measure may report the same month twice (the audit measured 92-114
  # conflicting months per measure before the repair).
  per_year <- observations %>%
    dplyr::count(.data$series_label, year = lubridate::year(.data$period))
  testthat::expect_true(all(per_year$n <= 12L))
  testthat::expect_equal(sum(duplicated(observations[c("series_label", "period")])), 0L)
  # 139 months. Schema 23 read 144 by admitting Agosto-Diciembre 2026, whose two
  # component cells are empty and whose Total holds a cached zero from the
  # sheet's own '=+G+H'; schema 24 recognises the trailing run of a year block
  # with no component values as the template it is. Five months the publisher had
  # not reported are no longer published, and the vintage's availability comes
  # back to 2026-07-31 with it.
  testthat::expect_equal(dplyr::n_distinct(observations$period), 139L)
  testthat::expect_equal(max(observations$period), as.Date("2026-07-31"))

  # Arithmetic reconciliation of the published subtotal, on every month where the
  # publisher printed all three figures. A month with a total and no components
  # is not a failed subtotal, it is a month with nothing to decompose, and
  # asserting over it compares against NA rather than against zero.
  wide <- observations %>%
    dplyr::select(dplyr::all_of(c("period", "series_label", "value"))) %>%
    tidyr::pivot_wider(names_from = "series_label", values_from = "value")
  complete <- !is.na(wide$`Ventas Compensatorias`) & !is.na(wide$`Ventas Complementarias`) &
    !is.na(wide$`Total Ventas`)
  testthat::expect_gt(sum(complete), 130L)
  testthat::expect_true(all(abs(
    wide$`Ventas Compensatorias`[complete] + wide$`Ventas Complementarias`[complete] -
      wide$`Total Ventas`[complete]
  ) < 1e-6))
  # Every month now published carries all three figures: the only rows that ever
  # had a total without components were the template tail of the current year.
  testthat::expect_equal(sum(!complete), 0L)

  # Parser-region non-overlap: one source cell feeds at most one observation.
  testthat::expect_equal(sum(duplicated(observations[c("source_row", "source_column")])), 0L)

  # Spot checks against the published cells (rows 8, 26 and the 2016 block).
  totals <- observations %>% dplyr::filter(.data$series_label == "Total Ventas")
  testthat::expect_equal(totals$value[totals$period == as.Date("2015-01-31")], 84)
  testthat::expect_equal(totals$value[totals$period == as.Date("2016-01-31")], 175.8)
  testthat::expect_equal(totals$value[totals$period == as.Date("2017-01-31")], 29.6)
})

# --- CUADRO 61, local FX market turnover -------------------------------------

testthat::test_that("CUADRO 61 parses into named institution and operation series", {
  path <- fs::dir_ls(
    file.path(project_test_root, "input", "current", "economic_annex"),
    regexp = "\\.(xlsx|xlsm)$"
  )[[1]]
  dimensions <- xlsx_sheet_dimensions(path) %>% dplyr::filter(.data$sheet_name == "CUADRO 61")
  raw <- read_dimensioned_sheet(path, dimensions)
  result <- documented_parse_fx_market_turnover(raw, "CUADRO 61")
  observations <- result$observations

  testthat::expect_identical(result$mode, "fx_market_turnover")
  # 2 sides x 5 institutions x 17 breakdowns (the period total, five operation
  # types, and the currency/residency splits nested under three of them).
  testthat::expect_equal(dplyr::n_distinct(observations$series_path), 170L)
  # The nesting level must stay in the identity: "Euros" is published under both
  # Arbitraje and Operación Nominal and means a different thing under each.
  testthat::expect_true(all(c(
    "Compra — Bancos comerciales — Arbitraje — Euros",
    "Compra — Bancos comerciales — Operación Nominal — Euros",
    "Compra — Bancos comerciales — Forward — Residentes"
  ) %in% observations$series_label))
  # No published cell may be ambiguous on its own identity.
  testthat::expect_equal(
    sum(duplicated(observations[c("series_label", "frequency", "period")])), 0L
  )
  # The generic extractor named series from data rows; every label was a
  # concatenation of numbers. No published label may look like a number.
  testthat::expect_false(any(stringr::str_detect(observations$series_label, "^[0-9]")))
  testthat::expect_true(all(stringr::str_detect(observations$series_label, "^(Compra|Venta) — ")))
  testthat::expect_setequal(unique(observations$frequency), c("annual", "quarterly", "monthly"))
  testthat::expect_true(all(observations$unit == "USD" & observations$scale == "thousands"))

  # Source-to-target balance: every numeric cell inside the published data block
  # becomes exactly one observation, and no cell feeds two observations.
  numbers <- documented_number_matrix(raw)
  testthat::expect_equal(nrow(observations), sum(!is.na(numbers[, 2:11])))
  testthat::expect_equal(sum(duplicated(observations[c("source_row", "source_column")])), 0L)

  # Arithmetic reconciliation: the five operation types sum to the period total.
  parts <- c("Spot y Efectivo", "Arbitraje", "Operación Nominal", "Forward", "Canje")
  reconciliation <- observations %>%
    dplyr::mutate(group = stringr::str_remove(.data$series_label, " — [^—]+$")) %>%
    dplyr::filter(.data$measure %in% c("Total", parts)) %>%
    dplyr::group_by(.data$group, .data$period, .data$frequency) %>%
    dplyr::summarise(
      total = sum(.data$value[.data$measure == "Total"]),
      components = sum(.data$value[.data$measure %in% parts]),
      component_count = sum(.data$measure %in% parts), .groups = "drop"
    ) %>%
    dplyr::filter(.data$component_count == 5L)
  testthat::expect_gt(nrow(reconciliation), 1000L)
  testthat::expect_true(all(
    abs(reconciliation$total - reconciliation$components) <= pmax(1e-6, abs(reconciliation$total) * 1e-4)
  ))

  # Every series is a real time series, not a positional singleton.
  testthat::expect_gt(min(table(observations$series_path)), 100L)
})

# --- research-readiness gate -------------------------------------------------

testthat::test_that("table status configuration is complete and self-consistent", {
  status <- read_table_status(project_test_root)
  registry <- readr::read_csv(
    file.path(project_test_root, "config", "source_registry.csv"), show_col_types = FALSE
  )
  testthat::expect_true(all(status$status %in% TABLE_STATUS_VALUES))
  testthat::expect_equal(sum(duplicated(status[c("source_id", "source_sheet")])), 0L)
  testthat::expect_true(all(status$source_id %in% registry$source_id))
  # Every source needs a wildcard row, otherwise a newly published worksheet
  # would reach the catalogue with no declared status.
  testthat::expect_setequal(
    status$source_id[status$source_sheet == "*"],
    registry$source_id
  )
  # A validated table is a claim about economic review and needs a named
  # reviewer with a date.
  validated <- status %>% dplyr::filter(.data$status == "validated")
  if (nrow(validated)) {
    testthat::expect_true(all(nzchar(trimws(validated$reviewed_by)) & validated$reviewed_by != "unreviewed"))
    testthat::expect_false(any(is.na(lubridate::ymd(validated$reviewed_at, quiet = TRUE))))
  }
})
