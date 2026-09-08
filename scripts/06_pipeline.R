# --- Build isolation ---------------------------------------------------------
# The seventh audit's F-01, and the limit the sixth round recorded rather than
# closed.
#
# Schema 30 made publication a pointer at an immutable decision, so a blocked
# build could no longer *withdraw* the published database. What it could still do
# was change it. Published views resolve vintages through
# `active_data_release.source_bundle_id` -- the source bundle, not the build --
# and no published carrier has a build_id, so every build of the same bundle
# resolves to the same rows. Meanwhile the run commits source by source
# (run_manifest_pipeline() below), commits the release-wide derived tables before
# validation, and -- worst -- runs the schema migrations' invalidate_v*() steps
# inside initialize_database(), which DELETE published facts by source_id before
# any of this run's work has begun. A build that then blocked left the pointer
# aimed at a build whose data had already been rewritten underneath it.
#
# No amount of care inside one database file fixes that, because the run and the
# published product are the same bytes. So they stop being the same bytes.
#
# This is the audit's section 11.1, option 1, and the shape is already in this
# repository: compact_database.R copies, builds a candidate beside the live file,
# verifies it, syncs and renames it into place. The pipeline was already
# parameterised by db_path for rebuild_from_archive.R. What was missing was a
# caller that used it for the production path too.
#
# What this gives: a build that is not accepted cannot alter the published
# database by any mechanism, provable by comparing the file's hash.
# What it does not give: facts are still not versioned per build, so an arbitrary
# past product cannot be reconstructed. That limit is unchanged and is stated in
# docs/ARCHITECTURE.md rather than implied away.
run_isolated_update <- function(root, registry, manifest, resolution_issues = tibble(),
                                production = file.path(
                                  root, "database", "paraguay_macro_pilot.duckdb"
                                ),
                                pipeline = run_manifest_pipeline) {
  ensure_dirs(root)
  # An interrupted swap, found before anything else is attempted.
  #
  # Between the two renames below there is a moment when the production pathname
  # does not exist. A soft failure is rolled back in R; a hard kill in that
  # window is not, and leaves no published database and nothing saying why. The
  # marker is what turns that from a mystery into an instruction. RA2-08.
  swap_marker <- file.path(root, "database", ".swap_in_progress")
  if (file.exists(swap_marker)) stop(
    "A previous update was interrupted while swapping the database into place, so ",
    basename(production), " may be missing. Read ", swap_marker, ": it names the file that was ",
    "moved aside and the candidate that was going in. Restore whichever you want published, ",
    "then delete the marker.", call. = FALSE
  )
  # One writer. Released on the way out, whatever happens.
  update_lock <- acquire_update_lock(root)
  on.exit(release_update_lock(update_lock), add = TRUE)
  write_run_log(root, "update_started", production = production)
  # The same guard compact_database.R opens with. A write-ahead log beside the
  # production file means the last writer did not shut down cleanly, so the file
  # on disk is not the database -- and copying it would silently build on a
  # truncated state.
  if (file.exists(paste0(production, ".wal"))) stop(
    "A write-ahead log is present beside ", basename(production), ", so the database has ",
    "uncommitted state and must not be copied. Open it once with DuckDB to checkpoint it, ",
    "then re-run.", call. = FALSE
  )
  stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  candidate <- file.path(root, "database", "candidates", paste0("candidate_", stamp, ".duckdb"))
  if (file.exists(candidate)) stop("Candidate path already exists: ", candidate, call. = FALSE)
  # A failure anywhere below must not leave a half-built candidate for the next
  # run to trip over. Cleared once the candidate has been either published or
  # deliberately retained.
  settled <- FALSE
  on.exit({
    if (!settled) {
      unlink(candidate)
      unlink(paste0(candidate, ".wal"))
      # The failure this log exists for. A run that dies before its candidate can
      # be opened has no database to have recorded anything in, and the message
      # went to stderr and vanished with the session. `settled` is TRUE only once
      # the build has been published or deliberately retained, so reaching here
      # with it FALSE is an abnormal exit.
      write_run_log(
        root, "update_ended_without_publishing",
        production = production, candidate = candidate
      )
    }
  }, add = TRUE)

  base_sha256 <- NA_character_
  if (file.exists(production)) {
    message("Copying the published database to a build candidate...")
    copy_started <- proc.time()[["elapsed"]]
    if (!file.copy(production, candidate)) stop(
      "Could not write the build candidate at ", candidate,
      ". The published database is untouched.", call. = FALSE
    )
    # The identity of what this build is a revision *of*. The lock makes a
    # concurrent run unlikely; this makes an undetected one impossible, and it
    # also catches the operator who restored a backup mid-build.
    base_sha256 <- file_sha256(production)
    message(sprintf(
      "Candidate ready in %.1f seconds (%.1f MiB). The published database is not open for writing.",
      pipeline_elapsed_seconds(copy_started), file.info(candidate)$size / 1048576
    ))
  } else {
    message("No published database yet; this build bootstraps one.")
  }

  result <- pipeline(
    root, registry, manifest, resolution_issues,
    db_path = candidate, artifact_path = production
  )

  # A stub or an older caller may not report a decision; the run status still
  # does. Defaulting to "not accepted" would discard a good build, and defaulting
  # to "accepted" would publish a bad one, so the two are read in that order and
  # neither is guessed.
  accepted <- if (!is.null(result$decision)) {
    identical(result$decision, "accepted")
  } else {
    !identical(result$status, "release_blocked")
  }

  if (!accepted) {
    blocked <- file.path(root, "database", "candidates", paste0("blocked_", stamp, ".duckdb"))
    if (!file.rename(candidate, blocked)) blocked <- candidate
    settled <- TRUE
    write_run_log(
      root, "release_blocked", build = result$build_id, release = result$release_id,
      errors = result$error_count, candidate = blocked, production = production
    )
    message(
      "Release blocked. The published database was never opened for writing and is unchanged.\n",
      "  The blocked build is retained for inspection at: ", blocked, "\n",
      "  Read outputs/quality_flags_latest.csv, then query that file's _all interfaces."
    )
    return(invisible(c(result, list(
      published = FALSE, candidate = blocked, publication = production, swapped_from = NA_character_
    ))))
  }

  # An accepted build has to have published itself inside its own file before
  # this swaps that file in. Promoting a database whose pointer names a different
  # build would publish exactly the mixture this whole procedure exists to
  # prevent.
  verify <- DBI::dbConnect(duckdb::duckdb(), candidate, read_only = TRUE)
  pointer <- DBI::dbGetQuery(verify, "SELECT data_release_id FROM audit.active_data_release")
  DBI::dbDisconnect(verify, shutdown = TRUE)
  if (nrow(pointer) != 1L) stop(
    "The accepted candidate has ", nrow(pointer), " active data releases and must not be ",
    "published. The published database is untouched.", call. = FALSE
  )
  if (!is.null(result$build_id) && !identical(pointer$data_release_id[[1]], result$build_id)) stop(
    "The accepted candidate publishes ", pointer$data_release_id[[1]], " but this run built ",
    result$build_id, ". The published database is untouched.", call. = FALSE
  )
  if (file.exists(paste0(candidate, ".wal"))) stop(
    "The candidate still has a write-ahead log, so it did not shut down cleanly and must not ",
    "be published. The published database is untouched.", call. = FALSE
  )

  # The base this build revised must still be the base being replaced.
  #
  # The lock above makes a concurrent run unlikely; this makes an undetected one
  # impossible. If production changed between the copy and here, somebody else
  # published in the meantime, and renaming over them would discard their release
  # silently -- which is the half of RA2-08 that a lock alone cannot cover, since
  # a lock taken over from a dead holder, or an operator restoring a backup by
  # hand, produces the same state.
  if (!is.na(base_sha256)) {
    # The candidate is kept rather than cleaned up: it is a complete accepted
    # build that took as long to produce as any other, and the operator needs it
    # to diff against whatever replaced its base. Retaining it also makes the
    # message below true, which it would not be if the exit handler deleted it.
    retain_unpublished <- function() {
      kept <- file.path(root, "database", "candidates", paste0("unpublished_", stamp, ".duckdb"))
      if (file.rename(candidate, kept)) candidate <<- kept
      settled <<- TRUE
      write_run_log(
        root, "publication_refused_base_changed", build = result$build_id,
        candidate = candidate, production = production, expected_sha256 = base_sha256
      )
      candidate
    }
    if (!file.exists(production)) stop(
      "The published database disappeared while this build was running. Nothing was published; ",
      "the candidate is at ", retain_unpublished(), call. = FALSE
    )
    if (!identical(file_sha256(production), base_sha256)) stop(
      "The published database changed while this build was running, so this candidate revises a ",
      "database that is no longer published. Nothing was swapped in -- publishing it would ",
      "discard whatever replaced it. Re-run against the current database; the candidate is at ",
      retain_unpublished(), call. = FALSE
    )
  }

  # The database this build was copied from is finished and immutable, so its
  # hash can be recorded -- and this build is the only party in a position to
  # record it, because a file cannot contain its own hash. Written into the
  # candidate before the swap, so the published database carries the identity of
  # the one it replaced and the chain is complete one link behind. RA2-10.
  if (!is.na(base_sha256)) {
    link <- DBI::dbConnect(duckdb::duckdb(), candidate)
    try({
      set_project_search_path(link)
      record_inherited_artifact(link, production, base_sha256, result$schema_version)
    }, silent = TRUE)
    DBI::dbDisconnect(link, shutdown = TRUE)
    if (file.exists(paste0(candidate, ".wal"))) stop(
      "Recording the superseded artifact left a write-ahead log on the candidate, so it did not ",
      "close cleanly and must not be published. The published database is untouched.",
      call. = FALSE
    )
  }

  # Get the candidate's bytes onto the disk before the rename makes them the
  # published database -- the same reasoning as compact_database.R: rename within
  # a filesystem is atomic, but that only guarantees the directory entry, not
  # that what it points at has been flushed.
  if (nzchar(Sys.which("sync"))) system2("sync")

  backup <- NA_character_
  if (file.exists(production)) {
    backup <- file.path(
      root, "database", "backups", paste0("paraguay_macro_pilot_pre_swap_", stamp, ".duckdb")
    )
    # The window this marker covers opens here and closes after the second
    # rename. Written before the first rename so that it exists for the whole of
    # it, and it names both paths, because the recovery is a file move and the
    # operator needs to know which file goes where.
    writeLines(c(
      "A database swap was interrupted. The published database may be missing.",
      paste0("moved_aside=", backup),
      paste0("candidate=", candidate),
      paste0("publication=", production),
      paste0("build=", if (is.null(result$build_id)) NA_character_ else result$build_id),
      paste0("started_at=", format(Sys.time(), "%Y-%m-%dT%H:%M:%S")),
      "",
      "To keep the previous database:  move moved_aside back to publication.",
      "To publish the new build:       move candidate to publication.",
      "Then delete this file."
    ), swap_marker)
    # Moved rather than copied: it is the same bytes either way, and a rename
    # costs nothing where a second 500 MiB copy costs a minute. Two renames also
    # work on Windows, where renaming onto an existing file does not.
    if (!file.rename(production, backup)) {
      unlink(swap_marker)
      stop(
        "Could not move the published database aside; it is untouched and nothing was published.",
        call. = FALSE
      )
    }
  }
  if (!file.rename(candidate, production)) {
    if (!is.na(backup) && file.exists(backup) && !file.exists(production)) {
      file.rename(backup, production)
    }
    unlink(swap_marker)
    stop(
      "Could not swap the accepted build into place; the previously published database has ",
      "been restored and nothing was published.", call. = FALSE
    )
  }
  settled <- TRUE
  if (nzchar(Sys.which("sync"))) system2("sync")
  unlink(swap_marker)
  # The published bytes, hashed now that they are final: the connection is
  # closed, the checkpoint has run and the rename has happened. This is the only
  # moment in the run when the file will not change again, and it is what makes
  # the artifact identity derivable from the artifact. RA2-10.
  published_sha256 <- file_sha256(production)
  record_published_artifact(
    production, result$build_id, result$schema_version, published_sha256,
    supersedes = if (is.na(base_sha256)) NA_character_ else base_sha256
  )
  write_run_log(
    root, "published", build = result$build_id, release = result$release_id,
    sha256 = published_sha256, superseded_sha256 = base_sha256,
    warnings = result$warning_count, production = production, backup = backup
  )
  write_build_manifest(root, production, published_sha256, result)
  message(
    "Published ", result$build_id, " by atomic swap.",
    "\n  SHA-256: ", published_sha256,
    if (is.na(backup)) "" else paste0("\n  Previous database retained at: ", backup)
  )
  invisible(c(result, list(
    published = TRUE, candidate = NA_character_, publication = production,
    swapped_from = backup, sha256 = published_sha256
  )))
}

