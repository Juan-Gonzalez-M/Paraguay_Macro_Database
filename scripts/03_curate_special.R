slug <- function(x) janitor::make_clean_names(normalize_label(x))

append_snapshot <- function(con, table_name, data, vintage_id) {
  if (table_has_vintage(con, table_name, vintage_id)) return(invisible(FALSE))
  if (DBI::dbExistsTable(con, table_name)) DBI::dbWriteTable(con, table_name, data, append = TRUE)
  else DBI::dbWriteTable(con, table_name, data, overwrite = TRUE)
  invisible(TRUE)
}

ensure_series_dimension <- function(con, series_meta) {
  defaults <- list(
    identity_basis = series_meta$series_id,
    identity_stability = rep("semantic", nrow(series_meta)),
    hierarchy_status = rep("not_applicable", nrow(series_meta)),
    # Only documented_source_parser() computes a real constant-price base year
    # today; every other series-dimension writer (icc, eve, fx_operations,
    # exchange-rate panels) gets NA here rather than being required to know
    # about a field that doesn't apply to them.
    price_base_year = rep(NA_character_, nrow(series_meta))
  )
  for (field in names(defaults)) if (!field %in% names(series_meta)) series_meta[[field]] <- defaults[[field]]
  expected <- c(
    "series_id", "source_id", "label", "unit", "scale", "frequency", "currency", "index_base",
    "hierarchy_level", "parent_series_id", "is_total", "identity_basis", "identity_stability",
    "hierarchy_status", "semantic_status", "first_vintage_id", "price_base_year"
  )
  missing <- setdiff(expected, names(series_meta))
  if (length(missing)) stop("Series-dimension contract missing field(s): ", paste(missing, collapse = ", "), call. = FALSE)
  series_meta <- series_meta %>% dplyr::select(dplyr::all_of(expected)) %>% distinct(series_id, .keep_all = TRUE)
  existing <- DBI::dbGetQuery(con, "SELECT series_id FROM dim_series")$series_id
  new <- series_meta %>% filter(!series_id %in% existing)
  if (nrow(new)) DBI::dbWriteTable(con, "dim_series", new, append = TRUE)
  if (exists("sync_source_specific_concepts", mode = "function")) sync_source_specific_concepts(con)
}

write_sparse_series <- function(con, observations, series_meta, item, publication_date) {
  ensure_series_dimension(con, series_meta)
  existing_vintage <- DBI::dbGetQuery(con, paste0(
    "SELECT COUNT(*) AS n FROM fact_series_events WHERE vintage_id = ", sql_string(item$vintage_id)
  ))$n[[1]]
  if (existing_vintage) return(invisible(0L))
  observations <- observations %>%
    transmute(series_id, period = as.Date(period), value = as.numeric(value)) %>%
    filter(!is.na(period), !is.na(value)) %>% distinct(series_id, period, .keep_all = TRUE)
  historical_ids <- DBI::dbGetQuery(con, paste0(
    "SELECT series_id FROM dim_series WHERE source_id = ", sql_string(item$source_id)
  ))$series_id
  ids <- union(unique(series_meta$series_id), historical_ids)
  previous <- tibble(series_id = character(), period = as.Date(character()), previous_value = double(), previous_vintage_id = character())
  if (length(ids)) {
    id_sql <- paste(vapply(ids, sql_string, character(1)), collapse = ",")
    previous <- DBI::dbGetQuery(con, paste0(
      "SELECT series_id, period, value AS previous_value, vintage_id AS previous_vintage_id FROM v_series_latest WHERE series_id IN (", id_sql, ")"
    )) %>% mutate(period = as.Date(period))
  }
  compared <- observations %>% left_join(previous, by = c("series_id", "period")) %>%
    mutate(changed = is.na(previous_vintage_id) | is.na(previous_value) | abs(value - previous_value) > 1e-12)
  changed_events <- compared %>% filter(changed) %>% transmute(
    series_id, period, value, vintage_id = item$vintage_id,
    publication_date = as.Date(publication_date),
    value_hash = vapply(paste(series_id, period, format(value, digits = 17), sep = "|"), digest::digest, character(1), algo = "sha256", serialize = FALSE),
    is_deleted = FALSE, source_file = item$source_file
  )
  removed <- previous %>%
    anti_join(observations, by = c("series_id", "period")) %>%
    transmute(
      series_id, period, value = NA_real_, vintage_id = item$vintage_id,
      publication_date = as.Date(publication_date),
      value_hash = vapply(paste(series_id, period, "<deleted>", sep = "|"), digest::digest, character(1), algo = "sha256", serialize = FALSE),
      is_deleted = TRUE, source_file = item$source_file
    )
  events <- bind_rows(changed_events, removed)
  if (nrow(events)) DBI::dbWriteTable(con, "fact_series_events", events, append = TRUE)
  changed_revisions <- compared %>% filter(changed, !is.na(previous_vintage_id)) %>% transmute(
    revision_id = vapply(paste(series_id, period, previous_vintage_id, item$vintage_id, sep = "|"), digest::digest, character(1), algo = "sha256", serialize = FALSE),
    series_id, period, previous_value, new_value = value, previous_vintage_id,
    new_vintage_id = item$vintage_id, publication_date = as.Date(publication_date),
    absolute_revision = abs(value - previous_value)
  )
  removal_revisions <- removed %>% left_join(previous, by = c("series_id", "period")) %>% transmute(
    revision_id = vapply(paste(series_id, period, previous_vintage_id, item$vintage_id, "deleted", sep = "|"), digest::digest, character(1), algo = "sha256", serialize = FALSE),
    series_id, period, previous_value, new_value = NA_real_, previous_vintage_id,
    new_vintage_id = item$vintage_id, publication_date = as.Date(publication_date),
    absolute_revision = NA_real_
  )
  revisions <- bind_rows(changed_revisions, removal_revisions)
  if (nrow(revisions)) DBI::dbWriteTable(con, "series_revisions", revisions, append = TRUE)
  create_series_views(con)
  nrow(events)
}

