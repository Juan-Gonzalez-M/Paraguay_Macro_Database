# --- Source-to-target reconciliation ----------------------------------------
# The audit's P0: "for each source table/release, numeric source cells =
# accepted + rejected + documented exclusions", and no source cell may feed more
# than one observation without a documented many-to-one rule.
#
# Broad coverage is not the same as correct coverage. Counting parsed
# observations proves nothing on its own; the question is whether every numeric
# cell the parser claimed to interpret became exactly one observation. Two
# measures answer it, and both are computed from coordinates the pipeline
# already records on every observation (source_row / source_column):
#
#   cell_reuse          accepted observations minus distinct consumed cells.
#                       Must be zero. This is the invariant the compensatory FX
#                       defect violated -- it re-read the same year block under
#                       later years, producing 345 reused cells and 1,005
#                       duplicated observations. Release-blocking.
#
#   unmapped_in_region  numeric cells inside the rectangle the parser actually
#                       consumed that became neither an observation nor a
#                       recorded discard. This is what the CUADRO 61 defect
#                       looked like from the outside: 394 cells present in the
#                       source and silently absent from the database.
#
# Cells outside that rectangle are period-axis headers, numeric row labels and
# footnote markers. They are recorded as out_of_region_cells for transparency
# but are deliberately not part of the balance: the parser never claimed them.
# Treating them as unexplained would bury the signal that matters in structural
# noise present on nearly every worksheet.
#
# The follow-up audit found the first version of this too weak to close the
# question it asks. A scalar excluded_cells count per worksheet says how many
# cells someone waved through, not which ones or why, so it cannot distinguish
# "these forty cells are the published annual subtotal" from "forty observations
# went missing and nobody noticed". Two of the sheets that carried an
# unexplained residual turned out to be the second kind: CUADRO 59 was losing
# 480 external-debt observations to footnote-marked month labels, and
# banking_indicators sheet 1 was dropping two entire published columns.
#
# So the residual is now resolved cell by cell. config/reconciliation_cell_rules.csv
# maps coordinate rectangles to a classification with a reason, the worksheet
# evidence, and a named reviewer; every unmapped cell must match exactly one
# rule; and any cell that matches none blocks the release rather than the
# release recording a warning and continuing.

RECONCILIATION_STATUS_VALUES <- c(
  "balanced",             # every in-region numeric cell is an observation or a classified non-observation
  "defects_recorded",     # fully classified, but a rule says real data is not being read
  "unexplained_cells",    # in-region cells matching no rule at all
  "cell_reuse_detected"   # one source cell feeding several observations
)

# What a numeric cell inside the parsed region can be, if it is not an
# observation. The first four are reasons a cell legitimately carries no
# observation; the last two are admissions that it should and does not, and both
# keep a worksheet out of v_research_series until the parser is repaired.
RECONCILIATION_CELL_CLASSIFICATIONS <- c(
  "header_or_label",       # a period axis, row number, code or footnote marker that happens to be numeric
  "subtotal_or_formula",   # a published total or derived cell the parser deliberately does not re-read
  "report_layout_derived", # interannual comparison and variation columns: report layout, not a time observation
  "out_of_scope_block",    # a second table on the same worksheet that this parser does not claim
  "parser_defect",         # published data the parser fails to read; the residual is real loss
  "observation_expected"   # a repair is landing and these cells are expected to become observations
)

RECONCILIATION_DEFECT_CLASSIFICATIONS <- c("parser_defect", "observation_expected")

# Who may sign a rule.
#
# Every classification here is a claim about worksheet layout -- this row is the
# published monthly average, this column carries no header, this block is a
# second table -- and every one of them is checkable by opening the workbook at
# the coordinates the rule names. That is a different kind of claim from "this
# series is a stock measured at end-period", which no amount of reading the
# worksheet can settle and which the canonical and table_status registers
# therefore require a named economist for.
#
# So layout claims may be signed 'layout_verified', on one condition the guard
# enforces: the evidence field must quote what is actually in the worksheet, so
# a reader can check the claim rather than take it. A rule that says only
# "not data" is rejected.
RECONCILIATION_LAYOUT_REVIEWER <- "layout_verified"
RECONCILIATION_MINIMUM_EVIDENCE_CHARACTERS <- 24L

# Unbounded ends of a rule rectangle. A rule that says "column 9, every row"
# writes '*' rather than guessing a row count that the next publication changes.
RECONCILIATION_UNBOUNDED <- "*"
RECONCILIATION_LOWER_SENTINEL <- -1e15
RECONCILIATION_UPPER_SENTINEL <- 1e15

# Resolving a register keyed (source_id, source_sheet) with '*' as the
# source-level rule, exactly once.
#
# The seventh audit's F-06. `config/source_grains.csv` has been keyed by
# worksheet since schema 32, and write_coverage_dashboard() still joined it on
# source_id alone -- so every worksheet of a source with N rules appeared N
# times. direct_investment has three, and its seven worksheets each appeared
# three times under contradictory grains: 256 dashboard rows for 242 worksheets,
# and any sum over the file triple-counted direct investment.
#
# The idiom for doing this correctly was already in the same function, sixteen
# lines below the defect, written for table_status. Copying it a third time is
# how the second copy came to be wrong, so it is written once here.
#
# It also repairs the copy it replaces, which was wrong in a quieter way: the
# inner select dropped the register's own source_sheet, so the tie-break
# `CASE WHEN source_sheet = '*'` was reading the *worksheet's* name, which is
# never '*'. The window's ordering was therefore constant and the winner
# arbitrary whenever a source carried both a wildcard and an exact rule -- five
# sources and fifteen worksheets do. It is latent today because all fifteen
# exact rules agree with their wildcard on status, parser_claim and reviewed_by;
# it stops being latent the first time someone overrides one.
wildcard_precedence_join_sql <- function(register, columns, keys_sql,
                                         wildcard = RECONCILIATION_UNBOUNDED) {
  selected <- paste(paste0("r.", columns), collapse = ", ")
  paste(
    "SELECT source_id, source_sheet,", paste(columns, collapse = ", "),
    "FROM (SELECT x.source_id, x.source_sheet,", selected, ",",
    "  row_number() OVER (PARTITION BY x.source_id, x.source_sheet",
    "    ORDER BY CASE WHEN r.source_sheet =", sql_string(wildcard), "THEN 1 ELSE 0 END,",
    "             r.source_sheet) AS precedence",
    "FROM (", keys_sql, ") x",
    "JOIN", register, "r ON r.source_id = x.source_id",
    " AND (r.source_sheet = x.source_sheet OR r.source_sheet =", sql_string(wildcard), "))",
    "WHERE precedence = 1"
  )
}

read_reconciliation_cell_rules <- function(root) {
  read_cell_rule_register(
    file.path(root, "config", "reconciliation_cell_rules.csv"),
    RECONCILIATION_CELL_CLASSIFICATIONS, "Reconciliation guard"
  )
}

