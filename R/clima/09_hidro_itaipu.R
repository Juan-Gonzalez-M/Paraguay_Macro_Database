# Itaipú Binacional: hidrología diaria del embalse y generación horaria (ONS Brasil, datos abiertos, CC-BY).
#
# Fuentes (descarga directa, sin registro) a <ACQ_NUEVA>/ons/:
#   - Dados Hidráulicos por Reservatório – Base diária: DADOS_HIDROLOGICOS_RES_<AAAA>.parquet (2000–hoy),
#     se filtra el reservatorio ITAIPU (id PNITAI).
#   - Geração de Itaipu Binacional – Base horária: GERACAO_ITAIPU.parquet (total, 60 Hz, 50 Hz, Brasil).
# ONS advierte que los datos se consolidan y pueden revisarse después de publicados: cada corrida
# refresca los archivos del año en curso y deja su hash en inventory.csv (vintage).
# Marcas de tiempo: ONS publica instantes sin zona (hora local); se leen como UTC "ingenuo" para no
# desplazar fechas. Día = fecha del instante; mes = mes del instante.
#
# Agregación mensual (sin imputar):
#   hidrología: promedio mensual de caudales (m3/s), nivel aguas arriba (m) y volumen útil (%);
#   generación: potencia media (MWmed) y energía (GWh = Σ MWmed horarios / 1000) con horas observadas.
#   Derivada explícita: itaipu_generacion_no_brasil = total − Brasil (≈ energía destinada a Paraguay).
# Salidas: data/clima/hidro_itaipu_diario.csv, data/clima/hidro_itaipu_mensual.csv

source("R/clima/00_utils.R")
suppressPackageStartupMessages(library(arrow))

S3 <- "https://ons-aws-prod-opendata.s3.amazonaws.com/dataset"
anio_actual <- as.integer(format(Sys.Date(), "%Y"))

# Hidrología ------------------------------------------------------------------------------------------
f_h <- vapply(2000:anio_actual, function(a) {
  descargar(sprintf("%s/dados_hidrologicos_di/DADOS_HIDROLOGICOS_RES_%d.parquet", S3, a),
            sprintf("ons/hidrologia_diaria/DADOS_HIDROLOGICOS_RES_%d.parquet", a),
            refrescar = (a == anio_actual && !file.exists(file.path(ACQ_NUEVA, sprintf("ons/hidrologia_diaria/.refrescado_%s", Sys.Date())))))
}, character(1))
file.create(file.path(ACQ_NUEVA, sprintf("ons/hidrologia_diaria/.refrescado_%s", Sys.Date())))
descargar(paste0(S3, "/dados_hidrologicos_di/DicionarioDados_DadosHidrologicosDiarios.json"),
          "ons/hidrologia_diaria/DicionarioDados_DadosHidrologicosDiarios.json")

VARS_H <- c(val_vazaoafluente = "caudal_afluente", val_vazaonatural = "caudal_natural",
            val_vazaoincremental = "caudal_incremental", val_vazaoturbinada = "caudal_turbinado",
            val_vazaovertida = "caudal_vertido", val_vazaodefluente = "caudal_defluente",
            val_nivelmontante = "nivel_aguas_arriba", val_volumeutilcon = "volumen_util")
UNID_H <- c(caudal_afluente = "m3/s", caudal_natural = "m3/s", caudal_incremental = "m3/s", caudal_turbinado = "m3/s",
            caudal_vertido = "m3/s", caudal_defluente = "m3/s", nivel_aguas_arriba = "m", volumen_util = "porcentaje")

h <- rbindlist(lapply(f_h, function(f) {
  x <- as.data.table(read_parquet(f))
  x <- x[id_reservatorio == "PNITAI"]
  x[, archivo := f]
}), fill = TRUE)
h[, fecha := as.IDate(format(din_instante, "%Y-%m-%d", tz = "UTC"))]
dup <- h[, .N, by = fecha][N > 1]
if (nrow(dup)) stop("Hidrología Itaipú: fechas duplicadas: ", nrow(dup))
esperadas <- seq(min(h$fecha), max(h$fecha), by = "day")
log_msg("Hidrología Itaipú:", nrow(h), "días", format(min(h$fecha)), "→", format(max(h$fecha)),
        "; días faltantes en el rango:", length(setdiff(esperadas, h$fecha)))
hl <- melt(h[, c("fecha", "archivo", names(VARS_H)), with = FALSE], id.vars = c("fecha", "archivo"),
           variable.name = "col", value.name = "valor")
hl[, variable := paste0("itaipu_", VARS_H[as.character(col)])]
hl[, unidad := UNID_H[sub("^itaipu_", "", variable)]]
diario <- hl[, .(fecha, id_geo = "ONS-PNITAI", nivel_geo = "estacion", variable, valor, unidad,
                 fuente = "ONS Brasil, Dados Hidráulicos por Reservatório (diario)", frecuencia = "diaria",
                 periodo_publicado = format(fecha), flag = fifelse(is.na(valor), "sin_dato_en_fuente", NA_character_),
                 archivo_origen = archivo)]
