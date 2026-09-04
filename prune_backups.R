# Retention for database/backups/ and database/candidates/.
#
#   Rscript prune_backups.R              # say what would go; delete nothing
#   Rscript prune_backups.R --apply      # do it
#   Rscript prune_backups.R --keep=5 --apply
#
# The seventh audit's F-11: 34 files and 13 GB accumulated in eight days,
# dominating the database/ directory they sit in, because every compaction wrote
# a full pre-compaction copy and nothing ever removed one. Eight of them came
# from a single afternoon, four within ninety seconds of each other.
#
# Two design decisions, both deliberate:
#
# **Dry-run by default, and the pipeline never calls this.** A retention rule
# that deletes databases as a side effect of a build is a rule that will one day
# delete the copy you needed -- and the whole purpose of the pre-swap backup is
# to be there when something has gone wrong. Deleting a database is the
# operator's act.
#
# **An unrecognised file is reported, never deleted.** The classes below are the
# ones this project writes. Anything else is somebody's deliberate copy, and a
# retention script that cleans up files it does not understand is a data-loss
# incident waiting for a naming convention to change.

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(root, "config", "source_registry.csv"))) {
  stop("Run from the project root: Rscript prune_backups.R", call. = FALSE)
}

args <- commandArgs(trailingOnly = TRUE)
apply_changes <- "--apply" %in% args
classify_only <- "--classify" %in% args
keep_argument <- grep("^--keep=", args, value = TRUE)
keep <- if (length(keep_argument)) {
  parsed <- suppressWarnings(as.integer(sub("^--keep=", "", keep_argument[[1]])))
  if (is.na(parsed) || parsed < 1L) {
    stop("--keep must be a positive whole number.", call. = FALSE)
  }
  parsed
} else 3L
unknown <- setdiff(args, c("--apply", "--classify", keep_argument))
if (length(unknown)) stop(
  "Unrecognised argument(s): ", paste(unknown, collapse = ", "),
  ". Usage: Rscript prune_backups.R [--classify] [--keep=N] [--apply]", call. = FALSE
)

# What produced a file, read from its name, and what the rule is for that class.
#
#   rolling  keep the most recent `keep`; the older ones are superseded copies
#   keep     never delete; one per schema step, or one somebody named on purpose
#   unknown  report and leave alone
BACKUP_CLASSES <- list(
  list(prefix = "paraguay_macro_pilot_pre_migration_schema", rule = "keep",
       label = "pre-migration (one per schema step)"),
  list(prefix = "paraguay_macro_pilot_milestone_", rule = "keep",
       label = "milestone (named deliberately)"),
  list(prefix = "paraguay_macro_pilot_pre_swap_", rule = "rolling",
       label = "pre-swap (the build each accepted run replaced)"),
  list(prefix = "paraguay_macro_pilot_pre_compaction_", rule = "rolling",
       label = "pre-compaction"),
  # A second, third or fifth copy taken at the same schema version during one
  # working session. Real snapshots, and not one-per-step migration evidence, so
  # they age out rather than being kept forever.
  list(prefix = "paraguay_macro_pilot_working_", rule = "rolling",
       label = "working copy (intermediate, same schema step)"),
  list(prefix = "blocked_", rule = "rolling",
       label = "blocked build candidate")
)

mib <- function(bytes) sprintf("%.0f MiB", bytes / 1048576)
gib <- function(bytes) sprintf("%.1f GiB", bytes / 1073741824)

classify <- function(name) {
  for (class in BACKUP_CLASSES) if (startsWith(name, class$prefix)) return(class)
  list(prefix = NA_character_, rule = "unknown", label = "unrecognised")
}

