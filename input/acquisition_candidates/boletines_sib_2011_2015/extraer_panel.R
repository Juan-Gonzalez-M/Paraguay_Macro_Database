# Capa 2: panel por entidad a partir de la capa 1 (extraer_celdas.R). Asigna a cada celda numérica la
# entidad (o agregado) a la que se refiere, el concepto, la moneda y el período, SIN cambiar el valor.
# Uso (desde esta carpeta): Rscript extraer_panel.R
# Entradas: extraidos/celdas_numericas.parquet, alias_entidades.csv (alias revisables, versionado)
# Salidas (extraidos/):
#   panel_entidades.parquet   una fila por celda asignada: fecha_corte, tipo, diseño, versión, archivo, hoja,
#                             fila, columna, entidad_publicada, entidad_clave, es_agregado, eje (fila|columna),
#                             concepto (ruta publicada), moneda, periodo_publicado, periodo (mes), unidad_publicada,
#                             valor_publicado, valor.
#   diccionario_entidades.csv cada nombre publicado distinto -> clave normalizada, n de celdas, meses, método.
#   control_panel.csv         por tipo, diseño y hoja: celdas de la capa 1, asignadas y no asignadas.
# Reglas:
#   - Una etiqueta es ENTIDAD si, normalizada (mayúsculas, sin acentos, sin numeración «3- », sin «(*)» ni
#     comillas, sin forma societaria final), coincide con un nombre de la lista de entidades o de alias, o
#     tiene la forma de un nombre de entidad (Banco…, …Financiera…, …Cambios…, …S.A.…) y no es un rubro de
#     la lista EXCLUIR. Es AGREGADO si es un total o subtotal (SISTEMA, SUB-TOTAL, grupos de propiedad).
#   - «SUB-TOTAL» se publica sin grupo: se le agrega la sección vigente («SUB-TOTAL | PROPIEDAD LOCAL…»).
#   - Si la entidad está en la fila, el concepto es el encabezado de columna; si está en la columna, el
#     concepto es la etiqueta de fila y el resto del encabezado (sin la entidad ni la moneda) va a
#     «encabezado_resto».
#   - Período: fecha de corte del archivo, salvo que el encabezado nombre un mes («Diciembre 2014») o un par
#     de meses («Dic-14 Ene-15»): entonces se guarda el texto y el mes (el último del par). Nada se deriva.
#   - Herencia por columna (asignacion = "heredada_columna"): ver el comentario en el código.
#   - Celdas sin entidad reconocible quedan en la capa 1 y se cuentan en el control (no se descartan).

suppressPackageStartupMessages({library(data.table); library(arrow)})
N <- as.data.table(read_parquet("extraidos/celdas_numericas.parquet"))

norm <- function(x) {
  x <- toupper(stringi::stri_trans_general(x, "Latin-ASCII"))
  x <- gsub('["“”]', "", x)
  x <- gsub("\\(\\*+\\)", "", x)
  x <- sub("^\\s*\\d+\\s*-\\s*", "", x)                        # numeración «3- »
  x <- gsub("\\([^)]*\\)", "", x)                               # siglas entre paréntesis: (CEFISA), (INTERFISA BANCO)
  x <- gsub("[.,-]", " ", x)
  x <- gsub("\\s+", " ", trimws(x))
  x <- gsub("\\bS ?A( ?E ?C ?A| ?E)?\\b|\\bN A$", "", x)          # formas societarias (S.A., S.A.E.C.A., N.A.)
  x <- gsub("\\s+", " ", trimws(x))
  sub(" DE$", "", x)
}
EXCLUIR <- c("CAJA Y BANCOS", "CAJAS Y BANCOS", "BANCO CENTRAL", "BANCOS", "FINANCIERAS", "EMPRESAS FINANCIERAS",
             "PROPIEDAD", "TIPO DE CAMBIO")
