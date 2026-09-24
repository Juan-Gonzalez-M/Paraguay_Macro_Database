# IRI (Columbia): vintages mensuales de probabilidades ENSO (La Niña / Neutral / El Niño) por temporada.
#
# Dos formatos en el sitio:
#   2002-01 … 2013-12: .../enso/archive/YYYYMM/figure3.html  ("Made in <Mes AAAA>", temporadas con año)
#   2014-01 … hoy:     .../enso/YYYY-<month>-quick-look/      ("Published: <fecha>", temporadas sin año)
# Descarga lenta (1 pedido cada 2 s), reanudable, a <ACQ_NUEVA>/iri/. Meses sin página o sin tabla
# quedan registrados en data/clima/iri_control.csv (no se imputan).
#
# Salida: data/clima/enso_iri_pronosticos.csv
#   OJO: dos PRODUCTOS distintos según la página: iri_probabilistico (2002–2013, archivo figure3) y
#   cpc_iri_oficial (2014–, tabla oficial CPC/IRI de las páginas quick-look). No se empalman.
#   fecha = mes de emisión (vintage); variable = enso_prob_<producto>_<fase>_hNN, con NN = meses entre el mes
#   de emisión y el mes CENTRAL de la temporada objetivo; periodo_publicado = temporada objetivo
#   ("DJF 2025"); flag = fecha de publicación cuando la página la informa.

source("R/clima/00_utils.R")

BASE <- "https://iri.columbia.edu/our-expertise/climate/forecasts/enso"
DIR_IRI <- file.path(ACQ_NUEVA, "iri"); dir.create(DIR_IRI, showWarnings = FALSE, recursive = TRUE)
CENTRO <- c(DJF = 1, JFM = 2, FMA = 3, MAM = 4, AMJ = 5, MJJ = 6, JJA = 7, JAS = 8, ASO = 9, SON = 10, OND = 11, NDJ = 12)
MESES_EN <- tolower(month.name)

hoy <- Sys.Date()
emisiones <- seq(as.Date("2002-01-01"), as.Date(format(hoy, "%Y-%m-01")), by = "month")

url_de <- function(m) {
  if (m < as.Date("2014-01-01")) sprintf("%s/archive/%s/figure3.html", BASE, format(m, "%Y%m"))
  else sprintf("%s/%s-%s-quick-look/", BASE, format(m, "%Y"), MESES_EN[month(m)])
}

bajar <- function(m) {
  dest <- file.path(DIR_IRI, paste0(format(m, "%Y%m"), ".html"))
  miss <- paste0(dest, ".404")
  if (file.exists(dest)) return("ok")
  if (file.exists(miss)) return("no_existe")
  u <- url_de(m)
  h <- curl::new_handle(useragent = USER_AGENT, followlocation = TRUE, timeout = 60)
  r <- tryCatch(curl::curl_fetch_memory(u, handle = h), error = function(e) e)
  Sys.sleep(2)
  if (inherits(r, "error")) { log_msg("error", u, conditionMessage(r)); return("error") }
  if (r$status_code == 404) { writeLines(u, miss); return("no_existe") }
  if (r$status_code != 200) { log_msg("HTTP", r$status_code, u); return(paste0("http_", r$status_code)) }
  writeBin(r$content, dest)
  registrar_descarga(file.path("iri", basename(dest)), u, "downloaded")
  "ok"
}

texto_plano <- function(f) {
  t <- rawToChar(readBin(f, "raw", file.size(f)))
  Encoding(t) <- "UTF-8"
  t <- gsub("(?s)<script.*?</script>|<style.*?</style>", " ", t, perl = TRUE)
  t <- gsub("<[^>]+>", " ", t)
  t <- gsub("&nbsp;|&#160;", " ", t)
  gsub("\\s+", " ", t)
}

