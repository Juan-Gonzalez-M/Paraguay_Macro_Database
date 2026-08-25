ensure_table_column <- function(con, table_name, column_name, column_type) {
  if (!DBI::dbExistsTable(con, table_name)) return(invisible(FALSE))
  columns <- DBI::dbGetQuery(con, paste0("PRAGMA table_info(", sql_string(table_name), ")"))$name
  if (!column_name %in% columns) DBI::dbExecute(con, paste0(
    "ALTER TABLE ", DBI::dbQuoteIdentifier(con, table_name), " ADD COLUMN ",
    DBI::dbQuoteIdentifier(con, column_name), " ", column_type
  ))
  invisible(TRUE)
}

database_object_type <- function(con, object_name) {
  result <- DBI::dbGetQuery(con, paste0(
    "SELECT table_type FROM information_schema.tables WHERE table_schema = current_schema() ",
    "AND table_name = ", sql_string(object_name)
  ))
  if (nrow(result)) result$table_type[[1]] else NA_character_
}

invalidate_v2_curated_content <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version")) return(invisible(FALSE))
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!2L %in% versions || 3L %in% versions) return(invisible(FALSE))

  source_ids <- c("icc", "eve", "fx_operations")
  source_sql <- paste(vapply(source_ids, sql_string, character(1)), collapse = ", ")
  vintage_sql <- paste0("SELECT vintage_id FROM source_files WHERE source_id IN (", source_sql, ")")
  series_prefixes <- c("icc:%", "eve:%", "fx_operations:%")
  series_where <- paste(vapply(series_prefixes, function(prefix) {
    paste0("series_id LIKE ", sql_string(prefix))
  }, character(1)), collapse = " OR ")

  DBI::dbWithTransaction(con, {
    for (table_name in c("fact_series_events", "semantic_coverage", "structure_checks",
                         "discarded_rows", "quality_flags", "report_cells")) {
      if (DBI::dbExistsTable(con, table_name)) DBI::dbExecute(con, paste0(
        "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
        " WHERE vintage_id IN (", vintage_sql, ")"
      ))
    }
    if (DBI::dbExistsTable(con, "series_revisions")) DBI::dbExecute(con, paste0(
      "DELETE FROM series_revisions WHERE ", series_where
    ))
    if (DBI::dbExistsTable(con, "dim_series")) DBI::dbExecute(con, paste0(
      "DELETE FROM dim_series WHERE source_id IN (", source_sql, ")"
    ))
    for (table_name in c("consumer_confidence_snapshot", "eve_expectations_snapshot", "fx_operations_snapshot")) {
      if (DBI::dbExistsTable(con, table_name)) DBI::dbExecute(con, paste0(
        "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
        " WHERE vintage_id IN (", vintage_sql, ")"
      ))
    }
    DBI::dbExecute(con, paste0(
      "UPDATE source_files SET ingestion_status = 'needs_v3_reingestion', publication_date = NULL, ",
      "publication_date_source = 'pending_content_inference' ",
      "WHERE source_id IN (", source_sql, ")"
    ))
  })
  invisible(TRUE)
}

invalidate_v3_reference_semantics <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version")) return(invisible(FALSE))
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!3L %in% versions || 4L %in% versions || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  DBI::dbExecute(con, paste0(
    "UPDATE source_files SET ingestion_status = 'needs_v4_reingestion' ",
    "WHERE source_id = 'bank_reference'"
  ))
  invisible(TRUE)
}

invalidate_v4_documented_sources <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!4L %in% versions || 5L %in% versions) return(invisible(FALSE))
  source_ids <- c("economic_annex", "payments", "exchange_houses", "credit_survey")
  source_sql <- paste(vapply(source_ids, sql_string, character(1)), collapse = ", ")
  DBI::dbExecute(con, paste0(
    "UPDATE source_files SET ingestion_status = 'needs_v5_reingestion' ",
    "WHERE source_id IN (", source_sql, ")"
  ))
  invisible(TRUE)
}

invalidate_v6_documented_identity <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!6L %in% versions || 7L %in% versions) return(invisible(FALSE))
  source_ids <- c("economic_annex", "payments", "exchange_houses", "credit_survey")
  source_sql <- paste(vapply(source_ids, sql_string, character(1)), collapse = ", ")
  series_query <- paste0("SELECT series_id FROM dim_series WHERE source_id IN (", source_sql, ") AND semantic_status = 'documented_series'")
  vintage_query <- paste0("SELECT vintage_id FROM source_files WHERE source_id IN (", source_sql, ")")
  DBI::dbWithTransaction(con, {
    if (DBI::dbExistsTable(con, "map_series_concept")) DBI::dbExecute(con, paste0(
      "DELETE FROM map_series_concept WHERE series_id IN (", series_query, ")"
    ))
    if (DBI::dbExistsTable(con, "fact_series_events")) DBI::dbExecute(con, paste0(
      "DELETE FROM fact_series_events WHERE series_id IN (", series_query, ")"
    ))
    if (DBI::dbExistsTable(con, "series_revisions")) DBI::dbExecute(con, paste0(
      "DELETE FROM series_revisions WHERE series_id IN (", series_query, ")"
    ))
    if (DBI::dbExistsTable(con, "dim_series")) DBI::dbExecute(con, paste0(
      "DELETE FROM dim_series WHERE series_id IN (", series_query, ")"
    ))
    if (DBI::dbExistsTable(con, "dim_concept")) DBI::dbExecute(con, paste0(
      "DELETE FROM dim_concept WHERE mapping_status = 'source_specific_unreviewed' ",
      "AND concept_id NOT IN (SELECT concept_id FROM map_series_concept)"
    ))
    for (table_name in c("documented_series_snapshot", "documented_table_catalog",
                         "documented_sheet_drift", "semantic_coverage")) {
      if (DBI::dbExistsTable(con, table_name)) DBI::dbExecute(con, paste0(
        "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
        " WHERE vintage_id IN (", vintage_query, ")"
      ))
    }
    DBI::dbExecute(con, paste0(
      "UPDATE source_files SET ingestion_status = 'needs_v7_reingestion' WHERE source_id IN (", source_sql, ")"
    ))
  })
  invisible(TRUE)
}

