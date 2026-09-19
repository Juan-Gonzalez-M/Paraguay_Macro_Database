# Descubrimiento y diseño de onboarding IMF — 2026-09-19

## Alcance y veredicto

Esta fase fue exclusivamente diagnóstica. No se registró ninguna fuente IMF, no
se construyó candidato, no se modificó la base publicada, no se alteraron
contratos productivos y no se cambió ninguna interfaz `catalog`, `explore` o
`research`.

Los 25 archivos son analizables sin pérdida mediante un lector de dos etapas,
pero no son CSV ordinarios. La recomendación es conservarlos como el primer
vintage recibido y comenzar un piloto aislado con CPI, ER, EER, QNEA y CTOT,
publicado inicialmente sólo en preservación, catálogo y exploración.

## Estado de producción verificado antes del diagnóstico

- `database/paraguay_macro_pilot.duckdb` tiene SHA-256
  `9cf802028b8693506f5f6ad9ab321f2ace93f314fbeffe0a5ac831cdad087ca4` y
  497.823.744 bytes; coincide con su sidecar.
- El registro de promoción declara build
  `build:6928154663966c1f7d0ee63d`, attempt
  `attempt:1441a2cb2abc7fa63b773cd0`, bundle
  `release:a8120d5735c5ec0d32eddf42`, schema 46 y el mismo hash.
- La base activa confirma estado `accepted`, cero errores, 1.255.908 hechos y
  12.265 identidades.
- CDA: 421 identidades y 21.839 hechos. TCN: dos identidades y 3.502 hechos por
  lado, unidad `PYG_PER_USD`, moneda `PYG/USD`, escala 1 y 4.156 tokens `ND`
  crudos. LRM: 940 identidades y 10.334 hechos.
- CDA y TCN tienen cero filas en `research.series_catalog`; no existe ninguna
  fuente IMF en `raw.source_files`.
- Las verificaciones de candidato y de interfaces pasaron. Las 141 vistas
  públicas enlazan con una conexión nueva de sólo lectura y `search_path` vacío.

El handover del 18 de septiembre es evidencia histórica y fue reemplazado por
la promoción CDA–TCN del 19 de septiembre; no se usaron sus cifras antiguas como
estado actual.

## Inventario cuantitativo

El inventario exacto está en `file_inventory.csv`; `dataset_versions.csv`
conserva los identificadores `DATASET`, agencia, dataflow y versión. Totales:

| Métrica | Resultado |
|---|---:|
| Archivos | 25 |
| Bytes | 180.202.064 |
| Filas lógicas de datos | 35.266 |
| Códigos de serie distintos, sumados por archivo | 33.775 |
| Celdas de período no vacías | 5.778.535 |
| Filas con ancho irregular después de reconstrucción | 0 |
| Errores de parseo después de reconstrucción | 0 |
| Registros físicamente multilínea | 30 |

`IMTS` domina el volumen: 98.447.357 bytes, 12.811 series y 3.118.702
observaciones potenciales. La tabla FSI de metadatos contiene 1.988 filas pero
sólo 497 `SERIES_CODE`, repetidos por cuatro medidas de metadatos; no deben
contarse como observaciones estadísticas ordinarias.

## Diagnóstico de serialización

La estructura observada es:

1. bytes originales con CRLF;
2. una envoltura exterior delimitada por punto y coma;
3. un payload por registro que contiene CSV interior separado por comas;
4. comillas interiores duplicadas por la envoltura;
5. campos exteriores vacíos terminales variables;
6. punto y coma legítimo dentro de texto, que divide el payload exterior y debe
   recomponerse antes de leer el CSV interior.

Veinticuatro archivos son UTF-8 con BOM. `Production Indexes, World and Country
Group Aggregates.csv` es Windows-1252 sin BOM. Todos usan CRLF.

`CPI_WCA` contiene 30 registros partidos físicamente en dos líneas entre campos
de metadatos. El diagnóstico recompone el separador omitido y obtiene 30 filas
de ancho exacto. Leer por líneas, usar directamente `read.csv`, asumir UTF-8 en
todos los casos o eliminar columnas vacías antes de reconstruir el payload puede
perder texto, desplazar columnas o descartar filas silenciosamente.

