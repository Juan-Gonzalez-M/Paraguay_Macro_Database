documented_parse_insurance_sheet <- function(raw, source_sheet, hierarchy_status = "unresolved") {
  text <- documented_text_matrix(raw); numbers <- documented_number_matrix(raw)
  normalized <- matrix(normalize_semantic_label(text), nrow = nrow(text), ncol = ncol(text))
  anchors <- which(normalized == "ejercicio", arr.ind = TRUE)
  fiscal_pattern <- "^((?:19|20)[0-9]{2})[-/]((?:19|20)[0-9]{2})$"
  if (nrow(anchors) > 1L) stop("Insurance-annex guard: multiple Ejercicio headers in ", source_sheet, ".", call. = FALSE)
  if (nrow(anchors) == 1L) {
    header_row <- anchors[[1, "row"]]; period_col <- anchors[[1, "col"]]
  } else {
    fiscal_mask <- matrix(stringr::str_detect(trimws(text), fiscal_pattern), nrow = nrow(text), ncol = ncol(text))
    scores <- colSums(fiscal_mask, na.rm = TRUE); candidates <- which(scores == max(scores) & scores >= 3L)
    if (length(candidates) != 1L) stop(
      "Insurance-annex guard: Ejercicio is absent and no unique fiscal-year column exists in ", source_sheet, ".",
      call. = FALSE
    )
    period_col <- candidates[[1]]; header_row <- min(which(fiscal_mask[, period_col])) - 1L
  }
  group_row <- max(1L, header_row - 2L)
  group_headers <- text[group_row, ]
  for (j in seq_len(ncol(text))) if (j > 1L && documented_blank(group_headers[[j]])) group_headers[[j]] <- group_headers[[j - 1L]]
  period_match <- stringr::str_match(trimws(text[, period_col]), fiscal_pattern)
  data_rows <- which(!is.na(period_match[, 1]) & seq_len(nrow(text)) > header_row)
  if (!length(data_rows)) stop("Insurance-annex guard: no fiscal-year rows in ", source_sheet, ".", call. = FALSE)
  title <- documented_compact_path(unique(group_headers[!documented_blank(group_headers)]))
  records <- list(); k <- 0L
  for (r in data_rows) {
    end_year <- as.integer(period_match[r, 3]); period <- as.Date(sprintf("%04d-06-30", end_year))
    for (j in seq.int(period_col + 1L, ncol(text))) {
      value <- numbers[r, j]; section <- text[header_row, j]
      if (is.na(value) || documented_blank(section)) next
      group <- group_headers[[j]]
      label <- documented_compact_path(c(group, section))
      k <- k + 1L
      records[[k]] <- documented_record(
        source_sheet, title, "insurance_fiscal_year", period,
        text[r, period_col], "annual", label, group, section, value, r, j
      )
    }
  }
  observations <- documented_bind_records(records)
  observations <- observations %>% dplyr::mutate(unit = "PYG", scale = "units", currency = "PYG")
  list(observations = observations, mode = "insurance_fiscal_year", hierarchy_status = hierarchy_status,
       raw_nonempty_cells = sum(!documented_blank(text)), title = title)
}

documented_local_block_title <- function(text, header_row, lookback = 12L) {
  if (header_row <= 1L) return(NA_character_)
  rows <- rev(seq.int(max(1L, header_row - as.integer(lookback)), header_row - 1L))
  fallback <- NA_character_
  for (r in rows) {
    candidates <- stringr::str_squish(text[r, ])
    candidates <- candidates[!documented_blank(candidates) & nchar(candidates) >= 6L]
    candidates <- candidates[!stringr::str_detect(
      normalize_semantic_label(candidates),
      "^(?:fecha|ano|plazo|monto|tasa|cantidad|compra|venta)(?: |$)"
    )]
    if (!length(candidates)) next
    candidate <- documented_compact_path(candidates)
    if (is.na(fallback)) fallback <- candidate
    # A single descriptive cell is much more likely to be the block title
    # than a multi-column group-header row immediately above the table.
    if (length(candidates) == 1L) return(candidate)
  }
  fallback
}

documented_parse_row_events <- function(raw, source_sheet, date_header,
                                        dimension_headers, category,
                                        block_patterns = NULL) {
  text <- documented_text_matrix(raw); numbers <- documented_number_matrix(raw)
  dates <- documented_date_matrix(raw, text)
  normalized <- matrix(normalize_semantic_label(text), nrow = nrow(text), ncol = ncol(text))
  anchors <- which(matrix_equal(normalized, normalize_semantic_label(date_header)), arr.ind = TRUE)
  if (!nrow(anchors)) stop(
    "Row-event guard: no '", date_header, "' header in ", source_sheet, ".", call. = FALSE
  )
  anchors <- anchors[order(anchors[, "row"], anchors[, "col"]), , drop = FALSE]
  records <- list(); k <- 0L; titles <- character()
  for (b in seq_len(nrow(anchors))) {
    header_row <- anchors[b, "row"]; date_col <- anchors[b, "col"]
    block_end <- if (b < nrow(anchors)) anchors[b + 1L, "row"] - 1L else nrow(text)
    rows <- seq.int(header_row + 1L, block_end)
    if (!length(rows)) next
    title <- documented_local_block_title(text, header_row)
    block_key <- NA_character_
    if (!is.null(block_patterns)) {
      if (is.null(names(block_patterns)) || any(!nzchar(names(block_patterns)))) stop(
        "Row-event guard: block_patterns must use stable semantic names.", call. = FALSE
      )
      normalized_title <- normalize_semantic_label(title)
      matches <- names(block_patterns)[vapply(block_patterns, function(pattern) {
        !is.na(normalized_title) && stringr::str_detect(normalized_title, pattern)
      }, logical(1))]
      if (length(matches) != 1L) stop(
        "Row-event guard: expected one block type in ", source_sheet, " near row ",
        header_row, "; found ", length(matches), ".", call. = FALSE
      )
      block_key <- matches[[1]]
    }
    header_labels <- text[header_row, ]
    normalized_headers <- normalize_semantic_label(header_labels)
    dimension_cols <- unique(unlist(lapply(dimension_headers, function(pattern) {
      which(stringr::str_detect(normalized_headers, pattern))
    })))
    if (!length(dimension_cols)) stop(
      "Row-event guard: semantic dimension headers were not found in ", source_sheet, ".",
      call. = FALSE
    )
    numeric_density <- colSums(!is.na(numbers[rows, , drop = FALSE]))
    date_density <- colSums(!is.na(dates[rows, , drop = FALSE]))
    measure_cols <- setdiff(
      which(numeric_density > 0L & date_density == 0L & seq_len(ncol(text)) != date_col),
      dimension_cols
    )
    if (!length(measure_cols)) next
    active_rows <- rows[rowSums(!is.na(numbers[rows, measure_cols, drop = FALSE])) > 0L]
    if (!length(active_rows)) next
    periods <- as.Date(as.numeric(dates[, date_col]), origin = "1970-01-01")
    for (r in seq.int(min(active_rows), max(active_rows))) {
      if (r > min(active_rows) && is.na(periods[r])) periods[r] <- periods[r - 1L]
    }
    active_rows <- active_rows[!is.na(periods[active_rows])]
    if (!length(active_rows)) next
    dimension_state <- rep(NA_character_, length(dimension_cols))
    dimension_paths <- character(length(active_rows))
    for (rr in seq_along(active_rows)) {
      r <- active_rows[[rr]]
      current <- text[r, dimension_cols]
      update <- !documented_blank(current)
      dimension_state[update] <- current[update]
      pieces <- paste0(header_labels[dimension_cols], ": ", dimension_state)
      dimension_paths[[rr]] <- documented_compact_path(c(
        if (!is.na(block_key)) paste0("operation_type: ", block_key) else character(),
        pieces[!documented_blank(dimension_state)]
      ))
    }
    base_keys <- paste(periods[active_rows], dimension_paths, sep = "|")
    duplicated_event <- duplicated(base_keys) | duplicated(base_keys, fromLast = TRUE)
    # Some published event tables legitimately contain multiple rows with the
    # same date and semantic dimensions. Values must never enter identity: a
    # revision to an amount or rate must remain a revision of the same event,
    # not create a new series. Use a deterministic within-key occurrence lane
    # and expose its positional nature through identity_stability.
    event_occurrence <- ave(seq_along(base_keys), base_keys, FUN = seq_along)
    titles <- c(titles, title)
    for (rr in seq_along(active_rows)) {
      r <- active_rows[[rr]]
      event_path <- dimension_paths[[rr]]
      parser_mode <- "row_event_semantic"
      if (duplicated_event[[rr]]) {
        event_path <- documented_compact_path(c(
          event_path, paste0("event_instance:", event_occurrence[[rr]])
        ))
        parser_mode <- "row_event_positional_lane"
      }
      for (j in measure_cols) {
        value <- numbers[r, j]
        if (is.na(value)) next
        measure <- documented_compact_path(header_labels[[j]])
        if (!nzchar(measure)) measure <- paste0("column_", j)
        label <- documented_compact_path(c(event_path, measure))
        k <- k + 1L
        records[[k]] <- documented_record(
          source_sheet, title, parser_mode, periods[r], as.character(periods[r]),
          "irregular_daily", label, category, measure, value, r, j
        )
      }
    }
  }
  observations <- documented_bind_records(records)
  list(
    observations = observations, mode = "row_event_table", hierarchy_status = "flat",
    raw_nonempty_cells = sum(!documented_blank(text)), title = documented_compact_path(unique(titles))
  )
}

