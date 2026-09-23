# Resumen de viabilidad del portafolio y prioridades de datos

*Fase 2 · 2026-09-22 · Base `paraguay_macro_pilot.duckdb`, esquema 49, build `481cb2d5`, SHA-256 `c902c77f…4f50` (sin modificar).*

Este documento compara todos los proyectos del portafolio y los doce proyectos nuevos que propongo (N1–N3 en una primera ronda; N4–N12, con foco en identificación causal, en una segunda). Luego prioriza los datos que faltan según cuánto cambiarían la viabilidad y a cuántos proyectos beneficiarían. Cada carpeta tiene su propio `README.md` con el detalle; aquí solo se resume.

**Cómo leer la viabilidad.** Se refiere al *ejercicio inicial* de cada ficha con los datos que existen hoy (base + NOAA/FRED + IMTS), no a la versión causal "óptima".

- **Alta:** la variable central y los controles están disponibles.
- **Media:** la variable central existe, pero con frecuencia, cobertura o calidad limitadas.
- **Baja:** falta la variable central.

---

## 1. Tabla comparativa

### 1.1 Proyectos construidos (25 carpetas)

| # | Proyecto | Viabilidad | Justificación en una línea | Principales brechas | Series (validadas / prelim. / no compr. / externas) | Tamaño |
|---|---|---|---|---|---|---|
| 01 | A1 Reservas y liquidez FX | **Media** | Precios diarios completos; reservas bancarias solo a fin de mes | Reservas bancarias diarias; calendario del corredor y del encaje; flujos diarios del Tesoro | 64 (0 / 46 / 0 / 0) + 18 especiales; paneles, LRM | 36 MB |
| 02 | B1 Intervención cambiaria | **Media** | Cronología diaria de operaciones del BCP desde 2013; sin timing ni reglas del programa | Clasificación diaria compensatoria/complementaria; hora de ejecución; reglas del programa | 42 (1 / 35 / 0 / 4) + 2 especiales | 18 MB |
| 03 | B2 Marco multi-horizonte PYG/USD | **Alta** | Núcleo mensual completo (parte validado) + controles globales de FRED | DXY propiamente dicho; precios forward; flujo por tipo de cliente | 70 (12 / 46 / 0 / 12) | 11 MB |
| 05 | C1 Liquidez USD y descalce | **Media** | Panel banco × moneda × sector desde 2016; sin plazo residual ni prestatario | Registro de crédito; plazo residual; moneda de ingreso del prestatario | 64 (6 / 54 / 0 / 4) + 6 paneles | 99 MB |
| 06 | C2 Depósitos, crédito y sustitución | **Media-alta** (bancos) / **Baja** (cooperativas) | Tasas por producto-plazo-moneda y paneles completos; tasas solo a nivel sistema | Tasas por entidad; panel de cooperativas (INCOOP) | 401 (5 / 391 / 5 / 0) + CDA + 4 paneles | 114 MB |
| 07 | C3 Bonos, banca y deuda pública | **Media** | Curvas NSS y 286 mil transacciones; sin subastas del Tesoro | Subastas del Tesoro; *security master*; tenencias | 83 (4 / 77 / 0 / 2) + curvas, transacciones, eventos | 91 MB |
| 09 | D1 ENSO no lineal | **Alta** ↑ | Con el ONI de NOAA el mínimo de la ficha está completo desde 1994 | Clima físico; producción agrícola | 47 (12 / 30 / 0 / 5) | 3 MB |
| 12 | D4 Inflación climática y colas | **Media-alta** | Componentes del IPC, IPP, EVE, ENSO y precios mundiales | Clima físico; ponderaciones del IPC; densidades de expectativas | 89 (5 / 78 / 0 / 6) | 7 MB |
| 13 | D5 Clima y riesgo de crédito | **Media** (descriptivo) / **Baja** (causal) | Panel banco-sector-cultivo-moneda + ENSO; pocos episodios y sin geografía | Geografía de la cartera; registro de crédito; clima geográfico | 46 (2 / 40 / 0 / 4) + 5 paneles | 23 MB |
| 16 | E3 Anclaje de expectativas | **Media** (agregado) | EVE (mediana) desde 2006/2014 con realizaciones; sin dispersión | Dispersión y microdatos de la EVE; historia oficial de la meta | 35 (6 / 29 / 0 / 0) + meta manual | 2 MB |
| 18 | F2 Pass-through e importaciones | **Media** (agregado) / **Baja** (frontera) | Valores unitarios de importación desde 1994 + IMTS por socio | Aduanas por transacción; IPC regional y precios de frontera | 854 (4 / 824 / 24 / 2) + IMTS | 86 MB |
| 20 | F4 Pagos instantáneos (SPI) | **Media** (monitoreo) / **Baja** (causal) | Boletín completo con SPI desde 2022-05 y paneles por entidad | SPI entidad-día y cliente; fechas de adopción | 634 (0 / 556 / 78 / 0) + 3 paneles | 18 MB |
| 21 | F5 Inflación desigual (N9) | **Media** (N9) / **Baja** (N10) | Índices por división, grupo y producto; faltan pesos por grupo de hogares | Ponderadores EIGH por grupo; IPC por producto | 183 (3 / 90 / 90 / 0) | 8 MB |
| 22 | **N1 Política fiscal** (nuevo) | **Media-alta** | 23 años de datos fiscales mensuales (MEF) + binacionales como fuente externa al ciclo | Presupuesto aprobado; SPNF consolidado; cronología de la regla fiscal | 121 (5 / 88 / 28 / 0) | 7 MB |
| 23 | **N2 Mercado laboral e informalidad** (nuevo) | **Media** | EPHC completa pero corta (38 trimestres) | Microdatos EPHC; series pre-2017; cotizantes IPS | 1.101 (3 / 390 / 708 / 0) | 8 MB |
| 24 | **N3 Panel regional FMI** (nuevo) | **Media-alta** | 9 países × 22 indicadores (192 de 198 disponibles) + shocks globales | Datos del FMI actualizados; EMBI; intervención oficial de pares | 197 (0 / 192 / 0 / 5) + panel largo | 16 MB |
| 25 | **N4 Sorpresas monetarias de alta frecuencia** (nuevo) | **Media-alta** | Interbancario diario desde 2011; 40 fechas de cambio de TPM reconstruidas del corredor | Calendario del COPOM con hora de anuncio | 42 (0 / 7 / 0 / 3) + 32 especiales; LRM, curvas | 31 MB |
| 26 | **N5 Shocks cambiarios de Argentina** (nuevo) | **Media-alta** | Shocks grandes y externos; comercio bilateral, régimen de turismo, precios y remesas | Tipo de cambio paralelo; IPC regional; fechas oficiales de eventos | 228 (3 / 216 / 9 / 0) + IMTS bilateral | 15 MB |
| 27 | **N6 Regulación bancaria (DiD)** (nuevo) | **Media-alta** (encaje) / **Media-baja** (tope de tarjetas) | Encaje por banco desde 2016; tope de tarjetas visible en oct-2015, pero sin panel previo por banco | Fechas de cambios de encaje; boletines SIB 2013–2015 | 219 (0 / 219 / 0 / 0) + 5 paneles | 55 MB |
| 28 | **N7 Alivio COVID y mora** (nuevo) | **Media** | Cartera COVID por banco 2020–2026 con período previo desde 2016; selección de bancos | Resoluciones de alivio; registro de crédito | 6 (2 / 4 / 0 / 0) + 5 paneles | 45 MB |
| 29 | **N8 Canal de crédito bancario** (nuevo) | **Media** (→ media-alta con N4) | Panel de balance completo; tratamiento creíble depende de N4 | Sorpresas de N4; originaciones por banco | 8 (2 / 6 / 0 / 0) + 3 paneles | 46 MB |
| 30 | **N9 SPI y efectivo** (nuevo) | **Media** (descriptivo) / **Baja** (causal) | Una sola fecha nacional sin control; coincide con el ciclo de 2022 | Hitos del SPI; SPI entidad-día | 225 (1 / 214 / 10 / 0) + canales | 7 MB |
| 31 | **N10 Combustibles y expectativas** (nuevo) | **Media** | 41 ajustes del gasoil > 3% desde 2015; ajustes endógenos al petróleo | Fechas y precios de Petropar | 24 (3 / 20 / 0 / 1) | 3 MB |
| 32 | **N11 Salario mínimo** (nuevo) | **Media** | 12 ajustes fechados desde 2010 (julio desde 2017); en parte anticipados por fórmula | Decretos; exposición sectorial | 205 (2 / 71 / 132 / 0) + tramos de vigencia | 2 MB |
| 33 | **N12 Remesas** (nuevo) | **Media-baja** | Remesas por origen 2008–2026 y shocks de origen; peso macro pequeño | Remesas por departamento | 27 (1 / 23 / 0 / 3) | 2 MB |

