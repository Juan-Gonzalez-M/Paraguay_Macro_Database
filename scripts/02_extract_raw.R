ensure_table_column <- function(con, table_name, column_name, column_type) {
  if (!DBI::dbExistsTable(con, table_name)) return(invisible(FALSE))
  columns <- DBI::dbGetQuery(con, paste0("PRAGMA table_info(", sql_string(table_name), ")"))$name
  if (!column_name %in% columns) DBI::dbExecute(con, paste0(
    "ALTER TABLE ", DBI::dbQuoteIdentifier(con, table_name), " ADD COLUMN ",
    DBI::dbQuoteIdentifier(con, column_name), " ", column_type
  ))
  invisible(TRUE)
}

rename_table_column <- function(con, table_name, from, to) {
  if (!DBI::dbExistsTable(con, table_name)) return(invisible(FALSE))
  columns <- DBI::dbGetQuery(con, paste0("PRAGMA table_info(", sql_string(table_name), ")"))$name
  if (!from %in% columns || to %in% columns) return(invisible(FALSE))
  DBI::dbExecute(con, paste(
    "ALTER TABLE", DBI::dbQuoteIdentifier(con, table_name), "RENAME COLUMN",
    DBI::dbQuoteIdentifier(con, from), "TO", DBI::dbQuoteIdentifier(con, to)
  ))
  invisible(TRUE)
}

database_object_type <- function(con, object_name) {
  result <- DBI::dbGetQuery(con, paste0(
    "SELECT table_type FROM information_schema.tables WHERE table_schema IN (",
    paste(vapply(c("main", PROJECT_SCHEMAS), sql_string, character(1)), collapse = ", "),
    ") AND table_name = ", sql_string(object_name)
  ))
  if (nrow(result)) result$table_type[[1]] else NA_character_
}

invalidate_v2_curated_content <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version")) return(invisible(FALSE))
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!2L %in% versions || 3L %in% versions) return(invisible(FALSE))

  source_ids <- c("icc", "eve", "fx_operations")
  source_sql <- paste(vapply(source_ids, sql_string, character(1)), collapse = ", ")
  vintage_sql <- paste0("SELECT vintage_id FROM source_files WHERE source_id IN (", source_sql, ")")
  series_prefixes <- c("icc:%", "eve:%", "fx_operations:%")
  series_where <- paste(vapply(series_prefixes, function(prefix) {
    paste0("series_id LIKE ", sql_string(prefix))
  }, character(1)), collapse = " OR ")

  with_project_transaction(con, {
    for (table_name in c("fact_series_events", "semantic_coverage", "structure_checks",
                         "discarded_rows", "quality_flags", "report_cells")) {
      if (DBI::dbExistsTable(con, table_name)) DBI::dbExecute(con, paste0(
        "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
        " WHERE vintage_id IN (", vintage_sql, ")"
      ))
    }
    if (DBI::dbExistsTable(con, "series_revisions")) DBI::dbExecute(con, paste0(
      "DELETE FROM series_revisions WHERE ", series_where
    ))
    if (DBI::dbExistsTable(con, "dim_series")) DBI::dbExecute(con, paste0(
      "DELETE FROM dim_series WHERE source_id IN (", source_sql, ")"
    ))
    for (table_name in c("consumer_confidence_snapshot", "eve_expectations_snapshot", "fx_operations_snapshot")) {
      if (DBI::dbExistsTable(con, table_name)) DBI::dbExecute(con, paste0(
        "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
        " WHERE vintage_id IN (", vintage_sql, ")"
      ))
    }
    DBI::dbExecute(con, paste0(
      "UPDATE source_files SET ingestion_status = 'needs_v3_reingestion', publication_date = NULL, ",
      "publication_date_source = 'pending_content_inference' ",
      "WHERE source_id IN (", source_sql, ")"
    ))
  })
  invisible(TRUE)
}

invalidate_v3_reference_semantics <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version")) return(invisible(FALSE))
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!3L %in% versions || 4L %in% versions || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  DBI::dbExecute(con, paste0(
    "UPDATE source_files SET ingestion_status = 'needs_v4_reingestion' ",
    "WHERE source_id = 'bank_reference'"
  ))
  invisible(TRUE)
}

invalidate_v4_documented_sources <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!4L %in% versions || 5L %in% versions) return(invisible(FALSE))
  source_ids <- c("economic_annex", "payments", "exchange_houses", "credit_survey")
  source_sql <- paste(vapply(source_ids, sql_string, character(1)), collapse = ", ")
  DBI::dbExecute(con, paste0(
    "UPDATE source_files SET ingestion_status = 'needs_v5_reingestion' ",
    "WHERE source_id IN (", source_sql, ")"
  ))
  invisible(TRUE)
}

invalidate_v6_documented_identity <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!6L %in% versions || 7L %in% versions) return(invisible(FALSE))
  source_ids <- c("economic_annex", "payments", "exchange_houses", "credit_survey")
  source_sql <- paste(vapply(source_ids, sql_string, character(1)), collapse = ", ")
  series_query <- paste0("SELECT series_id FROM dim_series WHERE source_id IN (", source_sql, ") AND semantic_status = 'documented_series'")
  vintage_query <- paste0("SELECT vintage_id FROM source_files WHERE source_id IN (", source_sql, ")")
  with_project_transaction(con, {
    if (DBI::dbExistsTable(con, "map_series_concept")) DBI::dbExecute(con, paste0(
      "DELETE FROM map_series_concept WHERE series_id IN (", series_query, ")"
    ))
    if (DBI::dbExistsTable(con, "fact_series_events")) DBI::dbExecute(con, paste0(
      "DELETE FROM fact_series_events WHERE series_id IN (", series_query, ")"
    ))
    if (DBI::dbExistsTable(con, "series_revisions")) DBI::dbExecute(con, paste0(
      "DELETE FROM series_revisions WHERE series_id IN (", series_query, ")"
    ))
    if (DBI::dbExistsTable(con, "dim_series")) DBI::dbExecute(con, paste0(
      "DELETE FROM dim_series WHERE series_id IN (", series_query, ")"
    ))
    if (DBI::dbExistsTable(con, "dim_concept")) DBI::dbExecute(con, paste0(
      "DELETE FROM dim_concept WHERE mapping_status = 'source_specific_unreviewed' ",
      "AND concept_id NOT IN (SELECT concept_id FROM map_series_concept)"
    ))
    for (table_name in c("documented_series_snapshot", "documented_table_catalog",
                         "documented_sheet_drift", "semantic_coverage")) {
      if (DBI::dbExistsTable(con, table_name)) DBI::dbExecute(con, paste0(
        "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
        " WHERE vintage_id IN (", vintage_query, ")"
      ))
    }
    DBI::dbExecute(con, paste0(
      "UPDATE source_files SET ingestion_status = 'needs_v7_reingestion' WHERE source_id IN (", source_sql, ")"
    ))
  })
  invisible(TRUE)
}

invalidate_v8_ingestion_repairs <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!8L %in% versions || 9L %in% versions) return(invisible(FALSE))
  documented_sources <- c(
    "economic_annex", "payments", "exchange_houses", "credit_survey",
    "direct_investment", "insurance_annex", "bcp_fx_daily", "exchange_rates",
    "banking_indicators", "financial_indicators", "interbank_market", "lrm_auctions",
    "compensatory_fx_sales", "liquidity_facility"
  )
  source_sql <- paste(vapply(documented_sources, sql_string, character(1)), collapse = ", ")
  series_query <- paste0(
    "SELECT series_id FROM dim_series WHERE source_id IN (", source_sql,
    ") AND semantic_status = 'documented_series'"
  )
  vintage_query <- paste0("SELECT vintage_id FROM source_files WHERE source_id IN (", source_sql, ")")
  affected_concepts <- if (DBI::dbExistsTable(con, "map_series_concept")) {
    DBI::dbGetQuery(con, paste0(
      "SELECT DISTINCT concept_id FROM map_series_concept WHERE series_id IN (",
      series_query, ") AND mapping_status = 'source_specific_unreviewed'"
    ))$concept_id
  } else character()
  with_project_transaction(con, {
    for (table_name in c("map_series_concept", "fact_series_events", "series_revisions")) {
      if (DBI::dbExistsTable(con, table_name)) DBI::dbExecute(con, paste0(
        "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
        " WHERE series_id IN (", series_query, ")"
      ))
    }
    if (DBI::dbExistsTable(con, "dim_series")) DBI::dbExecute(con, paste0(
      "DELETE FROM dim_series WHERE series_id IN (", series_query, ")"
    ))
    if (DBI::dbExistsTable(con, "dim_concept") && length(affected_concepts)) {
      concept_sql <- paste(vapply(affected_concepts, sql_string, character(1)), collapse = ", ")
      DBI::dbExecute(con, paste0(
        "DELETE FROM dim_concept WHERE concept_id IN (", concept_sql, ") ",
        "AND mapping_status = 'source_specific_unreviewed' ",
        "AND concept_id NOT IN (SELECT concept_id FROM map_series_concept)"
      ))
    }
    for (table_name in c(
      "documented_series_snapshot", "documented_table_catalog", "documented_sheet_drift",
      "documented_series_continuity", "semantic_coverage"
    )) if (DBI::dbExistsTable(con, table_name)) DBI::dbExecute(con, paste0(
      "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
      " WHERE vintage_id IN (", vintage_query, ")"
    ))
    DBI::dbExecute(con, paste0(
      "UPDATE source_files SET ingestion_status = 'needs_v9_reingestion' WHERE source_id IN (",
      source_sql, ") OR source_id = 'bank_reference'"
    ))
  })
  invisible(TRUE)
}

invalidate_v9_runtime_repairs <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!9L %in% versions || 10L %in% versions) return(invisible(FALSE))
  affected_sources <- c(
    "economic_annex", "exchange_rates", "exchange_houses",
    "liquidity_facility", "interbank_market", "lrm_auctions"
  )
  source_sql <- paste(vapply(affected_sources, sql_string, character(1)), collapse = ", ")
  series_query <- paste0(
    "SELECT series_id FROM dim_series WHERE source_id IN (", source_sql,
    ") AND semantic_status = 'documented_series'"
  )
  vintage_query <- paste0("SELECT vintage_id FROM source_files WHERE source_id IN (", source_sql, ")")
  affected_concepts <- if (DBI::dbExistsTable(con, "map_series_concept")) {
    DBI::dbGetQuery(con, paste0(
      "SELECT DISTINCT concept_id FROM map_series_concept WHERE series_id IN (",
      series_query, ") AND mapping_status = 'source_specific_unreviewed'"
    ))$concept_id
  } else character()
  with_project_transaction(con, {
    for (table_name in c("map_series_concept", "fact_series_events", "series_revisions")) {
      if (DBI::dbExistsTable(con, table_name)) DBI::dbExecute(con, paste0(
        "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
        " WHERE series_id IN (", series_query, ")"
      ))
    }
    if (DBI::dbExistsTable(con, "dim_series")) DBI::dbExecute(con, paste0(
      "DELETE FROM dim_series WHERE series_id IN (", series_query, ")"
    ))
    if (DBI::dbExistsTable(con, "dim_concept") && length(affected_concepts)) {
      concept_sql <- paste(vapply(affected_concepts, sql_string, character(1)), collapse = ", ")
      DBI::dbExecute(con, paste0(
        "DELETE FROM dim_concept WHERE concept_id IN (", concept_sql, ") ",
        "AND mapping_status = 'source_specific_unreviewed' ",
        "AND concept_id NOT IN (SELECT concept_id FROM map_series_concept)"
      ))
    }
    for (table_name in c(
      "documented_series_snapshot", "documented_table_catalog", "documented_sheet_drift",
      "documented_series_continuity", "semantic_coverage"
    )) if (DBI::dbExistsTable(con, table_name)) DBI::dbExecute(con, paste0(
      "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
      " WHERE vintage_id IN (", vintage_query, ")"
    ))
    DBI::dbExecute(con, paste0(
      "UPDATE source_files SET ingestion_status = 'needs_v10_reingestion' WHERE source_id IN (",
      source_sql, ")"
    ))
  })
  invisible(TRUE)
}

invalidate_v10_annex_year_axis <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!10L %in% versions || 11L %in% versions) return(invisible(FALSE))
  source_sql <- sql_string("economic_annex")
  series_query <- paste0(
    "SELECT series_id FROM dim_series WHERE source_id = ", source_sql,
    " AND semantic_status = 'documented_series'"
  )
  vintage_query <- paste0("SELECT vintage_id FROM source_files WHERE source_id = ", source_sql)
  affected_concepts <- if (DBI::dbExistsTable(con, "map_series_concept")) {
    DBI::dbGetQuery(con, paste0(
      "SELECT DISTINCT concept_id FROM map_series_concept WHERE series_id IN (",
      series_query, ") AND mapping_status = 'source_specific_unreviewed'"
    ))$concept_id
  } else character()
  with_project_transaction(con, {
    for (table_name in c("map_series_concept", "fact_series_events", "series_revisions")) {
      if (DBI::dbExistsTable(con, table_name)) DBI::dbExecute(con, paste0(
        "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
        " WHERE series_id IN (", series_query, ")"
      ))
    }
    if (DBI::dbExistsTable(con, "dim_series")) DBI::dbExecute(con, paste0(
      "DELETE FROM dim_series WHERE series_id IN (", series_query, ")"
    ))
    if (DBI::dbExistsTable(con, "dim_concept") && length(affected_concepts)) {
      concept_sql <- paste(vapply(affected_concepts, sql_string, character(1)), collapse = ", ")
      DBI::dbExecute(con, paste0(
        "DELETE FROM dim_concept WHERE concept_id IN (", concept_sql, ") ",
        "AND mapping_status = 'source_specific_unreviewed' ",
        "AND concept_id NOT IN (SELECT concept_id FROM map_series_concept)"
      ))
    }
    for (table_name in c(
      "documented_series_snapshot", "documented_table_catalog", "documented_sheet_drift",
      "documented_series_continuity", "semantic_coverage"
    )) if (DBI::dbExistsTable(con, table_name)) DBI::dbExecute(con, paste0(
      "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
      " WHERE vintage_id IN (", vintage_query, ")"
    ))
    DBI::dbExecute(con, paste0(
      "UPDATE source_files SET ingestion_status = 'needs_v11_reingestion' WHERE source_id = ",
      source_sql
    ))
  })
  invisible(TRUE)
}

