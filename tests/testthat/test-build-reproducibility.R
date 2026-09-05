# The audit's ER-12: a clean checkout must be able to reproduce the published
# candidate with the declared environment.

testthat::test_that("package versions are compared as versions, not as text", {
  # The audit reported the environment as differing from renv.lock for the
  # transitive package Rcpp. It does not. The lockfile records CRAN's spelling
  # of a revision, `1.1.1-1.1`; packageVersion() parses that and prints it back
  # as `1.1.1.1.1`, because R has always treated `-` and `.` as the same
  # separator. Comparing the strings reports a difference between a version and
  # itself, for every package whose maintainer ever issued a revision.
  testthat::expect_true(same_package_version("1.1.1.1.1", "1.1.1-1.1"))
  testthat::expect_true(same_package_version("1.0.13-1", "1.0.13.1"))
  testthat::expect_true(same_package_version("2.0.0", "2.0.0"))
  # And it must still detect real drift, or the repair would have replaced a
  # false positive with a false negative.
  testthat::expect_false(same_package_version("1.1.2", "1.1.1"))
  testthat::expect_false(same_package_version("1.0.13-2", "1.0.13-1"))
  testthat::expect_false(same_package_version(NA_character_, "1.0.0"))
})

testthat::test_that("the running environment matches the lockfile", {
  testthat::skip_if_not(
    file.exists(file.path(project_test_root, "renv.lock")), "no lockfile"
  )
  # strict = TRUE stops on a difference in a package this project loads directly.
  # It is the same call run_update.R makes before any build begins.
  testthat::expect_true(check_environment(project_test_root, strict = TRUE))
})

testthat::test_that("a build from an uncommitted tree blocks, and the override says it was taken", {
  path <- withr::local_tempfile(fileext = ".duckdb")
  con <- DBI::dbConnect(duckdb::duckdb(), path)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  initialize_database(con, project_test_root)

  dirty <- withr::local_tempdir()
  # A directory that is not a checkout answers NA, and NA is a warning rather
  # than a pass: a dirtiness check that cannot tell must not answer "clean".
  DBI::dbExecute(con, "DELETE FROM audit.quality_flags")
  validate_build_reproducibility(con, "fixture", dirty)
  flags <- DBI::dbGetQuery(con, paste(
    "SELECT check_name, severity FROM audit.quality_flags WHERE release_id = 'fixture'"
  ))
  testthat::expect_equal(flags$check_name, "build_git_state_unknown")
  testthat::expect_equal(flags$severity, "warning")

  # A real checkout with an uncommitted tracked change blocks.
  testthat::skip_if(nchar(Sys.which("git")) == 0L, "git not available")
  repo <- withr::local_tempdir()
  quiet <- function(args) system2("git", c("-C", shQuote(repo), args), stdout = FALSE, stderr = FALSE)
  quiet("init")
  quiet(c("config", "user.email", "fixture@example.invalid"))
  quiet(c("config", "user.name", "Fixture"))
  writeLines("one", file.path(repo, "tracked.txt"))
  quiet(c("add", "tracked.txt"))
  quiet(c("commit", "-m", "first"))
  testthat::skip_if(is.na(git_build_state(repo)$dirty), "git state unavailable in this sandbox")
  testthat::expect_false(git_build_state(repo)$dirty)

  DBI::dbExecute(con, "DELETE FROM audit.quality_flags")
  validate_build_reproducibility(con, "fixture", repo)
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM audit.quality_flags WHERE release_id = 'fixture'"
  ))$n[[1]], 0L)

  writeLines("two", file.path(repo, "tracked.txt"))
  testthat::expect_true(git_build_state(repo)$dirty)
  DBI::dbExecute(con, "DELETE FROM audit.quality_flags")
  withr::with_envvar(c(PARAGUAY_MACRO_ALLOW_DIRTY_BUILD = ""), {
    validate_build_reproducibility(con, "fixture", repo)
  })
  blocked <- DBI::dbGetQuery(con, paste(
    "SELECT check_name, severity FROM audit.quality_flags WHERE release_id = 'fixture'"
  ))
  testthat::expect_equal(blocked$check_name, "dirty_tree_build")
  testthat::expect_equal(blocked$severity, "error")

  # The override proceeds and records that it was taken, so a development build
  # cannot be mistaken for a research release after the fact.
  DBI::dbExecute(con, "DELETE FROM audit.quality_flags")
  withr::with_envvar(c(PARAGUAY_MACRO_ALLOW_DIRTY_BUILD = "1"), {
    validate_build_reproducibility(con, "fixture", repo)
  })
  overridden <- DBI::dbGetQuery(con, paste(
    "SELECT check_name, severity FROM audit.quality_flags WHERE release_id = 'fixture'"
  ))
  testthat::expect_equal(overridden$check_name, "dirty_tree_build_overridden")
  testthat::expect_equal(overridden$severity, "warning")
})

testthat::test_that("the build manifest records what a result was computed from", {
  manifest <- file.path(project_test_root, "outputs", "build_manifest.json")
  testthat::skip_if_not(file.exists(manifest), "no build has been published in this working tree")
  parsed <- jsonlite::fromJSON(manifest)
  testthat::expect_match(parsed$database$sha256, "^[0-9a-f]{64}$")
  testthat::expect_true(parsed$database$schema_version >= 39L)
  testthat::expect_true(nzchar(parsed$build$build_id))
  testthat::expect_true(all(c("canonical.fact_series_events", "canonical.dim_series")
                            %in% names(parsed$table_counts)))
  # The fields a second clean rebuild is not expected to reproduce are named,
  # not quietly omitted -- a manifest that dropped them would be claiming a
  # determinism it had not checked.
  testthat::expect_true(all(
    c("generated_at", "built_at") %in% parsed$nondeterministic_fields
  ))
  # The checksum in the manifest is the checksum of the file beside it.
  sidecar <- file.path(project_test_root, "database", "paraguay_macro_pilot.duckdb.sha256")
  testthat::skip_if_not(file.exists(sidecar), "no sidecar")
  testthat::expect_match(readLines(sidecar, warn = FALSE)[[1]], parsed$database$sha256, fixed = TRUE)
})