# Rótulos de concepto, notas y membretes que contienen palabras de nombres de entidad
RX_EXCLUIR <- "^(BALANCE|ESTADO DE|DEPOSITOS EN|III |GANAN|PERD|CREDITOS|MARGEN|CUENTAS|SALDOS|BOLETIN|INTENDENCIA|DIVISION|ACTIVO|ENTIDAD FUSIONADA|TOTAL (INGRESOS|EGRESOS|ACTIVO|PASIVO|PREVISIONES|CONTINGENTES))"
RX_AGREGADO <- "^(SUB ?TOTAL|SISTEMA|TOTAL SISTEMA|TOTAL BANCO|TOTAL EMPRESAS FINANCIERAS|TOTAL FINANCIERAS|TOTAL GENERAL|CON PARTICIPACION (DE|DEL) FONDO GANADERO|SUCURSALES DIRECTAS|PROPIEDAD (EXTRANJ|LOCAL)|PARTICIPACION ESTATAL)"
RX_ENTIDAD <- "(^BANCO\\b|\\bBANCO$|\\bBANK\\b|CITIBANK|\\bFINANCIERA\\b|AGROFINANCIERA|FINANCIER RIO|\\bFINANZAS\\b|\\bCAMBIOS\\b|CAMBIARIA|EXCHANGE|INTERFISA|BANCOP|FOREX|INTERBANCO|TRANFERS|FINEXPAR|FONDO GANADERO|^SOLAR\\b)"
alias <- if (file.exists("alias_entidades.csv")) fread("alias_entidades.csv", encoding = "UTF-8") else data.table(clave_publicada = character(), entidad_clave = character())

clasificar <- function(lab) {
  k <- norm(lab)
  fcase(is.na(k) | k == "", NA_character_,
        k %in% EXCLUIR | grepl(RX_EXCLUIR, k) | nchar(k) > 70, NA_character_,
        grepl(RX_AGREGADO, k), "agregado",
        grepl(RX_ENTIDAD, k) | k %in% alias$clave_publicada, "entidad",
        default = NA_character_)
}

# --- entidad en la FILA (último texto a la izquierda) --------------------------------------------------------
N[, lab_fila := trimws(sub(".*\\| ", "", etiqueta_fila))]
N[, clase_fila := clasificar(lab_fila)]
# --- entidad en la COLUMNA (algún componente del encabezado) ---------------------------------------------------
comp_col <- function(enc) {
  if (is.na(enc)) return(NA_character_)
  p <- trimws(strsplit(enc, " > ", fixed = TRUE)[[1]]); c <- clasificar(p)
  i <- which(!is.na(c)); if (length(i)) p[max(i)] else NA_character_
}
encs <- unique(N$encabezado_columna)
mapa_col <- data.table(encabezado_columna = encs, lab_col = vapply(encs, comp_col, ""))
N <- merge(N, mapa_col, by = "encabezado_columna", all.x = TRUE, sort = FALSE)
N[, clase_col := clasificar(lab_col)]
N[, eje := fcase(!is.na(clase_fila), "fila", !is.na(clase_col), "columna", default = NA_character_)]
N[, entidad_publicada := fifelse(eje == "fila", lab_fila, lab_col)]
N[, es_agregado := fifelse(eje == "fila", clase_fila, clase_col) == "agregado"]
N[es_agregado & grepl("^SUB ?TOTAL", norm(entidad_publicada)) & !is.na(seccion),
  entidad_publicada := paste(entidad_publicada, seccion, sep = " | ")]

N[, asignacion := fcase(eje == "fila", "etiqueta_fila", eje == "columna", "encabezado_columna", default = NA_character_)]
# Herencia por columna: en hojas con varios bloques verticales, el nombre de la entidad se publica una sola
# vez arriba y los bloques de abajo traen su propio encabezado. Si en la misma hoja y columna todas las celdas
# asignadas por encabezado apuntan a UNA sola entidad (y una sola moneda), las celdas sin asignar de esa
# columna la heredan (asignacion = "heredada_columna"). Si hay más de una, no se asigna nada.
col_ent <- N[eje == "columna", .(n_ent = uniqueN(entidad_publicada), ent = entidad_publicada[1], agr = es_agregado[1]),
             by = .(archivo, hoja, columna)][n_ent == 1]
N <- merge(N, col_ent[, .(archivo, hoja, columna, ent_col = ent, agr_col = agr)], by = c("archivo", "hoja", "columna"), all.x = TRUE, sort = FALSE)
N[is.na(eje) & !is.na(ent_col), `:=`(eje = "columna", entidad_publicada = ent_col, es_agregado = agr_col, asignacion = "heredada_columna")]
N[, c("ent_col", "agr_col") := NULL]

