# Regression cover for the audit's P0 remediation round (schema 13):
# cross-release identity migration, the credit-survey question-header repair,
# source-to-target reconciliation, the evidence-bearing research gate and the
# enforced observation grain.

production_database <- function() {
  path <- file.path(project_test_root, "database", "paraguay_macro_pilot.duckdb")
  testthat::skip_if_not(file.exists(path), "production database not present")
  path
}

open_production <- function() {
  con <- connect_project_database(production_database(), read_only = TRUE)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE), envir = parent.frame())
  con
}

testthat::test_that("the four repaired parser families match their golden source-cell signatures", {
  # A digest over every (sheet, row, column, label, frequency, period, value)
  # tuple. Counts alone would not notice a value landing under the wrong cell or
  # a label drifting, which is precisely how these four defects presented.
  fixture_path <- file.path(project_test_root, "tests", "testthat", "fixtures",
                            "repaired_family_signatures.csv")
  testthat::skip_if_not(file.exists(fixture_path), "golden fixtures not present")
  expected <- readr::read_csv(fixture_path, col_types = readr::cols(.default = readr::col_character()))
  con <- open_production()
  predicates <- c(
    bcp_fx_daily = "source_id = 'bcp_fx_daily'",
    compensatory_fx_sales = "source_id = 'compensatory_fx_sales'",
    cuadro_61 = "source_id = 'economic_annex' AND source_sheet = 'CUADRO 61'",
    credit_survey = "source_id = 'credit_survey'"
  )
  for (family in expected$family) {
    observations <- DBI::dbGetQuery(con, paste0(
      "SELECT source_sheet, source_row, source_column, series_label, frequency, period, value ",
      "FROM documented_series_snapshot WHERE ", predicates[[family]],
      " ORDER BY source_sheet, source_row, source_column, period"
    ))
    signature <- digest::digest(paste(paste(
      observations$source_sheet, observations$source_row, observations$source_column,
      observations$series_label, observations$frequency, format(observations$period),
      format(observations$value, digits = 15), sep = "|"
    ), collapse = "\n"), algo = "sha256", serialize = FALSE)
    row <- expected[expected$family == family, ]
    testthat::expect_equal(nrow(observations), as.integer(row$observation_count), info = family)
    testthat::expect_equal(
      length(unique(observations$series_label)), as.integer(row$series_count), info = family
    )
    # One source cell, one observation. The compensatory FX defect was exactly
    # the failure of this equality.
    testthat::expect_equal(
      nrow(unique(observations[c("source_sheet", "source_row", "source_column")])),
      as.integer(row$distinct_source_cells), info = family
    )
    testthat::expect_equal(signature, row$signature_sha256, info = family)
  }
})

testthat::test_that("the observation grain is enforced by the schema, not merely satisfied", {
  con <- open_production()
  keys <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM duckdb_constraints()",
    "WHERE table_name = 'fact_series_events' AND constraint_type = 'PRIMARY KEY'"
  ))$n[[1]]
  testthat::expect_equal(keys, 1L)
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM (SELECT 1 FROM fact_series_events",
    "GROUP BY series_id, period, vintage_id HAVING count(*) > 1)"
  ))$n[[1]], 0L)
  # A deletion event carries no value by design, so the completeness rule is
  # expressed as a check rather than a NOT NULL column.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM fact_series_events",
    "WHERE series_id IS NULL OR period IS NULL OR vintage_id IS NULL",
    "OR is_deleted IS NULL OR (value IS NULL AND NOT is_deleted)"
  ))$n[[1]], 0L)
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM duckdb_constraints()",
    "WHERE table_name = 'fact_series_events' AND constraint_type = 'CHECK'"
  ))$n[[1]], 1L)
})

