source_concept_id <- function(series_id) paste0(
  "concept:source:", substr(digest::digest(series_id, algo = "sha256", serialize = FALSE), 1L, 24L)
)

sync_source_specific_concepts <- function(con) {
  if (!DBI::dbExistsTable(con, "dim_series") || !DBI::dbExistsTable(con, "dim_concept")) return(invisible(0L))
  series <- DBI::dbGetQuery(con, paste(
    "SELECT s.* FROM dim_series s LEFT JOIN map_series_concept m ON s.series_id = m.series_id",
    "WHERE m.series_id IS NULL"
  ))
  if (!nrow(series)) return(invisible(0L))
  concept_ids <- vapply(series$series_id, source_concept_id, character(1))
  concepts <- series %>% dplyr::transmute(
    concept_id = concept_ids,
    concept_label = .data$label, concept_domain = .data$source_id,
    definition = paste("Source-specific concept for", .data$series_id),
    unit = .data$unit, scale = .data$scale, frequency = .data$frequency,
    mapping_status = "source_specific_unreviewed", first_vintage_id = .data$first_vintage_id
  )
  mappings <- series %>% dplyr::transmute(
    series_id, concept_id = concept_ids,
    relationship = "source_identity", mapping_status = "source_specific_unreviewed",
    evidence = "Generated one-to-one from dim_series; no cross-source equivalence asserted.",
    reviewed_by = NA_character_, reviewed_at = as.Date(NA), first_vintage_id
  )
  DBI::dbWriteTable(con, "dim_concept", concepts, append = TRUE)
  DBI::dbWriteTable(con, "map_series_concept", mappings, append = TRUE)
  invisible(nrow(mappings))
}

read_reviewed_concept_mappings <- function(root) {
  path <- file.path(root, "config", "concept_mappings.csv")
  required <- c("concept_id", "concept_label", "concept_domain", "definition", "series_id",
                "relationship", "evidence", "reviewed_by", "reviewed_at")
  if (!file.exists(path)) stop("Concept mapping configuration not found: ", path, call. = FALSE)
  mappings <- readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()))
  if (!identical(names(mappings), required)) stop(
    "Concept mapping guard: config/concept_mappings.csv columns changed or are reordered.", call. = FALSE
  )
  mappings
}