↑ = viabilidad mejorada respecto de la Fase 1 al incorporar datos externos (ONI).

### 1.2 Proyectos no construidos

| Ficha | Estado | Viabilidad | Motivo / brecha central |
|---|---|---|---|
| E1 Combinación y reconciliación del PIB | Omitido por tu instrucción | — | Depende de cortes y realizaciones first/final de cuentas nacionales (en construcción por ti) |
| E2 Vintages, nowcasting y juicio | Omitido por tu instrucción | — | Idem; la base tiene un solo vintage por fuente |
| B3 Flujo de órdenes FX | Bloque 3 omitido | **Baja** | No existe flujo firmado por agente (la ficha dice que no hay sustituto) |
| C4 Repricing y toma de riesgo | Bloque 3 omitido | **Baja** | Sin tasa fija/variable ni fechas de reajuste; requiere registro de crédito |
| D2 Clima por calendario agrícola | Bloque 3 omitido | **Baja → Media** con datos públicos | Clima en grilla y producción por cultivo: ambos públicos y baratos (ver rango 2 de la sección 3.3) |
| D3 Pronósticos ENSO y sorpresas | Bloque 3 omitido | **Baja → Media** con datos públicos | Vintages de pronósticos ENSO del IRI (públicos; ver rango 2 de la sección 3.3) |
| F1 Facturación electrónica | Bloque 3 omitido | **Baja** | Sin datos SIFEN; requiere convenio con la DNIT |
| F3 Río, logística e hidroelectricidad | Bloque 3 omitido | **Baja** (logística) / **Media** (energía) | Sin niveles del río ni fletes; el módulo de energía se cubre en parte con N1 (binacionales) |

