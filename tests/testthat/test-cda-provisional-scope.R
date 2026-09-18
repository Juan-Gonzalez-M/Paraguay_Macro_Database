CDA_PROVISIONAL_SCOPE_ID <- "schema46_cda_provisional_20260917"
CDA_EXACT_SHA256 <- "8796a589fc2bd31317efdce7865d4598473fdacd048cf04b676dc8f78e2b144c"
TCN_EXACT_SHA256 <- "74df666397a33b9c8cdfac10d7ffedd23acf7cbd5907ea21332e100fb939c0a4"

testthat::test_that("bounded CDA scope admits only the authorized hash and keeps TCN deferred", {
  registry <- readr::read_csv(
    file.path(project_test_root, "config", "source_registry.csv"), show_col_types = FALSE
  )
  scoped <- build_scoped_current_manifest(
    registry, project_test_root, CDA_PROVISIONAL_SCOPE_ID, expected_schema_version = 46L
  )
  testthat::expect_equal(nrow(scoped$scope), nrow(registry))
  testthat::expect_equal(sum(scoped$scope$disposition == "admit"), 23L)
  testthat::expect_equal(sum(scoped$scope$disposition == "defer"), 1L)
  testthat::expect_identical(
    scoped$scope$sha256[scoped$scope$source_id == "cda_curve"], CDA_EXACT_SHA256
  )
  testthat::expect_identical(
    scoped$scope$disposition[scoped$scope$source_id == "cda_curve"], "admit"
  )
  testthat::expect_identical(
    scoped$scope$sha256[scoped$scope$source_id == "tcn_referential_daily"], TCN_EXACT_SHA256
  )
  testthat::expect_identical(
    scoped$scope$disposition[scoped$scope$source_id == "tcn_referential_daily"], "defer"
  )
  testthat::expect_false("tcn_referential_daily" %in% scoped$manifest$source_id)
  testthat::expect_true("cda_curve" %in% scoped$manifest$source_id)
  testthat::expect_false(any(scoped$issues$severity == "error"))
})

testthat::test_that("bounded CDA scope fails closed when CDA bytes drift", {
  registry <- readr::read_csv(
    file.path(project_test_root, "config", "source_registry.csv"), show_col_types = FALSE
  )
  resolved <- build_current_manifest(registry, project_test_root)
  hit <- resolved$manifest$source_id == "cda_curve"
  drift_sha <- paste(rep("a", 64L), collapse = "")
  resolved$manifest$sha256[hit] <- drift_sha
  resolved$manifest$vintage_id[hit] <- make_vintage_id("cda_curve", drift_sha)
  scoped <- apply_release_input_scope(
    registry, resolved, project_test_root, CDA_PROVISIONAL_SCOPE_ID,
    expected_schema_version = 46L
  )
  issue <- scoped$issues[
    scoped$issues$source_id == "cda_curve" &
      scoped$issues$check_name == "release_input_scope_unresolved", , drop = FALSE
  ]
  testthat::expect_equal(nrow(issue), 1L)
  testthat::expect_identical(issue$severity, "error")
  testthat::expect_match(issue$detail, drift_sha, fixed = TRUE)
  testthat::expect_false("cda_curve" %in% scoped$manifest$source_id)
})
