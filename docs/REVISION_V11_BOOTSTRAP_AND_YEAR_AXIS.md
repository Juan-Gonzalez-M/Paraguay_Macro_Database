# Version 11 bootstrap and year-axis repairs

Version 11 responds directly to `REVISION_v10.md`. It preserves the 22-source model, stable series identities, v8 performance work and the source-isolated v9/v10 parsers.

| Runtime finding | v11 correction | Regression |
|---|---|---|
| Fresh initialization entered the v9 migration and referenced undefined `affected_concepts` | `initialize_database()` captures the pre-existing database state before creating tables and skips historical invalidators only for a genuinely empty bootstrap | Fresh in-memory initialization must install schema 11 without errors |
| The v9 migration had an incomplete concept cleanup | Affected source-specific concepts are selected before deleting their mappings; only newly orphaned affected concepts are removed | The v10 selective-migration test preserves payment and unrelated concepts |
| `CUADRO 58` years after 2011 carry `1/` footnotes | `documented_year_values()` accepts only exact four-digit years with controlled star or numeric-slash suffixes | Helper test accepts `2012 1/` and rejects arbitrary numeric strings |
| A data column could beat the real year column by raw count | Candidate axes must be monotone, contain more than one distinct year and use plausible gaps; the `Año` token breaks otherwise equal scores | Adversarial matrix selects column 1 despite many 1900–2100 values in column 2 |
| Legacy v2 fixture lacked `dim_series.semantic_status` and other current attributes | Current `dim_series` columns are added before migrations and concept views | Existing v2 migration test plus fresh-bootstrap test |
| EEFF count appeared one row short | The full smoke test derives the expected data rows from the recorded worksheet bounds and subtracts exactly one header | Dynamic equality replaces an unexplained hard-coded count |

## Migration behavior

- Fresh database: install the current tables and schema versions, then ingest all current sources. No invalidation function is called.
- Existing v10 database: invalidate and reingest only `economic_annex` under v11.
- Existing v2–v9 database: execute only the applicable guarded historical steps, followed by the selective v11 Annex repair.
- Non-empty database without a recognized schema: fail closed and require backup recovery or the explicit v1 rebuild path.

The v11 change does not alter documented-series identity inputs. The Annex is reingested because corrected periods and labels are content changes; the other 21 sources remain reusable.
