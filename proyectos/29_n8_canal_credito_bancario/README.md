# 29 · N8 (proyecto nuevo) — Canal de crédito bancario de la política monetaria

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 20:43:31 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

> **Proyecto nuevo.** Descriptivo o de forma reducida por sí solo; **causal cuando se combine con la serie de sorpresas del proyecto 25**, que es su tratamiento natural.

## 1. Resumen y pregunta de investigación

- **Pregunta:** ante un cambio (o una sorpresa) de la TPM, ¿contraen más el crédito los bancos con menos liquidez, menos capital o fondeo más sensible a tasas? (Kashyap-Stein; Jiménez et al.)
- **Estimando:** diferencia en la respuesta del crédito por banco según sus características predeterminadas: `∂² crédito / ∂TPM ∂característica`.
- **Evidencia:** con la TPM en nivel, descriptiva (la TPM responde a la demanda de crédito); con sorpresas de alta frecuencia y efectos fijos sector × moneda × mes, causal en la **heterogeneidad** (no en el efecto agregado).

## 2. Estrategia empírica propuesta

1. **Características predeterminadas (t−1):** liquidez (disponible + inversiones / depósitos), capital (TIER 1/APR), tamaño, dependencia de depósitos a plazo/CDA, fondeo externo, participación en moneda extranjera.
2. **Tratamiento:** Δ TPM mensual; sorpresa = TPM − expectativa EVE del mes (mediana); cuando exista el calendario del COPOM, la sorpresa de alta frecuencia del proyecto 25.
3. **LP de panel banco × sector × moneda × mes:** `Δlog crédito_{b,s,m,t+h} = β_h · shock_t × X_{b,t−1} + FE_{s,m,t} + FE_{b,s,m} + ε`, h = 0–12.
4. **Canal de tasas:** tasas implícitas por banco (ingresos financieros / colocaciones; egresos financieros / depósitos) sobre las mismas interacciones.
5. **Moneda:** separar el crédito en PYG (transmisión directa) del crédito en USD (placebo o canal cruzado).

## 3. Series extraídas

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `tpm` | Tasa de política monetaria (promedio mensual) | `economic_annex` CUADRO 19  | mensual | 2011-05-01 | 2026-07-01 | 183 | PERCENT | Preliminar | Tratamiento (nivel) |
| `eve_tpm_mes` | EVE (mediana): TPM esperada para el mes | `eve` NA | mensual | 2014-06-01 | 2026-08-01 | 147 | PROPORTION | Preliminar | Sorpresa = TPM − esperada |
| `eve_tpm_prox_mes` | EVE (mediana): TPM esperada próximo mes | `eve` NA | mensual | 2014-06-01 | 2026-08-01 | 147 | PROPORTION | Preliminar | Sorpresa alternativa |
| `c31_mn_activa_prom` | Tasa efectiva activa MN promedio (etiqueta contaminada) | `economic_annex` CUADRO 31 | mensual | 2011-01-01 | 2026-05-01 | 185 | PERCENT | Preliminar | Traspaso a tasas activas |
| `c31_mn_pasiva_prom` | Tasa efectiva pasiva MN promedio (etiqueta contaminada) | `economic_annex` CUADRO 31 | mensual | 2011-01-01 | 2026-05-01 | 185 | PERCENT | Preliminar | Traspaso a tasas pasivas |
| `imaep_original` | IMAEP serie original | `economic_annex` CUADRO 9 | mensual | 1994-01-01 | 2026-06-01 | 390 | INDEX | Preliminar | Control de demanda |
| `ipc_var_interanual` | Inflación interanual | `economic_annex` CUADRO 15 | mensual | 1993-12-01 | 2026-07-01 | 392 | PERCENT | Validada por regla | Control |
| `pyg_usd_prom_venta` | PYG por USD promedio mensual | `exchange_rates` USD Prom | mensual | 1989-01-01 | 2026-07-01 | 451 | PYG_PER_USD | Validada por regla | Conversión y control |

