# 01 · A1 — Demanda de reservas y huella de liquidez de las operaciones FX

*Carpeta de datos generada por `R/01_extraer_datos.R` · {{GENERADO}}*

## 1. Resumen y pregunta de investigación

La tasa de política no llega mecánicamente al crédito: la escasez de reservas bancarias, la liquidación de operaciones cambiarias del BCP y la esterilización con IRM/LRM pueden mover el premio de liquidez del mercado interbancario. El proyecto distingue el **nivel** de reservas del **shock neto** de liquidez.

- **Pregunta:** ¿cómo cambian el spread interbancario (TIB − TPM), el uso de las facilidades permanentes y las condiciones bancarias ante escasez de reservas o ante una sorpresa de liquidez por liquidación FX?
- **Estimandos:** (i) curva condicional reservas–spread; (ii) respuesta dinámica del spread y del uso de facilidades a una innovación neta de liquidez.
- **Tipo de evidencia:** descriptiva y de forma reducida. Causalidad solo si se valida una sorpresa institucional.

## 2. Estrategia empírica propuesta

1. **Identidad de liquidez mensual.** Variación de reservas bancarias en el BCP (encaje + cuenta corriente) = compras netas de divisas del BCP − colocación neta de IRM − Δ depósitos del Tesoro en el BCP − Δ efectivo + crédito del BCP (FPL). Verificar que la identidad "cuadre" es el primer entregable; los residuos grandes indican rubros faltantes.
2. **Curva reservas–spread (mensual, 2015–2026).** Regresión flexible (splines penalizados o por tramos con nudos fijados ex ante) del spread `tib_mensual − tpm`, y de la posición de la TIB dentro del corredor `(TIB − FPD)/(FPL − FPD)`, sobre reservas excedentes / depósitos, con efectos de calendario (fin de mes, aguinaldo en diciembre, vencimientos de IRM) y dummies de régimen del corredor.
3. **Proyecciones locales diarias (2013–2026).** Respuesta del spread diario (`tib_d_tasa_prom − tpm` interpolada al día) y del uso de FPL/FPD a las compras netas del BCP al sector financiero (`bcp_fx_neto_financiero_d`), horizonte 1–20 días hábiles, controlando por días de liquidación de subastas de LRM (archivo de eventos). La compra FX es endógena a la presión cambiaria: reportar como asociación condicionada.
4. **Extensión banco-mes (2016–2026).** Exposición predeterminada de cada entidad (cuenta corriente en el BCP / depósitos, en t−12) interactuada con el shock agregado; resultado: crecimiento de colocaciones y tenencia de valores públicos. Solo forma reducida.

Pruebas exigidas por la ficha: pre-tendencias, placebos de calendario, medidas alternativas de escasez (encaje vs. cuenta corriente vs. ratio de liquidez), resultado nulo fuera de la zona de escasez.

## 3. Series extraídas

Todas las series salen de `database/paraguay_macro_pilot.duckdb` en modo lectura. Valores tal como se publican (sin reescalar); la escala de cada serie está en la columna "Unidad".

{{TABLA_SERIES}}

### Otros archivos

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `eventos_subastas_lrm.csv` | Subastas de LRM, subasta a subasta: montos anunciado/ofertado/asignado, tasas mín./prom./máx., posturas; `detalle` trae el plazo estandarizado y residual | {{RANGO:eventos_subastas_lrm.csv}} | Estructura especial |
| `eventos_facilidad_liquidez.csv` | Subastas de depósito y repo de administración de liquidez de corto plazo | {{RANGO:eventos_facilidad_liquidez.csv}} | Estructura especial |
| `panel_eeff_liquidez_entidad_mes.csv` | Bancos y financieras × mes × moneda (6900 = PYG, 6200 = ME expresado en PYG): caja, **encaje, cuenta corriente en el BCP, depósitos por operaciones monetarias (IRM)**, valores, colocaciones, depósitos, pasivo con el BCP, interbancarios | {{RANGO:panel_eeff_liquidez_entidad_mes.csv}} | Panel provisional |
| `panel_ratios_liquidez_entidad_mes.csv` | Ratios de liquidez (disponible + inversiones temporales / depósitos y / pasivos), morosidad y TIER 1 por entidad | {{RANGO:panel_ratios_liquidez_entidad_mes.csv}} | Panel provisional |

