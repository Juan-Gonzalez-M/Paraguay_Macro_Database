# Bank and finance semantic reference

## Source and contract

`Referencias_bancos_financieras.xlsx` is ingested as the required `bank_reference` source. The parser reads Excel named tables rather than fixed cell coordinates. `config/reference_schema.csv` defines each expected worksheet, display-name hint, role, entity type and exact column list. Resolution uses worksheet plus column signature first; a display name is consulted only when signatures are ambiguous. A missing, ambiguous or structurally changed table fails the source transaction.

## Verified reference contents

| Semantic object | Current rows | Purpose |
|---|---:|---|
| Institution records | 31 | 21 bank/system plus 10 finance-company/system records |
| Currency codes | 2 | `6900 → MN, origin PYG, unit PYG`; `6200 → ME, origin FX, unit PYG` |
| Financial-statement items | 218 | 109 per institution family |
| Financial-statement account mappings | 456 unique | 460 source rows; two exact duplicate rows per institution family are deduplicated |
| Ratios | 80 | 40 per institution family |
| Portfolio items | 36 | 18 per institution family |
| Portfolio account mappings | 157 | Bank portfolio-account composition |
| Detailed credit activities | 1,112 | Activity code/description to bulletin sector |
| Credit sectors | 13 | Derived stable dimension shared by aggregate-sector and detailed-activity views |
| Named-table load records | 15 per vintage | Auditable source-table inventory and signatures |

Counts are enforced as minimum acceptance checks. The full named-table structure is enforced exactly.

## Mapping rules

- Entity joins require both `entity_type` and numeric-equivalent entity code.
- Currency joins use numeric-equivalent bulletin currency code.
- EEFF joins use institution family, normalized published label and report code.
- Ratio joins use institution family and normalized published label.
- Portfolio joins use institution family and normalized portfolio label.
- Detailed activities join on normalized description; the reference’s activity code and bulletin sector are appended.
- Semantic normalization lowercases, trims, collapses whitespace and removes Latin diacritics so source spellings such as `GANADERIA` match the verified `GANADERÍA`. It does not perform fuzzy matching.

## Currency semantics

The source label and measurement unit are separate facts:

| Code | Bulletin label | `currency_of_origin` | `unit_currency` | Interpretation |
|---|---|---|---|---|
| 6900 | MN | PYG | PYG | Operations in guaraníes, reported in guaraníes |
| 6200 | ME | FX | PYG | Foreign-currency operations converted to guaraníes at the month-end exchange rate |
| 6100 | USD | FX | USD | Future rule for values actually reported in foreign currency |

The current bank and finance bulletins contain 6900 and 6200, not 6100. A hard validation requires any description containing “convertidos a Gs.” to have `unit_currency = PYG`.

Account identifiers are forced to text during ingestion. `account_number_raw` preserves the official spacing/sign, while `account_number` contains digits only for joins. Scientific notation is rejected.

Underlying account mappings are separate one-to-many bridge tables. They are not joined directly to observation views because that would multiply each published observation by its component accounts.

## Mapping assurance

`validate_documented_financial_source()` requires complete entity/currency coverage and at least 99.9% hierarchy/activity coverage. Coverage below 95% is an error; smaller shortfalls are warnings. `outputs/documented_financial_coverage_latest.csv` reports row counts and mapped counts for all ten documented views.

Independent inspection of the supplied pilot files found:

- 100% entity and currency key coverage;
- 100% portfolio-item and detailed-activity coverage;
- 246,544 of 246,546 bank EEFF rows classified;
- 86,199 of 86,199 finance-company EEFF rows classified;
- 90,830 of 90,830 bank ratio rows classified;
- 41,190 of 41,195 finance-company ratio rows classified.

The residuals are two bank EEFF rows labelled `UTILIDAD A DISTRIBUIR` with no report code, and five finance-company ratio rows labelled `Capital Complementario (Nivel 2)`. They remain in the raw columns with null semantic keys; they are never discarded or guessed.

## Version behavior

Every distinct reference workbook is archived and receives a `vintage_id`. Snapshot tables preserve the parsed reference rows for that vintage. Current dimensions replace attributes for matching semantic keys while retaining each key’s original `first_vintage_id`.
