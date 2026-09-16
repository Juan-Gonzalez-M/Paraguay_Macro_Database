#!/usr/bin/env Rscript

options(warn = 1)
suppressPackageStartupMessages({
  library(DBI)
  library(duckdb)
})

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
release_dir <- file.path(root, "database", "releases", "schema43_scope_20260914_implementation")
evidence_dir <- file.path(release_dir, "evidence")
paths <- list(
  production = file.path(root, "database", "paraguay_macro_pilot.duckdb"),
  frozen = file.path(root, "database", "releases", "schema43_20260914_180157",
                     "schema41_base.duckdb"),
  accepted_lineage = "/private/tmp/schema43-lineage-final.JPitWw/paraguay_macro_schema43_candidate.duckdb",
  rejected = file.path(root, "database", "candidates", "blocked_20260914_180218.duckdb"),
  candidate = file.path(root, "database", "candidates",
                        "accepted_for_review_20260914_195427.duckdb")
)
stopifnot(all(file.exists(unlist(paths))))

sha256 <- function(path) digest::digest(file = path, algo = "sha256")
emit <- function(key, value) cat(key, "=", paste(value, collapse = ","), "\n", sep = "")
scalar <- function(con, sql) DBI::dbGetQuery(con, sql)[[1]][[1]]
sql_string <- function(con, value) as.character(DBI::dbQuoteString(con, value))

expected_sha <- c(
  production = "17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180",
  frozen = "17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180",
  accepted_lineage = "586f2e7af80d54316d45233f1532d03d6f6846d279316d194fa5dbc1d1c26dd8",
  rejected = "e31e444a4ca79cb18f9bc322391562d553a28b179c6cf10e3037b881cb61169b",
  candidate = "ef28b3e048c73a596731763fe2609247e096a02def1b2b5f4872f36c100aaae4"
)
observed_sha <- vapply(paths, sha256, character(1))
stopifnot(identical(unname(observed_sha), unname(expected_sha)))
for (name in names(paths)) {
  emit(paste0(name, "_path"), paths[[name]])
  emit(paste0(name, "_bytes"), unname(file.info(paths[[name]])$size))
  emit(paste0(name, "_sha256"), observed_sha[[name]])
}

attached <- DBI::dbConnect(duckdb::duckdb())
on.exit(DBI::dbDisconnect(attached, shutdown = TRUE), add = TRUE)
for (name in names(paths)) DBI::dbExecute(attached, paste0(
  "ATTACH ", sql_string(attached, paths[[name]]), " AS ", name, " (READ_ONLY)"
))

artifact_counts <- DBI::dbGetQuery(attached, paste(
  "SELECT 'frozen' artifact,",
  "(SELECT count(*) FROM frozen.canonical.fact_series_events) canonical_facts,",
  "(SELECT count(*) FROM frozen.canonical.dim_series) canonical_series",
  "UNION ALL SELECT 'production',",
  "(SELECT count(*) FROM production.canonical.fact_series_events),",
  "(SELECT count(*) FROM production.canonical.dim_series)",
  "UNION ALL SELECT 'accepted_lineage',",
  "(SELECT count(*) FROM accepted_lineage.canonical.fact_series_events),",
  "(SELECT count(*) FROM accepted_lineage.canonical.dim_series)",
  "UNION ALL SELECT 'rejected',",
  "(SELECT count(*) FROM rejected.canonical.fact_series_events),",
  "(SELECT count(*) FROM rejected.canonical.dim_series)",
  "UNION ALL SELECT 'candidate',",
  "(SELECT count(*) FROM candidate.canonical.fact_series_events),",
  "(SELECT count(*) FROM candidate.canonical.dim_series)"
))
utils::write.csv(artifact_counts, file.path(evidence_dir, "artifact_population_counts.csv"),
                 row.names = FALSE, na = "")
print(artifact_counts, row.names = FALSE)
expected_counts <- data.frame(
  artifact = c("frozen", "production", "accepted_lineage", "rejected", "candidate"),
  canonical_facts = c(1227082, 1227082, 1227082, 1255940, 1227082),
  canonical_series = c(13985, 13985, 13985, 14486, 13985)
)
stopifnot(identical(artifact_counts, expected_counts))

