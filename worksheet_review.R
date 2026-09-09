#!/usr/bin/env Rscript
# --- Reviewing a catalogue one worksheet at a time ---------------------------
#
# The readiness audit asks for every series used in research to carry a reviewed
# definition, timing, stock/flow, unit, seasonal status, hierarchy and
# comparability. Answered series by series that is 7,229 series times twenty
# fields, and the sources do not help: measured on schema 39, the published text
# states stock/flow for 669 series, nominal/real for 37, seasonal adjustment for
# 14, and all three together for **none**.
#
# But those fields are almost never properties of a *column*. They are properties
# of the *table*: `Cuadro Nº 6 -- Producto interno bruto trimestral ... En
# millones de guaraníes constantes de 2014` fixes the price basis, the valuation
# and the timing for all nine of its columns at once. So the unit of review is
# the worksheet, and 219 worksheets at roughly ten answers each is a few days of
# work rather than a few person-years.
#
# Two things keep that from becoming the bulk-approval the audit forbids.
#
# First, a worksheet answer is a *default*, not an override. Where the published
# text already states a field for a particular series -- the IMAEP block writes
# `Serie Original`, `Serie ajustada` and `Tendencia Ciclo` on the labels, and
# CUADRO 9 a therefore holds all three seasonal conventions on one sheet -- the
# series-level evidence wins and the sheet answer is ignored. Every expanded row
# records which of its fields came from published text and which from the sheet
# decision.
#
# Second, nothing here signs anything. This writes proposals.
# sign_off_reviews.R is still the only thing that puts a name in a register.
#
# Usage:
#   Rscript worksheet_review.R
#       Write or refresh config/proposals/worksheet_review.csv. Answers already
#       filled in are preserved; only the derived context is recomputed.
#
#   Rscript worksheet_review.R --expand
#       Expand every worksheet marked decision_status = 'accepted' into per-series
#       rows in config/proposals/series_review.csv, then read them with
#       `Rscript sign_off_reviews.R`.

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(root, "config", "source_registry.csv"))) stop(
  "Run this from the project root.", call. = FALSE
)
source(file.path(root, "scripts", "load_project.R"))
load_project_scripts(root, profile = "worksheet_review", quiet = TRUE)

WORKSHEET_REVIEW_PATH <- file.path("config", "proposals", "worksheet_review.csv")
SERIES_PROPOSAL_PATH <- file.path("config", "proposals", "series_review.csv")

# What the reviewer fills in, and the closed set each answer comes from. These
# are the sheet-wide judgements; everything else about a series -- its unit, its
# scale, its currency, its frequency -- is already resolved per series in the
# catalogue and is read from there rather than asked about again.
WORKSHEET_ANSWERS <- list(
  stock_flow          = SERIES_REVIEW_VOCABULARY$stock_flow,
  nominal_real        = SERIES_REVIEW_VOCABULARY$nominal_real,
  price_base_year     = NULL,   # four digits, and required when nominal_real is 'real'
  seasonal_adjustment = SERIES_REVIEW_VOCABULARY$seasonal_adjustment,
  timing_basis        = SERIES_REVIEW_VOCABULARY$timing_basis,
  valuation           = SERIES_REVIEW_VOCABULARY$valuation,
  comparability       = SERIES_REVIEW_VOCABULARY$comparability,
  total_label         = NULL,   # the exact label of the sheet's total, if it has one
  # The labels that actually sum into total_label, pipe-separated. Blank means
  # no hierarchy is asserted and every column is standalone.
  #
  # This is stated rather than inferred, because the obvious inference is wrong.
  # Treating "every column that is not the total" as a component of it makes
  # `IMAEP sin Agri ni Bin` a part of `IMAEP`, and it is not -- it is a second
  # aggregate over a different scope, published beside the first. hierarchy_role
  # = 'component' with a parent is what licenses summing, so an over-eager
  # default here would license double counting.
  component_labels    = NULL,
  methodology_regime_id = NULL, # a regime_id from config/methodology_regimes.csv, if one applies
  reviewer_note       = NULL
)

WORKSHEET_DECISION_STATUSES <- c("", "accepted", "skip")

