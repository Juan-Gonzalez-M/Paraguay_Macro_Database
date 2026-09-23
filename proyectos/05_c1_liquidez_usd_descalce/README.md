# 05 · C1 — Liquidez dólar, dolarización y descalce cambiario

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 20:01:45 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

## 1. Resumen y pregunta de investigación

La posición neta y la dolarización agregada no miden ni la liquidez de liquidación en dólares de cada banco ni el riesgo del prestatario endeudado en USD. El proyecto une F2 y F11 del portafolio original en una pregunta de estabilidad financiera.

- **Pregunta:** ¿cómo amplifican la vulnerabilidad de liquidez en USD de los bancos y el descalce de los prestatarios los shocks externos y las depreciaciones, en tasas, crédito y mora?
- **Estimandos:** (i) respuesta del crédito a un shock externo × vulnerabilidad bancaria predeterminada; (ii) diferencia de mora tras una depreciación × participación del crédito en USD × cobertura natural (sector exportador).
- **Evidencia:** forma reducida a nivel banco-mes; la versión causal requiere datos de prestatario (fuera de la base).

## 2. Estrategia empírica propuesta

1. **Mapa de exposición banco-moneda (2016–2026):** por entidad y mes, activos, depósitos, crédito, fondeo externo (`sub_rubro = Externo`), disponible y capital, separados por moneda (6200/6900); indicadores de vulnerabilidad en USD: (depósitos ME − crédito ME)/activo, fondeo externo ME/pasivo ME, disponible ME/depósitos ME.
2. **Proyecciones locales banco-sector-mes:** `Δlog crédito_{b,s,t+h}` sobre `shock_t × vulnerabilidad_{b,t−12}` con efectos fijos banco-sector y sector-tiempo, h = 1–24 meses. Shocks: Fed funds, VIX y dólar amplio, tratados **por separado** y sin suponerlos exógenos (la ficha advierte que el DXY no es un shock exógeno).
3. **Mora tras depreciaciones:** diferencia en la morosidad por moneda (`Morosidad ME` vs `Morosidad MN`) y por sector (cartera vencida/total en ME) antes y después de episodios de depreciación, comparando sectores exportadores (agricultura, ganadería: cobertura natural) con no exportadores (consumo, comercio, vivienda).
4. **Robustez:** exposición congelada antes del shock; pre-tendencias; USD/PYG por separado; tratamiento de fusiones.

