# --- Cross-release series identity migration --------------------------------
# The audit's P0 finding: only 1,571 of 28,417 prior series IDs survived the
# schema-12 parser repairs, and nothing recorded where the other 26,846 went.
# Research code written against a prior release therefore fails silently or,
# worse, selects a different series under a reused identifier.
#
# A migration map cannot be inferred from labels: the repairs deliberately
# changed labels (CUADRO 61) and deliberately merged identities (bcp_fx_daily
# 168 -> 12). The only durable evidence is the physical source cell, which the
# repairs did not move. documented_series_snapshot records, for every parsed
# observation, the file/sheet/row/column it came from, so joining two releases
# on that coordinate recovers the mapping without trusting any label.
#
# Three matching passes, most to least authoritative. Each observation records
# which pass produced it, so a reviewer can weigh the evidence:
#   source_cell_period  the same worksheet cell yielding the same period. The
#                       primary key of the lineage; unique on both sides.
#   source_cell         the same worksheet cell after a period correction. Only
#                       consulted for series the first pass left unmatched, and
#                       only where the cell is unambiguous on both sides.
#   label_frequency     for the four curated sources (eve, icc, fx_operations,
#                       corporate_bond_curves) which write no snapshot rows and
#                       therefore have no cell lineage at all.

MIGRATION_RELATIONSHIPS <- c(
  "identical",        # the identifier itself survived unchanged
  "renamed",          # one prior series, one new series, different identifier
  "merged",           # several prior series became one (bcp_fx_daily, eve)
  "split",            # one prior series became several
  "split_and_merged", # many-to-many; always needs review before use
  "dropped",          # prior series with no successor (invalid rows removed)
  "new"               # new series with no prior identity (recovered cells)
)

# digest() hashes its whole argument, so it must be applied one key at a time.
# Passing the vector in directly returns a single hash that is then recycled
# across every row, which is caught by the duplicate-identifier guard below.
migration_id <- function(from_release, to_release, old_series_id, new_series_id) {
  keys <- paste(from_release, to_release, old_series_id, new_series_id, sep = "|")
  paste0("migration:", substr(vapply(
    keys, function(key) digest::digest(key, algo = "sha256", serialize = FALSE), character(1)
  ), 1L, 24L))
}

# Pass 1 and 2: cell lineage for the thirteen documented (semantic_table)
# sources. Pass 2 is deliberately restricted to cells that are unambiguous in
# both releases -- the prior release contains 345 reused cells from the
# compensatory FX defect, and a reused cell cannot testify to identity.
# A table's storage layer differs between releases: everything lived in main
# before the layers existed, and a backup taken then is still a valid comparison
# point. The catalogue is asked where a table is rather than told.
attached_table <- function(con, catalog, table_name) {
  found <- DBI::dbGetQuery(con, paste0(
    "SELECT schema_name FROM duckdb_tables() WHERE database_name = ", sql_string(catalog),
    " AND table_name = ", sql_string(table_name), " ORDER BY schema_name LIMIT 1"
  ))
  if (!nrow(found)) stop(
    "Migration guard: ", catalog, " has no ", table_name, " table; it is not a comparable ",
    "release.", call. = FALSE
  )
  paste0(catalog, ".", found$schema_name[[1]], ".", table_name)
}