candidate_release <- DBI::dbGetQuery(attached, paste(
  "SELECT d.data_release_id,d.source_bundle_id,d.build_id,d.attempt_id,d.schema_version,",
  "d.status,d.error_count,d.warning_count,a.data_release_id active_data_release_id,",
  "a.source_bundle_id active_source_bundle_id",
  "FROM candidate.audit.data_releases d",
  "JOIN candidate.audit.active_data_release a ON a.data_release_id=d.data_release_id",
  "WHERE d.build_id='build:128e6bda14e9bd07c638a661'"
))
print(candidate_release, row.names = FALSE)
stopifnot(
  nrow(candidate_release) == 1L,
  candidate_release$source_bundle_id == "release:dcbccb827b93ee2362ab3c56",
  candidate_release$status == "accepted",
  candidate_release$error_count == 0L,
  candidate_release$schema_version == 43L,
  candidate_release$active_data_release_id == candidate_release$build_id,
  candidate_release$active_source_bundle_id == candidate_release$source_bundle_id
)
emit("candidate_build_id", candidate_release$build_id)
emit("candidate_source_bundle_id", candidate_release$source_bundle_id)
emit("candidate_attempt_id", candidate_release$attempt_id)
emit("candidate_decision", candidate_release$status)
emit("candidate_release_errors", candidate_release$error_count)
emit("candidate_release_warnings", candidate_release$warning_count)

source_manifest <- DBI::dbGetQuery(attached, paste(
  "SELECT rs.source_id,rs.vintage_id,f.source_file,f.source_uri,f.archive_uri,f.sha256,",
  "f.size_bytes,f.publication_date,f.publication_date_source,f.ingestion_status",
  "FROM candidate.audit.release_sources rs",
  "JOIN candidate.raw.source_files f USING(vintage_id)",
  "WHERE rs.release_id='release:dcbccb827b93ee2362ab3c56'",
  "ORDER BY rs.source_id"
))
source_manifest$release_scope_id <- "schema43_lineage_only_20260914"
source_manifest$release_scope_digest <-
  "7761380c0b4c73dc29759d00f30132574e15558e1ba689bfa50e267d88406dd8"
source_manifest$source_bundle_id <- "release:dcbccb827b93ee2362ab3c56"
utils::write.csv(source_manifest, file.path(release_dir, "source_input_manifest.csv"),
                 row.names = FALSE, na = "")
stopifnot(
  nrow(source_manifest) == 22L,
  !any(source_manifest$source_id %in% c("cda_curve", "tcn_referential_daily")),
  all(source_manifest$ingestion_status == "completed")
)
emit("candidate_admitted_source_count", nrow(source_manifest))

deferred <- DBI::dbGetQuery(attached, paste(
  "SELECT source_id,check_name,severity,detail FROM candidate.audit.quality_flags",
  "WHERE attempt_id='attempt:049eb8a54ce38961b51be4e9'",
  "AND check_name='release_input_deferred' ORDER BY source_id"
))
utils::write.csv(deferred, file.path(evidence_dir, "deferred_input_diagnostics.csv"),
                 row.names = FALSE, na = "")
stopifnot(
  nrow(deferred) == 2L,
  identical(deferred$source_id, c("cda_curve", "tcn_referential_daily")),
  all(deferred$severity == "warning"),
  grepl("8796a589fc2bd31317efdce7865d4598473fdacd048cf04b676dc8f78e2b144c",
        deferred$detail[[1]], fixed = TRUE),
  grepl("74df666397a33b9c8cdfac10d7ffedd23acf7cbd5907ea21332e100fb939c0a4",
        deferred$detail[[2]], fixed = TRUE)
)
emit("deferred_diagnostic_count", nrow(deferred))

