suppressPackageStartupMessages({
  library(DBI)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(lubridate)
  library(janitor)
  library(readxl)
  library(digest)
  library(fs)
  library(xml2)
  library(readr)
  library(yaml)
})

project_root <- function() normalizePath(getwd(), winslash = "/", mustWork = TRUE)

ensure_dirs <- function(root) {
  fs::dir_create(file.path(root, c(
    "database", "database/backups", "outputs", "input_archive", "logs"
  )), recurse = TRUE)
}

normalize_label <- function(x) {
  stringr::str_to_lower(stringr::str_squish(as.character(x)))
}

normalize_semantic_label <- function(x) {
  stringi::stri_trans_general(normalize_label(x), "Latin-ASCII")
}

# stringr/stringi deliberately return vectors for matrix inputs. Reattach the
# shape in one shared helper before using which(..., arr.ind = TRUE); otherwise
# callers silently receive linear offsets instead of row/column coordinates.
matrix_predicate <- function(x, predicate) {
  input_dim <- dim(x)
  if (is.null(input_dim) || length(input_dim) != 2L) stop(
    "matrix_predicate() requires a two-dimensional input.", call. = FALSE
  )
  result <- as.logical(predicate(as.vector(x)))
  if (length(result) != length(x)) stop(
    "Matrix predicate returned a result with the wrong length.", call. = FALSE
  )
  matrix(result, nrow = input_dim[[1]], ncol = input_dim[[2]])
}

matrix_detect <- function(x, pattern, ...) {
  matrix_predicate(x, function(values) stringr::str_detect(values, pattern, ...))
}

matrix_equal <- function(x, value) {
  matrix_predicate(x, function(values) values == value)
}

safe_table_name <- function(source_id, sheet_name) {
  paste0("raw_", janitor::make_clean_names(paste(source_id, sheet_name, sep = "_")))
}

sql_string <- function(x) paste0("'", gsub("'", "''", as.character(x)), "'")
file_sha256 <- function(path) digest::digest(file = path, algo = "sha256")

database_object_exists <- function(con, object_name) {
  DBI::dbGetQuery(con, paste0(
    "SELECT COUNT(*) AS n FROM information_schema.tables WHERE table_schema = current_schema() ",
    "AND table_name = ", sql_string(object_name)
  ))$n[[1]] > 0
}

make_vintage_id <- function(source_id, sha256) {
  paste(source_id, substr(sha256, 1, 24), sep = ":")
}

make_release_id <- function(manifest) {
  keys <- paste(manifest$source_id, manifest$sha256, sep = ":")
  paste0("release:", substr(digest::digest(
    paste(sort(keys), collapse = "|"), algo = "sha256", serialize = FALSE
  ), 1, 24))
}

resolve_current_files <- function(source_row, root) {
  folder <- file.path(root, source_row$input_folder)
  files <- fs::dir_ls(folder, recurse = FALSE, type = "file", fail = FALSE)
  files <- files[grepl(source_row$file_pattern, basename(files), ignore.case = TRUE, perl = TRUE)]
  files <- files[!grepl("^~\\$", basename(files))]
  issues <- tibble(severity = character(), check_name = character(), detail = character())
  if (!length(files)) {
    severity <- if (isTRUE(source_row$required)) "error" else "warning"
    issues <- add_row(issues, severity = severity, check_name = "source_missing",
                      detail = paste("No matching workbook in", folder))
    return(list(files = character(), issues = issues))
  }
  if (!isTRUE(source_row$allow_multiple) && length(files) > 1L) {
    if (!identical(source_row$selection_rule, "newest_mtime")) {
      stop("Unsupported single-file selection_rule: ", source_row$selection_rule, call. = FALSE)
    }
    info <- file.info(files)
    chosen <- files[[which.max(info$mtime)]]
    ignored <- setdiff(files, chosen)
    issues <- add_row(
      issues, severity = "warning", check_name = "multiple_candidates",
      detail = paste("Selected", basename(chosen), "and ignored", paste(basename(ignored), collapse = "; "))
    )
    files <- chosen
  }
  list(files = sort(files), issues = issues)
}

