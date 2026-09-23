## Proyecto 21 · F5 — Inflación desigual (N9) y comunicación experimental (N10)
## N9: índices de precios por división, grupo y producto para construir índices por grupos
## de hogares. Los ponderadores por grupo NO están en la base (EIGH/INE). N10: sin datos.

dicc <- read.csv(text = "
serie,candidate_id,descripcion,rol
ipc_var_mensual,economic_annex:cuadro_15:1720dedc33bdbea3951d2913,Inflación total mensual (oficial),Benchmark: inflación promedio
ipc_var_interanual,economic_annex:cuadro_15:080dbf95a46f3bcb97aeb69d,Inflación total interanual (oficial),Benchmark: inflación promedio
ipc_subyacente_interanual,economic_annex:cuadro_15:e2716d5d388cb5491db427df,Inflación subyacente interanual,Benchmark
ipc_transables_sin_fyv,economic_annex:cuadro_14_a:1f5d8129468fa2246f4ef067,IPC bienes transables sin frutas y verduras (índice),Descomposición de la brecha
ipc_no_transables,economic_annex:cuadro_14_a:14eda4efc6655f8715834492,IPC bienes no transables (índice; la base agrega 'Inter.' a la etiqueta),Descomposición de la brecha
ipc_importados_sin_fyv,economic_annex:cuadro_14_a:907533be614b9497d5409ff9,IPC productos importados sin frutas y verduras (índice),Descomposición de la brecha
ipc_nacionales,economic_annex:cuadro_14_a:9288e17840a5058852512941,IPC productos nacionales (índice),Descomposición de la brecha
ipc_bienes_alimenticios,economic_annex:cuadro_14_b:8af2fc023074afcb93ad5ee9,IPC bienes alimenticios (índice),Componente con peso alto en hogares pobres
ipc_alimenticios_sin_fyv,economic_annex:cuadro_14_b:bca046f33bc09e8c57fbc832,IPC bienes alimenticios sin frutas y verduras (índice),Componente
ipc_bienes_no_alimenticios,economic_annex:cuadro_14_b:cc2b8dbb719ae1ef61dd7875,IPC bienes distintos de alimentos (índice),Componente
ipc_servicios,economic_annex:cuadro_14_b:b4951083ce1d33a5c7c4d94b,IPC servicios (índice),Componente
ipc_renta,economic_annex:cuadro_14_b:b9ef206b3a9690b473eae490,IPC renta (alquileres; índice),Componente (inquilinos vs propietarios)
ipc_servicios_y_renta,economic_annex:cuadro_14_b:585affaf4bff829d27875bb5,IPC servicios y renta (índice),Componente
ipc_total_bienes,economic_annex:cuadro_14_b:b50f5e050a7ce09373d58545,IPC total de bienes (índice),Componente
ipc_sin_alimentos,economic_annex:cuadro_14_b:7322f9d55a73329aaf3ce74d,IPC sin alimentos (índice),Componente
ipcsae,economic_annex:cuadro_14_b:51ac506bc66449221b1c86ab,IPCSAE (sin alimentos ni energía; índice),Componente
ipc_sin_alim_comb_tarif,economic_annex:cuadro_14_b:ab458e86db5132b2311595e4,IPC sin alimentos combustibles ni servicios tarifados (índice),Componente
salario_minimo_nominal,economic_annex:cuadro_11:16fa8951007876479ada2d98,Salario mínimo legal nominal (índice),Ingreso de hogares de menores recursos
indice_salarios,economic_annex:cuadro_12:1e8b0cfe36d2a21eb507542c,Índice de sueldos y salarios: general (semestral),Ingreso laboral
", stringsAsFactors = FALSE, strip.white = TRUE)

con <- conectar()
bloques <- rbind(
  spec_por_hoja(con, "economic_annex", "CUADRO 14", "ipc_div", "Índice por división COICOP (base dic-2017)"),
  spec_por_hoja(con, "economic_annex", "CUADRO 14 c", "ipc_admin", "Bienes libres vs administrados"),
  spec_por_hoja(con, "economic_annex", "CUADRO 16", "ipc_grupo", "Índice por grupo de gasto"),
  spec_por_hoja(con, "economic_annex", "CUADRO 16 (Cont.)", "ipc_grupo_cont", "Índice por grupo de gasto"),
  spec_por_hoja(con, "economic_annex", "CUADRO 16 a", "ipc_carne", "Índice por corte de carne vacuna"),
  spec_por_hoja(con, "economic_annex", "CUADRO 13", "tarifa", "Índice de tarifas y precios regulados (etiquetas de la base cruzadas: ver supuestos)"),
  spec_por_hoja(con, "economic_annex", "CUADRO 13 a", "tarifa_gasoil", "Índice de precio del gasoil (el título del cuadro dice IPC empalmado; por valores es gasoil)"),
  spec_por_hoja(con, "ine_ephc", "INGRESOS_CATE", "ephc_ingreso", "Ingreso promedio por área/categoría/sexo (caracterización de grupos)",
                frecuencias = "quarterly"))
spec <- rbind(dicc, bloques)
x <- extraer_escalares(con, spec)
escribir_series(x, spec)

message("Ponderadores del IPC (FMI; canasta 2005) como referencia...")
pesos <- dbGetQuery(con, "
  SELECT s.series_code AS codigo_fmi, c.candidate_id, CAST(r.period_start AS DATE) AS fecha, r.value AS peso
    FROM staging.imf_series_snapshot s
    JOIN catalog.series c ON c.candidate_id = s.series_id
    JOIN main.v_series_research r ON r.series_id = c.candidate_id
   WHERE s.source_id = 'imf_cpi' AND s.series_code LIKE 'PRY.CPI.%.WGT_PT.M'
   ORDER BY codigo_fmi, fecha")
pesos$nivel_verificacion <- "Preliminar"
escribir_csv(pesos, "ponderadores_ipc_fmi_2005.csv")
cerrar(con)
