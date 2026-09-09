# Economist review workflow

This workflow covers the first flagship and duplicate-resolution waves. It separates evidence
preparation from the decision that changes the research surface.

## Series review

1. Start with `outputs/flagship_review_queue.csv`, ordered by source priority and economic relevance.
2. Open the cited worksheet and inspect the first and last observations, extrema, apparent breaks,
   missing episodes, formula/hidden-row status, and a reproducible sample.
3. Fill the corresponding row in `config/series_review.csv` only when definition, timing, unit,
   scale, currency, stock/flow, nominal/real, seasonal adjustment, hierarchy, comparability, and
   availability are evidenced. Use the source cell or official URL as the evidence URI.
4. Sign with `Rscript sign_off_reviews.R --register=series_review ...` and rebuild. The resulting
   row is `human_verified`; the proposal file remains a draft.

High-impact judgments—splices, deflators, seasonal variants, sign conventions, and aggregate
identities—require a second economist review.

## Duplicate and canonical review

Use `outputs/duplicate_canonical_resolution_queue.csv`. For each candidate, choose exactly one
disposition: `replica`, `historical_segment`, `alternative_definition`, `methodology_break`,
`exact_duplicate`, or `not_duplicate`. Record the evidence and effective dates. A canonical mapping
must also state precedence and overlap policy. Similar values are evidence to inspect, not permission
to merge.

For panel collisions, decide whether rows are exact duplicates, measure splits, or evidence of a
missing dimension. Until that decision is recorded in `config/panel_resolution.csv`, the research
panel continues to expose only collision-free rows.

## Acceptance gates

A review wave is ready for publication only when all selected rows have complete evidence, no open
questions, reconciled source cells, unique declared keys, no unresolved units, and a named reviewer.
The release must remain reproducible from a clean Git commit and its baseline must be compared with
`docs/RELEASE_BASELINE_SCHEMA41.md`.
