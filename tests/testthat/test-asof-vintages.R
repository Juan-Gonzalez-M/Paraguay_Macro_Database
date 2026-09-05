# The audit's ER-04: availability, and the no-look-ahead property that depends
# on it.
#
# The mechanism was repaired in schema 36 and has never had evidence to run on:
# one vintage per source, zero recorded revisions, no operator-recorded
# availability. So it is tested against synthetic accumulated vintages, which is
# what the audit's ER-04.5 asks for -- "before first availability, between
# releases and after a revision. Confirm that a cutoff never sees a later value."
#
# What these cannot test, and what no test can, is the history that was never
# retained. That is documented as irrecoverable in docs/ACQUISITION_RUNBOOK.md.

availability_fixture <- function(env = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".duckdb", .local_envir = env)
  con <- DBI::dbConnect(duckdb::duckdb(), path)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE), envir = env)
  initialize_database(con, project_test_root)
  for (table_name in c("releases", "release_sources", "data_releases", "active_data_release")) {
    DBI::dbExecute(con, paste0("DELETE FROM audit.", table_name))
  }

  bundles <- c(first = "release:av-a", second = "release:av-b")
  vintages <- c(first = "fixture:av1", second = "fixture:av2")
  DBI::dbWriteTable(con, "release_sources", tibble::tibble(
    release_id = unname(bundles), source_id = "fixture", vintage_id = unname(vintages)
  ), append = TRUE)
  DBI::dbWriteTable(con, "source_files", tibble::tibble(
    vintage_id = unname(vintages), first_ingested_release_id = unname(bundles),
    source_id = "fixture", source_label = "Fixture", publisher = "Fixture",
    source_format = "xlsx", source_file = paste0(names(vintages), ".xlsx"),
    source_path = NA_character_, archive_path = NA_character_,
    sha256 = c("a1", "a2"), size_bytes = 1,
    publication_date = as.Date(c("2026-02-10", "2026-05-10")),
    publication_date_source = "filename", first_ingested_at = Sys.time(),
    ingestion_status = "completed", vintage_sk = 1:2
  ), append = TRUE)
  # The operator's record, which is what the as-of ranking actually reads. The
  # first vintage carries a publisher release timestamp; the second carries only
  # a retrieval time, so both quality levels are exercised.
  DBI::dbWriteTable(con, "source_provenance", tibble::tibble(
    vintage_id = unname(vintages), source_id = "fixture", sha256 = c("a1", "a2"),
    official_release_date = as.Date(c("2026-02-10", NA)),
    official_url = c("https://example.invalid/release", NA_character_),
    release_identifier = c("2026-02", NA_character_),
    retrieved_at = c("2026-02-11T09:00:00Z", "2026-05-12T09:00:00Z"),
    retrieval_method = c("manual_download", "manual_download"),
    available_at = as.POSIXct(c("2026-02-10 00:00:00", "2026-05-12 09:00:00"), tz = "UTC"),
    availability_quality = c("official_release", "retrieval_time"),
    license = c("open", "open"), evidence = c("fixture", "fixture"), recorded_at = Sys.time()
  ), append = TRUE)
  DBI::dbWriteTable(con, "dim_series", tibble::tibble(
    series_id = "fixture:series", source_id = "fixture", label = "Fixture series",
    unit = "index", scale = "units", frequency = "monthly", first_vintage_id = "fixture:av1",
    series_grain = "scalar_series", unit_code = "INDEX", scale_multiplier = 1, series_sk = 1L
  ), append = TRUE)
  # One period, published at 100 and revised to 175. The period is held constant
  # so that the only thing changing between cutoffs is the vintage.
  DBI::dbWriteTable(con, "fact_series_events", tibble::tibble(
    series_id = "fixture:series", period = as.Date("2026-01-31"),
    value = c(100, 175), vintage_id = unname(vintages),
    publication_date = as.Date(c("2026-02-10", "2026-05-10")),
    is_deleted = FALSE, source_file = paste0(names(vintages), ".xlsx"),
    series_sk = 1L, vintage_sk = 1:2
  ), append = TRUE)
  DBI::dbWriteTable(con, "series_revisions", tibble::tibble(
    revision_id = "fixture:rev1", series_id = "fixture:series",
    period = as.Date("2026-01-31"), previous_value = 100, new_value = 175,
    previous_vintage_id = "fixture:av1", new_vintage_id = "fixture:av2",
    publication_date = as.Date("2026-05-10"), absolute_revision = 75
  ), append = TRUE)

  publish_test_release(con, bundles[["first"]], "accepted")
  publish_test_release(con, bundles[["second"]], "accepted")
  create_series_views(con)
  create_semantic_views(con)
  list(con = con, bundles = bundles, vintages = vintages)
}

