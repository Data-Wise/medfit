# PLAN: Native mean structure, 0.9.0 (observed intercepts)

**Date:** 2026-10-12 | **Branch:** `feature/native-mean-structure` (not created; branching waits for your request)
**Inputs:** [SPEC](SPEC-native-mean-structure-2026-10-12.md), [GRILL](GRILL-native-mean-structure-2026-10-12.md) (G1-G6 supersede the SPEC where they differ)
**Scope (G2, G6):** observed intercepts and exogenous means only. Out of 0.9.0: latent means (0.11.0), `:` operator and four-way (0.10.0, needs the grammar amendment first).

Sizes: XS/S/M (no hour estimates, per the 0.7.0 grill D7). Checkpoints drive the schedule: **A** after T3, **B** after T6, **C** before release.

## Dependency order

T1 -> T2 -> T3 (A) -> T4 -> T5 -> T6 (B) -> T7 -> T8 -> T9 (C)

## Tasks

### T1: Flag and fixture freeze (S)
- [ ] Add `has_mean` to the RAM spec and sample list, default `FALSE`; no behavior change.
- [ ] Freeze 0.8.0 reference values (F, gradient, SEs, logLik, df) for the existing frozen and OpenMx fixtures, to 1e-12.
- [ ] Test: with `has_mean = FALSE` every frozen value is reproduced (G3 gate, written first, red against a deliberately perturbed `.sem_eval`).
- Files: `R/sem-ml.R`, `tests/testthat/test-sem-*.R`, `helper-sem.R`.

### T2: Parser and table (S)
- [ ] `.sem_to_ram()` (`R/sem-model.R:136`): accept free and fixed `~1` on observed variables; latent `~1` still errors, naming the variable and "planned for a later release".
- [ ] `meanstructure` argument on `fit_sem()`; auto-on when `~1` appears; `meanstructure = FALSE` with a free `~1` errors naming the term; `meanstructure = TRUE` adds saturated free intercepts.
- [ ] Coefficient names `y~1`; intercepts take labels and constraints like any parameter. (0.10.0 rule 9 will forbid fixed, shared, or constrained `~1` rows in models that contain a product, because they move the slopes and `b0` away from OLS; nothing to enforce in 0.9.0, but do not make the table shape depend on it.)
- [ ] Update `R/fit-sem.R:21` roxygen.
- Test: error messages by name; fixed-zero intercept still dropped; labels shared across an intercept and a path.

### T3: Likelihood core (M) — Checkpoint A
- [ ] `m` vector in RAM; `mu = F (I - A)^-1 m`; `.sem_sample()` keeps raw data and (weighted) `xbar`, uncentered data for scores.
- [ ] `F` adds `(xbar - mu)' Sigma^-1 (xbar - mu)`; gradient uses `W = Sigma^-1 - Sigma^-1 (S + d d') Sigma^-1` plus the `dmu` block (`dmu/dm_j = F B e_j`, `dmu/dA_ij = F B E_ij B m`).
- [ ] Expected and observed information gain the additive mean term (G1).
- [ ] `.sem_step_floor()` gets a mean-parameter floor (open question; decide here, record the decision).
- Tests: gradient and information vs finite differences with a theta-dependent mean; saturated free intercepts reproduce the covariance-only estimates, SEs, df, chi-square to 1e-6; planted defects (gradient without `dmu`; information without the mean term) each fail a named test.
- **Checkpoint A:** go/no-go on T4-T6 only if both regression gates pass.

### T4: Scores, weights, sandwich (M)
- [ ] `.sem_scores()` adds `w_i * (dmu_k)' Sigma^-1 (x_i - mu(theta))`; centering at the sample mean removed for the mean-structure path.
- [ ] Update the `R/sem-sandwich.R` header comment (the block-diagonal sentence is no longer true).
- Tests: scores sum to the gradient at the optimum; sandwich SEs match lavaan `meanstructure = TRUE` with `sampling.weights`; planted defect (scores centered at the sample mean) fails.

