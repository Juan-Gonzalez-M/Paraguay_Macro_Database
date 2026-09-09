# Generates review-required YAML companions for documented-table worksheets.
# The parsers are already active; these files are a queue for optional semantic
# refinements such as unit overrides and cross-source concept mappings.
root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists(file.path(root, "config", "source_registry.csv"))) {
  stop("Run from the project root: Rscript --vanilla generate_spec_skeletons.R", call. = FALSE)
}
source(file.path(root, "scripts", "01_utils.R"))
registry <- readr::read_csv(file.path(root, "config", "source_registry.csv"), show_col_types = FALSE) %>%
  filter(ingest_mode == "semantic_table")
target_dir <- file.path(root, "outputs", "spec_skeletons")
dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
for (i in seq_len(nrow(registry))) {
  resolved <- resolve_current_files(registry[i, ], root)
  for (path in resolved$files) {
    dims <- xlsx_sheet_dimensions(path)
    for (j in seq_len(nrow(dims))) {
      preview <- read_dimensioned_sheet(path, dims[j, ], max_rows = 12L, max_cols = 20L)
      labels <- unique(str_squish(as.character(unlist(preview, use.names = FALSE))))
      labels <- labels[!is.na(labels) & nzchar(labels)]
      spec <- list(
        status = "review_required",
        source_id = registry$source_id[[i]],
        sheet = dims$sheet_name[[j]],
        observed_rows = dims$used_rows[[j]],
        observed_columns = dims$used_cols[[j]],
        candidate_anchors = head(labels, 12),
        required_manual_fields = c("unit_override", "scale_override", "concept_mapping", "hierarchy_review", "subtotal_validation")
      )
      filename <- paste0(janitor::make_clean_names(registry$source_id[[i]]), "__", janitor::make_clean_names(dims$sheet_name[[j]]), ".yml")
      yaml::write_yaml(spec, file.path(target_dir, filename))
    }
  }
}
message("Review-required specifications written to: ", target_dir)
