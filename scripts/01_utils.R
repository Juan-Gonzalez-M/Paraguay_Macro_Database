suppressPackageStartupMessages({
  library(DBI)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(lubridate)
  library(janitor)
  library(readxl)
  library(digest)
  library(fs)
  library(xml2)
  library(readr)
  library(yaml)
})

ensure_dirs <- function(root) {
  fs::dir_create(file.path(root, c(
    "database", "database/backups", "database/candidates", "outputs", "input_archive", "logs"
  )), recurse = TRUE)
}

# Why a parser is allowed to discard a publisher's row.
#
# The audit's section 11.3 asks for a release to block on unclassified rejected
# rows. A register of reasons alone cannot deliver that: the first version of
# this check compared the register against a grep over the sources, and the grep
# missed both the ternary in the FX parser and the CSV reasons, which are list
# names rather than string literals. It passed by luck.
#
# So the vocabulary is here, in code, and both ends are held to it: a parser may
# only record a reason from this vector, and config/row_rejection_reasons.csv
# must declare exactly this vector and nothing else. The register says what each
# one *means* and whether seeing it is expected; this says which ones exist.
ROW_REJECTION_REASONS <- c(
  # Written by the ICC/EVE and FX-operations parsers since schema 12.
  "non_data_note",
  "unrecognized_period_with_values",
  # The delimited sources, since schema 34.
  "invalid_date",
  "invalid_numeric_token",
  "missing_mandatory_dimension",
  "unsupported_currency",
  "out_of_range_value",
  "duplicate_key"
)

normalize_label <- function(x) {
  stringr::str_to_lower(stringr::str_squish(as.character(x)))
}

normalize_semantic_label <- function(x) {
  stringi::stri_trans_general(normalize_label(x), "Latin-ASCII")
}

# stringr/stringi deliberately return vectors for matrix inputs. Reattach the
# shape in one shared helper before using which(..., arr.ind = TRUE); otherwise
# callers silently receive linear offsets instead of row/column coordinates.
matrix_predicate <- function(x, predicate) {
  input_dim <- dim(x)
  if (is.null(input_dim) || length(input_dim) != 2L) stop(
    "matrix_predicate() requires a two-dimensional input.", call. = FALSE
  )
  result <- as.logical(predicate(as.vector(x)))
  if (length(result) != length(x)) stop(
    "Matrix predicate returned a result with the wrong length.", call. = FALSE
  )
  matrix(result, nrow = input_dim[[1]], ncol = input_dim[[2]])
}

matrix_detect <- function(x, pattern, ...) {
  matrix_predicate(x, function(values) stringr::str_detect(values, pattern, ...))
}

matrix_equal <- function(x, value) {
  matrix_predicate(x, function(values) values == value)
}

safe_table_name <- function(source_id, sheet_name) {
  paste0("raw_", janitor::make_clean_names(paste(source_id, sheet_name, sep = "_")))
}

sql_string <- function(x) paste0("'", gsub("'", "''", as.character(x)), "'")
file_sha256 <- function(path) digest::digest(file = path, algo = "sha256")

# --- Storage layers ---------------------------------------------------------
# The audit's P2: "76 tables and 61 views remain in main. Useful objects were
# added, but raw/staging/canonical/marts/audit ownership is still difficult to
# discover; use schemas."
#
# The five layers say what an object is for, which is information the name alone
# does not carry. documented_series_snapshot and dim_series look equally
# authoritative in a flat catalogue; one is parser output that a repair will
# rewrite, the other is the curated dimension that research code joins to.
#
#   raw        immutable file, sheet and cell evidence exactly as read
#   staging    typed parser output, exclusions and parser diagnostics
#   canonical  the curated economic layer: dimensions, facts, identity, concepts
#   marts      the research-facing interface (views only)
#   audit      governance, review status, reconciliation, release evidence
#
# The search path keeps unqualified names resolving for the pipeline's own
# connections. It does NOT keep them resolving for a stored view: DuckDB keeps a
# view's SQL as text and re-binds it against the *caller's* search path every
# time the view is queried. Schema 21 moved the tables while every view body
# still named them bare, so 74 of 88 views and all three macros raised
# "Table with name dim_series does not exist" from a fresh default connection --
# which is every connection the project does not open itself, including its own
# documented read API in scripts/05_query_helpers.R.
#
# Schema 22 is the repair: every stored object is written with its dependencies
# schema-qualified (create_project_view/create_project_macro below), a lint reads
# the stored SQL back and rejects any bare reference that survived, and a gate
# executes every view and macro on a connection with no search path set. The
# search path stays, because dbWriteTable() and dbExistsTable() still use it; it
# is no longer load-bearing for anything a researcher touches.
PROJECT_SCHEMAS <- c("raw", "staging", "canonical", "marts", "research", "audit")

PROJECT_TABLE_SCHEMA <- c(
  # raw: what was read, before anyone interpreted it
  source_files = "raw", source_sheets = "raw", report_sheet_versions = "raw",
  report_sheet_vintages = "raw", report_cell_values = "raw", report_cells_legacy = "raw",
  reference_table_loads = "raw",
  # staging: parser output and parser diagnostics
  documented_table_catalog = "staging", documented_series_snapshot = "staging",
  documented_sheet_drift = "staging", documented_series_continuity = "staging",
  discarded_rows = "staging", semantic_coverage = "staging",
  bond_curve_snapshot = "staging", securities_transactions_snapshot = "staging",
  # canonical: the curated economic layer
  dim_series = "canonical", fact_series_events = "canonical", series_revisions = "canonical",
  dim_concept = "canonical", map_series_concept = "canonical", dim_entity = "canonical",
  dim_currency = "canonical", dim_statement_item = "canonical", map_statement_account = "canonical",
  dim_ratio = "canonical", dim_portfolio_item = "canonical", map_portfolio_account = "canonical",
  dim_credit_activity = "canonical", dim_credit_sector = "canonical",
  dim_payment_participant = "canonical", dim_exchange_item = "canonical",
  series_id_migration = "canonical", source_alias = "canonical", continuity_map = "canonical",
  canonical_series = "canonical", map_canonical_series = "canonical",
  methodology_regime = "canonical", classification_concordance = "canonical",
  series_semantic_evidence = "canonical", series_dimension = "canonical",
  series_period_bounds = "canonical",
  missingness_contracts = "audit", panel_resolution = "audit",
  acquisition_contracts = "audit", certification_rules = "audit",
  certification_decisions = "canonical", rule_certified_series = "canonical",
  dataset_catalog = "canonical",
  # The published table title, resolved to one row per series. It is the only
  # field distinguishing 1,599 repeated labels, and it lived on a staging
  # snapshot at observation grain, so the documented read path could not reach it
  # without joining a table researchers are told not to use. Schema 39.
  series_titles = "canonical",
  # Reviewed unit and currency corrections, applied over the derived semantics.
  # Narrower than series_review, which requires the whole economic record: a
  # worksheet whose columns carry different units can be corrected without
  # claiming its series have been economically reviewed. Schema 39.
  unit_overrides = "canonical",
  # audit: governance and release evidence
  schema_version = "audit", ingestion_runs = "audit", ingestion_stage_timings = "audit",
  release_sources = "audit", structure_checks = "audit", quality_flags = "audit",
  table_status = "audit", table_domains = "audit", source_grains = "audit",
  table_reconciliation = "audit", reconciliation_cell_rules = "audit",
  reconciliation_cell_classification = "audit",
  releases = "audit", data_releases = "audit", active_data_release = "audit",
  distribution_artifacts = "audit",
  source_region_rules = "audit", source_region_classification = "audit",
  source_provenance = "raw", aggregate_identities = "audit",
  expected_observation_grid = "staging", observation_missingness = "staging",
  build_identity = "audit", build_environment = "audit",
  ingestion_run_attempts = "audit", source_value_tokens = "audit",
  report_cell_formulas = "raw", series_review = "canonical",
  # The staging names the in-place rebuilds use. DuckDB cannot alter a primary
  # key or add a CHECK, so those migrations build a replacement beside the table
  # and rename it; without an assignment the replacement would be created in
  # main and the rename would leave it there.
  fact_series_events_keyed = "canonical", fact_series_events_sk = "canonical",
  table_status_checked = "audit"
)

# The dynamically created tables -- one per financial worksheet, one per
# reference table, one per curated snapshot -- are named by rule rather than
# listed, because the set changes with the publications.
PROJECT_TABLE_SCHEMA_PATTERNS <- c(
  "^raw_" = "raw", "^reference_.*_snapshot$" = "raw", "_snapshot$" = "staging"
)

project_schema_for <- function(table_name) {
  assigned <- unname(PROJECT_TABLE_SCHEMA[table_name])
  if (!is.na(assigned)) return(assigned)
  for (pattern in names(PROJECT_TABLE_SCHEMA_PATTERNS)) {
    if (grepl(pattern, table_name)) return(unname(PROJECT_TABLE_SCHEMA_PATTERNS[[pattern]]))
  }
  # An unassigned table stays in main rather than failing the run. That is
  # visible -- validate_database() raises storage_layer_unassigned -- and a table
  # in the wrong place is a smaller problem than a release that will not start.
  "main"
}

project_qualified_name <- function(table_name) {
  paste0(project_schema_for(table_name), ".", table_name)
}

# A transaction that joins an outer one instead of failing on it.
#
# DuckDB has no nested transactions: a second BEGIN inside an open transaction is
# an error, not a savepoint. Every unit here that rewrites a table wraps itself
# for its own sake, which was correct while each ran alone -- and became a hard
# failure the moment the release-wide phases were wrapped as one product, because
# eight of them opened their own.
#
# So a unit asks for a transaction and gets either its own or the caller's. Run
# standalone it is atomic exactly as before; run inside the release transaction it
# contributes to that atomicity rather than competing with it.
#
# Depth is tracked per connection rather than detected by attempting the BEGIN.
# Attempting it looks tidier and does not work: DuckDB marks a transaction
# aborted as soon as any statement in it fails, so the probe that discovers "one
# is already open" is itself what poisons the one that was open, and every
# statement after it fails with "current transaction is aborted".
PROJECT_TRANSACTIONS <- new.env(parent = emptyenv())

project_connection_key <- function(con) {
  key <- tryCatch(format(con@conn_ref), error = function(e) NULL)
  if (is.null(key) || !length(key) || !nzchar(key)) "default" else key[[1]]
}

project_transaction_open <- function(con) {
  isTRUE(PROJECT_TRANSACTIONS[[project_connection_key(con)]])
}

# The explicit form, for the one place that cannot use a block: the per-source
# ingestion opens its transaction, does work across a tryCatch boundary, and
# commits or rolls back in different branches.
#
# It must go through here rather than calling DBI directly. A bare DBI::dbBegin()
# leaves this register saying no transaction is open, so the first unit inside
# that asks for one tries to open a second -- and in DuckDB that failed BEGIN
# aborts the transaction it was asking about, taking the whole source down with a
# message about a transaction nobody wrote.
project_begin_transaction <- function(con) {
  DBI::dbBegin(con)
  assign(project_connection_key(con), TRUE, envir = PROJECT_TRANSACTIONS)
  invisible(TRUE)
}

project_commit_transaction <- function(con) {
  on.exit(assign(project_connection_key(con), FALSE, envir = PROJECT_TRANSACTIONS), add = TRUE)
  DBI::dbCommit(con)
  invisible(TRUE)
}

project_rollback_transaction <- function(con) {
  on.exit(assign(project_connection_key(con), FALSE, envir = PROJECT_TRANSACTIONS), add = TRUE)
  try(DBI::dbRollback(con), silent = TRUE)
  invisible(TRUE)
}

with_project_transaction <- function(con, code) {
  if (project_transaction_open(con)) return(force(code))
  project_begin_transaction(con)
  committed <- FALSE
  on.exit(if (!committed) project_rollback_transaction(con), add = TRUE)
  result <- force(code)
  project_commit_transaction(con)
  committed <- TRUE
  result
}

# The vintages a researcher is allowed to see: those bundled by the source bundle
# that the *active data release* points at.
#
# Sources commit one at a time and are marked completed before the release-wide
# validation runs, so 'this vintage loaded' has never meant 'this vintage may be
# published'. Every published interface filters through this, in SQL, so
# publishing a build is one pointer swap and no view has to be rebuilt.
#
# It used to read `releases.status = 'accepted'` directly. That made publication a
# mutable property of the source bundle, and a rebuild of an accepted bundle that
# failed set the same row to blocked -- withdrawing the whole database because the
# *next* build broke. Publication is now a property of a decided product, and a
# failed build cannot move the pointer. See data_releases in 02_extract_raw.R.
accepted_release_vintages_sql <- function() {
  paste(
    "SELECT rs.vintage_id FROM release_sources rs",
    "JOIN active_data_release a ON a.source_bundle_id = rs.release_id"
  )
}

