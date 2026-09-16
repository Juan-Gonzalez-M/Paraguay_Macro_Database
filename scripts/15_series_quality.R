# --- Post-promotion series census and review package -----------------------

SERIES_REVIEW_CATEGORIES <- c(
  "apparently_valid_preliminary", "research_validated", "discovery_only",
  "clear_mechanical_defect", "probable_identity_fragmentation",
  "probable_duplicate_or_overlap", "semantic_review_required",
  "provenance_review_required", "insufficient_evidence"
)

write_series_quality_package <- function(con, output_dir, database_path = NA_character_,
                                         baseline_sha256 = NA_character_) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  write_query <- function(file, sql) {
    rows <- DBI::dbGetQuery(con, sql)
    readr::write_csv(rows, file.path(output_dir, file), na = "")
    invisible(rows)
  }

  observation_stats_sql <- paste(
    "WITH ordered AS (SELECT o.series_id,o.period_start,o.period_end,o.period,o.value,",
    " lag(o.period_start) OVER(PARTITION BY o.series_id ORDER BY o.period_start,o.period) prev_period,",
    " lag(o.value) OVER(PARTITION BY o.series_id ORDER BY o.period_start,o.period) prev_value",
    " FROM main.v_series_latest o), stats AS (SELECT series_id,count(*) observation_count_check,",
    " count(value) numeric_observation_count,min(value) minimum_value,max(value) maximum_value,",
    " avg(value) mean_value,stddev_pop(value) standard_deviation,count(DISTINCT value) distinct_values,",
    " count(*) FILTER(WHERE value<0) negative_value_count,",
    " count(*) FILTER(WHERE value=0) zero_value_count,",
    " median(date_diff('day',prev_period,period_start)) FILTER(WHERE prev_period IS NOT NULL)",
    "  observed_median_step_days,",
    " max(abs(value-prev_value)/greatest(abs(prev_value),1e-12))",
    "  FILTER(WHERE prev_value IS NOT NULL) max_relative_step",
    " FROM ordered GROUP BY series_id), signatures AS (SELECT series_id,count(*) signature_observations,",
    " md5(string_agg(strftime(period_start,'%Y-%m-%d')||':'||",
    "  coalesce(strftime(period_end,'%Y-%m-%d'),'<NULL>')||':'||printf('%.17g',value),",
    "  '|' ORDER BY period_start,period)) observation_signature",
    " FROM ordered GROUP BY series_id), signature_groups AS (",
    " SELECT observation_signature,signature_observations,count(*) signature_group_size",
    " FROM signatures WHERE signature_observations>=2 GROUP BY ALL HAVING count(*)>1),",
    " label_groups AS (SELECT lower(trim(original_source_label)) normalized_source_label,",
    " count(*) repeated_label_series_count,count(DISTINCT source_id) repeated_label_source_count",
    " FROM catalog.series GROUP BY 1)",
    " SELECT c.*,s.numeric_observation_count,s.minimum_value,s.maximum_value,s.mean_value,",
    " s.standard_deviation,s.distinct_values,s.negative_value_count,s.zero_value_count,",
    " s.observed_median_step_days,s.max_relative_step,",
    " CASE WHEN s.distinct_values=1 THEN TRUE ELSE FALSE END constant_series,",
    " CASE WHEN s.distinct_values>1 AND coalesce(s.standard_deviation,0)<=",
    "  1e-9*greatest(abs(coalesce(s.mean_value,0)),1) THEN TRUE ELSE FALSE END near_constant_series,",
    " g.observation_signature,coalesce(g.signature_group_size,1) exact_population_group_size,",
    " l.normalized_source_label,l.repeated_label_series_count,l.repeated_label_source_count,",
    " TRUE AS catalog_exposed,(c.observation_interface IS NOT NULL) AS explore_exposed,",
    " (c.research_admission_status='admitted') AS research_exposed",
    " FROM catalog.series c LEFT JOIN stats s ON s.series_id=c.candidate_id",
    " LEFT JOIN signatures z ON z.series_id=c.candidate_id",
    " LEFT JOIN signature_groups g ON g.observation_signature=z.observation_signature",
    "  AND g.signature_observations=z.signature_observations",
    " LEFT JOIN label_groups l ON l.normalized_source_label=lower(trim(c.original_source_label))",
    " ORDER BY c.source_id,c.candidate_id"
  )
  classification <- write_query("series_classification.csv", observation_stats_sql)
  if (nrow(classification) != 13985L || anyDuplicated(classification$candidate_id)) stop(
    "Series-quality census must contain exactly one row for each of 13,985 active series.",
    call. = FALSE
  )
  if (!all(classification$primary_review_category %in% SERIES_REVIEW_CATEGORIES)) stop(
    "Series-quality census contains an unknown primary review category.", call. = FALSE
  )

  write_query("counts_by_dimension.csv", paste(
    "WITH dimensions AS (",
    " SELECT 'source' AS dimension,source_id AS dimension_value,count(*) AS series,sum(observation_count) AS observations",
    " FROM catalog.series GROUP BY 1,2 UNION ALL",
    " SELECT 'dataset',coalesce(source_dataset,'<unresolved>'),count(*),sum(observation_count)",
    " FROM catalog.series GROUP BY 1,2 UNION ALL",
    " SELECT 'frequency',coalesce(frequency,'<unresolved>'),count(*),sum(observation_count)",
    " FROM catalog.series GROUP BY 1,2 UNION ALL",
    " SELECT 'unit',coalesce(unit_code,'<unresolved>'),count(*),sum(observation_count)",
    " FROM catalog.series GROUP BY 1,2 UNION ALL",
    " SELECT 'primary_review_category',primary_review_category,count(*),sum(observation_count)",
    " FROM catalog.series GROUP BY 1,2 UNION ALL",
    " SELECT 'validation_tier',validation_tier,count(*),sum(observation_count)",
    " FROM catalog.series GROUP BY 1,2 UNION ALL",
    " SELECT 'catalog_admission',catalog_admission_status,count(*),sum(observation_count)",
    " FROM catalog.series GROUP BY 1,2 UNION ALL",
    " SELECT 'explore_admission',explore_admission_status,count(*),sum(observation_count)",
    " FROM catalog.series GROUP BY 1,2 UNION ALL",
    " SELECT 'research_admission',research_admission_status,count(*),sum(observation_count)",
    " FROM catalog.series GROUP BY 1,2)",
    " SELECT * FROM dimensions ORDER BY dimension,series DESC,dimension_value"
  ))

  write_query("suspicious_population_register.csv", paste(
    "SELECT source_id,count(*) series,sum(observation_count) observations,",
    " count(*) FILTER(WHERE observation_count<=2) series_at_most_two_observations,",
    " count(*) FILTER(WHERE observation_count<=12) series_at_most_twelve_observations,",
    " count(*) FILTER(WHERE identity_stability IN ('positional','positional_lane')) positional_series,",
    " count(*) FILTER(WHERE supported_overlap_series_count>0) supported_overlap_series,",
    " count(*) FILTER(WHERE unit_code IS NULL OR unit_code='UNRESOLVED_SOURCE_UNITS') unresolved_unit_series,",
    " count(*) FILTER(WHERE gap_count>0) gap_indicator_series,",
    " count(*) FILTER(WHERE coordinate_lineage_status<>'complete_for_current_observations')",
    "  coordinate_limited_series,",
    " count(*) FILTER(WHERE explore_admission_status IN ('withheld','quarantined')) withheld_series,",
    " string_agg(DISTINCT primary_review_category,';' ORDER BY primary_review_category) categories",
    " FROM catalog.series GROUP BY source_id ORDER BY series DESC,source_id"
  ))

  write_query("exact_duplicate_overlap_diagnostics.csv", paste(
    "WITH sig AS (SELECT series_id,count(*) observations,min(period_start) first_period,",
    " max(period_end) last_period,count(DISTINCT value) distinct_values,",
    " md5(string_agg(strftime(period_start,'%Y-%m-%d')||':'||",
    "  coalesce(strftime(period_end,'%Y-%m-%d'),'<NULL>')||':'||printf('%.17g',value),",
    "  '|' ORDER BY period_start,period)) observation_signature",
    " FROM main.v_series_latest GROUP BY series_id), groups AS (",
    " SELECT observation_signature,observations,count(*) group_size,",
    " bool_and(distinct_values=1) constant_population",
    " FROM sig WHERE observations>=2 GROUP BY 1,2 HAVING count(*)>1)",
    " SELECT g.observation_signature,g.observations,g.group_size,g.constant_population,",
    " s.series_id,c.source_id,c.original_source_label,c.full_series_path,c.frequency,c.unit_code,",
    " s.first_period,s.last_period,",
    " CASE WHEN c.supported_overlap_series_count>0",
    "  THEN 'supported_cross_source_overlap' ELSE 'review_indicator_only' END diagnostic_disposition",
    " FROM groups g JOIN sig s USING(observation_signature,observations)",
    " JOIN catalog.series c ON c.candidate_id=s.series_id",
    " ORDER BY g.group_size DESC,g.observation_signature,c.source_id,s.series_id"
  ))

  write_query("short_series_diagnostics.csv", paste(
    "SELECT candidate_id,source_id,original_source_label,full_series_path,data_structure,",
    " identity_basis,identity_stability,source_sheets,observation_count,earliest_period,latest_period,",
    " frequency,unit_code,primary_review_category,explore_admission_status,",
    " classification_issue_codes FROM catalog.series WHERE observation_count<=12",
    " ORDER BY observation_count,source_id,candidate_id"
  ))

  write_query("fragmented_identity_diagnostics.csv", paste(
    "WITH repeated AS (SELECT source_id,lower(trim(original_source_label)) normalized_label,",
    " count(*) series_count,count(DISTINCT source_sheets) worksheet_presentations,",
    " min(earliest_period) first_period,max(latest_period) last_period",
    " FROM catalog.series GROUP BY 1,2 HAVING count(*)>1)",
    " SELECT c.candidate_id,c.source_id,c.original_source_label,r.normalized_label,",
    " c.identity_basis,c.identity_stability,c.source_sheets,c.example_source_row,",
    " c.example_source_column,c.observation_count,c.earliest_period,c.latest_period,",
    " r.series_count,r.worksheet_presentations,c.primary_review_category,",
    " CASE WHEN c.source_id='lrm_auctions' THEN 'annual_sheet_or_measure_lane_review'",
    "  WHEN c.identity_stability IN ('positional','positional_lane') THEN 'positional_identity_review'",
    "  ELSE 'repeated_label_review_indicator' END diagnostic_disposition",
    " FROM catalog.series c JOIN repeated r ON r.source_id=c.source_id",
    "  AND r.normalized_label=lower(trim(c.original_source_label))",
    " WHERE c.identity_stability IN ('positional','positional_lane')",
    "  OR c.source_id='lrm_auctions'",
    " ORDER BY c.source_id,r.series_count DESC,r.normalized_label,c.candidate_id"
  ))

  decision_register <- data.frame(
    priority = c("P0", "P0", "P1", "P1", "P1", "P2", "P2"),
    population = c(
      "economic_annex / fx_operations same-label varying overlaps",
      "lrm_auctions annual-sheet and offered/assigned measure identities",
      "insurance_annex exact populations, predominantly constant zero",
      "corporate_bond_curves coordinate lineage",
      "unresolved source units across active series",
      "CDA deferred exploratory onboarding",
      "TCN annual-sheet identity correction and onboarding"
    ),
    decision_required = c(
      "Confirm conceptual equivalence, vintage relationship, precedence, and canonical membership.",
      "Confirm event-versus-series grain and add the omitted offered/assigned measure distinction before any merge.",
      "Determine whether equal zero histories are legitimate distinct sub-concepts; do not deduplicate by value.",
      "Establish durable row/node source locators or approve the explicit lineage limitation.",
      "Verify economic units source by source; do not infer from values alone.",
      "Separately approve provisional explore admission with incomplete acquisition metadata; no research exposure.",
      "Review source chain and repair likely annual-sheet fragmentation before separate provisional onboarding."
    ),
    current_action = c(rep("decision_register_only_no_data_change", 5), rep("deferred_separate_stage", 2)),
    stringsAsFactors = FALSE
  )
  readr::write_csv(decision_register, file.path(output_dir, "decision_register.csv"))
  readr::write_csv(data.frame(
    correction_id = character(), source_id = character(), defect = character(),
    upstream_change = character(), before_series = integer(), after_series = integer(),
    before_observations = integer(), after_observations = integer(), evidence = character()
  ), file.path(output_dir, "unambiguous_corrections.csv"))

  identity <- DBI::dbGetQuery(con, paste(
    "SELECT a.data_release_id build_id,a.source_bundle_id,",
    " d.attempt_id,d.schema_version,d.status AS decision,d.error_count,d.warning_count",
    " FROM audit.active_data_release a JOIN audit.data_releases d USING(data_release_id)",
    " JOIN audit.build_identity b USING(build_id)"
  ))
  identity$database_path <- database_path
  identity$bytes <- if (!is.na(database_path) && file.exists(database_path)) {
    file.info(database_path)$size
  } else NA_real_
  identity$sha256 <- if (!is.na(database_path) && file.exists(database_path)) {
    file_sha256(database_path)
  } else NA_character_
  identity$baseline_sha256 <- baseline_sha256
  readr::write_csv(identity, file.path(output_dir, "candidate_identity.csv"), na = "")
  invisible(list(classification = classification, identity = identity))
}
