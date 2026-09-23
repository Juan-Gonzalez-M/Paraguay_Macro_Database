## Proyecto 28 · N7 (nuevo) — Medidas de alivio COVID, reprogramaciones y mora posterior
## Panel banco-mes con la cartera "Medida Excepcional COVID" (vigente y vencida), refinanciados,
## reestructurados, renovados, mora por sector, categorías de riesgo, previsiones y capital.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
imaep_original,economic_annex:cuadro_9:fc9a02c5dcc0573b3c038553,IMAEP serie original,Shock agregado (COVID)
imaep9a_desest,economic_annex:cuadro_9_a:b8f0c675b509f9ec047b421e,IMAEP serie ajustada,Shock agregado
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,Tasa de política monetaria,Control (política simultánea)
cred_priv_mn,economic_annex:cuadro_24a:066262e294293abfdf394a22,Crédito privado MN (agregado),Resultado agregado
cred_priv_me_usd,economic_annex:cuadro_24a:24d810aa73e2ae59ac1bd9b9,Crédito privado ME en millones de USD,Resultado agregado
pyg_usd_prom_venta,exchange_rates:usd_prom:190c4a9509f6c233bdc28928,PYG por USD promedio mensual,Conversión de cartera ME
", stringsAsFactors = FALSE, strip.white = TRUE)

con <- conectar()
x <- extraer_escalares(con, dicc)
escribir_series(x, dicc)

union <- function(a, b) sprintf("(SELECT * FROM %s UNION ALL BY NAME SELECT * FROM %s)", a, b)
car <- dbGetQuery(con, paste("SELECT source_id AS tipo_entidad, fecha, codigo_entidad, codigo_cuenta AS cuenta, codigo_moneda, importe AS importe_pyg FROM",
                             union("main.v_latest_raw_banks_carteras", "main.v_latest_raw_financial_carteras"), "ORDER BY 1,2,3,4,5"))
car <- fechas_panel(car); car$nivel_verificacion <- "Panel provisional"
escribir_csv(car, "panel_carteras_entidad_mes.csv")
sec <- dbGetQuery(con, paste("SELECT source_id AS tipo_entidad, fecha, codigo_entidad, codigo_moneda, actividad_destino_vs2 AS sector, cartera_vigente, cartera_vencida FROM",
                             union("main.v_latest_raw_banks_credito_sector", "main.v_latest_raw_financial_credito_sector"), "ORDER BY 1,2,3,4,5"))
sec <- fechas_panel(sec); sec$nivel_verificacion <- "Panel provisional"
escribir_csv(sec, "panel_credito_sector_entidad_mes.csv")
cat_r <- dbGetQuery(con, paste("SELECT source_id AS tipo_entidad, fecha, codigo_entidad, codigo_tipo_riesgo AS categoria_riesgo, total AS saldo FROM",
                               union("main.v_latest_raw_banks_categoria_creditos", "main.v_latest_raw_financial_categoria_creditos"), "ORDER BY 1,2,3,4"))
cat_r <- fechas_panel(cat_r); cat_r$nivel_verificacion <- "Panel provisional"
escribir_csv(cat_r, "panel_categoria_riesgo_entidad_mes.csv")
rat <- dbGetQuery(con, paste("SELECT source_id AS tipo_entidad, fecha, codigo_entidad, sub_rubro AS ratio, total AS valor FROM",
                             union("main.v_latest_raw_banks_ratios", "main.v_latest_raw_financial_ratios"), "ORDER BY 1,2,3,4"))
rat <- fechas_panel(rat); rat$nivel_verificacion <- "Panel provisional"
escribir_csv(rat, "panel_ratios_entidad_mes.csv")
ee <- dbGetQuery(con, paste("
  SELECT source_id AS tipo_entidad, fecha, entity_id, short_name AS entidad, semantic_rubro AS rubro, sub_rubro, codigo_moneda, importe AS importe_pyg
    FROM", union("main.v_banks_eeff_documented", "main.v_financial_eeff_documented"), "
   WHERE semantic_rubro IN ('1.4. Coloc. Netas','1.5. Productos Financ.','2.1. Depósitos','3.1. Capital Social','3.2. Reservas','3.3. Resultados Acum.','3.4. Utilidad del Ej.','7.1. Previsión del Ejercicio')
   ORDER BY 1,2,3,5,6,7"))
ee <- fechas_panel(ee); ee$nivel_verificacion <- "Panel provisional"
escribir_csv(ee, "panel_eeff_riesgo_entidad_mes.csv")
ent <- dbGetQuery(con, paste("SELECT DISTINCT entity_id, short_name AS entidad, legal_name AS razon_social, ownership_type AS propiedad FROM",
                             union("main.v_banks_eeff_documented", "main.v_financial_eeff_documented"), "ORDER BY 1"))
escribir_csv(ent, "entidades.csv", fecha_col = "none")

message("Medidas de alivio (manual)...")
leer_manual("medidas_alivio",
            c("fecha_vigencia", "fecha_fin", "norma", "tipo_medida", "alcance", "condiciones", "fuente", "estado_verificacion"))
cerrar(con)
