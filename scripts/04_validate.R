validate_fx_aggregates <- function(con, release_id, vintage_id, root) {
  if (!DBI::dbExistsTable(con, "fx_operations_snapshot")) return(invisible(NULL))
  fx <- DBI::dbGetQuery(con, paste0(
    "SELECT * FROM fx_operations_snapshot WHERE vintage_id = ", sql_string(vintage_id)
  )) %>% mutate(period = as.Date(period))
  if (!nrow(fx)) return(invisible(NULL))
  monthly <- fx %>% filter(frequency == "monthly") %>% mutate(quarter = quarter(period)) %>%
    group_by(sector, operation, year, quarter) %>% summarise(component_count = n(), calculated = sum(value), .groups = "drop")
  quarterly <- fx %>% filter(frequency == "quarterly") %>% mutate(quarter = quarter(period)) %>%
    select(sector, operation, year, quarter, published = value)
  qcheck <- monthly %>% inner_join(quarterly, by = c("sector", "operation", "year", "quarter")) %>%
    filter(component_count == 3L) %>% mutate(diff = published - calculated)
  bad_q <- qcheck %>% filter(abs(diff) > 1e-6)
  if (nrow(bad_q)) insert_quality_flag(
    con, release_id, "error", "fx_months_do_not_sum_to_quarter", "fx_operations",
    paste(nrow(bad_q), "sector-operation-quarter subtotals differ; max difference", max(abs(bad_q$diff))), vintage_id, "Datos"
  )
  qsum <- fx %>% filter(frequency == "quarterly") %>% group_by(sector, operation, year) %>%
    summarise(component_count = n(), calculated = sum(value), .groups = "drop")
  annual <- fx %>% filter(frequency == "annual") %>% select(sector, operation, year, published = value)
  acheck <- qsum %>% inner_join(annual, by = c("sector", "operation", "year")) %>%
    filter(component_count == 4L) %>% mutate(diff = published - calculated)
  bad_a <- acheck %>% filter(abs(diff) > 1e-6)
  exception_path <- file.path(root, "config", "validation_exceptions.csv")
  exceptions <- if (file.exists(exception_path)) readr::read_csv(exception_path, show_col_types = FALSE) else tibble()
  known_years <- exceptions %>% filter(source_id == "fx_operations", check_name == "fx_quarters_do_not_sum_to_year") %>% pull(period) %>% as.integer()
  known <- bad_a %>% filter(year %in% known_years)
  unexpected <- bad_a %>% filter(!year %in% known_years)
  if (nrow(known)) insert_quality_flag(
    con, release_id, "warning", "known_published_fx_non_additivity", "fx_operations",
    paste(nrow(known), "published annual subtotals differ in documented exception years; max difference", max(abs(known$diff))), vintage_id, "Datos"
  )
  if (nrow(unexpected)) insert_quality_flag(
    con, release_id, "error", "fx_quarters_do_not_sum_to_year", "fx_operations",
    paste(nrow(unexpected), "unexpected sector-operation-year subtotal differences; max difference", max(abs(unexpected$diff))), vintage_id, "Datos"
  )
  invisible(list(quarter_checks = nrow(qcheck), annual_checks = nrow(acheck)))
}

validate_curated_keys <- function(con, release_id, table_name, vintage_id, key_columns, source_id) {
  if (!DBI::dbExistsTable(con, table_name)) return(invisible(NULL))
  keys <- paste(DBI::dbQuoteIdentifier(con, key_columns), collapse = ", ")
  query <- paste0("SELECT COUNT(*) AS duplicate_groups FROM (SELECT ", keys, ", COUNT(*) AS n FROM ",
                  DBI::dbQuoteIdentifier(con, table_name), " WHERE vintage_id = ", sql_string(vintage_id),
                  " GROUP BY ", keys, " HAVING COUNT(*) > 1) duplicate_keys")
  n <- DBI::dbGetQuery(con, query)$duplicate_groups[[1]]
  if (n > 0) insert_quality_flag(con, release_id, "error", "duplicate_curated_keys", source_id,
                                 paste(n, "duplicate key groups in", table_name), vintage_id)
}

validate_documented_financial_source <- function(con, item, release_id) {
  checks <- list(
    eeff = c("entity_id", "currency_of_origin", "unit_currency", "semantic_classification"),
    ratios = c("entity_id", "semantic_classification"),
    carteras = c("entity_id", "currency_of_origin", "unit_currency", "semantic_classification"),
    credito_sector = c("entity_id", "currency_of_origin", "unit_currency", "credit_sector_id"),
    credito_actividad = c("entity_id", "currency_of_origin", "unit_currency", "activity_code", "credit_sector_id")
  )
  for (suffix in names(checks)) {
    view_name <- paste0("v_", item$source_id, "_", suffix, "_documented")
    if (!database_object_exists(con, view_name)) {
      insert_quality_flag(con, release_id, "error", "documented_view_missing", item$source_id,
                          paste("Expected semantic view not created:", view_name), item$vintage_id)
      next
    }
    fields <- checks[[suffix]]
    expressions <- c("COUNT(*) AS rows", vapply(fields, function(field) paste0(
      "SUM(CASE WHEN ", DBI::dbQuoteIdentifier(con, field), " IS NOT NULL THEN 1 ELSE 0 END) AS ",
      DBI::dbQuoteIdentifier(con, paste0("mapped_", field))
    ), character(1)))
    result <- DBI::dbGetQuery(con, paste0(
      "SELECT ", paste(expressions, collapse = ", "), " FROM ", DBI::dbQuoteIdentifier(con, view_name)
    ))
    if (!result$rows[[1]]) {
      insert_quality_flag(con, release_id, "error", "documented_view_empty", item$source_id,
                          paste(view_name, "contains no rows."), item$vintage_id)
      next
    }
    for (field in fields) {
      coverage <- result[[paste0("mapped_", field)]][[1]] / result$rows[[1]]
      threshold <- if (field %in% c("semantic_classification", "activity_code")) 0.999 else 1
      if (coverage < threshold) insert_quality_flag(
        con, release_id, if (coverage < 0.95) "error" else "warning",
        "documented_mapping_below_threshold", item$source_id,
        sprintf("%s maps %.3f%% of rows to %s; required %.1f%%.",
                view_name, 100 * coverage, field, 100 * threshold), item$vintage_id
      )
    }
  }
  invisible(NULL)
}