# Both cell registers -- what an unread cell *inside* the parsed rectangle is,
# and what a numeric cell *outside* it is -- are the same shape of claim: a
# coordinate rectangle, a classification from a closed vocabulary, a reason, the
# worksheet evidence, and a named reviewer. They differ only in their vocabulary
# and in which guard is speaking, so they share the reader rather than each
# growing its own copy of these checks.
read_cell_rule_register <- function(path, classifications, guard) {
  required <- c("source_id", "source_sheet", "row_from", "row_to", "column_from", "column_to",
                "classification", "expected_cells", "reason", "evidence", "reviewed_by",
                "reviewed_at")
  if (!file.exists(path)) stop(guard, ": configuration not found: ", path, call. = FALSE)
  # trim_ws = FALSE, because a worksheet name is whatever the publisher typed and
  # several of them end in a space: 'CUADRO 10 ', 'CUADRO 17 ', 'Subastas 2015 '.
  # Trimming the register's copy while the database keeps the real one makes the
  # rule silently match nothing. Every other field is trimmed explicitly below.
  rules <- readr::read_csv(
    path, col_types = readr::cols(.default = readr::col_character()), trim_ws = FALSE
  )
  if (!identical(names(rules), required)) stop(
    guard, ": ", basename(path), " columns changed or are reordered.", call. = FALSE
  )
  if (!nrow(rules)) return(reconciliation_empty_rules())
  for (field in setdiff(required, "source_sheet")) rules[[field]] <- trimws(rules[[field]])
  for (field in required) {
    if (any(is.na(rules[[field]]) | !nzchar(trimws(rules[[field]])))) stop(
      guard, ": ", field, " is required on every rule row. A rule is a reviewed claim ",
      "about what specific source cells are.", call. = FALSE
    )
  }
  invalid <- setdiff(unique(rules$classification), classifications)
  if (length(invalid)) stop(
    guard, ": unsupported classification(s): ", paste(invalid, collapse = "; "),
    ". Allowed: ", paste(classifications, collapse = ", "), ".", call. = FALSE
  )
  if (any(rules$reviewed_by == "unreviewed")) stop(
    guard, ": ", basename(path), " requires a named reviewer or '",
    RECONCILIATION_LAYOUT_REVIEWER, "'. Declaring that a source cell is not data is a review ",
    "claim, not a parser outcome.", call. = FALSE
  )
  # A layout signature is accepted only where the evidence lets a reader check
  # the claim against the worksheet. Without that it is an assertion, and an
  # unsigned assertion is what this register exists to stop.
  layout_signed <- rules$reviewed_by == RECONCILIATION_LAYOUT_REVIEWER
  thin <- layout_signed & nchar(trimws(rules$evidence)) < RECONCILIATION_MINIMUM_EVIDENCE_CHARACTERS
  if (any(thin)) stop(
    guard, ": a rule signed '", RECONCILIATION_LAYOUT_REVIEWER, "' must quote what ",
    "the worksheet actually shows at those coordinates, so the claim can be checked. ",
    sum(thin), " rule(s) do not.", call. = FALSE
  )
  dates <- suppressWarnings(lubridate::ymd(rules$reviewed_at, quiet = TRUE))
  if (any(is.na(dates))) stop(
    guard, ": reviewed_at must use valid YYYY-MM-DD dates.", call. = FALSE
  )

  bounds <- lapply(c("row_from", "row_to", "column_from", "column_to"), function(field) {
    raw <- trimws(rules[[field]])
    sentinel <- if (grepl("_from$", field)) RECONCILIATION_LOWER_SENTINEL else RECONCILIATION_UPPER_SENTINEL
    parsed <- suppressWarnings(as.numeric(raw))
    parsed[raw == RECONCILIATION_UNBOUNDED] <- sentinel
    if (any(is.na(parsed))) stop(
      guard, ": ", field, " must be a whole number or '", RECONCILIATION_UNBOUNDED,
      "'.", call. = FALSE
    )
    parsed
  })
  names(bounds) <- c("row_from", "row_to", "column_from", "column_to")
  if (any(bounds$row_to < bounds$row_from) || any(bounds$column_to < bounds$column_from)) stop(
    guard, ": a rule rectangle ends before it starts.", call. = FALSE
  )

  # How many cells the reviewer actually looked at. A rule has to be broad enough
  # to survive the next publication shifting rows, which means it is also broad
  # enough to quietly absorb a new defect that appears inside it. Recording the
  # verified count turns that into a visible change instead of a silent one:
  # apply_table_reconciliation() reports any rule whose match count moves.
  expected <- trimws(rules$expected_cells)
  expected_cells <- suppressWarnings(as.integer(expected))
  expected_cells[expected == RECONCILIATION_UNBOUNDED] <- NA_integer_
  if (any(is.na(expected_cells) & expected != RECONCILIATION_UNBOUNDED)) stop(
    guard, ": expected_cells must be a non-negative whole number or '",
    RECONCILIATION_UNBOUNDED, "'.", call. = FALSE
  )
  if (any(!is.na(expected_cells) & expected_cells < 0L)) stop(
    guard, ": expected_cells must not be negative.", call. = FALSE
  )

  rows <- tibble::tibble(
    source_id = rules$source_id, source_sheet = rules$source_sheet,
    row_from = bounds$row_from, row_to = bounds$row_to,
    column_from = bounds$column_from, column_to = bounds$column_to,
    classification = rules$classification, expected_cells = expected_cells,
    reason = rules$reason, evidence = rules$evidence,
    reviewed_by = rules$reviewed_by, reviewed_at = dates
  )
  rows$rule_id <- reconciliation_rule_id(rows)
  if (anyDuplicated(rows$rule_id)) stop(
    guard, ": two rules cover the same source, sheet and rectangle.", call. = FALSE
  )
  rows[c("rule_id", names(rows)[names(rows) != "rule_id"])]
}

reconciliation_empty_rules <- function() {
  tibble::tibble(
    rule_id = character(), source_id = character(), source_sheet = character(),
    row_from = double(), row_to = double(), column_from = double(), column_to = double(),
    classification = character(), expected_cells = integer(), reason = character(),
    evidence = character(), reviewed_by = character(), reviewed_at = as.Date(character())
  )
}

# digest() hashes its whole argument, so it is applied one key at a time; passing
# the vector in returns a single hash recycled across every row.
reconciliation_rule_id <- function(rows) {
  if (!nrow(rows)) return(character())
  keys <- paste(
    rows$source_id, rows$source_sheet, rows$row_from, rows$row_to,
    rows$column_from, rows$column_to, sep = "|"
  )
  paste0("rule:", substr(vapply(
    keys, function(key) digest::digest(key, algo = "sha256", serialize = FALSE), character(1)
  ), 1L, 24L))
}

# The two layers do not share a coordinate system, and the first version of this
# reconciliation did not know that.
#
# report_cell_values stores each worksheet cropped to its used range: the raw
# ingestion path takes the submatrix from (content_first_row, content_first_col)
# and numbers it from 1, a convention read_source_sheet() preserves deliberately.
# The parsers work on the uncropped sheet and record A1 coordinates. On a
# worksheet whose content starts at A1 the two agree, which is why this went
# unnoticed; on one starting at B2 every coordinate is off by one, and a join
# between them matches the wrong cells in both directions.
#
# The effect was large. Comparing the layers untranslated reported 18,883
# unexplained cells across 47 worksheets. Translating the raw side into A1 --
# which is all the offset below does -- leaves 5,842 across 22. The difference
# was never missing data; it was this join. What remains is real, and includes
# the CUADRO 59 and CUADRO 55 losses that the footnote repair addresses.
#
# The translation is applied here rather than by rewriting 700,000 raw rows into
# A1 coordinates: the cropped convention is what the raw layer has always meant,
# and changing it would silently reinterpret every stored coordinate. v_report_cells_a1
# exposes the translated form for anyone joining the layers by hand.
RECONCILIATION_CROP_ORIGIN <- paste(
  "SELECT vintage_id, sheet_name AS source_sheet,",
  "coalesce(content_first_row, 1) - 1 AS row_offset,",
  "coalesce(content_first_col, 1) - 1 AS column_offset",
  "FROM source_sheets"
)