pipeline_elapsed_seconds <- function(started_at) {
  unname(proc.time()[["elapsed"]] - started_at)
}

# --- The build manifest ------------------------------------------------------
# The audit's ER-12.4: "produce a machine-readable build manifest and confirm
# deterministic table counts/checksums, with documented exceptions for
# inherently variable metadata."
#
# Everything needed to say what a result was computed from, in one file a script
# can read. It is written from the *published* database after the swap, not from
# the candidate during the build, because that is the only moment every field is
# true of the bytes on disk: the checksum is final, the pointer has moved, and
# the row counts are the ones a researcher will see.
#
# The counts are the governed tables only, and they are the determinism test.
# built_at and recorded_at are excluded from it by name rather than by omission:
# a manifest that quietly dropped the fields that vary would be claiming a
# reproducibility it had not checked.
BUILD_MANIFEST_COUNTED_TABLES <- c(
  "canonical.fact_series_events", "canonical.dim_series", "canonical.series_review",
  "canonical.series_titles", "canonical.unit_overrides", "canonical.series_period_bounds",
  "canonical.canonical_series", "canonical.map_canonical_series", "canonical.methodology_regime",
  "staging.documented_series_snapshot", "staging.observation_missingness",
  "audit.table_status", "audit.quality_flags", "raw.source_provenance"
)

