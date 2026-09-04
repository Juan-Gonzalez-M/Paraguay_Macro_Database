# --- Research marts, coverage dashboard and quality screens ------------------
# The audit's P2. Four things, all of which depend on the classification and
# reconciliation layers built for P0 and P1:
#
#   marts      one research-facing view per Annex domain, carrying the review
#              and reconciliation status of the worksheet each series came from
#              so a mart can never quietly imply more assurance than exists
#   dashboard  what the database covers, per source worksheet, with its status
#   grains     auctions, trades, curves and entity panels counted separately
#              from scalar macro series, because a catalogue that mixes them
#              misrepresents economic breadth -- the failure the audit found
#              when 85% of Annex identifiers came from detailed trade layouts
#   screens    the gap, discontinuity and cross-source tests of section 11

SERIES_GRAIN_VALUES <- c("scalar_series", "event", "entity_panel", "curve_panel")

# Grain is declared per source and, since schema 32, may be overridden per
# worksheet.
#
# One grain per source was too coarse and the audit's section 4.3 names the case:
# direct_investment is declared scalar_series, and its Cuadro 5 and Cuadro 7 are
# country panels -- 73 and 34 countries each, which is an entity panel wearing a
# scalar catalogue's clothes. One workbook mixing structures is normal, and
# forcing a single answer for it means the catalogue is wrong either way.
#
# The `*` wildcard in source_sheet is the source-level rule, matching the
# convention config/table_status.csv and config/source_value_tokens.csv already
# use. A worksheet row wins over the wildcard.
apply_series_grain <- function(con, root) {
  path <- file.path(root, "config", "source_grains.csv")
  required <- c("source_id", "source_sheet", "series_grain", "note", "reviewed_by", "reviewed_at")
  if (!file.exists(path)) stop("Series grain configuration not found: ", path, call. = FALSE)
  grains <- readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()))
  if (!identical(names(grains), required)) stop(
    "Series grain guard: config/source_grains.csv columns changed or are reordered. Expected: ",
    paste(required, collapse = ", "), call. = FALSE
  )
  invalid <- setdiff(unique(grains$series_grain), SERIES_GRAIN_VALUES)
  if (length(invalid)) stop(
    "Series grain guard: unsupported series_grain value(s): ", paste(invalid, collapse = "; "),
    ". Allowed: ", paste(SERIES_GRAIN_VALUES, collapse = ", "), ".", call. = FALSE
  )
  if (anyDuplicated(paste(grains$source_id, grains$source_sheet))) stop(
    "Series grain guard: duplicate (source_id, source_sheet) rows.", call. = FALSE
  )
  registry_path <- file.path(root, "config", "source_registry.csv")
  if (file.exists(registry_path)) {
    registered <- readr::read_csv(registry_path, show_col_types = FALSE)$source_id
    wildcard <- grains$source_id[grains$source_sheet == RECONCILIATION_UNBOUNDED]
    undeclared <- setdiff(registered, wildcard)
    if (length(undeclared)) stop(
      "Series grain guard: no source-level grain declared for source(s): ",
      paste(undeclared, collapse = "; "), call. = FALSE
    )
  }
  replace_table_if_changed(con, "source_grains", grains %>% dplyr::transmute(
    source_id, source_sheet, series_grain, note,
    reviewed_by = dplyr::coalesce(.data$reviewed_by, "unreviewed"),
    reviewed_at = suppressWarnings(lubridate::ymd(.data$reviewed_at, quiet = TRUE))
  ))
  # The source-level rule first, then the worksheet overrides on top of it. A
  # series is placed by the sheet it is published on, which the documented
  # snapshot records per observation; a series appearing on several sheets keeps
  # the source rule, because a grain that changes by worksheet is a property of
  # the worksheet and not of that series.
  DBI::dbExecute(con, paste0(
    "UPDATE dim_series SET series_grain = (",
    "  SELECT g.series_grain FROM source_grains g",
    "  WHERE g.source_id = dim_series.source_id AND g.source_sheet = ",
    sql_string(RECONCILIATION_UNBOUNDED), ")"
  ))
  if (database_object_exists(con, "documented_series_snapshot")) {
    DBI::dbExecute(con, paste0(
      "UPDATE dim_series SET series_grain = o.series_grain FROM (",
      "  SELECT s.series_id, any_value(g.series_grain) AS series_grain",
      "  FROM ", project_qualified_name("documented_series_snapshot"), " s",
      "  JOIN ", project_qualified_name("source_grains"), " g",
      "    ON g.source_id = s.source_id AND g.source_sheet = s.source_sheet",
      "  WHERE g.source_sheet <> ", sql_string(RECONCILIATION_UNBOUNDED),
      "  GROUP BY 1 HAVING count(DISTINCT g.series_grain) = 1",
      "    AND count(DISTINCT s.source_sheet) = 1) o",
      " WHERE o.series_id = dim_series.series_id"
    ))
  }
  invisible(nrow(grains))
}

