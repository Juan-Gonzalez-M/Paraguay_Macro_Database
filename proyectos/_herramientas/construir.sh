#!/bin/bash
# Arma R/01_extraer_datos.R (plantilla compartida + especificación del proyecto),
# lo ejecuta, regenera el README y verifica la carpeta.
# Uso (desde cualquier lugar): _herramientas/construir.sh <NN>      p. ej. 25
#        --solo-readme: no vuelve a extraer datos, solo regenera y verifica el README.
set -euo pipefail
H="$(cd "$(dirname "$0")" && pwd)"; B="$(dirname "$H")"
n="$1"; P="$(ls -d "$B"/${n}_* | head -1)"
if [ "${2:-}" != "--solo-readme" ]; then
  mkdir -p "$P/R" "$P/datos"
  cat "$H/plantilla_funciones.R" "$H/specs/spec_$n.R" > "$P/R/01_extraer_datos.R"
  (cd "$P" && Rscript --vanilla R/01_extraer_datos.R 2>&1 | grep -v "built under" || true)
fi
Rscript --vanilla "$H/readme.R" "$P" "$H/plantillas_readme/readme_$n.md"
python3 "$H/verificar.py" "$(basename "$P")"
