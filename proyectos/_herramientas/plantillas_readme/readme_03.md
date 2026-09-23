# 03 · B2 — Marco multi-horizonte del guaraní-dólar

*Carpeta de datos generada por `R/01_extraer_datos.R` · {{GENERADO}}*

## 1. Resumen y pregunta de investigación

El nivel de equilibrio, el retorno mensual y el movimiento diario del PYG/USD son objetos distintos. El proyecto construye un marco recurrente, separado por frecuencia, que mejore el diagnóstico y el pronóstico sin convertir una estimación de "valor justo" en objetivo de política.

- **Pregunta:** ¿qué variables explican y predicen el PYG/USD a cada horizonte (1 día a 24 meses)?
- **Estimando:** contribuciones históricas y desempeño fuera de muestra de modelos por frecuencia frente al random walk; **no** el efecto causal de cada fundamental.
- **Mecanismo:** ajuste macro lento (términos de intercambio, precios relativos, diferenciales de tasas) frente a presión financiera de alta frecuencia (dólar global, Brasil, aversión al riesgo).

## 2. Estrategia empírica propuesta

1. **Mensual, nivel (ECM/BEER), 1995–2026.** Relación de largo plazo entre el TCR multilateral (o el PYG/USD real) y sus fundamentos: términos de intercambio (`ctot_expo_pry`, soja), diferencial de productividad aproximado por IMAEP relativo, posición externa. Corrección de errores para la dinámica. Bandas amplias; descomposición histórica.
2. **Mensual, retorno (1–24 meses).** Regresiones predictivas directas por horizonte y BVAR pequeño (PYG/USD, dólar amplio, BRL/USD, soja, diferencial de tasas TPM − Fed, inflación relativa), estimados de forma recursiva desde 2011 (inicio de TPM y de tasas por moneda). Benchmark: random walk y random walk con drift; métricas RMSE, Diebold-Mariano/Clark-West, tests de Giacomini-Rossi para estabilidad.
3. **Diario (1–20 días), 2013–2026.** Retornos del TCN referencial sobre retornos del dólar amplio, BRL/USD, VIX y compras netas del BCP (esta última solo como control, no como tratamiento; ver B1).
4. **Frontera:** modelo de espacio de estados que combine un componente lento (BEER) con presión de mercado diaria.

Exigencias de la ficha: benchmark simple, evaluación recursiva, tests de estabilidad, episodios históricos predefinidos (p. ej. 2015, 2018 Argentina, 2020 COVID, 2022 sequía). Que no se le gane al random walk es un resultado válido que delimita el uso del marco.

## 3. Series extraídas

Valores tal como se publican. Las variables externas (FRED) se descargan en cada corrida y quedan en `datos/fuentes_externas/`.

{{TABLA_SERIES}}

Formatos: `series_mensual.csv` y `series_diaria.csv` en formato largo (con unidad, nivel y `candidate_id`); `*_ancho.csv` con una columna por serie. `fecha` = primer día del período.

{{TABLA_ARCHIVOS}}

## 4. Cómo se usarían los datos

