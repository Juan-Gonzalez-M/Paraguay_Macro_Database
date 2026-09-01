# --- Measurement semantics, period bounds and availability -------------------
# The audit's section 6 asks for stock/flow, nominal/real, seasonal adjustment,
# transformation and valuation to be mandatory, and its section 4 for a numeric
# scale multiplier, explicit period bounds and an as-of availability interface.
#
# Two kinds of field are involved and they are treated differently on purpose.
#
# Determinate fields are derived. The scale vocabulary is a closed set of four
# magnitudes, so scale_multiplier is exact arithmetic, and it is the field that
# actually prevents the silent 1,000x error the audit warns about. unit_code is
# the published unit normalised to one token per unit.
#
# Judgement fields default to not_reviewed and are filled in only where the
# publisher states the answer in words. An honest not_reviewed plus a published
# completeness report is worth more to a researcher than a full column they
# cannot trust, and it is what the audit's own VERIFY discipline requires.
#
# The earlier version of this file went further and derived nothing at all,
# reasoning that a search of the 94 Annex *titles* for "desestacionalizado",
# "tendencia-ciclo" and "serie original" returned nothing. That was true and the
# conclusion was still wrong: the seasonal-adjustment status of the IMAEP block
# is written on the series *labels*, and the valuation basis of the trade tables
# is in their titles in the word FOB. The evidence was there; the search was in
# the wrong column. Every derivation now records the wording it relied on, so
# the difference between "the source says so" and "an economist checked" stays
# visible instead of being flattened into a populated column.

SERIES_SEMANTIC_COLUMNS <- c(
  "stock_flow", "nominal_real", "seasonal_adjustment", "transformation", "valuation"
)

# What the published text has to say before a field is filled in.
#
# The audit asks for these fields to be complete, and the honest answer for most
# series is still that no one has reviewed them. But "no evidence" was too
# strong: the first version of this file searched the 94 Annex *titles* and found
# nothing, while the seasonal-adjustment status of the IMAEP block is written on
# the series labels -- "IMAEP - Serie Original", "Servicios - Tendencia Ciclo".
# The publisher is stating it; the parser was looking in the wrong place.
#
# So each rule below fires only where the source says the thing in words, and
# records the words it relied on. That is not review -- a reviewer would also
# check the methodological note, the compilation basis and whether the label
# still means what it did ten years ago -- and it is never presented as review:
# the basis travels with the value in series_semantic_evidence, and
# v_series_measurement exposes it beside every field. A researcher can filter to
# reviewed only, derived only, or both, and can see the sentence behind each one.
#
# Patterns are matched against the published table title and series label after
# accent folding. A series matching more than one value in a family is left at
# not_reviewed: an ambiguous label is not evidence.
SERIES_SEMANTIC_DERIVATIONS <- list(
  stock_flow = list(
    stock = "saldo|a fin de|fin de(l)? periodo|fin de mes",
    flow  = "flujo"
  ),
  seasonal_adjustment = list(
    not_adjusted        = "serie original",
    trend_cycle         = "tendencia.?ciclo",
    seasonally_adjusted = "desestacionaliz"
  ),
  # The trade tables state their valuation basis in the title. FOB and CIF are
  # not interchangeable -- CIF includes freight and insurance, so an import
  # series valued CIF is not comparable with an export series valued FOB, and
  # differencing them is not a trade balance. 638 series say FOB in as many
  # words; none says CIF.
  valuation = list(
    fob          = "\\bfob\\b",
    cif          = "\\bcif\\b",
    market_value = "valor de mercado"
  )
)

# --- Economic dimensions ----------------------------------------------------
# The audit's P1: "model product, sector, instrument, currency, counterpart,
# valuation, seasonal adjustment and transformation as explicit dimensions --
# not worksheet/lane identity", and specifically "remodel ... detailed trade
# using explicit economic dimensions".
#
# On the eight foreign-trade worksheets those dimensions are published, just not
# where a database can use them. The direction of trade and the classification
# scheme are in the sheet title -- "Exportaciones por niveles de procesamiento",
# "Importaciones por tipo de bienes" -- and the customs regime is the second
# segment of the row label on Cuadros 52a and 52b. A researcher who wants every
# export series, or every series under the tourism regime, currently has to
# parse prose. After this they can filter a column.
#
# Dimensions live in their own table rather than as columns on dim_series. They
# are source-specific by nature -- trade has a regime, the interbank market has
# a maturity, the credit survey has a question -- and widening the series
# dimension for each family would leave most of it null most of the time. The
# long form also carries the published wording each value came from, exactly as
# series_semantic_evidence does, so nothing derived can pass as reviewed.
# The worksheets each family of dimensions applies to. Named rather than
# inferred: a title elsewhere in the Annex that happens to say "exportaciones" is
# not a detailed trade series, and labelling it as one would be the same mistake
# as reading a matching label as a matching concept. The source is named beside
# the sheets because worksheet names are not unique across sources -- the
# insurance annex also publishes sheets called "2.1" and "2.2".
TRADE_DIMENSION_SHEETS <- c(
  "Cuadro 46a", "Cuadro 46b", "Cuadro 51a", "Cuadro 51b",
  "Cuadro 52a", "Cuadro 52b", "Cuadro 53a", "Cuadro 53b"
)

FINANCIAL_INDICATOR_SHEETS <- c(
  "1.1", "1.2", "2.1", "2.2", "3.1", "3.2", "4", "5", "6", "7", "8"
)

SERIES_DIMENSION_DERIVATIONS <- list(
  trade_flow = list(scope = "title", source_id = "economic_annex",
                    sheets = TRADE_DIMENSION_SHEETS, values = list(
    export = "exportaciones", import = "importaciones"
  )),
  trade_classification = list(scope = "title", source_id = "economic_annex",
                              sheets = TRADE_DIMENSION_SHEETS, values = list(
    end_use_regime   = "uso interno y bajo el regimen de turismo",
    processing_level = "niveles de procesamiento",
    goods_type       = "tipo de bienes"
  )),
  trade_regime = list(scope = "label", source_id = "economic_annex",
                      sheets = TRADE_DIMENSION_SHEETS, values = list(
    tourism      = "regimen de turismo",
    domestic_use = "consumo interno",
    registered   = "importacion registrada"
  )),
  # The audit's P1: "researchers cannot infer whether a series is a rate, amount,
  # count or index from its label/metadata", with 464 duplicate-label groups
  # covering 1,014 of the 1,050 financial-indicator series.
  #
  # The cause is that the publisher reuses one portfolio taxonomy across two
  # different measures. Sheets 4 and 7 publish outstanding balances broken down
  # by maturity and portfolio; every other sheet publishes interest rates over
  # the same breakdown. Both therefore carry rows called "MN - Tasa Activa -
  # Comercial - Total", and nothing in the parsed label, unit or metadata said
  # which of the two a given series was.
  #
  # The publisher does say, in the table name: "Cuadro Nº 4 - Saldos desglosados
  # por plazo y cartera" against "Cuadro Nº 1.1 - Tasas de interés nominales".
  # The pattern is anchored to that name rather than searched for anywhere in the
  # title, because the rate tables also end with "Ponderación sobre saldos" --
  # they are weighted by balances, they do not report them.
  measure = list(scope = "title", source_id = "financial_indicators",
                 sheets = FINANCIAL_INDICATOR_SHEETS, values = list(
    rate               = "^cuadro n\\S* [0-9.]+ - tasas de interes",
    outstanding_amount = "^cuadro n\\S* [0-9.]+ - saldos"
  ))
)

# The published wording that justified each derived value, so the claim can be
# checked rather than taken. Kept short: the matched phrase in context, not the
# whole label.
SERIES_EVIDENCE_CONTEXT_CHARACTERS <- 90L

