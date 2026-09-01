# --- Canonical series, methodology regimes and concordances ------------------
# The audit's P1: concepts must be independent of source identity, and stable
# canonical identifiers must be separated from parser identifiers "so future
# parser improvements do not force wholesale identifier churn".
#
# This release makes that separation concrete. A canonical_series_id is assigned
# by a reviewer in config/canonical_series.csv and is never derived from a
# worksheet, a row position or a parser hash. Membership -- which parsed series
# currently carry a canonical series -- lives in map_canonical_series and is the
# only part that moves when a parser is repaired.
#
# The value of that split was demonstrated by this very release. Repairing the
# foreign-trade axis retired 6,706 parser identifiers and merged 1,106 more. Any
# research code citing them broke. A canonical identifier sitting above the
# parser layer would have survived unchanged, with only its membership rewritten
# -- which is exactly why the audit asks for the separation rather than for
# better parser identifiers.
#
# The registries ship empty on purpose. A canonical series is an economic claim
# about what a measure means; a methodology regime is a claim about when a
# definition changed. Neither can be derived from the workbooks, and seeding
# them with plausible-looking guesses would put unreviewed economics behind an
# interface that looks reviewed. The machinery, the guards and the review
# workflow are what this release delivers.

CANONICAL_REVIEW_STATUSES <- c("proposed", "reviewed", "retired")
# `alias` completes the set the audit's target model names (primary, alias,
# fragment, component): a second source surface publishing the same figures as
# the primary. The Annex CUADRO 20 series are the case in hand -- each matches a
# dedicated fx_operations series across all 379 of its monthly observations -- and
# without a role for it the only ways to record the relationship were to call one
# of them a component of the other, which is false, or to leave the duplication
# undeclared, which is what lets a researcher count it twice.
CANONICAL_RELATIONSHIPS <- c(
  "primary", "alias", "component", "alternative_frequency", "spliced_predecessor"
)
METHODOLOGY_CHANGE_TYPES <- c(
  "definition", "classification", "base_period", "coverage", "valuation", "compilation_method"
)
METHODOLOGY_COMPARABILITY <- c("comparable", "break_in_series", "spliced", "not_comparable")

# Every governance register in this project follows the same shape: an exact
# column contract, no partially filled rows, no duplicate keys, and a named
# reviewer with a parseable date on anything that asserts a reviewed fact.
documented_register_guard <- function(register, path_label, required, key_columns,
                                      reviewed_required = TRUE) {
  if (!identical(names(register), required)) stop(
    "Register guard: ", path_label, " columns changed or are reordered.", call. = FALSE
  )
  if (!nrow(register)) return(register)
  for (field in required) {
    if (any(is.na(register[[field]]) | !nzchar(trimws(register[[field]])))) stop(
      "Register guard: ", path_label, " requires ", field, " on every row.", call. = FALSE
    )
  }
  if (anyDuplicated(register[key_columns])) stop(
    "Register guard: ", path_label, " has duplicate ",
    paste(key_columns, collapse = "/"), " rows.", call. = FALSE
  )
  if (reviewed_required) {
    dates <- suppressWarnings(lubridate::ymd(register$reviewed_at, quiet = TRUE))
    if (any(is.na(dates))) stop(
      "Register guard: ", path_label, " requires reviewed_at as YYYY-MM-DD.", call. = FALSE
    )
    if (any(register$reviewed_by == "unreviewed")) stop(
      "Register guard: ", path_label, " requires a named reviewer.", call. = FALSE
    )
  }
  register
}

read_register_csv <- function(root, file_name) {
  path <- file.path(root, "config", file_name)
  if (!file.exists(path)) stop("Register not found: ", path, call. = FALSE)
  readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()))
}