# --- Classification -----------------------------------------------------------
# The re-audit's RA2-11. Twenty-six hand-named copies matched no class, so this
# script reported and ignored 9.5 GiB -- safe, and useless. What they are cannot
# be read from their names (`pre30b_194844.duckdb`), but it can be read from
# inside them: every DuckDB file states the schema version it was left at.
#
# So each one is opened read-only and named for what it contains. One copy per
# schema step is the migration evidence and is kept; a second or fifth copy at
# the same step is a working snapshot from one session and ages out. Nothing is
# deleted here, and nothing is renamed without --apply.
classify_legacy_backups <- function(directory, apply_changes) {
  files <- list.files(directory, pattern = "[.]duckdb$", full.names = TRUE)
  unrecognised <- files[vapply(basename(files), function(n) {
    identical(classify(n)$rule, "unknown")
  }, logical(1))]
  if (!length(unrecognised)) {
    message("Every backup already matches a class. Nothing to classify.\n")
    return(invisible(NULL))
  }
  message("Reading ", length(unrecognised), " unrecognised file(s) to see what they contain...")
  read_schema <- function(path) {
    out <- try({
      con <- DBI::dbConnect(duckdb::duckdb(), path, read_only = TRUE)
      on.exit(try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE), add = TRUE)
      schema_home <- DBI::dbGetQuery(con, paste(
        "SELECT schema_name FROM duckdb_tables() WHERE table_name = 'schema_version' LIMIT 1"
      ))
      if (!nrow(schema_home)) return(NA_integer_)
      DBI::dbGetQuery(con, paste0(
        "SELECT max(version) AS v FROM ", schema_home$schema_name[[1]], ".schema_version"
      ))$v[[1]]
    }, silent = TRUE)
    if (inherits(out, "try-error")) NA_integer_ else as.integer(out)
  }
  info <- file.info(unrecognised)
  inventory <- data.frame(
    path = unrecognised, file = basename(unrecognised),
    schema_version = vapply(unrecognised, read_schema, integer(1), USE.NAMES = FALSE),
    size_mib = round(info$size / 1048576, 1), mtime = info$mtime,
    stringsAsFactors = FALSE
  )
  inventory <- inventory[order(inventory$schema_version, inventory$mtime), ]
  # The earliest copy at each schema version is the state before that step; the
  # rest of that version's copies are intermediate.
  inventory$role <- "working"
  first_at_version <- !duplicated(inventory$schema_version) & !is.na(inventory$schema_version)
  inventory$role[first_at_version] <- "pre_migration"
  inventory$role[is.na(inventory$schema_version)] <- "unidentified"
  stamp_of <- function(path, mtime) {
    found <- regmatches(basename(path), regexpr("[0-9]{8}_[0-9]{6}", basename(path)))
    if (length(found)) found else format(mtime, "%Y%m%d_%H%M%S")
  }
  inventory$proposed <- vapply(seq_len(nrow(inventory)), function(i) {
    stamp <- stamp_of(inventory$path[[i]], inventory$mtime[[i]])
    switch(
      inventory$role[[i]],
      pre_migration = paste0(
        "paraguay_macro_pilot_pre_migration_schema", inventory$schema_version[[i]], "_", stamp,
        ".duckdb"
      ),
      working = paste0("paraguay_macro_pilot_working_", stamp, ".duckdb"),
      inventory$file[[i]]
    )
  }, character(1))

  readr::write_csv(
    inventory[, c("file", "schema_version", "role", "proposed", "size_mib", "mtime")],
    file.path(root, "outputs", "backup_inventory.csv")
  )
  for (role in c("pre_migration", "working", "unidentified")) {
    rows <- inventory[inventory$role == role, ]
    if (!nrow(rows)) next
    message(role, " — ", nrow(rows), " file(s), ", gib(sum(rows$size_mib) * 1048576))
    for (i in seq_len(nrow(rows))) message(sprintf(
      "  schema %-4s %8s  %s\n           -> %s",
      ifelse(is.na(rows$schema_version[[i]]), "?", rows$schema_version[[i]]),
      mib(rows$size_mib[[i]] * 1048576), rows$file[[i]], rows$proposed[[i]]
    ))
    message("")
  }
  message("Inventory written to outputs/backup_inventory.csv.\n")
  renameable <- inventory[inventory$role != "unidentified" & inventory$file != inventory$proposed, ]
  if (!nrow(renameable)) return(invisible(inventory))
  if (!apply_changes) {
    message(
      "Would rename ", nrow(renameable), " file(s) so the retention rule recognises them. ",
      "Nothing has been renamed. Re-run with --apply to do it."
    )
    return(invisible(inventory))
  }
  renamed <- vapply(seq_len(nrow(renameable)), function(i) {
    isTRUE(file.rename(
      renameable$path[[i]], file.path(dirname(renameable$path[[i]]), renameable$proposed[[i]])
    ))
  }, logical(1))
  message(
    "Renamed ", sum(renamed), " of ", nrow(renameable), " file(s). ",
    "Nothing was deleted; run without --classify to see what retention would reclaim."
  )
  invisible(inventory)
}