build_current_manifest <- function(registry, root) {
  records <- list(); issues <- list(); k <- 0L; z <- 0L
  for (i in seq_len(nrow(registry))) {
    source_row <- registry[i, ]
    resolved <- resolve_current_files(source_row, root)
    if (nrow(resolved$issues)) {
      z <- z + 1L
      issues[[z]] <- resolved$issues %>% mutate(source_id = source_row$source_id, .before = 1)
    }
    for (path in resolved$files) {
      sha <- file_sha256(path)
      k <- k + 1L
      records[[k]] <- tibble(
        source_id = source_row$source_id,
        source_label = source_row$source_label,
        publisher = source_row$publisher,
        source_format = source_row$source_format,
        ingest_mode = source_row$ingest_mode,
        semantic_status = source_row$semantic_status,
        path = path,
        source_file = basename(path),
        sha256 = sha,
        vintage_id = make_vintage_id(source_row$source_id, sha)
      )
    }
  }
  list(manifest = bind_rows(records), issues = bind_rows(issues))
}

build_archive_manifest <- function(registry, root) {
  manifest_path <- file.path(root, "input_archive", "archive_manifest.csv")
  if (file.exists(manifest_path)) {
    archived <- readr::read_csv(manifest_path, show_col_types = FALSE) %>%
      distinct(source_id, sha256, .keep_all = TRUE)
    records <- archived %>% inner_join(
      registry %>% select(source_id, source_label, publisher, source_format, ingest_mode, semantic_status), by = "source_id"
    ) %>% mutate(
      path = file.path(root, archive_path),
      fallback_mtime = file.info(path)$mtime
    ) %>% filter(file.exists(path)) %>% transmute(
      source_id, source_label, publisher, source_format, ingest_mode, semantic_status,
      path, source_file = original_filename,
      sha256, vintage_id = make_vintage_id(source_id, sha256),
      inferred_date = as.Date(publication_date), fallback_mtime
    )
    return(records %>% arrange(source_id, is.na(inferred_date), inferred_date, fallback_mtime) %>%
             select(-inferred_date, -fallback_mtime))
  }
  records <- list(); k <- 0L
  for (i in seq_len(nrow(registry))) {
    source_row <- registry[i, ]
    folder <- file.path(root, "input_archive", source_row$source_id)
    files <- fs::dir_ls(folder, regexp = "\\.(xlsx|xlsm|csv)$", recurse = FALSE, fail = FALSE)
    for (path in files) {
      sha <- tools::file_path_sans_ext(basename(path))
      if (!grepl("^[0-9a-f]{64}$", sha)) sha <- file_sha256(path)
      k <- k + 1L
      records[[k]] <- tibble(
        source_id = source_row$source_id, source_label = source_row$source_label,
        publisher = source_row$publisher, source_format = source_row$source_format,
        ingest_mode = source_row$ingest_mode, semantic_status = source_row$semantic_status,
        path = path, source_file = basename(path),
        sha256 = sha, vintage_id = make_vintage_id(source_row$source_id, sha),
        inferred_date = infer_publication_date_from_name(path), fallback_mtime = file.info(path)$mtime
      )
    }
  }
  bind_rows(records) %>% arrange(source_id, is.na(inferred_date), inferred_date, fallback_mtime) %>%
    select(-inferred_date, -fallback_mtime)
}

spanish_month_number <- function(x) {
  keys <- c(ene = 1L, enero = 1L, feb = 2L, febrero = 2L, mar = 3L, marzo = 3L,
            abr = 4L, abril = 4L, may = 5L, mayo = 5L, jun = 6L, junio = 6L,
            jul = 7L, julio = 7L, ago = 8L, agosto = 8L, sep = 9L, sept = 9L,
            setiembre = 9L, septiembre = 9L, oct = 10L, octubre = 10L, nov = 11L, noviembre = 11L,
            dic = 12L, diciembre = 12L)
  unname(keys[[normalize_label(x)]])
}

month_end <- function(year, month) {
  as.Date(lubridate::ceiling_date(as.Date(sprintf("%04d-%02d-01", year, month)), "month") - days(1))
}

