project_test_root <- normalizePath(file.path(getwd()), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(project_test_root, "config", "source_registry.csv"))) {
  project_test_root <- normalizePath(file.path(getwd(), "..", ".."), winslash = "/", mustWork = TRUE)
}
source(file.path(project_test_root, "scripts", "load_project.R"))
load_project_scripts(project_test_root, profile = "pipeline")

project_test_database <- function() {
  override <- Sys.getenv("PARAGUAY_MACRO_TEST_DATABASE", unset = "")
  if (nzchar(override)) normalizePath(override, winslash = "/", mustWork = TRUE)
  else file.path(project_test_root, "database", "paraguay_macro_pilot.duckdb")
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
