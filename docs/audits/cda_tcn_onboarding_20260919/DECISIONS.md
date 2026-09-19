# Combined CDA and TCN decisions

Date: 2026-09-19
Reviewer/source owner: Juan Manuel Gonzalez Masulli

This workstream combines the already recorded CDA semantic decisions with the
exact TCN vintage `tcn_referential_daily:74df666397a33b9c8cdfac10` (SHA-256
`74df666397a33b9c8cdfac10d7ffedd23acf7cbd5907ea21332e100fb939c0a4`).

The source owner confirmed that:

- `TCN_Referencial_Diario.xlsx` was downloaded directly from the Banco Central
  del Paraguay;
- numeric quotations are Paraguayan guaranies per United States dollar;
- `Compra` and `Venta` preserve the same definitions from 2012 through 2026 and
  therefore form two continuous daily identities across the annual worksheets;
- `ND` denotes a weekend or holiday for which no quotation exists.

The parser preserves every `ND` token in raw cell evidence but emits no
observation, zero or interpolated value for it. Annual worksheet names and exact
A1 coordinates remain observation lineage. The acquisition URL, actual
retrieval timestamp, official release date, release identifier and licence were
not supplied and remain explicitly unresolved.

For CDA, the source owner additionally confirmed that blank cells H9:I9 in
`CDA_ML_102021` preserve the standard layout H = `BANCOS`, I = `FINANCIERAS`.
The 35 values join the corresponding stable CDA identities while the blank raw
headers remain unchanged.
