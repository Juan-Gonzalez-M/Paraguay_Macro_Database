# Niveles hidrométricos diarios del río Paraguay (DMH–DINAC).
#
# Fuente: https://meteorologia.gov.py/nivel-rio/vermas_convencional.php?code=<código>&page=<n>
# El sitio solo ofrece páginas de 15 registros (el filtro por fechas está deshabilitado en el HTML),
# ordenadas de la más reciente a la más antigua. Se descargan TODAS las páginas a ritmo lento
# (1 pedido cada 2 s) y se guardan comprimidas como evidencia en
#   <ACQ_NUEVA>/dmh_rios/<snapshot>/<código>/page_NNNNN.html.gz
# La descarga es reanudable: las páginas ya guardadas no se vuelven a pedir.
#
# Uso:  Rscript R/clima/05_rios_dmh.R            # descargar (si falta) + procesar
#       Rscript R/clima/05_rios_dmh.R descargar
#       Rscript R/clima/05_rios_dmh.R procesar
# Variable de entorno opcional DMH_SNAPSHOT=AAAA-MM-DD para fijar la instantánea (por defecto,
# la última existente o la fecha de hoy).
#
# Salidas: data/clima/rios_dmh_diario.csv, data/clima/rios_dmh_mensual.csv

source("R/clima/00_utils.R")

ESTACIONES <- data.table(
  code = c("2000086218", "2000086255", "2000086134"),
  estacion = c("Asunción", "Pilar", "Concepción"),
  rio = "Paraguay"
)
BASE_URL <- "https://meteorologia.gov.py/nivel-rio/vermas_convencional.php"
PAUSA_SEG <- 2

dir_rios <- file.path(ACQ_NUEVA, "dmh_rios")
snap <- Sys.getenv("DMH_SNAPSHOT")
if (snap == "") {
  prev <- sort(list.dirs(dir_rios, recursive = FALSE, full.names = FALSE))
  snap <- if (length(prev)) tail(prev, 1) else format(Sys.Date())
}
DIR_SNAP <- file.path(dir_rios, snap)

pedir_pagina <- function(code, page) {
  url <- sprintf("%s?code=%s&page=%d", BASE_URL, code, page)
  for (k in 1:4) {
    h <- curl::new_handle(useragent = USER_AGENT, timeout = 60)
    r <- tryCatch(curl::curl_fetch_memory(url, handle = h), error = function(e) e)
    if (!inherits(r, "error") && r$status_code == 200) return(list(url = url, body = r$content))
    log_msg("reintento", k, url, if (inherits(r, "error")) conditionMessage(r) else r$status_code)
    Sys.sleep(15 * k)
  }
  stop("Falla persistente en ", url)
}

parsear_html <- function(txt) {
  filas <- regmatches(txt, gregexpr("<tr[^>]*>.*?</tr>", txt, perl = TRUE))[[1]]
  celdas <- lapply(filas, function(f) {
    x <- regmatches(f, gregexpr("<td[^>]*>.*?</td>", f, perl = TRUE))[[1]]
    trimws(gsub("<[^>]+>", "", x))
  })
  celdas <- Filter(function(x) length(x) == 2 && grepl("^\\d{2}-\\d{2}-\\d{4}$", x[1]), celdas)
  total <- as.integer(sub(".*de un total de\\s*(\\d+)\\s*registros.*", "\\1",
                          regmatches(txt, regexpr("de un total de\\s*\\d+\\s*registros", txt))))
  list(filas = if (length(celdas)) data.table(fecha_txt = sapply(celdas, `[`, 1), nivel_txt = sapply(celdas, `[`, 2)) else data.table(),
       total = if (length(total)) total else NA_integer_)
}

ruta_pagina <- function(code, page) file.path(DIR_SNAP, code, sprintf("page_%05d.html.gz", page))

leer_pagina <- function(code, page) {
  con <- gzfile(ruta_pagina(code, page), "rb"); on.exit(close(con))
  rawToChar(readBin(con, "raw", 5e6))
}

guardar_pagina <- function(code, page, body) {
  p <- ruta_pagina(code, page); dir.create(dirname(p), showWarnings = FALSE, recursive = TRUE)
  con <- gzfile(paste0(p, ".part"), "wb"); writeBin(body, con); close(con)
  file.rename(paste0(p, ".part"), p)
}