# LRM auctions publish one auction-tenor event per row.  They look superficially
# like the generic row-event tables, but their rate columns have a two-level
# header: K:M are offered rates and N:P are assigned rates, while row 14 repeats
# Promedio/Minima/Maxima under both groups.  Reading row 14 alone loses the side
# and forces positional column tokens into identity.  Keep this source-specific
# contract here rather than weakening the generic parser.
documented_parse_lrm_auction_sheet <- function(raw, source_sheet, root = NULL) {
  text <- documented_text_matrix(raw)
  numbers <- documented_number_matrix(raw)
  dates <- documented_date_matrix(raw, text)
  normalized <- matrix(normalize_semantic_label(text), nrow = nrow(text), ncol = ncol(text))
  anchors <- which(matrix_equal(normalized, "fecha subasta"), arr.ind = TRUE)
  if (nrow(anchors) != 1L) stop(
    "LRM parser guard: expected exactly one 'Fecha subasta' header in ", source_sheet,
    "; found ", nrow(anchors), ".", call. = FALSE
  )
  header_row <- anchors[[1L, "row"]]
  if (anchors[[1L, "col"]] != 1L || header_row < 2L || ncol(text) != 16L) stop(
    "LRM parser guard: expected the two-level A:P header ending at 'Fecha subasta' in ",
    source_sheet, ".", call. = FALSE
  )
  lower_expected <- c(
    "fecha subasta", "fecha liquidacion", "fecha de vencimiento",
    "plazos estandarizados", "plazos residuales", "montos anunciados",
    "montos ofertados", "montos asignados", "ofertado #", "asignado #",
    "promedio", "minima", "maxima", "promedio", "minima", "maxima"
  )
  if (!identical(normalize_semantic_label(text[header_row, 1:16]), lower_expected)) stop(
    "LRM parser guard: lower header differs from the governed A:P contract in ",
    source_sheet, ".", call. = FALSE
  )
  upper <- normalize_semantic_label(text[header_row - 1L, ])
  upper_expected <- c(
    `1` = "fecha", `4` = "plazos (dias)", `6` = "montos (millones de guaranies)",
    `9` = "cantidad de posturas", `11` = "tasa de interes ofertada",
    `14` = "tasa de interes asignada"
  )
  if (!all(upper[as.integer(names(upper_expected))] == unname(upper_expected))) stop(
    "LRM parser guard: upper offered/assigned or unit header differs in ", source_sheet,
    ".", call. = FALSE
  )

  measure_contract <- tibble::tribble(
    ~source_column, ~measure, ~series_label, ~unit, ~scale, ~currency,
    6L,  "announced_amount",       "Monto anunciado",                         "PYG",          "millions", "PYG",
    7L,  "offered_amount",         "Monto ofertado",                          "PYG",          "millions", "PYG",
    8L,  "assigned_amount",        "Monto asignado",                          "PYG",          "millions", "PYG",
    9L,  "offered_bid_count",      "Cantidad de posturas ofertadas",          "count",        "units",    NA_character_,
    10L, "assigned_bid_count",     "Cantidad de posturas asignadas",          "count",        "units",    NA_character_,
    11L, "offered_average_rate",   "Tasa de interes ofertada - Promedio",     "percent_per_annum", "units", NA_character_,
    12L, "offered_minimum_rate",   "Tasa de interes ofertada - Minima",       "percent_per_annum", "units", NA_character_,
    13L, "offered_maximum_rate",   "Tasa de interes ofertada - Maxima",       "percent_per_annum", "units", NA_character_,
    14L, "assigned_average_rate",  "Tasa de interes asignada - Promedio",     "percent_per_annum", "units", NA_character_,
    15L, "assigned_minimum_rate",  "Tasa de interes asignada - Minima",       "percent_per_annum", "units", NA_character_,
    16L, "assigned_maximum_rate",  "Tasa de interes asignada - Maxima",       "percent_per_annum", "units", NA_character_
  )
  auction_dates <- as.Date(as.numeric(dates[, 1L]), origin = "1970-01-01")
  settlement_dates <- as.Date(as.numeric(dates[, 2L]), origin = "1970-01-01")
  maturity_dates <- as.Date(as.numeric(dates[, 3L]), origin = "1970-01-01")
  data_rows <- which(seq_len(nrow(text)) > header_row & !is.na(auction_dates) &
                       rowSums(!is.na(numbers[, 6:16, drop = FALSE])) > 0L)
  if (!length(data_rows)) stop("LRM parser guard: no auction rows in ", source_sheet, ".", call. = FALSE)
  incomplete_dimensions <- data_rows[
    is.na(settlement_dates[data_rows]) | is.na(maturity_dates[data_rows]) |
      is.na(numbers[data_rows, 4L]) | is.na(numbers[data_rows, 5L])
  ]
  if (length(incomplete_dimensions)) stop(
    "LRM event-key guard: incomplete date/tenor dimensions in ", source_sheet,
    " row(s) ", paste(incomplete_dimensions, collapse = ", "), ".", call. = FALSE
  )
  event_key <- paste(
    auction_dates[data_rows], settlement_dates[data_rows], maturity_dates[data_rows],
    format(numbers[data_rows, 4L], scientific = FALSE, trim = TRUE),
    format(numbers[data_rows, 5L], scientific = FALSE, trim = TRUE), sep = "|"
  )
  series_event_key <- paste(
    auction_dates[data_rows],
    format(numbers[data_rows, 4L], scientific = FALSE, trim = TRUE),
    format(numbers[data_rows, 5L], scientific = FALSE, trim = TRUE), sep = "|"
  )
  unresolved_key <- duplicated(event_key) | duplicated(event_key, fromLast = TRUE) |
    duplicated(series_event_key) | duplicated(series_event_key, fromLast = TRUE)
  event_instance <- ave(seq_along(series_event_key), series_event_key, FUN = seq_along)
  title <- documented_local_block_title(text, header_row - 1L)
  records <- vector("list", length(data_rows) * nrow(measure_contract)); k <- 0L
  for (ii in seq_along(data_rows)) {
    r <- data_rows[[ii]]
    event_path <- documented_compact_path(c(
      paste0("standardized_tenor_days: ", format(numbers[r, 4L], scientific = FALSE, trim = TRUE)),
      paste0("residual_tenor_days: ", format(numbers[r, 5L], scientific = FALSE, trim = TRUE))
    ))
    parser_mode <- "lrm_auction_event"
    if (unresolved_key[[ii]]) {
      # The workbook publishes no auction number capable of separating these
      # same-date, same-maturity rows.  Preserve them with an explicit unstable
      # storage lane so they remain catalogued and lineaged, but let the normal
      # identity/admission machinery withhold them from explore.*.
      event_path <- documented_compact_path(c(
        event_path, paste0("unresolved_event_instance: ", event_instance[[ii]])
      ))
      parser_mode <- "lrm_auction_event_unresolved_positional_lane"
    }
    for (m in seq_len(nrow(measure_contract))) {
      j <- measure_contract$source_column[[m]]
      value <- numbers[r, j]
      if (is.na(value)) next
      k <- k + 1L
      record <- documented_record(
        source_sheet, title, parser_mode, auction_dates[[r]],
        as.character(auction_dates[[r]]), "irregular_daily",
        measure_contract$series_label[[m]], event_path, measure_contract$measure[[m]],
        value, r, j,
        question = paste0("settlement_date: ", settlement_dates[[r]]),
        response = paste0("maturity_date: ", maturity_dates[[r]])
      )
      record$unit <- measure_contract$unit[[m]]
      record$scale <- measure_contract$scale[[m]]
      record$currency <- measure_contract$currency[[m]]
      records[[k]] <- record
    }
  }
  observations <- documented_bind_records(records[seq_len(k)])
  if (nrow(observations) != sum(!is.na(numbers[data_rows, 6:16, drop = FALSE]))) stop(
    "LRM source-cell reconciliation guard: not every numeric F:P cell emitted exactly once in ",
    source_sheet, ".", call. = FALSE
  )
  if (anyDuplicated(observations[c("source_row", "source_column")])) stop(
    "LRM source-cell reconciliation guard: a data cell emitted more than once in ",
    source_sheet, ".", call. = FALSE
  )
  component_observations <- observations
  consolidation_lineage <- tibble::tibble()
  if (!is.null(root)) {
    decision_path <- file.path(root, "config", "lrm_event_consolidations.csv")
    decisions <- readr::read_csv(decision_path, show_col_types = FALSE,
      col_types = readr::cols(.default = readr::col_character()))
    decisions <- decisions[decisions$source_sheet == source_sheet, , drop = FALSE]
    for (decision_row in seq_len(nrow(decisions))) {
      rows <- as.integer(strsplit(decisions$component_rows[[decision_row]], ";", fixed = TRUE)[[1]])
      components <- component_observations[component_observations$source_row %in% rows, , drop = FALSE]
      if (!length(rows) || !all(rows %in% components$source_row)) stop(
        "LRM consolidation guard: configured component rows are absent in ", source_sheet, ".", call. = FALSE)
      base_categories <- sub(" — unresolved_event_instance: [0-9]+$", "", components$category)
      keys <- unique(components[c("period", "question", "response")])
      if (nrow(keys) != 1L || length(unique(base_categories)) != 1L) stop(
        "LRM consolidation guard: component event dimensions differ.", call. = FALSE)
      base_category <- unique(base_categories)[[1]]
      made <- list()
      for (measure_row in seq_len(nrow(measure_contract))) {
        measure <- measure_contract$measure[[measure_row]]
        j <- measure_contract$source_column[[measure_row]]
        values <- components[components$measure == measure, , drop = FALSE]
        if (!nrow(values)) next
        value <- if (measure %in% c("announced_amount", "offered_amount", "assigned_amount",
                                   "offered_bid_count", "assigned_bid_count")) {
          sum(values$value)
        } else if (measure == "offered_average_rate") {
          amounts <- components[components$measure == "offered_amount", c("source_row", "value")]
          sum(values$value * amounts$value[match(values$source_row, amounts$source_row)]) / sum(amounts$value)
        } else if (measure == "assigned_average_rate") {
          amounts <- components[components$measure == "assigned_amount", c("source_row", "value")]
          weights <- amounts$value[match(values$source_row, amounts$source_row)]
          sum(values$value * weights) / sum(weights)
        } else if (grepl("minimum_rate$", measure)) min(values$value) else max(values$value)
        record <- values[1, , drop = FALSE]
        record$value <- value
        record$category <- base_category
        record$series_path <- documented_compact_path(c(base_category, record$series_label))
        record$parser_mode <- "lrm_auction_event_governed_consolidation"
        record$source_row <- NA_integer_
        record$source_column <- NA_integer_
        made[[length(made) + 1L]] <- record
        # Lineage names every component coordinate, including a structurally
        # blank assigned cell. The blank is evidence that the operation had no
        # assignment; omitting it would lose the component row from the governed
        # derivation even though it correctly contributes no numeric value.
        lineage_cells <- tibble::tibble(source_row = rows, source_column = j)
        if (measure == "offered_average_rate") lineage_cells <- dplyr::bind_rows(
          lineage_cells, tibble::tibble(source_row = rows, source_column = 7L))
        if (measure == "assigned_average_rate") lineage_cells <- dplyr::bind_rows(
          lineage_cells, tibble::tibble(source_row = rows, source_column = 8L))
        derivation_rule <- if (grepl("amount$|bid_count$", measure)) "sum" else if (
          grepl("average_rate$", measure)) "amount_weighted_average" else if (
          grepl("minimum_rate$", measure)) "minimum_available" else "maximum_available"
        consolidation_lineage <- dplyr::bind_rows(consolidation_lineage, tibble::tibble(
          source_sheet = source_sheet, period = keys$period[[1]], category = base_category,
          measure = .env$measure, source_row = lineage_cells$source_row,
          source_column = lineage_cells$source_column, component_rows = decisions$component_rows[[decision_row]],
          derivation_rule = .env$derivation_rule,
          evidence_basis = decisions$evidence_basis[[decision_row]], reviewed_by = decisions$reviewed_by[[decision_row]],
          reviewed_at = as.Date(decisions$reviewed_at[[decision_row]])
        ))
      }
      observations <- observations[!observations$source_row %in% rows, , drop = FALSE]
      observations <- dplyr::bind_rows(observations, dplyr::bind_rows(made))
    }
  }
  list(
    observations = observations, component_observations = component_observations,
    consolidation_lineage = consolidation_lineage,
    mode = "lrm_auction_event", hierarchy_status = "flat",
    raw_nonempty_cells = sum(!documented_blank(text)), title = title
  )
}

