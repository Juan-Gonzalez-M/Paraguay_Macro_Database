#!/usr/bin/env Rscript
# --- Promoting a drafted review into a governed register ---------------------
#
# The readiness audit's ER-03 asks for an economic review; its governing
# principle 4 asks that "each decision needs reviewer, review date, source
# citation, rationale", and its principle 3 that a gate is never made to pass by
# filling a field with a guess.
#
# Those two requirements are in tension the moment anyone other than the reviewer
# prepares the evidence. A draft with a reviewer's name already on it is not a
# draft; a draft with nobody's name on it cannot enter a register that requires
# one. So drafting and signing are separated:
#
#   config/proposals/<register>.csv   evidence, a citation and a proposed value,
#                                     attributed to whoever drafted it, read by
#                                     nothing in the pipeline and admitting no
#                                     series to anything.
#
#   config/<register>.csv             the governed register. A row arrives here
#                                     only through this script, only with a named
#                                     reviewer and a date, and only if the whole
#                                     resulting register passes its own validator.
#
# Until a row is signed, marts.v_research_series stays empty. That is the
# fail-closed principle working rather than a gap.
#
# Usage:
#   Rscript sign_off_reviews.R
#       Dry run. Lists every proposal with its evidence and open questions, and
#       says what signing it would do. Writes nothing.
#
#   Rscript sign_off_reviews.R --register=series_review --series=<id>[,<id>...] \
#                              --reviewer="Your Name"
#       Signs the named proposals.
#
#   Rscript sign_off_reviews.R --register=series_review --all --reviewer="Your Name"
#       Signs every proposal in that register. Use it when you have read them all.
#
# Options:
#   --date=YYYY-MM-DD   the review date (default: today)
#   --force             sign a proposal whose confidence is 'low' or which still
#                       has open questions recorded against it. Without it those
#                       are skipped and reported, because an open question is a
#                       reason not to sign.

root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(root, "config", "source_registry.csv"))) stop(
  "Run this from the project root.", call. = FALSE
)
# Register validators reach across stages, so this uses the governed dependency
# profile shared with the other entry points rather than maintaining a local list.
source(file.path(root, "scripts", "load_project.R"))
load_project_scripts(root, profile = "governance", quiet = TRUE)

# The annotations a proposal carries and a register does not: who drafted it,
# what it rests on, how sure they were, and what is still unresolved. They are
# stripped on promotion -- the register records the decision, and the evidence
# behind it stays in the proposal file, which is version-controlled beside it.
# `proposal_evidence`, not `evidence`: methodology_regimes and
# canonical_series_members already have a column called `evidence`, which is part
# of the decision and travels into the register. The annotation is a different
# thing -- why the draft says what it says -- and giving them the same name would
# make one silently overwrite the other.
PROPOSAL_ANNOTATION_COLUMNS <- c(
  "proposal_evidence", "source_cell", "proposed_by", "proposed_at", "confidence",
  "open_questions"
)

PROPOSAL_CONFIDENCE_VALUES <- c("high", "medium", "low")

# Each register, the columns its file has, and the key that identifies a row in
# it. `stamped` names the columns this script fills in on promotion; a proposal
# must not carry them, because a drafted row with a reviewer's name on it is the
# thing this whole arrangement exists to prevent.
REVIEW_REGISTERS <- list(
  series_review = list(
    file = "series_review.csv",
    columns = c(SERIES_REVIEW_REQUIRED_FIELDS, SERIES_REVIEW_CONDITIONAL_FIELDS),
    key = "series_id",
    stamped = c("reviewed_by", "reviewed_at")
  ),
  table_status = list(
    file = "table_status.csv",
    columns = c("source_id", "source_sheet", "status", "parser_claim", "reviewed_by",
                "reviewed_at", "note", "definitions_reviewed", "units_reviewed",
                "timing_reviewed", "hierarchy_reviewed", "methodology_reviewed",
                "evidence_uri"),
    key = c("source_id", "source_sheet"),
    stamped = c("reviewed_by", "reviewed_at"),
    vocabulary = list(status = TABLE_STATUS_VALUES, parser_claim = TABLE_STATUS_PARSER_CLAIMS)
  ),
  canonical_series = list(
    file = "canonical_series.csv",
    columns = c("canonical_series_id", "canonical_name", "concept_id", "definition", "domain", "subdomain",
                "frequency", "unit_code", "currency", "stock_flow", "nominal_real",
                "seasonal_adjustment", "transformation", "valuation", "methodology_regime_id",
                "reviewed_status", "reviewed_by", "reviewed_at"),
    key = "canonical_series_id",
    stamped = c("reviewed_by", "reviewed_at"),
    vocabulary = list(reviewed_status = CANONICAL_REVIEW_STATUSES)
  ),
  canonical_series_members = list(
    file = "canonical_series_members.csv",
    columns = c("canonical_series_id", "series_id", "relationship", "valid_from", "valid_to",
                "precedence", "overlap_policy", "evidence",
                "reviewed_by", "reviewed_at"),
    key = c("canonical_series_id", "series_id"),
    stamped = c("reviewed_by", "reviewed_at"),
    vocabulary = list(relationship = CANONICAL_RELATIONSHIPS)
  ),
  methodology_regimes = list(
    file = "methodology_regimes.csv",
    columns = c("regime_id", "concept_key", "regime_label", "change_type", "effective_from",
                "effective_to", "comparability", "evidence", "reviewed_by", "reviewed_at"),
    key = "regime_id",
    stamped = c("reviewed_by", "reviewed_at"),
    vocabulary = list(change_type = METHODOLOGY_CHANGE_TYPES,
                      comparability = METHODOLOGY_COMPARABILITY)
  )
)

