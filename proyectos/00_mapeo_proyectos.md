# Mapeo preliminar: proyectos del portafolio × datos disponibles

*Fase 1 — reconocimiento, 2026-09-22. Base: `paraguay_macro_pilot.duckdb`, esquema 49, SHA-256 `c902c77f…4f50`.*

> **Actualización 2026-09-24.** La base no cambió (mismo SHA-256). Se marcan con **⊕** las variables que antes faltaban y hoy existen **fuera de la base**: el bloque clima/agro en `data/clima/` y las adquisiciones en `input/acquisition_candidates/`. Ver `00_inventario_base.md` § 6. Son datos externos, sin revisión de un economista, y no están integrados a DuckDB. En la tabla resumen, la viabilidad nueva va en negrita después de «→»; los proyectos N1–N12 están en `00_resumen_viabilidad.md`.

> **Actualización 2026-09-25.** La base sigue igual. Nuevas fuentes fuera de la base, marcadas **⊕ (2026-09-25)**:
> - **Calendario del CPM completo** 2010-01 → 2026-07 (196 decisiones; `input/acquisition_candidates/web_brechas_2026-09-23/extraidos/`).
> - **Calendario institucional del BCP** 2011–2026: compilación del usuario verificada en parte, **local y no publicada** (`input/acquisition_candidates/eventos_bcp_usuario_2026-09-25/`; en Git solo README y scripts). Cubre meta, encaje, alivios, pautas cambiarias 2014–2018, tarjetas y SPI, más 11 eventos agregados (COVID de marzo de 2020 y estructura del corredor, 5 inferidos de la serie diaria).
> - **Panel por entidad 2011–2015** de los boletines SIB, con vínculos a los códigos de la base aprobados por el usuario (`input/acquisition_candidates/boletines_sib_2011_2015/`).
> - **ERA5-Land**: 246 de 548 meses descargados; temperatura y SPEI siguen pendientes.

Cómo leer este documento:

- **Variables necesarias** salen de la pregunta, el estimando y la "escalera de datos" de cada ficha (niveles *mínimo* y *suficiente*; los niveles *ideal* y *óptimo* casi nunca están en la base y se mencionan solo cuando algo existe).
- **Estado**: ✅ disponible · 🟡 parcial o proxy · ❌ ausente.
- **Nivel** de verificación según [`00_inventario_base.md`](00_inventario_base.md): *Validada* (validada por regla) · *Prelim.* (preliminar) · *No compr.* (no comprobada) · *Especial* (panel/evento/curva, provisional).
- La **viabilidad** es preliminar y se refiere al *ejercicio inicial* de cada ficha con los datos que ya existen. Se confirmará en la Fase 2.

## Resumen

| # | Ficha | Carpeta propuesta | Prioridad del portafolio | Viabilidad preliminar | Cuello de botella principal |
|---|---|---|---|---|---|
| 01 | A1 Demanda de reservas y liquidez FX | `01_a1_reservas_liquidez` | A | **Media** | Reservas bancarias en el BCP solo mensuales; ⊕ calendario de encaje y corredor (2026-09-25, parcial) |
| 02 | B1 Intervención cambiaria | `02_b1_intervencion_fx` | B | **Media** | Compensatorias solo mensuales; ⊕ pautas anunciadas 2014–2018 (2026-09-25) |
| 03 | B2 Marco multi-horizonte PYG/USD | `03_b2_tc_multihorizonte` | A | **Alta** | Falta dólar amplio (DXY) e IPC de EE.UU. |
| 04 | B3 Flujo de órdenes y microestructura | `04_b3_flujo_ordenes_fx` | C | **Baja** | No existe flujo firmado por agente |
| 05 | C1 Liquidez USD, dolarización y descalce | `05_c1_liquidez_usd_descalce` | B | **Media** | Sin plazo residual, fondeo externo validado ni cobertura del prestatario; ⊕ panel por entidad 2011–2015 (boletines SIB) |
| 06 | C2 Depósitos, crédito y sustitución | `06_c2_depositos_credito` | A | **Media-alta** (bancos) / Baja → **Media-baja** (cooperativas) | Tasas solo a nivel sistema; cooperativas ⊕ panel anual INCOOP 2017–2025 |
| 07 | C3 Bonos corporativos, banca y deuda pública | `07_c3_bonos_deuda_publica` | B | Media → **Media-alta** | ⊕ subastas del Tesoro 2006–2026 y *security master*; tenencias solo en 4 cortes |
| 08 | C4 Riesgo bancario y repricing | `08_c4_repricing_riesgo` | B | **Baja** | Sin tasa fija/variable ni fechas de reajuste |
| 09 | D1 ENSO no lineal | `09_d1_enso_no_lineal` | A | Media → **Alta** | ⊕ ONI/RONI/MEI/SOI y clima local; límite: pocos episodios ENSO |
| 10 | D2 Clima por calendario agrícola | `10_d2_clima_calendario_agricola` | B | Baja → **Media-alta** | ⊕ lluvia, SPI y NDVI por departamento, producción MAG por departamento y calendario; temperatura y SPEI en descarga (246/548 meses al 2026-09-25) |
| 11 | D3 Pronósticos ENSO y sorpresas | `11_d3_pronosticos_enso` | B | Baja → **Media** | ⊕ vintages 2003–2025-04 (dos productos distintos); sin datos desde 2025-05 |
| 12 | D4 Inflación climática y riesgo de cola | `12_d4_inflacion_climatica` | B | Media → **Media-alta** | ⊕ ponderaciones oficiales del IPC (465 artículos), clima y precios mayoristas; faltan microprecios |
| 13 | D5 Clima y riesgo de crédito | `13_d5_clima_riesgo_credito` | B | **Media** (stress test descriptivo) / **Baja** (causal) | ⊕ clima por departamento, pero falta la geografía de la cartera; ⊕ panel por entidad 2011–2015 y medidas de alivio fechadas (2026-09-25) |
| 14 | E1 Combinación y reconciliación del PIB | `14_e1_combinacion_pib` | A | **Media** | No hay archivo de pronósticos; hay que generarlos |
| 15 | E2 Vintages, nowcasting y juicio | `15_e2_vintages_nowcasting` | A | **Baja** | La base tiene un único vintage por fuente |
| 16 | E3 Desacuerdo y anclaje de expectativas | `16_e3_expectativas_anclaje` | A | **Media** (agregado) | EVE sin dispersión ni n; ⊕ historia de la meta fuera de la base (2026-09-25) |
| 17 | F1 Facturación electrónica y pagos | `17_f1_facturacion_electronica` | C | **Baja** | Ningún dato SIFEN ni de firma |
| 18 | F2 Precios de importación y frontera | `18_f2_pass_through_frontera` | B | **Media** (agregado) / Baja → **Media** (frontera) | ⊕ aduanas a nivel ítem 1997–2026 por aduana y origen; sin moneda de factura ni precios regionales |
| 19 | F3 Río, logística e hidroelectricidad | `19_f3_rio_logistica` | B | Baja → **Media** (logística) / Media → **Media-alta** (energía) | ⊕ nivel del río diario 1904–2026 e Itaipú; faltan fletes, restricciones de navegación y Yacyretá |
| 20 | F4 Pagos instantáneos (SPI) | `20_f4_pagos_instantaneos` | C | **Media** (monitoreo) / **Baja** (causal) | Datos mensuales por entidad, no cliente-día; ⊕ hitos del SPI (2026-09-25) |
| 21 | F5 Inflación desigual y comunicación | `21_f5_inflacion_desigual` | A (N9) / C (N10) | **Media** (N9) / **Baja** (N10) | ⊕ ponderaciones oficiales por artículo; faltan ponderadores por grupo de hogares (EPF 2015/16) |

