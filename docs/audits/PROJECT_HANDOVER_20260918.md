# Paraguay macroeconomic database — project handover

**Generated:** 2026-09-18T21:48:00Z
**Status:** documentation and state reconciliation only. No parser, contract, source, candidate, production, backup, or release state was changed.

## 1. Executive summary

This repository builds a research-grade DuckDB database from Paraguayan macroeconomic and financial publications. Its practical objective is broad, honest preliminary usability without passing source ambiguity, parser mechanics, or incomplete acquisition evidence off as economic validation.

The three public layers deliberately have different meanings:

| Layer | Purpose | Current rule |
| --- | --- | --- |
| `catalog.*` | Discover every parser-identified dataset and candidate identity with warnings and lineage. | May contain provisional and withheld material. |
| `explore.*` | Retrieve mechanically eligible, native-grain current observations. | Requires stable identity, usable dates and values, deterministic parsing, a correct interface, and visible warnings; it is not formal validation. |
| `research.*` | Formal analytical/research interfaces. | Requires the separate governed assurance and review contract; preliminary or merely mechanically sound data do not enter. |

Consequently, incomplete acquisition metadata can be honestly retained in `catalog.*` and, where the meaning of the emitted value is non-misleading, in `explore.*`. It cannot justify real-time claims, unrestricted redistribution, or research admission. The active product is Schema 46, including the completed LRM remediation. A separate, retained CDA candidate is ready only for bounded independent acceptance: its count-of-operations curve nodes are provisionally explorable; its rate, volume, and anomalous positional nodes are withheld; it has no CDA research observations. TCN remains deferred.

**Authority convention in this handover:** database/sidecar/promotion records and the current configuration are current facts; earlier release reports are historical evidence. In particular, the rejected 24-source Schema 43 build is superseded by later scoped releases and is not the active state.

## 2. Current authoritative state

### Active production (verified 2026-09-18)

| Field | Verified value |
| --- | --- |
| Database / sidecar | `database/paraguay_macro_pilot.duckdb` / `database/paraguay_macro_pilot.duckdb.sha256` |
| Schema / SHA-256 / bytes | 46 / `eaba62ab6efbc3c81a59dd77493282d5a3f28290319ec487f0876eb3b318c553` / 476,590,080 |
| Active build / attempt / source bundle | `build:da67d6517df1dd3dae219ebc` / `attempt:7eba4ebf8c1f4d731bb8bc87` / `release:dcbccb827b93ee2362ab3c56` |
| Active decision | accepted, 22 sources, 0 errors, 38 warnings; promoted 2026-09-17 23:12:28 |
| Canonical facts / identities | 1,227,065 / 11,842 |
| Catalogue datasets / identities | 24 / 11,842 |
| Exploratory catalogue identities | 11,495 |
| Research catalogue identities | 32 |
| Registered / active admitted sources | 24 / 22 |
| Current scope position | CDA and TCN are not in the active 22-source bundle. |
| Latest rollback backup | `database/backups/paraguay_macro_pilot_pre_swap_20260917_203245.duckdb` |
| Latest promotion record | `database/releases/promotions/build_da67d6517df1dd3dae219ebc_20260917_203252.json` |
| Git | `empirical-readiness-schema-39`, `4ee3b07ba88d4dd70435750ece06f7cfed770a27`; branch is ahead of its configured upstream by 16 commits. |

| Active public interface | Rows | Identities where applicable |
| --- | ---: | ---: |
| `explore.observations` | 957,627 | 6,881 |
| `explore.events` | 95,543 | 2,343 at observation interface; 4,614 native-grain catalogue identities overall |
| `explore.panel_observations` | 17,044 | 984 |
| `explore.curve_observations` | 116,766 | 1,287 |
| `research.observations_latest_actual` | 7,498 | 32 |
| `research.observations_latest_statement` | 7,500 | 32 |
| `research.events` | 0 | 0 |
| `research.curves` | 38,922 | native curve grain |
| `research.entity_panel` | 332,745 | native panel grain |

