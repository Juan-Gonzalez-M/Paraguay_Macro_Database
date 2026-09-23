## Proyecto 26 · N5 (nuevo) — Shocks cambiarios de Argentina y economía fronteriza paraguaya
## Devaluaciones y controles cambiarios argentinos como shocks grandes, fechados y externos:
## tipo de cambio PYG/ARS, comercio bilateral (Anexo e IMTS), importaciones bajo régimen de turismo
## (reexportación), precios transables, remesas desde Argentina. Brasil como placebo parcial.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
pyg_ars,economic_annex:cuadro_60a:2758fed7ea57c524cd0fcb0c,PYG por ARS (promedio mensual; Cuadro 60a),Shock: tipo de cambio bilateral
pyg_brl,economic_annex:cuadro_60a:2442b69bab143106463ed144,PYG por BRL (Cuadro 60a),Placebo / control regional
pyg_usd_prom_venta,exchange_rates:usd_prom:190c4a9509f6c233bdc28928,PYG por USD promedio mensual,Control
tcr_argentina,economic_annex:cuadro_60c:8ec28511cf3e35f6d413c26f,Tipo de cambio real bilateral con Argentina,Shock real (gap de precios)
tcr_brasil,economic_annex:cuadro_60c:df5674f2dacbbc4d470c3175,Tipo de cambio real bilateral con Brasil,Placebo
ars_usd_prom,imf_er:c45a0a7edaa90b29d3564005,FMI: ARS por USD promedio mensual (oficial),Shock: devaluación oficial argentina
brl_usd_prom,imf_er:13f5f115b7431dbad5fcb4b6,FMI: BRL por USD promedio mensual,Placebo
ipc_argentina,imf_cpi:e3b883567e33f043224c1a88,FMI: IPC Argentina (desde dic-2016),Precios del vecino
ipc_brasil,imf_cpi:ba03fe4dcdde13d15e4126f3,FMI: IPC Brasil,Precios del vecino (placebo)
tpm_argentina,imf_mfs_ir:0ea7d6c5d48ac4a212348a2b,FMI: tasa de política Argentina,Contexto del shock
expo_argentina,economic_annex:cuadro_45:176082e3d76511cb8de20384,Exportaciones registradas a Argentina (miles USD),Resultado: comercio
expo_brasil,economic_annex:cuadro_45:67e8920792be474187167d91,Exportaciones registradas a Brasil,Placebo
expo_total,economic_annex:cuadro_45:bf8595a1dd956a764d20c6a1,Exportaciones registradas totales,Normalización
impo_argentina,economic_annex:cuadro_50:176082e3d76511cb8de20384,Importaciones registradas desde Argentina (miles USD),Resultado: comercio
impo_brasil,economic_annex:cuadro_50:67e8920792be474187167d91,Importaciones registradas desde Brasil,Placebo
impo_total,economic_annex:cuadro_50:bf8595a1dd956a764d20c6a1,Importaciones registradas totales,Normalización
remesas_argentina,economic_annex:cuadro_58:ef41d4327ef626b39b618ef8,Remesas familiares desde Argentina (miles USD),Resultado: ingreso de hogares
remesas_total,economic_annex:cuadro_58:936554c066082e51a38ba32e,Remesas familiares totales,Normalización
ipc_indice,economic_annex:cuadro_14:a5d7fc4139616340def083cc,IPC Paraguay índice general,Resultado: precios
ipc_transables_sin_fyv,economic_annex:cuadro_14_a:1f5d8129468fa2246f4ef067,IPC transables sin frutas y verduras,Resultado: precios transables
ipc_no_transables,economic_annex:cuadro_14_a:14eda4efc6655f8715834492,IPC no transables,Placebo (no transables)
ipc_importados_sin_fyv,economic_annex:cuadro_14_a:907533be614b9497d5409ff9,IPC importados sin frutas y verduras,Resultado: precios importados
ipc_alimentos_div,economic_annex:cuadro_14:744a94962b4d73e447cb93ed,IPC alimentos y bebidas no alcohólicas,Resultado: bienes de frontera
ipc_vestido_div,economic_annex:cuadro_14:99ae18dcab4a9573cd1b207d,IPC prendas de vestir y calzado,Resultado: bienes de frontera
ipc_carne_vacuna,economic_annex:cuadro_16_a:b0212ed6375596572608dc92,IPC carne vacuna,Resultado: bien exportado a Argentina / arbitraje
imaep_original,economic_annex:cuadro_9:fc9a02c5dcc0573b3c038553,IMAEP serie original,Control / resultado agregado
", stringsAsFactors = FALSE, strip.white = TRUE)

con <- conectar()
bloques <- rbind(
  spec_por_hoja(con, "economic_annex", "Cuadro 52a", "impo_turismo_usd", "Importaciones uso interno y régimen de turismo (miles USD): canal de reexportación"),
  spec_por_hoja(con, "economic_annex", "Cuadro 54", "impo_regimen", "Importaciones por régimen aduanero (miles USD)"))
