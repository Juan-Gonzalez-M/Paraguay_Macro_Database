"""Reconstruye una plantilla readme_NN.md a partir de un README generado.

Uso: python3 reconstruir_plantilla.py <carpeta_proyecto> <salida.md>
Sustituye por marcadores las partes que genera readme.R: la línea de
generación, la tabla de series, la tabla de archivos y los rangos de
archivos del manifiesto citados en otras tablas.
"""
import csv, re, sys
P, out = sys.argv[1], sys.argv[2]
lines = open(f"{P}/README.md", encoding="utf-8").read().split("\n")
man = list(csv.DictReader(open(f"{P}/datos/00_manifiesto.csv", encoding="utf-8")))
res, i = [], 0
while i < len(lines):
    l = lines[i]
    if l.startswith("*Carpeta de datos generada por `R/01_extraer_datos.R` · "):
        res.append("*Carpeta de datos generada por `R/01_extraer_datos.R` · {{GENERADO}}*"); i += 1; continue
    for head, ph in (("| Serie | Descripción | Fuente / tabla |", "{{TABLA_SERIES}}"),
                     ("| Archivo | Filas | Columnas | Desde | Hasta |", "{{TABLA_ARCHIVOS}}")):
        if l.startswith(head):
            while i < len(lines) and lines[i].startswith("|"): i += 1
            res.append(ph); break
    else:
        for m in man:
            fil = "{:,}".format(int(m["filas"])).replace(",", ".")
            txt = f"{m['desde']} a {m['hasta']}, {fil} filas"
            if f"`{m['archivo']}`" in l and txt in l:
                l = l.replace(txt, "{{RANGO:%s}}" % m["archivo"])
        res.append(l); i += 1
open(out, "w", encoding="utf-8").write("\n".join(res))
