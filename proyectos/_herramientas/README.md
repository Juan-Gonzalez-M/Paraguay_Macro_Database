# Herramientas de las carpetas de proyectos

Todo lo necesario para regenerar y verificar las carpetas `proyectos/NN_*`. Nada de esto modifica la base de datos: los scripts la abren en **solo lectura**.

## Contenido

| Archivo | Qué hace |
|---|---|
| `plantilla_funciones.R` | Funciones compartidas por todos los scripts de extracción: conexión de solo lectura, extracción de series, FRED/NOAA, escritura de CSV, manifiesto, diccionario y datos manuales (`leer_manual`). |
| `specs/spec_NN.R` | Especificación de cada proyecto: qué series, eventos, paneles y archivos extrae. |
| `plantillas_readme/readme_NN.md` | Texto de cada README con marcadores que completa `readme.R`: `{{GENERADO}}`, `{{TABLA_SERIES}}`, `{{TABLA_ARCHIVOS}}`, `{{RANGO:archivo.csv}}`, `{{SERIE:nombre}}`. **Los cambios de texto de un README se hacen aquí**, no en el README generado. |
| `readme.R` | Genera `README.md` a partir de la plantilla y de `datos/00_manifiesto.csv` y `datos/diccionario_series.csv`, para que los rangos siempre coincidan con los archivos. |
| `verificar.py` | Verifica manifiesto vs. archivos, diccionario vs. datos, rangos del README, fechas ISO y marcadores sin reemplazar. |
| `construir.sh` | Encadena todo para un proyecto. |
| `reconstruir_plantilla.py` | Recupera una plantilla a partir de un README generado (se usó para 01, 03, 06, 09, 16 y 21). |
| `portafolio/editar.py` | Script que generó `Portafolio_..._v2.docx` editando `word/document.xml` del original descomprimido en `u/`. Se conserva como registro. |

`R/01_extraer_datos.R` de cada carpeta es **exactamente** `plantilla_funciones.R` + `specs/spec_NN.R` concatenados, para que cada carpeta funcione sola. Para cambiar la extracción de un proyecto, edita el spec y vuelve a construir; si cambias la plantilla compartida, reconstruye todas las carpetas.

## Uso

```bash
# Extraer datos, regenerar README y verificar (p. ej., después de completar datos_manuales/)
proyectos/_herramientas/construir.sh 25

# Solo regenerar y verificar el README (tras editar su plantilla)
proyectos/_herramientas/construir.sh 25 --solo-readme

# Verificar varias carpetas
cd proyectos && python3 _herramientas/verificar.py [0-9][0-9]_*
```

Requisitos: R con `DBI` y `duckdb` (el resto es R base); Python 3. La base se busca en `../../database/paraguay_macro_pilot.duckdb` desde cada carpeta, o en la variable de entorno `PARAGUAY_MACRO_DB`. Para no descargar FRED/NOAA y usar la copia ya guardada, usar `DESCARGAR_EXTERNOS=0`.
