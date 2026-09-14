# Audit resolution plan

Audit reviewed: `AUDIT_REPORT.md`, dated 2026-09-13, for
`database/paraguay_macro_pilot.duckdb` SHA-256
`17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180`.

This ledger evaluates the report against the repository and the database. The database is generated:
`run_update.R` loads the project through `scripts/load_project.R`, resolves the source manifest, and calls
`run_isolated_update()` in `scripts/06_pipeline.R`. That function builds in a candidate and swaps it into
the published path only after an accepted decision. No audit work will modify the published database.

The repository had pre-existing uncommitted source-onboarding work when this review began. In particular,
the CDA and daily referential exchange-rate sources, their configuration, parser code, and tests were
already modified or untracked. Those changes are treated as user work and are outside this audit except
that the complete regression suite must continue to pass with them present.

## Status definitions

- **Confirmed**: the reported condition and its material effect are reproduced.
- **Partial**: the evidence is real, but the report overstates the defect or omits an existing control.
- **Obsolete**: current executable controls already implement the requested protection.
- **Unsupported**: available evidence does not establish the claim.
- **Needs user decision**: the condition is real, but remediation requires one of the economic, source,
  release-product, or compatibility decisions reserved by the task's decision gate.

## Findings ledger

### AR-01 — `research.entity_panel` collapses source currency categories

- **Audit severity:** P0.
- **Verified status:** Confirmed.
- **Evidence:** `create_research_views()` in `scripts/12_platform.R` partitions the EEFF union by
  `(source_id, fecha, entity_id, statement_item_id, economic_currency)` and publishes only `n = 1`.
  `docs/DATA_MODEL.md` and `docs/SEMANTIC_REFERENCE.md` define `economic_currency` as a deprecated alias
  of `unit_currency`. The query reproduced from the report returns 332,745 source rows and 93,217
  research rows. It finds 119,764 collision groups, 119,737 with different values. Replacing the last
  key field with `codigo_moneda` yields zero collisions and zero conflicting groups. In
  `canonical.dim_currency`, code `6200` is `(currency_of_origin = FX, unit_currency = PYG)` and code
  `6900` is `(currency_of_origin = PYG, unit_currency = PYG)`; both have
  `economic_currency = PYG`.
- **Root cause:** the public view used a reporting-unit alias as though it represented the publisher's
  currency category and then silently filtered the collisions this created.
- **Proposed remedy:** publish `source_currency_code`, `currency_of_origin`, `unit_currency`, and
  `economic_currency`; retain `currency` only as the compatibility alias; key and certify the row on
  the source currency code; add release-blocking row-conservation and target-release collision checks.
- **Validation criterion:** 332,745 of 332,745 current EEFF rows reach `research.entity_panel`; zero
  duplicate or conflicting keys on `(source_id, reference_period, entity_id, item_id,
  source_currency_code, measure)`; codes `6200` and `6900` remain separately queryable; a deliberate
  duplicate fixture produces an error-severity release flag; all public objects bind from a fresh
  connection.
- **Implementation priority:** P0, automatic. The remedy preserves publisher distinctions and does not
  require an economic interpretation.

### AR-02 — uncertified content is present in the same DuckDB file

- **Audit severity:** P0.
- **Verified status:** Partial; needs user decision for any artifact redesign.
- **Evidence:** the file contains 13,985 rows in `canonical.dim_series` and 32 in
  `canonical.rule_certified_series`. However, `research.series_catalog` also has exactly 32 rows and
  `research.observations_latest_actual` has 7,498 rows, with zero rows lacking a matching research
  catalogue entry. `marts.v_research_series` additionally requires human review and balanced validated
  worksheets. `research.dataset_catalog` intentionally lists all sources, including 18 provisional and
  four rule-certified datasets, because it is a disposition catalogue rather than a data view.
  `config/public_view_contract.csv` classifies `_all`, diagnostic, reference, and current objects.
- **Root cause:** the audit treats physical co-location of maintainer layers as equivalent to publication,
  while the project defines publication by governed interfaces. A recipient can still bypass that
  convention if given the complete file.
- **Proposed remedy:** keep the existing fail-closed `research` boundary. Decide separately whether the
  distributable product should remain a complete auditable database or become a reduced researcher-only
  artifact; that choice changes the product and compatibility contract.
- **Validation criterion:** every scalar data row in `research` joins to an admitted series; every long
  research data view joins to an enabled dataset rule; the distribution documentation names the intended
  artifact scope.
- **Implementation priority:** P0 policy decision; no automatic artifact redesign.

### AR-03 — official provenance and licence evidence are incomplete

