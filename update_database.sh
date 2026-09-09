#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
Rscript --vanilla run_update.R
