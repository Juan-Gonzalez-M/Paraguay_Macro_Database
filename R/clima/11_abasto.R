# Mercado de Abasto de Asunción (MAG/SIMA con datos de la DAMA): precios mayoristas e ingresos.
#
# Insumos (Fase A):
#   mag/mercado_abasto/Precios_2021_Jun2026.xlsx — precios diarios mín./común/máx. por código de producto
#     (rubro × variedad × origen PY/AR/BR), 2021-01-04 → 2026-06-29. Guaraníes por unidad publicada
#     (KILO o DOCENA). Hojas 2 y 3 vacías.
#   mag/mercado_abasto/{Tomate,Cebolla,Lechuga,Pimiento2}.xls — ingresos mensuales (kg) al Mercado,
#     nacional y extranjero; Hoja1 2010–2023, Hoja2 1991–1997 (tomate y cebolla); resto de hojas vacías.
# Decisiones:
#   - Precios diarios: se conservan todas las filas (una duplicada en la fuente queda marcada).
#   - Precio mensual = promedio simple de los precios comunes diarios del mes (si hay dos filas el mismo
#     día para un código, primero se promedian). Se informa el número de días con cotización.
#   - Volúmenes: "-" → NA con flag; valores con decimales → flag (en 2020–2023 son sistemáticos y
#     sugieren estimaciones); fila "extranjero" idéntica a la "nacional" del mismo año (≥ 3 meses comparables, todos iguales) → flag.
# Salidas: data/clima/abasto_precios_diario.csv, data/clima/abasto_precios_mensual.csv,
#          data/clima/abasto_ingresos_mensual.csv

source("R/clima/00_utils.R")
suppressPackageStartupMessages(library(readxl))

DIR_AB <- file.path(ACQ_BASE, "mag/mercado_abasto")
f_p <- file.path(DIR_AB, "Precios_2021_Jun2026.xlsx")
stopifnot(identical(excel_sheets(f_p), c("Hoja1", "Hoja2", "Hoja3")))
for (h in c("Hoja2", "Hoja3")) stopifnot(nrow(read_excel(f_p, sheet = h, col_names = FALSE)) == 0)
p <- as.data.table(read_excel(f_p, sheet = "Hoja1"))
p[, fila := .I + 1L]
p[, fecha := as.IDate(format(FECHA, "%Y-%m-%d", tz = "UTC"))]
p[, clave := paste(NOMPRO_050, fifelse(is.na(VARPRO_050), "sin_variedad", VARPRO_050), NACEXT_050, sep = "_")]
p[, clave := gsub("[^a-z0-9_]+", "_", tolower(clave))]
p[, unidad := fifelse(UNIMED_050 == "KILO", "PYG/kg", fifelse(UNIMED_050 == "DOCEN", "PYG/docena", paste0("PYG/", UNIMED_050)))]
p[, dup := .N > 1, by = .(fecha, CODPRO_050)]
p[, flag_base := paste0("codigo:", CODPRO_050, "; calidad:", CALIDAD, "; oferta:", OFERTA,
                        fifelse(dup, "; fila_duplicada_en_fuente", ""),
                        fifelse(PRECIO_MIN > PRECIO_COM | PRECIO_COM > PRECIO_MAX, "; orden_min_com_max_no_se_cumple", ""))]
log_msg("Abasto precios:", nrow(p), "filas;", p[(dup), .N], "filas en días duplicados;",
        p[PRECIO_MIN > PRECIO_COM | PRECIO_COM > PRECIO_MAX, .N], "filas con mín>común o común>máx")
dl <- melt(p, id.vars = c("fecha", "clave", "unidad", "flag_base", "fila"),
           measure.vars = c("PRECIO_MIN", "PRECIO_COM", "PRECIO_MAX"), variable.name = "tipo", value.name = "valor")
dl[, variable := paste0("abasto_precio_", c(PRECIO_MIN = "minimo", PRECIO_COM = "comun", PRECIO_MAX = "maximo")[as.character(tipo)], "__", clave)]
diario <- dl[, .(fecha, id_geo = "PY-MERCADO-ABASTO-ASU", nivel_geo = "mercado", variable, valor, unidad,
                 fuente = "MAG/SIMA - DAMA, Mercado de Abasto de Asunción", frecuencia = "diaria",
                 periodo_publicado = format(fecha), flag = flag_base,
                 archivo_origen = paste0(f_p, "#Hoja1!fila", fila))]
escribir_largo(diario, "abasto_precios_diario", claves = c("archivo_origen", "variable"), insumos = huella(f_p))