candidate_counts_by_source <- DBI::dbGetQuery(attached, paste(
  "WITH sources AS (SELECT source_id FROM candidate.canonical.dataset_catalog),",
  "facts AS (SELECT d.source_id,count(*) facts FROM candidate.canonical.fact_series_events f",
  "JOIN candidate.canonical.dim_series d USING(series_id) GROUP BY 1),",
  "series AS (SELECT source_id,count(*) series FROM candidate.canonical.dim_series GROUP BY 1),",
  "staging AS (SELECT source_id,count(*) staging_rows FROM",
  "candidate.staging.documented_series_snapshot GROUP BY 1),",
  "raw_files AS (SELECT source_id,count(*) raw_source_files FROM candidate.raw.source_files GROUP BY 1),",
  "catalogue AS (SELECT source_id,count(*) catalog_series FROM candidate.catalog.series GROUP BY 1),",
  "explore AS (SELECT source_id,count(*) explore_observations FROM (",
  "SELECT source_id FROM candidate.explore.observations UNION ALL",
  "SELECT source_id FROM candidate.explore.events UNION ALL",
  "SELECT source_id FROM candidate.explore.panel_observations UNION ALL",
  "SELECT source_id FROM candidate.explore.curve_observations) x GROUP BY 1)",
  "SELECT s.source_id,coalesce(r.raw_source_files,0) raw_source_files,",
  "coalesce(t.staging_rows,0) staging_rows,coalesce(f.facts,0) canonical_facts,",
  "coalesce(d.series,0) canonical_series,coalesce(c.catalog_series,0) catalog_series,",
  "coalesce(e.explore_observations,0) explore_observations",
  "FROM sources s LEFT JOIN raw_files r USING(source_id) LEFT JOIN staging t USING(source_id)",
  "LEFT JOIN facts f USING(source_id) LEFT JOIN series d USING(source_id)",
  "LEFT JOIN catalogue c USING(source_id) LEFT JOIN explore e USING(source_id)",
  "ORDER BY s.source_id"
))
utils::write.csv(candidate_counts_by_source,
                 file.path(evidence_dir, "candidate_counts_by_source.csv"),
                 row.names = FALSE, na = "")
affected_counts <- candidate_counts_by_source[
  candidate_counts_by_source$source_id %in% c("cda_curve", "tcn_referential_daily"), ]
print(affected_counts, row.names = FALSE)
stopifnot(nrow(affected_counts) == 2L, all(affected_counts[-1] == 0))

dataset_discovery <- DBI::dbGetQuery(attached, paste(
  "SELECT source_id,candidate_series,current_series_observations,current_vintage_id,",
  "source_sha256,access_interface FROM candidate.catalog.datasets",
  "WHERE source_id IN ('cda_curve','tcn_referential_daily') ORDER BY source_id"
))
utils::write.csv(dataset_discovery, file.path(evidence_dir, "deferred_dataset_discovery.csv"),
                 row.names = FALSE, na = "")
print(dataset_discovery, row.names = FALSE)
stopifnot(
  nrow(dataset_discovery) == 2L,
  all(dataset_discovery$candidate_series == 0L),
  all(dataset_discovery$current_series_observations == 0L),
  all(is.na(dataset_discovery$current_vintage_id)),
  all(is.na(dataset_discovery$source_sha256))
)

research_deferred <- scalar(attached, paste(
  "SELECT count(*) FROM (",
  "SELECT source_id FROM candidate.research.entity_panel",
  "UNION ALL SELECT source_id FROM candidate.research.events",
  "UNION ALL SELECT source_id FROM candidate.research.observations_latest_actual",
  "UNION ALL SELECT source_id FROM candidate.research.observations_latest_statement",
  "UNION ALL SELECT f.source_id FROM candidate.research.curves r",
  "JOIN candidate.raw.source_files f USING(vintage_id)",
  "UNION ALL SELECT f.source_id FROM candidate.research.transactions r",
  "JOIN candidate.raw.source_files f USING(vintage_id)) x",
  "WHERE source_id IN ('cda_curve','tcn_referential_daily')"
))
emit("candidate_research_deferred_observations", research_deferred)
stopifnot(research_deferred == 0L)

release_errors <- scalar(attached, paste(
  "SELECT count(*) FROM candidate.audit.quality_flags",
  "WHERE attempt_id='attempt:049eb8a54ce38961b51be4e9' AND severity='error'"
))
provenance_errors <- scalar(attached, paste(
  "SELECT count(*) FROM candidate.audit.quality_flags",
  "WHERE attempt_id='attempt:049eb8a54ce38961b51be4e9'",
  "AND check_name='new_vintage_provenance_incomplete'"
))
emit("candidate_release_blocking_errors", release_errors)
emit("candidate_new_vintage_provenance_incomplete", provenance_errors)
stopifnot(release_errors == 0L, provenance_errors == 0L)

