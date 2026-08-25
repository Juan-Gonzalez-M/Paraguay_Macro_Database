documented_blank <- function(x) {
  input_dim <- dim(x)
  out <- is.na(x) | !nzchar(trimws(as.character(x)))
  if (!is.null(input_dim)) dim(out) <- input_dim
  out
}

documented_or <- function(x, fallback) {
  if (is.null(x) || !length(x) || all(is.na(x))) fallback else x
}

documented_as_date <- function(x) {
  if (inherits(x, "Date")) return(as.Date(x))
  as.Date(as.numeric(x), origin = "1970-01-01")
}

documented_text_matrix <- function(raw) {
  if (!ncol(raw)) return(matrix(character(), nrow = 0L, ncol = 0L))
  out <- do.call(cbind, lapply(raw, cell_character))
  if (is.null(dim(out))) out <- matrix(out, ncol = ncol(raw))
  out
}

documented_number_matrix <- function(raw) {
  if (!ncol(raw)) return(matrix(double(), nrow = 0L, ncol = 0L))
  out <- do.call(cbind, lapply(raw, as_number_or_na))
  if (is.null(dim(out))) out <- matrix(out, ncol = ncol(raw))
  out
}

documented_date_matrix <- function(raw, text) {
  if (!ncol(raw)) return(matrix(as.Date(character()), nrow = 0L, ncol = 0L))
  typed <- do.call(cbind, lapply(raw, function(x) as.numeric(as_typed_date(x))))
  if (is.null(dim(typed))) typed <- matrix(typed, ncol = ncol(raw))
  result <- matrix(as.Date(NA), nrow = nrow(text), ncol = ncol(text))
  typed_keep <- !is.na(typed)
  result[typed_keep] <- as.Date(typed[typed_keep], origin = "1970-01-01")
  match <- stringr::str_match(trimws(text), "^((?:19|20)[0-9]{2})[/.-](0?[1-9]|1[0-2])$")
  char_keep <- !is.na(match[, 1])
  if (any(char_keep)) {
    result[char_keep] <- lubridate::ceiling_date(as.Date(sprintf(
      "%s-%02d-01", match[char_keep, 2], as.integer(match[char_keep, 3])
    )), "month") - lubridate::days(1)
  }
  month_match <- stringr::str_match(
    normalize_semantic_label(trimws(text)),
    "^(ene|feb|mar|abr|may|jun|jul|ago|sep|set|oct|nov|dic)[- /]([0-9]{2}|[0-9]{4})$"
  )
  month_keep <- !is.na(month_match[, 1])
  if (any(month_keep)) {
    years <- as.integer(month_match[month_keep, 3])
    years[years < 100L] <- years[years < 100L] + ifelse(years[years < 100L] >= 40L, 1900L, 2000L)
    months <- documented_month_number(month_match[month_keep, 2])
    result[month_keep] <- as.Date(vapply(seq_along(years), function(i) {
      as.character(month_end(years[[i]], months[[i]]))
    }, character(1)))
  }
  result
}

documented_year_values <- function(text) {
  input_dim <- dim(text)
  values <- trimws(as.character(text))
  matched <- stringr::str_match(
    values,
    "^((?:19|20)[0-9]{2})(?:\\s*(?:\\(?\\*+\\)?|[0-9]{1,2}/))*\\s*$"
  )
  year <- suppressWarnings(as.integer(matched[, 2]))
  if (!is.null(input_dim)) dim(year) <- input_dim
  year
}

documented_year_axis_counts <- function(years, margin = 1L, minimum = 3L) {
  if (is.null(dim(years)) || length(dim(years)) != 2L || any(dim(years) == 0L)) return(numeric())
  margin <- as.integer(margin)
  if (!margin %in% c(1L, 2L)) stop("Year-axis margin must be 1 (rows) or 2 (columns).", call. = FALSE)
  minimum <- as.integer(minimum)
  n_slices <- dim(years)[[margin]]
  vapply(seq_len(n_slices), function(i) {
    values <- if (margin == 1L) years[i, ] else years[, i]
    values <- values[!is.na(values)]
    if (length(values) < minimum) return(0)
    # A single reviewed year is only accepted as an axis when the caller has
    # explicitly lowered the floor to 1 (see year_axis_minimum in
    # sheet_modes.csv); every other caller keeps the default minimum of 2+
    # distinct, consistently ordered years, so this branch changes nothing
    # for them.
    if (length(values) == 1L) return(if (minimum <= 1L) 1 else 0)
    if (length(unique(values)) < 2L) return(0)
    changes <- diff(values)
    nonzero <- changes[changes != 0L]
    ordered <- length(nonzero) && (all(nonzero > 0L) || all(nonzero < 0L))
    plausible_gaps <- length(nonzero) && all(abs(nonzero) <= 10L)
    if (ordered && plausible_gaps) length(values) else 0
  }, numeric(1))
}

documented_year_axis_index <- function(text, margin = 1L, minimum = 3L) {
  years <- documented_year_values(text)
  counts <- documented_year_axis_counts(years, margin = margin, minimum = minimum)
  if (!length(counts) || !any(counts > 0L)) return(NA_integer_)
  header_bonus <- vapply(seq_along(counts), function(i) {
    values <- if (margin == 1L) text[i, ] else text[, i]
    any(normalize_semantic_label(values) == "ano", na.rm = TRUE)
  }, logical(1))
  which.max(counts + as.numeric(header_bonus) / 2)
}

documented_consecutive_year_rows <- function(text, minimum = 2L) {
  years <- documented_year_values(text)
  if (!length(years) || !nrow(years)) return(integer())
  which(vapply(seq_len(nrow(years)), function(r) {
    values <- years[r, !is.na(years[r, ])]
    length(values) >= as.integer(minimum) && !anyDuplicated(values) &&
      all(diff(values) == 1L)
  }, logical(1)))
}

documented_date_axis_token <- function(x) {
  key <- normalize_semantic_label(trimws(as.character(x)))
  out <- stringr::str_detect(
    key,
    "^(?:(?:19|20)[0-9]{2}-[0-1][0-9]-[0-3][0-9]|(?:19|20)[0-9]{2}[/.-](?:0?[1-9]|1[0-2])|(?:ene|feb|mar|abr|may|jun|jul|ago|sep|set|oct|nov|dic)[- /](?:[0-9]{2}|[0-9]{4}))$"
  )
  out[is.na(out)] <- FALSE
  out
}

documented_month_number <- function(x) {
  input_dim <- dim(x)
  key <- normalize_semantic_label(x)
  key <- stringr::str_replace_all(key, "[.]", "")
  map <- c(
    ene = 1L, enero = 1L, jan = 1L, january = 1L,
    feb = 2L, febrero = 2L, february = 2L,
    mar = 3L, marzo = 3L, march = 3L,
    abr = 4L, abril = 4L, apr = 4L, april = 4L,
    may = 5L, mayo = 5L,
    jun = 6L, junio = 6L, june = 6L,
    jul = 7L, julio = 7L, july = 7L,
    ago = 8L, agosto = 8L, aug = 8L, august = 8L,
    sep = 9L, sept = 9L, set = 9L, setiembre = 9L, septiembre = 9L, september = 9L,
    oct = 10L, octubre = 10L, october = 10L,
    nov = 11L, noviembre = 11L, november = 11L,
    dic = 12L, diciembre = 12L, dec = 12L, december = 12L
  )
  result <- unname(map[key])
  if (!is.null(input_dim)) dim(result) <- input_dim
  result
}

documented_quarter_number <- function(x) {
  input_dim <- dim(x)
  key <- normalize_semantic_label(x)
  key <- stringr::str_replace_all(key, "[.]", "")
  out <- rep(NA_integer_, length(key))
  roman <- c(i = 1L, ii = 2L, iii = 3L, iv = 4L)
  out[key %in% names(roman)] <- unname(roman[key[key %in% names(roman)]])
  # A naked 1--4 is commonly an index, footnote or data value. Require an
  # explicit quarter marker (T or trim/trimester) before interpreting it as a
  # period. Roman numerals remain accepted because the BCP uses I--IV headers.
  numeric_match <- stringr::str_match(
    key,
    "^(?:t\\s*([1-4])(?:er|do|ro|to)?|([1-4])(?:er|do|ro|to)?\\s*trim(?:e|estre)?)$"
  )
  keep <- !is.na(numeric_match[, 1])
  captured <- dplyr::coalesce(numeric_match[, 2], numeric_match[, 3])
  out[keep] <- as.integer(captured[keep])
  if (!is.null(input_dim)) dim(out) <- input_dim
  out
}

documented_contextual_quarters <- function(period_labels, raw_year_values) {
  quarters <- documented_quarter_number(period_labels)
  year_starts <- which(!is.na(raw_year_values))
  if (!length(year_starts)) return(quarters)
  annual_total <- stringr::str_detect(
    normalize_semantic_label(period_labels), "total|anual|ano"
  ) | !is.na(documented_year_values(period_labels))
  annual_total[is.na(annual_total)] <- FALSE
  # Infer a missing token only inside a complete Q1--Q4/annual block whose
  # explicit quarter labels agree with their slots. This recovers an official
  # workbook cell containing a naked digit without globally treating 1--4 as
  # quarters.
  for (ii in seq_along(year_starts)) {
    start <- year_starts[[ii]]
    end <- if (ii < length(year_starts)) year_starts[[ii + 1L]] - 1L else length(period_labels)
    block <- seq.int(start, end)
    totals <- block[annual_total[block]]
    if (!length(totals)) next
    annual_col <- totals[[1]]
    quarter_cols <- block[block < annual_col]
    if (length(quarter_cols) != 4L) next
    explicit <- quarters[quarter_cols]
    expected <- seq_len(4L)
    if (any(!is.na(explicit) & explicit != expected)) next
    quarters[quarter_cols[is.na(explicit)]] <- expected[is.na(explicit)]
  }
  quarters
}

documented_fill_right <- function(x) {
  if (!length(x)) return(x)
  for (r in seq_len(nrow(x))) {
    values <- x[r, ]
    blank <- documented_blank(values)
    previous <- cummax(ifelse(!blank, seq_along(values), 0L))
    fill <- blank & previous > 0L
    values[fill] <- values[previous[fill]]
    x[r, ] <- values
  }
  x
}

