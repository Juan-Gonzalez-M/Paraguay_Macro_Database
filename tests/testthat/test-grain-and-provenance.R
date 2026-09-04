# Regression cover for the third audit's P0-2, P0-3 and P1: the research
# boundary, the recovered cells, and the semantics that made a rate-labelled
# series carry a non-rate unit.

round3_production <- function() {
  path <- file.path(project_test_root, "database", "paraguay_macro_pilot.duckdb")
  testthat::skip_if_not(file.exists(path), "production database not present")
  con <- connect_project_database(path, read_only = TRUE)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE), envir = parent.frame())
  con
}

# --- P0-2: the research boundary ---------------------------------------------

# A database holding two worksheets an economist has validated, one of which does
# not reconcile.
#
# The seventh audit's F-13. The production-state test below could only run when
# some worksheet happened to carry a defect, so it disabled itself exactly when
# the codebase was clean -- and a regression that let defective worksheets into a
# validated mart would have been caught only by luck. The state the boundary is
# about has to be constructed, not waited for.
round3_defect_fixture <- function(env = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".duckdb", .local_envir = env)
  con <- DBI::dbConnect(duckdb::duckdb(), path)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE), envir = env)
  initialize_database(con, project_test_root)
  release <- "release:defect-fixture"
  sheets <- c("Hoja balanceada", "Hoja con defecto")
  series <- c("fixture:clean", "fixture:defective")

  DBI::dbWriteTable(con, "release_sources", tibble::tibble(
    release_id = release, source_id = "fixture", vintage_id = "fixture:v1"
  ), append = TRUE)
  DBI::dbWriteTable(con, "source_files", tibble::tibble(
    vintage_id = "fixture:v1", first_ingested_release_id = release, source_id = "fixture",
    source_label = "Fixture", publisher = "Fixture", source_format = "xlsx",
    source_file = "fixture.xlsx", source_path = NA_character_, archive_path = NA_character_,
    sha256 = "aa", size_bytes = 1, publication_date = as.Date("2024-02-15"),
    publication_date_source = "filename", first_ingested_at = Sys.time(),
    ingestion_status = "completed", vintage_sk = 1L
  ), append = TRUE)
  DBI::dbWriteTable(con, "dim_series", tibble::tibble(
    series_id = series, source_id = "fixture", label = paste("Fixture", series),
    unit = "index", scale = "units", frequency = "monthly", first_vintage_id = "fixture:v1",
    series_grain = "scalar_series", unit_code = "INDEX", scale_multiplier = 1,
    semantic_status = "documented_series", series_sk = 1:2
  ), append = TRUE)
  DBI::dbWriteTable(con, "fact_series_events", tibble::tibble(
    series_id = series, period = as.Date("2024-01-31"), value = c(1, 2),
    vintage_id = "fixture:v1", publication_date = as.Date("2024-02-15"), is_deleted = FALSE,
    source_file = "fixture.xlsx", series_sk = 1:2, vintage_sk = 1L
  ), append = TRUE)
  DBI::dbWriteTable(con, "documented_series_snapshot", tibble::tibble(
    vintage_id = "fixture:v1", series_id = series, period = as.Date("2024-01-31"),
    source_id = "fixture", source_sheet = sheets, value = c(1, 2)
  ), append = TRUE)
  # Both worksheets are validated by a named economist. The only thing that
  # differs is whether their source cells reconcile -- which is the point: the
  # boundary must hold on reconciliation alone, with review status held constant.
  DBI::dbWriteTable(con, "table_status", tibble::tibble(
    source_id = "fixture", source_sheet = sheets, status = "validated",
    reviewed_by = "fixture economist", reviewed_at = as.Date("2026-01-01"),
    evidence_uri = "https://example.invalid/evidence", note = "fixture"
  ), append = TRUE)
  DBI::dbWriteTable(con, "table_domains", tibble::tibble(
    source_id = "fixture", source_sheet = sheets, domain = "prices",
    subdomain = "consumer_prices", measure_family = "index",
    reviewed_by = "fixture economist"
  ), append = TRUE)
  DBI::dbWriteTable(con, "table_reconciliation", tibble::tibble(
    vintage_id = "fixture:v1", source_id = "fixture", source_sheet = sheets,
    release_id = release, numeric_source_cells = 1, accepted_observations = 1,
    rejected_observations = 0, documented_exclusions = 0L, many_to_one_allowance = 0L,
    balance_delta = c(0, 3), status = c("balanced", "defects_recorded"),
    note = "fixture", checked_at = Sys.time(), accepted_cells = 1, cell_reuse = 0,
    unmapped_in_region = 0, out_of_region_cells = 0, classified_cells = c(0L, 3L),
    unclassified_cells = 0L, parser_defect_cells = c(0L, 3L)
  ), append = TRUE)

  # Both series are also economically reviewed, since schema 36 made that a
  # requirement of the validated marts. Held constant for the same reason the
  # worksheet status is: what differs between these two series must be
  # reconciliation alone, or the test proves the wrong thing.
  DBI::dbWriteTable(con, "series_review", tibble::tibble(
    series_id = series,
    definition = "Indice de precios al consumidor, nivel general, base diciembre 2020 = 100.",
    definition_evidence_uri = "https://example.invalid/anexo", source_semantics = "Fixture row",
    frequency = "monthly", reference_period_convention = "calendar month, dated at month end",
    timing_basis = "period_average", stock_flow = "flow", unit_code = "INDEX",
    scale_multiplier = 1, currency = "PYG", valuation = "not_applicable",
    nominal_real = "real", price_base_year = "2020", seasonal_adjustment = "not_adjusted",
    transformation = "index", hierarchy_role = "total", parent_series_id = NA_character_,
    methodology_regime_id = NA_character_, comparability = "comparable",
    availability_convention = "published within 10 days of month end",
    reviewed_by = "fixture economist", reviewed_at = as.Date("2026-01-01")
  ), append = TRUE)

  publish_test_release(con, release, "accepted")
  create_series_views(con)
  create_semantic_views(con)
  create_domain_views(con)
  create_table_status_views(con)
  create_mart_views(con)
  list(con = con, sheets = sheets, series = series)
}

