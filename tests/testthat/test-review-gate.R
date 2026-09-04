# The re-audit's RA2-02: `canonical.series_review` was not required by
# `marts.v_research_series`, and the eligibility gate tested column *values*
# rather than reviewed evidence.
#
# The trace the re-audit gives is the one that matters. The derivation layer
# fills every eligibility field from published wording -- a label reading "saldo"
# yields stock_flow = 'stock' with basis = 'published_label', a published price
# base year yields nominal_real = 'real' -- and none of those values is
# 'not_reviewed', so the gate passed them. The only remaining barrier was a human
# promoting the *worksheet*. Promote one, and every series on it would have
# entered the research surface with zero economic review, while the
# documentation said the register was what let them in.
#
# This file builds exactly that state and asserts it is now refused.

review_gate_fixture <- function(env = parent.frame(), reviewed = FALSE) {
  path <- withr::local_tempfile(fileext = ".duckdb", .local_envir = env)
  con <- DBI::dbConnect(duckdb::duckdb(), path)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE), envir = env)
  initialize_database(con, project_test_root)
  release <- "release:review-gate"

  DBI::dbWriteTable(con, "release_sources", tibble::tibble(
    release_id = release, source_id = "fixture", vintage_id = "fixture:v1"
  ), append = TRUE)
  DBI::dbWriteTable(con, "source_files", tibble::tibble(
    vintage_id = "fixture:v1", first_ingested_release_id = release, source_id = "fixture",
    source_label = "Fixture", publisher = "Fixture", source_format = "xlsx",
    source_file = "fixture.xlsx", source_path = NA_character_, archive_path = NA_character_,
    sha256 = "aa", size_bytes = 1, publication_date = as.Date("2026-02-15"),
    publication_date_source = "filename", first_ingested_at = Sys.time(),
    ingestion_status = "completed", vintage_sk = 1L
  ), append = TRUE)
  # Every eligibility field populated, and none of them 'not_reviewed' -- exactly
  # what the derivation layer produces from a Spanish label and a base year.
  DBI::dbWriteTable(con, "dim_series", tibble::tibble(
    series_id = "fixture:series", source_id = "fixture",
    label = "Saldo a fin de periodo - Serie Original", unit = "index", scale = "units",
    frequency = "monthly", first_vintage_id = "fixture:v1", series_grain = "scalar_series",
    unit_code = "INDEX", scale_multiplier = 1, price_base_year = "2020",
    stock_flow = "stock", nominal_real = "real", seasonal_adjustment = "not_adjusted",
    transformation = "index", valuation = "not_applicable",
    semantic_status = "documented_series", series_sk = 1L
  ), append = TRUE)
  # …and the evidence recording that they were *derived*, not reviewed. This is
  # the distinction the gate now reads and previously did not.
  DBI::dbWriteTable(con, "series_semantic_evidence", tibble::tibble(
    series_id = "fixture:series",
    field = c("unit_code", "scale_multiplier", "stock_flow", "nominal_real",
              "seasonal_adjustment", "transformation", "valuation"),
    value = c("INDEX", "1", "stock", "real", "not_adjusted", "index", "not_applicable"),
    basis = "published_label",
    evidence = "The published label reads 'Saldo a fin de periodo - Serie Original'.",
    derived_at = Sys.time()
  ), append = TRUE)
  DBI::dbWriteTable(con, "fact_series_events", tibble::tibble(
    series_id = "fixture:series", period = as.Date("2024-01-31"), value = 1,
    vintage_id = "fixture:v1", publication_date = as.Date("2026-02-15"), is_deleted = FALSE,
    source_file = "fixture.xlsx", series_sk = 1L, vintage_sk = 1L
  ), append = TRUE)
  DBI::dbWriteTable(con, "documented_series_snapshot", tibble::tibble(
    vintage_id = "fixture:v1", series_id = "fixture:series", period = as.Date("2024-01-31"),
    source_id = "fixture", source_sheet = "Hoja", value = 1
  ), append = TRUE)
  # An economist has validated the worksheet. That is the only human act the old
  # gate required.
  DBI::dbWriteTable(con, "table_status", tibble::tibble(
    source_id = "fixture", source_sheet = "Hoja", status = "validated",
    reviewed_by = "fixture economist", reviewed_at = as.Date("2026-01-01"),
    evidence_uri = "https://example.invalid/evidence", note = "fixture"
  ), append = TRUE)

  if (reviewed) DBI::dbWriteTable(con, "series_review", tibble::tibble(
    series_id = "fixture:series",
    definition = "Indice de precios al consumidor, nivel general, base diciembre 2020 = 100.",
    definition_evidence_uri = "https://example.invalid/anexo",
    source_semantics = "Hoja, fila 'Nivel general'", frequency = "monthly",
    reference_period_convention = "calendar month, dated at month end",
    timing_basis = "end_of_period", stock_flow = "stock", unit_code = "INDEX",
    scale_multiplier = 1, currency = "PYG", valuation = "not_applicable",
    nominal_real = "real", price_base_year = "2020", seasonal_adjustment = "not_adjusted",
    transformation = "index", hierarchy_role = "total", parent_series_id = NA_character_,
    methodology_regime_id = NA_character_, comparability = "comparable",
    availability_convention = "published within 10 days of month end",
    reviewed_by = "fixture economist", reviewed_at = as.Date("2026-01-01")
  ), append = TRUE)

  publish_test_release(con, release, "accepted")
  create_series_views(con)
  create_semantic_views(con)
  create_domain_views(con)
  create_table_status_views(con)
  create_mart_views(con)
  con
}