# The published scale vocabulary. Anything outside it must stay NULL rather than
# default to 1: a wrong multiplier is worse than a missing one.
SERIES_SCALE_MULTIPLIERS <- c(units = 1, thousands = 1e3, millions = 1e6, billions = 1e9)

apply_series_semantics <- function(con) {
  if (!DBI::dbExistsTable(con, "dim_series")) return(invisible(0L))
  cases <- paste(vapply(names(SERIES_SCALE_MULTIPLIERS), function(scale) paste0(
    "WHEN ", sql_string(scale), " THEN ", format(SERIES_SCALE_MULTIPLIERS[[scale]], scientific = FALSE)
  ), character(1)), collapse = " ")
  DBI::dbExecute(con, paste(
    "UPDATE dim_series SET scale_multiplier = CASE lower(trim(scale))", cases, "ELSE NULL END"
  ))
  # One token per unit, so PYG_per_USD and pyg_per_usd stop being two units.
  # The two review states the project already uses stay legible as codes.
  DBI::dbExecute(con, paste(
    "UPDATE dim_series SET unit_code = CASE",
    "WHEN unit IS NULL OR trim(unit) = '' THEN NULL",
    "WHEN lower(trim(unit)) = 'source_units' THEN 'UNRESOLVED_SOURCE_UNITS'",
    "WHEN lower(trim(unit)) = 'mixed_physical_units' THEN 'MIXED_PHYSICAL_UNITS'",
    "ELSE upper(trim(unit)) END"
  ))
  DBI::dbExecute(con, paste(
    "UPDATE dim_series SET nominal_real = CASE",
    "WHEN price_base_year IS NOT NULL AND trim(price_base_year) <> '' THEN 'real'",
    "ELSE 'not_reviewed' END"
  ))
  # An index number is a transformation of a level, and the unit says so
  # without any inference. Everything else waits for review.
  DBI::dbExecute(con, paste(
    "UPDATE dim_series SET transformation = CASE",
    "WHEN lower(trim(unit)) IN ('index', 'index_points') THEN 'index'",
    "ELSE 'not_reviewed' END"
  ))
  for (column in c("stock_flow", "seasonal_adjustment", "valuation")) {
    DBI::dbExecute(con, paste0(
      "UPDATE dim_series SET ", column, " = 'not_reviewed' WHERE ", column, " IS NULL"
    ))
  }
  derive_series_semantics_from_text(con)
  derive_series_dimensions(con)
  apply_series_period_bounds(con)
  create_semantic_views(con)
  invisible(TRUE)
}

# --- Irregular published intervals ------------------------------------------
# Period bounds are a function of the reference period and the frequency, and
# v_series_observations derives them for that reason: copying two dates onto 1.2
# million fact rows to serve a handful would be the wrong trade, and the previous
# release said so explicitly.
#
# One published shape is not a function of the frequency. CUADRO 11 carries the
# legal minimum wage in force over irregular within-year intervals -- "Enero
# /Junio", "Mayo/Diciembre", "Junio/Agosto" -- underneath the annual average.
# No frequency implies "1 January to 30 June 1980", so the opening date is read
# from the label the publisher printed and stored for those observations only.
# The closing date is already the period. Everything else keeps falling back to
# the derived bound.
apply_series_period_bounds <- function(con) {
  if (!database_object_exists(con, "series_period_bounds")) return(invisible(0L))
  if (!database_object_exists(con, "documented_series_snapshot")) return(invisible(0L))
  intervals <- DBI::dbGetQuery(con, paste(
    "SELECT DISTINCT series_id, period, source_period_label",
    "FROM", project_qualified_name("documented_series_snapshot"),
    "WHERE frequency = 'irregular_interval' AND source_period_label IS NOT NULL"
  ))
  bounds <- if (nrow(intervals)) {
    opening <- vapply(intervals$source_period_label, function(label) {
      documented_month_interval(label)[[1]]
    }, integer(1), USE.NAMES = FALSE)
    keep <- !is.na(opening) & !is.na(intervals$period)
    tibble::tibble(
      series_id = intervals$series_id[keep],
      period = as.Date(intervals$period[keep]),
      period_start = as.Date(sprintf(
        "%04d-%02d-01", lubridate::year(intervals$period[keep]), opening[keep]
      )),
      basis = "published_period_label",
      evidence = paste0(
        "The published period label ", sql_string(intervals$source_period_label[keep]),
        " names the interval this value was in force over."
      ),
      derived_at = Sys.time()
    )
  } else tibble::tibble(
    series_id = character(), period = as.Date(character()), period_start = as.Date(character()),
    basis = character(), evidence = character(), derived_at = as.POSIXct(character())
  )
  # An interval that closes before it opens would be a publication error the
  # parser must not paper over; documented_month_interval() already refuses one,
  # so reaching here with a start after the period means the label and the
  # period axis disagree and the release should stop.
  if (nrow(bounds) && any(bounds$period_start > bounds$period)) stop(
    "Period-bounds guard: an irregular interval starts after it ends.", call. = FALSE
  )
  DBI::dbExecute(con, paste("DELETE FROM", project_qualified_name("series_period_bounds")))
  if (nrow(bounds)) DBI::dbWriteTable(
    con, DBI::Id(schema = project_schema_for("series_period_bounds"),
                 table = "series_period_bounds"), bounds, append = TRUE
  )
  invisible(nrow(bounds))
}

# --- Derivation from published text -----------------------------------------
# Everything this writes is recorded twice: the value on dim_series, so existing
# queries keep working, and the value plus its basis and the wording it came from
# in series_semantic_evidence, so nothing derived can be mistaken for reviewed.
derive_series_semantics_from_text <- function(con) {
  if (!DBI::dbExistsTable(con, "series_semantic_evidence")) return(invisible(0L))
  text <- DBI::dbGetQuery(con, paste(
    "SELECT d.series_id, d.label,",
    "coalesce(any_value(n.table_title), '') AS table_title,",
    "coalesce(any_value(n.series_label), d.label, '') AS series_label",
    "FROM dim_series d LEFT JOIN documented_series_snapshot n USING (series_id)",
    "GROUP BY 1, 2"
  ))
  if (!nrow(text)) return(invisible(0L))
  haystack <- normalize_semantic_label(paste(
    text$table_title, coalesce_chr(text$series_label, text$label)
  ))

  rows <- list()
  for (field in names(SERIES_SEMANTIC_DERIVATIONS)) {
    values <- SERIES_SEMANTIC_DERIVATIONS[[field]]
    hits <- vapply(values, function(pattern) stringr::str_detect(haystack, pattern),
                   logical(length(haystack)))
    if (is.null(dim(hits))) hits <- matrix(hits, nrow = length(haystack))
    # An ambiguous label -- one that names two members of the same family -- is
    # not evidence for either of them.
    decided <- rowSums(hits) == 1L
    if (!any(decided)) next
    chosen <- names(values)[max.col(hits[decided, , drop = FALSE], ties.method = "first")]
    matched <- vapply(seq_along(chosen), function(i) {
      values[[chosen[[i]]]]
    }, character(1))
    rows[[field]] <- tibble::tibble(
      series_id = text$series_id[decided], field = field, value = chosen,
      basis = "published_label",
      evidence = semantic_evidence_snippet(haystack[decided], matched),
      derived_at = Sys.time()
    )
  }
  # nominal_real and transformation are already derived above, from the published
  # price base year and the published unit. They are recorded here too so that
  # every non-reviewed value in v_series_measurement carries its basis rather
  # than only the two families added later.
  derived_elsewhere <- DBI::dbGetQuery(con, paste(
    "SELECT series_id, 'nominal_real' AS field, nominal_real AS value,",
    "'price_base_year' AS basis,",
    "'Published price base year: ' || price_base_year AS evidence",
    "FROM dim_series WHERE nominal_real <> 'not_reviewed' AND price_base_year IS NOT NULL",
    "UNION ALL",
    "SELECT series_id, 'transformation', transformation, 'published_unit',",
    "'Published unit: ' || unit",
    "FROM dim_series WHERE transformation <> 'not_reviewed' AND unit IS NOT NULL"
  ))
  if (nrow(derived_elsewhere)) {
    derived_elsewhere$derived_at <- Sys.time()
    rows[["derived_elsewhere"]] <- tibble::as_tibble(derived_elsewhere)
  }

  evidence <- dplyr::bind_rows(rows)
  with_project_transaction(con, {
    DBI::dbExecute(con, "DELETE FROM series_semantic_evidence WHERE basis <> 'reviewed'")
    if (nrow(evidence)) DBI::dbWriteTable(con, "series_semantic_evidence", evidence, append = TRUE)
  })
  # Write the derived values back, but never over a reviewed one.
  for (field in names(SERIES_SEMANTIC_DERIVATIONS)) {
    DBI::dbExecute(con, paste0(
      "UPDATE dim_series SET ", field, " = (",
      "  SELECT e.value FROM series_semantic_evidence e",
      "  WHERE e.series_id = dim_series.series_id AND e.field = ", sql_string(field), ")",
      " WHERE ", field, " = 'not_reviewed' AND EXISTS (",
      "  SELECT 1 FROM series_semantic_evidence e",
      "  WHERE e.series_id = dim_series.series_id AND e.field = ", sql_string(field), ")"
    ))
  }
  invisible(nrow(evidence))
}