apply_canonical_series <- function(con, root) {
  required <- c("canonical_series_id", "concept_id", "definition", "domain", "subdomain",
                "frequency", "unit_code", "currency", "stock_flow", "nominal_real",
                "seasonal_adjustment", "transformation", "valuation", "methodology_regime_id",
                "reviewed_status", "reviewed_by", "reviewed_at")
  series <- documented_register_guard(
    read_register_csv(root, "canonical_series.csv"), "config/canonical_series.csv",
    required, "canonical_series_id"
  )
  if (nrow(series)) {
    invalid <- setdiff(unique(series$reviewed_status), CANONICAL_REVIEW_STATUSES)
    if (length(invalid)) stop(
      "Canonical guard: unsupported reviewed_status: ", paste(invalid, collapse = "; "),
      call. = FALSE
    )
    # A canonical identifier must not be a parser identifier wearing a new name.
    if (any(series$canonical_series_id %in%
            DBI::dbGetQuery(con, "SELECT series_id FROM dim_series")$series_id)) stop(
      "Canonical guard: a canonical_series_id must not reuse a parsed series_id; the point ",
      "of the canonical layer is that it does not move when a parser does.", call. = FALSE
    )
  }
  members_required <- c("canonical_series_id", "series_id", "relationship", "evidence",
                        "reviewed_by", "reviewed_at")
  members <- documented_register_guard(
    read_register_csv(root, "canonical_series_members.csv"),
    "config/canonical_series_members.csv", members_required,
    c("canonical_series_id", "series_id")
  )
  if (nrow(members)) {
    invalid <- setdiff(unique(members$relationship), CANONICAL_RELATIONSHIPS)
    if (length(invalid)) stop(
      "Canonical guard: unsupported relationship: ", paste(invalid, collapse = "; "), call. = FALSE
    )
    unknown_canonical <- setdiff(members$canonical_series_id, series$canonical_series_id)
    if (length(unknown_canonical)) stop(
      "Canonical guard: member rows reference undeclared canonical series: ",
      paste(head(unknown_canonical, 5), collapse = "; "), call. = FALSE
    )
    # Members are resolved through the identity map, so a membership recorded
    # against an identifier a later parser repair superseded still binds.
    resolvable <- DBI::dbGetQuery(
      con, "SELECT DISTINCT published_series_id FROM v_series_id_resolution"
    )$published_series_id
    unknown_series <- setdiff(members$series_id, resolvable)
    if (length(unknown_series)) stop(
      "Canonical guard: member rows reference unknown series: ",
      paste(head(unknown_series, 5), collapse = "; "), call. = FALSE
    )
    # An identifier a later release split names several current series. Which of
    # them belongs to this canonical concept is an economic decision, so the
    # register has to state it rather than the view picking one.
    ambiguous <- DBI::dbGetQuery(con, paste(
      "SELECT DISTINCT published_series_id FROM v_series_id_resolution",
      "WHERE resolution_cardinality <> 'one_to_one'"
    ))$published_series_id
    ambiguous_members <- intersect(members$series_id, ambiguous)
    if (length(ambiguous_members)) stop(
      "Canonical guard: member rows are declared against identifier(s) that no longer name a ",
      "single series; re-declare them against the intended successor: ",
      paste(head(ambiguous_members, 5), collapse = "; "), call. = FALSE
    )
  }
  canonical_rows <- series %>% dplyr::mutate(
    reviewed_at = suppressWarnings(lubridate::ymd(.data$reviewed_at, quiet = TRUE))
  )
  member_rows <- members %>% dplyr::mutate(
    reviewed_at = suppressWarnings(lubridate::ymd(.data$reviewed_at, quiet = TRUE))
  )
  # The two tables are rewritten together or not at all: a membership row that
  # outlived its canonical series would reference nothing, and
  # validate_referential_integrity() would fail the release for it.
  canonical_changed <- !identical(
    content_fingerprint(DBI::dbGetQuery(con, "SELECT * FROM canonical_series")),
    content_fingerprint(canonical_rows)
  ) || !identical(
    content_fingerprint(DBI::dbGetQuery(con, "SELECT * FROM map_canonical_series")),
    content_fingerprint(member_rows)
  )
  if (canonical_changed) with_project_transaction(con, {
    DBI::dbExecute(con, "DELETE FROM map_canonical_series")
    DBI::dbExecute(con, "DELETE FROM canonical_series")
    if (nrow(canonical_rows)) DBI::dbWriteTable(con, "canonical_series", canonical_rows, append = TRUE)
    if (nrow(member_rows)) DBI::dbWriteTable(con, "map_canonical_series", member_rows, append = TRUE)
  })
  create_canonical_views(con)
  invisible(nrow(canonical_rows))
}