invalidate_v8_ingestion_repairs <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!8L %in% versions || 9L %in% versions) return(invisible(FALSE))
  documented_sources <- c(
    "economic_annex", "payments", "exchange_houses", "credit_survey",
    "direct_investment", "insurance_annex", "bcp_fx_daily", "exchange_rates",
    "banking_indicators", "financial_indicators", "interbank_market", "lrm_auctions",
    "compensatory_fx_sales", "liquidity_facility"
  )
  source_sql <- paste(vapply(documented_sources, sql_string, character(1)), collapse = ", ")
  series_query <- paste0(
    "SELECT series_id FROM dim_series WHERE source_id IN (", source_sql,
    ") AND semantic_status = 'documented_series'"
  )
  vintage_query <- paste0("SELECT vintage_id FROM source_files WHERE source_id IN (", source_sql, ")")
  affected_concepts <- if (DBI::dbExistsTable(con, "map_series_concept")) {
    DBI::dbGetQuery(con, paste0(
      "SELECT DISTINCT concept_id FROM map_series_concept WHERE series_id IN (",
      series_query, ") AND mapping_status = 'source_specific_unreviewed'"
    ))$concept_id
  } else character()
  DBI::dbWithTransaction(con, {
    for (table_name in c("map_series_concept", "fact_series_events", "series_revisions")) {
      if (DBI::dbExistsTable(con, table_name)) DBI::dbExecute(con, paste0(
        "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
        " WHERE series_id IN (", series_query, ")"
      ))
    }
    if (DBI::dbExistsTable(con, "dim_series")) DBI::dbExecute(con, paste0(
      "DELETE FROM dim_series WHERE series_id IN (", series_query, ")"
    ))
    if (DBI::dbExistsTable(con, "dim_concept") && length(affected_concepts)) {
      concept_sql <- paste(vapply(affected_concepts, sql_string, character(1)), collapse = ", ")
      DBI::dbExecute(con, paste0(
        "DELETE FROM dim_concept WHERE concept_id IN (", concept_sql, ") ",
        "AND mapping_status = 'source_specific_unreviewed' ",
        "AND concept_id NOT IN (SELECT concept_id FROM map_series_concept)"
      ))
    }
    for (table_name in c(
      "documented_series_snapshot", "documented_table_catalog", "documented_sheet_drift",
      "documented_series_continuity", "semantic_coverage"
    )) if (DBI::dbExistsTable(con, table_name)) DBI::dbExecute(con, paste0(
      "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
      " WHERE vintage_id IN (", vintage_query, ")"
    ))
    DBI::dbExecute(con, paste0(
      "UPDATE source_files SET ingestion_status = 'needs_v9_reingestion' WHERE source_id IN (",
      source_sql, ") OR source_id = 'bank_reference'"
    ))
  })
  invisible(TRUE)
}

invalidate_v9_runtime_repairs <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!9L %in% versions || 10L %in% versions) return(invisible(FALSE))
  affected_sources <- c(
    "economic_annex", "exchange_rates", "exchange_houses",
    "liquidity_facility", "interbank_market", "lrm_auctions"
  )
  source_sql <- paste(vapply(affected_sources, sql_string, character(1)), collapse = ", ")
  series_query <- paste0(
    "SELECT series_id FROM dim_series WHERE source_id IN (", source_sql,
    ") AND semantic_status = 'documented_series'"
  )
  vintage_query <- paste0("SELECT vintage_id FROM source_files WHERE source_id IN (", source_sql, ")")
  affected_concepts <- if (DBI::dbExistsTable(con, "map_series_concept")) {
    DBI::dbGetQuery(con, paste0(
      "SELECT DISTINCT concept_id FROM map_series_concept WHERE series_id IN (",
      series_query, ") AND mapping_status = 'source_specific_unreviewed'"
    ))$concept_id
  } else character()
  DBI::dbWithTransaction(con, {
    for (table_name in c("map_series_concept", "fact_series_events", "series_revisions")) {
      if (DBI::dbExistsTable(con, table_name)) DBI::dbExecute(con, paste0(
        "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
        " WHERE series_id IN (", series_query, ")"
      ))
    }
    if (DBI::dbExistsTable(con, "dim_series")) DBI::dbExecute(con, paste0(
      "DELETE FROM dim_series WHERE series_id IN (", series_query, ")"
    ))
    if (DBI::dbExistsTable(con, "dim_concept") && length(affected_concepts)) {
      concept_sql <- paste(vapply(affected_concepts, sql_string, character(1)), collapse = ", ")
      DBI::dbExecute(con, paste0(
        "DELETE FROM dim_concept WHERE concept_id IN (", concept_sql, ") ",
        "AND mapping_status = 'source_specific_unreviewed' ",
        "AND concept_id NOT IN (SELECT concept_id FROM map_series_concept)"
      ))
    }
    for (table_name in c(
      "documented_series_snapshot", "documented_table_catalog", "documented_sheet_drift",
      "documented_series_continuity", "semantic_coverage"
    )) if (DBI::dbExistsTable(con, table_name)) DBI::dbExecute(con, paste0(
      "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
      " WHERE vintage_id IN (", vintage_query, ")"
    ))
    DBI::dbExecute(con, paste0(
      "UPDATE source_files SET ingestion_status = 'needs_v10_reingestion' WHERE source_id IN (",
      source_sql, ")"
    ))
  })
  invisible(TRUE)
}

invalidate_v10_annex_year_axis <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!10L %in% versions || 11L %in% versions) return(invisible(FALSE))
  source_sql <- sql_string("economic_annex")
  series_query <- paste0(
    "SELECT series_id FROM dim_series WHERE source_id = ", source_sql,
    " AND semantic_status = 'documented_series'"
  )
  vintage_query <- paste0("SELECT vintage_id FROM source_files WHERE source_id = ", source_sql)
  affected_concepts <- if (DBI::dbExistsTable(con, "map_series_concept")) {
    DBI::dbGetQuery(con, paste0(
      "SELECT DISTINCT concept_id FROM map_series_concept WHERE series_id IN (",
      series_query, ") AND mapping_status = 'source_specific_unreviewed'"
    ))$concept_id
  } else character()
  DBI::dbWithTransaction(con, {
    for (table_name in c("map_series_concept", "fact_series_events", "series_revisions")) {
      if (DBI::dbExistsTable(con, table_name)) DBI::dbExecute(con, paste0(
        "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
        " WHERE series_id IN (", series_query, ")"
      ))
    }
    if (DBI::dbExistsTable(con, "dim_series")) DBI::dbExecute(con, paste0(
      "DELETE FROM dim_series WHERE series_id IN (", series_query, ")"
    ))
    if (DBI::dbExistsTable(con, "dim_concept") && length(affected_concepts)) {
      concept_sql <- paste(vapply(affected_concepts, sql_string, character(1)), collapse = ", ")
      DBI::dbExecute(con, paste0(
        "DELETE FROM dim_concept WHERE concept_id IN (", concept_sql, ") ",
        "AND mapping_status = 'source_specific_unreviewed' ",
        "AND concept_id NOT IN (SELECT concept_id FROM map_series_concept)"
      ))
    }
    for (table_name in c(
      "documented_series_snapshot", "documented_table_catalog", "documented_sheet_drift",
      "documented_series_continuity", "semantic_coverage"
    )) if (DBI::dbExistsTable(con, table_name)) DBI::dbExecute(con, paste0(
      "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
      " WHERE vintage_id IN (", vintage_query, ")"
    ))
    DBI::dbExecute(con, paste0(
      "UPDATE source_files SET ingestion_status = 'needs_v11_reingestion' WHERE source_id = ",
      source_sql
    ))
  })
  invisible(TRUE)
}

