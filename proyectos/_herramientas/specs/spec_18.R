## Proyecto 18 · F2 — Precios de importación, arbitraje fronterizo e inflación
## Importaciones por tipo de bien en USD y toneladas (valores unitarios), por régimen y origen;
## IPC de importados/nacionales/transables; tipos de cambio bilaterales; IPC de vecinos;
## comercio por país socio del FMI (IMTS), leído del CSV en input/current porque no está en la base.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
ipc_indice,economic_annex:cuadro_14:a5d7fc4139616340def083cc,IPC índice general (base dic-2017=100),Resultado: IPC
ipc_importados_sin_fyv,economic_annex:cuadro_14_a:907533be614b9497d5409ff9,IPC productos importados sin frutas y verduras,Resultado principal: precio al consumidor de importados
ipc_nacionales,economic_annex:cuadro_14_a:9288e17840a5058852512941,IPC productos nacionales,Comparación (no importados)
ipc_transables_sin_fyv,economic_annex:cuadro_14_a:1f5d8129468fa2246f4ef067,IPC transables sin frutas y verduras,Tradables
ipc_no_transables,economic_annex:cuadro_14_a:14eda4efc6655f8715834492,IPC no transables,Placebo (no transables)
ipc_div_alimentos,economic_annex:cuadro_14:744a94962b4d73e447cb93ed,IPC alimentación y bebidas no alcohólicas,Canasta con comercio fronterizo
ipc_div_vestido,economic_annex:cuadro_14:99ae18dcab4a9573cd1b207d,IPC prendas de vestir y calzado,Canasta con comercio fronterizo
ipc_div_muebles_hogar,economic_annex:cuadro_14:056f3ae122fe939e87e00dee,IPC muebles y artículos para el hogar,Durables importados
ipc_div_transporte,economic_annex:cuadro_14:31f35587c92c9fdb55e8c9f0,IPC transporte (combustibles y vehículos),Energía importada
ipp_importados,economic_annex:cuadro_17:9f1ee570d547e79ead6674bc,Índice de precios al productor: productos importados,Etapa previa al consumidor
pyg_usd_prom_venta,exchange_rates:usd_prom:190c4a9509f6c233bdc28928,PYG por USD promedio mensual,Tipo de cambio dólar (moneda de factura dominante)
pyg_brl,economic_annex:cuadro_60a:2442b69bab143106463ed144,PYG por BRL,Tipo de cambio bilateral Brasil
pyg_ars,economic_annex:cuadro_60a:2758fed7ea57c524cd0fcb0c,PYG por ARS,Tipo de cambio bilateral Argentina (gap fronterizo)
tcr_brasil,economic_annex:cuadro_60c:df5674f2dacbbc4d470c3175,Tipo de cambio real bilateral Brasil,Gap de precios relativos con Brasil
tcr_argentina,economic_annex:cuadro_60c:8ec28511cf3e35f6d413c26f,Tipo de cambio real bilateral Argentina,Gap de precios relativos con Argentina
tcr_multilateral,economic_annex:cuadro_60b:cda2955982d3c374c57fbb42,Tipo de cambio real multilateral,Control
ipc_brasil,imf_cpi:ba03fe4dcdde13d15e4126f3,FMI: IPC Brasil índice,Precios del vecino
ipc_argentina,imf_cpi:e3b883567e33f043224c1a88,FMI: IPC Argentina índice (desde dic-2016),Precios del vecino
petroleo_brent,economic_annex:cuadro_49:e501920f72d07f6719ca5d85,Petróleo Brent USD/barril,Costo de importación de combustibles
", stringsAsFactors = FALSE, strip.white = TRUE)