---

## 01 · A1 — Demanda de reservas y huella de liquidez de operaciones FX

**Pregunta:** cómo responden el spread interbancario, el uso de facilidades y las condiciones bancarias ante escasez de reservas o sorpresas de liquidez por liquidación FX. **Estimando:** curva reservas-spread y respuesta dinámica a innovación neta de reservas. Evidencia descriptiva y de forma reducida.

| Variable necesaria | Estado | Serie / tabla en la base | Frec. y rango | Nivel |
|---|---|---|---|---|
| Tasa de política (TPM) | ✅ | `economic_annex` Cuadro 19 (etiqueta contaminada; valores coherentes) | M 2011-05 → 2026-07 | Prelim. |
| Corredor: FPL y FPD (tasa y monto) | ✅ | Cuadro 19 (mensual); `interbank_market` hoja Datos (diario) | M 2012–2026; D 2013–2026 | Prelim. / Especial |
| Tasa interbancaria (TIB), call PYG/USD, REPO interbancario y tripartito: tasas, montos, nº de operaciones | ✅ | `interbank_market` (explore.events); Cuadro 19 (TIB mensual) | D 2010-01 → 2026-08 | Especial |
| Reservas bancarias en el BCP (encaje legal MN/ME, cuenta corriente) | 🟡 solo mensual | Cuadro 27 (depósitos del sistema financiero en el BCP); Cuadro 18 | M 1994 → 2026-06 | Prelim. (unidades ME sin resolver) |
| Esterilización: colocaciones de IRM/LRM por plazo, saldos y tasas | ✅ | Cuadro 19 (montos, saldos, tasas por plazo); `lrm_auctions` (subasta a subasta) | M 1993–2026; eventos 2013–2026 | Prelim. / Especial |
| Operaciones FX del BCP (compra/venta por sector) | ✅ | `bcp_fx_daily`; Cuadro 20; `fx_operations` | D 2013-01 → 2026-08; M 1995– | Prelim. |
| Subastas de liquidez de corto plazo | ✅ (histórico) | `liquidity_facility` | 2016-01 → 2021-09 | Especial |
| Depósitos del sector público en el BCP (proxy de flujos del Tesoro) | 🟡 mensual | Cuadro 35; Cuadro 18 | M 1994 → 2026-05 | Prelim. |
| Pagos SIPAP agregados | 🟡 mensual | `payments` SIPAP_01/02 | M 2013-11 → 2026-07 | Prelim. |
| Resultados bancarios (banco-mes) | ✅ | Paneles `banks` EEFF, Ratios, Carteras | M 2016-01 → 2026-07 | Especial |
| Reservas internacionales (control) | ✅ | Cuadro 56a/56b; `imf_irfcl` | M 1994 → 2026-08 | Prelim. |
| Reservas diarias, cuentas intradía | ❌ | — | — | — |
| Calendario de regímenes: encaje y estructura del corredor fechados | ⊕ 🟡 | fuera de la base (2026-09-25): calendario del usuario, familias Encaje y Corredor (local). Cambios de spread de 2013, 2015 y 2019 **inferidos** de la serie diaria FPD/FPL, sin documento; falta la matriz completa de encaje | eventos 2010 → 2021 | Externa (compilación) |

