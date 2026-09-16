# Schema 43 post-promotion series-quality package

Date: 2026-09-16

Scope: first post-promotion consolidation of all 13,985 active canonical series

Engineering verdict: **READY FOR BOUNDED REVIEW**

Publication decision: **candidate retained; not promoted**

## Outcome

The active Schema 43 population was censused without changing source facts, canonical identities,
research admission, or the production database. Every active series now receives exactly one
conservative public review category plus separate issue codes and layer-specific admission or
exclusion fields. The existing assurance ledger remains authoritative: the new usability category
does not certify economic meaning and cannot admit a series to `research.*`.

The isolated candidate is
`database/candidates/accepted_for_review_20260916_202652.duckdb`, SHA-256
`f0f9ddb6482b6921c8bbf0b1cf6cd442aefed8c24082b81c57c7799e806ec85b`, 425,209,856 bytes,
build `build:e52dcd9ea7cbf6658a0a6d5a`, source bundle
`release:dcbccb827b93ee2362ab3c56`, and attempt
`attempt:555657fc0085a6ad40cf1127`. Its internal decision is accepted with zero errors and 40
warnings. It was built from clean commit `81039e7` with `publish = FALSE`.

Production remains 423,374,848 bytes and SHA-256
`6079c80ce0edd26f899b9f54fe98f73eee08c90c5f006759b051960edbd7a9fa`.

## Census and classification

| Primary review category | Series | Current observations |
|---|---:|---:|
| `apparently_valid_preliminary` | 13,546 | 1,168,599 |
| `research_validated` | 32 | 7,498 |
| `discovery_only` | 0 | 0 |
| `clear_mechanical_defect` | 0 | 0 |
| `probable_identity_fragmentation` | 324 | 39,717 |
| `probable_duplicate_or_overlap` | 60 | 10,900 |
| `semantic_review_required` | 0 | 0 |
| `provenance_review_required` | 0 | 0 |
| `insufficient_evidence` | 23 | 25 |
| **Total** | **13,985** | **1,227,082** |

The zero primary counts are deliberate. Semantic and provenance incompleteness are secondary issue
flags for most candidates, not reasons to obscure a stronger primary disposition. All 13,985 have
incomplete or non-publisher-verified provenance status, and 13,953 have no formal economic-semantic
verification. The 32 research rows are existing `rule_certified` admissions, explicitly labelled
`rule_certified_not_human_verified`; no new series was admitted to research.

Layer results are 13,985 discoverable catalogue profiles; 6,881 scalar and 6,757 native-grain
candidates eligible in `explore.*`; 347 withheld; and 32 existing research admissions. There are no
empty series, all-null series, malformed-period series, non-finite-value series, duplicate logical
keys, or conflicting logical keys.

## Principal review populations

1. **LRM auctions:** 3,083 event identities and 10,351 observations, all with at most twelve
   observations. Repeated labels span annual worksheets, and offered-rate versus assigned-rate
   columns can share the public label `Promedio`. These are native-grain preliminary records plus a
   high-priority representation/continuity review, not proven garbage and not automatically merged.
2. **Annex versus dedicated FX source:** all thirty `economic_annex:cuadro_20` populations have an
   exact varying date/value counterpart among the thirty `fx_operations` series. The sixty members
   are `probable_duplicate_or_overlap`; conceptual equivalence, vintage relationship, precedence,
   and canonical membership require a governed decision.
3. **Exact population matches:** 587 groups contain 2,425 member series and 427,847 pairwise
   matches. Constant populations account for 427,131 pairs; only 716 pairs vary. Equal values are
   therefore never treated as a deletion rule. Insurance-annex zero histories dominate this screen.
4. **Short native-grain records:** interbank-market, exchange-house, liquidity-facility, and LRM
   records explain most of the 3,372 series with at most two observations and 5,428 with at most
   twelve. Representative raw evidence shows events, institutions, ratios, or other declared native
   dimensions rather than headers parsed as facts.