icc_parser <- function(con, item, dimensions, release_id, root, publication_date) {
  spec <- read_parser_spec(root, "icc")
  dims <- dimensions %>% filter(sheet_name == spec$sheet)
  if (nrow(dims) != 1L) stop("Structure guard: ICC sheet not found exactly once: ", spec$sheet, call. = FALSE)
  raw <- read_dimensioned_sheet(item$path, dims)
  anchor <- find_anchor_cell(raw, spec$anchor, spec$anchor_search_rows, spec$anchor_search_cols)
  metric_row <- anchor[["row"]] + spec$metric_row_offset
  first_metric_col <- anchor[["col"]] + 1L
  labels <- cell_character(extract_row_cells(raw, metric_row, first_metric_col:ncol(raw)))
  labels <- labels[!is.na(labels) & nzchar(trimws(labels))]
  check <- assert_same_structure(unlist(spec$expected_metrics), labels, "icc", spec$sheet, "metric_headers")
  record_structure_check(con, check, item$vintage_id, release_id)
  data_start <- anchor[["row"]] + spec$data_row_offset
  dates <- as_excel_date(raw[[anchor[["col"]]]][data_start:nrow(raw)])
  assert_plausible_dates(dates, "icc", spec$sheet)
  records <- lapply(seq_along(labels), function(j) {
    values <- as_number_or_na(raw[[first_metric_col + j - 1L]][data_start:nrow(raw)])
    tibble(
      vintage_id = item$vintage_id, release_id = release_id, publication_date = as.Date(publication_date),
      date = dates, metric = labels[[j]], value = values,
      source_file = item$source_file, source_sheet = spec$sheet,
      series_id = paste("icc", slug(labels[[j]]), sep = ":")
    ) %>% filter(!is.na(date), !is.na(value))
  })
  snapshot <- bind_rows(records)
  if (is.na(publication_date) && nrow(snapshot)) {
    publication_date <- max(snapshot$date)
    snapshot$publication_date <- publication_date
    set_source_publication_date(con, item$vintage_id, publication_date)
    update_archive_manifest_date(root, item$source_id, item$sha256, publication_date)
  }
  append_snapshot(con, "consumer_confidence_snapshot", snapshot, item$vintage_id)
  meta <- snapshot %>% distinct(series_id, metric) %>% transmute(
    series_id, source_id = "icc", label = metric, unit = spec$unit, scale = "units", frequency = spec$frequency,
    currency = NA_character_, index_base = NA_character_, hierarchy_level = "indicator",
    parent_series_id = NA_character_, is_total = FALSE, semantic_status = "curated",
    first_vintage_id = item$vintage_id
  )
  events <- write_sparse_series(con, snapshot %>% transmute(series_id, period = date, value), meta, item, publication_date)
  list(curated_rows = nrow(snapshot), event_rows = events, publication_date = publication_date, source_sheet = spec$sheet)
}

eve_unit <- function(block) {
  b <- normalize_label(block)
  if (str_detect(b, "tipo de cambio")) "pyg_per_usd"
  else if (str_detect(b, "pib")) "percent_change"
  else if (str_detect(b, "politica monetaria")) "percent"
  else "proportion"
}

