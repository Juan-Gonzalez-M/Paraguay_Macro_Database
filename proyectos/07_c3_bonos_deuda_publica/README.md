# 07 · C3 — Bonos corporativos, crédito bancario y deuda pública

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 20:01:57 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

## 1. Resumen y pregunta de investigación

Los spreads de bonos y los de préstamos no son comparables sin ajustar por riesgo, plazo, moneda y liquidez, y las subastas del Tesoro pueden mover los rendimientos por la capacidad de los intermediarios. La ficha pide **dos módulos separados** hasta que existan datos de tenencias:

- **Módulo A — bono vs. banca:** ¿cuál es el spread de financiamiento bono−banco ajustado (por calificación, moneda y plazo) y cómo responde a las condiciones monetarias? Estimando: spread hedónico/emparejado.
- **Módulo B — deuda pública:** ¿cuál es la elasticidad de los rendimientos a una oferta inesperada del Tesoro? Estimando: pendiente de demanda por instrumento.
- **Evidencia:** descriptiva y de forma reducida; causal solo con sorpresas de oferta bien fechadas.

## 2. Estrategia empírica propuesta

**Módulo A (viable con estos datos)**
1. **Curvas comparables:** tasas cero de las curvas NSS por calificación (AAA–B) y moneda en plazos fijos (1, 3, 5 años), frente a la tasa bancaria de plazo equivalente por moneda (`tef_plazo_bancos_*`, préstamos > 1 año) y a la curva CDA (costo de fondeo bancario).
2. **Spread emparejado:** `spread_{r,m,τ,t} = tasa_bono − tasa_préstamo` por calificación r, moneda m y plazo τ; panel mensual 2011–2026.
3. **Respuesta a la política monetaria:** proyecciones locales del spread y de la pendiente de la curva ante cambios de TPM (y sorpresas `tpm − eve_tpm`), separando PYG y USD; en USD, controlar por `ust_10a`.
4. **Emisores:** con `transacciones_deuda_bva.csv` (emisor, ISIN, mercado primario/secundario) construir un *security master* mínimo y un panel instrumento-mes con efectos fijos de emisor.

**Módulo B (limitado)**
5. **Tablero de oferta pública:** financiamiento interno y externo mensual de la Administración Central, stock de deuda externa y negociaciones de Bonos del Tesoro en la BVA (desde 2023); subastas de LRM del BCP como caso análogo, con montos anunciados, ofertados y adjudicados.
6. **Event study de subastas de LRM:** tasa adjudicada vs. monto ofertado/anunciado (bid-to-cover) y efecto sobre el mercado secundario de LRM.