migrate_report_cells_storage <- function(con) {
  object_type <- database_object_type(con, "report_cells")
  if (identical(object_type, "BASE TABLE")) {
    if (DBI::dbExistsTable(con, "report_cells_legacy")) stop(
      "Cannot migrate report_cells: report_cells_legacy already exists.", call. = FALSE
    )
    DBI::dbExecute(con, "ALTER TABLE report_cells RENAME TO report_cells_legacy")
  }
  invisible(TRUE)
}

create_report_cells_view <- function(con) {
  sparse_sql <- paste(
    "SELECT v.vintage_id, v.release_id, v.publication_date, v.source_id,",
    "v.source_file, v.source_sheet, c.row_id, c.column_id,",
    "c.raw_value_text, c.raw_value_num, c.raw_value_date",
    "FROM report_sheet_vintages v JOIN report_cell_values c USING (sheet_version_id)"
  )
  legacy_sql <- if (DBI::dbExistsTable(con, "report_cells_legacy")) {
    " UNION ALL SELECT vintage_id, release_id, publication_date, source_id, source_file, source_sheet, row_id, column_id, raw_value_text, raw_value_num, raw_value_date FROM report_cells_legacy"
  } else ""
  DBI::dbExecute(con, paste0("CREATE OR REPLACE VIEW report_cells AS ", sparse_sql, legacy_sql))
  invisible(TRUE)
}

correct_currency_semantics_in_place <- function(con) {
  if (!DBI::dbExistsTable(con, "dim_currency")) return(invisible(FALSE))
  DBI::dbExecute(con, paste0(
    "UPDATE dim_currency SET ",
    "currency_of_origin = CASE WHEN currency_code = '6900' THEN 'PYG' ",
    "WHEN currency_code IN ('6100', '6200') THEN 'FX' ELSE currency_of_origin END, ",
    "unit_currency = CASE WHEN currency_code IN ('6900', '6200') THEN 'PYG' ",
    "WHEN currency_code = '6100' THEN 'USD' ELSE unit_currency END, ",
    "economic_currency = CASE WHEN currency_code IN ('6900', '6200') THEN 'PYG' ",
    "WHEN currency_code = '6100' THEN 'USD' ELSE economic_currency END ",
    "WHERE currency_code IN ('6100', '6200', '6900')"
  ))
  invisible(TRUE)
}

