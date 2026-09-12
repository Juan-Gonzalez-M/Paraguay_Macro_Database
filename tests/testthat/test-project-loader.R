test_that("project loader profiles reference existing scripts in dependency order", {
  expect_named(PROJECT_SCRIPT_PROFILES)
  expect_true(all(vapply(PROJECT_SCRIPT_PROFILES, length, integer(1)) > 0L))
  expect_true(all(vapply(PROJECT_SCRIPT_PROFILES, function(scripts) {
    !anyDuplicated(scripts) && all(file.exists(file.path(project_test_root, "scripts", scripts)))
  }, logical(1))))
  expect_identical(tail(PROJECT_SCRIPT_PROFILES$pipeline, 1L), "06_pipeline.R")
  expect_identical(
    PROJECT_SCRIPT_PROFILES$research_tools,
    head(PROJECT_SCRIPT_PROFILES$pipeline, -1L)
  )
})

test_that("project loader fails clearly for unknown profiles", {
  expect_error(
    load_project_scripts(project_test_root, "not-a-profile", new.env()),
    "Unknown project script profile"
  )
})

test_that("supported entry points use the canonical loader", {
  entry_points <- c(
    "run_update.R", "rebuild_from_archive.R", "prepare_review_packets.R",
    "sign_off_reviews.R", "worksheet_review.R", "build_migration_map.R"
  )
  code <- vapply(entry_points, function(path) paste(
    readLines(file.path(project_test_root, path), warn = FALSE), collapse = "\n"
  ), character(1))
  expect_true(all(grepl("scripts.*load_project[.]R", code)))
  expect_false(any(grepl("for \\(script in c", code)))
})

test_that("current Markdown links resolve inside the repository", {
  documents <- c(file.path(project_test_root, c("README.md", "PROJECT_HANDOVER.md")), list.files(
    file.path(project_test_root, "docs"), pattern = "[.]md$", full.names = TRUE
  ))
  broken <- character()
  for (document in documents) {
    text <- paste(readLines(document, warn = FALSE), collapse = "\n")
    links <- regmatches(text, gregexpr("\\[[^]]+\\]\\([^)]+\\)", text, perl = TRUE))[[1]]
    if (identical(links, character(0)) || identical(links, "")) next
    targets <- sub("^.*\\]\\(([^)#]+)(?:#[^)]*)?\\)$", "\\1", links, perl = TRUE)
    targets <- targets[!grepl("^(https?:|mailto:)", targets)]
    missing <- targets[!file.exists(file.path(dirname(document), targets))]
    if (length(missing)) broken <- c(broken, paste(basename(document), missing, sep = ": "))
  }
  if (length(broken)) testthat::fail(paste("Broken local Markdown links:", paste(
    broken, collapse = "\n"
  ), sep = "\n"))
  expect_length(broken, 0L)
})

test_that("README advertises the current executable schema", {
  version <- max(vapply(SCHEMA_MIGRATIONS, function(step) step$version, integer(1)))
  title <- readLines(file.path(project_test_root, "README.md"), n = 1L, warn = FALSE)
  expect_match(title, paste0("v", version, "$"))
})

test_that("retired schema-40 view builder is absent", {
  expect_false(exists("create_schema40_compat_views", inherits = TRUE))
  expect_false(exists("register_column_order", inherits = TRUE))
  expect_false(exists("write_review_readiness_packets", inherits = TRUE))
})
