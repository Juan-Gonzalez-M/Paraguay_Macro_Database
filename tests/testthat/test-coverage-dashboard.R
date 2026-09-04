# The seventh audit's F-06 and its section 11.2.
#
# Two levels, because the defect had two: the dashboard fanned out, and the
# precedence idiom it was supposed to be copying was itself only accidentally
# right. The first test is on the resolver, so it holds without a database of any
# particular shape; the second is the audit's own query against the file a
# reader actually opens.

testthat::test_that("a register keyed by worksheet resolves exact over wildcard, once", {
  con <- DBI::dbConnect(duckdb::duckdb(), ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbWriteTable(con, "grains", tibble::tibble(
    source_id = c("di", "di", "di", "annex"),
    source_sheet = c("*", "Cuadro 5", "Cuadro 7", "*"),
    series_grain = c("scalar_series", "entity_panel", "entity_panel", "scalar_series")
  ))
  keys <- paste(
    "SELECT 'di' AS source_id, 'Cuadro 1' AS source_sheet",
    "UNION ALL SELECT 'di', 'Cuadro 5'",
    "UNION ALL SELECT 'di', 'Cuadro 7'",
    "UNION ALL SELECT 'annex', 'CUADRO 9'"
  )
  resolved <- DBI::dbGetQuery(con, wildcard_precedence_join_sql("grains", "series_grain", keys))

  # One row per worksheet: the fan-out is the defect, and 4 keys must give 4 rows
  # even though 'di' carries three rules.
  testthat::expect_equal(nrow(resolved), 4L)
  testthat::expect_equal(nrow(dplyr::distinct(resolved, source_id, source_sheet)), 4L)

  grain_of <- function(sheet) resolved$series_grain[resolved$source_sheet == sheet]
  # The worksheet rule wins where there is one...
  testthat::expect_equal(grain_of("Cuadro 5"), "entity_panel")
  testthat::expect_equal(grain_of("Cuadro 7"), "entity_panel")
  # ...and the source rule applies where there is not. A resolver that simply
  # preferred worksheet rows would drop this worksheet entirely.
  testthat::expect_equal(grain_of("Cuadro 1"), "scalar_series")
  testthat::expect_equal(grain_of("CUADRO 9"), "scalar_series")
})

testthat::test_that("the tie-break reads the rule's own key, not the worksheet's", {
  # The quiet half of F-06. The copy this replaces selected the *worksheet's*
  # source_sheet and then ordered by `CASE WHEN source_sheet = '*'`, which is
  # never true of a worksheet -- so the window's ordering was constant and the
  # winner arbitrary whenever both a wildcard and an exact rule matched. Five
  # sources and fifteen worksheets are in that position today; it is latent only
  # because all fifteen exact rules currently agree with their wildcard.
  #
  # Here they disagree, which is the only way to observe the difference.
  con <- DBI::dbConnect(duckdb::duckdb(), ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbWriteTable(con, "status", tibble::tibble(
    source_id = c("s", "s"), source_sheet = c("*", "Hoja"),
    status = c("provisional", "validated")
  ))
  resolved <- DBI::dbGetQuery(con, wildcard_precedence_join_sql(
    "status", "status", "SELECT 's' AS source_id, 'Hoja' AS source_sheet"
  ))
  testthat::expect_equal(nrow(resolved), 1L)
  testthat::expect_equal(resolved$status, "validated")
})

testthat::test_that("the published coverage dashboard holds one row per worksheet", {
  # Section 11.2's query, against the file itself:
  #   SELECT source_id, source_sheet, count(*) ... HAVING count(*) <> 1
  # must return nothing.
  path <- file.path(project_test_root, "outputs", "coverage_dashboard.csv")
  testthat::skip_if_not(file.exists(path), "no coverage dashboard has been generated")
  dashboard <- readr::read_csv(path, show_col_types = FALSE, progress = FALSE)
  duplicated_keys <- dashboard %>%
    dplyr::count(.data$source_id, .data$source_sheet, name = "rows") %>%
    dplyr::filter(.data$rows != 1L)
  testthat::expect_equal(nrow(duplicated_keys), 0L)
  testthat::expect_equal(
    nrow(dashboard), nrow(dplyr::distinct(dashboard, .data$source_id, .data$source_sheet))
  )

  # And the grain the fan-out was corrupting is the one schema 32 introduced:
  # direct investment's country panels are not scalar macro series.
  direct <- dashboard %>% dplyr::filter(.data$source_id == "direct_investment")
  testthat::skip_if(nrow(direct) == 0L, "direct investment is not in this dashboard")
  entity <- direct$source_sheet[direct$series_grain == "entity_panel"]
  testthat::expect_setequal(entity, c("Cuadro 5", "Cuadro 7"))
})