apply_methodology_regimes <- function(con, root) {
  required <- c("regime_id", "concept_key", "regime_label", "change_type", "effective_from",
                "effective_to", "comparability", "evidence", "reviewed_by", "reviewed_at")
  regimes <- read_register_csv(root, "methodology_regimes.csv")
  # effective_to is legitimately open for the current regime, so it is exempt
  # from the "no empty field" rule.
  if (!identical(names(regimes), required)) stop(
    "Register guard: config/methodology_regimes.csv columns changed or are reordered.",
    call. = FALSE
  )
  if (nrow(regimes)) {
    for (field in setdiff(required, "effective_to")) {
      if (any(is.na(regimes[[field]]) | !nzchar(trimws(regimes[[field]])))) stop(
        "Register guard: config/methodology_regimes.csv requires ", field, " on every row.",
        call. = FALSE
      )
    }
    if (anyDuplicated(regimes$regime_id)) stop(
      "Register guard: duplicate regime_id rows.", call. = FALSE
    )
    invalid <- setdiff(unique(regimes$change_type), METHODOLOGY_CHANGE_TYPES)
    if (length(invalid)) stop(
      "Methodology guard: unsupported change_type: ", paste(invalid, collapse = "; "), call. = FALSE
    )
    invalid <- setdiff(unique(regimes$comparability), METHODOLOGY_COMPARABILITY)
    if (length(invalid)) stop(
      "Methodology guard: unsupported comparability: ", paste(invalid, collapse = "; "), call. = FALSE
    )
    # A methodology break is a reviewed claim about when a definition changed,
    # and carries the same evidence burden as every other register here.
    if (any(regimes$reviewed_by == "unreviewed")) stop(
      "Register guard: config/methodology_regimes.csv requires a named reviewer.", call. = FALSE
    )
    dates <- suppressWarnings(lubridate::ymd(regimes$reviewed_at, quiet = TRUE))
    if (any(is.na(dates))) stop(
      "Register guard: config/methodology_regimes.csv requires reviewed_at as YYYY-MM-DD.",
      call. = FALSE
    )
  }
  rows <- regimes %>% dplyr::mutate(
    effective_from = suppressWarnings(lubridate::ymd(.data$effective_from, quiet = TRUE)),
    effective_to = suppressWarnings(lubridate::ymd(.data$effective_to, quiet = TRUE)),
    reviewed_at = suppressWarnings(lubridate::ymd(.data$reviewed_at, quiet = TRUE))
  )
  replace_table_if_changed(con, "methodology_regime", rows)
  invisible(nrow(rows))
}

apply_classification_concordance <- function(con, root) {
  required <- c("concordance_id", "from_scheme", "from_code", "to_scheme", "to_code",
                "relationship", "evidence", "reviewed_by", "reviewed_at")
  concordance <- documented_register_guard(
    read_register_csv(root, "classification_concordance.csv"),
    "config/classification_concordance.csv", required, "concordance_id"
  )
  rows <- concordance %>% dplyr::mutate(
    reviewed_at = suppressWarnings(lubridate::ymd(.data$reviewed_at, quiet = TRUE))
  )
  replace_table_if_changed(con, "classification_concordance", rows)
  invisible(nrow(rows))
}

# The continuity register had a table, a storage assignment and a release-gate
# presence check, and no writer anywhere in the project -- so it could not be
# populated even by a reviewer who had done the work. It is the register that
# says a concept survived a break: when a definition, a classification or a
# base period changed, which prior series continues into which successor, and
# whether the two may be spliced or only compared.
#
# It is deliberately separate from series_id_migration, which records that a
# parser repair renamed an identifier. That is a fact about this project's
# identifiers and is derived. This is a claim about the economy and is reviewed.
CONTINUITY_RELATIONSHIPS <- c("continues", "replaces", "splits_into", "merges_into")
CONTINUITY_OVERLAP_RULES <- c(
  "direct_splice", "ratio_splice_on_overlap", "level_shift_on_overlap",
  "no_splice_compare_only"
)