apply_reviewed_concept_mappings <- function(con, root) {
  sync_source_specific_concepts(con)
  mappings <- read_reviewed_concept_mappings(root)
  if (!nrow(mappings)) {
    with_project_transaction(con, {
      DBI::dbExecute(con, "DELETE FROM map_series_concept WHERE mapping_status = 'reviewed'")
      DBI::dbExecute(con, "DELETE FROM dim_concept WHERE mapping_status = 'reviewed'")
    })
    create_concept_views(con)
    return(invisible(0L))
  }
  required_values <- c("concept_id", "concept_label", "concept_domain", "definition", "series_id",
                       "relationship", "evidence", "reviewed_by", "reviewed_at")
  incomplete <- Reduce(`|`, lapply(required_values, function(x) is.na(mappings[[x]]) | !nzchar(trimws(mappings[[x]]))))
  if (any(incomplete)) stop("Concept mapping guard: every reviewed row requires identifiers, evidence, reviewer and review date.", call. = FALSE)
  if (anyDuplicated(mappings[c("series_id", "concept_id")])) stop(
    "Concept mapping guard: duplicate series_id/concept_id rows.", call. = FALSE
  )
  allowed_relationships <- c("equivalent", "component", "aggregate", "benchmark", "related")
  invalid_relationships <- setdiff(unique(mappings$relationship), allowed_relationships)
  if (length(invalid_relationships)) stop(
    "Concept mapping guard: unsupported relationship(s): ", paste(invalid_relationships, collapse = "; "), call. = FALSE
  )
  if (any(stringr::str_starts(mappings$concept_id, "concept:source:"))) stop(
    "Concept mapping guard: concept:source: is reserved for generated source identities.", call. = FALSE
  )
  concept_contracts <- mappings %>% dplyr::group_by(.data$concept_id) %>% dplyr::summarise(
    labels = dplyr::n_distinct(.data$concept_label), domains = dplyr::n_distinct(.data$concept_domain),
    definitions = dplyr::n_distinct(.data$definition), .groups = "drop"
  )
  if (any(concept_contracts$labels > 1L | concept_contracts$domains > 1L | concept_contracts$definitions > 1L)) stop(
    "Concept mapping guard: each concept_id must have one label, domain and definition.", call. = FALSE
  )
  reviewed_dates <- suppressWarnings(lubridate::ymd(mappings$reviewed_at, quiet = TRUE))
  if (any(is.na(reviewed_dates))) stop("Concept mapping guard: reviewed_at must use valid YYYY-MM-DD dates.", call. = FALSE)
  known <- DBI::dbGetQuery(con, "SELECT series_id, unit, scale, frequency, first_vintage_id FROM dim_series")
  missing_series <- setdiff(mappings$series_id, known$series_id)
  if (length(missing_series)) stop("Concept mapping guard: unknown series_id(s): ", paste(missing_series, collapse = "; "), call. = FALSE)
  equivalent <- mappings %>% dplyr::filter(.data$relationship == "equivalent") %>%
    dplyr::left_join(known, by = "series_id") %>%
    dplyr::group_by(.data$concept_id) %>%
    dplyr::summarise(contracts = dplyr::n_distinct(paste(.data$unit, .data$scale, .data$frequency, sep = "|")), .groups = "drop")
  if (any(equivalent$contracts > 1L)) stop(
    "Concept mapping guard: equivalent series must have identical unit, scale and frequency contracts.", call. = FALSE
  )
  concepts <- mappings %>% dplyr::left_join(known, by = "series_id") %>% dplyr::group_by(.data$concept_id) %>%
    dplyr::summarise(
      concept_label = dplyr::first(.data$concept_label), concept_domain = dplyr::first(.data$concept_domain),
      definition = dplyr::first(.data$definition), unit = dplyr::first(.data$unit),
      scale = dplyr::first(.data$scale), frequency = dplyr::first(.data$frequency),
      mapping_status = "reviewed", first_vintage_id = dplyr::first(.data$first_vintage_id), .groups = "drop"
    )
  reviewed <- mappings %>% dplyr::left_join(known %>% dplyr::select(.data$series_id, .data$first_vintage_id), by = "series_id") %>% dplyr::transmute(
    series_id, concept_id, relationship, mapping_status = "reviewed", evidence, reviewed_by,
    reviewed_at = as.Date(.data$reviewed_at),
    first_vintage_id
  )
  with_project_transaction(con, {
    DBI::dbExecute(con, "DELETE FROM map_series_concept WHERE mapping_status = 'reviewed'")
    DBI::dbExecute(con, "DELETE FROM dim_concept WHERE mapping_status = 'reviewed'")
    DBI::dbWriteTable(con, "dim_concept", concepts, append = TRUE)
    DBI::dbWriteTable(con, "map_series_concept", reviewed, append = TRUE)
  })
  create_concept_views(con)
  invisible(nrow(reviewed))
}

# --- Research-readiness gate ------------------------------------------------
# The audit's P0 asks for an explicit allowlist so the generic catalogue is not
# exposed as research-ready. config/table_status.csv carries one reviewed status
# per source table; v_research_series exposes only what has been reviewed.
#
# The four statuses are deliberately narrow:
#   validated        an economist has reviewed the table's definitions, units,
#                    period conventions and hierarchy. Only these reach
#                    v_research_series. No automated check can grant this.
#   provisional      parses cleanly and passes the automated gates, but has had
#                    no economic review. The default for everything.
#   needs_remodeling values are believed right but the identities are not usable
#                    for research (missing source dimensions).
#   quarantined      proven defective; excluded from every research-facing view.
TABLE_STATUS_VALUES <- c("validated", "provisional", "needs_remodeling", "quarantined")

# The audit's P0 asks that a table family be promoted only "after economic review
# with named reviewer, date, definitions, units, timing, hierarchy, and
# methodology evidence". A single reviewer name cannot carry that claim, so each
# question is recorded separately: a validated row must state what was checked
# for each, and evidence_uri must point at the publication or note relied on.
# For any status other than validated these stay blank -- they document a
# completed review, not an aspiration.
TABLE_STATUS_EVIDENCE_COLUMNS <- c(
  "definitions_reviewed", "units_reviewed", "timing_reviewed",
  "hierarchy_reviewed", "methodology_reviewed", "evidence_uri"
)

