# Canonical script loader for command-line entry points and tests.
#
# File numbers describe the pipeline stages historically; they are not a safe
# lexical load order (concept helpers, for example, precede extraction). Keep
# dependency order in this one manifest instead of copying it into every tool.

PROJECT_SCRIPT_PROFILES <- list(
  pipeline = c(
    "01_utils.R", "03_concepts.R", "02_extract_raw.R", "03_reference_semantics.R",
    "03_curate_documented.R", "03_curate_expanded.R", "03_curate_special.R",
    "04_validate.R", "05_query_helpers.R", "07_migration.R", "08_reconciliation.R",
    "09_semantics.R", "10_canonical.R", "11_marts.R", "12_platform.R",
    "13_explore.R", "14_review_readiness.R", "06_pipeline.R"
  ),
  research_tools = c(
    "01_utils.R", "03_concepts.R", "02_extract_raw.R", "03_reference_semantics.R",
    "03_curate_documented.R", "03_curate_expanded.R", "03_curate_special.R",
    "04_validate.R", "05_query_helpers.R", "07_migration.R", "08_reconciliation.R",
    "09_semantics.R", "10_canonical.R", "11_marts.R", "12_platform.R",
    "13_explore.R", "14_review_readiness.R"
  ),
  governance = c(
    "01_utils.R", "03_concepts.R", "02_extract_raw.R", "04_validate.R",
    "08_reconciliation.R", "09_semantics.R", "10_canonical.R", "11_marts.R"
  ),
  worksheet_review = c(
    "01_utils.R", "03_concepts.R", "02_extract_raw.R", "09_semantics.R"
  ),
  migration = c("01_utils.R", "03_concepts.R", "02_extract_raw.R", "07_migration.R")
)

load_project_scripts <- function(root, profile = "pipeline", envir = parent.frame(),
                                 quiet = FALSE) {
  scripts <- PROJECT_SCRIPT_PROFILES[[profile]]
  if (is.null(scripts)) stop(
    "Unknown project script profile: ", profile, ". Choose one of: ",
    paste(names(PROJECT_SCRIPT_PROFILES), collapse = ", "), call. = FALSE
  )
  paths <- file.path(root, "scripts", scripts)
  missing <- paths[!file.exists(paths)]
  if (length(missing)) stop(
    "Project script profile '", profile, "' references missing file(s): ",
    paste(basename(missing), collapse = ", "), call. = FALSE
  )
  for (path in paths) {
    if (quiet) suppressMessages(sys.source(path, envir = envir))
    else sys.source(path, envir = envir)
  }
  invisible(scripts)
}
