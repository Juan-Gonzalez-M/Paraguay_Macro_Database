# Run from the project root: source("run_update.R")
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(root, "config", "source_registry.csv"))) {
  stop("Open pilot_paraguay_macro_database.Rproj first, then run source('run_update.R').", call. = FALSE)
}
for (script in c("01_utils.R", "03_concepts.R", "02_extract_raw.R", "03_reference_semantics.R", "03_curate_documented.R", "03_curate_expanded.R", "03_curate_special.R", "04_validate.R", "05_query_helpers.R", "07_migration.R", "08_reconciliation.R", "09_semantics.R", "10_canonical.R", "11_marts.R", "06_pipeline.R")) {
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
# The audit's P0 asks for a gate that actually stops a defective release rather
# than recording its defects and continuing. An error-severity flag now fails
# the run, so a caller in a script or scheduler sees it.
if (identical(result$status, "release_blocked")) {
  stop(
    "Release gate: the run produced error-severity quality flags and is blocked. ",
    "See outputs/quality_flags_latest.csv.", call. = FALSE
  )
}
