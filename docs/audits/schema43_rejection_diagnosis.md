# Schema 43 rejection diagnosis

Audit date: 2026-09-14  
Rejected artifact: `database/candidates/blocked_20260914_180218.duckdb`  
Artifact SHA-256: `e31e444a4ca79cb18f9bc322391562d553a28b179c6cf10e3037b881cb61169b`  
Artifact size: 454,307,840 bytes  
Build: `build:43303bc15d28971e37dfd49f`  
Source bundle: `release:549669d609b3dc600b81b9bf`  
Decision: **blocked; do not promote**

Unless shown as an external absolute path, file paths below are relative to
`/Users/juanmanuelgonzalezmasulli/Documents/Paraguay_Macro_Database`.

## Conclusion

The rejected build selected two source vintages that were absent from both the frozen schema-41
incumbent and the reviewed lineage-fixed schema-43 candidate:

1. `cda_curve:8796a589fc2bd31317efdce7`; and
2. `tcn_referential_daily:74df666397a33b9c8cdfac10`.

Both lack a matching row in `config/source_vintages.csv`. The resulting
`raw.source_provenance` rows have null acquisition fields, and the executable release gate raised
`new_vintage_provenance_incomplete`. Together the vintages added 28,858 canonical fact rows and
501 canonical series identities. No incumbent canonical row was removed.

The parsers produced exactly the populations asserted by the real-workbook tests: 21,854 rows and
471 series for CDA, and 7,004 rows and 30 series for TCN. The additions therefore are **expected
source expansion at parser level, but accidental ingestion relative to the authorized schema-43
release scope**. The prior acceptance review expressly required any CDA/TCN activation to be
reconciled instead of attributed to the lineage-only candidate. Neither population may be admitted
merely by filling plausible metadata.

Production was not changed. The frozen incumbent and the production file are still byte-identical:

| Artifact | SHA-256 | Bytes |
|---|---|---:|
| `database/releases/schema43_20260914_180157/schema41_base.duckdb` | `17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180` | 418,918,400 |
| `database/paraguay_macro_pilot.duckdb` | `17e0a825c7279da6bacff5fdee31b008bc936432f69ff796462004eaa876b180` | 418,918,400 |

The active pointer in all inspected artifacts remains
`build:57fe1ff64fb654508b2a8f0a` / `release:748d41036c3a73638a1c2086`, schema 41.

## Governing provenance condition

`scripts/12_platform.R::validate_platform_contracts()` treats a provenance row as a non-legacy
vintage unless `retrieval_method = 'archive_ingest_upper_bound'`. For a non-legacy row it requires
all seven of these fields to be nonblank:

- `official_release_date`;
- `official_url`;
- `release_identifier`;
- `retrieved_at`;
- `retrieval_method`;
- `license`; and
- `evidence`.

Both new rows are missing all seven. Their derived `available_at` and `availability_quality` are
also null. Because no matching registry row exists, `original_filename` is also absent from the
operator-maintained acquisition register even though the filename is preserved independently in
`raw.source_files`, the release source manifest, the archive manifest, and the Git LFS pointer.

There are two documentation/evidence inconsistencies that a repair must not hide:

- `docs/ACQUISITION_RUNBOOK.md` says `official_release_date` may be blank when the publisher states
  none, but the executable non-legacy gate requires it. Executable behavior is the current gate.
- `evidence/source_provenance_worklist.csv` lists `available_at`, URL, release identifier,
  retrieval timestamp, and retrieval method for these rows, but omits the gate-required
  `official_release_date`, `license`, and `evidence`. The release error is therefore broader than
  the worklist wording.

Neither discrepancy authorizes weakening the gate or inventing a date, licence, or provenance
statement.

## Vintage 1: CDA curve

### Exact bytes and ingestion route

