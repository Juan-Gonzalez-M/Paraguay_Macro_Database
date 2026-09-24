# Calendario de decisiones de política monetaria a partir de los comunicados del CEOMA/CPM (BCP)
# descargados del Internet Archive (python3 acquire.py archivo). No modifica los valores publicados:
# guarda la frase de la decisión TAL COMO APARECE y, aparte, lo que se lee de ella.
# Uso (desde esta carpeta): Rscript extraer_cpm.R      (requiere pdftotext, de poppler)
# Entrada: extraidos/cpm_documentos_control.csv + raw/archivo/cpm/*.pdf + inventory_archivo.csv
# Salida:  extraidos/cpm_calendario_decisiones.csv — una fila por COMUNICADO EN ESPAÑOL descargado
#   (los comunicados en inglés quedan en el control; no se usan para leer la decisión). El idioma se decide
#   por el TEXTO (el nombre del archivo no siempre lo dice: «..._Ingles.pdf», «CPM_EnglishFeb.pdf»).
# Reglas:
#   - fecha_comunicado: la fecha de encabezado «Asunción, d de mes de aaaa» (fecha de la reunión o del
#     comunicado; los comunicados no traen la HORA del anuncio, así que no se infiere).
#   - instrumento: a qué tasa se refiere la frase. Hasta 2012 el BCP anunciaba tasas de los Instrumentos de
#     Regulación Monetaria (IRM) a 14 días, curvas de IRM o la tasa de la FLIR, no una «TPM»; por eso las
#     columnas se llaman tasa_* y la fila dice el instrumento («tpm» solo si el texto habla de política monetaria).
#   - tasa_nueva: la tasa que el texto da como resultado; tasa_anterior: solo si el texto la dice («de X% a
#     Y%»); cambio_pb: solo si el texto lo dice. Nada se calcula a partir de otras filas. Si la frase trae
#     varias tasas (curva de plazos), tasa_nueva queda NA y la frase se conserva completa.
#   - Si algo no se puede leer, queda NA y la fila lleva una marca en «revisar» (nunca se descarta).

suppressPackageStartupMessages(library(data.table))
ctrl <- fread("extraidos/cpm_documentos_control.csv", encoding = "UTF-8")
inv <- fread("inventory_archivo.csv", encoding = "UTF-8")
es <- ctrl[path != "" & grepl("\\.pdf$", path, ignore.case = TRUE)]
es <- unique(es, by = "path")  # el mismo documento enlazado dos veces en la página
MESES <- c(enero = 1, febrero = 2, marzo = 3, abril = 4, mayo = 5, junio = 6, julio = 7, agosto = 8,
           septiembre = 9, setiembre = 9, octubre = 10, noviembre = 11, diciembre = 12)
num <- function(x) as.numeric(sub("[,.]", ".", x))
DEC <- "\\d{1,2}(?:[,.]\\d{1,2})?"

leer <- function(path) {
  t <- system2("pdftotext", c(shQuote(path), "-"), stdout = TRUE, stderr = FALSE)
  t <- gsub("\\s+", " ", paste(t, collapse = " "))
  f <- regmatches(t, regexpr("Asunci[oó]n,? +\\d{1,2} +(de +)?[A-Za-zé]+ +(del? +)?\\d{4}", t, perl = TRUE))
  # «[^.]» admite el punto decimal («6.75%») y el de una enumeración («decisiones: 1. Fijar…»), no el de fin de oración
  frase <- regmatches(t, regexpr("(?i)(decidi[oó]|decidido|acord[oó]|resolvi[oó]|siguientes? decisi[oó]n(es)?:)(?:[^.]|\\.(?=\\d)|(?<=\\s\\d)\\.){0,300}?(anual|%)(?:[^.;]|\\.(?=\\d)){0,40}", t, perl = TRUE))
  # Segundo intento (2010–2011): decisión sin tasa explícita («decidió no modificar…», «resolvió mantener los niveles…»)
  if (!length(frase)) frase <- regmatches(t, regexpr("(?i)(decidi[oó]|resolvi[oó])(?:[^.]|\\.(?=\\d)){0,600}\\.", t, perl = TRUE))
  es <- grepl("pol[ií]tica monetaria|tasa de inter[eé]s", t, ignore.case = TRUE)
  data.table(idioma_texto = if (es) "es" else "otro", n_caracteres = nchar(t), fecha_publicada = if (length(f)) f else NA_character_,
             frase_decision = if (length(frase)) trimws(frase) else NA_character_)
}
x <- cbind(es[, .(uuid, nombre_publicado, url_bcp, wayback_timestamp, path)], rbindlist(lapply(es$path, leer)))
x <- merge(x, inv[, .(path, sha256)], by = "path", all.x = TRUE, sort = FALSE)
cat("PDF descargados:", nrow(x), "| en español por el texto:", sum(x$idioma_texto == "es"), "| otros (inglés):", sum(x$idioma_texto != "es"), "\n")
x <- x[idioma_texto == "es"][, idioma_texto := NULL]

