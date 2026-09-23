## Proyecto 16 · E3 — Desacuerdo y anclaje de expectativas (versión agregada)
## EVE publica un solo estadístico por variable: la MEDIANA. No hay dispersión ni n.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
eve_inf_mes,eve:bloque_de_inflacion:expectativa_del_mes,EVE (mediana): inflación mensual esperada para el mes corriente,Expectativa de corto plazo
eve_inf_prox_mes,eve:bloque_de_inflacion:expectativa_del_proximo_mes,EVE (mediana): inflación mensual esperada para el próximo mes,Expectativa de corto plazo
eve_inf_anio_t,eve:bloque_de_inflacion:expectativa_ano_t,EVE (mediana): inflación esperada para diciembre del año t,Expectativa de horizonte fijo (fin de año)
eve_inf_anio_t1,eve:bloque_de_inflacion:expectativa_ano_t_1,EVE (mediana): inflación esperada para diciembre del año t+1,Expectativa de horizonte fijo (fin de año siguiente)
eve_inf_12m,eve:bloque_de_inflacion:proximos_12_meses,EVE (mediana): inflación esperada próximos 12 meses,Expectativa de horizonte móvil
eve_inf_24m,eve:bloque_de_inflacion:horizonte_de_politica_monetaria_proximos_24_meses,EVE (mediana): inflación esperada en el horizonte de política (24 meses),Variable central de anclaje (largo plazo)
eve_tpm_mes,eve:tasa_de_politica_monetaria_tpm:expectativa_del_mes,EVE (mediana): TPM esperada para el mes,Sorpresa de política
eve_tpm_prox_mes,eve:tasa_de_politica_monetaria_tpm:expectativa_del_proximo_mes,EVE (mediana): TPM esperada para el próximo mes,Sorpresa de política
eve_tpm_anio_t,eve:tasa_de_politica_monetaria_tpm:expectativa_ano_t,EVE (mediana): TPM esperada fin de año t,Trayectoria esperada de política
eve_tpm_anio_t1,eve:tasa_de_politica_monetaria_tpm:expectativa_ano_t_1,EVE (mediana): TPM esperada fin de año t+1,Trayectoria esperada de política
eve_pib_anio_t,eve:pib_variacion_porcentual_del_pib:expectativa_ano_t,EVE (mediana): crecimiento del PIB esperado año t,Expectativa de actividad
eve_pib_anio_t1,eve:pib_variacion_porcentual_del_pib:expectativa_ano_t_1,EVE (mediana): crecimiento del PIB esperado año t+1,Expectativa de actividad
eve_tc_mes,eve:tipo_de_cambio_nominal_usd:expectativa_del_mes,EVE (mediana): tipo de cambio esperado para el mes,Expectativa cambiaria
eve_tc_prox_mes,eve:tipo_de_cambio_nominal_usd:expectativa_del_proximo_mes,EVE (mediana): tipo de cambio esperado próximo mes,Expectativa cambiaria
eve_tc_anio_t,eve:tipo_de_cambio_nominal_usd:expectativa_ano_t,EVE (mediana): tipo de cambio esperado fin de año t,Expectativa cambiaria
eve_tc_anio_t1,eve:tipo_de_cambio_nominal_usd:expectativa_ano_t_1,EVE (mediana): tipo de cambio esperado fin de año t+1,Expectativa cambiaria
ipc_indice,economic_annex:cuadro_14:a5d7fc4139616340def083cc,IPC índice general (base dic-2017=100),Realización (para errores de pronóstico)
ipc_var_mensual,economic_annex:cuadro_15:1720dedc33bdbea3951d2913,Inflación total mensual,Realización / sorpresa de inflación
ipc_var_interanual,economic_annex:cuadro_15:080dbf95a46f3bcb97aeb69d,Inflación total interanual,Realización / sorpresa de inflación
ipc_subyacente_mensual,economic_annex:cuadro_15:dfecdb75e556917955185f87,Inflación subyacente mensual,Sorpresa de inflación subyacente
ipc_subyacente_interanual,economic_annex:cuadro_15:e2716d5d388cb5491db427df,Inflación subyacente interanual,Realización
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,Tasa de política monetaria (promedio del mes; etiqueta contaminada),Realización / sorpresa de política
pyg_usd_prom_venta,exchange_rates:usd_prom:190c4a9509f6c233bdc28928,PYG por USD promedio mensual (venta),Realización cambiaria
tcn_venta,tcn_referential_daily:tcn_referencial_daily:5fc9eaa0817a8a6ece9666c4,Tipo de cambio referencial diario (para el valor de fin de año),Realización cambiaria
pib_real_anual,economic_annex:cuadro_1:0a012e9b809e605737c253e0,PIB anual a precios de comprador (millones de Gs. constantes de 2014),Realización de crecimiento
pib_var_anual,economic_annex:cuadro_3:0a012e9b809e605737c253e0,Variación porcentual anual del PIB (Cuadro 3),Realización de crecimiento
icc,icc:icc,Índice de confianza del consumidor,Expectativas de hogares
iee,icc:iee,Índice de expectativas económicas (hogares),Expectativas de hogares
iee_pais,icc:iee_pais,Índice de expectativas económicas: país,Expectativas de hogares
iee_personal,icc:iee_personal,Índice de expectativas económicas: situación personal,Expectativas de hogares
sgc_general_expectativa,credit_survey:indices:4aef21c7a463e7fe8271158b,Situación General del Crédito: índice de expectativa general,Expectativas de empresas/bancos
sgc_consumo_expectativa,credit_survey:indices:1031a383bb2053a7e1771f56,Situación General del Crédito: expectativa consumo,Expectativas sectoriales
sgc_agricultura_expectativa,credit_survey:indices:6ad4dd35596ab6e51abab3bd,Situación General del Crédito: expectativa agricultura,Expectativas sectoriales
sgc_industria_expectativa,credit_survey:indices:bce41c36158e55cc008960e9,Situación General del Crédito: expectativa industria,Expectativas sectoriales
sgc_comercio_expectativa,credit_survey:indices:9f75946728a483594ded363f,Situación General del Crédito: expectativa comercio,Expectativas sectoriales
", stringsAsFactors = FALSE, strip.white = TRUE)

## Meta de inflación: NO está en la base. Registro manual con fechas aproximadas; verificar.
meta <- read.csv(text = "
vigencia_desde,meta_pct,rango_tolerancia_pp,fuente,estado
2011-05-01,5.0,2.5,Adopción formal de metas de inflación (BCP 2011),Registro manual: verificar fecha exacta y resolución
2014-12-01,4.5,2.0,Reducción anunciada por el BCP en diciembre de 2014,Registro manual: verificar fecha exacta y resolución
2017-03-01,4.0,2.0,Reducción anunciada por el BCP en 2017,Registro manual: verificar fecha exacta y resolución
2025-01-01,3.5,,Inferido: la mediana EVE a 24 meses pasa de 4.0% a 3.5% en enero de 2025,NO VERIFICADO: confirmar si hubo cambio de meta y su rango de tolerancia
", stringsAsFactors = FALSE, strip.white = TRUE)

con <- conectar()
x <- extraer_escalares(con, dicc)
escribir_series(x, dicc)
meta$vigencia_desde <- as.Date(meta$vigencia_desde)
escribir_csv(meta, "meta_inflacion_manual.csv", fecha_col = "vigencia_desde")
cerrar(con)
