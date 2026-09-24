# MODIS MOD13A3 v061 (NASA LP DAAC): NDVI y EVI mensuales a 1 km, por departamento y nacional.
#
# REQUISITO: cuenta gratuita de NASA Earthdata y pedido de área en AppEEARS; ver data/clima/README.md,
# sección "Instrucciones: MODIS". Copiar los GeoTIFF de la entrega de AppEEARS, sin editarlos, a
#   input/acquisition_candidates/clima_agro_2026-09-23_faseB/modis/
# Nombres aceptados: MOD13A3.061__1_km_monthly_<capa>_doyAAAADDD_aid0001.tif o
# MOD13A3.061__1_km_monthly_<capa>_AAAAMMDDT000000_aid0001.tif (formato de la entrega del 2026-09-23),
# con capas NDVI, EVI y pixel_reliability. La capa VI_Quality también viene en la entrega pero no se usa:
# la máscara de calidad se hace con pixel_reliability (resumen oficial de VI_Quality).
#
# Escala: los GeoTIFF declaran scale_factor 0,0001 y NoData −3000, y terra los aplica solo al leer. Para no
# depender de eso, se leen los enteros CRUDOS (scoff = 1, 0) y se aplican explícitamente, verificando que
# los metadatos declaren esos mismos valores.
#
# Método: escala 0,0001 (NDVI/EVI); se descartan píxeles con valor de relleno (−3000) o con
# pixel_reliability distinto de 0 (bueno) o 1 (marginal). Media ponderada por fracción y área de celda
# (exactextractr) sobre las 18 unidades del INE, nacional y nacional agrícola (pesos fijos 2007/08).
# Se informa la fracción de píxeles válidos de cada unidad-mes (variable modis_fraccion_valida).
# Fecha: el sello del archivo (día juliano o AAAAMMDD) marca el inicio del mes compuesto de MOD13A3.
# Salida: data/clima/clima_modis_vegetacion.csv

source("R/clima/00_utils.R")
suppressPackageStartupMessages({ library(terra); library(sf); library(exactextractr) })

DIR_MO <- Sys.getenv("MODIS_DIR", file.path(ACQ_NUEVA, "modis")); dir.create(DIR_MO, showWarnings = FALSE, recursive = TRUE)
todos <- list.files(DIR_MO, pattern = "^MOD13A3\\.061_.*_(doy\\d{7}|\\d{8}T\\d{6})_aid\\d+\\.tif$", full.names = TRUE)
if (!length(todos)) stop("No hay GeoTIFF de MOD13A3 en ", DIR_MO, ". Ver data/clima/README.md (Instrucciones: MODIS).")
info <- data.table(f = todos, capa = sub(".*1_km_monthly_(.*)_(doy\\d{7}|\\d{8}T\\d{6})_aid.*", "\\1", basename(todos)),
                   sello = sub(".*_(doy\\d{7}|\\d{8}T\\d{6})_aid.*", "\\1", basename(todos)))
info[, fecha := suppressWarnings(fifelse(startsWith(sello, "doy"),
                        as.IDate(as.Date(paste0(substr(sello, 4, 7), "-01-01")) + as.integer(substr(sello, 8, 10)) - 1L),
                        as.IDate(substr(sello, 1, 8), format = "%Y%m%d")))]
info <- info[capa %in% c("NDVI", "EVI", "pixel_reliability")]
if (info[mday(fecha) != 1, .N]) stop("Hay archivos cuyo sello de fecha no es el primer día de un mes")
if (info[, .N, by = .(capa, fecha)][N > 1, .N]) stop("Hay capa-fecha duplicadas (¿dos entregas mezcladas?)")
leer_crudo <- function(ff, escala_esperada) {
  r <- rast(ff)
  sc <- scoff(r)
  if (!isTRUE(all.equal(unname(sc[1, 1]), escala_esperada)) || unname(sc[1, 2]) != 0) stop("Escala inesperada en ", basename(ff), ": ", sc[1, 1])
  scoff(r) <- cbind(1, 0)
  r
}
fechas <- sort(unique(info$fecha))
completo <- info[capa %in% c("NDVI", "EVI", "pixel_reliability"), .N, by = fecha][N == 3, fecha]
faltan <- setdiff(fechas, completo)
if (length(faltan)) log_msg("MODIS: meses sin las tres capas (se omiten):", paste(format(as.IDate(faltan)), collapse = ", "))
log_msg("MODIS:", length(completo), "meses completos,", format(min(completo)), "→", format(max(completo)))

deptos <- st_transform(st_read(GEOJSON_DPTOS, quiet = TRUE), 4326)
deptos$id_geo <- paste0("PY-", deptos$DPTO)
unidades <- rbind(deptos[, "id_geo"], st_sf(id_geo = "PY", geometry = st_union(st_make_valid(deptos))))
w <- fread(file.path(OUT_DIR, "clima_pesos_agricolas.csv"))

res <- list()
for (k in seq_along(completo)) {
  fe <- completo[k]
  g <- function(cp, esc) leer_crudo(info[fecha == fe & capa == cp, f], esc)
  rel <- g("pixel_reliability", 1)
  valido <- rel %in% c(0, 1)
  for (cp in c("NDVI", "EVI")) {
    r <- g(cp, 1e-4)
    r <- mask(ifel(r == -3000, NA, r * 0.0001), valido, maskvalues = 0)
    v <- exact_extract(r, unidades, fun = "weighted_mean", weights = "area", progress = FALSE)
    fr <- exact_extract(!is.na(r), unidades, fun = "weighted_mean", weights = "area", progress = FALSE)
    res[[length(res) + 1]] <- data.table(fecha = fe, id_geo = unidades$id_geo, variable = paste0("modis_", tolower(cp)), valor = v, unidad = "indice")
    if (cp == "NDVI") res[[length(res) + 1]] <- data.table(fecha = fe, id_geo = unidades$id_geo, variable = "modis_fraccion_valida", valor = fr, unidad = "proporcion")
  }
}
d <- rbindlist(res)
agro <- merge(d[id_geo != "PY" & variable != "modis_fraccion_valida"], w[, .(id_geo, peso)], by = "id_geo")[
  , .(valor = sum(valor * peso, na.rm = TRUE) / sum(peso[!is.na(valor)]), unidad = unidad[1]), by = .(fecha, variable)][, id_geo := "PY-AGRO"]
d <- rbind(d, agro, use.names = TRUE)
out <- d[, .(fecha, id_geo, nivel_geo = fifelse(id_geo %in% c("PY", "PY-AGRO"), "nacional", "departamento"),
             variable, valor, unidad, fuente = "NASA LP DAAC MOD13A3 v061 vía AppEEARS (agregado propio)",
             frecuencia = "mensual", periodo_publicado = NA_character_,
             flag = fifelse(id_geo == "PY-AGRO", "ponderado_superficie_16_cultivos_2007_08", fifelse(is.na(valor), "sin_pixeles_validos", NA_character_)),
             archivo_origen = DIR_MO)]
escribir_largo(out, "clima_modis_vegetacion", claves = c("fecha", "id_geo", "variable"), insumos = paste0(DIR_MO, "/*.tif"))