testthat::test_that("every identifier the project has published has a recorded outcome", {
  con <- open_production()
  testthat::expect_gt(DBI::dbGetQuery(con, "SELECT count(*) AS n FROM series_id_migration")$n[[1]], 0L)
  # The reproducibility contract: no identifier ever simply stops resolving.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM (",
    "  SELECT DISTINCT old_series_id FROM series_id_migration WHERE old_series_id IS NOT NULL",
    "  EXCEPT SELECT published_series_id FROM v_series_id_resolution)"
  ))$n[[1]], 0L)
  resolutions <- DBI::dbGetQuery(
    con, "SELECT DISTINCT resolution FROM v_series_id_resolution"
  )$resolution
  testthat::expect_setequal(resolutions, c("current", "prior_release_alias", "retired"))
  # The audit measured 1,571 of 28,417 prior identifiers surviving the
  # schema-12 repairs unchanged. The map has to reproduce that number, or it is
  # not describing the same pair of releases.
  hop <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM series_id_migration",
    "WHERE from_release = 'schema_11' AND to_release = 'schema_12' AND relationship = 'identical'"
  ))$n[[1]]
  testthat::expect_equal(hop, 1571L)
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(DISTINCT old_series_id) AS n FROM series_id_migration",
    "WHERE from_release = 'schema_11'"
  ))$n[[1]], 28417L)
  # Resolution must be transitive: a schema-11 EVE fragment has to land on the
  # consolidated series, not on the intermediate schema-12 identifier.
  eve <- DBI::dbGetQuery(con, paste(
    "SELECT current_series_id FROM v_series_id_resolution",
    "WHERE published_series_id = 'eve:bloque_de_inflacion_216:expectativa_del_mes'"
  ))
  testthat::expect_equal(nrow(eve), 1L)
  testthat::expect_equal(eve$current_series_id[[1]], "eve:bloque_de_inflacion:expectativa_del_mes")
})

testthat::test_that("no source cell feeds more than one observation", {
  con <- open_production()
  reconciliation <- DBI::dbGetQuery(con, "SELECT * FROM table_reconciliation")
  testthat::expect_gt(nrow(reconciliation), 0L)
  testthat::expect_true(all(reconciliation$status %in% RECONCILIATION_STATUS_VALUES))
  # Parser-region non-overlap, the audit's P0 test. Zero across every worksheet.
  testthat::expect_equal(sum(reconciliation$cell_reuse), 0L)
  testthat::expect_equal(
    reconciliation$accepted_observations, reconciliation$accepted_cells
  )
  # balance_delta is the residual nobody has accounted for at all, so it must be
  # zero on every worksheet: a cell matching no rule blocks the release.
  testthat::expect_equal(sum(reconciliation$balance_delta), 0L)
  testthat::expect_equal(sum(reconciliation$unclassified_cells), 0L)
  # Zero residual is not the same as balanced. A worksheet where a rule records
  # that the parser is not reading published data is fully accounted for and
  # still must not reach v_research_series, which is what defects_recorded says.
  testthat::expect_true(all(
    (reconciliation$status == "balanced") ==
      (reconciliation$unclassified_cells == 0L & reconciliation$parser_defect_cells == 0L &
         reconciliation$cell_reuse == 0L)
  ))
  testthat::expect_true(all(
    reconciliation$parser_defect_cells[reconciliation$status == "defects_recorded"] > 0L
  ))
})

testthat::test_that("the credit-survey question axis is fully semantic", {
  con <- open_production()
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM dim_series",
    "WHERE source_id = 'credit_survey' AND identity_stability <> 'semantic'"
  ))$n[[1]], 0L)
  # Two rows publishing the same question and response in the same quarter is
  # the signature of a mis-attributed block.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM (SELECT question, response FROM documented_series_snapshot",
    "WHERE source_id = 'credit_survey' AND source_sheet = '%'",
    "GROUP BY 1, 2 HAVING count(DISTINCT series_id) > 1)"
  ))$n[[1]], 0L)
  # 18,2 is published without a dash after the number; it must still be read as
  # a question rather than folded into 18,1.
  questions <- DBI::dbGetQuery(con, paste(
    "SELECT DISTINCT question FROM documented_series_snapshot",
    "WHERE source_id = 'credit_survey' AND question LIKE '18,%'"
  ))$question
  testthat::expect_equal(length(questions), 2L)
})