parse_arguments <- function(args) {
  value_of <- function(flag) {
    hit <- grep(paste0("^--", flag, "="), args, value = TRUE)
    if (!length(hit)) return(NULL)
    sub(paste0("^--", flag, "="), "", hit[[1]])
  }
  list(
    register = value_of("register"),
    reviewer = value_of("reviewer"),
    date = value_of("date"),
    keys = {
      raw <- c(value_of("series"), value_of("key"))
      if (is.null(raw)) NULL else trimws(unlist(strsplit(raw, ",", fixed = TRUE)))
    },
    all = "--all" %in% args,
    force = "--force" %in% args
  )
}

read_proposals <- function(root, register_name) {
  spec <- REVIEW_REGISTERS[[register_name]]
  path <- file.path(root, "config", "proposals", spec$file)
  if (!file.exists(path)) return(NULL)
  proposals <- readr::read_csv(
    path, show_col_types = FALSE, col_types = readr::cols(.default = readr::col_character())
  )
  # Schema-40 defaults let the existing unsigned evidence pack be reviewed
  # without pretending that a mechanical CSV migration was an economic review.
  if (identical(register_name, "canonical_series") && !"canonical_name" %in% names(proposals)) {
    proposals$canonical_name <- proposals$concept_id
  }
  if (identical(register_name, "canonical_series_members") &&
      !"precedence" %in% names(proposals)) {
    proposals$valid_from <- ""; proposals$valid_to <- ""; proposals$precedence <- "1"
    proposals$overlap_policy <- "require_equal_then_primary"
  }
  expected <- c(setdiff(spec$columns, spec$stamped), PROPOSAL_ANNOTATION_COLUMNS)
  missing <- setdiff(expected, names(proposals))
  if (length(missing)) stop(
    "config/proposals/", spec$file, " is missing column(s): ", paste(missing, collapse = ", "),
    call. = FALSE
  )
  # A drafted row must not carry a reviewer. If it did, the separation this
  # script exists to enforce would already have been bypassed by whoever wrote
  # the file.
  present <- intersect(spec$stamped, names(proposals))
  if (length(present)) stop(
    "config/proposals/", spec$file, " carries ", paste(present, collapse = ", "),
    ". A proposal is unsigned by construction; the signature is added here, by the person ",
    "who read it.", call. = FALSE
  )
  bad_confidence <- !proposals$confidence %in% PROPOSAL_CONFIDENCE_VALUES
  if (any(bad_confidence)) stop(
    "config/proposals/", spec$file, ": confidence must be one of ",
    paste(PROPOSAL_CONFIDENCE_VALUES, collapse = ", "), ".", call. = FALSE
  )
  proposals[expected]
}

read_register <- function(root, register_name) {
  spec <- REVIEW_REGISTERS[[register_name]]
  path <- file.path(root, "config", spec$file)
  register <- readr::read_csv(
    path, show_col_types = FALSE, col_types = readr::cols(.default = readr::col_character())
  )
  # Set equality, not order. The register's field constants are grouped by
  # meaning -- required fields, then the ones required only conditionally -- and
  # the file is ordered for a human filling it in. Both are legitimate and they
  # are not the same order. What must not differ is which columns exist, because
  # the register's own guards read them by name and a missing one is a question
  # nobody was asked.
  if (!setequal(names(register), spec$columns)) stop(
    "config/", spec$file, " does not have the expected columns (missing: ",
    paste(setdiff(spec$columns, names(register)), collapse = ", "), "; unexpected: ",
    paste(setdiff(names(register), spec$columns), collapse = ", "),
    "). Refusing to write to a register whose shape this script does not recognise.",
    call. = FALSE
  )
  register
}