5. **Metadata and lineage:** 4,057 series have unresolved source units; 1,345 have coordinate-level
   lineage limitations (1,287 corporate-bond curve nodes, 30 FX-operation series, 16 EVE series,
   and 12 ICC series); 488 have gap indicators. These are visible qualifications, not defects.
6. **Constant and unusual values:** 4,083 series are constant and 819 contain negative values.
   Neither condition is classified as a defect without economic or source evidence.

## Mechanical defects and corrections

No mechanically proven defect was found in the active canonical population. Consequently no parser,
fact, identity, label, unit, or public row was deleted, merged, relabelled, or transformed. The
header-only `unambiguous_corrections.csv` records this explicitly. The LRM public-label ambiguity is
a real representation issue, but deciding the correct long-run identity and economic label requires
source-specific parser work and review; it is not safe to rewrite in this consolidation stage.

## Layer and assurance contract

`catalog.series` now exposes:

- `primary_review_category`, rule ID/version/basis, and independent issue codes;
- catalog, explore, and research admission statuses and exclusion reasons;
- semantic-review, provenance-review, parser/reconciliation, and current-observation status; and
- the bounded supported-overlap member IDs/count for the Annex/FX population.

These fields propagate onto exploratory observation rows. Existing `validation_tier`, warnings,
`canonical.certification_decisions`, `canonical.rule_certified_series`, and
`canonical.series_review` remain unchanged and authoritative. The platform validator fails a build
for missing/unknown categories or inconsistent research admission. `catalog.*` remains discovery,
`explore.*` remains mechanically controlled and provisional, and `research.*` still requires the
pre-existing formal contract.

## Candidate reconciliation and verification

Bidirectional `EXCEPT ALL` comparisons returned zero differences for `canonical.dim_series` and
`canonical.fact_series_events`; per-source series/observation counts also matched. The candidate has
13,985 canonical series and 1,227,082 nondeleted facts, exactly matching production. All 17
catalog/explore/research views bind from a fresh default read-only connection. The complete
regression suite passed; its sole warning is the intentional corrupt-ZIP failure-isolation fixture.

CDA and TCN retain their exact governed deferrals: both remain present once in `catalog.datasets`,
with zero candidate series, zero current observations, null current vintage, and no canonical,
exploratory, or research observations. Their parsers, archives, and release-scope decisions were not
changed.

## Machine-readable contents

- `series_classification.csv`: complete one-row-per-series census and classification, including
  distribution statistics, period diagnostics, constant/near-constant indicators, layer exposure,
  lineage, semantics, provenance, and exact-population group size.
- `counts_by_dimension.csv`: counts by source, dataset, frequency, unit, category, validation tier,
  and layer admission.
- `suspicious_population_register.csv`: grouped source-level review indicators.
- `exact_duplicate_overlap_diagnostics.csv`: exact date/value population groups and member rows,
  with constant versus varying populations and supported-overlap disposition.
- `short_series_diagnostics.csv` and `fragmented_identity_diagnostics.csv`: filterable worklists.
- `decision_register.csv`: prioritized unresolved economic, identity, provenance, CDA, and TCN work.
- `unambiguous_corrections.csv`: the empty correction register with its full schema.
- `population_reconciliation.csv`, `candidate_identity.csv`, and `tests_and_commands.csv`: build and
  verification evidence.

## Prioritized roadmap

1. Decide Annex/FX equivalence and precedence, then use canonical membership rather than deleting a
   carrier.
2. Perform source-specific LRM parser/identity work, preserving event evidence and distinguishing
   offered from assigned measures before any continuity proposal.
3. Review the insurance-annex constant-match population and corporate-bond coordinate lineage.
4. Resolve units selectively by economic priority, then conduct formal series review for a bounded
   subset instead of bulk-promoting preliminary data.
5. Onboard CDA separately for provisional exploration with explicit incomplete acquisition metadata
   and no research exposure.
6. Review TCN source chain and annual-sheet identity fragmentation before a separate provisional
   onboarding candidate.

Final engineering verdict: **READY FOR BOUNDED REVIEW**.
