# Extrae a CSV dos tablas de documentos oficiales descargados (sin modificar los valores publicados).
#   1) Anexo 2 de la Metodología IPC base dic-2017 (BCP): código, descripción, nivel, ponderación.
#   2) Tabla 1 del Reporte técnico de salario mínimo (MTESS, 2026): episodios de ajuste 1989–2025.
# Uso (desde esta carpeta): Rscript extraer_tablas.R
# Salidas: extraidos/ipc_base2017_canasta_ponderaciones.csv, extraidos/salario_minimo_decretos_1989_2025.csv
# Controles: ver mensajes; el script falla si no se cumplen.

suppressPackageStartupMessages(library(data.table))
dir.create("extraidos", showWarnings = FALSE)
txt <- function(f, p1, p2) system2("pdftotext", c("-layout", "-f", p1, "-l", p2, shQuote(f), "-"), stdout = TRUE)
num <- function(x) as.numeric(gsub(",", ".", gsub("\\.", "", x)))

# 1) IPC -------------------------------------------------------------------------------------------
f_ipc <- "raw/bcp_metodologia_ipc_base_dic2017.pdf"
n_pag <- as.integer(sub(".*Pages:\\s+(\\d+).*", "\\1", paste(system2("pdfinfo", shQuote(f_ipc), stdout = TRUE), collapse = " ")))
l <- txt(f_ipc, 75, n_pag)
pat <- "^\\s*(\\d{1,9})\\s{2,}(\\S.*?)\\s{2,}([0-4])\\s+(\\d{1,3},\\d{3})\\s*$"
m <- regmatches(l, regexec(pat, l, perl = TRUE))
ok <- lengths(m) == 5
ipc <- rbindlist(lapply(m[ok], function(v) data.table(codigo = v[2], descripcion = trimws(v[3]), nivel = as.integer(v[4]),
                                                    ponderacion_publicada = v[5], ponderacion = num(v[5]), nota = NA_character_)))
# Filas con la descripción partida en la línea anterior y la siguiente (el código queda solo en su línea)
pat2 <- "^\\s*(\\d{1,9})\\s{5,}([0-4])\\s+(\\d{1,3},\\d{3})\\s*$"
solo_texto <- function(x) grepl("^\\s{10,}[A-ZÁÉÍÓÚÑ(]", x) & !grepl("^\\s*\\d", x)
i2 <- which(grepl(pat2, l, perl = TRUE))
if (length(i2)) {
  partes <- rbindlist(lapply(i2, function(i) {
    v <- regmatches(l[i], regexec(pat2, l[i], perl = TRUE))[[1]]
    arriba <- if (i > 1 && solo_texto(l[i - 1])) trimws(l[i - 1]) else ""
    abajo <- if (i < length(l) && solo_texto(l[i + 1])) trimws(l[i + 1]) else ""
    if (arriba == "" && abajo == "") stop("Fila sin descripción recuperable: ", l[i])
    data.table(codigo = v[2], descripcion = trimws(paste(arriba, abajo)), nivel = as.integer(v[3]),
               ponderacion_publicada = v[4], ponderacion = num(v[4]), nota = "descripcion_armada_de_lineas_vecinas")
  }))
  ipc <- rbind(ipc, partes); ok[i2] <- TRUE
}
ipc <- ipc[order(match(codigo, regmatches(l, regexpr("^\\s*\\d{1,9}", l)) |> trimws()))]
# Líneas del anexo con aspecto de fila (empiezan con código) que no calzaron con el patrón:
cand <- grepl("^\\s*\\d{5,9}\\s{2,}\\S", l) & !ok
if (any(cand)) { print(l[cand]); stop("Filas del Anexo 2 sin interpretar: ", sum(cand)) }
if (anyDuplicated(ipc$codigo)) stop("Códigos duplicados en el Anexo 2")
# Códigos: división (1 o 2 dígitos: 1–12) + grupo (2) + subgrupo (2) + artículo (3); 8 o 9 dígitos.
ipc[, n := nchar(codigo)]
ipc[, padre := fcase(nivel == 1, "0",
                     nivel == 2, paste0(substr(codigo, 1, n - 7), strrep("0", 7)),
                     nivel == 3, paste0(substr(codigo, 1, n - 5), strrep("0", 5)),
                     nivel == 4, paste0(substr(codigo, 1, n - 3), "000"),
                     default = NA_character_)][, n := NULL]
