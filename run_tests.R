source("scripts/00_install_packages.R")
testthat::test_dir("tests/testthat", reporter = "summary")
