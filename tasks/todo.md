# Todo: `fixed_x` (bundled into 0.9.0)

**Status (2026-10-13):** merged to `dev` as #175 (`1023520`, with the 0.9.0 mean structure, #174 `8681083`); unreleased, DESCRIPTION still 0.8.0. Open below: the F-C doc-currency report, the 0.9.0 release gate R1 and the release decision.

Plan: [tasks/plan.md](plan.md) | Spec: [SPEC-native-fixed-x](../planning/specs/SPEC-native-fixed-x-2026-10-13.md) | Branch `feature/native-fixed-x` is created only on request. Test-first: write the failing test, then the code. After any edit to `.sem_eval`, `.sem_df`, `logLik` or `.sem_complete`, rerun the frozen gate (`test-sem-frozen-v080.R`).

## Phase 0: groundwork
- [x] **R0** (done 2026-10-13: lavaan keeps an explicit statement free and its df moves; medfit errors, see the GRILL) Probe lavaan 0.7.2: explicit `x ~~ x` under `fixed.x = TRUE`
  - Acceptance: result (error / override / stays free) written to the GRILL open questions
  - Verify: a 10-line script in `planning/specs/evidence/native-fixed-x-2026-10-13/` and its output
  - Files: that script, `GRILL-native-fixed-x-2026-10-13.md`
- [x] **V1** (harness written 2026-10-13: tests fail for the intended reason) `fixed_x` argument, validation and errors (S1, S5)
  - Acceptance: `FALSE` unchanged; `TRUE`/names resolve against `ram$ov_x`; a non-exogenous name, an explicit statement or a tie to a structural parameter errors naming the term; resolved set stored in `SEMFit@internals`
  - Verify: `devtools::test(filter = "sem-fixed-x-args")`; frozen gate
  - Files: `R/fit-sem.R`, `R/sem-fit.R`, `R/sem-model.R`, `tests/testthat/test-sem-fixed-x-args.R`

## Phase 1: the core path
- [x] **V2** `fixed_x = TRUE`, covariance-only, simple model, end to end (S2, S3, S6)
  - Acceptance: flagged fixed rows in `@table`; values from the listwise sample after `.sem_sample()`; `ram$n_fixed_x` leaves `.sem_moments()` and `ram$q`; df equals the free fit's; structural estimates and SEs equal the free fit (1e-8 / 1e-6); `theta`/`vcov`/`coef()`/npar exclude fixed rows
  - Verify: `devtools::test(filter = "sem-fixed-x-core")`; frozen gate
  - Files: `R/sem-model.R`, `R/sem-fit.R`, `R/sem-ml.R`, `R/methods-sem.R`, `tests/testthat/test-sem-fixed-x-core.R`
- [x] **Checkpoint F-A** (passed 2026-10-13)
  - [x] lavaan `fixed.x = TRUE` parity: rows, npar, df 1, chi-square 9.188694 (reference model)
  - [x] frozen gate bit-identical with `fixed_x = FALSE`
  - [x] planted defect `countrestrict` fails the df test
  - [ ] full suite green; review with you before Phase 2

## Phase 2: breadth (V3, V4, V5 independent)
- [x] **V3** Subsets and pairing (S1, S4)
  - Acceptance: every subset of {x, c1, c2} equals the free fit; `c1 ~~ c2` survives with explicit `~~` rows elsewhere; a product column selectable by name
  - Verify: `devtools::test(filter = "sem-fixed-x-subsets")`; defect `droppair` fails
  - Files: `R/sem-model.R`, `tests/testthat/test-sem-fixed-x-subsets.R`
- [x] **V4** Mean structure and conditional logLik (S7)
  - Acceptance: fixed means follow S2; logLik conditional and equal to lavaan's `fixed.x = TRUE`; `glance()$fixed_x` lists names; print/summary note present only when something is fixed
  - Verify: `devtools::test(filter = "sem-fixed-x-loglik")`; defect `jointlik` fails
  - Files: `R/methods-sem.R`, `R/sem-ml.R`, `tests/testthat/test-sem-fixed-x-loglik.R`
- [x] **V5** Scale (S10)
  - Acceptance: `.sem_shift_ok()` allows fixed-x intercept rows; fits with `TRUE` and a subset accepted at location mean/sd 0, 1e2, 1e3, 1e5 with estimates equal to location 0
  - Verify: sweep test; defect `noshift` fails
  - Files: `R/sem-fit.R`, `tests/testthat/test-sem-fixed-x-scale.R`

