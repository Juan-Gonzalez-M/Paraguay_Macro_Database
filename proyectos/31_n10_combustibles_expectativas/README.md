# 31 · N10 (proyecto nuevo) — Precios administrados de combustibles, inflación y expectativas

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 20:44:20 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

> **Proyecto nuevo con potencial causal moderado.** Los ajustes del precio del gasoil son discretos y fechados, pero responden al petróleo y al tipo de cambio; la identificación usa el componente del ajuste no explicado por esos determinantes (o su *timing*, que depende de decisiones de Petropar y del Gobierno).

## 1. Resumen y pregunta de investigación

- **Pregunta:** ¿cuánto y a qué velocidad se trasladan los ajustes de combustibles a la inflación total, a la subyacente (segunda vuelta) y a las expectativas de la EVE?
- **Estimandos:** traspaso directo (IPC combustibles, transporte), indirecto (transporte público, alimentos) y de segunda vuelta (IPCSAE, subyacente); respuesta de las expectativas a 1, 12 y 24 meses.
- **Evidencia:** forma reducida con eventos discretos; causal si el ajuste se descompone en parte anticipada (petróleo, tipo de cambio) y sorpresa (decisión de precio).

## 2. Estrategia empírica propuesta

1. **Eventos:** ajustes de precios de Petropar y distribuidoras (`datos_manuales/ajustes_combustibles.csv`); mientras tanto, `ajustes_gasoil_inferidos.csv` detecta 84 meses con variaciones del índice del gasoil mayores a ±3% (41 desde 2015).
2. **Función de reacción del precio administrado:** Δ gasoil sobre Brent (diario y mensual) y PYG/USD con rezagos; el residuo es el componente discrecional.
3. **LP mensuales** de IPC total, subyacente, IPCSAE, transporte y alimentos sobre el componente discrecional, h = 0–12; asimetría subas/bajas.
4. **Expectativas:** respuesta de la EVE (mes, año t, 12 y 24 meses) en el mes del ajuste y siguientes; un anclaje fuerte implica respuesta nula a 24 meses.

## 3. Series extraídas

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `gasoil_indice` | Índice de precio del gasoil (Cuadro 13 a; el título del cuadro dice IPC empalmado) | `economic_annex` CUADRO 13 a | mensual | 1988-01-01 | 2026-07-01 | 462 | INDEX | Preliminar | Tratamiento: precio administrado |
| `gasoil_var_mensual` | Variación mensual del índice del gasoil (Cuadro 13 a) | `economic_annex` CUADRO 13 a | mensual | 1988-02-01 | 2026-07-01 | 462 | PERCENT | Preliminar | Tratamiento (variación) |
| `ipc_combustibles_grupo` | IPC transporte: combustibles y lubricantes (Cuadro 16) | `economic_annex` CUADRO 16 (Cont.) | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Primera etapa en el IPC |
| `ipc_transporte_div` | IPC división transporte | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Traspaso directo |
| `ipc_transporte_publico` | IPC transporte público y taxis | `economic_annex` CUADRO 16 (Cont.) | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Traspaso indirecto (tarifas) |
| `ipc_indice` | IPC índice general | `economic_annex` CUADRO 14 | mensual | 1994-12-01 | 2026-07-01 | 380 | INDEX | Preliminar | Resultado |
| `ipc_var_mensual` | Inflación total mensual | `economic_annex` CUADRO 15 | mensual | 1993-01-01 | 2026-07-01 | 403 | PERCENT | Validada por regla | Resultado |
| `ipc_subyacente_mensual` | Inflación subyacente mensual | `economic_annex` CUADRO 15 | mensual | 1993-01-01 | 2026-07-01 | 403 | PERCENT | Validada por regla | Resultado: segunda vuelta |
| `ipcsae` | IPCSAE (sin alimentos ni energía) | `economic_annex` CUADRO 14 b | mensual | 2007-12-01 | 2026-07-01 | 224 | INDEX | Preliminar | Resultado: segunda vuelta |
| `ipc_bienes_alimenticios` | IPC bienes alimenticios | `economic_annex` CUADRO 14 b | mensual | 1995-01-01 | 2026-07-01 | 379 | INDEX | Preliminar | Resultado: costos de transporte de alimentos |
| `eve_inf_mes` | EVE (mediana): inflación esperada del mes | `eve` NA | mensual | 2006-04-01 | 2026-08-01 | 245 | PROPORTION | Preliminar | Resultado: expectativas corto plazo |
| `eve_inf_prox_mes` | EVE (mediana): inflación esperada próximo mes | `eve` NA | mensual | 2014-06-01 | 2026-08-01 | 147 | PROPORTION | Preliminar | Resultado: expectativas |
| `eve_inf_anio_t` | EVE (mediana): inflación esperada año t | `eve` NA | mensual | 2006-04-01 | 2026-08-01 | 245 | PROPORTION | Preliminar | Resultado: expectativas |
| `eve_inf_12m` | EVE (mediana): inflación esperada 12 meses | `eve` NA | mensual | 2017-09-01 | 2026-08-01 | 108 | PROPORTION | Preliminar | Resultado: expectativas |
| `eve_inf_24m` | EVE (mediana): inflación esperada 24 meses | `eve` NA | mensual | 2014-08-01 | 2026-08-01 | 145 | PROPORTION | Preliminar | Resultado: anclaje |
| `petroleo_brent` | Petróleo Brent USD/barril (mensual) | `economic_annex` Cuadro 49 | mensual | 1994-01-01 | 2026-07-01 | 391 | USD_PER_BARREL | Preliminar | Determinante del ajuste (función de reacción de Petropar) |
| `pyg_usd_prom_venta` | PYG por USD promedio mensual | `exchange_rates` USD Prom | mensual | 1989-01-01 | 2026-07-01 | 451 | PYG_PER_USD | Validada por regla | Determinante del ajuste |
| `tpm` | Tasa de política monetaria | `economic_annex` CUADRO 19  | mensual | 2011-05-01 | 2026-07-01 | 183 | PERCENT | Preliminar | Control |
| `brent_d` | FRED: petróleo Brent diario | `FRED` DCOILBRENTEU | diaria | 1987-05-20 | 2026-09-15 | 9.087 | USD_PER_BARREL | Externa (FRED), no verificada en la base | Determinante diario del ajuste |
| `tarifa_cuadro_13_*` | 5 series: economic_annex hoja CUADRO 13 (detalle en diccionario_series.csv) | `economic_annex` CUADRO 13 | mensual | 1988-01-01 | 2026-07-01 | 2.217 | INDEX | Preliminar (5) | Índices de tarifas y precios regulados (etiquetas de la base cruzadas) |