infer_publication_date_from_name <- function(path) {
  x <- normalize_label(tools::file_path_sans_ext(basename(path)))
  full <- str_match(x, "(20[0-9]{2})[_ -]([01]?[0-9])[_ -]([0-3]?[0-9])")
  if (!is.na(full[1, 1])) return(as.Date(sprintf("%s-%02d-%02d", full[1, 2], as.integer(full[1, 3]), as.integer(full[1, 4]))))
  dmy <- str_match(x, "([0-3]?[0-9])[_ -]([01]?[0-9])[_ -](20[0-9]{2})")
  if (!is.na(dmy[1, 1])) return(as.Date(sprintf("%s-%02d-%02d", dmy[1, 4], as.integer(dmy[1, 3]), as.integer(dmy[1, 2]))))
  named <- str_match(x, "(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)[_ -]+(20[0-9]{2})")
  if (!is.na(named[1, 1])) return(month_end(as.integer(named[1, 3]), spanish_month_number(named[1, 2])))
  short <- str_match(x, "(ene|feb|mar|abr|may|jun|jul|ago|sep|oct|nov|dic)[_ -]*([0-9]{2})(?:[^0-9]|$)")
  if (!is.na(short[1, 1])) return(month_end(2000L + as.integer(short[1, 3]), spanish_month_number(short[1, 2])))
  as.Date(NA)
}

archive_source <- function(path, source_id, root, sha256, publication_date = as.Date(NA)) {
  archive_dir <- file.path(root, "input_archive", source_id)
  fs::dir_create(archive_dir, recurse = TRUE)
  normalized_path <- normalizePath(path, winslash = "/", mustWork = TRUE)
  normalized_archive <- normalizePath(archive_dir, winslash = "/", mustWork = TRUE)
  if (startsWith(normalized_path, paste0(normalized_archive, "/"))) {
    return(list(path = path, created = FALSE))
  }
  ext <- tools::file_ext(path)
  target <- file.path(archive_dir, paste0(sha256, ".", ext))
  created <- FALSE
  if (!file.exists(target)) {
    if (!file.copy(path, target, copy.date = TRUE)) stop("Could not archive source: ", path, call. = FALSE)
    created <- TRUE
  }
  manifest_path <- file.path(root, "input_archive", "archive_manifest.csv")
  relative_target <- file.path("input_archive", source_id, basename(target))
  manifest <- if (file.exists(manifest_path)) readr::read_csv(manifest_path, show_col_types = FALSE) %>%
    mutate(publication_date = as.Date(as.character(publication_date)), archived_at = as.POSIXct(as.character(archived_at), tz = "UTC")) else tibble(
    source_id = character(), sha256 = character(), archive_path = character(),
    original_filename = character(), publication_date = as.Date(character()), archived_at = as.POSIXct(character())
  )
  if (!any(manifest$source_id == source_id & manifest$sha256 == sha256)) {
    manifest <- bind_rows(manifest, tibble(
      source_id = source_id, sha256 = sha256, archive_path = relative_target,
      original_filename = basename(path), publication_date = as.Date(publication_date), archived_at = Sys.time()
    ))
    readr::write_csv(manifest, manifest_path)
  }
  list(path = target, created = created)
}

update_archive_manifest_date <- function(root, source_id, sha256, publication_date) {
  if (is.na(publication_date)) return(invisible(NULL))
  path <- file.path(root, "input_archive", "archive_manifest.csv")
  if (!file.exists(path)) return(invisible(NULL))
  manifest <- readr::read_csv(path, show_col_types = FALSE) %>% mutate(publication_date = as.Date(as.character(publication_date)))
  hit <- manifest$source_id == source_id & manifest$sha256 == sha256
  manifest$publication_date[hit] <- as.Date(publication_date)
  readr::write_csv(manifest, path)
  invisible(NULL)
}

a1_column_number <- function(x) {
  chars <- strsplit(toupper(x), "", fixed = TRUE)[[1]]
  sum(match(chars, LETTERS) * 26 ^ rev(seq_along(chars) - 1L))
}

parse_a1_ref <- function(ref) {
  ref <- tail(strsplit(ref, ":", fixed = TRUE)[[1]], 1)
  c(row = as.integer(str_extract(ref, "[0-9]+")), col = a1_column_number(str_extract(ref, "[A-Z]+")))
}