# --- A record that survives the process ---------------------------------------
# The re-audit's A11 #16. `ensure_dirs()` has created logs/ since the first
# audit and nothing has ever written to it: run history lives in DuckDB and in
# outputs/*_latest.csv, both of which are *inside* the thing being built and both
# overwritten by the next run.
#
# That is fine until the case this exists for. A build that dies before its
# candidate can be opened, or one that is refused by the lock, or one whose swap
# is interrupted, leaves no database to have recorded anything in -- and the
# messages go to stderr and vanish with the session. One line of JSON per event,
# appended, is the smallest thing that answers "what happened at 03:14" a week
# later.
#
# Deliberately not a logging framework: no dependency, no configuration, no
# levels. If it grows one it should be because something needed it.
write_run_log <- function(root, event, ...) {
  if (is.null(root) || !nzchar(root)) return(invisible(FALSE))
  directory <- file.path(root, "logs")
  if (!dir.exists(directory)) return(invisible(FALSE))
  record <- c(
    list(
      at = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3"),
      event = event,
      pid = Sys.getpid(),
      host = as.character(Sys.info()[["nodename"]])
    ),
    lapply(list(...), function(value) {
      if (is.null(value) || length(value) != 1L) return(as.character(
        if (is.null(value)) NA_character_ else paste(value, collapse = "; ")
      ))
      if (is.na(value)) NA_character_ else value
    })
  )
  line <- tryCatch(
    jsonlite::toJSON(record, auto_unbox = TRUE, null = "null", na = "null"),
    error = function(e) NULL
  )
  if (is.null(line)) return(invisible(FALSE))
  path <- file.path(directory, paste0("update_", format(Sys.Date(), "%Y%m"), ".jsonl"))
  # Appending, and never failing the run because logging failed: a build must not
  # die because a disk is full of diagnostics.
  try(cat(line, "\n", sep = "", file = path, append = TRUE), silent = TRUE)
  invisible(TRUE)
}

# --- Single-writer coordination ----------------------------------------------
# The re-audit's RA2-08.
#
# The candidate design that closed F-01 has a consequence nobody had written
# down: because production is only ever *copied* and never opened, DuckDB's own
# single-writer lock gives no cross-run protection at all. Two updates can copy
# the same published database, build independently, both be accepted, and both
# rename over production -- last writer wins, and the loser's release disappears
# along with its build identity and every diagnostic it produced. Nothing in the
# repository prevented that, and nothing recorded that it could happen.
#
# `dir.create()` is the primitive: creating a directory is atomic on POSIX and
# on Windows, returns FALSE rather than throwing when it already exists, and
# needs no package. A lock file written with file.create() is not atomic in the
# same way -- two processes can both find it absent and both create it.
UPDATE_LOCK_NAME <- ".update.lock"

process_is_alive <- function(pid) {
  if (is.na(pid) || !nzchar(pid)) return(FALSE)
  if (.Platform$OS.type == "windows") {
    out <- suppressWarnings(tryCatch(system2(
      "tasklist", c("/FI", shQuote(paste0("PID eq ", pid))), stdout = TRUE, stderr = FALSE
    ), error = function(e) character()))
    return(any(grepl(paste0("\\b", pid, "\\b"), out)))
  }
  # kill -0 tests for existence without signalling. A non-zero status means the
  # process is gone (or is not ours, which for this purpose is the same answer).
  identical(suppressWarnings(system2(
    "kill", c("-0", pid), stdout = FALSE, stderr = FALSE
  )), 0L)
}

acquire_update_lock <- function(root) {
  path <- file.path(root, "database", UPDATE_LOCK_NAME)
  holder <- function() {
    info <- tryCatch(readr::read_csv(
      file.path(path, "holder.csv"), show_col_types = FALSE,
      col_types = readr::cols(.default = readr::col_character())
    ), error = function(e) NULL)
    if (is.null(info) || !nrow(info)) NULL else as.list(info[1, ])
  }
  take <- function() {
    readr::write_csv(tibble(
      pid = as.character(Sys.getpid()),
      host = as.character(Sys.info()[["nodename"]]),
      started_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
    ), file.path(path, "holder.csv"))
    path
  }
  if (suppressWarnings(dir.create(path))) return(take())

  current <- holder()
  # A lock whose holder is gone is debris from a killed run, not a live writer.
  # Refusing forever would mean a crashed update blocks every future one, which
  # is a worse failure than the one the lock prevents.
  if (is.null(current)) {
    message("Update lock exists with no readable holder; taking it over.")
    return(take())
  }
  same_host <- identical(current$host, as.character(Sys.info()[["nodename"]]))
  if (same_host && !process_is_alive(current$pid)) {
    message(
      "Update lock was held by process ", current$pid, " (started ", current$started_at,
      "), which is no longer running. Taking it over."
    )
    return(take())
  }
  stop(
    "Another update holds the lock: process ", current$pid, " on ", current$host,
    ", started ", current$started_at, ". Two updates must not build and publish at once -- ",
    "they would copy the same database and the last to finish would silently discard the ",
    "other's release. Wait for it, or remove ", path, " if you are certain it is dead.",
    call. = FALSE
  )
}

release_update_lock <- function(path) {
  if (is.null(path) || is.na(path) || !nzchar(path)) return(invisible(FALSE))
  unlink(path, recursive = TRUE, force = TRUE)
  invisible(TRUE)
}

# Every vintage that was ever published -- which is a different question, and the
# one a point-in-time query asks.
#
# The re-audit's RA2-01. `accepted_release_vintages_sql()` above resolves through
# a *one-row* pointer, so it answers "what is published now". `release_id` is a
# hash of the manifest, so replacing a single workbook mints a new bundle whose
# release_sources set omits the superseded vintage. The old vintage stays in
# fact_series_events, in source_files and in input_archive/ -- and drops out of
# the population the as-of ranking sees. `series_as_of_date()` ranked over the
# active bundle, so it could only ever return the current vintage, whatever date
# it was asked about.
#
# The ingredients for the right answer already existed and were never joined:
# release_sources is append-only and many-to-many, and data_releases records one
# immutable decision per product. Their join is the set of vintages a researcher
# could ever have been shown.
#
# It reads `data_releases.status`, not `releases.status`. The latter is the
# mutable per-bundle column schema 30 retired as the publication test precisely
# because a failed rebuild flipped it to blocked; using it here would let a later
# failure erase history that was genuinely published.
accepted_history_vintages_sql <- function() {
  paste(
    "SELECT DISTINCT rs.vintage_id FROM release_sources rs",
    "JOIN data_releases d ON d.source_bundle_id = rs.release_id",
    "WHERE d.status = 'accepted'"
  )
}

# Which accepted product first admitted each vintage, and when.
#
# This replaces `max(release_id)` over hashed identifiers, which picked whichever
# hex prefix sorted highest: not the earliest, not the latest, not the active one.
# For a historical row the meaningful context is the product that first published
# it, so that is what is recorded, with the decision timestamp beside it.
admitting_data_release_sql <- function() {
  paste(
    "SELECT rs.vintage_id,",
    "       arg_min(d.data_release_id, d.decided_at) AS accepted_release_id,",
    "       min(d.decided_at) AS first_published_at",
    "FROM release_sources rs",
    "JOIN data_releases d ON d.source_bundle_id = rs.release_id",
    "WHERE d.status = 'accepted' GROUP BY 1"
  )
}

# Publication decisions are recorded once per product and never rewritten, so a
# later build cannot restate what an earlier one was found to be. Re-deciding the
# same product identically is a no-op -- a deterministic rebuild reaching the same
# verdict is not a contradiction -- and re-deciding it differently is an error.
record_data_release_decision <- function(con, source_bundle_id, build_id, attempt_id,
                                         schema_version, status, errors, warnings,
                                         decided_by = "release_gate") {
  if (!status %in% c("accepted", "blocked")) stop(
    "A data release is decided accepted or blocked, not '", status, "'.", call. = FALSE
  )
  existing <- DBI::dbGetQuery(con, paste0(
    "SELECT status FROM ", project_qualified_name("data_releases"),
    " WHERE data_release_id = ", sql_string(build_id)
  ))
  if (nrow(existing)) {
    if (!identical(existing$status[[1]], status)) stop(
      "Data release ", build_id, " was already decided '", existing$status[[1]],
      "' and cannot be restated as '", status, "'. A recorded decision is immutable; ",
      "a different verdict from the same code, configuration and sources means one of ",
      "them is not what it claims to be.", call. = FALSE
    )
    return(invisible(FALSE))
  }
  DBI::dbWriteTable(con, "data_releases", tibble(
    data_release_id = build_id, source_bundle_id = source_bundle_id, build_id = build_id,
    attempt_id = attempt_id, schema_version = as.integer(schema_version), status = status,
    error_count = as.integer(errors), warning_count = as.integer(warnings),
    decided_at = Sys.time(), decided_by = decided_by
  ), append = TRUE)
  invisible(TRUE)
}

# The pointer swap, and the only thing that publishes anything.
#
# Called only for an accepted product. A blocked one never reaches here, which is
# the whole point: the previously published product stays published, and the
# operator reads the flags and decides what to do, rather than discovering that a
# broken run has emptied every research view.
promote_data_release <- function(con, data_release_id, source_bundle_id,
                                 promoted_by = "release_gate") {
  decided <- DBI::dbGetQuery(con, paste0(
    "SELECT status FROM ", project_qualified_name("data_releases"),
    " WHERE data_release_id = ", sql_string(data_release_id)
  ))
  if (!nrow(decided)) stop(
    "Data release ", data_release_id, " has no recorded decision and cannot be promoted.",
    call. = FALSE
  )
  if (!identical(decided$status[[1]], "accepted")) stop(
    "Data release ", data_release_id, " was decided '", decided$status[[1]],
    "' and must not be promoted.", call. = FALSE
  )
  with_project_transaction(con, {
    DBI::dbExecute(con, paste0("DELETE FROM ", project_qualified_name("active_data_release")))
    DBI::dbWriteTable(con, "active_data_release", tibble(
      singleton = TRUE, data_release_id = data_release_id,
      source_bundle_id = source_bundle_id, promoted_at = Sys.time(),
      promoted_by = promoted_by
    ), append = TRUE)
  })
  invisible(TRUE)
}

# Where an object *actually is*, which during a migration is not always where it
# belongs. relocate_tables_to_storage_layers() has not run yet when
# initialize_database() first asks what version this database is at, so a
# pre-schema-21 file still has schema_version in main while
# project_qualified_name() would already say audit.
database_object_qualified_name <- function(con, object_name) {
  found <- DBI::dbGetQuery(con, paste0(
    "SELECT table_schema FROM information_schema.tables WHERE table_name = ",
    sql_string(object_name), " AND table_schema IN (",
    paste(vapply(c("main", PROJECT_SCHEMAS), sql_string, character(1)), collapse = ", "),
    ") ORDER BY CASE WHEN table_schema = 'main' THEN 1 ELSE 0 END LIMIT 1"
  ))
  if (!nrow(found)) return(project_qualified_name(object_name))
  paste0(found$table_schema[[1]], ".", object_name)
}

# --- Schema-qualified stored SQL --------------------------------------------
# project_schema_for() answers where a *table* belongs by declaration. A view
# body also references other views, which are not in that declaration and whose
# schema is decided by where they were created. So the qualifier reads the live
# catalogue instead, and falls back to the declaration for a table the migration
# is about to create.
#
# The lookup is per-connection and rebuilt on demand: views are created in
# dependency order, so every object a body names already exists by the time the
# body is written.
project_object_schemas <- function(con) {
  rows <- DBI::dbGetQuery(con, paste0(
    "SELECT table_name, table_schema FROM information_schema.tables",
    " WHERE table_schema IN (",
    paste(vapply(c("main", PROJECT_SCHEMAS), sql_string, character(1)), collapse = ", "), ")"
  ))
  if (!nrow(rows)) return(character())
  # An object present in both main and a layer is mid-migration -- the layer copy
  # is the one that survives, so it wins.
  rows <- rows[order(rows$table_name, rows$table_schema == "main"), , drop = FALSE]
  rows <- rows[!duplicated(rows$table_name), , drop = FALSE]
  stats::setNames(rows$table_schema, rows$table_name)
}

# Names introduced by the query itself -- common table expressions -- are not
# database objects and must never be qualified, even when one happens to share a
# name with a table. Matching "<name> AS (" after WITH or a comma finds them.
sql_cte_names <- function(sql) {
  pattern <- paste0(
    "(?i)(?:\\bWITH\\s+(?:RECURSIVE\\s+)?|,\\s*)",   # WITH, WITH RECURSIVE, or the next in the list
    "([A-Za-z_][A-Za-z0-9_]*)",                       # the name
    "\\s*(?:\\([^)]*\\))?\\s+AS\\s*\\("               # an optional column list, then AS (
  )
  matches <- regmatches(sql, gregexpr(pattern, sql, perl = TRUE))[[1]]
  if (!length(matches)) return(character())
  unique(sub(paste0("(?is)^", pattern, "$"), "\\1", matches, perl = TRUE))
}