### Paneles y datos manuales

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `panel_balance_entidad_mes.csv` | Activo, pasivo y patrimonio completos por entidad × sub-rubro × moneda (millones de Gs.) | 2016-01-01 a 2026-07-01, 157.673 filas | Panel provisional |
| `panel_credito_sector_entidad_mes.csv` | Cartera vigente y vencida por sector y moneda | 2016-01-01 a 2026-07-01, 66.073 filas | Panel provisional |
| `panel_ratios_entidad_mes.csv` | 40 ratios publicados (liquidez, capital, rentabilidad) | 2016-01-01 a 2026-07-01, 132.025 filas | Panel provisional |
| `datos_manuales/calendario_copom.csv` | **Plantilla** (mismo formato que en el proyecto 25) | vacía | Manual |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_mensual.csv` | 2.080 | 11 | 1989-01-01 | 2026-08-01 |
| `datos/series_mensual_ancho.csv` | 452 | 9 | 1989-01-01 | 2026-08-01 |
| `datos/diccionario_series.csv` | 8 | 13 | 1989-01-01 | 2014-06-01 |
| `datos/panel_balance_entidad_mes.csv` | 157.673 | 11 | 2016-01-01 | 2026-07-01 |
| `datos/panel_credito_sector_entidad_mes.csv` | 66.073 | 9 | 2016-01-01 | 2026-07-01 |
| `datos/panel_ratios_entidad_mes.csv` | 132.025 | 7 | 2016-01-01 | 2026-07-01 |
| `datos/entidades.csv` | 29 | 4 | — | — |

## 4. Cómo se usarían los datos

- Crédito en moneda de origen, `Δlog`; características en niveles predeterminados, estandarizadas.
- EVE en proporción: `sorpresa = tpm − 100 × eve_tpm_mes`.
- Errores agrupados por banco (≈ 29 entidades) con *wild bootstrap*.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Calendario del COPOM (y la serie de sorpresas del proyecto 25) | Tratamiento creíble | BCP |
| Crédito nuevo (originaciones) y tasas por banco | Separar stock de flujo y precio | SIB |
| Registro de crédito (mismo prestatario en varios bancos) | Efectos fijos de prestatario × tiempo: identificación de oferta más fuerte | Central de riesgos |

## 6. Evaluación de viabilidad

**Media** hoy (TPM y sorpresa EVE mensuales, panel completo desde 2016); **media-alta** cuando se incorpore la serie de sorpresas del proyecto 25.

## 7. Supuestos que debes revisar

1. La sorpresa EVE supone que la encuesta se releva antes de la decisión del mes.
2. Paneles con bancos y financieras; revisar fusiones antes de usar exposiciones predeterminadas largas.
3. Las tasas del Cuadro 31 (MN) tienen etiquetas contaminadas; asignadas por texto inicial.

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Canal de crédito bancario

| Referencia | Qué respalda en este proyecto |
|---|---|
| Bernanke, B. S. y Blinder, A. S. (1992). "The Federal Funds Rate and the Channels of Monetary Transmission." *American Economic Review*, 82(4), 901–921. **[Revista]** | Evidencia agregada del canal de crédito. |
| Bernanke, B. S. y Gertler, M. (1995). "Inside the Black Box: The Credit Channel of Monetary Policy Transmission." *Journal of Economic Perspectives*, 9(4), 27–48. **[Revista]** | Marco conceptual: canal de préstamos bancarios y canal de hoja de balance. |
| Kashyap, A. K. y Stein, J. C. (2000). *American Economic Review*, 90(3), 407–428. **[Revista]** | **Diseño central**: la respuesta del crédito a la política depende de la liquidez del banco. Es `∂²crédito/∂TPM∂liquidez`. |
| Kishan, R. P. y Opiela, T. P. (2000). *Journal of Money, Credit and Banking*, 32(1), 121–141. **[Revista]** | Heterogeneidad por tamaño y capital. |
| Gambacorta, L. (2005). "Inside the Bank Lending Channel." *European Economic Review*, 49(7), 1737–1759. **[Revista]** | Versión para un sistema bancario europeo, con liquidez y capitalización como características predeterminadas. Modelo cercano a la especificación con el panel EEFF. |
| Jiménez, G., Ongena, S., Peydró, J.-L. y Saurina, J. (2012). *American Economic Review*, 102(5), 2301–2326. **[Revista]** | Efectos fijos de demanda y política × capital del banco. Estándar del paso 3. |
| Drechsler, I., Savov, A. y Schnabl, P. (2017). *Quarterly Journal of Economics*, 132(4), 1819–1876. **[Revista]** | El canal de depósitos como explicación alternativa de la heterogeneidad (paso 4). |

### 8.2 El tratamiento

- Las sorpresas de alta frecuencia del proyecto 25 (Kuttner, 2001; Nakamura y Steinsson, 2018) hacen **causal la heterogeneidad**. Con la TPM en nivel, el coeficiente de interacción es más creíble que el efecto agregado, porque los efectos fijos absorben la demanda común.

### 8.3 Antecedentes para Paraguay

- **[PY]** Rojas (2017, tesis de la UdeSA; ver carpeta 06) estima el traspaso agregado a tasas. No encontré estudios a nivel banco del canal de crédito en Paraguay.