migration_documented_pairs <- function(con, current) {
  current_snapshot <- attached_table(con, current, "documented_series_snapshot")
  previous_snapshot <- attached_table(con, "prev", "documented_series_snapshot")
  derived_union <- ""
  lineage_exists <- nrow(DBI::dbGetQuery(con, paste0(
    "SELECT 1 FROM duckdb_tables() WHERE database_name=", sql_string(current),
    " AND table_name='lrm_derived_observation_lineage' LIMIT 1"
  ))) > 0L
  if (lineage_exists) derived_union <- paste(
    "UNION ALL SELECT o.series_id AS old_series_id,l.derived_series_id AS new_series_id,",
    "o.source_id,count(*) AS shared_observations FROM", previous_snapshot, "o JOIN",
    attached_table(con, current, "lrm_derived_observation_lineage"), "l",
    "ON o.vintage_id=l.vintage_id AND o.source_sheet=l.source_sheet",
    "AND o.source_row=l.source_row AND o.source_column=l.source_column AND o.period=l.period",
    "GROUP BY 1,2,3"
  )
  by_cell_period <- DBI::dbGetQuery(con, paste(
    "SELECT o.series_id AS old_series_id, n.series_id AS new_series_id,",
    "n.source_id, count(*) AS shared_observations",
    "FROM", previous_snapshot, "o",
    "JOIN", current_snapshot, "n",
    "  ON o.source_id = n.source_id AND o.source_file = n.source_file",
    " AND o.source_sheet = n.source_sheet AND o.source_row = n.source_row",
    " AND o.source_column = n.source_column AND o.period = n.period",
    "GROUP BY 1, 2, 3", derived_union
  ))
  by_cell_period$match_method <- "source_cell_period"

  matched_old <- unique(by_cell_period$old_series_id)
  matched_new <- unique(by_cell_period$new_series_id)

  by_cell <- DBI::dbGetQuery(con, paste(
    "WITH old_cells AS (",
    "  SELECT source_id, source_file, source_sheet, source_row, source_column,",
    "         any_value(series_id) AS series_id",
    "  FROM", attached_table(con, "prev", "documented_series_snapshot"), "GROUP BY 1, 2, 3, 4, 5",
    "  HAVING count(DISTINCT series_id) = 1",
    "), new_cells AS (",
    "  SELECT source_id, source_file, source_sheet, source_row, source_column,",
    "         any_value(series_id) AS series_id",
    "  FROM", attached_table(con, current, "documented_series_snapshot"), "GROUP BY 1, 2, 3, 4, 5",
    "  HAVING count(DISTINCT series_id) = 1",
    ")",
    "SELECT o.series_id AS old_series_id, n.series_id AS new_series_id,",
    "n.source_id, count(*) AS shared_observations",
    "FROM old_cells o JOIN new_cells n",
    "  ON o.source_id = n.source_id AND o.source_file = n.source_file",
    " AND o.source_sheet = n.source_sheet AND o.source_row = n.source_row",
    " AND o.source_column = n.source_column",
    "GROUP BY 1, 2, 3"
  ))
  by_cell$match_method <- "source_cell"
  by_cell <- by_cell %>% dplyr::filter(
    !.data$old_series_id %in% matched_old, !.data$new_series_id %in% matched_new
  )

  dplyr::bind_rows(by_cell_period, by_cell)
}

# Pass 3: the curated sources. They have no cell lineage, so the published
# label plus frequency is the only available evidence. That is exactly why
# these pairs are recorded with a weaker match_method rather than silently
# mixed in with cell-derived ones.
migration_curated_pairs <- function(con, current, matched_old, matched_new) {
  pairs <- DBI::dbGetQuery(con, paste(
    "SELECT o.series_id AS old_series_id, n.series_id AS new_series_id,",
    "n.source_id, 0 AS shared_observations",
    "FROM", attached_table(con, "prev", "dim_series"), "o JOIN", attached_table(con, current, "dim_series"), "n",
    "  ON o.source_id = n.source_id AND o.frequency IS NOT DISTINCT FROM n.frequency",
    " AND lower(trim(o.label)) = lower(trim(n.label))",
    "WHERE n.series_id NOT IN (SELECT series_id FROM",
    attached_table(con, current, "documented_series_snapshot"), ")"
  ))
  if (!nrow(pairs)) return(pairs)
  pairs$match_method <- "label_frequency"
  pairs %>% dplyr::filter(
    !.data$old_series_id %in% matched_old, !.data$new_series_id %in% matched_new
  )
}

migration_classify <- function(pairs) {
  if (!nrow(pairs)) return(pairs)
  pairs %>%
    dplyr::group_by(.data$old_series_id) %>%
    dplyr::mutate(successors = dplyr::n_distinct(.data$new_series_id)) %>%
    dplyr::group_by(.data$new_series_id) %>%
    dplyr::mutate(predecessors = dplyr::n_distinct(.data$old_series_id)) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(relationship = dplyr::case_when(
      .data$old_series_id == .data$new_series_id           ~ "identical",
      .data$successors > 1L & .data$predecessors > 1L      ~ "split_and_merged",
      .data$predecessors > 1L                              ~ "merged",
      .data$successors > 1L                                ~ "split",
      TRUE                                                 ~ "renamed"
    ))
}

