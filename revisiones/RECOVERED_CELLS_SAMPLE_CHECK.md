# Recovered cells — economic sample check

**Status: generated, unsigned.** This is a reading task, not a test. The tests already prove that
each of these observations sits on a source cell holding its value; what they cannot prove is that
the value *means* what the series label says. That is a judgement against the published workbook,
and it is the check the audit's P0-3 asks for.

Generated from `tests/testthat/fixtures/recovered_observations.csv`: **5034 recovered cells across 29 worksheets**.
Open each workbook at the coordinates below and confirm the header path and the period.

## Coverage by worksheet

| Source | Worksheet | Cells | First | Last | Published table title |
|---|---|---:|---|---|---|
| interbank_market | `Datos (+ de 1 día)` | 605 | 2013-12-03 | 2026-08-14 | Mercado Interbancario de Fondos (más de 1 día) |
| economic_annex | `CUADRO 59` | 500 | 2016-01-31 | 2026-05-31 | CUADRO N° 59 — Deuda pública externa (*) — En miles de dólares. |
| economic_annex | `CUADRO 23` | 459 | 2024-04-30 | 2026-06-30 | Cuadro N° 23 — Depósitos /1 del sector privado y público en bancos y financieras. |
| economic_annex | `CUADRO 23a` | 405 | 2024-04-30 | 2026-06-30 | Cuadro N° 23a — Depósitos /1 del sector privado en bancos y financieras. |
| economic_annex | `CUADRO 25` | 324 | 2024-04-30 | 2026-06-30 | Cuadro N° 25 — Créditos y depósitos del sector privado y público en bancos y financieras — Tasas de variación  |
| economic_annex | `CUADRO 18` | 281 | 2023-12-31 | 2026-06-30 | Cuadro N° 18 — Balance monetario del Banco Central del Paraguay. — En millones de guaraníes. — Activos interna |
| economic_annex | `CUADRO 55` | 244 | 2018-01-31 | 2026-06-30 | Cuadro Nº 55 — Ingreso de divisas - entidades binacionales. — En miles de dólares. |
| economic_annex | `CUADRO 29 (Cont.)` | 216 | 2024-04-30 | 2026-06-30 | Cuadro N° 29 (continuación) — Panorama Monetario - Pasivos 1/ — En millones de guaraníes. |
| economic_annex | `CUADRO 22` | 190 | 2024-12-31 | 2026-06-30 | Cuadro N° 22 — Agregados monetarios. — Tasas de variación, (%). |
| economic_annex | `CUADRO 21` | 190 | 2024-12-31 | 2026-06-30 | Cuadro N° 21 — Agregados monetarios 1/ — En millones de guaraníes. |
| economic_annex | `CUADRO 27` | 190 | 2024-12-31 | 2026-06-30 | Cuadro N° 27 — Posición del BCP ante el sistema financiero. — En millones de guaraníes. |
| economic_annex | `CUADRO 24` | 189 | 2024-04-30 | 2026-06-30 | Cuadro N° 24 — Créditos de bancos y financieras al sector privado y público. |
| economic_annex | `CUADRO 29` | 189 | 2024-04-30 | 2026-06-30 | Cuadro N° 29 — Panorama Monetario - Pasivos 1/ — En millones de guaraníes. |
| economic_annex | `CUADRO 24a` | 189 | 2024-04-30 | 2026-06-30 | Cuadro N° 24a — Créditos de bancos y financieras al sector privado |
| economic_annex | `CUADRO 28` | 189 | 2024-04-30 | 2026-06-30 | Cuadro N° 28 — Panorama Monetario - Activos 1/ — En millones de guaraníes. |
| economic_annex | `CUADRO 30` | 108 | 2024-04-30 | 2026-06-30 | Cuadro N° 30 — Créditos y depósitos del sector privado y público en bancos y financieras. — Moneda extranjera  |
| bcp_fx_daily | `OpDivisas2020(DatosDiarios)` | 108 | 2020-11-30 | 2020-12-11 | Monto de Operaciones de Divisas del Banco Central del Paraguay (millones de USD) - Año 2020 |
| economic_annex | `Cuadro 21 a` | 95 | 2024-12-31 | 2026-06-30 | Cuadro Nº 21 a — Agregados Monetarios -Serie Histórica 1/ — En millones de guaranies |
| economic_annex | `CUADRO 11` | 83 | 1980-06-30 | 2026-06-30 | Cuadro Nº 11 — Evolución del salario mínimo legal. — Base 1980 = 100. |
| economic_annex | `CUADRO 17 ` | 64 | 2025-03-01 | 2026-06-01 | Cuadro Nº 17 — Índice de precios del productor. — Base Marzo 2025= 100. |
| economic_annex | `CUADRO 56a` | 63 | 2019-03-31 | 2020-04-30 | Cuadro Nº 56a — Reservas Internacionales Netas 1/ — En millones de dólares. |
| economic_annex | `CUADRO 26` | 54 | 2023-12-31 | 2026-07-31 | Cuadro N° 26 — Gastos de la Política Monetaria del BCP — En millones de guaraníes. |
| payments | `SIPAP_04` | 50 | 2026-03-31 | 2026-07-31 | Transferencias entre Clientes de Entidades Financieras, por rango de Monto |
| economic_annex | `CUADRO 56b` | 25 | 2019-03-31 | 2020-04-30 | Cuadro Nº 56b — Reservas Internacionales Netas — En millones de dólares. |
| economic_annex | `CUADRO 35` | 10 | 2019-12-31 | 2019-12-31 | Cuadro Nº 35 — Depósitos del sector público no financiero en el Banco Central del Paraguay — En millones de gu |
| economic_annex | `CUADRO 32 A` | 6 | 2026-01-01 | 2026-06-01 | Cuadro N° 32 A — Instrumentos Bursátiles-Documentos en Custodia — Total Guaraníes (MN+ME) |
| compensatory_fx_sales | `Ventas(DatosMensuales)` | 5 | 2026-08-31 | 2026-12-31 | Monto de Operaciones de Divisas Compensatorias y Complementarias del Banco Central del Paraguay (millones de U |
| payments | `CCC 02` | 2 | 2013-11-30 | 2013-11-30 | Cheques Pagados por Entidad Bancaria - (Cámara Compensadora de Cheques - BANCARD) |
| payments | `SIPAP_12` | 1 | 2026-07-31 | 2026-07-31 | Transferencias por funcionalidades del SPI |

## Sample — first, middle and last recovered cell of each worksheet

| Source | Worksheet | Cell | Period label | Period | Series label | Unit | Value |
|---|---|---|---|---|---|---|---:|
| bcp_fx_daily | `OpDivisas2020(DatosDiarios)` | R243C2 | 30-nov.-20 | 2020-11-30 | Compra del BCP — Sector Financiero | USD | 0 |
| bcp_fx_daily | `OpDivisas2020(DatosDiarios)` | R251C17 | 11-dic.-20 | 2020-12-11 | Sector Público + Sector Financiero — Acumulado en el Año | USD | 556.6718 |
| compensatory_fx_sales | `Ventas(DatosMensuales)` | R114C9 | Agosto | 2026-08-31 | Total Ventas | USD | 0 |
| compensatory_fx_sales | `Ventas(DatosMensuales)` | R116C9 | Octubre | 2026-10-31 | Total Ventas | USD | 0 |
| compensatory_fx_sales | `Ventas(DatosMensuales)` | R118C9 | Diciembre | 2026-12-31 | Total Ventas | USD | 0 |
| economic_annex | `CUADRO 11` | R13C3 | Enero/Junio | 1980-06-30 | Salario mínimo legal — Nominal — vigencia sub-anual | index | 20,520 |
| economic_annex | `CUADRO 11` | R78C3 | Mayo/Diciembre | 2001-12-31 | Salario mínimo legal — Nominal — vigencia sub-anual | index | 782,186 |
| economic_annex | `CUADRO 11` | R146C3 | Enero/Junio | 2026-06-30 | Salario mínimo legal — Nominal — vigencia sub-anual | index | 2,899,048 |
| economic_annex | `CUADRO 17 ` | R363C10 | 2025-03-01 | 2025-03-01 | Productos nacionales — Otros productos manufacturados | index | 100 |
| economic_annex | `CUADRO 17 ` | R378C21 | 2026-06-01 | 2026-06-01 | Productos importados — Otros productos manufacturados | index | 100.8991 |
| economic_annex | `CUADRO 18` | R378C2 | dic.-23 | 2023-12-31 | 826646.9 — 1289316.623 — 985944.58 — 1271784.12 — 2000365.48 | PYG | 74,887,344 |
| economic_annex | `CUADRO 18` | R399C2 | sept-25 * | 2025-09-30 | 826646.9 — 1289316.623 — 985944.58 — 1271784.12 — 2000365.48 | PYG | 73,138,488 |
| economic_annex | `CUADRO 18` | R408C16 | jun-26 * | 2026-06-30 | Otros activos y pasivos — c = (a+b) — Depósitos ME — 547123  | source_units | 31,133,616 |
| economic_annex | `CUADRO 21` | R371C2 | dic-24 (3/) | 2024-12-31 | BM — Base Monetaria | PYG | 30,341,938 |
| economic_annex | `CUADRO 21` | R389C11 | jun-26 (3/) | 2026-06-30 | M3 — e = (c+d) | PYG | 169,170,293 |
| economic_annex | `CUADRO 22` | R361C2 | dic-24 (1/) | 2024-12-31 | BM — Base monetaria — Variación — Mensual | percent | 9.058452 |
| economic_annex | `CUADRO 22` | R379C11 | jun-26 (1/) | 2026-06-30 | M3 — Billetes y monedas en circulación — Variación — Interan | percent | 5.88654 |
| economic_annex | `CUADRO 23` | R352C2 | abr-24 * | 2024-04-30 | En moneda nacional (en millones de guaraníes) — Cuenta corri | PYG | 30,651,010 |
| economic_annex | `CUADRO 23` | R365C10 | may-25 * | 2025-05-31 | En moneda extranjera (en millones de guaraníes) — Ahorro a l | source_units | 14,736,912 |
| economic_annex | `CUADRO 23` | R378C18 | jun-26 * | 2026-06-30 | Total de depósitos (millones de guaraníes) — Part. — % | percent | 175,118,352 |
| economic_annex | `CUADRO 23a` | R355C2 | abr-24 * | 2024-04-30 | En moneda nacional (en millones de guaraníes) — Cuenta corri | PYG | 27,432,674 |
| economic_annex | `CUADRO 23a` | R368C9 | may-25 * | 2025-05-31 | En moneda extranjera (en millones de guaraníes) — Ahorro a l | source_units | 13,530,181 |
| economic_annex | `CUADRO 23a` | R381C16 | jun-26 * | 2026-06-30 | Total de depósitos (millones de guaraníes) — Part. — % | percent | 152,191,283 |
| economic_annex | `CUADRO 24` | R354C2 | abr-24 (1/) | 2024-04-30 | Moneda nacional — En millones de guaranies | PYG | 88,747,987 |
| economic_annex | `CUADRO 24` | R367C5 | may-25 (1/) | 2025-05-31 | Moneda extranjera — En millones USD | source_units | 10,143.58 |
| economic_annex | `CUADRO 24` | R380C8 | jun-26 (1/) | 2026-06-30 | Total de saldos — En millones de guaranies | PYG | 197,202,982 |
| economic_annex | `CUADRO 24a` | R354C2 | abr-24 (1/) | 2024-04-30 | Moneda nacional — En millones de guaranies | PYG | 82,032,413 |
| economic_annex | `CUADRO 24a` | R367C5 | may-25 (1/) | 2025-05-31 | Moneda extranjera — En millones USD | source_units | 9,824.551 |
| economic_annex | `CUADRO 24a` | R380C8 | jun-26 (1/) | 2026-06-30 | Total de saldos — En millones de guaranies | PYG | 184,652,281 |
| economic_annex | `CUADRO 25` | R341C2 | abr-24 (1/) | 2024-04-30 | Depósitos del sector privado público en bancos y financieras | percent | 0.1416252 |
| economic_annex | `CUADRO 25` | R367C13 | jun-26 (1/) | 2026-06-30 | Créditos de bancos y financieras al sector privado y público | percent | 5.062055 |
| economic_annex | `CUADRO 26` | R297C2 | dic.-23 | 2023-12-31 | Remuneración por IRM 1/ — 127845.196 | PYG | 112,629.4 |
| economic_annex | `CUADRO 26` | R331C7 | Jul-26 (3/) | 2026-07-31 | Total de gastos — ME — 161286.627 | source_units | 88,439.53 |
| economic_annex | `CUADRO 27` | R388C2 | dic-24 (2/) | 2024-12-31 | Crédito al sist. financiero del BCP — Sistema bancario — 117 | PYG | 1,343,150 |
| economic_annex | `CUADRO 27` | R406C11 | jun-26 (2/) | 2026-06-30 | Posición neta — Depósitos del resto del sistema financiero — | PYG | -26,920,231 |
| economic_annex | `CUADRO 28` | R364C2 | abr-24 (2/) | 2024-04-30 | Activos Externos Netos (AEN) | PYG | 72,470,359 |
| economic_annex | `CUADRO 28` | R377C5 | may-25 (2/) | 2025-05-31 | Activos Internos Netos (AIN) — Crédito - Sector Privado | PYG | 176,372,327 |
| economic_annex | `CUADRO 28` | R390C8 | jun-26 (2/) | 2026-06-30 | Total Activos — Total AIN | PYG | 224,738,504 |
| economic_annex | `CUADRO 29` | R363C2 | abr-24 (3/) | 2024-04-30 | Billetes y Monedas en Circulación - M0 | PYG | 17,723,052 |
| economic_annex | `CUADRO 29` | R376C5 | may-25 (3/) | 2025-05-31 | Depósitos en Cuenta Corriente | PYG | 28,446,830 |
| economic_annex | `CUADRO 29` | R389C8 | jun-26 (3/) | 2026-06-30 | M2 | PYG | 100,499,762 |
| economic_annex | `CUADRO 29 (Cont.)` | R363C2 | abr-24 (3/) | 2024-04-30 | M2 | PYG | 77,421,895 |
| economic_annex | `CUADRO 29 (Cont.)` | R389C9 | jun-26 (3/) | 2026-06-30 | Total Pasivos | PYG | 224,738,504 |
| economic_annex | `CUADRO 30` | R340C2 | abr-24 (1/) | 2024-04-30 | Depósitos — Mensual | percent | 1.138963 |
| economic_annex | `CUADRO 30` | R366C5 | jun-26 (1/) | 2026-06-30 | Créditos — Interanual | percent | 21.43076 |
| economic_annex | `CUADRO 32 A` | R161C2 | 2026-01-01 | 2026-01-01 | Títulos de Crédito | PYG | 21,596,286,664 |
| economic_annex | `CUADRO 32 A` | R166C2 | 2026-06-01 | 2026-06-01 | Títulos de Crédito | PYG | 19,774,053,712 |
| economic_annex | `CUADRO 35` | R328C11 | dic- 19* | 2019-12-31 | Total — 291729 — 426041 — 326912 — 228542 — 478984 | PYG | 7,341,939 |
| economic_annex | `CUADRO 35` | R328C2 | dic- 19* | 2019-12-31 | Administración Central — MN — 1990 — 1991 — 1992 — 1993 — 19 | PYG | 1,180,527 |
| economic_annex | `CUADRO 55` | R348C2 | Ene* | 2018-01-31 | Itaipú1 | USD | 30,238.66 |
| economic_annex | `CUADRO 55` | R465C4 | Jun* | 2026-06-30 | Total | USD | 45,623.74 |
| economic_annex | `CUADRO 56a` | R321C3 | mar.-19 | 2019-03-31 | Oro — 13.5 — 12.8 — 11.6 — 13.7 | USD | 341.2144 |
| economic_annex | `CUADRO 56a` | R331C7 | ene.-20 | 2020-01-31 | Divisas — Corresponsales en el exterior — Plazo — Dólares —  | USD | 6,409.488 |
| economic_annex | `CUADRO 56a` | R334C11 | abr.-20 | 2020-04-30 | Otros activos de reserva — Saldo — Plazo — Otras monedas — 6 | USD | 9,257.578 |
| economic_annex | `CUADRO 56b` | R133C3 | mar.-19 | 2019-03-31 | Oro | USD | 341.2144 |
| economic_annex | `CUADRO 56b` | R142C5 | dic.-19 | 2019-12-31 | Tramo de Reservas en el FMI (DEG) | USD | 64.78598 |
| economic_annex | `CUADRO 56b` | R146C7 | abr.-20 | 2020-04-30 | Saldo | USD | 9,257.578 |
| economic_annex | `CUADRO 59` | R324C2 | Ene** | 2016-01-31 | Saldos | USD | 3,979,611 |
| economic_annex | `CUADRO 59` | R468C5 | May** | 2026-05-31 | Transf. Neta — (a-b) | USD | -137,445.5 |
| economic_annex | `Cuadro 21 a` | R790C2 | dic-24 (2/) | 2024-12-31 | BM | PYG | 30,341,938 |
| economic_annex | `Cuadro 21 a` | R799C4 | sep-25 (2/) | 2025-09-30 | M1 | PYG | 43,866,788 |
| economic_annex | `Cuadro 21 a` | R808C6 | jun-26 (2/) | 2026-06-30 | M3 | PYG | 169,170,293 |
| interbank_market | `Datos (+ de 1 día)` | R503C21 | 2013-12-03 | 2013-12-03 | Call Money Market (USD) — Monto — operacion 1 | USD | 1,000,000 |
| interbank_market | `Datos (+ de 1 día)` | R2625C16 | 2022-04-08 | 2022-04-08 | 15000 — 1 — 2.5 — 7 — REPO Tripartito (PYG) — # de Operacion | count | 1 |
| interbank_market | `Datos (+ de 1 día)` | R3704C20 | 2026-08-14 | 2026-08-14 | 20000 — 1 — 7 — 2 — REPO Tripartito (PYG) — Plazo | PYG | 4 |
| payments | `CCC 02` | R5C11 | 2013/11 | 2013-11-30 | BCPAPYPXXXXX — Cantidad | count | 4,245 |
| payments | `CCC 02` | R5C12 | 2013/11 | 2013-11-30 | BCPAPYPXXXXX — Importe | source_units | 450,656,997,826 |
| payments | `SIPAP_04` | R153C65 | 2026/03 | 2026-03-31 | PYG (SPI) — 6- Más de 5 a 6 Millones — Cantidad | count | 69,434 |
| payments | `SIPAP_04` | R157C74 | 2026/07 | 2026-07-31 | PYG (SPI) — 10- Más de 9 a 10 Millones — Importe | PYG | 1,300,280,114,048 |
| payments | `SIPAP_12` | R54C17 | 2026/07 | 2026-07-31 | Transferencias con QR (H) | source_units | 302,815 |

## What to confirm

1. The header path in the workbook matches the series label.
2. The period label in column or row matches the period the parser assigned.
3. The value is the published figure, in the unit the series claims.
4. For `CUADRO 11`, that the sub-annual rows are the wage *in force* over the interval and the
   annual row above them is the year's average — not the same measure twice.
5. For `Datos (+ de 1 día)`, that the REPO Tripartito block (columns 15–20) is an instrument and
   not a restatement of the Call Money block, and that a continuation row is one operation of the
   day whose aggregate is the dated row above it.

Sign here when done, and record the reviewer and date in `config/table_status.csv` if the check
supports promoting any of these worksheets.

Reviewed by: _______________  Date: ____________