**Brechas clave:** saldos diarios de reservas bancarias; flujos diarios del Tesoro; documentos de los cambios del corredor y matriz completa de encaje (el calendario ya existe en parte, ⊕ 2026-09-25). **Viabilidad preliminar: Media** — el lado de precios (tasas) es diario y rico; la variable de cantidad (reservas) es mensual, lo que limita la curva reservas-spread a frecuencia mensual.

## 02 · B1 — Intervención cambiaria y eficacia

**Pregunta:** efecto dinámico de una operación FX mejor identificada sobre retorno, volatilidad y colas del PYG/USD. **Estimando:** respuesta acumulada por monto y tipo de operación.

| Variable necesaria | Estado | Serie / tabla | Frec. y rango | Nivel |
|---|---|---|---|---|
| Monto, fecha y dirección de operaciones del BCP | ✅ | `bcp_fx_daily` (compra/venta/neto con sector público y financiero) | D 2013-01-02 → 2026-08-14 | Prelim. |
| Tipo: compensatoria vs. complementaria | 🟡 solo mensual | `compensatory_fx_sales` | M 2015-01 → 2026-07 | Prelim. |
| Tipo de cambio diario | ✅ | `tcn_referential_daily` (compra/venta) | D 2012-08-06 → 2026-08-25 | Prelim. |
| Presión cambiaria previa, volatilidad | 🟡 construible | a partir del TCN diario | D | — |
| Proxies de intervención comparables | ✅ | `imf_wpfxi` (FMI, Paraguay y región) | M/T 2000 → 2024 | Prelim. |
| Controles regionales (BRL, ARS) | 🟡 solo mensual | Cuadro 60a; `exchange_rates`; `imf_er` | M | Prelim. |
| Controles globales diarios (DXY, VIX, soja) | ❌ | — | — | — |
| Anuncios de pautas compensatorias y complementarias | ⊕ 🟡 | fuera de la base (2026-09-25): calendario del usuario (local), 44 pautas 2014–2018 y 3 complementarias de 2015; faltan 2011–2013 y 2019–2026. Son montos **ofrecidos**, no ejecutados | eventos 2014 → 2018 | Externa (compilación) |
| Hora de ejecución, spreads, profundidad | ❌ | — | — | — |

**Brechas clave:** clasificación diaria compensatoria/complementaria; pautas anunciadas fuera de 2014–2018; controles globales diarios. **Viabilidad preliminar: Media** — la cronología diaria y el event study condicionado son factibles; la identificación causal no.

## 03 · B2 — Marco multi-horizonte del guaraní-dólar

**Pregunta:** qué variables explican y predicen el PYG/USD por horizonte. **Estimando:** contribuciones y desempeño fuera de muestra frente a random walk. ECM/BEER mensual, luego BVAR.

| Variable necesaria | Estado | Serie / tabla | Frec. y rango | Nivel |
|---|---|---|---|---|
| PYG/USD mensual (promedio) | ✅ | `exchange_rates` USD Prom compra/venta | M 1989-01 → 2026-07 | **Validada** |
| PYG/USD diario | ✅ | `tcn_referential_daily` | D 2012-08 → 2026-08 | Prelim. |
| Tipo de cambio real multilateral y bilaterales (EE.UU., Brasil, Argentina) | ✅ | Cuadro 60b, 60c | M 1995-01 → 2026-06 | **Validada** |
| PYG/BRL, PYG/ARS, PYG/EUR | ✅ | Cuadro 60a; `exchange_rates` | M 1994/1997 → 2026-07 | Prelim. |
| Brasil y Argentina: tipo de cambio, IPC, PIB, tasas | ✅ | `imf_er`, `imf_cpi`, `imf_qnea`, `imf_mfs_ir`; Selic en `financial_indicators` hoja 8 | M/T hasta 2026 | Prelim. |
| Commodities (soja, maíz, carne, petróleo) y términos de intercambio | ✅ | Cuadro 49; `imf_pcps`; `imf_ctot` | M 1994 → 2026-08 | Prelim. |
| Inflación doméstica (IPC, subyacente) | ✅ | Cuadro 15 | M 1993 → 2026-07 | **Validada** |
| Tasas domésticas y externas | 🟡 | TPM (Cuadro 19); Fed (rango), SOFR (`financial_indicators` hoja 8, 2016–) | M | Prelim. |
| Comercio exterior | ✅ | Cuadros 43–54; exportaciones totales (Cuadro 46a) | M 1994 → 2026-07 | Validada (total exp.) / Prelim. |
| Actividad (IMAEP) | ✅ | Cuadro 9 (1994–) y 9 a (2014–, ajustada) | M → 2026-06 | **Validada** (9 a) |
| Intervención | ✅ | `bcp_fx_daily`, Cuadro 20 | D/M | Prelim. |
| Expectativas de tipo de cambio | ✅ | `eve` (mes, próximo mes, año t, t+1) | M 2011-11 → 2026-08 | Prelim. |
| Forwards (volúmenes por residente/no residente) | 🟡 volúmenes, no precios | Cuadro 61 | M 2015-07 → 2026-07 | Prelim. |
| Dólar amplio (DXY), IPC de EE.UU., rendimientos del Tesoro de EE.UU. | ❌ | — | — | — |

**Brechas clave:** DXY/dólar amplio y variables de EE.UU.; precios forward. **Viabilidad preliminar: Alta** — el núcleo mensual está completo y parte está validado. Existe un paquete previo en `research_projects/b2_fx_multihorizon`.

