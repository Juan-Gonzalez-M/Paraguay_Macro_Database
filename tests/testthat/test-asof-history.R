# The re-audit's RA2-01, tested the way A6 asks for it:
#
#   "Test two distinct accepted bundles where the second replaces a vintage and
#    an intermediate cutoff returns the first."
#
# The existing as-of test (test-governance-and-migrations.R) links both of its
# vintages to ONE release_id. That proves ranking *within* a bundle and cannot
# reach the production shape, which is two bundles with one of them active --
# because `release_id` is a hash of the manifest, so replacing a single workbook
# necessarily mints a new bundle.
#
# Under the old carrier this whole file fails: `series_as_of_date()` read
# `v_series_observations`, which filters to the active pointer, so the superseded
# vintage was not in the population being ranked and no cutoff could return it.

asof_history_fixture <- function(env = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".duckdb", .local_envir = env)
  con <- DBI::dbConnect(duckdb::duckdb(), path)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE), envir = env)
  initialize_database(con, project_test_root)

  DBI::dbExecute(con, "DELETE FROM audit.releases")
  DBI::dbExecute(con, "DELETE FROM audit.release_sources")
  DBI::dbExecute(con, "DELETE FROM audit.data_releases")
  DBI::dbExecute(con, "DELETE FROM audit.active_data_release")

  # Three bundles. Each replaces the single source's workbook, so each contains
  # exactly one vintage -- which is what the monthly replacement workflow does.
  bundles <- c(first = "release:bundle-a", second = "release:bundle-b", third = "release:bundle-c")
  vintages <- c(first = "fixture:v1", second = "fixture:v2", third = "fixture:v3")
  DBI::dbWriteTable(con, "release_sources", tibble::tibble(
    release_id = unname(bundles), source_id = "fixture", vintage_id = unname(vintages)
  ), append = TRUE)
  DBI::dbWriteTable(con, "source_files", tibble::tibble(
    vintage_id = unname(vintages), first_ingested_release_id = unname(bundles),
    source_id = "fixture", source_label = "Fixture", publisher = "Fixture",
    source_format = "xlsx", source_file = paste0(names(vintages), ".xlsx"),
    source_path = NA_character_, archive_path = NA_character_,
    sha256 = c("aa", "bb", "cc"), size_bytes = 1,
    publication_date = as.Date(c("2026-01-15", "2026-06-15", "2026-09-15")),
    publication_date_source = "filename", first_ingested_at = Sys.time(),
    ingestion_status = "completed", vintage_sk = 1:3
  ), append = TRUE)
  DBI::dbWriteTable(con, "dim_series", tibble::tibble(
    series_id = "fixture:series", source_id = "fixture", label = "Fixture series",
    unit = "index", scale = "units", frequency = "monthly", first_vintage_id = "fixture:v1",
    series_grain = "scalar_series", unit_code = "INDEX", scale_multiplier = 1, series_sk = 1L
  ), append = TRUE)
  # One series, one period, revised twice. The period is held constant so that
  # what changes between cutoffs is the *vintage*, which is the whole subject.
  DBI::dbWriteTable(con, "fact_series_events", tibble::tibble(
    series_id = "fixture:series", period = as.Date("2025-12-31"),
    value = c(100, 200, 300), vintage_id = unname(vintages),
    publication_date = as.Date(c("2026-01-15", "2026-06-15", "2026-09-15")),
    is_deleted = FALSE, source_file = paste0(names(vintages), ".xlsx"),
    series_sk = 1L, vintage_sk = 1:3
  ), append = TRUE)

  # Bundle A is published, then B replaces it. Both decisions are accepted and
  # both are immutable; only the pointer moves. Bundle C is decided blocked and
  # never published -- it is the look-ahead trap.
  publish_test_release(con, bundles[["first"]], "accepted")
  publish_test_release(con, bundles[["second"]], "accepted")
  publish_test_release(con, bundles[["third"]], "blocked")

  create_series_views(con)
  create_semantic_views(con)
  list(con = con, bundles = bundles, vintages = vintages)
}

as_of <- function(con, date, macro = "series_as_of_date") {
  DBI::dbGetQuery(con, paste0(
    "SELECT value, vintage_id FROM ", macro, "(DATE '", date, "')"
  ))
}

testthat::test_that("the current pointer names the newest bundle only", {
  fixture <- asof_history_fixture()
  con <- fixture$con
  pointer <- DBI::dbGetQuery(con, "SELECT source_bundle_id FROM audit.active_data_release")
  testthat::expect_equal(pointer$source_bundle_id, "release:bundle-b")

  # The current interface is unchanged by this round and must stay unchanged:
  # "what is published now" is bundle B's vintage.
  latest <- DBI::dbGetQuery(con, "SELECT value, vintage_id FROM main.v_series_latest")
  testthat::expect_equal(nrow(latest), 1L)
  testthat::expect_equal(latest$value, 200)
  testthat::expect_equal(latest$vintage_id, "fixture:v2")
})

