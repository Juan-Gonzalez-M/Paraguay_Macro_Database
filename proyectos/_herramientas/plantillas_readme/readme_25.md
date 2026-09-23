# 25 · N4 (proyecto nuevo) — Sorpresas de política monetaria de alta frecuencia

*Carpeta de datos generada por `R/01_extraer_datos.R` · {{GENERADO}}*

> **Proyecto nuevo, de infraestructura con potencial causal.** Construye la serie de *shocks monetarios bien medidos* que hoy le falta al portafolio y que usarían como tratamiento A1, C2, C3, E3, B2 y el canal de crédito (proyecto 29).

## 1. Resumen y pregunta de investigación

En Paraguay la TPM responde a la inflación y a la actividad, por lo que su nivel no es un shock. La literatura (Gürkaynak-Sack-Swanson; Nakamura-Steinsson) identifica el componente sorpresivo con el movimiento de tasas de mercado en una ventana estrecha alrededor del anuncio.

- **Pregunta:** ¿qué parte de cada decisión del COPOM fue sorpresiva para el mercado y cómo se transmite esa sorpresa a las tasas interbancarias, de LRM, de bonos y al tipo de cambio?
- **Estimando:** serie de sorpresas `s_t = Δ tasa de mercado (ventana del anuncio)`, y respuestas de tasas y tipo de cambio a `s_t` (0–60 días).
- **Evidencia:** causal en el sentido de alta frecuencia (el anuncio es lo único que cambia sistemáticamente dentro de la ventana), con los límites de la sección 7.

## 2. Estrategia empírica propuesta

1. **Calendario:** fechas y horas de las reuniones y anuncios del COPOM (`datos_manuales/calendario_copom.csv`). Mientras tanto, `fechas_candidatas_cambio_tpm.csv` identifica **40 fechas** en que FPL y FPD se movieron en paralelo y en la misma magnitud (2015–2026), que reconstruyen la trayectoria de la TPM (p. ej., recortes a 0,75% en 2020 y subas a 8,5% en 2021–22).
2. **Sorpresa diaria:** variación de la tasa promedio del mercado interbancario (call + REPO + tripartito) y del REPO interbancario entre t−1 y t+1 del anuncio, menos el cambio de la TPM *esperado* (EVE, mediana del mes). Variante sin EVE: componente del cambio de la TPM no anticipado por el movimiento previo del interbancario.
3. **Validación:** las sorpresas deben ser grandes en las fechas del COPOM y ≈ 0 en días placebo (sin reunión); no deben predecirse con información pública previa (inflación, IMAEP, Fed).
4. **Transmisión:** proyecciones locales diarias de tasas de LRM adjudicadas, REPO, curva de bonos corporativos en PYG (plazos 1–5 años) y TCN sobre `s_t`; mensual, sobre tasas activas y pasivas.
5. **Uso posterior:** exportar la serie de sorpresas como instrumento de la TPM para A1, C2, C3, E3, B2 y el canal de crédito (proyecto 29).

## 3. Series extraídas

{{TABLA_SERIES}}

### Otros archivos

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `fechas_candidatas_cambio_tpm.csv` | Días en que FPD y FPL cambian el mismo día y en la misma magnitud, con la TPM implícita (punto medio del corredor) | {{RANGO:fechas_candidatas_cambio_tpm.csv}} | Inferido de datos preliminares |
| `cambios_corredor_inferidos.csv` | Todos los cambios diarios de la tasa FPD o FPL (incluye ajustes menores de 2013–2014 que no son decisiones de TPM) | {{RANGO:cambios_corredor_inferidos.csv}} | Inferido |
| `eventos_subastas_lrm.csv` | Subastas de LRM (tasas ofertadas/adjudicadas, montos, plazo) | {{RANGO:eventos_subastas_lrm.csv}} | Estructura especial |
| `curvas_bonos_pyg.csv` | Curva cero de bonos corporativos en PYG por calificación y plazo (fechas irregulares) | {{RANGO:curvas_bonos_pyg.csv}} | Validada por regla (estructural) |
| `datos_manuales/calendario_copom.csv` | **Plantilla para completar**: fecha de reunión, fecha y hora del anuncio, TPM anterior y nueva, tipo de reunión, fuente | vacía | Manual |

{{TABLA_ARCHIVOS}}

## 4. Cómo se usarían los datos