Formatos: `series_<frecuencia>.csv` en formato largo (una fila por serie-fecha, con unidad, nivel y `candidate_id`) y `series_<frecuencia>_ancho.csv` (una columna por serie). `fecha` = primer día del período; `fecha_fin` = último día. `00_manifiesto.csv` registra filas, rango y versión de la base de cada archivo.

{{TABLA_ARCHIVOS}}

## 4. Cómo se usarían los datos

- **Spreads:** `tib_mensual − tpm`; diario `tib_d_tasa_prom − tpm` (TPM llevada al día con el último valor mensual; mejor reemplazar por el calendario de decisiones, ver brechas). Posición en el corredor `(TIB − FPD)/(FPL − FPD)`.
- **Reservas:** `bancos_ctacte_mn` (reservas por encima del encaje) y `bancos_encaje_mn` en niveles, normalizadas por depósitos en PYG (Cuadro 23 o panel EEFF) o por la base monetaria. Nada de logaritmos sobre el ratio; sí `log` para los niveles.
- **Deflactación:** innecesaria para spreads; para montos en PYG usar IPC si se comparan niveles a través de más de 5 años.
- **Estacionalidad:** no desestacionalizar las reservas: la estacionalidad (fin de mes, diciembre) *es* parte del mecanismo; modelarla con dummies de calendario.
- **Moneda extranjera:** `bancos_*_me` están en millones de Gs. equivalentes; convertir a USD con `tcn_venta` del último día hábil del mes si se analiza la liquidez en dólares.
- **Agregación diario → mensual:** promedios del mes para tasas; sumas para compras/ventas del BCP; fin de mes para saldos.
- **Panel:** usar solo `codigo_moneda = 6900` para la liquidez en PYG; los rubros `Encaje` y `Cuenta Corriente-BCP` por banco permiten construir la exposición predeterminada.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Saldos **diarios** de reservas bancarias en el BCP (encaje computable, cuenta corriente, excedente) | La curva reservas–spread diaria es el núcleo "suficiente" de la ficha; hoy solo hay fin de mes | BCP – Gerencia de Operaciones de Mercado Abierto / Sistemas de Pago (datos internos) |
| Calendario fechado de decisiones del COPOM y cambios del corredor, del encaje y de la remuneración del encaje | Para regímenes, dummies y la TPM diaria | BCP – comunicados del COPOM, resoluciones del Directorio |
| Flujos diarios del Tesoro en el BCP | Principal fuente de liquidez autónoma no FX | MEF – Tesorería General; BCP (cuenta del Tesoro) |
| Liquidación intradía SIPAP por entidad | Nivel "óptimo" | BCP – SIPAP |
| Tasas y cantidades de crédito nuevo por banco-moneda-sector | Condiciones bancarias a nivel banco | SIB – central de riesgos / reporte de tasas por entidad |
| Hora de liquidación de operaciones FX y de subastas | Separar decisión de liquidación | BCP – mesa de cambios |

## 6. Evaluación de viabilidad

**Media.** El lado de precios (TIB, REPO, corredor, subastas) está disponible a diario desde 2011–2014 y la contabilidad mensual de reservas desde 1994, pero la variable de cantidad central —reservas bancarias— solo existe a fin de mes, lo que limita la curva reservas–spread a unas 130 observaciones mensuales con corredor vigente.

## 7. Supuestos que debes revisar

1. **"Reservas" = reservas de los bancos en el BCP** (encaje legal + cuenta corriente, Cuadro 27 y rubros del panel EEFF). Las RIN (`rin_saldo`) entran solo como control.
2. **Etiquetas del Cuadro 19 contaminadas.** Asigné por valores: `tpm` (5,50% en 2026-07), `irm_colocado_total` y `irm_saldo` (la base les pega "456 a 728 días", pero por magnitud son el total del mes y el saldo total: ≈ 5,9 billones de Gs. en 2026-07), `irm_rend_ponderado` es una **tasa en %** aunque la base diga "PYG millions".
3. `bancos_encaje_me` y `resto_sf_encaje_me` figuran con unidad no resuelta; por magnitud y por el título del cuadro los leo como **millones de Gs. equivalentes**.
4. `repo_interb_monto` viene con escala "units" mientras los demás montos interbancarios están en millones de Gs.; no lo reescalé: revisar contra la hoja `Datos` antes de sumar.
5. Excluí el *call money* PYG de la hoja diaria `Datos` porque solo tiene 12 observaciones (el agregado CMM + REPO + tripartito sí es continuo).
6. `dep_adm_central_bcp` (Cuadro 35) es un proxy mensual de la cuenta del Tesoro; su etiqueta en la base también está contaminada con números.
7. Las subastas de LRM se entregan en formato evento completo; la base las marca como identidad anual por hoja **no resuelta** (tasas ofertadas vs. asignadas): verificar contra el Excel antes de construir series de tasas de LRM.
8. El panel conserva bancos y financieras; las entidades que entran, salen o se fusionan entre 2016 y 2026 no fueron depuradas.

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Base teórica y de diseño

