# Research database guide

Use `catalog.*` to discover the full parser-identified candidate universe, `explore.*` to retrieve
mechanically eligible preliminary observations, and `research.*` for formally admitted data. The
three schemas answer different questions. Catalogue membership means that the pipeline can identify
a source candidate; exploratory eligibility means that its current observations pass explicit key,
date, and finite-value checks; research admission requires the existing governed assurance process.

## Assurance

| Level | Meaning |
|---|---|
| `human_verified` | A named economist signed the complete semantic register. |
| `rule_certified` | A versioned deterministic rule and hashed evidence passed. It is not human review. |
| `provisional` | Retained and auditable, but not admitted to a default data view. |
| `quarantined` | A known collision or defect prevents use at the requested grain. |
| `excluded` | Intentionally outside that research product. |

The append-only record is `canonical.certification_decisions`; the current automated result is
`canonical.rule_certified_series`. Rules and their configuration hashes are in
`audit.certification_rules`.

Exploratory validation uses a separate vocabulary:

| Validation tier | Meaning |
|---|---|
| `research_ready` | The candidate is admitted to `research.*` at its stated assurance level. |
| `exploratory_structurally_valid` | Scalar observations pass the documented mechanical checks; economic review is incomplete. |
| `candidate_needs_review` | The candidate is identifiable but ordinary retrieval is withheld, commonly for positional identity or fewer than three observations. |
| `quarantined_or_invalid` | A governed invalid status or key/date/value-integrity failure prevents exploratory exposure. |
| `non_scalar_or_special_structure` | Use the event, panel, curve, transaction, or other native-grain interface. |

Validation tier is computed for access and never replaces `assurance_level`.

## Supported interfaces

```sql
-- 1. Search every candidate. Status is intentionally part of the result.
SELECT candidate_id, researcher_name, original_source_label, source_institution,
       source_id, domain, subdomain, data_structure, frequency,
       earliest_period, latest_period, observation_count, unit_code, currency,
       validation_tier, status_code, concise_warning
FROM catalog.series
WHERE source_id = 'economic_annex'
  AND frequency = 'monthly'
  AND (domain = 'prices' OR lower(researcher_name) LIKE '%precio%')
ORDER BY validation_tier, researcher_name;

-- Source datasets, including direct panels and long-format data.
SELECT * FROM catalog.datasets ORDER BY source_id;

-- 2. Inspect one concise candidate profile.
SELECT * FROM catalog.profile('economic_annex:cuadro_1:example_id');

-- 3. Retrieve a preliminary scalar candidate. Only mechanically eligible
-- exploratory or research-ready candidates return rows.
SELECT *
FROM explore.series('economic_annex:cuadro_1:example_id')
ORDER BY reference_period_start;

-- 4. Retrieve a formally admitted research series.
SELECT *
FROM research.observations_latest_actual
WHERE research_series_id = 'the_selected_research_series_id'
ORDER BY reference_period_start;

-- 5. Read every warning before analysis.
SELECT s.candidate_id, s.validation_tier, s.status_code,
       w.warning_code, w.warning
FROM catalog.series s
JOIN catalog.series_warnings w USING (candidate_id)
WHERE s.candidate_id = 'economic_annex:cuadro_1:example_id'
ORDER BY w.warning_code;

-- Formally admitted catalogue, publisher statement, and as-of macro.
SELECT * FROM research.series_catalog ORDER BY research_series_id;
SELECT * FROM research.observations_latest_statement;
SELECT * FROM research.observations_as_of(TIMESTAMP '2026-09-01 00:00:00');
```

Candidate IDs in examples are placeholders: search `catalog.series` and copy the exact ID returned
by the database. `catalog.series.observation_interface` names the appropriate relation. Scalar
candidates use `explore.observations`; interval and event candidates use `explore.events`; entity
and curve candidates use `explore.panel_observations` and `explore.curve_observations`. The certified
native curve and transaction interfaces remain `research.curves` and `research.transactions`.

`explore.*` guarantees current-release membership, a catalogue link, a finite value, ordered
normalized period bounds, and uniqueness at its declared generic candidate-period grain. It does not
guarantee a reviewed unit, economic definition, seasonal-adjustment status, stock/flow status,
hierarchy, completeness, continuity across publications, cross-source comparability, or real-time
availability. Keep `validation_tier`, `status_code`, and `warning_codes` with any extract.

For source inspection, treat `explore.*.source_sheet`, `source_row`, and `source_column` as one
observation-level locator. `table_title` comes from that same source observation. Candidate profiles
use `source_sheet` only for a complete single-worksheet series and expose `source_sheets`,
`source_sheet_count`, and `worksheet_lineage_status` when a series spans several worksheets. The
separate `identity_source_sheet`/`identity_basis` and `title_record_*` fields preserve the parser
identity and series-level title record; `worksheet_lineage_correction_reason` states why an
observation-specific worksheet replaced that record in retrieval.

Use `research.entity_panel`, `research.events`, `research.curves`, and `research.transactions` for
their native grains. Do not combine these with the scalar catalogue by counting identifiers as if
they were macroeconomic time series.

The EEFF panel key is `(source_id, reference_period, entity_id, item_id,
source_currency_code, measure)`. Preserve `source_currency_code` when grouping: `6200` means
foreign-currency-origin balances converted to PYG, while `6900` means PYG-origin balances measured
in PYG. `currency_of_origin` and `unit_currency` expose those two economic dimensions separately.
`economic_currency` and `currency` are compatibility aliases of the reporting unit and are not a
complete panel key.

## Current fitness

- Suitable now: latest-snapshot work using admitted scalar series; structurally certified curve and
  transaction analysis; banking statement analysis at the source-currency-code panel grain.
- Suitable with explicit researcher review: provisional source views in `main`/`marts`, provided the
  researcher records definitions, units, transformations, and exclusions in the project output.
- Not suitable yet: historical real-time forecasting evaluation, revision analysis, or claims about
  what was known before the retained snapshot. Forward vintage collection begins with
  `config/acquisition_contracts.csv`.
- Rights: every current acquisition contract says `license_status = unverified`. That does not erase
  source attribution and does not constitute permission for redistribution.

No automatic logs, growth rates, seasonal adjustment, deflation, interpolation, or splicing are
stored. `value_in_base_units` is only the deterministic published scale multiplication.

## First review workstream

The frozen baseline and complete continuation plan are in `PROJECT_HANDOVER.md`. The ranked economist queue is
`outputs/flagship_review_queue.csv`; it contains 50 scalar candidates with blank decision fields.
`outputs/duplicate_canonical_resolution_queue.csv` combines value-signature duplicates, panel
collisions, canonical proposals, and membership proposals. Complete those packets only after
checking the cited source cells and then promote decisions through the existing sign-off workflow.
The generator is `scripts/14_review_readiness.R` and is intentionally not run on every release, so a
baseline remains frozen until an operator explicitly creates a new one.

## Citation and reproducibility

Record the database SHA-256, schema version, active `data_release_id`, query text, assurance level,
and `research_series_id` values used. A citable artifact must be rebuilt from a clean Git commit;
development builds explicitly record and warn about a dirty worktree.
