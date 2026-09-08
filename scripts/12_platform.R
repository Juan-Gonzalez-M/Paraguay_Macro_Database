# --- Schema 40: governed research platform ---------------------------------

MISSINGNESS_CONTRACT_TYPES <- c(
  "regular_calendar", "event_structural_absence", "panel_conditional", "observed_only"
)
PANEL_RESOLUTION_DISPOSITIONS <- c(
  "canonical_row", "exact_duplicate", "measure_split", "quarantine"
)
CANONICAL_VALUE_RELATIONSHIPS <- c(
  "primary", "replica", "historical_segment", "methodology_break", "alias",
  "spliced_predecessor"
)

platform_table_columns <- function(con, table_name) {
  DBI::dbGetQuery(con, paste0(
    "SELECT column_name FROM information_schema.columns WHERE table_schema = ",
    sql_string(project_schema_for(table_name)), " AND table_name = ", sql_string(table_name),
    " ORDER BY ordinal_position"
  ))$column_name
}

initialize_platform_contracts <- function(con) {
  DBI::dbExecute(con, "CREATE SCHEMA IF NOT EXISTS research")
  if (database_object_exists(con, "dim_series")) {
    DBI::dbExecute(con, paste(
      "UPDATE", project_qualified_name("dim_series"),
      "SET source_label = coalesce(source_label, label)"
    ))
    if (database_object_exists(con, "documented_series_snapshot") &&
        "series_path" %in% platform_table_columns(con, "documented_series_snapshot")) {
      DBI::dbExecute(con, paste(
        "UPDATE", project_qualified_name("dim_series"), "d SET full_series_path = x.series_path",
        "FROM (SELECT series_id, any_value(series_path) AS series_path",
        "      FROM", project_qualified_name("documented_series_snapshot"),
        "      GROUP BY 1 HAVING count(DISTINCT series_path) = 1) x",
        "WHERE x.series_id = d.series_id AND d.full_series_path IS NULL"
      ))
    }
  }
  if (database_object_exists(con, "source_provenance")) {
    DBI::dbExecute(con, paste(
      "UPDATE", project_qualified_name("source_provenance"), "p SET snapshot_policy = CASE",
      "WHEN availability_quality = 'inferred_upper_bound' THEN 'legacy_current_snapshot_only'",
      "WHEN (SELECT count(*) FROM", project_qualified_name("source_provenance"),
      "      q WHERE q.source_id = p.source_id AND q.sha256 <> p.sha256) > 0",
      "  THEN 'release_history' ELSE 'verified_current_snapshot' END"
    ))
  }
  invisible(TRUE)
}

read_missingness_contracts <- function(root) {
  required <- c(
    "source_id", "source_sheet", "contract_type", "calendar_frequency", "applicability",
    "evidence", "reviewed_by", "reviewed_at"
  )
  rows <- readr::read_csv(
    file.path(root, "config", "missingness_contracts.csv"),
    col_types = readr::cols(.default = readr::col_character())
  )
  if (!identical(names(rows), required)) stop(
    "Missingness contract columns changed or are reordered.", call. = FALSE
  )
  if (anyDuplicated(rows[c("source_id", "source_sheet")])) stop(
    "Missingness contracts contain duplicate source/sheet rows.", call. = FALSE
  )
  invalid <- setdiff(unique(rows$contract_type), MISSINGNESS_CONTRACT_TYPES)
  if (length(invalid)) stop(
    "Unsupported missingness contract type: ", paste(invalid, collapse = "; "), call. = FALSE
  )
  required_text <- c(
    "source_id", "source_sheet", "contract_type", "applicability", "evidence", "reviewed_by"
  )
  incomplete <- apply(rows[required_text], 1, function(row) {
    any(is.na(row) | !nzchar(trimws(as.character(row))))
  })
  dates <- suppressWarnings(lubridate::ymd(rows$reviewed_at, quiet = TRUE))
  if (any(incomplete | is.na(dates) | dates > Sys.Date())) stop(
    "Missingness contracts require evidence, a reviewer, and a valid non-future review date.",
    call. = FALSE
  )
  regular <- rows$contract_type == "regular_calendar"
  if (any(regular & (is.na(rows$calendar_frequency) |
                     !nzchar(trimws(rows$calendar_frequency)) |
                     rows$calendar_frequency == "not_applicable"))) stop(
    "Regular-calendar missingness contracts require a calendar_frequency.", call. = FALSE
  )
  rows
}

