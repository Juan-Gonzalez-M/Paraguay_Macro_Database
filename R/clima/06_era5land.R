# ERA5-Land (Copernicus CDS): temperatura, humedad del suelo y evaporación por departamento y nacional.
#
# REQUISITO: token personal de la API CDS en ~/.cdsapirc (ver data/clima/README.md, sección
# "Instrucciones: ERA5-Land") y licencia del conjunto aceptada en la web. Sin eso, el script se detiene.
# No usa ni guarda contraseñas.
#
# Descargas (a <ACQ_NUEVA>/era5land/, reanudable; un archivo por pedido):
#   A) reanalysis-era5-land-monthly-means (monthly_averaged_reanalysis), 1981–último año completo+parcial:
#      2m_temperature, volumetric_soil_water_layer_1/2/3, total_evaporation, potential_evaporation
#   B) reanalysis-era5-land 2m_temperature HORARIA, un pedido por mes (hasta 20 activos; jobID en
#      era5land/horario/cds_jobs_horario.csv; reanudable). De ahí se derivan tmax y tmin diarias en hora
#      local UTC−3 (idénticas al producto derived-era5-land-daily-statistics, validado con 1982-01).
# Área: N −19, O −63, S −28, E −54 (Paraguay con margen).
#
# Agregación: igual que CHIRPS (media ponderada por fracción y área de celda; 18 unidades INE,
# nacional por área y nacional agrícola con los mismos pesos fijos 2007/08).
# Conversiones explícitas: K → °C; evaporación de m/día (media diaria de acumulados) → mm/día,
# conservando el signo de ERA5 (negativo = flujo hacia la atmósfera). Humedad del suelo en m³/m³.
# Variables derivadas de los diarios: tmax y tmin medias mensuales; días con tmax ≥ 35 °C y días con
# tmin ≤ 0 °C (umbrales de las categorías del anuario DMH) calculados POR CELDA y luego promediados.
#
# Uso: Rscript R/clima/06_era5land.R [descargar|procesar]   (sin argumento: ambos)
# Salida: data/clima/clima_era5land.csv

source("R/clima/00_utils.R")
suppressPackageStartupMessages({ library(terra); library(sf); library(exactextractr); library(ecmwfr) })

DIR_E5 <- Sys.getenv("E5_DIR", file.path(ACQ_NUEVA, "era5land")); dir.create(DIR_E5, showWarnings = FALSE, recursive = TRUE)
AREA <- c(-19, -63, -28, -54)
ANIO_INI <- 1981
hoy <- Sys.Date()
ANIO_FIN <- as.integer(format(hoy, "%Y"))
modo <- commandArgs(TRUE)[1]   # NA (todo), "descargar" o "procesar"

