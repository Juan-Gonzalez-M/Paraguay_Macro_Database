# Regression cover for the audit's P1 and P2 rounds (schema 14): the bounded
# horizontal axis, the Annex classification, measurement semantics, period
# bounds and availability, the domain marts, the grain separation and the
# governance registers.

p1_production <- function() {
  path <- file.path(project_test_root, "database", "paraguay_macro_pilot.duckdb")
  testthat::skip_if_not(file.exists(path), "production database not present")
  con <- connect_project_database(path, read_only = TRUE)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE), envir = parent.frame())
  con
}

testthat::test_that("the foreign-trade axis is bounded and provisional markers stay out of labels", {
  con <- p1_production()
  # R45 mechanism 2: a bare "*" over the most recent months was becoming the
  # measure, cutting every product series in two.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM dim_series",
    "WHERE label LIKE '%— *' OR label LIKE '%- *'"
  ))$n[[1]], 0L)
  # R45 mechanism 1: the seven interannual comparison columns inherited the last
  # real period, so every product gained spurious observations in that month.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM dim_series",
    "WHERE source_id = 'economic_annex' AND identity_stability = 'positional_lane'"
  ))$n[[1]], 0L)
  # Soja on Cuadro 53a is one continuous monthly series again, not two.
  soja <- DBI::dbGetQuery(con, paste(
    "SELECT series_label, count(*) AS observations, min(period) AS first_period,",
    "max(period) AS last_period FROM documented_series_snapshot",
    "WHERE source_sheet = 'Cuadro 53a' AND series_label LIKE 'Soja%' GROUP BY 1"
  ))
  testthat::expect_equal(nrow(soja), 1L)
  testthat::expect_equal(soja$series_label[[1]], "Soja")
  testthat::expect_equal(as.Date(soja$first_period[[1]]), as.Date("1994-01-01"))
  testthat::expect_equal(as.Date(soja$last_period[[1]]), as.Date("2026-07-01"))
  # Nothing is parsed beyond the last column that carries a real date.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT max(source_column) AS n FROM documented_series_snapshot",
    "WHERE source_sheet = 'Cuadro 53a'"
  ))$n[[1]], 392L)
})

testthat::test_that("every parsed source matches its golden parser contract", {
  fixture <- file.path(project_test_root, "tests", "testthat", "fixtures",
                       "parser_contract_signatures.csv")
  testthat::skip_if_not(file.exists(fixture), "parser contracts not present")
  expected <- readr::read_csv(fixture, col_types = readr::cols(.default = readr::col_character()))
  con <- p1_production()
  for (source_id in expected$source_id) {
    observations <- DBI::dbGetQuery(con, paste0(
      "SELECT source_sheet, source_row, source_column, series_label, frequency, period, value ",
      "FROM documented_series_snapshot WHERE source_id = ", sql_string(source_id),
      " ORDER BY source_sheet, source_row, source_column, period"
    ))
    signature <- digest::digest(paste(paste(
      observations$source_sheet, observations$source_row, observations$source_column,
      observations$series_label, observations$frequency, format(observations$period),
      format(observations$value, digits = 15), sep = "|"
    ), collapse = "\n"), algo = "sha256", serialize = FALSE)
    row <- expected[expected$source_id == source_id, ]
    testthat::expect_equal(nrow(observations), as.integer(row$observation_count), info = source_id)
    # One source cell, one observation, for every documented layout.
    testthat::expect_equal(
      nrow(unique(observations[c("source_sheet", "source_row", "source_column")])),
      nrow(observations), info = source_id
    )
    testthat::expect_equal(signature, row$signature_sha256, info = source_id)
  }
})

testthat::test_that("every Annex worksheet carries an economic classification", {
  con <- p1_production()
  unclassified <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM (",
    "  SELECT DISTINCT source_sheet FROM documented_series_snapshot WHERE source_id = 'economic_annex'",
    "  EXCEPT SELECT source_sheet FROM table_domains WHERE source_id = 'economic_annex')"
  ))$n[[1]]
  testthat::expect_equal(unclassified, 0L)
  domains <- DBI::dbGetQuery(con, "SELECT DISTINCT measure_family FROM table_domains")$measure_family
  testthat::expect_true(all(domains %in% TABLE_DOMAIN_MEASURE_FAMILIES))
})