descargar_estacion <- function(code) {
  bitacora <- file.path(DIR_SNAP, code, "bitacora.csv")
  if (!file.exists(ruta_pagina(code, 1))) {
    r <- pedir_pagina(code, 1); guardar_pagina(code, 1, r$body); Sys.sleep(PAUSA_SEG)
  }
  total <- parsear_html(leer_pagina(code, 1))$total
  if (is.na(total)) stop("No se pudo leer el total de registros de ", code)
  n_pag <- ceiling(total / 15)
  log_msg(code, ": total declarado", total, "registros →", n_pag, "páginas (snapshot", snap, ")")
  for (p in seq_len(n_pag)) {
    if (file.exists(ruta_pagina(code, p))) next
    r <- pedir_pagina(code, p)
    guardar_pagina(code, p, r$body)
    n <- nrow(parsear_html(rawToChar(r$body))$filas)
    fwrite(data.table(page = p, url = r$url, retrieved_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
                      bytes = length(r$body), sha256 = as.character(openssl::sha256(r$body)), filas = n),
           bitacora, append = file.exists(bitacora))
    if (p %% 100 == 0) log_msg(code, "página", p, "/", n_pag)
    Sys.sleep(PAUSA_SEG)
  }
  # Por si el total creció mientras se descargaba: pedir páginas extra hasta vaciar.
  p <- n_pag + 1
  repeat {
    if (!file.exists(ruta_pagina(code, p))) {
      r <- pedir_pagina(code, p); Sys.sleep(PAUSA_SEG)
      if (nrow(parsear_html(rawToChar(r$body))$filas) == 0) break
      guardar_pagina(code, p, r$body)
    }
    p <- p + 1
  }
}

