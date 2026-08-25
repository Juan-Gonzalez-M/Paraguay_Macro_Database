open_macro_database <- function(root = getwd(), read_only = TRUE) {
  DBI::dbConnect(duckdb::duckdb(), file.path(root, "database", "paraguay_macro_pilot.duckdb"), read_only = read_only)
}

series_latest <- function(con, series_id = NULL) {
  where <- if (is.null(series_id)) "" else paste0(" WHERE series_id = ", sql_string(series_id))
  DBI::dbGetQuery(con, paste0("SELECT * FROM v_series_latest", where, " ORDER BY series_id, period"))
}

series_as_of <- function(con, cutoff_date, series_id = NULL) {
  cutoff <- as.character(as.Date(cutoff_date))
  series_filter <- if (is.null(series_id)) "" else paste0(" AND series_id = ", sql_string(series_id))
  DBI::dbGetQuery(con, paste0(
    "WITH ranked AS (SELECT *, row_number() OVER (PARTITION BY series_id, period ORDER BY publication_date DESC NULLS LAST, vintage_id DESC) AS rn FROM fact_series_events WHERE publication_date <= ",
    sql_string(cutoff), series_filter,
    ") SELECT series_id, period, value, vintage_id, publication_date, source_file FROM ranked WHERE rn = 1 AND NOT is_deleted ORDER BY series_id, period"
  ))
}

series_revision_history <- function(con, series_id = NULL) {
  where <- if (is.null(series_id)) "" else paste0(" WHERE series_id = ", sql_string(series_id))
  DBI::dbGetQuery(con, paste0("SELECT * FROM series_revisions", where, " ORDER BY series_id, period, publication_date"))
}

series_by_concept <- function(con, concept_id, reviewed_only = TRUE) {
  reviewed_filter <- if (isTRUE(reviewed_only)) " AND mapping_status = 'reviewed'" else ""
  DBI::dbGetQuery(con, paste0(
    "SELECT * FROM v_concept_latest WHERE concept_id = ", sql_string(concept_id),
    reviewed_filter, " ORDER BY period, source_id, series_id"
  ))
}

concept_catalogue <- function(con, reviewed_only = FALSE) {
  where <- if (isTRUE(reviewed_only)) " WHERE mapping_status = 'reviewed'" else ""
  DBI::dbGetQuery(con, paste0(
    "SELECT * FROM v_series_concept_catalogue", where,
    " ORDER BY concept_domain, concept_id, source_id, series_id"
  ))
}
