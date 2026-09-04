# The seventh audit's F-01, tested the way section 11.1 asks for it.
#
# The previous round's isolation test asserts that a blocked build cannot move
# the pointer, and that the release-wide transaction rolls back. Both pass. The
# audit's point is that neither is the question:
#
#   "the difference between 'the pointer did not move' and 'the rows exposed by
#    the pointer did not mutate.'"
#
# Nothing was testing the second, because nothing could: the run and the
# published database were the same file, and per-source work commits long before
# the decision exists. So the test that settles it is the one the audit writes
# out, steps 1 to 6 -- publish a value, start a second build against the same
# bundle, have it replace that value, fail it after the source commit, and assert
# the published value is untouched while the failed build remains inspectable.
#
# The pipeline is injected rather than run for real. That is deliberate: the
# adversarial half of this test is "a build that mutates the same vintage and
# then dies", which no real 22-source run performs on request, and a stub can do
# it in milliseconds and deterministically. test-full-pipeline-smoke.R covers
# that the real pipeline runs; this covers that a failed one cannot reach the
# published bytes.

# A published database holding one series whose current value is 1.
published_fixture_database <- function(path, value = 1) {
  con <- DBI::dbConnect(duckdb::duckdb(), path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  initialize_database(con, project_test_root)
  release <- "release:bundle-x"
  DBI::dbExecute(con, "DELETE FROM audit.releases")
  DBI::dbExecute(con, "DELETE FROM audit.release_sources")
  DBI::dbExecute(con, "DELETE FROM audit.data_releases")
  DBI::dbExecute(con, "DELETE FROM audit.active_data_release")
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
    series_id = "fixture:series", source_id = "fixture", label = "Fixture series",
    unit = "index", scale = "units", frequency = "monthly",
    first_vintage_id = "fixture:v1", series_grain = "scalar_series",
    unit_code = "INDEX", scale_multiplier = 1, series_sk = 1L
  ), append = TRUE)
  DBI::dbWriteTable(con, "fact_series_events", tibble::tibble(
    series_id = "fixture:series", period = as.Date("2024-01-31"), value = value,
    vintage_id = "fixture:v1", publication_date = as.Date("2024-02-15"),
    is_deleted = FALSE, source_file = "fixture.xlsx", series_sk = 1L, vintage_sk = 1L
  ), append = TRUE)
  build_id <- publish_test_release(con, release, "accepted")
  create_series_views(con)
  list(release_id = release, build_id = build_id)
}