testthat::test_that("a validated worksheet that does not reconcile is kept out of the mart", {
  fixture <- round3_defect_fixture()
  con <- fixture$con
  # Both series are validated and both are in the unfiltered view, so the test
  # cannot pass by the mart being empty for some unrelated reason.
  all_rows <- DBI::dbGetQuery(con, paste(
    "SELECT series_id, review_status, reconciliation_status FROM marts.v_mart_prices_all",
    "ORDER BY series_id"
  ))
  testthat::expect_equal(nrow(all_rows), 2L)
  testthat::expect_equal(unique(all_rows$review_status), "validated")
  testthat::expect_setequal(all_rows$reconciliation_status, c("balanced", "defects_recorded"))

  # And only the balanced one is published.
  published <- DBI::dbGetQuery(con, "SELECT series_id FROM marts.v_mart_prices")
  testthat::expect_equal(published$series_id, "fixture:clean")
})

testthat::test_that("no defective worksheet reaches a validated mart in the live database", {
  # The same property against whatever the production database currently holds,
  # as a second check beside the synthetic fixture above.
  #
  # It used to skip when nothing was defective, which meant it switched itself
  # off exactly when the codebase was clean -- the re-audit's A11 #14, and the
  # last skip in the suite. There is no need for a skip: "every defective
  # worksheet is absent from every mart" is vacuously true when none is
  # defective, and asserting that explicitly is a statement about the database
  # rather than an absence of one. The loop below runs either way; when
  # `defective` is empty the count it asserts is zero for the trivial reason,
  # which the first assertion records.
  con <- round3_production()
  defective <- DBI::dbGetQuery(con, paste(
    "SELECT DISTINCT source_id, source_sheet FROM audit.table_reconciliation",
    "WHERE status <> 'balanced'"
  ))
  testthat::expect_gte(nrow(defective), 0L)
  marts <- DBI::dbGetQuery(con, paste(
    "SELECT schema_name || '.' || view_name AS mart FROM duckdb_views()",
    "WHERE schema_name = 'marts' AND view_name LIKE 'v\\_mart\\_%' ESCAPE '\\'",
    "AND view_name NOT LIKE '%\\_all' ESCAPE '\\'"
  ))$mart
  testthat::expect_gt(length(marts), 0L)
  for (mart in c(marts, "marts.v_research_series")) {
    columns <- DBI::dbGetQuery(con, paste0("PRAGMA table_info('", mart, "')"))$name
    if (!"source_sheet" %in% columns) next
    leaked <- DBI::dbGetQuery(con, paste(
      "SELECT count(*) AS n FROM", mart, "m JOIN audit.table_reconciliation r",
      "  ON r.source_id = m.source_id AND r.source_sheet = m.source_sheet",
      "WHERE r.status <> 'balanced'"
    ))$n[[1]]
    testthat::expect_equal(
      leaked, 0,
      info = paste(mart, "exposes rows from a worksheet whose cells do not reconcile")
    )
  }
})

