root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(root, "scripts", "load_project.R"))
load_project_scripts(root, profile = "pipeline", quiet = TRUE)

candidate <- file.path(
  root, "database", "candidates", "accepted_for_review_20260919_103853.duckdb"
)
production <- file.path(root, "database", "paraguay_macro_pilot.duckdb")
con <- connect_project_database(candidate, read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
DBI::dbExecute(con, paste0("ATTACH ", sql_string(production), " AS prod (READ_ONLY)"))
scalar <- function(sql) DBI::dbGetQuery(con, sql)[[1]][[1]]
check <- function(label, sql, expected) {
  actual <- scalar(sql)
  if (!identical(actual, expected)) stop(label, ": expected ", expected, ", got ", actual)
  cat(label, "=", actual, "\n")
}

check("candidate_sha256", paste0("SELECT '", file_sha256(candidate), "'"),
      "9cf802028b8693506f5f6ad9ab321f2ace93f314fbeffe0a5ac831cdad087ca4")
check("cda_identities", "SELECT count(*)::INTEGER FROM canonical.dim_series WHERE source_id='cda_curve'", 421L)
check("cda_facts", paste(
  "SELECT count(*)::INTEGER FROM canonical.fact_series_events f",
  "JOIN canonical.dim_series d USING(series_id)",
  "WHERE d.source_id='cda_curve' AND NOT f.is_deleted"
), 21839L)
check("cda_explore_facts", "SELECT count(*)::INTEGER FROM explore.curve_observations WHERE source_id='cda_curve'", 21839L)
check("cda_unlabeled_identities", paste(
  "SELECT count(*)::INTEGER FROM canonical.dim_series WHERE source_id='cda_curve'",
  "AND label ILIKE '%UNLABELED%'"
), 0L)

check("tcn_identities", "SELECT count(*)::INTEGER FROM canonical.dim_series WHERE source_id='tcn_referential_daily'", 2L)
check("tcn_facts", paste(
  "SELECT count(*)::INTEGER FROM canonical.fact_series_events f",
  "JOIN canonical.dim_series d USING(series_id)",
  "WHERE d.source_id='tcn_referential_daily' AND NOT f.is_deleted"
), 7004L)
check("tcn_explore_facts", "SELECT count(*)::INTEGER FROM explore.observations WHERE source_id='tcn_referential_daily'", 7004L)
check("tcn_unit_currency", paste(
  "SELECT count(*)::INTEGER FROM canonical.dim_series",
  "WHERE source_id='tcn_referential_daily' AND unit_code='PYG_PER_USD'",
  "AND currency='PYG/USD' AND scale_multiplier=1"
), 2L)
check("tcn_compra_facts", paste(
  "SELECT count(*)::INTEGER FROM canonical.fact_series_events f",
  "JOIN canonical.dim_series d USING(series_id)",
  "WHERE d.source_id='tcn_referential_daily' AND d.label='Compra' AND NOT f.is_deleted"
), 3502L)
check("tcn_venta_facts", paste(
  "SELECT count(*)::INTEGER FROM canonical.fact_series_events f",
  "JOIN canonical.dim_series d USING(series_id)",
  "WHERE d.source_id='tcn_referential_daily' AND d.label='Venta' AND NOT f.is_deleted"
), 3502L)
check("tcn_nd_raw_tokens", paste(
  "SELECT count(*)::INTEGER FROM main.v_report_cells_a1",
  "WHERE source_id='tcn_referential_daily' AND raw_value_text='ND'"
), 4156L)

for (source in c("cda_curve", "tcn_referential_daily")) for (column in c(
  "balance_delta", "cell_reuse", "unmapped_in_region", "unclassified_cells",
  "parser_defect_cells"
)) check(paste(source, column, sep = "_"), paste0(
  "SELECT sum(", column, ")::INTEGER FROM audit.table_reconciliation WHERE source_id='",
  source, "'"
), 0L)

non_target_forward <- paste(
  "SELECT f.* FROM canonical.fact_series_events f JOIN canonical.dim_series d USING(series_id)",
  "WHERE d.source_id NOT IN ('cda_curve','tcn_referential_daily') EXCEPT",
  "SELECT f.* FROM prod.canonical.fact_series_events f",
  "JOIN prod.canonical.dim_series d USING(series_id)",
  "WHERE d.source_id NOT IN ('cda_curve','tcn_referential_daily')"
)
non_target_reverse <- paste(
  "SELECT f.* FROM prod.canonical.fact_series_events f",
  "JOIN prod.canonical.dim_series d USING(series_id)",
  "WHERE d.source_id NOT IN ('cda_curve','tcn_referential_daily') EXCEPT",
  "SELECT f.* FROM canonical.fact_series_events f JOIN canonical.dim_series d USING(series_id)",
  "WHERE d.source_id NOT IN ('cda_curve','tcn_referential_daily')"
)
check("candidate_minus_production_non_targets",
      paste0("SELECT count(*)::INTEGER FROM (", non_target_forward, ")"), 0L)
check("production_minus_candidate_non_targets",
      paste0("SELECT count(*)::INTEGER FROM (", non_target_reverse, ")"), 0L)
check("lrm_identities", "SELECT count(*)::INTEGER FROM canonical.dim_series WHERE source_id='lrm_auctions'", 940L)
check("lrm_facts", paste(
  "SELECT count(*)::INTEGER FROM canonical.fact_series_events f",
  "JOIN canonical.dim_series d USING(series_id)",
  "WHERE d.source_id='lrm_auctions' AND NOT f.is_deleted"
), 10334L)
check("target_research_rows", paste(
  "SELECT count(*)::INTEGER FROM research.series_catalog",
  "WHERE source_id IN ('cda_curve','tcn_referential_daily')"
), 0L)

identity <- DBI::dbGetQuery(con, paste(
  "SELECT d.data_release_id,d.source_bundle_id,d.build_id,d.attempt_id,d.status,",
  "d.error_count,d.warning_count,d.schema_version",
  "FROM audit.active_data_release a JOIN audit.data_releases d USING(data_release_id)"
))
print(identity)
cat("verification=PASS\n")
