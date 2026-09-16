# Run from the project root. The first argument is the candidate database and
# the optional second argument is the output directory.
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(root, "scripts", "load_project.R"))
load_project_scripts(root, profile = "research_tools", quiet = TRUE)
args <- commandArgs(trailingOnly = TRUE)
database_path <- if (length(args)) args[[1]] else file.path(
  root, "database", "paraguay_macro_pilot.duckdb"
)
output_dir <- if (length(args) >= 2L) args[[2]] else file.path(
  root, "docs", "audits", "schema43_post_promotion_series_quality"
)
con <- DBI::dbConnect(duckdb::duckdb(), database_path, read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE))
quality_temp <- tempfile("paraguay_macro_series_quality_")
dir.create(quality_temp, recursive = TRUE, showWarnings = FALSE)
on.exit(unlink(quality_temp, recursive = TRUE), add = TRUE)
DBI::dbExecute(con, paste0("SET temp_directory=", sql_string(quality_temp)))
write_series_quality_package(
  con, output_dir, database_path = database_path,
  baseline_sha256 = "6079c80ce0edd26f899b9f54fe98f73eee08c90c5f006759b051960edbd7a9fa"
)
