root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
suppressPackageStartupMessages(library(DBI))
suppressPackageStartupMessages(library(duckdb))

candidate <- file.path(
  root, "database", "candidates", "accepted_for_review_20260919_103853.duckdb"
)
con <- DBI::dbConnect(duckdb::duckdb(), candidate, read_only = TRUE)
on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

search_path <- DBI::dbGetQuery(
  con, "SELECT current_setting('search_path') AS value"
)$value[[1]]
stopifnot(identical(trimws(search_path), ""))

views <- DBI::dbGetQuery(con, paste(
  "SELECT schema_name, view_name FROM duckdb_views()",
  "WHERE NOT internal ORDER BY schema_name, view_name"
))
failures <- character()
for (i in seq_len(nrow(views))) {
  object <- paste0(
    DBI::dbQuoteIdentifier(con, views$schema_name[[i]]), ".",
    DBI::dbQuoteIdentifier(con, views$view_name[[i]])
  )
  outcome <- try(DBI::dbGetQuery(
    con, paste0("SELECT * FROM ", object, " LIMIT 0")
  ), silent = TRUE)
  if (inherits(outcome, "try-error")) {
    failures <- c(failures, paste0(
      views$schema_name[[i]], ".", views$view_name[[i]], ": ",
      conditionMessage(attr(outcome, "condition"))
    ))
  }
}

cat("views=", nrow(views), "\n", sep = "")
cat("failures=", length(failures), "\n", sep = "")
if (length(failures)) stop(paste(failures, collapse = "\n"))
