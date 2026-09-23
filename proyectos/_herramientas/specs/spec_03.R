## Proyecto 03 · B2 — Marco multi-horizonte del guaraní-dólar
## Archivo de datos por frecuencia (diario y mensual) para ECM/BEER, BVAR y evaluación
## recursiva frente al random walk. EVE = mediana de la encuesta.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
pyg_usd_prom_venta,exchange_rates:usd_prom:190c4a9509f6c233bdc28928,PYG por USD: promedio mensual del mercado fluctuante (venta),Variable dependiente (mensual)
pyg_usd_prom_compra,exchange_rates:usd_prom:005b085ac773ce425557eb28,PYG por USD: promedio mensual (compra),Robustez / spread compra-venta
tcr_multilateral,economic_annex:cuadro_60b:cda2955982d3c374c57fbb42,Tipo de cambio real multilateral (ene-1995=100),Desalineamiento (BEER)
tcr_usa,economic_annex:cuadro_60c:5ce712fc868d221501a03e51,Tipo de cambio real bilateral con EE.UU.,Desalineamiento bilateral
tcr_brasil,economic_annex:cuadro_60c:df5674f2dacbbc4d470c3175,Tipo de cambio real bilateral con Brasil,Canal regional
tcr_argentina,economic_annex:cuadro_60c:8ec28511cf3e35f6d413c26f,Tipo de cambio real bilateral con Argentina,Canal regional
tcn_multilateral_idx,economic_annex:cuadro_60b:7b8ad5b369d2399deef2c09b,Índice de tipo de cambio nominal multilateral (Cuadro 60b),Descomposición TCR
ipe_multilateral,economic_annex:cuadro_60b:a8e4175ddd00562d16ff5898,Índice de precios externos (socios comerciales),Precios relativos
pyg_brl,economic_annex:cuadro_60a:2442b69bab143106463ed144,PYG por BRL (Cuadro 60a),Canal regional
pyg_ars,economic_annex:cuadro_60a:2758fed7ea57c524cd0fcb0c,PYG por ARS (Cuadro 60a),Canal regional
pyg_eur,economic_annex:cuadro_60a:9b265b8246f1c6383a14d886,PYG por EUR (Cuadro 60a),Dólar global (cruce)
ipc_indice,economic_annex:cuadro_14:a5d7fc4139616340def083cc,IPC índice general (base dic-2017=100),Precios relativos (nivel)
ipc_var_interanual,economic_annex:cuadro_15:080dbf95a46f3bcb97aeb69d,Inflación total interanual,Inflación relativa
ipc_subyacente_interanual,economic_annex:cuadro_15:e2716d5d388cb5491db427df,Inflación subyacente interanual,Inflación relativa
imaep_original,economic_annex:cuadro_9:fc9a02c5dcc0573b3c038553,IMAEP serie original (Cuadro 9 1994-),Actividad
imaep_desest,economic_annex:cuadro_9_a:b8f0c675b509f9ec047b421e,IMAEP serie ajustada (Cuadro 9 a 2014-),Actividad (robustez)
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,Tasa de política monetaria (etiqueta contaminada en la base),Diferencial de tasas
tasa_pasiva_cda_me,economic_annex:cuadro_31_cont:471798dff0fbf8cce6e28cce,Tasa efectiva pasiva CDA en moneda extranjera,Diferencial de tasas en USD
tasa_activa_me,economic_annex:cuadro_31_cont:eaf763baa29bd5845926073b,Tasa efectiva activa ME promedio ponderado,Diferencial de tasas en USD
fed_rango_inferior,financial_indicators:x8:6525e9b20e3a11458bb7714f,Fed funds: límite inferior del rango (hoja 8),Tasa externa
fed_rango_superior,financial_indicators:x8:c6e9b9ddaec363c3e89b538d,Fed funds: límite superior del rango (hoja 8),Tasa externa
selic,financial_indicators:x8:66dac7933b59a1b55c19f938,Tasa Selic (hoja 8),Tasa regional
expo_totales,economic_annex:cuadro_43:9698b36b4c7f01c050f61d76,Exportaciones totales (miles USD FOB),Comercio / flujos
expo_registradas,economic_annex:cuadro_46a:c53d182b059f53899aef8f2a,Exportaciones registradas total (Cuadro 46a),Comercio / flujos
impo_totales,economic_annex:cuadro_43:d8ea1faf82e60f77ca4709dd,Importaciones totales (miles USD FOB),Comercio / flujos
saldo_comercial,economic_annex:cuadro_43:f51d08d7995561bfce2166eb,Saldo de la balanza de bienes,Comercio / flujos
soja_chicago,economic_annex:cuadro_49:898153a96bc9fe9ece97e94b,Soja Chicago USD/t,Términos de intercambio
harina_soja,economic_annex:cuadro_49:bf5bd1aed67803e8f3f424b1,Harina de soja Chicago USD/t,Términos de intercambio
aceite_soja,economic_annex:cuadro_49:dd0453e90037927ad7dde0d5,Aceite de soja Chicago USD/t,Términos de intercambio
maiz_chicago,economic_annex:cuadro_49:339fdc05049428df6c5c21c5,Maíz Chicago USD/t,Términos de intercambio
carne_chicago,economic_annex:cuadro_49:6e6364e656bb4f80ee31dff8,Carne Chicago USD/t,Términos de intercambio
petroleo_brent,economic_annex:cuadro_49:e501920f72d07f6719ca5d85,Petróleo Brent USD/barril,Términos de intercambio (importaciones)
ctot_expo_pry,imf_ctot:a1bfab2f0d7ba20791d31063,FMI: índice de precios de commodities exportados por Paraguay (pesos móviles),Términos de intercambio
ctot_neto_pry,imf_ctot:dd3feb041b21f3efab7ab0bb,FMI: índice de precios netos de commodities (exportaciones netas),Términos de intercambio
reer_fmi,imf_eer:14b72845146207a1978f035d,FMI: tipo de cambio real efectivo (2010=100),Robustez del TCR
brl_usd_prom,imf_er:13f5f115b7431dbad5fcb4b6,FMI: BRL por USD promedio mensual,Canal regional
ars_usd_prom,imf_er:c45a0a7edaa90b29d3564005,FMI: ARS por USD promedio mensual,Canal regional
ipc_brasil,imf_cpi:ba03fe4dcdde13d15e4126f3,FMI: IPC Brasil índice,Inflación relativa
ipc_argentina,imf_cpi:e3b883567e33f043224c1a88,FMI: IPC Argentina índice (desde dic-2016),Inflación relativa
tpm_argentina,imf_mfs_ir:0ea7d6c5d48ac4a212348a2b,FMI: tasa de política Argentina,Tasa regional
rin_saldo,economic_annex:cuadro_56b:f51d08d7995561bfce2166eb,Reservas internacionales netas,Colchón de reservas
bcp_fx_neto_total_m,economic_annex:cuadro_20:7b59d8ba436a0b3c68fb07fd,Operaciones cambiarias netas totales del BCP (mensual),Intervención (control)
ventas_compensatorias_total,compensatory_fx_sales:ventas_datos_mensuales:0fd68cdb8f1812280c93a9ad,Ventas compensatorias + complementarias del BCP,Intervención (control)
fwd_compra_total,economic_annex:cuadro_61:c1e3d7c587159be995288eee,Mercado local: compras forward totales (volumen),Presión / cobertura
fwd_venta_total,economic_annex:cuadro_61:d964d9000ef92ca9b9bdd9a1,Mercado local: ventas forward totales (volumen),Presión / cobertura
fwd_compra_no_residentes,economic_annex:cuadro_61:a4179a572dd9040aec144cae,Compras forward a no residentes,Presión / cobertura
fwd_venta_no_residentes,economic_annex:cuadro_61:bf1f329e3e81fc731e430c55,Ventas forward a no residentes,Presión / cobertura
spot_compra_total,economic_annex:cuadro_61:a3b2890dba5a4ba594eafb7b,Mercado local: compras spot y efectivo,Volumen del mercado
spot_venta_total,economic_annex:cuadro_61:62cb82b68264179b4cf5bef7,Mercado local: ventas spot y efectivo,Volumen del mercado
eve_tc_mes,eve:tipo_de_cambio_nominal_usd:expectativa_del_mes,EVE (mediana): tipo de cambio esperado para el mes,Expectativas
eve_tc_prox_mes,eve:tipo_de_cambio_nominal_usd:expectativa_del_proximo_mes,EVE (mediana): tipo de cambio esperado próximo mes,Expectativas
eve_tc_anio_t,eve:tipo_de_cambio_nominal_usd:expectativa_ano_t,EVE (mediana): tipo de cambio esperado fin de año t,Expectativas (horizonte 12m)
eve_tc_anio_t1,eve:tipo_de_cambio_nominal_usd:expectativa_ano_t_1,EVE (mediana): tipo de cambio esperado fin de año t+1,Expectativas (horizonte 24m)
eve_inflacion_anio_t,eve:bloque_de_inflacion:expectativa_ano_t,EVE (mediana): inflación esperada año t,Expectativas
tcn_venta,tcn_referential_daily:tcn_referencial_daily:5fc9eaa0817a8a6ece9666c4,Tipo de cambio referencial diario PYG/USD venta,Variable dependiente (diaria)
tcn_compra,tcn_referential_daily:tcn_referencial_daily:a07f02c9c6cdd8a96698da73,Tipo de cambio referencial diario PYG/USD compra,Robustez
bcp_fx_neto_total_d,bcp_fx_daily:op_divisas_datos_diarios:542ac0ab6cb137a1139018b2,Compras netas diarias del BCP (sector público + financiero),Intervención diaria (control)
bcp_fx_neto_financiero_d,bcp_fx_daily:op_divisas_datos_diarios:5aa4e7262dee69adde87a3ae,Compras netas diarias del BCP al sector financiero,Intervención diaria (control)
", stringsAsFactors = FALSE, strip.white = TRUE)