initialize_database <- function(con) {
  if (DBI::dbExistsTable(con, "source_files") && !DBI::dbExistsTable(con, "schema_version")) {
    stop("A version-1 database was detected. Run source('scripts/upgrade_v1_to_v11.R') once before updating.", call. = FALSE)
  }
  existing_versions <- if (DBI::dbExistsTable(con, "schema_version")) {
    DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  } else integer()
  existing_sources <- DBI::dbExistsTable(con, "source_files") &&
    DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM source_files")$n[[1]] > 0L
  if (!length(existing_versions) && existing_sources) stop(
    "An unversioned non-empty database was detected. Restore a backup or use the guarded version-1 migration.",
    call. = FALSE
  )
  fresh_bootstrap <- !length(existing_versions) && !existing_sources
  statements <- c(
    "CREATE TABLE IF NOT EXISTS schema_version (version INTEGER PRIMARY KEY, applied_at TIMESTAMP, description VARCHAR)",
    "CREATE TABLE IF NOT EXISTS ingestion_runs (release_id VARCHAR PRIMARY KEY, executed_at TIMESTAMP, status VARCHAR, source_count INTEGER, error_count INTEGER, warning_count INTEGER)",
    "CREATE TABLE IF NOT EXISTS ingestion_stage_timings (release_id VARCHAR, vintage_id VARCHAR, source_id VARCHAR, stage VARCHAR, elapsed_seconds DOUBLE, recorded_at TIMESTAMP)",
    "CREATE TABLE IF NOT EXISTS release_sources (release_id VARCHAR, source_id VARCHAR, vintage_id VARCHAR, PRIMARY KEY (release_id, vintage_id))",
    "CREATE TABLE IF NOT EXISTS source_files (vintage_id VARCHAR PRIMARY KEY, release_id VARCHAR, source_id VARCHAR, source_label VARCHAR, publisher VARCHAR, source_format VARCHAR, source_file VARCHAR, source_path VARCHAR, archive_path VARCHAR, sha256 VARCHAR, size_bytes BIGINT, publication_date DATE, publication_date_source VARCHAR, first_ingested_at TIMESTAMP, ingestion_status VARCHAR)",
    "CREATE TABLE IF NOT EXISTS source_sheets (vintage_id VARCHAR, release_id VARCHAR, source_id VARCHAR, source_file VARCHAR, sheet_name VARCHAR, used_rows BIGINT, used_cols BIGINT, content_first_row BIGINT, content_first_col BIGINT, content_last_row BIGINT, content_last_col BIGINT, ingest_mode VARCHAR, structure_signature VARCHAR)",
    "CREATE TABLE IF NOT EXISTS structure_checks (vintage_id VARCHAR, release_id VARCHAR, source_id VARCHAR, source_sheet VARCHAR, component VARCHAR, expected_signature VARCHAR, observed_signature VARCHAR, status VARCHAR, checked_at TIMESTAMP)",
    "CREATE TABLE IF NOT EXISTS quality_flags (check_id VARCHAR PRIMARY KEY, release_id VARCHAR, vintage_id VARCHAR, severity VARCHAR, check_name VARCHAR, source_id VARCHAR, source_sheet VARCHAR, detail VARCHAR, created_at TIMESTAMP)",
    "CREATE TABLE IF NOT EXISTS discarded_rows (discard_id VARCHAR PRIMARY KEY, release_id VARCHAR, vintage_id VARCHAR, source_id VARCHAR, source_sheet VARCHAR, row_id BIGINT, reason VARCHAR, raw_label VARCHAR)",
    "CREATE TABLE IF NOT EXISTS report_sheet_versions (sheet_version_id VARCHAR PRIMARY KEY, source_id VARCHAR, source_sheet VARCHAR, structure_signature VARCHAR, raw_nonempty_cells BIGINT, first_vintage_id VARCHAR, created_at TIMESTAMP)",
    "CREATE TABLE IF NOT EXISTS report_sheet_vintages (vintage_id VARCHAR, release_id VARCHAR, publication_date DATE, source_id VARCHAR, source_file VARCHAR, source_sheet VARCHAR, sheet_version_id VARCHAR, PRIMARY KEY (vintage_id, source_sheet))",
    "CREATE TABLE IF NOT EXISTS report_cell_values (sheet_version_id VARCHAR, row_id BIGINT, column_id BIGINT, raw_value_text VARCHAR, raw_value_num DOUBLE, raw_value_date DATE, PRIMARY KEY (sheet_version_id, row_id, column_id))",
    "CREATE TABLE IF NOT EXISTS documented_table_catalog (vintage_id VARCHAR, source_id VARCHAR, source_sheet VARCHAR, table_title VARCHAR, parser_mode VARCHAR, parse_status VARCHAR, hierarchy_status VARCHAR, raw_nonempty_cells BIGINT, parsed_observations BIGINT, series_count BIGINT, first_period DATE, last_period DATE, unit_summary VARCHAR, coverage_note VARCHAR, PRIMARY KEY (vintage_id, source_sheet))",
    "CREATE TABLE IF NOT EXISTS documented_sheet_drift (vintage_id VARCHAR, previous_vintage_id VARCHAR, source_id VARCHAR, source_sheet VARCHAR, previous_observations BIGINT, current_observations BIGINT, observation_change BIGINT, previous_series BIGINT, current_series BIGINT, series_change BIGINT, drift_status VARCHAR, PRIMARY KEY (vintage_id, source_sheet))",
    "CREATE TABLE IF NOT EXISTS documented_series_continuity (vintage_id VARCHAR, previous_vintage_id VARCHAR, source_id VARCHAR, series_id VARCHAR, source_sheet VARCHAR, change_type VARCHAR, previous_label VARCHAR, current_label VARCHAR, previous_unit VARCHAR, current_unit VARCHAR, previous_scale VARCHAR, current_scale VARCHAR, previous_currency VARCHAR, current_currency VARCHAR, identity_stability VARCHAR, PRIMARY KEY (vintage_id, series_id, change_type))",
    "CREATE TABLE IF NOT EXISTS documented_series_snapshot (vintage_id VARCHAR, release_id VARCHAR, publication_date DATE, source_id VARCHAR, source_file VARCHAR, source_sheet VARCHAR, table_title VARCHAR, parser_mode VARCHAR, series_id VARCHAR, identity_basis VARCHAR, identity_stability VARCHAR, hierarchy_status VARCHAR, period DATE, source_period_label VARCHAR, frequency VARCHAR, series_label VARCHAR, series_path VARCHAR, category VARCHAR, measure VARCHAR, question VARCHAR, response VARCHAR, entity_id VARCHAR, exchange_item_id VARCHAR, participant_id VARCHAR, unit VARCHAR, scale VARCHAR, currency VARCHAR, index_base VARCHAR, value DOUBLE, is_total BOOLEAN, source_row BIGINT, source_column BIGINT)",
    "CREATE TABLE IF NOT EXISTS semantic_coverage (vintage_id VARCHAR, source_id VARCHAR, source_sheet VARCHAR, semantic_status VARCHAR, raw_nonempty_cells BIGINT, curated_observations BIGINT, coverage_note VARCHAR)",
    "CREATE TABLE IF NOT EXISTS dim_entity (entity_id VARCHAR PRIMARY KEY, entity_code VARCHAR, entity_type VARCHAR, entity_name VARCHAR, legal_name VARCHAR, short_name VARCHAR, ownership_type VARCHAR, mapping_status VARCHAR, first_vintage_id VARCHAR)",
    "CREATE TABLE IF NOT EXISTS dim_currency (currency_code VARCHAR PRIMARY KEY, currency_label VARCHAR, currency_of_origin VARCHAR, unit_currency VARCHAR, economic_currency VARCHAR, description VARCHAR, mapping_status VARCHAR, first_vintage_id VARCHAR)",
    "CREATE TABLE IF NOT EXISTS dim_statement_item (statement_item_id VARCHAR PRIMARY KEY, entity_type VARCHAR, report_code VARCHAR, classification VARCHAR, rubro VARCHAR, sub_rubro VARCHAR, source_label VARCHAR, source_label_normalized VARCHAR, first_vintage_id VARCHAR)",
    "CREATE TABLE IF NOT EXISTS map_statement_account (statement_account_id VARCHAR PRIMARY KEY, entity_type VARCHAR, report_name VARCHAR, classification VARCHAR, rubro VARCHAR, sub_rubro VARCHAR, account_number_raw VARCHAR, account_number VARCHAR, multiplier DOUBLE, first_vintage_id VARCHAR)",
    "CREATE TABLE IF NOT EXISTS dim_ratio (ratio_id VARCHAR PRIMARY KEY, entity_type VARCHAR, classification VARCHAR, rubro VARCHAR, source_label VARCHAR, source_label_normalized VARCHAR, first_vintage_id VARCHAR)",
    "CREATE TABLE IF NOT EXISTS dim_portfolio_item (portfolio_item_id VARCHAR PRIMARY KEY, entity_type VARCHAR, classification VARCHAR, rubro VARCHAR, sub_rubro VARCHAR, source_code VARCHAR, source_code_normalized VARCHAR, first_vintage_id VARCHAR)",
    "CREATE TABLE IF NOT EXISTS map_portfolio_account (portfolio_account_id VARCHAR PRIMARY KEY, entity_type VARCHAR, classification VARCHAR, rubro VARCHAR, sub_rubro VARCHAR, source_code VARCHAR, account_number_raw VARCHAR, account_number VARCHAR, first_vintage_id VARCHAR)",
    "CREATE TABLE IF NOT EXISTS dim_credit_activity (activity_id VARCHAR PRIMARY KEY, activity_code VARCHAR, activity_description VARCHAR, activity_description_normalized VARCHAR, bulletin_sector VARCHAR, first_vintage_id VARCHAR)",
    "CREATE TABLE IF NOT EXISTS dim_credit_sector (credit_sector_id VARCHAR PRIMARY KEY, sector_label VARCHAR, sector_label_normalized VARCHAR, first_vintage_id VARCHAR)",
    "CREATE TABLE IF NOT EXISTS dim_payment_participant (participant_id VARCHAR PRIMARY KEY, bic_code VARCHAR, legal_name VARCHAR, participant_type VARCHAR, first_vintage_id VARCHAR)",
    "CREATE TABLE IF NOT EXISTS dim_exchange_item (exchange_item_id VARCHAR PRIMARY KEY, statement_type VARCHAR, classification VARCHAR, item_label VARCHAR, item_label_normalized VARCHAR, first_vintage_id VARCHAR)",
    "CREATE TABLE IF NOT EXISTS reference_table_loads (vintage_id VARCHAR, source_sheet VARCHAR, source_table VARCHAR, semantic_role VARCHAR, row_count BIGINT, structure_signature VARCHAR, PRIMARY KEY (vintage_id, source_sheet, source_table))",
    "CREATE TABLE IF NOT EXISTS dim_series (series_id VARCHAR PRIMARY KEY, source_id VARCHAR, label VARCHAR, unit VARCHAR, scale VARCHAR, frequency VARCHAR, currency VARCHAR, index_base VARCHAR, hierarchy_level VARCHAR, parent_series_id VARCHAR, is_total BOOLEAN, identity_basis VARCHAR, identity_stability VARCHAR, hierarchy_status VARCHAR, semantic_status VARCHAR, first_vintage_id VARCHAR)",
    "CREATE TABLE IF NOT EXISTS bond_curve_snapshot (vintage_id VARCHAR, release_id VARCHAR, publication_date DATE, source_file VARCHAR, source_row BIGINT, period DATE, currency VARCHAR, risk_rating VARCHAR, maturity_years DOUBLE, zero_coupon_rate DOUBLE, discount_factor DOUBLE, par_rate DOUBLE, beta0 DOUBLE, beta1 DOUBLE, beta2 DOUBLE, beta3 DOUBLE, lambda1 DOUBLE, lambda2 DOUBLE)",
    "CREATE TABLE IF NOT EXISTS securities_transactions_snapshot (vintage_id VARCHAR, release_id VARCHAR, publication_date DATE, source_file VARCHAR, transaction_id VARCHAR, source_row BIGINT, operation_date DATE, broker_tax_id VARCHAR, broker_name VARCHAR, isin VARCHAR, issuer_tax_id VARCHAR, issuer_name VARCHAR, instrument VARCHAR, market VARCHAR, operation_type VARCHAR, local_currency_volume DOUBLE, currency VARCHAR, trading_venue VARCHAR)",
    "CREATE TABLE IF NOT EXISTS dim_concept (concept_id VARCHAR PRIMARY KEY, concept_label VARCHAR, concept_domain VARCHAR, definition VARCHAR, unit VARCHAR, scale VARCHAR, frequency VARCHAR, mapping_status VARCHAR, first_vintage_id VARCHAR)",
    "CREATE TABLE IF NOT EXISTS map_series_concept (series_id VARCHAR, concept_id VARCHAR, relationship VARCHAR, mapping_status VARCHAR, evidence VARCHAR, reviewed_by VARCHAR, reviewed_at DATE, first_vintage_id VARCHAR, PRIMARY KEY (series_id, concept_id))",
    "CREATE TABLE IF NOT EXISTS fact_series_events (series_id VARCHAR, period DATE, value DOUBLE, vintage_id VARCHAR, publication_date DATE, value_hash VARCHAR, is_deleted BOOLEAN, source_file VARCHAR)",
    "CREATE TABLE IF NOT EXISTS series_revisions (revision_id VARCHAR PRIMARY KEY, series_id VARCHAR, period DATE, previous_value DOUBLE, new_value DOUBLE, previous_vintage_id VARCHAR, new_vintage_id VARCHAR, publication_date DATE, absolute_revision DOUBLE)"
  )
  invisible(lapply(statements, function(statement) DBI::dbExecute(con, statement)))
  ensure_table_column(con, "source_files", "publisher", "VARCHAR")
  ensure_table_column(con, "source_files", "source_format", "VARCHAR")
  ensure_table_column(con, "source_files", "first_ingested_at", "TIMESTAMP")
  ensure_table_column(con, "source_sheets", "content_first_row", "BIGINT")
  ensure_table_column(con, "source_sheets", "content_first_col", "BIGINT")
  ensure_table_column(con, "source_sheets", "content_last_row", "BIGINT")
  ensure_table_column(con, "source_sheets", "content_last_col", "BIGINT")
  ensure_table_column(con, "dim_entity", "legal_name", "VARCHAR")
  ensure_table_column(con, "dim_entity", "short_name", "VARCHAR")
  ensure_table_column(con, "dim_entity", "ownership_type", "VARCHAR")
  ensure_table_column(con, "dim_series", "label", "VARCHAR")
  ensure_table_column(con, "dim_series", "unit", "VARCHAR")
  ensure_table_column(con, "dim_series", "scale", "VARCHAR")
  ensure_table_column(con, "dim_series", "frequency", "VARCHAR")
  ensure_table_column(con, "dim_series", "currency", "VARCHAR")
  ensure_table_column(con, "dim_series", "index_base", "VARCHAR")
  ensure_table_column(con, "dim_series", "hierarchy_level", "VARCHAR")
  ensure_table_column(con, "dim_series", "parent_series_id", "VARCHAR")
  ensure_table_column(con, "dim_series", "is_total", "BOOLEAN")
  ensure_table_column(con, "dim_series", "semantic_status", "VARCHAR")
  ensure_table_column(con, "dim_series", "first_vintage_id", "VARCHAR")
  ensure_table_column(con, "dim_currency", "currency_of_origin", "VARCHAR")
  ensure_table_column(con, "dim_currency", "unit_currency", "VARCHAR")
  ensure_table_column(con, "map_statement_account", "account_number_raw", "VARCHAR")
  ensure_table_column(con, "map_portfolio_account", "account_number_raw", "VARCHAR")
  ensure_table_column(con, "reference_currency_snapshot", "currency_of_origin", "VARCHAR")
  ensure_table_column(con, "reference_currency_snapshot", "unit_currency", "VARCHAR")
  ensure_table_column(con, "reference_statement_account_snapshot", "account_number_raw", "VARCHAR")
  ensure_table_column(con, "reference_portfolio_account_snapshot", "account_number_raw", "VARCHAR")
  ensure_table_column(con, "documented_series_snapshot", "exchange_item_id", "VARCHAR")
  ensure_table_column(con, "documented_series_snapshot", "identity_basis", "VARCHAR")
  ensure_table_column(con, "documented_series_snapshot", "identity_stability", "VARCHAR")
  ensure_table_column(con, "documented_series_snapshot", "hierarchy_status", "VARCHAR")
  ensure_table_column(con, "documented_table_catalog", "hierarchy_status", "VARCHAR")
  ensure_table_column(con, "dim_series", "identity_basis", "VARCHAR")
  ensure_table_column(con, "dim_series", "identity_stability", "VARCHAR")
  ensure_table_column(con, "dim_series", "hierarchy_status", "VARCHAR")
  ensure_table_column(con, "bond_curve_snapshot", "source_row", "BIGINT")
  ensure_table_column(con, "securities_transactions_snapshot", "source_row", "BIGINT")
  correct_currency_semantics_in_place(con)
  if (!fresh_bootstrap) invalidate_v2_curated_content(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 3")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (3, current_timestamp, 'Executable guarded pipeline plus documented bank and finance semantic dimensions')")
  }
  migrate_report_cells_storage(con)
  if (!fresh_bootstrap) invalidate_v3_reference_semantics(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 4")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (4, current_timestamp, 'Correct currency semantics, resilient references and sparse report-cell storage')")
  }
  if (!fresh_bootstrap) invalidate_v4_documented_sources(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 5")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (5, current_timestamp, 'Documented series extraction for the economic annex, payments, exchange houses and credit survey')")
  }
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 6")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (6, current_timestamp, 'Explicit concept governance, bounded anchor search and sheet-level vintage drift diagnostics')")
  }
  if (!fresh_bootstrap) invalidate_v6_documented_identity(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 7")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (7, current_timestamp, 'Stable documented-series identity, continuity and hierarchy warnings, CSV market sources and expanded BCP coverage')")
  }
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 8")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (8, current_timestamp, 'Vectorized documented metadata and identity, single-pass semantic workbook reads and stage timings')")
  }
  if (!fresh_bootstrap) invalidate_v8_ingestion_repairs(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 9")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (9, current_timestamp, 'Real-file ingestion repairs, semantic row-event identities and per-source discovery isolation')")
  }
  if (!fresh_bootstrap) invalidate_v9_runtime_repairs(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 10")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (10, current_timestamp, 'Contextual date and year parsing, empty-sheet bounds, continuity SQL and complete event dimensions')")
  }
  if (!fresh_bootstrap) invalidate_v10_annex_year_axis(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 11")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (11, current_timestamp, 'Bootstrap-safe migrations and sequence-aware annotated year-axis selection')")
  }
  create_series_views(con)
  create_report_cells_view(con)
  if (exists("documented_create_views", mode = "function")) documented_create_views(con)
  if (exists("create_concept_views", mode = "function")) {
    sync_source_specific_concepts(con)
    create_concept_views(con)
  }
  if (exists("create_market_views", mode = "function")) create_market_views(con)
}

