# Índices ENSO observados (NOAA): ONI, RONI, MEI.v2, SOI y SST Niño 3.4 mensual.
#
# Insumos:
#   Fase A (ya descargados): noaa/oni.ascii.txt, noaa/RONI.ascii.txt, noaa/meiv2.csv
#   Fase B (se descargan si faltan): noaa/soi.txt, noaa/sstoi.indices
# Convenciones de fecha (sin rezagos: los rezagos se aplican en el análisis):
#   ONI/RONI: temporada de 3 meses fechada en el MES CENTRAL (DJF → enero), como en los proyectos 09/12/13.
#   MEI.v2:   temporada bimestral fechada en el SEGUNDO mes (DJ → enero), como la publica NOAA PSL.
#   SOI y Niño 3.4: mes calendario.
# Salida: data/clima/enso_indices.csv

source("R/clima/00_utils.R")

f_oni  <- file.path(ACQ_BASE, "noaa/oni.ascii.txt")
f_roni <- file.path(ACQ_BASE, "noaa/RONI.ascii.txt")
f_mei  <- file.path(ACQ_BASE, "noaa/meiv2.csv")
f_soi  <- descargar("https://www.cpc.ncep.noaa.gov/data/indices/soi", "noaa/soi.txt")
f_sst  <- descargar("https://www.cpc.ncep.noaa.gov/data/indices/sstoi.indices", "noaa/sstoi.indices")

TEMPORADAS <- c(DJF = 1, JFM = 2, FMA = 3, MAM = 4, AMJ = 5, MJJ = 6, JJA = 7, JAS = 8, ASO = 9, SON = 10, OND = 11, NDJ = 12)
BIMESTRES  <- c("DJ", "JF", "FM", "MA", "AM", "MJ", "JJ", "JA", "AS", "SO", "ON", "ND")

base <- function(dt, variable, unidad, fuente, frecuencia, archivo) {
  dt[, .(fecha, id_geo = "GLOBAL", nivel_geo = "global", variable, valor, unidad, fuente,
         frecuencia, periodo_publicado, flag = NA_character_, archivo_origen = archivo)]
}

# ONI (anomalía y temperatura total) -----------------------------------------
oni <- fread(f_oni)
stopifnot(identical(names(oni), c("SEAS", "YR", "TOTAL", "ANOM")), all(oni$SEAS %in% names(TEMPORADAS)))
oni[, fecha := as.IDate(sprintf("%d-%02d-01", YR, TEMPORADAS[SEAS]))][, periodo_publicado := paste(SEAS, YR)]
out <- list(
  base(oni[, .(fecha, valor = ANOM, periodo_publicado)], "oni", "grados_C", "NOAA CPC ONI", "trimestral_movil", f_oni),
  base(oni[, .(fecha, valor = TOTAL, periodo_publicado)], "nino34_sst_3m", "grados_C", "NOAA CPC ONI", "trimestral_movil", f_oni)
)

# RONI --------------------------------------------------------------------------
roni <- fread(f_roni)
stopifnot(identical(names(roni), c("SEAS", "YR", "ANOM")))
roni[, fecha := as.IDate(sprintf("%d-%02d-01", YR, TEMPORADAS[SEAS]))][, periodo_publicado := paste(SEAS, YR)]
out[[3]] <- base(roni[, .(fecha, valor = ANOM, periodo_publicado)], "roni", "grados_C", "NOAA CPC RONI", "trimestral_movil", f_roni)

# MEI.v2: el encabezado declara faltante -999 pero el archivo usa -9999; se tratan ambos como faltante
# y esas filas (meses aún no publicados) se excluyen.
mei <- fread(f_mei, skip = 1, header = FALSE, col.names = c("fecha", "valor"))
mei[, fecha := as.IDate(fecha)]
n_falt <- mei[valor <= -999, .N]
mei <- mei[valor > -999]
mei[, periodo_publicado := paste(BIMESTRES[month(fecha)], year(fecha))]
log_msg("MEI.v2: excluidas", n_falt, "filas con código de faltante (meses sin publicar)")
out[[4]] <- base(mei, "mei_v2", "indice_estandarizado", "NOAA PSL MEI.v2", "bimestral_movil", f_mei)

# SOI (dos bloques: anomalía y estandarizado), ancho fijo: año (4) + 12 campos de 6 --------
lineas <- readLines(f_soi)
leer_bloque <- function(ini, fin) {
  l <- lineas[ini:fin]; l <- l[grepl("^\\d{4}", l)]
  rbindlist(lapply(l, function(s) {
    v <- as.numeric(substring(s, seq(5, 71, 6), seq(10, 76, 6)))
    data.table(anio = as.integer(substr(s, 1, 4)), mes = 1:12, valor = v)
  }))
}
i_std <- grep("STANDARDIZED", lineas)
stopifnot(length(i_std) == 1, grepl("ANOMALY", lineas[2]))
soi <- rbind(leer_bloque(1, i_std - 1)[, variable := "soi_anomalia"],
             leer_bloque(i_std, length(lineas))[, variable := "soi_estandarizado"])
n_falt <- soi[valor <= -999, .N]
soi <- soi[valor > -999]
log_msg("SOI: excluidas", n_falt, "celdas con -999.9 (meses sin publicar)")
soi[, `:=`(fecha = as.IDate(sprintf("%d-%02d-01", anio, mes)), periodo_publicado = sprintf("%d %s", anio, toupper(month.abb[mes])))]
out[[5]] <- soi[, .(fecha, id_geo = "GLOBAL", nivel_geo = "global", variable, valor,
                    unidad = fifelse(variable == "soi_anomalia", "diferencia_presiones_estandarizadas", "indice_estandarizado"),
                    fuente = "NOAA CPC SOI", frecuencia = "mensual", periodo_publicado, flag = NA_character_,
                    archivo_origen = f_soi)]

# SST Niño 3.4 mensual (1982-) --------------------------------------------------
sst <- fread(f_sst)
stopifnot(identical(names(sst)[1:2], c("YR", "MON")), ncol(sst) == 10)
setnames(sst, c("YR", "MON", "n12", "n12_anom", "n3", "n3_anom", "n4", "n4_anom", "n34", "n34_anom"))
sst[, `:=`(fecha = as.IDate(sprintf("%d-%02d-01", YR, MON)), periodo_publicado = sprintf("%d %02d", YR, MON))]
out[[6]] <- base(sst[, .(fecha, valor = n34_anom, periodo_publicado)], "nino34_anom_mensual", "grados_C", "NOAA CPC sstoi.indices", "mensual", f_sst)
out[[7]] <- base(sst[, .(fecha, valor = n34, periodo_publicado)], "nino34_sst_mensual", "grados_C", "NOAA CPC sstoi.indices", "mensual", f_sst)

enso <- rbindlist(out)
escribir_largo(enso, "enso_indices", claves = c("fecha", "id_geo", "variable"),
               insumos = huella(c(f_oni, f_roni, f_mei, f_soi, f_sst)))