## 3. Series extraídas

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `dep_priv_part_me` | Participación de ME en depósitos privados (%) | `economic_annex` CUADRO 23a | mensual | 1995-03-01 | 2026-06-01 | 370 | PERCENT | Preliminar | Dolarización de depósitos (agregado) |
| `dep_priv_me_total_usd` | Depósitos privados en ME (millones de USD) | `economic_annex` CUADRO 23a | mensual | 1995-03-01 | 2026-06-01 | 370 | UNRESOLVED_SOURCE_UNITS (millones) | Preliminar | Fondeo en USD (agregado) |
| `dep_priv_mn_total` | Depósitos privados en MN (millones de Gs.) | `economic_annex` CUADRO 23a | mensual | 1995-03-01 | 2026-06-01 | 370 | PYG (millones) | Preliminar | Fondeo en PYG (agregado) |
| `cred_priv_part_me` | Participación de ME en el crédito privado (%) | `economic_annex` CUADRO 24a | mensual | 1995-03-01 | 2026-06-01 | 370 | PERCENT | Preliminar | Dolarización del crédito (agregado) |
| `cred_priv_me_usd` | Crédito privado en ME (millones de USD) | `economic_annex` CUADRO 24a | mensual | 1995-03-01 | 2026-06-01 | 370 | UNRESOLVED_SOURCE_UNITS (millones) | Preliminar | Exposición cambiaria del crédito |
| `cred_priv_mn` | Crédito privado en MN (millones de Gs.) | `economic_annex` CUADRO 24a | mensual | 1995-03-01 | 2026-06-01 | 370 | PYG (millones) | Preliminar | Crédito en PYG |
| `c31_me_pasiva_cda` | Tasa efectiva pasiva ME CDA | `economic_annex` CUADRO 31 (Cont.) | mensual | 2011-01-01 | 2026-05-01 | 185 | PERCENT | Validada por regla | Costo del fondeo en USD |
| `c31_me_pasiva_vista` | Tasa efectiva pasiva ME a la vista | `economic_annex` CUADRO 31 (Cont.) | mensual | 1994-01-01 | 2026-05-01 | 389 | PERCENT | Validada por regla | Costo del fondeo en USD |
| `c31_me_activa_prom` | Tasa efectiva activa ME promedio ponderado | `economic_annex` CUADRO 31 (Cont.) | mensual | 2011-01-01 | 2026-05-01 | 185 | PERCENT | Validada por regla | Precio del crédito en USD |
| `c31_mn_activa_prom` | Tasa efectiva activa MN promedio (sin tarjetas ni sobregiros; etiqueta contaminada) | `economic_annex` CUADRO 31 | mensual | 2011-01-01 | 2026-05-01 | 185 | PERCENT | Preliminar | Precio del crédito en PYG |
| `tpm` | Tasa de política monetaria | `economic_annex` CUADRO 19  | mensual | 2011-05-01 | 2026-07-01 | 183 | PERCENT | Preliminar | Control doméstico |
| `pyg_usd_prom_venta` | PYG por USD promedio mensual (venta) | `exchange_rates` USD Prom | mensual | 1989-01-01 | 2026-07-01 | 451 | PYG_PER_USD | Validada por regla | Depreciación (shock y conversión) |
| `tcr_multilateral` | Tipo de cambio real multilateral | `economic_annex` CUADRO 60b | mensual | 1995-01-01 | 2026-06-01 | 378 | INDEX | Validada por regla | Depreciación real |
| `pyg_brl` | PYG por BRL | `economic_annex` CUADRO 60a | mensual | 1997-01-01 | 2026-07-01 | 355 | PYG_PER_BRL | Preliminar | Shock regional |
| `rin_saldo` | Reservas internacionales netas | `economic_annex` CUADRO 56b | mensual | 2009-01-01 | 2026-08-01 | 212 | USD (millones) | Preliminar | Colchón de liquidez en USD del sistema |
| `fwd_compra_total` | Compras forward totales (volumen) | `economic_annex` CUADRO 61 | mensual | 2011-01-01 | 2026-07-01 | 187 | USD (miles) | Preliminar | Cobertura cambiaria (proxy) |
| `fwd_venta_total` | Ventas forward totales (volumen) | `economic_annex` CUADRO 61 | mensual | 2011-01-01 | 2026-07-01 | 187 | USD (miles) | Preliminar | Cobertura cambiaria (proxy) |
| `fed_rango_superior` | Fed funds: límite superior (hoja 8) | `financial_indicators` 8 | mensual | 2016-01-01 | 2026-06-01 | 126 | UNRESOLVED_SOURCE_UNITS | Preliminar | Shock externo de tasas |
| `sofr` | SOFR (hoja 8) | `financial_indicators` 8 | mensual | 2018-04-01 | 2026-06-01 | 99 | UNRESOLVED_SOURCE_UNITS | Preliminar | Costo del fondeo externo en USD |
| `selic` | Tasa Selic (hoja 8) | `financial_indicators` 8 | mensual | 2016-01-01 | 2026-06-01 | 126 | UNRESOLVED_SOURCE_UNITS | Preliminar | Shock regional |
| `soja_chicago` | Soja Chicago USD/t | `economic_annex` Cuadro 49 | mensual | 1994-01-01 | 2026-08-01 | 392 | USD_PER_TONNE | Preliminar | Shock a ingresos de exportadores (cobertura natural) |
| `carne_chicago` | Carne Chicago USD/t | `economic_annex` Cuadro 49 | mensual | 1994-01-01 | 2026-08-01 | 392 | USD_PER_TONNE | Preliminar | Shock a ingresos de exportadores |
| `expo_registradas` | Exportaciones registradas totales | `economic_annex` Cuadro 46a | mensual | 1994-01-01 | 2026-07-01 | 391 | USD (miles) | Validada por regla | Ingresos en USD de la economía |
| `vix_m` | FRED: VIX promedio mensual | `FRED` VIXCLS | mensual | 1990-01-01 | 2026-08-01 | 440 | INDEX_POINTS | Externa (FRED), no verificada en la base | Shock global de riesgo |
| `dolar_amplio_m` | FRED: índice nominal amplio del dólar | `FRED` TWEXBGSMTH | mensual | 2006-01-01 | 2026-08-01 | 248 | INDEX | Externa (FRED), no verificada en la base | Shock global de dólar (no exógeno; ver ficha) |
| `fed_funds_efectiva` | FRED: tasa efectiva de fondos federales | `FRED` FEDFUNDS | mensual | 1954-07-01 | 2026-08-01 | 866 | PERCENT | Externa (FRED), no verificada en la base | Shock externo de tasas (historia larga) |
| `ust_2a` | FRED: rendimiento Tesoro EE.UU. 2 años (promedio mensual) | `FRED` DGS2 | mensual | 1976-06-01 | 2026-08-01 | 603 | PERCENT | Externa (FRED), no verificada en la base | Shock externo de tasas |
| `tef_bancos_1_2_*` | 37 series: financial_indicators hoja 1.2 (detalle en diccionario_series.csv) | `financial_indicators` 1.2 | mensual | 2011-01-01 | 2026-06-01 | 5.888 | PERCENT | Preliminar (37) | Tasas efectivas por producto y moneda (bancos; promedio del sistema) |

