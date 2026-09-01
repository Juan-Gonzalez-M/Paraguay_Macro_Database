# The audit's R6-01 and R6-02, tested the way it asks for them to be tested.
#
# The previous round's release test passed. It proved nothing, because it reused
# the same predicate the code used -- "does the stored SQL contain the word
# releases" -- so a view that mentioned the boundary while ignoring it satisfied
# both. `v_series_observations` did exactly that: it read the whole fact table and
# LEFT JOINed accepted releases only to fill in a label.
#
# The only test that can settle it is adversarial: build a database that actually
# holds data nobody is allowed to see, then ask every published interface for it.

# A minimal, isolated database with one published vintage and one that must not
# be. Everything is fabricated: no source workbook is read and the production
# database is never opened.
isolation_fixture <- function(env = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".duckdb", .local_envir = env)
  con <- DBI::dbConnect(duckdb::duckdb(), path)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE), envir = env)
  initialize_database(con, project_test_root)

  published <- "release:published"
  withheld <- "release:withheld"
  DBI::dbExecute(con, "DELETE FROM audit.releases")
  DBI::dbExecute(con, "DELETE FROM audit.release_sources")
  DBI::dbExecute(con, "DELETE FROM audit.data_releases")
  DBI::dbExecute(con, "DELETE FROM audit.active_data_release")
  DBI::dbWriteTable(con, "releases", tibble::tibble(
    release_id = c(published, withheld), status = c("accepted", "blocked"),
    staged_at = Sys.time(), decided_at = Sys.time(), source_count = 1L,
    error_count = c(0L, 1L), warning_count = 0L, decided_by = "fixture"
  ), append = TRUE)
  DBI::dbWriteTable(con, "release_sources", tibble::tibble(
    release_id = c(published, withheld), source_id = "fixture",
    vintage_id = c("fixture:published", "fixture:withheld")
  ), append = TRUE)
  # The decision and the pointer: the published bundle is the active product, the
  # withheld one was decided and never promoted.
  DBI::dbWriteTable(con, "data_releases", tibble::tibble(
    data_release_id = c("build:published", "build:withheld"),
    source_bundle_id = c(published, withheld),
    build_id = c("build:published", "build:withheld"), attempt_id = NA_character_,
    schema_version = 30L, status = c("accepted", "blocked"),
    error_count = c(0L, 1L), warning_count = 0L,
    decided_at = Sys.time(), decided_by = "fixture"
  ), append = TRUE)
  DBI::dbWriteTable(con, "active_data_release", tibble::tibble(
    singleton = TRUE, data_release_id = "build:published",
    source_bundle_id = published, promoted_at = Sys.time(), promoted_by = "fixture"
  ), append = TRUE)

  DBI::dbWriteTable(con, "source_files", tibble::tibble(
    vintage_id = c("fixture:published", "fixture:withheld"),
    first_ingested_release_id = c(published, withheld), source_id = "fixture",
    source_label = "Fixture", publisher = "Fixture", source_format = "xlsx",
    source_file = c("published.xlsx", "withheld.xlsx"), source_path = NA_character_,
    archive_path = NA_character_, sha256 = c("aa", "bb"), size_bytes = 1,
    publication_date = as.Date("2024-01-31"), publication_date_source = "filename",
    first_ingested_at = Sys.time(), ingestion_status = "completed",
    vintage_sk = c(1L, 2L)
  ), append = TRUE)
  DBI::dbWriteTable(con, "dim_series", tibble::tibble(
    series_id = "fixture:series", source_id = "fixture", label = "Fixture series",
    unit = "index", scale = "units", frequency = "monthly",
    first_vintage_id = "fixture:published", series_grain = "scalar_series",
    unit_code = "INDEX", scale_multiplier = 1, series_sk = 1L
  ), append = TRUE)
  # The withheld vintage is *newer*, so any view ranking by publication date will
  # reach for it first. That is the point: a filter applied after the ranking
  # would return nothing, and one applied to the wrong relation would return the
  # value nobody may see.
  DBI::dbWriteTable(con, "fact_series_events", tibble::tibble(
    series_id = "fixture:series",
    period = as.Date(c("2024-01-31", "2030-01-31", "2024-01-31", "2030-01-31")),
    value = c(1, 2, 999, 998),
    vintage_id = rep(c("fixture:published", "fixture:withheld"), each = 2),
    publication_date = rep(as.Date(c("2024-02-15", "2026-02-15")), each = 2),
    is_deleted = FALSE, source_file = rep(c("published.xlsx", "withheld.xlsx"), each = 2),
    series_sk = 1L, vintage_sk = rep(c(1L, 2L), each = 2)
  ), append = TRUE)
  DBI::dbWriteTable(con, "observation_missingness", tibble::tibble(
    series_id = "fixture:series", period = as.Date(c("2024-03-31", "2024-04-30")),
    source_id = "fixture", source_sheet = "Datos", source_row = 2L, source_column = 2L,
    reason = "blank_in_source", source_token = NA_character_,
    vintage_id = c("fixture:published", "fixture:withheld"), build_id = "build:published"
  ), append = TRUE)

  create_series_views(con)
  create_semantic_views(con)
  create_domain_views(con)
  create_missingness_views(con)
  create_table_status_views(con)
  create_mart_views(con)
  list(con = con, published = published, withheld = withheld)
}