# --- Governance drift -------------------------------------------------------
# The audit found eight table_status notes still describing a defect the release
# had already fixed: they claimed the interannual comparison block was being read
# as time periods, months after schema 14 bounded it out of the period axis. A
# note is the only prose a reviewer reads before deciding whether to trust a
# table, so a stale one is worse than no note at all -- it argues against data
# that is now correct, and it makes every other note less believable.
#
# The failure mode is structural, not clerical: a note is written once and the
# database moves on underneath it. So each row states its parser claim in a
# closed vocabulary, and the claim is checked against the reconciliation the same
# release computed. The prose stays free -- it is for the reader -- and is never
# pattern-matched, because a check that guesses at prose fires on notes that
# merely mention a defect they are denying, and gets switched off within a week.
#
# Three claims, each with an exact counterpart in table_reconciliation:
#
#   none          the parser reads this worksheet completely. Contradicted by any
#                 unread or unclassified cell.
#   unread_cells  published cells are not being read. Contradicted by a balanced
#                 reconciliation, which says they now are.
#   cell_reuse    one source cell is feeding several observations. Contradicted
#                 by cell_reuse of zero.
#
# A worksheet that is merely unmodelled -- dimensions in the row label, hierarchy
# not encoded -- claims 'none'. Those are real reasons to withhold validation and
# the note should say so, but they are not claims about the parser and the
# accounting cannot speak to them.
TABLE_STATUS_PARSER_CLAIMS <- c("none", "unread_cells", "cell_reuse")

read_table_status <- function(root) {
  path <- file.path(root, "config", "table_status.csv")
  required <- c("source_id", "source_sheet", "status", "parser_claim", "reviewed_by",
                "reviewed_at", "note", TABLE_STATUS_EVIDENCE_COLUMNS)
  if (!file.exists(path)) stop("Table status configuration not found: ", path, call. = FALSE)
  status <- readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()))
  if (!identical(names(status), required)) stop(
    "Table status guard: config/table_status.csv columns changed or are reordered.", call. = FALSE
  )
  status
}

apply_table_status <- function(con, root) {
  status <- read_table_status(root)
  for (field in c("source_id", "source_sheet", "status")) {
    if (any(is.na(status[[field]]) | !nzchar(trimws(status[[field]])))) stop(
      "Table status guard: ", field, " is required on every row.", call. = FALSE
    )
  }
  invalid <- setdiff(unique(status$status), TABLE_STATUS_VALUES)
  if (length(invalid)) stop(
    "Table status guard: unsupported status value(s): ", paste(invalid, collapse = "; "),
    ". Allowed: ", paste(TABLE_STATUS_VALUES, collapse = ", "), ".", call. = FALSE
  )
  status$parser_claim <- dplyr::coalesce(status$parser_claim, "none")
  invalid <- setdiff(unique(status$parser_claim), TABLE_STATUS_PARSER_CLAIMS)
  if (length(invalid)) stop(
    "Table status guard: unsupported parser_claim value(s): ", paste(invalid, collapse = "; "),
    ". Allowed: ", paste(TABLE_STATUS_PARSER_CLAIMS, collapse = ", "), ".", call. = FALSE
  )
  if (anyDuplicated(status[c("source_id", "source_sheet")])) stop(
    "Table status guard: duplicate source_id/source_sheet rows.", call. = FALSE
  )
  # A validated row is a claim about economic review, so it carries the same
  # evidence burden as a reviewed concept mapping.
  validated <- status$status == "validated"
  if (any(validated & (is.na(status$reviewed_by) | !nzchar(trimws(status$reviewed_by)) |
                       status$reviewed_by == "unreviewed"))) stop(
    "Table status guard: every validated table requires a named reviewer.", call. = FALSE
  )
  if (any(validated)) {
    dates <- suppressWarnings(lubridate::ymd(status$reviewed_at[validated], quiet = TRUE))
    if (any(is.na(dates))) stop(
      "Table status guard: validated tables require a reviewed_at date (YYYY-MM-DD).", call. = FALSE
    )
    for (field in TABLE_STATUS_EVIDENCE_COLUMNS) {
      if (any(is.na(status[[field]][validated]) | !nzchar(trimws(status[[field]][validated])))) stop(
        "Table status guard: every validated table requires ", field,
        ". Promotion is an economic-review claim, not a parser outcome.", call. = FALSE
      )
    }
    unbalanced <- unreconciled_table_families(con, status[validated, , drop = FALSE])
    if (length(unbalanced)) stop(
      "Table status guard: cannot validate table(s) whose source-to-target reconciliation does ",
      "not balance: ", paste(unbalanced, collapse = "; "), call. = FALSE
    )
  }
  # Validate against the registry, not against source_files: the configuration
  # legitimately declares a status for every registered source, while any single
  # run may have ingested only some of them. The opposite direction -- a source
  # present in the database with no declared status -- is the one that matters,
  # and validate_database() raises it as table_status_incomplete.
  registry_path <- file.path(root, "config", "source_registry.csv")
  if (file.exists(registry_path)) {
    registered <- readr::read_csv(registry_path, show_col_types = FALSE)$source_id
    unknown <- setdiff(unique(status$source_id), registered)
    if (length(unknown)) stop(
      "Table status guard: unknown source_id(s): ", paste(unknown, collapse = "; "), call. = FALSE
    )
  }
  rows <- status %>% dplyr::transmute(
    source_id, source_sheet, status, parser_claim,
    reviewed_by = dplyr::coalesce(.data$reviewed_by, "unreviewed"),
    reviewed_at = suppressWarnings(lubridate::ymd(.data$reviewed_at, quiet = TRUE)),
    note,
    definitions_reviewed, units_reviewed, timing_reviewed,
    hierarchy_reviewed, methodology_reviewed, evidence_uri
  )
  replace_table_if_changed(con, "table_status", rows)
  create_table_status_views(con)
  invisible(nrow(rows))
}

