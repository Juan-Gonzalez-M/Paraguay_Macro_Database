# 24 · N3 (proyecto nuevo) — Paraguay en el panel regional: shocks globales, reservas, intervención y vulnerabilidad financiera

*Carpeta de datos generada por `R/01_extraer_datos.R` · 2026-09-22 20:16:26 · esquema 49 · build:481cb2d5c90afff4f1964f7f*

> **Proyecto no incluido en el portafolio original.** Lo propongo porque la base ya contiene, para **9 países sudamericanos** (Argentina, Bolivia, Brasil, Chile, Colombia, Ecuador, Paraguay, Perú y Uruguay), balanza de pagos, reservas, indicadores de solidez financiera (FSI), IPC, tipo de cambio, tipo de cambio real, términos de intercambio, tasas de política e intervención cambiaria del FMI, datos que ningún proyecto usa. Todos los proyectos del portafolio son de un solo país; este aporta la **variación entre países** que les falta a B1, B2 y C1 para separar lo común (shocks globales) de lo específico de Paraguay.

## 1. Resumen y pregunta de investigación

- **Preguntas:** (i) ¿cómo responden los flujos de capital, el tipo de cambio, la inflación, la mora y el capital bancario de cada país a shocks globales comunes (VIX, tasa Fed, dólar, commodities)? (ii) ¿amortiguan esas respuestas el nivel de reservas, la intervención cambiaria y la dolarización del crédito? (iii) ¿dónde se ubica Paraguay: es su respuesta excepcional una vez condicionada a sus características?
- **Estimandos:** respuestas medias y heterogéneas (interacciones con reservas/PIB, intervención y préstamos en ME) en proyecciones locales de panel; posición de Paraguay en la distribución regional.
- **Evidencia:** forma reducida con shocks globales comunes (más exógenos para economías pequeñas que los shocks domésticos) y efectos fijos de país.

## 2. Estrategia empírica propuesta

1. **Benchmarking descriptivo:** Paraguay frente a la mediana y el rango regional en cuenta corriente/PIB, entradas de IED, cartera y otra inversión, reservas, mora, capital, dolarización del crédito y posición abierta en ME (2005–2026).
2. **Proyecciones locales de panel (trimestral, 2005–2026):** `y_{i,t+h} = α_i + β_h · shock_global_t + γ_h · shock_t × X_{i,t−1} + controles + ε`, con `X` = reservas/PIB, intervención/PIB, préstamos ME/total. Resultados: flujos de capital (% del PIB), tipo de cambio, inflación, mora.
3. **Intervención cambiaria comparada:** usar los proxies homogéneos del FMI (WPFXI) para comparar la reacción de Paraguay con la de sus pares ante presiones cambiarias (complementa B1, que tiene el dato oficial diario).
4. **Términos de intercambio país-específicos:** shock de precios de commodities ponderado por la canasta exportadora de cada país (índice CTOT del FMI), con Paraguay y su canasta soja/carne/energía.
5. **Robustez:** excluir Argentina (inflación alta) y Ecuador (dolarizado) o tratarlos aparte; errores estándar de Driscoll-Kraay.

## 3. Series extraídas

Las series se nombran `<país>_<indicador>` (p. ej. `pry_fsi_mora`, `bra_cuenta_corriente`); la descripción incluye el código SDMX del FMI.

