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

project_root <- function() normalizePath(getwd(), winslash = "/", mustWork = TRUE)

ensure_dirs <- function(root) {
  fs::dir_create(file.path(root, c(
    "database", "database/backups", "outputs", "input_archive", "logs"
  )), recurse = TRUE)
}

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
PROJECT_SCHEMAS <- c("raw", "staging", "canonical", "marts", "audit")

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
  build_identity = "audit", ingestion_run_attempts = "audit", source_value_tokens = "audit",
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
  DBI::dbExecute(con, paste0(
    "SET search_path = '", paste(c("main", PROJECT_SCHEMAS), collapse = ","), "'"
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
  absolute <- normalizePath(path, winslash = "/", mustWork = FALSE)
  base <- paste0(normalizePath(root, winslash = "/", mustWork = FALSE), "/")
  if (!startsWith(absolute, base)) return(NA_character_)
  substr(absolute, nchar(base) + 1L, nchar(absolute))
}

make_vintage_id <- function(source_id, sha256) {
  paste(source_id, substr(sha256, 1, 24), sep = ":")
}

make_release_id <- function(manifest) {
  keys <- paste(manifest$source_id, manifest$sha256, sep = ":")
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

SOURCE_VINTAGE_REGISTRY_COLUMNS <- c(
  "source_id", "sha256", "original_filename", "official_release_date", "official_url",
  "release_identifier", "retrieved_at", "retrieval_method", "license", "evidence"
)

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
  # Only the packages this project actually loads. renv.lock also pins the
  # transitive tree, and a difference three levels down is not something an
  # operator can act on from a test failure message.
  declared <- read_required_packages(root)
  for (package in intersect(declared, lock$packages$package)) {
    expected <- lock$packages$version[lock$packages$package == package][[1]]
    installed <- tryCatch(
      as.character(utils::packageVersion(package)), error = function(e) NA_character_
    )
    if (is.na(installed)) {
      drift <- c(drift, paste0(package, " is not installed; renv.lock records ", expected))
    } else if (!identical(installed, expected)) {
      drift <- c(drift, paste0(package, " ", installed, " is installed; renv.lock records ", expected))
    }
  }
  if (!length(drift)) {
    message("Environment matches renv.lock: R ", running_r, " and ", length(declared), " packages.")
    return(invisible(TRUE))
  }
  detail <- paste0(
    "The running environment differs from renv.lock in ", length(drift), " place(s):\n  - ",
    paste(drift, collapse = "\n  - "),
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
    } else length(changed[!grepl("^.{2,3}database/", changed)]) > 0L
  )
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
  # The audit's R6-18. build_id names the code, configuration and inputs behind a
  # database; nothing named the database file itself. So the commit that carries a
  # rebuilt .duckdb -- necessarily made *after* the build that produced it -- read
  # as a provenance mismatch, with the recorded build pointing at an earlier
  # commit than HEAD. It is not a mismatch, and now it does not look like one:
  # the artifact has an identity of its own, recorded beside the build.
  build_id <- paste0("build:", substr(digest::digest(paste(
    release_id, git$commit, isTRUE(git$dirty), schema_version,
    config_digest, code_digest, environment_digest, R.version.string, sep = "|"
  ), algo = "sha256", serialize = FALSE), 1, 24))
  tibble(
    build_id = build_id, release_id = release_id, git_commit = git$commit,
    git_dirty = git$dirty, schema_version = as.integer(schema_version),
    config_digest = config_digest, code_digest = code_digest,
    environment_digest = environment_digest, r_version = R.version.string,
    built_at = Sys.time()
  )
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
    # Recorded per sheet rather than per cell: attaching formula text to each of
    # 1.25 million cells would change the content hash of every worksheet version
    # and force the whole raw layer to be re-read, which is a large cost for a
    # diagnostic. The count and the hidden ranges answer the question that
    # matters operationally -- how much of this sheet is computed, what is hidden,
    # and did either change between vintages.
    formula_cells <- length(xml2::xml_find_all(doc, ".//*[local-name()='c']/*[local-name()='f']"))
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
  bind_rows(out)
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
record_distribution_artifact <- function(con, db_path, build_id, data_release_id,
                                         schema_version = NA_integer_) {
  if (!database_object_exists(con, "distribution_artifacts")) return(invisible(FALSE))
  if (is.null(db_path) || !nzchar(db_path) || !file.exists(db_path)) return(invisible(FALSE))
  info <- file.info(db_path)
  artifact_id <- paste0("artifact:", substr(digest::digest(
    paste(build_id, data_release_id, basename(db_path), info$size, sep = "|"),
    algo = "sha256", serialize = FALSE
  ), 1, 24))
  DBI::dbExecute(con, paste0(
    "DELETE FROM ", project_qualified_name("distribution_artifacts"),
    " WHERE artifact_id = ", sql_string(artifact_id)
  ))
  DBI::dbWriteTable(con, "distribution_artifacts", tibble(
    artifact_id = artifact_id, build_id = build_id, data_release_id = data_release_id,
    artifact_path = repository_uri(db_path, dirname(dirname(db_path))),
    size_bytes = as.numeric(info$size), schema_version = as.integer(schema_version),
    recorded_at = Sys.time()
  ), append = TRUE)
  invisible(artifact_id)
}
