# Why the database file grows on every run

The short version: **the file records the largest it has ever needed to be, not how much data it currently holds.** Nothing is leaking and nothing is corrupt. This note explains the mechanism, because the behaviour is surprising the first time you see a 230 MiB database become 555 MiB while the data inside it gets *smaller*.

## 1. The file is a set of fixed-size blocks

DuckDB keeps the whole database in one file, divided into fixed-size blocks — 256 KiB each here. Every table's data lives in some set of those blocks, and the file also carries a small directory saying which blocks are in use and which are free.

You can see the split at any time:

```r
con <- DBI::dbConnect(duckdb::duckdb(), "database/paraguay_macro_pilot.duckdb", read_only = TRUE)
DBI::dbGetQuery(con, "SELECT * FROM pragma_database_size()")
```

which reports `used_blocks`, `free_blocks` and `total_blocks`. The file on disk is `total_blocks × block_size`. That is the number that matters for Git LFS and for your disk — and it is *not* the same as the amount of live data.

## 2. DuckDB never edits a block in place

This is the part that explains everything else.

When a run changes a table, DuckDB does **not** open the existing blocks and overwrite them. It writes the new version into **new** blocks, and only once that has succeeded does it mark the old blocks as free.

That ordering is deliberate: it is what makes the database crash-safe. If the machine dies halfway through a run, the old blocks are still intact and untouched, so the database simply reopens at its previous state. You cannot get that guarantee if you overwrite data in place.

But it has a direct consequence. For the moment between "new blocks written" and "old blocks released", **both copies exist in the file at once**:

```
before   [ old data 100 MiB ][ free 5 MiB ]                      file = 105 MiB
during   [ old data 100 MiB ][ new data 100 MiB ]                file = 200 MiB   <- must grow
after    [ free     100 MiB ][ new data 100 MiB ]                file = 200 MiB   <- stays
```

The file had to grow to 200 MiB to hold both. Afterwards only 100 MiB is live — but the file is still 200 MiB.

## 3. Freed space is reused, but never given back

Those 100 MiB of freed blocks are not wasted forever. They go on a free list inside the file, and the *next* run will write into them before extending the file again. This is why the growth is a ratchet rather than a runaway: it climbs to a plateau and mostly stays there.

What DuckDB does not do is shrink the file. There is no automatic step that walks the free list, moves live blocks down, and truncates the file back to the operating system. So the file permanently reflects the worst moment it ever had.

## 4. Why *this* pipeline rewrites so much

Two patterns in this project make step 2 happen often.

**Every run rewrites the governance tables.** `apply_table_status()`, `apply_table_domains()`, `apply_table_reconciliation()`, `apply_series_semantics()`, `apply_series_grain()` and `rebuild_prior_release_aliases()` all follow the same shape: delete every row, then write the current set back. That is the right design — it makes the configuration files the single source of truth, so a row deleted from a CSV disappears from the database — but it means those tables are rewritten in full on every run, even when nothing changed.

These tables are small, which is why a routine run is cheap. Measured on this database: **a non-migrating run costs about 9 MiB.**

**A migrating release rewrites the big curated tables.** When a schema step changes how `series_id` is built, the affected sources are invalidated and re-ingested from the raw layer. For `economic_annex` that means rewriting:

| Table | Rows rewritten |
|---|---|
| `documented_series_snapshot` | 651,660 |
| `report_cell_values` | 700,262 |
| `fact_series_events` | 651,660 |

Two million rows, written into new blocks while the old ones are still held. **A migrating release therefore costs 100 MiB or more**, and it costs it every time, because each run must fit both copies.

## 5. What made this particular session unusual

The schema-13 and schema-14 work took the file from 230 MiB to 555 MiB. That was not one release behaving badly; it was about ten full pipeline runs in a few hours, several of them migrating, because each fix was verified by running the pipeline and re-measuring. On top of that, adding the primary key to `fact_series_events` required rebuilding that table once — writing a second copy of 1.2 million rows before dropping the first.

Each of those runs pushed the high-water mark up a little further, and none of them ever pushed it back down. The end state was 330 MiB of live data sitting in a 555 MiB file, with 224 MiB of free blocks that no future run was going to need all at once.

Your normal cadence — one update when the BCP publishes — will not do this. It is a development-session artefact, not a property of the design.

## 6. Note that the data itself did not grow

Worth separating, because it is easy to read a growing file as growing data. Measured by compacting a copy and stripping components one at a time:

| Component | Size |
|---|---|
| Base data (all observations, cells, panels) | 186.0 MiB |
| Primary-key index on `fact_series_events` | 114.3 MiB |
| `series_id_migration` + `source_alias` | 10.3 MiB |
| **Live content** | **300.3 MiB** |
| Free blocks | 254.5 MiB |
| **File on disk** | **554.8 MiB** |

