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
