# The audit's ER-02: one safe temporal key.
#
# The defect these protect against produced no error message. Joining the price
# index to the exchange rate through the documented read path returned zero rows,
# because the two sources date monthly observations to different days, and
# nothing said so. The regression is therefore not "does the join work" but
# "does the unsafe join stay visibly unsafe while the safe one is available on
# the path researchers are actually sent to".

temporal_production <- function() {
  path <- file.path(project_test_root, "database", "paraguay_macro_pilot.duckdb")
  testthat::skip_if_not(file.exists(path), "production database not present")
  con <- connect_project_database(path, read_only = TRUE)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE), envir = parent.frame())
  con
}

testthat::test_that("the documented current-value view carries the normalised bounds", {
  con <- temporal_production()
  # The whole of ER-02 in one assertion: the columns exist where README.md and
  # scripts/05_query_helpers.R actually send people. They existed on
  # v_series_observations before schema 39 and that was not where anyone looked.
  for (view in c("v_series_latest", "v_publisher_statement_latest", "v_series_observations",
                 "v_series_research")) {
    columns <- table_column_names(con, view)
    testthat::expect_true("period_start" %in% columns, info = view)
    testthat::expect_true("period_end" %in% columns, info = view)
    # And `period` survives: it is half the observation key and it is the date
    # the publisher printed.
    testthat::expect_true("period" %in% columns, info = view)
  }
})

testthat::test_that("the interval contains its own observation and the canonical key is unique", {
  con <- temporal_production()
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM main.v_series_observations",
    "WHERE period_start IS NULL OR period_end IS NULL OR period_end < period_start",
    "   OR period < period_start OR period > period_end"
  ))$n[[1]], 0L)
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM (SELECT 1 FROM main.v_series_observations",
    "WHERE NOT is_deleted GROUP BY series_id, period_start HAVING count(*) > 1)"
  ))$n[[1]], 0L)
  # Monthly bounds are the month, whichever day the source used. This is the
  # property that makes a cross-source monthly join possible at all.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM main.v_series_latest l",
    "JOIN canonical.dim_series d USING (series_id)",
    "WHERE d.frequency = 'monthly'",
    "  AND (l.period_start <> date_trunc('month', l.period) OR l.period_end <> last_day(l.period))"
  ))$n[[1]], 0L)
})

testthat::test_that("the audit's zero-row join is the raw-date join, and the canonical key fixes it", {
  con <- temporal_production()
  # The exact monthly-date mismatch documented by Paraguay_Macro_Database_Audit.md:
  # the consumer price index on the economic annex (dated day 1) against the
  # monthly average PYG/USD rate on exchange_rates (dated month end).
  cpi <- "economic_annex:cuadro_60b:293a83a82f814b7fc49afadc"
  fx <- "exchange_rates:usd_prom:190c4a9509f6c233bdc28928"
  counts <- DBI::dbGetQuery(con, paste0(
    "WITH cpi AS (SELECT period, period_start FROM main.v_series_latest",
    "             WHERE series_id = ", sql_string(cpi), "),",
    "     fx  AS (SELECT period, period_start FROM main.v_series_latest",
    "             WHERE series_id = ", sql_string(fx), ")",
    " SELECT (SELECT count(*) FROM cpi) AS cpi_obs,",
    "        (SELECT count(*) FROM fx) AS fx_obs,",
    "        (SELECT count(*) FROM cpi JOIN fx USING (period)) AS join_on_period,",
    "        (SELECT count(*) FROM cpi JOIN fx USING (period_start)) AS join_on_period_start"
  ))
  testthat::skip_if(counts$cpi_obs[[1]] == 0L || counts$fx_obs[[1]] == 0L,
                    "the audit's demonstration series are not in this database")
  # Both series have data...
  testthat::expect_gt(counts$cpi_obs[[1]], 300L)
  testthat::expect_gt(counts$fx_obs[[1]], 300L)
  # ...the raw-date join still finds nothing, because the sources still date
  # their months differently and this database does not rewrite what they
  # published...
  testthat::expect_equal(counts$join_on_period[[1]], 0L)
  # ...and the canonical key returns the shared sample. The audit measured 378
  # months; asserting "the overlap, not zero" keeps the test true when a new
  # vintage extends either series.
  testthat::expect_equal(
    counts$join_on_period_start[[1]],
    min(counts$cpi_obs[[1]], counts$fx_obs[[1]])
  )
  testthat::expect_gte(counts$join_on_period_start[[1]], 378L)
})

