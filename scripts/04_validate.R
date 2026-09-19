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
    # The unfiltered twin, and scoped to the vintage this call is validating.
    # This asks whether *this* ingestion mapped its rows to entities, currencies
    # and statement items -- an ingestion question, asked inside the source's own
    # transaction, before the release has been accepted and therefore before the
    # published view can see anything at all.
    published_name <- paste0("v_", item$source_id, "_", suffix, "_documented")
    view_name <- paste0(published_name, "_all")
    if (!database_object_exists(con, view_name)) {
      insert_quality_flag(con, release_id, "error", "documented_view_missing", item$source_id,
                          paste("Expected semantic view not created:", published_name), item$vintage_id)
      next
    }
    fields <- checks[[suffix]]
    expressions <- c("COUNT(*) AS rows", vapply(fields, function(field) paste0(
      "SUM(CASE WHEN ", DBI::dbQuoteIdentifier(con, field), " IS NOT NULL THEN 1 ELSE 0 END) AS ",
      DBI::dbQuoteIdentifier(con, paste0("mapped_", field))
    ), character(1)))
    result <- DBI::dbGetQuery(con, paste0(
      "SELECT ", paste(expressions, collapse = ", "), " FROM ", DBI::dbQuoteIdentifier(con, view_name),
      " WHERE vintage_id = ", sql_string(item$vintage_id)
    ))
    if (!result$rows[[1]]) {
      insert_quality_flag(con, release_id, "error", "documented_view_empty", item$source_id,
                          paste(published_name, "contains no rows for this vintage."), item$vintage_id)
      next
    }
    for (field in fields) {
      coverage <- result[[paste0("mapped_", field)]][[1]] / result$rows[[1]]
      threshold <- if (field %in% c("semantic_classification", "activity_code")) 0.999 else 1
      if (coverage < threshold) insert_quality_flag(
        con, release_id, if (coverage < 0.95) "error" else "warning",
        "documented_mapping_below_threshold", item$source_id,
        sprintf("%s maps %.3f%% of rows to %s; required %.1f%%.",
                published_name, 100 * coverage, field, 100 * threshold), item$vintage_id
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
    "vintage_id", "previous_vintage_id", "source_id", "source_sheet",
    "previous_observations", "current_observations", "observation_change",
    "previous_series", "current_series", "series_change", "drift_status"
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
  if (item$ingest_mode == "imf_wide") {
    counts <- DBI::dbGetQuery(con, paste0(
      "SELECT (SELECT count(*) FROM ", project_qualified_name("imf_raw_records"),
      " WHERE vintage_id=", sql_string(item$vintage_id), ") records,",
      "(SELECT count(distinct series_code) FROM ", project_qualified_name("imf_series_snapshot"),
      " WHERE vintage_id=", sql_string(item$vintage_id), ") series,",
      "(SELECT count(*) FROM ", project_qualified_name("imf_observation_snapshot"),
      " WHERE vintage_id=", sql_string(item$vintage_id), ") observations,",
      "(SELECT count(*) FROM ", project_qualified_name("imf_metadata_snapshot"),
      " WHERE vintage_id=", sql_string(item$vintage_id), ") metadata_values"
    ))
    contract <- read_imf_wide_contracts(root)
    contract <- contract[contract$source_id == item$source_id, , drop = FALSE]
    if (nrow(contract) != 1L || counts$records[[1]] != as.numeric(contract$data_records[[1]]) ||
        counts$series[[1]] != as.numeric(contract$series_count[[1]]) ||
        counts$observations[[1]] != as.numeric(contract$observation_count[[1]]) ||
        counts$metadata_values[[1]] != as.numeric(contract$metadata_value_count[[1]])) stop(
      "IMF stored-population guard failed for ", item$source_id, call. = FALSE
    )
  }
  if (item$ingest_mode == "semantic_table") validate_documented_source(con, item, release_id, root)
  if (item$source_id %in% c("banks", "financial")) {
    validate_documented_financial_source(con, item, release_id)
  }
}

# The audit's section 11 lists eight P0 tests whose action is "block release".
# Each one is an invariant the project currently satisfies, so recording them
# here converts "we checked once" into "the pipeline refuses to ship without
# it". Every flag raised is error severity, which now sets the run to
# release_blocked in run_manifest_pipeline().
# The audit's precise check 1: "For every fact, require fact.publication_date IS
# NOT DISTINCT FROM source_files.publication_date." It is stated over facts, but
# every table that carries the pair is a copy of the same thing and the audit
# found the snapshot drifting alongside the facts, so all of them are tested.
# propagate_vintage_publication_date() is what makes this pass; this is what
# proves it did.
validate_publication_date_consistency <- function(con, release_id) {
  tables <- publication_date_mirror_tables(con)
  source_files <- database_object_qualified_name(con, "source_files")
  divergent <- list()
  for (i in seq_len(nrow(tables))) {
    qualified <- paste0(
      DBI::dbQuoteIdentifier(con, tables$table_schema[[i]]), ".",
      DBI::dbQuoteIdentifier(con, tables$table_name[[i]])
    )
    counted <- DBI::dbGetQuery(con, paste0(
      "SELECT f.source_id, count(*) AS n, min(t.publication_date) AS mirror_date,",
      " min(f.publication_date) AS vintage_date FROM ", qualified, " AS t",
      " JOIN ", source_files, " AS f USING (vintage_id)",
      " WHERE t.publication_date IS DISTINCT FROM f.publication_date GROUP BY 1"
    ))
    if (nrow(counted)) divergent[[tables$table_name[[i]]]] <- counted
  }
  if (length(divergent)) {
    detail <- paste(vapply(names(divergent), function(name) paste0(
      name, ": ", paste(sprintf(
        "%s %d row(s) say %s, the vintage says %s", divergent[[name]]$source_id,
        divergent[[name]]$n, divergent[[name]]$mirror_date, divergent[[name]]$vintage_date
      ), collapse = "; ")
    ), character(1)), collapse = " | ")
    insert_quality_flag(
      con, release_id, "error", "fact_publication_date_mismatch", NA_character_,
      paste("Publication dates disagree with the authoritative source vintage:", detail)
    )
  }

  # A source's later vintage cannot have been available earlier than its
  # predecessor. With one vintage per source this cannot fire today; it is the
  # check that makes a second vintage safe to add.
  regressions <- DBI::dbGetQuery(con, paste0(
    "SELECT source_id, count(*) AS n FROM (",
    "  SELECT source_id, publication_date, first_ingested_at,",
    "    lag(publication_date) OVER (PARTITION BY source_id ORDER BY first_ingested_at) AS previous",
    "  FROM ", source_files, " WHERE publication_date IS NOT NULL",
    ") WHERE previous IS NOT NULL AND publication_date < previous GROUP BY 1"
  ))
  if (nrow(regressions)) insert_quality_flag(
    con, release_id, "error", "publication_date_not_monotonic", NA_character_,
    paste0(
      "A later vintage carries an earlier publication date than its predecessor: ",
      paste0(regressions$source_id, " (", regressions$n, ")", collapse = "; ")
    )
  )

  # A vintage whose date is *labelled* content_max_period while the content
  # reaches further is an internal contradiction, and it is how the audit's
  # defect first appeared. It is not the same as a workbook that legitimately
  # publishes projections: those carry a filename or registry date, and this
  # never looks at them.
  periods <- publication_date_period_columns(con)
  if (nrow(periods)) {
    union_sql <- paste(vapply(seq_len(nrow(periods)), function(i) paste0(
      "SELECT vintage_id, max(CAST(", DBI::dbQuoteIdentifier(con, periods$column_name[[i]]),
      " AS DATE)) AS content_max FROM ",
      DBI::dbQuoteIdentifier(con, periods$table_schema[[i]]), ".",
      DBI::dbQuoteIdentifier(con, periods$table_name[[i]]), " GROUP BY 1"
    ), character(1)), collapse = " UNION ALL ")
    contradictory <- DBI::dbGetQuery(con, paste0(
      "WITH content AS (", union_sql, ")",
      " SELECT f.source_id, f.publication_date, max(content.content_max) AS content_max",
      " FROM ", source_files, " AS f JOIN content USING (vintage_id)",
      " WHERE f.publication_date_source = 'content_max_period'",
      " GROUP BY 1, 2 HAVING max(content.content_max) > f.publication_date"
    ))
    if (nrow(contradictory)) insert_quality_flag(
      con, release_id, "warning", "publication_date_source_contradicts_content", NA_character_,
      paste0(
        "The publication date is recorded as the maximum period in the content, but the content ",
        "reaches further. Record the official release date in config/source_vintages.csv or ",
        "review the parser: ",
        paste0(
          contradictory$source_id, " (recorded ", contradictory$publication_date,
          ", content reaches ", contradictory$content_max, ")", collapse = "; "
        )
      )
    )
  }

  inferred <- DBI::dbGetQuery(con, paste0(
    "SELECT source_id, publication_date, publication_date_source FROM ", source_files,
    " WHERE publication_date_source IS DISTINCT FROM 'official_registry' ORDER BY source_id"
  ))
  if (nrow(inferred)) insert_quality_flag(
    con, release_id, "warning", "publication_date_inferred_from_content", NA_character_,
    paste0(
      nrow(inferred), " source vintage(s) have no official release date in ",
      "config/source_vintages.csv, so availability is inferred from the filename or the ",
      "content: ", paste0(
        head(paste0(inferred$source_id, " (", inferred$publication_date_source, ")"), 25),
        collapse = "; "
      )
    )
  )
  invisible(TRUE)
}

# The period-bearing columns of every vintage-keyed table, used to ask what the
# latest period a vintage actually contains is. Discovered from the catalogue so
# a snapshot added later is included without anyone remembering to.
publication_date_period_columns <- function(con) {
  candidates <- DBI::dbGetQuery(con, paste(
    "SELECT c.table_schema, c.table_name, c.column_name FROM information_schema.columns c",
    "JOIN information_schema.tables t ON t.table_schema = c.table_schema",
    "  AND t.table_name = c.table_name AND t.table_type = 'BASE TABLE'",
    "WHERE c.column_name IN ('period', 'date', 'operation_date', 'fecha')",
    "  AND c.data_type IN ('DATE', 'TIMESTAMP')",
    "  AND EXISTS (SELECT 1 FROM information_schema.columns v",
    "              WHERE v.table_schema = c.table_schema AND v.table_name = c.table_name",
    "                AND v.column_name = 'vintage_id')"
  ))
  candidates[!duplicated(paste(candidates$table_schema, candidates$table_name)), , drop = FALSE]
}

validate_release_gate <- function(con, release_id) {
  gate <- function(check_name, detail) insert_quality_flag(
    con, release_id, "error", check_name, NA_character_, detail
  )
  scalar <- function(sql) DBI::dbGetQuery(con, sql)$n[[1]]

  validate_publication_date_consistency(con, release_id)

  duplicated_keys <- scalar(paste(
    "SELECT count(*) AS n FROM (SELECT 1 FROM fact_series_events",
    "GROUP BY series_id, period, vintage_id HAVING count(*) > 1)"
  ))
  if (duplicated_keys) gate(
    "observation_grain_violated",
    paste(duplicated_keys, "observation keys occur more than once in fact_series_events.")
  )

  # A tombstone legitimately has no value; a live observation must have one.
  incomplete_keys <- scalar(paste(
    "SELECT count(*) AS n FROM fact_series_events",
    "WHERE series_id IS NULL OR period IS NULL OR vintage_id IS NULL",
    "OR is_deleted IS NULL OR (value IS NULL AND NOT is_deleted)"
  ))
  if (incomplete_keys) gate(
    "observation_key_incomplete",
    paste(incomplete_keys, "observations lack a series, period, vintage or value.")
  )

  orphan_facts <- scalar(paste(
    "SELECT count(*) AS n FROM fact_series_events f",
    "LEFT JOIN dim_series d USING (series_id) WHERE d.series_id IS NULL"
  ))
  if (orphan_facts) gate(
    "orphan_observations",
    paste(orphan_facts, "observations reference a series that is not in dim_series.")
  )

  # The fact table is keyed on surrogate integers and carries the human
  # identifiers alongside them. That is only safe while the two agree: a
  # surrogate key that drifted from its identifier would repoint observations at
  # a different series without changing a single visible value, and every query
  # in the project reads the identifier.
  if ("series_sk" %in% table_column_names(con, "fact_series_events")) {
    for (dimension in list(
      list(table = "dim_series", key = "series_sk", natural = "series_id"),
      list(table = "source_files", key = "vintage_sk", natural = "vintage_id")
    )) {
      unassigned <- scalar(paste0(
        "SELECT count(*) AS n FROM ", dimension$table, " WHERE ", dimension$key, " IS NULL"
      ))
      if (unassigned) gate("surrogate_key_unassigned", paste(
        unassigned, "rows in", dimension$table, "have no", dimension$key
      ))
      collisions <- scalar(paste0(
        "SELECT count(*) AS n FROM (SELECT 1 FROM ", dimension$table,
        " GROUP BY ", dimension$key, " HAVING count(*) > 1)"
      ))
      if (collisions) gate("surrogate_key_collision", paste(
        collisions, dimension$key, "values in", dimension$table, "name more than one",
        dimension$natural
      ))
      divergent <- scalar(paste0(
        "SELECT count(*) AS n FROM fact_series_events f JOIN ", dimension$table, " d",
        " ON d.", dimension$key, " = f.", dimension$key,
        " WHERE d.", dimension$natural, " IS DISTINCT FROM f.", dimension$natural
      ))
      if (divergent) gate("surrogate_key_diverged", paste(
        divergent, "observations carry a", dimension$key, "and a", dimension$natural,
        "that name different rows of", dimension$table
      ))
    }
  }

  if (database_object_exists(con, "table_reconciliation")) {
    # Parser-region non-overlap: a source cell may feed one observation unless a
    # reviewed many-to-one rule says otherwise. This is the test the compensatory
    # FX defect would have failed before it reached a release.
    reuse <- DBI::dbGetQuery(con, paste(
      "SELECT source_id, source_sheet, cell_reuse FROM table_reconciliation",
      "WHERE cell_reuse > many_to_one_allowance ORDER BY cell_reuse DESC"
    ))
    if (nrow(reuse)) gate("source_cell_reuse", paste0(
      nrow(reuse), " worksheet(s) feed one source cell into several observations: ",
      paste(head(paste0(reuse$source_id, "/", reuse$source_sheet, " (", reuse$cell_reuse, ")"), 10),
            collapse = "; ")
    ))
    # A worksheet whose accounting does not balance is reported, but only blocks
    # the release once someone has claimed it is validated. Promotion is where
    # the unexplained residual becomes a correctness claim.
    unbalanced <- DBI::dbGetQuery(con, paste(
      "SELECT r.source_id, r.source_sheet, r.balance_delta FROM table_reconciliation r",
      "JOIN table_status t ON t.source_id = r.source_id",
      "  AND (t.source_sheet = r.source_sheet OR t.source_sheet = '*')",
      "WHERE r.status <> 'balanced' AND t.status = 'validated'"
    ))
    if (nrow(unbalanced)) gate("validated_table_unreconciled", paste0(
      nrow(unbalanced), " validated worksheet(s) do not reconcile to their source cells: ",
      paste(head(paste0(unbalanced$source_id, "/", unbalanced$source_sheet), 10), collapse = "; ")
    ))
    # The audit's central P0: a numeric cell nobody has accounted for is not a
    # warning to be read later, it is a release that may be silently missing
    # data. Classifying it -- as a header, a subtotal, report layout, an
    # out-of-scope block, or an admitted parser defect -- is what clears this.
    if (database_object_exists(con, "reconciliation_cell_classification") &&
        "unclassified_cells" %in% table_column_names(con, "table_reconciliation")) {
      unclassified <- DBI::dbGetQuery(con, paste(
        "SELECT source_id, source_sheet, unclassified_cells FROM table_reconciliation",
        "WHERE unclassified_cells > 0 ORDER BY unclassified_cells DESC"
      ))
      if (nrow(unclassified)) gate("reconciliation_unclassified", paste0(
        sum(unclassified$unclassified_cells), " numeric source cell(s) across ", nrow(unclassified),
        " worksheet(s) match no rule in config/reconciliation_cell_rules.csv. See ",
        "outputs/reconciliation_unclassified_cells.csv and v_reconciliation_unclassified. Largest: ",
        paste(head(paste0(unclassified$source_id, "/", unclassified$source_sheet,
                          " (", unclassified$unclassified_cells, ")"), 10), collapse = "; ")
      ))
      # A recorded defect is honest but is still unread published data, so it is
      # reported at every release until the parser is repaired.
      defects <- DBI::dbGetQuery(con, paste(
        "SELECT source_id, source_sheet, parser_defect_cells FROM table_reconciliation",
        "WHERE parser_defect_cells > 0 ORDER BY parser_defect_cells DESC"
      ))
      if (nrow(defects)) insert_quality_flag(
        con, release_id, "warning", "reconciliation_parser_defect", NA_character_,
        paste0(
          sum(defects$parser_defect_cells), " numeric source cell(s) across ", nrow(defects),
          " worksheet(s) are published data a reviewer has recorded as unread by the current ",
          "parser. Those worksheets cannot reach v_research_series: ",
          paste(head(paste0(defects$source_id, "/", defects$source_sheet,
                            " (", defects$parser_defect_cells, ")"), 10), collapse = "; ")
        )
      )
    }
  }

  # Cross-release identity stability: every identifier the project has ever
  # published must have a recorded outcome -- still current, superseded by a
  # named successor, or explicitly retired. An identifier that simply stops
  # resolving is what broke reproducibility in the first place.
  if (database_object_exists(con, "series_id_migration") &&
      database_object_exists(con, "v_series_id_resolution")) {
    recorded <- scalar("SELECT count(*) AS n FROM series_id_migration")
    if (recorded) {
      unresolved <- scalar(paste(
        "SELECT count(*) AS n FROM (",
        "  SELECT DISTINCT old_series_id FROM series_id_migration",
        "  WHERE old_series_id IS NOT NULL",
        "  EXCEPT SELECT published_series_id FROM v_series_id_resolution)"
      ))
      if (unresolved) gate("superseded_identifier_unresolved", paste(
        unresolved, "published series identifiers have no recorded outcome",
        "(neither current, superseded nor retired)."
      ))
    }
    # Every published identifier must land in exactly one cardinality class, and
    # the scalar resolver must decline every ambiguous one. A resolver that
    # returns an arbitrary successor for a split series is worse than no
    # resolver, because research code cannot tell it happened.
    if ("resolution_cardinality" %in% table_column_names(con, "v_series_id_resolution")) {
      inconsistent <- scalar(paste(
        "SELECT count(*) AS n FROM (SELECT published_series_id FROM v_series_id_resolution",
        "GROUP BY 1 HAVING count(DISTINCT resolution_cardinality) > 1)"
      ))
      if (inconsistent) gate("identifier_cardinality_inconsistent", paste(
        inconsistent, "published identifiers carry more than one resolution cardinality."
      ))
      # Asserted on the view, not through the macro. A DuckDB macro substitutes
      # the caller's argument expression into its body, so calling it from the
      # very view it reads would compare a column with itself and pass
      # vacuously. The macro is exercised with literals in the test suite; here
      # the underlying resolution is what has to be right.
      leaked <- scalar(paste(
        "SELECT count(*) AS n FROM v_series_id_scalar_resolution",
        "WHERE resolution_cardinality <> 'one_to_one' AND resolved_series_id IS NOT NULL"
      ))
      if (leaked) gate("identifier_resolution_not_fail_closed", paste(
        leaked, "ambiguous or retired identifiers resolve to a single series through",
        "resolve_series_id(); the scalar resolver must decline rather than choose."
      ))
    }
  }
  # The audit's third P0 test: "no duplicated observation key after all joins".
  # A mart is several joins deep into classification, review and reconciliation
  # metadata, and every one of those is a chance to multiply an observation by a
  # key nobody checked. Counting the grain after the joins is the only test that
  # actually catches it, and it catches the *_all views too, since a defect there
  # reaches the validated marts the moment a table is promoted.
  mart_views <- DBI::dbGetQuery(con, paste(
    "SELECT table_name FROM information_schema.tables",
    "WHERE table_type = 'VIEW'",
    "AND table_name LIKE 'v_mart\\_%' ESCAPE '\\' ORDER BY table_name"
  ))$table_name
  for (mart in mart_views) {
    grain <- DBI::dbGetQuery(con, paste0(
      "SELECT count(*) AS emitted, count(DISTINCT (series_id, period, vintage_id)) AS keys FROM ",
      DBI::dbQuoteIdentifier(con, mart)
    ))
    if (grain$emitted[[1]] != grain$keys[[1]]) gate("mart_key_not_unique", paste0(
      mart, " emits ", grain$emitted[[1]], " rows for ", grain$keys[[1]],
      " distinct (series_id, period, vintage_id) keys; a join in the mart is multiplying observations."
    ))
  }
  # A research mart must never carry a row its worksheet has not been validated
  # for. The filter is in the view, so this asserts the view still says what it
  # is named for rather than trusting that nobody edited it.
  for (mart in grep("_all$", mart_views, value = TRUE, invert = TRUE)) {
    leaked <- DBI::dbGetQuery(con, paste0(
      "SELECT count(*) AS n FROM ", DBI::dbQuoteIdentifier(con, mart),
      " WHERE review_status IS DISTINCT FROM 'validated'",
      " OR reconciliation_status IS DISTINCT FROM 'balanced'"
    ))$n[[1]]
    if (leaked) gate("mart_exposes_unvalidated_rows", paste0(
      leaked, " row(s) in ", mart, " come from a worksheet that is not validated or does not ",
      "reconcile to its source cells."
    ))
  }
  validate_referential_integrity(con, release_id)
  invisible(TRUE)
}

# The audit asks for foreign keys "where the DuckDB workflow permits, plus
# release-blocking anti-join tests". Declared foreign keys are the wrong tool
# here: every curated table is rewritten with DELETE-then-append on each run, so
# a declared constraint would reject the pipeline's own normal operation midway
# through a release. The anti-join tests give the same guarantee at the point
# where it matters -- the end of the run, on the finished release -- without
# constraining how the release is assembled.
validate_referential_integrity <- function(con, release_id) {
  relations <- list(
    list("map_series_concept", "series_id", "dim_series", "series_id"),
    list("map_series_concept", "concept_id", "dim_concept", "concept_id"),
    list("documented_series_snapshot", "series_id", "dim_series", "series_id"),
    list("series_revisions", "series_id", "dim_series", "series_id"),
    list("fact_series_events", "vintage_id", "source_files", "vintage_id"),
    list("release_sources", "vintage_id", "source_files", "vintage_id"),
    list("report_sheet_vintages", "sheet_version_id", "report_sheet_versions", "sheet_version_id"),
    list("report_cell_values", "sheet_version_id", "report_sheet_versions", "sheet_version_id"),
    list("table_reconciliation", "vintage_id", "source_files", "vintage_id"),
    list("map_canonical_series", "canonical_series_id", "canonical_series", "canonical_series_id")
  )
  for (relation in relations) {
    child <- relation[[1]]; child_key <- relation[[2]]
    parent <- relation[[3]]; parent_key <- relation[[4]]
    if (!database_object_exists(con, child) || !database_object_exists(con, parent)) next
    orphans <- DBI::dbGetQuery(con, paste0(
      "SELECT count(*) AS n FROM ", DBI::dbQuoteIdentifier(con, child), " c",
      " WHERE c.", child_key, " IS NOT NULL AND NOT EXISTS (SELECT 1 FROM ",
      DBI::dbQuoteIdentifier(con, parent), " p WHERE p.", parent_key, " = c.", child_key, ")"
    ))$n[[1]]
    if (orphans) insert_quality_flag(
      con, release_id, "error", "referential_integrity_violated", NA_character_,
      paste0(orphans, " rows in ", child, ".", child_key, " have no matching ",
             parent, ".", parent_key, ".")
    )
  }
  # Natural keys that the audit tested by hand and found unique. Enforcing them
  # here means a parser regression that starts duplicating a grain fails the
  # release instead of being discovered by the next auditor.
  natural_keys <- list(
    list("documented_series_snapshot", c("vintage_id", "series_id", "period")),
    list("table_reconciliation", c("vintage_id", "source_sheet")),
    list("report_cell_values", c("sheet_version_id", "row_id", "column_id"))
  )
  for (entry in natural_keys) {
    table_name <- entry[[1]]; key_columns <- entry[[2]]
    if (!database_object_exists(con, table_name)) next
    duplicates <- DBI::dbGetQuery(con, paste0(
      "SELECT count(*) AS n FROM (SELECT 1 FROM ", DBI::dbQuoteIdentifier(con, table_name),
      " GROUP BY ", paste(key_columns, collapse = ", "), " HAVING count(*) > 1)"
    ))$n[[1]]
    if (duplicates) insert_quality_flag(
      con, release_id, "error", "natural_key_violated", NA_character_,
      paste0(duplicates, " duplicated (", paste(key_columns, collapse = ", "),
             ") keys in ", table_name, ".")
    )
  }
  invisible(TRUE)
}

# --- The published interface ------------------------------------------------
# The audit's P0: 74 of 74 views and all three macros raised
# "Table with name dim_series does not exist" from a fresh default connection,
# because schema 21 moved the tables while every stored body still named them
# bare. The pipeline never saw it -- it sets a search path on its own connections
# -- and neither did the suite, which reached every view through a helper that
# does the same. Two gates, because they fail differently:
#
#   the lint    reads the stored SQL back and rejects a bare reference. It
#               catches a defect the moment it is written, and it names the
#               object and the reference rather than a symptom.
#   the gate    executes every object on a connection with nothing configured.
#               It is the only check that reproduces what a researcher does, and
#               it would have caught this on the day it shipped.
#
# Both are release-blocking. Neither trusts the other: a view can lint clean and
# still fail to execute, and a view can execute on this machine's search path
# and still be unqualified.

# Anything after FROM or JOIN that names a project object without a schema. The
# search is the same shape as qualify_project_sql()'s rewrite, deliberately: if
# the two ever disagree, the lint is what fails the release.
stored_sql_unqualified_references <- function(sql, object_names) {
  candidates <- setdiff(object_names, sql_cte_names(sql))
  found <- vapply(candidates, function(object) grepl(
    paste0("(\\b(?:FROM|JOIN)\\s+)(\"?)", object, "\\2\\b(?!\\s*\\.)"), sql, perl = TRUE
  ), logical(1))
  candidates[found]
}

validate_stored_object_qualification <- function(con, release_id) {
  object_names <- names(project_object_schemas(con))
  if (!length(object_names)) return(invisible(FALSE))
  stored <- rbind(
    DBI::dbGetQuery(con, paste(
      "SELECT schema_name || '.' || view_name AS object_name, 'view' AS object_type, sql AS body",
      "FROM duckdb_views() WHERE NOT internal"
    )),
    DBI::dbGetQuery(con, paste(
      "SELECT schema_name || '.' || function_name AS object_name, 'macro' AS object_type,",
      "macro_definition AS body FROM duckdb_functions() WHERE NOT internal AND macro_definition IS NOT NULL"
    ))
  )
  offenders <- list()
  for (i in seq_len(nrow(stored))) {
    bare <- stored_sql_unqualified_references(stored$body[[i]], object_names)
    if (length(bare)) offenders[[length(offenders) + 1L]] <- paste0(
      stored$object_name[[i]], " (", stored$object_type[[i]], ") -> ", paste(bare, collapse = ", ")
    )
  }
  if (!length(offenders)) return(invisible(TRUE))
  insert_quality_flag(
    con, release_id, "error", "unqualified_object_dependency", NA_character_,
    paste0(
      length(offenders), " stored object(s) reference a project object without a schema and will ",
      "fail from a default connection. Create them through create_project_view()/",
      "create_project_macro(): ", paste(head(offenders, 10), collapse = " | ")
    )
  )
  invisible(FALSE)
}

AGGREGATE_IDENTITY_COLUMNS <- c(
  "source_id", "source_sheet", "identity_label", "total_column", "component_columns",
  "tolerance", "basis", "evidence", "reviewed_by", "reviewed_at"
)

# The audit's P1: "Add per-source aggregation identities only where the publisher
# defines them." A publisher states an identity in a footnote -- SIPAP_12 row 64,
# "(I): El total de operaciones SPI se compone de D+E+F+G+H" -- or in the block
# header itself, and it is stated over *columns*, which is also the only stable
# way to name it: labels change with a parser repair, worksheet columns do not.
read_aggregate_identities <- function(root) {
  path <- file.path(root, "config", "aggregate_identities.csv")
  empty <- tibble::tibble(
    identity_id = character(), source_id = character(), source_sheet = character(),
    identity_label = character(), total_column = integer(), component_columns = character(),
    tolerance = double(), basis = character(), evidence = character(),
    reviewed_by = character(), reviewed_at = as.Date(character())
  )
  if (!file.exists(path)) return(empty)
  rules <- readr::read_csv(
    path, col_types = readr::cols(.default = readr::col_character()), trim_ws = FALSE
  )
  if (!identical(names(rules), AGGREGATE_IDENTITY_COLUMNS)) stop(
    "Aggregate-identity guard: config/aggregate_identities.csv columns changed or are reordered.",
    call. = FALSE
  )
  if (!nrow(rules)) return(empty)
  for (field in setdiff(AGGREGATE_IDENTITY_COLUMNS, "source_sheet")) {
    rules[[field]] <- trimws(rules[[field]])
    if (any(is.na(rules[[field]]) | !nzchar(rules[[field]]))) stop(
      "Aggregate-identity guard: ", field, " is required on every row.", call. = FALSE
    )
  }
  if (any(rules$reviewed_by == "unreviewed")) stop(
    "Aggregate-identity guard: an identity is a claim about what the publisher states and needs a ",
    "named reviewer or '", RECONCILIATION_LAYOUT_REVIEWER, "'.", call. = FALSE
  )
  total <- suppressWarnings(as.integer(rules$total_column))
  tolerance <- suppressWarnings(as.numeric(rules$tolerance))
  reviewed_at <- suppressWarnings(lubridate::ymd(rules$reviewed_at, quiet = TRUE))
  if (any(is.na(total)) || any(is.na(tolerance)) || any(is.na(reviewed_at))) stop(
    "Aggregate-identity guard: total_column, tolerance and reviewed_at must be a whole number, ",
    "a number and a YYYY-MM-DD date.", call. = FALSE
  )
  components <- strsplit(rules$component_columns, "|", fixed = TRUE)
  if (any(vapply(components, length, integer(1)) < 2L)) stop(
    "Aggregate-identity guard: an identity needs at least two component columns, separated by '|'.",
    call. = FALSE
  )
  rows <- tibble::tibble(
    source_id = rules$source_id, source_sheet = rules$source_sheet,
    identity_label = rules$identity_label, total_column = total,
    component_columns = rules$component_columns, tolerance = tolerance,
    basis = rules$basis, evidence = rules$evidence,
    reviewed_by = rules$reviewed_by, reviewed_at = reviewed_at
  )
  rows$identity_id <- paste0("identity:", substr(vapply(
    paste(rows$source_id, rows$source_sheet, rows$identity_label, sep = "|"),
    function(key) digest::digest(key, algo = "sha256", serialize = FALSE), character(1)
  ), 1L, 24L))
  if (anyDuplicated(rows$identity_id)) stop(
    "Aggregate-identity guard: two rows name the same source, sheet and identity.", call. = FALSE
  )
  rows[c("identity_id", setdiff(names(rows), "identity_id"))]
}

validate_published_identities <- function(con, release_id, root) {
  if (!database_object_exists(con, "documented_series_snapshot")) return(invisible(FALSE))
  identities <- read_aggregate_identities(root)
  if (database_object_exists(con, "aggregate_identities")) {
    DBI::dbExecute(con, "DELETE FROM aggregate_identities")
    if (nrow(identities)) DBI::dbWriteTable(con, "aggregate_identities", identities, append = TRUE)
  }
  if (!nrow(identities)) return(invisible(TRUE))
  breaches <- list()
  incomplete <- list()
  unchecked <- character()
  for (i in seq_len(nrow(identities))) {
    row <- identities[i, ]
    components <- as.integer(strsplit(row$component_columns, "|", fixed = TRUE)[[1]])
    # Completeness and equality are separate questions, and coalescing an absent
    # component to zero answered neither. A component that is not published is
    # not a component that is zero: filling it in makes an identity with a
    # missing term arithmetically pass, which is the failure mode a component
    # check exists to catch. So the presence of every declared component is
    # counted first, and the residual is measured only where they are all there.
    measured <- DBI::dbGetQuery(con, paste0(
      "WITH v AS (SELECT period, source_column, value FROM ",
      project_qualified_name("documented_series_snapshot"),
      " WHERE source_id = ", sql_string(row$source_id),
      " AND source_sheet = ", sql_string(row$source_sheet), ")",
      " SELECT count(*) AS periods,",
      " count(*) FILTER (WHERE present < ", length(components), ") AS incomplete,",
      " count(*) FILTER (WHERE present = ", length(components),
      "   AND abs(total - components) > ", row$tolerance, ") AS breaches,",
      " max(abs(total - components)) FILTER (WHERE present = ", length(components),
      "   ) AS worst FROM (",
      "   SELECT period, max(value) FILTER (WHERE source_column = ", row$total_column, ") AS total,",
      "     ", paste(sprintf(
        "coalesce(max(value) FILTER (WHERE source_column = %d), 0)", components
      ), collapse = " + "), " AS components,",
      "     ", paste(sprintf(
        "CASE WHEN max(value) FILTER (WHERE source_column = %d) IS NULL THEN 0 ELSE 1 END",
        components
      ), collapse = " + "), " AS present",
      "   FROM v GROUP BY 1) x WHERE total IS NOT NULL"
    ))
    if (!measured$periods[[1]]) {
      unchecked <- c(unchecked, paste0(row$source_id, "/", row$source_sheet, " ", row$identity_label))
      next
    }
    if (measured$breaches[[1]]) breaches[[length(breaches) + 1L]] <- paste0(
      row$source_id, "/", row$source_sheet, " ", row$identity_label, ": ",
      measured$breaches[[1]], " of ", measured$periods[[1]],
      " period(s) break it, worst ", format(measured$worst[[1]], scientific = FALSE)
    )
    if (measured$incomplete[[1]]) incomplete[[length(incomplete) + 1L]] <- paste0(
      row$source_id, "/", row$source_sheet, " ", row$identity_label, ": ",
      measured$incomplete[[1]], " of ", measured$periods[[1]],
      " period(s) publish the total without every component"
    )
  }
  if (length(breaches)) insert_quality_flag(
    con, release_id, "error", "published_identity_broken", NA_character_,
    paste0(
      length(breaches), " identity(ies) the publisher states do not hold in what was parsed. ",
      "Either the parser is reading the wrong columns or the source has changed shape: ",
      paste(head(breaches, 5), collapse = " | ")
    )
  )
  # A period that publishes the total without every component is not a broken
  # identity -- there is nothing to compare -- but it is not a passing one
  # either, and treating a missing term as a zero is what let it look like one.
  if (length(incomplete)) insert_quality_flag(
    con, release_id, "warning", "published_identity_incomplete", NA_character_,
    paste0(
      length(incomplete), " identity(ies) have period(s) where the publisher gives the total but ",
      "not every component, so the equality cannot be tested there: ",
      paste(head(incomplete, 5), collapse = " | ")
    )
  )
  # An identity that matches no period is describing a worksheet that no longer
  # looks like that, exactly as an unused reconciliation rule is.
  if (length(unchecked)) insert_quality_flag(
    con, release_id, "warning", "published_identity_unchecked", NA_character_,
    paste0(
      length(unchecked), " identity(ies) in config/aggregate_identities.csv match no parsed period. ",
      "Check the source, sheet and columns: ", paste(head(unchecked, 5), collapse = "; ")
    )
  )
  invisible(!length(breaches))
}

# The audit's F-13, as much of it as a sheet-level record can carry.
#
# Every number this project reads is a cached formula result: readxl cannot
# calculate, so a workbook shipped without recalculating stores whatever was last
# computed, and nothing downstream can tell. Hidden rows and columns are the
# mirror image -- the parser cannot say whether a value it read, or skipped, was
# visible to the publisher's own reader.
#
# Neither is a defect on its own. What matters is the *change*: a sheet that was
# 30% formulas and is now 2%, or that has begun hiding a block of rows, has
# changed behaviour between vintages in a way no cell comparison reveals. With
# one vintage per source this reports the state; with two it reports the drift.
#
# The state is only worth reporting if it has a consequence, so the hidden ranges
# are joined back to the parsed observations. They do: the annex hides most of
# CUADRO 31 and nearly all of Cuadro 21 a, and the parser reads those rows and
# publishes them. That is not evidence of an error -- a publisher who hides a
# historical block is usually still standing behind it -- but a researcher is
# entitled to know that a number they are citing is one the publisher's own
# reader does not see.
hidden_row_observations <- function(con) {
  empty <- tibble(
    source_id = character(), sheet_name = character(),
    hidden_row_observations = numeric(), hidden_row_series = numeric()
  )
  if (!database_object_exists(con, "documented_series_snapshot")) return(empty)
  DBI::dbGetQuery(con, paste(
    "WITH packed AS (",
    "  SELECT source_id, sheet_name, vintage_id, unnest(string_split(hidden_rows, ';')) AS span",
    "  FROM", project_qualified_name("source_sheets"), "WHERE hidden_rows IS NOT NULL),",
    "spans AS (",
    "  SELECT source_id, sheet_name, vintage_id,",
    "         TRY_CAST(split_part(span, '-', 1) AS BIGINT) AS row_from,",
    "         TRY_CAST(CASE WHEN span LIKE '%-%' THEN split_part(span, '-', 2)",
    "                       ELSE span END AS BIGINT) AS row_to",
    "  FROM packed)",
    "SELECT s.source_id, s.sheet_name,",
    "       count(*) AS hidden_row_observations,",
    "       count(DISTINCT o.series_id) AS hidden_row_series",
    "FROM spans s",
    "JOIN", project_qualified_name("documented_series_snapshot"), "o",
    "  ON o.vintage_id = s.vintage_id AND o.source_sheet = s.sheet_name",
    " AND o.source_row BETWEEN s.row_from AND s.row_to",
    "GROUP BY 1, 2"
  ))
}

validate_workbook_behaviour <- function(con, release_id, root) {
  if (!database_object_exists(con, "source_sheets")) return(invisible(FALSE))
  columns <- table_column_names(con, "source_sheets")
  if (!all(c("formula_cells", "hidden_rows") %in% columns)) return(invisible(FALSE))
  state <- DBI::dbGetQuery(con, paste(
    "SELECT source_id, sheet_name, vintage_id, coalesce(formula_cells, 0) AS formula_cells,",
    "hidden_rows, hidden_columns FROM", project_qualified_name("source_sheets")
  ))
  if (!nrow(state) || is.null(root)) return(invisible(TRUE))
  published <- hidden_row_observations(con)
  state <- dplyr::left_join(state, published, by = c("source_id", "sheet_name"))
  state$hidden_row_observations <- dplyr::coalesce(state$hidden_row_observations, 0)
  state$hidden_row_series <- dplyr::coalesce(state$hidden_row_series, 0)
  readr::write_csv(
    state[order(-state$hidden_row_observations, -state$formula_cells), , drop = FALSE],
    file.path(root, "outputs", "workbook_behaviour_latest.csv")
  )
  formula_heavy <- state[state$formula_cells > 0, , drop = FALSE]
  hidden <- state[!is.na(state$hidden_rows) | !is.na(state$hidden_columns), , drop = FALSE]
  read_from_hidden <- hidden[hidden$hidden_row_observations > 0, , drop = FALSE]
  read_from_hidden <- read_from_hidden[
    order(-read_from_hidden$hidden_row_observations), , drop = FALSE]
  if (nrow(formula_heavy) || nrow(hidden)) insert_quality_flag(
    con, release_id, "warning", "workbook_cached_formulas_and_hidden_state", NA_character_,
    paste0(
      format(sum(formula_heavy$formula_cells), big.mark = ","), " cell(s) across ",
      nrow(formula_heavy), " worksheet(s) hold a cached formula result rather than a typed value, ",
      "and ", nrow(hidden), " worksheet(s) hide rows or columns. Neither is a defect, and neither ",
      "can be seen from the cell values: whether the publisher recalculated before shipping, and ",
      "whether a hidden row was meant to be read, are questions for the publisher. ",
      if (nrow(read_from_hidden)) paste0(
        format(sum(read_from_hidden$hidden_row_observations), big.mark = ","),
        " published observation(s) across ", nrow(read_from_hidden),
        " worksheet(s) come from rows the publisher hid: ",
        paste(head(paste0(
          read_from_hidden$source_id, "/", read_from_hidden$sheet_name, " (",
          format(read_from_hidden$hidden_row_observations, big.mark = "", trim = TRUE), ")"
        ), 5), collapse = "; "), ". "
      ) else "No published observation sits on a hidden row. ",
      "See outputs/workbook_behaviour_latest.csv."
    )
  )
  # The drift test, which needs a second vintage of the same worksheet to say
  # anything and is written now so that it does when one arrives.
  drift <- DBI::dbGetQuery(con, paste(
    "SELECT source_id, sheet_name, count(DISTINCT formula_cells) AS formula_states,",
    "count(DISTINCT coalesce(hidden_rows, '')) AS hidden_row_states",
    "FROM", project_qualified_name("source_sheets"), "GROUP BY 1, 2",
    "HAVING count(DISTINCT vintage_id) > 1",
    "   AND (count(DISTINCT formula_cells) > 1 OR count(DISTINCT coalesce(hidden_rows, '')) > 1)"
  ))
  if (nrow(drift)) insert_quality_flag(
    con, release_id, "warning", "workbook_behaviour_changed", NA_character_,
    paste0(
      nrow(drift), " worksheet(s) changed their formula or hidden-row structure between vintages, ",
      "which a value comparison cannot show: ",
      paste(head(paste0(drift$source_id, "/", drift$sheet_name), 8), collapse = "; ")
    )
  )
  invisible(TRUE)
}

# The audit's F-08, as the condition on promotion rather than as a count.
#
# Unit, scale, frequency, stock/flow, nominal/real, adjustment and timing are not
# metadata niceties: without them a transformation is a guess that looks like
# arithmetic. Deflating a series nobody has marked nominal, summing a stock,
# annualising a rate, comparing a seasonally adjusted series with an original one
# -- each is a technically valid query and an economically invalid answer.
#
# The gate is written now and passes vacuously, because nothing is promoted yet.
# That is the point: it is what makes the first promotion safe, and writing it
# after something has been promoted would be writing it too late.
RESEARCH_ELIGIBILITY_FIELDS <- c(
  "unit_code", "scale_multiplier", "frequency", "stock_flow", "nominal_real",
  "seasonal_adjustment"
)

validate_research_eligibility_metadata <- function(con, release_id) {
  if (!database_object_exists(con, "v_research_series")) return(invisible(FALSE))
  columns <- table_column_names(con, "dim_series")
  fields <- intersect(RESEARCH_ELIGIBILITY_FIELDS, columns)
  if (!length(fields)) return(invisible(FALSE))
  predicate <- paste(vapply(fields, function(field) paste0(
    "d.", DBI::dbQuoteIdentifier(con, field), " IS NULL OR CAST(d.",
    DBI::dbQuoteIdentifier(con, field), " AS VARCHAR) IN ('not_reviewed', 'UNRESOLVED_SOURCE_UNITS')"
  ), character(1)), collapse = " OR ")
  ineligible <- DBI::dbGetQuery(con, paste0(
    "SELECT d.source_id, count(*) AS series FROM marts.v_research_series r",
    " JOIN ", project_qualified_name("dim_series"), " d ON d.series_id = r.series_id",
    " WHERE ", predicate, " GROUP BY 1 ORDER BY series DESC"
  ))
  if (nrow(ineligible)) insert_quality_flag(
    con, release_id, "error", "research_series_metadata_incomplete", NA_character_,
    paste0(
      sum(ineligible$series), " series reach the research surface without every field a ",
      "transformation depends on (", paste(fields, collapse = ", "),
      "). A series whose stock/flow or nominal/real status nobody has established cannot be ",
      "aggregated or deflated safely, however valid the SQL looks: ",
      paste0(ineligible$source_id, " (", ineligible$series, ")", collapse = "; ")
    )
  )
  # A value is not a review. The re-audit's RA2-02.
  #
  # The check above asks whether the column holds something other than
  # `not_reviewed`, and the derivation layer fills these columns from published
  # wording: `saldo` in a label yields stock_flow = 'stock' with
  # basis = 'published_label'. That is a reasonable inference and it is not an
  # economist's judgement, which is the entire distinction
  # series_semantic_evidence exists to record -- and which nothing read.
  #
  # So the gate now asks the question the evidence table was built to answer:
  # does every eligibility field of every series on the research surface rest on
  # a row whose basis is 'reviewed'?
  unreviewed <- if (!database_object_exists(con, "series_semantic_evidence")) {
    tibble(source_id = character(), series = integer(), fields = character())
  } else DBI::dbGetQuery(con, paste0(
    "WITH required AS (SELECT unnest([",
    paste(vapply(fields, sql_string, character(1)), collapse = ", "), "]) AS field),",
    " surface AS (SELECT r.series_id, d.source_id FROM marts.v_research_series r",
    "   JOIN ", project_qualified_name("dim_series"), " d USING (series_id))",
    " SELECT s.source_id, count(DISTINCT s.series_id) AS series,",
    "        string_agg(DISTINCT q.field, ', ') AS fields",
    " FROM surface s CROSS JOIN required q",
    " WHERE NOT EXISTS (SELECT 1 FROM ",
    project_qualified_name("series_semantic_evidence"), " e",
    "   WHERE e.series_id = s.series_id AND e.field = q.field AND e.basis = 'reviewed')",
    " GROUP BY 1 ORDER BY series DESC"
  ))
  if (nrow(unreviewed)) insert_quality_flag(
    con, release_id, "error", "research_series_evidence_not_reviewed", NA_character_,
    paste0(
      sum(unreviewed$series), " series reach the research surface carrying values nobody has ",
      "reviewed. The fields are populated, but by derivation from published wording rather than ",
      "by an economist: a label reading 'saldo' is evidence about a label, not a judgement that ",
      "the series is a stock. Record the review in config/series_review.csv. Affected: ",
      paste0(unreviewed$source_id, " (", unreviewed$series, ": ", unreviewed$fields, ")",
             collapse = "; ")
    )
  )
  invisible(!nrow(ineligible) && !nrow(unreviewed))
}

# The audit's F-05. A value dated after the vintage that published it is not an
# outcome, and the general current-value interface used to present it as one.
#
# The rows are kept there by explicit decision -- v_series_latest answers what the
# publisher currently says for a series and period, and a published projection is
# part of that answer -- so the control here is that the distinction is always
# carried and always counted. The gate is an error if the column disappears,
# because that is the failure that makes the rest invisible again, and a warning
# reporting how many rows a naive query would pick up.
validate_observation_status_exposure <- function(con, release_id) {
  if (!database_object_exists(con, "v_series_latest")) return(invisible(FALSE))
  exposed <- "observation_status" %in% table_column_names(con, "v_series_latest")
  if (!exposed) {
    insert_quality_flag(
      con, release_id, "error", "observation_status_not_exposed", NA_character_,
      paste(
        "main.v_series_latest does not carry observation_status, so a projection is",
        "indistinguishable from a realized observation in the general current-value interface."
      )
    )
    return(invisible(FALSE))
  }
  # The research default must contain none of them. Since schema 30 that is the
  # contract rather than an instruction to remember, so a projection reaching
  # v_series_latest is a defect and not a warning.
  leaked <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM main.v_series_latest WHERE observation_status <> 'observed'"
  ))$n[[1]]
  if (leaked) {
    insert_quality_flag(
      con, release_id, "error", "projections_in_realized_view", NA_character_,
      paste(
        leaked, "observation(s) dated after the vintage that published them are visible through",
        "main.v_series_latest, which is contracted to hold realized observations only.",
        "main.v_publisher_statement_latest is where a published projection belongs."
      )
    )
    return(invisible(FALSE))
  }
  if (!database_object_exists(con, "v_publisher_statement_latest")) return(invisible(TRUE))
  projections <- DBI::dbGetQuery(con, paste(
    "SELECT d.source_id, count(*) AS n, count(DISTINCT l.series_id) AS series,",
    "max(l.period) AS furthest",
    "FROM main.v_publisher_statement_latest l JOIN", project_qualified_name("dim_series"), "d",
    "USING (series_id) WHERE l.observation_status <> 'observed' GROUP BY 1 ORDER BY 2 DESC"
  ))
  if (!nrow(projections)) return(invisible(TRUE))
  # Reported, not warned about as a risk: the risk was the name, and the name is
  # fixed. What is left is a fact a researcher should know about the source.
  insert_quality_flag(
    con, release_id, "warning", "publisher_statement_contains_projections", NA_character_,
    paste0(
      sum(projections$n), " observation(s) across ", sum(projections$series),
      " series in main.v_publisher_statement_latest are dated after the vintage that published ",
      "them. That view is the publisher's current statement and holds them by design; ",
      "main.v_series_latest excludes them and marts.v_series_projections is the complement. ",
      "By source: ",
      paste0(
        projections$source_id, " (", projections$n, ", to ", projections$furthest, ")",
        collapse = "; "
      )
    )
  )
  invisible(TRUE)
}