The working tree intentionally has user-owned changes: the production database and checksum are modified relative to Git, four promotion JSON records are untracked, and `database/releases/schema43_20260914_180157/` is an untracked protected release-evidence directory. Do not clean, stage, alter, or infer invalidity from this state. The production artifact and sidecar agree with each other. It was built with a recorded dirty-tree warning; that is visible development evidence, not a release error.

### Retained CDA candidate (not production)

| Field | Verified value |
| --- | --- |
| Path / SHA-256 / bytes | `database/candidates/accepted_for_review_20260917_212826.duckdb` / `11727959edd135bb211dd267dedd0d7c569dea3e473510ee72b6ef8cb1155876` / 468,725,760 |
| Schema / build / attempt / source bundle | 46 / `build:180fb40bb51fadff89f9509f` / `attempt:a35046bd8c9f23aece17d28f` / `release:b4fa3c04186b336a91e9be7b` |
| Candidate decision | accepted internally, `completed_with_warnings`, 23 sources, 0 errors, 39 warnings, `published = FALSE` |
| Candidate totals | 1,248,919 facts / 12,313 identities |
| Scope | 23 exact hashes admitted; exact TCN hash deferred; no other source changed. |

The candidate's own pointer is an internal candidate state, not a publication. Promotion must use the retained-candidate path and re-check the candidate hash, base production hash, candidate decision, scope, build, attempt, bundle, schema, and population identities.

## 3. Architecture and operating model

1. Register each source in `config/source_registry.csv`; preserve exact source bytes and SHA-256.
2. When a product scope is frozen, use the exhaustive content-addressed decision in `config/release_input_scope.csv`; every registered source has one exact-hash `admit` or `defer` decision, and changed, missing, duplicate, or unreviewed inputs fail closed.
3. Parse in the authoritative loader route (`scripts/load_project.R`), retaining publisher labels, formulas/cached values, worksheet and A1 lineage, and explicit cell accounting.
4. Represent observations at their natural scalar, event, panel, or curve grain in canonical tables. Coordinates, values, and workbook position are not economic identity material.
5. Classify assurance, provenance, semantic review, identity stability, reconciliation, and quality independently.
6. Publish all recognised candidates to `catalog.*` with evidence and warnings.
7. Expose only mechanically safe, correctly shaped current observations through `explore.*`.
8. Expose only separately certified/formally admitted material through `research.*`.
9. Build in an isolated candidate copied from production; release-wide work runs there, never against production.
10. Perform bounded review of source scope, lineage, populations, warnings, natural keys, and public-view binding.
11. Promote only a hash-pinned `accepted_for_review_*.duckdb` via `promote_retained_candidate()`. It uses the same guarded atomic publisher, pre-swap production-hash check, backup, fresh read-only smoke test, and rollback as an ordinary accepted build.
12. Retain the candidate and the pre-swap backup as review and rollback evidence.

The retained-candidate mechanism was added so that independent acceptance can occur after a complete candidate build without creating a second, weaker publisher. A blocked build cannot change production; an accepted review candidate is still not production until the governed promotion succeeds. See [architecture](../ARCHITECTURE.md), [operations](../OPERATIONS.md), and [storage](../DATABASE_STORAGE.md).

## 4. Chronology of material work