documented_fill_down <- function(x) {
  if (!length(x)) return(x)
  for (j in seq_len(ncol(x))) {
    values <- x[, j]
    blank <- documented_blank(values)
    previous <- cummax(ifelse(!blank, seq_along(values), 0L))
    fill <- blank & previous > 0L
    values[fill] <- values[previous[fill]]
    x[, j] <- values
  }
  x
}

documented_compact_path <- function(x) {
  x <- stringr::str_squish(as.character(x))
  x <- x[!is.na(x) & nzchar(x)]
  paste(unique(x), collapse = " — ")
}

documented_header_rows <- function(text, data_start, data_cols, maximum = 8L) {
  if (data_start <= 1L || !length(data_cols)) return(integer())
  candidate <- seq.int(max(1L, data_start - maximum), data_start - 1L)
  density <- rowSums(!documented_blank(text[candidate, data_cols, drop = FALSE]))
  selected <- candidate[density >= pmin(2L, length(data_cols))]
  if (!length(selected)) selected <- tail(candidate[density > 0L], 1L)
  selected
}

documented_table_title <- function(text, metadata_rows) {
  if (!length(metadata_rows)) return(NA_character_)
  values <- as.vector(t(text[metadata_rows, , drop = FALSE]))
  values <- stringr::str_squish(values)
  keep <- !documented_blank(values) & nchar(values) >= 6L &
    !stringr::str_detect(normalize_semantic_label(values), "^(indice|cuadro n|ano mes|fecha)$")
  values <- unique(values[keep])
  if (!length(values)) return(NA_character_)
  substr(paste(head(values, 6L), collapse = " — "), 1L, 800L)
}

documented_mode <- function(text, dates, source_sheet = NULL) {
  date_mask <- !is.na(dates)
  years <- documented_year_values(text)
  coherent_year_rows <- documented_year_axis_counts(years, margin = 1L)
  coherent_year_cols <- documented_year_axis_counts(years, margin = 2L)
  month_mask <- !is.na(documented_month_number(text))
  quarter_mask <- !is.na(documented_quarter_number(text))
  maxima <- c(
    date_row = max(rowSums(date_mask), 0L), date_col = max(colSums(date_mask), 0L),
    year_row = max(coherent_year_rows, 0L), year_col = max(coherent_year_cols, 0L),
    month_col = max(colSums(month_mask), 0L), quarter_row = max(rowSums(quarter_mask), 0L),
    quarter_col = max(colSums(quarter_mask), 0L)
  )
  if (maxima[["date_col"]] >= 3L && maxima[["date_col"]] >= maxima[["date_row"]]) return("vertical_date")
  if (maxima[["date_row"]] >= 3L) return("horizontal_date")
  if (maxima[["year_row"]] >= 3L && maxima[["quarter_row"]] >= 3L) return("horizontal_year_quarter")
  if (maxima[["year_row"]] >= 3L && maxima[["month_col"]] >= 3L) return("horizontal_year_month")
  if (maxima[["year_row"]] >= 3L) return("horizontal_year")
  if (maxima[["year_col"]] >= 3L && (maxima[["month_col"]] >= 3L || maxima[["quarter_col"]] >= 3L)) return("vertical_block")
  if (maxima[["year_col"]] >= 3L) return("vertical_year")
  "unparsed"
}

documented_frequency <- function(periods) {
  periods <- sort(unique(documented_as_date(periods[!is.na(periods)])))
  if (length(periods) < 2L) return("monthly")
  day_gap <- stats::median(diff(as.numeric(periods)))
  if (!is.na(day_gap) && day_gap <= 7) return("daily")
  month_index <- lubridate::year(periods) * 12L + lubridate::month(periods)
  gap <- stats::median(diff(month_index))
  if (gap <= 2) "monthly" else if (gap <= 5) "quarterly" else if (gap <= 8) "semiannual" else "annual"
}

documented_measure_metadata_vectorized <- function(series_label, table_title) {
  if (!length(series_label) && !length(table_title)) return(tibble::tibble(
    unit = character(), scale = character(), currency = character(), index_base = character()
  ))
  if (!length(series_label) || !length(table_title)) stop(
    "Metadata labels and titles must both be present (NA is allowed).", call. = FALSE
  )
  size <- max(length(series_label), length(table_title))
  series_label <- rep_len(series_label, size)
  table_title <- rep_len(table_title, size)
  local <- normalize_semantic_label(series_label)
  global <- normalize_semantic_label(table_title)
  local[is.na(local)] <- ""
  global[is.na(global)] <- ""
  context <- paste(local, global)
  pyg_token <- "pyg|guarani|moneda nacional|(^| )mn($| )|(^| )gs(?:[./ ]|$)|₲"
  local_currencies <- cbind(
    PYG = stringr::str_detect(local, pyg_token),
    FX = stringr::str_detect(local, "moneda extranjera|(^| )me($| )"),
    USD = stringr::str_detect(local, "usd|dolar"),
    EUR = stringr::str_detect(local, "eur|euro")
  )
  global_currencies <- cbind(
    PYG = stringr::str_detect(global, pyg_token),
    FX = stringr::str_detect(global, "moneda extranjera|(^| )me($| )"),
    USD = stringr::str_detect(global, "usd|dolar"),
    EUR = stringr::str_detect(global, "eur|euro")
  )
  currencies <- local_currencies
  use_global <- rowSums(local_currencies) == 0L
  currencies[use_global, ] <- global_currencies[use_global, , drop = FALSE]
  currency <- rep(NA_character_, size)
  single <- rowSums(currencies) == 1L
  currency[single] <- colnames(currencies)[max.col(currencies[single, , drop = FALSE], ties.method = "first")]
  unit <- dplyr::case_when(
    stringr::str_detect(local, "cantidad|numero|lotes|operaciones|tarjetas|cheques|dependencias|personal") ~ "count",
    stringr::str_detect(context, "porcentaje|%") ~ "percent",
    stringr::str_detect(context, "veces") ~ "ratio",
    stringr::str_detect(context, "indice|base .{0,40}100") ~ "index",
    stringr::str_detect(local, "plazo.{0,20}dia|dias") ~ "days",
    stringr::str_detect(context, "usd[/ ]?(?:por )?ton|dolar.{0,12}ton") ~ "USD_per_tonne",
    stringr::str_detect(context, "usd[/ ]?(?:por )?barr|dolar.{0,12}barr") ~ "USD_per_barrel",
    stringr::str_detect(context, "tipo de cambio|pyg[/ ]?usd|guarani.{0,20}dolar") ~ "PYG_per_USD",
    stringr::str_detect(context, "toneladas") & stringr::str_detect(context, "kwh") ~ "mixed_physical_units",
    stringr::str_detect(context, "toneladas") ~ "tonnes",
    stringr::str_detect(context, "kwh") ~ "kWh",
    currency %in% c("PYG", "USD", "EUR") ~ currency,
    TRUE ~ "source_units"
  )
  scale <- dplyr::case_when(
    stringr::str_detect(context, "miles (de )?millones") ~ "billions",
    stringr::str_detect(context, "millones") ~ "millions",
    stringr::str_detect(context, "miles") ~ "thousands",
    TRUE ~ "units"
  )
  scale[unit %in% c("index", "percent", "ratio", "count", "days")] <- "units"
  currency[unit == "PYG_per_USD"] <- "PYG/USD"
  base_match <- stringr::str_extract(table_title, stringr::regex("base.{0,50}?100", ignore_case = TRUE))
  tibble::tibble(
    unit = unit, scale = scale, currency = currency,
    index_base = dplyr::if_else(is.na(base_match), NA_character_, base_match)
  )
}

# Single-input convenience wrapper for tests exercising one label/title pair
# at a time. No production caller uses this -- every real parser goes through
# documented_enrich_metadata()/documented_measure_metadata_vectorized() so it
# only pays the regex cost once per distinct (label, title) pair, not once per
# observation. Keep it as a test helper; do not add production call sites.
documented_measure_metadata_single <- function(series_label, table_title) {
  result <- documented_measure_metadata_vectorized(series_label, table_title)
  if (nrow(result) != 1L) stop(
    "documented_measure_metadata_single() takes one label/title pair; use documented_measure_metadata_vectorized() for vectors.",
    call. = FALSE
  )
  as.list(result[1, , drop = FALSE])
}

documented_enrich_metadata <- function(observations, metadata_label = observations$series_label) {
  if (!nrow(observations)) return(observations)
  if (length(metadata_label) != nrow(observations)) stop(
    "Metadata label vector must have one value per observation.", call. = FALSE
  )
  metadata_fields <- c("unit", "scale", "currency", "index_base")
  for (field in metadata_fields) if (!field %in% names(observations)) observations[[field]] <- NA_character_
  if (!"is_total" %in% names(observations)) observations$is_total <- NA
  observations$.metadata_label <- metadata_label
  lookup <- observations %>%
    dplyr::distinct(.data$.metadata_label, .data$table_title)
  lookup <- lookup %>%
    dplyr::bind_cols(documented_measure_metadata_vectorized(lookup$.metadata_label, lookup$table_title)) %>%
    dplyr::rename_with(~ paste0(.x, "_inferred"), dplyr::all_of(metadata_fields))
  observations %>%
    dplyr::left_join(lookup, by = c(".metadata_label", "table_title"), na_matches = "na") %>%
    dplyr::mutate(
      unit = dplyr::coalesce(.data$unit, .data$unit_inferred),
      scale = dplyr::coalesce(.data$scale, .data$scale_inferred),
      currency = dplyr::coalesce(.data$currency, .data$currency_inferred),
      index_base = dplyr::coalesce(.data$index_base, .data$index_base_inferred),
      is_total = dplyr::coalesce(.data$is_total, documented_is_total(.data$series_label))
    ) %>%
    dplyr::select(-dplyr::all_of(c(".metadata_label", paste0(metadata_fields, "_inferred"))))
}

documented_is_total <- function(x) {
  stringr::str_detect(normalize_semantic_label(x), "(^| )(total|sistema|indice general)( |$)")
}

documented_empty_observations <- function() tibble::tibble(
  source_sheet = character(), table_title = character(), parser_mode = character(),
  period = as.Date(character()), source_period_label = character(), frequency = character(),
  series_label = character(), series_path = character(), category = character(), measure = character(),
  question = character(), response = character(), entity_id = character(), exchange_item_id = character(),
  participant_id = character(),
  hierarchy_status = character(),
  unit = character(), scale = character(), currency = character(), index_base = character(),
  value = double(), is_total = logical(), source_row = integer(), source_column = integer()
)

