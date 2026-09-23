# 06 · C2 — Depósitos, crédito y sustitución entre intermediarios

*Carpeta de datos generada por `R/01_extraer_datos.R` · {{GENERADO}}*

## 1. Resumen y pregunta de investigación

En un sistema dual (PYG/USD), la política monetaria puede redistribuir depósitos entre monedas, entre productos (vista, plazo, CDA), entre bancos y hacia valores o cooperativas. Mirar solo el crédito bancario puede sobre- o subestimar la transmisión.

- **Pregunta:** ¿cómo cambia el fondeo —precio, cantidad y moneda— ante la política monetaria, y qué sucede con el crédito?
- **Estimandos:** (i) *beta de depósitos* por producto y moneda (traspaso de la TPM a las tasas pasivas); (ii) respuesta de los flujos de depósitos y crédito; (iii) sustitución entre tipos de prestamista (bancos, financieras, cooperativas).
- **Evidencia:** descriptiva y de forma reducida; oferta causal solo con exposición predeterminada y comparación común de demanda.

## 2. Estrategia empírica propuesta

1. **Betas de depósito (sistema, 2011–2026).** Para cada tasa pasiva `tef_*` (producto × plazo × moneda): `Δ tasa_{t,t+h} = β_h Δ TPM_t + controles`, en proyecciones locales h = 0–12 meses, separando subidas y bajadas (asimetría tightening/easing) y ciclos (2011–2015, 2019–2021, 2021–2023, 2024–2026). Sorpresa alternativa: `tpm − eve_tpm_mes` (EVE mediana).
2. **Mapa de flujos (sistema).** Descomposición de la variación de depósitos privados por moneda e instrumento (Cuadro 23a) y del crédito (Cuadro 24a) alrededor de cambios de TPM; verificar que "los flujos sumen".
3. **Panel entidad-mes (2016–2026).** Beta de fondeo por entidad aproximada con la tasa implícita de depósitos (egresos financieros por obligaciones con el sector no financiero / depósitos, del EEFF) y crecimiento de depósitos por moneda y producto; heterogeneidad por participación de mercado (concentración) y por franquicia (proporción de depósitos a la vista, cantidad de canales). Exposición predeterminada × cambio de TPM, con efectos fijos de tiempo (y de sector-tiempo en crédito) para absorber la demanda común.
4. **Sustitución banca–cooperativas (agregado, 2017-12 a 2025-11).** Solo descriptiva: participación de las cooperativas Tipo A en depósitos y créditos totales alrededor de los ciclos de TPM.

## 3. Series extraídas

Series del Anexo, de Indicadores Financieros (hojas 1.2, 2.2, 4, 5, 6 y 7 completas, con nombres generados a partir de la etiqueta publicada) y de bancarización. Valores tal como se publican.

{{TABLA_SERIES}}

### Paneles y curvas

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `curvas_cda_mensual.csv` | Curva de CDA: tasa ponderada, cantidad de operaciones y volumen captado por plazo (30 días a 8 años), moneda y tipo de entidad; hojas mensuales `CDA_ML_mmaaaa`, `CDA_ME_mmaaaa`, `OPERACIONES_VOLUMEN_*` | {{RANGO:curvas_cda_mensual.csv}} | Estructura especial |
| `panel_eeff_entidad_mes.csv` | Estados financieros completos: 98 sub-rubros × moneda (6900 PYG / 6200 ME en PYG) × entidad | {{RANGO:panel_eeff_entidad_mes.csv}} | Panel provisional |
| `panel_carteras_entidad_mes.csv` | Cartera vigente, vencida, renovada, refinanciada, reestructurada; depósitos a la vista, plazo fijo, CDA, cuenta corriente | {{RANGO:panel_carteras_entidad_mes.csv}} | Panel provisional |
| `panel_credito_sector_entidad_mes.csv` | Cartera vigente y vencida por 13 sectores y moneda | {{RANGO:panel_credito_sector_entidad_mes.csv}} | Panel provisional |
| `panel_ratios_entidad_mes.csv` | 40 ratios publicados por entidad (liquidez, morosidad, capital, rentabilidad, eficiencia) | {{RANGO:panel_ratios_entidad_mes.csv}} | Panel provisional |
| `entidades.csv` | Correspondencia `entity_id` → nombre, razón social y tipo de propiedad. En los paneles "raw" `codigo_entidad` = número de `entity_id` sin el prefijo `bank:`/`finance:` | 29 entidades | Referencia |

