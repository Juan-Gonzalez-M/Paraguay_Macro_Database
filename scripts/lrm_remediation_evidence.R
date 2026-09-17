root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(root, "scripts", "load_project.R"))
load_project_scripts(root, profile = "research_tools", quiet = TRUE)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Usage: Rscript scripts/lrm_remediation_evidence.R <candidate_db>")
candidate <- normalizePath(args[[1]], winslash = "/", mustWork = TRUE)
out <- file.path(root, "docs", "audits", "lrm_remediation_20260917")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
workbook <- file.path(root, "input", "current", "lrm_auctions", "Subasta de LRM_WEB.xlsx")
dimensions <- xlsx_sheet_dimensions(workbook)
formula_coordinates <- xlsx_formula_cell_coordinates(dimensions)

cell_rows <- list()
sheet_rows <- list()
for (i in seq_len(nrow(dimensions))) {
  sheet <- dimensions$sheet_name[[i]]
  raw <- read_dimensioned_sheet(workbook, dimensions[i, ])
  text <- documented_text_matrix(raw)
  parsed <- documented_parse_lrm_auction_sheet(raw, sheet)$observations
  header_row <- which(normalize_semantic_label(text[, 1]) == "fecha subasta")
  data_rows <- unique(parsed$source_row)
  grid <- expand.grid(source_row = seq_len(nrow(text)), source_column = seq_len(ncol(text)))
  grid$source_sheet <- sheet
  grid$cell_a1 <- paste0(openxlsx::int2col(grid$source_column), grid$source_row)
  grid$raw_value <- as.character(text[cbind(grid$source_row, grid$source_column)])
  grid$classification <- "blank"
  nonblank <- !documented_blank(grid$raw_value)
  grid$classification[nonblank] <- "intentionally_excluded_non_observational_content"
  grid$classification[grid$source_row %in% c(header_row - 1L, header_row)] <- "header"
  grid$classification[grid$source_row %in% data_rows & grid$source_column %in% 1:5] <- "identity_or_dimension"
  observed_key <- paste(parsed$source_row, parsed$source_column)
  grid$classification[paste(grid$source_row, grid$source_column) %in% observed_key] <- "parsed_observation"
  formulas <- formula_coordinates[formula_coordinates$sheet_name == sheet, , drop = FALSE]
  grid$formula_or_cached_formula <- paste(grid$source_row, grid$source_column) %in%
    paste(formulas$row_id, formulas$column_id)
  grid$parser_defect <- FALSE
  cell_rows[[i]] <- grid[, c(
    "source_sheet", "cell_a1", "source_row", "source_column", "raw_value",
    "classification", "formula_or_cached_formula", "parser_defect"
  )]
  sheet_rows[[i]] <- tibble::tibble(
    source_sheet = sheet,
    worksheet_year = as.integer(stringr::str_extract(sheet, "[0-9]{4}")),
    header_rows = paste(header_row - 1L, header_row, sep = ":"),
    merged_header_ranges = dimensions$merge_ranges[[i]],
    hidden_rows = dimensions$hidden_rows[[i]], hidden_columns = dimensions$hidden_columns[[i]],
    formula_cells = dimensions$formula_cells[[i]], data_rows = length(data_rows),
    parsed_observations = nrow(parsed), first_auction_date = min(parsed$period),
    last_auction_date = max(parsed$period), parser_mode = "lrm_auction_event"
  )
}
cells <- dplyr::bind_rows(cell_rows)
readr::write_csv(cells, file.path(out, "source_cell_reconciliation.csv"))
readr::write_csv(dplyr::bind_rows(sheet_rows), file.path(out, "worksheet_structure.csv"))
readr::write_csv(
  cells |> dplyr::count(.data$source_sheet, .data$classification,
                        .data$formula_or_cached_formula, name = "cells"),
  file.path(out, "source_cell_reconciliation_summary.csv")
)

con <- connect_project_database(candidate, read_only = FALSE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
DBI::dbExecute(con, paste0(
  "ATTACH ", sql_string(file.path(root, "database", "paraguay_macro_pilot.duckdb")),
  " AS production (READ_ONLY)"
))
ledger <- DBI::dbGetQuery(con, paste(
  "WITH old_counts AS (SELECT series_id,count(*) observations,min(period) first_period,max(period) last_period",
  " FROM production.canonical.fact_series_events WHERE NOT is_deleted GROUP BY 1),",
  "new_counts AS (SELECT series_id,count(*) observations,min(period) first_period,max(period) last_period",
  " FROM canonical.fact_series_events WHERE NOT is_deleted GROUP BY 1)",
  "SELECT m.old_series_id,o.label old_public_label,o.identity_basis old_dimensions,",
  "m.new_series_id,n.label new_public_label,n.identity_basis new_dimensions,",
  "CASE m.relationship WHEN 'merged' THEN 'many-to-one' WHEN 'split' THEN 'one-to-many'",
  " WHEN 'renamed' THEN 'one-to-one' WHEN 'dropped' THEN 'retired' ELSE m.relationship END mapping_cardinality,",
  "'LRM two-level-header and annual-sheet identity remediation' migration_reason,",
  "oc.observations observations_before,nc.observations observations_after,m.shared_observations,",
  "(m.shared_observations=oc.observations) values_and_dates_preserved,TRUE old_identity_structurally_ambiguous,",
  "CASE WHEN cs.explore_admission_status='eligible_native_grain' THEN 'explore.events' ELSE 'catalog.series' END replacement_public_access_path,",
  "'superseded; resolved through canonical.source_alias and main.resolve_series_id(s)' deprecation_treatment,",
  "m.match_method,m.evidence",
  "FROM canonical.series_id_migration m",
  "LEFT JOIN production.canonical.dim_series o ON o.series_id=m.old_series_id",
  "LEFT JOIN canonical.dim_series n ON n.series_id=m.new_series_id",
  "LEFT JOIN old_counts oc ON oc.series_id=m.old_series_id",
  "LEFT JOIN new_counts nc ON nc.series_id=m.new_series_id",
  "LEFT JOIN catalog.series cs ON cs.candidate_id=m.new_series_id",
  "WHERE m.from_release='schema_43' AND m.to_release='schema_44'",
  "AND m.source_id='lrm_auctions' ORDER BY m.old_series_id,m.new_series_id"
))
readr::write_csv(ledger, file.path(out, "lrm_identifier_migration.csv"))
DBI::dbExecute(con, "DETACH production")