build_series_id_migration <- function(con, previous_db_path, from_release, to_release, root,
                                      current = "main") {
  if (!file.exists(previous_db_path)) stop(
    "Migration guard: previous release database not found: ", previous_db_path, call. = FALSE
  )
  DBI::dbExecute(con, paste0("ATTACH ", sql_string(previous_db_path), " AS prev (READ_ONLY)"))
  on.exit(try(DBI::dbExecute(con, "DETACH prev"), silent = TRUE), add = TRUE)

  for (table_name in c("dim_series", "documented_series_snapshot")) {
    attached_table(con, "prev", table_name)
  }

  documented <- migration_documented_pairs(con, current)
  curated <- migration_curated_pairs(
    con, current, unique(documented$old_series_id), unique(documented$new_series_id)
  )
  pairs <- migration_classify(dplyr::bind_rows(documented, curated))

  old_series <- DBI::dbGetQuery(con, paste("SELECT series_id, source_id FROM", attached_table(con, "prev", "dim_series")))
  new_series <- DBI::dbGetQuery(con, paste("SELECT series_id, source_id FROM", attached_table(con, current, "dim_series")))
  old_counts <- DBI::dbGetQuery(con, paste(
    "SELECT series_id, count(*) AS observations FROM", attached_table(con, "prev", "fact_series_events"),
    "WHERE NOT is_deleted GROUP BY 1"
  ))
  new_counts <- DBI::dbGetQuery(con, paste(
    "SELECT series_id, count(*) AS observations FROM",
    attached_table(con, current, "fact_series_events"), "WHERE NOT is_deleted GROUP BY 1"
  ))

  # A prior identity with no successor and a new identity with no predecessor
  # are both reportable outcomes, not gaps in the map. Recording them is what
  # lets the release gate assert that every changed identifier is accounted for.
  dropped <- old_series %>%
    dplyr::filter(!.data$series_id %in% pairs$old_series_id) %>%
    dplyr::transmute(
      old_series_id = .data$series_id, new_series_id = NA_character_, source_id,
      shared_observations = 0L, match_method = "none", relationship = "dropped"
    )
  added <- new_series %>%
    dplyr::filter(!.data$series_id %in% pairs$new_series_id) %>%
    dplyr::transmute(
      old_series_id = NA_character_, new_series_id = .data$series_id, source_id,
      shared_observations = 0L, match_method = "none", relationship = "new"
    )

  rows <- dplyr::bind_rows(
    pairs %>% dplyr::select(
      "old_series_id", "new_series_id", "source_id", "shared_observations",
      "match_method", "relationship"
    ),
    dropped, added
  ) %>%
    dplyr::left_join(
      old_counts %>% dplyr::rename(old_series_id = "series_id", old_observations = "observations"),
      by = "old_series_id"
    ) %>%
    dplyr::left_join(
      new_counts %>% dplyr::rename(new_series_id = "series_id", new_observations = "observations"),
      by = "new_series_id"
    ) %>%
    dplyr::transmute(
      migration_id = migration_id(
        from_release, to_release,
        dplyr::coalesce(.data$old_series_id, ""), dplyr::coalesce(.data$new_series_id, "")
      ),
      from_release, to_release, source_id, old_series_id, new_series_id, relationship,
      match_method,
      shared_observations = as.integer(dplyr::coalesce(.data$shared_observations, 0L)),
      old_observations = as.integer(dplyr::coalesce(.data$old_observations, 0L)),
      new_observations = as.integer(dplyr::coalesce(.data$new_observations, 0L)),
      evidence = dplyr::case_when(
        .data$match_method == "source_cell_period" ~
          "Same source file/sheet/row/column and reference period in both releases.",
        .data$match_method == "source_cell" ~
          "Same source file/sheet/row/column in both releases; reference period was corrected.",
        .data$match_method == "label_frequency" ~
          "Curated source without cell lineage; matched on published label and frequency.",
        .data$relationship == "dropped" ~
          "No cell or label evidence of a successor in the new release.",
        TRUE ~ "No cell or label evidence of a predecessor in the prior release."
      ),
      reviewed_by = NA_character_, reviewed_at = as.Date(NA),
      created_at = Sys.time()
    )

  invalid <- setdiff(unique(rows$relationship), MIGRATION_RELATIONSHIPS)
  if (length(invalid)) stop(
    "Migration guard: unsupported relationship(s): ", paste(invalid, collapse = "; "), call. = FALSE
  )
  if (anyDuplicated(rows$migration_id)) stop(
    "Migration guard: duplicate migration_id rows.", call. = FALSE
  )
  unmapped <- setdiff(old_series$series_id, c(rows$old_series_id))
  if (length(unmapped)) stop(
    "Migration guard: ", length(unmapped), " prior series are absent from the map.", call. = FALSE
  )
  unmapped_new <- setdiff(new_series$series_id, c(rows$new_series_id))
  if (length(unmapped_new)) stop(
    "Migration guard: ", length(unmapped_new), " new series are absent from the map.", call. = FALSE
  )

  with_project_transaction(con, {
    DBI::dbExecute(con, paste0(
      "DELETE FROM series_id_migration WHERE from_release = ", sql_string(from_release),
      " AND to_release = ", sql_string(to_release)
    ))
    DBI::dbWriteTable(con, "series_id_migration", rows, append = TRUE)
  })
  rebuild_prior_release_aliases(con)
  create_migration_views(con)

  if (!is.null(root)) {
    readr::write_csv(
      DBI::dbGetQuery(con, "SELECT * FROM series_id_migration ORDER BY from_release, source_id"),
      file.path(root, "outputs", "series_id_migration.csv")
    )
  }
  invisible(rows)
}

