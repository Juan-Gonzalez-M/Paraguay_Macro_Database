# Write a distributable copy of the database with workstation paths removed.
#
# The audit's P2: "consider stripping workstation-absolute paths from
# distributed copies while retaining portable URIs and hashes."
#
# Two kinds of path are stored, and only one of them is durable lineage.
# source_uri and archive_uri are repository-relative and mean the same thing on
# anyone's machine -- they are how a reader finds the workbook a value came from.
# source_path and archive_path are absolute, name a home directory, and mean
# something only on the machine that ran the ingestion; they are run metadata,
# and the previous release said so. Keeping them in the live database is right
# and useful. Shipping them to a third party discloses a directory layout and a
# user name for no research benefit.
#
# So the live file is never modified. This writes a copy, blanks the run-local
# paths in it, and verifies the copy still carries every portable URI and hash
# and still executes -- because a distributed database that does not open is the
# defect the whole schema-22 round exists to fix.
#
# Usage:  Rscript prepare_distribution.R [output_path]

suppressPackageStartupMessages({
  library(DBI)
  library(duckdb)
})

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(root, "config", "source_registry.csv"))) {
  stop("Run from the project root.", call. = FALSE)
}
production <- file.path(root, "database", "paraguay_macro_pilot.duckdb")
if (!file.exists(production)) stop("No database at ", production, call. = FALSE)

args <- commandArgs(trailingOnly = TRUE)
target <- if (length(args)) args[[1]] else file.path(
  root, "database", "paraguay_macro_pilot_distribution.duckdb"
)
if (file.exists(target)) stop(
  "Refusing to overwrite an existing file: ", target, call. = FALSE
)

# The columns that hold a path meaningful only on the machine that ran the
# ingestion. Named rather than pattern-matched: a column added later should have
# to be considered, not silently scrubbed or silently shipped.
RUN_LOCAL_PATH_COLUMNS <- list(
  list(table = "raw.source_files", columns = c("source_path", "archive_path"))
)

message("Copying ", basename(production), " -> ", basename(target), " ...")
if (!file.copy(production, target)) stop("Could not write the distribution copy.", call. = FALSE)

con <- dbConnect(duckdb(), target)
scrubbed <- 0L
for (entry in RUN_LOCAL_PATH_COLUMNS) {
  present <- DBI::dbGetQuery(con, paste0(
    "SELECT column_name FROM information_schema.columns WHERE table_schema = '",
    sub("[.].*$", "", entry$table), "' AND table_name = '", sub("^.*[.]", "", entry$table), "'"
  ))$column_name
  for (column in intersect(entry$columns, present)) {
    scrubbed <- scrubbed + DBI::dbExecute(con, paste0(
      "UPDATE ", entry$table, " SET ", column, " = NULL WHERE ", column, " IS NOT NULL"
    ))
  }
}

# The portable lineage has to survive, or the copy is not a database anyone can
# trace a number through.
kept <- DBI::dbGetQuery(con, paste(
  "SELECT count(*) AS files,",
  "count(source_uri) AS source_uris, count(archive_uri) AS archive_uris,",
  "count(sha256) AS hashes FROM raw.source_files"
))
if (kept$source_uris[[1]] < kept$files[[1]] || kept$archive_uris[[1]] < kept$files[[1]] ||
    kept$hashes[[1]] < kept$files[[1]]) {
  DBI::dbDisconnect(con, shutdown = TRUE)
  unlink(target)
  stop("Distribution guard: the copy lost a portable URI or a hash; nothing was written.",
       call. = FALSE)
}
remaining <- DBI::dbGetQuery(con, paste(
  "SELECT count(*) AS n FROM raw.source_files",
  "WHERE coalesce(source_path, '') <> '' OR coalesce(archive_path, '') <> ''"
))$n[[1]]
DBI::dbDisconnect(con, shutdown = TRUE)
if (remaining) {
  unlink(target)
  stop("Distribution guard: ", remaining, " run-local path(s) survived; nothing was written.",
       call. = FALSE)
}

# And it still has to open. Same check the release gate and the compaction run:
# a default connection, nothing configured.
message("Executing every published object in the copy...")
runtime <- dbConnect(duckdb(), target, read_only = TRUE)
views <- DBI::dbGetQuery(runtime, paste(
  "SELECT schema_name, view_name FROM duckdb_views() WHERE NOT internal ORDER BY 1, 2"
))
failures <- character()
for (i in seq_len(nrow(views))) {
  object <- sprintf('"%s"."%s"', views$schema_name[[i]], views$view_name[[i]])
  outcome <- try(DBI::dbGetQuery(runtime, paste("SELECT count(*) FROM", object)), silent = TRUE)
  if (inherits(outcome, "try-error")) failures <- c(failures, paste0(
    views$schema_name[[i]], ".", views$view_name[[i]]
  ))
}
DBI::dbDisconnect(runtime, shutdown = TRUE)
if (length(failures)) {
  unlink(target)
  stop("Distribution guard: ", length(failures), " object(s) do not execute in the copy: ",
       paste(utils::head(failures, 5), collapse = "; "), call. = FALSE)
}

message(sprintf(
  "Distribution copy written: %s\n  %d run-local path value(s) removed; %d files keep their source URI, archive URI and hash.\n  %d views executed from a default connection.\n  The live database is unchanged.",
  target, scrubbed, kept$files[[1]], nrow(views)
))