# Qualification is confined to table position -- immediately after FROM or JOIN.
# A column, an alias, a string literal or a function argument that happens to
# spell a table name is therefore untouched, which is what makes a textual
# rewrite safe here. A reference that is already qualified does not match,
# because the token after FROM is then the schema.
#
# main-resident views are qualified too, which is not cosmetic. A bare name binds
# against the caller's catalog, so `marts.v_mart_trade_all` selecting `FROM
# v_series_observations` resolves correctly on a direct connection and fails the
# moment the file is ATTACHed under an alias -- the caller's own main is searched
# instead of the database the view lives in. That is how a researcher combines
# this database with their own, and how compact_database.R and 07_migration.R
# already read across releases. A schema-qualified name binds inside the view's
# own catalog, so `main.v_series_observations` resolves under any alias.
qualify_project_sql <- function(con, sql, schemas = project_object_schemas(con)) {
  if (!length(schemas)) return(sql)
  known <- setdiff(names(schemas), sql_cte_names(sql))
  # Longest first: no name in this project is a prefix of another at a word
  # boundary, but ordering costs nothing and removes the question.
  for (object in known[order(nchar(known), decreasing = TRUE)]) {
    sql <- gsub(
      paste0("(\\b(?:FROM|JOIN)\\s+)(\"?)", object, "\\2\\b(?!\\s*\\.)"),
      paste0("\\1", unname(schemas[[object]]), ".", object), sql, perl = TRUE
    )
  }
  sql
}

# The single door every stored object goes through. The body is qualified, and
# the object's own name is placed in the layer that owns it -- marts for the
# research interface, main for everything internal.
create_project_view <- function(con, view_name, body, schema = NULL) {
  schemas <- project_object_schemas(con)
  target <- if (!is.null(schema)) schema else if (grepl(".", view_name, fixed = TRUE)) {
    NULL
  } else "main"
  qualified <- if (is.null(target)) view_name else paste0(target, ".", quote_object(view_name))
  DBI::dbExecute(con, paste0(
    "CREATE OR REPLACE VIEW ", qualified, " AS ", qualify_project_sql(con, body, schemas)
  ))
  invisible(qualified)
}

create_project_macro <- function(con, macro_name, body) {
  DBI::dbExecute(con, paste0(
    "CREATE OR REPLACE MACRO main.", macro_name, " ", qualify_project_sql(con, body)
  ))
  invisible(TRUE)
}

# A view name generated from a worksheet may need quoting; a hand-written one
# never does, and quoting it unconditionally would change nothing but the noise.
quote_object <- function(name) {
  if (grepl("^[a-z_][a-z0-9_]*$", name)) name else paste0("\"", gsub("\"", "\"\"", name), "\"")
}

# Set once per connection, by initialize_database() and by every read-only
# helper. With it, every unqualified name in the project resolves as it always
# did, including through DBI's dbExistsTable() and dbWriteTable(append = TRUE).
# main stays first so anything unassigned is still found and still created there.
set_project_search_path <- function(con) {
  existing <- DBI::dbGetQuery(con, "SELECT schema_name FROM information_schema.schemata")$schema_name
  path <- c("main", PROJECT_SCHEMAS)
  path <- path[path %in% existing]
  DBI::dbExecute(con, paste0(
    "SET search_path = '", paste(path, collapse = ","), "'"
  ))
  invisible(TRUE)
}

connect_project_database <- function(path, read_only = FALSE) {
  con <- DBI::dbConnect(duckdb::duckdb(), path, read_only = read_only)
  try(set_project_search_path(con), silent = TRUE)
  con
}

# Objects are looked for across every layer, not only the current schema. Before
# the layers existed this asked about current_schema() and was right by
# accident; now that is the one schema most of the database is not in.
database_object_exists <- function(con, object_name) {
  DBI::dbGetQuery(con, paste0(
    "SELECT COUNT(*) AS n FROM information_schema.tables WHERE table_schema IN (",
    paste(vapply(c("main", PROJECT_SCHEMAS), sql_string, character(1)), collapse = ", "),
    ") AND table_name = ", sql_string(object_name)
  ))$n[[1]] > 0
}

# A guard that runs before a migration has added a column has to ask, not
# assume: the same validation code runs against a database at any schema version
# the upgrade path supports.
table_column_names <- function(con, table_name) {
  if (!database_object_exists(con, table_name)) return(character())
  DBI::dbGetQuery(con, paste0("PRAGMA table_info(", sql_string(table_name), ")"))$name
}

# Rewrite a small governance table only when its content actually changed.
#
# Every governance register in this project is rebuilt from its CSV on each run:
# delete every row, write the current set back. That is the right design -- it
# makes the configuration file the single source of truth, so a row deleted from
# a CSV disappears from the database -- but DuckDB never edits a block in place,
# so an unchanged table still costs a fresh copy of itself every run. Ten of
# these are rewritten per release, which is most of the ~9 MiB a non-migrating
# run allocates (docs/DATABASE_STORAGE.md, section 4).
#
# The comparison is over content, not order: rows are hashed after sorting by
# every column, so a table that comes back in a different order is still
# recognised as unchanged.
content_fingerprint <- function(rows) {
  if (!nrow(rows)) return("empty")
  rows <- rows[do.call(order, unname(as.list(rows))), , drop = FALSE]
  digest::digest(
    paste(vapply(rows, function(column) paste(format(column, digits = 17), collapse = ""),
                 character(1)), collapse = ""),
    algo = "sha256", serialize = FALSE
  )
}

replace_table_if_changed <- function(con, table_name, rows) {
  quoted <- DBI::dbQuoteIdentifier(con, table_name)
  current <- DBI::dbGetQuery(con, paste0("SELECT * FROM ", quoted))
  rows <- rows[intersect(names(current), names(rows))]
  if (identical(names(current), names(rows)) &&
      identical(content_fingerprint(current), content_fingerprint(rows))) {
    return(invisible(FALSE))
  }
  with_project_transaction(con, {
    DBI::dbExecute(con, paste0("DELETE FROM ", quoted))
    if (nrow(rows)) DBI::dbWriteTable(con, table_name, rows, append = TRUE)
  })
  invisible(TRUE)
}

# Where a file sits inside the repository, rather than where it sat on the
# machine that ingested it.
#
# The audit found every durable path in source_files recorded as an absolute
# /Users/... path. That is two problems at once: it does not survive being
# opened on another machine, and it publishes the operator's directory layout to
# anyone the database is shared with. The repository-relative URI is the durable
# identity of the file; the absolute path is a fact about one run and stays
# beside it as such.
#
# A path outside the repository -- a workbook opened from a Downloads folder --
# has no repository-relative form and returns NA rather than a fabricated one.
repository_uri <- function(path, root) {
  if (is.null(root) || is.na(path)) return(NA_character_)
  # normalizePath() does not resolve a symlinked ancestor (notably macOS's
  # /var -> /private/var) when the leaf does not exist yet. Artifact destinations
  # are intentionally recorded before the final rename, so canonicalize the
  # existing parent and then restore the prospective basename.
  absolute <- if (file.exists(path)) {
    normalizePath(path, winslash = "/", mustWork = FALSE)
  } else {
    file.path(
      normalizePath(dirname(path), winslash = "/", mustWork = FALSE),
      basename(path)
    )
  }
  base <- paste0(normalizePath(root, winslash = "/", mustWork = FALSE), "/")
  if (!startsWith(absolute, base)) return(NA_character_)
  substr(absolute, nchar(base) + 1L, nchar(absolute))
}

make_vintage_id <- function(source_id, sha256) {
  paste(source_id, substr(sha256, 1, 24), sep = ":")
}

make_release_id <- function(manifest) {
  keys <- paste(manifest$source_id, manifest$sha256, sep = ":")
  scope_columns <- c("release_scope_id", "release_scope_digest")
  present_scope_columns <- intersect(scope_columns, names(manifest))
  if (length(present_scope_columns) == 1L) stop(
    "A scoped source manifest must carry both release_scope_id and release_scope_digest.",
    call. = FALSE
  )
  if (length(present_scope_columns) == 2L) {
    scope_keys <- unique(paste(manifest$release_scope_id, manifest$release_scope_digest, sep = ":"))
    if (length(scope_keys) != 1L || any(is.na(scope_keys)) || any(!nzchar(scope_keys))) stop(
      "A scoped source manifest must name exactly one nonblank scope identity.", call. = FALSE
    )
    keys <- c(keys, paste0("release_scope:", scope_keys))
  }
  paste0("release:", substr(digest::digest(
    paste(sort(keys), collapse = "|"), algo = "sha256", serialize = FALSE
  ), 1, 24))
}

resolve_current_files <- function(source_row, root) {
  folder <- file.path(root, source_row$input_folder)
  files <- fs::dir_ls(folder, recurse = FALSE, type = "file", fail = FALSE)
  files <- files[grepl(source_row$file_pattern, basename(files), ignore.case = TRUE, perl = TRUE)]
  files <- files[!grepl("^~\\$", basename(files))]
  issues <- tibble(severity = character(), check_name = character(), detail = character())
  if (!length(files)) {
    severity <- if (isTRUE(source_row$required)) "error" else "warning"
    issues <- add_row(issues, severity = severity, check_name = "source_missing",
                      detail = paste("No matching workbook in", folder))
    return(list(files = character(), issues = issues))
  }
  if (!isTRUE(source_row$allow_multiple) && length(files) > 1L) {
    rule <- source_row$selection_rule
    if (!rule %in% SOURCE_SELECTION_RULES) {
      stop("Unsupported single-file selection_rule: ", rule, call. = FALSE)
    }
    # The audit's F-11: a copy time is not a publication order. A file copied
    # today can be older than the one beside it, and newest_mtime would make it
    # current with nothing but a non-blocking warning to say so. 'manifest'
    # resolves the file by the SHA-256 an operator recorded in
    # config/source_vintages.csv, which names the bytes rather than the moment
    # they landed on this disk.
    if (identical(rule, "manifest")) {
      registered <- source_vintage_registry(root)
      wanted <- registered$sha256[registered$source_id == source_row$source_id]
      wanted <- wanted[!is.na(wanted) & nzchar(wanted)]
      hashes <- vapply(files, function(path) digest::digest(file = path, algo = "sha256"), character(1))
      chosen <- files[hashes %in% wanted]
      if (length(chosen) != 1L) {
        issues <- add_row(
          issues, severity = if (isTRUE(source_row$required)) "error" else "warning",
          check_name = "manifest_selection_unresolved",
          detail = paste0(
            "selection_rule 'manifest' matched ", length(chosen), " of ", length(files),
            " candidate file(s) in ", folder, " against the SHA-256 values recorded for ",
            source_row$source_id, " in config/source_vintages.csv. Record the intended file's ",
            "hash, or remove the others."
          )
        )
        return(list(files = character(), issues = issues))
      }
      files <- chosen
    } else {
      info <- file.info(files)
      chosen <- files[[which.max(info$mtime)]]
      ignored <- setdiff(files, chosen)
      issues <- add_row(
        issues, severity = "warning", check_name = "multiple_candidates",
        detail = paste0(
          "Selected ", basename(chosen), " on modification time and ignored ",
          paste(basename(ignored), collapse = "; "),
          ". Modification time is when the file reached this disk, not when the publisher ",
          "released it; set selection_rule to 'manifest' and record the intended SHA-256 in ",
          "config/source_vintages.csv to choose explicitly."
        )
      )
      files <- chosen
    }
  }
  list(files = sort(files), issues = issues)
}

build_current_manifest <- function(registry, root) {
  records <- list(); issues <- list(); k <- 0L; z <- 0L
  for (i in seq_len(nrow(registry))) {
    source_row <- registry[i, ]
    resolved <- resolve_current_files(source_row, root)
    if (nrow(resolved$issues)) {
      z <- z + 1L
      issues[[z]] <- resolved$issues %>% mutate(source_id = source_row$source_id, .before = 1)
    }
    for (path in resolved$files) {
      sha <- file_sha256(path)
      k <- k + 1L
      records[[k]] <- tibble(
        source_id = source_row$source_id,
        source_label = source_row$source_label,
        publisher = source_row$publisher,
        source_format = source_row$source_format,
        ingest_mode = source_row$ingest_mode,
        semantic_status = source_row$semantic_status,
        path = path,
        source_file = basename(path),
        sha256 = sha,
        vintage_id = make_vintage_id(source_row$source_id, sha)
      )
    }
  }
  list(manifest = bind_rows(records), issues = bind_rows(issues))
}

# A product release may deliberately admit a narrower population than the
# global source registry. The registry still answers whether a source is part of
# the project and whether its current file is required; this governed table
# answers the separate question "which exact bytes define this product?".
#
# The scope is positive and exhaustive. Every registered source has one exact
# hash decision, including deferrals, so a new source or changed vintage cannot
# disappear merely because it was not on an allowlist. Such drift becomes a
# release-blocking resolution issue before any source is linked or ingested.
RELEASE_INPUT_SCOPE_COLUMNS <- c(
  "scope_id", "schema_version", "source_id", "sha256", "disposition", "reason",
  "decided_by", "decided_at", "evidence"
)

