# The audit's ER-05: a research extraction interface that returns enough to
# interpret what it returned.
#
# `series_latest()` gave a researcher seven columns -- no label, no unit, no
# frequency -- and the join that fixes that lands on a label which names more
# than one series 1,599 times over. These are the contract tests: the columns
# are present, the grain is one row per key, and an ambiguous label is an error
# rather than an arbitrary choice.

research_production <- function() {
  path <- file.path(project_test_root, "database", "paraguay_macro_pilot.duckdb")
  testthat::skip_if_not(file.exists(path), "production database not present")
  con <- connect_project_database(path, read_only = TRUE)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE), envir = parent.frame())
  con
}

# The audit's P1.1 field list, plus the four its ER-05.1 adds. Named here so a
# column that goes missing fails this test rather than a researcher's script.
RESEARCH_CONTRACT_COLUMNS <- c(
  "series_id", "label", "table_title", "source_id", "source_sheet",
  "period", "period_start", "period_end", "frequency",
  "unit_code", "scale_multiplier", "currency",
  "stock_flow", "nominal_real", "seasonal_adjustment", "transformation",
  "hierarchy_status", "hierarchy_role", "methodology_regime_id", "review_status",
  "value", "value_in_base_units", "vintage_id", "available_at", "observation_status"
)

testthat::test_that("the research view carries every field the contract names", {
  con <- research_production()
  columns <- table_column_names(con, "v_series_research")
  for (field in RESEARCH_CONTRACT_COLUMNS) {
    testthat::expect_true(field %in% columns, info = field)
  }
})

testthat::test_that("the research view is one row per series and period, and realised only", {
  con <- research_production()
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM (SELECT 1 FROM main.v_series_research",
    "GROUP BY series_id, period HAVING count(*) > 1)"
  ))$n[[1]], 0L)
  # A projection reaching the default research surface is the defect schema 30
  # named: a 2028 forecast that looks exactly like an outcome.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM main.v_series_research",
    "WHERE observation_status <> 'observed'"
  ))$n[[1]], 0L)
  # And the release boundary is inherited, not reimplemented: nothing appears
  # here that is absent from the carrier it descends from.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM main.v_series_research r",
    "WHERE NOT EXISTS (SELECT 1 FROM main.v_series_observations o",
    "  WHERE o.series_id = r.series_id AND o.period = r.period",
    "    AND o.vintage_id = r.vintage_id)"
  ))$n[[1]], 0L)
})

testthat::test_that("value_in_base_units is the stored value times its declared scale, and nothing else", {
  con <- research_production()
  # No silent rescaling, deflation, splicing or seasonal adjustment. The two
  # value columns differ by exactly the multiplier the metadata declares.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM main.v_series_research",
    "WHERE scale_multiplier IS NOT NULL",
    "  AND abs(value_in_base_units - value * scale_multiplier) > 1e-9 * abs(value_in_base_units)"
  ))$n[[1]], 0L)
})

testthat::test_that("the published table title is reachable without touching a staging table", {
  con <- research_production()
  titled <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS with_title, count(DISTINCT series_id) AS series",
    "FROM main.v_series_titles WHERE table_title IS NOT NULL AND table_title <> ''"
  ))
  testthat::expect_gt(titled$series[[1]], 0L)
  # One row per series: the join into the research view must not fan out, which
  # is the whole reason the title is resolved into a table rather than joined
  # from the observation-grain snapshot.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM (SELECT 1 FROM canonical.series_titles",
    "GROUP BY series_id HAVING count(*) > 1)"
  ))$n[[1]], 0L)
  # A publisher who retitles a table between vintages is a fact, not a fan-out.
  testthat::expect_true("title_varies_by_vintage" %in% table_column_names(con, "series_titles"))
})

testthat::test_that("an ambiguous label is an error that names the candidates", {
  con <- research_production()
  worst <- DBI::dbGetQuery(con, paste(
    "SELECT label, count(DISTINCT series_id) AS series FROM main.v_series_research",
    "GROUP BY 1 HAVING count(DISTINCT series_id) > 1 ORDER BY 2 DESC LIMIT 1"
  ))
  testthat::skip_if(!nrow(worst), "no ambiguous label in this database")
  # The audit's section 4: 4,015 of 7,229 scalar series share a label. A helper
  # that returned the first match would return current prices where the caller
  # meant constant, with nothing in the result to say so.
  testthat::expect_error(
    series_research(con, label = worst$label[[1]]),
    "names .* series, so it cannot select one"
  )
  # The error is a worklist, not a complaint: it has to name what to pass instead.
  message <- tryCatch(
    series_research(con, label = worst$label[[1]]), error = conditionMessage
  )
  testthat::expect_match(message, "Pass series_id")
  testthat::expect_match(message, worst$label[[1]], fixed = TRUE)

  unambiguous <- DBI::dbGetQuery(con, paste(
    "SELECT label FROM main.v_series_research GROUP BY 1",
    "HAVING count(DISTINCT series_id) = 1 LIMIT 1"
  ))$label
  testthat::skip_if(!length(unambiguous), "no unambiguous label in this database")
  found <- series_research(con, label = unambiguous[[1]])
  testthat::expect_gt(nrow(found), 0L)
  testthat::expect_equal(length(unique(found$series_id)), 1L)
})

testthat::test_that("an empty result keeps the full column set", {
  con <- research_production()
  # A zero-row frame with no columns breaks every downstream mutate. The contract
  # is the columns, not the rows.
  empty <- series_research(con, series_id = "no:such:series")
  testthat::expect_equal(nrow(empty), 0L)
  for (field in RESEARCH_CONTRACT_COLUMNS) {
    testthat::expect_true(field %in% names(empty), info = field)
  }
})

testthat::test_that("the whole research path works from a default connection", {
  path <- file.path(project_test_root, "database", "paraguay_macro_pilot.duckdb")
  testthat::skip_if_not(file.exists(path), "production database not present")
  # No search path, exactly as an external client connects -- the condition
  # scripts/05_query_helpers.R exists to enforce, and the one schema 22 was
  # written for. A new view that binds a dependency unqualified fails here.
  con <- DBI::dbConnect(duckdb::duckdb(), path, read_only = TRUE)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  for (object in c("main.v_series_research", "main.v_series_titles", "main.v_series_latest")) {
    testthat::expect_gte(
      DBI::dbGetQuery(con, paste0("SELECT count(*) AS n FROM ", object))$n[[1]], 0L,
      info = object
    )
  }
  one <- DBI::dbGetQuery(con, "SELECT series_id FROM main.v_series_research LIMIT 1")$series_id
  testthat::skip_if(!length(one), "no observations published")
  testthat::expect_gt(nrow(series_research(con, series_id = one)), 0L)
})
