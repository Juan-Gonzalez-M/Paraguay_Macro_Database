# Run from the project root: source("run_update.R")
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(root, "config", "source_registry.csv"))) {
  stop("Open pilot_paraguay_macro_database.Rproj first, then run source('run_update.R').", call. = FALSE)
}
source(file.path(root, "scripts", "load_project.R"))
load_project_scripts(root, profile = "pipeline")

# The audit's F-09: the update did not enforce the environment it records. A
# build carries an environment_digest of renv.lock, so a database built against a
# library that drifted from the lockfile claims a reproducibility it does not
# have -- and claims it under a build_id that cannot tell the two apart.
#
# check_environment() has existed since the first audit and nothing called it
# strictly. It does now. The override is deliberate, explicit and recorded: a
# build that took it says so in its own quality flags, rather than being
# indistinguishable from one that did not.
environment_issues <- tibble::tibble(
  severity = character(), check_name = character(),
  source_id = character(), detail = character()
)
if (identical(Sys.getenv("PARAGUAY_MACRO_ALLOW_ENV_DRIFT"), "1")) {
  drift <- withCallingHandlers(
    check_environment(root, strict = FALSE),
    warning = function(w) invokeRestart("muffleWarning")
  )
  if (!isTRUE(drift)) {
    message(
      "PARAGUAY_MACRO_ALLOW_ENV_DRIFT=1: building against an environment that differs from ",
      "renv.lock. The difference is recorded as a quality flag on this build."
    )
    environment_issues <- tibble::tibble(
      severity = "warning", check_name = "environment_drift_overridden",
      source_id = NA_character_,
      detail = paste(
        "The running package versions differ from renv.lock and the build was allowed to",
        "proceed by PARAGUAY_MACRO_ALLOW_ENV_DRIFT=1. Run check_environment() for the",
        "difference and renv::restore() to remove it."
      )
    )
  }
} else {
  check_environment(root, strict = TRUE)
}

ensure_dirs(root)
registry <- readr::read_csv(file.path(root, "config", "source_registry.csv"), show_col_types = FALSE)
# Schema 43 is the explicitly authorized lineage-only product. The governed
# scope names every registered source and exact full hash, including exact
# deferrals, so a changed or newly registered input blocks instead of silently
# changing the product population.
resolved <- build_scoped_current_manifest(
  registry, root, "schema43_lineage_only_20260914", expected_schema_version = 43L
)

# The audit's F-01. The pipeline builds into a candidate file beside the
# published database and the candidate is renamed into place only if it is
# accepted, so a blocked or crashed build cannot alter what is published --
# by any mechanism, including the schema migrations that delete published facts
# before a run begins. See run_isolated_update() in scripts/06_pipeline.R.
result <- run_isolated_update(
  root, registry, resolved$manifest,
  dplyr::bind_rows(resolved$issues, environment_issues)
)
message("Database: ", result$publication)
message("Deterministic release: ", result$release_id)
message("Build: ", result$build_id)
message("Run status: ", result$status)
message("Published: ", if (isTRUE(result$published)) "yes" else "no")
message("Review outputs/update_report.md before using new observations.")
# The audit's P0 asks for a gate that actually stops a defective release rather
# than recording its defects and continuing. An error-severity flag now fails
# the run, so a caller in a script or scheduler sees it.
if (identical(result$status, "release_blocked")) {
  stop(
    "Release gate: the run produced error-severity quality flags and is blocked. ",
    "The published database is unchanged. See outputs/quality_flags_latest.csv, and ",
    "inspect the blocked build at ", result$candidate, call. = FALSE
  )
}