# The context a reviewer needs in front of them to answer, all of it read out of
# the database rather than asserted here.
worksheet_context <- function(con) {
  DBI::dbGetQuery(con, paste(
    "WITH placed AS (",
    "  SELECT DISTINCT n.series_id, n.source_id, n.source_sheet",
    "  FROM", project_qualified_name("documented_series_snapshot"), "n",
    "), titled AS (",
    "  SELECT source_id, source_sheet, any_value(table_title) AS table_title",
    "  FROM", project_qualified_name("documented_series_snapshot"),
    "  WHERE table_title IS NOT NULL AND table_title <> '' GROUP BY 1, 2",
    "), obs AS (",
    "  SELECT series_id, count(*) AS observations, min(period) AS first_period,",
    "         max(period) AS last_period",
    "  FROM", project_qualified_name("fact_series_events"), "WHERE NOT is_deleted GROUP BY 1",
    ")",
    "SELECT p.source_id, p.source_sheet, t.table_title,",
    "  count(*) AS series_on_sheet,",
    "  string_agg(DISTINCT d.unit_code, ' | ') AS unit_codes,",
    "  string_agg(DISTINCT d.scale, ' | ') AS scales,",
    "  string_agg(DISTINCT d.frequency, ' | ') AS frequencies,",
    "  string_agg(DISTINCT d.index_base, ' | ') AS index_bases,",
    "  CASE WHEN count(DISTINCT d.unit_code) = 1 AND count(DISTINCT d.scale) = 1",
    "         AND count(DISTINCT d.frequency) = 1 THEN 'homogeneous' ELSE 'mixed' END AS sheet_kind,",
    "  sum(o.observations) AS observations, min(o.first_period) AS first_period,",
    "  max(o.last_period) AS last_period,",
    # What the published text already settles, so a reviewer can see how much of
    # the sheet the source has answered before they answer the rest.
    "  count(*) FILTER (WHERE d.stock_flow <> 'not_reviewed') AS stated_stock_flow,",
    "  count(*) FILTER (WHERE d.nominal_real <> 'not_reviewed') AS stated_nominal_real,",
    "  count(*) FILTER (WHERE d.seasonal_adjustment <> 'not_reviewed') AS stated_seasonal,",
    "  count(*) FILTER (WHERE d.valuation <> 'not_reviewed') AS stated_valuation,",
    "  string_agg(DISTINCT substr(d.label, 1, 40), ' | ') AS sample_labels",
    "FROM placed p",
    "JOIN", project_qualified_name("dim_series"), "d ON d.series_id = p.series_id",
    "LEFT JOIN titled t ON t.source_id = p.source_id AND t.source_sheet = p.source_sheet",
    "LEFT JOIN obs o ON o.series_id = p.series_id",
    "WHERE d.series_grain = 'scalar_series'",
    "GROUP BY 1, 2, 3",
    # Most series first: a reviewer working top-down covers the catalogue
    # fastest, and a homogeneous sheet is the safest to answer as a unit.
    "ORDER BY sheet_kind, series_on_sheet DESC"
  ))
}

generate_worksheet_review <- function(con, root) {
  context <- worksheet_context(con)
  context$sample_labels <- substr(context$sample_labels, 1, 300)
  answers <- names(WORKSHEET_ANSWERS)
  path <- file.path(root, WORKSHEET_REVIEW_PATH)
  # Answers already given are preserved. Regenerating must never quietly discard
  # a reviewer's work because a rebuild added a series to a sheet.
  if (file.exists(path)) {
    previous <- readr::read_csv(
      path, show_col_types = FALSE, col_types = readr::cols(.default = readr::col_character())
    )
    keep <- intersect(c("source_id", "source_sheet", answers, "decision_status"), names(previous))
    context <- dplyr::left_join(context, previous[keep], by = c("source_id", "source_sheet"))
  }
  for (field in c(answers, "decision_status")) {
    if (is.null(context[[field]])) context[[field]] <- NA_character_
  }
  context$decision_status[is.na(context$decision_status)] <- ""
  readr::write_csv(context, path, na = "")
  answered <- sum(context$decision_status == "accepted", na.rm = TRUE)
  message(
    "Wrote ", nrow(context), " worksheet(s) to ", WORKSHEET_REVIEW_PATH, ".\n",
    "  ", sum(context$sheet_kind == "homogeneous"), " homogeneous, covering ",
    sum(context$series_on_sheet[context$sheet_kind == "homogeneous"]), " series.\n",
    "  ", answered, " already marked accepted.\n",
    "Fill in ", paste(answers[1:7], collapse = ", "), " and set decision_status = 'accepted',\n",
    "then run: Rscript worksheet_review.R --expand"
  )
  invisible(context)
}