- **Audit severity:** P0.
- **Verified status:** Confirmed; needs user decision and source evidence.
- **Evidence:** grouping `main.v_source_provenance` returns 22 rows with
  `provenance_status = incomplete` and `availability_quality = inferred_upper_bound`.
  `research.dataset_catalog` reports `license_status = unverified` for every dataset.
  `config/acquisition_contracts.csv` deliberately records blank official landing pages and prohibits
  licence-assured redistribution. `outputs/source_provenance_worklist.csv` has one row per vintage plus
  its header.
- **Root cause:** legacy files were acquired before authoritative URL, release identifier, retrieval, and
  licence evidence were recorded.
- **Proposed remedy:** populate `config/source_vintages.csv` only from official evidence and let the
  existing provenance validation enforce it for future vintages. Do not invent or infer licences.
- **Validation criterion:** every released vintage intended for distribution is complete in
  `main.v_source_provenance`, and its dataset use restrictions agree with recorded licence evidence.
- **Implementation priority:** P0 evidence-gathering decision; no automatic data entry.

### AR-04 — as-of interfaces invite claims the retained vintages cannot support

- **Audit severity:** P0.
- **Verified status:** Confirmed limitation, partly mitigated; needs user decision.
- **Evidence:** every one of the 22 sources has exactly one retained vintage and all provenance rows use
  `inferred_upper_bound`. `canonical.series_revisions` is empty. `research.observations_as_of` remains
  available, but `docs/RESEARCH_DATABASE_GUIDE.md`, `config/acquisition_contracts.csv`, and the dataset
  catalogue explicitly prohibit historical as-of claims and describe the legacy timestamp as a
  conservative upper bound.
- **Root cause:** the schema can represent vintage history, while the legacy source population cannot.
- **Proposed remedy:** choose whether to retain the macro as a forward-looking interface with explicit
  limits or withdraw it until official timestamps and successive vintages exist.
- **Validation criterion:** either the supported-interface documentation and catalogue continue to mark
  the macro as non-real-time for legacy data, or the interface is removed through a reviewed compatibility
  change; any source advertised as revision-capable has at least two genuine vintages.
- **Implementation priority:** P0 product-policy decision; no automatic interface withdrawal.

### AR-05 — economic metadata and human review coverage are sparse

- **Audit severity:** P1.
- **Verified status:** Confirmed; needs economic review.
- **Evidence:** queries against `canonical.dim_series` reproduce 4,057 unresolved units, 13,102
  `stock_flow = not_reviewed`, 13,948 `nominal_real = not_reviewed`, 13,965 unreviewed seasonal
  adjustment states, 13,766 unreviewed transformations, 13,347 unreviewed valuations, and 7,874
  unresolved hierarchies. `canonical.series_review` and `config/series_review.csv` contain no review rows.
  `validate_research_eligibility_metadata()` in `scripts/04_validate.R` blocks unreviewed evidence from
  `marts.v_research_series`; automated assurance remains separately labelled.
- **Root cause:** economic review has not yet been completed; the code correctly refuses to manufacture it.
- **Proposed remedy:** work through `outputs/semantic_review_worklist.csv` and sign decisions through the
  governed review workflow, beginning with a user-selected release set.
- **Validation criterion:** each series selected for human-verified release has a complete signed register
  row and reviewed evidence for every transformation-critical field.
- **Implementation priority:** P1, needs user/economist decisions.

### AR-06 — generated and positional identities may not be stable across publications

- **Audit severity:** P1.
- **Verified status:** Partial; needs source review and possibly identifier migration.
- **Evidence:** `canonical.dim_series` contains 320 `positional` and 500 `positional_lane` identities,
  reproducing the report's 820 count. `validate_published_identities()` emits source-specific warnings and
  `write_identity_stability_worklist()` writes the evidence queue. The report's additional 1,729
  generated/source-value classification is based on its own diagnostic logic; its referenced CSV and
  Python program were not supplied. Labels containing generated tokens do appear in
  `config/proposals/worksheet_review.csv`, so the concern is credible but is not proof of wrong values or
  of one uniform parser defect.
- **Root cause:** some publishers omit a stable semantic discriminator; other parser paths retain generic
  header tokens to avoid collapsing source rows.
- **Proposed remedy:** review source coordinates by source, repair only demonstrated header-path defects,
  and use the existing migration machinery for every changed published identifier. Retain positional lanes
  where the publisher supplies no semantic identifier.
- **Validation criterion:** each changed identifier has source evidence, source-cell accounting, and
  one-to-one migration coverage; unresolved identities remain visibly provisional.
- **Implementation priority:** P1, needs source/economic decisions. No blanket parser rewrite.

### AR-07 — short scalar series and regular gaps require disposition

