# Bloque de datos climáticos y agroclimáticos

*Fase B · 2026-09-23. Diagnóstico previo: `input/acquisition_candidates/clima_agro_2026-09-23/00_diagnostico.md`.*

Esta carpeta contiene series **de investigación** construidas con scripts reproducibles de `R/clima/`. **No forman parte de la base DuckDB** ni pasan por su pipeline (registro de fuentes, candidatos, releases). Incorporarlas a la base requiere parser, entrada en el registro y el flujo de release (`docs/ARCHITECTURE.md`). Nada aquí está revisado por un economista: tratar todo como *preliminar*.

## 1. Cómo regenerar

Desde la raíz del repositorio:

```bash
Rscript R/clima/99_ejecutar_todo.R      # todo, en orden; omite con aviso lo que requiere credenciales
Rscript R/clima/98_catalogo.R           # solo verificación + catálogo
```

| Script | Fuente | Salida(s) | Requisito | Tiempo aprox. |
|---|---|---|---|---|
| `00_utils.R` | — | funciones comunes: esquema, geografía, descargas con hash, manifiesto | — | — |
| `01_enso.R` | NOAA CPC/PSL | `enso_indices.csv` | — | segundos |
| `02_mag_produccion.R` | MAG–DCEA | `agro_mag_departamental.csv` (+ controles) | — | 1–2 min |
| `03_chirps.R` | CHIRPS v3.0 | `clima_chirps_precipitacion.csv`, `clima_pesos_agricolas.csv` | `02` | 10 s |
| `04_spi.R` | cálculo sobre CHIRPS | `clima_spi.csv` | `03` | 10 s |
| `05_rios_dmh.R` | DMH–DINAC | `rios_dmh_diario.csv`, `rios_dmh_mensual.csv`, `rios_dmh_estaciones.csv`, `rios_dmh_control_descarga.csv` | — | **≈ 5 h la primera vez** (descarga lenta); luego segundos |
| `06_era5land.R` | Copernicus ERA5-Land | `clima_era5land.csv` | **token CDS** (§ 8.1) | ≈ 12–14 h la primera vez (548 pedidos horarios; cola CDS); luego minutos |
| `07_spei.R` | cálculo CHIRPS + ERA5-Land | `clima_spei.csv` | `03`, `06` | segundos |
| `08_iri.R` | IRI Columbia | `enso_iri_pronosticos.csv`, `iri_control.csv` | — | ≈ 12 min la primera vez |
| `09_hidro_itaipu.R` | ONS Brasil | `hidro_itaipu_diario.csv`, `hidro_itaipu_mensual.csv` | — | 1 min |
| `10_faostat_usda.R` | FAOSTAT, USDA PSD | `agro_faostat_nacional.csv`, `agro_usda_psd_nacional.csv` | — | 30 s |
| `11_abasto.R` | MAG/SIMA–DAMA | `abasto_precios_diario.csv`, `abasto_precios_mensual.csv`, `abasto_ingresos_mensual.csv` | — | segundos |
| `12_emdat.R` | EM-DAT | `eventos_emdat_paraguay.csv`, `eventos_emdat_mensual.csv` | **Excel de EM-DAT** (§ 8.2) | segundos |
| `13_modis_ndvi.R` | MODIS MOD13A3 | `clima_modis_vegetacion.csv` | GeoTIFF de AppEEARS (§ 8.3), ya cargados | ≈ 3 min |
| `14_calendario_cultivos.R` | USDA FAS GAIN (citas verificadas) | `calendario_cultivos.csv` | `pdftotext` (poppler) | 10 s |
| `98_catalogo.R` | — | verificación, `00_catalogo_variables.csv`, catálogo de este README | — | 30 s |
| `97_inventario_proyectos.R` | — | agrega o actualiza las series de `data/clima` en `proyectos/00_inventario_series.csv` (idempotente; no toca las filas de la base) | `98` | segundos |
| `99_ejecutar_todo.R` | — | ejecuta todo | — | — |

Paquetes de R: `data.table`, `readxl`, `openssl`, `curl`, `jsonlite`, `terra`, `sf`, `exactextractr`, `SPEI`, `ecmwfr`, `arrow`.

**Insumos.** Los archivos de la Fase A (`input/acquisition_candidates/clima_agro_2026-09-23/`) se leen y **nunca se modifican**. Todo lo descargado en la Fase B está en `input/acquisition_candidates/clima_agro_2026-09-23_faseB/`, con `inventory.csv` (URL, fecha UTC, bytes, SHA-256). Esa carpeta tiene su propio `.gitignore` y **no se sube a Git**. Los scripts no vuelven a descargar lo que ya existe; cuando refrescan una fuente viva (ONS, año en curso de ERA5-Land), queda como nuevo vintage con su hash.

