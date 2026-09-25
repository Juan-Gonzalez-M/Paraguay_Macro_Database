# Contraste: pautas compensatorias mensuales anunciadas (libro del usuario) vs. ventas diarias efectivas del BCP al sector financiero.
# Uso (desde la raíz del repo): Rscript input/acquisition_candidates/eventos_bcp_usuario_2026-09-25/verificacion/scripts/fx_pauta_vs_ventas.R
suppressPackageStartupMessages({library(DBI); library(data.table)})
con <- dbConnect(duckdb::duckdb(shared_home = FALSE), "database/paraguay_macro_pilot.duckdb", read_only = TRUE)
d <- as.data.table(dbGetQuery(con, "select cast(period_start as date) f, value v, unit_code, scale from main.v_series_research where series_id = 'bcp_fx_daily:op_divisas_datos_diarios:b074d786fee864b2efd438e0' and period_start between '2013-12-01' and '2019-01-31' and value is not null order by 1"))
dbDisconnect(con, shutdown = TRUE)
print(head(d, 3)); print(unique(d[, .(unit_code, scale)]))
d[, mes := format(f, "%Y-%m")]
m <- d[, .(dias_obs = .N, dias_con_venta = sum(v > 0), mediana_diaria = median(v[v > 0]), moda = as.numeric(names(sort(-table(round(v[v>0],1))))[1]), total = sum(v)), by = mes]
E <- as.data.table(readxl::read_excel("input/acquisition_candidates/eventos_bcp_usuario_2026-09-25/raw/BCP_eventos_politica_2011_2026.xlsx", sheet = "Eventos", col_types = "text"))
p <- E[grepl("^FX_20(1[6-8])_", event_id), .(mes = sub("FX_(\\d{4})_(\\d{2})", "\\1-\\2", event_id), anuncio = announcement_date,
        pauta = as.numeric(sub(".*anuncia USD ([0-9.]+) millones.*", "\\1", description)))]
x <- merge(p, m, by = "mes", all.x = TRUE)
print(x, nrows = 50)
fwrite(x, "input/acquisition_candidates/eventos_bcp_usuario_2026-09-25/verificacion/fx_pauta_vs_ventas_2016_2018.csv")