| Field | Exact value |
|---|---|
| Source ID | `cda_curve` |
| Vintage ID | `cda_curve:8796a589fc2bd31317efdce7` |
| Source file | `Curva_CDA.xlsx` |
| Input path | `input/current/Curva_CDA.xlsx` |
| Immutable archive path | `input_archive/cda_curve/8796a589fc2bd31317efdce7865d4598473fdacd048cf04b676dc8f78e2b144c.xlsx` |
| SHA-256 | `8796a589fc2bd31317efdce7865d4598473fdacd048cf04b676dc8f78e2b144c` |
| Size | 4,505,245 bytes |
| Manifest publication date | `2026-07-31` |
| Publication-date basis | `content_max_period` — not an official availability fact |
| Archive-manifest timestamp | `2026-09-14T21:02:26Z` — archive upper bound only |
| Registry route | `config/source_registry.csv`: `input/current`, `^Curva_CDA\.xlsx$`, `allow_multiple=FALSE`, `selection_rule=manifest`, `ingest_mode=semantic_table`, `semantic_status=documented_series`, `required=TRUE` |
| Parser route | authoritative loader `scripts/load_project.R` → `scripts/06_pipeline.R::run_manifest_pipeline()` → `scripts/03_curate_special.R::ingest_curated_source()` → `scripts/03_curate_documented.R::documented_source_parser()` → `documented_parse_cda_curve_sheet()` |
| Parser/input contract | `config/documented_source_contracts.csv`: exactly 412 sheets, minimum 412 parsed sheets, minimum 10,000 observations, minimum date `2018-01-01`, maximum 400 series disappearances, and eight named required sheets |

The current file, archived file, release manifest, database `raw.source_files` row, and Git LFS
pointer all agree on the full SHA-256 and byte count.

### Missing metadata and local evidence

Missing mandatory fields: `official_release_date`, `official_url`, `release_identifier`,
`retrieved_at`, `retrieval_method`, `license`, and `evidence`. Derived `available_at` and
`availability_quality` are consequently missing as well.

Local evidence is sufficient for the exact bytes, filename, hash, byte count, source-content
maximum date, and archive time. The workbook properties name BCP-associated authors, show an
internal modification time of `2026-08-17T14:45:02Z`, and retain internal `bcp027` file links.
Those are useful origin clues, not a publisher release record, public URL, release identifier,
licence, or acquisition timestamp. File modification time is not an admissible substitute under
the project contract.

**Authoritative evidence does not exist locally to complete the mandatory acquisition record.**
The local archive timestamp can support only a conservative `archive_ingest_upper_bound` if the
vintage is explicitly governed as a legacy/current snapshot; it cannot prove when the file was
downloaded or first published.

### Population difference and affected identities

| Object/population | Before | Rejected build | Difference |
|---|---:|---:|---:|
| `raw.source_files` vintages | 0 | 1 | +1 |
| `main.report_cells` retained nonempty cells | 0 | 49,813 across 412 sheets | +49,813 |
| `staging.documented_series_snapshot` rows | 0 | 21,854 | +21,854 |
| `canonical.dim_series` identities | 0 | 471 | +471 |
| `canonical.fact_series_events` rows | 0 | 21,854 | +21,854 |
| `catalog.series` candidate rows in the blocked file | 0 | 471 | +471 |
| Current observations in `catalog.datasets` | 0 | 0 | 0 |
| `explore.curve_observations` under the unchanged active pointer | 0 | 0 | 0 |
| `research.*` data rows | 0 | 0 | 0 |

Affected dataset identity: `dataset_id = source_id = 'cda_curve'`, grain `curve_panel`, assurance
`provisional`, point-in-time status `forward_collection_required`, access route
`catalog.series` / `catalog.profile(candidate_id)` and, only after an accepted source bundle,
`explore.curve_observations`.

The 471 candidate identities are exactly the 471 new `canonical.dim_series.series_id` values, and
each equals its `catalog.series.candidate_id`. They split into:

| Identity family | Candidates | Fact rows | Period range |
|---|---:|---:|---|
| `cda_curve:cda_operations_curve:<24-hex>` | 243 | 14,553 | `2018-01-31` to `2026-07-31` |
| `cda_curve:cda_rate_curve:<24-hex>` | 228 | 7,301 | `2018-01-31` to `2026-07-31` |

The operation identities contain 114 `CANTIDAD DE OPERACIONES`, 115 `VOLUMEN CAPTADO`, and 14
explicit anomalous `Monto Capital Original` candidates; the rate family contains 228
`TASA PONDERADA` candidates. This is the parser's governed retention behavior, including unresolved
publisher cells rather than silent deletion.

