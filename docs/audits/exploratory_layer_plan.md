# Exploratory researcher layer plan

Date: 2026-09-13

## Purpose and evidence base

This plan adds broad discovery and preliminary retrieval without changing the admission rules or
meaning of the existing `research.*` layer. It is based on the complete review of `AUDIT_REPORT.md`,
`docs/audits/audit_resolution_plan.md`, and `docs/audits/audit_resolution_report.md`, followed by
inspection of the current code, configuration, source registry, generated schema-41 database, and
schema-42 platform changes in the worktree.

The path named `docs/audits/database_audit_2026-09-13.md` does not exist in the repository. The root
`AUDIT_REPORT.md` is dated 2026-09-13 and identifies the same production database SHA-256 recorded in
both resolution documents, so it is the audit report used here.

The production database contains 13,985 parser-identified rows in `canonical.dim_series`, 1,226,739
current actual observations, and 32 admitted research series. The current facts have no null or
non-finite current values, duplicate fact keys, or malformed stored dates. Those facts establish that
broad preliminary retrieval is feasible. They do not establish economic meaning, continuity,
comparability, completeness, or human review. The new interfaces therefore expose these limitations
rather than treating canonical extraction as research admission.

## Architectural placement

The authoritative loader remains `scripts/load_project.R`. `run_update.R` calls the isolated candidate
workflow in `scripts/06_pipeline.R`; the new views will be created during the existing
`create_research_views()` platform phase after canonical semantics, table status, missingness, marts,
and the active release boundary exist. The function will be renamed only if needed for clarity; its
pipeline position will not move.

The implementation will add schema version 43 and these schema-qualified interfaces:

| Object | Grain and role |
|---|---|
| `catalog.series` | One row per `canonical.dim_series.series_id`; complete candidate discovery and profile metadata. |
| `catalog.series_warnings` | One row per `(candidate_id, warning_code)`; normalized limitations for filtering and review. |
| `catalog.datasets` | One row per governed source dataset; covers direct panels and long-form sources that are not represented completely by scalar-series rows. |
| `catalog.profile(candidate_id)` | Table macro returning the single `catalog.series` profile. |
| `explore.series_catalog` | The subset of catalogue series that has a dedicated exploratory observation interface; status remains visible. |
| `explore.observations` | Current actual scalar observations keyed by `(candidate_id, reference_period_start)`. |
| `explore.events` | Current event observations, with event date/bounds and source lineage. |
| `explore.panel_observations` | Current parser-identified entity-panel observations, preserving the full candidate identity/path and available dimensions. |
| `explore.curve_observations` | Current parser-identified curve-panel observations, preserving the full candidate identity/path; `research.curves` remains the dedicated certified curve-node interface. |
| `explore.series(candidate_id)` | Table macro returning one scalar candidate from `explore.observations`. |

`research.*` remains unchanged: human-reviewed or rule-certified scalar admission continues through
`main.v_certified_research_series`, and the existing separately certified entity-panel, curve,
transaction, and event interfaces retain their controls. No new tier is an assurance level and no
catalogue status will be translated into `human_verified` or `rule_certified`.

All new objects will be declared in `config/public_view_contract.csv`. Stored definitions will use
schema-qualified project dependencies and will be tested from a fresh connection with an empty
`search_path` and while the database is attached under an alias.

## Candidate grain and stable identifiers

For series-like extracts, `candidate_id` is exactly `canonical.dim_series.series_id`. It is not a hash
of a display label, an inferred cross-source concept, or a newly collapsed identity. This preserves the
project's existing parser identity, source distinctions, and migration machinery. The catalogue will
also expose `identity_basis` and `identity_stability`; positional and positional-lane identifiers remain
discoverable but are not described as stable across future workbook layouts.

For direct panels and long-format datasets that are not exhaustively represented by `dim_series`,
`catalog.datasets.dataset_id` remains the governed identifier. Its row will declare the native grain,
available dedicated interface, series and observation counts where meaningful, provenance status, and
use restrictions. The implementation will not invent scalar IDs for transaction, panel, or curve rows.

Source dimensions already encoded in `series_id`, `full_series_path`, or the documented snapshot remain
separate fields where available: product, trade flow/classification/regime, measure, entity,
participant, exchange item, question/response, source currency, reporting unit, sector, and institution.
No dimension will be dropped to manufacture longer or apparently more complete series.

