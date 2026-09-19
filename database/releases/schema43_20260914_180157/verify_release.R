#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(DBI)
  library(duckdb)
})

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
run_dir <- file.path(root, "database", "releases", "schema43_20260914_180157")
paths <- c(
  production = file.path(root, "database", "paraguay_macro_pilot.duckdb"),
  pre_fix = "/private/tmp/paraguay-exploratory-schema43.60oOOT/paraguay_macro_schema43.duckdb",
  reported = "/private/tmp/schema43-lineage-final.JPitWw/paraguay_macro_schema43_candidate.duckdb",
  blocked = file.path(root, "database", "candidates", "blocked_20260914_180218.duckdb")
)
stopifnot(all(file.exists(paths)))

con <- dbConnect(duckdb(), dbdir = ":memory:")
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)
for (nm in names(paths)) {
  dbExecute(con, paste("ATTACH", dbQuoteString(con, paths[[nm]]), "AS", nm, "(READ_ONLY)"))
}

q <- function(sql) dbGetQuery(con, sql)
scalar <- function(sql) q(sql)[[1]][[1]]
count_except <- function(left, right, columns = "*") {
  scalar(paste0(
    "SELECT count(*) FROM (SELECT ", columns, " FROM ", left,
    " EXCEPT ALL SELECT ", columns, " FROM ", right, ")"
  ))
}

out <- file.path(run_dir, "verification_results.txt")
sink(out, split = TRUE)
on.exit(sink(), add = TRUE)