## 2. Esquema común (formato largo)

Todos los archivos de datos, salvo las tablas de control, la de eventos EM-DAT y el calendario, tienen estas columnas en este orden:

| Columna | Contenido |
|---|---|
| `fecha` | Fecha de referencia (primer día del período). Ver convenciones en la § 3. |
| `id_geo` | `PY` (nacional por área), `PY-AGRO` (nacional ponderado por área agrícola), `PY-00` … `PY-17` (código INE CNPV 2022: `00` Asunción … `17` Alto Paraguay), `GLOBAL` (índices ENSO), `DMH-<código>` (estación hidrométrica), `ONS-PNITAI` (embalse de Itaipú), `ONS-ITAIPU` (central de Itaipú), `PY-MERCADO-ABASTO-ASU` |
| `nivel_geo` | `nacional`, `departamento`, `estacion`, `mercado`, `global` |
| `variable` | Nombre de la variable (ver catálogo) |
| `valor` | Número; `NA` solo con `flag` que lo explica |
| `unidad` | Unidad tal como queda el valor; las conversiones se indican en la § 4 |
| `fuente` | Institución y producto; «agregado propio» o «cálculo propio» cuando hay transformación |
| `frecuencia` | `diaria`, `mensual`, `bimestral_movil`, `trimestral_movil`, `anual`, `campania`, `vintage_mensual` |
| `periodo_publicado` | Etiqueta del período tal como la publica la fuente («2021/22*», «DJF 2025», «MY 2021») |
| `flag` | Marcas de calidad, notas de la fuente y decisiones (texto; `;` separa marcas) |
| `archivo_origen` | Ruta del archivo fuente y, cuando aplica, `#hoja!celda` |

`00_manifiesto.csv` registra filas, rango de fechas, SHA-256 e insumos de cada salida. `98_catalogo.R` verifica que los archivos coincidan con el manifiesto antes de regenerar el catálogo.

## 3. Convenciones temporales (sin rezagos ni interpolaciones)

- **ONI y RONI:** temporada de 3 meses fechada en el **mes central** (DJF → enero). **MEI.v2:** bimestre fechado en su **segundo mes** (DJ → enero). **SOI y Niño 3.4:** mes calendario. Los rezagos (p. ej., rezagar un mes el ONI centrado) se aplican en el análisis, no en los datos.
- **MAG (campañas):** `fecha` = **1 de julio del primer año** de la campaña (2021/22 → 2021-07-01). Es una convención propia y no indica la fecha de cosecha; usar `periodo_publicado`. FAOSTAT año Y = campaña MAG (Y−1)/Y en soja (comprobado).
- **USDA PSD:** `fecha` = 1 de enero del **año comercial (MY)** publicado. El MY no se alinea con la campaña MAG y **cambia según el producto**. Según el GAIN 2025: trigo MY 2023/24 empieza en sep-2023; maíz MY 2023/24 empieza en **jun-2024**; arroz MY 2023/24 empieza en ene-2024. En soja, MY 2021 = campaña 2021/22 (la sequía: 4,18 Mt).
- **IRI:** `fecha` = mes de emisión (vintage). La variable lleva el horizonte `hNN` = meses entre la emisión y el mes central de la temporada objetivo.
- **Diario → mensual** (ríos, Itaipú, ERA5-Land diario): promedio, mínimo y máximo sobre los días con dato, más el número de días. Los meses incompletos se marcan con `mes_incompleto:n/N_dias`. No se imputa.
- **Normal climatológica** para anomalías, SPI y SPEI: **1991–2020** (OMM; la misma que usa la DMH).

## 4. Catálogo por fuente

### 4.1 ENSO observado — `enso_indices.csv` (01)
ONI y SST Niño 3.4 de 3 meses (1950–), RONI (1950–), MEI.v2 (1979–), SOI anomalía y estandarizado (1951–), anomalía y SST mensual Niño 3.4 (1982–). Sin transformaciones. Se excluyeron los meses que NOAA publica con código de faltante (−9999 en MEI, cuyo encabezado dice −999; −999,9 en SOI). Los ONI y RONI son idénticos byte a byte a los que ya usan los proyectos 09, 12 y 13.

### 4.2 Pronósticos ENSO — `enso_iri_pronosticos.csv` (08)
Probabilidades (%) de La Niña, Neutral y El Niño por temporada objetivo y mes de emisión. **Son dos productos distintos; no empalmarlos:**
- `enso_prob_iri_probabilistico_*`: **2003-06 → 2013-12**, pronóstico probabilístico del IRI (páginas `archive/YYYYMM/figure3.html`).
- `enso_prob_cpc_iri_oficial_*`: **2014-01 → 2025-04**, pronóstico oficial CPC/IRI de las páginas quick-look.