# Schema 12 -- P0 identity and parser repairs from the external technical audit
# (Technical_Audit.docx, 27 Aug 2026). Every source listed here produces
# different series_id values under version 12 than it did under version 11, so
# their curated output must be discarded and rebuilt from the immutable raw
# layer rather than merged:
#   * all semantic_table sources: the worksheet slug inside series_id was
#     uniquified by position (Datos, Datos_2, ... Datos_26), so identity moved
#     whenever a column was inserted upstream. documented_sheet_slug() now
#     depends only on the sheet name.
#   * bcp_fx_daily: the 14 annual worksheets are merged into one continuation
#     group, 168 series become 12.
#   * economic_annex: CUADRO 61 gets a table-specific parser (170 numeric-label
#     identities become 130 named series).
#   * credit_survey: the structural slot moves to the row axis, collapsing 2,534
#     one-observation identities.
#   * compensatory_fx_sales: year blocks are bounded, 36 lane series become 3.
#   * eve: slug() no longer sees the materialized tibble column, 2,760 series
#     become 16. eve is curated, not documented, so its identity has to be
#     selected by source_id and its own snapshot table cleared as well.
# Shared body of every parser-repair invalidation: drop the curated content of
# the named sources so the next run re-ingests them from the archived files.
# Extracted so a new repair declares only which sources it touches.
# --- The migration registry -------------------------------------------------
# One declaration per schema version: what it changed, and which sources it
# forces back through the parser. Two things read it, which is the point.
# invalidate_v*() takes its source list from here rather than repeating it, and
# write_migration_runbook() generates docs/SCHEMA_MIGRATIONS.md from it.
#
# Keeping this declaration executable prevents the generated runbook, migration
# invalidation and recovery instructions from drifting apart.
#
# Versions 2 to 11 predate the registry and keep their bespoke invalidation
# bodies; they are declared here for the runbook only, and the guard below
# asserts that every applied version is accounted for either way.
SCHEMA_MIGRATIONS <- list(
  list(version = 2L, reingests = c("icc", "eve", "fx_operations"), registry_driven = FALSE,
       change = "Corrected ICC, EVE and FX-operations content is forced through reingestion."),
  list(version = 3L, reingests = character(), registry_driven = FALSE,
       change = "Reference semantics are reingested; full report-cell history is preserved behind the sparse compatibility view."),
  list(version = 4L, reingests = c("economic_annex", "payments", "exchange_houses", "credit_survey"),
       registry_driven = FALSE,
       change = "The Annex, payments, exchange houses and credit survey are marked for guarded v5 reingestion."),
  list(version = 5L, reingests = character(), registry_driven = FALSE,
       change = "Source-specific concept identities and the diagnostic tables are added without changing observations."),
  list(version = 6L, reingests = c("economic_annex", "payments", "exchange_houses", "credit_survey"),
       registry_driven = FALSE,
       change = "The original four documented sources are reingested once under the stable v7 identity contract."),
  list(version = 7L, reingests = character(), registry_driven = FALSE,
       change = "The performance schema and stage timings are added without reingesting observations."),
  list(version = 8L, reingests = "all documented Excel sources", registry_driven = FALSE,
       change = "Documented Excel sources are reingested once under the corrected v9 date, reference and event-identity contracts."),
  list(version = 9L, reingests = "the six sources affected by contextual date, formula-view and row-event changes",
       registry_driven = FALSE,
       change = "Real-file ingestion repairs, semantic row-event identities and per-source discovery isolation."),
  list(version = 10L, reingests = "economic_annex", registry_driven = FALSE,
       change = "Contextual date and year parsing, empty-sheet bounds, continuity SQL and complete event dimensions."),
  list(version = 11L, reingests = character(), registry_driven = FALSE,
       change = "Bootstrap-safe migrations and sequence-aware annotated year-axis selection."),
  list(version = 12L,
       reingests = c("economic_annex", "payments", "exchange_houses", "credit_survey",
                     "direct_investment", "insurance_annex", "bcp_fx_daily", "exchange_rates",
                     "banking_indicators", "financial_indicators", "interbank_market",
                     "lrm_auctions", "compensatory_fx_sales", "liquidity_facility", "eve"),
       registry_driven = TRUE,
       change = "Sheet-stable series identity, sheet continuation groups, bounded year blocks, the credit-survey period axis, EVE slug scalars and the CUADRO 61 parser."),
  list(version = 13L, reingests = "credit_survey", registry_driven = TRUE,
       change = "Credit-survey question headers, cross-release identity migration and aliases, table reconciliation and a blocking release gate."),
  list(version = 14L,
       reingests = c("economic_annex", "insurance_annex", "direct_investment", "banking_indicators",
                     "financial_indicators", "exchange_rates", "payments", "exchange_houses"),
       registry_driven = TRUE,
       change = "Bounded horizontal period axis, provisional markers out of series identity, semantic measurement metadata, period bounds and availability."),
  list(version = 15L, reingests = character(), registry_driven = TRUE,
       change = "Cell-level reconciliation classification and hard gate, validated-mart isolation and join repairs, fail-closed identity resolution, governance drift detection. Changes no observation."),
  list(version = 16L, reingests = "economic_annex", registry_driven = TRUE,
       change = "Reconciliation coordinate translation between the cropped raw layer and A1 parser coordinates, and footnote-marked month labels on the vertical period axis."),
  list(version = 17L,
       reingests = c("economic_annex", "financial_indicators", "payments", "banking_indicators",
                     "bcp_fx_daily", "interbank_market"),
       registry_driven = TRUE,
       change = "Late-starting data columns admitted by shape rather than density, and the published month-year spellings the period-label pattern was missing."),
  list(version = 18L, reingests = c("bcp_fx_daily", "economic_annex"), registry_driven = TRUE,
       change = "Text day-month-year period labels and loose month-year separators."),
  list(version = 19L, reingests = character(), registry_driven = TRUE,
       change = "Portable repository-relative source URIs, explicit economic dimensions for detailed trade, and measurement semantics derived from published text with the wording recorded. Changes no observation."),
  list(version = 20L, reingests = character(), registry_driven = TRUE,
       change = "BIGINT surrogate keys carry the physical fact grain, replacing a primary-key index over two long text columns. Human identifiers stay on every fact row and stay unique in the dimensions. Changes no observation."),
  list(version = 21L, reingests = character(), registry_driven = TRUE,
       change = "Every table moves into the storage layer that says what it is for -- raw, staging, canonical, marts or audit -- and the research interface is published under marts. Changes no observation."),
  list(version = 22L, reingests = character(), registry_driven = TRUE,
       change = "Every stored view and macro is written with its dependencies schema-qualified, so the published interface works from a default connection instead of one this project configured for itself. A lint reads the stored SQL back and a gate executes every object with no search path set. Changes no observation."),
  list(version = 23L,
       reingests = c("economic_annex", "payments", "interbank_market",
                     "compensatory_fx_sales", "financial_indicators"),
       registry_driven = TRUE,
       change = "The recorded parser defects are repaired: a published column is admitted on the header the publisher printed for it rather than on how busy it is, an undated row beneath a dated one is read as an event with the trade date inherited and an operation sequence, and an irregular sub-annual interval label resolves to a period whose opening date is stored. Financial-indicator measure semantics are derived from the published table name, and a unit stated in a title now outranks one inferred from a row label."),
  list(version = 24L,
       reingests = c("compensatory_fx_sales", "payments", "interbank_market", "direct_investment"),
       registry_driven = TRUE,
       change = "One authoritative publication date per vintage, mirrored onto every snapshot and fact rather than decided by whichever parser wrote last, with equality, monotonicity and authority gates. A release is a lifecycle with an accepted state, and every published interface joins through it. Worksheet merge ranges are retained as provenance and admit a headerless column the publisher merged into a headed block. The column-recovery window is the published header span rather than the gap between the first and last confident column. Numeric cells outside every parser region are classified against a reviewed register and block promotion while unreviewed."),
  list(version = 25L, reingests = character(), registry_driven = TRUE,
       change = "Source acquisition provenance is recorded per vintage and gated; an expected-observation grid gives every absent period a reason read off the raw cell layer rather than leaving absence indistinguishable from omission; and the aggregate identities the publisher states are checked against what was parsed. Changes no observation."),
  list(version = 26L, reingests = character(), registry_driven = TRUE,
       change = "The declared natural key of every staging snapshot is enforced by a unique index and asserted at every release together with its required fields; a build identity records the code, configuration and environment behind a release rather than only the files it read; run attempts are retained append-only beside the deterministic release record; and a source with several candidate files can be chosen by recorded hash instead of by modification time. Changes no observation."),
  list(version = 27L,
       reingests = c("economic_annex", "direct_investment", "financial_indicators",
                     "banks", "financial"),
       registry_driven = TRUE,
       change = "Every published interface joins the accepted release, not only the generic series path: the seventeen direct panels, the documented family and both market views ranked whatever had been committed. A unit stated in a table title outranks a count or duration keyword read from a row label, which repairs twelve CUADRO 20 foreign-exchange series stored as counts at scale one under a title reading 'En millones de dólares', and the same defect on the balance-of-payments and budget-execution tables. What the publisher writes instead of a number is read from a reviewed register rather than treated as an empty cell, so 's/m' is recorded as no movement rather than as a blank. The current-value interface carries observation status, so a published projection is distinguishable from an outcome. The year-quarter parser reads a shared year-and-quarter header row together with the year row above it, guarded by the publisher's own arithmetic, which recovers the direct-investment stock tables; and a horizontal axis extends to the end of the last period's block rather than to its label. The direct panels record the physical worksheet row each record came from and store institution and currency codes as the labels they are."),
  list(version = 28L, reingests = character(), registry_driven = TRUE,
       change = "An accepted release is no longer un-accepted in order to rebuild it, and an ingestion attempt is recorded when it starts so a run that dies leaves a record that it ran and failed. An aggregate identity tests component presence separately from the residual instead of reading an absent component as a zero. source_files.release_id is named first_ingested_release_id, and the release context of a query is derived through release_sources, so a reused vintage stops reporting the bundle it arrived in. Availability is recorded by the operator and outranks the date derived from the file. Duplicate value signatures are screened and ranked as evidence for an economist, and a canonical alias that disagrees with its primary blocks the release. Changes no observation."),
  list(version = 29L, reingests = character(), registry_driven = TRUE,
       change = "A catalogue per series grain, so 4,485 event identities and 1,287 curve points stop being counted alongside GDP and the price index. Formula counts and hidden row and column ranges are recorded per worksheet as the workbook behaviour the cell values cannot show, with a drift test for the vintage after this one. Because both are properties of the workbook rather than of a parsed value, every already-archived vintage is filled in from its own archived file rather than re-parsed. Stage timings are keyed by attempt and appended rather than replaced per release, and every release-wide phase is timed rather than only the parsing. Changes no observation."),
  list(version = 30L, reingests = character(), registry_driven = TRUE,
       change = "Publication stops being a mutable status on the source bundle. A release_id hashes the source files, so fourteen attempts spanning four schema versions shared one identifier, and the single attempt among them that failed set that shared row to blocked -- withdrawing the whole published database because the next build broke. A decision is now recorded once per product, source bundle plus build identity, and never rewritten; whether a product is published is a one-row pointer that only an accepted build moves. The release-wide phases run as one transaction, so a build that dies leaves the derived tables it had begun to overwrite intact. Every published object declares whether it is current, all, history or diagnostic, and a current one must descend restrictively from a filtered base relation rather than merely mention the word releases -- which is what let an unfiltered observation view, the projections built on it, the missingness mart and the annual foreign-exchange view pass the lint. The expected grid and missingness carry the vintage they were computed from. Breaking: the default current-value view is realized observations only, and the publisher\'s full current statement including projections is published as v_publisher_statement_latest. Changes no observation."),
  list(version = 31L, reingests = character(), registry_driven = TRUE,
       change = "Reports describe the attempt that produced them rather than every attempt that ever shared the source bundle, and the release compares each generated file with the database beside it, because a report that looks authoritative and is stale misleads more than no report. The provenance queue names, per vintage, which acquisition fields are missing and what each one costs -- separating operator-recorded availability, which every point-in-time claim depends on, from the four fields that only affect re-acquisition. The source-region queue is ordered by the economic weight of the worksheet rather than by how many cells nobody has looked at, so the price index is reviewed before the auction year-sheets. A declared canonical membership is checked for comparability as well as equality: aliases differing in unit, scale or frequency, and aliases that share no period with their primary and have therefore never been tested, block the release. A direct publisher panel reaching an aggregate mart blocks the release while rows that repeat every modelled dimension remain unresolved. Changes no observation."),
  list(version = 32L, reingests = character(), registry_driven = TRUE,
       change = "Grain is declared per worksheet as well as per source, because one grain for a whole workbook was wrong for direct investment, whose Cuadro 5 and Cuadro 7 are country panels inside a source declared scalar. Whether a value was read from a row the publisher hid, and how many formulas its worksheet carries, are queryable per observation rather than reconstructible from a packed range. Every source is selected by the SHA-256 recorded in the registry rather than by file modification time, which is when a file reached this disk and not when it was published; with one candidate file the rule never fires, and with two it now stops the run and names the fix instead of guessing. The database is a distribution artifact with its own recorded identity, so the commit that carries a rebuilt database stops looking like a provenance mismatch. Changes no observation."),
  list(version = 33L, reingests = character(), registry_driven = TRUE,
       change = "A build no longer writes the published database. Schema 30 stopped a failed build withdrawing the product; it could not stop one changing it, because the run and the published database were the same bytes -- published views resolve vintages through the source bundle rather than the build, sources commit one at a time long before the verdict exists, and the schema migrations delete published facts before a run has begun. The run now copies the database to a candidate file, builds there, and renames the candidate into place only if it is accepted, so a blocked or crashed build leaves the published bytes identical and is retained for inspection. The coverage dashboard resolves worksheet-keyed registers exact-over-wildcard through one shared expression instead of three hand-written copies -- it had 256 rows for 242 worksheets, tripling every direct-investment sheet under contradictory grains -- and a duplicated worksheet now blocks the release. The operations manual stops telling operators to edit a release status that has changed nothing since schema 30. Changes no observation."),
  list(version = 34L, reingests = c("corporate_bond_curves", "securities_trades"),
       registry_driven = TRUE,
       change = "Delimited sources account for every row the publisher supplied. Both CSV parsers read permissively and dropped whatever came back NA, recording nothing, so the only loss they could notice was losing everything: three real corporate-bond purchases with a blank volume had been disappearing on every run since the source was added, 312,329 rows in the file against 312,326 in the database. Every row is now accepted or rejected with a declared reason, a partial numeric token is a rejection rather than a number, a structurally broken file is refused whole, and an undeclared rejection reason blocks the release. Every retained vintage is re-hashed against its archived bytes, because a vintage whose workbook is gone is not retained. And an economist can record the review of a series -- definition and evidence, timing and reference-period convention, stock/flow, unit, scale, currency, valuation, nominal/real, seasonal adjustment, hierarchy role and comparability -- which the research-eligibility gate has required since schema 28 with no way to supply it. The register ships empty and a half-finished row blocks the release instead of half-promoting a series. Changes no observation."),
  list(version = 35L, reingests = character(), registry_driven = TRUE,
       change = "Build identity records the package versions that actually ran. It hashed renv.lock, which is a declaration, so two builds against libraries differing from each other and from the lockfile produced the same build_id -- an identity unable to answer the one question it exists for. The update also refuses to build against an environment that differs from the lockfile, with an explicit override that records itself as a flag on the build. Formula cells are recorded per coordinate and exposed per observation: 91,673 cells were a fact about the database, and whether a particular number is a cached formula result was a question the researcher holding it could not ask. No source is re-ingested for it -- formula position is a property of the archived workbook, recovered from it as schema 29 recovered the per-worksheet counts. The expected-grid cost is reported per retained vintage against a budget, so the phase that dominates the run stays measurable as vintages accumulate. Changes no observation."),
  list(version = 36L, reingests = character(), registry_driven = TRUE,
       change = "The as-of interface ranks over every vintage that was ever published rather than the ones the active pointer names. release_id hashes the manifest, so replacing one workbook mints a new bundle whose release_sources set omits the vintage it replaced -- and the as-of macros filtered to the active bundle before ranking, so a superseded vintage left the population entirely and no cutoff could return it. The operations manual's own recipe for retaining a historical workbook produced exactly that state. A history carrier joins release_sources to the immutable accepted decisions in data_releases; the as-of macros descend from it, the current views keep the pointer, and the lint distinguishes the two boundaries so a history object filtered through the pointer fails. The release context stops being a lexical maximum over hashed bundle identifiers taken from the mutable releases.status, and names the accepted product that first admitted each vintage. And the series review register becomes binding: v_research_series and every validated mart now require a review row, and the eligibility gate requires each field to rest on evidence whose basis is reviewed rather than merely on a value that is not the not_reviewed sentinel -- which the derivation layer never writes, so promoting one worksheet would have admitted every series on it with no economic review at all. Seven further register checks: frequency vocabulary, positive scale, plausible base year, self-parenting and hierarchy cycles, unit/currency coherence and future review dates. Changes no observation."),
  list(version = 37L, reingests = "securities_trades", registry_driven = TRUE,
       change = "A trade with an unknown volume is still a trade. Schema 34 stopped three real corporate-bond purchases vanishing and classified them as a missing mandatory dimension, which was right about silent-loss detection and wrong as economics: their date, broker, ISIN, issuer, instrument, market, operation type and currency are all present, and what is absent is one measure. They are now accepted with a null volume and volume_status = 'not_reported', so the transaction count is complete while the volume sum is unchanged; v_securities_daily_activity reports transactions_with_volume beside the sum so the two denominators are visible rather than assumed equal. A malformed volume token is still a rejection, and a blank currency or instrument still is -- those are dimensions the grain is built from, not measures hanging off it. The update takes a single-writer lock and re-checks the SHA-256 of the production file between copying it and swapping the candidate in, so two concurrent runs cannot silently discard one another's release, and a marker closes the window in which neither rename has completed. **This step changes a published count: the securities snapshot moves from 312,326 to 312,329 rows.**"),
  list(version = 38L, reingests = character(), registry_driven = TRUE,
       change = "Reproducibility evidence that matches what actually happened. The environment record covered 19 declared packages out of 61 in the lockfile and no platform at all, so an arm64 macOS build and an x86 Linux build produced identical identities -- and DBI and duckdb, the two packages that write the database, are built under a different R patch release than the one running, which nothing could see. The full lockfile-intersected library is now recorded with each package's Built field, alongside the platform, the OS release and a digest of the loaded namespaces. Distribution artifacts are identified by their bytes: the artifact id hashed a size read while the connection was still open and more rows were still to be written, so the recorded size was 37% out and the identifier was not derivable from the shipped file. The artifact is now recorded after final close with a real SHA-256, and compaction registers the compacted file as a linked transformation of the file it replaced. The discontinuity and gap screens gain row-level worklists -- 38,433 flagged observations summarised into fifteen rows by source could not be investigated. A structured run log survives the process, for the failures that never reach the database. Changes no observation."),
  list(version = 39L, reingests = character(), registry_driven = TRUE,
       change = "The research interface the readiness audit found missing. Monthly series do not share a day convention -- 2,057 dated to month end, 1,757 to day 1, and 164 alternating inside a single series -- and the normalisation that resolves it existed only on v_series_observations, while the documented read path pointed at v_series_latest, which did not carry it. Joining the price index to the exchange rate on `period` therefore returned zero rows with no error and no warning. Both current-value carriers now publish period_start and period_end, `period` keeps the date the publisher printed, the temporal contract is written down, and the release blocks on an unordered bound or a duplicate canonical period. The documented helper returned seven columns with no label, unit or frequency, so v_series_research publishes the full interpretable record on the path researchers are told to use -- including the published table title, the only field separating 1,599 labels that name more than one series, and until now reachable only through a staging table. A wide extraction refuses to guess its join key, and a label that names more than one series is an error rather than a silent choice among the 4,015 scalar series that share one. Exchange-rate units are corrected against the published worksheet titles: the five CUADRO 60c series tagged as a price of foreign currency are index numbers based on January 1995, and the CUADRO 60a euro, Argentine-peso and Brazilian-real quotations do not have a US dollar denominator. Acquisition time is recorded per vintage with the quality of that evidence beside it, so a conservative upper bound is distinguishable from a publisher's release timestamp instead of passing as one. And a release built from an uncommitted tree blocks, with the same explicit override the environment check already had. Changes no observation.")
  ,list(version = 40L, reingests = character(), registry_driven = TRUE,
       change = "Canonical members gain effective dates, precedence and explicit overlap policy; source semantics retain publisher labels and full paths; missingness and panel-resolution contracts become governed inputs; quality flags gain row and series scope; legacy vintages are explicitly snapshot-only; and a nine-view research schema publishes only reviewed, collision-free data while compatibility views remain available. Changes no source observation.")
  ,list(version = 41L, reingests = character(), registry_driven = TRUE,
       change = "A separate append-only assurance ledger admits deterministic high-confidence proposal rows as rule_certified without impersonating human review; every source receives an explicit dataset disposition and forward-acquisition contract; and the research schema becomes a grain-aware nine-view API plus an as-of table macro. Ambiguous rows remain provisional or quarantined. Changes no source observation.")
  ,list(version = 42L, reingests = character(), registry_driven = TRUE,
       change = "The research EEFF panel preserves the publisher's source currency code, currency of origin and reporting unit; its key no longer collapses foreign-origin balances converted to PYG with PYG-origin balances, and release-blocking accounting prevents collided rows from disappearing. Changes no source observation.")
  ,list(version = 43L, reingests = character(), registry_driven = TRUE,
       change = "A comprehensive catalog schema profiles every parser-identified candidate with coverage, lineage, mechanical diagnostics, validation tier and warnings; a separate explore schema exposes mechanically eligible scalar observations and grain-specific event, entity-panel and curve-panel observations without changing research admission. Changes no source observation.")
)

# The audit's P2 test: "operations migration paths and schema version are
# generated/checked against the registry". Regenerated on every release, so the
# runbook describes the database in front of the reader rather than the one it
# was written for.
write_migration_runbook <- function(con, root) {
  if (is.null(root) || !DBI::dbExistsTable(con, "schema_version")) return(invisible(NULL))
  applied <- DBI::dbGetQuery(
    con, "SELECT version, applied_at, description FROM schema_version ORDER BY version"
  )
  if (!nrow(applied)) return(invisible(NULL))
  undeclared <- setdiff(applied$version, vapply(SCHEMA_MIGRATIONS, function(e) e$version, integer(1)))
  if (length(undeclared)) stop(
    "Migration registry: schema version(s) ", paste(undeclared, collapse = ", "),
    " are applied to the database but not declared in SCHEMA_MIGRATIONS.", call. = FALSE
  )
  current <- max(applied$version)
  lines <- c(
    "# Schema migrations",
    "",
    paste0(
      "Generated from the migration registry (`SCHEMA_MIGRATIONS` in ",
      "`scripts/02_extract_raw.R`) and the `schema_version` table on ",
      format(Sys.Date()), ". Do not edit by hand -- `write_migration_runbook()` ",
      "rewrites this file on every release."
    ),
    "",
    paste0("The database is at **schema ", current, "**."),
    "",
    paste(
      "`initialize_database()` applies every version step a database still needs, in order, on",
      "each run. A step that changes how `series_id` is built also invalidates the affected",
      "sources so they re-parse from the immutable raw layer instead of merging into stale",
      "identities; those sources reappear as `needs_v<N>_reingestion` and are re-ingested by the",
      "same run. Back up `database/paraguay_macro_pilot.duckdb` into `database/backups/` before a",
      "migrating run: the migration deletes curated content by design, and the backup is what lets",
      "you diff observation totals source by source afterwards, and what",
      "`build_migration_map.R` compares against."
    ),
    "",
    "| Version | Applied | Re-ingests | Change |",
    "|---|---|---|---|"
  )
  for (i in seq_len(nrow(applied))) {
    entry <- schema_migration_entry(applied$version[[i]])
    sources <- entry$reingests
    reingests <- if (!length(sources)) "nothing" else paste0("`", paste(sources, collapse = "`, `"), "`")
    if (length(sources) == 1L && !grepl("^[a-z_]+$", sources)) reingests <- sources
    lines <- c(lines, paste0(
      "| ", applied$version[[i]], " | ", format(as.Date(applied$applied_at[[i]])), " | ",
      reingests, " | ", entry$change, " |"
    ))
  }
  # Named from the files that exist, not from the schema number: the entry point
  # is whichever upgrade script is actually shipped, and stating a filename that
  # is not there is exactly the drift this file is generated to prevent.
  upgrades <- list.files(file.path(root, "scripts"), pattern = "^upgrade_v1_to_v[0-9]+\\.R$")
  upgrade_entry <- if (length(upgrades)) {
    upgrades[[which.max(as.integer(sub("^upgrade_v1_to_v([0-9]+)\\.R$", "\\1", upgrades)))]]
  } else NA_character_
  lines <- c(
    lines, "",
    "## From a version-1 database",
    "",
    if (is.na(upgrade_entry)) {
      "No version-1 upgrade script is shipped in this release."
    } else paste0(
      "`scripts/", upgrade_entry, "` is the version-1 entry point. It brings the database ",
      "to the current schema by running every step above in order. The original is backed up ",
      "and retained as `.v1_retired`."
    ),
    "",
    "## Recovery from any applied version",
    "",
    paste(
      "Run the normal update: `source(\"run_update.R\")`. `initialize_database()` walks every",
      "step the database is missing, in order, and the table above says which sources each step",
      "sends back through the parser. A fresh database follows the bootstrap path and executes no",
      "historical invalidation; a non-empty database with no recognised schema version fails",
      "closed rather than guessing which migration applies."
    ),
    "",
    paste(
      "After any run that re-ingests a source, record the identity migration with",
      "`Rscript build_migration_map.R database/backups/<the backup taken before the run>",
      "schema_<from> schema_<to>`. The release gate raises `superseded_identifier_unresolved`",
      "and blocks until this is done."
    ),
    ""
  )
  fs::dir_create(file.path(root, "docs"))
  writeLines(lines, file.path(root, "docs", "SCHEMA_MIGRATIONS.md"))
  invisible(lines)
}

schema_migration_entry <- function(version) {
  match <- Filter(function(entry) entry$version == version, SCHEMA_MIGRATIONS)
  if (!length(match)) stop(
    "Migration registry: schema version ", version, " is not declared in SCHEMA_MIGRATIONS. ",
    "Add it there, so the runbook and the invalidation step cannot disagree.", call. = FALSE
  )
  match[[1]]
}

# The sources a version re-ingests, taken from the registry so the runbook and
# the invalidation can never describe different sets.
schema_migration_sources <- function(version) {
  entry <- schema_migration_entry(version)
  if (!isTRUE(entry$registry_driven)) stop(
    "Migration registry: schema version ", version, " keeps a bespoke invalidation body and ",
    "cannot be driven from the registry.", call. = FALSE
  )
  entry$reingests
}

invalidate_documented_sources <- function(con, affected_sources, status_label) {
  source_sql <- paste(vapply(affected_sources, sql_string, character(1)), collapse = ", ")
  series_query <- paste0("SELECT series_id FROM dim_series WHERE source_id IN (", source_sql, ")")
  vintage_query <- paste0("SELECT vintage_id FROM source_files WHERE source_id IN (", source_sql, ")")
  affected_concepts <- if (DBI::dbExistsTable(con, "map_series_concept")) {
    DBI::dbGetQuery(con, paste0(
      "SELECT DISTINCT concept_id FROM map_series_concept WHERE series_id IN (",
      series_query, ") AND mapping_status = 'source_specific_unreviewed'"
    ))$concept_id
  } else character()
  with_project_transaction(con, {
    for (table_name in c("map_series_concept", "fact_series_events", "series_revisions")) {
      if (DBI::dbExistsTable(con, table_name)) DBI::dbExecute(con, paste0(
        "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
        " WHERE series_id IN (", series_query, ")"
      ))
    }
    if (DBI::dbExistsTable(con, "dim_series")) DBI::dbExecute(con, paste0(
      "DELETE FROM dim_series WHERE series_id IN (", series_query, ")"
    ))
    if (DBI::dbExistsTable(con, "dim_concept") && length(affected_concepts)) {
      concept_sql <- paste(vapply(affected_concepts, sql_string, character(1)), collapse = ", ")
      DBI::dbExecute(con, paste0(
        "DELETE FROM dim_concept WHERE concept_id IN (", concept_sql, ") ",
        "AND mapping_status = 'source_specific_unreviewed' ",
        "AND concept_id NOT IN (SELECT concept_id FROM map_series_concept)"
      ))
    }
    # eve_expectations_snapshot is included because append_snapshot() is a no-op
    # when the vintage already has rows; leaving it would silently keep the
    # fragmented snapshot alongside the repaired series. discarded_rows is
    # included because eve_parser() re-inserts the same content-addressed
    # discard_id values on every pass, so re-ingesting an unchanged vintage
    # without clearing them aborts on the primary key.
    for (table_name in c(
      "documented_series_snapshot", "documented_table_catalog", "documented_sheet_drift",
      "documented_series_continuity", "semantic_coverage", "eve_expectations_snapshot",
      "discarded_rows"
    )) if (DBI::dbExistsTable(con, table_name)) DBI::dbExecute(con, paste0(
      "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
      " WHERE vintage_id IN (", vintage_query, ")"
    ))
    DBI::dbExecute(con, paste0(
      "UPDATE source_files SET ingestion_status = ", sql_string(status_label),
      " WHERE source_id IN (", source_sql, ")"
    ))
  })
  invisible(TRUE)
}

# The audit's P0 asks that the observation grain be enforced rather than merely
# observed to hold: today's data has no duplicate or null keys, but nothing stops
# a future parser regression from introducing them. DuckDB cannot add a primary
# key to an existing table, so the constraint is applied by rebuilding the table
# once. The current rows already satisfy it, so this adds a guarantee without
# changing a value -- and refuses to proceed if they ever stop satisfying it.
#
# `value` is deliberately nullable. fact_series_events is a sparse event log:
# when an observation disappears from a source, write_sparse_series() records a
# tombstone with a null value and is_deleted set. The audit anticipated this when
# it asked to "enforce NOT NULL ... separate deletion events if needed", so the
# rule is expressed as a check rather than a column constraint -- a live
# observation must carry a value, a deletion event need not.
#
# Dropping the table takes v_series_latest and everything built on it with it;
# those are recreated a few lines later by create_series_views() and the other
# view builders at the end of initialize_database().
# The audit's F-10: the staging snapshots declare a natural key in the
# documentation and in the validation code, and the database does not know about
# it. Integrity that depends only on the procedure holding is integrity that an
# ad hoc write, an interrupted run or a future parser can break silently.
#
# DuckDB cannot add a primary key to a populated table without rebuilding it, and
# rebuilding six snapshots -- with every view that depends on them -- to gain a
# constraint would be a large risk taken for a small one. A unique index gives
# the substantive half physically, on the table as it stands, and the audit's own
# alternative gives the other half: every declared key and required field is
# asserted at every release, so a violation blocks rather than being discovered
# later by a researcher.
STAGING_NATURAL_KEYS <- list(
  documented_series_snapshot = list(
    key = c("vintage_id", "series_id", "period"),
    required = c("vintage_id", "series_id", "period", "source_id", "source_sheet", "value")
  ),
  bond_curve_snapshot = list(
    key = c("vintage_id", "period", "currency", "risk_rating", "maturity_years"),
    required = c("vintage_id", "period", "currency", "risk_rating", "maturity_years")
  ),
  securities_transactions_snapshot = list(
    key = c("vintage_id", "transaction_id"),
    # local_currency_volume is deliberately absent: since schema 37 a trade the
    # publisher reported without a volume is retained with a null one. What is
    # required is that the row *says which* it is, so a null measure is always an
    # explicit statement rather than an absence a reader has to interpret.
    required = c("vintage_id", "transaction_id", "operation_date", "currency", "instrument",
                 "volume_status")
  ),
  consumer_confidence_snapshot = list(
    key = c("vintage_id", "series_id", "date"),
    required = c("vintage_id", "series_id", "date", "value")
  ),
  eve_expectations_snapshot = list(
    key = c("vintage_id", "series_id", "date"),
    required = c("vintage_id", "series_id", "date", "value")
  ),
  fx_operations_snapshot = list(
    key = c("vintage_id", "series_id", "period"),
    required = c("vintage_id", "series_id", "period", "value")
  ),
  semantic_coverage = list(
    key = c("vintage_id", "source_sheet"),
    required = c("vintage_id", "source_id", "source_sheet")
  )
)

staging_key_index_name <- function(table_name) paste0("ux_", table_name, "_natural_key")

# The direct panels keep the publisher's own columns, and their economic grain is
# source-specific -- date by entity by account on one sheet, by item or by
# currency on the next. Declaring an economic key for each would be this project
# asserting a grain the publisher has not stated, which schema 26 declined to do
# for exactly that reason.
#
# The physical grain is a different claim and a safe one: one row of the
# database is one row of the worksheet. With source_row recorded from schema 27
# that key is enforceable, and it is what makes the 399 duplicated
# raw_banks_canales_person records *representable* -- they are distinct
# published rows, and the open question is which dimension the publisher varies
# between them, not whether the parser invented them.
direct_panel_natural_keys <- function(con) {
  tables <- DBI::dbGetQuery(con, paste(
    "SELECT table_name FROM information_schema.tables",
    "WHERE table_type = 'BASE TABLE' AND table_name LIKE 'raw\\_%' ESCAPE '\\'"
  ))$table_name
  keys <- list()
  for (table_name in tables) {
    columns <- table_column_names(con, table_name)
    if (!all(c("vintage_id", "source_sheet", "source_row") %in% columns)) next
    keys[[table_name]] <- list(
      key = c("vintage_id", "source_sheet", "source_row"),
      required = c("vintage_id", "source_id", "source_sheet", "source_row")
    )
  }
  keys
}

enforce_staging_natural_keys <- function(con) {
  existing <- DBI::dbGetQuery(
    con, "SELECT index_name FROM duckdb_indexes() WHERE is_unique"
  )$index_name
  created <- 0L
  declared <- c(STAGING_NATURAL_KEYS, direct_panel_natural_keys(con))
  for (table_name in names(declared)) {
    if (!DBI::dbExistsTable(con, table_name)) next
    index_name <- staging_key_index_name(table_name)
    if (index_name %in% existing) next
    key <- declared[[table_name]]$key
    if (!all(key %in% table_column_names(con, table_name))) next
    quoted <- paste(vapply(key, function(x) as.character(DBI::dbQuoteIdentifier(con, x)), character(1)), collapse = ", ")
    duplicates <- DBI::dbGetQuery(con, paste0(
      "SELECT count(*) AS n FROM (SELECT 1 FROM ", project_qualified_name(table_name),
      " GROUP BY ", quoted, " HAVING count(*) > 1)"
    ))$n[[1]]
    if (duplicates) stop(
      "Staging key guard: ", table_name, " has ", duplicates, " duplicated (",
      paste(key, collapse = ", "), ") key(s); the declared natural key cannot be enforced ",
      "until they are resolved.", call. = FALSE
    )
    DBI::dbExecute(con, paste0(
      "CREATE UNIQUE INDEX ", DBI::dbQuoteIdentifier(con, index_name),
      " ON ", project_qualified_name(table_name), " (", quoted, ")"
    ))
    created <- created + 1L
  }
  invisible(created)
}