testthat::test_that("measurement metadata is derived where determinate and honest elsewhere", {
  con <- p1_production()
  # The multiplier is the field that prevents a silent 1,000x error, so it must
  # be complete wherever a scale is published.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM dim_series",
    "WHERE scale IS NOT NULL AND scale <> '' AND scale_multiplier IS NULL"
  ))$n[[1]], 0L)
  multipliers <- DBI::dbGetQuery(con, paste(
    "SELECT DISTINCT scale, scale_multiplier FROM dim_series WHERE scale_multiplier IS NOT NULL"
  ))
  testthat::expect_equal(
    multipliers$scale_multiplier,
    unname(SERIES_SCALE_MULTIPLIERS[multipliers$scale])
  )
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM dim_series WHERE unit IS NOT NULL AND unit_code IS NULL"
  ))$n[[1]], 0L)
  # nominal_real is claimed only where price_base_year provides the evidence.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM dim_series WHERE nominal_real = 'real'",
    "AND (price_base_year IS NULL OR trim(price_base_year) = '')"
  ))$n[[1]], 0L)
  # The judgement fields must not be silently filled in.
  for (field in c("stock_flow", "seasonal_adjustment", "valuation")) {
    testthat::expect_equal(DBI::dbGetQuery(con, paste0(
      "SELECT count(*) AS n FROM dim_series WHERE ", field, " IS NULL"
    ))$n[[1]], 0L, info = field)
  }
})

testthat::test_that("period bounds are convention-independent and availability is never inferred", {
  con <- p1_production()
  # The audit's mixed monthly convention: whichever day the source used, the
  # bounds describe the same month.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM v_series_observations WHERE frequency = 'monthly'",
    "AND (period_start <> date_trunc('month', period) OR period_end <> last_day(period))"
  ))$n[[1]], 0L)
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM v_series_observations",
    "WHERE period_start IS NULL OR period_end IS NULL OR period_end < period_start"
  ))$n[[1]], 0L)
  # available_at comes from the vintage, never from the reference period.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM v_series_observations",
    "WHERE publication_date IS NOT NULL AND CAST(available_at AS DATE) <> publication_date"
  ))$n[[1]], 0L)
  # Values dated after their own publication are separated from realised ones.
  after <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM v_series_observations WHERE observation_status = 'after_publication'"
  ))$n[[1]]
  testthat::expect_gt(after, 0L)
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM v_series_observations",
    "WHERE observation_status = 'after_publication' AND period <= publication_date"
  ))$n[[1]], 0L)
  # The as-of interface must not leak anything published later than the cutoff.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM series_as_of_date(DATE '2026-01-01')",
    "WHERE available_at > TIMESTAMP '2026-01-01 00:00:00'"
  ))$n[[1]], 0L)
})

testthat::test_that("the domain marts and grain separation are populated", {
  con <- p1_production()
  for (mart in names(ANNEX_MART_DOMAINS)) {
    # The unfiltered view carries the data; the mart proper carries only what a
    # reviewer validated and the accounting balances, which today is nothing.
    # A populated v_mart_<x> would mean provisional rows are reaching a
    # research-facing name -- the audit's second P0.
    all_rows <- DBI::dbGetQuery(con, paste0("SELECT count(*) AS n FROM v_mart_", mart, "_all"))$n[[1]]
    testthat::expect_gt(all_rows, 0L)
    leaked <- DBI::dbGetQuery(con, paste0(
      "SELECT count(*) AS n FROM v_mart_", mart,
      " WHERE review_status IS DISTINCT FROM 'validated'",
      " OR reconciliation_status IS DISTINCT FROM 'balanced'"
    ))$n[[1]]
    testthat::expect_equal(leaked, 0L, info = mart)
  }
  grains <- DBI::dbGetQuery(con, "SELECT DISTINCT series_grain FROM dim_series")$series_grain
  testthat::expect_true(all(grains %in% SERIES_GRAIN_VALUES))
  testthat::expect_equal(DBI::dbGetQuery(
    con, "SELECT count(*) AS n FROM dim_series WHERE series_grain IS NULL"
  )$n[[1]], 0L)
  # Auction tenders and yield-curve nodes must not be counted as macro series.
  by_grain <- DBI::dbGetQuery(
    con, "SELECT series_grain, sum(series) AS series FROM v_catalogue_by_grain GROUP BY 1"
  )
  testthat::expect_true(all(c("scalar_series", "event", "curve_panel") %in% by_grain$series_grain))
  testthat::expect_gt(by_grain$series[by_grain$series_grain == "event"], 0L)
})

