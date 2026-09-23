## Proyecto 33 · N12 (nuevo) — Remesas familiares: shocks en los países de origen y consumo
## Remesas mensuales por país de origen (Cuadro 58, 2008-2026) con shocks de los países de origen
## (desempleo en España y EE.UU., tipo de cambio de Argentina y EUR/USD) en un diseño shift-share.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
pyg_usd_prom_venta,exchange_rates:usd_prom:190c4a9509f6c233bdc28928,PYG por USD promedio mensual,Conversión / canal cambiario
pyg_eur,economic_annex:cuadro_60a:9b265b8246f1c6383a14d886,PYG por EUR,Valor en guaraníes de remesas desde Europa
pyg_ars,economic_annex:cuadro_60a:2758fed7ea57c524cd0fcb0c,PYG por ARS,Valor en guaraníes de remesas desde Argentina
ars_usd_prom,imf_er:c45a0a7edaa90b29d3564005,FMI: ARS por USD promedio mensual,Shock en el país de origen (Argentina)
ipc_argentina,imf_cpi:e3b883567e33f043224c1a88,FMI: IPC Argentina,Shock en origen (salario real)
imaep_original,economic_annex:cuadro_9:fc9a02c5dcc0573b3c038553,IMAEP serie original,Resultado agregado
consumo_privado_real,economic_annex:cuadro_7:8ec08dadb3d7e0f27eb4c838,PIB por gasto: consumo privado (millones de Gs. de 2014; trimestral),Resultado: consumo
ipc_indice,economic_annex:cuadro_14:a5d7fc4139616340def083cc,IPC índice general,Deflactor
dep_priv_me_total_usd,economic_annex:cuadro_23a:6665dcbd306238301a26a70e,Depósitos privados en ME (millones de USD),Resultado: ahorro en dólares
", stringsAsFactors = FALSE, strip.white = TRUE)

externos <- read.csv(text = "
serie,id,agregacion,unidad,descripcion,rol
desempleo_espana,LRHUTTTTESM156S,,PERCENT,FRED/OCDE: tasa de desempleo de España (mensual),Shock en origen (España)
desempleo_eeuu,UNRATE,,PERCENT,FRED: tasa de desempleo de EE.UU.,Shock en origen (EE.UU.)
usd_por_eur_m,DEXUSEU,avg,USD_PER_EUR,FRED: USD por EUR (promedio mensual),Shock cambiario en origen (Europa)
", stringsAsFactors = FALSE, strip.white = TRUE, na.strings = "")

con <- conectar()
rem <- spec_por_hoja(con, "economic_annex", "CUADRO 58", "remesas", "Remesas familiares por país de origen (miles de USD; algunas en EUR)")
spec <- rbind(dicc, rem)
x <- extraer_escalares(con, spec)
ext <- leer_fred_bloque(externos)
escribir_series(rbind(x, ext), rbind(spec[, c("serie", "descripcion", "rol")], externos[, c("serie", "descripcion", "rol")]))
cerrar(con)
