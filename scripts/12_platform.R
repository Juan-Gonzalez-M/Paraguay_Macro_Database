# --- Schemas 40-41: governed research platform -----------------------------

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
ASSURANCE_LEVELS <- c(
  "rule_certified", "human_verified", "provisional", "quarantined", "excluded"
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

read_acquisition_contracts <- function(root) {
  required <- c(
    "source_id", "expected_frequency", "acquisition_method", "official_landing_page",
    "license_status", "retention_policy", "provenance_requirement", "point_in_time_status",
    "allowed_uses", "prohibited_uses", "owner", "effective_from"
  )
  rows <- readr::read_csv(
    file.path(root, "config", "acquisition_contracts.csv"),
    col_types = readr::cols(.default = readr::col_character())
  )
  if (!identical(names(rows), required)) stop(
    "Acquisition contract columns changed or are reordered.", call. = FALSE
  )
  if (anyDuplicated(rows$source_id)) stop("Duplicate acquisition source_id.", call. = FALSE)
  text_fields <- setdiff(required, c("official_landing_page", "effective_from"))
  incomplete <- apply(rows[text_fields], 1, function(x) any(is.na(x) | !nzchar(trimws(x))))
  effective <- suppressWarnings(lubridate::ymd(rows$effective_from, quiet = TRUE))
  if (any(incomplete | is.na(effective))) stop(
    "Acquisition contracts require all policy fields and a valid effective_from date.",
    call. = FALSE
  )
  rows$effective_from <- effective
  rows$official_landing_page <- dplyr::na_if(rows$official_landing_page, "")
  rows
}

read_certification_rules <- function(root) {
  required <- c(
    "rule_id", "rule_version", "object_type", "assurance_level", "description", "enabled"
  )
  rows <- readr::read_csv(
    file.path(root, "config", "certification_rules.csv"),
    col_types = readr::cols(.default = readr::col_character())
  )
  if (!identical(names(rows), required) || anyDuplicated(rows[c("rule_id", "rule_version")])) {
    stop("Certification rule contract is invalid.", call. = FALSE)
  }
  if (any(!rows$assurance_level %in% ASSURANCE_LEVELS)) stop(
    "Certification rule uses an unsupported assurance level.", call. = FALSE
  )
  rows$enabled <- tolower(rows$enabled) == "true"
  rows$config_hash <- vapply(seq_len(nrow(rows)), function(i) {
    digest::digest(paste(rows[i, required], collapse = "|"), algo = "sha256", serialize = FALSE)
  }, character(1))
  rows
}

blank_text <- function(x) is.na(x) | !nzchar(trimws(as.character(x)))

apply_rule_certification <- function(con, root, build_id = NA_character_) {
  rules <- read_certification_rules(root)
  contracts <- read_acquisition_contracts(root)
  registry <- readr::read_csv(
    file.path(root, "config", "source_registry.csv"), show_col_types = FALSE
  )
  if (!setequal(registry$source_id, contracts$source_id)) stop(
    "Acquisition contracts must cover every registered source exactly once.", call. = FALSE
  )
  replace_table_if_changed(con, "certification_rules", rules)
  replace_table_if_changed(con, "acquisition_contracts", contracts)

  proposals <- readr::read_csv(
    file.path(root, "config", "proposals", "series_review.csv"),
    col_types = readr::cols(.default = readr::col_character())
  )
  required_semantics <- c(
    "definition", "definition_evidence_uri", "frequency", "reference_period_convention",
    "timing_basis", "stock_flow", "unit_code", "scale_multiplier", "currency", "valuation",
    "nominal_real", "seasonal_adjustment", "transformation", "hierarchy_role", "comparability",
    "proposal_evidence", "source_cell"
  )
  candidate <- proposals$confidence == "high" & blank_text(proposals$open_questions)
  candidate <- candidate & !apply(proposals[required_semantics], 1, function(x) any(blank_text(x)))
  candidate <- candidate & proposals$unit_code != "UNRESOLVED_SOURCE_UNITS" &
    proposals$stock_flow != "not_reviewed" & proposals$nominal_real != "not_reviewed" &
    proposals$seasonal_adjustment != "not_reviewed"
  proposals <- proposals[candidate, , drop = FALSE]

  if (nrow(proposals)) {
    ids <- paste(vapply(proposals$series_id, sql_string, character(1)), collapse = ",")
    dimensions <- DBI::dbGetQuery(con, paste0(
      "SELECT series_id, source_id, series_grain, identity_stability, full_series_path ",
      "FROM canonical.dim_series WHERE series_id IN (", ids, ")"
    ))
    proposals <- merge(proposals, dimensions, by = "series_id")
    proposals <- proposals[
      proposals$series_grain == "scalar_series" & proposals$identity_stability == "semantic" &
        !blank_text(proposals$full_series_path), , drop = FALSE
    ]
  }

  # A source identity is certifiable only when every physical worksheet that
  # contributes to it balances and the identity resolves to one published title.
  if (nrow(proposals)) {
    ids <- paste(vapply(proposals$series_id, sql_string, character(1)), collapse = ",")
    technical <- DBI::dbGetQuery(con, paste0(
      "WITH sheets AS (SELECT DISTINCT series_id, source_id, source_sheet, vintage_id ",
      " FROM staging.documented_series_snapshot WHERE series_id IN (", ids, ")), ",
      "checks AS (SELECT s.series_id, count(*) AS sheet_rows, ",
      " count(*) FILTER (WHERE r.status = 'balanced' AND coalesce(r.balance_delta,0)=0 ",
      " AND coalesce(r.unclassified_cells,0)=0 AND coalesce(r.parser_defect_cells,0)=0) AS good_rows ",
      " FROM sheets s LEFT JOIN audit.table_reconciliation r USING ",
      " (vintage_id, source_id, source_sheet) GROUP BY 1), ",
      "titles AS (SELECT series_id, count(DISTINCT table_title) FILTER (WHERE table_title IS NOT NULL) title_count ",
      " FROM main.v_series_research_all WHERE series_id IN (", ids, ") GROUP BY 1) ",
      "SELECT c.series_id FROM checks c JOIN titles t USING(series_id) ",
      "WHERE c.sheet_rows=c.good_rows AND t.title_count=1"
    ))$series_id
    proposals <- proposals[proposals$series_id %in% technical, , drop = FALSE]
  }

  canonical <- readr::read_csv(
    file.path(root, "config", "proposals", "canonical_series.csv"),
    col_types = readr::cols(.default = readr::col_character())
  )
  members <- readr::read_csv(
    file.path(root, "config", "proposals", "canonical_series_members.csv"),
    col_types = readr::cols(.default = readr::col_character())
  )
  canon_ok <- canonical$confidence == "high" & blank_text(canonical$open_questions) &
    (blank_text(canonical$methodology_regime_id) | canonical$methodology_regime_id == "not_applicable")
  member_ok <- members$confidence == "high" & blank_text(members$open_questions) &
    members$relationship == "primary"
  canonical_candidates <- canonical[
    canon_ok, c("canonical_series_id", "proposal_evidence", "source_cell"), drop = FALSE
  ]
  names(canonical_candidates)[2:3] <- c("canonical_proposal_evidence", "canonical_source_cell")
  mappings <- merge(
    canonical_candidates,
    members[member_ok, c("canonical_series_id", "series_id"), drop = FALSE],
    by = "canonical_series_id"
  )
  mappings <- mappings[mappings$series_id %in% proposals$series_id, , drop = FALSE]
  proposals <- merge(proposals, mappings, by = "series_id", all.x = TRUE)
  proposals$research_series_id <- ifelse(
    blank_text(proposals$canonical_series_id), proposals$series_id, proposals$canonical_series_id
  )
  proposals$canonical_name <- proposals$canonical_series_id
  rule_version <- rules$rule_version[rules$rule_id == "proposal_high_no_open"][[1]]
  certified_at <- as.POSIXct(Sys.time(), tz = "UTC")
  if (nrow(proposals)) {
    proposals$evidence_hash <- vapply(seq_len(nrow(proposals)), function(i) digest::digest(
      paste(proposals[i, c("series_id", required_semantics)], collapse = "|"),
      algo = "sha256", serialize = FALSE
    ), character(1))
  } else proposals$evidence_hash <- character()
  stored <- proposals %>% dplyr::transmute(
    series_id, research_series_id, canonical_name, definition, definition_evidence_uri,
    frequency, reference_period_convention, timing_basis, stock_flow, unit_code,
    scale_multiplier = as.numeric(.data$scale_multiplier), currency, valuation, nominal_real,
    price_base_year = dplyr::na_if(.data$price_base_year, ""), seasonal_adjustment,
    transformation, hierarchy_role, parent_series_id = dplyr::na_if(.data$parent_series_id, ""),
    methodology_regime_id = dplyr::na_if(.data$methodology_regime_id, ""), comparability,
    assurance_level = "rule_certified", certification_rule_id = "proposal_high_no_open",
    certification_rule_version = rule_version, evidence_hash, certified_at = certified_at
  )
  DBI::dbExecute(con, "DELETE FROM canonical.rule_certified_series")
  if (nrow(stored)) DBI::dbAppendTable(
    con, DBI::Id(schema = "canonical", table = "rule_certified_series"), stored
  )

  decision_ids <- vapply(seq_len(nrow(stored)), function(i) digest::digest(
    paste("series", stored$series_id[[i]], stored$evidence_hash[[i]], build_id, sep = "|"),
    algo = "sha256", serialize = FALSE
  ), character(1))
  decisions <- stored %>% dplyr::transmute(
    decision_id = decision_ids,
    object_type = "series", object_id = series_id, assurance_level,
    rule_id = certification_rule_id, rule_version = certification_rule_version,
    evidence_uri = definition_evidence_uri, evidence_hash,
    rationale = "All deterministic proposal, semantic-identity and worksheet-reconciliation gates passed; this is automated assurance, not human review.",
    decided_at = certified_at, build_id = as.character(build_id)
  )
  if (nrow(decisions)) {
    existing <- DBI::dbGetQuery(con, "SELECT decision_id FROM canonical.certification_decisions")$decision_id
    decisions <- decisions[!decisions$decision_id %in% existing, , drop = FALSE]
    if (nrow(decisions)) DBI::dbAppendTable(
      con, DBI::Id(schema = "canonical", table = "certification_decisions"), decisions
    )
  }
  if (nrow(mappings)) {
    canonical_rule_version <- rules$rule_version[
      rules$rule_id == "canonical_high_no_dependency"
    ][[1]]
    canonical_decisions <- mappings %>% dplyr::transmute(
      object_type = "canonical_series", object_id = canonical_series_id,
      assurance_level = "rule_certified", rule_id = "canonical_high_no_dependency",
      rule_version = canonical_rule_version, evidence_uri = canonical_source_cell,
      evidence_hash = vapply(seq_len(nrow(mappings)), function(i) digest::digest(
        paste(mappings$canonical_series_id[[i]], mappings$series_id[[i]],
              mappings$canonical_proposal_evidence[[i]], sep = "|"),
        algo = "sha256", serialize = FALSE
      ), character(1)),
      rationale = "Canonical and membership proposals are high confidence, have no open question, require no unsigned methodology regime, and the source series is rule-certified.",
      decided_at = certified_at, build_id = as.character(build_id)
    )
    canonical_decisions$decision_id <- vapply(seq_len(nrow(canonical_decisions)), function(i) {
      digest::digest(paste(
        "canonical_series", canonical_decisions$object_id[[i]],
        canonical_decisions$evidence_hash[[i]], build_id, sep = "|"
      ), algo = "sha256", serialize = FALSE)
    }, character(1))
    canonical_decisions <- canonical_decisions[c(
      "decision_id", "object_type", "object_id", "assurance_level", "rule_id", "rule_version",
      "evidence_uri", "evidence_hash", "rationale", "decided_at", "build_id"
    )]
    existing <- DBI::dbGetQuery(con, "SELECT decision_id FROM canonical.certification_decisions")$decision_id
    canonical_decisions <- canonical_decisions[
      !canonical_decisions$decision_id %in% existing, , drop = FALSE
    ]
    if (nrow(canonical_decisions)) DBI::dbAppendTable(
      con, DBI::Id(schema = "canonical", table = "certification_decisions"), canonical_decisions
    )
  }

  grain <- DBI::dbGetQuery(con, paste(
    "SELECT source_id, any_value(series_grain) AS grain FROM audit.source_grains",
    "WHERE source_sheet='*' GROUP BY 1"
  ))
  catalog <- merge(registry, contracts, by = "source_id", all.x = TRUE)
  catalog <- merge(catalog, grain, by = "source_id", all.x = TRUE)
  certified_source_ids <- unique(proposals$source_id)
  structural <- catalog$source_id %in% c("corporate_bond_curves", "securities_trades")
  catalog$assurance_level <- ifelse(
    catalog$source_id %in% certified_source_ids | structural, "rule_certified", "provisional"
  )
  catalog$disposition_reason <- ifelse(
    structural, "Long-format rows pass explicit parser accounting; assurance covers structure only.",
    ifelse(catalog$source_id %in% certified_source_ids,
      "At least one scalar series passes the automated semantic and reconciliation rule; other rows remain provisional.",
      ifelse(catalog$source_id %in% c("banks", "financial"),
        "Dataset remains provisional; only collision-free rows are exposed by research.entity_panel.",
        "No row has yet passed a complete automated or human economic certification rule."))
  )
  catalog$grain[blank_text(catalog$grain)] <- "mixed_or_undeclared"
  dataset <- catalog %>% dplyr::transmute(
    dataset_id = source_id, source_id, source_label, publisher, source_format, grain,
    assurance_level, disposition_reason, point_in_time_status, license_status, allowed_uses,
    prohibited_uses, certification_rule_id = ifelse(
      structural, "accounted_long_source",
      ifelse(source_id %in% certified_source_ids, "proposal_high_no_open", NA_character_)
    ), evidence_uri = "config/acquisition_contracts.csv", updated_at = certified_at
  )
  DBI::dbExecute(con, "DELETE FROM canonical.dataset_catalog")
  DBI::dbAppendTable(con, DBI::Id(schema = "canonical", table = "dataset_catalog"), dataset)
  dataset_decisions <- dataset %>% dplyr::transmute(
    object_type = "dataset", object_id = dataset_id, assurance_level,
    rule_id = certification_rule_id, rule_version = ifelse(
      is.na(certification_rule_id), NA_character_, "1"
    ), evidence_uri,
    evidence_hash = vapply(seq_len(nrow(dataset)), function(i) digest::digest(
      paste(dataset$dataset_id[[i]], dataset$assurance_level[[i]],
            dataset$allowed_uses[[i]], dataset$prohibited_uses[[i]], sep = "|"),
      algo = "sha256", serialize = FALSE
    ), character(1)),
    rationale = disposition_reason, decided_at = certified_at, build_id = as.character(build_id)
  )
  dataset_decisions$decision_id <- vapply(seq_len(nrow(dataset_decisions)), function(i) {
    digest::digest(paste(
      "dataset", dataset_decisions$object_id[[i]], dataset_decisions$evidence_hash[[i]],
      build_id, sep = "|"
    ), algo = "sha256", serialize = FALSE)
  }, character(1))
  dataset_decisions <- dataset_decisions[c(
    "decision_id", "object_type", "object_id", "assurance_level", "rule_id", "rule_version",
    "evidence_uri", "evidence_hash", "rationale", "decided_at", "build_id"
  )]
  existing <- DBI::dbGetQuery(con, "SELECT decision_id FROM canonical.certification_decisions")$decision_id
  dataset_decisions <- dataset_decisions[!dataset_decisions$decision_id %in% existing, , drop = FALSE]
  if (nrow(dataset_decisions)) DBI::dbAppendTable(
    con, DBI::Id(schema = "canonical", table = "certification_decisions"), dataset_decisions
  )
  invisible(list(series = nrow(stored), datasets = nrow(dataset)))
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

apply_platform_contracts <- function(con, root, build_id = NA_character_) {
  initialize_platform_contracts(con)
  apply_missingness_contracts(con, root)
  apply_panel_resolution(con, root)
  apply_rule_certification(con, root, build_id)
  invisible(TRUE)
}

current_quality_flags_sql <- function() paste(
  "SELECT q.* FROM audit.quality_flags q",
  "JOIN audit.data_releases d ON d.attempt_id = q.attempt_id",
  "JOIN audit.active_data_release a ON a.data_release_id = d.data_release_id",
  "WHERE coalesce(q.status, 'open') = 'open'"
)

create_schema40_compat_views <- function(con) {
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

# Schema 41. The research schema is deliberately small and grain-aware. Its
# assurance column is part of the data contract: rule certification is visible
# at every row and is never presented as economist sign-off.
create_research_views <- function(con) {
  DBI::dbExecute(con, "CREATE SCHEMA IF NOT EXISTS research")
  retired <- c(
    "series_catalog_approved", "bank_panel", "lrm_auction_events", "interbank_events",
    "bond_curves", "securities_transactions"
  )
  for (view in retired) DBI::dbExecute(
    con, paste0("DROP VIEW IF EXISTS research.", view, " CASCADE")
  )

  create_project_view(con, "v_certified_research_series", paste(
    "WITH human AS (",
    " SELECT d.series_id, coalesce(m.canonical_series_id,d.series_id) AS research_series_id,",
    " c.canonical_series_id AS canonical_name, r.definition, r.definition_evidence_uri,",
    " r.frequency, r.reference_period_convention, r.timing_basis, r.stock_flow, r.unit_code,",
    " r.scale_multiplier, r.currency, r.valuation, r.nominal_real, r.price_base_year,",
    " r.seasonal_adjustment, r.transformation, r.hierarchy_role, r.parent_series_id,",
    " r.methodology_regime_id, r.comparability, 'human_verified' AS assurance_level,",
    " 'human_series_review' AS certification_rule_id, 'register' AS certification_rule_version,",
    " d.source_id, d.source_label, d.full_series_path, d.series_grain,",
    " coalesce(m.relationship,'primary') AS relationship, coalesce(m.precedence,1) AS precedence",
    " FROM canonical.series_review r JOIN canonical.dim_series d USING(series_id)",
    " LEFT JOIN canonical.map_canonical_series m USING(series_id)",
    " LEFT JOIN canonical.canonical_series c ON c.canonical_series_id=m.canonical_series_id",
    "  AND c.reviewed_status='reviewed'",
    "), automated AS (",
    " SELECT r.*, d.source_id, d.source_label, d.full_series_path, d.series_grain,",
    " 'primary' AS relationship, 1 AS precedence",
    " FROM canonical.rule_certified_series r JOIN canonical.dim_series d USING(series_id)",
    " WHERE NOT EXISTS (SELECT 1 FROM human h WHERE h.series_id=r.series_id)",
    ") SELECT * FROM human UNION ALL BY NAME SELECT * FROM automated"
  ), schema = "main")

  create_project_view(con, "quality_flags", current_quality_flags_sql(), schema = "research")
  create_project_view(con, "observations_latest_actual", paste(
    "WITH ranked AS (SELECT r.research_series_id, r.canonical_name, o.series_id AS source_series_id,",
    " o.label AS source_label, o.table_title, o.period AS source_period_date,",
    " o.period_start AS reference_period_start, o.period_end AS reference_period_end,",
    " o.value, o.value * r.scale_multiplier AS value_in_base_units, r.frequency, r.unit_code,",
    " r.scale_multiplier, r.currency, r.stock_flow, r.nominal_real, r.seasonal_adjustment,",
    " r.transformation, o.vintage_id, o.publication_date, o.available_at,",
    " o.availability_quality, o.observation_status, o.source_id, o.source_sheet,",
    " r.relationship, r.precedence, r.assurance_level, r.certification_rule_id,",
    " row_number() OVER(PARTITION BY r.research_series_id,o.period_start",
    " ORDER BY r.precedence,o.available_at DESC,o.series_id) AS member_rank",
    " FROM main.v_series_research o JOIN main.v_certified_research_series r USING(series_id)",
    " WHERE o.observation_status='observed' AND EXISTS(SELECT 1 FROM audit.active_data_release))",
    " SELECT * EXCLUDE(member_rank),",
    " (SELECT count(*) FROM research.quality_flags q WHERE q.series_id=ranked.source_series_id",
    " OR (q.series_id IS NULL AND q.source_id=ranked.source_id",
    " AND (q.source_sheet IS NULL OR q.source_sheet=ranked.source_sheet))) AS flag_count",
    " FROM ranked WHERE member_rank=1"
  ), schema = "research")

  create_project_view(con, "observations_latest_statement", paste(
    "WITH ranked AS (SELECT r.research_series_id, r.canonical_name, o.series_id AS source_series_id,",
    " d.label AS source_label, t.table_title, o.period AS source_period_date,",
    " o.period_start AS reference_period_start, o.period_end AS reference_period_end,",
    " o.value, o.value*r.scale_multiplier AS value_in_base_units, r.frequency, r.unit_code,",
    " r.scale_multiplier, r.currency, r.stock_flow, r.nominal_real, r.seasonal_adjustment,",
    " r.transformation, o.vintage_id, o.publication_date, p.available_at,",
    " p.availability_quality, o.observation_status, d.source_id, o.source_sheet,",
    " r.relationship, r.precedence, r.assurance_level, r.certification_rule_id,",
    " row_number() OVER(PARTITION BY r.research_series_id,o.period_start",
    " ORDER BY r.precedence,p.available_at DESC,o.series_id) AS member_rank",
    " FROM main.v_series_observations o JOIN main.v_certified_research_series r USING(series_id)",
    " JOIN canonical.dim_series d USING(series_id) LEFT JOIN canonical.series_titles t USING(series_id)",
    " LEFT JOIN raw.source_provenance p USING(vintage_id)",
    " WHERE NOT o.is_deleted AND EXISTS(SELECT 1 FROM audit.active_data_release))",
    " SELECT * EXCLUDE(member_rank),",
    " (SELECT count(*) FROM research.quality_flags q WHERE q.series_id=ranked.source_series_id",
    " OR (q.series_id IS NULL AND q.source_id=ranked.source_id",
    " AND (q.source_sheet IS NULL OR q.source_sheet=ranked.source_sheet))) AS flag_count",
    " FROM ranked WHERE member_rank=1"
  ), schema = "research")

  create_project_view(con, "series_catalog", paste(
    "SELECT r.research_series_id, r.canonical_name, r.series_id AS source_series_id,",
    " r.source_id, r.source_label, r.full_series_path, r.definition, r.definition_evidence_uri,",
    " r.series_grain, r.frequency, r.reference_period_convention, r.timing_basis, r.stock_flow,",
    " r.unit_code, r.scale_multiplier, r.currency, r.valuation, r.nominal_real,",
    " r.price_base_year, r.seasonal_adjustment, r.transformation, r.hierarchy_role,",
    " r.parent_series_id, r.methodology_regime_id, r.comparability, r.assurance_level,",
    " r.certification_rule_id, count(o.reference_period_start) AS observations,",
    " min(o.reference_period_start) AS first_period, max(o.reference_period_end) AS last_period",
    " FROM main.v_certified_research_series r LEFT JOIN research.observations_latest_actual o",
    " ON o.research_series_id=r.research_series_id AND o.source_series_id=r.series_id GROUP BY ALL"
  ), schema = "research")

  create_project_view(con, "dataset_catalog", paste(
    "SELECT d.*, (SELECT count(*) FROM canonical.dim_series s WHERE s.source_id=d.source_id) AS series,",
    " (SELECT count(*) FROM main.v_series_latest o JOIN canonical.dim_series s USING(series_id)",
    "  WHERE s.source_id=d.source_id) AS scalar_observations",
    " FROM canonical.dataset_catalog d"
  ), schema = "research")

  bank_inputs_exist <- all(vapply(c("v_banks_eeff_documented", "v_financial_eeff_documented"),
    function(x) database_object_exists(con, x), logical(1)))
  panel_sql <- if (bank_inputs_exist) paste(
    "WITH source AS (SELECT * FROM main.v_banks_eeff_documented UNION ALL BY NAME",
    " SELECT * FROM main.v_financial_eeff_documented), keyed AS (SELECT x.*,",
    " count(*) OVER(PARTITION BY source_id,fecha,entity_id,statement_item_id,economic_currency) n",
    " FROM source x) SELECT vintage_id,source_id,source_sheet,source_file,fecha AS reference_period,",
    " entity_id,short_name AS entity_name,statement_item_id AS item_id,semantic_classification,",
    " semantic_rubro,semantic_sub_rubro,economic_currency AS currency,'balance' AS measure,",
    " importe AS value,source_row,'rule_certified' AS assurance_level,",
    " 'collision_free_panel_row' AS certification_rule_id FROM keyed WHERE n=1",
    " AND EXISTS(SELECT 1 FROM audit.active_data_release)"
  ) else paste(
    "SELECT NULL::VARCHAR vintage_id,NULL::VARCHAR source_id,NULL::VARCHAR source_sheet,",
    "NULL::VARCHAR source_file,NULL::TIMESTAMP reference_period,NULL::VARCHAR entity_id,",
    "NULL::VARCHAR entity_name,NULL::VARCHAR item_id,NULL::VARCHAR semantic_classification,",
    "NULL::VARCHAR semantic_rubro,NULL::VARCHAR semantic_sub_rubro,NULL::VARCHAR currency,",
    "NULL::VARCHAR AS measure,NULL::DOUBLE AS value,NULL::BIGINT AS source_row,",
    "NULL::VARCHAR assurance_level,NULL::VARCHAR certification_rule_id WHERE FALSE"
  )
  create_project_view(con, "entity_panel", panel_sql, schema = "research")

  create_project_view(con, "events", paste(
    "SELECT md5(o.series_id||':'||cast(o.period AS VARCHAR)||':'||o.vintage_id) AS event_id,",
    " o.period AS event_date,o.series_id AS source_series_id,r.source_id,o.source_sheet,",
    " r.full_series_path AS measure_path,o.value,o.value_in_base_units,r.unit_code,o.vintage_id,",
    " r.assurance_level,r.certification_rule_id FROM main.v_series_research o",
    " JOIN main.v_certified_research_series r USING(series_id) WHERE r.series_grain='event'",
    " AND o.observation_status='observed' AND EXISTS(SELECT 1 FROM audit.active_data_release)"
  ), schema = "research")
  create_project_view(con, "curves", paste(
    "SELECT c.*,'rule_certified' AS assurance_level,'accounted_long_source' AS certification_rule_id",
    " FROM main.v_bond_curves_latest c WHERE EXISTS(SELECT 1 FROM canonical.dataset_catalog d",
    " WHERE d.source_id='corporate_bond_curves' AND d.assurance_level='rule_certified')",
    " AND EXISTS(SELECT 1 FROM audit.active_data_release)"
  ), schema = "research")
  create_project_view(con, "transactions", paste(
    "SELECT t.*,'rule_certified' AS assurance_level,'accounted_long_source' AS certification_rule_id",
    " FROM main.v_securities_transactions_latest t WHERE EXISTS(SELECT 1 FROM canonical.dataset_catalog d",
    " WHERE d.source_id='securities_trades' AND d.assurance_level='rule_certified')",
    " AND EXISTS(SELECT 1 FROM audit.active_data_release)"
  ), schema = "research")

  # A table macro, not a tenth view. It ranks every accepted historical vintage
  # by recorded availability and therefore remains empty before the first truly
  # timestamped forward vintage for a cutoff earlier than the legacy upper bound.
  DBI::dbExecute(con, paste0(
    "CREATE OR REPLACE MACRO research.observations_as_of(cutoff) AS TABLE (",
    "WITH ranked AS (SELECT r.research_series_id,r.canonical_name,o.series_id source_series_id,",
    "o.period source_period_date,o.period_start reference_period_start,o.period_end reference_period_end,",
    "o.value,o.value*r.scale_multiplier value_in_base_units,r.frequency,r.unit_code,r.scale_multiplier,",
    "r.currency,r.stock_flow,r.nominal_real,r.seasonal_adjustment,r.transformation,o.vintage_id,",
    "o.publication_date,o.available_at,p.availability_quality,o.observation_status,d.source_id,",
    "o.source_sheet,r.assurance_level,r.certification_rule_id,row_number() over(partition by ",
    "r.research_series_id,o.period_start order by r.precedence,o.available_at desc,o.vintage_id desc) rn ",
    "FROM main.v_series_observations_history o JOIN main.v_certified_research_series r USING(series_id) ",
    "JOIN canonical.dim_series d USING(series_id) LEFT JOIN raw.source_provenance p USING(vintage_id) ",
    "WHERE NOT o.is_deleted AND o.observation_status='observed' ",
    "AND o.available_at<=cutoff) SELECT * EXCLUDE(rn) FROM ranked WHERE rn=1)"
  ))
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
  acquisitions <- DBI::dbGetQuery(con, "SELECT source_id FROM audit.acquisition_contracts")$source_id
  if (!setequal(acquisitions, registered)) insert_quality_flag(
    con, release_id, "error", "acquisition_contract_coverage", NA_character_,
    "The acquisition register does not cover every registered source exactly once."
  )
  catalog <- DBI::dbGetQuery(con, paste(
    "SELECT source_id,assurance_level,license_status,point_in_time_status,allowed_uses,prohibited_uses",
    "FROM canonical.dataset_catalog"
  ))
  if (!setequal(catalog$source_id, registered) || any(!catalog$assurance_level %in% ASSURANCE_LEVELS) ||
      any(blank_text(catalog$allowed_uses) | blank_text(catalog$prohibited_uses))) {
    insert_quality_flag(
      con, release_id, "error", "dataset_disposition_incomplete", NA_character_,
      "Every registered source must have one valid assurance disposition and explicit use limits."
    )
  }
  certified <- DBI::dbGetQuery(con, paste(
    "SELECT r.series_id FROM canonical.rule_certified_series r",
    "LEFT JOIN canonical.certification_decisions d ON d.object_type='series'",
    "AND d.object_id=r.series_id AND d.evidence_hash=r.evidence_hash",
    "WHERE d.decision_id IS NULL OR r.assurance_level<>'rule_certified'",
    "OR r.unit_code='UNRESOLVED_SOURCE_UNITS' OR r.stock_flow='not_reviewed'",
    "OR r.nominal_real='not_reviewed' OR r.seasonal_adjustment='not_reviewed'"
  ))
  if (nrow(certified)) insert_quality_flag(
    con, release_id, "error", "invalid_rule_certification", NA_character_,
    paste(nrow(certified), "series carry incomplete certification evidence or semantics.")
  )
  duplicate_actual <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM (SELECT research_series_id,reference_period_start,count(*) n",
    "FROM research.observations_latest_actual GROUP BY 1,2 HAVING count(*)>1)"
  ))$n[[1]]
  duplicate_panel <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM (SELECT source_id,reference_period,entity_id,item_id,currency,measure,count(*) n",
    "FROM research.entity_panel GROUP BY 1,2,3,4,5,6 HAVING count(*)>1)"
  ))$n[[1]]
  if (duplicate_actual || duplicate_panel) insert_quality_flag(
    con, release_id, "error", "research_grain_not_unique", NA_character_,
    paste(duplicate_actual, "scalar keys and", duplicate_panel, "entity-panel keys are duplicated.")
  )
  tryCatch(
    DBI::dbGetQuery(con, "SELECT * FROM research.observations_as_of(current_timestamp) LIMIT 0"),
    error = function(e) insert_quality_flag(
      con, release_id, "error", "research_as_of_unusable", NA_character_, conditionMessage(e)
    )
  )
  invisible(TRUE)
}
