project_test_root <- normalizePath(file.path(getwd()), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(project_test_root, "config", "source_registry.csv"))) {
  project_test_root <- normalizePath(file.path(getwd(), "..", ".."), winslash = "/", mustWork = TRUE)
}
for (script in c("01_utils.R", "03_concepts.R", "02_extract_raw.R", "03_reference_semantics.R", "03_curate_documented.R", "03_curate_expanded.R", "03_curate_special.R", "04_validate.R", "05_query_helpers.R", "07_migration.R", "08_reconciliation.R", "09_semantics.R", "10_canonical.R", "11_marts.R", "12_platform.R", "14_review_readiness.R", "06_pipeline.R")) {
  source(file.path(project_test_root, "scripts", script))
}

# Publishing a release in a fixture, since schema 30 made that two steps.
#
# decide_release() records the source bundle's lifecycle and no longer publishes
# anything: publication is a pointer at an immutable per-product decision, so a
# fixture that wants its data visible has to promote a product the way the
# pipeline does. `blocked` clears the pointer when it names this bundle, which is
# how a fixture models "this was never published".
publish_test_release <- function(con, release_id, status = "accepted",
                                 build_id = paste0("build:", substr(digest::digest(
                                   paste(release_id, status), algo = "sha256", serialize = FALSE
                                 ), 1, 24)),
                                 errors = 0L, warnings = 0L) {
  decide_release(con, release_id, status, errors, warnings)
  record_data_release_decision(
    con, release_id, build_id, NA_character_, 30L, status, errors, warnings, "fixture"
  )
  if (identical(status, "accepted")) {
    promote_data_release(con, build_id, release_id, "fixture")
  } else {
    DBI::dbExecute(con, paste0(
      "DELETE FROM ", project_qualified_name("active_data_release"),
      " WHERE source_bundle_id = ", sql_string(release_id)
    ))
  }
  invisible(build_id)
}
