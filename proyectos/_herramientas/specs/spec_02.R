## Proyecto 02 · B1 — Intervención cambiaria y eficacia en el mercado FX
## Cronología diaria de operaciones del BCP + tipo de cambio diario + controles globales diarios.
## El tipo compensatoria/complementaria solo existe en frecuencia mensual.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
bcp_compra_total_d,bcp_fx_daily:op_divisas_datos_diarios:10aa9337ca44858e6554071b,Compra diaria de divisas del BCP: total,Tratamiento (compras)
bcp_compra_financiero_d,bcp_fx_daily:op_divisas_datos_diarios:17b3daf11066d8eac5808be7,Compra diaria del BCP al sector financiero,Tratamiento (mercado)
bcp_compra_publico_d,bcp_fx_daily:op_divisas_datos_diarios:299c6815e8c66c366cbda661,Compra diaria del BCP al sector público,Operación con el Tesoro (no intervención de mercado)
bcp_venta_total_d,bcp_fx_daily:op_divisas_datos_diarios:2e11e6bedf4350e619bbfcb6,Venta diaria de divisas del BCP: total,Tratamiento (ventas)
bcp_venta_financiero_d,bcp_fx_daily:op_divisas_datos_diarios:b074d786fee864b2efd438e0,Venta diaria del BCP al sector financiero,Tratamiento principal (intervención vendedora)
bcp_venta_publico_d,bcp_fx_daily:op_divisas_datos_diarios:fc1b68ba4459ed6c42b6f1d6,Venta diaria del BCP al sector público,Operación con el Tesoro
bcp_neto_financiero_d,bcp_fx_daily:op_divisas_datos_diarios:5aa4e7262dee69adde87a3ae,Compras netas diarias del BCP al sector financiero,Tratamiento neto (mercado)
bcp_neto_publico_d,bcp_fx_daily:op_divisas_datos_diarios:3c951804d5e93c97589a95e2,Compras netas diarias del BCP al sector público,Control / separación de propósito
bcp_neto_total_d,bcp_fx_daily:op_divisas_datos_diarios:542ac0ab6cb137a1139018b2,Compras netas diarias (público + financiero),Tratamiento agregado
bcp_acum_financiero_d,bcp_fx_daily:op_divisas_datos_diarios:b26a6ad2b9ed04e5fb4eedea,Compras netas acumuladas en el año: sector financiero,Verificación contable
bcp_acum_publico_d,bcp_fx_daily:op_divisas_datos_diarios:0957433db1b1c1cef39b7c41,Compras netas acumuladas en el año: sector público,Verificación contable
bcp_acum_total_d,bcp_fx_daily:op_divisas_datos_diarios:1167218c0c4db02d98be2ed4,Compras netas acumuladas en el año: total,Verificación contable
tcn_venta,tcn_referential_daily:tcn_referencial_daily:5fc9eaa0817a8a6ece9666c4,Tipo de cambio referencial PYG/USD venta,Resultado: retorno volatilidad y colas
tcn_compra,tcn_referential_daily:tcn_referencial_daily:a07f02c9c6cdd8a96698da73,Tipo de cambio referencial PYG/USD compra,Resultado (spread compra-venta)
ventas_compensatorias_m,compensatory_fx_sales:ventas_datos_mensuales:c5abc5cf41acb9b12b8f31e9,Ventas compensatorias del BCP (mensual),Tipo de operación
ventas_complementarias_m,compensatory_fx_sales:ventas_datos_mensuales:0e0e199377b87e46849e6139,Ventas complementarias del BCP (mensual),Tipo de operación
ventas_total_m,compensatory_fx_sales:ventas_datos_mensuales:0fd68cdb8f1812280c93a9ad,Ventas compensatorias + complementarias (mensual),Tipo de operación
opfx_neto_total_m,fx_operations:total:net:monthly,Histórico de operaciones cambiarias: neto total (mensual),Conciliación diario-mensual
opfx_neto_financiero_m,fx_operations:financial_sector:net:monthly,Histórico: neto con el sector financiero,Conciliación
opfx_compra_financiero_m,fx_operations:financial_sector:purchase:monthly,Histórico: compras al sector financiero,Conciliación
opfx_venta_financiero_m,fx_operations:financial_sector:sale:monthly,Histórico: ventas al sector financiero,Conciliación
opfx_neto_publico_m,fx_operations:public_sector:net:monthly,Histórico: neto con el sector público,Conciliación
opfx_neto_otras_m,fx_operations:other_operations:net:monthly,Histórico: otras operaciones netas,Conciliación
wpfxi_spot_publicada_m,imf_wpfxi:10e00f53f001282b9e50d09e,FMI WPFXI: intervención spot publicada (millones USD),Comparación internacional
wpfxi_spot_proxy_m,imf_wpfxi:8b185691c34db8c15397616c,FMI WPFXI: intervención spot aproximada (millones USD),Comparación internacional
wpfxi_total_proxy_pib_m,imf_wpfxi:20486b9d339444e69a5fce8b,FMI WPFXI: intervención total aproximada (% del PIB promedio 3 años),Comparación internacional
wpfxi_esterilizacion_m,imf_wpfxi:73f747cafa97abff0ec62a59,FMI WPFXI: dummy de esterilización,Metadato de esterilización
pyg_usd_prom_venta,exchange_rates:usd_prom:190c4a9509f6c233bdc28928,PYG por USD promedio mensual (venta),Resultado mensual
rin_saldo,economic_annex:cuadro_56b:f51d08d7995561bfce2166eb,Reservas internacionales netas,Capacidad de intervención
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,Tasa de política monetaria,Control
pyg_brl,economic_annex:cuadro_60a:2442b69bab143106463ed144,PYG por BRL (mensual),Control regional
pyg_ars,economic_annex:cuadro_60a:2758fed7ea57c524cd0fcb0c,PYG por ARS (mensual),Control regional
soja_chicago,economic_annex:cuadro_49:898153a96bc9fe9ece97e94b,Soja Chicago USD/t (mensual),Control de flujos de exportación
eve_tc_mes,eve:tipo_de_cambio_nominal_usd:expectativa_del_mes,EVE (mediana): tipo de cambio esperado para el mes,Presión esperada
fwd_compra_no_residentes,economic_annex:cuadro_61:a4179a572dd9040aec144cae,Compras forward a no residentes (volumen mensual),Presión de no residentes
fwd_venta_no_residentes,economic_annex:cuadro_61:bf1f329e3e81fc731e430c55,Ventas forward a no residentes (volumen mensual),Presión de no residentes
", stringsAsFactors = FALSE, strip.white = TRUE)