# The text each dimension family reads, scoped to the source and worksheets it
# was declared for. A series is looked up once per family rather than once
# overall, because the families do not share worksheets.
dimension_scope_text <- function(con, source_id, sheets) {
  DBI::dbGetQuery(con, paste(
    "SELECT series_id, any_value(source_sheet) AS source_sheet,",
    "any_value(table_title) AS table_title, any_value(series_label) AS series_label",
    "FROM", project_qualified_name("documented_series_snapshot"),
    "WHERE source_id =", sql_string(source_id),
    "AND source_sheet IN (", paste(vapply(sheets, sql_string, character(1)), collapse = ", "), ")",
    "GROUP BY 1"
  ))
}

derive_series_dimensions <- function(con) {
  if (!DBI::dbExistsTable(con, "series_dimension")) return(invisible(0L))
  text <- dimension_scope_text(con, "economic_annex", TRADE_DIMENSION_SHEETS)

  rows <- list()
  for (dimension in names(SERIES_DIMENSION_DERIVATIONS)) {
    rule <- SERIES_DIMENSION_DERIVATIONS[[dimension]]
    scope <- dimension_scope_text(con, rule$source_id, rule$sheets)
    if (!nrow(scope)) next
    haystack <- normalize_semantic_label(
      if (identical(rule$scope, "title")) scope$table_title else scope$series_label
    )
    haystack[is.na(haystack)] <- ""
    hits <- vapply(rule$values, function(pattern) stringr::str_detect(haystack, pattern),
                   logical(length(haystack)))
    if (is.null(dim(hits))) hits <- matrix(hits, nrow = length(haystack))
    # A title matching two values of the same dimension decides nothing. That is
    # the guard that keeps "Ponderación sobre saldos" on a rate table from
    # claiming the table reports balances.
    decided <- rowSums(hits) == 1L
    if (!any(decided)) next
    chosen <- names(rule$values)[max.col(hits[decided, , drop = FALSE], ties.method = "first")]
    matched <- vapply(chosen, function(value) rule$values[[value]], character(1))
    rows[[dimension]] <- tibble::tibble(
      series_id = scope$series_id[decided], dimension = dimension, value = chosen,
      basis = if (identical(rule$scope, "title")) "published_title" else "published_label",
      evidence = semantic_evidence_snippet(haystack[decided], matched),
      derived_at = Sys.time()
    )
  }

  # The product is what is left of the label once the regime segment is removed.
  # On Cuadros 52a and 52b the publisher appends the customs regime to the
  # product name; everywhere else the label is the product already.
  product <- trimws(sub("\\s*[—-]\\s*Importaci[oó]n.*$", "", text$series_label))
  keep <- nzchar(product)
  if (any(keep)) rows[["product"]] <- tibble::tibble(
    series_id = text$series_id[keep], dimension = "product", value = product[keep],
    basis = "published_label",
    evidence = paste0("Published row label: ", text$series_label[keep]),
    derived_at = Sys.time()
  )

  dimensions <- dplyr::bind_rows(rows)
  with_project_transaction(con, {
    DBI::dbExecute(con, "DELETE FROM series_dimension WHERE basis <> 'reviewed'")
    if (nrow(dimensions)) DBI::dbWriteTable(con, "series_dimension", dimensions, append = TRUE)
  })
  invisible(nrow(dimensions))
}

coalesce_chr <- function(x, y) {
  out <- x
  blank <- is.na(out) | !nzchar(trimws(out))
  out[blank] <- y[blank]
  ifelse(is.na(out), "", out)
}

# The matched phrase in its immediate context, so a reader sees the sentence the
# derivation rests on rather than a bare pattern.
semantic_evidence_snippet <- function(haystack, patterns) {
  vapply(seq_along(haystack), function(i) {
    location <- stringr::str_locate(haystack[[i]], patterns[[i]])
    if (any(is.na(location))) return(substr(haystack[[i]], 1L, SERIES_EVIDENCE_CONTEXT_CHARACTERS))
    half <- SERIES_EVIDENCE_CONTEXT_CHARACTERS %/% 2L
    from <- max(1L, location[[1, "start"]] - half)
    to <- min(nchar(haystack[[i]]), location[[1, "end"]] + half)
    paste0(
      if (from > 1L) "..." else "", substr(haystack[[i]], from, to),
      if (to < nchar(haystack[[i]])) "..." else ""
    )
  }, character(1))
}

