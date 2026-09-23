## Proyecto 01 · A1 — Demanda de reservas y huella de liquidez de operaciones FX
## "Reservas" = reservas de los bancos en el BCP (encaje + cuenta corriente);
## las reservas internacionales entran solo como control.

ea <- "economic_annex:"
dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,Tasa de política monetaria (promedio del mes; etiqueta de la base contaminada),Política: nivel del corredor
fpl_tasa,economic_annex:cuadro_19:fc0d3e91762b1e49e7c60de2,Facilidad permanente de liquidez: tasa promedio ponderada,Techo del corredor
fpl_monto,economic_annex:cuadro_19:fe22911e7e25fb577e0e11aa,Facilidad permanente de liquidez: monto promedio,Uso de facilidades (resultado)
fpd_tasa,economic_annex:cuadro_19:3f0cf05cf3e314e3723dc6d9,Facilidad permanente de depósito: tasa promedio ponderada,Piso del corredor
fpd_monto,economic_annex:cuadro_19:a4c28f3ee786b7b8bee93995,Facilidad permanente de depósito: monto promedio,Uso de facilidades (resultado)
tib_mensual,economic_annex:cuadro_19:b3cda7014d948e51eb7adc50,Tasa interbancaria promedio del mes,Resultado: spread TIB - TPM
irm_colocado_7_53d,economic_annex:cuadro_19:f46fbf29ee24ff2db287707c,IRM: monto colocado 7-53 días,Esterilización
irm_colocado_54_105d,economic_annex:cuadro_19:c8db7cd5afebbea97ba012b6,IRM: monto colocado 54-105 días,Esterilización
irm_colocado_106_213d,economic_annex:cuadro_19:fea38bcbc4f4dfa6f67bcdfc,IRM: monto colocado 106-213 días,Esterilización
irm_colocado_214_455d,economic_annex:cuadro_19:3f5aa0a18be3af2c4ee78163,IRM: monto colocado 214-455 días,Esterilización
irm_colocado_456_728d,economic_annex:cuadro_19:47af8c31cfe1c6ae89ddaef5,IRM: monto colocado 456-728 días,Esterilización
irm_colocado_total,economic_annex:cuadro_19:57803c7f7ce6878c1ad0b5b3,IRM: total colocado en el mes (etiqueta contaminada con '456 a 728'),Esterilización (flujo)
irm_saldo,economic_annex:cuadro_19:c6b004df42fbf4677d7e4272,IRM: saldo a fin de mes (etiqueta contaminada con '456 a 728'),Esterilización (stock)
irm_rend_ponderado,economic_annex:cuadro_19:e026b8621200b0bd86ff8222,IRM: rendimiento promedio ponderado % (la base marca escala 'millions' por error),Costo de esterilización
irm_tasa_7_53d,economic_annex:cuadro_19:d2df2aa861a714464e439e44,IRM: tasa 7-53 días,Curva corta del BCP
irm_tasa_54_105d,economic_annex:cuadro_19:e6f771bffc66a1526cba9eed,IRM: tasa 54-105 días,Curva corta del BCP
irm_tasa_106_213d,economic_annex:cuadro_19:a756f870544a4cf0005bd461,IRM: tasa 106-213 días,Curva corta del BCP
irm_tasa_214_455d,economic_annex:cuadro_19:1a1cd1fa97e8e3b688c5c497,IRM: tasa 214-455 días,Curva corta del BCP
irm_tasa_456_728d,economic_annex:cuadro_19:889ec3ea7088fbd5b663f56e,IRM: tasa 456-728 días,Curva corta del BCP
bancos_encaje_mn,economic_annex:cuadro_27:1c63a4cb41004337fa196728,Depósitos de bancos en el BCP: encaje legal MN,Reservas bancarias (variable central)
bancos_encaje_me,economic_annex:cuadro_27:00327fb5cb588d371dfa5379,Depósitos de bancos en el BCP: encaje legal ME (en millones de Gs.; unidad no resuelta en la base),Reservas bancarias ME
bancos_ctacte_mn,economic_annex:cuadro_27:c8a9b0c71e4e66dff210d94c,Depósitos de bancos en el BCP: cuenta corriente MN,Reservas excedentes (variable central)
bancos_ctacte_me,economic_annex:cuadro_27:17b0fa4f4c476d7cf768bbaf,Depósitos de bancos en el BCP: cuenta corriente ME,Reservas excedentes ME
resto_sf_encaje_mn,economic_annex:cuadro_27:b22847132af352e8fd9e57ec,Depósitos del resto del sistema financiero en el BCP: encaje MN,Reservas (financieras)
resto_sf_encaje_me,economic_annex:cuadro_27:b202b7449603e63a65af83e3,Depósitos del resto del sistema financiero en el BCP: encaje ME,Reservas (financieras)
resto_sf_obligaciones,economic_annex:cuadro_27:83385b03bdfd86661a319f9a,Depósitos del resto del sistema financiero: obligaciones con el resto,Reservas (financieras)
credito_bcp_bancos,economic_annex:cuadro_27:478091b79252bf99eec909f3,Crédito del BCP al sistema bancario,Provisión de liquidez
credito_bcp_resto_sf,economic_annex:cuadro_27:851b0f5e17a793cd3951ef01,Crédito del BCP al resto del sistema financiero,Provisión de liquidez
posicion_neta_resto_sf,economic_annex:cuadro_27:4c4b3b766a26ed2641495d72,Posición neta del BCP con el resto del sistema financiero,Provisión de liquidez
base_monetaria,economic_annex:cuadro_21:2bf58454c90affb85cd6091b,Base monetaria,Identidad de liquidez
billetes_monedas,economic_annex:cuadro_21:b8ce2b9f8e9025fdccf7e5f5,M0: billetes y monedas en circulación,Identidad de liquidez (demanda de efectivo)
dep_adm_central_bcp,economic_annex:cuadro_35:f907a1e096fb65a973d56cf0,Depósitos de la Administración Central en el BCP (total),Flujos del Tesoro (proxy)
gasto_remun_irm,economic_annex:cuadro_26:2df5f0d344b919a22c820b55,Gasto de política monetaria: remuneración por IRM,Costo de esterilización
gasto_remun_encaje_mn,economic_annex:cuadro_26:a5a0376103c224b5640c8773,Gasto de política monetaria: remuneración del encaje MN,Costo de reservas
bcp_fx_neto_total_m,economic_annex:cuadro_20:7b59d8ba436a0b3c68fb07fd,Operaciones cambiarias netas totales del BCP (mensual),Liquidez inyectada por FX
bcp_fx_neto_financiero_m,economic_annex:cuadro_20:00f3d90c3b3a0f40d972cfe1,Operaciones cambiarias netas del BCP con el sector financiero,Liquidez inyectada por FX
bcp_fx_neto_publico_m,economic_annex:cuadro_20:b19650e61d3f12d0e70674cb,Operaciones cambiarias netas del BCP con el sector público,Liquidez (Tesoro)
rin_saldo,economic_annex:cuadro_56b:f51d08d7995561bfce2166eb,Reservas internacionales netas: saldo,Control (no es la variable central)
sipap_interbancario_pyg_monto,payments:sipap_01:a972cb808e07f638f05bee72,LBTR: transferencias entre entidades financieras PYG (importe),Actividad de pagos interbancarios
sipap_interbancario_pyg_cant,payments:sipap_01:f97c57c61e9dc5e9d2695802,LBTR: transferencias entre entidades financieras PYG (cantidad),Actividad de pagos interbancarios
bcp_fx_compra_total_d,bcp_fx_daily:op_divisas_datos_diarios:10aa9337ca44858e6554071b,Compra diaria de divisas del BCP: total,Shock de liquidez FX (diario)
bcp_fx_venta_total_d,bcp_fx_daily:op_divisas_datos_diarios:2e11e6bedf4350e619bbfcb6,Venta diaria de divisas del BCP: total,Shock de liquidez FX (diario)
bcp_fx_neto_financiero_d,bcp_fx_daily:op_divisas_datos_diarios:5aa4e7262dee69adde87a3ae,Compras netas diarias del BCP al sector financiero,Shock de liquidez FX (diario)
bcp_fx_neto_publico_d,bcp_fx_daily:op_divisas_datos_diarios:3c951804d5e93c97589a95e2,Compras netas diarias del BCP al sector público,Liquidez del Tesoro (diario)
bcp_fx_neto_total_d,bcp_fx_daily:op_divisas_datos_diarios:542ac0ab6cb137a1139018b2,Compras netas diarias sector público + financiero,Shock de liquidez FX (diario)
tcn_venta,tcn_referential_daily:tcn_referencial_daily:5fc9eaa0817a8a6ece9666c4,Tipo de cambio referencial PYG/USD venta,Control
", stringsAsFactors = FALSE, strip.white = TRUE)