- **Variable dependiente:** `log(pyg_usd_prom_venta)` en el nivel; `Δlog` a h meses para retornos; `Δlog(tcn_venta)` diario. Mantener compra y venta separadas; usar venta como principal.
- **Precios relativos:** `log(ipc_indice) − log(ipc_eeuu)` (EE.UU.) y contra `ipe_multilateral`; alternativamente `tcr_multilateral`. El IPC de Paraguay (`ipc_indice`, base dic-2017) no está desestacionalizado: usar variaciones interanuales o desestacionalizar con X-13 si se usan variaciones mensuales. El IPC de EE.UU. viene desestacionalizado.
- **Tasas:** diferencial `tpm − fed_rango_superior` (o `fed_funds_efectiva` para historia previa a 2016); en USD `tasa_pasiva_cda_me − ust_2a`.
- **Términos de intercambio:** `log(soja_chicago)` y `log(ctot_expo_pry)`; deflactar precios en USD por `ipc_eeuu` si se usan en nivel real.
- **Actividad:** `imaep_original` (1994–) con desestacionalización propia; `imaep_desest` (2014–) solo como robustez (ver supuestos).
- **Diario → mensual:** promedio del mes para precios (compatible con `pyg_usd_prom_venta`), suma para compras netas del BCP; alinear el dólar amplio y el VIX por fecha calendario (sin rellenar feriados de Paraguay con datos de EE.UU. hacia adelante: dejar `NA`).
- **Expectativas:** error de pronóstico EVE = `eve_tc_anio_t` (medido en el mes t) − valor realizado a fin de año; útil como benchmark adicional frente al random walk.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Índice DXY (ICE) propiamente dicho | La ficha pide "dólar amplio"; incluí el índice amplio de la Fed, no el DXY | ICE / Bloomberg; alternativamente usar el de la Fed (incluido) |
| Precios forward PYG/USD (no volúmenes) | Nivel "ideal": diferencial cubierto, expectativas de mercado | BCP – mesa de cambios; bancos (BBVA, Itaú); Bloomberg NDF |
| Compras netas de bancos por tipo de cliente | Nivel "ideal" | BCP – Operaciones Cambiarias (reportes diarios de posición) |
| Actividad mensual de Brasil y Argentina (IBC-Br, EMAE) | Canal regional de demanda | BCB (SGS 24363), INDEC |
| IPC de Argentina antes de dic-2016 | La serie del FMI empieza en 2016-12 por la discontinuidad del INDEC | INDEC + IPC-CABA / provincias para empalme |
| Hora de cierre y fuente exacta del TCN referencial | Metadato exigido por la ficha | BCP – Estudios Económicos |
| Vintages macro | La ficha los lista como "óptimo"; excluidos por tu instrucción | — |

## 6. Evaluación de viabilidad

**Alta.** El núcleo mensual (tipo de cambio, TCR, precios, actividad, commodities, tasas, comercio, expectativas) está completo desde 1995 —en parte validado por regla—, el diario desde 2012–2013, y los controles globales se incorporaron desde FRED.

## 7. Supuestos que debes revisar

1. **Serie principal:** promedio mensual lado **venta** del mercado fluctuante (validada por regla) y TCN referencial diario lado venta.
2. **EVE = mediana** (confirmado por ti); se usa solo como benchmark de pronóstico.
3. **Dólar amplio:** índice nominal amplio de la Fed (`TWEXBGSMTH`, desde 2006) empalmable con el índice anterior (`TWEXBMTH`, 1973–2019); no es el DXY.
4. **IMAEP:** uso el Cuadro 9 (1994–, preliminar) como serie principal por longitud y el 9 a (2014–, validado) como robustez; puede haber cambio de base entre ambos.
5. **Tasas externas de la hoja 8 de Indicadores Financieros** (Fed, Selic) tienen la unidad sin resolver en la base; las leo como % anual. Para la historia previa a 2016 uso `fed_funds_efectiva` de FRED.
6. **IPC de Argentina** del FMI empieza en 2016-12; no lo empalmé.
7. Los volúmenes forward y spot del Cuadro 61 son **montos brutos** del mercado local, no precios ni flujo neto firmado.
8. No incluí vintages ni fechas de publicación (excluidos por tu instrucción); la evaluación fuera de muestra es pseudo-real, con datos finales.

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Por qué un marco separado por horizonte

| Referencia | Qué respalda en este proyecto |
|---|---|
| Meese, R. A. y Rogoff, K. (1983). "Empirical Exchange Rate Models of the Seventies: Do They Fit Out of Sample?" *Journal of International Economics*, 14(1–2), 3–24. **[Revista]** | Origen del **random walk como benchmark** obligatorio. Respalda la exigencia de la ficha de que "no ganarle al random walk" sea un resultado válido. |
| Engel, C. y West, K. D. (2005). "Exchange Rates and Fundamentals." *Journal of Political Economy*, 113(3), 485–517. **[Revista]** | Explica por qué los fundamentos pueden determinar el tipo de cambio y aun así no predecirlo a corto plazo. Justifica separar el **nivel de equilibrio** (ECM/BEER) del **pronóstico de retornos**. |
| Rossi, B. (2013). "Exchange Rate Predictability." *Journal of Economic Literature*, 51(4), 1063–1119. **[Revista]** | Revisión de referencia: la predictibilidad depende del horizonte, del modelo, de la métrica y de la muestra, y es inestable en el tiempo. Respalda la evaluación recursiva por horizonte y las pruebas de estabilidad. |

