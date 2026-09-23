## Proyecto 13 · D5 — Clima y riesgo de crédito
## Panel banco-sector-mes (cartera vigente/vencida por sector y cultivo, por moneda), ratios de
## mora, capital y provisiones por entidad, ENSO (NOAA), actividad agropecuaria y seguros agrícolas.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
imaep9a_primario,economic_annex:cuadro_9_a:5916c3b35790deb8a40a6158,IMAEP sector primario serie original (2014-),Canal: cash flow agropecuario
imaep_original,economic_annex:cuadro_9:fc9a02c5dcc0573b3c038553,IMAEP serie original (1994-),Control de actividad
pib_real_agricultura,economic_annex:cuadro_6:6d027c95b5cac6d53c10f8f0,PIB trimestral real: agricultura,Canal: cash flow agrícola
pib_real_ganaderia,economic_annex:cuadro_6:393a82900fdf35ef616c1419,PIB trimestral real: ganadería forestal pesca y minería,Canal: cash flow ganadero
expo_ton_soja,economic_annex:cuadro_44b:7df4a507b9ac890a7e324938,Exportaciones de granos de soja (toneladas),Canal: cosecha
expo_ton_maiz,economic_annex:cuadro_44b:5d75a4e3807ba33b30a10bce,Exportaciones de maíz (toneladas),Canal: cosecha
expo_ton_carne,economic_annex:cuadro_44b:fa15c1a2b381b6f4c3c0aabd,Exportaciones de carne (toneladas),Canal: ganadería
soja_chicago,economic_annex:cuadro_49:898153a96bc9fe9ece97e94b,Soja Chicago USD/t,Control: precio (separar de cantidad)
carne_chicago,economic_annex:cuadro_49:6e6364e656bb4f80ee31dff8,Carne Chicago USD/t,Control: precio
pyg_usd_prom_venta,exchange_rates:usd_prom:190c4a9509f6c233bdc28928,PYG por USD promedio mensual,Control: valuación de cartera en ME
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,Tasa de política monetaria,Control
seg_agro_primas,insurance_annex:x1_1:ff55a6c00710090a73dc7791,Seguros: primas directas rama agropecuaria (anual),Canal: seguro
seg_agro_siniestros,insurance_annex:x1_8:312741d02a53dcd17a3f6bc0,Seguros: siniestros directos rama agropecuaria (anual),Resultado: pérdidas aseguradas por clima
seg_agro_recupero_siniestros,insurance_annex:x1_16:bdffc7db2996b3ac042c88a2,Seguros: recupero de siniestros directos rama agropecuaria,Canal: seguro
seg_agro_siniestros_reaseg_cedidos_ext,insurance_annex:x1_18:f64ffadf7c8cd2ef9eacb6fa,Seguros: siniestros recuperados de reaseguro cedido al exterior (agropecuario),Transferencia del riesgo al exterior
", stringsAsFactors = FALSE, strip.white = TRUE)