**Balance** (31 proyectos evaluables: 25 construidos y 6 del bloque 3; E1 y E2 omitidos por instrucción). Tomando la viabilidad del ejercicio principal de cada uno:

- **Alta:** 2 (B2, D1).
- **Media-alta:** 7 (C2 bancario, D4, N1, N3, N4, N5, N6-encaje).
- **Media:** 15 (A1, B1, C1, C3, D5, E3, F2, F4, F5-N9, N2, N7, N8, N9, N10, N11).
- **Media-baja:** 1 (N12).
- **Baja:** 6 (B3, C4, D2, D3, F1, F3).

**Proyectos con identificación causal defendible con los datos actuales + los datos que conseguirás mañana:** N4 (sorpresas de alta frecuencia), N5 (shocks argentinos), N6 módulo A (encaje × exposición bancaria), N1 (binacionales) y, con más reservas, N7, N10 y N11. N8 hereda la identificación de N4.

---

## 2. Series compartidas entre proyectos

Series que aparecen en 4 o más carpetas (por identificador de la base). Cualquier mejora de su calidad beneficia a todos esos proyectos a la vez.

| Serie | Fuente | Nivel | Nº proyectos | Carpetas |
|---|---|---|---|---|
| `tpm` — Tasa de política monetaria | Anexo, Cuadro 19 | **Preliminar (etiqueta contaminada)** | **19** | 01 02 03 05 06 07 09 12 13 16 20 22 23 25 27 28 29 30 31 |
| `pyg_usd_prom_venta` — PYG/USD promedio mensual | Cotizaciones BCP | Validada por regla | 15 | 02 03 05 07 09 12 13 16 18 22 26 28 29 31 33 |
| `ipc_indice` — IPC general base 2017 | Anexo, Cuadro 14 | Preliminar | 15 | 03 09 12 16 18 20 21 22 23 26 27 30 31 32 33 |
| `imaep_original` — IMAEP 1994– | Anexo, Cuadro 9 | Preliminar | 12 | 03 09 13 22 23 26 27 28 29 30 32 33 |
| `ipc_var_interanual` — Inflación interanual | Anexo, Cuadro 15 | Validada por regla | 10 | 03 06 07 09 12 16 21 23 29 30 |
| `soja_chicago` — Soja USD/t | Anexo, Cuadro 49 | Preliminar | 7 | 02 03 05 09 12 13 22 |
| `eve_inflacion_anio_t`, `ipc_var_mensual` | EVE; Cuadro 15 | Preliminar / Validada | 6 c/u | 03 09 12 16 21 31 32 |
| `tcn_venta`, `pyg_brl`, `pyg_ars`, `imaep_desest`, `petroleo_brent`, `ipc_argentina`, `ipc_subyacente_mensual`, `ipc_alimentos_indice` | Varias | Preliminar / Validada | 5 c/u | — |
| VIX, UST 2 años (diarios) | FRED (externo) | Externa | 5 c/u | 02 03 05 07 24 25 |
| `rin_saldo`, `bcp_fx_neto_total_d`, tasas efectivas ME (Cuadro 31) | Anexo; BCP | Preliminar / Validada | 4 c/u | 01 02 03 05 06 07 25 |
| ONI, RONI, Niño 3.4 | NOAA (externo) | Externa | 3 | 09 12 13 |

