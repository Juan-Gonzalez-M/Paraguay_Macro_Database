# Run the regression suite.
#
# This no longer installs anything. The audit's F-09: the previous version
# sourced scripts/00_install_packages.R first, so running the tests could change
# the environment being tested -- and an `install.packages()` inside a test entry
# point is also what makes the suite unsafe to run in CI or during an audit.
#
# Preparing the environment is a separate, deliberate act:
#
#   renv::restore()                      # match the recorded environment
#   source("scripts/00_install_packages.R")  # or, without renv, install by name
#
# check_environment() reports drift against renv.lock and does not fix it.
source("scripts/01_utils.R")
check_environment(getwd())
testthat::test_dir("tests/testthat", reporter = "summary")
