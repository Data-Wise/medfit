# medfit 0.21.1 release checklist

Status: **released 2026-11-26 (tag `v0.21.1` at `0bca3ee5`, GitHub release published); CRAN upload pending, see R10.** Single source of release
state. GitHub release done; the CRAN upload (`devtools::submit_cran()`, TTY and emailed link) stays the maintainer's.
Version: patch bump from 0.21.0 (tag `v0.21.0` at `cc84770c`), chosen by the maintainer ("use 0.21.1").

## What 0.21.1 contains

No file under `R/`, `NAMESPACE`, `man/`, `data/` or `inst/` differs from `v0.21.0` (checked with `git diff --stat
v0.21.0..HEAD`), so every result is the 0.21.0 result.

- CRAN readiness: `skip_on_cran()` on the 17 slowest test files (#554); the six test warnings removed (#553).
- Cookbook recipe 25 for MLR (#552). CI and test speed plan records (#549, #550, #551); nothing in it adopted.
- Not in it: parallel test workers (T3), the CRAN upload, fit indices, P2(b), P3 lifts.

## Preconditions

| # | Precondition | Evidence |
|---|---|---|
| P0 | CRAN-skip, warnings and cookbook PRs merged into `dev` | #554 `a91196ea`, #553 `48697aaf`, #552 `25231691` |
| P1 | The maintainer authorizes the release in words | 2026-11-26: "use 0.21.1" and "I confirm the release after all the checks are passed" |
| P2 | Risk tier low: no risk file touched | `git diff --stat v0.21.0..HEAD -- R` shows no change |

## Steps

| # | Step | State |
|---|---|---|
| R1 | Release prep: DESCRIPTION 0.21.1, NEWS, wording, status lines, this file | in this PR |
| R2 | CRAN-mode `R CMD check --as-cran` of the prep tree (NOT_CRAN unset, cores limited, incoming checks on): total time and notes | **done 2026-11-26**: 1 NOTE (version jump 0.3.2 to 0.21.1), 0 warnings, 0 errors; total 4 min 7 s (24.6 min for v0.21.0), tests 194 s; `[ FAIL 0 \| WARN 0 \| SKIP 203 \| PASS 14233 ]` |
| R3 | rforge `cran-prep` stages on the prep tree (strict flavors, tarball, advisory stages) | **done 2026-11-26**, verdict ready, no blockers: document, spell, urlcheck, tarball-check, description, build-hygiene, docs-consistency, test_config ok; check, noSuggests, suggests-only and incoming report notes only (expected); lint and site-leaks advisory (pkgdown site files, not tarball). The full `test` and `coverage` stages and revdep were skipped on purpose (full suite ran on the candidate; coverage is hosted; dependents ran against 0.21.0) |
| R4 | `cran-comments.md` from R2 and R3 | **done**: the generated file said "no downstream dependencies", which is wrong for medfit, so it was rewritten by hand with the real results |
| R5 | Release PR `dev` to `main` titled `Release: v0.21.1`; hosted checks green (R-CMD-check, coverage, gates) | **done 2026-11-26**: PR #556, 14 of 14 checks green on head `bc7a23c6`; the required `ubuntu-latest (release)` job hung in `setup-r` for 5 h on its first run (runner fault, the job timed out at the 5 h limit) and passed in 50 min on `gh run rerun --failed` |
| R6 | Merge commit; `main` CI green; tree equals the tested `dev` tree | **done**: merge commit `0bca3ee5`; lint, pkgdown, test-coverage and every R-CMD-check leg green on `main`; `git diff origin/main origin/dev` empty before the bump |
| R7 | Tag `v0.21.1`; GitHub release with the NEWS block | **done**: tag `v0.21.1` at `0bca3ee5`, release published (`gh release create --target`) |
| R8 | Tagged-install smoke; back-merge `main` into `dev`; bump to `0.21.1.9000` | **done**: smoke on the tag (version 0.21.1, `fit_sem(estimator = "MLR")` scaled-test columns, classed `medfit_error_estimator`); back-merge PR #557 (`0029ff86`); follow-up #558 (`8c335c90`) removed a stray `testthat-problems.rds` that #557 carried by mistake (not in the tag or `main`) |
| R9 | Hand the maintainer the CRAN steps (`submit_cran()`, email link) with the gate's verdict | **done**; see R10 for what happened |

## R10: CRAN submission record (2026-11-26)

| Time (UTC) | Event |
|---|---|
| 19:43 | A submission of **medfit 0.21.1.9000** (the `dev` version, packaged from `dev` after #557, before #558) was made with `submit_cran()`; CRAN mailed the confirmation link |
| 19:47 | CRAN's form recorded the upload (confirmation link used) |
| 20:00 | Withdrawal email sent to `cran-submissions@r-project.org` (sent 2026-11-26 13:00 MST) |

Why it was wrong: the tarball carried `Version: 0.21.1.9000` (a development version, and `cran-comments.md` said 0.21.1) and, built before #558, very likely the stray `tests/testthat/testthat-problems.rds`. Nothing from CRAN had arrived when this was written.

Lessons (also in `CLAUDE.md`, CRAN check practice):
- Submit only from a detached checkout of the release tag (`git switch --detach v0.21.1`), never from `dev`; before the confirmation link, read `Version:` in the email.
- The r-universe tarball is not a CRAN tarball: it adds a top-level `extra/` folder, `Repository: https://data-wise.r-universe.dev` and `Date/Publication` to `DESCRIPTION`. Build with `R CMD build` from the tag.
- A broad `git add -A` after a failing local test run commits `tests/testthat/_problems/` and `testthat-problems.rds`; they are now ignored in `.gitignore` and `.Rbuildignore` (#558).

Resubmission: build from the tag (`git archive v0.21.1`, then `R CMD build`) and submit that file; it has 432 files, no `problems` file, no non-standard top-level folders. CRAN-mode `R CMD check --as-cran --run-donttest` of that tag-built tarball (2026-11-26 13:06 MST; NOT_CRAN unset, cores limited, incoming checks on): **Status: 1 NOTE** (the version jump 0.3.2 to 0.21.1), 0 warnings, 0 errors. Not done: win-builder and R-hub uploads.

## Stop rule

Stop and report on any WARNING or ERROR in R2 or R3, a CRAN-mode check longer than about 10 minutes, or a hosted check
that fails on the release PR and not on v0.21.0.