# The seven marts the audit names. Each is the same shape, so the SQL is written
# once: a mart is a domain filter over the observation view, joined to the
# classification, review and reconciliation layers.
ANNEX_MART_DOMAINS <- list(
  national_accounts_activity = c("national_accounts", "activity_indicators", "labour"),
  prices = "prices",
  money_credit = "monetary_financial",
  fiscal = "fiscal",
  external_accounts = "balance_of_payments",
  trade = "trade",
  reserves_fx = c("external_reserves_fx", "external_debt")
)

create_mart_views <- function(con) {
  for (mart in names(ANNEX_MART_DOMAINS)) {
    domains <- paste(vapply(ANNEX_MART_DOMAINS[[mart]], sql_string, character(1)), collapse = ", ")
    # Three join defects the follow-up audit found, all of them latent rather
    # than currently firing, which is exactly why they had to be fixed before a
    # second vintage or a multi-sheet canonical series arrives:
    #
    #   d.source_sheet = d.source_sheet was a tautology. It reads as a join key
    #   and constrains nothing, so the moment one series carries two domain rows
    #   every observation of it is emitted twice.
    #
    #   the reconciliation join carried no release or vintage. table_reconciliation
    #   is keyed by (vintage_id, source_sheet) and is rewritten per release; with
    #   two vintages in the file, one observation would meet several
    #   reconciliation rows and multiply.
    #
    #   the status join accepted the source-level '*' row and the worksheet row
    #   interchangeably, so a source carrying both doubled every row.
    #
    # Sheet identity now comes from the observation (v_series_observations
    # carries it per row), not from the classification side of the join.
    create_project_view(con, paste0("v_mart_", mart, "_all"), paste(
      "SELECT d.domain, d.subdomain, d.measure_family, o.series_id, s.label AS series_label,",
      "o.source_id, o.source_sheet, o.period, o.period_start, o.period_end, o.frequency,",
      "o.value, o.value_in_base_units, o.unit_code, o.scale_multiplier, s.currency,",
      "s.stock_flow, s.nominal_real, s.seasonal_adjustment, s.transformation, s.valuation,",
      # Explicit economic dimensions rather than a Spanish row label to parse.
      # Null wherever the source does not publish them, which is most of the
      # Annex; the eight detailed trade worksheets carry all four.
      "x.product, x.trade_flow, x.trade_classification, x.trade_regime, x.measure,",
      "o.available_at, o.observation_status, o.vintage_id, o.accepted_release_id,",
      "t.status AS review_status, r.status AS reconciliation_status",
      "FROM v_series_observations o",
      "JOIN v_series_domain d ON d.series_id = o.series_id",
      "  AND d.source_id = o.source_id AND d.source_sheet = o.source_sheet",
      "JOIN dim_series s ON s.series_id = o.series_id",
      "LEFT JOIN v_series_dimensions x ON x.series_id = o.series_id",
      "LEFT JOIN v_series_table_status t ON t.series_id = o.series_id",
      "  AND t.source_id = o.source_id AND t.source_sheet = o.source_sheet",
      "LEFT JOIN table_reconciliation r ON r.source_id = o.source_id",
      "  AND r.source_sheet = o.source_sheet AND r.vintage_id = o.vintage_id",
      "WHERE NOT o.is_deleted AND d.domain IN (", domains, ")"
    ), schema = "marts")
    # The audit's P0: "researchers may mistake provisional/unbalanced data for
    # approved research products". The unfiltered view keeps the name that says
    # what it is; the mart proper carries only rows whose worksheet an economist
    # validated and whose source cells reconcile. Today every one of them is
    # empty, which is the honest answer and the same answer v_research_series
    # already gives.
    #
    # Since schema 36 it also requires the *series* to have been reviewed, for
    # the reason set out over v_research_series: a mart row is an observation of
    # a series, so if the series' unit, timing and stock/flow status rest on a
    # regex over a Spanish label rather than on an economist's judgement, the
    # observation is not a research product either. Worksheet review and series
    # review answer different questions and both are required.
    create_project_view(con, paste0("v_mart_", mart), paste(
      "SELECT m.* FROM", paste0("marts.v_mart_", mart, "_all"), "m",
      "JOIN", project_qualified_name("series_review"), "sr ON sr.series_id = m.series_id",
      "WHERE m.review_status = 'validated' AND m.reconciliation_status = 'balanced'",
      "AND m.vintage_id IN (", accepted_release_vintages_sql(), ")"
    ), schema = "marts")
  }
  # Catalogue counts that do not pretend an auction tender is a macro series.
  #
  # Counted over v_series_latest rather than over fact_series_events, so a
  # catalogue describes the database a researcher can read. A series whose only
  # vintage belongs to a staged or blocked release is not in the catalogue,
  # because it is not in anything else either.
  create_project_view(con, "v_catalogue_by_grain", paste(
    "SELECT coalesce(d.series_grain, 'undeclared') AS series_grain, d.source_id,",
    "count(*) AS series, sum(x.observations) AS observations",
    "FROM dim_series d",
    "JOIN (SELECT series_id, count(*) AS observations FROM v_series_latest",
    "      GROUP BY 1) x USING (series_id)",
    "GROUP BY 1, 2"
  ), schema = "marts")
  # One catalogue per grain, because a single list of 13,985 identifiers reads as
  # 13,985 macroeconomic concepts and is not.
  #
  # 4,485 of them are events -- individual LRM auction tenders and interbank
  # operations, 2,263 of which have exactly one observation each -- 1,287 are
  # points on a yield curve, and 770 are entity-panel rows. All of them belong in
  # the database and none of them belongs in the same catalogue as GDP or the
  # consumer price index. Counting them together is what makes the coverage look
  # an order of magnitude broader than it is, which is the audit's section 6.2.
  #
  # Nothing is hidden: each grain gets its own catalogue and v_catalogue_by_grain
  # still totals them. Only the scalar one is the macro series catalogue.
  for (grain in SERIES_GRAIN_VALUES) {
    create_project_view(con, paste0("v_catalogue_", grain), paste(
      "SELECT d.series_id, d.source_id, n.source_sheet, d.label, d.frequency, d.unit_code,",
      "d.scale_multiplier, d.currency, d.stock_flow, d.nominal_real, d.seasonal_adjustment,",
      "d.identity_stability, x.first_period, x.last_period, coalesce(x.observations, 0) AS observations",
      "FROM dim_series d",
      # One row per series. A dozen series are published across all fourteen
      # year-sheets of their workbook, and joining the sheets row-by-row put each
      # of them in the catalogue fourteen times -- an inflated count, in the view
      # whose whole purpose is to stop the count being inflated.
      "LEFT JOIN (SELECT series_id, string_agg(DISTINCT source_sheet, '; ' ORDER BY source_sheet)",
      "           AS source_sheet FROM documented_series_snapshot GROUP BY 1) n",
      "  USING (series_id)",
      "JOIN (SELECT series_id, min(period) AS first_period, max(period) AS last_period,",
      "      count(*) AS observations FROM v_series_latest GROUP BY 1) x USING (series_id)",
      "WHERE d.series_grain =", sql_string(grain)
    ), schema = "marts")
  }
  invisible(TRUE)
}

