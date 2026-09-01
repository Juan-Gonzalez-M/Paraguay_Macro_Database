# Concept governance

## Why this layer exists

Two series can have similar labels while differing in definition, seasonal adjustment, price basis, unit, scale, frequency, institutional coverage or revision policy. The database therefore separates a **source series** (`dim_series`) from an **economic concept** (`dim_concept`). It never treats normalized labels as proof of equivalence.

At ingestion, each new series receives its own deterministic source-specific concept and a `source_identity` relationship in `map_series_concept`. This makes every series queryable through the concept layer without merging it with anything else.

## Adding a reviewed mapping

Edit `config/concept_mappings.csv`. Each row must contain:

| Field | Meaning |
|---|---|
| `concept_id` | Stable reviewed identifier chosen by the project, such as `concept:bcp:gdp_agriculture_real` |
| `concept_label` | Human-readable concept name |
| `concept_domain` | Broad domain such as `national_accounts` or `financial_conditions` |
| `definition` | Precise meaning and scope |
| `series_id` | Existing identifier from `v_series_catalogue` |
| `relationship` | `equivalent` only when observations are interchangeable; otherwise use a documented relation such as `component`, `benchmark`, or `related` |
| `evidence` | Official table, methodology or documented expert rationale |
| `reviewed_by` | Responsible reviewer or unit |
| `reviewed_at` | ISO date (`YYYY-MM-DD`) |

Run `source("run_update.R")` after editing. The guard rejects unknown series, duplicate mappings, incomplete review metadata, and `equivalent` groups whose unit, scale or frequency differ.

The production mapping file carries three reviewed rows for `concept:interbank_repo_rate_pyg` (one `aggregate`, two `component`); everything else stays source-specific until an authorized reviewer supplies evidence. The canonical layer added in schema 14 (`config/canonical_series.csv`, `config/methodology_regimes.csv`) is empty for the same reason: a canonical series is an economic claim, and its identifiers are assigned by a reviewer rather than derived from a parsed `series_id`, so that a future parser repair cannot move them. The test suite exercises the complete reviewed-mapping path with two synthetic, same-contract series in a temporary configuration; no test identity or equivalence is written to the production database.

## Recommended GDP/activity workflow

1. Load monthly activity and quarterly GDP as distinct source series with their official granular classifications.
2. Preserve seasonal-adjustment status, price basis, reference year, unit, scale and frequency in series metadata.
3. Create reviewed concepts at the narrowest defensible activity level.
4. Map monthly activity and quarterly GDP as `related` or `benchmark` unless the methodology supports true equivalence.
5. Use bridge or temporal-disaggregation models in analysis code; do not encode a model-based relationship as database identity.

## Queries

```r
source("scripts/05_query_helpers.R")

# Includes source-specific and reviewed mappings
concept_catalogue(con)

# Restrict to reviewed mappings
concept_catalogue(con, reviewed_only = TRUE)

# Retrieve all latest series assigned to one reviewed concept
series_by_concept(con, "concept:bcp:gdp_agriculture_real")
```

The source-specific mapping remains alongside a reviewed mapping for provenance. `series_by_concept()` defaults to reviewed relationships, so an unreviewed source identity cannot accidentally enter a harmonized analysis.