if (classify_only) {
  suppressWarnings(suppressMessages({library(DBI); library(duckdb); library(readr)}))
  classify_legacy_backups(file.path(root, "database", "backups"), apply_changes)
  quit(save = "no", status = 0)
}

directories <- c(
  file.path(root, "database", "backups"),
  file.path(root, "database", "candidates")
)
files <- unlist(lapply(directories[dir.exists(directories)], function(directory) {
  list.files(directory, pattern = "[.]duckdb$", full.names = TRUE)
}))
if (!length(files)) {
  message("No backup or candidate databases found. Nothing to do.")
  quit(save = "no", status = 0)
}

info <- file.info(files)
inventory <- data.frame(
  path = files, name = basename(files), size = info$size, mtime = info$mtime,
  stringsAsFactors = FALSE
)
inventory$rule <- vapply(inventory$name, function(n) classify(n)$rule, character(1))
inventory$label <- vapply(inventory$name, function(n) classify(n)$label, character(1))
inventory$prefix <- vapply(inventory$name, function(n) {
  prefix <- classify(n)$prefix
  if (is.na(prefix)) "unrecognised" else prefix
}, character(1))

# Within a rolling class, newest first, and everything past `keep` goes.
inventory$decision <- "keep"
for (prefix in unique(inventory$prefix[inventory$rule == "rolling"])) {
  rows <- which(inventory$prefix == prefix)
  rows <- rows[order(inventory$mtime[rows], decreasing = TRUE)]
  if (length(rows) > keep) inventory$decision[rows[-seq_len(keep)]] <- "delete"
}


message("Retention: keep every migration and milestone copy, the ", keep,
        " most recent of each rolling class, and nothing else.\n")
for (prefix in unique(inventory$prefix)) {
  rows <- inventory[inventory$prefix == prefix, ]
  rows <- rows[order(rows$mtime, decreasing = TRUE), ]
  message(rows$label[[1]], " — ", nrow(rows), " file(s), ", gib(sum(rows$size)))
  for (i in seq_len(nrow(rows))) message(sprintf(
    "  %-8s %s  %s  %s", rows$decision[[i]], format(rows$mtime[[i]], "%Y-%m-%d %H:%M"),
    mib(rows$size[[i]]), rows$name[[i]]
  ))
  message("")
}

doomed <- inventory[inventory$decision == "delete", ]
unrecognised <- inventory[inventory$rule == "unknown", ]
if (nrow(unrecognised)) message(
  nrow(unrecognised), " file(s) match no known class and are left alone. If they are ",
  "superseded copies, rename them to a known prefix or remove them by hand.\n"
)

if (!nrow(doomed)) {
  message("Nothing to reclaim. ", nrow(inventory), " file(s), ", gib(sum(inventory$size)),
          " retained.")
  quit(save = "no", status = 0)
}

if (!apply_changes) {
  message(
    "Would delete ", nrow(doomed), " file(s), reclaiming ", gib(sum(doomed$size)), ".\n",
    "Nothing has been deleted. Re-run with --apply to do it."
  )
  quit(save = "no", status = 0)
}

removed <- vapply(doomed$path, function(path) isTRUE(file.remove(path)), logical(1))
if (any(!removed)) message(
  "Could not delete ", sum(!removed), " file(s): ",
  paste(basename(doomed$path[!removed]), collapse = ", ")
)
message(
  "Deleted ", sum(removed), " file(s), reclaiming ", gib(sum(doomed$size[removed])), ". ",
  nrow(inventory) - sum(removed), " file(s), ",
  gib(sum(inventory$size) - sum(doomed$size[removed])), " retained."
)