# The other half of the audit's F-10, and the half a unique index cannot give:
# a required field that is null. Asserted for every declared key at every
# release, so the claim the documentation makes about a table's grain is a claim
# the release has actually tested.
# Which direct-panel records repeat every dimension the database models. Not a
# failure -- the physical key proves they are distinct published rows -- but the
# reason those tables must not be aggregated until someone identifies what the
# publisher is varying between them.
write_direct_panel_duplicate_worklist <- function(con, root) {
  if (is.null(root)) return(invisible(NULL))
  panels <- names(direct_panel_natural_keys(con))
  rows <- list()
  for (table_name in panels) {
    columns <- table_column_names(con, table_name)
    dimensions <- setdiff(columns, c(
      "source_row", "release_id", "publication_date", "source_file", "first_ingested_at"
    ))
    measures <- grep("^(saldo|monto|importe|cantidad|total|valor)", dimensions, value = TRUE)
    dimensions <- setdiff(dimensions, measures)
    if (length(dimensions) < 3L) next
    quoted <- paste(vapply(
      dimensions, function(x) as.character(DBI::dbQuoteIdentifier(con, x)), character(1)
    ), collapse = ", ")
    found <- tryCatch(DBI::dbGetQuery(con, paste0(
      "SELECT ", sql_string(table_name), " AS table_name, count(*) AS duplicate_groups,",
      " sum(rows_in_group) AS rows_affected FROM (SELECT count(*) AS rows_in_group FROM ",
      project_qualified_name(table_name), " GROUP BY ", quoted, " HAVING count(*) > 1)"
    )), error = function(e) NULL)
    if (!is.null(found) && nrow(found) && !is.na(found$rows_affected[[1]])) {
      found$dimensions <- paste(dimensions, collapse = ", ")
      rows[[table_name]] <- found
    }
  }
  report <- dplyr::bind_rows(rows)
  readr::write_csv(report, file.path(root, "outputs", "direct_panel_duplicate_keys.csv"))
  # Only the tables the summary just found duplicates in. The row-level pass
  # ranks over every dimension of a panel, which is not free, and running it over
  # the seventeen panels that have nothing to report would cost the build a
  # measurable amount to produce empty output.
  affected <- if (!nrow(report)) character() else {
    report$table_name[!is.na(report$rows_affected) & report$rows_affected > 0]
  }
  write_direct_panel_duplicate_rows(con, root, tables = affected)
  invisible(report)
}