externos <- read.csv(text = "
serie,id,agregacion,unidad,descripcion,rol
dolar_amplio_m,TWEXBGSMTH,,INDEX,FRED: índice nominal amplio del dólar,Canal de moneda dominante
ipc_eeuu,CPIAUCSL,,INDEX,FRED: IPC de EE.UU.,Precios en la moneda de factura
", stringsAsFactors = FALSE, strip.white = TRUE, na.strings = "")

con <- conectar()
bloques <- rbind(
  spec_por_hoja(con, "economic_annex", "Cuadro 51a", "impo_tipo_usd", "Importaciones por tipo de bien (miles USD FOB)"),
  spec_por_hoja(con, "economic_annex", "Cuadro 51b", "impo_tipo_ton", "Importaciones por tipo de bien (toneladas)"),
  spec_por_hoja(con, "economic_annex", "Cuadro 53a", "impo_proc_usd", "Importaciones por nivel de procesamiento (miles USD FOB)"),
  spec_por_hoja(con, "economic_annex", "Cuadro 53b", "impo_proc_ton", "Importaciones por nivel de procesamiento (toneladas)"),
  spec_por_hoja(con, "economic_annex", "Cuadro 52a", "impo_turismo_usd", "Importaciones uso interno y régimen de turismo (miles USD) — reexportación/frontera"),
  spec_por_hoja(con, "economic_annex", "Cuadro 52b", "impo_turismo_ton", "Importaciones uso interno y régimen de turismo (toneladas)"),
  spec_por_hoja(con, "economic_annex", "Cuadro 50", "impo_origen", "Importaciones por origen (miles USD)"),
  spec_por_hoja(con, "economic_annex", "Cuadro 54", "impo_regimen", "Importaciones por régimen aduanero (miles USD)"))
spec <- rbind(dicc, bloques)
x <- extraer_escalares(con, spec)
ext <- leer_fred_bloque(externos)
escribir_series(rbind(x, ext), rbind(spec[, c("serie", "descripcion", "rol")], externos[, c("serie", "descripcion", "rol")]))
cerrar(con)

## ---- IMTS (FMI): comercio de Paraguay por país socio, mensual. Fuera de la base. ----
message("Leyendo IMTS (FMI) desde input/current/IMF_Data ...")
f_imts <- file.path(RUTA_INPUT, "IMF_Data", "International Trade in Goods (by partner country) (IMTS).csv")
if (!file.exists(f_imts)) stop("No se encuentra el archivo IMTS: ", f_imts)
lin <- readLines(f_imts, encoding = "UTF-8", warn = FALSE)
limpiar <- function(l) { l <- sub("^﻿", "", l); ifelse(grepl('^".*"$', l), gsub('""', '"', substr(l, 2, nchar(l) - 1)), l) }
hdr <- scan(text = limpiar(lin[1]), what = "", sep = ",", quiet = TRUE)
pry <- lin[grepl('Paraguay', lin, fixed = TRUE)]
tab <- utils::read.csv(text = limpiar(pry), header = FALSE, col.names = hdr, check.names = FALSE,
                       colClasses = "character", na.strings = "")
tab <- tab[tab$COUNTRY == "Paraguay" & tab$FREQUENCY == "Monthly" &
           tab$INDICATOR %in% c("Exports of goods, Free on board (FOB), US dollar",
                                "Imports of goods, Cost insurance freight (CIF), US dollar",
                                "Imports of goods, Free on board (FOB), US dollar"), ]
mcols <- grep("^[0-9]{4}-M[0-9]{2}$", names(tab), value = TRUE)
largo <- do.call(rbind, lapply(mcols, function(k) {
  v <- suppressWarnings(as.numeric(tab[[k]])); ok <- !is.na(v)
  if (!any(ok)) return(NULL)
  data.frame(fecha = as.Date(paste0(substr(k, 1, 4), "-", substr(k, 7, 8), "-01")),
             flujo = ifelse(grepl("^Exports", tab$INDICATOR[ok]), "exportaciones_fob",
                            ifelse(grepl("CIF", tab$INDICATOR[ok]), "importaciones_cif", "importaciones_fob")),
             socio = tab$COUNTERPART_COUNTRY[ok], valor_millones_usd = v[ok], codigo_fmi = tab$SERIES_CODE[ok],
             stringsAsFactors = FALSE)
}))
largo <- largo[order(largo$flujo, largo$socio, largo$fecha), ]
largo$nivel_verificacion <- "Fuera de la base (CSV FMI en input/current; sin parser ni validación)"
escribir_csv(largo, "comercio_por_socio_imts_mensual.csv")

m <- do.call(rbind, MANIFIESTO); m$generado <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
prev <- utils::read.csv(file.path(DIR_DATOS, "00_manifiesto.csv"), stringsAsFactors = FALSE)
m$esquema_base <- prev$esquema_base[1]; m$release_base <- prev$release_base[1]
utils::write.csv(m, file.path(DIR_DATOS, "00_manifiesto.csv"), row.names = FALSE, na = "", fileEncoding = "UTF-8")
message("Listo: IMTS agregado al manifiesto.")
