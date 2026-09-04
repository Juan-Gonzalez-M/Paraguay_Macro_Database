# The seventh audit's section 11.4: the economic review of a series, and the gate
# on it.
#
# Verified before writing any of it: rows in series_semantic_evidence whose basis
# is 'reviewed' are deliberately preserved across every rebuild, and **nothing in
# the codebase has ever written one**. The project had an output worklist naming
# what was unreviewed and no input register for the answers. So this is not a
# second copy of v28's machinery; it is the missing half of it.
#
# config/series_review.csv ships empty and every test here builds its own, which
# is deliberate: no review decision is ever written to the production database by
# a test, the same rule the reviewed-concept tests follow.

series_review_row <- function(series_id = "fixture:series", ...) {
  row <- tibble::tibble(
    series_id = series_id,
    definition = "Indice de precios al consumidor, nivel general, base diciembre 2020 = 100.",
    definition_evidence_uri = "https://www.bcp.gov.py/anexo-estadistico",
    source_semantics = "Anexo estadistico CUADRO 9, fila 'Nivel general'.",
    frequency = "monthly",
    reference_period_convention = "calendar month, dated at month end",
    timing_basis = "period_average", stock_flow = "flow", unit_code = "INDEX",
    scale_multiplier = "1", currency = "PYG", valuation = "not_applicable",
    nominal_real = "real", price_base_year = "2020", seasonal_adjustment = "not_adjusted",
    transformation = "index", hierarchy_role = "total", parent_series_id = "",
    methodology_regime_id = "", comparability = "comparable",
    availability_convention = "published within 10 days of month end",
    reviewed_by = "fixture economist", reviewed_at = "2026-09-01"
  )
  overrides <- list(...)
  for (name in names(overrides)) row[[name]] <- overrides[[name]]
  row
}

write_review_register <- function(root, rows) {
  dir.create(file.path(root, "config"), showWarnings = FALSE, recursive = TRUE)
  readr::write_csv(rows, file.path(root, "config", "series_review.csv"))
  root
}

review_fixture <- function(env = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".duckdb", .local_envir = env)
  con <- DBI::dbConnect(duckdb::duckdb(), path)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE), envir = env)
  initialize_database(con, project_test_root)
  DBI::dbWriteTable(con, "dim_series", tibble::tibble(
    series_id = c("fixture:series", "fixture:parent"), source_id = "fixture",
    label = c("Nivel general", "Total"), unit = "index", scale = "units",
    frequency = "monthly", first_vintage_id = "fixture:v1", series_grain = "scalar_series",
    unit_code = "INDEX", scale_multiplier = 1, stock_flow = "not_reviewed",
    nominal_real = "not_reviewed", seasonal_adjustment = "not_reviewed",
    transformation = "not_reviewed", valuation = "not_reviewed", series_sk = 1:2
  ), append = TRUE)
  con
}

testthat::test_that("the register ships empty, so nothing is claimed to be reviewed", {
  register <- read_series_review_register(project_test_root)
  testthat::expect_equal(nrow(register), 0L)
  # Empty and *well formed*: every question section 11.4 asks has a column, so
  # filling one in is a matter of writing an answer rather than inventing a
  # schema.
  testthat::expect_true(all(SERIES_REVIEW_REQUIRED_FIELDS %in% names(register)))
  testthat::expect_true(all(SERIES_REVIEW_CONDITIONAL_FIELDS %in% names(register)))
  testthat::expect_equal(
    series_review_problems(register, "fixture:series")$problem, character()
  )
})