# --- Economic classification of the Statistical Annex ------------------------
# The audit's P1: "create reviewed domain/subdomain and measure classifications
# for all 93 Statistical Annex table/sheet identifiers". Series count is a poor
# guide to economic breadth -- the detailed trade layouts produce 85% of the
# Annex identifiers but the macroeconomic core is elsewhere -- so the Annex needs
# an organising layer that is independent of how many identities a worksheet
# happens to emit.
#
# The shipped assignment is derived from the published table titles and is
# recorded as unreviewed. It is a navigational index, not a certification: it
# says where a table belongs, never that its definitions or units were checked.
# That remains the job of table_status.
TABLE_DOMAIN_MEASURE_FAMILIES <- c(
  "level", "flow", "growth", "structure", "index", "rate", "ratio", "price",
  "unknown", "not_applicable"
)

read_table_domains <- function(root) {
  path <- file.path(root, "config", "table_domains.csv")
  required <- c("source_id", "source_sheet", "domain", "subdomain", "measure_family",
                "reviewed_by", "reviewed_at", "note")
  if (!file.exists(path)) stop("Table domain configuration not found: ", path, call. = FALSE)
  # trim_ws must stay off: three Annex worksheets are published with a trailing
  # space in their name ("CUADRO 10 "), and that space is part of the identity
  # the observations carry. Trimming it here silently detaches those sheets from
  # their classification.
  domains <- readr::read_csv(
    path, col_types = readr::cols(.default = readr::col_character()), trim_ws = FALSE
  )
  if (!identical(names(domains), required)) stop(
    "Table domain guard: config/table_domains.csv columns changed or are reordered.", call. = FALSE
  )
  domains
}

apply_table_domains <- function(con, root) {
  domains <- read_table_domains(root)
  for (field in c("source_id", "source_sheet", "domain", "subdomain", "measure_family")) {
    if (any(is.na(domains[[field]]) | !nzchar(trimws(domains[[field]])))) stop(
      "Table domain guard: ", field, " is required on every row.", call. = FALSE
    )
  }
  invalid <- setdiff(unique(domains$measure_family), TABLE_DOMAIN_MEASURE_FAMILIES)
  if (length(invalid)) stop(
    "Table domain guard: unsupported measure_family value(s): ", paste(invalid, collapse = "; "),
    ". Allowed: ", paste(TABLE_DOMAIN_MEASURE_FAMILIES, collapse = ", "), ".", call. = FALSE
  )
  if (anyDuplicated(domains[c("source_id", "source_sheet")])) stop(
    "Table domain guard: duplicate source_id/source_sheet rows.", call. = FALSE
  )
  rows <- domains %>% dplyr::transmute(
    source_id, source_sheet, domain, subdomain, measure_family,
    reviewed_by = dplyr::coalesce(.data$reviewed_by, "unreviewed"),
    reviewed_at = suppressWarnings(lubridate::ymd(.data$reviewed_at, quiet = TRUE)),
    note
  )
  replace_table_if_changed(con, "table_domains", rows)
  create_domain_views(con)
  invisible(nrow(rows))
}