### T5: Counts, anova, logLik (S)
- [ ] `.sem_df()`: moments `p(p+1)/2 + p` with mean structure on; saturated free intercepts leave df unchanged.
- [ ] `anova()` refuses fits that differ in mean-structure status, naming both.
- [ ] `logLik()` includes the mean term only when the flag is on.
- Tests: df cases (saturated, one fixed intercept, one equality); refusal message; no-`~1` fits keep the 0.8.0 logLik.

### T6: Constraints and MBCO (M) — Checkpoint B
- [ ] Intercept rows work in linear and nonlinear `==`, `<`, `>`, `:=` and in the redundancy rule (`.sem_independent_rows()`).
- [ ] `mbco_sem()` clean-start null refits carry intercepts.
- [ ] Intercept variants of `tests/sim/sem-nonlinear-gate.R` (with `MUTANT=` switches).
- **Checkpoint B:** nonlinear gate and lavaan parity on simple, serial, and parallel models pass, then author go/no-go on T7-T9.

### T7: Methods and extraction (S)
- [ ] `coef`, `vcov`, `tidy`, `glance`, `confint` include intercept rows; `SEMFit` carries the flag.
- [ ] `extract_mediation(<SEMFit>)` returns the same effects as the covariance-only fit; intercept rows never enter `.path_se()` or the effect SEs of two-way effects. **Exception (0.10.0 review F7):** the four-way INTref gradient needs the mediator intercept `b0` (`R/effect-se.R:268`, guarded by `if ("b0" %in% rownames(vc))`), so the `m~1` row and its covariances with the path rows must stay in `vcov` and reach that gradient; add a test that the `b0` terms are present once four-way exists.
- Tests: extraction equality (paths, NIE, SEs) with and without a saturated mean structure.

### T8: Parity oracles (M)
- [ ] lavaan `meanstructure = TRUE`: estimates, SEs, logLik to 1e-4 on simple, serial, parallel; sandwich with `sampling.weights`.
- [ ] OpenMx independent optimum on a constrained-intercept model (`skip_if_not_installed("OpenMx")`).
- [ ] One worked example where an intercept constraint changes a result (G4 honesty requirement); doubles as a docs test.

### T9: Docs and close-out (S) — Checkpoint C
- [ ] NEWS `[Unreleased]`: behavior change (error becomes feature) and the honest benefit statement (saturated-mean fits give identical paths, effects, SEs).
- [ ] `?"medfit-syntax"`, `man/fit_sem.Rd`, `model-native.qmd`, `native-guide.qmd`, `model-native-multi.qmd`, `guide-troubleshooting.qmd`; lavaan comparison table row flips (verified live); `methods.qmd` discrepancy with the mean term; CLAUDE.md Engines row; `.STATUS`.
- [ ] Doc currency check across all tutorial/reference files; `test-refcard-coverage.R`, cookbook, and link tests green.
- [ ] Full suite with counts, `R CMD check --as-cran`, strict-flavor check, `urlchecker`, `spelling`; before any submission, `cran-comments.md` resynced (CRAN stays on hold).
- **Checkpoint C:** release decision (version bump to 0.9.0 handled by release engineering).

## Risks carried from the GRILL

| Risk | Where it is caught |
|---|---|
| Silent change to existing fits | T1 gate, rerun after every edit to `.sem_eval`/`.sem_scores`/`.sem_sample` |
| Information or scores missing the mean term | T3, T4 planted defects |
| SLSQP behavior with intercepts under nonlinear constraints | T6 gate variants |
| Overselling the release | T9 NEWS wording and T8 example |

## Not in this plan

Grammar amendment spec for the `:` operator (next deliverable, gates 0.10.0); lavaan latent-row verification (gates 0.11.0); four-way oracle design (0.10.0 plan).
