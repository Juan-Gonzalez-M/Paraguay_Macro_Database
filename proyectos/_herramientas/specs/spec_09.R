## Proyecto 09 · D1 — ENSO no lineal y respuestas macroeconómicas
## Índices ENSO de NOAA (ONI, RONI, Niño 3.4 mensual) + actividad, PIB sectorial real,
## precios y volúmenes de exportación agrícola. Muestra mensual lo más larga posible.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
imaep_original,economic_annex:cuadro_9:fc9a02c5dcc0573b3c038553,IMAEP serie original (Cuadro 9; 1994-),Resultado principal (actividad total)
imaep_sin_agro_bin_original,economic_annex:cuadro_9:50676b58c0b150737790879f,IMAEP sin agricultura ni binacionales serie original (Cuadro 9; 1994-),Resultado: actividad no climática directa
imaep9a_original,economic_annex:cuadro_9_a:fd9298219967c6b520d1afff,IMAEP serie original (Cuadro 9 a; 2014-),Resultado (robustez)
imaep9a_desest,economic_annex:cuadro_9_a:b8f0c675b509f9ec047b421e,IMAEP serie ajustada (Cuadro 9 a),Resultado (robustez)
imaep9a_primario,economic_annex:cuadro_9_a:5916c3b35790deb8a40a6158,IMAEP sector primario serie original,Resultado sectorial
imaep9a_primario_desest,economic_annex:cuadro_9_a:94bcafb869036135a8363269,IMAEP sector primario serie ajustada,Resultado sectorial
imaep9a_secundario,economic_annex:cuadro_9_a:f868ee64d4b18f88eec7fe07,IMAEP sector secundario serie original,Resultado sectorial
imaep9a_manufactura,economic_annex:cuadro_9_a:4b20a71a70f3144f9e0b0355,IMAEP manufactura serie original,Resultado sectorial
imaep9a_servicios,economic_annex:cuadro_9_a:fd49e39d87802b129f360d7c,IMAEP servicios serie original,Resultado sectorial
imaep9a_sin_agro_bin,economic_annex:cuadro_9_a:8f84ed0f8814038ee0810d9e,IMAEP sin agricultura ni binacionales serie original (9 a),Resultado sectorial
pib_real,economic_annex:cuadro_6:6929f799551947bd2eb72b88,PIB trimestral a precios de comprador (millones de Gs. constantes de 2014),Resultado trimestral
pib_real_agricultura,economic_annex:cuadro_6:6d027c95b5cac6d53c10f8f0,PIB trimestral real: agricultura,Resultado sectorial trimestral
pib_real_ganaderia,economic_annex:cuadro_6:393a82900fdf35ef616c1419,PIB trimestral real: ganadería forestal pesca y minería,Resultado sectorial trimestral
pib_real_manufactura,economic_annex:cuadro_6:92c49007aa191278ef2a7c1f,PIB trimestral real: manufactura,Resultado sectorial trimestral
pib_real_electricidad_agua,economic_annex:cuadro_6:530f8e5f22d100df2b5c3a0c,PIB trimestral real: electricidad y agua (binacionales),Resultado sectorial (canal hídrico)
pib_real_construccion,economic_annex:cuadro_6:554e1192b3c7c926c3e3d4f6,PIB trimestral real: construcción,Resultado sectorial trimestral
pib_real_servicios,economic_annex:cuadro_6:eb584ca02fd165d0f293d6b0,PIB trimestral real: servicios,Resultado sectorial trimestral
ipc_indice,economic_annex:cuadro_14:a5d7fc4139616340def083cc,IPC índice general (base dic-2017=100),Resultado: inflación
ipc_var_mensual,economic_annex:cuadro_15:1720dedc33bdbea3951d2913,Inflación total mensual,Resultado: inflación
ipc_var_interanual,economic_annex:cuadro_15:080dbf95a46f3bcb97aeb69d,Inflación total interanual,Resultado: inflación
ipc_subyacente_mensual,economic_annex:cuadro_15:dfecdb75e556917955185f87,Inflación subyacente mensual,Resultado: inflación subyacente
ipc_frutas_verduras_indice,economic_annex:cuadro_15:73a3cd7f9a37d1bb3084868e,IPC frutas y verduras índice,Resultado: alimentos frescos
ipc_alimentos_indice,economic_annex:cuadro_14:744a94962b4d73e447cb93ed,IPC alimentación y bebidas no alcohólicas índice (Cuadro 14),Resultado: alimentos
ipc_bienes_alimenticios,economic_annex:cuadro_14_b:8af2fc023074afcb93ad5ee9,IPC bienes alimenticios índice (Cuadro 14 b),Resultado: alimentos
ipc_carnes,economic_annex:cuadro_16:3c8c2222c67a7c4df52b8cc0,IPC alimentación: carnes,Resultado: ganadería
ipc_vegetales_frescos,economic_annex:cuadro_16:3e4b4a5be0690c528a1a82b4,IPC alimentación: vegetales frescos,Resultado: alimentos frescos
ipc_frutas_frescas,economic_annex:cuadro_16:cfe9c5fec8a041d700450210,IPC alimentación: frutas frescas,Resultado: alimentos frescos
ipc_cereales,economic_annex:cuadro_16:4f788f5502dcb1d1526de81d,IPC alimentación: cereales y derivados,Resultado: alimentos
ipc_lacteos,economic_annex:cuadro_16:4cb3afa78d49d2d57974b398,IPC alimentación: productos lácteos,Resultado: alimentos
expo_ton_soja,economic_annex:cuadro_44b:7df4a507b9ac890a7e324938,Exportaciones de granos de soja (toneladas),Mecanismo: cosecha
expo_ton_maiz,economic_annex:cuadro_44b:5d75a4e3807ba33b30a10bce,Exportaciones de maíz (toneladas),Mecanismo: cosecha
expo_ton_trigo,economic_annex:cuadro_44b:e93c392753900bfd80c2bc36,Exportaciones de trigo (toneladas),Mecanismo: cosecha
expo_ton_arroz,economic_annex:cuadro_44b:3ebde32dc701c7eaf0697028,Exportaciones de arroz (toneladas),Mecanismo: cosecha
expo_ton_carne,economic_annex:cuadro_44b:fa15c1a2b381b6f4c3c0aabd,Exportaciones de carne (toneladas),Mecanismo: ganadería
expo_kwh_energia,economic_annex:cuadro_44b:bbf6a4dac429f3f977e36274,Exportaciones de energía eléctrica (miles de kWh),Mecanismo: hidrología
soja_chicago,economic_annex:cuadro_49:898153a96bc9fe9ece97e94b,Soja Chicago USD/t,Control global (precio)
maiz_chicago,economic_annex:cuadro_49:339fdc05049428df6c5c21c5,Maíz Chicago USD/t,Control global (precio)
trigo_chicago,economic_annex:cuadro_49:701a9b2812b6f3b613ace77a,Trigo Chicago USD/t,Control global (precio)
petroleo_brent,economic_annex:cuadro_49:e501920f72d07f6719ca5d85,Petróleo Brent USD/barril,Control global (costos)
pyg_usd_prom_venta,exchange_rates:usd_prom:190c4a9509f6c233bdc28928,PYG por USD promedio mensual (venta),Control / mecanismo cambiario
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,Tasa de política monetaria,Control (reacción de política)
eve_inflacion_anio_t,eve:bloque_de_inflacion:expectativa_ano_t,EVE (mediana): inflación esperada año t,Mecanismo: expectativas
", stringsAsFactors = FALSE, strip.white = TRUE)