testthat::test_that("no published interface returns a vintage that was never promoted", {
  fixture <- isolation_fixture()
  con <- fixture$con
  contract <- read_public_view_contract(project_test_root)
  testthat::skip_if(is.null(contract), "no public view contract")

  stored <- DBI::dbGetQuery(con, paste(
    "SELECT schema_name || '.' || view_name AS object_id FROM duckdb_views() WHERE NOT internal"
  ))$object_id
  current <- intersect(contract$object_id[contract$public_scope == "current"], stored)
  testthat::expect_gt(length(current), 20L)

  # Every current view that carries a vintage must exclude the withheld one, and
  # every one that carries a value must not contain the withheld values.
  leaked_vintage <- character()
  leaked_value <- character()
  for (object_id in current) {
    columns <- DBI::dbGetQuery(con, paste0(
      "SELECT name FROM pragma_table_info(", sql_string(object_id), ")"
    ))$name
    if ("vintage_id" %in% columns) {
      n <- DBI::dbGetQuery(con, paste0(
        "SELECT count(*) AS n FROM ", object_id, " WHERE vintage_id = 'fixture:withheld'"
      ))$n[[1]]
      if (n > 0) leaked_vintage <- c(leaked_vintage, object_id)
    }
    if ("value" %in% columns) {
      n <- DBI::dbGetQuery(con, paste0(
        "SELECT count(*) AS n FROM ", object_id, " WHERE value IN (999, 998)"
      ))$n[[1]]
      if (n > 0) leaked_value <- c(leaked_value, object_id)
    }
  }
  testthat::expect_equal(leaked_vintage, character())
  testthat::expect_equal(leaked_value, character())
})

testthat::test_that("the interfaces the audit named by name are the ones checked", {
  # R6-01 lists these individually. Each is asserted here rather than left to the
  # sweep above, so a future change that drops one from the contract cannot make
  # this test quietly weaker.
  fixture <- isolation_fixture()
  con <- fixture$con
  named <- function(sql) DBI::dbGetQuery(con, sql)$n[[1]]

  testthat::expect_equal(named(
    "SELECT count(*) AS n FROM main.v_series_observations WHERE vintage_id = 'fixture:withheld'"), 0L)
  testthat::expect_equal(named(
    "SELECT count(*) AS n FROM marts.v_series_projections WHERE vintage_id = 'fixture:withheld'"), 0L)
  testthat::expect_equal(named(
    "SELECT count(*) AS n FROM marts.v_series_missingness WHERE vintage_id = 'fixture:withheld'"), 0L)
  testthat::expect_equal(named(
    "SELECT count(*) AS n FROM main.v_series_latest WHERE vintage_id = 'fixture:withheld'"), 0L)
  # And the unfiltered twins do see it -- that is what they are for, and a test
  # that passed because the fixture was empty would prove nothing.
  testthat::expect_gt(named(
    "SELECT count(*) AS n FROM main.v_series_observations_all WHERE vintage_id = 'fixture:withheld'"), 0L)
  testthat::expect_gt(named(
    "SELECT count(*) AS n FROM main.v_series_latest_all WHERE vintage_id = 'fixture:withheld'"), 0L)
})