create_semantic_views <- function(con) {
  # Period bounds. The database deliberately keeps `period` exactly as parsed --
  # it is part of the observation key and rewriting it would retire every
  # identifier in the catalogue. The mixed monthly convention the audit found
  # (587,516 observations on day 1, 256,487 on month end) is resolved here
  # instead: period_start and period_end describe the same interval whichever
  # convention the source used, so a join on them cannot lose observations or
  # shift a lag by a month.
  # A stored bound wins over a derived one. Only an irregular published interval
  # has one, so this changes nothing for any series whose frequency already says
  # what its interval is.
  bounds <- paste(
    "coalesce(b.period_start, CASE d.frequency",
    "  WHEN 'annual' THEN date_trunc('year', f.period)",
    "  WHEN 'semiannual' THEN CASE WHEN month(f.period) <= 6",
    "    THEN date_trunc('year', f.period)",
    "    ELSE date_trunc('year', f.period) + INTERVAL 6 MONTH END",
    "  WHEN 'quarterly' THEN date_trunc('quarter', f.period)",
    "  WHEN 'monthly' THEN date_trunc('month', f.period)",
    "  WHEN 'monthly_survey' THEN date_trunc('month', f.period)",
    "  ELSE f.period END) AS period_start,",
    "CASE d.frequency",
    "  WHEN 'annual' THEN date_trunc('year', f.period) + INTERVAL 1 YEAR - INTERVAL 1 DAY",
    "  WHEN 'semiannual' THEN CASE WHEN month(f.period) <= 6",
    "    THEN date_trunc('year', f.period) + INTERVAL 6 MONTH - INTERVAL 1 DAY",
    "    ELSE date_trunc('year', f.period) + INTERVAL 1 YEAR - INTERVAL 1 DAY END",
    "  WHEN 'quarterly' THEN date_trunc('quarter', f.period) + INTERVAL 3 MONTH - INTERVAL 1 DAY",
    "  WHEN 'monthly' THEN last_day(f.period)",
    "  WHEN 'monthly_survey' THEN last_day(f.period)",
    "  ELSE f.period END AS period_end"
  )
  # available_at is the vintage's publication date, falling back to the moment
  # the file was first ingested. It is never derived from the reference period:
  # that is precisely the inference that creates look-ahead bias.
  #
  # observation_status separates values that were already published from
  # period-end placeholders and projections carried in the same tables -- the
  # 535 Annex observations and 30 FX-operations rows dated after the release.
  # source_sheet is carried per observation, not per series. Twelve bcp_fx_daily
  # series legitimately span fourteen annual worksheets, so a series-level sheet
  # column would be wrong for them and any join through it would fan out. The
  # snapshot's (vintage_id, series_id, period) grain is a declared natural key --
  # validate_referential_integrity() enforces it -- so this join is exactly
  # one-to-one and adds the sheet without adding a row.
  # The one filtered base relation every published current view descends from,
  # and its unfiltered twin.
  #
  # This view used to read fact_series_events with no restriction at all. Its
  # accepted-release join was a LEFT JOIN whose only job was to populate
  # accepted_release_id, so a row belonging to no accepted release survived it
  # with a null label -- and the lint passed the view, and everything built on it,
  # because the body contained the word "releases". That is the audit's R6-01,
  # and it is why the lint now requires descent from a declared filtered base
  # relation rather than the presence of a word. The label stays; the filter is
  # what publishes.
  observations_body <- function(filter) paste(
    # first_ingested_release_id, not release_id.
    #
    # A vintage can belong to many releases -- release_sources is the bridge that
    # says so -- while source_files keeps one column, which is the bundle that
    # first ingested it. Exposing that as `release_id` beside an observation read
    # as the release context of the query, so a reused vintage reported the
    # release it arrived in rather than the one being read. The column is named
    # for what it is, and the release context of a query is the accepted release
    # the filter selected, which release_sources gives.
    "SELECT f.series_id, f.period,", bounds, ", f.value, f.vintage_id, f.publication_date,",
    "f.is_deleted, f.source_file, d.source_id, n.source_sheet,",
    "s.first_ingested_release_id, r.accepted_release_id,",
    "d.frequency, d.unit, d.unit_code,",
    "d.scale, d.scale_multiplier,",
    "CASE WHEN d.scale_multiplier IS NULL THEN NULL ELSE f.value * d.scale_multiplier END",
    "  AS value_in_base_units,",
    # available_at is when a researcher could first have had this figure. The
    # operator's recorded acquisition timestamp outranks the publication date,
    # which outranks the moment this project happened to ingest the file.
    "coalesce(CAST(p.available_at AS TIMESTAMP), CAST(f.publication_date AS TIMESTAMP),",
    "         s.first_ingested_at) AS available_at,",
    "CASE WHEN f.publication_date IS NOT NULL AND f.period > f.publication_date",
    "     THEN 'after_publication' ELSE 'observed' END AS observation_status",
    "FROM fact_series_events f",
    "JOIN dim_series d USING (series_id)",
    "LEFT JOIN source_files s ON s.vintage_id = f.vintage_id",
    "LEFT JOIN source_provenance p ON p.vintage_id = f.vintage_id",
    "LEFT JOIN (SELECT rs.vintage_id, max(rs.release_id) AS accepted_release_id",
    "           FROM release_sources rs JOIN releases rl USING (release_id)",
    "           WHERE rl.status = 'accepted' GROUP BY 1) r ON r.vintage_id = f.vintage_id",
    "LEFT JOIN documented_series_snapshot n ON n.vintage_id = f.vintage_id",
    "  AND n.series_id = f.series_id AND n.period = f.period",
    "LEFT JOIN series_period_bounds b ON b.series_id = f.series_id AND b.period = f.period",
    filter
  )
  create_project_view(con, "v_series_observations", observations_body(paste0(
    "WHERE f.vintage_id IN (", accepted_release_vintages_sql(), ")"
  )))
  create_project_view(con, "v_series_observations_all", observations_body(""))
  # The as-of interface the audit asks for. v_series_latest answers "what does
  # the publisher say today"; this answers "what could a researcher have known
  # on a given date", which is the question a forecast evaluation must ask. Both
  # are restricted to accepted releases: a release that ends blocked was never
  # knowable, so including it would be the same look-ahead error in a different
  # dimension.
  #
  # Realized observations only by default, for the same reason v_series_latest
  # is: an as-of query is asked precisely when look-ahead matters, so the default
  # must not be the one that leaks it. Pass include_projections := true to get the
  # publisher's full statement as of that date.
  as_of_body <- function(projection_predicate) paste(
    "AS TABLE",
    "WITH ranked AS (",
    "  SELECT *, row_number() OVER (PARTITION BY series_id, period",
    "    ORDER BY available_at DESC NULLS LAST, vintage_id DESC) AS rn",
    "  FROM v_series_observations WHERE available_at IS NOT NULL AND available_at <= as_of",
    projection_predicate,
    ")",
    "SELECT series_id, period, period_start, period_end, value, value_in_base_units,",
    "vintage_id, available_at, observation_status, source_id, frequency, unit_code,",
    "scale_multiplier FROM ranked WHERE rn = 1 AND NOT is_deleted"
  )
  create_project_macro(con, "series_as_of_date(as_of)", as_of_body(
    "    AND observation_status = 'observed'"
  ))
  create_project_macro(con, "series_statement_as_of_date(as_of)", as_of_body(""))
  # The projections, on their own, so "which of these are not outcomes" is a
  # query rather than a warning someone has to remember. Economic Annex CUADRO 49
  # is the bulk of it: the publisher's own monthly path to 2028, documented as
  # such, and indistinguishable from realized history in a plain value column.
  #
  # o.source_sheet, not a join. v_series_observations already carries the sheet
  # per observation, joined one-to-one on (vintage_id, series_id, period). The
  # join this replaces took DISTINCT (series_id, source_sheet) and matched on
  # series alone, so a series published across several worksheets -- twelve
  # bcp_fx_daily series span fourteen annual sheets -- was multiplied by the
  # number of its sheets. Latent today only because the current projections all
  # sit on one sheet each. The audit's R6-10; the same defect was found and fixed
  # in the grain catalogues one schema ago, and this copy was missed.
  create_project_view(con, "v_series_projections", paste(
    "SELECT o.series_id, o.period, o.value, o.value_in_base_units, o.vintage_id,",
    "o.publication_date, o.available_at, o.source_id, o.source_sheet, o.frequency,",
    "o.unit_code, d.label AS series_label",
    "FROM v_series_observations o JOIN dim_series d USING (series_id)",
    "WHERE o.observation_status = 'after_publication' AND NOT o.is_deleted"
  ), schema = "marts")
  # Every judgement field is published beside the basis it rests on, so a
  # researcher never has to guess whether a value was reviewed, read off the
  # published wording, or simply never looked at. 'not_reviewed' is a real
  # answer and is reported as one.
  basis_columns <- paste(vapply(SERIES_SEMANTIC_COLUMNS, function(field) paste0(
    "coalesce((SELECT e.basis FROM series_semantic_evidence e",
    " WHERE e.series_id = d.series_id AND e.field = ", sql_string(field), "),",
    " CASE WHEN d.", field, " = 'not_reviewed' THEN 'not_reviewed' ELSE 'unrecorded' END)",
    " AS ", field, "_basis"
  ), character(1)), collapse = ", ")
  create_project_view(con, "v_series_measurement", paste(
    "SELECT d.series_id, d.source_id, d.label, d.unit, d.unit_code, d.scale, d.scale_multiplier,",
    "d.currency, d.frequency, d.index_base, d.price_base_year, d.stock_flow, d.nominal_real,",
    "d.seasonal_adjustment, d.transformation, d.valuation, d.identity_stability,",
    "d.semantic_status,", basis_columns,
    "FROM dim_series d"
  ))
  create_project_view(con, "v_series_semantic_evidence", paste(
    "SELECT e.series_id, d.source_id, d.label, e.field, e.value, e.basis, e.evidence, e.derived_at",
    "FROM series_semantic_evidence e JOIN dim_series d USING (series_id)"
  ))
  # One row per series with its economic dimensions as columns, so a researcher
  # can filter on trade direction or customs regime instead of pattern-matching a
  # Spanish row label. The pivot names the dimensions this release derives;
  # v_series_dimension_evidence keeps the long form and the wording behind each.
  pivot <- paste(vapply(names(SERIES_DIMENSION_DERIVATIONS), function(dimension) paste0(
    "any_value(CASE WHEN dimension = ", sql_string(dimension), " THEN value END) AS ", dimension
  ), character(1)), collapse = ", ")
  create_project_view(con, "v_series_dimensions", paste(
    "SELECT series_id,",
    "any_value(CASE WHEN dimension = 'product' THEN value END) AS product,", pivot,
    "FROM series_dimension GROUP BY 1"
  ))
  create_project_view(con, "v_series_dimension_evidence", paste(
    "SELECT e.series_id, d.source_id, d.label, e.dimension, e.value, e.basis, e.evidence,",
    "e.derived_at FROM series_dimension e JOIN dim_series d USING (series_id)"
  ))
  invisible(TRUE)
}