**Paneles banco/financiera-mes compartidos:** EEFF, carteras, crédito por sector, ratios y categorías de riesgo aparecen (completos o filtrados) en 01, 05, 06, 13, 20, 27, 28, 29 y 30. Una depuración única del panel (altas, bajas y fusiones de entidades) serviría a los nueve.

---

## 3. Priorización de datos e información faltante

### 3.1 Método

Para cada brecha identificada en los README:

- **Proyectos beneficiados:** cuántos proyectos (del portafolio, del bloque 3 y nuevos) mejoran al conseguirla.
- **Impacto:** cuánto cambia la viabilidad. **3** = sube un nivel de viabilidad o habilita la variable central; **2** = habilita la versión "suficiente" o un módulo; **1** = robustez o control.
- **Puntaje = Σ impactos** sobre los proyectos beneficiados.
- **Costo / acceso:** **Muy bajo** (documental o descarga pública), **Bajo** (dato interno del BCP ya existente), **Medio** (otra institución, formato público), **Alto** (convenio de confidencialidad o datos nuevos).

La prioridad final combina puntaje y costo: primero las brechas de alto puntaje y bajo costo.

### 3.2 Prioridad 0 — Validar lo que ya existe (no requiere datos nuevos)

Antes de buscar datos nuevos conviene validar las series que ya usa casi todo el portafolio. Hoy **ninguna** serie está revisada por un economista y la más usada (la TPM, en 19 proyectos) tiene la etiqueta contaminada. Las fechas candidatas de cambio de TPM del proyecto 25 sirven para verificarla.

| Acción | Proyectos beneficiados | Impacto | Costo |
|---|---|---|---|
| Revisar y firmar en el registro de la base (`config/series_review.csv`) las ~20 series compartidas de la sección 2: TPM, IPC y componentes, IMAEP, tipo de cambio, RIN, tasas del Cuadro 31, soja | 25 de 25 | Alto: quita la mayor fuente de riesgo común | **Muy bajo** (horas) |
| Corregir etiquetas contaminadas y unidades de los Cuadros 18, 19, 20, 26, 27, 31, 32, 33, 35, 56a, 23b/24b y 13/13 a (ya identificadas por valores en los README) | 01 02 05 06 07 16 20 21 22 | Medio | Muy bajo |
| Resolver la identidad de series posicionales clave: variaciones del IPC (14 a/b), MEF (28), EPHC por sexo e ingresos (708), SPI por entidad (52) | 12 18 20 21 22 23 | Medio-alto (habilita desagregaciones) | Bajo |
| Depurar el panel de entidades (fusiones, altas y bajas 2016–2026) | 01 05 06 13 20 27 28 29 30 | Medio | Bajo |

### 3.3 Ranking de datos faltantes

**Puntaje ajustado = puntaje ÷ factor de costo** (Muy bajo = 1; Bajo = 1,25; Bajo–medio = 1,5; Medio = 2; Alto = 2,5). El ranking se ordena por el puntaje ajustado; el puntaje bruto indica el beneficio total si el costo no importara.