# Fecha publicada -> fecha ISO
p <- regmatches(x$fecha_publicada, regexec("(\\d{1,2}) +(?:de +)?([A-Za-zé]+) +(?:del? +)?(\\d{4})", x$fecha_publicada, perl = TRUE))
x[, fecha_comunicado := as.IDate(vapply(p, function(v) if (length(v) == 4 && tolower(v[3]) %in% names(MESES))
  sprintf("%s-%02d-%02d", v[4], MESES[[tolower(v[3])]], as.integer(v[2])) else NA_character_, ""))]

# Lectura de la frase
x[, accion := fcase(grepl("(?i)mantener|mantiene|no modificar", frase_decision, perl = TRUE), "mantener",
                    grepl("(?i)reducir|disminuir|recortar|bajar", frase_decision, perl = TRUE), "reducir",
                    grepl("(?i)aumentar|incrementar|elevar|subir", frase_decision, perl = TRUE), "aumentar",
                    default = NA_character_)]
x[, instrumento := fcase(grepl("(?i)pol[ií]tica monetaria", frase_decision, perl = TRUE), "tpm",
                        grepl("(?i)curva|plazos", frase_decision, perl = TRUE), "curva_irm",
                        grepl("(?i)FLIR|Facilidad de Liquidez", frase_decision, perl = TRUE), "flir",
                        grepl("(?i)14 d[ií]as", frase_decision, perl = TRUE), "irm_14d", default = NA_character_)]
x[, votacion := fcase(grepl("(?i)unanimidad|un[aá]nime", frase_decision, perl = TRUE), "unanimidad",
                      grepl("(?i)mayor[ií]a", frase_decision, perl = TRUE), "mayoria", default = NA_character_)]
tasas <- regmatches(x$frase_decision, gregexpr(paste0(DEC, " ?%"), x$frase_decision, perl = TRUE))
x[, n_tasas := lengths(tasas)]
# Dos tasas solo se leen como «anterior → nueva» si el texto dice «de X% a Y%»; si no (p. ej., 14 y 35 días), NA.
x[, de_a := grepl(paste0("\\bde ", DEC, " ?%( anual)? a \\d"), frase_decision, perl = TRUE) & n_tasas == 2]
x[, tasa_nueva := mapply(function(v, da) if (length(v) == 1 || da) num(sub(" ?%", "", v[length(v)])) else NA_real_, tasas, de_a)]
x[, tasa_anterior := mapply(function(v, da) if (da) num(sub(" ?%", "", v[1])) else NA_real_, tasas, de_a)]
x[, cambio_pb := suppressWarnings(as.numeric(sub(".*?(\\d{1,3}) puntos? bas[ei].*", "\\1", frase_decision, perl = TRUE)))]
x[!grepl("puntos? bas[ei]", frase_decision), cambio_pb := NA_real_]

# Marcas de revisión (nada se descarta)
x[, revisar := trimws(paste(
  fifelse(n_caracteres < 200, "sin_texto(pdf_escaneado?)", ""),
  fifelse(is.na(fecha_comunicado), "sin_fecha", ""),
  fifelse(is.na(frase_decision), "sin_frase_decision", ""),
  fifelse(!is.na(frase_decision) & is.na(accion), "accion_no_leida", ""),
  fifelse(!is.na(frase_decision) & n_tasas == 0, "sin_tasa", ""),
  fifelse(n_tasas > 2 | (n_tasas == 2 & !de_a), "varias_tasas", ""),
  fifelse(!is.na(frase_decision) & is.na(instrumento), "instrumento_no_leido", ""),
  fifelse(accion %in% "mantener" & !is.na(cambio_pb), "mantener_con_pb", "")))]
x[, revisar := gsub(" +", ";", revisar)]
# Coherencia interna (solo control; no corrige nada): cambio declarado vs. tasas declaradas
x[!is.na(tasa_anterior) & !is.na(cambio_pb) & abs(abs(tasa_nueva - tasa_anterior) * 100 - cambio_pb) > 0.01,
  revisar := paste0(revisar, fifelse(revisar == "", "", ";"), "pb_no_coincide_con_tasas")]
dup <- x[!is.na(fecha_comunicado), .N, by = fecha_comunicado][N > 1, fecha_comunicado]
x[fecha_comunicado %in% dup, revisar := paste0(revisar, fifelse(revisar == "", "", ";"), "fecha_repetida(varios_documentos)")]

setorder(x, fecha_comunicado, nombre_publicado, na.last = TRUE)
out <- x[, .(fecha_comunicado, fecha_publicada, instrumento, accion, tasa_anterior, tasa_nueva, cambio_pb, votacion, frase_decision,
             revisar, nombre_publicado, uuid, url_bcp, wayback_timestamp, path, sha256)]
fwrite(out, "extraidos/cpm_calendario_decisiones.csv")
cat("Comunicados en español leídos:", nrow(out), "| con fecha:", sum(!is.na(out$fecha_comunicado)),
    "| con tasa_nueva:", sum(!is.na(out$tasa_nueva)), "| instrumento tpm:", sum(out$instrumento %in% "tpm"), "| a revisar:", sum(out$revisar != ""), "\n")
print(out[revisar != "", .N, by = revisar])
cat("Rango:", format(range(out$fecha_comunicado, na.rm = TRUE)), "\n")
