# MAG–DCEA: superficie, producción y rendimiento por cultivo, departamento y campaña agrícola.
#
# Insumos (Fase A, solo lectura), TODOS se procesan y se conservan con su archivo de origen:
#   A) mag/cultivos_tres_departamentos/1 - SERIEHISTORICA_16_principales.xlsx  (16 cultivos, 2007/08–2024/25)
#   B) mag/arroz_2020_2025/SERIE_HISTORICA_CULTIVOSTEMPORALES.xlsx             (22 cultivos, 2020/21–2024/25)
#   C) mag/sesamo_2018_2024/...SERIEHISTORICA_SESAMO_2018-2024.xlsx            (sésamo, 2017/18–2024/25)
# Los libros se superponen. Cuando dos archivos publican valores distintos para la misma celda
# (cultivo, variable, departamento, campaña), se conservan AMBOS y se marcan con
# flag "conflicto_version" (decisión del usuario, 2026-09-23). No se elige una versión.
#
# Convención temporal (no publicada por MAG): fecha = 1 de julio del primer año de la campaña
# (inicio convencional del año agrícola). periodo_publicado conserva la etiqueta tal cual ("2021/22*").
# Las marcas de la etiqueta (*, **, ***, (*), (**), (1)) se traducen a texto con las notas al pie
# de la MISMA hoja (su significado cambia entre hojas: sequía, helada, exceso de lluvia...).
#
# Los CSV de mag/cultivos_2020_2021/ (campañas 2019/20 y 2020/21, sin rendimiento) NO se incluyen: son
# redundantes con el libro A. Se compararon el 2026-09-23 (agro_mag_control_csv_2020_2021.csv) y luego se
# eliminaron a pedido del usuario (ver eliminados_2026-09-23.csv en la carpeta de la Fase A). Si ya no
# existen, la comparación se omite y se conserva el control previo.
#
# Salida: data/clima/agro_mag_departamental.csv (+ control de celdas en agro_mag_control.csv)

source("R/clima/00_utils.R")
suppressPackageStartupMessages(library(readxl))

F_A <- file.path(ACQ_BASE, "mag/cultivos_tres_departamentos/1 - SERIEHISTORICA_16_principales.xlsx")
F_B <- file.path(ACQ_BASE, "mag/arroz_2020_2025/SERIE_HISTORICA_CULTIVOSTEMPORALES.xlsx")
F_C <- list.files(file.path(ACQ_BASE, "mag/sesamo_2018_2024"), pattern = "SERIEHISTORICA_SESAMO", full.names = TRUE)
stopifnot(file.exists(F_A), file.exists(F_B), length(F_C) == 1)

BLOQUES <- c(SUPERFICIE = "superficie", PRODUCCION = "produccion", RENDIMIENTO = "rendimiento")
UNIDADES <- c(superficie = "ha", produccion = "t", rendimiento = "kg/ha")
PAT_CAMP <- "^\\s*(\\d{4})/(\\d{2})"
PAT_MARCA <- "\\(\\*\\*\\)|\\(\\*\\)|\\(1\\)|\\*\\*\\*|\\*\\*|\\*"

nombre_cultivo <- function(s) {
  x <- tolower(chartr("ÁÉÍÓÚÑ", "AEIOUN", toupper(trimws(s))))
  gsub("[^a-z0-9]+", "_", gsub("'", "", x))
}

notas_de_hoja <- function(col1) {
  n <- trimws(col1[!is.na(col1) & grepl("^\\s*(\\(\\*\\*\\)|\\(\\*\\)|\\(1\\)|\\*)", col1)])
  marca <- regmatches(n, regexpr(paste0("^(", PAT_MARCA, ")"), n))
  texto <- trimws(sub(paste0("^(", PAT_MARCA, ")"), "", n))
  setNames(texto, marca)
}