validate_currency_semantics <- function(con, item, release_id) {
  if (!DBI::dbExistsTable(con, "dim_currency")) return(invisible(NULL))
  invalid <- DBI::dbGetQuery(con, paste0(
    "SELECT currency_code, description, currency_of_origin, unit_currency FROM dim_currency WHERE ",
    "(currency_code = '6900' AND (currency_of_origin IS DISTINCT FROM 'PYG' OR unit_currency IS DISTINCT FROM 'PYG')) OR ",
    "(currency_code = '6200' AND (currency_of_origin IS DISTINCT FROM 'FX' OR unit_currency IS DISTINCT FROM 'PYG')) OR ",
    "(currency_code = '6100' AND (currency_of_origin IS DISTINCT FROM 'FX' OR unit_currency IS DISTINCT FROM 'USD')) OR ",
    "(lower(coalesce(description, '')) LIKE '%convertid%a gs.%' AND unit_currency IS DISTINCT FROM 'PYG')"
  ))
  if (nrow(invalid)) stop(
    "Currency semantic guard failed for code(s) ",
    paste(invalid$currency_code, collapse = ", "),
    ": currency origin or measurement unit conflicts with the BCP description/code rules.",
    call. = FALSE
  )
  invisible(NULL)
}

validate_nonshrinking_snapshot <- function(con, item, release_id, table_name) {
  if (!DBI::dbExistsTable(con, table_name)) return(invisible(NULL))
  current <- DBI::dbGetQuery(con, paste0(
    "SELECT COUNT(*) AS n FROM ", DBI::dbQuoteIdentifier(con, table_name),
    " WHERE vintage_id = ", sql_string(item$vintage_id)
  ))$n[[1]]
  previous <- DBI::dbGetQuery(con, paste0(
    "SELECT t.vintage_id, COUNT(*) AS n FROM ", DBI::dbQuoteIdentifier(con, table_name), " t ",
    "JOIN source_files f USING (vintage_id) WHERE f.source_id = ", sql_string(item$source_id),
    " AND t.vintage_id <> ", sql_string(item$vintage_id),
    " AND f.ingestion_status = 'completed' GROUP BY t.vintage_id, f.publication_date, f.first_ingested_at ",
    "ORDER BY f.publication_date DESC NULLS LAST, f.first_ingested_at DESC LIMIT 1"
  ))
  if (nrow(previous) && current < previous$n[[1]]) insert_quality_flag(
    con, release_id, "error", "snapshot_observation_count_shrank", item$source_id,
    paste(table_name, "contains", current, "rows versus", previous$n[[1]],
          "in the previous completed vintage."), item$vintage_id
  )
  invisible(NULL)
}

validate_long_csv_source <- function(con, item, release_id, root) {
  contracts <- readr::read_csv(
    file.path(root, "config", "long_csv_contracts.csv"),
    show_col_types = FALSE, col_types = readr::cols(.default = readr::col_character())
  )
  contract <- contracts %>% dplyr::filter(.data$source_id == .env$item$source_id)
  if (nrow(contract) != 1L) stop("Long-CSV contract missing for ", item$source_id, ".", call. = FALSE)
  table_name <- contract$table_name[[1]]
  date_column <- contract$date_column[[1]]
  key_column <- dplyr::na_if(contract$key_column[[1]], "")
  minimum_rows <- as.integer(contract$minimum_rows[[1]])
  current_where <- paste0("vintage_id = ", sql_string(item$vintage_id))
  summary <- DBI::dbGetQuery(con, paste0(
    "SELECT COUNT(*) AS rows, min(", DBI::dbQuoteIdentifier(con, date_column), ") AS first_date, max(",
    DBI::dbQuoteIdentifier(con, date_column), ") AS last_date FROM ",
    DBI::dbQuoteIdentifier(con, table_name), " WHERE ", current_where
  ))
  if (summary$rows[[1]] < minimum_rows) stop(
    "Long-CSV contract: ", table_name, " contains ", summary$rows[[1]],
    " valid rows; expected at least ", minimum_rows, ".", call. = FALSE
  )
  assert_plausible_dates(
    as.Date(as.character(c(summary$first_date[[1]], summary$last_date[[1]]))), item$source_id, "data",
    minimum = as.Date(contract$minimum_date[[1]])
  )
  if (!is.na(key_column)) {
    duplicate <- DBI::dbGetQuery(con, paste0(
      "SELECT COUNT(*) AS n FROM (SELECT ", DBI::dbQuoteIdentifier(con, key_column),
      " FROM ", DBI::dbQuoteIdentifier(con, table_name), " WHERE ", current_where,
      " GROUP BY 1 HAVING COUNT(*) > 1) x"
    ))$n[[1]]
    if (duplicate) stop("Long-CSV key guard: ", duplicate, " duplicate ", key_column,
                        " values in ", table_name, ".", call. = FALSE)
  }
  required_currencies <- strsplit(contract$required_currencies[[1]], "|", fixed = TRUE)[[1]]
  observed_currencies <- DBI::dbGetQuery(con, paste0(
    "SELECT DISTINCT currency FROM ", DBI::dbQuoteIdentifier(con, table_name),
    " WHERE ", current_where, " AND currency IS NOT NULL"
  ))$currency
  missing_currencies <- setdiff(required_currencies, observed_currencies)
  if (length(missing_currencies)) stop(
    "Long-CSV currency guard: missing ", paste(missing_currencies, collapse = ", "),
    " in ", table_name, ".", call. = FALSE
  )
  validate_nonshrinking_snapshot(con, item, release_id, table_name)
  invisible(summary)
}

