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
    # `serie ajustada` is the BCP's own wording, and it was the one variant of
    # the three this list did not read. CUADRO 9 a publishes `Serie Original`,
    # `Serie ajustada` and `Tendencia Ciclo` side by side for six IMAEP
    # aggregates; the first and third were derived and the middle six were left
    # not_reviewed, so the seasonally adjusted activity index -- the series a
    # macro model actually wants -- looked unreviewed while its neighbours did
    # not. The same error this whole list was written to fix, one word further
    # on: the publisher is stating it and the search was for a different word.
    #
    # `serie ajustad` and not `ajustad`: the shorter stem would eventually catch
    # an unrelated `ajustado por`, and matching two values in one family leaves
    # the field not_reviewed rather than guessing. Measured across all 13,985
    # labels, the phrase occurs six times and every one is an IMAEP variant.
    seasonally_adjusted = "desestacionaliz|serie ajustad"
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

# --- Reviewed unit and currency corrections ----------------------------------
# The readiness audit's ER-01, and the narrowest register that can close it.
#
# Units are inherited at worksheet level. A worksheet whose columns are not all
# in the same unit therefore mislabels every column on it, and the audit found
# the clear case: CUADRO 60c is a real-exchange-rate table titled
# "(enero 1995 = 100)" whose five index series -- IPC, TCN, TCR USA, TCR Br,
# TCR Arg -- were all tagged as a price of US dollars. Its sibling CUADRO 60b
# publishes the same series under the same labels and identity hashes, correctly
# coded INDEX with no currency, which is as close to a control case as a
# metadata defect gets. On CUADRO 60a the euro, Argentine-peso and Brazilian-real
# quotations all carried a US-dollar denominator; only one of the four columns
# can have one.
#
# Why this is not config/series_review.csv: that register asserts the whole
# economic record of a series -- definition, timing, stock/flow, comparability --
# and a row in it makes the series research-eligible. Correcting a unit is not a
# claim that anybody has reviewed the economics, and requiring the second in
# order to do the first would either block the correction or launder an unreviewed
# series onto the research surface. The narrow correction gets a narrow register.
#
# Why it runs *before* the derivations rather than after, which is the opposite
# of apply_series_review(): unit_code and transformation are pure functions of
# `unit`, recomputed on every build. Overriding the derived output would leave
# `unit` saying one thing and `unit_code` another; overriding the *input* makes
# every consequence follow coherently, and is what makes the corrected 60c row
# come out identical to the 60b row that was right all along.
UNIT_OVERRIDE_COLUMNS <- c(
  "series_id", "source_id", "source_sheet",
  "unit", "unit_code", "scale", "currency", "index_base",
  "evidence", "reviewed_by", "reviewed_at"
)

# The reviewer states the whole measurement, not a patch. A blank currency or
# index base means the series has none -- which is the answer for an index
# number, and the answer this register exists to be able to give. Everything
# else is required, because a row that leaves the unit or the scale unsaid is
# not a correction, it is a half-finished thought.
UNIT_OVERRIDE_REQUIRED_FIELDS <- c(
  "series_id", "source_id", "source_sheet", "unit", "unit_code", "scale",
  "evidence", "reviewed_by", "reviewed_at"
)

read_unit_override_register <- function(root) {
  empty <- tibble::as_tibble(stats::setNames(
    rep(list(character()), length(UNIT_OVERRIDE_COLUMNS)), UNIT_OVERRIDE_COLUMNS
  ))
  if (is.null(root)) return(empty)
  path <- file.path(root, "config", "unit_overrides.csv")
  if (!file.exists(path)) return(empty)
  register <- readr::read_csv(
    path, show_col_types = FALSE, col_types = readr::cols(.default = readr::col_character())
  )
  missing <- setdiff(UNIT_OVERRIDE_COLUMNS, names(register))
  if (length(missing)) stop(
    "Unit override register: missing column(s) ", paste(missing, collapse = ", "),
    call. = FALSE
  )
  register[UNIT_OVERRIDE_COLUMNS]
}

# The same normalisation apply_series_semantics() applies to every other series,
# written once so a reviewed unit and a parsed one cannot normalise differently.
normalize_unit_code <- function(unit) {
  unit <- trimws(as.character(unit))
  dplyr::case_when(
    is.na(unit) | !nzchar(unit) ~ NA_character_,
    tolower(unit) == "source_units" ~ "UNRESOLVED_SOURCE_UNITS",
    tolower(unit) == "mixed_physical_units" ~ "MIXED_PHYSICAL_UNITS",
    TRUE ~ toupper(unit)
  )
}

# Everything wrong with the register, as rows a person can work through -- the
# same shape series_review_problems() returns, so the release gate can report
# both the same way.
unit_override_problems <- function(register, known_series = tibble::tibble(
  series_id = character(), source_id = character(), source_sheet = character()
)) {
  if (!nrow(register)) return(tibble::tibble(series_id = character(), problem = character()))
  blank <- function(x) is.na(x) | !nzchar(trimws(x))
  problems <- list()
  add <- function(rows, problem) {
    if (any(rows)) problems[[length(problems) + 1L]] <<- tibble::tibble(
      series_id = register$series_id[rows], problem = problem
    )
  }
  for (field in UNIT_OVERRIDE_REQUIRED_FIELDS) {
    add(blank(register[[field]]), paste0("`", field, "` is blank and is required."))
  }
  add(duplicated(register$series_id), "the series appears more than once in the register.")
  add(
    !blank(register$unit_code) & !blank(register$unit) &
      register$unit_code != normalize_unit_code(register$unit),
    "`unit_code` is not the normalisation of `unit`; they would disagree after the build."
  )
  add(
    !blank(register$scale) & !tolower(trimws(register$scale)) %in% names(SERIES_SCALE_MULTIPLIERS),
    paste0(
      "`scale` is outside the published vocabulary (",
      paste(names(SERIES_SCALE_MULTIPLIERS), collapse = ", "),
      "), so the multiplier would be null and value_in_base_units unusable."
    )
  )
  # A correction aimed at a series that does not exist is not inert: it is a
  # correction that silently does nothing, which is the failure mode this whole
  # register exists to stop. Identity is positional on many worksheets, so a
  # rebuild can move it -- and the reviewer must be told, not quietly ignored.
  if (nrow(known_series)) {
    add(
      !register$series_id %in% known_series$series_id,
      "no series with this id exists, so the correction would silently apply to nothing."
    )
    placed <- merge(
      register[c("series_id", "source_id", "source_sheet")],
      known_series, by = "series_id", suffixes = c("", "_actual")
    )
    misplaced <- placed$series_id[
      placed$source_id != placed$source_id_actual |
        placed$source_sheet != placed$source_sheet_actual
    ]
    add(
      register$series_id %in% misplaced,
      "the recorded source or worksheet is not where this series actually lives."
    )
  }
  if (!length(problems)) return(tibble::tibble(series_id = character(), problem = character()))
  dplyr::bind_rows(problems)
}