| Stage | Purpose and outcome | Product status / principal evidence | Key commits |
| --- | --- | --- | --- |
| Pre-42 baseline | Schema 41 was the historical incumbent after earlier source and canonical work. | Historical/superseded; frozen in protected Schema 43 evidence. | Earlier history |
| Schema 42 research-platform correction | Correct `research.entity_panel` to preserve source currency code, origin currency, and reporting unit; restored 332,745 EEFF rows and prevented collisions/row loss. | Functionally carried forward; current production includes this correction. | `2ec1fc6`; [audit resolution](audit_resolution_report.md) |
| Schema 43 discovery/exploration and worksheet-lineage correction | Added broad catalogue/explore interfaces and repaired observation-specific worksheet/title lineage without changing values. | Promoted subsequently; superseded as a schema label by 44–46 but behavior carried forward. | `98370c2`, `d98a36a`; [lineage report](schema43_lineage_fix_report.md) |
| Rejected Schema 43 build | A global 24-source rebuild unintentionally selected CDA and TCN. Their parsers produced expected rows, but scope and provenance were unauthorized. | Permanently rejected; production stayed unchanged. | Historical artifact `blocked_20260914_180218.duckdb`; [diagnosis](schema43_rejection_diagnosis.md) |
| Exhaustive source scope | Replaced implicit global-registry product selection with exact full-hash admits/deferrals. | Current operating mechanism. Schema-43 scope has 22 admits/2 deferrals. | Scope implementation and promotion records |
| Successful scoped Schema 43 promotion | Released the intended 22-source population through the normal candidate process. | Superseded by later Schema 44–46 product, but establishes scope discipline. | `d98a36a`; [scope promotion](schema43_scope_promotion_record.md) |
| Series census and quality framework | Assigned exactly one conservative primary review category plus independent issue flags and per-layer admission/exclusion fields; did not confer economic certification. | Current framework, counts updated below. | `81039e7`, `fff93c3`, `8e1c5d7`; [package](schema43_post_promotion_series_quality/README.md) |
| LRM withholding and remediation | Initially withheld unstable/ambiguous LRM pieces; then established event-tenor identity, source-cell accounting, identity migration, human rate-unit decision, and two governed 2013 consolidations. | Fully closed for current exploratory use in Schema 46; no LRM research admission. | `dc50dbe`, `321cf60`, `73d741e`, `87db367`, `671462a`, `d823877`; [closure](lrm_remediation_20260917/CLOSURE.md) |
| CDA provisional onboarding | Added an exact-hash scope row and provisional provenance record; corrected identity-family persistence; exposed only count nodes in the curve interface. | Retained candidate only; not promoted. | `69c069e`, `2f86eb7`, `4ee3b07`; [CDA report](cda_onboarding_20260917/CDA_ONBOARDING_REPORT.md) |
| TCN | Preserved exact archive and continued deferral. | Deferred; no active or candidate observations. | Scope row and [Schema 43 diagnosis](schema43_rejection_diagnosis.md) |

The early report saying Schema 43 was not promoted is true only for its specific failed 2026-09-14 attempt. It is superseded by the later scoped Schema 43 promotion and, ultimately, by current Schema 46 production.

## 5. Human and product decisions

| Decision | Evidence classification | Current effect |
| --- | --- | --- |
| Broad discovery and provisional exploration are priorities, while research admission remains selective. | Human/product decision, implemented in architecture and public contracts. | `catalog.*` is broad; `explore.*` is bounded; `research.*` remains strict. |
| CDA and TCN were initially deferred instead of receiving invented provenance. | Governed scope decision; repository-documented. | Preserved source evidence without release admission. |
| Incomplete acquisition metadata can permit provisional exploration when representation is non-misleading. | Authorized product decision; bounded by evidence. | CDA count nodes may be explored in the retained candidate only. |
| CDA rates/volumes without established units remain withheld. | Workbook/repository evidence plus governed containment. | No rate, volume, or positional CDA node reaches explore/research. |
| LRM rates are annual percentages; `6.50` means 6.50% per annum; do not divide by 100 or re-annualise. | User-provided human domain confirmation, recorded in LRM closure. | `PERCENT_PER_ANNUM`, source values unchanged. |
| Two repeated 2013 LRM pairs are same-day auction operations inside common auction-tenor events. | User-provided human domain confirmation plus governed analytical decision. | Components retained in lineage; no source row discarded. |
| LRM amounts/counts sum; average rates are amount-weighted; minima/maxima select extrema; structural absence is not zero. | Governed analytical decision, implemented and reconciled. | 22 derived facts with 52 lineage links. |
| No provisional source enters research without separate formal validation. | Non-negotiable architecture/research contract. | CDA and LRM have zero research rows. |