## 3. Series extraídas

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `tpm` | Tasa de política monetaria | `economic_annex` CUADRO 19  | mensual | 2011-05-01 | 2026-07-01 | 183 | PERCENT | Preliminar | Condición monetaria (explicativa) |
| `c31_mn_activa_prom` | Tasa efectiva activa MN promedio (sin tarjetas ni sobregiros; etiqueta contaminada) | `economic_annex` CUADRO 31 | mensual | 2011-01-01 | 2026-05-01 | 185 | PERCENT | Preliminar | Tasa bancaria de referencia MN |
| `c31_me_activa_prom` | Tasa efectiva activa ME promedio ponderado | `economic_annex` CUADRO 31 (Cont.) | mensual | 2011-01-01 | 2026-05-01 | 185 | PERCENT | Validada por regla | Tasa bancaria de referencia ME |
| `c31_me_pasiva_cda` | Tasa efectiva pasiva ME CDA | `economic_annex` CUADRO 31 (Cont.) | mensual | 2011-01-01 | 2026-05-01 | 185 | PERCENT | Validada por regla | Costo de fondeo bancario ME |
| `deuda_ext_saldo` | Deuda pública externa: saldo (miles de USD) | `economic_annex` CUADRO 59 | mensual | 1994-01-01 | 2026-05-01 | 389 | USD (miles) | Preliminar | Oferta de deuda pública (stock) |
| `deuda_ext_desembolsos` | Deuda pública externa: desembolsos | `economic_annex` CUADRO 59 | mensual | 1994-01-01 | 2026-05-01 | 389 | USD (miles) | Preliminar | Oferta de deuda pública (flujo) |
| `deuda_ext_servicio` | Deuda pública externa: pagos de capital e intereses | `economic_annex` CUADRO 59 | mensual | 1994-01-01 | 2026-05-01 | 389 | USD (miles) | Preliminar | Servicio de deuda |
| `fiscal_financiamiento_neto` | Administración Central: incurrimiento neto de pasivos | `mef_central_government` Serie | mensual | 2003-01-01 | 2026-08-01 | 284 | PYG (miles de millones) | Preliminar | Necesidad de financiamiento del Tesoro |
| `fiscal_financiamiento_interno` | Administración Central: financiamiento interno (incurrimiento de pasivos) | `mef_central_government` Serie | mensual | 2003-01-01 | 2026-08-01 | 284 | PYG (miles de millones) | Preliminar | Oferta local de deuda pública |
| `fiscal_financiamiento_externo` | Administración Central: financiamiento externo | `mef_central_government` Serie | mensual | 2003-01-01 | 2026-08-01 | 284 | PYG (miles de millones) | Preliminar | Oferta externa de deuda pública |
| `fiscal_intereses` | Administración Central: gasto en intereses | `mef_central_government` Serie | mensual | 2003-01-01 | 2026-08-01 | 284 | PYG (miles de millones) | Preliminar | Costo de la deuda |
| `fiscal_balance` | Administración Central: préstamo neto / endeudamiento neto | `mef_central_government` Serie | mensual | 2003-01-01 | 2026-08-01 | 284 | PYG (miles de millones) | Preliminar | Necesidad de financiamiento |
| `bva_total_operacion` | Bolsa de Valores: total operado (millones de Gs.; etiqueta contaminada) | `economic_annex` CUADRO 32 | mensual | 1994-01-01 | 2026-05-01 | 389 | PYG (millones) | Preliminar | Liquidez del mercado |
| `bva_bonos` | Bolsa de Valores: bonos en PYG (etiqueta contaminada) | `economic_annex` CUADRO 32 | mensual | 1994-01-01 | 2026-05-01 | 389 | PYG (millones) | Preliminar | Liquidez del mercado de bonos |
| `bva_bonos_usd` | Bolsa de Valores: bonos en USD (etiqueta contaminada) | `economic_annex` CUADRO 32 | mensual | 1994-01-01 | 2026-05-01 | 389 | USD (millones) | Preliminar | Liquidez del mercado de bonos |
| `bva_custodia_total` | Documentos en custodia: total (millones de Gs.) | `economic_annex` CUADRO 32 A | mensual | 2013-01-01 | 2026-06-01 | 162 | PYG | Preliminar | Stock del mercado |
| `bva_custodia_bono` | Documentos en custodia: bonos | `economic_annex` CUADRO 32 A | mensual | 2013-01-01 | 2026-06-01 | 162 | PYG | Preliminar | Stock de bonos |
| `bva_custodia_bono_financiero` | Documentos en custodia: bonos financieros | `economic_annex` CUADRO 32 A | mensual | 2013-01-01 | 2026-06-01 | 162 | PYG | Preliminar | Stock de bonos bancarios |
| `bva_custodia_bono_subordinado` | Documentos en custodia: bonos subordinados | `economic_annex` CUADRO 32 A | mensual | 2013-01-01 | 2026-06-01 | 162 | PYG | Preliminar | Stock de bonos bancarios |
| `bva_custodia_bbcp` | Documentos en custodia: bonos del BCP | `economic_annex` CUADRO 32 A | mensual | 2013-01-01 | 2026-06-01 | 162 | PYG | Preliminar | Stock de papeles del BCP |
| `pyg_usd_prom_venta` | PYG por USD promedio mensual | `exchange_rates` USD Prom | mensual | 1989-01-01 | 2026-07-01 | 451 | PYG_PER_USD | Validada por regla | Conversión |
| `ipc_var_interanual` | Inflación total interanual | `economic_annex` CUADRO 15 | mensual | 1993-12-01 | 2026-07-01 | 392 | PERCENT | Validada por regla | Tasas reales |
| `eve_tpm_anio_t` | EVE (mediana): TPM esperada fin de año | `eve` NA | mensual | 2014-06-01 | 2026-08-01 | 147 | PROPORTION | Preliminar | Trayectoria esperada de tasas |
| `ust_10a` | FRED: rendimiento Tesoro EE.UU. 10 años (promedio mensual) | `FRED` DGS10 | mensual | 1962-01-01 | 2026-08-01 | 776 | PERCENT | Externa (FRED), no verificada en la base | Tasa libre de riesgo global (bonos en USD) |
| `ust_2a` | FRED: rendimiento Tesoro EE.UU. 2 años (promedio mensual) | `FRED` DGS2 | mensual | 1976-06-01 | 2026-08-01 | 603 | PERCENT | Externa (FRED), no verificada en la base | Tasa libre de riesgo global |
| `tef_plazo_bancos_2_2_*` | 58 series: financial_indicators hoja 2.2 (detalle en diccionario_series.csv) | `financial_indicators` 2.2 | mensual | 2011-01-01 | 2026-06-01 | 8.348 | PERCENT | Preliminar (58) | Tasa bancaria por producto, plazo y moneda (comparación con bonos) |

