## Proyecto 05 · C1 — Liquidez dólar, dolarización y descalce cambiario
## Panel banco/financiera × mes × moneda (6200 = ME expresado en PYG; 6900 = PYG) con
## balance completo, cartera por sector y actividad, categorías de riesgo y ratios, más
## shocks externos (FRED) y agregados de dolarización. Paneles completos por acuerdo de la Fase 1.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
dep_priv_part_me,economic_annex:cuadro_23a:322c9ae3c660f49040467fce,Participación de ME en depósitos privados (%),Dolarización de depósitos (agregado)
dep_priv_me_total_usd,economic_annex:cuadro_23a:6665dcbd306238301a26a70e,Depósitos privados en ME (millones de USD),Fondeo en USD (agregado)
dep_priv_mn_total,economic_annex:cuadro_23a:4f4afb1454f1954045984105,Depósitos privados en MN (millones de Gs.),Fondeo en PYG (agregado)
cred_priv_part_me,economic_annex:cuadro_24a:c634f2fdb01f30ade67b492f,Participación de ME en el crédito privado (%),Dolarización del crédito (agregado)
cred_priv_me_usd,economic_annex:cuadro_24a:24d810aa73e2ae59ac1bd9b9,Crédito privado en ME (millones de USD),Exposición cambiaria del crédito
cred_priv_mn,economic_annex:cuadro_24a:066262e294293abfdf394a22,Crédito privado en MN (millones de Gs.),Crédito en PYG
c31_me_pasiva_cda,economic_annex:cuadro_31_cont:471798dff0fbf8cce6e28cce,Tasa efectiva pasiva ME CDA,Costo del fondeo en USD
c31_me_pasiva_vista,economic_annex:cuadro_31_cont:55464b82ce76371bfa534f0b,Tasa efectiva pasiva ME a la vista,Costo del fondeo en USD
c31_me_activa_prom,economic_annex:cuadro_31_cont:eaf763baa29bd5845926073b,Tasa efectiva activa ME promedio ponderado,Precio del crédito en USD
c31_mn_activa_prom,economic_annex:cuadro_31:c90c5c9c2ec39acfaed4ff16,Tasa efectiva activa MN promedio (sin tarjetas ni sobregiros; etiqueta contaminada),Precio del crédito en PYG
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,Tasa de política monetaria,Control doméstico
pyg_usd_prom_venta,exchange_rates:usd_prom:190c4a9509f6c233bdc28928,PYG por USD promedio mensual (venta),Depreciación (shock y conversión)
tcr_multilateral,economic_annex:cuadro_60b:cda2955982d3c374c57fbb42,Tipo de cambio real multilateral,Depreciación real
pyg_brl,economic_annex:cuadro_60a:2442b69bab143106463ed144,PYG por BRL,Shock regional
rin_saldo,economic_annex:cuadro_56b:f51d08d7995561bfce2166eb,Reservas internacionales netas,Colchón de liquidez en USD del sistema
fwd_compra_total,economic_annex:cuadro_61:c1e3d7c587159be995288eee,Compras forward totales (volumen),Cobertura cambiaria (proxy)
fwd_venta_total,economic_annex:cuadro_61:d964d9000ef92ca9b9bdd9a1,Ventas forward totales (volumen),Cobertura cambiaria (proxy)
fed_rango_superior,financial_indicators:x8:c6e9b9ddaec363c3e89b538d,Fed funds: límite superior (hoja 8),Shock externo de tasas
sofr,financial_indicators:x8:34f5511046704209dd8c44d5,SOFR (hoja 8),Costo del fondeo externo en USD
selic,financial_indicators:x8:66dac7933b59a1b55c19f938,Tasa Selic (hoja 8),Shock regional
soja_chicago,economic_annex:cuadro_49:898153a96bc9fe9ece97e94b,Soja Chicago USD/t,Shock a ingresos de exportadores (cobertura natural)
carne_chicago,economic_annex:cuadro_49:6e6364e656bb4f80ee31dff8,Carne Chicago USD/t,Shock a ingresos de exportadores
expo_registradas,economic_annex:cuadro_46a:c53d182b059f53899aef8f2a,Exportaciones registradas totales,Ingresos en USD de la economía
", stringsAsFactors = FALSE, strip.white = TRUE)