enforce_fact_series_events_grain <- function(con) {
  if (!DBI::dbExistsTable(con, "fact_series_events")) return(invisible(FALSE))
  already_keyed <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM duckdb_constraints()",
    "WHERE table_name = 'fact_series_events' AND constraint_type = 'PRIMARY KEY'"
  ))$n[[1]]
  value_nullable <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM information_schema.columns",
    "WHERE table_name = 'fact_series_events' AND column_name = 'value'",
    "AND is_nullable = 'YES'"
  ))$n[[1]]
  if (already_keyed && value_nullable) return(invisible(FALSE))
  incomplete <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM fact_series_events",
    "WHERE series_id IS NULL OR period IS NULL OR vintage_id IS NULL",
    "OR is_deleted IS NULL OR (value IS NULL AND NOT is_deleted)"
  ))$n[[1]]
  duplicated_keys <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM (SELECT 1 FROM fact_series_events",
    "GROUP BY series_id, period, vintage_id HAVING count(*) > 1)"
  ))$n[[1]]
  if (incomplete || duplicated_keys) stop(
    "Release gate: fact_series_events has ", incomplete, " incomplete row(s) and ",
    duplicated_keys, " duplicated observation key(s); the grain cannot be enforced ",
    "until they are resolved.", call. = FALSE
  )
  DBI::dbExecute(con, paste(
    "CREATE TABLE", project_qualified_name("fact_series_events_keyed"),
    "(series_id VARCHAR NOT NULL, period DATE NOT NULL,",
    "value DOUBLE, vintage_id VARCHAR NOT NULL, publication_date DATE,",
    "value_hash VARCHAR, is_deleted BOOLEAN NOT NULL, source_file VARCHAR,",
    "CHECK (is_deleted OR value IS NOT NULL),",
    "PRIMARY KEY (series_id, period, vintage_id))"
  ))
  DBI::dbExecute(con, paste(
    "INSERT INTO", project_qualified_name("fact_series_events_keyed"),
    "SELECT series_id, period, value, vintage_id,",
    "publication_date, value_hash, is_deleted, source_file FROM fact_series_events"
  ))
  DBI::dbExecute(con, paste("DROP TABLE", project_qualified_name("fact_series_events"), "CASCADE"))
  DBI::dbExecute(con, paste(
    "ALTER TABLE", project_qualified_name("fact_series_events_keyed"),
    "RENAME TO fact_series_events"
  ))
  invisible(TRUE)
}

# The audit's review of OPERATIONS.md: "reviewer fields required by procedure
# are mostly application-enforced; DB CHECK coverage is minimal". apply_table_status()
# already refuses to write a validated row without a reviewer, a date and the
# five evidence answers, but that guard only protects the pipeline's own writes.
# Someone updating table_status by hand in a SQL client bypasses it entirely, and
# a validated row is the one claim in this database that puts a series in front
# of a researcher. The constraint makes the rule structural.
#
# Same rebuild shape as the fact grain above: DuckDB cannot add a CHECK to an
# existing table, so the table is recreated and refilled. It holds thirty rows.
enforce_table_status_evidence_check <- function(con) {
  if (!DBI::dbExistsTable(con, "table_status")) return(invisible(FALSE))
  already_checked <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM duckdb_constraints()",
    "WHERE table_name = 'table_status' AND constraint_type = 'CHECK'"
  ))$n[[1]]
  if (already_checked) return(invisible(FALSE))
  columns <- table_column_names(con, "table_status")
  if (!all(TABLE_STATUS_EVIDENCE_COLUMNS %in% columns)) return(invisible(FALSE))
  offending <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM table_status WHERE status = 'validated' AND (",
    "reviewed_by IS NULL OR reviewed_by = 'unreviewed' OR reviewed_at IS NULL OR",
    "evidence_uri IS NULL OR trim(evidence_uri) = '')"
  ))$n[[1]]
  if (offending) stop(
    "Release gate: ", offending, " validated table_status row(s) lack a reviewer, a review date ",
    "or evidence. Promotion to validated is an economic-review claim and cannot be recorded ",
    "without them.", call. = FALSE
  )
  DBI::dbExecute(con, paste(
    "CREATE TABLE", project_qualified_name("table_status_checked"),
    "(source_id VARCHAR, source_sheet VARCHAR, status VARCHAR,",
    "parser_claim VARCHAR, reviewed_by VARCHAR, reviewed_at DATE, note VARCHAR,",
    paste(paste(TABLE_STATUS_EVIDENCE_COLUMNS, "VARCHAR"), collapse = ", "), ",",
    "CHECK (status <> 'validated' OR (reviewed_by IS NOT NULL AND reviewed_by <> 'unreviewed'",
    "  AND reviewed_at IS NOT NULL AND evidence_uri IS NOT NULL AND trim(evidence_uri) <> '')),",
    "PRIMARY KEY (source_id, source_sheet))"
  ))
  DBI::dbExecute(con, paste(
    "INSERT INTO", project_qualified_name("table_status_checked"),
    "SELECT source_id, source_sheet, status,",
    "coalesce(parser_claim, 'none'), reviewed_by, reviewed_at, note,",
    paste(TABLE_STATUS_EVIDENCE_COLUMNS, collapse = ", "), "FROM table_status"
  ))
  DBI::dbExecute(con, paste("DROP TABLE", project_qualified_name("table_status"), "CASCADE"))
  DBI::dbExecute(con, paste(
    "ALTER TABLE", project_qualified_name("table_status_checked"), "RENAME TO table_status"
  ))
  invisible(TRUE)
}

# --- Surrogate keys for the fact table --------------------------------------
# The audit: "Fact PK indexes long text series/vintage IDs. Correct but
# expensive; consider BIGINT surrogate keys in the physical fact while keeping
# human IDs unique in the dimensions."
#
# It is expensive for a measurable reason. DuckDB implements a primary key as a
# radix tree that stores the key material, and this key was two long text columns
# plus a date -- about 99 bytes per row over 1.2 million rows, which
# DATABASE_STORAGE.md measured at 114 MiB, more than the fact table it indexes.
#
# The text identifiers stay on the fact table. Dropping them would have meant
# rewriting every query in the project that joins or filters on series_id, for a
# saving that is in the index rather than in the columns, and the identifiers are
# what makes a fact row readable when someone is debugging one. What moves is the
# key: (series_sk, period, vintage_sk), three fixed-width values. The text grain
# is still guaranteed unique, by the sk-to-id bijection the guards below enforce
# plus the observation_grain_violated release test, which has always asserted it
# directly.
#
# Surrogate keys are assigned once and never reassigned. A key that moved between
# runs would silently repoint every fact row that carried it, so new dimension
# rows take numbers above the current maximum and existing ones are left alone.
assign_surrogate_keys <- function(con) {
  assignments <- list(
    list(table = "dim_series", key = "series_sk", natural = "series_id"),
    list(table = "source_files", key = "vintage_sk", natural = "vintage_id")
  )
  for (assignment in assignments) {
    if (!DBI::dbExistsTable(con, assignment$table)) next
    if (!assignment$key %in% table_column_names(con, assignment$table)) next
    pending <- DBI::dbGetQuery(con, paste0(
      "SELECT count(*) AS n FROM ", assignment$table, " WHERE ", assignment$key, " IS NULL"
    ))$n[[1]]
    if (!pending) next
    DBI::dbExecute(con, paste0(
      "UPDATE ", assignment$table, " SET ", assignment$key, " = numbered.assigned FROM (",
      "  SELECT ", assignment$natural, ",",
      "    (SELECT coalesce(max(", assignment$key, "), 0) FROM ", assignment$table, ")",
      "    + row_number() OVER (ORDER BY ", assignment$natural, ") AS assigned",
      "  FROM ", assignment$table, " WHERE ", assignment$key, " IS NULL",
      ") AS numbered WHERE numbered.", assignment$natural, " = ",
      assignment$table, ".", assignment$natural
    ))
  }
  invisible(TRUE)
}

# Move the fact table onto the surrogate key. Same rebuild shape as the two
# constraint migrations above, because DuckDB cannot change a primary key in
# place; the table is recreated, refilled through a join on the dimensions, and
# renamed. Dropping it takes the dependent views with it, and they are recreated
# by the view builders at the end of initialize_database().
enforce_fact_surrogate_grain <- function(con) {
  if (!DBI::dbExistsTable(con, "fact_series_events")) return(invisible(FALSE))
  if ("series_sk" %in% table_column_names(con, "fact_series_events")) return(invisible(FALSE))
  assign_surrogate_keys(con)
  unresolved <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM fact_series_events f",
    "LEFT JOIN dim_series d ON d.series_id = f.series_id",
    "LEFT JOIN source_files s ON s.vintage_id = f.vintage_id",
    "WHERE d.series_sk IS NULL OR s.vintage_sk IS NULL"
  ))$n[[1]]
  if (unresolved) stop(
    "Release gate: ", unresolved, " observations reference a series or vintage with no ",
    "surrogate key; the fact grain cannot be moved onto one.", call. = FALSE
  )
  DBI::dbExecute(con, paste(
    "CREATE TABLE", project_qualified_name("fact_series_events_sk"),
    "(series_sk BIGINT NOT NULL, period DATE NOT NULL,",
    "vintage_sk BIGINT NOT NULL, series_id VARCHAR NOT NULL, vintage_id VARCHAR NOT NULL,",
    "value DOUBLE, publication_date DATE, value_hash VARCHAR, is_deleted BOOLEAN NOT NULL,",
    "source_file VARCHAR, CHECK (is_deleted OR value IS NOT NULL),",
    "PRIMARY KEY (series_sk, period, vintage_sk))"
  ))
  DBI::dbExecute(con, paste(
    "INSERT INTO", project_qualified_name("fact_series_events_sk"),
    "SELECT d.series_sk, f.period, s.vintage_sk,",
    "f.series_id, f.vintage_id, f.value, f.publication_date, f.value_hash, f.is_deleted,",
    "f.source_file FROM fact_series_events f",
    "JOIN dim_series d ON d.series_id = f.series_id",
    "JOIN source_files s ON s.vintage_id = f.vintage_id"
  ))
  moved <- DBI::dbGetQuery(con, paste(
    "SELECT (SELECT count(*) FROM fact_series_events) AS before,",
    "(SELECT count(*) FROM fact_series_events_sk) AS after"
  ))
  if (moved$before[[1]] != moved$after[[1]]) {
    DBI::dbExecute(con, paste("DROP TABLE", project_qualified_name("fact_series_events_sk")))
    stop(
      "Release gate: moving the fact grain onto surrogate keys would have changed the row ",
      "count from ", moved$before[[1]], " to ", moved$after[[1]], ".", call. = FALSE
    )
  }
  DBI::dbExecute(con, paste("DROP TABLE", project_qualified_name("fact_series_events"), "CASCADE"))
  DBI::dbExecute(con, paste(
    "ALTER TABLE", project_qualified_name("fact_series_events_sk"), "RENAME TO fact_series_events"
  ))
  invisible(TRUE)
}

invalidate_v12_p0_identity_repairs <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!11L %in% versions || 12L %in% versions) return(invisible(FALSE))
  invalidate_documented_sources(
    con, schema_migration_sources(12L), "needs_v12_reingestion"
  )
}

# v13 repairs the credit-survey question-header test, which mis-attributes every
# second sub-question block. Only that source's identities move, so only that
# source is re-ingested.
invalidate_v13_credit_survey_question_headers <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!12L %in% versions || 13L %in% versions) return(invisible(FALSE))
  invalidate_documented_sources(con, schema_migration_sources(13L), "needs_v13_reingestion")
}

# v14 bounds the horizontal period axis and keeps provisional-data markers out
# of series labels. Both live in the shared horizontal extractor, so every
# source that uses it is re-ingested, not only the foreign-trade sheets that
# made the defect visible.
invalidate_v14_horizontal_axis_bounds <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!13L %in% versions || 14L %in% versions) return(invisible(FALSE))
  invalidate_documented_sources(con, schema_migration_sources(14L), "needs_v14_reingestion")
}

# v16 teaches the month axis what the year axis has understood since the CUADRO
# 57a repair: a footnote marker on a period label is still a period label. Only
# economic_annex publishes marked month labels -- 26 distinct ones across 240
# cells -- so only it is re-ingested. CUADRO 59 recovers 480 external-debt
# observations and CUADRO 55 recovers 229, all of them in the most recent years
# of the series.
invalidate_v16_period_footnote_labels <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!15L %in% versions || 16L %in% versions) return(invisible(FALSE))
  invalidate_documented_sources(con, schema_migration_sources(16L), "needs_v16_reingestion")
}

# v17 repairs two more families the cell-level reconciliation exposed, both of
# which were losing published data silently:
#
#   late-starting columns  the vertical-date extractor's density floor dropped
#                          any column the publisher had only just opened.
#                          CUADRO 17 lost four real-exchange-rate partner indices
#                          and SIPAP_04 lost ten payment-band columns.
#   month-year spellings   "mar.-19" (abbreviation with a full stop) and
#                          "sept-25" (four-letter September) were not recognised
#                          as period labels, so CUADRO 56a/56b, 18, 23, 23a and
#                          26 dropped whole rows.
#
# The first lives in documented_extract_vertical_date(), so every source using
# it is re-ingested; the second is in the shared period-label pattern, and only
# economic_annex and financial_indicators publish the affected spellings.
invalidate_v17_column_starts_and_month_spellings <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!16L %in% versions || 17L %in% versions) return(invisible(FALSE))
  invalidate_documented_sources(con, schema_migration_sources(17L), "needs_v17_reingestion")
}

# v18 closes the last two period-label spellings the reconciliation found:
# day-month-year written as text ("30-nov.-20", nine trading days in
# bcp_fx_daily's 2020 worksheet, 108 intervention observations) and a month-year
# with a space inside the separator ("dic- 19*", one month of CUADRO 35).
invalidate_v18_text_day_labels <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!17L %in% versions || 18L %in% versions) return(invisible(FALSE))
  invalidate_documented_sources(con, schema_migration_sources(18L), "needs_v18_reingestion")
}

# v23 re-ingests the sources whose parsers changed. Every one of them is a source
# whose reconciliation recorded published cells the parser did not read, or whose
# measurement semantics were derived from the wrong evidence:
#
#   economic_annex         83 within-year minimum-wage steps on CUADRO 11
#   interbank_market       605 cells: the REPO Tripartito block and the
#                          continuation operations under each dated aggregate
#   payments               3 of 4 cells on CCC 02 and SIPAP_12
#   compensatory_fx_sales  5 published zero totals
#   financial_indicators   no unread cells, but the measure, the unit and the
#                          table title all change
invalidate_v23_parser_repairs <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!22L %in% versions || 23L %in% versions) return(invisible(FALSE))
  invalidate_documented_sources(con, schema_migration_sources(23L), "needs_v23_reingestion")
}

# v24 changes what four sources emit. compensatory_fx_sales stops reading the
# template tail of the current year; payments gains the second QR column on
# SIPAP_12; interbank_market gains three published blocks the recovery window
# could not reach; direct_investment stops emitting the 105 corrupted rows
# Cuadro 5 and Cuadro 7 produced from a data row read as a period header.
# v27 changes what five sources emit. economic_annex gains the final month's
# other two import measures and loses the count units on five monetary tables;
# direct_investment gains the two stock tables in full; financial_indicators
# reclassifies 18,416 's/m' cells; and the two direct panels are re-read to
# record their physical worksheet row and to store codes as text, which is a
# change of column type and so cannot be backfilled in place.
invalidate_v27_publication_and_units <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!26L %in% versions || 27L %in% versions) return(invisible(FALSE))
  affected <- schema_migration_sources(27L)
  # The direct panels are physically replaced rather than invalidated: their
  # tables gain a column and change a column's type, so the rows have to go.
  #
  # Their views go with them, explicitly. DuckDB's CASCADE does not follow a view
  # that reads a dropped table -- the definition survives and fails only when
  # something tries to rebuild on top of it -- so the derived views are named and
  # dropped here. Every one is recreated as the source is re-ingested.
  for (source_id in intersect(affected, c("banks", "financial"))) {
    tables <- DBI::dbGetQuery(con, paste0(
      "SELECT table_name FROM information_schema.tables WHERE table_type = 'BASE TABLE'",
      " AND table_name LIKE 'raw\\_", source_id, "\\_%' ESCAPE '\\'"
    ))$table_name
    derived <- DBI::dbGetQuery(con, paste0(
      "SELECT schema_name, view_name FROM duckdb_views() WHERE NOT internal",
      " AND (view_name LIKE 'v\\_latest\\_raw\\_", source_id, "\\_%' ESCAPE '\\'",
      " OR view_name LIKE 'v\\_", source_id, "\\_%\\_documented' ESCAPE '\\')"
    ))
    for (i in seq_len(nrow(derived))) DBI::dbExecute(con, paste0(
      "DROP VIEW IF EXISTS ", DBI::dbQuoteIdentifier(con, derived$schema_name[[i]]), ".",
      DBI::dbQuoteIdentifier(con, derived$view_name[[i]]), " CASCADE"
    ))
    for (table_name in tables) {
      DBI::dbExecute(con, paste("DROP TABLE IF EXISTS", project_qualified_name(table_name), "CASCADE"))
    }
  }
  invalidate_documented_sources(con, affected, "needs_v27_reingestion")
}

# Schema 34. The delimited parsers now record every row they reject, and a
# reused vintage is never re-parsed -- so without this the accounting would ask
# the existing database a question it cannot answer.
#
# It is not hypothetical, and the first real run proved it: `securities_trades`
# offers 312,329 data rows and its snapshot holds 312,326. The three missing ones
# were dropped by the old parser without a record, so the release correctly
# reported three source rows neither accepted nor rejected and blocked. The rows
# can only be classified by reading the file again.
#
# This is what `reingests` in SCHEMA_MIGRATIONS is for, and declaring it empty
# was the mistake: a step that changes what a parser records has to send that
# parser's sources back through it.
invalidate_v34_row_accounting <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (34L %in% versions) return(invisible(FALSE))
  invalidate_documented_sources(con, schema_migration_sources(34L), "needs_v34_reingestion")
}

# Schema 37, the re-audit's RA2-06. The three blank-volume trades this step
# retains are not in the database to be converted: schema 34 recorded them as
# rejections in discarded_rows and kept them out of the snapshot. Only reading
# the file again produces them, so the source goes back through its parser.
invalidate_v37_trade_retention <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (37L %in% versions) return(invisible(FALSE))
  invalidate_documented_sources(con, schema_migration_sources(37L), "needs_v37_reingestion")
}

invalidate_v24_parser_repairs <- function(con) {
  if (!DBI::dbExistsTable(con, "schema_version") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(FALSE))
  }
  versions <- DBI::dbGetQuery(con, "SELECT version FROM schema_version")$version
  if (!23L %in% versions || 24L %in% versions) return(invisible(FALSE))
  invalidate_documented_sources(con, schema_migration_sources(24L), "needs_v24_reingestion")
}

# v19 records the repository-relative URI of every ingested file beside the
# absolute path it was read from. The audit found all 22 durable paths recorded
# as /Users/... : not portable to another machine, and leaking the operator's
# directory layout to anyone the database is shared with. Existing rows are
# backfilled here rather than re-ingested; the files have not moved, only the way
# they are named has.
backfill_v19_portable_source_uris <- function(con, root) {
  if (is.null(root) || !DBI::dbExistsTable(con, "source_files")) return(invisible(FALSE))
  if (!all(c("source_uri", "archive_uri") %in% table_column_names(con, "source_files"))) {
    return(invisible(FALSE))
  }
  rows <- DBI::dbGetQuery(con, paste(
    "SELECT vintage_id, source_path, archive_path FROM source_files",
    "WHERE source_uri IS NULL OR (archive_path IS NOT NULL AND archive_uri IS NULL)"
  ))
  if (!nrow(rows)) return(invisible(FALSE))
  for (i in seq_len(nrow(rows))) {
    source_uri <- repository_uri(rows$source_path[[i]], root)
    archive_uri <- repository_uri(rows$archive_path[[i]], root)
    DBI::dbExecute(con, paste0(
      "UPDATE source_files SET source_uri = ",
      if (is.na(source_uri)) "NULL" else sql_string(source_uri),
      ", archive_uri = ", if (is.na(archive_uri)) "NULL" else sql_string(archive_uri),
      " WHERE vintage_id = ", sql_string(rows$vintage_id[[i]])
    ))
  }
  invisible(TRUE)
}

# v24 repairs the audit's F-01 in place. Two things are wrong in an existing
# database and neither needs the workbooks re-read to fix:
#
#   the authority   a vintage whose date was pinned by an early parse keeps that
#                   pin even when config/source_vintages.csv now records the
#                   official release date. The authority rule is applied to every
#                   recorded vintage here, once.
#   the mirrors     documented_series_snapshot, the curated snapshots, the raw
#                   panel tables and 1.2 million facts each hold a copy of the
#                   date. The audit found 422 of those copies saying 2026-12-31
#                   while source_files said 2026-07-31. They are refreshed from
#                   the one authoritative row.
reconcile_v24_publication_dates <- function(con, root) {
  if (!DBI::dbExistsTable(con, "source_files")) return(invisible(FALSE))
  vintages <- DBI::dbGetQuery(con, paste(
    "SELECT vintage_id, source_id, source_file, sha256, publication_date, publication_date_source",
    "FROM source_files"
  ))
  for (i in seq_len(nrow(vintages))) {
    item <- list(
      source_id = vintages$source_id[[i]], sha256 = vintages$sha256[[i]],
      source_file = vintages$source_file[[i]]
    )
    resolved <- resolve_vintage_publication_date(item, root)
    if (is.na(resolved$publication_date)) next
    set_source_publication_date(
      con, vintages$vintage_id[[i]], resolved$publication_date, resolved$publication_date_source
    )
  }
  propagate_vintage_publication_date(con)
  settled <- DBI::dbGetQuery(con, paste(
    "SELECT source_id, sha256, publication_date FROM source_files WHERE publication_date IS NOT NULL"
  ))
  for (i in seq_len(nrow(settled))) update_archive_manifest_date(
    root, settled$source_id[[i]], settled$sha256[[i]], as.Date(settled$publication_date[[i]])
  )
  invisible(TRUE)
}

# v24 gives every release already in the database the lifecycle row it never had.
# The honest translation of the historical record is the status the run itself
# recorded: a run that completed, with or without warnings, is a release that was
# accepted; a blocked run is a blocked release. A release with vintages but no run
# record was never validated and stays staged, which is to say invisible -- that
# is the fail-closed answer, and it is the one the audit asks for.
backfill_v24_release_lifecycle <- function(con) {
  if (!DBI::dbExistsTable(con, "releases") || !DBI::dbExistsTable(con, "release_sources")) {
    return(invisible(FALSE))
  }
  DBI::dbExecute(con, paste(
    "INSERT INTO releases",
    "SELECT s.release_id,",
    "  CASE WHEN r.status IN ('completed', 'completed_with_warnings') THEN 'accepted'",
    "       WHEN r.status IS NULL THEN 'staged' ELSE 'blocked' END AS status,",
    "  r.executed_at AS staged_at, r.executed_at AS decided_at, r.source_count,",
    "  r.error_count, r.warning_count,",
    "  CASE WHEN r.status IS NULL THEN NULL ELSE 'schema_24_backfill' END AS decided_by",
    "FROM (SELECT DISTINCT release_id FROM release_sources) s",
    "LEFT JOIN ingestion_runs r USING (release_id)",
    "WHERE s.release_id NOT IN (SELECT release_id FROM releases)"
  ))
  invisible(TRUE)
}

migrate_report_cells_storage <- function(con) {
  object_type <- database_object_type(con, "report_cells")
  if (identical(object_type, "BASE TABLE")) {
    if (DBI::dbExistsTable(con, "report_cells_legacy")) stop(
      "Cannot migrate report_cells: report_cells_legacy already exists.", call. = FALSE
    )
    DBI::dbExecute(con, "ALTER TABLE report_cells RENAME TO report_cells_legacy")
  }
  invisible(TRUE)
}

create_report_cells_view <- function(con) {
  sparse_sql <- paste(
    "SELECT v.vintage_id, v.release_id, v.publication_date, v.source_id,",
    "v.source_file, v.source_sheet, c.row_id, c.column_id,",
    "c.raw_value_text, c.raw_value_num, c.raw_value_date",
    "FROM report_sheet_vintages v JOIN report_cell_values c USING (sheet_version_id)"
  )
  legacy_sql <- if (DBI::dbExistsTable(con, "report_cells_legacy")) {
    " UNION ALL SELECT vintage_id, release_id, publication_date, source_id, source_file, source_sheet, row_id, column_id, raw_value_text, raw_value_num, raw_value_date FROM report_cells_legacy"
  } else ""
  create_project_view(con, "report_cells", paste0(sparse_sql, legacy_sql))
  invisible(TRUE)
}