## Phase 3: robustness and guards
- [x] **V6** Weights, sandwich, missing rows
  - Acceptance: weighted moments (ML denominator); subset invariance for model-based and sandwich SEs, weighted and with missing rows
  - Verify: `devtools::test(filter = "sem-fixed-x-weights")`
  - Files: `R/sem-fit.R`, `R/sem-ml.R`, `tests/testthat/test-sem-fixed-x-weights.R`
- [x] **V7** Comparisons refused (S8)
  - Acceptance: `.sem_fixed_signature()`; `anova()`, `mbco_sem()` and multi-fit `AIC()`/`BIC()` error across different fixed sets or data naming the difference; same set compares; single-fit `AIC()` unchanged
  - Verify: `devtools::test(filter = "sem-fixed-x-compare")`; defect `aicwarnonly` fails
  - Files: `R/sem-anova.R`, `R/sem-mbco.R`, `R/methods-aic.R` (new), `NAMESPACE`/`R/zzz.R`, `tests/testthat/test-sem-fixed-x-compare.R`
- [x] **V8** Plumbing and visibility (S6, S9)
  - Acceptance: `fit_mediation(engine_args = list(fixed_x = ))` reaches the fit; `.sem_fit_branches()` and the `mbco_sem()` refit carry it; `extract_mediation()` unchanged; `tidy()`/`summary()` show fixed rows (flag, est, se NA)
  - Verify: `devtools::test(filter = "sem-fixed-x-plumbing")` (mocked-binding capture of the refit call)
  - Files: `R/fit-glm.R`, `R/sem-fit.R`, `R/sem-mbco.R`, `R/methods-tidy.R`, `tests/testthat/test-sem-fixed-x-plumbing.R`
  - Open item (found 2026-10-13, not blocking): the `mbco_sem()` refit does not pass `fixed_x` (`R/sem-mbco.R:155-156` passes `meanstructure` only) and the plumbing test's mock sees `fit_sem()`'s own call first (`test-sem-fixed-x-plumbing.R:14-25`), so it cannot catch this. The statistic is unchanged (`test-sem-fixed-x-compare.R:16`).
- [x] **Checkpoint F-B** (merged with #175; PR body: six planted defects, not five, each exit 1)
  - [x] S1-S10 each covered by a passing test
  - [x] the planted defects each fail the right test
  - [x] full suite, lint (120 columns), strict `R CMD check` clean (PR #175: full suite 0 failures, strict check 0/0/0, CI 10/10)

## Phase 4: evidence and docs
- [x] **V9** Gate script, timing table, OpenMx (OpenMx subset check: `test-sem-fixed-x-compare.R`, estimates 1e-4, SEs 1e-3)
  - Acceptance: `tests/sim/sem-fixed-x-gate.R` RULE MET; each `MUTANT` exits 1; OpenMx agrees on a subset; 30-covariate timing table (n, hardware, free parameters before/after) recorded
  - Verify: `Rscript tests/sim/sem-fixed-x-gate.R`; `MUTANT=<name> ...` for each defect
  - Files: `tests/sim/sem-fixed-x-gate.R`, `planning/specs/evidence/native-fixed-x-2026-10-13/`
- [x] **V10** Docs, NEWS and close-out (done in #175: NEWS, `?fit_sem`, `?"medfit-syntax"`, `model-native.qmd`, `native-guide.qmd`, the lavaan-comparison row, CLAUDE.md Engines row, `.STATUS`; strict check 0/0/0 and spelling clean per the PR body; the doc-currency run and `urlchecker` are not recorded there)
  - Acceptance: NEWS (behavior note, measured ratio only), `?fit_sem`, `?"medfit-syntax"`, `model-native.qmd`, `native-guide.qmd`, lavaan-comparison row, CLAUDE.md Engines row, `.STATUS`; doc-currency check run
  - Verify: `devtools::document()`; spelling and urlchecker clean; strict check 0/0/0
  - Files: `NEWS.md`, `R/fit-sem.R`, `R/sem-syntax-help.R`, `vignettes/articles/*.qmd`, `CLAUDE.md` (grouped; split if any exceeds 5 files)
- [ ] **Checkpoint F-C** (CI green and merged; open: the doc-currency report, not evidenced)
  - [x] CI green (10/10); merge decision made (#175 merged to `dev`)
  - [ ] doc-currency report (not recorded in the PR body)

## 0.9.0 release gates (carried from the archived plan)
- [ ] **R1** Say whether the 1e-12 frozen tolerance is relative; confirm the fixture on the ubuntu CI BLAS
- [x] **R2** (done: `.sem_seed()` never hashed `m`, identical to 0.8.0; pinned by a test) `.sem_seed()` must not hash the `m` vector when the mean flag is off; add a frozen retry case
- [ ] **Release decision** (version bump and tag are release engineering's)