escribir_largo(diario, "hidro_itaipu_diario", claves = c("fecha", "id_geo", "variable"), insumos = huella(f_h))

hl[, mes := as.IDate(format(fecha, "%Y-%m-01"))]
hm <- hl[, .(valor = if (all(is.na(valor))) NA_real_ else mean(valor, na.rm = TRUE), n = sum(!is.na(valor))), by = .(mes, variable, unidad)]
hm[, dias_mes := as.integer(format(seq(as.Date(mes[1]), by = "month", length.out = 2)[2] - 1, "%d")), by = mes]
hm[, flag := fifelse(n < dias_mes, paste0("mes_incompleto:", n, "/", dias_mes, "_dias"), NA_character_)]
hid_m <- hm[, .(fecha = mes, id_geo = "ONS-PNITAI", nivel_geo = "estacion", variable = paste0(variable, "_promedio"),
                valor, unidad, fuente = "ONS Brasil (promedio mensual propio de datos diarios)", frecuencia = "mensual",
                periodo_publicado = NA_character_, flag, archivo_origen = file.path(ACQ_NUEVA, "ons/hidrologia_diaria"))]

# Generación -------------------------------------------------------------------------------------------
f_g <- descargar(paste0(S3, "/geracao_itaipu/GERACAO_ITAIPU.parquet"), "ons/geracao_itaipu/GERACAO_ITAIPU.parquet",
                 refrescar = !file.exists(file.path(ACQ_NUEVA, sprintf("ons/geracao_itaipu/.refrescado_%s", Sys.Date()))))
file.create(file.path(ACQ_NUEVA, sprintf("ons/geracao_itaipu/.refrescado_%s", Sys.Date())))
descargar(paste0(S3, "/geracao_itaipu/DicionarioDados_Geracao_Itaipu_Binacional.json"),
          "ons/geracao_itaipu/DicionarioDados_Geracao_Itaipu_Binacional.json")
g <- as.data.table(read_parquet(f_g))
stopifnot(identical(names(g), c("din_instante", "val_itaipu_total", "val_itaipu_60hz", "val_itaipu_50hz", "val_itaipu_50hz_br", "val_itaipu_br")))
g[, mes := as.IDate(format(din_instante, "%Y-%m-01", tz = "UTC"))]
g[, val_itaipu_no_brasil := val_itaipu_total - val_itaipu_br]
VARS_G <- c(val_itaipu_total = "total", val_itaipu_60hz = "sector_60hz", val_itaipu_50hz = "sector_50hz",
            val_itaipu_br = "destino_brasil", val_itaipu_no_brasil = "no_brasil_derivado")
gl <- melt(g, id.vars = c("din_instante", "mes"), measure.vars = names(VARS_G), variable.name = "col", value.name = "mw")
gm <- gl[, .(mwmed = mean(mw, na.rm = TRUE), gwh = sum(mw, na.rm = TRUE) / 1000, horas = sum(!is.na(mw))), by = .(mes, col)]
gm[, horas_mes := 24L * as.integer(format(seq(as.Date(mes[1]), by = "month", length.out = 2)[2] - 1, "%d")), by = mes]
gm[, flag := fifelse(abs(horas - horas_mes) > 1, paste0("horas_observadas:", horas, "/", horas_mes), NA_character_)]
gm[col == "val_itaipu_no_brasil", flag := fifelse(is.na(flag), "derivado:total_menos_brasil", paste0(flag, "; derivado:total_menos_brasil"))]
gen_m <- rbind(
  gm[, .(fecha = mes, variable = paste0("itaipu_generacion_", VARS_G[as.character(col)], "_mwmed"), valor = mwmed, unidad = "MWmed", flag)],
  gm[, .(fecha = mes, variable = paste0("itaipu_generacion_", VARS_G[as.character(col)], "_gwh"), valor = gwh, unidad = "GWh", flag)]
)[, `:=`(id_geo = "ONS-ITAIPU", nivel_geo = "estacion", fuente = "ONS Brasil, Geração de Itaipu (horaria; agregado propio)",
         frecuencia = "mensual", periodo_publicado = NA_character_, archivo_origen = f_g)]
log_msg("Generación Itaipú:", nrow(g), "horas,", format(min(g$din_instante)), "→", format(max(g$din_instante)),
        "; meses con horas incompletas:", gm[!is.na(flag) & col == "val_itaipu_total" & grepl("horas", flag), .N])

escribir_largo(rbind(hid_m, gen_m, use.names = TRUE), "hidro_itaipu_mensual",
               claves = c("fecha", "id_geo", "variable"), insumos = huella(c(f_h, f_g)))
