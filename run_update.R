# Run from the project root: source("run_update.R")
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(root, "config", "source_registry.csv"))) {
  stop("Open pilot_paraguay_macro_database.Rproj first, then run source('run_update.R').", call. = FALSE)
}
for (script in c("01_utils.R", "03_concepts.R", "02_extract_raw.R", "03_reference_semantics.R", "03_curate_documented.R", "03_curate_expanded.R", "03_curate_special.R", "04_validate.R", "06_pipeline.R")) {
  source(file.path(root, "scripts", script))
}
ensure_dirs(root)
registry <- readr::read_csv(file.path(root, "config", "source_registry.csv"), show_col_types = FALSE)
resolved <- build_current_manifest(registry, root)
result <- run_manifest_pipeline(root, registry, resolved$manifest, resolved$issues)
message("Database: ", result$database)
message("Deterministic release: ", result$release_id)
message("Run status: ", result$status)
message("Review outputs/update_report.md before using new observations.")
