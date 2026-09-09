# Rebuilds a separate database using every deduplicated workbook in input_archive/.
# The production database is never overwritten.
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
for (script in c("01_utils.R", "03_concepts.R", "02_extract_raw.R", "03_reference_semantics.R", "03_curate_documented.R", "03_curate_expanded.R", "03_curate_special.R", "04_validate.R", "05_query_helpers.R", "07_migration.R", "08_reconciliation.R", "09_semantics.R", "10_canonical.R", "11_marts.R", "12_platform.R", "14_review_readiness.R", "06_pipeline.R")) {
  source(file.path(root, "scripts", script))
}
ensure_dirs(root)
registry <- readr::read_csv(file.path(root, "config", "source_registry.csv"), show_col_types = FALSE)
manifest <- build_archive_manifest(registry, root)
if (!nrow(manifest)) stop("No archived workbooks found. Run source('run_update.R') first.", call. = FALSE)
target <- file.path(root, "database", "paraguay_macro_rebuilt_from_archive.duckdb")
if (file.exists(target)) stop("Archive rebuild target already exists; move it to backups/ before rebuilding again: ", target, call. = FALSE)
result <- run_manifest_pipeline(root, registry, manifest, db_path = target)
message("Archive reconstruction completed: ", result$database)