`flag` indica la fecha de publicación cuando la página la informa (desde 2014) y los valores publicados como «~0 %». En 45 meses el año publicado de alguna temporada no coincide con la secuencia: a veces es otra convención (DJF con el año de diciembre) y a veces un error evidente («JFM 2012» en una emisión de dic-2012). Se conserva la etiqueta en `periodo_publicado` y el horizonte se calcula por la secuencia de temporadas (`etiqueta_anio_publicada_difiere…`). Sin datos (38 de 297 meses): 2002-01 a 2003-05 (páginas inexistentes o con la tabla como imagen); 2009-12 y 2010-01 (tabla vacía); 2015-06 y 2017-04 (solo tabla climatológica); **2025-05 en adelante** (el sitio muestra las probabilidades solo mediante JavaScript). Detalle mes a mes en `iri_control.csv`.

### 4.3 Precipitación — `clima_chirps_precipitacion.csv` (03)
CHIRPS v3.0 mensual (0,05°), **media de celdas ponderada por la fracción de la celda dentro del polígono y por su área**, para las 18 unidades del INE y el total país (`PY`). `PY-AGRO` es el promedio de los departamentos ponderado por la superficie de los 16 cultivos principales en la campaña 2007/08 (dato censal CAN 2008): pesos fijos y anteriores a casi toda la muestra, en `clima_pesos_agricolas.csv` (Alto Paraná 27 %, Itapúa 18 %, Canindeyú 17 %, Caaguazú 12 %…; Asunción 0). Variables: `precipitacion` (mm/mes), `precipitacion_anomalia_1991_2020` (mm) y `precipitacion_pct_normal_1991_2020` (%).
Contraste: en Asunción, correlación mensual 0,89 con NASA POWER (MERRA-2) 1981–2025. Normal anual: de 669 mm (Boquerón) a 1.912 mm (Itapúa).

### 4.4 Sequía — `clima_spi.csv` (04) y `clima_spei.csv` (07)
**SPI 1, 3, 6 y 12** (gamma, calibración 1991–2020) sobre la precipitación ya agregada por unidad (no es el promedio de SPI por celda). Los primeros k−1 meses de cada escala no existen por construcción. En 1991–2020 tiene media ≈ 0 y desvío ≈ 1. SPI-12 `PY-AGRO`: 2009-03 −1,39; 2012-03 −1,26; 2022-03 −1,99.
**SPEI 3, 6 y 12** (log-logística, 1991–2020) con balance = lluvia CHIRPS − PET de Hargreaves (tmin y tmax mensuales de ERA5-Land, latitud del centroide). Incluye `pet_hargreaves` (mm). Cuando el balance cae fuera del soporte de la distribución ajustada, el SPEI da ±Inf: queda `NA` con flag, sin recortarlo a un valor arbitrario. **Pendiente de ERA5-Land** (§ 8.1).

### 4.5 Temperatura, humedad del suelo y evaporación — `clima_era5land.csv` (06) — **pendiente del token CDS**
Agregación espacial igual que CHIRPS, con estas variables:
- **Temperatura:** `temperatura_media`, `temperatura_maxima_media` y `temperatura_minima_media` (°C).
- **Días extremos:** `dias_tmax_ge_35C` y `dias_tmin_le_0C`, calculados **por celda** y luego promediados. Los umbrales son las categorías del anuario DMH.
- **Humedad del suelo:** `humedad_suelo_0_7cm`, `_7_28cm` y `_28_100cm` (m³/m³).
- **Evaporación:** `evaporacion_total` y `evaporacion_potencial_era5` (mm/día, convertidos de m; signo de ERA5: negativo = hacia la atmósfera).

- **Método de la temperatura diaria (cambiado el 2026-09-24):** se descarga la temperatura **horaria** de `reanalysis-era5-land`, un pedido por mes (548 meses, 1981-01 → 2026-08, unos 5,3 GB conservados en `…_faseB/era5land/horario/`). De ahí se derivan las máximas y mínimas diarias en hora local UTC−3.
- **Por qué:** el producto `derived-era5-land-daily-statistics` entregaba un archivo cada 4–5 horas por la congestión de la cola del CDS. Sus 89 pedidos restantes se cancelaron y los 3 recibidos se conservan como referencia.
- **Validación:** las máximas y mínimas derivadas coinciden **exactamente** (0,0 K) con las oficiales del CDS para enero de 1982. La cadena horario → diario → mensual se probó con datos reales.
- **Copia de Earth Data Hub, descartada (2026-09-24):** DestinE ofrece ERA5-Land horario en Zarr (`https://api.earthdatahub.destine.eu/era5/era5-land-v0.zarr`), mucho más rápido que la cola del CDS. Pero su `t2m` está comprimida con pérdida (filtro BitRound): los valores vienen en pasos de 0,25 K.
  - Contra el archivo del CDS de 1985-01 (744 horas × 91 × 91 celdas), la diferencia llega a 0,125 K y solo el 0,07 % de los valores coincide exactamente. La media casi no cambia (−0,00002 K).
  - Las celdas-día con tmax ≥ 35 °C pasan de 6.451 a 6.616 (+2,6 %).
  - Por eso no se usa: todo sale del CDS.