release_input_scope_digest <- function(scope) {
  ordered <- scope[order(scope$source_id, method = "radix"), RELEASE_INPUT_SCOPE_COLUMNS,
                   drop = FALSE]
  rows <- apply(ordered, 1, function(row) paste(row, collapse = "|"))
  digest::digest(paste(rows, collapse = "\n"), algo = "sha256", serialize = FALSE)
}

read_release_input_scope <- function(root, scope_id) {
  path <- file.path(root, "config", "release_input_scope.csv")
  if (!file.exists(path)) stop(
    "Release-input scope not found: ", path, ". A scoped release must fail closed.",
    call. = FALSE
  )
  scopes <- project_cached_config(path, function(config_path) readr::read_csv(
    config_path, show_col_types = FALSE,
    col_types = readr::cols(.default = readr::col_character())
  ))
  if (!identical(names(scopes), RELEASE_INPUT_SCOPE_COLUMNS)) stop(
    "config/release_input_scope.csv must have exactly these columns in order: ",
    paste(RELEASE_INPUT_SCOPE_COLUMNS, collapse = ", "), call. = FALSE
  )
  scope <- scopes[!is.na(scopes$scope_id) & scopes$scope_id == scope_id, , drop = FALSE]
  if (!nrow(scope)) stop("Unknown release-input scope: ", scope_id, call. = FALSE)
  incomplete <- apply(scope, 1, function(row) any(is.na(row) | !nzchar(trimws(row))))
  if (any(incomplete)) stop(
    "Release-input scope ", scope_id, " has ", sum(incomplete),
    " row(s) with blank governed fields.", call. = FALSE
  )
  if (anyDuplicated(scope$source_id)) stop(
    "Release-input scope ", scope_id, " must decide each source_id exactly once.",
    call. = FALSE
  )
  if (any(!grepl("^[0-9a-f]{64}$", scope$sha256))) stop(
    "Release-input scope ", scope_id, " contains a non-full or invalid SHA-256.",
    call. = FALSE
  )
  if (any(!scope$disposition %in% c("admit", "defer"))) stop(
    "Release-input scope ", scope_id, " uses an unsupported disposition.", call. = FALSE
  )
  if (length(unique(scope$schema_version)) != 1L ||
      !grepl("^[0-9]+$", unique(scope$schema_version))) stop(
    "Release-input scope ", scope_id, " must name exactly one integer schema_version.",
    call. = FALSE
  )
  scope
}

apply_release_input_scope <- function(registry, resolved, root, scope_id,
                                      expected_schema_version = NULL) {
  scope <- read_release_input_scope(root, scope_id)
  issues <- resolved$issues
  add_scope_issue <- function(source_id, severity, check_name, detail) {
    issues <<- dplyr::bind_rows(issues, tibble::tibble(
      source_id = source_id, severity = severity, check_name = check_name, detail = detail
    ))
  }

  schema_version <- as.integer(unique(scope$schema_version))
  if (!is.null(expected_schema_version) &&
      !identical(schema_version, as.integer(expected_schema_version))) stop(
    "Release-input scope ", scope_id, " is for schema ", schema_version,
    ", not schema ", expected_schema_version, ".", call. = FALSE
  )

  registered <- as.character(registry$source_id)
  if (anyDuplicated(registered)) stop("config/source_registry.csv contains duplicate source_id values.",
                                      call. = FALSE)
  missing_decisions <- setdiff(registered, scope$source_id)
  stale_decisions <- setdiff(scope$source_id, registered)
  for (source_id in missing_decisions) add_scope_issue(
    source_id, "error", "release_input_scope_unresolved",
    paste0("Release-input scope ", scope_id, " has no decision for registered source ",
           source_id, ". The source is not admitted.")
  )
  for (source_id in stale_decisions) add_scope_issue(
    source_id, "error", "release_input_scope_unresolved",
    paste0("Release-input scope ", scope_id, " decides source ", source_id,
           " but that source is absent from config/source_registry.csv.")
  )

  manifest <- resolved$manifest
  admitted <- vector("list", nrow(scope))
  admitted_n <- 0L
  for (i in seq_len(nrow(scope))) {
    decision <- scope[i, , drop = FALSE]
    current <- manifest[manifest$source_id == decision$source_id[[1]], , drop = FALSE]
    exact <- current[current$sha256 == decision$sha256[[1]], , drop = FALSE]
    if (nrow(current) != 1L || nrow(exact) != 1L) {
      observed <- if (!nrow(current)) "none" else paste(current$sha256, collapse = ";")
      add_scope_issue(
        decision$source_id[[1]], "error", "release_input_scope_unresolved",
        paste0(
          "Release-input scope ", scope_id, " expects exactly ", decision$disposition[[1]],
          " ", decision$source_id[[1]], ":", decision$sha256[[1]],
          " but the current resolver found ", nrow(current), " candidate(s) with SHA-256 ",
          observed, ". No current bytes for this source are admitted."
        )
      )
      next
    }
    if (identical(decision$disposition[[1]], "defer")) {
      add_scope_issue(
        decision$source_id[[1]], "warning", "release_input_deferred",
        paste0(
          "Release-input scope ", scope_id, " explicitly defers ", exact$vintage_id[[1]],
          " (full SHA-256 ", exact$sha256[[1]], "): ", decision$reason[[1]]
        )
      )
      next
    }
    admitted_n <- admitted_n + 1L
    admitted[[admitted_n]] <- exact
  }

  unexpected <- setdiff(unique(manifest$source_id), scope$source_id)
  for (source_id in unexpected) add_scope_issue(
    source_id, "error", "release_input_scope_unresolved",
    paste0("Current resolver found source ", source_id, " outside release-input scope ",
           scope_id, ". The source is not admitted.")
  )

  admitted <- if (admitted_n) dplyr::bind_rows(admitted[seq_len(admitted_n)]) else manifest[0, ]
  scope_digest <- release_input_scope_digest(scope)
  admitted$release_scope_id <- scope_id
  admitted$release_scope_digest <- scope_digest
  list(
    manifest = admitted, issues = issues, scope = scope,
    scope_id = scope_id, scope_digest = scope_digest, schema_version = schema_version
  )
}

build_scoped_current_manifest <- function(registry, root, scope_id,
                                          expected_schema_version = NULL) {
  apply_release_input_scope(
    registry, build_current_manifest(registry, root), root, scope_id,
    expected_schema_version = expected_schema_version
  )
}

build_archive_manifest <- function(registry, root) {
  manifest_path <- file.path(root, "input_archive", "archive_manifest.csv")
  if (file.exists(manifest_path)) {
    archived <- readr::read_csv(manifest_path, show_col_types = FALSE) %>%
      distinct(source_id, sha256, .keep_all = TRUE)
    records <- archived %>% inner_join(
      registry %>% select(source_id, source_label, publisher, source_format, ingest_mode, semantic_status), by = "source_id"
    ) %>% mutate(
      path = file.path(root, archive_path),
      fallback_mtime = file.info(path)$mtime
    ) %>% filter(file.exists(path)) %>% transmute(
      source_id, source_label, publisher, source_format, ingest_mode, semantic_status,
      path, source_file = original_filename,
      sha256, vintage_id = make_vintage_id(source_id, sha256),
      inferred_date = as.Date(publication_date), fallback_mtime
    )
    return(records %>% arrange(source_id, is.na(inferred_date), inferred_date, fallback_mtime) %>%
             select(-inferred_date, -fallback_mtime))
  }
  records <- list(); k <- 0L
  for (i in seq_len(nrow(registry))) {
    source_row <- registry[i, ]
    folder <- file.path(root, "input_archive", source_row$source_id)
    files <- fs::dir_ls(folder, regexp = "\\.(xlsx|xlsm|csv)$", recurse = FALSE, fail = FALSE)
    for (path in files) {
      sha <- tools::file_path_sans_ext(basename(path))
      if (!grepl("^[0-9a-f]{64}$", sha)) sha <- file_sha256(path)
      k <- k + 1L
      records[[k]] <- tibble(
        source_id = source_row$source_id, source_label = source_row$source_label,
        publisher = source_row$publisher, source_format = source_row$source_format,
        ingest_mode = source_row$ingest_mode, semantic_status = source_row$semantic_status,
        path = path, source_file = basename(path),
        sha256 = sha, vintage_id = make_vintage_id(source_row$source_id, sha),
        inferred_date = infer_publication_date_from_name(path), fallback_mtime = file.info(path)$mtime
      )
    }
  }
  bind_rows(records) %>% arrange(source_id, is.na(inferred_date), inferred_date, fallback_mtime) %>%
    select(-inferred_date, -fallback_mtime)
}

spanish_month_number <- function(x) {
  keys <- c(ene = 1L, enero = 1L, feb = 2L, febrero = 2L, mar = 3L, marzo = 3L,
            abr = 4L, abril = 4L, may = 5L, mayo = 5L, jun = 6L, junio = 6L,
            jul = 7L, julio = 7L, ago = 8L, agosto = 8L, sep = 9L, sept = 9L,
            setiembre = 9L, septiembre = 9L, oct = 10L, octubre = 10L, nov = 11L, noviembre = 11L,
            dic = 12L, diciembre = 12L)
  unname(keys[[normalize_label(x)]])
}

month_end <- function(year, month) {
  as.Date(lubridate::ceiling_date(as.Date(sprintf("%04d-%02d-01", year, month)), "month") - days(1))
}

infer_publication_date_from_name <- function(path) {
  x <- normalize_label(tools::file_path_sans_ext(basename(path)))
  full <- str_match(x, "(20[0-9]{2})[_ -]([01]?[0-9])[_ -]([0-3]?[0-9])")
  if (!is.na(full[1, 1])) return(as.Date(sprintf("%s-%02d-%02d", full[1, 2], as.integer(full[1, 3]), as.integer(full[1, 4]))))
  dmy <- str_match(x, "([0-3]?[0-9])[_ -]([01]?[0-9])[_ -](20[0-9]{2})")
  if (!is.na(dmy[1, 1])) return(as.Date(sprintf("%s-%02d-%02d", dmy[1, 4], as.integer(dmy[1, 3]), as.integer(dmy[1, 2]))))
  named <- str_match(x, "(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)[_ -]+(20[0-9]{2})")
  if (!is.na(named[1, 1])) return(month_end(as.integer(named[1, 3]), spanish_month_number(named[1, 2])))
  short <- str_match(x, "(ene|feb|mar|abr|may|jun|jul|ago|sep|oct|nov|dic)[_ -]*([0-9]{2})(?:[^0-9]|$)")
  if (!is.na(short[1, 1])) return(month_end(2000L + as.integer(short[1, 3]), spanish_month_number(short[1, 2])))
  as.Date(NA)
}

archive_source <- function(path, source_id, root, sha256, publication_date = as.Date(NA)) {
  archive_dir <- file.path(root, "input_archive", source_id)
  fs::dir_create(archive_dir, recurse = TRUE)
  normalized_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  normalized_archive <- normalizePath(archive_dir, winslash = "/", mustWork = TRUE)
  if (startsWith(normalized_path, paste0(normalized_archive, "/"))) {
    return(list(path = path, created = FALSE))
  }
  ext <- tools::file_ext(path)
  target <- file.path(archive_dir, paste0(sha256, ".", ext))
  created <- FALSE
  if (!file.exists(target)) {
    if (!file.copy(path, target, copy.date = TRUE)) stop("Could not archive source: ", path, call. = FALSE)
    created <- TRUE
  }
  manifest_path <- file.path(root, "input_archive", "archive_manifest.csv")
  relative_target <- file.path("input_archive", source_id, basename(target))
  manifest <- if (file.exists(manifest_path)) readr::read_csv(manifest_path, show_col_types = FALSE) %>%
    mutate(publication_date = as.Date(as.character(publication_date)), archived_at = as.POSIXct(as.character(archived_at), tz = "UTC")) else tibble(
    source_id = character(), sha256 = character(), archive_path = character(),
    original_filename = character(), publication_date = as.Date(character()), archived_at = as.POSIXct(character())
  )
  if (!any(manifest$source_id == source_id & manifest$sha256 == sha256)) {
    manifest <- bind_rows(manifest, tibble(
      source_id = source_id, sha256 = sha256, archive_path = relative_target,
      original_filename = basename(path), publication_date = as.Date(publication_date), archived_at = Sys.time()
    ))
    readr::write_csv(manifest, manifest_path)
  }
  list(path = target, created = created)
}

