xlsx_named_table_catalog <- function(path) {
  scratch <- tempfile("xlsx_tables_")
  dir.create(scratch)
  on.exit(unlink(scratch, recursive = TRUE, force = TRUE), add = TRUE)
  utils::unzip(path, exdir = scratch)
  wb <- xml2::read_xml(file.path(scratch, "xl", "workbook.xml"))
  rel <- xml2::read_xml(file.path(scratch, "xl", "_rels", "workbook.xml.rels"))
  sheet_nodes <- xml2::xml_find_all(wb, ".//*[local-name()='sheet']")
  rel_nodes <- xml2::xml_find_all(rel, ".//*[local-name()='Relationship']")
  rel_target <- stats::setNames(xml2::xml_attr(rel_nodes, "Target"), xml2::xml_attr(rel_nodes, "Id"))
  records <- list(); k <- 0L
  for (sheet_index in seq_along(sheet_nodes)) {
    node <- sheet_nodes[[sheet_index]]
    attrs <- xml2::xml_attrs(node)
    sid <- xml2::xml_attr(node, "id")
    if (is.na(sid)) {
      hit <- which(names(attrs) == "r:id" | endsWith(names(attrs), ":id"))
      if (length(hit)) sid <- unname(attrs[[hit[[1]]]])
    }
    if (is.na(sid) || !sid %in% names(rel_target)) next
    sheet_target <- rel_target[[sid]]
    sheet_path <- normalizePath(file.path(scratch, "xl", sheet_target), winslash = "/", mustWork = TRUE)
    rel_path <- file.path(dirname(sheet_path), "_rels", paste0(basename(sheet_path), ".rels"))
    if (!file.exists(rel_path)) next
    sheet_rel <- xml2::read_xml(rel_path)
    table_rels <- xml2::xml_find_all(sheet_rel, ".//*[local-name()='Relationship' and contains(@Type, '/table')]")
    for (table_rel in table_rels) {
      target <- xml2::xml_attr(table_rel, "Target")
      table_path <- normalizePath(file.path(dirname(sheet_path), target), winslash = "/", mustWork = TRUE)
      table_doc <- xml2::read_xml(table_path)
      table_node <- xml2::xml_root(table_doc)
      if (!identical(xml2::xml_name(table_node), "table")) stop(
        "Reference guard: named-table XML root is not <table> in ", basename(table_path), ".",
        call. = FALSE
      )
      column_nodes <- xml2::xml_find_all(table_doc, ".//*[local-name()='tableColumn']")
      k <- k + 1L
      records[[k]] <- tibble::tibble(
        source_sheet = xml2::xml_attr(node, "name"),
        source_table = xml2::xml_attr(table_node, "displayName"),
        table_range = xml2::xml_attr(table_node, "ref"),
        observed_columns = paste(xml2::xml_attr(column_nodes, "name"), collapse = "|")
      )
    }
  }
  dplyr::bind_rows(records)
}

read_reference_table <- function(path, sheet, range) {
  readxl::read_excel(path, sheet = sheet, range = range, col_names = TRUE,
                     col_types = "text", .name_repair = "minimal", trim_ws = TRUE) %>%
    dplyr::filter(dplyr::if_any(dplyr::everything(), ~ !is.na(.x) & nzchar(trimws(as.character(.x)))))
}

resolve_reference_table <- function(catalog, spec) {
  expected <- strsplit(spec$expected_columns, "|", fixed = TRUE)[[1]]
  candidates <- catalog %>% dplyr::filter(.data$source_sheet == spec$source_sheet)
  matches <- vapply(candidates$observed_columns, function(columns) {
      observed <- strsplit(columns, "|", fixed = TRUE)[[1]]
      identical(unname(normalize_label(expected)), unname(normalize_label(observed)))
    }, logical(1))
  candidates <- candidates[matches, ]
  if (nrow(candidates) == 1L) return(candidates)
  if (nrow(candidates) > 1L) {
    hinted <- candidates %>% dplyr::filter(.data$source_table == spec$source_table_hint)
    if (nrow(hinted) == 1L) return(hinted)
    stop("Reference guard: multiple named tables on ", spec$source_sheet,
         " share the expected column signature for role ", spec$semantic_role,
         "; display-name hint did not resolve the ambiguity.", call. = FALSE)
  }
  stop("Reference guard: no named table on ", spec$source_sheet,
       " has the expected column signature for role ", spec$semantic_role, ".", call. = FALSE)
}