### 8.2 Variables: fundamentos de nivel y factores de alta frecuencia

| Referencia | Variable que respalda |
|---|---|
| Clark, P. B. y MacDonald, R. (1999). "Exchange Rates and Economic Fundamentals: A Methodological Comparison of BEERs and FEERs." En MacDonald, R. y Stein, J. L. (eds.), *Equilibrium Exchange Rates*. Kluwer. **[Libro]** | Especificación **BEER** del paso 1: TCR sobre términos de intercambio, productividad relativa y posición externa, con corrección de errores. |
| Chen, Y.-C. y Rogoff, K. (2003). "Commodity Currencies." *Journal of International Economics*, 60(1), 133–160. **[Revista]** | Precio de las exportaciones básicas como determinante del TCR en economías exportadoras. Respalda `ctot_expo_pry` y el precio de la soja. |
| Cashin, P., Céspedes, L. F. y Sahay, R. (2004). "Commodity Currencies and the Real Exchange Rate." *Journal of Development Economics*, 75(1), 239–268. **[Revista]** | Encuentra relaciones de largo plazo entre el TCR y los precios de exportación en economías en desarrollo exportadoras de commodities, y es el antecedente más cercano para Paraguay. |
| Lilley, A., Maggiori, M., Neiman, B. y Schreger, J. (2022). "Exchange Rate Reconnect." *Review of Economics and Statistics*, 104(4), 845–855. **[Revista]** | Desde 2008 los tipos de cambio se mueven con el **ciclo global de riesgo y el dólar**. Respalda el dólar amplio, el VIX y el BRL/USD como factores diarios y mensuales. |

### 8.3 Evaluación de pronósticos

| Referencia | Uso |
|---|---|
| Diebold, F. X. y Mariano, R. S. (1995). "Comparing Predictive Accuracy." *Journal of Business & Economic Statistics*, 13(3), 253–263. **[Revista]** | Prueba de igual precisión frente al random walk. |
| Clark, T. E. y West, K. D. (2007). "Approximately Normal Tests for Equal Predictive Accuracy in Nested Models." *Journal of Econometrics*, 138(1), 291–311. **[Revista]** | Versión correcta para modelos anidados (random walk ⊂ modelo con fundamentos). |
| Giacomini, R. y Rossi, B. (2010). "Forecast Comparisons in Unstable Environments." *Journal of Applied Econometrics*, 25(4), 595–620. **[Revista]** | Comparación de pronósticos con desempeño relativo cambiante en el tiempo (episodios 2015, 2018, 2020, 2022). |

### 8.4 Antecedentes para Paraguay

- **[PY]** Banco Central del Paraguay, Informe de Política Monetaria, Recuadro I, "Estimación del Tipo de Cambio Real de Equilibrio" ([enlace](https://www.bcp.gov.py/documents/20117/80085/Recuadro+I+_Estimaci%C3%B3n+del+Tipo+de+Cambio+Real+de+Equilibrio.pdf)). Según su descripción pública, aplica el BEER de Clark y MacDonald (1999) estimado por DOLS con fundamentos filtrados. **El paso 1 de este proyecto es, por lo tanto, una actualización de un ejercicio que el BCP ya hizo.** El aporte está en los pasos 2 a 4: pronóstico por horizonte, frecuencia diaria y evaluación fuera de muestra. No pude abrir el PDF, así que conviene confirmar la edición del IPoM y los fundamentos usados.
