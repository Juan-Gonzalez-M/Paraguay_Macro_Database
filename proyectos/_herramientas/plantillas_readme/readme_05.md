# 05 · C1 — Liquidez dólar, dolarización y descalce cambiario

*Carpeta de datos generada por `R/01_extraer_datos.R` · {{GENERADO}}*

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

{{TABLA_SERIES}}

### Paneles por entidad

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `panel_eeff_entidad_mes.csv` | Estados financieros completos por entidad × mes × sub-rubro × moneda; `importe_pyg` en **millones de Gs.** (los saldos 6200 son ME convertidos a PYG) | {{RANGO:panel_eeff_entidad_mes.csv}} | Panel provisional |
| `panel_carteras_entidad_mes.csv` | Cartera vigente/vencida/renovada/refinanciada/reestructurada y depósitos por tipo, por moneda | {{RANGO:panel_carteras_entidad_mes.csv}} | Panel provisional |
| `panel_credito_sector_entidad_mes.csv` | Cartera vigente y vencida por 13 sectores × moneda | {{RANGO:panel_credito_sector_entidad_mes.csv}} | Panel provisional |
| `panel_credito_actividad_entidad_mes.csv` | Cartera vigente y vencida × moneda para 4 cultivos: soja, arroz, trigo y algodón | {{RANGO:panel_credito_actividad_entidad_mes.csv}} | Panel provisional |
| `panel_categoria_riesgo_entidad_mes.csv` | Cartera por categoría de riesgo (1, 1a, 1b, 2 a 6) | {{RANGO:panel_categoria_riesgo_entidad_mes.csv}} | Panel provisional |
| `panel_ratios_entidad_mes.csv` | 40 ratios publicados (morosidad MN y ME, capital, liquidez, rentabilidad) | {{RANGO:panel_ratios_entidad_mes.csv}} | Panel provisional |
| `entidades.csv` | `entity_id` → nombre, razón social, propiedad (nacional/extranjera). En los paneles "raw", `codigo_entidad` = número de `entity_id` | 29 entidades | Referencia |

{{TABLA_ARCHIVOS}}

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