- **Ventanas:** diaria (t−1 a t+1). Con la hora del anuncio se puede decidir si el día del anuncio pertenece a t o a t+1 (anuncios después del cierre del mercado).
- **Tasas en puntos porcentuales**; sorpresas en puntos básicos. No transformar en logaritmos.
- **Días hábiles:** el mercado interbancario tiene huecos (días sin operaciones); usar la última observación disponible *antes* y la primera *después* del anuncio, y registrar la distancia en días.
- **Agregación mensual:** suma de las sorpresas del mes para usarlas en modelos mensuales.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| **Calendario del COPOM con hora de anuncio** | Define las ventanas; sin él la sorpresa se basa en las fechas inferidas del corredor (fecha de vigencia, no de anuncio) | BCP – comunicados del COPOM (lo conseguirás mañana) |
| Tasas intradía o de cierre del interbancario y del REPO | Ventanas más estrechas | BCP – mercado monetario |
| Rendimientos de mercado secundario de bonos del Tesoro y de LRM (diarios) | Sorpresas sobre la curva (*path* vs. *target*) | BVA / SEN; BCP |
| Forwards PYG/USD diarios | Reacción cambiaria de corto plazo | BCP – operaciones cambiarias |

## 6. Evaluación de viabilidad

**Media-alta.** Hay tasas diarias del interbancario y del corredor desde 2011–2014 y las fechas de cambio de TPM se pueden reconstruir desde los datos (40 fechas candidatas); con el calendario oficial del COPOM (que tendrás mañana) el proyecto queda completo. El límite es la ventana diaria: en Paraguay no hay un mercado de futuros de tasas y el interbancario es poco profundo.

## 7. Supuestos que debes revisar

1. Las fechas candidatas son **fechas de vigencia del nuevo corredor**, no necesariamente de la reunión ni del anuncio; confirmar con el calendario del COPOM.
2. En 2016 el punto medio del corredor (p. ej. 6,375%) no coincide con la TPM publicada: el corredor no era simétrico en todos los períodos; la TPM oficial debe venir del calendario.
3. Las decisiones de **mantener** la TPM no aparecen como fechas candidatas (no mueven el corredor), pero pueden contener sorpresas; por eso el calendario completo es indispensable.
4. Las series del mercado interbancario son "estructura especial (provisional)" en la base.

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Identificación de alta frecuencia

| Referencia | Qué respalda en este proyecto |
|---|---|
| Kuttner, K. N. (2001). "Monetary Policy Surprises and Interest Rates: Evidence from the Fed Funds Futures Market." *Journal of Monetary Economics*, 47(3), 523–544. **[Revista]** | Separar el componente **esperado** del sorpresivo de cada decisión con precios de mercado. Base del paso 2. |
| Gürkaynak, R. S., Sack, B. y Swanson, E. T. (2005). "Do Actions Speak Louder Than Words? The Response of Asset Prices to Monetary Policy Actions and Statements." *International Journal of Central Banking*, 1(1), 55–93. **[Revista]** | Sorpresas en ventanas estrechas y su efecto en la curva. Respalda el paso 4. |
| Nakamura, E. y Steinsson, J. (2018). "High-Frequency Identification of Monetary Non-Neutrality: The Information Effect." *Quarterly Journal of Economics*, 133(3), 1283–1330. **[Revista]** | Justificación de la ventana alrededor del anuncio, y advertencia sobre el **efecto información** (el anuncio revela información del banco central sobre la economía). |
| Jarociński, M. y Karadi, P. (2020). "Deconstructing Monetary Policy Surprises—The Role of Information Shocks." *American Economic Journal: Macroeconomics*, 12(2), 1–43. **[Revista]** | Separa el shock de política del de información con el co-movimiento de tasas y acciones. En Paraguay podría aproximarse con tasas y tipo de cambio. |
| Bauer, M. D. y Swanson, E. T. (2023). "A Reassessment of Monetary Policy Surprises and High-Frequency Identification." *NBER Macroeconomics Annual*, 37, 87–155. **[Revista]** | Las sorpresas pueden ser **predecibles** con información pública previa. Respalda la prueba de validación del paso 3. |

### 8.2 Alternativas cuando no hay derivados

| Referencia | Qué respalda |
|---|---|
| Romer, C. D. y Romer, D. H. (2004). "A New Measure of Monetary Shocks: Derivation and Implications." *American Economic Review*, 94(4), 1055–1084. **[Revista]** | Shock como el residuo de la decisión respecto de los pronósticos del banco central. Alternativa cuando el mercado interbancario es poco líquido (con los pronósticos internos del BCP). |
| Bolhuis, M. A., Das, S. y Yao, B. (2024). "A New Dataset of High-Frequency Monetary Policy Shocks." IMF Working Paper 24/224. **[DT]** | Base de datos de sorpresas diarias para 29 bancos centrales, incluidos emergentes, con un método estandarizado. Referencia de procedimiento y de comparación. |

### 8.3 Antecedentes para Paraguay

No encontré una serie publicada de sorpresas monetarias para Paraguay. Al no haber futuros de tasas, la sorpresa debe construirse con el **mercado interbancario** y con la **EVE** (mediana de la TPM esperada). Esa combinación de mercado y encuesta está menos validada en la literatura que los derivados, así que la validación del paso 3 es clave.
