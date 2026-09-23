## Proyecto 22 · N1 (nuevo) — Política fiscal: ciclicidad, estabilizadores y multiplicadores
## Estado de operaciones mensual de la Administración Central (MEF, MEFP 2001, 2003-2026),
## ejecución presupuestaria (Anexo, Cuadro 36), ingresos de divisas y regalías de las
## binacionales (fuente de ingreso fiscal externa al ciclo), actividad, precios y deuda.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
imaep_original,economic_annex:cuadro_9:fc9a02c5dcc0573b3c038553,IMAEP serie original (1994-),Resultado: actividad mensual
imaep_sin_agro_bin_original,economic_annex:cuadro_9:50676b58c0b150737790879f,IMAEP sin agricultura ni binacionales (1994-),Resultado: actividad no agrícola (menos ruido climático)
imaep9a_desest,economic_annex:cuadro_9_a:b8f0c675b509f9ec047b421e,IMAEP serie ajustada (2014-),Resultado (robustez)
pib_real,economic_annex:cuadro_6:6929f799551947bd2eb72b88,PIB trimestral real (millones de Gs. de 2014),Resultado trimestral / normalización
pib_nominal,economic_annex:cuadro_6a:6929f799551947bd2eb72b88,PIB trimestral a precios corrientes (millones de Gs.),Normalización (% del PIB)
consumo_publico_real,economic_annex:cuadro_7:59a7eb27db3fdc934607e9fb,PIB por gasto (millones de Gs. de 2014): consumo público,Gasto público en cuentas nacionales
consumo_privado_real,economic_annex:cuadro_7:8ec08dadb3d7e0f27eb4c838,PIB por gasto (millones de Gs. de 2014): consumo privado,Resultado: respuesta del consumo
fbkf_real,economic_annex:cuadro_7:123120bfea36bd004d09cff4,PIB por gasto (millones de Gs. de 2014): formación bruta de capital fijo,Resultado: respuesta de la inversión
ipc_indice,economic_annex:cuadro_14:a5d7fc4139616340def083cc,IPC índice general,Deflactor
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,Tasa de política monetaria,Control: interacción fiscal-monetaria
pyg_usd_prom_venta,exchange_rates:usd_prom:190c4a9509f6c233bdc28928,PYG por USD promedio mensual,Conversión de ingresos binacionales y deuda externa
binacionales_divisas_total,economic_annex:cuadro_55:c53d182b059f53899aef8f2a,Ingreso de divisas de entidades binacionales: total (miles USD),Fuente de ingreso externa al ciclo
binacionales_divisas_itaipu,economic_annex:cuadro_55:4e4a5c19cb632666598e2107,Ingreso de divisas: Itaipú (miles USD),Fuente de ingreso externa al ciclo
binacionales_divisas_yacyreta,economic_annex:cuadro_55:76e9c8f666a595a4af127610,Ingreso de divisas: Yacyretá (miles USD),Fuente de ingreso externa al ciclo
deuda_ext_saldo,economic_annex:cuadro_59:e5c2a05e30651e100a3dc1e7,Deuda pública externa: saldo (miles USD),Sostenibilidad / financiamiento
deuda_ext_desembolsos,economic_annex:cuadro_59:f9c2e28f029232cc280c33bc,Deuda pública externa: desembolsos,Financiamiento
deuda_ext_servicio,economic_annex:cuadro_59:69307e03162e952cb9a46553,Deuda pública externa: pagos de capital e intereses,Servicio de deuda
dep_adm_central_bcp,economic_annex:cuadro_35:f907a1e096fb65a973d56cf0,Depósitos de la Administración Central en el BCP,Colchón de caja del Tesoro
eve_pib_anio_t,eve:pib_variacion_porcentual_del_pib:expectativa_ano_t,EVE (mediana): crecimiento esperado del PIB año t,Componente esperado del ciclo
soja_chicago,economic_annex:cuadro_49:898153a96bc9fe9ece97e94b,Soja Chicago USD/t,Control: términos de intercambio
", stringsAsFactors = FALSE, strip.white = TRUE)

con <- conectar()
bloques <- rbind(
  spec_por_hoja(con, "mef_central_government", "Serie", "mef", "Estado de operaciones de la Administración Central (MEFP 2001)"),
  spec_por_hoja(con, "economic_annex", "CUADRO 36", "ejec_ppto", "Ejecución presupuestaria de la Administración Central (Anexo BCP; etiquetas contaminadas)"))
spec <- rbind(dicc, bloques)
x <- extraer_escalares(con, spec)
escribir_series(x, spec)
cerrar(con)