update_archive_manifest_date <- function(root, source_id, sha256, publication_date) {
  if (is.na(publication_date)) return(invisible(NULL))
  path <- file.path(root, "input_archive", "archive_manifest.csv")
  if (!file.exists(path)) return(invisible(NULL))
  manifest <- readr::read_csv(path, show_col_types = FALSE) %>% mutate(publication_date = as.Date(as.character(publication_date)))
  hit <- manifest$source_id == source_id & manifest$sha256 == sha256
  manifest$publication_date[hit] <- as.Date(publication_date)
  readr::write_csv(manifest, path)
  invisible(NULL)
}

# Config files are read on every worksheet of every source. Reading them once per
# (path, size, mtime) keeps that free while still picking up an operator's edit
# within the same session. documented_cached_config() in 03_curate_documented.R
# delegates here so the documented parsers and the ingestion layer share one cache.
.project_config_cache <- new.env(parent = emptyenv())

project_cached_config <- function(path, reader) {
  if (!file.exists(path)) return(NULL)
  info <- file.info(path)
  signature <- paste(info$size[[1]], as.numeric(info$mtime[[1]]), sep = "|")
  key <- normalizePath(path, winslash = "/", mustWork = TRUE)
  cached <- if (exists(key, envir = .project_config_cache, inherits = FALSE)) {
    get(key, envir = .project_config_cache, inherits = FALSE)
  } else NULL
  if (is.null(cached) || !identical(cached$signature, signature)) {
    cached <- list(signature = signature, data = reader(path))
    assign(key, cached, envir = .project_config_cache)
  }
  cached$data
}

# How a source with several candidate files picks one. 'manifest' names the file
# by its recorded hash; 'newest_mtime' guesses from the filesystem and says so.
SOURCE_SELECTION_RULES <- c("manifest", "newest_mtime")

# --- The temporal contract ---------------------------------------------------
# The normalized interval every published observation carries, written once
# because two carriers publish it and a second copy is a second answer.
#
# The database deliberately keeps `period` exactly as parsed. It is part of the
# observation key, and rewriting it would retire every identifier in the
# catalogue -- so the fix for the mixed monthly convention the readiness audit
# found (2,057 monthly series dated to month end, 1,757 to day 1, and 164
# alternating inside a single series) is not to rewrite the key but to publish
# the interval beside it. period_start and period_end describe the same month
# whichever day the publisher printed, so a join on them cannot silently lose
# observations or shift a lag by a month.
#
# A stored bound wins over a derived one. Only an irregular published interval
# has one -- CUADRO 11 publishes 83 of them, where no frequency implies "in
# force from 1 January to 30 June 1980" -- so this changes nothing for a series
# whose frequency already says what its interval is.
#
# Nothing here manufactures a daily interpretation of a lower-frequency
# observation: a frequency the contract does not name falls through to the
# parsed date on both bounds, which is a one-day interval and honest about it.
series_period_bounds_sql <- function(fact = "f", series = "d", stored = "b") {
  period <- paste0(fact, ".period")
  frequency <- paste0(series, ".frequency")
  stored_start <- if (is.null(stored)) NULL else paste0(stored, ".period_start")
  start_expression <- paste(
    "CASE", frequency,
    "  WHEN 'annual' THEN date_trunc('year',", period, ")",
    "  WHEN 'semiannual' THEN CASE WHEN month(", period, ") <= 6",
    "    THEN date_trunc('year',", period, ")",
    "    ELSE date_trunc('year',", period, ") + INTERVAL 6 MONTH END",
    "  WHEN 'quarterly' THEN date_trunc('quarter',", period, ")",
    "  WHEN 'monthly' THEN date_trunc('month',", period, ")",
    "  WHEN 'monthly_survey' THEN date_trunc('month',", period, ")",
    "  ELSE", period, "END"
  )
  paste(
    if (is.null(stored_start)) paste(start_expression, "AS period_start,")
    else paste("coalesce(", stored_start, ",", start_expression, ") AS period_start,"),
    "CASE", frequency,
    "  WHEN 'annual' THEN date_trunc('year',", period, ") + INTERVAL 1 YEAR - INTERVAL 1 DAY",
    "  WHEN 'semiannual' THEN CASE WHEN month(", period, ") <= 6",
    "    THEN date_trunc('year',", period, ") + INTERVAL 6 MONTH - INTERVAL 1 DAY",
    "    ELSE date_trunc('year',", period, ") + INTERVAL 1 YEAR - INTERVAL 1 DAY END",
    "  WHEN 'quarterly' THEN date_trunc('quarter',", period, ") + INTERVAL 3 MONTH - INTERVAL 1 DAY",
    "  WHEN 'monthly' THEN last_day(", period, ")",
    "  WHEN 'monthly_survey' THEN last_day(", period, ")",
    "  ELSE", period, "END AS period_end"
  )
}

SOURCE_VINTAGE_REGISTRY_COLUMNS <- c(
  "source_id", "sha256", "original_filename", "official_release_date", "official_url",
  "release_identifier", "retrieved_at", "retrieval_method", "availability_quality",
  "license", "evidence"
)

# How good the availability evidence is. The audit's ER-04 asks for availability
# to be defined conservatively and for the weaker definition to say that it is
# weaker, because a point-in-time result computed from a guess and one computed
# from a publisher's release timestamp are not the same claim and looked
# identical in the column that carried them.
#
# 'official_release'      the publisher's own release timestamp: the real answer.
# 'retrieval_time'        when an operator actually fetched the file. Later than
#                         availability, so as-of sees less rather than more.
# 'inferred_upper_bound'  no acquisition record survives; the moment the file
#                         entered the immutable archive bounds it from above.
#                         Safe in the same direction, and weaker evidence.
AVAILABILITY_QUALITY_VALUES <- c("official_release", "retrieval_time", "inferred_upper_bound")

# The operator-maintained record of where a source vintage came from. The audit's
# F-14: a publisher name is not provenance. This is also the highest authority for
# a publication date, because a date an operator read off the publisher's release
# page outranks anything a filename or a cell range can be made to say.
source_vintage_registry <- function(root) {
  path <- file.path(root, "config", "source_vintages.csv")
  empty <- tibble(!!!stats::setNames(
    rep(list(character()), length(SOURCE_VINTAGE_REGISTRY_COLUMNS)),
    SOURCE_VINTAGE_REGISTRY_COLUMNS
  ))
  registry <- project_cached_config(path, function(config_path) readr::read_csv(
    config_path, show_col_types = FALSE,
    col_types = readr::cols(.default = readr::col_character())
  ))
  if (is.null(registry)) return(empty)
  missing <- setdiff(SOURCE_VINTAGE_REGISTRY_COLUMNS, names(registry))
  if (length(missing)) stop(
    "config/source_vintages.csv is missing required column(s): ",
    paste(missing, collapse = ", "), call. = FALSE
  )
  registry
}

source_vintage_registry_row <- function(root, source_id, sha256) {
  registry <- source_vintage_registry(root)
  if (!nrow(registry)) return(NULL)
  hit <- registry$source_id == source_id & registry$sha256 == sha256
  if (!any(hit, na.rm = TRUE)) return(NULL)
  as.list(registry[which(hit)[[1]], , drop = FALSE])
}

# --- Execution environment ---------------------------------------------------
# The audit's F-09: package resolution was mutable and the test entry point
# installed packages, so running the tests could change the environment they were
# testing. renv.lock records what this project was verified against; this reads
# it back and says whether the running session matches.
#
# It reports rather than installs. Restoring an environment is `renv::restore()`,
# a deliberate act with a network and a library behind it, and doing it as a side
# effect of `source("run_tests.R")` is the problem, not the fix.
read_environment_lock <- function(root) {
  path <- file.path(root, "renv.lock")
  if (!file.exists(path)) return(NULL)
  lock <- if (requireNamespace("renv", quietly = TRUE)) {
    tryCatch(renv::lockfile_read(path), error = function(e) NULL)
  } else NULL
  if (is.null(lock) && requireNamespace("jsonlite", quietly = TRUE)) {
    lock <- tryCatch(jsonlite::fromJSON(path, simplifyVector = FALSE), error = function(e) NULL)
  }
  if (is.null(lock)) return(NULL)
  packages <- lock$Packages
  list(
    r_version = if (is.null(lock$R$Version)) NA_character_ else lock$R$Version,
    packages = tibble(
      package = vapply(packages, function(p) p$Package, character(1)),
      version = vapply(packages, function(p) p$Version, character(1))
    )
  )
}

# Two package versions, compared as versions rather than as text.
#
# The readiness audit reported the environment as differing from renv.lock for
# the transitive package Rcpp, and it does not. The lockfile records CRAN's own
# spelling of a revision, `1.1.1-1.1`; `packageVersion()` parses that and prints
# it back as `1.1.1.1.1`, because R has always treated `-` and `.` as the same
# separator in a package version. Comparing the two strings therefore reports a
# difference between a version and itself -- for every package whose maintainer
# has ever issued a revision, on every build, forever.
#
# ER-12 asks whether the drift is intentional and whether it affects a compiled
# dependency. It is neither: there is no drift. The reported difference was an
# artefact of the comparison, and the repair is to compare versions.
same_package_version <- function(installed, expected) {
  if (is.na(installed) || is.na(expected)) return(FALSE)
  parsed <- tryCatch(
    list(numeric_version(installed), numeric_version(expected)), error = function(e) NULL
  )
  if (is.null(parsed)) return(identical(installed, expected))
  identical(parsed[[1]], parsed[[2]])
}

check_environment <- function(root = getwd(), strict = FALSE) {
  lock <- read_environment_lock(root)
  if (is.null(lock)) {
    message(
      "No renv.lock found (or jsonlite unavailable): the running package versions are not ",
      "being checked against a recorded environment."
    )
    return(invisible(FALSE))
  }
  drift <- character()
  running_r <- paste(R.version$major, R.version$minor, sep = ".")
  if (!is.na(lock$r_version) && !identical(running_r, lock$r_version)) drift <- c(drift, paste0(
    "R ", running_r, " is running; renv.lock records ", lock$r_version
  ))
  # The whole lockfile is compared; only the declared packages can stop a build.
  #
  # The re-audit's RA2-09. Checking 19 of 61 was defended on the grounds that a
  # difference three levels down is not actionable from a failure message, which
  # is a good argument for not *failing* on it and no argument at all for not
  # *looking*. A transitive package that has moved is exactly the sort of thing
  # that explains a result nobody can reproduce, and it was invisible.
  declared <- read_required_packages(root)
  transitive_drift <- character()
  for (package in lock$packages$package) {
    expected <- lock$packages$version[lock$packages$package == package][[1]]
    installed <- tryCatch(
      as.character(utils::packageVersion(package)), error = function(e) NA_character_
    )
    note <- if (is.na(installed)) {
      paste0(package, " is not installed; renv.lock records ", expected)
    } else if (!same_package_version(installed, expected)) {
      paste0(package, " ", installed, " is installed; renv.lock records ", expected)
    } else NULL
    if (is.null(note)) next
    if (package %in% declared) drift <- c(drift, note) else {
      transitive_drift <- c(transitive_drift, note)
    }
  }
  if (length(transitive_drift)) message(
    "The running environment differs from renv.lock in ", length(transitive_drift),
    " transitive package(s). These do not stop a build -- nothing here loads them directly -- ",
    "but they are recorded in audit.build_environment and are worth knowing when a result ",
    "will not reproduce:\n  - ", paste(transitive_drift, collapse = "\n  - ")
  )
  if (!length(drift)) {
    message(
      "Environment matches renv.lock: R ", running_r, ", ", length(declared),
      " direct package(s) of ", nrow(lock$packages), " pinned",
      if (length(transitive_drift)) paste0(
        " (", length(transitive_drift), " transitive difference(s) reported above)"
      ) else "", "."
    )
    return(invisible(TRUE))
  }
  detail <- paste0(
    "The running environment differs from renv.lock in ", length(drift),
    " directly loaded package(s):\n  - ", paste(drift, collapse = "\n  - "),
    "\nRun renv::restore() to match it, or renv::snapshot() if the change is intended."
  )
  if (strict) stop(detail, call. = FALSE)
  warning(detail, call. = FALSE)
  invisible(FALSE)
}

# The packages the project loads, read from the one place that lists them so the
# installer and the environment check cannot disagree.
read_required_packages <- function(root) {
  path <- file.path(root, "scripts", "00_install_packages.R")
  if (!file.exists(path)) return(character())
  expressions <- tryCatch(parse(path), error = function(e) NULL)
  if (is.null(expressions)) return(character())
  # Evaluated in a child of baseenv() so c() resolves, and nothing else the file
  # might contain can reach the calling session.
  scope <- new.env(parent = baseenv())
  for (expression in expressions) {
    if (is.call(expression) && identical(as.character(expression[[1]]), "<-") &&
        identical(as.character(expression[[2]]), "required")) {
      return(as.character(eval(expression[[3]], envir = scope)))
    }
  }
  character()
}

# --- Build identity ----------------------------------------------------------
# The audit's F-08. release_id is a hash of the source files, which is what makes
# it deterministic and what makes it useless for saying which *database* you are
# holding: change a parser and the same release_id names different observations.
# So the code, the configuration and the declared environment are hashed too, and
# the result is recorded beside the release rather than replacing it.

