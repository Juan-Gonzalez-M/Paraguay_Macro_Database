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
