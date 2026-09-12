# The temporal contract

What a period means in this database, per frequency, and which column you may join on.

This document exists because of a defect that produced no error message. Joining the consumer price
index to the exchange rate through the documented read path returned **zero rows** — not a warning,
not a partial sample, an empty estimation sample — because the two sources date monthly observations
to different days of the month. The consolidated audit at
[`PROJECT_HANDOVER.md`](../PROJECT_HANDOVER.md) records the defect and its remediation.

## The three columns

Every published observation carries three dates. They answer different questions and only one of
them is a join key.

| Column | What it is | Join on it? |
| --- | --- | --- |
| `period` | **The date the publisher printed.** Part of the observation key; it is what the workbook said and it is never rewritten. | **No.** |
| `period_start` | The first day of the interval the observation covers. | **Yes** — this is the canonical key. |
| `period_end` | The last day of that interval. | Yes, if you prefer end-dating. Be consistent. |

`period` is retained rather than corrected on purpose. It is half of the natural key
`(series_id, period)` that every identifier in the catalogue is built on, and it is the evidence of
what the source actually published. Normalising it in place would retire 13,985 series identifiers
to fix a problem that a second column solves.

## Why `period` is not a join key

Measured on the schema-38 database, across monthly scalar series:

| Dating convention | Series | Observations |
| --- | ---: | ---: |
| Last day of the month | 2,057 | 260,804 |
| First day of the month | 1,757 | 580,732 |
| Neither | 14 | 103 |

And **164 monthly series use more than one convention inside their own history** — 150 with two, 14
with three. They include core monetary aggregates: `M2 — Billetes y monedas en circulación`,
`Activos Internos Netos (AIN) — Total`, `Crédito y depósito del sector público`.

Two consequences, both silent:

- **Across series**, an exact-date join finds no matches at all. The price index is dated day 1 and
  the exchange rate to month end, so they share 378 months and zero dates.
- **Within a series**, a time index that alternates between the first and the last day of the month
  is not a regular index. `lag()`, `diff()` and every seasonal routine in every time-series package
  will accept it and return the wrong answer.

`period_start` and `period_end` are immune to both: they describe the same month whichever day the
publisher printed.

## The interval, per frequency

`period_start` and `period_end` are derived from the series' declared frequency, except where the
publisher stated an irregular interval and the parser stored it (`canonical.series_period_bounds` —
CUADRO 11 publishes 83 of these). A stored bound always wins.

| Frequency | `period_start` | `period_end` |
| --- | --- | --- |
| `annual` | 1 January | 31 December |
| `semiannual` | 1 January or 1 July | 30 June or 31 December |
| `quarterly` | first day of the quarter | last day of the quarter |
| `monthly`, `monthly_survey` | first day of the month | last day of the month |
| `daily`, `irregular_daily` | the parsed date | the parsed date |
| anything else | the parsed date | the parsed date |

A frequency the contract does not name falls through to the parsed date on both bounds. That is a
one-day interval, and it is deliberately honest rather than a guess: no daily interpretation is
manufactured for a lower-frequency observation.

The rule is written once, in `series_period_bounds_sql()` (`scripts/01_utils.R`), and both current-
value carriers and the observations carrier use it. Two copies of an interval rule are two answers
waiting to disagree.

## Where the columns are

Since schema 39, on every published observation interface:

- `main.v_series_research` — the research extraction interface
- `main.v_series_latest` and `main.v_publisher_statement_latest`
- `main.v_series_observations` (and its `_all` and `_history` twins)
- `main.series_as_of_date(d)` and `main.series_statement_as_of_date(d)`

Before schema 39 the bounds existed only on `v_series_observations`, while `README.md` and
`scripts/05_query_helpers.R` sent researchers to `v_series_latest`, which did not carry them. The
normalisation was there; nobody was pointed at it.

## Using it

```r
source("scripts/05_query_helpers.R")
con <- open_macro_database()

# One column per series, one row per month, on the canonical key.
sample <- series_wide(
  con,
  c("economic_annex:cuadro_60b:293a83a82f814b7fc49afadc",   # IPC, index
    "exchange_rates:usd_prom:190c4a9509f6c233bdc28928"),    # PYG/USD, monthly average
  key = "period_start"
)
```

`series_wide()` has no default `key`. That is not an oversight: choosing the key is the decision that
went wrong, and a helper that picked one for you would be making it silently. Passing
`key = "period"` is a hard error that explains why.

The same function refuses to combine frequencies without an explicit alignment rule, and refuses to
pivot a series that has two observations in one normalised period. Both are cases where a value would
otherwise be chosen for you.

## What the release enforces

`validate_temporal_contract()` (`scripts/04_validate.R`) runs on every build:

| Check | Severity |
| --- | --- |
| `period_start <= period <= period_end`, both bounds present | **error** |
| `(series_id, period_start)` unique | **error** |
| A research-eligible series changes convention inside its own history | **error** |
| Any other series changes convention inside its own history | warning + worklist |

The first two are errors because they already held for all 1.2 million observations before the
contract was written down, so a violation is a genuine regression rather than a backlog.

The convention check cannot block today and is not meant to. The 164 mixed series are a real and
unresolved property of the sources; the bounds are what make them harmless to join; and blocking the
release over them would stop the database being published in order to protest about the database.
They are ranked in `outputs/temporal_convention_worklist.csv` by what a wrong lag would cost, and the
check becomes an error for exactly the series a reviewer has admitted to the research surface — which
is where a wrong lag would actually reach an estimate.

## What is still open

Knowing that a series changes convention is not knowing why. The audit's ER-02.2 asks for each of the
164 to be separated into a source-layout change and a genuine change of observation timing — a series
that moved from a period average to an end-of-period reading changed what it measures, and that is a
methodology regime (`config/methodology_regimes.csv`), not a date to normalise. That review has not
been done. Until it is, the normalised bounds make these series safe to *join*; they do not make them
safe to assume comparable across the break.