testthat::test_that("a complete review reaches dim_series, and is marked reviewed there", {
  con <- review_fixture()
  root <- write_review_register(withr::local_tempdir(), series_review_row())
  testthat::expect_equal(apply_series_review(con, root), 1L)

  series <- DBI::dbGetQuery(con, paste(
    "SELECT stock_flow, nominal_real, seasonal_adjustment, transformation, valuation,",
    "unit_code, scale_multiplier, price_base_year, is_total",
    "FROM canonical.dim_series WHERE series_id = 'fixture:series'"
  ))
  testthat::expect_equal(series$stock_flow, "flow")
  testthat::expect_equal(series$nominal_real, "real")
  testthat::expect_equal(series$seasonal_adjustment, "not_adjusted")
  testthat::expect_equal(series$price_base_year, "2020")
  testthat::expect_true(series$is_total)

  # The value alone would be indistinguishable from one guessed off a label. What
  # makes it a review is the basis and the sentence beside it, which is the whole
  # design of v_series_measurement.
  evidence <- DBI::dbGetQuery(con, paste(
    "SELECT field, value, basis, evidence FROM canonical.series_semantic_evidence",
    "WHERE series_id = 'fixture:series' ORDER BY field"
  ))
  # Every research-eligibility field, plus the measurement columns. The union is
  # the point: schema 36 made the eligibility gate read this evidence, so a field
  # the gate requires and the register does not record would make a completed
  # review unable to satisfy the check written for it. `frequency` was exactly
  # that field.
  testthat::expect_setequal(evidence$field, union(
    RESEARCH_ELIGIBILITY_FIELDS, c("unit_code", "scale_multiplier", SERIES_SEMANTIC_COLUMNS)
  ))
  testthat::expect_true(all(RESEARCH_ELIGIBILITY_FIELDS %in% evidence$field))
  testthat::expect_equal(unique(evidence$basis), "reviewed")
  testthat::expect_match(evidence$evidence[[1]], "fixture economist")
  testthat::expect_match(evidence$evidence[[1]], "bcp.gov.py")

  # The unreviewed series is untouched: review is per series, not per run.
  testthat::expect_equal(
    DBI::dbGetQuery(con, paste(
      "SELECT stock_flow FROM canonical.dim_series WHERE series_id = 'fixture:parent'"
    ))$stock_flow,
    "not_reviewed"
  )
})

testthat::test_that("a reviewed series satisfies the research-eligibility gate", {
  # The point of the whole register: the gate has existed since schema 28 and
  # nothing could pass it, because nothing could fill the fields it reads.
  con <- review_fixture()
  root <- write_review_register(withr::local_tempdir(), series_review_row())
  apply_series_review(con, root)
  eligible <- DBI::dbGetQuery(con, paste0(
    "SELECT count(*) AS n FROM canonical.dim_series WHERE series_id = 'fixture:series' AND ",
    paste(vapply(RESEARCH_ELIGIBILITY_FIELDS, function(field) paste0(
      field, " IS NOT NULL AND CAST(", field,
      " AS VARCHAR) NOT IN ('not_reviewed', 'UNRESOLVED_SOURCE_UNITS')"
    ), character(1)), collapse = " AND ")
  ))$n[[1]]
  testthat::expect_equal(eligible, 1L)
})

testthat::test_that("a half-finished review blocks the release and applies nothing", {
  # Error severity, and nothing applied. A partly-recorded review is worse than
  # none: it fills exactly the columns the eligibility gate reads, so the series
  # becomes promotable on the strength of a row the reviewer never finished.
  con <- review_fixture()
  root <- write_review_register(
    withr::local_tempdir(), series_review_row(seasonal_adjustment = "", timing_basis = "")
  )
  testthat::expect_equal(apply_series_review(con, root), 0L)
  testthat::expect_equal(
    DBI::dbGetQuery(con, paste(
      "SELECT stock_flow FROM canonical.dim_series WHERE series_id = 'fixture:series'"
    ))$stock_flow,
    "not_reviewed"
  )

  validate_series_review_register(con, "release:x", root)
  flags <- DBI::dbGetQuery(con, "SELECT severity, check_name, detail FROM audit.quality_flags")
  testthat::expect_true("series_review_incomplete" %in% flags$check_name)
  testthat::expect_equal(flags$severity[flags$check_name == "series_review_incomplete"], "error")
})

