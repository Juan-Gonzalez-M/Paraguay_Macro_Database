# Changelog

## v41

Research-usability implementation following the final DuckDB re-audit. Changes no source
observation.

- Added an append-only assurance ledger and versioned deterministic rules. Automated decisions use
  `rule_certified`; human signatures remain exclusively `human_verified` and are never fabricated.
- Certified 32 high-confidence, no-open-question scalar proposals only when semantic identity,
  complete transformation metadata, unique published context, and worksheet reconciliation all
  pass. Unsafe canonical merges remain source identities.
- Replaced the empty research surface with exactly nine grain-aware views plus an as-of table macro.
  Curves and transactions retain their native grains; entity-panel collisions are excluded.
- Added a source-complete dataset catalogue and explicit forward-acquisition contracts for all 22
  sources, including rights and point-in-time limitations.
- Preserved all unresolved material as provisional or excluded rather than inventing definitions,
  units, historical vintages, or methodological splices.
- Consolidated entry-point dependency order in `scripts/load_project.R`, removed the unreachable
  schema-40 research-view builder, renamed the active platform regression suite for schema 41, and
  repaired current documentation links to the consolidated audit and review workflow. Repository
  tests now enforce those contracts. Fixture regeneration requires an explicit historical baseline,
  and unattended launchers use vanilla R sessions. These are codebase-maintenance changes and do
  not alter the published database or research SQL contract.

## v40

Canonical-platform remediation from `Paraguay_Macro_Database_Audit.md`. Changes no source
observation.

- Added a compact nine-view `research` schema. Canonical observations require reviewed source
  semantics, a validated source table, a reviewed canonical definition, effective membership, and
  deterministic precedence. Actuals and publisher projections remain separate.
- Canonical membership now records relationship, effective dates, precedence, and overlap policy;
  source metadata retain the publisher label and full hierarchy path separately from a reviewed
  canonical name. Replicas are equality-tested against their primary and ambiguous overlaps block.
- Every source declares a governed missingness contract: regular calendar, structural event
  absence, conditional panel, or observed-only. Expected-grid generation is restricted to regular
  sources instead of silently applying a scalar calendar to events and panels.
- Quality flags can identify release, vintage, source, table, series, or observation scope and carry
  lifecycle/test-version fields. Research exports expose only flags from the active release.
- Legacy vintages are explicitly labelled `legacy_current_snapshot_only`. New vintages fail the
  provenance gate unless acquisition metadata are complete; inferred legacy availability is never
  promoted into a real-time research claim.
- Added governed panel-collision dispositions and a fail-closed curated bank-panel surface. No
  unresolved panel is aggregated, and no unsigned economic proposal was promoted automatically.

## v39

Empirical-readiness remediation, `revisiones/EMPIRICAL_READINESS_2026-09-03.md`, items ER-01, ER-02,
ER-04, ER-05, ER-06, ER-07, ER-08, ER-09 and ER-12. Changes no observation.

- **A cross-source monthly join returned zero rows, silently.** Monthly series do not share a day
  convention: **2,057 are dated to the last day of the month, 1,757 to the first, 14 to neither**,
  and **164 alternate between conventions inside a single series** — including `M2 — Billetes y
  monedas en circulación` and `Activos Internos Netos (AIN) — Total`. Joining the price index, dated
  day 1, to the monthly average PYG/USD rate, dated month end, through the documented read path
  produced **378 CPI observations, 451 exchange-rate observations and 0 joined rows**. No error, no
  warning, an empty estimation sample. The normalisation that fixes it — `period_start` and
  `period_end`, which describe the same month whichever day the source printed — existed since
  schema 14 on `v_series_observations`, while `README.md` and `scripts/05_query_helpers.R` sent every
  researcher to `v_series_latest`, which did not carry it. Both current-value carriers now publish
  the bounds; the same join returns **378 rows**. `period` is untouched: it is half the observation
  key and it is what the publisher wrote. The rule lives in one function shared by both carriers,
  the contract is written down in `docs/TEMPORAL_CONTRACT.md`, and the release blocks on an
  unordered interval or a duplicate canonical period — both of which already held for all 1.2
  million observations, which is what makes them safe as blocking checks rather than a backlog.
- **Five index numbers were tagged as a price of US dollars.** Units are inherited at worksheet
  level, so a table whose columns are not all in the same unit mislabels every column on it. CUADRO
  60c is titled *"Tipo de cambio real bilateral — (enero 1995 = 100)"* and its five series — IPC,
  TCN, TCR USA, TCR Br, TCR Arg — all carried `PYG_PER_USD` and currency `PYG/USD`. The sibling
  worksheet CUADRO 60b publishes the same series under the same labels and **the same identity
  hashes**, correctly coded `INDEX` with no currency, which is as close to a control case as a
  metadata defect gets. On CUADRO 60a the euro, Argentine-peso and Brazilian-real quotations also
  declared a dollar denominator; only one of the four columns can have one, and the arithmetic
  against the dollar column on the same rows confirms each (2024-01: euro 7,945.71 against USD
  7,283.00 is EUR/USD 1.091; peso 8.90 is ARS/USD 818; real 1,483.44 is BRL/USD 4.91). Eight
  corrections are recorded in `config/unit_overrides.csv` with the worksheet title and the
  cross-rate as evidence. **`PYG_PER_USD` falls from 23 series to 15 and `INDEX` rises from 175 to
  180**; filtering by the currency-pair unit no longer returns index points. A new check compares the
  declared unit family with what the table title and column header say, at warning severity because
  it reads free text — the fail-closed consequence stays where it belongs, on research eligibility.
  `USD Fin Mes` (annual, 1945–1969, 3.12 to 147.50) was inspected and is **correct**: that is the
  guaraní's real path through the 1951 devaluation, not a unit error. What it needs is a methodology
  regime before it is spliced to the modern series, and that is recorded as open.
- **The documented read path returned no metadata.** `series_latest()` returned seven columns — no
  label, no unit, no frequency — and the join that fixes that lands on a label which names more than
  one series **1,599 times**, covering **4,015 of 7,229 scalar series**. `main.v_series_research`
  publishes the interpretable record on the path researchers are told to use, including the
  published table title, which is often the only field separating two series and lived only on a
  staging table at observation grain. It is resolved to one row per series in `canonical.series_titles`
  — **12,625 series, 12 of which the publisher has retitled between vintages**, flagged rather than
  fanned out. `series_research()` refuses an ambiguous label and names the candidates instead of
  choosing one; `series_wide()` has **no default join key**, rejects `period` by name with the
  reason, and refuses to combine frequencies without an explicit alignment rule.
- **Availability was recorded without saying how it was established.** All 22 vintages now carry
  `retrieved_at` and a new `availability_quality`, so a publisher's release timestamp and an archive
  time that merely bounds acquisition from above are distinguishable instead of arriving in the same
  column. All 22 are currently `inferred_upper_bound`, dated from the immutable archive — safe in the
  conservative direction, since an as-of query then sees less than a researcher could have, never
  more — and the build warns that no real-time claim may rest on them. `docs/ACQUISITION_RUNBOOK.md`
  is the forward procedure; the history that was never retained is documented as **irrecoverable**
  rather than marked resolved.
- **A release built from an uncommitted tree could be published.** `git_dirty` has been recorded on
  every build since schema 26 and read by nothing. It now blocks, with the same explicit override the
  environment check already had, which records itself as a flag so a development build cannot later
  be mistaken for a research release. `outputs/build_manifest.json` records what a result was
  computed from, naming the fields a second clean rebuild is not expected to reproduce rather than
  quietly dropping them.
- **The reported `Rcpp` environment drift does not exist.** The lockfile records CRAN's spelling of a
  revision, `1.1.1-1.1`; `packageVersion()` parses that and prints it back as `1.1.1.1.1`, because R
  has always treated `-` and `.` as the same separator in a package version. The check compared the
  two **strings**, and so reported a difference between a version and itself — for every package whose
  maintainer has ever issued a revision, on every build. Versions are now compared as versions, and
  the environment matches the lockfile exactly.
- **Five review queues that name rows instead of counting them.** The audit's standing complaint,
  applied to what was left: `exchange_rate_unit_worklist.csv` (every series on a worksheet assigning
  a currency-pair unit, with the decision taken against each), `unit_resolution_worklist.csv` (the
  4,057 unresolved units partitioned into true unknowns, mixed-unit sheets, missing column rules and
  non-measure records), `identity_stability_worklist.csv` (the positional identities, each with the
  repair its own label evidence supports), `out_of_region_cells_worklist.csv` (the 6,522 flagged
  cells collapsed into contiguous rectangles with the register row that would classify each) and
  `panel_duplicate_worklist.csv` (the duplicate groups themselves, with every dimension and whether
  the measures differ). The discontinuity and gap queues stop being ranked by magnitude alone: a jump
  the rest of its worksheet takes at the same moment is a rebase or a devaluation, one that happens
  alone is where a parser defect looks like economics, and only the second ordering separates them.

The economic review the audit's ER-03, ER-06 and ER-11 call for is **not** in this release.
`config/series_review.csv` and the canonical registers remain empty, so `marts.v_research_series` is
still 0 rows — by design, and it is the fail-closed principle working rather than a gap. Evidence-
backed proposals and the sign-off command that promotes them are the next step.

## Repository cleanup — 2026-09-03

Schema and published observations are unchanged. Superseded audit narratives, version-specific
repair notes, stale schema-12/14 CSV exports, obsolete version-1 compatibility wrappers and local
generated/session artifacts were removed. Living regression tests were retained and renamed by the
behavior they protect. `revisiones/EMPIRICAL_READINESS_2026-09-03.md` is now the only current audit
and remediation guide; Git history remains the archive for deleted historical reports.

## v38

Re-audit addendum, roadmap items P2. Changes no observation.

