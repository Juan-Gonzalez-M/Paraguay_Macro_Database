testthat::test_that("vectorized metadata is identical to scalar compatibility results", {
  legacy_metadata <- function(series_label, table_title) {
    local <- normalize_semantic_label(series_label); global <- normalize_semantic_label(table_title)
    local[is.na(local)] <- ""; global[is.na(global)] <- ""; context <- paste(local, global)
    pyg_token <- "pyg|guarani|moneda nacional|(^| )mn($| )|(^| )gs(?:[./ ]|$)|₲"
    currencies <- c(
      PYG = stringr::str_detect(local, pyg_token),
      FX = stringr::str_detect(local, "moneda extranjera|(^| )me($| )"),
      USD = stringr::str_detect(local, "usd|dolar"), EUR = stringr::str_detect(local, "eur|euro")
    )
    if (!any(currencies)) currencies <- c(
      PYG = stringr::str_detect(global, pyg_token),
      FX = stringr::str_detect(global, "moneda extranjera|(^| )me($| )"),
      USD = stringr::str_detect(global, "usd|dolar"), EUR = stringr::str_detect(global, "eur|euro")
    )
    currency <- if (sum(currencies) == 1L) names(currencies)[currencies][[1]] else NA_character_
    unit <- dplyr::case_when(
      stringr::str_detect(local, "cantidad|numero|lotes|operaciones|tarjetas|cheques|dependencias|personal") ~ "count",
      stringr::str_detect(context, "porcentaje|%") ~ "percent",
      stringr::str_detect(context, "veces") ~ "ratio",
      stringr::str_detect(context, "indice|base .{0,40}100") ~ "index",
      stringr::str_detect(local, "plazo.{0,20}dia|dias") ~ "days",
      stringr::str_detect(context, "usd[/ ]?(?:por )?ton|dolar.{0,12}ton") ~ "USD_per_tonne",
      stringr::str_detect(context, "usd[/ ]?(?:por )?barr|dolar.{0,12}barr") ~ "USD_per_barrel",
      stringr::str_detect(context, "tipo de cambio|pyg[/ ]?usd|guarani.{0,20}dolar") ~ "PYG_per_USD",
      stringr::str_detect(context, "toneladas") & stringr::str_detect(context, "kwh") ~ "mixed_physical_units",
      stringr::str_detect(context, "toneladas") ~ "tonnes",
      stringr::str_detect(context, "kwh") ~ "kWh",
      currency %in% c("PYG", "USD", "EUR") ~ currency,
      TRUE ~ "source_units"
    )
    scale <- dplyr::case_when(
      stringr::str_detect(context, "miles (de )?millones") ~ "billions",
      stringr::str_detect(context, "millones") ~ "millions",
      stringr::str_detect(context, "miles") ~ "thousands", TRUE ~ "units"
    )
    if (unit %in% c("index", "percent", "ratio", "count", "days")) scale <- "units"
    if (identical(unit, "PYG_per_USD")) currency <- "PYG/USD"
    base_match <- stringr::str_extract(table_title, stringr::regex("base.{0,50}?100", ignore_case = TRUE))
    tibble::tibble(unit = unit, scale = scale, currency = currency,
                   index_base = ifelse(is.na(base_match), NA_character_, base_match))
  }
  labels <- c(
    "Cantidad de operaciones", "Tasa activa ME (%)", "Índice general",
    "Tipo de cambio Gs./USD", "Soja USD/ton.", "Saldo en millones de guaraníes"
  )
  titles <- c(
    "Operaciones", "Promedio mensual", "Base 2014 = 100",
    "Mercado cambiario", "Precios internacionales", "En millones de guaraníes"
  )
  vectorized <- documented_measure_metadata_vectorized(labels, titles)
  scalar <- dplyr::bind_rows(Map(legacy_metadata, labels, titles))
  testthat::expect_identical(vectorized, scalar)
  testthat::expect_identical(vectorized$scale[vectorized$unit == "index"], "units")
})

testthat::test_that("deferred metadata enrichment preserves explicit parser overrides", {
  records <- documented_bind_records(list(
    documented_add_record(
      list(), 1L, "Sheet", "En millones de guaraníes", "vertical_date",
      as.Date("2025-01-31"), "Jan", "monthly", "Saldo", "Category", "Saldo",
      100, 10L, 3L
    )[[1]],
    documented_add_record(
      list(), 1L, "Sheet", "En miles de dólares", "vertical_date",
      as.Date("2025-01-31"), "Jan", "monthly", "Porcentaje", "Category", "Share",
      0.5, 11L, 3L
    )[[1]]
  ))
  records$unit[[2]] <- "proportion"; records$scale[[2]] <- "units"
  enriched <- documented_enrich_metadata(records)
  testthat::expect_identical(enriched$unit, c("PYG", "proportion"))
  testthat::expect_identical(enriched$scale, c("millions", "units"))
  testthat::expect_identical(enriched$currency, c("PYG", "USD"))
})

