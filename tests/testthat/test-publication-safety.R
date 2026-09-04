# The re-audit's RA2-08 and RA2-10, and A11 #16.
#
# The candidate design that closed F-01 left three things unguarded, and all
# three are consequences of the same fact: because production is only ever
# *copied* and never opened, DuckDB's own single-writer lock protects nothing
# between runs.
#
#   - two accepted runs could both rename over production, last writer wins;
#   - nothing re-checked that the file being replaced was the file that was copied;
#   - a hard kill between the two renames left no published database and nothing
#     on disk saying so.
#
# Plus RA2-10: the artifact identifier hashed a size read from an open
# connection, so it was 37% wrong and not derivable from the shipped file.

safety_root <- function(env = parent.frame()) {
  root <- withr::local_tempdir(.local_envir = env)
  ensure_dirs(root)
  root
}

# A minimal published database. Content is irrelevant here -- what is under test
# is the file-level protocol around it.
safety_database <- function(path, value = 1) {
  con <- DBI::dbConnect(duckdb::duckdb(), path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  initialize_database(con, project_test_root)
  DBI::dbExecute(con, "DELETE FROM audit.active_data_release")
  DBI::dbExecute(con, "DELETE FROM audit.data_releases")
  DBI::dbWriteTable(con, "release_sources", tibble::tibble(
    release_id = "release:x", source_id = "fixture", vintage_id = "fixture:v1"
  ), append = TRUE)
  publish_test_release(con, "release:x", "accepted")
  invisible(path)
}

accepting_pipeline <- function(build_id = "build:next", before_return = NULL) {
  force(build_id); force(before_return)
  function(root, registry, manifest, resolution_issues = tibble::tibble(),
           db_path = NULL, artifact_path = db_path, ...) {
    con <- connect_project_database(db_path)
    record_data_release_decision(
      con, "release:x", build_id, "attempt:test", 37L, "accepted", 0L, 0L, "fixture"
    )
    promote_data_release(con, build_id, "release:x", "fixture")
    DBI::dbDisconnect(con, shutdown = TRUE)
    if (is.function(before_return)) before_return()
    list(
      release_id = "release:x", database = db_path, build_id = build_id,
      data_release_id = build_id, decision = "accepted", status = "completed",
      schema_version = 37L, warning_count = 0L, error_count = 0L
    )
  }
}

# --- The lock ----------------------------------------------------------------

testthat::test_that("a live update refuses a second one and names the holder", {
  root <- safety_root()
  lock <- acquire_update_lock(root)
  withr::defer(release_update_lock(lock))
  testthat::expect_true(dir.exists(lock))

  # A second acquisition from this same (living) process must be refused. Before
  # schema 37 there was nothing to refuse it with: two runs copied the same
  # database and whichever renamed last silently discarded the other's release,
  # its build identity and every diagnostic it produced.
  testthat::expect_error(acquire_update_lock(root), "Another update holds the lock")
  testthat::expect_error(acquire_update_lock(root), as.character(Sys.getpid()))
})

testthat::test_that("a lock held by a dead process is taken over, not honoured forever", {
  # A crashed update must not block every future one -- that is a worse failure
  # than the one the lock prevents.
  root <- safety_root()
  path <- file.path(root, "database", UPDATE_LOCK_NAME)
  dir.create(path)
  readr::write_csv(tibble::tibble(
    pid = "999999", host = as.character(Sys.info()[["nodename"]]),
    started_at = "2020-01-01T00:00:00"
  ), file.path(path, "holder.csv"))
  testthat::expect_false(process_is_alive("999999"))

  taken <- testthat::expect_message(acquire_update_lock(root), "no longer running")
  holder <- readr::read_csv(file.path(path, "holder.csv"), show_col_types = FALSE)
  testthat::expect_equal(as.character(holder$pid), as.character(Sys.getpid()))
  release_update_lock(path)
  testthat::expect_false(dir.exists(path))
})

testthat::test_that("the lock is released even when the build fails", {
  root <- safety_root()
  safety_database(file.path(root, "database", "paraguay_macro_pilot.duckdb"))
  testthat::expect_error(
    run_isolated_update(
      root, tibble::tibble(), tibble::tibble(),
      pipeline = function(...) stop("the parser died", call. = FALSE)
    ),
    "the parser died"
  )
  # A lock left behind by a failed run would block the retry that fixes it.
  testthat::expect_false(dir.exists(file.path(root, "database", UPDATE_LOCK_NAME)))
})

# --- The base the candidate revised ------------------------------------------

testthat::test_that("a candidate whose base was replaced under it is not published", {
  # The half a lock cannot cover: a lock taken over from a dead holder, or an
  # operator restoring a backup by hand mid-build, produces exactly this state.
  root <- safety_root()
  production <- file.path(root, "database", "paraguay_macro_pilot.duckdb")
  safety_database(production)

  # Somebody else publishes while this build is running.
  interfere <- function() {
    other <- file.path(root, "database", "someone_elses.duckdb")
    safety_database(other)
    file.copy(other, production, overwrite = TRUE)
  }
  testthat::expect_error(
    run_isolated_update(
      root, tibble::tibble(), tibble::tibble(),
      pipeline = accepting_pipeline(before_return = interfere)
    ),
    "changed while this build was running"
  )
  # Their release survives, and ours is kept rather than thrown away.
  testthat::expect_true(file.exists(production))
  testthat::expect_equal(
    length(list.files(file.path(root, "database", "candidates"), pattern = "[.]duckdb$")), 1L
  )
})

# --- The interrupted swap ----------------------------------------------------

testthat::test_that("an interrupted swap stops the next run and says what to move", {
  root <- safety_root()
  production <- file.path(root, "database", "paraguay_macro_pilot.duckdb")
  safety_database(production)
  marker <- file.path(root, "database", ".swap_in_progress")
  writeLines(c("moved_aside=/x", "candidate=/y", "publication=/z"), marker)

  ran <- FALSE
  testthat::expect_error(
    run_isolated_update(
      root, tibble::tibble(), tibble::tibble(),
      pipeline = function(...) { ran <<- TRUE; list(status = "completed") }
    ),
    "interrupted while swapping"
  )
  # It refuses before doing anything, because the published pathname may be the
  # thing that is missing.
  testthat::expect_false(ran)
  testthat::expect_false(dir.exists(file.path(root, "database", UPDATE_LOCK_NAME)))
})

testthat::test_that("a completed swap leaves no marker behind", {
  root <- safety_root()
  production <- file.path(root, "database", "paraguay_macro_pilot.duckdb")
  safety_database(production)
  result <- run_isolated_update(
    root, tibble::tibble(), tibble::tibble(), pipeline = accepting_pipeline()
  )
  testthat::expect_true(result$published)
  testthat::expect_false(file.exists(file.path(root, "database", ".swap_in_progress")))
})

# --- The artifact -------------------------------------------------------------

testthat::test_that("the published artifact is identified by its own bytes", {
  # RA2-10. The recorded size was read while the connection was open and more
  # rows were still to be written: 553,136,128 against a shipped 344,993,792.
  # The hash is taken after close, checkpoint and rename -- the one moment the
  # bytes are final.
  root <- safety_root()
  production <- file.path(root, "database", "paraguay_macro_pilot.duckdb")
  safety_database(production)
  result <- run_isolated_update(
    root, tibble::tibble(), tibble::tibble(), pipeline = accepting_pipeline()
  )
  testthat::expect_true(result$published)

  sidecar <- paste0(production, ARTIFACT_SIDECAR_SUFFIX)
  testthat::expect_true(file.exists(sidecar))
  # The claim is true of the file that is actually there.
  testthat::expect_equal(result$sha256, file_sha256(production))
  testthat::expect_equal(published_artifact_sha256(production), file_sha256(production))
  # …and it is checkable without R: `shasum -a 256 -c` reads this format.
  testthat::expect_match(
    readLines(sidecar, warn = FALSE)[[1]],
    paste0("^[0-9a-f]{64}  ", basename(production), "$")
  )
})

testthat::test_that("the superseded database is recorded inside the one that replaced it", {
  # A file cannot contain its own hash: writing the row changes the bytes the row
  # describes. So a database records the hashes of artifacts *other* than itself,
  # and the chain is complete one build behind, with the newest link in the
  # sidecar.
  root <- safety_root()
  production <- file.path(root, "database", "paraguay_macro_pilot.duckdb")
  safety_database(production)
  first_sha <- file_sha256(production)

  result <- run_isolated_update(
    root, tibble::tibble(), tibble::tibble(), pipeline = accepting_pipeline()
  )
  testthat::expect_true(result$published)
  testthat::expect_equal(result$sha256 == first_sha, FALSE)

  con <- connect_project_database(production, read_only = TRUE)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  artifacts <- DBI::dbGetQuery(con, paste(
    "SELECT artifact_role, sha256 FROM audit.distribution_artifacts",
    "WHERE sha256 IS NOT NULL"
  ))
  testthat::expect_true(first_sha %in% artifacts$sha256)
  testthat::expect_equal(
    artifacts$artifact_role[artifacts$sha256 == first_sha], "superseded_database"
  )
  # And the row this build wrote about *itself* carries no hash, rather than a
  # number that looks authoritative and is wrong.
  own <- DBI::dbGetQuery(con, paste(
    "SELECT sha256 FROM audit.distribution_artifacts WHERE build_id =",
    sql_string(result$build_id)
  ))
  testthat::expect_true(all(is.na(own$sha256)))
})

# --- The log ------------------------------------------------------------------

testthat::test_that("a run that publishes nothing still leaves a record outside the database", {
  # A11 #16. A build that dies before its candidate can be opened has no database
  # to have recorded anything in, and the message went to stderr and vanished
  # with the session.
  root <- safety_root()
  safety_database(file.path(root, "database", "paraguay_macro_pilot.duckdb"))
  testthat::expect_error(
    run_isolated_update(
      root, tibble::tibble(), tibble::tibble(),
      pipeline = function(...) stop("the parser died", call. = FALSE)
    ),
    "the parser died"
  )
  logs <- list.files(file.path(root, "logs"), pattern = "[.]jsonl$", full.names = TRUE)
  testthat::expect_length(logs, 1L)
  events <- vapply(
    readLines(logs, warn = FALSE), function(line) jsonlite::fromJSON(line)$event,
    character(1), USE.NAMES = FALSE
  )
  testthat::expect_true("update_started" %in% events)
  testthat::expect_true("update_ended_without_publishing" %in% events)
})

testthat::test_that("a published run records its hash in the log", {
  root <- safety_root()
  safety_database(file.path(root, "database", "paraguay_macro_pilot.duckdb"))
  result <- run_isolated_update(
    root, tibble::tibble(), tibble::tibble(), pipeline = accepting_pipeline()
  )
  logs <- list.files(file.path(root, "logs"), pattern = "[.]jsonl$", full.names = TRUE)
  records <- lapply(readLines(logs, warn = FALSE), jsonlite::fromJSON)
  published <- Filter(function(r) identical(r$event, "published"), records)
  testthat::expect_length(published, 1L)
  testthat::expect_equal(published[[1]]$sha256, result$sha256)
  testthat::expect_equal(published[[1]]$build, result$build_id)
})