No hay tokens no numéricos en celdas de período cuyo `OBS_MEASURE` sea
`OBS_VALUE`. La ausencia se representa como cadena vacía y debe conservarse como
ausencia, nunca como cero. Los ceros publicados sí son valores observados.

## Dataflows y cobertura

Cada archivo contiene un único dataflow/version declarado. Los 25 son:

`BOP(21.0.0)`, `CTOT(5.0.1)`, `CPI_WCA(3.0.0)`, `CPI(5.0.0)`,
`EER(6.0.0)`, `ER(4.0.1)`, `FSIBSIS(18.0.0)`, `FSIC(13.0.1)`,
`FSI_COUNTRY_METADATA_TABLE_2(2.0.0)`, `IIP(13.0.0)`, `IL(13.0.1)`,
`IRFCL(12.0.0)`, `ITG(4.0.0)`, `IMTS(1.0.0)`, `MFS_CBS(24.0.0)`,
`MFS_DC(8.0.0)`, `MFS_IR(9.0.0)`, `MFS_MA(10.0.1)`, `MFS_ODC(10.0.0)`,
`QNEA(7.0.0)`, `PCPS(9.0.0)`, `PI_WCA(1.0.0)`, `QGDP_WCA(4.0.0)`,
`RSUI(1.0.0)` y `WPFXI(1.0.2)`.

Las colecciones nacionales cubren principalmente Argentina, Bolivia, Brasil,
Chile, Colombia, Ecuador, Paraguay, Perú y Uruguay. EER carece de Argentina,
Ecuador y Perú; MFS_MA carece de Ecuador; RSUI carece de Uruguay. PCPS es
mundial. CPI_WCA, PI_WCA y QGDP_WCA contienen regiones o agregados mundiales, no
países. IMTS agrega 219 contrapartes, incluidas regiones y categorías no
especificadas.

La cobertura exacta por país, frecuencia, dataset, primer período con valor,
último período con valor, número de series y celdas no vacías está en
`country_frequency_coverage.csv`. Los encabezados abarcan 1900–2026 en CPI,
pero esos extremos no implican que cada serie tenga datos allí; el archivo de
cobertura usa sólo celdas no vacías.

## Clasificación económica y tratamiento

`economic_classification.csv` asigna cada archivo a una categoría y módulo.

- Estadísticas oficiales o compiladas: BOP, CPI, ER, EER, FSIBSIS, FSIC, IIP,
  IL, IRFCL, ITG, IMTS, MFS y QNEA. Que el FMI las publique no elimina la
  necesidad de conservar país reportante, sector, contraparte, valoración,
  unidad y metodología.
- Metadatos: `FSI_COUNTRY_METADATA_TABLE_2` contiene definiciones, base de
  consolidación, ajustes intragrupo y estándares contables. Debe ir a una tabla
  de metadatos por serie/medida/período, no al fact de valores.
- Agregados/estimaciones del staff: CPI_WCA, PI_WCA y QGDP_WCA. Sus campos
  embebidos indican `IMF Staff Estimates`; deben quedar fuera del panel de
  países y llevar tipo de entidad geográfica `aggregate`.
- Indicadores derivados: CTOT y varias transformaciones ya calculadas dentro de
  CPI, MFS, PCPS y los agregados. Se conservan como series publicadas distintas;
  no se recalculan ni se confunden con niveles.
- Globales: PCPS y agregados mundiales/regionales van a módulos separados de
  factores globales.
- Experimentales/investigación: RSUI y WPFXI. WPFXI mezcla datos públicos y
  proxies; RSUI es un índice de investigación. Ambos deben conservarse con
  `statistical_status` explícito y nunca presentarse como estadística oficial.

## Modelo recomendado

### Preservación y catálogo

- `raw.imf_files`: un registro por bytes recibidos, con SHA-256, tamaño,
  encoding, envelope, nombre recibido, tiempo de ingestión y evidencia de
  adquisición separada.
