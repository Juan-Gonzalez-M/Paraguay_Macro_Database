#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
Rscript run_update.R