testthat::test_that("referential integrity and natural keys hold across the release", {
  con <- p1_production()
  for (check in c("referential_integrity_violated", "natural_key_violated",
                  "source_cell_reuse", "observation_grain_violated")) {
    testthat::expect_equal(DBI::dbGetQuery(con, paste0(
      "SELECT count(*) AS n FROM quality_flags WHERE check_name = ", sql_string(check)
    ))$n[[1]], 0L, info = check)
  }
})

testthat::test_that("governance registers refuse unreviewed or dangling entries", {
  register_root <- tempfile("paraguay_macro_registers_")
  dir.create(register_root)
  testthat::expect_true(file.copy(file.path(project_test_root, "config"), register_root,
                                  recursive = TRUE))
  ensure_dirs(register_root)
  con <- connect_project_database(file.path(register_root, "database", "reg.duckdb"))
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  initialize_database(con)

  # A methodology break is a reviewed claim about when a definition changed.
  regimes <- file.path(register_root, "config", "methodology_regimes.csv")
  readr::write_csv(tibble::tibble(
    regime_id = "regime:test", concept_key = "economic_annex", regime_label = "Rebasing",
    change_type = "base_period", effective_from = "2017-12-01", effective_to = "",
    comparability = "break_in_series", evidence = "Published note",
    reviewed_by = "unreviewed", reviewed_at = "2026-08-29"
  ), regimes, na = "")
  testthat::expect_error(apply_methodology_regimes(con, register_root), "named reviewer")

  readr::write_csv(tibble::tibble(
    regime_id = "regime:test", concept_key = "economic_annex", regime_label = "Rebasing",
    change_type = "not_a_change_type", effective_from = "2017-12-01", effective_to = "",
    comparability = "break_in_series", evidence = "Published note",
    reviewed_by = "A. Reviewer", reviewed_at = "2026-08-29"
  ), regimes, na = "")
  testthat::expect_error(apply_methodology_regimes(con, register_root), "change_type")

  # A canonical identifier must not be a parser identifier under a new name.
  canonical <- file.path(register_root, "config", "canonical_series.csv")
  readr::write_csv(tibble::tibble(
    canonical_series_id = "canonical:gdp_real_annual", concept_id = "concept:gdp_real",
    definition = "Real GDP", domain = "national_accounts", subdomain = "gdp_by_activity",
    frequency = "annual", unit_code = "PYG", currency = "PYG", stock_flow = "flow",
    nominal_real = "real", seasonal_adjustment = "not_applicable", transformation = "level",
    valuation = "constant_prices", methodology_regime_id = "regime:none",
    reviewed_status = "not_a_status", reviewed_by = "A. Reviewer", reviewed_at = "2026-08-29"
  ), canonical, na = "")
  testthat::expect_error(apply_canonical_series(con, register_root), "reviewed_status")

  # A membership pointing at a series that does not exist must not load.
  readr::write_csv(tibble::tibble(
    canonical_series_id = "canonical:gdp_real_annual", concept_id = "concept:gdp_real",
    definition = "Real GDP", domain = "national_accounts", subdomain = "gdp_by_activity",
    frequency = "annual", unit_code = "PYG", currency = "PYG", stock_flow = "flow",
    nominal_real = "real", seasonal_adjustment = "not_applicable", transformation = "level",
    valuation = "constant_prices", methodology_regime_id = "regime:none",
    reviewed_status = "proposed", reviewed_by = "A. Reviewer", reviewed_at = "2026-08-29"
  ), canonical, na = "")
  readr::write_csv(tibble::tibble(
    canonical_series_id = "canonical:gdp_real_annual", series_id = "economic_annex:nope:0000",
    relationship = "primary", evidence = "test", reviewed_by = "A. Reviewer",
    reviewed_at = "2026-08-29"
  ), file.path(register_root, "config", "canonical_series_members.csv"), na = "")
  testthat::expect_error(apply_canonical_series(con, register_root), "unknown series")
})

