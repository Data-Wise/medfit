# RESULT: quality control of the 0.15.0 native defaults flip

Date: 2026-10-26. Branch `feature/native-defaults-flip`. Plan `planning/PLAN-0.15.0-native-defaults-flip-2026-10-26.md`;
spec `planning/specs/SPEC-0-15-release-2026-10-26.md`; decision `planning/specs/ADR-native-defaults-2026-10-24.md`.

Sources: the plan's T1 result, the T3 and T4 oracle-QA and gates reports (`_agents_workspace/T3`, `T4`, git-ignored), and
the 0.15.0 release brief for the oracle matrix. Counts marked "matrix" are quoted from the brief, not re-run here.

## What the release changes

An unset `fixed_x` resolves to the exogenous observed variables (an explicit character subset) and an unset
`meanstructure` is `TRUE`. `options(medfit.native_defaults)` is obsolete and ignored with one message per session (removed
in 0.16.0), and the 0.14.x `medfit_warning_default_change` no longer fires. Moves: the conditional log likelihood, the
parameter count, AIC and BIC, the names in `coef()`, `vcov()` and `tidy()`, and the retry seed. Does not move: structural
estimates and standard errors.

## Flip gates

| Gate | Result | Where |
|---|---|---|
| Oracle matrix, structural estimates and SEs, default vs the 0.14.x settings | 557 rows: 503 pass, 54 limit, 0 block (matrix) | `tests/sim/native-defaults-oracle.R` |
| lavaan `fixed.x = TRUE, meanstructure = TRUE` vs the default fit, simple, product and lenient cells | row sets, npar and conditional logLik equal; coefficients to 1e-15, SEs to 2.1e-11 (T3 QA) | `_agents_workspace/T3/qa.md` |
| Neutrality against `dev` for an explicit setting | max difference 0 (T3 QA) | same |
| Planted defects | a resolver that overwrites an explicit `FALSE`: 13 failures; the old default left in `fit_mediation()` only, two variants: caught; the old default restored: 9 of the 12 rewritten test files fail as required, the other 3 pin explicit settings by design (T4 QA) | same, `_agents_workspace/T4/qa.md` |
| Full suite (`NOT_CRAN=true devtools::test()`, reference BLAS, macOS) | 1694 tests, 8580 expectations, 0 failed, 0 errors, 2 skipped, 1 warning (T4 gates) | `_agents_workspace/T4/gates.md` |
| Lint | 168 `object_usage_linter` findings package-wide on the branch against 169 on `dev` (T3 gates) | same |

## Documented limit: #320

`compare_lr()` with lavaan above the reference. Re-measured 2026-10-26 on `dev` at `74016e6` (pinned design and seeds,
`c(1:12, 15, 37, 41)` by 4 cells, n = 200, a = b = 0.4; lavaan 0.7.3, OpenMx 2.22.11; local macOS run):

| Run | lavaan above reference (of 60) | OpenMx above reference (of 60) |
|---|---|---|
| Baseline 2026-10-24 (`tests/sim/results/compare-lr-gate-2026-10-24.csv`) | 18 | 13 |
| Control, `v0.14.0` tree plus the current gate script | 18 | 13 |
| `dev` at `74016e6` | 18 | 13 |

The control reproduces both baselines, so the comparison is valid. Neither count grew and no row is mislabeled (150 of
150 rows pass). Decision: a documented limit, with the note in `?compare_lr`. The flip does not change it: the
retained-null fixture shows the same lavaan zero-start value on `origin/dev` with explicit `fixed_x = TRUE,
meanstructure = TRUE` and on the flip branch default (T4 QA). This result is recorded in the docs only; it has not been
posted to #320.

## Not run

- The OpenBLAS gate runs (`gates (rest)`, `gates (reliability)`) on the runner. They run on PRs to `main` only; they are
  deferred to the release PR, and no result is claimed here. The 2026-10-26 #320 re-measure ran locally, not on the runner.
- The BLAS of the 2026-10-24 baseline is not recorded, so a BLAS difference between baseline and re-measure is possible;
  the control run on the `v0.14.0` tree reproduced both counts in the same environment.