testthat::test_that("the register cannot review a series that does not exist", {
  con <- review_fixture()
  root <- write_review_register(
    withr::local_tempdir(), series_review_row(series_id = "fixture:not-a-series")
  )
  validate_series_review_register(con, "release:x", root)
  detail <- DBI::dbGetQuery(con, paste(
    "SELECT detail FROM audit.quality_flags WHERE check_name = 'series_review_incomplete'"
  ))$detail
  testthat::expect_length(detail, 1L)
  testthat::expect_match(detail, "does not name a series in this database")
})

testthat::test_that("the vocabularies are closed and the conditional fields are conditional", {
  known <- c("fixture:series", "fixture:parent")
  problems_for <- function(...) series_review_problems(series_review_row(...), known)$problem

  testthat::expect_match(problems_for(stock_flow = "stocks"), "stock_flow must be one of")
  testthat::expect_match(problems_for(timing_basis = "eop"), "timing_basis must be one of")
  testthat::expect_match(problems_for(scale_multiplier = "one"), "scale_multiplier must be a number")
  testthat::expect_match(problems_for(reviewed_at = "01/09/2026"), "must be an ISO date")
  testthat::expect_match(problems_for(definition = "CPI"), "at least")

  # Real without a base year is not a real series, it is an unfinished sentence.
  testthat::expect_match(
    problems_for(price_base_year = ""), "price_base_year is required"
  )
  # ...and the same row is fine once it is nominal, because the field stops
  # meaning anything.
  testthat::expect_equal(
    problems_for(nominal_real = "nominal", price_base_year = ""), character()
  )
  testthat::expect_match(
    problems_for(hierarchy_role = "component"), "parent_series_id is required"
  )
  testthat::expect_equal(
    problems_for(hierarchy_role = "component", parent_series_id = "fixture:parent"), character()
  )
  testthat::expect_match(
    problems_for(hierarchy_role = "component", parent_series_id = "fixture:ghost"),
    "parent_series_id does not name a series"
  )
  testthat::expect_match(
    problems_for(comparability = "break_documented"), "methodology_regime_id is required"
  )
})

testthat::test_that("the seven checks the re-audit's A7 asks for all bite", {
  # Each of these passed silently before schema 36, and each is a claim a
  # reviewer could make by accident that the arithmetic downstream would then
  # believe.
  known <- c("fixture:series", "fixture:parent")
  frequencies <- c("monthly", "quarterly", "annual")
  problems_for <- function(...) series_review_problems(
    series_review_row(...), known, frequencies
  )$problem

  # 1. A frequency the database does not use. Required before, but only checked
  # for blankness, so any string satisfied it.
  testthat::expect_match(problems_for(frequency = "fortnightly"), "frequency must be one")
  testthat::expect_equal(problems_for(frequency = "quarterly"), character())

  # 2. Zero erases the series in value_in_base_units; a negative inverts its sign.
  testthat::expect_match(problems_for(scale_multiplier = "0"), "greater than zero")
  testthat::expect_match(problems_for(scale_multiplier = "-1000"), "greater than zero")
  testthat::expect_equal(problems_for(scale_multiplier = "1000"), character())

  # 3. The base year column is free text and presence was all that was required.
  testthat::expect_match(problems_for(price_base_year = "banana"), "four-digit year")
  testthat::expect_match(problems_for(price_base_year = "20"), "four-digit year")
  testthat::expect_match(problems_for(price_base_year = "1780"), "four-digit year")

  # 4. Self-parenting passed every check, because known_series contains the row's
  # own identifier. Aggregating a total into itself is what follows.
  self_parent <- problems_for(hierarchy_role = "component", parent_series_id = "fixture:series")
  testthat::expect_true(any(grepl("parent_series_id is the series itself", self_parent)))
  # It is also reported as a cycle, which it is -- one of length one. Both
  # messages are true and the specific one is the actionable one.
  testthat::expect_true(any(grepl("contains a cycle", self_parent)))
  # …and a genuine two-row cycle, which no single-row check could see.
  cycle <- rbind(
    series_review_row("fixture:series", hierarchy_role = "component",
                      parent_series_id = "fixture:parent"),
    series_review_row("fixture:parent", hierarchy_role = "component",
                      parent_series_id = "fixture:series")
  )
  testthat::expect_true(any(grepl(
    "contains a cycle", series_review_problems(cycle, known, frequencies)$problem
  )))

  # 5. A three-letter unit code names a currency, and it must be the one declared.
  testthat::expect_match(
    problems_for(unit_code = "USD", currency = "PYG"),
    "contradicts the declared currency"
  )
  testthat::expect_equal(problems_for(unit_code = "USD", currency = "USD"), character())
  # An index of guaraní prices is not a contradiction and must not be flagged.
  testthat::expect_equal(problems_for(unit_code = "INDEX", currency = "PYG"), character())

  # 6. A review dated in the future has not happened.
  future <- format(Sys.Date() + 30L, "%Y-%m-%d")
  testthat::expect_match(problems_for(reviewed_at = future), "in the future")
  testthat::expect_equal(problems_for(reviewed_at = format(Sys.Date(), "%Y-%m-%d")), character())
})