# The series the register can be checked against: one row per series, with the
# worksheet it was read from. A series published across several worksheets --
# twelve bcp_fx_daily series span fourteen annual sheets -- is left out of the
# placement check rather than reported as misplaced against whichever sheet
# sorted first.
unit_override_series_placement <- function(con) {
  empty <- tibble::tibble(series_id = character(), source_id = character(), source_sheet = character())
  if (!database_object_exists(con, "documented_series_snapshot")) return(empty)
  tryCatch(DBI::dbGetQuery(con, paste(
    "SELECT series_id, any_value(source_id) AS source_id, any_value(source_sheet) AS source_sheet",
    "FROM", project_qualified_name("documented_series_snapshot"),
    "GROUP BY series_id HAVING count(DISTINCT source_sheet) = 1"
  )), error = function(e) empty)
}

apply_unit_overrides <- function(con, root) {
  if (!DBI::dbExistsTable(con, "dim_series")) return(invisible(0L))
  register <- read_unit_override_register(root)
  if (DBI::dbExistsTable(con, "unit_overrides")) {
    DBI::dbExecute(con, "DELETE FROM unit_overrides")
  }
  if (!nrow(register)) return(invisible(0L))
  # A register with a problem in it applies nothing, exactly as the series
  # review register behaves: a half-applied set of unit corrections is a
  # database in a state no reviewer ever approved. validate_unit_overrides()
  # reports the problems and blocks the release.
  if (nrow(unit_override_problems(register, unit_override_series_placement(con)))) {
    return(invisible(0L))
  }
  blank_to_na <- function(x) {
    x <- trimws(as.character(x))
    x[!nzchar(x)] <- NA_character_
    x
  }
  applied <- register %>% dplyr::transmute(
    series_id, source_id, source_sheet,
    unit = trimws(.data$unit), unit_code = trimws(.data$unit_code),
    scale = tolower(trimws(.data$scale)),
    currency = blank_to_na(.data$currency), index_base = blank_to_na(.data$index_base),
    evidence, reviewed_by, reviewed_at = suppressWarnings(as.Date(.data$reviewed_at))
  )
  if (DBI::dbExistsTable(con, "unit_overrides")) DBI::dbWriteTable(
    con, "unit_overrides",
    applied[c("series_id", "source_id", "source_sheet", "unit_code", "currency",
              "index_base", "evidence", "reviewed_by", "reviewed_at")] %>%
      dplyr::mutate(scale_multiplier = unname(SERIES_SCALE_MULTIPLIERS[applied$scale])),
    append = TRUE
  )
  for (i in seq_len(nrow(applied))) {
    DBI::dbExecute(con, paste0(
      "UPDATE ", project_qualified_name("dim_series"), " SET unit = ", sql_string(applied$unit[[i]]),
      ", scale = ", sql_string(applied$scale[[i]]),
      ", currency = ", if (is.na(applied$currency[[i]])) "NULL" else sql_string(applied$currency[[i]]),
      ", index_base = ", if (is.na(applied$index_base[[i]])) "NULL" else sql_string(applied$index_base[[i]]),
      " WHERE series_id = ", sql_string(applied$series_id[[i]])
    ))
  }
  invisible(nrow(applied))
}

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
  DBI::dbExecute(con, paste(
    "UPDATE dim_series SET nominal_real='nominal'",
    "WHERE source_id='cda_curve' AND unit='percent_per_annum'"
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
  apply_series_titles(con)
  create_semantic_views(con)
  invisible(TRUE)
}

# --- The economic review register --------------------------------------------
# The seventh audit's section 11.4, and the hole it names:
#
#   "Only after this review should a series enter marts.v_research_series or a
#    canonical cross-source concept."
#
# The gates for that have existed since schema 28 -- a series needs unit, scale,
# frequency, stock/flow, nominal/real and seasonal adjustment, with not_reviewed
# not counting. What did not exist was any way to satisfy them. Rows in
# series_semantic_evidence whose basis is 'reviewed' are deliberately preserved
# across every rebuild while derived rows are deleted and recomputed, and nothing
# in the codebase has ever written one. The project had an output worklist saying
# which series were unreviewed and no input for the answers.
#
# So this is the input. It ships empty, exactly as config/canonical_series.csv
# does, and it changes no observation until an economist fills it in. What it
# changes today is that filling it in is possible, and that a half-filled row
# blocks the release instead of half-promoting a series.
#
# The eleven properties section 11.4 requires, in the order it lists them.
SERIES_REVIEW_REQUIRED_FIELDS <- c(
  "series_id",
  "definition", "definition_evidence_uri",   # published definition and its evidence
  "source_semantics",                         # what the source table and row mean
  "frequency", "reference_period_convention", # frequency and reference-period convention
  "timing_basis",                             # end-of-period, average, cumulative
  "stock_flow",
  "unit_code", "scale_multiplier", "currency", "valuation",
  "nominal_real",
  "seasonal_adjustment",
  "transformation",
  "hierarchy_role",                           # total / component / standalone
  "comparability",                            # methodology breaks
  "availability_convention",                  # release and availability timing
  "reviewed_by", "reviewed_at"
)

# Required only when the answer above makes them meaningful. A base year on a
# nominal series is not extra rigour, it is a contradiction.
SERIES_REVIEW_CONDITIONAL_FIELDS <- c(
  "price_base_year", "parent_series_id", "methodology_regime_id"
)

# Closed vocabularies, matching the values the derivation layer already writes so
# that a reviewed answer and a derived one are the same kind of thing. An open
# vocabulary here would let two reviewers write "eop" and "end_of_period" and
# make the column unusable for exactly the automated transformation it exists to
# license.
SERIES_REVIEW_VOCABULARY <- list(
  stock_flow = c("stock", "flow"),
  nominal_real = c("nominal", "real"),
  seasonal_adjustment = c("not_adjusted", "seasonally_adjusted", "trend_cycle"),
  transformation = c("level", "index", "growth_rate", "contribution", "ratio"),
  valuation = c("market_value", "book_value", "face_value", "fob", "cif", "not_applicable"),
  timing_basis = c("end_of_period", "period_average", "period_total", "cumulative_to_date"),
  hierarchy_role = c("total", "component", "standalone"),
  comparability = c("comparable", "break_documented", "not_comparable")
)

read_series_review_register <- function(root) {
  columns <- c(SERIES_REVIEW_REQUIRED_FIELDS, SERIES_REVIEW_CONDITIONAL_FIELDS)
  empty <- tibble::as_tibble(stats::setNames(
    rep(list(character()), length(columns)), columns
  ))
  path <- file.path(root, "config", "series_review.csv")
  if (!file.exists(path)) return(empty)
  register <- readr::read_csv(
    path, show_col_types = FALSE, col_types = readr::cols(.default = readr::col_character())
  )
  # A malformed *file* stops the run; a malformed *row* blocks the release
  # through a flag. The difference matters: the first is a broken register that
  # nothing can interpret, the second is a reviewer's work in progress, and an
  # operator should be told which one they have.
  missing <- setdiff(columns, names(register))
  if (length(missing)) stop(
    "Series review register: missing column(s) ", paste(missing, collapse = ", "),
    ". The register declares the whole economic review of a series; a column that ",
    "is absent is a question nobody was asked.", call. = FALSE
  )
  register[columns]
}

# Everything wrong with the register, as rows a person can work through. A
# release blocks while any of them exists.
# Units that measure no currency. Used only to decide whether a three-letter
# `unit_code` is naming a currency, which is the one unit/currency contradiction
# worth blocking on: a series measured in USD that declares itself PYG.
SERIES_REVIEW_DIMENSIONLESS_UNITS <- c(
  "INDEX", "INDEX_POINTS", "PERCENT", "PROPORTION", "RATIO", "COUNT", "DAYS", "YEARS"
)

series_review_problems <- function(register, known_series = character(),
                                   known_frequencies = character()) {
  if (!nrow(register)) return(tibble::tibble(series_id = character(), problem = character()))
  blank <- function(x) is.na(x) | !nzchar(trimws(x))
  problems <- list()
  add <- function(rows, problem) {
    if (any(rows)) problems[[length(problems) + 1L]] <<- tibble::tibble(
      series_id = register$series_id[rows], problem = problem
    )
  }

  for (field in SERIES_REVIEW_REQUIRED_FIELDS) {
    add(blank(register[[field]]), paste0(field, " is blank and is required"))
  }
  # An identifier that names nothing is the failure mode a register of free text
  # invites: the review is real and attached to a series that does not exist, so
  # the gates it was meant to satisfy stay unsatisfied and nobody notices.
  if (length(known_series)) {
    add(
      !blank(register$series_id) & !register$series_id %in% known_series,
      "series_id does not name a series in this database"
    )
  }
  add(duplicated(register$series_id), "series_id is reviewed more than once")

  for (field in names(SERIES_REVIEW_VOCABULARY)) {
    allowed <- SERIES_REVIEW_VOCABULARY[[field]]
    add(
      !blank(register[[field]]) & !trimws(register[[field]]) %in% allowed,
      paste0(field, " must be one of: ", paste(allowed, collapse = ", "))
    )
  }
  add(
    !blank(register$scale_multiplier) & is.na(suppressWarnings(
      as.numeric(register$scale_multiplier)
    )),
    "scale_multiplier must be a number"
  )
  add(
    !blank(register$reviewed_at) & is.na(suppressWarnings(
      lubridate::ymd(register$reviewed_at, quiet = TRUE)
    )),
    "reviewed_at must be an ISO date (YYYY-MM-DD)"
  )
  # A definition nobody can check is not a definition. The same rule the
  # reconciliation rule register enforces on its evidence field.
  add(
    !blank(register$definition) &
      nchar(trimws(register$definition)) < RECONCILIATION_MINIMUM_EVIDENCE_CHARACTERS,
    paste0("definition must quote the publisher's own wording (at least ",
           RECONCILIATION_MINIMUM_EVIDENCE_CHARACTERS, " characters)")
  )

  # The conditional three.
  add(
    trimws(register$nominal_real) == "real" & blank(register$price_base_year),
    "price_base_year is required when nominal_real is 'real'"
  )
  add(
    trimws(register$hierarchy_role) == "component" & blank(register$parent_series_id),
    "parent_series_id is required when hierarchy_role is 'component'"
  )
  if (length(known_series)) {
    add(
      !blank(register$parent_series_id) & !register$parent_series_id %in% known_series,
      "parent_series_id does not name a series in this database"
    )
  }
  add(
    !blank(register$comparability) & trimws(register$comparability) != "comparable" &
      blank(register$methodology_regime_id),
    "methodology_regime_id is required when comparability is not 'comparable'"
  )

  # --- The seven the re-audit's section A7 asks for --------------------------
  # Each one passes vacuously on an empty register, which is the argument for
  # adding them now rather than after the first review is written.

  # 1. Frequency. It is required and was checked only for blankness, so any
  # string passed. The vocabulary is not invented here: it is the set of
  # frequencies the database actually holds, because a review naming a frequency
  # no series has is a review of something that is not in front of the reviewer.
  if (length(known_frequencies)) add(
    !blank(register$frequency) & !trimws(register$frequency) %in% known_frequencies,
    paste0("frequency must be one this database uses: ",
           paste(sort(known_frequencies), collapse = ", "))
  )

  # 2. Scale. "Is a number" admitted 0 and negatives, and a scale multiplier is
  # a factor to base units: zero would erase the series and a negative would
  # invert its sign, silently, in value_in_base_units.
  scale_numeric <- suppressWarnings(as.numeric(register$scale_multiplier))
  add(
    !blank(register$scale_multiplier) & !is.na(scale_numeric) &
      (scale_numeric <= 0 | !is.finite(scale_numeric)),
    "scale_multiplier must be a finite number greater than zero"
  )

  # 3. Base year. Presence was required when nominal_real is 'real'; the column
  # is free text, so "banana" satisfied it.
  base_year <- suppressWarnings(as.integer(register$price_base_year))
  add(
    !blank(register$price_base_year) &
      (is.na(base_year) | !grepl("^[0-9]{4}$", trimws(register$price_base_year)) |
         base_year < 1900L | base_year > as.integer(format(Sys.Date(), "%Y")) + 1L),
    "price_base_year must be a four-digit year between 1900 and next year"
  )

  # 4. Hierarchy. A series that is its own parent passed every check, because
  # known_series contains the row's own identifier. Aggregating a total into
  # itself is the arithmetic that follows.
  add(
    !blank(register$parent_series_id) &
      trimws(register$parent_series_id) == trimws(register$series_id),
    "parent_series_id is the series itself"
  )
  parents <- stats::setNames(trimws(register$parent_series_id), trimws(register$series_id))
  parents <- parents[!is.na(parents) & nzchar(parents)]
  in_cycle <- vapply(trimws(register$series_id), function(start) {
    seen <- character()
    node <- start
    while (!is.na(node) && nzchar(node) && node %in% names(parents)) {
      if (node %in% seen) return(TRUE)
      seen <- c(seen, node)
      node <- unname(parents[[node]])
    }
    FALSE
  }, logical(1), USE.NAMES = FALSE)
  add(in_cycle, "the hierarchy declared in this register contains a cycle")

  # 5. Unit and currency. Narrow on purpose: a three-letter unit code that is not
  # one of the dimensionless measures is naming a currency, and it must be the
  # currency the row declares. An index of guaraní prices legitimately carries a
  # currency context, so nothing is said about that case.
  unit_upper <- toupper(trimws(register$unit_code))
  names_a_currency <- !blank(register$unit_code) & grepl("^[A-Z]{3}$", unit_upper) &
    !unit_upper %in% SERIES_REVIEW_DIMENSIONLESS_UNITS
  add(
    names_a_currency & !blank(register$currency) &
      unit_upper != toupper(trimws(register$currency)),
    "unit_code names a currency that contradicts the declared currency"
  )

  # 6. A review dated in the future has not happened.
  reviewed_on <- suppressWarnings(lubridate::ymd(register$reviewed_at, quiet = TRUE))
  add(!is.na(reviewed_on) & reviewed_on > Sys.Date(), "reviewed_at is in the future")

  # 7. Reviewed evidence reaching the research interface is enforced where it can
  # be seen -- validate_research_eligibility_metadata() in scripts/04_validate.R,
  # which raises research_series_evidence_not_reviewed. It is not a property of
  # a register row in isolation, so it is not checked here.

  if (!length(problems)) return(tibble::tibble(series_id = character(), problem = character()))
  dplyr::bind_rows(problems) %>% dplyr::arrange(.data$series_id, .data$problem)
}

# The frequencies this database actually holds. Not a constant, because the two
# lists the project already has disagree -- EXPECTED_GRID_FREQUENCIES is
# monthly/quarterly/annual, the marts gap screen also accepts semiannual, and
# dim_series additionally holds irregular_daily. Rather than invent a third list
# or silently pick one, the register is checked against what is in front of the
# reviewer. Reconciling those two is a real defect and a separate one.
known_series_frequencies <- function(con) {
  if (!database_object_exists(con, "dim_series")) return(character())
  sort(stats::na.omit(DBI::dbGetQuery(con, paste(
    "SELECT DISTINCT frequency FROM", project_qualified_name("dim_series"),
    "WHERE frequency IS NOT NULL AND trim(frequency) <> ''"
  ))$frequency))
}

# Load the register, and let a reviewed answer outrank every derived one.
#
# Runs after apply_series_semantics(), never before. Those derivations include
# unconditional UPDATEs -- unit_code from unit, nominal_real from the price base
# year, transformation from the unit -- which would overwrite a reviewed value if
# review came first. Ordering review last makes "reviewed wins" true by
# construction rather than by each derivation remembering to check.
apply_series_review <- function(con, root) {
  if (!database_object_exists(con, "series_review")) return(invisible(0L))
  register <- read_series_review_register(root)
  known <- if (database_object_exists(con, "dim_series")) DBI::dbGetQuery(
    con, paste("SELECT series_id FROM", project_qualified_name("dim_series"))
  )$series_id else character()
  problems <- series_review_problems(register, known, known_series_frequencies(con))
  # A register with a problem in it applies nothing. Loading the good rows and
  # reporting the bad ones would promote half a review, which is the state the
  # gate exists to prevent.
  usable <- if (nrow(problems)) register[0, ] else register

  rows <- usable %>% dplyr::transmute(
    series_id = trimws(.data$series_id), definition = trimws(.data$definition),
    definition_evidence_uri = trimws(.data$definition_evidence_uri),
    source_semantics = trimws(.data$source_semantics), frequency = trimws(.data$frequency),
    reference_period_convention = trimws(.data$reference_period_convention),
    timing_basis = trimws(.data$timing_basis), stock_flow = trimws(.data$stock_flow),
    unit_code = toupper(trimws(.data$unit_code)),
    scale_multiplier = as.numeric(.data$scale_multiplier),
    currency = trimws(.data$currency), valuation = trimws(.data$valuation),
    nominal_real = trimws(.data$nominal_real),
    price_base_year = dplyr::na_if(trimws(.data$price_base_year), ""),
    seasonal_adjustment = trimws(.data$seasonal_adjustment),
    transformation = trimws(.data$transformation),
    hierarchy_role = trimws(.data$hierarchy_role),
    parent_series_id = dplyr::na_if(trimws(.data$parent_series_id), ""),
    methodology_regime_id = dplyr::na_if(trimws(.data$methodology_regime_id), ""),
    comparability = trimws(.data$comparability),
    availability_convention = trimws(.data$availability_convention),
    reviewed_by = trimws(.data$reviewed_by),
    reviewed_at = suppressWarnings(lubridate::ymd(.data$reviewed_at, quiet = TRUE))
  )

  with_project_transaction(con, {
    DBI::dbExecute(con, "DELETE FROM series_review")
    if (nrow(rows)) DBI::dbWriteTable(con, "series_review", rows, append = TRUE)
    # The evidence rows. Written with basis = 'reviewed' and the reviewer's own
    # sentence, so v_series_measurement keeps showing the difference between "the
    # publisher's label says so" and "an economist checked" -- which is the whole
    # design of that column and the reason this could not be done by simply
    # filling in dim_series.
    if (database_object_exists(con, "series_semantic_evidence")) {
      DBI::dbExecute(con, "DELETE FROM series_semantic_evidence WHERE basis = 'reviewed'")
      # The union, so the two lists cannot drift apart.
      #
      # They already had. `frequency` is a research-eligibility field and the
      # register carries it and writes it to dim_series, but it was absent from
      # this vector -- so no reviewed evidence was ever recorded for it. Harmless
      # while nothing read the evidence, and immediately fatal once schema 36
      # made the gate read it: a fully completed review could not satisfy the
      # check it was written to satisfy. Found by the test, not by reasoning.
      fields <- union(
        RESEARCH_ELIGIBILITY_FIELDS,
        c("unit_code", "scale_multiplier", SERIES_SEMANTIC_COLUMNS)
      )
      if (nrow(rows)) {
        evidence <- dplyr::bind_rows(lapply(fields, function(field) tibble::tibble(
          series_id = rows$series_id, field = field, value = as.character(rows[[field]]),
          basis = "reviewed",
          evidence = paste0(
            rows$reviewed_by, " (", rows$reviewed_at, "): ", rows$definition,
            " Source: ", rows$definition_evidence_uri
          ),
          derived_at = Sys.time()
        )))
        # Reviewed rows replace derived ones for the same (series_id, field);
        # the primary key means they cannot coexist, and the delete above cleared
        # only the reviewed side, so the derived twin goes now.
        if (nrow(evidence)) {
          DBI::dbExecute(con, paste0(
            "DELETE FROM series_semantic_evidence WHERE series_id IN (",
            paste(vapply(unique(rows$series_id), sql_string, character(1)), collapse = ", "),
            ") AND field IN (",
            paste(vapply(fields, sql_string, character(1)), collapse = ", "), ")"
          ))
          DBI::dbWriteTable(con, "series_semantic_evidence", evidence, append = TRUE)
        }
      }
    }
    # And the values themselves, onto dim_series, where every existing query
    # already reads them.
    if (nrow(rows)) DBI::dbExecute(con, paste(
      "UPDATE dim_series SET",
      "unit_code = r.unit_code, scale_multiplier = r.scale_multiplier,",
      "frequency = r.frequency, currency = r.currency,",
      "price_base_year = coalesce(r.price_base_year, dim_series.price_base_year),",
      "stock_flow = r.stock_flow, nominal_real = r.nominal_real,",
      "seasonal_adjustment = r.seasonal_adjustment, transformation = r.transformation,",
      "valuation = r.valuation,",
      "parent_series_id = coalesce(r.parent_series_id, dim_series.parent_series_id),",
      "is_total = (r.hierarchy_role = 'total'),",
      "hierarchy_status = CASE WHEN r.hierarchy_role = 'standalone' THEN 'flat' ELSE 'resolved' END",
      "FROM", project_qualified_name("series_review"), "r",
      "WHERE r.series_id = dim_series.series_id"
    ))
  })
  create_series_review_views(con)
  invisible(nrow(rows))
}

# In main, not marts, and the distinction is the contract's own: marts publishes
# observations under a release boundary, and every marts object is `current` or
# `all`. This describes *series* and carries no vintage, which is what the nine
# other `reference` objects -- v_series_measurement, v_series_semantic_evidence,
# v_series_table_status -- have in common with it.
create_series_review_views <- function(con) {
  if (!database_object_exists(con, "series_review")) return(invisible(FALSE))
  create_project_view(con, "v_series_review", paste(
    "SELECT r.*, d.source_id, d.label AS series_label, d.series_grain",
    "FROM", project_qualified_name("series_review"), "r",
    "JOIN", project_qualified_name("dim_series"), "d USING (series_id)"
  ))
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
  # A reviewed judgement outranks a derived one, and the primary key
  # (series_id, field) means they cannot both be stored. The delete below spares
  # reviewed rows deliberately -- that is what makes review durable across
  # rebuilds -- so the derived side has to stand down for the same key, or the
  # append aborts. Latent until schema 34 gave anyone a way to record a review.
  reviewed <- DBI::dbGetQuery(
    con, "SELECT series_id, field FROM series_semantic_evidence WHERE basis = 'reviewed'"
  )
  if (nrow(evidence) && nrow(reviewed)) evidence <- evidence %>% dplyr::anti_join(
    reviewed, by = c("series_id", "field")
  )
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
    # Source-published dimensions are parser evidence, not semantic derivations.
    # Rebuilding label/title-derived dimensions must never erase them.
    DBI::dbExecute(con, paste(
      "DELETE FROM series_dimension",
      "WHERE basis NOT IN ('reviewed', 'published_imf_export')"
    ))
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

# --- The published table title, at series grain ------------------------------
# The audit's ER-05.2, and the reason it is a table rather than a join.
#
# `PIB a precios de comprador` appears on thirteen worksheets, and 4,015 of the
# 7,229 scalar series share a label with at least one other series. On CUADRO 6
# and CUADRO 7 two of them are indistinguishable on every field a researcher can
# see -- same unit, same frequency, same base year, means differing by 23 in 39
# million -- and the only field that separates them is the title the publisher
# printed above the table.
#
# That title has always been in the database, on documented_series_snapshot, at
# (vintage_id, series_id, period) grain in the staging layer. Joining it at query
# time would mean telling researchers to read a staging table, and would fan a
# series out over its vintages and periods. So it is resolved once, here, to one
# row per series, with the count of distinct titles kept beside it: a publisher
# who retitles a table between vintages is a fact worth seeing, not a reason for
# the join to start returning two rows.
apply_series_titles <- function(con) {
  if (!DBI::dbExistsTable(con, "series_titles")) return(invisible(0L))
  if (!database_object_exists(con, "documented_series_snapshot")) return(invisible(0L))
  DBI::dbExecute(con, "DELETE FROM series_titles")
  DBI::dbExecute(con, paste(
    "INSERT INTO series_titles",
    "WITH ranked AS (",
    "  SELECT n.series_id, n.table_title, n.source_sheet, n.vintage_id,",
    "    count(*) AS observations,",
    # The current vintage's wording wins, and the count of distinct titles
    # travels with it so nobody has to trust that it was the only one.
    "    row_number() OVER (PARTITION BY n.series_id",
    "      ORDER BY max(n.publication_date) DESC NULLS LAST, count(*) DESC, n.vintage_id DESC)",
    "      AS rn",
    "  FROM", project_qualified_name("documented_series_snapshot"), "n",
    "  WHERE n.table_title IS NOT NULL AND n.table_title <> ''",
    "  GROUP BY n.series_id, n.table_title, n.source_sheet, n.vintage_id",
    "),",
    "titles AS (",
    "  SELECT series_id, count(DISTINCT table_title) AS distinct_titles",
    "  FROM", project_qualified_name("documented_series_snapshot"),
    "  WHERE table_title IS NOT NULL AND table_title <> '' GROUP BY 1",
    ")",
    "SELECT r.series_id, r.table_title, r.source_sheet,",
    "  t.distinct_titles > 1 AS title_varies_by_vintage, t.distinct_titles, r.vintage_id",
    "FROM ranked r JOIN titles t USING (series_id) WHERE r.rn = 1"
  ))
  invisible(DBI::dbGetQuery(con, "SELECT count(*) AS n FROM series_titles")$n[[1]])
}

create_semantic_views <- function(con) {
  bounds <- series_period_bounds_sql()
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
    "s.first_ingested_release_id, r.accepted_release_id, r.first_published_at,",
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
    # The accepted product that first admitted this vintage, and when.
    #
    # This was `max(rs.release_id)` over release_sources joined to
    # `releases.status = 'accepted'`, and it was wrong three ways at once. The
    # aggregate is a *lexical* maximum over hashed identifiers, so for a vintage
    # in several bundles it named whichever hex prefix sorted highest -- not the
    # earliest, not the latest, not the active one. It read `releases.status`,
    # the mutable per-bundle column schema 30 retired as the publication test, so
    # a failed rebuild of any bundle containing the vintage nulled the label on
    # rows that were still published. And it was exposed to researchers in every
    # v_mart_*_all. The re-audit's section A7.
    "LEFT JOIN (", admitting_data_release_sql(), ") r ON r.vintage_id = f.vintage_id",
    "LEFT JOIN documented_series_snapshot n ON n.vintage_id = f.vintage_id",
    "  AND n.series_id = f.series_id AND n.period = f.period",
    "LEFT JOIN series_period_bounds b ON b.series_id = f.series_id AND b.period = f.period",
    filter
  )
  create_project_view(con, "v_series_observations", observations_body(paste0(
    "WHERE f.vintage_id IN (", accepted_release_vintages_sql(), ")"
  )))
  create_project_view(con, "v_series_observations_all", observations_body(""))
  # The third carrier, and the one a point-in-time query needs: every vintage
  # that was ever published, rather than the ones the current pointer names.
  #
  # The re-audit's RA2-01. "What is published now" and "what could have been seen
  # then" are different questions over different populations, and until now both
  # were answered from the first. A vintage superseded by a later bundle left the
  # as-of population entirely, so no cutoff could return it -- including cutoffs
  # from before its successor existed.
  #
  # The blocked case is what makes this a filter rather than no filter at all: a
  # build that ended blocked was never knowable by anyone, so admitting it would
  # be a look-ahead error of exactly the kind as-of exists to prevent. Hence
  # accepted products only, and `v_series_observations_all` remains the
  # unfiltered twin for diagnostics.
  create_project_view(con, "v_series_observations_history", observations_body(paste0(
    "WHERE f.vintage_id IN (", accepted_history_vintages_sql(), ")"
  )))
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
  # It reads the *history* carrier, not the current one.
  #
  # Reading v_series_observations applied the active-bundle filter before the
  # ranking, which meant the ranking could only ever choose among vintages that
  # are current today -- so a cutoff before the newest publication still returned
  # the newest vintage's value, silently, with no way for the caller to tell.
  # That is look-ahead: the exact error this interface exists to prevent, in the
  # one place it was least visible. The re-audit's RA2-01.
  as_of_body <- function(projection_predicate) paste(
    "AS TABLE",
    "WITH ranked AS (",
    "  SELECT *, row_number() OVER (PARTITION BY series_id, period",
    "    ORDER BY available_at DESC NULLS LAST, vintage_id DESC) AS rn",
    "  FROM v_series_observations_history",
    "  WHERE available_at IS NOT NULL AND available_at <= as_of",
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
  # The title, on the documented path rather than in staging.
  create_project_view(con, "v_series_titles", paste(
    "SELECT t.series_id, d.source_id, d.label, t.table_title, t.source_sheet,",
    "t.title_varies_by_vintage, t.distinct_titles",
    "FROM series_titles t JOIN dim_series d USING (series_id)"
  ))
  # --- The research extraction interface -------------------------------------
  # The audit's ER-05, and its P1.1 field list.
  #
  # `series_latest()` returned seven columns: series_id, period, value,
  # vintage_id, publication_date, source_file, observation_status. No label. No
  # unit. No frequency. A researcher had to know to join canonical.dim_series --
  # and once they did, the label they joined for is not an identifier, because
  # 1,599 labels name more than one series.
  #
  # So this view carries what interpreting a number actually requires, on one
  # relation, on the path the README sends people to. It changes nothing about
  # the values: it descends from v_series_observations, which is the declared
  # filtered base relation, and adds metadata by joins that are one-to-one by
  # construction. Nothing here rescales, deflates, splices, seasonally adjusts or
  # aggregates -- value is the stored number and value_in_base_units is the same
  # number times its declared scale, and both are named for what they are.
  #
  # Realized observations only, for the same reason v_series_latest is: this is
  # the default a researcher reaches for, and the default must not be the one
  # that puts a 2028 projection into an estimation sample.
  research_body <- function(source) paste(
    "SELECT o.series_id, d.label, t.table_title, o.source_id, o.source_sheet,",
    "o.period, o.period_start, o.period_end, o.frequency,",
    "o.unit_code, o.unit, o.scale, o.scale_multiplier, d.currency, d.index_base,",
    "d.price_base_year, d.stock_flow, d.nominal_real, d.seasonal_adjustment,",
    "d.transformation, d.valuation, d.hierarchy_status, d.identity_stability,",
    "r.hierarchy_role, r.methodology_regime_id, r.timing_basis,",
    # Whether an economist has signed this series off, said in the row rather
    # than implied by which view the reader chose.
    "CASE WHEN r.series_id IS NULL THEN 'not_reviewed' ELSE 'reviewed' END AS review_status,",
    "r.reviewed_by, r.reviewed_at,",
    "o.value, o.value_in_base_units, o.vintage_id, o.publication_date, o.available_at,",
    "p.availability_quality, o.observation_status",
    "FROM", source, "o",
    "JOIN dim_series d ON d.series_id = o.series_id",
    "LEFT JOIN series_titles t ON t.series_id = o.series_id",
    "LEFT JOIN series_review r ON r.series_id = o.series_id",
    "LEFT JOIN source_provenance p ON p.vintage_id = o.vintage_id",
    "WHERE NOT o.is_deleted AND o.observation_status = 'observed'"
  )
  create_project_view(con, "v_series_research", research_body("v_series_observations"))
  # The unfiltered twin, on the project's existing convention: it exists for
  # ingestion diagnosis and is not a research interface, which is what the name
  # and the contract both say.
  create_project_view(con, "v_series_research_all", research_body("v_series_observations_all"))
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
  formula_coordinates <- database_object_exists(con, "report_cell_formulas")
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
    # Schema 35, the seventh audit's F-07. Schema 29 closed this gap for hidden
    # rows and could not close it for formulas, because the hidden ranges are
    # coordinates and the formula count was a number. Now that the coordinates are
    # recorded, the same join answers the same question: readxl cannot calculate,
    # so every value here is a cached result, and this says whether *this* value
    # is one whose cell held a formula at all.
    if (formula_coordinates) paste(
      "       EXISTS (SELECT 1 FROM", project_qualified_name("report_cell_formulas"), "c",
      "               WHERE c.vintage_id = o.vintage_id AND c.sheet_name = o.source_sheet",
      "                 AND c.row_id = o.source_row",
      "                 AND c.column_id = o.source_column) AS from_formula_cell,"
    ) else "       CAST(NULL AS BOOLEAN) AS from_formula_cell,",
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
    paste(vapply(EXPECTED_GRID_FREQUENCIES, sql_string, character(1)), collapse = ", "), ")",
    "AND EXISTS (SELECT 1 FROM", project_qualified_name("missingness_contracts"), "c",
    " WHERE c.source_id = documented_series_snapshot.source_id",
    " AND c.contract_type = 'regular_calendar'",
    " AND (c.source_sheet = documented_series_snapshot.source_sheet OR c.source_sheet = '*'))"
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
# --- ER-01: every series on a worksheet that assigns a currency-pair unit ----
# The audit's ER-01 deliverable 1, verbatim: "a review worklist for every series
# on CUADRO 60a, CUADRO 60c and every other worksheet assigning PYG_PER_USD.
# Include series_id, complete dimensional path, table title, source cells,
# observed range, period coverage, current unit and currency fields."
#
# Scoped to worksheets rather than to series, because the defect is inherited at
# worksheet level: what makes CUADRO 60c wrong is not any one column but the
# sheet's single unit applied to five columns that are not in it. So a sheet
# appears here in full the moment any column on it declares a currency pair, and
# the corrected columns stay on the list beside the uncorrected ones with the
# decision that was taken recorded against them.
write_exchange_rate_unit_worklist <- function(con, root) {
  if (is.null(root) || !database_object_exists(con, "dim_series")) return(invisible(NULL))
  worklist <- tryCatch(DBI::dbGetQuery(con, paste(
    "WITH pair_sheets AS (",
    "  SELECT DISTINCT n.source_id, n.source_sheet",
    "  FROM", project_qualified_name("documented_series_snapshot"), "n",
    "  JOIN", project_qualified_name("dim_series"), "d USING (series_id)",
    "  WHERE regexp_matches(d.unit_code, '^[A-Z]{3}_PER_[A-Z]{3}$')",
    # A worksheet that has been corrected stays on the list. Scoping only to
    # sheets that *currently* assign a currency-pair unit would drop CUADRO 60c
    # the moment its five index series were fixed -- so the queue would lose the
    # record of the decision exactly when the decision was made, and ER-01's
    # "before/after list of affected series" would have nothing to show.
    "  UNION",
    "  SELECT DISTINCT u.source_id, u.source_sheet",
    "  FROM", project_qualified_name("unit_overrides"), "u",
    "), on_sheet AS (",
    "  SELECT DISTINCT n.series_id, n.source_id, n.source_sheet,",
    "    any_value(n.table_title) OVER (PARTITION BY n.series_id) AS table_title,",
    "    any_value(n.series_path) OVER (PARTITION BY n.series_id) AS series_path",
    "  FROM", project_qualified_name("documented_series_snapshot"), "n",
    "  JOIN pair_sheets p USING (source_id, source_sheet)",
    ")",
    "SELECT s.source_id, s.source_sheet, s.series_id, d.label, s.series_path, s.table_title,",
    "  d.frequency, d.unit_code, d.currency, d.index_base, d.scale, d.transformation,",
    "  d.identity_stability,",
    "  o.observations, o.first_period, o.last_period, o.min_value, o.max_value,",
    "  o.first_source_row, o.first_source_column,",
    "  CASE WHEN u.series_id IS NULL THEN 'open' ELSE 'reviewed' END AS decision_status,",
    "  u.reviewed_by, u.reviewed_at, u.evidence",
    "FROM on_sheet s",
    "JOIN", project_qualified_name("dim_series"), "d ON d.series_id = s.series_id",
    "LEFT JOIN", project_qualified_name("unit_overrides"), "u ON u.series_id = s.series_id",
    "LEFT JOIN (",
    "  SELECT series_id, count(*) AS observations, min(period) AS first_period,",
    "    max(period) AS last_period, min(value) AS min_value, max(value) AS max_value,",
    "    min(source_row) AS first_source_row, min(source_column) AS first_source_column",
    "  FROM", project_qualified_name("documented_series_snapshot"), "GROUP BY 1",
    ") o ON o.series_id = s.series_id",
    "ORDER BY s.source_sheet, decision_status, d.label"
  )), error = function(e) NULL)
  if (is.null(worklist) || !nrow(worklist)) return(invisible(NULL))
  readr::write_csv(worklist, file.path(root, "outputs", "exchange_rate_unit_worklist.csv"))
  invisible(worklist)
}

# --- ER-06: the unresolved units, partitioned rather than counted ------------
# "Partition the 4,057 unresolved-unit records into true unknowns, mixed-unit
# sheets, missing mapping rules and non-measure/structural records."
#
# 4,057 is not a task. Which of those four a record belongs to decides who can
# fix it and how: a mixed-unit sheet needs a column-level rule, a structural
# record needs no unit at all, and a true unknown needs the publisher's notes.
# The partition is derived from evidence already in the database -- whether other
# columns on the same worksheet did resolve, whether the series is a measure at
# all, and whether the sheet's own title states a unit -- and a record the
# evidence does not place is left in the true-unknown bucket rather than guessed
# into a smaller one.
write_unit_resolution_worklist <- function(con, root) {
  if (is.null(root) || !database_object_exists(con, "dim_series")) return(invisible(NULL))
  worklist <- tryCatch(DBI::dbGetQuery(con, paste(
    "WITH placed AS (",
    "  SELECT d.series_id, d.source_id, d.label, d.unit_code, d.series_grain, d.frequency,",
    "    any_value(n.source_sheet) AS source_sheet, any_value(n.table_title) AS table_title",
    "  FROM", project_qualified_name("dim_series"), "d",
    "  LEFT JOIN", project_qualified_name("documented_series_snapshot"), "n USING (series_id)",
    "  WHERE d.unit_code IN ('UNRESOLVED_SOURCE_UNITS', 'MIXED_PHYSICAL_UNITS')",
    "     OR d.unit_code IS NULL",
    "  GROUP BY d.series_id, d.source_id, d.label, d.unit_code, d.series_grain, d.frequency",
    "), sheet_units AS (",
    "  SELECT n.source_id, n.source_sheet,",
    "    count(DISTINCT d.unit_code) FILTER (",
    "      WHERE d.unit_code NOT IN ('UNRESOLVED_SOURCE_UNITS', 'MIXED_PHYSICAL_UNITS')",
    "    ) AS resolved_units_on_sheet",
    "  FROM", project_qualified_name("documented_series_snapshot"), "n",
    "  JOIN", project_qualified_name("dim_series"), "d USING (series_id)",
    "  GROUP BY 1, 2",
    ")",
    "SELECT p.series_id, p.source_id, p.source_sheet, p.label, p.table_title, p.frequency,",
    "  p.unit_code, p.series_grain, coalesce(s.resolved_units_on_sheet, 0) AS resolved_units_on_sheet,",
    "  coalesce(o.observations, 0) AS observations,",
    "  CASE",
    # A record that is not a scalar measure has no unit to resolve: an event or
    # a curve point is not a quantity in a unit, and counting it among the
    # unresolved makes the backlog look larger than the work.
    "    WHEN p.series_grain IS NOT NULL AND p.series_grain <> 'scalar_series'",
    "      THEN 'structural_or_non_measure'",
    "    WHEN p.unit_code = 'MIXED_PHYSICAL_UNITS' THEN 'mixed_physical_units'",
    # Other columns on the same worksheet did resolve, so the publisher stated a
    # unit somewhere on the sheet and this column did not inherit it. That is a
    # column-level mapping rule, not a question for the publisher.
    "    WHEN coalesce(s.resolved_units_on_sheet, 0) > 0 THEN 'missing_column_mapping_rule'",
    "    ELSE 'true_unknown'",
    "  END AS partition,",
    "  CASE WHEN coalesce(o.observations, 0) >= 60 THEN '1_usable_length'",
    "       WHEN coalesce(o.observations, 0) > 0 THEN '2_short'",
    "       ELSE '3_no_observations' END AS review_priority",
    "FROM placed p",
    "LEFT JOIN sheet_units s ON s.source_id = p.source_id AND s.source_sheet = p.source_sheet",
    "LEFT JOIN (SELECT series_id, count(*) AS observations FROM",
    project_qualified_name("fact_series_events"), "WHERE NOT is_deleted GROUP BY 1) o",
    "  ON o.series_id = p.series_id",
    "ORDER BY partition, review_priority, observations DESC"
  )), error = function(e) NULL)
  if (is.null(worklist) || !nrow(worklist)) return(invisible(NULL))
  readr::write_csv(worklist, file.path(root, "outputs", "unit_resolution_worklist.csv"))
  invisible(worklist)
}

# --- ER-06: the positional identities ---------------------------------------
# "Review the 820 positional or positional-lane identities against stable labels,
# dimensions and source cells."
#
# A positional identity is one whose series_id depends on where the column sat,
# so a publisher who inserts a column re-points it at different data without
# changing anything a query can see. What decides whether that is dangerous is
# whether the label is stable and distinctive enough to carry the identity
# instead -- which is measurable, and is measured here, rather than left as a
# count of 820.
write_identity_stability_worklist <- function(con, root) {
  if (is.null(root) || !database_object_exists(con, "dim_series")) return(invisible(NULL))
  worklist <- tryCatch(DBI::dbGetQuery(con, paste(
    "WITH labelled AS (",
    "  SELECT label, count(*) AS series_sharing_label FROM", project_qualified_name("dim_series"),
    "  GROUP BY 1",
    ")",
    "SELECT d.series_id, d.source_id, n.source_sheet, d.label, n.table_title, d.frequency,",
    "  d.unit_code, d.identity_stability, d.identity_basis, d.hierarchy_status,",
    "  l.series_sharing_label, o.observations, o.first_period, o.last_period,",
    "  o.first_source_row, o.first_source_column,",
    # The repair the evidence supports, stated per row. A label that names this
    # series and no other can carry the identity; one that names several cannot,
    # and needs a dimension before the position can be given up.
    "  CASE WHEN l.series_sharing_label = 1 THEN 'label_is_unique_candidate_semantic_identity'",
    "       ELSE 'label_is_ambiguous_needs_dimension_before_repositioning' END AS proposed_repair,",
    "  CASE WHEN coalesce(o.observations, 0) >= 60 THEN '1_usable_length'",
    "       WHEN coalesce(o.observations, 0) > 0 THEN '2_short'",
    "       ELSE '3_no_observations' END AS review_priority",
    "FROM", project_qualified_name("dim_series"), "d",
    "JOIN labelled l ON l.label = d.label",
    "LEFT JOIN (SELECT series_id, any_value(source_sheet) AS source_sheet,",
    "  any_value(table_title) AS table_title FROM",
    project_qualified_name("documented_series_snapshot"), "GROUP BY 1) n USING (series_id)",
    "LEFT JOIN (SELECT series_id, count(*) AS observations, min(period) AS first_period,",
    "  max(period) AS last_period, min(source_row) AS first_source_row,",
    "  min(source_column) AS first_source_column FROM",
    project_qualified_name("documented_series_snapshot"), "GROUP BY 1) o USING (series_id)",
    "WHERE d.identity_stability IN ('positional', 'positional_lane')",
    "ORDER BY review_priority, proposed_repair, observations DESC"
  )), error = function(e) NULL)
  if (is.null(worklist) || !nrow(worklist)) return(invisible(NULL))
  readr::write_csv(worklist, file.path(root, "outputs", "identity_stability_worklist.csv"))
  invisible(worklist)
}

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
  # Schema 34: the queue and the register are the two ends of one workflow, and
  # until now they did not name each other. A reviewer reading this file could
  # see that a series was unreviewed and had nowhere to go with the answer.
  register <- tryCatch(read_series_review_register(root), error = function(e) NULL)
  reviewed_ids <- if (is.null(register)) character() else trimws(register$series_id)
  blank <- function(x) is.na(x) | !nzchar(trimws(x))
  worklist$review_register_row <- ifelse(
    worklist$series_id %in% reviewed_ids, "present", "absent"
  )
  worklist$review_register_missing_fields <- vapply(worklist$series_id, function(series_id) {
    if (is.null(register) || !series_id %in% reviewed_ids) {
      return(paste(SERIES_REVIEW_REQUIRED_FIELDS[-1], collapse = "; "))
    }
    row <- register[trimws(register$series_id) == series_id, , drop = FALSE][1, ]
    absent <- SERIES_REVIEW_REQUIRED_FIELDS[-1][
      vapply(SERIES_REVIEW_REQUIRED_FIELDS[-1], function(f) blank(row[[f]]), logical(1))
    ]
    if (!length(absent)) "" else paste(absent, collapse = "; ")
  }, character(1), USE.NAMES = FALSE)
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