For an exact compact fingerprint, sort the complete candidate IDs bytewise, join them with `\n`,
and retain one trailing `\n`: SHA-256
`6624edf9f190bb9edb123338b6fcb15e8c1277fbc8dfed38cef3d1b9d1753730`.
For the sorted canonical fact natural keys
`series_id|YYYY-MM-DD|vintage_id` under the same newline convention: SHA-256
`50c7a09d29f94f92806a5a214fb05c6d311a8f3a862333bb5aea7398ecba378c`.
The reproduction query at the end emits every full identity rather than abbreviating the 471-row
set in prose.

### Classification and minimum safe remedy

**Classification:** expected source expansion at parser level; accidental ingestion into this
release. The exact 21,854/471/412 counts are asserted by the real-workbook smoke test, and the
source-specific parser, contracts, status, grain, and acquisition contract show deliberate
onboarding. The schema-43 acceptance review, however, authorized a candidate with no CDA vintage
and required any later activation to be separately reconciled.

Minimum safe remedy:

- If CDA is in scope, obtain official/source-owner evidence tied to these exact bytes for the
  release page, issue identifier/date, acquisition time/method, and licence; record only what that
  evidence supports, then obtain an explicit source-population decision before rebuilding.
- If actual retrieval time is irrecoverable, classifying this hash as a legacy current snapshot
  with the archive time as an inferred upper bound is honest but **requires an explicit governance
  and scope decision**; it is not a mechanical way to bypass the non-legacy gate.
- If CDA is out of scope, exclude it through a governed release-input selection mechanism. Do not
  delete or rename the source, rewrite its archive identity, or rely on filesystem absence.

Remedy classification: evidence collection is **requiring official/source-owner evidence**;
include/exclude or legacy-snapshot treatment is **requiring the user's explicit scope decision**;
entering a reviewed record and rechecking exact hashes afterward is **mechanical and safe to
implement**, but only after those dependencies are satisfied.

## Vintage 2: TCN referential daily

### Exact bytes and ingestion route

| Field | Exact value |
|---|---|
| Source ID | `tcn_referential_daily` |
| Vintage ID | `tcn_referential_daily:74df666397a33b9c8cdfac10` |
| Source file | `TCN_Referencial_Diario.xlsx` |
| Input path | `input/current/TCN_Referencial_Diario.xlsx` |
| Immutable archive path | `input_archive/tcn_referential_daily/74df666397a33b9c8cdfac10d7ffedd23acf7cbd5907ea21332e100fb939c0a4.xlsx` |
| SHA-256 | `74df666397a33b9c8cdfac10d7ffedd23acf7cbd5907ea21332e100fb939c0a4` |
| Size | 117,740 bytes |
| Manifest publication date | null |
| Publication-date basis | `pending_content_inference` |
| Archive-manifest timestamp | `2026-09-14T21:04:29Z` — archive upper bound only |
| Registry route | `config/source_registry.csv`: `input/current`, `^TCN_Referencial_Diario\.xlsx$`, `allow_multiple=FALSE`, `selection_rule=manifest`, `ingest_mode=semantic_table`, `semantic_status=documented_series`, `required=TRUE` |
| Parser route | authoritative loader `scripts/load_project.R` → `scripts/06_pipeline.R::run_manifest_pipeline()` → `scripts/03_curate_special.R::ingest_curated_source()` → `scripts/03_curate_documented.R::documented_source_parser()` → `scripts/03_curate_expanded.R::documented_validate_daily_calendar_grid_workbook()` and `documented_parse_daily_calendar_grid()` |
| Parser/input contract | `config/documented_source_contracts.csv`: exactly 30 sheets, minimum 30 parsed sheets, minimum 7,000 observations, minimum date `2012-08-06`, maximum 400 series disappearances, and six named required sheets |

The current file, archived file, release manifest, database `raw.source_files` row, and Git LFS
pointer all agree on the full SHA-256 and byte count.

### Missing metadata and local evidence

Missing mandatory fields: `official_release_date`, `official_url`, `release_identifier`,
`retrieved_at`, `retrieval_method`, `license`, and `evidence`. Derived `available_at` and
`availability_quality` are consequently missing as well.