create_series_views <- function(con) {
  DBI::dbExecute(con, "CREATE OR REPLACE VIEW v_series_latest AS WITH ranked AS (SELECT *, row_number() OVER (PARTITION BY series_id, period ORDER BY publication_date DESC NULLS LAST, vintage_id DESC) AS rn FROM fact_series_events) SELECT series_id, period, value, vintage_id, publication_date, source_file FROM ranked WHERE rn = 1 AND NOT is_deleted")
  DBI::dbExecute(con, "CREATE OR REPLACE VIEW v_series_catalogue AS SELECT d.*, x.first_period, x.last_period, x.observations FROM dim_series d LEFT JOIN (SELECT series_id, min(period) AS first_period, max(period) AS last_period, count(*) AS observations FROM v_series_latest GROUP BY 1) x USING (series_id)")
}

insert_quality_flag <- function(con, release_id, severity, check_name, source_id = NA_character_, detail, vintage_id = NA_character_, source_sheet = NA_character_) {
  key <- paste(release_id, vintage_id, severity, check_name, source_id, source_sheet, detail, sep = "|")
  check_id <- digest::digest(key, algo = "sha256", serialize = FALSE)
  existing <- DBI::dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM quality_flags WHERE check_id = ", sql_string(check_id)))$n[[1]]
  if (!existing) DBI::dbWriteTable(con, "quality_flags", tibble(
    check_id = check_id, release_id = release_id, vintage_id = vintage_id,
    severity = severity, check_name = check_name, source_id = source_id,
    source_sheet = source_sheet, detail = detail, created_at = Sys.time()
  ), append = TRUE)
  invisible(check_id)
}