correct_currency_semantics_in_place <- function(con) {
  if (!DBI::dbExistsTable(con, "dim_currency")) return(invisible(FALSE))
  DBI::dbExecute(con, paste0(
    "UPDATE dim_currency SET ",
    "currency_of_origin = CASE WHEN currency_code = '6900' THEN 'PYG' ",
    "WHEN currency_code IN ('6100', '6200') THEN 'FX' ELSE currency_of_origin END, ",
    "unit_currency = CASE WHEN currency_code IN ('6900', '6200') THEN 'PYG' ",
    "WHEN currency_code = '6100' THEN 'USD' ELSE unit_currency END, ",
    "economic_currency = CASE WHEN currency_code IN ('6900', '6200') THEN 'PYG' ",
    "WHEN currency_code = '6100' THEN 'USD' ELSE economic_currency END ",
    "WHERE currency_code IN ('6100', '6200', '6900')"
  ))
  invisible(TRUE)
}

# Every table the pipeline declares, with its constraints. Lifted out of
# initialize_database() so that relocate_tables_to_storage_layers() can rebuild a
# table in its storage layer from the same declaration, rather than copying it and
# losing the keys and checks on the way.
DATABASE_TABLE_STATEMENTS <- c(
  "CREATE TABLE IF NOT EXISTS schema_version (version INTEGER PRIMARY KEY, applied_at TIMESTAMP, description VARCHAR)",
  "CREATE TABLE IF NOT EXISTS ingestion_runs (release_id VARCHAR PRIMARY KEY, executed_at TIMESTAMP, status VARCHAR, source_count INTEGER, error_count INTEGER, warning_count INTEGER)",
  "CREATE TABLE IF NOT EXISTS ingestion_stage_timings (attempt_id VARCHAR, release_id VARCHAR, vintage_id VARCHAR, source_id VARCHAR, stage VARCHAR, elapsed_seconds DOUBLE, recorded_at TIMESTAMP)",
  "CREATE TABLE IF NOT EXISTS release_sources (release_id VARCHAR, source_id VARCHAR, vintage_id VARCHAR, PRIMARY KEY (release_id, vintage_id))",
  "CREATE TABLE IF NOT EXISTS source_files (vintage_id VARCHAR PRIMARY KEY, first_ingested_release_id VARCHAR, source_id VARCHAR, source_label VARCHAR, publisher VARCHAR, source_format VARCHAR, source_file VARCHAR, source_path VARCHAR, archive_path VARCHAR, sha256 VARCHAR, size_bytes BIGINT, publication_date DATE, publication_date_source VARCHAR, first_ingested_at TIMESTAMP, ingestion_status VARCHAR)",
  "CREATE TABLE IF NOT EXISTS source_sheets (vintage_id VARCHAR, release_id VARCHAR, source_id VARCHAR, source_file VARCHAR, sheet_name VARCHAR, used_rows BIGINT, used_cols BIGINT, content_first_row BIGINT, content_first_col BIGINT, content_last_row BIGINT, content_last_col BIGINT, merge_ranges VARCHAR, formula_cells BIGINT, hidden_rows VARCHAR, hidden_columns VARCHAR, ingest_mode VARCHAR, structure_signature VARCHAR)",
  "CREATE TABLE IF NOT EXISTS structure_checks (vintage_id VARCHAR, release_id VARCHAR, source_id VARCHAR, source_sheet VARCHAR, component VARCHAR, expected_signature VARCHAR, observed_signature VARCHAR, status VARCHAR, checked_at TIMESTAMP)",
  "CREATE TABLE IF NOT EXISTS quality_flags (check_id VARCHAR PRIMARY KEY, attempt_id VARCHAR, release_id VARCHAR, vintage_id VARCHAR, severity VARCHAR, check_name VARCHAR, source_id VARCHAR, source_sheet VARCHAR, detail VARCHAR, created_at TIMESTAMP)",
  "CREATE TABLE IF NOT EXISTS discarded_rows (discard_id VARCHAR PRIMARY KEY, release_id VARCHAR, vintage_id VARCHAR, source_id VARCHAR, source_sheet VARCHAR, row_id BIGINT, reason VARCHAR, raw_label VARCHAR)",
  "CREATE TABLE IF NOT EXISTS report_sheet_versions (sheet_version_id VARCHAR PRIMARY KEY, source_id VARCHAR, source_sheet VARCHAR, structure_signature VARCHAR, raw_nonempty_cells BIGINT, first_vintage_id VARCHAR, created_at TIMESTAMP)",
  "CREATE TABLE IF NOT EXISTS report_sheet_vintages (vintage_id VARCHAR, release_id VARCHAR, publication_date DATE, source_id VARCHAR, source_file VARCHAR, source_sheet VARCHAR, sheet_version_id VARCHAR, PRIMARY KEY (vintage_id, source_sheet))",
  "CREATE TABLE IF NOT EXISTS report_cell_values (sheet_version_id VARCHAR, row_id BIGINT, column_id BIGINT, raw_value_text VARCHAR, raw_value_num DOUBLE, raw_value_date DATE, PRIMARY KEY (sheet_version_id, row_id, column_id))",
  # Schema 35, the seventh audit's F-07. Which workbook cells hold a formula, in
  # the worksheet's own A1 coordinates. Keyed by vintage and sheet name rather
  # than by sheet_version_id, because sheet_version_id hashes the cell *values*
  # and formula position is a property of the file: putting it inside that hash
  # would re-key the whole raw layer for a diagnostic.
  "CREATE TABLE IF NOT EXISTS report_cell_formulas (vintage_id VARCHAR, sheet_name VARCHAR, row_id BIGINT, column_id BIGINT, PRIMARY KEY (vintage_id, sheet_name, row_id, column_id))",
  "CREATE TABLE IF NOT EXISTS documented_table_catalog (vintage_id VARCHAR, source_id VARCHAR, source_sheet VARCHAR, table_title VARCHAR, parser_mode VARCHAR, parse_status VARCHAR, hierarchy_status VARCHAR, raw_nonempty_cells BIGINT, parsed_observations BIGINT, series_count BIGINT, first_period DATE, last_period DATE, unit_summary VARCHAR, coverage_note VARCHAR, PRIMARY KEY (vintage_id, source_sheet))",
  "CREATE TABLE IF NOT EXISTS documented_sheet_drift (vintage_id VARCHAR, previous_vintage_id VARCHAR, source_id VARCHAR, source_sheet VARCHAR, previous_observations BIGINT, current_observations BIGINT, observation_change BIGINT, previous_series BIGINT, current_series BIGINT, series_change BIGINT, drift_status VARCHAR, PRIMARY KEY (vintage_id, source_sheet))",
  "CREATE TABLE IF NOT EXISTS documented_series_continuity (vintage_id VARCHAR, previous_vintage_id VARCHAR, source_id VARCHAR, series_id VARCHAR, source_sheet VARCHAR, change_type VARCHAR, previous_label VARCHAR, current_label VARCHAR, previous_unit VARCHAR, current_unit VARCHAR, previous_scale VARCHAR, current_scale VARCHAR, previous_currency VARCHAR, current_currency VARCHAR, identity_stability VARCHAR, PRIMARY KEY (vintage_id, series_id, change_type))",
  "CREATE TABLE IF NOT EXISTS documented_series_snapshot (vintage_id VARCHAR, release_id VARCHAR, publication_date DATE, source_id VARCHAR, source_file VARCHAR, source_sheet VARCHAR, table_title VARCHAR, parser_mode VARCHAR, series_id VARCHAR, identity_basis VARCHAR, identity_stability VARCHAR, hierarchy_status VARCHAR, period DATE, source_period_label VARCHAR, frequency VARCHAR, series_label VARCHAR, series_path VARCHAR, category VARCHAR, measure VARCHAR, question VARCHAR, response VARCHAR, entity_id VARCHAR, exchange_item_id VARCHAR, participant_id VARCHAR, unit VARCHAR, scale VARCHAR, currency VARCHAR, index_base VARCHAR, value DOUBLE, is_total BOOLEAN, source_row BIGINT, source_column BIGINT, footnote_marker VARCHAR, price_base_year VARCHAR)",
  "CREATE TABLE IF NOT EXISTS semantic_coverage (vintage_id VARCHAR, source_id VARCHAR, source_sheet VARCHAR, semantic_status VARCHAR, raw_nonempty_cells BIGINT, curated_observations BIGINT, coverage_note VARCHAR)",
  "CREATE TABLE IF NOT EXISTS dim_entity (entity_id VARCHAR PRIMARY KEY, entity_code VARCHAR, entity_type VARCHAR, entity_name VARCHAR, legal_name VARCHAR, short_name VARCHAR, ownership_type VARCHAR, mapping_status VARCHAR, first_vintage_id VARCHAR)",
  "CREATE TABLE IF NOT EXISTS dim_currency (currency_code VARCHAR PRIMARY KEY, currency_label VARCHAR, currency_of_origin VARCHAR, unit_currency VARCHAR, economic_currency VARCHAR, description VARCHAR, mapping_status VARCHAR, first_vintage_id VARCHAR)",
  "CREATE TABLE IF NOT EXISTS dim_statement_item (statement_item_id VARCHAR PRIMARY KEY, entity_type VARCHAR, report_code VARCHAR, classification VARCHAR, rubro VARCHAR, sub_rubro VARCHAR, source_label VARCHAR, source_label_normalized VARCHAR, first_vintage_id VARCHAR)",
  "CREATE TABLE IF NOT EXISTS map_statement_account (statement_account_id VARCHAR PRIMARY KEY, entity_type VARCHAR, report_name VARCHAR, classification VARCHAR, rubro VARCHAR, sub_rubro VARCHAR, account_number_raw VARCHAR, account_number VARCHAR, multiplier DOUBLE, first_vintage_id VARCHAR)",
  "CREATE TABLE IF NOT EXISTS dim_ratio (ratio_id VARCHAR PRIMARY KEY, entity_type VARCHAR, classification VARCHAR, rubro VARCHAR, source_label VARCHAR, source_label_normalized VARCHAR, first_vintage_id VARCHAR)",
  "CREATE TABLE IF NOT EXISTS dim_portfolio_item (portfolio_item_id VARCHAR PRIMARY KEY, entity_type VARCHAR, classification VARCHAR, rubro VARCHAR, sub_rubro VARCHAR, source_code VARCHAR, source_code_normalized VARCHAR, first_vintage_id VARCHAR)",
  "CREATE TABLE IF NOT EXISTS map_portfolio_account (portfolio_account_id VARCHAR PRIMARY KEY, entity_type VARCHAR, classification VARCHAR, rubro VARCHAR, sub_rubro VARCHAR, source_code VARCHAR, account_number_raw VARCHAR, account_number VARCHAR, first_vintage_id VARCHAR)",
  "CREATE TABLE IF NOT EXISTS dim_credit_activity (activity_id VARCHAR PRIMARY KEY, activity_code VARCHAR, activity_description VARCHAR, activity_description_normalized VARCHAR, bulletin_sector VARCHAR, first_vintage_id VARCHAR)",
  "CREATE TABLE IF NOT EXISTS dim_credit_sector (credit_sector_id VARCHAR PRIMARY KEY, sector_label VARCHAR, sector_label_normalized VARCHAR, first_vintage_id VARCHAR)",
  "CREATE TABLE IF NOT EXISTS dim_payment_participant (participant_id VARCHAR PRIMARY KEY, bic_code VARCHAR, legal_name VARCHAR, participant_type VARCHAR, first_vintage_id VARCHAR)",
  "CREATE TABLE IF NOT EXISTS dim_exchange_item (exchange_item_id VARCHAR PRIMARY KEY, statement_type VARCHAR, classification VARCHAR, item_label VARCHAR, item_label_normalized VARCHAR, first_vintage_id VARCHAR)",
  "CREATE TABLE IF NOT EXISTS reference_table_loads (vintage_id VARCHAR, source_sheet VARCHAR, source_table VARCHAR, semantic_role VARCHAR, row_count BIGINT, structure_signature VARCHAR, PRIMARY KEY (vintage_id, source_sheet, source_table))",
  "CREATE TABLE IF NOT EXISTS dim_series (series_id VARCHAR PRIMARY KEY, source_id VARCHAR, label VARCHAR, unit VARCHAR, scale VARCHAR, frequency VARCHAR, currency VARCHAR, index_base VARCHAR, hierarchy_level VARCHAR, parent_series_id VARCHAR, is_total BOOLEAN, identity_basis VARCHAR, identity_stability VARCHAR, hierarchy_status VARCHAR, semantic_status VARCHAR, first_vintage_id VARCHAR, price_base_year VARCHAR)",
  "CREATE TABLE IF NOT EXISTS bond_curve_snapshot (vintage_id VARCHAR, release_id VARCHAR, publication_date DATE, source_file VARCHAR, source_row BIGINT, period DATE, currency VARCHAR, risk_rating VARCHAR, maturity_years DOUBLE, zero_coupon_rate DOUBLE, discount_factor DOUBLE, par_rate DOUBLE, beta0 DOUBLE, beta1 DOUBLE, beta2 DOUBLE, beta3 DOUBLE, lambda1 DOUBLE, lambda2 DOUBLE)",
  "CREATE TABLE IF NOT EXISTS securities_transactions_snapshot (vintage_id VARCHAR, release_id VARCHAR, publication_date DATE, source_file VARCHAR, transaction_id VARCHAR, source_row BIGINT, operation_date DATE, broker_tax_id VARCHAR, broker_name VARCHAR, isin VARCHAR, issuer_tax_id VARCHAR, issuer_name VARCHAR, instrument VARCHAR, market VARCHAR, operation_type VARCHAR, local_currency_volume DOUBLE, volume_status VARCHAR, currency VARCHAR, trading_venue VARCHAR)",
  "CREATE TABLE IF NOT EXISTS dim_concept (concept_id VARCHAR PRIMARY KEY, concept_label VARCHAR, concept_domain VARCHAR, definition VARCHAR, unit VARCHAR, scale VARCHAR, frequency VARCHAR, mapping_status VARCHAR, first_vintage_id VARCHAR)",
  "CREATE TABLE IF NOT EXISTS map_series_concept (series_id VARCHAR, concept_id VARCHAR, relationship VARCHAR, mapping_status VARCHAR, evidence VARCHAR, reviewed_by VARCHAR, reviewed_at DATE, first_vintage_id VARCHAR, PRIMARY KEY (series_id, concept_id))",
  "CREATE TABLE IF NOT EXISTS table_status (source_id VARCHAR, source_sheet VARCHAR, status VARCHAR, reviewed_by VARCHAR, reviewed_at DATE, note VARCHAR, PRIMARY KEY (source_id, source_sheet))",
  "CREATE TABLE IF NOT EXISTS fact_series_events (series_sk BIGINT NOT NULL, period DATE NOT NULL, vintage_sk BIGINT NOT NULL, series_id VARCHAR NOT NULL, vintage_id VARCHAR NOT NULL, value DOUBLE, publication_date DATE, value_hash VARCHAR, is_deleted BOOLEAN NOT NULL, source_file VARCHAR, CHECK (is_deleted OR value IS NOT NULL), PRIMARY KEY (series_sk, period, vintage_sk))",
  "CREATE TABLE IF NOT EXISTS series_revisions (revision_id VARCHAR PRIMARY KEY, series_id VARCHAR, period DATE, previous_value DOUBLE, new_value DOUBLE, previous_vintage_id VARCHAR, new_vintage_id VARCHAR, publication_date DATE, absolute_revision DOUBLE)",
  "CREATE TABLE IF NOT EXISTS series_id_migration (migration_id VARCHAR PRIMARY KEY, from_release VARCHAR, to_release VARCHAR, source_id VARCHAR, old_series_id VARCHAR, new_series_id VARCHAR, relationship VARCHAR, match_method VARCHAR, shared_observations BIGINT, old_observations BIGINT, new_observations BIGINT, evidence VARCHAR, reviewed_by VARCHAR, reviewed_at DATE, created_at TIMESTAMP)",
  "CREATE TABLE IF NOT EXISTS source_alias (alias_id VARCHAR PRIMARY KEY, series_id VARCHAR, source_id VARCHAR, alias_kind VARCHAR, alias_value VARCHAR, valid_from DATE, valid_to DATE, evidence VARCHAR, reviewed_by VARCHAR, reviewed_at DATE)",
  "CREATE TABLE IF NOT EXISTS continuity_map (continuity_id VARCHAR PRIMARY KEY, concept_key VARCHAR, from_series_id VARCHAR, to_series_id VARCHAR, relationship VARCHAR, overlap_rule VARCHAR, evidence VARCHAR, reviewed_by VARCHAR, reviewed_at DATE)",
  "CREATE TABLE IF NOT EXISTS table_domains (source_id VARCHAR, source_sheet VARCHAR, domain VARCHAR, subdomain VARCHAR, measure_family VARCHAR, reviewed_by VARCHAR, reviewed_at DATE, note VARCHAR, PRIMARY KEY (source_id, source_sheet))",
  "CREATE TABLE IF NOT EXISTS canonical_series (canonical_series_id VARCHAR PRIMARY KEY, concept_id VARCHAR, definition VARCHAR, domain VARCHAR, subdomain VARCHAR, frequency VARCHAR, unit_code VARCHAR, currency VARCHAR, stock_flow VARCHAR, nominal_real VARCHAR, seasonal_adjustment VARCHAR, transformation VARCHAR, valuation VARCHAR, methodology_regime_id VARCHAR, reviewed_status VARCHAR, reviewed_by VARCHAR, reviewed_at DATE)",
  "CREATE TABLE IF NOT EXISTS map_canonical_series (canonical_series_id VARCHAR, series_id VARCHAR, relationship VARCHAR, evidence VARCHAR, reviewed_by VARCHAR, reviewed_at DATE, PRIMARY KEY (canonical_series_id, series_id))",
  "CREATE TABLE IF NOT EXISTS methodology_regime (regime_id VARCHAR PRIMARY KEY, concept_key VARCHAR, regime_label VARCHAR, change_type VARCHAR, effective_from DATE, effective_to DATE, comparability VARCHAR, evidence VARCHAR, reviewed_by VARCHAR, reviewed_at DATE)",
  "CREATE TABLE IF NOT EXISTS classification_concordance (concordance_id VARCHAR PRIMARY KEY, from_scheme VARCHAR, from_code VARCHAR, to_scheme VARCHAR, to_code VARCHAR, relationship VARCHAR, evidence VARCHAR, reviewed_by VARCHAR, reviewed_at DATE)",
  "CREATE TABLE IF NOT EXISTS missingness_contracts (source_id VARCHAR, source_sheet VARCHAR, contract_type VARCHAR NOT NULL, calendar_frequency VARCHAR, applicability VARCHAR NOT NULL, evidence VARCHAR NOT NULL, reviewed_by VARCHAR NOT NULL, reviewed_at DATE, PRIMARY KEY (source_id, source_sheet))",
  "CREATE TABLE IF NOT EXISTS panel_resolution (resolution_id VARCHAR PRIMARY KEY, table_name VARCHAR NOT NULL, source_sheet VARCHAR NOT NULL, source_row BIGINT NOT NULL, disposition VARCHAR NOT NULL, measure VARCHAR, canonical_source_row BIGINT, evidence VARCHAR NOT NULL, reviewed_by VARCHAR NOT NULL, reviewed_at DATE)",
  "CREATE TABLE IF NOT EXISTS acquisition_contracts (source_id VARCHAR PRIMARY KEY, expected_frequency VARCHAR NOT NULL, acquisition_method VARCHAR NOT NULL, official_landing_page VARCHAR, license_status VARCHAR NOT NULL, retention_policy VARCHAR NOT NULL, provenance_requirement VARCHAR NOT NULL, point_in_time_status VARCHAR NOT NULL, allowed_uses VARCHAR NOT NULL, prohibited_uses VARCHAR NOT NULL, owner VARCHAR NOT NULL, effective_from DATE NOT NULL)",
  "CREATE TABLE IF NOT EXISTS certification_rules (rule_id VARCHAR, rule_version VARCHAR, object_type VARCHAR, assurance_level VARCHAR, description VARCHAR, enabled BOOLEAN, config_hash VARCHAR, PRIMARY KEY (rule_id, rule_version))",
  "CREATE TABLE IF NOT EXISTS certification_decisions (decision_id VARCHAR PRIMARY KEY, object_type VARCHAR NOT NULL, object_id VARCHAR NOT NULL, assurance_level VARCHAR NOT NULL, rule_id VARCHAR, rule_version VARCHAR, evidence_uri VARCHAR NOT NULL, evidence_hash VARCHAR NOT NULL, rationale VARCHAR NOT NULL, decided_at TIMESTAMP NOT NULL, build_id VARCHAR)",
  "CREATE TABLE IF NOT EXISTS rule_certified_series (series_id VARCHAR PRIMARY KEY, research_series_id VARCHAR NOT NULL, canonical_name VARCHAR, definition VARCHAR NOT NULL, definition_evidence_uri VARCHAR NOT NULL, frequency VARCHAR NOT NULL, reference_period_convention VARCHAR NOT NULL, timing_basis VARCHAR NOT NULL, stock_flow VARCHAR NOT NULL, unit_code VARCHAR NOT NULL, scale_multiplier DOUBLE NOT NULL, currency VARCHAR NOT NULL, valuation VARCHAR NOT NULL, nominal_real VARCHAR NOT NULL, price_base_year VARCHAR, seasonal_adjustment VARCHAR NOT NULL, transformation VARCHAR NOT NULL, hierarchy_role VARCHAR NOT NULL, parent_series_id VARCHAR, methodology_regime_id VARCHAR, comparability VARCHAR NOT NULL, assurance_level VARCHAR NOT NULL, certification_rule_id VARCHAR NOT NULL, certification_rule_version VARCHAR NOT NULL, evidence_hash VARCHAR NOT NULL, certified_at TIMESTAMP NOT NULL)",
  "CREATE TABLE IF NOT EXISTS dataset_catalog (dataset_id VARCHAR PRIMARY KEY, source_id VARCHAR NOT NULL, source_label VARCHAR NOT NULL, publisher VARCHAR NOT NULL, source_format VARCHAR NOT NULL, grain VARCHAR NOT NULL, assurance_level VARCHAR NOT NULL, disposition_reason VARCHAR NOT NULL, point_in_time_status VARCHAR NOT NULL, license_status VARCHAR NOT NULL, allowed_uses VARCHAR NOT NULL, prohibited_uses VARCHAR NOT NULL, certification_rule_id VARCHAR, evidence_uri VARCHAR NOT NULL, updated_at TIMESTAMP NOT NULL)",
  # Keyed by (source_id, source_sheet) since schema 32: a source declares one
  # grain under the '*' wildcard and may override it per worksheet, so source_id
  # alone is no longer unique.
  "CREATE TABLE IF NOT EXISTS source_grains (source_id VARCHAR, source_sheet VARCHAR, series_grain VARCHAR, note VARCHAR, reviewed_by VARCHAR, reviewed_at DATE, PRIMARY KEY (source_id, source_sheet))",
  # Identities the publisher states -- in a footnote, or in the block header
  # itself -- and which therefore have to hold in what was parsed. The audit's
  # P1: "Add per-source aggregation identities only where the publisher defines
  # them." Anything else would be this project inventing an accounting rule.
  "CREATE TABLE IF NOT EXISTS aggregate_identities (identity_id VARCHAR PRIMARY KEY, source_id VARCHAR, source_sheet VARCHAR, identity_label VARCHAR, total_column BIGINT, component_columns VARCHAR, tolerance DOUBLE, basis VARCHAR, evidence VARCHAR, reviewed_by VARCHAR, reviewed_at DATE)",
  "CREATE TABLE IF NOT EXISTS table_reconciliation (vintage_id VARCHAR, source_id VARCHAR, source_sheet VARCHAR, release_id VARCHAR, numeric_source_cells BIGINT, accepted_observations BIGINT, rejected_observations BIGINT, documented_exclusions BIGINT, many_to_one_allowance BIGINT, balance_delta BIGINT, status VARCHAR, note VARCHAR, checked_at TIMESTAMP, accepted_cells BIGINT, cell_reuse BIGINT, unmapped_in_region BIGINT, out_of_region_cells BIGINT, PRIMARY KEY (vintage_id, source_sheet))",
  # The audit's P0: the residual has to be resolved cell by cell, not by a
  # scalar count. reconciliation_cell_rules is the reviewed register; the
  # classification table is what it resolved to on this release, so a reviewer
  # can see which rule explained which cell instead of trusting a total.
  "CREATE TABLE IF NOT EXISTS reconciliation_cell_rules (rule_id VARCHAR PRIMARY KEY, source_id VARCHAR, source_sheet VARCHAR, row_from DOUBLE, row_to DOUBLE, column_from DOUBLE, column_to DOUBLE, classification VARCHAR, expected_cells BIGINT, reason VARCHAR, evidence VARCHAR, reviewed_by VARCHAR, reviewed_at DATE)",
  "CREATE TABLE IF NOT EXISTS reconciliation_cell_classification (vintage_id VARCHAR, source_id VARCHAR, source_sheet VARCHAR, row_id BIGINT, column_id BIGINT, classification VARCHAR, rule_id VARCHAR, PRIMARY KEY (vintage_id, source_sheet, row_id, column_id))",
  # The audit's F-03. Reconciliation measures the rectangle the parser consumed,
  # and a numeric cell outside that rectangle was counted and never judged. This
  # register is built from the raw cell layer *independently of what the parser
  # emitted*, which is the only way to say anything about ingestion completeness,
  # and every cell in it resolves to a reviewed classification or to 'unreviewed'.
  "CREATE TABLE IF NOT EXISTS source_region_rules (rule_id VARCHAR PRIMARY KEY, source_id VARCHAR, source_sheet VARCHAR, row_from DOUBLE, row_to DOUBLE, column_from DOUBLE, column_to DOUBLE, classification VARCHAR, expected_cells BIGINT, reason VARCHAR, evidence VARCHAR, reviewed_by VARCHAR, reviewed_at DATE)",
  "CREATE TABLE IF NOT EXISTS source_region_classification (vintage_id VARCHAR, source_id VARCHAR, source_sheet VARCHAR, row_id BIGINT, column_id BIGINT, classification VARCHAR, rule_id VARCHAR, PRIMARY KEY (vintage_id, source_sheet, row_id, column_id))",
  # The audit's F-04. A release is a thing with a lifecycle, not a status string
  # on a run record: sources commit one at a time and are marked completed before
  # the release-wide validation has run, so 'this vintage loaded' and 'this
  # release may be published' are different questions. Every published interface
  # joins through here and shows only an accepted release, so a release that ends
  # blocked never becomes visible and the decision is one atomic UPDATE.
  "CREATE TABLE IF NOT EXISTS releases (release_id VARCHAR PRIMARY KEY, status VARCHAR NOT NULL, staged_at TIMESTAMP, decided_at TIMESTAMP, source_count INTEGER, error_count INTEGER, warning_count INTEGER, decided_by VARCHAR)",
  # The audit's R6-02, and the reason `releases` above stopped being the
  # publication authority.
  #
  # A release_id hashes the source files. That makes it a *source bundle* ID, and
  # it is the right identity for "which files were these". It is the wrong
  # identity for "which database is this", because the parser, the configuration
  # and the schema decide what those files become: fourteen attempts spanning
  # schemas 26 to 29, with materially different observations, all shared one
  # release_id, and `releases` kept only the latest decision for it.
  #
  # The consequence was not theoretical. One of those attempts ended blocked, and
  # because every published view joined `releases.status = 'accepted'`, a failed
  # rebuild of an already-accepted bundle withdrew the entire published database.
  # A build that fails must not be able to un-publish the build that succeeded.
  #
  # So a decision is recorded once per *product* -- bundle plus build identity --
  # and is never rewritten. Whether that product is the published one is a
  # separate, single-row pointer, moved only by a build that was accepted.
  "CREATE TABLE IF NOT EXISTS data_releases (data_release_id VARCHAR PRIMARY KEY, source_bundle_id VARCHAR NOT NULL, build_id VARCHAR NOT NULL, attempt_id VARCHAR, schema_version INTEGER, status VARCHAR NOT NULL, error_count INTEGER, warning_count INTEGER, decided_at TIMESTAMP NOT NULL, decided_by VARCHAR NOT NULL)",
  "CREATE TABLE IF NOT EXISTS active_data_release (singleton BOOLEAN PRIMARY KEY, data_release_id VARCHAR NOT NULL, source_bundle_id VARCHAR NOT NULL, promoted_at TIMESTAMP NOT NULL, promoted_by VARCHAR NOT NULL)",
  # The audit's F-08: release_id hashes the source files and nothing else, so the
  # same release identifier can name two databases built by different code from
  # the same inputs. release_id keeps that meaning -- "these input files" -- and
  # build_id answers the other question, "this database".
  "CREATE TABLE IF NOT EXISTS build_identity (build_id VARCHAR PRIMARY KEY, release_id VARCHAR, git_commit VARCHAR, git_dirty BOOLEAN, schema_version INTEGER, config_digest VARCHAR, code_digest VARCHAR, environment_digest VARCHAR, package_versions_digest VARCHAR, r_version VARCHAR, built_at TIMESTAMP)",
  # Schema 35, the seventh audit's F-09. environment_digest hashes renv.lock --
  # what the environment was declared to be. This records what it was: one row
  # per package the project loads, as reported by the running session. A build
  # against a drifted library is now a different build_id and can also be
  # diffed against the one before it, package by package.
  "CREATE TABLE IF NOT EXISTS build_environment (build_id VARCHAR, package VARCHAR, version VARCHAR, recorded_at TIMESTAMP, PRIMARY KEY (build_id, package))",
  # The audit's R6-18. The database file is itself a distributed artifact, and
  # nothing recorded its identity: the commit carrying a rebuilt .duckdb is
  # necessarily later than the build that produced it, which reads as a
  # provenance mismatch until someone works out why. This says so explicitly.
  "CREATE TABLE IF NOT EXISTS distribution_artifacts (artifact_id VARCHAR PRIMARY KEY, build_id VARCHAR, data_release_id VARCHAR, artifact_path VARCHAR, size_bytes BIGINT, schema_version INTEGER, recorded_at TIMESTAMP)",
  # Run history, append-only. Re-running the same source bundle rewrites the
  # ingestion_runs row for that release, because a release is deterministic and
  # there is only one of it; an *attempt* is not, and the operational question
  # "what happened the last five times we ran this" had no answer at all.
  "CREATE TABLE IF NOT EXISTS ingestion_run_attempts (attempt_id VARCHAR PRIMARY KEY, release_id VARCHAR, started_at TIMESTAMP, finished_at TIMESTAMP, status VARCHAR, source_count INTEGER, error_count INTEGER, warning_count INTEGER, build_id VARCHAR)",
  # The audit's F-14: a publisher's name is not provenance. Where the file came
  # from, when it was retrieved, under what release identifier and licence, is
  # operator knowledge that no parser can recover, so it is recorded in
  # config/source_vintages.csv and loaded here beside the vintage it describes.
  "CREATE TABLE IF NOT EXISTS source_provenance (vintage_id VARCHAR PRIMARY KEY, source_id VARCHAR, sha256 VARCHAR, official_release_date DATE, official_url VARCHAR, release_identifier VARCHAR, retrieved_at VARCHAR, retrieval_method VARCHAR, license VARCHAR, evidence VARCHAR, recorded_at TIMESTAMP)",
  # An expected observation is a period the series' own frequency says should be
  # there. Absence is then a fact with a reason rather than a silent hole, which
  # is the audit's F-12: a researcher cannot tell "not published" from "the
  # parser did not read it" when both look like a missing row.
  "CREATE TABLE IF NOT EXISTS expected_observation_grid (series_id VARCHAR, period DATE, frequency VARCHAR, PRIMARY KEY (series_id, period))",
  "CREATE TABLE IF NOT EXISTS observation_missingness (series_id VARCHAR, period DATE, source_id VARCHAR, source_sheet VARCHAR, source_row BIGINT, source_column BIGINT, reason VARCHAR NOT NULL, source_token VARCHAR, PRIMARY KEY (series_id, period))",
  # What the publisher writes in a cell instead of a number, and what it means.
  # `s/m` is 38,584 cells of this database saying "sin movimiento"; before this
  # register the code read only the numeric value and recorded every one of them
  # as a blank, which is the opposite of what the publisher said.
  "CREATE TABLE IF NOT EXISTS source_value_tokens (source_id VARCHAR, source_sheet VARCHAR, token VARCHAR, status VARCHAR NOT NULL, meaning VARCHAR, evidence VARCHAR, reviewed_by VARCHAR, reviewed_at DATE, PRIMARY KEY (source_id, source_sheet, token))",
  # Why a measurement field holds the value it does. 'reviewed' rows are
  # written by an economist and are never touched by the pipeline; everything
  # else is derived from published text and says which text.
  "CREATE TABLE IF NOT EXISTS series_semantic_evidence (series_id VARCHAR, field VARCHAR, value VARCHAR, basis VARCHAR, evidence VARCHAR, derived_at TIMESTAMP, PRIMARY KEY (series_id, field))",
  # Economic dimensions -- product, trade flow, classification scheme, customs
  # regime -- kept out of the row label and out of worksheet position, which is
  # what the audit asks for. Long-form because they are source-specific: trade
  # has a regime, the interbank market has a maturity, and columns on
  # dim_series for each family would be null most of the time.
  "CREATE TABLE IF NOT EXISTS series_dimension (series_id VARCHAR, dimension VARCHAR, value VARCHAR, basis VARCHAR, evidence VARCHAR, derived_at TIMESTAMP, PRIMARY KEY (series_id, dimension))",
  # Schema 34, the seventh audit's section 11.4. The economic review of a series,
  # as an economist records it.
  #
  # series_semantic_evidence has always kept a slot for review -- rows whose basis
  # is 'reviewed' survive every rebuild, where derived ones are deleted and
  # recomputed. Nothing ever wrote one, because there was nowhere to write it
  # from: the project had an output worklist naming what was unreviewed and no
  # input register for the answers. This is that register, loaded from
  # config/series_review.csv, and it holds the whole record rather than only the
  # fields dim_series happens to have columns for.
  "CREATE TABLE IF NOT EXISTS series_review (series_id VARCHAR PRIMARY KEY, definition VARCHAR, definition_evidence_uri VARCHAR, source_semantics VARCHAR, frequency VARCHAR, reference_period_convention VARCHAR, timing_basis VARCHAR, stock_flow VARCHAR, unit_code VARCHAR, scale_multiplier DOUBLE, currency VARCHAR, valuation VARCHAR, nominal_real VARCHAR, price_base_year VARCHAR, seasonal_adjustment VARCHAR, transformation VARCHAR, hierarchy_role VARCHAR, parent_series_id VARCHAR, methodology_regime_id VARCHAR, comparability VARCHAR, availability_convention VARCHAR, reviewed_by VARCHAR, reviewed_at DATE)",
  # Period bounds are a function of the reference period and the series
  # frequency, so v_series_observations derives them rather than storing them on
  # 1.2 million fact rows. An irregular published interval is the exception: no
  # frequency implies "in force from 1 January to 30 June 1980", and CUADRO 11
  # publishes 83 of them. Only those rows are stored, with the published label
  # they were read from, and the view falls back to the derived bound everywhere
  # else -- so the fact table, its grain and its primary key are untouched.
  "CREATE TABLE IF NOT EXISTS series_period_bounds (series_id VARCHAR, period DATE, period_start DATE NOT NULL, basis VARCHAR, evidence VARCHAR, derived_at TIMESTAMP, PRIMARY KEY (series_id, period))",
  # The published table title at series grain. It is carried per observation on
  # documented_series_snapshot, which is a staging table, so the one field that
  # separates `PIB a precios de comprador` on CUADRO 6 from the same label on
  # CUADRO 7 was unreachable from the documented read path. Resolved to one row
  # per series here, with a flag where the publisher's own title changed between
  # vintages, so the join into the research view stays one-to-one. Schema 39.
  "CREATE TABLE IF NOT EXISTS series_titles (series_id VARCHAR PRIMARY KEY, table_title VARCHAR, source_sheet VARCHAR, title_varies_by_vintage BOOLEAN, distinct_titles BIGINT, resolved_from_vintage_id VARCHAR)",
  # Reviewed unit, currency and index-base corrections, keyed to the series.
  # Units are inherited at worksheet level, so a worksheet whose columns are not
  # all in the same unit mislabels every column on it -- CUADRO 60c tagged five
  # index numbers as a price of foreign currency. Correcting that through
  # series_review would require asserting the whole economic record for series
  # nobody has reviewed, so the narrow correction gets its own narrow register.
  # Schema 39.
  "CREATE TABLE IF NOT EXISTS unit_overrides (series_id VARCHAR PRIMARY KEY, source_id VARCHAR, source_sheet VARCHAR, unit_code VARCHAR, currency VARCHAR, index_base VARCHAR, scale_multiplier DOUBLE, evidence VARCHAR, reviewed_by VARCHAR, reviewed_at DATE)"
)

