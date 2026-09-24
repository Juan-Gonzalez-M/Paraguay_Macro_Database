# Inventario de los boletines estadístico-financieros de la SIB 2011–2015 (formato clásico, BCP).
# Uso (desde esta carpeta): Rscript inventario.R
# Recorre raw/ y escribe inventory.csv con: ruta, origen, URL, fecha de obtención, bytes, SHA-256, tipo de
# boletín, diseño (clásico / nuevo / ficha), fecha de corte LEÍDA DENTRO del archivo y marca de versión.
# No modifica ningún archivo. Si inventory.csv ya existe, verifica que los SHA-256 no hayan cambiado.

suppressPackageStartupMessages({library(readxl); library(data.table)})
ORIGEN <- list(
  manual_usuario = list(url = "https://www.bcp.gov.py/en/formato-clasico", obtenido = "2026-09-24",
                        nota = "descarga manual del usuario desde el navegador (el sitio bloquea clientes automáticos)"),
  internet_archive = list(url = NA_character_, obtenido = "2026-09-24",
                          nota = "copia del sitio anterior del BCP (/userfiles/files/) en el Internet Archive, julio de 2017; el enlace actual entrega el mes anterior"))
WAYBACK <- c("1_BOLB_092015.xls" = "https://web.archive.org/web/20170711094118id_/https://www.bcp.gov.py/userfiles/files/1_BOLB_092015.xls",
             "3_BOLCC_032014.xls" = "https://web.archive.org/web/20170711080104id_/https://www.bcp.gov.py/userfiles/files/3_BOLCC_032014.xls")

f <- list.files("raw", recursive = TRUE, full.names = TRUE, pattern = "\\.xlsx?$")
tipo <- function(a) fcase(grepl("BOLB|^BANCOS|^Bancos_prop", a), "bancos", grepl("BOLF|^FINANCIERAS", a), "financieras",
                          grepl("BOLCC|CASAS|^Cambios_prop", a), "casas_cambio",
                          grepl("Ficha|Otros_Datos", a, ignore.case = TRUE), "ficha_tecnica", default = NA_character_)
# Fecha de corte: la fecha más frecuente en los encabezados de las primeras hojas (en la ficha técnica,
# que compara meses, la más reciente). Acepta dd-mm-aaaa, dd/mm/aaaa y números de serie de Excel.
fecha_corte <- function(x, t) {
  out <- as.IDate(character())
  for (s in head(excel_sheets(x), 6)) {
    r <- tryCatch(suppressMessages(read_excel(x, sheet = s, col_names = FALSE, n_max = 15, col_types = "text", .name_repair = "minimal")),
                  error = function(e) NULL)
    if (is.null(r)) next
    v <- unlist(r, use.names = FALSE); v <- v[!is.na(v)]
    m <- regmatches(v, regexpr("\\b\\d{2}[-/]\\d{2}[-/]20\\d{2}\\b", v))
    out <- c(out, as.IDate(gsub("/", "-", m), format = "%d-%m-%Y"))
    n <- suppressWarnings(as.numeric(v)); n <- n[!is.na(n) & n > 40000 & n < 42500 & n == round(n)]
    out <- c(out, as.IDate(n, origin = "1899-12-30"))
  }
  if (!length(out)) return(as.IDate(NA))
  if (t == "ficha_tecnica") return(max(out))
  tab <- sort(table(out), decreasing = TRUE); as.IDate(names(tab)[1])
}
inv <- rbindlist(lapply(f, function(x) {
  a <- basename(x); o <- basename(dirname(x)); t <- tipo(a); h <- excel_sheets(x)
  data.table(path = x, archivo = a, origen = o,
             url = if (o == "internet_archive") WAYBACK[[a]] else ORIGEN[[o]]$url,
             obtenido = ORIGEN[[o]]$obtenido, nota_origen = ORIGEN[[o]]$nota,
             bytes = file.size(x), sha256 = digest::digest(file = x, algo = "sha256"),
             tipo = t, hojas = length(h),
             diseno = fcase(t == "ficha_tecnica", "ficha",
                            t == "casas_cambio" & "CC" %in% h, "nuevo",
                            t %in% c("bancos", "financieras") & length(h) <= 21, "nuevo", default = "clasico"),
             fecha_corte = fecha_corte(x, t))
}))
# Único archivo sin fecha legible en los encabezados: se toma del nombre y se marca.
inv[, fecha_por_nombre := FALSE]
inv[archivo == "BOLF 062012.xls" & is.na(fecha_corte), `:=`(fecha_corte = as.IDate("2012-06-30"), fecha_por_nombre = TRUE)]
stopifnot(!anyNA(inv$tipo), !anyNA(inv$fecha_corte))
inv[, mes := format(fecha_corte, "%Y-%m")]
# Más de un archivo para el mismo tipo y mes: se conservan TODOS (no se elige versión sin evidencia).
inv[, n_versiones_mes := .N, by = .(tipo, mes)]
inv[, version := fifelse(n_versiones_mes > 1, paste0("version_", diseno), "unica")]
setorder(inv, tipo, mes, diseno, archivo)

if (file.exists("inventory.csv")) {
  prev <- fread("inventory.csv")
  cmp <- merge(prev[, .(path, sha_prev = sha256)], inv[, .(path, sha256)], by = "path", all = TRUE)
  if (cmp[is.na(sha_prev) | is.na(sha256) | sha_prev != sha256, .N]) { print(cmp[is.na(sha_prev) | is.na(sha256) | sha_prev != sha256]); stop("El contenido de raw/ cambió respecto del inventario.") }
  cat("Inventario verificado: ", nrow(inv), " archivos sin cambios.\n", sep = "")
} else fwrite(inv, "inventory.csv")

meses <- format(seq(as.IDate("2011-01-01"), as.IDate("2015-12-01"), by = "month"), "%Y-%m")
for (t in c("bancos", "financieras", "casas_cambio", "ficha_tecnica"))
  cat(sprintf("%-14s %2d/60 meses; faltan: %s\n", t, sum(meses %in% inv[tipo == t, mes]), paste(setdiff(meses, inv[tipo == t, mes]), collapse = " ")))
print(inv[n_versiones_mes > 1, .(tipo, mes, archivo, diseno)])