testthat::test_that("promotion to validated requires review evidence and a balanced worksheet", {
  gate_root <- tempfile("paraguay_macro_gate_")
  dir.create(gate_root)
  testthat::expect_true(file.copy(file.path(project_test_root, "config"), gate_root, recursive = TRUE))
  ensure_dirs(gate_root)
  con <- connect_project_database(file.path(gate_root, "database", "gate.duckdb"))
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  initialize_database(con)

  status_path <- file.path(gate_root, "config", "table_status.csv")
  status <- readr::read_csv(status_path, col_types = readr::cols(.default = readr::col_character()))
  target <- which(status$source_id == "economic_annex" & status$source_sheet == "*")[[1]]

  # A named reviewer alone must not be enough: the audit asks for definitions,
  # units, timing, hierarchy and methodology to be answered individually.
  status$status[target] <- "validated"
  status$reviewed_by[target] <- "A. Reviewer"
  status$reviewed_at[target] <- "2026-08-28"
  readr::write_csv(status, status_path, na = "")
  testthat::expect_error(apply_table_status(con, gate_root), "definitions_reviewed")

  for (field in TABLE_STATUS_EVIDENCE_COLUMNS) status[[field]][target] <- "checked"
  readr::write_csv(status, status_path, na = "")
  # With no reconciliation measured yet the gate cannot speak to the accounting,
  # so evidence alone is accepted.
  testthat::expect_silent(suppressMessages(apply_table_status(con, gate_root)))

  # Once a worksheet has been measured and does not balance, promoting it is
  # refused: an unexplained residual is an unproven correctness claim.
  DBI::dbExecute(con, paste(
    "INSERT INTO table_reconciliation (vintage_id, source_id, source_sheet, release_id,",
    "numeric_source_cells, accepted_observations, rejected_observations, documented_exclusions,",
    "many_to_one_allowance, balance_delta, status, note, checked_at, accepted_cells, cell_reuse,",
    "unmapped_in_region, out_of_region_cells) VALUES ('v', 'economic_annex', 'CUADRO 1', 'r',",
    "100, 90, 0, 0, 0, 10, 'unexplained_cells', 'test', current_timestamp, 90, 0, 10, 0)"
  ))
  testthat::expect_error(apply_table_status(con, gate_root), "reconciliation")
})

testthat::test_that("the reconciliation cell-rule register refuses unreviewed entries", {
  rule_root <- tempfile("paraguay_macro_rules_")
  dir.create(file.path(rule_root, "config"), recursive = TRUE)
  path <- file.path(rule_root, "config", "reconciliation_cell_rules.csv")
  rule <- tibble::tibble(
    source_id = "economic_annex", source_sheet = "CUADRO 1",
    row_from = "4", row_to = "4", column_from = "2", column_to = "9",
    classification = "header_or_label", expected_cells = "8",
    reason = "period-axis header numerals",
    evidence = "Row 4 carries the year axis 1990, 1991, 1992, 1993, 1994, 1995, 1996, 1997.",
    reviewed_by = "A. Reviewer", reviewed_at = "2026-08-28"
  )

  # Declaring that a source cell is not data is a review claim, so it carries the
  # same evidence burden as every other register in the project.
  readr::write_csv(dplyr::mutate(rule, reviewed_by = ""), path, na = "")
  testthat::expect_error(read_reconciliation_cell_rules(rule_root), "reviewed_by")
  readr::write_csv(dplyr::mutate(rule, evidence = ""), path, na = "")
  testthat::expect_error(read_reconciliation_cell_rules(rule_root), "evidence")
  readr::write_csv(dplyr::mutate(rule, reviewed_at = "28/08/2026"), path, na = "")
  testthat::expect_error(read_reconciliation_cell_rules(rule_root), "YYYY-MM-DD")
  readr::write_csv(dplyr::mutate(rule, classification = "probably_a_header"), path, na = "")
  testthat::expect_error(read_reconciliation_cell_rules(rule_root), "classification")

  # '*' is the unbounded end of a rectangle: "column 9, every row", which is what
  # a rule has to say when the next publication adds months.
  readr::write_csv(dplyr::mutate(rule, row_to = "*"), path, na = "")
  unbounded <- read_reconciliation_cell_rules(rule_root)
  testthat::expect_gt(unbounded$row_to, 1e6)

  # A layout signature is accepted, but only with evidence a reader can check
  # against the worksheet. "not data" is an assertion, not evidence.
  readr::write_csv(
    dplyr::mutate(rule, reviewed_by = RECONCILIATION_LAYOUT_REVIEWER, evidence = "not data"),
    path, na = ""
  )
  testthat::expect_error(read_reconciliation_cell_rules(rule_root), "quote what")
  readr::write_csv(
    dplyr::mutate(rule, reviewed_by = RECONCILIATION_LAYOUT_REVIEWER), path, na = ""
  )
  testthat::expect_equal(nrow(read_reconciliation_cell_rules(rule_root)), 1L)

  readr::write_csv(rule, path, na = "")
  accepted <- read_reconciliation_cell_rules(rule_root)
  testthat::expect_equal(nrow(accepted), 1L)
  testthat::expect_equal(accepted$row_from, 4)
  testthat::expect_equal(accepted$column_to, 9)
  testthat::expect_equal(accepted$expected_cells, 8L)
  testthat::expect_true(startsWith(accepted$rule_id, "rule:"))

  # Two rules covering the same rectangle would make the classification of a cell
  # depend on file order.
  readr::write_csv(dplyr::bind_rows(rule, rule), path, na = "")
  testthat::expect_error(read_reconciliation_cell_rules(rule_root), "same source, sheet")
})

