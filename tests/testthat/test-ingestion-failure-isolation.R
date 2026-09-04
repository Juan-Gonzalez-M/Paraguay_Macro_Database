testthat::test_that("named-table XML includes the root table element", {
  path <- fs::dir_ls(
    file.path(project_test_root, "input", "current", "bank_reference"),
    regexp = "\\.xlsx$"
  )[[1]]
  catalog <- xlsx_named_table_catalog(path)
  testthat::expect_equal(nrow(catalog), 15L)
  testthat::expect_false(any(is.na(catalog$source_table)))
  testthat::expect_false(any(is.na(catalog$table_range)))
  testthat::expect_true(all(nzchar(catalog$observed_columns)))
})

testthat::test_that("empty formula views retain the raw-cell schema", {
  cells <- cells_from_matrix(tibble::tibble(
    a = as.list(rep(NA, 3L)), b = as.list(rep(NA, 3L))
  ))
  testthat::expect_named(cells, c(
    "row_id", "column_id", "raw_value_text", "raw_value_num", "raw_value_date"
  ))
  testthat::expect_equal(nrow(cells), 0L)
  testthat::expect_match(
    report_sheet_version_id(cells, "exchange_houses", "linked view"),
    "^report_sheet:"
  )
})

testthat::test_that("matrix predicates preserve row and column coordinates", {
  values <- matrix(c("x", "enero/2020", "y", "meses"), nrow = 2L)
  detected <- matrix_detect(values, "enero")
  testthat::expect_identical(dim(detected), dim(values))
  hit <- which(detected, arr.ind = TRUE)
  testthat::expect_equal(unname(hit[1, ]), c(2L, 1L))
  testthat::expect_identical(dim(matrix_equal(values, "meses")), dim(values))
})

testthat::test_that("Spanish month aliases and explicit quarter tokens are conservative", {
  testthat::expect_identical(documented_month_number("set"), 9L)
  testthat::expect_true(all(is.na(documented_quarter_number(as.character(1:4)))))
  testthat::expect_identical(
    documented_quarter_number(c("T1", "T2do", "3er trime", "4to trimestre", "IV")),
    c(1L, 2L, 3L, 4L, 4L)
  )
  testthat::expect_identical(
    documented_contextual_quarters(
      c("3", "II", "III", "IV", "1997"), c(1997L, NA, NA, NA, NA)
    ),
    c(1L, 2L, 3L, 4L, NA_integer_)
  )
})

testthat::test_that("credit subquestions become distinct semantic series", {
  path <- fs::dir_ls(
    file.path(project_test_root, "input", "current", "credit_survey"),
    regexp = "\\.xlsx$"
  )[[1]]
  dimension <- xlsx_sheet_dimensions(path) %>% dplyr::filter(.data$sheet_name == "%")
  result <- documented_parse_credit_sheet(read_dimensioned_sheet(path, dimension), "%")
  testthat::expect_true(any(stringr::str_detect(result$observations$question, "^10,1\\s*-")))
  finalized <- documented_finalize_observations(
    result$observations %>% dplyr::mutate(hierarchy_status = "flat"),
    tibble::tibble(source_id = "credit_survey", vintage_id = "credit:test", source_file = basename(path)),
    "release:test", max(result$observations$period)
  )
  testthat::expect_equal(
    nrow(finalized),
    dplyr::n_distinct(paste(finalized$series_id, finalized$period))
  )
})

testthat::test_that("published direct-investment quarter blocks have unique periods", {
  path <- fs::dir_ls(
    file.path(project_test_root, "input", "current", "direct_investment"),
    regexp = "\\.xlsx$"
  )[[1]]
  dimension <- xlsx_sheet_dimensions(path) %>% dplyr::filter(.data$sheet_name == "Cuadro 2")
  result <- documented_extract_generic_sheet(read_dimensioned_sheet(path, dimension), "Cuadro 2")
  finalized <- documented_finalize_observations(
    documented_enrich_metadata(result$observations) %>%
      dplyr::mutate(hierarchy_status = result$hierarchy_status),
    tibble::tibble(source_id = "direct_investment", vintage_id = "id:test", source_file = basename(path)),
    "release:test", max(result$observations$period)
  )
  testthat::expect_true(all(c("quarterly", "annual") %in% finalized$frequency))
  testthat::expect_false(any(stringr::str_detect(finalized$series_path, "81568553")))
  testthat::expect_true(as.Date("1995-12-31") %in% finalized$period)
  testthat::expect_equal(
    nrow(finalized), dplyr::n_distinct(paste(finalized$series_id, finalized$period))
  )
})