# The referential daily quotation workbook publishes one calendar grid per
# year and quote side: months across B:M, day numbers down A3:A33 and either a
# numeric quotation or the exact token ND in each data cell.  It is not one of
# the generic orientations because a period moves across both worksheet axes.
documented_validate_daily_calendar_grid_workbook <- function(dimensions) {
  expected_sheets <- as.vector(rbind(
    paste0(2012:2026, "_Compra"), paste0(2012:2026, "_Venta")
  ))
  if (!identical(dimensions$sheet_name, expected_sheets)) stop(
    "Daily calendar-grid workbook guard: expected the 30 ordered worksheets ",
    "2012_Compra, 2012_Venta, ..., 2026_Compra, 2026_Venta.", call. = FALSE
  )
  exact_range <- dimensions$used_rows == 33L & dimensions$used_cols == 13L &
    dimensions$content_first_row == 1L & dimensions$content_first_col == 1L &
    dimensions$content_last_row == 33L & dimensions$content_last_col == 13L
  if (any(!exact_range)) stop(
    "Daily calendar-grid workbook guard: every worksheet must occupy exactly A1:M33.",
    call. = FALSE
  )
  if (any(dimensions$merge_ranges != "A1:E1" | is.na(dimensions$merge_ranges))) stop(
    "Daily calendar-grid workbook guard: every worksheet must retain merge A1:E1.",
    call. = FALSE
  )
  if (any(dimensions$formula_cells != 0L | is.na(dimensions$formula_cells)) ||
      any(!is.na(dimensions$hidden_rows)) || any(!is.na(dimensions$hidden_columns))) stop(
    "Daily calendar-grid workbook guard: formulas or hidden rows/columns were introduced.",
    call. = FALSE
  )
  invisible(TRUE)
}

