project_test_root <- normalizePath(file.path(getwd()), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(project_test_root, "config", "source_registry.csv"))) {
  project_test_root <- normalizePath(file.path(getwd(), "..", ".."), winslash = "/", mustWork = TRUE)
}
for (script in c("01_utils.R", "03_concepts.R", "02_extract_raw.R", "03_reference_semantics.R", "03_curate_documented.R", "03_curate_expanded.R", "03_curate_special.R", "04_validate.R", "06_pipeline.R")) {
  source(file.path(project_test_root, "scripts", script))
}
