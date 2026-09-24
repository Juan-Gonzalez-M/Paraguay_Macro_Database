# Diagnóstico del bloque climático y agroclimático — Fase A

*2026-09-23 · Carpeta revisada: `input/acquisition_candidates/clima_agro_2026-09-23/`. La ruta indicada en el pedido (`input/acquisition/candidates_clima_agro_2026-09-23/`) no existe; esta es la única carpeta de candidatos clima/agro del repositorio.*

> **Nota posterior (2026-09-23, Fase B):** a pedido del usuario se eliminaron de esta carpeta los CSV y XLSX de MAG 2020–2021, `usda/paraguay_crop_calendar_2024_report.pdf`, `fao/gaez_portal_page.html` y `dmh/anuario_climatologico_2022.pdf`. La ruta, el SHA-256, la URL y el motivo de cada uno están en `eliminados_2026-09-23.csv`. El resto de este diagnóstico describe la carpeta tal como estaba antes de esa limpieza.

**Alcance.** No se descargó, modificó ni transformó ningún archivo original. Solo se leyeron los archivos y se escribió este documento. Los datos candidatos están **fuera** del pipeline de DuckDB (`input/current/`, registro de fuentes, releases). Lo que produzca la Fase B en `data/clima/` será un insumo de investigación, no una fuente publicada en la base. Incorporarlo a la base requeriría parser, entrada en el registro y el flujo de candidato y release (`docs/ARCHITECTURE.md`).

**Verificaciones hechas en esta fase** (independientes del `README.md` previo de la carpeta):

- SHA-256 y tamaño recalculados para los **615 archivos** de `inventory.csv`: 0 discrepancias y 0 faltantes.
- CHIRPS: los 548 GeoTIFF se decodificaron completos. El calendario mensual es continuo (1981-01 → 2026-08) y los valores sobre Paraguay son plausibles: la sequía de enero de 2022 da 73 mm de media, frente a 199 mm en enero de 1981.
- FAOSTAT: el ZIP pasa la prueba de integridad. La producción de soja coincide con el total de MAG en 15 de 17 años con la regla *año FAO = año de cosecha de la campaña MAG* (2009, 2012 y 2022 muestran las sequías).
- MAG: se compararon celda a celda los dos libros de series históricas que se superponen (sección 1.3). Aparecieron **conflictos de versión** en 2024/25.
- Los ONI y RONI de la carpeta son idénticos byte a byte a los que ya usan los proyectos 09, 12 y 13.

Abreviaturas de proyectos (carpeta · ficha): **09** D1 ENSO no lineal · **10** D2 clima por calendario agrícola* · **11** D3 pronósticos ENSO* · **12** D4 inflación climática · **13** D5 clima y riesgo de crédito · **18** F2 pass-through y frontera · **19** F3 río, logística e hidroelectricidad* · **22** N1 política fiscal (binacionales) · **23** N2 mercado laboral (episodios de sequía) · **26** N5 shocks de Argentina · **28** N7 alivio crediticio (medidas por sequía). *(\*) Ficha del bloque 3, sin carpeta construida todavía.*

---

## 1. Estado de lo disponible

### 1.1 Clima e índices ENSO

| Archivo(s) | Fuente | Contenido y variables | Frecuencia | Cobertura temporal | Cobertura geográfica | Formato | Estado |
|---|---|---|---|---|---|---|---|
| `chc/monthly_latam/chirps-v3.0.YYYY.MM.tif` (548) + `chc/monthly_latam_index.html` | UCSB Climate Hazards Center, CHIRPS v3.0 | Precipitación total mensual (mm/mes), float32 | Mensual | 1981-01 → 2026-08 | Grilla de 0,05° (~5,5 km) de América Latina (lon −120 a −34; lat 35 a −60); Paraguay completo | GeoTIFF (LZW), 2,1 GB | **Completo y legible.** Sin recortar ni agregar. El índice fecha la historia en nov–dic de 2024 (publicación de la v3) y agrega un mes por mes; hay que verificar si CHC revisa los meses recientes. |
| `noaa/oni.ascii.txt` | NOAA CPC | ONI: SST Niño 3.4 (total y anomalía), media móvil de 3 meses | Estacional móvil (mensual) | DJF 1950 → JJA 2026 (919) | Índice global | Texto de ancho fijo | Completo. Idéntico al de los proyectos. |
| `noaa/RONI.ascii.txt` | NOAA CPC | ONI relativo (descuenta el calentamiento tropical medio) | Estacional móvil | DJF 1950 → JJA 2026 | Índice global | Texto | Completo. Idéntico al de los proyectos. |
| `noaa/meiv2.csv` | NOAA PSL | MEI.v2 (índice multivariado ENSO) | Bimestral móvil | 1979-01 → 2026-08 | Índice global | CSV | Completo. **Cautela:** el encabezado declara faltante = −999 pero el archivo usa −9999 (meses 2026-09 a 2026-12). |
| `nasa_power/asuncion_daily_1981_2025.csv` | NASA POWER (MERRA-2) | T2M, T2M_MAX, T2M_MIN (°C) y PRECTOTCORR (mm/día) | Diaria | 1981-01-01 → 2025-12-31 (16.436 días, 0 faltantes) | **Un punto** (−25,3; −57,6), celda de 0,5° × 0,625° | CSV con encabezado | Completo, pero de representatividad espacial baja: es una celda de reanálisis, no una estación ni un panel departamental. |
| `copernicus/era5_land_dataset_page.html` | Copernicus CDS | Página del catálogo ERA5-Land (horario, 0,1°, 1950–presente, licencia CC-BY) | — | — | — | HTML | **Solo enlace, sin datos.** Requiere cuenta CDS y aceptar la licencia. |
| `dmh/anuario_climatologico_2022.pdf` | DMH–DINAC | Anuario de 2022: 19 estaciones convencionales (lista con coordenadas y altitud), resúmenes mensuales, olas de calor y frío, SPI anual (texto) | Mensual (un año) | 2022 | 19 estaciones | PDF, 79 páginas | Completo como documento, pero las tablas mensuales **no se pueden extraer como texto** (van como imagen). Útil como metadatos de estaciones y para validar episodios. |
| `dmh/anuario_2025_page.html` | DMH | Página del anuario 2025 | — | — | — | HTML | Sin enlace a PDF ni datos en la página guardada. |
| `dmh/servicio_publico.html` | DMH | Condiciones del servicio de datos: solicitud y pago de arancel | — | — | — | HTML | Documento de acceso. Confirma que las series de estaciones **no son de descarga libre**. |