documented_parse_daily_calendar_grid <- function(raw, source_sheet) {
  text <- documented_text_matrix(raw)
  numbers <- documented_number_matrix(raw)
  if (nrow(text) != 33L || ncol(text) != 13L) stop(
    "Daily calendar-grid sheet guard: expected A1:M33 in ", source_sheet, ".",
    call. = FALSE
  )

  sheet_parts <- stringr::str_match(source_sheet, "^(20[0-9]{2})_(Compra|Venta)$")
  if (is.na(sheet_parts[1, 1])) stop(
    "Daily calendar-grid sheet guard: unsupported worksheet name ", source_sheet, ".",
    call. = FALSE
  )
  year <- as.integer(sheet_parts[1, 2])
  side <- sheet_parts[1, 3]
  if (!year %in% 2012:2026) stop(
    "Daily calendar-grid sheet guard: year outside the contracted workbook range in ",
    source_sheet, ".", call. = FALSE
  )

  title <- unname(text[1, 1])
  expected_title <- paste0(
    "PLANILLA DE COTIZACIONES DEL AÑO ", year,
    " - MERCADO LIBRE FLUCTUANTE - ", toupper(side)
  )
  if (source_sheet == "2021_Compra") {
    if (!identical(title, "}")) stop(
      "Daily calendar-grid title guard: 2021_Compra!A1 no longer contains the retained damaged title '}'.",
      call. = FALSE
    )
  } else if (!identical(title, expected_title)) stop(
    "Daily calendar-grid title guard: unexpected A1 in ", source_sheet, ".",
    call. = FALSE
  )

  expected_months <- c("ENE", "FEB", "MAR", "ABR", "MAY", "JUN",
                       "JUL", "AGO", "SEP", "OCT", "NOV", "DIC")
  if (!identical(unname(text[2, 1]), "#") || !identical(unname(text[2, 2:13]), expected_months)) stop(
    "Daily calendar-grid axis guard: A2 or B2:M2 changed in ", source_sheet, ".",
    call. = FALSE
  )
  if (!identical(as.integer(numbers[3:33, 1]), 1:31)) stop(
    "Daily calendar-grid axis guard: A3:A33 must contain numeric days 1 through 31 in ",
    source_sheet, ".", call. = FALSE
  )

  data_text <- text[3:33, 2:13, drop = FALSE]
  data_numbers <- numbers[3:33, 2:13, drop = FALSE]
  unsupported <- is.na(data_numbers) & data_text != "ND"
  unsupported[is.na(unsupported)] <- TRUE
  if (any(unsupported)) {
    position <- which(unsupported, arr.ind = TRUE)[1, ]
    source_row <- position[[1]] + 2L
    source_column <- position[[2]] + 1L
    stop(
      "Daily calendar-grid cell guard: expected a numeric value or exact ND at ",
      openxlsx::int2col(source_column), source_row, " in ", source_sheet, ".",
      call. = FALSE
    )
  }

  records <- list(); k <- 0L
  for (r in 3:33) for (j in 2:13) {
    day <- as.integer(numbers[r, 1])
    month <- j - 1L
    period <- as.Date(sprintf("%04d-%02d-%02d", year, month, day), format = "%Y-%m-%d")
    value <- numbers[r, j]
    if (is.na(period)) {
      if (!is.na(value)) stop(
        "Daily calendar-grid date guard: numeric value occupies invalid calendar cell ",
        openxlsx::int2col(j), r, " in ", source_sheet, ".", call. = FALSE
      )
      next
    }
    # Human source-owner review on 2026-09-19 confirmed that ND denotes a
    # weekend or holiday for which no quotation exists. Preserve the exact token
    # in raw evidence and emit no observation: it is neither zero nor a value to
    # interpolate.
    if (is.na(value)) next
    period_label <- paste(text[r, 1], text[2, j], year)
    k <- k + 1L
    records[[k]] <- documented_record(
      source_sheet, title, "daily_calendar_grid", period, period_label, "daily",
      side, "TCN REFERENCIAL DIARIO", side, value, r, j
    )
    records[[k]]$unit <- "PYG_per_USD"
    records[[k]]$scale <- "units"
    records[[k]]$currency <- "PYG/USD"
    records[[k]]$is_total <- FALSE
  }
  observations <- documented_bind_records(records)
  if (!nrow(observations)) stop(
    "Daily calendar-grid structure guard: no numeric observations in ", source_sheet, ".",
    call. = FALSE
  )
  list(
    observations = observations, mode = "daily_calendar_grid", hierarchy_status = "flat",
    raw_nonempty_cells = sum(!documented_blank(text)), title = title
  )
}

documented_parse_daily_exchange_rates <- function(raw, source_sheet, item) {
  text <- documented_text_matrix(raw); numbers <- documented_number_matrix(raw)
  normalized <- matrix(normalize_semantic_label(text), nrow = nrow(text), ncol = ncol(text))
  month_pattern <- "(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)[/ -](20[0-9]{2})"
  month_anchors <- which(matrix_detect(normalized, month_pattern), arr.ind = TRUE)
  if (!nrow(month_anchors)) stop("Exchange-rate guard: no month/year block title.", call. = FALSE)
  month_anchors <- month_anchors[order(month_anchors[, "row"], month_anchors[, "col"]), , drop = FALSE]
  currency_codes <- c(
    dolar = "USD", real = "BRL", `peso argentino` = "ARS", euro = "EUR", yen = "JPY",
    `peso uruguayo` = "UYU", `peso chileno` = "CLP", `peso boliviano` = "BOB",
    `franco suizo` = "CHF", `libra esterlina` = "GBP", `corona sueca` = "SEK",
    `corona danesa` = "DKK", `dolar canadiense` = "CAD", `dolar australiano` = "AUD"
  )
  records <- list(); k <- 0L
  for (b in seq_len(nrow(month_anchors))) {
    title_row <- month_anchors[b, "row"]; title_col <- month_anchors[b, "col"]
    block_end <- if (b < nrow(month_anchors)) month_anchors[b + 1L, "row"] - 1L else nrow(text)
    month_cell <- text[title_row, title_col]
    parts <- stringr::str_match(normalize_semantic_label(month_cell), month_pattern)
    month <- documented_month_number(parts[[2]]); year <- as.integer(parts[[3]])
    currency_row <- title_row + 2L; header_row <- title_row + 3L
    if (header_row > nrow(text)) stop("Exchange-rate guard: incomplete daily block.", call. = FALSE)
    currency_headers <- text[currency_row, ]
    for (j in seq_len(ncol(text))) if (j > 1L && documented_blank(currency_headers[[j]])) currency_headers[[j]] <- currency_headers[[j - 1L]]
    measure_cols <- which(normalized[header_row, ] %in% c("compra", "venta"))
    if (length(measure_cols) < 2L) stop("Exchange-rate guard: buy/sell headers not found in block ", b, ".", call. = FALSE)
    possible_rows <- seq.int(header_row + 1L, block_end)
    day_scores <- colSums(numbers[possible_rows, , drop = FALSE] >= 1 & numbers[possible_rows, , drop = FALSE] <= 31, na.rm = TRUE)
    day_col <- which.max(day_scores)
    day_values <- numbers[possible_rows, day_col]
    data_rows <- possible_rows[!is.na(day_values) & day_values >= 1 & day_values <= 31]
    for (r in data_rows) {
      day <- as.integer(numbers[r, day_col]); period <- suppressWarnings(as.Date(sprintf("%04d-%02d-%02d", year, month, day)))
      if (is.na(period)) next
      for (j in measure_cols) {
        measure <- normalize_semantic_label(text[header_row, j]); value <- numbers[r, j]
        if (is.na(value)) next
        currency_label <- currency_headers[[j]]; code <- unname(currency_codes[normalize_semantic_label(currency_label)])
        if (is.na(code)) next
        label <- documented_compact_path(c(currency_label, measure))
        k <- k + 1L
        records[[k]] <- documented_record(
          source_sheet, month_cell, "daily_exchange_rates", period,
          as.character(day), "daily", label, currency_label, measure, value, r, j
        )
        records[[k]]$unit <- paste0("PYG_per_", code); records[[k]]$scale <- "units"
        records[[k]]$currency <- paste0("PYG/", code)
      }
    }
  }
  observations <- documented_bind_records(records)
  list(observations = observations, mode = "daily_exchange_rates", hierarchy_status = "flat",
       raw_nonempty_cells = sum(!documented_blank(text)), title = documented_compact_path(unique(text[month_anchors])))
}

