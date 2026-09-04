# The re-audit's RA2-06: a trade with an unknown volume is still a trade.
#
# Schema 34 stopped three real corporate-bond purchases vanishing and recorded
# them as `missing_mandatory_dimension`. That was right about silent-loss
# detection and wrong as economics. Their date, broker, ISIN, issuer, instrument,
# market, operation type and currency are all present and intact; what is absent
# is one *measure*. Classing the row as unplaceable understates the count of
# corporate-bond purchases, so a reader summing `transactions` in the daily
# activity view got a number wrong by three, for a reason only the rejection
# register explained.
#
# This is the one change in this sequence of rounds that moves a published
# count: 312,326 -> 312,329.

testthat::test_that("a blank volume is not a rejection, and a malformed one still is", {
  # The distinction the parser now draws, at the level of the predicates it
  # actually uses. Absent and unreadable are different publisher acts.
  volumes <- c("130080000", "", "   ", "12abc", "1.2.3", "0")
  testthat::expect_equal(csv_blank_token(volumes), c(FALSE, TRUE, TRUE, FALSE, FALSE, FALSE))
  testthat::expect_equal(
    csv_invalid_numeric_token(volumes), c(FALSE, FALSE, FALSE, TRUE, TRUE, FALSE)
  )
  # A blank is neither a number nor a malformed token: it is the absence of a
  # measure, which is what volume_status records.
  testthat::expect_false(any(csv_blank_token(volumes) & csv_invalid_numeric_token(volumes)))
})

testthat::test_that("the three real blank-volume trades are the ones in the source file", {
  # Not a synthetic fixture: the actual published file, so the count this round
  # changes is anchored to the bytes rather than to an assumption about them.
  path <- file.path(
    project_test_root, "input", "current", "securities_trades", "Negociaciones_Bursatiles.csv"
  )
  testthat::skip_if_not(file.exists(path), "securities source not present")
  raw <- suppressWarnings(readr::read_delim(
    path, delim = ";", col_types = readr::cols(.default = readr::col_character()),
    locale = readr::locale(encoding = "UTF-8"), trim_ws = TRUE, show_col_types = FALSE,
    name_repair = "minimal", progress = FALSE
  ))
  volume <- raw[["Volumen Moneda Local"]]
  blank <- which(csv_blank_token(volume))
  testthat::expect_equal(length(blank), 3L)
  # Source rows, header included, as the rejection register named them.
  testthat::expect_equal(blank + 1L, c(4747L, 29690L, 173494L))

  # Every one of them is a complete trade apart from the measure. This is the
  # whole argument for retaining them, so it is asserted rather than described.
  for (column in c("Fecha Operacion", "Ruc Casa Bolsa", "Isin Identificador", "Ruc Emisor",
                   "Instrumento", "Mercado", "Tipo Operacion", "Moneda")) {
    testthat::expect_false(
      any(csv_blank_token(raw[[column]][blank])),
      info = paste("blank", column, "on a row retained for its other dimensions")
    )
  }
  # And none of them is a malformed token that the parser merely failed to read.
  testthat::expect_false(any(csv_invalid_numeric_token(volume[blank])))
})

testthat::test_that("the retained rows carry a null volume and an explicit status", {
  con <- DBI::dbConnect(duckdb::duckdb(), withr::local_tempfile(fileext = ".duckdb"))
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  initialize_database(con, project_test_root)

  DBI::dbWriteTable(
    con, DBI::Id(schema = "staging", table = "securities_transactions_snapshot"),
    tibble::tibble(
      vintage_id = "fixture:v1", release_id = "release:x",
      publication_date = as.Date("2026-01-31"), source_file = "trades.csv",
      transaction_id = paste0("trade:", 1:3), source_row = c(10L, 11L, 12L),
      operation_date = as.Date("2025-06-01"), broker_tax_id = "1", broker_name = "CBSA",
      isin = "X", issuer_tax_id = "2", issuer_name = "BANCO", instrument = "BONOS",
      market = "SECUNDARIO", operation_type = "COMPRA",
      local_currency_volume = c(100, NA, 300),
      volume_status = c("reported", "not_reported", "reported"),
      currency = "PYG", trading_venue = "ST"
    ), append = TRUE
  )

  stored <- DBI::dbGetQuery(con, paste(
    "SELECT volume_status, count(*) AS rows, count(local_currency_volume) AS with_volume,",
    "sum(local_currency_volume) AS total",
    "FROM staging.securities_transactions_snapshot GROUP BY 1 ORDER BY 1"
  ))
  testthat::expect_equal(stored$volume_status, c("not_reported", "reported"))
  # The count includes the unmeasured trade; the sum does not. Those are the two
  # numbers the daily activity view now reports side by side, and they are
  # supposed to differ.
  testthat::expect_equal(stored$rows, c(1L, 2L))
  testthat::expect_equal(stored$with_volume, c(0L, 2L))
  testthat::expect_equal(stored$total[stored$volume_status == "reported"], 400)
  testthat::expect_true(is.na(stored$total[stored$volume_status == "not_reported"]))

  # A null volume must always say so. The declared required set carries
  # volume_status precisely so an absent measure is a statement rather than a
  # silence a reader has to interpret.
  testthat::expect_true(
    "volume_status" %in% STAGING_NATURAL_KEYS$securities_transactions_snapshot$required
  )
  testthat::expect_false(
    "local_currency_volume" %in% STAGING_NATURAL_KEYS$securities_transactions_snapshot$required
  )
})

