pipeline_elapsed_seconds <- function(started_at) {
  unname(proc.time()[["elapsed"]] - started_at)
}

write_pipeline_timings <- function(con, release_id, item, timings) {
  if (!nrow(timings)) return(invisible(FALSE))
  rows <- timings %>% dplyr::transmute(
    release_id = .env$release_id, vintage_id = .env$item$vintage_id, source_id = .env$item$source_id,
    stage = .data$stage, elapsed_seconds = as.numeric(.data$elapsed_seconds),
    recorded_at = Sys.time()
  )
  DBI::dbWriteTable(con, "ingestion_stage_timings", rows, append = TRUE)
  invisible(TRUE)
}

run_manifest_pipeline <- function(root, registry, manifest, resolution_issues = tibble(),
                                  db_path = file.path(root, "database", "paraguay_macro_pilot.duckdb")) {
  if (!nrow(manifest)) stop("The file manifest is empty.", call. = FALSE)
  release_id <- make_release_id(manifest)
  con <- DBI::dbConnect(duckdb::duckdb(), db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  initialize_database(con)
  DBI::dbExecute(con, paste0("DELETE FROM quality_flags WHERE release_id = ", sql_string(release_id)))
  DBI::dbExecute(con, paste0("DELETE FROM ingestion_stage_timings WHERE release_id = ", sql_string(release_id)))
  if (nrow(resolution_issues)) for (i in seq_len(nrow(resolution_issues))) insert_quality_flag(
    con, release_id, resolution_issues$severity[[i]], resolution_issues$check_name[[i]],
    resolution_issues$source_id[[i]], resolution_issues$detail[[i]]
  )
  for (i in seq_len(nrow(manifest))) {
    item <- manifest[i, ]
    source_started <- proc.time()[["elapsed"]]
    timings <- tibble::tibble(stage = character(), elapsed_seconds = double())
    add_timing <- function(stage, started_at) {
      timings <<- dplyr::bind_rows(timings, tibble::tibble(
        stage = stage, elapsed_seconds = pipeline_elapsed_seconds(started_at)
      ))
    }
    link_exists <- DBI::dbGetQuery(con, paste0(
      "SELECT COUNT(*) AS n FROM release_sources WHERE release_id = ", sql_string(release_id),
      " AND vintage_id = ", sql_string(item$vintage_id)
    ))$n[[1]]
    if (!link_exists) DBI::dbWriteTable(con, "release_sources", tibble(
      release_id = release_id, source_id = item$source_id, vintage_id = item$vintage_id
    ), append = TRUE)
    previous_status <- if (source_vintage_exists(con, item$vintage_id)) DBI::dbGetQuery(con, paste0(
      "SELECT ingestion_status FROM source_files WHERE vintage_id = ", sql_string(item$vintage_id)
    ))$ingestion_status[[1]] else NA_character_
    if (!is.na(previous_status) && previous_status == "completed") {
      reuse_started <- proc.time()[["elapsed"]]
      create_documented_financial_views(con)
      validate_source(con, item, release_id, root)
      add_timing("reuse_and_validation", reuse_started)
      add_timing("source_total", source_started)
      write_pipeline_timings(con, release_id, item, timings)
      message("Unchanged source; reused existing vintage: ", item$source_id)
      next
    }
    if (!is.na(previous_status) && previous_status == "failed_structure_or_ingestion") {
      DBI::dbExecute(con, paste0(
        "DELETE FROM quality_flags WHERE vintage_id = ", sql_string(item$vintage_id),
        " AND check_name = 'source_ingestion_failed'"
      ))
    }
    transaction_open <- FALSE
    tryCatch({
      discovery_started <- proc.time()[["elapsed"]]
      dimensions <- if (tolower(item$source_format) == "csv") {
        csv_source_dimensions(item$path)
      } else xlsx_sheet_dimensions(item$path)
      meta <- record_source_metadata(con, item, dimensions, release_id, root)
      publication_date <- meta$publication_date
      if (is.na(publication_date) && item$source_id == "credit_survey") {
        publication_date <- infer_credit_survey_publication_date(item, dimensions)
        set_source_publication_date(con, item$vintage_id, publication_date)
        update_archive_manifest_date(root, item$source_id, item$sha256, publication_date)
      }
      add_timing("source_discovery_and_metadata", discovery_started)
      DBI::dbBegin(con)
      transaction_open <- TRUE
      ingestion_started <- proc.time()[["elapsed"]]
      if (item$ingest_mode == "semantic_table") {
        # The documented parser stores the raw sheet version from the same
        # in-memory sheet used for semantic extraction, avoiding a second full
        # read of every workbook while preserving both layers.
        curated <- ingest_curated_source(con, item, dimensions, release_id, root, publication_date)
        publication_date <- curated$publication_date
      } else if (item$ingest_mode == "long_csv") {
        curated <- ingest_curated_source(con, item, dimensions, release_id, root, publication_date)
        publication_date <- curated$publication_date
      } else {
        curated <- ingest_curated_source(con, item, dimensions, release_id, root, publication_date)
        publication_date <- curated$publication_date
        if (item$ingest_mode == "direct") {
          ingest_direct_workbook(con, item, dimensions, publication_date, release_id, root)
        } else if (item$ingest_mode != "reference") {
          ingest_report_workbook(con, item, dimensions, publication_date, release_id)
        }
      }
      add_timing("ingestion_and_curation", ingestion_started)
      if (!item$ingest_mode %in% c("semantic_table", "long_csv", "direct", "reference")) {
        if (curated$curated_rows > 0 && !is.na(curated$source_sheet)) DBI::dbExecute(con, paste0(
          "UPDATE semantic_coverage SET curated_observations = ", curated$curated_rows,
          ", semantic_status = 'curated', coverage_note = 'Semantic parser passed its structure guard; raw coordinate layer also retained.' WHERE vintage_id = ",
          sql_string(item$vintage_id), " AND source_sheet = ", sql_string(curated$source_sheet)
        ))
      }
      validation_started <- proc.time()[["elapsed"]]
      create_documented_financial_views(con)
      validate_source(con, item, release_id, root)
      add_timing("source_validation", validation_started)
      DBI::dbCommit(con)
      transaction_open <- FALSE
      mark_source_status(con, item$vintage_id, "completed")
      message("Loaded: ", item$source_id, " / ", item$source_file, " / ", item$vintage_id)
    }, error = function(e) {
      if (isTRUE(transaction_open)) try(DBI::dbRollback(con), silent = TRUE)
      transaction_open <- FALSE
      if (inherits(e, "documented_continuity_error")) {
        DBI::dbExecute(con, paste0(
          "DELETE FROM documented_series_continuity WHERE vintage_id = ", sql_string(e$vintage_id)
        ))
        if (nrow(e$changes)) DBI::dbWriteTable(con, "documented_series_continuity", e$changes, append = TRUE)
        if (nrow(e$quality_records)) for (j in seq_len(nrow(e$quality_records))) insert_quality_flag(
          con, release_id, "error", e$quality_records$check_name[[j]], e$source_id,
          e$quality_records$detail[[j]], e$vintage_id
        )
      }
      ensure_failed_source_metadata(con, item, release_id)
      mark_source_status(con, item$vintage_id, "failed_structure_or_ingestion")
      insert_quality_flag(con, release_id, "error", "source_ingestion_failed", item$source_id,
                          conditionMessage(e), item$vintage_id)
      message("FAILED: ", item$source_id, " — ", conditionMessage(e))
    })
    add_timing("source_total", source_started)
    try(write_pipeline_timings(con, release_id, item, timings), silent = TRUE)
    message(sprintf(
      "Timing: %s completed in %.1f seconds.", item$source_id,
      timings$elapsed_seconds[timings$stage == "source_total"][[1]]
    ))
  }
  apply_reviewed_concept_mappings(con, root)
  apply_table_status(con, root)
  flags <- validate_database(con, manifest, release_id, root)
  errors <- sum(flags$severity == "error")
  warnings <- sum(flags$severity == "warning")
  run_status <- if (errors > 0) "completed_with_errors" else if (warnings > 0) "completed_with_warnings" else "completed"
  DBI::dbExecute(con, paste0("DELETE FROM ingestion_runs WHERE release_id = ", sql_string(release_id)))
  DBI::dbWriteTable(con, "ingestion_runs", tibble(
    release_id = release_id, executed_at = Sys.time(), status = run_status,
    source_count = nrow(manifest), error_count = errors, warning_count = warnings
  ), append = TRUE)
  write_update_report(con, release_id, root)
  catalogue <- DBI::dbGetQuery(con, paste0(
    "SELECT s.* FROM source_sheets s JOIN release_sources r USING (vintage_id) WHERE r.release_id = ",
    sql_string(release_id), " ORDER BY source_id, sheet_name"
  ))
  readr::write_csv(catalogue, file.path(root, "outputs", "source_sheet_catalogue_latest.csv"))
  timing_output <- DBI::dbGetQuery(con, paste0(
    "SELECT source_id, vintage_id, stage, elapsed_seconds, recorded_at FROM ingestion_stage_timings WHERE release_id = ",
    sql_string(release_id), " ORDER BY source_id, recorded_at, stage"
  ))
  readr::write_csv(timing_output, file.path(root, "outputs", "ingestion_stage_timings_latest.csv"))
  invisible(list(release_id = release_id, status = run_status, database = db_path))
}
