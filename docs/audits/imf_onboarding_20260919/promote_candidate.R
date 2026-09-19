root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
source(file.path(root, "scripts", "load_project.R"))
load_project_scripts(root, profile = "pipeline", quiet = TRUE)

result <- promote_retained_candidate(
  root = root,
  candidate = file.path(
    root, "database", "candidates", "accepted_for_review_20260919_203133.duckdb"
  ),
  expected_sha256 = "e95ae6b0550347177c9fa57eda474990f6a7493bd5eac1c9a47f046a3b116616",
  expected_bytes = 1081356288,
  expected_production_sha256 = "9cf802028b8693506f5f6ad9ab321f2ace93f314fbeffe0a5ac831cdad087ca4",
  expected_build_id = "build:190aeb8320eaecd238c8d75b",
  expected_source_bundle_id = "release:42753eb4fa49d2dbedd73b07",
  expected_attempt_id = "attempt:a9e93ae220bdfebea12073a4",
  expected_schema_version = 49L,
  expected_scope_id = "schema49_imf_experimental_20260919",
  expected_scope_digest = "6b9238b3ed09bbb45d38cf82f228f9e34401765ed5a2fff67b62ae9658956d95",
  expected_canonical_facts = 3814646,
  expected_canonical_series = 32732
)
print(result)
