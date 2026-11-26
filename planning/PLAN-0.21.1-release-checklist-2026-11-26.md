# medfit 0.21.1 release checklist

Status: **authorized 2026-11-26; R1 in progress on `feature/release-0.21.1`, nothing tagged.** Single source of release
state. GitHub release now; the CRAN upload (`devtools::submit_cran()`, TTY and emailed link) stays the maintainer's.
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
| R5 | Release PR `dev` to `main` titled `Release: v0.21.1`; hosted checks green (R-CMD-check, coverage, gates) | pending |
| R6 | Merge commit; `main` CI green; tree equals the tested `dev` tree | pending |
| R7 | Tag `v0.21.1`; GitHub release with the NEWS block | pending |
| R8 | Tagged-install smoke; back-merge `main` into `dev`; bump to `0.21.1.9000` | pending |
| R9 | Hand the maintainer the CRAN steps (`submit_cran()`, email link) with the gate's verdict | pending |

## Stop rule

Stop and report on any WARNING or ERROR in R2 or R3, a CRAN-mode check longer than about 10 minutes, or a hosted check
that fails on the release PR and not on v0.21.0.