- **The identity could not distinguish the machine, and recorded 19 of 61 packages.** Schema 35
  narrowed the environment record to the declared set, arguing that a difference three levels down
  is not actionable from a failure message. That is a good argument for not *failing* on it and none
  at all for not *looking*: 42 pinned packages went unrecorded, and the narrowing hid something
  specific. The addendum names five direct packages built under R 4.5.2 while R 4.5.1 runs. Measured
  here: **all 61 are built under R 4.5.0 or R 4.5.2 and not one under 4.5.1**, including `DBI` and
  `duckdb`, which write the database. `packageDescription()$Built` is the field that says so and
  nothing read it. The whole lockfile is now recorded with each package's build, plus
  `platform` (`aarch64-apple-darwin20`) and `os_release` — before this, an arm64 macOS build and an
  x86 Linux build produced identical identities. `check_environment()` compares all 61 and fails only
  on the 19 direct ones, because the transitive ones are still not actionable but should no longer
  be invisible.
- **`loadedNamespaces()` is recorded and deliberately not hashed.** A departure from the addendum's
  wording, with the reason in the code: loaded namespaces differ between `run_update.R` and
  `run_tests.R`, so folding them into `build_id` would make the same sources on the same machine
  produce two identities depending on which entry point ran — and "re-running against unchanged
  inputs reproduces the exact same release" is the property the whole release model rests on.
- **A locale could have changed a build identity.** Found while fixing the above: the package list
  feeding the digest was ordered with `sort()`, which is locale-aware — `"DBI"` sorts before `"bit"`
  under C and after it under `en_US`. Ordering feeds the digest, the digest feeds `build_id`. It is
  radix-sorted now, which is byte order everywhere and also what DuckDB's `ORDER BY` gives, so the
  stored rows and the digest agree. A reproducibility defect introduced by the fix for a
  reproducibility defect, caught by the test that recomputes the digest from the stored table.
- **An artifact identified by its bytes.** The id hashed a size read while the connection was still
  open with rows still to be written: **553,136,128 recorded against a shipped 344,993,792, 37.6%
  out**, so the identifier of a database could not be recomputed from the database. The obstacle is
  arithmetic, not engineering — *a file cannot contain its own hash*, because writing the row changes
  the bytes the row describes. So the rule is now stated and followed: **a database records the
  hashes of artifacts other than itself, and its own lives in a sidecar beside it.** The sidecar is
  written after close, checkpoint and rename — the one moment the bytes are final — in the format
  `shasum -a 256 -c` reads. The database it replaced is recorded *inside* it with a real hash, since
  that file is finished and this build is the only party that can witness it. Compaction registers
  the same link between what it consumed and what it produced.
- **38,433 discontinuities in fifteen rows.** The screen summarised by source, which no one can
  investigate — and the inner CTE already computed every field a reviewer needs before the outer
  `SELECT` threw it away. `outputs/discontinuity_worklist.csv` and `outputs/gap_worklist.csv` carry
  series, worksheet, period, previous and current value, the change, the `typical_change` threshold
  that flagged it, vintage and the A1 source coordinate, ranked by severity and bounded. The first
  row it surfaces is `financial_indicators` sheet 7 rows 98–99 going 0 → 7,715.471 → 0 in
  consecutive months, which the source-level count could never have shown.
- **The last skip is gone.** The production-state defect check switched itself off whenever no
  worksheet carried a defect — i.e. exactly when the code was clean. It now asserts what it finds.
  **The suite has no skips.**
- **A record that survives the process.** `ensure_dirs()` has created `logs/` since the first audit
  and nothing ever wrote to it. `logs/update_<YYYYMM>.jsonl` now carries one line per event, for the
  case that justifies it: a run that dies before its candidate can be opened has no database to have
  recorded anything in, and the message went to stderr and vanished with the session.
- **9.5 GiB the retention script reported and did not understand.** Twenty-six hand-named copies
  matched no class. What they are cannot be read from `pre30b_194844.duckdb`, but it can be read from
  inside them: every DuckDB file states the schema version it was left at. `prune_backups.R
  --classify` opens each read-only and names it for what it contains — the earliest copy at each
  schema version is migration evidence and is kept, a second or fifth copy at the same version is a
  working snapshot and ages out. Result: **19 migration copies retained, 7 working copies (2.8 GiB)
  now subject to retention, zero unrecognised**. Nothing was deleted; `--apply` would reclaim 4.3 GiB
  and remains the operator's call.

## v37

Re-audit addendum, roadmap item P1. **Changes a published count.**

- **A trade with an unknown volume is still a trade.** Schema 34 stopped three real corporate-bond
  purchases vanishing and recorded them as `missing_mandatory_dimension` — right about silent-loss
  detection, wrong as economics. Their date, broker, ISIN, issuer, instrument, market, operation type
  and currency are all present and intact; what is absent is one *measure*. Classing the row as
  unplaceable understated the count of corporate-bond purchases, so a reader summing `transactions`
  in the daily activity view got a number wrong by three for reasons only the rejection register
  explained. They are now accepted with a null volume and `volume_status = 'not_reported'`.
  **The securities snapshot moves from 312,326 to 312,329 rows** — the first change in this sequence
  of rounds that moves a published count. No monetary total changes: `sum()` already skipped NULLs.
  `v_securities_daily_activity` reports `transactions_with_volume` beside the sum, so the two
  denominators are visible rather than assumed equal.
- A *malformed* volume token is still a rejection, and a blank currency or instrument still is —
  those are dimensions the grain is built from, not measures hanging off it. The accounting guard
  changes from a prohibition to a **correspondence**: a null volume is permitted only where the
  source token was blank, so a measure the parser failed to read still stops the run rather than
  quietly becoming "not reported". The identity needs no change — both sides are `count(*)` — and the
  register text that named these three rows as rejected is rewritten, since it became false.
- **Two updates could publish at once and the last one won.** Because production is only ever
  *copied* and never opened, DuckDB's own single-writer lock protects nothing between runs: two
  builds could copy the same database, both be accepted, and both rename over it — the loser
  disappearing along with its build identity and every diagnostic it produced. A lock at
  `database/.update.lock`, taken with `dir.create()` because that is atomic where `file.create()` is
  not, holds pid, host and start time. A lock whose process is gone is reported and taken over: a
  crashed update must not block the run that fixes it.
- **And the base is verified, because a lock alone cannot cover it.** The production file's SHA-256
  is recorded at copy time and re-checked immediately before the swap. A lock inherited from a dead
  holder, or an operator restoring a backup by hand mid-build, produces a state no lock sees. If it
  changed, the run refuses and **keeps** its candidate — it is a complete accepted build, and the
  operator needs it to diff against whatever replaced its base.
- **The window where neither rename has completed.** Between moving production aside and moving the
  candidate in, the published pathname does not exist. A soft failure was already rolled back; a hard
  kill was not, and left no database and nothing saying why. A `.swap_in_progress` marker names both
  files and what to do with each, and the next run refuses to start until it is resolved.

## v36

Re-audit addendum, roadmap item P0. Changes no observation.

- **The as-of interface ranked over the present and answered about the past.** `release_id` hashes
  the manifest, so replacing one workbook mints a new bundle whose `release_sources` set omits the
  vintage it replaced. The as-of macros read `v_series_observations`, which filters to the bundle the
  one-row pointer names — so a superseded vintage left the ranking population entirely and **no
  cutoff could return it**, including cutoffs from before its replacement existed. It is the same
  look-ahead error the interface exists to prevent, in the one place it was least visible.
- **The manual's own recipe produced exactly that state.** `docs/OPERATIONS.md` told the operator to
  ingest the historical workbook and then restore the current one — two runs, two bundles, and the
  historical vintage dropped from the carrier. Following the instructions gave you two vintages and
  one answer.
- **The ingredients existed and nothing joined them.** `release_sources` is append-only and
  many-to-many; `data_releases` holds one immutable decision per product. Their join *is* the set of
  vintages a researcher could ever have been shown, and nothing in the codebase performed it.
  `main.v_series_observations_history` does, declared `history` in the view contract — **a scope the
  contract has declared valid since schema 30 and no object had ever used.** The current views keep
  the pointer; the two questions stay separate. It reads `data_releases.status`, not
  `releases.status`, because the latter is the mutable column schema 30 retired and using it here
  would let a later failure erase history that was genuinely published.
- **The as-of macros were declared `current`, and that was part of the defect.** The lint requires a
  `current` object to descend from the active-pointer carrier — so while they were classified that
  way, the lint was certifying the very thing that made them wrong. They are `history` now, and the
  lint checks the two boundaries separately: a history carrier must restrict to accepted products and
  must **not** restrict to the pointer, or it is the current carrier under another name.
- **Blocking a bundle today no longer erases what it published yesterday.** Current views empty
  immediately because the pointer moves; as-of keeps answering, because a later failed rebuild does
  not un-happen an earlier publication. A bundle that was *never* accepted stays invisible at every
  cutoff. One schema-31 test encoded the opposite coupling and was updated with the reasoning beside
  it.
- **The release context was a lexical maximum.** `max(release_id)` over `"release:" || sha256[1:24]`
  picks whichever hex prefix sorts highest — not the earliest, not the latest, not the active one —
  and it read the retired `releases.status`, so a failed rebuild of any bundle containing a vintage
  nulled the label on rows that were still published. It is exposed to researchers in every
  `v_mart_*_all`. It now names the accepted product that **first admitted** each vintage, with
  `first_published_at` beside it.
- **The review register admitted nothing.** Schema 34 wrote it, validated it, published it — and
  nothing that decided anything read it. `marts.v_research_series` asked only whether every
  contributing worksheet was `validated`, and the eligibility gate compared six **column values**
  against two sentinels the derivation layer never writes. A label containing `saldo` and `serie
  original`, plus a published base year, unit and scale, fills all six with
  `basis = 'published_label'` — so promoting a single worksheet would have admitted every series on
  it with no economic review at all, while the documentation said the register was what let them in.
  **That documentation was mine, written the round before.** The view and every validated mart now
  join the register, and the gate reads the *basis*: `research_series_evidence_not_reviewed` fires
  when a series on the research surface carries a field with no reviewed evidence behind it.