externos <- read.csv(text = "
serie,id,agregacion,unidad,descripcion,rol
vix_m,VIXCLS,avg,INDEX_POINTS,FRED: VIX promedio mensual,Shock global de riesgo
dolar_amplio_m,TWEXBGSMTH,,INDEX,FRED: índice nominal amplio del dólar,Shock global de dólar (no exógeno; ver ficha)
fed_funds_efectiva,FEDFUNDS,,PERCENT,FRED: tasa efectiva de fondos federales,Shock externo de tasas (historia larga)
ust_2a,DGS2,avg,PERCENT,FRED: rendimiento Tesoro EE.UU. 2 años (promedio mensual),Shock externo de tasas
", stringsAsFactors = FALSE, strip.white = TRUE, na.strings = "")

con <- conectar()
tasas <- spec_por_hoja(con, "financial_indicators", "1.2", "tef_bancos", "Tasas efectivas por producto y moneda (bancos; promedio del sistema)")
spec <- rbind(dicc, tasas)
x <- extraer_escalares(con, spec)
ext <- leer_fred_bloque(externos)
escribir_series(rbind(x, ext), rbind(spec[, c("serie", "descripcion", "rol")], externos[, c("serie", "descripcion", "rol")]))

message("Paneles completos entidad-mes (bancos y financieras)...")
union <- function(a, b) sprintf("(SELECT * FROM %s UNION ALL BY NAME SELECT * FROM %s)", a, b)
eeff <- dbGetQuery(con, paste("
  SELECT source_id AS tipo_entidad, fecha, entity_id, short_name AS entidad, ownership_type AS propiedad,
         semantic_classification AS clase, semantic_rubro AS rubro, sub_rubro, codigo_moneda,
         currency_of_origin AS moneda_origen, importe AS importe_pyg
    FROM", union("main.v_banks_eeff_documented", "main.v_financial_eeff_documented"),
  "ORDER BY tipo_entidad, fecha, entity_id, clase, rubro, sub_rubro, codigo_moneda"))
eeff <- fechas_panel(eeff); eeff$nivel_verificacion <- "Panel provisional"
escribir_csv(eeff, "panel_eeff_entidad_mes.csv")
car <- dbGetQuery(con, paste("
  SELECT source_id AS tipo_entidad, fecha, codigo_entidad, codigo_cuenta AS cuenta, codigo_moneda, importe AS importe_pyg
    FROM", union("main.v_latest_raw_banks_carteras", "main.v_latest_raw_financial_carteras"), "ORDER BY 1,2,3,4,5"))
car <- fechas_panel(car); car$nivel_verificacion <- "Panel provisional"
escribir_csv(car, "panel_carteras_entidad_mes.csv")
sec <- dbGetQuery(con, paste("
  SELECT source_id AS tipo_entidad, fecha, codigo_entidad, codigo_moneda, actividad_destino_vs2 AS sector,
         cartera_vigente, cartera_vencida
    FROM", union("main.v_latest_raw_banks_credito_sector", "main.v_latest_raw_financial_credito_sector"), "ORDER BY 1,2,3,4,5"))
sec <- fechas_panel(sec); sec$nivel_verificacion <- "Panel provisional"
escribir_csv(sec, "panel_credito_sector_entidad_mes.csv")
act <- dbGetQuery(con, paste("
  SELECT source_id AS tipo_entidad, fecha, codigo_entidad, codigo_moneda, descripcion_actividad AS actividad,
         cartera_vigente, cartera_vencida
    FROM", union("main.v_latest_raw_banks_credito_actividad", "main.v_latest_raw_financial_credito_actividad"), "ORDER BY 1,2,3,4,5"))
act <- fechas_panel(act); act$nivel_verificacion <- "Panel provisional"
escribir_csv(act, "panel_credito_actividad_entidad_mes.csv")
cat_r <- dbGetQuery(con, paste("
  SELECT source_id AS tipo_entidad, fecha, codigo_entidad, codigo_tipo_riesgo AS categoria_riesgo, total AS saldo
    FROM", union("main.v_latest_raw_banks_categoria_creditos", "main.v_latest_raw_financial_categoria_creditos"), "ORDER BY 1,2,3,4"))
cat_r <- fechas_panel(cat_r); cat_r$nivel_verificacion <- "Panel provisional"
escribir_csv(cat_r, "panel_categoria_riesgo_entidad_mes.csv")
rat <- dbGetQuery(con, paste("
  SELECT source_id AS tipo_entidad, fecha, codigo_entidad, sub_rubro AS ratio, total AS valor
    FROM", union("main.v_latest_raw_banks_ratios", "main.v_latest_raw_financial_ratios"), "ORDER BY 1,2,3,4"))
rat <- fechas_panel(rat); rat$nivel_verificacion <- "Panel provisional"
escribir_csv(rat, "panel_ratios_entidad_mes.csv")
ent <- dbGetQuery(con, paste("SELECT DISTINCT entity_id, short_name AS entidad, legal_name AS razon_social, ownership_type AS propiedad FROM",
                             union("main.v_banks_eeff_documented", "main.v_financial_eeff_documented"), "ORDER BY 1"))
escribir_csv(ent, "entidades.csv", fecha_col = "none")
cerrar(con)