# Every identifier the project has ever published becomes a durable alias of the
# series it resolves to now. Resolution has to be transitive: an identifier from
# the schema-11 release may have been renamed by the schema-12 repairs and then
# renamed again by schema 13, and research code citing the original must still
# land on the right series. The recursive walk follows each chain to its current
# end rather than assuming one hop.
#
# A prior identifier that was split legitimately resolves to several current
# series and therefore produces several alias rows. That ambiguity is real and
# is surfaced rather than silently resolved to one of them.
rebuild_prior_release_aliases <- function(con) {
  aliases <- DBI::dbGetQuery(con, paste(
    "WITH RECURSIVE resolved(published_series_id, current_series_id) AS (",
    "  SELECT series_id, series_id FROM dim_series",
    "  UNION",
    "  SELECT m.old_series_id, r.current_series_id",
    "  FROM series_id_migration m",
    "  JOIN resolved r ON m.new_series_id = r.published_series_id",
    "  WHERE m.old_series_id IS NOT NULL",
    ")",
    "SELECT r.published_series_id, r.current_series_id, d.source_id",
    "FROM resolved r JOIN dim_series d ON d.series_id = r.current_series_id",
    "WHERE r.published_series_id <> r.current_series_id"
  ))
  rows <- if (nrow(aliases)) {
    aliases %>% dplyr::transmute(
      alias_id = paste0("alias:", substr(vapply(
        paste(.data$published_series_id, .data$current_series_id, sep = "|"),
        function(x) digest::digest(x, algo = "sha256", serialize = FALSE), character(1)
      ), 1L, 24L)),
      series_id = .data$current_series_id, source_id,
      alias_kind = "prior_release_series_id", alias_value = .data$published_series_id,
      valid_from = as.Date(NA), valid_to = as.Date(NA),
      evidence = "Superseded identifier resolved through the recorded release migration chain.",
      reviewed_by = NA_character_, reviewed_at = as.Date(NA)
    ) %>% dplyr::distinct(.data$alias_id, .keep_all = TRUE)
  } else aliases
  with_project_transaction(con, {
    DBI::dbExecute(con, "DELETE FROM source_alias WHERE alias_kind = 'prior_release_series_id'")
    if (nrow(rows)) DBI::dbWriteTable(con, "source_alias", rows, append = TRUE)
  })
  invisible(nrow(rows))
}

