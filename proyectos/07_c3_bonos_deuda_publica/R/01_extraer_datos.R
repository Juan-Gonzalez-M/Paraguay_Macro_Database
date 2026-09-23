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
## Proyecto 07 · C3 — Bonos corporativos, crédito bancario y deuda pública
## Dos módulos separados: (a) spread bono-banco; (b) deuda pública y subastas.
## Curvas NSS de bonos corporativos (research.curves), curva CDA, transacciones bursátiles
## de instrumentos de deuda (research.transactions), mercado secundario de LRM/bonos y subastas de LRM.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,Tasa de política monetaria,Condición monetaria (explicativa)
c31_mn_activa_prom,economic_annex:cuadro_31:c90c5c9c2ec39acfaed4ff16,Tasa efectiva activa MN promedio (sin tarjetas ni sobregiros; etiqueta contaminada),Tasa bancaria de referencia MN
c31_me_activa_prom,economic_annex:cuadro_31_cont:eaf763baa29bd5845926073b,Tasa efectiva activa ME promedio ponderado,Tasa bancaria de referencia ME
c31_me_pasiva_cda,economic_annex:cuadro_31_cont:471798dff0fbf8cce6e28cce,Tasa efectiva pasiva ME CDA,Costo de fondeo bancario ME
deuda_ext_saldo,economic_annex:cuadro_59:e5c2a05e30651e100a3dc1e7,Deuda pública externa: saldo (miles de USD),Oferta de deuda pública (stock)
deuda_ext_desembolsos,economic_annex:cuadro_59:f9c2e28f029232cc280c33bc,Deuda pública externa: desembolsos,Oferta de deuda pública (flujo)
deuda_ext_servicio,economic_annex:cuadro_59:69307e03162e952cb9a46553,Deuda pública externa: pagos de capital e intereses,Servicio de deuda
fiscal_financiamiento_neto,mef_central_government:serie:360944a8298772c084d758da,Administración Central: incurrimiento neto de pasivos,Necesidad de financiamiento del Tesoro
fiscal_financiamiento_interno,mef_central_government:serie:0a018056482e619181d731fb,Administración Central: financiamiento interno (incurrimiento de pasivos),Oferta local de deuda pública
fiscal_financiamiento_externo,mef_central_government:serie:98de68d5e2727de6c4025229,Administración Central: financiamiento externo,Oferta externa de deuda pública
fiscal_intereses,mef_central_government:serie:58c4415b123ad9470009c434,Administración Central: gasto en intereses,Costo de la deuda
fiscal_balance,mef_central_government:serie:8d3088bf00ff46c755b66e9d,Administración Central: préstamo neto / endeudamiento neto,Necesidad de financiamiento
bva_total_operacion,economic_annex:cuadro_32:5592ee1b8212b9878d3cd2ab,Bolsa de Valores: total operado (millones de Gs.; etiqueta contaminada),Liquidez del mercado
bva_bonos,economic_annex:cuadro_32:4b50e297688d658d9de4ca28,Bolsa de Valores: bonos en PYG (etiqueta contaminada),Liquidez del mercado de bonos
bva_bonos_usd,economic_annex:cuadro_32:96baa49a13e1b2f51f4669a5,Bolsa de Valores: bonos en USD (etiqueta contaminada),Liquidez del mercado de bonos
bva_custodia_total,economic_annex:cuadro_32_a:bf8595a1dd956a764d20c6a1,Documentos en custodia: total (millones de Gs.),Stock del mercado
bva_custodia_bono,economic_annex:cuadro_32_a:1e33613420bc47f1b07dad92,Documentos en custodia: bonos,Stock de bonos
bva_custodia_bono_financiero,economic_annex:cuadro_32_a:d2cb0dc67412f1258f2887d5,Documentos en custodia: bonos financieros,Stock de bonos bancarios
bva_custodia_bono_subordinado,economic_annex:cuadro_32_a:beb4202973702f3b4308b44d,Documentos en custodia: bonos subordinados,Stock de bonos bancarios
bva_custodia_bbcp,economic_annex:cuadro_32_a:160591a737b8a78ea214b4b6,Documentos en custodia: bonos del BCP,Stock de papeles del BCP
pyg_usd_prom_venta,exchange_rates:usd_prom:190c4a9509f6c233bdc28928,PYG por USD promedio mensual,Conversión
ipc_var_interanual,economic_annex:cuadro_15:080dbf95a46f3bcb97aeb69d,Inflación total interanual,Tasas reales
eve_tpm_anio_t,eve:tasa_de_politica_monetaria_tpm:expectativa_ano_t,EVE (mediana): TPM esperada fin de año,Trayectoria esperada de tasas
", stringsAsFactors = FALSE, strip.white = TRUE)