# The parsed region and the two invariants: these are measurements, not
# judgements, and nothing about them depends on the rule register.
compute_table_reconciliation <- function(con) {
  DBI::dbGetQuery(con, paste(
    "WITH crop AS (", RECONCILIATION_CROP_ORIGIN, "),",
    "region AS (",
    "  SELECT vintage_id, source_id, source_sheet,",
    "         count(*) AS accepted_observations,",
    "         count(DISTINCT (source_row::VARCHAR || ':' || source_column::VARCHAR)) AS accepted_cells,",
    "         min(source_row) AS r0, max(source_row) AS r1,",
    "         min(source_column) AS c0, max(source_column) AS c1",
    "  FROM documented_series_snapshot",
    "  WHERE source_row IS NOT NULL AND source_column IS NOT NULL",
    "  GROUP BY 1, 2, 3",
    "), consumed AS (",
    "  SELECT DISTINCT vintage_id, source_id, source_sheet, source_row, source_column",
    "  FROM documented_series_snapshot",
    "), cells AS (",
    "  SELECT v.vintage_id, v.source_id, v.source_sheet,",
    "         c.row_id + k.row_offset AS row_id, c.column_id + k.column_offset AS column_id",
    "  FROM report_sheet_vintages v",
    "  JOIN crop k ON k.vintage_id = v.vintage_id AND k.source_sheet = v.source_sheet",
    "  JOIN report_cell_values c USING (sheet_version_id)",
    "  WHERE c.raw_value_num IS NOT NULL",
    "), rejected AS (",
    "  SELECT vintage_id, source_sheet, count(*) AS rejected_observations",
    "  FROM discarded_rows GROUP BY 1, 2",
    ")",
    "SELECT g.vintage_id, g.source_id, g.source_sheet,",
    "       g.accepted_observations, g.accepted_cells,",
    "       g.accepted_observations - g.accepted_cells AS cell_reuse,",
    "       count(c.row_id) AS numeric_source_cells,",
    "       coalesce(any_value(j.rejected_observations), 0) AS rejected_observations,",
    "       sum(CASE WHEN c.row_id BETWEEN g.r0 AND g.r1",
    "                 AND c.column_id BETWEEN g.c0 AND g.c1",
    "                 AND u.source_row IS NULL THEN 1 ELSE 0 END) AS unmapped_in_region,",
    "       sum(CASE WHEN c.row_id NOT BETWEEN g.r0 AND g.r1",
    "                  OR c.column_id NOT BETWEEN g.c0 AND g.c1 THEN 1 ELSE 0 END) AS out_of_region_cells",
    "FROM region g",
    "LEFT JOIN cells c USING (vintage_id, source_id, source_sheet)",
    "LEFT JOIN consumed u ON u.vintage_id = g.vintage_id AND u.source_id = g.source_id",
    "  AND u.source_sheet = g.source_sheet AND u.source_row = c.row_id",
    "  AND u.source_column = c.column_id",
    "LEFT JOIN rejected j ON j.vintage_id = g.vintage_id AND j.source_sheet = g.source_sheet",
    "GROUP BY 1, 2, 3, 4, 5, 6"
  ))
}

# --- CSV row accounting ------------------------------------------------------
# The audit's F-05 and section 11.3, in the same table as the worksheet
# accounting so that one report answers "is every part of this source accounted
# for" for all 22 of them.
#
#   source data rows = accepted rows + rejected rows + documented exclusions
#
# Everything it needs is already durable, which is what makes this computable
# release-wide instead of at parse time -- and it has to be release-wide, because
# apply_table_reconciliation() rebuilds this table every run and an unchanged
# source is never re-parsed:
#
#   source rows  raw.source_sheets content bounds, minus the header row
#   accepted     the snapshot named by config/long_csv_contracts.csv
#   rejected     staging.discarded_rows, which compute_table_reconciliation()
#                already reads for the worksheet path
#
# The column names are the worksheet path's -- `numeric_source_cells`,
# `accepted_observations`. Read them as "what the source offered" and "what was
# taken from it"; the unit is a row here and a cell there.
compute_csv_row_reconciliation <- function(con, root, release_id) {
  path <- file.path(root, "config", "long_csv_contracts.csv")
  if (!file.exists(path)) return(tibble())
  contracts <- readr::read_csv(
    path, show_col_types = FALSE, col_types = readr::cols(.default = readr::col_character())
  )
  rows <- list()
  for (i in seq_len(nrow(contracts))) {
    table_name <- contracts$table_name[[i]]
    if (!database_object_exists(con, table_name)) next
    measured <- DBI::dbGetQuery(con, paste0(
      "WITH offered AS (",
      "  SELECT vintage_id, source_id,",
      "         coalesce(content_last_row, 0) - coalesce(content_first_row, 1) AS source_rows",
      "  FROM ", project_qualified_name("source_sheets"),
      "  WHERE source_id = ", sql_string(contracts$source_id[[i]]), " AND sheet_name = 'data'",
      "), accepted AS (",
      "  SELECT vintage_id, count(*) AS accepted_rows FROM ",
      project_qualified_name(table_name), " GROUP BY 1",
      "), rejected AS (",
      "  SELECT vintage_id, count(*) AS rejected_rows FROM ",
      project_qualified_name("discarded_rows"), " WHERE source_sheet = 'data' GROUP BY 1",
      ") SELECT o.vintage_id, o.source_id, o.source_rows,",
      "  coalesce(a.accepted_rows, 0) AS accepted_rows,",
      "  coalesce(r.rejected_rows, 0) AS rejected_rows",
      " FROM offered o LEFT JOIN accepted a USING (vintage_id)",
      " LEFT JOIN rejected r USING (vintage_id)"
    ))
    if (!nrow(measured)) next
    rows[[length(rows) + 1L]] <- measured %>% dplyr::transmute(
      vintage_id = .data$vintage_id, source_id = .data$source_id, source_sheet = "data",
      release_id = .env$release_id,
      numeric_source_cells = as.numeric(.data$source_rows),
      accepted_observations = as.numeric(.data$accepted_rows),
      rejected_observations = as.numeric(.data$rejected_rows),
      documented_exclusions = 0L, many_to_one_allowance = 0L,
      balance_delta = as.numeric(
        .data$source_rows - .data$accepted_rows - .data$rejected_rows
      ),
      status = dplyr::if_else(
        .data$source_rows - .data$accepted_rows - .data$rejected_rows == 0,
        "balanced", "unexplained_cells"
      ),
      note = dplyr::if_else(
        .data$source_rows - .data$accepted_rows - .data$rejected_rows == 0,
        paste0(
          .data$source_rows, " data row(s): ", .data$accepted_rows, " accepted, ",
          .data$rejected_rows, " rejected with a recorded reason."
        ),
        paste0(
          abs(.data$source_rows - .data$accepted_rows - .data$rejected_rows), " data row(s) of ",
          .data$source_rows, " are neither accepted nor recorded as a rejection. Every row of a ",
          "delimited source must be one or the other."
        )
      ),
      checked_at = Sys.time(),
      accepted_cells = as.numeric(.data$accepted_rows), cell_reuse = 0,
      unmapped_in_region = 0, out_of_region_cells = 0, classified_cells = 0L,
      unclassified_cells = as.integer(pmax(
        .data$source_rows - .data$accepted_rows - .data$rejected_rows, 0
      )),
      parser_defect_cells = 0L
    )
  }
  if (!length(rows)) return(tibble())
  dplyr::bind_rows(rows)
}