# --- Coverage dashboard -----------------------------------------------------
# The worksheets the dashboard is about: one row per parsed worksheet, and the
# key both registers below are resolved against.
COVERAGE_DASHBOARD_KEYS <- "SELECT DISTINCT source_id, source_sheet FROM documented_series_snapshot"

write_coverage_dashboard <- function(con, root) {
  if (is.null(root)) return(invisible(NULL))
  dashboard <- DBI::dbGetQuery(con, paste(
    "WITH series_stats AS (",
    "  SELECT s.source_id, s.source_sheet, count(DISTINCT s.series_id) AS series,",
    "         count(*) AS observations, min(s.period) AS first_period, max(s.period) AS last_period",
    "  FROM documented_series_snapshot s GROUP BY 1, 2",
    "), identity_stats AS (",
    "  SELECT s.source_id, s.source_sheet,",
    "    count(DISTINCT CASE WHEN d.identity_stability <> 'semantic'",
    "      THEN s.series_id END) AS non_semantic_series,",
    "    count(DISTINCT CASE WHEN d.unit = 'source_units' THEN s.series_id END) AS unresolved_unit_series,",
    "    count(DISTINCT CASE WHEN d.hierarchy_status = 'unresolved' THEN s.series_id END)",
    "      AS unresolved_hierarchy_series",
    "  FROM documented_series_snapshot s JOIN dim_series d USING (series_id) GROUP BY 1, 2",
    ")",
    "SELECT st.source_id, st.source_sheet, g.series_grain, dm.domain, dm.subdomain,",
    "st.series, st.observations, st.first_period, st.last_period,",
    "ts.status AS review_status, ts.parser_claim, ts.reviewed_by,",
    "rc.status AS reconciliation_status, rc.balance_delta, rc.cell_reuse,",
    # What the audit asks a coverage report to show together: how much data is
    # here, how far back, whether every source cell is accounted for, how much of
    # its meaning is established and by whom, and whether any identifier on it
    # has stopped naming one series. A coverage number on its own is the thing
    # the audit warns about.
    "coalesce(rc.unclassified_cells, 0) AS unclassified_cells,",
    "coalesce(rc.parser_defect_cells, 0) AS unread_source_cells,",
    "ist.non_semantic_series, ist.unresolved_unit_series, ist.unresolved_hierarchy_series,",
    "coalesce(sem.derived_fields, 0) AS derived_measurement_fields,",
    "coalesce(sem.reviewed_fields, 0) AS reviewed_measurement_fields,",
    "coalesce(dim.dimension_values, 0) AS economic_dimension_values,",
    "coalesce(res.ambiguous_identifiers, 0) AS ambiguous_prior_identifiers,",
    "coalesce(rev.revisions, 0) AS recorded_revisions,",
    "coalesce(brk.breaks, 0) AS methodology_breaks",
    "FROM series_stats st",
    "LEFT JOIN identity_stats ist USING (source_id, source_sheet)",
    # Exact-over-wildcard, not either-of, for both registers. A source carrying
    # both a worksheet row and a '*' row otherwise appears once per rule -- the
    # audit's F-06, which this join failed and the one below only appeared to
    # pass. See wildcard_precedence_join_sql() in scripts/08_reconciliation.R.
    "LEFT JOIN (",
    wildcard_precedence_join_sql("source_grains", "series_grain", COVERAGE_DASHBOARD_KEYS),
    ") g ON g.source_id = st.source_id AND g.source_sheet = st.source_sheet",
    "LEFT JOIN table_domains dm ON dm.source_id = st.source_id AND dm.source_sheet = st.source_sheet",
    "LEFT JOIN (",
    wildcard_precedence_join_sql(
      "table_status", c("status", "parser_claim", "reviewed_by"), COVERAGE_DASHBOARD_KEYS
    ),
    ") ts ON ts.source_id = st.source_id AND ts.source_sheet = st.source_sheet",
    "LEFT JOIN table_reconciliation rc ON rc.source_id = st.source_id",
    "  AND rc.source_sheet = st.source_sheet",
    "LEFT JOIN (",
    "  SELECT n.source_id, n.source_sheet,",
    "    count(*) FILTER (WHERE e.basis <> 'reviewed') AS derived_fields,",
    "    count(*) FILTER (WHERE e.basis = 'reviewed') AS reviewed_fields",
    "  FROM series_semantic_evidence e",
    "  JOIN (SELECT DISTINCT series_id, source_id, source_sheet FROM documented_series_snapshot) n",
    "    USING (series_id) GROUP BY 1, 2",
    ") sem ON sem.source_id = st.source_id AND sem.source_sheet = st.source_sheet",
    "LEFT JOIN (",
    "  SELECT n.source_id, n.source_sheet, count(*) AS dimension_values",
    "  FROM series_dimension e",
    "  JOIN (SELECT DISTINCT series_id, source_id, source_sheet FROM documented_series_snapshot) n",
    "    USING (series_id) GROUP BY 1, 2",
    ") dim ON dim.source_id = st.source_id AND dim.source_sheet = st.source_sheet",
    "LEFT JOIN (",
    "  SELECT d.source_id, count(*) AS ambiguous_identifiers",
    "  FROM v_series_id_scalar_resolution s",
    "  JOIN dim_series d ON d.series_id = s.lookup_id",
    "  WHERE s.resolution_cardinality <> 'one_to_one' GROUP BY 1",
    ") res ON res.source_id = st.source_id",
    "LEFT JOIN (SELECT d.source_id, count(*) AS revisions FROM series_revisions r",
    "           JOIN dim_series d USING (series_id) GROUP BY 1) rev ON rev.source_id = st.source_id",
    "LEFT JOIN (SELECT concept_key, count(*) AS breaks FROM methodology_regime",
    "           WHERE comparability <> 'comparable' GROUP BY 1) brk ON brk.concept_key = st.source_id",
    "ORDER BY st.source_id, st.source_sheet"
  ))
  readr::write_csv(dashboard, file.path(root, "outputs", "coverage_dashboard.csv"))
  invisible(dashboard)
}