- **Which review is authoritative, answered rather than left implicit.** `table_status` is about a
  *worksheet* — is its parsing and cell accounting fit to publish. `series_review` is about a
  *series* — is its economic meaning established. Neither implies the other, and both are required.
- **A defect the test found, not the reasoning.** `frequency` is a research-eligibility field, and
  the register carries it and writes it to `dim_series` — but it was missing from the vector of
  fields `apply_series_review()` records evidence for. Harmless while nothing read the evidence, and
  immediately fatal once the gate did: a *fully completed* review could not satisfy the check written
  for it. The two lists are now a union, so they cannot drift again.
- **Seven further register checks**, each of which passed silently before: frequency vocabulary,
  strictly positive scale multiplier, plausible four-digit base year, self-parenting and hierarchy
  cycles, unit/currency coherence, and a review date in the future. `parent_series_id = series_id`
  used to pass, because the known-series set contains the row's own identifier. The frequency
  vocabulary is read from the frequencies the database actually holds rather than invented — the
  project has two frequency lists and they disagree (`EXPECTED_GRID_FREQUENCIES` omits `semiannual`,
  the marts gap screen includes it), and reconciling those is a real but separate defect the addendum
  does not raise.

## v35

Seventh technical audit, roadmap item P2. Changes no observation.

- **The build identity could not tell which library built the database.** It hashed `renv.lock`,
  which is a *declaration*: two builds run against libraries differing from each other and from the
  lockfile produced the same `build_id`. That is an identity unable to answer the one question it
  exists for. It now hashes the versions that actually ran, and `audit.build_environment` keeps the
  list beside the digest — a digest says two builds differ, only the list says which package moved.
  It goes inside the hash rather than in a column next to it, because a different library **is** a
  different build. **Every `build_id` changes once, deliberately.**
- **And the update refuses to build against an environment that differs from the lockfile.**
  `check_environment(strict = TRUE)` has existed since the first audit and nothing called it.
  `PARAGUAY_MACRO_ALLOW_ENV_DRIFT=1` is the deliberate override and the build that takes it carries
  an `environment_drift_overridden` flag saying so: a gate with a silent bypass is not a gate. The
  quick start moves to `renv::restore()`; `scripts/00_install_packages.R` stays as the fallback
  without `renv` and now says what it does, which is install by name and check presence, not version.
- **"Is *this* number a cached formula result?"** Schema 29 recorded formulas and hidden rows per
  worksheet, closed the per-observation gap for hidden rows and could not close it for formulas: the
  hidden ranges are coordinates and the formula count was a number. `raw.report_cell_formulas` keeps
  the coordinates, and `marts.v_observation_source_behaviour` exposes `from_formula_cell` per value.
  The cost argument recorded at schema 29 — that per-cell formula data would re-hash the entire raw
  layer — was about storing formula *text* in the content-hashed `report_cell_values`, and does not
  apply to a side table. The A1 refs were already in hand: the `<f>` node set was being selected and
  collapsed with `length()`. **91,673 coordinates against 91,673 counted**, in the same pass, no
  second read of any file. No source is re-ingested — formula position is a property of the archived
  workbook, recovered from it exactly as schema 29 recovered the counts.

  And the answer is not evenly spread, which is the point of asking it per value:
  **81,367 of 1,100,840 published documented observations (7.4%) sit on a cell that held a
  formula**, but `bcp_fx_daily` is **27,224 of 40,836 — two thirds of the daily BCP exchange-rate
  series** — against 4.6% of the economic annex. A researcher taking daily FX from this database is
  mostly taking cached results of formulas `readxl` cannot recompute, and until now there was no way
  to know that from the data. The hidden-row count is unchanged at 15,403, which is the check that
  the existing measure still means what it did.
- **The expected grid, measured against a budget — and the audit's number for it corrected.** The
  report says this table holds 9,152,525 rows and is the largest in the database. It is not: the
  live database held **267,830** before this round and holds 267,830 after. The phase builds one row
  per regular series-period per vintage and then prunes, keeping a period only where it is an
  observation or an explained absence. The nine million is that pre-pruning intermediate — real, and
  what costs the time, but not a row count anyone can query, and reporting it as one sends a reader
  looking for a table thirty-four times smaller than described. What is true is that the phase is
  the slowest in the run, **24.6 of 82.9 seconds**, and that both it and the stored table grow
  linearly in retained vintages, which is what P1 asks for more of. The update report now leads with
  the seconds and carries the rows, the retained vintages and the contributing vintages beside them;
  a warning fires when either budget is passed, naming the two ways out. A warning and not an error:
  growth is the consequence of doing the right thing with vintages.
- **34 deprecation warnings, gone, and a test that switched itself off.** `.data$` inside `select()`
  at four call sites; a static test now expects zero, because in a suite that always prints warnings
  nobody reads the twenty-ninth. And `test-grain-and-provenance.R` skipped whenever no worksheet
  carried a defect — it disabled itself exactly when the codebase was clean. A synthetic fixture now
  builds two worksheets **both validated by an economist**, one that reconciles and one that does
  not, and asserts only the first reaches the mart.
- **13 GB of backups nobody was going to delete by hand.** A naming convention per producer, and
  `prune_backups.R` that reads it: migration and milestone copies are kept, rolling classes keep the
  most recent few, and **anything it does not recognise is reported and left alone**. Dry-run by
  default, and the pipeline never calls it — a rule that deletes databases as a side effect of a
  build will one day delete the copy you needed, and `pre_swap_` exists for the runs where something
  went wrong. On the current state it identifies four near-identical compaction copies from one
  afternoon (2.5 GiB) and leaves the 26 hand-named ones untouched.

## v34

Seventh technical audit, roadmap item P1. Changes no observation.

- **Three real securities trades had been disappearing on every run.** Both CSV parsers read with
  `readr::parse_number()` — which takes the first numeric run out of any string it is handed —
  dropped whatever came back `NA`, and recorded nothing, so the only loss they could notice was
  losing *every* row. Measured before touching code: **312,329 rows in the file, 312,326 in the
  database**. The three are corporate and subordinated bond purchases with a blank volume, at source
  rows 4747, 29690 and 173494. Every row is now accepted or rejected with a declared reason written
  to `staging.discarded_rows`; a partial numeric token (`12abc`, `1.2.3`, `5 %`) is a rejection
  rather than a number; a structurally broken file is refused **whole**, because a file whose shape
  contradicts its contract is not the file the contract describes; and
  `source rows = accepted + rejected + documented exclusions` is measured per CSV vintage in the same
  table the worksheet accounting uses. **An undeclared rejection reason blocks the release.** The
  machinery was already there and unused: `discarded_rows` since schema 12, and
  `compute_table_reconciliation()` already summing `rejected_observations` out of it. Measured
  after: 38,922 = 38,922 + 0 for the bond curves, 312,329 = 312,326 + 3 for the trades, both
  balanced.
- **The gate found something on its first run, and it was not in the CSV path.** The ICC/EVE and
  FX-operations parsers have been discarding rows as `non_data_note` since schema 12 under a reason
  no register described. The audit names the CSV path because that is where rows were vanishing
  *unrecorded*; the principle was never about CSVs, so the register covers all of `discarded_rows`
  and is named for that. And the first attempt to test it was worthless: it compared the register
  against a grep for `reason = "..."` over the sources, which missed both the ternary in the FX
  parser and the CSV reasons, which are list names rather than literals. A grep over source is not a
  vocabulary. `ROW_REJECTION_REASONS` is, a parser cannot record anything outside it, and the
  register must equal it **in both directions** — a declared reason no parser can write is a claim
  about a behaviour that does not exist.
- **This step re-ingests the two delimited sources, and declaring it not to was a defect of its
  own.** An unchanged source is never re-parsed, so in a reuse build nothing records the rejections
  and the accounting correctly reported three source rows neither accepted nor rejected — and
  blocked. Those are the same three trades: they can only be classified by reading the file again. A
  step that changes what a parser records has to send that parser's sources back through it, which
  is what `reingests` in `SCHEMA_MIGRATIONS` is for.
- **A vintage without its bytes is not retained; it is a row claiming to be.** Every archived file is
  re-hashed on every release, and a missing or mismatched one blocks. **22 of 22 verified in 0.51
  seconds** over 104 MiB, against a 49-second run — cheap enough that sampling would have been a
  false economy. `outputs/vintage_retention_status.csv` says per vintage what is held and what it
  costs: while a source retains one vintage, that row says there is no revision history and no as-of
  reconstruction. Nobody should need an external audit to discover that.
- **An economist now has somewhere to write down what they reviewed.** Verified before building it,
  because the risk was duplicating schemas 28 and 31: rows in `canonical.series_semantic_evidence`
  whose `basis` is `reviewed` are deliberately preserved across every rebuild while derived ones are
  deleted and recomputed — and **nothing in the codebase had ever written one**. There was an output
  worklist naming what was unreviewed and no input for the answers. `config/series_review.csv` is
  that input, one column per property section 11.4 lists. It is applied *after* the derivation layer,
  so "reviewed wins" is true by construction rather than by each derivation remembering to check.
  **A problem in any row applies none of it** — not the good rows with the bad ones reported, because
  a partly-recorded review fills exactly the columns the research-eligibility gate reads. It ships
  empty; `marts.v_research_series` stays at 0 rows until somebody writes the first one, and that is
  correct.

## v33

Seventh technical audit, roadmap item P0. Changes no observation.

