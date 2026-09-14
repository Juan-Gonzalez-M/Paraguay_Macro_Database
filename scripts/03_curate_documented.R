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
  normalized <- normalize_semantic_label(documented_strip_footnote(text))
  month_match <- stringr::str_match(normalized, DOCUMENTED_MONTH_YEAR_PATTERN)
  month_keep <- !is.na(month_match[, 1])
  if (any(month_keep)) {
    years <- documented_expand_two_digit_year(as.integer(month_match[month_keep, 3]))
    months <- documented_month_number(month_match[month_keep, 2])
    result[month_keep] <- as.Date(vapply(seq_along(years), function(i) {
      as.character(month_end(years[[i]], months[[i]]))
    }, character(1)))
  }
  # A day-month-year label names one day, not the month it falls in, so it is
  # resolved to the exact date rather than pushed to month end.
  day_match <- stringr::str_match(normalized, DOCUMENTED_DAY_MONTH_YEAR_PATTERN)
  day_keep <- !is.na(day_match[, 1]) & is.na(result)
  if (any(day_keep)) {
    years <- documented_expand_two_digit_year(as.integer(day_match[day_keep, 4]))
    months <- documented_month_number(day_match[day_keep, 3])
    days <- as.integer(day_match[day_keep, 2])
    result[day_keep] <- as.Date(sprintf("%04d-%02d-%02d", years, months, days))
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

# Same year-cell pattern as documented_year_values(), but returns the trailing
# footnote/qualifier text (e.g. the "*" in "2021*") instead of discarding it.
# Published footnote markers usually mean "provisional, subject to revision" --
# real editorial information this project otherwise throws away silently while
# parsing the year (verified on CUADRO 57a). A blank
# capture (no marker) is normalized to NA, matching every other "not present"
# convention in this file.
documented_year_footnote <- function(text) {
  input_dim <- dim(text)
  values <- trimws(as.character(text))
  matched <- stringr::str_match(
    values,
    "^(?:19|20)[0-9]{2}((?:\\s*(?:\\(?\\*+\\)?|[0-9]{1,2}/))*)\\s*$"
  )
  marker <- trimws(matched[, 2])
  marker[!nzchar(marker)] <- NA_character_
  if (!is.null(input_dim)) dim(marker) <- input_dim
  marker
}

# TRUE for a cell whose entire content is a published footnote marker -- "*",
# "**", "(*)", "1/", "12/". Such a cell qualifies the data underneath it; it is
# never a dimension of the series and must not reach a label.
documented_footnote_only <- function(x) {
  key <- trimws(as.character(x))
  out <- stringr::str_detect(key, "^(?:\\(?\\*+\\)?|[0-9]{1,2}/)+$")
  out[is.na(out)] <- FALSE
  if (!is.null(dim(x))) dim(out) <- dim(x)
  out
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

# The published month-year cell, in the forms the BCP actually writes it.
#
# Two of them were missing and cost real observations. The Spanish abbreviation
# is written with a full stop as often as without -- "mar.-19", "dic.-19" -- and
# the four-letter "sept" appears alongside "sep" and "set"; CUADRO 56a/56b lost
# 88 reserve-composition observations to the first and CUADRO 18/23/23a/26 lost
# 72 to the second. Both are spellings of a period label, not different kinds of
# cell, so both belong in the pattern rather than in a list of exceptions.
DOCUMENTED_MONTH_ABBREVIATIONS <-
  "ene|feb|mar|abr|may|jun|jul|ago|sept|sep|set|oct|nov|dic"

# The separator is written loosely too: "dic- 19*" carries a space the publisher
# typed after the dash, which cost CUADRO 35 a month of banking-system data.
DOCUMENTED_MONTH_YEAR_PATTERN <- paste0(
  "^(", DOCUMENTED_MONTH_ABBREVIATIONS, ")[.]?\\s*[- /]\\s*([0-9]{2}|[0-9]{4})$"
)

# Daily labels the BCP writes as text rather than as an Excel date: "30-nov.-20".
# bcp_fx_daily's 2020 worksheet has nine of them, and they cost 108 observations
# of the BCP's own foreign-exchange intervention.
DOCUMENTED_DAY_MONTH_YEAR_PATTERN <- paste0(
  "^([0-9]{1,2})\\s*[- /]\\s*(", DOCUMENTED_MONTH_ABBREVIATIONS,
  ")[.]?\\s*[- /]\\s*([0-9]{2}|[0-9]{4})$"
)

# Two-digit years are read on the same century boundary the month-year path uses.
documented_expand_two_digit_year <- function(years) {
  short <- !is.na(years) & years < 100L
  years[short] <- years[short] + ifelse(years[short] >= 40L, 1900L, 2000L)
  years
}

documented_date_axis_token <- function(x) {
  key <- normalize_semantic_label(documented_strip_footnote(x))
  out <- stringr::str_detect(key, "^(?:19|20)[0-9]{2}-[0-1][0-9]-[0-3][0-9]$") |
    stringr::str_detect(key, "^(?:19|20)[0-9]{2}[/.-](?:0?[1-9]|1[0-2])$") |
    stringr::str_detect(key, DOCUMENTED_MONTH_YEAR_PATTERN) |
    stringr::str_detect(key, DOCUMENTED_DAY_MONTH_YEAR_PATTERN)
  out[is.na(out)] <- FALSE
  out
}

# A footnote marker on a period label is still a period label. The BCP marks
# provisional and revised figures by hanging an asterisk on the month itself --
# "Ene**", "Set*" -- and the annex uses it heavily: 240 month labels across the
# Statistical Annex carry one. The reconciliation found what that cost. CUADRO 59
# (external public debt) lost 480 observations and CUADRO 55 lost 229, because
# every marked month failed to match and its whole row went unread, silently, for
# the most recent years of the series -- exactly the years a researcher wants.
#
# The marker grammar is the one documented_year_values() already uses for year
# cells -- asterisks, optionally parenthesised, and numbered "1/" references. The
# year axis has handled footnotes since the CUADRO 57a repair; the month axis
# never did, which is the whole of this defect.
DOCUMENTED_FOOTNOTE_SUFFIX <- "((?:\\s*(?:\\(?\\*+\\)?|\\(?[0-9]{1,2}/\\)?))+)\\s*$"

documented_strip_footnote <- function(x) {
  input_dim <- dim(x)
  out <- stringr::str_replace(trimws(as.character(x)), DOCUMENTED_FOOTNOTE_SUFFIX, "")
  if (!is.null(input_dim)) dim(out) <- input_dim
  out
}

# Same cell pattern, returning the marker instead of discarding it, exactly as
# documented_year_footnote() does for years.
documented_month_footnote <- function(x) {
  input_dim <- dim(x)
  marker <- trimws(stringr::str_match(
    trimws(as.character(x)), DOCUMENTED_FOOTNOTE_SUFFIX
  )[, 2])
  marker[is.na(marker) | !nzchar(marker)] <- NA_character_
  if (!is.null(input_dim)) dim(marker) <- input_dim
  marker
}

# A published sub-annual interval: "Enero/Junio", "Mayo/Diciembre", "Junio/Agosto",
# or a single month standing for itself. CUADRO 11 publishes the legal minimum
# wage this way -- the annual row carries the year's average and the rows beneath
# it carry the wage actually in force over each interval, which is what a
# researcher dating a minimum-wage change needs. Neither documented_month_number()
# nor documented_quarter_number() resolves a compound label, so those rows fell
# through to `next` and 83 published values were never read.
#
# Returns the first and last month of the interval, or NA when the label is not
# one. A reversed pair is refused rather than silently swapped: "Diciembre/Enero"
# would be a publication error, not an interval this parser may guess at.
documented_month_interval <- function(label) {
  if (length(label) != 1L || documented_blank(label)) return(c(NA_integer_, NA_integer_))
  parts <- stringr::str_split(stringr::str_squish(as.character(label)), "\\s*/\\s*")[[1]]
  if (!length(parts) || length(parts) > 2L) return(c(NA_integer_, NA_integer_))
  months <- documented_month_number(parts)
  if (anyNA(months)) return(c(NA_integer_, NA_integer_))
  bounds <- c(months[[1]], months[[length(months)]])
  if (bounds[[2]] < bounds[[1]]) return(c(NA_integer_, NA_integer_))
  bounds
}

documented_month_number <- function(x) {
  input_dim <- dim(x)
  key <- normalize_semantic_label(documented_strip_footnote(x))
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
  key <- normalize_semantic_label(documented_strip_footnote(x))
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
  # A navigation link is not part of the published title. Every financial-
  # indicator worksheet carries a "Volver al índice" link in its header block,
  # and because the unit derivation reads the title for the word "indice" it put
  # unit = index on 146 series -- including sheet 8, whose entire title is that
  # link, and sheets 4 and 7, which publish outstanding balances. The exclusion
  # below already dropped a cell that is exactly "Índice"; the link says the same
  # thing in four words and slipped past it.
  keep <- !documented_blank(values) & nchar(values) >= 6L &
    !stringr::str_detect(
      normalize_semantic_label(values),
      "^(indice|cuadro n|ano mes|fecha)$|^volver al indice$|^volver$"
    )
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
    unit = character(), scale = character(), currency = character(), index_base = character(),
    price_base_year = character()
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
  # A row label is read as a unit only where the published title has not already
  # said what the table measures. The two label heuristics below look for a
  # headcount and a duration, and on these tables they find a product name and a
  # maturity bucket instead: "Préstamo Personal", "Tarjetas de Crédito",
  # "<= 90 días". On a table the publisher named "Saldos desglosados por plazo y
  # cartera" -- outstanding balances, broken down by exactly that maturity and
  # that portfolio -- they said nothing about the unit, and reading them put
  # count and days on 18,541 published balances.
  #
  # A title that states the money the table is denominated in settles the
  # question just as firmly, and the Annex CUADRO 20 defect is what that omission
  # cost. The table is headed "Operaciones cambiarias del Banco Central del
  # Paraguay. — En millones de dólares." and twelve of its thirty series carry
  # the word "operaciones" in their row label -- "Otras operaciones 1/",
  # "Operaciones netas totales" -- so the count keyword won and they were stored
  # as counts at scale 1 while the eighteen beside them were stored as USD
  # millions. Their base-unit values were wrong by a factor of 1,000,000, and
  # each of the twelve matches a dedicated fx_operations series, held in USD
  # millions, across all 379 of its monthly observations. A currency and a
  # magnitude printed under the table title is the publisher naming the unit; no
  # word in a row label outranks it.
  title_states_money <- stringr::str_detect(
    global,
    "(miles|millones|billones)\\s+(de\\s+)?(dolar|guarani|euro)|en\\s+(dolar|guarani|euro)"
  )
  title_names_measure <- stringr::str_detect(global, "(^|[^a-z])saldos([^a-z]|$)") |
    title_states_money
  unit <- dplyr::case_when(
    # A unit the publisher states in the table *title* outranks one inferred from
    # a word in a row label. "Tasas de interés nominales - Bancos - Promedio
    # mensuales en porcentajes anuales" states the unit of every column beneath
    # it. Read from the label instead, "Préstamo Personal" and "<= 90 días" put
    # unit = count on 311 published interest rates and days on 52 more, which is
    # how a rate-labelled series ends up carrying a non-rate unit code. Only the
    # title is consulted here -- the label-and-title `context` used further down
    # would let the label win again through the back door.
    stringr::str_detect(global, "porcentaje|%") ~ "percent",
    !title_names_measure &
      stringr::str_detect(local, "cantidad|numero|lotes|operaciones|tarjetas|cheques|dependencias|personal") ~ "count",
    stringr::str_detect(context, "porcentaje|%") ~ "percent",
    stringr::str_detect(context, "veces") ~ "ratio",
    stringr::str_detect(context, "indice|base .{0,40}100") ~ "index",
    !title_names_measure & stringr::str_detect(local, "plazo.{0,20}dia|dias") ~ "days",
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
  # Distinct from index_base above: a constant-price valuation year (e.g. "En
  # millones de guaraníes constantes de 2014") is not an index=100 reference,
  # it is the year whose prices were used to value quantities from other
  # years -- CLAUDE.md's own documented trap ("PIB constante 2014"). Verified
  # against the real economic_annex titles before adding this: the phrase
  # "constante(s) de <year>" appears consistently across the GDP tables
  # (Cuadro 1/2/6/6a/7/7a) and nowhere else; no evidence of a seasonal-
  # adjustment marker was found anywhere in the 94 real titles, so that field
  # is left for explicit economic review rather than inferred from a title.
  price_base_year <- stringr::str_match(
    table_title, stringr::regex("constantes?\\s+de\\s+((?:19|20)[0-9]{2})", ignore_case = TRUE)
  )[, 2]
  tibble::tibble(
    unit = unit, scale = scale, currency = currency,
    index_base = dplyr::if_else(is.na(base_match), NA_character_, base_match),
    price_base_year = price_base_year
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
  metadata_fields <- c("unit", "scale", "currency", "index_base", "price_base_year")
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
      price_base_year = dplyr::coalesce(.data$price_base_year, .data$price_base_year_inferred),
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

documented_extract_vertical_date <- function(text, numbers, dates, source_sheet,
                                             merge_ranges = parse_merge_ranges(NA_character_)) {
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
  # A column that starts late is a new series, not a stray number.
  #
  # The density floor exists to keep footnote numerals and one-off marginal notes
  # out of the data columns, and it does that well. But it also drops any column
  # the publisher has only just begun: reconciliation found CUADRO 17 losing four
  # real-exchange-rate partner indices introduced in March 2025 (16 months of
  # data against an 18-row floor) and SIPAP_04 losing ten payment-band columns
  # opened five months ago. Both would have kept failing silently until enough
  # history accumulated to clear the threshold, which is the worst possible time
  # to start reading a series -- the early months would simply never appear.
  #
  # The distinguishing feature is shape, not size: a new series runs unbroken
  # from the row it starts on to the end of the data, and carries a published
  # header. A footnote numeral does neither.
  header_span <- seq_len(max(1L, min(candidate_rows) - 1L))
  starts_late <- vapply(possible_cols, function(j) {
    present <- !is.na(numbers[candidate_rows, j])
    if (sum(present) < 2L) return(FALSE)
    first <- which(present)[[1]]
    all(present[first:length(present)]) &&
      any(!documented_blank(text[header_span, j]))
  }, logical(1))
  # Settlement/maturity columns are attributes of an observation, not numeric
  # measures. Excel dates are internally numeric, so explicitly exclude columns
  # whose candidate cells are predominantly dates.
  data_cols <- possible_cols[
    (numeric_density >= min_density | starts_late) & date_density < min_density
  ]
  if (!length(data_cols)) return(documented_empty_observations())
  header_rows <- documented_header_rows(text, min(candidate_rows), data_cols)
  # A published column the density floor does not reach.
  #
  # The floor and starts_late between them describe a column that is either busy,
  # or newly opened and running to the end. Three published shapes are neither,
  # and reconciliation recorded all three as unread data:
  #
  #   a participant that reported once and left   CCC 02 columns 11-12, one value
  #                                               each in 2013/11 and never again
  #   a column opened in the final month          SIPAP_12 columns 17-18, one
  #                                               value each, under the two-value
  #                                               floor starts_late imposes
  #   a thinly traded instrument                  interbank "Datos (+ de 1 dia)"
  #                                               columns 15-20, the whole REPO
  #                                               Tripartito block: 551 values on
  #                                               95 of 3,653 trading days, 2.6%
  #                                               against a 5% floor
  #
  # The last is the largest of the three and the least like the description it
  # was filed under. It is not a grain problem and not a late start: a thin
  # market does not trade every day, and a density floor cannot tell "rarely
  # traded" from "not a data column".
  #
  # What can is the header. The floor was always a proxy for "did the publisher
  # mean this to be a column", and the publisher answers that directly by heading
  # it -- on the same header rows the confident columns just established, inside
  # the block those columns span. A footnote numeral or a marginal note has no
  # such header. Density stays as the first pass because it is what identifies
  # those header rows in the first place; this is the second.
  headers <- documented_fill_right(text)
  recovered_cols <- integer()
  merged_cols <- integer()
  if (length(header_rows)) {
    # The window used to run only between the first and last confident data
    # column, so a published block lying entirely outside that span could never
    # be examined -- in either direction. The interbank sheets lose three blocks
    # to it, all headed, all published, none read:
    #
    #   left of the first    "Datos" and "Datos (+ de 1 día)" both open with the
    #                        Call Money Market (PYG) block, headed by the merge
    #                        C18:G18 with its own Monto, Número de transacciones
    #                        and Tasa Máxima/Mínima/Promedio on row 19. The first
    #                        confident column is the REPO Interbancario block
    #                        after it.
    #   right of the last    "Datos (+ de 1 día)" column Z is the Plazo of the
    #                        Call Money Market (USD) block and columns AB-AD are
    #                        the whole Facilidad de Crédito Especial block, named
    #                        on row 18 and detailed on row 19.
    #
    # The window is therefore the span the publisher headed: everything right of
    # the period axis, out to the last column carrying a header. The evidence
    # rule below is unchanged, so a stray numeral beyond the table is still
    # rejected -- it has no header on the header rows and no merge over it.
    headed_cols <- which(colSums(!documented_blank(text[header_rows, , drop = FALSE])) > 0L)
    header_extent <- max(c(max(data_cols), headed_cols[headed_cols <= ncol(text)]))
    block <- setdiff(seq.int(axis_col + 1L, header_extent), data_cols)
    group_row <- min(header_rows)
    # A row-label column holds text against the period axis, not numbers, so the
    # numeric test is what keeps the widened window from swallowing one.
    carries_values <- function(j) {
      any(!is.na(numbers[candidate_rows, j])) &&
        date_density[[match(j, possible_cols)]] < min_density
    }
    # First pass: a column the publisher headed in the column itself.
    published_cols <- block[vapply(block, function(j) {
      carries_values(j) && any(!documented_blank(text[header_rows, j]))
    }, logical(1))]
    accepted <- sort(c(data_cols, published_cols))
    # Second pass: a column with no header of its own, admitted when a merged
    # group header spans it together with a column that is accepted. That is the
    # publisher stating, in the only place a workbook can state it, that the two
    # columns are one block. SIPAP_12 column 18 is inside the merge Q2:R2 with
    # column 17; CUADRO 35 column 12 is inside no merge at all, and stays the
    # out_of_scope_block review classified it. The two are indistinguishable in
    # the cell matrix, and the merge ranges -- now carried through from the
    # workbook XML -- are the only thing that separates them. The passes are
    # ordered because the partner can itself be a recovered column: column 17 is
    # admitted on its own group header before column 18 is judged against it.
    merged_group <- function(j) {
      if (!nrow(merge_ranges)) return(FALSE)
      spanning <- merge_ranges[
        merge_ranges$row_from <= group_row & merge_ranges$row_to >= group_row &
          merge_ranges$col_from <= j & merge_ranges$col_to >= j, , drop = FALSE
      ]
      if (!nrow(spanning)) return(FALSE)
      any(vapply(seq_len(nrow(spanning)), function(k) {
        span <- seq.int(spanning$col_from[[k]], spanning$col_to[[k]])
        any(setdiff(span, j) %in% accepted) &&
          !documented_blank(text[group_row, spanning$col_from[[k]]])
      }, logical(1)))
    }
    merged_cols <- setdiff(block, published_cols)
    merged_cols <- merged_cols[vapply(
      merged_cols, function(j) carries_values(j) && merged_group(j), logical(1)
    )]
    recovered_cols <- sort(c(published_cols, merged_cols))
    if (length(recovered_cols)) data_cols <- sort(c(data_cols, recovered_cols))
  }
  first_data_col <- min(data_cols)
  metadata_rows <- setdiff(seq_len(max(1L, min(candidate_rows) - 1L)), header_rows)
  title <- documented_table_title(text, metadata_rows)
  # Filling right is right for a group header, which is merged, and wrong for a
  # sub-header the publisher simply left blank -- it would carry the neighbour's
  # meaning across a group boundary. On SIPAP_12 the QR block has no
  # Cantidad/Importe row at all, and inheriting it would label a count of 302,815
  # operations "Importe Destino". For a column admitted on a merged group header
  # rather than on a header of its own, the group row is therefore taken filled
  # and the sub-header rows only as published, so the two QR columns end up
  # sharing the group name and are separated by the existing positional-identity
  # machinery instead of by a label that is not true. A column that does publish
  # its own sub-header -- the Call Money Market block on the interbank sheets
  # names its Monto, Número de transacciones and three rate columns on row 19 --
  # is labelled like any other.
  column_labels <- vapply(data_cols, function(j) {
    parts <- if (j %in% recovered_cols) {
      published <- text[header_rows, j]
      published[header_rows == min(header_rows)] <- headers[min(header_rows), j]
      published
    } else headers[header_rows, j]
    label <- documented_compact_path(parts)
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
  # Continuation operations.
  #
  # An undated row directly beneath a dated one is not a row whose date went
  # missing. On the interbank sheets the dated row carries the day's published
  # aggregate and the rows beneath it carry the individual operations that make
  # it up: under a 9,000,000 total at an average 2.144% sit a 5,000,000 at 2.14%
  # for 17 days and a 4,000,000 at 2.15% for 7. Total and components are a
  # different grain, so simply inheriting the date -- which is what block_fill
  # does where undated rows are the majority -- would put two different things in
  # one series and collide them on (series_id, period).
  #
  # They are emitted as event records instead, which is what the audit asks for:
  # the trade date inherited from the row above and an operation sequence saying
  # which operation of that day this is. The sequence is positional and is
  # declared positional -- the publisher does not number these rows, so nothing
  # guarantees a given operation keeps its place when the sheet is republished.
  if (!block_fill && length(candidate_rows) > 1L) {
    in_data <- rowSums(!is.na(numbers[, data_cols, drop = FALSE])) > 0L
    governing <- NA_integer_
    sequence_number <- 0L
    for (r in seq.int(min(candidate_rows), max(candidate_rows))) {
      if (!is.na(periods[[r]])) {
        governing <- r
        sequence_number <- 0L
        next
      }
      if (!in_data[[r]] || is.na(governing) || r %in% annual_rows) next
      sequence_number <- sequence_number + 1L
      for (jj in seq_along(data_cols)) {
        j <- data_cols[[jj]]
        value <- numbers[r, j]
        if (is.na(value)) next
        series_label <- documented_compact_path(c(
          column_labels[[jj]], paste0("operacion ", sequence_number)
        ))
        k <- k + 1L
        records[[k]] <- documented_record(
          source_sheet, title, "vertical_date_event_positional_lane",
          periods[[governing]], text[governing, axis_col], frequency_default,
          series_label, "", column_labels[[jj]], value, r, j
        )
      }
    }
  }
  documented_bind_records(records)
}

documented_extract_horizontal_time <- function(text, numbers, dates, source_sheet, mode) {
  # The period axis ends at the last header cell that actually parses as a
  # period. Filling right past it swallows the comparison columns published to
  # the right of the data -- on the foreign-trade sheets those are "A Julio
  # 2024", "A Julio 2025*", "A Julio 2026*", "Var. Nominal", "Var. %",
  # "Incidencia" and "Var. % Interanual", seven per sheet. Each inherited the
  # last real period, so every product gained seven extra observations in the
  # same month, which collided and were pushed onto positional lanes. Merged
  # header cells inside the axis still fill right, which is what the fill is
  # for; the bound only stops it running off the end of the axis (R45).
  fill_right_within_axis <- function(values, first_col, last_col) {
    for (j in seq.int(first_col, last_col)) {
      if (j > first_col && is.na(values[[j]])) values[[j]] <- values[[j - 1L]]
    }
    values[seq_len(length(values)) > last_col] <- NA
    values
  }
  # Where the last period's block ends, which is not where its label sits.
  #
  # A sheet that publishes several measures under each period writes the period
  # once, above the first measure. Ending the axis at the last *label* therefore
  # cuts the final period short by however many measures follow it: Cuadro 52a
  # and 52b publish "Importación Registrada", "Importacion bajo el Regimen de
  # Turismo" and "Importacion para consumo interno" under every month, so the
  # last month lost two of its three columns -- 256 published cells across the
  # pair, invisible because the sheet still balanced.
  #
  # The block width is the publisher's own stride between period labels, and the
  # last block is as wide as the ones before it. The extension applies only when
  # that stride is regular; an irregular axis extends by nothing, which is the
  # behaviour every single-measure sheet already had.
  axis_last_column <- function(axis_cols, columns) {
    if (length(axis_cols) < 3L) return(max(axis_cols))
    strides <- diff(axis_cols)
    if (length(unique(strides)) != 1L || strides[[1]] <= 1L) return(max(axis_cols))
    min(columns, max(axis_cols) + strides[[1]] - 1L)
  }
  if (mode == "horizontal_date") {
    time_row <- which.max(rowSums(!is.na(dates)))
    period_values <- dates[time_row, ]
    axis_cols <- which(!is.na(period_values))
    if (!length(axis_cols)) return(documented_empty_observations())
    first_time_col <- min(axis_cols)
    period_values <- fill_right_within_axis(
      period_values, first_time_col, axis_last_column(axis_cols, ncol(text))
    )
    frequency_default <- documented_frequency(dates[time_row, !is.na(dates[time_row, ])])
  } else {
    years <- documented_year_values(text)
    time_row <- documented_year_axis_index(text, margin = 1L)
    if (is.na(time_row)) return(documented_empty_observations())
    year_values <- years[time_row, ]
    axis_cols <- which(!is.na(year_values))
    if (!length(axis_cols)) return(documented_empty_observations())
    first_time_col <- min(axis_cols)
    year_values <- fill_right_within_axis(
      year_values, first_time_col, axis_last_column(axis_cols, ncol(text))
    )
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
  # A sub-header row that contains nothing but a provisional-data marker is
  # editorial, not a dimension. On the foreign-trade sheets a bare "*" sits over
  # the most recent 24 months; treated as a sub-header it became the measure, so
  # every product was cut in two at the month the marker starts -- "Soja" with
  # 367 observations to 2024-07 and "Soja - *" with 31 from 2024-08. The marker
  # is real editorial information, so it is kept on the observation rather than
  # discarded, but it must not enter the identity (R45).
  marker_cells <- documented_footnote_only(text)
  footnote_by_column <- rep(NA_character_, ncol(text))
  if (length(subheader_rows)) for (r in subheader_rows) {
    markers <- ifelse(marker_cells[r, ], trimws(as.character(text[r, ])), NA_character_)
    footnote_by_column <- dplyr::coalesce(footnote_by_column, markers)
  }
  label_text <- text
  label_text[marker_cells] <- NA_character_
  subheaders <- documented_fill_right(label_text)
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
  observations <- documented_bind_records(records)
  if (nrow(observations) && any(!is.na(footnote_by_column))) {
    observations$footnote_marker <- footnote_by_column[observations$source_column]
  }
  observations
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
    } else if (!anyNA(documented_month_interval(label))) {
      # An irregular sub-annual interval. The period axis carries its closing
      # month, which keeps the project's period-end convention and keeps two
      # intervals in one year on distinct keys; the opening month is recorded by
      # apply_series_period_bounds() from this same published label, so
      # v_series_observations reports the interval a researcher must date the
      # value to rather than a bound inferred from the frequency.
      #
      # These are a different measure from the annual row above them and are
      # labelled as one: on CUADRO 11 the 1980 annual row is 22,065, the average
      # of the 20,520 in force to June and the 23,610 in force from July.
      frequency <- "irregular_interval"
      period <- month_end(current_year, documented_month_interval(label)[[2]])
    } else next
    interval_measure <- identical(frequency, "irregular_interval")
    for (jj in seq_along(data_cols)) {
      j <- data_cols[[jj]]; value <- numbers[r, j]
      if (is.na(value)) next
      series_label <- if (interval_measure) {
        documented_compact_path(c(column_labels[[jj]], "vigencia sub-anual"))
      } else column_labels[[jj]]
      k <- k + 1L
      records[[k]] <- documented_record(
        source_sheet, title, mode, period, label, frequency,
        series_label, "", series_label, value, r, j
      )
    }
  }
  observations <- documented_bind_records(records)
  # Keep the "provisional" or "revised" marker the month label carried, the same
  # way the horizontal extractor keeps the one on a year header. It is published
  # editorial information about the figure, and now that these rows parse at all
  # it would otherwise be discarded on the way in.
  if (nrow(observations)) {
    markers <- documented_month_footnote(text[, period_col])
    if (any(!is.na(markers))) observations$footnote_marker <- markers[observations$source_row]
  }
  observations
}

# The publisher's own arithmetic, used as the check on a year mapping that is
# otherwise only readable from two header rows at once.
#
# On a stock table the fourth quarter of a year *is* the year-end level, so the
# Q4 column and the annual column that closes the block must hold the same
# number on every row. If the mapping were shifted by one year -- which is
# exactly what reading the shared header row alone does -- Q4 would line up
# against the wrong annual column and this would fail on nearly every row.
#
# It is a hard stop rather than a warning because the failure it guards against
# is silent: 12,000 observations dated a year early look entirely ordinary. If a
# future workbook publishes flows in this layout, where the annual column is the
# sum of the quarters rather than the last of them, this will fire and a person
# will decide what the sheet means instead of the parser guessing.
documented_assert_quarter_block_closes <- function(numbers, year_values, quarter_values,
                                                   period_labels, source_sheet,
                                                   minimum_agreement = 0.9) {
  annual_cols <- which(!is.na(documented_year_values(period_labels)))
  fourth_cols <- which(!is.na(quarter_values) & quarter_values == 4L)
  if (!length(annual_cols) || !length(fourth_cols)) return(invisible(TRUE))
  compared <- 0L; agreed <- 0L
  for (annual in annual_cols) {
    closing <- fourth_cols[fourth_cols < annual]
    if (!length(closing)) next
    closing <- max(closing)
    # The Q4 immediately before the annual column, and only if it belongs to the
    # year that column is labelled with.
    if (!identical(year_values[[closing]], as.numeric(documented_year_values(period_labels)[[annual]]))) next
    left <- numbers[, closing]; right <- numbers[, annual]
    both <- !is.na(left) & !is.na(right)
    if (!any(both)) next
    compared <- compared + sum(both)
    agreed <- agreed + sum(abs(left[both] - right[both]) <=
                             1e-6 * pmax(abs(right[both]), 1))
  }
  if (!compared) return(invisible(TRUE))
  share <- agreed / compared
  if (share < minimum_agreement) stop(
    "Year-quarter block guard on ", source_sheet, ": the fourth quarter of a block matches the ",
    "annual column that closes it in only ", round(100 * share, 1), "% of ", compared,
    " comparable cells. On a stock table those are the same figure, so the year each quarter ",
    "block belongs to is not being read correctly, or this table publishes flows in a layout ",
    "the two-header reading does not describe.", call. = FALSE
  )
  invisible(TRUE)
}

documented_extract_horizontal_year_quarter <- function(text, numbers, source_sheet) {
  years <- documented_year_values(text)
  year_row <- documented_year_axis_index(text, margin = 1L)
  if (is.na(year_row)) return(documented_empty_observations())
  quarter_scores <- rowSums(!is.na(documented_quarter_number(text)))
  # A window with no quarter labels in it has no quarter axis, and must yield
  # nothing rather than a data row promoted to an axis.
  #
  # which.max over a vector of zeros returns the first candidate, so a sheet whose
  # quarter labels are not on any row below the year row silently took its first
  # *data* row as the period header. direct_investment Cuadro 5 and Cuadro 7 put
  # the year and its quarters on one row -- row 11 of Cuadro 5 reads 1995, I, II,
  # III, IV, 1996, I, ... across 147 columns -- so both failed this way, and the
  # failure was not a quiet omission. ALEMANIA's 1995 balance became a header,
  # every series was labelled with three of its own values, and all 72 surviving
  # rows were stamped 2024-12-31 in the single column that came through; Cuadro 7
  # produced 33 the same way. Those 105 rows are removed here.
  #
  # The two-header layout, now read.
  #
  # On these sheets the period axis is spread over two rows and neither is
  # sufficient alone. Row 10 carries a year above the *first* column of each
  # quarter block; row 11 carries the quarter numerals and, on the column that
  # closes each block, that block's year as an annual total. Reading row 11 alone
  # carries 1995 across the first four quarters, which dates every observation on
  # the sheet a year early. The publisher's own arithmetic settles it: these are
  # stock tables, so the fourth quarter of a block must equal the annual column
  # beside it, and ALEMANIA's 538,145.747 sits in Q4 of the first block and in
  # the annual column labelled 1996 -- not the 1995 that precedes it.
  #
  # So when the year row is also the quarter row, the quarters take their year
  # from the row above and the annual columns keep the year written on them, and
  # the Q4-equals-annual identity is asserted before anything is emitted.
  shared_header <- quarter_scores[[year_row]] > 0L
  below <- intersect(seq.int(year_row + 1L, min(nrow(text), year_row + 4L)), seq_len(nrow(text)))
  quarter_row <- if (shared_header) {
    year_row
  } else if (length(below) && max(quarter_scores[below]) > 0L) {
    below[[which.max(quarter_scores[below])]]
  } else {
    # A window with no quarter labels in it has no quarter axis, and must yield
    # nothing rather than a data row promoted to an axis: which.max over a vector
    # of zeros returns the first candidate, which is the first row of data.
    return(documented_empty_observations())
  }
  raw_year_values <- years[year_row, ]
  # The row above the shared header, where the year of each quarter block is
  # written. Absent on a single-header sheet, in which case the quarters carry
  # the year forward from the shared row exactly as before.
  block_year_values <- if (shared_header && year_row > 1L) {
    above <- rev(seq_len(year_row - 1L))
    candidate <- above[which(rowSums(!is.na(years[above, , drop = FALSE])) >= 2L)]
    if (length(candidate)) years[candidate[[1]], ] else rep(NA_real_, ncol(text))
  } else rep(NA_real_, ncol(text))
  year_values <- raw_year_values
  first_year_col <- min(which(!is.na(year_values)))
  for (j in seq.int(first_year_col, ncol(text))) {
    if (j > first_year_col && is.na(year_values[[j]])) year_values[[j]] <- year_values[[j - 1L]]
  }
  period_labels <- text[quarter_row, ]
  quarter_values <- documented_contextual_quarters(period_labels, raw_year_values)
  if (shared_header && any(!is.na(block_year_values))) {
    # Quarter columns take the block year stated above them; annual columns keep
    # the year written on the shared row.
    carried <- block_year_values
    first_block_col <- min(which(!is.na(carried)))
    for (j in seq.int(first_block_col, ncol(text))) {
      if (j > first_block_col && is.na(carried[[j]])) carried[[j]] <- carried[[j - 1L]]
    }
    quarter_cols <- !is.na(quarter_values) & !is.na(carried)
    year_values[quarter_cols] <- carried[quarter_cols]
    documented_assert_quarter_block_closes(
      numbers, year_values, quarter_values, period_labels, source_sheet
    )
  }
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
  # masquerading as a time axis. A few
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
  footnote_marker <- documented_year_footnote(text)[cbind(rep(year_row, length(source_columns)), source_columns)]
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
    source_column = as.integer(source_columns), footnote_marker = footnote_marker
  )
}

documented_extract_generic_sheet <- function(raw, source_sheet, mode_override = NA_character_,
                                             hierarchy_status = "unresolved", year_axis_minimum = NA_integer_,
                                             merge_ranges = parse_merge_ranges(NA_character_)) {
  text <- documented_text_matrix(raw)
  numbers <- documented_number_matrix(raw)
  dates <- documented_date_matrix(raw, text)
  mode <- if (!is.na(mode_override) && nzchar(mode_override)) mode_override else documented_mode(text, dates)
  observations <- switch(
    mode,
    vertical_date = documented_extract_vertical_date(text, numbers, dates, source_sheet, merge_ranges),
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

# One cache for every project config file, in 01_utils.R, so the ingestion layer
# and the documented parsers cannot hold two different views of the same edited
# file within one run.
documented_cached_config <- function(path, reader) project_cached_config(path, reader)

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
    note = NA_character_, year_axis_minimum = NA_integer_, continuation_group = NA_character_
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
  continuation_group <- if ("continuation_group" %in% names(rule)) {
    dplyr::na_if(rule$continuation_group[[1]], "")
  } else NA_character_
  list(
    parser_mode_override = dplyr::na_if(rule$parser_mode_override[[1]], ""),
    hierarchy_status = dplyr::coalesce(dplyr::na_if(rule$hierarchy_status[[1]], ""), "unresolved"),
    note = dplyr::na_if(rule$note[[1]], ""),
    year_axis_minimum = year_axis_minimum,
    continuation_group = continuation_group
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

# Parser modes whose period axis runs across columns. The structural slot used
# to disambiguate a repeated label must sit on the axis that is NOT the period
# axis: source_row for these modes, source_column for every other (vertical)
# mode. Getting it backwards pins the period and turns each column into its own
# one-observation series -- credit_question_quarter was missing from this list
# and produced 2,534 single-observation identities out of 2,805.
documented_horizontal_period_modes <- c(
  "horizontal_date", "horizontal_year", "horizontal_year_month", "horizontal_year_quarter",
  "credit_question_quarter", "credit_index_quarter"
)

documented_period_axis_is_horizontal <- function(parser_mode) {
  parser_mode %in% documented_horizontal_period_modes
}

# Slug a worksheet name for use inside series_id. janitor::make_clean_names() is
# deliberately applied one value at a time: given a vector it uniquifies
# duplicates BY POSITION (Datos, Datos_2, ... Datos_26), so the same sheet name
# would receive a different slug depending on where its series happened to fall
# in the identity table. Series identity would then shift for every downstream
# series as soon as the publisher inserted one column. The slug must depend only
# on the sheet name.
documented_sheet_slug <- function(source_sheet) {
  vapply(source_sheet, function(sheet) janitor::make_clean_names(sheet), character(1), USE.NAMES = FALSE)
}

documented_finalize_observations <- function(observations, item, release_id, publication_date) {
  if (!nrow(observations)) return(observations)
  # identity_sheet is the worksheet key that participates in series identity. It
  # equals source_sheet unless config/sheet_modes.csv declares a
  # continuation_group, i.e. the publisher split one continuous series across
  # several worksheets (bcp_fx_daily: one sheet per year). source_sheet itself is
  # never touched, so per-sheet lineage, drift and raw-cell paths are unaffected.
  if (!"identity_sheet" %in% names(observations)) observations$identity_sheet <- NA_character_
  observations$identity_sheet <- dplyr::coalesce(observations$identity_sheet, observations$source_sheet)
  observations <- observations %>%
    dplyr::filter(!is.na(.data$period), !is.na(.data$value), nzchar(.data$series_path)) %>%
    dplyr::mutate(
      identity_path = dplyr::if_else(
        !is.na(.data$exchange_item_id) & !is.na(.data$entity_id),
        paste(.data$exchange_item_id, .data$entity_id, sep = "|"), .data$series_path
      ),
      collision_key = paste(.data$identity_sheet, .data$frequency, .data$identity_path, sep = "|"),
      structural_slot = dplyr::if_else(
        documented_period_axis_is_horizontal(.data$parser_mode),
        paste0("row_", .data$source_row), paste0("column_", .data$source_column)
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
      axis_collision_key = paste(.data$identity_sheet, .data$frequency, .data$axis_path, sep = "|")
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
    dplyr::distinct(.data$identity_sheet, .data$frequency, .data$stable_path) %>%
    dplyr::mutate(
      identity_basis = paste(.data$identity_sheet, .data$frequency, .data$stable_path, sep = "|"),
      series_hash = substr(vapply(
        paste(.data$stable_path, .data$frequency, sep = "|"), digest::digest,
        character(1), algo = "sha256", serialize = FALSE
      ), 1L, 24L),
      series_id = paste0(
        item$source_id, ":", documented_sheet_slug(.data$identity_sheet), ":", .data$series_hash
      )
    ) %>%
    dplyr::select(-dplyr::all_of("series_hash"))
  observations <- observations %>%
    dplyr::left_join(
      identity_lookup,
      by = c("identity_sheet", "frequency", "stable_path"),
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
  # Only documented_extract_horizontal_year_month() populates footnote_marker
  # today (the one confirmed real case, CUADRO 57a); credit_survey and
  # exchange_houses skip documented_enrich_metadata() entirely (explicit
  # semantic contracts, see the comment at that call site) so they never see
  # price_base_year either. Default both here instead of touching every
  # parser, so the columns are always present without claiming knowledge
  # nothing upstream actually captured.
  if (!"footnote_marker" %in% names(observations)) observations$footnote_marker <- NA_character_
  if (!"price_base_year" %in% names(observations)) observations$price_base_year <- NA_character_
  expected <- c(
    "vintage_id", "release_id", "publication_date", "source_id", "source_file", "source_sheet",
    "table_title", "parser_mode", "series_id", "identity_basis", "identity_stability", "hierarchy_status",
    "period", "source_period_label", "frequency", "series_label", "series_path", "category", "measure",
    "question", "response", "entity_id", "exchange_item_id", "participant_id", "unit", "scale", "currency",
    "index_base", "value", "is_total", "source_row", "source_column", "footnote_marker", "price_base_year"
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
      # The published question number is what makes a row a question header, not
      # the emptiness of its value columns. Nine of the 73 header rows on this
      # worksheet carry a stray numeric in a period column -- "10,2 - Ganaderia"
      # carries thirteen. Requiring all(is.na(values)) made those rows fail the
      # test, so the header was consumed as a response of the previous question
      # and every response row of the block that followed inherited the wrong
      # question: Ganaderia's shares published under Agricultura, colliding with
      # Agricultura's own responses in the same quarter and forcing both onto
      # positional identities. A response label never begins with a digit, and a
      # real response row carries 46-54 values rather than one or two, so the
      # label pattern alone decides this safely (audit P0; R52).
      # The separator after the question number is not published consistently:
      # most headers read "18,1 - ..." but "18,2 ¿Cual sera..." has only a space,
      # so requiring a dash/dot/parenthesis missed it and question 18,2's answers
      # were published under 18,1. Accept a separator or plain whitespace. The
      # only other label on this worksheet that opens with a digit is the
      # footnote "1/ Los datos fueron empalmados...", which matches neither form.
      if (!documented_blank(label) && stringr::str_detect(
        label, "^[0-9]+(?:[.,][0-9]+)*(?:\\s*[-.)]|\\s)"
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

# CUADRO 61 -- "Compra / Venta de divisas en el mercado cambiario local".
#
# The generic extractor reads the date axis of this sheet correctly but never
# captures its two-level column header, so it names series from data rows: 170
# identities whose labels are concatenated numbers ("221174 - 2534436.331676 -
# ..."), all positional lanes. Right values, unusable identities.
#
# Published layout (verified against report_cell_values, 2,752 x 236 sheet):
#   row  10        "Compra" at the first value column, "Venta" at the second
#                  block; both span their five columns and must be filled right.
#   row  11        "Año" in column 1, then the institution for each column:
#                  Bancos comerciales | Casas de cambio | Financieras |
#                  Casas de cambios y financieras | Total, repeated per side.
#   column 1       the row axis, mixing three period kinds and their breakdowns:
#                  a bare year (an annual observation, and/or the anchor for the
#                  quarter rows below it), "1er. trim." .. "4to. trim.", and a
#                  typed month date. Every row between two period rows is a
#                  breakdown OF the period above it. From July 2015 the
#                  breakdown is two levels deep: an operation type (Spot y
#                  Efectivo, Arbitraje, Operación Nominal, Forward, Canje) and,
#                  under some of them, a dash-prefixed split by currency
#                  (- Dólar, - Euros, ...) or residency (- Residentes). The dash
#                  is the publisher's nesting marker, so "- Euros" means one
#                  thing under Arbitraje and another under Operación Nominal and
#                  the parent has to stay in the identity.
# Monthly CDA term panels publish one observation date for the whole worksheet,
# with maturity buckets down rows and institution/measure columns across them.
# They are dated curve snapshots, not generic time-axis tables or row events.
documented_parse_cda_curve_sheet <- function(raw, source_sheet) {
  text <- documented_text_matrix(raw)
  numbers <- documented_number_matrix(raw)
  if (nrow(text) < 12L || ncol(text) < 8L) stop(
    "CDA curve structure guard: worksheet is smaller than the supported layout: ",
    source_sheet, ".", call. = FALSE
  )

  title <- text[7, 1]
  period_label <- text[8, 1]
  if (documented_blank(title) || documented_blank(period_label)) stop(
    "CDA curve structure guard: title or 'Datos al' evidence is missing in A7:A8: ",
    source_sheet, ".", call. = FALSE
  )
  matched <- stringr::str_match(
    trimws(period_label),
    stringr::regex("^Datos\\s+al\\s+([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})$", ignore_case = TRUE)
  )
  if (is.na(matched[1, 1])) stop(
    "CDA curve period guard: A8 is not 'Datos al dd/mm/yyyy' in ", source_sheet,
    ": ", period_label, call. = FALSE
  )
  period <- as.Date(sprintf(
    "%04d-%02d-%02d", as.integer(matched[1, 4]), as.integer(matched[1, 3]),
    as.integer(matched[1, 2])
  ))
  if (is.na(period)) stop("CDA curve period guard: invalid date in A8: ", period_label, call. = FALSE)

  title_key <- normalize_semantic_label(title)
  is_rate <- stringr::str_detect(title_key, "tasas ponderadas de depositos a plazo")
  is_operations <- stringr::str_detect(title_key, "depositos a plazo") && !is_rate
  local_origin <- stringr::str_detect(title_key, "moneda local")
  foreign_origin <- stringr::str_detect(title_key, "moneda extranjera")
  if ((!is_rate && !is_operations) || local_origin == foreign_origin) stop(
    "CDA curve structure guard: unsupported A7 title/currency-origin evidence: ",
    title, call. = FALSE
  )
  origin_label <- if (local_origin) "MONEDA LOCAL" else "MONEDA EXTRANJERA"

  if (is_rate) {
    rate_header <- normalize_semantic_label(text[9, 8:9])
    labelled_header <- identical(rate_header, c("bancos", "financieras"))
    omitted_header <- all(is.na(rate_header))
    if (!labelled_header && !omitted_header) stop(
      "CDA rate structure guard: H9:I9 must be BANCOS/FINANCIERAS or both explicitly blank in ",
      source_sheet, ".", call. = FALSE
    )
    maturity_col <- 6L; display_col <- 7L; data_cols <- 8:9
    # CDA_ML_102021 omits both column labels. Retain its values without silently
    # borrowing semantics from adjacent sheets; explicit column labels keep the
    # unresolved identities separate until governed evidence maps them.
    institutions <- if (labelled_header) text[9, data_cols] else c("UNLABELED COLUMN H", "UNLABELED COLUMN I")
    measures <- rep("TASA PONDERADA", 2L)
    units <- rep("percent", 2L)
    identity_sheet <- "CDA_RATE_CURVE"
  } else {
    expected_measures <- c("cantidad de operaciones", NA_character_, "volumen captado", NA_character_)
    expected_institutions <- c("bancos", "financieras", "bancos", "financieras")
    if (!identical(normalize_semantic_label(text[10, 5:8]), expected_measures) ||
        !identical(normalize_semantic_label(text[11, 5:8]), expected_institutions)) stop(
      "CDA operations structure guard: E10:H11 do not match the published blocks in ",
      source_sheet, ".", call. = FALSE
    )
    maturity_col <- 3L; display_col <- 4L; data_cols <- 5:8
    institutions <- text[11, data_cols]
    measures <- c("CANTIDAD DE OPERACIONES", "CANTIDAD DE OPERACIONES",
                  "VOLUMEN CAPTADO", "VOLUMEN CAPTADO")
    # Counts are explicit. The volume title and stored numeric cells do not
    # establish one consistent scale across vintages, so never rescale here.
    units <- c("count", "count", "source_units", "source_units")
    identity_sheet <- "CDA_OPERATIONS_CURVE"
  }

  maturity <- text[, maturity_col]
  maturity_rows <- which(stringr::str_detect(
    trimws(maturity), "^(?:[+]\\s*)?[0-9]+\\s+D[IÍ]AS(?:\\s*[+])?$"
  ))
  if (!length(maturity_rows)) stop(
    "CDA curve structure guard: no published DÍAS maturity rows in ", source_sheet, ".",
    call. = FALSE
  )

  records <- list(); k <- 0L
  for (r in maturity_rows) for (z in seq_along(data_cols)) {
    j <- data_cols[[z]]
    value <- numbers[r, j]
    if (is.na(value)) next
    maturity_label <- text[r, maturity_col]
    display_label <- text[r, display_col]
    institution <- institutions[[z]]
    measure <- measures[[z]]
    series_label <- paste(
      origin_label, measure, institution, maturity_label, display_label, sep = " — "
    )
    k <- k + 1L
    records[[k]] <- documented_record(
      source_sheet, title, "cda_monthly_curve", period, period_label, "monthly",
      series_label, origin_label, measure, value, r, j
    )
    records[[k]]$unit <- units[[z]]
    records[[k]]$scale <- "units"
    # The publisher's currency-origin wording remains in category/series_path.
    # A single currency field cannot represent origin and reporting currency;
    # leave it unknown instead of collapsing those two concepts.
    records[[k]]$currency <- NA_character_
  }
  if (is_operations) {
    # Two worksheets contain numeric publisher cells outside the regular E:H
    # block. Retain them as explicitly unresolved observations rather than
    # dropping them or assigning semantics from neighbouring cells.
    extra_cols <- if (ncol(text) > max(data_cols)) seq.int(max(data_cols) + 1L, ncol(text)) else integer()
    extra_cols <- extra_cols[
      !documented_blank(text[11, extra_cols]) &
        colSums(!is.na(numbers[maturity_rows, extra_cols, drop = FALSE])) > 0L
    ]
    for (j in extra_cols) for (r in maturity_rows) {
      value <- numbers[r, j]
      if (is.na(value)) next
      measure <- text[11, j]
      series_label <- paste(
        origin_label, measure, "INSTITUTION NOT PUBLISHED", text[r, maturity_col],
        text[r, display_col], sep = " — "
      )
      k <- k + 1L
      records[[k]] <- documented_record(
        source_sheet, title, "cda_monthly_curve_unresolved_column", period, period_label,
        "monthly", series_label, origin_label, measure, value, r, j
      )
      records[[k]]$unit <- "source_units"
      records[[k]]$scale <- "units"
      records[[k]]$currency <- NA_character_
    }

    candidate_rows <- seq.int(min(maturity_rows), min(nrow(text), max(maturity_rows) + 1L))
    unlabeled_rows <- setdiff(candidate_rows, maturity_rows)
    for (r in unlabeled_rows) for (z in seq_along(data_cols)) {
      j <- data_cols[[z]]
      value <- numbers[r, j]
      if (is.na(value)) next
      measure <- measures[[z]]
      series_label <- paste(
        origin_label, measure, institutions[[z]], paste0("UNLABELED ROW ", r), sep = " — "
      )
      k <- k + 1L
      records[[k]] <- documented_record(
        source_sheet, title, "cda_monthly_curve_unresolved_row", period, period_label,
        "monthly", series_label, origin_label, measure, value, r, j
      )
      records[[k]]$unit <- units[[z]]
      records[[k]]$scale <- "units"
      records[[k]]$currency <- NA_character_
    }
  }
  observations <- documented_bind_records(records)
  if (!nrow(observations)) stop(
    "CDA curve structure guard: no numeric observations in ", source_sheet, ".",
    call. = FALSE
  )
  observations$identity_sheet <- identity_sheet
  list(
    observations = observations, mode = "cda_monthly_curve",
    hierarchy_status = "unresolved", raw_nonempty_cells = sum(!documented_blank(text)),
    title = title
  )
}

# Columns 12+ and the rows after the last period carry a stray duplicated block
# and the published footnotes; both are excluded by requiring an institution
# header on the column and a resolved period on the row.
documented_parse_fx_market_turnover <- function(raw, source_sheet) {
  text <- documented_text_matrix(raw)
  numbers <- documented_number_matrix(raw)
  dates <- documented_date_matrix(raw, text)
  if (nrow(text) < 12L || ncol(text) < 3L) stop(
    "FX-turnover guard: sheet is smaller than the published CUADRO 61 layout.", call. = FALSE
  )
  normalized <- matrix(normalize_semantic_label(text), nrow = nrow(text), ncol = ncol(text))
  side_rows <- which(
    rowSums(normalized == "compra", na.rm = TRUE) > 0L &
      rowSums(normalized == "venta", na.rm = TRUE) > 0L
  )
  if (!length(side_rows)) stop(
    "FX-turnover guard: no header row carries both Compra and Venta.", call. = FALSE
  )
  side_row <- side_rows[[1]]
  entity_row <- side_row + 1L
  if (entity_row > nrow(text) || !identical(normalized[entity_row, 1], "ano")) stop(
    "FX-turnover guard: the row below the Compra/Venta header does not start with 'Año'.", call. = FALSE
  )

  entity_labels <- stringr::str_squish(text[entity_row, ])
  entity_cols <- which(!documented_blank(entity_labels))
  entity_cols <- entity_cols[entity_cols > 1L]
  if (!length(entity_cols)) stop(
    "FX-turnover guard: no institution columns found under the Año header.", call. = FALSE
  )
  side_labels <- stringr::str_squish(text[side_row, ])
  filled_sides <- rep(NA_character_, ncol(text))
  current_side <- NA_character_
  for (j in seq_len(max(entity_cols))) {
    if (!documented_blank(side_labels[[j]])) current_side <- side_labels[[j]]
    filled_sides[[j]] <- current_side
  }
  value_cols <- entity_cols[!is.na(filled_sides[entity_cols])]
  sides_present <- unique(filled_sides[value_cols])
  if (length(sides_present) != 2L) stop(
    "FX-turnover guard: expected exactly two published sides, found ",
    length(sides_present), ".", call. = FALSE
  )

  title <- documented_table_title(text, seq_len(entity_row))
  row_years <- documented_year_values(text[, 1])
  row_quarters <- documented_quarter_number(text[, 1])
  records <- list(); k <- 0L
  anchor_year <- NA_integer_
  period <- as.Date(NA); frequency <- NA_character_
  period_label <- NA_character_
  parent <- NA_character_; detail <- NA_character_
  for (r in seq.int(entity_row + 1L, nrow(text))) {
    label <- stringr::str_squish(text[r, 1])
    values <- numbers[r, value_cols]
    has_values <- any(!is.na(values))
    row_date <- documented_as_date(dates[r, 1])
    if (!is.na(row_date)) {
      anchor_year <- lubridate::year(row_date)
      period <- month_end(anchor_year, lubridate::month(row_date))
      frequency <- "monthly"; period_label <- label
      parent <- "Total"; detail <- NA_character_
    } else if (!is.na(row_years[[r]])) {
      anchor_year <- row_years[[r]]
      period_label <- label; parent <- "Total"; detail <- NA_character_
      # A bare year with no values is only a section header for the month rows
      # below it. Clear the period so a following breakdown row cannot be
      # attributed to a period that was never published.
      if (!has_values) { period <- as.Date(NA); frequency <- NA_character_; next }
      period <- month_end(anchor_year, 12L); frequency <- "annual"
    } else if (!is.na(row_quarters[[r]])) {
      if (is.na(anchor_year)) next
      period <- quarter_end(anchor_year, row_quarters[[r]])
      frequency <- "quarterly"; period_label <- paste(anchor_year, label)
      parent <- "Total"; detail <- NA_character_
    } else if (!documented_blank(label) && has_values && !is.na(period)) {
      if (stringr::str_detect(label, "^[-–—]")) {
        if (is.na(parent)) stop(
          "FX-turnover guard: nested breakdown row ", r, " has no parent breakdown above it.", call. = FALSE
        )
        detail <- stringr::str_squish(stringr::str_remove(label, "^[-–—]\\s*"))
      } else {
        parent <- label; detail <- NA_character_
      }
    } else next
    if (!has_values || is.na(period)) next
    breakdown <- if (is.na(detail)) parent else paste(parent, detail, sep = " — ")
    for (j in value_cols) {
      value <- numbers[r, j]
      if (is.na(value)) next
      series_label <- paste(filled_sides[[j]], entity_labels[[j]], breakdown, sep = " — ")
      k <- k + 1L
      records[[k]] <- documented_record(
        source_sheet, title, "fx_market_turnover", period, period_label, frequency,
        series_label, "Mercado cambiario local", breakdown, value, r, j
      )
      records[[k]]$unit <- "USD"
      records[[k]]$scale <- "thousands"
      records[[k]]$currency <- "USD"
      records[[k]]$is_total <- identical(normalize_semantic_label(entity_labels[[j]]), "total") &&
        identical(normalize_semantic_label(breakdown), "total")
    }
  }
  observations <- documented_bind_records(records)
  if (!nrow(observations)) stop(
    "FX-turnover guard: the published layout was recognized but produced no observations.", call. = FALSE
  )
  if (dplyr::n_distinct(observations$frequency) < 2L) stop(
    "FX-turnover guard: expected annual, quarterly and monthly rows; found only ",
    paste(unique(observations$frequency), collapse = ", "), ".", call. = FALSE
  )
  # Every published cell must resolve to a distinct (series, period) on its own.
  # Without this the shared identity guard would silently absorb an unrecognized
  # nesting level into positional lanes instead of failing here -- which is how
  # the dash-prefixed currency splits stayed hidden under their operation type.
  ambiguous <- observations %>%
    dplyr::count(.data$series_label, .data$frequency, .data$period) %>%
    dplyr::filter(.data$n > 1L)
  if (nrow(ambiguous)) stop(
    "FX-turnover guard: ", nrow(ambiguous),
    " series/period pairs are published more than once; the row hierarchy is not fully resolved (e.g. ",
    ambiguous$series_label[[1]], " at ", ambiguous$period[[1]], ").", call. = FALSE
  )
  list(observations = observations, mode = "fx_market_turnover",
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
  # Every documented "latest" view in this file is built on this one, so this is
  # where the accepted-release boundary belongs. It was missing: schema 24 gave
  # the generic series path a release filter and left the documented path ranking
  # whatever had been committed, which meant "latest" answered two different
  # questions depending on which view a researcher happened to open.
  create_project_view(con, "v_documented_series_latest_snapshot", paste0(
    "SELECT * EXCLUDE(vintage_rank, source_ingested_at) FROM (SELECT d.*, ",
    "f.first_ingested_at AS source_ingested_at, dense_rank() OVER (PARTITION BY d.source_id ",
    "ORDER BY d.publication_date DESC NULLS LAST, f.first_ingested_at DESC NULLS LAST, d.vintage_id DESC) AS vintage_rank ",
    "FROM documented_series_snapshot d LEFT JOIN source_files f USING (vintage_id) ",
    "WHERE d.vintage_id IN (", accepted_release_vintages_sql(), ")) WHERE vintage_rank = 1"
  ))
  create_project_view(con, "v_economic_annex_latest", "SELECT * FROM v_documented_series_latest_snapshot WHERE source_id = 'economic_annex'")
  create_project_view(con, "v_payments_latest", paste0(
    "SELECT d.*, p.bic_code, p.legal_name AS participant_name, ",
    "p.participant_type FROM v_documented_series_latest_snapshot d LEFT JOIN dim_payment_participant p ",
    "USING (participant_id) WHERE d.source_id = 'payments'"
  ))
  create_project_view(con, "v_exchange_houses_latest", paste0(
    "SELECT d.*, e.entity_code, e.legal_name, ",
    "e.short_name, x.classification AS item_classification, x.item_label_normalized ",
    "FROM v_documented_series_latest_snapshot d LEFT JOIN dim_entity e USING (entity_id) ",
    "LEFT JOIN dim_exchange_item x USING (exchange_item_id) ",
    "WHERE d.source_id = 'exchange_houses'"
  ))
  create_project_view(con, "v_credit_survey_latest", "SELECT * FROM v_documented_series_latest_snapshot WHERE source_id = 'credit_survey'")
  create_project_view(con, "v_documented_series_catalogue", paste0(
    "SELECT series_id, source_id, source_sheet, ",
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
        results[[sheet]] <- if (identical(rule$parser_mode_override, "fx_market_turnover")) {
          documented_parse_fx_market_turnover(raw, sheet)
        } else {
          documented_extract_generic_sheet(
            raw, sheet, rule$parser_mode_override, rule$hierarchy_status, rule$year_axis_minimum,
            sheet_merge_ranges(dimensions, sheet)
          )
        }
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
        results[[sheet]] <- documented_extract_generic_sheet(
          raw, sheet, rule$parser_mode_override, rule$hierarchy_status, rule$year_axis_minimum,
          sheet_merge_ranges(dimensions, sheet)
        )
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
      raw, sheet, rule$parser_mode_override, rule$hierarchy_status, rule$year_axis_minimum,
      sheet_merge_ranges(dimensions, sheet)
    )
  }

  if (source_id == "lrm_auctions") for (sheet in dimensions$sheet_name) {
    results[[sheet]] <- documented_parse_row_events(
      read_source_sheet(sheet), sheet, "fecha subasta",
      c("plazos estandarizados", "plazos residuales"),
      "lrm_auction_tenor"
    )
  }

  if (source_id == "cda_curve") for (sheet in dimensions$sheet_name) {
    results[[sheet]] <- documented_parse_cda_curve_sheet(read_source_sheet(sheet), sheet)
  }

  if (source_id == "tcn_referential_daily") {
    documented_validate_daily_calendar_grid_workbook(dimensions)
    for (sheet in dimensions$sheet_name) {
      results[[sheet]] <- documented_parse_daily_calendar_grid(read_source_sheet(sheet), sheet)
    }
  }

  generic_sources <- c("direct_investment", "bcp_fx_daily",
                       "banking_indicators", "financial_indicators")
  if (source_id %in% generic_sources) for (sheet in dimensions$sheet_name) {
    raw <- read_source_sheet(sheet); rule <- documented_sheet_rule(root, source_id, sheet)
    if (identical(rule$parser_mode_override, "skip_metadata")) {
      results[[sheet]] <- documented_skipped_result(raw, "metadata_only")
    } else results[[sheet]] <- documented_extract_generic_sheet(
      raw, sheet, rule$parser_mode_override, rule$hierarchy_status, rule$year_axis_minimum,
      sheet_merge_ranges(dimensions, sheet)
    )
  }

  for (sheet in names(results)) {
    rule <- documented_sheet_rule(root, source_id, sheet)
    if (is.null(results[[sheet]]$hierarchy_status)) results[[sheet]]$hierarchy_status <- rule$hierarchy_status
    identity_sheet <- dplyr::coalesce(rule$continuation_group, sheet)
    results[[sheet]]$observations <- results[[sheet]]$observations %>%
      dplyr::mutate(
        hierarchy_status = results[[sheet]]$hierarchy_status,
        identity_sheet = identity_sheet
      )
  }
  observations <- dplyr::bind_rows(lapply(results, `[[`, "observations"))
  # The credit parser supplies an explicit semantic contract, including
  # intentional NA currency/index-base fields. All record-oriented parsers use
  # deferred inference; do not overwrite explicit NA semantics by guessing.
  if (!source_id %in% c("credit_survey", "exchange_houses", "cda_curve", "tcn_referential_daily")) {
    metadata_labels <- dplyr::if_else(
      stringr::str_detect(observations$parser_mode, "^row_event_"),
      observations$measure, observations$series_label
    )
    observations <- documented_enrich_metadata(observations, metadata_labels)
  }
  if (source_id == "payments") observations <- documented_attach_payment_participants(observations, payment_participants)
  if (is.na(publication_date) && nrow(observations) && source_id != "tcn_referential_daily") {
    set_source_publication_date(con, item$vintage_id, max(observations$period))
    publication_date <- settled_publication_date(con, item$vintage_id, max(observations$period))
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
    .data$identity_stability, .data$hierarchy_status, .data$price_base_year
  ) %>% dplyr::transmute(
    series_id, source_id = item$source_id, label = series_label, unit, scale, frequency, currency,
    index_base, hierarchy_level = "documented_table_series", parent_series_id = NA_character_,
    is_total, identity_basis, identity_stability, hierarchy_status,
    semantic_status = "documented_series", first_vintage_id = item$vintage_id, price_base_year
  )
  events <- write_sparse_series(
    con, observations %>% dplyr::transmute(series_id = .data$series_id, period = .data$period, value = .data$value),
    series_meta, item, publication_date
  )
  documented_create_views(con)
  list(curated_rows = nrow(observations), event_rows = events, publication_date = publication_date,
       source_sheet = NA_character_)
}