## 04 · B3 — Flujo de órdenes, posiciones bancarias y microestructura FX

**Pregunta:** impacto del flujo FX firmado por tipo de agente sobre el PYG/USD. **Variable central:** flujo neto firmado; la ficha dice explícitamente que no tiene sustituto.

| Variable necesaria | Estado | Serie / tabla | Frec. y rango | Nivel |
|---|---|---|---|---|
| Flujo neto firmado por tipo de agente | ❌ | — | — | — |
| Compras y ventas del mercado local por tipo de entidad y operación (spot, forward residente/no residente, arbitraje, canje) | 🟡 volumen, no flujo iniciado | Cuadro 61 (170 series) | M 2004/2015 → 2026-07 | Prelim. |
| Turnover diario interbancario USD | 🟡 | `interbank_market` call USD | D 2011 → 2026-02 | Especial |
| Posición en ME de bancos | 🟡 mensual | Panel `banks` EEFF moneda 6200 | M 2016 → 2026 | Especial |
| Casas de cambio | 🟡 | `exchange_houses` (EEFF anual; resto solo 2026-06) | A | Especial |
| Trades, cotizaciones, posiciones intradía | ❌ | — | — | — |

**Viabilidad preliminar: Baja** — solo puede hacerse la etapa de "validar definición y cobertura" con compras-ventas brutas mensuales; la ficha misma dice que el turnover no sirve como flujo.

## 05 · C1 — Liquidez dólar, dolarización y descalce cambiario

**Pregunta:** cómo amplifican la vulnerabilidad de liquidez USD y el descalce del prestatario los shocks externos hacia tasas, crédito y default. **Unidad:** banco-mes.

| Variable necesaria | Estado | Serie / tabla | Frec. y rango | Nivel |
|---|---|---|---|---|
| Activos, depósitos, crédito, capital por moneda y banco | ✅ | Panel `banks`/`financial` EEFF (6200 vs 6900) | M 2016-01 → 2026-07 | Especial |
| NPL por moneda y banco | ✅ | Ratios (Morosidad MN/ME); Carteras (vencida) | M 2016 → 2026 | Especial |
| Crédito banco × sector × moneda | ✅ | Credito Sector (13 sectores) | M 2016 → 2026 | Especial |
| Categorías de riesgo, refinanciados, reestructurados | ✅ | Categoría Creditos; Carteras | M 2016 → 2026 | Especial |
| Tasas por moneda y plazo (sistema) | ✅ | `financial_indicators` 1.x–3.x | M 2011 → 2026-06 | Prelim. |
| Dolarización agregada de depósitos y crédito | ✅ | Cuadros 23, 24, 25, 30 | M 1995 → 2026-06 | Prelim. (unidades ME sin resolver) |
| Shocks externos (Fed, SOFR, BRL, commodities) | 🟡 | `financial_indicators` hoja 8; Cuadro 49; Cuadro 60a | M | Prelim. |
| Fondeo externo por banco | 🟡 por identificar | rubros de EEFF (préstamos del exterior) — por validar | M | Especial |
| Panel por entidad antes de 2016 (activo, pasivo, cartera por moneda) | ⊕ ✅ | fuera de la base (2026-09-25): boletines SIB 2011–2015 en formato largo, vínculos con los códigos de la base aprobados | M 2011-01 → 2015-12 | Externa (sin revisión de series) |
| Plazo residual, originaciones, cobertura natural, exportador | ❌ | — | — | — |

**Viabilidad preliminar: Media** — el panel banco-moneda-sector (nivel "mínimo" completo) existe desde 2016; la dimensión prestatario no. Existe un paquete previo en `research_projects/c1_bank_fx_exposure`.

## 06 · C2 — Depósitos, crédito y sustitución entre intermediarios

**Pregunta:** cómo cambia el fondeo (precio, cantidad y moneda) ante la política monetaria y qué pasa con el crédito. **Estimando:** beta de depósitos y sustitución entre tipos de prestamista.

| Variable necesaria | Estado | Serie / tabla | Frec. y rango | Nivel |
|---|---|---|---|---|
| Tasas de depósito por producto, plazo y moneda | ✅ nivel sistema | `financial_indicators` 1.1–3.2 (bancos), 5–6 (financieras); CDA (Cuadro 31) | M 2011-01 → 2026-06 | Prelim. / **Validada** (C31 ME) |
| Curva CDA por plazo (ML/ME) y volumen | ✅ | `cda_curve` | M 2018-01 → 2026-07 | Especial |
| Depósitos por moneda e instrumento (agregado) | ✅ | Cuadros 23, 23a | M 1995 → 2026-06 | Prelim. |
| Depósitos y crédito banco-mes por moneda y producto | ✅ | Paneles `banks`, `financial` (Carteras: vista, plazo fijo, CDA) | M 2016 → 2026-07 | Especial |
| Tasa de política | ✅ | Cuadro 19 | M 2011 → 2026-07 | Prelim. |
| Crédito por tipo de entidad | 🟡 | bancos, financieras (paneles); cooperativas Tipo A (Cuadros 23b/24b, agregado) | Coop.: M 2017-12 → 2025-11 | Prelim. |
| Tasas por banco | ❌ | solo máximo/mínimo/promedio del sistema | — | — |
| Depósitos y crédito por entidad 2011–2015 | ⊕ ✅ | fuera de la base (2026-09-25): boletines SIB (bancos, financieras, casas de cambio); tasas promedio por producto del sistema 2011–2013 | M 2011-01 → 2015-12 | Externa |
| Panel de cooperativas por entidad (INCOOP) | ⊕ 🟡 | fuera de la base: balances por cooperativa tipo A (`web_no_clima_2026-09-23/raw/incoop`) | A 2017–2024; T 2025 | Externa (INCOOP: «referencial, no validado») |

