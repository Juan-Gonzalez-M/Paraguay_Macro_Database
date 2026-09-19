root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(root, "scripts", "load_project.R"))
load_project_scripts(root, profile = "pipeline", quiet = TRUE)

candidate <- file.path(
  root, "database", "candidates", "accepted_for_review_20260919_094613.duckdb"
)
production <- file.path(root, "database", "paraguay_macro_pilot.duckdb")
con <- connect_project_database(candidate, read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
DBI::dbExecute(con, paste0("ATTACH ", sql_string(production), " AS prod (READ_ONLY)"))

scalar <- function(sql) DBI::dbGetQuery(con, sql)[[1]][[1]]
assert_equal <- function(actual, expected, label) {
  if (!identical(actual, expected)) stop(
    label, ": expected ", expected, ", got ", actual, call. = FALSE
  )
  cat(label, "=", actual, "\n")
}

assert_equal(file_sha256(candidate),
             "49c79f20a43db6194667dfafec2f12923b50a015470e811ebc129ce3e29ae1bb",
             "candidate_sha256")
assert_equal(scalar("SELECT count(*)::INTEGER FROM canonical.dim_series WHERE source_id='cda_curve'"),
             456L, "cda_identities")
assert_equal(scalar(paste(
  "SELECT count(*)::INTEGER FROM canonical.fact_series_events f",
  "JOIN canonical.dim_series d USING(series_id)",
  "WHERE d.source_id='cda_curve' AND NOT f.is_deleted"
)), 21839L, "cda_facts")
assert_equal(scalar(paste(
  "SELECT count(*)::INTEGER FROM catalog.series",
  "WHERE source_id='cda_curve' AND identity_stability='semantic'",
  "AND explore_admission_status='eligible_native_grain'"
)), 421L, "cda_explore_identities")
assert_equal(scalar("SELECT count(*)::INTEGER FROM explore.curve_observations WHERE source_id='cda_curve'"),
             21804L, "cda_explore_facts")
assert_equal(scalar(paste(
  "SELECT count(*)::INTEGER FROM catalog.series",
  "WHERE source_id='cda_curve' AND identity_stability='positional'",
  "AND explore_admission_status='withheld'",
  "AND explore_exclusion_reason='published_institution_heading_missing'"
)), 35L, "cda_withheld_positional_identities")
assert_equal(scalar(paste(
  "SELECT sum(observation_count)::INTEGER FROM catalog.series",
  "WHERE source_id='cda_curve' AND identity_stability='positional'",
  "AND explore_admission_status='withheld'"
)), 35L, "cda_withheld_positional_facts")

assert_equal(scalar(paste(
  "SELECT count(*)::INTEGER FROM canonical.dim_series WHERE source_id='cda_curve'",
  "AND unit_code='PERCENT_PER_ANNUM' AND nominal_real='nominal'"
)), 228L, "cda_rate_identities")
assert_equal(scalar(paste(
  "SELECT count(*)::INTEGER FROM canonical.dim_series WHERE source_id='cda_curve'",
  "AND unit_code='COUNT'"
)), 114L, "cda_count_identities")
assert_equal(scalar(paste(
  "SELECT count(*)::INTEGER FROM canonical.dim_series WHERE source_id='cda_curve'",
  "AND unit_code IN ('PYG','USD') AND scale_multiplier=1"
)), 114L, "cda_volume_identities")
assert_equal(scalar(paste(
  "SELECT count(*)::INTEGER FROM canonical.dim_series WHERE source_id='cda_curve'",
  "AND ((currency='PYG' AND full_series_path ILIKE '%MONEDA LOCAL%')",
  "OR (currency='USD' AND full_series_path ILIKE '%MONEDA EXTRANJERA%'))"
)), 456L, "cda_currency_origin_matches")

assert_equal(scalar(paste(
  "SELECT sum(numeric_source_cells)::INTEGER FROM audit.table_reconciliation",
  "WHERE source_id='cda_curve'"
)), 21854L, "cda_numeric_source_cells")
assert_equal(scalar(paste(
  "SELECT sum(accepted_observations)::INTEGER FROM audit.table_reconciliation",
  "WHERE source_id='cda_curve'"
)), 21839L, "cda_accepted_observations")
assert_equal(scalar(paste(
  "SELECT sum(out_of_region_cells)::INTEGER FROM audit.table_reconciliation",
  "WHERE source_id='cda_curve'"
)), 15L, "cda_governed_exclusions")
for (column in c("balance_delta", "cell_reuse", "unmapped_in_region",
                 "unclassified_cells", "parser_defect_cells")) {
  assert_equal(scalar(paste0(
    "SELECT sum(", column, ")::INTEGER FROM audit.table_reconciliation ",
    "WHERE source_id='cda_curve'"
  )), 0L, paste0("cda_", column))
}

assert_equal(scalar(paste(
  "SELECT count(*)::INTEGER FROM canonical.series_id_migration",
  "WHERE from_release='build:180fb40bb51fadff89f9509f'",
  "AND to_release='build:33e0b5ab5e893910793a7b8e'",
  "AND source_id='cda_curve' AND relationship='dropped'"
)), 15L, "cda_retired_identifiers")
assert_equal(scalar(paste(
  "SELECT count(*)::INTEGER FROM canonical.series_id_migration",
  "WHERE from_release='build:180fb40bb51fadff89f9509f'",
  "AND to_release='build:33e0b5ab5e893910793a7b8e'",
  "AND source_id='cda_curve' AND relationship='identical'"
)), 456L, "cda_preserved_identifiers")

non_cda_fact_diff <- paste(
  "SELECT f.* FROM canonical.fact_series_events f JOIN canonical.dim_series d USING(series_id)",
  "WHERE d.source_id<>'cda_curve' EXCEPT",
  "SELECT f.* FROM prod.canonical.fact_series_events f JOIN prod.canonical.dim_series d USING(series_id)",
  "WHERE d.source_id<>'cda_curve'"
)
assert_equal(scalar(paste0("SELECT count(*)::INTEGER FROM (", non_cda_fact_diff, ")")),
             0L, "candidate_minus_production_non_cda_facts")
non_cda_fact_diff_reverse <- paste(
  "SELECT f.* FROM prod.canonical.fact_series_events f JOIN prod.canonical.dim_series d USING(series_id)",
  "WHERE d.source_id<>'cda_curve' EXCEPT",
  "SELECT f.* FROM canonical.fact_series_events f JOIN canonical.dim_series d USING(series_id)",
  "WHERE d.source_id<>'cda_curve'"
)
assert_equal(scalar(paste0("SELECT count(*)::INTEGER FROM (", non_cda_fact_diff_reverse, ")")),
             0L, "production_minus_candidate_non_cda_facts")

assert_equal(scalar(paste(
  "SELECT count(*)::INTEGER FROM canonical.fact_series_events f",
  "JOIN canonical.dim_series d USING(series_id)",
  "WHERE d.source_id='lrm_auctions' AND NOT f.is_deleted"
)), 10334L, "lrm_facts")
assert_equal(scalar("SELECT count(*)::INTEGER FROM canonical.dim_series WHERE source_id='lrm_auctions'"),
             940L, "lrm_identities")
assert_equal(scalar("SELECT count(*)::INTEGER FROM research.curves WHERE source_file='Curva_CDA.xlsx'"),
             0L, "cda_research_rows")

identity <- DBI::dbGetQuery(con, paste(
  "SELECT d.data_release_id,d.source_bundle_id,d.build_id,d.attempt_id,d.status,",
  "d.error_count,d.warning_count,d.schema_version",
  "FROM audit.active_data_release a JOIN audit.data_releases d USING(data_release_id)"
))
print(identity)
cat("verification=PASS\n")