# The order the register file itself uses, so signing a row does not silently
# rewrite the whole file into a different column order.
register_column_order <- function(root, register_name) {
  names(read_register(root, register_name))
}

proposal_key <- function(rows, spec) {
  if (!nrow(rows)) return(character())
  do.call(paste, c(lapply(spec$key, function(column) rows[[column]]), sep = " / "))
}

describe_proposals <- function(root, register_name, proposals) {
  spec <- REVIEW_REGISTERS[[register_name]]
  register <- read_register(root, register_name)
  signed <- proposal_key(register, spec)
  keys <- proposal_key(proposals, spec)
  cat("\n", register_name, " -- ", nrow(proposals), " proposal(s), ",
      sum(!keys %in% signed), " unsigned\n", sep = "")
  cat(strrep("-", 78), "\n", sep = "")
  for (i in seq_len(nrow(proposals))) {
    status <- if (keys[[i]] %in% signed) "SIGNED" else "unsigned"
    cat("\n[", status, "] ", keys[[i]], "\n", sep = "")
    cat("  confidence: ", proposals$confidence[[i]], "\n", sep = "")
    if (has_text(proposals$source_cell[[i]])) {
      cat("  source:     ", proposals$source_cell[[i]], "\n", sep = "")
    }
    cat("  evidence:   ", proposals$proposal_evidence[[i]], "\n", sep = "")
    if (has_text(proposals$open_questions[[i]])) {
      cat("  OPEN:       ", proposals$open_questions[[i]], "\n", sep = "")
    }
  }
  invisible(NULL)
}

# The standard null-coalesce, and only that. It was written as
# `if (is.null(x) || is.na(x))`, which works for a missing character scalar and
# breaks on anything longer: `is.na()` of the two-element vocabulary list returns
# a length-two logical, and `||` has rejected those since R 4.3. Blank-or-absent
# text is a different question and is asked separately, below.
`%||%` <- function(x, y) if (is.null(x)) y else x

# Absent, NA, or whitespace -- the three ways a proposal field says nothing.
has_text <- function(x) length(x) == 1L && !is.na(x) && nzchar(trimws(x))

sign_off <- function(root, register_name, keys_wanted, reviewer, review_date, force) {
  spec <- REVIEW_REGISTERS[[register_name]]
  proposals <- read_proposals(root, register_name)
  if (is.null(proposals) || !nrow(proposals)) {
    message("No proposals in config/proposals/", spec$file, ".")
    return(invisible(0L))
  }
  keys <- proposal_key(proposals, spec)
  selected <- if (is.null(keys_wanted)) rep(TRUE, length(keys)) else keys %in% keys_wanted
  unknown <- setdiff(keys_wanted, keys)
  if (length(unknown)) stop(
    "No proposal for: ", paste(unknown, collapse = ", "), call. = FALSE
  )
  # An open question is a reason not to sign. So is low confidence. Both can be
  # overridden deliberately and neither by accident.
  blocked <- selected & !force & (
    proposals$confidence %in% "low" |
      (!is.na(proposals$open_questions) & nzchar(trimws(proposals$open_questions)))
  )
  if (any(blocked)) {
    message(
      "Skipping ", sum(blocked), " proposal(s) with open questions or low confidence:\n  - ",
      paste(keys[blocked], collapse = "\n  - "),
      "\nRead them, resolve the question in the proposal file, or pass --force to sign anyway."
    )
  }
  selected <- selected & !blocked
  if (!any(selected)) {
    message("Nothing to sign.")
    return(invisible(0L))
  }
  register <- read_register(root, register_name)
  promoted <- proposals[selected, setdiff(spec$columns, spec$stamped), drop = FALSE]
  promoted$reviewed_by <- reviewer
  promoted$reviewed_at <- format(review_date, "%Y-%m-%d")
  promoted <- promoted[names(register)]
  # Re-signing an existing row replaces it rather than duplicating the key.
  existing <- proposal_key(register, spec)
  register <- register[!existing %in% proposal_key(promoted, spec), , drop = FALSE]
  updated <- dplyr::bind_rows(register, promoted)

  problems <- validate_signed_register(root, register_name, updated)
  if (nrow(problems)) {
    stop(
      "The register would not be valid after signing, so nothing was written:\n  - ",
      paste(utils::head(paste0(problems$series_id, ": ", problems$problem), 20), collapse = "\n  - "),
      call. = FALSE
    )
  }
  readr::write_csv(updated, file.path(root, "config", spec$file), na = "")
  message(
    "Signed ", sum(selected), " proposal(s) into config/", spec$file, " as ", reviewer,
    " on ", format(review_date, "%Y-%m-%d"), ".\n",
    "Run `Rscript -e 'source(\"run_update.R\")'` to rebuild; the validated marts become ",
    "non-empty only after that."
  )
  invisible(sum(selected))
}

