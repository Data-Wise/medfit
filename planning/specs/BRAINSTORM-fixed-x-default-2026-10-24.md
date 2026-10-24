# BRAINSTORM: `fixed_x = TRUE` as the default of the native engine (2026-10-24)

Depth: deep. Focus: API. Decisions below are the author's answers to six questions on 2026-10-24.

## The change

`fit_sem()` and `fit_mediation(engine = "native")` default to `fixed_x = FALSE` (exogenous variances,
covariances and means estimated). The goal is lavaan's `fixed.x = TRUE` behavior by default: those moments held at
the sample values.

What `fixed_x` changes (from `?fit_sem`, `R/methods-sem.R`): structural estimates, their SEs, df and chi-square are
**unchanged**; the parameter count, the log-likelihood (now conditional on the fixed block), AIC and BIC **change**.
`anova()`, `mbco_sem()`, `AIC()` and `BIC()` refuse fits whose `fixed_x` sets differ.

## Decisions (author, 2026-10-24)

| # | Question | Decision | Rejected |
|---|---|---|---|
| D1 | Migration | 0.14.0 warns, 0.15.0 flips | flip in 0.14.0 as a breaking change; opt-in option only |
| D2 | Scope | `fit_sem()` and native `fit_mediation()` share one default | `fit_sem()` only (two likelihoods for one model) |
| D3 | `compare_lr()` | support `fixed_x` (lavaan `fixed.x = TRUE`; OpenMx fixes the exogenous paths at the sample moments) | keep refusing (every default fit would be refused after the flip) |
| D4 | Statement on an exogenous variable (`treatment ~~ treatment`) | when the **default** set `fixed_x`, leave that variable free with a note; an explicit `fixed_x = TRUE` still errors | error for both |
| D5 | Dependents | `[BREAKING]` issue with a 2-month notice; RMediation passes `fixed_x` explicitly during 0.14 | NEWS only |
| D6 | Gates and frozen tests | pin `fixed_x = FALSE` where a baseline depends on logLik/npar; add a test that structural results agree under both settings | re-baseline everything under TRUE |

## What the other engines do by default (checked 2026-10-24)

| Engine | Exogenous variance by default | Evidence |
|---|---|---|
| lavaan `sem()` | fixed at the sample value (`fixed.x = TRUE`) | `lavaan-comparison.qmd` passes `fixed.x = FALSE` to match medfit today |
| semopy 2.3.11 | fixed (no row in the output; matches `fit_sem(fixed_x = TRUE)` to 1e-6) | `tests/sim/oracles/semopy-simple.csv` |
| OpenMx (RAM) | no such option: an exogenous variance you do not write is a fixed **zero**, and the fit fails ("covariance ... not positive definite") | run here on `mediation_demo`; fixed.x behavior needs `mxPath(..., free = FALSE, values = <sample variance>)` |
| medfit native | estimated (`fixed_x = FALSE`) | `?fit_sem` |

So after the flip medfit agrees with lavaan and semopy out of the box; the OpenMx adapter of `compare_lr()` (D3) has to
write the fixed paths itself.

## Ramifications found (scan, 2026-10-24)

| Area | Effect of the flip | Handling |
|---|---|---|
| API freeze (0.11.0, `test-api-freeze.R`) | the pinned default `fixed_x = FALSE` changes | D1: deprecation first; update the freeze test in 0.15.0 with the flip |
| `compare_lr()` (`R/compare-lr.R:156`) | refuses any `fixed_x` fit, so every default fit | D3 |
| Explicit exogenous `~~`/`~1` statements | error today when the variable is fixed | D4 |
| `anova()`, `mbco_sem()`, AIC/BIC | unchanged within a default (both fits share the set); comparing a 0.14 fit with a 0.15 fit errors | NEWS note: refit old fits |
| `logLik()`, AIC, BIC, `glance()` npar | change for every default fit | the 0.14 warning names them |
| Product terms (`x:m`) | `TRUE` fixes product columns too (doc) | VERIFY the four-way extraction and `.sem_product_modeltest()` verdicts under TRUE |
| Factor covariates, weights, mean structure | `fixed_x` already handles them (`fixed_x = "g"`, weighted moments, fixed means) | covered by the `fixed-x` and `factor` gates; add default-path cells |
| Latent exogenous variables | `fixed_x` applies to observed exogenous variables only | no change; say so in the docs |
| medfit tests | 588 `fit_sem()` calls in `tests/testthat` without `fixed_x` (103 with) | D6: most check structural results (unaffected); pin FALSE only where a logLik/npar/AIC is frozen |
| `tests/sim` gates | 27 `fit_sem()` calls without `fixed_x` | D6: pin FALSE; the 0.14 warning would otherwise flood the reliability gate (76,800 fits) |
| Vignettes, mini-book | 227 calls without `fixed_x`; printed logLik/AIC change | re-render in 0.15.0; `guide-changes` row |

