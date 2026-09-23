# 06 · C2 — Depósitos, crédito y sustitución entre intermediarios

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 18:58:06 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

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

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `tpm` | Tasa de política monetaria (etiqueta contaminada en la base) | `economic_annex` CUADRO 19  | mensual | 2011-05-01 | 2026-07-01 | 183 | PERCENT | Preliminar | Tratamiento: política monetaria |
| `eve_tpm_mes` | EVE (mediana): TPM esperada para el mes | `eve` NA | mensual | 2014-06-01 | 2026-08-01 | 147 | PROPORTION | Preliminar | Sorpresa de política (TPM − esperada) |
| `eve_tpm_prox_mes` | EVE (mediana): TPM esperada para el próximo mes | `eve` NA | mensual | 2014-06-01 | 2026-08-01 | 147 | PROPORTION | Preliminar | Sorpresa de política |
| `ipc_var_interanual` | Inflación total interanual | `economic_annex` CUADRO 15 | mensual | 1993-12-01 | 2026-07-01 | 392 | PERCENT | Validada por regla | Control / tasas reales |
| `c31_mn_pasiva_vista` | Tasa efectiva pasiva MN a la vista (etiqueta contaminada) | `economic_annex` CUADRO 31 | mensual | 1994-01-01 | 2026-05-01 | 389 | PERCENT | Preliminar | Precio del fondeo MN |
| `c31_mn_pasiva_plazo` | Tasa efectiva pasiva MN a plazo (etiqueta contaminada) | `economic_annex` CUADRO 31 | mensual | 2011-01-01 | 2026-05-01 | 185 | PERCENT | Preliminar | Precio del fondeo MN |
| `c31_mn_pasiva_cda` | Tasa efectiva pasiva MN CDA (etiqueta contaminada) | `economic_annex` CUADRO 31 | mensual | 2011-01-01 | 2026-05-01 | 185 | PERCENT | Preliminar | Precio del fondeo MN |
| `c31_mn_pasiva_prom` | Tasa efectiva pasiva MN promedio ponderado (etiqueta contaminada) | `economic_annex` CUADRO 31 | mensual | 2011-01-01 | 2026-05-01 | 185 | PERCENT | Preliminar | Precio del fondeo MN |
| `c31_mn_activa_prom` | Tasa efectiva activa MN promedio ponderado sin tarjetas ni sobregiros (etiqueta contaminada) | `economic_annex` CUADRO 31 | mensual | 2011-01-01 | 2026-05-01 | 185 | PERCENT | Preliminar | Precio del crédito MN |
| `c31_me_pasiva_vista` | Tasa efectiva pasiva ME a la vista | `economic_annex` CUADRO 31 (Cont.) | mensual | 1994-01-01 | 2026-05-01 | 389 | PERCENT | Validada por regla | Precio del fondeo ME |
| `c31_me_pasiva_plazo` | Tasa efectiva pasiva ME a plazo | `economic_annex` CUADRO 31 (Cont.) | mensual | 2011-01-01 | 2026-05-01 | 185 | PERCENT | Validada por regla | Precio del fondeo ME |
| `c31_me_pasiva_cda` | Tasa efectiva pasiva ME CDA | `economic_annex` CUADRO 31 (Cont.) | mensual | 2011-01-01 | 2026-05-01 | 185 | PERCENT | Validada por regla | Precio del fondeo ME |
| `c31_me_activa_prom` | Tasa efectiva activa ME promedio ponderado | `economic_annex` CUADRO 31 (Cont.) | mensual | 2011-01-01 | 2026-05-01 | 185 | PERCENT | Validada por regla | Precio del crédito ME |
| `dep_priv_mn_ctacte` | Depósitos del sector privado MN: cuenta corriente | `economic_annex` CUADRO 23a | mensual | 1995-03-01 | 2026-06-01 | 370 | PYG (millones) | Preliminar | Cantidad de fondeo MN |
| `dep_priv_mn_vista` | Depósitos del sector privado MN: ahorro a la vista | `economic_annex` CUADRO 23a | mensual | 1995-03-01 | 2026-06-01 | 370 | PYG (millones) | Preliminar | Cantidad de fondeo MN |
| `dep_priv_mn_plazo` | Depósitos del sector privado MN: ahorro a plazo | `economic_annex` CUADRO 23a | mensual | 1995-03-01 | 2026-06-01 | 370 | PYG (millones) | Preliminar | Cantidad de fondeo MN |
| `dep_priv_mn_cds` | Depósitos del sector privado MN: CDs | `economic_annex` CUADRO 23a | mensual | 1995-03-01 | 2026-06-01 | 370 | PYG (millones) | Preliminar | Cantidad de fondeo MN |
| `dep_priv_mn_total` | Depósitos del sector privado MN: total | `economic_annex` CUADRO 23a | mensual | 1995-03-01 | 2026-06-01 | 370 | PYG (millones) | Preliminar | Cantidad de fondeo MN |
| `dep_priv_me_ctacte` | Depósitos del sector privado ME: cuenta corriente (millones de Gs.) | `economic_annex` CUADRO 23a | mensual | 1995-03-01 | 2026-06-01 | 370 | UNRESOLVED_SOURCE_UNITS (millones) | Preliminar | Cantidad de fondeo ME |
| `dep_priv_me_vista` | Depósitos del sector privado ME: ahorro a la vista (millones de Gs.) | `economic_annex` CUADRO 23a | mensual | 1995-03-01 | 2026-06-01 | 370 | UNRESOLVED_SOURCE_UNITS (millones) | Preliminar | Cantidad de fondeo ME |
| `dep_priv_me_plazo` | Depósitos del sector privado ME: ahorro a plazo (millones de Gs.) | `economic_annex` CUADRO 23a | mensual | 1995-03-01 | 2026-06-01 | 370 | UNRESOLVED_SOURCE_UNITS (millones) | Preliminar | Cantidad de fondeo ME |
| `dep_priv_me_cds` | Depósitos del sector privado ME: CDs (millones de Gs.) | `economic_annex` CUADRO 23a | mensual | 1995-03-01 | 2026-06-01 | 370 | UNRESOLVED_SOURCE_UNITS (millones) | Preliminar | Cantidad de fondeo ME |
| `dep_priv_me_total` | Depósitos del sector privado ME: total (millones de Gs.) | `economic_annex` CUADRO 23a | mensual | 1995-03-01 | 2026-06-01 | 370 | UNRESOLVED_SOURCE_UNITS (millones) | Preliminar | Cantidad de fondeo ME |
| `dep_priv_me_total_usd` | Depósitos del sector privado ME: total en millones de USD | `economic_annex` CUADRO 23a | mensual | 1995-03-01 | 2026-06-01 | 370 | UNRESOLVED_SOURCE_UNITS (millones) | Preliminar | Cantidad de fondeo ME |
| `dep_priv_tc` | Tipo de cambio usado en el Cuadro 23a | `economic_annex` CUADRO 23a | mensual | 1995-03-01 | 2026-06-01 | 370 | PYG_PER_USD (millones) | Preliminar | Conversión |
| `dep_priv_part_me` | Participación de ME en depósitos privados (%) | `economic_annex` CUADRO 23a | mensual | 1995-03-01 | 2026-06-01 | 370 | PERCENT | Preliminar | Dolarización de depósitos |
| `cred_priv_mn` | Crédito de bancos y financieras al sector privado MN | `economic_annex` CUADRO 24a | mensual | 1995-03-01 | 2026-06-01 | 370 | PYG (millones) | Preliminar | Resultado: crédito |
| `cred_priv_me` | Crédito al sector privado ME (millones de Gs.) | `economic_annex` CUADRO 24a | mensual | 1995-03-01 | 2026-06-01 | 370 | UNRESOLVED_SOURCE_UNITS (millones) | Preliminar | Resultado: crédito |
| `cred_priv_me_usd` | Crédito al sector privado ME en millones de USD | `economic_annex` CUADRO 24a | mensual | 1995-03-01 | 2026-06-01 | 370 | UNRESOLVED_SOURCE_UNITS (millones) | Preliminar | Resultado: crédito |
| `cred_priv_total` | Crédito al sector privado total | `economic_annex` CUADRO 24a | mensual | 1995-03-01 | 2026-06-01 | 370 | PYG (millones) | Preliminar | Resultado: crédito |
| `cred_priv_part_me` | Participación de ME en el crédito privado (%) | `economic_annex` CUADRO 24a | mensual | 1995-03-01 | 2026-06-01 | 370 | PERCENT | Preliminar | Dolarización del crédito |
| `coop_dep_mn` | Cooperativas Tipo A: depósitos MN (millones de Gs.) | `economic_annex` CUADRO 23b | mensual | 2017-12-01 | 2025-11-01 | 96 | PYG (millones) | Preliminar | Sustitución hacia cooperativas |
| `coop_dep_me` | Cooperativas Tipo A: depósitos ME (millones de Gs.; la base agrega '%' a la etiqueta por error) | `economic_annex` CUADRO 23b | mensual | 2017-12-01 | 2025-11-01 | 96 | PERCENT | Preliminar | Sustitución hacia cooperativas |
| `coop_dep_total` | Cooperativas Tipo A: depósitos totales (millones de Gs.; la base agrega '%' a la etiqueta por error) | `economic_annex` CUADRO 23b | mensual | 2017-12-01 | 2025-11-01 | 96 | PERCENT | Preliminar | Sustitución hacia cooperativas |
| `coop_cred_mn` | Cooperativas Tipo A: créditos MN (millones de Gs.) | `economic_annex` CUADRO 24b | mensual | 2017-12-01 | 2025-11-01 | 96 | PYG (millones) | Preliminar | Sustitución hacia cooperativas |
| `coop_cred_me` | Cooperativas Tipo A: créditos ME (millones de Gs.; la base agrega '%' a la etiqueta por error) | `economic_annex` CUADRO 24b | mensual | 2017-12-01 | 2025-11-01 | 96 | PERCENT | Preliminar | Sustitución hacia cooperativas |
| `coop_cred_total` | Cooperativas Tipo A: créditos totales (millones de Gs.; la base agrega '%' a la etiqueta por error) | `economic_annex` CUADRO 24b | mensual | 2017-12-01 | 2025-11-01 | 96 | PERCENT | Preliminar | Sustitución hacia cooperativas |
| `bancariz_cuentas_total` | Cantidad total de cuentas de depósito | `banking_indicators` 4 | mensual | 2016-01-01 | 2026-06-01 | 126 | COUNT | Preliminar | Base de depositantes |
| `bancariz_personas_total` | Personas con cuentas de depósito | `banking_indicators` 4 | mensual | 2016-01-01 | 2026-06-01 | 126 | UNRESOLVED_SOURCE_UNITS | Preliminar | Base de depositantes |
| `bancariz_cuentas_cda` | Cantidad de cuentas a plazo (CDA) | `banking_indicators` 6 | mensual | 2016-01-01 | 2026-06-01 | 126 | UNRESOLVED_SOURCE_UNITS | Preliminar | Base de depositantes |
| `bancariz_cuentas_vista` | Cantidad de cuentas a la vista | `banking_indicators` 6 | mensual | 2016-01-01 | 2026-06-01 | 126 | UNRESOLVED_SOURCE_UNITS | Preliminar | Base de depositantes |
| `tef_bancos_1_2_*` | 37 series: financial_indicators hoja 1.2 (detalle en diccionario_series.csv) | `financial_indicators` 1.2 | mensual | 2011-01-01 | 2026-06-01 | 5.888 | PERCENT | Preliminar (37) | Precio por producto y moneda (bancos; promedio del sistema) |
| `tef_plazo_bancos_2_2_*` | 58 series: financial_indicators hoja 2.2 (detalle en diccionario_series.csv) | `financial_indicators` 2.2 | mensual | 2011-01-01 | 2026-06-01 | 8.348 | PERCENT | Preliminar (58) | Precio por producto, plazo y moneda (bancos) |
| `saldos_bancos_4_*` | 94 series: financial_indicators hoja 4 (detalle en diccionario_series.csv) | `financial_indicators` 4 | mensual | 2011-01-01 | 2026-06-01 | 17.484 | UNRESOLVED_SOURCE_UNITS/PYG | Preliminar (94) | Cantidades por producto y plazo (bancos) |
| `tef_financieras_5_*` | 28 series: financial_indicators hoja 5 (detalle en diccionario_series.csv) | `financial_indicators` 5 | mensual | 2011-01-01 | 2026-06-01 | 4.427 | PERCENT | No comprobada (2); Preliminar (26) | Precio por producto y moneda (financieras) |
| `tef_plazo_financieras_6_*` | 49 series: financial_indicators hoja 6 (detalle en diccionario_series.csv) | `financial_indicators` 6 | mensual | 2011-01-01 | 2026-06-01 | 5.009 | PERCENT | No comprobada (3); Preliminar (46) | Precio por producto y plazo (financieras) |
| `saldos_financieras_7_*` | 94 series: financial_indicators hoja 7 (detalle en diccionario_series.csv) | `financial_indicators` 7 | mensual | 2011-01-01 | 2026-06-01 | 17.425 | UNRESOLVED_SOURCE_UNITS/PYG | Preliminar (94) | Cantidades por producto y plazo (financieras) |