reference_id <- function(prefix, ...) {
  value <- paste(..., sep = "|")
  paste0(prefix, ":", substr(digest::digest(value, algo = "sha256", serialize = FALSE), 1, 24))
}

replace_dimension_rows <- function(con, table_name, data, key_column) {
  if (!nrow(data)) return(invisible(NULL))
  if (anyDuplicated(data[[key_column]])) stop(
    "Reference key guard: duplicate ", key_column, " values produced for ", table_name, ".",
    call. = FALSE
  )
  keys <- unique(as.character(data[[key_column]]))
  if ("first_vintage_id" %in% names(data)) {
    existing <- DBI::dbGetQuery(con, paste0(
      "SELECT ", DBI::dbQuoteIdentifier(con, key_column), ", first_vintage_id FROM ",
      DBI::dbQuoteIdentifier(con, table_name), " WHERE ",
      DBI::dbQuoteIdentifier(con, key_column), " IN (",
      paste(vapply(keys, sql_string, character(1)), collapse = ","), ")"
    ))
    if (nrow(existing)) {
      names(existing)[[1]] <- key_column
      data <- data %>%
        dplyr::left_join(existing, by = key_column, suffix = c("", "_existing")) %>%
        dplyr::mutate(first_vintage_id = dplyr::coalesce(.data$first_vintage_id_existing, .data$first_vintage_id)) %>%
        dplyr::select(-dplyr::all_of("first_vintage_id_existing"))
    }
  }
  DBI::dbExecute(con, paste0(
    "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name), " WHERE ",
    DBI::dbQuoteIdentifier(con, key_column), " IN (",
    paste(vapply(keys, sql_string, character(1)), collapse = ","), ")"
  ))
  DBI::dbWriteTable(con, table_name, data, append = TRUE)
  invisible(NULL)
}

reference_rows <- function(raw, role, entity_type, vintage_id) {
  value <- function(i) as.character(raw[[i]])
  if (role == "statement_item") return(tibble::tibble(
    statement_item_id = mapply(reference_id, "statement_item", entity_type, value(4), value(5), USE.NAMES = FALSE),
    entity_type = entity_type, report_code = value(5), classification = value(1),
    rubro = value(2), sub_rubro = value(3), source_label = value(4),
    source_label_normalized = normalize_semantic_label(value(4)), first_vintage_id = vintage_id
  ))
  if (role == "ratio") return(tibble::tibble(
    ratio_id = mapply(reference_id, "ratio", entity_type, value(3), USE.NAMES = FALSE),
    entity_type = entity_type, classification = value(1), rubro = value(2),
    source_label = value(3), source_label_normalized = normalize_semantic_label(value(3)),
    first_vintage_id = vintage_id
  ))
  if (role == "entity") {
    ownership <- if (ncol(raw) >= 4L) value(4) else rep(NA_character_, nrow(raw))
    return(tibble::tibble(
      entity_id = paste(entity_type, value(1), sep = ":"), entity_code = value(1),
      entity_type = entity_type, entity_name = value(3), legal_name = value(2),
      short_name = value(3), ownership_type = ownership,
      mapping_status = "verified_reference_workbook", first_vintage_id = vintage_id
    ))
  }
  if (role == "currency") return(tibble::tibble(
    currency_code = value(1), currency_label = value(2),
    currency_of_origin = dplyr::case_when(
      value(1) == "6900" ~ "PYG", value(1) %in% c("6100", "6200") ~ "FX", TRUE ~ NA_character_
    ),
    unit_currency = dplyr::case_when(
      value(1) %in% c("6900", "6200") ~ "PYG", value(1) == "6100" ~ "USD", TRUE ~ NA_character_
    ),
    economic_currency = dplyr::case_when(
      value(1) %in% c("6900", "6200") ~ "PYG", value(1) == "6100" ~ "USD", TRUE ~ NA_character_
    ),
    description = value(3), mapping_status = "verified_reference_workbook",
    first_vintage_id = vintage_id
  ))
  if (role == "statement_account") {
    account_raw <- value(5)
    if (any(grepl("[0-9][eE][+-]?[0-9]", account_raw), na.rm = TRUE)) stop(
      "Reference account guard: scientific notation found in statement account identifiers.", call. = FALSE
    )
    account <- gsub("[^0-9]", "", account_raw)
    return(tibble::tibble(
      statement_account_id = mapply(reference_id, "statement_account", entity_type,
                                    value(1), value(2), value(3), value(4), account,
                                    USE.NAMES = FALSE),
      entity_type = entity_type, report_name = value(1), classification = value(2),
      rubro = value(3), sub_rubro = value(4), account_number_raw = account_raw,
      account_number = account,
      multiplier = ifelse(startsWith(trimws(account_raw), "-"), -1, 1), first_vintage_id = vintage_id
    ))
  }
  if (role == "portfolio_account") {
    account_raw <- value(6)
    if (any(grepl("[0-9][eE][+-]?[0-9]", account_raw), na.rm = TRUE)) stop(
      "Reference account guard: scientific notation found in portfolio account identifiers.", call. = FALSE
    )
    account <- gsub("[^0-9]", "", account_raw)
    return(tibble::tibble(
      portfolio_account_id = mapply(reference_id, "portfolio_account", entity_type, value(5), account, USE.NAMES = FALSE),
      entity_type = entity_type, classification = value(2), rubro = value(3),
      sub_rubro = value(4), source_code = value(5), account_number_raw = account_raw,
      account_number = account, first_vintage_id = vintage_id
    ))
  }
  if (role == "credit_activity") return(tibble::tibble(
    activity_id = paste0("activity:", value(1)), activity_code = value(1),
    activity_description = value(2), activity_description_normalized = normalize_semantic_label(value(2)),
    bulletin_sector = value(3), first_vintage_id = vintage_id
  ))
  if (role == "portfolio_item") return(tibble::tibble(
    portfolio_item_id = mapply(reference_id, "portfolio_item", entity_type, value(4), USE.NAMES = FALSE),
    entity_type = entity_type, classification = value(1), rubro = value(2),
    sub_rubro = value(3), source_code = value(4),
    source_code_normalized = normalize_semantic_label(value(4)), first_vintage_id = vintage_id
  ))
  stop("Unknown semantic reference role: ", role, call. = FALSE)
}