### 1.2 Hidrología y ENSO pronosticado

| Archivo(s) | Fuente | Contenido | Frecuencia | Cobertura | Formato | Estado |
|---|---|---|---|---|---|---|
| `dmh/niveles_rio_actuales.html` | DMH, niveles hidrométricos | Nivel del día, variación y mínimo y máximo históricos de **31 estaciones** (ríos Paraguay y Paraná y puertos brasileños), con su código (`code=`) | Instantánea (22–23/09/2026) | Una fecha | HTML | Instantánea. Da el catálogo de estaciones: Asunción 2000086218, Pilar 2000086255, Concepción 2000086134, Encarnación 2000086297, Ayolas 2000086261, entre otras. |
| `dmh/river_asuncion_detail.html`, `…_page_1000.html` | DMH | Nivel diario de Asunción (m) | Diaria | La página declara **44.796 registros** (≈ 122 años si no hay huecos). Se guardaron la página 1 (sep-2026) y la 1000 (ago-1985). | HTML paginado, 15 registros por página (≈ 2.987 páginas) | **Muestra parcial.** No hay exportación masiva. |
| `dmh/river_pilar_detail.html` | DMH | Nivel diario de Pilar (m) | Diaria | **34.571 registros** declarados; solo se guardó la página 1 | HTML paginado (≈ 2.305 páginas) | Muestra parcial. **Concepción: sin descargar.** |
| `iri/enso_forecast_archive.html`, `iri/enso_forecast_2024_10.html`, `iri/enso_forecast_2012_10.pdf` | IRI Columbia | Probabilidades de La Niña, Neutral y El Niño por temporada. La página de 2024 trae una **tabla HTML** (9 temporadas); el PDF de 2012 es un gráfico de una página. El selector del sitio cubre 2002–2026. | Mensual (vintage de publicación) | 3 ejemplos | HTML y PDF | **Muestra.** Prueba que existe un archivo mensual 2002–2026 con tablas extraíbles; falta armar la serie de vintages. |

### 1.3 Producción agrícola, censos y precios (MAG, FAO, USDA)