- **Evaporación potencial:** la de ERA5-Land (`evaporacion_potencial_era5`) viene muy sesgada (del orden de −14 mm/día en enero). Se publica tal cual, pero **no** se usa para el SPEI, que usa Hargreaves.

### 4.6 Ríos — `rios_dmh_diario.csv`, `rios_dmh_mensual.csv` (05)
Nivel hidrométrico diario (m) del río Paraguay en **Asunción, Pilar y Concepción**, extraído de las páginas públicas de la DMH (15 registros por página, 1 pedido cada 2 s). Cada página se guarda comprimida como evidencia. Se verifica que las fechas únicas obtenidas cubran el total declarado por el sitio y que las filas repetidas por corrimiento de la paginación tengan el mismo valor (`rios_dmh_control_descarga.csv`). Mensual: `nivel_rio_promedio`, `_minimo`, `_maximo` y `nivel_rio_dias`. **No** se calculan días bajo umbrales de navegación: el umbral es una decisión económica o logística a documentar en F3. La descarga es una instantánea fechada (`dmh_rios/<AAAA-MM-DD>/`). No se incluyeron estaciones del Paraná (Encarnación, Ayolas); ver § 6.

### 4.7 Itaipú — `hidro_itaipu_diario.csv`, `hidro_itaipu_mensual.csv` (09)
Datos del ONS Brasil (datos abiertos, CC-BY):
- **Hidrología del embalse** (diaria 2000-01-01 → hoy): caudales afluente, natural, incremental, turbinado, vertido y defluente (m³/s), nivel aguas arriba (m) y volumen útil (%).
- **Generación horaria** (2000 → hoy): total, sectores de 60 Hz y 50 Hz y destino Brasil, agregada a potencia media mensual (MWmed) y energía (GWh = Σ MWmed horarios / 1000). `itaipu_generacion_no_brasil_derivado_*` = total − Brasil; aproxima la energía destinada a Paraguay y **es derivada**.

Controles: total anual de 102,4 TWh en 2016 (récord) y 65,9 TWh en 2021 (sequía). Hay 14 meses con horas observadas distintas de las del calendario (cambios de horario de verano en Brasil antes de 2019 o faltantes), marcados en `flag`. ONS advierte que consolida y revisa datos después de publicarlos. **Yacyretá: pendiente** (§ 6).

### 4.8 Producción agrícola
- **`agro_mag_departamental.csv` (02).** Superficie (ha), producción (t) y rendimiento (kg/ha) por cultivo, departamento (17 + total nacional) y campaña, de **tres libros MAG superpuestos**, **todos conservados** con `archivo_origen#hoja!celda`:
  - A: 16 cultivos, 2007/08–2024/25;
  - B: 22 cultivos, 2020/21–2024/25;
  - C: sésamo, 2017/18–2024/25.

  Se contabilizan 21.924 celdas, y cada una produce una fila; 2.565 no son numéricas y quedan `NA` con flag (`ningun_valor(-)`, `celda_vacia`). Donde los libros publican valores distintos para la misma celda lógica, **ambos** llevan `conflicto_version`: trigo 2024/25 (35 celdas), sésamo 2024/25 (27), algodón 2023/24 (1) y mandioca 2020/21 (1). Las marcas de campaña se traducen con las notas de cada hoja: `*` censo; `(1)` preliminar ENA 2025; `**`/`***` merma por sequía, helada o exceso de lluvia, según la hoja. **Cautelas del diagnóstico:**
  - En 2022/23 y 2023/24 las áreas departamentales crecen en el mismo porcentaje en todos los departamentos.
  - 2015/16 y 2016/17 parecen prorrateados.
  - Hay un quiebre de distribución en 2019/20.

  Filtrar por `archivo_origen` para quedarse con una versión.
- **`agro_faostat_nacional.csv` (10):** FAOSTAT QCL, Paraguay, **todos** los ítems y elementos 1961–2024 (18.471 filas), unidades y flags FAO tal cual (`faostat_flag:A/E/I/M/X`).
- **`agro_usda_psd_nacional.csv` (10):** USDA PSD, Paraguay, 21 productos, 1960–2026, unidades publicadas (1000 MT, 1000 HA, MT/HA). `flag`: mes de la última actualización y `usda_estimacion_o_proyeccion` para los años comerciales vigentes (se revisan cada mes).

