## Proyecto 30 · N9 (nuevo) — SPI y demanda de efectivo / sustitución entre medios de pago
## Estudio de eventos en torno al lanzamiento del SPI (2022-05) y sus hitos: efectivo (M0),
## depósitos transaccionales, cheques, ACH, LBTR, tarjetas y SPI; cajeros por entidad.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
billetes_monedas,economic_annex:cuadro_21:b8ce2b9f8e9025fdccf7e5f5,M0: billetes y monedas en circulación,Resultado principal: demanda de efectivo
base_monetaria,economic_annex:cuadro_21:2bf58454c90affb85cd6091b,Base monetaria,Control
m1,economic_annex:cuadro_21:0c4d7e31c82107467040bbaa,M1,Resultado: dinero transaccional
m2,economic_annex:cuadro_21:57f8dfa2bf9a6d5b0ec92042,M2,Normalización (M0/M2)
dep_priv_mn_ctacte,economic_annex:cuadro_23a:cb884bce6a9707e5dbb37c81,Depósitos privados MN en cuenta corriente,Resultado: depósitos transaccionales
dep_priv_mn_vista,economic_annex:cuadro_23a:82319ba269b30cfdbab2067c,Depósitos privados MN a la vista,Resultado: depósitos transaccionales
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,Tasa de política monetaria,Control: costo de oportunidad del efectivo (2022 = ciclo de subas)
ipc_indice,economic_annex:cuadro_14:a5d7fc4139616340def083cc,IPC índice general,Deflactor / control
ipc_var_interanual,economic_annex:cuadro_15:080dbf95a46f3bcb97aeb69d,Inflación interanual,Control (inflación alta en 2022)
imaep_original,economic_annex:cuadro_9:fc9a02c5dcc0573b3c038553,IMAEP serie original,Control de transacciones
", stringsAsFactors = FALSE, strip.white = TRUE)

con <- conectar()
hojas <- c("SIPAP_01", "SIPAP_02", "SIPAP_06", "SIPAP_07", "SIPAP_09", "SIPAP_10", "SIPAP_12", "SIPAP_13",
           "CCC 01", "CCC 02", "CCC 03", "CCE", "CCCoop", "OMP 01", "OMP 02", "OMP 03", "OMP 04")
bloques <- do.call(rbind, lapply(hojas, function(h)
  spec_por_hoja(con, "payments", h, paste0("pag_", slug(h)), paste0("Sistemas de pago: hoja ", h))))
spec <- rbind(dicc, bloques)
x <- extraer_escalares(con, spec)
escribir_series(x, spec)
union <- function(a, b) sprintf("(SELECT * FROM %s UNION ALL BY NAME SELECT * FROM %s)", a, b)
can <- dbGetQuery(con, paste("SELECT source_id AS tipo_entidad, fecha, codigo_entidad, clasificacion, descripcion, total FROM",
                             union("main.v_latest_raw_banks_canales_person", "main.v_latest_raw_financial_canales_person"), "ORDER BY 1,2,3,4,5"))
can <- fechas_panel(can); can$nivel_verificacion <- "Panel provisional"
escribir_csv(can, "panel_canales_entidad_mes.csv")
message("Hitos del SPI (manual)...")
ejemplo <- data.frame(fecha_hito = "2022-05-01", hito = "Inicio de operaciones del SPI (primer mes con datos en el boletín SIPAP_07)",
                      detalle = "", fuente = "Inferido del boletín de pagos (primer dato de SIPAP_07)", estado_verificacion = "no verificado")
leer_manual("hitos_spi", c("fecha_hito", "hito", "detalle", "fuente", "estado_verificacion"), ejemplo)
cerrar(con)
