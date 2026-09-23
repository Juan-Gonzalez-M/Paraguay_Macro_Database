## Proyecto 23 · N2 (nuevo) — Mercado laboral, informalidad y ciclo
## Anexo trimestral de la EPHC (INE, 2017-2026) completo, más actividad, PIB sectorial,
## precios, salario mínimo, índice de salarios y confianza del consumidor.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
imaep_original,economic_annex:cuadro_9:fc9a02c5dcc0573b3c038553,IMAEP serie original (mensual; agregar a trimestre),Ciclo (Okun)
imaep9a_desest,economic_annex:cuadro_9_a:b8f0c675b509f9ec047b421e,IMAEP serie ajustada (mensual),Ciclo (Okun)
pib_real,economic_annex:cuadro_6:6929f799551947bd2eb72b88,PIB trimestral real (millones de Gs. de 2014),Ciclo trimestral
pib_real_agricultura,economic_annex:cuadro_6:6d027c95b5cac6d53c10f8f0,PIB trimestral real: agricultura,Ciclo sectorial
pib_real_manufactura,economic_annex:cuadro_6:92c49007aa191278ef2a7c1f,PIB trimestral real: manufactura,Ciclo sectorial
pib_real_construccion,economic_annex:cuadro_6:554e1192b3c7c926c3e3d4f6,PIB trimestral real: construcción,Ciclo sectorial
pib_real_servicios,economic_annex:cuadro_6:eb584ca02fd165d0f293d6b0,PIB trimestral real: servicios,Ciclo sectorial
ipc_indice,economic_annex:cuadro_14:a5d7fc4139616340def083cc,IPC índice general,Deflactor / curva de Phillips de salarios
ipc_var_interanual,economic_annex:cuadro_15:080dbf95a46f3bcb97aeb69d,Inflación total interanual,Curva de Phillips
salario_minimo_nominal,economic_annex:cuadro_11:16fa8951007876479ada2d98,Salario mínimo legal nominal (índice),Salario institucional
indice_salarios,economic_annex:cuadro_12:1e8b0cfe36d2a21eb507542c,Índice de sueldos y salarios: general (semestral),Salario formal
icc,icc:icc,Índice de confianza del consumidor,Percepción de hogares
tpm,economic_annex:cuadro_19:af96532c37dd31a3b75c4a78,Tasa de política monetaria,Control
", stringsAsFactors = FALSE, strip.white = TRUE)

con <- conectar()
hojas <- c("Tasas", "Población Total", "CARACTERÍSTICAS_OCU", "SECTORECONÓMICO", "CATEGORÍAOCUPACIONAL",
           "TAMAÑODEEMPRESA", "FORMALIDAD", "HORASHABITUALES", "PROMEDIO DE HORAS", "TIEMPOEXPERIENCIA",
           "PROMEDIODEAÑODEESTUDIO", "INGRESOS_CATE", "INGRESOS_SECTOR", "INGRESOS_OCUP", "INGRESOSPORHORAS")
bloques <- do.call(rbind, lapply(hojas, function(h)
  spec_por_hoja(con, "ine_ephc", h, paste0("ephc_", slug(h, 14)), paste0("EPHC (INE) hoja ", h), frecuencias = "quarterly")))
spec <- rbind(dicc, bloques)
x <- extraer_escalares(con, spec)
escribir_series(x, spec)
cerrar(con)
