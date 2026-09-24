# SPEI (Índice Estandarizado de Precipitación-Evapotranspiración) 3, 6 y 12 meses.
#
# Insumos: data/clima/clima_chirps_precipitacion.csv (precipitación, 03_chirps.R) y
#          data/clima/clima_era5land.csv (tmax y tmin medias mensuales, 06_era5land.R).
# Método: PET de Hargreaves (SPEI::hargreaves) con tmin/tmax mensuales de ERA5-Land y la latitud del
# centroide de cada unidad; balance = precipitación CHIRPS − PET; SPEI log-logístico, calibración
# 1991–2020. Para PY-AGRO el balance es el promedio de los balances departamentales con los pesos
# agrícolas fijos. No se usa la evaporación potencial de ERA5-Land (sesgada para este fin).
# Salida: data/clima/clima_spei.csv (y la PET en la misma tabla, variable pet_hargreaves)

source("R/clima/00_utils.R")
suppressPackageStartupMessages({ library(SPEI); library(sf) })

f_p <- file.path(OUT_DIR, "clima_chirps_precipitacion.csv")
f_t <- file.path(OUT_DIR, "clima_era5land.csv")
if (!file.exists(f_t)) stop("Falta ", f_t, ": correr antes 06_era5land.R (requiere token CDS).")

p <- fread(f_p)[variable == "precipitacion" & id_geo != "PY-AGRO", .(fecha, id_geo, pre = valor)]
t <- dcast(fread(f_t)[variable %in% c("temperatura_maxima_media", "temperatura_minima_media") & id_geo != "PY-AGRO"],
           fecha + id_geo ~ variable, value.var = "valor")
setnames(t, c("temperatura_maxima_media", "temperatura_minima_media"), c("tmax", "tmin"))
d <- merge(p, t, by = c("fecha", "id_geo"))  # período común
setorder(d, id_geo, fecha)

deptos <- st_transform(st_read(GEOJSON_DPTOS, quiet = TRUE), 4326)
cent <- st_coordinates(st_centroid(st_make_valid(rbind(
  st_sf(id_geo = paste0("PY-", deptos$DPTO), geometry = st_geometry(deptos)),
  st_sf(id_geo = "PY", geometry = st_union(st_make_valid(deptos)))))))
lat <- setNames(cent[, "Y"], c(paste0("PY-", deptos$DPTO), "PY"))

# Serie continua requerida por SPEI
for (g in unique(d$id_geo)) {
  f <- d[id_geo == g, fecha]
  if (!identical(as.Date(f), seq(min(as.Date(f)), max(as.Date(f)), by = "month"))) stop("Serie con huecos en ", g)
}
d[, pet := {
  as.numeric(hargreaves(Tmin = ts(tmin, start = c(year(fecha[1]), month(fecha[1])), frequency = 12),
                        Tmax = ts(tmax, start = c(year(fecha[1]), month(fecha[1])), frequency = 12),
                        lat = lat[[id_geo[1]]], na.rm = FALSE, verbose = FALSE))
}, by = id_geo]
d[, balance := pre - pet]
w <- fread(file.path(OUT_DIR, "clima_pesos_agricolas.csv"))
agro <- merge(d[id_geo != "PY"], w[, .(id_geo, peso)], by = "id_geo")[, .(pet = sum(pet * peso), balance = sum(balance * peso)), by = fecha][, id_geo := "PY-AGRO"]
d <- rbind(d[, .(fecha, id_geo, pet, balance)], agro)
setorder(d, id_geo, fecha)

res <- list(d[, .(fecha, id_geo, variable = "pet_hargreaves", valor = pet, unidad = "mm")])
for (g in unique(d$id_geo)) for (k in c(3, 6, 12)) {
  s <- d[id_geo == g]
  v <- as.numeric(suppressWarnings(spei(ts(s$balance, start = c(year(s$fecha[1]), month(s$fecha[1])), frequency = 12),
                                        scale = k, distribution = "log-Logistic",
                                        ref.start = c(1991, 1), ref.end = c(2020, 12), verbose = FALSE))$fitted)
  res[[length(res) + 1]] <- data.table(fecha = s$fecha, id_geo = g, variable = paste0("spei_", k), valor = v,
                                       unidad = "indice_estandarizado")[-seq_len(k - 1)]
}
x <- rbindlist(res)
# Un balance por debajo del límite inferior de la log-logística ajustada da ±Inf (limitación conocida
# del SPEI). No se recorta a un valor arbitrario: queda NA con flag y se informa el conteo.
x[, flag_inf := fifelse(is.infinite(valor), paste0("spei_fuera_del_soporte_de_la_distribucion(", valor, ")"), NA_character_)]
x[is.infinite(valor), valor := NA_real_]
log_msg("SPEI: valores fuera del soporte (±Inf → NA):", x[!is.na(flag_inf), .N])
if (x[is.na(valor) & is.na(flag_inf), .N]) stop("SPEI/PET con NA inesperados: ", x[is.na(valor) & is.na(flag_inf), .N])
out <- x[, .(fecha, id_geo, nivel_geo = fifelse(id_geo %in% c("PY", "PY-AGRO"), "nacional", "departamento"),
             variable, valor, unidad,
             fuente = "Cálculo propio: CHIRPS v3.0 − PET Hargreaves (ERA5-Land tmax/tmin); SPEI::spei log-logística, ref. 1991-2020",
             frecuencia = "mensual", periodo_publicado = NA_character_,
             flag = {
               ag <- fifelse(id_geo == "PY-AGRO", "ponderado_superficie_16_cultivos_2007_08", NA_character_)
               fifelse(is.na(flag_inf), ag, fifelse(is.na(ag), flag_inf, paste0(flag_inf, "; ", ag)))
             },
             archivo_origen = paste(f_p, f_t, sep = ";"))]
escribir_largo(out, "clima_spei", claves = c("fecha", "id_geo", "variable"), insumos = huella(c(f_p, f_t)))