# A screen counts; a worklist names -- the project's own lesson from the
# discontinuity screen, applied to the panels.
#
# The audit's ER-08.1 asks for the 411 duplicate groups themselves, "with all
# source dimensions, provenance cells, entity, period, measure, labels and
# values", because the question a reviewer has to answer is what the publisher is
# varying between two rows that look identical -- and that question cannot be
# asked of a count. The rows are exported with every dimension the grouping used
# and every measure it excluded, side by side: if the measures differ, the rows
# are two different figures the model cannot tell apart, and if they do not, the
# publisher printed the same record twice.
DIRECT_PANEL_WORKLIST_LIMIT <- 5000L

write_direct_panel_duplicate_rows <- function(con, root, tables = NULL,
                                              limit = DIRECT_PANEL_WORKLIST_LIMIT) {
  if (is.null(root)) return(invisible(NULL))
  panels <- names(direct_panel_natural_keys(con))
  if (!is.null(tables)) panels <- intersect(panels, tables)
  if (!length(panels)) return(invisible(NULL))
  rows <- list()
  for (table_name in panels) {
    columns <- table_column_names(con, table_name)
    provenance <- intersect(
      c("source_row", "release_id", "publication_date", "source_file", "first_ingested_at"), columns
    )
    dimensions <- setdiff(columns, provenance)
    measures <- grep("^(saldo|monto|importe|cantidad|total|valor)", dimensions, value = TRUE)
    dimensions <- setdiff(dimensions, measures)
    if (length(dimensions) < 3L) next
    quote_all <- function(x) paste(vapply(
      x, function(name) as.character(DBI::dbQuoteIdentifier(con, name)), character(1)
    ), collapse = ", ")
    found <- tryCatch(DBI::dbGetQuery(con, paste0(
      "SELECT ", sql_string(table_name), " AS table_name,",
      " dense_rank() OVER (ORDER BY ", quote_all(dimensions), ") AS duplicate_group,",
      " count(*) OVER (PARTITION BY ", quote_all(dimensions), ") AS rows_in_group, *",
      " FROM ", project_qualified_name(table_name),
      " QUALIFY count(*) OVER (PARTITION BY ", quote_all(dimensions), ") > 1",
      " ORDER BY duplicate_group, ",
      if (length(provenance)) quote_all(intersect("source_row", provenance)) else "1"
    )), error = function(e) NULL)
    if (is.null(found) || !nrow(found)) next
    found$repeated_dimensions <- paste(dimensions, collapse = ", ")
    found$measures_compared <- paste(measures, collapse = ", ")
    # Whether the publisher printed two different numbers under one identity, or
    # the same number twice. They call for opposite repairs: the first is a
    # missing dimension, the second is a duplicated display row.
    found$measures_differ <- if (!length(measures)) NA else {
      vapply(seq_len(nrow(found)), function(i) {
        group <- found[found$duplicate_group == found$duplicate_group[[i]], measures, drop = FALSE]
        any(vapply(measures, function(m) length(unique(group[[m]])) > 1L, logical(1)))
      }, logical(1))
    }
    rows[[table_name]] <- found
  }
  worklist <- dplyr::bind_rows(rows)
  if (!nrow(worklist)) return(invisible(NULL))
  total <- nrow(worklist)
  worklist <- utils::head(worklist, limit)
  worklist$worklist_of_total <- total
  readr::write_csv(worklist, file.path(root, "outputs", "panel_duplicate_worklist.csv"))
  invisible(worklist)
}

