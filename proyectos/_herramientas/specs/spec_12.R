## Proyecto 12 · D4 — Inflación climática, precios relativos y riesgo de cola
## Componentes del IPC (headline, alimentos, subyacente, transables, administrados, grupos),
## precios al productor, expectativas EVE (mediana), precios mundiales y ENSO (NOAA).

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
ipc_indice,economic_annex:cuadro_14:a5d7fc4139616340def083cc,IPC índice general (base dic-2017=100),Resultado: headline (nivel)
ipc_alimentos_div,economic_annex:cuadro_14:744a94962b4d73e447cb93ed,IPC alimentación y bebidas no alcohólicas (Cuadro 14),Componente que carga el efecto
ipc_bienes_alimenticios,economic_annex:cuadro_14_b:8af2fc023074afcb93ad5ee9,IPC bienes alimenticios (índice),Componente: alimentos
ipc_alimenticios_sin_fyv,economic_annex:cuadro_14_b:bca046f33bc09e8c57fbc832,IPC bienes alimenticios sin frutas y verduras,Componente: alimentos procesados
ipc_sin_alimentos,economic_annex:cuadro_14_b:7322f9d55a73329aaf3ce74d,IPC sin alimentos,Componente
ipcsae,economic_annex:cuadro_14_b:51ac506bc66449221b1c86ab,IPCSAE (sin alimentos ni energía),Núcleo alternativo (no controlar por alimentos)
ipc_sin_alim_comb_tarif,economic_annex:cuadro_14_b:ab458e86db5132b2311595e4,IPC sin alimentos combustibles ni tarifados,Núcleo alternativo
ipc_servicios,economic_annex:cuadro_14_b:b4951083ce1d33a5c7c4d94b,IPC servicios,Componente sticky
ipc_total_bienes,economic_annex:cuadro_14_b:b50f5e050a7ce09373d58545,IPC total de bienes,Componente flexible
ipc_transables_sin_fyv,economic_annex:cuadro_14_a:1f5d8129468fa2246f4ef067,IPC transables sin frutas y verduras,Tradables (canal FX)
ipc_no_transables,economic_annex:cuadro_14_a:14eda4efc6655f8715834492,IPC no transables,No tradables
ipc_importados_sin_fyv,economic_annex:cuadro_14_a:907533be614b9497d5409ff9,IPC productos importados sin frutas y verduras,Canal FX
ipc_nacionales,economic_annex:cuadro_14_a:9288e17840a5058852512941,IPC productos nacionales,Canal doméstico
ipc_bienes_libres,economic_annex:cuadro_14_c:144017bee83415e50913bbb9,IPC bienes libres,Flexibles
ipc_administrados,economic_annex:cuadro_14_c:d8ff2b8f227bff316782777e,IPC bienes y servicios administrados,Precios regulados (excluir en robustez)
eve_inf_mes,eve:bloque_de_inflacion:expectativa_del_mes,EVE (mediana): inflación esperada del mes,Expectativas (densidad aproximada / sorpresa)
eve_inf_anio_t,eve:bloque_de_inflacion:expectativa_ano_t,EVE (mediana): inflación esperada año t,Expectativas
eve_inf_12m,eve:bloque_de_inflacion:proximos_12_meses,EVE (mediana): inflación esperada 12 meses,Benchmark para pronóstico de densidad
eve_inf_24m,eve:bloque_de_inflacion:horizonte_de_politica_monetaria_proximos_24_meses,EVE (mediana): inflación esperada 24 meses,Anclaje
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,Tasa de política monetaria,Control (reacción; no inferir política óptima)
pyg_usd_prom_venta,exchange_rates:usd_prom:190c4a9509f6c233bdc28928,PYG por USD promedio mensual,Canal FX
soja_chicago,economic_annex:cuadro_49:898153a96bc9fe9ece97e94b,Soja Chicago USD/t,Precio mundial agrícola
maiz_chicago,economic_annex:cuadro_49:339fdc05049428df6c5c21c5,Maíz Chicago USD/t,Precio mundial agrícola
trigo_chicago,economic_annex:cuadro_49:701a9b2812b6f3b613ace77a,Trigo Chicago USD/t,Precio mundial agrícola (pan)
carne_chicago,economic_annex:cuadro_49:6e6364e656bb4f80ee31dff8,Carne Chicago USD/t,Precio mundial (carne)
petroleo_brent,economic_annex:cuadro_49:e501920f72d07f6719ca5d85,Petróleo Brent USD/barril,Costos energéticos
", stringsAsFactors = FALSE, strip.white = TRUE)

externos <- read.csv(text = "
serie,id,agregacion,unidad,descripcion,rol
alimentos_indice_mundial,PFOODINDEXM,,INDEX,FRED/FMI: índice mundial de precios de alimentos,Global food (nivel suficiente)
commodities_indice,PALLFNFINDEXM,,INDEX,FRED/FMI: índice de todas las commodities,Control global
", stringsAsFactors = FALSE, strip.white = TRUE, na.strings = "")

dicc_enso <- read.csv(text = "
serie,descripcion,rol
oni,NOAA CPC: Oceanic Niño Index (media móvil 3 meses; mes central),Tratamiento: ENSO
nino34_sst_3m,NOAA CPC: temperatura absoluta Niño 3.4 media móvil 3 meses,Índice alternativo
roni,NOAA CPC: ONI relativo,Índice alternativo
nino34_anom_mensual,NOAA CPC: anomalía mensual Niño 3.4 (1982-),Índice alternativo mensual
", stringsAsFactors = FALSE, strip.white = TRUE)

con <- conectar()
bloques <- rbind(
  spec_por_hoja(con, "economic_annex", "CUADRO 15", "ipc15", "IPC: total, subyacente, frutas y verduras, combustibles, tarifados (índices y variaciones)"),
  spec_por_hoja(con, "economic_annex", "CUADRO 16", "ipc_grupo", "IPC por grupo de gasto (alimentos, vivienda, vestido)"),
  spec_por_hoja(con, "economic_annex", "CUADRO 17", "ipp", "Índice de precios del productor (base mar-2025)"))
spec <- rbind(dicc, bloques)
x <- extraer_escalares(con, spec)
message("Descargando ENSO (NOAA) y precios mundiales (FRED)...")
enso <- rbind(leer_oni(), leer_roni(), leer_nino34_mensual())
ext <- leer_fred_bloque(externos)
escribir_series(rbind(x, enso, ext),
                rbind(spec[, c("serie", "descripcion", "rol")], dicc_enso, externos[, c("serie", "descripcion", "rol")]))
cerrar(con)