testthat::test_that("the daily activity view separates the two denominators", {
  con <- DBI::dbConnect(duckdb::duckdb(), withr::local_tempfile(fileext = ".duckdb"))
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  initialize_database(con, project_test_root)
  release <- "release:trades"

  DBI::dbWriteTable(con, "release_sources", tibble::tibble(
    release_id = release, source_id = "securities_trades", vintage_id = "fixture:v1"
  ), append = TRUE)
  DBI::dbWriteTable(con, "source_files", tibble::tibble(
    vintage_id = "fixture:v1", first_ingested_release_id = release,
    source_id = "securities_trades", source_label = "Trades", publisher = "BVA",
    source_format = "csv", source_file = "trades.csv", source_path = NA_character_,
    archive_path = NA_character_, sha256 = "aa", size_bytes = 1,
    publication_date = as.Date("2026-01-31"), publication_date_source = "content",
    first_ingested_at = Sys.time(), ingestion_status = "completed", vintage_sk = 1L
  ), append = TRUE)
  DBI::dbWriteTable(
    con, DBI::Id(schema = "staging", table = "securities_transactions_snapshot"),
    tibble::tibble(
      vintage_id = "fixture:v1", release_id = release,
      publication_date = as.Date("2026-01-31"), source_file = "trades.csv",
      transaction_id = paste0("trade:", 1:3), source_row = c(10L, 11L, 12L),
      operation_date = as.Date("2025-06-01"), broker_tax_id = "1", broker_name = "CBSA",
      isin = "X", issuer_tax_id = "2", issuer_name = "BANCO", instrument = "BONOS",
      market = "SECUNDARIO", operation_type = "COMPRA",
      local_currency_volume = c(100, NA, 300),
      volume_status = c("reported", "not_reported", "reported"),
      currency = "PYG", trading_venue = "ST"
    ), append = TRUE
  )
  publish_test_release(con, release, "accepted")
  create_market_views(con)

  daily <- DBI::dbGetQuery(con, paste(
    "SELECT transactions, transactions_with_volume, local_currency_volume",
    "FROM main.v_securities_daily_activity"
  ))
  testthat::expect_equal(nrow(daily), 1L)
  # Three trades happened; two of them report a size. Before this round the
  # first number would have been 2 and the difference would have been invisible.
  testthat::expect_equal(daily$transactions, 3L)
  testthat::expect_equal(daily$transactions_with_volume, 2L)
  testthat::expect_equal(daily$local_currency_volume, 400)
})

testthat::test_that("the rejection register no longer claims these rows are rejected", {
  # The register's text named the three rows by source row. Retaining them makes
  # that sentence false, and a register that describes behaviour the code no
  # longer has is the drift this project keeps repairing.
  register <- read_row_rejection_reasons(project_test_root)
  meaning <- register$meaning[register$reason == "missing_mandatory_dimension"]
  testthat::expect_length(meaning, 1L)
  testthat::expect_false(grepl("4747", meaning, fixed = TRUE))
  testthat::expect_match(meaning, "volume_status")
  # The reason itself survives, because a blank currency or instrument still uses it.
  testthat::expect_true("missing_mandatory_dimension" %in% ROW_REJECTION_REASONS)
})