# Resolve every unmapped cell against the rule register. Precedence is
# most-specific-wins: a rule naming the worksheet beats a source-wide '*' rule,
# and a smaller rectangle beats a larger one. Ties would make the classification
# depend on row order, so the rule_id breaks them deterministically.
classify_unmapped_cells <- function(con, rules) {
  DBI::dbExecute(con, "DROP TABLE IF EXISTS reconciliation_rule_scratch")
  DBI::dbExecute(con, paste(
    "CREATE TEMPORARY TABLE reconciliation_rule_scratch (",
    "rule_id VARCHAR, source_id VARCHAR, source_sheet VARCHAR,",
    "row_from DOUBLE, row_to DOUBLE, column_from DOUBLE, column_to DOUBLE,",
    "classification VARCHAR)"
  ))
  on.exit(try(
    DBI::dbExecute(con, "DROP TABLE IF EXISTS reconciliation_rule_scratch"), silent = TRUE
  ), add = TRUE)
  if (nrow(rules)) DBI::dbWriteTable(
    con, "reconciliation_rule_scratch",
    rules[c("rule_id", "source_id", "source_sheet", "row_from", "row_to",
            "column_from", "column_to", "classification")],
    append = TRUE
  )
  DBI::dbGetQuery(con, paste(
    "WITH crop AS (", RECONCILIATION_CROP_ORIGIN, "),",
    "region AS (",
    "  SELECT vintage_id, source_id, source_sheet,",
    "         min(source_row) AS r0, max(source_row) AS r1,",
    "         min(source_column) AS c0, max(source_column) AS c1",
    "  FROM documented_series_snapshot",
    "  WHERE source_row IS NOT NULL AND source_column IS NOT NULL",
    "  GROUP BY 1, 2, 3",
    "), consumed AS (",
    "  SELECT DISTINCT vintage_id, source_id, source_sheet, source_row, source_column",
    "  FROM documented_series_snapshot",
    "), unmapped AS (",
    # Coordinates are translated into A1 before anything is compared, for the
    # reason set out above compute_table_reconciliation().
    "  SELECT g.vintage_id, g.source_id, g.source_sheet,",
    "         c.row_id + k.row_offset AS row_id, c.column_id + k.column_offset AS column_id",
    "  FROM region g",
    "  JOIN report_sheet_vintages v",
    "    ON v.vintage_id = g.vintage_id AND v.source_sheet = g.source_sheet",
    "  JOIN crop k ON k.vintage_id = g.vintage_id AND k.source_sheet = g.source_sheet",
    "  JOIN report_cell_values c ON c.sheet_version_id = v.sheet_version_id",
    "  LEFT JOIN consumed u ON u.vintage_id = g.vintage_id AND u.source_id = g.source_id",
    "    AND u.source_sheet = g.source_sheet AND u.source_row = c.row_id + k.row_offset",
    "    AND u.source_column = c.column_id + k.column_offset",
    "  WHERE c.raw_value_num IS NOT NULL AND u.source_row IS NULL",
    "    AND c.row_id + k.row_offset BETWEEN g.r0 AND g.r1",
    "    AND c.column_id + k.column_offset BETWEEN g.c0 AND g.c1",
    "), matched AS (",
    "  SELECT m.vintage_id, m.source_id, m.source_sheet, m.row_id, m.column_id,",
    "         r.rule_id, r.classification,",
    "         row_number() OVER (",
    "           PARTITION BY m.vintage_id, m.source_sheet, m.row_id, m.column_id",
    "           ORDER BY CASE WHEN r.source_sheet = ", sql_string(RECONCILIATION_UNBOUNDED),
    "                    THEN 1 ELSE 0 END,",
    "                    (r.row_to - r.row_from) * (r.column_to - r.column_from),",
    "                    r.rule_id",
    "         ) AS precedence",
    "  FROM unmapped m",
    "  LEFT JOIN reconciliation_rule_scratch r",
    "    ON r.source_id = m.source_id",
    "   AND (r.source_sheet = m.source_sheet OR r.source_sheet = ",
    sql_string(RECONCILIATION_UNBOUNDED), ")",
    "   AND m.row_id BETWEEN r.row_from AND r.row_to",
    "   AND m.column_id BETWEEN r.column_from AND r.column_to",
    ")",
    "SELECT vintage_id, source_id, source_sheet, row_id, column_id,",
    "coalesce(classification, 'unclassified') AS classification, rule_id",
    "FROM matched WHERE precedence = 1"
  ))
}