apply_continuity_decisions <- function(con, root) {
  required <- c("continuity_id", "concept_key", "from_series_id", "to_series_id",
                "relationship", "overlap_rule", "evidence", "reviewed_by", "reviewed_at")
  decisions <- documented_register_guard(
    read_register_csv(root, "continuity_decisions.csv"),
    "config/continuity_decisions.csv", required, "continuity_id"
  )
  if (nrow(decisions)) {
    invalid <- setdiff(unique(decisions$relationship), CONTINUITY_RELATIONSHIPS)
    if (length(invalid)) stop(
      "Continuity guard: unsupported relationship(s): ", paste(invalid, collapse = "; "),
      ". Allowed: ", paste(CONTINUITY_RELATIONSHIPS, collapse = ", "), ".", call. = FALSE
    )
    invalid_rule <- setdiff(unique(decisions$overlap_rule), CONTINUITY_OVERLAP_RULES)
    if (length(invalid_rule)) stop(
      "Continuity guard: unsupported overlap_rule(s): ", paste(invalid_rule, collapse = "; "),
      ". Allowed: ", paste(CONTINUITY_OVERLAP_RULES, collapse = ", "), ".", call. = FALSE
    )
    # Both sides must still name exactly one live series, resolved through the
    # migration map for the same reason canonical membership is: a continuity
    # decision recorded against an identifier a later repair split would
    # otherwise silently widen to every successor.
    resolution <- DBI::dbGetQuery(con, paste(
      "SELECT published_series_id, resolution_cardinality FROM",
      project_qualified_name("v_series_id_resolution")
    ))
    scalar <- resolution$published_series_id[resolution$resolution_cardinality == "one_to_one"]
    declared <- unique(c(decisions$from_series_id, decisions$to_series_id))
    unknown <- setdiff(declared, scalar)
    if (length(unknown)) stop(
      "Continuity guard: ", length(unknown), " declared identifier(s) do not resolve to exactly ",
      "one current series: ", paste(head(unknown, 5), collapse = "; "), call. = FALSE
    )
  }
  rows <- decisions %>% dplyr::mutate(
    reviewed_at = suppressWarnings(lubridate::ymd(.data$reviewed_at, quiet = TRUE))
  )
  replace_table_if_changed(con, "continuity_map", rows)
  invisible(nrow(rows))
}

create_canonical_views <- function(con) {
  # Membership is resolved through v_series_id_resolution, so a canonical series
  # keeps its members across a parser repair that renamed them -- but only where
  # the identifier still names one series. A member declared under an identifier
  # a later release split resolves to several candidates, and silently admitting
  # all of them would quietly widen what the canonical series means. Those are
  # excluded here and reported by apply_canonical_series() so a reviewer
  # re-declares the membership against the successor they actually meant.
  create_project_view(con, "v_canonical_membership", paste(
    "SELECT m.canonical_series_id, m.relationship, r.current_series_id AS series_id,",
    "m.series_id AS declared_series_id, m.reviewed_by, m.reviewed_at",
    "FROM map_canonical_series m",
    "JOIN v_series_id_resolution r ON r.published_series_id = m.series_id",
    "WHERE r.current_series_id IS NOT NULL AND r.resolution_cardinality = 'one_to_one'"
  ))
  create_project_view(con, "v_canonical_series_catalogue", paste(
    "SELECT c.*, count(m.series_id) AS member_series,",
    "min(o.period_start) AS first_period, max(o.period_end) AS last_period,",
    "count(o.value) AS observations",
    "FROM canonical_series c",
    "LEFT JOIN v_canonical_membership m ON m.canonical_series_id = c.canonical_series_id",
    "LEFT JOIN v_series_observations o ON o.series_id = m.series_id AND NOT o.is_deleted",
    "GROUP BY ALL"
  ))
  create_project_view(con, "v_canonical_observations", paste(
    "SELECT m.canonical_series_id, m.relationship, o.*",
    "FROM v_canonical_membership m JOIN v_series_observations o USING (series_id)",
    "WHERE NOT o.is_deleted"
  ))
  invisible(TRUE)
}

