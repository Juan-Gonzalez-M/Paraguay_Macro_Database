## Uso: Rscript readme.R <carpeta_proyecto> <plantilla_readme.md> [salida]
args <- commandArgs(TRUE); P <- args[1]; tpl <- readLines(args[2], encoding = "UTF-8")
d <- read.csv(file.path(P, "datos", "diccionario_series.csv"), stringsAsFactors = FALSE, encoding = "UTF-8")
m <- read.csv(file.path(P, "datos", "00_manifiesto.csv"), stringsAsFactors = FALSE)
esc <- c(units = "", millions = "millones", thousands = "miles", billions = "miles de millones")
fmt <- function(n) formatC(n, format = "d", big.mark = ".", decimal.mark = ",")
un <- function(u, e) { e2 <- ifelse(is.na(e) | e == "", "", ifelse(e %in% names(esc), esc[e], e)); u <- ifelse(is.na(u) | u == "", "s/d", u)
  ifelse(e2 == "", u, paste0(u, " (", e2, ")")) }
fuente <- function(f, t) { t <- gsub("\\|", "/", t); t <- ifelse(nchar(t) > 40, paste0(substr(t, 1, 38), "…"), t); paste0("`", f, "` ", t) }
bulk <- grepl("^[a-z_]+ hoja [^:]+: ", d$descripcion)
d$grupo <- ifelse(bulk, sub(": .*$", "", d$descripcion), NA)
indiv <- d[!bulk, ]
if (any(bulk)) {
  g <- split(d[bulk, ], d$grupo[bulk])
  agr <- do.call(rbind, lapply(g, function(z) {
    pref <- sub("^((?:[a-z]+_){1,3}[0-9_]*).*$", "\\1", z$serie[1], perl = TRUE)
    niv <- table(z$nivel_verificacion)
    data.frame(serie = paste0(sub("_+$", "", pref), "_*"), descripcion = paste0(nrow(z), " series: ", z$grupo[1], " (detalle en diccionario_series.csv)"),
               fuente = z$fuente[1], tabla = z$tabla[1], frecuencia = paste(unique(z$frecuencia), collapse = "/"),
               desde = min(z$desde), hasta = max(z$hasta), n_obs = sum(z$n_obs),
               unidad = paste(unique(z$unidad), collapse = "/"), escala = paste(unique(z$escala), collapse = "/"),
               nivel_verificacion = paste(paste0(names(niv), " (", as.integer(niv), ")"), collapse = "; "),
               rol = z$rol[1], stringsAsFactors = FALSE)
  }))
  d <- rbind(indiv[, names(agr)], agr)
}
tab <- c("| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |",
         "|---|---|---|---|---|---|---|---|---|---|",
         sprintf("| `%s` | %s | %s | %s | %s | %s | %s | %s | %s | %s |", d$serie, gsub("\\|","/",d$descripcion), fuente(d$fuente, d$tabla),
                 d$frecuencia, d$desde, d$hasta, fmt(d$n_obs), un(d$unidad, d$escala), d$nivel_verificacion, gsub("\\|","/",d$rol)))
arch <- c("| Archivo | Filas | Columnas | Desde | Hasta |", "|---|---|---|---|---|",
          sprintf("| `datos/%s` | %s | %d | %s | %s |", m$archivo, fmt(m$filas), m$columnas,
                  ifelse(is.na(m$desde) | m$desde == "", "—", m$desde), ifelse(is.na(m$hasta) | m$hasta == "", "—", m$hasta)))
dd <- read.csv(file.path(P, "datos", "diccionario_series.csv"), stringsAsFactors = FALSE, encoding = "UTF-8")
out <- c()
for (l in tpl) {
  if (trimws(l) == "{{TABLA_SERIES}}") { out <- c(out, tab); next }
  if (trimws(l) == "{{TABLA_ARCHIVOS}}") { out <- c(out, arch); next }
  while (grepl("\\{\\{RANGO:[^}]+\\}\\}", l)) {
    k <- sub(".*\\{\\{RANGO:([^}]+)\\}\\}.*", "\\1", l); r <- m[m$archivo == k, ]
    if (!nrow(r)) stop("Archivo no encontrado en manifiesto: ", k)
    l <- sub(paste0("{{RANGO:", k, "}}"), sprintf("%s a %s, %s filas", r$desde, r$hasta, fmt(r$filas)), l, fixed = TRUE)
  }
  while (grepl("\\{\\{SERIE:[^}]+\\}\\}", l)) {
    k <- sub(".*\\{\\{SERIE:([^}]+)\\}\\}.*", "\\1", l); r <- dd[dd$serie == k, ]
    if (!nrow(r)) stop("Serie no encontrada: ", k)
    l <- sub(paste0("{{SERIE:", k, "}}"), sprintf("%s a %s", r$desde, r$hasta), l, fixed = TRUE)
  }
  out <- c(out, l)
}
m2 <- m[1, ]; out <- gsub("{{GENERADO}}", paste0(m2$generado, " · esquema ", m2$esquema_base, " · ", m2$release_base), out, fixed = TRUE)
salida <- if (length(args) >= 3) args[3] else file.path(P, "README.md")
writeLines(out, salida, useBytes = TRUE)
cat("README escrito:", length(out), "líneas\n")