append_reference_snapshot <- function(con, role, data, item, release_id) {
  table_name <- paste0("reference_", role, "_snapshot")
  snapshot <- data %>% dplyr::mutate(
    vintage_id = item$vintage_id, release_id = release_id,
    source_file = item$source_file, .before = 1
  )
  if (DBI::dbExistsTable(con, table_name)) {
    DBI::dbExecute(con, paste0(
      "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
      " WHERE vintage_id = ", sql_string(item$vintage_id)
    ))
    DBI::dbWriteTable(con, table_name, snapshot, append = TRUE)
  } else DBI::dbWriteTable(con, table_name, snapshot, overwrite = TRUE)
  invisible(NULL)
}

create_documented_financial_views <- function(con) {
  normalized_sql <- function(expression) paste0(
    "translate(lower(regexp_replace(trim(CAST(", expression,
    " AS VARCHAR)), '[[:space:]]+', ' ', 'g')), 'áéíóúüñ', 'aeiouun')"
  )
  create_view <- function(view_name, source_view, joins, select_extra) {
    if (!database_object_exists(con, source_view)) return(invisible(NULL))
    DBI::dbExecute(con, paste0(
      "CREATE OR REPLACE VIEW ", DBI::dbQuoteIdentifier(con, view_name), " AS SELECT r.*, ",
      select_extra, " FROM ", DBI::dbQuoteIdentifier(con, source_view), " r ", joins
    ))
  }
  for (source_id in c("banks", "financial")) {
    entity_type <- if (source_id == "banks") "bank" else "finance_company"
    prefix <- paste0("v_latest_raw_", source_id, "_")
    entity_join <- paste0(
      " LEFT JOIN dim_entity e ON e.entity_type = '", entity_type,
      "' AND TRY_CAST(e.entity_code AS BIGINT) = TRY_CAST(r.codigo_entidad AS BIGINT)"
    )
    currency_join <- " LEFT JOIN dim_currency c ON TRY_CAST(c.currency_code AS BIGINT) = TRY_CAST(r.codigo_moneda AS BIGINT)"
    create_view(paste0("v_", source_id, "_eeff_documented"), paste0(prefix, "eeff"), paste0(
      entity_join, currency_join,
      " LEFT JOIN dim_statement_item d ON d.entity_type = '", entity_type,
      "' AND d.source_label_normalized = ", normalized_sql("r.sub_rubro"), " AND d.report_code = r.reporte"
    ), "e.entity_id, e.legal_name, e.short_name, e.ownership_type, c.currency_label, c.currency_of_origin, c.unit_currency, c.economic_currency, d.statement_item_id, d.classification AS semantic_classification, d.rubro AS semantic_rubro, d.sub_rubro AS semantic_sub_rubro")
    create_view(paste0("v_", source_id, "_ratios_documented"), paste0(prefix, "ratios"), paste0(
      entity_join,
      " LEFT JOIN dim_ratio d ON d.entity_type = '", entity_type,
      "' AND d.source_label_normalized = ", normalized_sql("r.sub_rubro")
    ), "e.entity_id, e.legal_name, e.short_name, e.ownership_type, d.ratio_id, d.classification AS semantic_classification, d.rubro AS semantic_rubro")
    create_view(paste0("v_", source_id, "_carteras_documented"), paste0(prefix, "carteras"), paste0(
      entity_join, currency_join,
      " LEFT JOIN dim_portfolio_item d ON d.entity_type = '", entity_type,
      "' AND d.source_code_normalized = ", normalized_sql("r.codigo_cuenta")
    ), "e.entity_id, e.legal_name, e.short_name, e.ownership_type, c.currency_label, c.currency_of_origin, c.unit_currency, c.economic_currency, d.portfolio_item_id, d.classification AS semantic_classification, d.rubro AS semantic_rubro, d.sub_rubro AS semantic_sub_rubro")
    create_view(paste0("v_", source_id, "_credito_sector_documented"), paste0(prefix, "credito_sector"), paste0(
      entity_join, currency_join,
      " LEFT JOIN dim_credit_sector s ON s.sector_label_normalized = ", normalized_sql("r.actividad_destino_vs2")
    ), "e.entity_id, e.legal_name, e.short_name, e.ownership_type, c.currency_label, c.currency_of_origin, c.unit_currency, c.economic_currency, s.credit_sector_id, s.sector_label AS semantic_credit_sector")
    create_view(paste0("v_", source_id, "_credito_actividad_documented"), paste0(prefix, "credito_actividad"), paste0(
      entity_join, currency_join,
      " LEFT JOIN dim_credit_activity a ON a.activity_description_normalized = ", normalized_sql("r.descripcion_actividad"),
      " LEFT JOIN dim_credit_sector s ON s.sector_label_normalized = ", normalized_sql("a.bulletin_sector")
    ), "e.entity_id, e.legal_name, e.short_name, e.ownership_type, c.currency_label, c.currency_of_origin, c.unit_currency, c.economic_currency, a.activity_id, a.activity_code, s.credit_sector_id, a.bulletin_sector AS semantic_credit_sector")
  }
  invisible(NULL)
}