- `raw.imf_records`: payload interior exacto, número lógico, líneas físicas y
  resultado de parseo. Para fuentes delimitadas, esta es la evidencia equivalente
  a coordenadas de celda.
- `staging.imf_wide_rows`: fila reconstruida sin derretir, con nombres y valores
  crudos.
- `canonical.imf_datasets`, `imf_series`, `imf_dimensions`,
  `imf_series_dimensions`, `imf_coverage` e `imf_observations`.

### Grano e identidad

Grano recomendado de observación:

`vintage_id × dataset_id × series_code × obs_measure × published_period`.

Para IMTS y cualquier dataflow donde `SERIES_CODE` no codifique de forma
completa todas las dimensiones, se añade la clave SDMX explícita y sus pares
dimensión/código. Antes del piloto debe verificarse con la estructura SDMX del
dataflow si `SERIES_CODE` es único y completo; no debe asumirse desde la etiqueta.

La identidad económica de fuente debe incluir `DATASET` completo (agencia,
dataflow y versión), `SERIES_CODE`, `OBS_MEASURE` y cualquier dimensión SDMX que
no esté determinada funcionalmente por esos campos. No incluye nombre de
archivo, posición de fila, año, período, valor, vintage ni etiquetas traducidas.
La versión se conserva como atributo e identidad de dataset recibido; una
decisión humana futura debe gobernar continuidad entre versiones.

`published_period` permanece textual. `period_start` y `period_end` se derivan
por frecuencia, sin sustituir el texto publicado. Debe distinguirse mensual de
trimestral incluso cuando ambos aparecen en un mismo archivo.

### Semántica y missingness

Las dimensiones deben conservar código y etiqueta por separado: país,
contraparte, sector, indicador, entrada contable, unidad, escala, moneda,
frecuencia, transformación, ajuste estacional, precio, índice y otras
dimensiones específicas. No conviene una tabla ancha común con columnas nulas;
un catálogo largo de dimensiones conserva dataflows futuros sin perder campos.

Estados mínimos de valor: `observed_numeric`, `source_missing_blank`,
`source_non_numeric_token`, `metadata_text` y `parse_rejected`. El piloto no
debe generar filas numéricas para blancos, ni derivar ceros. El FSI metadata
requiere un carrier textual separado.

Toda fila recibida debe reconciliar como exactamente una de: aceptada como
serie/observación, aceptada como metadato, vacío estructural contabilizado,
exclusión documentada o rechazo con motivo gobernado. Deben cuadrar filas
físicas, filas lógicas, campos, celdas de período no vacías y observaciones.

## Solapamientos y comparabilidad

Los principales solapamientos potenciales con BCP son CPI, ER/TCN, EER,
cuentas nacionales, BOP/IIP/reservas, MFS, tasas, FSI y comercio. También existen
solapamientos internos IMF: ER frente a MFS_IR; BOP frente a IIP/IRFCL/IL;
ITG frente a IMTS; CPI frente a CPI_WCA; QNEA frente a QGDP_WCA; MFS_CBS,
MFS_DC, MFS_ODC y MFS_MA entre sí.

No se propone deduplicación. Debe crearse posteriormente una concordancia
revisada que distinga `same_publisher_republication`, `methodologically_related`,
`benchmark`, `component`, `aggregate` y, sólo con evidencia, `equivalent`.
Comparar valores o etiquetas no basta. Son riesgos específicos: fecha de corte y
vintage distintos, moneda doméstica versus USD, escala, promedio versus fin de
período, FOB versus CIF, stock versus flujo, precios corrientes/constantes,
ajuste estacional, índice/base y transformaciones publicadas.

## Procedencia, licencia y atribución

Los bytes, hashes, dataflows y versiones están establecidos. No existe en este
paquete evidencia del URL exacto de descarga, fecha/hora verificable de
adquisición, consulta/filtros usados, identidad del usuario exportador ni fecha
de publicación de cada archivo; deben quedar `unknown` hasta aportar evidencia.

