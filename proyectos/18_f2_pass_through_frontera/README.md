# 18 · F2 — Precios de importación, arbitraje fronterizo e inflación

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 20:02:52 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

## 1. Resumen y pregunta de investigación

El dólar amplio, el PYG/USD, el real y el peso pueden trasladarse a los precios por la moneda de facturación, por el comercio regional y por el arbitraje fronterizo (régimen de turismo, compras en la frontera). Un pass-through agregado no identifica cuál canal domina.

- **Pregunta:** ¿cómo se transmite el tipo de cambio desde el precio de importación al IPC, y cuándo se concentra en bienes y zonas fronterizas?
- **Estimandos:** (i) pass-through por tipo de bien, origen y etapa (importación → productor → consumidor); (ii) diferencial frontera–interior ante cambios en la brecha relativa con Brasil y Argentina (no factible sin precios regionales; ver brechas).
- **Evidencia:** forma reducida; el arbitraje requiere concentración geográfica y de producto.

## 2. Estrategia empírica propuesta

1. **Valores unitarios** por tipo de bien y nivel de procesamiento: `VU = miles de USD / toneladas` (Cuadros 51a/51b y 53a/53b emparejados por concepto), mensual 1994–2026; limpieza de outliers (unit values mezclan precio y calidad).
2. **Pass-through por etapa:** proyecciones locales del IPC de importados (`ipc_importados_sin_fyv`), del IPP de importados y del IPC por división sobre `Δlog` del PYG/USD, del dólar amplio y de los bilaterales BRL/ARS, horizonte 0–12 meses; comparación con el IPC de nacionales y de no transables (placebo).
3. **Moneda dominante vs. bilateral:** con los pesos de origen de las importaciones (IMTS por socio y Cuadro 50), construir un tipo de cambio ponderado por comercio y compararlo con el dólar.
4. **Canal fronterizo (proxy agregado):** importaciones bajo régimen de turismo (Cuadros 52a/52b, reexportación a Brasil/Argentina) frente al gap de precios relativos (`tcr_brasil`, `tcr_argentina`, `pyg_ars`); si no hay concentración, renombrar como "pass-through regional" (lo pide la ficha).