| Rango | Dato faltante | Proyectos beneficiados | Nº | Impacto por proyecto | Puntaje | Costo / acceso | Puntaje ajustado | Fuente |
|---|---|---|---|---|---|---|---|---|
| **1** | **Calendario institucional fechado**: decisiones y hora de anuncio del COPOM, cambios del corredor y del encaje, tope de tarjetas, historia de la meta de inflación, ventas compensatorias, regla fiscal, medidas de alivio, ajustes de combustibles, decretos de salario mínimo, hitos del SPI | A1, B1, C2, E3, N1, D5, C4, **N4, N6, N7, N8, N9, N10, N11** | 14 | A1, B1, E3, N4, N6: 3; resto: 1–2 | 32 | Muy bajo (documental) | **32,0** | BCP, SIB, MEF, Petropar, MTESS (**lo conseguirás mañana**: ver sección 5) |
| **2** | **Clima físico y agro**: lluvia y temperatura en grilla (CHIRPS/ERA5-Land), calendarios de cultivo, producción por campaña; vintages de pronósticos ENSO (IRI) | D1, D2, D3, D4, D5, F3 | 6 | D2, D3: 3; D1, D4, D5, F3: 2 | 14 | Muy bajo (público) | **14,0** | CHIRPS, Copernicus, MAG, USDA, IRI |
| **3** | **Tasas y originaciones por entidad** (banco × producto × moneda × plazo) | A1, C1, C2, C3, C4 | 5 | C2, C4: 3; resto: 2–3 | 13 | Bajo (reporte regulatorio) | **10,4** | SIB / BCP |
| **4** | **Operaciones y liquidez diarias del BCP**: reservas bancarias diarias, operaciones FX con tipo y hora, flujos diarios del Tesoro, SPI entidad-día | A1, B1, B3, F4, C2 | 5 | A1, B1: 3 (suben a alta); F4: 2; B3, C2: 1–2 | 12 | Bajo (interno BCP) | **9,6** | BCP (OMA, Op. Internacionales, SIPAP) |
| **5** | **Ponderadores del IPC** (base 2017 oficiales y por grupo de hogares de la EIGH) + IPC por producto | F5, D4, F2 | 3 | F5: 3 (variable central); D4, F2: 2 | 7 | Muy bajo (público/BCP) | **7,0** | BCP (metodología IPC), INE (EIGH) |
| **6** | **Registro de crédito** (préstamo-prestatario anonimizado: moneda, plazo, tasa, reset, garantía, ubicación, reprogramación) | C1, C2, C4, D5, F1, C3, A1 | 7 | C1, C4, D5: 3; resto: 1–2 | 17 | Alto (confidencialidad) | **6,8** | Central de Riesgos BCP/SIB |
| **6b** | **Boletines de bancos y financieras anteriores a 2016** (2011–2015) | N6 (módulo tarjetas), C1, C2, D5, N7, N8 | 6 | N6: 3; resto: 1 | 8 | Bajo (archivo SIB) | **6,4** | SIB – boletines históricos |
| **7** | **Microdatos y dispersión de la EVE** (+ fecha de levantamiento) | E3, D4, B2, C2 | 4 | E3: 3; resto: 1–2 | 8 | Bajo (interno BCP) | **6,4** | BCP – Estudios Económicos |
| **8** | **Flujo FX firmado y posiciones cambiarias por banco (diario)** | B3, B1, B2, C1 | 4 | B3: 3 (variable central); resto: 1–2 | 8 | Bajo–medio (interno BCP) | **5,3** | BCP – Operaciones Cambiarias |
| **9** | **Subastas de bonos del Tesoro + *security master* + tenencias** | C3, N1, A1 | 3 | C3: 3 (módulo B); N1, A1: 1 | 5 | Bajo | **4,0** | MEF, BVA, CAVAPY |
| **10** | **Microdatos EPHC y series anteriores a 2017** | N2, F5 | 2 | 2 | 4 | Muy bajo (público) | **4,0** | INE |
| **11** | **Río: niveles, restricciones de navegación, fletes** | F3, D1, D2, F2 | 4 | F3: 3; resto: 1 | 6 | Bajo–medio (público) | **4,0** | DMH, ANNP, Prefectura |
| **12** | **Presupuesto aprobado (PGN) y SPNF consolidado** | N1 | 1 | 3 | 3 | Muy bajo | **3,0** | MEF (PGN, SIAF) |
| **13** | **Aduanas por transacción** (HS, origen, moneda de factura, importador/exportador) | F2, F3, C1, D2 | 4 | F2: 3; C1: 2; resto: 1 | 7 | Alto (convenio) | **2,8** | DNA |
| **13b** | **Tipo de cambio paralelo argentino (blue/MEP/CCL)** | N5, B2, N12 | 3 | N5: 2; resto: 1 | 4 | Bajo–medio (público, disperso) | **2,7** | Ámbito, BCRA |
| **14** | **Cooperativas por entidad** | C2, D5, C1 | 3 | C2 (sustitución): 3; resto: 1 | 5 | Medio | **2,5** | INCOOP |
| **15** | **Spreads soberanos (EMBI) e intervención oficial de pares** | N3, B2, C3 | 3 | 1–2 | 4 | Medio (comercial) | **2,0** | JP Morgan / Bloomberg; bancos centrales |
| **16** | **SIFEN / facturación electrónica** | F1, N1 | 2 | F1: 3; N1: 1 | 4 | Alto (convenio y privacidad) | **1,6** | DNIT |
| — | **Vintages de cuentas nacionales e indicadores** (en construcción por ti) | E1, E2, D3, E3, B2, D4 | 6 | E1, E2: 3; resto: 1–2 | 12 | En curso | — | BCP |

