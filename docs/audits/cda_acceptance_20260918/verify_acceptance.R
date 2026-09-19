file_arg <- commandArgs(trailingOnly = FALSE)[grep("^--file=", commandArgs(trailingOnly = FALSE))]
script_path <- sub("^--file=", "", file_arg[[1]])
root <- normalizePath(file.path(dirname(script_path), "..", "..", ".."), mustWork = TRUE)

source(file.path(root, "scripts", "load_project.R"))
load_project_scripts(root, "pipeline", quiet = TRUE)

library(DBI)
library(duckdb)

candidate <- file.path(root, "database", "candidates", "accepted_for_review_20260917_212826.duckdb")
production <- file.path(root, "database", "paraguay_macro_pilot.duckdb")
cda_vintage <- "cda_curve:8796a589fc2bd31317efdce7"
cda_sha <- "8796a589fc2bd31317efdce7865d4598473fdacd048cf04b676dc8f78e2b144c"
tcn_sha <- "74df666397a33b9c8cdfac10d7ffedd23acf7cbd5907ea21332e100fb939c0a4"
build_id <- "build:180fb40bb51fadff89f9509f"
attempt_id <- "attempt:a35046bd8c9f23aece17d28f"
bundle_id <- "release:b4fa3c04186b336a91e9be7b"
scope_id <- "schema46_cda_provisional_20260917"

check <- function(name, observed, expected) {
  if (!identical(as.character(observed), as.character(expected))) {
    stop(name, ": expected ", paste(expected, collapse = ","), "; observed ",
         paste(observed, collapse = ","), call. = FALSE)
  }
  cat(name, "=", paste(observed, collapse = ","), "\n", sep = "")
}

check("production_sha256", file_sha256(production),
      "eaba62ab6efbc3c81a59dd77493282d5a3f28290319ec487f0876eb3b318c553")
check("production_bytes", unname(file.info(production)$size), 476590080)
check("candidate_sha256", file_sha256(candidate),
      "11727959edd135bb211dd267dedd0d7c569dea3e473510ee72b6ef8cb1155876")
check("candidate_bytes", unname(file.info(candidate)$size), 468725760)
check("cda_current_sha256", file_sha256(file.path(root, "input", "current", "Curva_CDA.xlsx")), cda_sha)
check("cda_archive_sha256", file_sha256(file.path(root, "input_archive", "cda_curve", paste0(cda_sha, ".xlsx"))), cda_sha)

scope <- read_release_input_scope(root, scope_id)
check("scope_digest", release_input_scope_digest(scope),
      "7f94c1cc30fcf3b8eee15ae73a7ae2c426f7afd545ccc3c9bd8c8e896f19cf29")
check("scope_rows", nrow(scope), 24)
check("scope_admits", sum(scope$disposition == "admit"), 23)
check("scope_defers", sum(scope$disposition == "defer"), 1)
check("scope_cda", paste(scope$sha256[scope$source_id == "cda_curve"],
                         scope$disposition[scope$source_id == "cda_curve"], sep = ":"),
      paste(cda_sha, "admit", sep = ":"))
check("scope_tcn", paste(scope$sha256[scope$source_id == "tcn_referential_daily"],
                         scope$disposition[scope$source_id == "tcn_referential_daily"], sep = ":"),
      paste(tcn_sha, "defer", sep = ":"))

con <- dbConnect(duckdb(), candidate, read_only = TRUE)
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)
q <- function(sql) dbGetQuery(con, sql)

release <- q(paste0(
  "SELECT d.data_release_id,d.source_bundle_id,d.build_id,d.attempt_id,d.schema_version,d.status,",
  "d.error_count,d.warning_count,r.status attempt_status,r.source_count,",
  "a.data_release_id active_build,a.source_bundle_id active_bundle ",
  "FROM audit.data_releases d JOIN audit.ingestion_run_attempts r USING(attempt_id) ",
  "JOIN audit.active_data_release a ON a.data_release_id=d.data_release_id ",
  "WHERE d.build_id='", build_id, "'"
))
check("release_rows", nrow(release), 1)
check("release_identity", unlist(release[1, c("data_release_id", "source_bundle_id", "build_id", "attempt_id")]),
      c(build_id, bundle_id, build_id, attempt_id))
check("release_state", unlist(release[1, c("schema_version", "status", "error_count", "warning_count", "attempt_status", "source_count")]),
      c(46, "accepted", 0, 39, "completed_with_warnings", 23))

artifact <- q(paste0("SELECT artifact_path,size_bytes,schema_version,artifact_role FROM audit.distribution_artifacts WHERE build_id='", build_id, "'"))
check("artifact_rows", nrow(artifact), 1)
check("artifact_record", unlist(artifact[1, ]), c("candidates/accepted_for_review_20260917_212826.duckdb", 468725760, 46, "database"))
check("release_error_flags", q(paste0("SELECT count(*) n FROM audit.quality_flags WHERE attempt_id='", attempt_id, "' AND severity='error'"))$n, 0)

