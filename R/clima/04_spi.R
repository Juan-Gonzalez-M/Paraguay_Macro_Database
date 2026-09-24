# SPI (Índice de Precipitación Estandarizado) 1, 3, 6 y 12 meses por departamento y nacional.
#
# Insumo: data/clima/clima_chirps_precipitacion.csv (variable "precipitacion"), de 03_chirps.R.
# Método: paquete SPEI::spi, distribución gamma, calibración 1991–2020 (normal OMM), sobre la serie
# de precipitación YA agregada por unidad (no es el promedio de SPI por celda; se documenta).
# Los primeros (escala − 1) meses de cada serie quedan NA por construcción y se excluyen.
# Salida: data/clima/clima_spi.csv

source("R/clima/00_utils.R")
suppressPackageStartupMessages(library(SPEI))

p <- fread(file.path(OUT_DIR, "clima_chirps_precipitacion.csv"))[variable == "precipitacion"]
setorder(p, id_geo, fecha)
ESCALAS <- c(1, 3, 6, 12)
res <- list()
for (g in unique(p$id_geo)) {
  s <- p[id_geo == g]
  inicio <- c(year(s$fecha[1]), month(s$fecha[1]))
  y <- ts(s$valor, start = inicio, frequency = 12)
  for (k in ESCALAS) {
    v <- as.numeric(suppressWarnings(spi(y, scale = k, distribution = "Gamma",
                                         ref.start = c(1991, 1), ref.end = c(2020, 12), verbose = FALSE))$fitted)
    res[[length(res) + 1]] <- data.table(fecha = s$fecha, id_geo = g, nivel_geo = s$nivel_geo, k, valor = v)
  }
}
d <- rbindlist(res)
d[, pos := seq_len(.N), by = .(id_geo, k)]
d <- d[pos > k - 1]  # NA iniciales por construcción (k − 1 meses)
n_inf <- d[!is.finite(valor) & !is.na(valor), .N]
if (d[is.na(valor), .N] || n_inf) stop("SPI con NA/Inf fuera de los meses iniciales: ", d[is.na(valor), .N], " / ", n_inf)
out <- d[, .(fecha, id_geo, nivel_geo, variable = paste0("spi_", k), valor, unidad = "indice_estandarizado",
             fuente = "Cálculo propio sobre CHC CHIRPS v3.0 (SPEI::spi, gamma, ref. 1991-2020)",
             frecuencia = "mensual", periodo_publicado = NA_character_,
             flag = fifelse(id_geo == "PY-AGRO", "ponderado_superficie_16_cultivos_2007_08", NA_character_),
             archivo_origen = file.path(OUT_DIR, "clima_chirps_precipitacion.csv"))]
escribir_largo(out, "clima_spi", claves = c("fecha", "id_geo", "variable"),
               insumos = huella(file.path(OUT_DIR, "clima_chirps_precipitacion.csv")))
