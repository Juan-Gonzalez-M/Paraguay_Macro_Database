# Evidencia para la revisión humana del calendario del CPM (no decide nada ni modifica el calendario).
# Uso (desde esta carpeta): Rscript evidencia_revision_cpm.R      (requiere pdftotext, de poppler)
# Entrada: extraidos/cpm_calendario_decisiones.csv (salida de extraer_cpm.R) y los PDF de raw/archivo/cpm/.
# Salida:  extraidos/cpm_filas_a_revisar.csv — las filas con marca en «revisar», con un extracto más largo del
#   texto del comunicado (texto completo desde el encabezado «Asunción, …», espacios normalizados) para
#   decidir sin abrir el PDF. El extracto es texto de pdftotext: puede traer cortes de palabra del original.
suppressPackageStartupMessages(library(data.table))
cal <- fread("extraidos/cpm_calendario_decisiones.csv", encoding = "UTF-8")
r <- cal[revisar != ""]
texto <- function(path) {
  t <- system2("pdftotext", c(shQuote(path), "-"), stdout = TRUE, stderr = FALSE)
  t <- gsub("\\s+", " ", paste(t, collapse = " "))
  i <- regexpr("Asunci[oó]n,", t)
  substr(t, if (i > 0) i else 1, nchar(t))
}
r[, extracto := vapply(path, texto, "")]
out <- r[, .(fecha_comunicado, fecha_publicada, instrumento, accion, tasa_anterior, tasa_nueva, cambio_pb, votacion, revisar,
             frase_decision, extracto, nombre_publicado, path, sha256, url_bcp, wayback_timestamp)]
fwrite(out, "extraidos/cpm_filas_a_revisar.csv")
cat("Filas con marca:", nrow(out), "de", nrow(cal), "\n")
print(out[, .(fecha_comunicado, instrumento, accion, tasa_nueva, revisar)])
