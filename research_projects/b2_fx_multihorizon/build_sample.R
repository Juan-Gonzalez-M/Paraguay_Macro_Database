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
package_dir <- dirname(normalizePath(script_path))
project_root <- normalizePath(file.path(package_dir, "..", ".."))
manifest <- utils::read.csv(file.path(package_dir, "series_manifest.csv"), stringsAsFactors = FALSE, na.strings = "")
selected <- manifest[manifest$status == "selected", , drop = FALSE]

con <- dbConnect(duckdb(), file.path(project_root, "database", "paraguay_macro_pilot.duckdb"), read_only = TRUE)
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

quoted <- paste(DBI::dbQuoteString(con, selected$series_id), collapse = ", ")
sql <- paste0(
  "SELECT series_id, source_id, source_sheet, series_label, period, frequency, unit, scale, currency, value, ",
  "CASE WHEN frequency IN ('monthly','monthly_survey') THEN date_trunc('month', period)::DATE ELSE period END AS period_start, ",
  "vintage_id, publication_date, source_file, source_row, source_column, identity_stability, hierarchy_status ",
  "FROM main.v_documented_series_latest_snapshot WHERE series_id IN (", quoted, ") ",
  "ORDER BY frequency, series_id, period"
)
long <- dbGetQuery(con, sql)

missing_ids <- setdiff(selected$series_id, unique(long$series_id))
if (length(missing_ids)) stop("Series seleccionadas sin observaciones: ", paste(missing_ids, collapse = ", "), call. = FALSE)
if (anyDuplicated(long[c("series_id", "period_start")])) stop("La muestra contiene más de una observación por serie y período normalizado.", call. = FALSE)

long <- merge(selected[c("role", "series_id", "interpretation", "limitation")], long, by = "series_id", all.y = TRUE, sort = FALSE)
long <- long[order(long$frequency, long$role, long$period_start), ]
utils::write.csv(long, file.path(out_dir, "b2_core_long.csv"), row.names = FALSE, na = "")
utils::write.csv(manifest, file.path(out_dir, "series_manifest_snapshot.csv"), row.names = FALSE, na = "")

summary <- aggregate(period_start ~ role + frequency, long, function(x) paste(min(x), max(x), sep = " / "))
counts <- aggregate(value ~ role + frequency, long, length)
names(counts)[names(counts) == "value"] <- "observations"
summary <- merge(summary, counts, by = c("role", "frequency"), all = TRUE)
utils::write.csv(summary, file.path(out_dir, "sample_summary.csv"), row.names = FALSE, na = "")
print(summary, row.names = FALSE)
