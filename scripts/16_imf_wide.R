# IMF Data portal wide-export reader.
#
# The received files are not ordinary CSV. Each physical record is an outer
# semicolon-delimited envelope whose payload is a comma-delimited CSV record.
# Semicolons inside inner text split the envelope and metadata-rich exports may
# place a physical newline between adjacent inner fields. This reader restores
# that representation without rewriting the source bytes.

IMF_PERIOD_PATTERN <- "^(?:[0-9]{4}|[0-9]{4}-Q[1-4]|[0-9]{4}-M(?:0[1-9]|1[0-2])|[0-9]{4}-S[12])$"
IMF_DATASET_PATTERN <- "^([^:]+):([^()]+)\\(([^()]+)\\)$"

imf_detect_encoding <- function(path) {
  bytes <- readBin(path, "raw", n = min(file.info(path)$size, 3L))
  if (length(bytes) >= 3L && identical(as.integer(bytes[1:3]), c(239L, 187L, 191L))) {
    return("UTF-8-BOM")
  }
  probe <- readBin(path, "raw", n = min(file.info(path)$size, 100000L))
  converted <- suppressWarnings(iconv(rawToChar(probe), from = "UTF-8", to = "UTF-8"))
  if (!is.na(converted)) "UTF-8" else "windows-1252"
}

imf_read_lines <- function(path, encoding = imf_detect_encoding(path)) {
  from <- if (encoding == "UTF-8-BOM") "UTF-8" else encoding
  lines <- readLines(path, encoding = from, warn = FALSE, skipNul = FALSE)
  lines <- iconv(lines, from = from, to = "UTF-8", sub = NA_character_)
  if (anyNA(lines)) stop(
    "IMF export contains bytes that cannot be converted from ", encoding,
    " to UTF-8: ", basename(path), call. = FALSE
  )
  if (length(lines)) lines[[1]] <- sub("^\\ufeff", "", lines[[1]])
  lines
}

imf_parse_delimited_record <- function(text, separator) {
  connection <- textConnection(text, encoding = "UTF-8")
  on.exit(close(connection), add = TRUE)
  result <- utils::read.table(
    connection, header = FALSE, sep = separator, quote = "\\\"",
    comment.char = "", fill = TRUE, stringsAsFactors = FALSE,
    colClasses = "character", check.names = FALSE,
    allowEscapes = FALSE, blank.lines.skip = FALSE
  )
  if (!nrow(result)) character() else unname(as.character(result[1, , drop = TRUE]))
}

imf_outer_payload <- function(line) {
  fields <- imf_parse_delimited_record(line, ";")
  sub(";+$", "", paste(fields, collapse = ";"))
}

imf_parse_period <- function(period, frequency) {
  if (grepl("^[0-9]{4}-M[0-9]{2}$", period)) {
    return(as.Date(paste0(substr(period, 1L, 4L), "-", substr(period, 7L, 8L), "-01")))
  }
  if (grepl("^[0-9]{4}-Q[1-4]$", period)) {
    month <- (as.integer(substr(period, 7L, 7L)) - 1L) * 3L + 1L
    return(as.Date(sprintf("%s-%02d-01", substr(period, 1L, 4L), month)))
  }
  if (grepl("^[0-9]{4}-S[12]$", period)) {
    month <- if (substr(period, 7L, 7L) == "1") 1L else 7L
    return(as.Date(sprintf("%s-%02d-01", substr(period, 1L, 4L), month)))
  }
  if (grepl("^[0-9]{4}$", period)) return(as.Date(paste0(period, "-01-01")))
  stop("Unsupported IMF published period: ", period, " (frequency ", frequency, ")", call. = FALSE)
}

imf_period_end <- function(start, published_period) {
  if (grepl("-M", published_period)) return(seq(start, by = "1 month", length.out = 2L)[[2]] - 1)
  if (grepl("-Q", published_period)) return(seq(start, by = "3 months", length.out = 2L)[[2]] - 1)
  if (grepl("-S", published_period)) return(seq(start, by = "6 months", length.out = 2L)[[2]] - 1)
  as.Date(paste0(format(start, "%Y"), "-12-31"))
}