record_structure_check <- function(con, check, vintage_id, release_id) {
  check <- check %>% mutate(vintage_id = vintage_id, release_id = release_id,
                            checked_at = Sys.time(), .before = 1)
  DBI::dbWriteTable(con, "structure_checks", check, append = TRUE)
}

source_vintage_exists <- function(con, vintage_id) {
  DBI::dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM source_files WHERE vintage_id = ", sql_string(vintage_id)))$n[[1]] > 0
}

record_source_metadata <- function(con, item, dimensions, release_id, root) {
  publication_date <- infer_publication_date_from_name(item$source_file)
  publication_source <- if (is.na(publication_date)) "pending_content_inference" else "filename"
  archived <- archive_source(item$path, item$source_id, root, item$sha256, publication_date)
  publisher <- if ("publisher" %in% names(item)) as.character(item$publisher[[1]]) else NA_character_
  source_format <- if ("source_format" %in% names(item)) as.character(item$source_format[[1]]) else tools::file_ext(item$path)
  sheet_rows <- dimensions %>% mutate(
    vintage_id = item$vintage_id, release_id = release_id, source_id = item$source_id,
    source_file = item$source_file, ingest_mode = item$ingest_mode,
    structure_signature = NA_character_, .before = 1
  )
  if (!source_vintage_exists(con, item$vintage_id)) {
    info <- file.info(item$path)
    DBI::dbWriteTable(con, "source_files", tibble(
      vintage_id = item$vintage_id, release_id = release_id, source_id = item$source_id,
      source_label = item$source_label, publisher = publisher,
      source_format = source_format, source_file = item$source_file,
      source_path = normalizePath(item$path, winslash = "/"),
      archive_path = normalizePath(archived$path, winslash = "/"), sha256 = item$sha256,
      size_bytes = as.numeric(info$size), publication_date = publication_date,
      publication_date_source = publication_source, first_ingested_at = Sys.time(),
      ingestion_status = "started"
    ), append = TRUE)
    DBI::dbWriteTable(con, "source_sheets", sheet_rows, append = TRUE)
  } else {
    date_update <- if (is.na(publication_date)) "" else paste0(
      ", publication_date = ", sql_string(as.character(publication_date)),
      ", publication_date_source = 'filename'"
    )
    DBI::dbExecute(con, paste0(
      "UPDATE source_files SET publisher = ", if (is.na(publisher)) "NULL" else sql_string(publisher),
      ", source_format = ", if (is.na(source_format)) "NULL" else sql_string(source_format), date_update,
      " WHERE vintage_id = ", sql_string(item$vintage_id)
    ))
    DBI::dbExecute(con, paste0("DELETE FROM source_sheets WHERE vintage_id = ", sql_string(item$vintage_id)))
    DBI::dbWriteTable(con, "source_sheets", sheet_rows, append = TRUE)
  }
  list(publication_date = publication_date, archive_created = archived$created)
}

ensure_failed_source_metadata <- function(con, item, release_id) {
  if (source_vintage_exists(con, item$vintage_id)) {
    DBI::dbExecute(con, paste0(
      "UPDATE source_files SET release_id = ", sql_string(release_id),
      ", ingestion_status = 'failed_structure_or_ingestion' WHERE vintage_id = ",
      sql_string(item$vintage_id)
    ))
    return(invisible(FALSE))
  }
  info <- file.info(item$path)
  publisher <- if ("publisher" %in% names(item)) as.character(item$publisher[[1]]) else NA_character_
  source_format <- if ("source_format" %in% names(item)) as.character(item$source_format[[1]]) else tools::file_ext(item$path)
  DBI::dbWriteTable(con, "source_files", tibble::tibble(
    vintage_id = item$vintage_id, release_id = release_id, source_id = item$source_id,
    source_label = item$source_label, publisher = publisher, source_format = source_format,
    source_file = item$source_file,
    source_path = normalizePath(item$path, winslash = "/", mustWork = FALSE),
    archive_path = NA_character_, sha256 = item$sha256, size_bytes = as.numeric(info$size),
    publication_date = as.Date(NA), publication_date_source = "discovery_failed",
    first_ingested_at = Sys.time(), ingestion_status = "failed_structure_or_ingestion"
  ), append = TRUE)
  invisible(TRUE)
}