### 4.9 Mercado de Abasto de Asunción (11)
- `abasto_precios_diario.csv`: precio mínimo, común y máximo (PYG/kg o PYG/docena) de ají, cebolla, huevo, lechuga, pimiento y tomate, por variedad y **origen PY/AR/BR**, 2021-01-04 → 2026-06-29. Se conservan las 13.858 filas. Una fila está duplicada en la fuente y 6 no cumplen mín ≤ común ≤ máx; ambas situaciones quedan marcadas.
- `abasto_precios_mensual.csv`: promedio mensual del precio común más los días con cotización.
- `abasto_ingresos_mensual.csv`: ingresos mensuales (kg) al Mercado, nacional y extranjero, de tomate, cebolla, lechuga y pimiento (1991–1997 para tomate y cebolla; 2010–2023 para los cuatro). Flags: `valor_con_decimales(posible_estimacion)` (sistemático en 2020–2023) y `fila_identica_a_nacional(posible_error_de_copia)` (tomate importado 2018).

### 4.10 Eventos extremos — EM-DAT (12)
**Estos dos archivos no se suben a Git** (`data/clima/.gitignore`): la licencia de EM-DAT prohíbe redistribuir y el repositorio es público. Se regeneran localmente con `12_emdat.R` a partir del Excel del usuario, que ya está cargado (61 eventos, 1963–2025).
`eventos_emdat_paraguay.csv` (un registro por evento, columnas originales normalizadas) y `eventos_emdat_mensual.csv` (formato largo: eventos que comienzan en el mes por tipo, afectados, muertes y daño ajustado imputados al mes de inicio, sin prorratear, con los `DisNo.` en `flag`). Los eventos sin mes de inicio quedan fuera del mensual y se informan. Probado solo con un Excel sintético con las columnas de la exportación pública.

### 4.11 Vegetación — `clima_modis_vegetacion.csv` (13)
NDVI y EVI mensuales de MODIS MOD13A3 v061 a 1 km, **2000-02 → 2026-08** (319 meses completos en las 4 capas de la entrega de AppEEARS: NDVI, EVI, pixel_reliability y VI_Quality; esta última no se usa).
- **Lectura:** se leen los enteros **crudos**, porque `terra` aplicaría solo el factor de escala del GeoTIFF y se escalaría dos veces. Luego se aplican de forma explícita la escala 0,0001 y el relleno −3000, verificando que los metadatos declaren esos valores.
- **Máscara:** se descartan los píxeles con `pixel_reliability` distinto de 0 o 1. Se agrega como CHIRPS y se informa `modis_fraccion_valida` (media 0,997; mínimo 0,707).
- **Controles:** NDVI medio 2001–2020 de 0,44 (Asunción) y 0,60 (Boquerón) a ≈ 0,70 (departamentos agrícolas del este). Anomalía de NDVI `PY-AGRO` en enero de 2022: −0,18, la mayor de la serie. Correlación con el SPI-3 `PY-AGRO`: 0,48.
- **Ubicación:** los GeoTIFF se subieron a `input/AppEEARS/` y se movieron a `…_faseB/modis/`, que está fuera de Git, con `inventory_modis.csv` (SHA-256 de los 1.276 archivos).

### 4.12 Calendario de cultivos — `calendario_cultivos.csv` (14)
Ver la § 5.

## 5. Calendario de cultivos

`calendario_cultivos.csv` es una **tabla de referencia** (no formato largo): cultivo, temporada, etapa (siembra o cosecha), mes de inicio y de fin con su precisión publicada (inicios, mediados o fines), página, SHA-256 del documento y **cita textual**. La tabla se construye a mano en `R/clima/insumos/calendario_cultivos_fuentes.csv` porque **no existe un calendario público descargable para Paraguay**:
- El calendario GEOGLAM Crop Monitor for Early Warning (Zenodo, v1.3) se descargó y verificó: cubre 86 países, **no incluye Paraguay** ni soja. Luego se eliminó a pedido del usuario; el hash y el motivo están en `…_faseB/eliminados_2026-09-23.csv`.
- El calendario GEOGLAM para AMIS (que cubriría soja) figura como «coming soon».
- FAO GIEWS solo informa la campaña en curso.

`14_calendario_cultivos.R` **verifica que cada cita aparezca en la página indicada del PDF** y falla si no. Se probó con una cita alterada.