P <- N[!is.na(eje)]
moneda_rx <- "^(MN|ME|TOTAL|M/N|M/E|M\\.N\\.|M\\.E\\.|MON\\. LOCAL|MON\\. EXTRANJ\\.?)$"
P[, partes_enc := strsplit(fifelse(is.na(encabezado_columna), "", encabezado_columna), " > ", fixed = TRUE)]
P[eje == "columna", moneda := vapply(partes_enc, function(p) { m <- p[grepl(moneda_rx, trimws(p))]; if (length(m)) trimws(m[length(m)]) else NA_character_ }, "")]
P[eje == "columna", encabezado_resto := vapply(seq_len(.N), function(i) {
  p <- trimws(partes_enc[[i]]); p <- p[!(p %in% c(entidad_publicada[i], moneda[i]))]
  if (length(p)) paste(p, collapse = " > ") else NA_character_ }, "")]
col_mon <- P[asignacion == "encabezado_columna" & !is.na(moneda), .(n = uniqueN(moneda), mon = moneda[1]), by = .(archivo, hoja, columna)][n == 1]
P <- merge(P, col_mon[, .(archivo, hoja, columna, mon_col = mon)], by = c("archivo", "hoja", "columna"), all.x = TRUE, sort = FALSE)
P[asignacion == "heredada_columna" & is.na(moneda), moneda := mon_col][, mon_col := NULL]
P[, concepto := fifelse(eje == "fila", encabezado_columna, etiqueta_fila)]
P[, partes_enc := NULL]

# --- período del encabezado ------------------------------------------------------------------------------------
MES <- c(ENE = 1, FEB = 2, MAR = 3, ABR = 4, MAY = 5, JUN = 6, JUL = 7, AGO = 8, SET = 9, SEP = 9, OCT = 10, NOV = 11, DIC = 12)
per_de <- function(enc) {
  if (is.na(enc)) return(NA_character_)
  e <- toupper(iconv(gsub("\\s+", " ", enc), "UTF-8", "ASCII//TRANSLIT"))
  m <- regmatches(e, gregexpr("\\b(ENE|FEB|MAR|ABR|MAY|JUN|JUL|AGO|SET|SEP|OCT|NOV|DIC)[A-Z]*[ -]+(20)?\\d{2}\\b", e))[[1]]
  if (!length(m)) return(NA_character_)
  u <- m[length(m)]; mes <- MES[[substr(u, 1, 3)]]; a <- as.integer(sub(".*?(\\d{2,4})$", "\\1", u)); if (a < 100) a <- 2000 + a
  sprintf("%04d-%02d", a, mes)
}
encs <- unique(P$encabezado_columna)
mapa_per <- data.table(encabezado_columna = encs, periodo = vapply(encs, per_de, ""))
P <- merge(P, mapa_per, by = "encabezado_columna", all.x = TRUE, sort = FALSE)
P[, periodo_publicado := fifelse(is.na(periodo), NA_character_, encabezado_columna)]
P[is.na(periodo), periodo := format(as.IDate(fecha_corte), "%Y-%m")]
P[, unidad_publicada := regmatches(titulo_hoja, regexpr("(?i)\\(?en (millones de (gs|guaran[ií]es)|porcentaje|miles de [a-z]+|veces|cantidad)[^/)]*\\)?", titulo_hoja, perl = TRUE))[1], by = titulo_hoja]

# --- claves de entidad y diccionario ---------------------------------------------------------------------------
P[, entidad_clave := norm(sub(" \\|.*", "", entidad_publicada))]
P[es_agregado & grepl("^SUB ?TOTAL", entidad_clave), entidad_clave := paste0("SUB-TOTAL | ", norm(sub(" \\|.*", "", seccion)))]
P <- merge(P, alias[, .(entidad_clave = clave_publicada, alias_a = entidad_clave)], by = "entidad_clave", all.x = TRUE, sort = FALSE)
P[, metodo_clave := fifelse(is.na(alias_a), "normalizacion_automatica", "alias_revisable")]
P[!is.na(alias_a), entidad_clave := alias_a][, alias_a := NULL]

dic <- P[, .(celdas = .N, meses = uniqueN(periodo), primer_mes = min(periodo), ultimo_mes = max(periodo),
             tipos = paste(sort(unique(tipo)), collapse = ",")), by = .(entidad_publicada = sub(" \\|.*", "", entidad_publicada), entidad_clave, es_agregado, metodo_clave)]
setorder(dic, es_agregado, entidad_clave, entidad_publicada)
fwrite(dic, "extraidos/diccionario_entidades.csv")

