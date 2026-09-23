## Proyecto 31 · N10 (nuevo) — Precios administrados de combustibles, inflación y expectativas
## Ajustes discretos del gasoil y combustibles (Cuadros 13, 13 a, 15, 16) frente al petróleo,
## el tipo de cambio, la inflación subyacente y las expectativas de la EVE (mediana).

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
gasoil_indice,economic_annex:cuadro_13_a:0eb3cec8343b3ec1b1d753a7,Índice de precio del gasoil (Cuadro 13 a; el título del cuadro dice IPC empalmado),Tratamiento: precio administrado
gasoil_var_mensual,economic_annex:cuadro_13_a:b6f955a47c21f01d75920d18,Variación mensual del índice del gasoil (Cuadro 13 a),Tratamiento (variación)
ipc_combustibles_grupo,economic_annex:cuadro_16_cont:0165ca199b60a8673a541044,IPC transporte: combustibles y lubricantes (Cuadro 16),Primera etapa en el IPC
ipc_transporte_div,economic_annex:cuadro_14:31f35587c92c9fdb55e8c9f0,IPC división transporte,Traspaso directo
ipc_transporte_publico,economic_annex:cuadro_16_cont:f436277b9de09f562b1a8980,IPC transporte público y taxis,Traspaso indirecto (tarifas)
ipc_indice,economic_annex:cuadro_14:a5d7fc4139616340def083cc,IPC índice general,Resultado
ipc_var_mensual,economic_annex:cuadro_15:1720dedc33bdbea3951d2913,Inflación total mensual,Resultado
ipc_subyacente_mensual,economic_annex:cuadro_15:dfecdb75e556917955185f87,Inflación subyacente mensual,Resultado: segunda vuelta
ipcsae,economic_annex:cuadro_14_b:51ac506bc66449221b1c86ab,IPCSAE (sin alimentos ni energía),Resultado: segunda vuelta
ipc_bienes_alimenticios,economic_annex:cuadro_14_b:8af2fc023074afcb93ad5ee9,IPC bienes alimenticios,Resultado: costos de transporte de alimentos
eve_inf_mes,eve:bloque_de_inflacion:expectativa_del_mes,EVE (mediana): inflación esperada del mes,Resultado: expectativas corto plazo
eve_inf_prox_mes,eve:bloque_de_inflacion:expectativa_del_proximo_mes,EVE (mediana): inflación esperada próximo mes,Resultado: expectativas
eve_inf_anio_t,eve:bloque_de_inflacion:expectativa_ano_t,EVE (mediana): inflación esperada año t,Resultado: expectativas
eve_inf_12m,eve:bloque_de_inflacion:proximos_12_meses,EVE (mediana): inflación esperada 12 meses,Resultado: expectativas
eve_inf_24m,eve:bloque_de_inflacion:horizonte_de_politica_monetaria_proximos_24_meses,EVE (mediana): inflación esperada 24 meses,Resultado: anclaje
petroleo_brent,economic_annex:cuadro_49:e501920f72d07f6719ca5d85,Petróleo Brent USD/barril (mensual),Determinante del ajuste (función de reacción de Petropar)
pyg_usd_prom_venta,exchange_rates:usd_prom:190c4a9509f6c233bdc28928,PYG por USD promedio mensual,Determinante del ajuste
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,Tasa de política monetaria,Control
", stringsAsFactors = FALSE, strip.white = TRUE)

externos <- read.csv(text = "
serie,id,agregacion,unidad,descripcion,rol
brent_d,DCOILBRENTEU,,USD_PER_BARREL,FRED: petróleo Brent diario,Determinante diario del ajuste
", stringsAsFactors = FALSE, strip.white = TRUE, na.strings = "")

con <- conectar()
tar <- spec_por_hoja(con, "economic_annex", "CUADRO 13", "tarifa", "Índices de tarifas y precios regulados (etiquetas de la base cruzadas)")
spec <- rbind(dicc, tar)
x <- extraer_escalares(con, spec)
ext <- leer_fred_bloque(externos)
escribir_series(rbind(x, ext), rbind(spec[, c("serie", "descripcion", "rol")], externos[, c("serie", "descripcion", "rol")]))
cerrar(con)

message("Ajustes candidatos: meses con variación del índice del gasoil mayor a 3% en valor absoluto...")
g <- x[x$serie == "gasoil_indice", ]; g <- g[order(g$fecha), ]
g$var_pct <- c(NA, 100 * diff(log(g$valor)))
aj <- g[!is.na(g$var_pct) & abs(g$var_pct) > 3, c("fecha", "valor", "var_pct")]
names(aj)[2] <- "indice_gasoil"; aj$nota <- "Inferido (mensual); la fecha exacta del ajuste debe venir de Petropar"
escribir_csv(aj, "ajustes_gasoil_inferidos.csv")
leer_manual("ajustes_combustibles",
            c("fecha_vigencia", "producto", "empresa", "precio_anterior_gs_litro", "precio_nuevo_gs_litro", "fuente", "estado_verificacion"))
m <- do.call(rbind, MANIFIESTO); m$generado <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
prev <- utils::read.csv(file.path(DIR_DATOS, "00_manifiesto.csv"), stringsAsFactors = FALSE)
m$esquema_base <- prev$esquema_base[1]; m$release_base <- prev$release_base[1]
utils::write.csv(m, file.path(DIR_DATOS, "00_manifiesto.csv"), row.names = FALSE, na = "", fileEncoding = "UTF-8")