### Curvas, transacciones y eventos

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `curvas_bonos_corporativos.csv` | Curvas Nelson-Siegel-Svensson de bonos corporativos: fecha de estimación, moneda (PYG, USD), calificación (AAA a B), plazo (años), tasa cero, tasa par, factor de descuento y parámetros β0–β3, λ1–λ2 | 2010-11-01 a 2026-07-31, 38.922 filas | Validada por regla (estructural) |
| `curvas_cda_mensual.csv` | Curva de CDA por plazo y moneda: tasa ponderada, volumen y cantidad de operaciones (bancos y financieras) | 2018-01-01 a 2026-07-01, 21.839 filas | Estructura especial |
| `transacciones_deuda_bva.csv` | Operaciones de la BVA en bonos corporativos, subordinados, financieros, del Tesoro, municipales, BBCP, LRM y CDA: fecha, mercado (primario, secundario, repo), moneda, volumen, ISIN, emisor, casa de bolsa | 2010-05-17 a 2026-08-19, 286.174 filas | Validada por regla (estructural) |
| `eventos_mercado_secundario_lrm_bonos.csv` | Operaciones del mercado secundario de LRM y bonos (tasa, monto, plazo residual) | 2012-03-09 a 2026-08-14, 2.037 filas | Estructura especial |
| `eventos_subastas_lrm.csv` | Subastas de LRM: monto anunciado/ofertado/asignado, tasas mín./prom./máx. ofertadas y asignadas, posturas, plazo | 2013-01-08 a 2026-07-30, 10.334 filas | Estructura especial |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_mensual.csv` | 16.019 | 11 | 1962-01-01 | 2026-08-01 |
| `datos/series_mensual_ancho.csv` | 776 | 84 | 1962-01-01 | 2026-08-01 |
| `datos/diccionario_series.csv` | 83 | 13 | 1962-01-01 | 2016-03-01 |
| `datos/curvas_bonos_corporativos.csv` | 38.922 | 16 | 2010-11-01 | 2026-07-31 |
| `datos/curvas_cda_mensual.csv` | 21.839 | 8 | 2018-01-01 | 2026-07-01 |
| `datos/transacciones_deuda_bva.csv` | 286.174 | 16 | 2010-05-17 | 2026-08-19 |
| `datos/eventos_mercado_secundario_lrm_bonos.csv` | 2.037 | 10 | 2012-03-09 | 2026-08-14 |
| `datos/eventos_subastas_lrm.csv` | 10.334 | 10 | 2013-01-08 | 2026-07-30 |

## 4. Cómo se usarían los datos

- **Curvas:** las tasas de `research.curves` están en **proporción** (0,097 = 9,7%); las tasas bancarias y la TPM, en %. Multiplicar las curvas por 100. Las fechas de las curvas son irregulares (varias por mes); para el panel mensual usar la última curva del mes.
- **Plazos comparables:** interpolar la curva NSS con sus parámetros (no linealmente) a los plazos de las bandas bancarias (≤ 1 año, > 1 año).
- **Transacciones:** agregar a instrumento-día o emisor-mes; `volumen_moneda_local` está en la moneda de la operación; revisar `estado_volumen` antes de sumar. Separar primario, secundario y repo (el repo no es negociación de precio).
- **Fiscal:** los montos del MEF están en miles de millones de Gs. (`escala = billions`); la deuda externa del Cuadro 59, en miles de USD.
- **Sin desestacionalizar** tasas ni spreads; los flujos fiscales tienen estacionalidad marcada (aguinaldo, vencimientos).

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Resultados de subastas de Bonos del Tesoro (ofertas, adjudicación, rendimiento, fecha de anuncio y liquidación) | Núcleo del módulo B | MEF – Dirección de Política de Endeudamiento; BVA (SEN) |
| Calendario de emisiones del Tesoro (anunciado vs. realizado) | Sorpresas de oferta | MEF – programa financiero anual |
| *Security master*: cupón, vencimiento, calificación y covenants por ISIN | Emparejamiento hedónico | BVA; Comisión Nacional de Valores (prospectos) |
| Tenencias de bonos por banco e inversor | Vínculo entre módulos | SIB (cartera de inversiones por banco); CAVAPY |
| Tasas de préstamos a los mismos emisores | Comparación intra-emisor | Central de riesgos BCP |
| Curva soberana en PYG y USD | Referencia libre de riesgo local | MEF / BVA; bonos globales de Paraguay (Bloomberg) |

## 6. Evaluación de viabilidad

**Media.** El módulo A es viable: hay curvas por calificación y moneda desde 2010, curva CDA desde 2018, tasas bancarias por plazo desde 2011 y 286 mil transacciones con emisor e ISIN. El módulo B no tiene resultados de subastas del Tesoro; solo permite un tablero de oferta pública y el análogo de las subastas de LRM.

## 7. Supuestos que debes revisar

1. Las tasas de las curvas NSS (`tasa_cero`, `tasa_par`) se interpretan como **proporciones** anuales; verificar la convención (efectiva vs. nominal) con la BVA.
2. Incluí CDA en las transacciones porque es el principal instrumento bancario negociado en bolsa (desde 2023); excluí acciones, fondos, fideicomisos y títulos extranjeros.
3. Las etiquetas del Cuadro 32 (operaciones de la BVA) están contaminadas con números; las asigné por el texto inicial.
4. Financiamiento interno y externo de la Administración Central tomados del estado de operaciones del MEF (MEFP 2001); los signos siguen al publicador.
5. Las subastas de LRM tienen identidad anual por hoja no resuelta en la base (tasas ofertadas vs. asignadas); revisar contra el Excel antes de usarlas.
