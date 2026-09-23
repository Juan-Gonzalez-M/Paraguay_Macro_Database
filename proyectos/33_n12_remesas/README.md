# 33 · N12 (proyecto nuevo) — Remesas familiares: shocks en los países de origen y consumo

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 20:44:41 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

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

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `pyg_usd_prom_venta` | PYG por USD promedio mensual | `exchange_rates` USD Prom | mensual | 1989-01-01 | 2026-07-01 | 451 | PYG_PER_USD | Validada por regla | Conversión / canal cambiario |
| `pyg_eur` | PYG por EUR | `economic_annex` CUADRO 60a | mensual | 1997-01-01 | 2026-07-01 | 355 | PYG_PER_EUR | Preliminar | Valor en guaraníes de remesas desde Europa |
| `pyg_ars` | PYG por ARS | `economic_annex` CUADRO 60a | mensual | 1997-01-01 | 2026-07-01 | 355 | PYG_PER_ARS | Preliminar | Valor en guaraníes de remesas desde Argentina |
| `ars_usd_prom` | FMI: ARS por USD promedio mensual | `imf_er` NA | mensual | 1962-05-01 | 2026-07-01 | 771 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Shock en el país de origen (Argentina) |
| `ipc_argentina` | FMI: IPC Argentina | `imf_cpi` NA | mensual | 2016-12-01 | 2026-06-01 | 115 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Shock en origen (salario real) |
| `imaep_original` | IMAEP serie original | `economic_annex` CUADRO 9 | mensual | 1994-01-01 | 2026-06-01 | 390 | INDEX | Preliminar | Resultado agregado |
| `consumo_privado_real` | PIB por gasto: consumo privado (millones de Gs. de 2014; trimestral) | `economic_annex` CUADRO 7 | trimestral | 1994-01-01 | 2026-01-01 | 129 | PYG (millones) | Preliminar | Resultado: consumo |
| `ipc_indice` | IPC índice general | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Deflactor |
| `dep_priv_me_total_usd` | Depósitos privados en ME (millones de USD) | `economic_annex` CUADRO 23a | mensual | 1995-03-01 | 2026-06-01 | 370 | UNRESOLVED_SOURCE_UNITS (millones) | Preliminar | Resultado: ahorro en dólares |
| `desempleo_espana` | FRED/OCDE: tasa de desempleo de España (mensual) | `FRED` LRHUTTTTESM156S | mensual | 1986-04-01 | 2026-07-01 | 484 | PERCENT | Externa (FRED), no verificada en la base | Shock en origen (España) |
| `desempleo_eeuu` | FRED: tasa de desempleo de EE.UU. | `FRED` UNRATE | mensual | 1948-01-01 | 2026-08-01 | 943 | PERCENT | Externa (FRED), no verificada en la base | Shock en origen (EE.UU.) |
| `usd_por_eur_m` | FRED: USD por EUR (promedio mensual) | `FRED` DEXUSEU | mensual | 1999-01-01 | 2026-08-01 | 332 | USD_PER_EUR | Externa (FRED), no verificada en la base | Shock cambiario en origen (Europa) |
| `remesas_cuadro_58_*` | 15 series: economic_annex hoja CUADRO 58 (detalle en diccionario_series.csv) | `economic_annex` CUADRO 58 | mensual | 2008-01-01 | 2026-05-01 | 3.315 | USD/EUR (miles) | Preliminar (15) | Remesas familiares por país de origen (miles de USD; algunas en EUR) |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_mensual.csv` | 8.261 | 11 | 1948-01-01 | 2026-08-01 |
| `datos/series_mensual_ancho.csv` | 944 | 27 | 1948-01-01 | 2026-08-01 |
| `datos/series_trimestral.csv` | 129 | 11 | 1994-01-01 | 2026-01-01 |
| `datos/series_trimestral_ancho.csv` | 129 | 2 | 1994-01-01 | 2026-01-01 |
| `datos/diccionario_series.csv` | 27 | 13 | 1948-01-01 | 2016-12-01 |

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
