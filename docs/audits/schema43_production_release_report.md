# Schema 43 controlled production release report

Release attempt date: 2026-09-14  
Run identifier: `schema43_20260914_180157`  
Pre-release Git commit: `98370c2c26f8162401cf6e0e3eb3019ef7f687c1`  
Decision: **NO-GO — REJECTED; schema 43 was not promoted**

## Final active release

| Field | Final state |
|---|---|
| Active database | `database/paraguay_macro_pilot.duckdb` |
| Schema version | 41 |
| Active build | `build:57fe1ff64fb654508b2a8f0a` |
| Active source bundle | `release:748d41036c3a73638a1c2086` |
| SHA-256 before attempt | `17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180` |
| SHA-256 after attempt | `17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180` |
| Promotion performed | No |

The active pointer still resolves to the accepted schema-41 build above. The production file was
never opened for writing, no swap marker was entered, and no schema-43 artifact was renamed over
the production path.

## Artifacts and frozen evidence

| Artifact | Role | SHA-256 |
|---|---|---|
| `/private/tmp/schema43-lineage-final.JPitWw/paraguay_macro_schema43_candidate.duckdb` | Reported isolated lineage-fix candidate | `586f2e7af80d54316d45233f1532d03d6f6846d279316d194fa5dbc1d1c26dd8` |
| `/private/tmp/paraguay-exploratory-schema43.60oOOT/paraguay_macro_schema43.duckdb` | Pre-fix schema-43 comparison artifact | `23d8feacf1492fc2847d05c5e5f55342f97265f525342a1a76696a7c1af0a015` |
| `database/candidates/blocked_20260914_180218.duckdb` | Official isolated build, rejected and retained | `e31e444a4ca79cb18f9bc322391562d553a28b179c6cf10e3037b881cb61169b` |
| `database/releases/schema43_20260914_180157/schema41_base.duckdb` | Byte-identical frozen incumbent / rollback evidence | `17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180` |

The run-specific directory contains:

- `blocked_release_manifest.json`: build identity, environment, source manifest, decision, hashes,
  reconciliation summary, and the reason later gates were not run;
- `source_input_manifest.csv`: all 24 files selected by the authoritative manifest with their
  vintage IDs, SHA-256 hashes, paths, sizes, publication dates, and ingestion status;
- `verification_results.txt`: independent read-only lineage, logical-diff, interface, decision,
  and active-pointer results;
- `evidence/`: the official update report, quality flags, timings, provenance worklists,
  reconciliation, coverage, drift, and continuity outputs produced by the blocked run;
- `verify_release.R`: the read-only verification script used to reproduce the database checks.

## Release gates and outcomes

### 1. Lineage report evidence

**Outcome: the lineage fix itself passed; the production-release equivalence condition did not.**

- Both supplied hashes matched independently: reported schema-43 candidate
  `586f2e7a…c26dd8` and incumbent schema 41 `17e0a825…b180`.
- The reported candidate contains exactly 39,543 correction rows across 27 candidates: 37,800
  observations across 12 `bcp_fx_daily` candidates and 1,743 observations across 15
  `financial_indicators` candidates.
- All 957,627 scalar exploratory observations joined to the matching documented staging natural
  key with 0 worksheet disagreements, 0 title disagreements, 0 value disagreements, and 0 row or
  column disagreements.
- All 39,543 corrected rows joined to `main.v_report_cells_a1` with 0 missing raw cells and 0
  numeric disagreements at `1e-8 * greatest(1, abs(value))` tolerance.
- The 12 BCP FX profiles each represent 14 worksheets with
  `complete_multiple_worksheets`; the 15 financial-indicator profiles each represent exact sheet
  `8` with `complete_single_worksheet`.
- Against the pre-fix schema-43 artifact, bidirectional `EXCEPT ALL` found 0 changes in canonical
  facts, canonical dimensions, table statuses, `main.v_series_latest`, every `research.*` data
  view (excluding only the documented operational `updated_at` field), and every shared
  non-lineage catalogue/exploratory field. This confirms that the reported correction is limited
  to worksheet-lineage fields and their explicit diagnostics.
- Catalogue and exploratory integrity passed on the reported candidate: 13,985 unique profiles,
  no orphan profiles, and no duplicate keys, malformed rows, or orphan rows across
  `explore.observations`, `explore.events`, `explore.panel_observations`, and
  `explore.curve_observations`.

The reported schema-43 artifact is not strictly identical to the incumbent schema-41
`research.*` surface because it also contains the previously reviewed schema-42 EEFF restoration:
`research.entity_panel` adds four currency fields and restores 239,528 rows over the shared
columns; `research.dataset_catalog` also has two additional registered datasets. Those are
unchanged between the pre-fix and corrected schema-43 artifacts, but they are differences from the
schema-41 incumbent and therefore cannot be described as effects of the lineage correction.

### 2. Git and pre-release state