testthat::test_that("revision logging and as-of extraction work on a second vintage", {
  # P1-4 asks for a demonstrated revision history and an as-of interface. The
  # machinery exists -- write_sparse_series() writes tombstones and revision
  # rows, series_as_of_date() reads back what was knowable on a date -- but the
  # production database has exactly one ingestion run, because input_archive/
  # holds one vintage per source and no newer BCP publication exists. So the code
  # path is proven here on a synthetic second vintage rather than asserted on
  # production data that does not exist. What this test cannot show, and what
  # remains genuinely undemonstrated, is that a real BCP revision behaves this way.
  path <- tempfile(fileext = ".duckdb")
  con <- connect_project_database(path)
  withr::defer({
    DBI::dbDisconnect(con, shutdown = TRUE)
    unlink(path)
  })
  initialize_database(con)

  vintage <- function(id, published) tibble::tibble(
    vintage_id = id, first_ingested_release_id = "release:test", source_id = "eve",
    source_label = "test", publisher = "test", source_format = "xlsx",
    source_file = "test.xlsx", source_path = "test.xlsx", archive_path = "test.xlsx",
    sha256 = id, size_bytes = 1, publication_date = as.Date(published),
    publication_date_source = "test", first_ingested_at = as.POSIXct(published, tz = "UTC"),
    ingestion_status = "completed"
  )
  DBI::dbWriteTable(con, "source_files", vintage("v:first", "2026-02-15"), append = TRUE)
  DBI::dbWriteTable(con, "source_files", vintage("v:second", "2026-05-15"), append = TRUE)
  # Since schema 24 a vintage is not published because it loaded; it is published
  # because the release that bundles it was accepted. Both vintages therefore
  # need a release link and an accepted release before any research interface
  # will show them, which is also the point of the barrier.
  DBI::dbWriteTable(con, "release_sources", tibble::tibble(
    release_id = "release:test", source_id = "eve", vintage_id = c("v:first", "v:second")
  ), append = TRUE)
  stage_release(con, "release:test", 2L)
  publish_test_release(con, "release:test", "accepted")

  item <- function(id, file) list(vintage_id = id, source_id = "eve", source_file = file)
  meta <- tibble::tibble(
    series_id = c("eve:test_revised", "eve:test_withdrawn"), source_id = "eve",
    label = c("revised", "withdrawn"), unit = "index", scale = "units",
    frequency = "monthly", currency = NA_character_, index_base = NA_character_,
    hierarchy_level = NA_character_, parent_series_id = NA_character_, is_total = FALSE,
    identity_basis = "test", identity_stability = "semantic", hierarchy_status = "resolved",
    semantic_status = "curated_series", first_vintage_id = "v:first", price_base_year = NA_character_
  )

  first <- tibble::tibble(
    series_id = c("eve:test_revised", "eve:test_withdrawn"),
    period = as.Date(c("2026-01-31", "2026-01-31")), value = c(100, 5)
  )
  write_sparse_series(con, first, meta, item("v:first", "first.xlsx"), as.Date("2026-02-15"))

  # The second publication revises one value and stops reporting the other.
  second <- tibble::tibble(
    series_id = "eve:test_revised", period = as.Date("2026-01-31"), value = 107
  )
  write_sparse_series(con, second, meta, item("v:second", "second.xlsx"), as.Date("2026-05-15"))

  revisions <- DBI::dbGetQuery(con, paste(
    "SELECT series_id, previous_value, new_value, previous_vintage_id, new_vintage_id",
    "FROM series_revisions ORDER BY series_id"
  ))
  testthat::expect_equal(nrow(revisions), 2L)
  revised <- revisions[revisions$series_id == "eve:test_revised", ]
  testthat::expect_equal(revised$previous_value, 100)
  testthat::expect_equal(revised$new_value, 107)
  testthat::expect_equal(revised$previous_vintage_id, "v:first")
  testthat::expect_equal(revised$new_vintage_id, "v:second")
  # A series that stops being published is a tombstone, not a silent deletion.
  withdrawn <- DBI::dbGetQuery(con, paste(
    "SELECT is_deleted, value FROM fact_series_events",
    "WHERE series_id = 'eve:test_withdrawn' AND vintage_id = 'v:second'"
  ))
  testthat::expect_true(withdrawn$is_deleted[[1]])
  testthat::expect_true(is.na(withdrawn$value[[1]]))

  # As-of extraction: what a researcher could have known on a date, not what the
  # publisher says today. Getting this wrong is look-ahead bias.
  apply_series_semantics(con)
  before <- DBI::dbGetQuery(con, paste(
    "SELECT series_id, value FROM series_as_of_date(DATE '2026-03-01') ORDER BY series_id"
  ))
  testthat::expect_equal(nrow(before), 2L)
  testthat::expect_equal(before$value[before$series_id == "eve:test_revised"], 100)
  after <- DBI::dbGetQuery(con, paste(
    "SELECT series_id, value FROM series_as_of_date(DATE '2026-06-01') ORDER BY series_id"
  ))
  testthat::expect_equal(after$value[after$series_id == "eve:test_revised"], 107)
  # The withdrawn series must disappear from the later as-of view, not revert to
  # its first-vintage value.
  testthat::expect_false("eve:test_withdrawn" %in% after$series_id)
  # v_series_latest answers the other question -- what the publisher says now --
  # and must agree with the latest as-of extract.
  latest <- DBI::dbGetQuery(
    con, "SELECT series_id, value FROM v_series_latest ORDER BY series_id"
  )
  testthat::expect_equal(latest$series_id, "eve:test_revised")
  testthat::expect_equal(latest$value, 107)

  # The audit's F-04, on the same two vintages: blocking the release withdraws it
  # from every research interface at once, and the unfiltered twin still holds
  # everything so the release can be diagnosed. Nothing is rebuilt to do this --
  # the views join through audit.releases, so one UPDATE is the whole decision.
  publish_test_release(con, "release:test", "blocked", errors = 1L)
  testthat::expect_equal(DBI::dbGetQuery(
    con, "SELECT count(*) AS n FROM v_series_latest"
  )$n[[1]], 0L)
  testthat::expect_equal(DBI::dbGetQuery(
    con, "SELECT count(*) AS n FROM series_as_of_date(DATE '2026-06-01')"
  )$n[[1]], 0L)
  testthat::expect_gt(DBI::dbGetQuery(
    con, "SELECT count(*) AS n FROM v_series_latest_all"
  )$n[[1]], 0L)
  publish_test_release(con, "release:test", "accepted")
  testthat::expect_equal(DBI::dbGetQuery(
    con, "SELECT count(*) AS n FROM v_series_latest"
  )$n[[1]], 1L)
})

