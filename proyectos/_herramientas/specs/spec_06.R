## Proyecto 06 · C2 — Depósitos, crédito y sustitución entre intermediarios
## Versión bancaria (bancos + financieras). Las cooperativas solo existen como agregado
## Tipo A del Anexo (2017-12 a 2025-11). Paneles completos por acuerdo de la Fase 1.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,Tasa de política monetaria (etiqueta contaminada en la base),Tratamiento: política monetaria
eve_tpm_mes,eve:tasa_de_politica_monetaria_tpm:expectativa_del_mes,EVE (mediana): TPM esperada para el mes,Sorpresa de política (TPM − esperada)
eve_tpm_prox_mes,eve:tasa_de_politica_monetaria_tpm:expectativa_del_proximo_mes,EVE (mediana): TPM esperada para el próximo mes,Sorpresa de política
ipc_var_interanual,economic_annex:cuadro_15:080dbf95a46f3bcb97aeb69d,Inflación total interanual,Control / tasas reales
c31_mn_pasiva_vista,economic_annex:cuadro_31:4cf5c9315d0ce4a1ccef0be2,Tasa efectiva pasiva MN a la vista (etiqueta contaminada),Precio del fondeo MN
c31_mn_pasiva_plazo,economic_annex:cuadro_31:aacfa4b95b892d3d761fdc06,Tasa efectiva pasiva MN a plazo (etiqueta contaminada),Precio del fondeo MN
c31_mn_pasiva_cda,economic_annex:cuadro_31:c2b248d54ebd174566d7c4bb,Tasa efectiva pasiva MN CDA (etiqueta contaminada),Precio del fondeo MN
c31_mn_pasiva_prom,economic_annex:cuadro_31:6ff03d8f79fc15937b18bab3,Tasa efectiva pasiva MN promedio ponderado (etiqueta contaminada),Precio del fondeo MN
c31_mn_activa_prom,economic_annex:cuadro_31:c90c5c9c2ec39acfaed4ff16,Tasa efectiva activa MN promedio ponderado sin tarjetas ni sobregiros (etiqueta contaminada),Precio del crédito MN
c31_me_pasiva_vista,economic_annex:cuadro_31_cont:55464b82ce76371bfa534f0b,Tasa efectiva pasiva ME a la vista,Precio del fondeo ME
c31_me_pasiva_plazo,economic_annex:cuadro_31_cont:170f1e2a628c1df46041835a,Tasa efectiva pasiva ME a plazo,Precio del fondeo ME
c31_me_pasiva_cda,economic_annex:cuadro_31_cont:471798dff0fbf8cce6e28cce,Tasa efectiva pasiva ME CDA,Precio del fondeo ME
c31_me_activa_prom,economic_annex:cuadro_31_cont:eaf763baa29bd5845926073b,Tasa efectiva activa ME promedio ponderado,Precio del crédito ME
dep_priv_mn_ctacte,economic_annex:cuadro_23a:cb884bce6a9707e5dbb37c81,Depósitos del sector privado MN: cuenta corriente,Cantidad de fondeo MN
dep_priv_mn_vista,economic_annex:cuadro_23a:82319ba269b30cfdbab2067c,Depósitos del sector privado MN: ahorro a la vista,Cantidad de fondeo MN
dep_priv_mn_plazo,economic_annex:cuadro_23a:eccf9463ea3b632825f0794e,Depósitos del sector privado MN: ahorro a plazo,Cantidad de fondeo MN
dep_priv_mn_cds,economic_annex:cuadro_23a:2352af509e2f2e05b140ed28,Depósitos del sector privado MN: CDs,Cantidad de fondeo MN
dep_priv_mn_total,economic_annex:cuadro_23a:4f4afb1454f1954045984105,Depósitos del sector privado MN: total,Cantidad de fondeo MN
dep_priv_me_ctacte,economic_annex:cuadro_23a:804e1eca1f3c07b3e4bfbf36,Depósitos del sector privado ME: cuenta corriente (millones de Gs.),Cantidad de fondeo ME
dep_priv_me_vista,economic_annex:cuadro_23a:7d80399f2fa437bc4d8b57ae,Depósitos del sector privado ME: ahorro a la vista (millones de Gs.),Cantidad de fondeo ME
dep_priv_me_plazo,economic_annex:cuadro_23a:ad70fdcb5e239a9b628799d3,Depósitos del sector privado ME: ahorro a plazo (millones de Gs.),Cantidad de fondeo ME
dep_priv_me_cds,economic_annex:cuadro_23a:fe9364b07027333baada5b5c,Depósitos del sector privado ME: CDs (millones de Gs.),Cantidad de fondeo ME
dep_priv_me_total,economic_annex:cuadro_23a:9183bbd87440955f3c4f61c3,Depósitos del sector privado ME: total (millones de Gs.),Cantidad de fondeo ME
dep_priv_me_total_usd,economic_annex:cuadro_23a:6665dcbd306238301a26a70e,Depósitos del sector privado ME: total en millones de USD,Cantidad de fondeo ME
dep_priv_tc,economic_annex:cuadro_23a:1d322c15f735fa600e48ca44,Tipo de cambio usado en el Cuadro 23a,Conversión
dep_priv_part_me,economic_annex:cuadro_23a:322c9ae3c660f49040467fce,Participación de ME en depósitos privados (%),Dolarización de depósitos
cred_priv_mn,economic_annex:cuadro_24a:066262e294293abfdf394a22,Crédito de bancos y financieras al sector privado MN,Resultado: crédito
cred_priv_me,economic_annex:cuadro_24a:068827fc3ff258bf18368305,Crédito al sector privado ME (millones de Gs.),Resultado: crédito
cred_priv_me_usd,economic_annex:cuadro_24a:24d810aa73e2ae59ac1bd9b9,Crédito al sector privado ME en millones de USD,Resultado: crédito
cred_priv_total,economic_annex:cuadro_24a:5a78850a2552c99415f492b7,Crédito al sector privado total,Resultado: crédito
cred_priv_part_me,economic_annex:cuadro_24a:c634f2fdb01f30ade67b492f,Participación de ME en el crédito privado (%),Dolarización del crédito
coop_dep_mn,economic_annex:cuadro_23b:38654549fa309beab0d7e0a1,Cooperativas Tipo A: depósitos MN (millones de Gs.),Sustitución hacia cooperativas
coop_dep_me,economic_annex:cuadro_23b:ec4c1dd789977ba80e59f08f,Cooperativas Tipo A: depósitos ME (millones de Gs.; la base agrega '%' a la etiqueta por error),Sustitución hacia cooperativas
coop_dep_total,economic_annex:cuadro_23b:80c098e04abaf5e13c44a170,Cooperativas Tipo A: depósitos totales (millones de Gs.; la base agrega '%' a la etiqueta por error),Sustitución hacia cooperativas
coop_cred_mn,economic_annex:cuadro_24b:38654549fa309beab0d7e0a1,Cooperativas Tipo A: créditos MN (millones de Gs.),Sustitución hacia cooperativas
coop_cred_me,economic_annex:cuadro_24b:ec4c1dd789977ba80e59f08f,Cooperativas Tipo A: créditos ME (millones de Gs.; la base agrega '%' a la etiqueta por error),Sustitución hacia cooperativas
coop_cred_total,economic_annex:cuadro_24b:be297d9734c362490e962fee,Cooperativas Tipo A: créditos totales (millones de Gs.; la base agrega '%' a la etiqueta por error),Sustitución hacia cooperativas
bancariz_cuentas_total,banking_indicators:x4:b7c61f0017b4715c0c5e76d1,Cantidad total de cuentas de depósito,Base de depositantes
bancariz_personas_total,banking_indicators:x4:7ff2948c9a61b9002fc4e336,Personas con cuentas de depósito,Base de depositantes
bancariz_cuentas_cda,banking_indicators:x6:a3c072d200353eb9f96d52b4,Cantidad de cuentas a plazo (CDA),Base de depositantes
bancariz_cuentas_vista,banking_indicators:x6:5c69cbe60916bd8c73130eb9,Cantidad de cuentas a la vista,Base de depositantes
", stringsAsFactors = FALSE, strip.white = TRUE)