testthat::test_that("every validated mart row is validated and balanced, and _all is its superset", {
  con <- round3_production()
  marts <- DBI::dbGetQuery(con, paste(
    "SELECT view_name FROM duckdb_views() WHERE schema_name = 'marts'",
    "AND view_name LIKE 'v\\_mart\\_%\\_all' ESCAPE '\\'"
  ))$view_name
  testthat::expect_gt(length(marts), 0L)
  for (all_view in marts) {
    strict <- sub("_all$", "", all_view)
    counts <- DBI::dbGetQuery(con, paste0(
      "SELECT (SELECT count(*) FROM marts.", strict, ") AS strict_rows,",
      " (SELECT count(*) FROM marts.", all_view, ") AS all_rows,",
      " (SELECT count(*) FROM marts.", all_view,
      "   WHERE review_status = 'validated' AND reconciliation_status = 'balanced')",
      "   AS qualifying_rows,",
      " (SELECT count(*) FROM marts.", strict,
      "   WHERE review_status <> 'validated' OR reconciliation_status <> 'balanced')",
      "   AS unqualified_rows"
    ))
    # The strict mart is exactly the qualifying subset -- not fewer (a join
    # defect losing rows) and not more (a filter that does not filter).
    testthat::expect_equal(counts$strict_rows[[1]], counts$qualifying_rows[[1]], info = strict)
    testthat::expect_equal(counts$unqualified_rows[[1]], 0, info = strict)
    testthat::expect_gte(counts$all_rows[[1]], counts$strict_rows[[1]])
  }
})

# --- P0-3: the recovered cells rest on real source cells ----------------------

testthat::test_that("every recovered observation sits on the source cell that holds its value", {
  # The fixture is the list of observations this project claims to have
  # recovered. The test does not trust the database's own account of them: it
  # goes back to the raw cell layer, in worksheet coordinates, and compares the
  # value there with the value stored against the observation.
  fixture <- file.path(project_test_root, "tests", "testthat", "fixtures",
                       "recovered_observations.csv")
  testthat::skip_if_not(file.exists(fixture), "recovered-observation fixture not present")
  # trim_ws = FALSE, because the publisher's worksheet names are part of the key
  # and some of them end in a space: "CUADRO 17 ", "CUADRO 19 ", "Subastas 2015 ".
  # read_csv() trims by default, which silently turned 64 of these rows into keys
  # that match nothing -- a golden fixture that mangles its own key is not one.
  expected <- readr::read_csv(fixture, show_col_types = FALSE, trim_ws = FALSE)
  testthat::expect_gt(nrow(expected), 4000L)
  testthat::expect_true(any(expected$source_sheet != trimws(expected$source_sheet)))
  con <- round3_production()
  DBI::dbWriteTable(con, "expected_recovered", expected, temporary = TRUE, overwrite = TRUE)
  missing <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM expected_recovered e",
    "LEFT JOIN staging.documented_series_snapshot s",
    "  ON s.source_id = e.source_id AND s.source_sheet = e.source_sheet",
    " AND s.source_row = e.source_row AND s.source_column = e.source_column",
    "WHERE s.series_id IS NULL"
  ))$n[[1]]
  testthat::expect_equal(missing, 0)
  mismatched <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM expected_recovered e",
    "JOIN staging.documented_series_snapshot s",
    "  ON s.source_id = e.source_id AND s.source_sheet = e.source_sheet",
    " AND s.source_row = e.source_row AND s.source_column = e.source_column",
    "JOIN main.v_report_cells_a1 c",
    "  ON c.vintage_id = s.vintage_id AND c.source_sheet = s.source_sheet",
    " AND c.row_id = s.source_row AND c.column_id = s.source_column",
    "WHERE c.raw_value_num IS NULL OR abs(c.raw_value_num - s.value) > 1e-9"
  ))$n[[1]]
  testthat::expect_equal(mismatched, 0)
})

testthat::test_that("the corrected periods are the ones the fixture records", {
  fixture <- file.path(project_test_root, "tests", "testthat", "fixtures",
                       "period_corrections.csv")
  testthat::skip_if_not(file.exists(fixture), "period-correction fixture not present")
  expected <- readr::read_csv(fixture, show_col_types = FALSE, trim_ws = FALSE)
  testthat::expect_gt(nrow(expected), 1000L)
  con <- round3_production()
  DBI::dbWriteTable(con, "expected_periods", expected, temporary = TRUE, overwrite = TRUE)
  wrong <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM expected_periods e",
    "LEFT JOIN staging.documented_series_snapshot s",
    "  ON s.source_id = e.source_id AND s.source_sheet = e.source_sheet",
    " AND s.source_row = e.source_row AND s.source_column = e.source_column",
    "WHERE s.period IS DISTINCT FROM e.period"
  ))$n[[1]]
  testthat::expect_equal(wrong, 0)
})