documented_record <- function(source_sheet, title, mode, period, period_label,
                              frequency, series_label, category, measure, value,
                              source_row, source_column, question = NA_character_,
                              response = NA_character_, entity_id = NA_character_,
                              participant_id = NA_character_) {
  # Keep the hot path allocation-light. Metadata depends only on the repeated
  # (series_label, table_title) pair and is added once per unique pair by
  # documented_enrich_metadata() after all sheets have been assembled.
  list(
    source_sheet = source_sheet, table_title = title, parser_mode = mode,
    period = documented_as_date(period), source_period_label = as.character(period_label), frequency = frequency,
    series_label = series_label, series_path = documented_compact_path(c(category, series_label)),
    category = category, measure = measure, question = question, response = response,
    entity_id = entity_id, exchange_item_id = NA_character_, participant_id = participant_id,
    unit = NA_character_, scale = NA_character_, currency = NA_character_,
    index_base = NA_character_, value = as.numeric(value),
    is_total = NA, source_row = as.integer(source_row),
    source_column = as.integer(source_column)
  )
}

documented_bind_records <- function(records) {
  records <- Filter(Negate(is.null), records)
  if (!length(records)) return(documented_empty_observations())
  fields <- names(records[[1]])
  if (!length(fields) || anyDuplicated(fields) || any(vapply(
    records, function(record) !identical(names(record), fields), logical(1)
  ))) stop("Documented record collector contains inconsistent fields.", call. = FALSE)
  columns <- lapply(fields, function(field) {
    values <- lapply(records, `[[`, field)
    raw <- unlist(values, recursive = FALSE, use.names = FALSE)
    if (field == "period") return(as.Date(as.numeric(raw), origin = "1970-01-01"))
    if (field %in% c("source_row", "source_column")) return(as.integer(raw))
    if (field == "value") return(as.numeric(raw))
    if (field == "is_total") return(as.logical(raw))
    as.character(raw)
  })
  names(columns) <- fields
  tibble::as_tibble(columns)
}

# Compatibility wrapper retained for external callers and focused unit tests.
# Production parsers assign documented_record() directly into their list so R
# never passes and returns the growing collector on every observation.
documented_add_record <- function(records, k, source_sheet, title, mode, period, period_label,
                                  frequency, series_label, category, measure, value,
                                  source_row, source_column, question = NA_character_,
                                  response = NA_character_, entity_id = NA_character_,
                                  participant_id = NA_character_) {
  records[[k]] <- documented_record(
    source_sheet, title, mode, period, period_label, frequency, series_label,
    category, measure, value, source_row, source_column, question, response,
    entity_id, participant_id
  )
  records
}

documented_extract_vertical_date <- function(text, numbers, dates, source_sheet) {
  valid_axis_tokens <- matrix(
    documented_date_axis_token(text), nrow = nrow(text), ncol = ncol(text)
  )
  date_counts <- colSums(!is.na(dates) & valid_axis_tokens)
  axis_col <- which.max(date_counts)
  date_rows <- which(!is.na(dates[, axis_col]) & valid_axis_tokens[, axis_col])
  if (!length(date_rows)) return(documented_empty_observations())
  numeric_row <- rowSums(!is.na(numbers)) > 0L
  between <- seq.int(min(date_rows), max(date_rows))
  unlabeled_numeric <- sum(numeric_row[between] & is.na(dates[between, axis_col]))
  block_fill <- unlabeled_numeric > max(3L, length(date_rows) / 2L)
  candidate_rows <- if (block_fill) between[numeric_row[between]] else date_rows[numeric_row[date_rows]]
  if (!length(candidate_rows)) return(documented_empty_observations())
  periods <- dates[, axis_col]
  if (block_fill) {
    for (r in seq.int(min(date_rows), max(candidate_rows))) {
      if (r > 1L && is.na(periods[[r]])) periods[[r]] <- periods[[r - 1L]]
    }
  }
  frequency_default <- documented_frequency(dates[date_rows, axis_col])
  min_density <- max(2L, floor(length(candidate_rows) * 0.05))
  possible_cols <- seq.int(axis_col + 1L, ncol(text))
  numeric_density <- colSums(!is.na(numbers[candidate_rows, possible_cols, drop = FALSE]))
  date_density <- colSums(!is.na(dates[candidate_rows, possible_cols, drop = FALSE]))
  # Settlement/maturity columns are attributes of an observation, not numeric
  # measures. Excel dates are internally numeric, so explicitly exclude columns
  # whose candidate cells are predominantly dates.
  data_cols <- possible_cols[numeric_density >= min_density & date_density < min_density]
  if (!length(data_cols)) return(documented_empty_observations())
  first_data_col <- min(data_cols)
  header_rows <- documented_header_rows(text, min(candidate_rows), data_cols)
  headers <- documented_fill_right(text)
  metadata_rows <- setdiff(seq_len(max(1L, min(candidate_rows) - 1L)), header_rows)
  title <- documented_table_title(text, metadata_rows)
  column_labels <- vapply(data_cols, function(j) {
    label <- documented_compact_path(headers[header_rows, j])
    if (!nzchar(label)) paste0("column_", j) else label
  }, character(1))
  label_cols <- if (first_data_col > axis_col + 1L) seq.int(axis_col + 1L, first_data_col - 1L) else integer()
  label_context <- rep(NA_character_, length(label_cols))
  annual_rows <- integer()
  if (!block_fill) {
    years <- documented_year_values(text[, axis_col])
    annual_rows <- which(!is.na(years) & numeric_row)
  }
  records <- vector("list", (length(candidate_rows) + length(annual_rows)) * length(data_cols)); k <- 0L
  for (r in candidate_rows) {
    if (length(label_cols)) {
      current <- text[r, label_cols]
      update <- !documented_blank(current)
      label_context[update] <- current[update]
      row_label <- documented_compact_path(label_context)
    } else row_label <- ""
    for (jj in seq_along(data_cols)) {
      j <- data_cols[[jj]]
      value <- numbers[r, j]
      if (is.na(value) || is.na(periods[[r]])) next
      series_label <- documented_compact_path(c(row_label, column_labels[[jj]]))
      k <- k + 1L
      records[[k]] <- documented_record(
        source_sheet, title, "vertical_date", periods[[r]], text[r, axis_col],
        frequency_default, series_label, row_label, column_labels[[jj]], value, r, j
      )
    }
  }
  if (!block_fill) {
    for (r in annual_rows) for (jj in seq_along(data_cols)) {
      j <- data_cols[[jj]]; value <- numbers[r, j]
      if (is.na(value)) next
      series_label <- column_labels[[jj]]
      k <- k + 1L
      records[[k]] <- documented_record(
        source_sheet, title, "vertical_date", as.Date(paste0(years[[r]], "-12-31")),
        text[r, axis_col], "annual", series_label, "", column_labels[[jj]], value, r, j
      )
    }
  }
  documented_bind_records(records)
}

documented_extract_horizontal_time <- function(text, numbers, dates, source_sheet, mode) {
  if (mode == "horizontal_date") {
    time_row <- which.max(rowSums(!is.na(dates)))
    period_values <- dates[time_row, ]
    first_time_col <- min(which(!is.na(period_values)))
    for (j in seq.int(first_time_col, ncol(text))) {
      if (j > first_time_col && is.na(period_values[[j]])) period_values[[j]] <- period_values[[j - 1L]]
    }
    frequency_default <- documented_frequency(dates[time_row, !is.na(dates[time_row, ])])
  } else {
    years <- documented_year_values(text)
    time_row <- documented_year_axis_index(text, margin = 1L)
    if (is.na(time_row)) return(documented_empty_observations())
    year_values <- years[time_row, ]
    first_time_col <- min(which(!is.na(year_values)))
    for (j in seq.int(first_time_col, ncol(text))) {
      if (j > first_time_col && is.na(year_values[[j]])) year_values[[j]] <- year_values[[j - 1L]]
    }
    period_values <- as.Date(ifelse(is.na(year_values), NA_character_, paste0(year_values, "-12-31")))
    frequency_default <- "annual"
  }
  time_cols <- which(!is.na(period_values))
  if (!length(time_cols)) return(documented_empty_observations())
  row_density <- rowSums(!is.na(numbers[, time_cols, drop = FALSE]))
  possible_data_rows <- which(seq_len(nrow(text)) > time_row & row_density >= 1L)
  label_cols <- seq_len(first_time_col - 1L)
  has_label <- rowSums(!documented_blank(text[, label_cols, drop = FALSE])) > 0L
  data_rows <- possible_data_rows[has_label[possible_data_rows]]
  if (!length(data_rows)) return(documented_empty_observations())
  data_start <- min(data_rows)
  subheader_rows <- if (data_start > time_row + 1L) seq.int(time_row + 1L, data_start - 1L) else integer()
  subheaders <- documented_fill_right(text)
  metadata_rows <- if (time_row > 1L) seq_len(time_row - 1L) else integer()
  title <- documented_table_title(text, metadata_rows)
  column_labels <- vapply(time_cols, function(j) documented_compact_path(subheaders[subheader_rows, j]), character(1))
  label_state <- rep(NA_character_, length(label_cols))
  records <- vector("list", length(data_rows) * length(time_cols)); k <- 0L
  for (r in data_rows) {
    current <- text[r, label_cols]
    actual_label <- any(!documented_blank(current))
    if (!actual_label) next
    if (length(label_cols) > 1L) {
      update <- !documented_blank(current)
      label_state[update] <- current[update]
      row_label <- documented_compact_path(label_state)
    } else row_label <- documented_compact_path(current)
    if (!nzchar(row_label)) next
    for (jj in seq_along(time_cols)) {
      j <- time_cols[[jj]]; value <- numbers[r, j]
      if (is.na(value)) next
      measure <- column_labels[[jj]]
      series_label <- documented_compact_path(c(row_label, measure))
      k <- k + 1L
      records[[k]] <- documented_record(
        source_sheet, title, mode, period_values[[j]], text[time_row, j],
        frequency_default, series_label, row_label, measure, value, r, j
      )
    }
  }
  documented_bind_records(records)
}