validate_documented_source <- function(con, item, release_id, root) {
  current_where <- paste0("vintage_id = ", sql_string(item$vintage_id),
                          " AND source_id = ", sql_string(item$source_id))
  duplicate <- DBI::dbGetQuery(con, paste0(
    "SELECT COUNT(*) AS n FROM (SELECT series_id, period, COUNT(*) AS rows FROM documented_series_snapshot WHERE ",
    current_where, " GROUP BY 1,2 HAVING COUNT(*) > 1) x"
  ))$n[[1]]
  if (duplicate) stop("Documented-series validation found duplicate series-period keys for ",
                      item$source_id, ".", call. = FALSE)
  validate_nonshrinking_snapshot(con, item, release_id, "documented_series_snapshot")
  validate_documented_sheet_drift(con, item, release_id)
  validate_documented_series_continuity(con, item, release_id, root)
  inconsistent_metadata <- DBI::dbGetQuery(con, paste0(
    "SELECT COUNT(*) AS n FROM (SELECT series_id FROM documented_series_snapshot WHERE ", current_where,
    " GROUP BY series_id HAVING COUNT(DISTINCT concat_ws('|', unit, scale, coalesce(currency, ''))) > 1) x"
  ))$n[[1]]
  if (inconsistent_metadata) stop("Documented-series metadata guard: ", inconsistent_metadata,
                                  " series have inconsistent unit/scale/currency within one vintage.", call. = FALSE)
  invalid_scale <- DBI::dbGetQuery(con, paste0(
    "SELECT COUNT(*) AS n FROM documented_series_snapshot WHERE ", current_where,
    " AND unit IN ('index','percent','ratio','count','days') AND scale <> 'units'"
  ))$n[[1]]
  if (invalid_scale) stop("Documented-series scale guard: ", invalid_scale,
                          " index/percent/ratio/count/day observations have a non-unit scale.", call. = FALSE)
  positional <- DBI::dbGetQuery(con, paste0(
    "SELECT COUNT(DISTINCT series_id) AS n FROM documented_series_snapshot WHERE ", current_where,
    " AND identity_stability LIKE 'positional%'"
  ))$n[[1]]
  if (positional) insert_quality_flag(
    con, release_id, "warning", "positional_series_identity", item$source_id,
    paste(positional, "series required a positional disambiguator; inspect identity_stability before relying on automated continuity."),
    item$vintage_id
  )
  positional_lane <- DBI::dbGetQuery(con, paste0(
    "SELECT COUNT(DISTINCT series_id) AS n FROM documented_series_snapshot WHERE ", current_where,
    " AND identity_stability = 'positional_lane'"
  ))$n[[1]]
  if (positional_lane) insert_quality_flag(
    con, release_id, "warning", "positional_lane_series_identity", item$source_id,
    paste(positional_lane, "series represent repeated same-period source rows/cells that have no unique published semantic identifier; all values were retained in deterministic within-period lanes."),
    item$vintage_id
  )
  unresolved <- DBI::dbGetQuery(con, paste0(
    "SELECT COUNT(*) AS n FROM documented_table_catalog WHERE vintage_id = ", sql_string(item$vintage_id),
    " AND hierarchy_status = 'unresolved' AND parse_status = 'documented_series'"
  ))$n[[1]]
  if (unresolved) insert_quality_flag(
    con, release_id, "warning", "documented_hierarchy_unresolved", item$source_id,
    paste(unresolved, "parsed sheets contain aggregates/components whose parent-child hierarchy is not fully encoded; do not sum all series blindly."),
    item$vintage_id
  )
  unknown <- DBI::dbGetQuery(con, paste0(
    "SELECT COUNT(*) FILTER (WHERE unit = 'source_units') AS unknown, ",
    "COUNT(*) FILTER (WHERE unit <> 'source_units') AS known, COUNT(*) AS total ",
    "FROM documented_series_snapshot WHERE ", current_where
  ))
  unknown_share <- if (unknown$total[[1]] > 0) 1 - unknown$known[[1]] / unknown$total[[1]] else 1
  if (unknown_share > 0.15) insert_quality_flag(
    con, release_id, "warning", "documented_units_need_review", item$source_id,
    sprintf("%.2f%% of observations retain source_units because the workbook does not state a unique unit in the parsed title/header path.",
            100 * unknown_share), item$vintage_id
  )
  if (item$source_id == "economic_annex") {
    key <- DBI::dbGetQuery(con, paste0(
      "SELECT source_sheet, frequency, unit, COUNT(*) AS n FROM documented_series_snapshot WHERE ", current_where,
      " AND source_sheet IN ('CUADRO 1', 'CUADRO 9') GROUP BY 1,2,3"
    ))
    if (!any(key$source_sheet == "CUADRO 1" & key$frequency == "annual" & key$unit == "PYG") ||
        !any(key$source_sheet == "CUADRO 9" & key$frequency == "monthly" & key$unit == "index")) {
      stop("Economic-annex semantic guard failed for annual GDP or monthly IMAEP metadata.", call. = FALSE)
    }
  }
  if (item$source_id == "payments") {
    participants <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM dim_payment_participant")$n[[1]]
    if (participants < 20L) stop("Payments reference guard: fewer than 20 BIC participants loaded.", call. = FALSE)
  }
  if (item$source_id == "exchange_houses") {
    unmapped <- DBI::dbGetQuery(con, paste0(
      "SELECT COUNT(*) AS n FROM documented_series_snapshot WHERE ", current_where,
      " AND (entity_id IS NULL OR exchange_item_id IS NULL)"
    ))$n[[1]]
    if (unmapped) stop("Exchange-house semantic guard: ", unmapped,
                       " observations have no verified entity or item mapping.", call. = FALSE)
    validate_currency_semantics(con, item, release_id)
  }
  if (item$source_id == "credit_survey") {
    invalid <- DBI::dbGetQuery(con, paste0(
      "SELECT COUNT(*) AS n FROM documented_series_snapshot WHERE ", current_where,
      " AND ((source_sheet = '%' AND (value < 0 OR value > 1.01)) OR ",
      "(source_sheet = 'Índices' AND (value < 0 OR value > 100.01)))"
    ))$n[[1]]
    if (invalid) stop("Credit-survey range guard failed for ", invalid, " observations.", call. = FALSE)
  }
  invisible(NULL)
}

