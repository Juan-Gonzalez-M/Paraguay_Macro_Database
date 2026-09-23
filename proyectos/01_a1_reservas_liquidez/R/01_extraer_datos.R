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
## Proyecto 01 · A1 — Demanda de reservas y huella de liquidez de operaciones FX
## "Reservas" = reservas de los bancos en el BCP (encaje + cuenta corriente);
## las reservas internacionales entran solo como control.

ea <- "economic_annex:"
dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,Tasa de política monetaria (promedio del mes; etiqueta de la base contaminada),Política: nivel del corredor
fpl_tasa,economic_annex:cuadro_19:fc0d3e91762b1e49e7c60de2,Facilidad permanente de liquidez: tasa promedio ponderada,Techo del corredor
fpl_monto,economic_annex:cuadro_19:fe22911e7e25fb577e0e11aa,Facilidad permanente de liquidez: monto promedio,Uso de facilidades (resultado)
fpd_tasa,economic_annex:cuadro_19:3f0cf05cf3e314e3723dc6d9,Facilidad permanente de depósito: tasa promedio ponderada,Piso del corredor
fpd_monto,economic_annex:cuadro_19:a4c28f3ee786b7b8bee93995,Facilidad permanente de depósito: monto promedio,Uso de facilidades (resultado)
tib_mensual,economic_annex:cuadro_19:b3cda7014d948e51eb7adc50,Tasa interbancaria promedio del mes,Resultado: spread TIB - TPM
irm_colocado_7_53d,economic_annex:cuadro_19:f46fbf29ee24ff2db287707c,IRM: monto colocado 7-53 días,Esterilización
irm_colocado_54_105d,economic_annex:cuadro_19:c8db7cd5afebbea97ba012b6,IRM: monto colocado 54-105 días,Esterilización
irm_colocado_106_213d,economic_annex:cuadro_19:fea38bcbc4f4dfa6f67bcdfc,IRM: monto colocado 106-213 días,Esterilización
irm_colocado_214_455d,economic_annex:cuadro_19:3f5aa0a18be3af2c4ee78163,IRM: monto colocado 214-455 días,Esterilización
irm_colocado_456_728d,economic_annex:cuadro_19:47af8c31cfe1c6ae89ddaef5,IRM: monto colocado 456-728 días,Esterilización
irm_colocado_total,economic_annex:cuadro_19:57803c7f7ce6878c1ad0b5b3,IRM: total colocado en el mes (etiqueta contaminada con '456 a 728'),Esterilización (flujo)
irm_saldo,economic_annex:cuadro_19:c6b004df42fbf4677d7e4272,IRM: saldo a fin de mes (etiqueta contaminada con '456 a 728'),Esterilización (stock)
irm_rend_ponderado,economic_annex:cuadro_19:e026b8621200b0bd86ff8222,IRM: rendimiento promedio ponderado % (la base marca escala 'millions' por error),Costo de esterilización
irm_tasa_7_53d,economic_annex:cuadro_19:d2df2aa861a714464e439e44,IRM: tasa 7-53 días,Curva corta del BCP
irm_tasa_54_105d,economic_annex:cuadro_19:e6f771bffc66a1526cba9eed,IRM: tasa 54-105 días,Curva corta del BCP
irm_tasa_106_213d,economic_annex:cuadro_19:a756f870544a4cf0005bd461,IRM: tasa 106-213 días,Curva corta del BCP
irm_tasa_214_455d,economic_annex:cuadro_19:1a1cd1fa97e8e3b688c5c497,IRM: tasa 214-455 días,Curva corta del BCP
irm_tasa_456_728d,economic_annex:cuadro_19:889ec3ea7088fbd5b663f56e,IRM: tasa 456-728 días,Curva corta del BCP
bancos_encaje_mn,economic_annex:cuadro_27:1c63a4cb41004337fa196728,Depósitos de bancos en el BCP: encaje legal MN,Reservas bancarias (variable central)
bancos_encaje_me,economic_annex:cuadro_27:00327fb5cb588d371dfa5379,Depósitos de bancos en el BCP: encaje legal ME (en millones de Gs.; unidad no resuelta en la base),Reservas bancarias ME
bancos_ctacte_mn,economic_annex:cuadro_27:c8a9b0c71e4e66dff210d94c,Depósitos de bancos en el BCP: cuenta corriente MN,Reservas excedentes (variable central)
bancos_ctacte_me,economic_annex:cuadro_27:17b0fa4f4c476d7cf768bbaf,Depósitos de bancos en el BCP: cuenta corriente ME,Reservas excedentes ME
resto_sf_encaje_mn,economic_annex:cuadro_27:b22847132af352e8fd9e57ec,Depósitos del resto del sistema financiero en el BCP: encaje MN,Reservas (financieras)
resto_sf_encaje_me,economic_annex:cuadro_27:b202b7449603e63a65af83e3,Depósitos del resto del sistema financiero en el BCP: encaje ME,Reservas (financieras)
resto_sf_obligaciones,economic_annex:cuadro_27:83385b03bdfd86661a319f9a,Depósitos del resto del sistema financiero: obligaciones con el resto,Reservas (financieras)
credito_bcp_bancos,economic_annex:cuadro_27:478091b79252bf99eec909f3,Crédito del BCP al sistema bancario,Provisión de liquidez
credito_bcp_resto_sf,economic_annex:cuadro_27:851b0f5e17a793cd3951ef01,Crédito del BCP al resto del sistema financiero,Provisión de liquidez
posicion_neta_resto_sf,economic_annex:cuadro_27:4c4b3b766a26ed2641495d72,Posición neta del BCP con el resto del sistema financiero,Provisión de liquidez
base_monetaria,economic_annex:cuadro_21:2bf58454c90affb85cd6091b,Base monetaria,Identidad de liquidez
billetes_monedas,economic_annex:cuadro_21:b8ce2b9f8e9025fdccf7e5f5,M0: billetes y monedas en circulación,Identidad de liquidez (demanda de efectivo)
dep_adm_central_bcp,economic_annex:cuadro_35:f907a1e096fb65a973d56cf0,Depósitos de la Administración Central en el BCP (total),Flujos del Tesoro (proxy)
gasto_remun_irm,economic_annex:cuadro_26:2df5f0d344b919a22c820b55,Gasto de política monetaria: remuneración por IRM,Costo de esterilización
gasto_remun_encaje_mn,economic_annex:cuadro_26:a5a0376103c224b5640c8773,Gasto de política monetaria: remuneración del encaje MN,Costo de reservas
bcp_fx_neto_total_m,economic_annex:cuadro_20:7b59d8ba436a0b3c68fb07fd,Operaciones cambiarias netas totales del BCP (mensual),Liquidez inyectada por FX
bcp_fx_neto_financiero_m,economic_annex:cuadro_20:00f3d90c3b3a0f40d972cfe1,Operaciones cambiarias netas del BCP con el sector financiero,Liquidez inyectada por FX
bcp_fx_neto_publico_m,economic_annex:cuadro_20:b19650e61d3f12d0e70674cb,Operaciones cambiarias netas del BCP con el sector público,Liquidez (Tesoro)
rin_saldo,economic_annex:cuadro_56b:f51d08d7995561bfce2166eb,Reservas internacionales netas: saldo,Control (no es la variable central)
sipap_interbancario_pyg_monto,payments:sipap_01:a972cb808e07f638f05bee72,LBTR: transferencias entre entidades financieras PYG (importe),Actividad de pagos interbancarios
sipap_interbancario_pyg_cant,payments:sipap_01:f97c57c61e9dc5e9d2695802,LBTR: transferencias entre entidades financieras PYG (cantidad),Actividad de pagos interbancarios
bcp_fx_compra_total_d,bcp_fx_daily:op_divisas_datos_diarios:10aa9337ca44858e6554071b,Compra diaria de divisas del BCP: total,Shock de liquidez FX (diario)
bcp_fx_venta_total_d,bcp_fx_daily:op_divisas_datos_diarios:2e11e6bedf4350e619bbfcb6,Venta diaria de divisas del BCP: total,Shock de liquidez FX (diario)
bcp_fx_neto_financiero_d,bcp_fx_daily:op_divisas_datos_diarios:5aa4e7262dee69adde87a3ae,Compras netas diarias del BCP al sector financiero,Shock de liquidez FX (diario)
bcp_fx_neto_publico_d,bcp_fx_daily:op_divisas_datos_diarios:3c951804d5e93c97589a95e2,Compras netas diarias del BCP al sector público,Liquidez del Tesoro (diario)
bcp_fx_neto_total_d,bcp_fx_daily:op_divisas_datos_diarios:542ac0ab6cb137a1139018b2,Compras netas diarias sector público + financiero,Shock de liquidez FX (diario)
tcn_venta,tcn_referential_daily:tcn_referencial_daily:5fc9eaa0817a8a6ece9666c4,Tipo de cambio referencial PYG/USD venta,Control
", stringsAsFactors = FALSE, strip.white = TRUE)