suma_hijos <- ipc[nivel >= 1, .(suma_hijos = sum(ponderacion), n_hijos = .N), by = padre]
chk <- merge(ipc[, .(codigo, nivel, ponderacion)], suma_hijos, by.x = "codigo", by.y = "padre")
chk[, dif := round(suma_hijos - ponderacion, 3)]
cat(sprintf("IPC Anexo 2: %d filas (niveles: %s); artículos (nivel 4): %d; suma artículos = %.3f\n",
            nrow(ipc), paste(names(table(ipc$nivel)), table(ipc$nivel), sep = "=", collapse = " "),
            ipc[nivel == 4, .N], ipc[nivel == 4, sum(ponderacion)]))
cat("Máxima diferencia |suma de hijos − padre|:", max(abs(chk$dif)), "(redondeo a 3 decimales)\n")
if (ipc[nivel == 4, .N] != 465) stop("Se esperaban 465 artículos (Metodología, cap. 5)")
if (max(abs(chk$dif)) > 0.01) { print(chk[abs(dif) > 0.01]); stop("La jerarquía no suma dentro de la tolerancia") }
ipc[, `:=`(fuente = "BCP, Metodología IPC base dic-2017, Anexo 2", archivo_origen = f_ipc)]
fwrite(ipc, "extraidos/ipc_base2017_canasta_ponderaciones.csv")

# 2) Salario mínimo ------------------------------------------------------------------------------------
f_sm <- "raw/mtess_reporte_tecnico_salario_minimo_2026.pdf"
l <- txt(f_sm, 1, 8)
i0 <- grep("Tabla 1\\. Episodios de ajuste", l); i1 <- grep("Fuente: Elaboración propia según Gaceta Oficial", l)
stopifnot(length(i0) == 1, length(i1) >= 1)
b <- l[(i0 + 1):(i1[i1 > i0][1] - 1)]
pat <- "^\\s*(\\d{1,2})\\s+(\\d{1,2}\\.\\d{3}|\\d{3,})?\\s*(\\d{1,2}/\\d{1,2}/\\d{4})\\s+(\\d+(?:,\\d+)?)\\s+(\\d{1,2}/\\d{1,2}/\\d{4}|-)\\s*$"
m <- regmatches(b, regexec(pat, b, perl = TRUE)); ok <- lengths(m) == 6
sm <- rbindlist(lapply(m[ok], function(v) data.table(episodio = as.integer(v[2]), decreto_numero = v[3], fecha_decreto = v[4],
                                                   porcentaje_publicado = v[5], vigencia_publicada = v[6])))
sm[decreto_numero == "", decreto_numero := NA]
sm[, `:=`(fecha_decreto_iso = as.IDate(fecha_decreto, format = "%d/%m/%Y"),
          porcentaje_ajuste = num(porcentaje_publicado),
          vigencia_iso = as.IDate(fifelse(vigencia_publicada == "-", NA_character_, vigencia_publicada), format = "%d/%m/%Y"))]
cat("MTESS Tabla 1:", nrow(sm), "episodios,", format(min(sm$fecha_decreto_iso)), "→", format(max(sm$fecha_decreto_iso)), "\n")
if (nrow(sm) != 33 || !identical(sm$episodio, 0:32)) stop("Se esperaban los episodios 0..32")
if (anyNA(sm$fecha_decreto_iso)) stop("Fechas de decreto no interpretables")
sm[, nota := fifelse(vigencia_publicada == "-", "sin_ajuste (porcentaje 0; vigencia '-')", NA_character_)]
sm[, `:=`(fuente = "MTESS, Reporte técnico ingresos laborales y salario mínimo (2026), Tabla 1; según Gaceta Oficial", archivo_origen = f_sm)]
fwrite(sm, "extraidos/salario_minimo_decretos_1989_2025.csv")
cat("Escritos: extraidos/ipc_base2017_canasta_ponderaciones.csv y extraidos/salario_minimo_decretos_1989_2025.csv\n")
