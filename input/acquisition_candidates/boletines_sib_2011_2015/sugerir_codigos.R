# Sugerencia (NO decisión) de vínculo entre las entidades de los boletines 2011–2015 y los códigos de entidad
# de la base (canonical.dim_entity), usando la continuidad del activo: boletín 2015-12 vs. panel de la
# base 2016-01 (research.entity_panel, lectura solamente). Muchas entidades cambiaron de nombre (Amambay -> Basa,
# Itapúa -> Río, BBVA -> código 1007), así que el nombre solo no alcanza.
# Uso (desde esta carpeta): Rscript sugerir_codigos.R  -> vinculo_codigos_sugerido.csv (estado_revision = pendiente)
# Regla: empareja cada entidad del boletín con la entidad de la base cuyo activo en MONEDA NACIONAL y en MONEDA
# EXTRANJERA esté más cerca (suma de |log| de ambos cocientes; el total solo no distingue entidades de tamaño
# parecido, p. ej. BNF y Sudameris en 2015-12), sin repetir, y lo marca «revisar» si alguno cambia más de 15%.
# Entidades que dejaron de existir antes
# de 2015-12 quedan sin sugerencia (necesitan revisión humana con otra evidencia).

suppressPackageStartupMessages({library(DBI); library(data.table); library(arrow)})
BASE <- "../../../database/paraguay_macro_pilot.duckdb"
con <- dbConnect(duckdb::duckdb(shared_home = FALSE), BASE, read_only = TRUE)
db <- as.data.table(dbGetQuery(con, "select source_id, entity_id, entity_name, source_currency_code mon, sum(value) v
  from research.entity_panel where source_id in ('banks','financial') and source_sheet = 'EEFF'
  and reference_period = '2016-01-31' and semantic_classification = '1. Activo' group by all"))
dbDisconnect(con, shutdown = TRUE)
# códigos de moneda del panel de la base: 6900 = moneda nacional, 6200 = moneda extranjera
db <- db[, .(mn_b = sum(v[mon == "6900"]), me_b = sum(v[mon == "6200"])), by = .(source_id, entity_id, entity_name)]
db[, `:=`(activo_base_2016_01 = mn_b + me_b, tipo = fifelse(source_id == "banks", "bancos", "financieras"))]

P <- as.data.table(read_parquet("extraidos/panel_entidades.parquet"))
bol <- P[format(as.IDate(fecha_corte), "%Y-%m") == "2015-12" & diseno == "nuevo" & !es_agregado & moneda %in% c("MN", "ME", "TOTAL") &
           toupper(trimws(concepto)) == "TOTAL ACTIVO" & asignacion == "encabezado_columna"]
bol <- dcast(bol, tipo + entidad_clave ~ moneda, value.var = "valor", fun.aggregate = function(v) v[1])
setnames(bol, c("MN", "ME", "TOTAL"), c("mn_a", "me_a", "activo_boletin_2015_12"))
lr <- function(x, y) abs(log(pmax(x, 1) / pmax(y, 1)))

out <- rbindlist(lapply(c("bancos", "financieras"), function(t) {
  a <- bol[tipo == t]; b <- db[tipo == t]
  d <- CJ(i = seq_len(nrow(a)), j = seq_len(nrow(b)))[, dist := lr(b$mn_b[j], a$mn_a[i]) + lr(b$me_b[j], a$me_a[i])]
  setorder(d, dist); usados_i <- integer(); usados_j <- integer(); r <- list()
  for (k in seq_len(nrow(d))) if (!(d$i[k] %in% usados_i) && !(d$j[k] %in% usados_j)) {
    usados_i <- c(usados_i, d$i[k]); usados_j <- c(usados_j, d$j[k]); r[[length(r) + 1]] <- d[k] }
  r <- rbindlist(r)
  data.table(tipo = t, entidad_clave = a$entidad_clave[r$i], activo_boletin_2015_12 = a$activo_boletin_2015_12[r$i],
             entity_id = b$entity_id[r$j], entity_name_base = b$entity_name[r$j], activo_base_2016_01 = b$activo_base_2016_01[r$j],
             variacion = b$activo_base_2016_01[r$j] / a$activo_boletin_2015_12[r$i] - 1,
             variacion_mn = b$mn_b[r$j] / a$mn_a[r$i] - 1, variacion_me = b$me_b[r$j] / a$me_a[r$i] - 1)
}))
out[, marca := fifelse(pmax(abs(variacion_mn), abs(variacion_me)) > 0.15, "revisar: variación MN o ME > 15%", "")]
out[, `:=`(metodo = "continuidad del activo en MN y ME, 2015-12 -> 2016-01", estado_revision = "pendiente")]
setorder(out, tipo, -activo_boletin_2015_12)
fwrite(out, "vinculo_codigos_sugerido.csv")
print(out[, .(tipo, entidad_clave, entity_id, entity_name_base, var_total = round(100 * variacion, 1),
              var_mn = round(100 * variacion_mn, 1), var_me = round(100 * variacion_me, 1), marca)])
cat("Sin sugerencia (no están en el boletín de 2015-12):",
    paste(setdiff(P[!es_agregado & tipo %in% c("bancos", "financieras"), unique(entidad_clave)], out$entidad_clave), collapse = "; "), "\n")
