# Producción agrícola nacional de largo plazo: FAOSTAT (QCL) y USDA PSD.
#
# FAOSTAT: <ACQ_BASE>/faostat/Production_Crops_Livestock_E_All_Data_Normalized.zip (Fase A).
#   Paraguay, todos los ítems y elementos, 1961–2024, año calendario. Unidades y flags tal como se publican
#   (flag FAO en la columna flag: A oficial, E estimado, I imputado, M faltante, X de otra organización).
#   Comprobado en Fase A: año FAO Y = campaña MAG (Y−1)/Y para soja.
# USDA PSD: psd_alldata_csv.zip (descarga directa, sin registro) a <ACQ_NUEVA>/usda/.
#   Paraguay, todos los productos y atributos, por AÑO COMERCIAL (Market_Year). Unidades publicadas
#   (1000 MT, 1000 HA, MT/HA) sin reescalar. Calendar_Year/Month = última actualización del dato (vintage).
#   Años comerciales recientes son estimaciones o proyecciones que USDA revisa cada mes: flag
#   "usda_estimacion_o_proyeccion" cuando Market_Year ≥ año de la última actualización − 1.
#   OJO: el año comercial no coincide necesariamente con la campaña MAG; varía por producto.
# Salidas: data/clima/agro_faostat_nacional.csv, data/clima/agro_usda_psd_nacional.csv

source("R/clima/00_utils.R")

# FAOSTAT -------------------------------------------------------------------------------------------
f_fao <- file.path(ACQ_BASE, "faostat/Production_Crops_Livestock_E_All_Data_Normalized.zip")
fao <- fread(cmd = paste("unzip -p", shQuote(f_fao), shQuote("Production_Crops_Livestock_E_All_Data_(Normalized).csv"),
                         "| awk 'NR==1 || /,\"Paraguay\",/'"), encoding = "Latin-1")
fao <- fao[Area == "Paraguay"]
stopifnot(nrow(fao) == 18471)  # conteo verificado en la Fase A
nombre_var <- function(x) gsub("^_|_$", "", gsub("[^a-z0-9]+", "_", tolower(iconv(x, "latin1", "ASCII//TRANSLIT"))))
fao_out <- fao[, .(fecha = as.IDate(sprintf("%d-01-01", Year)), id_geo = "PY", nivel_geo = "nacional",
                   variable = paste0("fao_", `Item Code`, "_", nombre_var(Item), "__", `Element Code`, "_", nombre_var(Element)),
                   valor = Value, unidad = Unit, fuente = "FAOSTAT QCL (Crops and livestock products)",
                   frecuencia = "anual", periodo_publicado = as.character(Year),
                   flag = paste0("faostat_flag:", fifelse(Flag == "", "(vacio)", Flag), fifelse(Note == "" | is.na(Note), "", paste0("; nota:", Note))),
                   archivo_origen = f_fao)]
escribir_largo(fao_out, "agro_faostat_nacional", claves = c("fecha", "id_geo", "variable"), insumos = huella(f_fao))

# USDA PSD ------------------------------------------------------------------------------------------
f_psd <- descargar("https://apps.fas.usda.gov/psdonline/downloads/psd_alldata_csv.zip", "usda/psd_alldata_csv.zip")
psd <- fread(cmd = paste("unzip -p", shQuote(f_psd), "| awk 'NR==1 || /,\"Paraguay\",/'"))
psd <- psd[Country_Name == "Paraguay"]
dup <- psd[, .N, by = .(Commodity_Code, Attribute_ID, Market_Year)][N > 1]
if (nrow(dup)) stop("USDA PSD: filas duplicadas por producto-atributo-año: ", nrow(dup))
psd[, ultimo_anio := max(Calendar_Year)]
psd_out <- psd[, .(fecha = as.IDate(sprintf("%d-01-01", Market_Year)), id_geo = "PY", nivel_geo = "nacional",
                   variable = paste0("usda_", nombre_var(Commodity_Description), "__", nombre_var(Attribute_Description)),
                   valor = Value, unidad = gsub("[()]", "", Unit_Description), fuente = "USDA FAS PSD Online",
                   frecuencia = "anual", periodo_publicado = paste0("MY ", Market_Year),
                   flag = paste0("actualizado:", Calendar_Year, "-", sprintf("%02d", Month),
                                 fifelse(Market_Year >= ultimo_anio - 1, "; usda_estimacion_o_proyeccion", "")),
                   archivo_origen = f_psd)]
escribir_largo(psd_out, "agro_usda_psd_nacional", claves = c("fecha", "id_geo", "variable"), insumos = huella(f_psd))