FASES <- c("la_nina", "neutral", "el_nino")
PAT_ENC <- "Season La Ni(ñ|n|&ntilde;)a Neutral El Ni(ñ|n|&ntilde;)o"
PAT_FILA <- "(DJF|JFM|FMA|MAM|AMJ|MJJ|JJA|JAS|ASO|SON|OND|NDJ)(?: (\\d{4}))? (~?\\d{1,3}) ?%? (~?\\d{1,3}) ?%? (~?\\d{1,3}) ?%?"

# Producto de cada tabla según el texto que la precede:
#   emisión < 2014 (figure3.html)     → iri_probabilistico (por tipo de página)
#   "Consensus"/"Official"/"CPC/IRI"  → cpc_iri_oficial (pronóstico oficial CPC/IRI, con juicio humano)
#   "IRI Probabilistic"/"Model-Based" → iri_probabilistico (pronóstico probabilístico del IRI)
#   "Climatological"                  → se descarta (probabilidades climatológicas, no pronóstico)
#   sin rótulo y emisión ≥ 2014       → cpc_iri_oficial, marcado "producto_inferido_por_ubicacion"
producto_de <- function(ctx, m) {
  if (grepl("Climatological", ctx)) return(c("climatologia", NA))
  # 2002–2013: la página archive/YYYYMM/figure3.html ES el "Prob. ENSO Forecast" del IRI (así la rotula el
  # índice del archivo); el texto previo a veces solo contiene el menú de navegación.
  if (m < as.Date("2014-01-01")) {
    return(c("iri_probabilistico", if (grepl("IRI Probabilistic", substr(ctx, nchar(ctx) - 90, nchar(ctx)))) NA else "producto_por_tipo_de_pagina"))
  }
  if (grepl("Consensus|Official|CPC/IRI", ctx)) return(c("cpc_iri_oficial", NA))
  if (grepl("IRI Probabilistic|Model-Based", ctx)) return(c("iri_probabilistico", NA))
  c("cpc_iri_oficial", "producto_inferido_por_ubicacion")
}

parsear <- function(m) {
  f <- file.path(DIR_IRI, paste0(format(m, "%Y%m"), ".html"))
  t <- texto_plano(f)
  pub <- NA_character_
  pm <- regmatches(t, regexpr("Published: [A-Z][a-z]+ \\d{1,2}, \\d{4}", t))
  if (length(pm)) pub <- format(as.Date(sub("Published: ", "", pm), format = "%B %d, %Y"))
  pos <- gregexpr(PAT_ENC, t, perl = TRUE)[[1]]
  if (pos[1] < 0) return(list(filas = NULL, estado = "sin_tabla", pub = pub))
  tablas <- list(); descartadas <- 0L
  for (p0 in pos) {
    prod <- producto_de(substr(t, max(1, p0 - 250), p0), m)
    if (prod[1] == "climatologia") { descartadas <- descartadas + 1L; next }
    cuerpo <- sub(PAT_ENC, "", substr(t, p0, p0 + 700), perl = TRUE)
    # Filas consecutivas desde el inicio del cuerpo (la tabla termina en la primera no-fila)
    filas <- character()
    repeat {
      mt <- regexpr(paste0("^\\s*", PAT_FILA), cuerpo, perl = TRUE)
      if (mt < 0) break
      filas <- c(filas, trimws(regmatches(cuerpo, mt))); cuerpo <- substr(cuerpo, attr(mt, "match.length") + 1, nchar(cuerpo))
    }
    if (!length(filas)) next
    v <- regmatches(filas, regexec(PAT_FILA, filas, perl = TRUE))
    x <- rbindlist(lapply(v, function(z) data.table(temp = z[2], anio_pub = suppressWarnings(as.integer(z[3])),
                                                    txt_la_nina = z[4], txt_neutral = z[5], txt_el_nino = z[6])))
    cm <- CENTRO[x$temp]
    a <- year(m) + if (cm[1] < month(m) - 6) 1L else if (cm[1] > month(m) + 6) -1L else 0L
    anio <- integer(nrow(x))
    for (k in seq_len(nrow(x))) { if (k > 1 && cm[k] < cm[k - 1]) a <- a + 1L; anio[k] <- a }
    x[, anio_centro := anio]
    # IRI rotula NDJ con el año de enero (NDJ 2013 = nov-2012..ene-2013); el mes central es diciembre.
    x[, consistente := is.na(anio_pub) | anio_pub == anio_centro | (temp == "NDJ" & anio_pub == anio_centro + 1L)]
    x[, centro := as.IDate(sprintf("%d-%02d-01", anio_centro, CENTRO[temp]))]
    x[, h := (year(centro) - year(m)) * 12L + (month(centro) - month(m))]
    x[, periodo := fifelse(is.na(anio_pub), paste(temp, "(sin año publicado)"), paste(temp, anio_pub))]
    x[, `:=`(producto = prod[1], flag_prod = prod[2])]
    tablas[[length(tablas) + 1]] <- x
  }
  if (!length(tablas)) return(list(filas = NULL, estado = if (descartadas) "solo_climatologia" else "tabla_vacia", pub = pub))
  x <- rbindlist(tablas)
  est <- c(if (any(!x$consistente)) "etiqueta_anio_publicada_difiere",
           if (anyDuplicated(x[, .(producto, h)])) "horizonte_duplicado")
  list(filas = x, estado = if (length(est)) paste(est, collapse = ";") else "ok", pub = pub)
}