testthat::test_that("the two storage layers are compared in one coordinate system", {
  con <- open_production()
  # report_cell_values is stored cropped to each sheet's used range; the parsers
  # record A1 coordinates. Joining them untranslated reported 13,041 phantom
  # unexplained cells -- most of the audit's headline 18,883 -- because on any
  # worksheet whose content does not start at A1 every coordinate is off by the
  # crop origin. v_report_cells_a1 is the only correct way to join the layers.
  offsets <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM source_sheets",
    "WHERE coalesce(content_first_row, 1) > 1 OR coalesce(content_first_col, 1) > 1"
  ))$n[[1]]
  testthat::expect_gt(offsets, 0L)
  translated <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM v_report_cells_a1 a",
    "JOIN source_sheets s ON s.vintage_id = a.vintage_id AND s.sheet_name = a.source_sheet",
    "WHERE a.row_id <> a.cropped_row_id + coalesce(s.content_first_row, 1) - 1",
    "   OR a.column_id <> a.cropped_column_id + coalesce(s.content_first_col, 1) - 1"
  ))$n[[1]]
  testthat::expect_equal(translated, 0L)
  # Every observation must sit on a source cell that actually holds its value.
  # This is the end-to-end statement the coordinate bug made unprovable.
  mismatched <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM documented_series_snapshot d",
    "JOIN v_report_cells_a1 a ON a.vintage_id = d.vintage_id",
    "  AND a.source_sheet = d.source_sheet AND a.row_id = d.source_row",
    "  AND a.column_id = d.source_column",
    "WHERE d.source_row IS NOT NULL AND a.raw_value_num IS NOT NULL",
    "  AND abs(a.raw_value_num - d.value) > 1e-9 * greatest(abs(d.value), 1)"
  ))$n[[1]]
  testthat::expect_equal(mismatched, 0L)
})

testthat::test_that("every in-region source cell is an observation or a classified non-observation", {
  con <- open_production()
  # The audit's central P0 test: unexplained_in_region must be zero. Every
  # remaining cell resolves to exactly one reviewed rule, and a rule that admits
  # the parser is not reading published data keeps its worksheet out of the
  # research marts rather than being quietly absorbed.
  testthat::expect_equal(DBI::dbGetQuery(
    con, "SELECT sum(unclassified_cells) AS n FROM table_reconciliation"
  )$n[[1]], 0)
  classified <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS total,",
    "count(*) FILTER (WHERE classification = 'unclassified') AS unclassified,",
    "count(*) FILTER (WHERE rule_id IS NULL) AS ruleless",
    "FROM reconciliation_cell_classification"
  ))
  testthat::expect_gt(classified$total[[1]], 0L)
  testthat::expect_equal(classified$unclassified[[1]], 0L)
  testthat::expect_equal(classified$ruleless[[1]], 0L)
  # One cell, one rule. A cell matching two rules would classify differently
  # depending on file order.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM (SELECT 1 FROM reconciliation_cell_classification",
    "GROUP BY vintage_id, source_sheet, row_id, column_id HAVING count(*) > 1)"
  ))$n[[1]], 0L)
  # A recorded defect is a real, named quantity of unread published data, and it
  # must block validation for its worksheet. Since schema 24 there are none left
  # in region -- SIPAP_12, the last one, is read -- so the mechanism is tested
  # against whatever the register currently holds and, when it holds nothing, the
  # stronger statement is asserted instead: no worksheet admits unread cells
  # inside the rectangle its parser consumed.
  defects <- DBI::dbGetQuery(con, paste(
    "SELECT source_id, source_sheet FROM table_reconciliation WHERE status = 'defects_recorded'"
  ))
  if (nrow(defects)) {
    testthat::expect_true(all(
      paste0(defects$source_id, "/", defects$source_sheet, " (defects_recorded)") %in%
        unreconciled_table_families(con, defects)
    ))
  } else {
    testthat::expect_equal(DBI::dbGetQuery(
      con, "SELECT sum(parser_defect_cells) AS n FROM table_reconciliation"
    )$n[[1]], 0)
  }
})