documented_parse_exchange_rate_history <- function(raw, source_sheet) {
  text <- documented_text_matrix(raw); numbers <- documented_number_matrix(raw)
  normalized <- matrix(normalize_semantic_label(text), nrow = nrow(text), ncol = ncol(text))
  currency_code <- dplyr::case_when(
    stringr::str_starts(normalize_semantic_label(source_sheet), "usd") ~ "USD",
    stringr::str_starts(normalize_semantic_label(source_sheet), "euro") ~ "EUR",
    stringr::str_starts(normalize_semantic_label(source_sheet), "real") ~ "BRL",
    stringr::str_starts(normalize_semantic_label(source_sheet), "peso") ~ "ARS",
    TRUE ~ NA_character_
  )
  if (is.na(currency_code)) stop("Exchange-rate history guard: unsupported currency sheet ", source_sheet, ".", call. = FALSE)
  records <- list(); k <- 0L
  years <- documented_year_values(text)
  title <- documented_table_title(text, seq_len(min(10L, nrow(text))))
  if (source_sheet == "USD Fin Mes") {
    year_col <- documented_year_axis_index(text, margin = 2L)
    if (is.na(year_col)) stop(
      "Exchange-rate annual guard: no coherent year column found in ", source_sheet, ".",
      call. = FALSE
    )
    data_rows <- which(!is.na(years[, year_col]))
    if (length(data_rows) < 3L) stop("Exchange-rate annual guard: insufficient year rows.", call. = FALSE)
    header_row <- min(data_rows) - 1L
    measure_cols <- which(normalized[header_row, ] %in% c("compra", "venta"))
    if (length(measure_cols) != 2L) stop("Exchange-rate annual guard: expected Compra and Venta.", call. = FALSE)
    for (r in data_rows) for (j in measure_cols) {
      value <- numbers[r, j]; if (is.na(value)) next
      measure <- text[header_row, j]
      k <- k + 1L
      records[[k]] <- documented_record(
        source_sheet, title, "exchange_rate_annual", as.Date(paste0(years[r, year_col], "-12-31")),
        text[r, year_col], "annual", documented_compact_path(c(currency_code, measure)), currency_code,
        measure, value, r, j
      )
    }
  } else {
    candidate_year_rows <- documented_consecutive_year_rows(text, minimum = 2L)
    valid_year_rows <- candidate_year_rows[vapply(candidate_year_rows, function(year_row) {
      measure_row <- year_row + 1L
      if (measure_row > nrow(text)) return(FALSE)
      year_cols <- which(!is.na(years[year_row, ]))
      if (length(year_cols) < 2L) return(FALSE)
      all(vapply(seq_along(year_cols), function(jj) {
        start_col <- year_cols[[jj]]
        end_col <- if (jj < length(year_cols)) year_cols[[jj + 1L]] - 1L else ncol(text)
        sum(normalized[measure_row, seq.int(start_col, end_col)] %in% c("compra", "venta")) == 2L
      }, logical(1)))
    }, logical(1))]
    if (!length(valid_year_rows)) stop(
      "Exchange-rate monthly guard: no consecutive year blocks with Compra/Venta headers.",
      call. = FALSE
    )
    month_values <- documented_month_number(text)
    for (bb in seq_along(valid_year_rows)) {
      year_row <- valid_year_rows[[bb]]
      measure_row <- year_row + 1L
      block_end <- if (bb < length(valid_year_rows)) valid_year_rows[[bb + 1L]] - 1L else nrow(text)
      block_rows <- seq.int(measure_row + 1L, block_end)
      month_scores <- colSums(!is.na(month_values[block_rows, , drop = FALSE]))
      month_col <- which.max(month_scores)
      month_rows <- block_rows[!is.na(month_values[block_rows, month_col])]
      if (!length(month_rows)) stop(
        "Exchange-rate monthly guard: no month rows under year block at row ", year_row, ".",
        call. = FALSE
      )
      year_cols <- which(!is.na(years[year_row, ]))
      for (jj in seq_along(year_cols)) {
        start_col <- year_cols[[jj]]
        end_col <- if (jj < length(year_cols)) year_cols[[jj + 1L]] - 1L else ncol(text)
        measure_cols <- seq.int(start_col, end_col)
        measure_cols <- measure_cols[normalized[measure_row, measure_cols] %in% c("compra", "venta")]
        for (r in month_rows) for (j in measure_cols) {
          value <- numbers[r, j]; if (is.na(value)) next
          month <- month_values[r, month_col]; measure <- text[measure_row, j]
          year <- years[year_row, start_col]
          k <- k + 1L
          records[[k]] <- documented_record(
            source_sheet, title, "exchange_rate_monthly",
            month_end(year, month), paste(year, text[r, month_col]),
            "monthly", documented_compact_path(c(currency_code, measure)), currency_code, measure, value, r, j
          )
        }
      }
    }
  }
  observations <- documented_bind_records(records)
  observations <- observations %>% dplyr::mutate(
    unit = paste0("PYG_per_", currency_code), scale = "units", currency = paste0("PYG/", currency_code)
  )
  mode <- if (nrow(observations)) unique(observations$parser_mode)[[1]] else "unparsed_exchange_rate_history"
  list(observations = observations, mode = mode, hierarchy_status = "flat",
       raw_nonempty_cells = sum(!documented_blank(text)), title = title)
}

documented_parse_compensatory_sales <- function(raw, source_sheet) {
  text <- documented_text_matrix(raw); numbers <- documented_number_matrix(raw)
  normalized <- matrix(normalize_semantic_label(text), nrow = nrow(text), ncol = ncol(text))
  year_hits <- which(matrix_detect(normalized, "^ano 20[0-9]{2}$"), arr.ind = TRUE)
  month_hits <- which(matrix_equal(normalized, "meses"), arr.ind = TRUE)
  if (!nrow(year_hits) || !nrow(month_hits)) stop("Compensatory-sales guard: year blocks or Meses headers not found.", call. = FALSE)
  records <- list(); k <- 0L
  for (b in seq_len(nrow(month_hits))) {
    month_row <- month_hits[b, "row"]; month_col <- month_hits[b, "col"]
    candidates <- year_hits[year_hits[, "col"] == month_col & year_hits[, "row"] < month_row, , drop = FALSE]
    if (!nrow(candidates)) next
    year_label <- text[max(candidates[, "row"]), month_col]
    year <- as.integer(stringr::str_extract(year_label, "20[0-9]{2}"))
    # The block is three columns wide: two components and their published total.
    # This used to test only the two components for activity while the reading
    # loop below consumed all three, so a month the publisher reported as a zero
    # total with both components left blank never became an active row and its
    # total was never visited. That silently dropped the five published zero
    # totals on Agosto-Diciembre 2025 -- reconciliation recorded them as a
    # parser_defect rather than as data. Deciding activity over the same columns
    # the loop reads is the whole fix.
    block_cols <- seq.int(month_col + 1L, min(ncol(text), month_col + 3L))
    component_cols <- if (length(block_cols) == 3L) block_cols[1:2] else block_cols
    total_cols <- setdiff(block_cols, component_cols)
    # Each year header owns exactly the rows up to the next year header in the
    # same column. Without this bound the block ran to the last numeric row of
    # the sheet, re-reading every later year block under this block's year: 474
    # rows for 139 months, with conflicting values in 92-114 months per measure.
    following_years <- year_hits[year_hits[, "col"] == month_col & year_hits[, "row"] > month_row, "row"]
    block_end <- if (length(following_years)) min(following_years) - 1L else nrow(text)
    if (block_end <= month_row) next
    possible_rows <- seq.int(month_row + 1L, block_end)
    active_rows <- possible_rows[rowSums(!is.na(numbers[possible_rows, block_cols, drop = FALSE])) > 0L]
    if (!length(active_rows)) next
    # The current-year block is a template for the whole calendar year, and the
    # months that have not happened yet are still in it: in the 2026 block both
    # component cells of Agosto to Diciembre are empty while the Total column
    # holds a cached zero from its own '=+G+H' formula. Reading those as
    # observations invented five monthly totals for months the publisher had not
    # reported, and -- because the vintage's publication date fell back to the
    # maximum period in the content -- moved the whole source's availability to
    # 2026-12-31 while source_files still said 2026-07-31. That is the audit's
    # F-01, and its 422 divergent facts.
    #
    # A trailing row is a template row when its components are blank *and* its
    # total is zero. Both halves matter. A published zero total sitting between
    # two reported months is still data and is still read, which is what the
    # schema-23 repair exists for; and a trailing month the publisher reports as
    # a single non-zero total is data too, and is also still read. Only the
    # empty-and-zero tail is dropped.
    template_tail <- rev(cumprod(rev(vapply(possible_rows, function(r) {
      components_blank <- all(is.na(numbers[r, component_cols]))
      totals <- numbers[r, total_cols]
      total_zero <- length(total_cols) > 0L && all(is.na(totals) | totals == 0)
      as.integer(components_blank && total_zero)
    }, integer(1))))) > 0L
    reported_rows <- setdiff(active_rows, possible_rows[template_tail])
    if (!length(reported_rows)) next
    last_active_row <- max(reported_rows)
    block_months <- documented_month_number(text[seq.int(month_row + 1L, last_active_row), month_col])
    if (sum(!is.na(block_months)) > 12L) stop(
      "Compensatory-sales guard: year block ", year, " spans ", sum(!is.na(block_months)),
      " month rows; a calendar year cannot exceed 12.", call. = FALSE
    )
    for (r in seq.int(month_row + 1L, last_active_row)) {
      month <- documented_month_number(text[r, month_col]); if (is.na(month)) next
      components <- numbers[r, block_cols]
      if (length(components) == 3L && all(!is.na(components)) &&
          abs(components[[1]] + components[[2]] - components[[3]]) > 1e-8) stop(
        "Compensatory-sales subtotal guard failed for ", year, "-", month, ".", call. = FALSE
      )
      for (j in block_cols) {
        measure <- text[month_row, j]; value <- numbers[r, j]
        if (documented_blank(measure) || is.na(value)) next
        k <- k + 1L
        records[[k]] <- documented_record(
          source_sheet, text[10, 1], "year_month_blocks",
          month_end(year, month), text[r, month_col], "monthly", measure,
          "BCP FX sales", measure, value, r, j
        )
        records[[k]]$unit <- "USD"; records[[k]]$scale <- "millions"; records[[k]]$currency <- "USD"
      }
    }
  }
  observations <- documented_bind_records(records)
  list(observations = observations, mode = "year_month_blocks", hierarchy_status = "unresolved",
       raw_nonempty_cells = sum(!documented_blank(text)), title = documented_table_title(text, seq_len(min(12L, nrow(text)))))
}