dicc_ev <- read.csv(text = "
serie,candidate_id,descripcion,rol
tib_d_tasa_prom,interbank_market:datos:bcc5aacb9d75d1afe2f27ed0,Mercado interbancario PYG (call + REPO interbancario + tripartito): tasa promedio,Resultado: spread diario
tib_d_tasa_min,interbank_market:datos:cc59a9e40de39ee404db9395,Mercado interbancario PYG: tasa mínima,Dispersión
tib_d_tasa_max,interbank_market:datos:45e90acb61692b08c4ef5759,Mercado interbancario PYG: tasa máxima,Dispersión
tib_d_monto,interbank_market:datos:4a607dcf6c954a30f3f2375f,Mercado interbancario PYG: monto,Cantidad negociada
tib_d_n_operaciones,interbank_market:datos:472fa025e457e48e8f66943d,Mercado interbancario PYG: número de transacciones,Actividad
tib_d_n_participantes,interbank_market:datos:8d272da5a2fbde144388aaad,Mercado interbancario PYG: número de participantes,Actividad
repo_interb_tasa_prom,interbank_market:datos:f9593693ffd0590725b89ee7,REPO interbancario PYG: tasa promedio,Componente
repo_interb_monto,interbank_market:datos:3747989b3ad1abc7e90e4f97,REPO interbancario PYG: monto,Componente
repo_tripart_tasa_prom,interbank_market:datos:31c1e4c711ef0c3cb2bbc6cd,REPO tripartito PYG: tasa promedio,Componente
repo_tripart_monto,interbank_market:datos:e735507ac65fe95be57a044b,REPO tripartito PYG: monto VLI (millones Gs.),Componente
call_usd_tasa_prom,interbank_market:datos:b577ca875b5a111a7232aa45,Call money USD: tasa promedio,Liquidez en dólares
call_usd_monto,interbank_market:datos:8995dee2b2f1ae20e56458ea,Call money USD: monto,Liquidez en dólares
fpl_d_tasa,interbank_market:datos:54054828ef6167893989ed71,FPL: tasa diaria,Techo del corredor (diario)
fpl_d_tasa_tramo1,interbank_market:datos:d00478f1dc4bc808934a2e86,FPL primer tramo: tasa,Techo del corredor (diario)
fpl_d_tasa_tramo2,interbank_market:datos:f212c5ee88afeb1f0e6fb205,FPL segundo tramo: tasa,Techo del corredor (diario)
fpd_d_tasa,interbank_market:datos:22e19406c0223e679659af0d,FPD: tasa diaria,Piso del corredor (diario)
fpd_d_monto,interbank_market:datos:26b14fc2ce33fb5cbbfeb095,FPD: monto adjudicado (millones Gs.),Uso de facilidades (diario)
haircut,interbank_market:datos:c9a24050123f53f41de2158e,Coeficiente de cobertura (haircut),Regla de colateral
", stringsAsFactors = FALSE, strip.white = TRUE)

con <- conectar()
message("Extrayendo series escalares...")
x <- extraer_escalares(con, dicc)
message("Extrayendo series diarias del mercado interbancario...")
y <- extraer_eventos_diarios(con, dicc_ev)
escribir_series(rbind(x, y), rbind(dicc, dicc_ev))

message("Eventos: subastas de LRM y facilidad de liquidez de corto plazo...")
ev <- dbGetQuery(con, "
  SELECT CAST(reference_period_start AS DATE) AS fecha, source_id AS fuente, source_sheet AS hoja,
         full_series_path AS detalle, researcher_name AS variable, value AS valor, unit_code AS unidad,
         validation_tier, candidate_id, source_row
    FROM explore.events WHERE source_id IN ('lrm_auctions', 'liquidity_facility')
   ORDER BY source_id, reference_period_start, candidate_id")
ev$nivel_verificacion <- nivel_verificacion(ev$validation_tier, NA); ev$validation_tier <- NULL
escribir_csv(ev[ev$fuente == "lrm_auctions", ], "eventos_subastas_lrm.csv")
escribir_csv(ev[ev$fuente == "liquidity_facility", ], "eventos_facilidad_liquidez.csv")

message("Panel banco/financiera-mes: posiciones con el BCP, liquidez y depósitos...")
pan <- dbGetQuery(con, "
  SELECT source_id AS tipo_entidad, fecha, entity_id, short_name AS entidad,
         semantic_rubro AS rubro, sub_rubro, codigo_moneda, currency_of_origin AS moneda_origen,
         importe AS importe_pyg
    FROM (SELECT * FROM main.v_banks_eeff_documented UNION ALL BY NAME
          SELECT * FROM main.v_financial_eeff_documented)
   WHERE semantic_rubro IN ('1.1. Caja y Bancos','1.2. BCP - Activo','1.3. Inv. en Valores','1.4. Coloc. Netas',
                            '2.1. Depósitos','2.3. BCP - Pasivo','2.5. Interbancarios')
   ORDER BY tipo_entidad, fecha, entity_id, rubro, sub_rubro, codigo_moneda")
pan <- fechas_panel(pan); pan$nivel_verificacion <- "Panel provisional"
escribir_csv(pan, "panel_eeff_liquidez_entidad_mes.csv")
rat <- dbGetQuery(con, "
  SELECT source_id AS tipo_entidad, fecha, codigo_entidad, sub_rubro AS ratio, total AS valor
    FROM (SELECT * FROM main.v_latest_raw_banks_ratios UNION ALL BY NAME SELECT * FROM main.v_latest_raw_financial_ratios)
   WHERE sub_rubro IN ('Disponible + Inversiones Temporales/Depósitos','Disponible + Inversiones Temporales/Pasivos',
                       'Cartera Vencida/Cartera Total - Morosidad','Relación entre TIER 1/ACPR')
   ORDER BY 1,2,3,4")
rat <- fechas_panel(rat); rat$nivel_verificacion <- "Panel provisional"
escribir_csv(rat, "panel_ratios_liquidez_entidad_mes.csv")
cerrar(con)