externos <- read.csv(text = "
serie,id,agregacion,unidad,descripcion,rol
alimentos_indice_mundial,PFOODINDEXM,,INDEX,FRED/FMI: índice mundial de precios de alimentos,Control global parsimonioso
", stringsAsFactors = FALSE, strip.white = TRUE, na.strings = "")

dicc_enso <- read.csv(text = "
serie,descripcion,rol
oni,NOAA CPC: Oceanic Niño Index (anomalía Niño 3.4; media móvil 3 meses fechada en el mes central),Tratamiento: fase e intensidad ENSO
nino34_sst_3m,NOAA CPC: temperatura absoluta Niño 3.4 media móvil 3 meses,Índice alternativo
roni,NOAA CPC: ONI relativo (descuenta el calentamiento tropical medio),Índice alternativo (robustez)
nino34_anom_mensual,NOAA CPC: anomalía mensual Niño 3.4 (sstoi.indices; 1982-),Índice alternativo (mensual sin suavizar)
", stringsAsFactors = FALSE, strip.white = TRUE)

con <- conectar()
x <- extraer_escalares(con, dicc)
message("Descargando índices ENSO (NOAA) y controles (FRED)...")
enso <- rbind(leer_oni(), leer_roni(), leer_nino34_mensual())
ext <- leer_fred_bloque(externos)
escribir_series(rbind(x, enso, ext),
                rbind(dicc[, c("serie", "descripcion", "rol")], dicc_enso,
                      externos[, c("serie", "descripcion", "rol")]))
cerrar(con)