read_guarded_delimited <- function(con, item, release_id, expected_headers) {
  # readr's own "one or more parsing issues" warning is muffled and replaced by
  # the error below, which names the row, the column and what was expected. A
  # warning that says to go and call problems() yourself, followed by a stop that
  # already did, is one message too many.
  data <- withCallingHandlers(
    readr::read_delim(
      item$path, delim = ";", col_types = readr::cols(.default = readr::col_character()),
      locale = readr::locale(encoding = "UTF-8"), trim_ws = TRUE, show_col_types = FALSE,
      name_repair = "minimal", progress = FALSE
    ),
    warning = function(w) {
      if (grepl("parsing issue", conditionMessage(w), fixed = TRUE)) invokeRestart("muffleWarning")
    }
  )
  # The audit's F-05. readr records what it could not read in an attribute nobody
  # was reading, and every column here is col_character(), so a problem can only
  # mean a structural one -- a row with the wrong number of fields, an unclosed
  # quote, an encoding failure. That is not a row to filter out later; it is a
  # file that is not the file the contract describes.
  problems <- readr::problems(data)
  if (nrow(problems)) stop(
    "CSV structure guard: ", nrow(problems), " parsing problem(s) reading ", item$source_file,
    ". The delimited file does not match its declared shape and no part of it is accepted. ",
    "First: row ", problems$row[[1]], ", column ", problems$col[[1]], " -- expected ",
    problems$expected[[1]], ", got ", problems$actual[[1]], ".", call. = FALSE
  )
  names(data)[[1]] <- sub("^\\ufeff", "", names(data)[[1]])
  check <- assert_same_structure(expected_headers, names(data), item$source_id, "data", "headers")
  record_structure_check(con, check, item$vintage_id, release_id)
  data
}

# --- CSV row accounting ------------------------------------------------------
# The audit's F-05 and its section 11.3:
#
#   source data rows = accepted rows + rejected rows with an explicit reason
#
# The Excel path has had this since the first audit, at cell grain: every numeric
# source cell is an observation, a classified non-observation or a recorded
# discard, and an unexplained one blocks the release. The CSV path had none of
# it. It parsed permissively with readr::parse_number(), which takes the first
# numeric run out of any string it is handed, dropped whatever came back NA with
# dplyr::filter(), and recorded nothing -- so the only defect that could be
# noticed was losing *every* row.
#
# It was not hypothetical. Three securities trades -- real corporate-bond
# purchases at source rows 4747, 29690 and 173494, with a blank volume -- have
# been disappearing on every run since the source was added. 312,329 rows in the
# file, 312,326 in the database, and nothing anywhere said so.
#
# The machinery to fix it already existed and was unused here: discarded_rows
# (schema 12) and the rejected_observations column that compute_table_reconciliation()
# already sums out of it.

# What a number may look like: digits with an optional decimal comma, with or
# without '.' thousands groups. Neither source uses grouping today; accepting it
# costs nothing and refusing "12abc", "1.2.3" and "5 %" is the point.
CSV_NUMERIC_TOKEN <- "^[+-]?(([0-9]{1,3}(\\.[0-9]{3})+)|[0-9]+)(,[0-9]+)?$"

csv_blank_token <- function(x) is.na(x) | !nzchar(trimws(x))

# Present, and not a number. Distinguished from blank because they are different
# publisher acts with different reasons: a missing value versus a value written
# in a form this parser will not silently reinterpret.
csv_invalid_numeric_token <- function(x) {
  !csv_blank_token(x) & !grepl(CSV_NUMERIC_TOKEN, trimws(x))
}

parse_decimal_comma <- function(x) readr::parse_number(
  x, locale = readr::locale(decimal_mark = ",", grouping_mark = "."), na = c("", "NA", "N/A")
)

# Every rejected row carries one reason -- the first that applies, in the order
# the caller lists them, so a row with an unreadable date and a blank volume is
# reported once under the defect a reviewer would look at first rather than
# twice.
csv_row_rejections <- function(raw, tests) {
  # A reason no register describes is the silent-loss defect wearing a label, so
  # it is refused here rather than caught three phases later by the release gate.
  unsupported <- setdiff(names(tests), ROW_REJECTION_REASONS)
  if (length(unsupported)) stop(
    "Row-rejection guard: unsupported reason(s) ", paste(unsupported, collapse = ", "),
    ". Add them to ROW_REJECTION_REASONS and to config/row_rejection_reasons.csv.", call. = FALSE
  )
  reason <- rep(NA_character_, nrow(raw))
  for (name in names(tests)) {
    hit <- is.na(reason) & tests[[name]]
    reason[hit] <- name
  }
  rejected <- which(!is.na(reason))
  tibble::tibble(
    source_row = raw$source_row[rejected],
    reason = reason[rejected],
    raw_label = csv_row_label(raw[rejected, , drop = FALSE])
  )
}

# Enough of the row to recognise it in the source file without copying the file
# into the database.
csv_row_label <- function(rows) {
  if (!nrow(rows)) return(character())
  columns <- setdiff(names(rows), "source_row")
  vapply(seq_len(nrow(rows)), function(i) {
    values <- vapply(columns, function(column) {
      value <- as.character(rows[[column]][[i]])
      if (is.na(value)) "" else value
    }, character(1))
    substr(paste(values, collapse = ";"), 1L, 300L)
  }, character(1))
}

record_csv_rejections <- function(con, item, release_id, rejections) {
  DBI::dbExecute(con, paste0(
    "DELETE FROM discarded_rows WHERE vintage_id = ", sql_string(item$vintage_id)
  ))
  if (!nrow(rejections)) return(invisible(0L))
  rows <- rejections %>% dplyr::transmute(
    discard_id = vapply(paste(
      item$vintage_id, "data", .data$source_row, .data$reason, sep = "|"
    ), digest::digest, character(1), algo = "sha256", serialize = FALSE),
    release_id = release_id, vintage_id = item$vintage_id, source_id = item$source_id,
    source_sheet = "data", row_id = as.numeric(.data$source_row),
    reason = .data$reason, raw_label = .data$raw_label
  )
  DBI::dbWriteTable(con, "discarded_rows", rows, append = TRUE)
  invisible(nrow(rows))
}