## 6. Series-quality and usability framework

Every `catalog.series` identity has one primary review category and independent issue codes. The category is a review queue, not a semantic certificate. Current **production** counts are:

| Primary review category | Identities | Current facts |
| --- | ---: | ---: |
| `apparently_valid_preliminary` | 11,403 | 1,168,582 |
| `research_admitted_rule_certified` | 32 | 7,498 |
| `probable_identity_fragmentation` | 324 | 39,717 |
| `probable_duplicate_or_overlap` | 60 | 10,900 |
| `insufficient_evidence` | 23 | 25 |
| **Total** | **11,842** | **1,226,722** |

The remaining 343 canonical facts are publisher-statement/revision-status facts outside that current-observation profile sum; canonical total remains 1,227,065. Current exploratory admission is 6,881 scalar and 4,614 native-grain identities; 347 identities are withheld (324 for unstable preliminary identity, 23 for insufficient scalar history). Research admission remains 32 scalar identities/7,498 current actual observations.

The framework makes unit warnings, overlap warnings, identity fragmentation, source-cell/worksheet lineage status, semantic/provenance review status, and public exclusion reasons query-visible in catalogue and exploratory rows. “Series” here includes granular panels, events, instruments, institutions, and curve nodes; it is not a count of headline macroeconomic indicators.

## 7. LRM final state — closed for current exploratory use

LRM source ID is `lrm_auctions`, exact vintage `lrm_auctions:b7e160f57d37a215d182eaef`, SHA-256 `b7e160f57d37a215d182eaeffea7d18a4e99151ebbde1efd9aa320d08ba71a37`. Schema 46 represents it at native auction-tenor event grain: auction date plus published settlement/maturity and standardized/residual tenor dimensions, with explicit measure. Annual worksheet is lineage, not identity.

Amounts remain source PYG millions; tenors are days; bid counts are counts; rates are source values interpreted as percentages per annum by human confirmation, without rescaling. The two 2013 duplicate event pairs are analytically consolidated under the documented rules above, while all 10,351 components remain in `staging.lrm_component_observations`. There are 10,334 current canonical LRM facts and 940 identities, exactly the same 10,334/940 observations available through `explore.events`; `research.*` contains zero LRM observations. The migration ledger covers 957 prior Schema-44 identifiers with 964 mappings to 940 current identifiers. Cell reconciliation records all 20,016 A1 cells and zero parser defects. A remaining nonblocking limitation is provenance/availability evidence shared with legacy-current snapshots; it does not reopen the resolved LRM representation.

The final result is active production Schema 46/build `build:da67d6517df1dd3dae219ebc`; use [LRM closure](lrm_remediation_20260917/CLOSURE.md), [report](lrm_remediation_20260917/REPORT.md), the migration CSV, and source-cell ledger for continuation.

## 8. CDA candidate state

**Exact source:** `cda_curve`, vintage `cda_curve:8796a589fc2bd31317efdce7`, SHA-256 `8796a589fc2bd31317efdce7865d4598473fdacd048cf04b676dc8f78e2b144c`, 4,505,245 bytes. `input/current/Curva_CDA.xlsx` and the immutable archive copy under `input_archive/cda_curve/<sha>.xlsx` were re-hashed and match.

The BCP workbook is *Curva de Certificados de Depósitos de Ahorro*: 412 visible monthly worksheets (206 rates; 206 operations/volume), from 2018-01-31 through 2026-07-31. Workbook-explicit labels distinguish local/foreign-origin presentations, weighted term-deposit rates, operations/counts, volume, published institution class, and published tenor labels. `Datos al dd/mm/yyyy` is the observation date. It does not establish maturity date, standardized numeric tenor, issue/trade/auction date, rate percent-versus-decimal convention, annual/nominal/effective/compounding interpretation, universal currency meaning, volume scale, publisher verification, licence, or actual acquisition/publication time.