# The declared DDL names its tables unqualified; the storage layer each belongs
# to is declared once, in PROJECT_TABLE_SCHEMA, so it cannot drift from the
# assignment the relocation and the audit checks read.
qualify_create_statement <- function(statement) {
  table_name <- sub("^CREATE TABLE IF NOT EXISTS ([A-Za-z0-9_]+) .*$", "\\1", statement)
  if (identical(table_name, statement)) return(statement)
  sub(
    paste0("CREATE TABLE IF NOT EXISTS ", table_name, " "),
    paste0("CREATE TABLE IF NOT EXISTS ", project_qualified_name(table_name), " "),
    statement, fixed = TRUE
  )
}

# Move an existing database into the storage layers.
#
# The tables are recreated in their layer and refilled by name rather than
# renamed, because DuckDB has no ALTER TABLE ... SET SCHEMA. Recreating from the
# declared DDL is what preserves the primary keys, the NOT NULLs and the two
# CHECK constraints; a CREATE TABLE AS SELECT would move the rows and silently
# drop every constraint on them, which on fact_series_events is the observation
# grain itself.
#
# Tables the DDL does not declare -- one per financial worksheet, one per
# reference table -- carry no constraints, because dbWriteTable() created them.
# Those are copied as they stand.
relocate_tables_to_storage_layers <- function(con) {
  in_main <- DBI::dbGetQuery(con, paste(
    "SELECT table_name FROM duckdb_tables()",
    "WHERE schema_name = 'main' AND NOT internal ORDER BY table_name"
  ))$table_name
  movable <- in_main[vapply(in_main, function(x) project_schema_for(x) != "main", logical(1))]
  declared <- stats::setNames(
    lapply(DATABASE_TABLE_STATEMENTS, function(statement) statement),
    vapply(DATABASE_TABLE_STATEMENTS, function(statement) sub(
      "^CREATE TABLE IF NOT EXISTS ([A-Za-z0-9_]+) .*$", "\\1", statement
    ), character(1))
  )
  # A view that has moved into the marts layer still has a copy in main from the
  # release before, and main is first in the search path, so the old one would
  # shadow the new one indefinitely.
  stale_views <- DBI::dbGetQuery(con, paste(
    "SELECT view_name FROM duckdb_views() WHERE schema_name = 'main' AND NOT internal",
    "AND (view_name LIKE 'v\\_mart\\_%' ESCAPE '\\' OR view_name IN",
    "('v_research_series', 'v_catalogue_by_grain'))"
  ))$view_name
  for (view_name in stale_views) DBI::dbExecute(con, paste0(
    "DROP VIEW IF EXISTS main.", DBI::dbQuoteIdentifier(con, view_name), " CASCADE"
  ))
  if (!length(movable)) return(invisible(0L))
  moved <- 0L
  for (table_name in movable) {
    target <- project_qualified_name(table_name)
    quoted_source <- paste0("main.", DBI::dbQuoteIdentifier(con, table_name))
    rebuilt_from_ddl <- !is.null(declared[[table_name]])
    if (rebuilt_from_ddl) {
      DBI::dbExecute(con, qualify_create_statement(declared[[table_name]]))
      # A database old enough to predate one of the target's NOT NULL columns
      # cannot be filled through its current declaration. Those move as a plain
      # copy and get their keys back from the constraint migrations that run
      # afterwards and own them -- enforce_fact_series_events_grain(),
      # enforce_fact_surrogate_grain(), enforce_table_status_evidence_check().
      required <- DBI::dbGetQuery(con, paste0("PRAGMA table_info(", sql_string(target), ")"))
      required <- required$name[required$notnull == 1L]
      present <- DBI::dbGetQuery(
        con, paste0("PRAGMA table_info(", sql_string(paste0("main.", table_name)), ")")
      )$name
      if (length(setdiff(required, present))) {
        DBI::dbExecute(con, paste0("DROP TABLE ", target))
        rebuilt_from_ddl <- FALSE
      }
    }
    if (rebuilt_from_ddl) {
      # Both sides are asked by qualified name. While the move is in progress the
      # same table exists in main and in its layer, and an unqualified lookup
      # resolves to main -- so asking for "the target's columns" would return the
      # source's, and the columns the live table gained through
      # ensure_table_column() would never be added to the copy.
      columns_of <- function(qualified) DBI::dbGetQuery(
        con, paste0("PRAGMA table_info(", sql_string(qualified), ")")
      )
      source_columns <- columns_of(paste0("main.", table_name))
      target_columns <- columns_of(target)$name
      for (i in seq_len(nrow(source_columns))) {
        if (!source_columns$name[[i]] %in% target_columns) DBI::dbExecute(con, paste0(
          "ALTER TABLE ", target, " ADD COLUMN ",
          DBI::dbQuoteIdentifier(con, source_columns$name[[i]]), " ", source_columns$type[[i]]
        ))
      }
      shared <- intersect(source_columns$name, columns_of(target)$name)
      columns <- paste(vapply(shared, function(x) as.character(
        DBI::dbQuoteIdentifier(con, x)
      ), character(1)), collapse = ", ")
      DBI::dbExecute(con, paste0(
        "INSERT INTO ", target, " (", columns, ") SELECT ", columns, " FROM ", quoted_source
      ))
    } else {
      DBI::dbExecute(con, paste0(
        "CREATE TABLE ", target, " AS SELECT * FROM ", quoted_source
      ))
    }
    counts <- DBI::dbGetQuery(con, paste0(
      "SELECT (SELECT count(*) FROM ", quoted_source, ") AS before,",
      " (SELECT count(*) FROM ", target, ") AS after"
    ))
    if (counts$before[[1]] != counts$after[[1]]) stop(
      "Storage layer guard: moving ", table_name, " into ", project_schema_for(table_name),
      " changed the row count from ", counts$before[[1]], " to ", counts$after[[1]], ".",
      call. = FALSE
    )
    DBI::dbExecute(con, paste0("DROP TABLE ", quoted_source, " CASCADE"))
    moved <- moved + 1L
  }
  invisible(moved)
}