imf_read_wide_export <- function(path) {
  encoding <- imf_detect_encoding(path)
  lines <- imf_read_lines(path, encoding)
  if (!length(lines)) stop("IMF export is empty: ", path, call. = FALSE)
  payloads <- lapply(seq_along(lines), function(i) list(
    physical_start = i, physical_end = i, text = imf_outer_payload(lines[[i]])
  ))
  header <- imf_parse_delimited_record(payloads[[1]]$text, ",")
  if (!length(header) || header[[1]] != "DATASET") stop(
    "IMF export header does not begin with DATASET: ", basename(path), call. = FALSE
  )
  expected <- length(header)
  records <- vector("list", 0L)
  i <- 2L
  while (i <= length(payloads)) {
    current <- payloads[[i]]
    consumed <- 1L
    row <- tryCatch(imf_parse_delimited_record(current$text, ","), error = function(e) NULL)
    while ((is.null(row) || length(row) < expected) && i + consumed <= length(payloads)) {
      next_payload <- payloads[[i + consumed]]
      if (startsWith(next_payload$text, "IMF.")) break
      current$text <- paste0(current$text, ",", next_payload$text)
      current$physical_end <- next_payload$physical_end
      consumed <- consumed + 1L
      row <- tryCatch(imf_parse_delimited_record(current$text, ","), error = function(e) NULL)
    }
    if (is.null(row) || length(row) != expected) stop(
      "IMF inner CSV width mismatch in ", basename(path), " at physical line ",
      current$physical_start, ": expected ", expected, ", got ",
      if (is.null(row)) "unparseable" else length(row), call. = FALSE
    )
    records[[length(records) + 1L]] <- list(
      physical_start = current$physical_start, physical_end = current$physical_end, values = row
    )
    i <- i + consumed
  }
  matrix_values <- if (length(records)) do.call(rbind, lapply(records, `[[`, "values")) else
    matrix(character(), nrow = 0L, ncol = expected)
  data <- as.data.frame(matrix_values, stringsAsFactors = FALSE, check.names = FALSE)
  names(data) <- header
  data$source_record <- seq_len(nrow(data)) + 1L
  data$physical_start <- vapply(records, `[[`, integer(1), "physical_start")
  data$physical_end <- vapply(records, `[[`, integer(1), "physical_end")
  data$raw_payload <- vapply(records, function(record) {
    paste(payloads[record$physical_start:record$physical_end] |>
      vapply(`[[`, character(1), "text"), collapse = "\n")
  }, character(1))
  attr(data, "imf_encoding") <- encoding
  attr(data, "imf_header") <- header
  data
}

imf_normalize_wide_export <- function(data) {
  header <- attr(data, "imf_header")
  if (is.null(header)) header <- setdiff(names(data), c(
    "source_record", "physical_start", "physical_end", "raw_payload"
  ))
  period_columns <- header[grepl(IMF_PERIOD_PATTERN, header, perl = TRUE)]
  dimension_columns <- setdiff(header, period_columns)
  if (!length(period_columns)) stop("IMF export contains no recognized period columns.", call. = FALSE)
  frequency_column <- if ("FREQUENCY" %in% names(data)) "FREQUENCY" else if ("FREQ" %in% names(data)) "FREQ" else NA_character_
  rows <- vector("list", length(period_columns))
  for (j in seq_along(period_columns)) {
    period <- period_columns[[j]]
    keep <- !is.na(data[[period]]) & nzchar(data[[period]])
    if (!any(keep)) next
    part <- data[keep, c(
      dimension_columns, "source_record", "physical_start", "physical_end", "raw_payload"
    ), drop = FALSE]
    part$published_period <- period
    part$source_column <- match(period, header)
    part$raw_value <- data[[period]][keep]
    numeric_value <- suppressWarnings(as.numeric(part$raw_value))
    is_statistical <- !"OBS_MEASURE" %in% names(part) | part$OBS_MEASURE == "OBS_VALUE"
    if (any(is_statistical & is.na(numeric_value))) stop(
      "IMF numeric observation contains a non-numeric token at period ", period, call. = FALSE
    )
    part$value <- numeric_value
    frequency <- if (is.na(frequency_column)) "" else part[[frequency_column]]
    part$period_start <- as.Date(vapply(seq_len(nrow(part)), function(i) as.character(
      imf_parse_period(period, frequency[[i]])
    ), character(1)))
    part$period_end <- as.Date(vapply(seq_len(nrow(part)), function(i) as.character(
      imf_period_end(part$period_start[[i]], period)
    ), character(1)))
    rows[[j]] <- part
  }
  dplyr::bind_rows(rows)
}

imf_dataset_identity <- function(dataset) {
  match <- regexec(IMF_DATASET_PATTERN, dataset, perl = TRUE)
  values <- regmatches(dataset, match)[[1]]
  if (length(values) != 4L) stop("Invalid IMF DATASET identity: ", dataset, call. = FALSE)
  list(dataset = values[[1]], agency = values[[2]], dataflow = values[[3]], version = values[[4]])
}