The correct representation is a monthly **curve-node panel**. Stable identity is parser family (`CDA_RATE_CURVE` or `CDA_OPERATIONS_CURVE`), frequency, and full publisher label path (origin wording, measure, institution class where present, and verbatim tenor label). Worksheet, coordinate, value, monthly date, format, and order are excluded from identity. The natural key `(series_id, period, vintage_id)` has no duplicates. Formulas/cached values are retained; cached supplied numeric results are used, never recomputed. The workbook has 263 formula-bearing cells and no hidden rows/columns.

| CDA candidate disposition | Identities | Facts |
| --- | ---: | ---: |
| Catalogued/reconciled total | 471 | 21,854 |
| `COUNT`, semantic, explorable in `explore.curve_observations` | 114 | 7,269 |
| Rate/volume semantic identities withheld for unresolved source unit/scale | 342 | 14,570 |
| Positional anomalous/unlabelled identities withheld | 15 | 15 |
| **Withheld total** | **357** | **14,585** |
| CDA research | 0 | 0 |

Every numeric data-bearing cell (21,854) maps once to an accepted observation; numeric cells equal accepted observations, and rejected, documented exclusion, balance delta, cell reuse, unmapped, unclassified, and parser-defect counts are all zero. There are 49,813 nonempty raw cells across the workbook. The old rejected build's 471/21,854 count is reproduced, but this is a reconciliation result, not a representation target.

Provenance is deliberately limited: archive-ingest upper bound `2026-09-14T21:02:26Z`, content maximum `2026-07-31`, exact paths/hash and parser contract are established. That timestamp is **not** a retrieval or official release time. Official release date/URL/identifier, actual retrieval time, licence/redistribution right, and publisher verification remain unresolved; `availability_quality = inferred_upper_bound`. The candidate differs from production only by CDA: bidirectional non-CDA fact and identity comparisons are zero; LRM remains 10,334 facts/940 identities; all 141 declared public views bind from fresh read-only connections. CDA tests, scope tests, smoke test, and the full test suite passed (the sole suite warning is the intentional corrupt-ZIP fixture). The candidate predates `2f86eb7` only in build time; that later commit changes a test fixture only, not candidate behavior.

**Why not promoted:** it requires an independent reviewer to verify the hash-pinned candidate, exact 23/1 scope, count-only curve admission, complete withholding, zero CDA research admission, non-CDA invariance, zero release errors, and unchanged production. The reviewer must not treat passing mechanical tests as proof of rate/volume economics or provenance.

## 9. TCN state — deferred

**Exact source:** `tcn_referential_daily`, vintage `tcn_referential_daily:74df666397a33b9c8cdfac10`, SHA-256 `74df666397a33b9c8cdfac10d7ffedd23acf7cbd5907ea21332e100fb939c0a4`, 117,740 bytes. Current and archived workbook bytes match. The Schema-46 CDA scope has 23 admits and one exact deferral: this TCN vintage.

Historical parser evidence identifies 30 annual Compra/Venta worksheets, a daily calendar-grid interpretation, 7,004 facts, and 30 annual-sheet candidate identities spanning 2012-08-06 through 2026-08-25. `ND` is a raw missing-value token; `2021_Compra!A1` has a damaged title cell. The workbook's package metadata and an absolute personal SharePoint path suggest a locally assembled/resaved aggregate rather than proving publisher-issued aggregate provenance. This is an evidence warning, not a claim that the data are false. The likely corrective representation is two continuous daily Compra/Venta identities (or a documented compatible native structure) rather than 30 annual worksheet series, but that requires source-chain evidence and a separate parser/identity review. Do not implement that work as a side effect of CDA acceptance.