Local evidence is sufficient for the exact bytes, filename, hash, byte count, archive time, and
the workbook's content range through `2026-08-25`. It is not sufficient to establish an official
publication. The workbook package says it was created and last modified by Juan Manuel Gonzalez
Masulli at `2026-08-26T11:38:38Z` and retains an absolute personal BCP SharePoint path under
`.../Paraguay_Database/Public/`. These facts indicate a locally assembled or re-saved workbook;
they are not an official public release page, a publisher-issued identifier, a licence, or proof
that the 30-sheet aggregation is itself an official BCP artifact. The smoke-test dates and URLs are
explicitly synthetic test-only provenance and cannot be reused.

**Authoritative evidence does not exist locally to complete the mandatory acquisition record or
to establish that this exact aggregate workbook is publisher-issued.** Source-owner evidence is
required to document how it was created, the official inputs from which it was assembled, and what
publication/licence claims are valid. If an official reacquisition produces different bytes, it is
a different vintage and must not be substituted under this hash.

### Population difference and affected identities

| Object/population | Before | Rejected build | Difference |
|---|---:|---:|---:|
| `raw.source_files` vintages | 0 | 1 | +1 |
| `main.report_cells` retained nonempty cells | 0 | 12,510 across 30 sheets | +12,510 |
| `staging.documented_series_snapshot` rows | 0 | 7,004 | +7,004 |
| `canonical.dim_series` identities | 0 | 30 | +30 |
| `canonical.fact_series_events` rows | 0 | 7,004 | +7,004 |
| `catalog.series` candidate rows in the blocked file | 0 | 30 | +30 |
| Current observations in `catalog.datasets` | 0 | 0 | 0 |
| `explore.observations` under the unchanged active pointer | 0 | 0 | 0 |
| `research.*` data rows | 0 | 0 | 0 |

Affected dataset identity: `dataset_id = source_id = 'tcn_referential_daily'`, grain
`scalar_series`, assurance `provisional`, point-in-time status `forward_collection_required`, and
current dataset disposition `candidate_needs_review`. All 30 candidates are withheld from the
scalar exploratory observation interface because each annual worksheet remains a separate series
with insufficient cross-year history.

The exact candidate identities and fact counts are:

| Sheet | Candidate ID | Rows | Period range |
|---|---|---:|---|
| `2012_Compra` | `tcn_referential_daily:x2012_compra:3e4d23ff879362909b539f1d` | 102 | `2012-08-06` to `2012-12-28` |
| `2012_Venta` | `tcn_referential_daily:x2012_venta:7b18d2efe6b0a8b36842129e` | 102 | `2012-08-06` to `2012-12-28` |
| `2013_Compra` | `tcn_referential_daily:x2013_compra:39c5807e0e3a37d9ba14a83e` | 249 | `2013-01-02` to `2013-12-30` |
| `2013_Venta` | `tcn_referential_daily:x2013_venta:d5d53a1e778ea6caa737f738` | 249 | `2013-01-02` to `2013-12-30` |
| `2014_Compra` | `tcn_referential_daily:x2014_compra:ac8d7759700fb1ef0ceacdd3` | 249 | `2014-01-02` to `2014-12-31` |
| `2014_Venta` | `tcn_referential_daily:x2014_venta:76adb28781d1d93ec7da755a` | 249 | `2014-01-02` to `2014-12-31` |
| `2015_Compra` | `tcn_referential_daily:x2015_compra:63f812909724070377170f36` | 249 | `2015-01-02` to `2015-12-31` |
| `2015_Venta` | `tcn_referential_daily:x2015_venta:24ff36f1f739b5a1ce337514` | 249 | `2015-01-02` to `2015-12-31` |
| `2016_Compra` | `tcn_referential_daily:x2016_compra:71fc8519204779d4b87599d3` | 253 | `2016-01-04` to `2016-12-30` |
| `2016_Venta` | `tcn_referential_daily:x2016_venta:edfcd0505134f30b41ef2005` | 253 | `2016-01-04` to `2016-12-30` |
| `2017_Compra` | `tcn_referential_daily:x2017_compra:74b1357d80456da5613746cf` | 249 | `2017-01-02` to `2017-12-28` |
| `2017_Venta` | `tcn_referential_daily:x2017_venta:eff7c813ed3925ed44f3d38b` | 249 | `2017-01-02` to `2017-12-28` |
| `2018_Compra` | `tcn_referential_daily:x2018_compra:40b7e333b390efc3100ccbd1` | 250 | `2018-01-02` to `2018-12-28` |
| `2018_Venta` | `tcn_referential_daily:x2018_venta:2024c805e46adfef2633e4f6` | 250 | `2018-01-02` to `2018-12-28` |
| `2019_Compra` | `tcn_referential_daily:x2019_compra:68f3c13c3ab92e737710c519` | 248 | `2019-01-02` to `2019-12-30` |
| `2019_Venta` | `tcn_referential_daily:x2019_venta:b0653622ed6205ca772b56d4` | 248 | `2019-01-02` to `2019-12-30` |
| `2020_Compra` | `tcn_referential_daily:x2020_compra:7f8ca5d1448c6da7877fa649` | 249 | `2020-01-02` to `2020-12-30` |
| `2020_Venta` | `tcn_referential_daily:x2020_venta:841f9217687c4828eb2c0930` | 249 | `2020-01-02` to `2020-12-30` |
| `2021_Compra` | `tcn_referential_daily:x2021_compra:ff50a134ebfea6830ec99d51` | 252 | `2021-01-04` to `2021-12-30` |
| `2021_Venta` | `tcn_referential_daily:x2021_venta:4721dbc78ba52e2b17751ab0` | 252 | `2021-01-04` to `2021-12-30` |
| `2022_Compra` | `tcn_referential_daily:x2022_compra:617acfbd2a4bc89639d0ad23` | 250 | `2022-01-03` to `2022-12-29` |
| `2022_Venta` | `tcn_referential_daily:x2022_venta:c6c61da90237c18ca3ae8447` | 250 | `2022-01-03` to `2022-12-29` |
| `2023_Compra` | `tcn_referential_daily:x2023_compra:146d7f860f2db14b83a72302` | 249 | `2023-01-02` to `2023-12-28` |
| `2023_Venta` | `tcn_referential_daily:x2023_venta:169f40d551aca4ac446d39f4` | 249 | `2023-01-02` to `2023-12-28` |
| `2024_Compra` | `tcn_referential_daily:x2024_compra:1245fc833ee457c8a1097267` | 249 | `2024-01-02` to `2024-12-30` |
| `2024_Venta` | `tcn_referential_daily:x2024_venta:f4974c03c335c0b832a1b6e3` | 249 | `2024-01-02` to `2024-12-30` |
| `2025_Compra` | `tcn_referential_daily:x2025_compra:9bb1817ce3310ccfc518f00e` | 245 | `2025-01-02` to `2025-12-30` |
| `2025_Venta` | `tcn_referential_daily:x2025_venta:3e94abe0d27f6b82c1e10dad` | 245 | `2025-01-02` to `2025-12-30` |
| `2026_Compra` | `tcn_referential_daily:x2026_compra:02df4cd65d4285e41225bad4` | 159 | `2026-01-02` to `2026-08-25` |
| `2026_Venta` | `tcn_referential_daily:x2026_venta:dd51862e8453aa72d9925c1d` | 159 | `2026-01-02` to `2026-08-25` |

Sorted candidate-ID set SHA-256 under the newline convention above:
`98e3edf91385f20f502e07d096545f877062955d4560224a7d48a475dc3bf293`.
Sorted canonical fact-key set SHA-256:
`c91036693bd3ba63b89cd2bcaba0a34d652908e8db6b5c86ebbb6d40ebfc0ca8`.

### Classification and minimum safe remedy

**Classification:** expected parser population and accidental release-scope ingestion, with the
publisher status of the aggregate workbook **indeterminate**. The exact 7,004/30/30 counts are
asserted by the source-specific tests and contract, so this is not an accidental cell-region
expansion. But local package metadata shows a locally created/re-saved aggregate workbook, and no
local authoritative record establishes that those exact bytes are an official BCP publication.

Minimum safe remedy:

- If TCN is in scope, first obtain source-owner evidence for the workbook's construction and the
  official underlying source(s), plus the mandatory release/acquisition/licence evidence tied to
  the exact bytes. If the exact workbook cannot be evidenced as an acceptable source artifact,
  acquire the official material and preserve it as a distinct content-addressed vintage; do not
  rewrite or relabel this hash.
- Decide explicitly whether a locally assembled workbook is admissible at all and, if so, in which
  evidence layer and under which publisher/source label. That is a source-scope decision, not a
  parser repair.
