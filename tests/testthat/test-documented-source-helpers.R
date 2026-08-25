testthat::test_that("documented period helpers preserve shapes and Spanish labels", {
  labels <- matrix(c("2019", "2020", "Ene", "Dic", "1ER TRIM", "IV"), nrow = 2)
  years <- documented_year_values(labels)
  months <- documented_month_number(labels)
  quarters <- documented_quarter_number(labels)
  testthat::expect_identical(dim(years), dim(labels))
  testthat::expect_identical(dim(months), dim(labels))
  testthat::expect_identical(dim(quarters), dim(labels))
  testthat::expect_true(all(c(2019L, 2020L) %in% years))
  testthat::expect_true(all(c(1L, 12L) %in% months))
  testthat::expect_true(all(c(1L, 4L) %in% quarters))
  testthat::expect_identical(documented_frequency(as.Date(c("2026-07-01", "2026-07-02", "2026-07-06"))), "daily")
  raw <- tibble::tibble(a = list("ENE-11", "FEB-11"))
  text <- documented_text_matrix(raw)
  testthat::expect_equal(
    as.Date(documented_date_matrix(raw, text)[, 1]),
    as.Date(c("2011-01-31", "2011-02-28"))
  )
})

testthat::test_that("documented orientation classification covers recurring layouts", {
  horizontal <- matrix(NA_character_, nrow = 5, ncol = 6)
  horizontal[2, 2:6] <- as.character(2020:2024)
  horizontal[3, 1] <- "Series"
  horizontal[3, 2:6] <- as.character(1:5)
  no_dates <- matrix(as.Date(NA), nrow = 5, ncol = 6)
  testthat::expect_identical(documented_mode(horizontal, no_dates, "Example"), "horizontal_year")

  vertical <- matrix(NA_character_, nrow = 6, ncol = 3)
  vertical[2:6, 1] <- as.character(2020:2024)
  vertical[2:6, 2] <- c("Ene", "Feb", "Mar", "Abr", "May")
  testthat::expect_identical(documented_mode(vertical, no_dates, "Example"), "vertical_block")
})

testthat::test_that("documented unit metadata preserves compound economic units", {
  price <- documented_measure_metadata_single("Soja — USD/ton.", "Precios internacionales")
  fx <- documented_measure_metadata_single("Tipo de cambio Gs./USD", "Mercado cambiario")
  testthat::expect_identical(price$unit, "USD_per_tonne")
  testthat::expect_identical(price$currency, "USD")
  testthat::expect_identical(fx$unit, "PYG_per_USD")
  testthat::expect_identical(fx$currency, "PYG/USD")
  foreign_rate <- documented_measure_metadata_single("ME — Tasa activa", "Promedio mensual en porcentajes anuales")
  testthat::expect_identical(foreign_rate$unit, "percent")
  testthat::expect_identical(foreign_rate$currency, "FX")
})

testthat::test_that("bounded anchor lookup disambiguates repeated labels", {
  cells <- tibble::tibble(a = c("Año", NA, "Año"), b = c(NA, "value", NA))
  testthat::expect_error(find_anchor_cell(cells, "Año", 3L, 2L), "expected one anchor")
  first <- find_anchor_cell(cells, "Año", 2L, 2L)
  second <- find_anchor_cell(cells, "Año", 3L, 2L, occurrence = 2L)
  testthat::expect_equal(unname(first), c(1, 1))
  testthat::expect_equal(unname(second), c(3, 1))
})

testthat::test_that("concept synchronization never asserts cross-source equivalence", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  initialize_database(con)
  DBI::dbWriteTable(con, "dim_series", tibble::tibble(
    series_id = c("a:x", "b:x"), source_id = c("a", "b"), label = c("X", "X"),
    unit = "index", scale = "units", frequency = "monthly", currency = NA_character_,
    index_base = NA_character_, hierarchy_level = "indicator", parent_series_id = NA_character_,
    is_total = FALSE, identity_basis = c("a|x", "b|x"), identity_stability = "semantic",
    hierarchy_status = "flat", semantic_status = "curated", first_vintage_id = c("a:v", "b:v")
  ), append = TRUE)
  sync_source_specific_concepts(con)
  mappings <- DBI::dbGetQuery(con, "SELECT * FROM map_series_concept ORDER BY series_id")
  testthat::expect_equal(nrow(mappings), 2L)
  testthat::expect_equal(length(unique(mappings$concept_id)), 2L)
  testthat::expect_true(all(mappings$mapping_status == "source_specific_unreviewed"))
})

testthat::test_that("reviewed concept mappings are exercised with synthetic evidence", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  initialize_database(con)
  series <- tibble::tibble(
    series_id = c("source_a:test", "source_b:test"), source_id = c("source_a", "source_b"),
    label = c("Synthetic A", "Synthetic B"), unit = "index", scale = "units", frequency = "monthly",
    currency = NA_character_, index_base = "2020=100", hierarchy_level = "indicator",
    parent_series_id = NA_character_, is_total = FALSE, identity_basis = c("a|test", "b|test"),
    identity_stability = "semantic", hierarchy_status = "flat", semantic_status = "curated",
    first_vintage_id = c("source_a:v1", "source_b:v1")
  )
  DBI::dbWriteTable(con, "dim_series", series, append = TRUE)
  fixture_root <- tempfile("concept_fixture_"); dir.create(file.path(fixture_root, "config"), recursive = TRUE)
  readr::write_csv(tibble::tibble(
    concept_id = "concept:test:synthetic", concept_label = "Synthetic reviewed concept",
    concept_domain = "test", definition = "Test-only mapping used to exercise reviewed governance.",
    series_id = series$series_id, relationship = "equivalent",
    evidence = "Synthetic fixture; not a production semantic assertion.", reviewed_by = "automated_test",
    reviewed_at = "2026-08-23"
  ), file.path(fixture_root, "config", "concept_mappings.csv"))
  testthat::expect_equal(apply_reviewed_concept_mappings(con, fixture_root), 2L)
  reviewed <- DBI::dbGetQuery(con, "SELECT * FROM map_series_concept WHERE mapping_status = 'reviewed'")
  testthat::expect_equal(nrow(reviewed), 2L)
  testthat::expect_equal(dplyr::n_distinct(reviewed$concept_id), 1L)
})

