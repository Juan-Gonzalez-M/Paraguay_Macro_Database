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
## Proyecto 06 · C2 — Depósitos, crédito y sustitución entre intermediarios
## Versión bancaria (bancos + financieras). Las cooperativas solo existen como agregado
## Tipo A del Anexo (2017-12 a 2025-11). Paneles completos por acuerdo de la Fase 1.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,Tasa de política monetaria (etiqueta contaminada en la base),Tratamiento: política monetaria
eve_tpm_mes,eve:tasa_de_politica_monetaria_tpm:expectativa_del_mes,EVE (mediana): TPM esperada para el mes,Sorpresa de política (TPM − esperada)
eve_tpm_prox_mes,eve:tasa_de_politica_monetaria_tpm:expectativa_del_proximo_mes,EVE (mediana): TPM esperada para el próximo mes,Sorpresa de política
ipc_var_interanual,economic_annex:cuadro_15:080dbf95a46f3bcb97aeb69d,Inflación total interanual,Control / tasas reales
c31_mn_pasiva_vista,economic_annex:cuadro_31:4cf5c9315d0ce4a1ccef0be2,Tasa efectiva pasiva MN a la vista (etiqueta contaminada),Precio del fondeo MN
c31_mn_pasiva_plazo,economic_annex:cuadro_31:aacfa4b95b892d3d761fdc06,Tasa efectiva pasiva MN a plazo (etiqueta contaminada),Precio del fondeo MN
c31_mn_pasiva_cda,economic_annex:cuadro_31:c2b248d54ebd174566d7c4bb,Tasa efectiva pasiva MN CDA (etiqueta contaminada),Precio del fondeo MN
c31_mn_pasiva_prom,economic_annex:cuadro_31:6ff03d8f79fc15937b18bab3,Tasa efectiva pasiva MN promedio ponderado (etiqueta contaminada),Precio del fondeo MN
c31_mn_activa_prom,economic_annex:cuadro_31:c90c5c9c2ec39acfaed4ff16,Tasa efectiva activa MN promedio ponderado sin tarjetas ni sobregiros (etiqueta contaminada),Precio del crédito MN
c31_me_pasiva_vista,economic_annex:cuadro_31_cont:55464b82ce76371bfa534f0b,Tasa efectiva pasiva ME a la vista,Precio del fondeo ME
c31_me_pasiva_plazo,economic_annex:cuadro_31_cont:170f1e2a628c1df46041835a,Tasa efectiva pasiva ME a plazo,Precio del fondeo ME
c31_me_pasiva_cda,economic_annex:cuadro_31_cont:471798dff0fbf8cce6e28cce,Tasa efectiva pasiva ME CDA,Precio del fondeo ME
c31_me_activa_prom,economic_annex:cuadro_31_cont:eaf763baa29bd5845926073b,Tasa efectiva activa ME promedio ponderado,Precio del crédito ME
dep_priv_mn_ctacte,economic_annex:cuadro_23a:cb884bce6a9707e5dbb37c81,Depósitos del sector privado MN: cuenta corriente,Cantidad de fondeo MN
dep_priv_mn_vista,economic_annex:cuadro_23a:82319ba269b30cfdbab2067c,Depósitos del sector privado MN: ahorro a la vista,Cantidad de fondeo MN
dep_priv_mn_plazo,economic_annex:cuadro_23a:eccf9463ea3b632825f0794e,Depósitos del sector privado MN: ahorro a plazo,Cantidad de fondeo MN
dep_priv_mn_cds,economic_annex:cuadro_23a:2352af509e2f2e05b140ed28,Depósitos del sector privado MN: CDs,Cantidad de fondeo MN
dep_priv_mn_total,economic_annex:cuadro_23a:4f4afb1454f1954045984105,Depósitos del sector privado MN: total,Cantidad de fondeo MN
dep_priv_me_ctacte,economic_annex:cuadro_23a:804e1eca1f3c07b3e4bfbf36,Depósitos del sector privado ME: cuenta corriente (millones de Gs.),Cantidad de fondeo ME
dep_priv_me_vista,economic_annex:cuadro_23a:7d80399f2fa437bc4d8b57ae,Depósitos del sector privado ME: ahorro a la vista (millones de Gs.),Cantidad de fondeo ME
dep_priv_me_plazo,economic_annex:cuadro_23a:ad70fdcb5e239a9b628799d3,Depósitos del sector privado ME: ahorro a plazo (millones de Gs.),Cantidad de fondeo ME
dep_priv_me_cds,economic_annex:cuadro_23a:fe9364b07027333baada5b5c,Depósitos del sector privado ME: CDs (millones de Gs.),Cantidad de fondeo ME
dep_priv_me_total,economic_annex:cuadro_23a:9183bbd87440955f3c4f61c3,Depósitos del sector privado ME: total (millones de Gs.),Cantidad de fondeo ME
dep_priv_me_total_usd,economic_annex:cuadro_23a:6665dcbd306238301a26a70e,Depósitos del sector privado ME: total en millones de USD,Cantidad de fondeo ME
dep_priv_tc,economic_annex:cuadro_23a:1d322c15f735fa600e48ca44,Tipo de cambio usado en el Cuadro 23a,Conversión
dep_priv_part_me,economic_annex:cuadro_23a:322c9ae3c660f49040467fce,Participación de ME en depósitos privados (%),Dolarización de depósitos
cred_priv_mn,economic_annex:cuadro_24a:066262e294293abfdf394a22,Crédito de bancos y financieras al sector privado MN,Resultado: crédito
cred_priv_me,economic_annex:cuadro_24a:068827fc3ff258bf18368305,Crédito al sector privado ME (millones de Gs.),Resultado: crédito
cred_priv_me_usd,economic_annex:cuadro_24a:24d810aa73e2ae59ac1bd9b9,Crédito al sector privado ME en millones de USD,Resultado: crédito
cred_priv_total,economic_annex:cuadro_24a:5a78850a2552c99415f492b7,Crédito al sector privado total,Resultado: crédito
cred_priv_part_me,economic_annex:cuadro_24a:c634f2fdb01f30ade67b492f,Participación de ME en el crédito privado (%),Dolarización del crédito
coop_dep_mn,economic_annex:cuadro_23b:38654549fa309beab0d7e0a1,Cooperativas Tipo A: depósitos MN (millones de Gs.),Sustitución hacia cooperativas
coop_dep_me,economic_annex:cuadro_23b:ec4c1dd789977ba80e59f08f,Cooperativas Tipo A: depósitos ME (millones de Gs.; la base agrega '%' a la etiqueta por error),Sustitución hacia cooperativas
coop_dep_total,economic_annex:cuadro_23b:80c098e04abaf5e13c44a170,Cooperativas Tipo A: depósitos totales (millones de Gs.; la base agrega '%' a la etiqueta por error),Sustitución hacia cooperativas
coop_cred_mn,economic_annex:cuadro_24b:38654549fa309beab0d7e0a1,Cooperativas Tipo A: créditos MN (millones de Gs.),Sustitución hacia cooperativas
coop_cred_me,economic_annex:cuadro_24b:ec4c1dd789977ba80e59f08f,Cooperativas Tipo A: créditos ME (millones de Gs.; la base agrega '%' a la etiqueta por error),Sustitución hacia cooperativas
coop_cred_total,economic_annex:cuadro_24b:be297d9734c362490e962fee,Cooperativas Tipo A: créditos totales (millones de Gs.; la base agrega '%' a la etiqueta por error),Sustitución hacia cooperativas
bancariz_cuentas_total,banking_indicators:x4:b7c61f0017b4715c0c5e76d1,Cantidad total de cuentas de depósito,Base de depositantes
bancariz_personas_total,banking_indicators:x4:7ff2948c9a61b9002fc4e336,Personas con cuentas de depósito,Base de depositantes
bancariz_cuentas_cda,banking_indicators:x6:a3c072d200353eb9f96d52b4,Cantidad de cuentas a plazo (CDA),Base de depositantes
bancariz_cuentas_vista,banking_indicators:x6:5c69cbe60916bd8c73130eb9,Cantidad de cuentas a la vista,Base de depositantes
", stringsAsFactors = FALSE, strip.white = TRUE)

