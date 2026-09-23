# 12 · D4 — Inflación climática, precios relativos y riesgo de cola

*Carpeta de datos generada por `R/01_extraer_datos.R` · {{GENERADO}}*

## 1. Resumen y pregunta de investigación

Un efecto medio de ENSO sobre la inflación no dice en qué parte de la canasta cae ni cuánto eleva el riesgo de inflación alta. La ficha propone dos módulos complementarios, sin confundir la predicción de colas con la causalidad de segunda vuelta:

- **Módulo 1 — propagación:** ¿qué componentes del IPC (alimentos frescos, carne, procesados, transables, núcleo) cargan el efecto ENSO y con qué rezago?
- **Módulo 2 — distribución:** ¿mejora la información ENSO el pronóstico de cuantiles y de la probabilidad de superar un umbral (p. ej. inflación interanual > meta + 2 pp) a 1–12 meses?
- **Evidencia:** forma reducida para componentes; predictiva para densidades. No inferir política óptima de la reacción histórica.

## 2. Estrategia empírica propuesta

1. **Perfiles por componente (1995–2026):** proyecciones locales con la misma especificación y nudos que D1 (carpeta 09) para cada componente; tests conjuntos entre componentes y control de multiplicidad. **No** controlar por alimentos al estimar el efecto sobre el núcleo (post-tratamiento).
2. **Descomposición por tipo de bien:** tradables/no tradables (Cuadro 14 a), flexibles/administrados (Cuadro 14 c), bienes/servicios (Cuadro 14 b), y precios al productor (Cuadro 17) como etapa previa.
3. **Regresión cuantílica y pronóstico de densidad:** cuantiles 10/50/90 de la inflación interanual a h = 1–12 con y sin ENSO, precios mundiales de alimentos y tipo de cambio; evaluación recursiva fuera de muestra con CRPS y WIS; benchmark EVE (mediana) y random walk.
4. **Probabilidad de cola:** logit/probit de `π_{t+h} > umbral`; scores de Brier y curvas de confiabilidad.

## 3. Series extraídas

{{TABLA_SERIES}}

{{TABLA_ARCHIVOS}}

## 4. Cómo se usarían los datos

- **Variaciones:** `Δlog` mensual e interanual de los índices; para las series oficiales de variación (Cuadro 15, validadas) usar directamente las publicadas.
- **Estacionalidad:** frutas y verduras y alimentos tienen estacionalidad fuerte; usar variaciones interanuales o desestacionalizar (X-13) cada componente por separado **antes** de agregar, y no desestacionalizar la serie de ENSO.
- **Precios mundiales:** en USD; convertir a PYG con `pyg_usd_prom_venta` para medir el traspaso en moneda local o incluir el tipo de cambio por separado.
- **Expectativas EVE:** proporciones (0,04 = 4%); multiplicar por 100.
- **ENSO:** rezagar un mes el ONI (media móvil centrada).
- **Muestra:** el IPP (Cuadro 17) cambió de base en marzo de 2025 y varios componentes empiezan ese mes; usar solo los que cubren 1995–2026.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Clima (lluvia, temperatura) nacional/regional | Canal físico; nivel "mínimo" pide "clima" además de ONI | DMH-DINAC; CHIRPS; ERA5-Land |
| Jerarquía estable del IPC con ponderaciones (base 2017) | Agregación consistente y contribuciones | BCP – metodología del IPC |
| Precios mayoristas (Mercado de Abasto de Asunción) | Etapa intermedia alimentos | DAMA / MAG – precios del Abasto |
| Microprecios por ítem y comercio | Nivel "óptimo" | BCP – relevamiento del IPC |
| Distribución de expectativas (EVE: dispersión, cuantiles) | Densidades de expectativas | BCP – EVE interna |
| Vintages del IPC y de la EVE | Evaluación en tiempo real | Excluido por tu instrucción |

## 6. Evaluación de viabilidad

**Media-alta.** Con el ONI incorporado desde NOAA, el mínimo de la ficha —IPC total, alimentos y núcleo, ONI, clima y tasa— queda completo salvo el clima físico, y el nivel "suficiente" (alimentos mundiales, tipo de cambio, EVE, componentes) también está. El riesgo principal es la cantidad de componentes frente a pocos episodios ENSO.