ingest_reference_workbook <- function(con, item, dimensions, release_id, root, publication_date) {
  schema <- readr::read_csv(file.path(root, "config", "reference_schema.csv"), show_col_types = FALSE)
  catalog <- xlsx_named_table_catalog(item$path)
  for (table_name in c("reference_table_loads", "semantic_coverage", "structure_checks")) {
    DBI::dbExecute(con, paste0(
      "DELETE FROM ", DBI::dbQuoteIdentifier(con, table_name),
      " WHERE vintage_id = ", sql_string(item$vintage_id)
    ))
  }
  workbook_check <- assert_same_structure(unique(schema$source_sheet), dimensions$sheet_name,
                                          item$source_id, "<workbook>", "reference_sheet_list")
  record_structure_check(con, workbook_check, item$vintage_id, release_id)
  role_data <- list(); table_loads <- list()
  for (i in seq_len(nrow(schema))) {
    spec <- schema[i, ]
    observed <- resolve_reference_table(catalog, spec)
    expected_columns <- strsplit(spec$expected_columns, "|", fixed = TRUE)[[1]]
    observed_columns <- strsplit(observed$observed_columns[[1]], "|", fixed = TRUE)[[1]]
    check <- assert_same_structure(expected_columns, observed_columns, item$source_id,
                                   spec$source_sheet, paste0("named_table:", observed$source_table[[1]]))
    record_structure_check(con, check, item$vintage_id, release_id)
    raw <- read_reference_table(item$path, spec$source_sheet, observed$table_range[[1]])
    parsed <- reference_rows(raw, spec$semantic_role, spec$entity_type, item$vintage_id)
    role_data[[spec$semantic_role]] <- dplyr::bind_rows(role_data[[spec$semantic_role]], parsed)
    table_loads[[i]] <- tibble::tibble(
      vintage_id = item$vintage_id, source_sheet = spec$source_sheet,
      source_table = observed$source_table[[1]], semantic_role = spec$semantic_role,
      row_count = nrow(parsed), structure_signature = structure_signature(observed_columns)
    )
  }
  loads <- dplyr::bind_rows(table_loads)
  if (!table_has_vintage(con, "reference_table_loads", item$vintage_id)) {
    DBI::dbWriteTable(con, "reference_table_loads", loads, append = TRUE)
  }
  dimensions_to_write <- list(
    entity = c("dim_entity", "entity_id"), currency = c("dim_currency", "currency_code"),
    statement_item = c("dim_statement_item", "statement_item_id"),
    statement_account = c("map_statement_account", "statement_account_id"),
    ratio = c("dim_ratio", "ratio_id"), portfolio_item = c("dim_portfolio_item", "portfolio_item_id"),
    portfolio_account = c("map_portfolio_account", "portfolio_account_id"),
    credit_activity = c("dim_credit_activity", "activity_id")
  )
  total_rows <- 0L
  for (role in names(role_data)) {
    data <- role_data[[role]] %>% dplyr::distinct()
    if (role == "currency") data <- data %>% dplyr::distinct(currency_code, .keep_all = TRUE)
    if (role == "credit_activity") data <- data %>% dplyr::distinct(activity_id, .keep_all = TRUE)
    append_reference_snapshot(con, role, data, item, release_id)
    target <- dimensions_to_write[[role]]
    if (role %in% c("statement_account", "portfolio_account")) {
      current_keys <- unique(as.character(data[[target[[2]]]]))
      DBI::dbExecute(con, paste0(
        "DELETE FROM ", DBI::dbQuoteIdentifier(con, target[[1]]),
        " WHERE ", DBI::dbQuoteIdentifier(con, target[[2]]), " NOT IN (",
        paste(vapply(current_keys, sql_string, character(1)), collapse = ","), ")"
      ))
    }
    replace_dimension_rows(con, target[[1]], data, target[[2]])
    total_rows <- total_rows + nrow(data)
  }
  if ("credit_activity" %in% names(role_data)) {
    sectors <- role_data$credit_activity %>%
      dplyr::filter(!is.na(.data$bulletin_sector), nzchar(trimws(.data$bulletin_sector))) %>%
      dplyr::distinct(.data$bulletin_sector) %>%
      dplyr::transmute(
        credit_sector_id = paste0("credit_sector:", janitor::make_clean_names(.data$bulletin_sector)),
        sector_label = .data$bulletin_sector,
        sector_label_normalized = normalize_semantic_label(.data$bulletin_sector),
        first_vintage_id = item$vintage_id
      )
    append_reference_snapshot(con, "credit_sector", sectors, item, release_id)
    replace_dimension_rows(con, "dim_credit_sector", sectors, "credit_sector_id")
    total_rows <- total_rows + nrow(sectors)
  }
  for (sheet in unique(schema$source_sheet)) {
    sheet_rows <- sum(loads$row_count[loads$source_sheet == sheet])
    DBI::dbWriteTable(con, "semantic_coverage", tibble::tibble(
      vintage_id = item$vintage_id, source_id = item$source_id, source_sheet = sheet,
      semantic_status = "reference_dimension", raw_nonempty_cells = sheet_rows,
      curated_observations = sheet_rows,
      coverage_note = "Verified BCP reference tables loaded into documented financial dimensions."
    ), append = TRUE)
  }
  create_documented_financial_views(con)
  list(curated_rows = total_rows, event_rows = 0L, publication_date = publication_date,
       source_sheet = NA_character_)
}