testthat::test_that("documented series identity excludes inferred unit and currency", {
  base <- documented_bind_records(list(documented_add_record(
    list(), 1L, "Sheet", "Title", "horizontal_year", as.Date("2025-12-31"),
    "2025", "annual", "Same series", "Category", "Measure", 1, 8L, 4L
  )[[1]])) %>% dplyr::mutate(hierarchy_status = "flat")
  item <- tibble::tibble(
    source_id = "example", vintage_id = "example:v1", source_file = "example.xlsx"
  )
  first <- documented_finalize_observations(
    base %>% dplyr::mutate(unit = "PYG", scale = "millions", currency = "PYG"),
    item, "release:one", as.Date("2026-01-31")
  )
  second <- documented_finalize_observations(
    base %>% dplyr::mutate(unit = "source_units", scale = "units", currency = NA_character_),
    item, "release:two", as.Date("2026-02-28")
  )
  testthat::expect_identical(first$series_id, second$series_id)
  testthat::expect_identical(first$identity_basis, second$identity_basis)
})

testthat::test_that("positional collision identities are explicit", {
  rows <- documented_bind_records(list(
    documented_add_record(list(), 1L, "Sheet", "Title", "vertical_date", as.Date("2025-01-31"),
                          "Jan", "monthly", "Amount", "Category", "Amount", 1, 7L, 2L)[[1]],
    documented_add_record(list(), 1L, "Sheet", "Title", "vertical_date", as.Date("2025-01-31"),
                          "Jan", "monthly", "Amount", "Category", "Amount", 2, 7L, 3L)[[1]]
  )) %>% dplyr::mutate(hierarchy_status = "unresolved")
  item <- tibble::tibble(source_id = "example", vintage_id = "example:v1", source_file = "example.xlsx")
  result <- documented_finalize_observations(rows, item, "release:one", as.Date("2026-01-31"))
  testthat::expect_true(all(result$identity_stability == "positional"))
  testthat::expect_equal(dplyr::n_distinct(result$series_id), 2L)
})

testthat::test_that("non-monetary measures cannot inherit monetary scale", {
  index <- documented_measure_metadata_single("Índice general", "En millones de guaraníes")
  share <- documented_measure_metadata_single("Porcentaje", "En miles de dólares")
  testthat::expect_identical(index$scale, "units")
  testthat::expect_identical(share$scale, "units")
})

testthat::test_that("sheet-specific parser exceptions live in configuration", {
  rule <- documented_sheet_rule(project_test_root, "economic_annex", "CUADRO 57a")
  testthat::expect_identical(rule$parser_mode_override, "horizontal_year_month")
  testthat::expect_identical(rule$hierarchy_status, "unresolved")
})

testthat::test_that("series continuity detects identity loss and metadata drift", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  initialize_database(con)
  DBI::dbExecute(con, paste(
    "INSERT INTO source_files (vintage_id, source_id, publication_date, first_ingested_at, ingestion_status)",
    "VALUES ('prior:v', 'credit_survey', DATE '2026-03-31', current_timestamp, 'completed'),",
    "('current:v', 'credit_survey', DATE '2026-06-30', current_timestamp, 'started')"
  ))
  for (i in 1:5) DBI::dbExecute(con, paste0(
    "INSERT INTO documented_series_snapshot ",
    "(vintage_id, source_id, source_sheet, series_id, series_label, unit, scale, currency, identity_stability, period, value) VALUES ",
    "('prior:v','credit_survey','Índices','series:", i, "','Series ", i,
    "','index','units',NULL,'semantic',DATE '2026-03-31',", i, ")"
  ))
  DBI::dbExecute(con, paste(
    "INSERT INTO documented_series_snapshot",
    "(vintage_id, source_id, source_sheet, series_id, series_label, unit, scale, currency, identity_stability, period, value)",
    "VALUES ('current:v','credit_survey','Índices','series:1','Series 1','percent','units',NULL,'semantic',DATE '2026-06-30',1)"
  ))
  item <- tibble::tibble(source_id = "credit_survey", vintage_id = "current:v")
  condition <- tryCatch(
    validate_documented_series_continuity(con, item, "release:test", project_test_root),
    documented_continuity_error = identity
  )
  testthat::expect_s3_class(condition, "documented_continuity_error")
  testthat::expect_equal(sum(condition$changes$change_type == "disappeared"), 4L)
  testthat::expect_equal(sum(condition$changes$change_type == "metadata_changed"), 1L)
  testthat::expect_true(all(c("documented_series_identity_break", "documented_series_metadata_changed") %in%
                              condition$quality_records$check_name))
})