# --- Expected observations, and why one is absent ----------------------------
#
# The audit's F-12. The parsers skip NA, so a period nobody published and a
# period the parser failed to read look identical from the outside: both are a
# row that is not there. A researcher cannot tell "the publisher reported
# nothing" from "this cell was dropped", and the two mean opposite things.
#
# So absence is given a reason. The expected grid is the regular sequence the
# series' own declared frequency implies, between the first and last period the
# series actually has -- never beyond, because a series that starts in 2015 was
# not "missing" 2014. Each expected period that has no observation is then
# classified against the raw cell layer, which is the only place that can tell a
# blank cell from a cell nobody visited.
# What the publisher can be saying when there is no number.
#
# The first version of this tested `raw_value_num IS NOT NULL` and called
# everything else blank, and the audit found what that cost: 18,416 of the 20,156
# supposed blanks are cells holding the text `s/m`. The publisher was answering
# the question -- sin movimiento, no operations in that period -- and the database
# recorded the answer as an absence of one. A blank cell and a stated "nothing
# happened" are different facts and, for an interest rate, they are opposite: one
# is unknown, the other says there was no rate to quote because nothing traded.
#
# So the text is read too, against config/source_value_tokens.csv. Anything the
# publisher writes that the register does not know stays `source_token_unreviewed`
# rather than being folded into blanks, which is what makes a new token visible
# the first time it appears instead of the release after someone notices.
OBSERVATION_MISSINGNESS_REASONS <- c(
  "blank_in_source",          # the cell is there in the workbook and is genuinely empty
  "no_movement",              # the publisher states that nothing happened in that period
  "not_available",            # the publisher states the datum is unavailable
  "suppressed",               # withheld, typically for confidentiality
  "formula_error",            # the workbook holds an error value at that cell
  "source_token_unreviewed",  # the cell holds text nobody has recorded the meaning of
  "unread_source_cell",       # the cell holds a number and the parser did not read it
  "period_absent_from_axis",  # the worksheet has no row or column for that period at all
  "axis_position_ambiguous",  # the worksheet places the period at several coordinates
  "unreviewed"                # none of the above could be established
)

# The statuses a token register may assign. `source_token_unreviewed` is not among
# them: it is what the classifier falls back to, never something a reviewer writes.
SOURCE_VALUE_TOKEN_STATUSES <- c(
  "no_movement", "not_available", "suppressed", "formula_error"
)

# Which absences stop a worksheet being promoted. A blank cell is an answer, and
# so is a token whose meaning a reviewer has recorded. A number nobody read, a
# coordinate that cannot be located, an unrecognised token and an absence nobody
# has explained are not.
OBSERVATION_MISSINGNESS_BLOCKING <- c(
  "unread_source_cell", "axis_position_ambiguous", "source_token_unreviewed", "unreviewed"
)

SOURCE_VALUE_TOKEN_COLUMNS <- c(
  "source_id", "source_sheet", "token", "status", "meaning", "evidence",
  "reviewed_by", "reviewed_at"
)

# What a token means is a claim about the publisher's convention, not about
# worksheet layout, so unlike the cell registers this one requires a *named*
# reviewer -- `layout_verified` cannot settle whether `s/m` means no movement or
# no data, and getting that wrong turns "nothing traded" into "unknown".
read_source_value_tokens <- function(root) {
  path <- file.path(root, "config", "source_value_tokens.csv")
  empty <- tibble::tibble(
    source_id = character(), source_sheet = character(), token = character(),
    status = character(), meaning = character(), evidence = character(),
    reviewed_by = character(), reviewed_at = as.Date(character())
  )
  if (!file.exists(path)) return(empty)
  rules <- readr::read_csv(
    path, col_types = readr::cols(.default = readr::col_character()), trim_ws = FALSE
  )
  if (!identical(names(rules), SOURCE_VALUE_TOKEN_COLUMNS)) stop(
    "Source-token guard: config/source_value_tokens.csv columns changed or are reordered.",
    call. = FALSE
  )
  if (!nrow(rules)) return(empty)
  for (field in setdiff(SOURCE_VALUE_TOKEN_COLUMNS, "source_sheet")) {
    rules[[field]] <- trimws(rules[[field]])
    if (any(is.na(rules[[field]]) | !nzchar(rules[[field]]))) stop(
      "Source-token guard: ", field, " is required on every row.", call. = FALSE
    )
  }
  invalid <- setdiff(rules$status, SOURCE_VALUE_TOKEN_STATUSES)
  if (length(invalid)) stop(
    "Source-token guard: unsupported status(es): ", paste(invalid, collapse = "; "),
    ". Allowed: ", paste(SOURCE_VALUE_TOKEN_STATUSES, collapse = ", "), ".", call. = FALSE
  )
  if (any(rules$reviewed_by %in% c("unreviewed", RECONCILIATION_LAYOUT_REVIEWER))) stop(
    "Source-token guard: what a published token means is a claim about the publisher's ",
    "convention and needs a named reviewer; '", RECONCILIATION_LAYOUT_REVIEWER,
    "' settles worksheet layout and cannot settle this.", call. = FALSE
  )
  thin <- nchar(rules$evidence) < RECONCILIATION_MINIMUM_EVIDENCE_CHARACTERS
  if (any(thin)) stop(
    "Source-token guard: every row must quote where the token appears and how often, so the ",
    "claim can be checked. ", sum(thin), " row(s) do not.", call. = FALSE
  )
  dates <- suppressWarnings(lubridate::ymd(rules$reviewed_at, quiet = TRUE))
  if (any(is.na(dates))) stop(
    "Source-token guard: reviewed_at must use valid YYYY-MM-DD dates.", call. = FALSE
  )
  rules$reviewed_at <- dates
  rules$token <- tolower(trimws(rules$token))
  if (anyDuplicated(paste(rules$source_id, rules$source_sheet, rules$token))) stop(
    "Source-token guard: two rows map the same source, sheet and token.", call. = FALSE
  )
  rules
}

# Only frequencies with a regular calendar grid. A daily series is not missing
# the weekends, and an irregular auction calendar has no expected period at all;
# inventing a grid for either would manufacture tens of thousands of false gaps,
# which is the opposite of what this is for.
EXPECTED_GRID_FREQUENCIES <- c("monthly", "quarterly", "annual")

expected_period_grid <- function(from, to, frequency) {
  anchor <- switch(
    frequency,
    monthly = lubridate::floor_date(from, "month"),
    quarterly = lubridate::floor_date(from, "quarter"),
    annual = lubridate::floor_date(from, "year")
  )
  step <- switch(frequency, monthly = 1L, quarterly = 3L, annual = 12L)
  months <- seq.int(0L, lubridate::interval(anchor, to) %/% months(1L), by = step)
  as.Date(lubridate::ceiling_date(anchor %m+% months(months), "month") - lubridate::days(1))
}