### Paneles y curvas

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `curvas_cda_mensual.csv` | Curva de CDA: tasa ponderada, cantidad de operaciones y volumen captado por plazo (30 días a 8 años), moneda y tipo de entidad; hojas mensuales `CDA_ML_mmaaaa`, `CDA_ME_mmaaaa`, `OPERACIONES_VOLUMEN_*` | 2018-01-01 a 2026-07-01, 21.839 filas | Estructura especial |
| `panel_eeff_entidad_mes.csv` | Estados financieros completos: 98 sub-rubros × moneda (6900 PYG / 6200 ME en PYG) × entidad | 2016-01-01 a 2026-07-01, 332.745 filas | Panel provisional |
| `panel_carteras_entidad_mes.csv` | Cartera vigente, vencida, renovada, refinanciada, reestructurada; depósitos a la vista, plazo fijo, CDA, cuenta corriente | 2016-01-01 a 2026-07-01, 75.618 filas | Panel provisional |
| `panel_credito_sector_entidad_mes.csv` | Cartera vigente y vencida por 13 sectores y moneda | 2016-01-01 a 2026-07-01, 66.073 filas | Panel provisional |
| `panel_ratios_entidad_mes.csv` | 40 ratios publicados por entidad (liquidez, morosidad, capital, rentabilidad, eficiencia) | 2016-01-01 a 2026-07-01, 132.025 filas | Panel provisional |
| `entidades.csv` | Correspondencia `entity_id` → nombre, razón social y tipo de propiedad. En los paneles "raw" `codigo_entidad` = número de `entity_id` sin el prefijo `bank:`/`finance:` | 29 entidades | Referencia |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_mensual.csv` | 69.263 | 11 | 1993-12-01 | 2026-08-01 |
| `datos/series_mensual_ancho.csv` | 393 | 402 | 1993-12-01 | 2026-08-01 |
| `datos/diccionario_series.csv` | 401 | 13 | 1993-12-01 | 2020-08-01 |
| `datos/curvas_cda_mensual.csv` | 21.839 | 8 | 2018-01-01 | 2026-07-01 |
| `datos/panel_eeff_entidad_mes.csv` | 332.745 | 13 | 2016-01-01 | 2026-07-01 |
| `datos/panel_carteras_entidad_mes.csv` | 75.618 | 8 | 2016-01-01 | 2026-07-01 |
| `datos/panel_credito_sector_entidad_mes.csv` | 66.073 | 9 | 2016-01-01 | 2026-07-01 |
| `datos/panel_ratios_entidad_mes.csv` | 132.025 | 7 | 2016-01-01 | 2026-07-01 |
| `datos/entidades.csv` | 29 | 4 |  |  |

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