- **A failed build could not withdraw the published database. It could still change it.** Schema 30
  closed the first half; the second needed something no care inside one file can give, because the
  run and the published database were the same bytes. Three isolation mechanisms existed and none was
  enough: the per-source transaction stops a half-parsed workbook landing, the release transaction
  stops a half-rebuilt derived layer landing, and the decision and pointer stop a failed build
  withdrawing the product — and **all three operate inside the file that is the product**. Published
  views resolve vintages through the source bundle rather than the build, so every build of one
  bundle exposes the same rows; sources commit one at a time hundreds of steps before the verdict
  exists; and worst, `initialize_database()` runs the migrations' `invalidate_v*()` steps, which
  delete published facts by `source_id` **before the run has begun**. Committed work under a pointer
  that has not moved is still committed.
- **So the run and the published database stop being the same bytes.** `run_isolated_update()` copies
  the database to `database/candidates/`, builds there, and renames the candidate into place only if
  it is accepted. It is the procedure `compact_database.R` has used for its own swap since schema 22,
  and `run_manifest_pipeline()` was already parameterised by `db_path`. A blocked build never opens
  the published file for writing and its candidate is retained, so the `_all` twins and every
  diagnostic of the failed build stay inspectable. **What this gives:** a build you did not accept
  cannot have altered the one you did, provable by hashing the file. **What it does not give:** facts
  are still not versioned per build, so an arbitrary past product cannot be reconstructed from inside
  one database. That limit is unchanged and is stated rather than implied away.
- **The regression the audit writes out, step by step.** The previous round's test asserted that the
  pointer does not move and that the release transaction rolls back. Both passed and neither was the
  question. This one publishes value 1, starts a build against the same bundle, has it replace that
  value with 999, fails it after the source commit, and asserts the published file's **SHA-256 is
  identical** — while the retained candidate does return 999. That last part matters: inside the
  candidate the *filtered* view returns 999, because the mutated row belongs to a vintage of the
  bundle that file's own pointer names. The two files answer the same query differently, and that is
  the whole repair.
- **It was demonstrated on the first real run, by accident.** The rebuild for this round blocked —
  on the schema-34 accounting below, correctly — against the live 22-source bundle, with the
  migrations already applied to the candidate. `database/paraguay_macro_pilot.duckdb` came out
  **byte-identical**: `c3380f43…f936bf51` before and after. Under the previous code that same run
  would have executed the invalidation steps against the published file, deleted the two CSV
  sources' facts, rebuilt the derived layer, committed all of it, and *then* blocked, leaving the
  published database a mixture of two builds. Nothing was staged for this; it is what the first
  attempt did.
- **The coverage dashboard counted direct investment three times.** `config/source_grains.csv` has
  been keyed by worksheet since schema 32 and the dashboard joined it on `source_id` alone: **256
  rows for 242 worksheets**, with each of the seven `direct_investment` sheets appearing three times
  under contradictory grains, so any sum over the file tripled it. The correct idiom sat sixteen lines
  below, written for `table_status`. Copying it a third time is how the second copy came to be wrong,
  so it is written once — and writing it once exposed that the second copy was only accidentally
  right: its inner select dropped the *register's* `source_sheet`, so the tie-break read the
  worksheet's name, which is never `'*'`, leaving the window's ordering constant and the winner
  arbitrary wherever a source carries both a wildcard and an exact rule. Five sources and fifteen
  worksheets are in that position; latent only because all fifteen exact rules currently agree with
  their wildcard. **256 → 242 rows, 242 distinct keys**, `Cuadro 5` and `Cuadro 7` back to
  `entity_panel`. The dashboard moves out of the post-decision step, where no gate could see it, and
  a duplicated worksheet now blocks the release.
- **The manual told operators to edit a column that does nothing.** `docs/OPERATIONS.md` said to
  override a decision by updating `audit.releases.status`, "because every published view joins
  through that table". They have resolved through `audit.active_data_release` since schema 30, so the
  instruction was wrong twice over. It is replaced by the two interventions that exist — restore the
  `pre_swap_` copy each accepted swap now leaves, or fix the cause and re-run — and by the statement
  that there is no supported way to promote a build the gates blocked, which is not an oversight.

## v32

Sixth technical audit, roadmap item P2. Changes no observation.

- **Grain is declared per worksheet as well as per source.** One grain for a whole workbook was too
  coarse, and direct investment is the case: the source is `scalar_series` and its `Cuadro 5` and
  `Cuadro 7` are foreign direct investment stocks by country — 73 and 34 country series, an entity
  panel wearing a scalar catalogue's clothes. `config/source_grains.csv` is now keyed
  `(source_id, source_sheet)` with `*` as the source-level rule. 214 identifiers left the macro
  catalogue, which holds **7,229**.
- **Workbook provenance per observation.** `marts.v_observation_source_behaviour` exposes
  `from_hidden_row` and `sheet_formula_cells` beside each value's coordinate. Recording them per
  worksheet was right for the drift test and wrong for a researcher holding a number: "15,403
  observations come from hidden rows" is a fact about the database, and "is *this* value one of them"
  was a question you could only answer by unpacking a packed range yourself. Derived, not stored.
- **Every source selects by recorded hash.** All 22 move from `newest_mtime` to `manifest`. The
  failure mode changes and it is worth knowing: with one candidate file the rule never fires, and
  with two the run now **stops** and names the fix where it used to pick the newer modification time
  and warn. Modification time is when a file reached this disk, not when the publisher released it.
- **The database is a recorded distribution artifact.** `audit.distribution_artifacts` gives the
  `.duckdb` file an identity, so the commit carrying a rebuilt database — necessarily later than the
  build that produced it — stops reading as a provenance mismatch.
- **The dominant phase is skipped when it cannot produce a different answer.** Rebuilding a
  2.4-million-row expected grid took 19 of the 36 seconds of a reuse build. It is skipped when the
  stored grid carries this same `build_id` — a stronger guard than "did any source change", because
  `build_id` hashes the code and configuration too, so editing the missingness logic forces a full
  rebuild. **19.08s → 0.03s**, with an identical 20,647 rows.

Three defects in v30's own work, found while verifying this round rather than by the audit:

- **The supported read interface bypassed the release boundary entirely.** `series_as_of()` in
  `scripts/05_query_helpers.R` — the file the operations manual calls the supported read path —
  ranked `canonical.fact_series_events` directly, with no release filter and no observation status.
  Neither the lint nor the new public-view contract was looking at it, because both reason about
  *stored objects* and this is an R function: the same class of gap as R6-01, one layer further out.
  It also answered a different question from the stored macro of the same name, ranking by
  publication date where `series_as_of_date()` ranks by `available_at`. It now delegates to the
  macro, and a test asserts the whole helper file reads only published surfaces.
- **A bare `DBI::dbBegin()` could abort the transaction it was inside.** The per-source ingestion
  opens its transaction explicitly, across a `tryCatch` boundary, and did not register it — so the
  first unit inside that asked for a transaction tried to open a second, and in DuckDB that failed
  `BEGIN` aborts the transaction it was asking about. Only a full ingest takes that path, which is
  why it took building a database from the real workbooks to find. Every transaction now goes
  through the register.
- **The fresh-connection check could hang instead of failing.** A second connection to a DuckDB file
  whose writer holds an open transaction waits rather than erroring, so a leaked transaction turned a
  release into a deadlock with nothing to read. It is now reported as
  `release_transaction_left_open` and the check is skipped: diagnosis beats deadlock.

## v31

Sixth technical audit, roadmap item P1. Changes no observation.

- **"Latest" files describe the latest run.** The flag CSV held 33 rows where the database held 35,
  because it was written at the end of validation and the gap and discontinuity screens run after
  validation. The update report, headed "this update", carried 696 timing rows from eight attempts
  that shared a source bundle — the same stage over and over with durations from runs that were not
  this one; it now carries the 56 this attempt measured. Flags are attributed to the attempt that
  raised them and are no longer deleted by `release_id`, so re-running a bundle stops destroying the
  accepted build's diagnostic evidence. The release compares each generated file against the
  database beside it.
- **The availability documentation was overstated, and it was ours.** `docs/DATA_MODEL.md` said
  `available_at` "is never inferred from the reference period". True of the operator-recorded field,
  false of the column: 12 of 22 publication dates derive from the content maximum, and `available_at`
  falls back to the publication date. The section now states the fallback chain, that
  `series_as_of_date('2020-12-31')` returns zero rows, and that no real-time claim should be made
  from this database until provenance is recorded.
- **Queues someone can pick up.** `outputs/source_provenance_worklist.csv` names per vintage which
  acquisition fields are missing and what each costs, separating `available_at` — on which every
  point-in-time claim depends — from the four that only affect re-acquisition.
  `outputs/source_region_review_queue.csv` ranks the 6,522 unreviewed cells by the economic weight of
  the worksheet rather than by cell count: sorted by volume the LRM auction year-sheets come first,
  and nobody should review those before the price index.
- **Two gates that pass vacuously, which is why they are written now.** A declared canonical
  membership must be *comparable* as well as equal — aliases differing in unit, scale or frequency,
  and aliases sharing no period with their primary and therefore never actually tested, block the
  release. And a direct publisher panel reaching an aggregate mart blocks the release while 411
  groups of rows repeat every dimension the database models.

## v30

Sixth technical audit, roadmap item P0. **Contains a breaking change to a published interface.**

- **Publication is a pointer at an immutable decision, not a status on the source bundle.** A
  `release_id` hashes the source files, so fourteen attempts across schemas 26–29 shared one, and the
  single attempt among them that ended blocked set that shared row to `blocked`. Every published view
  joined `releases.status = 'accepted'` — so **a failed rebuild withdrew the entire published
  database**, not the data it produced but the data it failed to replace. `audit.data_releases` now
  records one decision per product, inserted once and never rewritten;
  `audit.active_data_release` is a one-row pointer only an accepted build moves.
