# PLAN: every CRAN and GitHub check under 10 minutes (2026-11-27)

Goal: each hosted check on a release PR to `main`, and the CRAN check, finishes in under 10 minutes.
Builds on `planning/PLAN-ci-speed-2026-11-27.md` (local-only tier, 6 reliability shards).

## Where the time is (hosted, measured)

| Check | Now | Target | Main cost |
|---|---|---|---|
| ubuntu release (required) | 7 min | keep | tests of the CI tier |
| noSuggests | 4 min | keep | |
| ubuntu devel / oldrel-1 | 8 / 9 min | keep | check 405 s plus setup |
| macOS | 10 min | < 10 | check 462 s, setup about 3 min |
| Windows | 14 min | < 10 | `testthat.R` 558 s, setup 2.5 min |
| gates rest (3 shards) | 3 to 5 min | keep | |
| gates reliability (6 shards) | 2.6 to 7 min | keep | |
| pkgdown | 6.5 min | keep | install 51 s, build 257 s (articles are not the cost; slowest is 10 s) |
| lint | 3.3 min | keep | |
| test-coverage | 28.6 min before the tier; unmeasured since | < 10 | `covr` instrumentation of the CI tier |
| CRAN (Windows, win-builder) | 0.21.2 failed at 11 min; 0.21.3 estimated 7.6 min | < 10, confirmed | tests with `skip_on_cran` |

## Tasks

| # | Task | Done when | State |
|---|---|---|---|
| C1 | macOS and Windows run a platform subset via `MEDFIT_TEST_FILTER` (40 files, 17 s on a laptop) | dispatched run 46070257784: both legs under 10 min | pushed on `feature/ci-under-10min`, run in progress |
| C2 | Measure coverage after the tier: add `workflow_dispatch` to `test-coverage.yaml`, run once on the branch | a wall-clock number for the job | not started |
| C3 | If C2 is over 10 min: shard `covr` by test file (3 jobs, `covr::file_coverage` per shard, merged cobertura files uploaded to Codecov with flags) | each shard under 10 min, merged coverage within 1 point of the single run | not started |
| C4 | If C3 is not enough: ask the user to narrow coverage scope (for example the CI tier minus engine-internals files) | user decision, not mine | blocked on C2 |
| C5 | Trim setup on slow legs: skip `quarto-dev/quarto-actions/setup` on Windows and macOS if no check step renders a vignette; cache the dependency library | setup under 1.5 min | not started |
| C6 | CRAN: build the 0.21.3 tarball again from dev, run the CRAN-mode check locally with a timer, and have the user submit to win-builder | win-builder reports a check time under 10 min | user step |
| C7 | pkgdown and lint: leave unless a release PR shows more than 8 min | none | watch only |
| C8 | Record the rule: a hosted check over 8 min on a release PR gets a task here; update `CLAUDE.md` CI section and `.STATUS` | docs match the workflow | after C1 to C3 |

## Order and risk

1. C1 (in flight), then C2 in parallel.
2. C5 only if C1 leaves a leg between 9 and 10 min.
3. C3 only if C2 is over 10 min.
4. C8 last, with the measured numbers.

Risks:
- The platform subset gives Windows and macOS less test coverage. Mitigation: ubuntu release runs the full CI tier, and `scripts/check-local-full.sh` receipt gates the release.
- Sharded coverage can drift from a single run. Mitigation: compare totals on the same commit before switching.
- Hosted runner speed varies 20 to 40 percent between runs. Mitigation: aim for 8 min, not 10.

## Decisions for the user

- C4: whether coverage may drop files from its scope.
- C6: win-builder submission and the CRAN upload are yours.
- Moving the platform legs to run only after merge to `main` (instead of on the release PR) is available and would remove them from the PR wait entirely; not planned unless C1 fails.