create_domain_views <- function(con) {
  create_project_view(con, "v_series_domain", paste(
    "SELECT DISTINCT s.series_id, s.source_id, s.source_sheet,",
    "d.domain, d.subdomain, d.measure_family, d.reviewed_by AS domain_reviewed_by",
    "FROM documented_series_snapshot s",
    "JOIN table_domains d ON d.source_id = s.source_id AND d.source_sheet = s.source_sheet"
  ))
  invisible(TRUE)
}

create_table_status_views <- function(con) {
  # Documented sources are keyed by worksheet; curated sources (eve, icc,
  # fx_operations, the long-CSV markets) have no worksheet grain, so they match
  # the source-level wildcard row.
  create_project_view(con, "v_series_table_status", paste(
    "WITH sheets AS (",
    "  SELECT DISTINCT series_id, source_id, source_sheet FROM documented_series_snapshot",
    "  UNION",
    "  SELECT series_id, source_id, '*' AS source_sheet FROM dim_series",
    "   WHERE semantic_status IS DISTINCT FROM 'documented_series'",
    ")",
    "SELECT s.series_id, s.source_id, s.source_sheet,",
    "COALESCE(e.status, w.status, 'unreviewed') AS status,",
    "COALESCE(e.reviewed_by, w.reviewed_by, 'unreviewed') AS reviewed_by,",
    "COALESCE(e.reviewed_at, w.reviewed_at) AS reviewed_at,",
    "COALESCE(e.note, w.note) AS status_note",
    "FROM sheets s",
    "LEFT JOIN table_status e ON e.source_id = s.source_id AND e.source_sheet = s.source_sheet",
    "LEFT JOIN table_status w ON w.source_id = s.source_id AND w.source_sheet = '*'"
  ))
  # One row per series, and a series counts as validated only if every worksheet
  # it was assembled from is. Joining status straight onto the catalogue emitted
  # one row per worksheet instead: twelve bcp_fx_daily series are built from
  # fourteen annual sheets each, so promoting that source would have published
  # them fourteen times over. A researcher counting series would have been wrong
  # by an order of magnitude, and any join through this view would have
  # multiplied observations silently.
  create_project_view(con, "v_research_series", paste(
    "WITH series_status AS (",
    "  SELECT series_id, count(*) AS status_rows,",
    "    count(*) FILTER (WHERE status = 'validated') AS validated_rows,",
    "    string_agg(DISTINCT source_sheet, '; ') AS source_sheet,",
    "    string_agg(DISTINCT reviewed_by, '; ') AS reviewed_by,",
    "    max(reviewed_at) AS reviewed_at",
    "  FROM v_series_table_status GROUP BY 1",
    ")",
    "SELECT c.*, t.source_sheet, 'validated' AS status, t.reviewed_by, t.reviewed_at",
    "FROM v_series_catalogue c JOIN series_status t USING (series_id)",
    "WHERE t.validated_rows = t.status_rows",
    # v_series_catalogue counts every vintage the database holds, because it is a
    # catalogue. The research surface may not: a series whose only observations
    # belong to a release that was never accepted is not a research product.
    "AND EXISTS (SELECT 1 FROM main.v_series_latest l WHERE l.series_id = c.series_id)"
  ), schema = "marts")
  invisible(TRUE)
}

create_concept_views <- function(con) {
  create_project_view(con, "v_series_concept_catalogue", paste(
    "SELECT s.series_id, s.source_id, s.label AS series_label,",
    "s.unit AS series_unit, s.scale AS series_scale, s.frequency AS series_frequency,",
    "m.concept_id, c.concept_label, c.concept_domain, c.definition, m.relationship,",
    "m.mapping_status, m.evidence, m.reviewed_by, m.reviewed_at FROM dim_series s",
    "LEFT JOIN map_series_concept m USING (series_id) LEFT JOIN dim_concept c USING (concept_id)"
  ))
  create_project_view(con, "v_concept_latest", paste(
    "SELECT m.concept_id, f.period, f.value,",
    "m.series_id, s.source_id, f.vintage_id, f.publication_date, m.relationship, m.mapping_status",
    "FROM v_series_latest f JOIN map_series_concept m USING (series_id) JOIN dim_series s USING (series_id)"
  ))
  invisible(TRUE)
}
