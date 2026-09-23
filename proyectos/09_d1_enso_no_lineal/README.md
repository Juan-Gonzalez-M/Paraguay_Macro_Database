# 09 · D1 — ENSO no lineal y respuestas macroeconómicas

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 18:58:16 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

## 1. Resumen y pregunta de investigación

El Niño y La Niña pueden tener efectos de distinto signo, intensidad y rezago sobre una economía agroexportadora e hidroeléctrica como la paraguaya. El aporte es un **perfil de respuesta dependiente del estado** (fase e intensidad), no un supuesto shock mensual inesperado.

- **Pregunta:** ¿cómo se asocian la actividad, los sectores y la inflación con la intensidad y la fase ENSO?
- **Estimando:** perfil dinámico (0–24 meses) de cada resultado condicional a la intensidad del ONI, por separado para fase cálida (El Niño) y fría (La Niña).
- **Evidencia:** forma reducida. El mecanismo (clima → agricultura, río, energía, precios, expectativas) se describe, pero no se identifica canal por canal.

## 2. Estrategia empírica propuesta

1. **Proyecciones locales mensuales con base spline por fase** (1994–2026 para IMAEP e IPC; 1995–2026 trimestral para el PIB sectorial):
   `y_{t+h} − y_{t−1} = Σ_k β_{h,k}^{+} B_k(ONI_t⁺) + Σ_k β_{h,k}^{−} B_k(ONI_t⁻) + controles_t + ε`, h = 0…24, con `ONI⁺ = max(ONI,0)`, `ONI⁻ = min(ONI,0)` y B-splines con **nudos fijados ex ante** (p. ej. ±0,5 y ±1,5 °C). Controles parsimoniosos: rezagos de y, precio mundial de alimentos, soja, petróleo, tipo de cambio.
2. **Bandas simultáneas** (sup-t o Bonferroni por horizonte) y **tests conjuntos** de igualdad entre fases.
3. **Familias de resultados:** IMAEP total y sin agricultura ni binacionales; primario, secundario, servicios; PIB real agrícola, ganadero y de electricidad y agua; IPC total, alimentos, frutas y verduras, carnes, subyacente; volúmenes exportados de soja, maíz, trigo, carne y energía. Corregir por multiplicidad dentro de cada familia.
4. **Robustez:** RONI y anomalía mensual Niño 3.4 en lugar del ONI; *leave-one-event-out* (excluir 1997-98, 2015-16, 2023-24 El Niño y 2020-23 La Niña de a uno); muestra desde 2014 con el IMAEP ajustado.

Advertencia de la ficha: pocos episodios independientes (≈ 5–6 El Niño y 6–7 La Niña fuertes o moderados desde 1994). Si el perfil cambia al quitar un evento, hay que reducir la ambición del resultado.