validate_declared_natural_keys <- function(con, release_id, root = NULL) {
  failures <- character()
  # Since schema 27 the direct panels declare a physical key too -- one database
  # row per worksheet row -- so they are asserted here alongside the staging
  # snapshots rather than only having their provenance columns checked.
  all_declared <- c(STAGING_NATURAL_KEYS, direct_panel_natural_keys(con))
  for (table_name in names(all_declared)) {
    if (!database_object_exists(con, table_name)) next
    columns <- table_column_names(con, table_name)
    declared <- all_declared[[table_name]]
    key <- intersect(declared$key, columns)
    if (!length(key)) next
    qualified <- project_qualified_name(table_name)
    quoted <- paste(vapply(
      key, function(x) as.character(DBI::dbQuoteIdentifier(con, x)), character(1)
    ), collapse = ", ")
    duplicates <- DBI::dbGetQuery(con, paste0(
      "SELECT count(*) AS n FROM (SELECT 1 FROM ", qualified,
      " GROUP BY ", quoted, " HAVING count(*) > 1)"
    ))$n[[1]]
    if (duplicates) failures <- c(failures, paste0(
      table_name, ": ", duplicates, " duplicated (", paste(key, collapse = ", "), ")"
    ))
    required <- intersect(declared$required, columns)
    if (!length(required)) next
    predicate <- paste(vapply(required, function(column) paste0(
      as.character(DBI::dbQuoteIdentifier(con, column)), " IS NULL"
    ), character(1)), collapse = " OR ")
    incomplete <- DBI::dbGetQuery(con, paste0(
      "SELECT count(*) AS n FROM ", qualified, " WHERE ", predicate
    ))$n[[1]]
    if (incomplete) failures <- c(failures, paste0(
      table_name, ": ", incomplete, " row(s) with a null required field (",
      paste(required, collapse = ", "), ")"
    ))
  }
  # The physical key says one database row is one worksheet row. It does not say
  # the publisher's own dimensions identify a record, and on several panels they
  # do not: 399 rows of raw_banks_canales_person repeat a vintage, date, entity,
  # classification and description, some carrying different totals, and
  # raw_banks_inhab splits INHAB and REHAB into complementary rows that share
  # every declared dimension. Those are the publisher varying something this
  # database does not model yet. Guessing the missing dimension would be worse
  # than naming the gap, so they are reported and the tables stay unaggregatable.
  write_direct_panel_duplicate_worklist(con, root)
  # The audit asks for the same gate on "every staging *and direct* table". The
  # direct bank and finance panels keep the publisher's own columns, and their
  # grain is source-specific -- date by entity by account, or by item, or by
  # currency, depending on the worksheet. Declaring a key for each would be this
  # project asserting a grain the publisher has not, which is the mistake the
  # rest of the register exists to avoid. What every direct row must carry is its
  # provenance, and that is checkable without a domain claim.
  direct <- DBI::dbGetQuery(con, paste(
    "SELECT table_schema, table_name FROM information_schema.tables",
    "WHERE table_type = 'BASE TABLE' AND table_name LIKE 'raw\\_%' ESCAPE '\\'"
  ))
  for (i in seq_len(nrow(direct))) {
    qualified <- paste0(
      DBI::dbQuoteIdentifier(con, direct$table_schema[[i]]), ".",
      DBI::dbQuoteIdentifier(con, direct$table_name[[i]])
    )
    columns <- table_column_names(con, direct$table_name[[i]])
    required <- intersect(c("vintage_id", "source_id", "source_sheet"), columns)
    if (!length(required)) next
    predicate <- paste(vapply(required, function(column) paste0(
      as.character(DBI::dbQuoteIdentifier(con, column)), " IS NULL"
    ), character(1)), collapse = " OR ")
    incomplete <- DBI::dbGetQuery(con, paste0(
      "SELECT count(*) AS n FROM ", qualified, " WHERE ", predicate
    ))$n[[1]]
    if (incomplete) failures <- c(failures, paste0(
      direct$table_name[[i]], ": ", incomplete, " row(s) with no vintage, source or worksheet"
    ))
  }
  if (!length(failures)) return(invisible(TRUE))
  insert_quality_flag(
    con, release_id, "error", "declared_natural_key_violated", NA_character_,
    paste0(
      length(failures), " table(s) violate the natural key or required fields they declare: ",
      paste(head(failures, 6), collapse = "; ")
    )
  )
  invisible(FALSE)
}

# The audit's F-12, as a gate. An expected period with no observation is reported
# with the reason it is absent; `unread_source_cell` is the one that matters,
# because it names a workbook cell that holds a number the parser did not read.
validate_observation_missingness <- function(con, release_id) {
  if (!database_object_exists(con, "observation_missingness")) return(invisible(FALSE))
  counts <- DBI::dbGetQuery(con, paste(
    "SELECT reason, count(*) AS periods, count(DISTINCT series_id) AS series FROM",
    project_qualified_name("observation_missingness"), "GROUP BY 1 ORDER BY periods DESC"
  ))
  if (!nrow(counts)) return(invisible(TRUE))
  unknown <- setdiff(counts$reason, OBSERVATION_MISSINGNESS_REASONS)
  if (length(unknown)) insert_quality_flag(
    con, release_id, "error", "missingness_reason_unsupported", NA_character_,
    paste("Unsupported missingness reason(s):", paste(unknown, collapse = "; "))
  )
  # A token the publisher writes that nobody has recorded the meaning of is the
  # one absence that must be named at every release: `s/m` sat in 18,416 cells
  # being counted as blanks, and no gate said so because the classifier had never
  # looked at the text. Reported with the tokens themselves, so the answer is a
  # line in config/source_value_tokens.csv rather than an investigation.
  unregistered <- DBI::dbGetQuery(con, paste(
    "SELECT source_id, source_sheet, source_token, count(*) AS periods FROM",
    project_qualified_name("observation_missingness"),
    "WHERE reason = 'source_token_unreviewed' GROUP BY 1, 2, 3 ORDER BY periods DESC"
  ))
  if (nrow(unregistered)) insert_quality_flag(
    con, release_id, "warning", "source_token_unreviewed", NA_character_,
    paste0(
      format(sum(unregistered$periods), big.mark = ","), " expected observation(s) are absent ",
      "because the cell holds text whose meaning is not recorded in ",
      "config/source_value_tokens.csv, so no worksheet they touch can be promoted. Tokens: ",
      paste(head(paste0(
        "'", unregistered$source_token, "' in ", unregistered$source_id, "/",
        unregistered$source_sheet, " (", format(unregistered$periods, big.mark = ","), ")"
      ), 8), collapse = "; ")
    )
  )
  unread <- counts[counts$reason == "unread_source_cell", , drop = FALSE]
  if (nrow(unread)) insert_quality_flag(
    con, release_id, "warning", "missingness_unread_source_cell", NA_character_,
    paste0(
      format(unread$periods[[1]], big.mark = ","), " expected observation(s) across ",
      format(unread$series[[1]], big.mark = ","), " series are absent while the source cell at ",
      "their coordinate holds a number. See outputs/observation_missingness_latest.csv."
    )
  )
  insert_quality_flag(
    con, release_id, "warning", "observation_missingness_recorded", NA_character_,
    paste0(
      "Expected-period absence is recorded with a reason for ",
      format(sum(counts$periods), big.mark = ","), " period(s): ",
      paste0(counts$reason, " ", format(counts$periods, big.mark = ","), collapse = "; "),
      ". A validated worksheet may not carry unreviewed or unread absence."
    )
  )
  invisible(TRUE)
}

# The audit's F-14, as a gate. Incomplete acquisition evidence is a warning while
# a source is provisional -- it is operator work, not a parser outcome -- and an
# error the moment someone claims a worksheet of that source is validated, since
# a research product nobody can re-acquire is not reproducible.
# The audit's test 7: "assert exactly one active data-product release, while
# historical accepted releases remain immutable".
#
# The pointer is what publishes, so the invariants about it are the ones a
# researcher's whole view of the database rests on: there is exactly one, it names
# a decision that exists, and that decision is an acceptance. Any of the three
# failing means the published surface is not what anybody thinks it is.
#
# `promote_data_release()` maintains all three by construction. This is here for
# the case it exists for -- somebody editing the table by hand -- and because an
# invariant nothing checks is a comment.
validate_active_data_release <- function(con, release_id) {
  if (!database_object_exists(con, "active_data_release")) return(invisible(FALSE))
  # A first build has nothing published yet, and that is not a defect: validation
  # runs before the decision, so on a fresh database the pointer is legitimately
  # empty at this moment. Asserting otherwise would make the database
  # unbootstrappable -- the gate would block the release that was about to create
  # the first product. The invariant applies once something has been accepted.
  ever_accepted <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM", project_qualified_name("data_releases"),
    "WHERE status = 'accepted'"
  ))$n[[1]]
  if (!ever_accepted) return(invisible(TRUE))
  active <- DBI::dbGetQuery(con, paste(
    "SELECT a.data_release_id, a.source_bundle_id, d.status",
    "FROM", project_qualified_name("active_data_release"), "a",
    "LEFT JOIN", project_qualified_name("data_releases"), "d USING (data_release_id)"
  ))
  problems <- character()
  if (nrow(active) != 1L) problems <- c(problems, paste0(
    "there are ", nrow(active), " active data releases and there must be exactly one"
  ))
  if (nrow(active) == 1L) {
    if (is.na(active$status[[1]])) problems <- c(problems, paste0(
      "the active pointer names ", active$data_release_id[[1]],
      ", which has no recorded decision"
    ))
    else if (!identical(active$status[[1]], "accepted")) problems <- c(problems, paste0(
      "the active pointer names a product decided '", active$status[[1]], "'"
    ))
  }
  # Every accepted decision must still name a bundle whose vintages exist, or the
  # published set is empty for a reason nobody would look for.
  orphaned <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM", project_qualified_name("active_data_release"), "a",
    "WHERE NOT EXISTS (SELECT 1 FROM", project_qualified_name("release_sources"), "rs",
    "                  WHERE rs.release_id = a.source_bundle_id)"
  ))$n[[1]]
  if (orphaned) problems <- c(problems, paste(
    "the active pointer names a source bundle with no linked vintages"
  ))
  if (!length(problems)) return(invisible(TRUE))
  insert_quality_flag(
    con, release_id, "error", "active_data_release_invalid", NA_character_,
    paste0(
      "Publication resolves through audit.active_data_release, and it is not in a state that can ",
      "publish anything coherently: ", paste(problems, collapse = "; ")
    )
  )
  invisible(FALSE)
}

# The audit's test 6: "compare every *_latest.csv count and distinct check list to
# the live latest attempt after all phases finish".
#
# The flag report was written before the statistical screens ran, so the file an
# auditor opened had 33 rows where the database had 35 -- and nothing said so.
# The ordering is fixed; this is what keeps it fixed. Run at the very end, after
# the report has been written, and comparing counts rather than trusting them.
# The audit's F-06, as the audit states it in section 11.2: the dashboard must
# hold exactly one row per worksheet, and the query that proves it must return
# zero rows.
#
# An error, not a warning. A coverage report that counts direct investment three
# times is not a diagnostic to read later -- it is a number a reader will add up,
# and 256 rows for 242 worksheets shipped for a whole schema version because
# nothing looked. The check reads the written file rather than re-running the
# query behind it, because the file is what a reader opens and re-running the
# query could only prove the query agrees with itself.
validate_coverage_dashboard <- function(con, release_id, root) {
  if (is.null(root)) return(invisible(FALSE))
  path <- file.path(root, "outputs", "coverage_dashboard.csv")
  if (!file.exists(path)) return(invisible(FALSE))
  dashboard <- readr::read_csv(path, show_col_types = FALSE, progress = FALSE)
  if (!all(c("source_id", "source_sheet") %in% names(dashboard))) return(invisible(FALSE))
  duplicated_keys <- dashboard %>%
    dplyr::count(.data$source_id, .data$source_sheet, name = "rows") %>%
    dplyr::filter(.data$rows > 1L)
  if (!nrow(duplicated_keys)) return(invisible(TRUE))
  insert_quality_flag(
    con, release_id, "error", "coverage_dashboard_duplicate_worksheets", NA_character_,
    paste0(
      nrow(duplicated_keys), " worksheet(s) appear more than once in coverage_dashboard.csv ",
      "(", nrow(dashboard), " rows for ", nrow(dashboard) - sum(duplicated_keys$rows - 1L),
      " worksheets). A register keyed (source_id, source_sheet) is being joined without ",
      "exact-over-wildcard precedence; see wildcard_precedence_join_sql(). Affected: ",
      paste(utils::head(paste0(
        duplicated_keys$source_id, "/", duplicated_keys$source_sheet, " x", duplicated_keys$rows
      ), 10), collapse = "; ")
    )
  )
  invisible(FALSE)
}

# The audit's section 11.3: "A release should block on unclassified rejected
# rows."
#
# Two things are checked and they fail differently. A rejection reason nobody has
# declared is an error: the parser is discarding publisher rows for a cause no
# reviewer has seen, which is the silent-loss defect wearing a label. Rows
# carrying a declared but `unexpected` reason are a warning: the reason is
# understood, and its appearance means the publication changed shape.
#
# It reads every row of discarded_rows, not only the delimited sources, and the
# first run proved why that is the right scope: the ICC/EVE and FX-operations
# parsers have been discarding rows as `non_data_note` since schema 12 under a
# reason no register described. The audit names the CSV path because that is
# where rows were vanishing unrecorded; the principle is not about CSVs.
validate_row_rejection_accounting <- function(con, release_id, root) {
  if (!database_object_exists(con, "discarded_rows")) return(invisible(FALSE))
  register <- read_row_rejection_reasons(root)
  recorded <- DBI::dbGetQuery(con, paste0(
    "SELECT source_id, reason, count(*) AS rows FROM ",
    project_qualified_name("discarded_rows"), " GROUP BY 1, 2 ORDER BY 1, 2"
  ))
  if (!nrow(recorded)) return(invisible(TRUE))
  undeclared <- recorded %>% dplyr::filter(!.data$reason %in% .env$register$reason)
  if (nrow(undeclared)) insert_quality_flag(
    con, release_id, "error", "row_rejection_reason_undeclared", NA_character_,
    paste0(
      sum(undeclared$rows), " row(s) were rejected for ", nrow(undeclared),
      " reason(s) that config/row_rejection_reasons.csv does not declare. Declare each reason ",
      "with what it means, or repair the parser: ",
      paste(utils::head(paste0(
        undeclared$source_id, "/", undeclared$reason, " (", undeclared$rows, ")"
      ), 10), collapse = "; ")
    )
  )
  unexpected <- recorded %>%
    dplyr::inner_join(
      register %>% dplyr::filter(.data$expected == "unexpected") %>% dplyr::select("reason"),
      by = "reason"
    )
  if (nrow(unexpected)) insert_quality_flag(
    con, release_id, "warning", "row_rejection_unexpected_reason", NA_character_,
    paste0(
      sum(unexpected$rows), " row(s) were rejected for a reason the register marks unexpected. ",
      "The publication has changed shape or the contract is wrong: ",
      paste(utils::head(paste0(
        unexpected$source_id, "/", unexpected$reason, " (", unexpected$rows, ")"
      ), 10), collapse = "; ")
    )
  )
  invisible(!nrow(undeclared))
}

read_row_rejection_reasons <- function(root) {
  path <- file.path(root, "config", "row_rejection_reasons.csv")
  if (!file.exists(path)) return(tibble(reason = character(), expected = character()))
  register <- readr::read_csv(
    path, show_col_types = FALSE, col_types = readr::cols(.default = readr::col_character())
  )
  missing <- setdiff(c("reason", "meaning", "expected", "reviewed_by"), names(register))
  if (length(missing)) stop(
    "Row-rejection register: missing column(s) ", paste(missing, collapse = ", "), ".", call. = FALSE
  )
  blank <- register %>% dplyr::filter(
    is.na(.data$meaning) | !nzchar(trimws(.data$meaning)) |
      is.na(.data$reviewed_by) | !nzchar(trimws(.data$reviewed_by))
  )
  if (nrow(blank)) stop(
    "Row-rejection register: ", nrow(blank), " reason(s) declared with no meaning or no reviewer. ",
    "A reason nobody has written down is not a classification.", call. = FALSE
  )
  unsupported <- setdiff(register$expected, c("expected", "unexpected"))
  if (length(unsupported)) stop(
    "Row-rejection register: `expected` must be 'expected' or 'unexpected', not: ",
    paste(unsupported, collapse = ", "), ".", call. = FALSE
  )
  # The register and the code vocabulary have to be the same set, in both
  # directions. A reason a parser can write and the register does not describe is
  # the defect the register exists to prevent; a reason the register describes and
  # no parser can write is a claim about a behaviour that does not exist.
  undeclared <- setdiff(ROW_REJECTION_REASONS, register$reason)
  if (length(undeclared)) stop(
    "Row-rejection register: ", length(undeclared), " reason(s) a parser may record are not ",
    "declared: ", paste(undeclared, collapse = ", "),
    ". Say what each one means in config/row_rejection_reasons.csv.", call. = FALSE
  )
  invented <- setdiff(register$reason, ROW_REJECTION_REASONS)
  if (length(invented)) stop(
    "Row-rejection register: ", length(invented), " declared reason(s) no parser can record: ",
    paste(invented, collapse = ", "),
    ". Add them to ROW_REJECTION_REASONS or remove them from the register.", call. = FALSE
  )
  register
}

validate_report_agreement <- function(con, release_id, root) {
  if (is.null(root)) return(invisible(FALSE))
  attempt_id <- current_attempt_id(con, release_id)
  checks <- list(
    list(
      file = "quality_flags_latest.csv",
      n = DBI::dbGetQuery(con, paste0(
        "SELECT count(*) AS n FROM ", project_qualified_name("quality_flags"),
        " WHERE ", attempt_flags_predicate(con, release_id)
      ))$n[[1]],
      label = "quality flags raised by this attempt"
    ),
    list(
      file = "observation_missingness_latest.csv",
      n = NA_integer_, label = "missingness rows"
    )
  )
  mismatches <- character()
  for (check in checks) {
    path <- file.path(root, "outputs", check$file)
    if (!file.exists(path) || is.na(check$n)) next
    rows <- nrow(readr::read_csv(path, show_col_types = FALSE, progress = FALSE))
    if (!identical(as.integer(rows), as.integer(check$n))) mismatches <- c(mismatches, paste0(
      check$file, " holds ", rows, " row(s) where the database holds ", check$n,
      " ", check$label
    ))
  }
  if (!length(mismatches)) return(invisible(TRUE))
  insert_quality_flag(
    con, release_id, "warning", "report_disagrees_with_database", NA_character_,
    paste0(
      "A generated report does not describe the database beside it, which is how a reader is ",
      "misled by a file that looks authoritative: ", paste(mismatches, collapse = "; ")
    )
  )
  invisible(FALSE)
}

# The seventh audit's F-03, mechanical half.
#
# "Retain every subsequent source vintage" is a monthly commitment and not
# something code can perform. What code can do is make the retention *checkable*,
# and until now nothing verified that a vintage the database claims to hold still
# has its bytes. The whole point-in-time story rests on the archive: a vintage
# whose archived workbook is gone cannot be re-read, re-parsed or re-checked, and
# the database would go on reporting its observations as though it could.
#
# Every archived file is re-hashed on every release. Measured at 0.38 seconds for
# all 22 -- 104 MiB -- against a 49-second run, which is cheap enough that
# sampling or trusting the file size would be a false economy.
# The seventh audit's section 11.4. A gate that passes vacuously today, which is
# why it is written now rather than after the first promotion.
#
# The register is empty, so there is nothing to reject. That is the point: the
# first row anybody writes is the one that decides whether "reviewed" means
# anything, and by then the gate has to already exist. Schema 28 wrote the
# research-eligibility gate on the same reasoning and for the same reason.
#
# Error severity, not warning. A half-completed review is worse than none: it
# fills the columns the eligibility gate checks, so the series becomes eligible
# for marts.v_research_series on the strength of a row whose reviewer never
# finished it.
# The seventh audit's P2: "Profile missingness generation as vintages accumulate.
# Prevents expected-grid growth from becoming dominant."
#
# The phase builds one row per regular series-period per vintage and then prunes:
# a period survives only where it is an observation or an explained absence. So
# the *stored* table is small -- 267,830 rows -- while the phase is the slowest
# in the run at 24.6 of 82.9 seconds. Both scale linearly in retained vintages,
# and retaining vintages is what P1 asks for.
#
# Worth recording, because the audit's table of core interfaces reports this
# table at 9,152,525 rows and calls it the largest in the database. It is not:
# the live database held 267,830 before this round and holds 267,830 after. The
# nine million is the intermediate the phase constructs before pruning, which is
# real and is what costs the time -- but it is not a row count anyone can query,
# and reporting it as one sends a reader looking for a table that is 34 times
# smaller than described.
#
# So the shape is measured rather than assumed, and the seconds lead: rows,
# retained vintages, contributing vintages and elapsed time together. A warning,
# not an error -- growth is the consequence of doing the right thing with
# vintages, and the release should say so rather than block on it.
EXPECTED_GRID_ROW_BUDGET <- 25e6
EXPECTED_GRID_SECONDS_BUDGET <- 120