if (is.na(modo) || modo == "descargar") {
  rc <- path.expand("~/.cdsapirc")
  if (!file.exists(rc)) stop("Falta ~/.cdsapirc con el token de la API CDS. Ver data/clima/README.md (Instrucciones: ERA5-Land).")
  cfg <- readLines(rc, warn = FALSE)
  key <- trimws(sub("^key:\\s*", "", grep("^key:", cfg, value = TRUE)))
  if (!length(key) || !nzchar(key)) stop("~/.cdsapirc no tiene una línea 'key: <token>'")
  wf_set_key(key = key)

  pedir <- function(req, archivo) {
    dest <- file.path(DIR_E5, archivo)
    if (file.exists(dest)) return(dest)
    req$target <- archivo
    log_msg("CDS: pidiendo", archivo)
    wf_request(request = req, path = DIR_E5, transfer = TRUE, verbose = FALSE, time_out = 3 * 3600)
    if (!file.exists(dest)) stop("CDS no devolvió ", archivo)
    registrar_descarga(file.path("era5land", archivo), paste0("CDS:", req$dataset_short_name), "downloaded")
    dest
  }
  # A) Medias mensuales, por década. El tramo del año en curso se pide de nuevo si cambia la fecha
  #    (nuevo vintage, con sufijo _hasta_AAAAMMDD); los tramos cerrados no se vuelven a pedir.
  VARS_M <- c("2m_temperature", "volumetric_soil_water_layer_1", "volumetric_soil_water_layer_2",
              "volumetric_soil_water_layer_3", "total_evaporation", "potential_evaporation")
  for (dd in split(ANIO_INI:ANIO_FIN, (ANIO_INI:ANIO_FIN - ANIO_INI) %/% 10)) {
    completo <- max(dd) < ANIO_FIN
    nombre <- sprintf("era5land_mensual_%d_%d%s.nc", min(dd), max(dd), if (completo) "" else paste0("_hasta_", format(hoy, "%Y%m%d")))
    pedir(list(dataset_short_name = "reanalysis-era5-land-monthly-means",
               product_type = "monthly_averaged_reanalysis", variable = VARS_M,
               year = as.character(dd), month = sprintf("%02d", 1:12), time = "00:00",
               area = AREA, data_format = "netcdf", download_format = "unarchived"), nombre)
  }
  # B) Temperatura HORARIA (reanalysis-era5-land, 2m_temperature), un pedido por mes. El producto
  #    derivado de estadísticos diarios quedó descartado el 2026-09-24: su cola procesaba ~1 pedido cada
  #    4–5 h. El horario salió en ~2 min por mes, y las máximas y mínimas diarias calculadas desde él
  #    coinciden EXACTAMENTE (0,0 K) con las oficiales del CDS (validado con enero de 1982).
  #    Hasta MAX_ACTIVOS pedidos a la vez; jobID en era5land/horario/cds_jobs_horario.csv (reanudable).
  #    Solo meses completos: ERA5-Land se publica con unos días de rezago.
  CDS <- "https://cds.climate.copernicus.eu/api/retrieve/v1"
  hdr <- httr::add_headers(`PRIVATE-TOKEN` = key)
  DIR_H <- file.path(DIR_E5, "horario"); dir.create(DIR_H, showWarnings = FALSE)
  MAX_ACTIVOS <- 20
  f_jobs <- file.path(DIR_H, "cds_jobs_horario.csv")
  jobs <- if (file.exists(f_jobs)) fread(f_jobs, colClasses = "character") else data.table(archivo = character(), jobID = character(), estado = character(), enviado_utc = character())
  guardar_jobs <- function() fwrite(jobs, f_jobs)
  ultimo_mes <- seq(as.Date(format(hoy, "%Y-%m-01")), by = "-1 month", length.out = 2)[2]
  meses_h <- seq(as.Date(sprintf("%d-01-01", ANIO_INI)), ultimo_mes, by = "month")
  nombre_h <- function(m) sprintf("era5land_t2m_horario_%s.nc", format(m, "%Y%m"))
  pedido_h <- function(m) list(variable = list("2m_temperature"), year = list(format(m, "%Y")), month = list(format(m, "%m")),
                               day = as.list(sprintf("%02d", 1:31)), time = as.list(sprintf("%02d:00", 0:23)),
                               area = as.list(AREA), data_format = "netcdf", download_format = "unarchived")
  # Mes de prueba ya descargado (mismo pedido): se reutiliza en vez de volver a pedirlo.
  prueba <- file.path(DIR_E5, "..", "era5land_horario_prueba", "era5land_t2m_horario_198201.nc")
  if (file.exists(prueba) && !file.exists(file.path(DIR_H, nombre_h(as.Date("1982-01-01"))))) {
    file.copy(prueba, file.path(DIR_H, nombre_h(as.Date("1982-01-01"))))
    registrar_descarga(file.path("era5land/horario", nombre_h(as.Date("1982-01-01"))), "CDS:reanalysis-era5-land (pedido de prueba 1982-01)", "downloaded")
  }
  enviar <- function(m) {
    nm <- nombre_h(m)
    r <- tryCatch(httr::POST(paste0(CDS, "/processes/reanalysis-era5-land/execution"), hdr, body = list(inputs = pedido_h(m)), encode = "json"),
                  error = function(e) NULL)
    if (is.null(r) || httr::status_code(r) >= 300) {
      log_msg("CDS rechazó", nm, if (is.null(r)) "sin respuesta" else httr::status_code(r)); return(FALSE)
    }
    jobs <<- rbind(jobs[archivo != nm], data.table(archivo = nm, jobID = httr::content(r)$jobID, estado = "enviado",
                                                   enviado_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")))
    guardar_jobs(); Sys.sleep(1); TRUE
  }
  reintentos <- list()
  repeat {
    pend <- meses_h[!file.exists(file.path(DIR_H, vapply(meses_h, nombre_h, "")))]
    if (!length(pend)) break
    # 1) Revisar los activos
    activos <- jobs[archivo %in% vapply(pend, nombre_h, "") & estado %in% c("enviado", "accepted", "running", "successful")]
    for (i in seq_len(nrow(activos))) {
      nm <- activos$archivo[i]; id <- activos$jobID[i]
      st <- tryCatch(httr::content(httr::GET(paste0(CDS, "/jobs/", id), hdr))$status, error = function(e) NA)
      if (is.null(st) || is.na(st)) next
      jobs[archivo == nm, estado := st]
      if (st == "successful") {
        href <- tryCatch(httr::content(httr::GET(paste0(CDS, "/jobs/", id, "/results"), hdr))$asset$value$href, error = function(e) NULL)
        dest <- file.path(DIR_H, nm)
        ok <- !is.null(href) && isTRUE(tryCatch({ curl::curl_download(href, paste0(dest, ".part")); file.rename(paste0(dest, ".part"), dest) }, error = function(e) FALSE))
        if (ok) registrar_descarga(file.path("era5land/horario", nm), paste0("CDS:reanalysis-era5-land jobID=", id), "downloaded")
      } else if (st %in% c("failed", "dismissed", "deleted")) {
        reintentos[[nm]] <- (if (is.null(reintentos[[nm]])) 0 else reintentos[[nm]]) + 1
        log_msg("CDS: trabajo", st, nm, "(reintento", reintentos[[nm]], ")")
        if (reintentos[[nm]] > 3) stop("CDS: ", nm, " falló más de 3 veces")
        jobs[archivo == nm, estado := "reintentar"]
      }
    }
    guardar_jobs()
    # 2) Enviar nuevos hasta completar MAX_ACTIVOS
    pend <- meses_h[!file.exists(file.path(DIR_H, vapply(meses_h, nombre_h, "")))]
    n_act <- jobs[archivo %in% vapply(pend, nombre_h, "") & estado %in% c("enviado", "accepted", "running", "successful"), .N]
    sin_job <- pend[!vapply(pend, nombre_h, "") %in% jobs[estado %in% c("enviado", "accepted", "running", "successful"), archivo]]
    for (k in seq_len(min(length(sin_job), max(0, MAX_ACTIVOS - n_act)))) enviar(sin_job[k])
    log_msg("CDS horario:", length(meses_h) - length(pend), "/", length(meses_h), "meses descargados; activos:",
            jobs[archivo %in% vapply(pend, nombre_h, "") & estado %in% c("enviado", "accepted", "running", "successful"), .N])
    if (length(pend)) Sys.sleep(60)
  }
  log_msg("CDS horario: completo,", length(meses_h), "meses")
}
if (!is.na(modo) && modo == "descargar") quit(save = "no")

# Selección de archivos: tramos cerrados + el vintage más reciente de cada tramo abierto ("_hasta_").
elegir <- function(patron) {
  f <- sort(list.files(DIR_E5, pattern = patron, full.names = TRUE))
  base <- sub("_hasta_\\d{6,8}\\.nc$", ".nc", basename(f))
  f <- f[!duplicated(base, fromLast = TRUE)]   # orden alfabético: el último _hasta_ es el más reciente
  f
}
arch_m <- elegir("^era5land_mensual_\\d{4}_\\d{4}(_hasta_\\d{8})?\\.nc$")
# Máximas y mínimas DIARIAS derivadas de la temperatura horaria, en hora local UTC−3 (día local D =
# de D 03:00 UTC a D+1 02:00 UTC), igual que el producto oficial pedido con time_zone = "utc-03:00".
# Solo días con las 24 horas; se guardan por año en era5land/diario_derivado/ (se recalculan si cambian
# los horarios de ese año o de enero del año siguiente).
DIR_H <- file.path(DIR_E5, "horario"); DIR_DD <- file.path(DIR_E5, "diario_derivado"); dir.create(DIR_DD, showWarnings = FALSE)
arch_h <- sort(list.files(DIR_H, pattern = "^era5land_t2m_horario_\\d{6}\\.nc$", full.names = TRUE))
if (!length(arch_m) || !length(arch_h)) stop("No hay NetCDF de ERA5-Land en ", DIR_E5, ": correr primero el modo 'descargar'.")
mes_h <- as.Date(paste0(sub(".*_(\\d{6})\\.nc$", "\\1", arch_h), "01"), "%Y%m%d")
esperados_h <- seq(min(mes_h), max(mes_h), by = "month")
if (length(setdiff(esperados_h, mes_h))) stop("Faltan meses horarios: ", paste(format(as.Date(setdiff(esperados_h, mes_h), origin = "1970-01-01"), "%Y-%m"), collapse = ", "))
for (a in unique(as.integer(format(mes_h, "%Y")))) {
  ins <- arch_h[format(mes_h, "%Y") == a | format(mes_h, "%Y-%m") == sprintf("%d-01", a + 1)]
  dx <- file.path(DIR_DD, sprintf("era5land_t2m_daily_maximum_%d.nc", a)); dn <- sub("maximum", "minimum", dx)
  if (file.exists(dx) && file.exists(dn) && all(file.mtime(ins) < min(file.mtime(c(dx, dn))))) next
  h <- rast(ins)
  loc <- as.POSIXct(time(h), tz = "UTC") - 3 * 3600
  dia <- format(loc, "%Y-%m-%d")
  n_h <- table(dia); completos <- names(n_h)[n_h == 24 & substr(names(n_h), 1, 4) == as.character(a)]
  sel <- which(dia %in% completos)
  tx <- tapp(h[[sel]], dia[sel], max); tn <- tapp(h[[sel]], dia[sel], min)
  time(tx) <- time(tn) <- as.Date(sort(unique(dia[sel])))
  names(tx) <- names(tn) <- paste0("t2m_", seq_len(nlyr(tx)))
  writeCDF(tx, dx, varname = "t2m", unit = "K", overwrite = TRUE); writeCDF(tn, dn, varname = "t2m", unit = "K", overwrite = TRUE)
  log_msg("ERA5-Land: diarios derivados", a, ":", length(completos), "días completos")
}
arch_d <- sort(list.files(DIR_DD, pattern = "^era5land_t2m_daily_(maximum|minimum)_\\d{4}\\.nc$", full.names = TRUE))
log_msg("ERA5-Land: procesando", length(arch_m), "archivos mensuales,", length(arch_h), "horarios y", length(arch_d), "diarios derivados de", DIR_E5)

# Unidades de agregación ---------------------------------------------------------------------------
deptos <- st_transform(st_read(GEOJSON_DPTOS, quiet = TRUE), 4326)
deptos$id_geo <- paste0("PY-", deptos$DPTO)
unidades <- rbind(deptos[, "id_geo"], st_sf(id_geo = "PY", geometry = st_union(st_make_valid(deptos))))
w <- fread(file.path(OUT_DIR, "clima_pesos_agricolas.csv"))

extraer <- function(r, variable) {
  m <- as.data.table(exact_extract(r, unidades, fun = "weighted_mean", weights = "area", progress = FALSE))
  setnames(m, as.character(time(r)))
  m[, id_geo := unidades$id_geo]
  x <- melt(m, id.vars = "id_geo", variable.name = "fecha", value.name = "valor")
  x[, fecha := as.IDate(paste0(substr(as.character(fecha), 1, 7), "-01"))]
  agro <- merge(x[id_geo != "PY"], w[, .(id_geo, peso)], by = "id_geo")[, .(valor = sum(valor * peso)), by = fecha][, id_geo := "PY-AGRO"]
  rbind(x, agro)[, variable := variable][]
}

leer_var <- function(archivos, patron) {
  rs <- lapply(archivos, function(f) { r <- rast(f); r[[grepl(patron, names(r))]] })
  r <- do.call(c, rs)
  r[[!duplicated(time(r))]]
}

res <- list()
# Mensuales
conv <- list(t2m = list("temperatura_media", function(v) v - 273.15, "grados_C"),
             swvl1 = list("humedad_suelo_0_7cm", identity, "m3/m3"),
             swvl2 = list("humedad_suelo_7_28cm", identity, "m3/m3"),
             swvl3 = list("humedad_suelo_28_100cm", identity, "m3/m3"),
             e = list("evaporacion_total", function(v) v * 1000, "mm_por_dia (media diaria; negativo = evaporacion)"),
             pev = list("evaporacion_potencial_era5", function(v) v * 1000, "mm_por_dia (media diaria; negativo = evaporacion)"))
for (nm in names(conv)) {
  r <- leer_var(arch_m, paste0("^", nm, "(_|$)"))
  if (nlyr(r) == 0) stop("Variable ", nm, " ausente en los NetCDF mensuales")
  r <- app(r, conv[[nm]][[2]]); time(r) <- time(leer_var(arch_m, paste0("^", nm, "(_|$)")))
  res[[nm]] <- extraer(r, conv[[nm]][[1]])[, unidad := conv[[nm]][[3]]]
}
# Diarios → mensuales
diaria <- function(st) {
  r <- leer_var(arch_d[grepl(st, arch_d)], "t2m") - 273.15
  time(r) <- time(leer_var(arch_d[grepl(st, arch_d)], "t2m"))
  r
}
tx <- diaria("daily_maximum"); tn <- diaria("daily_minimum")
mes_x <- format(time(tx), "%Y-%m"); mes_n <- format(time(tn), "%Y-%m")
agg <- function(r, idx, fun) { a <- tapp(r, factor(idx), fun); time(a) <- as.Date(paste0(levels(factor(idx)), "-01")); a }
res$tmax <- extraer(agg(tx, mes_x, mean), "temperatura_maxima_media")[, unidad := "grados_C"]
res$tmin <- extraer(agg(tn, mes_n, mean), "temperatura_minima_media")[, unidad := "grados_C"]
res$d35 <- extraer(agg(tx >= 35, mes_x, sum), "dias_tmax_ge_35C")[, unidad := "dias"]
res$d0 <- extraer(agg(tn <= 0, mes_n, sum), "dias_tmin_le_0C")[, unidad := "dias"]
dias_obs <- tapply(rep(1, length(mes_x)), mes_x, sum)

d <- rbindlist(res, use.names = TRUE)
d[, dias_mes := as.integer(format(seq(as.Date(fecha[1]), by = "month", length.out = 2)[2] - 1, "%d")), by = fecha]
d[, flag := NA_character_]
d[variable %in% c("temperatura_maxima_media", "temperatura_minima_media", "dias_tmax_ge_35C", "dias_tmin_le_0C"),
  flag := fifelse(dias_obs[format(fecha, "%Y-%m")] < dias_mes, paste0("mes_incompleto:", dias_obs[format(fecha, "%Y-%m")], "/", dias_mes, "_dias"), NA_character_)]
d[id_geo == "PY-AGRO", flag := fifelse(is.na(flag), "ponderado_superficie_16_cultivos_2007_08", paste0(flag, "; ponderado_superficie_16_cultivos_2007_08"))]
out <- d[, .(fecha, id_geo, nivel_geo = fifelse(id_geo %in% c("PY", "PY-AGRO"), "nacional", "departamento"),
             variable, valor, unidad, fuente = "Copernicus ERA5-Land (agregado propio)", frecuencia = "mensual",
             periodo_publicado = NA_character_, flag, archivo_origen = DIR_E5)]
escribir_largo(out, "clima_era5land", claves = c("fecha", "id_geo", "variable"),
               insumos = huella(c(arch_m, arch_d)))
