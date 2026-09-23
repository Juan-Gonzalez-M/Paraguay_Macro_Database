# 30 · N9 (proyecto nuevo) — SPI y demanda de efectivo: sustitución entre medios de pago

*Carpeta de datos generada por `R/01_extraer_datos.R` · {{GENERADO}}*

> **Proyecto nuevo, descriptivo.** Complementa el tablero de F4 con una pregunta concreta: ¿redujo el SPI el uso de efectivo y de cheques? **No tiene identificación causal limpia**: hay una sola fecha nacional de lanzamiento (mayo de 2022), sin grupo de control, y coincide con el ciclo de subas de tasas y la inflación alta de 2022.

## 1. Resumen y pregunta de investigación

- **Pregunta:** ¿cuánto sustituyó el SPI al efectivo (M0), a los cheques, a las transferencias ACH y a las tarjetas de débito, y cambió la composición de los depósitos transaccionales?
- **Estimando:** quiebre en la tendencia y en la participación de cada medio de pago tras 2022-05 y tras cada hito del SPI (alias, QR, iniciadores de pago).
- **Evidencia:** descriptiva/predictiva (serie de tiempo interrumpida con controles).

## 2. Estrategia empírica propuesta

1. **Participaciones por riel** (número e importe): SPI, ACH, LBTR cliente-cliente, cheques compensados, tarjetas de débito/crédito/prepagas; antes y después de 2022-05.
2. **Demanda de efectivo:** modelo de demanda de M0/M2 con TPM, inflación, IMAEP y estacionalidad, estimado hasta 2022-04 y proyectado fuera de muestra: la brecha entre lo observado y lo proyectado mide el cambio posterior (con bandas).
3. **Hitos:** cargar las fechas de alias, QR, iniciadores de pago y cambios de límites en `datos_manuales/hitos_spi.csv` y probar quiebres adicionales.
4. **Variación entre entidades (exploratoria):** cajeros y corresponsales por entidad (panel de canales) vs. adopción de alias por entidad (en la carpeta 20).

## 3. Series extraídas

{{TABLA_SERIES}}

### Otros archivos

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `panel_canales_entidad_mes.csv` | Cajeros automáticos, dependencias, terminales de autoservicio y corresponsales no bancarios por entidad | {{RANGO:panel_canales_entidad_mes.csv}} | Panel provisional |
| `manual_hitos_spi.csv` | Copia de `datos_manuales/hitos_spi.csv` (1 hito inferido: inicio 2022-05, no verificado) | {{RANGO:manual_hitos_spi.csv}} | Manual |

{{TABLA_ARCHIVOS}}

## 4. Cómo se usarían los datos

- M0 y depósitos en PYG deflactados por IPC; `log` y variación interanual; estacionalidad fuerte en diciembre.
- En `SIPAP_07`, `column_3` = cantidad y `column_4` = importe del SPI (etiquetas vacías en la base).
- Participaciones sobre el total de pagos electrónicos (suma de rieles).

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Fechas de hitos del SPI (entrada de entidades, QR, alias, límites) | Quiebres múltiples y variación entre entidades | BCP – normativa SPI (lo conseguirás mañana) |
| SPI por entidad-día | Variación de adopción entre bancos | BCP – SIPAP |
| Retiros de efectivo en cajeros | Uso directo del efectivo | Bancard / Infonet |

## 6. Evaluación de viabilidad

**Media como estudio descriptivo** (≈ 50 meses de SPI y todos los rieles desde 2013); **baja para causalidad** por la ausencia de grupo de control y la coincidencia con el ciclo monetario de 2022.

## 7. Supuestos que debes revisar

1. Inicio del SPI = 2022-05 (primer dato del boletín); confirmar la fecha oficial.
2. Las series por entidad del boletín de pagos se identifican por posición (ver carpeta 20).

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Pagos digitales y demanda de efectivo

| Referencia | Qué respalda en este proyecto |
|---|---|
| Alvarez, F. y Lippi, F. (2009). "Financial Innovation and the Transactions Demand for Cash." *Econometrica*, 77(2), 363–402. **[Revista]** | Demanda de efectivo con tecnología de pagos como determinante. Base de la especificación del paso 2. |
| Chodorow-Reich, G., Gopinath, G., Mishra, P. y Narayanan, A. (2020). "Cash and the Economy: Evidence from India's Demonetization." *Quarterly Journal of Economics*, 135(1), 57–103. **[Revista]** | Sustitución entre efectivo y pagos electrónicos ante un shock. |
| Crouzet, N., Gupta, A. y Mezzanotti, F. (2023). *Journal of Political Economy*, 131(11), 3003–3065. **[Revista]** | La adopción de pagos electrónicos es **persistente** por complementariedades. Respalda buscar quiebres de tendencia y no solo de nivel. |
| Duarte, A., Frost, J., Gambacorta, L., Koo Wilkens, P. y Shin, H. S. (2022). BIS Bulletin 52. **[DT]** | Caso Pix: adopción rápida y sustitución de otros rieles (TED, DOC, boletos). Comparación directa para el paso 1. |
| Sarkisyan, S. SSRN 4176990. **[DT]** | Efecto de Pix en los depósitos por tipo de banco. Referencia para la variación entre entidades del paso 4. |

### 8.2 Métodos para una serie de tiempo interrumpida

| Referencia | Uso |
|---|---|
| Brodersen, K. H., Gallusser, F., Koehler, J., Remy, N. y Scott, S. L. (2015). "Inferring Causal Impact Using Bayesian Structural Time-Series Models." *Annals of Applied Statistics*, 9(1), 247–274. **[Revista]** | Contrafactual proyectado con modelo estimado antes del lanzamiento y bandas de incertidumbre. Es exactamente el paso 2. |
| Bernal, J. L., Cummins, S. y Gasparrini, A. (2017). "Interrupted Time Series Regression for the Evaluation of Public Health Interventions: A Tutorial." *International Journal of Epidemiology*, 46(1), 348–355. **[Revista]** | Buenas prácticas y amenazas a la validez (eventos simultáneos como el ciclo de tasas de 2022). |

### 8.3 Antecedentes para Paraguay

No encontré evaluaciones académicas del SPI (ver carpeta 20). El limitante sigue siendo la falta de un grupo de control; la literatura con identificación creíble (Higgins, 2024; Sarkisyan) usa **variación geográfica** en la exposición, que en Paraguay requeriría datos por localidad.
