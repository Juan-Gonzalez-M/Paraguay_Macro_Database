## Proyecto 07 · C3 — Bonos corporativos, crédito bancario y deuda pública
## Dos módulos separados: (a) spread bono-banco; (b) deuda pública y subastas.
## Curvas NSS de bonos corporativos (research.curves), curva CDA, transacciones bursátiles
## de instrumentos de deuda (research.transactions), mercado secundario de LRM/bonos y subastas de LRM.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,Tasa de política monetaria,Condición monetaria (explicativa)
c31_mn_activa_prom,economic_annex:cuadro_31:c90c5c9c2ec39acfaed4ff16,Tasa efectiva activa MN promedio (sin tarjetas ni sobregiros; etiqueta contaminada),Tasa bancaria de referencia MN
c31_me_activa_prom,economic_annex:cuadro_31_cont:eaf763baa29bd5845926073b,Tasa efectiva activa ME promedio ponderado,Tasa bancaria de referencia ME
c31_me_pasiva_cda,economic_annex:cuadro_31_cont:471798dff0fbf8cce6e28cce,Tasa efectiva pasiva ME CDA,Costo de fondeo bancario ME
deuda_ext_saldo,economic_annex:cuadro_59:e5c2a05e30651e100a3dc1e7,Deuda pública externa: saldo (miles de USD),Oferta de deuda pública (stock)
deuda_ext_desembolsos,economic_annex:cuadro_59:f9c2e28f029232cc280c33bc,Deuda pública externa: desembolsos,Oferta de deuda pública (flujo)
deuda_ext_servicio,economic_annex:cuadro_59:69307e03162e952cb9a46553,Deuda pública externa: pagos de capital e intereses,Servicio de deuda
fiscal_financiamiento_neto,mef_central_government:serie:360944a8298772c084d758da,Administración Central: incurrimiento neto de pasivos,Necesidad de financiamiento del Tesoro
fiscal_financiamiento_interno,mef_central_government:serie:0a018056482e619181d731fb,Administración Central: financiamiento interno (incurrimiento de pasivos),Oferta local de deuda pública
fiscal_financiamiento_externo,mef_central_government:serie:98de68d5e2727de6c4025229,Administración Central: financiamiento externo,Oferta externa de deuda pública
fiscal_intereses,mef_central_government:serie:58c4415b123ad9470009c434,Administración Central: gasto en intereses,Costo de la deuda
fiscal_balance,mef_central_government:serie:8d3088bf00ff46c755b66e9d,Administración Central: préstamo neto / endeudamiento neto,Necesidad de financiamiento
bva_total_operacion,economic_annex:cuadro_32:5592ee1b8212b9878d3cd2ab,Bolsa de Valores: total operado (millones de Gs.; etiqueta contaminada),Liquidez del mercado
bva_bonos,economic_annex:cuadro_32:4b50e297688d658d9de4ca28,Bolsa de Valores: bonos en PYG (etiqueta contaminada),Liquidez del mercado de bonos
bva_bonos_usd,economic_annex:cuadro_32:96baa49a13e1b2f51f4669a5,Bolsa de Valores: bonos en USD (etiqueta contaminada),Liquidez del mercado de bonos
bva_custodia_total,economic_annex:cuadro_32_a:bf8595a1dd956a764d20c6a1,Documentos en custodia: total (millones de Gs.),Stock del mercado
bva_custodia_bono,economic_annex:cuadro_32_a:1e33613420bc47f1b07dad92,Documentos en custodia: bonos,Stock de bonos
bva_custodia_bono_financiero,economic_annex:cuadro_32_a:d2cb0dc67412f1258f2887d5,Documentos en custodia: bonos financieros,Stock de bonos bancarios
bva_custodia_bono_subordinado,economic_annex:cuadro_32_a:beb4202973702f3b4308b44d,Documentos en custodia: bonos subordinados,Stock de bonos bancarios
bva_custodia_bbcp,economic_annex:cuadro_32_a:160591a737b8a78ea214b4b6,Documentos en custodia: bonos del BCP,Stock de papeles del BCP
pyg_usd_prom_venta,exchange_rates:usd_prom:190c4a9509f6c233bdc28928,PYG por USD promedio mensual,Conversión
ipc_var_interanual,economic_annex:cuadro_15:080dbf95a46f3bcb97aeb69d,Inflación total interanual,Tasas reales
eve_tpm_anio_t,eve:tasa_de_politica_monetaria_tpm:expectativa_ano_t,EVE (mediana): TPM esperada fin de año,Trayectoria esperada de tasas
", stringsAsFactors = FALSE, strip.white = TRUE)

