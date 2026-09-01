p1_audit4_production <- function() {
  path <- file.path(project_test_root, "database", "paraguay_macro_pilot.duckdb")
  testthat::skip_if_not(file.exists(path), "no production database")
  con <- connect_project_database(path, read_only = TRUE)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE), envir = parent.frame())
  con
}

testthat::test_that("every source vintage has a provenance record, complete or explicitly pending", {
  con <- p1_audit4_production()
  # The audit's F-14. A publisher's name is not provenance, and the answer to
  # "where did this file come from" has to exist for every vintage even when the
  # honest content of it is "nobody has recorded that yet".
  coverage <- DBI::dbGetQuery(con, paste(
    "SELECT count(*) AS vintages,",
    "count(*) FILTER (WHERE p.vintage_id IS NULL) AS unrecorded",
    "FROM raw.source_files f LEFT JOIN raw.source_provenance p USING (vintage_id)"
  ))
  testthat::expect_gt(coverage$vintages[[1]], 0L)
  testthat::expect_equal(coverage$unrecorded[[1]], 0L)
  # The view a researcher or operator reads, and the status it reports.
  status <- DBI::dbGetQuery(con, paste(
    "SELECT provenance_status, count(*) AS n FROM main.v_source_provenance GROUP BY 1"
  ))
  testthat::expect_true(all(status$provenance_status %in% c("complete", "incomplete")))
  testthat::expect_equal(sum(status$n), coverage$vintages[[1]])
})

testthat::test_that("the publication date is decided by authority and mirrored, not copied per writer", {
  con <- p1_audit4_production()
  # The audit's F-01, as the invariant rather than as the incident. Every table
  # holding (vintage_id, publication_date) is a mirror of source_files, and the
  # release gate refuses a release in which any of them has drifted.
  mirrors <- DBI::dbGetQuery(con, paste(
    "SELECT table_schema, table_name FROM information_schema.columns",
    "WHERE column_name IN ('vintage_id', 'publication_date')",
    "GROUP BY 1, 2 HAVING count(DISTINCT column_name) = 2"
  ))
  mirrors <- mirrors[mirrors$table_name != "source_files", , drop = FALSE]
  testthat::expect_gt(nrow(mirrors), 3L)
  for (i in seq_len(nrow(mirrors))) {
    divergent <- DBI::dbGetQuery(con, paste0(
      "SELECT count(*) AS n FROM ",
      DBI::dbQuoteIdentifier(con, mirrors$table_schema[[i]]), ".",
      DBI::dbQuoteIdentifier(con, mirrors$table_name[[i]]), " t",
      " JOIN raw.source_files f USING (vintage_id)",
      " WHERE t.publication_date IS DISTINCT FROM f.publication_date"
    ))$n[[1]]
    testthat::expect_equal(divergent, 0L, info = mirrors$table_name[[i]])
  }
  # The authority order itself: a lower authority may not overwrite a higher one.
  testthat::expect_gt(publication_date_authority("official_registry"),
                      publication_date_authority("filename"))
  testthat::expect_gt(publication_date_authority("filename"),
                      publication_date_authority("content_max_period"))
  testthat::expect_equal(publication_date_authority("pending_content_inference"), 0L)
  # And the compensatory-FX vintage the audit found, now settled on one date.
  compensatory <- DBI::dbGetQuery(con, paste(
    "SELECT f.publication_date, max(e.period) AS last_period, count(*) AS facts",
    "FROM canonical.fact_series_events e JOIN raw.source_files f USING (vintage_id)",
    "WHERE f.source_id = 'compensatory_fx_sales' GROUP BY 1"
  ))
  testthat::expect_equal(nrow(compensatory), 1L)
  testthat::expect_equal(as.Date(compensatory$publication_date[[1]]), as.Date("2026-07-31"))
  testthat::expect_equal(as.Date(compensatory$last_period[[1]]), as.Date("2026-07-31"))
  testthat::expect_equal(compensatory$facts[[1]], 417L)
})