# Built here rather than inside apply_observation_missingness(), which returns
# early when there is nothing to compute. A database with no documented data then
# had no missingness mart at all, and the release lint could not check a view that
# did not exist. A published interface should exist whether or not it has rows.
# The audit's R6-13: "expose derived per-observation flags" for formula and
# hidden-row provenance.
#
# Schema 29 recorded both per worksheet, which is the right grain for the drift
# test -- a sheet that has begun hiding a block has changed behaviour -- and the
# wrong grain for a researcher holding a number. "15,403 observations come from
# hidden rows" is a fact about the database; "is *this* value one of them" was a
# question you could only answer by unpacking a range yourself.
#
# Derived, not stored: the hidden ranges are on the worksheet and the coordinate
# is on the observation, so the join is the answer and copying a flag onto 1.2
# million rows would only create something to keep in step.
create_observation_behaviour_view <- function(con) {
  if (!database_object_exists(con, "documented_series_snapshot")) return(invisible(FALSE))
  if (!database_object_exists(con, "source_sheets")) return(invisible(FALSE))
  if (!"hidden_rows" %in% table_column_names(con, "source_sheets")) return(invisible(FALSE))
  create_project_view(con, "v_observation_source_behaviour", paste(
    "WITH spans AS (",
    "  SELECT source_id, sheet_name, vintage_id,",
    "         TRY_CAST(split_part(span, '-', 1) AS BIGINT) AS row_from,",
    "         TRY_CAST(CASE WHEN span LIKE '%-%' THEN split_part(span, '-', 2)",
    "                       ELSE span END AS BIGINT) AS row_to",
    "  FROM (SELECT source_id, sheet_name, vintage_id,",
    "               unnest(string_split(hidden_rows, ';')) AS span",
    "        FROM source_sheets WHERE hidden_rows IS NOT NULL))",
    "SELECT o.series_id, o.period, o.vintage_id, o.source_id, o.source_sheet,",
    "       o.source_row, o.source_column,",
    "       EXISTS (SELECT 1 FROM spans s",
    "               WHERE s.vintage_id = o.vintage_id AND s.sheet_name = o.source_sheet",
    "                 AND o.source_row BETWEEN s.row_from AND s.row_to) AS from_hidden_row,",
    "       coalesce(h.formula_cells, 0) AS sheet_formula_cells,",
    "       h.hidden_rows AS sheet_hidden_rows, h.hidden_columns AS sheet_hidden_columns",
    "FROM documented_series_snapshot o",
    "LEFT JOIN source_sheets h",
    "  ON h.vintage_id = o.vintage_id AND h.sheet_name = o.source_sheet",
    "WHERE o.vintage_id IN (", accepted_release_vintages_sql(), ")"
  ), schema = "marts")
  invisible(TRUE)
}

create_missingness_views <- function(con) {
  if (!database_object_exists(con, "observation_missingness")) return(invisible(FALSE))
  # Published, so it carries the release boundary like everything else in marts:
  # a gap is only reportable for a vintage a researcher can actually read.
  #
  # It used to test `EXISTS (... WHERE l.series_id = m.series_id)`, which matched
  # on series alone. A gap computed from a staged or blocked vintage stayed
  # visible whenever the same series ID also existed in accepted data -- which,
  # for a rebuild of the same bundle, is every series. Since schema 30 the row
  # carries the vintage it was computed from, so the filter is the same one every
  # other published interface uses.
  create_project_view(con, "v_series_missingness", paste(
    "SELECT m.series_id, m.period, m.source_id, m.source_sheet, m.vintage_id, m.build_id,",
    "m.reason, m.source_token,",
    "t.meaning AS token_meaning, d.label AS series_label, d.frequency, d.unit_code",
    "FROM observation_missingness m JOIN dim_series d USING (series_id)",
    "LEFT JOIN source_value_tokens t ON t.source_id = m.source_id",
    "  AND (t.source_sheet = m.source_sheet OR t.source_sheet = ",
    sql_string(RECONCILIATION_UNBOUNDED), ") AND t.token = lower(trim(m.source_token))",
    "WHERE m.vintage_id IN (", accepted_release_vintages_sql(), ")"
  ), schema = "marts")
  invisible(TRUE)
}

observation_missingness_is_current <- function(con, build_id) {
  if (is.na(build_id)) return(FALSE)
  if (!DBI::dbExistsTable(con, "expected_observation_grid")) return(FALSE)
  if (!"build_id" %in% table_column_names(con, "expected_observation_grid")) return(FALSE)
  stored <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS rows, count(DISTINCT build_id) AS builds,",
    "min(build_id) AS build_id FROM",
    project_qualified_name("expected_observation_grid")
  ))
  if (!stored$rows[[1]] || stored$builds[[1]] != 1L) return(FALSE)
  identical(stored$build_id[[1]], build_id)
}

