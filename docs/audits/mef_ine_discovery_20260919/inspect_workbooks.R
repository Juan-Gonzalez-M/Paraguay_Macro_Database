#!/usr/bin/env Rscript

# Read-only diagnostic inventory for the two unregistered MEF/INE workbooks.
# It does not load project code, register sources, archive inputs, or open DuckDB.

suppressPackageStartupMessages({
  library(openxlsx)
  library(xml2)
})

root <- normalizePath(file.path(dirname(commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))] |> sub("^--file=", "", x = _)), "..", "..", ".."), mustWork = TRUE)
out_dir <- file.path(root, "docs", "audits", "mef_ine_discovery_20260919")
files <- c(
  mef = file.path(root, "input", "current", "MEFP 2001 ADMINISTRACIÓN CENTRAL 2003-2026 serie mensual.xlsx"),
  ine = file.path(root, "input", "current", "Anexo_EPHC_2017-2026.xlsx")
)
stopifnot(all(file.exists(files)))

sha256 <- function(path) unname(tools::md5sum(path))
sha256_shell <- function(path) {
  out <- system2("shasum", c("-a", "256", shQuote(path)), stdout = TRUE)
  sub("[[:space:]].*$", "", out[[1]])
}

col_to_num <- function(x) {
  chars <- utf8ToInt(x)
  Reduce(function(a, b) a * 26L + b - 64L, chars, init = 0L)
}

cell_parts <- function(ref) {
  list(
    row = as.integer(sub("^[A-Z]+", "", ref)),
    col = col_to_num(sub("[0-9]+$", "", ref))
  )
}

safe_text <- function(x) {
  y <- as.character(x)
  y[is.na(y)] <- ""
  y
}

inventory <- list()
sheets_out <- list()
merges_out <- list()
hidden_rows_out <- list()
hidden_cols_out <- list()
formulas_out <- list()
cells_out <- list()
notes_out <- list()

