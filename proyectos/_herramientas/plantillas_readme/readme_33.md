# 33 · N12 (proyecto nuevo) — Remesas familiares: shocks en los países de origen y consumo

*Carpeta de datos generada por `R/01_extraer_datos.R` · {{GENERADO}}*

> **Proyecto nuevo, de alcance acotado.** Las remesas por país de origen permiten un diseño *shift-share* (exposición a España, Argentina, EE.UU. × shocks en esos países), pero su peso en la economía paraguaya es pequeño; puede integrarse como módulo de N2, N3 o del proyecto 26.

## 1. Resumen y pregunta de investigación

- **Pregunta:** ¿cómo responden las remesas a los ciclos y tipos de cambio de los países de origen, y cuánto amortiguan o amplifican el consumo privado paraguayo?
- **Estimandos:** elasticidad de las remesas al desempleo y al tipo de cambio en origen; respuesta del consumo privado a remesas predichas por shocks en origen (IV *shift-share*).
- **Evidencia:** forma reducida; el IV es creíble para shocks de origen (desempleo en España, devaluaciones argentinas), débil en la etapa del consumo por el tamaño de las remesas.

## 2. Estrategia empírica propuesta

1. **Descomposición por origen (2008–2026):** Argentina, España, EE.UU., Italia, Brasil y otros; participación y volatilidad.
2. **Remesas por origen sobre shocks del origen:** desempleo de España y EE.UU. (FRED/OCDE), ARS/USD e IPC de Argentina, EUR/USD.
3. **Shift-share:** remesas predichas = Σ_origen participación_2008 × crecimiento explicado por el shock del origen; instrumento para las remesas totales en una regresión del consumo privado trimestral y de los depósitos en ME.
4. **Episodios:** crisis española 2008–2013, devaluaciones argentinas (proyecto 26), COVID 2020.

## 3. Series extraídas

{{TABLA_SERIES}}

{{TABLA_ARCHIVOS}}

## 4. Cómo se usarían los datos

- Remesas en USD (algunas series vienen en EUR: convertir con `usd_por_eur_m`); `log` y variación interanual por estacionalidad (diciembre, Día de la Madre).
- Consumo privado trimestral: sumar las remesas mensuales del trimestre.
- Participaciones de origen congeladas en 2008–2009.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Remesas por departamento de destino | Variación geográfica (diseño mucho más fuerte) | BCP – balanza de pagos; empresas remesadoras; EPH (módulo de remesas) |
| Microdatos de hogares receptores (EPH) | Efectos en consumo y trabajo | INE |
| Stock de migrantes por país de origen | Participaciones de exposición | INE; OIM; censos de España y Argentina |

## 6. Evaluación de viabilidad

**Media-baja** como proyecto independiente: los datos por origen existen (2008–2026) y los shocks de origen son externos, pero las remesas pesan poco en el consumo agregado y no hay variación geográfica. Útil como módulo.

## 7. Supuestos que debes revisar

1. Las remesas del Cuadro 58 se leen en miles de USD salvo las marcadas en EUR (Europa); revisar la unidad serie por serie en el diccionario.
2. El desempleo de España (OCDE vía FRED) representa el ciclo relevante para los migrantes paraguayos en Europa.

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Remesas como seguro y su ciclicidad

| Referencia | Qué respalda en este proyecto |
|---|---|
| Yang, D. (2008). "International Migration, Remittances and Household Investment: Evidence from Philippine Migrants' Exchange Rate Shocks." *Economic Journal*, 118(528), 591–630. **[Revista]** | **Diseño central**: shocks cambiarios en los países donde viven los migrantes, ponderados por la exposición de cada hogar, como variación exógena de las remesas. Es el shift-share del paso 3. |
| Yang, D. y Choi, H. (2007). "Are Remittances Insurance? Evidence from Rainfall Shocks in the Philippines." *World Bank Economic Review*, 21(2), 219–248. **[Revista]** | Las remesas responden a shocks en el país de origen de los migrantes (seguro). Respalda la pregunta "amortiguan o amplifican". |
| Frankel, J. A. (2011). "Are Bilateral Remittances Countercyclical?" *Open Economies Review*, 22(1), 1–16. **[Revista]** | Con remesas **bilaterales**: contracíclicas respecto del país de origen del migrante y procíclicas respecto del país donde vive. Es la especificación del paso 2 con datos por origen. |
| Chami, R., Fullenkamp, C. y Jahjah, S. (2005). "Are Immigrant Remittance Flows a Source of Capital for Development?" *IMF Staff Papers*, 52(1), 55–81. **[Revista]** | Remesas motivadas por compensación (contracíclicas). Interpretación de los signos. |

### 8.2 Métodos

- Goldsmith-Pinkham, Sorkin y Swift (2020, *AER*) y Borusyak, Hull y Jaravel (2022, *REStud*): validez de los instrumentos shift-share con participaciones de origen congeladas (ver carpeta 28).

### 8.3 Antecedentes para Paraguay

- **[PY]** Gómez, P. S. y Bologna, E. (2013). "Remesas y participación laboral en Paraguay: efectos de los desplazamientos sur-sur." *Migraciones Internacionales*, 7(2). **[Revista]** Con la EPH 2006 y propensity score matching, los hogares que reciben remesas de Argentina y Brasil trabajan menos horas. Es evidencia a nivel hogar y complementa el enfoque agregado de este proyecto.
- **[PY]** Hay documentos descriptivos del UNFPA Paraguay y de la OIM sobre la emigración paraguaya a Argentina y España, útiles para las participaciones por país de destino de los emigrantes (brecha "stock de migrantes").