### 3.4 Recomendación de secuencia

1. **Inmediato (días a semanas; costo muy bajo):**
   - Prioridad 0: validar las series compartidas y corregir etiquetas.
   - **Calendario institucional** (rango 1), que sube de 7 a 14 proyectos beneficiados con la segunda ronda y es lo que traerás mañana (sección 5).
   - **Clima físico + vintages ENSO** (rango 2), que sube D2 y D3 de baja a media y refuerza D1, D4 y D5.
   - **Ponderadores del IPC** (rango 5), que vuelve factible F5-N9.
   - **Microdatos EPHC y PGN** (rangos 10 y 12).

   Juntos mejoran 20 proyectos sin necesidad de convenios.
2. **Corto plazo (1–3 meses; datos internos del BCP/SIB):**
   - **Tasas por entidad** (rango 3), que sube C2 a alta.
   - **Operaciones diarias del BCP** (rango 4), que sube A1 y B1 a alta.
   - **Microdatos de la EVE** (rango 7), que habilita el desacuerdo en E3.
   - **Flujo FX por banco** (rango 8), que es el único camino para B3.
   - **Subastas del Tesoro** (rango 9) y **boletines SIB 2011–2015** (rango 6b).
3. **Mediano plazo (convenios):**
   - **Registro de crédito** (rango 6). Tiene el mayor puntaje bruto junto con el calendario (17) y es el activo común que la ficha del portafolio pide para C1, C2, C4 y D5, pero requiere un marco de confidencialidad.
   - Después: aduanas (13), cooperativas (14) y SIFEN (16).

---

## 4. Proyectos nuevos propuestos

**Códigos en el portafolio v2** (`Portafolio_de_Investigacion_Orientado_a_Datos_Paraguay_v2.docx`). Los proyectos nuevos se integraron como fichas estandarizadas: A2 = carpeta 25 (N4), A3 = 29 (N8), C5 = 27 (N6), C6 = 28 (N7), D6 = 31 (N10), F6 = 26 (N5), F7 = 30 (N9) y un programa nuevo **G**: G1 = 22 (N1), G2 = 23 (N2), G3 = 32 (N11), G4 = 24 (N3), G5 = 33 (N12). El portafolio v2 incluye además una tabla de evaluación de todas las fichas contra la base; el original no se modificó.

### 4.1 Primera ronda (datos sin uso)

Al revisar qué datos de la base no usa ningún proyecto aparecieron tres bloques grandes sin aprovechar: el estado de operaciones fiscales mensual del MEF, el anexo laboral de la EPHC y el conjunto regional del FMI (9 países). Construí una carpeta para cada uno con la misma estructura que el resto.

