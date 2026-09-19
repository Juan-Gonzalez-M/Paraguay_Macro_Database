root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(root, "scripts", "load_project.R"))
load_project_scripts(root, profile = "pipeline")

registry <- readr::read_csv(
  file.path(root, "config", "source_registry.csv"), show_col_types = FALSE
)
resolved <- build_scoped_current_manifest(
  registry, root, "schema46_cda_provisional_20260917",
  expected_schema_version = 46L
)
environment_ok <- withCallingHandlers(
  check_environment(root, strict = FALSE),
  warning = function(w) invokeRestart("muffleWarning")
)
environment_issues <- if (isTRUE(environment_ok)) {
  tibble::tibble(
    severity = character(), check_name = character(),
    source_id = character(), detail = character()
  )
} else {
  tibble::tibble(
    severity = "warning", check_name = "environment_drift_overridden",
    source_id = NA_character_,
    detail = paste(
      "The running package versions differ from renv.lock. The user prohibited package",
      "installation; the isolated review candidate records this known limitation."
    )
  )
}

# The source bytes are unchanged, so explicitly invalidate only CDA in the
# isolated copy. This forces the current parser and semantic decisions to be
# applied without rebuilding or substituting the immutable workbook.
cda_pipeline <- function(root, registry, manifest, resolution_issues,
                         db_path, artifact_path) {
  con <- connect_project_database(db_path)
  invalidate_documented_sources(
    con, "cda_curve", "cda_semantic_decisions_20260919"
  )
  DBI::dbDisconnect(con, shutdown = TRUE)
  run_manifest_pipeline(
    root, registry, manifest, resolution_issues,
    db_path = db_path, artifact_path = artifact_path
  )
}

result <- run_isolated_update(
  root, registry, resolved$manifest,
  dplyr::bind_rows(resolved$issues, environment_issues),
  pipeline = cda_pipeline, publish = FALSE
)
print(result)