## 3. Series extraídas

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `ipc_indice` | IPC índice general (base dic-2017=100) | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Resultado: IPC |
| `ipc_importados_sin_fyv` | IPC productos importados sin frutas y verduras | `economic_annex` CUADRO 14 a | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Resultado principal: precio al consumidor de importados |
| `ipc_nacionales` | IPC productos nacionales | `economic_annex` CUADRO 14 a | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Comparación (no importados) |
| `ipc_transables_sin_fyv` | IPC transables sin frutas y verduras | `economic_annex` CUADRO 14 a | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Tradables |
| `ipc_no_transables` | IPC no transables | `economic_annex` CUADRO 14 a | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Placebo (no transables) |
| `ipc_div_alimentos` | IPC alimentación y bebidas no alcohólicas | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Canasta con comercio fronterizo |
| `ipc_div_vestido` | IPC prendas de vestir y calzado | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Canasta con comercio fronterizo |
| `ipc_div_muebles_hogar` | IPC muebles y artículos para el hogar | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Durables importados |
| `ipc_div_transporte` | IPC transporte (combustibles y vehículos) | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Energía importada |
| `ipp_importados` | Índice de precios al productor: productos importados | `economic_annex` CUADRO 17  | mensual | 1995-12-01 | 2026-06-01 | 367 | INDEX | Preliminar | Etapa previa al consumidor |
| `pyg_usd_prom_venta` | PYG por USD promedio mensual | `exchange_rates` USD Prom | mensual | 1989-01-01 | 2026-07-01 | 451 | PYG_PER_USD | Validada por regla | Tipo de cambio dólar (moneda de factura dominante) |
| `pyg_brl` | PYG por BRL | `economic_annex` CUADRO 60a | mensual | 1997-01-01 | 2026-07-01 | 355 | PYG_PER_BRL | Preliminar | Tipo de cambio bilateral Brasil |
| `pyg_ars` | PYG por ARS | `economic_annex` CUADRO 60a | mensual | 1997-01-01 | 2026-07-01 | 355 | PYG_PER_ARS | Preliminar | Tipo de cambio bilateral Argentina (gap fronterizo) |
| `tcr_brasil` | Tipo de cambio real bilateral Brasil | `economic_annex` CUADRO 60c | mensual | 1995-01-01 | 2026-06-01 | 378 | INDEX | Validada por regla | Gap de precios relativos con Brasil |
| `tcr_argentina` | Tipo de cambio real bilateral Argentina | `economic_annex` CUADRO 60c | mensual | 1995-01-01 | 2026-06-01 | 378 | INDEX | Validada por regla | Gap de precios relativos con Argentina |
| `tcr_multilateral` | Tipo de cambio real multilateral | `economic_annex` CUADRO 60b | mensual | 1995-01-01 | 2026-06-01 | 378 | INDEX | Validada por regla | Control |
| `ipc_brasil` | FMI: IPC Brasil índice | `imf_cpi` NA | mensual | 1979-12-01 | 2026-07-01 | 560 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Precios del vecino |
| `ipc_argentina` | FMI: IPC Argentina índice (desde dic-2016) | `imf_cpi` NA | mensual | 2016-12-01 | 2026-06-01 | 115 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Precios del vecino |
| `petroleo_brent` | Petróleo Brent USD/barril | `economic_annex` Cuadro 49 | mensual | 1994-01-01 | 2026-07-01 | 391 | USD_PER_BARREL | Preliminar | Costo de importación de combustibles |
| `dolar_amplio_m` | FRED: índice nominal amplio del dólar | `FRED` TWEXBGSMTH | mensual | 2006-01-01 | 2026-08-01 | 248 | INDEX | Externa (FRED), no verificada en la base | Canal de moneda dominante |
| `ipc_eeuu` | FRED: IPC de EE.UU. | `FRED` CPIAUCSL | mensual | 1947-01-01 | 2026-08-01 | 955 | INDEX | Externa (FRED), no verificada en la base | Precios en la moneda de factura |
| `impo_origen_cuadro_50_*` | 13 series: economic_annex hoja Cuadro 50 (detalle en diccionario_series.csv) | `economic_annex` Cuadro 50 | mensual | 1994-01-01 | 2026-07-01 | 5.083 | USD/EUR (miles) | Preliminar (13) | Importaciones por origen (miles USD) |
| `impo_tipo_usd_*` | 64 series: economic_annex hoja Cuadro 51a (detalle en diccionario_series.csv) | `economic_annex` Cuadro 51a | mensual | 1994-01-01 | 2026-07-01 | 25.024 | USD (miles) | No comprobada (3); Preliminar (61) | Importaciones por tipo de bien (miles USD FOB) |
| `impo_tipo_ton_*` | 64 series: economic_annex hoja Cuadro 51b (detalle en diccionario_series.csv) | `economic_annex` Cuadro 51b | mensual | 1994-01-01 | 2026-07-01 | 25.024 | TONNES | No comprobada (3); Preliminar (61) | Importaciones por tipo de bien (toneladas) |
| `impo_turismo_usd_*` | 192 series: economic_annex hoja Cuadro 52a (detalle en diccionario_series.csv) | `economic_annex` Cuadro 52a | mensual | 2006-01-01 | 2026-07-01 | 47.424 | USD (miles) | No comprobada (9); Preliminar (183) | Importaciones uso interno y régimen de turismo (miles USD) — reexportación/frontera |
| `impo_turismo_ton_*` | 192 series: economic_annex hoja Cuadro 52b (detalle en diccionario_series.csv) | `economic_annex` Cuadro 52b | mensual | 2006-01-01 | 2026-07-01 | 47.424 | TONNES | No comprobada (9); Preliminar (183) | Importaciones uso interno y régimen de turismo (toneladas) |
| `impo_proc_usd_*` | 149 series: economic_annex hoja Cuadro 53a (detalle en diccionario_series.csv) | `economic_annex` Cuadro 53a | mensual | 1994-01-01 | 2026-07-01 | 58.259 | USD (miles) | Preliminar (149) | Importaciones por nivel de procesamiento (miles USD FOB) |
| `impo_proc_ton_*` | 149 series: economic_annex hoja Cuadro 53b (detalle en diccionario_series.csv) | `economic_annex` Cuadro 53b | mensual | 1994-01-01 | 2026-07-01 | 58.259 | TONNES | Preliminar (149) | Importaciones por nivel de procesamiento (toneladas) |
| `impo_regimen_cuadro_54_*` | 10 series: economic_annex hoja Cuadro 54 (detalle en diccionario_series.csv) | `economic_annex` Cuadro 54 | mensual | 2003-01-01 | 2026-07-01 | 2.830 | USD (miles) | Preliminar (10) | Importaciones por régimen aduanero (miles USD) |

