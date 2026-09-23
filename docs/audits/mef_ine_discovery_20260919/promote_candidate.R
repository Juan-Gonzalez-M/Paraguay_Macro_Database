root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(root, "scripts", "load_project.R"))
load_project_scripts(root, profile = "pipeline", quiet = TRUE)

result <- promote_retained_candidate(
  root = root,
  candidate = file.path(
    root, "database", "candidates", "accepted_for_review_20260920_015318.duckdb"
  ),
  expected_sha256 = "c902c77fcddd3050641c50243c9244f4f77e9814ebdaa4582f14aed11a4b4f50",
  expected_bytes = 1081356288,
  expected_production_sha256 = "e95ae6b0550347177c9fa57eda474990f6a7493bd5eac1c9a47f046a3b116616",
  expected_build_id = "build:481cb2d5c90afff4f1964f7f",
  expected_source_bundle_id = "release:90ecbb654ed9413352a4e028",
  expected_attempt_id = "attempt:3f3ebc8b67a619e396a77ac1",
  expected_schema_version = 49L,
  expected_canonical_facts = 3864771,
  expected_canonical_series = 33902
)
print(result)