externos <- read.csv(text = "
serie,id,agregacion,unidad,descripcion,rol
dolar_amplio_m,TWEXBGSMTH,,INDEX,FRED: índice nominal amplio del dólar (Fed; ene-2006=100),Dólar global (mensual)
dolar_amplio_historico_m,TWEXBMTH,,INDEX,FRED: índice amplio del dólar anterior (1973-2019; discontinuado),Dólar global (historia larga)
dolar_amplio_d,DTWEXBGS,,INDEX,FRED: índice nominal amplio del dólar diario,Dólar global (diario)
vix_m,VIXCLS,avg,INDEX_POINTS,FRED: VIX promedio mensual,Aversión al riesgo
vix_d,VIXCLS,,INDEX_POINTS,FRED: VIX diario,Aversión al riesgo (diario)
brl_usd_d,DEXBZUS,,BRL_PER_USD,FRED: BRL por USD diario (Fed H.10),Canal regional diario
fed_funds_efectiva,FEDFUNDS,,PERCENT,FRED: tasa efectiva de fondos federales,Tasa externa (historia larga)
ust_2a,DGS2,avg,PERCENT,FRED: rendimiento Tesoro EE.UU. 2 años (promedio mensual),Tasa externa
ust_10a,DGS10,avg,PERCENT,FRED: rendimiento Tesoro EE.UU. 10 años (promedio mensual),Tasa externa
ipc_eeuu,CPIAUCSL,,INDEX,FRED: IPC de EE.UU. (desestacionalizado),Inflación relativa
commodities_indice,PALLFNFINDEXM,,INDEX,FRED/FMI: índice de precios de todas las commodities,Términos de intercambio
alimentos_indice,PFOODINDEXM,,INDEX,FRED/FMI: índice de precios de alimentos,Términos de intercambio
", stringsAsFactors = FALSE, strip.white = TRUE, na.strings = "")

con <- conectar()
message("Extrayendo series de la base...")
x <- extraer_escalares(con, dicc)
message("Descargando variables globales de FRED...")
ext <- leer_fred_bloque(externos)
escribir_series(rbind(x, ext), rbind(dicc[, c("serie", "descripcion", "rol")],
                                     externos[, c("serie", "descripcion", "rol")]))
cerrar(con)