| Archivo(s) | Fuente | Contenido | Frecuencia | Cobertura temporal | Cobertura geográfica | Formato | Estado |
|---|---|---|---|---|---|---|---|
| `mag/cultivos_tres_departamentos/1 - SERIEHISTORICA_16_principales.xlsx` | MAG–DCEA, *Síntesis Estadística* | **Superficie (ha), producción (t) y rendimiento (kg/ha) de 16 cultivos**: soja, maíz, algodón, mandioca, trigo, poroto, caña, maní, girasol, arroz con riego, tabaco, sésamo, tártago, canola, ka'a he'e y yerba mate | Anual por campaña | **2007/08 → 2024/25** (18 campañas) | **17 departamentos + total nacional** (sin fila para Asunción) | xlsx ancho: 3 bloques por hoja y notas al pie | **Completo. Es el hallazgo más valioso de la carpeta:** el catálogo lo titula «tres departamentos», pero es un panel nacional por departamento. Ver notas de calidad abajo. |
| `mag/arroz_2020_2025/SERIE_HISTORICA_CULTIVOSTEMPORALES.xlsx` | MAG–DCEA | Los mismos 3 bloques para **22 cultivos**. Agrega ajo, batata, cebolla, frutilla, locote, papa, sorgo, tomate y zanahoria; no trae tabaco, tártago ni yerba mate. | Anual por campaña | 2020/21 → 2024/25 | 17 departamentos + total | xlsx ancho | Completo. Coincide con el libro de 16 cultivos salvo por los conflictos de abajo. |
| `mag/cultivos_2020_2021/*.csv` (14) y `*.xlsx` (2) | MAG | Superficie y producción (sin rendimiento) de 16 cultivos. Las columnas «2020» y «2021» son las **campañas 2019/20 y 2020/21** (comprobado en soja). | Anual | 2 campañas | 17 departamentos, sin total | CSV `;` con punto como separador de miles | Completo pero **redundante** con el libro de 16 cultivos. |
| `mag/sesamo_2018_2024/…SERIEHISTORICA_SESAMO_2018-2024.xlsx` y `…Cuadro37…xlsx` | MAG; CAN 2022 | Serie de sésamo 2017/18–2024/25 por departamento; Cuadro 37 del CAN 2022 (fincas, superficie y producción de sésamo por departamento y distrito) | Anual; corte censal | 2017/18–2024/25; 2022 | Departamento; distrito | xlsx | Completo. La serie coincide con el libro de 22 cultivos, **no** con el de 16 en 2024/25. |
| `mag/can_2022/VOLUMEN I - CAN 2022 _final.xlsx` | MAG, Censo Agropecuario Nacional 2022 | 78 cuadros por **departamento × tamaño de finca**, entre ellos cultivos (C26–C35, con soja y maíz separados en **zafra y zafriña**), hortícolas y permanentes, ganado (C52–C58), **fuentes de agua** (C59), **acceso a crédito** (C70) y seguro e insumos | Corte censal | Campaña 2021/22 (algunos cuadros comparan con 2008) | 17 departamentos | xlsx (79 hojas) | Completo. |
| `mag/historico_tres_departamentos/CAN2022_Vol4_0{6,7,8}_*.xlsx` | MAG, CAN 2022 Vol. 4 | Los mismos cuadros por **distrito** para Caazapá, Itapúa y Misiones | Corte censal | 2022 | 3 departamentos, por distrito | xlsx (78 hojas cada uno) | Completo. El título del catálogo («2009–2024») no corresponde: es el CAN 2022. |
| `mag/cultivos_tres_departamentos/{2..8} - CUADRO{52,62,70,71,73,74,75}*.xls` | MAG, CAN 2008 | Uso de la tierra; algodón y soja zafra normal; soja zafriña y trigo; maíz zafra y zafriña; maíz chipa y pichinga; mandioca y maíz locro | Corte censal | 2008 (campaña 2007/08) | **Todo el país por departamento y distrito** (≈ 225 distritos) | xls (BIFF) | Completo. Sirve como línea de base de exposición anterior a la muestra. |
| `mag/mercado_abasto/Precios_2021_Jun2026.xlsx` | MAG/SIMA con datos de DAMA | Precio mínimo, común y máximo **mayorista** de ají, cebolla, huevo, lechuga, pimiento y tomate, con **origen PY, AR o BR** | Diaria (días hábiles) | 2021-01-04 → 2026-06-29 (13.858 filas) | Mercado de Abasto de Asunción | xlsx largo | Completo para 6 rubros. |
| `mag/mercado_abasto/{Tomate,Cebolla,Lechuga,Pimiento2}.xls` | MAG/SIMA con datos de DAMA | Ingresos mensuales (kg) al Mercado, nacionales e importados | Mensual | 2010–2023 (Hoja2 de algunos: 1991–1997) | Mercado de Asunción | xls ancho (años × meses) | **Parcial, con alertas de calidad** (abajo). |
| `mag/catalogo_*.html` (9) | datos.gov.py | Páginas de catálogo | — | — | — | HTML | Evidencia de origen. **`catalogo_algodon_historico.html` es una página de búsqueda:** la serie de algodón 1930–2026 **no se descargó**. **`catalogo_censo_agropecuario_2022.html` no lista recursos.** |
| `faostat/Production_Crops_Livestock_E_All_Data_Normalized.zip` | FAOSTAT (QCL) | Producción, área cosechada, rendimiento, existencias y faena. Paraguay: **131 ítems, 18.471 filas**, con flags A/E/X/M/I | Anual (año calendario) | 1961 → 2024 | Nacional (el ZIP trae todos los países) | ZIP con CSV largo (545 MB descomprimido) | Completo. |
| `usda/grain_feed_annual_paraguay_2025.pdf` | USDA FAS, GAIN PA2025-0002 | Informe narrativo: pronósticos por año comercial de trigo, maíz y arroz, más texto sobre ventanas de siembra y cosecha | Anual | MY 2025/26 | Nacional | PDF, 11 páginas | Completo como documento. **No es una base de datos.** |
| `usda/paraguay_crop_calendar_2024_report.pdf` | USDA IPAD | Respuesta HTML «IPAD retired» | — | — | — | **HTML con extensión .pdf** | **Inválido: no contiene datos.** |
| `fao/gaez_portal_page.html` | FAO GAEZ | Página del portal | — | — | — | HTML | Solo enlace. |
| `ine/DEPARTAMENTOS_PY_CNPV2022.geojson` | INE, CNPV 2022 | Límites de 18 unidades (17 departamentos + Asunción), `DPTO` y `DPTO_DESC` | Estático | 2022 | Departamento | GeoJSON, EPSG:4674 (SIRGAS 2000) | Completo. |
| `ine/DISTRITOS_PY_CNPV2022.geojson` | INE, CNPV 2022 | 263 distritos, clave `CLAVE` = DPTO + DISTRITO | Estático | 2022 | Distrito | GeoJSON, EPSG:4674 | Completo. |
| `bcp/metodologia_ipc_base_2017.pdf` (registrado en `failures.jsonl`) | BCP | — | — | — | — | — | **No existe:** HTTP 403. Queda fuera de este bloque (rango 5 de la priorización). |