testthat::test_that("series_wide() will not guess a join key and will not accept the unsafe one", {
  con <- temporal_production()
  ids <- c("economic_annex:cuadro_60b:293a83a82f814b7fc49afadc",
           "exchange_rates:usd_prom:190c4a9509f6c233bdc28928")
  testthat::skip_if_not(
    DBI::dbGetQuery(con, paste0(
      "SELECT count(*) AS n FROM main.v_series_research WHERE series_id IN (",
      paste(vapply(ids, sql_string, character(1)), collapse = ", "), ")"
    ))$n[[1]] > 0L,
    "the audit's demonstration series are not in this database"
  )
  # No default. Choosing the key is the decision that went wrong.
  testthat::expect_error(series_wide(con, ids), "requires an explicit `key`")
  # And the unsafe key is refused by name, with the reason.
  testthat::expect_error(series_wide(con, ids, key = "period"), "not a join key")
  testthat::expect_error(series_wide(con, ids, key = "fecha"), "Unknown key")

  wide <- series_wide(con, ids, key = "period_start")
  testthat::expect_named(wide, c("period_start", ids))
  testthat::expect_gte(nrow(wide), 378L)
  # A regular monthly index, which is the property a lag or a difference needs
  # and the one the raw `period` column of a mixed-convention series lacks.
  steps <- unique(diff(as.integer(format(wide$period_start, "%Y")) * 12L +
                         as.integer(format(wide$period_start, "%m"))))
  testthat::expect_equal(steps, 1L)
  testthat::expect_equal(attr(wide, "period_key"), "period_start")
  testthat::expect_null(attr(wide, "aggregated_to"))
})

testthat::test_that("series_wide() refuses to combine frequencies without a stated rule", {
  con <- temporal_production()
  mixed <- DBI::dbGetQuery(con, paste(
    "SELECT frequency, any_value(series_id) AS series_id FROM main.v_series_research",
    "WHERE frequency IN ('monthly', 'annual') GROUP BY 1"
  ))
  testthat::skip_if(nrow(mixed) < 2L, "no monthly/annual pair available")
  testthat::expect_error(
    series_wide(con, mixed$series_id, key = "period_start"),
    "span 2 frequencies"
  )
  # With a rule, it aligns to the coarsest frequency and records what it did,
  # rather than doing it silently or refusing to do it at all.
  aligned <- series_wide(con, mixed$series_id, key = "period_start", aggregate = "period_average")
  testthat::expect_equal(attr(aligned, "aggregated_to"), "annual")
  testthat::expect_equal(attr(aligned, "aggregation_rule"), "period_average")
  testthat::expect_true(all(format(aligned$period_start, "%m-%d") == "01-01"))
  testthat::expect_error(
    series_wide(con, mixed$series_id, key = "period_start", aggregate = "whatever"),
    "Unknown aggregate rule"
  )
})

testthat::test_that("the mixed-convention series are reported rather than silently normalised", {
  con <- temporal_production()
  # The bounds make these safe to join. They do not make the raw `period` column
  # a regular index, and the contract says so out loud rather than letting the
  # repair look like a resolution.
  mixed <- DBI::dbGetQuery(con, paste(
    "WITH o AS (",
    "  SELECT series_id, CASE WHEN day(period) = 1 THEN 'month_start'",
    "    WHEN day(period) >= 28 THEN 'month_end' ELSE 'other' END AS convention",
    "  FROM main.v_series_observations",
    "  WHERE frequency IN ('monthly','monthly_survey') AND NOT is_deleted)",
    "SELECT count(*) AS n FROM (SELECT series_id FROM o GROUP BY 1",
    "  HAVING count(DISTINCT convention) > 1)"
  ))$n[[1]]
  testthat::expect_gt(mixed, 0L)
  worklist <- file.path(project_test_root, "outputs", "temporal_convention_worklist.csv")
  testthat::skip_if_not(file.exists(worklist), "worklist not generated in this working tree")
  rows <- readr::read_csv(worklist, show_col_types = FALSE)
  testthat::expect_equal(nrow(rows), mixed)
  testthat::expect_true(all(c("review_priority", "observations_month_start",
                              "observations_month_end") %in% names(rows)))
})

