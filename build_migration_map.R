# Record how series identities moved between two releases.
#
# Run from the project root. The map is always written into the production
# database, whichever pair of releases is being compared, because that is where
# research code looks up a superseded identifier:
#
#   Rscript build_migration_map.R <previous_db> <from_release> <to_release> [current_db]
#
# Omit current_db to compare the previous release against production. Supply it
# to record an older hop whose "current" side is itself an archived file, for
# example the schema-11 to schema-12 churn the audit reported. Recording every
# hop matters because resolution is transitive: an identifier published under
# schema 11 may have been renamed twice before reaching the live catalogue.
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(root, "config", "source_registry.csv"))) {
  stop("Run from the project root: Rscript build_migration_map.R ...", call. = FALSE)
}
for (script in c("01_utils.R", "03_concepts.R", "02_extract_raw.R", "07_migration.R")) {
  source(file.path(root, "scripts", script))
}

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3L) stop(
  "Usage: Rscript build_migration_map.R <previous_db> <from_release> <to_release> [current_db]",
  call. = FALSE
)
previous_db <- normalizePath(args[[1]], winslash = "/", mustWork = TRUE)
from_release <- args[[2]]
to_release <- args[[3]]
current_db <- if (length(args) >= 4L) normalizePath(args[[4]], winslash = "/", mustWork = TRUE) else NULL

production <- file.path(root, "database", "paraguay_macro_pilot.duckdb")
# connect_project_database(), not a bare dbConnect: this script writes to
# series_id_migration and source_alias by unqualified name, and those live in
# canonical. A published interface must not depend on the search path -- this is
# not one, it is a maintenance tool, and setting the path is the right answer for
# it rather than qualifying every write.
con <- connect_project_database(production)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

# The catalogue the production database is attached under, asked for rather than
# assumed. DuckDB names the primary catalogue after the file -- here
# "paraguay_macro_pilot" -- and never "main"; main is a schema inside it. That
# distinction did not matter until schema 21 introduced attached_table(), which
# filters duckdb_tables() by database_name, and the hard-coded "main" then
# matched nothing and this script stopped being able to run at all. Same shape
# as the defect schema 22 fixes in the stored views: a name resolved by
# assumption in a database whose objects had moved.
current_catalog <- DBI::dbGetQuery(con, "SELECT current_database() AS name")$name[[1]]
if (!is.null(current_db) && !identical(current_db, normalizePath(production, winslash = "/"))) {
  DBI::dbExecute(con, paste0("ATTACH ", sql_string(current_db), " AS mid (READ_ONLY)"))
  on.exit(try(DBI::dbExecute(con, "DETACH mid"), silent = TRUE), add = TRUE)
  current_catalog <- "mid"
}

rows <- build_series_id_migration(
  con, previous_db, from_release, to_release, root, current = current_catalog
)

summary_rows <- DBI::dbGetQuery(con, paste0(
  "SELECT relationship, match_method, count(*) AS mappings FROM series_id_migration",
  " WHERE from_release = ", sql_string(from_release),
  " AND to_release = ", sql_string(to_release),
  " GROUP BY 1, 2 ORDER BY 3 DESC"
))
message("Recorded ", nrow(rows), " mappings for ", from_release, " -> ", to_release)
print(summary_rows, row.names = FALSE)
message("Aliases now resolvable: ", DBI::dbGetQuery(
  con, "SELECT count(*) AS n FROM source_alias WHERE alias_kind = 'prior_release_series_id'"
)$n[[1]])