initialize_database <- function(con, root = NULL) {
  # The storage layers and the search path come first, before anything asks what
  # is already in this database.
  #
  # They used to come after, and it silently disabled every migration that
  # re-ingests a source. dbExistsTable() resolves through the search path, the
  # pipeline opens its connection with DBI::dbConnect() and sets no path, and
  # schema 21 moved schema_version into audit and source_files into raw -- so on
  # the pipeline's own connection both existence checks answered FALSE, the
  # bootstrap detector concluded this was an empty database, and every
  # `if (!fresh_bootstrap) invalidate_...` step was skipped. A parser repair
  # would have reported success while re-reading nothing.
  #
  # It is the same defect as the one schema 22 fixes in the stored views: code
  # that resolves a name against session state, in a database whose objects
  # moved. The detection below now reads information_schema across every layer
  # through database_object_exists(), so it does not depend on session state at
  # all, and the path is set before it runs so nothing downstream does either.
  for (schema in PROJECT_SCHEMAS) {
    DBI::dbExecute(con, paste0("CREATE SCHEMA IF NOT EXISTS ", schema))
  }
  set_project_search_path(con)
  has_sources <- database_object_exists(con, "source_files")
  has_versions <- database_object_exists(con, "schema_version")
  if (has_sources && !has_versions) {
    stop("A version-1 database was detected. Run source('scripts/upgrade_v1_to_v12.R') once before updating.", call. = FALSE)
  }
  existing_versions <- if (has_versions) {
    DBI::dbGetQuery(con, paste("SELECT version FROM", database_object_qualified_name(con, "schema_version")))$version
  } else integer()
  existing_sources <- has_sources &&
    DBI::dbGetQuery(con, paste(
      "SELECT COUNT(*) AS n FROM", database_object_qualified_name(con, "source_files")
    ))$n[[1]] > 0L
  if (!length(existing_versions) && existing_sources) stop(
    "An unversioned non-empty database was detected. Restore a backup or use the guarded version-1 migration.",
    call. = FALSE
  )
  fresh_bootstrap <- !length(existing_versions) && !existing_sources
  relocate_tables_to_storage_layers(con)
  # Grain is keyed by (source_id, source_sheet) from schema 32, and a primary key
  # cannot be widened in place. source_grains mirrors config/source_grains.csv and
  # is rewritten from it on every run, so dropping it loses nothing that the file
  # does not hold -- which is why this is a drop rather than a careful migration.
  if (DBI::dbExistsTable(con, "source_grains") &&
      !"source_sheet" %in% table_column_names(con, "source_grains")) {
    DBI::dbExecute(con, paste0(
      "DROP TABLE ", database_object_qualified_name(con, "source_grains")
    ))
  }
  statements <- DATABASE_TABLE_STATEMENTS
  invisible(lapply(statements, function(statement) {
    DBI::dbExecute(con, qualify_create_statement(statement))
  }))
  ensure_table_column(con, "source_files", "publisher", "VARCHAR")
  # The durable, portable identity of each ingested file. source_path and
  # archive_path stay as run metadata: true of the machine that ingested it, and
  # of nothing else.
  ensure_table_column(con, "source_files", "source_uri", "VARCHAR")
  # Physical join keys. Human identifiers stay the public ones and stay unique in
  # the dimensions; these exist so the fact table is not keyed on long text.
  ensure_table_column(con, "dim_series", "series_sk", "BIGINT")
  ensure_table_column(con, "source_files", "vintage_sk", "BIGINT")
  ensure_table_column(con, "source_files", "archive_uri", "VARCHAR")
  ensure_table_column(con, "source_files", "source_format", "VARCHAR")
  ensure_table_column(con, "source_files", "first_ingested_at", "TIMESTAMP")
  ensure_table_column(con, "source_files", "publication_date", "DATE")
  ensure_table_column(con, "source_sheets", "content_first_row", "BIGINT")
  ensure_table_column(con, "source_sheets", "content_first_col", "BIGINT")
  ensure_table_column(con, "source_sheets", "content_last_row", "BIGINT")
  ensure_table_column(con, "source_sheets", "content_last_col", "BIGINT")
  # The worksheet's merged rectangles, retained as published provenance. They are
  # what tells a group header spanning a block from a sub-header the publisher
  # left blank, and without them SIPAP_12's second QR column could not be read.
  ensure_table_column(con, "source_sheets", "merge_ranges", "VARCHAR")
  # Workbook behaviour the cell matrix cannot show: how much of the sheet is a
  # cached formula result, and which rows and columns the publisher hid.
  ensure_table_column(con, "source_sheets", "formula_cells", "BIGINT")
  # Timings are kept per attempt, appended, so a slow run can be compared with
  # the one before it. Keyed only by release they were deleted and rewritten
  # every time the same bundle ran, which left exactly one measurement -- of
  # whichever run happened last, usually a reuse run that did almost no work.
  ensure_table_column(con, "ingestion_stage_timings", "attempt_id", "VARCHAR")
  ensure_table_column(con, "source_sheets", "hidden_rows", "VARCHAR")
  ensure_table_column(con, "source_sheets", "hidden_columns", "VARCHAR")
  # A quality flag belongs to the attempt that raised it. Flags used to be
  # deleted wholesale by release_id when a run began, so re-running a bundle
  # erased the diagnostic evidence of the build that had been accepted.
  ensure_table_column(con, "quality_flags", "attempt_id", "VARCHAR")
  # Missingness and the expected grid record which vintage they were computed
  # from, so a diagnostic published in a mart can be filtered to accepted data
  # instead of matching on series_id and hoping -- the audit's R6-01.
  ensure_table_column(con, "expected_observation_grid", "vintage_id", "VARCHAR")
  ensure_table_column(con, "expected_observation_grid", "build_id", "VARCHAR")
  ensure_table_column(con, "observation_missingness", "vintage_id", "VARCHAR")
  ensure_table_column(con, "observation_missingness", "build_id", "VARCHAR")
  # Schema 35, the seventh audit's F-09. The observed library beside the declared
  # one. Null on every build recorded before schema 35, which is the honest
  # answer: those builds did not measure it.
  ensure_table_column(con, "build_identity", "package_versions_digest", "VARCHAR")
  # Schema 37, the re-audit's RA2-06. Whether the publisher reported the volume,
  # beside the volume. Null on rows written before schema 37; the source is
  # re-ingested by this step, so the null does not survive the migration.
  ensure_table_column(con, "securities_transactions_snapshot", "volume_status", "VARCHAR")
  # Schema 38, the re-audit's RA2-10. An artifact identified by its bytes, and
  # linked to the artifact it was derived from. Null on every row written before
  # schema 38: those rows recorded a size read from an open connection, which is
  # why they are 37% short of the file they name.
  ensure_table_column(con, "distribution_artifacts", "sha256", "VARCHAR")
  ensure_table_column(con, "distribution_artifacts", "artifact_role", "VARCHAR")
  ensure_table_column(con, "distribution_artifacts", "derived_from_artifact_id", "VARCHAR")
  # Schema 38, RA2-09. The library and machine a build actually ran on.
  ensure_table_column(con, "build_environment", "built_under", "VARCHAR")
  ensure_table_column(con, "build_environment", "is_direct", "BOOLEAN")
  ensure_table_column(con, "build_environment", "library_path", "VARCHAR")
  ensure_table_column(con, "build_identity", "platform", "VARCHAR")
  ensure_table_column(con, "build_identity", "os_release", "VARCHAR")
  ensure_table_column(con, "build_identity", "loaded_namespaces_digest", "VARCHAR")

  # A vintage can belong to many releases; source_files holds one column, and it
  # is the bundle that first ingested the file. Named as `release_id` beside an
  # observation it read as the release the query had selected, which for a reused
  # vintage it is not. Renamed rather than dropped, because it is still the
  # honest answer to "which run first brought this file in".
  rename_table_column(con, "source_files", "release_id", "first_ingested_release_id")
  # When a researcher could first have had the figure, as recorded by the
  # operator. Distinct from the publication date, which is derived from the file,
  # and from first_ingested_at, which is when this project happened to read it.
  ensure_table_column(con, "source_provenance", "available_at", "TIMESTAMP")
  # How good the availability evidence is, beside the timestamp it qualifies. A
  # publisher's release timestamp and an archive time that merely bounds the
  # acquisition from above are both dates in the same column, and a point-in-time
  # claim that cannot tell them apart is overstating what it knows. Schema 39.
  ensure_table_column(con, "source_provenance", "availability_quality", "VARCHAR")
  ensure_table_column(con, "source_provenance", "snapshot_policy", "VARCHAR")
  # Schema 40 keeps the publisher-facing identity separate from the reviewed
  # research name and makes the full header path queryable at series grain.
  ensure_table_column(con, "dim_series", "source_label", "VARCHAR")
  ensure_table_column(con, "dim_series", "canonical_name", "VARCHAR")
  ensure_table_column(con, "dim_series", "measure_type", "VARCHAR")
  ensure_table_column(con, "dim_series", "full_series_path", "VARCHAR")
  # Canonical composition must say which member wins and when.  These columns
  # are nullable on databases predating schema 40 and are normalized by the
  # governed register loader before a member can be published.
  ensure_table_column(con, "map_canonical_series", "valid_from", "DATE")
  ensure_table_column(con, "map_canonical_series", "valid_to", "DATE")
  ensure_table_column(con, "map_canonical_series", "precedence", "INTEGER")
  ensure_table_column(con, "map_canonical_series", "overlap_policy", "VARCHAR")
  ensure_table_column(con, "canonical_series", "canonical_name", "VARCHAR")
  # A quality issue can now point to the exact object it qualifies rather than
  # surviving only as release prose.
  ensure_table_column(con, "quality_flags", "scope_type", "VARCHAR")
  ensure_table_column(con, "quality_flags", "series_id", "VARCHAR")
  ensure_table_column(con, "quality_flags", "period", "DATE")
  ensure_table_column(con, "quality_flags", "status", "VARCHAR")
  ensure_table_column(con, "quality_flags", "test_version", "VARCHAR")
  ensure_table_column(con, "quality_flags", "waiver_evidence", "VARCHAR")
  # What the publisher wrote in the cell, where there was no number to read. The
  # reason column alone says the status; this says which token produced it, so a
  # reviewer can go from the classification back to the worksheet.
  ensure_table_column(con, "observation_missingness", "source_token", "VARCHAR")
  ensure_table_column(con, "dim_entity", "legal_name", "VARCHAR")
  ensure_table_column(con, "dim_entity", "short_name", "VARCHAR")
  ensure_table_column(con, "dim_entity", "ownership_type", "VARCHAR")
  ensure_table_column(con, "dim_series", "label", "VARCHAR")
  ensure_table_column(con, "dim_series", "unit", "VARCHAR")
  ensure_table_column(con, "dim_series", "scale", "VARCHAR")
  ensure_table_column(con, "dim_series", "frequency", "VARCHAR")
  ensure_table_column(con, "dim_series", "currency", "VARCHAR")
  ensure_table_column(con, "dim_series", "index_base", "VARCHAR")
  ensure_table_column(con, "dim_series", "price_base_year", "VARCHAR")
  ensure_table_column(con, "dim_series", "hierarchy_level", "VARCHAR")
  ensure_table_column(con, "dim_series", "parent_series_id", "VARCHAR")
  ensure_table_column(con, "dim_series", "is_total", "BOOLEAN")
  ensure_table_column(con, "dim_series", "semantic_status", "VARCHAR")
  ensure_table_column(con, "dim_series", "first_vintage_id", "VARCHAR")
  ensure_table_column(con, "dim_currency", "currency_of_origin", "VARCHAR")
  ensure_table_column(con, "dim_currency", "unit_currency", "VARCHAR")
  ensure_table_column(con, "map_statement_account", "account_number_raw", "VARCHAR")
  ensure_table_column(con, "map_portfolio_account", "account_number_raw", "VARCHAR")
  ensure_table_column(con, "reference_currency_snapshot", "currency_of_origin", "VARCHAR")
  ensure_table_column(con, "reference_currency_snapshot", "unit_currency", "VARCHAR")
  ensure_table_column(con, "reference_statement_account_snapshot", "account_number_raw", "VARCHAR")
  ensure_table_column(con, "reference_portfolio_account_snapshot", "account_number_raw", "VARCHAR")
  ensure_table_column(con, "documented_series_snapshot", "exchange_item_id", "VARCHAR")
  ensure_table_column(con, "documented_series_snapshot", "identity_basis", "VARCHAR")
  ensure_table_column(con, "documented_series_snapshot", "identity_stability", "VARCHAR")
  ensure_table_column(con, "documented_series_snapshot", "hierarchy_status", "VARCHAR")
  ensure_table_column(con, "documented_series_snapshot", "footnote_marker", "VARCHAR")
  ensure_table_column(con, "documented_series_snapshot", "price_base_year", "VARCHAR")
  ensure_table_column(con, "documented_table_catalog", "hierarchy_status", "VARCHAR")
  ensure_table_column(con, "dim_series", "identity_basis", "VARCHAR")
  ensure_table_column(con, "dim_series", "identity_stability", "VARCHAR")
  ensure_table_column(con, "dim_series", "hierarchy_status", "VARCHAR")
  ensure_table_column(con, "bond_curve_snapshot", "source_row", "BIGINT")
  ensure_table_column(con, "securities_transactions_snapshot", "source_row", "BIGINT")
  # A validated table is a claim that specific economic questions were answered.
  # Recording which ones lets the gate refuse a validation that skipped any.
  for (evidence_column in TABLE_STATUS_EVIDENCE_COLUMNS) {
    ensure_table_column(con, "table_status", evidence_column, "VARCHAR")
  }
  # What the row claims about the parser, in a closed vocabulary, so the claim
  # can be checked against the reconciliation instead of read by a human who may
  # never come back to it. The audit found eight notes that nobody did.
  ensure_table_column(con, "table_status", "parser_claim", "VARCHAR")
  ensure_table_column(con, "reconciliation_cell_rules", "expected_cells", "BIGINT")
  for (diagnostic in c("accepted_cells", "cell_reuse", "unmapped_in_region", "out_of_region_cells",
                       "classified_cells", "unclassified_cells", "parser_defect_cells")) {
    ensure_table_column(con, "table_reconciliation", diagnostic, "BIGINT")
  }
  # Measurement semantics. scale_multiplier and unit_code are determinate and are
  # derived; the remaining five are economic judgements that no parser can make,
  # so they are created and left at not_reviewed rather than filled with guesses.
  ensure_table_column(con, "dim_series", "unit_code", "VARCHAR")
  ensure_table_column(con, "dim_series", "scale_multiplier", "DOUBLE")
  ensure_table_column(con, "dim_series", "series_grain", "VARCHAR")
  for (judgement in SERIES_SEMANTIC_COLUMNS) {
    ensure_table_column(con, "dim_series", judgement, "VARCHAR")
  }
  # period_start/period_end, available_at and observation_status are exact
  # functions of the reference period, the series frequency and the vintage's
  # publication date, all of which are already stored. They are exposed through
  # v_series_observations rather than copied onto 1.2 million fact rows, so the
  # sparse append path cannot leave them stale.
  correct_currency_semantics_in_place(con)
  if (!fresh_bootstrap) invalidate_v2_curated_content(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 3")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (3, current_timestamp, 'Executable guarded pipeline plus documented bank and finance semantic dimensions')")
  }
  migrate_report_cells_storage(con)
  if (!fresh_bootstrap) invalidate_v3_reference_semantics(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 4")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (4, current_timestamp, 'Correct currency semantics, resilient references and sparse report-cell storage')")
  }
  if (!fresh_bootstrap) invalidate_v4_documented_sources(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 5")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (5, current_timestamp, 'Documented series extraction for the economic annex, payments, exchange houses and credit survey')")
  }
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 6")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (6, current_timestamp, 'Explicit concept governance, bounded anchor search and sheet-level vintage drift diagnostics')")
  }
  if (!fresh_bootstrap) invalidate_v6_documented_identity(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 7")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (7, current_timestamp, 'Stable documented-series identity, continuity and hierarchy warnings, CSV market sources and expanded BCP coverage')")
  }
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 8")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (8, current_timestamp, 'Vectorized documented metadata and identity, single-pass semantic workbook reads and stage timings')")
  }
  if (!fresh_bootstrap) invalidate_v8_ingestion_repairs(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 9")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (9, current_timestamp, 'Real-file ingestion repairs, semantic row-event identities and per-source discovery isolation')")
  }
  if (!fresh_bootstrap) invalidate_v9_runtime_repairs(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 10")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (10, current_timestamp, 'Contextual date and year parsing, empty-sheet bounds, continuity SQL and complete event dimensions')")
  }
  if (!fresh_bootstrap) invalidate_v10_annex_year_axis(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 11")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (11, current_timestamp, 'Bootstrap-safe migrations and sequence-aware annotated year-axis selection')")
  }
  if (!fresh_bootstrap) invalidate_v12_p0_identity_repairs(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 12")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (12, current_timestamp, 'Audit P0 identity repairs: sheet-stable series identity, sheet continuation groups, bounded year blocks, credit-survey period axis, EVE slug scalars and the CUADRO 61 parser')")
  }
  enforce_fact_series_events_grain(con)
  if (!fresh_bootstrap) invalidate_v13_credit_survey_question_headers(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 13")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (13, current_timestamp, 'Audit P0 remediation: cross-release identity migration and aliases, credit-survey question headers, table reconciliation, evidence-bearing research gate and a blocking release gate')")
  }
  if (!fresh_bootstrap) invalidate_v14_horizontal_axis_bounds(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 14")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (14, current_timestamp, 'Audit P1 remediation: bounded horizontal period axis, provisional markers out of series identity, semantic measurement metadata, period bounds and availability')")
  }
  # Schema 15 changes no observation. It replaces the scalar reconciliation
  # exclusion count with a cell-level classification register, isolates the
  # research marts from provisional data, and makes superseded-identifier
  # resolution fail closed instead of returning an arbitrary candidate. Nothing
  # is reingested, so no source is invalidated.
  enforce_table_status_evidence_check(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 15")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (15, current_timestamp, 'Audit P0 round two: cell-level reconciliation classification and hard gate, validated-mart isolation and join repairs, fail-closed identity resolution, governance drift detection')")
  }
  if (!fresh_bootstrap) invalidate_v16_period_footnote_labels(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 16")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (16, current_timestamp, 'Reconciliation coordinate translation between the cropped raw layer and A1 parser coordinates, and footnote-marked month labels on the vertical period axis')")
  }
  if (!fresh_bootstrap) invalidate_v17_column_starts_and_month_spellings(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 17")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (17, current_timestamp, 'Late-starting data columns admitted by shape rather than density, and the published month-year spellings the period-label pattern was missing')")
  }
  if (!fresh_bootstrap) invalidate_v18_text_day_labels(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 18")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (18, current_timestamp, 'Text day-month-year period labels and loose month-year separators')")
  }
  backfill_v19_portable_source_uris(con, root)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 19")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (19, current_timestamp, 'Portable repository-relative source URIs, economic dimensions for detailed trade, and derived measurement semantics with published evidence')")
  }
  assign_surrogate_keys(con)
  enforce_fact_surrogate_grain(con)
  relocate_tables_to_storage_layers(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 20")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (20, current_timestamp, 'BIGINT surrogate keys carry the physical fact grain; human identifiers stay on the row and stay unique in the dimensions')")
  }
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 21")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (21, current_timestamp, 'Raw, staging, canonical, marts and audit storage layers; the research interface is published under marts')")
  }
  create_series_views(con)
  create_report_cells_view(con)
  if (exists("documented_create_views", mode = "function")) documented_create_views(con)
  if (exists("create_concept_views", mode = "function")) {
    sync_source_specific_concepts(con)
    create_concept_views(con)
  }
  if (exists("create_table_status_views", mode = "function")) create_table_status_views(con)
  if (exists("create_market_views", mode = "function")) create_market_views(con)
  if (exists("create_migration_views", mode = "function")) create_migration_views(con)
  recreate_source_derived_views(con)
  # Stamped after the views exist, not before: schema 22 *is* the stored objects
  # carrying their own dependencies, so a run that failed to rewrite them should
  # not be able to claim it.
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 22")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (22, current_timestamp, 'Every stored view and macro carries schema-qualified dependencies; a fresh-connection execution gate blocks the release')")
  }
  # After 22 is stamped, so the guard inside it can require 22 and refuse to run
  # twice, and before the pipeline's ingestion loop, which is what re-reads the
  # sources this marks.
  if (!fresh_bootstrap) invalidate_v23_parser_repairs(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 23")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (23, current_timestamp, 'Recorded parser defects repaired: published columns admitted on their header, continuation rows read as dated events, irregular sub-annual intervals given a stored opening date, and financial-indicator measure semantics derived from the published table name')")
  }
  if (!fresh_bootstrap) invalidate_v24_parser_repairs(con)
  # After the invalidation, so a source about to be re-parsed is not first given
  # a date it is going to recompute, and before the pipeline reads anything: the
  # authority rule and the mirrors are what the equality gate then tests.
  backfill_v24_release_lifecycle(con)
  reconcile_v24_publication_dates(con, root)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 24")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (24, current_timestamp, 'One authoritative publication date per vintage mirrored onto every snapshot and fact; an accepted-release lifecycle every published interface joins through; worksheet merge ranges retained as provenance; the column-recovery window widened to the published header span; and numeric cells outside every parser region classified against a reviewed register that blocks promotion while unreviewed')")
  }
  # Schema 25 changes no observation. It records where each source vintage came
  # from, gives every expected-but-absent period a reason established against the
  # raw cell layer, and checks the aggregate identities the publisher states. All
  # three are populated by the pipeline itself, so nothing is reingested.
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 25")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (25, current_timestamp, 'Source acquisition provenance recorded per vintage and gated, an expected-observation grid that gives every absent period a reason, and the publisher-stated aggregate identities checked against what was parsed')")
  }
  # Schema 26 changes no observation. The unique indexes are built last, after
  # every migration that rewrites a staging table has run, because an index on a
  # table that is about to be dropped and rebuilt would be lost with it.
  enforce_staging_natural_keys(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 26")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (26, current_timestamp, 'Declared staging natural keys enforced by unique index and asserted with their required fields, a build identity recording the code, configuration and environment behind a release, append-only run attempts, and hash-based source file selection')")
  }
  # Last, after every view this migration's new definitions belong to has been
  # written above: the panels it drops take their derived views with them, and
  # both are rebuilt as the sources are re-ingested.
  if (!fresh_bootstrap) invalidate_v27_publication_and_units(con)
  # Schema 28 changes no observation: it is release lifecycle, identity and
  # validation semantics. Its column rename runs with the other ensure/rename
  # steps far above, so nothing is left to do here but stamp it.
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 27")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (27, current_timestamp, 'One accepted-release boundary on every published interface; a unit stated in a table title outranks a keyword read from a row label; published non-numeric tokens read from a reviewed register rather than treated as blanks; observation status carried by the current-value interface; the shared year-and-quarter header read with the year row above it; and direct panels recording their physical worksheet row with codes stored as labels')")
  }
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 28")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (28, current_timestamp, 'An accepted release survives its own rebuild, attempts are recorded when they start, identity components are tested separately from the residual, release context is derived through release_sources rather than read off the vintage, operator-recorded availability outranks the date derived from the file, and duplicate value signatures are screened as ranked evidence')")
  }
  # Schema 29 re-reads no source. Formula counts and hidden ranges are read from
  # the workbook itself, so an already-archived vintage gains them from its own
  # archived file without being parsed again and without an observation moving.
  if (!fresh_bootstrap) backfill_workbook_behaviour(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 29")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (29, current_timestamp, 'A catalogue per series grain, formula and hidden-state provenance recorded per worksheet with a drift test and backfilled onto every archived vintage, and stage timings keyed by attempt with every release-wide phase measured')")
  }
  # Schema 30 moves publication from a mutable status on the source bundle to an
  # immutable decision on the product plus a pointer. Nothing is re-ingested; the
  # database that was published before the migration must still be published
  # after it, so the existing accepted release is adopted as the active product.
  if (!fresh_bootstrap) adopt_active_data_release(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 30")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (30, current_timestamp, 'Publication is a pointer to an immutable data-product decision rather than a mutable status on the source bundle, so a failed rebuild can no longer withdraw the database it failed to replace; the release-wide phases run as one transaction; every published object declares its scope and a current one must descend restrictively from a filtered base relation; the expected grid and missingness carry the vintage they were computed from; and the default current-value view is realized observations only')")
  }
  # Schema 31 changes no observation: it is reporting scope, review queues and
  # two promotion gates that pass vacuously while the registers are empty.
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 31")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (31, current_timestamp, 'Generated reports describe the attempt that produced them and are compared with the database beside them; the provenance and source-region queues are ranked by what they cost rather than by their size; a declared canonical membership must be comparable as well as equal; and a direct publisher panel may not reach an aggregate mart while its rows repeat every modelled dimension')")
  }
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 32")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (32, current_timestamp, 'Per-worksheet grain overrides, per-observation formula and hidden-row provenance, hash-based source selection for every source, and a recorded distribution artifact identity')")
  }
  # Schema 33 changes no stored data. Build isolation is a property of how the
  # pipeline is invoked -- the run builds a candidate file and the swap is the
  # publication -- so there is nothing here to migrate.
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 33")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (33, current_timestamp, 'A build runs in a candidate database and is renamed into place only if it is accepted, so a blocked or crashed run cannot alter the published bytes by any mechanism; the coverage dashboard resolves worksheet-keyed registers exact-over-wildcard and a duplicated worksheet blocks the release; and the release-operations manual describes the publication mechanism the code implements')")
  }
  # Schema 34 sends the two delimited sources back through their parsers, because
  # the rows they now record as rejections were dropped without a record by the
  # parser that ran before it. Everything else in the step is inert: the review
  # register is empty and every archived vintage verifies.
  if (!fresh_bootstrap) invalidate_v34_row_accounting(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 34")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (34, current_timestamp, 'Delimited sources account for every source row as accepted or rejected with a declared reason and fail closed on a partial numeric token; every retained vintage is re-hashed against its archived bytes; and an economist can record the review of a series, which a half-finished row blocks rather than half-applies')")
  }
  # Schema 35 re-reads no source: formula coordinates are a property of the
  # archived workbook and are recovered from it, as schema 29 recovered the
  # per-worksheet counts.
  if (!fresh_bootstrap) backfill_formula_cell_coordinates(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 35")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (35, current_timestamp, 'Build identity records the package versions that actually ran rather than only a hash of the lockfile declaring them, and the update refuses an environment that differs from renv.lock; formula cells are recorded per coordinate and exposed per observation; and the expected-grid cost is reported per vintage against a budget')")
  }
  # Schema 36 changes no stored data: the as-of carrier and the review gate are
  # view and validation definitions, rebuilt on every run.
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 36")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (36, current_timestamp, 'The as-of interface ranks over every vintage that was ever published rather than the ones the active pointer names, so a superseded vintage stays answerable at a cutoff before its replacement; the release context names the accepted product that admitted each vintage instead of a lexical maximum over hashed bundle identifiers; and the series review register becomes binding on the research surface, with the eligibility gate reading reviewed evidence rather than a value that is merely not the not_reviewed sentinel')")
  }
  # Schema 37 re-ingests the securities source: the three blank-volume trades it
  # now retains can only be produced by reading the file again.
  if (!fresh_bootstrap) invalidate_v37_trade_retention(con)
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 37")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (37, current_timestamp, 'A securities trade the publisher reported without a volume is retained with a null volume and an explicit volume_status rather than rejected, because a trade with an unknown size is still a trade; and the update takes a single-writer lock and verifies the production file has not changed between being copied and being replaced')")
  }
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 38")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (38, current_timestamp, 'The recorded environment covers the whole lockfile with each package build and the running platform; distribution artifacts are identified by a SHA-256 taken after final close and compaction registers a linked artifact; the discontinuity and gap screens gain row-level worklists; and a structured run log survives the process')")
  }
  # Schema 39 re-reads no source. The temporal bounds are derived in the view,
  # the table titles are resolved from a snapshot already in the database, and
  # the unit corrections are metadata applied over the derivation -- none of them
  # touches a parsed value, so nothing goes back through a parser.
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 39")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (39, current_timestamp, 'The current-value views carry normalized period bounds, so a cross-source monthly join stops returning an empty sample without saying so; v_series_research publishes the interpretable record, table title included, on the documented read path; the extraction helpers refuse an ambiguous label and an unstated join key; reviewed unit and currency corrections outrank the worksheet default; acquisition time carries the quality of its evidence; and a release built from an uncommitted tree blocks')")
  }
  if (exists("initialize_platform_contracts", mode = "function")) {
    initialize_platform_contracts(con)
  }
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 40")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (40, current_timestamp, 'Governed canonical precedence, scoped quality, explicit snapshot and missingness policy, collision resolution, and a fail-closed research API')")
  }
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 41")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (41, current_timestamp, 'Explicit automated assurance, dataset dispositions, forward acquisition contracts, and a grain-aware research API')")
  }
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 42")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (42, current_timestamp, 'The research EEFF panel preserves source currency code, currency of origin and reporting unit and blocks source-key collisions or row loss instead of filtering them')")
  }
  if (!DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 43")$n[[1]]) {
    DBI::dbExecute(con, "INSERT INTO schema_version VALUES (43, current_timestamp, 'Comprehensive candidate discovery and mechanically gated exploratory access remain separate from unchanged research admission')")
  }
}

# The migration's one job that is not DDL: keep the database published.
#
# Before schema 30 the published set was "vintages of releases whose status is
# accepted". After it, it is "vintages of the source bundle the active pointer
# names". A migration that created the pointer and left it empty would silently
# un-publish every view -- exactly the failure the pointer exists to prevent, in
# its first five minutes -- so the release that was accepted becomes the active
# product, attributed to the build that last wrote it where one is on record.
adopt_active_data_release <- function(con) {
  if (!DBI::dbExistsTable(con, "releases") || !DBI::dbExistsTable(con, "active_data_release")) {
    return(invisible(FALSE))
  }
  if (DBI::dbGetQuery(con, paste(
    "SELECT COUNT(*) AS n FROM", project_qualified_name("active_data_release")
  ))$n[[1]]) return(invisible(FALSE))
  accepted <- DBI::dbGetQuery(con, paste(
    "SELECT release_id, decided_at, error_count, warning_count FROM",
    project_qualified_name("releases"), "WHERE status = 'accepted'",
    "ORDER BY decided_at DESC NULLS LAST LIMIT 1"
  ))
  if (!nrow(accepted)) return(invisible(FALSE))
  bundle <- accepted$release_id[[1]]
  build <- DBI::dbGetQuery(con, paste0(
    "SELECT build_id, schema_version FROM ", project_qualified_name("build_identity"),
    " WHERE release_id = ", sql_string(bundle), " ORDER BY built_at DESC LIMIT 1"
  ))
  product <- if (nrow(build)) build$build_id[[1]] else paste0("build:adopted_", substr(bundle, 9, 32))
  DBI::dbWriteTable(con, "data_releases", tibble(
    data_release_id = product, source_bundle_id = bundle, build_id = product,
    attempt_id = NA_character_,
    schema_version = if (nrow(build)) as.integer(build$schema_version[[1]]) else NA_integer_,
    status = "accepted", error_count = as.integer(accepted$error_count[[1]]),
    warning_count = as.integer(accepted$warning_count[[1]]),
    decided_at = accepted$decided_at[[1]], decided_by = "schema_30_adoption"
  ), append = TRUE)
  DBI::dbWriteTable(con, "active_data_release", tibble(
    singleton = TRUE, data_release_id = product, source_bundle_id = bundle,
    promoted_at = Sys.time(), promoted_by = "schema_30_adoption"
  ), append = TRUE)
  invisible(TRUE)
}

