# Utilidades comunes del bloque clima/agro.
# Ejecutar los scripts desde la raíz del repositorio: Rscript R/clima/NN_fuente.R
# Nada de esto toca la base DuckDB ni input/current/.

suppressPackageStartupMessages({
  library(data.table)
})

if (!file.exists("AGENTS.md") || !dir.exists("R/clima")) {
  stop("Ejecutar desde la raíz del repositorio (donde está AGENTS.md).")
}

ACQ_BASE  <- "input/acquisition_candidates/clima_agro_2026-09-23"        # insumos de la Fase A (solo lectura)
ACQ_NUEVA <- "input/acquisition_candidates/clima_agro_2026-09-23_faseB"  # descargas de la Fase B
OUT_DIR   <- "data/clima"
dir.create(ACQ_NUEVA, showWarnings = FALSE, recursive = TRUE)
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

USER_AGENT <- "BCP-investigacion-clima/1.0 (uso academico; descarga lenta)"

COLS_LARGO <- c("fecha", "id_geo", "nivel_geo", "variable", "valor", "unidad", "fuente",
                "frecuencia", "periodo_publicado", "flag", "archivo_origen")
NIVELES_GEO <- c("nacional", "departamento", "estacion", "punto", "mercado", "global")
FRECUENCIAS <- c("diaria", "mensual", "bimestral_movil", "trimestral_movil", "anual",
                 "campania", "censal", "estatica", "vintage_mensual")

sha256_archivo <- function(path) {
  vapply(path, function(p) {
    con <- file(p, "rb"); on.exit(close(con))
    as.character(openssl::sha256(con))
  }, character(1), USE.NAMES = FALSE)
}

log_msg <- function(...) cat(format(Sys.time(), "%H:%M:%S"), "|", ..., "\n")

# ---------------------------------------------------------------------------
# Descargas: siempre dentro de ACQ_NUEVA, con inventario (url, fecha, bytes, sha256).
# No sobrescribe un archivo existente salvo refrescar = TRUE.
# ---------------------------------------------------------------------------
INVENTARIO_NUEVO <- file.path(ACQ_NUEVA, "inventory.csv")

registrar_descarga <- function(rel_path, url, status) {
  p <- file.path(ACQ_NUEVA, rel_path)
  fila <- data.table(path = rel_path, url = url,
                     retrieved_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
                     bytes = file.size(p), sha256 = sha256_archivo(p), status = status)
  inv <- if (file.exists(INVENTARIO_NUEVO)) fread(INVENTARIO_NUEVO, colClasses = "character") else NULL
  if (!is.null(inv)) inv <- inv[path != rel_path]
  fwrite(rbind(inv, fila[, lapply(.SD, as.character)]), INVENTARIO_NUEVO)
}

descargar <- function(url, rel_path, refrescar = FALSE, pausa = 1, intentos = 3) {
  dest <- file.path(ACQ_NUEVA, rel_path)
  dir.create(dirname(dest), showWarnings = FALSE, recursive = TRUE)
  if (file.exists(dest) && !refrescar) return(invisible(dest))
  tmp <- paste0(dest, ".part")
  for (k in seq_len(intentos)) {
    h <- curl::new_handle(useragent = USER_AGENT, followlocation = TRUE, timeout = 600)
    r <- tryCatch(curl::curl_fetch_disk(url, tmp, handle = h), error = function(e) e)
    if (!inherits(r, "error") && r$status_code == 200) {
      file.rename(tmp, dest)
      registrar_descarga(rel_path, url, "downloaded")
      Sys.sleep(pausa)
      return(invisible(dest))
    }
    msg <- if (inherits(r, "error")) conditionMessage(r) else paste("HTTP", r$status_code)
    log_msg("fallo", k, "/", intentos, url, msg)
    Sys.sleep(5 * k)
  }
  unlink(tmp)
  stop("No se pudo descargar: ", url)
}

# ---------------------------------------------------------------------------
# Geografía: 18 unidades del INE (CNPV 2022). id_geo = "PY-" + código DPTO.
# ---------------------------------------------------------------------------
GEOJSON_DPTOS <- file.path(ACQ_BASE, "ine/DEPARTAMENTOS_PY_CNPV2022.geojson")

