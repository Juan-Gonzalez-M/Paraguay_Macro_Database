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

# --- The research extraction interface ---------------------------------------
# The audit's ER-05. series_latest() answers "what is the current value" and
# returns seven columns to answer it; this answers "what is this number, and may
# I put it in a regression", which needs the label, the published table title,
# the normalized period bounds, the unit, the scale and the review status.

# The join key a frequency-compatible sample is built on. Named as a constant
# because both the helper below and its error message have to agree about what
# the safe answer is.
RESEARCH_PERIOD_KEYS <- c("period_start", "period_end")

# Coarsest last. Aligning frequencies can only ever go this way: a monthly
# series can be summarised to a quarter, and a quarterly one cannot be split
# into months without inventing the two that were never published.
RESEARCH_FREQUENCY_ORDER <- c(
  "daily", "irregular_daily", "monthly_survey", "monthly", "quarterly", "semiannual", "annual"
)

# What a caller has to say before this function will combine frequencies. There
# is no default and no "sensible" choice: a quarterly figure built from monthly
# data is a sum if the series is a flow, an average if it is a rate and the last
# observation if it is a stock, and picking one silently would put an arbitrary
# economic assumption inside a data-access helper.
RESEARCH_AGGREGATION_RULES <- list(
  period_total    = function(x) if (all(is.na(x))) NA_real_ else sum(x, na.rm = TRUE),
  period_average  = function(x) if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE),
  end_of_period   = function(x) if (all(is.na(x))) NA_real_ else utils::tail(x[!is.na(x)], 1L),
  start_of_period = function(x) if (all(is.na(x))) NA_real_ else utils::head(x[!is.na(x)], 1L)
)

# The floor of a date in the target frequency's own calendar, which is what makes
# the aligned key comparable with a natively published one: a monthly series
# summarised to quarters lands on the same period_start the publisher's own
# quarterly series carries.
research_frequency_floor <- function(dates, frequency) {
  unit <- switch(
    frequency,
    annual = "year", semiannual = "halfyear", quarterly = "quarter",
    monthly = , monthly_survey = "month", "day"
  )
  lubridate::floor_date(as.Date(dates), unit = unit)
}

series_research <- function(con, series_id = NULL, concept_id = NULL, label = NULL) {
  filters <- character()
  if (!is.null(series_id)) filters <- c(filters, paste0(
    "series_id IN (", paste(vapply(series_id, sql_string, character(1)), collapse = ", "), ")"
  ))
  if (!is.null(concept_id)) {
    # A concept is a reviewed statement that several series measure the same
    # thing. Resolving one is therefore a lookup in the mapping register, not a
    # pattern match, and an unreviewed mapping does not resolve.
    #
    # Through the published catalogue view, not canonical.map_series_concept.
    # Reading the base table would put a release boundary the whole file exists
    # to respect one function call out of reach -- the same gap, one layer out,
    # that test-release-isolation.R was written for after series_as_of() was
    # found ranking canonical.fact_series_events directly.
    mapped <- DBI::dbGetQuery(con, paste0(
      "SELECT series_id FROM main.v_series_concept_catalogue WHERE concept_id IN (",
      paste(vapply(concept_id, sql_string, character(1)), collapse = ", "),
      ") AND mapping_status = 'reviewed'"
    ))$series_id
    if (!length(mapped)) stop(
      "No reviewed series is mapped to concept ", paste(concept_id, collapse = ", "),
      ". concept_catalogue(con) lists the mappings that exist.", call. = FALSE
    )
    filters <- c(filters, paste0(
      "series_id IN (", paste(vapply(mapped, sql_string, character(1)), collapse = ", "), ")"
    ))
  }
  if (!is.null(label)) {
    # Label search discovers; it does not select.
    #
    # 4,015 of the 7,229 scalar series share a label with another series, and
    # `PIB a precios de comprador` names thirteen of them across thirteen
    # worksheets -- two of which are indistinguishable on every field except the
    # published table title. A helper that quietly returned the first match would
    # be returning current prices where the caller meant constant, with nothing
    # in the result to say so. So an ambiguous label is an error that names the
    # candidates and the title that separates them.
    candidates <- DBI::dbGetQuery(con, paste0(
      "SELECT DISTINCT series_id, source_id, source_sheet, table_title, unit_code, frequency",
      " FROM main.v_series_research WHERE label = ", sql_string(label), " ORDER BY series_id"
    ))
    if (!nrow(candidates)) stop(
      "No series is labelled ", sql_string(label), ".", call. = FALSE
    )
    if (nrow(candidates) > 1L) stop(
      "The label ", sql_string(label), " names ", nrow(candidates), " series, so it cannot select ",
      "one. Pass series_id = one of:\n",
      paste0(
        "  ", candidates$series_id, "  [", candidates$source_sheet, "; ",
        candidates$unit_code, "; ", candidates$frequency, "] ",
        substr(ifelse(is.na(candidates$table_title), "", candidates$table_title), 1, 90),
        collapse = "\n"
      ),
      call. = FALSE
    )
    filters <- c(filters, paste0("series_id = ", sql_string(candidates$series_id[[1]])))
  }
  where <- if (!length(filters)) "" else paste0(" WHERE ", paste(filters, collapse = " AND "))
  DBI::dbGetQuery(con, paste0(
    "SELECT * FROM main.v_series_research", where, " ORDER BY series_id, period_start, period"
  ))
}

