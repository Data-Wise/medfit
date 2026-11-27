# CI speed, 2026-11-27: move most test time local, shard the reliability gate

Why: the release PR 0.21.3 (#571) took 45 minutes to reach a mergeable state. The critical path was the required
`ubuntu-latest (release)` check (2,646 s in the check step, nearly all test time), then `gates (reliability)` (1,149 s).
Instruction (user, 2026-11-27): reduce the tests on CRAN and GitHub, run the larger ones locally, move the majority.

Measured on the maintainer's machine, hosted mode (`CI=true NOT_CRAN=true`), 244 test files: 775 s in total; the top 20 files
are 72% of it and the top 40 are 84%.

## Changes

| Item | Before | After |
|---|---|---|
| Test files on CI and CRAN | 244 files, 775 s (hosted mode) | 202 files, 149 s: 37 more files local-only (42 in the tier) |
| CRAN-mode tests | 53 s | 34 s |
| `gates (rest)` | 1,132 s in 3 shards | 411 s in 3 shards of about 137 s; 7 gates of 70 s or more local-only |
| `gates (reliability)` | 1,149 s on 3 of 4 cores | 6 shards on 4 cores each (3 measured at 9 to 12 min hosted, 2026-11-27; `SHARD`/`SHARDS` in `tests/sim/sem-reliability.R`, `scripts/merge-reliability.R`); same 76,800 fits, same verdict |

Kept on CI: the cookbook, troubleshooting and two-level docs guards (they protect the published site).
The release receipt (`scripts/check-local-full.sh`) now runs 42 files and 10 gates locally.

## Evidence (local)
- Hosted-mode suite 775 s to 149 s, CRAN mode 53 s to 34 s, 0 failures, 0 errors in both.
- Reliability at REPS=1: the 3 merged shards give 768 rows with outcome columns identical to the unsharded run.
- `test-local-only`, `test-gate-coverage`, `test-ci-workflows`, `test-docs-release` and `scripts/test-gate-shards.R` pass.

## Not changed (decisions for the maintainer)
- The platform legs on release PRs (macOS, Windows, devel, oldrel-1, noSuggests, coverage) still run there. Moving them to
  push-to-main would cut about 35 more minutes of waiting but moves platform failures after the merge.
- A test-shard design (5 runners, `scripts/test-shards.R`) was built and dropped: with the majority local it is not needed.