### Comercio por país socio (fuera de la base)

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `comercio_por_socio_imts_mensual.csv` | FMI IMTS: exportaciones FOB, importaciones CIF e importaciones FOB de Paraguay por país socio (≈ 220 socios y agregados), mensual, en millones de USD. Leído directamente de `input/current/IMF_Data/…(IMTS).csv`, que **no tiene parser en la base** | 1960-01-01 a 2026-05-01, 137.603 filas | Fuera de la base, sin validar |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_mensual.csv` | 277.674 | 11 | 1947-01-01 | 2026-08-01 |
| `datos/series_mensual_ancho.csv` | 956 | 855 | 1947-01-01 | 2026-08-01 |
| `datos/diccionario_series.csv` | 854 | 13 | 1947-01-01 | 2016-12-01 |
| `datos/comercio_por_socio_imts_mensual.csv` | 137.603 | 6 | 1960-01-01 | 2026-05-01 |

## 4. Cómo se usarían los datos

- **Emparejar a/b:** cada serie `impo_tipo_usd_*` tiene su par `impo_tipo_ton_*` con la misma etiqueta (idem `impo_proc_*` e `impo_turismo_*`); el valor unitario es el cociente del par (USD por tonelada ×1000, porque el valor está en miles de USD).
- **Transformaciones:** `Δlog` de valores unitarios, precios e índices; valores unitarios suavizados (media móvil de 3 meses) por su ruido; deflactar por el IPC de EE.UU. si se usan en nivel real.
- **Estacionalidad:** importaciones en valor y volumen son estacionales (maquinaria agrícola, combustibles); usar variaciones interanuales o X-13.
- **IMTS:** los socios incluyen agregados (World, regiones); filtrar países. Las importaciones CIF y FOB difieren por fletes y seguros: la diferencia es un proxy del costo de flete (útil también para F3).
- **Unidades:** el Anexo publica en **miles de USD**; IMTS en **millones de USD**.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Transacciones aduaneras (producto HS, importador, origen, moneda de factura) | Nivel "suficiente/ideal": pass-through por producto-origen y moneda dominante | DNA (Dirección Nacional de Aduanas); Comtrade (HS mensual por socio) |
| IPC regional o por ciudad (frontera vs. interior) | Estimando del arbitraje fronterizo | INE / BCP (IPC nacional por regiones desde 2017) |
| Precios en ciudades vecinas (Foz do Iguaçu, Posadas, Clorinda) | Gap de precios de frontera | IBGE (IPCA regional), INDEC/DPEC Misiones |
| Flujos fronterizos (cruces, compras de no residentes) | Volumen del arbitraje | DGM / Aduanas; balanza de pagos (viajes) |
| Concordancias HS–CPC–COICOP | Unir aduanas con IPC | INE / BCP; tablas ONU |
| Tipo de cambio paralelo del peso argentino | Gap real de frontera | Mercado informal (fuentes periodísticas), BCRA |

## 6. Evaluación de viabilidad

**Media para el pass-through agregado** por tipo de bien y etapa: hay valores y volúmenes de importación mensuales desde 1994, IPC de importados, IPP, tipos de cambio bilaterales y comercio por socio. **Baja para el mecanismo fronterizo**, que requiere aduanas a nivel de producto y precios regionales que no están en la base.

## 7. Supuestos que debes revisar

1. **IMTS** se lee directamente del CSV del FMI en `input/current/IMF_Data`, como acordamos, porque la base no lo incorpora; no pasó por los controles de la base.
2. Las importaciones bajo **régimen de turismo** (Cuadro 52) se usan como proxy de la reexportación/comercio fronterizo.
3. Los pares valor/toneladas se emparejan por etiqueta; algunas series de los Cuadros 51–52 son "no comprobadas" (identidad posicional): verificar el emparejamiento antes de calcular valores unitarios.
4. `ipp_importados` es el índice de productos importados del IPP, que cambió de base en marzo de 2025.
5. El IPC de Argentina del FMI empieza en 2016-12.