- **Audit severity:** P1.
- **Verified status:** Partial; needs source review.
- **Evidence:** `marts.v_catalogue_scalar_series` has 7,229 rows, including 25 with at most two
  observations. The audit narrows these to seven after applying its unsupported worklist classification.
  The active project gate records 499 regular-frequency series and 24,149 missing periods, while the
  report's independent convention finds 465. `run_quality_screens()` in `scripts/11_marts.R` generates
  row-level `outputs/gap_worklist.csv`, capped at 2,000 rows, and expected missingness records classify
  20,647 absences.
- **Root cause:** several phenomena are mixed: legitimate entry/exit, event or cross-sectional grains,
  source blanks, date-normalisation conventions, and possible parser omissions.
- **Proposed remedy:** reconcile the reviewer worklists against raw coordinates and expected grids. Do not
  delete or fill observations solely because a series is short or irregular.
- **Validation criterion:** reviewed series have a source-backed gap/short-series disposition and the
  internal and independent screens reconcile under one documented universe and period convention.
- **Implementation priority:** P1, needs source/economic decisions.

### AR-08 — 6,522 numeric cells are outside reviewed parser regions

- **Audit severity:** P1.
- **Verified status:** Confirmed review debt; existing containment is appropriate.
- **Evidence:** `main.v_source_region_unreviewed` contains 6,522 rows and
  `outputs/source_region_review_worklist.csv` contains those rows plus a header.
  `validate_source_region_completeness()` reports them. `unreconciled_table_families()` in
  `scripts/08_reconciliation.R` prevents any affected worksheet from being promoted to `validated`.
  `docs/DATA_MODEL.md` explicitly distinguishes in-region balance from out-of-region review.
- **Root cause:** out-of-region source content has not yet received source-backed classifications.
- **Proposed remedy:** review the coordinate queue and add precise rules or extend a parser only where the
  source establishes that the cells are observations. Retain `unreviewed` otherwise.
- **Validation criterion:** zero `unreviewed` or `data_not_ingested` cells for each worksheet promoted to
  validated; all accepted/rejected/excluded cells reconcile.
- **Implementation priority:** P1, needs source classification decisions; no automatic reclassification.

### AR-09 — hierarchy and domain coverage are incomplete

- **Audit severity:** P1.
- **Verified status:** Confirmed; needs economic review.
- **Evidence:** 7,874 series have `hierarchy_status = unresolved`, and `main.v_series_domain` contains a
  non-null controlled domain for 3,814 series. `documented_hierarchy_unresolved` warnings tell users not
  to aggregate blindly; validated marts require governed table and series review.
- **Root cause:** publisher tables mix aggregates and components, while most hierarchy/domain mappings
  have not been reviewed.
- **Proposed remedy:** populate hierarchy and domain mappings only from published structure or a signed
  economic review.
- **Validation criterion:** released aggregate/component relationships are acyclic, source-evidenced, and
  tested; every released series has one controlled domain.
- **Implementation priority:** P1, needs economic decisions.

### AR-10 — continuity, concordance, methodology, and canonical registers are empty

- **Audit severity:** P1.
- **Verified status:** Confirmed state, unsupported as a defect by itself.
- **Evidence:** counts are zero in `canonical.methodology_regime`, `canonical.continuity_map`,
  `canonical.classification_concordance`, `canonical.canonical_series`, and
  `canonical.map_canonical_series`. `docs/CONCEPT_GOVERNANCE.md` says this is deliberate until reviewed
  evidence exists. The database does not automatically splice or substitute these series.
- **Root cause:** no authorized economic decisions have been signed into the registers.
- **Proposed remedy:** populate only when a user-selected research release requires the relationship and
  official evidence establishes it.
- **Validation criterion:** every nonempty relationship has reviewer, evidence, effective dates where
  applicable, and passes overlap/equality/continuity guards.
- **Implementation priority:** no automatic action; future P1 economic review.

### AR-11 — other bank/finance panels may have currency-collapsed analytical keys

- **Audit severity:** P1.
- **Verified status:** Partial; no current research-view defect beyond AR-01.
- **Evidence:** the documented bank/finance views preserve `codigo_moneda`, `currency_of_origin`, and
  `unit_currency`. Only EEFF is exposed through `research.entity_panel`; the other panels remain source
  views and their publisher rows are retained. `docs/DATA_MODEL.md` declares each panel's natural grain
  with the source currency category. Null measures in other products are source states, not authorization
  to drop rows.
- **Root cause:** a common research-panel product has not been designed for these distinct grains.
- **Proposed remedy:** if those panels are later published, design each native key and missing-value status
  explicitly and apply the same row-conservation rule as AR-01.
- **Validation criterion:** source-to-research accounting, key uniqueness, complete dimension mapping, and
  explicit null reasons for every newly published panel.
- **Implementation priority:** no current action; future P1 feature requiring compatibility review.

### AR-12 — no persisted foreign keys

