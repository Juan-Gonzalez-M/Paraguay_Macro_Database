# The seventh audit's F-05 and section 11.3.
#
#   source data rows = accepted rows + rejected rows with an explicit reason
#
# The Excel path has had this at cell grain since the first audit. The CSV path
# parsed with readr::parse_number() -- which takes the first numeric run out of
# whatever string it is handed -- dropped whatever came back NA, and recorded
# nothing, so the only loss it could notice was losing everything.

csv_accounting_fixture <- function(env = parent.frame()) {
  path <- withr::local_tempfile(fileext = ".duckdb", .local_envir = env)
  con <- DBI::dbConnect(duckdb::duckdb(), path)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE), envir = env)
  initialize_database(con, project_test_root)
  con
}

testthat::test_that("a partial numeric token is a rejection, not a number", {
  # readr::parse_number("12abc") is 12. That is the defect: a publisher writing
  # "1.234 mill." or "5 %" would silently become a number of a different
  # magnitude, and nothing anywhere would say so.
  testthat::expect_equal(parse_decimal_comma("12abc"), 12)
  testthat::expect_true(csv_invalid_numeric_token("12abc"))
  testthat::expect_true(csv_invalid_numeric_token("1.2.3"))
  testthat::expect_true(csv_invalid_numeric_token("5 %"))
  testthat::expect_true(csv_invalid_numeric_token("(1,5)"))
  testthat::expect_true(csv_invalid_numeric_token("1,2,3"))

  # And the forms both publishers actually use stay valid, including the
  # thousands grouping neither uses today.
  valid <- c("0,5", "-0,059781507857", "130080000", "+3", "1.234.567,89", "7009634903")
  testthat::expect_false(any(csv_invalid_numeric_token(valid)))

  # Blank is absent, not malformed. They are different publisher acts and get
  # different reasons.
  testthat::expect_false(any(csv_invalid_numeric_token(c(NA, "", "   "))))
  testthat::expect_true(all(csv_blank_token(c(NA, "", "   "))))
})

testthat::test_that("every rejected row carries exactly one reason, the first that applies", {
  # The test list mirrors what the securities parser actually does, which since
  # schema 37 no longer rejects a blank volume: row 5 has one, and it is
  # accepted with a null measure rather than discarded. See
  # test-trade-retention.R for that half.
  raw <- tibble::tibble(
    source_row = 2:6,
    date = c("01/02/2020", "", "03/02/2020", "04/02/2020", "05/02/2020"),
    volume = c("100", "200", "12abc", "", "300"),
    currency = c("PYG", "PYG", "PYG", "PYG", "")
  )
  rejections <- csv_row_rejections(raw, list(
    invalid_date = csv_blank_token(raw$date),
    invalid_numeric_token = csv_invalid_numeric_token(raw$volume),
    missing_mandatory_dimension = csv_blank_token(raw$currency)
  ))
  testthat::expect_equal(nrow(rejections), 3L)
  testthat::expect_equal(rejections$source_row, c(3L, 4L, 6L))
  testthat::expect_equal(rejections$reason, c(
    "invalid_date", "invalid_numeric_token", "missing_mandatory_dimension"
  ))
  # A malformed volume is still a rejection and a blank one is not: "12abc" is a
  # token this parser will not silently reinterpret, while "" is a measure the
  # publisher did not report. Absent and unreadable are different publisher acts.
  testthat::expect_true(5L %in% setdiff(raw$source_row, rejections$source_row))
  # One row, one reason: row 3 is blank-dated, and row 4's malformed volume must
  # not also appear under another heading. A row counted twice breaks the
  # accounting identity as surely as a row counted never.
  testthat::expect_equal(anyDuplicated(rejections$source_row), 0L)
  # And the row survives in a readable form, so a reviewer can find it in the file.
  testthat::expect_match(rejections$raw_label[[2]], "12abc")
})

testthat::test_that("rejections are recorded per vintage and survive re-ingestion", {
  con <- csv_accounting_fixture()
  item <- list(vintage_id = "fixture:v1", source_id = "securities_trades")
  rejections <- tibble::tibble(
    source_row = c(4747L, 29690L), reason = "missing_mandatory_dimension",
    raw_label = c("row a", "row b")
  )
  testthat::expect_equal(record_csv_rejections(con, item, "release:x", rejections), 2L)
  # discard_id is content-addressed, so re-running the same vintage without
  # clearing would abort on the primary key -- the same trap the EVE parser hit.
  testthat::expect_equal(record_csv_rejections(con, item, "release:x", rejections), 2L)
  stored <- DBI::dbGetQuery(con, "SELECT * FROM staging.discarded_rows")
  testthat::expect_equal(nrow(stored), 2L)
  testthat::expect_equal(stored$source_sheet, rep("data", 2))
  testthat::expect_setequal(stored$row_id, c(4747, 29690))

  # A vintage that rejects nothing must leave nothing behind.
  testthat::expect_equal(
    record_csv_rejections(con, item, "release:x", rejections[0, ]), 0L
  )
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT count(*) AS n FROM staging.discarded_rows")$n[[1]], 0L
  )
})