## 10. Prioritised unresolved register

| Priority / issue | Impact and containment | Evidence needed | Blocks |
| --- | --- | --- | --- |
| P0 CDA rate unit, percent/decimal, periodicity, nominal/effective and compounding | Rates retained in catalogue, not explore/research. | Authoritative BCP methodology or source-owner statement tied to exact workbook. | CDA rate explore and research. |
| P0 CDA volume unit/currency/scale | Volumes retained, not explore/research; foreign-origin wording is not generalized. | Publisher definitions and scale/currency evidence. | CDA volume explore, research, redistribution claims. |
| P0 CDA acquisition/release/availability/licence | Exact lineage retained; inferred archive upper bound visibly warns. | Official release page/identifier/date, acquisition record, licence/redistribution terms. | Real-time claims, research, external redistribution. |
| P1 15 CDA positional/anomalous nodes | Catalogued and explicitly withheld. | Workbook/source-owner explanation of blank heading/row and stable semantic label. | Their explore/research admission. |
| P0 TCN source chain and publisher status | Exact workbook deferred; no observations leak. | Provenance of aggregate workbook or official inputs and authorised assembly history. | TCN catalogue/explore/research and redistribution. |
| P0 TCN continuous Compra/Venta identity | Annual fragments remain historical parser evidence only. | Reviewed meaning, date/grid continuity, stable measure/unit/currency evidence. | Correct TCN exploration. |
| P1 Legacy source provenance warnings | Existing active sources have availability/provenance warnings. | Per-vintage official source and licence records. | Strong availability/real-time and redistribution claims. |
| P1 Other unresolved units, overlaps, hierarchies | Visible quality flags and exclusion rules prevent silent certification. | Source-specific methodology and economic review. | Affected research admission; selected exploration only where misleading. |
| P2 Formal research expansion | Current research remains intentionally narrow. | Named review of definitions, units, timing, hierarchy, methods, provenance. | Research admission only. |
| P2 Candidate/backup retention | 17 candidates and 15 backups occupy about 12.8 GiB. | Read-only inventory/classification and explicit operator deletion decision. | Storage only; never an automatic cleanup. |

## 11. Recommended roadmap

| Stage | Objective, prerequisites, benefit, risks, deliverable, completion criterion | Fresh session? |
| --- | --- | --- |
| A — CDA bounded acceptance | Independently inspect the retained candidate/hash, count-only curve rows, all withholding, scope, invariance, and release records. Benefit: safely promote a small useful CDA subset. Risk: mistaking candidate acceptance for semantic validation. Deliverable: independent acceptance memo and, only with explicit authority, governed promotion. Complete when all stated checks pass and promotion record/smoke test exist. | Yes: an independent Codex acceptance session. |
| B — CDA semantic expansion | Obtain authoritative rate/volume documentation; resolve units, scaling, convention/compounding, currency interpretation and 15 positional nodes. Benefit: expand provisional exploration without inventing transformations. Risk: source wording overread. Deliverable: source-specific evidence and a new hash-pinned candidate. Complete when every newly exposed subset is unit-safe and reconciled. | Yes, after evidence arrives. |
| C — TCN remediation/onboarding | Establish source chain, retain Compra/Venta distinction, join annual grids only where justified, govern `ND` and damaged title, then build provisional candidate with zero initial research admission. Benefit: useful daily reference-rate access. Risk: locally assembled workbook and false continuity. Deliverable: evidence package and candidate. Complete when source, identity, unit, reconciliation and scope all pass. | Yes. |
| D — Continued source expansion | Inventory high-value Paraguayan sources and prioritise research value, coverage gain, and onboarding cost. Benefit: broader discovery. Risk: expansion outruns evidence. Deliverable: source backlog and one bounded source workstream at a time. Complete per source, not through bulk admission. | Only for each material source workstream. |
| E — Selective research validation | Validate datasets actually needed for papers, forecasting, or policy analysis. Benefit: useful certified research data without fictional comprehensive review. Risk: mass promotion by mechanics. Deliverable: named formal reviews, assurance records, and tests. Complete for each explicitly validated dataset. | Separate acceptance where material. |
| F — Usability and maintenance | Improve examples, retrieval/export helpers, refresh/vintage procedure, monitoring, candidate retention, performance and storage practice. Benefit: sustainable use. Risk: cleanup or convenience bypasses controls. Deliverable: user documentation and operator runbooks. Complete when controls remain tested and operator-owned retention decisions are recorded. | No for routine small docs; yes for changes to release/storage mechanics. |

