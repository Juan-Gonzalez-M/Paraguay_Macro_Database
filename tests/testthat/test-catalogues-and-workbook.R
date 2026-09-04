audit5_production <- function() {
  path <- file.path(project_test_root, "database", "paraguay_macro_pilot.duckdb")
  testthat::skip_if_not(file.exists(path), "no production database")
  con <- connect_project_database(path, read_only = TRUE)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE), envir = parent.frame())
  con
}

testthat::test_that("the release filter is required of every published interface by rule, not by list", {
  # The audit's F-01. The lint used to name the objects it checked, and the list
  # was already stale: the five grain catalogues, v_series_projections and
  # v_series_missingness all live in marts and matched none of its prefixes, so
  # schema 29 published six unfiltered interfaces and the lint said nothing.
  #
  # This asserts the rule rather than a count, so adding a view cannot quietly
  # shrink what is checked.
  con <- audit5_production()
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
  # Scope comes from the declared contract since schema 30, not from a naming
  # rule: a rule over names cannot decide which objects are research interfaces.
  contract <- read_public_view_contract(project_test_root)
  testthat::skip_if(is.null(contract), "no public view contract")
  carriers <- filtered_base_relations(contract)
  required <- intersect(
    contract$object_id[contract$public_scope == "current"], stored$object_name
  )

  # Every marts view that is not an _all twin is declared current.
  marts <- grep("^marts\\.", stored$object_name, value = TRUE)
  testthat::expect_setequal(
    grep("_all$", marts, value = TRUE, invert = TRUE),
    grep("^marts\\.", required, value = TRUE)
  )
  # So are all seventeen direct panels, and each has an unfiltered twin.
  panels <- grep("^main\\.v_latest_raw_", stored$object_name, value = TRUE)
  testthat::expect_equal(sum(!grepl("_all$", panels)), 17L)
  testthat::expect_equal(sum(grepl("_all$", panels)), 17L)
  testthat::expect_true(all(
    grep("_all$", panels, value = TRUE, invert = TRUE) %in% required
  ))
  # And no _all twin is ever required to filter -- that is what they are for.
  testthat::expect_length(grep("_all$", required, value = TRUE), 0L)

  unfiltered <- required[!vapply(
    required, function(name) release_filtered_object(name, stored, carriers), logical(1)
  )]
  testthat::expect_equal(unfiltered, character())
})

testthat::test_that("each series grain has its own catalogue and the scalar one is the macro surface", {
  # The audit's section 6.2: counting an LRM auction tender beside the price index
  # is what made the coverage look an order of magnitude broader than it is.
  con <- audit5_production()
  grains <- DBI::dbGetQuery(con, paste(
    "SELECT view_name FROM duckdb_views()",
    "WHERE schema_name = 'marts' AND view_name LIKE 'v_catalogue_%'"
  ))$view_name
  testthat::expect_true(all(
    paste0("v_catalogue_", SERIES_GRAIN_VALUES) %in% grains
  ))
  per_grain <- vapply(SERIES_GRAIN_VALUES, function(grain) DBI::dbGetQuery(con, paste0(
    "SELECT count(*) AS n FROM marts.v_catalogue_", grain
  ))$n[[1]], numeric(1))
  # Each catalogue holds exactly the series of its grain, and nothing else.
  for (grain in SERIES_GRAIN_VALUES) {
    other <- DBI::dbGetQuery(con, paste0(
      "SELECT count(*) AS n FROM marts.v_catalogue_", grain, " c",
      " JOIN canonical.dim_series d USING (series_id)",
      " WHERE d.series_grain IS DISTINCT FROM ", sql_string(grain)
    ))$n[[1]]
    testthat::expect_equal(other, 0L)
  }
  testthat::expect_gt(per_grain[["scalar_series"]], per_grain[["event"]])
  # A catalogue describes what a researcher can read, so it is counted over the
  # published interface rather than over every fact ever recorded.
  published <- DBI::dbGetQuery(con, paste(
    "SELECT count(DISTINCT series_id) AS n FROM main.v_series_latest"
  ))$n[[1]]
  testthat::expect_equal(sum(per_grain), published)
})