xlsx_sheet_dimensions <- function(path) {
  scratch <- tempfile("xlsx_xml_")
  dir.create(scratch)
  on.exit(unlink(scratch, recursive = TRUE, force = TRUE), add = TRUE)
  utils::unzip(path, exdir = scratch)
  wb <- xml2::read_xml(file.path(scratch, "xl", "workbook.xml"))
  rel <- xml2::read_xml(file.path(scratch, "xl", "_rels", "workbook.xml.rels"))
  sheet_nodes <- xml2::xml_find_all(wb, ".//*[local-name()='sheet']")
  rel_nodes <- xml2::xml_find_all(rel, ".//*[local-name()='Relationship']")
  rel_target <- stats::setNames(xml2::xml_attr(rel_nodes, "Target"), xml2::xml_attr(rel_nodes, "Id"))
  rel_type <- stats::setNames(xml2::xml_attr(rel_nodes, "Type"), xml2::xml_attr(rel_nodes, "Id"))
  out <- vector("list", length(sheet_nodes))
  for (i in seq_along(sheet_nodes)) {
    node <- sheet_nodes[[i]]
    sid <- xml2::xml_attr(node, "id")
    if (is.na(sid)) {
      attrs <- xml2::xml_attrs(node)
      id_attr <- which(names(attrs) == "r:id" | endsWith(names(attrs), ":id"))
      if (length(id_attr)) sid <- unname(attrs[[id_attr[[1]]]])
    }
    if (is.na(sid) || !sid %in% names(rel_target)) {
      stop("Could not resolve the worksheet relationship id for sheet '",
           xml2::xml_attr(node, "name"), "'.", call. = FALSE)
    }
    if (!stringr::str_ends(rel_type[[sid]], "/worksheet")) next
    target <- rel_target[[sid]]
    xml_path <- file.path(scratch, "xl", target)
    doc <- xml2::read_xml(xml_path)
    ref <- xml2::xml_attr(xml2::xml_find_first(doc, ".//*[local-name()='dimension']"), "ref")
    endpoint <- if (is.na(ref)) c(row = 1L, col = 1L) else parse_a1_ref(ref)
    active_cells <- xml2::xml_find_all(
      doc, ".//*[local-name()='c'][*[local-name()='v'] or *[local-name()='is'] or *[local-name()='f']]"
    )
    active_refs <- xml2::xml_attr(active_cells, "r")
    active_rows <- suppressWarnings(as.integer(stringr::str_extract(active_refs, "[0-9]+")))
    active_columns <- stringr::str_extract(active_refs, "[A-Z]+")
    active_columns <- vapply(active_columns, a1_column_number, numeric(1))
    keep <- !is.na(active_rows) & !is.na(active_columns)
    content_bounds <- if (!any(keep)) {
      # An actually empty worksheet has an empty half-open range. Using A1 as
      # a synthetic active cell disagrees with readxl, which correctly returns
      # a 0 x 0 tibble for formula views with no cached values.
      c(first_row = 1L, first_col = 1L, last_row = 0L, last_col = 0L)
    } else c(
      first_row = min(active_rows[keep]), first_col = min(active_columns[keep]),
      last_row = max(active_rows[keep]), last_col = max(active_columns[keep])
    )
    out[[i]] <- tibble(
      sheet_name = xml2::xml_attr(node, "name"), used_rows = endpoint[["row"]], used_cols = endpoint[["col"]],
      content_first_row = content_bounds[["first_row"]], content_first_col = content_bounds[["first_col"]],
      content_last_row = content_bounds[["last_row"]], content_last_col = content_bounds[["last_col"]]
    )
  }
  bind_rows(out)
}

csv_source_dimensions <- function(path) {
  header <- readr::read_lines(path, n_max = 1L, locale = readr::locale(encoding = "UTF-8"))
  delimiter <- if (length(header) && stringr::str_count(header, fixed(";")) >= stringr::str_count(header, fixed(","))) ";" else ","
  columns <- length(strsplit(sub("^\\ufeff", "", header), delimiter, fixed = TRUE)[[1]])
  rows <- length(readr::read_lines(path, locale = readr::locale(encoding = "UTF-8")))
  tibble::tibble(
    sheet_name = "data", used_rows = as.integer(rows), used_cols = as.integer(columns),
    content_first_row = 1L, content_first_col = 1L,
    content_last_row = as.integer(rows), content_last_col = as.integer(columns)
  )
}