as_of_value <- function(con, cutoff) {
  rows <- DBI::dbGetQuery(con, paste0(
    "SELECT value FROM main.series_as_of_date(DATE ", sql_string(cutoff), ")",
    " WHERE series_id = 'fixture:series'"
  ))
  if (!nrow(rows)) NA_real_ else rows$value[[1]]
}

testthat::test_that("a cutoff before first availability returns nothing at all", {
  fixture <- availability_fixture()
  # Not a null, not a zero, not the earliest value anyone ever published: no row.
  # A figure that did not exist yet cannot be in an information set.
  testthat::expect_true(is.na(as_of_value(fixture$con, "2026-01-31")))
  testthat::expect_true(is.na(as_of_value(fixture$con, "2026-02-09")))
})

testthat::test_that("a cutoff between releases returns the vintage in force at the time", {
  fixture <- availability_fixture()
  testthat::expect_equal(as_of_value(fixture$con, "2026-02-10"), 100)
  testthat::expect_equal(as_of_value(fixture$con, "2026-03-15"), 100)
  # The day before the revision was retrieved. This is the assertion that fails
  # if the ranking reads the current pointer instead of the accepted history --
  # the defect schema 36 repaired, which would have returned 175 here.
  testthat::expect_equal(as_of_value(fixture$con, "2026-05-11"), 100)
})

testthat::test_that("a cutoff after the revision returns the revised value", {
  fixture <- availability_fixture()
  testthat::expect_equal(as_of_value(fixture$con, "2026-05-13"), 175)
  testthat::expect_equal(as_of_value(fixture$con, "2026-12-31"), 175)
  # And the revision itself is recoverable, which is what makes the change
  # auditable rather than merely applied.
  revisions <- series_revision_history(fixture$con, "fixture:series")
  testthat::expect_equal(nrow(revisions), 1L)
  testthat::expect_equal(revisions$previous_value[[1]], 100)
  testthat::expect_equal(revisions$new_value[[1]], 175)
})

testthat::test_that("no cutoff ever returns a value that was not available by then", {
  fixture <- availability_fixture()
  # The general property, asserted over a sweep rather than at chosen points: at
  # every cutoff, everything returned was already available. This is the whole
  # contract of a point-in-time interface stated once.
  for (cutoff in c("2026-01-01", "2026-02-10", "2026-03-01", "2026-05-11",
                   "2026-05-12", "2026-06-01", "2027-01-01")) {
    leaked <- DBI::dbGetQuery(fixture$con, paste0(
      "SELECT count(*) AS n FROM main.series_as_of_date(DATE ", sql_string(cutoff), ")",
      " WHERE available_at > TIMESTAMP ", sql_string(paste(cutoff, "00:00:00"))
    ))$n[[1]]
    testthat::expect_equal(leaked, 0L, info = cutoff)
  }
})

testthat::test_that("availability outranks the publication date and is never the reference period", {
  fixture <- availability_fixture()
  rows <- DBI::dbGetQuery(fixture$con, paste(
    "SELECT vintage_id, period, publication_date, available_at",
    "FROM main.v_series_observations_history WHERE series_id = 'fixture:series'",
    "ORDER BY vintage_id"
  ))
  testthat::expect_equal(nrow(rows), 2L)
  # The second vintage was published on 2026-05-10 and retrieved on 2026-05-12.
  # The operator's record wins, which is the documented ordering and the reason
  # the cutoff on 2026-05-11 above still returns the old value.
  testthat::expect_equal(as.Date(rows$available_at[[2]]), as.Date("2026-05-12"))
  # And never the reference period, under any branch of the coalesce.
  testthat::expect_true(all(as.Date(rows$available_at) != rows$period))
})

testthat::test_that("the quality of the availability evidence is declared, and an undeclared one blocks", {
  fixture <- availability_fixture()
  con <- fixture$con
  quality <- DBI::dbGetQuery(con, paste(
    "SELECT availability_quality, count(*) AS n FROM raw.source_provenance GROUP BY 1 ORDER BY 1"
  ))
  testthat::expect_setequal(quality$availability_quality, c("official_release", "retrieval_time"))
  testthat::expect_true(all(quality$availability_quality %in% AVAILABILITY_QUALITY_VALUES))

  DBI::dbExecute(con, "DELETE FROM audit.quality_flags")
  validate_availability_quality(con, "fixture-release")
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM audit.quality_flags WHERE severity = 'error'"
  ))$n[[1]], 0L)

  # A timestamp with no declared provenance is not a weaker answer, it is an
  # unattributed one, and it blocks. Availability decides what a point-in-time
  # query may return; how it was established is part of the answer.
  DBI::dbExecute(con, "UPDATE raw.source_provenance SET availability_quality = NULL")
  DBI::dbExecute(con, "DELETE FROM audit.quality_flags")
  validate_availability_quality(con, "fixture-release")
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM audit.quality_flags",
    "WHERE severity = 'error' AND check_name = 'availability_quality_undeclared'"
  ))$n[[1]], 1L)
})