dicc_ev <- read.csv(text = "
serie,candidate_id,descripcion,rol
tib_d_tasa_prom,interbank_market:datos:bcc5aacb9d75d1afe2f27ed0,Mercado interbancario PYG (call + REPO interbancario + tripartito): tasa promedio,Resultado: spread diario
tib_d_tasa_min,interbank_market:datos:cc59a9e40de39ee404db9395,Mercado interbancario PYG: tasa mínima,Dispersión
tib_d_tasa_max,interbank_market:datos:45e90acb61692b08c4ef5759,Mercado interbancario PYG: tasa máxima,Dispersión
tib_d_monto,interbank_market:datos:4a607dcf6c954a30f3f2375f,Mercado interbancario PYG: monto,Cantidad negociada
tib_d_n_operaciones,interbank_market:datos:472fa025e457e48e8f66943d,Mercado interbancario PYG: número de transacciones,Actividad
tib_d_n_participantes,interbank_market:datos:8d272da5a2fbde144388aaad,Mercado interbancario PYG: número de participantes,Actividad
repo_interb_tasa_prom,interbank_market:datos:f9593693ffd0590725b89ee7,REPO interbancario PYG: tasa promedio,Componente
repo_interb_monto,interbank_market:datos:3747989b3ad1abc7e90e4f97,REPO interbancario PYG: monto,Componente
repo_tripart_tasa_prom,interbank_market:datos:31c1e4c711ef0c3cb2bbc6cd,REPO tripartito PYG: tasa promedio,Componente
repo_tripart_monto,interbank_market:datos:e735507ac65fe95be57a044b,REPO tripartito PYG: monto VLI (millones Gs.),Componente
call_usd_tasa_prom,interbank_market:datos:b577ca875b5a111a7232aa45,Call money USD: tasa promedio,Liquidez en dólares
call_usd_monto,interbank_market:datos:8995dee2b2f1ae20e56458ea,Call money USD: monto,Liquidez en dólares
fpl_d_tasa,interbank_market:datos:54054828ef6167893989ed71,FPL: tasa diaria,Techo del corredor (diario)
fpl_d_tasa_tramo1,interbank_market:datos:d00478f1dc4bc808934a2e86,FPL primer tramo: tasa,Techo del corredor (diario)
fpl_d_tasa_tramo2,interbank_market:datos:f212c5ee88afeb1f0e6fb205,FPL segundo tramo: tasa,Techo del corredor (diario)
fpd_d_tasa,interbank_market:datos:22e19406c0223e679659af0d,FPD: tasa diaria,Piso del corredor (diario)
fpd_d_monto,interbank_market:datos:26b14fc2ce33fb5cbbfeb095,FPD: monto adjudicado (millones Gs.),Uso de facilidades (diario)
haircut,interbank_market:datos:c9a24050123f53f41de2158e,Coeficiente de cobertura (haircut),Regla de colateral
", stringsAsFactors = FALSE, strip.white = TRUE)

con <- conectar()
message("Extrayendo series escalares...")
x <- extraer_escalares(con, dicc)
message("Extrayendo series diarias del mercado interbancario...")
y <- extraer_eventos_diarios(con, dicc_ev)
escribir_series(rbind(x, y), rbind(dicc, dicc_ev))

message("Eventos: subastas de LRM y facilidad de liquidez de corto plazo...")
ev <- dbGetQuery(con, "
  SELECT CAST(reference_period_start AS DATE) AS fecha, source_id AS fuente, source_sheet AS hoja,
         full_series_path AS detalle, researcher_name AS variable, value AS valor, unit_code AS unidad,
         validation_tier, candidate_id, source_row
    FROM explore.events WHERE source_id IN ('lrm_auctions', 'liquidity_facility')
   ORDER BY source_id, reference_period_start, candidate_id")
ev$nivel_verificacion <- nivel_verificacion(ev$validation_tier, NA); ev$validation_tier <- NULL
escribir_csv(ev[ev$fuente == "lrm_auctions", ], "eventos_subastas_lrm.csv")
escribir_csv(ev[ev$fuente == "liquidity_facility", ], "eventos_facilidad_liquidez.csv")

message("Panel banco/financiera-mes: posiciones con el BCP, liquidez y depósitos...")
pan <- dbGetQuery(con, "
  SELECT source_id AS tipo_entidad, fecha, entity_id, short_name AS entidad,
         semantic_rubro AS rubro, sub_rubro, codigo_moneda, currency_of_origin AS moneda_origen,
         importe AS importe_pyg
    FROM (SELECT * FROM main.v_banks_eeff_documented UNION ALL BY NAME
          SELECT * FROM main.v_financial_eeff_documented)
   WHERE semantic_rubro IN ('1.1. Caja y Bancos','1.2. BCP - Activo','1.3. Inv. en Valores','1.4. Coloc. Netas',
                            '2.1. Depósitos','2.3. BCP - Pasivo','2.5. Interbancarios')
   ORDER BY tipo_entidad, fecha, entity_id, rubro, sub_rubro, codigo_moneda")
pan <- fechas_panel(pan); pan$nivel_verificacion <- "Panel provisional"
escribir_csv(pan, "panel_eeff_liquidez_entidad_mes.csv")
rat <- dbGetQuery(con, "
  SELECT source_id AS tipo_entidad, fecha, codigo_entidad, sub_rubro AS ratio, total AS valor
    FROM (SELECT * FROM main.v_latest_raw_banks_ratios UNION ALL BY NAME SELECT * FROM main.v_latest_raw_financial_ratios)
   WHERE sub_rubro IN ('Disponible + Inversiones Temporales/Depósitos','Disponible + Inversiones Temporales/Pasivos',
                       'Cartera Vencida/Cartera Total - Morosidad','Relación entre TIER 1/ACPR')
   ORDER BY 1,2,3,4")
rat <- fechas_panel(rat); rat$nivel_verificacion <- "Panel provisional"
escribir_csv(rat, "panel_ratios_liquidez_entidad_mes.csv")
cerrar(con)