apply_missingness_contracts <- function(con, root) {
  rows <- read_missingness_contracts(root)
  registered <- readr::read_csv(
    file.path(root, "config", "source_registry.csv"), show_col_types = FALSE
  )$source_id
  unknown <- setdiff(rows$source_id, registered)
  if (length(unknown)) stop(
    "Missingness contract names unknown source(s): ", paste(unknown, collapse = "; "),
    call. = FALSE
  )
  undeclared <- setdiff(registered, rows$source_id[rows$source_sheet == "*"])
  if (length(undeclared)) stop(
    "Missingness contract is absent for source(s): ", paste(undeclared, collapse = "; "),
    call. = FALSE
  )
  stored <- rows %>% dplyr::transmute(
    source_id, source_sheet, contract_type,
    calendar_frequency = dplyr::na_if(.data$calendar_frequency, "not_applicable"),
    applicability, evidence, reviewed_by,
    reviewed_at = suppressWarnings(lubridate::ymd(.data$reviewed_at, quiet = TRUE))
  )
  replace_table_if_changed(con, "missingness_contracts", stored)
  invisible(nrow(stored))
}

apply_panel_resolution <- function(con, root) {
  required <- c(
    "resolution_id", "table_name", "source_sheet", "source_row", "disposition", "measure",
    "canonical_source_row", "evidence", "reviewed_by", "reviewed_at"
  )
  rows <- readr::read_csv(
    file.path(root, "config", "panel_resolution.csv"),
    col_types = readr::cols(.default = readr::col_character())
  )
  if (!identical(names(rows), required)) stop(
    "Panel resolution columns changed or are reordered.", call. = FALSE
  )
  if (nrow(rows)) {
    invalid <- setdiff(unique(rows$disposition), PANEL_RESOLUTION_DISPOSITIONS)
    if (length(invalid)) stop(
      "Unsupported panel resolution disposition: ", paste(invalid, collapse = "; "),
      call. = FALSE
    )
    if (anyDuplicated(rows$resolution_id)) stop("Duplicate panel resolution_id.", call. = FALSE)
    source_row <- suppressWarnings(as.numeric(rows$source_row))
    if (any(is.na(source_row) | source_row < 1)) stop(
      "Panel resolution source_row must be a positive integer.", call. = FALSE
    )
    required_text <- c(
      "resolution_id", "table_name", "source_sheet", "disposition", "evidence", "reviewed_by"
    )
    incomplete <- apply(rows[required_text], 1, function(row) {
      any(is.na(row) | !nzchar(trimws(as.character(row))))
    })
    dates <- suppressWarnings(lubridate::ymd(rows$reviewed_at, quiet = TRUE))
    if (any(incomplete | is.na(dates) | dates > Sys.Date())) stop(
      "Panel resolutions require evidence, a reviewer, and a valid non-future review date.",
      call. = FALSE
    )
    needs_canonical <- rows$disposition == "exact_duplicate"
    if (any(needs_canonical & (is.na(rows$canonical_source_row) |
                               !nzchar(trimws(rows$canonical_source_row))))) stop(
      "Exact-duplicate panel resolutions require canonical_source_row.", call. = FALSE
    )
    needs_measure <- rows$disposition == "measure_split"
    if (any(needs_measure & (is.na(rows$measure) | !nzchar(trimws(rows$measure))))) stop(
      "Measure-split panel resolutions require measure.", call. = FALSE
    )
  }
  stored <- rows %>% dplyr::transmute(
    resolution_id, table_name, source_sheet,
    source_row = suppressWarnings(as.numeric(.data$source_row)), disposition,
    measure = dplyr::na_if(.data$measure, ""),
    canonical_source_row = suppressWarnings(as.numeric(dplyr::na_if(.data$canonical_source_row, ""))),
    evidence, reviewed_by,
    reviewed_at = suppressWarnings(lubridate::ymd(.data$reviewed_at, quiet = TRUE))
  )
  replace_table_if_changed(con, "panel_resolution", stored)
  invisible(nrow(stored))
}

