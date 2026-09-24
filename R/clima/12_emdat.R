# EM-DAT (CRED/UCLouvain): desastres registrados en Paraguay.
#
# REQUISITO: registro gratuito (uso no comercial) y descarga MANUAL del Excel de EM-DAT; ver
# data/clima/README.md, sección "Instrucciones: EM-DAT". Copiar el archivo descargado, sin editarlo, a
#   input/acquisition_candidates/clima_agro_2026-09-23_faseB/emdat/
# El script toma el .xlsx más reciente de esa carpeta, lo registra en inventory.csv (hash) y filtra
# ISO = PRY. No redistribuye el Excel completo (licencia EM-DAT).
#
# Salidas:
#   data/clima/eventos_emdat_paraguay.csv — un registro por evento (tabla de eventos, no formato largo)
#   data/clima/eventos_emdat_mensual.csv  — formato largo mensual: número de eventos que COMIENZAN en el mes
#     por tipo de desastre, y afectados/daños de esos eventos imputados al mes de inicio (sin prorratear).
#     Eventos sin mes de inicio quedan fuera del mensual y se informan (siguen en la tabla de eventos).

source("R/clima/00_utils.R")
suppressPackageStartupMessages(library(readxl))

DIR_EM <- file.path(ACQ_NUEVA, "emdat"); dir.create(DIR_EM, showWarnings = FALSE, recursive = TRUE)
fx <- list.files(DIR_EM, pattern = "\\.xlsx$", full.names = TRUE)
if (!length(fx)) stop("No hay Excel de EM-DAT en ", DIR_EM, ". Ver data/clima/README.md (Instrucciones: EM-DAT).")
f <- fx[which.max(file.mtime(fx))]
registrar_descarga(file.path("emdat", basename(f)), "https://public.emdat.be (descarga manual del usuario)", "manual")
log_msg("EM-DAT: usando", basename(f))

x <- as.data.table(read_excel(f, sheet = 1, guess_max = 50000))
REQ <- c("DisNo.", "Disaster Group", "Disaster Subgroup", "Disaster Type", "Disaster Subtype", "ISO", "Country",
         "Location", "Start Year", "Start Month", "Start Day", "End Year", "End Month", "End Day",
         "Total Deaths", "Total Affected", "Total Damage ('000 US$)", "Total Damage, Adjusted ('000 US$)")
faltan <- setdiff(REQ, names(x))
if (length(faltan)) stop("El Excel de EM-DAT no tiene las columnas esperadas: ", paste(faltan, collapse = ", "),
                         ". Revisar si cambió el formato de exportación.")
py <- x[ISO == "PRY"]
log_msg("EM-DAT: filas totales", nrow(x), "; Paraguay", nrow(py))
if (!nrow(py)) stop("El archivo no contiene eventos de Paraguay (ISO = PRY): revisar el filtro de la exportación.")
if (anyDuplicated(py$`DisNo.`)) stop("DisNo. duplicado en el archivo")

ev <- copy(py)
setnames(ev, names(ev), gsub("[^a-z0-9]+", "_", tolower(names(ev))))
ev[, archivo_origen := f]
fwrite(ev, file.path(OUT_DIR, "eventos_emdat_paraguay.csv"))
log_msg("escrito", file.path(OUT_DIR, "eventos_emdat_paraguay.csv"), ":", nrow(ev), "eventos,",
        min(py$`Start Year`), "→", max(py$`Start Year`))

sin_mes <- py[is.na(`Start Month`)]
if (nrow(sin_mes)) log_msg("EM-DAT: eventos sin mes de inicio (fuera del mensual):", paste(sin_mes$`DisNo.`, collapse = ", "))
m <- py[!is.na(`Start Month`)]
m[, `:=`(fecha = as.IDate(sprintf("%d-%02d-01", `Start Year`, as.integer(`Start Month`))),
         tipo = gsub("[^a-z0-9]+", "_", tolower(`Disaster Type`)))]
agg <- m[, .(eventos = .N, afectados = sum(`Total Affected`, na.rm = TRUE), afectados_na = sum(is.na(`Total Affected`)),
             muertes = sum(`Total Deaths`, na.rm = TRUE),
             danio_ajustado = sum(`Total Damage, Adjusted ('000 US$)`, na.rm = TRUE), danio_na = sum(is.na(`Total Damage, Adjusted ('000 US$)`)),
             ids = paste(`DisNo.`, collapse = ",")), by = .(fecha, tipo)]
largo <- rbind(
  agg[, .(fecha, variable = paste0("emdat_eventos_inicio__", tipo), valor = eventos, unidad = "eventos", flag = paste0("DisNo:", ids))],
  agg[, .(fecha, variable = paste0("emdat_total_afectados__", tipo), valor = afectados, unidad = "personas",
          flag = paste0("DisNo:", ids, fifelse(afectados_na > 0, paste0("; eventos_sin_dato:", afectados_na), "")))],
  agg[, .(fecha, variable = paste0("emdat_muertes__", tipo), valor = muertes, unidad = "personas", flag = paste0("DisNo:", ids))],
  agg[, .(fecha, variable = paste0("emdat_danio_total_ajustado__", tipo), valor = danio_ajustado, unidad = "miles_USD_ajustados_EMDAT",
          flag = paste0("DisNo:", ids, fifelse(danio_na > 0, paste0("; eventos_sin_dato:", danio_na), "")))]
)[, `:=`(id_geo = "PY", nivel_geo = "nacional", fuente = "EM-DAT (CRED/UCLouvain), agregado propio por mes de inicio",
         frecuencia = "mensual", periodo_publicado = NA_character_, archivo_origen = f)]
escribir_largo(largo, "eventos_emdat_mensual", claves = c("fecha", "id_geo", "variable"), insumos = huella(f))