validate_documented_series_continuity <- function(con, item, release_id, root) {
  previous <- DBI::dbGetQuery(con, paste0(
    "SELECT d.vintage_id, f.publication_date, f.first_ingested_at FROM documented_series_snapshot d ",
    "JOIN source_files f USING (vintage_id) WHERE d.source_id = ", sql_string(item$source_id),
    " AND d.vintage_id <> ", sql_string(item$vintage_id), " AND f.ingestion_status = 'completed' ",
    "GROUP BY 1,2,3 ORDER BY f.publication_date DESC NULLS LAST, f.first_ingested_at DESC NULLS LAST LIMIT 1"
  ))
  DBI::dbExecute(con, paste0("DELETE FROM documented_series_continuity WHERE vintage_id = ", sql_string(item$vintage_id)))
  if (!nrow(previous)) return(invisible(tibble::tibble()))
  fields <- paste(
    "series_id",
    "any_value(source_sheet) AS source_sheet",
    "any_value(series_label) AS label",
    "any_value(unit) AS unit",
    "any_value(scale) AS scale",
    "any_value(currency) AS currency",
    "any_value(identity_stability) AS identity_stability",
    sep = ", "
  )
  prior <- DBI::dbGetQuery(con, paste0("SELECT ", fields, " FROM documented_series_snapshot WHERE vintage_id = ",
                                      sql_string(previous$vintage_id[[1]]), " GROUP BY series_id"))
  current <- DBI::dbGetQuery(con, paste0("SELECT ", fields, " FROM documented_series_snapshot WHERE vintage_id = ",
                                        sql_string(item$vintage_id), " GROUP BY series_id"))
  names(prior)[-1] <- paste0("previous_", names(prior)[-1])
  names(current)[-1] <- paste0("current_", names(current)[-1])
  changes <- dplyr::full_join(prior, current, by = "series_id") %>% dplyr::mutate(
    change_type = dplyr::case_when(
      is.na(.data$current_label) ~ "disappeared",
      is.na(.data$previous_label) ~ "new",
      dplyr::coalesce(.data$previous_unit, "") != dplyr::coalesce(.data$current_unit, "") |
        dplyr::coalesce(.data$previous_scale, "") != dplyr::coalesce(.data$current_scale, "") |
        dplyr::coalesce(.data$previous_currency, "") != dplyr::coalesce(.data$current_currency, "") ~ "metadata_changed",
      TRUE ~ "continued"
    ),
    vintage_id = item$vintage_id, previous_vintage_id = previous$vintage_id[[1]], source_id = item$source_id,
    source_sheet = dplyr::coalesce(.data$current_source_sheet, .data$previous_source_sheet),
    identity_stability = dplyr::coalesce(.data$current_identity_stability, .data$previous_identity_stability)
  ) %>% dplyr::filter(.data$change_type != "continued") %>% dplyr::transmute(
    vintage_id, previous_vintage_id, source_id, series_id, source_sheet, change_type,
    previous_label, current_label, previous_unit, current_unit, previous_scale, current_scale,
    previous_currency, current_currency, identity_stability
  )
  if (nrow(changes)) DBI::dbWriteTable(con, "documented_series_continuity", changes, append = TRUE)
  contracts <- readr::read_csv(file.path(root, "config", "documented_source_contracts.csv"), show_col_types = FALSE)
  threshold <- contracts$maximum_disappeared_series[match(item$source_id, contracts$source_id)]
  threshold <- ifelse(length(threshold) && !is.na(threshold), threshold, 0L)
  disappeared <- changes %>% dplyr::filter(.data$change_type == "disappeared")
  continuity_errors <- tibble::tibble(check_name = character(), detail = character())
  if (nrow(disappeared) > threshold) {
    examples <- paste(head(paste0(disappeared$source_sheet, ": ", disappeared$previous_label), 20L), collapse = "; ")
    continuity_errors <- dplyr::add_row(
      continuity_errors, check_name = "documented_series_identity_break",
      detail = paste0(nrow(disappeared), " series disappeared versus ", previous$vintage_id[[1]],
                      " (allowed ", threshold, "). A likely parser/identity break affected: ", examples)
    )
  }
  metadata_changed <- changes %>% dplyr::filter(.data$change_type == "metadata_changed")
  if (nrow(metadata_changed)) {
    examples <- paste(head(paste0(metadata_changed$source_sheet, ": ", metadata_changed$current_label,
      " [", metadata_changed$previous_unit, "/", metadata_changed$previous_scale, " -> ",
      metadata_changed$current_unit, "/", metadata_changed$current_scale, "]"), 20L), collapse = "; ")
    continuity_errors <- dplyr::add_row(
      continuity_errors, check_name = "documented_series_metadata_changed",
      detail = paste0(nrow(metadata_changed), " continuing series changed unit, scale or currency: ", examples)
    )
  }
  if (nrow(continuity_errors)) {
    stop(structure(
      list(
        message = paste(continuity_errors$detail, collapse = " | "), call = NULL,
        changes = changes, quality_records = continuity_errors,
        source_id = item$source_id, vintage_id = item$vintage_id
      ),
      class = c("documented_continuity_error", "error", "condition")
    ))
  }
  invisible(changes)
}

