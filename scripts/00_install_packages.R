# Install the packages this project loads, by name.
#
# This is not what run_tests.R does any more. The audit's F-09: a test entry
# point that installs packages can change the environment it is testing, and
# cannot be run in CI or during an audit without side effects. Preparing the
# environment is a deliberate act, and this file is it.
#
# The recorded environment is renv.lock. To reproduce it exactly rather than
# install whatever CRAN publishes today:
#
#   renv::restore()
#
# check_environment() in scripts/01_utils.R reports the difference either way.
required <- c(
  "readxl", "openxlsx", "dplyr", "tidyr", "stringr", "stringi", "lubridate",
  "janitor", "DBI", "duckdb", "digest", "fs", "xml2", "readr",
  "yaml", "testthat", "withr", "renv", "jsonlite"
)
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
message(
  "Required packages are installed. Compare them with the recorded environment using ",
  "check_environment(), then run: source('run_update.R')"
)