apply_table_reconciliation <- function(con, release_id, root) {
  measured <- compute_table_reconciliation(con)
  csv_rows <- compute_csv_row_reconciliation(con, root, release_id)
  if (!nrow(measured)) {
    if (nrow(csv_rows)) with_project_transaction(con, {
      DBI::dbExecute(con, "DELETE FROM table_reconciliation")
      DBI::dbWriteTable(con, "table_reconciliation", csv_rows, append = TRUE)
    })
    return(invisible(measured))
  }
  rules <- read_reconciliation_cell_rules(root)
  classified <- classify_unmapped_cells(con, rules)

  # A rule that matches nothing is either a typo or a repair that already
  # landed. Either way the register is now describing a worksheet that does not
  # look like that, so say so rather than carrying a rule nobody can verify.
  matched_counts <- table(classified$rule_id[!is.na(classified$rule_id)])
  unused <- setdiff(rules$rule_id, names(matched_counts))
  if (length(unused)) insert_quality_flag(
    con, release_id, "warning", "reconciliation_rule_unused", NA_character_,
    paste0(
      length(unused), " reconciliation cell rule(s) match no unmapped cell. Either the coordinates ",
      "are wrong or the parser has since been repaired: ",
      paste(head(unused, 5), collapse = "; ")
    )
  )
  # A rule whose match count has moved is covering something the reviewer did not
  # look at. The rule still classifies the cells, so the release is not blocked,
  # but the change is surfaced instead of absorbed.
  verified <- rules[!is.na(rules$expected_cells), , drop = FALSE]
  if (nrow(verified)) {
    observed <- as.integer(matched_counts[verified$rule_id])
    observed[is.na(observed)] <- 0L
    drifted <- which(observed != verified$expected_cells)
    if (length(drifted)) insert_quality_flag(
      con, release_id, "warning", "reconciliation_rule_scope_changed", NA_character_,
      paste0(
        length(drifted), " reconciliation cell rule(s) now cover a different number of cells than ",
        "the reviewer verified. Re-check the worksheet and update expected_cells: ",
        paste(head(paste0(
          verified$source_id[drifted], "/", verified$source_sheet[drifted],
          " (", verified$expected_cells[drifted], " -> ", observed[drifted], ")"
        ), 5), collapse = "; ")
      )
    )
  }

  counts <- classified %>%
    dplyr::group_by(.data$vintage_id, .data$source_sheet) %>%
    dplyr::summarise(
      unclassified_cells = sum(.data$classification == "unclassified"),
      parser_defect_cells = sum(.data$classification %in% RECONCILIATION_DEFECT_CLASSIFICATIONS),
      documented_exclusions = sum(
        .data$classification != "unclassified" &
          !.data$classification %in% RECONCILIATION_DEFECT_CLASSIFICATIONS
      ),
      .groups = "drop"
    )

  rows <- measured %>%
    dplyr::left_join(counts, by = c("vintage_id", "source_sheet")) %>%
    dplyr::mutate(
      unclassified_cells = as.integer(dplyr::coalesce(.data$unclassified_cells, 0L)),
      parser_defect_cells = as.integer(dplyr::coalesce(.data$parser_defect_cells, 0L)),
      documented_exclusions = as.integer(dplyr::coalesce(.data$documented_exclusions, 0L)),
      classified_cells = .data$documented_exclusions + .data$parser_defect_cells,
      many_to_one_allowance = 0L,
      # The residual that matters is what nobody has accounted for at all.
      balance_delta = .data$unclassified_cells,
      status = dplyr::case_when(
        .data$cell_reuse != 0L          ~ "cell_reuse_detected",
        .data$unclassified_cells != 0L  ~ "unexplained_cells",
        .data$parser_defect_cells != 0L ~ "defects_recorded",
        TRUE                            ~ "balanced"
      ),
      note = dplyr::case_when(
        .data$cell_reuse != 0L ~ paste0(
          .data$cell_reuse, " observation(s) beyond the distinct source cells consumed; ",
          "a source cell is feeding more than one observation."
        ),
        .data$unclassified_cells != 0L ~ paste0(
          .data$unclassified_cells, " numeric cell(s) inside the parsed region match no rule in ",
          "config/reconciliation_cell_rules.csv and are neither an observation nor a recorded discard."
        ),
        .data$parser_defect_cells != 0L ~ paste0(
          .data$parser_defect_cells, " numeric cell(s) are published data a reviewer has recorded ",
          "as unread by the current parser; the worksheet cannot be validated until it is repaired."
        ),
        .data$unmapped_in_region != 0L ~ paste0(
          "Every numeric cell in the parsed region is an observation or a classified ",
          "non-observation (", .data$documented_exclusions, " classified)."
        ),
        TRUE ~ "Every numeric cell in the parsed region is accounted for."
      ),
      release_id = release_id,
      checked_at = Sys.time()
    ) %>%
    dplyr::select(
      "vintage_id", "source_id", "source_sheet", "release_id", "numeric_source_cells",
      "accepted_observations", "rejected_observations", "documented_exclusions",
      "many_to_one_allowance", "balance_delta", "status", "note", "checked_at",
      "accepted_cells", "cell_reuse", "unmapped_in_region", "out_of_region_cells",
      "classified_cells", "unclassified_cells", "parser_defect_cells"
    )

  # The two delimited sources join the 242 worksheets here rather than in a
  # report of their own: the question "is every part of this source accounted
  # for" has one answer per source, and until now two of the twenty-two were
  # simply not being asked.
  rows <- dplyr::bind_rows(rows, csv_rows)

  invalid <- setdiff(unique(rows$status), RECONCILIATION_STATUS_VALUES)
  if (length(invalid)) stop(
    "Reconciliation guard: unsupported status value(s): ", paste(invalid, collapse = "; "),
    call. = FALSE
  )

  rule_rows <- rules[c("rule_id", "source_id", "source_sheet", "row_from", "row_to",
                       "column_from", "column_to", "classification", "expected_cells",
                       "reason", "evidence", "reviewed_by", "reviewed_at")]
  cell_rows <- classified[c("vintage_id", "source_id", "source_sheet", "row_id", "column_id",
                            "classification", "rule_id")]
  with_project_transaction(con, {
    DBI::dbExecute(con, "DELETE FROM table_reconciliation")
    DBI::dbWriteTable(con, "table_reconciliation", rows, append = TRUE)
    DBI::dbExecute(con, "DELETE FROM reconciliation_cell_classification")
    DBI::dbExecute(con, "DELETE FROM reconciliation_cell_rules")
    if (nrow(rule_rows)) DBI::dbWriteTable(con, "reconciliation_cell_rules", rule_rows, append = TRUE)
    if (nrow(cell_rows)) DBI::dbWriteTable(
      con, "reconciliation_cell_classification", cell_rows, append = TRUE
    )
  })
  create_reconciliation_views(con)
  if (!is.null(root)) {
    readr::write_csv(rows, file.path(root, "outputs", "table_reconciliation_latest.csv"))
    readr::write_csv(
      cell_rows[cell_rows$classification == "unclassified", , drop = FALSE],
      file.path(root, "outputs", "reconciliation_unclassified_cells.csv")
    )
  }
  invisible(rows)
}

# --- What "balanced" does not cover -----------------------------------------
# The audit's F-03. A worksheet is "balanced" when every numeric cell *inside the
# rectangle the parser consumed* is an observation or a classified
# non-observation. The rectangle is derived from the observations the parser
# emitted, so the measure cannot say anything about a cell the parser never went
# near: an entire published block can be missing and the sheet still balances.
# Catalogue-wide that was 73,830 cells, and until this release nothing asked
# which of them were data. Two of them were: the Call Money Market blocks on the
# interbank sheets, now read.
#
# So the accounting outside the region is built here from the raw cell layer
# *independently of what the parser emitted*, and every cell in it resolves to a
# reviewed classification or to 'unreviewed'. Unreviewed is not a release error --
# a gate nobody can pass is a gate that gets switched off, and nobody classifies
# 73,830 cells in one sitting -- but it does block promotion to validated, which
# is where an unexamined region would turn into a correctness claim.
SOURCE_REGION_CLASSIFICATIONS <- c(
  "period_axis",           # the year, date or period-label column the parser reads as the axis, not as a measure
  "row_index",             # a row number, ordinal or code the publisher prints beside the data
  "header_or_note",        # a numeric header, footnote marker or note sitting outside the table body
  "report_layout_derived", # cumulative-to-date and variation columns: report layout, not a time observation
  "out_of_scope_block",    # a second table on the same worksheet that this parser does not claim
  "data_not_ingested"      # published data outside every parser region: real loss, and it blocks promotion
)

SOURCE_REGION_DEFECT_CLASSIFICATIONS <- "data_not_ingested"

read_source_region_rules <- function(root) {
  path <- file.path(root, "config", "source_region_rules.csv")
  if (!file.exists(path)) return(reconciliation_empty_rules())
  read_cell_rule_register(path, SOURCE_REGION_CLASSIFICATIONS, "Source-region guard")
}

