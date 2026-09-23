## Proyecto 32 · N11 (nuevo) — Ajustes del salario mínimo: precios de servicios, salarios e informalidad
## La base trae la vigencia de cada tramo del salario mínimo (Cuadro 11, 1980-2026). Se usan los
## ajustes fechados como eventos sobre IPC de servicios intensivos en mano de obra, salarios y EPHC.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
sm_nominal_anual,economic_annex:cuadro_11:1c766cc1e040c500fff07261,Salario mínimo legal nominal (anual),Tratamiento (nivel)
sm_real_anual,economic_annex:cuadro_11:0e62be6692e50c117e06a8d1,Salario mínimo legal real (anual),Tratamiento real
sm_indice_nominal_anual,economic_annex:cuadro_11:a8a612a7b8807f5a690d9615,Índice de salario mínimo nominal (anual),Tratamiento
sm_indice_real_anual,economic_annex:cuadro_11:979d94a32433663252e9416c,Índice de salario mínimo real (anual),Tratamiento
ipc_servicios,economic_annex:cuadro_14_b:b4951083ce1d33a5c7c4d94b,IPC servicios,Resultado: servicios intensivos en mano de obra
ipc_renta,economic_annex:cuadro_14_b:b9ef206b3a9690b473eae490,IPC renta (alquileres),Placebo parcial
ipc_total_bienes,economic_annex:cuadro_14_b:b50f5e050a7ce09373d58545,IPC total de bienes,Placebo (bienes transables)
ipc_restaurantes_hoteles,economic_annex:cuadro_14:477a8476325a23767c3821b5,IPC restaurantes y hoteles,Resultado: intensivo en mano de obra
ipc_educacion,economic_annex:cuadro_14:664697ada1467bc94b2cca4d,IPC educación,Resultado
ipc_salud,economic_annex:cuadro_14:d20adc49bb953f69c865050d,IPC gasto en salud,Resultado
ipc_confeccion_ropas,economic_annex:cuadro_16:b7a2d1b99a7fdd43f22dfbb1,IPC vestido: confección de ropas (servicio),Resultado: servicio intensivo en mano de obra
ipc_indice,economic_annex:cuadro_14:a5d7fc4139616340def083cc,IPC índice general,Deflactor
ipc_var_mensual,economic_annex:cuadro_15:1720dedc33bdbea3951d2913,Inflación total mensual,Resultado agregado
ipc_subyacente_mensual,economic_annex:cuadro_15:dfecdb75e556917955185f87,Inflación subyacente mensual,Resultado agregado
eve_inf_anio_t,eve:bloque_de_inflacion:expectativa_ano_t,EVE (mediana): inflación esperada año t,Canal de expectativas
imaep_original,economic_annex:cuadro_9:fc9a02c5dcc0573b3c038553,IMAEP serie original,Control
", stringsAsFactors = FALSE, strip.white = TRUE)

con <- conectar()
bloques <- rbind(
  spec_por_hoja(con, "economic_annex", "CUADRO 12", "salarios", "Índice de sueldos y salarios por sector (semestral)", frecuencias = "semiannual"),
  spec_por_hoja(con, "ine_ephc", "FORMALIDAD", "ephc_formalidad", "EPHC: ocupados formales y totales por categoría", frecuencias = "quarterly"),
  spec_por_hoja(con, "ine_ephc", "Tasas", "ephc_tasas", "EPHC: tasas de fuerza de trabajo", frecuencias = "quarterly"),
  spec_por_hoja(con, "ine_ephc", "INGRESOS_CATE", "ephc_ingreso", "EPHC: ingreso promedio por categoría ocupacional (no comprobado)", frecuencias = "quarterly"))
spec <- rbind(dicc, bloques)
x <- extraer_escalares(con, spec)
escribir_series(x, spec)
message("Tramos de vigencia del salario mínimo (eventos del Cuadro 11)...")
sm <- dbGetQuery(con, "SELECT CAST(reference_period_start AS DATE) AS fecha, CAST(reference_period_end AS DATE) AS fecha_fin,
                              value AS salario_minimo_gs, candidate_id, source_row
                         FROM explore.events WHERE source_id = 'economic_annex' AND source_sheet = 'CUADRO 11'
                        ORDER BY fecha")
sm$variacion_pct <- c(NA, 100 * diff(log(sm$salario_minimo_gs)))
sm$es_ajuste <- !is.na(sm$variacion_pct) & sm$variacion_pct > 0
sm$nivel_verificacion <- "Estructura especial (provisional)"
escribir_csv(sm, "salario_minimo_tramos_vigencia.csv")
leer_manual("decretos_salario_minimo",
            c("fecha_decreto", "fecha_vigencia", "monto_gs", "norma", "criterio_ajuste", "fuente", "estado_verificacion"))
cerrar(con)
