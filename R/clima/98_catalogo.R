# Verificación final y catálogo del bloque clima/agro.
#
# 1) Para cada archivo del manifiesto (data/clima/00_manifiesto.csv) recalcula filas, fechas mínima y
#    máxima y SHA-256, y falla si algo no coincide (salida modificada a mano o manifiesto desactualizado).
#    También falla si hay CSV en formato largo en data/clima que no estén en el manifiesto.
# 2) Escribe data/clima/00_catalogo_variables.csv: una fila por (archivo, variable) con unidad,
#    frecuencia, niveles geográficos, desde, hasta, observaciones y NA.
# 3) Regenera en data/clima/README.md la sección entre <!-- CATALOGO:INICIO --> y <!-- CATALOGO:FIN -->
#    con los rangos calculados de los datos (así el catálogo nunca queda desalineado con los archivos).

source("R/clima/00_utils.R")

man <- fread(MANIFIESTO, colClasses = "character")
largos <- setdiff(list.files(OUT_DIR, pattern = "\\.csv$"), c(basename(MANIFIESTO), "00_catalogo_variables.csv"))
es_largo <- vapply(largos, function(f) identical(names(fread(file.path(OUT_DIR, f), nrows = 0)), COLS_LARGO), logical(1))
sin_man <- setdiff(largos[es_largo], man$archivo)
if (length(sin_man)) stop("CSV en formato largo sin entrada en el manifiesto: ", paste(sin_man, collapse = ", "))
faltan <- setdiff(man$archivo, largos)
# Salidas locales por licencia (no se suben a Git; ver data/clima/.gitignore): si faltan, se omiten con aviso.
SOLO_LOCALES <- c("eventos_emdat_mensual.csv", "eventos_emdat_paraguay.csv")
omit <- intersect(faltan, SOLO_LOCALES)
if (length(omit)) { log_msg("Omitidos (solo locales por licencia; correr 12_emdat.R para regenerarlos):", paste(omit, collapse = ", ")); man <- man[!archivo %in% omit] }
faltan <- setdiff(faltan, SOLO_LOCALES)
if (length(faltan)) stop("El manifiesto lista archivos inexistentes: ", paste(faltan, collapse = ", "))

PROYECTOS <- c(
  enso_indices = "09 D1, 12 D4, 13 D5, 10 D2*, 11 D3*",
  enso_iri_pronosticos = "11 D3*, 12 D4",
  clima_chirps_precipitacion = "10 D2*, 09 D1, 12 D4, 13 D5, 22 N1, 23 N2, 28 N7",
  clima_spi = "10 D2*, 13 D5, 12 D4, 28 N7, 23 N2",
  clima_era5land = "10 D2*, 12 D4, 13 D5, 09 D1",
  clima_spei = "10 D2*, 13 D5, 12 D4",
  clima_modis_vegetacion = "10 D2*, 13 D5",
  rios_dmh_diario = "19 F3*, 09 D1, 10 D2*, 18 F2",
  rios_dmh_mensual = "19 F3*, 09 D1, 10 D2*, 18 F2",
  hidro_itaipu_diario = "19 F3*, 22 N1, 09 D1",
  hidro_itaipu_mensual = "19 F3*, 22 N1, 09 D1",
  agro_mag_departamental = "10 D2*, 09 D1, 13 D5, 12 D4",
  agro_faostat_nacional = "10 D2*, 09 D1, 12 D4",
  agro_usda_psd_nacional = "10 D2*, 09 D1, 12 D4",
  abasto_precios_diario = "12 D4, 18 F2, 26 N5",
  abasto_precios_mensual = "12 D4, 18 F2, 26 N5",
  abasto_ingresos_mensual = "12 D4, 18 F2, 26 N5",
  eventos_emdat_mensual = "09 D1, 13 D5, 28 N7, 23 N2"
)

cat_rows <- list(); res_rows <- list()
for (i in seq_len(nrow(man))) {
  a <- man$archivo[i]; p <- file.path(OUT_DIR, a)
  x <- fread(p, colClasses = list(character = c("flag", "periodo_publicado")))
  chk <- c(filas = nrow(x) == as.integer(man$filas[i]),
           fecha_min = as.character(min(x$fecha)) == man$fecha_min[i],
           fecha_max = as.character(max(x$fecha)) == man$fecha_max[i],
           sha256 = sha256_archivo(p) == man$sha256[i])
  if (!all(chk)) stop(a, ": no coincide con el manifiesto en ", paste(names(chk)[!chk], collapse = ", "))
  cv <- x[, .(unidad = paste(unique(unidad), collapse = " | "), frecuencia = paste(unique(frecuencia), collapse = ","),
              nivel_geo = paste(sort(unique(nivel_geo)), collapse = ","), n_id_geo = uniqueN(id_geo),
              desde = min(fecha), hasta = max(fecha), obs = .N, valores_na = sum(is.na(valor)),
              filas_con_flag = sum(!is.na(flag) & flag != "")), by = variable]
  cat_rows[[a]] <- cbind(archivo = a, cv)
  base <- sub("\\.csv$", "", a)
  res_rows[[a]] <- data.table(archivo = a, filas = nrow(x), variables = uniqueN(x$variable),
                              frecuencia = paste(unique(x$frecuencia), collapse = ", "),
                              geo = paste(sort(unique(x$nivel_geo)), collapse = ", "),
                              n_geo = uniqueN(x$id_geo),
                              desde = as.character(min(x$fecha)), hasta = as.character(max(x$fecha)),
                              proyectos = if (base %in% names(PROYECTOS)) PROYECTOS[[base]] else "—")
}
catalogo <- rbindlist(cat_rows)
fwrite(catalogo, file.path(OUT_DIR, "00_catalogo_variables.csv"))
resumen <- rbindlist(res_rows)
log_msg("Verificación OK:", nrow(man), "archivos coinciden con el manifiesto;", nrow(catalogo), "variables catalogadas")

fmt <- function(n) formatC(n, format = "d", big.mark = ".", decimal.mark = ",")
tabla <- c("| Archivo | Filas | Variables | Frecuencia | Nivel geográfico (n unidades) | Desde | Hasta | Proyectos |",
           "|---|---|---|---|---|---|---|---|",
           resumen[, sprintf("| `%s` | %s | %d | %s | %s (%d) | %s | %s | %s |", archivo, fmt(filas), variables,
                             frecuencia, geo, n_geo, desde, hasta, proyectos)])
# Rango por variable "principal" de cada archivo con muchas variables: se remite al CSV del catálogo.
bloque <- c("<!-- CATALOGO:INICIO -->",
            paste0("*Generado por `R/clima/98_catalogo.R` el ", format(Sys.time(), "%Y-%m-%d %H:%M"),
                   " a partir de los archivos; no editar a mano. Detalle por variable (unidad, rango, NA, flags) en `00_catalogo_variables.csv`.*"),
            "", tabla, "", "<!-- CATALOGO:FIN -->")
readme <- file.path(OUT_DIR, "README.md")
if (file.exists(readme)) {
  r <- readLines(readme, warn = FALSE)
  i <- grep("<!-- CATALOGO:INICIO -->", r, fixed = TRUE); j <- grep("<!-- CATALOGO:FIN -->", r, fixed = TRUE)
  if (length(i) != 1 || length(j) != 1 || j < i) stop("README sin marcadores de catálogo válidos")
  writeLines(c(r[seq_len(i - 1)], bloque, r[-seq_len(j)]), readme)
  log_msg("Catálogo actualizado en", readme)
} else log_msg("README.md no existe todavía; catálogo solo en 00_catalogo_variables.csv")
