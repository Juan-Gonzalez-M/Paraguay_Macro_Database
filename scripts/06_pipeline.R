pipeline_elapsed_seconds <- function(started_at) {
  unname(proc.time()[["elapsed"]] - started_at)
}

write_pipeline_timings <- function(con, attempt_id, release_id, item, timings) {
  if (!nrow(timings)) return(invisible(FALSE))
  rows <- timings %>% dplyr::transmute(
    attempt_id = .env$attempt_id,
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
  run_started_at <- Sys.time()
  attempt_id <- paste0("attempt:", substr(digest::digest(
    paste(release_id, format(run_started_at, "%Y-%m-%dT%H:%M:%OS6"), Sys.getpid(), sep = "|"),
    algo = "sha256", serialize = FALSE
  ), 1, 24))
  con <- DBI::dbConnect(duckdb::duckdb(), db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  initialize_database(con, root)
  # Staged, not published -- unless this release was already accepted, in which
  # case it stays accepted while its content is rebuilt and the decision is
  # re-made at the end. The last accepted data is never withdrawn by the act of
  # starting a run.
  stage_release(con, release_id, nrow(manifest))
  # The attempt is open from here. Whatever happens next -- a parser error, a
  # failed gate, an interrupted process -- the exit handler closes it, so a run
  # that dies still leaves a record that it ran and failed.
  open_ingestion_attempt(con, attempt_id, release_id, run_started_at, nrow(manifest))
  attempt_closed <- FALSE
  on.exit({
    if (!attempt_closed) try(
      close_ingestion_attempt(con, attempt_id, "failed"), silent = TRUE
    )
  }, add = TRUE, after = FALSE)
  # Flags are attributed to the attempt that raised them and are no longer
  # deleted by release_id at the start of a run. Re-running a bundle used to
  # destroy the diagnostic evidence of the build that had been accepted, which is
  # the half of the audit's R6-02 that is about evidence rather than publication.
  # Only this attempt's own flags are cleared, and only if it is being re-entered.
  DBI::dbExecute(con, paste0(
    "DELETE FROM quality_flags WHERE attempt_id = ", sql_string(attempt_id)
  ))
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
      # An unchanged file never reaches record_source_metadata(), so this is the
      # only place an operator's newly recorded official release date can reach a
      # vintage that is being reused. The mirrors follow it in the same step.
      reused_date <- resolve_vintage_publication_date(item, root)
      if (!is.na(reused_date$publication_date)) {
        set_source_publication_date(
          con, item$vintage_id, reused_date$publication_date, reused_date$publication_date_source
        )
        update_archive_manifest_date(
          root, item$source_id, item$sha256,
          DBI::dbGetQuery(con, paste0(
            "SELECT publication_date FROM source_files WHERE vintage_id = ",
            sql_string(item$vintage_id)
          ))$publication_date[[1]]
        )
      }
      propagate_vintage_publication_date(con, item$vintage_id)
      create_documented_financial_views(con)
      validate_source(con, item, release_id, root)
      add_timing("reuse_and_validation", reuse_started)
      add_timing("source_total", source_started)
      write_pipeline_timings(con, attempt_id, release_id, item, timings)
      message("Unchanged source; reused existing vintage: ", item$source_id)
      next
    }
    if (!is.na(previous_status) && previous_status == "failed_structure_or_ingestion") {
      DBI::dbExecute(con, paste0(
        "DELETE FROM quality_flags WHERE vintage_id = ", sql_string(item$vintage_id),
        " AND check_name = 'source_ingestion_failed' AND attempt_id = ", sql_string(attempt_id)
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
        inferred <- infer_credit_survey_publication_date(item, dimensions)
        set_source_publication_date(con, item$vintage_id, inferred)
        publication_date <- settled_publication_date(con, item$vintage_id, inferred)
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
      # Inside the source transaction, before validation: every snapshot, raw and
      # fact row this source just wrote takes its publication date from
      # source_files rather than from whichever parser happened to write it. The
      # audit's 422-row divergence cannot survive this and cannot recur.
      propagate_vintage_publication_date(con, item$vintage_id)
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
      ensure_failed_source_metadata(con, item, release_id, root)
      mark_source_status(con, item$vintage_id, "failed_structure_or_ingestion")
      insert_quality_flag(con, release_id, "error", "source_ingestion_failed", item$source_id,
                          conditionMessage(e), item$vintage_id)
      message("FAILED: ", item$source_id, " — ", conditionMessage(e))
    })
    add_timing("source_total", source_started)
    try(write_pipeline_timings(con, attempt_id, release_id, item, timings), silent = TRUE)
    message(sprintf(
      "Timing: %s completed in %.1f seconds.", item$source_id,
      timings$elapsed_seconds[timings$stage == "source_total"][[1]]
    ))
  }
  # Each release-wide phase is timed. Without this the recorded evidence covered
  # parsing only, so a release reported 2.4 seconds while reconciliation, region
  # classification, a 2.4-million-row expected grid and mart validation went
  # unmeasured -- and no bottleneck could be found from what was written down.
  #
  # Timings are buffered rather than written where they are measured, because the
  # derived phases below run inside one transaction and a rollback would take the
  # record of how far the run got with it. The buffer is flushed on the way out,
  # whether the run finished or died.
  release_timings <- list()
  phase <- function(stage, expression) {
    started <- proc.time()[["elapsed"]]
    result <- force(expression)
    release_timings[[length(release_timings) + 1L]] <<- tibble(
      attempt_id = attempt_id, release_id = release_id, vintage_id = NA_character_,
      source_id = NA_character_, stage = stage,
      elapsed_seconds = pipeline_elapsed_seconds(started), recorded_at = Sys.time()
    )
    invisible(result)
  }
  flush_release_timings <- function() {
    if (!length(release_timings)) return(invisible(FALSE))
    rows <- dplyr::bind_rows(release_timings)
    release_timings <<- list()
    try(DBI::dbWriteTable(con, "ingestion_stage_timings", rows, append = TRUE), silent = TRUE)
    invisible(TRUE)
  }
  on.exit(flush_release_timings(), add = TRUE)
  # The build this run is producing. Computed here, before the derived phases,
  # because it is the identity of the product they are building -- the missingness
  # rows carry it, and the decision at the end is about it.
  schema_version <- DBI::dbGetQuery(con, "SELECT max(version) AS v FROM schema_version")$v[[1]]
  build <- build_identity_record(root, release_id, schema_version)
  # One transaction over everything that rewrites a release-wide derived table.
  #
  # These phases delete and rebuild reconciliation, region classification, table
  # status, semantics, the expected grid, missingness and the governance
  # registers. A run that died in the middle used to leave them half-rebuilt
  # underneath a release that was still marked accepted -- so the published
  # database was a mixture of two builds, and no pointer or decision record could
  # have helped, because the damage was already committed. DuckDB rolls DDL and
  # DML back together, so a failure here leaves the previous build's derived
  # tables exactly as they were.
  #
  # Validation, the screens and the reports stay outside it. They write flags and
  # files rather than data, and one of them opens a second connection to the same
  # database file to prove the published interface works without this session's
  # settings -- which cannot see uncommitted work, and would be testing the
  # previous build if it ran inside the transaction.
  with_project_transaction(con, {
  phase("concept_mappings", apply_reviewed_concept_mappings(con, root))
  # Reconciliation runs before the status gate: apply_table_status() refuses to
  # promote a worksheet whose cell accounting does not balance, so the balance
  # has to be measured first.
  phase("table_reconciliation", apply_table_reconciliation(con, release_id, root))
  # The out-of-region register runs beside it and before the status gate, for the
  # same reason: apply_table_status() refuses to promote a worksheet with
  # unreviewed or unread cells outside every parser region, so they have to be
  # classified first.
  phase("source_region_classification", apply_source_region_classification(con, release_id, root))
  phase("table_status_and_domains", {
    apply_table_status(con, root)
    apply_table_domains(con, root)
  })
  phase("series_semantics", {
    apply_series_semantics(con)
    apply_series_grain(con, root)
    apply_source_provenance(con, root)
  })
  # After the semantics, because the expected grid is read off each series'
  # declared frequency, and before the marts, which publish the result.
  phase("observation_missingness", apply_observation_missingness(con, root, build$build_id))
  phase("governance_registers", apply_governance_registers(con, root))
  phase("mart_views", create_mart_views(con))
  })
  flush_release_timings()
  phase("reports", {
    write_canonical_core_proposal(con, root)
    write_semantic_completeness_report(con, root)
    write_semantic_review_worklist(con, root)
    write_migration_runbook(con, root)
  })
  phase("validation", validate_database(con, manifest, release_id, root, db_path))
  # The statistical screens run after validation so their warnings join the same
  # flag set and the same release status, and their outputs sit alongside it.
  phase("quality_screens", run_quality_screens(con, release_id, root))
  # And the flag report is written after them, so the file describes every check
  # that ran rather than every check that had run when validation ended.
  phase("quality_flag_report", write_quality_flag_report(con, release_id, root))
  flags <- DBI::dbGetQuery(con, paste0(
    "SELECT severity FROM quality_flags WHERE attempt_id = ", sql_string(attempt_id)
  ))
  errors <- sum(flags$severity == "error")
  warnings <- sum(flags$severity == "warning")
  run_status <- if (errors > 0) "release_blocked" else if (warnings > 0) "completed_with_warnings" else "completed"
  status <- if (errors > 0) "blocked" else "accepted"
  # What this database *is*, as opposed to which files it was built from. The
  # identity was computed before the derived phases ran, because it names the
  # product they were building; this records it.
  DBI::dbExecute(con, paste0(
    "DELETE FROM build_identity WHERE build_id = ", sql_string(build$build_id)
  ))
  DBI::dbWriteTable(con, "build_identity", build, append = TRUE)
  # The publication decision, in two parts that used to be one mutable UPDATE.
  #
  # First the verdict on *this product*, recorded once and never rewritten. Then,
  # only if it was accepted, the pointer swap that publishes it. A blocked build
  # never reaches the second step, so the previously published product stays
  # published and the operator reads the flags rather than discovering that a
  # broken run emptied every research view. That is the audit's R6-02: the same
  # source bundle had fourteen attempts across four schema versions, one of them
  # blocked, and the blocked one withdrew the accepted database.
  #
  # The source-bundle lifecycle is still recorded, because "were these files ever
  # published" is a real question. It is no longer the thing views join to.
  record_data_release_decision(
    con, release_id, build$build_id, attempt_id, schema_version, status, errors, warnings
  )
  decide_release(con, release_id, status, errors, warnings)
  if (identical(status, "accepted")) promote_data_release(con, build$build_id, release_id)
  write_coverage_dashboard(con, root)
  DBI::dbExecute(con, paste0("DELETE FROM ingestion_runs WHERE release_id = ", sql_string(release_id)))
  DBI::dbWriteTable(con, "ingestion_runs", tibble(
    release_id = release_id, executed_at = Sys.time(), status = run_status,
    source_count = nrow(manifest), error_count = errors, warning_count = warnings
  ), append = TRUE)
  # ingestion_runs is one row per release, because a release is deterministic.
  # The attempt row was opened before any work began; this closes it.
  close_ingestion_attempt(con, attempt_id, run_status, errors, warnings, build$build_id)
  attempt_closed <- TRUE
  write_update_report(con, release_id, root)
  catalogue <- DBI::dbGetQuery(con, paste0(
    "SELECT s.* FROM source_sheets s JOIN release_sources r USING (vintage_id) WHERE r.release_id = ",
    sql_string(release_id), " ORDER BY source_id, sheet_name"
  ))
  readr::write_csv(catalogue, file.path(root, "outputs", "source_sheet_catalogue_latest.csv"))
  timing_output <- DBI::dbGetQuery(con, paste0(
    "SELECT attempt_id, source_id, vintage_id, stage, elapsed_seconds, recorded_at FROM ingestion_stage_timings WHERE attempt_id = ",
    sql_string(attempt_id), " ORDER BY recorded_at, source_id, stage"
  ))
  readr::write_csv(timing_output, file.path(root, "outputs", "ingestion_stage_timings_latest.csv"))
  invisible(list(release_id = release_id, status = run_status, database = db_path))
}