**Viabilidad preliminar: Media-alta** para la versión bancaria (betas por producto-moneda y flujos banco-mes); **baja** para la sustitución banca-cooperativas.

## 07 · C3 — Bonos corporativos, crédito bancario y deuda pública

**Pregunta:** spread bono-banco ajustado y su respuesta a condiciones monetarias; elasticidad de rendimientos a oferta inesperada del Tesoro.

| Variable necesaria | Estado | Serie / tabla | Frec. y rango | Nivel |
|---|---|---|---|---|
| Curvas por calificación, moneda y plazo | ✅ | `corporate_bond_curves` (PYG: AAA–B; USD: AAA–BB; parámetros NSS) | irregular 2010-11 → 2026-07 | **Validada (estructural)** |
| Curva CDA (soberano-bancaria de corto plazo) | ✅ | `cda_curve` | M 2018 → 2026 | Especial |
| Tasas bancarias por plazo | ✅ | `financial_indicators` 2.1/2.2 | M 2011 → 2026-06 | Prelim. |
| Transacciones secundarias con emisor e ISIN | ✅ | `securities_trades` (bonos corporativos, subordinados, financieros, Tesoro desde 2023) | 2010 → 2026-08 | **Validada (estructural)** |
| Subastas de LRM (BCP) | ✅ | `lrm_auctions` | 2013 → 2026-07 | Especial |
| Resultados de subastas de bonos del Tesoro (ofertas, adjudicación, rendimiento) | ⊕ ✅ | fuera de la base: MEF, resultado de subastas por subasta (`web_no_clima_2026-09-23/raw/mef/bonos`) | eventos 2006–2026 (sin subastas en 2011) | Externa |
| Deuda pública | 🟡 | Cuadro 59 (deuda externa); MEF: incurrimiento neto de pasivos | M 1994/2003 → 2026 | Prelim. |
| Security master (emisor, vencimiento, cupón), holdings bancarios | ⊕ 🟡 | fuera de la base: condiciones financieras de 194 emisiones del Tesoro; tenencias por tenedor (dic-2023, dic-2024, dic-2025, ago-2026) | cortes | Externa |

**Viabilidad preliminar: Media** — el módulo bonos-banca tiene curvas y transacciones; el módulo deuda pública no tiene subastas del Tesoro.

## 08 · C4 — Riesgo bancario, repricing contractual y toma de riesgo

**Pregunta:** si la política laxa cambia el riesgo ex ante de nuevas aprobaciones y si los shocks de tasa afectan la mora vía reajuste. **Mínimo:** stocks por tipo de tasa, madurez y moneda, y NPL.

| Variable necesaria | Estado | Serie / tabla | Frec. y rango | Nivel |
|---|---|---|---|---|
| Stocks por tipo de tasa (fija/variable) | ❌ | — | — | — |
| Stocks por madurez y moneda | 🟡 sistema | `financial_indicators` 4 y 7 (saldos por plazo y cartera) | M 2011 → 2026-06 | Prelim. (unidades ME sin resolver) |
| NPL, refinanciados, reestructurados, categorías de riesgo por banco | ✅ | Paneles `banks`: Carteras, Categoría Creditos, Ratios | M 2016 → 2026-07 | Especial |
| Tasa de política y tasas activas | ✅ | Cuadro 19; Cuadro 31 | M | Prelim. / **Validada** |
| Contratos, fechas de reset, solicitudes | ❌ | — | — | — |

**Viabilidad preliminar: Baja** — solo cabe un stress test descriptivo por cohortes de plazo a nivel sistema.

## 09 · D1 — ENSO no lineal y respuestas macroeconómicas

**Pregunta:** cómo se asocian actividad, sectores e inflación con la intensidad y fase ENSO. LP mensuales con splines por fase.

| Variable necesaria | Estado | Serie / tabla | Frec. y rango | Nivel |
|---|---|---|---|---|
| IMAEP total y sectores | ✅ | Cuadro 9 (1994–); Cuadro 9 a (2014–; primario, secundario, manufactura, servicios; original, ajustada, tendencia) | M → 2026-06 | **Validada** (9 a) / Prelim. (9) |
| PIB trimestral por sector (agricultura, ganadería, binacionales) | ✅ | Cuadros 6, 6 a | T 1994 → 2026-T1 | **Validada** (total) / Prelim. |
| IPC total, alimentos, frutas y verduras, subyacente | ✅ | Cuadros 13 a, 14 b, 15 | M 1988/1993 → 2026-07 | **Validada** (C15) / Prelim. |
| Exportaciones agrícolas en volumen (soja, maíz, trigo) | ✅ | Cuadro 44b | M 1994 → 2026-07 | Prelim. |
| Precios internacionales de alimentos | ✅ | Cuadro 49; `imf_pcps` | M 1994 → 2026-08 | Prelim. |
| Tipo de cambio, EVE | ✅ | `exchange_rates`; `eve` | M | Validada / Prelim. |
| ONI u otro índice ENSO | ⊕ ✅ | fuera de la base: `data/clima/enso_indices.csv` (ONI, RONI, MEI.v2, SOI, Niño 3.4) | M 1950 → 2026-08 | Externa |