**Notas de calidad de MAG** (a conservar como flags en la Fase B; **no corregir**):

1. **Conflictos entre versiones publicadas.** El libro de 16 cultivos y el de 22 cultivos difieren en:
   - **Sésamo 2024/25:** 27 celdas. La superficie total es 105.236 ha en el de 16 cultivos frente a 29.146 ha en el de 22 cultivos y en el archivo de sésamo.
   - **Trigo 2024/25:** 35 celdas.
   - **Algodón 2023/24 y mandioca 2020/21:** 1 celda cada uno.

   El resto de los cultivos coincide celda a celda. No hay evidencia para decidir cuál prevalece: ambas versiones deben conservarse con su archivo de origen.
2. **Estimaciones, no observaciones independientes por departamento:**
   - 2022/23 y 2023/24: la superficie de soja de **todos** los departamentos crece en el mismo porcentaje (+1,93% y +1,2%) sobre el dato censal 2021/22.
   - 2015/16 y 2016/17: valores fraccionarios, compatibles con un prorrateo.
   - En esos años la variación entre departamentos es artificial. Esto importa para D2 y D5.
3. **Quiebre en 2019/20** en la distribución departamental: por ejemplo, la soja de Concepción pasa de 40.987 a 3.300 ha y la de Boquerón de 5.035 a 25.000 ha, aunque el total nacional casi no cambia. Probablemente es un cambio de método.
4. **Marcas de encabezado:**
   - `*`: dato censal (2007/08 y 2021/22).
   - `(1)`: 2024/25 **preliminar**, elaborado con la ENA 2025 para la Región Oriental y una proyección para la Occidental.
   - `**` y `***`: merma por sequía, helada o exceso de lluvia. La marca va en la campaña, no en la celda.
   - `(-)`: «ningún valor». Es distinto de 0.
5. **Maíz** se publica sin separar zafra y zafriña en las series; la separación solo existe en los censos 2008 y 2022.
6. **Volúmenes del Mercado de Abasto:**
   - 2020–2023: valores con decimales y crecimiento suave, compatibles con estimaciones o proyecciones.
   - Tomate importado 2018: fila **idéntica** a la del tomate nacional 2018, posiblemente un error de copia de la fuente.

---

## 2. Cobertura frente a las necesidades de los proyectos

Variables climáticas y agroclimáticas que piden `00_mapeo_proyectos.md`, `00_resumen_viabilidad.md` (rangos 2 y 11) y los README de 09, 12, 13 y 22.

| # | Necesidad | Proyectos | Lo disponible | Estado |
|---|---|---|---|---|
| V1 | Índices ENSO: ONI, RONI, Niño 3.4, **SOI**, MEI | 09 (tratamiento), 12, 13, 10, 11 | ONI, RONI y MEI.v2 en la carpeta; Niño 3.4 mensual ya está en los proyectos (`sstoi.indices`) | ✅ salvo **SOI** (❌) |
| V2 | Vintages de pronósticos ENSO | 11 (variable central), 12 (densidades) | 2 ejemplos de IRI | 🟡 muestra; hay que construir la serie 2002–2026 |
| V3 | Precipitación mensual nacional y departamental | 10 (central), 09 (mecanismo), 12 (nivel mínimo «clima»), 13 (clima geográfico), 22, 23 y 28 (episodios de sequía) | CHIRPS 1981–2026 en grilla; límites del INE | 🟡 **dato completo, falta procesarlo** (agregación por departamento) |
| V4 | Temperatura media, máxima y mínima; olas de calor y heladas | 10, 12 (Kotz et al.), 09, 13 | Solo NASA POWER en un punto; anuario DMH 2022 (un año, tablas en imagen) | ❌ para el panel departamental |
| V5 | Sequía: SPI, SPEI y humedad del suelo | 10, 13, 12, 28, 23 | Nada precalculado. El SPI se puede calcular con CHIRPS; el SPEI necesita evapotranspiración potencial (PET), que no está. | 🟡 SPI calculable; ❌ SPEI y humedad del suelo |
| V6 | Niveles de los ríos Paraguay y Paraná (Asunción, Pilar, Concepción) | 19 (central), 09 (canal), 10, 18 | Páginas de muestra de Asunción y Pilar; catálogo de 31 estaciones | ❌ serie; 🟡 acceso comprobado |
| V7 | Hidrología y generación de Itaipú y Yacyretá | 19 (módulo energía), 22 (exogeneidad de los ingresos binacionales), 09 (PIB de electricidad) | Nada en la carpeta. La base tiene exportaciones de energía en kWh (Cuadro 44b) y divisas de binacionales (Cuadro 55), pero no generación ni caudales. | ❌ |
| V8 | Área, producción y rendimiento por cultivo y campaña | 10 (central), 09 (mecanismo: separar cosecha de exportación), 13 (exposición), 12 (oferta de alimentos) | MAG por departamento 2007/08–2024/25; FAOSTAT nacional 1961–2024; CAN 2008 y 2022 | ✅ (con notas de calidad) |
| V9 | Calendario de cultivos (siembra y cosecha) | 10 (central); 09, 12 y 13 (ventanas de agregación) | Texto del USDA GAIN 2025; el enlace de IPAD está muerto | 🟡 cualitativo |
| V10 | Vegetación (NDVI/EVI) | 10 (nivel ideal), 13 (opcional) | — | ❌ |
| V11 | Eventos extremos fechados (inundación, sequía, helada) | 09 (validación de episodios), 13, 28 (medidas por sequía e inundación), 23 | Texto del anuario DMH 2022; marcas `**` de MAG | ❌ registro sistemático |
| V12 | Precios mayoristas de alimentos | 12 (brecha explícita en su README); 18 y 26 (origen AR/BR) | Abasto 2021–2026 diario (6 rubros); volúmenes 2010–2023 | 🟡 corto y pocos rubros |
| V13 | Ponderadores geográficos (límites, área agrícola por departamento) | todos los que agreguen clima | GeoJSON del INE; área por departamento de MAG y de los CAN | ✅ |

