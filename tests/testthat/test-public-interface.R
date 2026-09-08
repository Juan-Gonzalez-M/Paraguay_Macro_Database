# Regression cover for the third audit's P0: the published interface.
#
# The defect these tests exist for: schema 21 moved every table into a storage
# layer while every stored view and macro still named its dependencies bare, so
# 74 of 74 user views and all three macros raised "Table with name dim_series
# does not exist" from a fresh default connection. The pipeline never saw it
# because it sets a search path on its own connections, and the suite never saw
# it because every test reached a view through connect_project_database() or
# initialize_database(), which do the same.
#
# So the rule for this file is that it must NOT use the project's connection
# helper. It opens the database the way a researcher does -- plain DBI, default
# settings, nothing configured -- and a test that quietly set a search path would
# be testing nothing.

round3_database <- function() {
  path <- file.path(project_test_root, "database", "paraguay_macro_pilot.duckdb")
  testthat::skip_if_not(file.exists(path), "production database not present")
  path
}

# Deliberately NOT connect_project_database().
open_unconfigured <- function(read_only = TRUE) {
  con <- DBI::dbConnect(duckdb::duckdb(), round3_database(), read_only = read_only)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE), envir = parent.frame())
  con
}

testthat::test_that("the test connection really is unconfigured", {
  # If this fails, every other test in the file is vacuous.
  con <- open_unconfigured()
  configured <- DBI::dbGetQuery(con, "SELECT current_setting('search_path') AS s")$s[[1]]
  testthat::expect_identical(trimws(configured), "")
})

testthat::test_that("every published view executes from a connection with default settings", {
  con <- open_unconfigured()
  views <- DBI::dbGetQuery(con, paste(
    "SELECT schema_name, view_name FROM duckdb_views() WHERE NOT internal",
    "ORDER BY schema_name, view_name"
  ))
  testthat::expect_gt(nrow(views), 60L)
  failures <- character()
  for (i in seq_len(nrow(views))) {
    object <- paste0("\"", views$schema_name[[i]], "\".\"", views$view_name[[i]], "\"")
    # Binding and execution are different failures: a view can bind and still
    # fail on a dependency reached only when rows are produced.
    for (form in c("SELECT * FROM %s LIMIT 0", "SELECT count(*) FROM %s")) {
      outcome <- try(DBI::dbGetQuery(con, sprintf(form, object)), silent = TRUE)
      if (inherits(outcome, "try-error")) {
        failures <- c(failures, paste0(
          views$schema_name[[i]], ".", views$view_name[[i]], ": ",
          trimws(gsub("\\s+", " ", conditionMessage(attr(outcome, "condition"))))
        ))
        break
      }
    }
  }
  testthat::expect_identical(failures, character())
})

testthat::test_that("the three resolver and as-of macros execute from a default connection", {
  con <- open_unconfigured()
  # Literals, not columns. A DuckDB macro substitutes the caller's argument
  # expression into its body, so calling the resolver with a bare column named
  # like its key column would turn the comparison into a tautology -- the reason
  # the scalar view's key is called lookup_id. Literals are what callers write.
  testthat::expect_true(is.data.frame(
    DBI::dbGetQuery(con, "SELECT resolve_series_id('smoke:not-a-series') AS resolved")
  ))
  testthat::expect_identical(
    DBI::dbGetQuery(con, "SELECT resolve_series_id('smoke:not-a-series') AS resolved")$resolved,
    NA_character_
  )
  testthat::expect_equal(
    nrow(DBI::dbGetQuery(con, "SELECT * FROM resolve_series_ids('smoke:not-a-series')")), 0L
  )
  testthat::expect_true(is.data.frame(
    DBI::dbGetQuery(con, "SELECT count(*) AS n FROM series_as_of_date(DATE '1900-01-01')")
  ))
})

testthat::test_that("a known identifier resolves to itself through the scalar macro", {
  con <- open_unconfigured()
  known <- DBI::dbGetQuery(con, "SELECT series_id FROM canonical.dim_series ORDER BY series_id LIMIT 1")$series_id
  resolved <- DBI::dbGetQuery(con, paste0(
    "SELECT resolve_series_id(", DBI::dbQuoteString(con, known), ") AS resolved"
  ))$resolved
  testthat::expect_identical(resolved, known)
})

