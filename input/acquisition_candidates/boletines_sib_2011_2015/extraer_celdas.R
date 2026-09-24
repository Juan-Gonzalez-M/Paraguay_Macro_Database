# Capa 1 de la extracción: TODAS las celdas de TODOS los boletines, con sus coordenadas y las etiquetas que
# las rodean tal como se publicaron. No interpreta nada económico (eso lo hace extraer_panel.R).
# Uso (desde esta carpeta, después de inventario.R): Rscript extraer_celdas.R
# Salidas (extraidos/):
#   celdas_numericas.parquet  una fila por celda numérica: archivo, hoja, fila, columna, valor publicado (texto)
#                             y numérico, título de la hoja, encabezado de columna, etiqueta de fila y sección.
#   celdas_texto.parquet      una fila por celda de texto, con su rol: titulo | encabezado | etiqueta_fila |
#                             seccion | otro (notas, fuentes, «Volver al Índice», etc.).
#   control_celdas.csv        por archivo y hoja: celdas leídas = numéricas + texto (debe cerrar exacto).
# Reglas para las etiquetas (solo describen la posición; no deciden significado):
#   - Columna de datos: la que tiene al menos 3 celdas numéricas.
#   - Fila de nota: sin números y con un único texto de más de 60 caracteres (notas al pie, fuentes).
#   - Fila de encabezado: sin números, con al menos dos textos y alguno en una columna de datos (una fila
#     con un solo texto corto es título o sección: así el membrete no se hereda a todas las columnas). Las filas de encabezado seguidas
#     forman el encabezado del bloque de datos que viene debajo (una hoja puede tener varios bloques); cada
#     celda vacía hereda el texto más cercano a su izquierda en la MISMA fila (celdas combinadas del original).
#   - Encabezado de columna de una celda: el encabezado acumulado de su bloque, de arriba hacia abajo (« > »).
#   - Etiqueta de fila: textos a la izquierda de la celda en la misma fila.
#   - Sección: fila sin números con texto solo en columnas de etiquetas, después del primer encabezado o
#     número (p. ej., «SUCURSALES DIRECTAS EXTRANJERAS»); antes de ambos es «título».
#   - Hojas «Módulo1/2» (macros de Excel) y gráficos sin celdas se registran en el control con 0 celdas.

suppressPackageStartupMessages({library(readxl); library(data.table); library(arrow)})
inv <- fread("inventory.csv")
dir.create("extraidos", showWarnings = FALSE)

es_num <- function(v) !is.na(v) & grepl("^\\s*-?\\d+(\\.\\d+)?([eE][-+]?\\d+)?\\s*$", v)