log_msg("IRI:", length(emisiones), "meses de emisión posibles (", format(min(emisiones)), "→", format(max(emisiones)), ")")
est_desc <- vapply(emisiones, bajar, character(1))
res <- list(); ctrl <- list()
for (k in seq_along(emisiones)) {
  m <- emisiones[k]
  if (est_desc[k] != "ok") { ctrl[[k]] <- data.table(emision = m, url = url_de(m), descarga = est_desc[k], tabla = NA, filas = 0L); next }
  r <- parsear(m)
  ctrl[[k]] <- data.table(emision = m, url = url_de(m), descarga = "ok", tabla = r$estado, filas = if (is.null(r$filas)) 0L else nrow(r$filas))
  if (is.null(r$filas)) next
  x <- melt(r$filas, id.vars = c("periodo", "h", "producto", "flag_prod", "consistente"),
            measure.vars = paste0("txt_", FASES), variable.name = "fase", value.name = "txt")
  x[, fase := sub("^txt_", "", fase)]
  x[, valor := as.numeric(sub("~", "", txt))]
  x[, flag := paste0(if (!is.na(r$pub)) paste0("publicado:", r$pub) else "fecha_publicacion_no_informada",
                     fifelse(grepl("~", txt), paste0("; valor_publicado:", txt, "%"), ""),
                     fifelse(is.na(flag_prod), "", paste0("; ", flag_prod)),
                     fifelse(consistente, "", "; etiqueta_anio_publicada_difiere_se_usa_secuencia"))]
  res[[k]] <- x[, .(fecha = as.IDate(m), id_geo = "GLOBAL", nivel_geo = "global",
                    variable = sprintf("enso_prob_%s_%s_h%02d", producto, fase, h), valor, unidad = "porcentaje",
                    fuente = fifelse(producto == "cpc_iri_oficial", "CPC/IRI, pronóstico oficial ENSO (vía IRI Columbia)",
                                     "IRI Columbia, pronóstico probabilístico ENSO (Niño 3.4)"),
                    frecuencia = "vintage_mensual", periodo_publicado = periodo, flag,
                    archivo_origen = file.path(DIR_IRI, paste0(format(m, "%Y%m"), ".html")))]
}
ctrl <- rbindlist(ctrl)
fwrite(ctrl, file.path(OUT_DIR, "iri_control.csv"))
print(ctrl[, .N, by = .(descarga, tabla)])
out <- rbindlist(res)
escribir_largo(out, "enso_iri_pronosticos", claves = c("fecha", "variable"), insumos = paste0(DIR_IRI, "/*.html"))
