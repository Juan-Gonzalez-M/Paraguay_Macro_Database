testthat::test_that("the full real-workbook pipeline completes with plausible outputs", {
  smoke_root <- tempfile("paraguay_macro_smoke_")
  dir.create(smoke_root)
  testthat::expect_true(file.copy(file.path(project_test_root, "config"), smoke_root, recursive = TRUE))
  testthat::expect_true(file.copy(file.path(project_test_root, "input"), smoke_root, recursive = TRUE))
  ensure_dirs(smoke_root)
  # The real CDA file deliberately has no invented acquisition metadata and a
  # production candidate must therefore block. This smoke test exercises the
  # downstream accepted-release interfaces, so give only its private copied
  # config an explicit synthetic provenance record. Nothing here is written to
  # the project registry or presented as publisher evidence.
  vintage_path <- file.path(smoke_root, "config", "source_vintages.csv")
  vintages <- readr::read_csv(
    vintage_path, show_col_types = FALSE,
    col_types = readr::cols(.default = readr::col_character())
  )
  cda_path <- file.path(smoke_root, "input", "current", "Curva_CDA.xlsx")
  vintages <- dplyr::bind_rows(vintages, tibble::tibble(
    source_id = "cda_curve", sha256 = file_sha256(cda_path),
    original_filename = "Curva_CDA.xlsx", official_release_date = "2026-08-01",
    official_url = "https://example.invalid/cda-test-fixture",
    release_identifier = "test-fixture-cda-2026-07", retrieved_at = "2026-08-01T00:00:00Z",
    retrieval_method = "test_fixture", availability_quality = "retrieval_time",
    license = "test_fixture", evidence = "Synthetic provenance confined to the full-pipeline smoke test."
  ))
  tcn_path <- file.path(smoke_root, "input", "current", "TCN_Referencial_Diario.xlsx")
  vintages <- dplyr::bind_rows(vintages, tibble::tibble(
    source_id = "tcn_referential_daily", sha256 = file_sha256(tcn_path),
    original_filename = "TCN_Referencial_Diario.xlsx", official_release_date = "2026-08-26",
    official_url = "https://example.invalid/tcn-test-fixture",
    release_identifier = "test-fixture-tcn-2026-08", retrieved_at = "2026-08-26T00:00:00Z",
    retrieval_method = "test_fixture", availability_quality = "retrieval_time",
    license = "test_fixture", evidence = "Synthetic provenance confined to the full-pipeline smoke test."
  ))
  readr::write_csv(vintages, vintage_path)
  registry <- readr::read_csv(file.path(smoke_root, "config", "source_registry.csv"), show_col_types = FALSE)
  resolved <- build_current_manifest(registry, smoke_root)
  expected_sources <- registry %>% dplyr::filter(.data$required) %>% dplyr::pull(.data$source_id)
  testthat::expect_setequal(resolved$manifest$source_id, expected_sources)
  testthat::expect_equal(nrow(resolved$manifest), length(expected_sources))
  db_path <- file.path(smoke_root, "database", "smoke.duckdb")
  result <- run_manifest_pipeline(smoke_root, registry, resolved$manifest, resolved$issues, db_path)
  testthat::expect_false(result$status == "completed_with_errors")
  con <- connect_project_database(db_path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  failed <- DBI::dbGetQuery(con, "SELECT * FROM source_files WHERE ingestion_status <> 'completed'")
  testthat::expect_equal(nrow(failed), 0)
  date_range <- DBI::dbGetQuery(con, "SELECT min(period) AS minimum, max(period) AS maximum FROM fact_series_events")
  testthat::expect_gte(as.Date(date_range$minimum[[1]]), as.Date("1900-01-01"))
  testthat::expect_lte(as.Date(date_range$maximum[[1]]), Sys.Date() + 1000L)
  bank_data_rows <- DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM raw_banks_eeff")$n[[1]]
  bank_sheet <- DBI::dbGetQuery(con, paste0(
    "SELECT content_first_row, content_last_row FROM source_sheets ",
    "WHERE source_id = 'banks' AND sheet_name = 'EEFF'"
  ))
  testthat::expect_gt(bank_data_rows, 200000)
  testthat::expect_equal(
    bank_data_rows,
    bank_sheet$content_last_row[[1]] - bank_sheet$content_first_row[[1]]
  )
  testthat::expect_gt(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM raw_financial_eeff")$n[[1]], 50000)
  testthat::expect_gte(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM consumer_confidence_snapshot")$n[[1]], 1236)
  testthat::expect_gte(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM eve_expectations_snapshot")$n[[1]], 2760)
  testthat::expect_gte(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM fx_operations_snapshot")$n[[1]], 5480)
  testthat::expect_gt(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM v_banks_eeff_documented WHERE entity_id IS NOT NULL")$n[[1]], 100000)
  contracts <- readr::read_csv(file.path(smoke_root, "config", "documented_source_contracts.csv"), show_col_types = FALSE)
  documented_dates <- DBI::dbGetQuery(con, paste0(
    "SELECT source_id, min(period) AS first_period, max(period) AS last_period ",
    "FROM documented_series_snapshot GROUP BY 1"
  )) %>% dplyr::left_join(
    contracts %>% dplyr::select("source_id", "minimum_date", "maximum_future_days"),
    by = "source_id"
  )
  testthat::expect_true(all(as.Date(documented_dates$first_period) >= as.Date(documented_dates$minimum_date)))
  testthat::expect_true(all(as.Date(documented_dates$last_period) <= Sys.Date() + documented_dates$maximum_future_days))
  observed_documented <- DBI::dbGetQuery(con, paste0(
    "SELECT source_id, COUNT(*) AS observations, COUNT(DISTINCT source_sheet) AS parsed_sheets ",
    "FROM documented_series_snapshot GROUP BY 1"
  ))
  documented_check <- contracts %>% dplyr::left_join(observed_documented, by = "source_id")
  testthat::expect_true(all(documented_check$observations >= documented_check$minimum_observations))
  testthat::expect_true(all(documented_check$parsed_sheets >= documented_check$minimum_parsed_sheets))
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM semantic_coverage WHERE semantic_status = 'inventory_only'")$n[[1]], 0)
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM dim_series s LEFT JOIN map_series_concept m USING (series_id) WHERE m.series_id IS NULL")$n[[1]],
    0
  )
  testthat::expect_gt(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM v_economic_annex_latest WHERE source_sheet = 'CUADRO 9' AND frequency = 'monthly' AND unit = 'index'")$n[[1]], 0)
  testthat::expect_equal(as.Date(DBI::dbGetQuery(con, "SELECT min(period) d FROM v_economic_annex_latest WHERE source_sheet = 'CUADRO 8'")$d[[1]]), as.Date("1950-12-31"))

  # Known-truth counts from CLAUDE.md, verified independently against the July/
  # August 2026 publication. These are exact, not minimums, because this test
  # always runs against the same 22 real input files copied above -- a change
  # in these numbers means the input files changed, which is exactly what this
  # is meant to catch. If a legitimately newer publication is dropped into
  # input/current/, update the numbers here alongside CLAUDE.md's table, not
  # the other way around.
  known_truth_coverage <- DBI::dbGetQuery(con, paste0(
    "SELECT source_id, COUNT(DISTINCT source_sheet) AS sheets, SUM(raw_nonempty_cells) AS cells ",
    "FROM semantic_coverage WHERE source_id IN ('economic_annex', 'payments', 'exchange_houses') GROUP BY 1"
  ))
  known_truth <- tibble::tribble(
    ~source_id,         ~sheets, ~cells,
    "economic_annex",   94L,     700262L,
    "payments",         40L,     57683L,
    "exchange_houses",  10L,     6164L
  )
  known_truth_check <- known_truth %>% dplyr::left_join(known_truth_coverage, by = "source_id", suffix = c("_expected", "_observed"))
  testthat::expect_equal(known_truth_check$sheets_observed, known_truth_check$sheets_expected)
  testthat::expect_equal(known_truth_check$cells_observed, known_truth_check$cells_expected)
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(DISTINCT sheet_name) n FROM source_sheets WHERE source_id = 'banks'")$n[[1]], 9L)
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(DISTINCT sheet_name) n FROM source_sheets WHERE source_id = 'financial'")$n[[1]], 8L)
  # dim_entity is a cumulative reference dimension (every code ever registered
  # in the bank/finance reference workbook) -- it is larger than, and not the
  # same question as, "how many entity codes report data in this specific
  # publication". CLAUDE.md's 20/9 counts are the latter; query the raw panel.
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(DISTINCT codigo_entidad) n FROM raw_banks_eeff")$n[[1]], 20L)
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(DISTINCT codigo_entidad) n FROM raw_financial_eeff")$n[[1]], 9L)
  annex_58 <- DBI::dbGetQuery(con, paste0(
    "SELECT min(period) AS first_period, max(period) AS last_period ",
    "FROM v_economic_annex_latest WHERE source_sheet = 'CUADRO 58'"
  ))
  testthat::expect_equal(as.Date(annex_58$first_period[[1]]), as.Date("2008-01-31"))
  testthat::expect_equal(as.Date(annex_58$last_period[[1]]), as.Date("2026-12-31"))
  testthat::expect_gt(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM v_payments_latest")$n[[1]], 40000)
  testthat::expect_gt(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM v_exchange_houses_latest WHERE entity_id IS NOT NULL AND exchange_item_id IS NOT NULL")$n[[1]], 4000)
  testthat::expect_gt(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM v_credit_survey_latest WHERE question IS NOT NULL AND response IS NOT NULL")$n[[1]], 10000)
  testthat::expect_gte(DBI::dbGetQuery(con, "SELECT COUNT(DISTINCT currency) n FROM documented_series_snapshot WHERE source_id = 'exchange_rates' AND source_sheet = 'Cotizaciones Diarias'")$n[[1]], 14)

  # Target cardinalities from the external technical audit, section 10. These
  # are exact: each one is a repaired identity defect, and any drift means a
  # parser or the identity rule regressed. Before the repairs the same queries
  # returned 36, 2760, 168, 170 and 2534.
  audit_series_count <- function(source_id) DBI::dbGetQuery(con, paste0(
    "SELECT COUNT(*) n FROM dim_series WHERE source_id = ", sql_string(source_id)
  ))$n[[1]]
  testthat::expect_equal(audit_series_count("compensatory_fx_sales"), 3L)
  testthat::expect_equal(audit_series_count("eve"), 16L)
  testthat::expect_equal(audit_series_count("bcp_fx_daily"), 12L)
  testthat::expect_equal(audit_series_count("fx_operations"), 30L)
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT COUNT(DISTINCT series_id) n FROM eve_expectations_snapshot")$n[[1]],
    16L
  )
  # 170 monthly identities (2 sides x 5 institutions x 17 breakdowns) plus the
  # 6 annual and 6 quarterly identities published for the early years.
  testthat::expect_equal(
    DBI::dbGetQuery(con, paste0(
      "SELECT COUNT(DISTINCT series_id) n FROM documented_series_snapshot ",
      "WHERE source_sheet = 'CUADRO 61'"
    ))$n[[1]],
    182L
  )
  testthat::expect_equal(
    DBI::dbGetQuery(con, paste0(
      "SELECT COUNT(*) n FROM documented_series_snapshot ",
      "WHERE source_sheet = 'CUADRO 61' AND identity_stability <> 'semantic'"
    ))$n[[1]],
    0L
  )
  # The credit survey's quarter axis runs across columns; no series may be left
  # holding a single observation because the slot pinned its period. 2,539
  # before the repair, then 5, now none. The last five came from R52: nine
  # question-header rows carry a stray numeric in a period column, so the
  # "header rows have no values" test rejected them, the header was consumed as
  # a response of the previous question, and every response row of the block
  # that followed inherited the wrong question. Exact, not a maximum, so drift
  # in either direction is caught.
  testthat::expect_equal(
    DBI::dbGetQuery(con, paste0(
      "SELECT COUNT(*) n FROM (SELECT series_id FROM documented_series_snapshot ",
      "WHERE source_id = 'credit_survey' GROUP BY 1 HAVING COUNT(*) = 1)"
    ))$n[[1]],
    0L
  )
  # Every credit-survey identity is now semantic: no question/response pair is
  # disambiguated by worksheet row, which is what mis-attribution looked like.
  testthat::expect_equal(audit_series_count("credit_survey"), 312L)
  testthat::expect_equal(
    DBI::dbGetQuery(con, paste0(
      "SELECT COUNT(*) n FROM dim_series WHERE source_id = 'credit_survey' ",
      "AND identity_stability <> 'semantic'"
    ))$n[[1]],
    0L
  )
  # Ganaderia's answers must be published under Ganaderia. Row 100 is the first
  # response row of the 10,2 block, immediately after the header at row 99 that
  # the old test rejected.
  testthat::expect_match(
    DBI::dbGetQuery(con, paste0(
      "SELECT DISTINCT question FROM documented_series_snapshot ",
      "WHERE source_id = 'credit_survey' AND source_sheet = '%' AND source_row = 100"
    ))$question[[1]],
    "^10,2 - Ganader"
  )
  # The worksheet slug inside series_id must be a pure function of the sheet
  # name. It used to be uniquified by position (Datos, Datos_2, ... Datos_26),
  # so inserting one column upstream reassigned the identity of every later
  # series in that sheet. A plain regexp cannot test this -- real sheet names
  # end in digits (CUADRO 61, SIPAP_01) -- so recompute the slug and compare.
  documented_identity <- DBI::dbGetQuery(con, paste0(
    "SELECT identity_basis, split_part(series_id, ':', 2) AS slug FROM dim_series ",
    "WHERE semantic_status = 'documented_series'"
  ))
  identity_sheet <- sub("[|].*$", "", documented_identity$identity_basis)
  expected_slug <- vapply(
    unique(identity_sheet), function(sheet) janitor::make_clean_names(sheet), character(1)
  )
  testthat::expect_equal(sum(documented_identity$slug != expected_slug[identity_sheet]), 0L)
  # The research gate: every series carries a declared table status, and the
  # allowlist only ever exposes reviewed tables.
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM v_series_table_status WHERE status = 'unreviewed'")$n[[1]],
    0L
  )
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM v_research_series WHERE status <> 'validated'")$n[[1]],
    0L
  )
  testthat::expect_true(all(c("compra", "venta") %in% DBI::dbGetQuery(con, "SELECT DISTINCT lower(measure) measure FROM documented_series_snapshot WHERE source_id = 'exchange_rates' AND source_sheet = 'USD Prom'")$measure))
  testthat::expect_gte(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM bond_curve_snapshot")$n[[1]], 38000)
  testthat::expect_gte(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM securities_transactions_snapshot")$n[[1]], 300000)
  testthat::expect_gte(DBI::dbGetQuery(con, "SELECT min(source_row) n FROM bond_curve_snapshot")$n[[1]], 2L)
  testthat::expect_gte(DBI::dbGetQuery(con, "SELECT min(source_row) n FROM securities_transactions_snapshot")$n[[1]], 2L)
  testthat::expect_gt(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM v_bond_curves_latest")$n[[1]], 0)
  testthat::expect_gt(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM v_securities_daily_activity")$n[[1]], 0)
  cda <- DBI::dbGetQuery(con, paste0(
    "SELECT COUNT(*) observations, COUNT(DISTINCT series_id) series, ",
    "COUNT(DISTINCT source_sheet) sheets, MIN(period) first_period, MAX(period) last_period ",
    "FROM documented_series_snapshot WHERE source_id = 'cda_curve'"
  ))
  testthat::expect_equal(cda$observations[[1]], 21854L)
  testthat::expect_equal(cda$series[[1]], 471L)
  testthat::expect_equal(cda$sheets[[1]], 412L)
  testthat::expect_equal(as.Date(cda$first_period[[1]]), as.Date("2018-01-31"))
  testthat::expect_equal(as.Date(cda$last_period[[1]]), as.Date("2026-07-31"))
  cda_accounting <- DBI::dbGetQuery(con, paste0(
    "SELECT SUM(cell_reuse) reuse, SUM(unmapped_in_region) unmapped, ",
    "SUM(unclassified_cells) unclassified, SUM(parser_defect_cells) defects ",
    "FROM table_reconciliation WHERE source_id = 'cda_curve'"
  ))
  testthat::expect_equal(unlist(cda_accounting[1, ]), c(reuse = 0, unmapped = 0, unclassified = 0, defects = 0))
  testthat::expect_equal(DBI::dbGetQuery(
    con, "SELECT COUNT(*) n FROM source_region_classification WHERE source_id = 'cda_curve'"
  )$n[[1]], 0L)
  testthat::expect_equal(DBI::dbGetQuery(
    con, "SELECT COUNT(*) n FROM v_research_series WHERE source_id = 'cda_curve'"
  )$n[[1]], 0L)
  testthat::expect_setequal(DBI::dbGetQuery(
    con, "SELECT DISTINCT status FROM v_series_table_status WHERE source_id = 'cda_curve'"
  )$status, "provisional")
  tcn <- DBI::dbGetQuery(con, paste0(
    "SELECT COUNT(*) observations, COUNT(DISTINCT series_id) series, ",
    "COUNT(DISTINCT source_sheet) sheets, MIN(period) first_period, MAX(period) last_period, ",
    "COUNT(DISTINCT unit) units, COUNT(currency) currencies ",
    "FROM documented_series_snapshot WHERE source_id = 'tcn_referential_daily'"
  ))
  testthat::expect_equal(tcn$observations[[1]], 7004L)
  testthat::expect_equal(tcn$series[[1]], 30L)
  testthat::expect_equal(tcn$sheets[[1]], 30L)
  testthat::expect_equal(as.Date(tcn$first_period[[1]]), as.Date("2012-08-06"))
  testthat::expect_equal(as.Date(tcn$last_period[[1]]), as.Date("2026-08-25"))
  testthat::expect_equal(tcn$units[[1]], 1L)
  testthat::expect_equal(tcn$currencies[[1]], 0L)
  tcn_accounting <- DBI::dbGetQuery(con, paste0(
    "SELECT SUM(cell_reuse) reuse, SUM(unmapped_in_region) unmapped, ",
    "SUM(unclassified_cells) unclassified, SUM(parser_defect_cells) defects ",
    "FROM table_reconciliation WHERE source_id = 'tcn_referential_daily'"
  ))
  testthat::expect_equal(
    unlist(tcn_accounting[1, ]), c(reuse = 0, unmapped = 0, unclassified = 0, defects = 0)
  )
  testthat::expect_equal(DBI::dbGetQuery(
    con, paste0(
      "SELECT COUNT(*) n FROM source_region_classification ",
      "WHERE source_id = 'tcn_referential_daily' AND classification = 'row_index'"
    )
  )$n[[1]], 930L)
  testthat::expect_equal(DBI::dbGetQuery(
    con, paste0(
      "SELECT COUNT(*) n FROM main.v_report_cells_a1 ",
      "WHERE source_id = 'tcn_referential_daily' AND raw_value_text = 'ND'"
    )
  )$n[[1]], 4156L)
  testthat::expect_equal(DBI::dbGetQuery(
    con, "SELECT COUNT(*) n FROM observation_missingness WHERE source_id = 'tcn_referential_daily'"
  )$n[[1]], 0L)
  testthat::expect_equal(DBI::dbGetQuery(
    con, "SELECT COUNT(*) n FROM v_research_series WHERE source_id = 'tcn_referential_daily'"
  )$n[[1]], 0L)
  testthat::expect_setequal(DBI::dbGetQuery(
    con, "SELECT DISTINCT status FROM v_series_table_status WHERE source_id = 'tcn_referential_daily'"
  )$status, "provisional")
  testthat::expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM (SELECT series_id, period, COUNT(*) AS rows FROM documented_series_snapshot GROUP BY 1,2 HAVING COUNT(*) > 1) x")$n[[1]], 0)
  currency <- DBI::dbGetQuery(con, "SELECT currency_of_origin, unit_currency, economic_currency FROM dim_currency WHERE currency_code = '6200'")
  testthat::expect_identical(currency$currency_of_origin[[1]], "FX")
  testthat::expect_identical(currency$unit_currency[[1]], "PYG")
  testthat::expect_identical(currency$economic_currency[[1]], "PYG")
  storage <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS links, COUNT(DISTINCT sheet_version_id) AS versions FROM report_sheet_vintages")
  testthat::expect_gte(storage$links[[1]], storage$versions[[1]])
  interbank_sheets <- DBI::dbGetQuery(con, "SELECT sheet_name FROM source_sheets WHERE source_id = 'interbank_market'")$sheet_name
  testthat::expect_setequal(interbank_sheets, c("Datos", "Datos (+ de 1 día)", "Mdo Secundario"))
})