dicc_ev <- read.csv(text = "
serie,candidate_id,descripcion,rol
call_usd_tasa_prom,interbank_market:datos:b577ca875b5a111a7232aa45,Call money USD: tasa promedio diaria,Liquidez en dólares (control)
call_usd_monto,interbank_market:datos:8995dee2b2f1ae20e56458ea,Call money USD: monto diario,Liquidez en dólares (control)
", stringsAsFactors = FALSE, strip.white = TRUE)

externos <- read.csv(text = "
serie,id,agregacion,unidad,descripcion,rol
dolar_amplio_d,DTWEXBGS,,INDEX,FRED: índice nominal amplio del dólar (diario),Control global diario
vix_d,VIXCLS,,INDEX_POINTS,FRED: VIX diario,Control global diario (riesgo)
brl_usd_d,DEXBZUS,,BRL_PER_USD,FRED: BRL por USD diario,Control regional diario
ust_2a_d,DGS2,,PERCENT,FRED: rendimiento Tesoro EE.UU. 2 años (diario),Control global diario (tasas)
", stringsAsFactors = FALSE, strip.white = TRUE, na.strings = "")

con <- conectar()
x <- extraer_escalares(con, dicc)
y <- extraer_eventos_diarios(con, dicc_ev)
ext <- leer_fred_bloque(externos)
escribir_series(rbind(x, y, ext), rbind(dicc[, c("serie", "descripcion", "rol")],
                                          dicc_ev[, c("serie", "descripcion", "rol")],
                                          externos[, c("serie", "descripcion", "rol")]))
cerrar(con)
