# Reclaim the free space a migrating release leaves behind.
#
#   Rscript compact_database.R
#
# DuckDB stores the database as fixed-size blocks in one file. When a release
# rewrites a table, the replacement blocks are written before the old ones are
# released, so the file grows to the high-water mark of that run; the freed
# blocks are then reused by later runs but are never returned to the operating
# system. After several migrating releases most of the file can be free space.
# See docs/DATABASE_STORAGE.md for the full explanation.
#
# Compaction copies every object into a fresh file and swaps it in. It must
# change no data, no identifier and no constraint, and the script proves that
# before replacing anything.
#
# The proof used to be row counts. The audit was right that this is too weak: a
# defect that moved a value between two rows of the same table, or swapped two
# columns, or dropped a column default, passes a row count untouched. What is
# compared now is the content itself -- every table, in both directions, as a
# multiset -- plus the schema each table declares.

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(root, "config", "source_registry.csv"))) {
  stop("Run from the project root: Rscript compact_database.R", call. = FALSE)
}
suppressMessages({library(duckdb); library(DBI)})

production <- file.path(root, "database", "paraguay_macro_pilot.duckdb")
if (!file.exists(production)) stop("Database not found: ", production, call. = FALSE)
if (file.exists(paste0(production, ".wal"))) {
  stop(
    "A write-ahead log is present, so the database has uncommitted state. Run ",
    "source('run_update.R') once to checkpoint it, then compact.", call. = FALSE
  )
}

mib <- function(path) file.info(path)$size / 1048576
before <- mib(production)

stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
backup <- file.path(root, "database", "backups", paste0("paraguay_macro_pilot_pre_compaction_", stamp, ".duckdb"))
staging <- file.path(root, "database", paste0(".compacting_", stamp, ".duckdb"))
# A failure anywhere below must not leave a half-built candidate behind for the
# next run to trip over.
on.exit(if (file.exists(staging)) unlink(staging), add = TRUE)
message("Backing up to ", basename(backup))
if (!file.copy(production, backup)) stop("Could not write the backup; aborting.", call. = FALSE)

# Compact out of the backup, so production is never opened for writing until the
# swap. A failure here leaves the live database exactly as it was.
message("Compacting...")
con <- dbConnect(duckdb(), backup)
invisible(DBI::dbExecute(con, paste0("ATTACH ", DBI::dbQuoteString(con, staging), " AS compacted")))
invisible(DBI::dbExecute(con, paste0(
  "COPY FROM DATABASE ", DBI::dbQuoteIdentifier(con, tools::file_path_sans_ext(basename(backup))),
  " TO compacted"
)))
invisible(DBI::dbExecute(con, "DETACH compacted"))
dbDisconnect(con, shutdown = TRUE)

# --- Verification -----------------------------------------------------------
# Both files are attached read-only to one connection, so the comparison runs
# inside the engine rather than pulling millions of rows into R.
message("Verifying...")
verify <- dbConnect(duckdb(), ":memory:")
on.exit(try(dbDisconnect(verify, shutdown = TRUE), silent = TRUE), add = TRUE)
DBI::dbExecute(verify, paste0("ATTACH ", DBI::dbQuoteString(verify, production), " AS live (READ_ONLY)"))
DBI::dbExecute(verify, paste0("ATTACH ", DBI::dbQuoteString(verify, staging), " AS fresh (READ_ONLY)"))

# DuckDB re-serialises a view's SQL when the database is copied, and the order
# of the identifiers inside a SELECT * EXCLUDE (...) list is not stable across
# that round trip. The list is a set, so sorting it makes the comparison test
# what the view means rather than how the engine happened to print it. Nothing
# else about the SQL is touched: a genuinely different view still fails.
normalize_view_sql <- function(views) {
  views$sql <- vapply(views$sql, function(sql) {
    parts <- regmatches(sql, gregexpr("EXCLUDE\\s*\\([^)]*\\)", sql, ignore.case = TRUE))[[1]]
    for (part in parts) {
      inner <- sub("^EXCLUDE\\s*\\(", "", part, ignore.case = TRUE)
      inner <- sub("\\)$", "", inner)
      sorted <- paste(sort(trimws(strsplit(inner, ",", fixed = TRUE)[[1]])), collapse = ", ")
      sql <- sub(part, paste0("EXCLUDE (", sorted, ")"), sql, fixed = TRUE)
    }
    sql
  }, character(1), USE.NAMES = FALSE)
  views
}

