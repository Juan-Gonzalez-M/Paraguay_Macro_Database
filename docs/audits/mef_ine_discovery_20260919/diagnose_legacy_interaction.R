root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(root, "scripts", "load_project.R"))
load_project_scripts(root, profile = "pipeline")
registry <- readr::read_csv(file.path(root, "config", "source_registry.csv"), show_col_types = FALSE)
resolved <- build_current_manifest(registry, root)

diagnostic_pipeline <- function(root, registry, manifest, resolution_issues,
                                db_path, artifact_path) {
  con <- connect_project_database(db_path)
  invalidate_documented_sources(
    con, c("economic_annex", "bcp_fx_daily"),
    "mef_ine_shared_parser_interaction_diagnosis"
  )
  DBI::dbDisconnect(con, shutdown = TRUE)
  run_manifest_pipeline(
    root, registry, manifest, resolution_issues,
    db_path = db_path, artifact_path = artifact_path
  )
}

result <- run_isolated_update(
  root, registry, resolved$manifest, resolved$issues,
  pipeline = diagnostic_pipeline, publish = FALSE
)
print(result)