procesar <- function() {
  diarios <- list(); control <- list()
  for (i in seq_len(nrow(ESTACIONES))) {
    code <- ESTACIONES$code[i]
    pags <- list.files(file.path(DIR_SNAP, code), pattern = "^page_\\d+\\.html\\.gz$")
    if (!length(pags)) stop("Sin páginas descargadas para ", code, " en ", DIR_SNAP)
    nums <- sort(as.integer(sub("page_(\\d+)\\.html\\.gz", "\\1", pags)))
    total <- parsear_html(leer_pagina(code, 1))$total
    esperado <- ceiling(total / 15)
    faltan <- setdiff(seq_len(esperado), nums)
    if (length(faltan)) stop(code, ": faltan ", length(faltan), " páginas (p. ej. ", paste(head(faltan), collapse = ","), ")")
    filas <- rbindlist(lapply(nums, function(p) { x <- parsear_html(leer_pagina(code, p))$filas; if (nrow(x)) x[, page := p]; x }))
    filas_leidas <- nrow(filas)
    filas[, fecha := as.IDate(fecha_txt, format = "%d-%m-%Y")]
    filas[, valor := suppressWarnings(as.numeric(sub("\\s*m$", "", nivel_txt)))]
    no_num <- filas[is.na(valor)]
    # Fechas repetidas: deben tener el mismo nivel. Se distingue su origen:
    #   - misma página  → duplicado publicado por la fuente (p. ej., 9, 14 y 15-03-2022 en las 3 estaciones);
    #   - páginas distintas → corrimiento de la paginación mientras se descargaba.
    conflictos <- filas[, .(n_val = uniqueN(nivel_txt)), by = fecha][n_val > 1]
    if (nrow(conflictos)) { print(filas[fecha %in% conflictos$fecha][order(fecha)]); stop(code, ": misma fecha con niveles distintos") }
    rep_f <- filas[, .(n = .N, paginas = uniqueN(page)), by = fecha][n > 1]
    rep_f[, origen := fifelse(paginas == 1, "fuente", "paginacion")]
    filas <- unique(filas, by = "fecha")
    filas[rep_f[origen == "fuente"], on = "fecha", dup_fuente := i.n]
    control[[code]] <- data.table(code = code, estacion = ESTACIONES$estacion[i], total_declarado = total,
                                  paginas = length(nums), filas_leidas = filas_leidas, fechas_unicas = nrow(filas),
                                  fechas_duplicadas_en_fuente = rep_f[origen == "fuente", .N],
                                  filas_repetidas_por_paginacion = rep_f[origen == "paginacion", sum(n - 1L)],
                                  valores_no_numericos = nrow(no_num),
                                  desde = min(filas$fecha), hasta = max(filas$fecha))
    # Control de completitud: las filas leídas, descontando las repetidas por paginación, deben igualar
    # el total declarado por el sitio (que cuenta también los duplicados publicados por la fuente).
    netas <- filas_leidas - rep_f[origen == "paginacion", sum(n - 1L)]
    if (netas < total) stop(code, ": filas netas ", netas, " < total declarado ", total)
    diarios[[code]] <- filas[, .(fecha, id_geo = paste0("DMH-", code), nivel_txt, valor, page, dup_fuente)]
  }
  ctrl <- rbindlist(control); print(ctrl)
  fwrite(ctrl, file.path(OUT_DIR, "rios_dmh_control_descarga.csv"))

  d <- rbindlist(diarios)
  d[, flag := fifelse(is.na(valor), paste0("valor_no_numerico:", nivel_txt), NA_character_)]
  d[!is.na(dup_fuente), flag := paste0(fifelse(is.na(flag), "", paste0(flag, "; ")), "fecha_duplicada_en_fuente(", dup_fuente, "_registros_identicos)")]
  diario <- d[, .(fecha, id_geo, nivel_geo = "estacion", variable = "nivel_rio", valor, unidad = "m",
                  fuente = "DMH-DINAC niveles hidrométricos", frecuencia = "diaria",
                  periodo_publicado = format(fecha, "%d-%m-%Y"), flag,
                  archivo_origen = sprintf("dmh_rios/%s/%s/page_%05d.html.gz", snap, sub("DMH-", "", id_geo), page))]
  escribir_largo(diario, "rios_dmh_diario", claves = c("fecha", "id_geo", "variable"),
                 insumos = paste0(DIR_SNAP, "/*"))

  # Mensual: promedio, mínimo, máximo y número de días con dato. Sin imputación.
  d[, mes := as.IDate(format(fecha, "%Y-%m-01"))]
  dias_mes <- function(m) as.integer(format(seq(m, by = "month", length.out = 2)[2] - 1, "%d"))
  m <- d[!is.na(valor), .(promedio = mean(valor), minimo = min(valor), maximo = max(valor), dias = as.numeric(.N)), by = .(id_geo, mes)]
  m[, `:=`(dias_calendario = vapply(mes, function(x) dias_mes(as.Date(x)), integer(1)), n_dias = dias)]
  largo <- melt(m, id.vars = c("id_geo", "mes", "dias_calendario", "n_dias"),
                measure.vars = c("promedio", "minimo", "maximo", "dias"), variable.name = "est", value.name = "valor")
  largo[, `:=`(variable = paste0("nivel_rio_", est), unidad = fifelse(est == "dias", "dias", "m"))]
  largo[, flag := fifelse(est != "dias" & n_dias < dias_calendario,
                          paste0("mes_incompleto:", n_dias, "/", dias_calendario, "_dias"), NA_character_)]
  mensual <- largo[, .(fecha = mes, id_geo, nivel_geo = "estacion", variable, valor, unidad,
                       fuente = "DMH-DINAC niveles hidrométricos (agregado propio)", frecuencia = "mensual",
                       periodo_publicado = NA_character_, flag, archivo_origen = paste0("dmh_rios/", snap))]
  escribir_largo(mensual, "rios_dmh_mensual", claves = c("fecha", "id_geo", "variable"),
                 insumos = paste0(DIR_SNAP, "/*"))
  fwrite(ESTACIONES[, .(id_geo = paste0("DMH-", code), estacion, rio, codigo_dmh = code)], file.path(OUT_DIR, "rios_dmh_estaciones.csv"))
}

modo <- commandArgs(TRUE)[1]
if (is.na(modo) || modo == "descargar") for (cd in ESTACIONES$code) descargar_estacion(cd)
if (is.na(modo) || modo == "procesar") procesar()