{{TABLA_ARCHIVOS}}

## 4. Cómo se usarían los datos

- **Tasas:** en puntos porcentuales, sin logaritmos. Betas en diferencias; tasas reales restando `ipc_var_interanual` (o expectativas EVE de inflación) solo para comparaciones de nivel.
- **Cantidades:** `log` de saldos en PYG; los saldos en ME expresados en PYG deben **convertirse a USD** con `dep_priv_tc` (o el tipo de cambio de fin de mes) antes de medir flujos, para no confundir depreciación con captación. Deflactar por IPC cuando se comparen niveles en PYG en el tiempo.
- **Estacionalidad:** depósitos a la vista y crédito de consumo tienen estacionalidad marcada (diciembre, aguinaldo); usar variaciones interanuales o X-13 en los agregados; en el panel, efectos fijos de mes calendario.
- **Panel:** mantener `codigo_moneda` como dimensión (nunca sumar 6200 y 6900 sin convertir); construir el panel balanceado solo después de revisar fusiones y altas/bajas de entidades.
- **Curva CDA:** interpolar por plazo solo dentro de cada mes y moneda; usar el nodo de 1 año como tasa de referencia del fondeo a plazo.
- **Horizontes:** 0–12 meses para betas; 0–24 meses para cantidades.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Tasas pasivas y activas **por banco** y producto | La beta por entidad es el núcleo "suficiente"; hoy solo hay promedios/máx./mín. del sistema | SIB/BCP – reporte de tasas por entidad (Res. de transparencia de tasas) |
| Panel de cooperativas por entidad (depósitos, créditos, tasas) | Sustitución banca–cooperativas | INCOOP – estados financieros de cooperativas Tipo A/B/C |
| Identificadores comunes banco–cooperativa de clientes | Frontera de la ficha (borrower-time FE) | Central de riesgos BCP + INCOOP (acuerdo institucional) |
| Depósitos por plazo residual y fondeo mayorista por banco | Fricción de cambio y fondeo alternativo | SIB – reportes regulatorios de liquidez |
| Uso digital / pagos instantáneos por entidad | Movilidad de depósitos (enlaza con F4) | BCP – SPI por entidad (parcialmente en la carpeta 20) |

## 6. Evaluación de viabilidad

**Media-alta para la versión bancaria.** Hay tasas por producto, plazo y moneda desde 2011, la curva CDA desde 2018 y paneles entidad-mes completos desde 2016; falta la tasa por entidad. **Baja para la sustitución con cooperativas**, que solo existe como agregado mensual Tipo A (96 meses) sin datos por entidad.

## 7. Supuestos que debes revisar

1. **Etiquetas contaminadas en el Cuadro 31 (MN):** las etiquetas traen números pegados; asigné cada serie por su texto inicial (vista, plazo, CDA, promedio, activa sin tarjetas ni sobregiros).
2. **Cooperativas (Cuadros 23b/24b):** la base agrega "— %" a etiquetas que por magnitud son **montos en millones de Gs.** (p. ej. depósitos totales ≈ 18,4 billones de Gs. en 2025-11). Las series de participación (%) quedaron fuera por tener identidad posicional (no comprobadas).
3. Las series ME de los Cuadros 23a/24a están en **millones de Gs. equivalentes** (la base dice "unidad no resuelta"); las versiones "en millones de USD" se incluyen aparte.
4. Las hojas 4 y 7 de Indicadores Financieros son **saldos** (PYG) aunque la etiqueta publicada diga "Tasa Pasiva/Activa"; es el encabezado del bloque, no la unidad.
5. Los nombres de las series de Indicadores Financieros se generaron automáticamente a partir de la etiqueta publicada (`tef_*` = tasas efectivas; `saldos_*` = saldos); la descripción completa y el `candidate_id` están en `diccionario_series.csv`.
6. Los paneles son completos (sin filtrar rubros), como acordamos para C2.
7. La sorpresa de política con EVE supone que la mediana de la expectativa del mes se releva antes de la decisión del COPOM; verificar el calendario de la encuesta.

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Diseño: betas de depósito y canal de fondeo