expected_grid_profile <- function(con, attempt_id = NULL) {
  if (!database_object_exists(con, "expected_observation_grid")) return(NULL)
  rows <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS grid_rows, count(DISTINCT vintage_id) AS grid_vintages FROM",
    project_qualified_name("expected_observation_grid")
  ))
  vintages <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS retained_vintages FROM", project_qualified_name("source_files")
  ))$retained_vintages[[1]]
  seconds <- NA_real_
  if (database_object_exists(con, "ingestion_stage_timings") && !is.null(attempt_id) &&
      !is.na(attempt_id)) {
    measured <- DBI::dbGetQuery(con, paste0(
      "SELECT sum(elapsed_seconds) AS seconds FROM ",
      project_qualified_name("ingestion_stage_timings"),
      " WHERE stage = 'observation_missingness' AND attempt_id = ", sql_string(attempt_id)
    ))$seconds[[1]]
    if (length(measured) && !is.na(measured)) seconds <- as.numeric(measured)
  }
  list(
    grid_rows = as.numeric(rows$grid_rows[[1]]),
    grid_vintages = as.integer(rows$grid_vintages[[1]]),
    retained_vintages = as.integer(vintages),
    rows_per_vintage = if (rows$grid_vintages[[1]] > 0) {
      as.numeric(rows$grid_rows[[1]]) / as.numeric(rows$grid_vintages[[1]])
    } else NA_real_,
    seconds = seconds
  )
}

validate_expected_grid_growth <- function(con, release_id, attempt_id = NULL) {
  profile <- expected_grid_profile(con, attempt_id)
  if (is.null(profile) || !profile$grid_rows) return(invisible(FALSE))
  over <- character()
  if (profile$grid_rows > EXPECTED_GRID_ROW_BUDGET) over <- c(over, paste0(
    format(profile$grid_rows, big.mark = ",", scientific = FALSE), " grid rows against a budget of ",
    format(EXPECTED_GRID_ROW_BUDGET, big.mark = ",", scientific = FALSE)
  ))
  if (!is.na(profile$seconds) && profile$seconds > EXPECTED_GRID_SECONDS_BUDGET) {
    over <- c(over, sprintf(
      "%.1f seconds against a budget of %d", profile$seconds, EXPECTED_GRID_SECONDS_BUDGET
    ))
  }
  if (!length(over)) return(invisible(TRUE))
  insert_quality_flag(
    con, release_id, "warning", "expected_grid_growth_budget", NA_character_,
    paste0(
      "The expected-observation grid has outgrown its budget: ", paste(over, collapse = "; "),
      ". It holds ", format(round(profile$rows_per_vintage), big.mark = ","),
      " rows per vintage across ", profile$retained_vintages,
      " retained vintages and grows linearly in them. Partition the grid by vintage, or ",
      "compute missingness only for the vintages a published view can reach."
    )
  )
  invisible(FALSE)
}

validate_series_review_register <- function(con, release_id, root) {
  if (is.null(root) || !database_object_exists(con, "series_review")) return(invisible(FALSE))
  register <- read_series_review_register(root)
  known <- if (database_object_exists(con, "dim_series")) DBI::dbGetQuery(
    con, paste("SELECT series_id FROM", project_qualified_name("dim_series"))
  )$series_id else character()
  problems <- series_review_problems(register, known, known_series_frequencies(con))
  if (!nrow(problems)) return(invisible(TRUE))
  insert_quality_flag(
    con, release_id, "error", "series_review_incomplete", NA_character_,
    paste0(
      nrow(problems), " problem(s) in config/series_review.csv across ",
      length(unique(problems$series_id)), " series. **No row of the register has been applied**, ",
      "because a partly-recorded review would fill exactly the fields the research-eligibility ",
      "gate reads: ",
      paste(utils::head(paste0(problems$series_id, ": ", problems$problem), 10), collapse = "; ")
    )
  )
  invisible(FALSE)
}

validate_archive_integrity <- function(con, release_id, root) {
  if (is.null(root) || !database_object_exists(con, "source_files")) return(invisible(FALSE))
  files <- DBI::dbGetQuery(con, paste(
    "SELECT source_id, vintage_id, source_file, sha256, size_bytes, publication_date,",
    "ingestion_status,",
    if ("archive_uri" %in% table_column_names(con, "source_files")) "archive_uri," else "NULL AS archive_uri,",
    "archive_path FROM", project_qualified_name("source_files"), "ORDER BY source_id, vintage_id"
  ))
  if (!nrow(files)) return(invisible(TRUE))

  # The portable URI first, because it means the same thing on anyone's machine;
  # the run-local absolute path second; and the content-addressed convention
  # last, which is how a distribution copy with its paths scrubbed still resolves.
  resolve <- function(i) {
    candidates <- c(
      if (!is.na(files$archive_uri[[i]])) file.path(root, files$archive_uri[[i]]),
      if (!is.na(files$archive_path[[i]])) files$archive_path[[i]],
      Sys.glob(file.path(
        root, "input_archive", files$source_id[[i]], paste0(files$sha256[[i]], ".*")
      ))
    )
    found <- candidates[file.exists(candidates)]
    if (length(found)) found[[1]] else NA_character_
  }

  status <- vapply(seq_len(nrow(files)), function(i) {
    path <- resolve(i)
    if (is.na(path)) return("missing")
    if (is.na(files$sha256[[i]])) return("unhashed")
    if (!identical(digest::digest(file = path, algo = "sha256"), files$sha256[[i]])) {
      return("hash_mismatch")
    }
    "verified"
  }, character(1))

  retained <- as.integer(table(files$source_id)[files$source_id])
  readr::write_csv(
    tibble(
      source_id = files$source_id, vintage_id = files$vintage_id,
      source_file = files$source_file, sha256 = files$sha256,
      publication_date = files$publication_date, ingestion_status = files$ingestion_status,
      archive_status = status, retained_vintages_for_source = retained,
      # Stated per row rather than left to be inferred, because "one vintage per
      # source" is the fact behind series_as_of_date() returning nothing, and it
      # should not take an external audit to discover it.
      point_in_time_note = ifelse(
        retained > 1L, "more than one vintage retained; revision and as-of queries have something to compare",
        "only vintage retained for this source; no revision history and no as-of reconstruction is possible"
      )
    ),
    file.path(root, "outputs", "vintage_retention_status.csv")
  )

  broken <- files[status %in% c("missing", "hash_mismatch"), , drop = FALSE]
  broken_status <- status[status %in% c("missing", "hash_mismatch")]
  if (nrow(broken)) insert_quality_flag(
    con, release_id, "error", "archived_vintage_unverifiable", NA_character_,
    paste0(
      nrow(broken), " retained vintage(s) cannot be verified against their archived bytes. ",
      "A vintage the database reports but cannot re-read is not retained: ",
      paste(utils::head(paste0(
        broken$source_id, "/", broken$vintage_id, " (", broken_status, ")"
      ), 10), collapse = "; ")
    )
  )
  invisible(!nrow(broken))
}

validate_source_provenance <- function(con, release_id, root) {
  if (!database_object_exists(con, "source_provenance")) return(invisible(FALSE))
  status <- DBI::dbGetQuery(con, paste(
    "SELECT source_id, vintage_id, official_url, release_identifier, retrieved_at, retrieval_method",
    "FROM", project_qualified_name("source_provenance")
  ))
  if (!nrow(status)) return(invisible(TRUE))
  incomplete <- status[
    is.na(status$official_url) | is.na(status$release_identifier) |
      is.na(status$retrieved_at) | is.na(status$retrieval_method), , drop = FALSE
  ]
  if (!is.null(root)) readr::write_csv(
    status, file.path(root, "outputs", "source_provenance_status.csv")
  )
  # The audit's R6-04. Reporting that provenance is incomplete has not moved it
  # in three rounds, because "22 vintages are incomplete" is not a task anybody
  # can pick up. This says, per vintage, exactly which fields are missing and what
  # the consequence is -- and it names available_at separately from the other
  # four, because that is the one blocking every point-in-time claim the database
  # makes. The values are the operator's to supply; none is invented here.
  if (!is.null(root)) {
    fields <- c("official_url", "release_identifier", "retrieved_at", "retrieval_method")
    available <- DBI::dbGetQuery(con, paste(
      "SELECT vintage_id, available_at, availability_quality FROM",
      project_qualified_name("source_provenance")
    ))
    status$available_at <- available$available_at[match(status$vintage_id, available$vintage_id)]
    status$availability_quality <- available$availability_quality[
      match(status$vintage_id, available$vintage_id)
    ]
    dated <- DBI::dbGetQuery(con, paste(
      "SELECT vintage_id, publication_date, publication_date_source FROM",
      project_qualified_name("source_files")
    ))
    worklist <- tibble(
      source_id = status$source_id, vintage_id = status$vintage_id,
      missing_fields = vapply(seq_len(nrow(status)), function(i) {
        absent <- fields[vapply(fields, function(f) is.na(status[[f]][[i]]), logical(1))]
        if (is.na(status$available_at[[i]])) absent <- c("available_at", absent)
        paste(absent, collapse = "; ")
      }, character(1)),
      publication_date = dated$publication_date[match(status$vintage_id, dated$vintage_id)],
      publication_date_source = dated$publication_date_source[
        match(status$vintage_id, dated$vintage_id)
      ],
      # Beside what is missing, how good what is present actually is. Schema 39
      # fills retrieved_at for every vintage from the moment the file entered
      # the immutable archive, which bounds acquisition from above and is
      # therefore safe -- but it is not the publisher's release timestamp, and a
      # worklist that stopped naming the difference would read as though the
      # provenance question had been answered.
      availability_quality = status$availability_quality
    )
    worklist$consequence <- ifelse(
      grepl("available_at", worklist$missing_fields, fixed = TRUE) &
        worklist$publication_date_source %in% c("content_max_period", "pending_content_inference"),
      "as-of ranking falls back to a date derived from the content maximum, which is the reference period and not an availability fact",
      ifelse(
        grepl("available_at", worklist$missing_fields, fixed = TRUE),
        "as-of ranking falls back to the publication date read from the filename",
        ifelse(
          worklist$availability_quality %in% "inferred_upper_bound",
          paste(
            "the vintage cannot be independently re-acquired, and availability is an upper",
            "bound taken from the archive time rather than the publisher's release timestamp,",
            "so an as-of query sees this vintage later than a researcher really could have"
          ),
          "the vintage cannot be independently re-acquired"
        )
      )
    )
    worklist <- worklist[nzchar(worklist$missing_fields), , drop = FALSE]
    worklist <- worklist[order(worklist$source_id), , drop = FALSE]
    readr::write_csv(worklist, file.path(root, "outputs", "source_provenance_worklist.csv"))
  }
  if (!nrow(incomplete)) return(invisible(TRUE))
  validated_sources <- if (database_object_exists(con, "table_status")) {
    DBI::dbGetQuery(con, paste(
      "SELECT DISTINCT source_id FROM", project_qualified_name("table_status"),
      "WHERE status = 'validated'"
    ))$source_id
  } else character()
  blocking <- intersect(incomplete$source_id, validated_sources)
  insert_quality_flag(
    con, release_id, if (length(blocking)) "error" else "warning",
    "source_provenance_incomplete", NA_character_,
    paste0(
      nrow(incomplete), " source vintage(s) have no official URL, release identifier, retrieval ",
      "timestamp or retrieval method in config/source_vintages.csv, so they cannot be independently ",
      "re-acquired. ",
      if (length(blocking)) paste0(
        "This blocks the release because ", paste(blocking, collapse = ", "),
        " carr", if (length(blocking) == 1L) "ies" else "y", " a validated worksheet. "
      ) else "",
      "See outputs/source_provenance_status.csv."
    )
  )
  invisible(!length(blocking))
}

# How good the availability evidence is, checked as evidence rather than counted
# as presence. The audit's ER-04 asks for availability to be defined
# conservatively and for the weaker definition to declare itself, because a
# point-in-time result computed from an archive timestamp and one computed from
# a publisher's release timestamp are different claims that arrive in the same
# column.
#
# An undeclared value blocks: a vocabulary nobody enforces is a vocabulary two
# operators will spell differently. An inferred bound warns, once, with the count
# -- it is the honest state of a database whose vintages predate any acquisition
# procedure, and it must stay visible without stopping every build until history
# that cannot be recreated has been recreated.
validate_availability_quality <- function(con, release_id) {
  if (!database_object_exists(con, "source_provenance")) return(invisible(FALSE))
  if (!"availability_quality" %in% table_column_names(con, "source_provenance")) {
    return(invisible(FALSE))
  }
  quality <- DBI::dbGetQuery(con, paste(
    "SELECT vintage_id, source_id, available_at, availability_quality FROM",
    project_qualified_name("source_provenance")
  ))
  if (!nrow(quality)) return(invisible(TRUE))
  undeclared <- quality[
    !is.na(quality$available_at) &
      !quality$availability_quality %in% AVAILABILITY_QUALITY_VALUES, , drop = FALSE
  ]
  if (nrow(undeclared)) insert_quality_flag(
    con, release_id, "error", "availability_quality_undeclared", NA_character_,
    paste0(
      nrow(undeclared), " vintage(s) carry an availability timestamp with no declared quality, or ",
      "one outside the published vocabulary (",
      paste(AVAILABILITY_QUALITY_VALUES, collapse = ", "),
      "). Availability decides what a point-in-time query may return, so how it was established ",
      "is part of the answer and not an optional annotation: ",
      paste(utils::head(unique(undeclared$source_id), 10), collapse = ", ")
    )
  )
  inferred <- sum(quality$availability_quality %in% "inferred_upper_bound", na.rm = TRUE)
  if (inferred) insert_quality_flag(
    con, release_id, "warning", "availability_inferred_upper_bound", NA_character_,
    paste0(
      inferred, " of ", nrow(quality), " vintage(s) date availability from the moment the file ",
      "entered the immutable archive rather than from a publisher's release timestamp. The bound ",
      "is safe -- it is later than real availability, so an as-of query sees less than a ",
      "researcher could have seen and never more -- but it is not evidence of when the ",
      "publication appeared, and a real-time claim must not be made from it. ",
      "outputs/source_provenance_worklist.csv names the missing field per vintage; ",
      "docs/ACQUISITION_RUNBOOK.md is the procedure that stops this recurring for future releases."
    )
  )
  invisible(!nrow(undeclared))
}

# --- The temporal contract ---------------------------------------------------
# The audit's ER-02, enforced rather than described.
#
# docs/TEMPORAL_CONTRACT.md states what a published period means per frequency.
# This is the half of it a document cannot do: the bounds are ordered and
# contain the parsed date, and the canonical key is unique, on every observation
# of every release. Measured on schema 38 before the contract existed, all three
# already held for 1.2 million observations -- which is what makes them safe as
# blocking checks rather than warnings, and what makes a future violation a
# genuine regression rather than a backlog.
#
# The convention check is the one that cannot block, and deliberately so. 164
# monthly series alternate between month-start and month-end dating inside a
# single series; that is a real and unresolved property of the sources, the
# bounds are what make it harmless, and blocking the release over it would stop
# the database being published in order to protest about the database. It is a
# warning with a worklist, and an error only where it reaches a research
# surface, which is where a wrong lag would actually reach an estimate.
validate_temporal_contract <- function(con, release_id, root = NULL) {
  if (!database_object_exists(con, "v_series_observations")) return(invisible(FALSE))
  scalar <- function(sql) DBI::dbGetQuery(con, sql)$n[[1]]
  gate <- function(check_name, detail) insert_quality_flag(
    con, release_id, "error", check_name, NA_character_, detail
  )
  unordered <- scalar(paste(
    "SELECT count(*) AS n FROM main.v_series_observations",
    "WHERE period_start IS NULL OR period_end IS NULL",
    "   OR period_end < period_start OR period < period_start OR period > period_end"
  ))
  if (unordered) gate("temporal_bounds_unordered", paste0(
    unordered, " observation(s) carry a period interval that is null, reversed, or does not ",
    "contain the date the publisher printed. The bounds are the join key every cross-source ",
    "monthly sample is built on; an interval that does not contain its own observation cannot ",
    "carry one."
  ))
  duplicated_keys <- scalar(paste(
    "SELECT count(*) AS n FROM (SELECT 1 FROM main.v_series_observations",
    "WHERE NOT is_deleted GROUP BY series_id, period_start HAVING count(*) > 1)"
  ))
  if (duplicated_keys) gate("temporal_canonical_key_duplicated", paste0(
    duplicated_keys, " series-period key(s) occur more than once after normalisation. The ",
    "canonical period is what a researcher joins and lags on, so two observations sharing one ",
    "would silently become whichever the optimiser returned -- the failure the normalisation ",
    "exists to prevent, one layer further in."
  ))
  # The mixed-convention series, ranked and exported rather than merely counted.
  mixed <- tryCatch(DBI::dbGetQuery(con, paste(
    "WITH o AS (",
    "  SELECT o.series_id, o.frequency, o.period,",
    "    CASE WHEN day(o.period) = 1 THEN 'month_start'",
    "         WHEN day(o.period) >= 28 THEN 'month_end' ELSE 'other' END AS convention",
    "  FROM main.v_series_observations o",
    "  WHERE o.frequency IN ('monthly', 'monthly_survey') AND NOT o.is_deleted",
    ")",
    "SELECT o.series_id, count(DISTINCT o.convention) AS conventions,",
    "  count(*) FILTER (WHERE o.convention = 'month_start') AS observations_month_start,",
    "  count(*) FILTER (WHERE o.convention = 'month_end') AS observations_month_end,",
    "  count(*) FILTER (WHERE o.convention = 'other') AS observations_other,",
    "  min(o.period) AS first_period, max(o.period) AS last_period, count(*) AS observations",
    "FROM o GROUP BY 1 HAVING count(DISTINCT o.convention) > 1"
  )), error = function(e) NULL)
  if (is.null(mixed)) return(invisible(TRUE))
  if (nrow(mixed) && !is.null(root)) {
    catalogue <- DBI::dbGetQuery(con, paste(
      "SELECT series_id, label, source_id, unit_code FROM",
      project_qualified_name("dim_series")
    ))
    sheets <- tryCatch(DBI::dbGetQuery(con, paste(
      "SELECT series_id, string_agg(DISTINCT source_sheet, '; ') AS source_sheet FROM",
      project_qualified_name("documented_series_snapshot"), "GROUP BY series_id"
    )), error = function(e) NULL)
    eligible <- temporal_research_series(con)
    worklist <- mixed %>%
      dplyr::left_join(catalogue, by = "series_id")
    worklist$source_sheet <- if (is.null(sheets)) NA_character_ else {
      sheets$source_sheet[match(worklist$series_id, sheets$series_id)]
    }
    # Ranked by what a wrong lag would cost, not by how many observations the
    # series happens to have: a series on the research surface first, then one
    # that changes convention often enough that the change is structural rather
    # than a single stray date.
    worklist$review_priority <- ifelse(
      worklist$series_id %in% eligible, "1_research_eligible",
      ifelse(
        pmin(worklist$observations_month_start, worklist$observations_month_end) > 1L,
        "2_structural_change", "3_isolated_dates"
      )
    )
    worklist <- worklist[order(worklist$review_priority, -worklist$observations), , drop = FALSE]
    readr::write_csv(worklist, file.path(root, "outputs", "temporal_convention_worklist.csv"))
  }
  blocking <- intersect(mixed$series_id, temporal_research_series(con))
  if (length(blocking)) gate("temporal_convention_mixed_on_research_series", paste0(
    length(blocking), " research-eligible series change day convention inside their own history. ",
    "A series whose time index alternates between the first and the last day of the month ",
    "produces wrong lags and wrong differences in any time-series package, silently, and a ",
    "reviewed series is one an estimate is entitled to be built on: ",
    paste(utils::head(blocking, 10), collapse = ", ")
  )) else if (nrow(mixed)) insert_quality_flag(
    con, release_id, "warning", "temporal_convention_mixed", NA_character_,
    paste0(
      nrow(mixed), " monthly series change day convention inside their own history. The ",
      "normalised bounds make a join over them safe, so this does not block; what it does mean ",
      "is that the raw `period` column of these series is not a regular index and must not be ",
      "differenced or lagged directly. Ranked in outputs/temporal_convention_worklist.csv."
    )
  )
  invisible(!length(blocking))
}