| Cultivo | Temporada | Siembra | Cosecha | Fuente |
|---|---|---|---|---|
| Soja | zafra | fines de ago → mediados de nov | fines de dic → mediados de mar | USDA GAIN Oilseeds PA2026-0002, p. 3 |
| Soja | zafriña | fines de ene → mediados de feb | mediados de may → jul | ídem (PA2025-0001 decía «late January to early February») |
| Maíz | temprano | ago → sep | dic → ene | USDA GAIN Grain and Feed PA2026-0001, p. 3 |
| Maíz | zafriña | ene → inicios de mar | jun → ago | ídem |
| Trigo | única | abr → jun (2026); abr → may (2025) | **no documentada explícitamente** | G&F PA2026-0001 p. 2; G&F 2025 p. 2 |
| Arroz | única | inicios de sep → inicios de nov | fines de dic → mediados de abr | G&F 2025 p. 8 (campaña 2024/25) |

Para agregar clima a la campaña (p. ej., lluvia de octubre a febrero para soja zafra), usar estas ventanas **declarando la elección** en cada proyecto. No se incorporaron al resto de los archivos.

## 6. Registro de decisiones (dudas menores resueltas durante la Fase B)

1. **Carpeta de candidatos:** la ruta pedida (`input/acquisition/candidates_…`) no existe; se usó `input/acquisition_candidates/clima_agro_2026-09-23/`.
2. **Descargas nuevas en una carpeta aparte**, fechada y fuera de Git (`…_faseB/`), con inventario y hash.
3. **Asunción y Central:** el clima se agrega a las 18 unidades del INE. MAG publica 17 departamentos sin fila para Asunción y no se fusionan unidades.
4. **Fecha de las campañas MAG** = 1 de julio del primer año (§ 3).
5. **Versiones MAG en conflicto:** se conservan todas y se marcan (decisión del usuario).
6. **CSV MAG 2020–2021 excluidos por redundantes:** comparados con el libro A, 901 celdas son iguales, 49 están vacías en ambos y 2 difieren (tártago Misiones 2019/20 producción «−» frente a 1; arroz con riego Central 2020/21 superficie 2.769 frente a 2.729). El detalle está en `agro_mag_control_csv_2020_2021.csv`. Esos 16 archivos (14 CSV y 2 XLSX; los XLSX también coinciden, 134 celdas) **se eliminaron** el 2026-09-23 a pedido del usuario; el registro está en `eliminados_2026-09-23.csv` de la carpeta de la Fase A.
7. **CAN 2008 y 2022 no se pasaron a formato largo** (78 cuadros por tamaño de finca). Solo se usa el dato censal 2007/08 del libro A como ponderador. Pasarlos queda pendiente si D5 o D2 lo requieren (exposición por departamento, agua, crédito).
8. **Ponderación agrícola nacional (`PY-AGRO`)** con pesos fijos 2007/08, siempre junto al promedio por área (`PY`), nunca en su lugar.
9. **SPI sobre la precipitación agregada** y **SPEI con Hargreaves** (no con la evaporación potencial de ERA5-Land). Los valores ±Inf del SPEI quedan `NA` con flag.
10. **ERA5-Land:** estadísticos diarios con zona horaria UTC−03:00. Umbrales de 35 °C y 0 °C tomados de las categorías del anuario DMH.
11. **Ríos:** solo Asunción, Pilar y Concepción (las del diagnóstico). Las del Paraná (Encarnación, Ayolas) duplicarían el tiempo de extracción; se pueden agregar sumando su código en `ESTACIONES` de `05_rios_dmh.R`.
12. **IRI:** dos productos sin empalmar; los meses posteriores a 2025-04 no se pueden extraer como texto (§ 4.2).
13. **Yacyretá:** no se encontró una serie mensual pública descargable (ni EBY ni CAMMESA exponen archivos estables). Queda pendiente (§ 8.4). La base ya tiene divisas de Yacyretá (Cuadro 55).
14. **Algodón 1930–2026 (datos.gov.py):** las páginas de recurso no exponen archivo descargable. Se descargó en cambio «Datos algodón nacional 2011–2022» (`…_faseB/mag/algodon/`), que es nacional, se superpone con el libro A y trae comercio exterior de algodón. **No se procesó** por redundante y luego se eliminó a pedido del usuario (registro en `…_faseB/eliminados_2026-09-23.csv`).
15. **Tiempo de ONS:** los instantes sin zona se leen como fecha local sin desplazar.
16. **Nombres de variable FAOSTAT** con código de ítem y de elemento: el mismo elemento puede publicarse en dos unidades.

## 7. Verificaciones realizadas

- Cada script falla ante pérdidas no explicadas: celdas leídas frente a emitidas (MAG, Abasto), páginas y fechas frente al total declarado (DMH), meses esperados (CHIRPS) y claves duplicadas (todas las salidas).
- `98_catalogo.R` recalcula filas, fechas y SHA-256 de cada salida y los compara con el manifiesto. Además regenera el catálogo de abajo **a partir de los datos**.
- ERA5-Land, SPEI, EM-DAT y MODIS se probaron primero con insumos **sintéticos**. **EM-DAT y MODIS ya corrieron con los archivos reales.** En MODIS la entrega real mostró dos diferencias, ya resueltas: fechas `AAAAMMDDT000000` en vez de día juliano, y escala aplicada automáticamente por `terra`. **ERA5-Land diario y SPEI** siguen pendientes de la cola del CDS; sus NetCDF mensuales reales ya se verificaron: nombres de variables y tiempo como se esperaba.