# information_schema is scoped to the current database in DuckDB and cannot be
# addressed on an attached one, so the catalogue is read through the duckdb_*()
# system functions, which take the database as a filter.
catalogue <- function(database) {
  name <- DBI::dbQuoteString(verify, database)
  list(
    tables = DBI::dbGetQuery(verify, paste0(
      "SELECT schema_name, table_name FROM duckdb_tables()",
      " WHERE database_name = ", name, " AND NOT internal ORDER BY schema_name, table_name"
    )),
    # Column order and declared type, not only the name set: a column that
    # changed type still holds the same values today and will not tomorrow.
    columns = DBI::dbGetQuery(verify, paste0(
      "SELECT schema_name, table_name, column_name, column_index, data_type,",
      " is_nullable, column_default FROM duckdb_columns()",
      " WHERE database_name = ", name, " AND NOT internal",
      " ORDER BY schema_name, table_name, column_index"
    )),
    views = normalize_view_sql(DBI::dbGetQuery(verify, paste0(
      "SELECT schema_name, view_name, sql FROM duckdb_views()",
      " WHERE database_name = ", DBI::dbQuoteString(verify, database),
      " AND NOT internal ORDER BY schema_name, view_name"
    ))),
    constraints = DBI::dbGetQuery(verify, paste0(
      "SELECT schema_name, table_name, constraint_type, constraint_text FROM duckdb_constraints()",
      " WHERE database_name = ", DBI::dbQuoteString(verify, database),
      " ORDER BY schema_name, table_name, constraint_type, constraint_text"
    )),
    indexes = DBI::dbGetQuery(verify, paste0(
      "SELECT schema_name, index_name, table_name, is_unique, sql FROM duckdb_indexes()",
      " WHERE database_name = ", DBI::dbQuoteString(verify, database),
      " ORDER BY schema_name, index_name"
    )),
    sequences = DBI::dbGetQuery(verify, paste0(
      "SELECT schema_name, sequence_name, start_value, increment_by, cycle FROM duckdb_sequences()",
      " WHERE database_name = ", DBI::dbQuoteString(verify, database),
      " ORDER BY schema_name, sequence_name"
    )),
    macros = DBI::dbGetQuery(verify, paste0(
      "SELECT schema_name, function_name, macro_definition FROM duckdb_functions()",
      " WHERE database_name = ", DBI::dbQuoteString(verify, database),
      " ORDER BY schema_name, function_name, macro_definition"
    )),
    schema_version = DBI::dbGetQuery(
      verify, paste0(
        "SELECT max(version) AS n FROM ", database, ".",
        DBI::dbGetQuery(verify, paste0(
          "SELECT schema_name FROM duckdb_tables() WHERE database_name = ", name,
          " AND table_name = 'schema_version' LIMIT 1"
        ))$schema_name[[1]], ".schema_version"
      )
    )$n[[1]]
  )
}

live <- catalogue("live")
fresh <- catalogue("fresh")

problems <- character()
compare <- function(label, a, b) {
  if (!isTRUE(all.equal(a, b, check.attributes = FALSE))) {
    problems <<- c(problems, paste(label, "differ"))
  }
}
compare("table sets", live$tables, fresh$tables)
compare("column definitions", live$columns, fresh$columns)
compare("view definitions", live$views, fresh$views)
compare("constraints", live$constraints, fresh$constraints)
compare("indexes", live$indexes, fresh$indexes)
compare("sequences", live$sequences, fresh$sequences)
compare("macros", live$macros, fresh$macros)
if (!identical(live$schema_version, fresh$schema_version)) {
  problems <- c(problems, "schema_version differs")
}

# Content equivalence, per table, in both directions. EXCEPT ALL is a multiset
# difference: it is insensitive to row order, which a copied database does not
# preserve, and sensitive to everything else -- a changed value, a duplicated
# row, a dropped row, a value under the wrong column. Running it both ways is
# what makes it an equality rather than a containment.
if (!length(problems)) {
  total_rows <- 0
  for (i in seq_len(nrow(live$tables))) {
    schema <- DBI::dbQuoteIdentifier(verify, live$tables$schema_name[[i]])
    table <- DBI::dbQuoteIdentifier(verify, live$tables$table_name[[i]])
    qualified <- function(database) paste0(database, ".", schema, ".", table)
    difference <- DBI::dbGetQuery(verify, paste0(
      "SELECT (SELECT count(*) FROM (SELECT * FROM ", qualified("live"),
      " EXCEPT ALL SELECT * FROM ", qualified("fresh"), ")) AS only_live,",
      " (SELECT count(*) FROM (SELECT * FROM ", qualified("fresh"),
      " EXCEPT ALL SELECT * FROM ", qualified("live"), ")) AS only_fresh,",
      " (SELECT count(*) FROM ", qualified("live"), ") AS rows_live"
    ))
    total_rows <- total_rows + difference$rows_live[[1]]
    if (difference$only_live[[1]] || difference$only_fresh[[1]]) problems <- c(problems, paste0(
      "contents differ in ", live$tables$table_name[[i]], ": ",
      difference$only_live[[1]], " row(s) only in the live database, ",
      difference$only_fresh[[1]], " only in the candidate"
    ))
  }
}
dbDisconnect(verify, shutdown = TRUE)