# Series a reviewer has admitted to the research surface. Empty until the review
# register is filled in, which is why the convention check above cannot be an
# error today and will become one for exactly the series that matter.
temporal_research_series <- function(con) {
  if (!database_object_exists(con, "v_research_series")) return(character())
  tryCatch(
    DBI::dbGetQuery(con, "SELECT series_id FROM marts.v_research_series")$series_id,
    error = function(e) character()
  )
}

# --- Build reproducibility ---------------------------------------------------
# The audit's ER-12.3: "make dirty-tree publication fail closed or require an
# explicit development override that cannot be confused with a research
# release."
#
# `git_dirty` has been recorded on every build since schema 26 and read by
# nothing. It is folded into build_id, so a dirty build is at least
# distinguishable from a clean one after the fact -- but nothing stopped one
# being published, and a citable release built from code that is not in the
# history cannot be reproduced by anybody, including its author.
#
# The override is the same shape as the environment check's, deliberately: the
# environment variable is spelled out, it cannot be set by accident, and taking
# it records a warning on the build that says it was taken. A release with that
# flag on it is visibly a development build.
#
# A git call that fails is NA, never FALSE, and NA blocks. A dirtiness check that
# cannot tell whether the tree is clean must not answer "clean".
validate_build_reproducibility <- function(con, release_id, root) {
  if (is.null(root)) return(invisible(FALSE))
  state <- git_build_state(root)
  if (is.na(state$dirty)) {
    insert_quality_flag(
      con, release_id, "warning", "build_git_state_unknown", NA_character_,
      paste0(
        "Whether the code that produced this build is committed could not be determined -- ",
        root, " does not answer as a git checkout. The build is recorded with git_dirty = NA, ",
        "and it cannot be cited as reproducible from a commit."
      )
    )
    return(invisible(TRUE))
  }
  if (!isTRUE(state$dirty)) return(invisible(TRUE))
  overridden <- identical(Sys.getenv("PARAGUAY_MACRO_ALLOW_DIRTY_BUILD"), "1")
  insert_quality_flag(
    con, release_id, if (overridden) "warning" else "error",
    if (overridden) "dirty_tree_build_overridden" else "dirty_tree_build", NA_character_,
    if (overridden) paste0(
      "PARAGUAY_MACRO_ALLOW_DIRTY_BUILD=1: this database was built from a working tree with ",
      "uncommitted tracked changes at commit ", state$commit, ". It is a development build. The ",
      "code that produced it is not in the history, so the build cannot be reproduced from the ",
      "commit it names, and it must not be cited as a research release."
    ) else paste0(
      "This database would be built from a working tree with uncommitted tracked changes at ",
      "commit ", state$commit, ", so nothing could reproduce it -- the code that made it is not ",
      "in the history. Commit the tree and re-run. If this is deliberately a development build, ",
      "PARAGUAY_MACRO_ALLOW_DIRTY_BUILD=1 proceeds and records the fact on the build. ",
      "The database file itself is excluded from this test: a run writes it, so counting it ",
      "would make every build dirty by construction."
    )
  )
  invisible(overridden)
}

# --- The queryable hierarchy -------------------------------------------------
# The audit's ER-06.4: "validate that each child has the intended parent by
# regime and that queryable hierarchies are acyclic."
#
# series_review_problems() already refuses a cycle declared in the review
# register. This is the other half: the hierarchy actually stored on
# dim_series.parent_series_id, which is what a recursive query would walk. A
# cycle there is not a data-quality opinion -- it makes any roll-up either
# non-terminating or double-counting, and the answer it produces is wrong in a
# way no reviewer would see in the output.
#
# 20 series carry a parent today, none self-parenting, none dangling and none in
# a cycle. That is what makes this an error rather than a queue: it holds now, so
# a violation is a regression somebody just introduced.
validate_series_hierarchy_acyclic <- function(con, release_id) {
  if (!database_object_exists(con, "dim_series")) return(invisible(FALSE))
  if (!"parent_series_id" %in% table_column_names(con, "dim_series")) return(invisible(FALSE))
  series <- project_qualified_name("dim_series")
  gate <- function(check_name, detail) insert_quality_flag(
    con, release_id, "error", check_name, NA_character_, detail
  )
  dangling <- DBI::dbGetQuery(con, paste0(
    "SELECT d.series_id, d.parent_series_id FROM ", series, " d",
    " WHERE d.parent_series_id IS NOT NULL AND NOT EXISTS (",
    "   SELECT 1 FROM ", series, " p WHERE p.series_id = d.parent_series_id)"
  ))
  if (nrow(dangling)) gate("series_parent_missing", paste0(
    nrow(dangling), " series name a parent that is not in the catalogue, so the component would ",
    "be excluded from its own total by a join that returns no error: ",
    paste(utils::head(paste0(dangling$series_id, " -> ", dangling$parent_series_id), 5),
          collapse = "; ")
  ))
  # Depth-bounded, because an unbounded recursion over a cycle is the failure it
  # is looking for. Anything still walking at 50 levels is cyclic or is a
  # hierarchy nobody intended.
  cyclic <- tryCatch(DBI::dbGetQuery(con, paste0(
    "WITH RECURSIVE walk(root, node, depth) AS (",
    "  SELECT series_id, parent_series_id, 1 FROM ", series,
    "  WHERE parent_series_id IS NOT NULL",
    "  UNION ALL",
    "  SELECT w.root, d.parent_series_id, w.depth + 1 FROM walk w",
    "  JOIN ", series, " d ON d.series_id = w.node",
    "  WHERE d.parent_series_id IS NOT NULL AND w.depth < 50",
    ") SELECT DISTINCT root FROM walk WHERE node = root"
  )), error = function(e) NULL)
  if (!is.null(cyclic) && nrow(cyclic)) gate("series_hierarchy_cycle", paste0(
    nrow(cyclic), " series sit in a parent cycle. Summing a component into a total that is ",
    "already one of its own ancestors double-counts by an amount nothing in the result reveals: ",
    paste(utils::head(cyclic$root, 5), collapse = "; ")
  ))
  invisible(!nrow(dangling) && (is.null(cyclic) || !nrow(cyclic)))
}

# --- The unit register and the unit-family check -----------------------------

# A reviewed correction that applies to nothing is worse than no correction: the
# reviewer believes the defect is fixed and it is not. apply_unit_overrides()
# refuses to apply a register with any problem in it, and this is how the
# operator finds out -- with the row and the reason, not a silent no-op.
validate_unit_overrides <- function(con, release_id, root) {
  register <- tryCatch(read_unit_override_register(root), error = function(e) NULL)
  if (is.null(register)) {
    insert_quality_flag(
      con, release_id, "error", "unit_override_register_unreadable", NA_character_,
      "config/unit_overrides.csv could not be read. A register that cannot be parsed applies none of its corrections."
    )
    return(invisible(FALSE))
  }
  if (!nrow(register)) return(invisible(TRUE))
  problems <- unit_override_problems(register, unit_override_series_placement(con))
  if (!nrow(problems)) return(invisible(TRUE))
  insert_quality_flag(
    con, release_id, "error", "unit_override_register_incomplete", NA_character_,
    paste0(
      nrow(problems), " problem(s) in config/unit_overrides.csv. None of its corrections has been ",
      "applied -- a half-applied set of unit corrections is a database in a state no reviewer ",
      "approved. ",
      paste(utils::head(paste0(problems$series_id, ": ", problems$problem), 10), collapse = " ")
    )
  )
  invisible(FALSE)
}

# The Spanish currency vocabulary the publisher writes in its column headers,
# longest first so "Dólar Canadiense" is not read as the US dollar.
#
# `peso` on its own is deliberately absent. CUADRO 60a's third column is headed
# exactly that and is the Argentine peso, which the arithmetic against the
# dollar column shows and the header does not -- so an unqualified `peso` is
# ambiguous, and an ambiguous label is not evidence of a contradiction any more
# than it is evidence of agreement.
UNIT_CURRENCY_LABEL_PATTERNS <- c(
  "dolar canadiense" = "CAD", "dolar australiano" = "AUD",
  "peso argentino" = "ARS", "peso uruguayo" = "UYU", "peso chileno" = "CLP",
  "peso boliviano" = "BOB", "corona sueca" = "SEK", "corona danesa" = "DKK",
  "libra esterlina" = "GBP", "franco suizo" = "CHF",
  "euro" = "EUR", "\\breal\\b" = "BRL", "\\byen\\b" = "JPY",
  "\\busd\\b|dolar americano|\\bdolar\\b" = "USD", "guarani" = "PYG"
)

# Wording that says a column is an index number, whatever unit the worksheet
# assigned it. "= 100" is the decisive one: a base statement is not something a
# price of foreign currency has.
UNIT_INDEX_LABEL_PATTERN <- "=\\s*100|\\bindice\\b|tipo de cambio real|\\btcr\\b"

# The audit's ER-01.5: compare the declared unit family with what the table and
# column actually say, and treat magnitude as a warning rather than proof.
#
# Both halves of the finding are reproducible from this check. On CUADRO 60a the
# euro and real columns declared a US-dollar denominator while their headers name
# a different currency; on CUADRO 60c five index columns declared a currency pair
# under a title reading "(enero 1995 = 100)". Neither is inferred from the
# numbers -- the publisher wrote both facts down, in the header and in the title,
# and the parser's worksheet-level unit inheritance overwrote them.
#
# Warning severity throughout, on purpose. This reads free text, and free text
# produces false positives; a check that reads prose and stops the release is a
# check somebody will delete. The fail-closed consequence is carried where it
# belongs -- an unresolved series cannot pass the research-eligibility gate --
# and here the job is to put the question in front of a reviewer.
validate_unit_family_plausibility <- function(con, release_id) {
  if (!database_object_exists(con, "dim_series")) return(invisible(FALSE))
  series <- tryCatch(DBI::dbGetQuery(con, paste(
    "SELECT d.series_id, d.label, d.unit_code, d.currency,",
    "  coalesce(t.table_title, '') AS table_title, coalesce(t.source_sheet, '') AS source_sheet",
    "FROM", project_qualified_name("dim_series"), "d",
    "LEFT JOIN (SELECT series_id, any_value(table_title) AS table_title,",
    "                  any_value(source_sheet) AS source_sheet",
    "           FROM", project_qualified_name("documented_series_snapshot"),
    "           GROUP BY series_id) t ON t.series_id = d.series_id",
    "WHERE d.unit_code IS NOT NULL"
  )), error = function(e) NULL)
  if (is.null(series) || !nrow(series)) return(invisible(TRUE))
  # The same folding the derivation layer applies, so a pattern that matches a
  # published label here matches it there.
  folded <- function(x) normalize_semantic_label(ifelse(is.na(x), "", x))
  label <- folded(series$label)
  title <- folded(series$table_title)
  pair <- grepl("^[A-Z]{3}_PER_[A-Z]{3}$", series$unit_code)
  denominator <- ifelse(pair, sub("^[A-Z]{3}_PER_", "", series$unit_code), NA_character_)

  # What currency does the column header name, where it names one at all?
  named <- rep(NA_character_, nrow(series))
  for (pattern in names(UNIT_CURRENCY_LABEL_PATTERNS)) {
    hit <- is.na(named) & grepl(pattern, label)
    named[hit] <- UNIT_CURRENCY_LABEL_PATTERNS[[pattern]]
  }
  contradicted <- pair & !is.na(named) & named != "PYG" & named != denominator
  if (any(contradicted)) insert_quality_flag(
    con, release_id, "warning", "unit_currency_contradicts_label", NA_character_,
    paste0(
      sum(contradicted), " series declare a currency pair whose denominator is not the currency ",
      "their own column header names. A worksheet unit is inherited by every column on the sheet, ",
      "so one heterogeneous table mislabels all of it: ",
      paste(utils::head(paste0(
        series$source_sheet[contradicted], " / ", series$label[contradicted],
        " declared ", series$unit_code[contradicted], ", header names ", named[contradicted]
      ), 10), collapse = "; ")
    )
  )

  # And the reverse defect: a column the publisher describes as an index,
  # carrying a unit that measures a price.
  indexed <- pair & (grepl(UNIT_INDEX_LABEL_PATTERN, title) | grepl(UNIT_INDEX_LABEL_PATTERN, label))
  if (any(indexed)) insert_quality_flag(
    con, release_id, "warning", "unit_family_contradicts_index_wording", NA_character_,
    paste0(
      sum(indexed), " series declare a currency pair while the published table title or column ",
      "header describes an index number. An index has a base, not a denominator, and filtering ",
      "by the currency-pair unit returns both index points and real quotations as though they ",
      "were the same measure: ",
      paste(utils::head(paste0(
        series$source_sheet[indexed], " / ", series$label[indexed],
        " (", series$unit_code[indexed], ")"
      ), 10), collapse = "; ")
    )
  )
  invisible(!any(contradicted) && !any(indexed))
}

# The audit's R6-01, and the second time this lint has been rebuilt.
#
# Version one named two objects and matched the mart family; the audit found
# thirty-four published views with no release join at all. Version two replaced
# the list with naming rules -- v_latest_*, v_*_latest*, everything in marts --
# and the audit found the deeper problem: a rule over *names* cannot decide which
# objects are research interfaces, and a test for the *word* "releases" cannot
# decide whether one filters.
#
# Both halves failed concretely. `v_series_observations` reads the whole fact
# table and LEFT JOINs accepted releases only to label a column, so a row
# belonging to no accepted release survives with a null label -- and the body
# contains the word, so the lint passed it, and passed `v_series_projections`
# built on it, and `v_canonical_observations` built on that. Meanwhile
# `v_fx_operations_annual` and `v_series_catalogue` matched no naming rule at
# all, and neither did thirty-five other public objects.
#
# So neither question is inferred any more. What an object is *for* is declared
# by a person in config/public_view_contract.csv; whether it filters is decided
# by descent to a relation that actually restricts, not by a substring.
PUBLIC_VIEW_SCOPES <- c("current", "all", "history", "reference", "diagnostic")

# Which objects carry the release boundary in their own body is declared in the
# same register, not hard-coded here. A `current` object must either carry it or
# read something that does.
#
# Declaring it is a reviewed act with a name against it, and forgetting to
# declare a new filtering view makes the lint *fail* rather than pass -- the
# object's dependants stop descending to anything. That is the property the two
# previous versions of this lint lacked: a list you forget to extend used to mean
# an unchecked view, and now it means a blocked release.
# A declared boundary carrier, of which there are now two kinds.
#
# `current` carriers restrict to the one-row active pointer: "what is published
# now". `history` carriers restrict to every accepted product: "what could have
# been seen then". They are different populations and a view that took the wrong
# one would be wrong in a way no row count reveals -- which is the re-audit's
# RA2-01, where the as-of macros descended from the current carrier and could
# therefore only ever return today's vintage.
filtered_base_relations <- function(contract, scope = "current") {
  if (is.null(contract) || !"carries_release_boundary" %in% names(contract)) return(character())
  contract$object_id[
    isTRUE_vector(contract$carries_release_boundary) & contract$public_scope %in% scope
  ]
}

isTRUE_vector <- function(x) !is.na(x) & as.logical(x)

read_public_view_contract <- function(root) {
  if (is.null(root)) return(NULL)
  path <- file.path(root, "config", "public_view_contract.csv")
  if (!file.exists(path)) return(NULL)
  contract <- readr::read_csv(path, show_col_types = FALSE)
  required <- c("schema_name", "object_name", "object_type", "public_scope",
               "carries_release_boundary", "reason", "reviewed_by")
  missing_columns <- setdiff(required, names(contract))
  if (length(missing_columns)) stop(
    "config/public_view_contract.csv is missing: ", paste(missing_columns, collapse = ", "),
    call. = FALSE
  )
  bad_scope <- setdiff(unique(contract$public_scope), PUBLIC_VIEW_SCOPES)
  if (length(bad_scope)) stop(
    "config/public_view_contract.csv declares unknown public_scope value(s): ",
    paste(bad_scope, collapse = ", "), ". Allowed: ",
    paste(PUBLIC_VIEW_SCOPES, collapse = ", "), call. = FALSE
  )
  unreviewed <- contract$object_name[
    is.na(contract$reviewed_by) | !nzchar(trimws(contract$reviewed_by))
  ]
  if (length(unreviewed)) stop(
    "config/public_view_contract.csv leaves reviewed_by empty for: ",
    paste(head(unreviewed, 5), collapse = ", "),
    ". What an object is published for is a decision, and a decision has an author.",
    call. = FALSE
  )
  contract$object_id <- paste0(contract$schema_name, ".", contract$object_name)
  contract
}