imf_series_id <- function(source_id, dataset, series_code, obs_measure) {
  key <- paste(source_id, dataset, series_code, obs_measure, sep = "|")
  paste0(source_id, ":", substr(vapply(
    key, digest::digest, character(1), algo = "sha256", serialize = FALSE
  ), 1L, 24L))
}

read_imf_wide_contracts <- function(root) {
  readr::read_csv(
    file.path(root, "config", "imf_wide_contracts.csv"),
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE, progress = FALSE
  )
}

validate_imf_wide_contract <- function(item, parsed, normalized, root) {
  contracts <- read_imf_wide_contracts(root)
  contract <- contracts[contracts$source_id == item$source_id, , drop = FALSE]
  if (nrow(contract) != 1L) stop(
    "IMF contract guard: expected exactly one contract for ", item$source_id, call. = FALSE
  )
  datasets <- unique(parsed$DATASET)
  statistical <- !"OBS_MEASURE" %in% names(normalized) |
    normalized$OBS_MEASURE == "OBS_VALUE"
  checks <- c(
    sha256 = identical(item$sha256, contract$sha256[[1]]),
    dataset = identical(datasets, contract$dataset[[1]]),
    records = nrow(parsed) == as.integer(contract$data_records[[1]]),
    series = length(unique(parsed$SERIES_CODE)) == as.integer(contract$series_count[[1]]),
    observations = sum(statistical) == as.numeric(contract$observation_count[[1]]),
    metadata_values = sum(!statistical) == as.numeric(contract$metadata_value_count[[1]]),
    encoding = identical(attr(parsed, "imf_encoding"), contract$encoding[[1]])
  )
  if (!all(checks)) stop(
    "IMF contract guard failed for ", item$source_id, ": ",
    paste(names(checks)[!checks], collapse = ", "), call. = FALSE
  )
  invisible(contract)
}