# Every numeric cell of every documented worksheet that no parser region covers,
# resolved against the register. The rectangle is still derived from the
# snapshot, because that is what "the parser's region" means; what is different
# from compute_table_reconciliation() is that the cells come from the raw layer
# and are judged on their own, not counted as a residual.
classify_out_of_region_cells <- function(con, rules) {
  DBI::dbExecute(con, "DROP TABLE IF EXISTS source_region_rule_scratch")
  DBI::dbExecute(con, paste(
    "CREATE TEMPORARY TABLE source_region_rule_scratch (",
    "rule_id VARCHAR, source_id VARCHAR, source_sheet VARCHAR,",
    "row_from DOUBLE, row_to DOUBLE, column_from DOUBLE, column_to DOUBLE,",
    "classification VARCHAR)"
  ))
  on.exit(try(
    DBI::dbExecute(con, "DROP TABLE IF EXISTS source_region_rule_scratch"), silent = TRUE
  ), add = TRUE)
  if (nrow(rules)) DBI::dbWriteTable(
    con, "source_region_rule_scratch",
    rules[c("rule_id", "source_id", "source_sheet", "row_from", "row_to",
            "column_from", "column_to", "classification")],
    append = TRUE
  )
  DBI::dbGetQuery(con, paste(
    "WITH crop AS (", RECONCILIATION_CROP_ORIGIN, "),",
    # The sheet universe is every documented worksheet, not every worksheet that
    # produced an observation. A sheet the parser reads nothing from has no
    # region at all, and deriving the universe from the snapshot would drop it
    # silently -- which is the exact failure this register exists to catch. Its
    # bounds come back NULL and the comparison below then puts every numeric cell
    # outside, which is the truth about it.
    "sheets AS (",
    "  SELECT DISTINCT vintage_id, source_id, source_sheet FROM documented_table_catalog",
    "), region AS (",
    "  SELECT vintage_id, source_sheet,",
    "         min(source_row) AS r0, max(source_row) AS r1,",
    "         min(source_column) AS c0, max(source_column) AS c1",
    "  FROM documented_series_snapshot",
    "  WHERE source_row IS NOT NULL AND source_column IS NOT NULL",
    "  GROUP BY 1, 2",
    "), outside AS (",
    "  SELECT s.vintage_id, s.source_id, s.source_sheet,",
    "         c.row_id + k.row_offset AS row_id, c.column_id + k.column_offset AS column_id",
    "  FROM sheets s",
    "  LEFT JOIN region g ON g.vintage_id = s.vintage_id AND g.source_sheet = s.source_sheet",
    "  JOIN report_sheet_vintages v",
    "    ON v.vintage_id = s.vintage_id AND v.source_sheet = s.source_sheet",
    "  JOIN crop k ON k.vintage_id = s.vintage_id AND k.source_sheet = s.source_sheet",
    "  JOIN report_cell_values c ON c.sheet_version_id = v.sheet_version_id",
    "  WHERE c.raw_value_num IS NOT NULL",
    "    AND (g.r0 IS NULL",
    "         OR c.row_id + k.row_offset NOT BETWEEN g.r0 AND g.r1",
    "         OR c.column_id + k.column_offset NOT BETWEEN g.c0 AND g.c1)",
    "), matched AS (",
    "  SELECT m.vintage_id, m.source_id, m.source_sheet, m.row_id, m.column_id,",
    "         r.rule_id, r.classification,",
    "         row_number() OVER (",
    "           PARTITION BY m.vintage_id, m.source_sheet, m.row_id, m.column_id",
    "           ORDER BY CASE WHEN r.source_sheet = ", sql_string(RECONCILIATION_UNBOUNDED),
    "                    THEN 1 ELSE 0 END,",
    "                    (r.row_to - r.row_from) * (r.column_to - r.column_from),",
    "                    r.rule_id",
    "         ) AS precedence",
    "  FROM outside m",
    "  LEFT JOIN source_region_rule_scratch r",
    "    ON r.source_id = m.source_id",
    "   AND (r.source_sheet = m.source_sheet OR r.source_sheet = ",
    sql_string(RECONCILIATION_UNBOUNDED), ")",
    "   AND m.row_id BETWEEN r.row_from AND r.row_to",
    "   AND m.column_id BETWEEN r.column_from AND r.column_to",
    ")",
    "SELECT vintage_id, source_id, source_sheet, row_id, column_id,",
    "coalesce(classification, 'unreviewed') AS classification, rule_id",
    "FROM matched WHERE precedence = 1"
  ))
}

apply_source_region_classification <- function(con, release_id, root) {
  if (!database_object_exists(con, "source_region_classification")) return(invisible(NULL))
  rules <- read_source_region_rules(root)
  classified <- classify_out_of_region_cells(con, rules)
  rule_rows <- rules[c("rule_id", "source_id", "source_sheet", "row_from", "row_to",
                       "column_from", "column_to", "classification", "expected_cells",
                       "reason", "evidence", "reviewed_by", "reviewed_at")]
  cell_rows <- classified[c("vintage_id", "source_id", "source_sheet", "row_id", "column_id",
                            "classification", "rule_id")]
  with_project_transaction(con, {
    DBI::dbExecute(con, "DELETE FROM source_region_classification")
    DBI::dbExecute(con, "DELETE FROM source_region_rules")
    if (nrow(rule_rows)) DBI::dbWriteTable(con, "source_region_rules", rule_rows, append = TRUE)
    if (nrow(cell_rows)) DBI::dbWriteTable(con, "source_region_classification", cell_rows, append = TRUE)
  })
  create_source_region_views(con)
  # A rule that matches nothing is a typo or a repair that already landed, and
  # either way the register now describes a worksheet that does not look like
  # that. Same reasoning as the in-region register, same severity.
  unused <- setdiff(rules$rule_id, unique(classified$rule_id[!is.na(classified$rule_id)]))
  if (length(unused)) insert_quality_flag(
    con, release_id, "warning", "source_region_rule_unused", NA_character_,
    paste0(
      length(unused), " source-region rule(s) match no out-of-region cell. Either the coordinates ",
      "are wrong or the parser has since been repaired: ", paste(head(unused, 5), collapse = "; ")
    )
  )
  if (!is.null(root)) write_source_region_report(con, root, classified)
  invisible(classified)
}

create_source_region_views <- function(con) {
  create_project_view(con, "v_source_region_completeness", paste(
    "SELECT c.source_id, c.source_sheet, c.classification, count(*) AS cells,",
    "min(c.row_id) AS first_row, max(c.row_id) AS last_row,",
    "string_agg(DISTINCT CAST(c.column_id AS VARCHAR), ', ') AS columns_affected",
    "FROM source_region_classification c GROUP BY 1, 2, 3"
  ))
  create_project_view(con, "v_source_region_unreviewed", paste(
    "SELECT * FROM source_region_classification WHERE classification = 'unreviewed'"
  ))
  invisible(TRUE)
}