# Does this object descend to a relation that actually restricts vintages?
#
# The predicate this replaces was `grepl("releases", body)`. It returned TRUE for
# a view whose only mention of releases was a LEFT JOIN populating a label, which
# is how an entirely unfiltered observation view -- and everything built on it --
# was certified as filtered. Mentioning the boundary is not respecting it.
#
# The rule now is descent: an object is filtered if it *is* a declared filtered
# base relation, or if it reads one. Reaching a base relation only through its
# `_all` twin does not count, which is what the twins are for.
release_filtered_object <- function(name, stored, carriers, seen = character()) {
  if (name %in% carriers) return(TRUE)
  if (name %in% seen) return(FALSE)
  body <- stored$body[stored$object_name == name]
  if (!length(body)) return(FALSE)
  # DuckDB quotes a same-schema qualifier when it serializes a stored view or
  # macro (for example `"catalog".series`). Normalize those harmless quotes so
  # the dependency walk compares canonical `schema.object` identifiers.
  body <- gsub('"', "", body[[1]], fixed = TRUE)
  dependencies <- setdiff(
    stored$object_name[vapply(
      stored$object_name, function(candidate) grepl(candidate, body, fixed = TRUE), logical(1)
    )],
    name
  )
  # A name that is a strict prefix of another matches the longer one's SQL, so
  # `v_series_latest` looks like a dependency of anything reading
  # `v_series_latest_all`. Descending through the `_all` twin would then certify
  # the diagnostic path as filtered, so twins are never followed.
  dependencies <- grep("_all$", dependencies, value = TRUE, invert = TRUE)
  any(vapply(
    dependencies,
    function(dependency) release_filtered_object(dependency, stored, carriers, c(seen, name)),
    logical(1)
  ))
}

# Every declared filtered base relation must earn the name: its own body has to
# restrict vintages to the active data release. Without this the descent test
# would be circular -- a list of relations asserted to filter, and a rule that
# trusts the list.
validate_filtered_base_relations <- function(con, release_id, stored, carriers,
                                             history_carriers = character()) {
  failures <- character()
  for (name in carriers) {
    body <- stored$body[stored$object_name == name]
    if (!length(body)) next
    restricts <- grepl("active_data_release", body[[1]], fixed = TRUE)
    if (!restricts) failures <- c(failures, name)
  }
  # A history carrier has to restrict to accepted *products* and must not
  # restrict to the active pointer. Both halves matter: without the first it
  # would publish blocked builds, and without the second it would be the current
  # carrier under another name -- which is precisely the state RA2-01 found, an
  # as-of interface that could only return what is published today.
  history_failures <- character()
  for (name in history_carriers) {
    body <- stored$body[stored$object_name == name]
    if (!length(body)) next
    admits_history <- grepl("data_releases", body[[1]], fixed = TRUE)
    narrows_to_active <- grepl("active_data_release", body[[1]], fixed = TRUE)
    if (!admits_history || narrows_to_active) history_failures <- c(history_failures, name)
  }
  if (!length(failures) && !length(history_failures)) return(invisible(TRUE))
  if (length(failures)) insert_quality_flag(
    con, release_id, "error", "filtered_base_relation_unrestricted", NA_character_,
    paste0(
      length(failures), " relation(s) declared as filtered bases do not restrict vintages to the ",
      "active data release, so every current view descending from them is unfiltered: ",
      paste(failures, collapse = ", ")
    )
  )
  if (length(history_failures)) insert_quality_flag(
    con, release_id, "error", "history_base_relation_unrestricted", NA_character_,
    paste0(
      length(history_failures), " relation(s) declared as history bases do not restrict vintages ",
      "to accepted data releases, or narrow them to the active pointer -- either way the as-of ",
      "interface cannot see a superseded vintage: ", paste(history_failures, collapse = ", ")
    )
  )
  invisible(FALSE)
}

validate_published_release_filter <- function(con, release_id, root = NULL) {
  if (!database_object_exists(con, "releases")) return(invisible(FALSE))
  stored <- rbind(
    DBI::dbGetQuery(con, paste(
      "SELECT schema_name || '.' || view_name AS object_name, sql AS body",
      "FROM duckdb_views() WHERE NOT internal"
    )),
    DBI::dbGetQuery(con, paste(
      "SELECT schema_name || '.' || function_name AS object_name, macro_definition AS body",
      "FROM duckdb_functions() WHERE NOT internal AND macro_definition IS NOT NULL"
    ))
  )
  contract <- read_public_view_contract(root)
  carriers <- filtered_base_relations(contract, "current")
  history_carriers <- filtered_base_relations(contract, "history")
  validate_filtered_base_relations(con, release_id, stored, carriers, history_carriers)
  problems <- character()
  history_required <- character()
  if (is.null(contract)) {
    problems <- c(problems, "config/public_view_contract.csv is missing, so no object declares what it publishes")
    required <- character()
  } else {
    published <- grep("^(main|marts|research|catalog|explore)\\.", stored$object_name, value = TRUE)
    # An object nobody has classified is the failure this register exists to
    # catch: a view added without anyone saying whether researchers should read
    # it. Undeclared is not the same as diagnostic, and must not default to it.
    undeclared <- setdiff(published, contract$object_id)
    if (length(undeclared)) problems <- c(problems, paste0(
      length(undeclared), " published object(s) declare no public_scope in ",
      "config/public_view_contract.csv: ", paste(head(sort(undeclared), 8), collapse = ", ")
    ))
    stale <- setdiff(contract$object_id, stored$object_name)
    if (length(stale)) problems <- c(problems, paste0(
      length(stale), " object(s) in config/public_view_contract.csv no longer exist: ",
      paste(head(sort(stale), 8), collapse = ", ")
    ))
    required <- contract$object_id[contract$public_scope == "current"]
    required <- intersect(required, stored$object_name)
    history_required <- contract$object_id[contract$public_scope == "history"]
    history_required <- intersect(history_required, stored$object_name)
  }
  # A history object must descend from a history carrier. Descending from the
  # current one instead is the RA2-01 defect exactly: the object looks filtered,
  # passes every other rule, and answers a question about the past using only the
  # present.
  unhistoried <- history_required[!vapply(
    history_required,
    function(name) release_filtered_object(name, stored, history_carriers), logical(1)
  )]
  if (length(unhistoried)) problems <- c(problems, paste0(
    length(unhistoried), " object(s) declared `history` do not descend from a relation carrying ",
    "the accepted-product boundary, so they cannot see a superseded vintage: ",
    paste(sort(unhistoried), collapse = ", ")
  ))
  unfiltered <- required[!vapply(
    required, function(name) release_filtered_object(name, stored, carriers), logical(1)
  )]
  if (length(unfiltered)) problems <- c(problems, paste0(
    length(unfiltered), " object(s) declared `current` do not descend from a filtered base ",
    "relation: ", paste(sort(unfiltered), collapse = ", ")
  ))
  visible_blocked <- DBI::dbGetQuery(con, paste0(
    "SELECT count(*) AS n FROM main.v_series_latest l WHERE l.vintage_id NOT IN (",
    accepted_release_vintages_sql(), ")"
  ))$n[[1]]
  if (visible_blocked) problems <- c(problems, paste(
    visible_blocked, "observation(s) are visible through v_series_latest whose vintage belongs to",
    "no accepted release"
  ))
  if (!length(problems)) return(invisible(TRUE))
  insert_quality_flag(
    con, release_id, "error", "blocked_release_visible", NA_character_,
    paste0(
      "The published interface does not isolate accepted releases: ",
      paste(problems, collapse = "; ")
    )
  )
  invisible(FALSE)
}

# A second connection to the same file inherits none of this session's settings,
# so its search path is empty -- which is precisely the condition to test under.
verify_fresh_connection_interface <- function(con, release_id, db_path) {
  if (is.null(db_path) || !nzchar(db_path) || !file.exists(db_path)) return(invisible(FALSE))
  # Never open a second connection while this one holds a transaction.
  #
  # A second connection to a DuckDB file whose writer has an open transaction does
  # not fail -- it waits, and a release that waits forever tells the operator
  # nothing at all. A hang is the worst failure mode there is, because there is no
  # message to read and no line to look at.
  #
  # Reaching here with a transaction open is itself a defect, so it is reported as
  # one rather than worked around. Diagnosis beats deadlock.
  if (project_transaction_open(con)) {
    insert_quality_flag(
      con, release_id, "error", "release_transaction_left_open", NA_character_,
      paste(
        "A transaction was still open on the pipeline's connection when the fresh-connection",
        "interface check was reached. The check is skipped rather than run, because a second",
        "connection to a DuckDB file with an open writer waits rather than failing, and the",
        "release would hang with nothing to diagnose. Find the phase that opened a transaction",
        "and did not close it."
      )
    )
    return(invisible(FALSE))
  }
  fresh <- try(DBI::dbConnect(duckdb::duckdb(), db_path), silent = TRUE)
  if (inherits(fresh, "try-error")) return(invisible(FALSE))
  on.exit(try(DBI::dbDisconnect(fresh, shutdown = FALSE), silent = TRUE), add = TRUE)
  configured <- DBI::dbGetQuery(fresh, "SELECT current_setting('search_path') AS s")$s[[1]]
  failures <- character()
  if (nzchar(trimws(configured))) failures <- c(failures, paste0(
    "the test connection carried a search path (", configured, ") and proves nothing"
  ))
  views <- DBI::dbGetQuery(fresh, paste(
    "SELECT schema_name, view_name FROM duckdb_views() WHERE NOT internal",
    "ORDER BY schema_name, view_name"
  ))
  for (i in seq_len(nrow(views))) {
    object <- paste0(views$schema_name[[i]], ".", views$view_name[[i]])
    # LIMIT 0 binds the whole query; COUNT(*) makes it run. A view can pass the
    # first and fail the second on a dependency only reached at execution.
    for (form in c("SELECT * FROM %s LIMIT 0", "SELECT count(*) FROM %s")) {
      outcome <- try(DBI::dbGetQuery(fresh, sprintf(
        form, paste0("\"", views$schema_name[[i]], "\".\"", views$view_name[[i]], "\"")
      )), silent = TRUE)
      if (inherits(outcome, "try-error")) {
        failures <- c(failures, paste0(object, ": ", trimws(gsub("\\s+", " ", conditionMessage(attr(outcome, "condition"))))))
        break
      }
    }
  }
  # The macros are called with literals rather than a column, because the whole
  # point of the resolver's lookup_id naming is that a bare column argument would
  # substitute into the body. A literal is what a caller actually writes.
  macro_calls <- c(
    resolve_series_id = "SELECT resolve_series_id('smoke:not-a-series') AS resolved",
    resolve_series_ids = "SELECT * FROM resolve_series_ids('smoke:not-a-series')",
    series_as_of_date = "SELECT count(*) AS n FROM series_as_of_date(DATE '1900-01-01')"
  )
  for (macro in names(macro_calls)) {
    outcome <- try(DBI::dbGetQuery(fresh, macro_calls[[macro]]), silent = TRUE)
    if (inherits(outcome, "try-error")) failures <- c(failures, paste0(
      macro, "(): ", trimws(gsub("\\s+", " ", conditionMessage(attr(outcome, "condition"))))
    ))
  }
  if (!length(failures)) return(invisible(TRUE))
  insert_quality_flag(
    con, release_id, "error", "fresh_connection_object_failed", NA_character_,
    paste0(
      length(failures), " of ", nrow(views) + length(macro_calls),
      " published object(s) fail from a connection with default settings, which is every ",
      "connection this project does not open itself: ", paste(head(failures, 8), collapse = " | ")
    )
  )
  invisible(FALSE)
}

# --- Numbers written into prose -----------------------------------------------
# The audit's P1: the financial_indicators status note still said "1,636
# positional-lane series" for a source whose live count is zero, months after the
# repair that removed them. validate_governance_drift() did not catch it and was
# right not to: it polices the closed-vocabulary parser_claim and deliberately
# never pattern-matches the note, because a check that guesses at prose fires on
# notes that mention a defect in order to deny it.
#
# The fix keeps that principle and narrows the target. A *number* followed by one
# of the phrases this project actually uses to make a quantitative claim is not
# prose, it is an assertion with a live counterpart, and it is checked against it.
# Everything else in the note stays free text and stays unread. Adding a phrase
# here is how a new kind of claim becomes checkable.
GOVERNANCE_NOTE_CLAIMS <- list(
  unread_cells = list(
    pattern = "([0-9][0-9,.]*)\\s+published source cell",
    describe = "unread published source cells"
  ),
  positional_lanes = list(
    pattern = "([0-9][0-9,.]*)\\s+positional[- ]lane series",
    describe = "positional-lane series identities"
  )
)

governance_note_claimed_number <- function(note, pattern) {
  match <- stringr::str_match(note, pattern)
  if (is.na(match[, 1])) return(NA_real_)
  suppressWarnings(as.numeric(gsub("[,.]", "", match[, 2])))
}

validate_governance_note_counts <- function(con, release_id) {
  if (!database_object_exists(con, "table_status")) return(invisible(FALSE))
  status <- DBI::dbGetQuery(con, paste(
    "SELECT source_id, source_sheet, note FROM", project_qualified_name("table_status"),
    "WHERE note IS NOT NULL AND note <> ''"
  ))
  if (!nrow(status)) return(invisible(TRUE))
  defects <- if (database_object_exists(con, "table_reconciliation") &&
                 "parser_defect_cells" %in% table_column_names(con, "table_reconciliation")) {
    DBI::dbGetQuery(con, paste(
      "SELECT source_id, source_sheet, sum(parser_defect_cells) AS cells",
      "FROM", project_qualified_name("table_reconciliation"), "GROUP BY 1, 2"
    ))
  } else NULL
  lanes <- if (database_object_exists(con, "dim_series")) {
    DBI::dbGetQuery(con, paste(
      "SELECT d.source_id, coalesce(n.source_sheet, '*') AS source_sheet, count(*) AS lanes",
      "FROM", project_qualified_name("dim_series"), "d",
      "LEFT JOIN (SELECT DISTINCT series_id, source_sheet FROM",
      project_qualified_name("documented_series_snapshot"), ") n USING (series_id)",
      "WHERE d.identity_stability = 'positional_lane' GROUP BY 1, 2"
    ))
  } else NULL
  # A worksheet row speaks for its worksheet; a '*' row speaks for the source, so
  # its number is the source total.
  live_total <- function(frame, column, source_id, source_sheet) {
    if (is.null(frame) || !nrow(frame)) return(0)
    rows <- frame[frame$source_id == source_id, , drop = FALSE]
    if (!identical(source_sheet, "*")) rows <- rows[rows$source_sheet == source_sheet, , drop = FALSE]
    sum(as.numeric(rows[[column]]), na.rm = TRUE)
  }
  stale <- character()
  for (i in seq_len(nrow(status))) {
    for (claim in names(GOVERNANCE_NOTE_CLAIMS)) {
      rule <- GOVERNANCE_NOTE_CLAIMS[[claim]]
      claimed <- governance_note_claimed_number(status$note[[i]], rule$pattern)
      if (is.na(claimed)) next
      actual <- if (identical(claim, "unread_cells")) {
        live_total(defects, "cells", status$source_id[[i]], status$source_sheet[[i]])
      } else {
        live_total(lanes, "lanes", status$source_id[[i]], status$source_sheet[[i]])
      }
      if (!isTRUE(all.equal(claimed, actual))) stale <- c(stale, paste0(
        status$source_id[[i]], " / ", status$source_sheet[[i]], ": the note claims ",
        format(claimed, big.mark = ",", scientific = FALSE), " ", rule$describe,
        "; this release measures ", format(actual, big.mark = ",", scientific = FALSE)
      ))
    }
  }
  if (!length(stale)) return(invisible(TRUE))
  insert_quality_flag(
    con, release_id, "error", "governance_note_stale_count", NA_character_,
    paste0(
      length(stale), " table_status note(s) state a number this release contradicts. ",
      "Correct config/table_status.csv: ", paste(head(stale, 6), collapse = " | ")
    )
  )
  invisible(FALSE)
}

# --- Measure against unit -----------------------------------------------------
# The audit's P1: 456 rate/spread-labelled series carry non-rate unit codes, so
# "automated transformations can silently be nonsensical". Nothing checked this;
# the existing unit guards test internal consistency within a vintage and the
# plausibility of a scale, never whether the unit agrees with what the series is.
#
# The check runs off the derived measure dimension rather than off the label,
# because the label is what was ambiguous in the first place. A rate must carry a
# rate-compatible unit; an outstanding amount must carry a currency; a count must
# be counted.
SEMANTIC_MEASURE_UNITS <- list(
  rate = c("PERCENT", "PERCENT_PER_ANNUM", "BASIS_POINTS", "PROPORTION", "RATIO"),
  outstanding_amount = c("PYG", "USD", "EUR", "UNRESOLVED_SOURCE_UNITS"),
  new_business_volume = c("PYG", "USD", "EUR", "UNRESOLVED_SOURCE_UNITS"),
  transaction_count = c("COUNT"),
  index_or_statistic = c("INDEX", "INDEX_POINTS", "PROPORTION", "RATIO")
)

validate_semantic_contradictions <- function(con, release_id) {
  if (!database_object_exists(con, "series_dimension")) return(invisible(FALSE))
  if (!database_object_exists(con, "dim_series")) return(invisible(FALSE))
  measured <- DBI::dbGetQuery(con, paste(
    "SELECT x.value AS measure, d.unit_code, count(*) AS series,",
    "min(d.series_id) AS example",
    "FROM", project_qualified_name("series_dimension"), "x",
    "JOIN", project_qualified_name("dim_series"), "d USING (series_id)",
    "WHERE x.dimension = 'measure' GROUP BY 1, 2"
  ))
  if (!nrow(measured)) return(invisible(TRUE))
  offending <- character(); total <- 0L
  for (i in seq_len(nrow(measured))) {
    allowed <- SEMANTIC_MEASURE_UNITS[[measured$measure[[i]]]]
    if (is.null(allowed)) next
    unit <- measured$unit_code[[i]]
    if (!is.na(unit) && unit %in% allowed) next
    total <- total + measured$series[[i]]
    offending <- c(offending, paste0(
      measured$measure[[i]], " with unit ", if (is.na(unit)) "NULL" else unit, ": ",
      measured$series[[i]], " series (e.g. ", measured$example[[i]], ")"
    ))
  }
  if (!length(offending)) return(invisible(TRUE))
  insert_quality_flag(
    con, release_id, "error", "semantic_contradiction", NA_character_,
    paste0(
      total, " series carry a unit their derived measure contradicts, so an automated ",
      "transformation over them would be meaningless: ", paste(head(offending, 8), collapse = " | ")
    )
  )
  invisible(FALSE)
}