# The register's own validator, run before the file is written rather than
# discovered by the next build. series_review has a real one; the governance
# registers are guarded inside apply_*(), so what can be checked here is the key
# and the completeness of the row.
validate_signed_register <- function(root, register_name, updated) {
  spec <- REVIEW_REGISTERS[[register_name]]
  if (identical(register_name, "series_review")) {
    return(series_review_problems(updated))
  }
  blank <- function(x) is.na(x) | !nzchar(trimws(x))
  problems <- list()
  key <- proposal_key(updated, spec)
  # The closed vocabularies each register's apply_*() enforces, checked here
  # instead of at the next build. Discovering that `rebase` is spelled
  # `base_period` when the pipeline refuses to start is a worse way to find out
  # than being told before the file is written.
  for (field in names(spec$vocabulary %||% list())) {
    allowed <- spec$vocabulary[[field]]
    offending <- !blank(updated[[field]]) & !updated[[field]] %in% allowed
    if (any(offending)) problems[[length(problems) + 1L]] <- tibble::tibble(
      series_id = key[offending],
      problem = paste0(
        "`", field, "` is '", updated[[field]][offending], "', which is outside the register's ",
        "vocabulary (", paste(allowed, collapse = ", "), ")."
      )
    )
  }
  if (anyDuplicated(key)) problems[[length(problems) + 1L]] <- tibble::tibble(
    series_id = key[duplicated(key)], problem = "the key appears more than once."
  )
  for (field in c(spec$stamped, spec$key)) {
    if (any(blank(updated[[field]]))) problems[[length(problems) + 1L]] <- tibble::tibble(
      series_id = key[blank(updated[[field]])], problem = paste0("`", field, "` is blank.")
    )
  }
  if (!length(problems)) tibble::tibble(series_id = character(), problem = character())
  else dplyr::bind_rows(problems)
}

main <- function(args = commandArgs(trailingOnly = TRUE)) {
  options <- parse_arguments(args)
  registers <- if (is.null(options$register)) names(REVIEW_REGISTERS) else options$register
  unknown <- setdiff(registers, names(REVIEW_REGISTERS))
  if (length(unknown)) stop(
    "Unknown register: ", paste(unknown, collapse = ", "),
    ". Known: ", paste(names(REVIEW_REGISTERS), collapse = ", "), call. = FALSE
  )
  if (is.null(options$reviewer)) {
    cat(
      "Dry run: nothing will be written.\n",
      "Sign with --register=<name> --reviewer=\"Your Name\" and either --all or --series=<id,...>\n",
      sep = ""
    )
    any_found <- FALSE
    for (register_name in registers) {
      proposals <- tryCatch(read_proposals(root, register_name), error = function(e) {
        message("config/proposals/", REVIEW_REGISTERS[[register_name]]$file, ": ",
                conditionMessage(e))
        NULL
      })
      if (is.null(proposals) || !nrow(proposals)) next
      any_found <- TRUE
      describe_proposals(root, register_name, proposals)
    }
    if (!any_found) cat("\nNo proposals found under config/proposals/.\n")
    return(invisible(NULL))
  }
  if (!nzchar(trimws(options$reviewer))) stop(
    "--reviewer must name a person. A register row records who decided it.", call. = FALSE
  )
  if (is.null(options$register)) stop(
    "--register is required when signing. Sign one register at a time and read it first.",
    call. = FALSE
  )
  if (!options$all && is.null(options$keys)) stop(
    "Pass --all, or --series=<id,...> naming what you have read.", call. = FALSE
  )
  review_date <- if (is.null(options$date)) Sys.Date() else as.Date(options$date)
  if (is.na(review_date)) stop("--date must be YYYY-MM-DD.", call. = FALSE)
  if (review_date > Sys.Date()) stop(
    "--date is in the future. A review cannot have happened yet.", call. = FALSE
  )
  sign_off(
    root, options$register, if (options$all) NULL else options$keys,
    trimws(options$reviewer), review_date, options$force
  )
}

if (!interactive() && identical(environment(), globalenv())) main()
