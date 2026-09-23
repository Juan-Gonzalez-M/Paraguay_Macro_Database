# 09 · D1 — ENSO no lineal y respuestas macroeconómicas

*Carpeta de datos generada por `R/01_extraer_datos.R` · {{GENERADO}}*

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

{{TABLA_SERIES}}

{{TABLA_ARCHIVOS}}

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

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 ENSO como shock macroeconómico

| Referencia | Qué respalda en este proyecto |
|---|---|
| Brunner, A. D. (2002). "El Niño and World Primary Commodity Prices: Warm Water or Hot Air?" *Review of Economics and Statistics*, 84(1), 176–183. **[Revista]** | ENSO mueve los precios mundiales de commodities y la inflación. Respalda incluir precios de alimentos, soja y petróleo como controles y el IPC de alimentos como resultado. |
| Cashin, P., Mohaddes, K. y Raissi, M. (2017). "Fair Weather or Foul? The Macroeconomic Effects of El Niño." *Journal of International Economics*, 106, 37–54. **[Revista]** | Referencia central: efectos de El Niño sobre el PIB, la inflación y los precios de commodities por país, **con signos distintos según la región** (en algunos países El Niño es favorable). Respalda estimar el perfil para Paraguay en lugar de suponer un signo. |
| Smith, S. C. y Ubilava, D. (2017). "The El Niño Southern Oscillation and Economic Growth in the Developing World." *Global Environmental Change*, 45, 151–164. **[Revista]** | Efectos **asimétricos** entre fases y regiones en 69 países en desarrollo. Respalda separar `ONI⁺` y `ONI⁻`. |
| Generoso, R., Couharde, C., Damette, O. y Mohaddes, K. (2020). "The Growth Effects of El Niño and La Niña: Local Weather Conditions Matter." *Annals of Economics and Statistics*, 140, 83–126. **[Revista]** | Diferencias sustanciales entre El Niño y La Niña, mediadas por el clima local (lluvia, temperatura). Respalda el diseño por fase y la brecha "lluvia local por departamento". |
| Callahan, C. W. y Mankin, J. S. (2023). "Persistent Effect of El Niño on Global Economic Growth." *Science*, 380(6649), 1064–1069. **[Revista]** | Efectos persistentes durante varios años. Respalda horizontes de hasta 24 meses. |
| Liu, Y., Cai, W., Lin, X., Li, Z. y Zhang, Y. (2023). "Nonlinear El Niño Impacts on the Global Economy under Climate Change." *Nature Communications*, 14, 5887. **[Revista]** | Pérdidas que crecen de forma **no lineal** con la intensidad. Respalda la base spline sobre la intensidad del ONI con nudos fijados ex ante. |

### 8.2 Canal agrícola y de precios

| Referencia | Variable que respalda |
|---|---|
| Iizumi, T. et al. (2014). "Impacts of El Niño Southern Oscillation on the Global Yields of Major Crops." *Nature Communications*, 5, 3712. **[Revista]** | Efectos de ENSO sobre los rendimientos de soja, maíz, trigo y arroz por región. Respalda los volúmenes exportados de soja, maíz y trigo y el PIB agrícola como resultados. |
| Ubilava, D. (2018). "The Role of El Niño Southern Oscillation in Commodity Price Movement and Predictability." *American Journal of Agricultural Economics*, 100(1), 239–263. **[Revista]** | ENSO predice precios de commodities de forma no lineal. Respalda controlar los precios mundiales para separar el canal local (producción) del global (precios). |
| Dell, M., Jones, B. F. y Olken, B. A. (2014). "What Do We Learn from the Weather? The New Climate-Economy Literature." *Journal of Economic Literature*, 52(3), 740–798. **[Revista]** | Marco general de identificación con variación climática como cuasi-experimento, y sus límites (pocos eventos, adaptación). |

### 8.3 Métodos econométricos

| Referencia | Uso |
|---|---|
| Jordà, Ò. (2005). *American Economic Review*, 95(1), 161–182. **[Revista]** | Proyecciones locales con términos no lineales. |
| Barnichon, R. y Brownlees, C. (2019). "Impulse Response Estimation by Smooth Local Projections." *Review of Economics and Statistics*, 101(3), 522–530. **[Revista]** | Proyecciones locales suavizadas con B-splines, útiles con muestras cortas y pocos eventos. |
| Montiel Olea, J. L. y Plagborg-Møller, M. (2019). "Simultaneous Confidence Bands: Theory, Implementation, and an Application to SVARs." *Journal of Applied Econometrics*, 34(1), 1–17. **[Revista]** | Bandas sup-t simultáneas para todo el perfil de respuesta (paso 2). |

### 8.4 Antecedentes para Paraguay

- **[PY]** González, Á. (BCP). "Nonlinear Climate Shocks and Financial Stability: Evidence from El Niño in Paraguay." Presentado en un taller regional sobre adaptación al cambio climático organizado por el BCP ([nota de prensa](https://marketdata.com.py/noticias/fenomenos-climaticos-como-el-nino-bajo-el-analisis-de-los-bancos-centrales-latinoamericanos-151477/)). **Es el antecedente más cercano** (no lineal, El Niño, Paraguay), aunque se enfoca en estabilidad financiera, que es el tema del proyecto 13 (D5). Conviene conseguir el documento para no duplicar y para alinear la medición de ENSO.
- **[PY]** PNUD Paraguay. "Paraguay: impactos económicos y sociales de la sequía" ([enlace](https://www.undp.org/es/paraguay/publicaciones/paraguay-impactos-economicos-y-sociales-de-la-sequia)). Evaluación descriptiva de la sequía 2021–2022, útil como validación de episodios.