# The accounting identity itself is computed release-wide, in
# compute_csv_row_reconciliation() (scripts/08_reconciliation.R), not here. Two
# reasons, both structural: apply_table_reconciliation() empties
# table_reconciliation and rebuilds it every release, so a row written during
# ingestion would not survive to be read; and an unchanged source is never
# re-parsed, so a parse-time count would go missing on exactly the runs where
# most sources are reused. Everything the identity needs is durable -- the source
# row count is on raw.source_sheets, the accepted rows are the snapshot, and the
# rejections are the rows this file writes.

curate_bond_curves_csv <- function(con, item, release_id, root, publication_date) {
  headers <- c("Periodo", "Moneda", "Calificación de Riesgo", "Plazo (años)", "Tasa cupon cero",
               "Factor de descuento", "Tasa Par", "beta0", "beta1", "beta2", "beta3", "lambda1", "lambda2")
  raw <- read_guarded_delimited(con, item, release_id, headers) %>% dplyr::mutate(source_row = dplyr::row_number() + 1L)
  # Every row is either accepted or rejected with a reason. The order of the
  # tests is the order a reviewer would want them attributed, and each row gets
  # the first that applies.
  numeric_columns <- c("Plazo (años)", "Tasa cupon cero", "Factor de descuento", "Tasa Par",
                       "beta0", "beta1", "beta2", "beta3", "lambda1", "lambda2")
  rejections <- csv_row_rejections(raw, list(
    invalid_date = csv_blank_token(raw$Periodo) |
      is.na(lubridate::dmy(substr(raw$Periodo, 1L, 10L), quiet = TRUE)),
    invalid_numeric_token = Reduce(`|`, lapply(
      numeric_columns, function(column) csv_invalid_numeric_token(raw[[column]])
    )),
    missing_mandatory_dimension = csv_blank_token(raw$`Plazo (años)`) |
      csv_blank_token(raw$Moneda) | csv_blank_token(raw$`Calificación de Riesgo`)
  ))
  record_csv_rejections(con, item, release_id, rejections)
  accepted <- raw %>% dplyr::filter(!.data$source_row %in% .env$rejections$source_row)
  snapshot <- accepted %>% dplyr::transmute(
    vintage_id = item$vintage_id, release_id = release_id, publication_date = as.Date(publication_date),
    source_file = item$source_file, source_row, period = lubridate::dmy(substr(.data$Periodo, 1L, 10L), quiet = TRUE),
    currency = .data$Moneda, risk_rating = .data$`Calificación de Riesgo`,
    maturity_years = parse_decimal_comma(.data$`Plazo (años)`),
    zero_coupon_rate = parse_decimal_comma(.data$`Tasa cupon cero`),
    discount_factor = parse_decimal_comma(.data$`Factor de descuento`),
    par_rate = parse_decimal_comma(.data$`Tasa Par`), beta0 = parse_decimal_comma(.data$beta0),
    beta1 = parse_decimal_comma(.data$beta1), beta2 = parse_decimal_comma(.data$beta2),
    beta3 = parse_decimal_comma(.data$beta3), lambda1 = parse_decimal_comma(.data$lambda1),
    lambda2 = parse_decimal_comma(.data$lambda2)
  )
  # Nothing may reach the snapshot that the rejection tests did not clear. The
  # filter this replaces *was* the classification; keeping it as an assertion is
  # what stops the two drifting apart.
  if (any(is.na(snapshot$period) | is.na(snapshot$maturity_years))) stop(
    "Bond-curve accounting guard: a row survived classification with an unusable period or ",
    "maturity. The rejection tests and the parse disagree.", call. = FALSE
  )
  if (!nrow(snapshot)) stop("Bond-curve guard: no valid observations.", call. = FALSE)
  assert_plausible_dates(snapshot$period, item$source_id, "data", minimum = as.Date("2000-01-01"))
  if (any(snapshot$maturity_years <= 0, na.rm = TRUE) ||
      any(snapshot$discount_factor <= 0 | snapshot$discount_factor > 2, na.rm = TRUE) ||
      any(snapshot$zero_coupon_rate < -0.5 | snapshot$zero_coupon_rate > 2, na.rm = TRUE) ||
      any(snapshot$par_rate < -0.5 | snapshot$par_rate > 2, na.rm = TRUE)) stop(
    "Bond-curve range guard failed for maturity, discount factor or rates.", call. = FALSE
  )
  set_source_publication_date(con, item$vintage_id, max(snapshot$period))
  publication_date <- settled_publication_date(con, item$vintage_id, max(snapshot$period))
  snapshot$publication_date <- publication_date
  update_archive_manifest_date(root, item$source_id, item$sha256, publication_date)
  DBI::dbExecute(con, paste0("DELETE FROM bond_curve_snapshot WHERE vintage_id = ", sql_string(item$vintage_id)))
  DBI::dbWriteTable(con, "bond_curve_snapshot", snapshot, append = TRUE)
  measures <- c(zero_coupon_rate = "proportion", discount_factor = "ratio", par_rate = "proportion")
  # This filter is not a row rejection and must not be recorded as one. The row
  # is accepted and stored in the snapshot; what is absent is one measure of a
  # curve node, which is what a sparse fact layer is for. No row is lost, and no
  # cell of this source is currently blank in any case.
  observations <- snapshot %>% tidyr::pivot_longer(dplyr::all_of(names(measures)), names_to = "measure", values_to = "value") %>%
    dplyr::filter(!is.na(.data$value)) %>% dplyr::mutate(
      series_key = paste(.data$currency, .data$risk_rating, format(.data$maturity_years, trim = TRUE), .data$measure, sep = "|"),
      series_id = paste0(item$source_id, ":", substr(vapply(.data$series_key, digest::digest, character(1),
        algo = "sha256", serialize = FALSE), 1L, 24L))
    )
  meta <- observations %>% dplyr::distinct(.data$series_id, .data$series_key, .data$currency, .data$measure) %>%
    dplyr::transmute(
      series_id, source_id = item$source_id, label = series_key, unit = unname(measures[measure]), scale = "units",
      frequency = "irregular_daily", currency, index_base = NA_character_, hierarchy_level = "yield_curve_point",
      parent_series_id = NA_character_, is_total = FALSE, identity_basis = series_key,
      identity_stability = "semantic", hierarchy_status = "flat", semantic_status = "curated",
      first_vintage_id = item$vintage_id
    )
  events <- write_sparse_series(con, observations %>% dplyr::select("series_id", "period", "value"), meta, item, publication_date)
  create_market_views(con)
  list(curated_rows = nrow(snapshot), event_rows = events, publication_date = publication_date, source_sheet = "data")
}