- If TCN is out of scope, exclude it through governed release-input selection without deleting,
  renaming, or silently ignoring the retained bytes.

Remedy classification: construction and publisher evidence is **requiring official/source-owner
evidence**; admissibility and include/exclude treatment is **requiring the user's explicit scope
decision**; entering an authorized record or a governed exclusion after those decisions is
**mechanical and safe to implement**.

## Aggregate before/after reconciliation

| Artifact | Canonical fact rows | Canonical series |
|---|---:|---:|
| Frozen schema-41 incumbent | 1,227,082 | 13,985 |
| Reviewed lineage-fixed schema-43 candidate | 1,227,082 | 13,985 |
| Rejected official schema-43 build | 1,255,940 | 14,486 |
| Difference from either baseline | **+28,858** | **+501** |

Bidirectional comparison found 28,858 blocked-only fact rows, 501 blocked-only series, and zero
baseline-only rows. The two source contributions sum exactly to those totals. The two governed
dataset identities already existed as zero-population catalogue entries in the reviewed schema-43
candidate; their `catalog.datasets.candidate_series` values changed from 0 to 471 and 30. CDA
remained a dedicated curve structure and TCN placed 30 identities in the review tier.

Because the active pointer did not move, both datasets still had zero current observations in
`catalog.datasets`, zero rows in their `explore.*` observation interfaces, and zero `research.*`
data rows. This confirms release-boundary isolation inside the rejected artifact; it does not make
the persisted canonical additions in-scope or acceptable for promotion.

## Remedy classification matrix

| Proposed action | Classification | Why |
|---|---|---|
| Re-hash current and archived bytes; verify sizes, manifests, and identity-set counts | Mechanical and safe to implement | Read-only/reproducible and changes no governed state. |
| Enter metadata already supported by approved evidence, keyed by exact `(source_id, sha256)` | Mechanical and safe to implement | Data entry is deterministic only after evidence and scope approval exist. |
| Obtain official release page/identifier/date and licence evidence for CDA | Requiring official/source-owner evidence | None of these facts is established locally. |
| Establish the construction chain and official inputs for the TCN aggregate workbook | Requiring official/source-owner evidence | The exact file appears locally assembled/re-saved. |
| Treat either hash as `archive_ingest_upper_bound` legacy evidence | Requiring the user's explicit scope decision | The archive time is locally provable, but using legacy policy changes how a post-contract source is admitted and bypasses the non-legacy completeness gate by design. |
| Include either dataset in the schema-43 product | Requiring the user's explicit scope decision | It changes the authorized source and candidate population. |
| Exclude either dataset from schema 43 through governed manifest selection | Requiring the user's explicit scope decision | It changes which registered required inputs define the product. |
| Weaken `new_vintage_provenance_incomplete`, invent metadata, use file mtime, or copy synthetic test metadata | **Not a safe remedy** | It would violate provenance and release invariants. |

## Dependency-ordered repair plan and release gates

No step below has been implemented.

1. **Freeze the evidence and choose source scope.** Preserve both hashes and their archive copies.
   The user must decide, separately for CDA and TCN, whether schema 43 includes the source,
   excludes it, or defers it to a later release. For TCN the decision must also say whether a
   locally assembled aggregate can be an admissible source artifact.  
   **Gate:** a written product-scope decision names both exact source IDs and hashes and does not
   reinterpret the rejected decision or active pointer.

2. **Resolve source authority for every included vintage.** For CDA, obtain official release and
   licence evidence tied to the exact hash. For TCN, first establish the construction/source chain,
   then obtain official evidence for the underlying material and the rights to use the aggregate.
   If reacquired bytes differ, create a new vintage; never substitute them for the rejected hash.  
   **Gate:** a stranger can verify the official/source-owner evidence, exact-byte relationship,
   release identifier/date, URL, licence, and acquisition history. Unresolved facts remain explicit.

3. **Resolve the availability-policy edge case.** If the publisher states no release date, reconcile
   the runbook's permitted blank with the executable gate's mandatory field through a separately
   reviewed policy decision. If retrieval time is irrecoverable and archive-upper-bound treatment
   is proposed, obtain explicit approval to classify that hash as legacy/snapshot-limited.  
   **Gate:** recorded metadata and executable validation express the same availability policy; no
   date comes from reference periods, file mtimes, workbook properties, or test fixtures.