- **The release-wide phases run as one transaction.** Without it the pointer is theatre: a build that
  died halfway had already half-rebuilt reconciliation, semantics, the expected grid and missingness
  underneath a release still marked accepted. This needed a nesting-aware transaction helper, since
  eight phases open their own and DuckDB has no nested transactions — and detecting the outer one by
  attempting a `BEGIN` does not work, because the failed probe aborts the transaction it is probing.
  **What this does not give:** facts are not versioned per build, so a past product cannot be
  reconstructed from the database. Only the decisions are preserved.
- **Every published object declares what it is for.** The release lint has been rebuilt twice and the
  audit found the deeper problem: a rule over *names* cannot decide which objects are research
  interfaces, and a test for the word `releases` cannot decide whether one filters.
  `v_series_observations` read the whole fact table and `LEFT JOIN`ed accepted releases only to
  populate a label — the body contained the word, so the lint passed it, and passed the projections
  built on it, and the canonical views built on those. `v_fx_operations_annual` and
  `v_series_catalogue` matched no naming rule, and neither did 35 other public objects.
  `config/public_view_contract.csv` declares scope per object; an undeclared object blocks the
  release; and filtering is decided by descent to a declared boundary-carrying relation, never
  through an `_all` twin.
- **Breaking: `v_series_latest` is realized observations only.** Schema 27 kept the 343 projections
  there and exposed `observation_status` beside them. The reasoning was sound and the naming was not:
  it is the obvious default, and a researcher who never reads the column gets 2028 forecasts in an
  estimation sample. The publisher's full current statement is `v_publisher_statement_latest`;
  `v_series_latest_observed` remains as an alias; a projection reaching the realized view is now an
  **error**.
- **The projection fan-out**, the same `DISTINCT`-sheet join found and fixed in the grain catalogues
  one schema earlier and missed in this copy. And the expected grid and missingness carry the vintage
  and build they were computed from, so a diagnostic published in a mart can be release-filtered
  instead of matching on `series_id` and hoping.
- The acceptance test is adversarial, not the lint: `test-release-isolation.R` builds a
  database that genuinely holds a vintage nobody may see, asks every `current` interface for it, and
  asserts the `_all` twins *do* return it so the test cannot pass vacuously.

## v29

Fifth technical audit, roadmap item P2. Changes no observation.

- **A catalogue per series grain.** `marts.v_catalogue_scalar_series`, `v_catalogue_event`,
  `v_catalogue_curve_panel` and `v_catalogue_entity_panel`. `series_grain` already classified them and
  `v_catalogue_by_grain` already counted them, but a single undifferentiated catalogue is still what a
  reader opens, and it said this database holds thousands of macroeconomic series when 3,083 of those
  identifiers are one LRM auction tender each and 1,287 are one curve node.
- **Cached formulas and hidden rows are recorded per worksheet.** `raw.source_sheets` gains
  `formula_cells`, `hidden_rows` and `hidden_columns`. Neither survives into any value the parser
  reads, and both change what a number means: `readxl` cannot calculate, so every number here is a
  cached result, and a hidden row is one the publisher's own reader does not see. The current release
  holds 91,673 formula cells across 104 worksheets, and **15,403 published observations across 13
  worksheets come from rows the publisher hid** — mostly the annex collapsing the early history of a
  long table, which is benign, and none of which was visible before. `workbook_behaviour_changed`
  reports drift in either between vintages; `outputs/workbook_behaviour_latest.csv` carries the state.
- **No source was re-ingested to get them.** Both are properties of the workbook rather than of a
  parsed value, so every already-archived vintage was filled in from its own archived file. The
  backfill is idempotent and covers all 284 worksheets across all 22 sources.
- **Stage timings are per attempt and append-only.** `audit.ingestion_stage_timings` is keyed by
  `attempt_id` and no longer deleted per release, and the release-wide phases — reconciliation, region
  classification, the expected grid, missingness, semantics, canonical, marts, validation — are timed
  rather than only the per-source parsing. `observation_missingness` at 21s is the slowest phase in the
  run, which was not previously measurable.
- **Build dirtiness answers the question it is asked.** Every `build_identity` row recorded
  `git_dirty = TRUE`, and committing the tree did not change it. `git_build_state()` runs from inside
  the pipeline, by which time the run has written to the tracked `.duckdb`, so the file the build was
  producing counted as an uncommitted change against the build producing it — unsatisfiable by
  construction. The database is excluded and nothing else is, and a git call that fails is now `NA`
  rather than `FALSE`: a dirtiness check that fails open is worse than the one it replaced.
- Documentation: the README is titled for the schema it describes rather than v11, states what
  `latest`, `as-of` and `validated` each guarantee, and corrects the claim that bank and
  finance-company panels carry no row number. `docs/DATA_MODEL.md` and `docs/OPERATIONS.md` follow.

## v28

Fifth technical audit, roadmap item P1. Changes no observation.

- **An accepted release survives its own rebuild.** `stage_release()` used to delete and re-insert, so
  re-running a bundle set an already-accepted release back to `staged` and un-published the database
  for the duration of the run. It now leaves a decided release alone; promotion is one terminal
  `UPDATE`.
- **An attempt is recorded when it starts.** The `ingestion_run_attempts` row was written at the end,
  which meant the one case where the record mattered — a run that crashed — was the one case that left
  nothing. It is now opened with status `running` and closed from an `on.exit()` handler.
- **An identity component that is absent is no longer read as zero.** `validate_published_identities()`
  used `coalesce(component, 0)`, so a period publishing the total and half the parts could pass by
  arithmetic accident. Presence is now checked first and reported separately as
  `published_identity_incomplete` (warning); `published_identity_broken` (error) means the components
  are all there and do not add up. Five identities have periods where the publisher gives a total
  without every component.
- **`source_files.release_id` is `first_ingested_release_id`.** It records the bundle a vintage arrived
  in, which is not the release a query is reading; that is derived through `release_sources`.
  `v_series_observations` carries both.
- **Operator-recorded availability.** `available_at` in `raw.source_provenance` outranks the date
  derived from the file when `series_as_of_date()` ranks vintages. It ships `pending`; the values are
  the operator's to supply.
- **A research-eligibility gate.** A series may not enter a validated mart without unit, scale,
  frequency, stock/flow, nominal/real and seasonal adjustment, with `not_reviewed` not counting. It
  passes vacuously because nothing is promoted — which is why it is written now rather than after the
  first promotion.
- **Duplicate evidence, not duplicate decisions.** `outputs/duplicate_series_candidates.csv` screens
  for series agreeing period-for-period by md5 signature, and
  `validate_canonical_membership_agreement()` blocks a release in which a declared alias disagrees with
  its primary. `config/canonical_series.csv` stays empty: declaring one canonical series means
  asserting seven economic properties under a named reviewer, and that is economic review, not
  automation. The evidence is ranked and waiting.

## v27

Fifth technical audit, roadmap item P0.

- **One accepted-release boundary, on every published interface.** Thirty-four views carried no release
  join: all seventeen `v_latest_raw_*` direct panels, the whole documented family, and both market
  views, which tested `ingestion_status = 'completed'` — a fact about whether a file loaded, not about
  whether it may be published. The filter now sits inside each ranking subquery, so a view returns the
  newest vintage a researcher may see rather than nothing while a newer one is staged, and every
  filtered view has an unfiltered `_all` twin for diagnostics. The lint requiring the join follows view
  dependencies transitively instead of reading a hard-coded list.
- **A unit stated in a table title outranks a keyword in a row label.** `CUADRO 20` is titled *"En
  millones de dólares"*, and twelve of its thirty series carried `unit_code = COUNT` with
  `scale_multiplier = 1` because their row label contains *operaciones* — `value_in_base_units` wrong
  by 10⁶ on twelve foreign-exchange series, each of which matches a dedicated `fx_operations` series to
  floating precision over 379 monthly observations. The guard that already existed for *saldos* now
  covers any title stating a monetary magnitude, on the `count` and `days` branches alike. 16 series
  and 5,942 observations change unit; no value changes.
- **What the publisher writes instead of a number is read, not discarded.** 18,416 of the 20,156
  `blank_in_source` rows sat on cells holding the text `s/m` — *sin movimiento*, no transactions — and
  the classifier tested only whether a number had parsed. `config/source_value_tokens.csv` registers
  tokens with a status, quoted evidence and a **named** reviewer (`layout_verified` is rejected: what a
  publisher means is not a layout claim). Missingness is now classified on the cell's text, and an
  unregistered token becomes `source_token_unreviewed`, which blocks promotion rather than passing as a
  blank.
- **A published projection is distinguishable from an outcome.** 343 observations across 186 series are
  dated after the vintage that published them. `v_series_latest` and `series_as_of_date()` now expose
  `observation_status`; `v_series_latest_observed` and `marts.v_series_projections` split them.
  **The default keeps the projections, on the operator's instruction** — they are what the publisher
  published — so it is not a look-ahead-safe default, and `current_view_contains_projections` reports
  the count every release.
- **The unread data regions are parsed.** The direct-investment stock tables `Cuadro 5` and `Cuadro 7`
  publish a year-quarter header across two rows; the parser read one and lost 12,006 cells. It now
  reads both, guarded by the publisher's own arithmetic — the fourth quarter of a block must equal the
  annual column that closes it — so a workbook that changes shape fails loudly rather than shifting
  every period by a year. The annex horizontal axis stopped at the column carrying the last period's
  label rather than at the end of its block, losing 256 cells on `Cuadro 52a`/`52b`. **`data_not_ingested`
  falls from 12,371 cells to zero**, and the four rules recording that loss are retired with the
  defects.
- **Direct panels have a grain.** Each row records `source_row`, the physical worksheet row, and each
  panel declares `(vintage_id, source_sheet, source_row)` as a natural key enforced by a unique index —
  which makes the 399 duplicate dimensional keys in `raw_banks_canales_person` representable instead of
  ambiguous, and reported in `outputs/direct_panel_duplicate_keys.csv` rather than guessed at.
  `codigo_entidad` and `codigo_moneda` are stored as text: they are labels, not quantities, and the
  reference joins no longer depend on a `TRY_CAST` round-trip.