**En síntesis:** lo descargado cubre bien **ENSO observado**, **precipitación** (en bruto) y **producción agrícola**. Falta lo necesario para **temperatura, humedad del suelo, SPEI, ríos, hidroelectricidad, pronósticos ENSO, eventos extremos y vegetación**.

---

## 3. Brechas: fuentes propuestas

### 3.1 Agregar

| Fuente | Qué aporta | Necesidad | Proyectos | Acceso | Prioridad |
|---|---|---|---|---|---|
| **CHIRPS v3** (ya descargado) → agregación por departamento | Lluvia mensual por departamento y nacional; anomalías; base del SPI | V3, V5 | 10, 09, 12, 13, 22, 23, 28 | Ya local | **Alta** |
| **SPI 1, 3, 6 y 12** calculado sobre CHIRPS | Sequía estandarizada por departamento, comparable entre regiones | V5 | 10, 13, 12, 28, 23 | Paquete R `SPEI` (CRAN) | **Alta** |
| **ERA5-Land**, medias mensuales (y estadísticas diarias para extremos) | Temperatura a 2 m, humedad del suelo por capas, evaporación y PET (insumo del SPEI); 0,1°, 1950–presente | V4, V5 | 10, 12, 13, 09 | API CDS (`ecmwfr` en R). **Requiere cuenta gratuita en CDS y aceptar la licencia CC-BY del conjunto.** | **Alta** |
| *Alternativa sin credenciales:* **TerraClimate** | Tmáx, Tmín, PET, humedad del suelo y PDSI mensuales a ~4 km | V4, V5 | ídem | Descarga directa de NetCDF (servidor THREDDS) | Solo si no hay cuenta CDS. **Limitación:** se actualiza una vez al año y hoy termina en 2024. |
| **SPEI 3, 6 y 12** (PET de ERA5-Land o TerraClimate + lluvia CHIRPS) | Sequía con balance hídrico, que el SPI no capta porque ignora la temperatura | V5 | 10, 13, 12 | Paquete `SPEI`; **SPEIbase** (CSIC, 0,5°) como contraste, de descarga directa | Media |
| **SOI** (NOAA CPC) y **Niño 3.4 mensual** | Completa los «varios índices» que pide D1 | V1 | 09, 12, 13 | Descarga directa (texto) | Alta (costo mínimo) |
| **IRI, vintages de pronósticos ENSO 2002–2026** | Probabilidades de La Niña, Neutral y El Niño por temporada y mes de emisión | V2 | 11 (central), 12 | Web: ≈ 290 páginas HTML mensuales con tabla (extracción lenta y registrada). Los meses que solo tengan PDF o gráfico quedan marcados como faltantes. | Media |
| **DMH, niveles diarios de ríos**: Asunción, Pilar, Concepción; opcionalmente Encarnación y Ayolas (Paraná) | Nivel diario → promedio, mínimo y máximo mensual, y días bajo umbrales de navegación | V6 | 19, 09, 10, 18 | Web paginada, 15 registros por página (≈ 2.987 páginas en Asunción, ≈ 2.305 en Pilar). **Alternativa:** pedir el archivo tabular a DMH o a la ANNP. | Media-alta para F3 |
| **ONS Brasil**, datos abiertos de hidrología de embalses (Itaipú) | Caudal afluente y defluente, y nivel del embalse de Itaipú, diarios | V7 | 19, 22, 09 | Descarga directa (CSV o Parquet, sin registro). A verificar: cobertura de Itaipú y de ambos sectores. | Media |
| **Generación de Itaipú y Yacyretá** (Itaipú Binacional; EBY o CAMMESA; ANDE, *Compilación Estadística*) | Generación mensual en GWh por central | V7 | 19, 22, 09 | Sitios oficiales en HTML o PDF (en parte manual). CAMMESA publica planillas públicas. | Media |
| **USDA PSD** (*Production, Supply and Distribution*) | Oferta y uso por año comercial (soja, maíz, trigo, arroz, algodón, carne): producción, exportación y stocks | V8 | 10, 09, 12 | Descarga masiva de CSV, sin registro. **Cautela:** el año en curso es pronóstico y se revisa cada mes. | Media |
| **Calendario de cultivos** (tabla propia documentada) | Meses de siembra y cosecha de soja zafra y zafriña, maíz, trigo, arroz y hortícolas | V9 | 10, 09, 12, 13 | Construcción manual con fuentes citadas: USDA GAIN 2025 (ya local), FAO GIEWS *Country Brief* y calendarios de GEOGLAM Crop Monitor (públicos) | Media |
| **EM-DAT** | Desastres en Paraguay fechados (inundaciones, sequías, tormentas, temperaturas extremas), con afectados y daños | V11 | 09, 13, 28, 23 | **Requiere registro gratuito** (uso no comercial) en public.emdat.be; descarga manual de Excel | Media-baja |
| **MODIS MOD13A3** (NDVI/EVI mensual, 1 km, 2000–presente) | Condición de la vegetación y los cultivos dentro de la campaña | V10 | 10, 13 | **Requiere cuenta gratuita en NASA Earthdata** (AppEEARS o LP DAAC) | Baja: diferir hasta que se construya D2 |