**Outcome: passed.**

The working tree was clean before the attempt on branch `empirical-readiness-schema-39`, at commit
`98370c2c26f8162401cf6e0e3eb3019ef7f687c1` (three commits ahead of its configured upstream).
There were no unrelated dirty-tree changes to preserve. The blocked run's generated date-only
rewrite of `docs/SCHEMA_MIGRATIONS.md` was restored to its exact pre-run content. The retained
release directory, blocked candidate, and this report are new release evidence.

### 3. Official isolated release build

**Outcome: failed and rejected by the official release gate.**

The authoritative loader and normal pipeline were used. The environment check passed against
`renv.lock` under R 4.5.1. The build ran against a byte-identical incumbent copy in the new
run-specific directory. Its recorded identity is:

| Field | Value |
|---|---|
| Build | `build:43303bc15d28971e37dfd49f` |
| Source bundle | `release:549669d609b3dc600b81b9bf` |
| Attempt | `attempt:f3811e32fe3f4f71a7921548` |
| Schema | 43 |
| Decision | `blocked` |
| Errors | 1 |
| Warnings | 40 |
| Decision timestamp | `2026-09-14 21:05:30` UTC |

The blocking error was `new_vintage_provenance_incomplete`: **2 non-legacy vintages lack mandatory
acquisition metadata**. The authoritative current manifest selected and ingested:

- `cda_curve:8796a589fc2bd31317efdce7` from `Curva_CDA.xlsx`;
- `tcn_referential_daily:74df666397a33b9c8cdfac10` from
  `TCN_Referencial_Diario.xlsx`.

Neither vintage has the mandatory acquisition record required for a non-legacy vintage. No
metadata, parser, schema, semantic, or admission-control change was made to bypass the gate.

### 4. Full release suite, binding, reconciliation, and final diff

**Outcome: stopped after gate 3 failed, as required.**

The official pipeline completed its release-wide validation and recorded no additional
error-severity checks; its fresh-connection and source reconciliation checks therefore raised no
release error. The retained reconciliation evidence is in the run directory. The separate full
regression suite and post-acceptance promotion checks were not run because the instruction requires
the release to stop on the first failed gate.

A read-only final diff was still run to characterize the rejected build and verify isolation. The
two newly selected sources added 28,858 canonical fact rows and 501 canonical series identities to
the blocked file. No incumbent canonical row was removed. Because the blocked file's active pointer
remained on schema 41, `main.v_series_latest` exposed none of those rows. This population change is
outside the authorized lineage-only release scope even apart from the missing-provenance error.

### 5. Failure isolation

**Outcome: passed.**

The product decision `build:43303bc15d28971e37dfd49f` is recorded as `blocked`; the candidate was
renamed to `database/candidates/blocked_20260914_180218.duckdb` and retained with all generated
evidence. The actual production database and active pointer remained unchanged.

## Final differences from schema 41

There are **no final active-release differences** because no promotion occurred. The active
database remains the same schema-41 bytes and build.

The rejected schema-43 build differs from schema 41 by the planned schema-42/43 interfaces and by
the unintended-for-this-release activation of the two current input sources described above. The
reported lineage-fix candidate, when compared with its pre-fix schema-43 base, is limited to the
39,543 exploratory worksheet-lineage corrections and explicit lineage diagnostics. The official
production build cannot receive that confirmation because its source population changed.

## Rollback

No rollback action is needed because no swap occurred. The exact frozen rollback artifact is
`database/releases/schema43_20260914_180157/schema41_base.duckdb`, SHA-256
`17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180`; it is byte-identical to the
still-active `database/paraguay_macro_pilot.duckdb`.

If production were later found missing or damaged independently of this attempt, stop readers,
verify that frozen artifact's SHA-256, move the damaged file aside, place a copy of the frozen
artifact at `database/paraguay_macro_pilot.duckdb`, restore its matching sidecar hash, and confirm in
a fresh read-only connection that `audit.active_data_release` names
`build:57fe1ff64fb654508b2a8f0a`. That procedure was not executed in this run.

## Reproduction commands

From the repository root, the official isolated attempt was run with:

```sh
Rscript --vanilla -e 'root <- normalizePath(getwd(), winslash="/", mustWork=TRUE); source(file.path(root,"scripts","load_project.R")); load_project_scripts(root, profile="pipeline"); check_environment(root, strict=TRUE); ensure_dirs(root); registry <- readr::read_csv(file.path(root,"config","source_registry.csv"), show_col_types=FALSE); resolved <- build_current_manifest(registry, root); result <- run_isolated_update(root, registry, resolved$manifest, resolved$issues, production=file.path(root,"database","releases","schema43_20260914_180157","schema41_base.duckdb")); dput(result)'
```

The independent read-only verification is reproduced with:

```sh
Rscript --vanilla database/releases/schema43_20260914_180157/verify_release.R
```