documented_extract_vertical_block <- function(text, numbers, source_sheet, mode = "vertical_block") {
  years <- documented_year_values(text)
  axis_col <- documented_year_axis_index(text, margin = 2L)
  if (is.na(axis_col)) return(documented_empty_observations())
  year_rows <- which(!is.na(years[, axis_col]))
  if (!length(year_rows)) return(documented_empty_observations())
  period_candidates <- unique(pmin(ncol(text), c(axis_col, axis_col + 1L, axis_col + 2L)))
  period_scores <- vapply(period_candidates, function(j) {
    sum(!is.na(documented_month_number(text[, j]))) + sum(!is.na(documented_quarter_number(text[, j])))
  }, numeric(1))
  period_col <- period_candidates[[which.max(period_scores)]]
  start_row <- min(year_rows)
  candidate_rows <- seq.int(start_row, nrow(text))
  min_density <- max(2L, floor(length(candidate_rows) * 0.02))
  possible_cols <- seq.int(max(axis_col, period_col) + 1L, ncol(text))
  numeric_density <- colSums(!is.na(numbers[candidate_rows, possible_cols, drop = FALSE]))
  data_cols <- possible_cols[numeric_density >= min_density]
  if (!length(data_cols)) return(documented_empty_observations())
  header_rows <- documented_header_rows(text, start_row, data_cols)
  headers <- documented_fill_right(text)
  metadata_rows <- setdiff(seq_len(max(1L, start_row - 1L)), header_rows)
  title <- documented_table_title(text, metadata_rows)
  column_labels <- vapply(data_cols, function(j) {
    value <- documented_compact_path(headers[header_rows, j])
    if (!nzchar(value)) paste0("column_", j) else value
  }, character(1))
  observed_months <- sort(unique(documented_month_number(text[, period_col])))
  observed_months <- observed_months[!is.na(observed_months)]
  semiannual_months <- length(observed_months) > 0L && all(observed_months %in% c(6L, 12L))
  records <- vector("list", length(candidate_rows) * length(data_cols)); k <- 0L; current_year <- NA_integer_
  for (r in candidate_rows) {
    row_year <- years[r, axis_col]
    if (!is.na(row_year)) current_year <- row_year
    if (is.na(current_year)) next
    label <- text[r, period_col]
    month <- documented_month_number(label)
    quarter <- documented_quarter_number(label)
    if (!is.na(month)) {
      frequency <- if (semiannual_months) "semiannual" else "monthly"
      period <- lubridate::ceiling_date(as.Date(sprintf("%d-%02d-01", current_year, month)), "month") - lubridate::days(1)
    } else if (!is.na(quarter)) {
      frequency <- "quarterly"; period <- quarter_end(current_year, quarter)
    } else if (!is.na(row_year)) {
      frequency <- "annual"; period <- as.Date(paste0(current_year, "-12-31"))
    } else next
    for (jj in seq_along(data_cols)) {
      j <- data_cols[[jj]]; value <- numbers[r, j]
      if (is.na(value)) next
      series_label <- column_labels[[jj]]
      k <- k + 1L
      records[[k]] <- documented_record(
        source_sheet, title, mode, period, label, frequency,
        series_label, "", series_label, value, r, j
      )
    }
  }
  documented_bind_records(records)
}

documented_extract_horizontal_year_quarter <- function(text, numbers, source_sheet) {
  years <- documented_year_values(text)
  year_row <- documented_year_axis_index(text, margin = 1L)
  if (is.na(year_row)) return(documented_empty_observations())
  quarter_scores <- rowSums(!is.na(documented_quarter_number(text)))
  nearby <- intersect(seq.int(year_row + 1L, min(nrow(text), year_row + 4L)), seq_len(nrow(text)))
  if (!length(nearby)) return(documented_empty_observations())
  quarter_row <- nearby[[which.max(quarter_scores[nearby])]]
  raw_year_values <- years[year_row, ]
  year_values <- raw_year_values
  first_year_col <- min(which(!is.na(year_values)))
  for (j in seq.int(first_year_col, ncol(text))) {
    if (j > first_year_col && is.na(year_values[[j]])) year_values[[j]] <- year_values[[j - 1L]]
  }
  period_labels <- text[quarter_row, ]
  quarter_values <- documented_contextual_quarters(period_labels, raw_year_values)
  annual_total <- stringr::str_detect(normalize_semantic_label(period_labels), "total|anual|ano") |
    !is.na(documented_year_values(period_labels))
  annual_total[is.na(annual_total)] <- FALSE
  year_starts <- which(!is.na(raw_year_values))
  for (ii in seq_along(year_starts)) {
    block_end <- if (ii < length(year_starts)) year_starts[[ii + 1L]] - 1L else ncol(text)
    if (block_end == year_starts[[ii]]) annual_total[year_starts[[ii]]] <- TRUE
  }
  annual_total[is.na(annual_total)] <- FALSE
  time_cols <- which(!is.na(year_values) & (!is.na(quarter_values) | annual_total))
  if (!length(time_cols)) return(documented_empty_observations())
  first_time_col <- min(time_cols)
  label_cols <- seq_len(first_time_col - 1L)
  metadata_rows <- if (year_row > 1L) seq_len(year_row - 1L) else integer()
  title <- documented_table_title(text, metadata_rows)
  row_density <- rowSums(!is.na(numbers[, time_cols, drop = FALSE]))
  data_rows <- which(seq_len(nrow(text)) > quarter_row & row_density > 0L &
                       rowSums(!documented_blank(text[, label_cols, drop = FALSE])) > 0L)
  if (!length(data_rows)) return(documented_empty_observations())
  data_start <- min(data_rows)
  subheader_rows <- if (data_start > quarter_row + 1L) {
    seq.int(quarter_row + 1L, data_start - 1L)
  } else integer()
  subheaders <- documented_fill_right(text)
  column_labels <- vapply(time_cols, function(j) {
    label <- documented_compact_path(subheaders[subheader_rows, j])
    # Time tokens do not distinguish an economic series. Keep only genuine
    # subheaders (sector, currency, measure, etc.) in the identity path.
    normalized <- normalize_semantic_label(label)
    if (!nzchar(label) || !is.na(documented_month_number(normalized)) ||
        !is.na(documented_quarter_number(normalized)) ||
        !is.na(documented_year_values(normalized))) "" else label
  }, character(1))
  records <- vector("list", length(data_rows) * length(time_cols)); k <- 0L; label_state <- rep(NA_character_, length(label_cols))
  for (r in data_rows) {
    current <- text[r, label_cols]
    update <- !documented_blank(current)
    label_state[update] <- current[update]
    row_label <- documented_compact_path(label_state)
    if (!nzchar(row_label)) next
    for (jj in seq_along(time_cols)) {
      j <- time_cols[[jj]]
      value <- numbers[r, j]
      if (is.na(value)) next
      if (!is.na(quarter_values[[j]])) {
        frequency <- "quarterly"; period <- quarter_end(year_values[[j]], quarter_values[[j]])
      } else {
        frequency <- "annual"; period <- as.Date(paste0(year_values[[j]], "-12-31"))
      }
      measure <- column_labels[[jj]]
      series_label <- documented_compact_path(c(row_label, measure))
      k <- k + 1L
      records[[k]] <- documented_record(
        source_sheet, title, "horizontal_year_quarter", period,
        paste(year_values[[j]], period_labels[[j]]), frequency, series_label,
        row_label, if (nzchar(measure)) measure else period_labels[[j]], value, r, j
      )
    }
  }
  documented_bind_records(records)
}

documented_extract_horizontal_year_month <- function(text, numbers, source_sheet, year_axis_minimum = NA_integer_) {
  years <- documented_year_values(text)
  # Most horizontal_year_month tables are genuine multi-year grids, where
  # requiring several ordered years protects against a lone stray value
  # masquerading as a time axis (see AUDITORIA_REGRESIONES.md R27). A few
  # published tables are reviewed single-year exceptions (e.g. CUADRO 57a);
  # those opt into a lower floor explicitly via sheet_modes.csv rather than
  # loosening the general guard for every sheet in this mode.
  axis_minimum <- if (!is.na(year_axis_minimum)) year_axis_minimum else 3L
  year_row <- documented_year_axis_index(text, margin = 1L, minimum = axis_minimum)
  if (is.na(year_row)) return(documented_empty_observations())
  year_cols <- which(!is.na(years[year_row, ]))
  if (!length(year_cols)) return(documented_empty_observations())
  month_values <- documented_month_number(text)
  month_col <- which.max(colSums(!is.na(month_values)))
  month_rows <- which(!is.na(month_values[, month_col]))
  if (!length(month_rows)) return(documented_empty_observations())
  metadata_rows <- if (min(year_row, min(month_rows)) > 1L) seq_len(min(year_row, min(month_rows)) - 1L) else integer()
  title <- documented_table_title(text, metadata_rows)
  series_label <- ifelse(is.na(title), source_sheet, title)
  source_rows <- rep(month_rows, each = length(year_cols))
  source_columns <- rep(year_cols, times = length(month_rows))
  values <- numbers[cbind(source_rows, source_columns)]
  keep <- !is.na(values)
  if (!any(keep)) return(documented_empty_observations())
  source_rows <- source_rows[keep]; source_columns <- source_columns[keep]; values <- values[keep]
  year <- years[cbind(rep(year_row, length(source_columns)), source_columns)]
  month <- month_values[cbind(source_rows, rep(month_col, length(source_rows)))]
  period <- as.Date(vapply(seq_along(year), function(i) {
    as.character(month_end(year[[i]], month[[i]]))
  }, character(1)))
  tibble::tibble(
    source_sheet = source_sheet, table_title = title, parser_mode = "horizontal_year_month",
    period = period, source_period_label = paste(year, text[cbind(source_rows, rep(month_col, length(source_rows)))]),
    frequency = "monthly", series_label = series_label, series_path = series_label,
    category = series_label, measure = "value", question = NA_character_, response = NA_character_,
    entity_id = NA_character_, exchange_item_id = NA_character_, participant_id = NA_character_,
    unit = NA_character_, scale = NA_character_, currency = NA_character_, index_base = NA_character_,
    value = as.numeric(values), is_total = NA, source_row = as.integer(source_rows),
    source_column = as.integer(source_columns)
  )
}