dicc_enso <- read.csv(text = "
serie,descripcion,rol
oni,NOAA CPC: Oceanic Niño Index (media móvil 3 meses; mes central),Shock climático (ENSO)
nino34_sst_3m,NOAA CPC: temperatura absoluta Niño 3.4 media móvil 3 meses,Índice alternativo
roni,NOAA CPC: ONI relativo,Índice alternativo
nino34_anom_mensual,NOAA CPC: anomalía mensual Niño 3.4 (1982-),Índice alternativo mensual
", stringsAsFactors = FALSE, strip.white = TRUE)

con <- conectar()
sgc <- spec_por_hoja(con, "credit_survey", "Índices", "sgc", "Situación General del Crédito por sector (situación, expectativa, confianza)",
                     frecuencias = "quarterly")
spec <- rbind(dicc, sgc)
x <- extraer_escalares(con, spec)
enso <- rbind(leer_oni(), leer_roni(), leer_nino34_mensual())
escribir_series(rbind(x, enso), rbind(spec[, c("serie", "descripcion", "rol")], dicc_enso))

message("Paneles entidad-mes: crédito por sector y cultivo, ratios, provisiones y capital...")
union <- function(a, b) sprintf("(SELECT * FROM %s UNION ALL BY NAME SELECT * FROM %s)", a, b)
sec <- dbGetQuery(con, paste("
  SELECT source_id AS tipo_entidad, fecha, codigo_entidad, codigo_moneda, actividad_destino_vs2 AS sector,
         cartera_vigente, cartera_vencida
    FROM", union("main.v_latest_raw_banks_credito_sector", "main.v_latest_raw_financial_credito_sector"), "ORDER BY 1,2,3,4,5"))
sec <- fechas_panel(sec); sec$nivel_verificacion <- "Panel provisional"
escribir_csv(sec, "panel_credito_sector_entidad_mes.csv")
act <- dbGetQuery(con, paste("
  SELECT source_id AS tipo_entidad, fecha, codigo_entidad, codigo_moneda, descripcion_actividad AS cultivo,
         cartera_vigente, cartera_vencida
    FROM", union("main.v_latest_raw_banks_credito_actividad", "main.v_latest_raw_financial_credito_actividad"), "ORDER BY 1,2,3,4,5"))
act <- fechas_panel(act); act$nivel_verificacion <- "Panel provisional"
escribir_csv(act, "panel_credito_cultivo_entidad_mes.csv")
rat <- dbGetQuery(con, paste("
  SELECT source_id AS tipo_entidad, fecha, codigo_entidad, sub_rubro AS ratio, total AS valor
    FROM", union("main.v_latest_raw_banks_ratios", "main.v_latest_raw_financial_ratios"), "
   WHERE sub_rubro IN ('Cartera Vencida/Cartera Total - Morosidad','Morosidad MN','Morosidad ME','Refinanciados/Cartera',
                       'Reestructurados/Cartera','Renovados/Cartera','RRR/Cartera','Previsiones/Préstamos Vencidos',
                       'Relación entre TIER 1/ACPR','Relación entre TIER 1 + TIER 2/ACPR',
                       'Disponible + Inversiones Temporales/Depósitos','Utilidad antes de Impuesto/Patrimonio (Anual)')
   ORDER BY 1,2,3,4"))
rat <- fechas_panel(rat); rat$nivel_verificacion <- "Panel provisional"
escribir_csv(rat, "panel_ratios_riesgo_entidad_mes.csv")
cat_r <- dbGetQuery(con, paste("
  SELECT source_id AS tipo_entidad, fecha, codigo_entidad, codigo_tipo_riesgo AS categoria_riesgo, total AS saldo
    FROM", union("main.v_latest_raw_banks_categoria_creditos", "main.v_latest_raw_financial_categoria_creditos"), "ORDER BY 1,2,3,4"))
cat_r <- fechas_panel(cat_r); cat_r$nivel_verificacion <- "Panel provisional"
escribir_csv(cat_r, "panel_categoria_riesgo_entidad_mes.csv")
ee <- dbGetQuery(con, paste("
  SELECT source_id AS tipo_entidad, fecha, entity_id, short_name AS entidad, semantic_rubro AS rubro, sub_rubro,
         codigo_moneda, importe AS importe_pyg
    FROM", union("main.v_banks_eeff_documented", "main.v_financial_eeff_documented"), "
   WHERE sub_rubro IN ('Sector No Financiero','Créditos y Colocaciones Vencidos','Deudores con Arreglo y Créditos Morosos',
                       'Total Previsiones','Constitución de Previsiones','Desafectación de Previsiones',
                       'Capital Integrado','Reserva Legal','Otras Reservas','Resultados Acumulados','Utilidad del Ejercicio')
   ORDER BY 1,2,3,5,6,7"))
ee <- fechas_panel(ee); ee$nivel_verificacion <- "Panel provisional"
escribir_csv(ee, "panel_eeff_riesgo_entidad_mes.csv")
ent <- dbGetQuery(con, paste("SELECT DISTINCT entity_id, short_name AS entidad, legal_name AS razon_social, ownership_type AS propiedad FROM",
                             union("main.v_banks_eeff_documented", "main.v_financial_eeff_documented"), "ORDER BY 1"))
escribir_csv(ent, "entidades.csv", fecha_col = "none")
cerrar(con)