# --- Expansion ---------------------------------------------------------------

worksheet_problems <- function(sheets) {
  blank <- function(x) is.na(x) | !nzchar(trimws(x))
  problems <- list()
  add <- function(rows, problem) {
    if (any(rows)) problems[[length(problems) + 1L]] <<- tibble::tibble(
      worksheet = paste(sheets$source_id[rows], sheets$source_sheet[rows], sep = "/"),
      problem = problem
    )
  }
  for (field in c("stock_flow", "nominal_real", "seasonal_adjustment", "timing_basis",
                  "valuation", "comparability")) {
    add(blank(sheets[[field]]), paste0("`", field, "` is blank and is required to expand."))
  }
  for (field in names(WORKSHEET_ANSWERS)) {
    allowed <- WORKSHEET_ANSWERS[[field]]
    if (is.null(allowed)) next
    add(
      !blank(sheets[[field]]) & !sheets[[field]] %in% allowed,
      paste0("`", field, "` is outside its vocabulary (", paste(allowed, collapse = ", "), ").")
    )
  }
  # The register refuses a real series with no price base, so catch it here
  # rather than after fifty rows have been written.
  add(
    sheets$nominal_real %in% "real" & blank(sheets$price_base_year),
    "`nominal_real` is 'real', so `price_base_year` is required."
  )
  add(
    !blank(sheets$price_base_year) & !grepl("^[0-9]{4}$", trimws(sheets$price_base_year)),
    "`price_base_year` must be four digits."
  )
  if (!length(problems)) return(tibble::tibble(worksheet = character(), problem = character()))
  dplyr::bind_rows(problems)
}

