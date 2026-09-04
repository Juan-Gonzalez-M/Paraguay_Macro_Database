# Heuristic guard against a bug class that has bitten this project twice
# (R26: `label`, R41: `rows`): a SQL expression aliased without `AS`, where the
# alias text happens to collide with a DuckDB reserved word and the query only
# fails at runtime. This is not a SQL parser — it scans double-quoted string
# literals that look like SQL for `)` immediately followed by a bare reserved
# word (no `AS` in between). It will not catch every possible case, but it
# would have caught both bugs that actually shipped.
testthat::test_that("SQL string literals do not alias expressions with a bare DuckDB reserved word", {
  script_files <- list.files(
    file.path(project_test_root, "scripts"), pattern = "\\.R$", full.names = TRUE
  )
  reserved <- c(
    "label", "rows", "order", "group", "column", "table", "values", "date", "time",
    "user", "role", "check", "value", "key", "end", "start", "window", "range",
    "grouping", "unnest", "using", "left", "right", "full", "cast", "array", "map"
  )
  alias_pattern <- paste0("\\)\\s+(", paste(reserved, collapse = "|"), ")\\b\\s*(?:,|\\bFROM\\b|$)")
  offenders <- character()
  for (path in script_files) {
    text <- paste(readLines(path, warn = FALSE), collapse = "\n")
    literals <- regmatches(text, gregexpr('"(?:[^"\\\\]|\\\\.)*"', text, perl = TRUE))[[1]]
    sql_literals <- literals[grepl("SELECT|FROM\\s|GROUP BY", literals, ignore.case = TRUE, perl = TRUE)]
    hits <- sql_literals[grepl(alias_pattern, sql_literals, ignore.case = TRUE, perl = TRUE)]
    if (length(hits)) offenders <- c(offenders, paste0(basename(path), ": ", hits))
  }
  testthat::expect_equal(
    offenders, character(),
    info = "Bare alias matching a DuckDB reserved word found; add AS before it."
  )
})

# The seventh audit's F-13. The suite ran with 28 warnings, almost all of them
# one deprecation: `.data$x` inside `select()`, which tidyselect 1.2.0 deprecated
# because `select()` takes column *names*, not the data-masking pronoun. Four
# call sites carried 34 of them.
#
# Warning noise is not harmless. A suite that always prints warnings is a suite
# where nobody reads the twenty-ninth, and the next deprecation to appear will be
# one that matters.
testthat::test_that("select() takes column names, not the .data pronoun", {
  # The tests are scanned too. A deprecation warning raised from a test file is
  # the same noise in the same report, and one was: the smoke test's contract
  # join.
  script_files <- c(
    list.files(file.path(project_test_root, "scripts"), pattern = "\\.R$", full.names = TRUE),
    list.files(file.path(project_test_root, "tests", "testthat"), pattern = "\\.R$", full.names = TRUE),
    Sys.glob(file.path(project_test_root, "*.R"))
  )
  # Balanced to one level of nesting, which is enough for every select() in this
  # codebase and keeps the pattern readable.
  select_call <- "(dplyr::)?select\\(([^()]|\\([^()]*\\))*\\)"
  offenders <- character()
  for (path in script_files) {
    text <- paste(readLines(path, warn = FALSE), collapse = "\n")
    calls <- regmatches(text, gregexpr(select_call, text, perl = TRUE))[[1]]
    hits <- calls[grepl(".data$", calls, fixed = TRUE)]
    if (length(hits)) offenders <- c(offenders, paste0(
      basename(path), ": ", gsub("\\s+", " ", substr(hits, 1, 120))
    ))
  }
  testthat::expect_equal(
    offenders, character(),
    info = "Use bare or quoted column names in select(); .data$ there is deprecated."
  )
})
