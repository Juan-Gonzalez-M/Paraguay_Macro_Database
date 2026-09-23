suppressPackageStartupMessages({
  library(DBI)
  library(duckdb)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Uso: build_sample.R <directorio_salida>", call. = FALSE)
out_dir <- normalizePath(args[[1]], mustWork = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

script_arg <- commandArgs(trailingOnly = FALSE)
script_path <- sub("^--file=", "", script_arg[grepl("^--file=", script_arg)][1])
project_root <- normalizePath(file.path(dirname(script_path), "..", ".."))
db_path <- file.path(project_root, "database", "paraguay_macro_pilot.duckdb")
con <- dbConnect(duckdb(), db_path, read_only = TRUE)
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

extracts <- list(
  eeff = "SELECT * FROM research.entity_panel WHERE source_id = 'banks' ORDER BY reference_period, entity_id, item_id, source_currency_code, measure",
  carteras = "SELECT * FROM main.v_banks_carteras_documented ORDER BY fecha, entity_id, portfolio_item_id, codigo_moneda, source_row",
  ratios = "SELECT * FROM main.v_banks_ratios_documented ORDER BY fecha, entity_id, ratio_id, source_row",
  sector = "SELECT *, cartera_vigente + cartera_vencida AS credito_total, CASE WHEN cartera_vigente + cartera_vencida = 0 THEN NULL ELSE cartera_vencida / (cartera_vigente + cartera_vencida) END AS ratio_vencida FROM main.v_banks_credito_sector_documented ORDER BY fecha, entity_id, credit_sector_id, codigo_moneda, source_row",
  actividad = "SELECT *, cartera_vigente + cartera_vencida AS credito_total, CASE WHEN cartera_vigente + cartera_vencida = 0 THEN NULL ELSE cartera_vencida / (cartera_vigente + cartera_vencida) END AS ratio_vencida FROM main.v_banks_credito_actividad_documented ORDER BY fecha, entity_id, activity_id, codigo_moneda, source_row"
)

summary_rows <- list()
for (nm in names(extracts)) {
  x <- dbGetQuery(con, extracts[[nm]])
  utils::write.csv(x, file.path(out_dir, paste0(nm, ".csv")), row.names = FALSE, na = "")
  date_col <- intersect(c("reference_period", "fecha"), names(x))[[1]]
  entity_col <- intersect(c("entity_id", "codigo_entidad"), names(x))[[1]]
  summary_rows[[nm]] <- data.frame(
    extract = nm,
    rows = nrow(x),
    entities = length(unique(x[[entity_col]])),
    first_period = as.character(min(as.Date(x[[date_col]]), na.rm = TRUE)),
    last_period = as.character(max(as.Date(x[[date_col]]), na.rm = TRUE)),
    duplicate_source_rows = sum(duplicated(x[c("vintage_id", "source_sheet", "source_row")])),
    stringsAsFactors = FALSE
  )
}
summary <- do.call(rbind, summary_rows)
utils::write.csv(summary, file.path(out_dir, "sample_summary.csv"), row.names = FALSE, na = "")
print(summary, row.names = FALSE)