digest_files <- function(paths) {
  paths <- sort(paths[file.exists(paths)])
  if (!length(paths)) return(NA_character_)
  parts <- vapply(paths, function(path) paste(
    basename(path), digest::digest(file = path, algo = "sha256"), sep = ":"
  ), character(1))
  substr(digest::digest(paste(parts, collapse = "|"), algo = "sha256", serialize = FALSE), 1, 24)
}

git_build_state <- function(root) {
  if (!nzchar(Sys.which("git")) || !dir.exists(file.path(root, ".git"))) {
    return(list(commit = NA_character_, dirty = NA))
  }
  # NULL when git itself failed, which is not the same answer as "nothing to
  # report" and must not be read as one -- see the dirtiness note below.
  run <- function(args) {
    out <- suppressWarnings(tryCatch(
      system2("git", c("-C", shQuote(root), args), stdout = TRUE, stderr = FALSE),
      error = function(e) NULL
    ))
    if (is.null(out) || !identical(attr(out, "status", exact = TRUE), NULL)) NULL else out
  }
  commit <- run(c("rev-parse", "HEAD"))
  # Tracked changes only, so an untracked report sitting in outputs/ does not make
  # every build claim to be dirty.
  #
  # The database file is tracked and is excluded here, which is the whole reason
  # `git_dirty` had never once been FALSE. This function is called from inside the
  # pipeline, by which time the run has already written to the .duckdb -- so the
  # tracked file the build is *producing* was being counted as an uncommitted
  # change against the build producing it. That is not a fact about the code; it
  # is unsatisfiable by construction, and a flag that can never be clear is a flag
  # nobody reads.
  #
  # What the field is for is the reproducibility question: was the code that built
  # this database committed. That is what is asked, and what config_digest,
  # code_digest and environment_digest pin exactly.
  # Filtered in R, not with a git pathspec: `:(exclude)...` has to survive a
  # shell, and system2 quoting turned the whole command into a syntax error. It
  # returned nothing, and nothing read as a clean tree -- so the first attempt at
  # this repair reported FALSE with uncommitted code sitting in front of it. A
  # dirtiness check that fails open is worse than the one it replaced, which is
  # why a failed git call is now NA and never FALSE.
  changed <- run(c("status", "--porcelain", "--untracked-files=no"))
  list(
    commit = if (length(commit)) commit[[1]] else NA_character_,
    dirty = if (is.null(commit) || is.null(changed)) {
      NA
    } else length(changed[!grepl(GIT_BUILD_OUTPUT_PATHS, changed)]) > 0L
  )
}

# Tracked paths the build itself writes, excluded from the dirtiness test.
#
# The database was already here, and the reason generalises: this runs from
# inside the pipeline, so a tracked file the run *produces* would be counted as
# an uncommitted change against the run producing it. That is not a fact about
# the code and it is unsatisfiable by construction.
#
# docs/SCHEMA_MIGRATIONS.md joined it in schema 39, found the moment the
# dirty-tree gate went live and blocked its own first build. The runbook is
# regenerated from the migration registry on every run -- its own header says not
# to hand-edit it -- so any run, or any test run, leaves it modified, and a gate
# that then refuses the next build would be permanently unsatisfiable. The
# question `git_dirty` answers is whether the *code* that built this database was
# committed, and a file the build writes is not code.
#
# Nothing else qualifies: outputs/ is gitignored and input_archive's manifest is
# untracked, so this list is the whole of it.
GIT_BUILD_OUTPUT_PATHS <- "^.{2,3}(database/|docs/SCHEMA_MIGRATIONS\\.md)"

# What was actually loaded, as opposed to what renv.lock says should have been.
#
# The audit's F-09. environment_digest below hashes the *file* renv.lock, so two
# builds run against libraries that differ from each other and from the lockfile
# produce a byte-identical build_id. The lockfile is a declaration; this is the
# observation, and the reproducibility question needs both.
#
# The whole lockfile, not the nineteen names the installer lists.
#
# The re-audit's RA2-09. Schema 35 narrowed this to the declared packages on the
# argument that a difference three levels down is not actionable from a failure
# message. That argument is right about *failing* and wrong about *recording*:
# 42 of the 61 pinned packages went unrecorded, so a build could not say what it
# ran against, and the narrowing hid something specific. DBI, duckdb, xml2, readr
# and testthat are built under R 4.5.2 while R 4.5.1 runs -- including the two
# packages that write the database -- and nothing could see it, because the
# comparison was of version strings and the Built field was never read.
#
# So: every lockfile package that is installed, with the R version it was built
# under. The `is_direct` flag keeps the distinction the gate still needs.
installed_package_versions <- function(root) {
  declared <- read_required_packages(root)
  lock <- read_environment_lock(root)
  locked <- if (is.null(lock)) character() else lock$packages$package
  # Radix, not the default: `sort()` is locale-aware, so "DBI" sorts before
  # "bit" under C and after it under en_US. The order feeds a digest that feeds
  # build_id, which would have made the build identity depend on the operator's
  # locale -- a reproducibility defect introduced by the fix for a
  # reproducibility defect. Radix is byte order everywhere, and it is also what
  # DuckDB's ORDER BY gives, so the stored rows and the digest agree.
  packages <- sort(union(declared, locked), method = "radix")
  if (!length(packages)) return(tibble(
    package = character(), version = character(), built_under = character(),
    is_direct = logical(), library_path = character()
  ))
  described <- lapply(packages, function(package) {
    description <- tryCatch(
      utils::packageDescription(package), error = function(e) NULL
    )
    if (!length(description) || !is.list(description)) return(list(
      version = NA_character_, built = NA_character_, library = NA_character_
    ))
    built <- if (is.null(description$Built)) NA_character_ else description$Built
    list(
      version = if (is.null(description$Version)) NA_character_ else description$Version,
      # "R 4.5.2; aarch64-apple-darwin20; 2025-11-01 12:00:00 UTC; unix" -- the
      # first field is the R version the binary was built under.
      built = if (is.na(built)) NA_character_ else trimws(strsplit(built, ";", fixed = TRUE)[[1]][[1]]),
      library = tryCatch(dirname(find.package(package)), error = function(e) NA_character_)
    )
  })
  tibble(
    package = packages,
    version = vapply(described, function(d) d$version, character(1)),
    built_under = vapply(described, function(d) d$built, character(1)),
    is_direct = packages %in% declared,
    library_path = vapply(described, function(d) as.character(d$library)[[1]], character(1))
  )
}

# The machine, which nothing recorded at all: an arm64 macOS build and an x86
# Linux build produced identical `r_version` strings and identical build ids.
build_platform_record <- function() {
  running <- tryCatch(utils::sessionInfo()$running, error = function(e) NULL)
  list(
    platform = R.version$platform,
    os_release = if (is.null(running)) NA_character_ else as.character(running)
  )
}

# The namespaces this session actually loaded, as evidence rather than identity.
#
# Deliberately *not* part of build_id. Loaded namespaces differ between
# run_update.R and run_tests.R -- testthat and withr are loaded by one and not
# the other -- so hashing them would make the same sources on the same machine
# produce two different build identities depending on which entry point ran,
# and "re-running the pipeline against unchanged inputs reproduces the exact
# same release" is the property the whole release model rests on. The digest is
# recorded beside the identity so the difference is visible without being
# load-bearing. A deliberate departure from the re-audit's wording.
loaded_namespaces_digest <- function() {
  loaded <- sort(loadedNamespaces())
  if (!length(loaded)) return(NA_character_)
  versions <- vapply(loaded, function(package) tryCatch(
    as.character(utils::packageVersion(package)), error = function(e) NA_character_
  ), character(1), USE.NAMES = FALSE)
  substr(digest::digest(
    paste(paste0(loaded, ":", versions), collapse = "|"), algo = "sha256", serialize = FALSE
  ), 1, 24)
}

build_identity_record <- function(root, release_id, schema_version = NA_integer_) {
  git <- git_build_state(root)
  config_digest <- digest_files(c(
    list.files(file.path(root, "config"), pattern = "\\.csv$", full.names = TRUE),
    list.files(file.path(root, "config", "specs"), pattern = "\\.ya?ml$", full.names = TRUE)
  ))
  code_digest <- digest_files(c(
    list.files(file.path(root, "scripts"), pattern = "\\.R$", full.names = TRUE),
    file.path(root, "run_update.R")
  ))
  environment_digest <- digest_files(file.path(root, "renv.lock"))
  # The audit's F-09. environment_digest is a hash of a *declaration*; this is a
  # hash of what was loaded. Two builds against libraries that differ from each
  # other and from the lockfile used to produce the same build_id, which makes
  # the identity unable to answer the one question it exists for.
  #
  # It is part of the hash rather than a column beside it, deliberately: a
  # different library is a different build, and recording that fact somewhere the
  # identity does not read would leave two builds sharing an id again.
  #
  # Since schema 38 it covers the whole lockfile and each package's Built field,
  # so a library rebuilt under a different R patch release is a different build
  # -- which is exactly the difference that was invisible when only version
  # strings were compared. It stays deterministic for a given machine and
  # library, which is why it can be in the hash at all; see
  # loaded_namespaces_digest() for the thing that cannot.
  packages <- installed_package_versions(root)
  package_versions_digest <- if (!nrow(packages)) NA_character_ else substr(digest::digest(
    paste(paste0(packages$package, ":", packages$version, ":", packages$built_under),
          collapse = "|"),
    algo = "sha256", serialize = FALSE
  ), 1, 24)
  machine <- build_platform_record()
  # The audit's R6-18. build_id names the code, configuration and inputs behind a
  # database; nothing named the database file itself. So the commit that carries a
  # rebuilt .duckdb -- necessarily made *after* the build that produced it -- read
  # as a provenance mismatch, with the recorded build pointing at an earlier
  # commit than HEAD. It is not a mismatch, and now it does not look like one:
  # the artifact has an identity of its own, recorded beside the build.
  build_id <- paste0("build:", substr(digest::digest(paste(
    release_id, git$commit, isTRUE(git$dirty), schema_version,
    config_digest, code_digest, environment_digest, package_versions_digest,
    R.version.string, machine$platform, sep = "|"
  ), algo = "sha256", serialize = FALSE), 1, 24))
  record <- tibble(
    build_id = build_id, release_id = release_id, git_commit = git$commit,
    git_dirty = git$dirty, schema_version = as.integer(schema_version),
    config_digest = config_digest, code_digest = code_digest,
    environment_digest = environment_digest,
    package_versions_digest = package_versions_digest, r_version = R.version.string,
    platform = machine$platform, os_release = machine$os_release,
    loaded_namespaces_digest = loaded_namespaces_digest(),
    built_at = Sys.time()
  )
  # The versions themselves travel with the record. A digest can say two builds
  # ran against different libraries; only the list can say which package moved.
  attr(record, "package_versions") <- packages
  record
}

# The observed environment, one row per package, recorded beside the build it
# produced. Written from the attribute build_identity_record() carries so the
# digest and the list cannot describe different libraries.
record_build_environment <- function(con, build) {
  if (!database_object_exists(con, "build_environment")) return(invisible(FALSE))
  packages <- attr(build, "package_versions")
  if (is.null(packages) || !nrow(packages)) return(invisible(FALSE))
  DBI::dbExecute(con, paste0(
    "DELETE FROM ", project_qualified_name("build_environment"),
    " WHERE build_id = ", sql_string(build$build_id[[1]])
  ))
  DBI::dbWriteTable(con, "build_environment", tibble(
    build_id = build$build_id[[1]], package = packages$package, version = packages$version,
    recorded_at = Sys.time(), built_under = packages$built_under,
    is_direct = packages$is_direct, library_path = packages$library_path
  ), append = TRUE)
  invisible(nrow(packages))
}

a1_column_number <- function(x) {
  chars <- strsplit(toupper(x), "", fixed = TRUE)[[1]]
  sum(match(chars, LETTERS) * 26 ^ rev(seq_along(chars) - 1L))
}

# Consecutive integers written the way a person reads them: "12-18;44;51-53".
# A sheet with two thousand hidden rows should not need two thousand numbers to
# say so.
pack_integer_ranges <- function(x) {
  x <- sort(unique(x[!is.na(x)]))
  if (!length(x)) return(NA_character_)
  breaks <- c(0L, which(diff(x) != 1L), length(x))
  parts <- vapply(seq_len(length(breaks) - 1L), function(i) {
    run <- x[(breaks[[i]] + 1L):breaks[[i + 1L]]]
    if (length(run) == 1L) as.character(run) else paste0(min(run), "-", max(run))
  }, character(1))
  paste(parts, collapse = ";")
}

parse_a1_ref <- function(ref) {
  ref <- tail(strsplit(ref, ":", fixed = TRUE)[[1]], 1)
  c(row = as.integer(str_extract(ref, "[0-9]+")), col = a1_column_number(str_extract(ref, "[A-Z]+")))
}