eve_parser <- function(con, item, dimensions, release_id, root, publication_date) {
  spec <- read_parser_spec(root, "eve")
  dims <- dimensions %>% filter(sheet_name == spec$sheet)
  if (nrow(dims) != 1L) stop("Structure guard: EVE sheet not found exactly once: ", spec$sheet, call. = FALSE)
  raw <- read_dimensioned_sheet(item$path, dims)
  anchor <- find_anchor_cell(raw, spec$anchor, spec$anchor_search_rows, spec$anchor_search_cols)
  date_row <- anchor[["row"]] + spec$date_row_offset
  first_value_col <- anchor[["col"]] + spec$value_column_offset
  dates <- as_excel_date(extract_row_cells(raw, date_row, first_value_col:ncol(raw)))
  assert_plausible_dates(dates, "eve", spec$sheet)
  block <- NA_character_; records <- list(); layout <- character(); discarded <- list(); k <- 0L; d <- 0L
  expected_blocks <- unlist(spec$expected_blocks)
  for (r in (anchor[["row"]] + spec$data_row_offset):nrow(raw)) {
    label <- cell_character(raw[[anchor[["col"]]]][r])[[1]]
    if (is.na(label) || !nzchar(trimws(label))) next
    vals <- as_number_or_na(extract_row_cells(raw, r, first_value_col:ncol(raw)))
    if (normalize_label(label) %in% normalize_label(expected_blocks)) {
      block <- expected_blocks[[match(normalize_label(label), normalize_label(expected_blocks))]]
      layout <- c(layout, paste0("B:", block))
      next
    }
    if (all(is.na(vals))) {
      d <- d + 1L
      discarded[[d]] <- tibble(row_id = r, reason = "non_data_note", raw_label = label)
      next
    }
    if (is.na(block)) stop("Structure guard: EVE data row found before a recognized block at row ", r, call. = FALSE)
    layout <- c(layout, paste0("V:", label))
    keep <- !is.na(dates) & !is.na(vals)
    if (!any(keep)) next
    k <- k + 1L
    # Slug the scalars BEFORE tibble(). Inside tibble(), `block = block` creates
    # a column named `block`, and a later argument resolves `block` to that
    # recycled column, not to the loop scalar. slug() then uniquifies the
    # repeated values by position (bloque_de_inflacion, _2, ... _245), giving one
    # series_id per observation: 16 indicators became 2,760 one-observation series.
    block_slug <- slug(block); label_slug <- slug(label)
    records[[k]] <- tibble(
      vintage_id = item$vintage_id, release_id = release_id, publication_date = as.Date(publication_date),
      date = dates[keep], block = block, variable = label, value = vals[keep],
      source_file = item$source_file, source_sheet = spec$sheet,
      series_id = paste("eve", block_slug, label_slug, sep = ":")
    )
  }
  check <- assert_same_structure(unlist(spec$expected_layout), layout, "eve", spec$sheet, "block_variable_layout")
  record_structure_check(con, check, item$vintage_id, release_id)
  snapshot <- bind_rows(records)
  if (n_distinct(paste(snapshot$block, snapshot$variable)) != spec$expected_variable_count) {
    stop("Structure guard: EVE variable count differs from specification.", call. = FALSE)
  }
  if (is.na(publication_date) && nrow(snapshot)) {
    publication_date <- max(snapshot$date)
    snapshot$publication_date <- publication_date
    set_source_publication_date(con, item$vintage_id, publication_date)
    update_archive_manifest_date(root, item$source_id, item$sha256, publication_date)
  }
  append_snapshot(con, "eve_expectations_snapshot", snapshot, item$vintage_id)
  if (length(discarded)) {
    discarded_df <- bind_rows(discarded) %>% mutate(
      discard_id = vapply(paste(item$vintage_id, spec$sheet, row_id, reason, sep = "|"), digest::digest, character(1), algo = "sha256", serialize = FALSE),
      release_id = release_id, vintage_id = item$vintage_id, source_id = "eve", source_sheet = spec$sheet, .before = 1
    )
    DBI::dbWriteTable(con, "discarded_rows", discarded_df, append = TRUE)
  }
  meta <- snapshot %>% distinct(series_id, block, variable) %>% rowwise() %>% transmute(
    series_id, source_id = "eve", label = paste(block, variable, sep = " — "), unit = eve_unit(block), scale = "units",
    frequency = spec$frequency, currency = ifelse(str_detect(normalize_label(block), "tipo de cambio"), "PYG/USD", NA_character_),
    index_base = NA_character_, hierarchy_level = "expectation_horizon", parent_series_id = NA_character_,
    is_total = FALSE, semantic_status = "curated", first_vintage_id = item$vintage_id
  ) %>% ungroup()
  events <- write_sparse_series(con, snapshot %>% transmute(series_id, period = date, value), meta, item, publication_date)
  list(curated_rows = nrow(snapshot), event_rows = events, publication_date = publication_date, source_sheet = spec$sheet)
}