hoja_celdas <- function(path, hoja) {
  m <- tryCatch(suppressMessages(read_excel(path, sheet = hoja, col_names = FALSE, col_types = "text", .name_repair = "minimal")),
                error = function(e) NULL)
  if (is.null(m) || !nrow(m) || !ncol(m)) return(NULL)
  m <- as.matrix(m); dimnames(m) <- NULL
  nr <- nrow(m); nc <- ncol(m)
  num <- matrix(es_num(m), nr, nc); txt <- !is.na(m) & !num
  if (!any(num | txt)) return(NULL)
  col_datos <- colSums(num) >= 3                      # columnas con datos (≥ 3 números)
  n_num_fila <- rowSums(num)
  # Recorrido fila por fila. Tipos de fila sin números:
  #   encabezado: tiene texto en alguna columna de datos  -> se acumula en el encabezado de cada columna;
  #               si la fila anterior con contenido era numérica, empieza un bloque nuevo (se reinicia);
  #   seccion:    texto solo en columnas de etiquetas, después del primer número de la hoja;
  #   titulo:     texto solo en columnas de etiquetas, antes del primer número de la hoja.
  tipo_fila <- rep(NA_character_, nr); enc_estado <- rep(NA_character_, nc); sec <- NA_character_
  enc_celda <- matrix(NA_character_, nr, nc); sec_fila <- rep(NA_character_, nr)
  hubo_num <- FALSE; hubo_enc <- FALSE; ultima_era_num <- FALSE
  for (i in seq_len(nr)) {
    if (!any(txt[i, ]) && n_num_fila[i] == 0) next
    if (n_num_fila[i] > 0) {
      tipo_fila[i] <- "datos"; enc_celda[i, ] <- enc_estado; sec_fila[i] <- sec
      hubo_num <- TRUE; ultima_era_num <- TRUE; next
    }
    if (sum(txt[i, ]) == 1 && nchar(m[i, txt[i, ]]) > 60) { tipo_fila[i] <- "nota"; next }  # notas al pie, fuentes
    if (sum(txt[i, ]) >= 2 && any(txt[i, col_datos])) {
      tipo_fila[i] <- "encabezado"; hubo_enc <- TRUE
      if (ultima_era_num) enc_estado <- rep(NA_character_, nc)
      ult <- NA_character_; fila_enc <- rep(NA_character_, nc)
      for (jj in seq_len(nc)) { if (txt[i, jj]) ult <- m[i, jj]; fila_enc[jj] <- ult }  # herencia a la derecha
      enc_estado <- ifelse(is.na(fila_enc), enc_estado, ifelse(is.na(enc_estado), fila_enc, paste(enc_estado, fila_enc, sep = " > ")))
      ultima_era_num <- FALSE
    } else if (hubo_num || hubo_enc) {
      tipo_fila[i] <- "seccion"; sec <- paste(m[i, txt[i, ]], collapse = " | ")
    } else tipo_fila[i] <- "titulo"
  }
  titulo <- paste(unique(m[tipo_fila %in% "titulo", , drop = FALSE][txt[tipo_fila %in% "titulo", , drop = FALSE]]), collapse = " / ")
  idx <- which(num, arr.ind = TRUE)
  out <- data.table(fila = idx[, 1], columna = idx[, 2], valor_publicado = m[idx])
  out[, valor := as.numeric(valor_publicado)]
  out[, encabezado_columna := enc_celda[idx]]
  out[, etiqueta_fila := mapply(function(i, j) { if (j < 2) return(NA_character_)
    z <- m[i, seq_len(j - 1)][txt[i, seq_len(j - 1)]]; if (length(z)) paste(z, collapse = " | ") else NA_character_ }, fila, columna)]
  out[, seccion := sec_fila[fila]]
  out[, titulo_hoja := titulo]
  it <- which(txt, arr.ind = TRUE)
  tx <- data.table(fila = it[, 1], columna = it[, 2], texto = m[it])
  tx[, rol := fifelse(tipo_fila[fila] == "datos",
                      fifelse(columna < sapply(fila, function(i) min(which(num[i, ]))), "etiqueta_fila", "otro"),
                      tipo_fila[fila])]
  list(num = out, txt = tx, n_leidas = sum(num | txt))
}

nums <- list(); txts <- list(); ctrl <- list()
for (k in seq_len(nrow(inv))) {
  a <- inv[k]
  for (h in excel_sheets(a$path)) {
    r <- hoja_celdas(a$path, h)
    base <- data.table(archivo = a$archivo, sha256 = a$sha256, tipo = a$tipo, diseno = a$diseno, fecha_corte = a$fecha_corte, version = a$version, hoja = h)
    if (is.null(r)) { ctrl[[length(ctrl) + 1]] <- cbind(base, leidas = 0L, numericas = 0L, texto = 0L); next }
    # (cbind con una tabla vacía dejaría una fila de NA: solo se agrega lo que existe)
    if (nrow(r$num)) nums[[length(nums) + 1]] <- cbind(base, r$num)
    if (nrow(r$txt)) txts[[length(txts) + 1]] <- cbind(base, r$txt)
    ctrl[[length(ctrl) + 1]] <- cbind(base, leidas = r$n_leidas, numericas = nrow(r$num), texto = nrow(r$txt))
  }
  if (k %% 25 == 0) cat(k, "/", nrow(inv), "archivos\n")
}
N <- rbindlist(nums); T <- rbindlist(txts); C <- rbindlist(ctrl)
stopifnot(C[, all(leidas == numericas + texto)], nrow(N) == sum(C$numericas), nrow(T) == sum(C$texto),
          !anyNA(N$valor), !anyNA(T$rol))
write_parquet(N, "extraidos/celdas_numericas.parquet"); write_parquet(T, "extraidos/celdas_texto.parquet")
fwrite(C, "extraidos/control_celdas.csv")
cat("Celdas numéricas:", nrow(N), "| de texto:", nrow(T), "| hojas:", nrow(C), "(sin celdas:", C[leidas == 0, .N], ")\n")
print(T[, .N, by = rol])
