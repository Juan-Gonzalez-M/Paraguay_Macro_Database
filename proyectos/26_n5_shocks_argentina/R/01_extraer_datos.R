## ============================================================================
## Funciones comunes (idénticas en todas las carpetas de proyecto)
## ----------------------------------------------------------------------------
## - Abre la base SOLO EN LECTURA; nunca escribe en ella ni en los Excel.
## - Series escalares: main.v_series_research (valor publicado, sin reescalar),
##   con el nivel de verificación tomado de catalog.series.
## - Fecha estándar: `fecha` = primer día del período (AAAA-MM-DD);
##   `fecha_fin` = último día del período. Nunca se usa la fecha impresa.
## - Variables externas (NOAA, FRED) se descargan y se guardan en
##   datos/fuentes_externas/; si la descarga falla se reutiliza la copia previa.
## Uso:  Rscript R/01_extraer_datos.R        (desde la carpeta del proyecto)
##       o source("R/01_extraer_datos.R") en RStudio.
## Variables de entorno opcionales:
##   PARAGUAY_MACRO_DB   ruta a paraguay_macro_pilot.duckdb
##   DESCARGAR_EXTERNOS  "0" para no descargar y usar la copia en caché
## ============================================================================

suppressPackageStartupMessages({
  library(DBI)
  library(duckdb)
})

localizar_script <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f)) return(dirname(normalizePath(f[1])))
  for (i in rev(seq_len(sys.nframe()))) {
    of <- sys.frame(i)$ofile
    if (!is.null(of)) return(dirname(normalizePath(of)))
  }
  if (file.exists("R/01_extraer_datos.R")) return(normalizePath("R"))
  stop("No se pudo ubicar el script: ejecútelo desde la carpeta del proyecto.")
}

DIR_PROYECTO <- normalizePath(file.path(localizar_script(), ".."))
DIR_DATOS    <- file.path(DIR_PROYECTO, "datos")
DIR_EXT      <- file.path(DIR_DATOS, "fuentes_externas")
RUTA_DB      <- Sys.getenv("PARAGUAY_MACRO_DB",
                  file.path(DIR_PROYECTO, "..", "..", "database", "paraguay_macro_pilot.duckdb"))
RUTA_INPUT   <- file.path(DIR_PROYECTO, "..", "..", "input", "current")
DESCARGAR    <- Sys.getenv("DESCARGAR_EXTERNOS", "1") == "1"
dir.create(DIR_DATOS, showWarnings = FALSE, recursive = TRUE)

MANIFIESTO <- list()

conectar <- function() {
  if (!file.exists(RUTA_DB)) stop("No se encuentra la base: ", RUTA_DB,
                                  " (defina PARAGUAY_MACRO_DB).")
  dbConnect(duckdb(shared_home = FALSE), dbdir = normalizePath(RUTA_DB), read_only = TRUE)
}

sql_lista <- function(x) paste0("'", gsub("'", "''", unique(x)), "'", collapse = ", ")

FREQ_ES <- c(daily = "diaria", monthly = "mensual", monthly_survey = "mensual",
             quarterly = "trimestral", semiannual = "semestral", annual = "anual",
             irregular_daily = "diaria")

nivel_verificacion <- function(tier, assurance) {
  out <- ifelse(!is.na(assurance) & assurance == "rule_certified", "Validada por regla",
         ifelse(tier == "exploratory_structurally_valid", "Preliminar",
         ifelse(tier == "candidate_needs_review", "No comprobada",
         ifelse(tier == "non_scalar_or_special_structure", "Estructura especial (provisional)", tier))))
  out
}

