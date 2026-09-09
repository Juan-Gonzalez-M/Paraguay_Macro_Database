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

test_that("retired schema-40 view builder is absent", {
  expect_false(exists("create_schema40_compat_views", inherits = TRUE))
})