testthat::test_that("formula and hidden-row behaviour is recorded for every worksheet of every source", {
  # The audit's F-13. Neither survives into any value the parser reads: readxl
  # cannot calculate, and a hidden row is one the publisher's own reader does not
  # see. Both were backfilled from the archived workbooks rather than re-ingested.
  con <- audit5_production()
  coverage <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS sheets, count(formula_cells) AS with_behaviour,",
    "count(DISTINCT source_id) AS sources FROM raw.source_sheets"
  ))
  testthat::expect_equal(coverage$with_behaviour[[1]], coverage$sheets[[1]])
  testthat::expect_gte(coverage$sources[[1]], 22L)
  # It is not uniformly zero -- these workbooks really do ship cached formulas.
  testthat::expect_gt(DBI::dbGetQuery(con, paste(
    "SELECT sum(formula_cells) AS n FROM raw.source_sheets"
  ))$n[[1]], 1000)
  # Hidden ranges are packed as they are read and parse back to integers.
  packed <- DBI::dbGetQuery(con, paste(
    "SELECT hidden_rows FROM raw.source_sheets WHERE hidden_rows IS NOT NULL"
  ))$hidden_rows
  testthat::expect_gt(length(packed), 0L)
  testthat::expect_true(all(grepl("^[0-9]+(-[0-9]+)?(;[0-9]+(-[0-9]+)?)*$", packed)))
})

testthat::test_that("observations read from hidden rows are counted rather than assumed away", {
  con <- audit5_production()
  hidden <- hidden_row_observations(con)
  # The annex collapses the early history of its long tables, and the parser reads
  # those rows. That is the right thing to do and it is not visible in any value,
  # which is exactly why it is reported.
  testthat::expect_gt(sum(hidden$hidden_row_observations), 0)
  testthat::expect_true(all(hidden$hidden_row_series > 0))
  # Every worksheet named must actually hide rows.
  declared <- DBI::dbGetQuery(con, paste(
    "SELECT DISTINCT source_id, sheet_name FROM raw.source_sheets",
    "WHERE hidden_rows IS NOT NULL"
  ))
  testthat::expect_true(all(
    paste(hidden$source_id, hidden$sheet_name) %in%
      paste(declared$source_id, declared$sheet_name)
  ))
})

testthat::test_that("stage timings are keyed by attempt and cover the release-wide phases", {
  # The audit's F-16. Timings used to be deleted per release, so the history of
  # how long a run took did not survive the next run, and only per-source parsing
  # was measured -- which is why observation_missingness, the slowest phase in the
  # run, was invisible.
  con <- audit5_production()
  columns <- DBI::dbGetQuery(con, "PRAGMA table_info('audit.ingestion_stage_timings')")$name
  testthat::expect_true("attempt_id" %in% columns)
  release_phases <- DBI::dbGetQuery(con, paste(
    "SELECT DISTINCT stage FROM audit.ingestion_stage_timings WHERE source_id IS NULL"
  ))$stage
  testthat::expect_true(all(c(
    "observation_missingness", "series_semantics", "validation"
  ) %in% release_phases))
  testthat::expect_gt(length(release_phases), 5L)
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM audit.ingestion_stage_timings WHERE elapsed_seconds IS NULL"
  ))$n[[1]], 0L)
  # Rows recorded before schema 29 keep a null attempt, because the table is now
  # append-only and rewriting them would be inventing an attempt they never had.
  # Every row written since carries one.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM audit.ingestion_stage_timings",
    "WHERE attempt_id IS NULL AND recorded_at > (",
    "  SELECT min(recorded_at) FROM audit.ingestion_stage_timings",
    "  WHERE attempt_id IS NOT NULL)"
  ))$n[[1]], 0L)
})

testthat::test_that("build dirtiness answers the reproducibility question and fails closed", {
  # The audit's F-15: every build_identity row recorded git_dirty = TRUE. The
  # cause was not an uncommitted tree. This function runs from inside the
  # pipeline, by which time the run has written to the tracked .duckdb, so the
  # file the build was producing counted as an uncommitted change against the
  # build producing it -- unsatisfiable by construction.
  state <- git_build_state(project_test_root)
  testthat::skip_if(is.na(state$dirty), "not a git checkout")
  testthat::expect_match(state$commit, "^[0-9a-f]{40}$")

  # The database alone must not make a build dirty, and anything else must.
  classify <- function(lines) length(lines[!grepl("^.{2,3}database/", lines)]) > 0L
  testthat::expect_false(classify(" M database/paraguay_macro_pilot.duckdb"))
  testthat::expect_true(classify(c(" M database/paraguay_macro_pilot.duckdb", " M scripts/01_utils.R")))
  testthat::expect_true(classify("A  config/source_value_tokens.csv"))

  # And a git call that fails is NA, never FALSE. The first attempt at this
  # repair used a `:(exclude)` pathspec, which the shell rejected; the command
  # returned nothing, nothing read as a clean tree, and it reported FALSE with
  # uncommitted code in front of it.
  absent <- git_build_state(file.path(tempdir(), "no-such-checkout"))
  testthat::expect_true(is.na(absent$dirty))
  testthat::expect_true(is.na(absent$commit))
})