documented_extract_generic_sheet <- function(raw, source_sheet, mode_override = NA_character_,
                                             hierarchy_status = "unresolved", year_axis_minimum = NA_integer_) {
  text <- documented_text_matrix(raw)
  numbers <- documented_number_matrix(raw)
  dates <- documented_date_matrix(raw, text)
  mode <- if (!is.na(mode_override) && nzchar(mode_override)) mode_override else documented_mode(text, dates)
  observations <- switch(
    mode,
    vertical_date = documented_extract_vertical_date(text, numbers, dates, source_sheet),
    horizontal_date = documented_extract_horizontal_time(text, numbers, dates, source_sheet, mode),
    horizontal_year = documented_extract_horizontal_time(text, numbers, dates, source_sheet, mode),
    vertical_block = documented_extract_vertical_block(text, numbers, source_sheet, mode),
    vertical_year = documented_extract_vertical_block(text, numbers, source_sheet, mode),
    horizontal_year_quarter = documented_extract_horizontal_year_quarter(text, numbers, source_sheet),
    horizontal_year_month = documented_extract_horizontal_year_month(text, numbers, source_sheet, year_axis_minimum = year_axis_minimum),
    documented_empty_observations()
  )
  list(
    observations = observations, mode = mode,
    hierarchy_status = hierarchy_status,
    raw_nonempty_cells = sum(!documented_blank(text)),
    title = if (nrow(observations)) observations$table_title[[1]] else documented_table_title(text, seq_len(min(12L, nrow(text))))
  )
}

.documented_config_cache <- new.env(parent = emptyenv())

documented_cached_config <- function(path, reader) {
  if (!file.exists(path)) return(NULL)
  info <- file.info(path)
  signature <- paste(info$size[[1]], as.numeric(info$mtime[[1]]), sep = "|")
  key <- normalizePath(path, winslash = "/", mustWork = TRUE)
  cached <- if (exists(key, envir = .documented_config_cache, inherits = FALSE)) {
    get(key, envir = .documented_config_cache, inherits = FALSE)
  } else NULL
  if (is.null(cached) || !identical(cached$signature, signature)) {
    cached <- list(signature = signature, data = reader(path))
    assign(key, cached, envir = .documented_config_cache)
  }
  cached$data
}

documented_sheet_modes <- function(root) {
  path <- file.path(root, "config", "sheet_modes.csv")
  documented_cached_config(path, function(config_path) readr::read_csv(
    config_path, show_col_types = FALSE,
    col_types = readr::cols(.default = readr::col_character())
  ))
}

documented_source_contracts <- function(root) {
  path <- file.path(root, "config", "documented_source_contracts.csv")
  documented_cached_config(path, function(config_path) readr::read_csv(
    config_path, show_col_types = FALSE
  ))
}

documented_sheet_rule <- function(root, source_id, source_sheet) {
  path <- file.path(root, "config", "sheet_modes.csv")
  empty_rule <- list(
    parser_mode_override = NA_character_, hierarchy_status = "unresolved",
    note = NA_character_, year_axis_minimum = NA_integer_
  )
  if (!file.exists(path)) return(empty_rule)
  rules <- documented_sheet_modes(root)
  exact <- rules %>% dplyr::filter(.data$source_id == .env$source_id, .data$source_sheet == .env$source_sheet)
  fallback <- rules %>% dplyr::filter(.data$source_id == .env$source_id, .data$source_sheet == "*")
  rule <- if (nrow(exact)) exact[1, ] else if (nrow(fallback)) fallback[1, ] else tibble::tibble()
  if (!nrow(rule)) return(empty_rule)
  year_axis_minimum <- if ("year_axis_minimum" %in% names(rule)) {
    suppressWarnings(as.integer(dplyr::na_if(rule$year_axis_minimum[[1]], "")))
  } else NA_integer_
  list(
    parser_mode_override = dplyr::na_if(rule$parser_mode_override[[1]], ""),
    hierarchy_status = dplyr::coalesce(dplyr::na_if(rule$hierarchy_status[[1]], ""), "unresolved"),
    note = dplyr::na_if(rule$note[[1]], ""),
    year_axis_minimum = year_axis_minimum
  )
}

documented_participant_type <- function(name) {
  key <- normalize_semantic_label(name)
  dplyr::case_when(
    stringr::str_detect(key, "^banco|bank") ~ "bank",
    stringr::str_detect(key, "financiera") ~ "finance_company",
    stringr::str_detect(key, "ministerio") ~ "government",
    stringr::str_detect(key, "agencia financiera") ~ "development_agency",
    TRUE ~ "other_participant"
  )
}

documented_load_payment_participants <- function(con, raw, item) {
  text <- documented_text_matrix(raw)
  if (ncol(text) < 4L) stop("Payment participant guard: BIC reference sheet has fewer than four columns.", call. = FALSE)
  rows <- which(stringr::str_detect(trimws(text[, 2]), "^[A-Z0-9]{8,12}$") & !documented_blank(text[, 4]))
  if (!length(rows)) stop("Payment participant guard: no BIC reference rows found.", call. = FALSE)
  data <- tibble::tibble(
    participant_id = paste0("payment_participant:", text[rows, 2]),
    bic_code = text[rows, 2], legal_name = text[rows, 4],
    participant_type = documented_participant_type(text[rows, 4]),
    first_vintage_id = item$vintage_id
  ) %>% dplyr::distinct(.data$participant_id, .keep_all = TRUE)
  replace_dimension_rows(con, "dim_payment_participant", data, "participant_id")
  data
}

documented_attach_payment_participants <- function(observations, participants) {
  if (!nrow(observations) || !nrow(participants)) return(observations)
  lookup <- observations %>% dplyr::distinct(.data$series_path)
  lookup$participant_id_matched <- vapply(lookup$series_path, function(path) {
    hit <- participants$bic_code[vapply(participants$bic_code, function(code) {
      stringr::str_detect(path, stringr::fixed(code))
    }, logical(1))]
    if (length(hit) == 1L) paste0("payment_participant:", hit[[1]]) else NA_character_
  }, character(1))
  observations %>%
    dplyr::left_join(lookup, by = "series_path", na_matches = "na") %>%
    dplyr::mutate(participant_id = dplyr::coalesce(.data$participant_id, .data$participant_id_matched)) %>%
    dplyr::select(-dplyr::all_of("participant_id_matched"))
}

documented_finalize_observations <- function(observations, item, release_id, publication_date) {
  if (!nrow(observations)) return(observations)
  observations <- observations %>%
    dplyr::filter(!is.na(.data$period), !is.na(.data$value), nzchar(.data$series_path)) %>%
    dplyr::mutate(
      identity_path = dplyr::if_else(
        !is.na(.data$exchange_item_id) & !is.na(.data$entity_id),
        paste(.data$exchange_item_id, .data$entity_id, sep = "|"), .data$series_path
      ),
      collision_key = paste(.data$source_sheet, .data$frequency, .data$identity_path, sep = "|"),
      structural_slot = dplyr::case_when(
        .data$parser_mode %in% c("horizontal_date", "horizontal_year", "horizontal_year_quarter") ~ paste0("row_", .data$source_row),
        TRUE ~ paste0("column_", .data$source_column)
      ),
      .row_order = dplyr::row_number()
    )
  collisions <- observations %>%
    dplyr::count(.data$collision_key, .data$period, name = "n") %>%
    dplyr::filter(.data$n > 1L) %>% dplyr::pull(.data$collision_key) %>% unique()
  observations <- observations %>%
    dplyr::mutate(
      axis_required = .data$collision_key %in% collisions,
      axis_path = dplyr::if_else(
        .data$axis_required,
        paste(.data$identity_path, .data$structural_slot, sep = " — "),
        .data$identity_path
      ),
      axis_collision_key = paste(.data$source_sheet, .data$frequency, .data$axis_path, sep = "|")
    )
  axis_collisions <- observations %>%
    dplyr::count(.data$axis_collision_key, .data$period, name = "n") %>%
    dplyr::filter(.data$n > 1L) %>%
    dplyr::pull(.data$axis_collision_key) %>%
    unique()
  observations <- observations %>%
    dplyr::arrange(.data$axis_collision_key, .data$period, .data$source_row, .data$source_column, .data$.row_order) %>%
    dplyr::group_by(.data$axis_collision_key, .data$period) %>%
    dplyr::mutate(collision_lane = dplyr::row_number()) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(
      lane_required = .data$axis_collision_key %in% axis_collisions,
      identity_stability = dplyr::case_when(
        .data$lane_required ~ "positional_lane",
        stringr::str_detect(.data$parser_mode, "positional_lane") ~ "positional_lane",
        stringr::str_detect(.data$parser_mode, "row_event_semantic") ~ "semantic_event",
        .data$axis_required ~ "positional",
        TRUE ~ "semantic"
      ),
      stable_path = dplyr::case_when(
        .data$lane_required ~ paste(.data$axis_path, paste0("lane_", .data$collision_lane), sep = " — "),
        TRUE ~ .data$axis_path
      )
    ) %>%
    dplyr::arrange(.data$.row_order)
  # A series identity repeats for every period. Hash each distinct identity
  # once, then join it back; this is byte-for-byte equivalent to the former
  # per-observation vapply() while avoiding hundreds of thousands of digests.
  identity_lookup <- observations %>%
    dplyr::distinct(.data$source_sheet, .data$frequency, .data$stable_path) %>%
    dplyr::mutate(
      identity_basis = paste(.data$source_sheet, .data$frequency, .data$stable_path, sep = "|"),
      series_hash = substr(vapply(
        paste(.data$stable_path, .data$frequency, sep = "|"), digest::digest,
        character(1), algo = "sha256", serialize = FALSE
      ), 1L, 24L),
      series_id = paste0(
        item$source_id, ":", janitor::make_clean_names(.data$source_sheet), ":", .data$series_hash
      )
    ) %>%
    dplyr::select(-dplyr::all_of("series_hash"))
  observations <- observations %>%
    dplyr::left_join(
      identity_lookup,
      by = c("source_sheet", "frequency", "stable_path"),
      na_matches = "na"
    ) %>%
    dplyr::arrange(.data$.row_order) %>%
    dplyr::mutate(
      vintage_id = item$vintage_id, release_id = release_id,
      publication_date = as.Date(publication_date), source_id = item$source_id,
      source_file = item$source_file, .before = 1
    ) %>%
    dplyr::select(-dplyr::all_of(c(
      "identity_path", "collision_key", "structural_slot", "axis_required", "axis_path",
      "axis_collision_key", "collision_lane", "lane_required", "stable_path", ".row_order"
    )))
  duplicate <- observations %>% dplyr::count(.data$series_id, .data$period) %>% dplyr::filter(.data$n > 1L)
  if (nrow(duplicate)) stop(
    "Documented-series key guard: ", nrow(duplicate),
    " duplicate series-period keys remain for ", item$source_id, ".", call. = FALSE
  )
  expected <- c(
    "vintage_id", "release_id", "publication_date", "source_id", "source_file", "source_sheet",
    "table_title", "parser_mode", "series_id", "identity_basis", "identity_stability", "hierarchy_status",
    "period", "source_period_label", "frequency", "series_label", "series_path", "category", "measure",
    "question", "response", "entity_id", "exchange_item_id", "participant_id", "unit", "scale", "currency",
    "index_base", "value", "is_total", "source_row", "source_column"
  )
  missing <- setdiff(expected, names(observations))
  if (length(missing)) stop("Documented snapshot contract missing field(s): ", paste(missing, collapse = ", "), call. = FALSE)
  observations %>% dplyr::select(dplyr::all_of(expected))
}