Los términos vigentes del FMI permiten descargar, copiar, transformar,
publicar y distribuir datos estadísticos publicados con atribución exacta,
integridad y declaración de transformaciones; advierten sobre contenido de
terceros, ausencia de garantía y reutilización comercial. La atribución mínima
debe incluir FMI, nombre de base y enlace al dataset. No debe generalizarse esa
licencia a texto, metodología, material de terceros o productos de investigación
sin revisar sus términos específicos. Referencias verificadas:

- https://www.imf.org/en/about/copyright-and-terms
- https://data.imf.org/en/Resource-Pages/IMF-API

Antes de redistribuir, el piloto debe guardar un snapshot fechado de los términos
aplicables y revisar individualmente WPFXI, RSUI y campos que atribuyan terceros.

## API SDMX futura

La API oficial ofrece SDMX 2.1 y 3.0. Es la ruta recomendada para actualizaciones
futuras porque permite conservar claves y estructuras explícitas, pero no debe
reemplazar este primer vintage. La adquisición deberá archivar respuesta cruda,
URL/consulta, headers, timestamp, estructura/dataflow, versión, filtros, hash y
estado HTTP; además debe comparar cobertura con el vintage anterior y fallar
cerrado ante cambios de estructura o versión.

## Piloto y fases

1. **Contrato de envelope y preservación (complejidad media):** lector de dos
   etapas, encoding, coordenadas lógicas/físicas, contabilidad completa y cinco
   archivos piloto. Sin registro global todavía.
2. **CPI + ER + EER (media):** catálogo y exploración, manteniendo frecuencia,
   transformación, unidad y promedio/EOP separados.
3. **QNEA + CTOT (media-alta):** precios, ajuste estacional, moneda, índices y
   carácter derivado explícitos.
4. **Aceptación del piloto (media):** candidato aislado, invariancia total de la
   producción no IMF, cero `research.*`, pruebas desde conexión nueva y revisión
   humana de advertencias.
5. **BOP/IIP/IL/IRFCL y MFS/FSI (alta):** jerarquías, sectores, posiciones/flujos,
   metadatos textuales y solapamientos.
6. **IMTS bilateral (muy alta):** 219 contrapartes y más de 3,1 millones de
   valores; módulo y grain propios.
7. **Globales y experimentales (media):** PCPS/agregados separados; RSUI/WPFXI
   con etiqueta experimental/proxy.
8. **Panel regional certificado y automatización SDMX (alta):** sólo después de
   revisiones económicas y de procedencia; selección pequeña para `research.*`.

## Decisiones humanas requeridas antes de implementar

1. ¿Se autoriza tratar estos 25 archivos como el primer vintage recibido aunque
   el URL, timestamp y filtros de adquisición permanezcan desconocidos, con una
   advertencia explícita de procedencia?
2. ¿El piloto debe registrar cinco `source_id` independientes o un source padre
   IMF con subdatasets? Se recomienda un `source_id` por dataflow y una familia
   de adquisición compartida.
3. ¿Se aprueba excluir por diseño CPI_WCA, PI_WCA, QGDP_WCA, RSUI y WPFXI del
   panel de países y mantenerlos en módulos separados?
4. ¿Se desea almacenar todos los blancos estructurales como registros explícitos
   o sólo su contabilidad por fila/serie? Se recomienda contabilidad agregada y
   hechos explícitos sólo para tokens no vacíos.
5. ¿Qué evidencia de adquisición puede aportarse para estos archivos: URL,
   fecha/hora, usuario, filtros o export job?
6. ¿La futura distribución será sólo interna/no comercial o pública/comercial?
   La respuesta determina el nivel de revisión jurídica y de terceros.
7. ¿Se autoriza consultar estructuras y datos futuros por API SDMX durante la
   fase piloto, conservando estos archivos como vintage cero?

## Criterio de detención

El trabajo se detiene aquí. No se implementó el parser productivo, no se añadió
ninguna fila a `config/source_registry.csv`, no se construyó candidato y no se
promovió nada.