**Viabilidad preliminar: Media** (Alta en cuanto se incorpore ONI, que es una serie pública y estable). Riesgo principal: el IMAEP largo (Cuadro 9) y el de 2014 (9 a) pueden tener cambio de base.

## 10 · D2 — Clima por calendario agrícola y transmisión sectorial

| Variable necesaria | Estado | Serie / tabla | Frec. y rango | Nivel |
|---|---|---|---|---|
| Clima mensual/diario nacional (lluvia, temperatura) | ⊕ ✅/🟡 | fuera de la base: CHIRPS, SPI y NDVI por departamento; temperatura y SPEI de ERA5-Land **en descarga** (246/548 meses al 2026-09-25) | M 1981 → 2026-08 | Externa |
| Producción anual de cultivos (soja, maíz, trigo) | ⊕ ✅ | fuera de la base: MAG por departamento y campaña (16–22 cultivos), FAOSTAT y USDA PSD nacionales; en la base, exportaciones en volumen (Cuadros 44b, 46b) y PIB agrícola (Cuadros 1, 6) como proxy | campaña 2007/08 → 2024/25; A 1961 → 2024 | Externa / Prelim. |
| Actividad agrícola | ✅ | IMAEP primario (9 a); PIB agricultura | M/T | Validada / Prelim. |
| IPC alimentos | ✅ | Cuadros 14 b, 15, 16 | M 1994 → 2026-07 | Prelim. |
| Calendarios de cultivo | ⊕ ✅ | fuera de la base: `data/clima/calendario_cultivos.csv` (soja y maíz zafra y zafriña, trigo, arroz; citas USDA verificadas) | estático | Externa |

**Viabilidad preliminar: Baja** — la variable física central no existe en la base. **Actualización 2026-09-24: Media-alta**, con los datos externos de `data/clima` (falta ERA5-Land, en descarga).

## 11 · D3 — Pronósticos ENSO, sorpresas y adaptación

| Variable necesaria | Estado | Serie / tabla | Nivel |
|---|---|---|---|
| Vintages de probabilidades ENSO (IRI/CPC) | ⊕ 🟡 | fuera de la base: `data/clima/enso_iri_pronosticos.csv` (IRI probabilístico 2003–2013; CPC/IRI oficial 2014–2025-04) | Externa |
| Outcomes macro/agro | ✅ | ver D1 | Validada / Prelim. |
| Crédito agrícola (proxy de adaptación) | ✅ | Credito Sector (agricultura, ganadería) banco-mes 2016– | Especial |

**Viabilidad preliminar: Baja** — la ficha exige vintages genuinos, que no existen en la base (sí existen públicamente en IRI desde 2002). **Actualización 2026-09-24: Media**, con 259 meses de vintages extraídos. Hay dos productos que no se pueden empalmar y faltan los datos desde 2025-05.

## 12 · D4 — Inflación climática, precios relativos y riesgo de cola

| Variable necesaria | Estado | Serie / tabla | Frec. y rango | Nivel |
|---|---|---|---|---|
| IPC headline, alimentos, subyacente | ✅ | Cuadro 15 (total y subyacente validados) | M 1993 → 2026-07 | **Validada** / Prelim. |
| Componentes: transables/no transables, servicios, renta, bienes libres/administrados, sin alimentos, IPCSAE | ✅ índices | Cuadros 14 a, 14 b, 14 c | M 1995/2003 → 2026-07 | Prelim. (las variaciones % son posicionales: No compr.) |
| Grupos de alimentos, carne (cortes) | ✅ | Cuadros 16, 16 a | M 1994 → 2026-07 | Prelim. |
| Ponderadores COICOP del IPC | ⊕ ✅ | fuera de la base: Anexo 2 de la metodología IPC base dic-2017, 465 artículos con jerarquía completa (`web_brechas_2026-09-23/extraidos/`); en la base, `imf_cpi` (pesos por división) | estático | Externa / Prelim. |
| Precios al productor | ✅ | Cuadro 17 (base marzo 2025) | M 1995-12 → 2026-06 | Prelim. |
| Precios mundiales de alimentos, FX, EVE, TPM | ✅ | Cuadro 49, `imf_pcps`, Cuadro 60a, `eve`, Cuadro 19 | M | Prelim. |
| ONI, clima | ⊕ ✅ | fuera de la base: `data/clima` (ENSO, lluvia, SPI; temperatura en descarga) | M | Externa |
| Precios mayoristas, microprecios | ⊕ 🟡 | fuera de la base: Mercado de Abasto, 6 rubros diarios por origen (`data/clima/abasto_*`); faltan los microprecios | D 2021 → 2026-06 | Externa |

**Viabilidad preliminar: Media** — el lado de precios es rico; depende de ONI externo y de auditar la jerarquía del IPC.

## 13 · D5 — Clima y riesgo de crédito

