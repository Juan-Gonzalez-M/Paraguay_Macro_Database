# --- Review readiness packets -----------------------------------------------
# These functions prepare evidence for the first three empirical-readiness
# steps. They never write a human review register and never promote a proposal.

FLAGSHIP_SOURCE_PRIORITY <- c(
  economic_annex = 1L, exchange_rates = 2L, financial_indicators = 3L,
  banking_indicators = 4L, payments = 5L, direct_investment = 6L,
  credit_survey = 7L, bcp_fx_daily = 8L, exchange_houses = 9L,
  insurance_annex = 10L, lrm_auctions = 11L, liquidity_facility = 12L
)

readiness_metric <- function(con, metric, sql) {
  value <- tryCatch(DBI::dbGetQuery(con, sql)[[1]][[1]], error = function(e) NA)
  tibble::tibble(metric = metric, value = as.character(value))
}

write_release_baseline <- function(con, root, baseline_id = "schema41-2026-09-09") {
  ensure_dirs(root)
  active <- DBI::dbGetQuery(con, paste(
    "SELECT data_release_id,source_bundle_id,promoted_at,promoted_by",
    "FROM audit.active_data_release"
  ))
  artifact <- DBI::dbGetQuery(con, paste(
    "SELECT build_id,artifact_path,size_bytes,schema_version,recorded_at",
    "FROM audit.distribution_artifacts WHERE artifact_role='database'",
    "ORDER BY recorded_at DESC LIMIT 1"
  ))
  manifest_path <- file.path(root, "outputs", "build_manifest.json")
  manifest <- if (file.exists(manifest_path)) jsonlite::fromJSON(manifest_path) else list()
  database_path <- file.path(root, "database", "paraguay_macro_pilot.duckdb")
  metrics <- dplyr::bind_rows(
    readiness_metric(con, "schema_version", "SELECT max(version) FROM audit.schema_version"),
    readiness_metric(con, "fact_series_events", "SELECT count(*) FROM canonical.fact_series_events"),
    readiness_metric(con, "source_series", "SELECT count(*) FROM canonical.dim_series"),
    readiness_metric(con, "source_vintages", "SELECT count(*) FROM raw.source_provenance"),
    readiness_metric(con, "certified_scalar_series", "SELECT count(*) FROM canonical.rule_certified_series"),
    readiness_metric(con, "certification_decisions", "SELECT count(*) FROM canonical.certification_decisions"),
    readiness_metric(con, "research_actual_observations", "SELECT count(*) FROM research.observations_latest_actual"),
    readiness_metric(con, "research_statement_observations", "SELECT count(*) FROM research.observations_latest_statement"),
    readiness_metric(con, "research_entity_panel_rows", "SELECT count(*) FROM research.entity_panel"),
    readiness_metric(con, "research_curve_nodes", "SELECT count(*) FROM research.curves"),
    readiness_metric(con, "research_transactions", "SELECT count(*) FROM research.transactions"),
    readiness_metric(con, "provisional_datasets", "SELECT count(*) FROM canonical.dataset_catalog WHERE assurance_level='provisional'"),
    readiness_metric(con, "open_quality_flags", "SELECT count(*) FROM research.quality_flags"),
    tibble::tibble(metric = "database_sha256", value = file_sha256(database_path)),
    tibble::tibble(metric = "database_bytes", value = as.character(file.info(database_path)$size)),
    tibble::tibble(metric = "data_release_id", value = if (nrow(active)) active$data_release_id[[1]] else NA_character_),
    tibble::tibble(metric = "source_bundle_id", value = if (nrow(active)) active$source_bundle_id[[1]] else NA_character_),
    tibble::tibble(metric = "build_id", value = if (nrow(artifact)) artifact$build_id[[1]] else NA_character_)
  )
  metrics$baseline_id <- baseline_id
  metrics$frozen_at <- as.character(Sys.time())
  readr::write_csv(metrics, file.path(root, "outputs", "release_baseline.csv"))
  lines <- c(
    "# Frozen release baseline",
    "",
    paste0("Baseline ID: `", baseline_id, "`  "),
    paste0("Frozen at: `", Sys.time(), "`  "),
    paste0("Active data release: `", if (nrow(active)) active$data_release_id[[1]] else NA, "`  "),
    paste0("Source bundle: `", if (nrow(active)) active$source_bundle_id[[1]] else NA, "`  "),
    paste0("Database SHA-256: `", file_sha256(database_path), "`  "),
    paste0("Database bytes: `", file.info(database_path)$size, "`"),
    "",
    "This is the immutable comparison point for subsequent economic review. It records the bytes and",
    "release identifiers, not a claim that every source is research-ready. Rebuilds must be compared",
    "against this baseline before a later release is accepted.",
    "",
    "| Metric | Value |",
    "|---|---:|",
    paste0("| ", metrics$metric, " | ", metrics$value, " |")
  )
  writeLines(lines, file.path(root, "docs", "RELEASE_BASELINE_SCHEMA41.md"))
  invisible(metrics)
}

