## Proyecto 25 · N4 (nuevo) — Sorpresas de política monetaria de alta frecuencia
## Tasas diarias del mercado interbancario, corredor (FPL/FPD), subastas de LRM, curvas de bonos
## y TCN alrededor de las reuniones del COPOM. Las fechas del COPOM se cargan a mano en
## datos_manuales/calendario_copom.csv; mientras tanto se infieren de los cambios diarios del corredor.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,TPM promedio mensual (Cuadro 19),Referencia mensual
eve_tpm_mes,eve:tasa_de_politica_monetaria_tpm:expectativa_del_mes,EVE (mediana): TPM esperada para el mes,Sorpresa mensual alternativa (baja frecuencia)
eve_tpm_prox_mes,eve:tasa_de_politica_monetaria_tpm:expectativa_del_proximo_mes,EVE (mediana): TPM esperada próximo mes,Sorpresa mensual alternativa
eve_tpm_anio_t,eve:tasa_de_politica_monetaria_tpm:expectativa_ano_t,EVE (mediana): TPM esperada fin de año t,Sorpresa de trayectoria (forward guidance)
eve_tpm_anio_t1,eve:tasa_de_politica_monetaria_tpm:expectativa_ano_t_1,EVE (mediana): TPM esperada fin de año t+1,Sorpresa de trayectoria
tcn_venta,tcn_referential_daily:tcn_referencial_daily:5fc9eaa0817a8a6ece9666c4,TCN referencial diario PYG/USD venta,Resultado diario: tipo de cambio
bcp_fx_neto_total_d,bcp_fx_daily:op_divisas_datos_diarios:542ac0ab6cb137a1139018b2,Compras netas diarias del BCP,Control (días con intervención)
", stringsAsFactors = FALSE, strip.white = TRUE)

externos <- read.csv(text = "
serie,id,agregacion,unidad,descripcion,rol
fed_funds_d,DFF,,PERCENT,FRED: tasa de fondos federales efectiva diaria,Control externo diario
ust_2a_d,DGS2,,PERCENT,FRED: rendimiento Tesoro EE.UU. 2 años diario,Control externo diario
vix_d,VIXCLS,,INDEX_POINTS,FRED: VIX diario,Control externo diario
", stringsAsFactors = FALSE, strip.white = TRUE, na.strings = "")

con <- conectar()
## Todas las series diarias semánticas del mercado interbancario (hoja 'Datos')
ib <- dbGetQuery(con, "SELECT candidate_id, researcher_name FROM catalog.series
                        WHERE source_id = 'interbank_market' AND trim(source_sheet) = 'Datos' AND frequency = 'daily'
                        ORDER BY researcher_name")
ib <- data.frame(serie = paste0("ib_", slug(ib$researcher_name, 60)), candidate_id = ib$candidate_id,
                 descripcion = paste("Mercado interbancario diario:", ib$researcher_name),
                 rol = "Resultado diario: tasas y cantidades de corto plazo", stringsAsFactors = FALSE)
ib$serie <- make.unique(ib$serie, sep = "_")
x <- extraer_escalares(con, dicc)
y <- extraer_eventos_diarios(con, ib)
ext <- leer_fred_bloque(externos)
escribir_series(rbind(x, y, ext), rbind(dicc[, c("serie", "descripcion", "rol")], ib[, c("serie", "descripcion", "rol")],
                                          externos[, c("serie", "descripcion", "rol")]))

message("Infiriendo fechas de cambio del corredor (FPD y FPL diarias)...")
corr <- y[y$serie %in% ib$serie[grepl("Facilidad Permanente de (Depósito|Liquidez) \\(F(PD|PL)\\) — Tasa", ib$descripcion)], ]
corr <- corr[order(corr$serie, corr$fecha), ]
cambios <- do.call(rbind, lapply(split(corr, corr$serie), function(z) {
  d <- c(NA, diff(z$valor)); k <- which(!is.na(d) & abs(d) > 1e-9)
  if (!length(k)) return(NULL)
  data.frame(fecha = z$fecha[k], serie = z$serie[k], tasa_anterior = z$valor[k - 1], tasa_nueva = z$valor[k],
             cambio_pb = round(100 * d[k]), dias_desde_obs_anterior = as.integer(z$fecha[k] - z$fecha[k - 1]))
}))
cambios$nota <- "Inferido: cambio de la tasa diaria de la facilidad; NO es la fecha de la reunión del COPOM (verificar)"
escribir_csv(cambios[order(cambios$fecha, cambios$serie), ], "cambios_corredor_inferidos.csv")
## Fechas candidatas de cambio de TPM: FPD y FPL cambian el mismo día y en la misma magnitud
fpd <- cambios[grepl("deposito", cambios$serie), c("fecha", "cambio_pb", "tasa_nueva")]
fpl <- cambios[grepl("liquidez_fpl_tasa", cambios$serie), c("fecha", "cambio_pb", "tasa_nueva")]
cand <- merge(fpd, fpl, by = "fecha", suffixes = c("_fpd", "_fpl"))
cand <- cand[cand$cambio_pb_fpd == cand$cambio_pb_fpl, ]
cand$tpm_implicita_nueva <- (cand$tasa_nueva_fpd + cand$tasa_nueva_fpl) / 2
cand$nota <- "Candidata: corredor simétrico desplazado en paralelo; confirmar con el calendario del COPOM"
escribir_csv(cand[order(cand$fecha), ], "fechas_candidatas_cambio_tpm.csv")

message("Eventos: subastas de LRM y curvas de bonos en PYG...")
ev <- dbGetQuery(con, "SELECT CAST(reference_period_start AS DATE) AS fecha, source_sheet AS hoja, full_series_path AS detalle,
                              researcher_name AS variable, value AS valor, unit_code AS unidad, candidate_id, source_row
                         FROM explore.events WHERE source_id = 'lrm_auctions' ORDER BY fecha, candidate_id")
ev$nivel_verificacion <- "Estructura especial (provisional)"
escribir_csv(ev, "eventos_subastas_lrm.csv")
cur <- dbGetQuery(con, "SELECT CAST(period AS DATE) AS fecha, risk_rating AS calificacion, maturity_years AS plazo_anios,
                               zero_coupon_rate AS tasa_cero FROM research.curves WHERE currency = 'PYG'
                         ORDER BY fecha, calificacion, plazo_anios")
cur$nivel_verificacion <- "Validada por regla (estructural)"
escribir_csv(cur, "curvas_bonos_pyg.csv")

message("Calendario del COPOM (manual)...")
leer_manual("calendario_copom",
            c("fecha_reunion", "fecha_anuncio", "hora_anuncio", "tpm_anterior", "tpm_nueva", "tipo_reunion", "fuente", "estado_verificacion"))
cerrar(con)