testthat::test_that("row-event parsers retain legitimate same-day operations", {
  specifications <- list(
    list("interbank_market", "Mdo Secundario", "fecha negociacion",
         c("^tipo de instrumento$", "^plazo residual"), "secondary_market_operation", NULL),
    list("lrm_auctions", "Subastas 2026", "fecha subasta",
         c("plazos estandarizados", "plazos residuales"),
         "lrm_auction_tenor", NULL),
    list("liquidity_facility", "ADM- LIQ- DEPOSITO", "fecha de liquidacion",
         c("^plazos"),
         "short_term_liquidity_auction", c(deposito = "deposit", repo = "repo"))
  )
  for (spec in specifications) {
    source_id <- spec[[1]]; sheet <- spec[[2]]
    path <- fs::dir_ls(
      file.path(project_test_root, "input", "current", source_id),
      regexp = "\\.(xlsx|xlsm)$"
    )[[1]]
    dimension <- xlsx_sheet_dimensions(path) %>% dplyr::filter(.data$sheet_name == sheet)
    result <- documented_parse_row_events(
      read_dimensioned_sheet(path, dimension), sheet, spec[[3]], spec[[4]], spec[[5]],
      block_patterns = spec[[6]]
    )
    finalized <- documented_finalize_observations(
      documented_enrich_metadata(result$observations, result$observations$measure) %>%
        dplyr::mutate(hierarchy_status = "flat"),
      tibble::tibble(source_id = source_id, vintage_id = paste0(source_id, ":test"), source_file = basename(path)),
      "release:test", max(result$observations$period)
    )
    testthat::expect_true(nrow(finalized) > 0L, info = source_id)
    testthat::expect_equal(
      nrow(finalized), dplyr::n_distinct(paste(finalized$series_id, finalized$period)),
      info = source_id
    )
  }
})

testthat::test_that("row-event identity is invariant to revised measures", {
  fixture <- function(amounts, rates) tibble::tibble(
    date = list("Fecha Negociación", as.Date("2026-01-02"), as.Date("2026-01-02")),
    instrument = list("Tipo de Instrumento", "LRM", "LRM"),
    amount = list("Monto", amounts[[1]], amounts[[2]]),
    rate = list("Tasa (%)", rates[[1]], rates[[2]]),
    tenor = list("Plazo residual (días)", 30, 30)
  )
  parse <- function(raw, vintage) {
    result <- documented_parse_row_events(
      raw, "Events", "fecha negociacion",
      c("^tipo de instrumento$", "^plazo residual"), "test_event"
    )
    documented_finalize_observations(
      documented_enrich_metadata(result$observations, result$observations$measure) %>%
        dplyr::mutate(hierarchy_status = "flat"),
      tibble::tibble(source_id = "events", vintage_id = vintage, source_file = "events.xlsx"),
      "release:test", as.Date("2026-01-02")
    )
  }
  first <- parse(fixture(c(100, 200), c(5, 5.1)), "events:v1")
  revised <- parse(fixture(c(110, 210), c(5.05, 5.15)), "events:v2")
  testthat::expect_setequal(first$series_id, revised$series_id)
  testthat::expect_true(all(first$identity_stability == "positional_lane"))
  testthat::expect_false(any(stringr::str_detect(first$identity_basis, "100|200|5[.]1")))
})

testthat::test_that("a discovery failure is persisted without losing the next source", {
  root <- tempfile("v9_isolation_")
  dir.create(root); ensure_dirs(root)
  file.copy(file.path(project_test_root, "config"), root, recursive = TRUE)
  # This test's manifest is deliberately narrowed to two sources to isolate
  # discovery-failure behavior -- unrelated to concept governance. Reset the
  # copied concept_mappings.csv to empty so a real reviewed mapping that
  # references a series from a source outside this narrow manifest (e.g.
  # interbank_market) doesn't fail apply_reviewed_concept_mappings()'s
  # unknown-series-id guard, which is correctly strict for production.
  writeLines(
    "concept_id,concept_label,concept_domain,definition,series_id,relationship,evidence,reviewed_by,reviewed_at",
    file.path(root, "config", "concept_mappings.csv")
  )
  bad <- file.path(root, "broken.xlsx")
  writeLines("not an xlsx archive", bad)
  good <- fs::dir_ls(
    file.path(project_test_root, "input", "current", "bank_reference"),
    regexp = "\\.xlsx$"
  )[[1]]
  make_item <- function(source_id, label, format, mode, path) {
    sha <- file_sha256(path)
    tibble::tibble(
      source_id = source_id, source_label = label, publisher = "BCP",
      source_format = format, ingest_mode = mode, semantic_status = "curated",
      path = path, source_file = basename(path), sha256 = sha,
      vintage_id = make_vintage_id(source_id, sha)
    )
  }
  manifest <- dplyr::bind_rows(
    make_item("exchange_rates", "Broken workbook", "xlsx", "semantic_table", bad),
    make_item("bank_reference", "Bank reference", "xlsx", "reference", good)
  )
  db_path <- file.path(root, "database", "isolation.duckdb")
  testthat::expect_no_error(run_manifest_pipeline(root, tibble::tibble(), manifest, db_path = db_path))
  con <- connect_project_database(db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  statuses <- DBI::dbGetQuery(con, "SELECT source_id, ingestion_status FROM source_files")
  testthat::expect_identical(
    statuses$ingestion_status[statuses$source_id == "exchange_rates"],
    "failed_structure_or_ingestion"
  )
  testthat::expect_identical(
    statuses$ingestion_status[statuses$source_id == "bank_reference"], "completed"
  )
})