set_source_publication_date <- function(con, vintage_id, publication_date, source = "content_max_period") {
  if (is.na(publication_date)) return(invisible(NULL))
  DBI::dbExecute(con, paste0(
    "UPDATE source_files SET publication_date = ", sql_string(as.character(publication_date)),
    ", publication_date_source = ", sql_string(source), " WHERE vintage_id = ", sql_string(vintage_id),
    " AND (publication_date IS NULL OR publication_date_source = 'pending_content_inference')"
  ))
}

mark_source_status <- function(con, vintage_id, status) {
  DBI::dbExecute(con, paste0("UPDATE source_files SET ingestion_status = ", sql_string(status),
                             " WHERE vintage_id = ", sql_string(vintage_id)))
}

assert_direct_structure <- function(path, source_id, dimensions, root) {
  schemas <- readr::read_csv(file.path(root, "config", "direct_schema.csv"), show_col_types = FALSE) %>%
    filter(.data$source_id == .env$source_id)
  checks <- list()
  check <- assert_same_structure(schemas$sheet_name, dimensions$sheet_name, source_id, "<workbook>", "sheet_list")
  checks[[1]] <- check
  for (i in seq_len(nrow(schemas))) {
    sheet <- schemas$sheet_name[[i]]
    observed <- names(readxl::read_excel(path, sheet = sheet, n_max = 0, .name_repair = "minimal"))
    expected <- strsplit(schemas$expected_columns[[i]], "|", fixed = TRUE)[[1]]
    checks[[i + 1L]] <- assert_same_structure(expected, observed, source_id, sheet, "column_headers")
  }
  bind_rows(checks)
}

table_has_vintage <- function(con, table_name, vintage_id) {
  DBI::dbExistsTable(con, table_name) &&
    DBI::dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM ", DBI::dbQuoteIdentifier(con, table_name),
                                " WHERE vintage_id = ", sql_string(vintage_id)))$n[[1]] > 0
}

update_entity_dimension <- function(con, data, source_id, vintage_id, root) {
  if (!"codigo_entidad" %in% names(data)) return(invisible(NULL))
  entity_type <- if (source_id == "banks") "bank" else if (source_id == "financial") "finance_company" else "unknown"
  codes <- unique(as.character(stats::na.omit(data$codigo_entidad)))
  if (!length(codes)) return(invisible(NULL))
  candidates <- tibble(entity_id = paste(entity_type, codes, sep = ":"), entity_code = codes, entity_type = entity_type)
  dictionary_path <- file.path(root, "config", "entity_dictionary.csv")
  if (file.exists(dictionary_path)) {
    dictionary <- readr::read_csv(dictionary_path, col_types = cols(.default = col_character()))
    candidates <- candidates %>% left_join(dictionary, by = c("entity_type", "entity_code"))
  } else candidates <- candidates %>% mutate(entity_name = NA_character_, mapping_status = "name_unavailable_in_source")
  existing <- DBI::dbGetQuery(con, "SELECT entity_id FROM dim_entity")$entity_id
  candidates <- candidates %>% filter(!entity_id %in% existing) %>% mutate(
    legal_name = entity_name, short_name = NA_character_, ownership_type = NA_character_,
    mapping_status = coalesce(mapping_status, "name_unavailable_in_source"), first_vintage_id = vintage_id
  ) %>% select(entity_id, entity_code, entity_type, entity_name, legal_name, short_name,
               ownership_type, mapping_status, first_vintage_id)
  if (nrow(candidates)) DBI::dbWriteTable(con, "dim_entity", candidates, append = TRUE)
}

create_latest_raw_view <- function(con, table_name) {
  view <- paste0("v_latest_", table_name)
  DBI::dbExecute(con, paste0(
    "CREATE OR REPLACE VIEW ", DBI::dbQuoteIdentifier(con, view), " AS ",
    "SELECT * EXCLUDE(vintage_rank) FROM (SELECT *, dense_rank() OVER (PARTITION BY source_id ORDER BY publication_date DESC NULLS LAST, vintage_id DESC) AS vintage_rank FROM ",
    DBI::dbQuoteIdentifier(con, table_name), ") WHERE vintage_rank = 1"
  ))
}

ingest_direct_workbook <- function(con, item, dimensions, publication_date, release_id, root) {
  checks <- assert_direct_structure(item$path, item$source_id, dimensions, root)
  record_structure_check(con, checks, item$vintage_id, release_id)
  max_date <- as.Date(NA)
  for (i in seq_len(nrow(dimensions))) {
    sheet <- dimensions$sheet_name[[i]]
    table_name <- safe_table_name(item$source_id, sheet)
    if (table_has_vintage(con, table_name, item$vintage_id)) next
    data <- readxl::read_excel(item$path, sheet = sheet, .name_repair = "minimal") %>% janitor::clean_names()
    date_cols <- intersect(names(data), c("fecha"))
    if (length(date_cols)) {
      observed_dates <- as_excel_date(data[[date_cols[[1]]]])
      observed_dates <- observed_dates[!is.na(observed_dates)]
      if (length(observed_dates)) {
        assert_plausible_dates(observed_dates, item$source_id, sheet)
        candidate <- max(observed_dates)
        if (is.na(max_date) || candidate > max_date) max_date <- candidate
      }
    }
    data <- data %>% mutate(
      vintage_id = item$vintage_id, release_id = release_id, publication_date = publication_date,
      source_id = item$source_id, source_sheet = sheet, source_file = item$source_file, .before = 1
    )
    if (DBI::dbExistsTable(con, table_name)) DBI::dbWriteTable(con, table_name, data, append = TRUE)
    else DBI::dbWriteTable(con, table_name, data, overwrite = TRUE)
    update_entity_dimension(con, data, item$source_id, item$vintage_id, root)
    DBI::dbWriteTable(con, "semantic_coverage", tibble(
      vintage_id = item$vintage_id, source_id = item$source_id, source_sheet = sheet,
      semantic_status = item$semantic_status, raw_nonempty_cells = sum(!is.na(data)),
      curated_observations = nrow(data),
      coverage_note = if (item$semantic_status == "documented_panel")
        "Structured panel linked to verified entity, currency, account, ratio and activity reference dimensions."
      else "Structured source table retained with named dimensions and measures; not yet mapped to dim_series."
    ), append = TRUE)
    create_latest_raw_view(con, table_name)
  }
  create_documented_financial_views(con)
  if (is.na(publication_date) && !is.na(max_date)) {
    set_source_publication_date(con, item$vintage_id, max_date)
    update_archive_manifest_date(root, item$source_id, item$sha256, max_date)
    tables <- vapply(dimensions$sheet_name, function(sheet) safe_table_name(item$source_id, sheet), character(1))
    for (table_name in tables) if (DBI::dbExistsTable(con, table_name)) DBI::dbExecute(con, paste0(
      "UPDATE ", DBI::dbQuoteIdentifier(con, table_name),
      " SET publication_date = ", sql_string(as.character(max_date)),
      " WHERE vintage_id = ", sql_string(item$vintage_id), " AND publication_date IS NULL"
    ))
  }
}