### 3.2 Completar

| Fuente | Qué falta |
|---|---|
| MAG, series históricas | Serie de algodón 1930–2026 (el catálogo guardado es una búsqueda vacía). Opcionalmente, versiones anteriores de la *Síntesis Estadística* (antes de 2007/08) para alargar el panel. |
| DMH, ríos | Concepción (código 2000086134), sin descargar. |

### 3.3 Descartar o no usar como dato principal

| Fuente | Decisión | Justificación |
|---|---|---|
| FAO GAEZ | Descartar | Capas estáticas de aptitud y suelos: no varían en el tiempo, y los diseños de D2 y D5 se identifican con shocks temporales × exposición. La exposición se mide mejor con el área cultivada de MAG o del CAN. |
| `usda/paraguay_crop_calendar_2024_report.pdf` | Descartar | No es un PDF ni contiene datos (página «IPAD retired»). Se conserva solo como evidencia de la respuesta. |
| NASA POWER (punto) | Reemplazar por grilla; mantener para validación | Una sola celda de 0,5° no forma un panel departamental. Queda para contrastar la temperatura de ERA5-Land o TerraClimate en Asunción. |
| Anuario DMH 2022 | No usar como serie | Un solo año y tablas en imagen. Sirve para las coordenadas de las 19 estaciones y para validar episodios. |
| Series de estaciones DMH (pago de arancel) | Diferir | CHIRPS y ERA5-Land dan cobertura continua sin costo. Pedir 5–10 estaciones solo si se necesita validar la grilla o analizar extremos diarios con dato observado. |
| CSV de MAG 2020–2021 | Redundante | Incluidos en el libro de 16 cultivos. Se conservan como evidencia; no entran al procesamiento. |
| CAN 2022 Vol. 4 (Caazapá, Itapúa, Misiones) | Diferir | El detalle por distrito existe solo para 3 departamentos; el Vol. I cubre todo el país por departamento. |
| IRI PDF 2012 | Sustituir por las tablas HTML | Es un gráfico; para las probabilidades usar las tablas HTML. |
| CAPECO | Diferir (contraste opcional) | Duplica la producción de soja, maíz y trigo de MAG y USDA. Su valor añadido (separar zafriña) se obtiene en parte de los CAN. Se publica en el sitio web sin formato estable. |
| Metodología del IPC del BCP (HTTP 403) | Fuera de este bloque | Pertenece al rango 5 (ponderadores del IPC), no al clima. |

---

## 4. Formato

### 4.1 Evaluación de lo disponible

| Formato actual | Fuentes | ¿Apto para análisis? | Transformación necesaria |
|---|---|---|---|
| GeoTIFF de toda la región, 2,1 GB | CHIRPS | No directamente | Recorte a Paraguay; media ponderada por fracción de celda sobre los polígonos del INE; SPI por departamento |
| Texto de ancho fijo con temporadas «DJF», «JFM», etc. | ONI, RONI | Casi | Leer la temporada y fecharla en el **mes central**, como ya hacen los proyectos. No se aplica rezago en los datos: el rezago va en el análisis. |
| CSV con −9999 como faltante | MEI.v2 | Casi | −9999 → NA. Documentar que el índice es bimestral. |
| xlsx ancho con 3 bloques por hoja, encabezados con marcas y notas al pie | MAG, CAN | No | Reestructurar a formato largo conservando la etiqueta de campaña tal como se publica, la marca (`*`, `(1)`, `**`), el archivo y la hoja de origen |
| xls antiguo (BIFF) ancho años × meses | Volúmenes del Abasto; CAN 2008 | No | Pasar a formato largo con flag de calidad |
| xlsx largo diario | Precios del Abasto | Sí | Solo normalizar fecha, unidad (kg o docena) y origen |
| HTML paginado | Ríos DMH; IRI | No | Extracción con control de cobertura (páginas y registros esperados frente a obtenidos) |
| PDF narrativo | USDA GAIN; anuario DMH | No | Solo como referencia documental (calendario, episodios) |