4. **Apply only the chosen mechanical remedy.** On the include branch, add evidence-backed
   `config/source_vintages.csv` rows keyed to the exact hashes. On the exclude branch, use a governed
   release-input/admission mechanism; do not remove source evidence or depend on missing files.  
   **Gate:** the resolved manifest contains exactly the scope approved in step 1; every included new
   vintage has complete mandatory provenance; every excluded vintage remains retained and visible
   to diagnostics without entering the candidate source bundle.

5. **Rebuild in isolation and reconcile each admitted population.** Use
   `scripts/load_project.R` and the normal candidate/transaction/decision workflow against a frozen
   production copy. For these exact bytes, the expected parser-level results are CDA
   49,813 raw cells / 412 sheets / 21,854 staging and fact rows / 471 series, and TCN
   12,510 raw cells / 30 sheets / 7,004 staging and fact rows / 30 series. Any different bytes or
   counts require a fresh source-specific investigation, not an updated baseline by assertion.  
   **Gate:** source-cell/row reconciliation balances; natural keys are unique; provenance, periods,
   semantic warnings, accepted/rejected/excluded content, and candidate identities reconcile; the
   approved population delta is exact and has zero unexplained removals or movements.

6. **Run release-wide verification before any promotion.** Run the focused source tests and the full
   regression suite, then validate public objects from a fresh read-only default connection. Compare
   canonical and public populations to both the frozen incumbent and the reviewed schema-43
   candidate.  
   **Gate:** `new_vintage_provenance_incomplete = 0`, all release-blocking errors are zero, the full
   suite passes, stored views/macros bind without `search_path`, public-interface scope matches the
   decision from step 1, and a failed candidate leaves production byte-for-byte unchanged.

7. **Make a new immutable product decision.** Do not rewrite
   `build:43303bc15d28971e37dfd49f` or its blocked decision. Only a new accepted build may become
   active.  
   **Gate:** the new schema-43 data-release record is accepted, its source bundle and build identity
   match the verified candidate, its active pointer names that same build, and the final artifact
   SHA-256 is recorded before atomic replacement.

## Reproduction queries

Open the rejected artifact read-only. These queries emit the full identities and reconcile the
population without relying on abbreviated labels:

```sql
-- Exact source bytes and acquisition state.
SELECT f.source_id, f.vintage_id, f.source_file, f.source_path, f.archive_path,
       f.sha256, f.size_bytes, f.publication_date, f.publication_date_source,
       p.official_release_date, p.official_url, p.release_identifier,
       p.retrieved_at, p.retrieval_method, p.available_at,
       p.availability_quality, p.license, p.evidence
FROM raw.source_files f
LEFT JOIN raw.source_provenance p USING (vintage_id)
WHERE f.source_id IN ('cda_curve', 'tcn_referential_daily')
ORDER BY f.source_id;

-- Every affected candidate identity, with its semantic label.
SELECT d.source_id, d.series_id AS candidate_id, d.identity_basis,
       d.identity_stability, d.source_label, d.full_series_path,
       count(f.series_id) AS fact_rows, min(f.period) AS earliest_period,
       max(f.period) AS latest_period
FROM canonical.dim_series d
LEFT JOIN canonical.fact_series_events f USING (series_id)
WHERE d.source_id IN ('cda_curve', 'tcn_referential_daily')
GROUP BY ALL
ORDER BY d.source_id, candidate_id;

-- Exact fact natural keys used for the set fingerprints above.
SELECT d.source_id, f.series_id, f.period, f.vintage_id
FROM canonical.fact_series_events f
JOIN canonical.dim_series d USING (series_id)
WHERE d.source_id IN ('cda_curve', 'tcn_referential_daily')
ORDER BY d.source_id, f.series_id, f.period, f.vintage_id;
```

Primary evidence used: the rejected artifact; the frozen schema-41 base; the reviewed lineage-fixed
schema-43 artifact; `database/releases/schema43_20260914_180157/{source_input_manifest.csv,
blocked_release_manifest.json,verification_results.txt,evidence/*}`; the exact current/archive
workbook bytes; `input_archive/archive_manifest.csv`; executable loader, pipeline, parser, and
release-gate code; source contracts; focused real-workbook tests; and the schema-43 acceptance and
production-release reports.
