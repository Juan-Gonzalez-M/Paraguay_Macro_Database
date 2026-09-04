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
# test-semantic-and-ingestion-contracts.R drives every function through this connection.

open_macro_database <- function(root = getwd(), read_only = TRUE) {
  DBI::dbConnect(duckdb::duckdb(), file.path(root, "database", "paraguay_macro_pilot.duckdb"), read_only = read_only)
}

series_latest <- function(con, series_id = NULL) {
  where <- if (is.null(series_id)) "" else paste0(" WHERE series_id = ", sql_string(series_id))
  DBI::dbGetQuery(con, paste0("SELECT * FROM main.v_series_latest", where, " ORDER BY series_id, period"))
}

# Delegates to the stored macro rather than reimplementing the query.
#
# This function used to rank `canonical.fact_series_events` directly, which made
# it the one published read path with **no release boundary at all** -- it would
# have returned a staged or blocked vintage, and every projection, to anyone using
# the documented helper. Neither the release lint nor the public-view contract was
# looking at it, because it is an R function rather than a stored object: the same
# class of gap as the audit's R6-01, one layer further out.
#
# It also answered a different question from the macro of the same name. This
# ranked by `publication_date`; `series_as_of_date()` ranks by `available_at`,
# which takes the operator's recorded acquisition time over the publication date
# over first ingestion. Two implementations of "as of" is itself the defect --
# whichever is right, they cannot both be.
series_as_of <- function(con, cutoff_date, series_id = NULL) {
  cutoff <- as.character(as.Date(cutoff_date))
  series_filter <- if (is.null(series_id)) "" else paste0(" WHERE series_id = ", sql_string(series_id))
  DBI::dbGetQuery(con, paste0(
    "SELECT * FROM main.series_as_of_date(DATE ", sql_string(cutoff), ")",
    series_filter, " ORDER BY series_id, period"
  ))
}

# The publisher's statement as of a date, projections included. Named so that
# asking for it is deliberate.
series_statement_as_of <- function(con, cutoff_date, series_id = NULL) {
  cutoff <- as.character(as.Date(cutoff_date))
  series_filter <- if (is.null(series_id)) "" else paste0(" WHERE series_id = ", sql_string(series_id))
  DBI::dbGetQuery(con, paste0(
    "SELECT * FROM main.series_statement_as_of_date(DATE ", sql_string(cutoff), ")",
    series_filter, " ORDER BY series_id, period"
  ))
}

# What the publisher currently says, projections included -- the twin of
# series_latest(), which is realized observations only.
series_publisher_statement <- function(con, series_id = NULL) {
  where <- if (is.null(series_id)) "" else paste0(" WHERE series_id = ", sql_string(series_id))
  DBI::dbGetQuery(con, paste0(
    "SELECT * FROM main.v_publisher_statement_latest", where, " ORDER BY series_id, period"
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
