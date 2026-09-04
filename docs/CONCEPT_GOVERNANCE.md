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

## Reviewing a series

`config/concept_mappings.csv` above answers "are these two series the same thing". `config/series_review.csv` answers the prior question: **what is this one series**. Both ship empty and both are economic claims under a named reviewer.

It exists because the gates for it did not have an input. Since schema 28 a series may not enter `marts.v_research_series` without unit, scale, frequency, stock/flow, nominal/real and seasonal adjustment, with `not_reviewed` not counting; and `canonical.series_semantic_evidence` has always preserved rows whose `basis` is `reviewed` while deleting and recomputing derived ones. Nothing had ever written one. There was an output worklist naming what was unreviewed and nowhere to put the answers.

### The row

One row per series, and every column below is required:

| Column | What it records |
|---|---|
| `series_id` | An identifier from `marts.v_catalogue_scalar_series`. A row naming a series that does not exist blocks the release. |
| `definition` | The publisher's own wording, quoted, at least 24 characters. Not a paraphrase — a reader has to be able to check it. |
| `definition_evidence_uri` | Where that wording is published. |
| `source_semantics` | What the source table and the row within it mean: worksheet, block, row label. |
| `frequency` | Publication frequency. |
| `reference_period_convention` | What the period *is* — calendar month dated at month end, fiscal year, quarter dated at quarter end. |
| `timing_basis` | `end_of_period`, `period_average`, `period_total` or `cumulative_to_date`. The difference between a stock read on the last day and an average over the month is not recoverable from the number. |
| `stock_flow` | `stock` or `flow`. |
| `unit_code`, `scale_multiplier`, `currency` | The measurement. `scale_multiplier` is the factor to base units, so thousands is `1000`. |
| `valuation` | `market_value`, `book_value`, `face_value`, `fob`, `cif` or `not_applicable`. FOB and CIF are not interchangeable and differencing them is not a trade balance. |
| `nominal_real` | `nominal` or `real`. |
| `price_base_year` | Required when `nominal_real` is `real`, meaningless otherwise. |
| `seasonal_adjustment` | `not_adjusted`, `seasonally_adjusted` or `trend_cycle`. |
| `transformation` | `level`, `index`, `growth_rate`, `contribution` or `ratio`. |
| `hierarchy_role` | `total`, `component` or `standalone`. |
| `parent_series_id` | Required when `hierarchy_role` is `component`. Prevents adding a total to its own parts. |
| `methodology_regime_id` | Required when `comparability` is not `comparable`; points at `config/methodology_regimes.csv`. |
| `comparability` | `comparable`, `break_documented` or `not_comparable`. |
| `availability_convention` | When the figure becomes available relative to its reference period. This is the publication-lag claim, and it is a claim. |
| `reviewed_by`, `reviewed_at` | Who, and when. |

### What happens when you fill one in

Run `source("run_update.R")`. The register is applied **after** the derivation layer, so a reviewed answer overwrites a value guessed from a published label rather than racing it. The values land on `canonical.dim_series`, where every existing query already reads them, and the reviewer's sentence lands in `canonical.series_semantic_evidence` with `basis = 'reviewed'` — so `main.v_series_measurement` goes on showing the difference between "the publisher's label says so" and "an economist checked". `marts.v_series_review` publishes the full record.

### The gate

**A problem anywhere in the register applies none of it.** Not the good rows with the bad ones reported: a partly-recorded review fills exactly the columns the research-eligibility gate reads, so a series would become promotable on the strength of a row its reviewer never finished. The release blocks with `series_review_incomplete`, listing each problem against its `series_id`.

**And since schema 36 the register is what admits a series, which it was not before.** As shipped in schema 34 this register was written, validated, published — and read by nothing that decided anything. `marts.v_research_series` asked only whether every contributing worksheet was `validated`, and the eligibility check tested column values rather than reviewed evidence, so a series whose stock/flow came from a regex over the word `saldo` passed it exactly as a reviewed one would. Promoting one worksheet would have admitted every series on it with no economic review at all. That was the re-audit's RA2-02, and the documentation claiming otherwise — including the paragraph above this one — was mine.

Three things now hold together:

- `marts.v_research_series` and every `marts.v_mart_*` **join** this register. No row here, no research surface.
- `validate_research_eligibility_metadata()` requires each eligibility field to rest on a `series_semantic_evidence` row at `basis = 'reviewed'`, raising `research_series_evidence_not_reviewed` otherwise. A populated column is not a review.
- Worksheet review and series review are **both** required and answer different questions: `table_status` is about a source table's parsing and cell accounting, this register is about a series' economic meaning. Neither implies the other.

`outputs/semantic_review_worklist.csv` is the other end of the same workflow: it ranks the unreviewed series by weight and now names, per series, which register fields are still missing.

Nothing here is filled in. `marts.v_research_series` is 0 rows and stays 0 rows until an economist writes the first one.