# One column per series, one row per period -- the shape an estimation needs,
# with the join it rests on stated rather than guessed.
#
# `key` has no default on purpose. The audit's first blocker is that joining two
# monthly series on the date the publisher printed returns an empty sample
# without an error: 2,057 monthly series are dated to the last day of the month
# and 1,757 to the first, so the price index and the exchange rate share 378
# months and zero dates. A helper that picked a key for the caller would be
# making exactly the choice that went wrong, silently, one level further in.
series_wide <- function(con, series_ids, key, aggregate = NULL) {
  if (missing(key) || !is.character(key) || length(key) != 1L) stop(
    "series_wide() requires an explicit `key`. Use one of: ",
    paste(RESEARCH_PERIOD_KEYS, collapse = ", "),
    ". The key is the join convention the sample rests on and this function will not choose it ",
    "for you.", call. = FALSE
  )
  if (identical(key, "period")) stop(
    "`period` is the date the publisher printed, not a join key. Monthly series in this database ",
    "do not share a day convention -- 2,057 are dated to month end, 1,757 to day 1, and 164 ",
    "alternate inside a single series -- so joining on it returns a silently incomplete or empty ",
    "sample. Use key = \"period_start\" (or \"period_end\"), which normalise to the same interval ",
    "whichever day the source used. See docs/TEMPORAL_CONTRACT.md.", call. = FALSE
  )
  if (!key %in% RESEARCH_PERIOD_KEYS) stop(
    "Unknown key ", sql_string(key), ". Use one of: ",
    paste(RESEARCH_PERIOD_KEYS, collapse = ", "), ".", call. = FALSE
  )
  if (!length(series_ids)) stop("series_wide() needs at least one series_id.", call. = FALSE)
  long <- series_research(con, series_id = series_ids)
  missing_ids <- setdiff(series_ids, unique(long$series_id))
  if (length(missing_ids)) stop(
    "No published observation for: ", paste(missing_ids, collapse = ", "),
    ". A pivot that silently dropped a requested series would produce a narrower sample than the ",
    "caller asked for.", call. = FALSE
  )
  frequencies <- unique(long$frequency)
  if (length(frequencies) > 1L && is.null(aggregate)) stop(
    "The requested series span ", length(frequencies), " frequencies (",
    paste(frequencies, collapse = ", "), "). Aligning them is an economic decision -- a quarterly ",
    "figure built from monthly data is a sum if the series is a flow, an average if it is a rate ",
    "and the last observation if it is a stock -- and this function will not choose for you. Pass ",
    "aggregate = one of \"", paste(names(RESEARCH_AGGREGATION_RULES), collapse = "\", \""),
    "\", or request one frequency at a time.", call. = FALSE
  )
  aligned_to <- NULL
  if (length(frequencies) > 1L) {
    if (!is.character(aggregate) || length(aggregate) != 1L ||
        !aggregate %in% names(RESEARCH_AGGREGATION_RULES)) stop(
      "Unknown aggregate rule. Use one of: ",
      paste(names(RESEARCH_AGGREGATION_RULES), collapse = ", "), ".", call. = FALSE
    )
    unknown <- setdiff(frequencies, RESEARCH_FREQUENCY_ORDER)
    if (length(unknown)) stop(
      "Cannot align frequency ", paste(unknown, collapse = ", "),
      ": it has no declared position in the frequency order, so which direction is coarser is ",
      "undefined.", call. = FALSE
    )
    aligned_to <- RESEARCH_FREQUENCY_ORDER[max(match(frequencies, RESEARCH_FREQUENCY_ORDER))]
    rule <- RESEARCH_AGGREGATION_RULES[[aggregate]]
    long <- long[order(long$series_id, long$period_start, long$period), , drop = FALSE]
    long[[key]] <- research_frequency_floor(long[[key]], aligned_to)
    long <- stats::aggregate(
      list(value = long$value), by = list(series_id = long$series_id, key = long[[key]]), FUN = rule
    )
    names(long)[names(long) == "key"] <- key
    long$frequency <- aligned_to
  }
  duplicated_keys <- long[duplicated(long[c("series_id", key)]), , drop = FALSE]
  if (nrow(duplicated_keys)) stop(
    nrow(duplicated_keys), " observation(s) share a series and a normalised period, so a column ",
    "cannot be built from them without choosing between values. Affected series: ",
    paste(unique(duplicated_keys$series_id), collapse = ", "), call. = FALSE
  )
  wide <- stats::reshape(
    long[c("series_id", key, "value")], idvar = key, timevar = "series_id", direction = "wide"
  )
  names(wide) <- sub("^value\\.", "", names(wide))
  wide <- wide[order(wide[[key]]), , drop = FALSE]
  rownames(wide) <- NULL
  # Requested order, not whatever the reshape produced.
  wide <- wide[c(key, intersect(series_ids, names(wide)))]
  # What the sample rests on, attached to the sample. A frozen research input has
  # to record its join convention and any alignment rule, and the easiest place
  # for that to be lost is between this call and the write-up.
  attr(wide, "period_key") <- key
  attr(wide, "aggregated_to") <- aligned_to
  attr(wide, "aggregation_rule") <- if (is.null(aligned_to)) NULL else aggregate
  wide
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

# --- Schema-41 governed research API ---------------------------------------
# A research_series_id is either a reviewed canonical concept or, where no safe
# cross-source mapping exists, the certified source identity itself.
research_catalogue <- function(con, canonical_series_id = NULL) {
  where <- if (is.null(canonical_series_id)) "" else paste0(
    " WHERE research_series_id IN (",
    paste(vapply(canonical_series_id, sql_string, character(1)), collapse = ", "), ")"
  )
  DBI::dbGetQuery(con, paste0(
    "SELECT * FROM research.series_catalog", where,
    " ORDER BY research_series_id"
  ))
}

research_observations <- function(con, canonical_series_id = NULL,
                                  include_projections = FALSE) {
  object <- if (isTRUE(include_projections)) {
    "research.observations_latest_statement"
  } else {
    "research.observations_latest_actual"
  }
  where <- if (is.null(canonical_series_id)) "" else paste0(
    " WHERE research_series_id IN (",
    paste(vapply(canonical_series_id, sql_string, character(1)), collapse = ", "), ")"
  )
  DBI::dbGetQuery(con, paste0(
    "SELECT * FROM ", object, where,
    " ORDER BY research_series_id, reference_period_start, source_period_date"
  ))
}

research_observations_as_of <- function(con, cutoff, research_series_id = NULL) {
  where <- if (is.null(research_series_id)) "" else paste0(
    " WHERE research_series_id IN (",
    paste(vapply(research_series_id, sql_string, character(1)), collapse = ", "), ")"
  )
  DBI::dbGetQuery(con, paste0(
    "SELECT * FROM research.observations_as_of(", sql_string(as.character(cutoff)),
    ")", where, " ORDER BY research_series_id, reference_period_start"
  ))
}

research_quality_flags <- function(con, series_id = NULL) {
  where <- if (is.null(series_id)) "" else paste0(
    " WHERE series_id IN (",
    paste(vapply(series_id, sql_string, character(1)), collapse = ", "), ")"
  )
  DBI::dbGetQuery(con, paste0(
    "SELECT * FROM research.quality_flags", where,
    " ORDER BY severity DESC, check_name, source_id, source_sheet, series_id, period"
  ))
}

# --- Preliminary discovery and retrieval -----------------------------------

preliminary_search <- function(con, text = NULL, source_id = NULL, frequency = NULL,
                               domain = NULL, formal_only = FALSE) {
  filters <- character()
  if (!is.null(text)) filters <- c(filters, paste0(
    "lower(concat_ws(' ',researcher_name,original_source_label,full_series_path,table_title)) LIKE ",
    sql_string(paste0("%", tolower(text), "%"))
  ))
  add_in <- function(column, values) paste0(
    column, " IN (", paste(vapply(values, sql_string, character(1)), collapse = ","), ")"
  )
  if (!is.null(source_id)) filters <- c(filters, add_in("source_id", source_id))
  if (!is.null(frequency)) filters <- c(filters, add_in("frequency", frequency))
  if (!is.null(domain)) filters <- c(filters, add_in("domain", domain))
  if (isTRUE(formal_only)) filters <- c(filters, "usability_level='formal'")
  where <- if (length(filters)) paste0(" WHERE ", paste(filters, collapse = " AND ")) else ""
  DBI::dbGetQuery(con, paste0(
    "SELECT * FROM catalog.series", where,
    " ORDER BY source_id,researcher_name,candidate_id"
  ))
}

preliminary_observations <- function(con, candidate_id, accept_warnings = FALSE,
                                     formal_only = FALSE) {
  if (!length(candidate_id)) stop("At least one candidate_id is required.", call. = FALSE)
  ids <- paste(vapply(candidate_id, sql_string, character(1)), collapse = ",")
  profiles <- DBI::dbGetQuery(con, paste0(
    "SELECT candidate_id,usability_level,warning_codes,observation_interface ",
    "FROM catalog.series WHERE candidate_id IN (", ids, ")"
  ))
  missing <- setdiff(candidate_id, profiles$candidate_id)
  if (length(missing)) stop("Unknown candidate_id: ", paste(missing, collapse = ", "), call. = FALSE)
  if (isTRUE(formal_only) && any(profiles$usability_level != "formal")) stop(
    "formal_only=TRUE rejects non-formal candidates: ",
    paste(profiles$candidate_id[profiles$usability_level != "formal"], collapse = ", "), call. = FALSE
  )
  preliminary <- profiles$usability_level == "preliminary_with_warnings"
  if (any(preliminary) && !isTRUE(accept_warnings)) stop(
    "Preliminary candidates require accept_warnings=TRUE after inspecting catalog.series warnings: ",
    paste(profiles$candidate_id[preliminary], collapse = ", "), call. = FALSE
  )
  unsupported <- !profiles$observation_interface %in% c(
    "explore.observations", "research.observations_latest_actual"
  )
  if (any(unsupported)) stop(
    "Requested candidates require a native-grain interface: ",
    paste(profiles$candidate_id[unsupported], collapse = ", "), call. = FALSE
  )
  DBI::dbGetQuery(con, paste0(
    "SELECT * FROM explore.observations WHERE candidate_id IN (", ids, ") ",
    "ORDER BY candidate_id,reference_period_start,source_period_date"
  ))
}

preliminary_wide <- function(con, candidate_id, key = "reference_period_start",
                             accept_warnings = FALSE, formal_only = FALSE) {
  allowed <- c("reference_period_start", "reference_period_end")
  if (!key %in% allowed) stop("key must be reference_period_start or reference_period_end.", call. = FALSE)
  long <- preliminary_observations(
    con, candidate_id, accept_warnings = accept_warnings, formal_only = formal_only
  )
  frequencies <- unique(long$frequency)
  if (length(frequencies) != 1L) stop(
    "Cannot silently join incompatible frequencies: ", paste(frequencies, collapse = ", "), call. = FALSE
  )
  if (anyDuplicated(long[c("candidate_id", key)])) stop(
    "The requested series are not unique at the selected normalized-period key.", call. = FALSE
  )
  wide <- stats::reshape(
    long[c("candidate_id", key, "value")], idvar = key, timevar = "candidate_id",
    direction = "wide"
  )
  names(wide) <- sub("^value\\.", "", names(wide))
  wide[order(wide[[key]]), c(key, intersect(candidate_id, names(wide))), drop = FALSE]
}

preliminary_family_ranking <- function(
    con,
    assumptions = list(
      fixed_hours = 1.5, per_series = 0.03, unresolved_unit = 0.06,
      ambiguous_time = 0.12, positional_identity = 0.08, collision = 0.50,
      overlap = 0.04, unknown_transformation = 0.04, methodology = 0.05,
      hierarchy = 0.03, specialized_structure = 0.05,
      incomplete_reconciliation = 0.08, parser_error = 1.00,
      structured_metadata_reward = 0.005, semantic_identity_reward = 0.005,
      reconciliation_reward = 0.005, explicit_dimension_reward = 0.005
    )) {
  defaults <- formals(preliminary_family_ranking)$assumptions
  defaults <- eval(defaults)
  unknown <- setdiff(names(assumptions), names(defaults))
  if (length(unknown)) stop("Unknown effort assumption(s): ", paste(unknown, collapse = ", "), call. = FALSE)
  a <- utils::modifyList(defaults, assumptions)
  if (any(!vapply(a, is.numeric, logical(1))) || any(unlist(a) < 0)) stop(
    "Effort assumptions must be non-negative numeric scalars.", call. = FALSE
  )
  x <- DBI::dbGetQuery(con, "SELECT * FROM catalog.family_readiness")
  penalty <- a$per_series * x$additional_releasable_series +
    a$unresolved_unit * x$unresolved_units + a$ambiguous_time * x$ambiguous_time +
    a$positional_identity * x$positional_ids + a$collision * x$collisions +
    a$overlap * x$overlap_series + a$unknown_transformation * x$unknown_transformations +
    a$methodology * x$methodology_uncertainty + a$hierarchy * x$complex_hierarchy +
    a$specialized_structure * x$specialized_series +
    a$incomplete_reconciliation * x$incomplete_reconciliation + a$parser_error * x$parser_errors
  reward <- a$structured_metadata_reward * x$structured_metadata +
    a$semantic_identity_reward * x$semantic_ids +
    a$reconciliation_reward * x$reconciled_series +
    a$explicit_dimension_reward * x$explicit_dimensions
  x$estimated_fixed_hours <- a$fixed_hours
  x$estimated_variable_hours <- pmax(0, penalty - reward)
  x$estimated_total_hours <- x$estimated_fixed_hours + x$estimated_variable_hours
  x$releasable_series_per_hour <- x$additional_releasable_series / x$estimated_total_hours
  x$effort_assumptions <- paste(names(a), unlist(a), sep = "=", collapse = ";")
  x[order(-x$releasable_series_per_hour, x$family), , drop = FALSE]
}