externos <- read.csv(text = "
serie,id,agregacion,unidad,descripcion,rol
ust_10a,DGS10,avg,PERCENT,FRED: rendimiento Tesoro EE.UU. 10 años (promedio mensual),Tasa libre de riesgo global (bonos en USD)
ust_2a,DGS2,avg,PERCENT,FRED: rendimiento Tesoro EE.UU. 2 años (promedio mensual),Tasa libre de riesgo global
", stringsAsFactors = FALSE, strip.white = TRUE, na.strings = "")

con <- conectar()
tasas <- spec_por_hoja(con, "financial_indicators", "2.2", "tef_plazo_bancos", "Tasa bancaria por producto, plazo y moneda (comparación con bonos)")
spec <- rbind(dicc, tasas)
x <- extraer_escalares(con, spec)
ext <- leer_fred_bloque(externos)
escribir_series(rbind(x, ext), rbind(spec[, c("serie", "descripcion", "rol")], externos[, c("serie", "descripcion", "rol")]))

message("Curvas de bonos corporativos (NSS) y curva CDA...")
cur <- dbGetQuery(con, "
  SELECT CAST(period AS DATE) AS fecha, currency AS moneda, risk_rating AS calificacion, maturity_years AS plazo_anios,
         zero_coupon_rate AS tasa_cero, par_rate AS tasa_par, discount_factor AS factor_descuento,
         beta0, beta1, beta2, beta3, lambda1, lambda2, assurance_level, source_row
    FROM research.curves ORDER BY fecha, moneda, calificacion, plazo_anios")
cur$nivel_verificacion <- "Validada por regla (estructural)"
escribir_csv(cur, "curvas_bonos_corporativos.csv")
escribir_csv(extraer_curvas(con, "cda_curve"), "curvas_cda_mensual.csv")

message("Transacciones bursátiles de instrumentos de deuda...")
tr <- dbGetQuery(con, "
  SELECT CAST(operation_date AS DATE) AS fecha, transaction_id, instrument AS instrumento, market AS mercado,
         operation_type AS tipo_operacion, currency AS moneda, local_currency_volume AS volumen_moneda_local,
         volume_status AS estado_volumen, isin, issuer_tax_id AS emisor_ruc, issuer_name AS emisor,
         broker_name AS casa_bolsa, trading_venue AS plataforma, assurance_level, source_row
    FROM research.transactions
   WHERE instrument IN ('BONOS CORPORATIVOS','BONOS SUBORDINADOS','BONO FINANCIERO','BONO DEL TESORO',
                        'BONOS DEL TESORO','BONOS MUNICIPALES','BBCP','LRM','CDA')
   ORDER BY fecha, transaction_id")
tr$nivel_verificacion <- "Validada por regla (estructural)"
escribir_csv(tr, "transacciones_deuda_bva.csv")

message("Eventos: mercado secundario de LRM/bonos y subastas de LRM...")
ev <- dbGetQuery(con, "
  SELECT CAST(reference_period_start AS DATE) AS fecha, source_id AS fuente, source_sheet AS hoja,
         full_series_path AS detalle, researcher_name AS variable, value AS valor, unit_code AS unidad,
         validation_tier, candidate_id, source_row
    FROM explore.events
   WHERE source_id = 'lrm_auctions' OR (source_id = 'interbank_market' AND source_sheet = 'Mdo Secundario')
   ORDER BY fuente, fecha, candidate_id")
ev$nivel_verificacion <- nivel_verificacion(ev$validation_tier, NA); ev$validation_tier <- NULL
escribir_csv(ev[ev$fuente == "interbank_market", ], "eventos_mercado_secundario_lrm_bonos.csv")
escribir_csv(ev[ev$fuente == "lrm_auctions", ], "eventos_subastas_lrm.csv")
cerrar(con)
