# 18 · F2 — Precios de importación, arbitraje fronterizo e inflación

*Carpeta de datos generada por `R/01_extraer_datos.R` · {{GENERADO}}*

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

{{TABLA_SERIES}}

### Comercio por país socio (fuera de la base)

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `comercio_por_socio_imts_mensual.csv` | FMI IMTS: exportaciones FOB, importaciones CIF e importaciones FOB de Paraguay por país socio (≈ 220 socios y agregados), mensual, en millones de USD. Leído directamente de `input/current/IMF_Data/…(IMTS).csv`, que **no tiene parser en la base** | {{RANGO:comercio_por_socio_imts_mensual.csv}} | Fuera de la base, sin validar |

{{TABLA_ARCHIVOS}}

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

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Pass-through por etapa y moneda de facturación

| Referencia | Qué respalda en este proyecto |
|---|---|
| Campa, J. M. y Goldberg, L. S. (2005). "Exchange Rate Pass-Through into Import Prices." *Review of Economics and Statistics*, 87(4), 679–690. **[Revista]** | Pass-through a precios de importación, incompleto y distinto por tipo de bien. Respalda el paso 1 (valores unitarios por tipo de bien). |
| Burstein, A. y Gopinath, G. (2014). "International Prices and Exchange Rates." En *Handbook of International Economics*, vol. 4, 391–451. Elsevier. **[Capítulo]** | Revisión de referencia: el pass-through cae de la frontera al consumidor por costos locales de distribución. Respalda el análisis **por etapa** (importación → productor → consumidor). |
| Gopinath, G., Boz, E., Casas, C., Díez, F. J., Gourinchas, P.-O. y Plagborg-Møller, M. (2020). "Dominant Currency Paradigm." *American Economic Review*, 110(3), 677–719. **[Revista]** | Los precios de comercio se fijan en dólares y el tipo de cambio frente al dólar domina sobre el bilateral. Respalda el paso 3 (dólar frente a canasta ponderada por comercio). |
| Forbes, K., Hjortsoe, I. y Nenova, T. (2018). "The Shocks Matter: Improving Our Estimates of Exchange Rate Pass-Through." *Journal of International Economics*, 114, 255–275. **[Revista]** | El pass-through depende del **shock** que mueve el tipo de cambio. Respalda comparar el dólar amplio, el PYG/USD y los bilaterales como fuentes distintas. |

### 8.2 Canal regional y fronterizo

| Referencia | Qué respalda |
|---|---|
| Burstein, A., Eichenbaum, M. y Rebelo, S. (2005). "Large Devaluations and the Real Exchange Rate." *Journal of Political Economy*, 113(4), 742–784. **[Revista]** | Tras grandes devaluaciones, los precios de no transables y de distribución se ajustan lentamente. Respalda los no transables como placebo y los episodios de Brasil y Argentina. |
| Campbell, J. R. y Lapham, B. (2004). "Real Exchange Rate Fluctuations and the Dynamics of Retail Trade Industries on the U.S.-Canada Border." *American Economic Review*, 94(4), 1194–1206. **[Revista]** | El comercio minorista en la frontera responde al tipo de cambio real bilateral. Es el antecedente conceptual del canal fronterizo (régimen de turismo frente a `tcr_brasil` y `tcr_argentina`). |

### 8.3 Medición

| Referencia | Uso |
|---|---|
| Silver, M. (2009). "Do Unit Value Export, Import, and Terms-of-Trade Indices Misrepresent Price Indices?" *IMF Staff Papers*, 56(2), 297–322. **[Revista]** | Sesgos de los **valores unitarios** por cambios de composición y calidad. Respalda la advertencia del paso 1 y la limpieza de outliers. |

### 8.4 Antecedentes para Paraguay

- **[PY]** Monfort, B. y Peña, S. (2008). IMF Working Paper 08/270 (ver carpeta 12). Los precios de Brasil pesan en la inflación de corto plazo, lo que respalda los bilaterales BRL frente al dólar.
- **[PY]** Masi, F. (2006). *Paraguay: los vaivenes de la política comercial externa en una economía abierta.* CADEP. Describe el régimen de turismo y la reexportación a Brasil y Argentina (comercio de triangulación). Es el contexto institucional del paso 4.
