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
    DBI::dbWithTransaction(con, {
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
  DBI::dbWithTransaction(con, {
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

read_table_status <- function(root) {
  path <- file.path(root, "config", "table_status.csv")
  required <- c("source_id", "source_sheet", "status", "reviewed_by", "reviewed_at", "note")
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
    source_id, source_sheet, status,
    reviewed_by = dplyr::coalesce(.data$reviewed_by, "unreviewed"),
    reviewed_at = suppressWarnings(lubridate::ymd(.data$reviewed_at, quiet = TRUE)),
    note
  )
  DBI::dbWithTransaction(con, {
    DBI::dbExecute(con, "DELETE FROM table_status")
    DBI::dbWriteTable(con, "table_status", rows, append = TRUE)
  })
  create_table_status_views(con)
  invisible(nrow(rows))
}

create_table_status_views <- function(con) {
  # Documented sources are keyed by worksheet; curated sources (eve, icc,
  # fx_operations, the long-CSV markets) have no worksheet grain, so they match
  # the source-level wildcard row.
  DBI::dbExecute(con, paste(
    "CREATE OR REPLACE VIEW v_series_table_status AS",
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
  DBI::dbExecute(con, paste(
    "CREATE OR REPLACE VIEW v_research_series AS",
    "SELECT c.*, t.source_sheet, t.status, t.reviewed_by, t.reviewed_at",
    "FROM v_series_catalogue c JOIN v_series_table_status t USING (series_id)",
    "WHERE t.status = 'validated'"
  ))
  invisible(TRUE)
}

create_concept_views <- function(con) {
  DBI::dbExecute(con, paste(
    "CREATE OR REPLACE VIEW v_series_concept_catalogue AS SELECT s.series_id, s.source_id, s.label AS series_label,",
    "s.unit AS series_unit, s.scale AS series_scale, s.frequency AS series_frequency,",
    "m.concept_id, c.concept_label, c.concept_domain, c.definition, m.relationship,",
    "m.mapping_status, m.evidence, m.reviewed_by, m.reviewed_at FROM dim_series s",
    "LEFT JOIN map_series_concept m USING (series_id) LEFT JOIN dim_concept c USING (concept_id)"
  ))
  DBI::dbExecute(con, paste(
    "CREATE OR REPLACE VIEW v_concept_latest AS SELECT m.concept_id, f.period, f.value,",
    "m.series_id, s.source_id, f.vintage_id, f.publication_date, m.relationship, m.mapping_status",
    "FROM v_series_latest f JOIN map_series_concept m USING (series_id) JOIN dim_series s USING (series_id)"
  ))
  invisible(TRUE)
}