### 4.2 Formato de destino propuesto (Fase B)

- **Un CSV largo por fuente** en `data/clima/` (UTF-8, punto decimal) con las columnas pedidas, en este orden: `fecha, id_geo, nivel_geo, variable, valor, unidad, fuente`. Propongo **agregar al final** `frecuencia`, `periodo_publicado`, `flag` y `archivo_origen`, para no perder la etiqueta original, las marcas de MAG ni la trazabilidad (ver pregunta 4).
- **Frecuencia mensual como base** para clima, ENSO, ríos y precios. Los datos anuales (MAG, FAOSTAT, USDA) quedan en archivos anuales aparte: **no se interpolan a mensual**.
- **Geografía:**
  - `nivel_geo` ∈ {`nacional`, `departamento`, `estacion`, `punto`}.
  - `id_geo` = `PY` para el nivel nacional y el código INE de 2 dígitos para los departamentos (`PY-07` = Itapúa), según el GeoJSON CNPV 2022.
  - MAG publica 17 departamentos (sin fila para Asunción; no documenta si la incluye en Central) y el INE 18 unidades (`00` Asunción … `17` Alto Paraguay). El clima se agrega a las 18 unidades del INE y se documenta la correspondencia; no se fusionan unidades sin decirlo.
- **Agregación espacial:** media ponderada por el área de la celda dentro del polígono.
  - El nivel nacional se publica en dos versiones explícitas: (a) ponderada por área y (b) **ponderada por área agrícola**, con pesos departamentales **fijos anteriores a la muestra** (CAN 2008). Así la ponderación no depende del resultado.
  - Nada reemplaza a la versión (a).
- **Anomalías y SPI:** período de referencia **1991–2020** (normal de la OMM, la misma que usa la DMH en el anuario).
- **Herramientas de R que faltan instalar:** `terra`, `sf` y `exactextractr` (los binarios de CRAN para macOS traen GDAL incluido) y `SPEI`; `ecmwfr` si se usa ERA5-Land. Ya están instalados `readxl`, `data.table`, `rvest`, `httr`, `jsonlite` y `lubridate`.
- **Tamaño esperado de las salidas:** menos de 50 MB en total (19 unidades × 548 meses × pocas variables).

---

## 5. Tabla resumen por fuente

