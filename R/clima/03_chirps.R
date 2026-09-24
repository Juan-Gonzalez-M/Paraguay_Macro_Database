# CHIRPS v3.0: precipitación mensual por departamento y nacional.
#
# Insumo: <ACQ_BASE>/chc/monthly_latam/chirps-v3.0.YYYY.MM.tif (548 meses, 0,05°, mm/mes).
# Método:
#   - Media de las celdas ponderada por la fracción de cada celda dentro del polígono y por el área
#     de la celda (exactextractr, weights = "area") para las 18 unidades del INE (CNPV 2022).
#   - Nacional por área: mismo cálculo sobre la unión de los 18 polígonos.
#   - Nacional agrícola (id_geo "PY-AGRO"): promedio de los departamentos ponderado por la superficie
#     de los 16 cultivos principales en la campaña 2007/08 (dato censal CAN 2008, libro MAG de 16
#     cultivos). Pesos FIJOS y anteriores a casi toda la muestra; Asunción pesa 0 (sin fila en MAG).
#   - Normal 1991–2020 por unidad y mes calendario; anomalía (mm) y porcentaje de la normal.
# No se interpola, rellena ni recorta ningún mes. Celdas con valor < 0 se tratarían como faltantes
# y se informan (no se esperan).
#
# Requiere haber corrido 02_mag_produccion.R (pesos agrícolas).
# Salida: data/clima/clima_chirps_precipitacion.csv (+ pesos en clima_pesos_agricolas.csv)

source("R/clima/00_utils.R")
suppressPackageStartupMessages({ library(terra); library(sf); library(exactextractr) })

tifs <- sort(list.files(file.path(ACQ_BASE, "chc/monthly_latam"), pattern = "^chirps-v3\\.0\\.\\d{4}\\.\\d{2}\\.tif$", full.names = TRUE))
meses <- as.IDate(paste0(sub(".*chirps-v3\\.0\\.(\\d{4})\\.(\\d{2})\\.tif$", "\\1-\\2", tifs), "-01"))
esperados <- seq(as.Date("1981-01-01"), max(as.Date(meses)), by = "month")
if (!identical(as.Date(meses), esperados)) stop("Calendario CHIRPS incompleto o desordenado")
log_msg("CHIRPS:", length(tifs), "meses", format(min(meses)), "→", format(max(meses)))

deptos <- st_read(GEOJSON_DPTOS, quiet = TRUE)
deptos <- st_transform(deptos, 4326)
deptos$id_geo <- paste0("PY-", deptos$DPTO)
pais <- st_sf(id_geo = "PY", geometry = st_union(st_make_valid(deptos)))
unidades <- rbind(deptos[, "id_geo"], pais)

r <- rast(tifs)
names(r) <- format(meses, "%Y-%m")
bb <- st_bbox(pais)
r <- crop(r, ext(bb$xmin - 0.1, bb$xmax + 0.1, bb$ymin - 0.1, bb$ymax + 0.1))
neg <- global(r < 0, "sum", na.rm = TRUE)$sum
if (sum(neg) > 0) { log_msg("CHIRPS: celdas negativas tratadas como NA:", sum(neg)); r <- classify(r, cbind(-Inf, 0 - 1e-9, NA)) }

log_msg("Extrayendo medias ponderadas para", nrow(unidades), "unidades ...")
m <- exact_extract(r, unidades, fun = "weighted_mean", weights = "area", progress = FALSE)
m <- as.data.table(m)[, id_geo := unidades$id_geo]
larg <- melt(m, id.vars = "id_geo", variable.name = "mes", value.name = "valor")
larg[, fecha := as.IDate(paste0(sub("weighted_mean\\.", "", mes), "-01"))][, mes := NULL]
if (larg[is.na(valor), .N]) stop("Medias NA en ", larg[is.na(valor), .N], " unidad-mes")
cob <- exact_extract(r[[1]], unidades, fun = "count", progress = FALSE)
log_msg("Celdas (fracción de cobertura sumada) por unidad: min", round(min(cob), 1), "max", round(max(cob), 1))

# Pesos agrícolas fijos (campaña 2007/08) --------------------------------------------------------
mag <- fread(file.path(OUT_DIR, "agro_mag_departamental.csv"))
F_A <- "1 - SERIEHISTORICA_16_principales.xlsx"
w <- mag[grepl(F_A, archivo_origen, fixed = TRUE) & nivel_geo == "departamento" &
           fecha == as.IDate("2007-07-01") & grepl("_superficie$", variable),
         .(peso_ha = sum(valor, na.rm = TRUE)), by = id_geo]
stopifnot(nrow(w) == 17)
w <- merge(data.table(id_geo = deptos$id_geo), w, all.x = TRUE)[is.na(peso_ha), peso_ha := 0]
w[, peso := peso_ha / sum(peso_ha)]
fwrite(w, file.path(OUT_DIR, "clima_pesos_agricolas.csv"))
agro <- merge(larg[id_geo != "PY"], w[, .(id_geo, peso)], by = "id_geo")[, .(valor = sum(valor * peso)), by = fecha][, id_geo := "PY-AGRO"]
larg <- rbind(larg, agro)

# Normal 1991–2020 y anomalías ----------------------------------------------------------------------
larg[, mes_cal := month(fecha)]
normal <- larg[year(fecha) %between% c(1991, 2020), .(normal = mean(valor)), by = .(id_geo, mes_cal)]
larg <- merge(larg, normal, by = c("id_geo", "mes_cal"))
larg[, `:=`(anomalia = valor - normal, pct_normal = 100 * valor / normal)]

nivel <- function(id) fifelse(id %in% c("PY", "PY-AGRO"), "nacional", "departamento")
arch <- file.path(ACQ_BASE, "chc/monthly_latam")
armar <- function(col, variable, unidad, fuente) larg[, .(
  fecha, id_geo, nivel_geo = nivel(id_geo), variable, valor = get(col), unidad, fuente,
  frecuencia = "mensual", periodo_publicado = format(fecha, "%Y.%m"),
  flag = fifelse(id_geo == "PY-AGRO", "ponderado_superficie_16_cultivos_2007_08", NA_character_),
  archivo_origen = paste0(arch, "/chirps-v3.0.", format(fecha, "%Y.%m"), ".tif"))]
out <- rbind(
  armar("valor", "precipitacion", "mm", "CHC CHIRPS v3.0 (agregado propio)"),
  armar("anomalia", "precipitacion_anomalia_1991_2020", "mm", "CHC CHIRPS v3.0 (cálculo propio)"),
  armar("pct_normal", "precipitacion_pct_normal_1991_2020", "porcentaje", "CHC CHIRPS v3.0 (cálculo propio)")
)
escribir_largo(out, "clima_chirps_precipitacion", claves = c("fecha", "id_geo", "variable"),
               insumos = c(paste0(arch, "/*.tif (", length(tifs), " archivos; hashes en inventory.csv)"), GEOJSON_DPTOS))