testthat::test_that("derived measurement values carry the published wording they rest on", {
  con <- p1_production()
  evidence <- DBI::dbGetQuery(con, paste(
    "SELECT field, value, basis, count(*) AS series FROM series_semantic_evidence",
    "GROUP BY 1, 2, 3"
  ))
  testthat::expect_gt(nrow(evidence), 0L)
  # Nothing may claim review. The only writer is the pipeline, and it derives.
  testthat::expect_false("reviewed" %in% evidence$basis)
  testthat::expect_true(all(evidence$basis %in% c(
    "published_label", "published_unit", "price_base_year", "reviewed"
  )))
  # A derived value without the wording behind it is an assertion.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM series_semantic_evidence",
    "WHERE evidence IS NULL OR length(trim(evidence)) < 8"
  ))$n[[1]], 0L)
  # The value on dim_series and the value the evidence justifies must agree, or
  # the basis published beside it is describing a different claim.
  for (field in c("stock_flow", "seasonal_adjustment")) {
    testthat::expect_equal(DBI::dbGetQuery(con, paste0(
      "SELECT count(*) AS n FROM series_semantic_evidence e JOIN dim_series d USING (series_id)",
      " WHERE e.field = ", sql_string(field), " AND d.", field, " IS DISTINCT FROM e.value"
    ))$n[[1]], 0L, info = field)
  }
  # And every derivation must be checkable: the wording has to actually contain
  # the vocabulary the rule fired on.
  seasonal <- DBI::dbGetQuery(con, paste(
    "SELECT value, evidence FROM series_semantic_evidence WHERE field = 'seasonal_adjustment'"
  ))
  testthat::expect_true(all(
    grepl("serie original", seasonal$evidence[seasonal$value == "not_adjusted"], fixed = TRUE)
  ))
  testthat::expect_true(all(
    grepl("tendencia ciclo", seasonal$evidence[seasonal$value == "trend_cycle"], fixed = TRUE)
  ))
  # Every field a researcher can read is published beside its basis, and a field
  # nobody has established says so rather than defaulting to something plausible.
  bases <- DBI::dbGetQuery(con, paste(
    "SELECT DISTINCT stock_flow_basis AS basis FROM v_series_measurement",
    "UNION SELECT DISTINCT seasonal_adjustment_basis FROM v_series_measurement",
    "UNION SELECT DISTINCT valuation_basis FROM v_series_measurement"
  ))$basis
  testthat::expect_true(all(bases %in% c(
    "not_reviewed", "published_label", "published_unit", "price_base_year", "reviewed", "unrecorded"
  )))
  testthat::expect_gt(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM v_series_measurement WHERE stock_flow_basis = 'published_label'"
  ))$n[[1]], 0L)
  testthat::expect_gt(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM v_series_measurement WHERE seasonal_adjustment_basis = 'not_reviewed'"
  ))$n[[1]], 0L)
})

