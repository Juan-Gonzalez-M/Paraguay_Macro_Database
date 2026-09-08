# Acquisition runbook

How a publication enters this database, and what has to be recorded about it so that a future
researcher can ask what was knowable on a given date.

This is the procedure the audit's ER-04 asks for. It is the one item on that list whose cost grows
with delay: **every month that passes without retaining the publications is a month of real-time
history that cannot be recovered later.**

## What is irrecoverable, stated plainly

The database holds **one vintage per source** and **zero recorded revisions**. No acquisition record
survives from before 2026-08-24 for any of the 22 sources.

That history cannot be reconstructed. Where the publisher has replaced a file in place — which is the
normal practice for the BCP's statistical annexes — the earlier bytes are gone, and no procedure
adopted now can bring them back. This is documented as irrecoverable rather than marked resolved, as
the audit's acceptance criterion requires.

What follows is therefore about **forward** capability. It starts working the second time it is run.

## Availability, and how good the evidence is

`available_at` is the moment a researcher could first have had the figure. It decides what
`series_as_of_date(d)` may return, which is the whole of the point-in-time interface, so how it was
established is part of the answer and is recorded beside it in `availability_quality`:

| `availability_quality` | `available_at` is | Use it for |
| --- | --- | --- |
| `official_release` | the publisher's own release timestamp | real-time and revision research |
| `retrieval_time` | when an operator actually fetched the file | real-time research, conservatively |
| `inferred_upper_bound` | when the file entered the immutable archive | **not** a real-time claim |

All three are safe in the same direction. Retrieval and archive times are *later* than true
availability, so an as-of query sees less than a researcher really could have seen, never more. That
is the correct direction for a bound to be wrong in: it cannot manufacture look-ahead.

All 22 current vintages are `inferred_upper_bound`, dated 2026-08-24 from
`input_archive/archive_manifest.csv`. `outputs/source_provenance_worklist.csv` names, per vintage,
which fields are still missing and what each one costs.

Schema 40 makes the use restriction machine-readable as
`raw.source_provenance.snapshot_policy = 'legacy_current_snapshot_only'`. A genuinely new hash is
labelled `verified_current_snapshot` or `release_history` only after the acquisition register is
complete. This policy is independent of engineering rebuilds: running the same bytes through newer
code does not create a statistical vintage.

**`available_at` is never derived from the reference period.** The observations span 1945 to 2028;
inferring availability from the period a figure describes is precisely the look-ahead the column
exists to prevent, and no code path does it. `source_files.publication_date` — read from the filename
or the content — is a statement about which month the bulletin covers, not about when anyone could
read it, and it is only ever a fallback.

## The procedure

Run this on each publication cycle, per source.

### 1. Before downloading, record where you are

Open the publisher's own release page — not a bookmarked file URL. Note the page URL, the release
identifier or title as printed, and the release date or timestamp the publisher states.

### 2. Download, and hash immediately

```sh
shasum -a 256 "<downloaded file>"
```

If the hash matches a row already in `config/source_vintages.csv`, the publisher has re-posted
identical bytes. That is not a new vintage — but it *is* a new acquisition event, and it is evidence
that the figures were unchanged as of that date. Record the event; do not create a second vintage.

If the hash is new, this is a new vintage, even if the filename is identical. **The filename is the
one thing publishers change freely; the hash is what identifies the file.**

### 3. Record the acquisition before ingesting

Add a row to `config/source_vintages.csv`:

| Column | What to write |
| --- | --- |
| `source_id`, `sha256` | the join key; both required |
| `original_filename` | exactly as downloaded, accents and all |
| `official_release_date` | the date the publisher states. Leave blank if it states none |
| `official_url` | the release page, or the direct file URL if that is what the publisher offers |
| `release_identifier` | the publisher's own name for the issue |
| `retrieved_at` | ISO 8601 UTC, e.g. `2026-09-05T14:22:00Z` |
| `retrieval_method` | how: `manual_download`, `scheduled_fetch`, `archive_ingest_upper_bound` |
| `availability_quality` | one of the three values above |
| `license`, `evidence` | terms, and a sentence a stranger could check |

`available_at` is not a column you fill in. It is derived: the official release date when one is
recorded, otherwise the retrieval time. Recording both and letting the rule choose is what keeps the
quality flag honest.

### 4. Put the file in place and run the update

```sh
cp "<file>" input/current/<source_id>/
Rscript -e 'source("run_update.R")'
```

The run archives the file immutably under `input_archive/<source_id>/<sha256>.<ext>` before parsing
it, so the bytes are preserved whatever the parser then does with them. A build that ends blocked
leaves the published database untouched and keeps its candidate for inspection.

### 5. Read the revision report

A second vintage of a source is the first moment revision detection has anything to compare. After
the run:

```r
con <- open_macro_database()
series_revision_history(con)                       # every value that changed, with both vintages
DBI::dbGetQuery(con, "SELECT * FROM outputs")      # or read outputs/update_report.md
```

Expect revisions. A statistical office that never revises is a statistical office whose comparison is
broken — if a new vintage produces zero revision rows and zero new observations, check that the
parser actually read the new file rather than concluding the publisher changed nothing.

### 6. Check the as-of interface answers

```r
series_as_of(con, "<a date before the new release>", series_id = "<a revised series>")
series_as_of(con, "<a date after it>",               series_id = "<the same series>")
```

The first must return the old value and the second the new one. If both return the new value,
`available_at` is wrong or missing on the new vintage; stop and fix it before citing anything.

## Rules that must not be relaxed

1. **Immutable before replaceable.** The archive copy is written before parsing, and archived files
   are never edited or deleted. `prune_backups.R` retains database backups; it does not touch
   `input_archive/`, and raw source vintages are not substitutes for database backups.
2. **A changed file is a new vintage.** Never overwrite a vintage's row to "correct" it.
3. **Never backdate.** If the publisher's release date is unknown, the retrieval time is the answer
   and `availability_quality` says the evidence is weaker. Guessing earlier is inventing look-ahead.
4. **Partial acquisition fails closed.** If a scheduled fetch returns a truncated or empty file, it
   must not be ingested as a vintage. The archive integrity check re-hashes every retained vintage
   against its archived bytes on every run.
5. **Reconstructed history is labelled.** If an official archive later yields a genuine historical
   release, it may be imported — but only where its authenticity and release timing can be
   established, and it must be distinguishable from a vintage captured contemporaneously.

## Scheduling it

The procedure above is manual because the acquisition decisions — is this the same issue, does the
publisher state a date — are judgements. What can be scheduled is the reminder and the check:

- Monthly, on the publisher's usual release day, for the annex and bulletin sources.
- After each run, read `outputs/source_provenance_worklist.csv`. A source that reappears on it with
  `available_at` missing is one whose vintage cannot support a point-in-time claim.
- `outputs/build_manifest.json` records the database checksum a result was computed from. Freeze it
  with the result.
