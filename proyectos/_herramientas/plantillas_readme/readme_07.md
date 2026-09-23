# 07 · C3 — Bonos corporativos, crédito bancario y deuda pública

*Carpeta de datos generada por `R/01_extraer_datos.R` · {{GENERADO}}*

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

{{TABLA_SERIES}}

### Curvas, transacciones y eventos

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `curvas_bonos_corporativos.csv` | Curvas Nelson-Siegel-Svensson de bonos corporativos: fecha de estimación, moneda (PYG, USD), calificación (AAA a B), plazo (años), tasa cero, tasa par, factor de descuento y parámetros β0–β3, λ1–λ2 | {{RANGO:curvas_bonos_corporativos.csv}} | Validada por regla (estructural) |
| `curvas_cda_mensual.csv` | Curva de CDA por plazo y moneda: tasa ponderada, volumen y cantidad de operaciones (bancos y financieras) | {{RANGO:curvas_cda_mensual.csv}} | Estructura especial |
| `transacciones_deuda_bva.csv` | Operaciones de la BVA en bonos corporativos, subordinados, financieros, del Tesoro, municipales, BBCP, LRM y CDA: fecha, mercado (primario, secundario, repo), moneda, volumen, ISIN, emisor, casa de bolsa | {{RANGO:transacciones_deuda_bva.csv}} | Validada por regla (estructural) |
| `eventos_mercado_secundario_lrm_bonos.csv` | Operaciones del mercado secundario de LRM y bonos (tasa, monto, plazo residual) | {{RANGO:eventos_mercado_secundario_lrm_bonos.csv}} | Estructura especial |
| `eventos_subastas_lrm.csv` | Subastas de LRM: monto anunciado/ofertado/asignado, tasas mín./prom./máx. ofertadas y asignadas, posturas, plazo | {{RANGO:eventos_subastas_lrm.csv}} | Estructura especial |

{{TABLA_ARCHIVOS}}

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

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Módulo A: bono frente a préstamo bancario

| Referencia | Qué respalda en este proyecto |
|---|---|
| Schwert, M. (2020). "Does Borrowing from Banks Cost More than Borrowing from the Market?" *Journal of Finance*, 75(2), 905–947. **[Revista]** | **Referencia central del Módulo A**: compara préstamos y bonos de la misma empresa en la misma fecha y encuentra una prima bancaria después de ajustar por riesgo. Respalda el spread emparejado por calificación, moneda y plazo; aquí se aproxima con curvas por calificación en lugar de emparejar empresa por empresa. |
| Becker, B. e Ivashina, V. (2014). "Cyclicality of Credit Supply: Firm Level Evidence." *Journal of Monetary Economics*, 62, 76–93. **[Revista]** | Las empresas sustituyen préstamos por bonos cuando se contrae la oferta bancaria. Respalda leer el spread bono−banco como indicador de condiciones de oferta. |
| Gertler, M. y Karadi, P. (2015). "Monetary Policy Surprises, Credit Costs, and Economic Activity." *American Economic Journal: Macroeconomics*, 7(1), 44–76. **[Revista]** | La política monetaria mueve los spreads de crédito además de las tasas libres de riesgo. Respalda la respuesta de spreads y pendiente a la TPM (paso 3). |
| Du, W. y Schreger, J. (2016). "Local Currency Sovereign Risk." *Journal of Finance*, 71(3), 1027–1070. **[Revista]** | Diferencias entre deuda en moneda local y en dólares de emergentes. Respalda separar las curvas PYG y USD y controlar por `ust_10a` en USD. |

### 8.2 Construcción de curvas

| Referencia | Uso |
|---|---|
| Nelson, C. R. y Siegel, A. F. (1987). "Parsimonious Modeling of Yield Curves." *Journal of Business*, 60(4), 473–489. **[Revista]** | Forma funcional de las curvas `research.curves`. |
| Svensson, L. E. O. (1994). "Estimating and Interpreting Forward Interest Rates: Sweden 1992–1994." NBER Working Paper 4871. **[DT]** | Extensión NSS usada en las curvas por calificación. |

### 8.3 Módulo B: oferta de deuda pública y subastas

| Referencia | Qué respalda |
|---|---|
| Krishnamurthy, A. y Vissing-Jorgensen, A. (2012). "The Aggregate Demand for Treasury Debt." *Journal of Political Economy*, 120(2), 233–267. **[Revista]** | Curva de demanda con pendiente negativa por deuda pública: más oferta, mayores rendimientos. Es el estimando del Módulo B. |
| Greenwood, R. y Vayanos, D. (2014). "Bond Supply and Excess Bond Returns." *Review of Financial Studies*, 27(3), 663–713. **[Revista]** | La oferta por plazo predice los retornos de los bonos. Respalda usar la composición del financiamiento interno y externo. |
| Lou, D., Yan, H. y Zhang, J. (2013). "Anticipated and Repeated Shocks in Liquid Markets." *Review of Financial Studies*, 26(8), 1891–1912. **[Revista]** | Ciclo de precios alrededor de las subastas del Tesoro por capacidad limitada de los intermediarios. Respalda el event study de subastas de LRM (paso 6). |
| Beetsma, R., Giuliodori, M., de Jong, F. y Widijanto, D. (2016). "Price Effects of Sovereign Debt Auctions in the Euro-Zone: The Role of the Crisis." *Journal of Financial Intermediation*, 25, 30–53. **[Revista]** | El efecto de las subastas es mayor en mercados menos profundos y en crisis. Relevante para un mercado pequeño como el paraguayo. |

### 8.4 Antecedentes para Paraguay

No encontré estudios académicos sobre spreads del mercado de bonos paraguayo (BVA). Hay cobertura de prensa sobre el crecimiento de las emisiones y el regreso de los Bonos del Tesoro a la Bolsa en 2026. Es un **tema poco estudiado**, lo que aumenta el aporte pero obliga a documentar bien la construcción de los datos.