- **Audit severity:** P1.
- **Verified status:** Obsolete as a requested protection.
- **Evidence:** `duckdb_constraints()` has no foreign keys, but
  `validate_referential_integrity()` in `scripts/04_validate.R` performs release-blocking anti-joins for
  ten dimension/fact relationships. `validate_observation_store()` separately checks natural and surrogate
  series/vintage references and primary fact keys. The code explains why DELETE-and-append source updates
  make persisted foreign keys incompatible with normal assembly before the release-wide transaction is
  complete. Existing tests include deliberate orphan fixtures.
- **Root cause:** deliberate enforcement timing, not an absent integrity policy.
- **Proposed remedy:** retain end-of-build release-blocking checks; add a relationship only if a future
  table is not already covered.
- **Validation criterion:** zero orphan counts in the isolated candidate and a deliberate orphan fixture
  blocks release.
- **Implementation priority:** no action.

### AR-13 — uncontrolled index-base text and empty naming/measure fields

- **Audit severity:** P2.
- **Verified status:** Partial; needs semantic review.
- **Evidence:** contrary to the report, `canonical.dim_series` already has both `canonical_name` and
  `measure_type`; both are null for all 13,985 rows. `index_base` remains publisher text, while
  `price_base_year` has a controlled reviewed role. `canonical_name` is populated in the research layer
  only through reviewed or certified canonical proposals.
- **Root cause:** the schema exists, but no evidence-backed population rule has been accepted; publisher
  display labels are intentionally preserved.
- **Proposed remedy:** keep exact publisher labels and add controlled codes or canonical names only through
  reviewed mappings. Do not normalize display text in place.
- **Validation criterion:** controlled values pass vocabulary tests and retain exact source labels and
  evidence; no new canonical equivalence is inferred from text alone.
- **Implementation priority:** P2, needs economic decisions.

### AR-14 — researchers may confuse raw periods, projections, and actuals

- **Audit severity:** P2.
- **Verified status:** Obsolete.
- **Evidence:** `docs/TEMPORAL_CONTRACT.md`, `docs/RESEARCH_DATABASE_GUIDE.md`, and
  `docs/DATA_MODEL.md` document `source_period_date`, `reference_period_start/end`, actual versus
  statement views, and projections. `research.observations_latest_actual` excludes non-observed statement
  values; `research.observations_latest_statement` includes and labels them. The active gate reports 343
  statement projections but does not expose them as actuals.
- **Root cause:** the report correctly identifies a user risk but overlooks the current schema-39/41
  interface and documentation.
- **Proposed remedy:** none beyond keeping documentation and executable contracts synchronized.
- **Validation criterion:** representative actual queries exclude projections and normalized monthly joins
  use `reference_period_start`.
- **Implementation priority:** no action.

### AR-15 — discontinuity flags lack reviewed dispositions

- **Audit severity:** P2.
- **Verified status:** Confirmed review debt.
- **Evidence:** the active screen reports 38,433 observations in 2,611 series.
  `run_quality_screens()` writes `outputs/discontinuity_worklist.csv` with row-level evidence, capped at
  2,000 rows; no signed disposition register is populated. The code and report both state that the screen
  is not proof of error.
- **Root cause:** the statistical screen has run, but economic and methodology review has not.
- **Proposed remedy:** record evidence-backed dispositions for series selected for release; do not correct
  values from magnitude alone.
- **Validation criterion:** every flagged observation in a released series has a review disposition or a
  cited methodology regime.
- **Implementation priority:** P2, needs economic decisions.

### AR-16 — independent reproducibility was not proven by the audit attachment

- **Audit severity:** material weakness, no explicit P-level.
- **Verified status:** Unsupported as a project defect; to be tested in Phase 4.
- **Evidence:** the repository includes the source workbooks, `renv.lock`, the authoritative loader,
  isolated candidate workflow, full real-workbook smoke test, build identity, and source/config/code hashes.
  The audit did not have those materials, so its stated evidentiary limit describes the audit package.
- **Root cause:** attachment scope.
- **Proposed remedy:** run the focused tests, full regression suite, and an isolated database validation;
  record commands and actual results in the resolution report.
- **Validation criterion:** all required tests pass, the isolated database builds or its expected gate
  disposition is explained, and the published database SHA-256 remains unchanged.
- **Implementation priority:** P1 verification work.

## Automatic implementation scope

Only AR-01 qualifies for automatic implementation: it is confirmed P0, the correct key is established by
the publisher code and the project's existing semantic dimension, and the change restores rather than
reinterprets source rows. It will be implemented as schema 42 with a versioned certification rule, public
contract update, targeted regression tests, release-blocking target-release accounting, and researcher
documentation.

AR-02 through AR-11 and AR-13/AR-15 are deliberately not implemented without the required product,
source, or economic decisions. AR-12 and AR-14 require no code change because current executable controls
already meet the underlying requirement.