expand_worksheet_review <- function(con, root) {
  path <- file.path(root, WORKSHEET_REVIEW_PATH)
  if (!file.exists(path)) stop(
    "No ", WORKSHEET_REVIEW_PATH, " yet. Run `Rscript worksheet_review.R` first.", call. = FALSE
  )
  sheets <- readr::read_csv(
    path, show_col_types = FALSE, col_types = readr::cols(.default = readr::col_character())
  )
  bad_status <- !sheets$decision_status %in% c(WORKSHEET_DECISION_STATUSES, NA)
  if (any(bad_status)) stop(
    "decision_status must be one of: ", paste(setdiff(WORKSHEET_DECISION_STATUSES, ""), collapse = ", "),
    " (or blank). Offending: ", paste(unique(sheets$decision_status[bad_status]), collapse = ", "),
    call. = FALSE
  )
  accepted <- sheets[sheets$decision_status %in% "accepted", , drop = FALSE]
  if (!nrow(accepted)) {
    message(
      "No worksheet is marked decision_status = 'accepted' in ", WORKSHEET_REVIEW_PATH,
      ", so nothing was expanded."
    )
    return(invisible(0L))
  }
  problems <- worksheet_problems(accepted)
  if (nrow(problems)) stop(
    "Cannot expand; ", nrow(problems), " problem(s) in the accepted worksheets:\n  - ",
    paste(utils::head(paste0(problems$worksheet, ": ", problems$problem), 20), collapse = "\n  - "),
    call. = FALSE
  )

  series <- DBI::dbGetQuery(con, paste(
    "SELECT DISTINCT n.series_id, n.source_id, n.source_sheet, d.label,",
    "  d.frequency, d.unit_code, d.scale_multiplier, d.currency, d.index_base,",
    "  d.price_base_year, d.stock_flow, d.nominal_real, d.seasonal_adjustment,",
    "  d.transformation, d.valuation,",
    "  any_value(n.table_title) OVER (PARTITION BY n.series_id) AS table_title,",
    "  any_value(n.series_path) OVER (PARTITION BY n.series_id) AS series_path,",
    "  min(n.source_row) OVER (PARTITION BY n.series_id) AS source_row,",
    "  min(n.source_column) OVER (PARTITION BY n.series_id) AS source_column",
    "FROM", project_qualified_name("documented_series_snapshot"), "n",
    "JOIN", project_qualified_name("dim_series"), "d USING (series_id)",
    "WHERE d.series_grain = 'scalar_series'"
  ))
  coverage <- DBI::dbGetQuery(con, paste(
    "SELECT series_id, count(*) AS observations, min(period) AS first_period,",
    "  max(period) AS last_period FROM", project_qualified_name("fact_series_events"),
    "WHERE NOT is_deleted GROUP BY 1"
  ))
  publication <- DBI::dbGetQuery(con, paste(
    "SELECT source_id, max(publication_date) AS publication_date FROM",
    project_qualified_name("source_files"), "GROUP BY 1"
  ))
  # The series that change day convention inside their own history, so an
  # expanded row inherits the question rather than losing it.
  mixed_convention <- tryCatch(DBI::dbGetQuery(con, paste(
    "WITH o AS (SELECT series_id, CASE WHEN day(period) = 1 THEN 'start'",
    "  WHEN day(period) >= 28 THEN 'end' ELSE 'other' END AS convention",
    "  FROM main.v_series_observations",
    "  WHERE frequency IN ('monthly','monthly_survey') AND NOT is_deleted)",
    "SELECT series_id FROM o GROUP BY 1 HAVING count(DISTINCT convention) > 1"
  ))$series_id, error = function(e) character())

  rows <- dplyr::inner_join(
    series, accepted[c("source_id", "source_sheet", names(WORKSHEET_ANSWERS))],
    by = c("source_id", "source_sheet"), suffix = c("", "_sheet")
  )
  rows <- dplyr::left_join(rows, coverage, by = "series_id")
  rows <- dplyr::left_join(rows, publication, by = "source_id")
  if (!nrow(rows)) stop("The accepted worksheets contain no scalar series.", call. = FALSE)

  blank_na <- function(x) ifelse(is.na(x), "", as.character(x))
  # Published text beats the sheet decision, and the row records which it used.
  # This is what keeps CUADRO 9 a's three seasonal variants distinct while one
  # sheet answer covers the rest of the catalogue.
  stated <- function(derived, fallback) ifelse(
    is.na(derived) | derived %in% c("not_reviewed", ""), fallback, derived
  )
  from_text <- function(derived) !(is.na(derived) | derived %in% c("not_reviewed", ""))

  sources <- c("stock_flow", "nominal_real", "seasonal_adjustment", "valuation")
  provenance <- vapply(seq_len(nrow(rows)), function(i) {
    text_fields <- sources[vapply(sources, function(f) from_text(rows[[f]][[i]]), logical(1))]
    sheet_fields <- setdiff(sources, text_fields)
    paste0(
      if (length(text_fields)) paste0(
        "From the published text: ", paste(text_fields, collapse = ", "), ". "
      ) else "",
      if (length(sheet_fields)) paste0(
        "From the worksheet decision: ", paste(sheet_fields, collapse = ", "),
        ", timing_basis, comparability."
      ) else "timing_basis and comparability from the worksheet decision."
    )
  }, character(1))

  # Hierarchy is asserted, never inferred. A column is a component only if the
  # reviewer named it in component_labels; everything else is standalone even
  # when the sheet has a total, because sitting on the same worksheet as a total
  # is not evidence of summing into it.
  total_label <- blank_na(rows$total_label)
  is_total <- nzchar(total_label) & rows$label == total_label
  declared_components <- strsplit(blank_na(rows$component_labels), "|", fixed = TRUE)
  is_component <- vapply(seq_len(nrow(rows)), function(i) {
    trimws(rows$label[[i]]) %in% trimws(declared_components[[i]])
  }, logical(1)) & !is_total
  parent <- rep(NA_character_, nrow(rows))
  key <- paste(rows$source_id, rows$source_sheet)
  for (k in unique(key[is_total])) {
    hit <- key == k
    parent[hit & is_component] <- rows$series_id[hit & is_total][[1]]
  }
  # A component named with no total to hang it on would be a dangling parent, so
  # it stays standalone and the row says why.
  orphaned <- is_component & is.na(parent)
  is_component[orphaned] <- FALSE

  questions <- ifelse(
    rows$series_id %in% mixed_convention,
    paste(
      "This series changes day convention inside its own history",
      "(see outputs/temporal_convention_worklist.csv). The normalised bounds make it safe to join;",
      "whether the change is a source-layout change or a change of observation timing is unresolved,",
      "and if the latter it needs a methodology regime."
    ), ""
  )
  # A sheet whose columns are not all in one unit is a sheet where a single
  # judgement is least likely to be true of every column, so the row says so.
  mixed_sheet <- rows$source_sheet %in%
    accepted$source_sheet[accepted$sheet_kind %in% "mixed"]
  questions <- trimws(paste(
    questions,
    ifelse(orphaned, paste(
      "This column was named in component_labels but its worksheet declares no total_label,",
      "so it is recorded standalone rather than given a dangling parent."
    ), ""),
    ifelse(mixed_sheet, paste(
      "This worksheet is not homogeneous -- its columns differ in unit, scale or frequency --",
      "so a sheet-wide judgement may not hold for this column. Confirm against the column header."
    ), "")
  ))

  proposals <- tibble::tibble(
    series_id = rows$series_id,
    definition = paste0(
      blank_na(rows$label), " -- as published on ", blank_na(rows$source_sheet), ": ",
      blank_na(rows$table_title)
    ),
    definition_evidence_uri = paste0(
      "worksheet:", blank_na(rows$source_id), "/", blank_na(rows$source_sheet),
      "!r", blank_na(rows$source_row), "c", blank_na(rows$source_column)
    ),
    source_semantics = paste0(
      "Worksheet ", blank_na(rows$source_sheet), ", column path '", blank_na(rows$series_path),
      "'. Read from the published table; no derivation applied to the value."
    ),
    frequency = rows$frequency,
    reference_period_convention = dplyr::case_when(
      rows$frequency %in% c("monthly", "monthly_survey") ~
        "calendar month; period_start is the first day and period_end the last",
      rows$frequency == "quarterly" ~
        "calendar quarter; period_start is the first day and period_end the last",
      rows$frequency == "semiannual" ~ "calendar half-year",
      rows$frequency == "annual" ~
        "calendar year; period_start is 1 January and period_end 31 December",
      TRUE ~ "see docs/TEMPORAL_CONTRACT.md"
    ),
    timing_basis = rows$timing_basis,
    stock_flow = stated(rows$stock_flow, rows$stock_flow_sheet),
    unit_code = rows$unit_code,
    scale_multiplier = format(rows$scale_multiplier, scientific = FALSE, trim = TRUE),
    currency = ifelse(is.na(rows$currency), "not_applicable", rows$currency),
    valuation = stated(rows$valuation, rows$valuation_sheet),
    nominal_real = stated(rows$nominal_real, rows$nominal_real_sheet),
    price_base_year = ifelse(
      is.na(rows$price_base_year) | !nzchar(blank_na(rows$price_base_year)),
      blank_na(rows$price_base_year_sheet), blank_na(rows$price_base_year)
    ),
    seasonal_adjustment = stated(rows$seasonal_adjustment, rows$seasonal_adjustment_sheet),
    transformation = ifelse(
      is.na(rows$transformation) | rows$transformation == "not_reviewed",
      "level", rows$transformation
    ),
    hierarchy_role = ifelse(is_total, "total", ifelse(is_component, "component", "standalone")),
    parent_series_id = blank_na(parent),
    methodology_regime_id = blank_na(rows$methodology_regime_id),
    comparability = rows$comparability,
    availability_convention = paste0(
      "Observed in the retained vintage only: last period ", blank_na(rows$last_period),
      " against a publication date of ", blank_na(rows$publication_date),
      ". No publication calendar has been recorded; see docs/ACQUISITION_RUNBOOK.md."
    ),
    proposal_evidence = paste0(
      "Worksheet title: '", blank_na(rows$table_title), "'. Column label: '",
      blank_na(rows$label), "'. Coverage ", blank_na(rows$first_period), " to ",
      blank_na(rows$last_period), " (", blank_na(rows$observations), " periods). ", provenance,
      if (any(nzchar(blank_na(rows$reviewer_note)))) "" else "",
      ifelse(nzchar(blank_na(rows$reviewer_note)),
             paste0(" Reviewer note: ", blank_na(rows$reviewer_note)), "")
    ),
    source_cell = paste0(
      blank_na(rows$source_id), "/", blank_na(rows$source_sheet), "!r",
      blank_na(rows$source_row), "c", blank_na(rows$source_column)
    ),
    proposed_by = paste0(
      "worksheet_review.R, expanded from the reviewed decision on ",
      blank_na(rows$source_id), "/", blank_na(rows$source_sheet)
    ),
    proposed_at = format(Sys.Date(), "%Y-%m-%d"),
    confidence = ifelse(mixed_sheet, "medium", "high"),
    open_questions = questions
  )
  proposals <- proposals[!duplicated(proposals$series_id), , drop = FALSE]

  # Existing proposals for the same series are replaced, not duplicated: a
  # reviewer who changes a worksheet answer and re-expands must get the new
  # answer, and hand-written per-series proposals must survive.
  existing <- if (file.exists(file.path(root, SERIES_PROPOSAL_PATH))) readr::read_csv(
    file.path(root, SERIES_PROPOSAL_PATH), show_col_types = FALSE,
    col_types = readr::cols(.default = readr::col_character())
  ) else NULL
  # A sheet-wide judgement is weaker evidence than a row somebody wrote about
  # one series, so it does not silently overwrite one. Rows this script produced
  # before are replaced -- re-expanding after changing an answer has to take
  # effect -- and hand-written rows are kept and reported, unless --overwrite
  # says otherwise.
  overwrite <- "--overwrite" %in% commandArgs(trailingOnly = TRUE)
  kept_by_hand <- character()
  if (!is.null(existing)) {
    from_worksheet <- grepl("^worksheet_review\\.R", coalesce_chr(existing$proposed_by, ""))
    protected <- if (overwrite) rep(FALSE, nrow(existing)) else !from_worksheet
    kept_by_hand <- intersect(existing$series_id[protected], proposals$series_id)
    proposals <- proposals[!proposals$series_id %in% kept_by_hand, , drop = FALSE]
    replaced <- sum(existing$series_id %in% proposals$series_id)
    combined <- dplyr::bind_rows(
      existing[!existing$series_id %in% proposals$series_id, , drop = FALSE],
      proposals[names(existing)]
    )
  } else {
    replaced <- 0L
    combined <- proposals
  }
  if (length(kept_by_hand)) message(
    length(kept_by_hand), " series already had a hand-written proposal and were left alone:\n  - ",
    paste(utils::head(kept_by_hand, 10), collapse = "\n  - "),
    "\nPass --overwrite to replace them with the worksheet judgement."
  )
  readr::write_csv(combined, file.path(root, SERIES_PROPOSAL_PATH), na = "")
  message(
    "Expanded ", nrow(accepted), " worksheet(s) into ", nrow(proposals), " series proposal(s) (",
    replaced, " replaced an existing row).\n",
    nrow(combined), " proposal(s) now in ", SERIES_PROPOSAL_PATH, ".\n",
    "Read them with `Rscript sign_off_reviews.R`, then sign with --reviewer=\"Your Name\"."
  )
  invisible(nrow(proposals))
}

main <- function(args = commandArgs(trailingOnly = TRUE)) {
  con <- connect_project_database(
    file.path(root, "database", "paraguay_macro_pilot.duckdb"), read_only = TRUE
  )
  on.exit(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE), add = TRUE)
  dir.create(file.path(root, "config", "proposals"), showWarnings = FALSE, recursive = TRUE)
  if ("--expand" %in% args) expand_worksheet_review(con, root)
  else generate_worksheet_review(con, root)
}

if (!interactive() && identical(environment(), globalenv())) main()
