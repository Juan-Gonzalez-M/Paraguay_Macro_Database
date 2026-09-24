# Agrega (o actualiza) en proyectos/00_inventario_series.csv las series del bloque clima/agro que viven
# FUERA de la base DuckDB (data/clima/), a partir de data/clima/00_catalogo_variables.csv.
# Idempotente: elimina las filas con interfaz "data/clima/…" de una corrida anterior y las vuelve a
# agregar; no toca las filas que describen la base. Correr después de 98_catalogo.R.
#   Rscript R/clima/97_inventario_proyectos.R

source("R/clima/00_utils.R")

f_inv <- "proyectos/00_inventario_series.csv"
f_cat <- file.path(OUT_DIR, "00_catalogo_variables.csv")
stopifnot(file.exists(f_inv), file.exists(f_cat))
# Las filas de la base se conservan BYTE A BYTE (lectura como texto); solo se quitan las líneas externas
# de una corrida anterior (las que terminan en ,"data/clima/…") y se agregan las nuevas al final, con el
# mismo estilo del archivo: textos entre comillas, fechas y números sin comillas.
lin <- readLines(f_inv, encoding = "UTF-8")
es_ext <- grepl(',"data/clima/[^"]*"$', lin)
base <- lin[!es_ext]
cat_v <- fread(f_cat)

FREC <- c(mensual = "monthly", diaria = "daily", anual = "annual", campania = "annual_crop_campaign",
          bimestral_movil = "bimonthly_rolling", trimestral_movil = "quarterly_rolling", vintage_mensual = "monthly_vintage")
frec_en <- function(x) vapply(strsplit(x, ","), function(v) paste(ifelse(v %in% names(FREC), FREC[v], v), collapse = ","), "")
q <- function(x) paste0('"', gsub('"', '""', x), '"')

nuevas <- cat_v[, paste(
  q("data/clima (externa)"), q(archivo),
  q(paste0("externo:data_clima:", sub("\\.csv$", "", archivo), ":", variable)),
  q(variable), q(frec_en(frecuencia)),
  as.character(desde), as.character(hasta), obs, q(unidad),
  q(fifelse(n_id_geo > 1, paste0("panel_geografico(", n_id_geo, " unidades: ", nivel_geo, ")"), "scalar_series")),
  q("Externa (fuera de la base; no revisada)"), q(""), q(""),
  q(paste0("data/clima/", archivo)), sep = ",")]
writeLines(c(base, nuevas), f_inv, useBytes = TRUE)
log_msg("Inventario de series:", length(base) - 1, "filas de la base (sin cambios) +", length(nuevas), "series externas de data/clima")