documented_catalog_row <- function(item, source_sheet, result, parse_status = NULL, note = NULL) {
  observations <- result$observations
  status <- documented_or(parse_status, if (nrow(observations)) "documented_series" else "unparsed")
  tibble::tibble(
    vintage_id = item$vintage_id, source_id = item$source_id, source_sheet = source_sheet,
    table_title = result$title, parser_mode = result$mode, parse_status = status,
    hierarchy_status = documented_or(result$hierarchy_status, "unresolved"),
    raw_nonempty_cells = as.integer(result$raw_nonempty_cells),
    parsed_observations = as.integer(nrow(observations)),
    series_count = as.integer(dplyr::n_distinct(observations$series_id)),
    first_period = if (nrow(observations)) min(observations$period) else as.Date(NA),
    last_period = if (nrow(observations)) max(observations$period) else as.Date(NA),
    unit_summary = if (nrow(observations)) paste(sort(unique(observations$unit)), collapse = "|") else NA_character_,
    coverage_note = documented_or(note, if (nrow(observations))
      "Periods, labels, units and values extracted under a documented orientation contract."
    else "No statistical observations claimed for this worksheet.")
  )
}

documented_validate_contract <- function(root, source_id, dimensions, catalog, observations) {
  contracts <- documented_source_contracts(root)
  contract <- contracts %>% dplyr::filter(.data$source_id == .env$source_id)
  if (nrow(contract) != 1L) stop("Documented-source contract missing for ", source_id, ".", call. = FALSE)
  required <- strsplit(contract$required_sheets[[1]], "|", fixed = TRUE)[[1]]
  missing <- setdiff(required, dimensions$sheet_name)
  if (length(missing)) stop("Documented-source guard: missing required sheets for ", source_id,
                            ": ", paste(missing, collapse = ", "), call. = FALSE)
  if (nrow(dimensions) < contract$minimum_sheet_count[[1]]) stop(
    "Documented-source guard: ", source_id, " has ", nrow(dimensions), " sheets; expected at least ",
    contract$minimum_sheet_count[[1]], ".", call. = FALSE
  )
  parsed <- sum(catalog$parse_status == "documented_series")
  if (parsed < contract$minimum_parsed_sheets[[1]]) stop(
    "Documented-source guard: ", source_id, " parsed ", parsed, " sheets; expected at least ",
    contract$minimum_parsed_sheets[[1]], ".", call. = FALSE
  )
  if (nrow(observations) < contract$minimum_observations[[1]]) stop(
    "Documented-source guard: ", source_id, " produced ", nrow(observations),
    " observations; expected at least ", contract$minimum_observations[[1]], ".", call. = FALSE
  )
  assert_plausible_dates(
    observations$period, source_id, "<documented-series layer>",
    minimum = as.Date(contract$minimum_date[[1]]),
    maximum = Sys.Date() + as.integer(contract$maximum_future_days[[1]])
  )
  invisible(TRUE)
}

documented_credit_periods <- function(text) {
  years <- documented_year_values(text)
  year_scores <- documented_year_axis_counts(years, margin = 1L, minimum = 2L)
  quarter_scores <- rowSums(!is.na(documented_quarter_number(text)))
  if (max(year_scores) < 2L || max(quarter_scores) < 2L) stop(
    "Credit-survey structure guard: repeated year and quarter headers were not found.", call. = FALSE
  )
  year_row <- documented_year_axis_index(text, margin = 1L, minimum = 2L)
  quarter_row <- which.max(quarter_scores)
  year_values <- years[year_row, ]
  first_year_col <- min(which(!is.na(year_values)))
  for (j in seq.int(first_year_col, ncol(text))) {
    if (j > first_year_col && is.na(year_values[[j]])) year_values[[j]] <- year_values[[j - 1L]]
  }
  quarters <- documented_quarter_number(text[quarter_row, ])
  valid <- which(!is.na(year_values) & !is.na(quarters))
  list(
    columns = valid, years = year_values, quarters = quarters,
    periods = as.Date(vapply(valid, function(j) as.character(quarter_end(year_values[[j]], quarters[[j]])), character(1))),
    year_row = year_row, quarter_row = quarter_row
  )
}

documented_parse_credit_sheet <- function(raw, source_sheet) {
  text <- documented_text_matrix(raw); numbers <- documented_number_matrix(raw)
  layout <- documented_credit_periods(text); title <- documented_table_title(text, 1L)
  records <- list(); k <- 0L
  if (source_sheet == "%") {
    question <- NA_character_
    for (r in seq.int(layout$quarter_row + 1L, nrow(text))) {
      label <- stringr::str_squish(text[r, 1])
      values <- numbers[r, layout$columns]
      if (!documented_blank(label) && all(is.na(values)) && stringr::str_detect(
        label, "^[0-9]+(?:[.,][0-9]+)*\\s*[-.)]"
      )) {
        question <- label; next
      }
      if (is.na(question) || documented_blank(label) || all(is.na(values))) next
      for (jj in seq_along(layout$columns)) {
        value <- values[[jj]]; if (is.na(value)) next
        j <- layout$columns[[jj]]; path <- documented_compact_path(c(question, label))
        k <- k + 1L
        records[[k]] <- tibble::tibble(
          source_sheet = source_sheet, table_title = title, parser_mode = "credit_question_quarter",
          period = layout$periods[[jj]], source_period_label = paste(layout$years[[j]], text[layout$quarter_row, j]),
          frequency = "quarterly", series_label = path, series_path = path,
          category = "credit_survey_responses", measure = "response_share", question = question,
          response = label, entity_id = NA_character_, exchange_item_id = NA_character_, participant_id = NA_character_,
          unit = "proportion", scale = "units", currency = NA_character_, index_base = NA_character_,
          value = as.numeric(value), is_total = FALSE, source_row = r, source_column = j
        )
      }
    }
  } else {
    category <- "General"
    for (r in seq.int(layout$quarter_row + 1L, nrow(text))) {
      label <- stringr::str_squish(text[r, 1]); values <- numbers[r, layout$columns]
      if (documented_blank(label)) next
      if (all(is.na(values))) { category <- label; next }
      for (jj in seq_along(layout$columns)) {
        value <- values[[jj]]; if (is.na(value)) next
        j <- layout$columns[[jj]]; path <- documented_compact_path(c(category, label))
        k <- k + 1L
        records[[k]] <- tibble::tibble(
          source_sheet = source_sheet, table_title = title, parser_mode = "credit_index_quarter",
          period = layout$periods[[jj]], source_period_label = paste(layout$years[[j]], text[layout$quarter_row, j]),
          frequency = "quarterly", series_label = path, series_path = path,
          category = category, measure = label, question = NA_character_, response = NA_character_,
          entity_id = NA_character_, exchange_item_id = NA_character_, participant_id = NA_character_, unit = "index_points",
          scale = "units", currency = NA_character_, index_base = NA_character_, value = as.numeric(value),
          is_total = normalize_semantic_label(category) == "general", source_row = r, source_column = j
        )
      }
    }
  }
  observations <- if (length(records)) dplyr::bind_rows(records) else documented_empty_observations()
  mode <- if (nrow(observations)) unique(observations$parser_mode)[[1]] else "unparsed_credit_layout"
  list(observations = observations, mode = mode,
       raw_nonempty_cells = sum(!documented_blank(text)), title = title)
}

documented_load_exchange_references <- function(con, raw, item) {
  text <- documented_text_matrix(raw)
  if (ncol(text) < 21L) stop("Exchange-house reference guard: expected at least 21 columns.", call. = FALSE)
  entity_rows <- which(stringr::str_detect(trimws(text[, 15]), "^[0-9]{4}$") & !documented_blank(text[, 16]))
  if (!length(entity_rows)) stop("Exchange-house reference guard: entity table not found.", call. = FALSE)
  entities <- tibble::tibble(
    entity_id = paste0("exchange_house:", text[entity_rows, 15]), entity_code = text[entity_rows, 15],
    entity_type = "exchange_house", entity_name = text[entity_rows, 17], legal_name = text[entity_rows, 16],
    short_name = text[entity_rows, 17], ownership_type = NA_character_,
    mapping_status = "verified_exchange_reference", first_vintage_id = item$vintage_id
  ) %>% dplyr::distinct(.data$entity_id, .keep_all = TRUE)
  replace_dimension_rows(con, "dim_entity", entities, "entity_id")
  currency_rows <- which(!documented_blank(text[, 19]) & !documented_blank(text[, 20]) &
                           seq_len(nrow(text)) > 14L)
  currency_rows <- currency_rows[stringr::str_detect(text[currency_rows, 19], "^[0-9+ ]+$")]
  currencies <- tibble::tibble(
    currency_code = stringr::str_squish(text[currency_rows, 19]),
    currency_label = text[currency_rows, 20],
    currency_of_origin = dplyr::case_when(
      currency_code == "6900" ~ "PYG", currency_code %in% c("6100", "6200") ~ "FX",
      stringr::str_detect(currency_code, "6200.*6900") ~ "MIXED", TRUE ~ NA_character_
    ),
    unit_currency = dplyr::case_when(
      currency_code %in% c("6900", "6200") ~ "PYG", currency_code == "6100" ~ "USD",
      stringr::str_detect(currency_code, "6200.*6900") ~ "PYG", TRUE ~ NA_character_
    ),
    economic_currency = unit_currency, description = text[currency_rows, 21],
    mapping_status = "verified_exchange_reference", first_vintage_id = item$vintage_id
  ) %>% dplyr::distinct(.data$currency_code, .keep_all = TRUE)
  replace_dimension_rows(con, "dim_currency", currencies, "currency_code")
  list(entities = entities, currencies = currencies)
}