| # | Proyecto | Pregunta central | Por qué tiene potencial | Viabilidad | Encaje en el programa del portafolio |
|---|---|---|---|---|---|
| 22 | **N1 Política fiscal: ciclicidad, estabilizadores y multiplicadores** | ¿Es el gasto procíclico, cambia con la regla fiscal y cuál es el multiplicador del gasto corriente y de capital? | 23 años de datos fiscales **mensuales**; las regalías/compensaciones de Itaipú y Yacyretá son una fuente de ingreso fiscal en buena medida externa al ciclo (útil para identificar); la coordinación fiscal-monetaria es tema central del BCP | **Media-alta** | Nuevo programa (fiscal); dialoga con A1 (flujos del Tesoro), C3 (oferta de deuda) y F3 (energía) |
| 23 | **N2 Mercado laboral, informalidad y ciclo** | ¿Por qué margen se ajusta el empleo (desocupación, subocupación, horas, informalidad) y hay una curva de Phillips con holgura ampliada? | EPHC completa (1.101 series) sin uso; informalidad ≈ 60% de los ocupados no agropecuarios: la holgura relevante para la política monetaria no es el desempleo | **Media** (38 trimestres) | Puente entre actividad (D1, N1) e inflación (D4, F5) |
| 24 | **N3 Panel regional: shocks globales, reservas, intervención y vulnerabilidad** | ¿Cómo responden flujos, tipo de cambio, inflación y bancos de 9 países a shocks globales, y qué los amortigua (reservas, intervención, dolarización)? | Único proyecto con **variación entre países**; los shocks globales son más exógenos que los domésticos; permite ubicar a Paraguay frente a sus pares | **Media-alta** | Complementa B1, B2 y C1 (programas B y C) |

### 4.2 Segunda ronda (foco en identificación causal)

Ideas de la sesión de brainstorming, todas construidas. La columna "Potencial causal" es mi evaluación franca.

| # | Proyecto | Identificación | Potencial causal | Hallazgo al construirlo | Viabilidad | Datos manuales que necesita |
|---|---|---|---|---|---|---|
| 25 | **N4 Sorpresas monetarias de alta frecuencia** | Movimiento de tasas de mercado en la ventana del anuncio del COPOM | **Alto** (infraestructura: tratamiento para A1, C2, C3, E3, B2, N8) | 40 fechas de cambio de TPM reconstruidas de los cambios paralelos del corredor (2015–2026) | Media-alta | `calendario_copom.csv` |
| 26 | **N5 Shocks cambiarios de Argentina** | Estudio de eventos con shocks externos grandes; Brasil y no transables como placebo | **Alto** para el efecto total por episodio | 15 meses con devaluación oficial > 10% (2002–2024) coinciden con los eventos conocidos | Media-alta | `eventos_argentina.csv` (9 candidatos no verificados) |
| 27 | **N6 Regulación bancaria (DiD)** | Cambio regulatorio × exposición predeterminada de cada banco; FE sector × moneda × mes | **Alto** en encaje; **bajo** en tarjetas con los datos actuales | Tope de tarjetas en **oct-2015** (tasa promedio 48% → 17%), pero los paneles por banco empiezan en 2016 | Media-alta / Media-baja | `cambios_regulatorios.csv` |
| 28 | **N7 Alivio COVID** | Intensidad de reprogramación por banco, instrumentada con exposición sectorial 2019 | **Moderado** (selección) | Cartera COVID ≈ 20 billones de Gs. (≈ 11% del crédito) en dic-2020; vencida ≈ 1,4 billones en 2022 | Media | `medidas_alivio.csv` |
| 29 | **N8 Canal de crédito bancario** | Heterogeneidad banco × sorpresa monetaria | **Moderado-alto** con N4 | — | Media → media-alta con N4 | `calendario_copom.csv` |
| 30 | **N9 SPI y efectivo** | Serie de tiempo interrumpida | **Bajo** (sin control; coincide con 2022) | SPI: 63,7 millones de operaciones/mes en 2026; ACH cae de 454 mil a 117 mil operaciones | Media (descriptivo) | `hitos_spi.csv` |
| 31 | **N10 Combustibles y expectativas** | Componente discrecional del ajuste (residuo de la regla con petróleo y tipo de cambio) | **Moderado** | 41 variaciones del gasoil > 3% desde 2015; +15% y +17% en mar–abr 2026 | Media | `ajustes_combustibles.csv` |
| 32 | **N11 Salario mínimo** | Eventos fechados con intensidad variable; servicios vs. bienes | **Moderado** (ajuste anticipado por fórmula) | 12 ajustes desde 2010 (3,4%–10,8%); sin ajuste en 2020 | Media | `decretos_salario_minimo.csv` |
| 33 | **N12 Remesas** | Shift-share por país de origen | **Moderado** en la primera etapa; débil en consumo | — | Media-baja | — |

**Ideas evaluadas y descartadas:**
- **Inversión directa por país y sector** (1995–2024, anual): anual y sin variación suficiente; puede incorporarse a N3.
- **Confianza del consumidor como indicador adelantado**: requiere evaluación en tiempo real (vintages), excluida por tu instrucción.

