## Proyecto 20 · F4 — Pagos instantáneos (SPI), competencia y movilidad de depósitos
## Piloto de monitoreo: boletín completo de sistemas de pago (SIPAP/LBTR, ACH, SPI, cheques,
## tarjetas, AFD, Hacienda, cooperativas), bancarización, efectivo y paneles por entidad.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
billetes_monedas,economic_annex:cuadro_21:b8ce2b9f8e9025fdccf7e5f5,M0: billetes y monedas en circulación,Uso de efectivo (resultado)
base_monetaria,economic_annex:cuadro_21:2bf58454c90affb85cd6091b,Base monetaria,Control
m1,economic_annex:cuadro_21:0c4d7e31c82107467040bbaa,M1,Depósitos transaccionales (resultado)
m2,economic_annex:cuadro_21:57f8dfa2bf9a6d5b0ec92042,M2,Control
dep_priv_mn_ctacte,economic_annex:cuadro_23a:cb884bce6a9707e5dbb37c81,Depósitos privados MN en cuenta corriente,Depósitos transaccionales
dep_priv_mn_vista,economic_annex:cuadro_23a:82319ba269b30cfdbab2067c,Depósitos privados MN a la vista,Depósitos transaccionales
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,Tasa de política monetaria,Control (costo de oportunidad del efectivo)
ipc_indice,economic_annex:cuadro_14:a5d7fc4139616340def083cc,IPC índice general,Deflactor
", stringsAsFactors = FALSE, strip.white = TRUE)

con <- conectar()
hojas_pagos <- dbGetQuery(con, "SELECT DISTINCT trim(source_sheet) h FROM catalog.series WHERE source_id = 'payments' ORDER BY 1")$h
bloques <- do.call(rbind, lapply(hojas_pagos, function(h)
  spec_por_hoja(con, "payments", h, paste0("pag_", slug(h)), paste0("Sistemas de pago: hoja ", h))))
banc <- do.call(rbind, lapply(as.character(1:7), function(h)
  spec_por_hoja(con, "banking_indicators", h, paste0("bancariz_", h), "Bancarización (personas y cuentas)")))
spec <- rbind(dicc, bloques, banc)
x <- extraer_escalares(con, spec)
escribir_series(x, spec)

message("Paneles entidad-mes: depósitos, canales de atención y tarjetas...")
union <- function(a, b) sprintf("(SELECT * FROM %s UNION ALL BY NAME SELECT * FROM %s)", a, b)
dep <- dbGetQuery(con, paste("
  SELECT source_id AS tipo_entidad, fecha, entity_id, short_name AS entidad, sub_rubro, codigo_moneda, importe AS importe_pyg
    FROM", union("main.v_banks_eeff_documented", "main.v_financial_eeff_documented"), "
   WHERE semantic_rubro = '2.1. Depósitos' ORDER BY 1,2,3,5,6"))
dep <- fechas_panel(dep); dep$nivel_verificacion <- "Panel provisional"
escribir_csv(dep, "panel_depositos_entidad_mes.csv")
can <- dbGetQuery(con, paste("
  SELECT source_id AS tipo_entidad, fecha, codigo_entidad, clasificacion, descripcion, total
    FROM", union("main.v_latest_raw_banks_canales_person", "main.v_latest_raw_financial_canales_person"), "ORDER BY 1,2,3,4,5"))
can <- fechas_panel(can); can$nivel_verificacion <- "Panel provisional"
escribir_csv(can, "panel_canales_personal_entidad_mes.csv")
tc <- dbGetQuery(con, paste("
  SELECT source_id AS tipo_entidad, fecha, codigo_entidad, clasificacion, total
    FROM", union("main.v_latest_raw_banks_tc", "main.v_latest_raw_financial_tc"), "ORDER BY 1,2,3,4"))
tc <- fechas_panel(tc); tc$nivel_verificacion <- "Panel provisional"
escribir_csv(tc, "panel_tarjetas_credito_entidad_mes.csv")
ent <- dbGetQuery(con, paste("SELECT DISTINCT entity_id, short_name AS entidad, legal_name AS razon_social, ownership_type AS propiedad FROM",
                             union("main.v_banks_eeff_documented", "main.v_financial_eeff_documented"), "ORDER BY 1"))
escribir_csv(ent, "entidades.csv", fecha_col = "none")
cerrar(con)