## 8. Instrucciones para las fuentes que requieren registro

### 8.1 ERA5-Land (Copernicus CDS)
1. **Cambia la contraseña de tu cuenta de Copernicus**: quedó escrita en una conversación. El script no usa contraseñas.
2. Inicia sesión en https://cds.climate.copernicus.eu. Arriba a la derecha, abre tu nombre → *Your profile* y copia el **Personal Access Token** (API token).
3. Acepta la licencia de los dos conjuntos. En cada página, pestaña *Download*, sección *Terms of use*, pulsa *Accept* en «Licence to use Copernicus Products»:
   - https://cds.climate.copernicus.eu/datasets/reanalysis-era5-land-monthly-means?tab=download
   - https://cds.climate.copernicus.eu/datasets/reanalysis-era5-land?tab=download (temperatura horaria)
4. En la Terminal (reemplaza `TU-TOKEN`; el token no debe pegarse en el chat):
   ```bash
   printf 'url: https://cds.climate.copernicus.eu/api\nkey: TU-TOKEN\n' > ~/.cdsapirc
   chmod 600 ~/.cdsapirc
   ```
5. Desde la raíz del repositorio:
   ```bash
   Rscript R/clima/06_era5land.R    # descarga (5 pedidos mensuales + 548 horarios, hasta 20 en cola a la vez; reanudable) y procesa
   Rscript R/clima/07_spei.R
   Rscript R/clima/98_catalogo.R
   ```
   `ecmwfr` guarda el token en el llavero de macOS; puede pedirte permiso la primera vez. La descarga es reanudable: si se corta, vuelve a correr el mismo comando.

### 8.2 EM-DAT
1. Regístrate gratis en https://public.emdat.be (*Register*). Usa el correo institucional y describe el uso como investigación. **Lee las condiciones:** el acceso público es para **uso no comercial** y **prohíbe redistribuir** la base. Confirma con el área legal del BCP que el uso institucional de investigación está cubierto.
2. Confirma el correo e inicia sesión. En *Access Data*:
   - Clasificación: *Natural* (todos los subgrupos).
   - País: *Paraguay* (o déjalo abierto: el script filtra `ISO = PRY`).
   - Años: desde 1900 hasta el último disponible.
   - Descarga en **Excel (.xlsx)**.
3. Copia el archivo **sin abrirlo ni editarlo** a `input/acquisition_candidates/clima_agro_2026-09-23_faseB/emdat/`.
4. Corre `Rscript R/clima/12_emdat.R` y luego `Rscript R/clima/98_catalogo.R`. Si el script avisa que faltan columnas, cambió el formato de exportación: avísame.

### 8.3 MODIS NDVI/EVI (NASA Earthdata + AppEEARS)
1. Crea una cuenta gratuita en https://urs.earthdata.nasa.gov/users/new.
2. Entra en https://appeears.earthdatacloud.nasa.gov con esa cuenta → *Extract* → *Area* → *Start a new request*.
3. **Nombre:** `paraguay_mod13a3`. **Área:** sube `input/acquisition_candidates/clima_agro_2026-09-23/ine/DEPARTAMENTOS_PY_CNPV2022.geojson`. Si el portal lo rechaza por tamaño, dibuja un rectángulo de −62,7 a −54,2 de longitud y de −27,7 a −19,2 de latitud.
4. **Fechas:** 02-01-2000 a la fecha actual (formato MM-DD-YYYY).
5. **Producto:** `MOD13A3.061` (Vegetation Indices Monthly L3 Global 1 km). **Capas:** `_1_km_monthly_NDVI`, `_1_km_monthly_EVI` y `_1_km_monthly_pixel_reliability`.
6. **Salida:** formato *GeoTIFF*; proyección *Geographic* (WGS84).
7. Envía el pedido. Cuando llegue el correo, descarga todos los `.tif` y cópialos a `input/acquisition_candidates/clima_agro_2026-09-23_faseB/modis/`.
8. Corre `Rscript R/clima/13_modis_ndvi.R` y `Rscript R/clima/98_catalogo.R`. El script acepta los dos formatos de nombre de AppEEARS (`…_NDVI_doy2000032_aid0001.tif` y `…_NDVI_20000201T000000_aid0001.tif`).