# The reviewer's worklist, ordered by how much is unaccounted for, with the
# column ranges each worksheet's unreviewed cells occupy so the question can be
# asked at a coordinate rather than in the abstract.
#
# The audit's R6-07 asks for one thing more: priority "by economically important
# table rather than cell count alone". 6,522 cells sorted by volume puts the LRM
# auction year-sheets at the top, and nobody should review those before the price
# index. So the queue carries the worksheet's economic weight beside its size --
# how many published series it feeds, and whether it is a table anyone is waiting
# on -- and orders by that.
#
# Weight is read from the reviewed domain register, not guessed from labels: a
# worksheet already mapped to a macro domain is one a researcher will reach for.
source_region_review_weight <- function(con) {
  if (!database_object_exists(con, "documented_series_snapshot")) {
    return(tibble(source_id = character(), source_sheet = character(),
                  published_series = integer(), domain = character()))
  }
  series <- DBI::dbGetQuery(con, paste(
    "SELECT source_id, source_sheet, count(DISTINCT series_id) AS published_series",
    "FROM", project_qualified_name("documented_series_snapshot"), "GROUP BY 1, 2"
  ))
  domains <- if (database_object_exists(con, "table_domains")) DBI::dbGetQuery(con, paste(
    "SELECT source_id, source_sheet, domain FROM", project_qualified_name("table_domains")
  )) else tibble(source_id = character(), source_sheet = character(), domain = character())
  dplyr::left_join(series, domains, by = c("source_id", "source_sheet"))
}

write_source_region_report <- function(con, root, classified = NULL) {
  if (is.null(classified)) return(invisible(NULL))
  report <- classified %>%
    dplyr::group_by(.data$source_id, .data$source_sheet) %>%
    dplyr::summarise(
      numeric_cells_outside_region = dplyr::n(),
      unreviewed_cells = sum(.data$classification == "unreviewed"),
      data_not_ingested_cells = sum(.data$classification %in% SOURCE_REGION_DEFECT_CLASSIFICATIONS),
      classified_cells = sum(.data$classification != "unreviewed"),
      columns_affected = paste(sort(unique(.data$column_id)), collapse = ", "),
      .groups = "drop"
    ) %>%
    dplyr::arrange(dplyr::desc(.data$unreviewed_cells), dplyr::desc(.data$numeric_cells_outside_region))
  readr::write_csv(report, file.path(root, "outputs", "source_region_completeness.csv"))
  weight <- source_region_review_weight(con)
  queue <- report[report$unreviewed_cells > 0, , drop = FALSE] %>%
    dplyr::left_join(weight, by = c("source_id", "source_sheet")) %>%
    dplyr::mutate(
      published_series = dplyr::coalesce(.data$published_series, 0L),
      domain = dplyr::coalesce(.data$domain, "undeclared"),
      # A worksheet with a reviewed macro domain outranks one without, and within
      # each the number of published series that depend on it outranks the number
      # of cells nobody has looked at. Cell count breaks ties and no more.
      review_priority = dplyr::case_when(
        .data$domain != "undeclared" & .data$published_series > 0 ~ "1_domain_mapped",
        .data$published_series > 0 ~ "2_publishes_series",
        TRUE ~ "3_no_published_series"
      )
    ) %>%
    dplyr::arrange(
      .data$review_priority, dplyr::desc(.data$published_series),
      dplyr::desc(.data$unreviewed_cells)
    )
  readr::write_csv(queue, file.path(root, "outputs", "source_region_review_queue.csv"))
  readr::write_csv(
    classified[classified$classification == "unreviewed", , drop = FALSE],
    file.path(root, "outputs", "source_region_review_worklist.csv")
  )
  write_out_of_region_cell_regions(con, root, classified)
  invisible(report)
}

# The audit's ER-07.1: "group the worklist by workbook, sheet, contiguous region
# and structural pattern rather than reviewing cells independently."
#
# 6,522 unreviewed cells is not 6,522 decisions. A worksheet's out-of-region
# numbers are almost always a handful of rectangles -- a footnote block, a
# repeated display panel, a year axis the parser stopped short of -- and a
# reviewer who classifies one rectangle has classified every cell in it. The
# row-level file above stays, because a rule has to be written against
# coordinates; this is the file somebody actually works through.
#
# Contiguity is computed the standard way: rows and columns that follow one
# another with no gap belong to the same run. A rectangle is reported with the
# bounds a rule in config/source_region_rules.csv would use, so the output of the
# review is a copy-paste away from the register that records it.
write_out_of_region_cell_regions <- function(con, root, classified) {
  if (is.null(root) || is.null(classified) || !nrow(classified)) return(invisible(NULL))
  unreviewed <- classified[classified$classification == "unreviewed", , drop = FALSE]
  if (!nrow(unreviewed)) return(invisible(NULL))
  unreviewed <- unreviewed[order(
    unreviewed$source_id, unreviewed$source_sheet, unreviewed$column_id, unreviewed$row_id
  ), , drop = FALSE]
  # One group per (sheet, column-run, row-run): a new group starts wherever the
  # sheet changes, the column is not the previous column, or the row skips.
  key <- paste(unreviewed$source_id, unreviewed$source_sheet, unreviewed$column_id, sep = "")
  starts <- c(TRUE, key[-1] != key[-length(key)] |
                diff(unreviewed$row_id) != 1L)
  unreviewed$column_run <- cumsum(starts)
  runs <- unreviewed %>%
    dplyr::group_by(.data$source_id, .data$source_sheet, .data$column_run) %>%
    dplyr::summarise(
      column_from = min(.data$column_id), column_to = max(.data$column_id),
      row_from = min(.data$row_id), row_to = max(.data$row_id),
      cells = dplyr::n(), .groups = "drop"
    )
  # Adjacent columns whose row spans are identical are one rectangle, not one
  # per column: a footnote block three columns wide is a single decision.
  regions <- runs %>%
    dplyr::arrange(.data$source_id, .data$source_sheet, .data$row_from, .data$row_to, .data$column_from) %>%
    dplyr::group_by(.data$source_id, .data$source_sheet, .data$row_from, .data$row_to) %>%
    dplyr::summarise(
      column_from = min(.data$column_from), column_to = max(.data$column_to),
      columns = dplyr::n(), cells = sum(.data$cells), .groups = "drop"
    ) %>%
    dplyr::mutate(
      rows = .data$row_to - .data$row_from + 1L,
      # The shape is the first thing a reviewer reads, and it usually names the
      # structural pattern outright: one row across many columns is an axis or a
      # total line, one column down many rows is an unparsed data column, and a
      # single cell is almost always a footnote marker.
      shape = dplyr::case_when(
        .data$cells == 1L ~ "single_cell",
        .data$rows == 1L ~ "row_band",
        .data$columns == 1L ~ "column_band",
        TRUE ~ "block"
      ),
      suggested_rule = paste0(
        "source_region_rules.csv: ", .data$source_id, ",", .data$source_sheet, ",",
        .data$row_from, ",", .data$row_to, ",", .data$column_from, ",", .data$column_to,
        ",<classification>,", .data$cells
      )
    ) %>%
    dplyr::arrange(dplyr::desc(.data$cells))
  weight <- source_region_review_weight(con)
  regions <- regions %>%
    dplyr::left_join(weight, by = c("source_id", "source_sheet")) %>%
    dplyr::mutate(
      published_series = dplyr::coalesce(.data$published_series, 0L),
      domain = dplyr::coalesce(.data$domain, "undeclared")
    ) %>%
    dplyr::arrange(dplyr::desc(.data$published_series), dplyr::desc(.data$cells))
  readr::write_csv(regions, file.path(root, "outputs", "out_of_region_cells_worklist.csv"))
  invisible(regions)
}

