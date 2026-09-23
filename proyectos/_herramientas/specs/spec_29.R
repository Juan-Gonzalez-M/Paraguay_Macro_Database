## Proyecto 29 · N8 (nuevo) — Canal de crédito bancario de la política monetaria
## ¿Responden distinto al cambio de la TPM los bancos con menos liquidez, menos capital o más fondeo
## a plazo? Panel banco × moneda × mes con balance, ratios y crédito por sector; TPM, sorpresas (EVE y,
## cuando exista, el calendario del COPOM del proyecto 25) y tasas del sistema.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,Tasa de política monetaria (promedio mensual),Tratamiento (nivel)
eve_tpm_mes,eve:tasa_de_politica_monetaria_tpm:expectativa_del_mes,EVE (mediana): TPM esperada para el mes,Sorpresa = TPM − esperada
eve_tpm_prox_mes,eve:tasa_de_politica_monetaria_tpm:expectativa_del_proximo_mes,EVE (mediana): TPM esperada próximo mes,Sorpresa alternativa
c31_mn_activa_prom,economic_annex:cuadro_31:c90c5c9c2ec39acfaed4ff16,Tasa efectiva activa MN promedio (etiqueta contaminada),Traspaso a tasas activas
c31_mn_pasiva_prom,economic_annex:cuadro_31:6ff03d8f79fc15937b18bab3,Tasa efectiva pasiva MN promedio (etiqueta contaminada),Traspaso a tasas pasivas
imaep_original,economic_annex:cuadro_9:fc9a02c5dcc0573b3c038553,IMAEP serie original,Control de demanda
ipc_var_interanual,economic_annex:cuadro_15:080dbf95a46f3bcb97aeb69d,Inflación interanual,Control
pyg_usd_prom_venta,exchange_rates:usd_prom:190c4a9509f6c233bdc28928,PYG por USD promedio mensual,Conversión y control
", stringsAsFactors = FALSE, strip.white = TRUE)

con <- conectar()
x <- extraer_escalares(con, dicc)
escribir_series(x, dicc)
union <- function(a, b) sprintf("(SELECT * FROM %s UNION ALL BY NAME SELECT * FROM %s)", a, b)
ee <- dbGetQuery(con, paste("
  SELECT source_id AS tipo_entidad, fecha, entity_id, short_name AS entidad, semantic_classification AS clase,
         semantic_rubro AS rubro, sub_rubro, codigo_moneda, importe AS importe_pyg
    FROM", union("main.v_banks_eeff_documented", "main.v_financial_eeff_documented"), "
   WHERE semantic_classification IN ('1. Activo','2. Pasivo','3. Patrimonio N.')
   ORDER BY 1,2,3,5,6,7,8"))
ee <- fechas_panel(ee); ee$nivel_verificacion <- "Panel provisional"
escribir_csv(ee, "panel_balance_entidad_mes.csv")
sec <- dbGetQuery(con, paste("SELECT source_id AS tipo_entidad, fecha, codigo_entidad, codigo_moneda, actividad_destino_vs2 AS sector, cartera_vigente, cartera_vencida FROM",
                             union("main.v_latest_raw_banks_credito_sector", "main.v_latest_raw_financial_credito_sector"), "ORDER BY 1,2,3,4,5"))
sec <- fechas_panel(sec); sec$nivel_verificacion <- "Panel provisional"
escribir_csv(sec, "panel_credito_sector_entidad_mes.csv")
rat <- dbGetQuery(con, paste("SELECT source_id AS tipo_entidad, fecha, codigo_entidad, sub_rubro AS ratio, total AS valor FROM",
                             union("main.v_latest_raw_banks_ratios", "main.v_latest_raw_financial_ratios"), "ORDER BY 1,2,3,4"))
rat <- fechas_panel(rat); rat$nivel_verificacion <- "Panel provisional"
escribir_csv(rat, "panel_ratios_entidad_mes.csv")
ent <- dbGetQuery(con, paste("SELECT DISTINCT entity_id, short_name AS entidad, legal_name AS razon_social, ownership_type AS propiedad FROM",
                             union("main.v_banks_eeff_documented", "main.v_financial_eeff_documented"), "ORDER BY 1"))
escribir_csv(ent, "entidades.csv", fecha_col = "none")
message("Calendario del COPOM (manual; el mismo formato que el proyecto 25)...")
leer_manual("calendario_copom",
            c("fecha_reunion", "fecha_anuncio", "hora_anuncio", "tpm_anterior", "tpm_nueva", "tipo_reunion", "fuente", "estado_verificacion"))
cerrar(con)