out <- P[, .(fecha_corte, tipo, diseno, version, archivo, sha256, hoja, fila, columna, titulo_hoja, eje, asignacion, entidad_publicada,
             entidad_clave, es_agregado, metodo_clave, concepto, encabezado_resto, moneda, seccion, periodo_publicado, periodo,
             unidad_publicada, valor_publicado, valor)]
setorder(out, tipo, fecha_corte, archivo, hoja, fila, columna)
write_parquet(out, "extraidos/panel_entidades.parquet")
ctrl <- merge(N[, .(celdas = .N), by = .(tipo, diseno, hoja)], out[, .(asignadas = .N), by = .(tipo, diseno, hoja)], by = c("tipo", "diseno", "hoja"), all.x = TRUE)
ctrl[is.na(asignadas), asignadas := 0L][, sin_entidad := celdas - asignadas]
fwrite(ctrl[order(tipo, diseno, hoja)], "extraidos/control_panel.csv")
stopifnot(nrow(out) + sum(ctrl$sin_entidad) == nrow(N))
cat("Celdas capa 1:", nrow(N), "| asignadas a entidad o agregado:", nrow(out), sprintf("(%.1f%%)", 100 * nrow(out) / nrow(N)),
    "| entidades distintas (clave):", out[es_agregado == FALSE, uniqueN(entidad_clave)], "\n")
print(out[, .(celdas = .N, entidades = uniqueN(entidad_clave[!es_agregado]), meses = uniqueN(periodo)), by = .(tipo, diseno)])

# --- Tasas de interés promedio por producto (ficha técnica, hoja «Tasas», 2011–2013) --------------------------
# Totales del sistema (no por entidad). Se toma solo la tabla rotulada: encabezado «BANCOS|FINANCIERAS > M/L|M/E >
# Nominal|Efectiva» y producto en la fila. El mes sale del título de la hoja («JUNIO 2012»); los guiones «--» del
# original son texto (sin dato) y quedan en la capa 1. El bloque sin rótulos al pie de la hoja no se interpreta.
MESES_L <- c(ENERO = 1, FEBRERO = 2, MARZO = 3, ABRIL = 4, MAYO = 5, JUNIO = 6, JULIO = 7, AGOSTO = 8, SETIEMBRE = 9,
             SEPTIEMBRE = 9, OCTUBRE = 10, NOVIEMBRE = 11, DICIEMBRE = 12)
Tz <- N[hoja == "Tasas" & grepl("^(BANCOS|FINANCIERAS) > (M/L|M/E) > (Nominal|Efectiva)$", encabezado_columna) & !is.na(etiqueta_fila)]
Tz[, c("sector", "moneda", "tasa") := tstrsplit(encabezado_columna, " > ", fixed = TRUE)]
Tz[, producto_publicado := trimws(sub(" \\|.*", "", etiqueta_fila))]
Tz[, mes_titulo := {
  t <- toupper(stringi::stri_trans_general(titulo_hoja, "Latin-ASCII"))
  m <- regmatches(t, regexpr("(ENERO|FEBRERO|MARZO|ABRIL|MAYO|JUNIO|JULIO|AGOSTO|SETIEMBRE|SEPTIEMBRE|OCTUBRE|NOVIEMBRE|DICIEMBRE) +(DE +)?20\\d{2}", t))
  if (length(m)) sprintf("%s-%02d", sub(".* ", "", m), MESES_L[[sub(" .*", "", m)]]) else NA_character_ }, by = titulo_hoja]
tasas <- Tz[, .(periodo = fifelse(is.na(mes_titulo), format(as.IDate(fecha_corte), "%Y-%m"), mes_titulo),
                periodo_de = fifelse(is.na(mes_titulo), "fecha_corte", "titulo_hoja"), seccion, producto_publicado, sector, moneda, tasa,
                valor_publicado, valor, unidad = "porcentaje anual (según la hoja)", archivo, sha256, fecha_corte, fila, columna)]
setorder(tasas, periodo, sector, moneda, tasa, fila)
stopifnot(tasas[, .N, by = .(periodo, archivo, producto_publicado, sector, moneda, tasa, fila)][N > 1, .N] == 0)
fwrite(tasas, "extraidos/tasas_ficha_tecnica.csv")
cat("Tasas (ficha técnica):", nrow(tasas), "valores |", uniqueN(tasas$periodo), "meses", paste(range(tasas$periodo), collapse = " a "), "|",
    uniqueN(tasas$producto_publicado), "productos\n")
