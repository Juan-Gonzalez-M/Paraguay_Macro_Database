# Ejecuta el bloque clima/agro de principio a fin, en orden, desde la raíz del repositorio:
#   Rscript R/clima/99_ejecutar_todo.R
# Cada script corre en un proceso R separado. Los que dependen de credenciales o de descargas
# manuales (ERA5-Land, SPEI, EM-DAT, MODIS) se OMITEN con aviso si falta el requisito; el resto
# debe terminar sin error. Al final, 98_catalogo.R verifica salidas contra el manifiesto y
# regenera el catálogo de data/clima/README.md; 97_inventario_proyectos.R actualiza el inventario de series.

if (!file.exists("AGENTS.md")) stop("Ejecutar desde la raíz del repositorio.")
ACQ_NUEVA <- "input/acquisition_candidates/clima_agro_2026-09-23_faseB"

tiene_era5 <- function() file.exists(path.expand("~/.cdsapirc")) ||
  length(list.files(file.path(ACQ_NUEVA, "era5land"), pattern = "\\.nc$")) > 0
PASOS <- list(
  list("01_enso.R"), list("02_mag_produccion.R"), list("03_chirps.R"), list("04_spi.R"),
  list("05_rios_dmh.R"),
  list("06_era5land.R", requisito = tiene_era5,
       motivo = "sin ~/.cdsapirc ni NetCDF descargados (ver README: Instrucciones ERA5-Land)",
       args = function() if (file.exists(path.expand("~/.cdsapirc"))) character() else "procesar"),
  list("07_spei.R", requisito = function() file.exists("data/clima/clima_era5land.csv"),
       motivo = "requiere data/clima/clima_era5land.csv (06_era5land.R)"),
  list("08_iri.R"), list("09_hidro_itaipu.R"), list("10_faostat_usda.R"), list("11_abasto.R"),
  list("12_emdat.R", requisito = function() length(list.files(file.path(ACQ_NUEVA, "emdat"), pattern = "\\.xlsx$")) > 0,
       motivo = "sin Excel de EM-DAT (ver README: Instrucciones EM-DAT)"),
  list("13_modis_ndvi.R", requisito = function() length(list.files(file.path(ACQ_NUEVA, "modis"), pattern = "^MOD13A3.*\\.tif$")) > 0,
       motivo = "sin GeoTIFF de AppEEARS (ver README: Instrucciones MODIS)"),
  list("14_calendario_cultivos.R"),
  list("98_catalogo.R"),
  list("97_inventario_proyectos.R")
)

resumen <- data.frame(script = character(), estado = character(), segundos = numeric(), stringsAsFactors = FALSE)
for (p in PASOS) {
  s <- p[[1]]
  if (!is.null(p$requisito) && !p$requisito()) {
    message(">>> OMITIDO ", s, ": ", p$motivo)
    resumen[nrow(resumen) + 1, ] <- list(s, paste("omitido:", p$motivo), 0); next
  }
  a <- if (!is.null(p$args)) p$args() else character()
  message(">>> ", s, " ", paste(a, collapse = " "))
  t0 <- Sys.time()
  rc <- system2("Rscript", c(file.path("R/clima", s), a))
  seg <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")))
  resumen[nrow(resumen) + 1, ] <- list(s, if (rc == 0) "ok" else paste("ERROR", rc), seg)
  if (rc != 0) { print(resumen); stop("Falló ", s, " (código ", rc, ")") }
}
print(resumen)
