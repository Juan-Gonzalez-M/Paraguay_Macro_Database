# 26 · N5 (proyecto nuevo) — Shocks cambiarios de Argentina y economía fronteriza paraguaya

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 20:40:33 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

> **Proyecto nuevo con potencial causal.** Las devaluaciones y controles cambiarios de Argentina son shocks grandes, fechados y decididos fuera de Paraguay: un experimento natural para el canal fronterizo que F2 no puede identificar con agregados.

## 1. Resumen y pregunta de investigación

- **Pregunta:** ¿cómo afectan los saltos del peso argentino al comercio bilateral, a las importaciones para reexportación (régimen de turismo), a los precios de bienes transables y de frontera, y a las remesas desde Argentina?
- **Estimandos:** respuestas acumuladas a 0–12 meses por episodio y en promedio (estudio de eventos), comparadas con el placebo de Brasil y de bienes no transables.
- **Evidencia:** forma reducida con shocks externos; la causalidad es creíble para el efecto total de cada episodio, no para mecanismos finos (no hay datos regionales).

## 2. Estrategia empírica propuesta

1. **Episodios:** 9 eventos candidatos en `datos_manuales/eventos_argentina.csv` (no verificados; completar con BCRA/prensa) y 15 meses con devaluación oficial > 10% en `episodios_devaluacion_argentina_inferidos.csv` (2002, 2014, 2015–16, 2018, 2019, 2023–24).
2. **Estudio de eventos mensual:** `y_{t+h} − y_{t−1}` alrededor de cada episodio, h = −6…+12, para exportaciones e importaciones con Argentina (Anexo e IMTS), importaciones bajo régimen de turismo, IPC transable/no transable/importados, carne vacuna, remesas desde Argentina.
3. **Placebos y controles:** las mismas variables frente a Brasil; IPC de no transables; meses sin shock. Controlar por el BRL y el dólar para aislar el componente argentino.
4. **Dosis-respuesta:** LP con `Δlog(ARS/USD)` continuo (y `Δlog PYG/ARS`) instrumentado por los episodios.
5. **Heterogeneidad:** controles de cambio (cepo) vs. devaluaciones con liberalización (2015, 2025): el gap entre el oficial y el paralelo cambia el signo esperado del arbitraje.

## 3. Series extraídas

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `pyg_ars` | PYG por ARS (promedio mensual; Cuadro 60a) | `economic_annex` CUADRO 60a | mensual | 1997-01-01 | 2026-07-01 | 355 | PYG_PER_ARS | Preliminar | Shock: tipo de cambio bilateral |
| `pyg_brl` | PYG por BRL (Cuadro 60a) | `economic_annex` CUADRO 60a | mensual | 1997-01-01 | 2026-07-01 | 355 | PYG_PER_BRL | Preliminar | Placebo / control regional |
| `pyg_usd_prom_venta` | PYG por USD promedio mensual | `exchange_rates` USD Prom | mensual | 1989-01-01 | 2026-07-01 | 451 | PYG_PER_USD | Validada por regla | Control |
| `tcr_argentina` | Tipo de cambio real bilateral con Argentina | `economic_annex` CUADRO 60c | mensual | 1995-01-01 | 2026-06-01 | 378 | INDEX | Validada por regla | Shock real (gap de precios) |
| `tcr_brasil` | Tipo de cambio real bilateral con Brasil | `economic_annex` CUADRO 60c | mensual | 1995-01-01 | 2026-06-01 | 378 | INDEX | Validada por regla | Placebo |
| `ars_usd_prom` | FMI: ARS por USD promedio mensual (oficial) | `imf_er` NA | mensual | 1962-05-01 | 2026-07-01 | 771 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Shock: devaluación oficial argentina |
| `brl_usd_prom` | FMI: BRL por USD promedio mensual | `imf_er` NA | mensual | 1957-01-01 | 2026-07-01 | 835 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Placebo |
| `ipc_argentina` | FMI: IPC Argentina (desde dic-2016) | `imf_cpi` NA | mensual | 2016-12-01 | 2026-06-01 | 115 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Precios del vecino |
| `ipc_brasil` | FMI: IPC Brasil | `imf_cpi` NA | mensual | 1979-12-01 | 2026-07-01 | 560 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Precios del vecino (placebo) |
| `tpm_argentina` | FMI: tasa de política Argentina | `imf_mfs_ir` NA | mensual | 2002-01-01 | 2025-06-01 | 282 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Contexto del shock |
| `expo_argentina` | Exportaciones registradas a Argentina (miles USD) | `economic_annex` Cuadro 45 | mensual | 1994-01-01 | 2026-07-01 | 391 | USD (miles) | Preliminar | Resultado: comercio |
| `expo_brasil` | Exportaciones registradas a Brasil | `economic_annex` Cuadro 45 | mensual | 1994-01-01 | 2026-07-01 | 391 | USD (miles) | Preliminar | Placebo |
| `expo_total` | Exportaciones registradas totales | `economic_annex` Cuadro 45 | mensual | 1994-01-01 | 2026-07-01 | 391 | USD (miles) | Preliminar | Normalización |
| `impo_argentina` | Importaciones registradas desde Argentina (miles USD) | `economic_annex` Cuadro 50 | mensual | 1994-01-01 | 2026-07-01 | 391 | USD (miles) | Preliminar | Resultado: comercio |
| `impo_brasil` | Importaciones registradas desde Brasil | `economic_annex` Cuadro 50 | mensual | 1994-01-01 | 2026-07-01 | 391 | USD (miles) | Preliminar | Placebo |
| `impo_total` | Importaciones registradas totales | `economic_annex` Cuadro 50 | mensual | 1994-01-01 | 2026-07-01 | 391 | USD (miles) | Preliminar | Normalización |
| `remesas_argentina` | Remesas familiares desde Argentina (miles USD) | `economic_annex` CUADRO 58 | mensual | 2008-01-01 | 2026-05-01 | 221 | USD (miles) | Preliminar | Resultado: ingreso de hogares |
| `remesas_total` | Remesas familiares totales | `economic_annex` CUADRO 58 | mensual | 2008-01-01 | 2026-05-01 | 221 | USD (miles) | Preliminar | Normalización |
| `ipc_indice` | IPC Paraguay índice general | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Resultado: precios |
| `ipc_transables_sin_fyv` | IPC transables sin frutas y verduras | `economic_annex` CUADRO 14 a | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Resultado: precios transables |
| `ipc_no_transables` | IPC no transables | `economic_annex` CUADRO 14 a | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Placebo (no transables) |
| `ipc_importados_sin_fyv` | IPC importados sin frutas y verduras | `economic_annex` CUADRO 14 a | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Resultado: precios importados |
| `ipc_alimentos_div` | IPC alimentos y bebidas no alcohólicas | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Resultado: bienes de frontera |
| `ipc_vestido_div` | IPC prendas de vestir y calzado | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Resultado: bienes de frontera |
| `ipc_carne_vacuna` | IPC carne vacuna | `economic_annex` CUADRO 16 a | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Resultado: bien exportado a Argentina / arbitraje |
| `imaep_original` | IMAEP serie original | `economic_annex` CUADRO 9 | mensual | 1994-01-01 | 2026-06-01 | 390 | INDEX | Preliminar | Control / resultado agregado |
| `impo_turismo_usd_*` | 192 series: economic_annex hoja Cuadro 52a (detalle en diccionario_series.csv) | `economic_annex` Cuadro 52a | mensual | 2006-01-01 | 2026-07-01 | 47.424 | USD (miles) | No comprobada (9); Preliminar (183) | Importaciones uso interno y régimen de turismo (miles USD): canal de reexportación |
| `impo_regimen_cuadro_54_*` | 10 series: economic_annex hoja Cuadro 54 (detalle en diccionario_series.csv) | `economic_annex` Cuadro 54 | mensual | 2003-01-01 | 2026-07-01 | 2.830 | USD (miles) | Preliminar (10) | Importaciones por régimen aduanero (miles USD) |