curate_securities_trades_csv <- function(con, item, release_id, root, publication_date) {
  headers <- c("Fecha Operacion", "Ruc Casa Bolsa", "Casa Bolsa", "Isin Identificador", "Ruc Emisor", "Emisor",
               "Instrumento", "Mercado", "Tipo Operacion", "Volumen Moneda Local", "Moneda", "Mercado Negociacion")
  raw <- read_guarded_delimited(con, item, release_id, headers) %>% dplyr::mutate(source_row = dplyr::row_number() + 1L)
  # The audit's F-05, in the place it actually cost something: three real
  # corporate-bond purchases with a blank volume have been dropped here on every
  # run since this source was added, leaving 312,326 rows in the database for
  # 312,329 in the file and no record of the difference anywhere.
  # A trade with an unknown volume is still a trade. The re-audit's RA2-06.
  #
  # Schema 34 stopped these three rows vanishing and classified them as
  # `missing_mandatory_dimension` -- correct as far as silent-loss detection
  # goes, and wrong as economics. Their date, broker, ISIN, issuer, instrument,
  # market, operation type and currency are all present and intact; what is
  # absent is one *measure*. Rejecting the row understates the count of corporate
  # bond purchases, so a reader summing `transactions` in the daily activity view
  # got a number that was wrong by three for reasons only the rejection register
  # explained.
  #
  # A blank volume is therefore accepted with a NULL value and an explicit
  # status. A *malformed* volume is still a rejection: "12abc" is not an absent
  # measure, it is a token this parser will not silently reinterpret, and the
  # file already models that distinction. Blank currency or instrument is still a
  # rejection too -- those are dimensions the grain is built from, not measures
  # hanging off it.
  #
  # This is the same shape the bond-curve parser above already uses for an absent
  # measure on a present node.
  volume_missing <- csv_blank_token(raw$`Volumen Moneda Local`)
  rejections <- csv_row_rejections(raw, list(
    invalid_date = csv_blank_token(raw$`Fecha Operacion`) |
      is.na(lubridate::dmy(raw$`Fecha Operacion`, quiet = TRUE)),
    invalid_numeric_token = csv_invalid_numeric_token(raw$`Volumen Moneda Local`),
    missing_mandatory_dimension = csv_blank_token(raw$Moneda) | csv_blank_token(raw$Instrumento)
  ))
  record_csv_rejections(con, item, release_id, rejections)
  snapshot <- raw %>% dplyr::filter(!.data$source_row %in% .env$rejections$source_row) %>%
    dplyr::transmute(
    vintage_id = item$vintage_id, release_id = release_id, publication_date = as.Date(publication_date),
    source_file = item$source_file,
    transaction_basis = paste(.data$`Fecha Operacion`, .data$`Ruc Casa Bolsa`, .data$`Isin Identificador`,
                              .data$`Ruc Emisor`, .data$Instrumento, .data$Mercado, .data$`Tipo Operacion`,
                              .data$`Volumen Moneda Local`, .data$Moneda, .data$`Mercado Negociacion`, sep = "|"),
    source_row, operation_date = lubridate::dmy(.data$`Fecha Operacion`, quiet = TRUE),
    broker_tax_id = .data$`Ruc Casa Bolsa`, broker_name = .data$`Casa Bolsa`, isin = .data$`Isin Identificador`,
    issuer_tax_id = .data$`Ruc Emisor`, issuer_name = .data$Emisor, instrument = .data$Instrumento,
    market = .data$Mercado, operation_type = .data$`Tipo Operacion`,
    local_currency_volume = parse_decimal_comma(.data$`Volumen Moneda Local`), currency = .data$Moneda,
    trading_venue = .data$`Mercado Negociacion`,
    # Whether the publisher reported the measure, said beside the value rather
    # than left for a reader to infer from a NULL.
    volume_status = dplyr::if_else(
      csv_blank_token(.data$`Volumen Moneda Local`), "not_reported", "reported"
    )
  ) %>%
    dplyr::group_by(.data$transaction_basis) %>% dplyr::mutate(duplicate_ordinal = dplyr::row_number()) %>% dplyr::ungroup() %>%
    dplyr::mutate(transaction_id = paste0("trade:", substr(vapply(paste(.data$transaction_basis, .data$duplicate_ordinal, sep = "|"),
      digest::digest, character(1), algo = "sha256", serialize = FALSE), 1L, 24L))) %>%
    dplyr::select(-dplyr::all_of(c("transaction_basis", "duplicate_ordinal"))) %>%
    dplyr::select(
      "vintage_id", "release_id", "publication_date", "source_file",
      "transaction_id", "source_row", "operation_date", "broker_tax_id", "broker_name",
      "isin", "issuer_tax_id", "issuer_name", "instrument", "market",
      "operation_type", "local_currency_volume", "volume_status", "currency", "trading_venue"
    )
  # Same assertion as the bond curves: the classification decides what is
  # accepted, and the parse must agree with it. Where a silent filter stood, an
  # error stands.
  #
  # The volume half is now a *correspondence* rather than a prohibition. A NULL
  # volume is permitted, and only where the source token was blank -- so a token
  # the parser failed to read for any other reason still stops the run instead of
  # quietly becoming a "not reported" measure.
  if (any(is.na(snapshot$operation_date))) stop(
    "Securities-trades accounting guard: a row survived classification with an unusable date. ",
    "The rejection tests and the parse disagree.", call. = FALSE
  )
  if (!identical(is.na(snapshot$local_currency_volume), snapshot$volume_status == "not_reported")) {
    stop(
      "Securities-trades accounting guard: a NULL volume does not correspond to a blank source ",
      "token. A measure the parser failed to read is not a measure the publisher did not report.",
      call. = FALSE
    )
  }
  if (!nrow(snapshot)) stop("Securities-trades guard: no valid transactions.", call. = FALSE)
  assert_plausible_dates(snapshot$operation_date, item$source_id, "data", minimum = as.Date("2000-01-01"))
  if (any(snapshot$local_currency_volume < 0, na.rm = TRUE)) stop(
    "Securities-trades range guard: negative local-currency volume.", call. = FALSE
  )
  if (any(is.na(snapshot$currency) | !nzchar(trimws(snapshot$currency)) |
          is.na(snapshot$instrument) | !nzchar(trimws(snapshot$instrument)))) stop(
    "Securities-trades semantic guard: currency or instrument is missing.", call. = FALSE
  )
  set_source_publication_date(con, item$vintage_id, max(snapshot$operation_date))
  publication_date <- settled_publication_date(con, item$vintage_id, max(snapshot$operation_date))
  snapshot$publication_date <- publication_date
  update_archive_manifest_date(root, item$source_id, item$sha256, publication_date)
  DBI::dbExecute(con, paste0("DELETE FROM securities_transactions_snapshot WHERE vintage_id = ", sql_string(item$vintage_id)))
  DBI::dbWriteTable(con, "securities_transactions_snapshot", snapshot, append = TRUE)
  create_market_views(con)
  list(curated_rows = nrow(snapshot), event_rows = 0L, publication_date = publication_date, source_sheet = "data")
}

create_market_views <- function(con) {
  # 'ingestion_status = completed' asks whether a vintage loaded. Whether it may
  # be published is a different question and has a different answer: a source
  # commits inside its own transaction, before the release-wide validation has
  # run at all. Both market views asked the first question and presented the
  # answer as the second, so a staged or blocked bond/securities vintage was
  # current here while the generic series path correctly hid it.
  latest_accepted_vintage <- function(source_id) paste(
    "(SELECT vintage_id FROM (SELECT vintage_id, row_number() OVER",
    "(PARTITION BY source_id ORDER BY publication_date DESC NULLS LAST, first_ingested_at DESC) rn",
    "FROM source_files WHERE source_id =", sql_string(source_id),
    "AND vintage_id IN (", accepted_release_vintages_sql(), ")) WHERE rn = 1) f USING (vintage_id)"
  )
  create_project_view(con, "v_bond_curves_latest", paste(
    "SELECT b.* FROM bond_curve_snapshot b JOIN", latest_accepted_vintage("corporate_bond_curves")
  ))
  create_project_view(con, "v_securities_transactions_latest", paste(
    "SELECT t.* FROM securities_transactions_snapshot t JOIN",
    latest_accepted_vintage("securities_trades")
  ))
  # `transactions` counts trades; `local_currency_volume` sums the ones that
  # report a volume. Those are different denominators whenever the publisher
  # omits a measure, so the second count says how many rows are behind the sum
  # rather than leaving a reader to assume it is all of them. The re-audit's
  # RA2-06: three corporate-bond purchases are in the count and not in the sum.
  create_project_view(con, "v_securities_daily_activity", paste(
    "SELECT operation_date, currency, instrument, market,",
    "operation_type, trading_venue, count(*) AS transactions,",
    "count(local_currency_volume) AS transactions_with_volume,",
    "sum(local_currency_volume) AS local_currency_volume",
    "FROM v_securities_transactions_latest GROUP BY 1,2,3,4,5,6"
  ))
  invisible(TRUE)
}

long_csv_parser <- function(con, item, dimensions, release_id, root, publication_date) {
  result <- switch(item$source_id,
    corporate_bond_curves = curate_bond_curves_csv(con, item, release_id, root, publication_date),
    securities_trades = curate_securities_trades_csv(con, item, release_id, root, publication_date),
    stop("No long-CSV parser registered for ", item$source_id, ".", call. = FALSE)
  )
  DBI::dbExecute(con, paste0("DELETE FROM semantic_coverage WHERE vintage_id = ", sql_string(item$vintage_id)))
  DBI::dbWriteTable(con, "semantic_coverage", tibble::tibble(
    vintage_id = item$vintage_id, source_id = item$source_id, source_sheet = "data",
    semantic_status = "curated_long_format", raw_nonempty_cells = as.integer(dimensions$used_rows[[1]] * dimensions$used_cols[[1]]),
    curated_observations = as.integer(result$curated_rows),
    coverage_note = "Guarded typed long-format ingestion; original source file retained by content hash."
  ), append = TRUE)
  result
}