## v26

Fourth technical audit, roadmap item P2. Changes no observation.

- **The environment is recorded.** `renv.lock` pins R 4.5.1 and 61 packages. It was written with
  `renv::snapshot()` over the already-verified library rather than `renv::init()`, so renv is not
  activated through `.Rprofile` and no open session in the directory has its library path changed
  underneath it; `renv::restore()` stays a deliberate act.
- **`run_tests.R` no longer installs anything.** It used to source the installer first, so running
  the tests could change the environment being tested — which is also what made the suite unsafe in
  CI or during an audit. It now calls `check_environment()`, which reports drift against `renv.lock`
  and, in strict mode, stops. It does not install.
- **`audit.build_identity`** records the Git commit and dirty flag, schema version, digests of
  `config/`, of `scripts/` and `run_update.R`, and of `renv.lock`, plus the R version. `release_id`
  keeps meaning "these input files"; `build_id` means "this database".
- **`audit.ingestion_run_attempts`** is appended and never rewritten, so re-running a bundle no
  longer erases the record of what happened the previous times.
- **Staging natural keys are enforced.** A unique index on each of the seven snapshots, plus
  `validate_declared_natural_keys()` asserting both the key and the table's required fields at every
  release. The tables were not rebuilt to gain a `PRIMARY KEY`: DuckDB cannot add one to a populated
  table without recreating it, and recreating six snapshots along with every dependent view is a
  large risk for a small gain — the index covers uniqueness and the assertion covers nullability,
  which is the alternative the audit itself offers.
- **`selection_rule = 'manifest'`** picks a source file by the SHA-256 recorded in
  `config/source_vintages.csv`. `newest_mtime` still works and now says in its warning what it
  actually does: modification time is when the file reached this disk, not when it was published.
- Documentation: `README.md` and `docs/OPERATIONS.md` drop `completed_with_errors` and explain what a
  blocked release means for the research views; the README's provenance claim is narrowed to what
  each source family actually carries; `docs/VERIFICATION.md` describes the current executable
  environment instead of asserting that R is unavailable. Superseded review notes were later removed
  from the current distribution and remain available through Git history.

## v25

Fourth technical audit, roadmap item P1, less the parts that need a human. Changes no observation.

- **Source acquisition provenance.** `config/source_vintages.csv` is loaded into
  `raw.source_provenance`, joined on `(source_id, sha256)` rather than on the filename — the one
  thing the publisher changes freely. The gate is a warning while a source is provisional and an
  error once a worksheet of that source is claimed `validated`, because a research product nobody can
  re-acquire is not reproducible. All 22 vintages currently read `pending`, and the warning lists
  them.
- **Absence now has a reason.** The parsers skip `NA`, so a period the publisher never reported and a
  period the parser failed to read were the same missing row. `staging.expected_observation_grid` is
  the regular sequence each series' declared frequency implies, bounded by its own first and last
  period; `staging.observation_missingness` classifies every gap against the raw cell layer.
  **20,156 `blank_in_source`, 491 `period_absent_from_axis`, nothing unread and nothing ambiguous** —
  which answers the 18,448 financial-indicator gaps the audit reported: the cells are in the workbook
  and hold no number. The invariant `grid = observed + explained` holds exactly (267,830 = 247,183 +
  20,647).
- Three corrections were needed to get there, all of which manufactured gaps that do not exist: a
  `summarise()` that resolved a later `.data$source_row` to the column the same call had just
  created (which discarded 18,448 real gaps); the exchange-rate histories reusing one column across
  disjoint year blocks, so the months in between resolve to cells that *were* read, as a different
  series (2,090 on EURO Prom); and periods a worksheet places at several coordinates, where taking
  the first named a cell in another block.
- **Publisher-stated identities are checked.** `config/aggregate_identities.csv` carries only
  identities the source itself states, expressed over worksheet columns because a parser repair moves
  labels and never moves columns. All five hold on every published period, including the interbank
  `Mercado Interbancario de Fondos = CMM + REPO Interbancario + REPO Tripartito` across 3,287 trading
  days — which is independent corroboration of the Call Money block schema 24 recovered.
- **The two-vintage path is exercised end to end**: revision recorded with previous and new value,
  tombstone for the withdrawn series, `series_as_of_date()` returning 100 in March and 107 in June,
  and the release barrier withdrawing both vintages when the release is blocked. What remains
  undemonstrated, and is said so, is that a real BCP revision behaves this way.
- **No economic review is written.** `outputs/semantic_review_worklist.csv` ranks the 13,927 series
  with an open measurement field by weight, so a reviewer can start where it matters.

## v24

Fourth technical audit, roadmap item P0. Every figure was re-measured read-only against the live
database before any code changed; all reproduced. The historical audit narrative remains available
through Git history.

- **One authoritative publication date per vintage.** The audit found 422 `compensatory_fx_sales`
  facts saying 2026-12-31 while `raw.source_files` said 2026-07-31. Two defects, not one.
  `set_source_publication_date()` refused to overwrite a date it had already derived, so a
  content-derived date could never be corrected once the parser read more of the sheet; and the
  content maximum is not a publication date when the sheet is a template for the whole calendar
  year. Authority now decides — `official_registry` > `filename` > `content_max_period` — and
  `propagate_vintage_publication_date()` copies the settled date from `source_files` onto every
  table that carries the pair, discovered from the catalogue rather than from a list. **Zero
  disagreements** between `source_files`, the snapshots, 1.2 million facts and the archive
  manifest, enforced by `fact_publication_date_mismatch`.
- The compensatory-FX template tail is no longer read as data. Agosto to Diciembre 2026 have both
  components empty and a cached zero from the sheet's own `=+G+H`; the source goes from 422 to 417
  facts and its availability from 2026-12-31 back to 2026-07-31. A published zero total between two
  reported months, which is what the schema-23 repair exists for, is still read.
- New warning `publication_date_source_contradicts_content` immediately found a second case the
  audit had not seen: `fx_operations` records 2026-07-31 as its content maximum while the content
  reaches 2026-12-31.
- **A release is a lifecycle, not a status string.** `audit.releases` moves `staged` →
  `accepted` | `blocked`, and `v_series_latest`, `series_as_of_date()`, every mart and
  `v_research_series` join through it in SQL. Accepting or blocking is one atomic `UPDATE` and no
  view is rebuilt. Verified: blocking the release takes `v_series_latest` from 1,214,830 rows to 0
  and `series_as_of_date()` from 1,212,070 to 0, while `v_series_latest_all` keeps both for
  diagnostics. `blocked_release_visible` checks the rows *and* lints the stored SQL, because a view
  rewritten without the join would pass every row test.
- **Worksheet merge ranges are retained as published provenance** in `raw.source_sheets`, and they
  settle the SIPAP_12 question the schema-23 note called undecidable. `mergeCell ref="Q2:R2"` says
  columns 17 and 18 are one block; `CUADRO 35` column 12 is in no merge and stays out of scope. The
  published footnote confirms the reading: the five component *Cantidad* columns sum to the
  published TOTAL SPI of 63,735,362 and the five *Importe Destino* columns to 21,232,517,839,313,
  both exactly.
- **The column-recovery window is the published header span.** It used to run only between the
  first and last confident data column, so a headed block outside that span was never examined in
  either direction. The interbank sheets lost three: Call Money Market (PYG) before the first, and
  the Call Money USD *Plazo* and the whole *Facilidad de Crédito Especial* block after the last.
  **647 cells recovered across 113 worksheets, none lost.**
- **Numeric cells outside every parser region are now classified.** `audit.source_region_
  classification` is built from the raw cell layer independently of what the parser emitted, over
  every documented worksheet rather than only those that produced observations. Of the audit's
  73,830 cells: 46,745 `period_axis`, 6,706 `report_layout_derived`, 12,371 `data_not_ingested` and
  7,695 `unreviewed`. The last two block promotion to `validated`; neither blocks the release.
- **A material defect the audit could not see.** Building that register exposed
  `direct_investment`. Cuadro 5 and Cuadro 7 put the year and its four quarters on one header row;
  the year-quarter parser looked for the quarters only *below* the year row, found none, and
  `which.max` over a vector of zeros handed it the first data row as the period header. ALEMANIA's
  1995 balance became a header, all 105 rows across the two sheets were labelled with their own
  values and stamped 2024-12-31 in the single surviving column, and 12,006 published cells were
  never read. The 105 corrupted rows are removed. The 12,006 are recorded as `data_not_ingested`
  rather than recovered: row 10 names the year of each quarter block and row 11 names the year of
  the annual column that closes it, so reading the quarters off row 11 alone dates every one of
  them a year early.

## v23

Third technical audit, roadmap items P0, P1 and P2. The historical audit narrative remains available
through Git history.

Delivered across schema 22 and 23. Every audit figure was re-verified read-only before any
code changed; all of them matched. One diagnosis was right about the symptom and wrong about
the cause, and is recorded rather than worked around.

- **The published interface works again.** Schema 21 moved every table into a storage layer
  while every stored view and macro still named its dependencies bare, so 74 of 74 views and
  all 3 macros raised `Catalog Error: Table with name dim_series does not exist` from any
  connection this project did not open itself -- including `scripts/05_query_helpers.R`, the
  read API the documentation tells researchers to use. Every object is now written through
  `create_project_view()`/`create_project_macro()`. **74 of 74 views and 3 of 3 macros execute
  from a default connection.** They also survive being `ATTACH`ed under an alias, which bare
  `main.` references did not.
- Two release-blocking gates so it cannot recur: `unqualified_object_dependency` reads the
  stored SQL back out of the database and rejects a bare reference; `fresh_connection_object_
  failed` opens a second connection with nothing configured and executes everything. Both run
  in `compact_database.R` before the swap and in `prepare_distribution.R` before a copy ships.