validate_documented_sheet_drift <- function(con, item, release_id) {
  previous <- DBI::dbGetQuery(con, paste0(
    "SELECT c.vintage_id, f.publication_date, f.first_ingested_at FROM documented_table_catalog c ",
    "JOIN source_files f USING (vintage_id) WHERE c.source_id = ", sql_string(item$source_id),
    " AND c.vintage_id <> ", sql_string(item$vintage_id),
    " AND f.ingestion_status = 'completed' GROUP BY 1,2,3 ",
    "ORDER BY f.publication_date DESC NULLS LAST, f.first_ingested_at DESC NULLS LAST LIMIT 1"
  ))
  DBI::dbExecute(con, paste0("DELETE FROM documented_sheet_drift WHERE vintage_id = ", sql_string(item$vintage_id)))
  if (!nrow(previous)) return(invisible(tibble::tibble()))
  current <- DBI::dbGetQuery(con, paste0(
    "SELECT source_sheet, parsed_observations AS current_observations, series_count AS current_series ",
    "FROM documented_table_catalog WHERE vintage_id = ", sql_string(item$vintage_id)
  ))
  prior <- DBI::dbGetQuery(con, paste0(
    "SELECT source_sheet, parsed_observations AS previous_observations, series_count AS previous_series ",
    "FROM documented_table_catalog WHERE vintage_id = ", sql_string(previous$vintage_id[[1]])
  ))
  drift <- dplyr::full_join(prior, current, by = "source_sheet") %>% dplyr::mutate(
    vintage_id = item$vintage_id, previous_vintage_id = previous$vintage_id[[1]], source_id = item$source_id,
    observation_change = .data$current_observations - .data$previous_observations,
    series_change = .data$current_series - .data$previous_series,
    drift_status = dplyr::case_when(
      is.na(.data$current_observations) ~ "missing_sheet",
      is.na(.data$previous_observations) ~ "new_sheet",
      .data$current_observations < .data$previous_observations ~ "observations_shrank",
      .data$current_series < .data$previous_series ~ "series_shrank",
      .data$current_observations > .data$previous_observations | .data$current_series > .data$previous_series ~ "grew",
      TRUE ~ "unchanged"
    )
  ) %>% dplyr::select(
    .data$vintage_id, .data$previous_vintage_id, .data$source_id, .data$source_sheet,
    .data$previous_observations, .data$current_observations, .data$observation_change,
    .data$previous_series, .data$current_series, .data$series_change, .data$drift_status
  )
  DBI::dbWriteTable(con, "documented_sheet_drift", drift, append = TRUE)
  risky <- drift %>% dplyr::filter(.data$drift_status %in% c("missing_sheet", "observations_shrank", "series_shrank"))
  if (nrow(risky)) for (i in seq_len(nrow(risky))) insert_quality_flag(
    con, release_id, "error", "documented_sheet_coverage_shrank", item$source_id,
    paste0("Sheet changed from ", risky$previous_observations[[i]], " to ",
           dplyr::coalesce(risky$current_observations[[i]], 0L), " observations and from ",
           risky$previous_series[[i]], " to ", dplyr::coalesce(risky$current_series[[i]], 0L),
           " series versus vintage ", risky$previous_vintage_id[[i]], "."),
    item$vintage_id, risky$source_sheet[[i]]
  )
  invisible(drift)
}