| Referencia | Qué respalda en este proyecto |
|---|---|
| Drechsler, I., Savov, A. y Schnabl, P. (2017). "The Deposits Channel of Monetary Policy." *Quarterly Journal of Economics*, 132(4), 1819–1876. **[Revista]** | Referencia central. Define la **beta de depósitos** (traspaso de la tasa de política a las tasas pasivas), muestra que depende del poder de mercado de cada banco y que las subas de tasas generan salida de depósitos y menos crédito. Respalda los pasos 1 y 3 y la heterogeneidad por concentración y franquicia. |
| Kashyap, A. K. y Stein, J. C. (2000). "What Do a Million Observations on Banks Say about the Transmission of Monetary Policy?" *American Economic Review*, 90(3), 407–428. **[Revista]** | Canal de préstamo bancario: la respuesta del crédito depende de la liquidez del banco. Respalda la exposición predeterminada × cambio de TPM. |
| Kishan, R. P. y Opiela, T. P. (2000). "Bank Size, Bank Capital, and the Bank Lending Channel." *Journal of Money, Credit and Banking*, 32(1), 121–141. **[Revista]** | Heterogeneidad por tamaño y capital. Respalda usar la participación de mercado y el capital del panel EEFF como dimensiones de exposición. |

### 8.2 Identificación: absorber la demanda de crédito

| Referencia | Uso |
|---|---|
| Khwaja, A. I. y Mian, A. (2008). "Tracing the Impact of Bank Liquidity Shocks: Evidence from an Emerging Market." *American Economic Review*, 98(4), 1413–1442. **[Revista]** | Efectos fijos que absorben la demanda común para aislar la oferta. Respalda los efectos fijos de tiempo y de sector-tiempo. Su versión ideal requiere datos prestatario-banco, que la base no tiene (ver brechas). |
| Jiménez, G., Ongena, S., Peydró, J.-L. y Saurina, J. (2012). "Credit Supply and Monetary Policy: Identifying the Bank Balance-Sheet Channel with Loan Applications." *American Economic Review*, 102(5), 2301–2326. **[Revista]** | Canal de balance bancario con política monetaria interactuada con características del banco. Es el estándar al que se acerca el paso 3. |

### 8.3 Sustitución entre intermediarios y dolarización

| Referencia | Qué respalda |
|---|---|
| Xiao, K. (2020). "Monetary Transmission through Shadow Banks." *Review of Financial Studies*, 33(6), 2379–2420. **[Revista]** | Ante subas de tasas, los depósitos migran de los bancos a intermediarios no bancarios. Respalda el paso 4 (bancos frente a cooperativas y financieras). |
| Levy Yeyati, E. (2006). "Financial Dollarization: Evaluating the Consequences." *Economic Policy*, 21(45), 61–118. **[Revista]** | Consecuencias de la dolarización financiera para la política monetaria. Respalda separar las betas y los flujos **por moneda**. |
| Acosta-Ormaechea, S. y Coble, D. (2011). "Monetary Transmission in Dollarized and Non-Dollarized Economies: The Cases of Chile, New Zealand, Peru and Uruguay." IMF Working Paper 11/87. **[DT]** | En economías dolarizadas (Perú, Uruguay) el canal de tasas es más débil y se fortalece con la desdolarización. Comparación regional directa para Paraguay. |

### 8.4 Antecedentes para Paraguay

- **[PY]** Rojas, E. (2017). *El efecto traspaso de corto y largo plazo de las tasas de política monetaria a las tasas de interés de la economía en Paraguay.* Tesis de Maestría en Finanzas, Universidad de San Andrés. Estima un traspaso de largo plazo promedio de ≈ 0,54 (2004–2015) y prueba asimetrías y el rol de la dolarización. **Es el antecedente directo del paso 1**: este proyecto lo extiende con datos por producto, plazo y moneda hasta 2026, proyecciones locales y panel por entidad.
- **[PY]** Banco Central del Paraguay (2017). Informe de Política Monetaria, junio 2017, Recuadro I, "Dolarización financiera en Paraguay". Contexto de la dolarización de depósitos y créditos.
