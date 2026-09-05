# Drafted reviews, awaiting signature

Files here are **proposals**. Nothing in the pipeline reads them, nothing in them admits a series to
any research mart, and a value written here has no effect on the database.

They exist because preparing evidence and deciding on it are two different acts, and the readiness
audit requires both. Its governing principle 4 asks that every decision carry a reviewer, a date, a
citation and a rationale; its principle 3 forbids filling a field with a guess in order to make a
gate pass. A draft with a reviewer's name already on it is not a draft. A draft with nobody's name on
it cannot enter a register that requires one. So:

| | drafted in | promoted to |
| --- | --- | --- |
| Series economic review | `config/proposals/series_review.csv` | `config/series_review.csv` |
| Worksheet promotion | `config/proposals/table_status.csv` | `config/table_status.csv` |
| Cross-source concepts | `config/proposals/canonical_series.csv` | `config/canonical_series.csv` |
| Concept membership | `config/proposals/canonical_series_members.csv` | `config/canonical_series_members.csv` |
| Methodology regimes | `config/proposals/methodology_regimes.csv` | `config/methodology_regimes.csv` |

A proposal has every column of its target register **except** `reviewed_by` and `reviewed_at` — those
are the signature, and this script is the only thing that writes them — plus six annotations that
stay behind when the row is promoted:

| Column | What it holds |
| --- | --- |
| `evidence` | the sentence the value rests on: a published title, a footnote, an arithmetic check |
| `source_cell` | where to look: `source_id/sheet!cell`, or the workbook SHA-256 |
| `proposed_by` | who or what drafted it |
| `proposed_at` | when |
| `confidence` | `high`, `medium` or `low` |
| `open_questions` | what the evidence did **not** settle |

## Signing

```sh
# Read everything first. Writes nothing.
Rscript sign_off_reviews.R

# Sign what you have read.
Rscript sign_off_reviews.R --register=series_review \
    --series=economic_annex:cuadro_60b:293a83a82f814b7fc49afadc \
    --reviewer="Your Name"

# Or all of one register, once you have read all of it.
Rscript sign_off_reviews.R --register=series_review --all --reviewer="Your Name"
```

A proposal with `confidence = low`, or with anything in `open_questions`, is **skipped and reported**
rather than signed. An open question is a reason not to sign; `--force` overrides it deliberately and
nothing overrides it by accident.

Signing writes the row, stamps you and the date, and re-validates the whole register before the file
is written — `series_review_problems()` for the review register, key and completeness checks for the
rest. If the result would not be valid, nothing is written at all.

Then rebuild:

```sh
Rscript -e 'source("run_update.R")'
```

`marts.v_research_series` becomes non-empty only after that run, and only for the series you signed.

## What signing means

That you have read the source, not that the proposal looked reasonable. The audit's ER-03.3 asks for
each series to be compared against the workbook at the beginning, the end, the extrema, the apparent
breaks, the missing episodes and a reproducible random sample, and for formula-derived and hidden-row
cells to be reviewed explicitly. A proposal can gather that evidence and put it in front of you. It
cannot do the reading.

High-impact judgements — splices, deflators, seasonal variants, unit corrections, sign conventions
and total/component classifications — need a second reviewer under ER-03.5. The register records one
name. Record the second in the proposal file before signing.