| Variable necesaria | Estado | Serie / tabla | Frec. y rango | Nivel |
|---|---|---|---|---|
| NPL por banco | ✅ | Ratios (Morosidad), Carteras (vencida) | M 2016 → 2026-07 | Especial |
| Participación sectorial de la cartera (agricultura, ganadería) por banco | ✅ | Credito Sector | M 2016 → 2026-07 | Especial |
| Crédito, provisiones, capital, liquidez por banco | ✅ | EEFF, Ratios | M 2016 → 2026-07 | Especial |
| Seguros agropecuarios (primas y siniestros) | 🟡 anual | `insurance_annex` 1.1, 1.8 (rama Agropecuario) | A 2009 → 2025 | Prelim. |
| Encuesta de crédito por sector (agricultura, ganadería) | ✅ | `credit_survey` | T 2013/2015 → 2026-06 | Prelim. |
| Panel banco-sector antes de 2016 y medidas de alivio fechadas | ⊕ 🟡 | fuera de la base (2026-09-25): boletines SIB 2011–2015 (por entidad; crédito por sector a confirmar) y medidas de alivio por sequía e inundaciones 2011–2025 del calendario del usuario (local) | M 2011 → 2015; eventos | Externa |
| ENSO/clima y geografía de la cartera | ⊕ 🟡 | fuera de la base: ENSO y clima por departamento (`data/clima`); la **geografía de la cartera sigue faltando** | M | Externa |

**Viabilidad preliminar: Media** para un stress test descriptivo banco-sector; **Baja** para inferencia causal (pocos episodios ENSO desde 2016 y sin geografía).

## 14 · E1 — Combinación y reconciliación de pronósticos del PIB

| Variable necesaria | Estado | Serie / tabla | Frec. y rango | Nivel |
|---|---|---|---|---|
| PIB trimestral por oferta (sectores) y por gasto, nominal y real | ✅ | Cuadros 6, 6 a, 7, 7 a (+ variaciones en "Cont.") | T 1994-T1 → 2026-T1 | **Validada** (totales) / Prelim. |
| PIB anual por sector y por gasto | ✅ | Cuadros 1, 2, 5 | A 1991 → 2025 | Validada / Prelim. (C5: 18 No compr.) |
| Matriz de agregación (summing matrix), discrepancia estadística | 🟡 construible | jerarquía no revisada en la base | — | — |
| Indicadores mensuales (IMAEP, ECN) | ✅ | Cuadros 9, 9 a, 10, 10 a | M | Validada / Prelim. |
| Archivo de pronósticos base y errores | ❌ | debe generarse (pseudo fuera de muestra) | — | — |

**Viabilidad preliminar: Media** — la jerarquía de cuentas existe; la evaluación será pseudo-real (datos finales), no real.

## 15 · E2 — Vintages, nowcasting, densidades y valor del juicio

| Variable necesaria | Estado | Nota |
|---|---|---|
| Vintages de datos | ❌ | La base guarda un único vintage por fuente; el mecanismo as-of existe pero está vacío |
| Calendario real de publicaciones | ❌ | `available_at` es un límite superior inferido, no una fecha de publicación |
| Pronósticos fechados, pre/post juicio | ❌ | — |
| Datos finales para nowcasting pseudo-real | ✅ | IMAEP, PIB, IPC, comercio, pagos, crédito (todas las fuentes mensuales) |

**Viabilidad preliminar: Baja** como proyecto de investigación hoy; es infraestructura: la base ya tiene la maquinaria de vintages (`config/acquisition_contracts.csv`) y habría que empezar a archivar.

## 16 · E3 — Desacuerdo y anclaje de expectativas

| Variable necesaria | Estado | Serie / tabla | Frec. y rango | Nivel |
|---|---|---|---|---|
| Expectativas de inflación corto/largo (mes, próximo mes, año t, t+1, 12 meses, 24 meses) | ✅ | `eve` | M 2006-04 → 2026-08 (horizontes largos desde 2014/2017) | Prelim. |
| Mediana, desviación, n de respuestas | ❌ | la EVE publicada trae un solo estadístico por variable | — | — |
| Meta de inflación y sus cambios | ⊕ ✅ | fuera de la base (2026-09-25): 5% ± 2,5 pp (2011) → ± 2 pp (2014) → 4,5% (anuncio 11-12-2014) → 4% (24-02-2017) → 3,5% ± 2 pp (16-12-2024); contrastada con los comunicados del CPM; falta confirmar la fuente de la banda de 2014 | eventos 2011 → 2024 | Externa (compilación) |
| Inflación realizada, TPM, expectativas de TPM y PIB | ✅ | Cuadro 15; Cuadro 19; `eve` | M | Validada / Prelim. |
| Expectativas de empresas y hogares | 🟡 | `credit_survey` (expectativa por sector); `icc` (IEE) | T 2015–; M 2018– | Prelim. |

**Viabilidad preliminar: Media** para la versión agregada (sensibilidad de la expectativa larga a sorpresas y event study de la meta); **Baja** para desacuerdo.

## 17 · F1 — Facturación electrónica, cadenas de pagos y formalización

| Variable necesaria | Estado | Serie / tabla | Nivel |
|---|---|---|---|
| Adopción SIFEN por firma, facturas, fechas de pago | ❌ | — | — |
| Formalidad del empleo (agregado) | 🟡 | `ine_ephc` FORMALIDAD | T 2017 → 2026-T2, Prelim. |
| Recaudación de IVA e impuestos (agregado) | 🟡 | `mef_central_government` | M 2003 → 2026-08, Prelim. |
| Cheques rechazados por causal (proxy de atrasos) | 🟡 | `payments` CCC 04 | M 2013 → 2026, Prelim. |

**Viabilidad preliminar: Baja** — sin microdatos; solo una descripción agregada de formalización.

## 18 · F2 — Precios de importación, arbitraje fronterizo e inflación