validate_source <- function(con, item, release_id, root) {
  if (item$source_id == "bank_reference") {
    expectations <- c(reference_table_loads = 15L, dim_currency = 2L,
                      dim_entity = 31L, dim_credit_activity = 1112L,
                      dim_credit_sector = 13L,
                      dim_statement_item = 218L, map_statement_account = 456L,
                      dim_ratio = 80L, dim_portfolio_item = 36L,
                      map_portfolio_account = 157L)
    for (table_name in names(expectations)) {
      observed <- DBI::dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM ",
        DBI::dbQuoteIdentifier(con, table_name)))$n[[1]]
      if (observed < expectations[[table_name]]) insert_quality_flag(
        con, release_id, "error", "reference_dimension_incomplete", "bank_reference",
        paste(table_name, "contains", observed, "rows; expected at least", expectations[[table_name]]),
        item$vintage_id
      )
    }
    validate_currency_semantics(con, item, release_id)
  }
  if (item$source_id == "icc" && DBI::dbExistsTable(con, "consumer_confidence_snapshot")) {
    range <- DBI::dbGetQuery(con, paste0("SELECT min(value) AS min_value, max(value) AS max_value FROM consumer_confidence_snapshot WHERE vintage_id = ", sql_string(item$vintage_id)))
    if (range$min_value[[1]] < 0 || range$max_value[[1]] > 100) insert_quality_flag(
      con, release_id, "error", "icc_out_of_range", "icc", "ICC contains values outside 0–100.", item$vintage_id, "Índices"
    )
    validate_curated_keys(con, release_id, "consumer_confidence_snapshot", item$vintage_id, c("date", "metric"), "icc")
    validate_nonshrinking_snapshot(con, item, release_id, "consumer_confidence_snapshot")
  }
  if (item$source_id == "eve") {
    validate_curated_keys(con, release_id, "eve_expectations_snapshot", item$vintage_id, c("date", "block", "variable"), "eve")
    validate_nonshrinking_snapshot(con, item, release_id, "eve_expectations_snapshot")
  }
  if (item$source_id == "fx_operations") {
    validate_curated_keys(con, release_id, "fx_operations_snapshot", item$vintage_id, c("period", "frequency", "sector", "operation"), "fx_operations")
    validate_nonshrinking_snapshot(con, item, release_id, "fx_operations_snapshot")
    validate_fx_aggregates(con, release_id, item$vintage_id, root)
  }
  if (item$ingest_mode == "long_csv") validate_long_csv_source(con, item, release_id, root)
  if (item$ingest_mode == "semantic_table") validate_documented_source(con, item, release_id, root)
  if (item$source_id %in% c("banks", "financial")) {
    validate_documented_financial_source(con, item, release_id)
  }
}