# --- The candidate has to work, not merely match ------------------------------
# Everything above compares what the two files *contain*. The audit's P2 test
# asks for one more thing before the swap -- that the objects in the candidate
# actually execute -- and it asks because comparing stored view SQL cannot notice
# that the SQL never worked. Schema 21 shipped 74 views whose text was compared,
# copied and compacted faithfully, and every one of them raised a catalog error
# on a fresh connection.
#
# So the candidate is opened the way a researcher opens it: its own connection,
# default settings, nothing configured.
message("Executing every view and macro in the candidate...")
runtime <- dbConnect(duckdb(), staging, read_only = TRUE)
configured <- DBI::dbGetQuery(runtime, "SELECT current_setting('search_path') AS s")$s[[1]]
if (nzchar(trimws(configured))) {
  DBI::dbDisconnect(runtime, shutdown = TRUE)
  unlink(staging)
  stop("Compaction verification could not run unconfigured; nothing was replaced.", call. = FALSE)
}
candidate_views <- DBI::dbGetQuery(runtime, paste(
  "SELECT schema_name, view_name FROM duckdb_views() WHERE NOT internal",
  "ORDER BY schema_name, view_name"
))
for (i in seq_len(nrow(candidate_views))) {
  object <- sprintf('"%s"."%s"', candidate_views$schema_name[[i]], candidate_views$view_name[[i]])
  outcome <- try(DBI::dbGetQuery(runtime, paste("SELECT count(*) FROM", object)), silent = TRUE)
  if (inherits(outcome, "try-error")) problems <- c(problems, paste0(
    "view does not execute from a default connection: ",
    candidate_views$schema_name[[i]], ".", candidate_views$view_name[[i]], " -- ",
    trimws(gsub("\\s+", " ", conditionMessage(attr(outcome, "condition"))))
  ))
}
for (call in c(
  "SELECT resolve_series_id('smoke:not-a-series')",
  "SELECT * FROM resolve_series_ids('smoke:not-a-series')",
  "SELECT count(*) FROM series_as_of_date(DATE '1900-01-01')"
)) {
  outcome <- try(DBI::dbGetQuery(runtime, call), silent = TRUE)
  if (inherits(outcome, "try-error")) problems <- c(problems, paste0(
    "macro does not execute from a default connection: ", call, " -- ",
    trimws(gsub("\\s+", " ", conditionMessage(attr(outcome, "condition"))))
  ))
}
executed <- nrow(candidate_views) + 3L
DBI::dbDisconnect(runtime, shutdown = TRUE)

if (length(problems)) {
  unlink(staging)
  stop(
    "Compaction verification failed, nothing was replaced:\n  - ",
    paste(problems, collapse = "\n  - "), call. = FALSE
  )
}

# Get the candidate onto the disk before the rename makes it the live database.
# file.rename() within one filesystem is atomic, so the swap itself cannot leave
# a half-written file in place; what it does not guarantee is that the bytes it
# points at have reached the platter. A crash in that window would leave the
# directory entry pointing at an incomplete file with no backup relationship to
# the original, which is the one failure mode this whole procedure exists to
# avoid. Flushing first closes it.
if (nzchar(Sys.which("sync"))) system2("sync")

if (!file.rename(staging, production)) {
  unlink(staging)
  stop("Could not swap the compacted database into place; the original is untouched.", call. = FALSE)
}
if (nzchar(Sys.which("sync"))) system2("sync")

after <- mib(production)
message(sprintf(
  "Compacted %.1f MiB -> %.1f MiB (reclaimed %.1f MiB, %.0f%%)",
  before, after, before - after, 100 * (before - after) / before
))
message(sprintf(
  paste(
    "Verified content-identical: %d tables and %s rows compared in both directions,",
    "%d views, %d constraints, %d indexes, %d macros, schema %d;",
    "%d published objects executed from a default connection."
  ),
  nrow(fresh$tables), format(total_rows, big.mark = ","), nrow(fresh$views),
  nrow(fresh$constraints), nrow(fresh$indexes), nrow(fresh$macros), fresh$schema_version,
  executed
))
message("Backup retained at ", backup)