### Otros archivos

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `ajustes_gasoil_inferidos.csv` | Meses con variación del índice del gasoil mayor a ±3% (inferido de datos mensuales) | 1989-05-01 a 2026-07-01, 84 filas | Inferido |
| `datos_manuales/ajustes_combustibles.csv` | **Plantilla para completar**: fecha de vigencia, producto, empresa, precio anterior y nuevo (Gs./litro), fuente | vacía | Manual |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_diaria.csv` | 9.087 | 11 | 1987-05-20 | 2026-09-15 |
| `datos/series_diaria_ancho.csv` | 9.087 | 2 | 1987-05-20 | 2026-09-15 |
| `datos/series_mensual.csv` | 7.985 | 11 | 1988-01-01 | 2026-08-01 |
| `datos/series_mensual_ancho.csv` | 464 | 24 | 1988-01-01 | 2026-08-01 |
| `datos/diccionario_series.csv` | 24 | 13 | 1987-05-20 | 2017-09-01 |
| `datos/ajustes_gasoil_inferidos.csv` | 84 | 4 | 1989-05-01 | 2026-07-01 |

## 4. Cómo se usarían los datos

- `Δlog` de índices y precios; Brent convertido a guaraníes con el tipo de cambio.
- La EVE está en proporciones (multiplicar por 100).
- Con fechas diarias de ajuste se asigna cada evento al mes de vigencia (o prorrateado por días si ocurre a mitad de mes).

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Fechas y precios de cada ajuste (Petropar y privados), por producto | Tratamiento exacto | Petropar; MIC; prensa (lo conseguirás mañana) |
| Subsidios y fondos de estabilización de combustibles | Separar decisión de precio de subsidio | MEF; Petropar |
| Microprecios de pasajes y fletes | Traspaso indirecto | Viceministerio de Transporte; BCP |

## 6. Evaluación de viabilidad

**Media.** Los datos mensuales de precios, IPC y expectativas están completos desde 1988–2014; la identificación mejora mucho con las fechas exactas de los ajustes.

## 7. Supuestos que debes revisar

1. El Cuadro 13 a es un **índice del precio del gasoil** (por valores), no el IPC empalmado que indica su título (ver carpeta 21).
2. Las etiquetas del Cuadro 13 están cruzadas en la base ("Gasoil — Teléfono", "Pasaje — Teléfono").
3. El umbral de ±3% para eventos inferidos es arbitrario; con las fechas oficiales se reemplaza.