## 12. Session and conversation plan

This implementation/documentation Codex session can close after committing this handover. The CDA implementation session is also closed: it produced a bounded candidate, not a promotion decision. Open one **fresh independent Codex acceptance session** for Stage A; give it authority to promote only if the explicit checks pass. If acceptance fails, it should leave the candidate/production untouched and record why.

Open a separate implementation session for CDA semantic expansion only after authoritative evidence exists. Open a separate source-specific implementation session for TCN. Use a separate acceptance session whenever a candidate changes production scope, identity, research admission, or semantics. Strategic ChatGPT conversations can prioritise evidence collection and roadmap choices; they should not substitute for code/release acceptance. Do not create a new session for trivial read-only queries or a documentation correction.

## 13. Artifact and commit index

| Item | Purpose / status | Needed to continue? |
| --- | --- | --- |
| `database/paraguay_macro_pilot.duckdb` and `.sha256` | Active Schema 46 production; current authority. | Yes, read-only baseline. |
| `database/backups/paraguay_macro_pilot_pre_swap_20260917_203245.duckdb` | Latest pre-Schema-46 rollback backup. | Yes, retain. |
| `database/releases/promotions/build_da67d6517df1dd3dae219ebc_20260917_203252.json` | Current production promotion provenance. | Yes. |
| `database/candidates/accepted_for_review_20260917_212826.duckdb` | Exact CDA bounded-review candidate. | Yes; do not modify. |
| `docs/audits/cda_onboarding_20260917/` | CDA representation plan and full evidence report. | Yes. |
| `docs/audits/lrm_remediation_20260917/` | LRM representation, closure, migration and cell reconciliation. | Yes for LRM provenance; LRM workstream itself is closed. |
| `docs/audits/schema43_rejection_diagnosis.md` and protected `database/releases/schema43_20260914_180157/` | Historical rejected-build/root-cause evidence. | Retain; not current state and do not alter. |
| `docs/audits/schema43_*scope*`, `schema43_lineage_fix_report.md` | Scope correction and lineage history. | Yes for historical rationale. |
| `docs/audits/schema43_post_promotion_series_quality/` | Quality census framework and machine-readable worklists. | Yes. |
| `config/release_input_scope.csv`, `config/source_vintages.csv`, `config/source_registry.csv` | Current governed scope and provenance contracts. | Yes. |
| `docs/ARCHITECTURE.md`, `docs/DATA_MODEL.md`, `docs/OPERATIONS.md`, `docs/RESEARCH_DATABASE_GUIDE.md`, `docs/SCHEMA_MIGRATIONS.md`, `docs/DATABASE_STORAGE.md` | Architecture, data/temporal contracts, release, research and storage rules. | Yes. |
| `2ec1fc6`, `98370c2`, `d98a36a`, `81039e7`, `fff93c3`, `8e1c5d7` | Schema 42/43 platform, promotion, quality framework history. | Historical reference. |
| `dc50dbe`, `321cf60`, `73d741e`, `87db367`, `671462a`, `d823877` | LRM remediation/closure. | Historical/current LRM evidence. |
| `69c069e`, `2f86eb7`, `4ee3b07` | CDA scope/parser admission, test-only fixture fix, durable CDA evidence. | Yes for CDA review. |