create_migration_views <- function(con) {
  # One lookup for research code: given any identifier the project has ever
  # published, say what became of it. Three outcomes, and every published
  # identifier has exactly one of them, so a caller never has to interpret a
  # missing row:
  #   current              the identifier is still live
  #   prior_release_alias  it was superseded; here is the series it became
  #   retired              it was withdrawn, because the series it named was a
  #                        parser artefact rather than a published measure
  #
  # Retirement is transitive. An identifier renamed by one release into a series
  # that a later release removed is itself retired, so the walk follows each
  # chain to its end instead of reporting the first hop and stopping.
  #
  # The follow-up audit asked for one more thing: make the cardinality explicit
  # and refuse to guess. Thirty-six prior identifiers legitimately resolve to
  # several current series, because the release that superseded them split one
  # measure into several. A lookup that quietly returned the first of them would
  # hand research code a different series under a familiar name -- the precise
  # failure this whole map exists to prevent. So resolution_cardinality names the
  # case, and the scalar resolver below returns nothing rather than something
  # arbitrary.
  create_project_view(con, "v_series_id_resolution", paste(
    "WITH RECURSIVE retired(series_id) AS (",
    "  SELECT old_series_id FROM series_id_migration",
    "  WHERE relationship = 'dropped' AND old_series_id IS NOT NULL",
    "  UNION",
    "  SELECT m.old_series_id FROM series_id_migration m",
    "  JOIN retired t ON m.new_series_id = t.series_id",
    "  WHERE m.old_series_id IS NOT NULL",
    "), resolved AS (",
    "  SELECT series_id AS published_series_id, series_id AS current_series_id,",
    "  'current' AS resolution, 'Identifier is current.' AS evidence FROM dim_series",
    "  UNION ALL",
    "  SELECT alias_value, series_id, 'prior_release_alias', evidence FROM source_alias",
    "  WHERE alias_kind = 'prior_release_series_id'",
    "  UNION ALL",
    "  SELECT r.series_id, NULL, 'retired',",
    "  'Withdrawn: the series it named did not survive a later parser repair.'",
    "  FROM retired r WHERE r.series_id NOT IN (SELECT series_id FROM dim_series)",
    "    AND r.series_id NOT IN (SELECT alias_value FROM source_alias",
    "                            WHERE alias_kind = 'prior_release_series_id')",
    ")",
    "SELECT published_series_id, current_series_id, resolution, evidence,",
    "count(*) OVER (PARTITION BY published_series_id) AS candidate_count,",
    "CASE WHEN current_series_id IS NULL THEN 'retired'",
    "     WHEN count(*) OVER (PARTITION BY published_series_id) > 1 THEN 'one_to_many'",
    "     ELSE 'one_to_one' END AS resolution_cardinality",
    "FROM resolved"
  ))
  # Exactly one row per identifier the project has ever published, with a
  # resolved_series_id that is NULL unless the identifier still names precisely
  # one current series. This is the form research code should join to: a retired
  # or split identifier drops out of the join instead of quietly picking up a
  # series it never named.
  #
  # The key column is called lookup_id rather than published_series_id on
  # purpose. A DuckDB macro substitutes the caller's argument expression into its
  # body, so a macro comparing published_series_id = published_id turns into a
  # tautology the moment someone calls it with a bare column of that name, and
  # silently resolves every identifier to the same arbitrary series. Naming the
  # key something no caller has makes that collision impossible.
  create_project_view(con, "v_series_id_scalar_resolution", paste(
    "SELECT published_series_id AS lookup_id,",
    "max(CASE WHEN resolution_cardinality = 'one_to_one' THEN current_series_id END)",
    "  AS resolved_series_id,",
    "any_value(resolution_cardinality) AS resolution_cardinality,",
    "count(*) AS candidate_count",
    "FROM v_series_id_resolution GROUP BY published_series_id"
  ))
  # Two resolvers, so a caller has to say which question it is asking.
  #
  #   resolve_series_id   scalar, and NULL is a real answer. It means "this
  #                       identifier does not name one current series", which is
  #                       true for a retired identifier and for a split one.
  #   resolve_series_ids  the table form, for callers that want every successor
  #                       of a split and will decide among them themselves.
  create_project_macro(con, "resolve_series_id(published_id)", paste(
    "AS (",
    "  SELECT max(resolved_series_id) FROM v_series_id_scalar_resolution",
    "  WHERE lookup_id = published_id",
    ")"
  ))
  create_project_macro(con, "resolve_series_ids(published_id)", paste(
    "AS TABLE",
    "SELECT s.lookup_id AS published_series_id, r.current_series_id, r.resolution,",
    "s.resolution_cardinality, r.evidence",
    "FROM v_series_id_scalar_resolution s",
    "JOIN v_series_id_resolution r ON r.published_series_id = s.lookup_id",
    "WHERE s.lookup_id = published_id"
  ))
  create_project_view(con, "v_series_migration_summary", paste(
    "SELECT from_release, to_release, source_id, relationship, match_method,",
    "count(*) AS mappings,",
    "count(DISTINCT old_series_id) AS prior_series,",
    "count(DISTINCT new_series_id) AS current_series",
    "FROM series_id_migration GROUP BY 1, 2, 3, 4, 5"
  ))
  invisible(TRUE)
}