documented_parse_exchange_panel <- function(raw, source_sheet, statement_type, entities) {
  text <- documented_text_matrix(raw); numbers <- documented_number_matrix(raw)
  dates <- documented_date_matrix(raw, text)
  normalized_text <- matrix(normalize_semantic_label(text), nrow = nrow(text), ncol = ncol(text))
  header_hits <- which(normalized_text == "fecha", arr.ind = TRUE)
  if (nrow(header_hits) != 1L) stop("Exchange-house guard: expected one Fecha header in ", source_sheet, ".", call. = FALSE)
  header_row <- header_hits[[1, "row"]]; date_col <- header_hits[[1, "col"]]
  date_rows <- which(!is.na(dates[, date_col]) & seq_len(nrow(text)) > header_row)
  if (!length(date_rows)) stop("Exchange-house guard: no typed dates below Fecha in ", source_sheet, ".", call. = FALSE)
  data_start <- min(date_rows)
  data_rows <- seq.int(data_start, nrow(text))
  period <- as.Date(as.numeric(dates[, date_col]), origin = "1970-01-01")
  if (length(period) != nrow(text)) stop(
    "Exchange-house guard: date vector does not match worksheet rows in ", source_sheet, ".",
    call. = FALSE
  )
  for (r in data_rows) if (r > data_start && is.na(period[r])) period[r] <- period[r - 1L]
  candidate_cols <- seq.int(date_col + 1L, ncol(text))
  numeric_density <- colSums(!is.na(numbers[data_rows, candidate_cols, drop = FALSE]))
  data_cols <- candidate_cols[numeric_density > 0L]
  if (!length(data_cols)) stop("Exchange-house guard: no numeric entity columns in ", source_sheet, ".", call. = FALSE)
  first_data_col <- min(data_cols)
  label_cols <- if (first_data_col > date_col + 1L) seq.int(date_col + 1L, first_data_col - 1L) else integer()
  entity_labels <- text[header_row, data_cols]
  if (header_row > 1L) {
    missing_header <- documented_blank(entity_labels)
    entity_labels[missing_header] <- text[header_row - 1L, data_cols[missing_header]]
  }
  entity_lookup <- stats::setNames(entities$entity_id, normalize_semantic_label(entities$short_name))
  entity_ids <- unname(entity_lookup[normalize_semantic_label(entity_labels)])
  entity_ids[normalize_semantic_label(entity_labels) %in% c("sistema", "total sistema", "1 total sistema")] <- "exchange_house:3000"
  for (jj in which(is.na(entity_ids))) {
    key <- normalize_semantic_label(entity_labels[[jj]])
    candidate <- entities$entity_id[
      stringr::str_detect(normalize_semantic_label(entities$legal_name), stringr::fixed(key)) |
        stringr::str_starts(normalize_semantic_label(entities$short_name), stringr::fixed(key))
    ]
    if (length(candidate) == 1L) entity_ids[[jj]] <- candidate[[1]]
  }
  title <- documented_table_title(text, seq_len(max(1L, header_row - 1L)))
  records <- list(); k <- 0L; label_state <- rep(NA_character_, length(label_cols))
  for (r in data_rows) {
    if (length(label_cols)) {
      current <- text[r, label_cols]; update <- !documented_blank(current); label_state[update] <- current[update]
      item_label <- documented_compact_path(label_state)
    } else item_label <- "value"
    if (!nzchar(item_label) || is.na(period[r])) next
    for (jj in seq_along(data_cols)) {
      j <- data_cols[[jj]]; value <- numbers[r, j]; if (is.na(value)) next
      entity_label <- entity_labels[[jj]]
      path <- documented_compact_path(c(item_label, entity_label))
      k <- k + 1L
      records[[k]] <- list(
        source_sheet = source_sheet, table_title = title, parser_mode = paste0("exchange_", statement_type),
        period = period[r], source_period_label = as.character(period[r]),
        frequency = if (statement_type == "balance_sheet") "annual" else "monthly",
        series_label = path, series_path = path, category = statement_type, measure = item_label,
        question = NA_character_, response = NA_character_, entity_id = entity_ids[[jj]],
        exchange_item_id = NA_character_, participant_id = NA_character_,
        unit = dplyr::case_when(
          statement_type == "balance_sheet" ~ "PYG",
          statement_type == "ratio" && stringr::str_detect(item_label, "%") ~ "proportion",
          statement_type == "operations" ~ "count",
          TRUE ~ NA_character_
        ),
        scale = if (statement_type %in% c("balance_sheet", "operations") ||
                    (statement_type == "ratio" && stringr::str_detect(item_label, "%"))) "units" else NA_character_,
        currency = if (statement_type == "balance_sheet") "PYG" else NA_character_,
        index_base = NA_character_, value = as.numeric(value), is_total = normalize_semantic_label(entity_label) == "sistema",
        source_row = r, source_column = j
      )
    }
  }
  observations <- documented_bind_records(records)
  if (nrow(observations)) {
    item_ids <- observations %>%
      dplyr::distinct(.data$category, .data$measure) %>%
      dplyr::mutate(exchange_item_id = paste0(
        "exchange_item:", substr(vapply(
          paste(.data$category, .data$measure, sep = "|"), digest::digest,
          character(1), algo = "sha256", serialize = FALSE
        ), 1L, 24L)
      ))
    observations <- observations %>%
      dplyr::select(-dplyr::all_of("exchange_item_id")) %>%
      dplyr::left_join(item_ids, by = c("category", "measure"), na_matches = "na")
    observations <- documented_enrich_metadata(observations, observations$measure)
  }
  list(observations = observations, mode = paste0("exchange_", statement_type),
       raw_nonempty_cells = sum(!documented_blank(text)), title = title)
}

documented_skipped_result <- function(raw, mode, title = NA_character_) {
  text <- documented_text_matrix(raw)
  list(observations = documented_empty_observations(), mode = mode, hierarchy_status = "not_applicable",
       raw_nonempty_cells = sum(!documented_blank(text)),
       title = ifelse(is.na(title), documented_table_title(text, seq_len(min(12L, nrow(text)))), title))
}

documented_create_views <- function(con) {
  DBI::dbExecute(con, paste0(
    "CREATE OR REPLACE VIEW v_documented_series_latest_snapshot AS ",
    "SELECT * EXCLUDE(vintage_rank, source_ingested_at) FROM (SELECT d.*, ",
    "f.first_ingested_at AS source_ingested_at, dense_rank() OVER (PARTITION BY d.source_id ",
    "ORDER BY d.publication_date DESC NULLS LAST, f.first_ingested_at DESC NULLS LAST, d.vintage_id DESC) AS vintage_rank ",
    "FROM documented_series_snapshot d LEFT JOIN source_files f USING (vintage_id)) WHERE vintage_rank = 1"
  ))
  DBI::dbExecute(con, "CREATE OR REPLACE VIEW v_economic_annex_latest AS SELECT * FROM v_documented_series_latest_snapshot WHERE source_id = 'economic_annex'")
  DBI::dbExecute(con, paste0(
    "CREATE OR REPLACE VIEW v_payments_latest AS SELECT d.*, p.bic_code, p.legal_name AS participant_name, ",
    "p.participant_type FROM v_documented_series_latest_snapshot d LEFT JOIN dim_payment_participant p ",
    "USING (participant_id) WHERE d.source_id = 'payments'"
  ))
  DBI::dbExecute(con, paste0(
    "CREATE OR REPLACE VIEW v_exchange_houses_latest AS SELECT d.*, e.entity_code, e.legal_name, ",
    "e.short_name, x.classification AS item_classification, x.item_label_normalized ",
    "FROM v_documented_series_latest_snapshot d LEFT JOIN dim_entity e USING (entity_id) ",
    "LEFT JOIN dim_exchange_item x USING (exchange_item_id) ",
    "WHERE d.source_id = 'exchange_houses'"
  ))
  DBI::dbExecute(con, "CREATE OR REPLACE VIEW v_credit_survey_latest AS SELECT * FROM v_documented_series_latest_snapshot WHERE source_id = 'credit_survey'")
  DBI::dbExecute(con, paste0(
    "CREATE OR REPLACE VIEW v_documented_series_catalogue AS SELECT series_id, source_id, source_sheet, ",
    "any_value(series_label) AS series_label, any_value(unit) AS unit, any_value(scale) AS scale, ",
    "any_value(currency) AS currency, any_value(frequency) AS frequency, ",
    "any_value(identity_stability) AS identity_stability, any_value(hierarchy_status) AS hierarchy_status, min(period) AS first_period, ",
    "max(period) AS last_period, count(*) AS observations FROM v_documented_series_latest_snapshot GROUP BY 1,2,3"
  ))
  invisible(TRUE)
}