release_sources <- q(paste0(
  "SELECT rs.source_id,f.sha256 FROM audit.release_sources rs JOIN raw.source_files f USING(vintage_id) ",
  "WHERE rs.release_id='", bundle_id, "' ORDER BY rs.source_id"
))
admitted <- scope[scope$disposition == "admit", c("source_id", "sha256")]
admitted <- admitted[order(admitted$source_id), ]
check("candidate_release_sources", nrow(release_sources), 23)
check("candidate_scope_source_ids", release_sources$source_id, admitted$source_id)
check("candidate_scope_hashes", release_sources$sha256, admitted$sha256)
check("tcn_release_rows", sum(release_sources$source_id == "tcn_referential_daily"), 0)

check("candidate_facts", q("SELECT count(*) n FROM canonical.fact_series_events")$n, 1248919)
check("candidate_identities", q("SELECT count(*) n FROM canonical.dim_series")$n, 12313)
check("cda_facts", q("SELECT count(*) n FROM canonical.fact_series_events f JOIN canonical.dim_series d USING(series_id) WHERE d.source_id='cda_curve'")$n, 21854)
check("cda_identities", q("SELECT count(*) n FROM canonical.dim_series WHERE source_id='cda_curve'")$n, 471)
check("cda_natural_key_duplicates", q(paste0(
  "SELECT count(*) n FROM (SELECT f.series_id,f.period,f.vintage_id,count(*) n ",
  "FROM canonical.fact_series_events f JOIN canonical.dim_series d USING(series_id) ",
  "WHERE d.source_id='cda_curve' GROUP BY ALL HAVING count(*)>1)"
))$n, 0)

check("cda_identity_families", q(paste0(
  "SELECT count(*) n FROM canonical.dim_series WHERE source_id='cda_curve' AND ",
  "(identity_basis LIKE 'CDA_RATE_CURVE|monthly|%' OR identity_basis LIKE 'CDA_OPERATIONS_CURVE|monthly|%')"
))$n, 471)
check("cda_identity_contains_sheet", q("SELECT count(*) n FROM canonical.dim_series WHERE source_id='cda_curve' AND regexp_matches(identity_basis, '(CDA_(ML|ME)_[0-9]|OPERACIONES_VOLUMEN_(ML|ME)_[0-9])')")$n, 0)
check("cda_identity_contains_coordinate", q("SELECT count(*) n FROM canonical.dim_series WHERE source_id='cda_curve' AND regexp_matches(identity_basis, '![A-Z]+[0-9]+')")$n, 0)

curve <- q("SELECT count(*) facts,count(DISTINCT candidate_id) identities,min(unit_code) unit_code,max(unit_code) max_unit FROM explore.curve_observations WHERE source_id='cda_curve'")
check("cda_explore_curve", unlist(curve[1, c("identities", "facts")]), c(114, 7269))
check("cda_explore_units", unlist(curve[1, c("unit_code", "max_unit")]), c("COUNT", "COUNT"))

withheld <- q(paste0(
  "SELECT identity_stability,count(*) identities,sum(observation_count) facts,",
  "count(DISTINCT unit_code) unit_codes,min(unit_code) min_unit,max(unit_code) max_unit,",
  "min(scale_multiplier) min_scale,max(scale_multiplier) max_scale,count(currency) currencies,",
  "count(DISTINCT transformation) transformations ",
  "FROM catalog.series WHERE source_id='cda_curve' AND explore_admission_status='withheld' GROUP BY identity_stability ORDER BY identity_stability"
))
semantic <- withheld[withheld$identity_stability == "semantic", ]
positional <- withheld[withheld$identity_stability == "positional", ]
check("cda_withheld_semantic", unlist(semantic[1, c("identities", "facts")]), c(342, 14570))
check("cda_withheld_positional", unlist(positional[1, c("identities", "facts")]), c(15, 15))
check("cda_withheld_unit", unique(withheld$min_unit), "UNRESOLVED_SOURCE_UNITS")
check("cda_withheld_scale", unique(c(withheld$min_scale, withheld$max_scale)), 1)
check("cda_withheld_currency_assignments", sum(withheld$currencies), 0)
check("cda_withheld_transformations", unique(withheld$transformations), 1)
check("cda_withheld_transformation_value", q("SELECT DISTINCT transformation FROM catalog.series WHERE source_id='cda_curve' AND explore_admission_status='withheld'")$transformation, "not_reviewed")