cat("schema43 controlled-release verification\n")
cat("verified_at_utc=", format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC"), "\n", sep = "")
cat("git_commit=98370c2c26f8162401cf6e0e3eb3019ef7f687c1\n")
cat("production_path=", paths[["production"]], "\n", sep = "")
cat("reported_path=", paths[["reported"]], "\n", sep = "")
cat("pre_fix_path=", paths[["pre_fix"]], "\n", sep = "")
cat("blocked_path=", paths[["blocked"]], "\n\n", sep = "")

cat("[schema versions and active pointers]\n")
for (nm in names(paths)) {
  cat(nm, "\n")
  print(q(paste0("SELECT max(version) AS schema_version FROM ", nm, ".audit.schema_version")))
  print(q(paste0("SELECT * FROM ", nm, ".audit.active_data_release")))
}

cat("\n[reported candidate lineage]\n")
print(q("SELECT count(*) AS observations, count(DISTINCT candidate_id) AS candidates FROM reported.explore.observations"))
print(q(paste(
  "SELECT count(*) AS corrected_observations, count(DISTINCT candidate_id) AS corrected_candidates,",
  "count(*) FILTER (WHERE source_id='bcp_fx_daily') AS bcp_fx_daily_rows,",
  "count(*) FILTER (WHERE source_id='financial_indicators') AS financial_indicator_rows",
  "FROM reported.explore.observations",
  "WHERE worksheet_lineage_correction_reason IS NOT NULL"
)))
print(q(paste(
  "SELECT count(*) FILTER (WHERE o.source_sheet IS DISTINCT FROM d.source_sheet) AS sheet_disagreements,",
  "count(*) FILTER (WHERE o.table_title IS DISTINCT FROM d.table_title) AS title_disagreements,",
  "count(*) FILTER (WHERE o.value IS DISTINCT FROM d.value) AS value_disagreements,",
  "count(*) FILTER (WHERE o.source_row IS DISTINCT FROM d.source_row OR o.source_column IS DISTINCT FROM d.source_column) AS coordinate_disagreements",
  "FROM reported.explore.observations o",
  "JOIN reported.staging.documented_series_snapshot d",
  "ON d.vintage_id=o.vintage_id AND d.series_id=o.candidate_id AND d.period=o.source_period_date"
)))
print(q(paste(
  "SELECT count(*) AS missing_raw_cells,",
  "count(*) FILTER (WHERE abs(r.raw_value_num-o.value) > 1e-8*greatest(1,abs(o.value))) AS numeric_disagreements",
  "FROM reported.explore.observations o",
  "LEFT JOIN reported.main.v_report_cells_a1 r",
  "ON r.vintage_id=o.vintage_id AND r.source_id=o.source_id AND r.source_sheet=o.source_sheet",
  "AND r.row_id=o.source_row AND r.column_id=o.source_column",
  "WHERE o.worksheet_lineage_correction_reason IS NOT NULL",
  "AND (r.vintage_id IS NULL OR abs(r.raw_value_num-o.value) > 1e-8*greatest(1,abs(o.value)))"
)))
print(q(paste(
  "SELECT source_id, count(*) AS candidates, sum(worksheet_lineage_correction_rows) AS corrected_rows,",
  "min(source_sheet_count) AS min_sheets, max(source_sheet_count) AS max_sheets,",
  "string_agg(DISTINCT worksheet_lineage_status, ', ' ORDER BY worksheet_lineage_status) AS statuses",
  "FROM reported.catalog.series WHERE worksheet_lineage_correction_rows>0 GROUP BY 1 ORDER BY 1"
)))

cat("\n[reported candidate versus production]\n")
for (obj in c(
  "canonical.fact_series_events", "canonical.dim_series", "audit.table_status",
  "main.v_series_latest"
)) {
  cat(obj, " reported_only=", count_except(paste0("reported.", obj), paste0("production.", obj)),
      " production_only=", count_except(paste0("production.", obj), paste0("reported.", obj)), "\n", sep = "")
}

cat("\n[reported lineage fix versus pre-fix schema 43]\n")
research_views <- q(paste(
  "SELECT table_name FROM information_schema.tables",
  "WHERE table_catalog='reported' AND table_schema='research' AND table_type='VIEW' ORDER BY table_name"
))$table_name
for (obj in c(
  "canonical.fact_series_events", "canonical.dim_series", "audit.table_status",
  "main.v_series_latest"
)) {
  cat(obj, " reported_only=", count_except(paste0("reported.", obj), paste0("pre_fix.", obj)),
      " pre_fix_only=", count_except(paste0("pre_fix.", obj), paste0("reported.", obj)), "\n", sep = "")
}
shared_non_lineage <- function(schema_name, table_name, excluded) {
  left <- q(paste0(
    "SELECT column_name FROM information_schema.columns WHERE table_catalog='reported' AND table_schema=",
    dbQuoteString(con, schema_name), " AND table_name=", dbQuoteString(con, table_name),
    " ORDER BY ordinal_position"
  ))$column_name
  right <- q(paste0(
    "SELECT column_name FROM information_schema.columns WHERE table_catalog='pre_fix' AND table_schema=",
    dbQuoteString(con, schema_name), " AND table_name=", dbQuoteString(con, table_name),
    " ORDER BY ordinal_position"
  ))$column_name
  setdiff(intersect(left, right), excluded)
}
for (spec in list(c("explore", "observations"), c("catalog", "series"))) {
  cols <- shared_non_lineage(spec[[1]], spec[[2]], c(
    "source_sheet", "table_title", "source_sheets", "source_sheet_count",
    "table_titles", "table_title_count", "coordinate_lineage_status",
    "worksheet_lineage_status", "worksheet_lineage_correction_reason",
    "worksheet_lineage_correction_rows", "title_record_source_sheet",
    "title_record_table_title", "missing_lineage_rows", "invalid_lineage_rows",
    "ambiguous_lineage_rows"
  ))
  columns <- paste(vapply(cols, function(x) as.character(dbQuoteIdentifier(con, x)), character(1)), collapse = ",")
  left <- paste0("reported.", spec[[1]], ".", spec[[2]])
  right <- paste0("pre_fix.", spec[[1]], ".", spec[[2]])
  cat(spec[[1]], ".", spec[[2]], " shared_non_lineage_reported_only=",
      count_except(left, right, columns), " pre_fix_only=", count_except(right, left, columns), "\n", sep = "")
}
for (view in research_views) {
  cols <- shared_non_lineage("research", view, if (view == "dataset_catalog") "updated_at" else character())
  columns <- paste(vapply(cols, function(x) as.character(dbQuoteIdentifier(con, x)), character(1)), collapse = ",")
  left <- paste0("reported.research.", view)
  right <- paste0("pre_fix.research.", view)
  cat("research.", view, " reported_only=", count_except(left, right, columns),
      " pre_fix_only=", count_except(right, left, columns), "\n", sep = "")
}

for (view in research_views) {
  left <- paste0("reported.research.", view)
  right <- paste0("production.research.", view)
  reported_cols <- q(paste0(
    "SELECT column_name FROM information_schema.columns WHERE table_catalog='reported' AND table_schema='research' ",
    "AND table_name=", dbQuoteString(con, view), " ORDER BY ordinal_position"
  ))$column_name
  production_cols <- q(paste0(
    "SELECT column_name FROM information_schema.columns WHERE table_catalog='production' AND table_schema='research' ",
    "AND table_name=", dbQuoteString(con, view), " ORDER BY ordinal_position"
  ))$column_name
  common <- intersect(reported_cols, production_cols)
  if (view == "dataset_catalog") common <- setdiff(common, "updated_at")
  columns <- paste(vapply(common, function(x) as.character(dbQuoteIdentifier(con, x)), character(1)), collapse = ",")
  cat("research.", view,
      " added_columns=", paste(setdiff(reported_cols, production_cols), collapse = "|"),
      " removed_columns=", paste(setdiff(production_cols, reported_cols), collapse = "|"),
      " reported_only=", count_except(left, right, columns),
      " production_only=", count_except(right, left, columns), "\n", sep = "")
}

cat("\n[reported catalogue and exploratory integrity]\n")
print(q(paste(
  "SELECT (SELECT count(*) FROM reported.catalog.series) AS catalogue_rows,",
  "(SELECT count(DISTINCT candidate_id) FROM reported.catalog.series) AS catalogue_ids,",
  "(SELECT count(*) FROM reported.catalog.series c LEFT JOIN reported.canonical.dim_series d ON d.series_id=c.candidate_id WHERE d.series_id IS NULL) AS orphan_profiles"
)))
for (obj in c("observations", "events", "panel_observations", "curve_observations")) {
  print(q(paste0(
    "SELECT ", dbQuoteString(con, obj), " AS interface, count(*) AS rows, ",
    "count(DISTINCT candidate_id) AS candidates, ",
    "count(*)-count(DISTINCT(candidate_id,reference_period_start)) AS duplicate_keys, ",
    "count(*) FILTER (WHERE value IS NULL OR NOT isfinite(value) OR reference_period_start IS NULL ",
    "OR reference_period_end IS NULL OR reference_period_end<reference_period_start ",
    "OR observation_status IS DISTINCT FROM 'observed') AS bad_rows, ",
    "count(*) FILTER (WHERE c.candidate_id IS NULL) AS orphan_rows ",
    "FROM reported.explore.", obj, " o LEFT JOIN reported.catalog.series c USING(candidate_id)"
  )))
}

cat("\n[blocked official build decision and population drift]\n")
print(q(paste(
  "SELECT data_release_id,source_bundle_id,build_id,schema_version,status,error_count,warning_count,decided_at",
  "FROM blocked.audit.data_releases WHERE data_release_id='build:43303bc15d28971e37dfd49f'"
)))
print(q(paste(
  "SELECT check_name,detail,attempt_id FROM blocked.audit.quality_flags",
  "WHERE attempt_id='attempt:f3811e32fe3f4f71a7921548' AND severity='error'"
)))
print(q(paste(
  "SELECT source_id,vintage_id FROM blocked.audit.release_sources",
  "WHERE release_id='release:549669d609b3dc600b81b9bf'",
  "EXCEPT SELECT source_id,vintage_id FROM production.audit.release_sources",
  "WHERE release_id='release:748d41036c3a73638a1c2086' ORDER BY source_id"
)))
for (obj in c("canonical.fact_series_events", "canonical.dim_series", "main.v_series_latest")) {
  cat(obj, " blocked_only=", count_except(paste0("blocked.", obj), paste0("production.", obj)),
      " production_only=", count_except(paste0("production.", obj), paste0("blocked.", obj)), "\n", sep = "")
}

cat("\n[production state after blocked run]\n")
print(q("SELECT max(version) AS schema_version FROM production.audit.schema_version"))
print(q("SELECT * FROM production.audit.active_data_release"))

source_manifest <- q(paste(
  "SELECT r.source_id,r.vintage_id,s.source_file,s.source_path,s.archive_path,s.sha256,",
  "s.size_bytes,s.publication_date,s.publication_date_source,s.ingestion_status",
  "FROM blocked.audit.release_sources r JOIN blocked.raw.source_files s USING(vintage_id)",
  "WHERE r.release_id='release:549669d609b3dc600b81b9bf' ORDER BY r.source_id"
))
write.csv(
  source_manifest, file.path(run_dir, "source_input_manifest.csv"),
  row.names = FALSE, na = ""
)
build_identity <- q(paste(
  "SELECT * FROM blocked.audit.build_identity",
  "WHERE build_id='build:43303bc15d28971e37dfd49f'"
))
build_environment <- q(paste(
  "SELECT package,version,built_under,is_direct,library_path,recorded_at",
  "FROM blocked.audit.build_environment",
  "WHERE build_id='build:43303bc15d28971e37dfd49f' ORDER BY package"
))
decision <- q(paste(
  "SELECT * FROM blocked.audit.data_releases",
  "WHERE data_release_id='build:43303bc15d28971e37dfd49f'"
))
reconciliation <- q(paste(
  "SELECT status,count(*) AS worksheets,sum(balance_delta) AS balance_delta,",
  "sum(unclassified_cells) AS unclassified_cells,sum(parser_defect_cells) AS parser_defect_cells",
  "FROM blocked.audit.table_reconciliation GROUP BY status ORDER BY status"
))
manifest <- list(
  manifest_version = 1L,
  release_run = "schema43_20260914_180157",
  decision = "rejected",
  blocker = "new_vintage_provenance_incomplete",
  generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC"),
  git = list(
    commit = "98370c2c26f8162401cf6e0e3eb3019ef7f687c1",
    pre_release_tracked_changes = character(),
    branch = "empirical-readiness-schema-39"
  ),
  artifacts = list(
    production = list(
      path = paths[["production"]], schema_version = 41L,
      sha256_before = "17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180",
      sha256_after = "17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180"
    ),
    reported_candidate = list(
      path = paths[["reported"]], schema_version = 43L,
      sha256 = "586f2e7af80d54316d45233f1532d03d6f6846d279316d194fa5dbc1d1c26dd8"
    ),
    pre_fix_candidate = list(
      path = paths[["pre_fix"]], schema_version = 43L,
      sha256 = "23d8feacf1492fc2847d05c5e5f55342f97265f525342a1a76696a7c1af0a015"
    ),
    blocked_official_build = list(
      path = paths[["blocked"]], schema_version = 43L,
      sha256 = "e31e444a4ca79cb18f9bc322391562d553a28b179c6cf10e3037b881cb61169b"
    )
  ),
  build_identity = if (nrow(build_identity)) as.list(build_identity[1, , drop = FALSE]) else NULL,
  decision_record = if (nrow(decision)) as.list(decision[1, , drop = FALSE]) else NULL,
  environment = build_environment,
  sources = source_manifest,
  validation = list(
    error_count = 1L, warning_count = 40L,
    error_check = "new_vintage_provenance_incomplete",
    error_detail = "2 non-legacy vintage(s) lack mandatory acquisition metadata.",
    reconciliation = reconciliation,
    full_regression_suite_run = FALSE,
    full_regression_suite_reason = "Stopped after the official isolated build failed a release gate."
  )
)
jsonlite::write_json(
  manifest, file.path(run_dir, "blocked_release_manifest.json"),
  auto_unbox = TRUE, pretty = TRUE, na = "null", digits = NA
)

cat("\nverification_complete=true\n")
