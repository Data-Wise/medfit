# PLAN: cut the wall time of the hosted checks and the local suite (2026-11-25)

Source: `planning/PLAN-speed-autonomy-2026-11-24.md` (items S3, S5, S6, section 8 "Corrected evidence"). This plan turns
those items into ordered, verifiable tasks. Tasks tracked in this file (no external tracker).

## Overview

The release PR to `main` (#545, v0.21.0) took about 50 to 60 minutes of wall time on 2026-11-25. Job timings from the
GitHub jobs API show where it goes:

| Job | Wall time | Where |
|---|---|---|
| `ubuntu-latest (release)` (required) | 49 min 42 s | `check-r-package` step (the test suite) |
| `ubuntu-latest (release, noSuggests)` | 19 to 20 min | same step, fewer tests run |
| `gates (reliability)` | 26 to 28 min | simulation gates |
| `ubuntu-latest (devel)` | setup 25 min, then the check | `setup-r-dependencies` builds from source |
| `test-coverage` | about 41 min | suite under covr (main only) |

The suite is about 2,750 tests and about 4,000 s of single-process CPU. Thread caps did not help and the image was not
the cause (section 8 of the speed plan). The same configuration varies between 42 and 62 minutes run to run, so every
claim below needs repeated, alternating measurements.

**Goal:** median wall time of the required `ubuntu-latest (release)` job at or below 25 minutes, with identical test
counts and no new failure, and the `devel` leg without its 25-minute dependency build.

**Freeze:** nothing in this plan merges into `dev` until release PR #545 is merged and v0.21.0 is tagged; a new commit
on `dev` re-runs all of its hosted checks (it did once already, after #547). Phase 0 is read-only and can run now.

## Architecture decisions

- **Measure first.** Per-file timing decides whether parallel workers, sharding or a test tier is the right lever.
  FIML files are reported as about 56% of test CPU (speed plan S6); T0 confirms or corrects that on the current tree.
- **Parallel workers before sharding.** `Config/testthat/parallel: true` is one DESCRIPTION line, needs no new
  workflow, and helps local runs too. Sharding across jobs is the fallback when state leaks between files.
- **No coverage given up on release.** Any tier or skip applies only to development runs; the full suite stays on PRs
  to `main` and on the tag.
- **Parity is the acceptance test, not speed.** A faster run with a different test or expectation count is a failure.
- **Pilots on a throwaway branch with `workflow_dispatch`**, alternating against the serial control, as in the thread
  probe. The branch is deleted after (the user runs the `-D` line).

## Task list

### Phase 0: measure (read-only; can start before the release lands)

- [x] **T0: per-file test timing from CI. Done 2026-11-25 (probe run 45728692964, `ubuntu-24.04`, `NOT_CRAN=true`,
  `test_dir` on the installed package).** 248 files, 2,751 tests, 23,125 expectations, 4,477 s summed test time.
  Top 5 files = 41.8% of the time, top 10 = 63.6%, top 20 = 80.2%, top 40 = 89.9%. By name: FIML files 49.9%,
  two-level files 35.2% (overlaps FIML where both appear), `sem-` files 16.6%, cluster 8.6%, bootstrap 3.8%.
  Slowest: `test-fiml-g3-serial-two-cov.R` 418 s, `test-twolevel-equal-indirect.R` 388 s, `test-sem-fiml-oracles.R`
  380 s, `test-twolevel-icc-h1-qa.R` 344 s, `test-twolevel-few-clusters-harness.R` 340 s, `test-fiml-g3-serial-two-cov-defects.R`
  277 s, `test-fiml-g3-parallel-covariates.R` 237 s, `test-fiml-g3-serial-covariate.R` 182 s. Correction to the
  speed plan: FIML is 49.9% here, not 56%. Caveat: this probe showed 1 failure in `test-sem-nnls.R` (and 19 skips)
  that the PR runs did not; the cause is not investigated (harness difference suspected, unverified), so the
  timings are valid but the pass count is not a parity baseline. Takeaway for T2: the load is concentrated in about
  ten long files, so parallel workers need them started first (`start-first`) or the longest file (418 s) bounds
  the speed-up.
  (original task text follows)
  Description: record seconds per test file for one `ubuntu-latest (release)` run, from the existing run's
  `tests/testthat` output or a JUnit reporter on a dispatched run, and rank files.
  Acceptance: a table of the 20 slowest files with seconds and share of total; the total is within 10% of the job's
  `check-r-package` time; FIML, cluster and bootstrap shares stated.
  Verification: the table is reproducible from a logged run id; the top-file share matches (or corrects) the 56% FIML
  figure.
  Dependencies: none. Files: `planning/` note only. Scope: XS.

### Phase 1: parallel workers (S3)

- [x] **T1: state-leak audit of the test files. Done 2026-11-25 (read-only, `origin/dev` at the 0.21.0.9000 bump, 249 test files).**
  Method: `git grep` per shared-state pattern, every hit in the risky categories read. Result: no blocker for parallel
  workers; four findings feed T1b, T2 and T6.
  Clean: no raw `options(` calls (the 11 files with option changes use `withr::local_options`/`local_envvar`), no
  `Sys.setenv`, no `assignInNamespace`/`unlockBinding` hits in tests, all file writes go to temp paths, `setwd`
  (`test-sem-fiml-harness.R`) and `Sys.setlocale` (`test-sem-factor-expand.R`, `test-sem-product-token.R`) restore in
  `on.exit`, `RNGkind` changes (`test-sem-optim.R`, `test-twolevel-few-clusters-harness.R`) restore or are no-ops for
  the default Mersenne-Twister. Mocks (`local_mocked_bindings`, 114 files) are test-scoped. Snapshots: 3 files only.
  Findings:
  1. **Shared two-level fit cache.** `helper-twolevel.R` keeps `.tl_cache` and `tl_cached()`, used by 11 files; each
     parallel worker would rebuild the fits it needs, so two-level files (35% of test time) gain less than the worker
     count suggests. The FIML serial caches (`s3_obj`, `s4_obj`, `sc_obj`) are each used by one file, so they do not
     duplicate across workers.
  2. **One timing assertion.** `test-bootstrap.R` (plugin bootstrap, `expect_true(elapsed < 0.1)`) can fail under a loaded
     worker; relax or skip on CI before the pilot.
  3. **Nested parallelism.** About six places call `mclapply` with `ncores = 2` (`test-bootstrap*.R`, `sim_gate(cores = 2L)`
     in `test-cluster-211.R`): 4 workers x 2 would oversubscribe 4 cores. Slower, not wrong; count it in the pilot.
  4. **Unseeded files.** 12 files draw random numbers with no `set.seed` or `seed =` in the file (`test-classes.R`,
     `test-classes-coverage.R`, `test-fiml-g3-serial-chain-defects.R`, `test-fiml-g3-serial-defects.R`,
     `test-sem-fixed-x-scale.R`, `test-sem-frozen-v080.R`, `test-sem-literal-certificates.R`, `test-sem-nloptr-faults.R`,
     `test-sem-outcomes.R`, `test-sem-start-fallback.R`, `test-sem-twolevel-guards.R`, `test-twolevel-native-docs.R`).
     In a serial run they inherit the RNG state an earlier file left, which is stable by file order; under parallel
     workers that state differs. This is the one real exposure and T1b tests it.
  Unverified: I did not read every one of the 131 `set.seed` files or the 67 `<<-` files; the greps show them inside
  `test_that` blocks, which is local.
  (original task text follows)
- [x] **T1b: seed-sensitivity check of the 12 unseeded files. Done 2026-11-25: no seed-sensitivity found.**
  Result: each of the 12 files ran alone in a fresh R session on an installed build of `origin/dev` under initial seeds
  101, 202, 303, 404 and 505 (60 runs, `NOT_CRAN=true`). All 60 passed, with identical test and expectation counts per
  file across seeds and 0 failures, 0 errors and 0 skips. Planted-defect control: a file asserting `rnorm(1) < 0` failed
  under seed 404 and passed under the other four, so the method can detect seed-sensitivity. Limits: five seeds, one
  platform (macOS, local), each file alone; a failure that needs a particular RNG state left by a specific earlier file
  would not show here, and the parallel pilot (T2) is the test for that. Takeaway: the unseeded files are not a blocker
  for T2; the remaining risks are the shared `.tl_cache`, the 0.1 s timing assertion and `mclapply` oversubscription.
  (original task text follows)
- [ ] **T1b: seed-sensitivity check of the 12 unseeded files.**
  Description: run each of the 12 files from finding 4 on its own, in a fresh R session, with five different initial
  seeds, and compare pass counts.
  Acceptance: every file passes under all five seeds, or the failing file and seed are listed with a fix (add `set.seed`).
  Verification: per-file pass counts equal across seeds; a planted unseeded-failure (a test that asserts a random value)
  is caught.
  Dependencies: none (read-only until a fix is needed). Files: report; `tests/testthat/*` for fixes. Scope: S.

- [ ] **T1: state-leak audit of the test files.**
  Description: grep the tests for what testthat does not reset between files: `set.seed`, `options(`, `Sys.setenv`,
  `local_mocked_bindings` on exported functions, writes outside `withr::local_tempdir`, `skip_on_covr` source
  mutation, and the optimizer fixtures pinned at 1e-6.
  Acceptance: a list of files with a shared-state risk and a one-line decision each (fix with `withr::local_*`,
  tolerate, or run first via `start-first`).
  Verification: every hit is read, not bulk-judged; the list is reviewed against the file count.
  Dependencies: none (read-only). Files: report only. Scope: S.
- [ ] **T2: parallel-workers pilot on one Ubuntu leg.**
  Description: on a throwaway branch, add `Config/testthat/parallel: true`, `Config/testthat/start-first` for the
  slowest files from T0, `Ncpus = 4` in the workflow, and BLAS and OpenMP threads capped per worker.
  Acceptance: three alternating pairs (parallel vs serial control, same commit) on `ubuntu-latest (release)`;
  identical test and expectation counts and identical failures (none) in all runs; median wall-time gain at least 25%.
  Verification: counts compared from the logs; the run ids are recorded in the plan ledger; one planted defect (a
  test that fails) is still reported failed in the parallel run.
  Dependencies: T0, T1, T1b. Files: `DESCRIPTION`, `.github/workflows/R-CMD-check.yaml`, `tests/testthat/*` (leak fixes).
  Scope: M.
- [ ] **T3: decision and adoption.**
  Description: adopt on `dev` if T2 passes; otherwise record the failure and go to T6.
  Acceptance: the PR to `dev` carries the T2 evidence table; `devtools::test()` passes locally with the new config;
  the next PR to `main` shows the required job at or below 25 minutes.
  Verification: the PR body quotes run ids and medians; NEWS is not touched (no behavior change).
  Dependencies: T2, release merged. Scope: S.

### Checkpoint: parallel workers
- [ ] Identical counts across control and pilot; median gain measured over at least three pairs
- [ ] No test relies on file order; the planted failing test is detected
- [ ] Review with the maintainer before adopting

### Phase 2: setup time (S5)

- [ ] **T4: dependency cache for the `devel` leg.**
  Description: `cache: always` on `setup-r-dependencies` (and a check that the cache key includes the R version), then
  a cold run followed by a warm run.
  Acceptance: warm `setup-r-dependencies` for `ubuntu-latest (devel)` is under 5 minutes (it was 25); no stale-cache
  failure over three runs; the "no package called" symptom noted in the workflow comment does not recur.
  Verification: step durations from the jobs API for cold and warm runs.
  Dependencies: none, but merges after the release. Files: `.github/workflows/R-CMD-check.yaml`. Scope: XS.

### Phase 3: only if Phase 1 fails parity or gain

- [ ] **T5: tiered tests for development (S6).**
  Description: gate the slowest files (from T0) behind an environment variable for local and dev runs; the full tier
  stays on PRs to `main` and release.
  Acceptance: the gated list is agreed by the maintainer; a test asserts that `MEDFIT_FULL=1` runs every file that the
  default tier skips; CI on PRs to `main` sets it.
  Verification: skip counts printed in the run; the release run shows 0 additional skips.
  Dependencies: T0, maintainer decision on the list. Scope: S.
- [ ] **T6: shard the suite across runners.**
  Description: split test files across 3 jobs as `gates` does, with a final job that checks the union of files equals
  the whole suite.
  Acceptance: union of shard files equals `tests/testthat/test-*.R`; wall time is the slowest shard; counts sum to the
  serial total.
  Verification: a planted file missing from every shard fails the union check.
  Dependencies: T0. Files: `.github/workflows/R-CMD-check.yaml`, a shard script under `scripts/`. Scope: M.

### Checkpoint: complete
- [ ] Required job median at or below 25 minutes over at least three runs
- [ ] `devel` leg setup under 5 minutes warm
- [ ] Test and expectation counts equal to the serial baseline
- [ ] Speed plan ledger and `.STATUS` updated

### Decision, not a task (maintainer)

- [ ] **D1: matrix policy.** Windows, macOS, oldrel and devel run beside the required leg on every PR to `main`. Running
  them on a schedule or on the tag saves runner cost, not wall time (they run at the same time), and drops cross-platform
  coverage on PRs. Recommendation: keep as is until T3 and T4 are measured.

## Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| State leaks between files under parallel workers (seeds, options, env, temp paths) | High: silent numeric differences in oracle tests | T1 audit; parity of counts and numbers; alternating pairs; planted failing test |
| Run-to-run variance (42 to 62 min for one configuration) hides a real gain | Medium | at least three alternating pairs; compare medians |
| Optimizer fixtures differ by core count or BLAS threads | Medium | fixtures stay pinned at 1e-6; cap BLAS threads per worker; run the OpenBLAS `gates` job |
| A dev commit during the release re-runs all hosted checks | Medium (about 50 minutes lost) | no merge to `dev` until v0.21.0 is tagged |
| Cache serves a stale dependency set | Low | key includes R version; three cold/warm trials |
| Parallel config changes local `devtools::test()` behavior | Low | verify locally before adoption; document `parallel: false` opt-out |

## Open questions

- Which slowest files, if any, may be tiered for development runs (T5)?
- Is the 25-minute target the right bar, or is 25% over the serial median enough?
- Keep the full platform matrix on every PR to `main` (D1)?

## Ledger

| Date | Event |
|---|---|
| 2026-11-25 | written after the 0.21.0 release PR timing analysis; tasks T0 to T6, decision D1; nothing started |
