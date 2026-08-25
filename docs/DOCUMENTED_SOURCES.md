# Documented and expanded sources

## Assurance model

Excel report workbooks are normalized into `documented_series_snapshot` at grain `vintage × series × period`. Every value retains its workbook, sheet, row and column. The two large CSV sources use dedicated typed tables because their natural grains are curve points and individual market transactions rather than generic report cells.

These layers preserve source meaning; they do not assert that similarly named indicators are equivalent or that every row on a worksheet can be summed.

## Source coverage

| Source | Contract and interpretation |
|---|---|
| Economic Annex | 93 statistical sheets using recurring period orientations; index excluded |
| Payments | 38 statistical sheets plus official BIC participant dimension |
| Exchange houses | Three authoritative panels plus verified entity, currency and item references |
| Credit survey | Quarterly question-response shares and credit indices |
| Liquidity facility | Deposit/repo auction rows keyed by operation type, settlement date and term; repeated same-day events retained in explicit lanes |
| Direct investment | Seven statistical year-quarter tables; contents sheet excluded |
| Insurance annex | 41 fiscal-year tables; cover and index excluded |
| BCP daily FX | Fourteen annual daily-operation sheets |
| Exchange rates | Dedicated daily buy/sell parser plus six historical tables |
| Banking indicators | Seven monthly bancarization tables; cover and index excluded |
| Financial indicators | Eleven monthly wide tables; index excluded |
| Interbank market | Three worksheets; workbook chartsheet ignored and extreme blank formatting bounded |
| LRM auctions | Fourteen annual auction-result sheets |
| Compensatory FX sales | Monthly year blocks; future formula-only template months excluded |
| Corporate bond curves | Typed long CSV with curve parameters and rate points |
| Securities trades | Typed long CSV with deterministic transaction identities and daily aggregate view |

Minimum sheets, observations and date bounds for Excel sources live in `config/documented_source_contracts.csv`. CSV row, date, key and currency requirements live in `config/long_csv_contracts.csv`.

## Orientation and exception policy

The generic classifier measures typed dates, years, Spanish month labels and quarter labels by row and column. Supported modes include `vertical_date`, `horizontal_date`, `horizontal_year`, `vertical_year`, `vertical_block`, `horizontal_year_quarter` and `horizontal_year_month`.

Reviewed exceptions are configuration, not code: `config/sheet_modes.csv` selects a mode by `source_id + source_sheet`, with wildcard defaults. The `CUADRO 57a` exception is recorded there. Dedicated parsers are used only when the workbook has semantics that an orientation cannot represent safely, including credit questions, exchange-house panels, fiscal insurance years, daily exchange quotations, row-event tables and year-block compensatory sales.

Excel worksheets can declare huge formatted ranges or contain chartsheets. XML inventory records the declared range but derives the read bound from cells containing a value, inline string or formula. Non-worksheet relationships are skipped. Reads begin at A1 so retained row and column coordinates remain true Excel coordinates.

## Stable series identity

For documented Excel sources, the identity basis is:

```text
source_id + source_sheet + semantic label path + frequency
```

`unit`, `scale` and `currency` are attributes, not identity. Correcting an inferred unit therefore changes metadata under the same series rather than deleting one series and creating another.

If two observations still have the same semantic path and period, a row or column slot is added only as a collision disambiguator. Those series carry `identity_stability = positional`; all others normally carry `semantic`. Event tables first use published dimensions such as operation type, instrument, residual term or auction term. Liquidity explicitly distinguishes `deposito` and `repo`. If those dimensions still identify more than one same-day event and the publisher supplies no operation ID, every occurrence is retained in deterministic source order with `identity_stability = positional_lane`. Amounts and rates never enter either identity. `identity_basis` exposes the exact pre-hash input. Both positional states warn that a future layout insertion may require reviewed identity remediation.

`documented_series_continuity` compares a new vintage to the preceding completed vintage and lists:

- `new` series;
- `disappeared` series;
- continuing series whose unit, scale or currency changed.

Each source contract specifies a small allowed disappearance count. Exceeding it raises `documented_series_identity_break`. Any metadata change on a continuing identity raises `documented_series_metadata_changed`. Either condition rolls back the source transaction before sparse tombstones or revisions are committed. The full affected list is then persisted as a diagnostic and exported to `outputs/documented_series_continuity_latest.csv`.

## Unit, scale and hierarchy policy

Units and scales are inferred only from explicit source text. If no unique unit is stated, `unit = source_units`. Index, percent, ratio and count observations must have `scale = units`, regardless of a monetary scale mentioned elsewhere in the table title. Within one vintage, a series cannot have conflicting unit/scale/currency metadata.

Currency code 6200 remains foreign-currency origin measured in PYG; it is never USD. The USD-measured code is 6100.

Many official sheets publish totals beside components. Until a reviewed parent-child model exists, `hierarchy_status = unresolved` is carried in `documented_table_catalog`, `documented_series_snapshot` and `dim_series`. Do not sum every series from such a sheet. Flat sources are marked `flat`; cover/reference sheets are `not_applicable`.

## Typed CSV tables

`bond_curve_snapshot` preserves source row, date, currency, risk rating, maturity, zero-coupon rate, discount factor, par rate and Nelson-Siegel/Svensson parameters. Curve rates also enter the sparse series layer using semantic identities based on currency, rating, maturity and measure.

`securities_transactions_snapshot` preserves source row, broker, issuer, ISIN, instrument, market, operation type, local-currency volume, currency and venue. `transaction_id` hashes the complete economic row plus an ordinal for exact duplicate source rows. `v_securities_daily_activity` aggregates the latest accepted vintage by date, currency, instrument, market, operation type and venue.

Both readers force all source fields to text first, require the exact header signature, parse Spanish decimal commas explicitly, enforce minimum row/date/currency contracts and reject truncation relative to the prior vintage.

## Review queries

```sql
-- Fragile identities or unresolved aggregation hierarchy
SELECT source_id, source_sheet, identity_stability, hierarchy_status, count(*) AS series
FROM v_documented_series_catalogue
WHERE identity_stability LIKE 'positional%' OR hierarchy_status = 'unresolved'
GROUP BY 1,2,3,4 ORDER BY 1,2;

-- Series continuity changes in the last run
SELECT * FROM documented_series_continuity
ORDER BY vintage_id DESC, source_id, change_type, source_sheet;

-- Trace a documented value to Excel
SELECT source_file, source_sheet, source_row, source_column,
       source_period_label, series_label, unit, scale, value
FROM v_documented_series_latest_snapshot
WHERE series_id = '<series id>' AND period = DATE '<yyyy-mm-dd>';

-- Latest bond curve and securities activity
SELECT * FROM v_bond_curves_latest WHERE currency = 'PYG' LIMIT 100;
SELECT * FROM v_securities_daily_activity ORDER BY operation_date DESC LIMIT 100;
```