BUILD_MANIFEST_NONDETERMINISTIC_FIELDS <- c(
  "generated_at", "built_at", "recorded_at", "elapsed_seconds"
)

write_build_manifest <- function(root, database_path, sha256, result) {
  if (is.null(root) || !requireNamespace("jsonlite", quietly = TRUE)) return(invisible(NULL))
  con <- tryCatch(
    connect_project_database(database_path, read_only = TRUE), error = function(e) NULL
  )
  if (is.null(con)) return(invisible(NULL))
  on.exit(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE), add = TRUE)
  count_of <- function(qualified) tryCatch(
    DBI::dbGetQuery(con, paste0("SELECT count(*) AS n FROM ", qualified))$n[[1]],
    error = function(e) NA_integer_
  )
  identity <- tryCatch(DBI::dbGetQuery(con, paste0(
    "SELECT * FROM audit.build_identity WHERE build_id = ", sql_string(result$build_id)
  )), error = function(e) NULL)
  packages <- tryCatch(DBI::dbGetQuery(con, paste0(
    "SELECT package, version, built_under, is_direct FROM audit.build_environment",
    " WHERE build_id = ", sql_string(result$build_id), " ORDER BY package"
  )), error = function(e) NULL)
  manifest <- list(
    manifest_version = 1L,
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC"),
    database = list(
      path = basename(database_path), sha256 = sha256,
      bytes = unname(file.info(database_path)$size),
      schema_version = result$schema_version
    ),
    build = if (is.null(identity) || !nrow(identity)) {
      list(build_id = result$build_id, release_id = result$release_id)
    } else as.list(identity[1, , drop = FALSE]),
    release = list(
      release_id = result$release_id, run_status = result$status, decision = result$decision,
      data_release_id = result$data_release_id,
      error_count = result$error_count, warning_count = result$warning_count
    ),
    table_counts = stats::setNames(
      lapply(BUILD_MANIFEST_COUNTED_TABLES, count_of), BUILD_MANIFEST_COUNTED_TABLES
    ),
    environment = if (is.null(packages)) NULL else packages,
    # Named, not omitted. A second clean rebuild is expected to reproduce every
    # field of this manifest except these.
    nondeterministic_fields = BUILD_MANIFEST_NONDETERMINISTIC_FIELDS
  )
  path <- file.path(root, "outputs", "build_manifest.json")
  writeLines(jsonlite::toJSON(manifest, auto_unbox = TRUE, null = "null", digits = NA), path)
  invisible(path)
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
                                  db_path = file.path(root, "database", "paraguay_macro_pilot.duckdb"),
                                  artifact_path = db_path) {
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
    "DELETE FROM ", project_qualified_name("quality_flags"),
    " WHERE attempt_id = ", sql_string(attempt_id)
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
        "DELETE FROM ", project_qualified_name("quality_flags"),
        " WHERE vintage_id = ", sql_string(item$vintage_id),
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
      project_begin_transaction(con)
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
      project_commit_transaction(con)
      transaction_open <- FALSE
      mark_source_status(con, item$vintage_id, "completed")
      message("Loaded: ", item$source_id, " / ", item$source_file, " / ", item$vintage_id)
    }, error = function(e) {
      if (isTRUE(transaction_open)) project_rollback_transaction(con)
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
    # Before the derivations, not after, and for the opposite reason to the
    # review register below. unit_code and transformation are recomputed from
    # `unit` on every build, so a correction applied to the output would leave
    # the two disagreeing; applied to the input, every consequence follows.
    apply_unit_overrides(con, root)
    apply_series_semantics(con)
    # After the derivations, never before: several of them are unconditional
    # UPDATEs that would overwrite a reviewed value. Reviewed wins because it
    # runs last, not because each derivation remembers to check.
    apply_series_review(con, root)
    apply_series_grain(con, root)
    apply_source_provenance(con, root)
    apply_platform_contracts(con, root, build$build_id)
  })
  # After the semantics, because the expected grid is read off each series'
  # declared frequency, and before the marts, which publish the result.
  phase("observation_missingness", apply_observation_missingness(con, root, build$build_id))
  phase("governance_registers", apply_governance_registers(con, root))
  phase("mart_views", {
    create_mart_views(con)
    create_research_views(con)
  })
  })
  flush_release_timings()
  phase("reports", {
    write_canonical_core_proposal(con, root)
    write_semantic_completeness_report(con, root)
    write_semantic_review_worklist(con, root)
    # The readiness audit's review queues. Each one names rows rather than
    # counting them, and each is ranked by what a mistake in it would cost --
    # ER-01's exchange-rate units, ER-06's unresolved units and positional
    # identities.
    write_exchange_rate_unit_worklist(con, root)
    write_unit_resolution_worklist(con, root)
    write_identity_stability_worklist(con, root)
    write_migration_runbook(con, root)
    # Moved here from after the release decision, where nothing could check it.
    # The audit's F-06 shipped a dashboard with 256 rows for 242 worksheets for
    # exactly that reason: the one report no gate could see. Validation asserts
    # its key below.
    write_coverage_dashboard(con, root)
  })
  phase("validation", validate_database(con, manifest, release_id, root, db_path, attempt_id))
  # The statistical screens run after validation so their warnings join the same
  # flag set and the same release status, and their outputs sit alongside it.
  phase("quality_screens", run_quality_screens(con, release_id, root))
  # And the flag report is written after them, so the file describes every check
  # that ran rather than every check that had run when validation ended.
  #
  # Written, then compared with the database, then written again. The comparison
  # is the audit's test 6 and its subject is the file, so it can only run once the
  # file exists; and if it finds a disagreement it raises a flag, which the file
  # must then contain. The second write costs nothing and makes the file
  # authoritative whatever the first one caught.
  phase("quality_flag_report", {
    write_quality_flag_report(con, release_id, root)
    validate_report_agreement(con, release_id, root)
    write_quality_flag_report(con, release_id, root)
  })
  flags <- DBI::dbGetQuery(con, paste0(
    "SELECT severity FROM ", project_qualified_name("quality_flags"),
    " WHERE attempt_id = ", sql_string(attempt_id)
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
  # And the library it actually ran against, package by package.
  record_build_environment(con, build)
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
  DBI::dbExecute(con, paste0("DELETE FROM ingestion_runs WHERE release_id = ", sql_string(release_id)))
  DBI::dbWriteTable(con, "ingestion_runs", tibble(
    release_id = release_id, executed_at = Sys.time(), status = run_status,
    source_count = nrow(manifest), error_count = errors, warning_count = warnings
  ), append = TRUE)
  # ingestion_runs is one row per release, because a release is deterministic.
  # The attempt row was opened before any work began; this closes it.
  close_ingestion_attempt(con, attempt_id, run_status, errors, warnings, build$build_id)
  attempt_closed <- TRUE
  # This build's own row carries a null sha256, and says so rather than
  # recording a size read from a connection that is still open and still
  # writing. Its true hash is taken after final close, by run_isolated_update(),
  # and lives in the sidecar beside the published file -- see
  # record_published_artifact(). RA2-10.
  record_distribution_artifact(
    con, db_path, build$build_id, build$build_id, schema_version, artifact_path
  )
  # Every phase measured so far reaches the report; the ones after it cannot,
  # since a report cannot time its own writing.
  flush_release_timings()
  write_update_report(con, release_id, root, attempt_id, build$build_id)
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
  # build_id and the verdict travel back to the caller, because since schema 33
  # the caller decides whether this file becomes the published database. A
  # publisher that has to re-open the database to find out what it just built
  # would be reading the answer from the thing whose trustworthiness is in
  # question.
  invisible(list(
    release_id = release_id, status = run_status, database = db_path,
    build_id = build$build_id, data_release_id = build$build_id,
    decision = status, error_count = errors, warning_count = warnings,
    attempt_id = attempt_id, schema_version = schema_version
  ))
}