validate_database <- function(con, manifest, release_id, root) {
  required <- c("source_files", "source_sheets", "report_sheet_versions", "report_sheet_vintages",
                "report_cell_values", "report_cells", "dim_series", "fact_series_events",
                "quality_flags", "dim_entity", "dim_currency", "dim_statement_item",
                "dim_ratio", "dim_portfolio_item", "dim_credit_activity", "dim_credit_sector",
                "documented_table_catalog", "documented_series_snapshot", "dim_payment_participant",
                "dim_exchange_item", "documented_sheet_drift", "documented_series_continuity",
                "dim_concept", "map_series_concept", "bond_curve_snapshot", "securities_transactions_snapshot",
                "table_status")
  for (tbl in required) if (!database_object_exists(con, tbl)) insert_quality_flag(
    con, release_id, "error", "missing_table", NA_character_, paste("Expected table not created:", tbl)
  )
  failed_sources <- DBI::dbGetQuery(con, paste0(
    "SELECT source_id, ingestion_status FROM source_files WHERE vintage_id IN (",
    paste(vapply(manifest$vintage_id, sql_string, character(1)), collapse = ","),
    ") AND ingestion_status <> 'completed'"
  ))
  if (nrow(failed_sources)) insert_quality_flag(
    con, release_id, "error", "incomplete_source_vintages", NA_character_,
    paste(nrow(failed_sources), "source vintages did not complete:",
          paste(failed_sources$source_id, collapse = "; "))
  )
  if (DBI::dbExistsTable(con, "fact_series_events")) {
    date_range <- DBI::dbGetQuery(con, "SELECT min(period) AS minimum, max(period) AS maximum FROM fact_series_events")
    if (nrow(date_range) && !is.na(date_range$minimum[[1]])) {
      minimum <- as.Date(date_range$minimum[[1]])
      maximum <- as.Date(date_range$maximum[[1]])
      contracts_path <- file.path(root, "config", "documented_source_contracts.csv")
      contract_horizons <- if (file.exists(contracts_path)) {
        readr::read_csv(contracts_path, show_col_types = FALSE)$maximum_future_days
      } else {
        integer()
      }
      future_days_ceiling <- max(c(400L, contract_horizons), na.rm = TRUE)
      if (minimum < as.Date("1900-01-01") || maximum > Sys.Date() + future_days_ceiling) insert_quality_flag(
        con, release_id, "error", "implausible_semantic_date_range", NA_character_,
        paste("Semantic observations span", minimum, "to", maximum)
      )
    }
  }
  missing_concepts <- DBI::dbGetQuery(con, paste(
    "SELECT COUNT(*) AS n FROM dim_series s LEFT JOIN map_series_concept m USING (series_id)",
    "WHERE m.series_id IS NULL"
  ))$n[[1]]
  if (missing_concepts) insert_quality_flag(
    con, release_id, "error", "series_without_concept_identity", NA_character_,
    paste(missing_concepts, "series have no explicit concept relationship.")
  )
  invalid_reviewed <- DBI::dbGetQuery(con, paste(
    "SELECT COUNT(*) AS n FROM map_series_concept WHERE mapping_status = 'reviewed' AND",
    "(evidence IS NULL OR trim(evidence) = '' OR reviewed_by IS NULL OR trim(reviewed_by) = '' OR reviewed_at IS NULL)"
  ))$n[[1]]
  if (invalid_reviewed) insert_quality_flag(
    con, release_id, "error", "reviewed_concept_mapping_incomplete", NA_character_,
    paste(invalid_reviewed, "reviewed concept mappings lack evidence or review metadata.")
  )
  # Research-readiness gate: no series may reach the catalogue without a
  # declared table status. 'unreviewed' means a source or worksheet appeared in
  # the database that config/table_status.csv never accounted for -- exactly the
  # silent expansion of the research surface the audit warns about.
  if (database_object_exists(con, "v_series_table_status")) {
    unreviewed <- DBI::dbGetQuery(con, paste(
      "SELECT source_id, source_sheet, COUNT(*) AS n FROM v_series_table_status",
      "WHERE status = 'unreviewed' GROUP BY 1, 2 ORDER BY 3 DESC"
    ))
    if (nrow(unreviewed)) insert_quality_flag(
      con, release_id, "error", "table_status_incomplete", NA_character_,
      paste0(
        sum(unreviewed$n), " series in ", nrow(unreviewed),
        " source tables have no row in config/table_status.csv: ",
        paste(head(paste0(unreviewed$source_id, "/", unreviewed$source_sheet), 10), collapse = "; ")
      )
    )
    quarantined <- DBI::dbGetQuery(con, paste(
      "SELECT COUNT(*) AS n FROM v_series_table_status WHERE status IN ('quarantined', 'needs_remodeling')"
    ))$n[[1]]
    if (quarantined) insert_quality_flag(
      con, release_id, "warning", "series_excluded_from_research_views", NA_character_,
      paste(quarantined, "series belong to tables marked quarantined or needs_remodeling and are excluded from v_research_series.")
    )
  }
  view_names <- unlist(lapply(c("banks", "financial"), function(source_id) paste0(
    "v_", source_id, "_", c("eeff", "ratios", "carteras", "credito_sector", "credito_actividad"),
    "_documented"
  )))
  documented_coverage <- list()
  for (view_name in view_names) if (database_object_exists(con, view_name)) {
    columns <- DBI::dbGetQuery(con, paste0("PRAGMA table_info(", sql_string(view_name), ")"))$name
    mapped_fields <- intersect(c("entity_id", "currency_of_origin", "unit_currency", "semantic_classification", "activity_code", "credit_sector_id"), columns)
    expressions <- c("COUNT(*) AS rows", vapply(mapped_fields, function(field) paste0(
      "SUM(CASE WHEN ", DBI::dbQuoteIdentifier(con, field), " IS NOT NULL THEN 1 ELSE 0 END) AS mapped_", field
    ), character(1)))
    documented_coverage[[view_name]] <- DBI::dbGetQuery(con, paste0(
      "SELECT ", paste(expressions, collapse = ", "), " FROM ", DBI::dbQuoteIdentifier(con, view_name)
    )) %>% mutate(view_name = view_name, .before = 1)
  }
  if (length(documented_coverage)) readr::write_csv(
    dplyr::bind_rows(documented_coverage), file.path(root, "outputs", "documented_financial_coverage_latest.csv")
  )
  legacy_rows <- if (DBI::dbExistsTable(con, "report_cells_legacy")) {
    DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM report_cells_legacy")$n[[1]]
  } else 0
  report_storage <- DBI::dbGetQuery(con, paste0(
    "SELECT (SELECT COUNT(*) FROM report_sheet_vintages) AS vintage_sheet_links, ",
    "(SELECT COUNT(*) FROM report_sheet_versions) AS distinct_sheet_versions, ",
    "(SELECT COUNT(*) FROM report_cell_values) AS sparse_physical_cells, ",
    "(SELECT COUNT(*) FROM report_cells) AS logical_vintage_cells"
  )) %>% dplyr::mutate(
    legacy_physical_cells = legacy_rows,
    physical_cells = .data$sparse_physical_cells + .data$legacy_physical_cells,
    logical_to_physical_ratio = dplyr::if_else(.data$physical_cells > 0,
                                                .data$logical_vintage_cells / .data$physical_cells,
                                                NA_real_)
  )
  readr::write_csv(report_storage, file.path(root, "outputs", "report_storage_latest.csv"))
  documented_catalog <- DBI::dbGetQuery(con, paste0(
    "SELECT c.* FROM documented_table_catalog c JOIN release_sources r USING (vintage_id) WHERE r.release_id = ",
    sql_string(release_id), " ORDER BY source_id, source_sheet"
  ))
  readr::write_csv(documented_catalog, file.path(root, "outputs", "documented_source_coverage_latest.csv"))
  documented_drift <- DBI::dbGetQuery(con, paste0(
    "SELECT d.* FROM documented_sheet_drift d JOIN release_sources r USING (vintage_id) WHERE r.release_id = ",
    sql_string(release_id), " ORDER BY source_id, source_sheet"
  ))
  readr::write_csv(documented_drift, file.path(root, "outputs", "documented_sheet_drift_latest.csv"))
  documented_continuity <- DBI::dbGetQuery(con, paste0(
    "SELECT d.* FROM documented_series_continuity d JOIN release_sources r USING (vintage_id) WHERE r.release_id = ",
    sql_string(release_id), " ORDER BY source_id, change_type, source_sheet, series_id"
  ))
  readr::write_csv(documented_continuity, file.path(root, "outputs", "documented_series_continuity_latest.csv"))
  coverage <- DBI::dbGetQuery(con, paste0(
    "SELECT source_id, semantic_status, sum(raw_nonempty_cells) AS raw_cells, sum(curated_observations) AS curated_observations FROM semantic_coverage WHERE vintage_id IN (",
    paste(vapply(manifest$vintage_id, sql_string, character(1)), collapse = ","), ") GROUP BY 1,2 ORDER BY 1"
  ))
  readr::write_csv(coverage, file.path(root, "outputs", "semantic_coverage_latest.csv"))
  flags <- DBI::dbGetQuery(con, paste0("SELECT * FROM quality_flags WHERE release_id = ", sql_string(release_id), " ORDER BY severity, source_id"))
  readr::write_csv(flags, file.path(root, "outputs", "quality_flags_latest.csv"))
  invisible(flags)
}