testthat::test_that("no stored view or macro references a project object without a schema", {
  # The lint, run against what is actually stored rather than against what the
  # code meant to store. It is what makes the qualifier auditable instead of
  # trusted: if qualify_project_sql() ever misses a shape, this is what says so.
  con <- open_unconfigured()
  object_names <- DBI::dbGetQuery(con, paste0(
    "SELECT DISTINCT table_name FROM information_schema.tables WHERE table_schema IN (",
    "'main', 'raw', 'staging', 'canonical', 'marts', 'research', 'audit')"
  ))$table_name
  stored <- rbind(
    DBI::dbGetQuery(con, paste(
      "SELECT schema_name || '.' || view_name AS object_name, sql AS body",
      "FROM duckdb_views() WHERE NOT internal"
    )),
    DBI::dbGetQuery(con, paste(
      "SELECT schema_name || '.' || function_name AS object_name, macro_definition AS body",
      "FROM duckdb_functions() WHERE NOT internal AND macro_definition IS NOT NULL"
    ))
  )
  offenders <- character()
  for (i in seq_len(nrow(stored))) {
    bare <- stored_sql_unqualified_references(stored$body[[i]], object_names)
    if (length(bare)) offenders <- c(offenders, paste0(
      stored$object_name[[i]], " -> ", paste(bare, collapse = ", ")
    ))
  }
  testthat::expect_identical(offenders, character())
})

testthat::test_that("the published objects survive being attached under an alias", {
  # A schema-qualified name binds inside the view's own catalogue; a bare one
  # binds against the caller's. ATTACH is how a researcher joins this database to
  # their own work, and how compact_database.R and the migration map already read
  # across releases, so a view that only works on a direct connection is still
  # broken. marts.v_mart_* are the case that failed: their bodies read from
  # main-resident views.
  con <- DBI::dbConnect(duckdb::duckdb(), ":memory:")
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  DBI::dbExecute(con, paste0(
    "ATTACH ", DBI::dbQuoteString(con, round3_database()), " AS pmp (READ_ONLY)"
  ))
  views <- DBI::dbGetQuery(con, paste(
    "SELECT schema_name, view_name FROM duckdb_views()",
    "WHERE database_name = 'pmp' AND NOT internal ORDER BY schema_name, view_name"
  ))
  testthat::expect_gt(nrow(views), 60L)
  failures <- character()
  for (i in seq_len(nrow(views))) {
    object <- sprintf("pmp.\"%s\".\"%s\"", views$schema_name[[i]], views$view_name[[i]])
    outcome <- try(DBI::dbGetQuery(con, paste("SELECT count(*) FROM", object)), silent = TRUE)
    if (inherits(outcome, "try-error")) failures <- c(failures, paste0(
      views$schema_name[[i]], ".", views$view_name[[i]], ": ",
      trimws(gsub("\\s+", " ", conditionMessage(attr(outcome, "condition"))))
    ))
  }
  testthat::expect_identical(failures, character())
})

testthat::test_that("the documented public read API works with nothing configured", {
  # scripts/05_query_helpers.R is what docs/CONCEPT_GOVERNANCE.md tells a
  # researcher to source. It was the exact reproduction of the audit's finding --
  # all five functions failed -- and it was untested because neither run_update.R
  # nor the test helper sourced the file at all.
  path <- round3_database()
  con <- open_macro_database(root = project_test_root)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  testthat::expect_identical(trimws(
    DBI::dbGetQuery(con, "SELECT current_setting('search_path') AS s")$s[[1]]
  ), "")

  known <- DBI::dbGetQuery(con, "SELECT series_id FROM canonical.dim_series ORDER BY series_id LIMIT 1")$series_id
  one <- series_latest(con, known)
  testthat::expect_gt(nrow(one), 0L)
  testthat::expect_true(all(one$series_id == known))

  testthat::expect_true(is.data.frame(series_as_of(con, "2026-01-01", known)))
  testthat::expect_true(is.data.frame(series_revision_history(con, known)))
  testthat::expect_true(is.data.frame(concept_catalogue(con)))
  testthat::expect_true(is.data.frame(series_by_concept(con, "concept:interbank_repo_rate_pyg")))
})

testthat::test_that("the schema version records the interface repair", {
  con <- open_unconfigured()
  applied <- DBI::dbGetQuery(con, "SELECT version FROM audit.schema_version ORDER BY version")$version
  testthat::expect_true(22L %in% applied)
  registry <- vapply(SCHEMA_MIGRATIONS, function(step) step$version, integer(1))
  testthat::expect_true(all(applied[applied > 1L] %in% registry))
})