testthat::test_that("cells outside every parser region are classified, and the unexplained ones block promotion", {
  con <- open_production()
  # The audit's F-03. 'balanced' is a statement about the rectangle the parser
  # consumed and cannot speak for a cell the parser never went near, so the
  # accounting outside it is built from the raw layer independently of what the
  # parser emitted -- and over every documented worksheet, not only those that
  # produced an observation, because a worksheet the parser reads nothing from
  # has no region at all.
  totals <- DBI::dbGetQuery(con, paste(
    "SELECT classification, count(*) AS cells FROM source_region_classification GROUP BY 1"
  ))
  testthat::expect_gt(sum(totals$cells), 0L)
  testthat::expect_true(all(
    totals$classification %in% c(SOURCE_REGION_CLASSIFICATIONS, "unreviewed")
  ))
  # One cell, one rule.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM (SELECT 1 FROM source_region_classification",
    "GROUP BY vintage_id, source_sheet, row_id, column_id HAVING count(*) > 1)"
  ))$n[[1]], 0L)
  # The period axis is the bulk of it, and it is the one classification that can
  # be checked mechanically: every cell under it is a stored date or a year.
  testthat::expect_gt(totals$cells[totals$classification == "period_axis"], 10000L)
  # A worksheet carrying unreviewed or admittedly-unread cells outside its region
  # cannot be promoted, whatever its in-region reconciliation says.
  blocked <- DBI::dbGetQuery(con, paste(
    "SELECT DISTINCT source_id, source_sheet FROM source_region_classification",
    "WHERE classification IN ('unreviewed', 'data_not_ingested')"
  ))
  testthat::expect_gt(nrow(blocked), 0L)
  reasons <- unreconciled_table_families(con, blocked[1, , drop = FALSE])
  testthat::expect_true(any(grepl("outside every parser region", reasons, fixed = TRUE)))
  # No worksheet admits published data outside every parser region any more.
  # direct_investment Cuadro 5 and Cuadro 7 were the reviewed extreme -- 12,115
  # cells of a table nothing read -- and schema 27's two-header year-quarter
  # reading closed them, so the honest assertion is now the stronger one.
  unread <- DBI::dbGetQuery(con, paste(
    "SELECT source_id, source_sheet, count(*) AS cells FROM source_region_classification",
    "WHERE classification = 'data_not_ingested' GROUP BY 1, 2"
  ))
  testthat::expect_equal(nrow(unread), 0L)
})

testthat::test_that("published period labels parse in every spelling the sources use", {
  # Each of these cost real observations before it was recognised: footnote
  # markers on month labels (CUADRO 59, 480 cells), the abbreviation written with
  # a full stop (CUADRO 56a/56b), four-letter September (CUADRO 18/23/23a/26),
  # a space inside the separator (CUADRO 35) and text day-month-year labels
  # (bcp_fx_daily 2020, 108 cells).
  raw <- tibble::tibble(v = c(
    "Ene**", "Set*", "mar.-19", "dic.-19", "sept-25 *", "dic-25 (3/)", "dic- 19*",
    "30-nov.-20", "1-dic.-20"
  ))
  parsed <- documented_date_matrix(raw, matrix(raw$v, ncol = 1))
  testthat::expect_equal(documented_month_number(c("Ene**", "Set*")), c(1L, 9L))
  testthat::expect_equal(documented_month_footnote("Ene**"), "**")
  # A plain matrix drops the Date class, so the day counts are restored before
  # comparing.
  testthat::expect_equal(
    as.character(as.Date(parsed[3:9, 1], origin = "1970-01-01")),
    c("2019-03-31", "2019-12-31", "2025-09-30", "2025-12-31", "2019-12-31",
      "2020-11-30", "2020-12-01")
  )
  # Nothing that is not a period label may become one.
  testthat::expect_false(any(documented_date_axis_token(
    c("Promedio", "300", "-", "29", "Total", "1/")
  )))
})