### 8.4 Otros pendientes manuales (opcionales)
- **Yacyretá (generación mensual):** EBY, *Memoria anual* (https://www.eby.gov.py/memoria-anual/, PDF), o la base mensual de CAMMESA (https://cammesaweb.cammesa.com, sección *Históricos*). Hace falta ubicar una tabla mensual por central; si consigues el archivo, lo incorporo con un script.
- **Algodón 1930–2026:** descarga manual desde https://www.datos.gov.py/dataset/series-hist%C3%B3ricas-del-algod%C3%B3n-1930%E2%80%932026 (los recursos no exponen enlace directo). Déjalo en `…_faseB/mag/algodon/`.
- **Estaciones DMH (validación de la grilla):** solicitud con arancel en https://www.meteorologia.gov.py/servicio-publico/. Solo si se necesita validar CHIRPS y ERA5-Land o analizar extremos diarios observados.
- **IRI 2025-05 en adelante:** transcribir desde el sitio (las tablas se muestran con JavaScript) o pedirlas al IRI.

## 9. Catálogo generado de los datos

<!-- CATALOGO:INICIO -->
*Generado por `R/clima/98_catalogo.R` el 2026-09-24 08:20 a partir de los archivos; no editar a mano. Detalle por variable (unidad, rango, NA, flags) en `00_catalogo_variables.csv`.*

| Archivo | Filas | Variables | Frecuencia | Nivel geográfico (n unidades) | Desde | Hasta | Proyectos |
|---|---|---|---|---|---|---|---|
| `enso_indices.csv` | 6.217 | 8 | bimestral_movil, mensual, trimestral_movil | global (1) | 1950-01-01 | 2026-08-01 | 09 D1, 12 D4, 13 D5, 10 D2*, 11 D3* |
| `clima_chirps_precipitacion.csv` | 32.880 | 3 | mensual | departamento, nacional (20) | 1981-01-01 | 2026-08-01 | 10 D2*, 09 D1, 12 D4, 13 D5, 22 N1, 23 N2, 28 N7 |
| `clima_spi.csv` | 43.480 | 4 | mensual | departamento, nacional (20) | 1981-01-01 | 2026-08-01 | 10 D2*, 13 D5, 12 D4, 28 N7, 23 N2 |
| `hidro_itaipu_diario.csv` | 78.096 | 8 | diaria | estacion (1) | 2000-01-01 | 2026-09-22 | 19 F3*, 22 N1, 09 D1 |
| `hidro_itaipu_mensual.csv` | 5.778 | 18 | mensual | estacion (2) | 2000-01-01 | 2026-09-01 | 19 F3*, 22 N1, 09 D1 |
| `enso_iri_pronosticos.csv` | 6.768 | 60 | vintage_mensual | global (1) | 2003-06-01 | 2025-04-01 | 11 D3*, 12 D4 |
| `agro_faostat_nacional.csv` | 18.471 | 304 | anual | nacional (1) | 1961-01-01 | 2024-01-01 | 10 D2*, 09 D1, 12 D4 |
| `agro_usda_psd_nacional.csv` | 15.028 | 288 | anual | nacional (1) | 1960-01-01 | 2026-01-01 | 10 D2*, 09 D1, 12 D4 |
| `abasto_precios_diario.csv` | 41.574 | 84 | diaria | mercado (1) | 2021-01-04 | 2026-06-29 | 12 D4, 18 F2, 26 N5 |
| `abasto_precios_mensual.csv` | 1.816 | 56 | mensual | mercado (1) | 2021-01-01 | 2026-06-01 | 12 D4, 18 F2, 26 N5 |
| `abasto_ingresos_mensual.csv` | 1.680 | 8 | mensual | mercado (1) | 1991-01-01 | 2023-12-01 | 12 D4, 18 F2, 26 N5 |
| `eventos_emdat_mensual.csv` | 228 | 24 | mensual | nacional (1) | 1965-06-01 | 2025-12-01 | 09 D1, 13 D5, 28 N7, 23 N2 |
| `agro_mag_departamental.csv` | 21.924 | 75 | campania | departamento, nacional (18) | 2007-07-01 | 2024-07-01 | 10 D2*, 09 D1, 13 D5, 12 D4 |
| `rios_dmh_diario.csv` | 122.073 | 1 | diaria | estacion (3) | 1904-01-01 | 2026-09-23 | 19 F3*, 09 D1, 10 D2*, 18 F2 |
| `rios_dmh_mensual.csv` | 16.056 | 4 | mensual | estacion (3) | 1904-01-01 | 2026-09-01 | 19 F3*, 09 D1, 10 D2*, 18 F2 |
| `clima_modis_vegetacion.csv` | 18.821 | 3 | mensual | departamento, nacional (20) | 2000-02-01 | 2026-08-01 | 10 D2*, 13 D5 |

<!-- CATALOGO:FIN -->