fact_duplicate_keys <- scalar(attached, paste(
  "SELECT count(*) FROM (SELECT series_id,period,vintage_id,count(*) n",
  "FROM candidate.canonical.fact_series_events GROUP BY 1,2,3 HAVING count(*)>1)"
))
source_cell_duplicate_keys <- scalar(attached, paste(
  "SELECT count(*) FROM (SELECT vintage_id,source_sheet,row_id,column_id,count(*) n",
  "FROM candidate.main.report_cells GROUP BY 1,2,3,4 HAVING count(*)>1)"
))
reconciliation <- DBI::dbGetQuery(attached, paste(
  "SELECT count(*) worksheets,coalesce(sum(balance_delta),0) balance_delta,",
  "coalesce(sum(unclassified_cells),0) unclassified_cells,",
  "coalesce(sum(parser_defect_cells),0) parser_defect_cells",
  "FROM candidate.audit.table_reconciliation"
))
print(reconciliation, row.names = FALSE)
emit("candidate_fact_duplicate_natural_keys", fact_duplicate_keys)
emit("candidate_source_cell_duplicate_natural_keys", source_cell_duplicate_keys)
stopifnot(
  fact_duplicate_keys == 0L, source_cell_duplicate_keys == 0L,
  reconciliation$balance_delta == 0L,
  reconciliation$unclassified_cells == 0L,
  reconciliation$parser_defect_cells == 0L
)

fact_candidate_only <- scalar(attached, paste(
  "SELECT count(*) FROM (SELECT * FROM candidate.canonical.fact_series_events",
  "EXCEPT ALL SELECT * FROM accepted_lineage.canonical.fact_series_events)"
))
fact_baseline_only <- scalar(attached, paste(
  "SELECT count(*) FROM (SELECT * FROM accepted_lineage.canonical.fact_series_events",
  "EXCEPT ALL SELECT * FROM candidate.canonical.fact_series_events)"
))
series_candidate_only <- scalar(attached, paste(
  "SELECT count(*) FROM (SELECT * FROM candidate.canonical.dim_series",
  "EXCEPT ALL SELECT * FROM accepted_lineage.canonical.dim_series)"
))
series_baseline_only <- scalar(attached, paste(
  "SELECT count(*) FROM (SELECT * FROM accepted_lineage.canonical.dim_series",
  "EXCEPT ALL SELECT * FROM candidate.canonical.dim_series)"
))
emit("candidate_only_canonical_facts_vs_accepted_lineage", fact_candidate_only)
emit("accepted_lineage_only_canonical_facts_vs_candidate", fact_baseline_only)
emit("candidate_only_canonical_series_vs_accepted_lineage", series_candidate_only)
emit("accepted_lineage_only_canonical_series_vs_candidate", series_baseline_only)
stopifnot(all(c(fact_candidate_only, fact_baseline_only,
                series_candidate_only, series_baseline_only) == 0L))

rejected_fact_delta <- scalar(attached, paste(
  "SELECT (SELECT count(*) FROM rejected.canonical.fact_series_events)-",
  "(SELECT count(*) FROM candidate.canonical.fact_series_events)"
))
rejected_series_delta <- scalar(attached, paste(
  "SELECT (SELECT count(*) FROM rejected.canonical.dim_series)-",
  "(SELECT count(*) FROM candidate.canonical.dim_series)"
))
emit("rejected_minus_candidate_canonical_facts", rejected_fact_delta)
emit("rejected_minus_candidate_canonical_series", rejected_series_delta)
stopifnot(rejected_fact_delta == 28858L, rejected_series_delta == 501L)

production_pointer <- DBI::dbGetQuery(attached, "SELECT * FROM production.audit.active_data_release")
rejected_decision <- DBI::dbGetQuery(attached, paste(
  "SELECT status,error_count FROM rejected.audit.data_releases",
  "WHERE build_id='build:43303bc15d28971e37dfd49f'"
))
stopifnot(
  nrow(production_pointer) == 1L,
  production_pointer$data_release_id == "build:57fe1ff64fb654508b2a8f0a",
  production_pointer$source_bundle_id == "release:748d41036c3a73638a1c2086",
  nrow(rejected_decision) == 1L,
  rejected_decision$status == "blocked",
  rejected_decision$error_count == 1L
)
emit("production_active_build", production_pointer$data_release_id)
emit("production_active_source_bundle", production_pointer$source_bundle_id)
emit("rejected_build_decision", rejected_decision$status)

DBI::dbDisconnect(attached, shutdown = TRUE)
attached <- NULL