# --- Section 11 P2 screens --------------------------------------------------
# All three are warnings by design. A gap or a jump is a reason to look at the
# source, not evidence that the data is wrong: Paraguayan series legitimately
# start late, pause, and move sharply. Treating a statistical screen as proof of
# a defect would be the same error the audit warns about when it separates
# "candidate equality" from "recommended consolidation".
# A screen counts; a worklist names. The re-audit's RA2-12.
#
# Bounded, because the point is that somebody works through it: 38,433 rows is
# the same "look at everything" instruction as the fifteen-row summary it
# replaces, only longer. The cap is recorded in the file itself so a reader can
# tell a full list from a truncated one, and the summary CSV keeps the totals.
SCREEN_WORKLIST_LIMIT <- 2000L

write_screen_worklist <- function(con, root, filename, query,
                                  limit = SCREEN_WORKLIST_LIMIT) {
  if (is.null(root)) return(invisible(NULL))
  rows <- tryCatch(DBI::dbGetQuery(con, query), error = function(e) NULL)
  if (is.null(rows) || !nrow(rows)) return(invisible(NULL))
  total <- nrow(rows)
  rows <- utils::head(rows, limit)
  rows$worklist_rank <- seq_len(nrow(rows))
  rows$worklist_of_total <- total
  readr::write_csv(rows, file.path(root, "outputs", filename))
  invisible(rows)
}

