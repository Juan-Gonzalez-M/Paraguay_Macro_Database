# The audit's ER-01: exchange-rate units and currency semantics.
#
# Two defects, both caused by the same mechanism -- a worksheet's unit is
# inherited by every column on it, so one heterogeneous table mislabels all of
# it. On CUADRO 60c five index numbers titled "(enero 1995 = 100)" were tagged as
# a price of US dollars; on CUADRO 60a the euro, Argentine-peso and
# Brazilian-real columns all declared a dollar denominator.
#
# The tests that matter here are the ones that fail if the correction is
# reverted AND the ones that fail if the check that found it stops working. A
# validation rule that cannot be shown to fire is not evidence of anything.

unit_production <- function() {
  path <- file.path(project_test_root, "database", "paraguay_macro_pilot.duckdb")
  testthat::skip_if_not(file.exists(path), "production database not present")
  con <- connect_project_database(path, read_only = TRUE)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE), envir = parent.frame())
  con
}

testthat::test_that("the CUADRO 60c series are index numbers with the published base", {
  con <- unit_production()
  rows <- DBI::dbGetQuery(con, paste(
    "SELECT series_id, label, unit_code, currency, index_base, transformation",
    "FROM canonical.dim_series WHERE series_id LIKE 'economic_annex:cuadro_60c:%'",
    "ORDER BY label"
  ))
  testthat::skip_if(!nrow(rows), "CUADRO 60c is not in this database")
  testthat::expect_setequal(rows$label, c("IPC", "TCN", "TCR Arg", "TCR Br", "TCR USA"))
  testthat::expect_true(all(rows$unit_code == "INDEX"))
  # An index has a base, not a denominator. Both halves are asserted, because
  # clearing the currency without recording the base would replace a wrong
  # answer with a missing one.
  testthat::expect_true(all(is.na(rows$currency)))
  testthat::expect_true(all(grepl("1995", rows$index_base)))
  testthat::expect_true(all(rows$transformation == "index"))

  # The control case that makes this a correction rather than an opinion: the
  # sibling worksheet publishes the same series under the same identity hashes,
  # and was always coded INDEX. If 60c is wrong, so is 60b.
  sibling <- DBI::dbGetQuery(con, paste(
    "SELECT unit_code FROM canonical.dim_series",
    "WHERE series_id = 'economic_annex:cuadro_60b:293a83a82f814b7fc49afadc'"
  ))
  testthat::skip_if(!nrow(sibling), "CUADRO 60b is not in this database")
  testthat::expect_equal(sibling$unit_code[[1]], "INDEX")
})

testthat::test_that("CUADRO 60a quotations name the currency they are actually against", {
  con <- unit_production()
  rows <- DBI::dbGetQuery(con, paste(
    "SELECT label, unit_code, currency FROM canonical.dim_series",
    "WHERE series_id LIKE 'economic_annex:cuadro_60a:%' ORDER BY label"
  ))
  testthat::skip_if(!nrow(rows), "CUADRO 60a is not in this database")
  expected <- c(Euro = "PYG_PER_EUR", Peso = "PYG_PER_ARS", Real = "PYG_PER_BRL",
                `USD 1/` = "PYG_PER_USD")
  for (label in names(expected)) {
    testthat::expect_equal(
      rows$unit_code[rows$label == label], unname(expected[[label]]), info = label
    )
  }
  testthat::expect_equal(
    rows$currency[rows$label == "Euro"], "PYG/EUR"
  )
})

testthat::test_that("filtering by PYG_PER_USD returns only quotations of the dollar", {
  con <- unit_production()
  # The audit's acceptance criterion for ER-01, stated as a query a researcher
  # would actually run: no index number may enter this result.
  offenders <- DBI::dbGetQuery(con, paste(
    "SELECT d.series_id, d.label, t.table_title",
    "FROM canonical.dim_series d",
    "LEFT JOIN canonical.series_titles t USING (series_id)",
    "WHERE d.unit_code = 'PYG_PER_USD'",
    "  AND (d.series_id LIKE '%cuadro_60c%'",
    "       OR lower(coalesce(t.table_title, '')) LIKE '%tipo de cambio real%')"
  ))
  testthat::expect_equal(nrow(offenders), 0L)
  # And every series still carrying the unit is denominated in dollars.
  remaining <- DBI::dbGetQuery(con, paste(
    "SELECT series_id, label, currency FROM canonical.dim_series WHERE unit_code = 'PYG_PER_USD'"
  ))
  testthat::expect_gt(nrow(remaining), 0L)
  testthat::expect_true(all(remaining$currency %in% "PYG/USD"))
})