testthat::test_that("an intermediate cutoff returns the superseded vintage", {
  # A6's requirement, verbatim. This is the assertion the old carrier could not
  # satisfy: v1 belongs to bundle A, the pointer names bundle B, and the ranking
  # population was the pointer's.
  fixture <- asof_history_fixture()
  con <- fixture$con

  before_revision <- as_of(con, "2026-03-01")
  testthat::expect_equal(nrow(before_revision), 1L)
  testthat::expect_equal(before_revision$value, 100)
  testthat::expect_equal(before_revision$vintage_id, "fixture:v1")

  # After the replacement, the same query returns the replacement.
  after_revision <- as_of(con, "2026-08-01")
  testthat::expect_equal(after_revision$value, 200)
  testthat::expect_equal(after_revision$vintage_id, "fixture:v2")

  # And before anything was available, nothing is knowable. A carrier that
  # leaked would show a value here.
  testthat::expect_equal(nrow(as_of(con, "2025-06-01")), 0L)

  # The carrier is what makes the difference, and this proves it rather than
  # asserting it: the same ranking over the *current* relation -- which is what
  # the macro read before this round -- returns nothing at the intermediate
  # cutoff, because v1 is not in the active bundle. If someone repoints the
  # macro back at v_series_observations, the assertions above break and this one
  # explains why.
  through_current_carrier <- DBI::dbGetQuery(con, paste(
    "WITH ranked AS (",
    "  SELECT *, row_number() OVER (PARTITION BY series_id, period",
    "    ORDER BY available_at DESC NULLS LAST, vintage_id DESC) AS rn",
    "  FROM main.v_series_observations",
    "  WHERE available_at IS NOT NULL AND available_at <= DATE '2026-03-01'",
    ") SELECT value, vintage_id FROM ranked WHERE rn = 1"
  ))
  testthat::expect_equal(nrow(through_current_carrier), 0L)
})

testthat::test_that("a vintage from a blocked build is never knowable at any cutoff", {
  # The negative half, and the reason the history carrier is a filter rather
  # than no filter at all. Bundle C was decided and never promoted: nobody could
  # have seen it, so admitting it would be look-ahead in the one interface whose
  # entire purpose is to prevent look-ahead.
  fixture <- asof_history_fixture()
  con <- fixture$con
  for (cutoff in c("2026-03-01", "2026-08-01", "2026-12-31", "2099-01-01")) {
    rows <- as_of(con, cutoff)
    testthat::expect_false(
      "fixture:v3" %in% rows$vintage_id,
      info = paste("blocked vintage visible at cutoff", cutoff)
    )
  }
  # Even at a cutoff past its publication date, the newest *knowable* value is
  # bundle B's -- not the blocked 300.
  testthat::expect_equal(as_of(con, "2099-01-01")$value, 200)
})

testthat::test_that("the history carrier holds every accepted vintage and no other", {
  fixture <- asof_history_fixture()
  con <- fixture$con
  history <- DBI::dbGetQuery(con, paste(
    "SELECT DISTINCT vintage_id FROM main.v_series_observations_history ORDER BY 1"
  ))$vintage_id
  testthat::expect_equal(history, c("fixture:v1", "fixture:v2"))

  # The current carrier is the narrower one, and stays narrow.
  current <- DBI::dbGetQuery(con, paste(
    "SELECT DISTINCT vintage_id FROM main.v_series_observations ORDER BY 1"
  ))$vintage_id
  testthat::expect_equal(current, "fixture:v2")

  # And the unfiltered twin still sees everything, so the test cannot pass by
  # the fixture simply lacking the blocked row.
  all_rows <- DBI::dbGetQuery(con, paste(
    "SELECT DISTINCT vintage_id FROM main.v_series_observations_all ORDER BY 1"
  ))$vintage_id
  testthat::expect_equal(all_rows, c("fixture:v1", "fixture:v2", "fixture:v3"))
})

testthat::test_that("the release context names the product that admitted the vintage", {
  # Section A7. This was max(release_id) over hashed identifiers joined to the
  # mutable releases.status -- a lexical maximum, which is not a release context.
  fixture <- asof_history_fixture()
  con <- fixture$con
  rows <- DBI::dbGetQuery(con, paste(
    "SELECT DISTINCT vintage_id, accepted_release_id, first_published_at",
    "FROM main.v_series_observations_history ORDER BY vintage_id"
  ))
  testthat::expect_equal(nrow(rows), 2L)
  testthat::expect_false(any(is.na(rows$accepted_release_id)))
  testthat::expect_false(any(is.na(rows$first_published_at)))
  # Each vintage's context is a decided product, not a source bundle hash.
  decided <- DBI::dbGetQuery(
    con, "SELECT data_release_id FROM audit.data_releases WHERE status = 'accepted'"
  )$data_release_id
  testthat::expect_true(all(rows$accepted_release_id %in% decided))
  # The two vintages were admitted by different products, in the order they were
  # published -- which a lexical maximum over hashes could not guarantee.
  testthat::expect_equal(length(unique(rows$accepted_release_id)), 2L)
  testthat::expect_lt(
    rows$first_published_at[rows$vintage_id == "fixture:v1"],
    rows$first_published_at[rows$vintage_id == "fixture:v2"]
  )
})

testthat::test_that("the contract declares the as-of interface as history, not current", {
  # The classification is part of the defect: an interface answering "what could
  # have been known then" was declared `current`, so the lint required it to
  # descend from the active-pointer carrier -- which is exactly what made it
  # wrong, and exactly what the lint was certifying.
  contract <- read_public_view_contract(project_test_root)
  testthat::skip_if(is.null(contract), "no public view contract")
  scope_of <- function(id) contract$public_scope[contract$object_id == id]
  testthat::expect_equal(scope_of("main.series_as_of_date"), "history")
  testthat::expect_equal(scope_of("main.series_statement_as_of_date"), "history")
  testthat::expect_equal(scope_of("main.v_series_observations_history"), "history")
  testthat::expect_true(isTRUE_vector(
    contract$carries_release_boundary[contract$object_id == "main.v_series_observations_history"]
  ))
  # The current carrier keeps its scope: the two questions stay separate.
  testthat::expect_equal(scope_of("main.v_series_observations"), "current")
})
