## Proyecto 27 · N6 (nuevo) — Cambios regulatorios con exposición bancaria heterogénea (DiD)
## Módulo A: cambios del encaje legal (tasas por moneda y plazo) × dependencia previa de cada banco.
## Módulo B: tope a las tasas de tarjetas de crédito × exposición previa de cada banco al negocio de tarjetas.
## Las fechas y reglas de cada cambio se cargan en datos_manuales/cambios_regulatorios.csv.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,Tasa de política monetaria,Control (política monetaria simultánea)
bancos_encaje_mn,economic_annex:cuadro_27:1c63a4cb41004337fa196728,Encaje legal de bancos en el BCP MN (agregado),Primera etapa agregada (módulo A)
bancos_encaje_me,economic_annex:cuadro_27:00327fb5cb588d371dfa5379,Encaje legal de bancos en el BCP ME (millones de Gs. equivalentes),Primera etapa agregada (módulo A)
gasto_remun_encaje_mn,economic_annex:cuadro_26:a5a0376103c224b5640c8773,Remuneración del encaje MN (gasto del BCP),Costo del encaje
cred_priv_mn,economic_annex:cuadro_24a:066262e294293abfdf394a22,Crédito privado MN (agregado),Resultado agregado
cred_priv_me_usd,economic_annex:cuadro_24a:24d810aa73e2ae59ac1bd9b9,Crédito privado ME en millones de USD,Resultado agregado
imaep_original,economic_annex:cuadro_9:fc9a02c5dcc0573b3c038553,IMAEP serie original,Control de demanda
ipc_indice,economic_annex:cuadro_14:a5d7fc4139616340def083cc,IPC índice general,Deflactor
", stringsAsFactors = FALSE, strip.white = TRUE)

con <- conectar()
## Tasas de tarjetas de crédito y demás productos de consumo del sistema (Indicadores Financieros)
tj <- dbGetQuery(con, "SELECT candidate_id, trim(source_sheet) AS hoja, researcher_name FROM catalog.series
                        WHERE source_id = 'financial_indicators' AND frequency = 'monthly'
                          AND (researcher_name ILIKE '%tarjeta%' OR researcher_name ILIKE '%consumo%' OR researcher_name ILIKE '%sobregiro%')
                          AND EXISTS (SELECT 1 FROM main.v_series_research r WHERE r.series_id = catalog.series.candidate_id)
                        ORDER BY hoja, researcher_name")
tj <- data.frame(serie = make.unique(paste0("fi_", slug(paste(tj$hoja, tj$researcher_name), 70)), sep = "_"),
                 candidate_id = tj$candidate_id,
                 descripcion = paste0("financial_indicators hoja ", tj$hoja, ": ", tj$researcher_name),
                 rol = "Tasas y saldos de tarjetas/consumo/sobregiros (módulo B: resultado y placebo)", stringsAsFactors = FALSE)
spec <- rbind(dicc, tj)
x <- extraer_escalares(con, spec)
escribir_series(x, spec)

message("Paneles entidad-mes...")
union <- function(a, b) sprintf("(SELECT * FROM %s UNION ALL BY NAME SELECT * FROM %s)", a, b)
ee <- dbGetQuery(con, paste("
  SELECT source_id AS tipo_entidad, fecha, entity_id, short_name AS entidad, semantic_rubro AS rubro, sub_rubro,
         codigo_moneda, importe AS importe_pyg
    FROM", union("main.v_banks_eeff_documented", "main.v_financial_eeff_documented"), "
   WHERE semantic_rubro IN ('1.1. Caja y Bancos','1.2. BCP - Activo','1.3. Inv. en Valores','1.4. Coloc. Netas','2.1. Depósitos','2.3. BCP - Pasivo')
      OR sub_rubro IN ('Tarjetas de Crédito','Capital Integrado','Reserva Legal','Otras Reservas','Resultados Acumulados','Utilidad del Ejercicio',
                       'Ganancias Créd. Vig. p/ Inter. Finan. S.N.F.','Pérd. Oblig. Inter. Finan. S.N.F.')
   ORDER BY 1,2,3,5,6,7"))
ee <- fechas_panel(ee); ee$nivel_verificacion <- "Panel provisional"
escribir_csv(ee, "panel_eeff_regulacion_entidad_mes.csv")
tc <- dbGetQuery(con, paste("SELECT source_id AS tipo_entidad, fecha, codigo_entidad, clasificacion, total FROM",
                            union("main.v_latest_raw_banks_tc", "main.v_latest_raw_financial_tc"), "ORDER BY 1,2,3,4"))
tc <- fechas_panel(tc); tc$nivel_verificacion <- "Panel provisional"
escribir_csv(tc, "panel_tarjetas_credito_entidad_mes.csv")
car <- dbGetQuery(con, paste("SELECT source_id AS tipo_entidad, fecha, codigo_entidad, codigo_cuenta AS cuenta, codigo_moneda, importe AS importe_pyg FROM",
                             union("main.v_latest_raw_banks_carteras", "main.v_latest_raw_financial_carteras"), "ORDER BY 1,2,3,4,5"))
car <- fechas_panel(car); car$nivel_verificacion <- "Panel provisional"
escribir_csv(car, "panel_carteras_entidad_mes.csv")
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

message("Cambios regulatorios (manual)...")
leer_manual("cambios_regulatorios",
            c("fecha_vigencia", "fecha_anuncio", "instrumento", "moneda", "plazo_o_segmento", "valor_anterior", "valor_nuevo",
              "unidad", "norma", "fuente", "estado_verificacion"))
cerrar(con)