### Paneles por entidad

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `panel_eeff_entidad_mes.csv` | Estados financieros completos por entidad × mes × sub-rubro × moneda; `importe_pyg` en **millones de Gs.** (los saldos 6200 son ME convertidos a PYG) | 2016-01-01 a 2026-07-01, 332.745 filas | Panel provisional |
| `panel_carteras_entidad_mes.csv` | Cartera vigente/vencida/renovada/refinanciada/reestructurada y depósitos por tipo, por moneda | 2016-01-01 a 2026-07-01, 75.618 filas | Panel provisional |
| `panel_credito_sector_entidad_mes.csv` | Cartera vigente y vencida por 13 sectores × moneda | 2016-01-01 a 2026-07-01, 66.073 filas | Panel provisional |
| `panel_credito_actividad_entidad_mes.csv` | Cartera vigente y vencida × moneda para 4 cultivos: soja, arroz, trigo y algodón | 2016-01-01 a 2026-07-01, 13.021 filas | Panel provisional |
| `panel_categoria_riesgo_entidad_mes.csv` | Cartera por categoría de riesgo (1, 1a, 1b, 2 a 6) | 2016-01-01 a 2026-07-01, 23.049 filas | Panel provisional |
| `panel_ratios_entidad_mes.csv` | 40 ratios publicados (morosidad MN y ME, capital, liquidez, rentabilidad) | 2016-01-01 a 2026-07-01, 132.025 filas | Panel provisional |
| `entidades.csv` | `entity_id` → nombre, razón social, propiedad (nacional/extranjera). En los paneles "raw", `codigo_entidad` = número de `entity_id` | 29 entidades | Referencia |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_mensual.csv` | 14.688 | 11 | 1954-07-01 | 2026-08-01 |
| `datos/series_mensual_ancho.csv` | 866 | 65 | 1954-07-01 | 2026-08-01 |
| `datos/diccionario_series.csv` | 64 | 13 | 1954-07-01 | 2018-04-01 |
| `datos/panel_eeff_entidad_mes.csv` | 332.745 | 13 | 2016-01-01 | 2026-07-01 |
| `datos/panel_carteras_entidad_mes.csv` | 75.618 | 8 | 2016-01-01 | 2026-07-01 |
| `datos/panel_credito_sector_entidad_mes.csv` | 66.073 | 9 | 2016-01-01 | 2026-07-01 |
| `datos/panel_credito_actividad_entidad_mes.csv` | 13.021 | 9 | 2016-01-01 | 2026-07-01 |
| `datos/panel_categoria_riesgo_entidad_mes.csv` | 23.049 | 7 | 2016-01-01 | 2026-07-01 |
| `datos/panel_ratios_entidad_mes.csv` | 132.025 | 7 | 2016-01-01 | 2026-07-01 |
| `datos/entidades.csv` | 29 | 4 | — | — |

## 4. Cómo se usarían los datos

- **Moneda:** nunca sumar 6200 y 6900 sin decidir la unidad. Para exposición en USD, convertir los saldos 6200 a USD con el tipo de cambio de **fin de mes** (no el promedio `pyg_usd_prom_venta`; obtener el de fin de mes del TCN diario, carpeta 03). Así se separa la variación por valuación de la variación por flujo.
- **Crecimiento del crédito:** `Δlog` de saldos en moneda de origen (USD para ME, PYG para MN).
- **Mora:** cartera vencida/(vigente + vencida) por sector y moneda; comparar con los ratios publicados `Morosidad ME/MN` como control de consistencia.
- **Exposición predeterminada:** congelar las participaciones en t−12 (o en diciembre del año previo al shock).
- **Shocks:** mensuales; VIX y UST en promedio del mes; Fed funds en nivel y variación.
- **Deflactación:** PYG por IPC solo en comparaciones de niveles de largo plazo.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Liquidez en USD por plazo residual (activos y pasivos ME por banda de vencimiento) | Nivel "ideal": liquidez de liquidación | SIB – reportes de calce de plazos y monedas |
| Originaciones (crédito nuevo) y tasas por banco-moneda-sector | Separar stock de flujo y precio | SIB / Central de riesgos |
| Moneda de ingreso del prestatario, condición de exportador | Cobertura natural (estimando ii) | Central de riesgos + DNA/aduanas (vínculo anonimizado empresa-banco) |
| Fondeo externo detallado (líneas de corresponsales, vencimientos) | Vulnerabilidad de refinanciamiento en USD | SIB; BCP – deuda externa privada |
| Posición de cambios por banco (diaria) | Descalce del propio banco | BCP – Operaciones Cambiarias |
| Fusiones y adquisiciones de entidades 2016–2026 | Panel balanceado | SIB – registro de entidades |

## 6. Evaluación de viabilidad

**Media.** El panel banco × moneda × sector (nivel "mínimo" completo: activos, depósitos, crédito, capital y mora por moneda) existe desde 2016 con 29 entidades, y los shocks externos se incorporaron desde FRED. No hay plazo residual, originaciones ni datos del prestatario, así que el estimando de descalce del prestatario solo se aproxima por sector.

## 7. Supuestos que debes revisar

1. **Unidad del panel EEFF:** millones de Gs. Lo verifiqué por magnitud: el crédito al sector no financiero en MN del panel (≈ 103 billones de Gs., 2026-07) es consistente con el crédito privado en MN del Cuadro 24a (≈ 110 billones, 2026-06).
2. **Fondeo externo** = sub-rubro `Externo` del pasivo ("Otras entidades"); no está validado que capture todo el endeudamiento externo (p. ej. bonos emitidos en el exterior).
3. **Sector exportador** = agricultura y ganadería del panel por sector; es una aproximación a la cobertura natural.
4. El panel por actividad cubre solo 4 cultivos, que es lo que trae el boletín actual; no es la clasificación completa de 1.112 actividades de la tabla de referencia.
5. Las tasas externas de la hoja 8 (Fed, SOFR, Selic) figuran con unidad no resuelta; las leo como % anual.
6. Paneles completos sin filtrar, como acordamos para C1.

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Fondeo en dólares de los bancos y shocks externos

| Referencia | Qué respalda en este proyecto |
|---|---|
| Ivashina, V., Scharfstein, D. S. y Stein, J. C. (2015). "Dollar Funding and the Lending Behavior of Global Banks." *Quarterly Journal of Economics*, 130(3), 1241–1281. **[Revista]** | Los bancos con fondeo en USD más frágil recortan más el crédito en USD ante tensiones de fondeo. Respalda la **vulnerabilidad de liquidez en USD por banco** del paso 1 (fondeo externo, disponible en ME / depósitos en ME). |
| Bruno, V. y Shin, H. S. (2015). "Cross-Border Banking and Global Liquidity." *Review of Economic Studies*, 82(2), 535–564. **[Revista]** | El fondeo bancario transfronterizo transmite las condiciones financieras globales. Respalda el fondeo externo y el VIX/dólar como shocks. |
| Bräuning, F. e Ivashina, V. (2020). "U.S. Monetary Policy and Emerging Market Credit Cycles." *Journal of Monetary Economics*, 112, 57–76. **[Revista]** | Efecto de la política de la Fed en el crédito a economías emergentes. Respalda los Fed funds como shock separado. |
| Rey, H. (2013). "Dilemma not Trilemma: The Global Financial Cycle and Monetary Policy Independence." *Jackson Hole Economic Policy Symposium*, Federal Reserve Bank of Kansas City. **[Conferencia]** | Ciclo financiero global medido con el VIX. Justifica el VIX como variable de estado, con la advertencia de la ficha sobre su exogeneidad. |

### 8.2 Descalce de prestatarios y depreciaciones

| Referencia | Qué respalda |
|---|---|
| Bleakley, H. y Cowan, K. (2008). "Corporate Dollar Debt and Depreciations: Much Ado About Nothing?" *Review of Economics and Statistics*, 90(4), 612–626. **[Revista]** | Con datos de firmas de cinco países latinoamericanos, las empresas endeudadas en USD tienden a tener ingresos sensibles al tipo de cambio (**cobertura natural**) y no invierten menos tras una depreciación. Respalda comparar sectores exportadores (agro) con no exportadores en el paso 3. |
| Aguiar, M. (2005). "Investment, Devaluation, and Foreign Currency Exposure: The Case of Mexico." *Journal of Development Economics*, 78(1), 95–113. **[Revista]** | Efecto de hoja de balance negativo en México 1994–95. Contraste con Bleakley y Cowan: el signo es empírico. |
| Galindo, A., Panizza, U. y Schiantarelli, F. (2003). "Debt Composition and Balance Sheet Effects of Currency Depreciation: A Summary of the Micro Evidence." *Emerging Markets Review*, 4(4), 330–339. **[Revista]** | Síntesis de la evidencia microeconómica en América Latina. |
| Kalemli-Özcan, Ş., Kamil, H. y Villegas-Sanchez, C. (2016). "What Hinders Investment in the Aftermath of Financial Crises: Insolvent Firms or Illiquid Banks?" *Review of Economics and Statistics*, 98(4), 756–769. **[Revista]** | Combina el descalce de firmas con la liquidez bancaria en crisis latinoamericanas. Es la **versión causal** a la que apunta el proyecto con datos de prestatario. |

### 8.3 Métodos

- Jordà (2005, *AER*) para las proyecciones locales, y Khwaja y Mian (2008, *AER*) y Kashyap y Stein (2000, *AER*) para la exposición bancaria predeterminada × shock agregado con efectos fijos sector-tiempo (ver las referencias completas en la carpeta 06).

### 8.4 Antecedentes para Paraguay

- **[PY]** Banco Central del Paraguay (2017). Informe de Política Monetaria, junio 2017, Recuadro I, "Dolarización financiera en Paraguay".
- **[PY]** Moreno Mareco, J. A. (2026). "Desdolarización del sistema financiero paraguayo: análisis de la evolución 1995–2024." *Economía & Negocios*, 8(1). **[Revista regional]** Descriptivo: la participación del guaraní en depósitos y créditos, el máximo de dolarización en 2002 y la recuperación parcial desde las metas de inflación.

Ninguno de los dos trabaja a nivel banco ni con descalce de prestatarios; ese es el aporte del proyecto.