### Mediationverse

| Package | Uses `fit_sem()` | Effect |
|---|---|---|
| missingmed | yes; always passes `fixed_x = FALSE` and refuses any other state (`R/mbco_sem.R:222-239`) | none |
| RMediation | examples in `R/00_classes.R`, tests `test-mbco-semfit*.R` call `fit_sem()` without `fixed_x` | measured: no MBCO value moves (differences about 1e-12, quick win 1); the 0.14 warning would appear in their tests and examples. D5: pass `fixed_x` explicitly |
| probmed, mediationverse, medsim, medrobust | no `fit_sem()` calls | none |

## Quick wins (< 30 min)
1. DONE 2026-10-24: RMediation's `test-mbco-semfit*.R` against scratch builds of `origin/dev` with the `fit_sem()`
   default `FALSE` and `TRUE` (only that line changed). Same 69 expectations, 0 failed, 1 skip, per-test results
   identical. Every MBCO statistic, its p-value and the `anova()` chi-square difference agree to about 1e-12 (e.g.
   product 0.0830995742875 in both); only the full model's log-likelihood moves (-2818.67 to -2550.92, `x` fixed).
   So the flip changes no RMediation number; D5's explicit argument is only to silence the 0.14 warning.
2. Draft the `[BREAKING]` issue text (D5) so the 2-month clock can start with 0.14.0.

## Medium effort (1-2 hrs each)
- [ ] 0.14.0: `fixed_x = NULL` sentinel in the signature (default resolved inside); when `NULL` and the model has an
      observed exogenous variable, `lifecycle::deprecate_soft()`-style warning, once per session, naming logLik/AIC/BIC.
- [ ] 0.14.0: D4 lenient path for the default only, with its note; error text unchanged for an explicit `TRUE`.
- [ ] 0.14.0: `compare_lr()` with `fixed_x` (D3): lavaan `fixed.x = TRUE`, OpenMx fixed exogenous paths; new cells in
      the `compare-lr` gate.
- [ ] 0.14.0: pin `fixed_x = FALSE` in `tests/sim` gates and in tests that freeze logLik/npar/AIC (D6); invariance
      test: estimates and SEs equal under both settings on the parity structures.

## Long-term (0.15.0)
- [ ] Flip the default; update `test-api-freeze.R`, `?fit_sem`, `?"medfit-syntax"`, the lavaan comparison (its
      `fixed.x = FALSE` note reverses), the syntax crosswalk table, cookbook recipe 18, native tutorial step 9,
      `guide-changes`, NEWS behavior-change note.
- [ ] ADR decision recording D1-D6 in `planning/specs/ADR-native-solver-and-engines-2026-10-23.md`.

## Test plan
| Tier | What |
|---|---|
| unit | sentinel resolution (`NULL` → FALSE + warning in 0.14, → TRUE in 0.15); D4 note vs explicit-TRUE error; warning once per session |
| integration | `fit_mediation(engine = "native")` and `fit_sem()` give the same fixed set; `mbco_sem()`/`anova()` across two default fits; `compare_lr()` with `fixed_x` through lavaan and OpenMx |
| dependency | RMediation and missingmed suites against the 0.14 and 0.15 builds in scratch libraries (per-test comparison, as for 0.13.0) |
| e2e | `fixed-x` gate gains default-path cells; product four-way under TRUE |
| dogfood | render the articles and mini-book in 0.15.0 and diff the printed logLik/AIC |

## Documentation
`?fit_sem`, `?"medfit-syntax"`, `vignettes/articles/lavaan-comparison.qmd`, `syntax-crosswalk.qmd`, cookbook recipe 18,
`native-tutorial.qmd` step 9, `guide-changes.qmd`, NEWS, README version row.

## Recommended next step
-> Quick win 1: confirm RMediation's MBCO numbers are unchanged under a flipped default before writing any code. If
they move, D5 needs more than an explicit argument.