testthat::test_that("the frequency vocabulary is read from the database, not invented", {
  # The project has two frequency lists and they disagree --
  # EXPECTED_GRID_FREQUENCIES omits semiannual, the marts gap screen includes it,
  # and dim_series additionally holds irregular_daily. Adding a third would make
  # it worse, so the register is checked against what the database actually
  # holds.
  con <- review_fixture()
  frequencies <- known_series_frequencies(con)
  testthat::expect_true("monthly" %in% frequencies)
  testthat::expect_equal(
    frequencies,
    sort(DBI::dbGetQuery(con, "SELECT DISTINCT frequency FROM canonical.dim_series")$frequency)
  )
  # An empty vocabulary disables the check rather than rejecting everything: a
  # database with no series cannot say which frequencies are legitimate.
  testthat::expect_equal(
    series_review_problems(series_review_row(frequency = "fortnightly"),
                           "fixture:series", character())$problem,
    character()
  )
})

testthat::test_that("a reviewed judgement is not overwritten by the derivation that follows it", {
  # The primary key on series_semantic_evidence is (series_id, field), and the
  # rebuild deliberately spares reviewed rows while deleting derived ones. Without
  # the anti-join, the next run's derived row for the same key aborts the insert.
  # Latent until this register gave anyone a way to record a review at all.
  con <- review_fixture()
  DBI::dbWriteTable(con, "documented_series_snapshot", tibble::tibble(
    vintage_id = "fixture:v1", series_id = "fixture:series", period = as.Date("2024-01-31"),
    source_id = "fixture", source_sheet = "Hoja", value = 1,
    series_label = "Saldo a fin de periodo, serie original", table_title = "Cuadro fixture"
  ), append = TRUE)

  root <- write_review_register(withr::local_tempdir(), series_review_row())
  apply_series_review(con, root)
  # The label says "saldo" and "serie original", so the derivation would write
  # stock/not_adjusted for both fields if it were allowed to.
  testthat::expect_no_error(derive_series_semantics_from_text(con))

  evidence <- DBI::dbGetQuery(con, paste(
    "SELECT field, value, basis FROM canonical.series_semantic_evidence",
    "WHERE series_id = 'fixture:series' AND field IN ('stock_flow', 'seasonal_adjustment')",
    "ORDER BY field"
  ))
  testthat::expect_equal(nrow(evidence), 2L)
  testthat::expect_equal(unique(evidence$basis), "reviewed")
  # The reviewer said flow; the label said saldo. The reviewer wins.
  testthat::expect_equal(evidence$value[evidence$field == "stock_flow"], "flow")
})