testthat::test_that("the migration runbook is generated from the registry, not maintained beside it", {
  con <- p1_production()
  runbook <- file.path(project_test_root, "docs", "SCHEMA_MIGRATIONS.md")
  testthat::expect_true(file.exists(runbook))
  lines <- readLines(runbook, warn = FALSE)
  applied <- DBI::dbGetQuery(con, "SELECT version FROM schema_version ORDER BY version")$version
  documented <- as.integer(sub("^\\|\\s*([0-9]+)\\s*\\|.*$", "\\1", grep(
    "^\\|\\s*[0-9]+\\s*\\|", lines, value = TRUE
  )))
  testthat::expect_setequal(documented, applied)
  testthat::expect_true(any(grepl(paste0("schema ", max(applied), "\\*\\*"), lines)))
  # Every applied version must be declared, and the sources a step re-ingests
  # come from the same declaration the invalidation reads -- that is the whole
  # point of generating the file.
  declared <- vapply(SCHEMA_MIGRATIONS, function(entry) entry$version, integer(1))
  testthat::expect_true(all(applied %in% declared))
  testthat::expect_equal(
    schema_migration_sources(18L), c("bcp_fx_daily", "economic_annex")
  )
  # The upgrade entry point the runbook names must exist.
  named <- regmatches(
    paste(lines, collapse = "\n"),
    regexpr("scripts/upgrade_v1_to_v[0-9]+\\.R", paste(lines, collapse = "\n"))
  )
  testthat::expect_true(file.exists(file.path(project_test_root, named)))
})

testthat::test_that("detailed trade carries explicit economic dimensions, not a parsed row label", {
  con <- p1_production()
  # The audit's P1: model product, flow, classification and regime as dimensions
  # rather than as worksheet position or Spanish prose in the label.
  # Scoped to the detailed-trade worksheets this test is about. Schema 23 added a
  # `measure` dimension for financial_indicators, which is a different family on
  # different sheets and is asserted in test-audit-round3-repairs.R; an unscoped
  # query over series_dimension would make this test fail every time another
  # source gains a dimension it says nothing about.
  dimensions <- DBI::dbGetQuery(con, paste(
    "SELECT x.dimension, count(*) AS series FROM series_dimension x",
    "JOIN dim_series d USING (series_id)",
    "WHERE d.source_id = 'economic_annex' GROUP BY 1"
  ))
  testthat::expect_setequal(
    dimensions$dimension, c("product", "trade_flow", "trade_classification", "trade_regime")
  )
  # Every dimension value must be one the derivation can actually produce, and
  # must carry the wording it came from.
  values <- DBI::dbGetQuery(
    con, "SELECT dimension, value, basis, evidence FROM series_dimension"
  )
  testthat::expect_true(all(values$basis %in% c("published_title", "published_label", "reviewed")))
  testthat::expect_true(all(nchar(trimws(values$evidence)) > 8L))
  for (dimension in names(SERIES_DIMENSION_DERIVATIONS)) {
    allowed <- names(SERIES_DIMENSION_DERIVATIONS[[dimension]]$values)
    testthat::expect_true(
      all(values$value[values$dimension == dimension] %in% allowed), info = dimension
    )
  }
  # Direction of trade must match the published title, not be inferred from the
  # sheet number: exports on 46, imports on 51/52/53.
  flow <- DBI::dbGetQuery(con, paste(
    "SELECT DISTINCT n.source_sheet, d.value FROM series_dimension d",
    "JOIN documented_series_snapshot n ON n.series_id = d.series_id",
    "WHERE d.dimension = 'trade_flow' ORDER BY 1"
  ))
  testthat::expect_equal(flow$value[flow$source_sheet == "Cuadro 46a"], "export")
  testthat::expect_equal(flow$value[flow$source_sheet == "Cuadro 53a"], "import")
  # The customs regime is only published on Cuadros 52a/52b, and all three of
  # its values must be present there -- a regime silently collapsing would make
  # tourism imports indistinguishable from imports for domestic use.
  regimes <- DBI::dbGetQuery(con, paste(
    "SELECT DISTINCT d.value FROM series_dimension d JOIN documented_series_snapshot n",
    "ON n.series_id = d.series_id",
    "WHERE d.dimension = 'trade_regime' AND n.source_sheet = 'Cuadro 52a'"
  ))$value
  testthat::expect_setequal(regimes, c("tourism", "domestic_use", "registered"))
  # And they must reach the mart as columns.
  mart <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS observations FROM v_mart_trade_all",
    "WHERE trade_flow = 'import' AND trade_regime = 'tourism'"
  ))$observations[[1]]
  testthat::expect_gt(mart, 0L)
  # Valuation is derived from the published title, and FOB and CIF must never be
  # asserted for the same series.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM dim_series WHERE valuation NOT IN ('fob', 'not_reviewed')"
  ))$n[[1]], 0L)
  testthat::expect_gt(DBI::dbGetQuery(
    con, "SELECT count(*) AS n FROM dim_series WHERE valuation = 'fob'"
  )$n[[1]], 0L)
})