## 3. Series extraídas

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `imaep_original` | IMAEP serie original (Cuadro 9; 1994-) | `economic_annex` CUADRO 9 | mensual | 1994-01-01 | 2026-06-01 | 390 | INDEX | Preliminar | Resultado principal (actividad total) |
| `imaep_sin_agro_bin_original` | IMAEP sin agricultura ni binacionales serie original (Cuadro 9; 1994-) | `economic_annex` CUADRO 9 | mensual | 1994-01-01 | 2026-06-01 | 390 | INDEX | Preliminar | Resultado: actividad no climática directa |
| `imaep9a_original` | IMAEP serie original (Cuadro 9 a; 2014-) | `economic_annex` CUADRO 9 a | mensual | 2014-01-01 | 2026-06-01 | 150 | INDEX | Validada por regla | Resultado (robustez) |
| `imaep9a_desest` | IMAEP serie ajustada (Cuadro 9 a) | `economic_annex` CUADRO 9 a | mensual | 2014-01-01 | 2026-06-01 | 150 | INDEX | Validada por regla | Resultado (robustez) |
| `imaep9a_primario` | IMAEP sector primario serie original | `economic_annex` CUADRO 9 a | mensual | 2014-01-01 | 2026-06-01 | 150 | INDEX | Validada por regla | Resultado sectorial |
| `imaep9a_primario_desest` | IMAEP sector primario serie ajustada | `economic_annex` CUADRO 9 a | mensual | 2014-01-01 | 2026-06-01 | 150 | INDEX | Preliminar | Resultado sectorial |
| `imaep9a_secundario` | IMAEP sector secundario serie original | `economic_annex` CUADRO 9 a | mensual | 2014-01-01 | 2026-06-01 | 150 | INDEX | Validada por regla | Resultado sectorial |
| `imaep9a_manufactura` | IMAEP manufactura serie original | `economic_annex` CUADRO 9 a | mensual | 2014-01-01 | 2026-06-01 | 150 | INDEX | Validada por regla | Resultado sectorial |
| `imaep9a_servicios` | IMAEP servicios serie original | `economic_annex` CUADRO 9 a | mensual | 2014-01-01 | 2026-06-01 | 150 | INDEX | Validada por regla | Resultado sectorial |
| `imaep9a_sin_agro_bin` | IMAEP sin agricultura ni binacionales serie original (9 a) | `economic_annex` CUADRO 9 a | mensual | 2014-01-01 | 2026-06-01 | 150 | INDEX | Validada por regla | Resultado sectorial |
| `pib_real` | PIB trimestral a precios de comprador (millones de Gs. constantes de 2014) | `economic_annex` CUADRO 6 | trimestral | 1994-01-01 | 2026-01-01 | 129 | PYG (millones) | Validada por regla | Resultado trimestral |
| `pib_real_agricultura` | PIB trimestral real: agricultura | `economic_annex` CUADRO 6 | trimestral | 1994-01-01 | 2026-01-01 | 129 | PYG (millones) | Preliminar | Resultado sectorial trimestral |
| `pib_real_ganaderia` | PIB trimestral real: ganadería forestal pesca y minería | `economic_annex` CUADRO 6 | trimestral | 1994-01-01 | 2026-01-01 | 129 | PYG (millones) | Preliminar | Resultado sectorial trimestral |
| `pib_real_manufactura` | PIB trimestral real: manufactura | `economic_annex` CUADRO 6 | trimestral | 1994-01-01 | 2026-01-01 | 129 | PYG (millones) | Preliminar | Resultado sectorial trimestral |
| `pib_real_electricidad_agua` | PIB trimestral real: electricidad y agua (binacionales) | `economic_annex` CUADRO 6 | trimestral | 1994-01-01 | 2026-01-01 | 129 | PYG (millones) | Preliminar | Resultado sectorial (canal hídrico) |
| `pib_real_construccion` | PIB trimestral real: construcción | `economic_annex` CUADRO 6 | trimestral | 1994-01-01 | 2026-01-01 | 129 | PYG (millones) | Preliminar | Resultado sectorial trimestral |
| `pib_real_servicios` | PIB trimestral real: servicios | `economic_annex` CUADRO 6 | trimestral | 1994-01-01 | 2026-01-01 | 129 | PYG (millones) | Preliminar | Resultado sectorial trimestral |
| `ipc_indice` | IPC índice general (base dic-2017=100) | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Resultado: inflación |
| `ipc_var_mensual` | Inflación total mensual | `economic_annex` CUADRO 15 | mensual | 1993-01-01 | 2026-07-01 | 403 | PERCENT | Validada por regla | Resultado: inflación |
| `ipc_var_interanual` | Inflación total interanual | `economic_annex` CUADRO 15 | mensual | 1993-12-01 | 2026-07-01 | 392 | PERCENT | Validada por regla | Resultado: inflación |
| `ipc_subyacente_mensual` | Inflación subyacente mensual | `economic_annex` CUADRO 15 | mensual | 1993-01-01 | 2026-07-01 | 403 | PERCENT | Validada por regla | Resultado: inflación subyacente |
| `ipc_frutas_verduras_indice` | IPC frutas y verduras índice | `economic_annex` CUADRO 15 | mensual | 1992-12-01 | 2026-07-01 | 404 | INDEX | Preliminar | Resultado: alimentos frescos |
| `ipc_alimentos_indice` | IPC alimentación y bebidas no alcohólicas índice (Cuadro 14) | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Resultado: alimentos |
| `ipc_bienes_alimenticios` | IPC bienes alimenticios índice (Cuadro 14 b) | `economic_annex` CUADRO 14 b | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Resultado: alimentos |
| `ipc_carnes` | IPC alimentación: carnes | `economic_annex` CUADRO 16 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Resultado: ganadería |
| `ipc_vegetales_frescos` | IPC alimentación: vegetales frescos | `economic_annex` CUADRO 16 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Resultado: alimentos frescos |
| `ipc_frutas_frescas` | IPC alimentación: frutas frescas | `economic_annex` CUADRO 16 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Resultado: alimentos frescos |
| `ipc_cereales` | IPC alimentación: cereales y derivados | `economic_annex` CUADRO 16 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Resultado: alimentos |
| `ipc_lacteos` | IPC alimentación: productos lácteos | `economic_annex` CUADRO 16 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Resultado: alimentos |
| `expo_ton_soja` | Exportaciones de granos de soja (toneladas) | `economic_annex` Cuadro 44b | mensual | 1994-01-01 | 2026-07-01 | 391 | TONNES | Preliminar | Mecanismo: cosecha |
| `expo_ton_maiz` | Exportaciones de maíz (toneladas) | `economic_annex` Cuadro 44b | mensual | 1994-01-01 | 2026-07-01 | 391 | TONNES | Preliminar | Mecanismo: cosecha |
| `expo_ton_trigo` | Exportaciones de trigo (toneladas) | `economic_annex` Cuadro 44b | mensual | 1994-01-01 | 2026-07-01 | 391 | TONNES | Preliminar | Mecanismo: cosecha |
| `expo_ton_arroz` | Exportaciones de arroz (toneladas) | `economic_annex` Cuadro 44b | mensual | 1994-01-01 | 2026-07-01 | 391 | TONNES | Preliminar | Mecanismo: cosecha |
| `expo_ton_carne` | Exportaciones de carne (toneladas) | `economic_annex` Cuadro 44b | mensual | 1994-01-01 | 2026-07-01 | 391 | TONNES | Preliminar | Mecanismo: ganadería |
| `expo_kwh_energia` | Exportaciones de energía eléctrica (miles de kWh) | `economic_annex` Cuadro 44b | mensual | 1994-01-01 | 2026-07-01 | 391 | KWH | Preliminar | Mecanismo: hidrología |
| `soja_chicago` | Soja Chicago USD/t | `economic_annex` Cuadro 49 | mensual | 1994-01-01 | 2026-08-01 | 392 | USD_PER_TONNE | Preliminar | Control global (precio) |
| `maiz_chicago` | Maíz Chicago USD/t | `economic_annex` Cuadro 49 | mensual | 1994-01-01 | 2026-07-01 | 391 | USD_PER_TONNE | Preliminar | Control global (precio) |
| `trigo_chicago` | Trigo Chicago USD/t | `economic_annex` Cuadro 49 | mensual | 1994-01-01 | 2026-07-01 | 391 | USD_PER_TONNE | Preliminar | Control global (precio) |
| `petroleo_brent` | Petróleo Brent USD/barril | `economic_annex` Cuadro 49 | mensual | 1994-01-01 | 2026-07-01 | 391 | USD_PER_BARREL | Preliminar | Control global (costos) |
| `pyg_usd_prom_venta` | PYG por USD promedio mensual (venta) | `exchange_rates` USD Prom | mensual | 1989-01-01 | 2026-07-01 | 451 | PYG_PER_USD | Validada por regla | Control / mecanismo cambiario |
| `tpm` | Tasa de política monetaria | `economic_annex` CUADRO 19  | mensual | 2011-05-01 | 2026-07-01 | 183 | PERCENT | Preliminar | Control (reacción de política) |
| `eve_inflacion_anio_t` | EVE (mediana): inflación esperada año t | `eve` NA | mensual | 2006-04-01 | 2026-08-01 | 245 | PROPORTION | Preliminar | Mecanismo: expectativas |
| `oni` | NOAA CPC: Oceanic Niño Index (anomalía Niño 3.4; media móvil 3 meses fechada en el mes central) | `NOAA CPC` oni.ascii.txt | mensual | 1950-01-01 | 2026-07-01 | 919 | GRADOS_C | Externa (NOAA), no verificada en la base | Tratamiento: fase e intensidad ENSO |
| `nino34_sst_3m` | NOAA CPC: temperatura absoluta Niño 3.4 media móvil 3 meses | `NOAA CPC` oni.ascii.txt | mensual | 1950-01-01 | 2026-07-01 | 919 | GRADOS_C | Externa (NOAA), no verificada en la base | Índice alternativo |
| `roni` | NOAA CPC: ONI relativo (descuenta el calentamiento tropical medio) | `NOAA CPC` RONI.ascii.txt | mensual | 1950-01-01 | 2026-07-01 | 919 | GRADOS_C | Externa (NOAA), no verificada en la base | Índice alternativo (robustez) |
| `nino34_anom_mensual` | NOAA CPC: anomalía mensual Niño 3.4 (sstoi.indices; 1982-) | `NOAA CPC` sstoi.indices | mensual | 1982-01-01 | 2026-08-01 | 536 | GRADOS_C | Externa (NOAA), no verificada en la base | Índice alternativo (mensual sin suavizar) |
| `alimentos_indice_mundial` | FRED/FMI: índice mundial de precios de alimentos | `FRED` PFOODINDEXM | mensual | 1992-01-01 | 2026-07-01 | 415 | INDEX | Externa (FRED), no verificada en la base | Control global parsimonioso |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_mensual.csv` | 15.119 | 11 | 1950-01-01 | 2026-08-01 |
| `datos/series_mensual_ancho.csv` | 920 | 41 | 1950-01-01 | 2026-08-01 |
| `datos/series_trimestral.csv` | 903 | 11 | 1994-01-01 | 2026-01-01 |
| `datos/series_trimestral_ancho.csv` | 129 | 8 | 1994-01-01 | 2026-01-01 |
| `datos/diccionario_series.csv` | 47 | 13 | 1950-01-01 | 2014-01-01 |

## 4. Cómo se usarían los datos

- **ENSO:** `oni` es una media móvil de 3 meses fechada en el **mes central** (DJF → enero). Para evitar usar información futura en un modelo mensual, rezagar un mes (el ONI de enero incluye febrero). Definir fases con el umbral estándar ±0,5 °C durante 5 temporadas consecutivas solo para la descripción; en la regresión usar el índice continuo.
- **Actividad:** `log(imaep_original)`; como la serie original tiene estacionalidad fuerte, trabajar con diferencias de 12 meses o incluir dummies de mes. El PIB trimestral real (`pib_real_*`, guaraníes constantes de 2014) en `log` y variación interanual.
- **Precios:** variaciones mensuales o interanuales de los índices; el IPC no está desestacionalizado (frutas y verduras tienen estacionalidad fuerte); nunca controlar por alimentos al estimar el efecto sobre la subyacente (post-tratamiento, según la ficha).
- **Volúmenes exportados:** `log(1 + toneladas)`, sumas por campaña agrícola (soja: enero–junio) como robustez.
- **Deflactación:** precios mundiales en USD en `log`; no hace falta deflactar para LP con diferencias.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Precipitación y temperatura nacionales o por departamento | Nivel "ideal": mecanismo físico | DMH-DINAC; CHIRPS (UCSB); ERA5-Land (Copernicus) |
| Producción física de cultivos (soja, maíz, trigo) por campaña | Separar cosecha de exportación | MAG – Síntesis estadística; CAPECO; USDA PSD |
| Nivel del río Paraguay (Asunción, Pilar) | Canal logístico e hidroeléctrico | DMH / ANNP; Prefectura General Naval |
| Índices ENSO alternativos (SOI, MEI.v2) | La ficha pide "varios índices" | NOAA PSL (SOI, MEI.v2) — fácil de agregar al script |
| Cambios de base de cuentas y del IPC documentados | Metadatos exigidos | BCP – notas metodológicas del IPC (base 2017) y de CN (base 2014) |

## 6. Evaluación de viabilidad

**Alta** (antes Media). Con el ONI incorporado desde NOAA, el mínimo de la ficha —IMAEP, IPC y ONI consistentes— está completo desde 1994, con sectores, alimentos y controles globales. El límite no es la disponibilidad sino el número de episodios ENSO independientes.

## 7. Supuestos que debes revisar

1. **IMAEP largo:** el Cuadro 9 (1994–) y el Cuadro 9 a (2014–) coinciden exactamente entre 2014-01 y 2026-06. Lo interpreto como la misma serie base 2014 **retropolada** hasta 1994 por el BCP; los datos 1994–2013 son una reconstrucción y deberían tratarse con cautela.
2. El IMAEP sectorial (primario, secundario, servicios) solo existe desde 2014; para 1994–2013 los sectores salen del PIB trimestral (Cuadro 6).
3. Uso el Cuadro 6 (guaraníes **constantes** de 2014) para el PIB sectorial; el Cuadro 6 a es a precios corrientes y no se incluyó.
4. ONI fechado en el mes central de la temporada de 3 meses (convención de NOAA). Los índices ENSO se descargan en cada corrida; NOAA revisa retroactivamente los últimos valores cuando actualiza la climatología.
5. Los volúmenes exportados son un **proxy** de cosecha: incluyen stocks y timing logístico (que a su vez depende del río).
6. EVE = mediana de la encuesta.