run_quality_screens <- function(con, release_id, root) {
  expected_step <- paste(
    "CASE frequency WHEN 'monthly' THEN 1 WHEN 'quarterly' THEN 3",
    "WHEN 'semiannual' THEN 6 WHEN 'annual' THEN 12 END"
  )
  gaps <- DBI::dbGetQuery(con, paste(
    "WITH ordered AS (",
    "  SELECT series_id, source_id, frequency, period_start,",
    "    lag(period_start) OVER (PARTITION BY series_id ORDER BY period_start) AS previous_start",
    "  FROM v_series_observations",
    "  WHERE NOT is_deleted AND frequency IN ('monthly','quarterly','semiannual','annual')",
    "), steps AS (",
    "  SELECT series_id, source_id, frequency, previous_start, period_start,",
    "    datediff('month', previous_start, period_start) AS observed_step,",
    expected_step, "AS expected_step",
    "  FROM ordered WHERE previous_start IS NOT NULL",
    ")",
    "SELECT source_id, count(DISTINCT series_id) AS series_with_gaps,",
    "sum(CASE WHEN observed_step > expected_step THEN 1 ELSE 0 END) AS gap_events,",
    "sum(CASE WHEN observed_step > expected_step",
    "    THEN (observed_step / expected_step) - 1 ELSE 0 END) AS missing_periods",
    "FROM steps WHERE observed_step > expected_step GROUP BY 1 ORDER BY 3 DESC"
  ))
  if (nrow(gaps)) {
    readr::write_csv(gaps, file.path(root, "outputs", "gap_screen_latest.csv"))
    # …and the gaps themselves. The summary above says 499 series skip 24,149
    # periods; it does not say which series, or when, which is everything an
    # investigation needs. The re-audit's RA2-12, applied to both screens.
    write_screen_worklist(con, root, "gap_worklist.csv", paste(
      "WITH ordered AS (",
      "  SELECT o.series_id, o.source_id, o.source_sheet, o.frequency, o.vintage_id,",
      "    o.period_start, o.unit_code,",
      "    lag(o.period_start) OVER (PARTITION BY o.series_id ORDER BY o.period_start)",
      "      AS previous_start",
      "  FROM v_series_observations o",
      "  WHERE NOT o.is_deleted AND o.frequency IN ('monthly','quarterly','semiannual','annual')",
      "), steps AS (",
      "  SELECT series_id, source_id, source_sheet, frequency, vintage_id, unit_code,",
      "    previous_start, period_start,",
      "    datediff('month', previous_start, period_start) AS observed_step,",
      expected_step, "AS expected_step",
      "  FROM ordered WHERE previous_start IS NOT NULL",
      ")",
      "SELECT series_id, source_id, source_sheet, frequency, unit_code, vintage_id,",
      "  previous_start AS gap_after, period_start AS resumes_at,",
      "  observed_step AS months_between, expected_step AS months_expected,",
      "  (observed_step / expected_step) - 1 AS missing_periods",
      "FROM steps WHERE observed_step > expected_step",
      "ORDER BY missing_periods DESC, series_id, resumes_at"
    ))
    insert_quality_flag(
      con, release_id, "warning", "regular_period_gaps", NA_character_,
      paste0(
        sum(gaps$series_with_gaps), " regular-frequency series skip at least one expected period (",
        format(round(sum(gaps$missing_periods)), scientific = FALSE),
        " periods in total). Expected for series that start late or pause; see ",
        "outputs/gap_screen_latest.csv."
      )
    )
  }

  # Robust jump screen: compare each period-on-period change with the series'
  # own median absolute change. Scale-free, so it works across guaraníes,
  # tonnes and index points without a unit-specific threshold, and resistant to
  # the outliers it is looking for -- which a standard deviation is not.
  jumps <- DBI::dbGetQuery(con, paste(
    "WITH ordered AS (",
    "  SELECT o.series_id, o.source_id, o.period, o.value, o.vintage_id,",
    "    o.value - lag(o.value) OVER (PARTITION BY o.series_id ORDER BY o.period) AS change",
    "  FROM v_series_observations o WHERE NOT o.is_deleted",
    "), scaled AS (",
    "  SELECT series_id, source_id, period, value, change,",
    "    median(abs(change)) OVER (PARTITION BY series_id) AS typical_change,",
    "    count(*) OVER (PARTITION BY series_id) AS observations",
    "  FROM ordered WHERE change IS NOT NULL",
    ")",
    "SELECT source_id, count(*) AS flagged_observations, count(DISTINCT series_id) AS series",
    "FROM scaled",
    "WHERE observations >= 24 AND typical_change > 0 AND abs(change) > 10 * typical_change",
    "GROUP BY 1 ORDER BY 2 DESC"
  ))
  if (nrow(jumps)) {
    readr::write_csv(jumps, file.path(root, "outputs", "discontinuity_screen_latest.csv"))
    # The rows behind the count. 38,433 flagged observations summarised into
    # fifteen rows by source cannot be investigated by anybody: the `scaled` CTE
    # above already computes every field a reviewer needs and the outer SELECT
    # threw all of it away. The re-audit's RA2-12.
    #
    # Ranked by how far past the threshold each observation sits, so the worst
    # are first, and bounded -- a worklist nobody can finish is a screen with a
    # different file name.
    write_screen_worklist(con, root, "discontinuity_worklist.csv", paste(
      "WITH ordered AS (",
      "  SELECT o.series_id, o.source_id, o.source_sheet, o.period, o.value, o.vintage_id,",
      "    o.unit_code,",
      "    lag(o.value) OVER (PARTITION BY o.series_id ORDER BY o.period) AS previous_value,",
      "    o.value - lag(o.value) OVER (PARTITION BY o.series_id ORDER BY o.period) AS change",
      "  FROM v_series_observations o WHERE NOT o.is_deleted",
      "), scaled AS (",
      "  SELECT *, median(abs(change)) OVER (PARTITION BY series_id) AS typical_change,",
      "    count(*) OVER (PARTITION BY series_id) AS observations",
      "  FROM ordered WHERE change IS NOT NULL",
      ")",
      "SELECT series_id, source_id, source_sheet, period, previous_value, value, change,",
      "  typical_change, 10 * typical_change AS threshold,",
      "  abs(change) / nullif(typical_change, 0) AS times_typical_change,",
      "  observations, unit_code, vintage_id,",
      # The coordinate lives on the snapshot, not on the observation view, and a
      # plain join would multiply a series published on several worksheets. A
      # scalar subquery returns one row per observation by construction.
      "  (SELECT any_value(n.source_row) FROM", project_qualified_name("documented_series_snapshot"), "n",
      "   WHERE n.vintage_id = scaled.vintage_id AND n.series_id = scaled.series_id",
      "     AND n.period = scaled.period) AS source_row,",
      "  (SELECT any_value(n.source_column) FROM", project_qualified_name("documented_series_snapshot"), "n",
      "   WHERE n.vintage_id = scaled.vintage_id AND n.series_id = scaled.series_id",
      "     AND n.period = scaled.period) AS source_column",
      "FROM scaled",
      "WHERE observations >= 24 AND typical_change > 0 AND abs(change) > 10 * typical_change",
      "ORDER BY times_typical_change DESC"
    ))
    insert_quality_flag(
      con, release_id, "warning", "discontinuity_screen", NA_character_,
      paste0(
        sum(jumps$flagged_observations), " observations in ", sum(jumps$series),
        " series move more than ten times the series' own median absolute change. ",
        "A screen for source and methodology review, not proof of an error; see ",
        "outputs/discontinuity_screen_latest.csv."
      )
    )
  }

  # Cross-source comparison runs over concepts a reviewer has declared
  # equivalent. None are declared yet, so it reports that rather than inventing
  # equivalences from matching labels -- the audit is explicit that identical
  # values are not evidence of identical concepts.
  equivalences <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM map_series_concept",
    "WHERE relationship = 'equivalent' AND mapping_status = 'reviewed'"
  ))$n[[1]]
  if (equivalences) {
    divergence <- DBI::dbGetQuery(con, paste(
      "WITH equivalent AS (",
      "  SELECT concept_id, series_id FROM map_series_concept",
      "  WHERE relationship = 'equivalent' AND mapping_status = 'reviewed'",
      ")",
      "SELECT e.concept_id, o.period, count(DISTINCT o.series_id) AS sources,",
      "max(o.value_in_base_units) - min(o.value_in_base_units) AS spread,",
      "max(abs(o.value_in_base_units)) AS scale",
      "FROM equivalent e JOIN v_series_observations o USING (series_id)",
      "WHERE NOT o.is_deleted GROUP BY 1, 2 HAVING count(DISTINCT o.series_id) > 1"
    ))
    diverging <- divergence[
      is.finite(divergence$spread) & divergence$scale > 0 &
        abs(divergence$spread) > 0.01 * divergence$scale, , drop = FALSE
    ]
    if (nrow(diverging)) {
      readr::write_csv(diverging, file.path(root, "outputs", "cross_source_screen_latest.csv"))
      insert_quality_flag(
        con, release_id, "warning", "cross_source_divergence", NA_character_,
        paste(
          nrow(diverging), "concept-periods where series declared equivalent differ by more",
          "than one percent of their level."
        )
      )
    }
  }
  invisible(TRUE)
}
