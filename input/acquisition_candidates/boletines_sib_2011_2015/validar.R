# Controles del panel por entidad (extraer_panel.R). Solo reporta: no corrige ni descarta nada.
# Uso (desde esta carpeta): Rscript validar.R      -> extraidos/validacion_*.csv y resumen en pantalla
#   A. Moneda: MN + ME = TOTAL, en las tablas con la entidad en columnas.
#   B. Agregación: suma de entidades = total del sistema publicado, por archivo, hoja y rubro (o columna),
#      solo en montos (ratios, participaciones, variaciones, rankings y cantidades no suman).
#      En financieras, el Fondo Ganadero se publica FUERA del «Total sistema financieras» (hay una columna
#      aparte «Con participación del Fondo Ganadero»), así que no se suma.
#   C. Puente entre diseños: en 2013-09, 2013-10 y 2013-11 hay boletín clásico y nuevo del mismo mes;
#      se compara el TOTAL ACTIVO de cada entidad en ambos.
#   D. Revisiones: las hojas evolutivas del diseño nuevo repiten 12 meses; se compara el valor de un mes
#      publicado en distintos boletines (vintages).

suppressPackageStartupMessages({library(data.table); library(arrow)})
P <- as.data.table(read_parquet("extraidos/panel_entidades.parquet"))
TOT_SIS <- c("SISTEMA", "TOTAL SISTEMA", "TOTAL SISTEMA FINANCIERAS", "TOTAL EMPRESAS FINANCIERAS", "TOTAL FINANCIERAS")
res <- list()

# A ------------------------------------------------------------------------------------------------------------
a <- P[eje == "columna" & moneda %in% c("MN", "ME", "TOTAL")]
wa <- dcast(a, archivo + hoja + fila + entidad_clave ~ moneda, value.var = "valor", fun.aggregate = function(v) v[1])
wa <- wa[!is.na(MN) & !is.na(ME) & !is.na(TOTAL)][, dif := TOTAL - (MN + ME)]
fwrite(wa[abs(dif) > 0.01], "extraidos/validacion_A_moneda.csv")
res$A <- data.table(control = "A. MN + ME = TOTAL", casos = nrow(wa), fallan = wa[abs(dif) > 0.01, .N],
                    detalle = sprintf("dif. máx. %.2f millones", wa[, max(abs(dif))]))

# B ------------------------------------------------------------------------------------------------------------
b1 <- P[eje == "columna" & (is.na(moneda) | moneda == "TOTAL")]
g1 <- b1[, .(suma = sum(valor[!es_agregado & entidad_clave != "FONDO GANADERO"]), n = sum(!es_agregado),
             sistema = valor[entidad_clave %in% TOT_SIS][1]), by = .(tipo, diseno, archivo, hoja, fila, concepto, seccion)]
b2 <- P[eje == "fila"]
g2 <- b2[, .(suma = sum(valor[!es_agregado & entidad_clave != "FONDO GANADERO"]), n = sum(!es_agregado),
             sistema = valor[entidad_clave %in% TOT_SIS][1]), by = .(tipo, diseno, archivo, hoja, columna, concepto)]
gb <- rbind(g1[, eje := "entidad_en_columna"], g2[, eje := "entidad_en_fila"], fill = TRUE)[!is.na(sistema) & n >= 2]
# Solo montos: se excluyen ratios, participaciones, variaciones, rankings, morosidad y cantidades (no suman).
ctx <- unique(P[, .(archivo, hoja, titulo_hoja)])[, .(txt = gsub("\\d{1,2}[/-]\\d{1,2}[/-]\\d{4}", "", paste(titulo_hoja, collapse = " "))), by = .(archivo, hoja)]
gb <- merge(gb, ctx, by = c("archivo", "hoja"), all.x = TRUE)
# (el título se arma uniendo renglones con « / », así que la barra solo cuenta dentro del concepto)
NO_MONTO <- "(?i)(%|porcentaje|part\\b|particip|variaci|veces|ranking|morosidad|ratio|indicador|cantidad|pl[aá]sticos|dependencias|cajeros|personal|calificaci|anual)"
gb[, es_monto := !grepl(NO_MONTO, paste(txt, concepto, seccion, hoja), perl = TRUE) &
                 !grepl("/", gsub("\\d{1,2}[/-]\\d{1,2}[/-]\\d{4}", "", concepto))]
gb[, txt := NULL]
gb[, rel := (suma - sistema) / pmax(abs(sistema), 1)]
fwrite(gb[es_monto & abs(rel) > 0.001], "extraidos/validacion_B_agregacion.csv")
res$B <- gb[es_monto == TRUE, .(control = paste0("B. Σ entidades = sistema (", tipo, ", ", diseno, ")"), casos = .N, fallan = sum(abs(rel) > 0.001),
                detalle = sprintf("%.1f%% cierra", 100 * mean(abs(rel) <= 0.001))), by = .(tipo, diseno)][, .(control, casos, fallan, detalle)]

# C ------------------------------------------------------------------------------------------------------------
P[, concepto_n := gsub("\\s+", " ", gsub("\\s*>\\s*", " ", toupper(concepto)))]
c1 <- P[!es_agregado & grepl("^TOTAL ACTIVO\\b", concepto_n) & (is.na(moneda) | moneda == "TOTAL") &
          format(as.IDate(fecha_corte), "%Y-%m") %in% c("2013-09", "2013-10", "2013-11") & periodo == format(as.IDate(fecha_corte), "%Y-%m")]
c1 <- c1[, .(valor = valor[1]), by = .(tipo, periodo, diseno, entidad_clave)]
wc <- dcast(c1, tipo + periodo + entidad_clave ~ diseno, value.var = "valor")
if (all(c("clasico", "nuevo") %in% names(wc))) {
  wc <- wc[!is.na(clasico) & !is.na(nuevo)][, rel := (nuevo - clasico) / pmax(abs(clasico), 1)]
  fwrite(wc, "extraidos/validacion_C_puente_disenos.csv")
  res$C <- data.table(control = "C. Total activo: clásico = nuevo (2013-09..11)", casos = nrow(wc), fallan = wc[abs(rel) > 0.001, .N],
                      detalle = sprintf("dif. rel. máx. %.4f%%", 100 * wc[, max(abs(rel))]))
}

# D ------------------------------------------------------------------------------------------------------------
d1 <- P[!is.na(periodo_publicado) & diseno == "nuevo"]
d1 <- d1[, .(valor = valor[1]), by = .(tipo, titulo_hoja = sub(" / \\d{2}/\\d{2}/\\d{4}.*", "", titulo_hoja), entidad_clave, periodo, fecha_corte)]
d1[, n_vint := .N, by = .(tipo, titulo_hoja, entidad_clave, periodo)]
dd <- d1[n_vint > 1, .(min = min(valor), max = max(valor), vintages = .N), by = .(tipo, titulo_hoja, entidad_clave, periodo)]
dd[, revisado := abs(max - min) > 0.01]
fwrite(dd[revisado == TRUE], "extraidos/validacion_D_revisiones.csv")
res$D <- data.table(control = "D. Mismo mes en varios boletines (hojas evolutivas)", casos = nrow(dd), fallan = dd[revisado == TRUE, .N],
                    detalle = "«fallan» = mes revisado entre boletines (no es error: son vintages)")

R <- rbindlist(res, fill = TRUE); fwrite(R, "extraidos/validacion_resumen.csv"); print(R)