for (source_key in names(files)) {
  path <- files[[source_key]]
  info <- file.info(path)
  tmp <- tempfile(paste0("xlsx_", source_key, "_"))
  dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE, force = TRUE), add = TRUE)
  utils::unzip(path, exdir = tmp)

  core_path <- file.path(tmp, "docProps", "core.xml")
  app_path <- file.path(tmp, "docProps", "app.xml")
  core <- if (file.exists(core_path)) read_xml(core_path) else NULL
  app <- if (file.exists(app_path)) read_xml(app_path) else NULL
  prop <- function(doc, xpath) if (is.null(doc)) "" else xml_text(xml_find_first(doc, xpath))

  inventory[[source_key]] <- data.frame(
    source_key = source_key,
    filename = basename(path),
    relative_path = sub(paste0("^", root, "/"), "", normalizePath(path)),
    bytes = unname(info$size),
    sha256 = sha256_shell(path),
    format = "Office Open XML workbook (.xlsx)",
    modified_at_filesystem = format(info$mtime, "%Y-%m-%dT%H:%M:%S%z"),
    creator = prop(core, "//*[local-name()='creator']"),
    last_modified_by = prop(core, "//*[local-name()='lastModifiedBy']"),
    created_property = prop(core, "//*[local-name()='created']"),
    modified_property = prop(core, "//*[local-name()='modified']"),
    application = prop(app, "//*[local-name()='Application']"),
    app_version = prop(app, "//*[local-name()='AppVersion']"),
    stringsAsFactors = FALSE
  )

  wb_xml <- read_xml(file.path(tmp, "xl", "workbook.xml"))
  rel_xml <- read_xml(file.path(tmp, "xl", "_rels", "workbook.xml.rels"))
  sheet_nodes <- xml_find_all(wb_xml, "//*[local-name()='sheets']/*[local-name()='sheet']")
  rel_nodes <- xml_find_all(rel_xml, "//*[local-name()='Relationship']")
  rel_map <- setNames(xml_attr(rel_nodes, "Target"), xml_attr(rel_nodes, "Id"))
  sheet_names <- xml_attr(sheet_nodes, "name")
  sheet_states <- xml_attr(sheet_nodes, "state")
  sheet_states[is.na(sheet_states)] <- "visible"
  sheet_targets <- rel_map[xml_attr(sheet_nodes, "id")]

  for (i in seq_along(sheet_names)) {
    sheet <- sheet_names[[i]]
    target <- sub("^/", "", sheet_targets[[i]])
    xml_path <- if (startsWith(target, "xl/")) file.path(tmp, target) else file.path(tmp, "xl", target)
    sx <- read_xml(xml_path)
    dim_ref <- xml_attr(xml_find_first(sx, "//*[local-name()='dimension']"), "ref")
    if (is.na(dim_ref)) dim_ref <- ""
    row_nodes <- xml_find_all(sx, "//*[local-name()='sheetData']/*[local-name()='row']")
    cell_nodes <- xml_find_all(sx, "//*[local-name()='sheetData']/*[local-name()='row']/*[local-name()='c']")
    merge_nodes <- xml_find_all(sx, "//*[local-name()='mergeCells']/*[local-name()='mergeCell']")
    formula_nodes <- xml_find_all(sx, "//*[local-name()='sheetData']/*[local-name()='row']/*[local-name()='c'][*[local-name()='f']]")
    hidden_rows <- row_nodes[xml_attr(row_nodes, "hidden") %in% c("1", "true")]
    col_nodes <- xml_find_all(sx, "//*[local-name()='cols']/*[local-name()='col']")
    hidden_cols <- col_nodes[xml_attr(col_nodes, "hidden") %in% c("1", "true")]

    dat <- tryCatch(
      read.xlsx(path, sheet = sheet, colNames = FALSE, skipEmptyRows = FALSE,
                skipEmptyCols = FALSE, check.names = FALSE, detectDates = FALSE),
      error = function(e) data.frame()
    )
    nr <- if (is.data.frame(dat)) nrow(dat) else 0L
    nc <- if (is.data.frame(dat)) ncol(dat) else 0L
    vals <- if (nr && nc) unlist(dat, use.names = FALSE) else character()
    texts <- safe_text(vals)
    nonempty <- texts != ""
    numeric_like <- suppressWarnings(!is.na(as.numeric(texts))) & nonempty
    special <- nonempty & !numeric_like & grepl("^(?:-|…|[.][.]|[.][.][.]|ND|N/D|NA|N/A|s/d|n/d|[*]+)$", trimws(texts), ignore.case = TRUE)

    sheets_out[[length(sheets_out) + 1L]] <- data.frame(
      source_key = source_key, sheet_index = i, sheet_name = sheet,
      sheet_state = sheet_states[[i]], declared_dimension = dim_ref,
      materialized_rows = nr, materialized_columns = nc,
      xml_rows = length(row_nodes), xml_cells = length(cell_nodes),
      nonempty_materialized_cells = sum(nonempty), numeric_like_cells = sum(numeric_like),
      special_token_cells = sum(special), formula_cells = length(formula_nodes),
      merged_ranges = length(merge_nodes), hidden_rows = length(hidden_rows),
      hidden_column_ranges = length(hidden_cols), stringsAsFactors = FALSE
    )

    if (length(merge_nodes)) merges_out[[length(merges_out) + 1L]] <- data.frame(
      source_key = source_key, sheet_name = sheet, range = xml_attr(merge_nodes, "ref"), stringsAsFactors = FALSE
    )
    if (length(hidden_rows)) hidden_rows_out[[length(hidden_rows_out) + 1L]] <- data.frame(
      source_key = source_key, sheet_name = sheet, row = as.integer(xml_attr(hidden_rows, "r")), stringsAsFactors = FALSE
    )
    if (length(hidden_cols)) hidden_cols_out[[length(hidden_cols_out) + 1L]] <- data.frame(
      source_key = source_key, sheet_name = sheet,
      min_col = as.integer(xml_attr(hidden_cols, "min")), max_col = as.integer(xml_attr(hidden_cols, "max")),
      stringsAsFactors = FALSE
    )
    if (length(formula_nodes)) formulas_out[[length(formulas_out) + 1L]] <- data.frame(
      source_key = source_key, sheet_name = sheet, cell = xml_attr(formula_nodes, "r"),
      formula = xml_text(xml_find_first(formula_nodes, "./*[local-name()='f']")),
      cached_value = xml_text(xml_find_first(formula_nodes, "./*[local-name()='v']")), stringsAsFactors = FALSE
    )

    if (nr && nc) {
      rr <- rep(seq_len(nr), times = nc)
      cc <- rep(seq_len(nc), each = nr)
      dim_start <- sub(":.*$", "", dim_ref)
      dim_parts <- cell_parts(dim_start)
      source_rr <- rr + dim_parts$row - 1L
      source_cc <- cc + dim_parts$col - 1L
      keep <- nonempty
      cell_df <- data.frame(
        source_key = source_key, sheet_name = sheet, row = source_rr[keep], column = source_cc[keep],
        coordinate = openxlsx::int2col(source_cc[keep]) |> paste0(source_rr[keep]),
        value = texts[keep], numeric_like = numeric_like[keep], special_token = special[keep],
        stringsAsFactors = FALSE
      )
      cells_out[[length(cells_out) + 1L]] <- cell_df
      note_keep <- grepl("^(Fuente:|Nota:|Notas:|Observaci|Aclaraci|[0-9]+/|[*]+)", trimws(cell_df$value), ignore.case = TRUE)
      if (any(note_keep)) notes_out[[length(notes_out) + 1L]] <- cell_df[note_keep, c("source_key", "sheet_name", "coordinate", "value")]
    }
  }
}

bind <- function(x, template = data.frame()) if (length(x)) do.call(rbind, x) else template
write.csv(bind(inventory), file.path(out_dir, "file_inventory.csv"), row.names = FALSE, na = "")
write.csv(bind(sheets_out), file.path(out_dir, "sheet_inventory.csv"), row.names = FALSE, na = "")
write.csv(bind(merges_out, data.frame(source_key=character(),sheet_name=character(),range=character())), file.path(out_dir, "merged_ranges.csv"), row.names = FALSE, na = "")
write.csv(bind(hidden_rows_out, data.frame(source_key=character(),sheet_name=character(),row=integer())), file.path(out_dir, "hidden_rows.csv"), row.names = FALSE, na = "")
write.csv(bind(hidden_cols_out, data.frame(source_key=character(),sheet_name=character(),min_col=integer(),max_col=integer())), file.path(out_dir, "hidden_columns.csv"), row.names = FALSE, na = "")
write.csv(bind(formulas_out, data.frame(source_key=character(),sheet_name=character(),cell=character(),formula=character(),cached_value=character())), file.path(out_dir, "formulas.csv"), row.names = FALSE, na = "")
write.csv(bind(cells_out), file.path(out_dir, "nonempty_cells.csv"), row.names = FALSE, na = "")
write.csv(bind(notes_out, data.frame(source_key=character(),sheet_name=character(),coordinate=character(),value=character())), file.path(out_dir, "notes_and_footnotes.csv"), row.names = FALSE, na = "")

cat("Wrote read-only workbook diagnostics to", out_dir, "\n")