# Whether a cell holds a formula, and whether its row was hidden, are properties
# of the workbook rather than of the value the parser read out of it. They can
# therefore be recovered from the archived file itself: a vintage ingested before
# schema 29 does not have to be re-parsed to gain them, and no observation moves.
#
# Idempotent by construction -- it fills the rows that are still NULL and stops.
# Vintages ingested from schema 29 onward record the columns at ingestion, so on
# a settled database this finds nothing and costs one query.
backfill_workbook_behaviour <- function(con) {
  if (!DBI::dbExistsTable(con, "source_sheets") || !DBI::dbExistsTable(con, "source_files")) {
    return(invisible(0L))
  }
  pending <- DBI::dbGetQuery(con, paste(
    "SELECT DISTINCT s.vintage_id, f.archive_path, f.source_path, f.source_format",
    "FROM source_sheets s JOIN source_files f USING (vintage_id)",
    "WHERE s.formula_cells IS NULL ORDER BY s.vintage_id"
  ))
  if (!nrow(pending)) return(invisible(0L))
  read <- list()
  for (i in seq_len(nrow(pending))) {
    path <- pending$archive_path[[i]]
    if (is.na(path) || !file.exists(path)) path <- pending$source_path[[i]]
    if (is.na(path) || !file.exists(path)) next
    dimensions <- tryCatch(
      if (identical(tolower(pending$source_format[[i]]), "csv")) {
        csv_source_dimensions(path)
      } else xlsx_sheet_dimensions(path),
      error = function(e) NULL
    )
    if (is.null(dimensions) || !"formula_cells" %in% names(dimensions)) next
    read[[length(read) + 1L]] <- tibble(
      vintage_id = pending$vintage_id[[i]], sheet_name = dimensions$sheet_name,
      formula_cells = as.numeric(dimensions$formula_cells),
      hidden_rows = as.character(dimensions$hidden_rows),
      hidden_columns = as.character(dimensions$hidden_columns)
    )
  }
  if (!length(read)) return(invisible(0L))
  behaviour <- dplyr::bind_rows(read)
  DBI::dbWriteTable(con, "workbook_behaviour_backfill", behaviour, temporary = TRUE, overwrite = TRUE)
  updated <- DBI::dbExecute(con, paste(
    "UPDATE", project_qualified_name("source_sheets"), "AS s",
    "SET formula_cells = b.formula_cells, hidden_rows = b.hidden_rows,",
    "hidden_columns = b.hidden_columns",
    "FROM workbook_behaviour_backfill b",
    "WHERE b.vintage_id = s.vintage_id AND b.sheet_name = s.sheet_name",
    "AND s.formula_cells IS NULL"
  ))
  DBI::dbExecute(con, "DROP TABLE IF EXISTS workbook_behaviour_backfill")
  invisible(updated)
}

# The views a *source* owns, rebuilt without re-reading the source.
#
# Most stored objects are created by a function this migration calls directly.
# Three families are not: one view per raw worksheet table, ten documented
# financial views built from those, and the FX-operations annual view. They are
# created as a side effect of ingesting the source they describe, so on a run
# where every vintage is unchanged and reused, they are never rewritten.
#
# That is exactly how schema 22 first failed to land. The migration qualified
# every object it created and reported success while eighteen views it had not
# touched still named their tables bare -- and the lint caught it, which is what
# the lint is for. A migration that rewrites stored SQL has to rewrite all of it,
# not only the part a re-ingestion happens to pass through.
recreate_source_derived_views <- function(con) {
  raw_tables <- DBI::dbGetQuery(con, paste(
    "SELECT table_name FROM information_schema.tables",
    "WHERE table_schema IN ('main', 'raw') AND table_name LIKE 'raw\\_%' ESCAPE '\\'",
    "ORDER BY table_name"
  ))$table_name
  for (table_name in raw_tables) create_latest_raw_view(con, table_name)
  if (exists("create_documented_financial_views", mode = "function")) {
    create_documented_financial_views(con)
  }
  if (database_object_exists(con, "fx_operations_snapshot")) {
    create_fx_operations_annual_views(con)
  }
  invisible(TRUE)
}

# The annual FX-operations surface. It was `SELECT * FROM fx_operations_snapshot
# WHERE frequency = 'annual'` -- no release filter, and no `_all` in the name to
# warn anyone. The audit's R6-01 lists it among the interfaces that would publish
# a staged or blocked vintage, and the lint never looked at it because its name
# matched no rule.
create_fx_operations_annual_views <- function(con) {
  if (!database_object_exists(con, "fx_operations_snapshot")) return(invisible(FALSE))
  body <- function(filter) paste0(
    "SELECT * FROM fx_operations_snapshot WHERE frequency = 'annual'", filter
  )
  create_project_view(con, "v_fx_operations_annual", body(paste0(
    " AND vintage_id IN (", accepted_release_vintages_sql(), ")"
  )))
  create_project_view(con, "v_fx_operations_annual_all", body(""))
  invisible(TRUE)
}

create_series_views <- function(con) {
  # The ranking runs inside the release filter, not outside it. Filtering the
  # result would return nothing for a series whose newest vintage is unpublished;
  # filtering the input returns the newest vintage a researcher may see, which is
  # the question the view is asked.
  # observation_status travels with the row.
  #
  # 343 of these observations are dated after the vintage that published them --
  # 313 in the Economic Annex, of which 148 are CUADRO 49's official monthly
  # projections running to 2028, and 30 in FX operations. v_series_observations
  # has computed the flag since schema 14; this view did not carry it, so the
  # general current-value interface let a 2028 forecast into an estimation sample
  # looking exactly like a realized outcome.
  #
  # Schema 27 kept those rows in v_series_latest and exposed the status beside
  # them, on the reasoning that the view answers "what does the publisher
  # currently say" and a projection is part of that answer. That reasoning is
  # sound and the naming was not: v_series_latest is the obvious default, it is
  # what every example query reaches for, and a researcher who never reads the
  # column gets 2028 forecasts in an estimation sample. The safe-sounding name
  # was the unsafe one, which is the audit's R6-03.
  #
  # So the names now match the contents. v_series_latest is realized observations
  # only. The publisher's full current statement, projections included, is
  # v_publisher_statement_latest -- a name nobody will use by accident. Nothing
  # is hidden and nothing is lost; marts.v_series_projections is still the
  # complement, and v_series_latest_observed remains as a deprecated alias so
  # existing queries keep working and keep meaning the same thing.
  # period_start and period_end travel with the row.
  #
  # The readiness audit's first blocker. The bounds that make a monthly join
  # convention-independent were computed on v_series_observations and nowhere
  # else, while README.md and scripts/05_query_helpers.R send every researcher to
  # v_series_latest -- which carried `period` alone. Joining the price index,
  # dated to day 1, to the exchange rate, dated to month end, therefore returned
  # zero rows through the documented read path: no error, no warning, an empty
  # estimation sample. 164 monthly series alternate between the two conventions
  # inside a single series, which produces wrong lags and wrong differences in
  # any time-series package without ever looking wrong.
  #
  # `period` is untouched. It is the observation key and it is the date the
  # publisher printed; the normalisation is published beside it, not over it.
  # The expression is series_period_bounds_sql(), shared with the observations
  # carrier, because two copies of an interval rule are two answers waiting to
  # disagree.
  latest_body <- function(filter) paste0(
    "WITH ranked AS (SELECT *, row_number() OVER (PARTITION BY series_id, period ",
    "ORDER BY publication_date DESC NULLS LAST, vintage_id DESC) AS rn FROM fact_series_events",
    filter, ") SELECT f.series_id, f.period, ", series_period_bounds_sql(), ", ",
    "f.value, f.vintage_id, f.publication_date, f.source_file, ",
    "CASE WHEN f.publication_date IS NOT NULL AND f.period > f.publication_date ",
    "     THEN 'after_publication' ELSE 'observed' END AS observation_status ",
    # Inner, exactly as v_series_observations joins it: a fact row without a
    # series dimension is a referential defect the release gate blocks, not a
    # row this view should quietly publish with a null frequency.
    "FROM ranked f JOIN dim_series d ON d.series_id = f.series_id ",
    "LEFT JOIN series_period_bounds b ON b.series_id = f.series_id AND b.period = f.period ",
    "WHERE f.rn = 1 AND NOT f.is_deleted"
  )
  # The unfiltered twin, on the project's existing `_all` convention: it is what
  # the ingestion path compares a new vintage against to detect a revision, and
  # what a diagnostic query asks when it wants to see a staged release.
  create_project_view(con, "v_publisher_statement_latest_all", latest_body(""))
  create_project_view(con, "v_publisher_statement_latest", latest_body(paste0(
    " WHERE vintage_id IN (", accepted_release_vintages_sql(), ")"
  )))
  # The research default. observation_status is still carried, so the column that
  # made the distinction visible has not gone anywhere -- it is simply constant
  # here, which is the point.
  create_project_view(con, "v_series_latest", paste(
    "SELECT * FROM v_publisher_statement_latest WHERE observation_status = 'observed'"
  ))
  # Deprecated alias, retained so queries written against schema 27 keep working
  # and keep returning exactly what they returned then.
  create_project_view(con, "v_series_latest_observed", "SELECT * FROM v_series_latest")
  # The diagnostic twin keeps its old name because that is what the ingestion
  # path compares a new vintage against, and it must see unaccepted releases.
  create_project_view(con, "v_series_latest_all", "SELECT * FROM v_publisher_statement_latest_all")
  # Two catalogues, because "how many series does this database have" has two
  # honest answers and the unqualified name should give the published one. It
  # read v_series_latest_all under an unqualified name, which is the audit's
  # open question 3.
  catalogue_body <- function(source) paste0(
    "SELECT d.*, x.first_period, x.last_period, x.observations FROM dim_series d ",
    "JOIN (SELECT series_id, min(period) AS first_period, max(period) AS last_period, ",
    "count(*) AS observations FROM ", source, " GROUP BY 1) x USING (series_id)"
  )
  create_project_view(con, "v_series_catalogue", catalogue_body("v_publisher_statement_latest"))
  create_project_view(con, "v_series_catalogue_all", catalogue_body("v_series_latest_all"))
}

# The attempt currently running, read from the database rather than carried in a
# global. open_ingestion_attempt() writes the row before any work begins, and a
# run has exactly one open attempt, so this is a lookup and not hidden state.
#
# It exists so that a quality flag can be attributed to the attempt that raised
# it without threading attempt_id through the hundred-odd call sites of
# insert_quality_flag(). Flags used to be deleted wholesale by release_id at the
# start of every run, which meant re-running a bundle destroyed the diagnostic
# evidence of the build that had been accepted -- the audit's R6-02.
current_attempt_id <- function(con, release_id) {
  if (!database_object_exists(con, "ingestion_run_attempts")) return(NA_character_)
  open <- DBI::dbGetQuery(con, paste0(
    "SELECT attempt_id FROM ", project_qualified_name("ingestion_run_attempts"),
    " WHERE release_id = ", sql_string(release_id), " AND status = 'running'",
    " ORDER BY started_at DESC LIMIT 1"
  ))
  if (!nrow(open)) NA_character_ else open$attempt_id[[1]]
}

insert_quality_flag <- function(con, release_id, severity, check_name, source_id = NA_character_,
                                detail, vintage_id = NA_character_, source_sheet = NA_character_,
                                scope_type = NULL, series_id = NA_character_, period = as.Date(NA),
                                status = "open", test_version = "schema_40",
                                waiver_evidence = NA_character_) {
  attempt_id <- current_attempt_id(con, release_id)
  key <- paste(
    attempt_id, release_id, vintage_id, severity, check_name, source_id, source_sheet,
    scope_type, series_id, as.character(period), status, test_version, detail, sep = "|"
  )
  check_id <- digest::digest(key, algo = "sha256", serialize = FALSE)
  existing <- DBI::dbGetQuery(con, paste0(
    "SELECT COUNT(*) AS n FROM ", project_qualified_name("quality_flags"),
    " WHERE check_id = ", sql_string(check_id)
  ))$n[[1]]
  if (!existing) DBI::dbWriteTable(
    con, DBI::Id(schema = project_schema_for("quality_flags"), table = "quality_flags"), tibble(
    check_id = check_id, attempt_id = attempt_id, release_id = release_id, vintage_id = vintage_id,
    severity = severity, check_name = check_name, source_id = source_id,
    source_sheet = source_sheet, detail = detail, created_at = Sys.time(),
    scope_type = if (is.null(scope_type)) {
      if (!is.na(series_id)) "series" else if (!is.na(source_sheet)) "table"
      else if (!is.na(source_id)) "source" else if (!is.na(vintage_id)) "vintage" else "release"
    } else scope_type,
    series_id = series_id, period = as.Date(period), status = status,
      test_version = test_version, waiver_evidence = waiver_evidence
    ), append = TRUE
  )
  invisible(check_id)
}

# The flags this attempt raised, which is what a report about this run must show.
attempt_flags_predicate <- function(con, release_id) {
  attempt_id <- current_attempt_id(con, release_id)
  if (is.na(attempt_id)) paste0("release_id = ", sql_string(release_id))
  else paste0("attempt_id = ", sql_string(attempt_id))
}

record_structure_check <- function(con, check, vintage_id, release_id) {
  check <- check %>% mutate(vintage_id = vintage_id, release_id = release_id,
                            checked_at = Sys.time(), .before = 1)
  DBI::dbWriteTable(con, "structure_checks", check, append = TRUE)
}

source_vintage_exists <- function(con, vintage_id) {
  DBI::dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM source_files WHERE vintage_id = ", sql_string(vintage_id)))$n[[1]] > 0
}

record_source_metadata <- function(con, item, dimensions, release_id, root) {
  resolved <- resolve_vintage_publication_date(item, root)
  publication_date <- resolved$publication_date
  publication_source <- resolved$publication_date_source
  archived <- archive_source(item$path, item$source_id, root, item$sha256, publication_date)
  publisher <- if ("publisher" %in% names(item)) as.character(item$publisher[[1]]) else NA_character_
  source_format <- if ("source_format" %in% names(item)) as.character(item$source_format[[1]]) else tools::file_ext(item$path)
  sheet_rows <- dimensions %>% mutate(
    vintage_id = item$vintage_id, release_id = release_id, source_id = item$source_id,
    source_file = item$source_file, ingest_mode = item$ingest_mode,
    structure_signature = NA_character_, .before = 1
  )
  if (!source_vintage_exists(con, item$vintage_id)) {
    info <- file.info(item$path)
    DBI::dbWriteTable(con, "source_files", tibble(
      vintage_id = item$vintage_id, first_ingested_release_id = release_id, source_id = item$source_id,
      source_label = item$source_label, publisher = publisher,
      source_format = source_format, source_file = item$source_file,
      source_path = normalizePath(item$path, winslash = "/"),
      archive_path = normalizePath(archived$path, winslash = "/"),
      source_uri = repository_uri(item$path, root),
      archive_uri = repository_uri(archived$path, root), sha256 = item$sha256,
      size_bytes = as.numeric(info$size), publication_date = publication_date,
      publication_date_source = publication_source, first_ingested_at = Sys.time(),
      ingestion_status = "started"
    ), append = TRUE)
    DBI::dbWriteTable(con, "source_sheets", sheet_rows, append = TRUE)
  } else {
    DBI::dbExecute(con, paste0(
      "UPDATE source_files SET publisher = ", if (is.na(publisher)) "NULL" else sql_string(publisher),
      ", source_format = ", if (is.na(source_format)) "NULL" else sql_string(source_format),
      " WHERE vintage_id = ", sql_string(item$vintage_id)
    ))
    # The date goes through the authority rule rather than being stamped
    # 'filename' unconditionally, which is how a registry date used to be
    # overwritten by a re-run against the same file.
    set_source_publication_date(con, item$vintage_id, publication_date, publication_source)
    DBI::dbExecute(con, paste0("DELETE FROM source_sheets WHERE vintage_id = ", sql_string(item$vintage_id)))
    DBI::dbWriteTable(con, "source_sheets", sheet_rows, append = TRUE)
  }
  record_formula_cell_coordinates(con, item$vintage_id, dimensions)
  # An authoritative date already known before any cell is read is recorded on the
  # archive manifest here, so the manifest, source_files and every mirror agree
  # from the first write rather than after a later repair.
  if (!is.na(publication_date)) {
    update_archive_manifest_date(root, item$source_id, item$sha256, publication_date)
  }
  list(publication_date = publication_date, archive_created = archived$created)
}

# Schema 35, the seventh audit's F-07. Which cells of the workbook hold a formula,
# in the worksheet's own A1 coordinates -- the same coordinates every documented
# observation carries, so the two join directly.
#
# The values are untouched. report_cell_values is content-hashed by
# report_sheet_version_id(), and adding a column there would re-hash the entire
# raw layer for a diagnostic; a side table costs nothing and re-hashes nothing.
record_formula_cell_coordinates <- function(con, vintage_id, dimensions) {
  if (!database_object_exists(con, "report_cell_formulas")) return(invisible(0L))
  coordinates <- xlsx_formula_cell_coordinates(dimensions)
  DBI::dbExecute(con, paste0(
    "DELETE FROM ", project_qualified_name("report_cell_formulas"),
    " WHERE vintage_id = ", sql_string(vintage_id)
  ))
  if (!nrow(coordinates)) return(invisible(0L))
  DBI::dbWriteTable(con, "report_cell_formulas", tibble::tibble(
    vintage_id = vintage_id, sheet_name = coordinates$sheet_name,
    row_id = as.numeric(coordinates$row_id), column_id = as.numeric(coordinates$column_id)
  ), append = TRUE)
  invisible(nrow(coordinates))
}

# The same recovery v29 performed for the per-worksheet counts, at the finer
# grain. Formula position is a property of the workbook, not of a parsed value,
# so every already-archived vintage gains it from its own archived file and no
# source is re-ingested. Idempotent: a vintage whose sheets report formula cells
# and which already has coordinates is skipped.
backfill_formula_cell_coordinates <- function(con) {
  if (!DBI::dbExistsTable(con, "report_cell_formulas")) return(invisible(0L))
  if (!DBI::dbExistsTable(con, "source_sheets")) return(invisible(0L))
  pending <- DBI::dbGetQuery(con, paste(
    "SELECT DISTINCT s.vintage_id, f.archive_path, f.source_path, f.source_format",
    "FROM", project_qualified_name("source_sheets"), "s",
    "JOIN", project_qualified_name("source_files"), "f USING (vintage_id)",
    "WHERE coalesce(s.formula_cells, 0) > 0 AND NOT EXISTS (",
    "  SELECT 1 FROM", project_qualified_name("report_cell_formulas"), "c",
    "  WHERE c.vintage_id = s.vintage_id)",
    "ORDER BY s.vintage_id"
  ))
  if (!nrow(pending)) return(invisible(0L))
  recorded <- 0L
  for (i in seq_len(nrow(pending))) {
    if (identical(tolower(pending$source_format[[i]]), "csv")) next
    path <- pending$archive_path[[i]]
    if (is.na(path) || !file.exists(path)) path <- pending$source_path[[i]]
    if (is.na(path) || !file.exists(path)) next
    dimensions <- tryCatch(xlsx_sheet_dimensions(path), error = function(e) NULL)
    if (is.null(dimensions)) next
    recorded <- recorded + record_formula_cell_coordinates(con, pending$vintage_id[[i]], dimensions)
  }
  invisible(recorded)
}

ensure_failed_source_metadata <- function(con, item, release_id, root = NULL) {
  if (source_vintage_exists(con, item$vintage_id)) {
    DBI::dbExecute(con, paste0(
      "UPDATE source_files SET first_ingested_release_id = ", sql_string(release_id),
      ", ingestion_status = 'failed_structure_or_ingestion' WHERE vintage_id = ",
      sql_string(item$vintage_id)
    ))
    return(invisible(FALSE))
  }
  info <- file.info(item$path)
  publisher <- if ("publisher" %in% names(item)) as.character(item$publisher[[1]]) else NA_character_
  source_format <- if ("source_format" %in% names(item)) as.character(item$source_format[[1]]) else tools::file_ext(item$path)
  DBI::dbWriteTable(con, "source_files", tibble::tibble(
    vintage_id = item$vintage_id, first_ingested_release_id = release_id, source_id = item$source_id,
    source_label = item$source_label, publisher = publisher, source_format = source_format,
    source_file = item$source_file,
    source_path = normalizePath(item$path, winslash = "/", mustWork = FALSE),
    archive_path = NA_character_, source_uri = repository_uri(item$path, root),
    archive_uri = NA_character_, sha256 = item$sha256, size_bytes = as.numeric(info$size),
    publication_date = as.Date(NA), publication_date_source = "discovery_failed",
    first_ingested_at = Sys.time(), ingestion_status = "failed_structure_or_ingestion"
  ), append = TRUE)
  invisible(TRUE)
}

# How much a publication date is worth, by where it came from. An operator who
# read the date off the publisher's release page outranks a filename, and a
# filename outranks anything derived from the cells -- the content is evidence
# about the periods a workbook covers, not about when it was released.
PUBLICATION_DATE_AUTHORITY <- c(
  discovery_failed = 0L,
  pending_content_inference = 0L,
  content_max_period = 1L,
  filename = 2L,
  official_registry = 3L
)

publication_date_authority <- function(source) {
  if (is.null(source) || is.na(source) || !source %in% names(PUBLICATION_DATE_AUTHORITY)) return(0L)
  unname(PUBLICATION_DATE_AUTHORITY[[source]])
}

# The authoritative date for a vintage, before any cell is read: the operator's
# registry if it records one, otherwise the filename. A NA result means the
# parser's content maximum is still the only candidate.
resolve_vintage_publication_date <- function(item, root) {
  registered <- if (is.null(root)) NULL else source_vintage_registry_row(root, item$source_id, item$sha256)
  official <- if (is.null(registered)) NA_character_ else registered$official_release_date
  if (length(official) && !is.na(official) && nzchar(official)) {
    parsed <- suppressWarnings(as.Date(official))
    if (is.na(parsed)) stop(
      "config/source_vintages.csv: official_release_date '", official, "' for ", item$source_id,
      " is not an ISO date.", call. = FALSE
    )
    return(list(publication_date = parsed, publication_date_source = "official_registry"))
  }
  from_name <- infer_publication_date_from_name(item$source_file)
  if (!is.na(from_name)) {
    return(list(publication_date = from_name, publication_date_source = "filename"))
  }
  list(publication_date = as.Date(NA), publication_date_source = "pending_content_inference")
}

# The audit's F-01. The old guard refused to write once any date was recorded
# unless it was still 'pending_content_inference', so a content-derived date could
# never be corrected: compensatory_fx_sales kept the 2026-07-31 its first parse
# produced while a later parse wrote 2026-12-31 into the snapshot and 422 facts,
# and the two layers disagreed for as long as the vintage existed. The rule is
# now about authority, not about whether a value is already there -- an equal or
# higher authority may restate the date, a lower one may not.
set_source_publication_date <- function(con, vintage_id, publication_date, source = "content_max_period") {
  if (is.na(publication_date)) return(invisible(NULL))
  current <- DBI::dbGetQuery(con, paste0(
    "SELECT publication_date, publication_date_source FROM source_files WHERE vintage_id = ",
    sql_string(vintage_id)
  ))
  if (!nrow(current)) return(invisible(NULL))
  if (publication_date_authority(source) < publication_date_authority(current$publication_date_source[[1]])) {
    return(invisible(FALSE))
  }
  DBI::dbExecute(con, paste0(
    "UPDATE source_files SET publication_date = ", sql_string(as.character(publication_date)),
    ", publication_date_source = ", sql_string(source), " WHERE vintage_id = ", sql_string(vintage_id)
  ))
}

# Every table that carries both a vintage and a publication date holds a *copy*
# of source_files.publication_date, and the audit found those copies drifting.
# They are refreshed from the one authoritative row rather than each writer
# deciding for itself, so the equality gate is a proof rather than a hope. The
# table list is discovered from the catalogue so a table added later cannot be
# forgotten here.
publication_date_mirror_tables <- function(con) {
  tables <- DBI::dbGetQuery(con, paste(
    "SELECT table_schema, table_name FROM information_schema.columns",
    "WHERE column_name IN ('vintage_id', 'publication_date')",
    "GROUP BY 1, 2 HAVING count(DISTINCT column_name) = 2"
  ))
  tables <- tables[tables$table_name != "source_files", , drop = FALSE]
  base_tables <- DBI::dbGetQuery(con, paste(
    "SELECT table_schema, table_name FROM information_schema.tables WHERE table_type = 'BASE TABLE'"
  ))
  key <- function(x) paste(x$table_schema, x$table_name, sep = ".")
  tables[key(tables) %in% key(base_tables), , drop = FALSE]
}