# The audit's P1 test: "every nonempty numeric source block is inside a reviewed
# parser region or explicitly out of scope". Reported rather than gated -- see
# write_source_region_report() for why -- but reported every release, so the
# number cannot quietly grow while every worksheet reads "balanced".
validate_source_region_completeness <- function(con, release_id) {
  if (!database_object_exists(con, "source_region_classification")) return(invisible(FALSE))
  outside <- DBI::dbGetQuery(con, paste(
    "SELECT source_id, source_sheet, classification, count(*) AS cells FROM",
    project_qualified_name("source_region_classification"), "GROUP BY 1, 2, 3"
  ))
  if (!nrow(outside)) return(invisible(TRUE))
  # Unreviewed is a worklist, not a release failure: nobody classifies tens of
  # thousands of cells in one sitting, and a gate nobody can pass is a gate that
  # gets switched off. It does stop promotion to validated --
  # unreconciled_table_families() enforces that -- which is where an unexamined
  # region would become a correctness claim.
  unreviewed <- outside[outside$classification == "unreviewed", , drop = FALSE]
  if (nrow(unreviewed)) insert_quality_flag(
    con, release_id, "warning", "source_region_unreviewed", NA_character_,
    paste0(
      format(sum(unreviewed$cells), big.mark = ","), " published numeric cell(s) across ",
      nrow(unreviewed), " worksheet(s) sit outside every parser region and have no rule in ",
      "config/source_region_rules.csv saying what they are, so no worksheet they touch can be ",
      "promoted to validated. See outputs/source_region_review_worklist.csv. Largest: ",
      paste(utils::head(paste0(
        unreviewed$source_id, "/", unreviewed$source_sheet, " (",
        format(unreviewed$cells, big.mark = ","), ")"
      ), 5), collapse = "; ")
    )
  )
  # A reviewer has looked at these and said they are published data the parser
  # does not read. That is the honest answer and it is reported at every release
  # until the parser is repaired, exactly as a recorded in-region defect is.
  unread <- outside[outside$classification %in% SOURCE_REGION_DEFECT_CLASSIFICATIONS, , drop = FALSE]
  if (nrow(unread)) insert_quality_flag(
    con, release_id, "warning", "source_region_data_not_ingested", NA_character_,
    paste0(
      format(sum(unread$cells), big.mark = ","), " published numeric cell(s) across ", nrow(unread),
      " worksheet(s) are reviewed as data that no parser region reaches. Those worksheets cannot ",
      "reach v_research_series: ",
      paste(utils::head(paste0(
        unread$source_id, "/", unread$source_sheet, " (", format(unread$cells, big.mark = ","), ")"
      ), 10), collapse = "; ")
    )
  )
  invisible(TRUE)
}

# The audit's P1 test: "status notes and parser claims must match current
# reconciliation and parser version". Checked in both directions, because the two
# failures are different and only one of them is the one that already happened.
validate_governance_drift <- function(con, release_id) {
  if (!database_object_exists(con, "table_status") ||
      !database_object_exists(con, "table_reconciliation")) return(invisible(FALSE))
  if (!"parser_defect_cells" %in% table_column_names(con, "table_reconciliation")) {
    return(invisible(FALSE))
  }
  if (!"parser_claim" %in% table_column_names(con, "table_status")) return(invisible(FALSE))

  # A claim is checked at the scope it was written at. A worksheet row speaks
  # for that worksheet; a '*' row speaks for the source, so it claims that
  # *somewhere* in the source the parser misreads something, and is stale only
  # when no worksheet of that source does. Checking a source-level claim against
  # each worksheet separately would flag every clean sheet in a source that has
  # one bad one, which is noise, not drift.
  # A '*' row speaks only for the worksheets that have no row of their own.
  # Without that, naming one bad sheet explicitly would leave the source-level
  # row contradicting itself: it would still be measured against the sheet it
  # just delegated.
  claims <- DBI::dbGetQuery(con, paste(
    "WITH scope AS (",
    "  SELECT t.source_id, t.source_sheet, t.parser_claim,",
    "    CASE WHEN t.source_sheet = '*' THEN 1 ELSE 0 END AS is_wildcard",
    "  FROM table_status t WHERE t.parser_claim IS NOT NULL",
    "), delegated AS (",
    "  SELECT source_id, source_sheet FROM scope WHERE is_wildcard = 0",
    "), in_scope AS (",
    "  SELECT s.source_id, s.source_sheet AS claim_sheet, s.parser_claim, s.is_wildcard,",
    "         r.cell_reuse, r.unclassified_cells, r.parser_defect_cells, r.unmapped_in_region",
    "  FROM scope s",
    "  JOIN table_reconciliation r ON r.source_id = s.source_id",
    "  LEFT JOIN delegated d ON d.source_id = r.source_id AND d.source_sheet = r.source_sheet",
    "  WHERE r.source_sheet = s.source_sheet",
    "     OR (s.is_wildcard = 1 AND d.source_sheet IS NULL)",
    ")",
    "SELECT source_id, claim_sheet AS source_sheet, parser_claim, is_wildcard,",
    "  count(*) AS worksheets, sum(cell_reuse) AS cell_reuse,",
    "  sum(unclassified_cells) AS unclassified_cells,",
    "  sum(parser_defect_cells) AS parser_defect_cells,",
    "  sum(unmapped_in_region) AS unmapped_in_region",
    "FROM in_scope GROUP BY 1, 2, 3, 4"
  ))
  # A source or worksheet this release did not measure cannot contradict
  # anything; say nothing about it rather than guessing.
  claims <- claims[claims$worksheets > 0, , drop = FALSE]
  if (!nrow(claims)) return(invisible(FALSE))

  # Direction one: the row still claims a defect this release's accounting says
  # is gone. This is the failure the audit found -- eight trade notes describing
  # a period-axis bug that schema 14 had already fixed.
  stale <- claims[
    (claims$parser_claim == "unread_cells" & claims$unmapped_in_region == 0) |
      (claims$parser_claim == "cell_reuse" & claims$cell_reuse == 0), , drop = FALSE
  ]
  if (nrow(stale)) insert_quality_flag(
    con, release_id, "error", "table_status_claim_stale", NA_character_,
    paste0(
      nrow(stale), " table_status row(s) claim a parser defect that this release's reconciliation ",
      "reports as resolved. Correct parser_claim in config/table_status.csv: ",
      paste(head(paste0(stale$source_id, "/", stale$source_sheet,
                        " (claims ", stale$parser_claim, ")"), 10), collapse = "; ")
    )
  )

  # Direction two: the accounting reports a live defect and the row claims the
  # parser reads the worksheet completely.
  silent <- claims[
    claims$parser_claim == "none" &
      (claims$parser_defect_cells > 0 | claims$unclassified_cells > 0 | claims$cell_reuse > 0),
    , drop = FALSE
  ]
  if (nrow(silent)) insert_quality_flag(
    con, release_id, "error", "table_status_claim_silent_on_defect", NA_character_,
    paste0(
      nrow(silent), " table_status row(s) claim the parser reads their worksheets completely ",
      "while the reconciliation reports unread, unclassified or reused source cells: ",
      paste(head(paste0(silent$source_id, "/", silent$source_sheet), 10), collapse = "; ")
    )
  )
  invisible(TRUE)
}

validate_database <- function(con, manifest, release_id, root, db_path = NULL,
                              attempt_id = NULL) {
  required <- c("source_files", "source_sheets", "report_sheet_versions", "report_sheet_vintages",
                "report_cell_values", "report_cells", "dim_series", "fact_series_events",
                "quality_flags", "dim_entity", "dim_currency", "dim_statement_item",
                "dim_ratio", "dim_portfolio_item", "dim_credit_activity", "dim_credit_sector",
                "documented_table_catalog", "documented_series_snapshot", "dim_payment_participant",
                "dim_exchange_item", "documented_sheet_drift", "documented_series_continuity",
                "dim_concept", "map_series_concept", "bond_curve_snapshot", "securities_transactions_snapshot",
                "table_status", "series_id_migration", "source_alias", "continuity_map",
                "table_reconciliation", "v_series_id_resolution")
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
  # The audit's P2 test: the documented migration paths and the schema version
  # must be checked against the registry, not maintained beside it. Three
  # statements about the same migrations had already drifted apart in
  # OPERATIONS.md before anyone noticed.
  if (!is.null(root) && database_object_exists(con, "schema_version")) {
    runbook <- file.path(root, "docs", "SCHEMA_MIGRATIONS.md")
    current <- DBI::dbGetQuery(con, "SELECT max(version) AS n FROM schema_version")$n[[1]]
    stale <- if (!file.exists(runbook)) {
      "docs/SCHEMA_MIGRATIONS.md has not been generated"
    } else {
      lines <- readLines(runbook, warn = FALSE)
      text <- paste(lines, collapse = "\n")
      documented <- as.integer(sub("^\\|\\s*([0-9]+)\\s*\\|.*$", "\\1", grep(
        "^\\|\\s*[0-9]+\\s*\\|", lines, value = TRUE
      )))
      missing <- setdiff(
        DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version, documented
      )
      if (!grepl(paste0("schema ", current, "\\*\\*"), text)) {
        paste0("docs/SCHEMA_MIGRATIONS.md does not name schema ", current)
      } else if (length(missing)) {
        paste0(
          "docs/SCHEMA_MIGRATIONS.md omits applied schema version(s) ",
          paste(missing, collapse = ", ")
        )
      } else NULL
    }
    if (!is.null(stale)) insert_quality_flag(
      con, release_id, "error", "migration_runbook_stale", NA_character_,
      paste0(stale, ". It is generated by write_migration_runbook() from SCHEMA_MIGRATIONS.")
    )
  }
  # Every table belongs to a storage layer. One that does not is not broken --
  # it stays in main and works -- but nobody has said what it is for, and the
  # layers exist precisely so that question has an answer.
  unassigned <- DBI::dbGetQuery(con, paste(
    "SELECT table_name FROM duckdb_tables()",
    "WHERE schema_name = 'main' AND NOT internal ORDER BY table_name"
  ))$table_name
  if (length(unassigned)) insert_quality_flag(
    con, release_id, "warning", "storage_layer_unassigned", NA_character_,
    paste0(
      length(unassigned), " table(s) are not assigned to a storage layer and remain in main. ",
      "Add them to PROJECT_TABLE_SCHEMA: ", paste(head(unassigned, 10), collapse = "; ")
    )
  )
  validate_governance_drift(con, release_id)
  validate_governance_note_counts(con, release_id)
  validate_semantic_contradictions(con, release_id)
  validate_source_region_completeness(con, release_id)
  validate_published_identities(con, release_id, root)
  validate_source_provenance(con, release_id, root)
  validate_availability_quality(con, release_id)
  if (exists("validate_platform_contracts", mode = "function")) {
    validate_platform_contracts(con, release_id, root)
  }
  validate_archive_integrity(con, release_id, root)
  validate_series_review_register(con, release_id, root)
  validate_unit_overrides(con, release_id, root)
  validate_unit_family_plausibility(con, release_id)
  validate_temporal_contract(con, release_id, root)
  validate_series_hierarchy_acyclic(con, release_id)
  validate_build_reproducibility(con, release_id, root)
  validate_expected_grid_growth(con, release_id, attempt_id)
  validate_observation_missingness(con, release_id)
  validate_declared_natural_keys(con, release_id, root)
  validate_observation_status_exposure(con, release_id)
  validate_research_eligibility_metadata(con, release_id)
  validate_workbook_behaviour(con, release_id, root)
  validate_canonical_membership_agreement(con, release_id)
  validate_direct_panel_aggregation_safety(con, release_id)
  validate_coverage_dashboard(con, release_id, root)
  validate_row_rejection_accounting(con, release_id, root)
  # The published interface, checked before the release gate reads the flags.
  validate_stored_object_qualification(con, release_id)
  validate_active_data_release(con, release_id)
  validate_published_release_filter(con, release_id, root)
  verify_fresh_connection_interface(con, release_id, db_path)
  validate_release_gate(con, release_id)
  # The unfiltered twins: this report is about how completely the panels mapped
  # to the reference dimensions, which is an ingestion measure and must not go to
  # zero merely because the release under construction has not been accepted yet.
  view_names <- unlist(lapply(c("banks", "financial"), function(source_id) paste0(
    "v_", source_id, "_", c("eeff", "ratios", "carteras", "credito_sector", "credito_actividad"),
    "_documented_all"
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
  invisible(TRUE)
}

# The flag report, written by the pipeline *after* the statistical screens.
#
# It used to be written here, at the end of validation -- and the gap and
# discontinuity screens run after validation, so the file an auditor opens was
# missing exactly the two checks that had not been performed when it was written:
# 33 rows in the CSV against 35 in the database. The audit's R6-11. A report that
# does not describe the database it sits beside is worse than no report, because
# it is read as if it did.
write_quality_flag_report <- function(con, release_id, root) {
  if (is.null(root)) return(invisible(NULL))
  flags <- DBI::dbGetQuery(con, paste0(
    "SELECT * FROM ", project_qualified_name("quality_flags"), " WHERE ",
    attempt_flags_predicate(con, release_id),
    " ORDER BY severity, source_id"
  ))
  readr::write_csv(flags, file.path(root, "outputs", "quality_flags_latest.csv"))
  invisible(flags)
}

# What a build was decided to be, and whether it is the one being published.
#
# The audit's F-01 changed what "this update" means. A build now runs in a
# candidate file that becomes the published database only if it is accepted, so a
# blocked run leaves outputs/ describing a database that is not the live one.
# That is the right trade -- an operator diagnosing a block needs the blocked
# build's reports, not the published build's -- but only if the report says so.
publication_state_lines <- function(con, build_id) {
  if (is.null(build_id) || is.na(build_id) || !database_object_exists(con, "data_releases")) {
    return(character())
  }
  decided <- DBI::dbGetQuery(con, paste0(
    "SELECT status FROM ", project_qualified_name("data_releases"),
    " WHERE data_release_id = ", sql_string(build_id)
  ))
  if (!nrow(decided)) return(character())
  pointer <- DBI::dbGetQuery(con, paste0(
    "SELECT data_release_id FROM ", project_qualified_name("active_data_release")
  ))
  published <- nrow(pointer) == 1L && identical(pointer$data_release_id[[1]], build_id)
  if (identical(decided$status[[1]], "accepted") && published) c(
    paste0("**Published.** This build (`", build_id, "`) was accepted and is the database at ",
           "`database/paraguay_macro_pilot.duckdb`. The build it replaced is retained under ",
           "`database/backups/paraguay_macro_pilot_pre_swap_*.duckdb`."),
    ""
  ) else c(
    paste0("**Not published.** This build (`", build_id, "`) was decided `",
           decided$status[[1]], "`, so it was never swapped into place. ",
           "`database/paraguay_macro_pilot.duckdb` is still the previously published build",
           if (nrow(pointer) == 1L) paste0(" (`", pointer$data_release_id[[1]], "`)") else "",
           " and is byte-for-byte unchanged. **The rest of this report describes the blocked ",
           "build, not the database you have**; it is retained under `database/candidates/` ",
           "so its `_all` interfaces can be inspected."),
    ""
  )
}

expected_grid_report_lines <- function(con, attempt_id = NULL) {
  profile <- expected_grid_profile(con, attempt_id)
  if (is.null(profile) || !profile$grid_rows) return("- No expected-observation grid.")
  c(
    if (is.na(profile$seconds)) "- **Seconds this attempt:** not measured (phase skipped, or not timed)"
    else sprintf("- **Seconds this attempt:** %.2f (budget %d)", profile$seconds,
                 EXPECTED_GRID_SECONDS_BUDGET),
    paste0("- Grid rows retained: ", format(profile$grid_rows, big.mark = ",", scientific = FALSE),
           " (budget ", format(EXPECTED_GRID_ROW_BUDGET, big.mark = ",", scientific = FALSE), ")"),
    paste0("- Retained source vintages: ", profile$retained_vintages,
           "; vintages contributing a grid: ", profile$grid_vintages),
    paste0("- Rows per contributing vintage: ",
           format(round(profile$rows_per_vintage), big.mark = ",", scientific = FALSE)),
    paste0("- The stored grid is what survives pruning: a period is kept only where it is an ",
           "observation or an explained absence. The phase builds a much larger intermediate ",
           "first — one row per regular series-period per vintage — so **the seconds, not the ",
           "retained rows, are the cost**, and both grow linearly in retained vintages.")
  )
}

write_update_report <- function(con, release_id, root, attempt_id = NULL, build_id = NULL) {
  sources <- DBI::dbGetQuery(con, paste0(
    "SELECT f.source_id, f.source_file, f.vintage_id, f.publication_date, f.publication_date_source, f.ingestion_status FROM source_files f JOIN release_sources r USING (vintage_id) WHERE r.release_id = ", sql_string(release_id), " ORDER BY f.source_id"
  ))
  coverage <- if (file.exists(file.path(root, "outputs", "semantic_coverage_latest.csv"))) readr::read_csv(file.path(root, "outputs", "semantic_coverage_latest.csv"), show_col_types = FALSE) else tibble()
  mapping_path <- file.path(root, "outputs", "documented_financial_coverage_latest.csv")
  mappings <- if (file.exists(mapping_path)) readr::read_csv(mapping_path, show_col_types = FALSE) else tibble()
  if (is.null(attempt_id)) attempt_id <- current_attempt_id(con, release_id)
  flag_predicate <- if (is.na(attempt_id)) paste0("release_id = ", sql_string(release_id))
                    else paste0("attempt_id = ", sql_string(attempt_id))
  flags <- DBI::dbGetQuery(con, paste0(
    "SELECT severity, source_id, check_name, detail FROM ",
    project_qualified_name("quality_flags"), " WHERE ",
    flag_predicate, " ORDER BY severity, source_id"
  ))
  # Scoped by attempt, not by release. A report headed "this update" was reading
  # every timing ever recorded for the bundle -- 488 rows across eight attempts
  # where the run it described had 55 -- so the same stage appeared repeatedly
  # with the durations of runs that were not this one. The audit's R6-11.
  # attempt_id is passed in, not looked up: this runs after
  # close_ingestion_attempt(), so the attempt is no longer the open one and a
  # lookup returns nothing -- which fell back to release_id and put 696 timing
  # rows from eight attempts into a report headed "this update", the same stage
  # appearing over and over.
  timings <- DBI::dbGetQuery(con, paste0(
    "SELECT source_id, stage, elapsed_seconds FROM ingestion_stage_timings WHERE ",
    if (is.na(attempt_id)) paste0("release_id = ", sql_string(release_id))
    else paste0("attempt_id = ", sql_string(attempt_id)),
    " ORDER BY source_id, stage"
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
    "# Paraguay macro database — update report", "",
    publication_state_lines(con, build_id),
    paste("Deterministic release:", release_id), "",
    if (is.null(build_id) || is.na(build_id)) character() else c(paste("Build:", build_id), ""),
    "## Source vintages", "", source_lines, "", "## Semantic coverage", "", coverage_lines, "",
    "## Documented financial mapping coverage", "", mapping_lines, "",
    "## Pipeline timings", "", timing_lines, "",
    # The four numbers that decide whether the dominant phase stays affordable,
    # in one place. Reported every run so the curve is readable from the
    # artifacts rather than by instrumenting a run after it has become a problem.
    "## Expected-grid cost", "", expected_grid_report_lines(con, attempt_id), "",
    "## Quality flags", "", flag_lines, "",
    "Documented-table sources are analytically queryable. Values whose workbook headers do not identify a unique unit remain explicitly marked as `source_units` pending review."
  )
  write_markdown_report(file.path(root, "outputs", "update_report.md"), lines)
}