# --- A reviewer's worksheet for the canonical core ---------------------------
# The registers ship empty on purpose, and this does not change that. What it
# changes is the cost of filling them: the reason nobody has is that choosing a
# canonical series means finding the candidates first, and the candidates are
# spread over 94 Annex worksheets whose labels are Spanish prose.
#
# So the candidates are generated, from live queries, every release: for each
# macro concept the project would need, every series whose published label could
# plausibly be it, with the worksheet, frequency, unit, span and observation
# count beside it. A reviewer then chooses from a menu and records why, instead
# of searching. Nothing here is a claim -- a row in this file asserts only that
# the label matched a pattern, which is exactly the kind of evidence the concept
# governance says is not sufficient on its own.
CANONICAL_CORE_CANDIDATES <- list(
  gdp_total            = list(subdomains = c("gdp_by_activity", "quarterly_gdp_by_activity"),
                              pattern = "producto interno bruto|^pib"),
  gdp_expenditure      = list(subdomains = c("gdp_by_expenditure", "quarterly_gdp_by_expenditure"),
                              pattern = "producto interno bruto|consumo final|formacion bruta"),
  activity_index       = list(subdomains = "imaep", pattern = "imaep"),
  consumer_prices      = list(subdomains = c("consumer_prices", "inflation_headline_and_core"),
                              pattern = "ipc|nivel general|inflacion"),
  producer_prices      = list(subdomains = "producer_prices", pattern = "ipp|productor"),
  monetary_aggregates  = list(subdomains = "monetary_aggregates",
                              pattern = "^m[0-3]$|base monetaria|circulacion"),
  interest_rates       = list(subdomains = c("interest_rates", "monetary_policy_instruments"),
                              pattern = "tasa de politica|tpm|call|interbancari|activas|pasivas"),
  credit_and_deposits  = list(subdomains = c("credit", "deposits", "credit_and_deposits"),
                              pattern = "total|credito|deposito"),
  exchange_rate        = list(subdomains = c("nominal_exchange_rate", "real_effective_exchange_rate"),
                              pattern = "tipo de cambio|nominal|efectivo|indice"),
  reserves             = list(subdomains = "net_international_reserves",
                              pattern = "reserva|neta|bruta"),
  trade                = list(subdomains = c("exports_by_processing_level", "exports_by_customs_regime"),
                              pattern = "^total$"),
  balance_of_payments  = list(subdomains = c("current_account", "bop_analytical_presentation"),
                              pattern = "cuenta corriente|balanza|saldo"),
  fiscal               = list(subdomains = "central_government_budget_execution",
                              pattern = "ingreso total|gastos total|resultado"),
  external_debt        = list(subdomains = "public_external_debt", pattern = "total|saldo"),
  labour               = list(subdomains = c("minimum_wage", "wages_and_salaries"),
                              pattern = "salario minimo|salario")
)