traducir_marcas <- function(etiqueta, notas) {
  resto <- sub(PAT_CAMP, "", etiqueta)
  toks <- regmatches(resto, gregexpr(PAT_MARCA, resto))[[1]]
  if (!length(toks)) return(NA_character_)
  paste(vapply(toks, function(t) paste0("marca", t, "=", if (!is.na(notas[t])) notas[t] else "SIN_NOTA_EN_HOJA"), ""), collapse = "; ")
}

leer_hoja <- function(f, hoja) {
  m <- as.matrix(read_excel(f, sheet = hoja, col_names = FALSE, .name_repair = "minimal", col_types = "text"))
  col1 <- m[, 1]
  notas <- notas_de_hoja(col1)
  filas_camp <- which(apply(m, 1, function(r) any(grepl(PAT_CAMP, r))))
  out <- list(); ctrl <- list()
  for (i in filas_camp) {
    lab <- toupper(paste(na.omit(m[i - 1, -1]), collapse = " "))
    bloque <- BLOQUES[vapply(names(BLOQUES), function(b) grepl(b, lab), logical(1))]
    if (length(bloque) != 1) stop(basename(f), " [", hoja, "] fila ", i, ": no se identifica el bloque (", lab, ")")
    cols <- which(grepl(PAT_CAMP, m[i, ]))
    j <- i + 1
    while (j <= nrow(m) && !is.na(col1[j]) && trimws(col1[j]) != "") {
      depto <- trimws(col1[j])
      for (k in cols) {
        etiqueta <- trimws(m[i, k]); txt <- trimws(m[j, k])
        v <- suppressWarnings(as.numeric(txt))
        fl <- traducir_marcas(etiqueta, notas)
        extra <- if (is.na(txt)) "celda_vacia" else if (is.na(v) && txt == "-") "ningun_valor(-)" else if (is.na(v)) paste0("texto_no_numerico:", txt) else NA_character_
        a <- as.integer(sub(paste0(PAT_CAMP, ".*"), "\\1", etiqueta))
        out[[length(out) + 1]] <- list(
          fecha = as.IDate(sprintf("%d-07-01", a)), depto = depto,
          variable = paste0(nombre_cultivo(hoja), "_", bloque), valor = v, unidad = UNIDADES[[bloque]],
          periodo_publicado = etiqueta, flag = paste(na.omit(c(fl, extra)), collapse = "; "),
          archivo_origen = f, hoja = hoja, celda = sprintf("R%dC%d", j, k))
      }
      j <- j + 1
      if (toupper(depto) == "TOTAL") break
    }
    if (trimws(col1[j - 1]) != "TOTAL") stop(basename(f), " [", hoja, "] bloque ", bloque, ": no termina en TOTAL")
    ctrl[[length(ctrl) + 1]] <- data.table(archivo = basename(f), hoja, bloque, filas = j - i - 1, campanias = length(cols), celdas = (j - i - 1) * length(cols))
  }
  if (length(filas_camp) != 3) stop(basename(f), " [", hoja, "]: se esperaban 3 bloques y hay ", length(filas_camp))
  list(datos = rbindlist(out), control = rbindlist(ctrl))
}

res <- list(); ctrl <- list()
for (f in c(F_A, F_B, F_C)) for (h in excel_sheets(f)) {
  r <- leer_hoja(f, h); res[[length(res) + 1]] <- r$datos; ctrl[[length(ctrl) + 1]] <- r$control
}
d <- rbindlist(res); ctrl <- rbindlist(ctrl)
d[flag == "", flag := NA_character_]
stopifnot(nrow(d) == sum(ctrl$celdas))
log_msg("MAG: celdas leídas", nrow(d), "=", sum(ctrl$celdas), "celdas del área de datos; no numéricas:", d[is.na(valor), .N])

d[, es_total := toupper(depto) == "TOTAL"]
d[, id_geo := "PY"]
d[!(es_total), id_geo := id_departamento(depto)]
d[, nivel_geo := fifelse(es_total, "nacional", "departamento")]

