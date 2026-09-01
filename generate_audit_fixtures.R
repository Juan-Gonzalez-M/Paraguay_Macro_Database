# Regenerate the golden fixtures for the recovered cells and the period
# corrections.
#
# The audit's P0-3 asks for "golden source-cell fixtures for all 4,338 recovered
# observations and 1,089 period corrections". The point of a fixture is that the
# claim survives the code that made it: a later parser change that quietly stops
# reading one of these cells has to fail a test rather than pass unnoticed.
#
# The comparison is the audit's own -- a physical source-cell comparison on
# (source_id, source_sheet, source_row, source_column), which is stable across
# the identifier churn every parser repair causes. Two products:
#
#   recovered_observations.csv  cells the current release reads that the
#                               baseline did not
#   period_corrections.csv      cells both read, dated differently
#
# The baseline is the last database that predates the repairs, kept in
# database/backups/. Pass a different one as the first argument to re-cut the
# fixtures against another release.
#
# Usage:  Rscript generate_audit_fixtures.R [baseline.duckdb]

suppressPackageStartupMessages({
  library(DBI)
  library(duckdb)
  library(readr)
})

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(root, "config", "source_registry.csv"))) {
  stop("Run from the project root.", call. = FALSE)
}
args <- commandArgs(trailingOnly = TRUE)
baseline <- if (length(args)) args[[1]] else file.path(
  root, "database", "backups", "paraguay_macro_pilot_pre_v16_20260829_092745.duckdb"
)
if (!file.exists(baseline)) stop("Baseline database not found: ", baseline, call. = FALSE)
current <- file.path(root, "database", "paraguay_macro_pilot.duckdb")

con <- dbConnect(duckdb(), ":memory:")
on.exit(try(dbDisconnect(con, shutdown = TRUE), silent = TRUE), add = TRUE)
DBI::dbExecute(con, paste0("ATTACH ", DBI::dbQuoteString(con, baseline), " AS prior (READ_ONLY)"))
DBI::dbExecute(con, paste0("ATTACH ", DBI::dbQuoteString(con, current), " AS live (READ_ONLY)"))

# The baseline predates the storage-layer move, so its tables are in main while
# the current ones are in staging. Resolve both from the catalogue rather than
# assuming either.
snapshot_of <- function(database) {
  found <- DBI::dbGetQuery(con, paste0(
    "SELECT schema_name FROM duckdb_tables() WHERE database_name = ",
    DBI::dbQuoteString(con, database),
    " AND table_name = 'documented_series_snapshot' ORDER BY schema_name LIMIT 1"
  ))
  if (!nrow(found)) stop("No documented_series_snapshot in ", database, call. = FALSE)
  paste0(database, ".", found$schema_name[[1]], ".documented_series_snapshot")
}
prior_snapshot <- snapshot_of("prior")
live_snapshot <- snapshot_of("live")

message("Baseline : ", basename(baseline))
message("Current  : ", basename(current))

cell_key <- "source_id, source_sheet, source_row, source_column"

recovered <- DBI::dbGetQuery(con, paste0(
  "SELECT l.source_id, l.source_sheet, l.source_row, l.source_column,",
  " l.period, l.frequency, l.series_id, l.series_label, l.value",
  " FROM (SELECT DISTINCT ", cell_key, ", period, frequency, series_id, series_label, value",
  "       FROM ", live_snapshot, ") l",
  " LEFT JOIN (SELECT DISTINCT ", cell_key, " FROM ", prior_snapshot, ") p",
  "   ON p.source_id = l.source_id AND p.source_sheet = l.source_sheet",
  "  AND p.source_row = l.source_row AND p.source_column = l.source_column",
  " WHERE p.source_id IS NULL",
  " ORDER BY l.source_id, l.source_sheet, l.source_row, l.source_column"
))

corrections <- DBI::dbGetQuery(con, paste0(
  "SELECT l.source_id, l.source_sheet, l.source_row, l.source_column,",
  " p.period AS previous_period, l.period AS period, l.frequency, l.value",
  " FROM (SELECT DISTINCT ", cell_key, ", period, frequency, value FROM ", live_snapshot, ") l",
  " JOIN (SELECT DISTINCT ", cell_key, ", period FROM ", prior_snapshot, ") p",
  "   ON p.source_id = l.source_id AND p.source_sheet = l.source_sheet",
  "  AND p.source_row = l.source_row AND p.source_column = l.source_column",
  " WHERE p.period IS DISTINCT FROM l.period",
  " ORDER BY l.source_id, l.source_sheet, l.source_row, l.source_column"
))

# A cell that stopped being read is a regression, not a recovery, and it is the
# thing this comparison exists to notice.
lost <- DBI::dbGetQuery(con, paste0(
  "SELECT p.source_id, p.source_sheet, count(*) AS cells",
  " FROM (SELECT DISTINCT ", cell_key, " FROM ", prior_snapshot, ") p",
  " LEFT JOIN (SELECT DISTINCT ", cell_key, " FROM ", live_snapshot, ") l",
  "   ON p.source_id = l.source_id AND p.source_sheet = l.source_sheet",
  "  AND p.source_row = l.source_row AND p.source_column = l.source_column",
  " WHERE l.source_id IS NULL GROUP BY 1, 2 ORDER BY cells DESC"
))

fixtures <- file.path(root, "tests", "testthat", "fixtures")
readr::write_csv(recovered, file.path(fixtures, "recovered_observations.csv"))
readr::write_csv(corrections, file.path(fixtures, "period_corrections.csv"))

message(sprintf("Recovered cells   : %d, across %d worksheet(s)",
                nrow(recovered), length(unique(paste(recovered$source_id, recovered$source_sheet)))))
message(sprintf("Period corrections: %d, across %d worksheet(s)",
                nrow(corrections), length(unique(paste(corrections$source_id, corrections$source_sheet)))))
if (nrow(recovered)) {
  by_source <- table(recovered$source_id)
  message("  by source: ", paste(names(by_source), by_source, sep = "=", collapse = ", "))
}
if (nrow(lost)) {
  message("WARNING: ", sum(lost$cells), " source cell(s) the baseline read are no longer read:")
  for (i in seq_len(min(10L, nrow(lost)))) message(sprintf(
    "  %s / %s: %d", lost$source_id[[i]], lost$source_sheet[[i]], lost$cells[[i]]
  ))
} else {
  message("No source cell the baseline read has stopped being read.")
}