# Consulted by apply_table_status(): a table family cannot be promoted to
# validated while its cell accounting is unexplained. The wildcard row promotes
# every worksheet of a source, so every one of them must balance. A recorded
# parser defect blocks promotion for the same reason an unexplained cell does --
# the difference is only whether someone has named the problem.
unreconciled_table_families <- function(con, validated) {
  if (!nrow(validated)) return(character())
  if (!DBI::dbExistsTable(con, "table_reconciliation")) return(character())
  recon <- DBI::dbGetQuery(
    con, "SELECT source_id, source_sheet, status FROM table_reconciliation"
  )
  if (!nrow(recon)) return(character())
  region_scope <- if (database_object_exists(con, "source_region_classification")) {
    DBI::dbGetQuery(con, paste0(
      "SELECT source_id, source_sheet, classification, count(*) AS cells",
      " FROM source_region_classification WHERE classification IN ('unreviewed', ",
      paste(vapply(SOURCE_REGION_DEFECT_CLASSIFICATIONS, sql_string, character(1)), collapse = ", "),
      ") GROUP BY 1, 2, 3"
    ))
  } else data.frame(
    source_id = character(), source_sheet = character(),
    classification = character(), cells = integer()
  )
  # The audit's F-12 as a promotion condition. A worksheet whose expected periods
  # are absent for a reason nobody established, or absent while the source cell
  # holds a number, has not been shown to be complete either.
  missing_scope <- if (database_object_exists(con, "observation_missingness")) {
    DBI::dbGetQuery(con, paste(
      "SELECT source_id, source_sheet, reason, count(*) AS periods",
      "FROM observation_missingness WHERE reason IN (", paste(vapply(
      OBSERVATION_MISSINGNESS_BLOCKING, sql_string, character(1)), collapse = ", "), ")",
      "GROUP BY 1, 2, 3"
    ))
  } else data.frame(
    source_id = character(), source_sheet = character(),
    reason = character(), periods = integer()
  )
  unresolved <- character()
  for (i in seq_len(nrow(validated))) {
    source_id <- validated$source_id[[i]]
    sheet <- validated$source_sheet[[i]]
    scope <- if (identical(sheet, "*")) {
      recon[recon$source_id == source_id, , drop = FALSE]
    } else {
      recon[recon$source_id == source_id & recon$source_sheet == sheet, , drop = FALSE]
    }
    # The audit's F-03 as a promotion condition. "Balanced" is a statement about
    # the rectangle the parser consumed and says nothing about the cells outside
    # it, so a worksheet with unreviewed or admittedly-unread cells out there has
    # not been shown to be complete -- and completeness is exactly what validating
    # it would be claiming. This is computed before the not-measured branch below
    # returns early, because the worksheet most in need of it is the one the
    # parser reads nothing from: it has no reconciliation row at all, and every
    # numeric cell on it is outside a region that does not exist.
    outside <- if (identical(sheet, "*")) {
      region_scope[region_scope$source_id == source_id, , drop = FALSE]
    } else {
      region_scope[region_scope$source_id == source_id & region_scope$source_sheet == sheet, , drop = FALSE]
    }
    if (nrow(outside)) unresolved <- c(unresolved, paste0(
      outside$source_id, "/", outside$source_sheet, " (", outside$cells, " ",
      outside$classification, " cell(s) outside every parser region)"
    ))
    absent <- if (identical(sheet, "*")) {
      missing_scope[missing_scope$source_id == source_id, , drop = FALSE]
    } else {
      missing_scope[missing_scope$source_id == source_id & missing_scope$source_sheet == sheet, , drop = FALSE]
    }
    if (nrow(absent)) unresolved <- c(unresolved, paste0(
      absent$source_id, "/", absent$source_sheet, " (", absent$periods, " expected period(s) ",
      absent$reason, ")"
    ))
    # A documented worksheet with no reconciliation record has not been measured,
    # which is not the same as having balanced.
    if (!nrow(scope) && !identical(sheet, "*")) {
      measured_source <- any(recon$source_id == source_id)
      if (measured_source) {
        unresolved <- c(unresolved, paste0(source_id, "/", sheet, " (not measured)"))
        next
      }
    }
    failing <- scope[scope$status != "balanced", , drop = FALSE]
    if (nrow(failing)) unresolved <- c(
      unresolved,
      paste0(failing$source_id, "/", failing$source_sheet, " (", failing$status, ")")
    )
  }
  unique(unresolved)
}

create_reconciliation_views <- function(con) {
  # Exact-over-wildcard precedence. A source with both a '*' row and a row for
  # this worksheet has two matching statuses, and joining on "either" silently
  # doubles the worksheet -- the audit's point about joining status by exact
  # source, sheet and precedence rather than by whichever row matches first.
  create_project_view(con, "v_table_reconciliation", paste(
    "WITH ranked AS (",
    "  SELECT r.vintage_id, r.source_sheet, t.status, t.reviewed_by,",
    "         row_number() OVER (",
    "           PARTITION BY r.vintage_id, r.source_sheet",
    "           ORDER BY CASE WHEN t.source_sheet = '*' THEN 1 ELSE 0 END",
    "         ) AS precedence",
    "  FROM table_reconciliation r",
    "  JOIN table_status t ON t.source_id = r.source_id",
    "    AND (t.source_sheet = r.source_sheet OR t.source_sheet = '*')",
    ")",
    "SELECT r.*, k.status AS review_status, k.reviewed_by",
    "FROM table_reconciliation r",
    "LEFT JOIN ranked k ON k.vintage_id = r.vintage_id AND k.source_sheet = r.source_sheet",
    "  AND k.precedence = 1"
  ))
  # The raw layer in worksheet (A1) coordinates. report_cell_values is stored
  # cropped to each sheet's used range, so its row_id/column_id are not the
  # coordinates the parsers, the snapshot or a person reading the workbook use.
  # Anything joining the raw layer to an observation must go through this view or
  # repeat the offset itself; the first version of the reconciliation did neither
  # and produced 13,041 phantom unexplained cells.
  create_project_view(con, "v_report_cells_a1", paste(
    "SELECT v.vintage_id, v.release_id, v.source_id, v.source_sheet, v.sheet_version_id,",
    "c.row_id + coalesce(s.content_first_row, 1) - 1 AS row_id,",
    "c.column_id + coalesce(s.content_first_col, 1) - 1 AS column_id,",
    "c.row_id AS cropped_row_id, c.column_id AS cropped_column_id,",
    "c.raw_value_text, c.raw_value_num, c.raw_value_date",
    "FROM report_sheet_vintages v",
    "JOIN source_sheets s ON s.vintage_id = v.vintage_id AND s.sheet_name = v.source_sheet",
    "JOIN report_cell_values c ON c.sheet_version_id = v.sheet_version_id"
  ))
  # What a reviewer needs in order to write the next rule: the worksheet, the
  # coordinates as they appear in the workbook, and the value in the cell.
  create_project_view(con, "v_reconciliation_unclassified", paste(
    "SELECT c.vintage_id, c.source_id, c.source_sheet, c.row_id, c.column_id,",
    "       a.raw_value_num, a.raw_value_text",
    "FROM reconciliation_cell_classification c",
    "JOIN v_report_cells_a1 a",
    "  ON a.vintage_id = c.vintage_id AND a.source_sheet = c.source_sheet",
    " AND a.row_id = c.row_id AND a.column_id = c.column_id",
    "WHERE c.classification = 'unclassified'"
  ))
  invisible(TRUE)
}