write_flagship_review_queue <- function(con, root, limit = 50L) {
  catalog <- DBI::dbGetQuery(con, paste(
    "SELECT c.series_id,c.source_id,c.label,c.frequency,c.unit_code,c.scale,",
    "c.series_grain,c.identity_stability,c.stock_flow,c.nominal_real,c.seasonal_adjustment,",
    "c.full_series_path,c.first_period,c.last_period,c.observations,",
    "coalesce(t.source_sheet,'') AS source_sheet,coalesce(t.table_title,'') AS table_title,",
    "coalesce(r.status,'provisional') AS reconciliation_status",
    "FROM main.v_series_catalogue c",
    "LEFT JOIN (SELECT series_id, string_agg(DISTINCT source_sheet,'; ' ORDER BY source_sheet) source_sheet,",
    "  string_agg(DISTINCT table_title,'; ' ORDER BY table_title) table_title",
    "  FROM main.v_series_research_all GROUP BY 1) t USING(series_id)",
    "LEFT JOIN (SELECT s.series_id, min(coalesce(x.status,'unreviewed')) status",
    "  FROM staging.documented_series_snapshot s LEFT JOIN audit.table_reconciliation x",
    "  USING(vintage_id,source_id,source_sheet) GROUP BY 1) r USING(series_id)",
    "WHERE c.series_grain='scalar_series'"
  ))
  if (!nrow(catalog)) return(invisible(NULL))
  priority <- unname(FLAGSHIP_SOURCE_PRIORITY[catalog$source_id])
  priority[is.na(priority)] <- 99L
  keyword <- grepl(
    "PIB|producto interno|inflaci|IPC|tipo de cambio|reserv|M2|agregado monet|\bTasa\b|\bPIB\b|export|import|balanza|ingreso|gasto|deuda|cr[eé]dito|IMAEP",
    catalog$label, ignore.case = TRUE, perl = TRUE
  )
  catalog$priority_score <- priority * 1000000 - as.numeric(catalog$observations) - keyword * 250000
  catalog <- catalog[order(catalog$priority_score, catalog$source_id, catalog$series_id), , drop = FALSE]
  catalog <- utils::head(catalog, limit)
  queue <- catalog %>% dplyr::transmute(
    queue_id = paste0("flagship:", series_id), series_id, source_id, source_sheet, table_title,
    label, frequency, unit_code, scale, series_grain, identity_stability, stock_flow,
    nominal_real, seasonal_adjustment, full_series_path, first_period, last_period, observations,
    reconciliation_status, priority_score, decision = "pending_human_review",
    reviewer = NA_character_, reviewed_at = NA_character_, definition_evidence_uri = NA_character_,
    review_notes = NA_character_
  )
  readr::write_csv(queue, file.path(root, "outputs", "flagship_review_queue.csv"))
  invisible(queue)
}

write_duplicate_resolution_queue <- function(con, root) {
  duplicate <- readr::read_csv(
    file.path(root, "outputs", "duplicate_series_candidates.csv"), show_col_types = FALSE
  )
  panel <- readr::read_csv(
    file.path(root, "outputs", "panel_duplicate_worklist.csv"), show_col_types = FALSE
  )
  canonical <- readr::read_csv(
    file.path(root, "config", "proposals", "canonical_series.csv"), show_col_types = FALSE
  )
  canonical_members <- readr::read_csv(
    file.path(root, "config", "proposals", "canonical_series_members.csv"), show_col_types = FALSE
  )
  series_queue <- if (nrow(duplicate)) duplicate %>% dplyr::transmute(
    queue_type = "series_duplicate", priority = dplyr::row_number(),
    source_id = sources, source_sheet = NA_character_, series_ids,
    evidence = paste0(periods, " overlapping periods; signature=", value_signature,
                      "; cross_source=", cross_source),
    proposed_canonical_id = NA_character_, decision = "pending_human_review",
    reviewer = NA_character_, reviewed_at = NA_character_, review_notes = NA_character_
  ) else tibble::tibble()
  panel_queue <- if (nrow(panel)) panel %>% dplyr::transmute(
    queue_type = "panel_collision", priority = dplyr::row_number(), source_id,
    source_sheet = table_name, series_ids = paste0("duplicate_group:", duplicate_group),
    evidence = paste0(rows_in_group, " rows; repeated dimensions: ", repeated_dimensions,
                      "; measures compared: ", measures_compared),
    proposed_canonical_id = NA_character_, decision = "pending_human_review",
    reviewer = NA_character_, reviewed_at = NA_character_, review_notes = NA_character_
  ) else tibble::tibble()
  canonical_queue <- if (nrow(canonical)) canonical %>% dplyr::transmute(
    queue_type = "canonical_proposal", priority = dplyr::row_number(), source_id = NA_character_,
    source_sheet = source_cell, series_ids = canonical_series_id,
    evidence = paste0(definition, " Open questions: ", coalesce(open_questions, "none")),
    proposed_canonical_id = canonical_series_id, decision = "pending_human_review",
    reviewer = NA_character_, reviewed_at = NA_character_, review_notes = NA_character_
  ) else tibble::tibble()
  members_queue <- if (nrow(canonical_members)) canonical_members %>% dplyr::transmute(
    queue_type = "canonical_membership", priority = dplyr::row_number(), source_id = NA_character_,
    source_sheet = source_cell, series_ids = series_id,
    evidence = paste0("canonical=", canonical_series_id, "; relationship=", relationship,
                      "; ", evidence), proposed_canonical_id = canonical_series_id,
    decision = "pending_human_review", reviewer = NA_character_, reviewed_at = NA_character_,
    review_notes = NA_character_
  ) else tibble::tibble()
  queue <- dplyr::bind_rows(series_queue, panel_queue, canonical_queue, members_queue)
  if (nrow(queue)) queue$priority <- seq_len(nrow(queue))
  readr::write_csv(queue, file.path(root, "outputs", "duplicate_canonical_resolution_queue.csv"))
  invisible(queue)
}
