# CDA semantic decisions

Date: 2026-09-19
Reviewer: Juan Manuel Gonzalez Masulli
Evidence basis: user-provided human domain confirmation

The reviewer confirmed the following for the exact retained CDA source vintage
`cda_curve:8796a589fc2bd31317efdce7`:

- CDA rates are nominal annual percentages. Published numeric values remain
  unchanged; they are not divided by 100 or annualised again.
- Worksheet names containing `ML` represent local currency, Paraguayan guaranies
  (`PYG`). Worksheet names containing `ME` represent foreign currency, United
  States dollars (`USD`).
- Captured volumes are whole currency units: scale multiplier 1 for both PYG and
  USD.
- The 14 numeric cells in `OPERACIONES_VOLUMEN_ML_072025!O12:O25`, headed
  `Monto Capital Original` but lacking an institution heading, are publisher
  errors and must not become observations.
- The isolated numeric cell `OPERACIONES_VOLUMEN_ML_062025!G40`, whose row has
  no published tenor label, is also a publisher error and must not become an
  observation.

The 15 excluded values remain preserved in the immutable workbook and raw cell
layer. Their explicit coordinate classifications live in
`config/reconciliation_cell_rules.csv`; exclusion is therefore governed and
reconciled rather than silent. These decisions do not admit CDA to `research.*`.

The reviewer subsequently confirmed on 2026-09-19 that `CDA_ML_102021` keeps
the same institutional layout as the surrounding worksheets despite its blank
H9:I9 cells: column H is `BANCOS` and column I is `FINANCIERAS`. The 35 values
therefore join the corresponding stable cross-month CDA identities. The blank
publisher cells remain unchanged in raw evidence and the reviewed mapping is
visible through parser mode `cda_monthly_curve_reviewed_header_mapping`.