write_canonical_core_proposal <- function(con, root, per_concept = 12L) {
  if (is.null(root)) return(invisible(NULL))
  if (!database_object_exists(con, "table_domains")) return(invisible(NULL))
  rows <- list()
  for (concept in names(CANONICAL_CORE_CANDIDATES)) {
    rule <- CANONICAL_CORE_CANDIDATES[[concept]]
    subdomains <- paste(vapply(rule$subdomains, sql_string, character(1)), collapse = ", ")
    found <- tryCatch(DBI::dbGetQuery(con, paste(
      "SELECT", sql_string(concept), "AS proposed_concept, t.domain, t.subdomain,",
      "n.source_id, n.source_sheet, d.series_id, d.label, d.frequency, d.unit_code,",
      "d.identity_stability, min(f.period) AS first_period, max(f.period) AS last_period,",
      "count(*) AS observations",
      "FROM", project_qualified_name("dim_series"), "d",
      "JOIN (SELECT DISTINCT series_id, source_id, source_sheet FROM",
      project_qualified_name("documented_series_snapshot"), ") n USING (series_id)",
      "JOIN", project_qualified_name("table_domains"), "t",
      "  ON t.source_id = n.source_id AND t.source_sheet = n.source_sheet",
      "JOIN", project_qualified_name("fact_series_events"), "f",
      "  ON f.series_id = d.series_id AND NOT f.is_deleted",
      "WHERE t.subdomain IN (", subdomains, ")",
      "AND regexp_matches(strip_accents(lower(d.label)),", sql_string(rule$pattern), ")",
      "GROUP BY ALL ORDER BY observations DESC LIMIT", as.integer(per_concept)
    )), error = function(e) NULL)
    if (!is.null(found) && nrow(found)) rows[[concept]] <- found
  }
  candidates <- dplyr::bind_rows(rows)
  readr::write_csv(candidates, file.path(root, "outputs", "canonical_core_candidates.csv"))
  invisible(candidates)
}

apply_governance_registers <- function(con, root) {
  apply_methodology_regimes(con, root)
  apply_classification_concordance(con, root)
  apply_continuity_decisions(con, root)
  apply_canonical_series(con, root)
  write_duplicate_series_candidates(con, root)
  invisible(TRUE)
}

# The audit's F-14 and its section 7, as a reproducible screen rather than a
# finding in a document.
#
# Two series that carry the same value on the same dates over a long history are
# not automatically one concept, and the audit is careful about this: 916 of the
# insurance series share a signature because their reported histories are all
# zero, and payments transfers to and from the ministry match because both are
# zero throughout. Direction, institution class and rate basis are economically
# material and identical values do not erase them.
#
# So this adjudicates nothing. It ranks the candidates by how much evidence there
# is -- how many periods agree, and whether the agreement is on anything other
# than zero -- so an economist works down a list instead of discovering the
# duplication in a regression. The one case the evidence settles on its own is
# reported first: an Annex series matching a dedicated source series over 379
# monthly observations of varying values is the same figure published twice.
DUPLICATE_SIGNATURE_MINIMUM_PERIODS <- 6L

write_duplicate_series_candidates <- function(con, root, minimum_periods = DUPLICATE_SIGNATURE_MINIMUM_PERIODS) {
  if (is.null(root) || !database_object_exists(con, "fact_series_events")) return(invisible(NULL))
  candidates <- tryCatch(DBI::dbGetQuery(con, paste(
    "WITH signature AS (",
    "  SELECT f.series_id,",
    "         count(*) AS periods,",
    "         max(abs(f.value)) AS largest_absolute_value,",
    "         md5(string_agg(CAST(f.period AS VARCHAR) || ':' || CAST(f.value AS VARCHAR),",
    "                        '|' ORDER BY f.period)) AS value_signature",
    "  FROM", project_qualified_name("fact_series_events"), "f",
    "  WHERE NOT f.is_deleted GROUP BY 1",
    "  HAVING count(*) >=", as.integer(minimum_periods),
    "), grouped AS (",
    "  SELECT value_signature, periods, count(*) AS series_in_group,",
    "         max(largest_absolute_value) AS largest_absolute_value,",
    "         string_agg(DISTINCT series_id, ' | ') AS series_ids",
    "  FROM signature GROUP BY 1, 2 HAVING count(*) > 1",
    ")",
    "SELECT g.value_signature, g.periods, g.series_in_group, g.series_ids,",
    "       g.largest_absolute_value = 0 AS zero_only_history,",
    "       string_agg(DISTINCT d.source_id, ' | ') AS sources",
    "FROM grouped g",
    "JOIN", project_qualified_name("dim_series"), "d",
    "  ON list_contains(str_split(g.series_ids, ' | '), d.series_id)",
    "GROUP BY ALL ORDER BY g.largest_absolute_value = 0, g.periods DESC, g.series_in_group DESC"
  )), error = function(e) NULL)
  if (is.null(candidates)) return(invisible(NULL))
  # A group spanning two sources with a non-zero history is the strongest kind of
  # evidence and the only kind that ever settles a case by itself.
  candidates$cross_source <- grepl(" | ", candidates$sources, fixed = TRUE)
  readr::write_csv(candidates, file.path(root, "outputs", "duplicate_series_candidates.csv"))
  invisible(candidates)
}