# --- P1-1: the recorded parser defects ---------------------------------------

testthat::test_that("the repaired worksheets read every published cell in their region", {
  con <- round3_production()
  repaired <- c("CUADRO 11", "Datos (+ de 1 día)", "Ventas(DatosMensuales)", "CCC 02")
  state <- DBI::dbGetQuery(con, paste(
    "SELECT source_id, source_sheet, unmapped_in_region, parser_defect_cells,",
    "unclassified_cells, status FROM audit.table_reconciliation",
    "WHERE source_sheet IN (",
    paste(vapply(repaired, function(x) DBI::dbQuoteString(con, x), character(1)), collapse = ", "),
    ")"
  ))
  testthat::expect_equal(nrow(state), length(repaired))
  # unmapped_in_region is not required to be zero, and asserting that it is was a
  # stronger claim than the reconciliation makes. A cell inside the region that
  # the parser deliberately does not consume -- the compensatory sheet's five
  # template totals for months the publisher has not reported -- is unmapped and
  # classified, which is exactly the state the register exists to express. What
  # must be zero is the unexplained residual and the admitted defect.
  testthat::expect_true(all(state$parser_defect_cells == 0L))
  testthat::expect_true(all(state$unclassified_cells == 0L))
  testthat::expect_true(all(state$status == "balanced"))
})

testthat::test_that("no source cell is left unaccounted for anywhere", {
  con <- round3_production()
  totals <- DBI::dbGetQuery(con, paste(
    "SELECT sum(unclassified_cells) AS unclassified, sum(cell_reuse) AS reuse,",
    "count(*) FILTER (WHERE status = 'unexplained_cells') AS unexplained",
    "FROM audit.table_reconciliation"
  ))
  testthat::expect_identical(as.numeric(totals$unclassified[[1]]), 0)
  testthat::expect_identical(as.numeric(totals$reuse[[1]]), 0)
  testthat::expect_equal(totals$unexplained[[1]], 0)
})

testthat::test_that("the minimum-wage regimes carry the interval they were in force over", {
  con <- round3_production()
  steps <- DBI::dbGetQuery(con, paste(
    "SELECT o.series_id, o.period, o.period_start, o.period_end, o.value",
    "FROM main.v_series_observations o",
    "JOIN canonical.dim_series d USING (series_id)",
    "WHERE d.frequency = 'irregular_interval' AND NOT o.is_deleted",
    "ORDER BY o.period"
  ))
  testthat::expect_gt(nrow(steps), 50L)
  # The interval is real: it opens before it closes, and it is not the whole
  # year the frequency-derived bound would have produced.
  testthat::expect_true(all(steps$period_start <= steps$period_end))
  testthat::expect_true(any(format(steps$period_start, "%m-%d") != "01-01"))
  # 1980 is the worked example: 20,520 in force to June, 23,610 from July, and
  # the annual row above them is their average.
  first_year <- steps[format(steps$period, "%Y") == "1980", ]
  testthat::expect_equal(nrow(first_year), 2L)
  testthat::expect_equal(sort(first_year$value), c(20520, 23610))
  annual <- DBI::dbGetQuery(con, paste(
    "SELECT value FROM main.v_series_observations o JOIN canonical.dim_series d USING (series_id)",
    "WHERE d.frequency = 'annual' AND d.label = 'Salario mínimo legal — Nominal'",
    "AND o.period = DATE '1980-12-31' AND NOT o.is_deleted"
  ))$value
  testthat::expect_equal(annual, 22065)
  testthat::expect_equal(mean(first_year$value), 22065)
})

testthat::test_that("interbank continuation operations are events, not scalar lanes", {
  con <- round3_production()
  events <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS series FROM canonical.dim_series d",
    "JOIN (SELECT DISTINCT series_id, parser_mode FROM staging.documented_series_snapshot) n",
    "  USING (series_id)",
    "WHERE n.parser_mode = 'vertical_date_event_positional_lane'"
  ))$series[[1]]
  testthat::expect_gt(events, 0L)
  # They inherit the trade date of the row above them, so they must never carry
  # a null period, and they are declared positional because the publisher does
  # not number the operations.
  stability <- DBI::dbGetQuery(con, paste(
    "SELECT DISTINCT d.identity_stability FROM canonical.dim_series d",
    "JOIN (SELECT DISTINCT series_id, parser_mode FROM staging.documented_series_snapshot) n",
    "  USING (series_id)",
    "WHERE n.parser_mode = 'vertical_date_event_positional_lane'"
  ))$identity_stability
  testthat::expect_identical(stability, "positional_lane")
})