testthat::test_that("an expected period that is absent carries the reason it is absent", {
  con <- p1_audit4_production()
  # The audit's F-12: absence and omission look identical from the outside, and
  # they mean opposite things. The grid is what the series' own frequency
  # implies; every period on it is either an observation or an absence with a
  # reason established against the raw cell layer. That invariant is the point --
  # a third, silent category would be exactly the ambiguity being removed.
  totals <- DBI::dbGetQuery(con, paste(
    "SELECT (SELECT count(*) FROM staging.expected_observation_grid) AS grid,",
    "(SELECT count(*) FROM staging.expected_observation_grid g",
    " JOIN staging.documented_series_snapshot o",
    "   ON o.series_id = g.series_id AND o.period = g.period) AS observed,",
    "(SELECT count(*) FROM staging.observation_missingness) AS missing"
  ))
  testthat::expect_gt(totals$grid[[1]], 0L)
  testthat::expect_equal(totals$grid[[1]], totals$observed[[1]] + totals$missing[[1]])
  reasons <- DBI::dbGetQuery(con, paste(
    "SELECT reason, count(*) AS periods FROM staging.observation_missingness GROUP BY 1"
  ))
  testthat::expect_true(all(reasons$reason %in% OBSERVATION_MISSINGNESS_REASONS))
  # The financial-indicator gaps the audit reported are answered, and schema 27
  # corrected what the answer is. Schema 25 called all 20,156 of them blank
  # because it read only the numeric value; 18,416 of those cells hold the text
  # `s/m`, which is the publisher saying that nothing traded in that month --
  # a definite answer, not an absent one. Only 1,740 are genuinely empty.
  count_of <- function(reason) {
    value <- reasons$periods[reasons$reason == reason]
    if (length(value)) value else 0L
  }
  testthat::expect_gt(count_of("no_movement"), 10000L)
  testthat::expect_lt(count_of("blank_in_source"), count_of("no_movement"))
  # And nothing the publisher writes goes unrecognised: an unregistered token
  # blocks promotion rather than being folded into blanks.
  testthat::expect_equal(count_of("source_token_unreviewed"), 0L)
  tokens <- DBI::dbGetQuery(con, paste(
    "SELECT status, count(*) AS n FROM audit.source_value_tokens GROUP BY 1"
  ))
  testthat::expect_gt(sum(tokens$n), 0L)
  testthat::expect_true(all(tokens$status %in% SOURCE_VALUE_TOKEN_STATUSES))
  # A grid is only built where the frequency implies a calendar, and only where
  # the series' own periods sit on it.
  frequencies <- DBI::dbGetQuery(
    con, "SELECT DISTINCT frequency FROM staging.expected_observation_grid"
  )$frequency
  testthat::expect_true(all(frequencies %in% EXPECTED_GRID_FREQUENCIES))
})

testthat::test_that("the aggregate identities the publisher states hold in what was parsed", {
  con <- p1_audit4_production()
  identities <- read_aggregate_identities(project_test_root)
  testthat::expect_gt(nrow(identities), 0L)
  for (i in seq_len(nrow(identities))) {
    row <- identities[i, ]
    components <- as.integer(strsplit(row$component_columns, "|", fixed = TRUE)[[1]])
    measured <- DBI::dbGetQuery(con, paste0(
      "WITH v AS (SELECT period, source_column, value FROM staging.documented_series_snapshot",
      " WHERE source_id = ", DBI::dbQuoteString(con, row$source_id),
      " AND source_sheet = ", DBI::dbQuoteString(con, row$source_sheet), ")",
      " SELECT count(*) AS periods,",
      " count(*) FILTER (WHERE abs(total - components) > ", row$tolerance, ") AS breaches",
      " FROM (SELECT period,",
      "   max(value) FILTER (WHERE source_column = ", row$total_column, ") AS total, ",
      paste(sprintf(
        "coalesce(max(value) FILTER (WHERE source_column = %d), 0)", components
      ), collapse = " + "), " AS components",
      "   FROM v GROUP BY 1) x WHERE total IS NOT NULL"
    ))
    testthat::expect_gt(measured$periods[[1]], 0L)
    testthat::expect_equal(measured$breaches[[1]], 0L, info = row$identity_label)
  }
  # The SIPAP_12 Importe identity is what establishes that column 18, which the
  # publisher left without a sub-header, is the Importe Destino of the QR block.
  testthat::expect_true(any(
    identities$source_sheet == "SIPAP_12" & grepl("Importe", identities$identity_label)
  ))
})