apply_platform_contracts <- function(con, root) {
  initialize_platform_contracts(con)
  apply_missingness_contracts(con, root)
  apply_panel_resolution(con, root)
  invisible(TRUE)
}

current_quality_flags_sql <- function() paste(
  "SELECT q.* FROM audit.quality_flags q",
  "JOIN audit.data_releases d ON d.attempt_id = q.attempt_id",
  "JOIN audit.active_data_release a ON a.data_release_id = d.data_release_id",
  "WHERE coalesce(q.status, 'open') = 'open'"
)

create_research_views <- function(con) {
  DBI::dbExecute(con, "CREATE SCHEMA IF NOT EXISTS research")
  create_project_view(con, "quality_flags", current_quality_flags_sql(), schema = "research")

  member_carriers <- paste(
    vapply(CANONICAL_VALUE_RELATIONSHIPS, sql_string, character(1)), collapse = ", "
  )
  create_project_view(con, "observations_latest_actual", paste(
    "WITH candidates AS (",
    " SELECT m.canonical_series_id, c.canonical_name, o.series_id AS source_series_id,",
    " o.period AS source_period_date, o.period_start AS reference_period_start,",
    " o.period_end AS reference_period_end, o.value, o.value_in_base_units,",
    " c.frequency, c.unit_code, c.currency, o.vintage_id, o.publication_date,",
    " o.available_at, o.availability_quality, o.observation_status, o.source_id,",
    " o.source_sheet, m.relationship, m.precedence,",
    " row_number() OVER (PARTITION BY m.canonical_series_id, o.period_start",
    "   ORDER BY m.precedence, CASE m.relationship WHEN 'primary' THEN 0 WHEN 'historical_segment' THEN 1 ELSE 2 END, o.series_id) AS member_rank",
    " FROM main.v_series_research o",
    " JOIN marts.v_research_series approved ON approved.series_id = o.series_id",
    " JOIN main.v_canonical_membership m ON m.series_id = o.series_id",
    " JOIN canonical.canonical_series c USING (canonical_series_id)",
    " WHERE c.reviewed_status = 'reviewed'",
    " AND m.relationship IN (", member_carriers, ")",
    " AND (m.valid_from IS NULL OR o.period_start >= m.valid_from)",
    " AND (m.valid_to IS NULL OR o.period_start <= m.valid_to)",
    " AND EXISTS (SELECT 1 FROM audit.active_data_release)",
    ") SELECT * EXCLUDE (member_rank),",
    " (SELECT count(*) FROM research.quality_flags q",
    "   WHERE q.series_id = candidates.source_series_id",
    "      OR (q.series_id IS NULL AND q.source_id = candidates.source_id",
    "          AND (q.source_sheet IS NULL OR q.source_sheet = candidates.source_sheet))) AS flag_count,",
    " (SELECT max(CASE q.severity WHEN 'error' THEN 3 WHEN 'warning' THEN 2 ELSE 1 END)",
    "  FROM research.quality_flags q WHERE q.series_id = candidates.source_series_id",
    "     OR (q.series_id IS NULL AND q.source_id = candidates.source_id",
    "         AND (q.source_sheet IS NULL OR q.source_sheet = candidates.source_sheet))) AS worst_severity_rank",
    " FROM candidates WHERE member_rank = 1"
  ), schema = "research")

  create_project_view(con, "observations_latest_statement", paste(
    "SELECT * FROM research.observations_latest_actual WHERE EXISTS (SELECT 1 FROM audit.active_data_release)",
    "UNION ALL BY NAME",
    "SELECT m.canonical_series_id, c.canonical_name, o.series_id AS source_series_id,",
    " o.period AS source_period_date, o.period_start AS reference_period_start,",
    " o.period_end AS reference_period_end, o.value, o.value_in_base_units,",
    " c.frequency, c.unit_code, c.currency, o.vintage_id, o.publication_date,",
    " o.available_at, p.availability_quality, o.observation_status, o.source_id,",
    " o.source_sheet, m.relationship, m.precedence, 0::BIGINT AS flag_count,",
    " NULL::INTEGER AS worst_severity_rank",
    "FROM main.v_series_observations o",
    "JOIN marts.v_research_series approved ON approved.series_id = o.series_id",
    "JOIN main.v_canonical_membership m ON m.series_id = o.series_id",
    "JOIN canonical.canonical_series c USING (canonical_series_id)",
    "LEFT JOIN raw.source_provenance p USING (vintage_id)",
    "WHERE m.relationship = 'projection' AND o.observation_status <> 'observed'",
    "AND c.reviewed_status = 'reviewed'",
    "AND (m.valid_from IS NULL OR o.period_start >= m.valid_from)",
    "AND (m.valid_to IS NULL OR o.period_start <= m.valid_to)",
    "AND EXISTS (SELECT 1 FROM audit.active_data_release)"
  ), schema = "research")

  create_project_view(con, "series_catalog_approved", paste(
    "SELECT c.*, count(o.reference_period_start) AS observations,",
    "min(o.reference_period_start) AS first_period, max(o.reference_period_end) AS last_period",
    "FROM canonical.canonical_series c",
    "LEFT JOIN research.observations_latest_actual o USING (canonical_series_id)",
    "WHERE c.reviewed_status = 'reviewed' GROUP BY ALL"
  ), schema = "research")

  bank_status <- paste(
    "coalesce((SELECT status FROM audit.table_status t WHERE t.source_id = x.source_id",
    "AND t.source_sheet = x.source_sheet LIMIT 1),",
    "(SELECT status FROM audit.table_status t WHERE t.source_id = x.source_id",
    "AND t.source_sheet = '*' LIMIT 1)) = 'validated'"
  )
  bank_inputs_exist <- all(vapply(
    c("v_banks_eeff_documented", "v_financial_eeff_documented"),
    function(view) database_object_exists(con, view), logical(1)
  ))
  bank_sql <- if (bank_inputs_exist) paste(
      "SELECT x.vintage_id, x.source_id, x.source_sheet, x.source_file, x.fecha AS reference_period,",
      "x.entity_id, x.short_name AS entity_name, x.statement_item_id AS item_id,",
      "x.semantic_classification, x.semantic_rubro, x.semantic_sub_rubro,",
      "x.economic_currency AS currency, 'balance' AS measure, x.importe AS value, x.source_row",
      "FROM (SELECT * FROM main.v_banks_eeff_documented UNION ALL BY NAME",
      "      SELECT * FROM main.v_financial_eeff_documented) x WHERE", bank_status,
      "AND EXISTS (SELECT 1 FROM audit.active_data_release)"
    ) else paste(
      "SELECT NULL::VARCHAR AS vintage_id, NULL::VARCHAR AS source_id,",
      "NULL::VARCHAR AS source_sheet, NULL::VARCHAR AS source_file, NULL::DATE AS reference_period,",
      "NULL::VARCHAR AS entity_id, NULL::VARCHAR AS entity_name, NULL::VARCHAR AS item_id,",
      "NULL::VARCHAR AS semantic_classification, NULL::VARCHAR AS semantic_rubro,",
      "NULL::VARCHAR AS semantic_sub_rubro, NULL::VARCHAR AS currency,",
      "NULL::VARCHAR AS measure, NULL::DOUBLE AS value, NULL::BIGINT AS source_row",
      "WHERE FALSE AND EXISTS (SELECT 1 FROM audit.active_data_release)"
    )
  create_project_view(con, "bank_panel", bank_sql, schema = "research")

  create_event_research_view <- function(name, source_id) create_project_view(con, name, paste(
    "SELECT md5(o.series_id || ':' || cast(o.period AS VARCHAR)) AS event_id,",
    "o.period AS event_date, o.series_id AS source_series_id, d.source_label AS measure_path,",
    "o.value, o.value_in_base_units, o.unit_code, o.vintage_id, o.source_sheet",
    "FROM main.v_series_observations o JOIN canonical.dim_series d USING (series_id)",
    "JOIN marts.v_research_series approved USING (series_id)",
    "WHERE o.source_id =", sql_string(source_id), "AND d.series_grain = 'event'",
    "AND NOT o.is_deleted AND o.observation_status = 'observed'",
    "AND EXISTS (SELECT 1 FROM audit.active_data_release)"
  ), schema = "research")
  create_event_research_view("lrm_auction_events", "lrm_auctions")
  create_event_research_view("interbank_events", "interbank_market")

  reviewed_grain <- function(source) paste0(
    "EXISTS (SELECT 1 FROM audit.source_grains g WHERE g.source_id = ", sql_string(source),
    " AND g.source_sheet = '*' AND g.reviewed_by <> 'unreviewed' AND g.reviewed_at IS NOT NULL) ",
    "AND coalesce((SELECT status FROM audit.table_status t WHERE t.source_id = ", sql_string(source),
    " AND t.source_sheet = '*' LIMIT 1), 'provisional') = 'validated'"
  )
  create_project_view(con, "bond_curves", paste(
    "SELECT * FROM main.v_bond_curves_latest WHERE", reviewed_grain("corporate_bond_curves"),
    "AND EXISTS (SELECT 1 FROM audit.active_data_release)"
  ), schema = "research")
  create_project_view(con, "securities_transactions", paste(
    "SELECT * FROM main.v_securities_transactions_latest WHERE", reviewed_grain("securities_trades"),
    "AND EXISTS (SELECT 1 FROM audit.active_data_release)"
  ), schema = "research")
  invisible(TRUE)
}