That primary-key index is why schema 20 moved the fact grain onto BIGINT surrogate keys. The
key was `(series_id, period, vintage_id)` — two long text columns and a date — and DuckDB
stores the key material in the radix tree, so the index cost more than the table it indexed.
`(series_sk, period, vintage_sk)` is three fixed-width values. The human identifiers stay on
every fact row, so nothing that queries the database changed; what changed is that the
compacted file is **243.3 MiB rather than 309.7 MiB, with 4,338 more observations in it.**

The base data was 190.2 MiB before this work and is 186.0 MiB after — slightly *smaller*, as it should be after removing 7,821 spurious series. The genuine additions are the identity-migration map (cheap) and the primary-key index (expensive: DuckDB implements a primary key as a radix tree that stores the key material, and this key is two long text columns plus a date, so it costs about 99 bytes per row — more than the table it indexes).

## 6a. Where the objects live, and why the layer is part of the storage story

Eighty tables sit in `raw`, `staging`, `canonical` and `audit`; `marts` and `main` hold views only.
The split is documented in [OPERATIONS.md](OPERATIONS.md#where-things-live) — what matters here is
that moving a table between schemas is not free and not neutral.

DuckDB has no `ALTER TABLE ... SET SCHEMA`, so each table was recreated in its layer from its
declared DDL and refilled by name. That is what preserved the primary keys, the NOT NULLs and the
two CHECK constraints; a `CREATE TABLE AS SELECT` would have moved the rows and dropped every
constraint on them. It is also a full rewrite of every table, which is why the schema-21 release is
one of the high-water marks in the table above.

The move had a second cost that took two releases to surface, and it is worth recording because it
is a storage decision that changed behaviour far from storage. **An object that moved is no longer
found by a name that does not say where it lives.** That broke two things:

- every stored view and macro, which bound its tables by bare name and resolved them only against
  the search path the pipeline sets on its own connections — 74 of 74 views failed from anyone
  else's connection until schema 22 rewrote them qualified;
- `initialize_database()`'s own bootstrap detection, which asked `dbExistsTable("schema_version")`
  on a connection that had not yet set a path, concluded the database was empty, and silently
  skipped every migration step that re-ingests a source. A parser repair would have reported
  success while re-reading nothing.

Both are fixed, and both are now checked rather than assumed: the stored SQL is linted and executed
from an unconfigured connection before a release is accepted, and the bootstrap detection reads
`information_schema` across every layer instead of relying on session state.

## 7. What compaction does

`Rscript compact_database.R` copies every object into a brand-new file. Because that file starts empty, only live data is ever written to it, and the free list starts at zero. The result is the same database occupying the space its contents actually need.

It is safe by construction:

- it backs up to `database/backups/` first;
- it compacts *out of the backup*, so the live database is never opened for writing;
- it compares the **contents**, not the row counts: every table as a multiset in both directions with `EXCEPT ALL`, which is insensitive to the row order a copy does not preserve and sensitive to a changed value, a duplicated row, a dropped row or a value under the wrong column;
- alongside that it compares column definitions and defaults, view SQL, constraints, indexes, sequences, macros and the schema version;
- it flushes the candidate to disk before the atomic rename, and swaps only if everything matched — otherwise it deletes the candidate and leaves the live database untouched.

Row counts alone were the earlier test and they are not enough: a defect that moves a value
between two rows of the same table, swaps two columns or drops a column default passes a row
count untouched.

Comparing contents is not enough either, and schema 21 is the proof. Every one of its 74 broken
views was copied, compared and compacted faithfully — the stored SQL matched on both sides,
because the stored SQL was identical and identically wrong. Comparison can only tell you the
candidate says the same thing as the original; it cannot tell you the original worked. So before
the swap, the candidate is now **opened on its own connection with nothing configured and every
view and macro is executed**. A candidate whose published objects do not run is deleted, and the
live database is left alone.

On this database it reclaimed 253.8 MiB — 46% of the file — with 76 tables, 4,733,363 rows, 61 views and 99 constraints verified identical.

## 8. When to run it

- After any migrating release (a schema step that re-ingests sources).
- After a burst of repeated runs, as in a development session.
- Before committing the database, since it is tracked through Git LFS and every commit stores the whole file.

Not needed after an ordinary monthly update; 9 MiB is not worth a compaction cycle.

## 9. How to check whether it is worth doing

```r
con <- DBI::dbConnect(duckdb::duckdb(), "database/paraguay_macro_pilot.duckdb", read_only = TRUE)
DBI::dbGetQuery(con, "
  SELECT round(used_blocks * block_size / 1048576.0, 1) AS used_mib,
         round(free_blocks * block_size / 1048576.0, 1) AS free_mib,
         round(100.0 * free_blocks / total_blocks, 0)   AS pct_free
  FROM pragma_database_size()")
```

If `pct_free` is above roughly 20%, compaction will pay for itself. Immediately after a compaction it should be near zero.