# The audit's P1 test for canonical membership: for members of one concept,
# measure overlap, exact agreement and tolerance breaches. It fires only where
# somebody has recorded a membership, so it passes vacuously today and is what
# makes the first mapping safe to record.
validate_canonical_membership_agreement <- function(con, release_id, tolerance = 1e-9) {
  if (!database_object_exists(con, "map_canonical_series")) return(invisible(FALSE))
  disagreements <- tryCatch(DBI::dbGetQuery(con, paste(
    "WITH primary_series AS (",
    "  SELECT canonical_series_id, series_id FROM", project_qualified_name("map_canonical_series"),
    "  WHERE relationship = 'primary'",
    "), alias_series AS (",
    "  SELECT canonical_series_id, series_id FROM", project_qualified_name("map_canonical_series"),
    "  WHERE relationship = 'alias'",
    ")",
    "SELECT p.canonical_series_id, a.series_id AS alias_series_id,",
    "       count(*) AS overlapping_periods,",
    "       count(*) FILTER (WHERE abs(pf.value - af.value) >", tolerance, ") AS disagreeing_periods",
    "FROM primary_series p JOIN alias_series a USING (canonical_series_id)",
    "JOIN", project_qualified_name("fact_series_events"), "pf ON pf.series_id = p.series_id",
    "JOIN", project_qualified_name("fact_series_events"), "af",
    "  ON af.series_id = a.series_id AND af.period = pf.period",
    "WHERE NOT pf.is_deleted AND NOT af.is_deleted",
    "GROUP BY 1, 2 HAVING count(*) FILTER (WHERE abs(pf.value - af.value) >", tolerance, ") > 0"
  )), error = function(e) NULL)
  if (!is.null(disagreements) && nrow(disagreements)) {
    insert_quality_flag(
      con, release_id, "error", "canonical_alias_disagrees", NA_character_,
      paste0(
        nrow(disagreements), " canonical alias(es) disagree with their primary series on periods ",
        "where both publish a value, so they are not the same figure and the membership is wrong: ",
        paste(head(paste0(
          disagreements$canonical_series_id, " vs ", disagreements$alias_series_id, " (",
          disagreements$disagreeing_periods, " of ", disagreements$overlapping_periods, ")"
        ), 5), collapse = "; ")
      )
    )
    return(invisible(FALSE))
  }
  validate_canonical_membership_comparability(con, release_id)
}