testthat::test_that("the financial-indicator lanes the audit found are gone, with no value moved", {
  con <- p1_production()
  # The audit reported 1,636 positional-lane identities in financial_indicators
  # and read them as a layout-driven modelling failure. The cause was narrower
  # and worse: column 168 of sheet 3.2 is headed SEPT-24, the period pattern did
  # not know the four-letter abbreviation, and the axis fill-right carried AGO-24
  # across it. That mis-dated 867 observations by a month and forked every
  # affected row onto a lane. Recognising the spelling fixed both.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM dim_series",
    "WHERE source_id = 'financial_indicators' AND identity_stability <> 'semantic'"
  ))$n[[1]], 0L)
  # The month that was being skipped now exists, and is dated to itself.
  sept <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM documented_series_snapshot",
    "WHERE source_id = 'financial_indicators' AND source_sheet = '3.2'",
    "AND source_column = 168 AND period = DATE '2024-09-30'"
  ))$n[[1]]
  testthat::expect_gt(sept, 0L)
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM documented_series_snapshot",
    "WHERE source_id = 'financial_indicators' AND source_sheet = '3.2'",
    "AND source_column = 168 AND period = DATE '2024-08-31'"
  ))$n[[1]], 0L)
  # No two columns of the same sheet may claim the same month: that is what the
  # unrecognised header caused, and it is the shape of the defect rather than
  # this one instance of it.
  collisions <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM (",
    "  SELECT source_sheet, period FROM documented_series_snapshot",
    "  WHERE source_id = 'financial_indicators'",
    "  GROUP BY 1, 2 HAVING count(DISTINCT source_column) > 1)"
  ))$n[[1]]
  testthat::expect_equal(collisions, 0L)
})