## Mechanical profile and validation tiers

The profile is computed from the active current actual relation `main.v_series_latest`, the canonical
dimension, title/domain/dimension/measurement views, active source provenance, table status, expected
missingness, and source-level quality flags. Counts and dates always refer to current actual observations;
publisher projections remain outside this profile and outside `explore.*`.

The exact tier order is fail-closed:

1. `quarantined_or_invalid` when the candidate's current table status is quarantined/invalid, an active
   error flag targets the series or its source table, or the mechanical profile finds a malformed period,
   null/non-finite current value, duplicate normalized logical key, or conflicting normalized logical key.
2. `research_ready` when the series is admitted by `main.v_certified_research_series`. This condition is
   evaluated only after the invalidity checks, so a broken research object cannot be masked by admission.
3. `non_scalar_or_special_structure` for event, entity-panel, curve-panel, interval, and any other
   non-scalar grain. These candidates are linked to grain-specific interfaces and are never mixed into
   the ordinary scalar table.
4. `candidate_needs_review` for scalar candidates with positional/positional-lane identity, fewer than
   three current non-missing observations, no current observations, or another failure of the minimum
   scalar conditions.
5. `exploratory_structurally_valid` for the remaining scalar candidates.

An ordinary scalar candidate is mechanically eligible only if it:

- has `series_grain = 'scalar_series'` and a semantic identity;
- has at least three current observed, finite, non-missing values;
- has non-null normalized period bounds with `period_end >= period_start`;
- has exactly one value per `(candidate_id, reference_period_start)` and no conflicting values there;
- belongs to the active data release and has no applicable error-severity quality flag; and
- is not attached to a table status explicitly marked quarantined or invalid.

These are retrieval and key-integrity conditions, not economic validation. Unknown units, unresolved
hierarchy, missing review, incomplete provenance, gaps, inferred availability, and absent continuity
evidence generate warnings but do not by themselves alter publisher values or prevent preliminary
retrieval. The 25 audited one- or two-observation scalar candidates remain in `catalog.series` as
`candidate_needs_review` and are not placed in `explore.observations`.

## Frequency, regularity, gaps, and missingness

The published `frequency` is retained unchanged. Because the current semantic evidence register does
not record a frequency basis, `frequency_basis` will say `parser_assigned_requires_verification`; it
will not call the frequency publisher-documented without evidence. Future reviewed evidence can replace
that status without changing the source value.

For annual, semiannual, quarterly, monthly, and monthly-survey candidates, the catalogue will compute
the number of steps longer than the declared interval and an estimated count of skipped regular periods
from normalized period starts. Daily and explicitly irregular frequencies will be labelled
`irregular_by_contract`; weekend and event gaps will not be called missing observations. Candidates with
fewer than three observations will be labelled `too_short_to_assess`. Expected-grid counts and explicit
missingness reasons will be summarized separately where the project has constructed a grid; absence of a
grid will be stated rather than interpreted as complete coverage.

## Metadata, lineage, and warnings

`catalog.series` will expose the source label and full source path alongside a researcher-facing name.
The latter will use a reviewed canonical name when present and otherwise the source label, with a field
that states which basis was used. Domain, subdomain, measure family, and explicit parsed dimensions will
remain nullable. Unknown economic fields will retain project-controlled values such as
`UNRESOLVED_SOURCE_UNITS`, `not_reviewed`, or null and will have a companion warning; the view will not
fill them from label matching.

Source lineage will include source ID, publisher, source file, workbook sheet/table title, source
vintage and SHA-256, parser mode, source row/column when retained, and the active build's schema version
and code digest. The repository has no independent parser-version field, so the catalogue will state
`parser_version_status = 'not_recorded_use_build_code_digest'` rather than manufacture a version number.
Observation-level coordinates will be left null for specialized paths that never entered
`staging.documented_series_snapshot`; the associated warning will state that only fact/source-vintage
lineage is available.

Every catalogue and exploratory row will carry `validation_tier`, `status_code`, and a concise warning.
`catalog.series_warnings` will normalize at least these conditions where applicable: non-research
status, semantic review incomplete, unresolved unit, hierarchy unresolved, positional identity, short
series, declared-frequency gaps, incomplete provenance, inferred availability, incomplete coordinate
lineage, table provisional/quarantined, and special structure. Default queries will include every tier;
no default discovery view will filter by status.