| Serie | Descripción | Fuente / tabla | Frec. | Desde | Hasta | Obs. | Unidad | Nivel de verificación | Rol en el modelo |
|---|---|---|---|---|---|---|---|---|---|
| `arg_cuenta_corriente` | Argentina: Saldo de cuenta corriente (millones USD; trimestral) [ARG.NETCD_T.CAB.USD.Q] | `imf_bop` NA | trimestral | 1976-01-01 | 2026-01-01 | 201 | US DOLLAR (Millions) | Preliminar | Vulnerabilidad externa |
| `bol_cuenta_corriente` | Bolivia: Saldo de cuenta corriente (millones USD; trimestral) [BOL.NETCD_T.CAB.USD.Q] | `imf_bop` NA | trimestral | 1977-01-01 | 2026-04-01 | 162 | US DOLLAR (Millions) | Preliminar | Vulnerabilidad externa |
| `bra_cuenta_corriente` | Brasil: Saldo de cuenta corriente (millones USD; trimestral) [BRA.NETCD_T.CAB.USD.Q] | `imf_bop` NA | trimestral | 1975-01-01 | 2026-04-01 | 206 | US DOLLAR (Millions) | Preliminar | Vulnerabilidad externa |
| `chl_cuenta_corriente` | Chile: Saldo de cuenta corriente (millones USD; trimestral) [CHL.NETCD_T.CAB.USD.Q] | `imf_bop` NA | trimestral | 1991-01-01 | 2026-01-01 | 141 | US DOLLAR (Millions) | Preliminar | Vulnerabilidad externa |
| `col_cuenta_corriente` | Colombia: Saldo de cuenta corriente (millones USD; trimestral) [COL.NETCD_T.CAB.USD.Q] | `imf_bop` NA | trimestral | 1996-01-01 | 2026-01-01 | 121 | US DOLLAR (Millions) | Preliminar | Vulnerabilidad externa |
| `ecu_cuenta_corriente` | Ecuador: Saldo de cuenta corriente (millones USD; trimestral) [ECU.NETCD_T.CAB.USD.Q] | `imf_bop` NA | trimestral | 1993-01-01 | 2026-01-01 | 133 | US DOLLAR (Millions) | Preliminar | Vulnerabilidad externa |
| `per_cuenta_corriente` | Perú: Saldo de cuenta corriente (millones USD; trimestral) [PER.NETCD_T.CAB.USD.Q] | `imf_bop` NA | trimestral | 1977-01-01 | 2025-10-01 | 172 | US DOLLAR (Millions) | Preliminar | Vulnerabilidad externa |
| `pry_cuenta_corriente` | Paraguay: Saldo de cuenta corriente (millones USD; trimestral) [PRY.NETCD_T.CAB.USD.Q] | `imf_bop` NA | trimestral | 2000-01-01 | 2026-01-01 | 105 | US DOLLAR (Millions) | Preliminar | Vulnerabilidad externa |
| `ury_cuenta_corriente` | Uruguay: Saldo de cuenta corriente (millones USD; trimestral) [URY.NETCD_T.CAB.USD.Q] | `imf_bop` NA | trimestral | 2000-01-01 | 2026-01-01 | 105 | US DOLLAR (Millions) | Preliminar | Vulnerabilidad externa |
| `arg_cuenta_financiera_sin_reservas` | Argentina: Saldo de la cuenta financiera excluyendo reservas (millones USD) [ARG.NNAFANIL_T.FABXRRI.USD.Q] | `imf_bop` NA | trimestral | 1976-01-01 | 2026-01-01 | 201 | US DOLLAR (Millions) | Preliminar | Flujos de capital netos |
| `bol_cuenta_financiera_sin_reservas` | Bolivia: Saldo de la cuenta financiera excluyendo reservas (millones USD) [BOL.NNAFANIL_T.FABXRRI.USD.Q] | `imf_bop` NA | trimestral | 1977-01-01 | 2026-04-01 | 162 | US DOLLAR (Millions) | Preliminar | Flujos de capital netos |
| `bra_cuenta_financiera_sin_reservas` | Brasil: Saldo de la cuenta financiera excluyendo reservas (millones USD) [BRA.NNAFANIL_T.FABXRRI.USD.Q] | `imf_bop` NA | trimestral | 1975-01-01 | 2026-04-01 | 206 | US DOLLAR (Millions) | Preliminar | Flujos de capital netos |
| `chl_cuenta_financiera_sin_reservas` | Chile: Saldo de la cuenta financiera excluyendo reservas (millones USD) [CHL.NNAFANIL_T.FABXRRI.USD.Q] | `imf_bop` NA | trimestral | 1991-01-01 | 2026-01-01 | 141 | US DOLLAR (Millions) | Preliminar | Flujos de capital netos |
| `col_cuenta_financiera_sin_reservas` | Colombia: Saldo de la cuenta financiera excluyendo reservas (millones USD) [COL.NNAFANIL_T.FABXRRI.USD.Q] | `imf_bop` NA | trimestral | 1996-01-01 | 2026-01-01 | 121 | US DOLLAR (Millions) | Preliminar | Flujos de capital netos |
| `ecu_cuenta_financiera_sin_reservas` | Ecuador: Saldo de la cuenta financiera excluyendo reservas (millones USD) [ECU.NNAFANIL_T.FABXRRI.USD.Q] | `imf_bop` NA | trimestral | 1993-01-01 | 2026-01-01 | 133 | US DOLLAR (Millions) | Preliminar | Flujos de capital netos |
| `per_cuenta_financiera_sin_reservas` | Perú: Saldo de la cuenta financiera excluyendo reservas (millones USD) [PER.NNAFANIL_T.FABXRRI.USD.Q] | `imf_bop` NA | trimestral | 1977-01-01 | 2025-10-01 | 172 | US DOLLAR (Millions) | Preliminar | Flujos de capital netos |
| `pry_cuenta_financiera_sin_reservas` | Paraguay: Saldo de la cuenta financiera excluyendo reservas (millones USD) [PRY.NNAFANIL_T.FABXRRI.USD.Q] | `imf_bop` NA | trimestral | 1977-04-01 | 2026-01-01 | 106 | US DOLLAR (Millions) | Preliminar | Flujos de capital netos |
| `ury_cuenta_financiera_sin_reservas` | Uruguay: Saldo de la cuenta financiera excluyendo reservas (millones USD) [URY.NNAFANIL_T.FABXRRI.USD.Q] | `imf_bop` NA | trimestral | 2000-01-01 | 2026-01-01 | 105 | US DOLLAR (Millions) | Preliminar | Flujos de capital netos |
| `arg_ied_pasivos` | Argentina: Inversión directa: incurrimiento neto de pasivos (millones USD) [ARG.L_NIL_T.D_F.USD.Q] | `imf_bop` NA | trimestral | 1976-01-01 | 2026-01-01 | 201 | US DOLLAR (Millions) | Preliminar | Entradas de capital (IED) |
| `bol_ied_pasivos` | Bolivia: Inversión directa: incurrimiento neto de pasivos (millones USD) [BOL.L_NIL_T.D_F.USD.Q] | `imf_bop` NA | trimestral | 1977-01-01 | 2026-04-01 | 162 | US DOLLAR (Millions) | Preliminar | Entradas de capital (IED) |
| `bra_ied_pasivos` | Brasil: Inversión directa: incurrimiento neto de pasivos (millones USD) [BRA.L_NIL_T.D_F.USD.Q] | `imf_bop` NA | trimestral | 1975-01-01 | 2026-04-01 | 206 | US DOLLAR (Millions) | Preliminar | Entradas de capital (IED) |
| `chl_ied_pasivos` | Chile: Inversión directa: incurrimiento neto de pasivos (millones USD) [CHL.L_NIL_T.D_F.USD.Q] | `imf_bop` NA | trimestral | 1991-01-01 | 2026-01-01 | 141 | US DOLLAR (Millions) | Preliminar | Entradas de capital (IED) |
| `col_ied_pasivos` | Colombia: Inversión directa: incurrimiento neto de pasivos (millones USD) [COL.L_NIL_T.D_F.USD.Q] | `imf_bop` NA | trimestral | 1996-01-01 | 2026-01-01 | 121 | US DOLLAR (Millions) | Preliminar | Entradas de capital (IED) |
| `ecu_ied_pasivos` | Ecuador: Inversión directa: incurrimiento neto de pasivos (millones USD) [ECU.L_NIL_T.D_F.USD.Q] | `imf_bop` NA | trimestral | 1993-01-01 | 2026-01-01 | 133 | US DOLLAR (Millions) | Preliminar | Entradas de capital (IED) |
| `per_ied_pasivos` | Perú: Inversión directa: incurrimiento neto de pasivos (millones USD) [PER.L_NIL_T.D_F.USD.Q] | `imf_bop` NA | trimestral | 1977-01-01 | 2025-10-01 | 172 | US DOLLAR (Millions) | Preliminar | Entradas de capital (IED) |
| `pry_ied_pasivos` | Paraguay: Inversión directa: incurrimiento neto de pasivos (millones USD) [PRY.L_NIL_T.D_F.USD.Q] | `imf_bop` NA | trimestral | 2000-01-01 | 2026-01-01 | 105 | US DOLLAR (Millions) | Preliminar | Entradas de capital (IED) |
| `ury_ied_pasivos` | Uruguay: Inversión directa: incurrimiento neto de pasivos (millones USD) [URY.L_NIL_T.D_F.USD.Q] | `imf_bop` NA | trimestral | 2000-01-01 | 2026-01-01 | 105 | US DOLLAR (Millions) | Preliminar | Entradas de capital (IED) |
| `arg_cartera_pasivos` | Argentina: Inversión de cartera: incurrimiento neto de pasivos (millones USD) [ARG.L_NIL_T.P_F.USD.Q] | `imf_bop` NA | trimestral | 1976-01-01 | 2026-01-01 | 201 | US DOLLAR (Millions) | Preliminar | Entradas de capital (cartera) |
| `bol_cartera_pasivos` | Bolivia: Inversión de cartera: incurrimiento neto de pasivos (millones USD) [BOL.L_NIL_T.P_F.USD.Q] | `imf_bop` NA | trimestral | 1977-01-01 | 2026-04-01 | 162 | US DOLLAR (Millions) | Preliminar | Entradas de capital (cartera) |
| `bra_cartera_pasivos` | Brasil: Inversión de cartera: incurrimiento neto de pasivos (millones USD) [BRA.L_NIL_T.P_F.USD.Q] | `imf_bop` NA | trimestral | 1975-01-01 | 2026-04-01 | 206 | US DOLLAR (Millions) | Preliminar | Entradas de capital (cartera) |
| `chl_cartera_pasivos` | Chile: Inversión de cartera: incurrimiento neto de pasivos (millones USD) [CHL.L_NIL_T.P_F.USD.Q] | `imf_bop` NA | trimestral | 1991-01-01 | 2026-01-01 | 141 | US DOLLAR (Millions) | Preliminar | Entradas de capital (cartera) |
| `col_cartera_pasivos` | Colombia: Inversión de cartera: incurrimiento neto de pasivos (millones USD) [COL.L_NIL_T.P_F.USD.Q] | `imf_bop` NA | trimestral | 1996-01-01 | 2026-01-01 | 121 | US DOLLAR (Millions) | Preliminar | Entradas de capital (cartera) |
| `ecu_cartera_pasivos` | Ecuador: Inversión de cartera: incurrimiento neto de pasivos (millones USD) [ECU.L_NIL_T.P_F.USD.Q] | `imf_bop` NA | trimestral | 1993-01-01 | 2026-01-01 | 133 | US DOLLAR (Millions) | Preliminar | Entradas de capital (cartera) |
| `per_cartera_pasivos` | Perú: Inversión de cartera: incurrimiento neto de pasivos (millones USD) [PER.L_NIL_T.P_F.USD.Q] | `imf_bop` NA | trimestral | 1977-01-01 | 2025-10-01 | 172 | US DOLLAR (Millions) | Preliminar | Entradas de capital (cartera) |
| `pry_cartera_pasivos` | Paraguay: Inversión de cartera: incurrimiento neto de pasivos (millones USD) [PRY.L_NIL_T.P_F.USD.Q] | `imf_bop` NA | trimestral | 2000-01-01 | 2026-01-01 | 105 | US DOLLAR (Millions) | Preliminar | Entradas de capital (cartera) |
| `ury_cartera_pasivos` | Uruguay: Inversión de cartera: incurrimiento neto de pasivos (millones USD) [URY.L_NIL_T.P_F.USD.Q] | `imf_bop` NA | trimestral | 2000-01-01 | 2026-01-01 | 105 | US DOLLAR (Millions) | Preliminar | Entradas de capital (cartera) |
| `arg_otra_inversion_pasivos` | Argentina: Otra inversión: incurrimiento neto de pasivos (millones USD) [ARG.L_NIL_T.O_F.USD.Q] | `imf_bop` NA | trimestral | 1976-01-01 | 2026-01-01 | 201 | US DOLLAR (Millions) | Preliminar | Entradas de capital (préstamos/depósitos) |
| `bol_otra_inversion_pasivos` | Bolivia: Otra inversión: incurrimiento neto de pasivos (millones USD) [BOL.L_NIL_T.O_F.USD.Q] | `imf_bop` NA | trimestral | 1977-01-01 | 2026-04-01 | 162 | US DOLLAR (Millions) | Preliminar | Entradas de capital (préstamos/depósitos) |
| `bra_otra_inversion_pasivos` | Brasil: Otra inversión: incurrimiento neto de pasivos (millones USD) [BRA.L_NIL_T.O_F.USD.Q] | `imf_bop` NA | trimestral | 1975-01-01 | 2026-04-01 | 206 | US DOLLAR (Millions) | Preliminar | Entradas de capital (préstamos/depósitos) |
| `chl_otra_inversion_pasivos` | Chile: Otra inversión: incurrimiento neto de pasivos (millones USD) [CHL.L_NIL_T.O_F.USD.Q] | `imf_bop` NA | trimestral | 1991-01-01 | 2026-01-01 | 141 | US DOLLAR (Millions) | Preliminar | Entradas de capital (préstamos/depósitos) |
| `col_otra_inversion_pasivos` | Colombia: Otra inversión: incurrimiento neto de pasivos (millones USD) [COL.L_NIL_T.O_F.USD.Q] | `imf_bop` NA | trimestral | 1996-01-01 | 2026-01-01 | 121 | US DOLLAR (Millions) | Preliminar | Entradas de capital (préstamos/depósitos) |
| `ecu_otra_inversion_pasivos` | Ecuador: Otra inversión: incurrimiento neto de pasivos (millones USD) [ECU.L_NIL_T.O_F.USD.Q] | `imf_bop` NA | trimestral | 1993-01-01 | 2026-01-01 | 133 | US DOLLAR (Millions) | Preliminar | Entradas de capital (préstamos/depósitos) |
| `per_otra_inversion_pasivos` | Perú: Otra inversión: incurrimiento neto de pasivos (millones USD) [PER.L_NIL_T.O_F.USD.Q] | `imf_bop` NA | trimestral | 1977-01-01 | 2025-10-01 | 172 | US DOLLAR (Millions) | Preliminar | Entradas de capital (préstamos/depósitos) |
| `pry_otra_inversion_pasivos` | Paraguay: Otra inversión: incurrimiento neto de pasivos (millones USD) [PRY.L_NIL_T.O_F.USD.Q] | `imf_bop` NA | trimestral | 2000-01-01 | 2026-01-01 | 105 | US DOLLAR (Millions) | Preliminar | Entradas de capital (préstamos/depósitos) |
| `ury_otra_inversion_pasivos` | Uruguay: Otra inversión: incurrimiento neto de pasivos (millones USD) [URY.L_NIL_T.O_F.USD.Q] | `imf_bop` NA | trimestral | 2000-01-01 | 2026-01-01 | 105 | US DOLLAR (Millions) | Preliminar | Entradas de capital (préstamos/depósitos) |
| `arg_reservas_flujo_bop` | Argentina: Activos de reserva: transacciones de balanza de pagos (millones USD) [ARG.A_T.R_F.USD.Q] | `imf_bop` NA | trimestral | 1976-01-01 | 2026-01-01 | 201 | US DOLLAR (Millions) | Preliminar | Acumulación de reservas |
| `bol_reservas_flujo_bop` | Bolivia: Activos de reserva: transacciones de balanza de pagos (millones USD) [BOL.A_T.R_F.USD.Q] | `imf_bop` NA | trimestral | 1977-01-01 | 2026-04-01 | 162 | US DOLLAR (Millions) | Preliminar | Acumulación de reservas |
| `bra_reservas_flujo_bop` | Brasil: Activos de reserva: transacciones de balanza de pagos (millones USD) [BRA.A_T.R_F.USD.Q] | `imf_bop` NA | trimestral | 1975-01-01 | 2026-04-01 | 206 | US DOLLAR (Millions) | Preliminar | Acumulación de reservas |
| `chl_reservas_flujo_bop` | Chile: Activos de reserva: transacciones de balanza de pagos (millones USD) [CHL.A_T.R_F.USD.Q] | `imf_bop` NA | trimestral | 1991-01-01 | 2026-01-01 | 141 | US DOLLAR (Millions) | Preliminar | Acumulación de reservas |
| `col_reservas_flujo_bop` | Colombia: Activos de reserva: transacciones de balanza de pagos (millones USD) [COL.A_T.R_F.USD.Q] | `imf_bop` NA | trimestral | 1996-01-01 | 2026-01-01 | 121 | US DOLLAR (Millions) | Preliminar | Acumulación de reservas |
| `ecu_reservas_flujo_bop` | Ecuador: Activos de reserva: transacciones de balanza de pagos (millones USD) [ECU.A_T.R_F.USD.Q] | `imf_bop` NA | trimestral | 1993-01-01 | 2026-01-01 | 133 | US DOLLAR (Millions) | Preliminar | Acumulación de reservas |
| `per_reservas_flujo_bop` | Perú: Activos de reserva: transacciones de balanza de pagos (millones USD) [PER.A_T.R_F.USD.Q] | `imf_bop` NA | trimestral | 1977-01-01 | 2025-10-01 | 172 | US DOLLAR (Millions) | Preliminar | Acumulación de reservas |
| `pry_reservas_flujo_bop` | Paraguay: Activos de reserva: transacciones de balanza de pagos (millones USD) [PRY.A_T.R_F.USD.Q] | `imf_bop` NA | trimestral | 1977-04-01 | 2026-01-01 | 106 | US DOLLAR (Millions) | Preliminar | Acumulación de reservas |
| `ury_reservas_flujo_bop` | Uruguay: Activos de reserva: transacciones de balanza de pagos (millones USD) [URY.A_T.R_F.USD.Q] | `imf_bop` NA | trimestral | 2000-01-01 | 2026-01-01 | 105 | US DOLLAR (Millions) | Preliminar | Acumulación de reservas |
| `arg_pib_nominal` | Argentina: PIB a precios corrientes (moneda local; trimestral sin desestacionalizar) [ARG.B1GQ.V.NSA.XDC.Q] | `imf_qnea` NA | trimestral | 2004-01-01 | 2026-01-01 | 89 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Normalización (% del PIB) |
| `bol_pib_nominal` | Bolivia: PIB a precios corrientes (moneda local; trimestral sin desestacionalizar) [BOL.B1GQ.V.NSA.XDC.Q] | `imf_qnea` NA | trimestral | 2017-01-01 | 2025-04-01 | 34 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Normalización (% del PIB) |
| `bra_pib_nominal` | Brasil: PIB a precios corrientes (moneda local; trimestral sin desestacionalizar) [BRA.B1GQ.V.NSA.XDC.Q] | `imf_qnea` NA | trimestral | 1996-01-01 | 2026-04-01 | 122 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Normalización (% del PIB) |
| `chl_pib_nominal` | Chile: PIB a precios corrientes (moneda local; trimestral sin desestacionalizar) [CHL.B1GQ.V.NSA.XDC.Q] | `imf_qnea` NA | trimestral | 1996-01-01 | 2026-04-01 | 122 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Normalización (% del PIB) |
| `col_pib_nominal` | Colombia: PIB a precios corrientes (moneda local; trimestral sin desestacionalizar) [COL.B1GQ.V.NSA.XDC.Q] | `imf_qnea` NA | trimestral | 2005-01-01 | 2026-04-01 | 86 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Normalización (% del PIB) |
| `ecu_pib_nominal` | Ecuador: PIB a precios corrientes (moneda local; trimestral sin desestacionalizar) [ECU.B1GQ.V.NSA.XDC.Q] | `imf_qnea` NA | trimestral | 2000-01-01 | 2026-01-01 | 105 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Normalización (% del PIB) |
| `per_pib_nominal` | Perú: PIB a precios corrientes (moneda local; trimestral sin desestacionalizar) [PER.B1GQ.V.NSA.XDC.Q] | `imf_qnea` NA | trimestral | 2007-01-01 | 2025-10-01 | 76 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Normalización (% del PIB) |
| `pry_pib_nominal` | Paraguay: PIB a precios corrientes (moneda local; trimestral sin desestacionalizar) [PRY.B1GQ.V.NSA.XDC.Q] | `imf_qnea` NA | trimestral | 1994-01-01 | 2025-10-01 | 128 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Normalización (% del PIB) |
| `ury_pib_nominal` | Uruguay: PIB a precios corrientes (moneda local; trimestral sin desestacionalizar) [URY.B1GQ.V.NSA.XDC.Q] | `imf_qnea` NA | trimestral | 2016-01-01 | 2026-01-01 | 41 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Normalización (% del PIB) |
| `arg_pib_real` | Argentina: PIB a precios constantes (moneda local; trimestral sin desestacionalizar) [ARG.B1GQ.Q.NSA.XDC.Q] | `imf_qnea` NA | trimestral | 2004-01-01 | 2026-01-01 | 89 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: actividad |
| `bol_pib_real` | Bolivia: PIB a precios constantes (moneda local; trimestral sin desestacionalizar) [BOL.B1GQ.Q.NSA.XDC.Q] | `imf_qnea` NA | trimestral | 2017-01-01 | 2025-04-01 | 34 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: actividad |
| `bra_pib_real` | Brasil: PIB a precios constantes (moneda local; trimestral sin desestacionalizar) [BRA.B1GQ.Q.NSA.XDC.Q] | `imf_qnea` NA | trimestral | 1996-01-01 | 2026-04-01 | 122 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: actividad |
| `chl_pib_real` | Chile: PIB a precios constantes (moneda local; trimestral sin desestacionalizar) [CHL.B1GQ.Q.NSA.XDC.Q] | `imf_qnea` NA | trimestral | 1996-01-01 | 2026-04-01 | 122 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: actividad |
| `col_pib_real` | Colombia: PIB a precios constantes (moneda local; trimestral sin desestacionalizar) [COL.B1GQ.Q.NSA.XDC.Q] | `imf_qnea` NA | trimestral | 2005-01-01 | 2026-04-01 | 86 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: actividad |
| `ecu_pib_real` | Ecuador: PIB a precios constantes (moneda local; trimestral sin desestacionalizar) [ECU.B1GQ.Q.NSA.XDC.Q] | `imf_qnea` NA | trimestral | 2000-01-01 | 2025-07-01 | 103 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: actividad |
| `per_pib_real` | Perú: PIB a precios constantes (moneda local; trimestral sin desestacionalizar) [PER.B1GQ.Q.NSA.XDC.Q] | `imf_qnea` NA | trimestral | 2007-01-01 | 2025-10-01 | 76 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: actividad |
| `pry_pib_real` | Paraguay: PIB a precios constantes (moneda local; trimestral sin desestacionalizar) [PRY.B1GQ.Q.NSA.XDC.Q] | `imf_qnea` NA | trimestral | 1994-01-01 | 2025-10-01 | 128 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: actividad |
| `ury_pib_real` | Uruguay: PIB a precios constantes (moneda local; trimestral sin desestacionalizar) [URY.B1GQ.Q.NSA.XDC.Q] | `imf_qnea` NA | trimestral | 2016-01-01 | 2026-01-01 | 41 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: actividad |
| `arg_fsi_mora` | Argentina: FSI: préstamos en mora / préstamos brutos (%) [ARG.S12CFSI.AQ12_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2012-01-01 | 2025-10-01 | 56 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: riesgo de crédito |
| `bol_fsi_mora` | Bolivia: FSI: préstamos en mora / préstamos brutos (%) [BOL.S12CFSI.AQ12_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2010-01-01 | 2025-07-01 | 63 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: riesgo de crédito |
| `bra_fsi_mora` | Brasil: FSI: préstamos en mora / préstamos brutos (%) [BRA.S12CFSI.AQ12_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2005-01-01 | 2026-01-01 | 85 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: riesgo de crédito |
| `chl_fsi_mora` | Chile: FSI: préstamos en mora / préstamos brutos (%) [CHL.S12CFSI.AQ12_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2001-01-01 | 2025-10-01 | 100 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: riesgo de crédito |
| `col_fsi_mora` | Colombia: FSI: préstamos en mora / préstamos brutos (%) [COL.S12CFSI.AQ12_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2005-01-01 | 2026-01-01 | 85 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: riesgo de crédito |
| `ecu_fsi_mora` | Ecuador: FSI: préstamos en mora / préstamos brutos (%) [ECU.S12CFSI.AQ12_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2003-01-01 | 2026-01-01 | 93 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: riesgo de crédito |
| `per_fsi_mora` | Perú: FSI: préstamos en mora / préstamos brutos (%) [PER.S12CFSI.AQ12_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2010-10-01 | 2025-07-01 | 60 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: riesgo de crédito |
| `pry_fsi_mora` | Paraguay: FSI: préstamos en mora / préstamos brutos (%) [PRY.S12CFSI.AQ12_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2005-01-01 | 2026-01-01 | 85 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: riesgo de crédito |
| `ury_fsi_mora` | Uruguay: FSI: préstamos en mora / préstamos brutos (%) [URY.S12CFSI.AQ12_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2015-10-01 | 2025-04-01 | 24 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: riesgo de crédito |
| `arg_fsi_capital` | Argentina: FSI: capital regulatorio / activos ponderados por riesgo (%) [ARG.S12CFSI.FSI688_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2012-01-01 | 2025-10-01 | 56 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Colchón bancario |
| `bol_fsi_capital` | Bolivia: FSI: capital regulatorio / activos ponderados por riesgo (%) [BOL.S12CFSI.FSI688_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2010-01-01 | 2025-07-01 | 63 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Colchón bancario |
| `bra_fsi_capital` | Brasil: FSI: capital regulatorio / activos ponderados por riesgo (%) [BRA.S12CFSI.FSI688_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2005-01-01 | 2026-01-01 | 85 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Colchón bancario |
| `chl_fsi_capital` | Chile: FSI: capital regulatorio / activos ponderados por riesgo (%) [CHL.S12CFSI.FSI688_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2001-01-01 | 2025-10-01 | 100 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Colchón bancario |
| `col_fsi_capital` | Colombia: FSI: capital regulatorio / activos ponderados por riesgo (%) [COL.S12CFSI.FSI688_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2005-01-01 | 2026-01-01 | 85 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Colchón bancario |
| `ecu_fsi_capital` | Ecuador: FSI: capital regulatorio / activos ponderados por riesgo (%) [ECU.S12CFSI.FSI688_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2003-01-01 | 2026-01-01 | 93 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Colchón bancario |
| `per_fsi_capital` | Perú: FSI: capital regulatorio / activos ponderados por riesgo (%) [PER.S12CFSI.FSI688_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2010-10-01 | 2025-07-01 | 60 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Colchón bancario |
| `pry_fsi_capital` | Paraguay: FSI: capital regulatorio / activos ponderados por riesgo (%) [PRY.S12CFSI.FSI688_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2005-01-01 | 2026-01-01 | 85 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Colchón bancario |
| `ury_fsi_capital` | Uruguay: FSI: capital regulatorio / activos ponderados por riesgo (%) [URY.S12CFSI.FSI688_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2015-10-01 | 2025-04-01 | 24 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Colchón bancario |
| `arg_fsi_roa` | Argentina: FSI: rentabilidad sobre activos (%) [ARG.S12CFSI.ROA_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2012-01-01 | 2025-10-01 | 56 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado bancario |
| `bol_fsi_roa` | Bolivia: FSI: rentabilidad sobre activos (%) [BOL.S12CFSI.ROA_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2010-01-01 | 2025-07-01 | 63 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado bancario |
| `bra_fsi_roa` | Brasil: FSI: rentabilidad sobre activos (%) [BRA.S12CFSI.ROA_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2005-01-01 | 2026-01-01 | 85 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado bancario |
| `chl_fsi_roa` | Chile: FSI: rentabilidad sobre activos (%) [CHL.S12CFSI.ROA_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2001-01-01 | 2025-10-01 | 100 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado bancario |
| `col_fsi_roa` | Colombia: FSI: rentabilidad sobre activos (%) [COL.S12CFSI.ROA_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2005-01-01 | 2026-01-01 | 85 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado bancario |
| `ecu_fsi_roa` | Ecuador: FSI: rentabilidad sobre activos (%) [ECU.S12CFSI.ROA_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2003-01-01 | 2026-01-01 | 93 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado bancario |
| `per_fsi_roa` | Perú: FSI: rentabilidad sobre activos (%) [PER.S12CFSI.ROA_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2010-10-01 | 2025-07-01 | 60 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado bancario |
| `pry_fsi_roa` | Paraguay: FSI: rentabilidad sobre activos (%) [PRY.S12CFSI.ROA_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2005-01-01 | 2026-01-01 | 85 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado bancario |
| `ury_fsi_roa` | Uruguay: FSI: rentabilidad sobre activos (%) [URY.S12CFSI.ROA_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2015-10-01 | 2025-04-01 | 24 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado bancario |
| `arg_fsi_liquidez` | Argentina: FSI: activos líquidos / pasivos de corto plazo (%) [ARG.S12CFSI.FSI765_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2012-01-01 | 2025-07-01 | 55 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Colchón de liquidez |
| `bol_fsi_liquidez` | Bolivia: FSI: activos líquidos / pasivos de corto plazo (%) [BOL.S12CFSI.FSI765_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2010-01-01 | 2025-07-01 | 63 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Colchón de liquidez |
| `bra_fsi_liquidez` | Brasil: FSI: activos líquidos / pasivos de corto plazo (%) [BRA.S12CFSI.FSI765_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2005-01-01 | 2026-01-01 | 85 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Colchón de liquidez |
| `chl_fsi_liquidez` | Chile: FSI: activos líquidos / pasivos de corto plazo (%) [CHL.S12CFSI.FSI765_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2001-01-01 | 2007-10-01 | 28 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Colchón de liquidez |
| `col_fsi_liquidez` | Colombia: FSI: activos líquidos / pasivos de corto plazo (%) [COL.S12CFSI.FSI765_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2005-01-01 | 2026-01-01 | 85 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Colchón de liquidez |
| `ecu_fsi_liquidez` | Ecuador: FSI: activos líquidos / pasivos de corto plazo (%) [ECU.S12CFSI.FSI765_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2003-01-01 | 2026-01-01 | 93 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Colchón de liquidez |
| `per_fsi_liquidez` | Perú: FSI: activos líquidos / pasivos de corto plazo (%) [PER.S12CFSI.FSI765_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2010-10-01 | 2025-07-01 | 60 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Colchón de liquidez |
| `pry_fsi_liquidez` | Paraguay: FSI: activos líquidos / pasivos de corto plazo (%) [PRY.S12CFSI.FSI765_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2005-01-01 | 2026-01-01 | 85 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Colchón de liquidez |
| `ury_fsi_liquidez` | Uruguay: FSI: activos líquidos / pasivos de corto plazo (%) [URY.S12CFSI.FSI765_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2015-10-01 | 2025-04-01 | 24 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Colchón de liquidez |
| `arg_fsi_prestamos_me` | Argentina: FSI: préstamos en moneda extranjera / préstamos totales (%) [ARG.S12CFSI.FSI131_AFSI_PT.Q] | `imf_fsic` NA | trimestral | 2012-01-01 | 2025-10-01 | 56 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Dolarización del crédito |
| `bol_fsi_prestamos_me` | Bolivia: FSI: préstamos en moneda extranjera / préstamos totales (%) [BOL.S12CFSI.FSI131_AFSI_PT.Q] | `imf_fsic` NA | trimestral | 2010-01-01 | 2025-07-01 | 63 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Dolarización del crédito |
| `bra_fsi_prestamos_me` | Brasil: FSI: préstamos en moneda extranjera / préstamos totales (%) [BRA.S12CFSI.FSI131_AFSI_PT.Q] | `imf_fsic` NA | trimestral | 2005-01-01 | 2026-01-01 | 85 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Dolarización del crédito |
| `chl_fsi_prestamos_me` | Chile: FSI: préstamos en moneda extranjera / préstamos totales (%) [CHL.S12CFSI.FSI131_AFSI_PT.Q] | `imf_fsic` NA | trimestral | 2001-01-01 | 2025-10-01 | 100 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Dolarización del crédito |
| `col_fsi_prestamos_me` | Colombia: FSI: préstamos en moneda extranjera / préstamos totales (%) [COL.S12CFSI.FSI131_AFSI_PT.Q] | `imf_fsic` NA | trimestral | 2005-01-01 | 2026-01-01 | 85 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Dolarización del crédito |
| `per_fsi_prestamos_me` | Perú: FSI: préstamos en moneda extranjera / préstamos totales (%) [PER.S12CFSI.FSI131_AFSI_PT.Q] | `imf_fsic` NA | trimestral | 2010-10-01 | 2025-07-01 | 60 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Dolarización del crédito |
| `pry_fsi_prestamos_me` | Paraguay: FSI: préstamos en moneda extranjera / préstamos totales (%) [PRY.S12CFSI.FSI131_AFSI_PT.Q] | `imf_fsic` NA | trimestral | 2005-01-01 | 2026-01-01 | 85 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Dolarización del crédito |
| `ury_fsi_prestamos_me` | Uruguay: FSI: préstamos en moneda extranjera / préstamos totales (%) [URY.S12CFSI.FSI131_AFSI_PT.Q] | `imf_fsic` NA | trimestral | 2015-10-01 | 2025-04-01 | 24 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Dolarización del crédito |
| `arg_fsi_posicion_abierta_me` | Argentina: FSI: posición abierta neta en ME / capital (%) [ARG.S12CFSI.FSI555_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2012-01-01 | 2025-10-01 | 56 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Descalce cambiario bancario |
| `bol_fsi_posicion_abierta_me` | Bolivia: FSI: posición abierta neta en ME / capital (%) [BOL.S12CFSI.FSI555_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2010-01-01 | 2025-07-01 | 63 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Descalce cambiario bancario |
| `bra_fsi_posicion_abierta_me` | Brasil: FSI: posición abierta neta en ME / capital (%) [BRA.S12CFSI.FSI555_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2008-10-01 | 2026-01-01 | 70 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Descalce cambiario bancario |
| `chl_fsi_posicion_abierta_me` | Chile: FSI: posición abierta neta en ME / capital (%) [CHL.S12CFSI.FSI555_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2008-01-01 | 2021-04-01 | 54 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Descalce cambiario bancario |
| `col_fsi_posicion_abierta_me` | Colombia: FSI: posición abierta neta en ME / capital (%) [COL.S12CFSI.FSI555_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2005-01-01 | 2026-01-01 | 85 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Descalce cambiario bancario |
| `ecu_fsi_posicion_abierta_me` | Ecuador: FSI: posición abierta neta en ME / capital (%) [ECU.S12CFSI.FSI555_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2024-01-01 | 2025-04-01 | 6 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Descalce cambiario bancario |
| `per_fsi_posicion_abierta_me` | Perú: FSI: posición abierta neta en ME / capital (%) [PER.S12CFSI.FSI555_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2010-10-01 | 2025-07-01 | 60 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Descalce cambiario bancario |
| `pry_fsi_posicion_abierta_me` | Paraguay: FSI: posición abierta neta en ME / capital (%) [PRY.S12CFSI.FSI555_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2005-01-01 | 2026-01-01 | 85 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Descalce cambiario bancario |
| `ury_fsi_posicion_abierta_me` | Uruguay: FSI: posición abierta neta en ME / capital (%) [URY.S12CFSI.FSI555_CFSI_PT.Q] | `imf_fsic` NA | trimestral | 2015-10-01 | 2025-04-01 | 24 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Descalce cambiario bancario |
| `arg_reservas_sin_oro` | Argentina: Reservas internacionales sin oro (millones USD; mensual) [ARG.RXF11_REVS.USD.M] | `imf_il` NA | mensual | 1950-12-01 | 2026-07-01 | 842 | US DOLLAR (Millions) | Preliminar | Colchón de reservas |
| `bol_reservas_sin_oro` | Bolivia: Reservas internacionales sin oro (millones USD; mensual) [BOL.RXF11_REVS.USD.M] | `imf_il` NA | mensual | 1950-12-01 | 2025-12-01 | 835 | US DOLLAR (Millions) | Preliminar | Colchón de reservas |
| `bra_reservas_sin_oro` | Brasil: Reservas internacionales sin oro (millones USD; mensual) [BRA.RXF11_REVS.USD.M] | `imf_il` NA | mensual | 1950-12-01 | 2026-06-01 | 841 | US DOLLAR (Millions) | Preliminar | Colchón de reservas |
| `chl_reservas_sin_oro` | Chile: Reservas internacionales sin oro (millones USD; mensual) [CHL.RXF11_REVS.USD.M] | `imf_il` NA | mensual | 1950-12-01 | 2026-06-01 | 825 | US DOLLAR (Millions) | Preliminar | Colchón de reservas |
| `col_reservas_sin_oro` | Colombia: Reservas internacionales sin oro (millones USD; mensual) [COL.RXF11_REVS.USD.M] | `imf_il` NA | mensual | 1950-12-01 | 2026-01-01 | 836 | US DOLLAR (Millions) | Preliminar | Colchón de reservas |
| `ecu_reservas_sin_oro` | Ecuador: Reservas internacionales sin oro (millones USD; mensual) [ECU.RXF11_REVS.USD.M] | `imf_il` NA | mensual | 1950-12-01 | 2026-07-01 | 842 | US DOLLAR (Millions) | Preliminar | Colchón de reservas |
| `per_reservas_sin_oro` | Perú: Reservas internacionales sin oro (millones USD; mensual) [PER.RXF11_REVS.USD.M] | `imf_il` NA | mensual | 1950-12-01 | 2026-01-01 | 829 | US DOLLAR (Millions) | Preliminar | Colchón de reservas |
| `pry_reservas_sin_oro` | Paraguay: Reservas internacionales sin oro (millones USD; mensual) [PRY.RXF11_REVS.USD.M] | `imf_il` NA | mensual | 1950-12-01 | 2025-11-01 | 834 | US DOLLAR (Millions) | Preliminar | Colchón de reservas |
| `ury_reservas_sin_oro` | Uruguay: Reservas internacionales sin oro (millones USD; mensual) [URY.RXF11_REVS.USD.M] | `imf_il` NA | mensual | 1950-12-01 | 2026-07-01 | 831 | US DOLLAR (Millions) | Preliminar | Colchón de reservas |
| `arg_tipo_cambio_prom` | Argentina: Tipo de cambio: moneda local por USD (promedio del período) [ARG.XDC_USD.PA_RT.M] | `imf_er` NA | mensual | 1962-05-01 | 2026-07-01 | 771 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: tipo de cambio |
| `bol_tipo_cambio_prom` | Bolivia: Tipo de cambio: moneda local por USD (promedio del período) [BOL.XDC_USD.PA_RT.M] | `imf_er` NA | mensual | 1959-03-01 | 2026-04-01 | 806 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: tipo de cambio |
| `bra_tipo_cambio_prom` | Brasil: Tipo de cambio: moneda local por USD (promedio del período) [BRA.XDC_USD.PA_RT.M] | `imf_er` NA | mensual | 1957-01-01 | 2026-07-01 | 835 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: tipo de cambio |
| `chl_tipo_cambio_prom` | Chile: Tipo de cambio: moneda local por USD (promedio del período) [CHL.XDC_USD.PA_RT.M] | `imf_er` NA | mensual | 1957-01-01 | 2026-07-01 | 835 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: tipo de cambio |
| `col_tipo_cambio_prom` | Colombia: Tipo de cambio: moneda local por USD (promedio del período) [COL.XDC_USD.PA_RT.M] | `imf_er` NA | mensual | 1957-01-01 | 2026-07-01 | 835 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: tipo de cambio |
| `ecu_tipo_cambio_prom` | Ecuador: Tipo de cambio: moneda local por USD (promedio del período) [ECU.XDC_USD.PA_RT.M] | `imf_er` NA | mensual | 1957-01-01 | 2026-08-01 | 836 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: tipo de cambio |
| `per_tipo_cambio_prom` | Perú: Tipo de cambio: moneda local por USD (promedio del período) [PER.XDC_USD.PA_RT.M] | `imf_er` NA | mensual | 1960-01-01 | 2026-07-01 | 799 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: tipo de cambio |
| `pry_tipo_cambio_prom` | Paraguay: Tipo de cambio: moneda local por USD (promedio del período) [PRY.XDC_USD.PA_RT.M] | `imf_er` NA | mensual | 1957-01-01 | 2026-03-01 | 831 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: tipo de cambio |
| `ury_tipo_cambio_prom` | Uruguay: Tipo de cambio: moneda local por USD (promedio del período) [URY.XDC_USD.PA_RT.M] | `imf_er` NA | mensual | 1957-01-01 | 2026-07-01 | 835 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: tipo de cambio |
| `arg_ipc` | Argentina: IPC índice (todos los ítems) [ARG.CPI._T.IX.M] | `imf_cpi` NA | mensual | 2016-12-01 | 2026-06-01 | 115 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: inflación |
| `bol_ipc` | Bolivia: IPC índice (todos los ítems) [BOL.CPI._T.IX.M] | `imf_cpi` NA | mensual | 2005-01-01 | 2026-06-01 | 258 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: inflación |
| `bra_ipc` | Brasil: IPC índice (todos los ítems) [BRA.CPI._T.IX.M] | `imf_cpi` NA | mensual | 1979-12-01 | 2026-07-01 | 560 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: inflación |
| `chl_ipc` | Chile: IPC índice (todos los ítems) [CHL.CPI._T.IX.M] | `imf_cpi` NA | mensual | 1970-01-01 | 2026-07-01 | 679 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: inflación |
| `col_ipc` | Colombia: IPC índice (todos los ítems) [COL.CPI._T.IX.M] | `imf_cpi` NA | mensual | 1970-01-01 | 2026-07-01 | 679 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: inflación |
| `ecu_ipc` | Ecuador: IPC índice (todos los ítems) [ECU.CPI._T.IX.M] | `imf_cpi` NA | mensual | 1969-01-01 | 2026-05-01 | 689 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: inflación |
| `per_ipc` | Perú: IPC índice (todos los ítems) [PER.CPI._T.IX.M] | `imf_cpi` NA | mensual | 2010-01-01 | 2026-05-01 | 197 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: inflación |
| `pry_ipc` | Paraguay: IPC índice (todos los ítems) [PRY.CPI._T.IX.M] | `imf_cpi` NA | mensual | 2005-01-01 | 2026-04-01 | 256 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: inflación |
| `ury_ipc` | Uruguay: IPC índice (todos los ítems) [URY.CPI._T.IX.M] | `imf_cpi` NA | mensual | 2005-01-01 | 2026-06-01 | 258 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Resultado: inflación |
| `bol_tcre` | Bolivia: Tipo de cambio real efectivo (2010=100) [BOL.REER_IX_RY2010_ACW_RCPI.M] | `imf_eer` NA | mensual | 1979-12-01 | 2026-06-01 | 559 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Competitividad |
| `bra_tcre` | Brasil: Tipo de cambio real efectivo (2010=100) [BRA.REER_IX_RY2010_ACW_RCPI.M] | `imf_eer` NA | mensual | 1979-12-01 | 2026-06-01 | 559 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Competitividad |
| `chl_tcre` | Chile: Tipo de cambio real efectivo (2010=100) [CHL.REER_IX_RY2010_ACW_RCPI.M] | `imf_eer` NA | mensual | 1979-12-01 | 2026-06-01 | 559 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Competitividad |
| `col_tcre` | Colombia: Tipo de cambio real efectivo (2010=100) [COL.REER_IX_RY2010_ACW_RCPI.M] | `imf_eer` NA | mensual | 1979-12-01 | 2026-06-01 | 559 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Competitividad |
| `pry_tcre` | Paraguay: Tipo de cambio real efectivo (2010=100) [PRY.REER_IX_RY2010_ACW_RCPI.M] | `imf_eer` NA | mensual | 1979-12-01 | 2026-06-01 | 559 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Competitividad |
| `ury_tcre` | Uruguay: Tipo de cambio real efectivo (2010=100) [URY.REER_IX_RY2010_ACW_RCPI.M] | `imf_eer` NA | mensual | 1979-12-01 | 2026-06-01 | 559 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Competitividad |
| `arg_terminos_intercambio_commodities` | Argentina: Índice de precios de commodities exportados (pesos móviles) [ARG.CEPI_CTOTX_TX.R_RW_IX.M] | `imf_ctot` NA | mensual | 1980-01-01 | 2026-05-01 | 557 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Shock de términos de intercambio (país-específico) |
| `bol_terminos_intercambio_commodities` | Bolivia: Índice de precios de commodities exportados (pesos móviles) [BOL.CEPI_CTOTX_TX.R_RW_IX.M] | `imf_ctot` NA | mensual | 1980-01-01 | 2026-05-01 | 557 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Shock de términos de intercambio (país-específico) |
| `bra_terminos_intercambio_commodities` | Brasil: Índice de precios de commodities exportados (pesos móviles) [BRA.CEPI_CTOTX_TX.R_RW_IX.M] | `imf_ctot` NA | mensual | 1980-01-01 | 2026-05-01 | 557 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Shock de términos de intercambio (país-específico) |
| `chl_terminos_intercambio_commodities` | Chile: Índice de precios de commodities exportados (pesos móviles) [CHL.CEPI_CTOTX_TX.R_RW_IX.M] | `imf_ctot` NA | mensual | 1980-01-01 | 2026-05-01 | 557 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Shock de términos de intercambio (país-específico) |
| `col_terminos_intercambio_commodities` | Colombia: Índice de precios de commodities exportados (pesos móviles) [COL.CEPI_CTOTX_TX.R_RW_IX.M] | `imf_ctot` NA | mensual | 1980-01-01 | 2026-05-01 | 557 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Shock de términos de intercambio (país-específico) |
| `ecu_terminos_intercambio_commodities` | Ecuador: Índice de precios de commodities exportados (pesos móviles) [ECU.CEPI_CTOTX_TX.R_RW_IX.M] | `imf_ctot` NA | mensual | 1980-01-01 | 2026-05-01 | 557 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Shock de términos de intercambio (país-específico) |
| `per_terminos_intercambio_commodities` | Perú: Índice de precios de commodities exportados (pesos móviles) [PER.CEPI_CTOTX_TX.R_RW_IX.M] | `imf_ctot` NA | mensual | 1980-01-01 | 2026-05-01 | 557 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Shock de términos de intercambio (país-específico) |
| `pry_terminos_intercambio_commodities` | Paraguay: Índice de precios de commodities exportados (pesos móviles) [PRY.CEPI_CTOTX_TX.R_RW_IX.M] | `imf_ctot` NA | mensual | 1980-01-01 | 2026-05-01 | 557 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Shock de términos de intercambio (país-específico) |
| `ury_terminos_intercambio_commodities` | Uruguay: Índice de precios de commodities exportados (pesos móviles) [URY.CEPI_CTOTX_TX.R_RW_IX.M] | `imf_ctot` NA | mensual | 1980-01-01 | 2026-05-01 | 557 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Shock de términos de intercambio (país-específico) |
| `arg_tasa_politica` | Argentina: Tasa de política monetaria (% anual) [ARG.MFS166_RT_PT_A_PT.M] | `imf_mfs_ir` NA | mensual | 2002-01-01 | 2025-06-01 | 282 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Respuesta de política |
| `bra_tasa_politica` | Brasil: Tasa de política monetaria (% anual) [BRA.MFS166_RT_PT_A_PT.M] | `imf_mfs_ir` NA | mensual | 1999-04-01 | 2026-05-01 | 326 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Respuesta de política |
| `chl_tasa_politica` | Chile: Tasa de política monetaria (% anual) [CHL.MFS166_RT_PT_A_PT.M] | `imf_mfs_ir` NA | mensual | 1995-05-01 | 2026-05-01 | 373 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Respuesta de política |
| `col_tasa_politica` | Colombia: Tasa de política monetaria (% anual) [COL.MFS166_RT_PT_A_PT.M] | `imf_mfs_ir` NA | mensual | 1995-04-01 | 2026-05-01 | 374 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Respuesta de política |
| `per_tasa_politica` | Perú: Tasa de política monetaria (% anual) [PER.MFS166_RT_PT_A_PT.M] | `imf_mfs_ir` NA | mensual | 2003-09-01 | 2023-04-01 | 236 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Respuesta de política |
| `pry_tasa_politica` | Paraguay: Tasa de política monetaria (% anual) [PRY.MFS166_RT_PT_A_PT.M] | `imf_mfs_ir` NA | mensual | 2011-01-01 | 2021-11-01 | 131 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Respuesta de política |
| `ury_tasa_politica` | Uruguay: Tasa de política monetaria (% anual) [URY.MFS166_RT_PT_A_PT.M] | `imf_mfs_ir` NA | mensual | 2008-01-01 | 2013-06-01 | 65 | UNRESOLVED_SOURCE_UNITS (Units) | Preliminar | Respuesta de política |
| `arg_intervencion_spot_proxy` | Argentina: Intervención cambiaria spot aproximada (FMI WPFXI; millones USD) [ARG.FXI_SPOT_PROXY_USD.M] | `imf_wpfxi` NA | mensual | 2000-01-01 | 2024-12-01 | 300 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Respuesta de política cambiaria |
| `bol_intervencion_spot_proxy` | Bolivia: Intervención cambiaria spot aproximada (FMI WPFXI; millones USD) [BOL.FXI_SPOT_PROXY_USD.M] | `imf_wpfxi` NA | mensual | 2000-01-01 | 2024-12-01 | 299 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Respuesta de política cambiaria |
| `bra_intervencion_spot_proxy` | Brasil: Intervención cambiaria spot aproximada (FMI WPFXI; millones USD) [BRA.FXI_SPOT_PROXY_USD.M] | `imf_wpfxi` NA | mensual | 2000-01-01 | 2024-12-01 | 300 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Respuesta de política cambiaria |
| `chl_intervencion_spot_proxy` | Chile: Intervención cambiaria spot aproximada (FMI WPFXI; millones USD) [CHL.FXI_SPOT_PROXY_USD.M] | `imf_wpfxi` NA | mensual | 2000-01-01 | 2024-12-01 | 300 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Respuesta de política cambiaria |
| `col_intervencion_spot_proxy` | Colombia: Intervención cambiaria spot aproximada (FMI WPFXI; millones USD) [COL.FXI_SPOT_PROXY_USD.M] | `imf_wpfxi` NA | mensual | 2000-01-01 | 2024-12-01 | 300 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Respuesta de política cambiaria |
| `ecu_intervencion_spot_proxy` | Ecuador: Intervención cambiaria spot aproximada (FMI WPFXI; millones USD) [ECU.FXI_SPOT_PROXY_USD.M] | `imf_wpfxi` NA | mensual | 2000-01-01 | 2024-12-01 | 300 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Respuesta de política cambiaria |
| `per_intervencion_spot_proxy` | Perú: Intervención cambiaria spot aproximada (FMI WPFXI; millones USD) [PER.FXI_SPOT_PROXY_USD.M] | `imf_wpfxi` NA | mensual | 2000-01-01 | 2024-12-01 | 300 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Respuesta de política cambiaria |
| `pry_intervencion_spot_proxy` | Paraguay: Intervención cambiaria spot aproximada (FMI WPFXI; millones USD) [PRY.FXI_SPOT_PROXY_USD.M] | `imf_wpfxi` NA | mensual | 2000-01-01 | 2024-08-01 | 296 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Respuesta de política cambiaria |
| `ury_intervencion_spot_proxy` | Uruguay: Intervención cambiaria spot aproximada (FMI WPFXI; millones USD) [URY.FXI_SPOT_PROXY_USD.M] | `imf_wpfxi` NA | mensual | 2000-01-01 | 2024-12-01 | 300 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Respuesta de política cambiaria |
| `arg_intervencion_total_pib` | Argentina: Intervención cambiaria total aproximada (% del PIB promedio 3 años) [ARG.FXI_BROAD_PROXY_GDP.M] | `imf_wpfxi` NA | mensual | 2000-01-01 | 2024-12-01 | 300 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Respuesta de política cambiaria |
| `bol_intervencion_total_pib` | Bolivia: Intervención cambiaria total aproximada (% del PIB promedio 3 años) [BOL.FXI_BROAD_PROXY_GDP.M] | `imf_wpfxi` NA | mensual | 2000-01-01 | 2024-12-01 | 299 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Respuesta de política cambiaria |
| `bra_intervencion_total_pib` | Brasil: Intervención cambiaria total aproximada (% del PIB promedio 3 años) [BRA.FXI_BROAD_PROXY_GDP.M] | `imf_wpfxi` NA | mensual | 2000-01-01 | 2024-12-01 | 300 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Respuesta de política cambiaria |
| `chl_intervencion_total_pib` | Chile: Intervención cambiaria total aproximada (% del PIB promedio 3 años) [CHL.FXI_BROAD_PROXY_GDP.M] | `imf_wpfxi` NA | mensual | 2000-01-01 | 2024-12-01 | 300 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Respuesta de política cambiaria |
| `col_intervencion_total_pib` | Colombia: Intervención cambiaria total aproximada (% del PIB promedio 3 años) [COL.FXI_BROAD_PROXY_GDP.M] | `imf_wpfxi` NA | mensual | 2000-01-01 | 2024-12-01 | 300 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Respuesta de política cambiaria |
| `ecu_intervencion_total_pib` | Ecuador: Intervención cambiaria total aproximada (% del PIB promedio 3 años) [ECU.FXI_BROAD_PROXY_GDP.M] | `imf_wpfxi` NA | mensual | 2000-01-01 | 2024-12-01 | 300 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Respuesta de política cambiaria |
| `per_intervencion_total_pib` | Perú: Intervención cambiaria total aproximada (% del PIB promedio 3 años) [PER.FXI_BROAD_PROXY_GDP.M] | `imf_wpfxi` NA | mensual | 2000-01-01 | 2024-12-01 | 300 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Respuesta de política cambiaria |
| `pry_intervencion_total_pib` | Paraguay: Intervención cambiaria total aproximada (% del PIB promedio 3 años) [PRY.FXI_BROAD_PROXY_GDP.M] | `imf_wpfxi` NA | mensual | 2000-01-01 | 2024-08-01 | 296 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Respuesta de política cambiaria |
| `ury_intervencion_total_pib` | Uruguay: Intervención cambiaria total aproximada (% del PIB promedio 3 años) [URY.FXI_BROAD_PROXY_GDP.M] | `imf_wpfxi` NA | mensual | 2000-01-01 | 2024-12-01 | 300 | UNRESOLVED_SOURCE_UNITS (source_scale) | Preliminar | Respuesta de política cambiaria |
| `global_vix_m` | FRED: VIX promedio mensual | `FRED` VIXCLS | mensual | 1990-01-01 | 2026-08-01 | 440 | INDEX_POINTS | Externa (FRED), no verificada en la base | Shock global común |
| `global_fed_funds` | FRED: tasa efectiva de fondos federales | `FRED` FEDFUNDS | mensual | 1954-07-01 | 2026-08-01 | 866 | PERCENT | Externa (FRED), no verificada en la base | Shock global común |
| `global_dolar_amplio_m` | FRED: índice nominal amplio del dólar | `FRED` TWEXBGSMTH | mensual | 2006-01-01 | 2026-08-01 | 248 | INDEX | Externa (FRED), no verificada en la base | Shock global común |
| `global_commodities` | FRED/FMI: índice de precios de todas las commodities | `FRED` PALLFNFINDEXM | mensual | 1992-01-01 | 2026-07-01 | 415 | INDEX | Externa (FRED), no verificada en la base | Shock global común |
| `global_ust_10a` | FRED: rendimiento Tesoro EE.UU. 10 años (promedio mensual) | `FRED` DGS10 | mensual | 1962-01-01 | 2026-08-01 | 776 | PERCENT | Externa (FRED), no verificada en la base | Shock global común |

### Otros archivos

| Archivo | Contenido | Rango y tamaño | Nivel |
|---|---|---|---|
| `panel_regional_trimestral.csv` | Panel largo país × indicador × trimestre (balanza de pagos, PIB, FSI) | 1975-01-01 a 2026-04-01, 13.274 filas | Preliminar |
| `panel_regional_mensual.csv` | Panel largo país × indicador × mes (reservas, tipo de cambio, IPC, TCRE, términos de intercambio, tasa de política, intervención) | 1950-12-01 a 2026-08-01, 34.133 filas | Preliminar |
| `disponibilidad_pais_indicador.csv` | Matriz de disponibilidad (1 = existe en la base) | 22 indicadores × 9 países | — |

| Archivo | Filas | Columnas | Desde | Hasta |
|---|---|---|---|---|
| `datos/series_mensual.csv` | 36.878 | 11 | 1950-12-01 | 2026-08-01 |
| `datos/series_mensual_ancho.csv` | 870 | 73 | 1950-12-01 | 2026-08-01 |
| `datos/series_trimestral.csv` | 13.274 | 11 | 1975-01-01 | 2026-04-01 |
| `datos/series_trimestral_ancho.csv` | 206 | 126 | 1975-01-01 | 2026-04-01 |
| `datos/diccionario_series.csv` | 197 | 13 | 1950-12-01 | 2024-01-01 |
| `datos/panel_regional_trimestral.csv` | 13.274 | 9 | 1975-01-01 | 2026-04-01 |
| `datos/panel_regional_mensual.csv` | 34.133 | 9 | 1950-12-01 | 2026-08-01 |
| `datos/disponibilidad_pais_indicador.csv` | 22 | 10 | — | — |

## 4. Cómo se usarían los datos

- **Normalización:** flujos de balanza de pagos (millones de USD, trimestrales) en % del PIB: convertir el PIB nominal (moneda local) a USD con el tipo de cambio promedio del trimestre (promedio de los 3 meses de `tipo_cambio_prom`).
- **Transformaciones:** `Δlog` de tipo de cambio e IPC (inflación interanual); reservas en `log` o en % del PIB; FSI en puntos porcentuales; PIB real en `Δlog` interanual (viene sin desestacionalizar).
- **Frecuencias:** los shocks globales son mensuales; para el panel trimestral promediar (VIX, tasas) o tomar el fin de período (dólar).
- **Paraguay:** para la tasa de política usar la serie del BCP (carpetas 01/03), porque la del FMI termina en 2021-11; para reservas, comparar con la RIN del BCP antes de mezclar fuentes.

## 5. Brechas

| Variable necesaria | Por qué importa | Fuente posible |
|---|---|---|
| Datos actualizados del FMI (algunas series terminan en 2021–2025) | Cobertura reciente | Descarga nueva de IMF Data (reprocesar con el pipeline) |
| Intervención oficial diaria de los otros bancos centrales | La proxy WPFXI es mensual y aproximada | Bancos centrales de la región; base de Adler et al. (FMI) |
| Spreads soberanos (EMBI) por país | Shock de riesgo país | JP Morgan (EMBI) / Bloomberg |
| Flujos de cartera de alta frecuencia (EPFR) | Identificación de shocks de flujos | EPFR / IIF |
| Tipo de cambio real efectivo de Argentina, Perú y Ecuador | Faltan en la base | BIS (REER amplio); bancos centrales |

## 6. Evaluación de viabilidad

**Media-alta.** 192 de 198 combinaciones país-indicador están en la base (balanza de pagos desde 1975, FSI desde 2001–2005, series mensuales largas) y los shocks globales se incorporaron desde FRED. Los límites son la calidad preliminar de las series del FMI (no validadas en la base) y la falta de spreads soberanos.

## 7. Supuestos que debes revisar

1. **Selección de indicadores:** elegí por código SDMX un conjunto núcleo (22 indicadores). La base tiene muchas más desagregaciones (p. ej. 7.520 series de balanza de pagos); se pueden agregar editando la tabla `plantillas` del script.
2. **Reservas de Paraguay:** `pry_reservas_sin_oro` del FMI (≈ 9.000 millones de USD a nov-2025) no coincide con la RIN del BCP (Cuadro 56b) por diferencias de definición (oro, activos de reserva vs. reservas netas); no mezclar fuentes.
3. La tasa de política del FMI para Paraguay termina en 2021-11 y la de Argentina en 2025-06; Bolivia y Ecuador no tienen.
4. Ecuador está dolarizado: su tipo de cambio es 1 y su "política cambiaria" no es comparable.
5. Los signos de la balanza de pagos siguen el MBP6 (cuenta financiera = activos − pasivos; un saldo negativo es entrada neta de capital).

## 8. Sustento metodológico y literatura relacionada

> Referencias revisadas en septiembre de 2026 contra RePEc, las editoriales o los repositorios institucionales. **[Revista]** indica un artículo publicado con revisión de pares; **[DT]** indica un documento de trabajo o un capítulo institucional; **[PY]** indica un trabajo sobre Paraguay. Cada referencia explica qué parte del diseño o qué variable respalda.

### 8.1 Shocks globales y flujos de capital

| Referencia | Qué respalda en este proyecto |
|---|---|
| Rey, H. (2013). "Dilemma not Trilemma: The Global Financial Cycle and Monetary Policy Independence." *Jackson Hole Economic Policy Symposium*. **[Conferencia]** | Un ciclo financiero global (VIX) mueve flujos y crédito en todos los países. Justifica los shocks globales comunes. |
| Miranda-Agrippino, S. y Rey, H. (2020). "U.S. Monetary Policy and the Global Financial Cycle." *Review of Economic Studies*, 87(6), 2754–2776. **[Revista]** | La política de la Fed impulsa ese ciclo. Respalda la tasa Fed como shock. |
| Forbes, K. J. y Warnock, F. E. (2012). "Capital Flow Waves: Surges, Stops, Flight, and Retrenchment." *Journal of International Economics*, 88(2), 235–251. **[Revista]** | Los episodios extremos de flujos responden sobre todo a factores globales. Respalda los resultados de flujos por componente de la balanza de pagos. |
| Fratzscher, M. (2012). "Capital Flows, Push versus Pull Factors and the Global Financial Crisis." *Journal of International Economics*, 88(2), 341–356. **[Revista]** | Factores globales (push) frente a factores del país (pull). Justifica la heterogeneidad `shock × X_{i,t−1}`. |

### 8.2 Amortiguadores

| Referencia | Qué respalda |
|---|---|
| Obstfeld, M., Ostry, J. D. y Qureshi, M. S. (2019). "A Tie That Binds: Revisiting the Trilemma in Emerging Market Economies." *Review of Economics and Statistics*, 101(2), 279–293. **[Revista]** | El régimen cambiario modula la transmisión de shocks globales en emergentes. Es el diseño de las interacciones del paso 2. |
| Gourinchas, P.-O. y Obstfeld, M. (2012). "Stories of the Twentieth Century for the Twenty-First." *American Economic Journal: Macroeconomics*, 4(1), 226–265. **[Revista]** | Las reservas altas reducen la probabilidad de crisis. Respalda las reservas/PIB como amortiguador. |
| Adler, G., Chang, K. S., Mano, R. C. y Shao, Y. (2025). *Journal of Money, Credit and Banking*, 57(5), 1241–1273. **[Revista]** | Fuente de los datos de intervención del FMI (paso 3). |
| Gruss, B. y Kebhaj, S. (2019). "Commodity Terms of Trade: A New Database." IMF Working Paper 19/21. **[DT]** | Fuente y método de los **términos de intercambio de commodities** por país (paso 4). |

### 8.3 Métodos

- Jordà (2005) para las proyecciones locales de panel, y Driscoll, J. C. y Kraay, A. C. (1998), "Consistent Covariance Matrix Estimation with Spatially Dependent Panel Data", *Review of Economics and Statistics*, 80(4), 549–560, para los errores robustos a la dependencia entre países.

### 8.4 Antecedentes para Paraguay

- **[PY]** Adler, G. y Sosa, S. (2012). "Intra-Regional Spillovers in South America: Is Brazil Systemic After All?" IMF Working Paper 12/145. **[DT]** Los países del Cono Sur (incluido Paraguay) son vulnerables a shocks de producto de Brasil, sobre todo por comercio. Respalda incluir el ciclo de Brasil como shock regional.
