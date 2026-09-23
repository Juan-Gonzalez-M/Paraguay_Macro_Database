## Proyecto 24 · N3 (nuevo) — Paraguay en el panel regional: shocks globales, reservas,
## intervención y vulnerabilidad financiera en 9 países sudamericanos (datos del FMI en la base).

paises <- c(ARG = "Argentina", BOL = "Bolivia", BRA = "Brasil", CHL = "Chile", COL = "Colombia",
            ECU = "Ecuador", PER = "Perú", PRY = "Paraguay", URY = "Uruguay")

plantillas <- read.csv(text = "
indicador,codigo,descripcion,rol
cuenta_corriente,{C}.NETCD_T.CAB.USD.Q,Saldo de cuenta corriente (millones USD; trimestral),Vulnerabilidad externa
cuenta_financiera_sin_reservas,{C}.NNAFANIL_T.FABXRRI.USD.Q,Saldo de la cuenta financiera excluyendo reservas (millones USD),Flujos de capital netos
ied_pasivos,{C}.L_NIL_T.D_F.USD.Q,Inversión directa: incurrimiento neto de pasivos (millones USD),Entradas de capital (IED)
cartera_pasivos,{C}.L_NIL_T.P_F.USD.Q,Inversión de cartera: incurrimiento neto de pasivos (millones USD),Entradas de capital (cartera)
otra_inversion_pasivos,{C}.L_NIL_T.O_F.USD.Q,Otra inversión: incurrimiento neto de pasivos (millones USD),Entradas de capital (préstamos/depósitos)
reservas_flujo_bop,{C}.A_T.R_F.USD.Q,Activos de reserva: transacciones de balanza de pagos (millones USD),Acumulación de reservas
pib_nominal,{C}.B1GQ.V.NSA.XDC.Q,PIB a precios corrientes (moneda local; trimestral sin desestacionalizar),Normalización (% del PIB)
pib_real,{C}.B1GQ.Q.NSA.XDC.Q,PIB a precios constantes (moneda local; trimestral sin desestacionalizar),Resultado: actividad
fsi_mora,{C}.S12CFSI.AQ12_CFSI_PT.Q,FSI: préstamos en mora / préstamos brutos (%),Resultado: riesgo de crédito
fsi_capital,{C}.S12CFSI.FSI688_CFSI_PT.Q,FSI: capital regulatorio / activos ponderados por riesgo (%),Colchón bancario
fsi_roa,{C}.S12CFSI.ROA_CFSI_PT.Q,FSI: rentabilidad sobre activos (%),Resultado bancario
fsi_liquidez,{C}.S12CFSI.FSI765_CFSI_PT.Q,FSI: activos líquidos / pasivos de corto plazo (%),Colchón de liquidez
fsi_prestamos_me,{C}.S12CFSI.FSI131_AFSI_PT.Q,FSI: préstamos en moneda extranjera / préstamos totales (%),Dolarización del crédito
fsi_posicion_abierta_me,{C}.S12CFSI.FSI555_CFSI_PT.Q,FSI: posición abierta neta en ME / capital (%),Descalce cambiario bancario
reservas_sin_oro,{C}.RXF11_REVS.USD.M,Reservas internacionales sin oro (millones USD; mensual),Colchón de reservas
tipo_cambio_prom,{C}.XDC_USD.PA_RT.M,Tipo de cambio: moneda local por USD (promedio del período),Resultado: tipo de cambio
ipc,{C}.CPI._T.IX.M,IPC índice (todos los ítems),Resultado: inflación
tcre,{C}.REER_IX_RY2010_ACW_RCPI.M,Tipo de cambio real efectivo (2010=100),Competitividad
terminos_intercambio_commodities,{C}.CEPI_CTOTX_TX.R_RW_IX.M,Índice de precios de commodities exportados (pesos móviles),Shock de términos de intercambio (país-específico)
tasa_politica,{C}.MFS166_RT_PT_A_PT.M,Tasa de política monetaria (% anual),Respuesta de política
intervencion_spot_proxy,{C}.FXI_SPOT_PROXY_USD.M,Intervención cambiaria spot aproximada (FMI WPFXI; millones USD),Respuesta de política cambiaria
intervencion_total_pib,{C}.FXI_BROAD_PROXY_GDP.M,Intervención cambiaria total aproximada (% del PIB promedio 3 años),Respuesta de política cambiaria
", stringsAsFactors = FALSE, strip.white = TRUE)

externos <- read.csv(text = "
serie,id,agregacion,unidad,descripcion,rol
global_vix_m,VIXCLS,avg,INDEX_POINTS,FRED: VIX promedio mensual,Shock global común
global_fed_funds,FEDFUNDS,,PERCENT,FRED: tasa efectiva de fondos federales,Shock global común
global_dolar_amplio_m,TWEXBGSMTH,,INDEX,FRED: índice nominal amplio del dólar,Shock global común
global_commodities,PALLFNFINDEXM,,INDEX,FRED/FMI: índice de precios de todas las commodities,Shock global común
global_ust_10a,DGS10,avg,PERCENT,FRED: rendimiento Tesoro EE.UU. 10 años (promedio mensual),Shock global común
", stringsAsFactors = FALSE, strip.white = TRUE, na.strings = "")

con <- conectar()
cods <- do.call(rbind, lapply(names(paises), function(p)
  data.frame(pais = p, indicador = plantillas$indicador, codigo = gsub("{C}", p, plantillas$codigo, fixed = TRUE),
             descripcion = plantillas$descripcion, rol = plantillas$rol, stringsAsFactors = FALSE)))
ids <- dbGetQuery(con, sprintf(
  "SELECT s.series_code AS codigo, s.series_id AS candidate_id
     FROM staging.imf_series_snapshot s JOIN catalog.series c ON c.candidate_id = s.series_id
    WHERE s.obs_measure = 'OBS_VALUE' AND s.series_code IN (%s)
      AND EXISTS (SELECT 1 FROM main.v_series_research r WHERE r.series_id = s.series_id)", sql_lista(cods$codigo)))
ids <- ids[!duplicated(ids$codigo), ]
cods <- merge(cods, ids, by = "codigo")
cods <- cods[order(match(cods$indicador, plantillas$indicador), cods$pais), ]
message(nrow(cods), " combinaciones país-indicador disponibles de ", length(paises) * nrow(plantillas))
spec <- data.frame(serie = paste0(tolower(cods$pais), "_", cods$indicador), candidate_id = cods$candidate_id,
                   descripcion = paste0(paises[cods$pais], ": ", cods$descripcion, " [", cods$codigo, "]"),
                   rol = cods$rol, stringsAsFactors = FALSE)
x <- extraer_escalares(con, spec)
ext <- leer_fred_bloque(externos)
escribir_series(rbind(x, ext), rbind(spec[, c("serie", "descripcion", "rol")], externos[, c("serie", "descripcion", "rol")]))

## Panel largo país × indicador × fecha (formato cómodo para estimación con efectos fijos)
pan <- x
pan$pais <- toupper(sub("_.*$", "", pan$serie)); pan$indicador <- sub("^[a-z]{3}_", "", pan$serie)
pan <- pan[, c("fecha", "fecha_fin", "frecuencia", "pais", "indicador", "valor", "unidad", "nivel_verificacion", "candidate_id")]
for (fr in unique(pan$frecuencia))
  escribir_csv(pan[pan$frecuencia == fr, ], paste0("panel_regional_", fr, ".csv"))
disp <- as.data.frame.matrix(table(cods$indicador, cods$pais))
disp <- cbind(indicador = rownames(disp), disp)
escribir_csv(disp[match(plantillas$indicador[plantillas$indicador %in% disp$indicador], disp$indicador), ],
             "disponibilidad_pais_indicador.csv", fecha_col = "none")
cerrar(con)