normalizar_nombre <- function(x) {
  x <- toupper(trimws(x))
  x <- chartr("ÁÉÍÓÚÜ", "AEIOUU", x)
  x <- gsub("Ñ", "N", x)
  x <- gsub("\\s+", " ", x)
  x <- sub("^PTE\\.? ", "PRESIDENTE ", x)
  x
}

tabla_departamentos <- function() {
  g <- jsonlite::fromJSON(GEOJSON_DPTOS, simplifyVector = FALSE)
  d <- rbindlist(lapply(g$features, function(f) data.table(dpto = f$properties$DPTO, nombre = f$properties$DPTO_DESC)))
  d[, id_geo := paste0("PY-", dpto)][, clave := normalizar_nombre(nombre)]
  setorder(d, dpto)[]
}

# Asigna id_geo a nombres de departamento publicados (MAG, CAN). Falla ante nombres desconocidos.
id_departamento <- function(nombres) {
  d <- tabla_departamentos()
  k <- normalizar_nombre(nombres)
  out <- d$id_geo[match(k, d$clave)]
  malos <- unique(nombres[is.na(out)])
  if (length(malos)) stop("Departamento sin correspondencia INE: ", paste(malos, collapse = ", "))
  out
}

# ---------------------------------------------------------------------------
# Escritura en formato largo con validación y manifiesto.
# claves: columnas que deben identificar unívocamente cada fila.
# ---------------------------------------------------------------------------
MANIFIESTO <- file.path(OUT_DIR, "00_manifiesto.csv")

escribir_largo <- function(dt, nombre, claves = c("fecha", "id_geo", "variable", "archivo_origen"),
                           insumos = character()) {
  dt <- as.data.table(dt)
  faltan <- setdiff(COLS_LARGO, names(dt))
  if (length(faltan)) stop(nombre, ": faltan columnas ", paste(faltan, collapse = ", "))
  dt <- dt[, ..COLS_LARGO]
  dt[, fecha := as.IDate(fecha)]
  dt[, valor := as.numeric(valor)]
  if (anyNA(dt$fecha)) stop(nombre, ": fechas NA")
  if (!all(dt$nivel_geo %in% NIVELES_GEO)) stop(nombre, ": nivel_geo inválido: ", paste(setdiff(unique(dt$nivel_geo), NIVELES_GEO), collapse = ","))
  if (!all(dt$frecuencia %in% FRECUENCIAS)) stop(nombre, ": frecuencia inválida: ", paste(setdiff(unique(dt$frecuencia), FRECUENCIAS), collapse = ","))
  if (anyNA(dt$id_geo) || anyNA(dt$variable) || anyNA(dt$unidad) || anyNA(dt$fuente)) stop(nombre, ": NA en columnas de identificación")
  dup <- dt[, .N, by = claves][N > 1]
  if (nrow(dup)) { print(head(dup)); stop(nombre, ": claves duplicadas (", nrow(dup), ")") }
  setorderv(dt, c("variable", "id_geo", "fecha"))
  path <- file.path(OUT_DIR, paste0(nombre, ".csv"))
  fwrite(dt, path, na = "NA")

  fila <- data.table(
    archivo = basename(path), filas = nrow(dt),
    fecha_min = as.character(min(dt$fecha)), fecha_max = as.character(max(dt$fecha)),
    n_variables = uniqueN(dt$variable), n_id_geo = uniqueN(dt$id_geo),
    valores_na = sum(is.na(dt$valor)),
    sha256 = sha256_archivo(path),
    insumos = paste(insumos, collapse = ";"),
    generado = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  )
  man <- if (file.exists(MANIFIESTO)) fread(MANIFIESTO, colClasses = "character") else NULL
  if (!is.null(man)) man <- man[archivo != fila$archivo]
  fwrite(rbind(man, fila[, lapply(.SD, as.character)]), MANIFIESTO)
  log_msg("escrito", path, ":", nrow(dt), "filas,", fila$fecha_min, "→", fila$fecha_max)
  invisible(dt)
}

# Resumen de insumos para el manifiesto: "ruta@sha256[1:12]"
huella <- function(paths) paste0(paths, "@", substr(sha256_archivo(paths), 1, 12))