# Bind every stored project view and every governed public macro from a fresh
# direct read-only default connection. No project helper and no search_path.
fresh <- DBI::dbConnect(duckdb::duckdb(), paths$candidate, read_only = TRUE)
on.exit(if (!is.null(fresh)) DBI::dbDisconnect(fresh, shutdown = TRUE), add = TRUE)
search_path <- scalar(fresh, "SELECT current_setting('search_path')")
views <- DBI::dbGetQuery(fresh, paste(
  "SELECT table_schema,table_name FROM information_schema.views",
  "WHERE table_schema IN ('main','raw','staging','canonical','audit','marts','catalog','explore','research')",
  "ORDER BY 1,2"
))
view_errors <- character()
for (i in seq_len(nrow(views))) {
  object <- paste(DBI::dbQuoteIdentifier(fresh, views$table_schema[[i]]),
                  DBI::dbQuoteIdentifier(fresh, views$table_name[[i]]), sep = ".")
  tryCatch(DBI::dbGetQuery(fresh, paste0("SELECT * FROM ", object, " LIMIT 0")),
           error = function(e) view_errors <<- c(view_errors, paste(object, conditionMessage(e))))
}
macro_queries <- c(
  "SELECT * FROM catalog.profile('missing') LIMIT 0",
  "SELECT * FROM explore.series('missing') LIMIT 0",
  "SELECT * FROM research.observations_as_of(TIMESTAMP '2026-09-01 00:00:00') LIMIT 0",
  "SELECT * FROM main.series_as_of_date(DATE '2026-09-01') LIMIT 0",
  "SELECT * FROM main.series_statement_as_of_date(DATE '2026-09-01') LIMIT 0",
  "SELECT main.resolve_series_id('missing') LIMIT 0",
  "SELECT * FROM main.resolve_series_ids('missing') LIMIT 0"
)
macro_errors <- character()
for (query in macro_queries) tryCatch(DBI::dbGetQuery(fresh, query),
  error = function(e) macro_errors <<- c(macro_errors, paste(query, conditionMessage(e))))
emit("fresh_default_search_path", search_path)
emit("fresh_views_bound", nrow(views))
emit("fresh_view_binding_errors", length(view_errors))
emit("fresh_public_macros_bound", length(macro_queries))
emit("fresh_public_macro_binding_errors", length(macro_errors))
if (length(view_errors)) cat(paste(view_errors, collapse = "\n"), "\n")
if (length(macro_errors)) cat(paste(macro_errors, collapse = "\n"), "\n")
stopifnot(identical(search_path, ""), !length(view_errors), !length(macro_errors))
DBI::dbDisconnect(fresh, shutdown = TRUE)
fresh <- NULL

deferred_files <- data.frame(
  source_id = c("cda_curve", "tcn_referential_daily"),
  sha256 = c(
    "8796a589fc2bd31317efdce7865d4598473fdacd048cf04b676dc8f78e2b144c",
    "74df666397a33b9c8cdfac10d7ffedd23acf7cbd5907ea21332e100fb939c0a4"
  ),
  current_path = file.path(root, "input", "current",
                           c("Curva_CDA.xlsx", "TCN_Referencial_Diario.xlsx")),
  archive_path = file.path(
    root, "input_archive", c("cda_curve", "tcn_referential_daily"),
    paste0(c(
      "8796a589fc2bd31317efdce7865d4598473fdacd048cf04b676dc8f78e2b144c",
      "74df666397a33b9c8cdfac10d7ffedd23acf7cbd5907ea21332e100fb939c0a4"
    ), ".xlsx")
  )
)
deferred_files$current_exists <- file.exists(deferred_files$current_path)
deferred_files$archive_exists <- file.exists(deferred_files$archive_path)
deferred_files$current_sha256 <- vapply(deferred_files$current_path, sha256, character(1))
deferred_files$archive_sha256 <- vapply(deferred_files$archive_path, sha256, character(1))
utils::write.csv(deferred_files, file.path(evidence_dir, "deferred_file_preservation.csv"),
                 row.names = FALSE, na = "")
stopifnot(
  all(deferred_files$current_exists), all(deferred_files$archive_exists),
  identical(deferred_files$current_sha256, deferred_files$sha256),
  identical(deferred_files$archive_sha256, deferred_files$sha256)
)
emit("deferred_current_files_preserved", sum(deferred_files$current_exists))
emit("deferred_archive_files_preserved", sum(deferred_files$archive_exists))
emit("verification_status", "PASS")
