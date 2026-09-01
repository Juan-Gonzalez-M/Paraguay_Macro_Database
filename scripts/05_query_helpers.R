# --- The public read interface ----------------------------------------------
# This is what a researcher is told to use, so it is deliberately the harshest
# test of the schema-22 repair: it opens the database the way any external client
# does -- plain DBI, default settings, no search path -- and it names every
# object it touches in full.
#
# Before schema 22 all five functions below failed. open_macro_database() sets no
# search path, and the views they query bound their own dependencies unqualified,
# so `series_latest()` returned "Catalog Error: Table with name dim_series does
# not exist" rather than data. The file was sourced by neither run_update.R nor
# the test helper, which is why nothing caught it. Both now source it, and
# test-audit-p0-remediation.R drives every function through this connection.

open_macro_database <- function(root = getwd(), read_only = TRUE) {
  DBI::dbConnect(duckdb::duckdb(), file.path(root, "database", "paraguay_macro_pilot.duckdb"), read_only = read_only)
}

series_latest <- function(con, series_id = NULL) {
  where <- if (is.null(series_id)) "" else paste0(" WHERE series_id = ", sql_string(series_id))
  DBI::dbGetQuery(con, paste0("SELECT * FROM main.v_series_latest", where, " ORDER BY series_id, period"))
}

series_as_of <- function(con, cutoff_date, series_id = NULL) {
  cutoff <- as.character(as.Date(cutoff_date))
  series_filter <- if (is.null(series_id)) "" else paste0(" AND series_id = ", sql_string(series_id))
  DBI::dbGetQuery(con, paste0(
    "WITH ranked AS (SELECT *, row_number() OVER (PARTITION BY series_id, period ORDER BY publication_date DESC NULLS LAST, vintage_id DESC) AS rn FROM canonical.fact_series_events WHERE publication_date <= ",
    sql_string(cutoff), series_filter,
    ") SELECT series_id, period, value, vintage_id, publication_date, source_file FROM ranked WHERE rn = 1 AND NOT is_deleted ORDER BY series_id, period"
  ))
}

series_revision_history <- function(con, series_id = NULL) {
  where <- if (is.null(series_id)) "" else paste0(" WHERE series_id = ", sql_string(series_id))
  DBI::dbGetQuery(con, paste0("SELECT * FROM canonical.series_revisions", where, " ORDER BY series_id, period, publication_date"))
}

series_by_concept <- function(con, concept_id, reviewed_only = TRUE) {
  reviewed_filter <- if (isTRUE(reviewed_only)) " AND mapping_status = 'reviewed'" else ""
  DBI::dbGetQuery(con, paste0(
    "SELECT * FROM main.v_concept_latest WHERE concept_id = ", sql_string(concept_id),
    reviewed_filter, " ORDER BY period, source_id, series_id"
  ))
}

concept_catalogue <- function(con, reviewed_only = FALSE) {
  where <- if (isTRUE(reviewed_only)) " WHERE mapping_status = 'reviewed'" else ""
  DBI::dbGetQuery(con, paste0(
    "SELECT * FROM main.v_series_concept_catalogue", where,
    " ORDER BY concept_domain, concept_id, source_id, series_id"
  ))
}