quarter_end <- function(year, quarter) month_end(year, quarter * 3L)

fx_parser <- function(con, item, dimensions, release_id, root, publication_date) {
  spec <- read_parser_spec(root, "fx_operations")
  dims <- dimensions %>% filter(sheet_name == spec$sheet)
  if (nrow(dims) != 1L) stop("Structure guard: FX sheet not found exactly once: ", spec$sheet, call. = FALSE)
  raw <- read_dimensioned_sheet(item$path, dims)
  anchor <- find_anchor_cell(raw, spec$anchor, spec$anchor_search_rows, spec$anchor_search_cols)
  header_row <- anchor[["row"]]
  observed_sectors <- cell_character(extract_row_cells(raw, header_row, anchor[["col"]]:(anchor[["col"]] + 10L)))
  observed_sectors <- observed_sectors[!is.na(observed_sectors) & nzchar(trimws(observed_sectors))]
  sector_check <- assert_same_structure(unlist(spec$expected_sector_headers), observed_sectors, "fx_operations", spec$sheet, "sector_headers")
  sub_row <- header_row + spec$subheader_row_offset
  observed_sub <- cell_character(extract_row_cells(raw, sub_row, (anchor[["col"]] + 1L):(anchor[["col"]] + 9L)))
  sub_check <- assert_same_structure(unlist(spec$expected_subheaders), observed_sub, "fx_operations", spec$sheet, "operation_headers")
  record_structure_check(con, bind_rows(sector_check, sub_check), item$vintage_id, release_id)
  mapping <- tibble(
    column_id = (anchor[["col"]] + 1L):(anchor[["col"]] + 10L),
    sector = c(rep("financial_sector", 3), rep("public_sector", 3), rep("other_operations", 3), "total"),
    operation = c("purchase", "sale", "net", "purchase", "sale", "net", "purchase", "sale", "net", "net")
  )
  start <- header_row + spec$data_row_offset
  current_year <- NA_integer_; rows <- list(); discarded <- list(); k <- 0L; d <- 0L
  month_map <- unlist(spec$month_labels)
  for (r in start:nrow(raw)) {
    label <- str_squish(cell_character(raw[[anchor[["col"]]]][r])[[1]])
    if (is.na(label) || !nzchar(label)) next
    numeric_values <- as_number_or_na(extract_row_cells(raw, r, mapping$column_id))
    is_year <- grepl("^[12][0-9]{3}$", label)
    is_quarter <- grepl("^T[1-4]$", toupper(label))
    is_month <- label %in% names(month_map)
    if (is_year) {
      current_year <- as.integer(label); frequency <- "annual"; period <- month_end(current_year, 12L); is_total <- TRUE; level <- "year"
    } else if (is_quarter && !is.na(current_year)) {
      q <- as.integer(sub("T", "", toupper(label))); frequency <- "quarterly"; period <- quarter_end(current_year, q); is_total <- TRUE; level <- "quarter"
    } else if (is_month && !is.na(current_year)) {
      frequency <- "monthly"; period <- month_end(current_year, month_map[[label]]); is_total <- FALSE; level <- "month"
    } else {
      d <- d + 1L
      discarded[[d]] <- tibble(row_id = r, reason = if (any(!is.na(numeric_values))) "unrecognized_period_with_values" else "non_data_note", raw_label = label)
      next
    }
    for (j in seq_len(nrow(mapping))) {
      if (is.na(numeric_values[[j]])) next
      k <- k + 1L
      parent_frequency <- if (frequency == "monthly") "quarterly" else if (frequency == "quarterly") "annual" else NA_character_
      rows[[k]] <- tibble(
        vintage_id = item$vintage_id, release_id = release_id, publication_date = as.Date(publication_date),
        period = as.Date(period), period_label = label, year = current_year, frequency = frequency,
        hierarchy_level = level, is_total = is_total, sector = mapping$sector[[j]], operation = mapping$operation[[j]],
        value = numeric_values[[j]], unit = "USD", scale = "millions",
        source_file = item$source_file, source_sheet = spec$sheet,
        series_id = paste("fx_operations", mapping$sector[[j]], mapping$operation[[j]], frequency, sep = ":"),
        parent_series_id = if (is.na(parent_frequency)) NA_character_ else paste("fx_operations", mapping$sector[[j]], mapping$operation[[j]], parent_frequency, sep = ":")
      )
    }
  }
  snapshot <- bind_rows(rows)
  if (nrow(snapshot)) assert_plausible_dates(snapshot$period, "fx_operations", spec$sheet)
  if (is.na(publication_date) && nrow(snapshot)) {
    monthly_periods <- snapshot$period[snapshot$frequency == "monthly"]
    publication_date <- if (length(monthly_periods)) max(monthly_periods) else max(snapshot$period)
    snapshot$publication_date <- publication_date
    set_source_publication_date(con, item$vintage_id, publication_date)
    update_archive_manifest_date(root, item$source_id, item$sha256, publication_date)
  }
  append_snapshot(con, "fx_operations_snapshot", snapshot, item$vintage_id)
  if (length(discarded)) {
    discarded_df <- bind_rows(discarded) %>% mutate(
      discard_id = vapply(paste(item$vintage_id, spec$sheet, row_id, reason, sep = "|"), digest::digest, character(1), algo = "sha256", serialize = FALSE),
      release_id = release_id, vintage_id = item$vintage_id, source_id = "fx_operations", source_sheet = spec$sheet, .before = 1
    )
    DBI::dbWriteTable(con, "discarded_rows", discarded_df, append = TRUE)
    risky <- discarded_df %>% filter(reason == "unrecognized_period_with_values")
    if (nrow(risky)) stop("FX parser found unrecognized period rows containing values; see discarded_rows.", call. = FALSE)
  }
  DBI::dbExecute(con, "CREATE OR REPLACE VIEW v_fx_operations_annual AS SELECT * FROM fx_operations_snapshot WHERE frequency = 'annual'")
  meta <- snapshot %>% distinct(series_id, sector, operation, frequency, hierarchy_level, parent_series_id, is_total) %>% transmute(
    series_id, source_id = "fx_operations", label = paste(sector, operation, frequency, sep = " — "),
    unit = "USD", scale = "millions", frequency, currency = "USD", index_base = NA_character_, hierarchy_level,
    parent_series_id, is_total, semantic_status = "curated", first_vintage_id = item$vintage_id
  )
  events <- write_sparse_series(con, snapshot %>% transmute(series_id, period, value), meta, item, publication_date)
  list(curated_rows = nrow(snapshot), event_rows = events, publication_date = publication_date, source_sheet = spec$sheet)
}