con <- conectar()
message("Tasas por producto, plazo y moneda (Indicadores Financieros, bancos y financieras)...")
tasas <- rbind(
  spec_por_hoja(con, "financial_indicators", "1.2", "tef_bancos", "Precio por producto y moneda (bancos; promedio del sistema)"),
  spec_por_hoja(con, "financial_indicators", "2.2", "tef_plazo_bancos", "Precio por producto, plazo y moneda (bancos)"),
  spec_por_hoja(con, "financial_indicators", "5", "tef_financieras", "Precio por producto y moneda (financieras)"),
  spec_por_hoja(con, "financial_indicators", "6", "tef_plazo_financieras", "Precio por producto y plazo (financieras)"),
  spec_por_hoja(con, "financial_indicators", "4", "saldos_bancos", "Cantidades por producto y plazo (bancos)"),
  spec_por_hoja(con, "financial_indicators", "7", "saldos_financieras", "Cantidades por producto y plazo (financieras)"))
spec <- rbind(dicc, tasas)
x <- extraer_escalares(con, spec)
escribir_series(x, spec)

message("Curva de CDA por plazo (tasas y volúmenes)...")
escribir_csv(extraer_curvas(con, "cda_curve"), "curvas_cda_mensual.csv")

message("Paneles completos entidad-mes (bancos y financieras)...")
eeff <- dbGetQuery(con, "
  SELECT source_id AS tipo_entidad, fecha, entity_id, short_name AS entidad, ownership_type AS propiedad,
         semantic_classification AS clase, semantic_rubro AS rubro, sub_rubro, codigo_moneda,
         currency_of_origin AS moneda_origen, importe AS importe_pyg
    FROM (SELECT * FROM main.v_banks_eeff_documented UNION ALL BY NAME SELECT * FROM main.v_financial_eeff_documented)
   ORDER BY tipo_entidad, fecha, entity_id, clase, rubro, sub_rubro, codigo_moneda")
eeff <- fechas_panel(eeff); eeff$nivel_verificacion <- "Panel provisional"
escribir_csv(eeff, "panel_eeff_entidad_mes.csv")
car <- dbGetQuery(con, "
  SELECT source_id AS tipo_entidad, fecha, codigo_entidad, codigo_cuenta AS cuenta, codigo_moneda, importe AS importe_pyg
    FROM (SELECT * FROM main.v_latest_raw_banks_carteras UNION ALL BY NAME SELECT * FROM main.v_latest_raw_financial_carteras)
   ORDER BY 1,2,3,4,5")
car <- fechas_panel(car); car$nivel_verificacion <- "Panel provisional"
escribir_csv(car, "panel_carteras_entidad_mes.csv")
sec <- dbGetQuery(con, "
  SELECT source_id AS tipo_entidad, fecha, codigo_entidad, codigo_moneda, actividad_destino_vs2 AS sector,
         cartera_vigente, cartera_vencida
    FROM (SELECT * FROM main.v_latest_raw_banks_credito_sector UNION ALL BY NAME SELECT * FROM main.v_latest_raw_financial_credito_sector)
   ORDER BY 1,2,3,4,5")
sec <- fechas_panel(sec); sec$nivel_verificacion <- "Panel provisional"
escribir_csv(sec, "panel_credito_sector_entidad_mes.csv")
rat <- dbGetQuery(con, "
  SELECT source_id AS tipo_entidad, fecha, codigo_entidad, sub_rubro AS ratio, total AS valor
    FROM (SELECT * FROM main.v_latest_raw_banks_ratios UNION ALL BY NAME SELECT * FROM main.v_latest_raw_financial_ratios)
   ORDER BY 1,2,3,4")
rat <- fechas_panel(rat); rat$nivel_verificacion <- "Panel provisional"
escribir_csv(rat, "panel_ratios_entidad_mes.csv")
ent <- dbGetQuery(con, "SELECT DISTINCT entity_id, short_name AS entidad, legal_name AS razon_social, ownership_type AS propiedad
                          FROM (SELECT * FROM main.v_banks_eeff_documented UNION ALL BY NAME SELECT * FROM main.v_financial_eeff_documented)
                         ORDER BY 1")
escribir_csv(ent, "entidades.csv", fecha_col = "none")
cerrar(con)
