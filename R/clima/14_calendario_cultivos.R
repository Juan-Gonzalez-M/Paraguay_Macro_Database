# Calendario de cultivos de Paraguay (siembra y cosecha por cultivo y temporada).
#
# No existe un calendario público descargable que cubra Paraguay:
#   - GEOGLAM Crop Monitor for Early Warning (Zenodo 15850408, v1.3) se descargó y NO incluye Paraguay
#     (86 países de alerta temprana; tampoco soja). Verificado el 2026-09-23 y luego eliminado a pedido del
#     usuario (hash y motivo en ..._faseB/eliminados_2026-09-23.csv). Si el zip vuelve a estar, se reverifica.
#   - GEOGLAM Crop Monitor for AMIS (que sí cubriría soja) figura como "Coming Soon".
#   - FAO GIEWS solo da el estado de la campaña en curso, no un calendario.
# Por eso el calendario es una tabla CURADA a mano (R/clima/insumos/calendario_cultivos_fuentes.csv) con
# la CITA TEXTUAL de un informe USDA FAS GAIN para cada ventana. Este script verifica que cada cita
# aparezca en la página indicada del PDF (texto normalizado) y falla si alguna no se encuentra.
# Los meses son los que dice el texto; "parte" (inicios/mediados/fines) conserva la precisión publicada.
# Salida: data/clima/calendario_cultivos.csv (tabla de referencia, no formato largo)

source("R/clima/00_utils.R")

cal <- fread("R/clima/insumos/calendario_cultivos_fuentes.csv", encoding = "UTF-8")
ruta_doc <- function(d) if (startsWith(d, "FASEA:")) file.path(ACQ_BASE, sub("^FASEA:", "", d)) else file.path(ACQ_NUEVA, d)

# PDFs de la Fase B (se descargan si faltan)
GAIN <- "https://apps.fas.usda.gov/newgainapi/api/Report/DownloadReportByFileName?fileName="
for (n in c("Oilseeds_and_Products_Annual_Buenos_Aires_Paraguay_PA2025-0001.pdf",
            "Oilseeds_and_Products_Annual_Buenos_Aires_Paraguay_PA2026-0002.pdf",
            "Grain_and_Feed_Annual_Buenos_Aires_Paraguay_PA2026-0001.pdf")) {
  descargar(paste0(GAIN, gsub("_", "+", n, fixed = TRUE)), file.path("usda/gain", n), pausa = 2)
}

norm <- function(x) {
  x <- gsub("[“”‘’\"']", "", x)
  x <- gsub("[–—]", "-", x)
  x <- gsub("-\\s*\\n\\s*", "-", x)
  tolower(gsub("\\s+", " ", x))
}
texto_pagina <- function(f, p) paste(system2("pdftotext", c("-f", p, "-l", p, shQuote(f), "-"), stdout = TRUE), collapse = " ")
if (!nzchar(Sys.which("pdftotext"))) stop("Se necesita pdftotext (poppler) para verificar las citas.")

cal[, doc_ruta := vapply(documento, ruta_doc, "")]
if (any(!file.exists(cal$doc_ruta))) stop("Documentos faltantes: ", paste(unique(cal$doc_ruta[!file.exists(cal$doc_ruta)]), collapse = ", "))
cal[, cita_encontrada := mapply(function(f, p, q) grepl(norm(q), norm(texto_pagina(f, p)), fixed = TRUE), doc_ruta, pagina, cita_textual)]
if (!all(cal$cita_encontrada)) { print(cal[!(cita_encontrada), .(cultivo, temporada, etapa, documento, pagina)]); stop("Citas no encontradas en la página indicada") }
cal[, sha256_documento := substr(sha256_archivo(doc_ruta), 1, 16)]
log_msg("Calendario:", nrow(cal), "ventanas; todas las citas verificadas en su página")

# GEOGLAM: verificar la ausencia de Paraguay (evidencia de por qué no se usa)
zip_g <- file.path(ACQ_NUEVA, "geoglam/GEOGLAM_CM4EW_Calendars_V1.3.zip")
if (file.exists(zip_g)) {
  dir_x <- file.path(ACQ_NUEVA, "geoglam/extraido")
  if (!dir.exists(dir_x)) unzip(zip_g, exdir = dir_x)
  dbf <- list.files(dir_x, pattern = "\\.dbf$", recursive = TRUE, full.names = TRUE)
  paises <- unique(sf::st_drop_geometry(sf::st_read(sub("\\.dbf$", ".shp", dbf), quiet = TRUE))$country)
  log_msg("GEOGLAM CM4EW v1.3:", length(paises), "países;", if ("Paraguay" %in% paises) "INCLUYE Paraguay: revisar" else "no incluye Paraguay (no se usa)")
}

out <- cal[, .(cultivo, temporada, etapa, mes_inicio, parte_inicio, mes_fin, parte_fin,
               cruza_anio = mes_fin < mes_inicio, fuente = "USDA FAS GAIN (Buenos Aires, informes de Paraguay)",
               documento = doc_ruta, pagina, sha256_documento, cita_textual, nota)]
fwrite(out, file.path(OUT_DIR, "calendario_cultivos.csv"))
log_msg("escrito", file.path(OUT_DIR, "calendario_cultivos.csv"), ":", nrow(out), "filas")