propagate_vintage_publication_date <- function(con, vintage_id = NULL) {
  tables <- publication_date_mirror_tables(con)
  if (!nrow(tables)) return(invisible(0L))
  scope <- if (is.null(vintage_id)) "" else paste0(" AND t.vintage_id = ", sql_string(vintage_id))
  # Where source_files actually is, not where schema 21 says it belongs: this can
  # run mid-migration, before the relocation step has moved it into raw.
  source_files <- database_object_qualified_name(con, "source_files")
  updated <- 0L
  for (i in seq_len(nrow(tables))) {
    qualified <- paste0(
      DBI::dbQuoteIdentifier(con, tables$table_schema[[i]]), ".",
      DBI::dbQuoteIdentifier(con, tables$table_name[[i]])
    )
    updated <- updated + DBI::dbExecute(con, paste0(
      "UPDATE ", qualified, " AS t SET publication_date = f.publication_date ",
      "FROM ", source_files, " AS f ",
      "WHERE f.vintage_id = t.vintage_id",
      " AND t.publication_date IS DISTINCT FROM f.publication_date", scope
    ))
  }
  invisible(updated)
}

# What source_files actually holds after the authority rule has been applied. A
# parser that proposes a content maximum must go on to use the date the database
# accepted, not the one it offered, or the two disagree again.
# A release enters the database staged and leaves it accepted or blocked. Nothing
# published reads a staged release, so the ingestion loop can commit source by
# source -- which is what keeps one broken workbook from stopping the diagnosis
# of the next -- without any of it becoming visible before the release-wide
# validation has had its say.
# The operator's acquisition record, loaded beside the vintage it describes.
# Joined on (source_id, sha256) rather than on the filename, because the filename
# is the one thing the publisher changes freely and the hash is the thing that
# actually identifies the file.
apply_source_provenance <- function(con, root) {
  if (!DBI::dbExistsTable(con, "source_provenance") || is.null(root)) return(invisible(FALSE))
  registry <- source_vintage_registry(root)
  vintages <- DBI::dbGetQuery(con, "SELECT vintage_id, source_id, sha256 FROM source_files")
  DBI::dbExecute(con, "DELETE FROM source_provenance")
  if (!nrow(vintages)) return(invisible(TRUE))
  blank_to_na <- function(x) {
    x <- trimws(as.character(x))
    x[!nzchar(x) | x == "pending"] <- NA_character_
    x
  }
  joined <- vintages %>%
    dplyr::left_join(registry, by = c("source_id", "sha256")) %>%
    dplyr::transmute(
      vintage_id, source_id, sha256,
      official_release_date = suppressWarnings(as.Date(blank_to_na(.data$official_release_date))),
      official_url = blank_to_na(.data$official_url),
      release_identifier = blank_to_na(.data$release_identifier),
      retrieved_at = blank_to_na(.data$retrieved_at),
      retrieval_method = blank_to_na(.data$retrieval_method),
      # Availability, and how good the evidence for it is, decided together.
      #
      # This used to be the acquisition timestamp alone. The audit's ER-04 asks
      # for the publisher's release timestamp where it is documented and the
      # retrieval time with a lower-quality flag where it is not -- because both
      # arrive as a date in one column, and a real-time claim that cannot tell
      # them apart is claiming more than it knows. The release date wins when
      # recorded; the acquisition time is the fallback and says so.
      #
      # Nothing here ever reads publication_date. That is derived from the file
      # and describes the period the bulletin covers, not the moment anyone could
      # have had it, and inferring availability from a reference period is
      # precisely the look-ahead this column exists to prevent.
      available_at = dplyr::coalesce(
        suppressWarnings(as.POSIXct(
          blank_to_na(.data$official_release_date), tz = "UTC", format = "%Y-%m-%d"
        )),
        suppressWarnings(as.POSIXct(blank_to_na(.data$retrieved_at), tz = "UTC"))
      ),
      availability_quality = dplyr::case_when(
        !is.na(blank_to_na(.data$official_release_date)) ~ "official_release",
        is.na(blank_to_na(.data$retrieved_at)) ~ NA_character_,
        # The operator declares the weaker reading by naming the method. An
        # archive time bounds acquisition from above; it is not a retrieval.
        blank_to_na(.data$availability_quality) %in% AVAILABILITY_QUALITY_VALUES ~
          blank_to_na(.data$availability_quality),
        TRUE ~ "retrieval_time"
      ),
      license = blank_to_na(.data$license),
      evidence = blank_to_na(.data$evidence),
      recorded_at = Sys.time()
    )
  DBI::dbWriteTable(con, "source_provenance", joined, append = TRUE)
  create_project_view(con, "v_source_provenance", paste(
    "SELECT f.source_id, f.vintage_id, f.source_file, f.sha256, f.publication_date,",
    "f.publication_date_source, p.official_release_date, p.official_url, p.release_identifier,",
    "p.retrieved_at, p.retrieval_method, p.available_at, p.availability_quality, p.license,",
    "CASE WHEN p.official_url IS NULL OR p.release_identifier IS NULL",
    "       OR p.retrieved_at IS NULL OR p.retrieval_method IS NULL",
    "     THEN 'incomplete' ELSE 'complete' END AS provenance_status",
    "FROM source_files f LEFT JOIN source_provenance p USING (vintage_id)"
  ))
  invisible(TRUE)
}

stage_release <- function(con, release_id, source_count) {
  # An accepted release is not un-accepted to rebuild it.
  #
  # This used to delete the row and re-insert it as `staged`, so re-running the
  # same bundle withdrew the last accepted data from every published view for the
  # duration of the run -- and if the run then crashed, left it withdrawn. That
  # is the opposite of what a release boundary is for: the point of deciding a
  # release is that the last good one keeps standing until a new one is accepted.
  #
  # A release that is already decided is therefore left alone. Its content is
  # rebuilt underneath it -- the facts and snapshots are keyed by vintage, and a
  # deterministic bundle rebuilds to the same content -- and the decision is
  # re-made at the end from the flags this run produced.
  existing <- DBI::dbGetQuery(con, paste0(
    "SELECT status FROM releases WHERE release_id = ", sql_string(release_id)
  ))
  if (nrow(existing) && !identical(existing$status[[1]], "staged")) return(invisible(FALSE))
  DBI::dbExecute(con, paste0("DELETE FROM releases WHERE release_id = ", sql_string(release_id)))
  DBI::dbWriteTable(con, "releases", tibble(
    release_id = release_id, status = "staged", staged_at = Sys.time(),
    decided_at = as.POSIXct(NA), source_count = as.integer(source_count),
    error_count = NA_integer_, warning_count = NA_integer_, decided_by = NA_character_
  ), append = TRUE)
  invisible(TRUE)
}

# An attempt is recorded when it starts, not when it ends.
#
# Writing the row only on the way out meant a run that failed hard left no trace
# of having happened at all: the operational question the append-only table
# exists to answer -- what happened the last several times this was run -- was
# answerable only for the runs that succeeded. The row opens as `running` and is
# closed by the caller's exit handler, so a crash leaves `failed` behind it.
open_ingestion_attempt <- function(con, attempt_id, release_id, started_at, source_count) {
  if (!DBI::dbExistsTable(con, "ingestion_run_attempts")) return(invisible(FALSE))
  DBI::dbExecute(con, paste0(
    "DELETE FROM ingestion_run_attempts WHERE attempt_id = ", sql_string(attempt_id)
  ))
  DBI::dbWriteTable(con, "ingestion_run_attempts", tibble(
    attempt_id = attempt_id, release_id = release_id, started_at = started_at,
    finished_at = as.POSIXct(NA), status = "running", source_count = as.integer(source_count),
    error_count = NA_integer_, warning_count = NA_integer_, build_id = NA_character_
  ), append = TRUE)
  invisible(TRUE)
}

close_ingestion_attempt <- function(con, attempt_id, status, errors = NA_integer_,
                                    warnings = NA_integer_, build_id = NA_character_) {
  if (!DBI::dbExistsTable(con, "ingestion_run_attempts")) return(invisible(FALSE))
  DBI::dbExecute(con, paste0(
    "UPDATE ingestion_run_attempts SET finished_at = current_timestamp, status = ",
    sql_string(status),
    ", error_count = ", if (is.na(errors)) "NULL" else as.integer(errors),
    ", warning_count = ", if (is.na(warnings)) "NULL" else as.integer(warnings),
    ", build_id = ", if (is.na(build_id)) "NULL" else sql_string(build_id),
    " WHERE attempt_id = ", sql_string(attempt_id)
  ))
  invisible(TRUE)
}

decide_release <- function(con, release_id, status, errors, warnings, decided_by = "release_gate") {
  if (!status %in% c("accepted", "blocked")) stop(
    "A release is decided accepted or blocked, not '", status, "'.", call. = FALSE
  )
  DBI::dbExecute(con, paste0(
    "UPDATE releases SET status = ", sql_string(status),
    ", decided_at = current_timestamp, error_count = ", as.integer(errors),
    ", warning_count = ", as.integer(warnings),
    ", decided_by = ", sql_string(decided_by),
    " WHERE release_id = ", sql_string(release_id)
  ))
  invisible(TRUE)
}

settled_publication_date <- function(con, vintage_id, proposed = as.Date(NA)) {
  settled <- DBI::dbGetQuery(con, paste0(
    "SELECT publication_date FROM source_files WHERE vintage_id = ", sql_string(vintage_id)
  ))
  if (!nrow(settled) || is.na(settled$publication_date[[1]])) return(as.Date(proposed))
  as.Date(settled$publication_date[[1]])
}

mark_source_status <- function(con, vintage_id, status) {
  DBI::dbExecute(con, paste0("UPDATE source_files SET ingestion_status = ", sql_string(status),
                             " WHERE vintage_id = ", sql_string(vintage_id)))
}

assert_direct_structure <- function(path, source_id, dimensions, root) {
  schemas <- readr::read_csv(file.path(root, "config", "direct_schema.csv"), show_col_types = FALSE) %>%
    filter(.data$source_id == .env$source_id)
  checks <- list()
  check <- assert_same_structure(schemas$sheet_name, dimensions$sheet_name, source_id, "<workbook>", "sheet_list")
  checks[[1]] <- check
  for (i in seq_len(nrow(schemas))) {
    sheet <- schemas$sheet_name[[i]]
    observed <- names(readxl::read_excel(path, sheet = sheet, n_max = 0, .name_repair = "minimal"))
    expected <- strsplit(schemas$expected_columns[[i]], "|", fixed = TRUE)[[1]]
    checks[[i + 1L]] <- assert_same_structure(expected, observed, source_id, sheet, "column_headers")
  }
  bind_rows(checks)
}

table_has_vintage <- function(con, table_name, vintage_id) {
  DBI::dbExistsTable(con, table_name) &&
    DBI::dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM ", DBI::dbQuoteIdentifier(con, table_name),
                                " WHERE vintage_id = ", sql_string(vintage_id)))$n[[1]] > 0
}

update_entity_dimension <- function(con, data, source_id, vintage_id, root) {
  if (!"codigo_entidad" %in% names(data)) return(invisible(NULL))
  entity_type <- if (source_id == "banks") "bank" else if (source_id == "financial") "finance_company" else "unknown"
  codes <- unique(as.character(stats::na.omit(data$codigo_entidad)))
  if (!length(codes)) return(invisible(NULL))
  candidates <- tibble(entity_id = paste(entity_type, codes, sep = ":"), entity_code = codes, entity_type = entity_type)
  dictionary_path <- file.path(root, "config", "entity_dictionary.csv")
  if (file.exists(dictionary_path)) {
    dictionary <- readr::read_csv(dictionary_path, col_types = cols(.default = col_character()))
    candidates <- candidates %>% left_join(dictionary, by = c("entity_type", "entity_code"))
  } else candidates <- candidates %>% mutate(entity_name = NA_character_, mapping_status = "name_unavailable_in_source")
  existing <- DBI::dbGetQuery(con, "SELECT entity_id FROM dim_entity")$entity_id
  candidates <- candidates %>% filter(!entity_id %in% existing) %>% mutate(
    legal_name = entity_name, short_name = NA_character_, ownership_type = NA_character_,
    mapping_status = coalesce(mapping_status, "name_unavailable_in_source"), first_vintage_id = vintage_id
  ) %>% select(entity_id, entity_code, entity_type, entity_name, legal_name, short_name,
               ownership_type, mapping_status, first_vintage_id)
  if (nrow(candidates)) DBI::dbWriteTable(con, "dim_entity", candidates, append = TRUE)
}

create_latest_raw_view <- function(con, table_name) {
  # One of the two view factories in the project: this emits a view per raw
  # worksheet table, so the set is decided by the publications rather than
  # written out. Qualifying the source table here covers all of them.
  #
  # The release filter goes *inside* the ranking, not around it, for the same
  # reason it does in v_series_latest: filtering the result would return nothing
  # for a panel whose newest vintage is unpublished, while filtering the input
  # returns the newest vintage a researcher may see. Schema 24 gave the generic
  # series path this boundary and left all seventeen direct panels ranking every
  # committed vintage, so a staged or blocked source was still current here.
  ranked <- function(filter) paste0(
    "SELECT * EXCLUDE(vintage_rank) FROM (SELECT *, dense_rank() OVER (PARTITION BY source_id ORDER BY publication_date DESC NULLS LAST, vintage_id DESC) AS vintage_rank FROM ",
    project_qualified_name(table_name), filter, ") WHERE vintage_rank = 1"
  )
  create_project_view(con, paste0("v_latest_", table_name), ranked(paste0(
    " WHERE vintage_id IN (", accepted_release_vintages_sql(), ")"
  )))
  # The unfiltered twin, on the project's `_all` convention. A source is
  # validated inside its own transaction, before the release it belongs to has
  # been decided, so the ingestion checks have to be able to see the vintage they
  # are checking; the published view deliberately cannot.
  create_project_view(con, paste0("v_latest_", table_name, "_all"), ranked(""))
}

# The identifier columns of the direct panels. They name institutions and
# currencies; nothing about them is a quantity.
DIRECT_PANEL_CODE_COLUMNS <- c("codigo_entidad", "codigo_moneda")

# A code read out of Excel as a double comes back as "1002" or, once it is large
# enough, as "1.002e+03". Both are wrong as identifiers and the second is wrong
# in a way that silently stops matching. Whole numbers are rendered without a
# decimal part or an exponent; anything already text is left exactly as the
# publisher wrote it, leading zeros included.
direct_panel_code_text <- function(x) {
  if (is.character(x)) return(trimws(x))
  if (!is.numeric(x)) return(as.character(x))
  whole <- !is.na(x) & x == floor(x) & abs(x) < 2^53
  out <- rep(NA_character_, length(x))
  out[whole] <- format(x[whole], scientific = FALSE, trim = TRUE, justify = "none")
  out[!whole & !is.na(x)] <- as.character(x[!whole & !is.na(x)])
  trimws(out)
}

ingest_direct_workbook <- function(con, item, dimensions, publication_date, release_id, root) {
  checks <- assert_direct_structure(item$path, item$source_id, dimensions, root)
  record_structure_check(con, checks, item$vintage_id, release_id)
  max_date <- as.Date(NA)
  for (i in seq_len(nrow(dimensions))) {
    sheet <- dimensions$sheet_name[[i]]
    table_name <- safe_table_name(item$source_id, sheet)
    if (table_has_vintage(con, table_name, item$vintage_id)) next
    data <- readxl::read_excel(item$path, sheet = sheet, .name_repair = "minimal") %>% janitor::clean_names()
    # The physical worksheet row each record came from.
    #
    # Without it these panels cannot distinguish a row the publisher printed
    # twice from a row this parser duplicated, and the audit found the
    # consequence: 399 rows of raw_banks_canales_person share a vintage, date,
    # entity, classification and description, some with conflicting totals, and
    # nothing in the database could say which physical row each came from. readxl
    # consumes the header, so the first data record is the row after it.
    data <- data %>% dplyr::mutate(
      source_row = seq_len(dplyr::n()) + as.integer(dimensions$content_first_row[[i]])
    )
    # A code is a label, not a measure. Stored as a double, an entity or currency
    # code loses a leading zero, invites arithmetic that means nothing, and has
    # to be cast back through TRY_CAST on every join in
    # scripts/03_reference_semantics.R. Text is what it always was in the
    # workbook; the reference joins compare text to text after this.
    for (code_column in intersect(names(data), DIRECT_PANEL_CODE_COLUMNS)) {
      data[[code_column]] <- direct_panel_code_text(data[[code_column]])
    }
    date_cols <- intersect(names(data), c("fecha"))
    if (length(date_cols)) {
      observed_dates <- as_excel_date(data[[date_cols[[1]]]])
      observed_dates <- observed_dates[!is.na(observed_dates)]
      if (length(observed_dates)) {
        assert_plausible_dates(observed_dates, item$source_id, sheet)
        candidate <- max(observed_dates)
        if (is.na(max_date) || candidate > max_date) max_date <- candidate
      }
    }
    data <- data %>% mutate(
      vintage_id = item$vintage_id, release_id = release_id, publication_date = publication_date,
      source_id = item$source_id, source_sheet = sheet, source_file = item$source_file, .before = 1
    )
    if (DBI::dbExistsTable(con, table_name)) DBI::dbWriteTable(con, table_name, data, append = TRUE)
    else write_table_in_storage_layer(con, table_name, data)
    update_entity_dimension(con, data, item$source_id, item$vintage_id, root)
    DBI::dbWriteTable(con, "semantic_coverage", tibble(
      vintage_id = item$vintage_id, source_id = item$source_id, source_sheet = sheet,
      semantic_status = item$semantic_status, raw_nonempty_cells = sum(!is.na(data)),
      curated_observations = nrow(data),
      coverage_note = if (item$semantic_status == "documented_panel")
        "Structured panel linked to verified entity, currency, account, ratio and activity reference dimensions."
      else "Structured source table retained with named dimensions and measures; not yet mapped to dim_series."
    ), append = TRUE)
    create_latest_raw_view(con, table_name)
  }
  create_documented_financial_views(con)
  if (is.na(publication_date) && !is.na(max_date)) {
    set_source_publication_date(con, item$vintage_id, max_date)
    update_archive_manifest_date(
      root, item$source_id, item$sha256, settled_publication_date(con, item$vintage_id, max_date)
    )
    # The per-sheet tables are mirrors of source_files, and
    # propagate_vintage_publication_date() refreshes every one of them from the
    # settled date after this source's transaction, so nothing is stamped here.
  }
}

cells_from_matrix <- function(data) {
  empty <- tibble::tibble(
    row_id = integer(), column_id = integer(), raw_value_text = character(),
    raw_value_num = double(), raw_value_date = as.Date(character())
  )
  if (!ncol(data)) return(empty)
  records <- vector("list", ncol(data))
  for (j in seq_along(data)) {
    x <- data[[j]]
    text_values <- cell_character(x)
    keep <- !is.na(text_values) & trimws(text_values) != ""
    if (!any(keep)) next
    numeric_values <- as_number_or_na(x)
    date_value <- as_typed_date(x)
    records[[j]] <- tibble(
      row_id = which(keep), column_id = j, raw_value_text = text_values[keep],
      raw_value_num = numeric_values[keep], raw_value_date = date_value[keep]
    )
  }
  result <- bind_rows(records)
  if (!nrow(result) && !ncol(result)) empty else result
}

report_sheet_version_id <- function(cells, source_id, source_sheet) {
  ordered <- cells %>% dplyr::arrange(.data$row_id, .data$column_id)
  payload <- if (!nrow(ordered)) "<EMPTY_SHEET>" else paste(
      ordered$row_id, ordered$column_id,
      ifelse(is.na(ordered$raw_value_text), "<NA>", ordered$raw_value_text),
      ifelse(is.na(ordered$raw_value_num), "<NA>", format(ordered$raw_value_num, digits = 17, scientific = FALSE, trim = TRUE)),
      ifelse(is.na(ordered$raw_value_date), "<NA>", as.character(ordered$raw_value_date)),
      sep = "\u001f", collapse = "\u001e"
    )
  paste0("report_sheet:", substr(digest::digest(
    paste(source_id, source_sheet, payload, sep = "\u001d"),
    algo = "sha256", serialize = FALSE
  ), 1, 32))
}

store_report_sheet_version <- function(con, cells, item, sheet, release_id,
                                       publication_date, structure_signature) {
  sheet_version_id <- report_sheet_version_id(cells, item$source_id, sheet)
  version_exists <- DBI::dbGetQuery(con, paste0(
    "SELECT COUNT(*) AS n FROM report_sheet_versions WHERE sheet_version_id = ",
    sql_string(sheet_version_id)
  ))$n[[1]] > 0
  if (!version_exists) {
    DBI::dbWriteTable(con, "report_sheet_versions", tibble(
      sheet_version_id = sheet_version_id, source_id = item$source_id,
      source_sheet = sheet, structure_signature = structure_signature,
      raw_nonempty_cells = nrow(cells), first_vintage_id = item$vintage_id,
      created_at = Sys.time()
    ), append = TRUE)
    if (nrow(cells)) DBI::dbWriteTable(con, "report_cell_values", cells %>%
      dplyr::mutate(sheet_version_id = sheet_version_id, .before = 1), append = TRUE)
  }
  link_exists <- DBI::dbGetQuery(con, paste0(
    "SELECT COUNT(*) AS n FROM report_sheet_vintages WHERE vintage_id = ",
    sql_string(item$vintage_id), " AND source_sheet = ", sql_string(sheet)
  ))$n[[1]] > 0
  if (!link_exists) DBI::dbWriteTable(con, "report_sheet_vintages", tibble(
    vintage_id = item$vintage_id, release_id = release_id,
    publication_date = as.Date(publication_date), source_id = item$source_id,
    source_file = item$source_file, source_sheet = sheet,
    sheet_version_id = sheet_version_id
  ), append = TRUE)
  invisible(list(sheet_version_id = sheet_version_id, new_content = !version_exists))
}

generic_report_signature <- function(data) {
  tokens <- character()
  text_rows <- 0L
  for (r in seq_len(nrow(data))) {
    row_has_text <- FALSE
    for (j in seq_len(min(ncol(data), 30L))) {
      value <- data[[j]][[r]]
      if (is.null(value) || !length(value) || all(is.na(value)) ||
          !nzchar(trimws(as.character(value[[1]])))) next
      value <- value[[1]]
      if (!is.na(suppressWarnings(as.numeric(value))) || inherits(value, c("Date", "POSIXt"))) next
      tokens <- c(tokens, paste(r, j, normalize_label(value), sep = ":"))
      row_has_text <- TRUE
    }
    if (row_has_text) text_rows <- text_rows + 1L
    if (text_rows >= 12L) break
  }
  structure_signature(tokens)
}

ingest_report_sheet_data <- function(con, item, sheet, data, publication_date, release_id,
                                     write_inventory_coverage = TRUE) {
  signature <- generic_report_signature(data)
  previous <- DBI::dbGetQuery(con, paste0(
    "SELECT s.structure_signature FROM source_sheets s JOIN source_files f USING (vintage_id) WHERE s.source_id = ",
    sql_string(item$source_id), " AND s.sheet_name = ", sql_string(sheet),
    " AND s.vintage_id <> ", sql_string(item$vintage_id),
    " AND s.structure_signature IS NOT NULL ORDER BY f.publication_date DESC NULLS LAST, f.first_ingested_at DESC LIMIT 1"
  ))
  DBI::dbExecute(con, paste0(
    "UPDATE source_sheets SET structure_signature = ", sql_string(signature),
    " WHERE vintage_id = ", sql_string(item$vintage_id), " AND sheet_name = ", sql_string(sheet)
  ))
  if (nrow(previous) && !identical(previous$structure_signature[[1]], signature)) insert_quality_flag(
    con, release_id, "warning", "report_structure_changed", item$source_id,
    "Header-text fingerprint changed. Raw coordinates were retained; any configured semantic parser validates coverage independently.", item$vintage_id, sheet
  )
  cells <- cells_from_matrix(data)
  store_report_sheet_version(con, cells, item, sheet, release_id, publication_date, signature)
  if (isTRUE(write_inventory_coverage)) {
    DBI::dbWriteTable(con, "semantic_coverage", tibble(
      vintage_id = item$vintage_id, source_id = item$source_id, source_sheet = sheet,
      semantic_status = item$semantic_status, raw_nonempty_cells = nrow(cells),
      curated_observations = 0L,
      coverage_note = if (item$semantic_status == "inventory_only") "Coordinate inventory only; not analytically queryable as a statistical series." else "Raw coordinate layer retained alongside curated output."
    ), append = TRUE)
  }
  invisible(list(signature = signature, raw_nonempty_cells = nrow(cells)))
}

ingest_report_workbook <- function(con, item, dimensions, publication_date, release_id) {
  for (i in seq_len(nrow(dimensions))) {
    sheet <- dimensions$sheet_name[[i]]
    data <- read_sheet_matrix(
      item$path, sheet, dimensions$used_rows[[i]], dimensions$used_cols[[i]],
      dimensions$content_first_row[[i]], dimensions$content_first_col[[i]],
      dimensions$content_last_row[[i]], dimensions$content_last_col[[i]]
    )
    ingest_report_sheet_data(
      con, item, sheet, data, publication_date, release_id,
      write_inventory_coverage = TRUE
    )
  }
}