---

## 5. Hoja de ruta para los datos que conseguirás mañana

Cada carpeta que necesita información institucional tiene una plantilla en `datos_manuales/`. **Complétala con fechas AAAA-MM-DD y vuelve a correr `R/01_extraer_datos.R`**: el script valida las fechas, copia el archivo a `datos/manual_<nombre>.csv` y lo registra en el manifiesto. Los archivos que completes nunca se sobrescriben.

| Prioridad | Información | Archivo(s) | Proyectos que se benefician | Cómo contrastarla |
|---|---|---|---|---|
| 1 | **Reuniones del COPOM** (fecha, fecha y hora del anuncio, TPM anterior y nueva, ordinaria/extraordinaria) | `25_n4_…/datos_manuales/calendario_copom.csv` y `29_n8_…/datos_manuales/calendario_copom.csv` (mismo formato: copiar el mismo archivo) | N4, N8, A1, C2, E3, B2 | Comparar con `25_n4_…/datos/fechas_candidatas_cambio_tpm.csv` (40 fechas inferidas) |
| 2 | **Cambios de encaje legal** (fecha de vigencia y de anuncio, moneda, plazo, tasa anterior y nueva, resolución) y **tope de tasas de tarjetas** (ley, reglamentación, fórmula, fecha) | `27_n6_…/datos_manuales/cambios_regulatorios.csv` | N6, C2, C1, A1 | El tope debería caer en oct-2015 (quiebre en las tasas del sistema) |
| 3 | **Medidas de alivio crediticio** (COVID 2020 y posteriores por sequía/inundación) | `28_n7_…/datos_manuales/medidas_alivio.csv` | N7, D5, C1 | La cartera COVID aparece en el panel desde 2020-03/04 |
| 4 | **Ajustes de precios de combustibles** (Petropar y privados) | `31_n10_…/datos_manuales/ajustes_combustibles.csv` | N10, D4 | `ajustes_gasoil_inferidos.csv` |
| 5 | **Decretos de salario mínimo** (fecha de decreto y vigencia, monto, criterio) | `32_n11_…/datos_manuales/decretos_salario_minimo.csv` | N11, N2 | `salario_minimo_tramos_vigencia.csv` (de la base) |
| 6 | **Hitos del SPI** (entrada de entidades, QR, alias, límites, iniciadores de pago) | `30_n9_…/datos_manuales/hitos_spi.csv` | N9, F4 | Primer dato del boletín: 2022-05 |
| 7 | **Eventos cambiarios argentinos** (verificar los 9 candidatos y agregar magnitudes) | `26_n5_…/datos_manuales/eventos_argentina.csv` | N5, F2 | `episodios_devaluacion_argentina_inferidos.csv` |
| 8 | Historia oficial de la **meta de inflación** (y si hubo cambio a 3,5% en 2025) | `16_e3_…/R/01_extraer_datos.R` (tabla `meta` dentro del script) | E3, D4 | La mediana EVE a 24 meses pasa de 4,0% a 3,5% en 2025-01 |
| 9 | **Boletines SIB 2011–2015** (si están disponibles en archivo) | nuevo insumo para la base | N6 (tarjetas), C1, C2, D5, N7, N8 | — |

---

## 6. Notas de reproducibilidad y operación

- Cada carpeta se regenera con `Rscript R/01_extraer_datos.R` desde la carpeta del proyecto, o con `source()` en RStudio. El script abre la base solo en lectura y descarga de nuevo las variables de NOAA/FRED (con caché en `datos/fuentes_externas/`).
- `datos/00_manifiesto.csv` registra filas, rangos, esquema y build de la base de cada extracción; `datos/diccionario_series.csv`, el `candidate_id` y el nivel de verificación de cada serie.
- **Espacio en disco:** tras cada reconstrucción de la base ejecuta `git add database/paraguay_macro_pilot.duckdb*` (o haz commit). Si no, Git LFS vuelve a acumular copias de 1 GB en `.git/lfs/tmp` cada vez que algo consulta `git diff`.
- Las carpetas suman ≈ 730 MB; las más pesadas (C1, C2, C3, F2, N6, N7, N8) lo son por los paneles por entidad y las transacciones.
- Todos los scripts comparten las mismas funciones comunes (incluida `leer_manual()` para los datos manuales).