testthat::test_that("a validated worksheet alone no longer admits a series to the research surface", {
  con <- review_gate_fixture(reviewed = FALSE)
  # The fixture is not vacuous: the worksheet really is validated, the series
  # really is published, and every eligibility field really is populated.
  testthat::expect_equal(
    DBI::dbGetQuery(con, paste(
      "SELECT count(*) AS n FROM main.v_series_table_status WHERE status = 'validated'"
    ))$n[[1]], 1L
  )
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT count(*) AS n FROM main.v_series_latest")$n[[1]], 1L
  )
  populated <- DBI::dbGetQuery(con, paste0(
    "SELECT count(*) AS n FROM canonical.dim_series WHERE ",
    paste(vapply(RESEARCH_ELIGIBILITY_FIELDS, function(field) paste0(
      field, " IS NOT NULL AND CAST(", field,
      " AS VARCHAR) NOT IN ('not_reviewed', 'UNRESOLVED_SOURCE_UNITS')"
    ), character(1)), collapse = " AND ")
  ))$n[[1]]
  testthat::expect_equal(populated, 1L)

  # And it is still refused, because nobody reviewed the series.
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT count(*) AS n FROM marts.v_research_series")$n[[1]], 0L
  )
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT count(*) AS n FROM marts.v_mart_prices")$n[[1]], 0L
  )
})

testthat::test_that("the review is what admits it", {
  # The other half: without this the test above would pass for any reason at all,
  # including the fixture simply being broken.
  con <- review_gate_fixture(reviewed = TRUE)
  surface <- DBI::dbGetQuery(con, paste(
    "SELECT series_id, reviewed_by, table_reviewed_by FROM marts.v_research_series"
  ))
  testthat::expect_equal(nrow(surface), 1L)
  testthat::expect_equal(surface$series_id, "fixture:series")
  # Both reviews are exposed, and they are distinguishable. The series-level one
  # is the new requirement; the worksheet-level one keeps its own column.
  testthat::expect_equal(surface$reviewed_by, "fixture economist")
  testthat::expect_equal(surface$table_reviewed_by, "fixture economist")
})

testthat::test_that("a review row without reviewed evidence is caught by the gate", {
  # Belt and braces, and they are not the same brace. The view requires a
  # register row; the validator requires the evidence that row is supposed to
  # produce. They diverge exactly when a row reaches the table without going
  # through apply_series_review() -- a hand edit, or a future code path -- and
  # that is the case where "reviewed" would otherwise be a claim with nothing
  # behind it.
  con <- review_gate_fixture(reviewed = TRUE)
  evidence <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM canonical.series_semantic_evidence WHERE basis = 'reviewed'"
  ))$n[[1]]
  testthat::expect_equal(evidence, 0L)

  validate_research_eligibility_metadata(con, "release:review-gate")
  flags <- DBI::dbGetQuery(con, "SELECT severity, check_name, detail FROM audit.quality_flags")
  testthat::expect_true("research_series_evidence_not_reviewed" %in% flags$check_name)
  testthat::expect_equal(
    flags$severity[flags$check_name == "research_series_evidence_not_reviewed"], "error"
  )
  testthat::expect_match(
    flags$detail[flags$check_name == "research_series_evidence_not_reviewed"],
    "derivation from published wording"
  )
  # The older value-shaped check stays quiet, because the values are all present.
  # The two checks are asking different questions and only one of them fires.
  testthat::expect_false("research_series_metadata_incomplete" %in% flags$check_name)
})

testthat::test_that("a complete review satisfies both halves of the gate", {
  # apply_series_review() writes the register row *and* the reviewed evidence, so
  # the supported path clears both. This is the state an economist actually
  # produces, and nothing should fire.
  con <- review_gate_fixture(reviewed = FALSE)
  root <- withr::local_tempdir()
  dir.create(file.path(root, "config"))
  readr::write_csv(tibble::tibble(
    series_id = "fixture:series",
    definition = "Indice de precios al consumidor, nivel general, base diciembre 2020 = 100.",
    definition_evidence_uri = "https://example.invalid/anexo",
    source_semantics = "Hoja, fila 'Nivel general'", frequency = "monthly",
    reference_period_convention = "calendar month, dated at month end",
    timing_basis = "end_of_period", stock_flow = "stock", unit_code = "INDEX",
    scale_multiplier = "1", currency = "PYG", valuation = "not_applicable",
    nominal_real = "real", price_base_year = "2020", seasonal_adjustment = "not_adjusted",
    transformation = "index", hierarchy_role = "total", parent_series_id = "",
    methodology_regime_id = "", comparability = "comparable",
    availability_convention = "published within 10 days of month end",
    reviewed_by = "fixture economist", reviewed_at = "2026-01-01"
  ), file.path(root, "config", "series_review.csv"))

  testthat::expect_equal(apply_series_review(con, root), 1L)
  create_table_status_views(con)
  create_mart_views(con)

  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT count(*) AS n FROM marts.v_research_series")$n[[1]], 1L
  )
  testthat::expect_true(validate_research_eligibility_metadata(con, "release:review-gate"))
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT count(*) AS n FROM audit.quality_flags")$n[[1]], 0L
  )
})