| Fuente | Estado | Cobertura | Proyectos | Acción | Acceso |
|---|---|---|---|---|---|
| CHIRPS v3 mensual | Completo (sin procesar) | 1981-01 → 2026-08; grilla 0,05° | 10, 09, 12, 13, 22, 23, 28 | **Usar** (agregar por departamento, calcular SPI) | Descarga directa (hecha) |
| NOAA ONI / RONI | Completo | 1950 → JJA 2026; índice | 09, 12, 13, 10, 11 | **Usar** | Descarga directa (hecha) |
| NOAA MEI.v2 | Completo | 1979-01 → 2026-08 | 09, 12, 13 | **Usar** (robustez) | Descarga directa (hecha) |
| NOAA SOI y Niño 3.4 mensual | Ausente en la carpeta | 1951/1982 → presente | 09, 12, 13 | **Agregar** | Descarga directa |
| NASA POWER (punto Asunción) | Completo, 1 punto | 1981–2025 diario | 09, 12 (validación) | **Reemplazar** como variable principal; usar para validar | API pública (hecha) |
| ERA5-Land (temperatura, humedad del suelo, PET) | Solo enlace | 1950 → presente; 0,1° | 10, 12, 13, 09 | **Agregar** | API CDS; **requiere cuenta y licencia** |
| TerraClimate | Ausente | 1958 → 2024; ~4 km | ídem (alternativa) | Agregar **solo si no hay CDS** | Descarga directa |
| SPI / SPEI | Ausente (calculable) | según los insumos | 10, 13, 12, 28, 23 | **Agregar** (cálculo propio; SPEIbase como contraste) | Paquete R `SPEI`; SPEIbase descarga directa |
| DMH anuario 2022 | Completo, no tabular | 2022; 19 estaciones | 09, 13 (validación) | **Usar solo como metadatos** | Descarga directa (hecha) |
| DMH series de estaciones | Ausente | según la solicitud | validación | **Diferir** | Solicitud con **arancel** |
| DMH niveles de ríos | Muestra (2 páginas de Asunción, 1 de Pilar) | Asunción ≈ 1904 → 2026 (44.796 registros); Pilar 34.571 | 19, 09, 10, 18 | **Completar** (Asunción, Pilar, Concepción) | Web paginada, o solicitud a DMH/ANNP |
| IRI pronósticos ENSO | Muestra (3 archivos) | 2002 → 2026 mensual | 11, 12 | **Completar** | Web (HTML con tabla) |
| ONS Brasil (hidrología de Itaipú) | Ausente | ≈ 2000 → presente, diaria (a verificar) | 19, 22, 09 | **Agregar** | Descarga directa, datos abiertos |
| Generación de Itaipú / Yacyretá | Ausente | mensual (a verificar) | 19, 22, 09 | **Agregar** | Web oficial (en parte manual); CAMMESA descarga directa |
| MAG, 16 cultivos por departamento | Completo, con notas de calidad | 2007/08 → 2024/25; 17 departamentos | 10, 09, 13, 12 | **Usar** (con flags) | Descarga directa (hecha) |
| MAG, 22 cultivos por departamento | Completo | 2020/21 → 2024/25; 17 departamentos | 10, 12 (hortícolas) | **Usar** (conservar las 2 versiones en conflicto) | Descarga directa (hecha) |
| MAG CSV 2020–2021 | Completo, redundante | 2019/20–2020/21 | — | **Descartar** (redundante) | — |
| MAG sésamo 2018–2024 | Completo | 2017/18 → 2024/25 | 10 | **Usar** como versión alternativa de sésamo | Descarga directa (hecha) |
| MAG algodón 1930–2026 | **No descargado** | — | 10 | **Completar** | Descarga directa (datos.gov.py) |
| CAN 2022 Vol. I | Completo | corte 2021/22; departamento | 13, 10 (exposición), 28 | **Usar** (cultivos, agua, crédito) | Descarga directa (hecha) |
| CAN 2022 Vol. 4 (3 departamentos) | Completo | 2022; distrito | — | **Diferir** | — |
| CAN 2008 (cuadros 52–75) | Completo | 2008; departamento y distrito | 10, 13 (pesos anteriores a la muestra) | **Usar** (ponderadores) | Descarga directa (hecha) |
| Abasto, precios mayoristas | Completo (6 rubros) | 2021-01 → 2026-06 diario | 12, 18, 26 | **Usar** (agregar a mensual) | Descarga directa (hecha) |
| Abasto, volúmenes de ingreso | Parcial, con alertas | 2010 → 2023 mensual | 12 | **Usar con flags** | Descarga directa (hecha) |
| FAOSTAT QCL | Completo | 1961 → 2024; nacional | 10, 09, 12 | **Usar** (serie larga nacional) | Descarga directa (hecha) |
| USDA PSD | Ausente | ≈ 1960 → año en curso; nacional | 10, 09, 12 | **Agregar** | Descarga directa masiva |
| USDA GAIN 2025 | Completo (documento) | 2025 | 10 (calendario) | **Usar** como fuente documental | Descarga directa (hecha) |
| USDA crop calendar (IPAD) | **Inválido** | — | — | **Descartar** | — |
| Calendario de cultivos | Ausente | estático | 10, 09, 12, 13 | **Agregar** (tabla manual con citas) | Documental (FAO GIEWS, GEOGLAM, USDA) |
| EM-DAT | Ausente | 1900 → presente; eventos | 09, 13, 28, 23 | **Agregar** | **Requiere registro** (gratuito) |
| MODIS NDVI/EVI | Ausente | 2000 → presente; 1 km | 10, 13 | **Diferir** | **Requiere cuenta NASA Earthdata** |
| CAPECO | Ausente | por campaña | 10 (contraste) | **Diferir** | Web, sin formato estable |
| FAO GAEZ | Solo enlace | estático | — | **Descartar** | — |
| INE GeoJSON (departamentos y distritos) | Completo | CNPV 2022 | todos | **Usar** | Descarga directa (hecha) |

---

## 6. Plan propuesto para la Fase B (sujeto a tu aprobación)

1. **Scripts en `R/clima/`**, uno por fuente:
   - `00_utils.R`: esquema largo, códigos geográficos y manifiesto con hash de los insumos.
   - `01_enso.R`: ONI, RONI, MEI, SOI y Niño 3.4.
   - `02_chirps.R`: lluvia y anomalías por departamento y nacional.
   - `03_spi_spei.R`.
   - `04_era5land.R` (o `04_terraclimate.R`).
   - `05_rios_dmh.R`.
   - `06_iri.R`.
   - `07_hidro_binacionales.R`.
   - `08_mag_produccion.R`.
   - `09_faostat_usda.R`.
   - `10_abasto.R`.
   - `11_calendario_eventos.R`.
2. Las descargas nuevas van **a una carpeta de adquisición nueva y fechada** (p. ej. `input/acquisition_candidates/clima_agro_2026-09-24/`) con su inventario y hashes. La carpeta actual no se toca.
3. Toda salida en `data/clima/` (formato largo) y un catálogo en `data/clima/README.md` con rangos calculados de los propios archivos.
4. Cada script verifica lo que consume y lo que produce: celdas leídas frente a celdas emitidas o clasificadas, meses esperados frente a obtenidos, páginas de río esperadas frente a descargadas. Falla si hay pérdidas sin explicar.

## 7. Preguntas pendientes

Están resumidas en el mensaje de cierre de la Fase A.
