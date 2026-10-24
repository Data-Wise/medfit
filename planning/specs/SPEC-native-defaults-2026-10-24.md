# SPEC: `fixed_x = TRUE` and `meanstructure = TRUE` as the native engine's defaults

**Date:** 2026-10-24. **Status:** grilled 2026-10-24 (Q1-Q7 answered); decisions in
`planning/specs/ADR-native-defaults-2026-10-24.md` (E-1 to E-12). **Releases:** 0.14.0 (warn), 0.15.0 (flip).
**Inputs:** `BRAINSTORM-fixed-x-default-2026-10-24.md` (decisions D1-D6, author 2026-10-24); the measurement in
`evidence/native-defaults-2026-10-24/` (this spec, section 4).

## 1. Objective

Make a default native fit look like a default lavaan or semopy fit: exogenous observed variables held at their
sample moments (`fixed_x = TRUE`, lavaan's `fixed.x = TRUE`) and observed intercepts estimated
(`meanstructure = TRUE`, lavaan's `meanstructure = TRUE`). Today `fit_sem()` and `fit_mediation(engine = "native")`
default to `fixed_x = FALSE` and `meanstructure = NULL` (a mean structure only when the model writes `~1` or a
product term).

**Who it serves.** A user who moves between lavaan and medfit, and medfit's own comparisons (`compare_lr()`, the
syntax crosswalk, the lavaan comparison), which today must pass `fixed.x = FALSE` to lavaan to line up.

**What must not change, and what is known about it.** `fixed_x` is documented to leave structural estimates,
their SEs, chi-square and df unchanged (`?fit_sem`; the `fixed-x` gate checks it on its cells). A saturated mean
structure (free, unconstrained intercepts) left the covariance part and the log-likelihood unchanged on the one
model measured (section 4.1) and on the frozen fixtures (4.3). **That is the extent of the evidence.** Weights and
sandwich SEs, constrained or fixed intercepts, latent models, products, factor expansion and named `fixed_x` subsets
are not yet covered under the new defaults; R-12 makes that oracle matrix a 0.14.0 requirement before the flip
(Codex review, 2026-10-24). What changes by design is bookkeeping: the parameter vector, `npar`, the conditional
log-likelihood, AIC, BIC, the names in `coef()`/`vcov()`/`tidy()`, and the retry seed.

### Assumptions (correct these in the grill)
1. Both defaults move together on the same schedule: one deprecation message, one flip. (E-2)
2. The flip is advisory-then-compulsory: 0.14.0 warns, 0.15.0 flips; no hard removal of `FALSE`/`NULL`, which stay
   valid values forever.
3. `meanstructure = NULL` keeps its current meaning ("follow the syntax") as an explicit choice after the flip.
4. 0.14.0 and 0.15.0 stay GitHub-only releases (CRAN deferred, #83), so the 2-month notice runs on GitHub.

## 2. Requirements

| ID | Requirement | Release |
|---|---|---|
| R-1 | First task of 0.14.0 (E-8): fix the mean-structure pinned-parameter bug: under a mean structure a parameter fixed by an equality (`b == 0`) gets SE 5.6e-18 and a z-statistic instead of SE 0 and `NA` (reproduced on today's build with an explicit `meanstructure = TRUE`) | 0.14.0, before anything else |
| R-2 | `fixed_x` and `meanstructure` defaults become a sentinel resolved inside `fit_sem()`; when the user supplied neither and the model has an observed exogenous variable, warn once per session that the defaults change in 0.15.0, naming what moves (`npar`, logLik, AIC, BIC, coefficient names) | 0.14.0 |
| R-3 | Opt-in before the flip: `options(medfit.native_defaults = "0.15")` switches both defaults and silences the warning; removed in 0.16.0 (E-9) | 0.14.0 |
| R-4 | `compare_lr()` accepts `fixed_x` and a saturated mean structure: the lavaan adapter passes `fixed.x`/`meanstructure`, the OpenMx adapter writes fixed exogenous paths (OpenMx has no fixed.x option: an unwritten exogenous variance is a fixed zero and the fit fails) and a means path | 0.14.0 |
| R-5 | Under the default (not an explicit `fixed_x = TRUE`), a variable the model writes a `~~` or `~1` statement on is left free with a note (D4) | 0.14.0 behind the opt-in; 0.15.0 default |
| R-6 | Refits pass the parent fit's settings explicitly: `mbco_sem()` passes `meanstructure = if (has_mean) TRUE` and `NULL` otherwise (`R/sem-mbco.R:165`); after the flip `NULL` means TRUE, so a `meanstructure = FALSE` fit would be refit with a mean structure. Pass `FALSE`. missingmed has the same line (`missingmed/R/mbco_sem.R:236`) | 0.14.0 (medfit); missingmed PR before 0.15.0 |
| R-7 | Flip both defaults in `fit_sem()` and native `fit_mediation()` (D2) | 0.15.0 |
| R-8 | Tests and gates that encode the old defaults pass them explicitly (D6), so their baselines stay valid; new tests cover the new defaults | 0.14.0 (pin), 0.15.0 (flip) |
| R-9 | Docs: `?fit_sem`, `?"medfit-syntax"`, lavaan comparison (its `fixed.x = FALSE` note reverses), syntax crosswalk table, cookbook recipes 18 and 19, native tutorial step 9, mini-book chapters that print npar/logLik, `guide-changes`, NEWS behavior-change note | 0.14.0 (announce), 0.15.0 (rewrite) |
| R-11a | Versioned resolution (E-14): in 0.14.x an unset setting takes the old value unless the opt-in is set; in 0.15.0 an unset setting takes the new value **unconditionally** (the option is ignored with a once-per-session note that it is obsolete, removed in 0.16.0); an explicit `FALSE`/`NULL` is never overwritten in either release. Tests: option absent, set, and stale, in both releases | 0.14.0, 0.15.0 |
| R-11b | Provenance for the default (E-13): an implicit `fixed_x = TRUE` is resolved in `fit_sem()` to an explicit character subset, the observed exogenous columns (product and factor columns included, E-11) minus those the model writes a `~~` or `~1` statement on, before `.sem_fit_syntax()` runs; an empty subset means `FALSE`. The resolved subset is what refits, `mbco_sem()`, `anova()` and `compare_lr()` see, and `glance()$fixed_x` names it. An explicit `TRUE` keeps today's error | 0.14.0 behind the opt-in |
| R-12 | Oracle matrix before the flip: the four combinations of the two settings crossed with weights + sandwich SEs, fixed and constrained intercepts, a latent mediator, a product (four-way), a factor covariate, and a named `fixed_x` subset; compare structural estimates, their SEs, chi-square, df, logLik, npar, AIC and BIC with lavaan (`fixed.x`, `meanstructure`, `sampling.weights`, `se = "robust.huber.white"`) or, where lavaan has no equivalent, a stated independent oracle. A cell that disagrees blocks 0.15.0 or is documented as a limit | 0.14.0 |
| R-10 | Ecosystem: `[BREAKING]` issue with the 2-month notice (D5); RMediation passes the settings explicitly in its examples and tests | 0.14.0 |

## 3. Interface (backend/API)

```r
# 0.14.0 (E-14): unset takes the old value unless opted in. missing() is only reliable before reassignment.
fit_sem <- function(model, data, ..., meanstructure = NULL, fixed_x = FALSE, ...) {
  fx_unset <- missing(fixed_x); ms_unset <- missing(meanstructure)
  new <- identical(getOption("medfit.native_defaults"), "0.15")
  if (fx_unset && new) fixed_x <- .sem_default_fixed_x(model, data)   # E-13: a character subset, never bare TRUE
  if (ms_unset && new) meanstructure <- TRUE
  if (!new && (fx_unset || ms_unset)) .warn_native_defaults_once(fx_unset, ms_unset, model)
  ...
}
# 0.15.0: formals become meanstructure = TRUE, fixed_x = TRUE; unset is resolved unconditionally
fit_sem <- function(model, data, ..., meanstructure = TRUE, fixed_x = TRUE, ...) {
  if (missing(fixed_x)) fixed_x <- .sem_default_fixed_x(model, data)  # explicit TRUE still errors on statements
  if (!is.null(getOption("medfit.native_defaults"))) .note_option_obsolete_once()
  ...
}
# fit_mediation(engine = "native") forwards fixed_x / meanstructure only when present in engine_args (E-10)
```

- An explicit `meanstructure = NULL` keeps "follow the syntax" (E-10).
- `test-api-freeze.R` pins the formals; 0.14.0 keeps them, 0.15.0 changes the two defaults (`fixed_x = TRUE`,
  `meanstructure = TRUE`) and updates the freeze test with the deprecation note.
- Warning class `medfit_warning_default_change` (lifecycle-style frequency: once per session per argument), so
  dependents can silence it by class in tests and CI can grep for it (section 6).

## 4. Measured impact (2026-10-24)

Three scratch installs of `origin/dev` at `1506262`: **base** (unchanged), **ms** (`meanstructure = TRUE` default),
**msfx** (both flipped). medfit's full suite and six dependents' suites against each. Scripts and raw results:
`planning/specs/evidence/native-defaults-2026-10-24/` (`arm.R`, `why.R`, `summary.csv`, `failures.csv`).

### 4.1 One model, three builds

| Build | has_mean | npar | logLik | chi-square / df |
|---|---|---|---|---|
| base | FALSE | 6 | -1488.061 | 0 / 0 |
| ms | TRUE | 9 | -1488.061 | 0 / 0 |
| msfx | TRUE | 7 | -1197.749 | 0 / 0 |

`fit_sem("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment", mediation_demo)`.

### 4.2 Dependents: no impact

| Package | Expectations | base / ms / msfx failures | Per-test results identical across builds |
|---|---|---|---|
| RMediation | 2383 | 0 / 0 / 0 | yes |
| missingmed | 2488 | 0 / 0 / 0 | yes |
| medsim | 1412 | 0 / 0 / 0 | yes |
| probmed | 832 | 0 / 0 / 0 | yes |
| medrobust | 376 | 0 / 0 / 0 | yes |
| mediationverse | 108 | 0 / 0 / 0 | yes |

RMediation's MBCO statistics also agree to about 1e-12 under the `fixed_x` flip (fixed_x brainstorm, quick win 1).
missingmed passes `fixed_x = FALSE` and refuses anything else, so the `fixed_x` flip cannot reach it; its refit line
(R-6) is a latent issue its tests do not exercise.

### 4.3 medfit's own suite

| Build | Expectations | Failed | Errors | Newly failing tests (files) |
|---|---|---|---|---|
| base | 6938 | 0 | 0 | - |
| ms | 6898 | 93 | 18 | 60 (24) |
| msfx | 6839 | 141 | 29 | 98 (38) |

Triage of the 60 under **ms** (each message is in `failures.csv`):

| Class | Tests | Real behavior change |
|---|---|---|
| `compare_lr()` refuses a mean structure | 14 | **yes, design gap** (R-4) |
| assertions of the old default: `npar`, `length(theta)`, `has_mean`, df attribute, names, tidy keys, seed | ~35 | no: they encode the default |
| frozen and parity vectors compared by position | ~9 | no: matched by name, theta agrees to 1e-8 and vcov to 4e-10 (`sem-v080-frozen.rds`, all three cases) |
| tests that mock covariance-only internals (`test-sem-nl-ineq.R`, native book ch. 5) | 3 | no |
| pinned parameter under a mean structure | 1 | **yes, existing bug** (R-1) |

The 38 more under **msfx**: tests that pass `fixed_x = TRUE` against what is now also the default (anova/AIC refusal
tests that compare a fixed fit with a "free" one, plumbing tests that expect `FALSE` to be passed), explicit
statements on exogenous variables now refused (R-5), a test that seeds starts by name from a fit with a different
parameter set, the edge grid refusing with a different reason (still a clear refusal), and
`test-sem-sumprod.R` no longer seeing its start-disagreement warning (the retry seed hashes `ram$par_names`,
`R/sem-optim.R:94`, so new parameters change the random starts: R-11 below).

| ID | Requirement found by the measurement |
|---|---|
| R-11 | The retry seed (`.sem_seed()`) hashes the parameter names, so the flip changes the random starts of every multi-start fit. Results of a well-identified fit do not move (measured), but which start wins, and the start-spread warning, can. NEWS states it; the reliability gate is rerun under the new defaults before 0.15.0 |

### 4.4 Not measured yet
- The `tests/sim` gates under the flipped defaults (about 50 minutes on the 24.04 runner): R-8 pins them, but a
  dispatched run under the new defaults is a 0.15.0 acceptance criterion.
- Vignettes and the mini-book under the new defaults (227 `fit_sem()` calls): rendered in the 0.15.0 PR.

## 5. Commands

```bash
# medfit suite against a scratch build (the measurement's method)
Rscript planning/specs/evidence/native-defaults-2026-10-24/arm.R /private/tmp/<dir> <arm>
# one test file during development
Rscript -e 'devtools::load_all(); testthat::test_file("tests/testthat/test-sem-mean-fit.R")'
# simulation gates, one shard, as CI runs them
Rscript tests/sim/run-gates.R --sim --only reliability
# dependents
gh workflow run revdep-check.yaml --ref <branch>
```

## 6. CI and release (devops)

- **Risk tier.** `R/fit-sem.R` is not in `tests/sim/risk-files.txt`, but the flip changes the parameter vector of
  every default fit, which the QC rule calls high-risk. The 0.15.0 PR carries the seven-item admission checklist
  by hand; add `R/fit-sem.R` to `risk-files.txt` in 0.14.0 so the `risk-tier` job enforces it.
- **Gates.** Pinned to ubuntu-24.04 (#312). 0.14.0 pins the old defaults in the gate scripts (R-8); the 0.15.0 PR
  to main runs the gates under the new defaults, plus a dispatched reliability run compared with the last green
  run's acceptance rate (non-inferiority, same rule as D-8 of the solver ADR).
- **Warning hygiene.** A test-helper check fails the suite if `medfit_warning_default_change` fires in medfit's own
  tests (every test states its settings by 0.15.0); dependents silence it by class.
- **Dependents.** `revdep-check.yaml` (weekly, manual) covers probmed, RMediation, medrobust through revdepcheck;
  missingmed, medsim and mediationverse are not in it. The scratch-library per-test comparison
  (`arm.R`) is the release evidence for all six; run it on the 0.14.0 and 0.15.0 release PRs.
- **Rollback.** The flip is one default in one function plus docs; reverting the 0.15.0 commit restores the old
  defaults with no data migration. A user can always pass the old values.

## 7. Testing strategy

| Tier | Tests |
|---|---|
| unit | sentinel resolution (unset, explicit FALSE/TRUE, explicit `NULL` for meanstructure); warning once per session and only when unset; opt-in switch; D4 note vs explicit-TRUE error |
| resolver (R-11a, R-11b) | option absent / set / stale in 0.14 and 0.15 builds; explicit `FALSE` and `NULL` never overwritten; the implicit subset excludes variables with `~~`/`~1` statements and includes product and factor columns; an explicit `TRUE` on such a model errors; the same through `fit_mediation(engine = "native")` |
| oracle matrix (R-12) | section 2, R-12 |
| integration | `fit_mediation(engine = "native")` and `fit_sem()` give the same settings; `mbco_sem()`/`anova()` across two default fits and across a default and a `meanstructure = FALSE` fit (R-6); `compare_lr()` with `fixed_x` and means through lavaan and OpenMx |
| regression (R-1) | pinned parameter under a mean structure: SE exactly 0, statistic and p-value `NA`, point interval; planted defect: the old tolerance-free comparison |
| invariance | for the parity structures, estimates and SEs of the covariance part are equal under all four combinations of the two settings (to 1e-8); logLik equal under `meanstructure` and shifted by the exogenous block under `fixed_x` |
| dependency | six dependents, per-test identity across old and new builds (`arm.R`) |
| gates | full `tests/sim` under the new defaults before 0.15.0; reliability non-inferior to the last green run |

## 8. Boundaries

- **Always:** pass both settings explicitly in medfit's own tests, gates, examples and articles; measure dependents
  per test before each release PR; keep `FALSE` and `NULL` valid values.
- **Ask first:** the flip itself (0.15.0); any change to `compare_lr()` verdict rules; touching another repo
  (RMediation, missingmed PRs).
- **Never:** change structural estimates or SEs as part of this work; flip without the 0.14.0 warning release;
  re-baseline a frozen fixture to make a default-change test pass.

## 9. Success criteria

1. 0.14.0: R-1 fixed with a regression test; the warning fires exactly when a caller leaves a setting unset and the
   model has an observed exogenous variable; `compare_lr()` runs on `fixed_x` and mean-structure fits through both
   engines; medfit's suite raises no `medfit_warning_default_change`; six dependents unchanged per test.
2. 0.15.0: a default fit equals lavaan's default `sem()` fit in estimates, SEs, npar, logLik, AIC and BIC on the
   parity structures (1e-6); the gates pass under the new defaults on the 24.04 runner; reliability non-inferior;
   six dependents unchanged per test; every article renders.

## 10. Grill answers (author, 2026-10-24)

| Q | Answer |
|---|---|
| Q1 schedule | both defaults together: one warning (0.14.0), one flip (0.15.0) (E-2) |
| Q2 opt-in | `options(medfit.native_defaults = "0.15")` (E-9) |
| Q3 unset | `missing()`, forward only supplied `engine_args` (E-10) |
| Q4 exogenous means | confirmed by measurement: with both flipped the simple model has 7 parameters (3 paths, 2 residual variances, 2 intercepts), lavaan's count with `fixed.x = TRUE` and a mean structure |
| Q5 products | fixed too (E-11); verify lavaan parity in the 0.15.0 PR |
| Q6 reliability | blocker for 0.15.0 (E-12) |
| Q7 R-1 bug | first task inside 0.14.0, not a separate patch (E-8; against the recommendation) |

## 10b. Adversarial review (Codex, 2026-10-24): verdict needs-attention, all three findings accepted

| Finding | Response |
|---|---|
| [high] the first resolver sketch reassigned unset arguments from the option, so in 0.15.0 an ordinary call without the option would restore the old defaults | R-11a / E-14: versioned resolution; 0.15.0 ignores the option |
| [high] resolving the default to bare `TRUE` loses whether the user or the default asked for it, so E-5's lenience cannot be implemented | R-11b / E-13: the default resolves to an explicit subset before the fit |
| [high] invariance and parity claims exceed one saturated unweighted model and unchanged dependent suites | section 1 rewritten as a bounded claim; R-12 oracle matrix required before the flip |

## 10a. Questions as asked
- Q1 Same schedule for both defaults, or `meanstructure` first? (assumption 1)
- Q2 The opt-in mechanism: `options(medfit.native_defaults = "0.15")`, a function argument, or none.
- Q3 How the sentinel tells "unset" from an explicit `meanstructure = NULL`.
- Q4 Should `fixed_x = TRUE` fix the exogenous **means** too (lavaan does with a mean structure; medfit does today)?
  Confirms the msfx row of 4.1.
- Q5 Product terms: `fixed_x = TRUE` also fixes the product columns (`?fit_sem`); is that the wanted default for a
  four-way model, or should products stay free?
- Q6 Is the reliability non-inferiority run a blocker for 0.15.0 or a follow-up?
