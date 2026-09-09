# Rebuilds a separate database using every deduplicated workbook in input_archive/.
# The production database is never overwritten.
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(root, "scripts", "load_project.R"))
load_project_scripts(root, profile = "pipeline")
ensure_dirs(root)
registry <- readr::read_csv(file.path(root, "config", "source_registry.csv"), show_col_types = FALSE)
manifest <- build_archive_manifest(registry, root)
if (!nrow(manifest)) stop("No archived workbooks found. Run source('run_update.R') first.", call. = FALSE)
target <- file.path(root, "database", "paraguay_macro_rebuilt_from_archive.duckdb")
if (file.exists(target)) stop("Archive rebuild target already exists; move it to backups/ before rebuilding again: ", target, call. = FALSE)
result <- run_manifest_pipeline(root, registry, manifest, db_path = target)
message("Archive reconstruction completed: ", result$database)