apply_observation_missingness <- function(con, root = NULL, build_id = NA_character_) {
  if (!DBI::dbExistsTable(con, "observation_missingness")) return(invisible(0L))
  # The audit's R6-16: this phase rebuilds a 2.4-million-row grid on every run and
  # is 19 of the 36 seconds a reuse build takes. It is skipped when it provably
  # cannot produce a different answer.
  #
  # "Provably" is doing real work, and the build identity is what makes it hold.
  # build_id hashes the release -- itself the hash of every source file -- plus
  # the code, configuration, environment and schema version. So a new vintage, an
  # edited token register, a changed frequency declaration or an edit to this
  # function all change it, and all force a full rebuild.
  #
  # A guard on "did any source change" would not have been enough: a run with
  # every source reused and new missingness logic would have kept the old answer,
  # which is how schema 22 first failed to land.
  #
  # The audit's own instruction was not to optimise before the release and
  # version semantics were right. They are now: the grid carries the build that
  # computed it, which is what makes this checkable at all.
  if (observation_missingness_is_current(con, build_id)) {
    return(invisible(DBI::dbGetQuery(con, paste(
      "SELECT count(*) AS n FROM", project_qualified_name("observation_missingness")
    ))$n[[1]]))
  }
  DBI::dbExecute(con, "DELETE FROM expected_observation_grid")
  DBI::dbExecute(con, "DELETE FROM observation_missingness")
  # The token register is loaded before the classification that reads it, so a
  # release always classifies against the register as it stands in config.
  if (DBI::dbExistsTable(con, "source_value_tokens")) {
    tokens <- if (is.null(root)) NULL else read_source_value_tokens(root)
    DBI::dbExecute(con, "DELETE FROM source_value_tokens")
    if (!is.null(tokens) && nrow(tokens)) {
      DBI::dbWriteTable(con, "source_value_tokens", tokens, append = TRUE)
    }
  }
  observed <- DBI::dbGetQuery(con, paste(
    "SELECT series_id, source_id, source_sheet, vintage_id, frequency, period,",
    "source_row, source_column FROM documented_series_snapshot",
    "WHERE source_row IS NOT NULL AND source_column IS NOT NULL AND frequency IN (",
    paste(vapply(EXPECTED_GRID_FREQUENCIES, sql_string, character(1)), collapse = ", "), ")"
  ))
  if (!nrow(observed)) return(invisible(0L))
  observed$period <- as.Date(observed$period)
  shape <- observed %>%
    dplyr::group_by(.data$series_id) %>%
    dplyr::summarise(
      source_id = dplyr::first(.data$source_id), source_sheet = dplyr::first(.data$source_sheet),
      vintage_id = dplyr::first(.data$vintage_id), frequency = dplyr::first(.data$frequency),
      first_period = min(.data$period), last_period = max(.data$period),
      observations = dplyr::n(),
      fixed_column = dplyr::n_distinct(.data$source_column) == 1L,
      fixed_row = dplyr::n_distinct(.data$source_row) == 1L,
      # The span of worksheet the series actually occupies. A sheet built from
      # repeated year blocks -- the exchange-rate histories stack 1970, 1971,
      # 1972 down the page and reuse the same COMPRA/VENTA columns in each --
      # gives one column to several series, so a period the column carries in
      # another block is not this series' missing period. Without the bound the
      # model reported 2,090 phantom gaps on EURO Prom alone.
      #
      # Computed before the scalar coordinates below, not after: summarise()
      # resolves a later .data$source_row to the column this same call has just
      # created, so min() over it would return that one value and the bound would
      # collapse to "the series' first row" -- which silently discarded 18,448
      # real financial-indicator gaps.
      axis_min = min(.data$source_row), axis_max = max(.data$source_row),
      cross_min = min(.data$source_column), cross_max = max(.data$source_column),
      source_row = dplyr::first(.data$source_row), source_column = dplyr::first(.data$source_column),
      .groups = "drop"
    ) %>%
    dplyr::filter(.data$observations > 1L, .data$fixed_column | .data$fixed_row)
  if (!nrow(shape)) return(invisible(0L))
  by_series <- split(observed$period, observed$series_id)
  grids <- vector("list", nrow(shape))
  for (i in seq_len(nrow(shape))) {
    row <- shape[i, ]
    grid <- expected_period_grid(row$first_period, row$last_period, row$frequency)
    # A series whose own periods do not all sit on the grid its frequency implies
    # is not regular, whatever the frequency column says. Asserting a grid over
    # it would report every one of its real periods as a gap.
    if (!all(by_series[[row$series_id]] %in% grid)) next
    # The vintage the grid was derived from travels with it. Without it the
    # missingness a mart publishes is a global snapshot that cannot be filtered
    # to accepted data -- v_series_missingness could only match on series_id, so
    # a gap computed from a staged or blocked vintage stayed visible whenever the
    # same series also existed in accepted data. The audit's R6-01.
    grids[[i]] <- tibble::tibble(
      series_id = row$series_id, period = grid, frequency = row$frequency,
      vintage_id = row$vintage_id, build_id = build_id
    )
  }
  grid_rows <- dplyr::bind_rows(grids)
  if (!nrow(grid_rows)) return(invisible(0L))
  DBI::dbWriteTable(con, "expected_observation_grid", grid_rows, append = TRUE)

  # Where the worksheet puts the period a series is missing. A vertical sheet
  # varies the period down the rows, so the series keeps its column and the
  # missing period names a row; a horizontal one is the transpose. Either way the
  # coordinate comes from the sheet's other series at that period, which is the
  # publisher's own layout rather than an assumption about it.
  #
  # On a worksheet with repeated year blocks -- the exchange-rate histories put
  # the same twelve months under 1970, 1971, 1972 and so on -- one period sits at
  # several coordinates, and picking one of them would name a cell belonging to a
  # different block. Taking the first row and calling the number in it unread is
  # exactly the wrong answer, so the ambiguity is recorded as itself.
  axis <- observed %>%
    dplyr::group_by(.data$vintage_id, .data$source_sheet, .data$period) %>%
    dplyr::summarise(
      axis_row = dplyr::first(.data$source_row), axis_column = dplyr::first(.data$source_column),
      distinct_rows = dplyr::n_distinct(.data$source_row),
      distinct_columns = dplyr::n_distinct(.data$source_column),
      .groups = "drop"
    )
  DBI::dbWriteTable(con, "missingness_axis_scratch", axis, temporary = TRUE, overwrite = TRUE)
  on.exit(try(
    DBI::dbExecute(con, "DROP TABLE IF EXISTS missingness_axis_scratch"), silent = TRUE
  ), add = TRUE)
  DBI::dbWriteTable(
    con, "missingness_shape_scratch",
    shape[c("series_id", "source_id", "source_sheet", "vintage_id",
            "fixed_column", "source_row", "source_column",
            "axis_min", "axis_max", "cross_min", "cross_max")],
    temporary = TRUE, overwrite = TRUE
  )
  on.exit(try(
    DBI::dbExecute(con, "DROP TABLE IF EXISTS missingness_shape_scratch"), silent = TRUE
  ), add = TRUE)
  # Named columns, not positional. The table gained vintage_id and build_id in
  # schema 30, and a positional INSERT would have silently shifted reason and
  # source_token into them.
  DBI::dbExecute(con, paste(
    "INSERT INTO observation_missingness",
    "(series_id, period, source_id, source_sheet, source_row, source_column,",
    " reason, source_token, vintage_id, build_id)",
    "WITH gaps AS (",
    "  SELECT g.series_id, g.period, s.source_id, s.source_sheet, s.vintage_id,",
    "         CASE WHEN s.fixed_column THEN a.axis_row ELSE s.source_row END AS source_row,",
    "         CASE WHEN s.fixed_column THEN s.source_column ELSE a.axis_column END AS source_column,",
    "         CASE WHEN s.fixed_column THEN a.distinct_rows ELSE a.distinct_columns END AS positions,",
    "         s.axis_min, s.axis_max, s.cross_min, s.cross_max",
    "  FROM expected_observation_grid g",
    "  JOIN missingness_shape_scratch s USING (series_id)",
    "  LEFT JOIN documented_series_snapshot o",
    "    ON o.series_id = g.series_id AND o.period = g.period",
    "  LEFT JOIN missingness_axis_scratch a",
    "    ON a.vintage_id = s.vintage_id AND a.source_sheet = s.source_sheet AND a.period = g.period",
    "  WHERE o.series_id IS NULL",
    ")",
    ", located AS (",
    "  SELECT gaps.* FROM gaps",
    # A cell that is already an observation is not a missing observation. On the
    # exchange-rate histories one column carries several disjoint year blocks
    # under one label -- EURO Prom column 5 holds 2003, 2009, 2015 and 2021 --
    # so the months in between resolve to cells that were read, as a different
    # series. That is a question about series identity, which the positional-lane
    # machinery already reports, and answering it here would have claimed 2,090
    # observations were lost when none were.
    "  LEFT JOIN documented_series_snapshot taken",
    "    ON taken.vintage_id = gaps.vintage_id AND taken.source_sheet = gaps.source_sheet",
    "   AND taken.source_row = gaps.source_row AND taken.source_column = gaps.source_column",
    "  WHERE taken.series_id IS NULL",
    # A coordinate outside the span the series occupies belongs to another block
    # of the same worksheet, so the period is not this series' at all. An absent
    # coordinate stays: not being able to place the period is itself a finding.
    "    AND (gaps.source_row IS NULL OR gaps.source_column IS NULL",
    "         OR (gaps.source_row BETWEEN gaps.axis_min AND gaps.axis_max",
    "             AND gaps.source_column BETWEEN gaps.cross_min AND gaps.cross_max))",
    ")",
    "SELECT located.series_id, located.period, located.source_id, located.source_sheet,",
    "       located.source_row, located.source_column,",
    "       CASE WHEN located.source_row IS NULL OR located.source_column IS NULL",
    "              THEN 'period_absent_from_axis'",
    "            WHEN located.positions > 1 THEN 'axis_position_ambiguous'",
    "            WHEN c.raw_value_num IS NOT NULL THEN 'unread_source_cell'",
    # A cell holding text is the publisher saying something, and what it says is
    # read from the register rather than assumed. Text that parses as a number is
    # a number the parser did not read, whatever its storage type.
    "            WHEN c.raw_value_text IS NULL OR trim(c.raw_value_text) = ''",
    "              THEN 'blank_in_source'",
    "            WHEN TRY_CAST(replace(trim(c.raw_value_text), ',', '') AS DOUBLE) IS NOT NULL",
    "              THEN 'unread_source_cell'",
    "            ELSE coalesce(t.status, 'source_token_unreviewed') END AS reason,",
    "       CASE WHEN c.raw_value_num IS NULL THEN nullif(trim(c.raw_value_text), '') END AS source_token,",
    "       located.vintage_id, ", if (is.na(build_id)) "NULL" else sql_string(build_id),
    "FROM located",
    "LEFT JOIN main.v_report_cells_a1 c",
    "  ON c.vintage_id = located.vintage_id AND c.source_sheet = located.source_sheet",
    " AND c.row_id = located.source_row AND c.column_id = located.source_column",
    "LEFT JOIN source_value_tokens t",
    "  ON t.source_id = located.source_id",
    " AND (t.source_sheet = located.source_sheet OR t.source_sheet = ",
    sql_string(RECONCILIATION_UNBOUNDED), ")",
    " AND t.token = lower(trim(c.raw_value_text))"
  ))
  # The grid is what the series' frequency implies; a period the layout shows is
  # not this series' at all is not an expected observation of it. Pruning them
  # keeps the invariant a reader needs -- every grid period is either an
  # observation or an absence with a reason -- instead of leaving a silent third
  # category that looks like unexplained loss.
  DBI::dbExecute(con, paste(
    "DELETE FROM expected_observation_grid g WHERE NOT EXISTS (",
    "  SELECT 1 FROM documented_series_snapshot o",
    "  WHERE o.series_id = g.series_id AND o.period = g.period",
    ") AND NOT EXISTS (",
    "  SELECT 1 FROM observation_missingness m",
    "  WHERE m.series_id = g.series_id AND m.period = g.period)"
  ))
  create_missingness_views(con)
  create_observation_behaviour_view(con)
  if (!is.null(root)) readr::write_csv(
    DBI::dbGetQuery(con, paste(
      "SELECT source_id, source_sheet, reason, count(*) AS periods,",
      "count(DISTINCT series_id) AS series FROM observation_missingness",
      "GROUP BY 1, 2, 3 ORDER BY periods DESC"
    )),
    file.path(root, "outputs", "observation_missingness_latest.csv")
  )
  invisible(DBI::dbGetQuery(con, "SELECT count(*) AS n FROM observation_missingness")$n[[1]])
}