testthat::test_that("the unit-family check fires on the defect it was written for", {
  # A validation rule that has only ever been run against corrected data has not
  # been shown to work. This reconstructs both defects in a fixture and asserts
  # the check reports them, then corrects them and asserts it goes quiet.
  path <- withr::local_tempfile(fileext = ".duckdb")
  con <- DBI::dbConnect(duckdb::duckdb(), path)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  initialize_database(con, project_test_root)

  DBI::dbWriteTable(con, "dim_series", tibble::tibble(
    series_id = c("fx:euro", "fx:index", "fx:usd"),
    source_id = "fx", label = c("Euro", "TCR USA", "USD 1/"),
    unit = "PYG_per_USD", scale = "units", frequency = "monthly",
    currency = "PYG/USD", first_vintage_id = "fx:v1", series_grain = "scalar_series",
    unit_code = "PYG_PER_USD", scale_multiplier = 1, series_sk = 1:3
  ), append = TRUE)
  DBI::dbWriteTable(con, "documented_series_snapshot", tibble::tibble(
    vintage_id = "fx:v1", release_id = "fx:r1", publication_date = as.Date("2026-01-31"),
    source_id = "fx", source_file = "fx.xlsx", source_sheet = "CUADRO 60x",
    table_title = "Cuadro Nº 60x — Tipo de cambio real bilateral — (enero 1995 = 100)",
    parser_mode = "documented",
    series_id = c("fx:euro", "fx:index", "fx:usd"),
    identity_basis = "semantic", identity_stability = "semantic",
    hierarchy_status = "unresolved", period = as.Date("2026-01-31"),
    source_period_label = "ene-26", frequency = "monthly",
    series_label = c("Euro", "TCR USA", "USD 1/"),
    series_path = c("Euro", "TCR USA", "USD 1/"),
    unit = "PYG_per_USD", scale = "units", currency = "PYG/USD",
    value = c(8000, 120, 7000), is_total = FALSE, source_row = 1:3, source_column = 2L
  ), append = TRUE)

  DBI::dbExecute(con, "DELETE FROM audit.quality_flags")
  validate_unit_family_plausibility(con, "fixture")
  flags <- DBI::dbGetQuery(con, paste(
    "SELECT check_name, severity, detail FROM audit.quality_flags WHERE release_id = 'fixture'"
  ))
  # The euro column names a currency its declared denominator is not...
  testthat::expect_true("unit_currency_contradicts_label" %in% flags$check_name)
  testthat::expect_match(
    flags$detail[flags$check_name == "unit_currency_contradicts_label"], "EUR"
  )
  # ...and the whole worksheet is titled as an index while declaring a price.
  testthat::expect_true("unit_family_contradicts_index_wording" %in% flags$check_name)
  # Warnings, not errors: this reads free text, and a check that reads prose and
  # stops the release is a check somebody deletes. The gate that fails closed is
  # research eligibility, not this.
  testthat::expect_true(all(flags$severity == "warning"))

  # `USD 1/` is correct and must not be reported. A check that flags everything
  # is as useless as one that flags nothing.
  testthat::expect_false(any(grepl("USD 1/", flags$detail, fixed = TRUE)))

  # Corrected, the check goes quiet.
  DBI::dbExecute(con, paste(
    "UPDATE canonical.dim_series SET unit = 'PYG_per_EUR', unit_code = 'PYG_PER_EUR',",
    "currency = 'PYG/EUR' WHERE series_id = 'fx:euro'"
  ))
  DBI::dbExecute(con, paste(
    "UPDATE canonical.dim_series SET unit = 'index', unit_code = 'INDEX', currency = NULL",
    "WHERE series_id = 'fx:index'"
  ))
  DBI::dbExecute(con, "DELETE FROM audit.quality_flags")
  validate_unit_family_plausibility(con, "fixture")
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM audit.quality_flags WHERE release_id = 'fixture'"
  ))$n[[1]], 0L)
})

testthat::test_that("a unit override that would apply to nothing blocks instead of doing nothing", {
  register <- read_unit_override_register(project_test_root)
  testthat::expect_gt(nrow(register), 0L)
  # The register as shipped is clean against the real catalogue.
  path <- file.path(project_test_root, "database", "paraguay_macro_pilot.duckdb")
  testthat::skip_if_not(file.exists(path), "production database not present")
  con <- connect_project_database(path, read_only = TRUE)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  placement <- unit_override_series_placement(con)
  testthat::expect_equal(nrow(unit_override_problems(register, placement)), 0L)

  # A correction aimed at a series that does not exist is not inert. Identity is
  # positional on many worksheets, so a rebuild can move it, and the reviewer
  # would go on believing the defect was fixed.
  moved <- register
  moved$series_id[[1]] <- "economic_annex:cuadro_60c:no-such-series"
  problems <- unit_override_problems(moved, placement)
  testthat::expect_gt(nrow(problems), 0L)
  testthat::expect_match(paste(problems$problem, collapse = " "), "silently apply to nothing")

  # And unit_code that is not the normalisation of unit would leave the two
  # disagreeing after the build recomputes one from the other.
  inconsistent <- register
  inconsistent$unit_code[[1]] <- "SOMETHING_ELSE"
  testthat::expect_match(
    paste(unit_override_problems(inconsistent, placement)$problem, collapse = " "),
    "not the normalisation"
  )
})
