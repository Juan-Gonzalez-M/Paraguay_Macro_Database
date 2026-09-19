root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(root, "scripts", "load_project.R"))
load_project_scripts(root, profile = "pipeline", quiet = TRUE)

candidate <- file.path(
  root, "database", "candidates", "accepted_for_review_20260919_203133.duckdb"
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
      "e95ae6b0550347177c9fa57eda474990f6a7493bd5eac1c9a47f046a3b116616")
check("schema_version", "SELECT max(version)::INTEGER FROM schema_version", 49L)
check("imf_sources", paste(
  "SELECT count(DISTINCT source_id)::INTEGER FROM raw.source_files",
  "WHERE source_id LIKE 'imf_%'"
), 24L)
check("imts_sources", paste(
  "SELECT count(*)::INTEGER FROM raw.source_files WHERE source_id='imf_imts'"
), 0L)
check("imf_series_rows", "SELECT count(*)::INTEGER FROM staging.imf_series_snapshot", 22455L)
check("imf_numeric_observations", paste(
  "SELECT count(*)::INTEGER FROM staging.imf_observation_snapshot"
), 2558738L)
check("imf_numeric_identities", paste(
  "SELECT count(DISTINCT series_id)::INTEGER FROM staging.imf_observation_snapshot"
), 20042L)
check("imf_metadata_values", "SELECT count(*)::INTEGER FROM staging.imf_metadata_snapshot", 101095L)
check("imf_metadata_identities", paste(
  "SELECT count(DISTINCT series_id)::INTEGER FROM staging.imf_metadata_snapshot"
), 195L)
check("imf_dimension_rows", paste(
  "SELECT count(*)::INTEGER FROM canonical.series_dimension",
  "WHERE basis='published_imf_export'"
), 192910L)
check("imf_dimension_identities", paste(
  "SELECT count(DISTINCT series_id)::INTEGER FROM canonical.series_dimension",
  "WHERE basis='published_imf_export'"
), 22455L)
check("imf_dimension_names", paste(
  "SELECT count(DISTINCT dimension)::INTEGER FROM canonical.series_dimension",
  "WHERE basis='published_imf_export'"
), 43L)
check("imf_explore_observations", paste(
  "SELECT count(*)::INTEGER FROM explore.observations WHERE source_id LIKE 'imf_%'"
), 2558289L)
check("imf_research_rows", paste(
  "SELECT count(*)::INTEGER FROM research.series_catalog WHERE source_id LIKE 'imf_%'"
), 0L)
check("rsui_identities", paste(
  "SELECT count(*)::INTEGER FROM catalog.series WHERE source_id='imf_rsui'"
), 16L)
check("rsui_observations", paste(
  "SELECT count(*)::INTEGER FROM explore.observations WHERE source_id='imf_rsui'"
), 6992L)
check("wpfxi_identities", paste(
  "SELECT count(*)::INTEGER FROM catalog.series WHERE source_id='imf_wpfxi'"
), 186L)
check("wpfxi_observations", paste(
  "SELECT count(*)::INTEGER FROM explore.observations WHERE source_id='imf_wpfxi'"
), 34541L)
check("imf_error_flags", paste(
  "SELECT count(*)::INTEGER FROM audit.quality_flags",
  "WHERE attempt_id='attempt:a9e93ae220bdfebea12073a4' AND severity='error'"
), 0L)
check("imf_scoped_warning_flags", paste(
  "SELECT count(*)::INTEGER FROM audit.quality_flags",
  "WHERE attempt_id='attempt:a9e93ae220bdfebea12073a4'",
  "AND severity='warning' AND source_id LIKE 'imf_%'"
), 0L)

non_imf_forward <- paste(
  "SELECT f.* FROM canonical.fact_series_events f JOIN canonical.dim_series d USING(series_id)",
  "WHERE d.source_id NOT LIKE 'imf_%' EXCEPT SELECT * FROM prod.canonical.fact_series_events"
)
non_imf_reverse <- paste(
  "SELECT * FROM prod.canonical.fact_series_events EXCEPT",
  "SELECT f.* FROM canonical.fact_series_events f JOIN canonical.dim_series d USING(series_id)",
  "WHERE d.source_id NOT LIKE 'imf_%'"
)
check("candidate_minus_production_non_imf",
      paste0("SELECT count(*)::INTEGER FROM (", non_imf_forward, ")"), 0L)
check("production_minus_candidate_non_imf",
      paste0("SELECT count(*)::INTEGER FROM (", non_imf_reverse, ")"), 0L)
check("cda_identities", "SELECT count(*)::INTEGER FROM canonical.dim_series WHERE source_id='cda_curve'", 421L)
check("tcn_identities", paste(
  "SELECT count(*)::INTEGER FROM canonical.dim_series",
  "WHERE source_id='tcn_referential_daily'"
), 2L)
check("lrm_identities", "SELECT count(*)::INTEGER FROM canonical.dim_series WHERE source_id='lrm_auctions'", 940L)

identity <- DBI::dbGetQuery(con, paste(
  "SELECT d.data_release_id,d.source_bundle_id,d.build_id,d.attempt_id,d.status,",
  "d.error_count,d.warning_count,d.schema_version",
  "FROM audit.active_data_release a JOIN audit.data_releases d USING(data_release_id)"
))
print(identity)
cat("verification=PASS\n")
