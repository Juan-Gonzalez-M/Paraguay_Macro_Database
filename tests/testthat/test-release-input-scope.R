SCHEMA43_SCOPE_ID <- "schema43_lineage_only_20260914"
SCHEMA43_DEFERRED <- c(
  cda_curve = "8796a589fc2bd31317efdce7865d4598473fdacd048cf04b676dc8f78e2b144c",
  tcn_referential_daily = "74df666397a33b9c8cdfac10d7ffedd23acf7cbd5907ea21332e100fb939c0a4"
)

schema43_scope_fixture <- function() {
  registry <- readr::read_csv(
    file.path(project_test_root, "config", "source_registry.csv"), show_col_types = FALSE
  )
  historical_scope <- read_release_input_scope(project_test_root, SCHEMA43_SCOPE_ID)
  registry <- registry[registry$source_id %in% historical_scope$source_id, , drop = FALSE]
  discovered <- build_current_manifest(registry, project_test_root)
  list(registry = registry, discovered = discovered)
}

testthat::test_that("Schema 43 scope explicitly admits 22 vintages and defers two exact hashes", {
  fixture <- schema43_scope_fixture()
  scoped <- apply_release_input_scope(
    fixture$registry, fixture$discovered, project_test_root, SCHEMA43_SCOPE_ID,
    expected_schema_version = 43L
  )

  testthat::expect_equal(nrow(scoped$scope), nrow(fixture$registry))
  testthat::expect_equal(sum(scoped$scope$disposition == "admit"), 22L)
  testthat::expect_equal(sum(scoped$scope$disposition == "defer"), 2L)
  deferred <- scoped$scope[scoped$scope$disposition == "defer", ]
  testthat::expect_identical(
    stats::setNames(deferred$sha256, deferred$source_id), SCHEMA43_DEFERRED
  )
  testthat::expect_equal(nrow(scoped$manifest), 22L)
  testthat::expect_false(any(scoped$manifest$source_id %in% names(SCHEMA43_DEFERRED)))
  testthat::expect_setequal(
    scoped$manifest$source_id,
    fixture$registry$source_id[!fixture$registry$source_id %in% names(SCHEMA43_DEFERRED)]
  )
  diagnostics <- scoped$issues[
    scoped$issues$check_name == "release_input_deferred", , drop = FALSE
  ]
  testthat::expect_equal(nrow(diagnostics), 2L)
  testthat::expect_setequal(diagnostics$source_id, names(SCHEMA43_DEFERRED))
  for (source_id in names(SCHEMA43_DEFERRED)) {
    testthat::expect_match(
      diagnostics$detail[diagnostics$source_id == source_id], SCHEMA43_DEFERRED[[source_id]],
      fixed = TRUE
    )
  }
  testthat::expect_false(any(scoped$issues$severity == "error"))
})

testthat::test_that("Schema 43 deferral fails closed on hash drift", {
  fixture <- schema43_scope_fixture()
  for (source_id in names(SCHEMA43_DEFERRED)) {
    drifted <- fixture$discovered
    hit <- drifted$manifest$source_id == source_id
    drifted$manifest$sha256[hit] <- paste(rep(if (source_id == "cda_curve") "a" else "b", 64),
                                          collapse = "")
    drifted$manifest$vintage_id[hit] <- make_vintage_id(
      source_id, drifted$manifest$sha256[hit]
    )
    scoped <- apply_release_input_scope(
      fixture$registry, drifted, project_test_root, SCHEMA43_SCOPE_ID,
      expected_schema_version = 43L
    )
    unresolved <- scoped$issues[
      scoped$issues$source_id == source_id &
        scoped$issues$check_name == "release_input_scope_unresolved", , drop = FALSE
    ]
    testthat::expect_equal(nrow(unresolved), 1L)
    testthat::expect_equal(unresolved$severity, "error")
    testthat::expect_match(unresolved$detail, drifted$manifest$sha256[hit], fixed = TRUE)
    testthat::expect_false(source_id %in% scoped$manifest$source_id)
  }
})