- **Found three more instances of the same defect.** `initialize_database()` asked
  `dbExistsTable("schema_version")` before setting a search path, concluded the database was
  empty and had been **skipping every source-reingesting migration since schema 21**;
  `build_migration_map.R` passed the literal `"main"` as a catalogue name DuckDB calls
  `paraguay_macro_pilot` and could not run at all; and eighteen views owned by a source were
  never rewritten because they are created only during ingestion.
- **Repaired 696 of the 697 recorded parser defects.** The density floor was the common cause:
  a column is now admitted on the header the publisher printed for it rather than on how busy
  it is. That recovers the whole interbank REPO Tripartito block (551 cells, an instrument
  trading on 95 of 3,653 days), the participant that reported once on CCC 02, and the column
  opened in the final month on SIPAP_12. Continuation rows become events with the trade date
  inherited and a positional operation sequence (54 cells); CUADRO 11's compound interval
  labels resolve to effective-dated periods (83); the compensatory-FX block tests activity
  over the columns it actually reads (5). Reconciliation: **241 balanced, 1 unread cell.**
- The audit reported all 605 interbank cells as continuation rows. 551 of them are a published
  instrument block no parser region reached, which no amount of event modelling would have
  recovered. Both causes are repaired; the discrepancy is recorded.
- SIPAP_12 column 18 is **not** repaired: it has no published header of its own, and admitting
  it on a neighbour's inherited label is indistinguishable from CUADRO 35 column 12, which a
  reviewer classified out of scope. One cell, an accurate reason, and the review left standing.
- `canonical.series_period_bounds` stores the opening date of an irregular published interval
  for the 83 observations that have one. The 1.2M fact rows and their key are untouched.
- **Financial-indicator semantics.** Sheets 4 and 7 publish balances and the rest publish
  interest rates over the same portfolio taxonomy, which is why 464 labels recurred. A
  `measure` dimension derived from the published table name now separates them (847 rate, 188
  outstanding amount), and two unit bugs are fixed: a "Volver al índice" navigation link was
  read as the word `indice` on 146 series, and a product name in a row label outranked a unit
  the publisher stated in the title on 363 more. **Rate-labelled series with a non-rate unit:
  0, from 432.** A new `semantic_contradiction` gate holds the line. Labels and identifiers are
  unchanged; the migration map records 84 new identifiers and **zero retired**.
- `governance_note_stale_count` checks numbers written into status notes against the live
  metric they name, which is how "1,636 positional-lane series" survived on a source whose
  count is zero. The prose stays free; only a number followed by a known claim phrase is read.
- `continuity_map` had a table, a storage assignment and a release gate, and **no writer**.
  `apply_continuity_decisions()` and `config/continuity_decisions.csv` now exist. The canonical
  registers still ship empty; `outputs/canonical_core_candidates.csv` generates the candidate
  list a reviewer needs.
- Golden fixtures for **5,034 recovered cells and 1,089 period corrections**, cut by physical
  source-cell comparison and verified back against the raw cell layer. Zero cells the baseline
  read have stopped being read.
- `source_region_incomplete` reports the 73,830 published numeric cells that sit outside every
  parser region -- `balanced` speaks only for cells inside it. Reported, not gated.
- `prepare_distribution.R` ships a copy with workstation paths removed and portable URIs and
  hashes verified. `docs/OPERATIONS.md` gains the client interface, the storage layers, the
  mart split and the defect-state policy.

## v21

Second technical audit, roadmap items P0, P1 and P2. The historical audit narrative remains available
through Git history.

Delivered across schema 15-21. Every audit figure was re-verified read-only before any code
changed; all of them matched. Two of the audit's diagnoses were right about the symptom and
wrong about the cause, and both are recorded rather than worked around.

- Reconciliation resolves the residual cell by cell. `config/reconciliation_cell_rules.csv`
  maps coordinate rectangles to a classification with the worksheet evidence quoted and a
  named reviewer; `reconciliation_cell_classification` records which rule explained which
  cell. A cell matching no rule now blocks the release. Result: 0 unclassified cells across
  all 242 worksheets, and 697 cells of still-unread published data named, documented and
  blocking on 5 of them.
- Fixed the reconciliation's own coordinate bug. `report_cell_values` stores each worksheet
  cropped to its used range; the parsers record A1 coordinates. Joining them untranslated
  reported 13,041 phantom unexplained cells -- most of the audit's 18,883. `v_report_cells_a1`
  is now the only correct way to join the layers.
- Repaired five parser defect families the classification exposed, recovering **4,338
  observations**: footnote-marked month labels (CUADRO 59 +480, CUADRO 55 +229), late-starting
  data columns (CUADRO 17, SIPAP_04), the month-year spellings `mar.-19`, `sept-25` and
  `dic- 19*`, and text day-month-year labels (bcp_fx_daily +108). The `sept` spelling had also
  been mis-dating 867 `financial_indicators` observations by a month and forking them onto
  1,636 positional lanes; both are gone.
- Split the marts. `v_mart_<x>_all` carries the data; `v_mart_<x>` carries only validated,
  reconciled rows and all seven are empty. Fixed the tautological `d.source_sheet =
  d.source_sheet` join, added `vintage_id` to the reconciliation join, applied exact-over-
  wildcard status precedence, and rebuilt `v_research_series` as one row per series.
- Added `parser_claim` to `table_status` and `validate_governance_drift()`, which checks the
  claim against this release's reconciliation in both directions. Corrected the eight stale
  Annex notes. A database CHECK now enforces reviewer, date and evidence on a validated row.
- Made identity resolution fail closed: `v_series_id_scalar_resolution`, `resolve_series_id()`
  and `resolve_series_ids()`. All 36 one-to-many and 15,096 retired identifiers resolve to
  NULL; canonical membership refuses an ambiguous identifier.
- Added `series_semantic_evidence`: `stock_flow`, `valuation`, `transformation`,
  `nominal_real` and `seasonal_adjustment` are derived only where the publisher states the
  answer in words, and `v_series_measurement` publishes the basis beside every field. 1,822
  fields have a value, none of them claiming review.
- Added `series_dimension`: `trade_flow`, `trade_classification`, `trade_regime` and `product`
  for the eight detailed trade worksheets, derived from the published title and label. The
  eight sheets moved from `needs_remodeling` to `provisional`.
- Strengthened compaction from row counts to content equivalence: every table as a multiset in
  both directions with `EXCEPT ALL`, plus column definitions, view SQL, constraints, indexes,
  sequences and macros. `docs/SCHEMA_MIGRATIONS.md` is now generated from the migration
  registry the invalidation steps read, so the runbook cannot drift from the database again.
- Moved every table into a storage layer -- `raw`, `staging`, `canonical`, `audit` -- and
  published the research interface under `marts`. Nothing remains in `main`. A search path set
  on every connection keeps unqualified names resolving.
- Moved the fact grain onto BIGINT surrogate keys, keeping the human identifiers on the row
  and unique in the dimensions. The compacted database is **243.3 MiB, down from 309.7 MiB**
  with 4,338 more observations in it.
- Added repository-relative `source_uri` and `archive_uri`; the 22 absolute `/Users/...` paths
  are no longer the durable identity of anything.

Not delivered, and reported as blocked: the canonical and methodology registers (they require
a named economist), the remaining 3,946 unresolved units (the sources do not state them), the
interbank event grain (it needs a modelling decision), and a second real vintage (no newer BCP
publication exists).

## v14

P1 and P2 of the external technical audit. The historical audit narrative and regression register
remain available through Git history.

- Bounded the horizontal period axis at the last header cell that parses as a period. The fill-right loop ran to the last column of the worksheet, so the seven interannual comparison columns on each foreign-trade sheet inherited the last real period; 6,962 spurious observations, all dated 2026-07-01, are gone and no real value moved.
- Kept bare provisional-data markers out of series identity. A `*` published over the most recent 24 months was read as a sub-header and cut every product series in two at 2024-08; 22,228 marker-suffixed labels became 0 and `Soja` is one series again. The marker is retained on the observation in `footnote_marker`.
- Added `config/table_domains.csv`, `table_domains` and `v_series_domain`: an economic domain, subdomain and measure family for all 94 Annex worksheets, recorded as unreviewed.
- Derived `unit_code` and `scale_multiplier` on `dim_series` from the published unit and scale, and created `stock_flow`, `nominal_real`, `seasonal_adjustment`, `transformation` and `valuation` at `not_reviewed` rather than filling them by inference; `outputs/semantic_metadata_completeness.csv` reports the coverage.
- Added `v_series_observations` with `period_start`, `period_end`, `available_at`, `observation_status` and `value_in_base_units`, plus the `series_as_of_date(as_of)` interface. `period` itself is untouched, so no observation key moved.
- Added `canonical_series`, `map_canonical_series`, `methodology_regime` and `classification_concordance` with guarded reviewer-facing configuration; canonical identifiers are assigned by a reviewer and cannot be reused from a parsed `series_id`.
- Added seven Annex marts by domain, a coverage dashboard, the section 11 P2 gap, discontinuity and cross-source screens, and `series_grain` so auctions, trades, curve nodes and entity panels are counted separately from scalar macro series.
- Added release-blocking anti-join and natural-key integrity checks in place of declared foreign keys, which the DELETE-then-append curation path cannot support.
- Added `compact_database.R` and `docs/DATABASE_STORAGE.md`. The file never shrinks on its own: a run writes replacement blocks before releasing the old ones, so it grows to each run's high-water mark and keeps the freed blocks on an internal free list. Ten runs during this round left 254 MiB of free space in a 555 MiB file. Compaction copies every object into a fresh file and swaps it in only after verifying every table, row count, view, macro, constraint and schema version is identical.

## v13

P0 of the external technical audit. The historical audit narrative and regression register remain
available through Git history.