xlsx_sheet_dimensions <- function(path) {
  scratch <- tempfile("xlsx_xml_")
  dir.create(scratch)
  on.exit(unlink(scratch, recursive = TRUE, force = TRUE), add = TRUE)
  utils::unzip(path, exdir = scratch)
  wb <- xml2::read_xml(file.path(scratch, "xl", "workbook.xml"))
  rel <- xml2::read_xml(file.path(scratch, "xl", "_rels", "workbook.xml.rels"))
  sheet_nodes <- xml2::xml_find_all(wb, ".//*[local-name()='sheet']")
  rel_nodes <- xml2::xml_find_all(rel, ".//*[local-name()='Relationship']")
  rel_target <- stats::setNames(xml2::xml_attr(rel_nodes, "Target"), xml2::xml_attr(rel_nodes, "Id"))
  rel_type <- stats::setNames(xml2::xml_attr(rel_nodes, "Type"), xml2::xml_attr(rel_nodes, "Id"))
  out <- vector("list", length(sheet_nodes))
  # Carried as an attribute rather than a column: every caller of this function
  # consumes one row per worksheet, and a list-column would have to be handled by
  # all of them to be recorded by one.
  formulas <- list()
  for (i in seq_along(sheet_nodes)) {
    node <- sheet_nodes[[i]]
    sid <- xml2::xml_attr(node, "id")
    if (is.na(sid)) {
      attrs <- xml2::xml_attrs(node)
      id_attr <- which(names(attrs) == "r:id" | endsWith(names(attrs), ":id"))
      if (length(id_attr)) sid <- unname(attrs[[id_attr[[1]]]])
    }
    if (is.na(sid) || !sid %in% names(rel_target)) {
      stop("Could not resolve the worksheet relationship id for sheet '",
           xml2::xml_attr(node, "name"), "'.", call. = FALSE)
    }
    if (!stringr::str_ends(rel_type[[sid]], "/worksheet")) next
    target <- rel_target[[sid]]
    xml_path <- file.path(scratch, "xl", target)
    doc <- xml2::read_xml(xml_path)
    ref <- xml2::xml_attr(xml2::xml_find_first(doc, ".//*[local-name()='dimension']"), "ref")
    endpoint <- if (is.na(ref)) c(row = 1L, col = 1L) else parse_a1_ref(ref)
    active_cells <- xml2::xml_find_all(
      doc, ".//*[local-name()='c'][*[local-name()='v'] or *[local-name()='is'] or *[local-name()='f']]"
    )
    active_refs <- xml2::xml_attr(active_cells, "r")
    active_rows <- suppressWarnings(as.integer(stringr::str_extract(active_refs, "[0-9]+")))
    active_columns <- stringr::str_extract(active_refs, "[A-Z]+")
    active_columns <- vapply(active_columns, a1_column_number, numeric(1))
    keep <- !is.na(active_rows) & !is.na(active_columns)
    content_bounds <- if (!any(keep)) {
      # An actually empty worksheet has an empty half-open range. Using A1 as
      # a synthetic active cell disagrees with readxl, which correctly returns
      # a 0 x 0 tibble for formula views with no cached values.
      c(first_row = 1L, first_col = 1L, last_row = 0L, last_col = 0L)
    } else c(
      first_row = min(active_rows[keep]), first_col = min(active_columns[keep]),
      last_row = max(active_rows[keep]), last_col = max(active_columns[keep])
    )
    # A merged range is the only place a workbook records that one label heads
    # several columns. readxl drops it, and without it a group header cannot be
    # told from a sub-header the publisher left blank: SIPAP_12 column 18 and
    # CUADRO 35 column 12 are identical in the cell matrix, and only the merge
    # Q2:R2 -- which exists on the first and not on the second -- separates them.
    merge_refs <- xml2::xml_attr(
      xml2::xml_find_all(doc, ".//*[local-name()='mergeCells']/*[local-name()='mergeCell']"), "ref"
    )
    merge_refs <- merge_refs[!is.na(merge_refs)]
    # Workbook behaviour the cell matrix cannot show.
    #
    # Every value this project reads is a *cached* formula result: readxl cannot
    # calculate, so if the publisher shipped a workbook without recalculating,
    # the number stored is whatever was last computed and nothing downstream can
    # tell. Hidden rows and columns are the same kind of blind spot in the other
    # direction -- a parser cannot say whether a value it read, or skipped, was
    # visible to the publisher's own reader.
    #
    # The count stays on the sheet row, because that is what the drift test
    # between vintages compares. The seventh audit's F-07 asks for the other
    # grain as well, and it is right: "91,673 formula cells" is a fact about the
    # database, and "is *this* number a cached formula result" was a question a
    # researcher holding one could not ask.
    #
    # The reasoning recorded here at schema 29 -- that per-cell formula data would
    # change the content hash of every worksheet version and force the raw layer
    # to be re-read -- was about storing formula text *in report_cell_values*,
    # which is content-hashed. It does not apply to a side table keyed by
    # coordinate, and 91,673 rows is nothing. So the coordinates are kept, and the
    # cell values are not touched.
    formula_nodes <- xml2::xml_find_all(doc, ".//*[local-name()='c']/*[local-name()='f']")
    formula_cells <- length(formula_nodes)
    if (formula_cells) {
      # The A1 ref is on the parent <c>, which is the same node set the active
      # bounds above are read from -- no second pass over the file.
      formula_refs <- xml2::xml_attr(xml2::xml_parent(formula_nodes), "r")
      formula_rows <- suppressWarnings(as.integer(stringr::str_extract(formula_refs, "[0-9]+")))
      formula_columns <- stringr::str_extract(formula_refs, "[A-Z]+")
      usable <- !is.na(formula_rows) & !is.na(formula_columns)
      if (any(usable)) formulas[[length(formulas) + 1L]] <- tibble(
        sheet_name = xml2::xml_attr(node, "name"),
        row_id = formula_rows[usable],
        column_id = vapply(formula_columns[usable], a1_column_number, numeric(1), USE.NAMES = FALSE)
      )
    }
    hidden_rows <- suppressWarnings(as.integer(xml2::xml_attr(xml2::xml_find_all(
      doc, ".//*[local-name()='row'][@hidden='1' or @hidden='true']"
    ), "r")))
    hidden_columns <- xml2::xml_find_all(
      doc, ".//*[local-name()='cols']/*[local-name()='col'][@hidden='1' or @hidden='true']"
    )
    hidden_column_numbers <- unlist(lapply(hidden_columns, function(col) {
      from <- suppressWarnings(as.integer(xml2::xml_attr(col, "min")))
      to <- suppressWarnings(as.integer(xml2::xml_attr(col, "max")))
      if (is.na(from) || is.na(to) || to < from) integer() else seq.int(from, to)
    }))
    out[[i]] <- tibble(
      sheet_name = xml2::xml_attr(node, "name"), used_rows = endpoint[["row"]], used_cols = endpoint[["col"]],
      content_first_row = content_bounds[["first_row"]], content_first_col = content_bounds[["first_col"]],
      content_last_row = content_bounds[["last_row"]], content_last_col = content_bounds[["last_col"]],
      merge_ranges = if (length(merge_refs)) paste(merge_refs, collapse = ";") else NA_character_,
      formula_cells = as.integer(formula_cells),
      hidden_rows = pack_integer_ranges(hidden_rows),
      hidden_columns = pack_integer_ranges(hidden_column_numbers)
    )
  }
  dimensions <- bind_rows(out)
  attr(dimensions, "formula_cells") <- if (length(formulas)) bind_rows(formulas) else tibble(
    sheet_name = character(), row_id = integer(), column_id = numeric()
  )
  dimensions
}

# The formula coordinates a dimensions frame is carrying, or an empty frame. One
# accessor so a caller never has to know it is an attribute.
xlsx_formula_cell_coordinates <- function(dimensions) {
  coordinates <- attr(dimensions, "formula_cells")
  if (is.null(coordinates)) tibble(
    sheet_name = character(), row_id = integer(), column_id = numeric()
  ) else coordinates
}

csv_source_dimensions <- function(path) {
  header <- readr::read_lines(path, n_max = 1L, locale = readr::locale(encoding = "UTF-8"))
  delimiter <- if (length(header) && stringr::str_count(header, fixed(";")) >= stringr::str_count(header, fixed(","))) ";" else ","
  columns <- length(strsplit(sub("^\\ufeff", "", header), delimiter, fixed = TRUE)[[1]])
  rows <- length(readr::read_lines(path, locale = readr::locale(encoding = "UTF-8")))
  tibble::tibble(
    sheet_name = "data", used_rows = as.integer(rows), used_cols = as.integer(columns),
    content_first_row = 1L, content_first_col = 1L,
    content_last_row = as.integer(rows), content_last_col = as.integer(columns),
    merge_ranges = NA_character_, formula_cells = 0L,
    hidden_rows = NA_character_, hidden_columns = NA_character_
  )
}

# The merged rectangles of one worksheet, in the same A1 coordinates the parsers
# use. Returns a zero-row frame when the sheet declares none, so callers never
# have to test for NA before iterating.
parse_merge_ranges <- function(packed) {
  empty <- tibble::tibble(
    row_from = integer(), row_to = integer(), col_from = integer(), col_to = integer()
  )
  if (is.null(packed) || !length(packed) || is.na(packed[[1]]) || !nzchar(packed[[1]])) return(empty)
  refs <- strsplit(packed[[1]], ";", fixed = TRUE)[[1]]
  refs <- refs[nzchar(refs)]
  if (!length(refs)) return(empty)
  corners <- lapply(refs, function(ref) {
    ends <- strsplit(ref, ":", fixed = TRUE)[[1]]
    if (length(ends) == 1L) ends <- c(ends, ends)
    first <- parse_a1_ref(ends[[1]]); last <- parse_a1_ref(ends[[2]])
    c(row_from = min(first[["row"]], last[["row"]]), row_to = max(first[["row"]], last[["row"]]),
      col_from = min(first[["col"]], last[["col"]]), col_to = max(first[["col"]], last[["col"]]))
  })
  parsed <- tibble::as_tibble(do.call(rbind, corners))
  parsed[stats::complete.cases(parsed), , drop = FALSE]
}

# The merged ranges of one sheet, taken from the dimensions row the caller
# already holds. A dimensions frame built before schema 24 has no such column;
# an absent column means "no merges known", never an error.
sheet_merge_ranges <- function(dimensions, sheet_name = NULL) {
  if (is.null(dimensions) || !nrow(dimensions) || !"merge_ranges" %in% names(dimensions)) {
    return(parse_merge_ranges(NA_character_))
  }
  row <- if (is.null(sheet_name)) dimensions else dimensions[dimensions$sheet_name == sheet_name, , drop = FALSE]
  if (!nrow(row)) return(parse_merge_ranges(NA_character_))
  parse_merge_ranges(row$merge_ranges[[1]])
}

read_sheet_matrix <- function(path, sheet, used_rows, used_cols,
                              content_first_row = 1L, content_first_col = 1L,
                              content_last_row = used_rows, content_last_col = used_cols) {
  bounds <- as.integer(c(content_first_row, content_first_col, content_last_row, content_last_col))
  if (any(is.na(bounds)) || bounds[[1]] < 1L || bounds[[2]] < 1L ||
      bounds[[3]] < bounds[[1]] || bounds[[4]] < bounds[[2]] ||
      bounds[[3]] - bounds[[1]] + 1L > 100000L || bounds[[4]] - bounds[[2]] + 1L > 5000L) stop(
    "Worksheet range guard: meaningful content bounds are invalid or implausibly large for ",
    basename(path), " / ", sheet, ".", call. = FALSE
  )
  x <- readxl::read_excel(
    path, sheet = sheet, col_names = FALSE, .name_repair = "minimal",
    range = readxl::cell_limits(bounds[1:2], bounds[3:4]), col_types = "list"
  )
  names(x) <- sprintf("col_%04d", seq_len(ncol(x)))
  x
}

read_dimensioned_sheet <- function(path, dimension_row, max_rows = NULL, max_cols = NULL) {
  if (nrow(dimension_row) != 1L) stop("Worksheet dimension guard: expected exactly one row.", call. = FALSE)
  first_active_row <- dimension_row$content_first_row[[1]]
  first_active_col <- dimension_row$content_first_col[[1]]
  # Read from A1 so source_row/source_column remain true Excel coordinates and
  # fixed official reference blocks retain their published column positions.
  first_row <- 1L
  first_col <- 1L
  last_row <- dimension_row$content_last_row[[1]]
  last_col <- dimension_row$content_last_col[[1]]
  if (is.na(last_row) || is.na(last_col) || last_row < 1L || last_col < 1L) {
    return(tibble::new_tibble(list(), nrow = 0L))
  }
  if (!is.null(max_rows)) last_row <- min(last_row, first_active_row + as.integer(max_rows) - 1L)
  if (!is.null(max_cols)) last_col <- min(last_col, first_active_col + as.integer(max_cols) - 1L)
  read_sheet_matrix(
    path, dimension_row$sheet_name[[1]], dimension_row$used_rows[[1]], dimension_row$used_cols[[1]],
    first_row, first_col, last_row, last_col
  )
}