imf_wide_parser <- function(con, item, dimensions, release_id, root, publication_date) {
  parsed <- imf_read_wide_export(item$path)
  normalized <- imf_normalize_wide_export(parsed)
  contract <- validate_imf_wide_contract(item, parsed, normalized, root)
  dataset_identity <- imf_dataset_identity(unique(parsed$DATASET))
  frequency_column <- if ("FREQUENCY" %in% names(parsed)) "FREQUENCY" else "FREQ"
  parsed$series_id <- imf_series_id(
    item$source_id, parsed$DATASET, parsed$SERIES_CODE, parsed$OBS_MEASURE
  )
  normalized$series_id <- imf_series_id(
    item$source_id, normalized$DATASET, normalized$SERIES_CODE, normalized$OBS_MEASURE
  )
  statistical_normalized <- normalized |>
    dplyr::filter(!"OBS_MEASURE" %in% names(normalized) | .data$OBS_MEASURE == "OBS_VALUE")
  metadata_normalized <- normalized |>
    dplyr::filter("OBS_MEASURE" %in% names(normalized) & .data$OBS_MEASURE != "OBS_VALUE")

  raw_records <- parsed |> dplyr::transmute(
    vintage_id = item$vintage_id, release_id = release_id, source_id = item$source_id,
    source_file = item$source_file, source_record = as.numeric(.data$source_record),
    physical_start = as.numeric(.data$physical_start), physical_end = as.numeric(.data$physical_end),
    dataset = .data$DATASET, series_code = .data$SERIES_CODE,
    obs_measure = .data$OBS_MEASURE, raw_payload = .data$raw_payload
  )
  DBI::dbExecute(con, paste0(
    "DELETE FROM imf_raw_records WHERE vintage_id = ", sql_string(item$vintage_id)
  ))
  DBI::dbWriteTable(con, "imf_raw_records", raw_records, append = TRUE)

  metadata_columns <- setdiff(attr(parsed, "imf_header"), grep(
    IMF_PERIOD_PATTERN, attr(parsed, "imf_header"), value = TRUE, perl = TRUE
  ))
  series_rows <- parsed |> dplyr::distinct(.data$series_id, .keep_all = TRUE) |>
    dplyr::transmute(
      vintage_id = item$vintage_id, release_id = release_id, source_id = item$source_id,
      dataset = .data$DATASET, agency = .env$dataset_identity$agency,
      dataflow = .env$dataset_identity$dataflow,
      dataflow_version = .env$dataset_identity$version, series_id = .data$series_id,
      series_code = .data$SERIES_CODE, obs_measure = .data$OBS_MEASURE,
      frequency = .data[[frequency_column]], source_record = as.numeric(.data$source_record)
    )
  DBI::dbExecute(con, paste0(
    "DELETE FROM imf_series_snapshot WHERE vintage_id = ", sql_string(item$vintage_id)
  ))
  DBI::dbWriteTable(con, "imf_series_snapshot", series_rows, append = TRUE)

  dimension_rows <- lapply(metadata_columns, function(column) {
    parsed |> dplyr::transmute(
      series_id = .data$series_id, dimension = column,
      value = as.character(.data[[column]]), basis = "published_imf_export",
      evidence = paste0(item$source_file, "#record=", .data$source_record),
      derived_at = Sys.time()
    ) |> dplyr::filter(!is.na(.data$value), nzchar(.data$value))
  }) |> dplyr::bind_rows() |> dplyr::distinct(.data$series_id, .data$dimension, .keep_all = TRUE)
  series_ids_sql <- paste(vapply(unique(series_rows$series_id), sql_string, character(1)), collapse = ",")
  if (nzchar(series_ids_sql)) DBI::dbExecute(con, paste0(
    "DELETE FROM series_dimension WHERE series_id IN (", series_ids_sql,
    ") AND basis='published_imf_export'"
  ))
  if (nrow(dimension_rows)) DBI::dbWriteTable(con, "series_dimension", dimension_rows, append = TRUE)

  series_meta <- parsed |>
    dplyr::filter(!"OBS_MEASURE" %in% names(parsed) | .data$OBS_MEASURE == "OBS_VALUE") |>
    dplyr::distinct(.data$series_id, .keep_all = TRUE) |>
    dplyr::transmute(
      series_id = .data$series_id, source_id = item$source_id,
      label = if ("INDICATOR" %in% names(parsed)) .data$INDICATOR else .data$SERIES_CODE,
      unit = if ("UNIT" %in% names(parsed)) dplyr::na_if(.data$UNIT, "") else "source_units",
      scale = if ("SCALE" %in% names(parsed)) dplyr::na_if(.data$SCALE, "") else "source_scale",
      frequency = tolower(.data[[frequency_column]]), currency = NA_character_,
      index_base = NA_character_, hierarchy_level = "imf_series",
      parent_series_id = NA_character_, is_total = FALSE,
      identity_basis = paste(.data$DATASET, .data$SERIES_CODE, .data$OBS_MEASURE, sep = "|"),
      identity_stability = "semantic", hierarchy_status = "unreviewed",
      semantic_status = "provisional", first_vintage_id = item$vintage_id,
      price_base_year = NA_character_
    ) |>
    dplyr::mutate(
      unit = dplyr::coalesce(.data$unit, "source_units"),
      scale = dplyr::coalesce(.data$scale, "source_scale")
    )

  observation_snapshot <- statistical_normalized |> dplyr::transmute(
    vintage_id = item$vintage_id, release_id = release_id, source_id = item$source_id,
    series_id = .data$series_id, published_period = .data$published_period,
    period_start = .data$period_start, period_end = .data$period_end,
    value = .data$value, raw_value = .data$raw_value,
    source_record = as.numeric(.data$source_record), source_column = as.numeric(.data$source_column)
  )
  DBI::dbExecute(con, paste0(
    "DELETE FROM imf_observation_snapshot WHERE vintage_id = ", sql_string(item$vintage_id)
  ))
  DBI::dbWriteTable(con, "imf_observation_snapshot", observation_snapshot, append = TRUE)

  metadata_snapshot <- metadata_normalized |> dplyr::transmute(
    vintage_id = item$vintage_id, release_id = release_id, source_id = item$source_id,
    series_id = .data$series_id, metadata_measure = .data$OBS_MEASURE,
    published_period = .data$published_period, period_start = .data$period_start,
    period_end = .data$period_end, text_value = .data$raw_value,
    source_record = as.numeric(.data$source_record), source_column = as.numeric(.data$source_column)
  )
  DBI::dbExecute(con, paste0(
    "DELETE FROM imf_metadata_snapshot WHERE vintage_id = ", sql_string(item$vintage_id)
  ))
  if (nrow(metadata_snapshot)) {
    DBI::dbWriteTable(con, "imf_metadata_snapshot", metadata_snapshot, append = TRUE)
  }
  events <- if (nrow(observation_snapshot)) {
    write_sparse_series(
      con,
      observation_snapshot |> dplyr::transmute(
        series_id = .data$series_id, period = .data$period_start, value = .data$value
      ),
      series_meta, item, publication_date
    )
  } else 0L
  list(
    curated_rows = nrow(parsed), event_rows = events, publication_date = publication_date,
    source_sheet = "data", observations = nrow(observation_snapshot),
    metadata_values = nrow(metadata_snapshot), contract = contract
  )
}
