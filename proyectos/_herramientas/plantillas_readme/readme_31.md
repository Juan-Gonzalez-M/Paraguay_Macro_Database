# 31 · N10 (proyecto nuevo) — Precios administrados de combustibles, inflación y expectativas

*Carpeta de datos generada por `R/01_extraer_datos.R` · {{GENERADO}}*

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

{{TABLA_SERIES}}

### Otros archivos

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `ajustes_gasoil_inferidos.csv` | Meses con variación del índice del gasoil mayor a ±3% (inferido de datos mensuales) | {{RANGO:ajustes_gasoil_inferidos.csv}} | Inferido |
| `datos_manuales/ajustes_combustibles.csv` | **Plantilla para completar**: fecha de vigencia, producto, empresa, precio anterior y nuevo (Gs./litro), fuente | vacía | Manual |

{{TABLA_ARCHIVOS}}

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

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Traspaso de precios de energía

| Referencia | Qué respalda en este proyecto |
|---|---|
| Kilian, L. (2008). "The Economic Effects of Energy Price Shocks." *Journal of Economic Literature*, 46(4), 871–909. **[Revista]** | Canales directos e indirectos de los precios de energía hacia la inflación. Marco del paso 3. |
| Choi, S., Furceri, D., Loungani, P., Mishra, S. y Poplawski-Ribeiro, M. (2018). "Oil Prices and Inflation Dynamics: Evidence from Advanced and Developing Economies." *Journal of International Money and Finance*, 82, 71–96. **[Revista]** | Traspaso del petróleo a la inflación con proyecciones locales en países en desarrollo. Mayor en países con **precios administrados** y dependencia energética. Especificación de referencia. |
| Kpodar, K. y Abdallah, C. (2017). "Dynamic Fuel Price Pass-Through: Evidence from a New Global Retail Fuel Price Database." *Energy Economics*, 66, 303–312. **[Revista]** | Traspaso del crudo al precio minorista de combustibles en 162 países, **asimétrico** (las bajas se trasladan menos). Respalda la función de reacción del paso 2 y la asimetría. |
| Borenstein, S., Cameron, A. C. y Gilbert, R. (1997). "Do Gasoline Prices Respond Asymmetrically to Crude Oil Price Changes?" *Quarterly Journal of Economics*, 112(1), 305–339. **[Revista]** | Referencia clásica de la asimetría "cohete y pluma". |

### 8.2 Combustibles y expectativas

| Referencia | Qué respalda |
|---|---|
| Coibion, O. y Gorodnichenko, Y. (2015). "Is the Phillips Curve Alive and Well after All? Inflation Expectations and the Missing Disinflation." *American Economic Journal: Macroeconomics*, 7(1), 197–232. **[Revista]** | Las expectativas de los hogares siguen al precio del combustible. Respalda el paso 4. |
| Binder, C. (2018). "Inflation Expectations and the Price at the Pump." *Journal of Macroeconomics*, 58, 1–18. **[Revista]** | Correlación estrecha entre el precio del combustible y las expectativas de los hogares. |
| Wong, B. (2015). "Do Inflation Expectations Propagate the Inflationary Impact of Real Oil Price Shocks?: Evidence from the Michigan Survey." *Journal of Money, Credit and Banking*, 47(8), 1673–1689. **[Revista]** | Canal de segunda vuelta vía expectativas. |

**Nota:** estos trabajos usan expectativas de **hogares**; la EVE es de expertos, que deberían reaccionar menos. Una respuesta nula de la EVE a 24 meses es consistente con anclaje, no con ausencia de efecto en hogares.

### 8.3 Antecedentes para Paraguay

- **[PY]** Monfort y Peña (2008), IMF WP 08/270 (ver carpeta 12): factores de costo en la inflación paraguaya. No encontré estudios específicos del traspaso de los ajustes de Petropar.
