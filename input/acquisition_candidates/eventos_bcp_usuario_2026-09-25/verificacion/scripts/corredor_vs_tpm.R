# Contraste: cambios diarios de FPD/FPL vs. TPM vigente según el calendario del CPM (vigencia al día hábil siguiente).
# Uso (desde la raíz del repo): Rscript input/acquisition_candidates/eventos_bcp_usuario_2026-09-25/verificacion/scripts/corredor_vs_tpm.R
suppressPackageStartupMessages(library(data.table))
ch <- fread("proyectos/25_n4_sorpresas_monetarias/datos/cambios_corredor_inferidos.csv")
ch[, s := fifelse(grepl("deposito", serie), "FPD", "FPL")]
w <- dcast(ch, fecha ~ s, value.var = c("tasa_anterior", "tasa_nueva", "cambio_pb"))
cal <- rbind(fread("input/acquisition_candidates/web_brechas_2026-09-23/extraidos/cpm_calendario_decisiones.csv")[instrumento == "tpm", .(f = as.IDate(fecha_comunicado), tpm = tasa_nueva)],
             fread("input/acquisition_candidates/web_brechas_2026-09-23/extraidos/cpm_decisiones_encontradas.csv")[instrumento == "tpm", .(f = as.IDate(fecha_comunicado), tpm = as.numeric(tasa_nueva))])
cal[f == as.IDate("2023-09-20"), tpm := 8.00]   # decisión C01 del usuario
cal <- cal[!is.na(tpm)][order(f)]
# TPM vigente el día anterior a cada cambio del corredor (anuncio desde las 15 h: vigencia el día hábil siguiente)
w[, fecha := as.IDate(fecha)]
w[, tpm_vig := sapply(fecha, function(d) { x <- cal[f < d]; if (nrow(x)) tail(x$tpm, 1) else NA_real_ })]
w[, tpm_ult_dec := sapply(fecha, function(d) { x <- cal[f < d]; if (nrow(x)) as.character(tail(x$f, 1)) else NA_character_ })]
w[, `:=`(spread_fpd = tasa_nueva_FPD - tpm_vig, spread_fpl = tasa_nueva_FPL - tpm_vig)]
print(w[, .(fecha, FPD = paste(tasa_anterior_FPD, "->", tasa_nueva_FPD), FPL = paste(tasa_anterior_FPL, "->", tasa_nueva_FPL), tpm_vig, tpm_ult_dec, spread_fpd, spread_fpl)], nrows = 200)
fwrite(w, "input/acquisition_candidates/eventos_bcp_usuario_2026-09-25/verificacion/corredor_vs_tpm.csv")
