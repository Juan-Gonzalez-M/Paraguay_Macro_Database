# Contraste de los hitos del sistema (fusiones, cambios de nombre, liquidaciones) con la evidencia disponible.
# Uso (desde esta carpeta): Rscript hitos.R
# Entradas:
#   hitos_usuario.csv  transcripción de la tabla que aportó el usuario el 2026-09-24 (imagen original:
#                      hitos_usuario_2026-09-24.png; sin fuente primaria citada). Las columnas *_publicado copian
#                      la tabla (las flechas «$\rightarrow$» de la imagen se transcriben como «→»); las columnas
#                      *_propuestas / *_propuestos son NUESTRA interpretación (claves del boletín, códigos de la base).
#   extraidos/panel_entidades.parquet (boletines 2011–2015) y la base DuckDB (panel 2016→, solo lectura).
# Salidas:
#   extraidos/altas_bajas_boletines.csv  por entidad: primer y último mes con balance propio (TOTAL ACTIVO del mes
#                                         del boletín) en 2011–2015, y meses faltantes dentro de ese rango.
#   extraidos/altas_bajas_base.csv       por código de la base: primer y último mes con datos (2016→).
#   extraidos/hitos_evidencia.csv        cada hito con esa evidencia (la lectura de coherencia está en el README).
# Nada de esto decide fechas: la fecha oficial requiere la resolución del BCP / SIB (revisión humana).

suppressPackageStartupMessages({library(DBI); library(data.table); library(arrow)})
H <- fread("hitos_usuario.csv", encoding = "UTF-8")
P <- as.data.table(read_parquet("extraidos/panel_entidades.parquet"))
P[, mes_corte := format(as.IDate(fecha_corte), "%Y-%m")]
P[, cn := gsub("\\s+", " ", gsub("\\s*>\\s*", " ", toupper(concepto)))]
# Activo total del mes: «TOTAL ACTIVO» (bancos, financieras, casas en diseño clásico) o «ACTIVO» (hoja CC de casas de
# cambio, diseño nuevo, donde es el total). En casas clásicas el activo puede estar partido en columnas: se toma
# cualquier concepto que empiece con TOTAL ACTIVO.
act <- P[!es_agregado & periodo == mes_corte & (is.na(moneda) | moneda == "TOTAL") &
           (grepl("^TOTAL ACTIVO", cn) | (hoja == "CC" & cn == "ACTIVO"))]
todos <- format(seq(as.IDate("2011-01-01"), as.IDate("2015-12-01"), by = "month"), "%Y-%m")
ab <- act[, .(tipo = paste(sort(unique(tipo)), collapse = ","), primer_mes = min(mes_corte), ultimo_mes = max(mes_corte), meses = uniqueN(mes_corte),
              faltan_en_rango = { m <- sort(unique(mes_corte)); f <- setdiff(todos[todos >= m[1] & todos <= m[length(m)]], m); paste(f, collapse = " ") }),
          by = entidad_clave][order(tipo, entidad_clave)]
ab[, lectura := fcase(primer_mes > "2011-01" & ultimo_mes < "2015-12", "entra y sale en 2011–2015",
                      primer_mes > "2011-01", "entra en 2011–2015", ultimo_mes < "2015-12", "sale en 2011–2015", default = "todo el período")]
fwrite(ab, "extraidos/altas_bajas_boletines.csv")

con <- dbConnect(duckdb::duckdb(shared_home = FALSE), "../../../database/paraguay_macro_pilot.duckdb", read_only = TRUE)
B <- as.data.table(dbGetQuery(con, "select entity_id, any_value(entity_name) entity_name, strftime(min(reference_period), '%Y-%m') primer_mes,
  strftime(max(reference_period), '%Y-%m') ultimo_mes, count(distinct reference_period) meses from research.entity_panel
  where source_id in ('banks','financial') and source_sheet = 'EEFF' group by entity_id order by entity_id"))
dbDisconnect(con, shutdown = TRUE)
fin_base <- B[, max(ultimo_mes)]
fwrite(B, "extraidos/altas_bajas_base.csv")

ev <- function(claves, codigos) {
  k <- if (claves == "") character() else strsplit(claves, ";")[[1]]
  c <- if (codigos == "") character() else strsplit(codigos, ";")[[1]]
  e1 <- ab[entidad_clave %in% k, paste0(entidad_clave, ": ", primer_mes, " → ", ultimo_mes, collapse = " | ")]
  e2 <- B[entity_id %in% c, paste0(entity_id, " (", entity_name, "): ", primer_mes, " → ", ultimo_mes, collapse = " | ")]
  c(if (length(k) && nrow(ab[entidad_clave %in% k])) e1 else "sin datos en 2011–2015",
    if (length(c) && nrow(B[entity_id %in% c])) e2 else "sin datos en la base")
}
H[, c("evidencia_boletines_2011_2015", "evidencia_base_2016") := transpose(Map(ev, claves_boletin_propuestas, codigos_base_propuestos))]
fwrite(H, "extraidos/hitos_evidencia.csv")
cat("Último mes de la base:", fin_base, "\n"); print(ab[lectura != "todo el período"]); print(H[, .(id, anio_publicado, evidencia_boletines_2011_2015, evidencia_base_2016)])