write_update_report <- function(con, release_id, root) {
  sources <- DBI::dbGetQuery(con, paste0(
    "SELECT f.source_id, f.source_file, f.vintage_id, f.publication_date, f.publication_date_source, f.ingestion_status FROM source_files f JOIN release_sources r USING (vintage_id) WHERE r.release_id = ", sql_string(release_id), " ORDER BY f.source_id"
  ))
  coverage <- if (file.exists(file.path(root, "outputs", "semantic_coverage_latest.csv"))) readr::read_csv(file.path(root, "outputs", "semantic_coverage_latest.csv"), show_col_types = FALSE) else tibble()
  mapping_path <- file.path(root, "outputs", "documented_financial_coverage_latest.csv")
  mappings <- if (file.exists(mapping_path)) readr::read_csv(mapping_path, show_col_types = FALSE) else tibble()
  flags <- DBI::dbGetQuery(con, paste0(
    "SELECT severity, source_id, check_name, detail FROM quality_flags WHERE release_id = ", sql_string(release_id), " ORDER BY severity, source_id"
  ))
  timings <- DBI::dbGetQuery(con, paste0(
    "SELECT source_id, stage, elapsed_seconds FROM ingestion_stage_timings WHERE release_id = ",
    sql_string(release_id), " ORDER BY source_id, stage"
  ))
  source_lines <- if (nrow(sources)) vapply(seq_len(nrow(sources)), function(i) sprintf(
    "- **%s** — `%s`; vintage `%s`; publication date `%s` (%s); status `%s`",
    sources$source_id[[i]], sources$source_file[[i]], sources$vintage_id[[i]],
    ifelse(is.na(sources$publication_date[[i]]), "unknown", as.character(sources$publication_date[[i]])),
    sources$publication_date_source[[i]], sources$ingestion_status[[i]]
  ), character(1)) else "- No sources processed."
  coverage_lines <- if (nrow(coverage)) vapply(seq_len(nrow(coverage)), function(i) sprintf(
    "- **%s** — `%s`; raw cells: %s; curated observations: %s",
    coverage$source_id[[i]], coverage$semantic_status[[i]], coverage$raw_cells[[i]], coverage$curated_observations[[i]]
  ), character(1)) else "- No coverage records."
  mapping_lines <- if (nrow(mappings)) vapply(seq_len(nrow(mappings)), function(i) {
    metrics <- setdiff(names(mappings), "view_name")
    metrics <- metrics[!vapply(metrics, function(metric) is.na(mappings[[metric]][[i]]), logical(1))]
    values <- vapply(metrics, function(metric) paste0(metric, ": ", mappings[[metric]][[i]]), character(1))
    paste0("- **", mappings$view_name[[i]], "** — ", paste(values, collapse = "; "))
  }, character(1)) else "- No documented financial views."
  flag_lines <- if (nrow(flags)) vapply(seq_len(nrow(flags)), function(i) sprintf(
    "- **%s / %s / %s:** %s", flags$severity[[i]], flags$source_id[[i]], flags$check_name[[i]], flags$detail[[i]]
  ), character(1)) else "- No quality flags."
  timing_lines <- if (nrow(timings)) vapply(seq_len(nrow(timings)), function(i) sprintf(
    "- **%s / %s:** %.2f seconds", timings$source_id[[i]], timings$stage[[i]], timings$elapsed_seconds[[i]]
  ), character(1)) else "- No timing records."
  lines <- c(
    "# Paraguay macro database — update report", "", paste("Deterministic release:", release_id), "",
    "## Source vintages", "", source_lines, "", "## Semantic coverage", "", coverage_lines, "",
    "## Documented financial mapping coverage", "", mapping_lines, "",
    "## Pipeline timings", "", timing_lines, "",
    "## Quality flags", "", flag_lines, "",
    "Documented-table sources are analytically queryable. Values whose workbook headers do not identify a unique unit remain explicitly marked as `source_units` pending review."
  )
  write_markdown_report(file.path(root, "outputs", "update_report.md"), lines)
}