externos <- read.csv(text = "
serie,id,agregacion,unidad,descripcion,rol
ust_10a,DGS10,avg,PERCENT,FRED: rendimiento Tesoro EE.UU. 10 años (promedio mensual),Tasa libre de riesgo global (bonos en USD)
ust_2a,DGS2,avg,PERCENT,FRED: rendimiento Tesoro EE.UU. 2 años (promedio mensual),Tasa libre de riesgo global
", stringsAsFactors = FALSE, strip.white = TRUE, na.strings = "")

con <- conectar()
tasas <- spec_por_hoja(con, "financial_indicators", "2.2", "tef_plazo_bancos", "Tasa bancaria por producto, plazo y moneda (comparación con bonos)")
spec <- rbind(dicc, tasas)
x <- extraer_escalares(con, spec)
ext <- leer_fred_bloque(externos)
escribir_series(rbind(x, ext), rbind(spec[, c("serie", "descripcion", "rol")], externos[, c("serie", "descripcion", "rol")]))

message("Curvas de bonos corporativos (NSS) y curva CDA...")
cur <- dbGetQuery(con, "
  SELECT CAST(period AS DATE) AS fecha, currency AS moneda, risk_rating AS calificacion, maturity_years AS plazo_anios,
         zero_coupon_rate AS tasa_cero, par_rate AS tasa_par, discount_factor AS factor_descuento,
         beta0, beta1, beta2, beta3, lambda1, lambda2, assurance_level, source_row
    FROM research.curves ORDER BY fecha, moneda, calificacion, plazo_anios")
cur$nivel_verificacion <- "Validada por regla (estructural)"
escribir_csv(cur, "curvas_bonos_corporativos.csv")
escribir_csv(extraer_curvas(con, "cda_curve"), "curvas_cda_mensual.csv")

message("Transacciones bursátiles de instrumentos de deuda...")
tr <- dbGetQuery(con, "
  SELECT CAST(operation_date AS DATE) AS fecha, transaction_id, instrument AS instrumento, market AS mercado,
         operation_type AS tipo_operacion, currency AS moneda, local_currency_volume AS volumen_moneda_local,
         volume_status AS estado_volumen, isin, issuer_tax_id AS emisor_ruc, issuer_name AS emisor,
         broker_name AS casa_bolsa, trading_venue AS plataforma, assurance_level, source_row
    FROM research.transactions
   WHERE instrument IN ('BONOS CORPORATIVOS','BONOS SUBORDINADOS','BONO FINANCIERO','BONO DEL TESORO',
                        'BONOS DEL TESORO','BONOS MUNICIPALES','BBCP','LRM','CDA')
   ORDER BY fecha, transaction_id")
tr$nivel_verificacion <- "Validada por regla (estructural)"
escribir_csv(tr, "transacciones_deuda_bva.csv")

message("Eventos: mercado secundario de LRM/bonos y subastas de LRM...")
ev <- dbGetQuery(con, "
  SELECT CAST(reference_period_start AS DATE) AS fecha, source_id AS fuente, source_sheet AS hoja,
         full_series_path AS detalle, researcher_name AS variable, value AS valor, unit_code AS unidad,
         validation_tier, candidate_id, source_row
    FROM explore.events
   WHERE source_id = 'lrm_auctions' OR (source_id = 'interbank_market' AND source_sheet = 'Mdo Secundario')
   ORDER BY fuente, fecha, candidate_id")
ev$nivel_verificacion <- nivel_verificacion(ev$validation_tier, NA); ev$validation_tier <- NULL
escribir_csv(ev[ev$fuente == "interbank_market", ], "eventos_mercado_secundario_lrm_bonos.csv")
escribir_csv(ev[ev$fuente == "lrm_auctions", ], "eventos_subastas_lrm.csv")
cerrar(con)