read_sheet_matrix <- function(path, sheet, used_rows, used_cols,
                              content_first_row = 1L, content_first_col = 1L,
                              content_last_row = used_rows, content_last_col = used_cols) {
  bounds <- as.integer(c(content_first_row, content_first_col, content_last_row, content_last_col))
  if (any(is.na(bounds)) || bounds[[1]] < 1L || bounds[[2]] < 1L ||
      bounds[[3]] < bounds[[1]] || bounds[[4]] < bounds[[2]] ||
      bounds[[3]] - bounds[[1]] + 1L > 100000L || bounds[[4]] - bounds[[2]] + 1L > 5000L) stop(
    "Worksheet range guard: meaningful content bounds are invalid or implausibly large for ",
    basename(path), " / ", sheet, ".", call. = FALSE
  )
  x <- readxl::read_excel(
    path, sheet = sheet, col_names = FALSE, .name_repair = "minimal",
    range = readxl::cell_limits(bounds[1:2], bounds[3:4]), col_types = "list"
  )
  names(x) <- sprintf("col_%04d", seq_len(ncol(x)))
  x
}

read_dimensioned_sheet <- function(path, dimension_row, max_rows = NULL, max_cols = NULL) {
  if (nrow(dimension_row) != 1L) stop("Worksheet dimension guard: expected exactly one row.", call. = FALSE)
  first_active_row <- dimension_row$content_first_row[[1]]
  first_active_col <- dimension_row$content_first_col[[1]]
  # Read from A1 so source_row/source_column remain true Excel coordinates and
  # fixed official reference blocks retain their published column positions.
  first_row <- 1L
  first_col <- 1L
  last_row <- dimension_row$content_last_row[[1]]
  last_col <- dimension_row$content_last_col[[1]]
  if (is.na(last_row) || is.na(last_col) || last_row < 1L || last_col < 1L) {
    return(tibble::new_tibble(list(), nrow = 0L))
  }
  if (!is.null(max_rows)) last_row <- min(last_row, first_active_row + as.integer(max_rows) - 1L)
  if (!is.null(max_cols)) last_col <- min(last_col, first_active_col + as.integer(max_cols) - 1L)
  read_sheet_matrix(
    path, dimension_row$sheet_name[[1]], dimension_row$used_rows[[1]], dimension_row$used_cols[[1]],
    first_row, first_col, last_row, last_col
  )
}

cell_list <- function(x) {
  if (is.list(x)) return(x)
  lapply(seq_along(x), function(i) x[[i]])
}

cell_character <- function(x) {
  cells <- cell_list(x)
  vapply(cells, function(value) {
    if (is.null(value) || length(value) == 0L || all(is.na(value))) return(NA_character_)
    if (inherits(value, c("Date", "POSIXt"))) return(format(as.Date(value), "%Y-%m-%d"))
    as.character(value[[1]])
  }, character(1))
}

extract_row_cells <- function(data, row, columns = seq_len(ncol(data))) {
  lapply(columns, function(column) data[[column]][[row]])
}

as_number_or_na <- function(x) {
  cells <- cell_list(x)
  vapply(cells, function(value) {
    if (is.null(value) || length(value) == 0L || all(is.na(value))) return(NA_real_)
    suppressWarnings(as.numeric(value[[1]]))
  }, numeric(1))
}

as_excel_date <- function(x) {
  cells <- cell_list(x)
  out <- as.Date(rep(NA_real_, length(cells)), origin = "1970-01-01")
  for (i in seq_along(cells)) {
    value <- cells[[i]]
    if (is.null(value) || length(value) == 0L || all(is.na(value))) next
    value <- value[[1]]
    if (inherits(value, c("Date", "POSIXt"))) {
      out[[i]] <- as.Date(value)
      next
    }
    numeric_value <- suppressWarnings(as.numeric(value))
    if (!is.na(numeric_value) && numeric_value > 20000 && numeric_value < 80000) {
      out[[i]] <- as.Date(numeric_value, origin = "1899-12-30")
      next
    }
    parsed <- tryCatch(suppressWarnings(as.Date(as.character(value), tryFormats = c(
      "%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y", "%Y/%m/%d"
    ))), error = function(e) as.Date(NA))
    if (!is.na(parsed)) out[[i]] <- parsed
  }
  out
}