## 14. Storage and retention recommendations

Read-only inventory on 2026-09-18 found 17 candidate databases totalling 7,614,443,520 bytes (about 7.09 GiB) and 15 backups totalling 6,075,109,376 bytes (about 5.66 GiB). The protected Schema-43 release directory is about 400 MiB, mostly its 418,918,400-byte `schema41_base.duckdb`.

Candidate inventory: ten `accepted_for_review_` files (20260914_195427, 20260914_202049, 20260916_202652, 20260916_212247, 20260917_174613, 20260917_191937, 20260917_192812, 20260917_194958, 20260917_201100, **20260917_212826**) and seven `blocked_` files (20260905_194653, **20260914_180218**, 20260917_174421, 20260917_191623, 20260917_191746, 20260917_211859, 20260917_212317). The bold retained CDA candidate and historical rejected Schema-43 candidate must be retained. Accepted candidates referenced by promotion records, Schema-46 candidate `accepted_for_review_20260917_201100`, and LRM review candidates are also evidence-bearing. Blocked candidates can only become cleanup candidates after read-only classification confirms that their reports/candidates are not the sole evidence of an unresolved release decision.

Backups comprise nine 2026-09-05–09 copies and six 2026-09-16–17 copies. The latest production rollback is required; earlier backups should be classified by schema/build/uniqueness before any future deletion. The repository's documented `prune_backups.R` is dry-run by default and deletion is an explicit operator act. Do not move, compress, or delete now. Before a later cleanup, verify promotion references, migration evidence, historical uniqueness, candidate hashes, protected-directory status, free-space need, and whether an artifact is cited by a durable report.

## 15. Immediate next action

**Open a fresh independent Codex session to perform bounded acceptance of the retained CDA candidate, with authority to promote it only if the provisional count-only admission, withholding rules, source scope, and non-CDA invariance all pass.** Do not begin CDA semantic expansion or TCN work in that session.

### Appendix — ready-to-paste next-session prompt

> Perform an independent bounded acceptance review of `database/candidates/accepted_for_review_20260917_212826.duckdb`; do not rebuild it and do not alter parsers/contracts/source files. Current production is Schema 46, SHA-256 `eaba62ab6efbc3c81a59dd77493282d5a3f28290319ec487f0876eb3b318c553`, bytes 476590080, build `build:da67d6517df1dd3dae219ebc`, attempt `attempt:7eba4ebf8c1f4d731bb8bc87`, source bundle `release:dcbccb827b93ee2362ab3c56`. Candidate SHA-256 is `11727959edd135bb211dd267dedd0d7c569dea3e473510ee72b6ef8cb1155876`, bytes 468725760, schema 46, build `build:180fb40bb51fadff89f9509f`, attempt `attempt:a35046bd8c9f23aece17d28f`, source bundle `release:b4fa3c04186b336a91e9be7b`, and 0 release errors. Verify it admits only exact CDA `cda_curve:8796a589fc2bd31317efdce7` / `8796a589fc2bd31317efdce7865d4598473fdacd048cf04b676dc8f78e2b144c`, retains exact TCN `tcn_referential_daily:74df666397a33b9c8cdfac10` / `74df666397a33b9c8cdfac10d7ffedd23acf7cbd5907ea21332e100fb939c0a4` as the sole deferral, has 471 CDA catalogue identities/21,854 facts, exposes only 114 count identities/7,269 facts through `explore.curve_observations`, withholds 357 identities/14,585 facts, has zero CDA research observations, reconciles all numeric CDA cells, and is invariant to production outside CDA (including LRM 10,334 facts/940 identities). Read `docs/audits/cda_onboarding_20260917/` and this handover. Promote only via the governed retained-candidate function, only after every check passes and only with explicit authority; otherwise leave candidate and production unchanged and report the blocking evidence.