com <- p[, .(valor = mean(PRECIO_COM)), by = .(fecha, clave, unidad)]
com[, mes := as.IDate(format(fecha, "%Y-%m-01"))]
men <- com[, .(promedio = mean(valor), dias = .N), by = .(mes, clave, unidad)]
mensual <- rbind(
  men[, .(fecha = mes, variable = paste0("abasto_precio_comun_promedio__", clave), valor = promedio, unidad)],
  men[, .(fecha = mes, variable = paste0("abasto_dias_con_cotizacion__", clave), valor = dias, unidad = "dias")]
)[, `:=`(id_geo = "PY-MERCADO-ABASTO-ASU", nivel_geo = "mercado", fuente = "MAG/SIMA - DAMA (promedio mensual propio)",
         frecuencia = "mensual", periodo_publicado = NA_character_, flag = NA_character_, archivo_origen = f_p)]
escribir_largo(mensual, "abasto_precios_mensual", claves = c("fecha", "id_geo", "variable"), insumos = huella(f_p))

# Ingresos mensuales -------------------------------------------------------------------------------
MESES <- c("ENE.", "FBR.", "MZ.", "ABR.", "MAYO", "JUNIO", "JULIO", "AG.", "SET.", "OCT.", "NOV.", "DIC.")
vols <- list(); ctrl <- list()
for (f in list.files(DIR_AB, pattern = "\\.xls$", full.names = TRUE)) for (sh in excel_sheets(f)) {
  m <- as.matrix(read_excel(f, sheet = sh, col_names = FALSE, .name_repair = "minimal", col_types = "text"))
  if (!length(m)) next
  rubro <- tolower(sub("2$", "", tools::file_path_sans_ext(basename(f))))
  origen <- NA_character_; hdr <- NULL
  for (i in seq_len(nrow(m))) {
    c1 <- toupper(ifelse(is.na(m[i, 1]), "", m[i, 1]))
    fila_txt <- toupper(paste(na.omit(m[i, ]), collapse = " "))
    if (!grepl("^(19|20)\\d\\d$", trimws(c1))) {
      if (grepl("NACION", fila_txt)) origen <- "nacional"
      if (grepl("EXTRAN", fila_txt)) origen <- "extranjero"
    }
    if (ncol(m) >= 13 && all(MESES %in% trimws(m[i, 2:13]))) hdr <- trimws(m[i, 2:13])
    if (grepl("^(19|20)\\d\\d$", trimws(c1))) {
      if (is.na(origen) || is.null(hdr)) stop(basename(f), " [", sh, "] fila ", i, ": año sin bloque/encabezado")
      txt <- trimws(m[i, 2:13]); v <- suppressWarnings(as.numeric(txt))
      vols[[length(vols) + 1]] <- data.table(rubro, origen, anio = as.integer(c1), mes = match(hdr, MESES), txt, valor = v,
                                             archivo = f, hoja = sh, celda = sprintf("R%dC%d", i, 2:13))
    }
  }
}
v <- rbindlist(vols)
ctrl <- v[, .(celdas = .N, numericas = sum(!is.na(valor)), guion = sum(txt == "-", na.rm = TRUE), vacias = sum(is.na(txt))), by = .(rubro, hoja, origen)]
print(ctrl)
dupl <- v[, .N, by = .(rubro, origen, anio, mes)][N > 1]
if (nrow(dupl)) { print(dupl); stop("Ingresos: el mismo rubro-origen-año-mes aparece en más de una hoja") }
iguales <- merge(v[origen == "nacional", .(rubro, anio, mes, vn = valor)], v[origen == "extranjero", .(rubro, anio, mes, ve = valor)])
iguales <- iguales[, .(identica = sum(!is.na(vn) & !is.na(ve)) >= 3 && all((vn == ve)[!is.na(vn) & !is.na(ve)])), by = .(rubro, anio)][(identica)]
log_msg("Ingresos: filas 'extranjero' idénticas a 'nacional':", paste(iguales[, paste(rubro, anio)], collapse = ", "))
v[, flag := paste0(
  fifelse(is.na(txt), "celda_vacia", fifelse(is.na(valor) & txt == "-", "ningun_valor(-)", fifelse(is.na(valor), paste0("texto:", txt), ""))),
  fifelse(!is.na(valor) & abs(valor - round(valor)) > 1e-9, "valor_con_decimales(posible_estimacion)", ""))]
v[iguales, on = .(rubro, anio), flag := paste0(flag, fifelse(origen == "extranjero", "; fila_identica_a_nacional(posible_error_de_copia)", ""))]
v[, flag := sub("^; ", "", flag)][flag == "", flag := NA_character_]
ing <- v[, .(fecha = as.IDate(sprintf("%d-%02d-01", anio, mes)), id_geo = "PY-MERCADO-ABASTO-ASU", nivel_geo = "mercado",
             variable = paste0("abasto_ingreso__", rubro, "__", origen), valor, unidad = "kg",
             fuente = "MAG/SIMA - DAMA, ingresos mensuales al Mercado de Abasto", frecuencia = "mensual",
             periodo_publicado = paste(anio, MESES[mes]), flag, archivo_origen = paste0(archivo, "#", hoja, "!", celda))]
escribir_largo(ing, "abasto_ingresos_mensual", claves = c("fecha", "id_geo", "variable"),
               insumos = huella(list.files(DIR_AB, pattern = "\\.xls$", full.names = TRUE)))
