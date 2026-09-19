root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(root, "scripts", "load_project.R"))
load_project_scripts(root, profile = "pipeline")

registry <- readr::read_csv(
  file.path(root, "config", "source_registry.csv"), show_col_types = FALSE
)
resolved <- build_scoped_current_manifest(
  registry, root, "schema48_imf_expansion_20260919",
  expected_schema_version = 48L
)

environment_ok <- withCallingHandlers(
  check_environment(root, strict = FALSE),
  warning = function(w) invokeRestart("muffleWarning")
)
environment_issues <- if (isTRUE(environment_ok)) {
  tibble::tibble(
    severity = character(), check_name = character(),
    source_id = character(), detail = character()
  )
} else {
  tibble::tibble(
    severity = "warning", check_name = "environment_drift_overridden",
    source_id = NA_character_,
    detail = paste(
      "The running package versions differ from renv.lock. Package installation",
      "was not authorized; the isolated review candidate records this limitation."
    )
  )
}

result <- run_isolated_update(
  root, registry, resolved$manifest,
  dplyr::bind_rows(resolved$issues, environment_issues),
  publish = FALSE
)
print(result)
