# LRM closure — Schema 46

## Decision evidence

On 2026-09-17 Juan Manuel Gonzalez Masulli confirmed as human domain reviewer that LRM
interest-rate levels are percentages per annum. This is user-provided reviewer attestation,
not workbook-explicit or publisher-documented evidence. The controlled representation is
`PERCENT_PER_ANNUM`, displayed as `percent per annum`; source values are unchanged and are
neither divided by 100 nor annualized.

The same review authorized consolidation of `Subastas 2013` rows 15+21 and 17+22 as two
auction-date/tenor events. The governed register is
`config/lrm_event_consolidations.csv`.

## Consolidation

Amounts and bid counts are summed. Offered and assigned average rates are weighted by the
corresponding offered and assigned amounts. Available minima and maxima are selected. A
component with blank assigned amount, count and rates contributes no assignment; structural
absence is never converted to zero.

| Rows | Measure | Components | Consolidated |
|---|---|---|---:|
| 15+21 | announced amount | 500000 + 250000 | 750000 |
| 15+21 | offered amount | 715000 + 235000 | 950000 |
| 15+21 | assigned amount | 500000 + 115000 | 615000 |
| 15+21 | offered bids | 12 + 6 | 18 |
| 15+21 | assigned bids | 9 + 3 | 12 |
| 15+21 | offered average | 6.387762237762238; 6.614893617021277 | 6.443947368421052 |
| 15+21 | assigned average | 6.275; 6.5 | 6.317073170731708 |
| 15+21 | offered min / max | 6.00–6.75; 6.50–6.75 | 6.00–6.75 |
| 15+21 | assigned min / max | 6.00–6.50; 6.50–6.50 | 6.00–6.50 |
| 17+22 | announced amount | 300000 + 100000 | 400000 |
| 17+22 | offered amount | 360000 + 15000 | 375000 |
| 17+22 | assigned amount | 360000 + structurally absent | 360000 |
| 17+22 | offered bids | 4 + 1 | 5 |
| 17+22 | assigned bids | 4 + structurally absent | 4 |
| 17+22 | offered average | 7.622222222222222; 7.75 | 7.6273333333333335 |
| 17+22 | assigned average | 7.622222222222222; structurally absent | 7.622222222222222 |
| 17+22 | offered min / max | 7.40–7.75; 7.75–7.75 | 7.40–7.75 |
| 17+22 | assigned min / max | 7.40–7.75; structurally absent | 7.40–7.75 |

The 10,351 source observations remain in `staging.lrm_component_observations`. The current
analytical representation has 10,334 facts and 940 identities. The 22 consolidated facts have
52 links in `staging.lrm_derived_observation_lineage`, including six structurally blank row-22
assigned-field coordinates; no derived fact claims a single source
coordinate. Schema 44's 957 identifiers have complete Schema 45 migration coverage: 964 mapping
rows, 957 distinct old identifiers and 940 distinct new identifiers.

## Acceptance

Retained candidate `accepted_for_review_20260917_201100.duckdb` has SHA-256
`eaba62ab6efbc3c81a59dd77493282d5a3f28290319ec487f0876eb3b318c553`, build
`build:da67d6517df1dd3dae219ebc`, attempt `attempt:7eba4ebf8c1f4d731bb8bc87`, zero
release errors and 38 reconciled warnings. The 38 are pre-existing/environmental categories
(including explicit dirty-tree/environment overrides, acquisition/provenance queues, deferred
CDA/TCN inputs, and known source diagnostics); none is an LRM unit, collision, lineage,
reconciliation, or research-admission defect.

All 10,334 current LRM facts are exposed through `explore.events`; zero are admitted to
`research.*`. Non-LRM facts (1,216,731), identities (10,902), and admission states are unchanged.
CDA and TCN remain deferred with zero observations. Focused tests and the complete `testthat`
suite passed; the only suite warning is the intentional corrupt-zip ingestion-isolation fixture.