published_value <- function(path) {
  con <- DBI::dbConnect(duckdb::duckdb(), path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  DBI::dbGetQuery(con, "SELECT value FROM main.v_series_latest")$value
}

# Build B: it replaces the value of the very vintage build A published -- the
# same DELETE-and-rewrite the real per-source path performs at
# scripts/03_curate_expanded.R:508 -- and commits it, exactly as
# run_manifest_pipeline() commits each source before the product decision exists.
mutating_pipeline <- function(decision, new_value = 999) {
  force(decision); force(new_value)
  function(root, registry, manifest, resolution_issues = tibble::tibble(),
           db_path = NULL, artifact_path = db_path, ...) {
    # The project search path, or an unqualified write lands in main and the
    # decision the promotion reads for is never recorded -- which is how this
    # stub failed the first time it ran.
    con <- connect_project_database(db_path)
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
    DBI::dbExecute(con, paste0(
      "UPDATE canonical.fact_series_events SET value = ", new_value,
      " WHERE vintage_id = 'fixture:v1'"
    ))
    build_id <- "build:rebuild-of-bundle-x"
    record_data_release_decision(
      con, "release:bundle-x", build_id, "attempt:test", 33L, decision,
      if (identical(decision, "blocked")) 1L else 0L, 0L, "fixture"
    )
    if (identical(decision, "accepted")) {
      promote_data_release(con, build_id, "release:bundle-x", "fixture")
    }
    list(
      release_id = "release:bundle-x", database = db_path, build_id = build_id,
      data_release_id = build_id, decision = decision,
      status = if (identical(decision, "blocked")) "release_blocked" else "completed"
    )
  }
}

isolation_root <- function(env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  ensure_dirs(root)
  root
}

testthat::test_that("a blocked same-bundle rebuild cannot change one published byte", {
  root <- isolation_root()
  production <- file.path(root, "database", "paraguay_macro_pilot.duckdb")
  published_fixture_database(production, value = 1)

  # Steps 1 and 2 of the audit's regression: build A is published with value 1.
  testthat::expect_equal(published_value(production), 1)
  before <- digest::digest(file = production, algo = "sha256")

  # Steps 3 and 4: build B replaces that value with 999 and then fails.
  result <- run_isolated_update(
    root, tibble::tibble(), tibble::tibble(),
    pipeline = mutating_pipeline("blocked", 999)
  )

  # Step 5. Not "the pointer did not move" and not "the row count is the same":
  # the value, and then the bytes of the whole file.
  testthat::expect_false(result$published)
  testthat::expect_equal(published_value(production), 1)
  testthat::expect_identical(digest::digest(file = production, algo = "sha256"), before)

  # Step 6, and the reason this test cannot pass vacuously: build B really did
  # write 999, and it is still there to be inspected. A wrapper that silently
  # skipped the build would satisfy step 5 and fail here.
  #
  # Note *which* interface returns it. `v_series_latest` is the release-filtered
  # one, and inside the candidate it returns 999 -- because the mutated row
  # belongs to a vintage of the bundle the candidate's own pointer names, which
  # is precisely the defect the audit describes. The two files answer the same
  # query differently, and that is the whole of the repair: the boundary that
  # could not be drawn inside one database is the file.
  testthat::expect_true(file.exists(result$candidate))
  testthat::expect_equal(published_value(result$candidate), 999)
  testthat::expect_equal(published_value(production), 1)
})

testthat::test_that("an accepted rebuild is swapped in and the build it replaced is retained", {
  root <- isolation_root()
  production <- file.path(root, "database", "paraguay_macro_pilot.duckdb")
  published_fixture_database(production, value = 1)
  before <- digest::digest(file = production, algo = "sha256")

  result <- run_isolated_update(
    root, tibble::tibble(), tibble::tibble(),
    pipeline = mutating_pipeline("accepted", 999)
  )

  testthat::expect_true(result$published)
  testthat::expect_equal(published_value(production), 999)
  # The previous database is not discarded by the swap; it is the rollback path
  # the operations manual now documents.
  testthat::expect_true(file.exists(result$swapped_from))
  testthat::expect_identical(
    digest::digest(file = result$swapped_from, algo = "sha256"), before
  )
  testthat::expect_equal(published_value(result$swapped_from), 1)
  # And no candidate is left behind for the next run to trip over.
  testthat::expect_equal(
    length(list.files(file.path(root, "database", "candidates"), pattern = "^candidate_")), 0L
  )
})

testthat::test_that("an accepted candidate that publishes a different build is refused", {
  # The swap's own precondition. Renaming a file whose pointer names some other
  # build into place would publish exactly the mixture of two builds this
  # procedure exists to prevent, so it is checked rather than assumed.
  root <- isolation_root()
  production <- file.path(root, "database", "paraguay_macro_pilot.duckdb")
  published_fixture_database(production, value = 1)
  before <- digest::digest(file = production, algo = "sha256")

  lying_pipeline <- function(root, registry, manifest, resolution_issues = tibble::tibble(),
                             db_path = NULL, artifact_path = db_path, ...) {
    list(
      release_id = "release:bundle-x", database = db_path,
      build_id = "build:never-decided", data_release_id = "build:never-decided",
      decision = "accepted", status = "completed"
    )
  }
  testthat::expect_error(
    run_isolated_update(root, tibble::tibble(), tibble::tibble(), pipeline = lying_pipeline),
    "publishes .* but this run built"
  )
  testthat::expect_identical(digest::digest(file = production, algo = "sha256"), before)
})

testthat::test_that("a write-ahead log stops the run before anything is copied", {
  # A .wal beside the production file means the last writer did not check point,
  # so the bytes on disk are not the database. compact_database.R has refused to
  # copy in that state since schema 22; the update path now refuses too.
  root <- isolation_root()
  production <- file.path(root, "database", "paraguay_macro_pilot.duckdb")
  published_fixture_database(production, value = 1)
  writeLines("", paste0(production, ".wal"))
  ran <- FALSE
  testthat::expect_error(
    run_isolated_update(
      root, tibble::tibble(), tibble::tibble(),
      pipeline = function(...) { ran <<- TRUE; list(status = "completed") }
    ),
    "write-ahead log"
  )
  testthat::expect_false(ran)
  testthat::expect_equal(
    length(list.files(file.path(root, "database", "candidates"))), 0L
  )
})

testthat::test_that("a build that dies mid-pipeline leaves no candidate and no change", {
  root <- isolation_root()
  production <- file.path(root, "database", "paraguay_macro_pilot.duckdb")
  published_fixture_database(production, value = 1)
  before <- digest::digest(file = production, algo = "sha256")
  testthat::expect_error(
    run_isolated_update(
      root, tibble::tibble(), tibble::tibble(),
      pipeline = function(root, registry, manifest, resolution_issues = tibble::tibble(),
                          db_path = NULL, artifact_path = db_path, ...) {
        stop("the parser died", call. = FALSE)
      }
    ),
    "the parser died"
  )
  testthat::expect_identical(digest::digest(file = production, algo = "sha256"), before)
  testthat::expect_equal(
    length(list.files(file.path(root, "database", "candidates"))), 0L
  )
})

testthat::test_that("the update entry point publishes through the isolation wrapper", {
  # The same shape as the query-helper check in test-release-isolation.R,
  # and for the same reason: the guarantee is a property of how the entry point
  # calls the pipeline, and nothing in the database can observe that. A future
  # edit that points run_update.R back at the production path would restore the
  # defect while every other test in this file still passed.
  source_text <- paste(readLines(
    file.path(project_test_root, "run_update.R"), warn = FALSE
  ), collapse = "\n")
  testthat::expect_match(source_text, "run_isolated_update(", fixed = TRUE)
  testthat::expect_false(grepl("run_manifest_pipeline(", source_text, fixed = TRUE))
})