testthat::test_that("a newly registered or otherwise unexpected source is unresolved, not hidden", {
  fixture <- schema43_scope_fixture()
  unexpected_registry <- dplyr::bind_rows(
    fixture$registry,
    dplyr::mutate(
      fixture$registry[1, ], source_id = "unexpected_source",
      source_label = "Unexpected source"
    )
  )
  unexpected_manifest <- dplyr::bind_rows(
    fixture$discovered$manifest,
    dplyr::mutate(
      fixture$discovered$manifest[1, ], source_id = "unexpected_source",
      sha256 = paste(rep("c", 64), collapse = ""),
      vintage_id = make_vintage_id("unexpected_source", paste(rep("c", 64), collapse = ""))
    )
  )
  scoped <- apply_release_input_scope(
    unexpected_registry,
    list(manifest = unexpected_manifest, issues = fixture$discovered$issues),
    project_test_root, SCHEMA43_SCOPE_ID, expected_schema_version = 43L
  )
  unresolved <- scoped$issues[
    scoped$issues$source_id == "unexpected_source" &
      scoped$issues$check_name == "release_input_scope_unresolved", , drop = FALSE
  ]
  testthat::expect_gte(nrow(unresolved), 1L)
  testthat::expect_true(all(unresolved$severity == "error"))
  testthat::expect_false("unexpected_source" %in% scoped$manifest$source_id)
})

testthat::test_that("scope identity is deterministic and distinguishes the Schema 43 product", {
  fixture <- schema43_scope_fixture()
  scoped <- apply_release_input_scope(
    fixture$registry, fixture$discovered, project_test_root, SCHEMA43_SCOPE_ID,
    expected_schema_version = 43L
  )
  reordered <- scoped$manifest[nrow(scoped$manifest):1, ]
  testthat::expect_identical(make_release_id(scoped$manifest), make_release_id(reordered))
  unscoped <- scoped$manifest[, setdiff(
    names(scoped$manifest), c("release_scope_id", "release_scope_digest")
  )]
  testthat::expect_false(identical(make_release_id(scoped$manifest), make_release_id(unscoped)))
  testthat::expect_identical(make_release_id(unscoped), "release:748d41036c3a73638a1c2086")
})

testthat::test_that("deferred workbooks, archives, parsers, and contracts remain intact", {
  scope <- read_release_input_scope(project_test_root, SCHEMA43_SCOPE_ID)
  contracts <- readr::read_csv(
    file.path(project_test_root, "config", "documented_source_contracts.csv"),
    show_col_types = FALSE
  )
  registry <- readr::read_csv(
    file.path(project_test_root, "config", "source_registry.csv"), show_col_types = FALSE
  )
  for (source_id in names(SCHEMA43_DEFERRED)) {
    decision <- scope[scope$source_id == source_id, ]
    current <- build_current_manifest(
      registry[registry$source_id == source_id, ], project_test_root
    )$manifest
    archive <- file.path(
      project_test_root, "input_archive", source_id,
      paste0(SCHEMA43_DEFERRED[[source_id]], ".xlsx")
    )
    testthat::expect_equal(nrow(current), 1L)
    testthat::expect_identical(current$sha256, decision$sha256)
    testthat::expect_true(file.exists(archive))
    testthat::expect_identical(file_sha256(archive), decision$sha256)
    testthat::expect_true(source_id %in% contracts$source_id)
    testthat::expect_true(registry$required[registry$source_id == source_id])
  }
  testthat::expect_true(exists("documented_parse_cda_curve_sheet", mode = "function"))
  testthat::expect_true(exists("documented_validate_daily_calendar_grid_workbook", mode = "function"))
  testthat::expect_true(exists("documented_parse_daily_calendar_grid", mode = "function"))
})
