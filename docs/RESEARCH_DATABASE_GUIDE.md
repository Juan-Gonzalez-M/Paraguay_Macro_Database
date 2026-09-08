# Research database guide

The research schema is the supported starting point. It is a governed subset of the database, not a
claim that every parsed source cell is economically comparable.

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

## Supported interfaces

```sql
-- Start here: scope, rights, vintage limits and allowed uses for every source.
SELECT * FROM research.dataset_catalog ORDER BY source_id;

-- Discover certified scalar series and their complete transformation metadata.
SELECT * FROM research.series_catalog ORDER BY research_series_id;

-- Realized values only. Join on normalized reference_period_start, not source_period_date.
SELECT * FROM research.observations_latest_actual;

-- Include the publisher's non-observed statement values, identified by observation_status.
SELECT * FROM research.observations_latest_statement;

-- A point-in-time query. Legacy available_at values are inferred upper bounds.
SELECT * FROM research.observations_as_of(TIMESTAMP '2026-09-01 00:00:00');
```

Use `research.entity_panel`, `research.events`, `research.curves`, and `research.transactions` for
their native grains. Do not combine these with the scalar catalogue by counting identifiers as if
they were macroeconomic time series.

## Current fitness

- Suitable now: latest-snapshot work using admitted scalar series; structurally certified curve and
  transaction analysis; banking statement analysis on collision-free panel keys.
- Suitable with explicit researcher review: provisional source views in `main`/`marts`, provided the
  researcher records definitions, units, transformations, and exclusions in the project output.
- Not suitable yet: historical real-time forecasting evaluation, revision analysis, or claims about
  what was known before the retained snapshot. Forward vintage collection begins with
  `config/acquisition_contracts.csv`.
- Rights: every current acquisition contract says `license_status = unverified`. That does not erase
  source attribution and does not constitute permission for redistribution.

No automatic logs, growth rates, seasonal adjustment, deflation, interpolation, or splicing are
stored. `value_in_base_units` is only the deterministic published scale multiplication.

## Citation and reproducibility

Record the database SHA-256, schema version, active `data_release_id`, query text, assurance level,
and `research_series_id` values used. A citable artifact must be rebuilt from a clean Git commit;
development builds explicitly record and warn about a dirty worktree.