| Variable necesaria | Estado | Serie / tabla | Frec. y rango | Nivel |
|---|---|---|---|---|
| Importaciones por tipo de bien en USD y toneladas (valores unitarios) | ✅ | Cuadros 51 a/b, 52 a/b, 53 a/b | M 1994/2006 → 2026-07 | Prelim. |
| Importaciones por régimen (incluye turismo/reexportación) | ✅ | Cuadros 52 a/b, 54 | M 2003/2006 → 2026-07 | Prelim. |
| IPC de productos importados, nacionales, transables | ✅ | Cuadro 14 a | M 1995 → 2026-07 | Prelim. |
| Tipos de cambio bilaterales y TCR | ✅ | Cuadros 60a–60c | M | Validada / Prelim. |
| Comercio por país socio | 🟡 fuera de la base | IMTS.csv del FMI (no incorporado) | M/T | — |
| IPC de países vecinos | ✅ | `imf_cpi` (ARG, BRA) | M | Prelim. |
| Aduanas por transacción, moneda de factura, precios regionales o de frontera | ⊕ 🟡 | fuera de la base: DNA a nivel ítem (despacho cifrado, NCM, origen, aduana, FOB, impuestos); **sin** moneda de factura ni precios regionales | M 1997 → 2026-08 | Externa (sin procesar) |

**Viabilidad preliminar: Media** para pass-through agregado por tipo de bien; **Baja** para el mecanismo fronterizo.

## 19 · F3 — Río, logística, hidroelectricidad y transmisión real

| Variable necesaria | Estado | Serie / tabla | Frec. y rango | Nivel |
|---|---|---|---|---|
| Nivel del río, restricciones de navegación, fletes | ⊕ 🟡 | fuera de la base: nivel diario del río Paraguay en Asunción, Pilar y Concepción (`data/clima/rios_dmh_*`); hidrología y generación de Itaipú (`data/clima/hidro_itaipu_*`); **faltan** fletes y restricciones | D 1904 → 2026-09 | Externa |
| Comercio agregado y por producto | ✅ | Cuadros 43–54 | M 1994 → 2026-07 | Prelim. |
| Exportación de energía eléctrica (USD y kWh) | ✅ | Cuadros 44a, 44b | M 1994 → 2026-07 | Prelim. |
| Ingreso de divisas de binacionales | ✅ | Cuadro 55 | M 1994 → 2026-06 | Prelim. |
| Regalías y compensaciones de Itaipú y Yacyretá (fiscal) | ✅ | `mef_central_government` | M 2003 → 2026-08 | Prelim. |
| PIB de electricidad y agua (binacionales) | ✅ | Cuadros 1, 6 | A/T | Prelim. |
| IPC | ✅ | Cuadro 15 | M | Validada |

**Viabilidad preliminar: Baja** para el módulo logístico; **Media** para el módulo energético descriptivo.

## 20 · F4 — Pagos instantáneos, competencia y movilidad de depósitos

| Variable necesaria | Estado | Serie / tabla | Frec. y rango | Nivel |
|---|---|---|---|---|
| Volúmenes y montos SPI | ✅ | `payments` SIPAP_07 a SIPAP_12 (por día, franja horaria, funcionalidad) | M 2022-05 → 2026-07 | Prelim. |
| SPI por entidad | ✅ | SIPAP_08 (55 series; 52 no comprobadas por identidad posicional) | M 2022-05 → 2026-07 | No compr. |
| Alias registrados y operativos por entidad | ✅ | SIPAP_13–15 | M 2023 → 2026-07 | Prelim. |
| Otros rieles: LBTR, ACH, cheques, tarjetas | ✅ | SIPAP_01–06, CCC, OMP | M 2013/2018 → 2026-07 | Prelim. |
| Depósitos y liquidez por entidad | ✅ | Paneles `banks`, `financial` | M 2016 → 2026-07 | Especial |
| Bancarización (personas con cuenta) | ✅ | `banking_indicators` | M 2016 → 2026-06 | Prelim. |
| Hitos del SPI (piloto, 24/7, solicitud de pago, PY-QR, QR Hub, límites) | ⊕ ✅ | fuera de la base (2026-09-25): calendario del usuario (local); piloto 2022-05-23 y 24/7 2022-07-04 contrastados con otras fuentes | eventos 2012 → 2026 | Externa (compilación) |
| Datos cliente/entidad-día, fechas de adopción por entidad | ❌ | — | — | — |

**Viabilidad preliminar: Media** como tablero de monitoreo (así lo pide la ficha); **Baja** para inferencia causal.

## 21 · F5 — Inflación desigual (N9) y comunicación experimental (N10)

| Variable necesaria | Estado | Serie / tabla | Frec. y rango | Nivel |
|---|---|---|---|---|
| IPC por componentes (divisiones, grupos) | 🟡 | Cuadros 14 b, 16; `imf_cpi` Paraguay por división COICOP (índices y pesos) | M 1994 → 2026-07 | Prelim. |
| Ponderadores de gasto por grupo de hogares (quintil, área) | ❌ | Sigue faltando. La canasta oficial (base 2017) viene de la EPF 2015/16, sin microdatos públicos. Fuera de la base hay ponderadores por artículo para el hogar promedio. La EIGyCV 2011/12 se descartó. | — | — |
| Ingresos por grupo (para caracterizar grupos) | 🟡 | `ine_ephc` ingresos por categoría, ocupación y sector | T 2017 → 2026-T1 | No compr. |
| N10: aleatorización, creencias pre/post | ❌ | requiere diseño prospectivo | — | — |

**Viabilidad preliminar: Media** para N9 si se consiguen los pesos de la EIGH; **Baja** para N10.