# Conflictos entre archivos para la misma celda lógica
# (tolerancia relativa 1e-6: las hojas guardan flotantes como 4687.9999999 frente a 4688)
d[, conflicto := {
  v <- valor[!is.na(valor)]
  length(v) > 1 && (max(v) - min(v)) > 1e-6 * max(1, abs(v))
}, by = .(fecha, id_geo, variable)]
d[(conflicto), flag := fifelse(is.na(flag), "conflicto_version", paste0(flag, "; conflicto_version"))]
conf <- unique(d[(conflicto), .(fecha, id_geo, variable, periodo = substr(periodo_publicado, 1, 7))])
log_msg("MAG: celdas lógicas con valores distintos entre archivos:")
print(conf[, .(celdas = .N), by = .(cultivo = sub("_(superficie|produccion|rendimiento)$", "", variable), periodo)])

out <- d[, .(fecha, id_geo, nivel_geo, variable, valor, unidad,
             fuente = "MAG-DCEA Síntesis Estadística", frecuencia = "campania",
             periodo_publicado, flag,
             archivo_origen = paste0(archivo_origen, "#", hoja, "!", celda))]
escribir_largo(out, "agro_mag_departamental", claves = c("archivo_origen"),
               insumos = huella(c(F_A, F_B, F_C)))
fwrite(ctrl, file.path(OUT_DIR, "agro_mag_control.csv"))

# Verificación de los CSV 2020–2021 (excluidos por redundantes) contra el libro A ------------------
# Las columnas "2020" y "2021" de esos CSV corresponden a las campañas 2019/20 y 2020/21.
csvs <- list.files(file.path(ACQ_BASE, "mag/cultivos_2020_2021"), pattern = "\\.csv$", full.names = TRUE)
if (!length(csvs)) {
  log_msg("CSV MAG 2020–2021: eliminados (redundantes); se conserva el control previo agro_mag_control_csv_2020_2021.csv")
  quit(save = "no")
}
alias <- c(ka_a_he_e = "kaa_hee")
filas_csv <- list()
for (f in csvs) {
  l <- iconv(readLines(f, warn = FALSE), "latin1", "UTF-8")
  cultivo <- nombre_cultivo(sub("^\\d+\\.\\s*([^-]+?)\\s*-.*$", "\\1", basename(f)))
  if (cultivo %in% names(alias)) cultivo <- alias[[cultivo]]
  bloque <- NA_character_
  for (s in l) {
    p <- strsplit(s, ";")[[1]]
    if (grepl("SUPERFICIE", s) && !grepl("PRODUCCION", s)) bloque <- "superficie" else if (grepl("PRODUCCI", s)) bloque <- "produccion"
    if (length(p) < 3 || !nzchar(trimws(p[1])) || grepl("DEPARTAMENTO|DPTO|MANDIOCA", p[1])) next
    idg <- tryCatch(id_departamento(p[1]), error = function(e) NA_character_)
    filas_csv[[length(filas_csv) + 1]] <- data.table(archivo = basename(f), depto = p[1], id_geo = idg,
      variable = paste0(cultivo, "_", bloque), fecha = as.IDate(c("2019-07-01", "2020-07-01")),
      v_csv = suppressWarnings(as.numeric(gsub(".", "", p[2:3], fixed = TRUE))))
  }
}
cc <- rbindlist(filas_csv)
ref <- d[archivo_origen == F_A, .(id_geo, variable, fecha, v_ref = valor)]
cc <- merge(cc, ref, by = c("id_geo", "variable", "fecha"), all.x = TRUE)
cc[, estado := fifelse(is.na(id_geo), "fila_no_departamental (titulo)", fifelse(is.na(v_ref) & is.na(v_csv), "ambos_vacios",
                fifelse(abs(fcoalesce(v_ref, 0) - fcoalesce(v_csv, 0)) <= 0.5 + 1e-6 * abs(fcoalesce(v_csv, 0)), "igual", "distinto")))]
log_msg("CSV MAG 2020–2021 (excluidos por redundantes), comparación con el libro A:")
print(cc[, .N, by = estado])
if (cc[estado == "distinto", .N]) print(cc[estado == "distinto"])
fwrite(cc, file.path(OUT_DIR, "agro_mag_control_csv_2020_2021.csv"))