validate_platform_contracts <- function(con, release_id, root) {
  contracts <- read_missingness_contracts(root)
  registered <- readr::read_csv(
    file.path(root, "config", "source_registry.csv"), show_col_types = FALSE
  )$source_id
  missing <- setdiff(registered, contracts$source_id[contracts$source_sheet == "*"])
  if (length(missing)) insert_quality_flag(
    con, release_id, "error", "missingness_contract_absent", NA_character_,
    paste("No source-level missingness contract for", paste(missing, collapse = "; "))
  )

  provenance <- DBI::dbGetQuery(con, paste(
    "SELECT * FROM", project_qualified_name("source_provenance")
  ))
  new_policy <- provenance$retrieval_method != "archive_ingest_upper_bound" |
    is.na(provenance$retrieval_method)
  required <- c(
    "official_release_date", "official_url", "release_identifier", "retrieved_at",
    "retrieval_method", "license", "evidence"
  )
  incomplete <- new_policy & apply(provenance[, required, drop = FALSE], 1, function(row) {
    any(is.na(row) | !nzchar(trimws(as.character(row))))
  })
  if (any(incomplete)) insert_quality_flag(
    con, release_id, "error", "new_vintage_provenance_incomplete", NA_character_,
    paste(sum(incomplete), "non-legacy vintage(s) lack mandatory acquisition metadata.")
  )

  members <- DBI::dbGetQuery(con, paste(
    "SELECT * FROM", project_qualified_name("map_canonical_series")
  ))
  if (nrow(members)) {
    carriers <- members[members$relationship %in% CANONICAL_VALUE_RELATIONSHIPS, , drop = FALSE]
    overlap <- merge(carriers, carriers, by = "canonical_series_id", suffixes = c("_x", "_y"))
    overlap <- overlap[
      overlap$series_id_x < overlap$series_id_y & overlap$precedence_x == overlap$precedence_y &
        (is.na(overlap$valid_to_x) | is.na(overlap$valid_from_y) | overlap$valid_to_x >= overlap$valid_from_y) &
        (is.na(overlap$valid_to_y) | is.na(overlap$valid_from_x) | overlap$valid_to_y >= overlap$valid_from_x),
      , drop = FALSE
    ]
    # A primary plus one or more verified replicas may deliberately overlap at
    # equal precedence: equality is tested separately and the primary wins in
    # the research view. Every other equal-precedence overlap is ambiguous.
    if (nrow(overlap)) {
      replica_roles <- c("primary", "alias", "replica")
      verified_replica <- overlap$relationship_x %in% replica_roles &
        overlap$relationship_y %in% replica_roles &
        (overlap$relationship_x == "primary" | overlap$relationship_y == "primary") &
        overlap$overlap_policy_x == "require_equal_then_primary" &
        overlap$overlap_policy_y == "require_equal_then_primary"
      overlap <- overlap[!verified_replica, , drop = FALSE]
    }
    if (nrow(overlap)) insert_quality_flag(
      con, release_id, "error", "canonical_precedence_ambiguous", NA_character_,
      paste(nrow(overlap), "canonical member pair(s) overlap with equal precedence.")
    )
  }
  invisible(TRUE)
}