cells_from_matrix <- function(data) {
  empty <- tibble::tibble(
    row_id = integer(), column_id = integer(), raw_value_text = character(),
    raw_value_num = double(), raw_value_date = as.Date(character())
  )
  if (!ncol(data)) return(empty)
  records <- vector("list", ncol(data))
  for (j in seq_along(data)) {
    x <- data[[j]]
    text_values <- cell_character(x)
    keep <- !is.na(text_values) & trimws(text_values) != ""
    if (!any(keep)) next
    numeric_values <- as_number_or_na(x)
    date_value <- as_typed_date(x)
    records[[j]] <- tibble(
      row_id = which(keep), column_id = j, raw_value_text = text_values[keep],
      raw_value_num = numeric_values[keep], raw_value_date = date_value[keep]
    )
  }
  result <- bind_rows(records)
  if (!nrow(result) && !ncol(result)) empty else result
}

report_sheet_version_id <- function(cells, source_id, source_sheet) {
  ordered <- cells %>% dplyr::arrange(.data$row_id, .data$column_id)
  payload <- if (!nrow(ordered)) "<EMPTY_SHEET>" else paste(
      ordered$row_id, ordered$column_id,
      ifelse(is.na(ordered$raw_value_text), "<NA>", ordered$raw_value_text),
      ifelse(is.na(ordered$raw_value_num), "<NA>", format(ordered$raw_value_num, digits = 17, scientific = FALSE, trim = TRUE)),
      ifelse(is.na(ordered$raw_value_date), "<NA>", as.character(ordered$raw_value_date)),
      sep = "\u001f", collapse = "\u001e"
    )
  paste0("report_sheet:", substr(digest::digest(
    paste(source_id, source_sheet, payload, sep = "\u001d"),
    algo = "sha256", serialize = FALSE
  ), 1, 32))
}

store_report_sheet_version <- function(con, cells, item, sheet, release_id,
                                       publication_date, structure_signature) {
  sheet_version_id <- report_sheet_version_id(cells, item$source_id, sheet)
  version_exists <- DBI::dbGetQuery(con, paste0(
    "SELECT COUNT(*) AS n FROM report_sheet_versions WHERE sheet_version_id = ",
    sql_string(sheet_version_id)
  ))$n[[1]] > 0
  if (!version_exists) {
    DBI::dbWriteTable(con, "report_sheet_versions", tibble(
      sheet_version_id = sheet_version_id, source_id = item$source_id,
      source_sheet = sheet, structure_signature = structure_signature,
      raw_nonempty_cells = nrow(cells), first_vintage_id = item$vintage_id,
      created_at = Sys.time()
    ), append = TRUE)
    if (nrow(cells)) DBI::dbWriteTable(con, "report_cell_values", cells %>%
      dplyr::mutate(sheet_version_id = sheet_version_id, .before = 1), append = TRUE)
  }
  link_exists <- DBI::dbGetQuery(con, paste0(
    "SELECT COUNT(*) AS n FROM report_sheet_vintages WHERE vintage_id = ",
    sql_string(item$vintage_id), " AND source_sheet = ", sql_string(sheet)
  ))$n[[1]] > 0
  if (!link_exists) DBI::dbWriteTable(con, "report_sheet_vintages", tibble(
    vintage_id = item$vintage_id, release_id = release_id,
    publication_date = as.Date(publication_date), source_id = item$source_id,
    source_file = item$source_file, source_sheet = sheet,
    sheet_version_id = sheet_version_id
  ), append = TRUE)
  invisible(list(sheet_version_id = sheet_version_id, new_content = !version_exists))
}

generic_report_signature <- function(data) {
  tokens <- character()
  text_rows <- 0L
  for (r in seq_len(nrow(data))) {
    row_has_text <- FALSE
    for (j in seq_len(min(ncol(data), 30L))) {
      value <- data[[j]][[r]]
      if (is.null(value) || !length(value) || all(is.na(value)) ||
          !nzchar(trimws(as.character(value[[1]])))) next
      value <- value[[1]]
      if (!is.na(suppressWarnings(as.numeric(value))) || inherits(value, c("Date", "POSIXt"))) next
      tokens <- c(tokens, paste(r, j, normalize_label(value), sep = ":"))
      row_has_text <- TRUE
    }
    if (row_has_text) text_rows <- text_rows + 1L
    if (text_rows >= 12L) break
  }
  structure_signature(tokens)
}

ingest_report_sheet_data <- function(con, item, sheet, data, publication_date, release_id,
                                     write_inventory_coverage = TRUE) {
  signature <- generic_report_signature(data)
  previous <- DBI::dbGetQuery(con, paste0(
    "SELECT s.structure_signature FROM source_sheets s JOIN source_files f USING (vintage_id) WHERE s.source_id = ",
    sql_string(item$source_id), " AND s.sheet_name = ", sql_string(sheet),
    " AND s.vintage_id <> ", sql_string(item$vintage_id),
    " AND s.structure_signature IS NOT NULL ORDER BY f.publication_date DESC NULLS LAST, f.first_ingested_at DESC LIMIT 1"
  ))
  DBI::dbExecute(con, paste0(
    "UPDATE source_sheets SET structure_signature = ", sql_string(signature),
    " WHERE vintage_id = ", sql_string(item$vintage_id), " AND sheet_name = ", sql_string(sheet)
  ))
  if (nrow(previous) && !identical(previous$structure_signature[[1]], signature)) insert_quality_flag(
    con, release_id, "warning", "report_structure_changed", item$source_id,
    "Header-text fingerprint changed. Raw coordinates were retained; any configured semantic parser validates coverage independently.", item$vintage_id, sheet
  )
  cells <- cells_from_matrix(data)
  store_report_sheet_version(con, cells, item, sheet, release_id, publication_date, signature)
  if (isTRUE(write_inventory_coverage)) {
    DBI::dbWriteTable(con, "semantic_coverage", tibble(
      vintage_id = item$vintage_id, source_id = item$source_id, source_sheet = sheet,
      semantic_status = item$semantic_status, raw_nonempty_cells = nrow(cells),
      curated_observations = 0L,
      coverage_note = if (item$semantic_status == "inventory_only") "Coordinate inventory only; not analytically queryable as a statistical series." else "Raw coordinate layer retained alongside curated output."
    ), append = TRUE)
  }
  invisible(list(signature = signature, raw_nonempty_cells = nrow(cells)))
}

ingest_report_workbook <- function(con, item, dimensions, publication_date, release_id) {
  for (i in seq_len(nrow(dimensions))) {
    sheet <- dimensions$sheet_name[[i]]
    data <- read_sheet_matrix(
      item$path, sheet, dimensions$used_rows[[i]], dimensions$used_cols[[i]],
      dimensions$content_first_row[[i]], dimensions$content_first_col[[i]],
      dimensions$content_last_row[[i]], dimensions$content_last_col[[i]]
    )
    ingest_report_sheet_data(
      con, item, sheet, data, publication_date, release_id,
      write_inventory_coverage = TRUE
    )
  }
}
