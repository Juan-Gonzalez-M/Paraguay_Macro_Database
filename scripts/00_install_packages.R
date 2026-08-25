required <- c(
  "readxl", "openxlsx", "dplyr", "tidyr", "stringr", "stringi", "lubridate",
  "janitor", "DBI", "duckdb", "digest", "fs", "xml2", "readr",
  "yaml", "testthat"
)
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
message("Required packages are installed. Now run: source('run_update.R')")