| Referencia | Qué respalda en este proyecto |
|---|---|
| Poole, W. (1968). "Commercial Bank Reserve Management in a Stochastic Model: Implications for Monetary Policy." *Journal of Finance*, 23(5), 769–791. **[Revista]** | Fundamento de una **curva de demanda de reservas no lineal**: con shocks de pago inciertos, la tasa interbancaria queda entre las tasas de las facilidades y sube cuando las reservas escasean. Es la razón para medir la posición de la TIB dentro del corredor `(TIB − FPD)/(FPL − FPD)` y no solo el spread. |
| Afonso, G., Giannone, D., La Spada, G. y Williams, J. C. (2022). "Scarce, Abundant, or Ample? A Time-Varying Model of the Reserve Demand Curve." FRBNY Staff Report 1019. **[DT]** | Modelo más cercano a la **curva reservas–spread** del paso 2: estima la pendiente de la demanda de reservas con reservas normalizadas por activos y encuentra una zona plana ("abundante") y otra empinada ("escasa"). Respalda normalizar las reservas excedentes por depósitos y la prueba de "resultado nulo fuera de la zona de escasez". |
| Lopez-Salido, D. y Vissing-Jorgensen, A. (2023). "Reserve Demand, Interest Rate Control, and Quantitative Tightening." SSRN 4371999. **[DT]** | Estima la demanda de reservas mensual en función del spread y de las necesidades de liquidez, y trata los depósitos del Tesoro en el banco central como **factor autónomo** de oferta de reservas. Respalda la identidad de liquidez del paso 1 (Δ depósitos del Tesoro, Δ efectivo, operaciones FX). |
| Hamilton, J. D. (1996). "The Daily Market for Federal Funds." *Journal of Political Economy*, 104(1), 26–56. **[Revista]** | Documenta **efectos de calendario** en la tasa interbancaria diaria (cierre del período de encaje, días de liquidación). Respalda los controles de fin de mes, aguinaldo y vencimientos de IRM/LRM en la especificación diaria. |

### 8.2 Métodos econométricos

| Referencia | Uso |
|---|---|
| Jordà, Ò. (2005). "Estimation and Inference of Impulse Responses by Local Projections." *American Economic Review*, 95(1), 161–182. **[Revista]** | Proyecciones locales diarias del spread y del uso de FPL/FPD (paso 3). |
| Kashyap, A. K. y Stein, J. C. (2000). "What Do a Million Observations on Banks Say about the Transmission of Monetary Policy?" *American Economic Review*, 90(3), 407–428. **[Revista]** | Diseño banco-mes del paso 4: la **liquidez predeterminada** de cada banco interactuada con el shock agregado identifica la respuesta diferencial del crédito. Respalda usar la cuenta corriente en el BCP / depósitos en t−12 como exposición. |
| Adler, G., Lisack, N. y Mano, R. C. (2019). "Unveiling the Effects of Foreign Exchange Intervention: A Panel Approach." *Emerging Markets Review*, 40. **[Revista]** | Muestra que la intervención FX responde a la presión cambiaria y necesita un instrumento para estimar su efecto. Respalda tratar las compras netas del BCP como **asociación condicionada** y no como shock exógeno. |

### 8.3 Aporte y límites frente a la literatura

La literatura sobre demanda de reservas es casi toda sobre la Reserva Federal y el Eurosistema, donde hay abundancia de reservas y remuneración de reservas. El aporte aquí es aplicar ese marco a un corredor con **excedentes estructurales absorbidos con IRM**, donde además las operaciones FX son una fuente importante de liquidez. No encontré un estudio publicado equivalente para Paraguay; conviene revisar los documentos de trabajo del BCP y los informes del Artículo IV del FMI, que han comentado el alineamiento entre la TIB y la TPM.