con <- conectar()
message("Tasas por producto, plazo y moneda (Indicadores Financieros, bancos y financieras)...")
tasas <- rbind(
  spec_por_hoja(con, "financial_indicators", "1.2", "tef_bancos", "Precio por producto y moneda (bancos; promedio del sistema)"),
  spec_por_hoja(con, "financial_indicators", "2.2", "tef_plazo_bancos", "Precio por producto, plazo y moneda (bancos)"),
  spec_por_hoja(con, "financial_indicators", "5", "tef_financieras", "Precio por producto y moneda (financieras)"),
  spec_por_hoja(con, "financial_indicators", "6", "tef_plazo_financieras", "Precio por producto y plazo (financieras)"),
  spec_por_hoja(con, "financial_indicators", "4", "saldos_bancos", "Cantidades por producto y plazo (bancos)"),
  spec_por_hoja(con, "financial_indicators", "7", "saldos_financieras", "Cantidades por producto y plazo (financieras)"))
spec <- rbind(dicc, tasas)
x <- extraer_escalares(con, spec)
escribir_series(x, spec)

message("Curva de CDA por plazo (tasas y volúmenes)...")
escribir_csv(extraer_curvas(con, "cda_curve"), "curvas_cda_mensual.csv")

message("Paneles completos entidad-mes (bancos y financieras)...")
eeff <- dbGetQuery(con, "
  SELECT source_id AS tipo_entidad, fecha, entity_id, short_name AS entidad, ownership_type AS propiedad,
         semantic_classification AS clase, semantic_rubro AS rubro, sub_rubro, codigo_moneda,
         currency_of_origin AS moneda_origen, importe AS importe_pyg
    FROM (SELECT * FROM main.v_banks_eeff_documented UNION ALL BY NAME SELECT * FROM main.v_financial_eeff_documented)
   ORDER BY tipo_entidad, fecha, entity_id, clase, rubro, sub_rubro, codigo_moneda")
eeff <- fechas_panel(eeff); eeff$nivel_verificacion <- "Panel provisional"
escribir_csv(eeff, "panel_eeff_entidad_mes.csv")
car <- dbGetQuery(con, "
  SELECT source_id AS tipo_entidad, fecha, codigo_entidad, codigo_cuenta AS cuenta, codigo_moneda, importe AS importe_pyg
    FROM (SELECT * FROM main.v_latest_raw_banks_carteras UNION ALL BY NAME SELECT * FROM main.v_latest_raw_financial_carteras)
   ORDER BY 1,2,3,4,5")
car <- fechas_panel(car); car$nivel_verificacion <- "Panel provisional"
escribir_csv(car, "panel_carteras_entidad_mes.csv")
sec <- dbGetQuery(con, "
  SELECT source_id AS tipo_entidad, fecha, codigo_entidad, codigo_moneda, actividad_destino_vs2 AS sector,
         cartera_vigente, cartera_vencida
    FROM (SELECT * FROM main.v_latest_raw_banks_credito_sector UNION ALL BY NAME SELECT * FROM main.v_latest_raw_financial_credito_sector)
   ORDER BY 1,2,3,4,5")
sec <- fechas_panel(sec); sec$nivel_verificacion <- "Panel provisional"
escribir_csv(sec, "panel_credito_sector_entidad_mes.csv")
rat <- dbGetQuery(con, "
  SELECT source_id AS tipo_entidad, fecha, codigo_entidad, sub_rubro AS ratio, total AS valor
    FROM (SELECT * FROM main.v_latest_raw_banks_ratios UNION ALL BY NAME SELECT * FROM main.v_latest_raw_financial_ratios)
   ORDER BY 1,2,3,4")
rat <- fechas_panel(rat); rat$nivel_verificacion <- "Panel provisional"
escribir_csv(rat, "panel_ratios_entidad_mes.csv")
ent <- dbGetQuery(con, "SELECT DISTINCT entity_id, short_name AS entidad, legal_name AS razon_social, ownership_type AS propiedad
                          FROM (SELECT * FROM main.v_banks_eeff_documented UNION ALL BY NAME SELECT * FROM main.v_financial_eeff_documented)
                         ORDER BY 1")
escribir_csv(ent, "entidades.csv", fecha_col = "none")
cerrar(con)