### Otros archivos

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `episodios_devaluacion_argentina_inferidos.csv` | Meses con devaluación oficial del ARS > 10% (FMI) | 2002-01-01 a 2024-01-01, 15 filas | Inferido |
| `comercio_bilateral_imts.csv` | Exportaciones FOB e importaciones CIF de Paraguay con Argentina y Brasil (FMI IMTS; millones de USD) | 1960-01-01 a 2026-05-01, 2.863 filas | Fuera de la base |
| `manual_eventos_argentina.csv` | Copia validada de `datos_manuales/eventos_argentina.csv` (9 candidatos **no verificados**) | 2014-01-23 a 2025-04-14, 9 filas | Manual, no verificado |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_mensual.csv` | 60.569 | 11 | 1957-01-01 | 2026-07-01 |
| `datos/series_mensual_ancho.csv` | 835 | 229 | 1957-01-01 | 2026-07-01 |
| `datos/diccionario_series.csv` | 228 | 13 | 1957-01-01 | 2016-12-01 |
| `datos/episodios_devaluacion_argentina_inferidos.csv` | 15 | 4 | 2002-01-01 | 2024-01-01 |
| `datos/comercio_bilateral_imts.csv` | 2.863 | 6 | 1960-01-01 | 2026-05-01 |
| `datos/manual_eventos_argentina.csv` | 9 | 6 | 2014-01-23 | 2025-04-14 |

## 4. Cómo se usarían los datos

- `Δlog` de tipos de cambio, flujos comerciales (en USD) y precios; flujos en proporción del total para neutralizar el ciclo común.
- Estacionalidad de comercio y remesas: variaciones interanuales o dummies de mes.
- El tipo de cambio **oficial** argentino (FMI) subestima el shock en períodos de cepo; registrar el tipo de cambio paralelo si se consigue (brecha).

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Tipo de cambio paralelo del ARS (blue, MEP, CCL) diario | Magnitud real del shock en períodos de cepo | Ámbito, BCRA (MEP/CCL), fuentes de mercado |
| IPC regional o por ciudad (frontera vs. interior: Encarnación, Pilar, Asunción) | Contraste geográfico, clave para el mecanismo fronterizo | INE / BCP |
| Aduanas por producto con Argentina | Productos más expuestos al arbitraje | DNA; Comtrade |
| Cruces fronterizos y compras de no residentes | Volumen del arbitraje de consumidores | DGM; Cámaras de comercio de Encarnación |
| Fechas oficiales de cada medida cambiaria argentina | Validar los eventos | BCRA – comunicaciones "A" |

## 6. Evaluación de viabilidad

**Media-alta.** Los shocks son grandes y externos, y la base tiene comercio bilateral, régimen de turismo, precios por componente y remesas por origen desde 1994–2008. Falta la dimensión geográfica (IPC regional) para afirmar el mecanismo fronterizo propiamente dicho.

## 7. Supuestos que debes revisar

1. Los 9 eventos de `eventos_argentina.csv` los cargué de memoria como candidatos: **verificar fechas y magnitudes** antes de usarlos. Los episodios inferidos de datos sí son reproducibles.
2. Las importaciones bajo régimen de turismo (Cuadro 52a) se usan como proxy del comercio de reexportación hacia Argentina y Brasil.
3. IMTS se lee directamente del CSV del FMI (no está en la base).
4. El IPC de Argentina del FMI empieza en 2016-12.