testthat::test_that("every object lives in the storage layer that says what it is for", {
  con <- p1_production()
  layers <- DBI::dbGetQuery(con, paste(
    "SELECT schema_name, count(*) AS tables FROM duckdb_tables()",
    "WHERE NOT internal GROUP BY 1"
  ))
  testthat::expect_setequal(layers$schema_name, PROJECT_SCHEMAS[PROJECT_SCHEMAS != "marts"])
  # Nothing is left in main. A table there is one nobody has said the purpose of,
  # which is the state the audit found the whole database in.
  testthat::expect_false("main" %in% layers$schema_name)
  # Each table is where its declaration says it should be.
  placement <- DBI::dbGetQuery(con, paste(
    "SELECT schema_name, table_name FROM duckdb_tables() WHERE NOT internal"
  ))
  testthat::expect_equal(
    placement$schema_name,
    unname(vapply(placement$table_name, project_schema_for, character(1)))
  )
  # The research interface is published under marts, and nowhere else.
  marts <- DBI::dbGetQuery(con, paste(
    "SELECT view_name FROM duckdb_views() WHERE schema_name = 'marts' AND NOT internal"
  ))$view_name
  testthat::expect_true("v_research_series" %in% marts)
  # What belongs in marts is no longer a list kept in step by hand -- that list
  # went stale twice. Since schema 30 every published object declares its scope in
  # config/public_view_contract.csv, so the assertion is that every marts view is
  # declared there and none of them is diagnostic.
  contract <- read_public_view_contract(project_test_root)
  testthat::skip_if(is.null(contract), "no public view contract")
  declared <- contract[contract$schema_name == "marts", , drop = FALSE]
  testthat::expect_setequal(marts, declared$object_name)
  testthat::expect_true(all(declared$public_scope %in% c("current", "all")))
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM duckdb_views()",
    "WHERE schema_name <> 'marts' AND view_name LIKE 'v\\_mart\\_%' ESCAPE '\\'"
  ))$n[[1]], 0L)
  # And the search path keeps every unqualified name in the project resolving,
  # which is what makes the move invisible to the SQL that does not care.
  testthat::expect_equal(
    DBI::dbGetQuery(con, "SELECT count(*) AS n FROM v_mart_trade_all")$n[[1]],
    DBI::dbGetQuery(con, "SELECT count(*) AS n FROM marts.v_mart_trade_all")$n[[1]]
  )
})

testthat::test_that("the fact grain is carried by surrogate keys that agree with the identifiers", {
  con <- p1_production()
  key <- DBI::dbGetQuery(con, paste(
    "SELECT constraint_text FROM duckdb_constraints()",
    "WHERE table_name = 'fact_series_events' AND constraint_type = 'PRIMARY KEY'"
  ))$constraint_text
  testthat::expect_match(key, "series_sk", fixed = TRUE)
  testthat::expect_match(key, "vintage_sk", fixed = TRUE)
  # Both keys must be complete, unique in their dimension, and consistent with
  # the identifier on the same fact row -- a surrogate key that drifted from its
  # identifier would repoint observations without changing a visible value.
  for (dimension in list(
    list(table = "dim_series", key = "series_sk", natural = "series_id"),
    list(table = "source_files", key = "vintage_sk", natural = "vintage_id")
  )) {
    testthat::expect_equal(DBI::dbGetQuery(con, paste0(
      "SELECT count(*) AS n FROM ", dimension$table, " WHERE ", dimension$key, " IS NULL"
    ))$n[[1]], 0L, info = dimension$key)
    testthat::expect_equal(DBI::dbGetQuery(con, paste0(
      "SELECT count(*) AS n FROM (SELECT 1 FROM ", dimension$table,
      " GROUP BY ", dimension$key, " HAVING count(*) > 1)"
    ))$n[[1]], 0L, info = dimension$key)
    testthat::expect_equal(DBI::dbGetQuery(con, paste0(
      "SELECT count(*) AS n FROM fact_series_events f JOIN ", dimension$table, " d",
      " ON d.", dimension$key, " = f.", dimension$key,
      " WHERE d.", dimension$natural, " IS DISTINCT FROM f.", dimension$natural
    ))$n[[1]], 0L, info = dimension$key)
  }
  # The public grain is still unique even though it is no longer the key.
  testthat::expect_equal(DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS n FROM (SELECT 1 FROM fact_series_events",
    "GROUP BY series_id, period, vintage_id HAVING count(*) > 1)"
  ))$n[[1]], 0L)
})

testthat::test_that("durable source paths are portable and run-local paths stay run-local", {
  con <- p1_production()
  files <- DBI::dbGetQuery(con, paste(
    "SELECT source_id, source_uri, archive_uri, source_path, archive_path FROM source_files"
  ))
  testthat::expect_gt(nrow(files), 0L)
  # Every durable identity is repository-relative. An absolute path does not
  # survive being opened on another machine and publishes the operator's
  # directory layout to whoever the database is shared with.
  testthat::expect_false(any(startsWith(files$source_uri, "/")))
  testthat::expect_false(any(startsWith(stats::na.omit(files$archive_uri), "/")))
  testthat::expect_equal(sum(is.na(files$source_uri)), 0L)
  testthat::expect_true(all(startsWith(files$source_uri, "input/")))
  # The absolute path is kept, as a fact about the run that produced the row.
  testthat::expect_true(all(startsWith(files$source_path, "/")))
})
