# Run from the project root to regenerate review evidence packets without
# ingesting, modifying, or publishing the DuckDB.
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(root, "config", "source_registry.csv"))) {
  stop("Run this script from the project root.", call. = FALSE)
}
source(file.path(root, "scripts", "load_project.R"))
load_project_scripts(root, profile = "research_tools")
con <- open_macro_database(root, read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
write_flagship_review_queue(con, root)
write_duplicate_resolution_queue(con, root)
message("Review packets written to outputs/. The database was opened read-only.")