testthat::test_that("optimized identity hashing is byte-identical to the identity contract", {
  rows <- documented_bind_records(lapply(1:3, function(month) {
    documented_add_record(
      list(), 1L, "Sheet A", "Title", "vertical_date",
      month_end(2025, month), month, "monthly", "Same series", "Category", "Value",
      month, month + 5L, 4L
    )[[1]]
  })) %>%
    documented_enrich_metadata() %>%
    dplyr::mutate(hierarchy_status = "flat")
  item <- tibble::tibble(source_id = "example", vintage_id = "example:v1", source_file = "example.xlsx")
  result <- documented_finalize_observations(rows, item, "release:test", as.Date("2026-01-31"))
  expected_hash <- substr(digest::digest(
    paste("Category — Same series", "monthly", sep = "|"),
    algo = "sha256", serialize = FALSE
  ), 1L, 24L)
  testthat::expect_identical(unique(result$series_id), paste0("example:sheet_a:", expected_hash))
  testthat::expect_identical(dplyr::n_distinct(result$series_id), 1L)
})

testthat::test_that("vectorized horizontal year-month extraction preserves cell order and values", {
  text <- matrix(NA_character_, nrow = 5L, ncol = 4L)
  text[1, 2:4] <- c("2023", "2024", "2025")
  text[2:4, 1] <- c("Ene", "Feb", "Mar")
  text[1, 1] <- "Monthly indicator"
  numbers <- matrix(NA_real_, nrow = 5L, ncol = 4L)
  numbers[2:4, 2:4] <- matrix(1:9, nrow = 3L, byrow = TRUE)
  result <- documented_extract_horizontal_year_month(text, numbers, "Sheet")
  testthat::expect_equal(nrow(result), 9L)
  testthat::expect_identical(result$value, as.numeric(1:9))
  testthat::expect_identical(result$source_row, rep(2:4, each = 3L))
  testthat::expect_identical(result$source_column, rep(2:4, times = 3L))
  testthat::expect_identical(
    result$period[c(1L, 5L, 9L)],
    as.Date(c("2023-01-31", "2024-02-29", "2025-03-31"))
  )
})

testthat::test_that("schema v9 preserves pipeline timings and ingestion repairs", {
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = ":memory:")
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  initialize_database(con)
  testthat::expect_true(DBI::dbExistsTable(con, "ingestion_stage_timings"))
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM schema_version WHERE version = 9")$n[[1]],
    1
  )
})

testthat::test_that("single-pass semantic reading preserves the v7 raw sheet content hash", {
  files <- list.files(
    file.path(project_test_root, "input", "current", "economic_annex"),
    pattern = "\\.(xlsx|xlsm)$", full.names = TRUE, ignore.case = TRUE
  )
  testthat::expect_length(files, 1L)
  dimensions <- xlsx_sheet_dimensions(files[[1]]) %>%
    dplyr::filter(.data$sheet_name == "CUADRO 1")
  testthat::expect_equal(nrow(dimensions), 1L)
  legacy_crop <- read_sheet_matrix(
    files[[1]], dimensions$sheet_name[[1]], dimensions$used_rows[[1]], dimensions$used_cols[[1]],
    dimensions$content_first_row[[1]], dimensions$content_first_col[[1]],
    dimensions$content_last_row[[1]], dimensions$content_last_col[[1]]
  )
  parser_raw <- read_dimensioned_sheet(files[[1]], dimensions)
  reused_crop <- parser_raw[
    seq.int(dimensions$content_first_row[[1]], dimensions$content_last_row[[1]]),
    seq.int(dimensions$content_first_col[[1]], dimensions$content_last_col[[1]]),
    drop = FALSE
  ]
  legacy_id <- report_sheet_version_id(cells_from_matrix(legacy_crop), "economic_annex", "CUADRO 1")
  reused_id <- report_sheet_version_id(cells_from_matrix(reused_crop), "economic_annex", "CUADRO 1")
  testthat::expect_identical(reused_id, legacy_id)
})