# --- P1-2: measure semantics --------------------------------------------------

testthat::test_that("the financial-indicator measure separates rates from balances", {
  con <- round3_production()
  measures <- DBI::dbGetQuery(con, paste(
    "SELECT x.value AS measure, count(*) AS series FROM canonical.series_dimension x",
    "JOIN canonical.dim_series d USING (series_id)",
    "WHERE x.dimension = 'measure' AND d.source_id = 'financial_indicators'",
    "GROUP BY 1 ORDER BY 1"
  ))
  testthat::expect_setequal(measures$measure, c("outstanding_amount", "rate"))
  testthat::expect_gt(measures$series[measures$measure == "rate"], 500L)
  testthat::expect_gt(measures$series[measures$measure == "outstanding_amount"], 100L)
  # Derived, with the published wording recorded, never claimed as reviewed.
  basis <- DBI::dbGetQuery(con, paste(
    "SELECT DISTINCT basis FROM canonical.series_dimension WHERE dimension = 'measure'"
  ))$basis
  testthat::expect_identical(basis, "published_title")
})

testthat::test_that("no series carries a unit its derived measure contradicts", {
  con <- round3_production()
  contradictions <- DBI::dbGetQuery(con, paste(
    "SELECT x.value AS measure, d.unit_code, count(*) AS series",
    "FROM canonical.series_dimension x JOIN canonical.dim_series d USING (series_id)",
    "WHERE x.dimension = 'measure' GROUP BY 1, 2"
  ))
  offending <- character()
  for (i in seq_len(nrow(contradictions))) {
    allowed <- SEMANTIC_MEASURE_UNITS[[contradictions$measure[[i]]]]
    if (is.null(allowed)) next
    unit <- contradictions$unit_code[[i]]
    if (!is.na(unit) && unit %in% allowed) next
    offending <- c(offending, paste0(contradictions$measure[[i]], "/", unit))
  }
  testthat::expect_identical(offending, character())
})

testthat::test_that("a rate-labelled financial indicator carries a rate unit", {
  # The audit's own predicate, run directly.
  con <- round3_production()
  wrong <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM canonical.dim_series",
    "WHERE source_id = 'financial_indicators'",
    "AND regexp_matches(strip_accents(lower(label)), 'tasa|spread')",
    "AND coalesce(unit_code, '') NOT IN ('PERCENT', 'PERCENT_PER_ANNUM', 'PROPORTION', 'RATIO',",
    "  'BASIS_POINTS', 'PYG', 'USD', 'EUR', 'UNRESOLVED_SOURCE_UNITS')"
  ))$n[[1]]
  testthat::expect_equal(wrong, 0)
})

# --- P1-3: numbers written into prose ----------------------------------------

testthat::test_that("no status note states a count this release contradicts", {
  con <- round3_production()
  notes <- DBI::dbGetQuery(con, paste(
    "SELECT source_id, source_sheet, note FROM audit.table_status",
    "WHERE note IS NOT NULL AND note <> ''"
  ))
  testthat::expect_gt(nrow(notes), 0L)
  # The claim the audit found: "1,636 positional-lane series" on a source whose
  # live count is zero.
  stale <- notes[grepl("1,636", notes$note, fixed = TRUE), ]
  testthat::expect_equal(nrow(stale), 0L)
  lanes <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM canonical.dim_series",
    "WHERE source_id = 'financial_indicators' AND identity_stability = 'positional_lane'"
  ))$n[[1]]
  testthat::expect_equal(lanes, 0)
})

testthat::test_that("the release itself raises no error-severity flag", {
  con <- round3_production()
  # By attempt, not by release. Since schema 30 a failed attempt's flags are
  # retained rather than deleted when the bundle is re-run -- that is the point of
  # keeping them -- so "did the release produce errors" is a question about the
  # attempt that produced the published build, not about every attempt that ever
  # shared the source bundle.
  errors <- DBI::dbGetQuery(con, paste(
    "SELECT check_name, detail FROM audit.quality_flags",
    "WHERE severity = 'error' AND attempt_id = (",
    "  SELECT attempt_id FROM audit.ingestion_run_attempts ORDER BY started_at DESC LIMIT 1)"
  ))
  testthat::expect_identical(nrow(errors), 0L, info = paste(errors$check_name, collapse = "; "))
})