ingest_curated_source <- function(con, item, dimensions, release_id, root, publication_date) {
  switch(item$ingest_mode,
         icc = icc_parser(con, item, dimensions, release_id, root, publication_date),
         eve = eve_parser(con, item, dimensions, release_id, root, publication_date),
         fx_operations = fx_parser(con, item, dimensions, release_id, root, publication_date),
         semantic_table = documented_source_parser(con, item, dimensions, release_id, root, publication_date),
         long_csv = long_csv_parser(con, item, dimensions, release_id, root, publication_date),
         reference = ingest_reference_workbook(con, item, dimensions, release_id, root, publication_date),
         list(curated_rows = 0L, event_rows = 0L, publication_date = publication_date, source_sheet = NA_character_))
}

infer_credit_survey_publication_date <- function(item, dimensions) {
  dims <- dimensions %>% filter(sheet_name == "Índices")
  if (nrow(dims) != 1L) return(as.Date(NA))
  raw <- read_dimensioned_sheet(item$path, dims, max_rows = 12L)
  quarter_counts <- vapply(seq_len(nrow(raw)), function(r) {
    as.integer(sum(str_detect(normalize_label(cell_character(extract_row_cells(raw, r))), "trim"), na.rm = TRUE))
  }, integer(1))
  quarter_row <- which(quarter_counts >= 2L)
  if (length(quarter_row) != 1L || quarter_row[[1]] == 1L) return(as.Date(NA))
  year_row <- quarter_row[[1]] - 1L
  years <- suppressWarnings(as.integer(as_number_or_na(extract_row_cells(raw, year_row))))
  for (j in seq_along(years)) if (is.na(years[[j]]) && j > 1L) years[[j]] <- years[[j - 1L]]
  quarters <- suppressWarnings(as.integer(str_extract(cell_character(extract_row_cells(raw, quarter_row[[1]])), "[1-4]")))
  valid <- which(!is.na(years) & !is.na(quarters))
  if (!length(valid)) return(as.Date(NA))
  j <- tail(valid, 1)
  quarter_end(years[[j]], quarters[[j]])
}