# The reviewer's queue, and the audit's F-06 and F-13.
#
# 4,054 series with an unresolved unit, 13,649 without a stock/flow review and
# 14,386 without a nominal/real review is not a list anyone works through in
# order. It is worth working through by weight: a series carrying 3,000
# observations that a canonical concept already maps, whose worksheet is
# otherwise ready to promote, is worth an economist's hour in a way that a
# one-observation auction tender is not. Nothing here decides anything -- no
# reviewed value is ever written by the pipeline -- it only says what to look at
# first.
write_semantic_review_worklist <- function(con, root) {
  if (is.null(root) || !database_object_exists(con, "dim_series")) return(invisible(NULL))
  open_fields <- paste(vapply(SERIES_SEMANTIC_COLUMNS, function(field) paste0(
    "CASE WHEN d.", field, " IS NULL OR d.", field, " = 'not_reviewed' THEN 1 ELSE 0 END"
  ), character(1)), collapse = " + ")
  worklist <- tryCatch(DBI::dbGetQuery(con, paste(
    "SELECT d.series_id, d.source_id, n.source_sheet, d.label, d.frequency, d.unit_code,",
    "d.scale, d.series_grain, d.identity_stability,",
    paste0("(", open_fields, ") AS open_review_fields,"),
    "CASE WHEN d.unit_code = 'UNRESOLVED_SOURCE_UNITS' THEN 1 ELSE 0 END AS unresolved_unit,",
    "coalesce(x.observations, 0) AS observations, x.first_period, x.last_period,",
    "coalesce(t.status, 'unknown') AS review_status,",
    "coalesce(r.status, 'not measured') AS reconciliation_status,",
    "CASE WHEN m.series_id IS NULL THEN 0 ELSE 1 END AS mapped_to_canonical_series",
    "FROM", project_qualified_name("dim_series"), "d",
    "LEFT JOIN (SELECT DISTINCT series_id, source_id, source_sheet FROM",
    project_qualified_name("documented_series_snapshot"), ") n USING (series_id)",
    "LEFT JOIN (SELECT series_id, count(*) AS observations, min(period) AS first_period,",
    "  max(period) AS last_period FROM", project_qualified_name("fact_series_events"),
    "  WHERE NOT is_deleted GROUP BY 1) x ON x.series_id = d.series_id",
    "LEFT JOIN main.v_series_table_status t ON t.series_id = d.series_id",
    "  AND t.source_id = n.source_id AND t.source_sheet = n.source_sheet",
    "LEFT JOIN", project_qualified_name("table_reconciliation"), "r",
    "  ON r.source_id = n.source_id AND r.source_sheet = n.source_sheet",
    "LEFT JOIN (SELECT DISTINCT series_id FROM", project_qualified_name("map_canonical_series"),
    ") m ON m.series_id = d.series_id",
    "WHERE", paste0("(", open_fields, ") > 0"), "OR d.unit_code = 'UNRESOLVED_SOURCE_UNITS'",
    "ORDER BY mapped_to_canonical_series DESC, unresolved_unit DESC, observations DESC"
  )), error = function(e) NULL)
  if (is.null(worklist)) return(invisible(NULL))
  readr::write_csv(worklist, file.path(root, "outputs", "semantic_review_worklist.csv"))
  invisible(worklist)
}

# Coverage is reported rather than implied. A researcher can see exactly which
# measurement questions the database can answer today and which are open.
write_semantic_completeness_report <- function(con, root) {
  if (is.null(root)) return(invisible(NULL))
  fields <- c("unit_code", "scale_multiplier", SERIES_SEMANTIC_COLUMNS)
  rows <- lapply(fields, function(field) {
    populated <- if (identical(field, "scale_multiplier")) {
      paste0(field, " IS NOT NULL")
    } else {
      paste0(field, " IS NOT NULL AND ", field, " <> 'not_reviewed'")
    }
    counts <- DBI::dbGetQuery(con, paste0(
      "SELECT count(*) AS series, sum(CASE WHEN ", populated,
      " THEN 1 ELSE 0 END) AS populated FROM dim_series"
    ))
    # Derived and reviewed are counted apart. A single "populated" number would
    # let a column filled from published wording read as an economist's
    # judgement, which is the confusion this whole layer exists to prevent.
    split <- DBI::dbGetQuery(con, paste0(
      "SELECT count(*) FILTER (WHERE basis = 'reviewed') AS reviewed,",
      " count(*) FILTER (WHERE basis <> 'reviewed') AS derived",
      " FROM series_semantic_evidence WHERE field = ", sql_string(field)
    ))
    tibble::tibble(
      field = field, series = counts$series[[1]], populated = counts$populated[[1]],
      reviewed = split$reviewed[[1]], derived = split$derived[[1]],
      share_populated = round(counts$populated[[1]] / counts$series[[1]], 4),
      basis = if (field %in% c("unit_code", "scale_multiplier")) "derived from the published unit and scale"
              else if (identical(field, "nominal_real")) "derived where price_base_year is published"
              else if (identical(field, "transformation")) "derived where the unit is an index"
              else if (field %in% names(SERIES_SEMANTIC_DERIVATIONS))
                "derived where the published title or label states it; otherwise requires economic review"
              else "requires economic review; no evidence in the sources"
    )
  })
  report <- dplyr::bind_rows(rows)
  readr::write_csv(report, file.path(root, "outputs", "semantic_metadata_completeness.csv"))
  readr::write_csv(
    DBI::dbGetQuery(con, paste(
      "SELECT field, value, basis, count(*) AS series FROM series_semantic_evidence",
      "GROUP BY 1, 2, 3 ORDER BY 1, 4 DESC"
    )),
    file.path(root, "outputs", "semantic_evidence_summary.csv")
  )
  invisible(report)
}