## spec: data.frame(serie, candidate_id, descripcion, rol)
extraer_escalares <- function(con, spec) {
  stopifnot(!anyDuplicated(spec$serie))
  cat_ <- dbGetQuery(con, sprintf(
    "SELECT candidate_id, validation_tier, research_assurance_level, source_id, source_sheet
       FROM catalog.series WHERE candidate_id IN (%s)", sql_lista(spec$candidate_id)))
  faltan <- setdiff(spec$candidate_id, cat_$candidate_id)
  if (length(faltan)) stop("Identificadores ausentes del catálogo (¿cambió la base?): ",
                           paste(faltan, collapse = ", "))
  obs <- dbGetQuery(con, sprintf(
    "SELECT series_id AS candidate_id, CAST(period_start AS DATE) AS fecha,
            CAST(period_end AS DATE) AS fecha_fin, value AS valor, unit_code AS unidad,
            scale AS escala, frequency, source_id AS fuente, source_sheet AS tabla
       FROM main.v_series_research WHERE series_id IN (%s)
      ORDER BY series_id, period_start, source_sheet", sql_lista(spec$candidate_id)))
  obs <- obs[!is.na(obs$valor), ]
  dup <- duplicated(obs[, c("candidate_id", "fecha")])
  if (any(dup)) {
    message("Aviso: ", sum(dup), " observaciones repetidas en más de una hoja; se conserva la primera.")
    obs <- obs[!dup, ]
  }
  sin_obs <- setdiff(spec$candidate_id, obs$candidate_id)
  if (length(sin_obs)) stop("Series sin observaciones: ", paste(sin_obs, collapse = ", "))
  obs$nivel_verificacion <- nivel_verificacion(
    cat_$validation_tier[match(obs$candidate_id, cat_$candidate_id)],
    cat_$research_assurance_level[match(obs$candidate_id, cat_$candidate_id)])
  i <- match(obs$candidate_id, spec$candidate_id)
  obs$serie <- spec$serie[i]
  obs$frecuencia <- unname(FREQ_ES[obs$frequency])
  obs$frecuencia[is.na(obs$frecuencia)] <- obs$frequency[is.na(obs$frecuencia)]
  obs[, c("fecha", "fecha_fin", "serie", "valor", "unidad", "escala", "frecuencia",
          "nivel_verificacion", "fuente", "tabla", "candidate_id")]
}

## Series diarias publicadas como eventos (mercado interbancario): una obs. por día
extraer_eventos_diarios <- function(con, spec) {
  obs <- dbGetQuery(con, sprintf(
    "SELECT candidate_id, CAST(reference_period_start AS DATE) AS fecha,
            CAST(reference_period_end AS DATE) AS fecha_fin, value AS valor, unit_code AS unidad,
            source_scale AS escala, source_id AS fuente, source_sheet AS tabla, validation_tier
       FROM explore.events WHERE candidate_id IN (%s) AND source_sheet = 'Datos'
      ORDER BY candidate_id, reference_period_start", sql_lista(spec$candidate_id)))
  faltan <- setdiff(spec$candidate_id, obs$candidate_id)
  if (length(faltan)) stop("Eventos sin observaciones: ", paste(faltan, collapse = ", "))
  obs <- obs[!is.na(obs$valor) & !duplicated(obs[, c("candidate_id", "fecha")]), ]
  obs$serie <- spec$serie[match(obs$candidate_id, spec$candidate_id)]
  obs$frecuencia <- "diaria"
  obs$nivel_verificacion <- nivel_verificacion(obs$validation_tier, NA)
  obs[, c("fecha", "fecha_fin", "serie", "valor", "unidad", "escala", "frecuencia",
          "nivel_verificacion", "fuente", "tabla", "candidate_id")]
}

## ---------------------------------------------------------------- externos ---
descargar_texto <- function(url, archivo_cache) {
  destino <- file.path(DIR_EXT, archivo_cache)
  dir.create(DIR_EXT, showWarnings = FALSE, recursive = TRUE)
  if (DESCARGAR) {
    tmp <- tempfile()
    ok <- tryCatch({ utils::download.file(url, tmp, quiet = TRUE, mode = "wb"); TRUE },
                   error = function(e) FALSE, warning = function(w) FALSE)
    if (ok && file.size(tmp) > 0) file.copy(tmp, destino, overwrite = TRUE)
    else message("Aviso: no se pudo descargar ", url, "; se usa la copia en caché.")
  }
  if (!file.exists(destino)) stop("Sin descarga ni caché para ", url)
  destino
}

## FRED sin clave: fredgraph.csv. `agregacion` = NULL (nativa) o "avg"/"eop" a mensual
leer_fred <- function(id, serie, agregacion = NULL, unidad = NA_character_) {
  url <- paste0("https://fred.stlouisfed.org/graph/fredgraph.csv?id=", id,
                if (!is.null(agregacion)) paste0("&fq=Monthly&fam=", agregacion) else "")
  f <- descargar_texto(url, paste0("FRED_", id, if (!is.null(agregacion)) paste0("_M_", agregacion) else "", ".csv"))
  x <- utils::read.csv(f, stringsAsFactors = FALSE, na.strings = c(".", ""))
  names(x) <- c("fecha", "valor")
  x$fecha <- as.Date(x$fecha)
  x <- x[!is.na(x$valor), ]
  d <- diff(sort(unique(x$fecha)))
  frec <- if (!is.null(agregacion)) "mensual" else if (median(as.numeric(d)) <= 5) "diaria" else
          if (median(as.numeric(d)) <= 31) "mensual" else if (median(as.numeric(d)) <= 92) "trimestral" else "anual"
  x$fecha_fin <- switch(frec,
    diaria = x$fecha,
    mensual = as.Date(sapply(x$fecha, function(z) seq(z, by = "month", length.out = 2)[2] - 1), origin = "1970-01-01"),
    trimestral = as.Date(sapply(x$fecha, function(z) seq(z, by = "3 months", length.out = 2)[2] - 1), origin = "1970-01-01"),
    anual = as.Date(sapply(x$fecha, function(z) seq(z, by = "year", length.out = 2)[2] - 1), origin = "1970-01-01"))
  data.frame(fecha = x$fecha, fecha_fin = x$fecha_fin, serie = serie, valor = x$valor,
             unidad = unidad, escala = NA_character_, frecuencia = frec,
             nivel_verificacion = "Externa (FRED), no verificada en la base",
             fuente = "FRED", tabla = id, candidate_id = paste0("fred:", id))
}

fin_de_mes <- function(f) as.Date(sapply(f, function(z) seq(z, by = "month", length.out = 2)[2] - 1),
                                  origin = "1970-01-01")

## ONI (NOAA CPC): media móvil de 3 meses de la anomalía Niño 3.4; se fecha en el mes central
leer_oni <- function() {
  f <- descargar_texto("https://www.cpc.ncep.noaa.gov/data/indices/oni.ascii.txt", "NOAA_oni.ascii.txt")
  x <- utils::read.table(f, header = TRUE, stringsAsFactors = FALSE)
  est <- c("DJF","JFM","FMA","MAM","AMJ","MJJ","JJA","JAS","ASO","SON","OND","NDJ")
  fecha <- as.Date(sprintf("%d-%02d-01", x$YR, match(x$SEAS, est)))
  rbind(
    data.frame(fecha = fecha, fecha_fin = fin_de_mes(fecha), serie = "oni", valor = x$ANOM,
               unidad = "GRADOS_C", escala = NA, frecuencia = "mensual",
               nivel_verificacion = "Externa (NOAA), no verificada en la base",
               fuente = "NOAA CPC", tabla = "oni.ascii.txt", candidate_id = "noaa:oni"),
    data.frame(fecha = fecha, fecha_fin = fin_de_mes(fecha), serie = "nino34_sst_3m", valor = x$TOTAL,
               unidad = "GRADOS_C", escala = NA, frecuencia = "mensual",
               nivel_verificacion = "Externa (NOAA), no verificada en la base",
               fuente = "NOAA CPC", tabla = "oni.ascii.txt", candidate_id = "noaa:oni_total"))
}

## RONI (ONI relativo, NOAA CPC) y anomalía mensual Niño 3.4 (sstoi.indices)
leer_roni <- function() {
  f <- descargar_texto("https://www.cpc.ncep.noaa.gov/data/indices/RONI.ascii.txt", "NOAA_RONI.ascii.txt")
  x <- utils::read.table(f, header = TRUE, stringsAsFactors = FALSE)
  est <- c("DJF","JFM","FMA","MAM","AMJ","MJJ","JJA","JAS","ASO","SON","OND","NDJ")
  fecha <- as.Date(sprintf("%d-%02d-01", x$YR, match(x$SEAS, est)))
  data.frame(fecha = fecha, fecha_fin = fin_de_mes(fecha), serie = "roni", valor = x$ANOM,
             unidad = "GRADOS_C", escala = NA, frecuencia = "mensual",
             nivel_verificacion = "Externa (NOAA), no verificada en la base",
             fuente = "NOAA CPC", tabla = "RONI.ascii.txt", candidate_id = "noaa:roni")
}
leer_nino34_mensual <- function() {
  f <- descargar_texto("https://www.cpc.ncep.noaa.gov/data/indices/sstoi.indices", "NOAA_sstoi.indices")
  x <- utils::read.table(f, header = FALSE, skip = 1)
  fecha <- as.Date(sprintf("%d-%02d-01", x[[1]], x[[2]]))
  data.frame(fecha = fecha, fecha_fin = fin_de_mes(fecha), serie = "nino34_anom_mensual", valor = x[[10]],
             unidad = "GRADOS_C", escala = NA, frecuencia = "mensual",
             nivel_verificacion = "Externa (NOAA), no verificada en la base",
             fuente = "NOAA CPC", tabla = "sstoi.indices", candidate_id = "noaa:nino34_anom")
}

## ----------------------------------------------------------------- salida ---
escribir_csv <- function(df, nombre, fecha_col = "fecha") {
  ruta <- file.path(DIR_DATOS, nombre)
  for (k in names(df)) if (inherits(df[[k]], "Date")) df[[k]] <- format(df[[k]], "%Y-%m-%d")
  utils::write.csv(df, ruta, row.names = FALSE, na = "", fileEncoding = "UTF-8")
  f <- if (fecha_col %in% names(df)) df[[fecha_col]] else NA
  MANIFIESTO[[nombre]] <<- data.frame(archivo = nombre, filas = nrow(df), columnas = ncol(df),
    desde = if (all(is.na(f))) NA else min(f, na.rm = TRUE),
    hasta = if (all(is.na(f))) NA else max(f, na.rm = TRUE))
  message(sprintf("  %-45s %8d filas", nombre, nrow(df)))
  invisible(ruta)
}

a_ancho <- function(largo) {
  fechas <- sort(unique(largo$fecha))
  series <- unique(largo$serie)
  out <- data.frame(fecha = fechas)
  for (s in series) {
    z <- largo[largo$serie == s, ]
    out[[s]] <- z$valor[match(fechas, z$fecha)]
  }
  out
}

## Escribe series_<frecuencia>.csv (largo) y series_<frecuencia>_ancho.csv, más el diccionario
escribir_series <- function(largo, dicc) {
  faltan <- setdiff(unique(largo$serie), dicc$serie)
  if (length(faltan)) stop("Series sin entrada en el diccionario: ", paste(faltan, collapse = ", "))
  largo <- largo[order(largo$frecuencia, largo$serie, largo$fecha), ]
  for (fr in unique(largo$frecuencia)) {
    z <- largo[largo$frecuencia == fr, ]
    escribir_csv(z, paste0("series_", fr, ".csv"))
    escribir_csv(a_ancho(z), paste0("series_", fr, "_ancho.csv"))
  }
  res <- do.call(rbind, lapply(split(largo, largo$serie), function(z) data.frame(
    serie = z$serie[1], frecuencia = z$frecuencia[1], desde = min(z$fecha), hasta = max(z$fecha),
    n_obs = nrow(z), unidad = paste(unique(na.omit(z$unidad)), collapse = "/"),
    escala = paste(unique(na.omit(z$escala)), collapse = "/"),
    nivel_verificacion = z$nivel_verificacion[1], fuente = z$fuente[1],
    tabla = paste(unique(z$tabla), collapse = " + "), candidate_id = z$candidate_id[1])))
  d <- merge(dicc[, c("serie", "descripcion", "rol")], res, by = "serie", all.y = TRUE)
  d <- d[order(match(d$serie, dicc$serie)), ]
  escribir_csv(d, "diccionario_series.csv", fecha_col = "desde")
  invisible(d)
}

cerrar <- function(con) {
  meta <- tryCatch(dbGetQuery(con, "SELECT (SELECT max(version) FROM audit.schema_version) AS esquema,
                                            (SELECT data_release_id FROM audit.active_data_release) AS release"),
                   error = function(e) data.frame(esquema = NA, release = NA))
  dbDisconnect(con, shutdown = TRUE)
  m <- do.call(rbind, MANIFIESTO)
  m$generado <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  m$esquema_base <- meta$esquema
  m$release_base <- meta$release
  utils::write.csv(m, file.path(DIR_DATOS, "00_manifiesto.csv"), row.names = FALSE, na = "", fileEncoding = "UTF-8")
  message("Listo: ", nrow(m), " archivos en ", DIR_DATOS)
}

## Paneles banco/financiera-mes: fecha publicada = fin de mes -> fecha = inicio de mes
fechas_panel <- function(df, col = "fecha") {
  f <- as.Date(df[[col]])
  df$fecha_fin <- f
  df$fecha <- as.Date(format(f, "%Y-%m-01"))
  df[, c("fecha", "fecha_fin", setdiff(names(df), c("fecha", "fecha_fin")))]
}

## ============================================================================
## Nombre corto a partir de una etiqueta
slug <- function(x, n = 70) {
  x <- chartr("áéíóúÁÉÍÓÚñÑüÜ", "aeiouAEIOUnNuU", enc2utf8(x))
  x <- gsub("< *=|≤", " hasta ", x); x <- gsub("> *=|≥", " desde ", x)
  x <- gsub("<", " menos ", x); x <- gsub(">", " mas ", x); x <- gsub("%", " pct ", x)
  x <- iconv(x, from = "UTF-8", to = "ASCII", sub = "")
  x <- tolower(gsub("[^A-Za-z0-9]+", "_", x))
  substr(gsub("^_+|_+$", "", x), 1, n)
}

## Todas las series escalares (con observaciones) de una o varias hojas de una fuente
spec_por_hoja <- function(con, fuente, hojas, prefijo, rol,
                          frecuencias = c("monthly", "monthly_survey")) {
  s <- dbGetQuery(con, sprintf(
    "SELECT c.candidate_id, c.researcher_name, trim(c.source_sheet) AS hoja
       FROM catalog.series c
      WHERE c.source_id = '%s' AND trim(c.source_sheet) IN (%s) AND c.frequency IN (%s)
        AND c.data_structure = 'scalar_series'
        AND EXISTS (SELECT 1 FROM main.v_series_research r WHERE r.series_id = c.candidate_id)
      ORDER BY hoja, c.researcher_name, c.candidate_id",
    fuente, sql_lista(hojas), sql_lista(frecuencias)))
  if (!nrow(s)) stop("Sin series para ", fuente, " / ", paste(hojas, collapse = ", "))
  s <- s[!duplicated(s$candidate_id), ]
  data.frame(serie = make.unique(paste0(prefijo, "_", slug(paste(s$hoja, s$researcher_name))), sep = "_"),
             candidate_id = s$candidate_id,
             descripcion = paste0(fuente, " hoja ", s$hoja, ": ", s$researcher_name),
             rol = rol, stringsAsFactors = FALSE)
}

## Curvas (CDA, bonos corporativos) en formato largo desde explore.curve_observations
extraer_curvas <- function(con, fuente) {
  x <- dbGetQuery(con, sprintf(
    "SELECT CAST(reference_period_start AS DATE) AS fecha, CAST(reference_period_end AS DATE) AS fecha_fin,
            source_sheet AS hoja, researcher_name AS nodo, value AS valor, unit_code AS unidad,
            validation_tier, candidate_id
       FROM explore.curve_observations WHERE source_id = '%s'
      ORDER BY fecha, hoja, nodo", fuente))
  x$nivel_verificacion <- nivel_verificacion(x$validation_tier, NA); x$validation_tier <- NULL
  x
}

## Datos manuales (calendarios institucionales, fechas de normas, etc.) en datos_manuales/<nombre>.csv.
## Si el archivo no existe se crea una plantilla (vacía o con filas candidatas marcadas "no verificado");
## nunca se sobrescribe un archivo existente. Las columnas que empiezan con "fecha" deben ser AAAA-MM-DD.
leer_manual <- function(nombre, columnas, ejemplo = NULL) {
  dir <- file.path(DIR_PROYECTO, "datos_manuales")
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  f <- file.path(dir, paste0(nombre, ".csv"))
  if (!file.exists(f)) {
    plantilla <- if (is.null(ejemplo)) {
      as.data.frame(setNames(replicate(length(columnas), character(0), simplify = FALSE), columnas))
    } else ejemplo[, columnas]
    utils::write.csv(plantilla, f, row.names = FALSE, na = "", fileEncoding = "UTF-8")
    message("  Plantilla creada: datos_manuales/", nombre, ".csv")
  }
  x <- utils::read.csv(f, stringsAsFactors = FALSE, colClasses = "character", na.strings = "", encoding = "UTF-8")
  faltan <- setdiff(columnas, names(x))
  if (length(faltan)) stop("Faltan columnas en datos_manuales/", nombre, ".csv: ", paste(faltan, collapse = ", "))
  x <- x[rowSums(!is.na(x[, columnas, drop = FALSE]) & x[, columnas, drop = FALSE] != "") > 0, , drop = FALSE]
  if (!nrow(x)) { message("  datos_manuales/", nombre, ".csv está vacío: complételo y vuelva a correr."); return(NULL) }
  for (k in grep("^fecha", names(x), value = TRUE)) {
    d <- as.Date(x[[k]], format = "%Y-%m-%d")
    if (any(is.na(d) & !is.na(x[[k]]))) stop("Fechas inválidas en ", nombre, ".csv, columna ", k, " (use AAAA-MM-DD)")
    x[[k]] <- d
  }
  escribir_csv(x, paste0("manual_", nombre, ".csv"), fecha_col = grep("^fecha", names(x), value = TRUE)[1])
  x
}

## Descarga un bloque de FRED definido como data.frame(serie, id, agregacion, unidad, ...)
leer_fred_bloque <- function(externos) {
  do.call(rbind, lapply(seq_len(nrow(externos)), function(i) {
    e <- externos[i, ]
    leer_fred(e$id, e$serie, if (is.na(e$agregacion) || e$agregacion == "") NULL else e$agregacion, e$unidad)
  }))
}

## ============================================================================
## Especificación del proyecto
## ============================================================================
## Proyecto 26 · N5 (nuevo) — Shocks cambiarios de Argentina y economía fronteriza paraguaya
## Devaluaciones y controles cambiarios argentinos como shocks grandes, fechados y externos:
## tipo de cambio PYG/ARS, comercio bilateral (Anexo e IMTS), importaciones bajo régimen de turismo
## (reexportación), precios transables, remesas desde Argentina. Brasil como placebo parcial.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
pyg_ars,economic_annex:cuadro_60a:2758fed7ea57c524cd0fcb0c,PYG por ARS (promedio mensual; Cuadro 60a),Shock: tipo de cambio bilateral
pyg_brl,economic_annex:cuadro_60a:2442b69bab143106463ed144,PYG por BRL (Cuadro 60a),Placebo / control regional
pyg_usd_prom_venta,exchange_rates:usd_prom:190c4a9509f6c233bdc28928,PYG por USD promedio mensual,Control
tcr_argentina,economic_annex:cuadro_60c:8ec28511cf3e35f6d413c26f,Tipo de cambio real bilateral con Argentina,Shock real (gap de precios)
tcr_brasil,economic_annex:cuadro_60c:df5674f2dacbbc4d470c3175,Tipo de cambio real bilateral con Brasil,Placebo
ars_usd_prom,imf_er:c45a0a7edaa90b29d3564005,FMI: ARS por USD promedio mensual (oficial),Shock: devaluación oficial argentina
brl_usd_prom,imf_er:13f5f115b7431dbad5fcb4b6,FMI: BRL por USD promedio mensual,Placebo
ipc_argentina,imf_cpi:e3b883567e33f043224c1a88,FMI: IPC Argentina (desde dic-2016),Precios del vecino
ipc_brasil,imf_cpi:ba03fe4dcdde13d15e4126f3,FMI: IPC Brasil,Precios del vecino (placebo)
tpm_argentina,imf_mfs_ir:0ea7d6c5d48ac4a212348a2b,FMI: tasa de política Argentina,Contexto del shock
expo_argentina,economic_annex:cuadro_45:176082e3d76511cb8de20384,Exportaciones registradas a Argentina (miles USD),Resultado: comercio
expo_brasil,economic_annex:cuadro_45:67e8920792be474187167d91,Exportaciones registradas a Brasil,Placebo
expo_total,economic_annex:cuadro_45:bf8595a1dd956a764d20c6a1,Exportaciones registradas totales,Normalización
impo_argentina,economic_annex:cuadro_50:176082e3d76511cb8de20384,Importaciones registradas desde Argentina (miles USD),Resultado: comercio
impo_brasil,economic_annex:cuadro_50:67e8920792be474187167d91,Importaciones registradas desde Brasil,Placebo
impo_total,economic_annex:cuadro_50:bf8595a1dd956a764d20c6a1,Importaciones registradas totales,Normalización
remesas_argentina,economic_annex:cuadro_58:ef41d4327ef626b39b618ef8,Remesas familiares desde Argentina (miles USD),Resultado: ingreso de hogares
remesas_total,economic_annex:cuadro_58:936554c066082e51a38ba32e,Remesas familiares totales,Normalización
ipc_indice,economic_annex:cuadro_14:a5d7fc4139616340def083cc,IPC Paraguay índice general,Resultado: precios
ipc_transables_sin_fyv,economic_annex:cuadro_14_a:1f5d8129468fa2246f4ef067,IPC transables sin frutas y verduras,Resultado: precios transables
ipc_no_transables,economic_annex:cuadro_14_a:14eda4efc6655f8715834492,IPC no transables,Placebo (no transables)
ipc_importados_sin_fyv,economic_annex:cuadro_14_a:907533be614b9497d5409ff9,IPC importados sin frutas y verduras,Resultado: precios importados
ipc_alimentos_div,economic_annex:cuadro_14:744a94962b4d73e447cb93ed,IPC alimentos y bebidas no alcohólicas,Resultado: bienes de frontera
ipc_vestido_div,economic_annex:cuadro_14:99ae18dcab4a9573cd1b207d,IPC prendas de vestir y calzado,Resultado: bienes de frontera
ipc_carne_vacuna,economic_annex:cuadro_16_a:b0212ed6375596572608dc92,IPC carne vacuna,Resultado: bien exportado a Argentina / arbitraje
imaep_original,economic_annex:cuadro_9:fc9a02c5dcc0573b3c038553,IMAEP serie original,Control / resultado agregado
", stringsAsFactors = FALSE, strip.white = TRUE)

con <- conectar()
bloques <- rbind(
  spec_por_hoja(con, "economic_annex", "Cuadro 52a", "impo_turismo_usd", "Importaciones uso interno y régimen de turismo (miles USD): canal de reexportación"),
  spec_por_hoja(con, "economic_annex", "Cuadro 54", "impo_regimen", "Importaciones por régimen aduanero (miles USD)"))
spec <- rbind(dicc, bloques)
x <- extraer_escalares(con, spec)
escribir_series(x, spec)
cerrar(con)

message("Episodios candidatos: meses con devaluación oficial argentina > 10%...")
ars <- x[x$serie == "ars_usd_prom", ]; ars <- ars[order(ars$fecha), ]
ars$dev_mensual_pct <- c(NA, 100 * diff(log(ars$valor)))
epi <- ars[!is.na(ars$dev_mensual_pct) & ars$dev_mensual_pct > 10 & ars$fecha >= as.Date("1995-01-01"),
           c("fecha", "valor", "dev_mensual_pct")]
names(epi)[2] <- "ars_por_usd"
epi$nota <- "Inferido de la serie oficial (FMI); no captura el tipo de cambio paralelo"
escribir_csv(epi, "episodios_devaluacion_argentina_inferidos.csv")

message("Comercio bilateral Paraguay-Argentina y Paraguay-Brasil (IMTS, FMI; fuera de la base)...")
f_imts <- file.path(RUTA_INPUT, "IMF_Data", "International Trade in Goods (by partner country) (IMTS).csv")
if (file.exists(f_imts)) {
  lin <- readLines(f_imts, encoding = "UTF-8", warn = FALSE)
  limpiar <- function(l) { l <- sub("^﻿", "", l); ifelse(grepl('^".*"$', l), gsub('""', '"', substr(l, 2, nchar(l) - 1)), l) }
  hdr <- scan(text = limpiar(lin[1]), what = "", sep = ",", quiet = TRUE)
  pry <- lin[grepl("Paraguay", lin, fixed = TRUE) & (grepl("Argentina", lin, fixed = TRUE) | grepl("Brazil", lin, fixed = TRUE))]
  tab <- utils::read.csv(text = limpiar(pry), header = FALSE, col.names = hdr, check.names = FALSE, colClasses = "character", na.strings = "")
  tab <- tab[tab$COUNTRY == "Paraguay" & tab$FREQUENCY == "Monthly" & tab$COUNTERPART_COUNTRY %in% c("Argentina", "Brazil") &
             grepl("^(Exports of goods|Imports of goods, Cost)", tab$INDICATOR), ]
  mcols <- grep("^[0-9]{4}-M[0-9]{2}$", names(tab), value = TRUE)
  imts <- do.call(rbind, lapply(mcols, function(k) {
    v <- suppressWarnings(as.numeric(tab[[k]])); ok <- !is.na(v); if (!any(ok)) return(NULL)
    data.frame(fecha = as.Date(paste0(substr(k, 1, 4), "-", substr(k, 7, 8), "-01")),
               flujo = ifelse(grepl("^Exports", tab$INDICATOR[ok]), "exportaciones_fob", "importaciones_cif"),
               socio = tab$COUNTERPART_COUNTRY[ok], valor_millones_usd = v[ok], codigo_fmi = tab$SERIES_CODE[ok])
  }))
  imts$nivel_verificacion <- "Fuera de la base (CSV FMI en input/current; sin parser ni validación)"
  escribir_csv(imts[order(imts$flujo, imts$socio, imts$fecha), ], "comercio_bilateral_imts.csv")
} else message("Aviso: no se encontró el archivo IMTS; se omite.")

ejemplo <- data.frame(
  fecha_evento = c("2014-01-23", "2015-12-17", "2018-04-25", "2018-08-30", "2019-08-12", "2019-09-01", "2023-08-14", "2023-12-13", "2025-04-14"),
  evento = c("Devaluación del peso oficial", "Fin del cepo y unificación cambiaria", "Inicio de la crisis cambiaria 2018",
             "Salto del tipo de cambio (crisis 2018)", "Shock posterior a las PASO", "Restablecimiento del cepo cambiario", "Devaluación posterior a las PASO 2023",
             "Devaluación del tipo de cambio oficial", "Flexibilización del cepo y régimen de bandas"),
  tipo = c("devaluacion", "liberalizacion", "devaluacion", "devaluacion", "devaluacion", "control_cambiario", "devaluacion", "devaluacion", "liberalizacion"),
  magnitud_aprox = "", fuente = "Memoria del analista (Claude); completar con BCRA/prensa",
  estado_verificacion = "no verificado", stringsAsFactors = FALSE)
message("Calendario de eventos cambiarios argentinos (manual; plantilla con candidatos NO verificados)...")
MANIFIESTO_BAK <- MANIFIESTO
leer_manual("eventos_argentina", c("fecha_evento", "evento", "tipo", "magnitud_aprox", "fuente", "estado_verificacion"), ejemplo)
m <- do.call(rbind, MANIFIESTO); m$generado <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
prev <- utils::read.csv(file.path(DIR_DATOS, "00_manifiesto.csv"), stringsAsFactors = FALSE)
m$esquema_base <- prev$esquema_base[1]; m$release_base <- prev$release_base[1]
utils::write.csv(m, file.path(DIR_DATOS, "00_manifiesto.csv"), row.names = FALSE, na = "", fileEncoding = "UTF-8")
