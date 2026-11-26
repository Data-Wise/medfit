#!/bin/sh
# Run the local-only tier (testthat files and simulation gates over ~300 s on a hosted runner) on this machine and write
# planning/local-full-runs/RECEIPT-<date>-<sha>.md. A release needs a green receipt for the release commit.
# Usage: scripts/check-local-full.sh [--workers N] [--tests-only | --gates-only] [--dry-run]
# Exit status: 0 = every item passed, 1 = any failure, 2 = setup error.
set -u
root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "check-local-full: not in a git tree" >&2; exit 2; }
cd "$root" || exit 2
[ -f scripts/check-local-full.R ] || { echo "check-local-full: scripts/check-local-full.R missing" >&2; exit 2; }
exec env NOT_CRAN=true Rscript scripts/check-local-full.R "$@"