cell_list <- function(x) {
  if (is.list(x)) return(x)
  lapply(seq_along(x), function(i) x[[i]])
}

cell_character <- function(x) {
  cells <- cell_list(x)
  vapply(cells, function(value) {
    if (is.null(value) || length(value) == 0L || all(is.na(value))) return(NA_character_)
    if (inherits(value, c("Date", "POSIXt"))) return(format(as.Date(value), "%Y-%m-%d"))
    as.character(value[[1]])
  }, character(1))
}

extract_row_cells <- function(data, row, columns = seq_len(ncol(data))) {
  lapply(columns, function(column) data[[column]][[row]])
}

as_number_or_na <- function(x) {
  cells <- cell_list(x)
  vapply(cells, function(value) {
    if (is.null(value) || length(value) == 0L || all(is.na(value))) return(NA_real_)
    suppressWarnings(as.numeric(value[[1]]))
  }, numeric(1))
}

as_excel_date <- function(x) {
  cells <- cell_list(x)
  out <- as.Date(rep(NA_real_, length(cells)), origin = "1970-01-01")
  for (i in seq_along(cells)) {
    value <- cells[[i]]
    if (is.null(value) || length(value) == 0L || all(is.na(value))) next
    value <- value[[1]]
    if (inherits(value, c("Date", "POSIXt"))) {
      out[[i]] <- as.Date(value)
      next
    }
    numeric_value <- suppressWarnings(as.numeric(value))
    if (!is.na(numeric_value) && numeric_value > 20000 && numeric_value < 80000) {
      out[[i]] <- as.Date(numeric_value, origin = "1899-12-30")
      next
    }
    parsed <- tryCatch(suppressWarnings(as.Date(as.character(value), tryFormats = c(
      "%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y", "%Y/%m/%d"
    ))), error = function(e) as.Date(NA))
    if (!is.na(parsed)) out[[i]] <- parsed
  }
  out
}

as_typed_date <- function(x) {
  cells <- cell_list(x)
  out <- as.Date(rep(NA_real_, length(cells)), origin = "1970-01-01")
  for (i in seq_along(cells)) {
    value <- cells[[i]]
    if (!is.null(value) && length(value) && !all(is.na(value)) &&
        inherits(value[[1]], c("Date", "POSIXt"))) out[[i]] <- as.Date(value[[1]])
  }
  out
}

assert_plausible_dates <- function(x, source_id, sheet, minimum = as.Date("1980-01-01"),
                                   maximum = Sys.Date() + 400L) {
  dates <- as.Date(x)
  dates <- dates[!is.na(dates)]
  if (!length(dates)) stop("Date guard: no valid dates parsed for ", source_id, "/", sheet, ".", call. = FALSE)
  if (min(dates) < minimum || max(dates) > maximum) stop(
    "Date guard failed for ", source_id, "/", sheet, ": observed range ",
    min(dates), " to ", max(dates), "; permitted range ", minimum, " to ", maximum, ".",
    call. = FALSE
  )
  invisible(TRUE)
}

read_parser_spec <- function(root, source_id) {
  path <- file.path(root, "config", "specs", paste0(source_id, ".yml"))
  if (!file.exists(path)) stop("Parser specification not found: ", path, call. = FALSE)
  yaml::yaml.load(paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n"))
}

find_anchor_cell <- function(data, value, max_rows = 20L, max_cols = 10L,
                             min_row = 1L, min_col = 1L, occurrence = NULL) {
  min_row <- max(1L, as.integer(min_row)); min_col <- max(1L, as.integer(min_col))
  max_rows <- min(nrow(data), as.integer(max_rows)); max_cols <- min(ncol(data), as.integer(max_cols))
  if (min_row > max_rows || min_col > max_cols) stop(
    "Structure guard: anchor search region is empty.", call. = FALSE
  )
  matches <- list(); k <- 0L
  search_rows <- seq.int(min_row, max_rows)
  for (j in seq.int(min_col, max_cols)) {
    vals <- normalize_label(cell_character(data[[j]][search_rows]))
    hit <- which(vals == normalize_label(value))
    if (length(hit)) for (r in search_rows[hit]) { k <- k + 1L; matches[[k]] <- c(row = r, col = j) }
  }
  if (!is.null(occurrence)) {
    occurrence <- as.integer(occurrence)
    if (occurrence < 1L || occurrence > length(matches)) stop(sprintf(
      "Structure guard: anchor '%s' occurrence %d requested, but only %d found in rows %d:%d and columns %d:%d.",
      value, occurrence, length(matches), min_row, max_rows, min_col, max_cols
    ), call. = FALSE)
    return(matches[[occurrence]])
  }
  if (length(matches) != 1L) stop(sprintf("Structure guard: expected one anchor '%s', found %d.", value, length(matches)), call. = FALSE)
  matches[[1]]
}

structure_signature <- function(x) {
  digest::digest(paste(normalize_label(x), collapse = "|"), algo = "sha256", serialize = FALSE)
}

assert_same_structure <- function(expected, observed, source_id, sheet, component) {
  expected <- unname(normalize_label(expected))
  observed <- unname(normalize_label(observed))
  if (!identical(expected, observed)) {
    missing <- setdiff(expected, observed)
    added <- setdiff(observed, expected)
    stop(sprintf(
      "Structure guard failed for %s/%s (%s). Missing: [%s]. Added or reordered: [%s].",
      source_id, sheet, component, paste(missing, collapse = "; "), paste(added, collapse = "; ")
    ), call. = FALSE)
  }
  tibble(source_id = source_id, source_sheet = sheet, component = component,
         expected_signature = structure_signature(expected), observed_signature = structure_signature(observed), status = "passed")
}

write_markdown_report <- function(path, lines) writeLines(lines, path, useBytes = TRUE)

# dbWriteTable() creates in the first schema of the search path, which is main.
# The dynamically created tables -- one per financial worksheet, one per
# reference table -- belong in a layer like every other table, so their first
# creation names it explicitly. Later writes append and resolve unqualified.
write_table_in_storage_layer <- function(con, table_name, data) {
  schema <- project_schema_for(table_name)
  if (identical(schema, "main")) {
    return(DBI::dbWriteTable(con, table_name, data, overwrite = TRUE))
  }
  DBI::dbWriteTable(con, DBI::Id(schema = schema, table = table_name), data, overwrite = TRUE)
}

# The database file as a thing that gets copied and shared, recorded beside the
# build that produced it. Written after the build identity, on a path this run
# actually wrote, so the artifact_id is the state of the file at the moment the
# run finished with it -- and a later commit of that same file is a fact about
# git, not a discrepancy in the provenance.
#
# Since schema 33 a build writes to a candidate file and is renamed into place
# only if it is accepted, so the file this run is writing and the file it will
# become are two different paths. The size is measured on the one that exists;
# the name recorded is the one a reader will find it under. Without the split,
# every artifact row named a temporary candidate that no longer exists.
# --- Artifact identity ---------------------------------------------------------
# The re-audit's RA2-10: the artifact id hashed build, filename and *size*, and
# the size was read while the connection was still open with rows still to be
# written. The recorded number was 553,136,128 against a shipped file of
# 344,993,792 -- 37% out -- so the identifier of a database could not be
# recomputed from the database.
#
# A file cannot contain its own hash. Writing the row changes the bytes the row
# describes, and that is not a bug to work around but an arithmetic fact, which
# is why "record it after final close" needs somewhere other than the file to
# record it. So the rule is: **a database records the hashes of artifacts other
# than itself, and its own hash lives in a sidecar beside it.**
#
# The sidecar is written after the connection is closed, the checkpoint has run
# and the rename has happened -- the one moment the bytes are final -- and it is
# in the format `shasum -c` reads, so the claim is checkable with a standard
# tool and no R at all.
ARTIFACT_SIDECAR_SUFFIX <- ".sha256"

record_published_artifact <- function(path, build_id, schema_version = NA_integer_,
                                      sha256 = NULL, supersedes = NA_character_) {
  if (!file.exists(path)) return(invisible(FALSE))
  if (is.null(sha256)) sha256 <- file_sha256(path)
  sidecar <- paste0(path, ARTIFACT_SIDECAR_SUFFIX)
  writeLines(c(
    paste0(sha256, "  ", basename(path)),
    paste0("# build=", if (is.null(build_id)) NA_character_ else build_id),
    paste0("# schema_version=", schema_version),
    paste0("# bytes=", format(file.info(path)$size, scientific = FALSE)),
    paste0("# recorded_at=", format(Sys.time(), "%Y-%m-%dT%H:%M:%S")),
    paste0("# supersedes_sha256=", supersedes),
    "# Written after final close. Verify with: shasum -a 256 -c <this file>"
  ), sidecar)
  invisible(sha256)
}

# The hash a sidecar claims, or NA. Used to complete the record of an artifact a
# later run inherited rather than produced.
published_artifact_sha256 <- function(path) {
  sidecar <- paste0(path, ARTIFACT_SIDECAR_SUFFIX)
  if (!file.exists(sidecar)) return(NA_character_)
  first <- utils::head(readLines(sidecar, warn = FALSE), 1)
  if (!length(first)) return(NA_character_)
  hash <- sub("\\s.*$", "", trimws(first))
  if (grepl("^[0-9a-f]{64}$", hash)) hash else NA_character_
}

record_distribution_artifact <- function(con, db_path, build_id, data_release_id,
                                         schema_version = NA_integer_,
                                         artifact_path = db_path,
                                         sha256 = NA_character_,
                                         artifact_role = "database",
                                         derived_from_artifact_id = NA_character_) {
  if (!database_object_exists(con, "distribution_artifacts")) return(invisible(FALSE))
  if (is.null(db_path) || !nzchar(db_path) || !file.exists(db_path)) return(invisible(FALSE))
  if (is.null(artifact_path) || !nzchar(artifact_path)) artifact_path <- db_path
  info <- file.info(db_path)
  # The identifier is derived from the content hash where one is known, and falls
  # back to the old size-based recipe only where it is not -- which is the row
  # this run writes about itself, still open and still growing. Those rows say so
  # by carrying a null sha256 rather than a number that looks authoritative and
  # is 37% wrong.
  artifact_id <- paste0("artifact:", substr(digest::digest(
    paste(
      build_id, data_release_id, basename(artifact_path),
      if (is.na(sha256)) info$size else sha256, sep = "|"
    ), algo = "sha256", serialize = FALSE
  ), 1, 24))
  DBI::dbExecute(con, paste0(
    "DELETE FROM ", project_qualified_name("distribution_artifacts"),
    " WHERE artifact_id = ", sql_string(artifact_id)
  ))
  DBI::dbWriteTable(con, "distribution_artifacts", tibble(
    artifact_id = artifact_id, build_id = build_id, data_release_id = data_release_id,
    artifact_path = repository_uri(artifact_path, dirname(dirname(artifact_path))),
    size_bytes = as.numeric(info$size), schema_version = as.integer(schema_version),
    recorded_at = Sys.time(), sha256 = as.character(sha256),
    artifact_role = as.character(artifact_role),
    derived_from_artifact_id = as.character(derived_from_artifact_id)
  ), append = TRUE)
  invisible(artifact_id)
}

# The artifact a run inherited: the database it copied, whose bytes were final
# before this run began and whose sidecar therefore states its true hash. Written
# by the *next* build, which is the only party that can know it -- see the note
# above record_published_artifact() on why a file cannot record its own hash.
record_inherited_artifact <- function(con, artifact_path, sha256, schema_version = NA_integer_) {
  if (is.na(sha256) || !nzchar(sha256)) return(invisible(FALSE))
  if (!database_object_exists(con, "distribution_artifacts")) return(invisible(FALSE))
  existing <- DBI::dbGetQuery(con, paste0(
    "SELECT artifact_id FROM ", project_qualified_name("distribution_artifacts"),
    " WHERE sha256 = ", sql_string(sha256)
  ))
  if (nrow(existing)) return(invisible(existing$artifact_id[[1]]))
  artifact_id <- paste0("artifact:", substr(digest::digest(
    paste("inherited", basename(artifact_path), sha256, sep = "|"),
    algo = "sha256", serialize = FALSE
  ), 1, 24))
  DBI::dbWriteTable(con, "distribution_artifacts", tibble(
    artifact_id = artifact_id, build_id = NA_character_, data_release_id = NA_character_,
    artifact_path = repository_uri(artifact_path, dirname(dirname(artifact_path))),
    size_bytes = NA_real_, schema_version = as.integer(schema_version),
    recorded_at = Sys.time(), sha256 = sha256, artifact_role = "superseded_database",
    derived_from_artifact_id = NA_character_
  ), append = TRUE)
  invisible(artifact_id)
}