testthat::test_that("the row accounting balances, and says so when it does not", {
  con <- csv_accounting_fixture()
  DBI::dbWriteTable(con, "source_sheets", tibble::tibble(
    vintage_id = "fixture:v1", source_id = "securities_trades", sheet_name = "data",
    content_first_row = 1L, content_last_row = 11L, content_first_col = 1L, content_last_col = 12L
  ), append = TRUE)
  snapshot <- tibble::tibble(
    vintage_id = "fixture:v1", transaction_id = paste0("trade:", 1:8),
    operation_date = as.Date("2020-01-01"), local_currency_volume = 1
  )
  DBI::dbWriteTable(
    con, DBI::Id(schema = "staging", table = "securities_transactions_snapshot"),
    snapshot, append = TRUE
  )
  record_csv_rejections(
    con, list(vintage_id = "fixture:v1", source_id = "securities_trades"), "release:x",
    tibble::tibble(source_row = 5:6, reason = "missing_mandatory_dimension", raw_label = "x")
  )

  # 10 offered = 8 accepted + 2 rejected.
  balanced <- compute_csv_row_reconciliation(con, project_test_root, "release:x")
  row <- balanced[balanced$vintage_id == "fixture:v1", ]
  testthat::expect_equal(nrow(row), 1L)
  testthat::expect_equal(row$numeric_source_cells, 10)
  testthat::expect_equal(row$accepted_observations, 8)
  testthat::expect_equal(row$rejected_observations, 2)
  testthat::expect_equal(row$status, "balanced")
  testthat::expect_equal(row$balance_delta, 0)

  # Remove a rejection record without accepting the row: that is exactly the
  # silent loss this whole check exists to catch, and it must not balance.
  DBI::dbExecute(con, "DELETE FROM staging.discarded_rows WHERE row_id = 5")
  broken <- compute_csv_row_reconciliation(con, project_test_root, "release:x")
  row <- broken[broken$vintage_id == "fixture:v1", ]
  testthat::expect_equal(row$status, "unexplained_cells")
  testthat::expect_equal(row$balance_delta, 1)
  testthat::expect_match(row$note, "neither accepted nor recorded as a rejection")
})

testthat::test_that("an undeclared rejection reason blocks the release", {
  con <- csv_accounting_fixture()
  record_csv_rejections(
    con, list(vintage_id = "fixture:v1", source_id = "securities_trades"), "release:x",
    tibble::tibble(source_row = 9L, reason = "because_i_said_so", raw_label = "x")
  )
  validate_row_rejection_accounting(con, "release:x", project_test_root)
  flags <- DBI::dbGetQuery(con, "SELECT severity, check_name FROM audit.quality_flags")
  testthat::expect_true("row_rejection_reason_undeclared" %in% flags$check_name)
  testthat::expect_equal(
    flags$severity[flags$check_name == "row_rejection_reason_undeclared"], "error"
  )
})

testthat::test_that("the register declares every reason any parser in this project writes", {
  # The first run of this gate blocked the release, and it was right to: the
  # ICC/EVE and FX-operations parsers have written `non_data_note` to
  # discarded_rows since schema 12, under a reason no register described. The
  # audit names the CSV path because that is where rows were vanishing
  # *unrecorded*; the principle was never about CSVs.
  #
  # So the assertion is over the reasons the source actually contains, which is
  # what makes it catch the next parser that invents one.
  # The first attempt at this test grepped the sources for `reason = "..."`. It
  # passed, and it was worthless: the regex missed the ternary in the FX parser
  # and missed the CSV reasons entirely, which are list names rather than string
  # literals. A grep over source is not a vocabulary.
  #
  # So the vocabulary is `ROW_REJECTION_REASONS` in the code, and the register
  # must be exactly it -- checked in both directions by the reader itself.
  register <- read_row_rejection_reasons(project_test_root)
  testthat::expect_setequal(register$reason, ROW_REJECTION_REASONS)
  testthat::expect_true(all(
    c("non_data_note", "unrecognized_period_with_values", "invalid_date",
      "invalid_numeric_token", "missing_mandatory_dimension") %in% ROW_REJECTION_REASONS
  ))
  # And a parser cannot record a reason outside it, which is what makes the
  # register's completeness mean something.
  testthat::expect_error(
    csv_row_rejections(
      tibble::tibble(source_row = 2L, x = "a"), list(because_i_said_so = TRUE)
    ),
    "unsupported reason"
  )
  # A register row without a meaning or a reviewer is not a classification.
  broken <- withr::local_tempdir()
  dir.create(file.path(broken, "config"))
  readr::write_csv(tibble::tibble(
    reason = "x", meaning = "", expected = "expected", reviewed_by = "someone",
    reviewed_at = "2026-09-01"
  ), file.path(broken, "config", "row_rejection_reasons.csv"))
  testthat::expect_error(read_row_rejection_reasons(broken), "no meaning or no reviewer")
})

testthat::test_that("a structurally broken delimited file is refused whole", {
  # Not "filter the bad rows out": a file whose shape disagrees with its contract
  # is not the file the contract describes, and no part of it is accepted.
  path <- withr::local_tempfile(fileext = ".csv")
  writeLines(c("a;b;c", "1;2;3", "4;5;6;7"), path)
  item <- list(path = path, source_id = "fixture", source_file = basename(path),
               vintage_id = "fixture:v1")
  testthat::expect_error(
    read_guarded_delimited(NULL, item, "release:x", c("a", "b", "c")),
    "CSV structure guard"
  )
})
