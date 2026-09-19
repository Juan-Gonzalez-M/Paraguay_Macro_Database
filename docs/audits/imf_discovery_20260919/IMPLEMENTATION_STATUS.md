# IMF onboarding implementation status — 2026-09-19

## Current state

Schema 49 implements 24 of the 25 received IMF dataflows in preservation,
staging, canonical catalogue and exploratory layers. The five pilot dataflows
are joined by 17 official/aggregate/global-factor dataflows and two explicitly
experimental research products.

One file remains deliberately unregistered:

- `IMTS`: bilateral country-partner trade, deferred to a dedicated high-volume
  module with its own natural grain;

RSUI is registered as an experimental research indicator and WPFXI as a
working-paper mixture of public data and proxies. Neither is represented as
official statistics or admitted to `research.*`.

No IMF series is admitted to `research.*`, no IMF/BCP equivalence is asserted,
and structural blanks are not facts.

## Parser and storage behavior

`scripts/16_imf_wide.R` detects UTF-8 BOM, UTF-8 and Windows-1252; unwraps the
semicolon envelope; reconstructs multiline inner CSV; retains physical and
logical coordinates; preserves dataflow/version, series code, observation
measure and every published dimension; and normalizes populated periods without
implicit transformations.

Schema 48 adds `staging.imf_metadata_snapshot`. The FSI metadata dataflow stores
101,095 textual values there with measure, published period and source
coordinates. Those values never enter the numeric fact table.

## Candidate

The latest isolated candidate is:

`database/candidates/blocked_20260919_192433.duckdb`

- release: `release:42753eb4fa49d2dbedd73b07`
- build: `build:68ee020667d5b12855fbee13`
- attempt: `attempt:9c00088f5aa91c93b3b6c6cb`
- schema: 49
- SHA-256: `1d0053eb2f83da52d3cc9ef2ce2ec62d2786e80ee896ef96ca7c5e5656a6667b`

It contains 20,964 distinct published IMF series codes, 2,558,738 numeric
observations and 101,095 textual metadata values. The current attempt is blocked
only by the dirty-tree reproducibility gate. Historical public-scope flags are
retained audit evidence rather than errors of this attempt. Production was not
changed.

## Verification

Focused parser, migration, scope, research and exploratory tests pass. The full
real-source smoke test also passes with all 48 registered project sources. The
full suite has one expected environment error because six directly loaded
packages differ from `renv.lock`; no package installation was authorized. Its
corrupt-ZIP isolation fixture emits the expected warning.

Promotion remains out of scope until the unrelated public contract is resolved,
the work is committed, and a separate acceptance decision is made.