documented_source_parser <- function(con, item, dimensions, release_id, root, publication_date) {
  source_id <- item$source_id
  supported <- documented_source_contracts(root)$source_id
  if (!source_id %in% supported) {
    stop("No documented-table parser registered for ", source_id, ".", call. = FALSE)
  }
  results <- list(); result_status <- list(); result_note <- list()
  payment_participants <- tibble::tibble()
  exchange_entities <- tibble::tibble()

  read_source_sheet <- function(sheet) {
    dims <- dimensions %>% dplyr::filter(.data$sheet_name == .env$sheet)
    if (nrow(dims) != 1L) stop("Documented-source guard: sheet not found exactly once: ", sheet, call. = FALSE)
    raw <- read_dimensioned_sheet(item$path, dims)
    # Reuse this single Excel read for the content-addressed raw layer. The
    # submatrix preserves the exact cropped coordinate convention used by the
    # previous raw-ingestion path, while parsers retain A1-based coordinates.
    empty_inventory <- !nrow(raw) || !ncol(raw) ||
      dims$content_last_row[[1]] < dims$content_first_row[[1]] ||
      dims$content_last_col[[1]] < dims$content_first_col[[1]]
    if (empty_inventory) {
      inventory_raw <- tibble::new_tibble(list(), nrow = 0L)
    } else {
      inventory_rows <- seq.int(dims$content_first_row[[1]], dims$content_last_row[[1]])
      inventory_cols <- seq.int(dims$content_first_col[[1]], dims$content_last_col[[1]])
      inventory_raw <- raw[inventory_rows, inventory_cols, drop = FALSE]
    }
    ingest_report_sheet_data(
      con, item, sheet, inventory_raw, publication_date, release_id,
      write_inventory_coverage = FALSE
    )
    raw
  }

  if (source_id == "economic_annex") {
    for (sheet in dimensions$sheet_name) {
      raw <- read_source_sheet(sheet)
      if (normalize_semantic_label(sheet) == "indice") {
        results[[sheet]] <- documented_skipped_result(raw, "index_only")
        result_status[[sheet]] <- "index_only"
        result_note[[sheet]] <- "Workbook table of contents; retained as raw cells, not duplicated as observations."
      } else {
        rule <- documented_sheet_rule(root, source_id, sheet)
        results[[sheet]] <- documented_extract_generic_sheet(raw, sheet, rule$parser_mode_override, rule$hierarchy_status, rule$year_axis_minimum)
      }
    }
  }

  if (source_id == "payments") {
    bic_raw <- read_source_sheet("BIC E. Bancarias")
    payment_participants <- documented_load_payment_participants(con, bic_raw, item)
    for (sheet in dimensions$sheet_name) {
      raw <- if (sheet == "BIC E. Bancarias") bic_raw else read_source_sheet(sheet)
      if (sheet == "Indice") {
        results[[sheet]] <- documented_skipped_result(raw, "index_only")
        result_status[[sheet]] <- "index_only"
        result_note[[sheet]] <- "Workbook table of contents; retained as raw cells."
      } else if (sheet == "BIC E. Bancarias") {
        results[[sheet]] <- documented_skipped_result(raw, "reference_dimension")
        result_status[[sheet]] <- "reference_dimension"
        result_note[[sheet]] <- "BIC-to-institution reference loaded into dim_payment_participant."
      } else {
        rule <- documented_sheet_rule(root, source_id, sheet)
        results[[sheet]] <- documented_extract_generic_sheet(raw, sheet, rule$parser_mode_override, rule$hierarchy_status, rule$year_axis_minimum)
      }
    }
  }

  if (source_id == "exchange_houses") {
    ref_raw <- read_source_sheet("Tablas ref.")
    refs <- documented_load_exchange_references(con, ref_raw, item)
    exchange_entities <- refs$entities
    panel_types <- c("1. EEFF" = "balance_sheet", "2. Ratios" = "ratio", "3. Dep y Person" = "operations")
    for (sheet in dimensions$sheet_name) {
      raw <- if (sheet == "Tablas ref.") ref_raw else read_source_sheet(sheet)
      if (sheet %in% names(panel_types)) {
        results[[sheet]] <- documented_parse_exchange_panel(raw, sheet, panel_types[[sheet]], exchange_entities)
      } else if (sheet == "Tablas ref.") {
        results[[sheet]] <- documented_skipped_result(raw, "reference_dimension")
        result_status[[sheet]] <- "reference_dimension"
        result_note[[sheet]] <- "Verified exchange-house entity, currency and statement references loaded into dimensions."
      } else {
        mode <- if (sheet %in% c("1.1 BG", "1.2 EERR", "2.1 Ratios", "3.1 Dep y P.")) "linked_display_only" else "presentation_only"
        results[[sheet]] <- documented_skipped_result(raw, mode)
        result_status[[sheet]] <- mode
        result_note[[sheet]] <- "Presentation or linked display worksheet; authoritative observations come from the three source panels."
      }
    }
  }

  if (source_id == "credit_survey") for (sheet in dimensions$sheet_name) {
    results[[sheet]] <- documented_parse_credit_sheet(read_source_sheet(sheet), sheet)
  }

  if (source_id == "insurance_annex") for (sheet in dimensions$sheet_name) {
    raw <- read_source_sheet(sheet); rule <- documented_sheet_rule(root, source_id, sheet)
    if (identical(rule$parser_mode_override, "skip_metadata")) results[[sheet]] <- documented_skipped_result(raw, "metadata_only")
    else results[[sheet]] <- documented_parse_insurance_sheet(raw, sheet, rule$hierarchy_status)
  }

  if (source_id == "exchange_rates") for (sheet in dimensions$sheet_name) {
    raw <- read_source_sheet(sheet); rule <- documented_sheet_rule(root, source_id, sheet)
    if (sheet == "Cotizaciones Diarias") results[[sheet]] <- documented_parse_daily_exchange_rates(raw, sheet, item)
    else results[[sheet]] <- documented_parse_exchange_rate_history(raw, sheet)
  }

  if (source_id == "compensatory_fx_sales") for (sheet in dimensions$sheet_name) {
    results[[sheet]] <- documented_parse_compensatory_sales(read_source_sheet(sheet), sheet)
  }

  if (source_id == "liquidity_facility") for (sheet in dimensions$sheet_name) {
    results[[sheet]] <- documented_parse_row_events(
      read_source_sheet(sheet), sheet, "fecha de liquidacion",
      c("^plazos"),
      "short_term_liquidity_auction",
      block_patterns = c(deposito = "deposit", repo = "repo")
    )
  }

  if (source_id == "interbank_market") for (sheet in dimensions$sheet_name) {
    raw <- read_source_sheet(sheet); rule <- documented_sheet_rule(root, source_id, sheet)
    if (sheet == "Mdo Secundario") {
      results[[sheet]] <- documented_parse_row_events(
        raw, sheet, "fecha negociacion", c("^tipo de instrumento$", "^plazo residual"),
        "secondary_market_operation"
      )
    } else results[[sheet]] <- documented_extract_generic_sheet(
      raw, sheet, rule$parser_mode_override, rule$hierarchy_status, rule$year_axis_minimum
    )
  }

  if (source_id == "lrm_auctions") for (sheet in dimensions$sheet_name) {
    results[[sheet]] <- documented_parse_row_events(
      read_source_sheet(sheet), sheet, "fecha subasta",
      c("plazos estandarizados", "plazos residuales"),
      "lrm_auction_tenor"
    )
  }

  generic_sources <- c("direct_investment", "bcp_fx_daily",
                       "banking_indicators", "financial_indicators")
  if (source_id %in% generic_sources) for (sheet in dimensions$sheet_name) {
    raw <- read_source_sheet(sheet); rule <- documented_sheet_rule(root, source_id, sheet)
    if (identical(rule$parser_mode_override, "skip_metadata")) {
      results[[sheet]] <- documented_skipped_result(raw, "metadata_only")
    } else results[[sheet]] <- documented_extract_generic_sheet(
      raw, sheet, rule$parser_mode_override, rule$hierarchy_status, rule$year_axis_minimum
    )
  }

  for (sheet in names(results)) {
    rule <- documented_sheet_rule(root, source_id, sheet)
    if (is.null(results[[sheet]]$hierarchy_status)) results[[sheet]]$hierarchy_status <- rule$hierarchy_status
    results[[sheet]]$observations <- results[[sheet]]$observations %>%
      dplyr::mutate(hierarchy_status = results[[sheet]]$hierarchy_status)
  }
  observations <- dplyr::bind_rows(lapply(results, `[[`, "observations"))
  # The credit parser supplies an explicit semantic contract, including
  # intentional NA currency/index-base fields. All record-oriented parsers use
  # deferred inference; do not overwrite explicit NA semantics by guessing.
  if (!source_id %in% c("credit_survey", "exchange_houses")) {
    metadata_labels <- dplyr::if_else(
      stringr::str_detect(observations$parser_mode, "^row_event_"),
      observations$measure, observations$series_label
    )
    observations <- documented_enrich_metadata(observations, metadata_labels)
  }
  if (source_id == "payments") observations <- documented_attach_payment_participants(observations, payment_participants)
  if (is.na(publication_date) && nrow(observations)) {
    publication_date <- max(observations$period)
    set_source_publication_date(con, item$vintage_id, publication_date)
    update_archive_manifest_date(root, item$source_id, item$sha256, publication_date)
  }
  observations <- documented_finalize_observations(observations, item, release_id, publication_date)
  for (sheet in names(results)) results[[sheet]]$observations <- observations %>% dplyr::filter(.data$source_sheet == .env$sheet)
  catalog <- dplyr::bind_rows(lapply(names(results), function(sheet) documented_catalog_row(
    item, sheet, results[[sheet]], result_status[[sheet]], result_note[[sheet]]
  )))
  documented_validate_contract(root, source_id, dimensions, catalog, observations)

  for (table_name in c("documented_series_snapshot", "documented_table_catalog", "semantic_coverage")) {
    DBI::dbExecute(con, paste0("DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
                               " WHERE vintage_id = ", sql_string(item$vintage_id)))
  }
  if (nrow(observations)) DBI::dbWriteTable(con, "documented_series_snapshot", observations, append = TRUE)
  DBI::dbWriteTable(con, "documented_table_catalog", catalog, append = TRUE)
  coverage <- catalog %>% dplyr::transmute(
    vintage_id, source_id, source_sheet, semantic_status = parse_status,
    raw_nonempty_cells, curated_observations = parsed_observations, coverage_note
  )
  DBI::dbWriteTable(con, "semantic_coverage", coverage, append = TRUE)

  if (source_id == "exchange_houses") {
    items <- observations %>% dplyr::distinct(.data$exchange_item_id, .data$category, .data$measure) %>% dplyr::transmute(
      exchange_item_id,
      statement_type = .data$category, classification = .data$category,
      item_label = .data$measure, item_label_normalized = normalize_semantic_label(.data$measure),
      first_vintage_id = item$vintage_id
    )
    replace_dimension_rows(con, "dim_exchange_item", items, "exchange_item_id")
  }

  series_meta <- observations %>% dplyr::distinct(
    .data$series_id, .data$series_label, .data$unit, .data$scale, .data$frequency,
    .data$currency, .data$index_base, .data$is_total, .data$identity_basis,
    .data$identity_stability, .data$hierarchy_status
  ) %>% dplyr::transmute(
    series_id, source_id = item$source_id, label = series_label, unit, scale, frequency, currency,
    index_base, hierarchy_level = "documented_table_series", parent_series_id = NA_character_,
    is_total, identity_basis, identity_stability, hierarchy_status,
    semantic_status = "documented_series", first_vintage_id = item$vintage_id
  )
  events <- write_sparse_series(
    con, observations %>% dplyr::transmute(series_id = .data$series_id, period = .data$period, value = .data$value),
    series_meta, item, publication_date
  )
  documented_create_views(con)
  list(curated_rows = nrow(observations), event_rows = events, publication_date = publication_date,
       source_sheet = NA_character_)
}