as_typed_date <- function(x) {
  cells <- cell_list(x)
  out <- as.Date(rep(NA_real_, length(cells)), origin = "1970-01-01")
  for (i in seq_along(cells)) {
    value <- cells[[i]]
    if (!is.null(value) && length(value) && !all(is.na(value)) &&
        inherits(value[[1]], c("Date", "POSIXt"))) out[[i]] <- as.Date(value[[1]])
  }
  out
}

assert_plausible_dates <- function(x, source_id, sheet, minimum = as.Date("1980-01-01"),
                                   maximum = Sys.Date() + 400L) {
  dates <- as.Date(x)
  dates <- dates[!is.na(dates)]
  if (!length(dates)) stop("Date guard: no valid dates parsed for ", source_id, "/", sheet, ".", call. = FALSE)
  if (min(dates) < minimum || max(dates) > maximum) stop(
    "Date guard failed for ", source_id, "/", sheet, ": observed range ",
    min(dates), " to ", max(dates), "; permitted range ", minimum, " to ", maximum, ".",
    call. = FALSE
  )
  invisible(TRUE)
}

read_parser_spec <- function(root, source_id) {
  path <- file.path(root, "config", "specs", paste0(source_id, ".yml"))
  if (!file.exists(path)) stop("Parser specification not found: ", path, call. = FALSE)
  yaml::yaml.load(paste(readLines(path, encoding = "UTF-8", warn = FALSE), collapse = "\n"))
}

find_anchor_cell <- function(data, value, max_rows = 20L, max_cols = 10L,
                             min_row = 1L, min_col = 1L, occurrence = NULL) {
  min_row <- max(1L, as.integer(min_row)); min_col <- max(1L, as.integer(min_col))
  max_rows <- min(nrow(data), as.integer(max_rows)); max_cols <- min(ncol(data), as.integer(max_cols))
  if (min_row > max_rows || min_col > max_cols) stop(
    "Structure guard: anchor search region is empty.", call. = FALSE
  )
  matches <- list(); k <- 0L
  search_rows <- seq.int(min_row, max_rows)
  for (j in seq.int(min_col, max_cols)) {
    vals <- normalize_label(cell_character(data[[j]][search_rows]))
    hit <- which(vals == normalize_label(value))
    if (length(hit)) for (r in search_rows[hit]) { k <- k + 1L; matches[[k]] <- c(row = r, col = j) }
  }
  if (!is.null(occurrence)) {
    occurrence <- as.integer(occurrence)
    if (occurrence < 1L || occurrence > length(matches)) stop(sprintf(
      "Structure guard: anchor '%s' occurrence %d requested, but only %d found in rows %d:%d and columns %d:%d.",
      value, occurrence, length(matches), min_row, max_rows, min_col, max_cols
    ), call. = FALSE)
    return(matches[[occurrence]])
  }
  if (length(matches) != 1L) stop(sprintf("Structure guard: expected one anchor '%s', found %d.", value, length(matches)), call. = FALSE)
  matches[[1]]
}

structure_signature <- function(x) {
  digest::digest(paste(normalize_label(x), collapse = "|"), algo = "sha256", serialize = FALSE)
}

assert_same_structure <- function(expected, observed, source_id, sheet, component) {
  expected <- unname(normalize_label(expected))
  observed <- unname(normalize_label(observed))
  if (!identical(expected, observed)) {
    missing <- setdiff(expected, observed)
    added <- setdiff(observed, expected)
    stop(sprintf(
      "Structure guard failed for %s/%s (%s). Missing: [%s]. Added or reordered: [%s].",
      source_id, sheet, component, paste(missing, collapse = "; "), paste(added, collapse = "; ")
    ), call. = FALSE)
  }
  tibble(source_id = source_id, source_sheet = sheet, component = component,
         expected_signature = structure_signature(expected), observed_signature = structure_signature(observed), status = "passed")
}

write_markdown_report <- function(path, lines) writeLines(lines, path, useBytes = TRUE)
