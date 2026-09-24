# Comprobación de disponibilidad: clima y agro

Adquisición inicial del 23 de septiembre de 2026. **Esta carpeta no forma parte de `input/current/`, `input_archive/` ni de DuckDB.** Los archivos descargados se conservan tal como llegaron, sin recortar, corregir o interpretar sus valores. `inventory.csv` guarda URL, fecha, tamaño y SHA-256 de cada archivo; `acquire_public.py` documenta y permite repetir las consultas. Los archivos fuente se mantienen locales y están excluidos de Git mediante `.gitignore` para evitar una publicación accidental de aproximadamente 2,4 GB.

## Resultado comprobado

| Fuente | Descarga comprobada | Alcance y cautela |
|---|---|---|
| CHIRPS v3 | 548 GeoTIFF mensuales de América Latina, enero de 1981 a agosto de 2026, más índice del repositorio. | Serie completa de meses publicados en el índice al momento de la consulta. No se recortó a Paraguay ni se contrastó todavía con estaciones locales. URL base: https://data.chc.ucsb.edu/products/CHIRPS/v3.0/monthly/latam/tifs/ |
| MAG | 16 archivos por cultivo de 2020–2021; libro `SERIE_HISTORICA_CULTIVOSTEMPORALES.xlsx` con 22 hojas de cultivos y campañas 2020/21–2024/25; archivos adicionales de sésamo, tres departamentos, censo y Mercado de Abasto. | Se comprobó que la hoja `SOJA` del libro cubre cinco campañas. Los recursos titulados «históricos 2009–2024» son libros del CAN 2022 para Caazapá, Itapúa y Misiones; el título del catálogo no demuestra un panel anual de esos años. Algunas etiquetas de campaña llevan `*` o `(1)` y requieren revisar notas. Catálogo: https://www.datos.gov.py/group/ministerio-de-agricultura-y-ganader%C3%ADa-mag |
| FAOSTAT | ZIP original del dominio *Crops and livestock products*: prueba `unzip -t` satisfactoria. | Contiene 18.471 filas de Paraguay entre 1961 y 2024, además de otros países. Cobertura nacional anual; no sustituye producción por departamento. URL en `inventory.csv`. |
| NOAA | ONI, RONI y MEI.v2 descargados. | Son índices ENSO observados; no son pronósticos publicados en tiempo real. URLs en `inventory.csv`. |
| INE | GeoJSON de 18 unidades departamentales/capital y de distritos del CNPV 2022. | Son límites para unir clima y producción; no resuelven cambios históricos de jurisdicción. Catálogo: https://www.datos.gov.py/dataset/base-de-datos-geojson-geoespacial-de-departamentos-distritos-ciudades-y-barrios-de-todo-el |
| IRI | Índice de pronósticos, PDF de octubre de 2012 y página de octubre de 2024. | Confirma acceso a ejemplos de vintages. No constituye todavía una base histórica numérica y homogénea de probabilidades. Archivo: https://iri.columbia.edu/our-expertise/climate/forecasts/enso/archive/ |
| DMH–DINAC | Anuario climatológico 2022 (79 páginas), página de servicios y páginas de niveles del río para Asunción y Pilar. | La página de Asunción declara 44.796 registros paginados de 15 en 15; la página 1000 efectivamente muestra agosto de 1985. No se descargó toda la historia ni se encontró un archivo masivo. La DMH indica solicitud y arancel para registros diarios/mensuales de estaciones: https://www.meteorologia.gov.py/servicio-publico/ |
| USDA FAS | Informe *Grain and Feed Annual* de Paraguay 2025, PDF de 11 páginas, con información de ventanas de cultivo. | El antiguo enlace de *Paraguay Crop Travel* devolvió una página HTML «IPAD retired» aunque la URL terminaba en `.pdf`; ese archivo se conserva como evidencia de la respuesta, **no como PDF válido**. |
| NASA POWER | CSV diario puntual de temperatura media/máxima/mínima y precipitación corregida, 1981–2025, en latitud −25,3 y longitud −57,6. | Prueba que la API pública responde sin credenciales. Es un solo punto de resolución gruesa; no equivale a un panel climático departamental ni a ERA5-Land. API: https://power.larc.nasa.gov/docs/services/api/temporal/daily/ |

## Disponibilidad aún limitada

| Fuente o dato | Resultado de la prueba | Paso necesario |
|---|---|---|
| ERA5-Land | El catálogo de Copernicus es accesible, pero sus instrucciones de acceso Zarr solicitan una clave de CDS; no se descargaron campos de temperatura o humedad del suelo. | Iniciar sesión y aceptar las condiciones del conjunto; luego solicitar un subconjunto geográfico y temporal reproducible. https://cds.climate.copernicus.eu/datasets/reanalysis-era5-land |
| Estaciones históricas DMH | La página oficial indica disponibilidad mediante solicitud con arancel; solo se descargó un anuario público. | Solicitar series diarias de estaciones seleccionadas y sus metadatos de ubicación, operación y faltantes. |
| Pronósticos IRI completos | Existen ejemplos archivados, pero no se verificó una descarga masiva estructurada de todos los meses, modelos y horizontes. | Definir el vintage, la familia de pronóstico y el período; reconstruir y auditar la serie histórica. |
| Río Paraguay completo | Historia visible por páginas HTML, sin exportación masiva identificada. | Consultar a DMH/ANNP por archivo tabular, o planificar extracción respetuosa de las páginas con control de cobertura. |
| FAO GAEZ | Se guardó la página pública del portal, sin descargar todavía capas de suelo, aptitud o riego. | Seleccionar variables, versión y resolución para Paraguay; comprobar el mecanismo de descarga del portal. https://www.fao.org/land-water/resources/tools/databases/gaez/en |
| BCP, metodología IPC base 2017 | La URL del PDF respondió HTTP 403 al cliente de descarga; no hay archivo local. | Obtenerlo por el navegador o canal institucional y registrar su URL y hash. |
| Geografía de préstamos, seguros agrícolas, cooperativas y microprecios | No se identificó descarga pública equivalente para los campos requeridos por D5/D4. | Solicitud institucional con definiciones y protección de datos. |

## Comprobaciones y límites

- `inventory.csv` contiene **615 archivos**, **2.424.098.850 bytes**, **cero discrepancias SHA-256** y un archivo con formato inesperado: la respuesta HTML del enlace antiguo del USDA.
- Los 548 nombres mensuales de CHIRPS coinciden con el calendario enero de 1981–agosto de 2026; no hay `.part` pendientes.
- El ZIP de FAOSTAT pasó su prueba de integridad. El GeoJSON departamental se pudo leer como `FeatureCollection` de 18 elementos.
- `failures.jsonl` incluye 16 errores de **registro de hash** de un primer intento con una versión antigua de Python. Los 16 archivos MAG sí se descargaron, se volvieron a registrar y pasan el control final. También registra el HTTP 403 del BCP.
- Estas comprobaciones acreditan acceso y conservación de bytes. **No validan aún definiciones económicas, continuidad estadística, cobertura espacial ni aptitud econométrica.**

Para actualizar los conjuntos públicos automatizados, ejecutar `python3 acquire_public.py mag2020`, `mag-more`, `chirps-monthly`, `extras`, `geography` o `river`. `python3 acquire_public.py finalize` vuelve a generar el inventario y comprueba hashes. La opción `direct --url URL --path RUTA` guarda un recurso adicional dentro de esta carpeta.
