# 26 · N5 (proyecto nuevo) — Shocks cambiarios de Argentina y economía fronteriza paraguaya

*Carpeta de datos generada por `R/01_extraer_datos.R` · {{GENERADO}}*

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

{{TABLA_SERIES}}

### Otros archivos

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `episodios_devaluacion_argentina_inferidos.csv` | Meses con devaluación oficial del ARS > 10% (FMI) | {{RANGO:episodios_devaluacion_argentina_inferidos.csv}} | Inferido |
| `comercio_bilateral_imts.csv` | Exportaciones FOB e importaciones CIF de Paraguay con Argentina y Brasil (FMI IMTS; millones de USD) | {{RANGO:comercio_bilateral_imts.csv}} | Fuera de la base |
| `manual_eventos_argentina.csv` | Copia validada de `datos_manuales/eventos_argentina.csv` (9 candidatos **no verificados**) | {{RANGO:manual_eventos_argentina.csv}} | Manual, no verificado |

{{TABLA_ARCHIVOS}}

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

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Devaluaciones grandes como experimento

| Referencia | Qué respalda en este proyecto |
|---|---|
| Burstein, A., Eichenbaum, M. y Rebelo, S. (2005). "Large Devaluations and the Real Exchange Rate." *Journal of Political Economy*, 113(4), 742–784. **[Revista]** | Tras grandes devaluaciones los precios de transables y no transables se ajustan de forma muy distinta. Respalda los no transables como placebo y la separación transable/no transable. |
| Campbell, J. R. y Lapham, B. (2004). "Real Exchange Rate Fluctuations and the Dynamics of Retail Trade Industries on the U.S.-Canada Border." *American Economic Review*, 94(4), 1194–1206. **[Revista]** | El comercio minorista fronterizo responde al tipo de cambio real bilateral. Mecanismo del régimen de turismo. |
| MacKinlay, A. C. (1997). "Event Studies in Economics and Finance." *Journal of Economic Literature*, 35(1), 13–39. **[Revista]** | Metodología del estudio de eventos (paso 2). |

### 8.2 Tipos de cambio múltiples y remesas

| Referencia | Qué respalda |
|---|---|
| Kiguel, M. y O'Connell, S. A. (1995). "Parallel Exchange Rates in Developing Countries." *World Bank Research Observer*, 10(1), 21–52. **[Revista]** | Con controles cambiarios, el relevante para el arbitraje es el **paralelo**, no el oficial. Respalda el paso 5 y la brecha de datos del tipo de cambio paralelo argentino. |
| Yang, D. (2008). "International Migration, Remittances and Household Investment: Evidence from Philippine Migrants' Exchange Rate Shocks." *Economic Journal*, 118(528), 591–630. **[Revista]** | Shocks cambiarios en el país donde viven los migrantes como variación exógena de las remesas. Respalda el resultado "remesas desde Argentina". |

### 8.3 Antecedentes para Paraguay

- **[PY]** Masi, F. (2006). *Paraguay: los vaivenes de la política comercial externa en una economía abierta.* CADEP. Contexto del régimen de turismo y de la triangulación con Argentina y Brasil.
- **[PY]** Adler y Sosa (2012), IMF WP 12/145 (ver carpeta 24): vínculos comerciales del Cono Sur. Se enfoca en Brasil; los shocks de **Argentina** sobre Paraguay están menos estudiados, lo que es parte del aporte.