- Added `series_id_migration`, `source_alias` and `continuity_map`, the operator entry point `build_migration_map.R`, and `v_series_id_resolution`, which resolves any identifier the project has ever published to its current series or an explicit retirement. Resolution is transitive across releases; three hops are recorded and no published identifier is left without an outcome.
- Repaired the credit-survey question-header test. It required a header row to carry no values, but nine of the 73 header rows carry a stray numeric and one is published without a dash after the question number, so each of those headers was consumed as a response of the previous question and the following block inherited the wrong question. 50 positional identities, 25 conflicting question/response groups and 5 spurious one-observation series went to zero; 24 stray cells stopped being read as survey responses.
- Added `table_reconciliation` and `config/reconciliation_exclusions.csv`: per worksheet, the numeric source cells reconciled against accepted observations, recorded discards and reviewed exclusions. Cell reuse is zero across all 242 worksheets.
- Added six evidence columns to `table_status`; a `validated` row now requires definitions, units, timing, hierarchy and methodology to be answered individually and the worksheet's cell accounting to balance.
- Enforced the observation grain: `fact_series_events` gained `PRIMARY KEY (series_id, period, vintage_id)` and NOT NULL on its key columns.
- Added the section 11 P0 release gate and made it block. An error-severity flag now sets the run to `release_blocked` and `run_update.R` exits non-zero, where the pipeline previously recorded errors and continued.
- Added golden source-cell signatures for the four repaired parser families.

## v12

P0 parser and identity repairs from the external technical audit. The historical audit narrative and
per-defect register remain available through Git history.

- Bounded each compensatory-FX year block at the next year header in its own column; 36 lane series became 3 measures with zero conflicting months.
- Made the worksheet slug inside `series_id` a pure function of the sheet name; it was uniquified by position, so an inserted column reassigned the identity of every later series in that sheet.
- Added `continuation_group` to `config/sheet_modes.csv` so worksheets that are chronological continuations of one series share an identity while keeping per-sheet lineage; `bcp_fx_daily` went from 168 series to 12.
- Derived period-axis orientation from a single helper so a horizontal parser cannot inherit a column slot; the credit survey lost 2,534 one-observation identities.
- Computed the EVE block and label slugs before `tibble()` so `slug()` no longer sees the materialized column; 2,760 series became 16.
- Added a table-specific `CUADRO 61` parser with a two-level row hierarchy, header guards and an ambiguity guard; 170 numeric-label lane identities became 182 semantic series with a perfect source-cell balance.
- Added `config/table_status.csv`, `table_status`, `v_series_table_status` and `v_research_series` so the generic catalogue is not exposed as research-ready, plus a release-blocking `table_status_incomplete` check.
- Added schema 12 with targeted reingestion of every documented source plus EVE, and cleared `discarded_rows` during invalidation so a re-ingested vintage no longer aborts on its content-addressed primary key.

## v11

- Separated fresh schema bootstrap from versioned data migrations so a new database never executes historical invalidation code.
- Fixed selective concept cleanup in the v9-to-v10 repair and retained unrelated source-specific concepts.
- Expanded legacy `dim_series` tables before migration queries, including the v2 compatibility fixture.
- Added strict annotated-year recognition and ordered-sequence scoring for row and column time axes.
- Added a real `CUADRO 58` regression that excludes false 2033–2098 periods.
- Added selective v10-to-v11 Annex reingestion, dynamic bank-header row accounting and a current v1-to-v11 entry point.

## v10

- Excluded Annex annotation/percentage rows from vertical date axes while allowing the reviewed official projection horizon.
- Rebuilt historical exchange-rate parsing around every consecutive-year block with verified Compra/Venta headers.
- Represented XML-empty formula views with zero content bounds and made all semantic matrix helpers 0 × 0 safe.
- Fixed DuckDB continuity aliases and added an executable two-vintage regression.
- Added canonical deposit/repo block identity to liquidity events and excluded semantic dimensions from measure observations.
- Added selective v9-to-v10 reingestion, a current v1-to-v10 migration entry point and reconstructed regression-audit documentation.

## v9

- Fixed named-table XML discovery by reading the root `<table>` node, restoring all 15 bank/finance reference tables.
- Made empty/formula-only worksheets produce a typed zero-row raw-cell table and hardened exchange-house date propagation.
- Added shape-preserving matrix predicates for regex/equality anchor searches.
- Added the BCP `set` month alias; quarter parsing now rejects naked digits and infers a missing quarter only inside a validated Q1--Q4/annual block.
- Preserved hierarchical credit-survey subquestions such as `10,1` and corrected direct-investment annual/quarter column boundaries.
- Added semantic row-event parsers for interbank operations, LRM tenors and liquidity auctions. Genuine same-day duplicates use deterministic positional lanes that never hash observed values and are explicitly marked `identity_stability = positional_lane`.
- Moved workbook discovery and metadata registration inside per-source failure isolation; a corrupt workbook is persisted as failed while later sources continue.
- Added v8-to-v9 reingestion invalidation, real-file regression tests and a v1-to-v9 migration entry point.

## v8

- Vectorized unit, scale, currency, index-base and total inference over distinct semantic keys while preserving source-specific overrides.
- Replaced per-observation one-row tibbles and growing-list function round trips with lightweight direct record assignment; vectorized the horizontal year-month grid.
- Calculated documented-series hashes once per unique worksheet/path/frequency identity and payment BIC matches once per unique series path.
- Reused one worksheet read for raw content-addressed storage and semantic parsing, eliminating the second full Excel pass for `semantic_table` sources.
- Cached sheet-mode and source-contract configuration with file-change invalidation.
- Added schema-v8 source/stage timings and `outputs/ingestion_stage_timings_latest.csv`.
- Added performance-equivalence tests against the v7 scalar metadata rules and identity contract.

## v7

- Removed inferred unit and currency from documented-series identity; exposed `identity_basis` and `identity_stability`.
- Added prior-vintage series continuity, disappearance thresholds and unit/scale/currency drift errors.
- Added configuration-driven sheet modes, hierarchy-status warnings and coherent non-monetary scales.
- Added 12 sources: ten Excel report sources and two guarded long-format market CSVs.
- Added typed bond-curve and securities-transaction tables plus latest and daily-activity views.
- Added active-cell bounds for every worksheet, chartsheet filtering and a repeated date-block parser for liquidity operations.
- Added registry-derived smoke-test source counts, expanded contracts and a v1-to-v7 migration entry point.

## v6

- Added `dim_concept`, `map_series_concept`, and audited concept views without automatic cross-source equivalence.
- Added guarded reviewed mappings through `config/concept_mappings.csv`.
- Added per-sheet prior-vintage drift diagnostics and `outputs/documented_sheet_drift_latest.csv`.
- Added bounded and occurrence-aware anchor lookup for repeated labels.
- Added a current v1-to-v6 migration entry point and updated compatibility aliases.

## Version 5

- Converted the four remaining inventory-only sources into guarded documented-series sources.
- Added reusable parsers for eight recurring Annex/payment table orientations and specialized credit-survey and exchange-house parsers.
- Added `documented_series_snapshot`, `documented_table_catalog`, `dim_payment_participant` and `dim_exchange_item`.
- Added latest-source views for the Annex, payments, exchange houses and credit survey plus a documented-series catalogue.
- Added source contracts, key-series/unit/entity/range validations, parser-helper tests and full-pipeline coverage assertions.
- Added v4-to-v5 reingestion invalidation and the then-current version-5 upgrade entry point. That
  obsolete compatibility entry point was removed in the 2026-09-03 repository cleanup; its history
  remains in Git.
- Retained ambiguous units as explicit `source_units` review items rather than inferring harmonized semantics.

## Version 4

- Corrected code 6200 from a false USD interpretation to foreign-currency origin measured in PYG.
- Added `currency_of_origin` and `unit_currency`; retained `economic_currency` only as a corrected deprecated alias.
- Added currency-description consistency validation.
- Replaced brittle exact growth-series counts with minimum baselines and prior-vintage shrinkage checks.
- Changed reference resolution from autogenerated Excel display names to worksheet-plus-column signatures.
- Forced reference cells to text and added raw/canonical account identifiers plus scientific-notation guards.
- Replaced full-copy report-cell ingestion with content-addressed sheet versions and vintage links.
- Added a compatibility view and non-destructive v3 legacy migration for report cells.
- Added schema version 4, migration tests and expanded documentation.

## Version 3

- Fixed worksheet relationship resolution for all workbooks.
- Fixed direct-source schema filtering for bank versus finance-company inputs.
- Standardized report reading on list cells to preserve mixed Excel types.
- Added Excel-epoch and defensive character date conversion.
- Added hard semantic-date plausibility guards.
- Made YAML loading locale-independent with explicit UTF-8.
- Added `publisher`, `source_format` and separate `scale` metadata.
- Added automatic invalidation/reingestion of defective v2 ICC, EVE and FX content.
- Added a version-1-to-version-3 migration and retained the old v2 filename as an alias.
- Added the bank/finance reference workbook as a required, versioned source.
- Added verified entity, currency, statement, ratio, portfolio, account and credit-activity dimensions.
- Added ten documented bank/finance views and mapping-coverage checks.
- Added exact reference-table count/structure tests and a full real-workbook smoke test.
- Corrected FX content-based publication-date inference to use the latest observed month.
- Expanded README, data model, architecture, operations, feedback and verification documentation.

## Version 2

- Added strict structure guards for direct and curated sources.
- Added deterministic content identities, deduplicated archives and consultable vintages.
- Added full snapshots, sparse change/removal events, as-of queries and revision history.
- Expanded FX operations to annual, quarterly and monthly data with subtotal checks.
- Added source transactions, discarded-row records and explicit semantic coverage.
- Added archive reconstruction and review-required semantic spec skeletons.

## Version 1

- Initial folder-based source resolver, raw archive, XML dimension detection, direct tables and three curated parsers.