spec <- rbind(dicc, bloques)
x <- extraer_escalares(con, spec)
escribir_series(x, spec)
cerrar(con)

message("Episodios candidatos: meses con devaluación oficial argentina > 10%...")
ars <- x[x$serie == "ars_usd_prom", ]; ars <- ars[order(ars$fecha), ]
ars$dev_mensual_pct <- c(NA, 100 * diff(log(ars$valor)))
epi <- ars[!is.na(ars$dev_mensual_pct) & ars$dev_mensual_pct > 10 & ars$fecha >= as.Date("1995-01-01"),
           c("fecha", "valor", "dev_mensual_pct")]
names(epi)[2] <- "ars_por_usd"
epi$nota <- "Inferido de la serie oficial (FMI); no captura el tipo de cambio paralelo"
escribir_csv(epi, "episodios_devaluacion_argentina_inferidos.csv")

message("Comercio bilateral Paraguay-Argentina y Paraguay-Brasil (IMTS, FMI; fuera de la base)...")
f_imts <- file.path(RUTA_INPUT, "IMF_Data", "International Trade in Goods (by partner country) (IMTS).csv")
if (file.exists(f_imts)) {
  lin <- readLines(f_imts, encoding = "UTF-8", warn = FALSE)
  limpiar <- function(l) { l <- sub("^﻿", "", l); ifelse(grepl('^".*"$', l), gsub('""', '"', substr(l, 2, nchar(l) - 1)), l) }
  hdr <- scan(text = limpiar(lin[1]), what = "", sep = ",", quiet = TRUE)
  pry <- lin[grepl("Paraguay", lin, fixed = TRUE) & (grepl("Argentina", lin, fixed = TRUE) | grepl("Brazil", lin, fixed = TRUE))]
  tab <- utils::read.csv(text = limpiar(pry), header = FALSE, col.names = hdr, check.names = FALSE, colClasses = "character", na.strings = "")
  tab <- tab[tab$COUNTRY == "Paraguay" & tab$FREQUENCY == "Monthly" & tab$COUNTERPART_COUNTRY %in% c("Argentina", "Brazil") &
             grepl("^(Exports of goods|Imports of goods, Cost)", tab$INDICATOR), ]
  mcols <- grep("^[0-9]{4}-M[0-9]{2}$", names(tab), value = TRUE)
  imts <- do.call(rbind, lapply(mcols, function(k) {
    v <- suppressWarnings(as.numeric(tab[[k]])); ok <- !is.na(v); if (!any(ok)) return(NULL)
    data.frame(fecha = as.Date(paste0(substr(k, 1, 4), "-", substr(k, 7, 8), "-01")),
               flujo = ifelse(grepl("^Exports", tab$INDICATOR[ok]), "exportaciones_fob", "importaciones_cif"),
               socio = tab$COUNTERPART_COUNTRY[ok], valor_millones_usd = v[ok], codigo_fmi = tab$SERIES_CODE[ok])
  }))
  imts$nivel_verificacion <- "Fuera de la base (CSV FMI en input/current; sin parser ni validación)"
  escribir_csv(imts[order(imts$flujo, imts$socio, imts$fecha), ], "comercio_bilateral_imts.csv")
} else message("Aviso: no se encontró el archivo IMTS; se omite.")

ejemplo <- data.frame(
  fecha_evento = c("2014-01-23", "2015-12-17", "2018-04-25", "2018-08-30", "2019-08-12", "2019-09-01", "2023-08-14", "2023-12-13", "2025-04-14"),
  evento = c("Devaluación del peso oficial", "Fin del cepo y unificación cambiaria", "Inicio de la crisis cambiaria 2018",
             "Salto del tipo de cambio (crisis 2018)", "Shock posterior a las PASO", "Restablecimiento del cepo cambiario", "Devaluación posterior a las PASO 2023",
             "Devaluación del tipo de cambio oficial", "Flexibilización del cepo y régimen de bandas"),
  tipo = c("devaluacion", "liberalizacion", "devaluacion", "devaluacion", "devaluacion", "control_cambiario", "devaluacion", "devaluacion", "liberalizacion"),
  magnitud_aprox = "", fuente = "Memoria del analista (Claude); completar con BCRA/prensa",
  estado_verificacion = "no verificado", stringsAsFactors = FALSE)
message("Calendario de eventos cambiarios argentinos (manual; plantilla con candidatos NO verificados)...")
MANIFIESTO_BAK <- MANIFIESTO
leer_manual("eventos_argentina", c("fecha_evento", "evento", "tipo", "magnitud_aprox", "fuente", "estado_verificacion"), ejemplo)
m <- do.call(rbind, MANIFIESTO); m$generado <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
prev <- utils::read.csv(file.path(DIR_DATOS, "00_manifiesto.csv"), stringsAsFactors = FALSE)
m$esquema_base <- prev$esquema_base[1]; m$release_base <- prev$release_base[1]
utils::write.csv(m, file.path(DIR_DATOS, "00_manifiesto.csv"), row.names = FALSE, na = "", fileEncoding = "UTF-8")