## Structure-specific representation

- Scalar candidates use `explore.observations` only after the minimum conditions pass.
- Event and interval candidates use `explore.events`, retaining source period and normalized start/end;
  single events remain legitimate and are not rejected for shortness.
- Entity-panel candidates use `explore.panel_observations`, retaining the parser candidate ID, full path,
  and all available parsed dimensions. The separately certified EEFF product remains
  `research.entity_panel` with its native source-currency key.
- Curve-panel candidates use `explore.curve_observations` for parser-identified candidate retrieval;
  researchers needing economic curve nodes use the existing `research.curves` dedicated relation.
- Securities trades have no artificial scalar-series conversion; `catalog.datasets` links directly to
  the existing `research.transactions` transaction-grain relation.
- Other direct panel datasets remain discoverable through `catalog.datasets` with their status and
  maintainer/source-view lineage. They will not be exposed through a generic scalar interface until a
  native public grain and missing-value contract exists.

## Backward compatibility

This is additive schema version 43. Existing `main.*`, `marts.*`, and `research.*` object names, columns,
admission rules, certification decisions, and row populations remain unchanged. Existing consumers may
ignore `catalog` and `explore`. The production DuckDB will not be overwritten; validation will migrate
or build a temporary copy/candidate.

## Implementation files

- `scripts/12_platform.R`: create the two schemas, views/macros, tier logic, and release-blocking
  integrity checks.
- `scripts/02_extract_raw.R`: register schema version 43 as an additive interface migration.
- `config/public_view_contract.csv`: classify each new view/macro and declare its scope/grain.
- `tests/testthat/test-exploratory-layer.R`: focused coverage, key, tier, warning, lineage, binding, and
  research-regression tests using an isolated database copy.
- `tests/testthat/test-research-platform.R`: adjust only the exact schema-version expectation and retain
  the exact governed research-object assertion.
- `docs/RESEARCH_DATABASE_GUIDE.md` and `docs/DATA_MODEL.md`: describe supported exploratory use and give
  example SQL without weakening research admission language.
- `docs/SCHEMA_MIGRATIONS.md`: generated/registered schema-43 entry if the repository's migration test
  requires it.
- `docs/audits/exploratory_layer_implementation_report.md`: final counts, checks, limitations, commands,
  and release recommendation.

## Acceptance tests

The isolated schema-43 candidate must demonstrate all of the following:

1. `catalog.series` has exactly one row for every `canonical.dim_series.series_id`, no extra ID, and no
   null candidate ID, tier, status, warning, retrieval interface, or source ID.
2. Every current canonical observation links to exactly one catalogue row. Dataset catalogue coverage
   matches every governed source, including sources represented only by direct-panel or long-form tables.
3. Every `explore.observations` row links to one `catalog.series` row whose tier is `research_ready` or
   `exploratory_structurally_valid`; every scalar candidate with either eligible tier has all and only its
   current actual observations in that view.
4. `explore.observations` has zero null/non-finite values, malformed bounds, duplicate normalized keys,
   conflicting normalized keys, projections, positional identities, or candidates with fewer than three
   observations.
5. Event, panel, and curve views contain only their declared grain, retain candidate/tier/warning/source
   lineage, and have no duplicate native generic keys. Special candidates never enter the scalar view.
6. All 25 audited one- or two-observation scalar candidates remain discoverable and zero enter ordinary
   exploratory scalar observations.
7. Every researcher-facing catalogue and exploratory interface has validation tier/status, concise
   warning, source/vintage lineage, and a documented retrieval method; normalized warning rows reconcile
   to profile warning counts.
8. The existing `research` schema still contains exactly its nine views plus its macro, the research
   series and observation counts are unchanged from the pre-migration copy, and its admission checks pass.
9. Every stored view binds from a fresh default read-only connection without `search_path` and when the
   database is attached under an alias.
10. A selected candidate can be searched, profiled through `catalog.profile`, retrieved through
    `explore.series`, and joined to source file, sheet/table, coordinates where available, build code
    digest, validation tier, and warnings.
11. A deliberate malformed/duplicate fixture is classified or blocked and cannot appear as an ordinary
    exploratory scalar observation.
12. The focused tests, public-interface tests, migration tests, full real-workbook smoke build, and full
    regression suite pass; the production database hash remains byte-for-byte unchanged.