research_objects <- c(
  "curves", "entity_panel", "events", "observations_latest_actual",
  "observations_latest_statement", "transactions"
)
research_cda <- 0
research_lrm <- 0
for (object in research_objects) {
  cols <- q(paste0("SELECT column_name FROM information_schema.columns WHERE table_schema='research' AND table_name='", object, "'"))$column_name
  if ("source_id" %in% cols) {
    research_cda <- research_cda + q(paste0("SELECT count(*) n FROM research.", object, " WHERE source_id='cda_curve'"))$n
    research_lrm <- research_lrm + q(paste0("SELECT count(*) n FROM research.", object, " WHERE source_id='lrm_auctions'"))$n
  }
}
check("cda_research_rows_all_interfaces", research_cda, 0)
check("lrm_research_rows_all_interfaces", research_lrm, 0)

rec <- q(paste0(
  "SELECT count(*) sheets,sum(numeric_source_cells) numeric_cells,sum(accepted_observations) accepted,",
  "sum(rejected_observations) rejected,sum(documented_exclusions) excluded,sum(balance_delta) delta,",
  "sum(accepted_cells) accepted_cells,sum(cell_reuse) reused,sum(unmapped_in_region) unmapped,",
  "sum(unclassified_cells) unclassified,sum(parser_defect_cells) defects ",
  "FROM audit.table_reconciliation WHERE source_id='cda_curve'"
))
check("cda_reconciliation", unlist(rec[1, ]), c(412, 21854, 21854, 0, 0, 0, 21854, 0, 0, 0, 0))
check("cda_nonempty_raw_cells", q("SELECT count(*) n FROM main.report_cells WHERE source_id='cda_curve'")$n, 49813)
check("cda_formula_cells", q(paste0(
  "SELECT count(*) n FROM raw.report_cell_formulas WHERE vintage_id='", cda_vintage, "'"
))$n, 263)

prov <- q("SELECT * FROM raw.source_provenance WHERE source_id='cda_curve'")
check("cda_provenance_rows", nrow(prov), 1)
check("cda_provenance_unresolved_official_fields", sum(!is.na(prov[1, c("official_release_date", "official_url", "release_identifier", "license")])), 0)
check("cda_provenance_quality", unlist(prov[1, c("retrieval_method", "availability_quality")]), c("archive_ingest_upper_bound", "inferred_upper_bound"))

dbExecute(con, paste0("ATTACH '", gsub("'", "''", production), "' AS prod (READ_ONLY)"))
fact_diff <- q(paste0(
  "SELECT (SELECT count(*) FROM (SELECT f.* FROM canonical.fact_series_events f JOIN canonical.dim_series d USING(series_id) WHERE d.source_id<>'cda_curve' EXCEPT ALL SELECT f.* FROM prod.canonical.fact_series_events f JOIN prod.canonical.dim_series d USING(series_id) WHERE d.source_id<>'cda_curve')) candidate_minus_prod,",
  "(SELECT count(*) FROM (SELECT f.* FROM prod.canonical.fact_series_events f JOIN prod.canonical.dim_series d USING(series_id) WHERE d.source_id<>'cda_curve' EXCEPT ALL SELECT f.* FROM canonical.fact_series_events f JOIN canonical.dim_series d USING(series_id) WHERE d.source_id<>'cda_curve')) prod_minus_candidate"
))
check("non_cda_fact_differences", unlist(fact_diff[1, ]), c(0, 0))
series_diff <- q(paste0(
  "SELECT (SELECT count(*) FROM (SELECT * FROM canonical.dim_series WHERE source_id<>'cda_curve' EXCEPT ALL SELECT * FROM prod.canonical.dim_series WHERE source_id<>'cda_curve')) candidate_minus_prod,",
  "(SELECT count(*) FROM (SELECT * FROM prod.canonical.dim_series WHERE source_id<>'cda_curve' EXCEPT ALL SELECT * FROM canonical.dim_series WHERE source_id<>'cda_curve')) prod_minus_candidate"
))
check("non_cda_identity_differences", unlist(series_diff[1, ]), c(0, 0))
check("lrm_candidate_facts", q("SELECT count(*) n FROM canonical.fact_series_events f JOIN canonical.dim_series d USING(series_id) WHERE d.source_id='lrm_auctions'")$n, 10334)
check("lrm_candidate_identities", q("SELECT count(*) n FROM canonical.dim_series WHERE source_id='lrm_auctions'")$n, 940)
check("lrm_production_facts", q("SELECT count(*) n FROM prod.canonical.fact_series_events f JOIN prod.canonical.dim_series d USING(series_id) WHERE d.source_id='lrm_auctions'")$n, 10334)
check("lrm_production_identities", q("SELECT count(*) n FROM prod.canonical.dim_series WHERE source_id='lrm_auctions'")$n, 940)
dbExecute(con, "DETACH prod")

contract <- read_public_view_contract(root)
views <- contract[contract$object_type == "view", ]
check("declared_public_views", nrow(views), 141)
for (i in seq_len(nrow(views))) {
  dbGetQuery(con, paste0("SELECT * FROM ", views$schema_name[[i]], ".", views$object_name[[i]], " LIMIT 0"))
}
cat("public_views_fresh_read_only=141\n")
cat("ACCEPTANCE_VERIFICATION=PASS\n")