testthat::test_that("the current view is realized observations and the statement view is not", {
  # R6-03. The fixture's 2030 period is dated after its 2024 publication date.
  fixture <- isolation_fixture()
  con <- fixture$con
  latest <- DBI::dbGetQuery(con, "SELECT period, value, observation_status FROM main.v_series_latest")
  testthat::expect_equal(nrow(latest), 1L)
  testthat::expect_equal(as.character(latest$period), "2024-01-31")
  testthat::expect_equal(latest$observation_status, "observed")

  statement <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM main.v_publisher_statement_latest",
    "WHERE observation_status = 'after_publication'"
  ))$n[[1]]
  testthat::expect_equal(statement, 1L)
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM marts.v_series_projections"
  ))$n[[1]], 1L)
})

testthat::test_that("a decided data release is immutable and a failed build cannot un-publish", {
  # R6-02. This is the failure that actually happened: one attempt among fourteen
  # sharing a release_id ended blocked, and because publication was a mutable
  # status on that shared row, it withdrew the accepted database.
  fixture <- isolation_fixture()
  con <- fixture$con

  before <- DBI::dbGetQuery(con, "SELECT data_release_id FROM audit.active_data_release")$data_release_id
  testthat::expect_equal(before, "build:published")

  # A rebuild of the same bundle that fails validation records its own blocked
  # decision. It must not touch the pointer, and it must not restate the earlier
  # verdict on the product that is published.
  record_data_release_decision(
    con, fixture$published, "build:rebuild_failed", "attempt:x", 30L, "blocked", 3L, 0L
  )
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT data_release_id FROM audit.active_data_release")$data_release_id,
    "build:published"
  )
  testthat::expect_error(
    promote_data_release(con, "build:rebuild_failed", fixture$published), "must not be promoted"
  )
  testthat::expect_error(
    record_data_release_decision(
      con, fixture$published, "build:published", NA_character_, 30L, "blocked", 1L, 0L
    ),
    "cannot be restated"
  )
  # Re-deciding a product the same way is not a contradiction and is a no-op.
  testthat::expect_false(record_data_release_decision(
    con, fixture$published, "build:published", NA_character_, 30L, "accepted", 0L, 0L
  ))
  # The published data is still published.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM main.v_series_latest"
  ))$n[[1]], 1L)

  # And a successful build promotes atomically, leaving exactly one active row.
  record_data_release_decision(
    con, fixture$published, "build:rebuild_ok", "attempt:y", 30L, "accepted", 0L, 0L
  )
  promote_data_release(con, "build:rebuild_ok", fixture$published)
  active <- DBI::dbGetQuery(con, "SELECT * FROM audit.active_data_release")
  testthat::expect_equal(nrow(active), 1L)
  testthat::expect_equal(active$data_release_id, "build:rebuild_ok")
})

testthat::test_that("a release-wide phase that dies rolls back the derived tables it had begun", {
  # R6-02's other half, and the reason the pointer alone is not enough: a failed
  # build had already overwritten the derived tables before anyone decided
  # anything, so the published database was a mixture of two builds.
  fixture <- isolation_fixture()
  con <- fixture$con
  before <- DBI::dbGetQuery(con, "SELECT count(*) AS n FROM staging.observation_missingness")$n[[1]]
  testthat::expect_gt(before, 0L)

  testthat::expect_error(with_project_transaction(con, {
    DBI::dbExecute(con, "DELETE FROM staging.observation_missingness")
    # A nested unit, which must join the outer transaction rather than commit
    # independently -- DuckDB has no nested transactions.
    with_project_transaction(con, DBI::dbExecute(con, "DELETE FROM staging.expected_observation_grid"))
    stop("phase died")
  }), "phase died")

  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT count(*) AS n FROM staging.observation_missingness")$n[[1]], before
  )
})
