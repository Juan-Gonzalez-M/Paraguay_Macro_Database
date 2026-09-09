# Run from the project root to regenerate review evidence packets without
# ingesting, modifying, or publishing the DuckDB.
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(root, "config", "source_registry.csv"))) {
  stop("Run this script from the project root.", call. = FALSE)
}
for (script in c(
  "01_utils.R", "03_concepts.R", "02_extract_raw.R", "03_reference_semantics.R",
  "03_curate_documented.R", "03_curate_expanded.R", "03_curate_special.R", "04_validate.R",
  "05_query_helpers.R", "07_migration.R", "08_reconciliation.R", "09_semantics.R",
  "10_canonical.R", "11_marts.R", "12_platform.R", "14_review_readiness.R"
)) source(file.path(root, "scripts", script))
con <- open_macro_database(root, read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
write_flagship_review_queue(con, root)
write_duplicate_resolution_queue(con, root)
message("Review packets written to outputs/. The database was opened read-only.")