## 7. Supuestos que debes revisar

1. **Etiquetas del Cuadro 15:** las series de índice figuran como "Índice — Interanual" (p. ej. `ipc15_cuadro_15_combustibles_indice_interanual`); por su unidad (INDEX) las trato como **niveles de índice**, no como variaciones. Verificar contra el Excel.
2. **Cuadro 17 (IPP):** la serie `ipp_cuadro_17_indice_general_indice_de_productos_importados` tiene una etiqueta combinada ambigua; puede ser el índice general. El IPP cambió de base en marzo de 2025.
3. Uso las mismas definiciones de ENSO que D1 (ONI, RONI y Niño 3.4 de NOAA).
4. EVE = mediana; no hay cuantiles de expectativas.
5. El IPCSAE empieza en 2007-12; el resto de los núcleos, en 1995.

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Módulo 2: inflación en riesgo (cuantiles y colas)

| Referencia | Qué respalda en este proyecto |
|---|---|
| Adrian, T., Boyarchenko, N. y Giannone, D. (2019). "Vulnerable Growth." *American Economic Review*, 109(4), 1263–1289. **[Revista]** | Método de referencia: **regresión cuantílica** de resultados futuros sobre variables de estado y ajuste de una distribución completa. Es la base del paso 3. |
| López-Salido, D. y Loria, F. (2024). "Inflation at Risk." *Journal of Monetary Economics*, 145. **[Revista]** | Aplica el enfoque de Adrian et al. a la **inflación** en un panel de la OCDE: las colas varían mucho aunque la media sea estable. Respalda que ENSO pueda mover las colas sin mover la mediana. |
| Koenker, R. y Bassett, G. (1978). "Regression Quantiles." *Econometrica*, 46(1), 33–50. **[Revista]** | Estimador cuantílico. |
| Gneiting, T. y Raftery, A. E. (2007). "Strictly Proper Scoring Rules, Prediction, and Estimation." *Journal of the American Statistical Association*, 102(477), 359–378. **[Revista]** | CRPS y reglas de puntuación propias para evaluar pronósticos de densidad. |
| Bracher, J., Ray, E. L., Gneiting, T. y Reich, N. G. (2021). "Evaluating Epidemic Forecasts in an Interval Format." *PLOS Computational Biology*, 17(2), e1008618. **[Revista]** | Definición del **WIS** (weighted interval score) para evaluar cuantiles 10/50/90. |

### 8.2 Módulo 1: clima y componentes del IPC

| Referencia | Qué respalda |
|---|---|
| Kotz, M., Kuik, F., Lis, E. y Nickel, C. (2024). "Global Warming and Heat Extremes to Enhance Inflationary Pressures." *Communications Earth & Environment*, 5, 116. **[Revista]** | Con IPC mensuales de muchos países, la temperatura eleva la inflación de **alimentos** y la general durante unos 12 meses, con efectos que dependen de la estación y la región. Respalda los perfiles por componente con horizonte de 12 meses. |
| Brunner, A. D. (2002). *Review of Economics and Statistics*, 84(1), 176–183. **[Revista]** | ENSO → precios mundiales de commodities (ver carpeta 09). |
| Cashin, P., Mohaddes, K. y Raissi, M. (2017). *Journal of International Economics*, 106, 37–54. **[Revista]** | ENSO → inflación por país (ver carpeta 09). |
| Peersman, G. (2022). "International Food Commodity Prices and Missing (Dis)Inflation in the Euro Area." *Review of Economics and Statistics*, 104(1), 85–100. **[Revista]** | Traspaso de los precios mundiales de alimentos a la inflación, incluida la **segunda vuelta** hacia el núcleo. Respalda no controlar por alimentos al estimar el efecto sobre el núcleo. |

### 8.3 Antecedentes para Paraguay

- **[PY]** Monfort, B. y Peña, S. (2008). "Inflation Determinants in Paraguay: Cost Push versus Demand Pull Factors." IMF Working Paper 08/270. **[DT]** Encuentra que los precios de algunos alimentos y los precios de Brasil pesan en la dinámica de corto plazo de la inflación paraguaya. Respalda el foco en alimentos y carne como canal del clima.
- **[PY]** Ver también el trabajo de Á. González (BCP) citado en la carpeta 09.