testthat::test_that("canonical members are compared on the normalised period", {
  # The temporal key reaching into the canonical layer, and the reason it had to.
  #
  # A canonical membership exists to relate series from different sources, and
  # different sources do not agree on which day of the month a monthly
  # observation carries. Both membership checks joined `af.period = pf.period`,
  # so the first genuine cross-source alias shared zero *dates* with its primary
  # -- and the two checks then failed in opposite directions: the value check
  # compared nothing and passed, while the comparability check saw no overlap and
  # blocked. The untested half is the dangerous one.
  path <- withr::local_tempfile(fileext = ".duckdb")
  con <- DBI::dbConnect(duckdb::duckdb(), path)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  initialize_database(con, project_test_root)

  months <- seq(as.Date("2020-01-01"), as.Date("2020-12-01"), by = "month")
  DBI::dbWriteTable(con, "dim_series", tibble::tibble(
    series_id = c("cx:primary", "cx:alias"), source_id = c("src_a", "src_b"),
    label = c("Rate", "Rate"), unit = "index", scale = "units", frequency = "monthly",
    first_vintage_id = "cx:v1", series_grain = "scalar_series", unit_code = "INDEX",
    scale_multiplier = 1, series_sk = 1:2
  ), append = TRUE)
  # Identical values, on identical months, dated the way their two publishers
  # date them: one to the first of the month, one to the last.
  DBI::dbWriteTable(con, "fact_series_events", tibble::tibble(
    series_id = rep(c("cx:primary", "cx:alias"), each = length(months)),
    period = c(months, as.Date(vapply(months, function(m) {
      as.character(seq(m, by = "month", length.out = 2)[[2]] - 1)
    }, character(1)))),
    value = rep(seq_along(months) + 100, times = 2),
    vintage_id = "cx:v1", publication_date = as.Date("2021-01-15"), is_deleted = FALSE,
    source_file = "cx.xlsx", series_sk = rep(1:2, each = length(months)), vintage_sk = 1L
  ), append = TRUE)
  DBI::dbWriteTable(con, "map_canonical_series", tibble::tibble(
    canonical_series_id = "canon:cx", series_id = c("cx:primary", "cx:alias"),
    relationship = c("primary", "alias"), evidence = "fixture",
    reviewed_by = "fixture", reviewed_at = as.Date("2026-01-01")
  ), append = TRUE)

  # They share no date at all -- which is the whole point.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM canonical.fact_series_events pf",
    "JOIN canonical.fact_series_events af ON af.period = pf.period",
    "WHERE pf.series_id = 'cx:primary' AND af.series_id = 'cx:alias'"
  ))$n[[1]], 0L)

  # And yet they are the same figure on every month, so nothing should fire.
  DBI::dbExecute(con, "DELETE FROM audit.quality_flags")
  testthat::expect_true(validate_canonical_membership_agreement(con, "cx"))
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM audit.quality_flags WHERE release_id = 'cx'"
  ))$n[[1]], 0L)

  # The comparison is real, not vacuous: change one value and it must be caught.
  DBI::dbExecute(con, paste(
    "UPDATE canonical.fact_series_events SET value = value + 5",
    "WHERE series_id = 'cx:alias' AND period = DATE '2020-06-30'"
  ))
  DBI::dbExecute(con, "DELETE FROM audit.quality_flags")
  testthat::expect_false(validate_canonical_membership_agreement(con, "cx"))
  flags <- DBI::dbGetQuery(con, paste(
    "SELECT check_name, detail FROM audit.quality_flags WHERE release_id = 'cx'"
  ))
  testthat::expect_equal(flags$check_name, "canonical_alias_disagrees")
  # One disagreeing month out of twelve compared -- so the overlap was measured,
  # which is what the old exact-date join could never do.
  testthat::expect_match(flags$detail, "(1 of 12)", fixed = TRUE)
})