# The audit's test 8, the part value equality does not cover.
#
# Two series can agree on every overlapping period and still not be the same
# economic quantity: one in millions and one in units agree at zero, a monthly
# and a quarterly series agree wherever the quarter ends, and an alias that never
# overlaps its primary at all agrees vacuously. Declaring a membership is
# asserting comparability, so the release asserts it too.
validate_canonical_membership_comparability <- function(con, release_id) {
  if (!database_object_exists(con, "map_canonical_series")) return(invisible(FALSE))
  members <- tryCatch(DBI::dbGetQuery(con, paste(
    "SELECT m.canonical_series_id, m.relationship, m.series_id,",
    "d.unit_code, d.scale_multiplier, d.frequency, d.stock_flow, d.nominal_real",
    "FROM", project_qualified_name("map_canonical_series"), "m",
    "JOIN", project_qualified_name("dim_series"), "d USING (series_id)"
  )), error = function(e) NULL)
  if (is.null(members) || !nrow(members)) return(invisible(TRUE))
  problems <- character()
  for (canonical in unique(members$canonical_series_id)) {
    group <- members[members$canonical_series_id == canonical, , drop = FALSE]
    # A fragment covers a different span by definition, so only aliases are held
    # to the frequency and unit of their primary.
    comparable <- group[group$relationship %in% c("primary", "alias"), , drop = FALSE]
    if (nrow(comparable) < 2L) next
    for (field in c("unit_code", "scale_multiplier", "frequency")) {
      values <- unique(comparable[[field]])
      if (length(values) > 1L) problems <- c(problems, paste0(
        canonical, " declares aliases differing in ", field, " (",
        paste(values, collapse = " vs "), ")"
      ))
    }
  }
  # An alias with no overlapping period has never been tested against its primary.
  vacuous <- tryCatch(DBI::dbGetQuery(con, paste(
    "WITH p AS (SELECT canonical_series_id, series_id FROM",
    project_qualified_name("map_canonical_series"), "WHERE relationship = 'primary'),",
    "a AS (SELECT canonical_series_id, series_id FROM",
    project_qualified_name("map_canonical_series"), "WHERE relationship = 'alias')",
    "SELECT p.canonical_series_id, a.series_id AS alias_series_id",
    "FROM p JOIN a USING (canonical_series_id)",
    "WHERE NOT EXISTS (",
    "  SELECT 1 FROM", project_qualified_name("fact_series_events"), "pf",
    "  JOIN", project_qualified_name("fact_series_events"), "af",
    "    ON af.series_id = a.series_id AND af.period = pf.period AND NOT af.is_deleted",
    "  WHERE pf.series_id = p.series_id AND NOT pf.is_deleted)"
  )), error = function(e) NULL)
  if (!is.null(vacuous) && nrow(vacuous)) problems <- c(problems, paste0(
    nrow(vacuous), " alias(es) share no period with their primary, so the equality that ",
    "justifies the membership has never been tested: ",
    paste(head(paste0(vacuous$canonical_series_id, "/", vacuous$alias_series_id), 3), collapse = "; ")
  ))
  if (!length(problems)) return(invisible(TRUE))
  insert_quality_flag(
    con, release_id, "error", "canonical_membership_incomparable", NA_character_,
    paste0(
      "A declared canonical membership asserts the members are the same economic quantity, and ",
      "these are not comparable as declared: ", paste(head(problems, 5), collapse = "; ")
    )
  )
  invisible(FALSE)
}

# The audit's test 11, and its R6-09.
#
# The direct panels have unique physical keys and 411 groups of rows that repeat
# every dimension the database models -- INHAB/REHAB pairs, conflicting totals
# published on separate lines. Physical identity is not economic identity, and
# summing a panel whose rows are not economically distinguished double-counts by
# an amount nobody can bound. The rows are kept, the duplicates are reported, and
# the panel stays out of any aggregate mart until someone identifies the missing
# dimension from the publisher's documentation.
validate_direct_panel_aggregation_safety <- function(con, release_id) {
  panels <- DBI::dbGetQuery(con, paste(
    "SELECT table_name FROM information_schema.tables",
    "WHERE table_schema = 'raw' AND table_name LIKE 'raw\\_%' ESCAPE '\\'"
  ))$table_name
  if (!length(panels)) return(invisible(TRUE))
  marts <- DBI::dbGetQuery(con, paste(
    "SELECT view_name, sql FROM duckdb_views() WHERE schema_name = 'marts' AND NOT internal"
  ))
  if (!nrow(marts)) return(invisible(TRUE))
  reached <- marts$view_name[vapply(marts$sql, function(body) any(vapply(
    panels, function(panel) grepl(panel, body, fixed = TRUE), logical(1)
  )), logical(1))]
  if (!length(reached)) return(invisible(TRUE))
  insert_quality_flag(
    con, release_id, "error", "direct_panel_in_aggregate_mart", NA_character_,
    paste0(
      length(reached), " mart view(s) read a direct publisher panel: ",
      paste(sort(reached), collapse = ", "),
      ". Those panels contain rows that repeat every modelled dimension, so aggregating them ",
      "double-counts. See outputs/direct_panel_duplicate_keys.csv; the missing dimension has to ",
      "come from the publisher's documentation before a mart may use the panel."
    )
  )
  invisible(FALSE)
}
